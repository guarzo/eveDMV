defmodule EveDmv.Platform.Utilities.QueryHelpers do
  @moduledoc """
  Database query utilities and helper functions used across the application.

  This module provides common query patterns, optimization utilities,
  and database interaction helpers to ensure consistent and efficient
  database operations.
  """

  import Ecto.Query

  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Repo

  require Logger

  # Common query patterns

  @doc """
  Build a date range filter for queries.
  """
  @spec date_range_filter(Ecto.Query.t(), atom(), Date.t() | nil, Date.t() | nil) ::
          Ecto.Query.t()
  def date_range_filter(query, _field, nil, nil), do: query

  def date_range_filter(query, field, start_date, nil) when not is_nil(start_date) do
    where(query, [q], field(q, ^field) >= ^start_date)
  end

  def date_range_filter(query, field, nil, end_date) when not is_nil(end_date) do
    where(query, [q], field(q, ^field) <= ^end_date)
  end

  def date_range_filter(query, field, start_date, end_date) do
    where(query, [q], field(q, ^field) >= ^start_date and field(q, ^field) <= ^end_date)
  end

  @doc """
  Build a datetime range filter for queries.
  """
  @spec datetime_range_filter(Ecto.Query.t(), atom(), DateTime.t() | nil, DateTime.t() | nil) ::
          Ecto.Query.t()
  def datetime_range_filter(query, _field, nil, nil), do: query

  def datetime_range_filter(query, field, start_datetime, nil) when not is_nil(start_datetime) do
    where(query, [q], field(q, ^field) >= ^start_datetime)
  end

  def datetime_range_filter(query, field, nil, end_datetime) when not is_nil(end_datetime) do
    where(query, [q], field(q, ^field) <= ^end_datetime)
  end

  def datetime_range_filter(query, field, start_datetime, end_datetime) do
    where(query, [q], field(q, ^field) >= ^start_datetime and field(q, ^field) <= ^end_datetime)
  end

  @doc """
  Add a safe limit to a query with maximum cap.
  """
  @spec safe_limit(Ecto.Query.t(), integer(), integer()) :: Ecto.Query.t()
  def safe_limit(query, limit, max_limit \\ 1000) do
    actual_limit = min(limit, max_limit)
    limit(query, ^actual_limit)
  end

  @doc """
  Add pagination to a query.
  """
  @spec paginate(Ecto.Query.t(), integer(), integer()) :: Ecto.Query.t()
  def paginate(query, page, per_page) when page > 0 and per_page > 0 do
    offset = (page - 1) * per_page

    query
    |> limit(^per_page)
    |> offset(^offset)
  end

  def paginate(query, _page, _per_page), do: query

  @doc """
  Filter by a list of IDs with IN clause.
  """
  @spec filter_by_ids(Ecto.Query.t(), atom(), [integer()]) :: Ecto.Query.t()
  def filter_by_ids(query, _field, []), do: where(query, false)

  def filter_by_ids(query, field, ids) when is_list(ids) do
    where(query, [q], field(q, ^field) in ^ids)
  end

  @doc """
  Filter by optional field value.
  """
  @spec maybe_filter(Ecto.Query.t(), atom(), any()) :: Ecto.Query.t()
  def maybe_filter(query, _field, nil), do: query
  def maybe_filter(query, _field, ""), do: query

  def maybe_filter(query, field, value) do
    where(query, [q], field(q, ^field) == ^value)
  end

  @doc """
  Add text search filter using ILIKE.
  """
  @spec text_search(Ecto.Query.t(), atom(), String.t() | nil) :: Ecto.Query.t()
  def text_search(query, _field, nil), do: query
  def text_search(query, _field, ""), do: query

  def text_search(query, field, search_term) do
    pattern = "%#{String.replace(search_term, "%", "\\%")}%"
    where(query, [q], ilike(field(q, ^field), ^pattern))
  end

  # Aggregation helpers

  @doc """
  Count records matching the query.
  """
  @spec count_records(Ecto.Query.t()) :: integer()
  def count_records(query) do
    query
    |> select([q], count(q.id))
    |> Repo.one()
    |> case do
      nil -> 0
      count -> count
    end
  end

  @doc """
  Get sum of a numeric field.
  """
  @spec sum_field(Ecto.Query.t(), atom()) :: number()
  def sum_field(query, field) do
    query
    |> select([q], sum(field(q, ^field)))
    |> Repo.one()
    |> case do
      nil -> 0
      sum -> sum
    end
  end

  @doc """
  Get average of a numeric field.
  """
  @spec avg_field(Ecto.Query.t(), atom()) :: float()
  def avg_field(query, field) do
    query
    |> select([q], avg(field(q, ^field)))
    |> Repo.one()
    |> case do
      nil -> 0.0
      %Decimal{} = avg -> Decimal.to_float(avg)
      avg when is_number(avg) -> avg * 1.0
    end
  end

  @doc """
  Group by field and count.
  """
  @spec group_count(Ecto.Query.t(), atom()) :: [{any(), integer()}]
  def group_count(query, field) do
    query
    |> group_by([q], field(q, ^field))
    |> select([q], {field(q, ^field), count(q.id)})
    |> Repo.all()
  end

  # Performance optimization

  @doc """
  Execute query with timeout and logging.
  """
  @spec safe_query(Ecto.Query.t(), keyword()) :: {:ok, [struct()]} | {:error, term()}
  def safe_query(query, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    log_slow = Keyword.get(opts, :log_slow, true)

    start_time = System.monotonic_time(:millisecond)

    try do
      result = Repo.all(query, timeout: timeout)

      execution_time = System.monotonic_time(:millisecond) - start_time

      if log_slow and execution_time > 1000 do
        Logger.warning("Slow query detected", %{
          execution_time_ms: execution_time,
          query: inspect(query)
        })
      end

      {:ok, result}
    rescue
      error ->
        execution_time = System.monotonic_time(:millisecond) - start_time

        Logger.error("Query failed", %{
          execution_time_ms: execution_time,
          error: inspect(error),
          query: inspect(query)
        })

        {:error, error}
    end
  end

  @doc """
  Execute a single query with error handling.
  """
  @spec safe_one(Ecto.Query.t(), keyword()) :: {:ok, struct() | nil} | {:error, term()}
  def safe_one(query, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 15_000)

    try do
      result = Repo.one(query, timeout: timeout)
      {:ok, result}
    rescue
      error ->
        Logger.error("Query failed", %{
          error: inspect(error),
          query: inspect(query)
        })

        {:error, error}
    end
  end

  # Batch operations

  @doc """
  Process records in batches to avoid memory issues.
  """
  @spec process_in_batches(Ecto.Query.t(), integer(), (list() -> any())) :: :ok
  def process_in_batches(query, batch_size \\ 1000, processor) when is_function(processor, 1) do
    do_process_batches(query, batch_size, 0, processor)
  end

  defp do_process_batches(query, batch_size, offset, processor) do
    batch =
      query
      |> limit(^batch_size)
      |> offset(^offset)
      |> Repo.all()

    case batch do
      [] ->
        :ok

      records ->
        processor.(records)
        do_process_batches(query, batch_size, offset + batch_size, processor)
    end
  end

  # Utility functions

  @doc """
  Build a recent filter (last N days).
  """
  @spec recent_filter(Ecto.Query.t(), atom(), integer()) :: Ecto.Query.t()
  def recent_filter(query, field, days) do
    cutoff_date = DateTime.utc_now() |> DateTimeUtils.add(-days * 24 * 60 * 60, :second)
    where(query, [q], field(q, ^field) >= ^cutoff_date)
  end

  @doc """
  Add ordering with null values last.
  """
  @spec order_by_nulls_last(Ecto.Query.t(), atom(), :asc | :desc) :: Ecto.Query.t()
  def order_by_nulls_last(query, field, direction \\ :asc) do
    case direction do
      :asc ->
        order_by(query, [q], asc_nulls_last: field(q, ^field))

      :desc ->
        order_by(query, [q], desc_nulls_last: field(q, ^field))
    end
  end

  @doc """
  Execute raw SQL with parameters safely.
  """
  @spec execute_raw(String.t(), [any()]) ::
          {:ok, %{rows: [[any()]], num_rows: integer()}} | {:error, term()}
  def execute_raw(sql, params \\ []) do
    result = Ecto.Adapters.SQL.query!(Repo, sql, params)
    {:ok, result}
  rescue
    error ->
      Logger.error("Raw SQL query failed", %{
        error: inspect(error),
        sql: sql,
        params: inspect(params)
      })

      {:error, error}
  end

  @doc """
  Check if a table exists in the database.
  """
  @spec table_exists?(String.t()) :: boolean()
  def table_exists?(table_name) do
    sql = """
    SELECT EXISTS (
      SELECT FROM information_schema.tables
      WHERE table_schema = 'public'
      AND table_name = $1
    )
    """

    case execute_raw(sql, [table_name]) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end

  @doc """
  Get table row count.
  """
  @spec table_row_count(String.t()) :: {:ok, integer()} | {:error, term()}
  def table_row_count(table_name) do
    sql = "SELECT COUNT(*) FROM #{table_name}"

    case execute_raw(sql) do
      {:ok, %{rows: [[count]]}} -> {:ok, count}
      error -> error
    end
  end

  # Connection and transaction helpers

  @doc """
  Execute function within a database transaction.
  """
  @spec transaction((-> any())) :: {:ok, any()} | {:error, any()}
  def transaction(func) when is_function(func, 0) do
    Repo.transaction(func)
  end

  @doc """
  Check database connectivity.
  """
  @spec ping() :: :ok | {:error, term()}
  def ping do
    Ecto.Adapters.SQL.query!(Repo, "SELECT 1", [])
    :ok
  rescue
    error -> {:error, error}
  end

  @doc """
  Get current database statistics.
  """
  @spec database_stats() :: map()
  def database_stats do
    stats_queries = [
      {"active_connections", "SELECT count(*) FROM pg_stat_activity WHERE state = 'active'"},
      {"total_connections", "SELECT count(*) FROM pg_stat_activity"},
      {"database_size", "SELECT pg_size_pretty(pg_database_size(current_database()))"},
      {"cache_hit_ratio",
       """
         SELECT round(
           100.0 * sum(blks_hit) / nullif(sum(blks_hit) + sum(blks_read), 0), 2
         ) FROM pg_stat_database WHERE datname = current_database()
       """}
    ]

    stats_queries
    |> Enum.map(fn {name, sql} ->
      case execute_raw(sql) do
        {:ok, %{rows: [[value]]}} -> {name, value}
        _ -> {name, nil}
      end
    end)
    |> Map.new()
  end
end
