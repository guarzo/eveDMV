defmodule EveDmv.Eve.EsiClient do
  @moduledoc """
  Client for interacting with EVE Online's ESI (EVE Swagger Interface) API.

  Provides access to character, corporation, alliance, and universe data.

  ## Rate Limiting

  ESI has a rate limit of 150 requests per second. This client implements
  automatic rate limiting to stay within these bounds.

  ## Configuration

  The client uses the same OAuth2 credentials as EVE SSO:

      config :eve_dmv, :esi,
        client_id: "your-client-id",
        base_url: "https://esi.evetech.net"

  ## Usage

      # Get character information
      {:ok, character} = EsiClient.get_character(95465499)
      
      # Get corporation information  
      {:ok, corp} = EsiClient.get_corporation(98388312)
      
      # Get multiple characters efficiently
      {:ok, characters} = EsiClient.get_characters([95465499, 90267367])
  """

  require Logger
  alias EveDmv.Eve.EsiCache

  @default_base_url "https://esi.evetech.net"
  @default_datasource "tranquility"
  @http_timeout 30_000
  @retry_attempts 3
  @retry_delay 1_000
  @rate_limit_per_second 150
  # 1 second in milliseconds
  @rate_limit_window 1_000

  # ESI API versions
  @character_api_version "v4"
  @corporation_api_version "v4"
  @alliance_api_version "v3"
  @universe_api_version "v4"
  @market_api_version "v1"

  # Public API

  @doc """
  Get character information by ID.

  ## Examples

      iex> EsiClient.get_character(95465499)
      {:ok, %{
        character_id: 95465499,
        name: "CCP Falcon",
        corporation_id: 98356193,
        alliance_id: nil,
        birthday: ~U[2013-09-06 15:14:00Z],
        gender: "male",
        race_id: 2,
        bloodline_id: 5,
        security_status: 0.0
      }}
  """
  @spec get_character(integer()) :: {:ok, map()} | {:error, term()}
  def get_character(character_id) when is_integer(character_id) do
    # Check cache first
    case EsiCache.get_character(character_id) do
      {:ok, cached} ->
        {:ok, cached}

      :miss ->
        # Fetch from API
        path = "/#{@character_api_version}/characters/#{character_id}/"

        with_rate_limit(fn ->
          case get_request(path) do
            {:ok, data} ->
              character = parse_character_response(character_id, data)
              EsiCache.put_character(character_id, character)
              {:ok, character}

            error ->
              error
          end
        end)
    end
  end

  @doc """
  Get multiple characters efficiently using parallel requests.

  ## Examples

      iex> EsiClient.get_characters([95465499, 90267367])
      {:ok, %{
        95465499 => %{character_id: 95465499, name: "CCP Falcon", ...},
        90267367 => %{character_id: 90267367, name: "Chribba", ...}
      }}
  """
  @spec get_characters([integer()]) :: {:ok, map()}
  def get_characters(character_ids) when is_list(character_ids) do
    # Check cache for all characters
    {cached, missing} = EsiCache.get_characters(character_ids)

    if Enum.empty?(missing) do
      {:ok, cached}
    else
      # Fetch missing characters in parallel (respecting rate limit)
      {:ok, fetched} = fetch_characters_parallel(missing)
      all_characters = Map.merge(cached, fetched)
      {:ok, all_characters}
    end
  end

  @doc """
  Get corporation information by ID.

  ## Examples

      iex> EsiClient.get_corporation(98388312)
      {:ok, %{
        corporation_id: 98388312,
        name: "CCP Games",
        ticker: "CCP",
        member_count: 500,
        ceo_id: 95465499,
        alliance_id: nil,
        date_founded: ~U[2003-05-01 00:00:00Z]
      }}
  """
  @spec get_corporation(integer()) :: {:ok, map()} | {:error, term()}
  def get_corporation(corporation_id) when is_integer(corporation_id) do
    case EsiCache.get_corporation(corporation_id) do
      {:ok, cached} ->
        {:ok, cached}

      :miss ->
        path = "/#{@corporation_api_version}/corporations/#{corporation_id}/"

        with_rate_limit(fn ->
          case get_request(path) do
            {:ok, data} ->
              corporation = parse_corporation_response(corporation_id, data)
              EsiCache.put_corporation(corporation_id, corporation)
              {:ok, corporation}

            error ->
              error
          end
        end)
    end
  end

  @doc """
  Get alliance information by ID.

  ## Examples

      iex> EsiClient.get_alliance(99005338)
      {:ok, %{
        alliance_id: 99005338,
        name: "Pandemic Horde",
        ticker: "REKTD",
        date_founded: ~U[2015-04-02 05:36:00Z],
        creator_id: 95432486,
        creator_corporation_id: 98388312,
        executor_corporation_id: 98481566
      }}
  """
  @spec get_alliance(integer()) :: {:ok, map()} | {:error, term()}
  def get_alliance(alliance_id) when is_integer(alliance_id) do
    case EsiCache.get_alliance(alliance_id) do
      {:ok, cached} ->
        {:ok, cached}

      :miss ->
        path = "/#{@alliance_api_version}/alliances/#{alliance_id}/"

        with_rate_limit(fn ->
          case get_request(path) do
            {:ok, data} ->
              alliance = parse_alliance_response(alliance_id, data)
              EsiCache.put_alliance(alliance_id, alliance)
              {:ok, alliance}

            error ->
              error
          end
        end)
    end
  end

  @doc """
  Get solar system information by ID.

  This is mainly used as a fallback when static data is incomplete.

  ## Examples

      iex> EsiClient.get_solar_system(30000142)
      {:ok, %{
        system_id: 30000142,
        name: "Jita",
        constellation_id: 20000020,
        security_status: 0.9,
        star_id: 40009077
      }}
  """
  @spec get_solar_system(integer()) :: {:ok, map()} | {:error, term()}
  def get_solar_system(system_id) when is_integer(system_id) do
    path = "/#{@universe_api_version}/universe/systems/#{system_id}/"

    with_rate_limit(fn ->
      case get_request(path) do
        {:ok, data} ->
          system = parse_system_response(system_id, data)
          {:ok, system}

        error ->
          error
      end
    end)
  end

  @doc """
  Search for entities by name.

  ## Examples

      iex> EsiClient.search("CCP Falcon", [:character])
      {:ok, %{
        character: [95465499]
      }}
  """
  @spec search(String.t(), [:character | :corporation | :alliance]) ::
          {:ok, map()} | {:error, term()}
  def search(search_string, categories) when is_binary(search_string) and is_list(categories) do
    path = "/v2/search/"

    params = %{
      "search" => search_string,
      "categories" => Enum.join(categories, ","),
      "strict" => "false"
    }

    with_rate_limit(fn ->
      case get_request(path, params) do
        {:ok, data} ->
          {:ok, data}

        error ->
          error
      end
    end)
  end

  @doc """
  Get market orders for a specific type in a region.

  ## Parameters
  - type_id: The item type ID to get orders for
  - region_id: The region ID (defaults to The Forge/Jita region: 10000002)
  - order_type: :buy, :sell, or :all (defaults to :all)

  ## Examples

      iex> EsiClient.get_market_orders(587, 10000002)
      {:ok, [
        %{
          order_id: 12345,
          type_id: 587,
          location_id: 60003760,
          price: 350000.0,
          volume_remain: 100,
          is_buy_order: false
        },
        ...
      ]}
  """
  @spec get_market_orders(integer(), integer(), :buy | :sell | :all) ::
          {:ok, [map()]} | {:error, term()}
  def get_market_orders(type_id, region_id \\ 10_000_002, order_type \\ :all) do
    path = "/#{@market_api_version}/markets/#{region_id}/orders/"

    params = %{
      "type_id" => type_id,
      "order_type" => to_string(order_type)
    }

    with_rate_limit(fn ->
      case get_request(path, params) do
        {:ok, data} when is_list(data) ->
          orders = Enum.map(data, &parse_market_order/1)
          {:ok, orders}

        {:ok, _} ->
          {:error, "Invalid response format"}

        error ->
          error
      end
    end)
  end

  @doc """
  Get market history for a specific type in a region.

  Returns daily price history including average, highest, lowest prices and volume.

  ## Examples

      iex> EsiClient.get_market_history(587, 10000002)
      {:ok, [
        %{
          date: ~D[2024-01-01],
          average: 350000.0,
          highest: 380000.0,
          lowest: 320000.0,
          volume: 15000,
          order_count: 250
        },
        ...
      ]}
  """
  @spec get_market_history(integer(), integer()) :: {:ok, [map()]} | {:error, term()}
  def get_market_history(type_id, region_id \\ 10_000_002) do
    path = "/#{@market_api_version}/markets/#{region_id}/history/"

    params = %{
      "type_id" => type_id
    }

    with_rate_limit(fn ->
      case get_request(path, params) do
        {:ok, data} when is_list(data) ->
          history = Enum.map(data, &parse_market_history/1)
          {:ok, history}

        {:ok, _} ->
          {:error, "Invalid response format"}

        error ->
          error
      end
    end)
  end

  @doc """
  Get type information by ID from ESI.

  ## Examples

      iex> EsiClient.get_type(587)
      {:ok, %{
        type_id: 587,
        name: "Rifter",
        description: "The Rifter is a...",
        group_id: 25,
        category_id: 6,
        market_group_id: 74,
        mass: 1067000.0,
        volume: 27289.0,
        capacity: 140.0,
        published: true
      }}
  """
  @spec get_type(integer()) :: {:ok, map()} | {:error, term()}
  def get_type(type_id) when is_integer(type_id) do
    path = "/#{@universe_api_version}/universe/types/#{type_id}/"

    with_rate_limit(fn ->
      case get_request(path) do
        {:ok, data} ->
          type_info = parse_type_response(type_id, data)
          {:ok, type_info}

        error ->
          error
      end
    end)
  end

  @doc """
  Get group information by ID from ESI.

  ## Examples

      iex> EsiClient.get_group(25)
      {:ok, %{
        group_id: 25,
        name: "Frigate",
        category_id: 6,
        published: true
      }}
  """
  @spec get_group(integer()) :: {:ok, map()} | {:error, term()}
  def get_group(group_id) when is_integer(group_id) do
    path = "/#{@universe_api_version}/universe/groups/#{group_id}/"

    with_rate_limit(fn ->
      case get_request(path) do
        {:ok, data} ->
          group_info = parse_group_response(group_id, data)
          {:ok, group_info}

        error ->
          error
      end
    end)
  end

  @doc """
  Get category information by ID from ESI.

  ## Examples

      iex> EsiClient.get_category(6)
      {:ok, %{
        category_id: 6,
        name: "Ship",
        published: true
      }}
  """
  @spec get_category(integer()) :: {:ok, map()} | {:error, term()}
  def get_category(category_id) when is_integer(category_id) do
    path = "/#{@universe_api_version}/universe/categories/#{category_id}/"

    with_rate_limit(fn ->
      case get_request(path) do
        {:ok, data} ->
          category_info = parse_category_response(category_id, data)
          {:ok, category_info}

        error ->
          error
      end
    end)
  end

  @doc """
  Get aggregated market statistics for multiple types efficiently.

  This calculates buy/sell prices based on market orders, using the
  5th percentile for buy orders and 95th percentile for sell orders
  to avoid market manipulation.

  ## Examples

      iex> EsiClient.get_market_prices([587, 588, 589])
      {:ok, %{
        587 => %{buy_price: 350000.0, sell_price: 380000.0, volume: 1500},
        588 => %{buy_price: 450000.0, sell_price: 480000.0, volume: 1200},
        589 => %{buy_price: 550000.0, sell_price: 580000.0, volume: 800}
      }}
  """
  @spec get_market_prices([integer()], integer()) :: {:ok, map()}
  def get_market_prices(type_ids, region_id \\ 10_000_002) when is_list(type_ids) do
    # Fetch market orders for each type in parallel (with rate limiting)
    results =
      type_ids
      |> Enum.map(fn type_id ->
        Task.async(fn ->
          case get_market_orders(type_id, region_id) do
            {:ok, orders} -> {type_id, calculate_market_prices(orders)}
            _ -> {type_id, nil}
          end
        end)
      end)
      |> Enum.map(&Task.await(&1, 60_000))
      |> Enum.reject(fn {_type_id, data} -> is_nil(data) end)
      |> Map.new()

    {:ok, results}
  end

  # Private functions

  defp get_request(path, params \\ %{}) do
    url = build_url(path)
    headers = build_headers()

    # Add datasource to params
    params = Map.put(params, "datasource", @default_datasource)

    with_retry(fn ->
      case HTTPoison.get(url, headers, params: params, recv_timeout: @http_timeout) do
        {:ok, %{status_code: 200, body: body}} ->
          Jason.decode(body)

        {:ok, %{status_code: 304}} ->
          # Not modified - should have been served from cache
          {:ok, %{}}

        {:ok, %{status_code: 404}} ->
          {:error, :not_found}

        {:ok, %{status_code: status, body: body}} ->
          Logger.error("ESI request failed with status #{status}: #{body}")
          {:error, "ESI returned status #{status}"}

        {:error, reason} = error ->
          Logger.error("ESI request failed: #{inspect(reason)}")
          error
      end
    end)
  end

  defp build_url(path) do
    base_url = get_config(:base_url, @default_base_url)
    base_url <> path
  end

  defp build_headers do
    [
      {"Accept", "application/json"},
      {"User-Agent", "EveDmv/1.0"}
    ]
  end

  defp parse_character_response(character_id, data) do
    %{
      character_id: character_id,
      name: data["name"],
      corporation_id: data["corporation_id"],
      alliance_id: data["alliance_id"],
      birthday: parse_datetime(data["birthday"]),
      gender: data["gender"],
      race_id: data["race_id"],
      bloodline_id: data["bloodline_id"],
      ancestry_id: data["ancestry_id"],
      security_status: data["security_status"] || 0.0,
      title: data["title"],
      faction_id: data["faction_id"],
      updated_at: DateTime.utc_now()
    }
  end

  defp parse_corporation_response(corporation_id, data) do
    %{
      corporation_id: corporation_id,
      name: data["name"],
      ticker: data["ticker"],
      member_count: data["member_count"] || 0,
      ceo_id: data["ceo_id"],
      alliance_id: data["alliance_id"],
      date_founded: parse_datetime(data["date_founded"]),
      home_station_id: data["home_station_id"],
      shares: data["shares"],
      tax_rate: data["tax_rate"] || 0.0,
      url: data["url"],
      war_eligible: data["war_eligible"],
      faction_id: data["faction_id"],
      updated_at: DateTime.utc_now()
    }
  end

  defp parse_alliance_response(alliance_id, data) do
    %{
      alliance_id: alliance_id,
      name: data["name"],
      ticker: data["ticker"],
      date_founded: parse_datetime(data["date_founded"]),
      creator_id: data["creator_id"],
      creator_corporation_id: data["creator_corporation_id"],
      executor_corporation_id: data["executor_corporation_id"],
      faction_id: data["faction_id"],
      updated_at: DateTime.utc_now()
    }
  end

  defp parse_system_response(system_id, data) do
    %{
      system_id: system_id,
      name: data["name"],
      constellation_id: data["constellation_id"],
      security_status: data["security_status"],
      star_id: data["star_id"],
      security_class: data["security_class"],
      updated_at: DateTime.utc_now()
    }
  end

  defp parse_type_response(type_id, data) do
    %{
      type_id: type_id,
      name: data["name"],
      description: data["description"],
      group_id: data["group_id"],
      category_id: data["category_id"],
      market_group_id: data["market_group_id"],
      mass: data["mass"],
      volume: data["volume"],
      capacity: data["capacity"],
      published: data["published"],
      updated_at: DateTime.utc_now()
    }
  end

  defp parse_group_response(group_id, data) do
    %{
      group_id: group_id,
      name: data["name"],
      category_id: data["category_id"],
      published: data["published"],
      updated_at: DateTime.utc_now()
    }
  end

  defp parse_category_response(category_id, data) do
    %{
      category_id: category_id,
      name: data["name"],
      published: data["published"],
      updated_at: DateTime.utc_now()
    }
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp fetch_characters_parallel(character_ids) do
    # Split into chunks to respect rate limit
    chunk_size = calculate_chunk_size(length(character_ids))

    results =
      character_ids
      |> Enum.chunk_every(chunk_size)
      |> Enum.map(fn chunk ->
        # Process chunk in parallel
        Task.async_stream(
          chunk,
          fn char_id ->
            case get_character(char_id) do
              {:ok, character} -> {char_id, character}
              _ -> {char_id, nil}
            end
          end,
          max_concurrency: chunk_size,
          timeout: @http_timeout
        )
        |> Enum.reduce(%{}, fn
          {:ok, {char_id, character}}, acc when not is_nil(character) ->
            Map.put(acc, char_id, character)

          _, acc ->
            acc
        end)
      end)
      |> Enum.reduce(%{}, &Map.merge/2)

    {:ok, results}
  end

  defp calculate_chunk_size(total) do
    # Conservative chunk size to stay well under rate limit
    # Safety margin
    max_concurrent = div(@rate_limit_per_second, 3)
    min(total, max_concurrent)
  end

  defp with_rate_limit(fun) do
    # Rate limiting with safety margin - use 80% of the allowed rate
    # This provides a buffer to prevent rate limit breaches
    safe_rate_per_second = round(@rate_limit_per_second * 0.8)
    interval_ms = div(@rate_limit_window, safe_rate_per_second)

    # Add small jitter to prevent thundering herd
    jitter_ms = :rand.uniform(5)
    total_delay_ms = interval_ms + jitter_ms

    result = fun.()
    Process.sleep(total_delay_ms)
    result
  end

  defp with_retry(fun, attempts \\ @retry_attempts) do
    case fun.() do
      {:error, _reason} = _error when attempts > 1 ->
        Logger.debug("ESI request failed, retrying... (#{attempts - 1} attempts left)")
        Process.sleep(@retry_delay)
        with_retry(fun, attempts - 1)

      result ->
        result
    end
  end

  defp get_config(key, default) do
    :eve_dmv
    |> Application.get_env(:esi, [])
    |> Keyword.get(key, default)
  end

  defp parse_market_order(data) do
    %{
      order_id: data["order_id"],
      type_id: data["type_id"],
      location_id: data["location_id"],
      price: data["price"] || 0.0,
      volume_remain: data["volume_remain"] || 0,
      volume_total: data["volume_total"] || 0,
      is_buy_order: data["is_buy_order"] || false,
      min_volume: data["min_volume"] || 1,
      duration: data["duration"],
      issued: parse_datetime(data["issued"]),
      range: data["range"]
    }
  end

  defp parse_market_history(data) do
    %{
      date: Date.from_iso8601!(data["date"]),
      average: data["average"] || 0.0,
      highest: data["highest"] || 0.0,
      lowest: data["lowest"] || 0.0,
      volume: data["volume"] || 0,
      order_count: data["order_count"] || 0
    }
  end

  defp calculate_market_prices(orders) do
    buy_orders = Enum.filter(orders, & &1.is_buy_order)
    sell_orders = Enum.reject(orders, & &1.is_buy_order)

    buy_price = calculate_percentile_price(buy_orders, 0.95, :desc)
    sell_price = calculate_percentile_price(sell_orders, 0.05, :asc)

    total_volume = Enum.reduce(orders, 0, &(&1.volume_remain + &2))

    %{
      buy_price: buy_price,
      sell_price: sell_price,
      volume: total_volume,
      buy_orders_count: length(buy_orders),
      sell_orders_count: length(sell_orders)
    }
  end

  defp calculate_percentile_price([], _percentile, _sort_order), do: nil

  defp calculate_percentile_price(orders, percentile, sort_order) do
    sorted_orders =
      case sort_order do
        :asc -> Enum.sort_by(orders, & &1.price)
        :desc -> Enum.sort_by(orders, & &1.price, :desc)
      end

    total_volume = Enum.reduce(sorted_orders, 0, &(&1.volume_remain + &2))
    target_volume = total_volume * percentile

    {_accumulated, price} =
      Enum.reduce_while(sorted_orders, {0, 0}, fn order, {acc_volume, _price} ->
        new_volume = acc_volume + order.volume_remain

        if new_volume >= target_volume do
          {:halt, {new_volume, order.price}}
        else
          {:cont, {new_volume, order.price}}
        end
      end)

    price
  end
end
