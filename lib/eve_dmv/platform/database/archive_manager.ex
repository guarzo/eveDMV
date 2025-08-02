defmodule EveDmv.Database.ArchiveManager do
  @moduledoc """
  Manages data archiving and lifecycle for the EVE DMV application.

  Implements automated archiving strategies to move older data to separate storage
  while maintaining query performance and managing storage costs.
  """

  use GenServer

  alias EveDmv.Database.ArchiveManager.ArchiveMetrics
  alias EveDmv.Database.ArchiveManager.ArchiveOperations
  alias EveDmv.Database.ArchiveManager.MaintenanceScheduler
  alias EveDmv.Database.ArchiveManager.PartitionManager
  alias EveDmv.Database.ArchiveManager.RestoreOperations

  require Logger

  @archive_check_interval :timer.hours(24)

  # Archive configuration for different data types
  # Archive policies will be implemented in a future version

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def archive_table(table_name) when is_binary(table_name) do
    GenServer.call(__MODULE__, {:archive_table, table_name}, :timer.minutes(30))
  end

  def get_archive_status do
    GenServer.call(__MODULE__, :get_archive_status)
  end

  def force_archive_check do
    GenServer.cast(__MODULE__, :force_archive_check)
  end

  def restore_from_archive(table_name, start_date, end_date) do
    GenServer.call(
      __MODULE__,
      {:restore_from_archive, table_name, start_date, end_date},
      :timer.minutes(10)
    )
  end

  def get_archive_statistics do
    GenServer.call(__MODULE__, :get_archive_statistics)
  end

  def cleanup_old_archives do
    GenServer.cast(__MODULE__, :cleanup_old_archives)
  end

  # Server callbacks

  def init(opts) do
    archive_policies = get_archive_policies()

    state = %{
      enabled: Keyword.get(opts, :enabled, true),
      last_archive_check: nil,
      archive_policies: archive_policies,
      archive_stats: %{
        total_archived_rows: 0,
        total_archived_tables: 0,
        last_archive_date: nil,
        archive_history: []
      }
    }

    if state.enabled do
      # Initialize archive tables
      Process.send_after(self(), :initialize_archive_tables, :timer.seconds(60))
      schedule_archive_check()
    end

    {:ok, state}
  end

  def handle_call({:archive_table, table_name}, _from, state) do
    result = perform_table_archive(table_name)
    new_state = update_archive_stats(state, result)
    {:reply, result, new_state}
  end

  def handle_call(:get_archive_status, _from, state) do
    status = get_current_archive_status(state.archive_policies, state)
    {:reply, status, state}
  end

  def handle_call({:restore_from_archive, table_name, start_date, end_date}, _from, state) do
    result = perform_archive_restore(table_name, start_date, end_date)
    {:reply, result, state}
  end

  def handle_call(:get_archive_statistics, _from, state) do
    stats = get_archive_table_statistics(state.archive_policies)
    {:reply, stats, state}
  end

  def handle_cast(:force_archive_check, state) do
    check_result = perform_archive_check(state.archive_policies)
    new_state = update_state_from_archive_results(state, check_result)
    {:noreply, new_state}
  end

  def handle_cast(:cleanup_old_archives, state) do
    cleanup_result = cleanup_expired_archives(state.archive_policies)
    new_state = update_state_from_cleanup_results(state, cleanup_result)
    {:noreply, new_state}
  end

  def handle_info(:initialize_archive_tables, state) do
    initialize_all_archive_tables(state.archive_policies)
    {:noreply, state}
  end

  def handle_info(:scheduled_archive_check, state) do
    check_result = perform_archive_check(state.archive_policies)
    new_state = update_state_from_archive_results(state, check_result)
    schedule_archive_check()
    {:noreply, new_state}
  end

  def handle_info(_, state), do: {:noreply, state}

  # Private functions

  defp schedule_archive_check do
    Process.send_after(self(), :scheduled_archive_check, @archive_check_interval)
  end

  defdelegate initialize_all_archive_tables(archive_policies), to: PartitionManager

  # Delegation to PartitionManager
  defdelegate ensure_archive_table_exists(policy), to: PartitionManager
  defdelegate table_exists?(table_name), to: PartitionManager
  defdelegate create_archive_table(source_table, archive_table, policy), to: PartitionManager
  defdelegate add_archive_columns(archive_table), to: PartitionManager
  defdelegate create_archive_indexes(archive_table, policy), to: PartitionManager
  defdelegate enable_table_compression(table_name), to: PartitionManager

  defdelegate perform_archive_check(archive_policies), to: MaintenanceScheduler

  # Delegation to ArchiveOperations
  defdelegate check_and_archive_table(policy), to: ArchiveOperations
  defdelegate archive_table_data(policy, cutoff_date, total_count), to: ArchiveOperations

  defdelegate archive_batch(policy, cutoff_date, batch_size, batch_id, batch_num),
    to: ArchiveOperations

  defdelegate perform_table_archive(table_name), to: ArchiveOperations

  # Delegation to RestoreOperations
  defdelegate perform_archive_restore(table_name, start_date, end_date), to: RestoreOperations
  defdelegate restore_from_archive_table(policy, start_date, end_date), to: RestoreOperations
  defdelegate get_original_table_columns(table_name), to: PartitionManager

  # Delegation to MaintenanceScheduler
  defdelegate cleanup_expired_archives(archive_policies), to: MaintenanceScheduler
  defdelegate cleanup_archive_table(policy), to: MaintenanceScheduler

  # Delegation to ArchiveMetrics
  defdelegate get_current_archive_status(archive_policies, state), to: ArchiveMetrics
  defdelegate get_archive_table_statistics(archive_policies), to: ArchiveMetrics
  defdelegate format_bytes(bytes), to: ArchiveMetrics
  defdelegate get_last_archive_date(archive_table), to: ArchiveMetrics

  # Delegation to ArchiveOperations
  defdelegate count_eligible_records(policy), to: ArchiveOperations

  # Delegation to PartitionManager
  defdelegate get_archive_table_size(archive_table), to: PartitionManager

  # Delegation to ArchiveMetrics
  defdelegate update_archive_stats(state, result), to: ArchiveMetrics
  defdelegate update_state_from_archive_results(state, results), to: ArchiveMetrics

  # Public utilities - delegation to ArchiveMetrics
  defdelegate get_archive_policy(table_name), to: ArchiveOperations
  defdelegate estimate_archive_space_savings(table_name), to: ArchiveOperations
  defdelegate validate_archive_integrity(table_name), to: RestoreOperations

  # Helper functions for state management
  defp get_archive_policies do
    # Get archive policies from ArchiveOperations
    # This is a simplified approach - in practice you'd want to cache these
    [
      %{
        table: "killmails_raw",
        archive_after_days: 365,
        archive_table: "killmails_raw_archive",
        date_column: "killmail_time",
        batch_size: 10_000,
        compression: true,
        retention_years: 7
      },
      %{
        table: "participants",
        archive_after_days: 365,
        archive_table: "participants_archive",
        date_column: "updated_at",
        batch_size: 50_000,
        compression: true,
        retention_years: 7
      },
      %{
        table: "character_stats",
        archive_after_days: 90,
        archive_table: "character_stats_archive",
        date_column: "last_calculated_at",
        batch_size: 10_000,
        compression: false,
        retention_years: 2
      }
    ]
  end

  defp update_state_from_cleanup_results(state, _cleanup_result) do
    # Update state with cleanup results
    %{
      state
      | archive_stats: %{
          state.archive_stats
          | last_archive_date: DateTime.utc_now()
        }
    }
  end
end
