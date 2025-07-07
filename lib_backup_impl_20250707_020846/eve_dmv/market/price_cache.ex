defmodule EveDmv.Market.PriceCache do
  @moduledoc """
  Market price cache adapter using the unified cache system.

  This module provides a backward-compatible interface for price caching
  while using the new unified cache system with the :api_responses cache type.
  """

  alias EveDmv.Cache

  @default_ttl_hours 24

  @doc """
  Start the price cache.

  This is now a no-op since the unified cache system handles initialization.
  """
  def start_link(_opts) do
    {:ok, spawn(fn -> :ok end)}
  end

  @doc """
  Child specification for supervision tree.

  This is now a no-op since the unified cache system handles supervision.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  @doc """
  Get a single item price from cache.
  """
  @spec get_item(integer()) :: {:ok, map()} | :miss
  def get_item(type_id) do
    Cache.get_price_data(type_id)
  end

  @doc """
  Get multiple items from cache.
  """
  @spec get_items([integer()]) :: {map(), [integer()]}
  def get_items(type_ids) do
    keys = Enum.map(type_ids, &{:price, &1})
    {found, missing_keys} = Cache.get_many(:api_responses, keys)

    # Convert keys to strings to match original interface
    string_found =
      found
      |> Enum.map(fn {{:price, type_id}, value} ->
        {Integer.to_string(type_id), value}
      end)
      |> Enum.into(%{})

    missing = Enum.map(missing_keys, fn {:price, type_id} -> type_id end)

    {string_found, missing}
  end

  @doc """
  Store a single item price in cache.
  """
  @spec put_item(integer(), map()) :: :ok
  def put_item(type_id, price_data) do
    Cache.put_price_data(type_id, price_data)
  end

  @doc """
  Store multiple item prices in cache.
  """
  @spec put_items(map()) :: :ok
  def put_items(prices_map) do
    entries =
      Enum.map(prices_map, fn {type_id_str, price_data} ->
        type_id =
          case type_id_str do
            id when is_binary(id) -> String.to_integer(id)
            id when is_integer(id) -> id
          end

        {{:price, type_id}, price_data}
      end)

    Cache.put_many(:api_responses, entries, ttl_ms: get_ttl_ms())
  end

  @doc """
  Clear all cached prices.
  """
  @spec clear() :: :ok
  def clear do
    Cache.invalidate_pattern(:api_responses, "price_*")
    :ok
  end

  @doc """
  Get cache statistics.
  """
  @spec stats() :: %{
          size: non_neg_integer(),
          memory_bytes: number(),
          ttl_hours: number()
        }
  def stats do
    cache_stats = Cache.stats(:api_responses)
    Map.put(cache_stats, :ttl_hours, get_ttl_hours())
  end

  # Private functions

  defp get_ttl_hours do
    Application.get_env(:eve_dmv, :price_cache_ttl_hours, @default_ttl_hours)
  end

  defp get_ttl_ms do
    get_ttl_hours() * 60 * 60 * 1000
  end
end
