defmodule EveDmv.Eve.NameResolver.CacheManager do
  @moduledoc """
  Cache management module for EVE name resolution.

  Handles ETS cache operations, TTL management, atomic operations,
  and cache lifecycle management for the name resolver system.
  """

  require Logger

  # ETS table for caching lookups
  @table_name :eve_name_cache

  # Different TTLs for different data types
  # Ship/item names rarely change
  @static_data_ttl :timer.hours(24)
  # Character/corp names can change
  @dynamic_data_ttl :timer.hours(4)
  # ESI data more frequent updates
  @esi_data_ttl :timer.minutes(30)

  @doc """
  Starts the name resolver cache.
  Called during application startup.
  """
  def start_cache do
    case :ets.whereis(@table_name) do
      :undefined ->
        :ets.new(@table_name, [:set, :public, :named_table])
        Logger.info("Started EVE name resolver cache")

      _pid ->
        Logger.debug("EVE name resolver cache already started")
    end

    :ok
  end

  @doc """
  Clears all cached names. Useful for development/testing.
  """
  def clear_cache do
    case :ets.whereis(@table_name) do
      :undefined ->
        :ok

      _pid ->
        :ets.delete_all_objects(@table_name)
        Logger.info("Cleared EVE name resolver cache")
    end

    :ok
  end

  @doc """
  Gets a value from cache or fetches it using the provided fetch function.
  Handles cache expiration and atomic updates.
  """
  def get_cached_or_fetch(type, id, fetch_fn) do
    cache_key = {type, id}

    case :ets.lookup(@table_name, cache_key) do
      [{^cache_key, value, expires_at}] ->
        if :os.system_time(:millisecond) < expires_at do
          {:ok, value}
        else
          # Cache expired, fetch fresh data
          :ets.delete(@table_name, cache_key)
          fetch_and_cache_atomic(type, id, fetch_fn)
        end

      [] ->
        fetch_and_cache_atomic(type, id, fetch_fn)
    end
  end

  @doc """
  Gets a value from cache without fetching if missing.
  Returns :miss if not found or expired.
  """
  def get_from_cache(type, id) do
    cache_key = {type, id}
    current_time = :os.system_time(:millisecond)

    case :ets.lookup(@table_name, cache_key) do
      [{^cache_key, value, expires_at}] when expires_at > current_time ->
        {:ok, value}

      _ ->
        :miss
    end
  end

  @doc """
  Caches batch results with appropriate TTL.
  """
  def cache_batch_results(type, results) do
    ttl = get_ttl_for_type(type)
    expires_at = :os.system_time(:millisecond) + ttl

    Enum.each(results, fn {id, name} ->
      cache_key = {type, id}
      :ets.insert(@table_name, {cache_key, name, expires_at})
    end)
  end

  @doc """
  Caches a single result with appropriate TTL.
  """
  def cache_result(type, id, value) do
    ttl = get_ttl_for_type(type)
    expires_at = :os.system_time(:millisecond) + ttl
    cache_key = {type, id}
    :ets.insert(@table_name, {cache_key, value, expires_at})
  end

  @doc """
  Gets the appropriate TTL for a given data type.
  """
  def get_ttl_for_type(type)
      when type in [:item_type, :ship_type, :solar_system, :solar_system_full] do
    @static_data_ttl
  end

  def get_ttl_for_type(type) when type in [:character, :corporation, :alliance] do
    @esi_data_ttl
  end

  def get_ttl_for_type(_type), do: @dynamic_data_ttl

  # Private helper functions

  # Atomic cache insertion to prevent race conditions
  defp fetch_and_cache_atomic(type, id, fetch_fn) do
    cache_key = {type, id}

    case fetch_fn.() do
      {:ok, value} ->
        ttl = get_ttl_for_type(type)
        expires_at = :os.system_time(:millisecond) + ttl
        cache_entry = {cache_key, value, expires_at}

        # Use insert_new to atomically insert only if key doesn't exist
        case :ets.insert_new(@table_name, cache_entry) do
          true ->
            {:ok, value}

          false ->
            handle_cache_collision(cache_key, cache_entry, value)
        end

      error ->
        error
    end
  end

  defp handle_cache_collision(cache_key, cache_entry, value) do
    # Another process already inserted this key, use their value
    case :ets.lookup(@table_name, cache_key) do
      [{^cache_key, existing_value, existing_expires}] ->
        if :os.system_time(:millisecond) < existing_expires do
          {:ok, existing_value}
        else
          # Their entry expired too, replace it
          :ets.insert(@table_name, cache_entry)
          {:ok, value}
        end

      [] ->
        # Edge case: they deleted it between insert_new and lookup
        :ets.insert(@table_name, cache_entry)
        {:ok, value}
    end
  end
end
