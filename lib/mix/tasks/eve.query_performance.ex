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

  defp show_performance_metrics do
    Mix.shell().info("=== Query Performance Metrics ===\n")

    metrics = QueryMonitor.get_performance_metrics()

    if Enum.empty?(metrics) do
      Mix.shell().info("No query metrics collected yet.")
      Mix.shell().info("Run the application and perform some operations to collect metrics.")
    else
      # Show summary
      total_queries = Enum.sum(Enum.map(metrics, & &1.query_count))
      total_time = Enum.sum(Enum.map(metrics, & &1.total_time_ms))
      avg_time = if total_queries > 0, do: Float.round(total_time / total_queries, 2), else: 0

      Mix.shell().info("Total Queries: #{total_queries}")
      Mix.shell().info("Total Time: #{Float.round(total_time, 2)}ms")
      Mix.shell().info("Average Query Time: #{avg_time}ms\n")

      # Show table metrics
      Mix.shell().info("Table Performance:")

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
          end

        Mix.shell().info(
          String.pad_trailing(m.table, 30) <>
            String.pad_trailing(to_string(m.query_count), 10) <>
            String.pad_trailing("#{m.avg_time_ms}ms", 12) <>
            String.pad_trailing("#{m.max_time_ms}ms", 12) <>
            status
        )
      end)
    end

    # Show slow query report
    Mix.shell().info("\n=== Slow Query Report ===\n")
    report = QueryMonitor.get_slow_query_report()

    if report.slow_table_count > 0 do
      Mix.shell().error("⚠️  Found #{report.slow_table_count} tables with slow queries!")

      Mix.shell().info(
        "\nRecommendation: Run `mix eve.query_performance --analyze` for detailed analysis"
      )
    else
      Mix.shell().info("✅ No slow queries detected")
    end
  end

  defp run_deep_analysis do
    Mix.shell().info("=== Deep Query Analysis ===\n")
    Mix.shell().info("Fetching slow queries from QueryPlanAnalyzer...")

    case QueryPlanAnalyzer.get_slow_queries(10) do
      [] ->
        Mix.shell().info("No slow queries found in the analyzer.")

      slow_queries ->
        Mix.shell().info("Found #{length(slow_queries)} slow queries\n")

        slow_queries
        |> Enum.with_index(1)
        |> Enum.each(fn {query, idx} ->
          Mix.shell().info("Query ##{idx}:")
          Mix.shell().info("Execution Time: #{query.execution_time_ms}ms")
          Mix.shell().info("Query: #{String.slice(query.query, 0, 200)}...")

          if query.recommendations do
            Mix.shell().info("\nRecommendations:")

            Enum.each(query.recommendations, fn rec ->
              Mix.shell().info("  - #{rec}")
            end)
          end

          Mix.shell().info("\n" <> String.duplicate("-", 80) <> "\n")
        end)
    end

    # Get index suggestions
    Mix.shell().info("\n=== Index Suggestions ===\n")
    suggestions = QueryPlanAnalyzer.suggest_indexes()

    if Enum.empty?(suggestions) do
      Mix.shell().info("No index suggestions at this time.")
    else
      Enum.each(suggestions, fn suggestion ->
        Mix.shell().info("Table: #{suggestion.table}")
        Mix.shell().info("Columns: #{Enum.join(suggestion.columns, ", ")}")
        Mix.shell().info("Reason: #{suggestion.reason}")
        Mix.shell().info("Benefit: #{suggestion.estimated_benefit}")
        Mix.shell().info("")
      end)
    end

    # Force a new analysis
    Mix.shell().info("\nRunning fresh analysis...")
    QueryPlanAnalyzer.force_analysis()
    Mix.shell().info("Analysis triggered. Check logs for results.")
  end

  defp reset_metrics do
    Mix.shell().info("Resetting query performance metrics...")
    QueryMonitor.reset_metrics()
    Mix.shell().info("✅ Metrics reset successfully")
  end
end
