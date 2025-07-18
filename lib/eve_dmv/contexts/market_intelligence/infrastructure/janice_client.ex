defmodule EveDmv.Contexts.MarketIntelligence.Infrastructure.JaniceClient do
  @moduledoc """
  Client for interacting with the Janice API for EVE Online market pricing.

  Janice provides accurate market prices for ships, modules, and other items
  based on Jita market data. This client handles rate limiting, caching,
  and fallback scenarios.

  API Documentation: https://janice.e-351.com/api/rest/v2
  """

  use Tesla
  require Logger

  @base_url "https://janice.e-351.com/api/rest/v2"
  # 15 minutes
  @cache_ttl_seconds 900
  @rate_limit_per_minute 100
  @rate_limit_window_ms 60_000

  # Configure Tesla client
  plug(Tesla.Middleware.BaseUrl, @base_url)
  plug(Tesla.Middleware.JSON)
  plug(Tesla.Middleware.Timeout, timeout: 10_000)

  # Use Tesla.Mock adapter in test environment
  if Application.compile_env(:eve_dmv, :environment) == :test do
    adapter(Tesla.Mock)
  end

  plug(Tesla.Middleware.Retry,
    delay: 500,
    max_retries: 3,
    max_delay: 4_000,
    should_retry: fn
      {:ok, %{status: status}} when status in 500..599 -> true
      # Rate limited
      {:ok, %{status: 429}} -> true
      {:error, _} -> true
      _ -> false
    end
  )

  # GenServer for rate limiting
  use GenServer

  defmodule State do
    @moduledoc false
    defstruct requests: [], cache: %{}
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    # Schedule cache cleanup
    Process.send_after(self(), :cleanup_cache, 60_000)
    {:ok, %State{}}
  end

  @doc """
  Get the current market price for a single item.

  Returns {:ok, price_info} or {:error, reason}

  Price info includes:
  - sell_price: Lowest sell order price
  - buy_price: Highest buy order price
  - volume: Daily volume
  - updated_at: When the price was last updated
  """
  @spec get_item_price(integer()) :: {:ok, map()} | {:error, term()}
  def get_item_price(type_id) when is_integer(type_id) do
    # Check if GenServer is running
    case Process.whereis(__MODULE__) do
      nil ->
        # Direct API call without caching/rate limiting
        fetch_item_price_direct(type_id)

      _pid ->
        # Use GenServer for caching and rate limiting
        GenServer.call(__MODULE__, {:get_item_price, type_id})
    end
  end

  @doc """
  Get the market price for a ship, including common fitting estimates.

  Ships often have standard fits that affect their practical value.
  Janice provides better estimates for common ship hulls.
  """
  @spec get_ship_price(integer()) :: {:ok, map()} | {:error, term()}
  def get_ship_price(type_id) when is_integer(type_id) do
    # Check if GenServer is running
    case Process.whereis(__MODULE__) do
      nil ->
        # Direct API call without caching/rate limiting
        fetch_item_price_direct(type_id)

      _pid ->
        # Use GenServer for caching and rate limiting
        GenServer.call(__MODULE__, {:get_ship_price, type_id})
    end
  end

  @doc """
  Get prices for multiple items in a single request.

  More efficient than individual requests. Limited to 100 items per call.
  """
  @spec bulk_price_lookup([integer()]) :: {:ok, map()} | {:error, term()}
  def bulk_price_lookup(type_ids) when is_list(type_ids) do
    # Limit to 100 items per request
    if length(type_ids) > 100 do
      {:error, :too_many_items}
    else
      case Process.whereis(__MODULE__) do
        nil ->
          # Direct API call
          fetch_bulk_prices_direct(type_ids)

        _pid ->
          GenServer.call(__MODULE__, {:bulk_price_lookup, type_ids})
      end
    end
  end

  @doc """
  Get current rate limit status.
  """
  @spec get_rate_limit_status() :: map()
  def get_rate_limit_status do
    case Process.whereis(__MODULE__) do
      nil ->
        %{
          requests_in_window: 0,
          limit: @rate_limit_per_minute,
          remaining: @rate_limit_per_minute,
          window_ms: @rate_limit_window_ms
        }

      _pid ->
        GenServer.call(__MODULE__, :get_rate_limit_status)
    end
  end

  @doc """
  Clear the price cache.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    case Process.whereis(__MODULE__) do
      nil -> :ok
      _pid -> GenServer.cast(__MODULE__, :clear_cache)
    end
  end

  # GenServer callbacks

  @impl GenServer
  def handle_call({:get_item_price, type_id}, _from, state) do
    case check_cache(state.cache, type_id) do
      {:ok, cached_price} ->
        Logger.debug("Janice cache hit for type_id #{type_id}")
        {:reply, {:ok, cached_price}, state}

      :miss ->
        case check_rate_limit(state) do
          {:ok, new_state} ->
            fetch_and_cache_item_price(type_id, new_state)

          {:error, :rate_limited} = error ->
            Logger.warning("Janice API rate limited")
            {:reply, error, state}
        end
    end
  end

  @impl GenServer
  def handle_call({:get_ship_price, type_id}, _from, state) do
    # Ships use the same endpoint but we can add ship-specific logic
    case check_cache(state.cache, type_id) do
      {:ok, cached_price} ->
        Logger.debug("Janice cache hit for ship type_id #{type_id}")
        {:reply, {:ok, cached_price}, state}

      :miss ->
        case check_rate_limit(state) do
          {:ok, new_state} ->
            fetch_and_cache_ship_price(type_id, new_state)

          {:error, :rate_limited} = error ->
            Logger.warning("Janice API rate limited for ship pricing")
            {:reply, error, state}
        end
    end
  end

  @impl GenServer
  def handle_call({:bulk_price_lookup, type_ids}, _from, state) do
    # Check cache for all items first
    {cached, missing} = split_cached_items(type_ids, state.cache)

    if Enum.empty?(missing) do
      Logger.debug("Janice cache hit for all #{length(type_ids)} items")
      {:reply, {:ok, cached}, state}
    else
      case check_rate_limit(state) do
        {:ok, new_state} ->
          fetch_and_cache_bulk_prices(missing, cached, new_state)

        {:error, :rate_limited} = error ->
          Logger.warning("Janice API rate limited for bulk lookup")
          {:reply, error, state}
      end
    end
  end

  @impl GenServer
  def handle_call(:get_rate_limit_status, _from, state) do
    current_window_requests = count_recent_requests(state.requests)

    status = %{
      requests_in_window: current_window_requests,
      limit: @rate_limit_per_minute,
      remaining: max(0, @rate_limit_per_minute - current_window_requests),
      window_ms: @rate_limit_window_ms
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_cast(:clear_cache, state) do
    Logger.info("Clearing Janice price cache")
    {:noreply, %{state | cache: %{}}}
  end

  @impl GenServer
  def handle_info(:cleanup_cache, state) do
    # Remove expired cache entries
    now = System.system_time(:second)

    cleaned_cache =
      state.cache
      |> Enum.filter(fn {_type_id, {_price, cached_at}} ->
        now - cached_at < @cache_ttl_seconds
      end)
      |> Map.new()

    removed_count = map_size(state.cache) - map_size(cleaned_cache)

    if removed_count > 0 do
      Logger.debug("Cleaned #{removed_count} expired entries from Janice cache")
    end

    # Schedule next cleanup
    Process.send_after(self(), :cleanup_cache, 60_000)

    {:noreply, %{state | cache: cleaned_cache}}
  end

  # Private functions

  defp check_cache(cache, type_id) do
    now = System.system_time(:second)

    case Map.get(cache, type_id) do
      {price_info, cached_at} when now - cached_at < @cache_ttl_seconds ->
        {:ok, price_info}

      _ ->
        :miss
    end
  end

  defp check_rate_limit(state) do
    current_requests = count_recent_requests(state.requests)

    if current_requests >= @rate_limit_per_minute do
      {:error, :rate_limited}
    else
      new_requests = [System.system_time(:millisecond) | state.requests]
      {:ok, %{state | requests: new_requests}}
    end
  end

  defp count_recent_requests(requests) do
    cutoff = System.system_time(:millisecond) - @rate_limit_window_ms

    requests
    |> Enum.filter(&(&1 > cutoff))
    |> length()
  end

  defp fetch_and_cache_item_price(type_id, state) do
    Logger.debug("Fetching price from Janice for type_id #{type_id}")

    case get("/market/#{type_id}") do
      {:ok, %{status: 200, body: body}} ->
        price_info = parse_price_response(body)
        new_cache = cache_price(state.cache, type_id, price_info)
        {:reply, {:ok, price_info}, %{state | cache: new_cache}}

      {:ok, %{status: 404}} ->
        Logger.warning("Type ID #{type_id} not found in Janice")
        {:reply, {:error, :not_found}, state}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Janice API error: status=#{status}, body=#{inspect(body)}")
        {:reply, {:error, {:api_error, status}}, state}

      {:error, reason} ->
        Logger.error("Janice API request failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  defp fetch_and_cache_ship_price(type_id, state) do
    # For now, ships use the same endpoint
    # In the future, we might add ship-specific endpoints or fitting estimates
    fetch_and_cache_item_price(type_id, state)
  end

  defp fetch_and_cache_bulk_prices(missing_ids, cached_prices, state) do
    Logger.debug("Fetching bulk prices from Janice for #{length(missing_ids)} items")

    # Janice bulk endpoint expects comma-separated type IDs
    type_ids_param = Enum.join(missing_ids, ",")

    case get("/market/bulk/#{type_ids_param}") do
      {:ok, %{status: 200, body: body}} ->
        bulk_prices = parse_bulk_price_response(body)
        new_cache = cache_bulk_prices(state.cache, bulk_prices)
        all_prices = Map.merge(cached_prices, bulk_prices)
        {:reply, {:ok, all_prices}, %{state | cache: new_cache}}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Janice bulk API error: status=#{status}, body=#{inspect(body)}")
        {:reply, {:error, {:api_error, status}}, state}

      {:error, reason} ->
        Logger.error("Janice bulk API request failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  defp split_cached_items(type_ids, cache) do
    now = System.system_time(:second)

    Enum.reduce(type_ids, {%{}, []}, fn type_id, {cached, missing} ->
      case Map.get(cache, type_id) do
        {price_info, cached_at} when now - cached_at < @cache_ttl_seconds ->
          {Map.put(cached, type_id, price_info), missing}

        _ ->
          {cached, [type_id | missing]}
      end
    end)
  end

  defp parse_price_response(body) when is_map(body) do
    %{
      sell_price: get_in(body, ["sell", "min"]) || 0.0,
      buy_price: get_in(body, ["buy", "max"]) || 0.0,
      sell_volume: get_in(body, ["sell", "volume"]) || 0,
      buy_volume: get_in(body, ["buy", "volume"]) || 0,
      updated_at: DateTime.utc_now()
    }
  end

  defp parse_bulk_price_response(body) when is_map(body) do
    body
    |> Enum.map(fn {type_id_str, price_data} ->
      type_id = String.to_integer(type_id_str)
      price_info = parse_price_response(price_data)
      {type_id, price_info}
    end)
    |> Map.new()
  end

  defp cache_price(cache, type_id, price_info) do
    Map.put(cache, type_id, {price_info, System.system_time(:second)})
  end

  defp cache_bulk_prices(cache, bulk_prices) do
    now = System.system_time(:second)

    Enum.reduce(bulk_prices, cache, fn {type_id, price_info}, acc ->
      Map.put(acc, type_id, {price_info, now})
    end)
  end

  # Direct API calls (for tests and when GenServer not running)

  defp fetch_item_price_direct(type_id) do
    Logger.debug("Direct API call to Janice for type_id #{type_id}")

    case get("/market/#{type_id}") do
      {:ok, %{status: 200, body: body}} ->
        price_info = parse_price_response(body)
        {:ok, price_info}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status}} ->
        {:error, {:api_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_bulk_prices_direct(type_ids) do
    Logger.debug("Direct bulk API call to Janice for #{length(type_ids)} items")

    type_ids_param = Enum.join(type_ids, ",")

    case get("/market/bulk/#{type_ids_param}") do
      {:ok, %{status: 200, body: body}} ->
        bulk_prices = parse_bulk_price_response(body)
        {:ok, bulk_prices}

      {:ok, %{status: status}} ->
        {:error, {:api_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
