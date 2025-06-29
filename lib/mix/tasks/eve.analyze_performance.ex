defmodule Mix.Tasks.Eve.AnalyzePerformance do
  @moduledoc """
  Mix task to analyze database performance and provide optimization recommendations.

  ## Usage

      mix eve.analyze_performance [options]

  ## Options

    * --vacuum - Run VACUUM ANALYZE on tables before analysis
    * --full-vacuum - Run VACUUM FULL ANALYZE (requires exclusive lock)
    * --update-stats - Update database statistics before analysis
    * --format - Output format: text (default), json

  ## Examples

      # Basic performance analysis
      mix eve.analyze_performance

      # Full analysis with vacuum
      mix eve.analyze_performance --vacuum --update-stats

      # JSON output for programmatic use
      mix eve.analyze_performance --format json
  """

  use Mix.Task

  alias EveDmv.Database.PerformanceOptimizer
  alias EveDmv.Repo

  @shortdoc "Analyze database performance and provide optimization recommendations"

  @impl Mix.Task
  def run(args) do
    # Start the application to access Repo
    Mix.Task.run("app.start")

    # Parse arguments
    {opts, _args, _invalid} = OptionParser.parse(args, 
      switches: [
        vacuum: :boolean,
        full_vacuum: :boolean, 
        update_stats: :boolean,
        format: :string
      ]
    )

    format = Keyword.get(opts, :format, "text")

    Mix.shell().info("🔍 Starting EVE DMV database performance analysis...")

    # Pre-analysis maintenance if requested
    if Keyword.get(opts, :update_stats, false) do
      Mix.shell().info("📊 Updating database statistics...")
      PerformanceOptimizer.update_statistics()
    end

    if Keyword.get(opts, :full_vacuum, false) do
      Mix.shell().info("🧹 Running VACUUM FULL ANALYZE (this may take a while)...")
      PerformanceOptimizer.vacuum_tables(full: true)
    elsif Keyword.get(opts, :vacuum, false) do
      Mix.shell().info("🧹 Running VACUUM ANALYZE...")
      PerformanceOptimizer.vacuum_tables()
    end

    # Run performance analysis
    Mix.shell().info("📈 Analyzing performance...")
    analysis = PerformanceOptimizer.analyze_performance()

    # Get connection stats
    connection_stats = PerformanceOptimizer.get_connection_stats()

    # Output results
    case format do
      "json" -> output_json(analysis, connection_stats)
      _ -> output_text(analysis, connection_stats)
    end

    Mix.shell().info("✅ Performance analysis complete!")
  end

  defp output_text(analysis, connection_stats) do
    # Database Connection Stats
    Mix.shell().info("\n📊 Database Connection Statistics")
    Mix.shell().info("=" <> String.duplicate("=", 40))
    Mix.shell().info("Active Connections: #{connection_stats["active_connections"]}")
    Mix.shell().info("Idle Connections: #{connection_stats["idle_connections"]}")
    Mix.shell().info("Total Connections: #{connection_stats["total_connections"]}")
    Mix.shell().info("Database Size: #{connection_stats["database_size"]}")
    Mix.shell().info("Cache Hit Ratio: #{connection_stats["cache_hit_ratio"]}%")

    # Slow Queries
    if length(analysis.slow_queries) > 0 do
      Mix.shell().info("\n🐌 Slow Queries (>1 second)")
      Mix.shell().info("=" <> String.duplicate("=", 40))
      
      Enum.each(analysis.slow_queries, fn query ->
        Mix.shell().info("Query: #{String.slice(query.query, 0, 100)}...")
        Mix.shell().info("  Calls: #{query.calls}")
        Mix.shell().info("  Average: #{Float.round(query.mean_time_seconds, 3)}s")
        Mix.shell().info("  Total: #{Float.round(query.total_time_seconds, 3)}s (#{Float.round(query.percentage, 1)}%)")
        Mix.shell().info("")
      end)
    else
      Mix.shell().info("\n✅ No slow queries detected")
    end

    # Index Usage
    unused_indexes = Enum.filter(analysis.index_usage, fn idx -> 
      (idx.number_of_scans || 0) < 10 and idx.index_name != nil
    end)

    if length(unused_indexes) > 0 do
      Mix.shell().info("\n📇 Potentially Unused Indexes")
      Mix.shell().info("=" <> String.duplicate("=", 40))
      
      Enum.each(unused_indexes, fn idx ->
        Mix.shell().info("#{idx.table_name}.#{idx.index_name} - #{idx.number_of_scans || 0} scans")
      end)
    else
      Mix.shell().info("\n✅ All indexes appear to be in use")
    end

    # Recommendations
    Mix.shell().info("\n💡 Recommendations")
    Mix.shell().info("=" <> String.duplicate("=", 40))
    
    Enum.each(analysis.recommendations, fn rec ->
      Mix.shell().info("• #{rec}")
    end)
  end

  defp output_json(analysis, connection_stats) do
    output = %{
      connection_stats: connection_stats,
      analysis: analysis
    }

    Mix.shell().info(Jason.encode!(output, pretty: true))
  end
end