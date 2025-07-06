defmodule EveDmv.Database.ArchiveManager.RestoreOperations do
  @moduledoc """
  Handles restore operations for moving data from archive tables back to active tables.

  Manages data restoration including validation, data integrity checks,
  and safe restoration of archived data when needed.
  """

  require Logger
  alias EveDmv.Repo
  alias EveDmv.Database.ArchiveManager.{PartitionManager, ArchiveOperations}
  alias Ecto.Adapters.SQL

  @doc """
  Restore data from archive within a date range.
  """
  def perform_archive_restore(table_name, start_date, end_date) do
    case ArchiveOperations.get_archive_policy(table_name) do
      {:ok, policy} ->
        restore_from_archive_table(policy, start_date, end_date)

      {:error, _} ->
        {:error, "No archive policy found for table: #{table_name}"}
    end
  end

  @doc """
  Restore data from an archive table back to the original table.
  """
  def restore_from_archive_table(policy, start_date, end_date) do
    Logger.info(
      "Starting restore from #{policy.archive_table} to #{policy.table} for period #{start_date} to #{end_date}"
    )

    # Validate date range
    if DateTime.compare(start_date, end_date) == :gt do
      {:error, "Start date must be before end date"}
    else
      perform_restore_operation(policy, start_date, end_date)
    end
  end

  @doc """
  Perform the actual restore operation with transaction safety.
  """
  def perform_restore_operation(policy, start_date, end_date) do
    Repo.transaction(fn ->
      # First, check if archive table exists
      if not PartitionManager.table_exists?(policy.archive_table) do
        Repo.rollback("Archive table #{policy.archive_table} does not exist")
      end

      # Get records to restore
      case select_archive_records(policy, start_date, end_date) do
        {:ok, records} when records != [] ->
          Logger.info("Found #{length(records)} records to restore")

          # Get original table columns to ensure compatibility
          case PartitionManager.get_original_table_columns(policy.table) do
            {:ok, columns} ->
              # Insert records back into original table
              case insert_restored_records(policy, records, columns) do
                {:ok, inserted_count} ->
                  # Mark records as restored in archive (optional)
                  mark_records_as_restored(policy, records)

                  Logger.info(
                    "Successfully restored #{inserted_count} records to #{policy.table}"
                  )

                  inserted_count

                {:error, error} ->
                  Repo.rollback("Failed to insert restored records: #{inspect(error)}")
              end

            {:error, error} ->
              Repo.rollback("Failed to get table structure: #{inspect(error)}")
          end

        {:ok, []} ->
          Logger.info("No records found in archive for the specified date range")
          0

        {:error, error} ->
          Repo.rollback("Failed to select archive records: #{inspect(error)}")
      end
    end)
  end

  @doc """
  Select records from archive table within date range.
  """
  def select_archive_records(policy, start_date, end_date) do
    query = """
    SELECT * FROM #{policy.archive_table}
    WHERE #{policy.date_column} >= $1
    AND #{policy.date_column} <= $2
    ORDER BY #{policy.date_column}
    """

    case SQL.query(Repo, query, [start_date, end_date]) do
      {:ok, %{rows: rows, columns: columns}} ->
        # Convert rows to maps for easier handling
        records =
          Enum.map(rows, fn row ->
            Enum.zip(columns, row)
            |> Enum.into(%{})
          end)

        {:ok, records}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Insert restored records back into the original table.
  """
  def insert_restored_records(policy, records, original_columns) do
    # Filter out archive-specific columns
    archive_specific_columns = ["archived_at", "archive_batch_id", "original_table_name"]

    filtered_records =
      Enum.map(records, fn record ->
        Enum.reject(record, fn {key, _value} ->
          to_string(key) in archive_specific_columns
        end)
      end)

    # Prepare batch insert
    case prepare_batch_insert(policy.table, filtered_records, original_columns) do
      {:ok, insert_sql, values} ->
        case SQL.query(Repo, insert_sql, values) do
          {:ok, %{num_rows: count}} ->
            {:ok, count}

          {:error, error} ->
            {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Mark records as restored in the archive table (adds a flag).
  """
  def mark_records_as_restored(policy, records) do
    # Extract primary keys
    pk_column = get_primary_key_column(policy.table)

    record_ids =
      Enum.map(records, fn record ->
        Map.get(record, pk_column) || Map.get(record, "id")
      end)

    # Add restored_at column if it doesn't exist
    ensure_restored_column_exists(policy.archive_table)

    # Update records to mark as restored
    placeholders = Enum.map_join(1..length(record_ids), ", ", &"$#{&1}")

    update_sql = """
    UPDATE #{policy.archive_table}
    SET restored_at = NOW()
    WHERE #{pk_column} IN (#{placeholders})
    """

    case SQL.query(Repo, update_sql, record_ids) do
      {:ok, _} ->
        Logger.debug("Marked #{length(record_ids)} records as restored")
        :ok

      {:error, error} ->
        Logger.warning("Failed to mark records as restored: #{inspect(error)}")
        :ok
    end
  end

  @doc """
  Validate archive integrity before restoration.
  """
  def validate_archive_integrity(table_name) do
    case ArchiveOperations.get_archive_policy(table_name) do
      {:ok, policy} ->
        perform_integrity_validation(policy)

      {:error, _} ->
        {:error, "No archive policy found for table: #{table_name}"}
    end
  end

  @doc """
  Check if archived data can be safely restored.
  """
  def check_restore_safety(policy, start_date, end_date) do
    # Check for overlapping data in original table
    overlap_query = """
    SELECT COUNT(*) FROM #{policy.table}
    WHERE #{policy.date_column} >= $1
    AND #{policy.date_column} <= $2
    """

    case SQL.query(Repo, overlap_query, [start_date, end_date]) do
      {:ok, %{rows: [[count]]}} when count > 0 ->
        {:warning, "#{count} overlapping records found in original table"}

      {:ok, %{rows: [[0]]}} ->
        :safe

      {:error, error} ->
        {:error, "Failed to check for overlapping data: #{inspect(error)}"}
    end
  end

  # Private helper functions

  defp prepare_batch_insert(table_name, records, original_columns) do
    if Enum.empty?(records) do
      {:ok, "", []}
    else
      # Get column names in the correct order
      column_names = Enum.map(original_columns, & &1.name)
      columns_str = Enum.join(column_names, ", ")

      # Prepare values and parameters
      {value_placeholders, all_values} = prepare_insert_values(records, column_names)

      insert_sql = """
      INSERT INTO #{table_name} (#{columns_str})
      VALUES #{value_placeholders}
      ON CONFLICT DO NOTHING
      """

      {:ok, insert_sql, all_values}
    end
  end

  defp prepare_insert_values(records, column_names) do
    {placeholders, values} =
      records
      |> Enum.with_index()
      |> Enum.map(fn {record, index} ->
        start_param = index * length(column_names) + 1

        row_values =
          Enum.map(column_names, fn col_name ->
            Map.get(record, col_name) || Map.get(record, String.to_existing_atom(col_name))
          end)

        row_placeholders =
          Enum.map(start_param..(start_param + length(column_names) - 1), &"$#{&1}")
          |> Enum.join(", ")

        {"(#{row_placeholders})", row_values}
      end)
      |> Enum.unzip()

    value_placeholders = Enum.join(placeholders, ", ")
    all_values = List.flatten(values)

    {value_placeholders, all_values}
  end

  defp ensure_restored_column_exists(archive_table) do
    sql = "ALTER TABLE #{archive_table} ADD COLUMN IF NOT EXISTS restored_at TIMESTAMP"

    case SQL.query(Repo, sql, []) do
      {:ok, _} -> :ok
      # Column might already exist
      {:error, _error} -> :ok
    end
  end

  defp get_primary_key_column(table_name) do
    # Simple heuristic - in practice you'd query the schema
    case table_name do
      "killmails_raw" -> "killmail_id"
      "killmails_enriched" -> "killmail_id"
      "participants" -> "id"
      "character_stats" -> "character_id"
      _ -> "id"
    end
  end

  defp perform_integrity_validation(policy) do
    validations = [
      check_archive_table_structure(policy),
      check_archive_data_consistency(policy),
      check_foreign_key_constraints(policy)
    ]

    case Enum.find(validations, &(not match?(:ok, &1))) do
      nil ->
        {:ok, "Archive integrity validation passed"}

      {:error, reason} ->
        {:error, reason}

      {:warning, message} ->
        {:warning, message}
    end
  end

  defp check_archive_table_structure(policy) do
    case PartitionManager.verify_table_structure(policy.table, policy.archive_table) do
      :ok -> :ok
      {:error, reason} -> {:error, "Table structure mismatch: #{reason}"}
    end
  end

  defp check_archive_data_consistency(policy) do
    # Check for duplicate records within archive
    query = """
    SELECT #{get_primary_key_column(policy.table)}, COUNT(*) as cnt
    FROM #{policy.archive_table}
    GROUP BY #{get_primary_key_column(policy.table)}
    HAVING COUNT(*) > 1
    LIMIT 5
    """

    case SQL.query(Repo, query, []) do
      {:ok, %{rows: []}} ->
        :ok

      {:ok, %{rows: duplicates}} ->
        duplicate_ids = Enum.map(duplicates, fn [id, _count] -> id end)
        {:warning, "Found duplicate records in archive: #{inspect(duplicate_ids)}"}

      {:error, error} ->
        {:error, "Failed to check data consistency: #{inspect(error)}"}
    end
  end

  defp check_foreign_key_constraints(_policy) do
    # Placeholder for foreign key validation
    # In practice, you'd check that foreign key references are still valid
    :ok
  end
end
