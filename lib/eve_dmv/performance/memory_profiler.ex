defmodule EveDmv.Performance.MemoryProfiler do
  @moduledoc """
  Memory profiling and optimization utilities for EVE DMV.

  Provides tools to analyze memory usage patterns, identify memory leaks,
  and optimize memory consumption across the application.
  """

  require Logger

  @doc """
  Profiles memory usage of a given function.
  Returns the result along with memory usage statistics.
  """
  def profile_memory(description \\ "operation", fun) when is_function(fun) do
    # Force garbage collection before measurement
    :erlang.garbage_collect()

    # Get initial memory usage
    initial_memory = get_memory_info()

    # Execute the function
    start_time = System.monotonic_time(:millisecond)
    result = fun.()
    end_time = System.monotonic_time(:millisecond)

    # Force garbage collection after execution
    :erlang.garbage_collect()

    # Get final memory usage
    final_memory = get_memory_info()

    # Calculate differences
    memory_diff = calculate_memory_diff(initial_memory, final_memory)
    execution_time = end_time - start_time

    Logger.info("""
    Memory Profile - #{description}:
    Execution Time: #{execution_time}ms
    Memory Usage:
      - Total: #{format_bytes(memory_diff.total)} 
      - Processes: #{format_bytes(memory_diff.processes)}
      - Atom: #{format_bytes(memory_diff.atom)}
      - Binary: #{format_bytes(memory_diff.binary)}
      - Code: #{format_bytes(memory_diff.code)}
      - ETS: #{format_bytes(memory_diff.ets)}
    """)

    {result,
     %{
       execution_time_ms: execution_time,
       memory_usage: memory_diff,
       initial_memory: initial_memory,
       final_memory: final_memory
     }}
  end

  @doc """
  Gets current memory usage information.
  """
  def get_memory_info do
    memory = :erlang.memory()

    %{
      total: Keyword.get(memory, :total, 0),
      processes: Keyword.get(memory, :processes, 0),
      processes_used: Keyword.get(memory, :processes_used, 0),
      system: Keyword.get(memory, :system, 0),
      atom: Keyword.get(memory, :atom, 0),
      atom_used: Keyword.get(memory, :atom_used, 0),
      binary: Keyword.get(memory, :binary, 0),
      code: Keyword.get(memory, :code, 0),
      ets: Keyword.get(memory, :ets, 0)
    }
  end

  @doc """
  Analyzes ETS table memory usage.
  """
  def analyze_ets_tables do
    tables = :ets.all()

    table_info =
      tables
      |> Enum.map(fn table ->
        try do
          info = :ets.info(table)

          %{
            name: info[:name] || table,
            size: info[:size] || 0,
            memory: info[:memory] || 0,
            type: info[:type] || :unknown,
            owner: info[:owner] || :unknown
          }
        rescue
          _ ->
            %{
              name: table,
              size: 0,
              memory: 0,
              type: :unknown,
              owner: :unknown
            }
        end
      end)
      |> Enum.sort_by(& &1.memory, :desc)

    total_ets_memory = Enum.sum(Enum.map(table_info, & &1.memory))

    Logger.info("""
    ETS Table Analysis:
    Total ETS Memory: #{format_bytes(total_ets_memory * 8)} (approx)
    Number of Tables: #{length(table_info)}

    Top 10 Tables by Memory:
    #{format_ets_table_list(Enum.take(table_info, 10))}
    """)

    %{
      total_memory: total_ets_memory,
      table_count: length(table_info),
      tables: table_info
    }
  end

  @doc """
  Analyzes process memory usage.
  """
  def analyze_process_memory do
    processes = Process.list()

    process_info =
      processes
      |> Enum.map(fn pid ->
        try do
          info = Process.info(pid, [:memory, :message_queue_len, :registered_name, :initial_call])

          %{
            pid: pid,
            memory: info[:memory] || 0,
            message_queue_len: info[:message_queue_len] || 0,
            registered_name: info[:registered_name],
            initial_call: info[:initial_call]
          }
        rescue
          _ ->
            %{
              pid: pid,
              memory: 0,
              message_queue_len: 0,
              registered_name: nil,
              initial_call: nil
            }
        end
      end)
      |> Enum.sort_by(& &1.memory, :desc)

    total_process_memory = Enum.sum(Enum.map(process_info, & &1.memory))

    top_processes = Enum.take(process_info, 10)

    Logger.info("""
    Process Memory Analysis:
    Total Process Memory: #{format_bytes(total_process_memory)}
    Number of Processes: #{length(process_info)}

    Top 10 Processes by Memory:
    #{format_process_list(top_processes)}
    """)

    %{
      total_memory: total_process_memory,
      process_count: length(process_info),
      processes: process_info,
      top_processes: top_processes
    }
  end

  @doc """
  Detects potential memory leaks by comparing memory usage over time.
  """
  def detect_memory_leaks(samples \\ []) do
    current_memory = get_memory_info()
    # Keep last 10 samples
    new_samples = [current_memory | Enum.take(samples, 9)]

    if length(new_samples) >= 3 do
      # Analyze trend in total memory usage
      memory_values = Enum.map(new_samples, & &1.total)

      # Calculate trend (simple linear regression)
      trend = calculate_memory_trend(memory_values)

      # Check for concerning patterns
      leak_indicators = %{
        # More than 1MB growth per sample
        upward_trend: trend > 1_000_000,
        # High variance
        high_variance: calculate_variance(memory_values) > 10_000_000,
        total_growth: List.first(memory_values) - List.last(memory_values)
      }

      if leak_indicators.upward_trend do
        Logger.warning("""
        Potential Memory Leak Detected:
        Trend: +#{format_bytes(trend)} per sample
        Total Growth: #{format_bytes(leak_indicators.total_growth)}
        High Variance: #{leak_indicators.high_variance}
        """)
      end

      {new_samples, leak_indicators}
    else
      {new_samples, %{insufficient_data: true}}
    end
  end

  @doc """
  Optimizes memory usage by running garbage collection and cleanup.
  """
  def optimize_memory do
    initial_memory = get_memory_info()

    # Force garbage collection on all processes
    :erlang.garbage_collect()

    # Run garbage collection on all processes
    processes = Process.list()

    Enum.each(processes, fn pid ->
      try do
        :erlang.garbage_collect(pid)
      rescue
        _ -> :ok
      end
    end)

    # Clean up unused atoms (if possible)
    # Note: Atom cleanup is not directly available in Erlang

    # Clean up old ETS tables that might be orphaned
    cleanup_orphaned_ets_tables()

    final_memory = get_memory_info()
    memory_freed = initial_memory.total - final_memory.total

    Logger.info("""
    Memory Optimization Complete:
    Memory Freed: #{format_bytes(memory_freed)}
    Before: #{format_bytes(initial_memory.total)}
    After: #{format_bytes(final_memory.total)}
    """)

    %{
      memory_freed: memory_freed,
      initial_memory: initial_memory,
      final_memory: final_memory
    }
  end

  # Private functions

  defp calculate_memory_diff(initial, final) do
    %{
      total: final.total - initial.total,
      processes: final.processes - initial.processes,
      atom: final.atom - initial.atom,
      binary: final.binary - initial.binary,
      code: final.code - initial.code,
      ets: final.ets - initial.ets
    }
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 2)}KB"

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024,
    do: "#{Float.round(bytes / (1024 * 1024), 2)}MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 2)}GB"

  defp format_ets_table_list(tables) do
    tables
    |> Enum.map_join("\n", fn table ->
      "  #{inspect(table.name)}: #{table.size} items, ~#{format_bytes(table.memory * 8)}"
    end)
  end

  defp format_process_list(processes) do
    processes
    |> Enum.map_join("\n", fn proc ->
      name = proc.registered_name || "#{inspect(proc.pid)}"
      "  #{name}: #{format_bytes(proc.memory)}, queue: #{proc.message_queue_len}"
    end)
  end

  defp calculate_memory_trend(values) do
    # Simple trend calculation (difference between first and last / count)
    if length(values) >= 2 do
      first = List.first(values)
      last = List.last(values)
      (first - last) / length(values)
    else
      0
    end
  end

  defp calculate_variance(values) do
    if length(values) >= 2 do
      mean = Enum.sum(values) / length(values)
      variance_sum = values |> Enum.map(&:math.pow(&1 - mean, 2)) |> Enum.sum()
      variance_sum / length(values)
    else
      0
    end
  end

  defp cleanup_orphaned_ets_tables do
    # Get all ETS tables
    tables = :ets.all()

    orphaned_count =
      Enum.reduce(tables, 0, fn table, acc ->
        try do
          info = :ets.info(table)
          owner = info[:owner]

          # Check if owner process is still alive
          if owner && not Process.alive?(owner) do
            # This table is orphaned, but we can't delete it as we're not the owner
            # Just count it for reporting
            acc + 1
          else
            acc
          end
        rescue
          _ -> acc
        end
      end)

    if orphaned_count > 0 do
      Logger.info("Found #{orphaned_count} potentially orphaned ETS tables")
    end

    orphaned_count
  end
end
