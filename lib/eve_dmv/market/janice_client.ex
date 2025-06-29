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
  alias EveDmv.Market.PriceCache

  @default_base_url "https://janice.e-351.com/api"
  # 30 seconds
  @http_timeout 30_000
  @retry_attempts 3
  # 1 second
  @retry_delay 1_000

  # Janice API endpoints
  @item_endpoint "/v2/prices"
  @appraisal_endpoint "/v2/appraisal"

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
      case post_request(@appraisal_endpoint, body) do
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
    params = %{
      "types" => Enum.join(type_ids, ","),
      "market" => "jita"
    }

    with_retry(fn ->
      case get_request(@item_endpoint, params) do
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
  end

  defp get_request(endpoint, params) do
    url = build_url(endpoint)
    headers = build_headers()

    HTTPoison.get(url, headers, params: params, recv_timeout: @http_timeout)
  end

  defp post_request(endpoint, body) do
    url = build_url(endpoint)
    headers = build_headers() ++ [{"Content-Type", "application/json"}]
    json_body = Jason.encode!(body)

    HTTPoison.post(url, json_body, headers, recv_timeout: @http_timeout)
  end

  defp build_url(endpoint) do
    base_url = get_config(:base_url, @default_base_url)
    base_url <> endpoint
  end

  defp build_headers do
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
              buy_price: get_in(price_data, ["buy", "max"]) || 0.0,
              sell_price: get_in(price_data, ["sell", "min"]) || 0.0,
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

  defp with_retry(fun, attempts \\ @retry_attempts) do
    case fun.() do
      {:error, _reason} = _error when attempts > 1 ->
        Process.sleep(@retry_delay)
        with_retry(fun, attempts - 1)

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
