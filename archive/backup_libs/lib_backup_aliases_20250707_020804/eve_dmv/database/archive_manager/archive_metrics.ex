defmodule EveDmv.Database.ArchiveManager.ArchiveMetrics do
  @moduledoc """
  Provides metrics and monitoring for archive operations.

  Handles collection and reporting of archive performance metrics,
  storage statistics, and operational insights for monitoring and optimization.
  """

  alias Ecto.Adapters.SQL
  alias EveDmv.Database.ArchiveManager.ArchiveOperations
  alias EveDmv.Database.ArchiveManager.PartitionManager
  alias EveDmv.Repo

  require Logger

  @doc """
  Get comprehensive archive statistics for all tables.
  """
  def get_archive_table_statistics(archive_policies) do
    Logger.info("Collecting archive statistics")

    table_stats =
      Enum.reject(Enum.map(archive_policies, fn policy ->
        get_single_table_statistics(policy)
      end), &is_nil/1)

    %{
      generated_at: DateTime.utc_now(),
      total_tables: length(table_stats),
      table_statistics: table_stats,
      summary: calculate_summary_statistics(table_stats)
    }
  end

  @doc """
  Get current archive status for monitoring dashboards.
  """
  def get_current_archive_status(archive_policies, state) do
    %{
      archive_system_enabled: true,
      last_archive_check: state.last_archive_check,
      total_tables_managed: length(archive_policies),
      archive_stats: state.archive_stats,
      table_status: get_table_status_summary(archive_policies),
      storage_summary: get_storage_summary(archive_policies),
      recent_activity: get_recent_activity_summary(state)
    }
  end

  @doc """
  Get detailed statistics for a single table.
  """
  def get_single_table_statistics(policy) do
    archive_table = policy.archive_table
    source_table = policy.table

    # Get archive table info
    archive_info = PartitionManager.get_archive_table_size(archive_table)

    # Get source table info
    source_info = get_source_table_info(source_table)

    # Get temporal information
    temporal_info = get_temporal_information(policy)

    # Calculate efficiency metrics
    efficiency_metrics = calculate_efficiency_metrics(policy, archive_info, source_info)

    %{
      table_name: source_table,
      archive_table_name: archive_table,
      policy: %{
        archive_after_days: policy.archive_after_days,
        retention_years: policy.retention_years,
        compression_enabled: policy.compression,
        batch_size: policy.batch_size
      },
      source_table: source_info,
      archive_table: archive_info,
      temporal_info: temporal_info,
      efficiency_metrics: efficiency_metrics,
      last_updated: DateTime.utc_now()
    }
  rescue
    error ->
      Logger.error("Failed to get statistics for #{policy.table}: #{inspect(error)}")
      nil
  end

  @doc """
  Track archive operation performance metrics.
  """
  def track_archive_operation(table_name, operation_type, duration_ms, record_count) do
    metrics = %{
      table_name: table_name,
      operation_type: operation_type,
      duration_ms: duration_ms,
      record_count: record_count,
      records_per_second: if(duration_ms > 0, do: record_count / (duration_ms / 1000), else: 0),
      timestamp: DateTime.utc_now()
    }

    # In a real implementation, you'd store these metrics in a time-series database
    Logger.info("Archive operation metrics: #{inspect(metrics)}")

    # For now, just return the metrics
    metrics
  end

  @doc """
  Get performance trends over time.
  """
  def get_performance_trends(table_name, days_back \\ 30) do
    # Placeholder for time-series data analysis
    # In practice, this would query a metrics database

    %{
      table_name: table_name,
      period_days: days_back,
      trends: %{
        archive_speed_trend: "stable",
        volume_trend: "increasing",
        efficiency_trend: "improving"
      },
      averages: %{
        avg_records_per_operation: 25_000,
        avg_duration_ms: 30_000,
        avg_records_per_second: 833
      },
      recent_operations: []
    }
  end

  @doc """
  Calculate storage efficiency metrics.
  """
  def calculate_storage_efficiency(archive_policies) do
    _total_source_size = 0
    _total_archive_size = 0
    _total_compression_savings = 0

    storage_data =
      Enum.map(archive_policies, fn policy ->
        archive_info = PartitionManager.get_archive_table_size(policy.archive_table)
        source_info = get_source_table_info(policy.table)

        estimated_uncompressed_size =
          if policy.compression do
            # Estimate uncompressed size (compression typically saves 30-50%)
            round(archive_info.total_size * 1.4)
          else
            archive_info.total_size
          end

        compression_savings = estimated_uncompressed_size - archive_info.total_size

        %{
          table: policy.table,
          source_size: source_info.total_size,
          archive_size: archive_info.total_size,
          compression_enabled: policy.compression,
          compression_savings: compression_savings,
          efficiency_ratio:
            if(source_info.total_size > 0,
              do: archive_info.total_size / source_info.total_size,
              else: 0
            )
        }
      end)

    %{
      per_table: storage_data,
      totals: %{
        total_source_size: Enum.sum(Enum.map(storage_data, & &1.source_size)),
        total_archive_size: Enum.sum(Enum.map(storage_data, & &1.archive_size)),
        total_compression_savings: Enum.sum(Enum.map(storage_data, & &1.compression_savings)),
        overall_efficiency: calculate_overall_efficiency(storage_data)
      }
    }
  end

  @doc """
  Get archive health score for monitoring.
  """
  def calculate_archive_health_score(archive_policies) do
    health_factors =
      Enum.map(archive_policies, fn policy ->
        calculate_table_health_score(policy)
      end)

    avg_health = Enum.sum(health_factors) / length(health_factors)

    %{
      overall_score: round(avg_health),
      status: classify_health_status(avg_health),
      table_scores: Enum.zip(Enum.map(archive_policies, & &1.table), health_factors),
      recommendations: generate_health_recommendations(health_factors, archive_policies)
    }
  end

  # Private helper functions

  defp get_source_table_info(table_name) do
    query = """
    SELECT
      pg_total_relation_size($1) as total_size,
      pg_relation_size($1) as table_size,
      (SELECT count(*) FROM #{table_name}) as row_count
    """

    case SQL.query(Repo, query, [table_name]) do
      {:ok, %{rows: [[total_size, table_size, row_count]]}} ->
        %{
          total_size: total_size,
          table_size: table_size,
          row_count: row_count
        }

      {:error, _} ->
        %{total_size: 0, table_size: 0, row_count: 0}
    end
  end

  defp get_temporal_information(policy) do
    # Get oldest and newest records in archive
    date_query = """
    SELECT
      MIN(#{policy.date_column}) as oldest_record,
      MAX(#{policy.date_column}) as newest_record,
      MIN(archived_at) as first_archived,
      MAX(archived_at) as last_archived
    FROM #{policy.archive_table}
    """

    case SQL.query(Repo, date_query, []) do
      {:ok, %{rows: [[oldest, newest, first_arch, last_arch]]}} ->
        %{
          oldest_record: oldest,
          newest_record: newest,
          first_archived: first_arch,
          last_archived: last_arch,
          archive_span_days: calculate_date_span(oldest, newest)
        }

      {:error, _} ->
        %{
          oldest_record: nil,
          newest_record: nil,
          first_archived: nil,
          last_archived: nil,
          archive_span_days: 0
        }
    end
  end

  defp calculate_efficiency_metrics(policy, archive_info, source_info) do
    # Calculate various efficiency metrics
    eligible_count = ArchiveOperations.count_eligible_records(policy)

    archive_ratio =
      if source_info.row_count > 0 do
        archive_info.row_count / (source_info.row_count + archive_info.row_count)
      else
        0
      end

    storage_efficiency =
      if source_info.total_size > 0 do
        1 - archive_info.total_size / (source_info.total_size + archive_info.total_size)
      else
        0
      end

    %{
      archive_ratio: Float.round(archive_ratio, 4),
      storage_efficiency: Float.round(storage_efficiency, 4),
      records_pending_archive: eligible_count,
      avg_archived_record_size:
        if(archive_info.row_count > 0,
          do: div(archive_info.total_size, archive_info.row_count),
          else: 0
        ),
      compression_effectiveness: calculate_compression_effectiveness(policy, archive_info)
    }
  end

  defp calculate_compression_effectiveness(policy, archive_info) do
    if policy.compression and archive_info.row_count > 0 do
      # Estimate compression ratio based on typical PostgreSQL compression
      estimated_uncompressed = archive_info.total_size * 1.4
      compression_ratio = archive_info.total_size / estimated_uncompressed
      Float.round(compression_ratio, 3)
    else
      1.0
    end
  end

  defp calculate_date_span(nil, _), do: 0
  defp calculate_date_span(_, nil), do: 0

  defp calculate_date_span(start_date, end_date) do
    DateTime.diff(end_date, start_date, :day)
  end

  defp calculate_summary_statistics(table_stats) do
    if Enum.empty?(table_stats) do
      %{total_archived_records: 0, total_archive_size: 0, avg_efficiency: 0}
    else
      total_records = Enum.sum(Enum.map(table_stats, & &1.archive_table.row_count))
      total_size = Enum.sum(Enum.map(table_stats, & &1.archive_table.total_size))

      avg_efficiency =
        Enum.map(table_stats, & &1.efficiency_metrics.storage_efficiency)
        |> Enum.sum()
        |> Kernel./(length(table_stats))

      %{
        total_archived_records: total_records,
        total_archive_size: total_size,
        total_archive_size_formatted: format_bytes(total_size),
        avg_storage_efficiency: Float.round(avg_efficiency, 4),
        tables_with_compression: Enum.count(table_stats, & &1.policy.compression_enabled)
      }
    end
  end

  defp get_table_status_summary(archive_policies) do
    Enum.map(archive_policies, fn policy ->
      eligible_count = ArchiveOperations.count_eligible_records(policy)
      archive_size = PartitionManager.get_archive_table_size(policy.archive_table)

      %{
        table: policy.table,
        records_pending: eligible_count,
        archived_records: archive_size.row_count,
        needs_attention: eligible_count > 50_000
      }
    end)
  end

  defp get_storage_summary(archive_policies) do
    total_archive_size =
      Enum.sum(Enum.map(archive_policies, fn policy ->
        PartitionManager.get_archive_table_size(policy.archive_table).total_size
      end))

    %{
      total_archive_size: total_archive_size,
      total_archive_size_formatted: format_bytes(total_archive_size),
      compression_enabled_tables: Enum.count(archive_policies, & &1.compression)
    }
  end

  defp get_recent_activity_summary(state) do
    %{
      last_archive_date: state.archive_stats.last_archive_date,
      total_archived_rows: state.archive_stats.total_archived_rows,
      total_archived_tables: state.archive_stats.total_archived_tables,
      recent_operations: Enum.take(state.archive_stats.archive_history, 10)
    }
  end

  defp calculate_overall_efficiency(storage_data) do
    if length(storage_data) > 0 do
      avg_efficiency =
        Enum.map(storage_data, & &1.efficiency_ratio)
        |> Enum.sum()
        |> Kernel./(length(storage_data))

      Float.round(avg_efficiency, 4)
    else
      0.0
    end
  end

  defp calculate_table_health_score(policy) do
    # Health score based on multiple factors
    eligible_count = ArchiveOperations.count_eligible_records(policy)
    archive_info = PartitionManager.get_archive_table_size(policy.archive_table)

    # Scoring factors (0-100 each)
    backlog_score = calculate_backlog_score(eligible_count)
    size_score = calculate_size_score(archive_info.total_size)
    # Placeholder - would track recent archive activity
    activity_score = 85

    # Weighted average
    backlog_score * 0.4 + size_score * 0.3 + activity_score * 0.3
  end

  defp calculate_backlog_score(eligible_count) do
    cond do
      eligible_count == 0 -> 100
      eligible_count < 10_000 -> 90
      eligible_count < 50_000 -> 75
      eligible_count < 100_000 -> 60
      eligible_count < 500_000 -> 40
      true -> 20
    end
  end

  defp calculate_size_score(total_size) do
    # Score based on archive table size (larger is generally good, but not too large)
    size_gb = total_size / 1_073_741_824

    cond do
      # Very small archive
      size_gb < 0.1 -> 60
      # Small archive
      size_gb < 1 -> 80
      # Good size
      size_gb < 10 -> 100
      # Large but manageable
      size_gb < 50 -> 90
      # Very large
      size_gb < 100 -> 75
      # Extremely large
      true -> 60
    end
  end

  defp classify_health_status(avg_health) do
    cond do
      avg_health >= 90 -> "Excellent"
      avg_health >= 75 -> "Good"
      avg_health >= 60 -> "Fair"
      avg_health >= 40 -> "Poor"
      true -> "Critical"
    end
  end

  defp generate_health_recommendations(health_factors, archive_policies) do
    initial_recommendations = []

    # Check for low health scores
    low_health_tables =
      Enum.zip(health_factors, archive_policies)
      |> Enum.filter(fn {score, _policy} -> score < 60 end)
      |> Enum.map(fn {_score, policy} -> policy.table end)

    recs_with_low_health =
      if length(low_health_tables) > 0 do
        [
          "Review archive configuration for tables: #{Enum.join(low_health_tables, ", ")}"
          | initial_recommendations
        ]
      else
        initial_recommendations
      end

    # Check average health
    avg_health = Enum.sum(health_factors) / length(health_factors)

    final_recommendations =
      if avg_health < 70 do
        [
          "Overall archive system health is below optimal - consider review"
          | recs_with_low_health
        ]
      else
        recs_with_low_health
      end

    if Enum.empty?(final_recommendations) do
      ["Archive system health is good"]
    else
      final_recommendations
    end
  end

  defp format_bytes(bytes) when bytes >= 1_073_741_824 do
    "#{Float.round(bytes / 1_073_741_824, 2)} GB"
  end

  defp format_bytes(bytes) when bytes >= 1_048_576 do
    "#{Float.round(bytes / 1_048_576, 2)} MB"
  end

  defp format_bytes(bytes) when bytes >= 1024 do
    "#{Float.round(bytes / 1024, 2)} KB"
  end

  defp format_bytes(bytes) do
    "#{bytes} bytes"
  end
end
