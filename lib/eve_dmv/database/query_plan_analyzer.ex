defmodule EveDmv.Database.QueryPlanAnalyzer do
  @moduledoc """
  Analyzes PostgreSQL query execution plans to identify performance bottlenecks
  and optimization opportunities.

  Provides automated query plan analysis, slow query detection, and
  optimization recommendations for the EVE DMV application.
  """

  use GenServer
  require Logger

  alias EveDmv.Repo

  @analysis_interval :timer.hours(1)
  @slow_query_threshold_ms 1000
  @expensive_query_threshold_ms 5000

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def analyze_query(query, params \\ []) do
    GenServer.call(__MODULE__, {:analyze_query, query, params})
  end

  def get_slow_queries(limit \\ 10) do
    GenServer.call(__MODULE__, {:get_slow_queries, limit})
  end

  def get_analysis_report do
    GenServer.call(__MODULE__, :get_analysis_report)
  end

  def analyze_table_stats(table_name) do
    GenServer.call(__MODULE__, {:analyze_table_stats, table_name})
  end

  def suggest_indexes do
    GenServer.call(__MODULE__, :suggest_indexes)
  end

  def force_analysis do
    GenServer.cast(__MODULE__, :force_analysis)
  end

  # Server callbacks

  def init(opts) do
    state = %{
      enabled: Keyword.get(opts, :enabled, true),
      slow_queries: [],
      analysis_stats: %{
        total_queries_analyzed: 0,
        slow_queries_detected: 0,
        last_analysis: nil,
        recommendations: []
      }
    }

    if state.enabled do
      # Enable pg_stat_statements if available
      ensure_pg_stat_statements_enabled()
      schedule_analysis()
    end

    {:ok, state}
  end

  def handle_call({:analyze_query, query, params}, _from, state) do
    result = perform_query_analysis(query, params)
    {:reply, result, state}
  end

  def handle_call({:get_slow_queries, limit}, _from, state) do
    slow_queries = Enum.take(state.slow_queries, limit)
    {:reply, slow_queries, state}
  end

  def handle_call(:get_analysis_report, _from, state) do
    report = generate_analysis_report(state)
    {:reply, report, state}
  end

  def handle_call({:analyze_table_stats, table_name}, _from, state) do
    result = analyze_table_statistics(table_name)
    {:reply, result, state}
  end

  def handle_call(:suggest_indexes, _from, state) do
    suggestions = generate_index_suggestions()
    {:reply, suggestions, state}
  end

  def handle_cast(:force_analysis, state) do
    new_state = perform_periodic_analysis(state)
    {:noreply, new_state}
  end

  def handle_info(:perform_analysis, state) do
    new_state = perform_periodic_analysis(state)
    schedule_analysis()
    {:noreply, new_state}
  end

  def handle_info(_, state), do: {:noreply, state}

  # Private functions

  defp schedule_analysis do
    Process.send_after(self(), :perform_analysis, @analysis_interval)
  end

  defp ensure_pg_stat_statements_enabled do
    query = "SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements')"

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, %{rows: [[true]]}} ->
        Logger.info("pg_stat_statements extension is available")
        :ok

      {:ok, %{rows: [[false]]}} ->
        Logger.warning(
          "pg_stat_statements extension not available - limited analysis capabilities"
        )

        :not_available

      {:error, error} ->
        Logger.error("Failed to check pg_stat_statements: #{inspect(error)}")
        :error
    end
  end

  defp perform_query_analysis(query, params) do
    Logger.debug("Analyzing query: #{String.slice(query, 0, 100)}...")

    start_time = System.monotonic_time(:millisecond)

    # Get query execution plan
    explain_query = "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " <> query

    case Ecto.Adapters.SQL.query(Repo, explain_query, params) do
      {:ok, %{rows: [[json_plan]]}} ->
        execution_time = System.monotonic_time(:millisecond) - start_time

        analysis = analyze_execution_plan(json_plan, execution_time)
        recommendations = generate_query_recommendations(analysis)

        %{
          execution_time_ms: execution_time,
          plan: analysis,
          recommendations: recommendations,
          is_slow: execution_time > @slow_query_threshold_ms,
          is_expensive: execution_time > @expensive_query_threshold_ms
        }

      {:error, error} ->
        Logger.error("Failed to analyze query: #{inspect(error)}")
        %{error: "Query analysis failed", details: inspect(error)}
    end
  rescue
    error ->
      Logger.error("Exception during query analysis: #{inspect(error)}")
      %{error: "Analysis exception", details: inspect(error)}
  end

  defp analyze_execution_plan(json_plan, execution_time) do
    plan = Jason.decode!(json_plan)
    root_node = List.first(plan)["Plan"]

    %{
      total_cost: root_node["Total Cost"],
      actual_time: root_node["Actual Total Time"],
      actual_rows: root_node["Actual Rows"],
      planned_rows: root_node["Plan Rows"],
      execution_time_ms: execution_time,
      node_types: extract_node_types(root_node),
      expensive_operations: find_expensive_operations(root_node),
      row_estimation_errors: calculate_row_estimation_errors(root_node),
      buffer_usage: extract_buffer_usage(root_node),
      index_usage: extract_index_usage(root_node)
    }
  end

  defp extract_node_types(node, types \\ []) do
    current_type = node["Node Type"]
    types_with_current = [current_type | types]

    case node["Plans"] do
      nil ->
        types_with_current

      plans when is_list(plans) ->
        Enum.reduce(plans, types_with_current, &extract_node_types/2)
    end
  end

  defp find_expensive_operations(node, expensive \\ []) do
    current_cost = node["Total Cost"] || 0
    actual_time = node["Actual Total Time"] || 0

    expensive_with_current =
      if current_cost > 1000 or actual_time > 100 do
        [
          %{
            node_type: node["Node Type"],
            cost: current_cost,
            actual_time: actual_time,
            relation: node["Relation Name"]
          }
          | expensive
        ]
      else
        expensive
      end

    case node["Plans"] do
      nil ->
        expensive_with_current

      plans when is_list(plans) ->
        Enum.reduce(plans, expensive_with_current, &find_expensive_operations/2)
    end
  end

  defp calculate_row_estimation_errors(node, errors \\ []) do
    actual_rows = node["Actual Rows"] || 0
    planned_rows = node["Plan Rows"] || 1

    error_ratio = if planned_rows > 0, do: actual_rows / planned_rows, else: 1.0

    errors_with_current =
      if abs(error_ratio - 1.0) > 0.5 and actual_rows > 10 do
        [
          %{
            node_type: node["Node Type"],
            planned_rows: planned_rows,
            actual_rows: actual_rows,
            error_ratio: error_ratio,
            relation: node["Relation Name"]
          }
          | errors
        ]
      else
        errors
      end

    case node["Plans"] do
      nil ->
        errors_with_current

      plans when is_list(plans) ->
        Enum.reduce(plans, errors_with_current, &calculate_row_estimation_errors/2)
    end
  end

  defp extract_buffer_usage(node, usage \\ %{}) do
    shared_hit = node["Shared Hit Blocks"] || 0
    shared_read = node["Shared Read Blocks"] || 0
    temp_read = node["Temp Read Blocks"] || 0
    temp_written = node["Temp Written Blocks"] || 0

    current_usage = %{
      shared_hit: shared_hit,
      shared_read: shared_read,
      temp_read: temp_read,
      temp_written: temp_written,
      cache_hit_ratio:
        if(shared_hit + shared_read > 0,
          do: shared_hit / (shared_hit + shared_read),
          else: 1.0
        )
    }

    merged_usage = merge_buffer_usage(usage, current_usage)

    case node["Plans"] do
      nil ->
        merged_usage

      plans when is_list(plans) ->
        Enum.reduce(plans, merged_usage, &extract_buffer_usage/2)
    end
  end

  defp merge_buffer_usage(usage1, usage2) do
    %{
      shared_hit: (usage1[:shared_hit] || 0) + usage2.shared_hit,
      shared_read: (usage1[:shared_read] || 0) + usage2.shared_read,
      temp_read: (usage1[:temp_read] || 0) + usage2.temp_read,
      temp_written: (usage1[:temp_written] || 0) + usage2.temp_written,
      cache_hit_ratio: calculate_combined_cache_ratio(usage1, usage2)
    }
  end

  defp calculate_combined_cache_ratio(usage1, usage2) do
    total_hit = (usage1[:shared_hit] || 0) + usage2.shared_hit
    total_read = (usage1[:shared_read] || 0) + usage2.shared_read

    if total_hit + total_read > 0 do
      total_hit / (total_hit + total_read)
    else
      1.0
    end
  end

  defp extract_index_usage(node, indexes \\ []) do
    index_info =
      case node["Node Type"] do
        "Index Scan" ->
          [
            %{
              type: "Index Scan",
              index_name: node["Index Name"],
              relation: node["Relation Name"],
              cost: node["Total Cost"],
              rows: node["Actual Rows"]
            }
          ]

        "Index Only Scan" ->
          [
            %{
              type: "Index Only Scan",
              index_name: node["Index Name"],
              relation: node["Relation Name"],
              cost: node["Total Cost"],
              rows: node["Actual Rows"]
            }
          ]

        "Bitmap Index Scan" ->
          [
            %{
              type: "Bitmap Index Scan",
              index_name: node["Index Name"],
              relation: node["Relation Name"],
              cost: node["Total Cost"],
              rows: node["Actual Rows"]
            }
          ]

        _ ->
          []
      end

    indexes_with_current = index_info ++ indexes

    case node["Plans"] do
      nil ->
        indexes_with_current

      plans when is_list(plans) ->
        Enum.reduce(plans, indexes_with_current, &extract_index_usage/2)
    end
  end

  defp generate_query_recommendations(analysis) do
    recommendations = []

    # Low cache hit ratio
    recommendations =
      if analysis.buffer_usage.cache_hit_ratio < 0.9 do
        [
          "Consider increasing shared_buffers or optimizing query to reduce disk I/O"
          | recommendations
        ]
      else
        recommendations
      end

    # Row estimation errors
    recommendations =
      if length(analysis.row_estimation_errors) > 0 do
        ["Update table statistics with ANALYZE to improve query planning" | recommendations]
      else
        recommendations
      end

    # Sequential scans on large tables
    recommendations =
      if Enum.any?(analysis.node_types, &(&1 == "Seq Scan")) do
        [
          "Sequential scans detected - consider adding indexes for frequently queried columns"
          | recommendations
        ]
      else
        recommendations
      end

    # Expensive sorts
    recommendations =
      if Enum.any?(analysis.expensive_operations, &(&1.node_type == "Sort")) do
        ["Expensive sort operations - consider adding indexes to avoid sorting" | recommendations]
      else
        recommendations
      end

    # Nested loops with high cost
    recommendations =
      if Enum.any?(analysis.expensive_operations, &(&1.node_type == "Nested Loop")) do
        [
          "Expensive nested loop joins - consider optimizing join conditions or adding indexes"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations
  end

  defp perform_periodic_analysis(state) do
    Logger.info("Starting periodic query plan analysis")

    start_time = System.monotonic_time(:millisecond)

    # Analyze slow queries from pg_stat_statements
    slow_queries = detect_slow_queries()

    # Analyze table statistics
    table_stats = analyze_critical_tables()

    # Generate index recommendations
    index_suggestions = generate_index_suggestions()

    duration_ms = System.monotonic_time(:millisecond) - start_time

    new_stats = %{
      total_queries_analyzed: state.analysis_stats.total_queries_analyzed + length(slow_queries),
      slow_queries_detected: length(slow_queries),
      last_analysis: DateTime.utc_now(),
      recommendations: index_suggestions,
      table_stats: table_stats,
      analysis_duration_ms: duration_ms
    }

    Logger.info(
      "Query plan analysis completed in #{duration_ms}ms - found #{length(slow_queries)} slow queries"
    )

    %{state | slow_queries: slow_queries, analysis_stats: new_stats}
  end

  defp detect_slow_queries do
    query = """
    SELECT 
      query,
      calls,
      total_time,
      mean_time,
      rows,
      100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
    FROM pg_stat_statements
    WHERE mean_time > $1
    ORDER BY mean_time DESC
    LIMIT 20
    """

    case Ecto.Adapters.SQL.query(Repo, query, [@slow_query_threshold_ms]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [query_text, calls, total_time, mean_time, row_count, hit_percent] ->
          %{
            query: String.slice(query_text, 0, 500),
            calls: calls,
            total_time_ms: total_time,
            mean_time_ms: mean_time,
            rows: row_count,
            cache_hit_percent: hit_percent || 0.0,
            detected_at: DateTime.utc_now()
          }
        end)

      {:error, error} ->
        Logger.warning("Failed to detect slow queries: #{inspect(error)}")
        []
    end
  end

  defp analyze_critical_tables do
    critical_tables = [
      "killmails_raw",
      "killmails_enriched",
      "participants",
      "character_stats"
    ]

    Enum.map(critical_tables, &analyze_table_statistics/1)
    |> Enum.reject(&is_nil/1)
  end

  defp analyze_table_statistics(table_name) do
    # Get table size and row count
    size_query = """
    SELECT 
      schemaname,
      tablename,
      attname,
      n_distinct,
      correlation,
      most_common_vals,
      most_common_freqs
    FROM pg_stats 
    WHERE tablename = $1 
    AND schemaname = 'public'
    """

    stats_query = """
    SELECT 
      schemaname,
      tablename,
      seq_scan,
      seq_tup_read,
      idx_scan,
      idx_tup_fetch,
      n_tup_ins,
      n_tup_upd,
      n_tup_del,
      n_live_tup,
      n_dead_tup
    FROM pg_stat_user_tables 
    WHERE tablename = $1 
    AND schemaname = 'public'
    """

    with {:ok, %{rows: stats_rows}} <- Ecto.Adapters.SQL.query(Repo, stats_query, [table_name]),
         {:ok, %{rows: size_rows}} <- Ecto.Adapters.SQL.query(Repo, size_query, [table_name]) do
      case stats_rows do
        [
          [
            _schema,
            table,
            seq_scan,
            seq_tup_read,
            idx_scan,
            idx_tup_fetch,
            n_tup_ins,
            n_tup_upd,
            n_tup_del,
            n_live_tup,
            n_dead_tup
          ]
        ] ->
          %{
            table_name: table,
            sequential_scans: seq_scan,
            sequential_tuples_read: seq_tup_read,
            index_scans: idx_scan,
            index_tuples_fetched: idx_tup_fetch,
            tuples_inserted: n_tup_ins,
            tuples_updated: n_tup_upd,
            tuples_deleted: n_tup_del,
            live_tuples: n_live_tup,
            dead_tuples: n_dead_tup,
            bloat_ratio:
              if(n_live_tup > 0, do: n_dead_tup / (n_live_tup + n_dead_tup), else: 0.0),
            column_stats: parse_column_stats(size_rows),
            recommendations:
              generate_table_recommendations(seq_scan, idx_scan, n_dead_tup, n_live_tup)
          }

        _ ->
          nil
      end
    else
      {:error, error} ->
        Logger.warning("Failed to analyze table #{table_name}: #{inspect(error)}")
        nil
    end
  end

  defp parse_column_stats(rows) do
    Enum.map(rows, fn [_schema, _table, column, n_distinct, correlation, _vals, _freqs] ->
      %{
        column_name: column,
        distinct_values: n_distinct,
        correlation: correlation
      }
    end)
  end

  defp generate_table_recommendations(seq_scan, idx_scan, dead_tuples, live_tuples) do
    recommendations = []

    # High sequential scan ratio
    recommendations =
      if seq_scan > 0 and idx_scan > 0 and seq_scan / (seq_scan + idx_scan) > 0.1 do
        ["Table has high sequential scan ratio - consider adding indexes" | recommendations]
      else
        recommendations
      end

    # High bloat ratio
    recommendations =
      if live_tuples > 0 and dead_tuples / (live_tuples + dead_tuples) > 0.1 do
        [
          "Table has high bloat ratio (#{Float.round(dead_tuples / (live_tuples + dead_tuples) * 100, 1)}%) - consider VACUUM FULL"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations
  end

  defp generate_index_suggestions do
    # Analyze query patterns to suggest indexes
    suggestions = []

    # Check for queries with WHERE clauses that might benefit from indexes
    where_clause_analysis = analyze_where_clause_patterns()

    # Check for queries with ORDER BY that might benefit from indexes
    order_by_analysis = analyze_order_by_patterns()

    # Check for JOIN conditions that might benefit from indexes
    join_analysis = analyze_join_patterns()

    suggestions ++ where_clause_analysis ++ order_by_analysis ++ join_analysis
  end

  defp analyze_where_clause_patterns do
    # This would analyze actual query logs to identify common WHERE patterns
    # For now, return some common patterns for EVE DMV
    [
      %{
        table: "participants",
        columns: ["character_id", "killmail_time"],
        reason: "Frequent character lookups with time range filters",
        estimated_benefit: "High"
      },
      %{
        table: "killmails_enriched",
        columns: ["solar_system_id", "killmail_time"],
        reason: "System-based queries with time filters",
        estimated_benefit: "High"
      },
      %{
        table: "character_stats",
        columns: ["last_calculated_at"],
        reason: "Finding stale character stats for updates",
        estimated_benefit: "Medium"
      }
    ]
  end

  defp analyze_order_by_patterns do
    [
      %{
        table: "killmails_enriched",
        columns: ["total_value", "killmail_time"],
        reason: "High-value killmail queries with time ordering",
        estimated_benefit: "Medium"
      }
    ]
  end

  defp analyze_join_patterns do
    [
      %{
        table: "participants",
        columns: ["alliance_id", "killmail_time"],
        reason: "Alliance activity analysis joins",
        estimated_benefit: "Medium"
      }
    ]
  end

  defp generate_analysis_report(state) do
    %{
      analysis_stats: state.analysis_stats,
      slow_query_count: length(state.slow_queries),
      recent_slow_queries: Enum.take(state.slow_queries, 5),
      system_health: assess_system_health(state),
      top_recommendations: get_top_recommendations(state)
    }
  end

  defp assess_system_health(state) do
    slow_query_count = length(state.slow_queries)

    health_score =
      cond do
        slow_query_count == 0 -> 100
        slow_query_count <= 5 -> 80
        slow_query_count <= 15 -> 60
        slow_query_count <= 30 -> 40
        true -> 20
      end

    status =
      cond do
        health_score >= 80 -> "Excellent"
        health_score >= 60 -> "Good"
        health_score >= 40 -> "Fair"
        health_score >= 20 -> "Poor"
        true -> "Critical"
      end

    %{
      score: health_score,
      status: status,
      slow_queries_detected: slow_query_count,
      last_analysis: state.analysis_stats.last_analysis
    }
  end

  defp get_top_recommendations(state) do
    state.analysis_stats.recommendations
    |> Enum.filter(&(&1.estimated_benefit in ["High", "Medium"]))
    |> Enum.sort_by(&(&1.estimated_benefit == "High"), &>=/2)
    |> Enum.take(5)
  end

  # Public utilities

  def enable_query_logging do
    queries = [
      "SET log_statement = 'all'",
      "SET log_min_duration_statement = #{@slow_query_threshold_ms}",
      "SET log_checkpoints = on",
      "SET log_lock_waits = on"
    ]

    Enum.each(queries, fn query ->
      case Ecto.Adapters.SQL.query(Repo, query, []) do
        {:ok, _} ->
          :ok

        {:error, error} ->
          Logger.warning("Failed to set logging parameter: #{inspect(error)}")
      end
    end)
  end

  def get_query_performance_metrics do
    query = """
    SELECT 
      'total_queries' as metric,
      sum(calls) as value
    FROM pg_stat_statements
    UNION ALL
    SELECT 
      'avg_query_time_ms' as metric,
      avg(mean_time) as value
    FROM pg_stat_statements
    UNION ALL
    SELECT 
      'slow_queries' as metric,
      count(*) as value
    FROM pg_stat_statements
    WHERE mean_time > $1
    """

    case Ecto.Adapters.SQL.query(Repo, query, [@slow_query_threshold_ms]) do
      {:ok, %{rows: rows}} ->
        Map.new(rows, fn [metric, value] -> {metric, value} end)

      {:error, _} ->
        %{}
    end
  end
end
