defmodule EveDmv.Database.PerformanceOptimizer do
  @moduledoc """
  Database performance optimization utilities for EVE DMV.

  This module provides functions to:
  1. Monitor and optimize query performance
  2. Manage database statistics and vacuum operations
  3. Provide query performance insights
  4. Suggest optimizations based on usage patterns
  """

  require Logger
  alias EveDmv.Repo

  @doc """
  Get slow query statistics from PostgreSQL.
  """
  @spec get_slow_queries(keyword()) :: [map()]
  def get_slow_queries(opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    min_duration = Keyword.get(opts, :min_duration, "1 second")

    query = """
    SELECT 
      query,
      calls,
      total_time / 1000 as total_time_seconds,
      mean_time / 1000 as mean_time_seconds,
      (100 * total_time / sum(total_time::numeric) OVER()) AS percentage
    FROM pg_stat_statements 
    WHERE total_time > EXTRACT(EPOCH FROM INTERVAL '#{min_duration}') * 1000
    ORDER BY total_time DESC 
    LIMIT #{limit}
    """

    case Repo.query(query) do
      {:ok, result} ->
        Enum.map(result.rows, fn row ->
          %{
            query: Enum.at(row, 0),
            calls: Enum.at(row, 1),
            total_time_seconds: Enum.at(row, 2),
            mean_time_seconds: Enum.at(row, 3),
            percentage: Enum.at(row, 4)
          }
        end)

      {:error, error} ->
        Logger.warning("Failed to get slow queries: #{inspect(error)}")
        []
    end
  end

  @doc """
  Get table size statistics.
  """
  @spec get_table_sizes() :: [map()]
  def get_table_sizes do
    query = """
    SELECT 
      schemaname,
      tablename,
      attname,
      n_distinct,
      correlation,
      most_common_vals
    FROM pg_stats 
    WHERE schemaname = 'public'
    ORDER BY tablename, attname
    """

    case Repo.query(query) do
      {:ok, result} ->
        Enum.map(result.rows, fn row ->
          %{
            schema: Enum.at(row, 0),
            table: Enum.at(row, 1),
            column: Enum.at(row, 2),
            n_distinct: Enum.at(row, 3),
            correlation: Enum.at(row, 4),
            most_common_vals: Enum.at(row, 5)
          }
        end)

      {:error, error} ->
        Logger.warning("Failed to get table sizes: #{inspect(error)}")
        []
    end
  end

  @doc """
  Get index usage statistics.
  """
  @spec get_index_usage() :: [map()]
  def get_index_usage do
    query = """
    SELECT 
      t.tablename,
      indexname,
      c.reltuples AS num_rows,
      pg_size_pretty(pg_relation_size(quote_ident(t.tablename)::text)) AS table_size,
      pg_size_pretty(pg_relation_size(quote_ident(indexrelname)::text)) AS index_size,
      CASE WHEN indisunique THEN 'Y' ELSE 'N' END AS UNIQUE,
      idx_scan as number_of_scans,
      idx_tup_read as tuples_read,
      idx_tup_fetch as tuples_fetched
    FROM pg_tables t
    LEFT OUTER JOIN pg_class c ON c.relname=t.tablename
    LEFT OUTER JOIN (
      SELECT c.relname AS ctablename, ipg.relname AS indexname, x.indnatts AS number_of_columns,
             idx_scan, idx_tup_read, idx_tup_fetch, indexrelname, indisunique FROM pg_index x
      JOIN pg_class c ON c.oid = x.indrelid
      JOIN pg_class ipg ON ipg.oid = x.indexrelid
      JOIN pg_stat_all_indexes psai ON x.indexrelid = psai.indexrelid
    ) AS foo ON t.tablename = foo.ctablename
    WHERE t.schemaname='public'
    ORDER BY 1,2
    """

    case Repo.query(query) do
      {:ok, result} ->
        Enum.map(result.rows, fn row ->
          %{
            table_name: Enum.at(row, 0),
            index_name: Enum.at(row, 1),
            num_rows: Enum.at(row, 2),
            table_size: Enum.at(row, 3),
            index_size: Enum.at(row, 4),
            unique: Enum.at(row, 5),
            number_of_scans: Enum.at(row, 6),
            tuples_read: Enum.at(row, 7),
            tuples_fetched: Enum.at(row, 8)
          }
        end)

      {:error, error} ->
        Logger.warning("Failed to get index usage: #{inspect(error)}")
        []
    end
  end

  @doc """
  Analyze database performance and suggest optimizations.
  """
  @spec analyze_performance() :: map()
  def analyze_performance do
    Logger.info("Starting database performance analysis")

    # Get various statistics
    slow_queries = get_slow_queries(limit: 5)
    index_usage = get_index_usage()
    table_stats = get_table_sizes()

    # Analyze and provide recommendations
    recommendations = generate_recommendations(slow_queries, index_usage, table_stats)

    %{
      slow_queries: slow_queries,
      index_usage: index_usage,
      table_stats: table_stats,
      recommendations: recommendations,
      analyzed_at: DateTime.utc_now()
    }
  end

  @doc """
  Update database statistics for better query planning.
  """
  @spec update_statistics() :: :ok
  def update_statistics do
    Logger.info("Updating database statistics")

    tables = [
      "killmails_raw",
      "killmails_enriched", 
      "participants",
      "surveillance_profiles",
      "surveillance_profile_matches",
      "character_stats"
    ]

    Enum.each(tables, fn table ->
      case Repo.query("ANALYZE #{table}") do
        {:ok, _} -> 
          Logger.debug("Updated statistics for table: #{table}")
        {:error, error} -> 
          Logger.warning("Failed to analyze table #{table}: #{inspect(error)}")
      end
    end)

    :ok
  end

  @doc """
  Vacuum and analyze tables for optimal performance.
  """
  @spec vacuum_tables(keyword()) :: :ok
  def vacuum_tables(opts \\ []) do
    full = Keyword.get(opts, :full, false)
    verbose = Keyword.get(opts, :verbose, false)

    vacuum_cmd = case {full, verbose} do
      {true, true} -> "VACUUM (FULL, VERBOSE, ANALYZE)"
      {true, false} -> "VACUUM (FULL, ANALYZE)"
      {false, true} -> "VACUUM (VERBOSE, ANALYZE)"
      {false, false} -> "VACUUM ANALYZE"
    end

    Logger.info("Starting vacuum operation: #{vacuum_cmd}")

    tables = [
      "killmails_raw",
      "killmails_enriched",
      "participants",
      "surveillance_profiles", 
      "surveillance_profile_matches"
    ]

    Enum.each(tables, fn table ->
      case Repo.query("#{vacuum_cmd} #{table}") do
        {:ok, _} -> 
          Logger.info("Vacuumed table: #{table}")
        {:error, error} -> 
          Logger.error("Failed to vacuum table #{table}: #{inspect(error)}")
      end
    end)

    :ok
  end

  @doc """
  Get current connection and query statistics.
  """
  @spec get_connection_stats() :: map()
  def get_connection_stats do
    queries = [
      {"active_connections", "SELECT count(*) FROM pg_stat_activity WHERE state = 'active'"},
      {"idle_connections", "SELECT count(*) FROM pg_stat_activity WHERE state = 'idle'"},
      {"total_connections", "SELECT count(*) FROM pg_stat_activity"},
      {"database_size", "SELECT pg_size_pretty(pg_database_size(current_database()))"},
      {"cache_hit_ratio", """
        SELECT round(
          100.0 * sum(blks_hit) / (sum(blks_hit) + sum(blks_read)), 2
        ) as cache_hit_ratio 
        FROM pg_stat_database 
        WHERE datname = current_database()
      """}
    ]

    stats = 
      Enum.into(queries, %{}, fn {name, query} ->
        case Repo.query(query) do
          {:ok, %{rows: [[value]]}} -> {name, value}
          {:error, _} -> {name, nil}
        end
      end)

    Map.put(stats, :checked_at, DateTime.utc_now())
  end

  # Private helper functions

  defp generate_recommendations(slow_queries, index_usage, _table_stats) do
    recommendations = []

    # Check for slow queries
    recommendations = if length(slow_queries) > 0 do
      ["Consider optimizing slow queries - #{length(slow_queries)} queries taking >1 second" | recommendations]
    else
      recommendations
    end

    # Check for unused indexes
    unused_indexes = Enum.filter(index_usage, fn idx -> 
      (idx.number_of_scans || 0) < 10 and idx.index_name != nil
    end)

    recommendations = if length(unused_indexes) > 0 do
      ["Consider dropping #{length(unused_indexes)} unused indexes to save space" | recommendations]
    else
      recommendations
    end

    # Check for missing indexes on frequently accessed tables
    high_scan_tables = index_usage
    |> Enum.filter(fn idx -> (idx.tuples_read || 0) > 100_000 end)
    |> Enum.map(& &1.table_name)
    |> Enum.uniq()

    recommendations = if length(high_scan_tables) > 0 do
      ["Tables with high scan counts may benefit from additional indexes: #{Enum.join(high_scan_tables, ", ")}" | recommendations]
    else
      recommendations
    end

    if length(recommendations) == 0 do
      ["Database performance looks good - no immediate optimizations needed"]
    else
      recommendations
    end
  end
end