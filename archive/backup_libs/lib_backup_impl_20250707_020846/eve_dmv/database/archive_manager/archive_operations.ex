defmodule EveDmv.Database.ArchiveManager.ArchiveOperations do
  @moduledoc """
  Handles archive operations including data movement from active tables to archive tables.

  Manages the actual archiving process including batch processing, data validation,
  and transaction safety for moving data between tables.
  """

  alias EveDmv.Repo
  alias SQL
  require Logger

  @doc """
  Check if a table needs archiving and perform the archive operation.
  """
  def check_and_archive_table(policy) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -policy.archive_after_days, :day)

    # Check how many records need archiving
    count_query = """
    SELECT COUNT(*)
    FROM #{policy.table}
    WHERE #{policy.date_column} < $1
    """

    case SQL.query(Repo, count_query, [cutoff_date]) do
      {:ok, %{rows: [[total_count]]}} when total_count > 0 ->
        Logger.info(
          "Found #{total_count} records to archive from #{policy.table} (cutoff: #{cutoff_date})"
        )

        archive_table_data(policy, cutoff_date, total_count)

      {:ok, %{rows: [[0]]}} ->
        Logger.debug("No records to archive from #{policy.table}")
        {:ok, 0}

      {:error, error} ->
        Logger.error(
          "Failed to count records for archiving in #{policy.table}: #{inspect(error)}"
        )

        {:error, error}
    end
  end

  @doc """
  Archive data from a table in batches.
  """
  def archive_table_data(policy, cutoff_date, total_count) do
    batch_size = policy.batch_size
    total_batches = div(total_count, batch_size) + 1

    batch_id =
      System.unique_integer([:positive])
      |> to_string()

    Logger.info(
      "Starting archive process for #{policy.table}: #{total_count} records in #{total_batches} batches"
    )

    start_time = System.monotonic_time(:millisecond)

    result =
      1..total_batches
      |> Enum.reduce_while({:ok, 0}, fn batch_num, {:ok, acc_count} ->
        case archive_batch(policy, cutoff_date, batch_size, batch_id, batch_num) do
          {:ok, batch_count} ->
            if rem(batch_num, 10) == 0 do
              Logger.info(
                "Archived batch #{batch_num}/#{total_batches} for #{policy.table} (#{acc_count + batch_count} total)"
              )
            end

            {:cont, {:ok, acc_count + batch_count}}

          {:error, error} ->
            Logger.error(
              "Failed to archive batch #{batch_num} for #{policy.table}: #{inspect(error)}"
            )

            {:halt, {:error, error}}
        end
      end)

    duration_ms = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, archived_count} ->
        Logger.info(
          "Successfully archived #{archived_count} records from #{policy.table} in #{duration_ms}ms"
        )

        {:ok, archived_count}

      error ->
        error
    end
  end

  @doc """
  Archive a single batch of records.
  """
  def archive_batch(policy, cutoff_date, batch_size, batch_id, _batch_num) do
    Repo.transaction(fn ->
      # Select records to archive
      select_query = """
      SELECT * FROM #{policy.table}
      WHERE #{policy.date_column} < $1
      ORDER BY #{policy.date_column}
      LIMIT $2
      FOR UPDATE
      """

      case SQL.query(Repo, select_query, [cutoff_date, batch_size]) do
        {:ok, %{rows: rows, columns: columns}} when rows != [] ->
          # Insert into archive table
          case insert_into_archive(policy, rows, columns, batch_id) do
            {:ok, inserted_count} ->
              # Delete from source table
              ids_to_delete = extract_primary_keys(rows, columns, policy)

              case delete_archived_records(policy, ids_to_delete) do
                {:ok, deleted_count} ->
                  if inserted_count == deleted_count do
                    deleted_count
                  else
                    Repo.rollback(
                      "Mismatch: inserted #{inserted_count}, deleted #{deleted_count}"
                    )
                  end

                {:error, error} ->
                  Repo.rollback("Delete failed: #{inspect(error)}")
              end

            {:error, error} ->
              Repo.rollback("Insert failed: #{inspect(error)}")
          end

        {:ok, %{rows: []}} ->
          # No more records to archive
          0

        {:error, error} ->
          Repo.rollback("Select failed: #{inspect(error)}")
      end
    end)
  end

  @doc """
  Perform archive operation for a specific table.
  """
  def perform_table_archive(table_name) do
    case get_archive_policy(table_name) do
      {:ok, policy} ->
        check_and_archive_table(policy)

      {:error, _} ->
        {:error, "No archive policy found for table: #{table_name}"}
    end
  end

  @doc """
  Insert records into the archive table.
  """
  def insert_into_archive(policy, rows, columns, batch_id) do
    # Prepare column names (excluding archive-specific columns we'll add)
    base_columns = Enum.join(columns, ", ")

    # Prepare value placeholders
    value_placeholders =
      rows
      |> Enum.with_index(1)
      |> Enum.map_join(", ", fn {_row, index} ->
        start_param = (index - 1) * length(columns) + 1
        end_param = start_param + length(columns) - 1

        params = Enum.map(start_param..end_param, &"$#{&1}")
        values = Enum.join(params, ", ")

        "(#{values}, NOW(), '#{batch_id}', '#{policy.table}')"
      end)

    # Flatten all row values for parameters
    all_values = List.flatten(rows)

    insert_sql = """
    INSERT INTO #{policy.archive_table}
    (#{base_columns}, archived_at, archive_batch_id, original_table_name)
    VALUES #{value_placeholders}
    """

    case SQL.query(Repo, insert_sql, all_values) do
      {:ok, %{num_rows: count}} ->
        {:ok, count}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Extract primary key values from rows for deletion.
  """
  def extract_primary_keys(rows, columns, policy) do
    # Find the primary key column index (assuming 'id' or first column)
    pk_column = get_primary_key_column(policy.table)
    pk_index = Enum.find_index(columns, &(&1 == pk_column))

    if pk_index do
      Enum.map(rows, &Enum.at(&1, pk_index))
    else
      # Fallback: use first column
      Enum.map(rows, &List.first/1)
    end
  end

  @doc """
  Delete archived records from the source table.
  """
  def delete_archived_records(policy, ids) do
    pk_column = get_primary_key_column(policy.table)
    placeholders = Enum.map_join(1..length(ids), ", ", &"$#{&1}")

    delete_sql = """
    DELETE FROM #{policy.table}
    WHERE #{pk_column} IN (#{placeholders})
    """

    case SQL.query(Repo, delete_sql, ids) do
      {:ok, %{num_rows: count}} ->
        {:ok, count}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Get archive policy for a specific table.
  """
  def get_archive_policy(table_name) do
    # This would normally come from configuration or database
    # For now, return a basic policy structure
    policies = [
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

    case Enum.find(policies, &(&1.table == table_name)) do
      nil -> {:error, :not_found}
      policy -> {:ok, policy}
    end
  end

  @doc """
  Count records eligible for archiving.
  """
  def count_eligible_records(policy) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -policy.archive_after_days, :day)

    query = """
    SELECT COUNT(*)
    FROM #{policy.table}
    WHERE #{policy.date_column} < $1
    """

    case SQL.query(Repo, query, [cutoff_date]) do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  end

  @doc """
  Estimate space savings from archiving a table.
  """
  def estimate_archive_space_savings(table_name) do
    case get_archive_policy(table_name) do
      {:ok, policy} ->
        eligible_count = count_eligible_records(policy)

        # Get average row size
        size_query = """
        SELECT
          pg_relation_size($1) as table_size,
          (SELECT count(*) FROM #{table_name}) as total_rows
        """

        case SQL.query(Repo, size_query, [table_name]) do
          {:ok, %{rows: [[table_size, total_rows]]}} when total_rows > 0 ->
            avg_row_size = div(table_size, total_rows)
            estimated_space_freed = eligible_count * avg_row_size

            compression_ratio = if policy.compression, do: 0.7, else: 1.0
            archive_space_used = round(estimated_space_freed * compression_ratio)

            %{
              eligible_records: eligible_count,
              estimated_space_freed: estimated_space_freed,
              archive_space_used: archive_space_used,
              net_space_savings: estimated_space_freed - archive_space_used,
              compression_enabled: policy.compression
            }

          _ ->
            %{error: "Could not analyze table size"}
        end

      {:error, _} ->
        %{error: "No archive policy found for table"}
    end
  end

  # Private helper functions

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
end
