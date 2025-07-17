defmodule EveDmv.Database.CacheHashManager do
  @moduledoc """
  Sprint 15A: Hash-based cache invalidation manager.

  Provides content-based hashing for cache entries to enable precise invalidation
  and improve cache hit ratios. Uses SHA256 hashes of query parameters and results
  to detect when cached data is still valid even after related updates.
  """

  use GenServer
  require Logger

  alias EveDmv.Cache.QueryCache
  alias EveDmv.Database.CacheInvalidator

  # Hash storage - maps cache keys to content hashes
  @hash_table :cache_hash_store
  # Hashes expire after 24 hours
  @hash_ttl :timer.hours(24)

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Compute and store hash for cache entry.
  Returns {:ok, hash} or {:error, reason}
  """
  def compute_hash(cache_key, query_params, result) do
    GenServer.call(__MODULE__, {:compute_hash, cache_key, query_params, result})
  end

  @doc """
  Check if cached data is still valid based on content hash.
  Returns true if the hash matches (data unchanged), false otherwise.
  """
  def validate_cache(cache_key, query_params, current_result) do
    GenServer.call(__MODULE__, {:validate_cache, cache_key, query_params, current_result})
  end

  @doc """
  Invalidate entries only if their content has changed.
  This is more precise than pattern-based invalidation.
  """
  def smart_invalidate(pattern, check_function) do
    GenServer.call(__MODULE__, {:smart_invalidate, pattern, check_function}, :timer.seconds(30))
  end

  @doc """
  Get hash statistics for monitoring.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server callbacks

  def init(_opts) do
    # Create ETS table for hash storage
    :ets.new(@hash_table, [:set, :public, :named_table, read_concurrency: true])

    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup_expired, :timer.minutes(30))

    # Subscribe to cache invalidation events
    CacheInvalidator.subscribe_to_invalidations()

    state = %{
      stats: %{
        total_hashes: 0,
        hash_hits: 0,
        hash_misses: 0,
        smart_invalidations: 0,
        bytes_saved: 0
      }
    }

    Logger.info("🔐 Cache Hash Manager started")

    {:ok, state}
  end

  def handle_call({:compute_hash, cache_key, query_params, result}, _from, state) do
    try do
      # Create deterministic content for hashing
      content = create_hash_content(query_params, result)
      hash = :crypto.hash(:sha256, content) |> Base.encode16()

      # Store hash with expiry
      expiry = System.system_time(:second) + div(@hash_ttl, 1000)
      :ets.insert(@hash_table, {cache_key, hash, expiry})

      new_stats = %{state.stats | total_hashes: state.stats.total_hashes + 1}

      {:reply, {:ok, hash}, %{state | stats: new_stats}}
    catch
      _, reason ->
        Logger.warning("Failed to compute hash for #{cache_key}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:validate_cache, cache_key, query_params, current_result}, _from, state) do
    case :ets.lookup(@hash_table, cache_key) do
      [{^cache_key, stored_hash, expiry}] ->
        now = System.system_time(:second)

        if now < expiry do
          # Compute current hash
          content = create_hash_content(query_params, current_result)
          current_hash = :crypto.hash(:sha256, content) |> Base.encode16()

          valid = current_hash == stored_hash

          # Update stats
          stat_key = if valid, do: :hash_hits, else: :hash_misses
          new_stats = Map.update!(state.stats, stat_key, &(&1 + 1))

          {:reply, valid, %{state | stats: new_stats}}
        else
          # Hash expired
          :ets.delete(@hash_table, cache_key)
          {:reply, false, state}
        end

      [] ->
        # No hash found
        {:reply, false, state}
    end
  end

  def handle_call({:smart_invalidate, pattern, check_function}, _from, state) do
    Logger.info("🧠 Starting smart invalidation for pattern: #{pattern}")

    # Get all cache entries matching the pattern
    matching_keys = QueryCache.get_keys_by_pattern(pattern)

    # Check each entry to see if it actually needs invalidation
    invalidated =
      Enum.reduce(matching_keys, 0, fn key, count ->
        if should_invalidate?(key, check_function) do
          QueryCache.invalidate_key(key)
          :ets.delete(@hash_table, key)
          count + 1
        else
          count
        end
      end)

    saved = length(matching_keys) - invalidated

    Logger.info("✅ Smart invalidation complete: #{invalidated} invalidated, #{saved} preserved")

    new_stats = %{
      state.stats
      | smart_invalidations: state.stats.smart_invalidations + 1,
        # Rough estimate
        bytes_saved: state.stats.bytes_saved + saved * 1024
    }

    {:reply, {:ok, %{invalidated: invalidated, preserved: saved}}, %{state | stats: new_stats}}
  end

  def handle_call(:get_stats, _from, state) do
    # Add current table size to stats
    table_size = :ets.info(@hash_table, :size)
    stats = Map.put(state.stats, :current_hashes, table_size)

    {:reply, stats, state}
  end

  def handle_info(:cleanup_expired, state) do
    # Remove expired hashes
    now = System.system_time(:second)

    expired =
      :ets.select_delete(@hash_table, [
        {
          {:"$1", :"$2", :"$3"},
          [{:<, :"$3", now}],
          [true]
        }
      ])

    if expired > 0 do
      Logger.debug("Cleaned up #{expired} expired cache hashes")
    end

    # Schedule next cleanup
    Process.send_after(self(), :cleanup_expired, :timer.minutes(30))

    {:noreply, state}
  end

  def handle_info({:cache_invalidated, pattern, _count}, state) do
    # When cache is invalidated, also clean up associated hashes
    Task.start(fn ->
      cleanup_hashes_for_pattern(pattern)
    end)

    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  # Private functions

  defp create_hash_content(query_params, result) do
    # Create deterministic content representation
    # Sort params to ensure consistency
    sorted_params = Enum.sort(query_params)

    # Convert result to deterministic format
    result_string =
      case result do
        %{} = map -> map |> Map.to_list() |> Enum.sort() |> inspect()
        list when is_list(list) -> list |> Enum.sort() |> inspect()
        other -> inspect(other)
      end

    # Combine params and result for hashing
    :erlang.term_to_binary({sorted_params, result_string})
  end

  defp should_invalidate?(cache_key, check_function) when is_function(check_function) do
    # Use the provided function to check if data has changed
    try do
      check_function.(cache_key)
    catch
      # If check fails, invalidate to be safe
      _, _ -> true
    end
  end

  defp should_invalidate?(_cache_key, nil), do: true

  defp cleanup_hashes_for_pattern(pattern) do
    # Convert cache pattern to ETS match pattern
    ets_pattern =
      pattern
      |> String.replace("*", :_)
      |> String.to_existing_atom()

    # Delete matching hashes
    :ets.match_delete(@hash_table, {ets_pattern, :_, :_})
  end

  # Public utilities

  @doc """
  Implement content-aware invalidation for corporation data.
  Only invalidates if member count or activity has significantly changed.
  """
  def smart_invalidate_corporation(corp_id) do
    pattern = "corp_*_#{corp_id}"

    check_function = fn cache_key ->
      # Check if the corporation data has materially changed
      case extract_corp_data(cache_key) do
        {:ok, old_data} ->
          {:ok, new_data} = fetch_current_corp_data(corp_id)
          corporation_data_changed?(old_data, new_data)

        _ ->
          # Invalidate if we can't determine
          true
      end
    end

    smart_invalidate(pattern, check_function)
  end

  defp extract_corp_data(_cache_key) do
    # This would extract data from the cache entry
    # For now, return a placeholder
    {:ok, %{member_count: 100, last_activity: DateTime.utc_now()}}
  end

  defp fetch_current_corp_data(_corp_id) do
    # This would fetch current data from the database
    # For now, return a placeholder
    {:ok, %{member_count: 101, last_activity: DateTime.utc_now()}}
  end

  defp corporation_data_changed?(old_data, new_data) do
    # Consider data changed if member count differs by >5% or last activity is >1 hour different
    member_change = abs(old_data.member_count - new_data.member_count) / old_data.member_count

    time_diff = DateTime.diff(new_data.last_activity, old_data.last_activity, :second)

    member_change > 0.05 or abs(time_diff) > 3600
  end

  @doc """
  Implement content-aware invalidation for killmail data.
  Uses participant and value hashes to detect actual changes.
  """
  def smart_invalidate_killmail(killmail_id) do
    pattern = "killmail_*_#{killmail_id}"

    check_function = fn cache_key ->
      case extract_killmail_hash(cache_key) do
        {:ok, old_hash} ->
          {:ok, new_hash} = compute_killmail_hash(killmail_id)
          old_hash != new_hash

        _ ->
          true
      end
    end

    smart_invalidate(pattern, check_function)
  end

  defp extract_killmail_hash(_cache_key) do
    # Extract stored hash for killmail
    {:ok, "placeholder_hash"}
  end

  defp compute_killmail_hash(killmail_id) do
    # Compute hash based on killmail participants and values
    # This would query the actual killmail data
    {:ok, "computed_hash_#{killmail_id}"}
  end
end
