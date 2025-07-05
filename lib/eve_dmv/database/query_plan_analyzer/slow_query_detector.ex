defmodule EveDmv.Database.QueryPlanAnalyzer.SlowQueryDetector do
  @moduledoc """
  Slow query detection and monitoring module.
  
  Detects slow-running queries using pg_stat_statements, analyzes their
  patterns, and provides recommendations for performance optimization.
  """

  require Logger
  alias EveDmv.Repo

  @slow_query_threshold_ms 1000
  @expensive_query_threshold_ms 5000

  @doc """
  Detects slow queries from pg_stat_statements.
  
  Queries the pg_stat_statements view to find queries that exceed
  the configured slow query threshold.
  """
  def detect_slow_queries(threshold_ms \\ @slow_query_threshold_ms) do
    query = """
    SELECT 
      query,
      calls,
      total_time,
      mean_time,
      rows,
      100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent,
      stddev_time,
      min_time,
      max_time
    FROM pg_stat_statements
    WHERE mean_time > $1
    ORDER BY mean_time DESC
    LIMIT 20
    """

    case Ecto.Adapters.SQL.query(Repo, query, [threshold_ms]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [query_text, calls, total_time, mean_time, row_count, hit_percent, stddev_time, min_time, max_time] ->
          %{
            query: String.slice(query_text, 0, 500),
            calls: calls,
            total_time_ms: total_time,
            mean_time_ms: mean_time,
            rows: row_count,
            cache_hit_percent: hit_percent || 0.0,
            stddev_time_ms: stddev_time || 0.0,
            min_time_ms: min_time || 0.0,
            max_time_ms: max_time || 0.0,
            detected_at: DateTime.utc_now(),
            severity: classify_query_severity(mean_time, total_time)
          }
        end)

      {:error, error} ->
        Logger.warning("Failed to detect slow queries: #{inspect(error)}")
        []
    end
  end

  @doc """
  Analyzes slow query patterns to identify common performance issues.
  """
  def analyze_slow_query_patterns(slow_queries) do
    %{
      total_slow_queries: length(slow_queries),
      severity_distribution: analyze_severity_distribution(slow_queries),
      cache_performance: analyze_cache_performance(slow_queries),
      query_patterns: identify_query_patterns(slow_queries),
      top_offenders: find_top_offenders(slow_queries),
      performance_trends: analyze_performance_trends(slow_queries)
    }
  end

  @doc """
  Generates recommendations for slow query optimization.
  """
  def generate_slow_query_recommendations(analysis) do
    recommendations = []

    # Cache hit ratio recommendations
    recommendations =
      if analysis.cache_performance.avg_hit_ratio < 0.9 do
        [
          "Average cache hit ratio is #{Float.round(analysis.cache_performance.avg_hit_ratio * 100, 1)}% - consider increasing shared_buffers"
          | recommendations
        ]
      else
        recommendations
      end

    # High variability recommendations
    recommendations =
      if analysis.performance_trends.high_variability_queries > 0 do
        [
          "#{analysis.performance_trends.high_variability_queries} queries show high execution time variability - investigate for parameter sniffing or plan instability"
          | recommendations
        ]
      else
        recommendations
      end

    # Critical query recommendations
    recommendations =
      if analysis.severity_distribution.critical > 0 do
        [
          "#{analysis.severity_distribution.critical} critical slow queries detected - immediate optimization required"
          | recommendations
        ]
      else
        recommendations
      end

    # Pattern-based recommendations
    pattern_recommendations = generate_pattern_recommendations(analysis.query_patterns)
    recommendations ++ pattern_recommendations
  end

  @doc """
  Monitors query performance trends over time.
  """
  def monitor_performance_trends do
    query = """
    SELECT 
      date_trunc('hour', stats_reset) as hour,
      avg(mean_time) as avg_mean_time,
      max(mean_time) as max_mean_time,
      count(*) as query_count,
      sum(calls) as total_calls
    FROM pg_stat_statements
    WHERE mean_time > $1
    GROUP BY date_trunc('hour', stats_reset)
    ORDER BY hour DESC
    LIMIT 24
    """

    case Ecto.Adapters.SQL.query(Repo, query, [@slow_query_threshold_ms]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [hour, avg_mean, max_mean, query_count, total_calls] ->
          %{
            hour: hour,
            avg_execution_time: avg_mean,
            max_execution_time: max_mean,
            slow_query_count: query_count,
            total_executions: total_calls,
            performance_score: calculate_performance_score(avg_mean, max_mean, query_count)
          }
        end)

      {:error, error} ->
        Logger.warning("Failed to monitor performance trends: #{inspect(error)}")
        []
    end
  end

  @doc """
  Identifies queries that are getting slower over time.
  """
  def detect_performance_regressions do
    # This would compare current performance with historical baselines
    # For now, return queries with very high execution time variance
    query = """
    SELECT 
      query,
      mean_time,
      stddev_time,
      stddev_time / nullif(mean_time, 0) as coefficient_of_variation,
      calls
    FROM pg_stat_statements
    WHERE mean_time > $1
      AND stddev_time / nullif(mean_time, 0) > 0.5
    ORDER BY coefficient_of_variation DESC
    LIMIT 10
    """

    case Ecto.Adapters.SQL.query(Repo, query, [@slow_query_threshold_ms]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [query_text, mean_time, stddev_time, cov, calls] ->
          %{
            query: String.slice(query_text, 0, 200),
            mean_time_ms: mean_time,
            stddev_time_ms: stddev_time,
            variability_coefficient: cov,
            calls: calls,
            regression_risk: classify_regression_risk(cov, calls)
          }
        end)

      {:error, error} ->
        Logger.warning("Failed to detect performance regressions: #{inspect(error)}")
        []
    end
  end

  @doc """
  Gets detailed metrics for query performance monitoring.
  """
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
    UNION ALL
    SELECT 
      'critical_queries' as metric,
      count(*) as value
    FROM pg_stat_statements
    WHERE mean_time > $2
    """

    case Ecto.Adapters.SQL.query(Repo, query, [@slow_query_threshold_ms, @expensive_query_threshold_ms]) do
      {:ok, %{rows: rows}} ->
        metrics = Map.new(rows, fn [metric, value] -> {metric, value} end)
        
        Map.merge(metrics, %{
          "slow_query_ratio" => calculate_slow_query_ratio(metrics),
          "performance_health_score" => calculate_health_score(metrics)
        })

      {:error, _} ->
        %{}
    end
  end

  # Private helper functions

  defp classify_query_severity(mean_time, _total_time) do
    cond do
      mean_time > @expensive_query_threshold_ms -> "Critical"
      mean_time > @slow_query_threshold_ms * 3 -> "High"
      mean_time > @slow_query_threshold_ms * 2 -> "Medium"
      true -> "Low"
    end
  end

  defp analyze_severity_distribution(slow_queries) do
    distribution = Enum.group_by(slow_queries, & &1.severity)
    
    %{
      critical: length(Map.get(distribution, "Critical", [])),
      high: length(Map.get(distribution, "High", [])),
      medium: length(Map.get(distribution, "Medium", [])),
      low: length(Map.get(distribution, "Low", []))
    }
  end

  defp analyze_cache_performance(slow_queries) do
    if length(slow_queries) > 0 do
      hit_ratios = Enum.map(slow_queries, & &1.cache_hit_percent) |> Enum.reject(&is_nil/1)
      
      %{
        avg_hit_ratio: if(length(hit_ratios) > 0, do: Enum.sum(hit_ratios) / length(hit_ratios) / 100, else: 0),
        min_hit_ratio: if(length(hit_ratios) > 0, do: Enum.min(hit_ratios) / 100, else: 0),
        queries_with_poor_cache: Enum.count(hit_ratios, & &1 < 80)
      }
    else
      %{avg_hit_ratio: 1.0, min_hit_ratio: 1.0, queries_with_poor_cache: 0}
    end
  end

  defp identify_query_patterns(slow_queries) do
    patterns = %{
      select_queries: 0,
      insert_queries: 0,
      update_queries: 0,
      delete_queries: 0,
      join_heavy_queries: 0,
      aggregation_queries: 0
    }

    Enum.reduce(slow_queries, patterns, fn query, acc ->
      query_text = String.upcase(query.query)
      
      acc
      |> update_if_pattern(query_text, :select_queries, "SELECT")
      |> update_if_pattern(query_text, :insert_queries, "INSERT")
      |> update_if_pattern(query_text, :update_queries, "UPDATE")
      |> update_if_pattern(query_text, :delete_queries, "DELETE")
      |> update_if_pattern(query_text, :join_heavy_queries, "JOIN")
      |> update_if_pattern(query_text, :aggregation_queries, ["GROUP BY", "COUNT", "SUM", "AVG"])
    end)
  end

  defp update_if_pattern(acc, query_text, key, patterns) when is_list(patterns) do
    if Enum.any?(patterns, &String.contains?(query_text, &1)) do
      Map.update!(acc, key, &(&1 + 1))
    else
      acc
    end
  end

  defp update_if_pattern(acc, query_text, key, pattern) when is_binary(pattern) do
    if String.contains?(query_text, pattern) do
      Map.update!(acc, key, &(&1 + 1))
    else
      acc
    end
  end

  defp find_top_offenders(slow_queries) do
    slow_queries
    |> Enum.sort_by(& &1.total_time_ms, :desc)
    |> Enum.take(5)
    |> Enum.map(fn query ->
      %{
        query_snippet: String.slice(query.query, 0, 100),
        total_time_ms: query.total_time_ms,
        mean_time_ms: query.mean_time_ms,
        calls: query.calls,
        severity: query.severity
      }
    end)
  end

  defp analyze_performance_trends(slow_queries) do
    high_variability = Enum.count(slow_queries, fn query ->
      query.stddev_time_ms > 0 and query.mean_time_ms > 0 and
      query.stddev_time_ms / query.mean_time_ms > 0.5
    end)

    %{
      high_variability_queries: high_variability,
      avg_execution_time: if(length(slow_queries) > 0, do: Enum.sum(Enum.map(slow_queries, & &1.mean_time_ms)) / length(slow_queries), else: 0),
      total_execution_time: Enum.sum(Enum.map(slow_queries, & &1.total_time_ms))
    }
  end

  defp generate_pattern_recommendations(patterns) do
    recommendations = []

    recommendations =
      if patterns.join_heavy_queries > patterns.select_queries * 0.5 do
        ["High ratio of JOIN-heavy queries - review query design and indexing strategy" | recommendations]
      else
        recommendations
      end

    recommendations =
      if patterns.aggregation_queries > 5 do
        ["Multiple slow aggregation queries - consider summary tables or materialized views" | recommendations]
      else
        recommendations
      end

    recommendations =
      if patterns.update_queries + patterns.delete_queries > patterns.select_queries * 0.3 do
        ["High ratio of slow write operations - review locking and indexing on modified tables" | recommendations]
      else
        recommendations
      end

    recommendations
  end

  defp calculate_performance_score(avg_mean, max_mean, query_count) do
    # Simple scoring: lower is better
    base_score = 100
    avg_penalty = if avg_mean > @slow_query_threshold_ms, do: (avg_mean - @slow_query_threshold_ms) / 100, else: 0
    max_penalty = if max_mean > @expensive_query_threshold_ms, do: (max_mean - @expensive_query_threshold_ms) / 500, else: 0
    count_penalty = query_count * 2
    
    max(0, base_score - avg_penalty - max_penalty - count_penalty)
  end

  defp classify_regression_risk(coefficient_of_variation, calls) when is_number(coefficient_of_variation) do
    cond do
      coefficient_of_variation > 1.0 and calls > 100 -> "High"
      coefficient_of_variation > 0.7 and calls > 50 -> "Medium"
      coefficient_of_variation > 0.5 -> "Low"
      true -> "Minimal"
    end
  end

  defp classify_regression_risk(_, _), do: "Unknown"

  defp calculate_slow_query_ratio(metrics) do
    total = Map.get(metrics, "total_queries", 0)
    slow = Map.get(metrics, "slow_queries", 0)
    
    if total > 0, do: slow / total * 100, else: 0
  end

  defp calculate_health_score(metrics) do
    slow_ratio = calculate_slow_query_ratio(metrics)
    avg_time = Map.get(metrics, "avg_query_time_ms", 0)
    
    cond do
      slow_ratio < 1 and avg_time < 100 -> 95
      slow_ratio < 5 and avg_time < 500 -> 80
      slow_ratio < 10 and avg_time < 1000 -> 60
      slow_ratio < 20 -> 40
      true -> 20
    end
  end
end