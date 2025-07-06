defmodule EveDmv.Database.ArchiveManager.PartitionManager do
  @moduledoc """
  Handles partition creation and table management for archive operations.

  Manages the creation, maintenance, and configuration of archive tables
  including structure creation, indexing, and compression setup.
  """

  require Logger
  alias EveDmv.Repo
  alias Ecto.Adapters.SQL

  @doc """
  Initialize all archive tables based on the archive policies.
  """
  def initialize_all_archive_tables(archive_policies) do
    Logger.info("Initializing archive tables")

    Enum.each(archive_policies, fn policy ->
      case ensure_archive_table_exists(policy) do
        :ok ->
          Logger.info("Archive table #{policy.archive_table} ready")

        {:error, error} ->
          Logger.error(
            "Failed to initialize archive table #{policy.archive_table}: #{inspect(error)}"
          )
      end
    end)

    :ok
  end

  @doc """
  Ensure that an archive table exists for the given policy.
  """
  def ensure_archive_table_exists(policy) do
    archive_table = policy.archive_table
    source_table = policy.table

    # Check if archive table exists
    if table_exists?(archive_table) do
      :ok
    else
      create_archive_table(source_table, archive_table, policy)
    end
  end

  @doc """
  Check if a table exists in the database.
  """
  def table_exists?(table_name) do
    query = """
    SELECT EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public'
      AND table_name = $1
    )
    """

    case SQL.query(Repo, query, [table_name]) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end

  @doc """
  Create an archive table with the same structure as the source table.
  """
  def create_archive_table(source_table, archive_table, policy) do
    # Create archive table with same structure as source
    create_sql = """
    CREATE TABLE #{archive_table} (LIKE #{source_table} INCLUDING ALL)
    """

    case SQL.query(Repo, create_sql, []) do
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

  @doc """
  Add archive-specific columns to an archive table.
  """
  def add_archive_columns(archive_table) do
    columns = [
      "ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP DEFAULT NOW()",
      "ADD COLUMN IF NOT EXISTS archive_batch_id UUID DEFAULT gen_random_uuid()",
      "ADD COLUMN IF NOT EXISTS original_table_name VARCHAR(255)"
    ]

    Enum.each(columns, fn column_def ->
      sql = "ALTER TABLE #{archive_table} #{column_def}"

      case SQL.query(Repo, sql, []) do
        {:ok, _} ->
          :ok

        {:error, error} ->
          Logger.warning("Failed to add archive column to #{archive_table}: #{inspect(error)}")
      end
    end)
  end

  @doc """
  Create indexes for an archive table based on the policy.
  """
  def create_archive_indexes(archive_table, policy) do
    indexes = [
      "CREATE INDEX IF NOT EXISTS idx_#{archive_table}_archived_at ON #{archive_table} (archived_at)",
      "CREATE INDEX IF NOT EXISTS idx_#{archive_table}_batch_id ON #{archive_table} (archive_batch_id)",
      "CREATE INDEX IF NOT EXISTS idx_#{archive_table}_date ON #{archive_table} (#{policy.date_column})"
    ]

    Enum.each(indexes, fn index_sql ->
      case SQL.query(Repo, index_sql, []) do
        {:ok, _} ->
          :ok

        {:error, error} ->
          Logger.warning("Failed to create archive index: #{inspect(error)}")
      end
    end)
  end

  @doc """
  Enable table compression for an archive table.
  """
  def enable_table_compression(table_name) do
    # PostgreSQL compression (if supported)
    sql = "ALTER TABLE #{table_name} SET (toast_tuple_target = 128)"

    case SQL.query(Repo, sql, []) do
      {:ok, _} ->
        Logger.info("Enabled compression for #{table_name}")

      {:error, error} ->
        Logger.warning("Could not enable compression for #{table_name}: #{inspect(error)}")
    end
  end

  @doc """
  Get the column structure of a table for restore operations.
  """
  def get_original_table_columns(table_name) do
    query = """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = $1
    AND column_name NOT IN ('archived_at', 'archive_batch_id', 'original_table_name')
    ORDER BY ordinal_position
    """

    case SQL.query(Repo, query, [table_name]) do
      {:ok, %{rows: rows}} ->
        columns =
          Enum.map(rows, fn [name, type, nullable, default] ->
            %{
              name: name,
              type: type,
              nullable: nullable == "YES",
              default: default
            }
          end)

        {:ok, columns}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Get table size information for monitoring.
  """
  def get_archive_table_size(archive_table) do
    query = """
    SELECT
      pg_total_relation_size($1) as total_size,
      pg_relation_size($1) as table_size,
      (SELECT count(*) FROM #{archive_table}) as row_count
    """

    case SQL.query(Repo, query, [archive_table]) do
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

  @doc """
  Drop an archive table (used for cleanup).
  """
  def drop_archive_table(table_name) do
    sql = "DROP TABLE IF EXISTS #{table_name} CASCADE"

    case SQL.query(Repo, sql, []) do
      {:ok, _} ->
        Logger.info("Dropped archive table: #{table_name}")
        :ok

      {:error, error} ->
        Logger.error("Failed to drop archive table #{table_name}: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Verify archive table structure matches source table.
  """
  def verify_table_structure(source_table, archive_table) do
    with {:ok, source_columns} <- get_table_columns(source_table),
         {:ok, archive_columns} <- get_archive_table_columns(archive_table) do
      # Filter out archive-specific columns
      archive_core_columns =
        Enum.reject(archive_columns, fn col ->
          col.name in ["archived_at", "archive_batch_id", "original_table_name"]
        end)

      if compare_column_structures(source_columns, archive_core_columns) do
        :ok
      else
        {:error, "Table structures do not match"}
      end
    else
      error -> error
    end
  end

  # Private helper functions

  defp get_table_columns(table_name) do
    query = """
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = $1
    ORDER BY ordinal_position
    """

    case SQL.query(Repo, query, [table_name]) do
      {:ok, %{rows: rows}} ->
        columns =
          Enum.map(rows, fn [name, type, nullable, default] ->
            %{name: name, type: type, nullable: nullable == "YES", default: default}
          end)

        {:ok, columns}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_archive_table_columns(table_name) do
    get_table_columns(table_name)
  end

  defp compare_column_structures(source_columns, archive_columns) do
    # Simple comparison - in practice you'd want more sophisticated matching
    length(source_columns) == length(archive_columns) and
      Enum.all?(Enum.zip(source_columns, archive_columns), fn {source, archive} ->
        source.name == archive.name and source.type == archive.type
      end)
  end
end
