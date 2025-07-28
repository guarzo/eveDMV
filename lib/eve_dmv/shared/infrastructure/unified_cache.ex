defmodule EveDmv.Shared.Infrastructure.UnifiedCache do
  @moduledoc """
  Unified cache system replacing multiple context-specific cache implementations.

  Consolidates cache functionality from:
  - MarketIntelligence.Infrastructure.PriceCache
  - ThreatAssessment.Infrastructure.ThreatCache
  - CombatIntelligence.Infrastructure.AnalysisCache
  - Surveillance.Infrastructure.MatchCache
  - CorporationAnalysis.Infrastructure.AnalysisCache

  Provides:
  - Unified ETS-based caching with configurable TTL
  - Domain-specific cache partitioning
  - Automatic cleanup and expiration
  - Performance monitoring and statistics
  - Cache warming and invalidation
  """

  use GenServer
  require Logger

  @cache_table :unified_cache
  @stats_table :cache_stats
  # 5 minutes
  @default_ttl 300
  # 1 minute
  @cleanup_interval 60_000
  @max_cache_size 50_000

  # Domain cache prefixes for partitioning
  @domain_prefixes %{
    market: "market",
    threat: "threat",
    combat: "combat",
    surveillance: "surveillance",
    corporation: "corp",
    intelligence: "intel",
    analysis: "analysis",
    player: "player",
    fleet: "fleet",
    wormhole: "wormhole"
  }

  @type domain ::
          :market
          | :threat
          | :combat
          | :surveillance
          | :corporation
          | :intelligence
          | :analysis
          | :player
          | :fleet
          | :wormhole
  @type cache_key :: term()
  @type cache_value :: term()
  @type ttl :: non_neg_integer()

  ## Public API

  @doc """
  Start the unified cache GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get cached value by domain and key.
  """
  @spec get(domain(), cache_key()) :: {:ok, cache_value()} | {:error, :not_found}
  def get(domain, key)
      when domain in [
             :market,
             :threat,
             :combat,
             :surveillance,
             :corporation,
             :intelligence,
             :analysis,
             :player,
             :fleet,
             :wormhole
           ] do
    cache_key = build_cache_key(domain, key)

    case :ets.lookup(@cache_table, cache_key) do
      [{^cache_key, value, expires_at}] ->
        if System.system_time(:second) < expires_at do
          update_access_stats(domain, :hit)
          {:ok, value}
        else
          # Expired entry
          :ets.delete(@cache_table, cache_key)
          update_access_stats(domain, :miss)
          {:error, :not_found}
        end

      [] ->
        update_access_stats(domain, :miss)
        {:error, :not_found}
    end
  end

  @doc """
  Put value in cache with optional TTL.
  """
  @spec put(domain(), cache_key(), cache_value(), ttl()) :: :ok
  def put(domain, key, value, ttl \\ @default_ttl) do
    cache_key = build_cache_key(domain, key)
    expires_at = System.system_time(:second) + ttl

    # Check cache size before insertion
    current_size = :ets.info(@cache_table, :size)

    if current_size >= @max_cache_size do
      cleanup_expired_entries()
    end

    :ets.insert(@cache_table, {cache_key, value, expires_at})
    update_write_stats(domain)
    :ok
  end

  @doc """
  Delete value from cache.
  """
  @spec delete(domain(), cache_key()) :: :ok
  def delete(domain, key) do
    cache_key = build_cache_key(domain, key)
    :ets.delete(@cache_table, cache_key)
    :ok
  end

  @doc """
  Invalidate all entries for a domain.
  """
  @spec invalidate_domain(domain()) :: :ok
  def invalidate_domain(domain) do
    prefix = Map.get(@domain_prefixes, domain, "unknown")
    match_pattern = {:"$1", :"$2", :"$3"}
    guard = {:==, {:hd, {:binary_part, :"$1", 0, byte_size(prefix)}}, prefix}

    keys_to_delete = :ets.select(@cache_table, [{match_pattern, [guard], [:"$1"]}])

    Enum.each(keys_to_delete, &:ets.delete(@cache_table, &1))
    Logger.debug("Invalidated #{length(keys_to_delete)} entries for domain #{domain}")
    :ok
  end

  @doc """
  Get cache statistics.
  """
  @spec get_stats() :: map()
  def get_stats() do
    total_entries = :ets.info(@cache_table, :size)

    domain_stats =
      Enum.map(@domain_prefixes, fn {domain, _prefix} ->
        stats = get_domain_stats(domain)
        {domain, stats}
      end)
      |> Map.new()

    %{
      total_entries: total_entries,
      max_cache_size: @max_cache_size,
      domain_stats: domain_stats,
      memory_usage: :ets.info(@cache_table, :memory),
      last_cleanup: get_last_cleanup_time()
    }
  end

  @doc """
  Get statistics for a specific domain.
  """
  @spec get_domain_stats(domain()) :: map()
  def get_domain_stats(domain) do
    case :ets.lookup(@stats_table, domain) do
      [{^domain, hits, misses, writes, last_access}] ->
        total_requests = hits + misses
        hit_rate = if total_requests > 0, do: hits / total_requests, else: 0.0

        %{
          hits: hits,
          misses: misses,
          writes: writes,
          total_requests: total_requests,
          hit_rate: Float.round(hit_rate, 3),
          last_access: last_access
        }

      [] ->
        %{
          hits: 0,
          misses: 0,
          writes: 0,
          total_requests: 0,
          hit_rate: 0.0,
          last_access: nil
        }
    end
  end

  @doc """
  Manually trigger cache cleanup.
  """
  @spec cleanup() :: :ok
  def cleanup() do
    GenServer.cast(__MODULE__, :cleanup)
  end

  @doc """
  Warm cache with provided data.
  """
  @spec warm_cache(domain(), [{cache_key(), cache_value()}], ttl()) :: :ok
  def warm_cache(domain, key_value_pairs, ttl \\ @default_ttl) do
    Enum.each(key_value_pairs, fn {key, value} ->
      put(domain, key, value, ttl)
    end)

    Logger.info("Warmed cache for domain #{domain} with #{length(key_value_pairs)} entries")
    :ok
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(_opts) do
    # Create ETS tables
    :ets.new(@cache_table, [:set, :public, :named_table, {:read_concurrency, true}])
    :ets.new(@stats_table, [:set, :public, :named_table, {:read_concurrency, true}])

    # Initialize domain stats
    Enum.each(Map.keys(@domain_prefixes), fn domain ->
      :ets.insert(@stats_table, {domain, 0, 0, 0, nil})
    end)

    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup, @cleanup_interval)

    Logger.info("Unified cache started with max size #{@max_cache_size}")
    {:ok, %{last_cleanup: System.system_time(:second)}}
  end

  @impl GenServer
  def handle_info(:cleanup, state) do
    cleanup_expired_entries()

    # Schedule next cleanup
    Process.send_after(self(), :cleanup, @cleanup_interval)

    {:noreply, %{state | last_cleanup: System.system_time(:second)}}
  end

  @impl GenServer
  def handle_cast(:cleanup, state) do
    cleanup_expired_entries()
    {:noreply, %{state | last_cleanup: System.system_time(:second)}}
  end

  ## Private Functions

  defp build_cache_key(domain, key) do
    prefix = Map.get(@domain_prefixes, domain, "unknown")
    "#{prefix}:#{:erlang.phash2(key)}"
  end

  defp update_access_stats(domain, type) do
    current_time = System.system_time(:second)

    case :ets.lookup(@stats_table, domain) do
      [{^domain, hits, misses, writes, _last_access}] ->
        new_stats =
          case type do
            :hit -> {domain, hits + 1, misses, writes, current_time}
            :miss -> {domain, hits, misses + 1, writes, current_time}
          end

        :ets.insert(@stats_table, new_stats)

      [] ->
        initial_stats =
          case type do
            :hit -> {domain, 1, 0, 0, current_time}
            :miss -> {domain, 0, 1, 0, current_time}
          end

        :ets.insert(@stats_table, initial_stats)
    end
  end

  defp update_write_stats(domain) do
    current_time = System.system_time(:second)

    case :ets.lookup(@stats_table, domain) do
      [{^domain, hits, misses, writes, _last_access}] ->
        :ets.insert(@stats_table, {domain, hits, misses, writes + 1, current_time})

      [] ->
        :ets.insert(@stats_table, {domain, 0, 0, 1, current_time})
    end
  end

  defp cleanup_expired_entries() do
    current_time = System.system_time(:second)

    # Find expired entries
    match_pattern = {:"$1", :"$2", :"$3"}
    guard = {:<, :"$3", current_time}
    expired_keys = :ets.select(@cache_table, [{match_pattern, [guard], [:"$1"]}])

    # Delete expired entries
    Enum.each(expired_keys, &:ets.delete(@cache_table, &1))

    if not Enum.empty?(expired_keys) do
      Logger.debug("Cleaned up #{length(expired_keys)} expired cache entries")
    end

    expired_keys
  end

  defp get_last_cleanup_time() do
    case GenServer.call(__MODULE__, :get_last_cleanup, 1000) do
      {:ok, time} -> time
      _ -> nil
    end
  rescue
    _ -> nil
  end

  @impl GenServer
  def handle_call(:get_last_cleanup, _from, state) do
    {:reply, {:ok, state.last_cleanup}, state}
  end

  ## Domain-Specific Helper Functions

  @doc """
  Cache market price data.
  """
  @spec cache_price(integer(), map(), ttl()) :: :ok
  # 15 minutes default
  def cache_price(type_id, price_data, ttl \\ 900) do
    put(:market, {:price, type_id}, price_data, ttl)
  end

  @doc """
  Get cached market price.
  """
  @spec get_price(integer()) :: {:ok, map()} | {:error, :not_found}
  def get_price(type_id) do
    get(:market, {:price, type_id})
  end

  @doc """
  Cache threat assessment data.
  """
  @spec cache_threat_assessment(integer(), map(), ttl()) :: :ok
  def cache_threat_assessment(character_id, assessment, ttl \\ @default_ttl) do
    put(:threat, {:assessment, character_id}, assessment, ttl)
  end

  @doc """
  Get cached threat assessment.
  """
  @spec get_threat_assessment(integer()) :: {:ok, map()} | {:error, :not_found}
  def get_threat_assessment(character_id) do
    get(:threat, {:assessment, character_id})
  end

  @doc """
  Cache combat analysis results.
  """
  @spec cache_combat_analysis(term(), map(), ttl()) :: :ok
  def cache_combat_analysis(analysis_key, results, ttl \\ @default_ttl) do
    put(:combat, {:analysis, analysis_key}, results, ttl)
  end

  @doc """
  Get cached combat analysis.
  """
  @spec get_combat_analysis(term()) :: {:ok, map()} | {:error, :not_found}
  def get_combat_analysis(analysis_key) do
    get(:combat, {:analysis, analysis_key})
  end

  @doc """
  Cache surveillance profile matching results.
  """
  @spec cache_surveillance_match(integer(), list(), ttl()) :: :ok
  # 3 minutes default
  def cache_surveillance_match(killmail_id, matches, ttl \\ 180) do
    put(:surveillance, {:matches, killmail_id}, matches, ttl)
  end

  @doc """
  Get cached surveillance matches.
  """
  @spec get_surveillance_matches(integer()) :: {:ok, list()} | {:error, :not_found}
  def get_surveillance_matches(killmail_id) do
    get(:surveillance, {:matches, killmail_id})
  end

  @doc """
  Cache corporation analysis results.
  """
  @spec cache_corp_analysis(integer(), map(), ttl()) :: :ok
  # 10 minutes default
  def cache_corp_analysis(corp_id, analysis, ttl \\ 600) do
    put(:corporation, {:analysis, corp_id}, analysis, ttl)
  end

  @doc """
  Get cached corporation analysis.
  """
  @spec get_corp_analysis(integer()) :: {:ok, map()} | {:error, :not_found}
  def get_corp_analysis(corp_id) do
    get(:corporation, {:analysis, corp_id})
  end

  @doc """
  Cache player profile data.
  """
  @spec cache_player_profile(integer(), map(), ttl()) :: :ok
  # 30 minutes default
  def cache_player_profile(character_id, profile, ttl \\ 1800) do
    put(:player, {:profile, character_id}, profile, ttl)
  end

  @doc """
  Get cached player profile.
  """
  @spec get_player_profile(integer()) :: {:ok, map()} | {:error, :not_found}
  def get_player_profile(character_id) do
    get(:player, {:profile, character_id})
  end

  @doc """
  Cache fleet analysis results.
  """
  @spec cache_fleet_analysis(term(), map(), ttl()) :: :ok
  def cache_fleet_analysis(fleet_key, analysis, ttl \\ @default_ttl) do
    put(:fleet, {:analysis, fleet_key}, analysis, ttl)
  end

  @doc """
  Get cached fleet analysis.
  """
  @spec get_fleet_analysis(term()) :: {:ok, map()} | {:error, :not_found}
  def get_fleet_analysis(fleet_key) do
    get(:fleet, {:analysis, fleet_key})
  end

  @doc """
  Cache wormhole intelligence data.
  """
  @spec cache_wormhole_intel(integer(), map(), ttl()) :: :ok
  # 10 minutes default
  def cache_wormhole_intel(system_id, intel, ttl \\ 600) do
    put(:wormhole, {:intel, system_id}, intel, ttl)
  end

  @doc """
  Get cached wormhole intelligence.
  """
  @spec get_wormhole_intel(integer()) :: {:ok, map()} | {:error, :not_found}
  def get_wormhole_intel(system_id) do
    get(:wormhole, {:intel, system_id})
  end

  @doc """
  Get cache hit rate for a domain.
  """
  @spec get_hit_rate(domain()) :: float()
  def get_hit_rate(domain) do
    stats = get_domain_stats(domain)
    stats.hit_rate
  end
end
