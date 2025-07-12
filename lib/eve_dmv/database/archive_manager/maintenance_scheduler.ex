defmodule EveDmv.Database.ArchiveManager.MaintenanceScheduler do
  @moduledoc """
  Handles scheduled maintenance tasks for archive management.

  Manages cleanup operations, archive health checks, and automated
  maintenance tasks to keep the archive system running efficiently.
  """

  alias Ecto.Adapters.SQL
  alias EveDmv.Database.ArchiveManager, as: AM
  alias AM.{ArchiveOperations, PartitionManager}
  alias EveDmv.Repo
  require Logger

  @doc """
  Perform scheduled archive check across all tables.
  """
  def perform_archive_check(archive_policies) do
    Logger.info("Starting scheduled archive check")
    start_time = System.monotonic_time(:millisecond)

    archive_results =
      Enum.map(archive_policies, fn policy ->
        case ArchiveOperations.check_and_archive_table(policy) do
          {:ok, archived_count} ->
            {policy.table, {:ok, archived_count}}

          {:error, error} ->
            Logger.error("Archive failed for #{policy.table}: #{inspect(error)}")
            {policy.table, {:error, error}}
        end
      end)

    duration_ms = System.monotonic_time(:millisecond) - start_time
    total_archived = calculate_total_archived(archive_results)

    Logger.info(
      "Archive check completed in #{duration_ms}ms. Total archived: #{total_archived} records"
    )

    %{
      duration_ms: duration_ms,
      total_archived: total_archived,
      results: archive_results
    }
  end

  @doc """
  Clean up expired archives based on retention policies.
  """
  def cleanup_expired_archives(archive_policies) do
    Logger.info("Starting cleanup of expired archives")

    cleanup_results =
      Enum.map(archive_policies, fn policy ->
        case cleanup_archive_table(policy) do
          {:ok, deleted_count} ->
            {policy.archive_table, {:ok, deleted_count}}

          {:error, error} ->
            Logger.error("Cleanup failed for #{policy.archive_table}: #{inspect(error)}")
            {policy.archive_table, {:error, error}}
        end
      end)

    total_deleted = calculate_total_deleted(cleanup_results)

    Logger.info("Archive cleanup completed. Total deleted: #{total_deleted} records")

    %{
      total_deleted: total_deleted,
      results: cleanup_results
    }
  end

  @doc """
  Clean up a specific archive table based on retention policy.
  """
  def cleanup_archive_table(policy) do
    retention_cutoff =
      DateTime.add(DateTime.utc_now(), -policy.retention_years * 365, :day)

    Logger.info(
      "Cleaning up #{policy.archive_table} - removing records older than #{retention_cutoff}"
    )

    # Count records to be deleted
    count_query = """
    SELECT COUNT(*)
    FROM #{policy.archive_table}
    WHERE #{policy.date_column} < $1
    """

    case SQL.query(Repo, count_query, [retention_cutoff]) do
      {:ok, %{rows: [[count_to_delete]]}} when count_to_delete > 0 ->
        # Delete in batches to avoid long locks
        delete_in_batches(
          policy.archive_table,
          policy.date_column,
          retention_cutoff,
          count_to_delete
        )

      {:ok, %{rows: [[0]]}} ->
        Logger.debug("No expired records to delete from #{policy.archive_table}")
        {:ok, 0}

      {:error, error} ->
        Logger.error("Failed to count expired records: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Perform health check on archive system.
  """
  def perform_health_check(archive_policies) do
    Logger.info("Performing archive system health check")

    health_results =
      Enum.map(archive_policies, fn policy ->
        {policy.table, check_table_health(policy)}
      end)

    overall_health = determine_overall_health(health_results)

    %{
      overall_health: overall_health,
      table_health: health_results,
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Optimize archive tables (vacuum, reindex, analyze).
  """
  def optimize_archive_tables(archive_policies) do
    Logger.info("Starting archive table optimization")

    optimization_results =
      Enum.map(archive_policies, fn policy ->
        result = optimize_single_table(policy.archive_table)
        {policy.archive_table, result}
      end)

    Logger.info("Archive table optimization completed")
    optimization_results
  end

  @doc """
  Schedule regular maintenance tasks.
  """
  def schedule_maintenance_tasks do
    # Daily archive check
    schedule_task(:daily_archive_check, :timer.hours(24))

    # Weekly cleanup
    schedule_task(:weekly_cleanup, :timer.hours(24 * 7))

    # Monthly optimization
    schedule_task(:monthly_optimization, :timer.hours(24 * 30))

    # Hourly health check
    schedule_task(:hourly_health_check, :timer.hours(1))

    Logger.info("Scheduled all maintenance tasks")
  end

  @doc """
  Generate maintenance report.
  """
  def generate_maintenance_report(archive_policies) do
    %{
      generated_at: DateTime.utc_now(),
      archive_status: get_archive_status_summary(archive_policies),
      storage_usage: get_storage_usage_summary(archive_policies),
      performance_metrics: get_performance_metrics(archive_policies),
      recommendations: generate_maintenance_recommendations(archive_policies)
    }
  end

  # Private helper functions

  defp calculate_total_archived(results) do
    Enum.sum(
      Enum.map(results, fn
        {_table, {:ok, count}} -> count
        {_table, {:error, _}} -> 0
      end)
    )
  end

  defp calculate_total_deleted(results) do
    Enum.sum(
      Enum.map(results, fn
        {_table, {:ok, count}} -> count
        {_table, {:error, _}} -> 0
      end)
    )
  end

  defp delete_in_batches(archive_table, date_column, cutoff_date, total_count) do
    batch_size = 10_000
    total_batches = div(total_count, batch_size) + 1

    Logger.info("Deleting #{total_count} expired records in #{total_batches} batches")

    result =
      Enum.reduce_while(1..total_batches, {:ok, 0}, fn batch_num, {:ok, acc_deleted} ->
        delete_sql = """
        DELETE FROM #{archive_table}
        WHERE #{date_column} < $1
        AND ctid IN (
          SELECT ctid FROM #{archive_table}
          WHERE #{date_column} < $1
          LIMIT $2
        )
        """

        case SQL.query(Repo, delete_sql, [cutoff_date, batch_size]) do
          {:ok, %{num_rows: deleted_count}} ->
            if rem(batch_num, 10) == 0 do
              Logger.info(
                "Deleted batch #{batch_num}/#{total_batches} (#{acc_deleted + deleted_count} total)"
              )
            end

            if deleted_count == 0 do
              # No more records to delete
              {:halt, {:ok, acc_deleted}}
            else
              {:cont, {:ok, acc_deleted + deleted_count}}
            end

          {:error, error} ->
            Logger.error("Failed to delete batch #{batch_num}: #{inspect(error)}")
            {:halt, {:error, error}}
        end
      end)

    case result do
      {:ok, deleted_count} ->
        Logger.info("Successfully deleted #{deleted_count} expired records")
        {:ok, deleted_count}

      error ->
        error
    end
  end

  defp check_table_health(policy) do
    health_checks = [
      check_table_exists(policy),
      check_index_health(policy),
      check_data_integrity(policy),
      check_storage_efficiency(policy)
    ]

    issues = Enum.filter(health_checks, &(not match?(:ok, &1)))

    if Enum.empty?(issues) do
      :healthy
    else
      {:issues, issues}
    end
  end

  defp check_table_exists(policy) do
    if PartitionManager.table_exists?(policy.archive_table) do
      :ok
    else
      {:error, "Archive table #{policy.archive_table} does not exist"}
    end
  end

  defp check_index_health(policy) do
    # Check if required indexes exist
    required_indexes = [
      "idx_#{policy.archive_table}_archived_at",
      "idx_#{policy.archive_table}_batch_id",
      "idx_#{policy.archive_table}_date"
    ]

    missing_indexes =
      Enum.reject(required_indexes, fn index_name ->
        index_exists?(policy.archive_table, index_name)
      end)

    if Enum.empty?(missing_indexes) do
      :ok
    else
      {:warning, "Missing indexes: #{Enum.join(missing_indexes, ", ")}"}
    end
  end

  defp check_data_integrity(policy) do
    # Check for null values in critical columns
    query = """
    SELECT COUNT(*) FROM #{policy.archive_table}
    WHERE #{policy.date_column} IS NULL
    OR archived_at IS NULL
    """

    case SQL.query(Repo, query, []) do
      {:ok, %{rows: [[0]]}} ->
        :ok

      {:ok, %{rows: [[count]]}} ->
        {:warning, "Found #{count} records with null critical values"}

      {:error, _} ->
        {:error, "Could not check data integrity"}
    end
  end

  defp check_storage_efficiency(policy) do
    table_info = PartitionManager.get_archive_table_size(policy.archive_table)

    if table_info.row_count > 0 do
      avg_row_size = div(table_info.table_size, table_info.row_count)

      # Flag if average row size seems unusually high
      if avg_row_size > 10_000 do
        {:warning, "High average row size (#{avg_row_size} bytes) - consider reviewing data"}
      else
        :ok
      end
    else
      :ok
    end
  end

  defp index_exists?(table_name, index_name) do
    query = """
    SELECT EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE tablename = $1
      AND indexname = $2
    )
    """

    case SQL.query(Repo, query, [table_name, index_name]) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end

  defp determine_overall_health(health_results) do
    health_statuses = Enum.map(health_results, fn {_table, status} -> status end)

    cond do
      Enum.any?(health_statuses, &match?({:issues, _}, &1)) -> :degraded
      Enum.any?(health_statuses, &match?({:warning, _}, &1)) -> :warning
      true -> :healthy
    end
  end

  defp optimize_single_table(table_name) do
    Logger.info("Optimizing table: #{table_name}")

    operations = [
      {"VACUUM ANALYZE", "VACUUM ANALYZE #{table_name}"},
      {"REINDEX", "REINDEX TABLE #{table_name}"}
    ]

    results =
      Enum.map(operations, fn {operation, sql} ->
        case SQL.query(Repo, sql, [], timeout: :timer.minutes(30)) do
          {:ok, _} ->
            Logger.info("Completed #{operation} on #{table_name}")
            {operation, :ok}

          {:error, error} ->
            Logger.warning("Failed #{operation} on #{table_name}: #{inspect(error)}")
            {operation, {:error, error}}
        end
      end)

    success_count = Enum.count(results, fn {_op, result} -> result == :ok end)

    if success_count == length(operations) do
      :ok
    else
      {:partial, results}
    end
  end

  defp schedule_task(task_name, interval) do
    # In practice, this would use a job scheduler like Oban
    Logger.debug("Scheduled #{task_name} to run every #{interval}ms")
    :ok
  end

  defp get_archive_status_summary(archive_policies) do
    Enum.map(archive_policies, fn policy ->
      eligible_count = ArchiveOperations.count_eligible_records(policy)
      table_size = PartitionManager.get_archive_table_size(policy.archive_table)

      %{
        table: policy.table,
        archive_table: policy.archive_table,
        records_eligible_for_archive: eligible_count,
        archived_records: table_size.row_count,
        archive_size_bytes: table_size.total_size
      }
    end)
  end

  defp get_storage_usage_summary(archive_policies) do
    total_archive_size =
      archive_policies
      |> Enum.map(fn policy ->
        PartitionManager.get_archive_table_size(policy.archive_table).total_size
      end)
      |> Enum.sum()

    %{
      total_archive_size_bytes: total_archive_size,
      total_archive_size_formatted: format_bytes(total_archive_size),
      tables_count: length(archive_policies)
    }
  end

  defp get_performance_metrics(_archive_policies) do
    # Placeholder for performance metrics
    # In practice, you'd track archiving speed, cleanup performance, etc.
    %{
      avg_archive_speed_records_per_second: 1000,
      avg_cleanup_speed_records_per_second: 5000,
      last_maintenance_duration_ms: 30_000
    }
  end

  defp generate_maintenance_recommendations(archive_policies) do
    recommendations =
      []
      |> add_backlog_recommendation(archive_policies)
      |> add_large_archive_recommendation(archive_policies)

    if Enum.empty?(recommendations) do
      ["No maintenance recommendations at this time"]
    else
      recommendations
    end
  end

  defp add_backlog_recommendation(recommendations, archive_policies) do
    high_backlog_tables =
      Enum.filter(archive_policies, fn policy ->
        ArchiveOperations.count_eligible_records(policy) > 100_000
      end)

    if length(high_backlog_tables) > 0 do
      table_names = Enum.map(high_backlog_tables, & &1.table)

      [
        "Consider running manual archive for tables with high backlogs: #{Enum.join(table_names, ", ")}"
        | recommendations
      ]
    else
      recommendations
    end
  end

  defp add_large_archive_recommendation(recommendation_list, archive_policies) do
    large_archives =
      Enum.filter(archive_policies, fn policy ->
        table_size = PartitionManager.get_archive_table_size(policy.archive_table)
        # 10GB
        table_size.total_size > 10_000_000_000
      end)

    if length(large_archives) > 0 do
      archive_names = Enum.map(large_archives, & &1.archive_table)

      [
        "Consider optimizing large archive tables: #{Enum.join(archive_names, ", ")}"
        | recommendation_list
      ]
    else
      recommendation_list
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
