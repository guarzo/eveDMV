defmodule EveDmv.Database.Repository.QueryBuilder do
  require Ash.Query
  @moduledoc """
  Query building utilities for the repository pattern.

  Provides composable query construction with optimization for common patterns
  like filtering, preloading, pagination, and sorting.
  """


  @doc """
  Build a query to get a single record by ID with optional preloading.
  """
  @spec build_get_query(module(), integer(), keyword()) :: Ash.Query.t()
  def build_get_query(resource, id, opts) do
    resource
    |> Ash.Query.new()
    |> apply_preloads(opts)
    |> Ash.Query.filter(id == ^id)
  end

  @doc """
  Build a query to list records with filtering, pagination, and preloading.
  """
  @spec build_list_query(module(), keyword()) :: Ash.Query.t()
  def build_list_query(resource, opts) do
    resource
    |> Ash.Query.new()
    |> apply_filters(opts)
    |> apply_preloads(opts)
    |> apply_pagination(opts)
    |> apply_sorting(opts)
  end

  @doc """
  Build a query to count records with filtering.
  """
  @spec build_count_query(module(), keyword()) :: Ash.Query.t()
  def build_count_query(resource, opts) do
    resource
    |> Ash.Query.new()
    |> apply_filters(opts)
  end

  @doc """
  Build a query to batch load multiple records by IDs.
  """
  @spec build_batch_query(module(), [integer()], keyword()) :: Ash.Query.t()
  def build_batch_query(resource, ids, opts) do
    resource
    |> Ash.Query.new()
    |> apply_preloads(opts)
    |> Ash.Query.filter(id in ^ids)
    |> apply_sorting(opts)
  end

  @doc """
  Apply filters from options to a query.

  ## Examples

      query |> apply_filters(filters: %{status: "active", type: "important"})
  """
  @spec apply_filters(Ash.Query.t(), keyword()) :: Ash.Query.t()
  def apply_filters(query, opts) do
    case Keyword.get(opts, :filters) do
      nil ->
        query

      filters when is_map(filters) ->
        Enum.reduce(filters, query, fn {field, value}, acc_query ->
          apply_filter(acc_query, field, value)
        end)
    end
  end

  @doc """
  Apply preloads from options to a query.

  ## Examples

      query |> apply_preloads(preload: [:user, :comments])
      query |> apply_preloads(preload: [user: [:profile], comments: []])
  """
  @spec apply_preloads(Ash.Query.t(), keyword()) :: Ash.Query.t()
  def apply_preloads(query, opts) do
    case Keyword.get(opts, :preload) do
      nil ->
        query

      [] ->
        query

      preloads when is_list(preloads) ->
        Ash.Query.load(query, preloads)
    end
  end

  @doc """
  Apply pagination from options to a query.

  ## Examples

      query |> apply_pagination(limit: 50, offset: 100)
  """
  @spec apply_pagination(Ash.Query.t(), keyword()) :: Ash.Query.t()
  def apply_pagination(query, opts) do
    query
    |> apply_limit(opts)
    |> apply_offset(opts)
  end

  @doc """
  Apply sorting from options to a query.

  ## Examples

      query |> apply_sorting(order_by: :inserted_at)
      query |> apply_sorting(order_by: [:name, {:inserted_at, :desc}])
  """
  @spec apply_sorting(Ash.Query.t(), keyword()) :: Ash.Query.t()
  def apply_sorting(query, opts) do
    case Keyword.get(opts, :order_by) do
      nil ->
        query

      field when is_atom(field) ->
        Ash.Query.sort(query, field)

      fields when is_list(fields) ->
        Ash.Query.sort(query, fields)
    end
  end

  # Private helper functions

  defp apply_filter(query, field, value) when is_atom(field) do
    case value do
      values when is_list(values) ->
        Ash.Query.filter(query, field(^field) in ^values)

      %{gte: gte_value} ->
        Ash.Query.filter(query, field(^field) >= ^gte_value)

      %{lte: lte_value} ->
        Ash.Query.filter(query, field(^field) <= ^lte_value)

      %{gt: gt_value} ->
        Ash.Query.filter(query, field(^field) > ^gt_value)

      %{lt: lt_value} ->
        Ash.Query.filter(query, field(^field) < ^lt_value)

      %{like: pattern} ->
        Ash.Query.filter(query, ilike(field(^field), ^pattern))

      %{not: not_value} ->
        Ash.Query.filter(query, field(^field) != ^not_value)

      simple_value ->
        Ash.Query.filter(query, field(^field) == ^simple_value)
    end
  end

  defp apply_limit(query, opts) do
    case Keyword.get(opts, :limit) do
      nil ->
        query

      limit when is_integer(limit) and limit > 0 ->
        Ash.Query.limit(query, limit)
    end
  end

  defp apply_offset(query, opts) do
    case Keyword.get(opts, :offset) do
      nil ->
        query

      offset when is_integer(offset) and offset >= 0 ->
        Ash.Query.offset(query, offset)
    end
  end
end
