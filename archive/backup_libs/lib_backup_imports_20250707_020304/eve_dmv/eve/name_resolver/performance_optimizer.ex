defmodule EveDmv.Eve.NameResolver.PerformanceOptimizer do
    alias EveDmv.Eve.NameResolver.StaticDataResolver
  alias EveDmv.Eve.NameResolver.EsiEntityResolver

  require Logger
  @moduledoc """
  Performance optimization module for EVE name resolution.

  Handles cache warming, preloading, and performance tuning to optimize
  name resolution performance for common use cases and high-traffic scenarios.
  """


  # Configurable timeout settings
  @task_timeout Application.compile_env(:eve_dmv, :name_resolver_task_timeout, 30_000)

  @doc """
  Preloads names for killmail participants to improve UI performance.

  Takes a list of killmails and preloads all character, corporation,
  and alliance names found in the participants.
  """
  def preload_killmail_names(killmails) when is_list(killmails) do
    Logger.debug("Preloading names for #{length(killmails)} killmails")

    # Extract all unique IDs from killmails
    {character_ids, corp_ids, alliance_ids} =
      Enum.reduce(killmails, {[], [], []}, fn km, {chars, corps, alliances} ->
        new_chars =
          [
            km.victim_character_id,
            km.final_blow_character_id
          ]
          |> Enum.reject(&is_nil/1)

        new_corps = [km.victim_corporation_id] |> Enum.reject(&is_nil/1)
        new_alliances = [km.victim_alliance_id] |> Enum.reject(&is_nil/1)

        {chars ++ new_chars, corps ++ new_corps, alliances ++ new_alliances}
      end)

    # Batch resolve all names in parallel
    tasks = [
      Task.async(fn -> EsiEntityResolver.character_names(Enum.uniq(character_ids)) end),
      Task.async(fn -> EsiEntityResolver.corporation_names(Enum.uniq(corp_ids)) end),
      Task.async(fn -> EsiEntityResolver.alliance_names(Enum.uniq(alliance_ids)) end)
    ]

    # Wait for all tasks to complete
    Enum.each(tasks, &Task.await(&1, @task_timeout))

    Logger.debug("Name preloading complete")
    :ok
  end

  @doc """
  Warms the cache with commonly used items.
  Should be called after static data is loaded.
  """
  def warm_cache do
    Logger.info("Warming EVE name resolver cache")

    cache_config = Application.get_env(:eve_dmv, :name_resolver_cache_warming, [])

    # Pre-load common ship types
    common_ships = Keyword.get(cache_config, :common_ships, [])

    unless Enum.empty?(common_ships) do
      StaticDataResolver.ship_names(common_ships)
    end

    # Pre-load major trade hubs
    trade_hubs = Keyword.get(cache_config, :trade_hubs, [])

    unless Enum.empty?(trade_hubs) do
      StaticDataResolver.system_names(trade_hubs)
    end

    # Pre-load well-known NPCs and corporations
    npc_corps = Keyword.get(cache_config, :npc_corporations, [])

    unless Enum.empty?(npc_corps) do
      EsiEntityResolver.corporation_names(npc_corps)
    end

    Logger.info("Cache warming complete")
    :ok
  end

  @doc """
  Preloads fleet participant names for improved fleet UI performance.
  """
  def preload_fleet_names(fleet_members) when is_list(fleet_members) do
    Logger.debug("Preloading names for #{length(fleet_members)} fleet members")

    # Extract character and corporation IDs
    {character_ids, corp_ids} =
      Enum.reduce(fleet_members, {[], []}, fn member, {chars, corps} ->
        char_ids = [member.character_id | chars]
        corp_ids = [member.corporation_id | corps]
        {char_ids, corp_ids}
      end)

    # Preload in parallel
    tasks = [
      Task.async(fn -> EsiEntityResolver.character_names(Enum.uniq(character_ids)) end),
      Task.async(fn -> EsiEntityResolver.corporation_names(Enum.uniq(corp_ids)) end)
    ]

    Enum.each(tasks, &Task.await(&1, @task_timeout))

    Logger.debug("Fleet name preloading complete")
    :ok
  end

  @doc """
  Preloads ship and item names commonly used in loadouts.
  """
  def preload_fitting_names(fittings) when is_list(fittings) do
    Logger.debug("Preloading names for #{length(fittings)} fittings")

    # Extract ship and module type IDs
    type_ids =
      Enum.flat_map(fittings, fn fitting ->
        ship_ids = [fitting.ship_type_id]
        module_ids = Enum.map(fitting.modules || [], & &1.type_id)
        ship_ids ++ module_ids
      end)
      |> Enum.uniq()

    # Preload item names
    StaticDataResolver.item_names(type_ids)

    Logger.debug("Fitting name preloading complete")
    :ok
  end

  @doc """
  Preloads names for market data display.
  """
  def preload_market_names(market_orders) when is_list(market_orders) do
    Logger.debug("Preloading names for #{length(market_orders)} market orders")

    # Extract type IDs and system IDs
    {type_ids, system_ids} =
      Enum.reduce(market_orders, {[], []}, fn order, {types, systems} ->
        type_list = [order.type_id | types]
        system_list = [order.system_id | systems]
        {type_list, system_list}
      end)

    # Preload in parallel
    tasks = [
      Task.async(fn -> StaticDataResolver.item_names(Enum.uniq(type_ids)) end),
      Task.async(fn -> StaticDataResolver.system_names(Enum.uniq(system_ids)) end)
    ]

    Enum.each(tasks, &Task.await(&1, @task_timeout))

    Logger.debug("Market name preloading complete")
    :ok
  end

  @doc """
  Performs intelligent cache warming based on usage patterns.
  """
  def intelligent_cache_warming(usage_stats \\ %{}) do
    Logger.info("Starting intelligent cache warming")

    # Warm most accessed ship types
    if top_ships = Map.get(usage_stats, :top_ships) do
      StaticDataResolver.ship_names(top_ships)
    end

    # Warm most accessed systems
    if top_systems = Map.get(usage_stats, :top_systems) do
      StaticDataResolver.system_names(top_systems)
    end

    # Warm active corporation and alliance names
    if active_entities = Map.get(usage_stats, :active_entities) do
      character_ids = Map.get(active_entities, :characters, [])
      corp_ids = Map.get(active_entities, :corporations, [])
      alliance_ids = Map.get(active_entities, :alliances, [])

      tasks = [
        Task.async(fn -> EsiEntityResolver.character_names(character_ids) end),
        Task.async(fn -> EsiEntityResolver.corporation_names(corp_ids) end),
        Task.async(fn -> EsiEntityResolver.alliance_names(alliance_ids) end)
      ]

      Enum.each(tasks, &Task.await(&1, @task_timeout))
    end

    Logger.info("Intelligent cache warming complete")
    :ok
  end

  @doc """
  Optimizes cache warming for specific game activities.
  """
  def warm_cache_for_activity(activity_type) do
    case activity_type do
      :pvp ->
        warm_pvp_cache()

      :industry ->
        warm_industry_cache()

      :exploration ->
        warm_exploration_cache()

      :trading ->
        warm_trading_cache()

      _ ->
        Logger.warning("Unknown activity type for cache warming: #{activity_type}")
        :ok
    end
  end

  @doc """
  Monitors cache performance and suggests optimizations.
  """
  def analyze_cache_performance do
    # This would analyze cache hit rates, most requested items, etc.
    # For now, return basic structure
    %{
      cache_hit_rate: calculate_cache_hit_rate(),
      most_requested_items: get_most_requested_items(),
      cache_size: get_cache_size(),
      recommendations: generate_cache_recommendations()
    }
  end

  # Private helper functions for activity-specific warming

  defp warm_pvp_cache do
    Logger.debug("Warming cache for PvP activity")

    # Common PvP ships and modules
    pvp_ships = [
      # Rifter
      587,
      # Punisher
      588,
      # Tormentor
      589,
      # Breacher
      590
      # Add more common PvP ships
    ]

    StaticDataResolver.ship_names(pvp_ships)
    :ok
  end

  defp warm_industry_cache do
    Logger.debug("Warming cache for Industry activity")

    # Common industrial systems and ships
    industry_systems = [
      # Jita
      30_000_142,
      # Amarr
      30_002_187,
      # Dodixie
      30_002_659,
      # Rens
      30_002_510
      # Add more industrial hubs
    ]

    StaticDataResolver.system_names(industry_systems)
    :ok
  end

  defp warm_exploration_cache do
    Logger.debug("Warming cache for Exploration activity")

    # Common exploration ships and systems
    exploration_ships = [
      # Magnate
      605,
      # Imicus
      606,
      # Heron
      607,
      # Probe
      608
    ]

    StaticDataResolver.ship_names(exploration_ships)
    :ok
  end

  defp warm_trading_cache do
    Logger.debug("Warming cache for Trading activity")

    # Major trade hubs
    trade_hubs = [
      # Jita
      30_000_142,
      # Amarr
      30_002_187,
      # Dodixie
      30_002_659,
      # Rens
      30_002_510,
      # Hek
      30_002_053
    ]

    StaticDataResolver.system_names(trade_hubs)
    :ok
  end

  # Performance monitoring helpers

  defp calculate_cache_hit_rate do
    # Would calculate actual hit rate from cache statistics
    # Placeholder
    0.85
  end

  defp get_most_requested_items do
    # Would return actual statistics
    # Placeholder
    []
  end

  defp get_cache_size do
    # Would return actual cache size
    # Placeholder
    0
  end

  defp generate_cache_recommendations do
    # Would generate actual recommendations based on usage patterns
    # Placeholder
    []
  end
end
