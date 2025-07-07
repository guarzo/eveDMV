defmodule EveDmv.Database.CacheInvalidator do
  use GenServer

  alias EveDmv.Database.CacheWarmer
  alias EveDmv.Database.QueryCache
  alias Phoenix.PubSub

  require Logger
  @moduledoc """
  Comprehensive cache invalidation strategy for maintaining cache coherency.

  Provides pattern-based and event-driven cache invalidation to ensure
  cached data remains consistent when underlying data changes.
  """



  @pubsub_topic "cache_invalidation"
  @invalidation_patterns %{
    # Character-related invalidations
    character: [
      "character_intel_*",
      "character_stats_*",
      "character_analysis_*"
    ],
    # Killmail-related invalidations
    killmail: [
      "killmail_enriched_*",
      "killmail_participants_*",
      "recent_killmails_*",
      "system_activity_*"
    ],
    # Alliance/Corporation invalidations
    alliance: [
      "alliance_stats_*",
      "alliance_members_*",
      "corp_*"
    ],
    # System/location invalidations
    system: [
      "system_info_*",
      "system_activity_*",
      "jump_data_*"
    ],
    # Item/market invalidations
    item: [
      "item_type_*",
      "item_price_*",
      "market_*"
    ],
    # Intelligence invalidations
    intelligence: [
      "wh_vetting_*",
      "threat_assessment_*",
      "chain_analysis_*"
    ]
  }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def invalidate_by_pattern(pattern) when is_binary(pattern) do
    GenServer.cast(__MODULE__, {:invalidate_pattern, pattern})
  end

  def invalidate_by_type(cache_type, entity_id) do
    GenServer.cast(__MODULE__, {:invalidate_type, cache_type, entity_id})
  end

  def invalidate_related(entity_type, entity_id, related_types \\ []) do
    GenServer.cast(__MODULE__, {:invalidate_related, entity_type, entity_id, related_types})
  end

  def bulk_invalidate(patterns) when is_list(patterns) do
    GenServer.cast(__MODULE__, {:bulk_invalidate, patterns})
  end

  def get_invalidation_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  def subscribe_to_invalidations do
    PubSub.subscribe(EveDmv.PubSub, @pubsub_topic)
  end

  def register_invalidation_hook(module, function) do
    GenServer.cast(__MODULE__, {:register_hook, module, function})
  end

  # Server callbacks

  def init(opts) do
    state = %{
      enabled: Keyword.get(opts, :enabled, true),
      hooks: [],
      stats: %{
        total_invalidations: 0,
        patterns_invalidated: 0,
        last_invalidation: nil,
        invalidations_by_type: %{}
      }
    }

    # Subscribe to relevant PubSub topics for automatic invalidation
    if state.enabled do
      setup_subscriptions()
    end

    {:ok, state}
  end

  def handle_cast({:invalidate_pattern, pattern}, state) do
    if state.enabled do
      Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
        perform_pattern_invalidation(pattern)
      end)

      new_state = update_stats(state, :pattern, pattern)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:invalidate_type, cache_type, entity_id}, state) do
    if state.enabled do
      Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
        perform_type_invalidation(cache_type, entity_id, state.hooks)
      end)

      new_state = update_stats(state, :type, {cache_type, entity_id})
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:invalidate_related, entity_type, entity_id, related_types}, state) do
    if state.enabled do
      Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
        perform_related_invalidation(entity_type, entity_id, related_types)
      end)

      new_state = update_stats(state, :related, {entity_type, entity_id})
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:bulk_invalidate, patterns}, state) do
    if state.enabled do
      Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
        perform_bulk_invalidation(patterns)
      end)

      new_state = update_stats(state, :bulk, length(patterns))
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:register_hook, module, function}, state) do
    new_hooks = [{module, function} | state.hooks]
    {:noreply, %{state | hooks: new_hooks}}
  end

  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  def handle_info({:data_updated, entity_type, entity_id}, state) do
    # Auto-invalidation based on data changes
    if state.enabled do
      Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
        handle_data_update(entity_type, entity_id)
      end)
    end

    {:noreply, state}
  end

  def handle_info({:killmail_processed, killmail}, state) do
    # Invalidate caches when new killmails are processed
    if state.enabled do
      Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
        handle_killmail_update(killmail)
      end)
    end

    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  # Private functions

  defp setup_subscriptions do
    topics = [
      "killmail:processed",
      "character:updated",
      "alliance:updated",
      "corporation:updated",
      "system:updated"
    ]

    Enum.each(topics, fn topic ->
      PubSub.subscribe(EveDmv.PubSub, topic)
    end)
  end

  defp perform_pattern_invalidation(pattern) do
    Logger.debug("Invalidating cache pattern: #{pattern}")

    start_time = System.monotonic_time(:millisecond)
    count = QueryCache.invalidate_pattern(pattern)
    duration_ms = System.monotonic_time(:millisecond) - start_time

    Logger.info("Invalidated #{count} cache entries matching '#{pattern}' in #{duration_ms}ms")

    # Broadcast invalidation event
    PubSub.broadcast(EveDmv.PubSub, @pubsub_topic, {:cache_invalidated, pattern, count})

    count
  end

  defp perform_type_invalidation(cache_type, entity_id, hooks \\ []) do
    patterns = Map.get(@invalidation_patterns, cache_type, [])

    # Replace wildcards with specific entity ID
    specific_patterns =
      Enum.map(patterns, fn pattern ->
        String.replace(pattern, "*", to_string(entity_id))
      end)

    Logger.debug("Invalidating cache for #{cache_type}:#{entity_id}")

    total_count =
      Enum.reduce(specific_patterns, 0, fn pattern, acc ->
        count = QueryCache.invalidate_pattern(pattern)
        acc + count
      end)

    Logger.info("Invalidated #{total_count} cache entries for #{cache_type}:#{entity_id}")

    # Execute registered hooks
    execute_hooks(hooks, cache_type, entity_id)

    total_count
  end

  defp perform_related_invalidation(entity_type, entity_id, related_types) do
    # Invalidate the primary entity
    perform_type_invalidation(entity_type, entity_id)

    # Invalidate related entities
    Enum.each(related_types, fn {related_type, related_ids} ->
      if is_list(related_ids) do
        Enum.each(related_ids, fn related_id ->
          perform_type_invalidation(related_type, related_id)
        end)
      else
        perform_type_invalidation(related_type, related_ids)
      end
    end)
  end

  defp perform_bulk_invalidation(patterns) do
    Logger.info("Performing bulk cache invalidation for #{length(patterns)} patterns")

    start_time = System.monotonic_time(:millisecond)

    total_count =
      Enum.reduce(patterns, 0, fn pattern, acc ->
        count = QueryCache.invalidate_pattern(pattern)
        acc + count
      end)

    duration_ms = System.monotonic_time(:millisecond) - start_time

    Logger.info("Bulk invalidation complete: #{total_count} entries in #{duration_ms}ms")

    total_count
  end

  defp handle_data_update(entity_type, entity_id) do
    Logger.debug("Handling data update for #{entity_type}:#{entity_id}")

    case entity_type do
      :character ->
        # Invalidate character intelligence and stats
        perform_type_invalidation(:character, entity_id)

      :killmail ->
        # Invalidate killmail and related system activity
        perform_related_invalidation(:killmail, entity_id, [
          {:system, get_killmail_system_id(entity_id)}
        ])

      :alliance ->
        # Invalidate alliance stats and member data
        perform_type_invalidation(:alliance, entity_id)

      _ ->
        # Generic invalidation
        perform_type_invalidation(entity_type, entity_id)
    end
  end

  defp handle_killmail_update(killmail) do
    # Extract relevant IDs from killmail
    character_ids = extract_character_ids(killmail)
    alliance_ids = extract_alliance_ids(killmail)
    _corp_ids = extract_corp_ids(killmail)
    system_id = killmail.solar_system_id

    # Invalidate all related caches
    related_invalidations = [
      {:system, system_id},
      {:character, character_ids},
      {:alliance, alliance_ids}
    ]

    perform_related_invalidation(:killmail, killmail.killmail_id, related_invalidations)

    # Invalidate aggregate caches
    invalidate_aggregate_caches(system_id)
  end

  defp extract_character_ids(killmail) do
    participants = killmail.participants || []
    participants |> Stream.map(& &1.character_id) |> Stream.reject(&is_nil/1) |> Enum.to_list()
  end

  defp extract_alliance_ids(killmail) do
    participants = killmail.participants || []
    participants |> Stream.map(& &1.alliance_id) |> Stream.reject(&is_nil/1) |> Enum.uniq()
  end

  defp extract_corp_ids(killmail) do
    participants = killmail.participants || []
    participants |> Stream.map(& &1.corporation_id) |> Stream.reject(&is_nil/1) |> Enum.uniq()
  end

  defp get_killmail_system_id(_killmail_id) do
    # This would typically query the database, but for now return nil
    # In real implementation, we'd look up the killmail's system
    nil
  end

  defp invalidate_aggregate_caches(system_id) do
    # Invalidate system-wide aggregate caches
    patterns = [
      "system_activity_#{system_id}",
      "recent_killmails_#{system_id}",
      "system_stats_#{system_id}",
      "hot_systems_*",
      "activity_summary_*"
    ]

    Enum.each(patterns, &perform_pattern_invalidation/1)
  end

  defp execute_hooks(hooks, cache_type, entity_id) do
    # Execute registered invalidation hooks
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      Enum.each(hooks, fn {module, function} ->
        try do
          apply(module, function, [cache_type, entity_id])
        rescue
          error ->
            Logger.warning("Cache invalidation hook failed: #{inspect(error)}")
        end
      end)
    end)
  end

  defp update_stats(state, invalidation_type, _data) do
    new_stats = %{
      state.stats
      | total_invalidations: state.stats.total_invalidations + 1,
        last_invalidation: DateTime.utc_now(),
        invalidations_by_type:
          Map.update(
            state.stats.invalidations_by_type,
            invalidation_type,
            1,
            &(&1 + 1)
          )
    }

    %{state | stats: new_stats}
  end

  # Public utilities for manual cache management

  def invalidate_character_intelligence(character_id) do
    invalidate_by_type(:character, character_id)
  end

  def invalidate_system_activity(system_id) do
    invalidate_by_type(:system, system_id)
  end

  def invalidate_alliance_data(alliance_id) do
    invalidate_by_type(:alliance, alliance_id)
  end

  def clear_all_caches do
    Logger.warning("Clearing all caches - this may impact performance")
    bulk_invalidate(["*"])
  end

  def warm_after_invalidation(cache_type, entity_id) do
    # Trigger cache warming after invalidation
    CacheWarmer.warm_specific(to_string(cache_type), [entity_id])
  end
end
