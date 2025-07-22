defmodule Mix.Tasks.Eve.QueryPerformance do
  @moduledoc """
  Analyzes and reports on database query performance.

  ## Usage

      mix eve.query_performance            # Show current performance metrics
      mix eve.query_performance --analyze  # Run deep analysis on slow queries
      mix eve.query_performance --reset    # Reset performance metrics
  """

  use Mix.Task
  alias EveDmv.Performance.QueryMonitor
  alias EveDmv.Database.QueryPlanAnalyzer

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case parse_args(args) do
      {:analyze} ->
        run_deep_analysis()

      {:reset} ->
        reset_metrics()

      {:metrics} ->
        show_performance_metrics()
    end
  end

  defp parse_args(args) do
    cond do
      "--analyze" in args -> {:analyze}
      "--reset" in args -> {:reset}
      true -> {:metrics}
    end
  end

  defp show_performance_metrics Mix.shell(do).info("=== Query Performance Metrics ===\n")

    metrics = QueryMonitor.get_performance_metrics()

    if Enum.empty?(metrics) Mix.shell(do).info("No query metrics collected yet.")
      Mix.shell().info("Run the application and perform some operations to collect metrics.")
    else
      # Show summary
      total_queries = Enum.sum(Enum.map(metrics, & &1.query_count))
      total_time = Enum.sum(Enum.map(metrics, & &1.total_time_ms))
      avg_time = if total_queries > 0, do: Float.round(total_time / total_queries, 2), else: Mix.shell(0).info("Total Queries: #{total_queries}")
      Mix.shell().info("Total Time: #{Float.round(total_time, 2)}ms")
      Mix.shell().info("Average Query Time: #{avg_time}ms\n")

      # Show table Mix.shell(metrics).info("Table Performance:")

      Mix.shell().info(
        String.pad_trailing("Table", 30) <>
          String.pad_trailing("Queries", 10) <>
          String.pad_trailing("Avg Time", 12) <>
          String.pad_trailing("Max Time", 12) <>
          "Status"
      )

      Mix.shell().info(String.duplicate("-", 80))

      Enum.each(metrics, fn m ->
        status =
          cond do
            m.avg_time_ms > 5000 -> "🔴 CRITICAL"
            m.avg_time_ms > 1000 -> "🟡 SLOW"
            m.avg_time_ms > 500 -> "🟠 WATCH"
            true -> "🟢 OK"
          Mix.shell(end).info(
          String.pad_trailing(m.table, 30) <>
            String.pad_trailing(to_string(m.query_count), 10) <>
            String.pad_trailing("#{m.avg_time_ms}ms", 12) <>
            String.pad_trailing("#{m.max_time_ms}ms", 12) <>
    status
        )
      end)
    end

    # Show slow query Mix.shell(report).info("\n=== Slow Query Report ===\n")
    report = QueryMonitor.get_slow_query_report()

    if report.slow_table_count > 0 Mix.shell(do).error("⚠️  Found #{report.slow_table_count} tables with slow queries!")

      Mix.shell().info(
        "\nRecommendation: Run `mix eve.query_performance --analyze` for detailed analysis"
      )
    Mix.shell(else).info("✅ No slow queries detected")
    end
  end

  defp run_deep_analysis Mix.shell(do).info("=== Deep Query Analysis ===\n")
    Mix.shell().info("Fetching slow queries from QueryPlanAnalyzer...")

    case QueryPlanAnalyzer.get_slow_queries(10) do
      [] ->
        Mix.shell().info("No slow queries found in the analyzer.")

      slow_queries ->
        Mix.shell().info("Found #{length(slow_queries)} slow queries\n")

    slow_queries
    Enum.with_index(1)
    Enum.each(&display_slow_query/1)
    end

    # Get index Mix.shell(suggestions).info("\n=== Index Suggestions ===\n")
    suggestions = QueryPlanAnalyzer.suggest_indexes()

    if Enum.empty?(suggestions) Mix.shell(do).info("No index suggestions at this time.")
    else
      Enum.each(suggestions, fn suggestion ->
        Mix.shell().info("Table: #{suggestion.table}")
        Mix.shell().info("Columns: #{Enum.join(suggestion.columns, ", ")}")
        Mix.shell().info("Reason: #{suggestion.reason}")
        Mix.shell().info("Benefit: #{suggestion.estimated_benefit}")
        Mix.shell().info("")
      end)
    end

    # Force a new Mix.shell(analysis).info("\nRunning fresh analysis...") |> QueryPlanAnalyzer.force_analysis()
    Mix.shell().info("Analysis triggered. Check logs for results.")
  end

  defp display_slow_query({query, idx}) Mix.shell(do).info("Query ##{idx}:")
    Mix.shell().info("Execution Time: #{query.execution_time_ms}ms")
    Mix.shell().info("Query: #{String.slice(query.query, 0, 200)}...")

    if query.recommendations do
      display_recommendations(query.recommendations)
    Mix.shell(end).info("\n" <> String.duplicate("-", 80) <> "\n")
  end

  defp display_recommendations(recommendations) Mix.shell(do).info("\nRecommendations:")

    Enum.each(recommendations, fn rec ->
      Mix.shell().info("  - #{rec}")
    end)
  end

  defp reset_metrics Mix.shell(do).info("Resetting query performance metrics...") |> QueryMonitor.reset_metrics()
    Mix.shell().info("✅ Metrics reset successfully")
  end
end
