defmodule Mix.Tasks.EveDmv.ImportHistorical do
  @moduledoc """
  Import historical killmail data from various sources.

  ## Usage

      mix eve_dmv.import_historical [source] [options]

  ## Sources

  - File path (JSONL format): `/path/to/killmails.jsonl`
  - File path (JSON array): `/path/to/killmails.json`
  - Directory of files: `/path/to/killmail/directory/`
  - HTTP URL: `https://example.com/killmails.jsonl`

  ## Options

  - `--format` - File format: jsonl (default), json_array, zkb_api
  - `--resume-from` - Resume from line number (for recovery)
  - `--batch-size` - Batch size for processing (default: 1000)
  - `--monitor` - Enable real-time progress monitoring

  ## Examples

      # Import from JSONL file
      mix eve_dmv.import_historical /data/killmails.jsonl
      
      # Import with monitoring
      mix eve_dmv.import_historical /data/killmails.jsonl --monitor
      
      # Resume failed import from line 50000
      mix eve_dmv.import_historical /data/killmails.jsonl --resume-from 50000
  """

  use Mix.Task
  require Logger

  alias EveDmv.Historical.{ImportPipeline, ImportProgressMonitor}

  @shortdoc "Import historical killmail data"

  @impl Mix.Task
  def run(args) do
    {opts, args, _} =
      OptionParser.parse(args,
        strict: [
          format: :string,
          resume_from: :integer,
          batch_size: :integer,
          monitor: :boolean
        ]
      )

    case args do
      [source] ->
        # Start the application
        Mix.Task.run("app.start")

        # Start the import
        import_historical_data(source, opts)

      _ ->
        Mix.shell().error("Usage: mix eve_dmv.import_historical [source] [options]")
        Mix.shell().info("")
        Mix.shell().info("Run 'mix help eve_dmv.import_historical' for more information")
    end
  end

  defp import_historical_data(source, opts) do
    Mix.shell().info("🚀 Starting historical import from: #{source}")

    # Convert options
    import_opts = [
      format: String.to_existing_atom(opts[:format] || "jsonl"),
      resume_from: opts[:resume_from] || 0
    ]

    # Start monitoring if requested
    if opts[:monitor] do
      Task.start(fn -> monitor_import_progress() end)
    end

    # Start the import
    case ImportPipeline.start_import(source, import_opts) do
      {:ok, import_id} ->
        Mix.shell().info("✅ Import started with ID: #{import_id}")

        # Subscribe to progress updates
        ImportProgressMonitor.subscribe_to_progress(import_id)

        # Wait for completion
        wait_for_import_completion(import_id)

      {:error, reason} ->
        Mix.shell().error("❌ Failed to start import: #{inspect(reason)}")
    end
  end

  defp wait_for_import_completion(import_id) do
    receive do
      {:import_progress, state} ->
        # Continue waiting if still running
        if state.status in [:running, :processing, :paused] do
          wait_for_import_completion(import_id)
        else
          # Import finished
          display_final_results(state)
        end
    after
      5000 ->
        # Check status periodically
        case ImportPipeline.get_status() do
          {:ok, status} ->
            if status.status in [:running, :processing, :paused] do
              wait_for_import_completion(import_id)
            else
              Mix.shell().info("Import finished with status: #{status.status}")
            end

          _ ->
            Mix.shell().error("Lost connection to import pipeline")
        end
    end
  end

  defp display_final_results(state) do
    duration =
      case state.end_time do
        nil ->
          "unknown"

        end_time ->
          seconds = DateTime.diff(end_time, state.start_time, :second)
          format_duration(seconds)
      end

    Mix.shell().info("")
    Mix.shell().info("=" |> String.duplicate(60))
    Mix.shell().info("📊 Import Complete: #{state.import_id}")
    Mix.shell().info("=" |> String.duplicate(60))
    Mix.shell().info("Status: #{state.status}")
    Mix.shell().info("Duration: #{duration}")
    Mix.shell().info("Total Processed: #{state.processed_count}")
    Mix.shell().info("Successful: #{state.success_count}")
    Mix.shell().info("Errors: #{state.error_count}")
    Mix.shell().info("Duplicates: #{state.duplicate_count}")
    Mix.shell().info("Average Rate: #{state.current_rate} killmails/min")
    Mix.shell().info("Peak Rate: #{state.peak_rate} killmails/min")
    Mix.shell().info("=" |> String.duplicate(60))

    if state.error_count > 0 and length(state.errors) > 0 do
      Mix.shell().info("")
      Mix.shell().info("Recent Errors:")

      state.errors
      |> Enum.take(5)
      |> Enum.each(fn error ->
        Mix.shell().info("  - #{inspect(error)}")
      end)
    end
  end

  defp monitor_import_progress do
    # Simple progress display loop
    :timer.sleep(2000)

    case ImportPipeline.get_status() do
      {:ok, status} when status.status in [:running, :processing] ->
        percentage = calculate_percentage(status.progress.processed, status.progress.total)
        bar = progress_bar(percentage)

        IO.write(
          "\r#{bar} #{percentage}% (#{status.progress.processed}/#{status.progress.total}) - #{status.performance.current_rate}/min"
        )

        monitor_import_progress()

      _ ->
        IO.write("\n")
    end
  end

  defp calculate_percentage(0, 0), do: 0.0
  defp calculate_percentage(processed, total), do: Float.round(processed / total * 100, 1)

  defp progress_bar(percentage) do
    filled = round(percentage / 2)
    empty = 50 - filled

    "[" <> String.duplicate("█", filled) <> String.duplicate("░", empty) <> "]"
  end

  defp format_duration(seconds) when seconds < 60, do: "#{seconds}s"

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
