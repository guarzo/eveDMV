defmodule EveDmv.Eve.EsiUniverseClient do
  @moduledoc """
  Universe and static data operations for EVE ESI API.

  This module handles all universe-related API calls including
  solar systems, types, groups, categories, alliances, and search.
  """

  alias EveDmv.Eve.EsiCache
  alias EveDmv.Eve.EsiParsers
  alias EveDmv.Eve.EsiRequestClient

  @universe_api_version "v4"
  @alliance_api_version "v3"
  @search_api_version "v2"

  @doc """
  Get alliance information by ID.
  """
  @spec get_alliance(integer()) :: {:ok, map()} | {:error, :service_unavailable}
  def get_alliance(alliance_id) when is_integer(alliance_id) do
    case EsiCache.get_alliance(alliance_id) do
      {:ok, cached} ->
        {:ok, cached}

      :miss ->
        path = "/#{@alliance_api_version}/alliances/#{alliance_id}/"

        case EsiRequestClient.get_request(path) do
          {:ok, response} when is_map(response) ->
            alliance = EsiParsers.parse_alliance_response(alliance_id, Map.get(response, :body))
            EsiCache.put_alliance(alliance_id, alliance)
            {:ok, alliance}

          {:error, _} = error ->
            error

          other ->
            {:error, {:unexpected_response, other}}
        end
    end
  end

  @doc """
  Get solar system information by ID.
  """
  @spec get_solar_system(integer()) :: {:ok, map()} | {:error, :service_unavailable}
  def get_solar_system(system_id) when is_integer(system_id) do
    case EsiCache.get_system(system_id) do
      {:ok, cached} ->
        {:ok, cached}

      :miss ->
        path = "/#{@universe_api_version}/universe/systems/#{system_id}/"

        case EsiRequestClient.get_request(path) do
          {:ok, response} when is_map(response) ->
            system = EsiParsers.parse_system_response(system_id, Map.get(response, :body))
            EsiCache.put_system(system_id, system)
            {:ok, system}

          {:error, _} = error ->
            error

          other ->
            {:error, {:unexpected_response, other}}
        end
    end
  end

  @doc """
  Search for entities in EVE universe.
  """
  @spec search(String.t(), [String.t()]) :: {:ok, map()} | {:error, term()}
  def search(search_string, categories) when is_binary(search_string) and is_list(categories) do
    if String.length(search_string) < 3 do
      {:error, :search_too_short}
    else
      path = "/#{@search_api_version}/search/"
      categories_param = Enum.join(categories, ",")
      params = %{"search" => search_string, "categories" => categories_param, "strict" => "false"}

      case EsiRequestClient.get_request(path, params) do
        {:ok, data} ->
          {:ok, data}

        error ->
          error
      end
    end
  end

  @doc """
  Get type information by ID.
  """
  @spec get_type(integer()) :: {:ok, map()} | {:error, :service_unavailable}
  def get_type(type_id) when is_integer(type_id) do
    case EsiCache.get_type(type_id) do
      {:ok, cached} ->
        {:ok, cached}

      :miss ->
        path = "/#{@universe_api_version}/universe/types/#{type_id}/"

        case EsiRequestClient.get_request(path) do
          {:ok, response} when is_map(response) ->
            type_info = EsiParsers.parse_type_response(type_id, Map.get(response, :body))
            EsiCache.put_type(type_id, type_info)
            {:ok, type_info}

          {:error, _} = error ->
            error

          other ->
            {:error, {:unexpected_response, other}}
        end
    end
  end

  @doc """
  Get group information by ID.
  """
  @spec get_group(integer()) :: {:ok, map()} | {:error, :service_unavailable}
  def get_group(group_id) when is_integer(group_id) do
    case EsiCache.get_group(group_id) do
      {:ok, cached} ->
        {:ok, cached}

      :miss ->
        path = "/#{@universe_api_version}/universe/groups/#{group_id}/"

        case EsiRequestClient.get_request(path) do
          {:ok, response} when is_map(response) ->
            group = EsiParsers.parse_group_response(group_id, Map.get(response, :body))
            EsiCache.put_group(group_id, group)
            {:ok, group}

          {:error, _} = error ->
            error

          other ->
            {:error, {:unexpected_response, other}}
        end
    end
  end

  @doc """
  Get category information by ID.
  """
  @spec get_category(integer()) :: {:ok, map()} | {:error, :service_unavailable}
  def get_category(category_id) when is_integer(category_id) do
    case EsiCache.get_category(category_id) do
      {:ok, cached} ->
        {:ok, cached}

      :miss ->
        path = "/#{@universe_api_version}/universe/categories/#{category_id}/"

        case EsiRequestClient.get_request(path) do
          {:ok, response} when is_map(response) ->
            category = EsiParsers.parse_category_response(category_id, Map.get(response, :body))
            EsiCache.put_category(category_id, category)
            {:ok, category}

          {:error, _} = error ->
            error

          other ->
            {:error, {:unexpected_response, other}}
        end
    end
  end
end
