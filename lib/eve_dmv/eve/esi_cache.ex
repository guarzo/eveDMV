defmodule EveDmv.Eve.EsiCache do
  @moduledoc """
  ESI cache adapter using the unified cache system with prefixed keys.

  This module maintains the same interface as before but uses a single
  cache with prefixed keys instead of multiple ETS tables.
  """

  alias EveDmv.Utils.Cache

  @cache_name :esi_cache

  # Cache TTLs
  # 10 minutes
  @character_ttl_ms 10 * 60 * 1000
  # 60 minutes
  @corporation_ttl_ms 60 * 60 * 1000
  # 60 minutes
  @alliance_ttl_ms 60 * 60 * 1000
  # 24 hours
  @universe_ttl_ms 24 * 60 * 60 * 1000

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
  """
  def start_link(_opts \\ []) do
    cache_opts = [
      name: @cache_name,
      # Default TTL
      ttl_ms: @character_ttl_ms,
      # Large cache for all ESI data
      max_size: 50_000,
      # 30 minutes
      cleanup_interval_ms: 30 * 60 * 1000
    ]

    Cache.start_link(cache_opts)
  end

  # Character cache functions

  @doc """
  Get a character from cache.
  """
  @spec get_character(integer()) :: {:ok, map()} | :miss
  def get_character(character_id) do
    Cache.get(@cache_name, {:character, character_id})
  end

  @doc """
  Get multiple characters from cache.
  Returns {found_map, missing_list}.
  """
  @spec get_characters([integer()]) :: {map(), [integer()]}
  def get_characters(character_ids) do
    keys = Enum.map(character_ids, &{:character, &1})
    {found, missing_keys} = Cache.get_many(@cache_name, keys)

    # Convert back to character_id => data format
    found_map =
      found
      |> Enum.map(fn {{:character, id}, data} -> {id, data} end)
      |> Enum.into(%{})

    missing_ids = Enum.map(missing_keys, fn {:character, id} -> id end)

    {found_map, missing_ids}
  end

  @doc """
  Store a character in cache.
  """
  @spec put_character(integer(), map()) :: :ok
  def put_character(character_id, character_data) do
    Cache.put(@cache_name, {:character, character_id}, character_data, ttl_ms: @character_ttl_ms)
  end

  # Corporation cache functions

  @doc """
  Get a corporation from cache.
  """
  @spec get_corporation(integer()) :: {:ok, map()} | :miss
  def get_corporation(corporation_id) do
    Cache.get(@cache_name, {:corporation, corporation_id})
  end

  @doc """
  Store a corporation in cache.
  """
  @spec put_corporation(integer(), map()) :: :ok
  def put_corporation(corporation_id, corporation_data) do
    Cache.put(@cache_name, {:corporation, corporation_id}, corporation_data,
      ttl_ms: @corporation_ttl_ms
    )
  end

  # Alliance cache functions

  @doc """
  Get an alliance from cache.
  """
  @spec get_alliance(integer()) :: {:ok, map()} | :miss
  def get_alliance(alliance_id) do
    Cache.get(@cache_name, {:alliance, alliance_id})
  end

  @doc """
  Store an alliance in cache.
  """
  @spec put_alliance(integer(), map()) :: :ok
  def put_alliance(alliance_id, alliance_data) do
    Cache.put(@cache_name, {:alliance, alliance_id}, alliance_data, ttl_ms: @alliance_ttl_ms)
  end

  # Generic cache functions (for backward compatibility)

  @doc """
  Get a value from the generic cache.
  """
  @spec get(String.t()) :: {:ok, term()} | {:error, :not_found}
  def get(key) do
    case Cache.get(@cache_name, {:generic, key}) do
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
    Cache.put(@cache_name, {:generic, key}, value, ttl_ms: ttl_ms)
  end

  # Universe cache functions

  @doc """
  Get a system from cache.
  """
  @spec get_system(integer()) :: {:ok, map()} | :miss
  def get_system(system_id) do
    Cache.get(@cache_name, {:universe, :system, system_id})
  end

  @doc """
  Store a system in cache.
  """
  @spec put_system(integer(), map()) :: :ok
  def put_system(system_id, system_data) do
    Cache.put(@cache_name, {:universe, :system, system_id}, system_data, ttl_ms: @universe_ttl_ms)
  end

  @doc """
  Get a type from cache.
  """
  @spec get_type(integer()) :: {:ok, map()} | :miss
  def get_type(type_id) do
    Cache.get(@cache_name, {:universe, :type, type_id})
  end

  @doc """
  Store a type in cache.
  """
  @spec put_type(integer(), map()) :: :ok
  def put_type(type_id, type_data) do
    Cache.put(@cache_name, {:universe, :type, type_id}, type_data, ttl_ms: @universe_ttl_ms)
  end

  @doc """
  Get a group from cache.
  """
  @spec get_group(integer()) :: {:ok, map()} | :miss
  def get_group(group_id) do
    Cache.get(@cache_name, {:universe, :group, group_id})
  end

  @doc """
  Store a group in cache.
  """
  @spec put_group(integer(), map()) :: :ok
  def put_group(group_id, group_data) do
    Cache.put(@cache_name, {:universe, :group, group_id}, group_data, ttl_ms: @universe_ttl_ms)
  end

  @doc """
  Get a category from cache.
  """
  @spec get_category(integer()) :: {:ok, map()} | :miss
  def get_category(category_id) do
    Cache.get(@cache_name, {:universe, :category, category_id})
  end

  @doc """
  Store a category in cache.
  """
  @spec put_category(integer(), map()) :: :ok
  def put_category(category_id, category_data) do
    Cache.put(@cache_name, {:universe, :category, category_id}, category_data,
      ttl_ms: @universe_ttl_ms
    )
  end

  # Utility functions

  @doc """
  Clear all caches.
  """
  @spec clear_all() :: :ok
  def clear_all do
    Cache.clear(@cache_name)
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
    overall_stats = Cache.stats(@cache_name)

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
