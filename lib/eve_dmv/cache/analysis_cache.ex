defmodule EveDmv.Cache.AnalysisCache do
  @moduledoc """
  Simple ETS-based cache for character and corporation analysis data.

  Caches expensive computations like killmail analysis, member statistics,
  timezone analysis, and location data to improve page load performance.
  """

  use GenServer

  require Logger

  @cache_table :analysis_cache
  # 15 minutes cache TTL
  @default_ttl :timer.minutes(15)
  # Clean expired entries every 5 minutes
  @cleanup_interval :timer.minutes(5)

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get cached corporation data or compute and cache it using the provided function.

  ## Examples

      iex> get_or_compute("members_123", fn -> expensive_member_calculation(123) end)
      {:ok, member_data}
  """
  def get_or_compute(cache_key, compute_fn, ttl \\ @default_ttl) do
    case get(cache_key) do
      {:ok, data} ->
        Logger.debug("Cache hit for key: #{cache_key}")
        {:ok, data}

      :miss ->
        Logger.debug("Cache miss for key: #{cache_key}, computing...")

        case compute_fn.() do
          {:ok, data} ->
            put(cache_key, data, ttl)
            {:ok, data}

          data when not is_tuple(data) ->
            # Handle functions that return data directly (not wrapped in {:ok, data})
            put(cache_key, data, ttl)
            {:ok, data}

          error ->
            Logger.warning("Failed to compute data for cache key #{cache_key}: #{inspect(error)}")
            error
        end
    end
  end

  @doc """
  Get data from cache.

  Returns `{:ok, data}` if found and not expired, `:miss` otherwise.
  """
  def get(cache_key) do
    case :ets.lookup(@cache_table, cache_key) do
      [{^cache_key, data, expires_at}] ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          {:ok, data}
        else
          # Expired, remove it
          :ets.delete(@cache_table, cache_key)
          :miss
        end

      [] ->
        :miss
    end
  end

  @doc """
  Put data into cache with TTL.
  """
  def put(cache_key, data, ttl \\ @default_ttl) do
    expires_at = DateTime.add(DateTime.utc_now(), ttl, :millisecond)
    :ets.insert(@cache_table, {cache_key, data, expires_at})
    :ok
  end

  @doc """
  Remove specific key from cache.
  """
  def delete(cache_key) do
    :ets.delete(@cache_table, cache_key)
    :ok
  end

  @doc """
  Clear all cached data for a corporation.
  """
  def invalidate_corporation(corporation_id) do
    pattern = {"corp_#{corporation_id}_*", :_, :_}
    :ets.match_delete(@cache_table, pattern)
    Logger.info("Invalidated cache for corporation #{corporation_id}")
    :ok
  end

  @doc """
  Clear all cached data for a character.
  """
  def invalidate_character(character_id) do
    pattern = {"char_#{character_id}_*", :_, :_}
    :ets.match_delete(@cache_table, pattern)
    Logger.info("Invalidated cache for character #{character_id}")
    :ok
  end

  @doc """
  Clear all cache entries.
  """
  def clear_all do
    :ets.delete_all_objects(@cache_table)
    Logger.info("Cleared all analysis cache entries")
    :ok
  end

  @doc """
  Get cache statistics.
  """
  def stats do
    total_entries = :ets.info(@cache_table, :size)
    memory_usage = :ets.info(@cache_table, :memory) * :erlang.system_info(:wordsize)

    %{
      total_entries: total_entries,
      memory_bytes: memory_usage,
      memory_mb: Float.round(memory_usage / (1024 * 1024), 2)
    }
  end

  # Helper functions for generating cache keys

  # Corporation cache keys
  def corp_info_key(corporation_id), do: "corp_#{corporation_id}_info"
  def corp_members_key(corporation_id), do: "corp_#{corporation_id}_members"
  def corp_timezone_key(corporation_id), do: "corp_#{corporation_id}_timezone"
  def corp_location_key(corporation_id), do: "corp_#{corporation_id}_locations"
  def corp_victims_key(corporation_id), do: "corp_#{corporation_id}_victims"
  def corp_activity_key(corporation_id), do: "corp_#{corporation_id}_activity"
  def corp_intelligence_key(corporation_id), do: "corp_#{corporation_id}_intelligence"

  # Character cache keys
  def char_analysis_key(character_id), do: "char_#{character_id}_analysis"
  def char_ships_key(character_id), do: "char_#{character_id}_ships"
  def char_weapons_key(character_id), do: "char_#{character_id}_weapons"
  def char_external_groups_key(character_id), do: "char_#{character_id}_external_groups"
  def char_gang_patterns_key(character_id), do: "char_#{character_id}_gang_patterns"
  def char_intel_summary_key(character_id), do: "char_#{character_id}_intel_summary"

  # GenServer callbacks

  @impl GenServer
  def init(_opts) do
    # Create ETS table for cache storage
    table =
      :ets.new(@cache_table, [
        :named_table,
        :public,
        :set,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ])

    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.info("Analysis cache started with table: #{inspect(table)}")
    {:ok, %{table: table}}
  end

  @impl GenServer
  def handle_info(:cleanup_expired, state) do
    cleanup_expired_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private functions

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_expired, @cleanup_interval)
  end

  defp cleanup_expired_entries do
    now = DateTime.utc_now()

    # Find all expired entries
    expired_keys =
      :ets.foldl(
        fn {key, _data, expires_at}, acc ->
          if DateTime.compare(now, expires_at) != :lt do
            [key | acc]
          else
            acc
          end
        end,
        [],
        @cache_table
      )

    # Delete expired entries
    Enum.each(expired_keys, &:ets.delete(@cache_table, &1))

    if length(expired_keys) > 0 do
      Logger.debug("Cleaned up #{length(expired_keys)} expired cache entries")
    end
  end
end
