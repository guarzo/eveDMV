defmodule EveDmv.Eve.EsiCorporationClient do
  @moduledoc """
  Corporation-related operations for EVE ESI API.

  This module handles all corporation-specific API calls including
  basic corporation information, members, and assets.
  """

  alias EveDmv.Eve.EsiCache
  alias EveDmv.Eve.EsiParsers
  alias EveDmv.Eve.EsiRequestClient

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
          {:ok, response} ->
            # Handle double-wrapped response from EsiRequestClient
            actual_response =
              case response do
                # Unwrap if double-wrapped
                {:ok, resp} -> resp
                # Use as-is if not double-wrapped
                resp -> resp
              end

            # Now extract the body
            body =
              case actual_response do
                %{body: body} -> body
                other -> other
              end

            corporation = EsiParsers.parse_corporation_response(corporation_id, body)
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
          {:ok, list(map())} | {:error, term()}
  def get_corporation_members(corporation_id, auth_token)
      when is_integer(corporation_id) and is_binary(auth_token) do
    path = "/#{@corporation_api_version}/corporations/#{corporation_id}/members/"

    case EsiRequestClient.authenticated_request("GET", path, auth_token) do
      {:ok, response} ->
        {:ok, Map.get(response, :body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get corporation assets (requires authentication).
  """
  @spec get_corporation_assets(integer(), String.t()) ::
          {:ok, list(map())} | {:error, term()}
  def get_corporation_assets(corporation_id, auth_token)
      when is_integer(corporation_id) and is_binary(auth_token) do
    fetch_all_corporation_assets(corporation_id, auth_token, 1, [])
  end

  # Private helper functions

  defp fetch_all_corporation_assets(corporation_id, auth_token, page, acc) do
    path = "/#{@corporation_api_version}/corporations/#{corporation_id}/assets/?page=#{page}"

    case EsiRequestClient.authenticated_request("GET", path, auth_token) do
      {:ok, %{body: assets, headers: headers}} ->
        new_acc = acc ++ assets

        if has_more_pages?(headers) do
          fetch_all_corporation_assets(corporation_id, auth_token, page + 1, new_acc)
        else
          {:ok, new_acc}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp has_more_pages?(headers) do
    # Check for 'pages' header or other pagination indicators
    case Map.get(headers, "x-pages") do
      pages_str when is_binary(pages_str) ->
        try do
          pages = String.to_integer(pages_str)
          pages > 1
        rescue
          _ -> false
        end

      _ ->
        false
    end
  end
end
