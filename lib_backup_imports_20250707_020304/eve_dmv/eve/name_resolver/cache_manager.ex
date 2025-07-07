defmodule EveDmv.Eve.NameResolver.CacheManager do
  alias EveDmv.Cache

  require Logger
  @moduledoc """
  Cache management module for EVE name resolution.

  This module has been migrated from direct ETS usage to use the unified EveDmv.Cache system
  for better consistency and centralized cache management.
  """



  # Different TTLs for different data types
  # Ship/item names rarely change
  @static_data_ttl :timer.hours(24)
  # Character/corp names can change
  @dynamic_data_ttl :timer.hours(4)
  # ESI data more frequent updates
  @esi_data_ttl :timer.minutes(30)

  @doc """
  Gets a cached name for the given ID and type, with appropriate TTL.
  """
  @spec get_cached_name(integer(), atom()) :: {:ok, String.t()} | {:error, :not_found}
  def get_cached_name(id, type) when is_integer(id) and is_atom(type) do
    cache_key = {type, id}

    case Cache.get(:hot_data, cache_key) do
      {:ok, name} -> {:ok, name}
      :miss -> {:error, :not_found}
    end
  end

  @doc """
  Caches a name with the appropriate TTL based on type.
  """
  @spec cache_name(integer(), atom(), String.t()) :: :ok
  def cache_name(id, type, name) when is_integer(id) and is_atom(type) and is_binary(name) do
    cache_key = {type, id}
    ttl = get_ttl_for_type(type)

    Cache.put(:hot_data, cache_key, name, ttl: ttl)
    :ok
  end

  @doc """
  Checks if a name is cached for the given ID and type.
  """
  @spec cached?(integer(), atom()) :: boolean()
  def cached?(id, type) when is_integer(id) and is_atom(type) do
    cache_key = {type, id}

    case Cache.get(:hot_data, cache_key) do
      {:ok, _name} -> true
      :miss -> false
    end
  end

  @doc """
  Caches multiple names in a batch operation.
  """
  @spec cache_names([{integer(), atom(), String.t()}]) :: :ok
  def cache_names(name_tuples) when is_list(name_tuples) do
    entries =
      Enum.map(name_tuples, fn {id, type, name} ->
        cache_key = {type, id}
        ttl = get_ttl_for_type(type)
        {cache_key, name, ttl}
      end)

    Cache.put_many(:hot_data, entries)
    Logger.debug("Cached #{length(name_tuples)} names in batch")
    :ok
  end

  @doc """
  Invalidates cached name for the given ID and type.
  """
  @spec invalidate_name(integer(), atom()) :: :ok
  def invalidate_name(id, type) when is_integer(id) and is_atom(type) do
    cache_key = {type, id}
    Cache.delete(:hot_data, cache_key)
    :ok
  end

  @doc """
  Invalidates all cached names for a specific type.
  """
  @spec invalidate_type(atom()) :: :ok
  def invalidate_type(type) when is_atom(type) do
    # Pattern-based invalidation not available, would need custom implementation
    # For now, log a warning and do nothing
    Logger.warning("Pattern-based cache invalidation not implemented for type: #{type}")
    :ok
  end

  @doc """
  Clears all cached names. Useful for development/testing.
  """
  def clear_cache do
    Cache.clear(:hot_data)
    Logger.info("Cleared EVE name resolver cache")
    :ok
  end

  @doc """
  Gets cache statistics for monitoring.
  """
  @spec get_cache_stats() :: map()
  def get_cache_stats do
    Cache.stats(:hot_data)
  end

  @doc """
  Warms the cache with commonly accessed names.
  """
  @spec warm_cache([{integer(), atom()}]) :: :ok
  def warm_cache(id_type_pairs) when is_list(id_type_pairs) do
    Logger.info("Warming name resolver cache for #{length(id_type_pairs)} entities")

    # This would typically trigger async resolution for uncached names
    # For now, we'll just check what's already cached
    cached_count = Enum.count(id_type_pairs, fn {id, type} -> cached?(id, type) end)
    Logger.debug("#{cached_count}/#{length(id_type_pairs)} names already cached")

    :ok
  end

  @doc """
  Gets the appropriate TTL for a given type.
  """
  @spec get_ttl_for_type(atom()) :: non_neg_integer()
  def get_ttl_for_type(type) do
    case type do
      # Static data types (ships, items, systems, etc.)
      type
      when type in [:ship, :item, :system, :constellation, :region, :station, :structure_type] ->
        @static_data_ttl

      # Dynamic data types (characters, corporations, alliances)
      type when type in [:character, :corporation, :alliance] ->
        @dynamic_data_ttl

      # ESI-sourced data with frequent updates
      type when type in [:structure, :esi_character, :esi_corporation, :esi_alliance] ->
        @esi_data_ttl

      # Default TTL for unknown types
      _ ->
        @dynamic_data_ttl
    end
  end

  @doc """
  Legacy compatibility function - no longer needs to start anything.
  """
  def start_cache do
    Logger.debug("EVE name resolver cache using unified cache system")
    :ok
  end

  # Adapter methods for backward compatibility

  @doc """
  Gets a cached value or fetches it using the provided function if not cached.
  This is an adapter method for backward compatibility.
  """
  @spec get_cached_or_fetch(atom(), integer(), function()) :: {:ok, String.t()} | {:error, term()}
  def get_cached_or_fetch(type, id, fetch_fn)
      when is_atom(type) and is_integer(id) and is_function(fetch_fn, 0) do
    case get_cached_name(id, type) do
      {:ok, name} ->
        {:ok, name}

      {:error, :not_found} ->
        case fetch_fn.() do
          {:ok, name} = result ->
            cache_name(id, type, name)
            result

          error ->
            error
        end
    end
  end

  @doc """
  Caches multiple results in batch format.
  This is an adapter method for backward compatibility.
  """
  @spec cache_batch_results(atom(), map()) :: :ok
  def cache_batch_results(type, results) when is_atom(type) and is_map(results) do
    name_tuples = Enum.map(results, fn {id, name} -> {id, type, name} end)
    cache_names(name_tuples)
  end

  @doc """
  Retrieves a single cached value.
  This is an adapter method for backward compatibility.
  """
  @spec get_from_cache(atom(), integer()) :: {:ok, String.t()} | {:error, :not_found}
  def get_from_cache(type, id) when is_atom(type) and is_integer(id) do
    get_cached_name(id, type)
  end

  @doc """
  Caches a single result.
  This is an adapter method for backward compatibility.
  """
  @spec cache_result(atom(), integer(), String.t()) :: :ok
  def cache_result(type, id, name) when is_atom(type) and is_integer(id) and is_binary(name) do
    cache_name(id, type, name)
  end
end
