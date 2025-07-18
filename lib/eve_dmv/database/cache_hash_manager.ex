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

  defp extract_corp_data(cache_key) do
    # Extract corporation data from the cached entry
    case QueryCache.get(cache_key) do
      {:ok, cached_data} when is_map(cached_data) ->
        # Extract relevant fields for comparison
        corp_data = %{
          member_count: Map.get(cached_data, :member_count, 0),
          last_activity: Map.get(cached_data, :last_activity, DateTime.utc_now()),
          total_kills: Map.get(cached_data, :total_kills, 0),
          total_losses: Map.get(cached_data, :total_losses, 0)
        }

        {:ok, corp_data}

      _ ->
        {:error, :no_cached_data}
    end
  end

  defp fetch_current_corp_data(corp_id) do
    # Fetch current corporation data from database
    # This queries the corporation summary and recent activity

    # Query for member count from corporation table or killmail data
    alias EveDmv.Killmails.KillmailRaw
    import Ash.Query

    # Last 7 days
    cutoff_date = DateTime.add(DateTime.utc_now(), -7, :day)

    # Get recent corporation activity from killmails (victim side only for simplicity)
    corp_query =
      KillmailRaw
      |> new()
      |> filter(victim_corporation_id: corp_id)
      |> filter(killmail_time: [gte: cutoff_date])
      |> limit(100)

    # Also get recent killmails to search for attacker involvement
    recent_query =
      KillmailRaw
      |> new()
      |> filter(killmail_time: [gte: cutoff_date])
      |> limit(500)

    with {:ok, victim_kills} <- Ash.read(corp_query, domain: EveDmv.Api),
         {:ok, recent_killmails} <- Ash.read(recent_query, domain: EveDmv.Api) do
      # Filter recent killmails for attacker involvement
      attacker_kills =
        Enum.filter(recent_killmails, fn km ->
          case km.raw_data do
            %{"attackers" => attackers} when is_list(attackers) ->
              Enum.any?(attackers, &(&1["corporation_id"] == corp_id))

            _ ->
              false
          end
        end)

      all_killmails = Enum.uniq_by(victim_kills ++ attacker_kills, & &1.killmail_id)

      # Get unique character count as proxy for member count
      unique_chars =
        (Enum.map(victim_kills, & &1.victim_character_id) ++
           Enum.flat_map(attacker_kills, fn km ->
             case km.raw_data do
               %{"attackers" => attackers} ->
                 attackers
                 |> Enum.filter(&(&1["corporation_id"] == corp_id))
                 |> Enum.map(& &1["character_id"])

               _ ->
                 []
             end
           end))
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      last_activity =
        if Enum.empty?(all_killmails) do
          # Default to 30 days ago
          DateTime.utc_now() |> DateTime.add(-30, :day)
        else
          all_killmails
          |> Enum.max_by(& &1.killmail_time, DateTime)
          |> Map.get(:killmail_time)
        end

      corp_data = %{
        member_count: length(unique_chars),
        last_activity: last_activity,
        total_kills: length(attacker_kills),
        total_losses: length(victim_kills)
      }

      {:ok, corp_data}
    else
      {:error, reason} ->
        Logger.warning("Failed to fetch corporation data for #{corp_id}: #{inspect(reason)}")
        # Return default data structure
        {:ok,
         %{
           member_count: 0,
           last_activity: DateTime.utc_now() |> DateTime.add(-30, :day),
           total_kills: 0,
           total_losses: 0
         }}
    end
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

  defp extract_killmail_hash(cache_key) do
    # Extract hash from ETS table or compute from cached data
    case :ets.lookup(@hash_table, cache_key) do
      [{^cache_key, hash, _expiry}] ->
        {:ok, hash}

      [] ->
        # Try to compute hash from cached killmail data
        case QueryCache.get(cache_key) do
          {:ok, cached_killmail} ->
            hash = compute_killmail_content_hash(cached_killmail)
            {:ok, hash}

          _ ->
            {:error, :no_hash_found}
        end
    end
  end

  defp compute_killmail_hash(killmail_id) do
    # Fetch fresh killmail data and compute content hash
    alias EveDmv.Killmails.KillmailRaw
    import Ash.Query

    query =
      KillmailRaw
      |> new()
      |> filter(killmail_id: killmail_id)
      |> limit(1)

    case Ash.read(query, domain: EveDmv.Api) do
      {:ok, [killmail]} ->
        hash = compute_killmail_content_hash(killmail)
        {:ok, hash}

      {:ok, []} ->
        {:error, :killmail_not_found}

      {:error, reason} ->
        Logger.warning("Failed to fetch killmail #{killmail_id}: #{inspect(reason)}")
        {:error, :database_error}
    end
  end

  defp compute_killmail_content_hash(killmail) do
    # Create hash based on killmail content that matters for cache validity
    content = %{
      killmail_id: killmail.killmail_id,
      victim_character_id: killmail.victim_character_id,
      victim_corporation_id: killmail.victim_corporation_id,
      victim_alliance_id: killmail.victim_alliance_id,
      victim_ship_type_id: killmail.victim_ship_type_id,
      killmail_time: killmail.killmail_time,
      # Key parts of raw_data that affect analysis
      attackers_count:
        case killmail.raw_data do
          %{"attackers" => attackers} when is_list(attackers) -> length(attackers)
          _ -> 0
        end,
      total_value: Map.get(killmail.raw_data || %{}, "zkb", %{}) |> Map.get("totalValue", 0)
    }

    # Create deterministic hash
    content
    |> :erlang.term_to_binary()
    |> :crypto.hash(:sha256)
    |> Base.encode16()
  end
end
