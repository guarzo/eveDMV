defmodule EveDmv.Monitoring.ErrorTracker do
  @moduledoc """
  Centralized error tracking and monitoring for EVE DMV.

  Tracks errors across the application, maintains statistics,
  and provides reporting capabilities for error patterns.
  """

  use GenServer
  require Logger

  alias EveDmv.Error
  alias EveDmv.ErrorCodes

  @table_name :error_tracker_ets
  # Keep errors for 24 hours
  @error_ttl :timer.hours(24)
  @cleanup_interval :timer.minutes(30)

  defmodule ErrorRecord do
    @moduledoc false
    defstruct [
      :id,
      :error,
      :timestamp,
      :module,
      :function,
      :metadata
    ]
  end

  defmodule ErrorStats do
    @moduledoc false
    defstruct [
      :category,
      :code,
      :count,
      :first_seen,
      :last_seen,
      :retry_count,
      :success_after_retry
    ]
  end

  # Client API

  @doc """
  Start the error tracker.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Track an error occurrence.
  """
  def track_error(error, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:track_error, error, metadata})
  end

  @doc """
  Track a successful retry after an error.
  """
  def track_retry_success(error_code, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:track_retry_success, error_code, metadata})
  end

  @doc """
  Get error statistics for a specific category.
  """
  def get_category_stats(category) do
    GenServer.call(__MODULE__, {:get_category_stats, category})
  end

  @doc """
  Get error statistics for a specific error code.
  """
  def get_error_stats(error_code) do
    GenServer.call(__MODULE__, {:get_error_stats, error_code})
  end

  @doc """
  Get recent errors (last N minutes).
  """
  def get_recent_errors(minutes \\ 60) do
    GenServer.call(__MODULE__, {:get_recent_errors, minutes})
  end

  @doc """
  Get error summary report.
  """
  def get_summary_report do
    GenServer.call(__MODULE__, :get_summary_report)
  end

  @doc """
  Clear all error data (for testing).
  """
  def clear_all do
    GenServer.call(__MODULE__, :clear_all)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # Create ETS tables for fast concurrent reads
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(:error_stats_ets, [:named_table, :set, :public, read_concurrency: true])

    # Schedule periodic cleanup
    schedule_cleanup()

    # Attach telemetry handlers
    attach_telemetry_handlers()

    state = %{
      start_time: DateTime.utc_now(),
      total_errors: 0,
      errors_by_category: %{},
      errors_by_code: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:track_error, error, metadata}, state) do
    normalized_error = Error.normalize(error)
    category = ErrorCodes.category(normalized_error.code)

    # Create error record
    record = %ErrorRecord{
      id: generate_id(),
      error: normalized_error,
      timestamp: DateTime.utc_now(),
      module: metadata[:module],
      function: metadata[:function],
      metadata: metadata
    }

    # Store in ETS
    :ets.insert(@table_name, {record.id, record})

    # Update stats
    update_error_stats(normalized_error.code, category)

    # Update state counters
    new_state = %{
      state
      | total_errors: state.total_errors + 1,
        errors_by_category: Map.update(state.errors_by_category, category, 1, &(&1 + 1)),
        errors_by_code: Map.update(state.errors_by_code, normalized_error.code, 1, &(&1 + 1))
    }

    # Check for error patterns
    check_error_patterns(normalized_error, new_state)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:track_retry_success, error_code, _metadata}, state) do
    # Update retry success stats
    case :ets.lookup(:error_stats_ets, error_code) do
      [{^error_code, stats}] ->
        updated_stats = %{stats | success_after_retry: stats.success_after_retry + 1}
        :ets.insert(:error_stats_ets, {error_code, updated_stats})

      _ ->
        :ok
    end

    {:noreply, state}
  end

  @impl true
  def handle_call({:get_category_stats, category}, _from, state) do
    stats = collect_category_stats(category)
    {:reply, stats, state}
  end

  @impl true
  def handle_call({:get_error_stats, error_code}, _from, state) do
    stats =
      case :ets.lookup(:error_stats_ets, error_code) do
        [{^error_code, stats}] -> stats
        [] -> nil
      end

    {:reply, stats, state}
  end

  @impl true
  def handle_call({:get_recent_errors, minutes}, _from, state) do
    cutoff = DateTime.add(DateTime.utc_now(), -minutes * 60, :second)

    errors =
      :ets.tab2list(@table_name)
      |> Enum.map(fn {_id, record} -> record end)
      |> Enum.filter(fn record ->
        DateTime.compare(record.timestamp, cutoff) == :gt
      end)
      |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})

    {:reply, errors, state}
  end

  @impl true
  def handle_call(:get_summary_report, _from, state) do
    report = %{
      start_time: state.start_time,
      uptime_hours: DateTime.diff(DateTime.utc_now(), state.start_time, :hour),
      total_errors: state.total_errors,
      errors_by_category: state.errors_by_category,
      top_errors: get_top_errors(10),
      error_rate: calculate_error_rate(state),
      retry_success_rate: calculate_retry_success_rate()
    }

    {:reply, report, state}
  end

  @impl true
  def handle_call(:clear_all, _from, _state) do
    :ets.delete_all_objects(@table_name)
    :ets.delete_all_objects(:error_stats_ets)

    new_state = %{
      start_time: DateTime.utc_now(),
      total_errors: 0,
      errors_by_category: %{},
      errors_by_code: %{}
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_old_errors()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp generate_id do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  defp update_error_stats(error_code, category) do
    now = DateTime.utc_now()

    case :ets.lookup(:error_stats_ets, error_code) do
      [{^error_code, stats}] ->
        updated_stats = %{
          stats
          | count: stats.count + 1,
            last_seen: now,
            retry_count:
              if(ErrorCodes.retryable?(error_code),
                do: stats.retry_count + 1,
                else: stats.retry_count
              )
        }

        :ets.insert(:error_stats_ets, {error_code, updated_stats})

      [] ->
        new_stats = %ErrorStats{
          category: category,
          code: error_code,
          count: 1,
          first_seen: now,
          last_seen: now,
          retry_count: if(ErrorCodes.retryable?(error_code), do: 1, else: 0),
          success_after_retry: 0
        }

        :ets.insert(:error_stats_ets, {error_code, new_stats})
    end
  end

  defp collect_category_stats(category) do
    error_codes = ErrorCodes.codes_in_category(category)

    error_codes
    |> Enum.map(fn code ->
      case :ets.lookup(:error_stats_ets, code) do
        [{^code, stats}] -> stats
        [] -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp get_top_errors(limit) do
    :ets.tab2list(:error_stats_ets)
    |> Enum.map(fn {_code, stats} -> stats end)
    |> Enum.sort_by(& &1.count, :desc)
    |> Enum.take(limit)
  end

  defp calculate_error_rate(state) do
    uptime_minutes = max(1, DateTime.diff(DateTime.utc_now(), state.start_time, :minute))
    state.total_errors / uptime_minutes
  end

  defp calculate_retry_success_rate do
    stats =
      :error_stats_ets
      |> :ets.tab2list()
      |> Enum.map(fn {_code, stats} -> stats end)
      |> Enum.filter(fn stats -> stats.retry_count > 0 end)

    total_retries = Enum.sum(Enum.map(stats, & &1.retry_count))
    total_successes = Enum.sum(Enum.map(stats, & &1.success_after_retry))

    if total_retries > 0 do
      total_successes / total_retries * 100
    else
      0.0
    end
  end

  defp check_error_patterns(error, state) do
    # Check for error spikes
    if state.total_errors > 0 and rem(state.total_errors, 100) == 0 do
      Logger.warning("Error tracker: #{state.total_errors} total errors recorded")
    end

    # Check for specific error code spikes
    error_count = Map.get(state.errors_by_code, error.code, 0)

    if error_count > 0 and rem(error_count, 50) == 0 do
      Logger.warning("Error spike detected: #{error.code} has occurred #{error_count} times")

      # Emit telemetry for alerting
      :telemetry.execute(
        [:eve_dmv, :error_tracker, :spike_detected],
        %{count: error_count},
        %{error_code: error.code, category: ErrorCodes.category(error.code)}
      )
    end
  end

  defp cleanup_old_errors do
    cutoff = DateTime.add(DateTime.utc_now(), -@error_ttl, :millisecond)

    # Remove old error records
    old_records =
      @table_name
      |> :ets.tab2list()
      |> Enum.filter(fn {_id, record} ->
        DateTime.compare(record.timestamp, cutoff) == :lt
      end)

    Enum.each(old_records, fn {id, _record} ->
      :ets.delete(@table_name, id)
    end)

    if length(old_records) > 0 do
      Logger.info("Error tracker: Cleaned up #{length(old_records)} old error records")
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp attach_telemetry_handlers do
    :telemetry.attach_many(
      "error-tracker-handlers",
      [
        [:eve_dmv, :error, :validation],
        [:eve_dmv, :error, :external_service],
        [:eve_dmv, :error, :system],
        [:eve_dmv, :error, :security],
        [:eve_dmv, :error, :business_logic],
        [:eve_dmv, :error, :not_found]
      ],
      &__MODULE__.handle_error_telemetry/4,
      nil
    )
  end

  @doc false
  def handle_error_telemetry(_event_name, _measurements, metadata, _config) do
    # Track errors that come through telemetry
    if metadata[:error_code] do
      error = Error.new(metadata[:error_code], metadata[:error_message] || "Unknown error")
      track_error(error, metadata)
    end
  end
end
