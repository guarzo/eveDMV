defmodule EveDmv.Cache do
  @moduledoc """
  Unified cache interface for EVE DMV application.

  Provides a simple, consistent API for accessing three specialized cache types:
  - :hot_data - Fast access for frequently used data (characters, systems, items)
  - :api_responses - External API responses with longer TTL (ESI, Janice, Mutamarket)
  - :analysis - Intelligence analysis results with domain-specific TTL

  This module acts as the primary interface for all caching needs in the application,
  automatically routing cache operations to the appropriate specialized cache.

  ## Examples

      # Cache character data (hot data)
      EveDmv.Cache.put(:hot_data, {:character, 123}, character_data)
      {:ok, data} = EveDmv.Cache.get(:hot_data, {:character, 123})
      
      # Cache API response
      EveDmv.Cache.put(:api_responses, {:esi, :character, 123}, esi_response)
      
      # Cache analysis result
      EveDmv.Cache.put(:analysis, {:character_intel, 123}, intel_data)
  """

  alias EveDmv.Utils.Cache
  alias EveDmv.CacheSupervisor

  @type cache_type :: :hot_data | :api_responses | :analysis
  @type cache_key :: term()
  @type cache_value :: term()

  @doc """
  Get a value from the specified cache type.

  Returns {:ok, value} if found, :miss if not found or expired.
  """
  @spec get(cache_type(), cache_key()) :: {:ok, cache_value()} | :miss
  def get(cache_type, key) do
    cache_name = CacheSupervisor.cache_name(cache_type)
    Cache.get(cache_name, key)
  end

  @doc """
  Get multiple values from the specified cache type.

  Returns {found_map, missing_keys}.
  """
  @spec get_many(cache_type(), [cache_key()]) :: {map(), [cache_key()]}
  def get_many(cache_type, keys) do
    cache_name = CacheSupervisor.cache_name(cache_type)
    Cache.get_many(cache_name, keys)
  end

  @doc """
  Put a value in the specified cache type.

  Uses cache-type-specific TTL unless overridden in opts.
  """
  @spec put(cache_type(), cache_key(), cache_value(), keyword()) :: :ok
  def put(cache_type, key, value, opts \\ []) do
    cache_name = CacheSupervisor.cache_name(cache_type)
    Cache.put(cache_name, key, value, opts)
  end

  @doc """
  Put multiple values in the specified cache type.
  """
  @spec put_many(cache_type(), [{cache_key(), cache_value()}], keyword()) :: :ok
  def put_many(cache_type, entries, opts \\ []) do
    cache_name = CacheSupervisor.cache_name(cache_type)
    Cache.put_many(cache_name, entries, opts)
  end

  @doc """
  Get or compute a value from the specified cache type.

  If the value is not found, calls compute_fn to generate it and stores the result.
  """
  @spec get_or_compute(cache_type(), cache_key(), (-> cache_value()), keyword()) :: cache_value()
  def get_or_compute(cache_type, key, compute_fn, opts \\ []) do
    cache_name = CacheSupervisor.cache_name(cache_type)
    Cache.get_or_compute(cache_name, key, compute_fn, opts)
  end

  @doc """
  Delete a key from the specified cache type.
  """
  @spec delete(cache_type(), cache_key()) :: :ok
  def delete(cache_type, key) do
    cache_name = CacheSupervisor.cache_name(cache_type)
    Cache.delete(cache_name, key)
  end

  @doc """
  Clear all entries from the specified cache type.
  """
  @spec clear(cache_type()) :: :ok
  def clear(cache_type) do
    cache_name = CacheSupervisor.cache_name(cache_type)
    Cache.clear(cache_name)
  end

  @doc """
  Invalidate entries matching a pattern in the specified cache type.

  Pattern uses * as wildcard (e.g., "user_*").
  Returns the number of invalidated entries.
  """
  @spec invalidate_pattern(cache_type(), String.t()) :: non_neg_integer()
  def invalidate_pattern(cache_type, pattern) do
    cache_name = CacheSupervisor.cache_name(cache_type)
    Cache.invalidate_pattern(cache_name, pattern)
  end

  @doc """
  Get statistics for the specified cache type.
  """
  @spec stats(cache_type()) :: map()
  def stats(cache_type) do
    cache_name = CacheSupervisor.cache_name(cache_type)
    Cache.stats(cache_name)
  end

  @doc """
  Get statistics for all cache types.
  """
  @spec all_stats() :: map()
  def all_stats do
    CacheSupervisor.all_cache_stats()
  end

  @doc """
  Clear all caches of all types.
  """
  @spec clear_all() :: :ok
  def clear_all do
    CacheSupervisor.clear_all_caches()
  end

  # Convenience functions for specific data types

  @doc """
  Cache character data in hot data cache.
  """
  @spec put_character(integer(), map()) :: :ok
  def put_character(character_id, character_data) do
    put(:hot_data, {:character, character_id}, character_data)
  end

  @doc """
  Get character data from hot data cache.
  """
  @spec get_character(integer()) :: {:ok, map()} | :miss
  def get_character(character_id) do
    get(:hot_data, {:character, character_id})
  end

  @doc """
  Cache ESI API response.
  """
  @spec put_esi_response(atom(), term(), map()) :: :ok
  def put_esi_response(endpoint, identifier, response_data) do
    put(:api_responses, {:esi, endpoint, identifier}, response_data)
  end

  @doc """
  Get ESI API response.
  """
  @spec get_esi_response(atom(), term()) :: {:ok, map()} | :miss
  def get_esi_response(endpoint, identifier) do
    get(:api_responses, {:esi, endpoint, identifier})
  end

  @doc """
  Cache price data from external APIs.
  """
  @spec put_price_data(integer(), map()) :: :ok
  def put_price_data(type_id, price_data) do
    put(:api_responses, {:price, type_id}, price_data)
  end

  @doc """
  Get price data from cache.
  """
  @spec get_price_data(integer()) :: {:ok, map()} | :miss
  def get_price_data(type_id) do
    get(:api_responses, {:price, type_id})
  end

  @doc """
  Cache intelligence analysis results.
  """
  @spec put_analysis(atom(), integer(), map()) :: :ok
  def put_analysis(analysis_type, subject_id, analysis_data) do
    put(:analysis, {analysis_type, subject_id}, analysis_data)
  end

  @doc """
  Get intelligence analysis results.
  """
  @spec get_analysis(atom(), integer()) :: {:ok, map()} | :miss
  def get_analysis(analysis_type, subject_id) do
    get(:analysis, {analysis_type, subject_id})
  end
end
