defmodule EveDmv.Database.MaterializedViewManager.ViewMetrics do
  alias Ecto.Adapters.SQL
  alias EveDmv.Database.MaterializedViewManager.ViewDefinitions
  alias EveDmv.Repo

  require Logger
  @moduledoc """
  Provides performance metrics and analysis for materialized views.

  Tracks view size, refresh performance, query patterns, and provides
  recommendations for optimization.
  """



  @doc """
  Gets current status of all materialized views.
  """
  def get_view_status(views, last_refresh, refresh_stats) do
    view_info =
      Enum.map(ViewDefinitions.all_views(), fn view_def ->
        view_name = view_def.name
        status = Map.get(views, view_name, %{status: :unknown})

        %{
          name: view_name,
          status: status.status,
          last_refresh: status[:last_refresh],
          refresh_time_ms: status[:refresh_time_ms],
          dependencies: view_def.dependencies,
          refresh_strategy: view_def.refresh_strategy
        }
      end)

    %{
      views: view_info,
      last_global_refresh: last_refresh,
      refresh_stats: refresh_stats,
      total_views: length(ViewDefinitions.all_views())
    }
  end

  @doc """
  Analyzes performance of all materialized views.
  """
  def analyze_performance do
    query = """
    SELECT
      schemaname,
      matviewname,
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||matviewname)) as size,
      pg_total_relation_size(schemaname||'.'||matviewname) as size_bytes
    FROM pg_matviews
    WHERE schemaname = 'public'
    ORDER BY pg_total_relation_size(schemaname||'.'||matviewname) DESC
    """

    case SQL.query(Repo, query, []) do
      {:ok, %{rows: rows}} ->
        views =
          Enum.map(rows, fn [schema, name, size, size_bytes] ->
            %{
              schema: schema,
              name: name,
              size: size,
              size_bytes: size_bytes
            }
          end)

        {:ok, views}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets detailed metrics for a specific view.
  """
  def get_view_metrics(view_name) do
    with {:ok, size_info} <- get_view_size_info(view_name),
         {:ok, index_info} <- get_view_index_info(view_name),
         {:ok, column_stats} <- get_view_column_stats(view_name) do
      {:ok,
       %{
         view_name: view_name,
         size_metrics: size_info,
         index_metrics: index_info,
         column_statistics: column_stats,
         recommendations: generate_view_recommendations(size_info, index_info)
       }}
    end
  end

  @doc """
  Tracks refresh performance over time.
  """
  def track_refresh_performance(view_name, duration_ms, status, error \\ nil) do
    # In a production system, this would write to a metrics store
    metrics = %{
      view_name: view_name,
      timestamp: DateTime.utc_now(),
      duration_ms: duration_ms,
      status: status,
      error: error
    }

    Logger.info("View refresh metrics: #{inspect(metrics)}")
    metrics
  end

  @doc """
  Analyzes query patterns on materialized views.
  """
  def analyze_query_patterns do
    # This would analyze pg_stat_statements in production
    # For now, return mock data structure
    %{
      most_queried_views: [
        %{view: "character_activity_summary", query_count: 15_000, avg_time_ms: 12},
        %{view: "system_activity_summary", query_count: 8_500, avg_time_ms: 25},
        %{view: "alliance_statistics", query_count: 5_000, avg_time_ms: 18}
      ],
      slow_queries: [],
      optimization_opportunities: []
    }
  end

  @doc """
  Generates performance report for all views.
  """
  def generate_performance_report(views, refresh_stats) do
    with {:ok, size_analysis} <- analyze_performance(),
         {:ok, health_check} <- check_views_health() do
      %{
        generated_at: DateTime.utc_now(),
        summary: %{
          total_views: length(ViewDefinitions.all_views()),
          total_size: calculate_total_size(size_analysis),
          avg_refresh_time_ms: refresh_stats.avg_refresh_time_ms,
          failed_refresh_rate: calculate_failure_rate(refresh_stats)
        },
        view_details: merge_view_details(views, size_analysis),
        health_status: health_check,
        recommendations: generate_global_recommendations(size_analysis, refresh_stats)
      }
    end
  end

  @doc """
  Checks health of all materialized views.
  """
  def check_views_health do
    query = """
    SELECT
      matviewname,
      hasindexes,
      ispopulated,
      definition
    FROM pg_matviews
    WHERE schemaname = 'public'
    """

    case SQL.query(Repo, query, []) do
      {:ok, %{rows: rows}} ->
        health_data =
          Enum.map(rows, fn [name, has_indexes, is_populated, definition] ->
            %{
              view: name,
              has_indexes: has_indexes,
              is_populated: is_populated,
              definition_length: String.length(definition),
              health_score: calculate_health_score(has_indexes, is_populated)
            }
          end)

        overall_health = calculate_overall_health(health_data)

        {:ok,
         %{
           overall_score: overall_health,
           view_health: health_data,
           issues: identify_health_issues(health_data)
         }}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Estimates resource usage for view refreshes.
  """
  def estimate_refresh_resources do
    Enum.map(ViewDefinitions.all_views(), fn view_def ->
      with {:ok, size_info} <- get_view_size_info(view_def.name) do
        %{
          view_name: view_def.name,
          estimated_memory_mb: estimate_memory_usage(size_info),
          estimated_cpu_seconds: estimate_cpu_usage(size_info, view_def),
          estimated_io_mb: size_info.size_bytes / 1_048_576
        }
      else
        _ ->
          %{
            view_name: view_def.name,
            estimated_memory_mb: 0,
            estimated_cpu_seconds: 0,
            estimated_io_mb: 0
          }
      end
    end)
  end

  # Private helper functions

  defp get_view_size_info(view_name) do
    query = """
    SELECT
      pg_total_relation_size($1) as total_size,
      pg_relation_size($1) as table_size,
      pg_indexes_size($1) as indexes_size,
      (SELECT COUNT(*) FROM #{view_name}) as row_count
    """

    case SQL.query(Repo, query, [view_name]) do
      {:ok, %{rows: [[total_size, table_size, indexes_size, row_count]]}} ->
        {:ok,
         %{
           total_size: total_size,
           size_bytes: total_size,
           table_size: table_size,
           indexes_size: indexes_size,
           row_count: row_count,
           avg_row_size: if(row_count > 0, do: div(table_size, row_count), else: 0)
         }}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_view_index_info(view_name) do
    query = """
    SELECT
      indexname,
      pg_relation_size(indexname::regclass) as size,
      idx_scan,
      idx_tup_read,
      idx_tup_fetch
    FROM pg_stat_user_indexes
    WHERE schemaname = 'public' AND tablename = $1
    """

    case SQL.query(Repo, query, [view_name]) do
      {:ok, %{rows: rows}} ->
        indexes =
          Enum.map(rows, fn [name, size, scans, reads, fetches] ->
            %{
              name: name,
              size: size,
              scan_count: scans || 0,
              tuples_read: reads || 0,
              tuples_fetched: fetches || 0,
              efficiency: calculate_index_efficiency(scans, reads, fetches)
            }
          end)

        {:ok,
         %{
           index_count: length(indexes),
           total_index_size: Enum.sum(Enum.map(indexes, & &1.size)),
           indexes: indexes
         }}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_view_column_stats(view_name) do
    query = """
    SELECT
      attname,
      n_distinct,
      null_frac,
      avg_width
    FROM pg_stats
    WHERE schemaname = 'public' AND tablename = $1
    LIMIT 20
    """

    case SQL.query(Repo, query, [view_name]) do
      {:ok, %{rows: rows}} ->
        columns =
          Enum.map(rows, fn [name, distinct, null_frac, avg_width] ->
            %{
              column_name: name,
              distinct_values: distinct || -1,
              null_fraction: null_frac || 0.0,
              avg_width: avg_width || 0
            }
          end)

        {:ok, columns}

      {:error, error} ->
        {:error, error}
    end
  end

  defp generate_view_recommendations(size_info, index_info) do
    initial_recommendations = []

    # Check for missing indexes
    recs_with_indexes =
      if index_info.index_count == 0 do
        ["Consider adding indexes to improve query performance" | initial_recommendations]
      else
        initial_recommendations
      end

    # Check for oversized views
    # 1GB
    recs_with_size =
      if size_info.size_bytes > 1_073_741_824 do
        [
          "View size exceeds 1GB - consider partitioning or filtering old data"
          | recs_with_indexes
        ]
      else
        recs_with_indexes
      end

    # Check for inefficient indexes
    inefficient_indexes =
      Enum.map(Enum.filter(index_info.indexes, &(&1.efficiency < 0.5)), & &1.name)

    final_recommendations =
      if length(inefficient_indexes) > 0 do
        ["Review inefficient indexes: #{Enum.join(inefficient_indexes, ", ")}" | recs_with_size]
      else
        recs_with_size
      end

    final_recommendations
  end

  defp calculate_index_efficiency(nil, _, _), do: 0.0
  defp calculate_index_efficiency(0, _, _), do: 0.0

  defp calculate_index_efficiency(_scans, reads, fetches) do
    if reads > 0 do
      Float.round(fetches / reads, 2)
    else
      1.0
    end
  end

  defp calculate_total_size(size_analysis) do
    Enum.sum(Enum.map(size_analysis, & &1.size_bytes))
  end

  defp calculate_failure_rate(refresh_stats) do
    total = refresh_stats.total_refreshes

    if total > 0 do
      Float.round(refresh_stats.failed_refreshes / total * 100, 2)
    else
      0.0
    end
  end

  defp merge_view_details(views, size_analysis) do
    Enum.map(ViewDefinitions.all_views(), fn view_def ->
      view_status = Map.get(views, view_def.name, %{})
      size_info = Enum.find(size_analysis, &(&1.name == view_def.name))

      %{
        name: view_def.name,
        status: view_status[:status] || :unknown,
        last_refresh: view_status[:last_refresh],
        size: size_info[:size] || "unknown",
        size_bytes: size_info[:size_bytes] || 0,
        refresh_strategy: view_def.refresh_strategy
      }
    end)
  end

  defp calculate_health_score(has_indexes, is_populated) do
    # Base score
    base_score = 50
    with_indexes_score = if has_indexes, do: base_score + 30, else: base_score
    final_score = if is_populated, do: with_indexes_score + 20, else: with_indexes_score
    final_score
  end

  defp calculate_overall_health(health_data) do
    if length(health_data) > 0 do
      avg_score =
        Enum.map(health_data, & &1.health_score)
        |> Enum.sum()
        |> Kernel./(length(health_data))

      round(avg_score)
    else
      0
    end
  end

  defp identify_health_issues(health_data) do
    initial_issues = []

    # Check for unpopulated views
    unpopulated =
      Enum.map(Enum.filter(health_data, &(not &1.is_populated)), & &1.view)

    issues_with_unpopulated =
      if length(unpopulated) > 0 do
        ["Unpopulated views: #{Enum.join(unpopulated, ", ")}" | initial_issues]
      else
        initial_issues
      end

    # Check for views without indexes
    no_indexes =
      Enum.map(Enum.filter(health_data, &(not &1.has_indexes)), & &1.view)

    final_issues =
      if length(no_indexes) > 0 do
        ["Views without indexes: #{Enum.join(no_indexes, ", ")}" | issues_with_unpopulated]
      else
        issues_with_unpopulated
      end

    final_issues
  end

  defp generate_global_recommendations(size_analysis, refresh_stats) do
    total_size = calculate_total_size(size_analysis)
    failure_rate = calculate_failure_rate(refresh_stats)

    recommendation_list =
      []
      # Check total size (10GB)
      |> maybe_add_recommendation(
        total_size > 10_737_418_240,
        "Total materialized view size exceeds 10GB - review data retention policies"
      )
      # Check failure rate
      |> maybe_add_recommendation(
        failure_rate > 10.0,
        "High refresh failure rate (#{failure_rate}%) - investigate refresh errors"
      )
      # Check refresh time (5 minutes)
      |> maybe_add_recommendation(
        refresh_stats.avg_refresh_time_ms > 300_000,
        "Average refresh time exceeds 5 minutes - consider optimization"
      )

    if Enum.empty?(recommendation_list) do
      ["Materialized view system is performing well"]
    else
      recommendation_list
    end
  end

  defp maybe_add_recommendation(recommendation_list, condition, message) do
    if condition do
      [message | recommendation_list]
    else
      recommendation_list
    end
  end

  defp estimate_memory_usage(size_info) do
    # Rough estimate: 2x table size for refresh operations
    round(size_info.table_size * 2 / 1_048_576)
  end

  defp estimate_cpu_usage(size_info, view_def) do
    # Rough estimate based on complexity and size
    # 10k rows per second
    base_time = size_info.row_count / 10_000

    complexity_factor =
      case view_def.refresh_strategy do
        :incremental -> 0.5
        :concurrent -> 1.2
        _ -> 1.0
      end

    round(base_time * complexity_factor)
  end
end
