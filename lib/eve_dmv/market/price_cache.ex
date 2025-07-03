defmodule EveDmv.Market.PriceCache do
  @moduledoc """
  Market price cache adapter using the unified cache system.

  This module maintains the same interface as before but delegates
  to the unified cache implementation.
  """

  alias EveDmv.Utils.Cache

  @cache_name :eve_price_cache
  @default_ttl_hours 24

  @doc """
  Start the price cache.
  """
  def start_link(_opts) do
    cache_opts = [
      name: @cache_name,
      ttl_ms: get_ttl_ms(),
      # Prices for up to 10k items
      max_size: 10_000,
      # 1 hour
      cleanup_interval_ms: 60 * 60 * 1000
    ]

    Cache.start_link(cache_opts)
  end

  @doc """
  Child specification for supervision tree.
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
    Cache.get(@cache_name, type_id)
  end

  @doc """
  Get multiple items from cache.
  """
  @spec get_items([integer()]) :: {map(), [integer()]}
  def get_items(type_ids) do
    {found, missing} = Cache.get_many(@cache_name, type_ids)

    # Convert keys to strings to match original interface
    string_found =
      found
      |> Enum.map(fn {type_id, value} ->
        {Integer.to_string(type_id), value}
      end)
      |> Enum.into(%{})

    {string_found, missing}
  end

  @doc """
  Store a single item price in cache.
  """
  @spec put_item(integer(), map()) :: :ok
  def put_item(type_id, price_data) do
    Cache.put(@cache_name, type_id, price_data, ttl_ms: get_ttl_ms())
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

        {type_id, price_data}
      end)

    Cache.put_many(@cache_name, entries, ttl_ms: get_ttl_ms())
  end

  @doc """
  Clear all cached prices.
  """
  @spec clear() :: :ok
  def clear do
    Cache.clear(@cache_name)
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
    cache_stats = Cache.stats(@cache_name)
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
