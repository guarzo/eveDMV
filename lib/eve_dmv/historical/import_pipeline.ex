defmodule EveDmv.Historical.ImportPipeline do
  @moduledoc """
  Sprint 15A: High-performance historical killmail import pipeline.

  Optimized for processing millions of killmails with progress tracking,
  error recovery, and performance monitoring. Targets >10,000 killmails/minute.
  """

  use GenServer
  require Logger
  require Ash.Query

  alias EveDmv.Killmails.KillmailRaw
  alias Phoenix.PubSub

  @batch_size 1000
  @max_concurrent_batches 4
  # Report every 10k killmails
  @progress_report_interval 10_000

  defstruct [
    :import_id,
    :source_type,
    :source_path,
    :status,
    :start_time,
    :end_time,
    :total_count,
    :processed_count,
    :success_count,
    :error_count,
    :duplicate_count,
    :current_rate,
    :peak_rate,
    :errors,
    :batch_queue
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start a historical data import from a file or URL.

  Options:
  - :source - File path or URL to import from
  - :format - :jsonl (default), :json_array, :zkb_api
  - :resume_from - Line/position to resume from (for recovery)
  - :filter - Optional filter function to select killmails
  """
  def start_import(source, opts \\ []) do
    GenServer.call(__MODULE__, {:start_import, source, opts}, :timer.minutes(1))
  end

  @doc """
  Get current import status and progress.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Pause the current import (can be resumed).
  """
  def pause_import do
    GenServer.call(__MODULE__, :pause_import)
  end

  @doc """
  Resume a paused import.
  """
  def resume_import do
    GenServer.call(__MODULE__, :resume_import)
  end

  @doc """
  Cancel the current import.
  """
  def cancel_import do
    GenServer.call(__MODULE__, :cancel_import)
  end

  # Server callbacks

  def init(_opts) do
    state = %__MODULE__{
      status: :idle,
      errors: [],
      batch_queue: :queue.new()
    }

    {:ok, state}
  end

  def handle_call({:start_import, source, opts}, _from, %{status: :idle} = state) do
    import_id = generate_import_id()

    new_state = %{
      state
      | import_id: import_id,
        source_type: determine_source_type(source),
        source_path: source,
        status: :initializing,
        start_time: DateTime.utc_now(),
        total_count: 0,
        processed_count: 0,
        success_count: 0,
        error_count: 0,
        duplicate_count: 0,
        current_rate: 0,
        peak_rate: 0,
        errors: []
    }

    # Start the import process
    send(self(), {:initialize_import, opts})

    Logger.info("🚀 Starting historical import #{import_id} from #{source}")

    {:reply, {:ok, import_id}, new_state}
  end

  def handle_call({:start_import, _source, _opts}, _from, state) do
    {:reply, {:error, "Import already in progress: #{state.import_id}"}, state}
  end

  def handle_call(:get_status, _from, state) do
    status = %{
      import_id: state.import_id,
      status: state.status,
      source: state.source_path,
      progress: %{
        total: state.total_count,
        processed: state.processed_count,
        success: state.success_count,
        errors: state.error_count,
        duplicates: state.duplicate_count,
        percentage: calculate_percentage(state.processed_count, state.total_count)
      },
      performance: %{
        current_rate: state.current_rate,
        peak_rate: state.peak_rate,
        elapsed_seconds: calculate_elapsed(state.start_time),
        eta_seconds: calculate_eta(state)
      },
      recent_errors: Enum.take(state.errors, 5)
    }

    {:reply, {:ok, status}, state}
  end

  def handle_call(:pause_import, _from, %{status: status} = state)
      when status in [:running, :processing] do
    Logger.info("⏸️  Pausing import #{state.import_id}")
    {:reply, :ok, %{state | status: :paused}}
  end

  def handle_call(:pause_import, _from, state) do
    {:reply, {:error, "Cannot pause import in status: #{state.status}"}, state}
  end

  def handle_call(:resume_import, _from, %{status: :paused} = state) do
    Logger.info("▶️  Resuming import #{state.import_id}")
    send(self(), :process_next_batch)
    {:reply, :ok, %{state | status: :running}}
  end

  def handle_call(:resume_import, _from, state) do
    {:reply, {:error, "Cannot resume import in status: #{state.status}"}, state}
  end

  def handle_call(:cancel_import, _from, state) do
    Logger.info("🛑 Cancelling import #{state.import_id}")
    {:reply, :ok, %{state | status: :cancelled, end_time: DateTime.utc_now()}}
  end

  # Import initialization
  def handle_info({:initialize_import, opts}, state) do
    case initialize_source(state.source_path, state.source_type, opts) do
      {:ok, total_count, batch_queue} ->
        Logger.info("📊 Import initialized: #{total_count} killmails to process")

        new_state = %{
          state
          | status: :running,
            total_count: total_count,
            batch_queue: batch_queue
        }

        # Start processing batches
        start_batch_processors(new_state)

        # Schedule first progress report
        Process.send_after(self(), :report_progress, 5000)

        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to initialize import: #{inspect(reason)}")
        {:noreply, %{state | status: :failed, errors: [reason | state.errors]}}
    end
  end

  # Batch processing
  def handle_info(:process_next_batch, %{status: :running} = state) do
    case :queue.out(state.batch_queue) do
      {{:value, batch}, remaining_queue} ->
        # Process this batch
        Task.start(fn -> process_batch(batch, state.import_id) end)

        # Continue with next batch
        if :queue.len(remaining_queue) > 0 do
          Process.send_after(self(), :process_next_batch, 100)
        end

        {:noreply, %{state | batch_queue: remaining_queue}}

      {:empty, _} ->
        # No more batches
        if state.processed_count >= state.total_count do
          complete_import(state)
        else
          # Wait for current batches to finish
          Process.send_after(self(), :check_completion, 1000)
          {:noreply, state}
        end
    end
  end

  def handle_info(:process_next_batch, state) do
    # Not running, ignore
    {:noreply, state}
  end

  # Batch result handling
  def handle_info({:batch_processed, batch_result}, state) do
    new_state = update_progress(state, batch_result)

    # Update current processing rate
    rate = calculate_current_rate(new_state)
    peak_rate = max(rate, new_state.peak_rate)

    new_state = %{new_state | current_rate: rate, peak_rate: peak_rate}

    # Check if we should report progress
    if rem(new_state.processed_count, @progress_report_interval) < @batch_size do
      report_import_progress(new_state)
    end

    {:noreply, new_state}
  end

  # Progress reporting
  def handle_info(:report_progress, %{status: status} = state)
      when status in [:running, :processing] do
    report_import_progress(state)

    # Schedule next report
    # Every 30 seconds
    Process.send_after(self(), :report_progress, 30_000)

    {:noreply, state}
  end

  def handle_info(:report_progress, state) do
    # Not running, don't schedule next report
    {:noreply, state}
  end

  # Completion check
  def handle_info(:check_completion, state) do
    if state.processed_count >= state.total_count do
      complete_import(state)
    else
      # Still processing, check again later
      Process.send_after(self(), :check_completion, 2000)
      {:noreply, state}
    end
  end

  def handle_info(:reset_to_idle, _state) do
    {:noreply, %__MODULE__{status: :idle, errors: [], batch_queue: :queue.new()}}
  end

  # Private functions

  defp generate_import_id do
    "import_#{DateTime.utc_now() |> DateTime.to_unix()}_#{:rand.uniform(9999)}"
  end

  defp determine_source_type(source) do
    cond do
      String.starts_with?(source, "http") -> :url
      String.ends_with?(source, ".jsonl") -> :jsonl_file
      String.ends_with?(source, ".json") -> :json_file
      File.dir?(source) -> :directory
      true -> :unknown
    end
  end

  defp initialize_source(path, :jsonl_file, opts) do
    try do
      # Count total lines for progress tracking
      line_count = count_file_lines(path)

      # Create batch queue
      resume_from = Keyword.get(opts, :resume_from, 0)
      batch_queue = create_file_batch_queue(path, resume_from, @batch_size)

      {:ok, line_count - resume_from, batch_queue}
    catch
      _, error ->
        {:error, error}
    end
  end

  defp initialize_source(path, :json_file, _opts) do
    try do
      # Load and parse JSON file
      data = File.read!(path) |> Jason.decode!()

      killmails =
        case data do
          %{"killmails" => km} when is_list(km) -> km
          list when is_list(list) -> list
          _ -> []
        end

      # Create batches
      batch_queue = create_memory_batch_queue(killmails, @batch_size)

      {:ok, length(killmails), batch_queue}
    catch
      _, error ->
        {:error, error}
    end
  end

  defp initialize_source(_path, type, _opts) do
    {:error, "Unsupported source type: #{type}"}
  end

  defp count_file_lines(path) do
    path
    |> File.stream!()
    |> Enum.count()
  end

  defp create_file_batch_queue(path, resume_from, batch_size) do
    # Create batches with file positions for efficient reading
    path
    |> File.stream!()
    |> Stream.drop(resume_from)
    |> Stream.with_index(resume_from)
    |> Stream.chunk_every(batch_size)
    |> Enum.reduce(:queue.new(), fn batch, queue ->
      :queue.in({:file_batch, path, batch}, queue)
    end)
  end

  defp create_memory_batch_queue(killmails, batch_size) do
    killmails
    |> Enum.chunk_every(batch_size)
    |> Enum.reduce(:queue.new(), fn batch, queue ->
      :queue.in({:memory_batch, batch}, queue)
    end)
  end

  defp start_batch_processors(_state) do
    # Start concurrent batch processors
    1..@max_concurrent_batches
    |> Enum.each(fn _ ->
      Process.send_after(self(), :process_next_batch, 100)
    end)
  end

  defp process_batch({:file_batch, _path, lines}, import_id) do
    result = %{
      processed: 0,
      success: 0,
      errors: 0,
      duplicates: 0,
      error_details: []
    }

    final_result =
      Enum.reduce(lines, result, fn {line, line_num}, acc ->
        case process_killmail_line(line, line_num) do
          {:ok, :created} ->
            %{acc | processed: acc.processed + 1, success: acc.success + 1}

          {:ok, :duplicate} ->
            %{acc | processed: acc.processed + 1, duplicates: acc.duplicates + 1}

          {:error, reason} ->
            error = %{line: line_num, error: reason}

            %{
              acc
              | processed: acc.processed + 1,
                errors: acc.errors + 1,
                error_details: [error | acc.error_details]
            }
        end
      end)

    # Send result back to the pipeline
    send(self(), {:batch_processed, final_result})

    # Emit telemetry
    :telemetry.execute(
      [:eve_dmv, :import, :batch],
      %{
        processed: final_result.processed,
        success: final_result.success,
        errors: final_result.errors
      },
      %{import_id: import_id}
    )
  end

  defp process_batch({:memory_batch, killmails}, import_id) do
    # Similar to file batch but with already parsed data
    result = %{
      processed: 0,
      success: 0,
      errors: 0,
      duplicates: 0,
      error_details: []
    }

    final_result =
      Enum.reduce(killmails, result, fn killmail, acc ->
        case import_killmail(killmail) do
          {:ok, :created} ->
            %{acc | processed: acc.processed + 1, success: acc.success + 1}

          {:ok, :duplicate} ->
            %{acc | processed: acc.processed + 1, duplicates: acc.duplicates + 1}

          {:error, reason} ->
            error = %{killmail_id: killmail["killmail_id"], error: reason}

            %{
              acc
              | processed: acc.processed + 1,
                errors: acc.errors + 1,
                error_details: [error | acc.error_details]
            }
        end
      end)

    send(self(), {:batch_processed, final_result})

    :telemetry.execute(
      [:eve_dmv, :import, :batch],
      %{
        processed: final_result.processed,
        success: final_result.success,
        errors: final_result.errors
      },
      %{import_id: import_id}
    )
  end

  defp process_killmail_line(line, line_num) do
    with {:ok, json} <- Jason.decode(line),
         {:ok, status} <- import_killmail(json) do
      {:ok, status}
    else
      {:error, %Jason.DecodeError{}} ->
        {:error, "Invalid JSON at line #{line_num}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp import_killmail(killmail_data) do
    # Check if killmail already exists
    killmail_id = killmail_data["killmail_id"]

    case KillmailRaw |> Ash.Query.filter(killmail_id == ^killmail_id) |> Ash.read_one() do
      {:ok, _existing} ->
        {:ok, :duplicate}

      {:error, %Ash.Error.Query.NotFound{}} ->
        # Create new killmail
        attrs = %{
          killmail_id: killmail_id,
          killmail_time: parse_killmail_time(killmail_data["killmail_time"]),
          solar_system_id: killmail_data["solar_system_id"],
          victim_ship_type_id: get_in(killmail_data, ["victim", "ship_type_id"]),
          victim_character_id: get_in(killmail_data, ["victim", "character_id"]),
          victim_corporation_id: get_in(killmail_data, ["victim", "corporation_id"]),
          victim_alliance_id: get_in(killmail_data, ["victim", "alliance_id"]),
          total_value: get_in(killmail_data, ["zkb", "totalValue"]) || 0,
          raw_data: killmail_data
        }

        case KillmailRaw |> Ash.Changeset.for_create(:create, attrs) |> Ash.create() do
          {:ok, _} -> {:ok, :created}
          {:error, error} -> {:error, format_error(error)}
        end

      {:error, error} ->
        {:error, format_error(error)}
    end
  end

  defp parse_killmail_time(time_string) when is_binary(time_string) do
    case DateTime.from_iso8601(time_string) do
      {:ok, datetime, _} -> datetime
      _ -> DateTime.utc_now()
    end
  end

  defp parse_killmail_time(_), do: DateTime.utc_now()

  defp format_error(%Ash.Error.Invalid{errors: errors}) do
    errors
    |> Enum.map(&inspect/1)
    |> Enum.join(", ")
  end

  defp format_error(error), do: inspect(error)

  defp update_progress(state, batch_result) do
    %{
      state
      | processed_count: state.processed_count + batch_result.processed,
        success_count: state.success_count + batch_result.success,
        error_count: state.error_count + batch_result.errors,
        duplicate_count: state.duplicate_count + batch_result.duplicates,
        errors: Enum.take(batch_result.error_details ++ state.errors, 100)
    }
  end

  defp calculate_percentage(0, 0), do: 0.0
  defp calculate_percentage(processed, total), do: Float.round(processed / total * 100, 2)

  defp calculate_elapsed(nil), do: 0

  defp calculate_elapsed(start_time) do
    DateTime.diff(DateTime.utc_now(), start_time, :second)
  end

  defp calculate_current_rate(%{start_time: nil}), do: 0

  defp calculate_current_rate(%{processed_count: processed, start_time: start_time}) do
    elapsed = calculate_elapsed(start_time)

    if elapsed > 0 do
      # Per minute
      round(processed / elapsed * 60)
    else
      0
    end
  end

  defp calculate_eta(%{current_rate: 0}), do: nil

  defp calculate_eta(%{current_rate: rate, total_count: total, processed_count: processed}) do
    remaining = total - processed

    if rate > 0 do
      # Seconds
      round(remaining / rate * 60)
    else
      nil
    end
  end

  defp report_import_progress(state) do
    percentage = calculate_percentage(state.processed_count, state.total_count)

    Logger.info("""
    📊 Import Progress: #{state.import_id}
    Progress: #{state.processed_count}/#{state.total_count} (#{percentage}%)
    Success: #{state.success_count} | Errors: #{state.error_count} | Duplicates: #{state.duplicate_count}
    Rate: #{state.current_rate}/min | Peak: #{state.peak_rate}/min
    """)

    # Broadcast progress for UI updates
    PubSub.broadcast(
      EveDmv.PubSub,
      "import:#{state.import_id}",
      {:import_progress, state}
    )
  end

  defp complete_import(state) do
    end_time = DateTime.utc_now()
    duration = DateTime.diff(end_time, state.start_time, :second)

    Logger.info("""
    ✅ Import Complete: #{state.import_id}
    Total Processed: #{state.processed_count}
    Success: #{state.success_count}
    Errors: #{state.error_count}
    Duplicates: #{state.duplicate_count}
    Duration: #{format_duration(duration)}
    Average Rate: #{round(state.processed_count / max(duration, 1) * 60)}/min
    Peak Rate: #{state.peak_rate}/min
    """)

    final_state = %{state | status: :completed, end_time: end_time}

    # Emit completion telemetry
    :telemetry.execute(
      [:eve_dmv, :import, :complete],
      %{
        duration: duration,
        processed: state.processed_count,
        success: state.success_count,
        errors: state.error_count
      },
      %{import_id: state.import_id}
    )

    # Reset to idle after a delay
    Process.send_after(self(), :reset_to_idle, 60_000)

    {:noreply, final_state}
  end

  defp format_duration(seconds) when seconds < 60 do
    "#{seconds}s"
  end

  defp format_duration(seconds) when seconds < 3600 do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}m #{secs}s"
  end

  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    "#{hours}h #{minutes}m"
  end

end
