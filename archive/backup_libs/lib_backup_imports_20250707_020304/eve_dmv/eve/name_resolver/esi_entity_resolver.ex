defmodule EveDmv.Eve.NameResolver.EsiEntityResolver do
    alias EveDmv.Eve.NameResolver.CacheManager
  alias EveDmv.Eve.EsiClient
  alias EveDmv.Eve.NameResolver.BatchProcessor

  require Logger
  @moduledoc """
  ESI entity resolution module for EVE name resolution.

  Handles resolution of characters, corporations, and alliances using
  the EVE Swagger Interface (ESI) API. These entities can change names
  and require more frequent cache updates.
  """


  # Configurable timeout and concurrency settings
  # Task timeout is handled by esi_timeout
  @max_concurrency Application.compile_env(:eve_dmv, :name_resolver_max_concurrency, 10)
  @esi_timeout Application.compile_env(:eve_dmv, :name_resolver_esi_timeout, 10_000)

  @doc """
  Resolves a character ID to a character name using ESI.

  ## Examples

      iex> EsiEntityResolver.character_name(95465499)
      "CCP Falcon"

      iex> EsiEntityResolver.character_name(999999999)
      "Unknown Character (999999999)"
  """
  @spec character_name(integer()) :: String.t()
  def character_name(character_id) when is_integer(character_id) do
    case CacheManager.get_cached_or_fetch(:character, character_id, fn ->
           fetch_from_esi(:character, character_id)
         end) do
      {:ok, name} -> name
      {:error, _} -> "Unknown Character (#{character_id})"
    end
  end

  @doc """
  Resolves a corporation ID to a corporation name using ESI.

  ## Examples

      iex> EsiEntityResolver.corporation_name(98388312)
      "CCP Games"

      iex> EsiEntityResolver.corporation_name(999999999)
      "Unknown Corporation (999999999)"
  """
  @spec corporation_name(integer()) :: String.t()
  def corporation_name(corporation_id) when is_integer(corporation_id) do
    case CacheManager.get_cached_or_fetch(:corporation, corporation_id, fn ->
           fetch_from_esi(:corporation, corporation_id)
         end) do
      {:ok, name} -> name
      {:error, _} -> "Unknown Corporation (#{corporation_id})"
    end
  end

  @doc """
  Resolves an alliance ID to an alliance name using ESI.

  ## Examples

      iex> EsiEntityResolver.alliance_name(99005338)
      "Pandemic Horde"

      iex> EsiEntityResolver.alliance_name(999999999)
      "Unknown Alliance (999999999)"
  """
  @spec alliance_name(integer() | nil) :: String.t() | nil
  def alliance_name(nil), do: nil

  def alliance_name(alliance_id) when is_integer(alliance_id) do
    case CacheManager.get_cached_or_fetch(:alliance, alliance_id, fn ->
           fetch_from_esi(:alliance, alliance_id)
         end) do
      {:ok, name} -> name
      {:error, _} -> "Unknown Alliance (#{alliance_id})"
    end
  end

  @doc """
  Resolves multiple character IDs to names efficiently.
  Uses ESI bulk lookup when possible.
  """
  @spec character_names(list(integer())) :: map()
  def character_names(character_ids) when is_list(character_ids) do
    BatchProcessor.batch_resolve_with_esi(:character, character_ids, &character_name/1)
  end

  @doc """
  Resolves multiple corporation IDs to names efficiently.
  Uses ESI bulk lookup when possible.
  """
  @spec corporation_names(list(integer())) :: map()
  def corporation_names(corporation_ids) when is_list(corporation_ids) do
    BatchProcessor.batch_resolve_with_esi(:corporation, corporation_ids, &corporation_name/1)
  end

  @doc """
  Resolves multiple alliance IDs to names efficiently.
  """
  @spec alliance_names(list(integer())) :: map()
  def alliance_names(alliance_ids) when is_list(alliance_ids) do
    BatchProcessor.batch_resolve_with_esi(:alliance, alliance_ids, &alliance_name/1)
  end

  @doc """
  Performs bulk ESI lookup for characters using native ESI bulk endpoint.
  """
  def bulk_esi_lookup(:character, character_ids) when length(character_ids) <= 1000 do
    case EsiClient.get_characters(character_ids) do
      {:ok, characters_map} ->
        results = Map.new(characters_map, fn {id, char} -> {id, char.name} end)
        {:ok, results}
    end
  end

  def bulk_esi_lookup(:corporation, corporation_ids) when length(corporation_ids) <= 50 do
    results =
      corporation_ids
      |> Task.async_stream(
        fn id ->
          case EsiClient.get_corporation(id) do
            {:ok, corp} -> {id, corp.name}
            {:error, _} -> {id, "Unknown Corporation (#{id})"}
          end
        end,
        max_concurrency: @max_concurrency,
        timeout: @esi_timeout
      )
      |> Enum.reduce(%{}, fn
        {:ok, {id, name}}, acc -> Map.put(acc, id, name)
        {:exit, _reason}, acc -> acc
      end)

    {:ok, results}
  rescue
    error in [FunctionClauseError, ArgumentError, RuntimeError] ->
      Logger.warning("Parallel fetch error: #{inspect(error)}")
      {:error, :parallel_fetch_failed}

    error ->
      Logger.error("Unexpected error in parallel fetch: #{inspect(error)}")
      {:error, :parallel_fetch_failed}
  end

  def bulk_esi_lookup(:alliance, alliance_ids) when length(alliance_ids) <= 50 do
    results =
      alliance_ids
      |> Task.async_stream(
        fn id ->
          case EsiClient.get_alliance(id) do
            {:ok, alliance} -> {id, alliance.name}
            {:error, _} -> {id, "Unknown Alliance (#{id})"}
          end
        end,
        max_concurrency: @max_concurrency,
        timeout: @esi_timeout
      )
      |> Enum.reduce(%{}, fn
        {:ok, {id, name}}, acc -> Map.put(acc, id, name)
        {:exit, _reason}, acc -> acc
      end)

    {:ok, results}
  rescue
    error in [FunctionClauseError, ArgumentError, RuntimeError] ->
      Logger.warning("Parallel fetch error: #{inspect(error)}")
      {:error, :parallel_fetch_failed}

    error ->
      Logger.error("Unexpected error in parallel fetch: #{inspect(error)}")
      {:error, :parallel_fetch_failed}
  end

  def bulk_esi_lookup(type, ids) when type == :character and length(ids) > 1000 do
    ids
    |> Enum.chunk_every(1000)
    |> Enum.reduce_while({:ok, %{}}, fn chunk, {:ok, acc} ->
      case bulk_esi_lookup(type, chunk) do
        {:ok, results} -> {:cont, {:ok, Map.merge(acc, results)}}
        error -> {:halt, error}
      end
    end)
  end

  def bulk_esi_lookup(type, ids) when type in [:corporation, :alliance] and length(ids) > 50 do
    ids
    |> Enum.chunk_every(50)
    |> Enum.reduce_while({:ok, %{}}, fn chunk, {:ok, acc} ->
      case bulk_esi_lookup(type, chunk) do
        {:ok, results} -> {:cont, {:ok, Map.merge(acc, results)}}
        error -> {:halt, error}
      end
    end)
  end

  def bulk_esi_lookup(_type, _ids), do: {:error, :unsupported_type}

  # Private helper functions

  defp fetch_from_esi(:character, character_id) do
    case EsiClient.get_character(character_id) do
      {:ok, character} -> {:ok, character.name}
      {:error, _} -> {:error, :not_found}
    end
  rescue
    error ->
      Logger.warning("Failed to fetch character #{character_id} from ESI: #{inspect(error)}")
      {:error, :esi_error}
  end

  defp fetch_from_esi(:corporation, corporation_id) do
    case EsiClient.get_corporation(corporation_id) do
      {:ok, corporation} -> {:ok, corporation.name}
      {:error, _} -> {:error, :not_found}
    end
  rescue
    error ->
      Logger.warning("Failed to fetch corporation #{corporation_id} from ESI: #{inspect(error)}")
      {:error, :esi_error}
  end

  defp fetch_from_esi(:alliance, alliance_id) do
    case EsiClient.get_alliance(alliance_id) do
      {:ok, alliance} -> {:ok, alliance.name}
      {:error, _} -> {:error, :not_found}
    end
  rescue
    error ->
      Logger.warning("Failed to fetch alliance #{alliance_id} from ESI: #{inspect(error)}")
      {:error, :esi_error}
  end
end
