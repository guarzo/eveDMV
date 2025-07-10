defmodule EveDmv.Database.PartitionManager do
  @moduledoc """
  Manages automated partition creation, maintenance, and cleanup for time-partitioned tables.

  Handles monthly partitions for killmails_raw table,
  automatically creating future partitions and managing partition lifecycle.
  """

  use GenServer

  alias Ecto.Adapters.SQL
  alias EveDmv.Repo

  require Logger

  @partition_check_interval :timer.hours(24)
  @partitioned_tables [
    %{
      table: "killmails_raw",
      date_column: "killmail_time",
      partition_interval: :monthly,
      # Keep 3 years of data
      retention_months: 36
    }
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def create_partitions_for_date(table, date) do
    GenServer.call(__MODULE__, {:create_partitions, table, date})
  end

  def cleanup_old_partitions(table) do
    GenServer.call(__MODULE__, {:cleanup_partitions, table})
  end

  def get_partition_status do
    GenServer.call(__MODULE__, :get_partition_status)
  end

  def force_maintenance do
    GenServer.cast(__MODULE__, :force_maintenance)
  end

  # Server callbacks

  def init(opts) do
    state = %{
      enabled: Keyword.get(opts, :enabled, true),
      last_maintenance: nil,
      partition_status: %{},
      created_partitions: [],
      dropped_partitions: []
    }

    if state.enabled do
      # Schedule initial maintenance after startup
      Process.send_after(self(), :perform_maintenance, :timer.seconds(30))
      schedule_maintenance()
    end

    {:ok, state}
  end

  def handle_call({:create_partitions, table, date}, _from, state) do
    result = create_partition_for_table_and_date(table, date)
    {:reply, result, state}
  end

  def handle_call({:cleanup_partitions, table}, _from, state) do
    result = cleanup_old_partitions_for_table(table)
    {:reply, result, state}
  end

  def handle_call(:get_partition_status, _from, state) do
    status = get_current_partition_status()
    {:reply, status, state}
  end

  def handle_cast(:force_maintenance, state) do
    new_state = perform_partition_maintenance(state)
    {:noreply, new_state}
  end

  def handle_info(:perform_maintenance, state) do
    new_state = perform_partition_maintenance(state)
    schedule_maintenance()
    {:noreply, new_state}
  end

  def handle_info(_, state), do: {:noreply, state}

  # Private functions

  defp schedule_maintenance do
    Process.send_after(self(), :perform_maintenance, @partition_check_interval)
  end

  defp perform_partition_maintenance(state) do
    Logger.info("Starting partition maintenance")
    start_time = System.monotonic_time(:millisecond)

    results = Enum.map(@partitioned_tables, &maintain_table_partitions/1)

    duration_ms = System.monotonic_time(:millisecond) - start_time
    Logger.info("Partition maintenance completed in #{duration_ms}ms")

    %{
      state
      | last_maintenance: DateTime.utc_now(),
        partition_status: Map.new(results, fn {table, status} -> {table, status} end)
    }
  end

  defp maintain_table_partitions(table_config) do
    table = table_config.table

    try do
      # Create future partitions (next 2 months)
      future_partitions = create_future_partitions(table_config)

      # Cleanup old partitions based on retention policy
      cleaned_partitions = cleanup_old_partitions_for_table(table)

      # Get current partition status
      existing_partitions = list_existing_partitions(table)

      status = %{
        table: table,
        existing_partitions: length(existing_partitions),
        created_partitions: length(future_partitions),
        cleaned_partitions: length(cleaned_partitions),
        last_maintained: DateTime.utc_now(),
        status: :healthy
      }

      Logger.info(
        "Maintained partitions for #{table}: created #{length(future_partitions)}, cleaned #{length(cleaned_partitions)}"
      )

      {table, status}
    rescue
      error ->
        Logger.error("Failed to maintain partitions for #{table}: #{inspect(error)}")

        {table,
         %{
           table: table,
           status: :error,
           error: inspect(error),
           last_maintained: DateTime.utc_now()
         }}
    end
  end

  defp create_future_partitions(table_config) do
    current_date = Date.utc_today()

    # Create partitions for current month and next 2 months
    future_dates = [
      current_date,
      # Approximately next month
      Date.add(current_date, 30),
      # Approximately month after
      Date.add(current_date, 60)
    ]

    Enum.flat_map(future_dates, fn date ->
      case create_partition_for_table_and_date(table_config.table, date) do
        {:ok, partition_name} -> [partition_name]
        {:exists, _} -> []
        {:error, _} -> []
      end
    end)
  end

  defp create_partition_for_table_and_date(table, date) do
    partition_name = generate_partition_name(table, date)

    # Check if partition already exists
    if partition_exists?(partition_name) do
      {:exists, partition_name}
    else
      create_partition(table, partition_name, date)
    end
  end

  defp generate_partition_name(table, date) do
    year = date.year
    month = String.pad_leading(to_string(date.month), 2, "0")
    "#{table}_y#{year}m#{month}"
  end

  defp partition_exists?(partition_name) do
    query = """
    SELECT EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public'
      AND table_name = $1
    )
    """

    case SQL.query(Repo, query, [partition_name]) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end

  defp create_partition(table, partition_name, date) do
    start_of_month = Date.beginning_of_month(date)
    end_of_month = Date.end_of_month(date)

    # Convert to datetime strings for PostgreSQL
    start_datetime = "#{start_of_month} 00:00:00"
    end_datetime = "#{Date.add(end_of_month, 1)} 00:00:00"

    sql = """
    CREATE TABLE IF NOT EXISTS #{partition_name}
    PARTITION OF #{table}
    FOR VALUES FROM ('#{start_datetime}') TO ('#{end_datetime}')
    """

    case SQL.query(Repo, sql, []) do
      {:ok, _} ->
        Logger.info("Created partition #{partition_name} for table #{table}")
        create_partition_indexes(table, partition_name)
        {:ok, partition_name}

      {:error, error} ->
        Logger.error("Failed to create partition #{partition_name}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp create_partition_indexes(table, partition_name) do
    # Create indexes specific to each table type
    case table do
      "killmails_raw" ->
        create_killmail_raw_indexes(partition_name)

      _ ->
        :ok
    end
  end

  defp create_killmail_raw_indexes(partition_name) do
    indexes = [
      "CREATE INDEX IF NOT EXISTS #{partition_name}_killmail_time_idx ON #{partition_name} (killmail_time)",
      "CREATE INDEX IF NOT EXISTS #{partition_name}_killmail_id_idx ON #{partition_name} (killmail_id)",
      "CREATE INDEX IF NOT EXISTS #{partition_name}_solar_system_idx ON #{partition_name} (solar_system_id)"
    ]

    Enum.each(indexes, fn sql ->
      case SQL.query(Repo, sql, []) do
        {:ok, _} ->
          :ok

        {:error, error} ->
          Logger.warning("Failed to create index: #{inspect(error)}")
      end
    end)
  end

  defp cleanup_old_partitions_for_table(table) do
    table_config = Enum.find(@partitioned_tables, &(&1.table == table))

    if table_config do
      cutoff_date = Date.add(Date.utc_today(), -table_config.retention_months * 30)
      old_partitions = find_old_partitions(table, cutoff_date)

      Enum.map(old_partitions, &drop_partition/1)
    else
      []
    end
  end

  defp find_old_partitions(table, cutoff_date) do
    query = """
    SELECT schemaname, tablename
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename LIKE $1
    """

    pattern = "#{table}_y%"

    case SQL.query(Repo, query, [pattern]) do
      {:ok, %{rows: rows}} ->
        rows
        # Get table name
        |> Enum.map(&Enum.at(&1, 1))
        |> Enum.filter(&partition_older_than?(&1, cutoff_date))

      _ ->
        []
    end
  end

  defp partition_older_than?(partition_name, cutoff_date) do
    # Extract date from partition name like "killmails_raw_y2023m01"
    case Regex.run(~r/_y(\d{4})m(\d{2})$/, partition_name) do
      [_, year_str, month_str] ->
        year = String.to_integer(year_str)
        month = String.to_integer(month_str)
        partition_date = Date.new!(year, month, 1)
        Date.compare(partition_date, cutoff_date) == :lt

      _ ->
        false
    end
  end

  defp drop_partition(partition_name) do
    sql = "DROP TABLE IF EXISTS #{partition_name}"

    case SQL.query(Repo, sql, []) do
      {:ok, _} ->
        Logger.info("Dropped old partition #{partition_name}")
        {:ok, partition_name}

      {:error, error} ->
        Logger.error("Failed to drop partition #{partition_name}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp list_existing_partitions(table) do
    query = """
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename LIKE $1
    ORDER BY tablename
    """

    pattern = "#{table}_y%"

    case SQL.query(Repo, query, [pattern]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, &Enum.at(&1, 0))

      _ ->
        []
    end
  end

  defp get_current_partition_status do
    Enum.map(@partitioned_tables, fn table_config ->
      table = table_config.table
      existing_partitions = list_existing_partitions(table)

      %{
        table: table,
        partition_count: length(existing_partitions),
        partitions: existing_partitions,
        retention_months: table_config.retention_months,
        next_partition_due: calculate_next_partition_date(),
        status: if(length(existing_partitions) > 0, do: :active, else: :needs_setup)
      }
    end)
  end

  defp calculate_next_partition_date do
    current_date = Date.utc_today()
    # Next month approximately
    Date.add(current_date, 30)
  end

  # Public utilities for manual partition management

  def create_partition_for_month(table, year, month) do
    date = Date.new!(year, month, 1)
    create_partition_for_table_and_date(table, date)
  end

  def list_partitions(table) do
    list_existing_partitions(table)
  end

  def get_partition_statistics do
    %{
      total_partitions: get_total_partition_count(),
      partition_sizes: get_partition_sizes(),
      oldest_partition: get_oldest_partition(),
      newest_partition: get_newest_partition()
    }
  end

  defp get_total_partition_count do
    query = """
    SELECT COUNT(*)
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename LIKE 'killmails_raw_y%'
    """

    case SQL.query(Repo, query, []) do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  end

  defp get_partition_sizes do
    query = """
    SELECT
      schemaname,
      tablename,
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename LIKE 'killmails_raw_y%'
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
    LIMIT 10
    """

    case SQL.query(Repo, query, []) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [_schema, table, size] -> %{table: table, size: size} end)

      _ ->
        []
    end
  end

  defp get_oldest_partition do
    query = """
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename LIKE 'killmails_raw_y%'
    ORDER BY tablename ASC
    LIMIT 1
    """

    case SQL.query(Repo, query, []) do
      {:ok, %{rows: [[table_name]]}} -> table_name
      _ -> nil
    end
  end

  defp get_newest_partition do
    query = """
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename LIKE 'killmails_raw_y%'
    ORDER BY tablename DESC
    LIMIT 1
    """

    case SQL.query(Repo, query, []) do
      {:ok, %{rows: [[table_name]]}} -> table_name
      _ -> nil
    end
  end
end
