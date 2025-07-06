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

  # Error types for consistent handling
  @type error_type :: :database_error | :validation_error | :query_error | :connection_error

  @type result(success_type) :: {:ok, success_type} | {:error, error_type(), String.t()}

  # Validation functions for SQL injection prevention
  defp validate_positive_integer(value, _default) when is_integer(value) and value > 0, do: value
  defp validate_positive_integer(_, default), do: default

  defp validate_duration_string(value, default) when is_binary(value) do
    # Allow only alphanumeric characters, spaces, and time units
    if String.match?(value, ~r/^[0-9]+\s+(second|minute|hour|day)s?$/i) do
      value
    else
      default
    end
  end

  defp validate_duration_string(_, default), do: default

  @allowed_tables [
    "killmails_raw",
    "killmails_enriched",
    "participants",
    "surveillance_profiles",
    "surveillance_profile_matches",
    "character_stats"
  ]

  defp validate_table_name(table_name) when table_name in @allowed_tables do
    # Quote the identifier to prevent injection
    ~s("#{table_name}")
  end

  defp validate_table_name(_), do: nil

  # Centralized error handling for consistent behavior
  defp handle_database_error(error, operation, context \\ %{}) do
    error_details = %{
      operation: operation,
      error: inspect(error),
      context: context,
      timestamp: DateTime.utc_now()
    }

    case error do
      %Postgrex.Error{postgres: %{code: code}} ->
        case code do
          :undefined_table ->
            Logger.error("Database table not found during #{operation}", error_details)
            {:error, :database_error, "Required database table not found"}

          :undefined_column ->
            Logger.error("Database column not found during #{operation}", error_details)
            {:error, :database_error, "Required database column not found"}

          :insufficient_privilege ->
            Logger.error("Insufficient database privileges for #{operation}", error_details)
            {:error, :database_error, "Insufficient database privileges"}

          _ ->
            Logger.error("Database error during #{operation}", error_details)
            {:error, :database_error, "Database operation failed: #{code}"}
        end

      %DBConnection.ConnectionError{} ->
        Logger.error("Database connection error during #{operation}", error_details)
        {:error, :connection_error, "Database connection failed"}

      _ ->
        Logger.error("Unexpected error during #{operation}", error_details)
        {:error, :query_error, "Query execution failed"}
    end
  end

  defp handle_validation_error(field, value, operation) do
    error_message = "Invalid #{field}: #{inspect(value)} for operation #{operation}"
    Logger.warning(error_message)
    {:error, :validation_error, error_message}
  end

  @doc """
  Get slow query statistics from PostgreSQL.
  """
  @spec get_slow_queries(keyword()) :: result([map()])
  def get_slow_queries(opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    min_duration = Keyword.get(opts, :min_duration, "1 second")

    # Validate and sanitize inputs
    validated_limit = validate_positive_integer(limit, 10)
    validated_duration = validate_duration_string(min_duration, "1 second")

    # Check if inputs were valid
    cond do
      limit != validated_limit ->
        handle_validation_error("limit", limit, "get_slow_queries")

      min_duration != validated_duration ->
        handle_validation_error("min_duration", min_duration, "get_slow_queries")

      true ->
        execute_slow_queries_query(validated_duration, validated_limit)
    end
  end

  defp execute_slow_queries_query(duration, limit) do
    query = """
    SELECT 
      query,
      calls,
      total_time / 1000 as total_time_seconds,
      mean_time / 1000 as mean_time_seconds,
      (100 * total_time / sum(total_time::numeric) OVER()) AS percentage
    FROM pg_stat_statements 
    WHERE total_time > EXTRACT(EPOCH FROM INTERVAL $1) * 1000
    ORDER BY total_time DESC 
    LIMIT $2
    """

    case Repo.query(query, [duration, limit]) do
      {:ok, result} ->
        slow_queries =
          Enum.map(result.rows, fn row ->
            %{
              query: Enum.at(row, 0),
              calls: Enum.at(row, 1),
              total_time_seconds: Enum.at(row, 2),
              mean_time_seconds: Enum.at(row, 3),
              percentage: Enum.at(row, 4)
            }
          end)

        {:ok, slow_queries}

      {:error, error} ->
        handle_database_error(error, "get_slow_queries", %{duration: duration, limit: limit})
    end
  end

  @doc """
  Get table size statistics.
  """
  @spec get_table_sizes() :: result([map()])
  def get_table_sizes do
    query = """
    SELECT 
      schemaname,
      tablename,
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
      pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS index_size,
      pg_total_relation_size(schemaname||'.'||tablename) AS size_bytes
    FROM pg_tables 
    WHERE schemaname = 'public'
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
    """

    case Repo.query(query) do
      {:ok, result} ->
        table_sizes =
          Enum.map(result.rows, fn row ->
            %{
              schema: Enum.at(row, 0),
              table: Enum.at(row, 1),
              total_size: Enum.at(row, 2),
              table_size: Enum.at(row, 3),
              index_size: Enum.at(row, 4),
              size_bytes: Enum.at(row, 5)
            }
          end)

        {:ok, table_sizes}

      {:error, error} ->
        handle_database_error(error, "get_table_sizes")
    end
  end

  @doc """
  Get index usage statistics.
  """
  @spec get_index_usage() :: result([map()])
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
        index_stats =
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

        {:ok, index_stats}

      {:error, error} ->
        handle_database_error(error, "get_index_usage")
    end
  end

  @doc """
  Analyze database performance and suggest optimizations.
  """
  @spec analyze_performance() ::
          result(%{
            slow_queries: [map()],
            index_usage: [map()],
            table_stats: [map()],
            recommendations: [String.t()],
            analyzed_at: DateTime.t(),
            errors: [String.t()]
          })
  def analyze_performance do
    Logger.info("Starting database performance analysis")

    # Collect all statistics with error handling
    {slow_queries, errors1} = safe_execute_with_fallback(&get_slow_queries/1, [limit: 5], [])
    {index_usage, errors2} = safe_execute_with_fallback(&get_index_usage/0, [], errors1)
    {table_stats, errors3} = safe_execute_with_fallback(&get_table_sizes/0, [], errors2)

    # Generate recommendations based on available data
    recommendations = generate_recommendations(slow_queries, index_usage, table_stats)

    result = %{
      slow_queries: slow_queries,
      index_usage: index_usage,
      table_stats: table_stats,
      recommendations: recommendations,
      analyzed_at: DateTime.utc_now(),
      errors: errors3
    }

    if Enum.empty?(errors3) do
      {:ok, result}
    else
      Logger.warning("Performance analysis completed with #{length(errors3)} errors")
      # Still return success with partial data
      {:ok, result}
    end
  end

  # Helper function to safely execute functions with fallbacks
  defp safe_execute_with_fallback(func, args, existing_errors) do
    case apply(func, args) do
      {:ok, data} ->
        {data, existing_errors}

      {:error, _type, message} ->
        {[], [message | existing_errors]}
    end
  end

  @doc """
  Update database statistics for better query planning.
  """
  @spec update_statistics() :: result([String.t()])
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

    {successes, errors} =
      Enum.reduce(tables, {[], []}, fn table, acc ->
        process_table_statistics(table, acc)
      end)

    if Enum.empty?(errors) do
      {:ok, successes}
    else
      Logger.warning("Statistics update completed with #{length(errors)} errors")
      # Return partial success
      {:ok, successes}
    end
  end

  @doc """
  Vacuum and analyze tables for optimal performance.
  """
  @spec vacuum_tables(keyword()) :: result([String.t()])
  def vacuum_tables(opts \\ []) do
    full = Keyword.get(opts, :full, false)
    verbose = Keyword.get(opts, :verbose, false)

    vacuum_cmd =
      case {full, verbose} do
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

    {successes, errors} =
      Enum.reduce(tables, {[], []}, fn table, acc ->
        process_table_vacuum(table, vacuum_cmd, acc)
      end)

    if Enum.empty?(errors) do
      {:ok, successes}
    else
      Logger.warning("Vacuum operation completed with #{length(errors)} errors")
      # Return partial success
      {:ok, successes}
    end
  end

  @doc """
  Get current connection and query statistics.
  """
  @spec get_connection_stats() ::
          result(%{String.t() => any(), checked_at: DateTime.t(), errors: [String.t()]})
  def get_connection_stats do
    queries = [
      {"active_connections", "SELECT count(*) FROM pg_stat_activity WHERE state = 'active'"},
      {"idle_connections", "SELECT count(*) FROM pg_stat_activity WHERE state = 'idle'"},
      {"total_connections", "SELECT count(*) FROM pg_stat_activity"},
      {"database_size", "SELECT pg_size_pretty(pg_database_size(current_database()))"},
      {"cache_hit_ratio",
       """
         SELECT round(
           100.0 * sum(blks_hit) / (sum(blks_hit) + sum(blks_read)), 2
         ) as cache_hit_ratio 
         FROM pg_stat_database 
         WHERE datname = current_database()
       """}
    ]

    {stats, errors} =
      Enum.reduce(queries, {%{}, []}, fn {name, query}, {stats_acc, errors_acc} ->
        case Repo.query(query) do
          {:ok, %{rows: [[value]]}} ->
            {Map.put(stats_acc, name, value), errors_acc}

          {:error, error} ->
            case handle_database_error(error, "get_connection_stats", %{stat: name}) do
              {:error, _type, message} ->
                {Map.put(stats_acc, name, nil), [message | errors_acc]}
            end
        end
      end)

    result =
      stats
      |> Map.put(:checked_at, DateTime.utc_now())
      |> Map.put(:errors, errors)

    if Enum.empty?(errors) do
      {:ok, result}
    else
      Logger.warning("Connection stats retrieved with #{length(errors)} errors")
      # Return partial success with errors included
      {:ok, result}
    end
  end

  # Private helper functions

  defp process_table_statistics(table, {success_acc, error_acc}) do
    case validate_table_name(table) do
      nil ->
        error_msg = "Invalid table name: #{table}"
        Logger.warning(error_msg)
        {success_acc, [error_msg | error_acc]}

      quoted_table ->
        case Repo.query("ANALYZE #{quoted_table}") do
          {:ok, _} ->
            Logger.debug("Updated statistics for table: #{table}")
            {[table | success_acc], error_acc}

          {:error, error} ->
            case handle_database_error(error, "update_statistics", %{table: table}) do
              {:error, _type, message} ->
                {success_acc, [message | error_acc]}
            end
        end
    end
  end

  defp process_table_vacuum(table, vacuum_cmd, {success_acc, error_acc}) do
    case validate_table_name(table) do
      nil ->
        error_msg = "Invalid table name: #{table}"
        Logger.warning(error_msg)
        {success_acc, [error_msg | error_acc]}

      quoted_table ->
        case Repo.query("#{vacuum_cmd} #{quoted_table}") do
          {:ok, _} ->
            Logger.info("Vacuumed table: #{table}")
            {[table | success_acc], error_acc}

          {:error, error} ->
            case handle_database_error(error, "vacuum_tables", %{table: table}) do
              {:error, _type, message} ->
                {success_acc, [message | error_acc]}
            end
        end
    end
  end

  defp generate_recommendations(slow_queries, index_usage, _table_stats) do
    recommendations = []

    # Check for slow queries
    recommendations =
      if length(slow_queries) > 0 do
        [
          "Consider optimizing slow queries - #{length(slow_queries)} queries taking >1 second"
          | recommendations
        ]
      else
        recommendations
      end

    # Check for unused indexes
    unused_indexes =
      Enum.filter(index_usage, fn idx ->
        (idx.number_of_scans || 0) < 10 and idx.index_name != nil
      end)

    recommendations =
      if length(unused_indexes) > 0 do
        [
          "Consider dropping #{length(unused_indexes)} unused indexes to save space"
          | recommendations
        ]
      else
        recommendations
      end

    # Check for missing indexes on frequently accessed tables
    high_scan_tables =
      index_usage
      |> Enum.filter(fn idx -> (idx.tuples_read || 0) > 100_000 end)
      |> Enum.map(& &1.table_name)
      |> Enum.uniq()

    recommendations =
      if length(high_scan_tables) > 0 do
        [
          "Tables with high scan counts may benefit from additional indexes: #{Enum.join(high_scan_tables, ", ")}"
          | recommendations
        ]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["Database performance looks good - no immediate optimizations needed"]
    else
      recommendations
    end
  end
end
