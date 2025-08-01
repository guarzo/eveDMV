defmodule EveDmv.Contexts.Surveillance.Infrastructure.MatchCache do
  @moduledoc """
  Caching layer for surveillance profile matches.
  
  Provides fast access to match results and prevents duplicate processing
  of killmails against surveillance profiles.
  """
  
  use GenServer
  require Logger
  
  # ETS table names
  @matches_table :surveillance_matches
  @stats_table :surveillance_match_stats
  
  # Cache configuration
  @default_ttl 3600  # 1 hour default TTL
  @cleanup_interval 300_000  # Cleanup every 5 minutes
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  # Public API
  
  @doc """
  Cache a match result for a profile and killmail.
  """
  @spec put(binary(), integer(), map()) :: :ok
  def put(profile_id, killmail_id, match_data) do
    GenServer.call(__MODULE__, {:put, profile_id, killmail_id, match_data})
  end
  
  @doc """
  Get cached match result for a profile and killmail.
  """
  @spec get(binary(), integer()) :: {:ok, map()} | {:error, :not_found}
  def get(profile_id, killmail_id) do
    GenServer.call(__MODULE__, {:get, profile_id, killmail_id})
  end
  
  @doc """
  Get all cached matches for a profile.
  """
  @spec get_cached_matches(binary(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def get_cached_matches(profile_id, opts \\ []) do
    GenServer.call(__MODULE__, {:get_cached_matches, profile_id, opts})
  end
  
  @doc """
  Invalidate cache for a specific profile.
  """
  @spec invalidate_profile_cache(binary()) :: :ok
  def invalidate_profile_cache(profile_id) do
    GenServer.call(__MODULE__, {:invalidate_profile, profile_id})
  end
  
  @doc """
  Check if a killmail has been processed for a profile.
  """
  @spec has_match?(binary(), integer()) :: boolean()
  def has_match?(profile_id, killmail_id) do
    case get(profile_id, killmail_id) do
      {:ok, _} -> true
      {:error, :not_found} -> false
    end
  end
  
  @doc """
  Get cache statistics.
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end
  
  @doc """
  Clear all cached data.
  """
  @spec clear_all() :: :ok
  def clear_all do
    GenServer.call(__MODULE__, :clear_all)
  end
  
  # GenServer callbacks
  
  @impl GenServer
  def init(_opts) do
    # Create ETS tables
    :ets.new(@matches_table, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(@stats_table, [:named_table, :set, :public, read_concurrency: true])
    
    # Initialize stats
    :ets.insert(@stats_table, {
      :cache_stats,
      %{
        total_matches: 0,
        cache_hits: 0,
        cache_misses: 0,
        profiles_cached: 0,
        last_cleanup: DateTime.utc_now()
      }
    })
    
    # Schedule periodic cleanup
    schedule_cleanup()
    
    Logger.info("MatchCache started with ETS tables")
    {:ok, %{}}
  end
  
  @impl GenServer
  def handle_call({:put, profile_id, killmail_id, match_data}, _from, state) do
    cache_key = build_cache_key(profile_id, killmail_id)
    
    cache_entry = %{
      profile_id: profile_id,
      killmail_id: killmail_id,
      match_data: match_data,
      cached_at: DateTime.utc_now(),
      expires_at: DateTime.add(DateTime.utc_now(), @default_ttl, :second)
    }
    
    :ets.insert(@matches_table, {cache_key, cache_entry})
    
    # Update stats
    update_cache_stats(:put)
    
    {:reply, :ok, state}
  end
  
  @impl GenServer
  def handle_call({:get, profile_id, killmail_id}, _from, state) do
    cache_key = build_cache_key(profile_id, killmail_id)
    
    case :ets.lookup(@matches_table, cache_key) do
      [{^cache_key, cache_entry}] ->
        # Check if entry has expired
        if DateTime.compare(DateTime.utc_now(), cache_entry.expires_at) == :lt do
          update_cache_stats(:hit)
          {:reply, {:ok, cache_entry.match_data}, state}
        else
          # Entry expired, remove it
          :ets.delete(@matches_table, cache_key)
          update_cache_stats(:miss)
          {:reply, {:error, :not_found}, state}
        end
      
      [] ->
        update_cache_stats(:miss)
        {:reply, {:error, :not_found}, state}
    end
  end
  
  @impl GenServer
  def handle_call({:get_cached_matches, profile_id, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 100)
    
    # Pattern match for all entries with this profile_id
    pattern = {:"$1", %{profile_id: profile_id, match_data: :"$2", cached_at: :"$3"}}
    
    matches = 
      :ets.match(@matches_table, pattern)
      |> Enum.map(fn [_key, match_data, cached_at] ->
        %{match_data: match_data, cached_at: cached_at}
      end)
      |> Enum.sort_by(& &1.cached_at, {:desc, DateTime})
      |> Enum.take(limit)
    
    {:reply, {:ok, matches}, state}
  end
  
  @impl GenServer
  def handle_call({:invalidate_profile, profile_id}, _from, state) do
    # Delete all entries for this profile
    pattern = {:"$1", %{profile_id: profile_id}}
    keys_to_delete = :ets.match(@matches_table, pattern) |> Enum.map(&hd/1)
    
    Enum.each(keys_to_delete, fn key ->
      :ets.delete(@matches_table, key)
    end)
    
    Logger.debug("Invalidated cache for profile #{profile_id}, removed #{length(keys_to_delete)} entries")
    
    {:reply, :ok, state}
  end
  
  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    case :ets.lookup(@stats_table, :cache_stats) do
      [{:cache_stats, stats}] ->
        # Add current table sizes
        enhanced_stats = Map.merge(stats, %{
          total_cached_entries: :ets.info(@matches_table, :size),
          memory_usage_words: :ets.info(@matches_table, :memory)
        })
        {:reply, enhanced_stats, state}
      
      [] ->
        {:reply, %{}, state}
    end
  end
  
  @impl GenServer
  def handle_call(:clear_all, _from, state) do
    :ets.delete_all_objects(@matches_table)
    
    # Reset stats
    :ets.insert(@stats_table, {
      :cache_stats,
      %{
        total_matches: 0,
        cache_hits: 0,
        cache_misses: 0,
        profiles_cached: 0,
        last_cleanup: DateTime.utc_now()
      }
    })
    
    Logger.info("Cleared all cache data")
    {:reply, :ok, state}
  end
  
  @impl GenServer
  def handle_info(:cleanup, state) do
    perform_cleanup()
    schedule_cleanup()
    {:noreply, state}
  end
  
  # Private functions
  
  defp build_cache_key(profile_id, killmail_id) do
    "#{profile_id}:#{killmail_id}"
  end
  
  defp update_cache_stats(operation) do
    case :ets.lookup(@stats_table, :cache_stats) do
      [{:cache_stats, current_stats}] ->
        updated_stats = 
          case operation do
            :put ->
              %{current_stats | total_matches: current_stats.total_matches + 1}
            :hit ->
              %{current_stats | cache_hits: current_stats.cache_hits + 1}
            :miss ->
              %{current_stats | cache_misses: current_stats.cache_misses + 1}
          end
        
        :ets.insert(@stats_table, {:cache_stats, updated_stats})
      
      [] ->
        # Initialize stats if not present
        initial_stats = %{
          total_matches: if(operation == :put, do: 1, else: 0),
          cache_hits: if(operation == :hit, do: 1, else: 0),
          cache_misses: if(operation == :miss, do: 1, else: 0),
          profiles_cached: 0,
          last_cleanup: DateTime.utc_now()
        }
        :ets.insert(@stats_table, {:cache_stats, initial_stats})
    end
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
  
  defp perform_cleanup do
    current_time = DateTime.utc_now()
    
    # Find expired entries
    expired_keys = 
      :ets.foldl(fn {key, entry}, acc ->
        if DateTime.compare(current_time, entry.expires_at) != :lt do
          [key | acc]
        else
          acc
        end
      end, [], @matches_table)
    
    # Remove expired entries
    Enum.each(expired_keys, fn key ->
      :ets.delete(@matches_table, key)
    end)
    
    # Update cleanup timestamp
    case :ets.lookup(@stats_table, :cache_stats) do
      [{:cache_stats, stats}] ->
        updated_stats = %{stats | last_cleanup: current_time}
        :ets.insert(@stats_table, {:cache_stats, updated_stats})
      [] ->
        :ok
    end
    
    if length(expired_keys) > 0 do
      Logger.debug("Cleaned up #{length(expired_keys)} expired cache entries")
    end
  end
end