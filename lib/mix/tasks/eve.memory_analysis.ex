defmodule Mix.Tasks.Eve.MemoryAnalysis do
  @moduledoc """
  Analyzes memory usage patterns and identifies optimization opportunities.

  ## Usage

      mix eve.memory_analysis                    # Show current memory usage
      mix eve.memory_analysis --detailed         # Detailed analysis including processes and ETS
      mix eve.memory_analysis --profile <module> # Profile a specific module/function
      mix eve.memory_analysis --optimize         # Run memory optimization
      mix eve.memory_analysis --leak-detection   # Run memory leak detection
  """

  use Mix.Task
  alias EveDmv.Performance.MemoryProfiler

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case parse_args(args) do
      {:basic} ->
        show_basic_memory_info()

      {:detailed} ->
        show_detailed_analysis()

      {:profile, module_name} ->
        profile_module(module_name)

      {:optimize} ->
        run_memory_optimization()

      {:leak_detection} ->
        run_leak_detection()
    end
  end

  defp parse_args(args) do
    cond do
      "--detailed" in args ->
        {:detailed}

      "--optimize" in args ->
        {:optimize}

      "--leak-detection" in args ->
        {:leak_detection}

      Enum.any?(args, &String.starts_with?(&1, "--profile")) ->
        profile_arg = Enum.find(args, &String.starts_with?(&1, "--profile"))
        module_name = String.replace(profile_arg, "--profile=", "")
        {:profile, module_name}

      true ->
        {:basic}
    end
  end

  defp show_basic_memory_info do
    Mix.shell().info("=== Basic Memory Analysis ===\n")

    memory_info = MemoryProfiler.get_memory_info()

    Mix.shell().info("Current Memory Usage:")
    Mix.shell().info("  Total:        #{format_bytes(memory_info.total)}")

    Mix.shell().info(
      "  Processes:    #{format_bytes(memory_info.processes)} (#{percentage(memory_info.processes, memory_info.total)}%)"
    )

    Mix.shell().info(
      "  System:       #{format_bytes(memory_info.system)} (#{percentage(memory_info.system, memory_info.total)}%)"
    )

    Mix.shell().info(
      "  Atom:         #{format_bytes(memory_info.atom)} (#{percentage(memory_info.atom, memory_info.total)}%)"
    )

    Mix.shell().info(
      "  Binary:       #{format_bytes(memory_info.binary)} (#{percentage(memory_info.binary, memory_info.total)}%)"
    )

    Mix.shell().info(
      "  Code:         #{format_bytes(memory_info.code)} (#{percentage(memory_info.code, memory_info.total)}%)"
    )

    Mix.shell().info(
      "  ETS:          #{format_bytes(memory_info.ets)} (#{percentage(memory_info.ets, memory_info.total)}%)"
    )

    # Memory health assessment
    Mix.shell().info("\n=== Memory Health Assessment ===")
    assess_memory_health(memory_info)
  end

  defp show_detailed_analysis do
    Mix.shell().info("=== Detailed Memory Analysis ===\n")

    # Basic info first
    show_basic_memory_info()

    # ETS analysis
    Mix.shell().info("\n=== ETS Table Analysis ===")
    ets_analysis = MemoryProfiler.analyze_ets_tables()

    Mix.shell().info("Total ETS Memory: #{format_bytes(ets_analysis.total_memory)}")
    Mix.shell().info("Number of Tables: #{ets_analysis.table_count}")

    if ets_analysis.table_count > 0 do
      Mix.shell().info("\nTop 10 Tables by Memory:")

      ets_analysis.tables
      |> Enum.take(10)
      |> Enum.each(fn table ->
        Mix.shell().info(
          "  #{inspect(table.name)}: #{table.size} items, ~#{format_bytes(table.memory * 8)}"
        )
      end)
    end

    # Process analysis
    Mix.shell().info("\n=== Process Memory Analysis ===")
    process_analysis = MemoryProfiler.analyze_process_memory()

    Mix.shell().info("Total Process Memory: #{format_bytes(process_analysis.total_memory)}")
    Mix.shell().info("Number of Processes: #{process_analysis.process_count}")

    Mix.shell().info("\nTop 10 Processes by Memory:")

    process_analysis.top_processes
    |> Enum.each(fn proc ->
      name = proc.registered_name || "#{inspect(proc.pid)}"

      Mix.shell().info(
        "  #{name}: #{format_bytes(proc.memory)}, queue: #{proc.message_queue_len}"
      )
    end)
  end

  defp profile_module(module_name) do
    Mix.shell().info("=== Module Profiling: #{module_name} ===\n")

    try do
      # Try to find and profile a common function in the module
      module = Module.safe_concat([module_name])

      # Check if module exists
      if Code.ensure_loaded?(module) do
        Mix.shell().info("Module #{module_name} found. Looking for profileable functions...")

        # For demo, we'll profile a simple operation
        {_result, profile} =
          MemoryProfiler.profile_memory("#{module_name} operation", fn ->
            # Try to call a simple function if available
            if function_exported?(module, :__info__, 1) do
              module.__info__(:functions)
            else
              :no_functions_available
            end
          end)

        Mix.shell().info("Profile Results:")
        Mix.shell().info("  Execution Time: #{profile.execution_time_ms}ms")
        Mix.shell().info("  Memory Change:")
        Mix.shell().info("    Total: #{format_bytes(profile.memory_usage.total)}")
        Mix.shell().info("    Processes: #{format_bytes(profile.memory_usage.processes)}")
        Mix.shell().info("    Binary: #{format_bytes(profile.memory_usage.binary)}")
      else
        Mix.shell().error("Module #{module_name} not found")
      end
    rescue
      error ->
        Mix.shell().error("Error profiling module: #{inspect(error)}")
    end
  end

  defp run_memory_optimization do
    Mix.shell().info("=== Memory Optimization ===\n")

    Mix.shell().info("Running memory optimization...")
    result = MemoryProfiler.optimize_memory()

    if result.memory_freed > 0 do
      Mix.shell().info("✅ Memory optimization successful!")
      Mix.shell().info("Memory freed: #{format_bytes(result.memory_freed)}")
    else
      Mix.shell().info("ℹ️  No significant memory was freed")
    end

    Mix.shell().info("Before: #{format_bytes(result.initial_memory.total)}")
    Mix.shell().info("After:  #{format_bytes(result.final_memory.total)}")
  end

  defp run_leak_detection do
    Mix.shell().info("=== Memory Leak Detection ===\n")

    Mix.shell().info("Collecting memory samples over time...")
    Mix.shell().info("This will take several seconds...")

    # Collect samples over time
    samples =
      Enum.reduce(1..5, [], fn i, acc ->
        Mix.shell().info("Sample #{i}/5...")
        {new_samples, _indicators} = MemoryProfiler.detect_memory_leaks(acc)
        # Wait 2 seconds between samples
        Process.sleep(2000)
        new_samples
      end)

    # Final analysis
    {_final_samples, indicators} = MemoryProfiler.detect_memory_leaks(samples)

    if Map.get(indicators, :insufficient_data) do
      Mix.shell().info("Insufficient data for leak detection")
    else
      if indicators.upward_trend do
        Mix.shell().error("⚠️  Potential memory leak detected!")
        Mix.shell().error("Memory growth trend detected")
      else
        Mix.shell().info("✅ No memory leaks detected")
      end

      if indicators.total_growth > 0 do
        Mix.shell().info("Total memory growth: +#{format_bytes(indicators.total_growth)}")
      else
        Mix.shell().info("Total memory change: #{format_bytes(indicators.total_growth)}")
      end
    end
  end

  defp assess_memory_health(memory_info) do
    total_mb = memory_info.total / (1024 * 1024)
    process_percentage = percentage(memory_info.processes, memory_info.total)
    ets_percentage = percentage(memory_info.ets, memory_info.total)

    issues = []

    # Check for high memory usage
    issues =
      if total_mb > 1000 do
        ["High total memory usage (>1GB)" | issues]
      else
        issues
      end

    # Check for high process memory
    issues =
      if process_percentage > 70 do
        ["High process memory percentage (>70%)" | issues]
      else
        issues
      end

    # Check for high ETS usage
    issues =
      if ets_percentage > 30 do
        ["High ETS memory percentage (>30%)" | issues]
      else
        issues
      end

    if Enum.empty?(issues) do
      Mix.shell().info("✅ Memory usage appears healthy")
    else
      Mix.shell().error("⚠️  Memory health concerns:")

      Enum.each(issues, fn issue ->
        Mix.shell().error("  - #{issue}")
      end)
    end

    # Recommendations
    Mix.shell().info("\n=== Recommendations ===")

    if process_percentage > 60 do
      Mix.shell().info(
        "• Consider running garbage collection: mix eve.memory_analysis --optimize"
      )
    end

    if ets_percentage > 20 do
      Mix.shell().info("• Review ETS table usage with: mix eve.memory_analysis --detailed")
    end

    if total_mb > 500 do
      Mix.shell().info(
        "• Monitor for memory leaks with: mix eve.memory_analysis --leak-detection"
      )
    end
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 2)}KB"

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024,
    do: "#{Float.round(bytes / (1024 * 1024), 2)}MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 2)}GB"

  defp percentage(part, total) when total > 0, do: Float.round(part / total * 100, 1)
  defp percentage(_, _), do: 0.0
end
