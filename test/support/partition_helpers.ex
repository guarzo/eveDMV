defmodule EveDmv.Test.PartitionHelpers do
  @moduledoc """
  Helper functions for creating partitions in tests.
  """

  alias Ecto.Adapters.SQL
  alias EveDmv.Repo

  @doc """
  Creates partitions for all dates used in the test, based on the killmail_time values.
  This should be called in the setup of any test that creates killmail records.
  """
  def ensure_partitions_for_dates(dates) when is_list(dates) do
    dates
    |> Enum.map(&extract_year_month/1)
    |> Enum.uniq()
    |> Enum.each(&create_partition_for_month/1)
  end

  @doc """
  Creates a partition for January 2024, which is commonly used in tests.
  """
  def ensure_test_partitions do
    # Create partitions for commonly used test dates
    create_partition_for_month({2024, 1})
    # Also create Feb for edge cases
    create_partition_for_month({2024, 2})

    # Also create current month partition
    today = Date.utc_today()
    create_partition_for_month({today.year, today.month})
  end

  defp extract_year_month(%DateTime{year: year, month: month}), do: {year, month}
  defp extract_year_month(%NaiveDateTime{year: year, month: month}), do: {year, month}
  defp extract_year_month(%Date{year: year, month: month}), do: {year, month}

  defp create_partition_for_month({year, month}) do
    partition_name = "killmails_raw_y#{year}m#{String.pad_leading("#{month}", 2, "0")}"

    # Check if partition already exists
    query = "SELECT 1 FROM pg_tables WHERE tablename = $1"

    case Repo.query(query, [partition_name]) do
      {:ok, %{num_rows: 0}} ->
        # Partition doesn't exist, create it
        start_date = Date.new!(year, month, 1)

        end_date =
          start_date
          |> Date.add(32)
          |> Date.beginning_of_month()

        create_query = """
        CREATE TABLE IF NOT EXISTS #{partition_name}
        PARTITION OF killmails_raw
        FOR VALUES FROM ('#{start_date}') TO ('#{end_date}')
        """

        case SQL.query(Repo, create_query) do
          {:ok, _} ->
            :ok

          {:error, %Postgrex.Error{postgres: %{code: :duplicate_table}}} ->
            :ok

          {:error, error} ->
            # Log the error but don't fail - partition might exist
            IO.puts("Warning: Could not create partition #{partition_name}: #{inspect(error)}")
            :ok
        end

      _ ->
        # Partition exists or error checking, assume it exists
        :ok
    end
  end
end
