defmodule Mix.Tasks.Eve.CreateIndexesAsync do
  @moduledoc """
  Creates database indexes asynchronously with progress monitoring.

  This task is designed to handle large-scale index creation that might timeout
  in normal migrations, especially on production databases.

  ## Usage

      mix eve.create_indexes_async
      mix eve.create_indexes_async --migration 20250718035000
      mix eve.create_indexes_async --check-only

  ## Options

    * `--migration` - Run indexes from a specific migration file
    * `--check-only` - Only check if indexes exist, don't create them
    * `--timeout` - Set timeout in seconds (default: 3600)
  """

  use Mix.Task
  require Logger

  alias EveDmv.Repo

  @shortdoc "Creates database indexes asynchronously with progress monitoring"

  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          migration: :string,
          check_only: :boolean,
          timeout: :integer
        ]
      )

    # Convert to milliseconds
    timeout = Keyword.get(opts, :timeout, 3600) * 1000
    check_only = Keyword.get(opts, :check_only, false)
    migration = Keyword.get(opts, :migration)

    Logger.info("Starting async index creation (timeout: #{timeout}ms)")

    indexes =
      if migration do
        get_indexes_from_migration(migration)
      else
        get_pending_indexes()
      end

    if check_only do
      check_indexes(indexes)
    else
      create_indexes_async(indexes, timeout)
    end
  end

  defp get_pending_indexes do
    # Get all indexes that need to be created
    [
      # Sprint 16 indexes
      %{
        name: "idx_killmails_system_time_battle_analysis",
        table: "killmails_raw",
        columns: ["solar_system_id", "killmail_time DESC"],
        where: "killmail_time >= '2024-01-01'::timestamp",
        comment: "Battle detection time range queries"
      },
      %{
        name: "idx_killmails_isk_participants_threat",
        table: "killmails_raw",
        columns: ["killmail_time DESC", "solar_system_id"],
        where: "raw_data ? 'zkb' AND (raw_data->'zkb'->>'totalValue')::bigint > 100000000",
        comment: "ISK destruction analysis"
      },
      # Sprint 17 indexes
      %{
        name: "killmails_raw_time_system_idx",
        table: "killmails_raw",
        columns: ["killmail_time", "solar_system_id"],
        where: nil,
        comment: "Optimizes battle detection spatial-temporal queries"
      },
      %{
        name: "killmails_raw_character_activity_idx",
        table: "killmails_raw",
        columns: ["victim_character_id", "killmail_time"],
        where: nil,
        comment: "Speeds up character activity timeline queries"
      },
      %{
        name: "killmails_raw_corp_alliance_idx",
        table: "killmails_raw",
        columns: ["victim_corporation_id", "victim_alliance_id"],
        where: nil,
        comment: "Optimizes affiliation-based battle queries"
      },
      %{
        name: "killmails_raw_corp_alliance_time_idx",
        table: "killmails_raw",
        columns: ["victim_corporation_id", "victim_alliance_id", "killmail_time"],
        where: nil,
        comment: "Supports complex affiliation and time-based queries"
      },
      %{
        name: "participants_character_activity_idx",
        table: "participants",
        columns: ["character_id", "killmail_time"],
        where: nil,
        comment: "Character activity tracking for battle participation"
      },
      %{
        name: "participants_corp_alliance_idx",
        table: "participants",
        columns: ["corporation_id", "alliance_id"],
        where: nil,
        comment: "Affiliation queries for battle participants"
      }
    ]
  end

  defp get_indexes_from_migration(migration_id) do
    # TODO: Parse migration file to extract index definitions
    Logger.info("Loading indexes from migration: #{migration_id}")
    get_pending_indexes()
  end

  defp check_indexes(indexes) do
    Logger.info("Checking #{length(indexes)} indexes...")

    Enum.each(indexes, fn index ->
      exists = index_exists?(index.name)
      status = if exists, do: "✓", else: "✗"
      Logger.info("#{status} #{index.name} on #{index.table}")
    end)
  end

  defp create_indexes_async(indexes, timeout) do
    Logger.info("Creating #{length(indexes)} indexes asynchronously...")

    # Group indexes by table to avoid conflicts
    grouped = Enum.group_by(indexes, & &1.table)

    Enum.each(grouped, fn {table, table_indexes} ->
      Logger.info("Processing #{length(table_indexes)} indexes for table: #{table}")

      Enum.each(table_indexes, fn index ->
        if index_exists?(index.name) do
          Logger.info("✓ Index #{index.name} already exists, skipping...")
        else
          create_index_with_progress(index, timeout)
        end
      end)
    end)

    Logger.info("Index creation complete!")
  end

  defp create_index_with_progress(index, timeout) do
    Logger.info("Creating index: #{index.name}...")
    Logger.info("  Table: #{index.table}")
    Logger.info("  Columns: #{inspect(index.columns)}")
    if index.where, do: Logger.info("  Where: #{index.where}")
    Logger.info("  Comment: #{index.comment}")

    # Build the CREATE INDEX statement
    columns_sql = Enum.join(index.columns, ", ")
    where_clause = if index.where, do: "\nWHERE #{index.where}", else: ""

    sql = """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS #{index.name}
    ON #{index.table} (#{columns_sql})#{where_clause}
    """

    # Start async task with progress monitoring
    task =
      Task.async(fn ->
        start_time = System.monotonic_time(:millisecond)

        # Set statement timeout for this specific query
        Repo.query!("SET statement_timeout = '#{timeout}ms'")

        try do
          # Run the index creation
          result = Repo.query!(sql)

          elapsed = System.monotonic_time(:millisecond) - start_time
          Logger.info("✓ Index #{index.name} created successfully in #{elapsed}ms")

          {:ok, result}
        rescue
          error ->
            elapsed = System.monotonic_time(:millisecond) - start_time

            Logger.error(
              "✗ Failed to create index #{index.name} after #{elapsed}ms: #{inspect(error)}"
            )

            {:error, error}
        after
          # Reset statement timeout
          Repo.query!("RESET statement_timeout")
        end
      end)

    # Monitor progress in a separate process
    monitor_task =
      Task.async(fn ->
        monitor_index_progress(index.name, index.table)
      end)

    # Wait for the index creation to complete
    # Add buffer for cleanup
    result = Task.await(task, timeout + 5000)

    # Stop monitoring
    Task.shutdown(monitor_task, :brutal_kill)

    result
  end

  defp monitor_index_progress(index_name, table_name) do
    # Check progress every 10 seconds
    Process.sleep(10_000)

    # Query pg_stat_progress_create_index for progress info
    progress_sql = """
    SELECT 
      phase,
      blocks_total,
      blocks_done,
      tuples_total,
      tuples_done,
      CASE 
        WHEN blocks_total > 0 THEN 
          ROUND((blocks_done::numeric / blocks_total::numeric) * 100, 2)
        ELSE 0
      END as percent_complete
    FROM pg_stat_progress_create_index
    WHERE relid::regclass::text = $1
    """

    case Repo.query(progress_sql, [table_name]) do
      {:ok, %{rows: [[phase, blocks_total, blocks_done, _tuples_total, _tuples_done, percent]]}} ->
        Logger.info(
          "  Progress: #{phase} - #{percent}% complete (#{blocks_done}/#{blocks_total} blocks)"
        )

      _ ->
        # No progress info available
        :ok
    end

    # Continue monitoring
    monitor_index_progress(index_name, table_name)
  end

  defp index_exists?(index_name) do
    sql = """
    SELECT EXISTS (
      SELECT 1 FROM pg_indexes 
      WHERE indexname = $1
    )
    """

    case Repo.query(sql, [index_name]) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end
end
