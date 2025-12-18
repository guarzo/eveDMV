defmodule EveDmv.Test.PartitionHelper do
  @moduledoc """
  Partition management helpers for tests.
  Ensures that partitions exist for test data dates.
  """

  alias Ecto.Adapters.SQL
  alias EveDmv.Repo

  @doc """
  Ensures partitions exist for test dates.
  Creates partitions for:
  - Current month (for DateTime.utc_now() based tests)
  - Previous 3 months (for historical data tests)
  - January 2024 (for hardcoded test dates)
  """
  def ensure_test_partitions do
    # Get current date
    now = DateTime.utc_now()

    # Create partitions for current and previous 3 months
    for months_ago <- 0..3 do
      date = DateTime.add(now, -months_ago * 30 * 24 * 60 * 60, :second)
      create_partition_for_date(date)
    end

    # Create partition for January 2024 (hardcoded test dates)
    create_partition_for_date(~U[2024-01-01 00:00:00Z])

    :ok
  end

  defp create_partition_for_date(date) do
    year = date.year
    month = date.month |> Integer.to_string() |> String.pad_leading(2, "0")

    partition_name = "killmails_raw_y#{year}m#{month}"

    # Calculate start and end dates for the partition
    start_date = "#{year}-#{month}-01"

    next_month =
      if date.month == 12 do
        {date.year + 1, 1}
      else
        {date.year, date.month + 1}
      end

    {end_year, end_month} = next_month
    end_month_str = end_month |> Integer.to_string() |> String.pad_leading(2, "0")
    end_date = "#{end_year}-#{end_month_str}-01"

    # Create the partition if it doesn't exist
    create_query = """
    CREATE TABLE IF NOT EXISTS #{partition_name}
    PARTITION OF killmails_raw
    FOR VALUES FROM ('#{start_date}') TO ('#{end_date}')
    """

    case SQL.query(Repo, create_query, []) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        # Check if it's a duplicate table error
        case error do
          %{postgres: %{code: :duplicate_table}} ->
            # Partition already exists, that's fine
            :ok

          _ ->
            # Log but don't fail - partition might already exist or parent table might not be partitioned
            require Logger
            Logger.debug("Could not create partition #{partition_name}: #{inspect(error)}")
            :ok
        end
    end
  end
end
