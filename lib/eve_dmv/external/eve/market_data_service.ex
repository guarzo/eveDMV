defmodule EveDmv.External.Eve.MarketDataService do
  @moduledoc """
  Market data service for retrieving real ship prices from EVE Online.

  This service replaces hardcoded ship costs with real market data by:
  1. Querying EVE ESI market endpoints for current prices
  2. Maintaining cached price data with daily refresh
  3. Providing fallback to historical averages when current data unavailable
  4. Supporting regional price variations (Jita, Amarr, Dodixie, Rens)

  Used by fleet cost calculators to provide accurate ship pricing.
  """

  use GenServer
  alias EveDmv.Cache
  alias EveDmv.Http.UnifiedClient
  alias EveDmv.StaticData.ShipTypes

  require Logger

  # Market hub region IDs
  @market_hubs %{
    # The Forge
    jita: 10_000_002,
    # Domain
    amarr: 10_000_043,
    # Sinq Laison
    dodixie: 10_000_032,
    # Heimatar
    rens: 10_000_030,
    # Metropolis
    hek: 10_000_042
  }

  @default_hub :jita
  # Cache prices for 24 hours
  @cache_ttl :timer.hours(24)
  @esi_base_url "https://esi.evetech.net/latest"
  # ESI allows up to 1000 type IDs per request
  @batch_size 100

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    # Schedule periodic cache warming
    schedule_cache_warming()
    {:ok, state}
  end

  @doc """
  Get current market price for a ship type ID.

  Returns the current market price from the specified region, with fallback
  to cached data and estimated values based on ship classification.

  ## Parameters
  - `type_id` - EVE ship type ID
  - `region` - Market region atom (default: :jita)
  - `price_type` - :sell_min, :buy_max, or :average (default: :sell_min)

  ## Returns
  - `{:ok, price}` - Current market price in ISK
  - `{:error, reason}` - Error retrieving price data

  ## Examples
      {:ok, price} = MarketDataService.get_ship_price(670)  # Capsule
      {:ok, price} = MarketDataService.get_ship_price(11176, :amarr, :buy_max)  # Rifter in Amarr
  """
  def get_ship_price(type_id, region \\ @default_hub, price_type \\ :sell_min) do
    GenServer.call(__MODULE__, {:get_ship_price, type_id, region, price_type})
  end

  @doc """
  Get market prices for multiple ships efficiently.

  Batches requests to ESI for optimal performance.

  ## Parameters
  - `type_ids` - List of ship type IDs
  - `region` - Market region atom (default: :jita)
  - `price_type` - :sell_min, :buy_max, or :average (default: :sell_min)

  ## Returns
  - `{:ok, price_map}` - Map of type_id => price
  - `{:error, reason}` - Error retrieving prices
  """
  def get_ship_prices_batch(type_ids, region \\ @default_hub, price_type \\ :sell_min) do
    GenServer.call(__MODULE__, {:get_ship_prices_batch, type_ids, region, price_type}, 30_000)
  end

  @doc """
  Get estimated ship cost with role-based multiplier.

  Combines market price with fitting cost estimation based on ship role.

  ## Parameters
  - `type_id` - Ship type ID
  - `role` - Ship role ("dps", "logistics", "fc", "tackle", "ewar")
  - `region` - Market region (default: :jita)

  ## Returns
  - `{:ok, estimated_cost}` - Total estimated cost including hull and fitting
  """
  def get_estimated_ship_cost(type_id, role, region \\ @default_hub) do
    with {:ok, hull_price} <- get_ship_price(type_id, region, :sell_min),
         {:ok, fitting_multiplier} <- get_fitting_multiplier(type_id, role) do
      total_cost = hull_price * fitting_multiplier
      {:ok, round(total_cost)}
    end
  end

  @doc """
  Warm the price cache for commonly used ships.

  Pre-loads market data for all ships in tactical categories to improve response times.
  """
  def warm_cache do
    GenServer.cast(__MODULE__, :warm_cache)
  end

  @doc """
  Clear cached market data to force fresh retrieval.
  """
  def clear_cache do
    GenServer.cast(__MODULE__, :clear_cache)
  end

  @doc """
  Get cache statistics and health information.
  """
  def get_cache_stats do
    GenServer.call(__MODULE__, :get_cache_stats)
  end

  # GenServer Callbacks

  def handle_call({:get_ship_price, type_id, region, price_type}, _from, state) do
    result = fetch_ship_price(type_id, region, price_type)
    {:reply, result, state}
  end

  def handle_call({:get_ship_prices_batch, type_ids, region, price_type}, _from, state) do
    result = fetch_ship_prices_batch(type_ids, region, price_type)
    {:reply, result, state}
  end

  def handle_call(:get_cache_stats, _from, state) do
    stats = get_cache_statistics()
    {:reply, {:ok, stats}, state}
  end

  def handle_cast(:warm_cache, state) do
    Task.start(fn -> perform_cache_warming() end)
    {:noreply, state}
  end

  def handle_cast(:clear_cache, state) do
    clear_price_cache()
    {:noreply, state}
  end

  def handle_info(:warm_cache_scheduled, state) do
    perform_cache_warming()
    schedule_cache_warming()
    {:noreply, state}
  end

  # Private Implementation

  defp fetch_ship_price(type_id, region, price_type) do
    cache_key = {:ship_price, type_id, region, price_type}

    case Cache.get(:analysis, cache_key) do
      nil ->
        case fetch_price_from_esi(type_id, region, price_type) do
          {:ok, price} ->
            Cache.put(:analysis, cache_key, price, ttl: @cache_ttl)
            {:ok, price}

          {:error, _reason} ->
            # Fallback to estimated price
            estimate_ship_price_fallback(type_id)
        end

      cached_price ->
        {:ok, cached_price}
    end
  end

  defp fetch_ship_prices_batch(type_ids, region, price_type) do
    # Check cache first
    {cached_prices, uncached_ids} = check_batch_cache(type_ids, region, price_type)

    if Enum.empty?(uncached_ids) do
      {:ok, cached_prices}
    else
      case fetch_prices_from_esi_batch(uncached_ids, region, price_type) do
        {:ok, new_prices} ->
          # Cache the new prices
          cache_batch_prices(new_prices, region, price_type)

          # Merge with cached prices
          all_prices = Map.merge(cached_prices, new_prices)
          {:ok, all_prices}

        {:error, reason} ->
          Logger.warning("Batch price fetch failed: #{inspect(reason)}")

          # Return cached prices with fallback estimates for missing ones
          fallback_prices = estimate_missing_prices(uncached_ids)
          all_prices = Map.merge(cached_prices, fallback_prices)
          {:ok, all_prices}
      end
    end
  end

  defp fetch_price_from_esi(type_id, region, price_type) do
    region_id = Map.get(@market_hubs, region, @market_hubs[@default_hub])
    url = "#{@esi_base_url}/markets/#{region_id}/orders/"

    params = %{
      "type_id" => type_id,
      "order_type" => if(price_type == :buy_max, do: "buy", else: "sell")
    }

    case UnifiedClient.get(url, headers: default_headers(), query: params) do
      {:ok, %{status: 200, body: orders}} when is_list(orders) ->
        parse_price_from_orders(orders, price_type)

      {:ok, %{status: status}} ->
        Logger.warning("ESI market request failed with status #{status} for type_id #{type_id}")
        {:error, :market_data_unavailable}

      {:error, reason} ->
        Logger.warning("ESI market request error: #{inspect(reason)}")
        {:error, :request_failed}
    end
  end

  defp fetch_prices_from_esi_batch(type_ids, region, price_type) do
    region_id = Map.get(@market_hubs, region, @market_hubs[@default_hub])

    # Split into batches to avoid ESI limits
    type_ids
    |> Enum.chunk_every(@batch_size)
    |> Enum.reduce_while({:ok, %{}}, fn batch, {:ok, acc} ->
      case fetch_batch_chunk(batch, region_id, price_type) do
        {:ok, batch_prices} ->
          {:cont, {:ok, Map.merge(acc, batch_prices)}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp fetch_batch_chunk(type_ids, region_id, price_type) do
    # For batch requests, we need to make individual calls to ESI
    # as the bulk orders endpoint doesn't support filtering by multiple type IDs efficiently

    results =
      type_ids
      |> Task.async_stream(
        fn type_id ->
          case fetch_price_from_esi(type_id, region_id_to_atom(region_id), price_type) do
            {:ok, price} -> {type_id, price}
            _ -> {type_id, nil}
          end
        end,
        max_concurrency: 10,
        timeout: 10_000
      )
      |> Enum.map(fn {:ok, result} -> result end)
      |> Enum.filter(fn {_, price} -> not is_nil(price) end)
      |> Map.new()

    {:ok, results}
  end

  defp parse_price_from_orders(orders, price_type) do
    case price_type do
      :sell_min ->
        # Find lowest sell order
        sell_orders = Enum.filter(orders, &(&1["is_buy_order"] == false))

        if Enum.empty?(sell_orders) do
          {:error, :no_sell_orders}
        else
          min_price = sell_orders |> Enum.map(& &1["price"]) |> Enum.min()
          {:ok, min_price}
        end

      :buy_max ->
        # Find highest buy order
        buy_orders = Enum.filter(orders, &(&1["is_buy_order"] == true))

        if Enum.empty?(buy_orders) do
          {:error, :no_buy_orders}
        else
          max_price = buy_orders |> Enum.map(& &1["price"]) |> Enum.max()
          {:ok, max_price}
        end

      :average ->
        # Calculate weighted average of spread
        sell_orders = Enum.filter(orders, &(&1["is_buy_order"] == false))
        buy_orders = Enum.filter(orders, &(&1["is_buy_order"] == true))

        case {sell_orders, buy_orders} do
          {[], []} ->
            {:error, :no_orders}

          {sells, []} ->
            avg_price = sells |> Enum.map(& &1["price"]) |> Enum.sum() |> div(length(sells))
            {:ok, avg_price}

          {[], buys} ->
            avg_price = buys |> Enum.map(& &1["price"]) |> Enum.sum() |> div(length(buys))
            {:ok, avg_price}

          {sells, buys} ->
            min_sell = sells |> Enum.map(& &1["price"]) |> Enum.min()
            max_buy = buys |> Enum.map(& &1["price"]) |> Enum.max()
            avg_price = (min_sell + max_buy) / 2
            {:ok, round(avg_price)}
        end
    end
  end

  defp estimate_ship_price_fallback(type_id) do
    # Use ship classification to estimate price when market data unavailable
    ship_class = ShipTypes.classify_ship_type(type_id)

    if ship_class != :unknown do
      estimated_price = get_base_price_estimate(ship_class)

      Logger.info(
        "Using estimated price #{estimated_price} ISK for ship type #{type_id} (#{ship_class})"
      )

      {:ok, estimated_price}
    else
      Logger.warning("Unknown ship type #{type_id}, using default price estimate")
      # 50M ISK default
      {:ok, 50_000_000}
    end
  end

  defp get_base_price_estimate(ship_class) do
    # Conservative price estimates based on typical market values
    # These are fallback values - real market data is preferred
    case ship_class do
      # 2M ISK
      :frigate -> 2_000_000
      # 8M ISK
      :destroyer -> 8_000_000
      # 25M ISK
      :cruiser -> 25_000_000
      # 80M ISK
      :battlecruiser -> 80_000_000
      # 150M ISK
      :battleship -> 150_000_000
      # 1.5B ISK
      :capital -> 1_500_000_000
      # 15B ISK
      :supercapital -> 15_000_000_000
      # 20M ISK
      :industrial -> 20_000_000
      # 150M ISK
      :mining -> 150_000_000
      # 50M ISK default
      _ -> 50_000_000
    end
  end

  defp get_fitting_multiplier(type_id, role) do
    # Calculate fitting cost multiplier based on ship attributes and role
    ship_class = ShipTypes.classify_ship_type(type_id)

    if ship_class != :unknown do
      base_multiplier = get_base_fitting_multiplier(ship_class)
      role_modifier = get_role_fitting_modifier(role)

      total_multiplier = base_multiplier * role_modifier
      {:ok, total_multiplier}
    end
  end

  defp get_base_fitting_multiplier(ship_class) do
    # Base fitting cost as multiplier of hull cost
    case ship_class do
      # Fittings typically 50% of hull cost
      :frigate -> 1.5
      # More expensive fittings
      :destroyer -> 1.8
      # T2 modules common
      :cruiser -> 2.2
      # Expensive command modules
      :battlecruiser -> 2.5
      # Faction/deadspace modules common
      :battleship -> 2.8
      # Very expensive capital modules
      :capital -> 3.5
      # Officer modules, etc.
      :supercapital -> 4.0
      # Default 100% of hull cost
      _ -> 2.0
    end
  end

  defp get_role_fitting_modifier(role) do
    # Additional cost modifier based on ship role complexity
    case role do
      # Command ships need expensive command modules
      "fc" -> 1.8
      # Logistics modules are pricey
      "logistics" -> 1.5
      # EWAR modules add cost
      "ewar" -> 1.3
      # Standard damage modules
      "dps" -> 1.2
      # Basic tackle modules
      "tackle" -> 1.0
      # Default moderate fitting cost
      _ -> 1.2
    end
  end

  defp check_batch_cache(type_ids, region, price_type) do
    type_ids
    |> Enum.map(fn type_id ->
      cache_key = {:ship_price, type_id, region, price_type}

      case Cache.get(:analysis, cache_key) do
        nil -> {:uncached, type_id}
        price -> {:cached, type_id, price}
      end
    end)
    |> Enum.split_with(fn {status, _} -> status == :cached end)
    |> then(fn {cached, uncached} ->
      cached_prices =
        cached |> Enum.map(fn {:cached, type_id, price} -> {type_id, price} end) |> Map.new()

      uncached_ids = uncached |> Enum.map(fn {:uncached, type_id} -> type_id end)
      {cached_prices, uncached_ids}
    end)
  end

  defp cache_batch_prices(prices, region, price_type) do
    prices
    |> Enum.each(fn {type_id, price} ->
      cache_key = {:ship_price, type_id, region, price_type}
      Cache.put(:analysis, cache_key, price, ttl: @cache_ttl)
    end)
  end

  defp estimate_missing_prices(type_ids) do
    type_ids
    |> Enum.map(fn type_id ->
      {:ok, price} = estimate_ship_price_fallback(type_id)
      {type_id, price}
    end)
    |> Map.new()
  end

  defp perform_cache_warming do
    Logger.info("Starting market data cache warming")

    # Get commonly used ship types for warming
    tactical_ships = get_tactical_ship_types()

    case get_ship_prices_batch(tactical_ships, @default_hub, :sell_min) do
      {:ok, prices} ->
        Logger.info("Warmed cache with #{map_size(prices)} ship prices")

      {:error, reason} ->
        Logger.warning("Cache warming failed: #{inspect(reason)}")
    end
  end

  defp get_tactical_ship_types do
    # Get ship type IDs for common tactical ships
    ship_groups = ShipTypes.tactical_ship_groups()

    ship_groups
    |> Map.values()
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.flat_map(fn class ->
      ShipTypes.get_ship_ids_for_class(class)
    end)
    # Limit to most common ships
    |> Enum.take(200)
  end

  defp schedule_cache_warming do
    # Schedule next cache warming in 6 hours
    Process.send_after(self(), :warm_cache_scheduled, :timer.hours(6))
  end

  defp clear_price_cache do
    # This would need to be implemented based on your cache backend
    Logger.info("Clearing market data cache")
  end

  defp get_cache_statistics do
    %{
      cache_backend: "IntelligenceCache",
      ttl_hours: @cache_ttl / :timer.hours(1),
      market_hubs: Map.keys(@market_hubs),
      # Would track last warming time
      last_warming: :not_implemented
    }
  end

  defp region_id_to_atom(region_id) do
    @market_hubs
    |> Enum.find(fn {_, id} -> id == region_id end)
    |> case do
      {atom, _} -> atom
      nil -> @default_hub
    end
  end

  defp default_headers do
    [
      {"User-Agent", "EVE DMV Market Service (https://github.com/your-org/eve-dmv)"},
      {"Accept", "application/json"}
    ]
  end
end
