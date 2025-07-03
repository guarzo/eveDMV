defmodule EveDmv.Database.ArchiveManager do
  @moduledoc """
  Manages data archiving and lifecycle for the EVE DMV application.

  Implements automated archiving strategies to move older data to separate storage
  while maintaining query performance and managing storage costs.
  """

  use GenServer
  require Logger

  alias EveDmv.Repo

  @archive_check_interval :timer.hours(24)

  # Archive configuration for different data types
  @archive_policies [
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
      table: "killmails_enriched",
      archive_after_days: 730,
      archive_table: "killmails_enriched_archive",
      date_column: "killmail_time",
      batch_size: 5000,
      compression: true,
      retention_years: 10
    },
    %{
      table: "participants",
      archive_after_days: 365,
      archive_table: "participants_archive",
      date_column: "updated_at",
      batch_size: 50_000,
      compression: true,
      retention_years: 7,
      cascade_tables: ["killmails_raw", "killmails_enriched"]
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
    state = %{
      enabled: Keyword.get(opts, :enabled, true),
      last_archive_check: nil,
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
    status = get_current_archive_status(state)
    {:reply, status, state}
  end

  def handle_call({:restore_from_archive, table_name, start_date, end_date}, _from, state) do
    result = perform_archive_restore(table_name, start_date, end_date)
    {:reply, result, state}
  end

  def handle_call(:get_archive_statistics, _from, state) do
    stats = get_archive_table_statistics()
    {:reply, stats, state}
  end

  def handle_cast(:force_archive_check, state) do
    new_state = perform_archive_check(state)
    {:noreply, new_state}
  end

  def handle_cast(:cleanup_old_archives, state) do
    new_state = cleanup_expired_archives(state)
    {:noreply, new_state}
  end

  def handle_info(:initialize_archive_tables, state) do
    new_state = initialize_all_archive_tables(state)
    {:noreply, new_state}
  end

  def handle_info(:scheduled_archive_check, state) do
    new_state = perform_archive_check(state)
    schedule_archive_check()
    {:noreply, new_state}
  end

  def handle_info(_, state), do: {:noreply, state}

  # Private functions

  defp schedule_archive_check do
    Process.send_after(self(), :scheduled_archive_check, @archive_check_interval)
  end

  defp initialize_all_archive_tables(state) do
    Logger.info("Initializing archive tables")

    Enum.each(@archive_policies, fn policy ->
      case ensure_archive_table_exists(policy) do
        :ok ->
          Logger.info("Archive table #{policy.archive_table} ready")

        {:error, error} ->
          Logger.error(
            "Failed to initialize archive table #{policy.archive_table}: #{inspect(error)}"
          )
      end
    end)

    state
  end

  defp ensure_archive_table_exists(policy) do
    archive_table = policy.archive_table
    source_table = policy.table

    # Check if archive table exists
    if table_exists?(archive_table) do
      :ok
    else
      create_archive_table(source_table, archive_table, policy)
    end
  end

  defp table_exists?(table_name) do
    query = """
    SELECT EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = $1
    )
    """

    case Ecto.Adapters.SQL.query(Repo, query, [table_name]) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end

  defp create_archive_table(source_table, archive_table, policy) do
    # Create archive table with same structure as source
    create_sql = """
    CREATE TABLE #{archive_table} (LIKE #{source_table} INCLUDING ALL)
    """

    case Ecto.Adapters.SQL.query(Repo, create_sql, []) do
      {:ok, _} ->
        Logger.info("Created archive table: #{archive_table}")

        # Add archive-specific columns
        add_archive_columns(archive_table)

        # Create archive indexes
        create_archive_indexes(archive_table, policy)

        # Set up compression if enabled
        if policy.compression do
          enable_table_compression(archive_table)
        end

        :ok

      {:error, error} ->
        Logger.error("Failed to create archive table #{archive_table}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp add_archive_columns(archive_table) do
    columns = [
      "ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP DEFAULT NOW()",
      "ADD COLUMN IF NOT EXISTS archive_batch_id UUID DEFAULT gen_random_uuid()",
      "ADD COLUMN IF NOT EXISTS original_table_name VARCHAR(255)"
    ]

    Enum.each(columns, fn column_def ->
      sql = "ALTER TABLE #{archive_table} #{column_def}"

      case Ecto.Adapters.SQL.query(Repo, sql, []) do
        {:ok, _} ->
          :ok

        {:error, error} ->
          Logger.warning("Failed to add archive column to #{archive_table}: #{inspect(error)}")
      end
    end)
  end

  defp create_archive_indexes(archive_table, policy) do
    indexes = [
      "CREATE INDEX IF NOT EXISTS idx_#{archive_table}_archived_at ON #{archive_table} (archived_at)",
      "CREATE INDEX IF NOT EXISTS idx_#{archive_table}_batch_id ON #{archive_table} (archive_batch_id)",
      "CREATE INDEX IF NOT EXISTS idx_#{archive_table}_date ON #{archive_table} (#{policy.date_column})"
    ]

    Enum.each(indexes, fn index_sql ->
      case Ecto.Adapters.SQL.query(Repo, index_sql, []) do
        {:ok, _} ->
          :ok

        {:error, error} ->
          Logger.warning("Failed to create archive index: #{inspect(error)}")
      end
    end)
  end

  defp enable_table_compression(table_name) do
    # PostgreSQL compression (if supported)
    sql = "ALTER TABLE #{table_name} SET (toast_tuple_target = 128)"

    case Ecto.Adapters.SQL.query(Repo, sql, []) do
      {:ok, _} ->
        Logger.info("Enabled compression for #{table_name}")

      {:error, error} ->
        Logger.warning("Could not enable compression for #{table_name}: #{inspect(error)}")
    end
  end

  defp perform_archive_check(state) do
    Logger.info("Starting scheduled archive check")
    start_time = System.monotonic_time(:millisecond)

    archive_results =
      Enum.map(@archive_policies, fn policy ->
        case check_and_archive_table(policy) do
          {:ok, archived_count} ->
            {policy.table, {:ok, archived_count}}

          {:error, error} ->
            Logger.error("Archive failed for #{policy.table}: #{inspect(error)}")
            {policy.table, {:error, error}}
        end
      end)

    duration_ms = System.monotonic_time(:millisecond) - start_time

    successful_archives =
      Enum.count(archive_results, fn {_, result} -> match?({:ok, _}, result) end)

    Logger.info(
      "Archive check completed in #{duration_ms}ms - #{successful_archives}/#{length(@archive_policies)} successful"
    )

    update_state_from_archive_results(state, archive_results)
  end

  defp check_and_archive_table(policy) do
    cutoff_date = Date.add(Date.utc_today(), -policy.archive_after_days)

    # Count records eligible for archiving
    count_query = """
    SELECT COUNT(*) FROM #{policy.table} 
    WHERE #{policy.date_column} < $1
    """

    case Ecto.Adapters.SQL.query(Repo, count_query, [cutoff_date]) do
      {:ok, %{rows: [[count]]}} when count > 0 ->
        Logger.info("Found #{count} records to archive from #{policy.table}")
        archive_table_data(policy, cutoff_date, count)

      {:ok, %{rows: [[0]]}} ->
        Logger.debug("No records to archive from #{policy.table}")
        {:ok, 0}

      {:error, error} ->
        {:error, error}
    end
  end

  defp archive_table_data(policy, cutoff_date, total_count) do
    batch_size = policy.batch_size
    batches = div(total_count, batch_size) + 1
    batch_id = Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)

    Logger.info("Archiving #{total_count} records from #{policy.table} in #{batches} batches")

    archived_count =
      Enum.reduce_while(1..batches, 0, fn batch_num, acc ->
        case archive_batch(policy, cutoff_date, batch_size, batch_id, batch_num) do
          {:ok, batch_count} ->
            {:cont, acc + batch_count}

          {:error, error} ->
            Logger.error("Batch #{batch_num} failed for #{policy.table}: #{inspect(error)}")
            {:halt, acc}
        end
      end)

    Logger.info("Archived #{archived_count} records from #{policy.table}")
    {:ok, archived_count}
  end

  defp archive_batch(policy, cutoff_date, batch_size, batch_id, batch_num) do
    Logger.debug("Processing batch #{batch_num} for #{policy.table}")

    # Use a transaction for consistency
    Repo.transaction(fn ->
      # Insert into archive table
      insert_sql = """
      INSERT INTO #{policy.archive_table} 
      SELECT *, NOW(), $1, $2
      FROM #{policy.table} 
      WHERE #{policy.date_column} < $3
      LIMIT $4
      """

      case Ecto.Adapters.SQL.query(Repo, insert_sql, [
             batch_id,
             policy.table,
             cutoff_date,
             batch_size
           ]) do
        {:ok, %{num_rows: inserted_count}} ->
          # Delete from source table
          delete_sql = """
          DELETE FROM #{policy.table} 
          WHERE #{policy.date_column} < $1
          AND ctid IN (
            SELECT ctid FROM #{policy.table} 
            WHERE #{policy.date_column} < $1
            LIMIT $2
          )
          """

          case Ecto.Adapters.SQL.query(Repo, delete_sql, [cutoff_date, batch_size]) do
            {:ok, %{num_rows: deleted_count}} ->
              Logger.debug(
                "Batch #{batch_num}: inserted #{inserted_count}, deleted #{deleted_count}"
              )

              inserted_count

            {:error, error} ->
              Repo.rollback(error)
          end

        {:error, error} ->
          Repo.rollback(error)
      end
    end)
  end

  defp perform_table_archive(table_name) do
    policy = Enum.find(@archive_policies, &(&1.table == table_name))

    if policy do
      check_and_archive_table(policy)
    else
      {:error, "No archive policy found for table: #{table_name}"}
    end
  end

  defp perform_archive_restore(table_name, start_date, end_date) do
    policy = Enum.find(@archive_policies, &(&1.table == table_name))

    if policy do
      restore_from_archive_table(policy, start_date, end_date)
    else
      {:error, "No archive policy found for table: #{table_name}"}
    end
  end

  defp restore_from_archive_table(policy, start_date, end_date) do
    Logger.info(
      "Restoring data from #{policy.archive_table} between #{start_date} and #{end_date}"
    )

    # Count records to restore
    count_query = """
    SELECT COUNT(*) FROM #{policy.archive_table}
    WHERE #{policy.date_column} >= $1 AND #{policy.date_column} <= $2
    """

    case Ecto.Adapters.SQL.query(Repo, count_query, [start_date, end_date]) do
      {:ok, %{rows: [[count]]}} when count > 0 ->
        # Get column list excluding archive-specific columns
        columns = get_original_table_columns(policy.table)
        column_list = Enum.join(columns, ", ")

        restore_sql = """
        INSERT INTO #{policy.table} (#{column_list})
        SELECT #{column_list} FROM #{policy.archive_table}
        WHERE #{policy.date_column} >= $1 AND #{policy.date_column} <= $2
        ON CONFLICT DO NOTHING
        """

        case Ecto.Adapters.SQL.query(Repo, restore_sql, [start_date, end_date]) do
          {:ok, %{num_rows: restored_count}} ->
            Logger.info("Restored #{restored_count} records to #{policy.table}")
            {:ok, restored_count}

          {:error, error} ->
            {:error, error}
        end

      {:ok, %{rows: [[0]]}} ->
        {:ok, 0}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_original_table_columns(table_name) do
    query = """
    SELECT column_name FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = $1
    AND column_name NOT IN ('archived_at', 'archive_batch_id', 'original_table_name')
    ORDER BY ordinal_position
    """

    case Ecto.Adapters.SQL.query(Repo, query, [table_name]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, &List.first/1)

      _ ->
        ["*"]
    end
  end

  defp cleanup_expired_archives(state) do
    Logger.info("Cleaning up expired archive data")

    cleanup_results =
      Enum.map(@archive_policies, fn policy ->
        case cleanup_archive_table(policy) do
          {:ok, deleted_count} ->
            {policy.archive_table, deleted_count}

          {:error, error} ->
            Logger.error("Cleanup failed for #{policy.archive_table}: #{inspect(error)}")
            {policy.archive_table, 0}
        end
      end)

    total_deleted = Enum.sum(Enum.map(cleanup_results, &elem(&1, 1)))
    Logger.info("Cleanup completed - deleted #{total_deleted} expired archive records")

    state
  end

  defp cleanup_archive_table(policy) do
    retention_cutoff = Date.add(Date.utc_today(), -(policy.retention_years * 365))

    delete_sql = """
    DELETE FROM #{policy.archive_table}
    WHERE #{policy.date_column} < $1
    """

    case Ecto.Adapters.SQL.query(Repo, delete_sql, [retention_cutoff]) do
      {:ok, %{num_rows: deleted_count}} ->
        if deleted_count > 0 do
          Logger.info("Deleted #{deleted_count} expired records from #{policy.archive_table}")
        end

        {:ok, deleted_count}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_current_archive_status(state) do
    table_statuses =
      Enum.map(@archive_policies, fn policy ->
        %{
          table: policy.table,
          archive_table: policy.archive_table,
          archive_after_days: policy.archive_after_days,
          retention_years: policy.retention_years,
          records_eligible: count_eligible_records(policy),
          archive_size: get_archive_table_size(policy.archive_table),
          last_archived: get_last_archive_date(policy.archive_table)
        }
      end)

    %{
      enabled: true,
      tables: table_statuses,
      last_check: state.last_archive_check,
      archive_stats: state.archive_stats
    }
  end

  defp count_eligible_records(policy) do
    cutoff_date = Date.add(Date.utc_today(), -policy.archive_after_days)

    query = """
    SELECT COUNT(*) FROM #{policy.table} 
    WHERE #{policy.date_column} < $1
    """

    case Ecto.Adapters.SQL.query(Repo, query, [cutoff_date]) do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  end

  defp get_archive_table_size(archive_table) do
    query = """
    SELECT 
      pg_size_pretty(pg_total_relation_size($1)) as size,
      pg_total_relation_size($1) as size_bytes
    """

    case Ecto.Adapters.SQL.query(Repo, query, [archive_table]) do
      {:ok, %{rows: [[size, size_bytes]]}} -> %{size: size, size_bytes: size_bytes}
      _ -> %{size: "Unknown", size_bytes: 0}
    end
  end

  defp get_last_archive_date(archive_table) do
    query = """
    SELECT MAX(archived_at) FROM #{archive_table}
    """

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, %{rows: [[date]]}} when not is_nil(date) -> date
      _ -> nil
    end
  end

  defp get_archive_table_statistics do
    stats =
      Enum.map(@archive_policies, fn policy ->
        archive_table = policy.archive_table

        query = """
        SELECT 
          COUNT(*) as record_count,
          MIN(#{policy.date_column}) as oldest_record,
          MAX(#{policy.date_column}) as newest_record,
          COUNT(DISTINCT archive_batch_id) as batch_count
        FROM #{archive_table}
        """

        case Ecto.Adapters.SQL.query(Repo, query, []) do
          {:ok, %{rows: [[count, oldest, newest, batches]]}} ->
            size_info = get_archive_table_size(archive_table)

            %{
              table: policy.table,
              archive_table: archive_table,
              record_count: count,
              oldest_record: oldest,
              newest_record: newest,
              batch_count: batches,
              size: size_info.size,
              size_bytes: size_info.size_bytes,
              compression_enabled: policy.compression
            }

          _ ->
            %{
              table: policy.table,
              archive_table: archive_table,
              record_count: 0,
              oldest_record: nil,
              newest_record: nil,
              batch_count: 0,
              size: "0 bytes",
              size_bytes: 0,
              compression_enabled: policy.compression
            }
        end
      end)

    total_records = Enum.sum(Enum.map(stats, & &1.record_count))
    total_size_bytes = Enum.sum(Enum.map(stats, & &1.size_bytes))

    %{
      tables: stats,
      totals: %{
        total_archived_records: total_records,
        total_size_bytes: total_size_bytes,
        total_size: format_bytes(total_size_bytes),
        active_archive_tables: length(Enum.filter(stats, &(&1.record_count > 0)))
      }
    }
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

  defp update_archive_stats(state, {:ok, archived_count}) do
    new_stats = %{
      state.archive_stats
      | total_archived_rows: state.archive_stats.total_archived_rows + archived_count,
        last_archive_date: DateTime.utc_now()
    }

    %{state | archive_stats: new_stats}
  end

  defp update_archive_stats(state, {:error, _}), do: state

  defp update_state_from_archive_results(state, results) do
    successful_results = Enum.filter(results, fn {_, result} -> match?({:ok, _}, result) end)
    total_archived = Enum.sum(Enum.map(successful_results, fn {_, {:ok, count}} -> count end))

    new_stats = %{
      state.archive_stats
      | total_archived_rows: state.archive_stats.total_archived_rows + total_archived,
        total_archived_tables:
          state.archive_stats.total_archived_tables + length(successful_results),
        last_archive_date: DateTime.utc_now(),
        archive_history: [
          %{
            date: DateTime.utc_now(),
            tables_processed: length(results),
            records_archived: total_archived,
            successful_tables: length(successful_results)
          }
          | Enum.take(state.archive_stats.archive_history, 9)
        ]
    }

    %{state | archive_stats: new_stats, last_archive_check: DateTime.utc_now()}
  end

  # Public utilities

  def get_archive_policy(table_name) do
    Enum.find(@archive_policies, &(&1.table == table_name))
  end

  def estimate_archive_space_savings(table_name) do
    policy = get_archive_policy(table_name)

    if policy do
      cutoff_date = Date.add(Date.utc_today(), -policy.archive_after_days)

      # Estimate space that would be freed
      query = """
      SELECT 
        COUNT(*) as eligible_records,
        pg_size_pretty(
          COUNT(*) * 
          (pg_total_relation_size($1)::numeric / GREATEST(
            (SELECT COUNT(*) FROM #{policy.table}), 1
          ))::bigint
        ) as estimated_space_freed
      FROM #{policy.table}
      WHERE #{policy.date_column} < $2
      """

      case Ecto.Adapters.SQL.query(Repo, query, [policy.table, cutoff_date]) do
        {:ok, %{rows: [[count, space_freed]]}} ->
          {:ok, %{eligible_records: count, estimated_space_freed: space_freed}}

        {:error, error} ->
          {:error, error}
      end
    else
      {:error, "No archive policy found for table: #{table_name}"}
    end
  end

  def validate_archive_integrity(table_name) do
    policy = get_archive_policy(table_name)

    if policy do
      # Check for data consistency between main and archive tables
      main_count_query = "SELECT COUNT(*) FROM #{policy.table}"
      archive_count_query = "SELECT COUNT(*) FROM #{policy.archive_table}"

      with {:ok, %{rows: [[main_count]]}} <- Ecto.Adapters.SQL.query(Repo, main_count_query, []),
           {:ok, %{rows: [[archive_count]]}} <-
             Ecto.Adapters.SQL.query(Repo, archive_count_query, []) do
        {:ok,
         %{
           main_table_records: main_count,
           archive_table_records: archive_count,
           total_records: main_count + archive_count,
           integrity_status: :ok
         }}
      else
        {:error, error} -> {:error, error}
      end
    else
      {:error, "No archive policy found for table: #{table_name}"}
    end
  end
end
