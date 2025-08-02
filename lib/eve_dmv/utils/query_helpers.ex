defmodule EveDmv.Utils.QueryHelpers do
  @moduledoc """
  Common query helper functions to reduce duplication across contexts.

  Part of Sprint 22 Quality Standards - Code Duplication Elimination.
  """

  import Ecto.Query
  require Logger

  @doc """
  Standard pagination parameters with defaults.
  """
  def pagination_params(params, defaults \\ %{}) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    per_page = Map.get(params, "per_page", "25") |> String.to_integer()

    %{
      page: max(page, 1),
      per_page: min(max(per_page, 1), Map.get(defaults, :max_per_page, 100)),
      offset: (max(page, 1) - 1) * min(max(per_page, 1), Map.get(defaults, :max_per_page, 100))
    }
  end

  @doc """
  Standard time range query builder.
  """
  def time_range_query(query, field, start_time, end_time) do
    query
    |> where([q], field(q, ^field) >= ^start_time)
    |> where([q], field(q, ^field) <= ^end_time)
  end

  @doc """
  Common character_id filter.
  """
  def character_filter(query, character_id) when is_integer(character_id) do
    where(query, [q], q.character_id == ^character_id)
  end

  def character_filter(query, _), do: query

  @doc """
  Common corporation_id filter.
  """
  def corporation_filter(query, corporation_id) when is_integer(corporation_id) do
    where(query, [q], q.corporation_id == ^corporation_id)
  end

  def corporation_filter(query, _), do: query

  @doc """
  Standard ordering with defaults.
  """
  def apply_ordering(query, params, default_field \\ :inserted_at) do
    order_by = Map.get(params, "order_by", Atom.to_string(default_field))
    direction = Map.get(params, "direction", "desc")

    field = String.to_existing_atom(order_by)
    dir = String.to_existing_atom(direction)

    order_by(query, [q], [{^dir, field(q, ^field)}])
  rescue
    ArgumentError ->
      Logger.warning("Invalid ordering parameters: #{inspect(params)}")
      order_by(query, [q], desc: field(q, ^default_field))
  end

  @doc """
  Safe limit application with bounds checking.
  """
  def safe_limit(query, limit) when is_integer(limit) and limit > 0 do
    limit(query, ^min(limit, 1000))
  end

  def safe_limit(query, _), do: limit(query, 25)
end
