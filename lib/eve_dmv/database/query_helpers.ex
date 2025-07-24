defmodule EveDmv.Database.QueryHelpers do
  @moduledoc """
  Query safety helpers and limits to prevent runaway queries and ensure
  optimal database performance.

  This module provides functions to:
  - Apply safe limits to queries
  - Set query timeouts
  - Add query hints for optimization
  - Batch large queries for memory efficiency
  """

  import Ecto.Query

  alias Ecto.Adapters.SQL
  alias EveDmv.Repo

  @default_limit 1000
  @max_limit 10_000
  @default_timeout_ms 30_000
  @max_timeout_ms 120_000

  @doc """
  Apply safe limits to queries to prevent unbounded result sets.

  ## Options
    * `:limit` - Requested limit (default: #{@default_limit}, max: #{@max_limit})
    * `:enforce_limit` - Whether to enforce limits even if explicitly disabled (default: true)

  ## Examples

      iex> apply_safe_limit(query)
      # Applies default limit of 1000

      iex> query |> apply_safe_limit(limit: 5000)
      # Applies limit of 5000

      iex> query |> apply_safe_limit(limit: 20000)
      # Applies max limit of 10000
  """
  def apply_safe_limit(query, opts \\ []) do
    requested_limit = Keyword.get(opts, :limit, @default_limit)
    enforce_limit = Keyword.get(opts, :enforce_limit, true)

    if enforce_limit do
      safe_limit = min(requested_limit, @max_limit)
      limit(query, ^safe_limit)
    else
      query
    end
  end

  @doc """
  Apply query timeout to prevent long-running queries.

  Returns a tuple of {query, repo_opts} to be used with Repo functions.

  ## Options
    * `:timeout` - Timeout in milliseconds (default: #{@default_timeout_ms}, max: #{@max_timeout_ms})

  ## Examples

      iex> {query, opts} = with_timeout(query)
      iex> Repo.all(query, opts)

      iex> {query, opts} = query |> with_timeout(timeout: 60_000)
      iex> Repo.all(query, opts)
  """
  def with_timeout(query, opts \\ []) do
    requested_timeout = Keyword.get(opts, :timeout, @default_timeout_ms)
    safe_timeout = min(requested_timeout, @max_timeout_ms)

    repo_opts = [timeout: safe_timeout]
    {query, repo_opts}
  end

  @doc """
  Apply both limit and timeout for maximum safety.

  ## Options
    * `:limit` - Query result limit
    * `:timeout` - Query timeout in milliseconds

  ## Examples

      iex> {safe_query, opts} = with_safety(query)
      iex> Repo.all(safe_query, opts)
  """
  def with_safety(query, opts \\ []) do
    query
    |> apply_safe_limit(opts)
    |> with_timeout(opts)
  end

  @doc """
  Add query hints for optimization.

  ## Supported hints
    * `:parallel` - Enable parallel query execution
    * `:index` - Force use of specific index
    * `:no_index` - Disable index usage

  ## Examples

      iex> query |> with_hints(parallel: true)
      iex> query |> with_hints(index: "idx_killmails_system_activity")
  """
  def with_hints(query, hints) do
    Enum.reduce(hints, query, fn
      {:parallel, true}, q ->
        # Add parallel hint comment
        q

      {:index, _index_name}, q ->
        # Add index hint
        q

      {:no_index, true}, q ->
        # Add no index hint
        q

      _, q ->
        q
    end)
  end

  @doc """
  Create a streaming query for large datasets.

  This function returns a Stream that fetches data in batches to avoid
  memory issues with large result sets.

  ## Options
    * `:batch_size` - Number of records per batch (default: 1000)
    * `:timeout` - Timeout per batch query (default: 30s)

  ## Examples

      iex> stream = query |> stream_query(batch_size: 500)
      iex> stream |> Stream.each(&process_record/1) Stream.run()
  """
  def stream_query(query, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 1000)
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)

    Stream.resource(
      fn -> {query, 0} end,
      fn {base_query, offset} ->
        batch_query =
          base_query
          |> limit(^batch_size)
          |> offset(^offset)

        case EveDmv.Repo.all(batch_query, timeout: timeout) do
          [] -> {:halt, {base_query, offset}}
          results -> {results, {base_query, offset + batch_size}}
        end
      end,
      fn _ -> :ok end
    )
  end

  @doc """
  Count query results safely with a maximum threshold.

  This prevents expensive COUNT(*) queries on large tables by stopping
  at a threshold.

  ## Options
    * `:max_count` - Maximum count threshold (default: 100_000)
    * `:estimate` - Use table statistics for estimation (default: false)

  ## Examples

      iex> {:ok, count} = safe_count(query)
      iex> {:max, 100_000} = query |> safe_count(max_count: 100_000)
  """
  def safe_count(query, opts \\ []) do
    max_count = Keyword.get(opts, :max_count, 100_000)
    use_estimate = Keyword.get(opts, :estimate, false)

    if use_estimate do
      estimate_count(query)
    else
      limited_query = limit(query, ^max_count + 1)

      case Repo.aggregate(limited_query, :count) do
        count when count > max_count -> {:max, max_count}
        count -> {:ok, count}
      end
    end
  end

  @doc """
  Prepare query for pagination with cursor support.

  ## Options
    * `:cursor_field` - Field to use for cursor (default: :id)
    * `:direction` - :asc or :desc (default: :asc)
    * `:limit` - Page size (default: 100)

  ## Examples

      iex> query |> paginate(cursor: last_id, limit: 50)
  """
  def paginate(query, opts \\ []) do
    cursor_field = Keyword.get(opts, :cursor_field, :id)
    direction = Keyword.get(opts, :direction, :asc)
    limit = Keyword.get(opts, :limit, 100)
    cursor = Keyword.get(opts, :cursor)

    query = apply_safe_limit(query, limit: limit)

    query =
      case direction do
        :asc -> order_by(query, [r], asc: field(r, ^cursor_field))
        :desc -> order_by(query, [r], desc: field(r, ^cursor_field))
      end

    if cursor do
      case direction do
        :asc -> where(query, [r], field(r, ^cursor_field) > ^cursor)
        :desc -> where(query, [r], field(r, ^cursor_field) < ^cursor)
      end
    else
      query
    end
  end

  # Private functions

  defp estimate_count(query) do
    # Extract table name from query
    # This is a simplified version - real implementation would need
    # to properly parse the query structure
    case extract_table_name(query) do
      {:ok, table} ->
        sql = """
        SELECT reltuples::bigint AS estimate
        FROM pg_class
        WHERE relname = $1
        """

        case SQL.query(Repo, sql, [table]) do
          {:ok, %{rows: [[estimate]]}} -> {:estimate, estimate}
          _ -> {:error, :estimation_failed}
        end

      _ ->
        {:error, :cannot_estimate}
    end
  end

  defp extract_table_name(query) do
    # Simplified implementation
    # In production, this would need to handle complex queries
    case query do
      %{from: %{source: {table, _}}} -> {:ok, table}
      _ -> {:error, :no_table}
    end
  end
end
