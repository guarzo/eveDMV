defmodule EveDmv.Database.PartitionAutomation do
  @moduledoc """
  Automated partition management for killmail tables.

  Provides functions to:
  - Ensure future partitions exist
  - Clean up old partitions based on retention policy
  - Monitor partition health and statistics
  - Manual partition management for edge cases
  """

  alias EveDmv.Repo
  require Logger

  @doc """
  Ensures that partitions exist for the next N months.
  Called by cron job and can be run manually.
  """
  @spec ensure_future_partitions(pos_integer()) :: {:ok, [String.t()]} | {:error, any()}
  def ensure_future_partitions(months_ahead \\ 3) do
    Logger.info("Creating partitions for next #{months_ahead} months")

    results =
      Enum.map(0..(months_ahead - 1), fn month_offset ->
        target_date = Date.add(Date.utc_today(), month_offset * 30)
        create_partition_for_month(target_date)
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil ->
        messages = Enum.map(results, fn {:ok, msg} -> msg end)
        {:ok, messages}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Creates a partition for a specific month if it doesn't exist.
  """
  @spec create_partition_for_month(Date.t()) :: {:ok, String.t()} | {:error, any()}
  def create_partition_for_month(%Date{} = target_date) do
    partition_name = generate_partition_name(target_date)
    {start_date, end_date} = generate_date_range(target_date)

    # Check if partition already exists
    if partition_exists?(partition_name) do
      {:ok, "Partition #{partition_name} already exists"}
    else
      try do
        create_partition_with_indexes(partition_name, start_date, end_date)
        Logger.info("Created partition #{partition_name} for range [#{start_date}, #{end_date})")
        {:ok, "Created partition #{partition_name}"}
      rescue
        error ->
          Logger.error("Failed to create partition #{partition_name}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  @doc """
  Cleans up old partitions based on retention policy.
  """
  @spec cleanup_old_partitions(pos_integer()) ::
          {:ok, {pos_integer(), [String.t()]}} | {:error, any()}
  def cleanup_old_partitions(retention_months \\ 12) do
    cutoff_date = Date.add(Date.utc_today(), -retention_months * 30)
    Logger.info("Cleaning up partitions older than #{cutoff_date} (#{retention_months} months)")

    try do
      old_partitions = find_old_partitions(cutoff_date)

      dropped_partitions =
        old_partitions
        |> Enum.map(&drop_partition/1)
        |> Enum.filter(&match?({:ok, _}, &1))
        |> Enum.map(fn {:ok, name} -> name end)

      Logger.info("Dropped #{length(dropped_partitions)} old partitions")
      {:ok, {length(dropped_partitions), dropped_partitions}}
    rescue
      error ->
        Logger.error("Failed to cleanup old partitions: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Gets statistics about current partitions.
  """
  @spec get_partition_stats() :: {:ok, map()} | {:error, any()}
  def get_partition_stats do
    query = """
    SELECT
      schemaname,
      tablename,
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
      (SELECT count(*) FROM (SELECT 1 FROM pg_class WHERE relname = tablename LIMIT 1000000) x) as approx_row_count
    FROM pg_tables
    WHERE tablename ~ '^killmails_raw_y[0-9]{4}m[0-9]{2}$'
    ORDER BY tablename;
    """

    case Repo.query(query) do
      {:ok, %{rows: rows, columns: columns}} ->
        stats =
          rows
          |> Enum.map(fn row ->
            columns |> Enum.zip(row) |> Enum.into(%{})
          end)

        summary = %{
          total_partitions: length(stats),
          partitions: stats,
          generated_at: DateTime.utc_now()
        }

        {:ok, summary}

      {:error, error} ->
        Logger.error("Failed to get partition stats: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Manual partition creation for specific date ranges.
  Useful for backfilling or handling edge cases.
  """
  @spec create_partition_for_date_range(Date.t(), Date.t()) :: {:ok, String.t()} | {:error, any()}
  def create_partition_for_date_range(%Date{} = start_date, %Date{} = end_date) do
    if Date.compare(start_date, end_date) >= 0 do
      {:error, "Start date must be before end date"}
    else
      partition_name =
        "killmails_raw_custom_#{Date.to_iso8601(start_date, :basic)}_#{Date.to_iso8601(end_date, :basic)}"

      try do
        create_partition_with_indexes(
          partition_name,
          Date.to_iso8601(start_date),
          Date.to_iso8601(end_date)
        )

        {:ok, "Created custom partition #{partition_name}"}
      rescue
        error ->
          {:error, error}
      end
    end
  end

  # Private functions

  defp generate_partition_name(%Date{year: year, month: month}) do
    month_str = String.pad_leading(Integer.to_string(month), 2, "0")
    "killmails_raw_y#{year}m#{month_str}"
  end

  defp generate_date_range(%Date{} = target_date) do
    start_date = target_date |> Date.beginning_of_month() |> Date.to_iso8601()

    end_date =
      target_date
      |> Date.beginning_of_month()
      |> Date.add(32)
      |> Date.beginning_of_month()
      |> Date.to_iso8601()
    {start_date, end_date}
  end

  defp partition_exists?(partition_name) do
    query = "SELECT 1 FROM pg_tables WHERE tablename = $1"

    case Repo.query(query, [partition_name]) do
      {:ok, %{num_rows: 0}} -> false
      {:ok, %{num_rows: _}} -> true
      _ -> false
    end
  end

  defp create_partition_with_indexes(partition_name, start_date, end_date) do
    # Create the partition
    Repo.query!("""
    CREATE TABLE #{partition_name}
    PARTITION OF killmails_raw
    FOR VALUES FROM ('#{start_date}') TO ('#{end_date}');
    """)

    # Create indexes
    Repo.query!("""
    CREATE INDEX #{partition_name}_system_time_idx
    ON #{partition_name} (solar_system_id, killmail_time);
    """)

    Repo.query!("""
    CREATE INDEX #{partition_name}_victim_time_idx
    ON #{partition_name} (victim_character_id, killmail_time);
    """)

    Repo.query!("""
    CREATE INDEX #{partition_name}_attacker_count_idx
    ON #{partition_name} (attacker_count, killmail_time);
    """)
  end

  defp find_old_partitions(cutoff_date) do
    # Find partitions older than cutoff date
    query =
      "SELECT tablename FROM pg_tables WHERE tablename ~ '^killmails_raw_y[0-9]{4}m[0-9]{2}$'"

    {:ok, %{rows: rows}} = Repo.query(query)

    rows
    |> List.flatten()
    |> Enum.filter(fn partition_name ->
      case extract_date_from_partition_name(partition_name) do
        {:ok, partition_date} -> Date.compare(partition_date, cutoff_date) == :lt
        _ -> false
      end
    end)
  end

  defp extract_date_from_partition_name(partition_name) do
    # Extract date from partition name format: killmails_raw_y2024m01
    case Regex.run(~r/killmails_raw_y(\d{4})m(\d{2})/, partition_name) do
      [_, year_str, month_str] ->
        year = String.to_integer(year_str)
        month = String.to_integer(month_str)
        {:ok, Date.new!(year, month, 1)}

      _ ->
        {:error, "Invalid partition name format"}
    end
  end

  defp drop_partition(partition_name) do
    try do
      Repo.query!("DROP TABLE #{partition_name}")
      Logger.info("Dropped partition #{partition_name}")
      {:ok, partition_name}
    rescue
      error ->
        Logger.warning("Failed to drop partition #{partition_name}: #{inspect(error)}")
        {:error, error}
    end
  end
end
