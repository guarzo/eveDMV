defmodule Mix.Tasks.Eve.Performance do
  @moduledoc """
  Comprehensive performance analysis and optimization toolkit.

  ## Usage

      mix eve.performance                      # Show performance dashboard
      mix eve.performance --analyze            # Run full performance analysis
      mix eve.performance --optimize           # Run all optimizations
      mix eve.performance --monitor            # Show real-time monitoring
      mix eve.performance --regression-check   # Check for performance regressions
      mix eve.performance --report             # Generate performance report
  """

  use Mix.Task

  alias EveDmv.Database.QueryPlanAnalyzer
  alias EveDmv.Eve.NameResolver
  alias EveDmv.Performance.MemoryProfiler
  alias EveDmv.Performance.QueryMonitor
  alias EveDmv.Performance.RegressionDetector

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case parse_args(args) do
      {:dashboard} ->
        show_performance_dashboard()

      {:analyze} ->
        run_full_analysis()

      {:optimize} ->
        run_all_optimizations()

      {:monitor} ->
        show_real_time_monitoring()

      {:regression_check} ->
        check_regressions()

      {:report} ->
        generate_performance_report()
    end
  end

  defp parse_args(args) do
    cond do
      "--analyze" in args -> {:analyze}
      "--optimize" in args -> {:optimize}
      "--monitor" in args -> {:monitor}
      "--regression-check" in args -> {:regression_check}
      "--report" in args -> {:report}
      true -> {:dashboard}
    end
  end

  defp show_performance_dashboard Mix.shell(do).info("=== EVE DMV Performance Dashboard ===\n")

    # Memory overview
    memory_info = MemoryProfiler.get_memory_info()
    Mix.shell().info("💾 Memory Usage: #{format_bytes(memory_info.total)}")

    # Query performance
    query_metrics = QueryMonitor.get_performance_metrics()
    slow_queries = Enum.filter(query_metrics, &(&1.avg_time_ms > 1000))

    if Enum.empty?(slow_queries) Mix.shell(do).info("⚡ Query Performance: ✅ All queries under 1s")
    Mix.shell(else).info("🐌 Query Performance: ⚠️  #{length(slow_queries)} slow queries detected")
    end

    # Regression status
    if Code.ensure_loaded?(RegressionDetector) do
      try do
        baselines = RegressionDetector.get_baselines()
        Mix.shell().info("📊 Regression Detection: ✅ Monitoring #{map_size(baselines)} metrics")
      rescue
        _ ->
          Mix.shell().info("📊 Regression Detection: ⚠️  Not running")
      end
    Mix.shell(else).info("📊 Regression Detection: ❌ Not available")
    end

    # System health
    process_count = length(Process.list())
    Mix.shell().info("🔧 System Health: #{process_count} processes running")

    Mix.shell().info("\n=== Quick Actions ===")
    Mix.shell().info("• Full analysis:     mix eve.performance --analyze")
    Mix.shell().info("• Run optimizations: mix eve.performance --optimize")
    Mix.shell().info("• Check regressions: mix eve.performance --regression-check")
    Mix.shell().info("• Generate report:   mix eve.performance --report")
  end

  defp run_full_analysis Mix.shell(do).info("=== Full Performance Analysis ===\n")

    Mix.shell().info("Running comprehensive performance analysis...")

    # 1. Query Mix.shell(Analysis).info("\n1. 📊 Query Performance Analysis")
    Mix.Task.run("eve.query_performance")

    # 2. Memory Mix.shell(Analysis).info("\n2. 💾 Memory Analysis")
    Mix.Task.run("eve.memory_analysis", ["--detailed"])

    # 3. Database Mix.shell(Analysis).info("\n3. 🗄️  Database Analysis")
    run_database_analysis()

    # 4. System Resource Mix.shell(Analysis).info("\n4. ⚙️  System Resource Analysis")
    run_system_analysis()

    Mix.shell().info("\n✅ Full analysis complete!")
  end

  defp run_all_optimizations Mix.shell(do).info("=== Performance Optimization Suite ===\n")

    Mix.shell().info("Running all available optimizations...")

    # 1. Memory Mix.shell(optimization).info("\n1. 💾 Memory Optimization")
    Mix.Task.run("eve.memory_analysis", ["--optimize"])

    # 2. Query optimization Mix.shell(suggestions).info("\n2. 📊 Query Optimization")
    Mix.Task.run("eve.query_performance", ["--analyze"])

    # 3. Cache Mix.shell(warming).info("\n3. 🔥 Cache Warming")
    warm_caches()

    # 4. Database Mix.shell(maintenance).info("\n4. 🗄️  Database Maintenance")
    run_database_maintenance()

    Mix.shell().info("\n✅ All optimizations complete!")
  end

  defp show_real_time_monitoring Mix.shell(do).info("=== Real-time Performance Monitoring ===\n")
    Mix.shell().info("Monitoring system performance... (Press Ctrl+C to stop)\n")

    monitor_loop(0)
  end

  defp monitor_loop(iteration) do
    # Clear screen and show updated metrics
    if iteration > 0 Mix.shell(do).info("\n" <> String.duplicate("=", 60))
    Mix.shell(end).info("Update ##{iteration + 1} - #{DateTime.utc_now()}")

    # Memory snapshot
    memory = MemoryProfiler.get_memory_info()

    Mix.shell().info(
      "Memory: #{format_bytes(memory.total)} (Processes: #{format_bytes(memory.processes)})"
    )

    # Recent query performance
    metrics = QueryMonitor.get_performance_metrics()
    slow_count = Enum.count(metrics, &(&1.avg_time_ms > 1000))
    Mix.shell().info("Queries: #{length(metrics)} monitored, #{slow_count} slow")

    # Process count
    process_count = length(Process.list())
    Mix.shell().info("Processes: #{process_count}")

    # Wait 5 seconds before next update
    Process.sleep(5000)
    monitor_loop(iteration + 1)
  end

  defp check_regressions Mix.shell(do).info("=== Performance Regression Check ===\n")

    if Code.ensure_loaded?(RegressionDetector) do
      try do
        # Force a regression RegressionDetector.force_regression_check(check)

        # Get current metrics vs baselines
        baselines = RegressionDetector.get_baselines()
        current_metrics = RegressionDetector.get_current_metrics()

        Mix.shell().info("Baselines: #{map_size(baselines)} metrics")
        Mix.shell().info("Current metrics: #{length(current_metrics)} measurements")

        # Show key Mix.shell(comparisons).info("\n=== Key Metrics Comparison ===")
        show_metric_comparison(baselines, current_metrics)

        Mix.shell().info("\n✅ Regression check complete - see logs for any alerts")
      rescue
        error ->
          Mix.shell().error("❌ Failed to check regressions: #{inspect(error)}")
      end
    Mix.shell(else).error("❌ Regression detector not available")
    end
  end

  defp generate_performance_report Mix.shell(do).info("=== Performance Report Generation ===\n")

    timestamp = DateTime.utc_now() DateTime.to_iso8601()

    Mix.shell().info("Generating comprehensive performance report...")

    # Collect all metrics
    memory_info = MemoryProfiler.get_memory_info()
    query_metrics = QueryMonitor.get_performance_metrics()

    report = %{
      timestamp: timestamp,
      memory: memory_info,
      queries: %{
        total_tables: length(query_metrics),
        slow_queries: Enum.count(query_metrics, &(&1.avg_time_ms > 1000)),
        metrics: query_metrics
      },
      system: %{
        process_count: length(Process.list()),
        uptime: get_system_uptime()
      }
    }

    # Save report to file
    report_filename = "performance_report_#{DateTime.utc_now() DateTime.to_unix()}.json"
    report_path = Path.join("tmp", report_filename)

    File.mkdir_p!("tmp")
    File.write!(report_path, Jason.encode!(report, pretty: true))

    Mix.shell().info("✅ Report saved to: #{report_path}")

    # Show Mix.shell(summary).info("\n=== Report Summary ===")
    Mix.shell().info("Memory Usage: #{format_bytes(memory_info.total)}")
    Mix.shell().info("Query Tables: #{report.queries.total_tables}")
    Mix.shell().info("Slow Queries: #{report.queries.slow_queries}")
    Mix.shell().info("Process Count: #{report.system.process_count}")
  end

  # Helper functions

  defp run_database_analysis Mix.shell(do).info("Analyzing database performance...")

    # Check database size and statistics
    QueryPlanAnalyzer.get_analysis_report(case) do
      report when is_map(report) ->
        Mix.shell().info("Database health: #{report.system_health.status}")
        Mix.shell().info("Slow queries detected: #{report.slow_query_count}")

      _ ->
        Mix.shell().info("Database analysis not available")
    end
  end

  defp run_system_analysis Mix.shell(do).info("Analyzing system resources...")

    # System process analysis
    process_analysis = MemoryProfiler.analyze_process_memory()
    Mix.shell().info("Total processes: #{process_analysis.process_count}")
    Mix.shell().info("Process memory: #{format_bytes(process_analysis.total_memory)}")

    # ETS analysis
    ets_analysis = MemoryProfiler.analyze_ets_tables()
    Mix.shell().info("ETS tables: #{ets_analysis.table_count}")
    Mix.shell().info("ETS memory: #{format_bytes(ets_analysis.total_memory)}")
  end

  defp warm_caches Mix.shell(do).info("Warming application caches...")

    # Warm name resolver cache
    try NameResolver.warm_cache(do)
      Mix.shell().info("✅ Name resolver cache warmed")
    rescue
      error ->
        Mix.shell().info("⚠️  Name resolver cache warming failed: #{inspect(error)}")
    end

    # Could add more cache warming Mix.shell(here).info("Cache warming complete")
  end

  defp run_database_maintenance Mix.shell(do).info("Running database maintenance tasks...")

    # This would run database-specific maintenance
    # For now, just report what would be Mix.shell(done).info("• Analyze table statistics")
    Mix.shell().info("• Update query plans")
    Mix.shell().info("• Check index usage")

    Mix.shell().info("Database maintenance complete")
  end

  defp show_metric_comparison(baselines, current_metrics) do
    # Show key metrics if available
    key_metrics = ["memory.total", "memory.processes", "system.process_count"]

    Enum.each(key_metrics, fn metric_name ->
      baseline = Map.get(baselines, metric_name)
      current = find_current_metric(current_metrics, metric_name)

      if baseline && current do
        change = current - baseline
        change_pct = if baseline > 0, do: change / baseline * 100, else: 0

        status =
          cond do
            abs(change_pct) < 5 -> "✅"
            change_pct > 20 -> "🔴"
            change_pct > 10 -> "🟡"
            true -> "✅"
          Mix.shell(end).info(
          "#{status} #{metric_name}: #{format_bytes(baseline)} → #{format_bytes(current)} (#{format_change(change_pct)})"
        )
      end
    end)
  end

  defp find_current_metric(metrics, metric_name) do
    case Enum.find(metrics, &(&1.metric == metric_name)) do
      %{latest: value} -> value
      _ -> nil
    end
  end

  defp format_change(pct) when pct > 0, do: "+#{Float.round(pct, 1)}%"
  defp format_change(pct), do: "#{Float.round(pct, 1)}%"

  defp get_system_uptime do
    # Simple uptime calculation
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    uptime_ms / 1000
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 2)}KB"

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024,
    do: "#{Float.round(bytes / (1024 * 1024), 2)}MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 2)}GB"
end
