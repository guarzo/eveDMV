# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmv.Market.JaniceClient do
  @moduledoc """
  Client for interacting with the Janice API for EVE Online market prices.

  Janice provides appraisal services for items and ship fittings.

  ## Configuration

  Set the following in your config:

      config :eve_dmv, :janice,
        api_key: "your-api-key",
        base_url: "https://janice.e-351.com/api"

  ## Usage

      # Get single item price
      {:ok, price} = JaniceClient.get_item_price(587)  # Rifter

      # Get multiple item prices
      {:ok, prices} = JaniceClient.get_item_prices([587, 588, 589])

      # Appraise a ship fitting
      {:ok, appraisal} = JaniceClient.appraise_fit(fitting_text)
  """

  require Logger
  alias EveDmv.Market.{PriceCache, RateLimiter}
  alias EveDmv.Config.{Api, Http}

  # Rate limiter name for Janice API
  @rate_limiter :janice_rate_limiter

  # Public API

  @doc """
  Get the current Jita buy price for a single item type.

  ## Examples

      iex> JaniceClient.get_item_price(587)
      {:ok, %{type_id: 587, buy_price: 350_000.0, sell_price: 380_000.0}}

      iex> JaniceClient.get_item_price(999999)
      {:error, "Item not found"}
  """
  @spec get_item_price(integer()) :: {:ok, map()} | {:error, term()}
  def get_item_price(type_id) when is_integer(type_id) do
    # Check cache first
    case PriceCache.get_item(type_id) do
      {:ok, cached_price} ->
        {:ok, cached_price}

      :miss ->
        # Fetch from API
        case get_item_prices([type_id]) do
          {:ok, prices} ->
            case Map.get(prices, Integer.to_string(type_id)) do
              nil -> {:error, "Item not found"}
              price_data -> {:ok, price_data}
            end

          error ->
            error
        end
    end
  end

  @doc """
  Get prices for multiple items in a single request.

  ## Examples

      iex> JaniceClient.get_item_prices([587, 588, 589])
      {:ok, %{
        "587" => %{type_id: 587, buy_price: 350_000.0, sell_price: 380_000.0},
        "588" => %{type_id: 588, buy_price: 450_000.0, sell_price: 480_000.0},
        "589" => %{type_id: 589, buy_price: 550_000.0, sell_price: 580_000.0}
      }}
  """
  @spec get_item_prices([integer()]) :: {:ok, map()} | {:error, String.t()}
  def get_item_prices(type_ids) when is_list(type_ids) do
    # Check cache for all items
    {cached, missing} = PriceCache.get_items(type_ids)

    if Enum.empty?(missing) do
      # All items found in cache
      {:ok, cached}
    else
      # Fetch missing items from API
      case fetch_prices_from_api(missing) do
        {:ok, fetched_prices} ->
          # Cache the fetched prices
          PriceCache.put_items(fetched_prices)

          # Merge cached and fetched
          all_prices = Map.merge(cached, fetched_prices)
          {:ok, all_prices}

        error ->
          error
      end
    end
  end

  @doc """
  Appraise a ship fitting or cargo scan.

  ## Examples

      iex> fitting = \"\"\"
      ...> [Rifter, PvP]
      ...> 200mm AutoCannon II
      ...> 200mm AutoCannon II
      ...> \"\"\"
      iex> JaniceClient.appraise_fit(fitting)
      {:ok, %{
        total_buy: 5_500_000.0,
        total_sell: 5_800_000.0,
        items: [...]
      }}
  """
  @spec appraise_fit(String.t()) :: {:ok, map()} | {:error, term()}
  def appraise_fit(fitting_text) when is_binary(fitting_text) do
    body = %{
      "text" => fitting_text,
      "market" => "jita",
      "pricing" => "buy"
    }

    with_retry(fn ->
      case post_request(Api.janice_endpoints()[:appraisal], body) do
        {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
          parse_appraisal_response(response_body)

        {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
          Logger.error("Janice appraisal failed with status #{status}: #{inspect(body)}")
          {:error, "API returned status #{status}"}

        {:error, reason} = error ->
          Logger.error("Janice appraisal request failed: #{inspect(reason)}")
          error
      end
    end)
  end

  # Private functions

  defp fetch_prices_from_api(type_ids) do
    # Check rate limit before making request
    case RateLimiter.try_acquire(@rate_limiter) do
      {:ok, _remaining} ->
        params = %{
          "types" => Enum.join(type_ids, ","),
          "market" => "jita"
        }

        with_retry(fn ->
          case get_request(Api.janice_endpoints()[:items], params) do
            {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
              parse_price_response(response_body)

            {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
              Logger.error("Janice price fetch failed with status #{status}: #{inspect(body)}")
              {:error, "API returned status #{status}"}

            {:error, reason} = error ->
              Logger.error("Janice price request failed: #{inspect(reason)}")
              error
          end
        end)

      {:error, :insufficient_tokens} ->
        Logger.warning("Janice API rate limit reached, skipping request")
        {:error, "Rate limit exceeded"}
    end
  end

  defp get_request(endpoint, params) do
    url = build_url(endpoint)
    headers = build_headers()

    HTTPoison.get(url, headers, params: params, recv_timeout: Http.janice_timeout())
  end

  defp post_request(endpoint, body) do
    url = build_url(endpoint)
    headers = [{"Content-Type", "application/json"} | build_headers()]
    json_body = Jason.encode!(body)

    HTTPoison.post(url, json_body, headers, recv_timeout: Http.janice_timeout())
  end

  defp build_url(endpoint) do
    base_url = get_config(:base_url, Api.janice_base_url())
    base_url <> endpoint
  end

  defp build_headers do
    # Security: API key is added to headers but never logged
    # All error logging only includes response bodies and status codes
    case get_config(:api_key) do
      nil ->
        []

      api_key ->
        [{"X-API-Key", api_key}]
    end
  end

  defp parse_price_response(body) do
    case Jason.decode(body) do
      {:ok, data} ->
        prices =
          data
          |> Map.get("prices", %{})
          |> Enum.reduce(%{}, fn {type_id_str, price_data}, acc ->
            type_id = String.to_integer(type_id_str)

            price_info = %{
              type_id: type_id,
              buy_price: get_in(price_data, ["buy", "max"]),
              sell_price: get_in(price_data, ["sell", "min"]),
              volume: get_in(price_data, ["volume"]) || 0,
              updated_at: DateTime.utc_now()
            }

            Map.put(acc, type_id_str, price_info)
          end)

        {:ok, prices}

      {:error, reason} ->
        {:error, "Failed to parse response: #{inspect(reason)}"}
    end
  end

  defp parse_appraisal_response(body) do
    case Jason.decode(body) do
      {:ok, data} ->
        result = %{
          total_buy: get_in(data, ["totals", "buy"]) || 0.0,
          total_sell: get_in(data, ["totals", "sell"]) || 0.0,
          items: parse_appraisal_items(data["items"] || []),
          effective_prices: data["effectivePrices"] || %{}
        }

        {:ok, result}

      {:error, reason} ->
        {:error, "Failed to parse response: #{inspect(reason)}"}
    end
  end

  defp parse_appraisal_items(items) do
    Enum.map(items, fn item ->
      %{
        type_id: item["typeID"],
        type_name: item["typeName"],
        quantity: item["quantity"] || 1,
        unit_buy: get_in(item, ["prices", "buy", "max"]) || 0.0,
        unit_sell: get_in(item, ["prices", "sell", "min"]) || 0.0,
        total_buy: get_in(item, ["totals", "buy"]) || 0.0,
        total_sell: get_in(item, ["totals", "sell"]) || 0.0
      }
    end)
  end

  defp with_retry(fun, attempts \\ nil, base_delay \\ nil) do
    attempts = attempts || Http.retry_attempts()
    base_delay = base_delay || Http.retry_delay()

    case fun.() do
      {:error, _reason} = _error when attempts > 1 ->
        # Exponential backoff: double the delay each time, with jitter
        max_attempts = Http.retry_attempts()
        retry_attempt = max_attempts - attempts + 1
        exponential_delay = base_delay * :math.pow(2, retry_attempt - 1)

        # Add random jitter (±25% of the delay) to prevent thundering herd
        jitter_range = trunc(exponential_delay * 0.25)
        jitter = :rand.uniform(jitter_range * 2) - jitter_range
        final_delay = max(trunc(exponential_delay + jitter), 100)

        Logger.debug(
          "Retrying Janice API call in #{final_delay}ms (attempt #{retry_attempt}/#{max_attempts})"
        )

        Process.sleep(final_delay)
        with_retry(fun, attempts - 1, base_delay)

      result ->
        result
    end
  end

  defp get_config(key, default \\ nil) do
    :eve_dmv
    |> Application.get_env(:janice, [])
    |> Keyword.get(key, default)
  end
end
