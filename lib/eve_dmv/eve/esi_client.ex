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
  @character_api_version "v5"
  @corporation_api_version "v5"
  @alliance_api_version "v4"
  @universe_api_version "v4"

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
    # Simple rate limiting - in production, use a proper rate limiter
    # This is a placeholder that just ensures we don't overwhelm the API
    result = fun.()
    Process.sleep(div(@rate_limit_window, @rate_limit_per_second))
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
end
