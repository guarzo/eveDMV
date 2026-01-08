defmodule EveDmv.Platform.Database.CacheInvalidator do
  @moduledoc """
  Comprehensive cache invalidation strategy for maintaining cache coherency.

  Provides pattern-based and event-driven cache invalidation to ensure
  cached data remains consistent when underlying data changes.

  ## Selective Invalidation

  This module supports selective invalidation based on actual changes to reduce
  unnecessary cache clearing. Use `invalidate_for_killmail/1` for targeted
  invalidation of only the entities involved in a killmail.

  ## Change Detection

  Use `maybe_invalidate_*` functions to check if content has actually changed
  before invalidating. This improves cache hit rates by preserving valid entries.
  """

  use GenServer

  alias EveDmv.Platform.Cache.QueryCache
  alias EveDmv.Platform.Database.CacheHashManager
  alias EveDmv.Platform.Database.CacheWarmer
  alias Phoenix.PubSub

  require Logger

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

  @impl GenServer
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

  @impl GenServer
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

  @impl GenServer
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

  @impl GenServer
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

  @impl GenServer
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

  @impl GenServer
  def handle_cast({:register_hook, module, function}, state) do
    new_hooks = [{module, function} | state.hooks]
    {:noreply, %{state | hooks: new_hooks}}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl GenServer
  def handle_info({:data_updated, entity_type, entity_id}, state) do
    # Auto-invalidation based on data changes
    if state.enabled do
      Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
        handle_data_update(entity_type, entity_id)
      end)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:killmail_processed, killmail}, state) do
    # Invalidate caches when new killmails are processed
    if state.enabled do
      Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
        handle_killmail_update(killmail)
      end)
    end

    {:noreply, state}
  end

  @impl GenServer
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

    topics
    |> Enum.each(fn topic ->
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

  # ============================================================================
  # Selective Invalidation Functions (Stream 10 improvements)
  # ============================================================================

  @doc """
  Selectively invalidate caches for entities involved in a killmail.

  Only invalidates caches for the specific characters, corporations, alliances,
  and system involved in the killmail, rather than using broad pattern-based
  invalidation. This improves cache hit rates.

  ## Example

      iex> invalidate_for_killmail(killmail)
      :ok

  """
  def invalidate_for_killmail(%{} = killmail) do
    start_time = System.monotonic_time(:microsecond)

    # Extract affected entities from victim
    victim_entities = [
      {:character, Map.get(killmail, :victim_character_id)},
      {:corporation, Map.get(killmail, :victim_corporation_id)},
      {:alliance, Map.get(killmail, :victim_alliance_id)},
      {:system, Map.get(killmail, :solar_system_id)}
    ]

    # Extract affected entities from attackers
    attacker_entities =
      case Map.get(killmail, :raw_data, %{}) do
        %{"attackers" => attackers} when is_list(attackers) ->
          Enum.flat_map(attackers, fn attacker ->
            [
              {:character, Map.get(attacker, "character_id")},
              {:corporation, Map.get(attacker, "corporation_id")},
              {:alliance, Map.get(attacker, "alliance_id")}
            ]
          end)

        _ ->
          []
      end

    # Combine, filter nil IDs, and deduplicate
    affected_entities =
      (victim_entities ++ attacker_entities)
      |> Enum.reject(fn {_, id} -> is_nil(id) end)
      |> Enum.uniq()

    # Invalidate each entity
    invalidated_count =
      Enum.reduce(affected_entities, 0, fn entity, count ->
        count + invalidate_entity(entity)
      end)

    duration_us = System.monotonic_time(:microsecond) - start_time

    # Emit telemetry
    emit_invalidation_telemetry(:selective_killmail, %{
      entities_count: length(affected_entities),
      invalidated_count: invalidated_count,
      duration_us: duration_us,
      killmail_id: Map.get(killmail, :killmail_id)
    })

    Logger.debug(
      "Selective invalidation for killmail #{Map.get(killmail, :killmail_id)}: " <>
        "#{invalidated_count} entries from #{length(affected_entities)} entities in #{duration_us}µs"
    )

    :ok
  end

  # Entity-specific invalidation that only clears time-sensitive caches
  defp invalidate_entity({:character, id}) when not is_nil(id) do
    # Only invalidate time-sensitive character caches
    # Don't invalidate historical analysis - it's expensive to recompute
    keys_invalidated =
      [
        "character_recent_activity_#{id}",
        "character_stats_#{id}",
        "character_activity_#{id}"
      ]
      |> Enum.reduce(0, fn key, count ->
        QueryCache.delete(key)
        count + 1
      end)

    keys_invalidated
  end

  defp invalidate_entity({:corporation, id}) when not is_nil(id) do
    keys_invalidated =
      [
        "corp_activity_#{id}",
        "corp_stats_#{id}",
        "corporation_activity_#{id}"
      ]
      |> Enum.reduce(0, fn key, count ->
        QueryCache.delete(key)
        count + 1
      end)

    keys_invalidated
  end

  defp invalidate_entity({:alliance, id}) when not is_nil(id) do
    keys_invalidated =
      [
        "alliance_activity_#{id}",
        "alliance_stats_#{id}"
      ]
      |> Enum.reduce(0, fn key, count ->
        QueryCache.delete(key)
        count + 1
      end)

    keys_invalidated
  end

  defp invalidate_entity({:system, id}) when not is_nil(id) do
    # System info doesn't change from killmails, only activity does
    keys_invalidated =
      [
        "system_activity_#{id}",
        "system_recent_kills_#{id}"
      ]
      |> Enum.reduce(0, fn key, count ->
        QueryCache.delete(key)
        count + 1
      end)

    keys_invalidated
  end

  defp invalidate_entity(_), do: 0

  # ============================================================================
  # Change Detection Functions (Stream 10 improvements)
  # ============================================================================

  @doc """
  Conditionally invalidate a character cache only if content has changed.

  Uses CacheHashManager to detect actual changes before invalidating.
  Returns `:invalidated` if cache was invalidated, `:unchanged` if preserved.

  ## Example

      iex> maybe_invalidate_character(12345, %{kills: 100, losses: 50})
      :unchanged

  """
  def maybe_invalidate_character(character_id, new_data) when is_integer(character_id) do
    cache_key = "character_analysis_#{character_id}"
    do_maybe_invalidate(cache_key, new_data, :character, character_id)
  end

  @doc """
  Conditionally invalidate a corporation cache only if content has changed.
  """
  def maybe_invalidate_corporation(corporation_id, new_data) when is_integer(corporation_id) do
    cache_key = "corp_analysis_#{corporation_id}"
    do_maybe_invalidate(cache_key, new_data, :corporation, corporation_id)
  end

  @doc """
  Conditionally invalidate an alliance cache only if content has changed.
  """
  def maybe_invalidate_alliance(alliance_id, new_data) when is_integer(alliance_id) do
    cache_key = "alliance_analysis_#{alliance_id}"
    do_maybe_invalidate(cache_key, new_data, :alliance, alliance_id)
  end

  @doc """
  Conditionally invalidate a system cache only if content has changed.
  """
  def maybe_invalidate_system(system_id, new_data) when is_integer(system_id) do
    cache_key = "system_analysis_#{system_id}"
    do_maybe_invalidate(cache_key, new_data, :system, system_id)
  end

  defp do_maybe_invalidate(cache_key, new_data, entity_type, entity_id) do
    start_time = System.monotonic_time(:microsecond)

    result =
      if CacheHashManager.content_changed?(cache_key, new_data) do
        QueryCache.delete(cache_key)
        CacheHashManager.store_hash(cache_key, new_data)
        :invalidated
      else
        :unchanged
      end

    duration_us = System.monotonic_time(:microsecond) - start_time

    # Emit telemetry for monitoring
    emit_invalidation_telemetry(:conditional, %{
      entity_type: entity_type,
      entity_id: entity_id,
      result: result,
      duration_us: duration_us
    })

    result
  end

  # ============================================================================
  # Telemetry Functions (Stream 10 improvements)
  # ============================================================================

  defp emit_invalidation_telemetry(type, metadata) do
    :telemetry.execute(
      [:eve_dmv, :cache, :invalidation],
      %{count: 1, duration_us: Map.get(metadata, :duration_us, 0)},
      Map.put(metadata, :type, type)
    )
  end
end
