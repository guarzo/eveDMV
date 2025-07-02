defmodule EveDmv.Market.PriceCache do
  @moduledoc """
  In-memory cache for market prices using ETS.

  Prices are cached with a configurable TTL (default 24 hours).
  """

  use GenServer
  require Logger

  @table_name :eve_price_cache
  @default_ttl_hours 24
  @cleanup_interval_minutes 60

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Child specification with proper shutdown timeout for ETS cleanup.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      # 10 seconds for ETS cleanup
      shutdown: 10_000
    }
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      # 10 seconds for ETS cleanup
      shutdown: 10_000
    }
  end

  @doc """
  Get a single item price from cache.

  Returns {:ok, price_data} if found and not expired, :miss otherwise.
  """
  @spec get_item(integer()) :: {:ok, map()} | :miss
  def get_item(type_id) do
    case :ets.lookup(@table_name, type_id) do
      [{^type_id, price_data, expires_at}] ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          {:ok, price_data}
        else
          # Expired, remove it
          :ets.delete(@table_name, type_id)
          :miss
        end

      [] ->
        :miss
    end
  end

  @doc """
  Get multiple items from cache.

  Returns {cached_map, missing_list} where cached_map contains found items
  and missing_list contains type_ids not found or expired.
  """
  @spec get_items([integer()]) :: {map(), [integer()]}
  def get_items(type_ids) do
    now = DateTime.utc_now()

    Enum.reduce(type_ids, {%{}, []}, fn type_id, {cached, missing} ->
      case :ets.lookup(@table_name, type_id) do
        [{^type_id, price_data, expires_at}] ->
          if DateTime.compare(now, expires_at) == :lt do
            {Map.put(cached, Integer.to_string(type_id), price_data), missing}
          else
            # Expired
            :ets.delete(@table_name, type_id)
            {cached, [type_id | missing]}
          end

        [] ->
          {cached, [type_id | missing]}
      end
    end)
  end

  @doc """
  Store a single item price in cache.
  """
  @spec put_item(integer(), map()) :: :ok
  def put_item(type_id, price_data) do
    expires_at = calculate_expiry()
    :ets.insert(@table_name, {type_id, price_data, expires_at})
    :ok
  end

  @doc """
  Store multiple item prices in cache.

  Expects a map with string keys (type_ids) and price data values.
  """
  @spec put_items(map()) :: :ok
  def put_items(prices_map) do
    expires_at = calculate_expiry()

    entries =
      Enum.map(prices_map, fn {type_id_str, price_data} ->
        type_id =
          case type_id_str do
            id when is_binary(id) -> String.to_integer(id)
            id when is_integer(id) -> id
          end

        {type_id, price_data, expires_at}
      end)

    :ets.insert(@table_name, entries)
    :ok
  end

  @doc """
  Clear all cached prices.
  """
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table_name)
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
    size = :ets.info(@table_name, :size)
    memory = :ets.info(@table_name, :memory)

    %{
      size: size,
      memory_bytes: memory * :erlang.system_info(:wordsize),
      ttl_hours: get_ttl_hours()
    }
  end

  # Server callbacks

  @impl true
  def init(_args) do
    # Create ETS table
    :ets.new(@table_name, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    # Schedule periodic cleanup
    schedule_cleanup()

    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup_expired, state) do
    cleanup_expired_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp calculate_expiry do
    ttl_hours = get_ttl_hours()
    DateTime.add(DateTime.utc_now(), ttl_hours * 3600, :second)
  end

  defp get_ttl_hours do
    Application.get_env(:eve_dmv, :price_cache_ttl_hours, @default_ttl_hours)
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_expired, @cleanup_interval_minutes * 60 * 1000)
  end

  defp cleanup_expired_entries do
    now = DateTime.utc_now()

    expired_count =
      :ets.foldl(
        fn {type_id, _price_data, expires_at}, count ->
          if DateTime.compare(now, expires_at) == :gt do
            :ets.delete(@table_name, type_id)
            count + 1
          else
            count
          end
        end,
        0,
        @table_name
      )

    if expired_count > 0 do
      Logger.info("Cleaned up #{expired_count} expired price cache entries")
    end
  end
end
