defmodule EveDmv.Eve.EsiCache do
  @moduledoc """
  ESI cache adapter using the unified cache system.

  This module provides a backward-compatible interface for ESI caching
  while using the new unified cache system with appropriate cache types.
  """

  alias EveDmv.Cache

  @doc """
  Child specification for supervised processes.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Start the ESI cache.

  This is now a no-op since the unified cache system handles initialization.
  """
  def start_link(_opts \\ []) do
    {:ok, spawn(fn -> :ok end)}
  end

  # Character cache functions

  @doc """
  Get a character from cache.
  """
  @spec get_character(integer()) :: {:ok, map()} | :miss
  def get_character(character_id) do
    Cache.get_esi_response(:character, character_id)
  end

  @doc """
  Get multiple characters from cache.
  Returns {found_map, missing_list}.
  """
  @spec get_characters([integer()]) :: {map(), [integer()]}
  def get_characters(character_ids) do
    keys = Enum.map(character_ids, &{:esi, :character, &1})
    {found, missing_keys} = Cache.get_many(:api_responses, keys)

    # Convert back to character_id => data format
    found_map =
      Enum.map(found, fn {{:esi, :character, id}, data} -> {id, data} end)
      |> Enum.into(%{})

    missing_ids = Enum.map(missing_keys, fn {:esi, :character, id} -> id end)

    {found_map, missing_ids}
  end

  @doc """
  Store a character in cache.
  """
  @spec put_character(integer(), map()) :: :ok
  def put_character(character_id, character_data) do
    Cache.put_esi_response(:character, character_id, character_data)
  end

  # Corporation cache functions

  @doc """
  Get a corporation from cache.
  """
  @spec get_corporation(integer()) :: {:ok, map()} | :miss
  def get_corporation(corporation_id) do
    Cache.get_esi_response(:corporation, corporation_id)
  end

  @doc """
  Store a corporation in cache.
  """
  @spec put_corporation(integer(), map()) :: :ok
  def put_corporation(corporation_id, corporation_data) do
    Cache.put_esi_response(:corporation, corporation_id, corporation_data)
  end

  # Alliance cache functions

  @doc """
  Get an alliance from cache.
  """
  @spec get_alliance(integer()) :: {:ok, map()} | :miss
  def get_alliance(alliance_id) do
    Cache.get_esi_response(:alliance, alliance_id)
  end

  @doc """
  Store an alliance in cache.
  """
  @spec put_alliance(integer(), map()) :: :ok
  def put_alliance(alliance_id, alliance_data) do
    Cache.put_esi_response(:alliance, alliance_id, alliance_data)
  end

  # Generic cache functions (for backward compatibility)

  @doc """
  Get a value from the generic cache.
  """
  @spec get(String.t()) :: {:ok, term()} | {:error, :not_found}
  def get(key) do
    case Cache.get(:api_responses, {:esi, :generic, key}) do
      {:ok, data} -> {:ok, data}
      :miss -> {:error, :not_found}
    end
  end

  @doc """
  Store a value in the generic cache.
  """
  @spec put(String.t(), term(), keyword()) :: :ok
  def put(key, value, opts \\ []) do
    ttl_seconds = Keyword.get(opts, :ttl, 3600)
    ttl_ms = ttl_seconds * 1000
    Cache.put(:api_responses, {:esi, :generic, key}, value, ttl_ms: ttl_ms)
  end

  # Universe cache functions

  @doc """
  Get a system from cache.
  """
  @spec get_system(integer()) :: {:ok, map()} | :miss
  def get_system(system_id) do
    Cache.get(:hot_data, {:universe, :system, system_id})
  end

  @doc """
  Store a system in cache.
  """
  @spec put_system(integer(), map()) :: :ok
  def put_system(system_id, system_data) do
    Cache.put(:hot_data, {:universe, :system, system_id}, system_data)
  end

  @doc """
  Get a type from cache.
  """
  @spec get_type(integer()) :: {:ok, map()} | :miss
  def get_type(type_id) do
    Cache.get(:hot_data, {:universe, :type, type_id})
  end

  @doc """
  Store a type in cache.
  """
  @spec put_type(integer(), map()) :: :ok
  def put_type(type_id, type_data) do
    Cache.put(:hot_data, {:universe, :type, type_id}, type_data)
  end

  @doc """
  Get a group from cache.
  """
  @spec get_group(integer()) :: {:ok, map()} | :miss
  def get_group(group_id) do
    Cache.get(:hot_data, {:universe, :group, group_id})
  end

  @doc """
  Store a group in cache.
  """
  @spec put_group(integer(), map()) :: :ok
  def put_group(group_id, group_data) do
    Cache.put(:hot_data, {:universe, :group, group_id}, group_data)
  end

  @doc """
  Get a category from cache.
  """
  @spec get_category(integer()) :: {:ok, map()} | :miss
  def get_category(category_id) do
    Cache.get(:hot_data, {:universe, :category, category_id})
  end

  @doc """
  Store a category in cache.
  """
  @spec put_category(integer(), map()) :: :ok
  def put_category(category_id, category_data) do
    Cache.put(:hot_data, {:universe, :category, category_id}, category_data)
  end

  # Utility functions

  @doc """
  Clear all caches.
  """
  @spec clear_all() :: :ok
  def clear_all do
    Cache.invalidate_pattern(:api_responses, "esi_*")
    :ok
  end

  @doc """
  Get cache statistics.
  """
  @spec stats() :: %{
          characters: %{size: non_neg_integer(), memory_bytes: number()},
          corporations: %{size: non_neg_integer(), memory_bytes: number()},
          alliances: %{size: non_neg_integer(), memory_bytes: number()},
          universe: %{size: non_neg_integer(), memory_bytes: number()}
        }
  def stats do
    # Get overall stats
    overall_stats = Cache.stats(:api_responses)

    # For compatibility, return the same structure but with estimated values
    # In reality, all data is in one table now
    per_type_estimate = %{
      # Rough estimate
      size: div(overall_stats.size, 4),
      memory_bytes: div(overall_stats.memory_bytes, 4)
    }

    %{
      characters: per_type_estimate,
      corporations: per_type_estimate,
      alliances: per_type_estimate,
      universe: per_type_estimate
    }
  end
end
