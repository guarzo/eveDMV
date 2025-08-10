defmodule EveDmv.MemoryMonitor do
  @moduledoc """
  Simple memory monitoring GenServer that logs warnings when memory usage is high.
  """

  use GenServer
  require Logger

  # Check memory every 5 minutes
  @check_interval 5 * 60 * 1000
  # Warn if memory usage exceeds 1GB
  @memory_warning_threshold 1024 * 1024 * 1024

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    # Schedule first check
    Process.send_after(self(), :check_memory, @check_interval)
    {:ok, nil}
  end

  def handle_info(:check_memory, state) do
    check_and_log_memory()

    # Schedule next check
    Process.send_after(self(), :check_memory, @check_interval)
    {:noreply, state}
  end

  @doc """
  Get current memory usage information.
  """
  def get_memory_info do
    memory = :erlang.memory()

    %{
      total_mb: memory[:total] / 1024 / 1024,
      processes_mb: memory[:processes] / 1024 / 1024,
      system_mb: memory[:system] / 1024 / 1024,
      ets_mb: memory[:ets] / 1024 / 1024,
      binary_mb: memory[:binary] / 1024 / 1024
    }
  end

  defp check_and_log_memory do
    memory = :erlang.memory()
    total_memory = memory[:total]
    total_mb = total_memory / 1024 / 1024

    # Log warning if memory usage is high
    if total_memory > @memory_warning_threshold do
      Logger.warning("""
      High memory usage detected: #{round(total_mb)} MB
      Breakdown:
        - Processes: #{round(memory[:processes] / 1024 / 1024)} MB
        - System: #{round(memory[:system] / 1024 / 1024)} MB
        - ETS: #{round(memory[:ets] / 1024 / 1024)} MB
        - Binary: #{round(memory[:binary] / 1024 / 1024)} MB
      """)

      # Store for monitoring
      store_memory_sample(total_mb, memory)
    end

    # Log info every hour (12 checks * 5 minutes = 60 minutes)
    if rem(:erlang.monotonic_time(:second), 3600) < 300 do
      Logger.info("Memory usage: #{round(total_mb)} MB")
    end
  end

  defp store_memory_sample(total_mb, memory_breakdown) do
    # Store in simple ETS for recent history
    ensure_memory_table()

    entry = {
      :os.system_time(:second),
      round(total_mb),
      %{
        processes: round(memory_breakdown[:processes] / 1024 / 1024),
        system: round(memory_breakdown[:system] / 1024 / 1024),
        ets: round(memory_breakdown[:ets] / 1024 / 1024),
        binary: round(memory_breakdown[:binary] / 1024 / 1024)
      }
    }

    :ets.insert(:memory_samples, entry)

    # Keep only last 24 samples (2 hours of data)
    case :ets.info(:memory_samples, :size) do
      size when size > 24 ->
        cleanup_memory_samples()

      _ ->
        :ok
    end
  end

  @doc """
  Get recent memory samples for debugging.
  """
  def get_recent_samples(limit \\ 12) do
    :ets.tab2list(:memory_samples)
    |> Enum.sort_by(fn {timestamp, _, _} -> timestamp end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {timestamp, total_mb, breakdown} ->
      %{
        timestamp: DateTime.from_unix!(timestamp),
        total_mb: total_mb,
        breakdown: breakdown
      }
    end)
  rescue
    _ -> []
  end

  defp ensure_memory_table do
    case :ets.whereis(:memory_samples) do
      :undefined ->
        :ets.new(:memory_samples, [
          :named_table,
          :public,
          :bag,
          {:read_concurrency, true}
        ])

      _ ->
        :ok
    end
  rescue
    ArgumentError ->
      :ok
  end

  defp cleanup_memory_samples do
    samples =
      :ets.tab2list(:memory_samples)
      |> Enum.sort_by(fn {timestamp, _, _} -> timestamp end, :desc)

    :ets.delete_all_objects(:memory_samples)

    samples
    |> Enum.take(12)
    |> Enum.each(&:ets.insert(:memory_samples, &1))
  rescue
    _ -> :ok
  end
end
