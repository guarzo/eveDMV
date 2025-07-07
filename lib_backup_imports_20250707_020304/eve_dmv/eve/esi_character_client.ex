defmodule EveDmv.Eve.EsiCharacterClient do
  alias EveDmv.Eve.EsiCache
  alias EveDmv.Eve.EsiParsers
  alias EveDmv.Eve.EsiRequestClient
  alias EveDmv.Eve.FallbackStrategy
  alias EveDmv.Telemetry.PerformanceMonitor

  require Logger
  @moduledoc """
  Character-related operations for EVE ESI API.

  This module handles all character-specific API calls including
  basic character information, skills, assets, and employment history.
  """


  @character_api_version "v4"

  @doc """
  Get character information by ID with reliability features.
  """
  @spec get_character(integer()) :: {:ok, map()} | {:error, term()}
  def get_character(character_id) when is_integer(character_id) do
    PerformanceMonitor.track_query("character_lookup", fn ->
      get_character_with_fallback(character_id)
    end)
  end

  def get_character(nil), do: {:error, :invalid_character_id}
  def get_character(_), do: {:error, :invalid_character_id}

  defp get_character_with_fallback(character_id) do
    cache_key = "character:#{character_id}"

    primary_fn = fn ->
      case EsiCache.get_character(character_id) do
        {:ok, cached} ->
          {:ok, cached}

        :miss ->
          fetch_character_from_esi(character_id)
      end
    end

    fallback_fn = fn ->
      FallbackStrategy.generate_placeholder_data(:character, character_id)
    end

    FallbackStrategy.execute_with_fallback(primary_fn,
      service: :esi_character,
      cache_key: cache_key,
      fallback_data_fn: fallback_fn,
      allow_stale: true,
      allow_placeholder: true
    )
  end

  defp fetch_character_from_esi(character_id) do
    path = "/#{@character_api_version}/characters/#{character_id}/"

    case EsiRequestClient.get_request(path, %{},
           operation_type: :character,
           cache_key: "character:#{character_id}",
           fallback_context: character_id
         ) do
      {:ok, data} ->
        character = EsiParsers.parse_character_response(character_id, data)
        EsiCache.put_character(character_id, character)
        {:ok, character}

      error ->
        error
    end
  end

  @doc """
  Get multiple characters efficiently using parallel requests with fallback.
  """
  @spec get_characters([integer()]) :: {:ok, map()} | {:ok, map(), :partial} | {:error, any()}
  def get_characters(character_ids) when is_list(character_ids) do
    case PerformanceMonitor.track_bulk_operation(
           "character_bulk_lookup",
           length(character_ids),
           fn ->
             get_characters_with_fallback(character_ids)
           end
         ) do
      {:ok, result} -> result
      {:error, _} = error -> error
    end
  end

  defp get_characters_with_fallback(character_ids) do
    {cached, missing} = EsiCache.get_characters(character_ids)

    if Enum.empty?(missing) do
      {:ok, cached}
    else
      # Create function specs for parallel execution with fallback
      function_specs =
        Enum.map(missing, fn char_id ->
          fn_spec = fn -> get_character_with_fallback(char_id) end

          fn_opts = [
            service: :esi_character,
            cache_key: "character:#{char_id}",
            allow_stale: true,
            allow_placeholder: true
          ]

          {fn_spec, fn_opts}
        end)

      case FallbackStrategy.execute_parallel_with_fallback(function_specs,
             timeout: 15_000,
             min_success_ratio: 0.5
           ) do
        {:ok, results} ->
          fetched = build_character_map(missing, results)
          all_characters = Map.merge(cached, fetched)
          {:ok, all_characters}

        {:ok, results, :partial} ->
          fetched = build_character_map(missing, results)
          all_characters = Map.merge(cached, fetched)
          {:ok, all_characters}

        {:error, reason} ->
          Logger.error("Failed to fetch characters in parallel", %{
            character_ids: missing,
            reason: reason
          })

          # Return cached data only
          {:ok, cached}
      end
    end
  end

  defp build_character_map(character_ids, results) do
    character_ids
    |> Enum.zip(results)
    |> Enum.reduce(%{}, fn {char_id, result}, acc ->
      case result do
        {:ok, character} -> Map.put(acc, char_id, character)
        {:ok, character, _type} -> Map.put(acc, char_id, character)
        _ -> acc
      end
    end)
  end

  @doc """
  Get character employment history.
  """
  @spec get_character_employment_history(integer()) ::
          {:ok, list(map())} | {:error, term()}
  def get_character_employment_history(character_id) when is_integer(character_id) do
    path = "/#{@character_api_version}/characters/#{character_id}/corporationhistory/"

    case EsiRequestClient.public_request("GET", path) do
      {:ok, response} ->
        parsed_history = parse_employment_history(response.body)
        {:ok, parsed_history}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get character skills (requires authentication).
  """
  @spec get_character_skills(integer(), String.t()) ::
          {:ok, %{skills: [any()], total_sp: any(), unallocated_sp: any()}}
          | {:error, :service_unavailable}
  def get_character_skills(character_id, auth_token)
      when is_integer(character_id) and is_binary(auth_token) do
    path = "/#{@character_api_version}/characters/#{character_id}/skills/"

    case EsiRequestClient.get_authenticated_request(path, auth_token) do
      {:ok, data} ->
        skills = EsiParsers.parse_skills_response(data)
        {:ok, skills}

      error ->
        error
    end
  end

  @doc """
  Get character assets (requires authentication).
  """
  @spec get_character_assets(integer(), String.t()) ::
          {:ok, list(map())} | {:error, term()}
  def get_character_assets(character_id, auth_token)
      when is_integer(character_id) and is_binary(auth_token) do
    fetch_all_character_assets(character_id, auth_token, 1, [])
  end

  def get_character_assets(character_id) when is_integer(character_id) do
    # For backward compatibility, return an error indicating auth is required
    {:error, :authentication_required}
  end

  # Private helper functions

  defp fetch_all_character_assets(character_id, auth_token, page, acc) do
    path = "/#{@character_api_version}/characters/#{character_id}/assets/?page=#{page}"

    case EsiRequestClient.authenticated_request("GET", path, auth_token) do
      {:ok, %{body: assets, headers: headers}} ->
        new_acc = acc ++ assets

        if has_more_pages?(headers) do
          fetch_all_character_assets(character_id, auth_token, page + 1, new_acc)
        else
          {:ok, new_acc}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_employment_history(history_data) when is_list(history_data) do
    Enum.map(history_data, fn entry ->
      %{
        corporation_id: entry["corporation_id"],
        is_deleted: entry["is_deleted"] || false,
        record_id: entry["record_id"],
        start_date: entry["start_date"]
      }
    end)
  end

  defp parse_employment_history(_), do: []

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
