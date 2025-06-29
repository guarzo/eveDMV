defmodule EveDmv.Market.MutamarketClient do
  @moduledoc """
  Client for interacting with the Mutamarket API for abyssal module prices.

  Mutamarket specializes in pricing mutaplasmid-modified (abyssal) modules
  which have unique attributes and can't be priced through normal market data.

  ## Configuration

  Set the following in your config:

      config :eve_dmv, :mutamarket,
        api_key: "your-api-key",
        base_url: "https://mutamarket.com/api/v1"

  ## Usage

      # Get abyssal module price estimate
      {:ok, price} = MutamarketClient.estimate_abyssal_price(type_id, attributes)
      
      # Search for similar modules
      {:ok, modules} = MutamarketClient.search_similar(type_id, attributes)
  """

  require Logger

  @default_base_url "https://mutamarket.com/api/v1"
  @http_timeout 30_000
  @retry_attempts 3
  @retry_delay 1_000

  # Mutamarket API endpoints
  @appraisal_endpoint "/appraisal/live"
  # @module_endpoint "/modules"  # Reserved for future use
  @type_stats_endpoint "/modules/type"
  @search_endpoint "/modules/search"

  # Public API

  @doc """
  Get price estimate for an abyssal module based on its attributes.

  ## Parameters

  - `type_id` - The base module type ID
  - `attributes` - Map of attribute IDs to values

  ## Examples

      iex> attributes = %{
      ...>   20 => 15.5,     # CPU usage
      ...>   30 => 220,      # Power grid usage  
      ...>   554 => 12500    # Damage multiplier
      ...> }
      iex> MutamarketClient.estimate_abyssal_price(47820, attributes)
      {:ok, %{
        estimated_price: 125_000_000,
        confidence: 0.85,
        similar_count: 15
      }}
  """
  @spec estimate_abyssal_price(integer(), map()) :: {:ok, map()} | {:error, term()}
  def estimate_abyssal_price(type_id, attributes)
      when is_integer(type_id) and is_map(attributes) do
    body = %{
      "type_id" => type_id,
      "attributes" => format_attributes(attributes)
    }

    with_retry(fn ->
      case post_request(@appraisal_endpoint, body) do
        {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
          parse_appraisal_response(response_body)

        {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
          Logger.error("Mutamarket appraisal failed with status #{status}: #{inspect(body)}")
          {:error, "API returned status #{status}"}

        {:error, reason} = error ->
          Logger.error("Mutamarket appraisal request failed: #{inspect(reason)}")
          error
      end
    end)
  end

  @doc """
  Get statistics for a specific abyssal module type.

  ## Examples

      iex> MutamarketClient.get_type_statistics(47820)
      {:ok, %{
        type_id: 47820,
        type_name: "Large Ancillary Shield Booster",
        total_listed: 245,
        average_price: 85_000_000,
        price_range: {10_000_000, 500_000_000},
        popular_attributes: [...]
      }}
  """
  @spec get_type_statistics(integer()) :: {:ok, map()} | {:error, term()}
  def get_type_statistics(type_id) when is_integer(type_id) do
    path = "#{@type_stats_endpoint}/#{type_id}"

    with_retry(fn ->
      case get_request(path) do
        {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
          parse_type_stats_response(response_body)

        {:ok, %HTTPoison.Response{status_code: 404}} ->
          {:error, :not_found}

        {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
          Logger.error("Mutamarket type stats failed with status #{status}: #{inspect(body)}")
          {:error, "API returned status #{status}"}

        {:error, reason} = error ->
          Logger.error("Mutamarket type stats request failed: #{inspect(reason)}")
          error
      end
    end)
  end

  @doc """
  Search for similar abyssal modules to get price comparison.

  ## Examples

      iex> MutamarketClient.search_similar(47820, attributes, limit: 10)
      {:ok, [
        %{
          item_id: "abc123",
          type_id: 47820,
          price: 120_000_000,
          attributes: %{...},
          similarity_score: 0.95
        },
        ...
      ]}
  """
  @spec search_similar(integer(), map(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def search_similar(type_id, attributes, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    params = %{
      "type_id" => type_id,
      "limit" => limit
    }

    body = %{
      "attributes" => format_attributes(attributes)
    }

    with_retry(fn ->
      case post_request(@search_endpoint, body, params) do
        {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
          parse_search_response(response_body)

        {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
          Logger.error("Mutamarket search failed with status #{status}: #{inspect(body)}")
          {:error, "API returned status #{status}"}

        {:error, reason} = error ->
          Logger.error("Mutamarket search request failed: #{inspect(reason)}")
          error
      end
    end)
  end

  @doc """
  Check if a module is likely abyssal based on its attributes.

  This is useful for determining whether to use Mutamarket or regular pricing.

  ## Examples

      iex> MutamarketClient.is_abyssal_module?(item_data)
      true
  """
  @spec abyssal_module?(map()) :: boolean()
  def abyssal_module?(item_data) do
    # Abyssal modules have specific type IDs or attribute patterns
    # They typically have type IDs in certain ranges or have mutated attributes

    cond do
      # Check for abyssal type ID ranges
      # Range 47,800-49,000 contains mutated abyssal modules according to EVE SDE
      item_data["type_id"] in 47_800..49_000 -> true
      # Check for mutated attribute flag
      item_data["mutated"] == true -> true
      # Check for abyssal-specific attributes
      has_abyssal_attributes?(item_data["attributes"] || %{}) -> true
      # Default to false
      true -> false
    end
  end

  # Private functions

  defp get_request(path, params \\ %{}) do
    url = build_url(path)
    headers = build_headers()

    HTTPoison.get(url, headers, params: params, recv_timeout: @http_timeout)
  end

  defp post_request(path, body, params \\ %{}) do
    url = build_url(path)
    headers = build_headers() ++ [{"Content-Type", "application/json"}]
    json_body = Jason.encode!(body)

    HTTPoison.post(url, json_body, headers, params: params, recv_timeout: @http_timeout)
  end

  defp build_url(path) do
    base_url = get_config(:base_url, @default_base_url)
    base_url <> path
  end

  defp build_headers do
    headers = [
      {"Accept", "application/json"},
      {"User-Agent", "EveDmv/1.0"}
    ]

    case get_config(:api_key) do
      nil -> headers
      api_key -> [{"Authorization", "Bearer #{api_key}"} | headers]
    end
  end

  defp format_attributes(attributes) do
    # Convert attribute map to Mutamarket's expected format
    Enum.map(attributes, fn {attr_id, value} ->
      %{
        "attribute_id" => to_string(attr_id),
        "value" => value
      }
    end)
  end

  defp parse_appraisal_response(body) do
    case Jason.decode(body) do
      {:ok, data} ->
        {:ok,
         %{
           estimated_price: get_in(data, ["appraisal", "price"]) || 0,
           confidence: get_in(data, ["appraisal", "confidence"]) || 0.0,
           similar_count: get_in(data, ["appraisal", "similar_count"]) || 0,
           price_factors: get_in(data, ["appraisal", "factors"]) || %{},
           updated_at: DateTime.utc_now()
         }}

      {:error, reason} ->
        {:error, "Failed to parse response: #{inspect(reason)}"}
    end
  end

  defp parse_type_stats_response(body) do
    case Jason.decode(body) do
      {:ok, data} ->
        {:ok,
         %{
           type_id: data["type_id"],
           type_name: data["type_name"],
           base_type_name: data["base_type_name"],
           total_listed: data["total_listed"] || 0,
           average_price: data["average_price"] || 0,
           median_price: data["median_price"] || 0,
           price_range: {
             data["min_price"] || 0,
             data["max_price"] || 0
           },
           volume_daily: data["daily_volume"] || 0,
           popular_attributes: parse_popular_attributes(data["popular_attributes"]),
           updated_at: parse_datetime(data["updated_at"])
         }}

      {:error, reason} ->
        {:error, "Failed to parse response: #{inspect(reason)}"}
    end
  end

  defp parse_search_response(body) do
    case Jason.decode(body) do
      {:ok, data} ->
        modules =
          data["modules"]
          |> Enum.map(fn module ->
            %{
              item_id: module["item_id"],
              type_id: module["type_id"],
              price: module["price"] || 0,
              location: module["location"],
              attributes: parse_module_attributes(module["attributes"]),
              similarity_score: module["similarity_score"] || 0.0,
              listed_at: parse_datetime(module["listed_at"])
            }
          end)

        {:ok, modules}

      {:error, reason} ->
        {:error, "Failed to parse response: #{inspect(reason)}"}
    end
  end

  defp parse_popular_attributes(nil), do: []

  defp parse_popular_attributes(attrs) do
    Enum.map(attrs, fn attr ->
      %{
        attribute_id: attr["attribute_id"],
        attribute_name: attr["attribute_name"],
        average_value: attr["average_value"],
        importance: attr["importance"] || 0.0
      }
    end)
  end

  defp parse_module_attributes(nil), do: %{}

  defp parse_module_attributes(attrs) do
    Enum.reduce(attrs, %{}, fn attr, acc ->
      Map.put(acc, attr["attribute_id"], attr["value"])
    end)
  end

  defp parse_datetime(nil), do: DateTime.utc_now()

  defp parse_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> DateTime.utc_now()
    end
  end

  defp has_abyssal_attributes?(attributes) do
    # Check for attributes that indicate abyssal modification
    abyssal_attribute_ids = [
      # Mutated attribute
      1692,
      # Abyssal depth
      2112,
      # Mutaplasmid type
      2113
    ]

    Enum.any?(abyssal_attribute_ids, &Map.has_key?(attributes, &1))
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
    |> Application.get_env(:mutamarket, [])
    |> Keyword.get(key, default)
  end
end
