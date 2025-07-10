defmodule EveDmv.Telemetry.PerformanceMonitor do
  @moduledoc """
  Performance monitoring utilities for tracking optimization impact.

  This module provides telemetry events and metrics tracking for
  database queries, API calls, and processing times.
  """

  alias EveDmv.Telemetry.PerformanceMonitor.ConnectionPoolMonitor
  alias EveDmv.Telemetry.PerformanceMonitor.DatabaseMetrics
  alias EveDmv.Telemetry.PerformanceMonitor.HealthMonitor
  alias EveDmv.Telemetry.PerformanceMonitor.IndexPartitionAnalyzer
  alias EveDmv.Telemetry.PerformanceMonitor.PerformanceTracker

  require Logger

  # Delegation to PerformanceTracker
  defdelegate track_query(query_name, fun), to: PerformanceTracker
  defdelegate track_api_call(service_name, endpoint, fun), to: PerformanceTracker
  defdelegate track_bulk_operation(operation_name, record_count, fun), to: PerformanceTracker
  defdelegate track_cache_access(cache_name, hit_or_miss), to: PerformanceTracker
  defdelegate track_database_metric(metric_name, value), to: PerformanceTracker
  defdelegate track_liveview_render(view_name, fun), to: PerformanceTracker

  @doc """
  Get performance metrics summary.
  """
  def get_performance_summary do
    %{
      database: DatabaseMetrics.get_database_metrics(),
      query_performance: DatabaseMetrics.get_slow_queries(),
      connection_pool: ConnectionPoolMonitor.get_pool_metrics(),
      cache_hit_rates: DatabaseMetrics.get_cache_metrics(),
      table_sizes: DatabaseMetrics.get_table_sizes(),
      index_usage: IndexPartitionAnalyzer.get_index_usage_stats(),
      partition_health: IndexPartitionAnalyzer.check_partition_health(),
      query_analysis: DatabaseMetrics.get_query_analysis(),
      n_plus_one_alerts: DatabaseMetrics.get_n_plus_one_detection()
    }
  end

  # Delegation to DatabaseMetrics
  defdelegate get_query_analysis(), to: DatabaseMetrics
  defdelegate get_n_plus_one_detection(), to: DatabaseMetrics

  # Delegation to HealthMonitor
  defdelegate monitor_database_health(), to: HealthMonitor
end
