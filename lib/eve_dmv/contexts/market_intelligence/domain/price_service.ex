defmodule EveDmv.Contexts.MarketIntelligence.Domain.PriceService do
  @moduledoc """
  Domain service for price discovery and management.

  This service coordinates price fetching from multiple sources,
  manages caching strategies, and publishes price update events.
  """

  use GenServer
  require Logger

  alias EveDmv.Contexts.MarketIntelligence.Infrastructure
  alias EveDmv.DomainEvents
  alias EveDmv.Infrastructure.EventBus
  # alias EveDmv.Result

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get price for a single item type.
  """
  def get_price(type_id, options \\ []) do
    GenServer.call(__MODULE__, {:get_price, type_id, options})
  end

  @doc """
  Get prices for multiple item types.
  """
  def get_prices(type_ids, options \\ []) do
    GenServer.call(__MODULE__, {:get_prices, type_ids, options})
  end

  @doc """
  Refresh prices bypassing cache.
  """
  def refresh_prices(type_ids, options \\ []) do
    GenServer.call(__MODULE__, {:refresh_prices, type_ids, options})
  end

  @doc """
  Get cache statistics.
  """
  def get_cache_stats do
    Infrastructure.PriceCache.stats()
  end

  @doc """
  Refresh commonly used items (called during static data updates).
  """
  def refresh_common_items do
    GenServer.cast(__MODULE__, :refresh_common_items)
  end

  # Server implementation

  @impl GenServer
  def init(_opts) do
    # Schedule periodic price refresh for hot items
    :timer.send_interval(:timer.minutes(30), :refresh_hot_items)

    {:ok,
     %{
       request_count: 0,
       cache_hits: 0,
       cache_misses: 0
     }}
  end

  @impl GenServer
  def handle_call({:get_price, type_id, options}, _from, state) do
    result = do_get_price(type_id, options)

    # Update stats
    new_state =
      state
      |> Map.update!(:request_count, &(&1 + 1))
      |> update_cache_stats(result)

    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_call({:get_prices, type_ids, options}, _from, state) do
    result = do_get_prices(type_ids, options)

    # Update stats  
    new_state =
      state
      |> Map.update!(:request_count, &(&1 + length(type_ids)))

    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_call({:refresh_prices, type_ids, options}, _from, state) do
    result = do_refresh_prices(type_ids, options)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_cast(:refresh_common_items, state) do
    # Refresh prices for commonly used items
    common_items = get_common_item_types()

    Task.start(fn ->
      do_refresh_prices(common_items, source: :best)
    end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:refresh_hot_items, state) do
    # Refresh hot items that are frequently requested
    hot_items = Infrastructure.PriceCache.get_hot_items(100)

    if length(hot_items) > 0 do
      Task.start(fn ->
        do_refresh_prices(hot_items, source: :best)
      end)

      Logger.debug("Refreshing #{length(hot_items)} hot items")
    end

    {:noreply, state}
  end

  # Private functions

  defp do_get_price(type_id, options) do
    source = Keyword.get(options, :source, :best)
    # 1 hour default
    cache_ttl = Keyword.get(options, :cache_ttl, 3600)

    case Infrastructure.PriceCache.get(type_id) do
      {:ok, cached_price} ->
        if price_fresh?(cached_price, cache_ttl) do
          {:ok, cached_price}
        else
          fetch_and_cache_price(type_id, source)
        end

      :miss ->
        fetch_and_cache_price(type_id, source)
    end
  end

  defp do_get_prices(type_ids, options) do
    # Check cache for all items first
    {cached, missing} =
      type_ids
      |> Enum.map(fn type_id ->
        case Infrastructure.PriceCache.get(type_id) do
          {:ok, price} -> {:cached, type_id, price}
          :miss -> {:missing, type_id}
        end
      end)
      |> Enum.split_with(fn {status, _, _} -> status == :cached end)

    # Fetch missing prices
    missing_type_ids = Enum.map(missing, fn {:missing, type_id} -> type_id end)

    fetched_result =
      if length(missing_type_ids) > 0 do
        fetch_and_cache_prices(missing_type_ids, Keyword.get(options, :source, :best))
      else
        {:ok, %{}}
      end

    case fetched_result do
      {:ok, fetched_prices} ->
        # Combine cached and fetched results
        all_prices =
          cached
          |> Enum.map(fn {:cached, type_id, price} -> {type_id, price} end)
          |> Map.new()
          |> Map.merge(fetched_prices)

        {:ok, all_prices}

      error ->
        error
    end
  end

  defp do_refresh_prices(type_ids, options) do
    source = Keyword.get(options, :source, :best)

    case fetch_and_cache_prices(type_ids, source, force_refresh: true) do
      {:ok, _prices} -> :ok
      error -> error
    end
  end

  defp fetch_and_cache_price(type_id, source) do
    case Infrastructure.ExternalPriceClient.get_price(type_id, source) do
      {:ok, price_data} ->
        # Cache the result
        Infrastructure.PriceCache.put(type_id, price_data)

        # Publish price update event
        event =
          DomainEvents.new(DomainEvents.PriceUpdated, %{
            type_id: type_id,
            price_data: price_data,
            source: source
          })

        EventBus.publish(event)

        {:ok, price_data}

      error ->
        Logger.warning("Failed to fetch price for type #{type_id}", %{
          type_id: type_id,
          source: source,
          error: inspect(error)
        })

        error
    end
  end

  defp fetch_and_cache_prices(type_ids, source, opts \\ []) do
    force_refresh = Keyword.get(opts, :force_refresh, false)

    case Infrastructure.ExternalPriceClient.get_prices(type_ids, source) do
      {:ok, prices} ->
        # Cache all results
        prices
        |> Enum.each(fn {type_id, price_data} ->
          if force_refresh do
            Infrastructure.PriceCache.put(type_id, price_data, force: true)
          else
            Infrastructure.PriceCache.put(type_id, price_data)
          end
        end)

        # Publish batch price update event
        event =
          DomainEvents.new(DomainEvents.MarketAnalyzed, %{
            analysis_id: generate_analysis_id(),
            analysis_type: :batch_price_update,
            item_types_analyzed: Map.keys(prices),
            market_trends: %{},
            price_anomalies: [],
            recommendations: []
          })

        EventBus.publish(event)

        {:ok, prices}

      error ->
        Logger.error("Failed to fetch batch prices", %{
          type_ids: type_ids,
          source: source,
          error: inspect(error)
        })

        error
    end
  end

  defp price_fresh?(price_data, cache_ttl) do
    updated_at = Map.get(price_data, :updated_at, DateTime.utc_now())
    age_seconds = DateTime.diff(DateTime.utc_now(), updated_at, :second)
    age_seconds < cache_ttl
  end

  defp update_cache_stats(state, {:ok, _}) do
    Map.update!(state, :cache_hits, &(&1 + 1))
  end

  defp update_cache_stats(state, _) do
    Map.update!(state, :cache_misses, &(&1 + 1))
  end

  defp get_common_item_types do
    # Commonly traded items that should always have fresh prices
    [
      # Tritanium
      34,
      # Pyerite  
      35,
      # Mexallon
      36,
      # Isogen
      37,
      # Nocxium
      38,
      # Zydrine
      39,
      # Megacyte
      40,
      # Morphite
      11399,
      # Plex
      16634,
      # Skill Injector
      29668
    ]
  end

  defp generate_analysis_id do
    8
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end
end
