defmodule EveDmv.Platform.Cache.Corporation.CorporationCache do
  @moduledoc """
  Corporation-specific cache implementation.

  Provides caching functionality for corporation analysis data
  to improve performance of repeated queries.
  """

  require Logger

  @cache_name :corporation_cache
  @default_ttl :timer.hours(1)

  @doc """
  Get a value from the corporation cache.
  """
  def get(key) do
    case :ets.lookup(@cache_name, key) do
      [{^key, value, expires_at}] ->
        if System.system_time(:millisecond) < expires_at do
          value
        else
          :ets.delete(@cache_name, key)
          nil
        end

      [] ->
        nil
    end
  rescue
    ArgumentError ->
      # ETS table doesn't exist
      nil
  end

  @doc """
  Put a value in the corporation cache.
  """
  def put(key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    expires_at = System.system_time(:millisecond) + ttl

    ensure_table_exists()
    :ets.insert(@cache_name, {key, value, expires_at})
    :ok
  rescue
    error ->
      Logger.warning("Failed to cache corporation data: #{inspect(error)}")
      :ok
  end

  @doc """
  Delete a value from the corporation cache.
  """
  def delete(key) do
    case :ets.delete(@cache_name, key) do
      true -> :ok
      false -> :ok
    end
  rescue
    ArgumentError ->
      # ETS table doesn't exist
      :ok
  end

  @doc """
  Clear all corporation cache entries.
  """
  def clear do
    case :ets.whereis(@cache_name) do
      :undefined ->
        :ok

      _pid ->
        :ets.delete_all_objects(@cache_name)
        :ok
    end
  end

  # Private functions

  defp ensure_table_exists do
    case :ets.whereis(@cache_name) do
      :undefined ->
        :ets.new(@cache_name, [:named_table, :public, :set])

      _pid ->
        :ok
    end
  end
end
