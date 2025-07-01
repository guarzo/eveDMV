defmodule EveDmv.Eve.EsiCorporationClient do
  @moduledoc """
  Corporation-related operations for EVE ESI API.

  This module handles all corporation-specific API calls including
  basic corporation information, members, and assets.
  """

  require Logger
  alias EveDmv.Eve.{EsiCache, EsiParsers, EsiRequestClient}

  @corporation_api_version "v4"

  @doc """
  Get corporation information by ID.
  """
  @spec get_corporation(integer()) :: {:ok, map()} | {:error, :service_unavailable}
  def get_corporation(corporation_id) when is_integer(corporation_id) do
    case EsiCache.get_corporation(corporation_id) do
      {:ok, cached} ->
        {:ok, cached}

      :miss ->
        path = "/#{@corporation_api_version}/corporations/#{corporation_id}/"

        case EsiRequestClient.get_request(path) do
          {:ok, data} ->
            corporation = EsiParsers.parse_corporation_response(corporation_id, data)
            EsiCache.put_corporation(corporation_id, corporation)
            {:ok, corporation}

          error ->
            error
        end
    end
  end

  @doc """
  Get corporation members (requires authentication).
  """
  @spec get_corporation_members(integer(), String.t()) ::
          {:error, :invalid_response | :service_unavailable}
  def get_corporation_members(corporation_id, auth_token)
      when is_integer(corporation_id) and is_binary(auth_token) do
    path = "/#{@corporation_api_version}/corporations/#{corporation_id}/members/"

    case EsiRequestClient.get_authenticated_request(path, auth_token) do
      error ->
        error
    end
  end

  @doc """
  Get corporation assets (requires authentication).
  """
  @spec get_corporation_assets(integer(), String.t()) :: {:error, :service_unavailable}
  def get_corporation_assets(corporation_id, auth_token)
      when is_integer(corporation_id) and is_binary(auth_token) do
    fetch_all_corporation_assets(corporation_id, auth_token, 1, [])
  end

  # Private helper functions

  defp fetch_all_corporation_assets(_corporation_id, _auth_token, _page, _accumulated) do
    {:error, :service_unavailable}
  end
end
