defmodule EveDmv.Test.DbHealth do
  @moduledoc """
  Database health checks for test environment.

  Provides utilities to monitor and verify database connection health
  before and during test runs.
  """

  require Logger

  @warning_threshold 0.8

  @doc """
  Checks current database connection usage and warns if approaching limits.

  Returns {:ok, stats} with connection statistics or {:error, reason} on failure.
  """
  @spec check_connection_usage() :: {:ok, map()} | {:error, any()}
  def check_connection_usage do
    query = """
    SELECT
      (SELECT count(*) FROM pg_stat_activity) as active,
      (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') as max
    """

    case EveDmv.Repo.query(query) do
      {:ok, %{rows: [[active, max]]}} ->
        ratio = active / max

        if ratio > @warning_threshold do
          Logger.warning("""
          High connection usage: #{active}/#{max} (#{round(ratio * 100)}%)
          Consider reducing pool_size or running fewer concurrent tests.
          """)
        end

        {:ok, %{active: active, max: max, ratio: ratio}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Ensures the database is healthy for testing.

  Raises an error if connection pool is exhausted or database is unreachable.
  """
  @spec ensure_healthy!() :: :ok
  def ensure_healthy! do
    case check_connection_usage() do
      {:ok, %{ratio: ratio}} when ratio > 0.95 ->
        raise """
        Database connection pool exhausted!
        Run: ./scripts/reset_test_db_connections.sh
        Or wait for connections to time out.
        """

      {:ok, _} ->
        :ok

      {:error, %Postgrex.Error{postgres: %{code: :too_many_connections}}} ->
        raise """
        Cannot connect to database - too many connections.
        Run: ./scripts/reset_test_db_connections.sh
        """

      {:error, reason} ->
        Logger.warning("Health check failed: #{inspect(reason)}")
        :ok
    end
  end

  @doc """
  Returns detailed information about current database connections.

  Useful for debugging connection leaks.
  """
  @spec get_connection_info() :: {:ok, list(map())} | {:error, any()}
  def get_connection_info do
    query = """
    SELECT
      pid,
      usename,
      datname,
      state,
      query_start,
      state_change,
      wait_event_type,
      wait_event,
      LEFT(query, 100) as query_preview
    FROM pg_stat_activity
    WHERE datname IS NOT NULL
    ORDER BY query_start DESC NULLS LAST
    LIMIT 50
    """

    case EveDmv.Repo.query(query) do
      {:ok, %{columns: columns, rows: rows}} ->
        connections =
          Enum.map(rows, fn row ->
            columns
            |> Enum.zip(row)
            |> Map.new()
          end)

        {:ok, connections}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Logs a summary of current connection state.

  Useful for debugging test connection issues.
  """
  @spec log_connection_summary() :: :ok
  def log_connection_summary do
    case check_connection_usage() do
      {:ok, stats} ->
        Logger.info("""
        Database Connection Summary:
        - Active: #{stats.active}
        - Max: #{stats.max}
        - Usage: #{round(stats.ratio * 100)}%
        """)

      {:error, reason} ->
        Logger.error("Failed to get connection summary: #{inspect(reason)}")
    end

    :ok
  end

  @doc """
  Returns count of idle connections older than the specified seconds.

  These are potential leak candidates.
  """
  @spec count_stale_connections(non_neg_integer()) :: {:ok, non_neg_integer()} | {:error, any()}
  def count_stale_connections(seconds \\ 60) do
    query = """
    SELECT count(*)
    FROM pg_stat_activity
    WHERE datname LIKE 'eve_dmv_test%'
      AND state = 'idle'
      AND query_start < NOW() - INTERVAL '#{seconds} seconds'
    """

    case EveDmv.Repo.query(query) do
      {:ok, %{rows: [[count]]}} -> {:ok, count}
      {:error, reason} -> {:error, reason}
    end
  end
end
