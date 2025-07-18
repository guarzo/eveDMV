defmodule Mix.Tasks.Eve.AnalyzePerformance do
  @moduledoc """
  Mix task to analyze database performance and provide optimization recommendations.
  """

  @shortdoc "Analyze database performance and provide optimization recommendations"

  use Mix.Task

  alias EveDmv.Database.PerformanceOptimizer

  @impl Mix.Task
  def run(_args) do
    # Start the application to access Repo
    Mix.Task.run("app.start")

    Mix.shell().info("🔍 Starting EVE DMV database performance analysis...")

    # Run performance analysis
    Mix.shell().info("📈 Analyzing performance...")
    {:ok, analysis} = PerformanceOptimizer.analyze_performance()

    # Get connection stats
    {:ok, connection_stats} = PerformanceOptimizer.get_connection_stats()

    # Output results
    output_text(analysis, connection_stats)

    Mix.shell().info("✅ Performance analysis complete!")
  end

  defp output_text(analysis, connection_stats) do
    # Database Connection Stats
    Mix.shell().info("\n📊 Database Connection Statistics")
    Mix.shell().info("=" <> String.duplicate("=", 40))
    Mix.shell().info("Active Connections: #{connection_stats["active_connections"]}")
    Mix.shell().info("Total Connections: #{connection_stats["total_connections"]}")
    Mix.shell().info("Database Size: #{connection_stats["database_size"]}")
    Mix.shell().info("Cache Hit Ratio: #{connection_stats["cache_hit_ratio"]}%")

    # Slow Queries
    if analysis.slow_queries != [] do
      Mix.shell().info("\n🐌 Slow Queries (>1 second)")
      Mix.shell().info("=" <> String.duplicate("=", 40))

      Enum.each(analysis.slow_queries, fn query ->
        query_text =
          case query.query do
            query_str when is_binary(query_str) ->
              String.slice(query_str, 0, 100) <> "..."

            _ ->
              "Query text unavailable"
          end

        Mix.shell().info("Query: #{query_text}")
        Mix.shell().info("  Average: #{Float.round(query.mean_time_seconds, 3)}s")
        Mix.shell().info("  Total: #{Float.round(query.total_time_seconds, 3)}s")
        Mix.shell().info("")
      end)
    else
      Mix.shell().info("\n✅ No slow queries detected")
    end

    # Recommendations
    Mix.shell().info("\n💡 Recommendations")
    Mix.shell().info("=" <> String.duplicate("=", 40))

    Enum.each(analysis.recommendations, fn rec ->
      Mix.shell().info("• #{rec}")
    end)
  end
end
