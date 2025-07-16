defmodule EveDmv.Database.QueryPerformance do
  @moduledoc """
  Performance tracking wrapper for database queries.

  Provides macros and functions to easily track query performance
  and identify bottlenecks.
  """

  import EveDmv.Monitoring.PerformanceTracker, only: [time_query: 3]

  @doc """
  Execute a query with performance tracking.

  ## Examples

      tracked_query("character_stats", 
        fn -> Repo.query(sql, params) end,
        metadata: %{character_id: 123}
      )
  """
  def tracked_query(query_name, query_fn, opts \\ []) do
    time_query query_name, opts do
      query_fn.()
    end
  end

  @doc """
  Execute an Ash query with performance tracking.

  ## Examples

      tracked_ash_query("recent_killmails",
        fn -> 
          KillmailRaw
          |> Ash.Query.filter(killmail_time > ^since)
          |> Api.read!()
        end
      )
  """
  def tracked_ash_query(query_name, query_fn, opts \\ []) do
    time_query "ash:#{query_name}", opts do
      query_fn.()
    end
  end

  @doc """
  Macro for tracking performance of a query block.

  ## Examples

      import EveDmv.Database.QueryPerformance
      
      track_query "get_character_kills" do
        Repo.query(sql, [character_id])
      end
  """
  defmacro track_query(name, opts \\ [], do: block) do
    quote do
      EveDmv.Monitoring.PerformanceTracker.time_query unquote(name), unquote(opts) do
        unquote(block)
      end
    end
  end

  @doc """
  Add query hints to help identify slow queries.

  ## Examples

      sql = with_query_hint("SELECT * FROM killmails", "character_analysis")
  """
  def with_query_hint(sql, hint) when is_binary(sql) and is_binary(hint) do
    "/* #{hint} */ #{sql}"
  end

  @doc """
  Analyze query execution plan.

  Returns the execution plan for a query, useful for debugging
  performance issues.
  """
  def explain_query(sql, params \\ []) do
    explain_sql = "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) #{sql}"

    case EveDmv.Repo.query(explain_sql, params) do
      {:ok, %{rows: [[json]]}} ->
        {:ok, Jason.decode!(json)}

      error ->
        error
    end
  end

  @doc """
  Get index usage statistics for a table.
  """
  def table_index_stats(table_name) do
    sql = """
    SELECT 
      schemaname,
      tablename,
      indexname,
      idx_scan as index_scans,
      idx_tup_read as tuples_read,
      idx_tup_fetch as tuples_fetched,
      pg_size_pretty(pg_relation_size(indexrelid)) as index_size
    FROM pg_stat_user_indexes
    WHERE tablename = $1
    ORDER BY idx_scan DESC
    """

    case EveDmv.Repo.query(sql, [table_name]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [schema, table, index, scans, read, fetched, size] ->
          %{
            schema: schema,
            table: table,
            index: index,
            scans: scans,
            tuples_read: read,
            tuples_fetched: fetched,
            size: size
          }
        end)

      _ ->
        []
    end
  end

  @doc """
  Check for missing indexes based on query patterns.
  """
  def suggest_missing_indexes(table_name) do
    sql = """
    SELECT 
      schemaname,
      tablename,
      attname as column_name,
      n_distinct,
      correlation
    FROM pg_stats
    WHERE tablename = $1
      AND n_distinct > 100
      AND schemaname = 'public'
    ORDER BY n_distinct DESC
    """

    case EveDmv.Repo.query(sql, [table_name]) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.map(fn [_schema, _table, column, n_distinct, correlation] ->
          %{
            column: column,
            distinct_values: n_distinct,
            correlation: correlation,
            index_benefit: calculate_index_benefit(n_distinct, correlation)
          }
        end)
        |> Enum.filter(&(&1.index_benefit > 0.5))

      _ ->
        []
    end
  end

  defp calculate_index_benefit(n_distinct, correlation)
       when is_number(n_distinct) and is_number(correlation) do
    # Higher distinct values and lower correlation suggest index would be beneficial
    distinct_factor = min(n_distinct / 1000, 1.0)
    correlation_factor = 1.0 - abs(correlation)

    (distinct_factor + correlation_factor) / 2
  end

  defp calculate_index_benefit(_, _), do: 0.0
end
