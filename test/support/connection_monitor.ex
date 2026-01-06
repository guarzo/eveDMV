defmodule EveDmv.Test.ConnectionMonitor do
  @moduledoc """
  Monitors database connection usage during tests.

  Add to test files to diagnose connection leaks:

      setup do
        ConnectionMonitor.start_monitoring()
        on_exit(fn -> ConnectionMonitor.report() end)
        :ok
      end
  """

  require Logger

  @doc """
  Starts monitoring connections for the current test.
  Stores the initial connection count in the process dictionary.
  """
  @spec start_monitoring() :: :ok
  def start_monitoring do
    Process.put(:test_connection_start, get_connection_count())
    :ok
  end

  @doc """
  Reports any connection leaks detected during the test.
  Logs a warning if more than 2 connections were leaked.
  """
  @spec report() :: :ok
  def report do
    start_count = Process.get(:test_connection_start, 0)
    end_count = get_connection_count()
    diff = end_count - start_count

    if diff > 2 do
      Logger.warning("""
      Connection leak detected!
      Started with: #{start_count}
      Ended with: #{end_count}
      Leaked: #{diff} connections
      """)
    end

    :ok
  end

  @doc """
  Gets the current connection count for test databases.
  """
  @spec get_connection_count() :: non_neg_integer()
  def get_connection_count do
    case EveDmv.Repo.query(
           "SELECT count(*) FROM pg_stat_activity WHERE datname LIKE 'eve_dmv_test%'"
         ) do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  end

  @doc """
  Returns detailed connection information for debugging.
  """
  @spec get_connection_details() :: {:ok, list(map())} | {:error, any()}
  def get_connection_details do
    query = """
    SELECT
      pid,
      usename,
      datname,
      state,
      query_start,
      state_change,
      LEFT(query, 100) as query_preview
    FROM pg_stat_activity
    WHERE datname LIKE 'eve_dmv_test%'
    ORDER BY query_start DESC
    """

    case EveDmv.Repo.query(query) do
      {:ok, %{columns: columns, rows: rows}} ->
        details =
          Enum.map(rows, fn row ->
            columns
            |> Enum.zip(row)
            |> Map.new()
          end)

        {:ok, details}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
