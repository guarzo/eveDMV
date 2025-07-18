defmodule EveDmv.Intelligence.RealTimeCoordinator do
  @moduledoc """
  Coordinates real-time intelligence updates and event publishing.

  This module acts as the central orchestrator for intelligence events,
  processing incoming data and determining what events should be published
  for real-time UI updates.

  Key responsibilities:
  - Monitor threat level changes and publish alerts
  - Detect significant intelligence updates
  - Coordinate between different intelligence subsystems
  - Filter and prioritize events for publishing
  - Manage real-time subscriptions and client updates
  """

  use GenServer
  require Logger

  alias EveDmv.Intelligence.EventPublisher
  alias EveDmv.Infrastructure.EventBus
  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.ThreatScoringCoordinator

  # Update thresholds for determining when to publish events
  # 15% change triggers event
  @threat_level_change_threshold 0.15
  # 3x normal activity triggers event
  @activity_spike_threshold 3.0
  # 5+ participants triggers battle event
  @battle_participant_threshold 5
  # Check for updates every 30 seconds
  @intelligence_update_interval 30_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Process a new killmail for real-time intelligence updates.

  This is called by the killmail pipeline to trigger intelligence analysis.
  """
  def process_killmail(killmail) do
    GenServer.cast(__MODULE__, {:process_killmail, killmail})
  end

  @doc """
  Update character threat assessment and check for significant changes.
  """
  def update_character_threat(character_id, new_assessment, previous_assessment \\ nil) do
    GenServer.cast(
      __MODULE__,
      {:update_character_threat, character_id, new_assessment, previous_assessment}
    )
  end

  @doc """
  Process system activity update for spike detection.
  """
  def update_system_activity(system_id, activity_data) do
    GenServer.cast(__MODULE__, {:update_system_activity, system_id, activity_data})
  end

  @doc """
  Update chain intelligence data for wormhole systems.
  """
  def update_chain_intelligence(chain_id, update_data) do
    GenServer.cast(__MODULE__, {:update_chain_intelligence, chain_id, update_data})
  end

  @doc """
  Process vetting result change.
  """
  def update_vetting_result(character_id, new_result, previous_result, opts \\ []) do
    GenServer.cast(
      __MODULE__,
      {:update_vetting_result, character_id, new_result, previous_result, opts}
    )
  end

  @doc """
  Subscribe to real-time intelligence updates for a specific scope.

  Scope can be:
  - :global - All intelligence updates
  - {:character, character_id} - Updates for specific character
  - {:system, system_id} - Updates for specific system
  - {:chain, chain_id} - Updates for specific wormhole chain
  """
  def subscribe_to_updates(scope, subscriber_pid \\ self()) do
    GenServer.call(__MODULE__, {:subscribe, scope, subscriber_pid})
  end

  @doc """
  Unsubscribe from real-time intelligence updates.
  """
  def unsubscribe_from_updates(ref) do
    GenServer.call(__MODULE__, {:unsubscribe, ref})
  end

  @doc """
  Get current intelligence status and statistics.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    # Subscribe to relevant domain events
    {:ok, _ref1} = EventBus.subscribe_process(:killmail_processed)
    {:ok, _ref2} = EventBus.subscribe_process(:battle_detected)
    {:ok, _ref3} = EventBus.subscribe_process(:character_analysis_complete)

    # Schedule periodic intelligence updates
    schedule_intelligence_update()

    state = %{
      subscriptions: %{},
      # character_id -> threat_data
      active_threats: %{},
      # system_id -> activity_data
      system_activity: %{},
      # chain_id -> intelligence_data
      chain_intelligence: %{},
      # Recent battle activity
      recent_battles: [],
      stats: %{
        killmails_processed: 0,
        threats_tracked: 0,
        events_published: 0,
        active_subscriptions: 0
      }
    }

    Logger.info("Real-time Intelligence Coordinator started")
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:process_killmail, killmail}, state) do
    # Extract intelligence from killmail
    try do
      # Check if this killmail indicates a battle
      battle_analysis = analyze_killmail_for_battle(killmail)

      if battle_analysis[:is_battle] do
        EventPublisher.publish_battle_detected(
          battle_analysis[:battle_id],
          killmail.solar_system_id,
          battle_analysis[:participant_count],
          battle_analysis[:opts]
        )
      end

      # Update character threat assessments for participants
      participants = extract_participants(killmail)
      update_participant_threats(participants, killmail.solar_system_id)

      # Check for activity spikes
      update_system_activity_from_killmail(killmail)

      new_stats = %{state.stats | killmails_processed: state.stats.killmails_processed + 1}
      {:noreply, %{state | stats: new_stats}}
    rescue
      error ->
        Logger.error("Error processing killmail for intelligence: #{inspect(error)}")
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast(
        {:update_character_threat, character_id, new_assessment, previous_assessment},
        state
      ) do
    # Check if threat level change is significant
    threat_change = calculate_threat_change(new_assessment, previous_assessment)

    if threat_change >= @threat_level_change_threshold do
      EventPublisher.publish_threat_update(
        character_id,
        new_assessment.threat_level,
        previous_assessment && previous_assessment.threat_level,
        analysis_factors: new_assessment.contributing_factors,
        system_id: new_assessment.last_seen_system,
        confidence_score: new_assessment.confidence
      )
    end

    # Update state
    new_active_threats = Map.put(state.active_threats, character_id, new_assessment)
    new_stats = %{state.stats | threats_tracked: map_size(new_active_threats)}

    {:noreply, %{state | active_threats: new_active_threats, stats: new_stats}}
  end

  @impl GenServer
  def handle_cast({:update_system_activity, system_id, activity_data}, state) do
    previous_activity = Map.get(state.system_activity, system_id)

    # Check for activity spikes
    if previous_activity && activity_spike_detected?(activity_data, previous_activity) do
      EventPublisher.publish_activity_spike(
        system_id,
        activity_data.current_level,
        previous_activity.baseline_level,
        activity_data.activity_type,
        duration_minutes: activity_data.duration_minutes,
        related_events: activity_data.related_events
      )
    end

    # Update state
    new_system_activity = Map.put(state.system_activity, system_id, activity_data)
    {:noreply, %{state | system_activity: new_system_activity}}
  end

  @impl GenServer
  def handle_cast({:update_chain_intelligence, chain_id, update_data}, state) do
    EventPublisher.publish_chain_update(
      chain_id,
      update_data.update_type,
      system_changes: update_data.system_changes,
      threat_changes: update_data.threat_changes,
      new_signatures: update_data.new_signatures,
      pilot_movements: update_data.pilot_movements
    )

    # Update state
    new_chain_intelligence = Map.put(state.chain_intelligence, chain_id, update_data)
    {:noreply, %{state | chain_intelligence: new_chain_intelligence}}
  end

  @impl GenServer
  def handle_cast(
        {:update_vetting_result, character_id, new_result, previous_result, opts},
        state
      ) do
    EventPublisher.publish_vetting_update(
      character_id,
      new_result,
      previous_result: previous_result,
      vetting_factors: opts[:vetting_factors],
      reviewer_notes: opts[:reviewer_notes],
      confidence_score: opts[:confidence_score],
      expires_at: opts[:expires_at]
    )

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:subscribe, scope, subscriber_pid}, _from, state) do
    ref = make_ref()

    subscription = %{
      scope: scope,
      subscriber_pid: subscriber_pid,
      subscribed_at: DateTime.utc_now()
    }

    new_subscriptions = Map.put(state.subscriptions, ref, subscription)
    new_stats = %{state.stats | active_subscriptions: map_size(new_subscriptions)}

    # Monitor the subscriber process
    Process.monitor(subscriber_pid)

    Logger.debug("Real-time intelligence subscription created", %{
      scope: inspect(scope),
      subscriber: inspect(subscriber_pid),
      ref: ref
    })

    {:reply, {:ok, ref}, %{state | subscriptions: new_subscriptions, stats: new_stats}}
  end

  @impl GenServer
  def handle_call({:unsubscribe, ref}, _from, state) do
    new_subscriptions = Map.delete(state.subscriptions, ref)
    new_stats = %{state.stats | active_subscriptions: map_size(new_subscriptions)}

    {:reply, :ok, %{state | subscriptions: new_subscriptions, stats: new_stats}}
  end

  @impl GenServer
  def handle_call(:get_status, _from, state) do
    status = %{
      active_threats: map_size(state.active_threats),
      monitored_systems: map_size(state.system_activity),
      tracked_chains: map_size(state.chain_intelligence),
      recent_battles: length(state.recent_battles),
      stats: state.stats,
      uptime: get_uptime()
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_info({:domain_event, event_type, event}, state) do
    # Handle domain events from other systems
    case event_type do
      :killmail_processed ->
        # Process via cast to avoid blocking
        GenServer.cast(self(), {:process_killmail, event})

      :battle_detected ->
        # Update recent battles list
        # Keep last 10
        new_recent_battles = [event | Enum.take(state.recent_battles, 9)]
        {:noreply, %{state | recent_battles: new_recent_battles}}

      :character_analysis_complete ->
        # Update character threat if analysis included threat assessment
        if event.threat_assessment do
          GenServer.cast(
            self(),
            {:update_character_threat, event.character_id, event.threat_assessment,
             event.previous_assessment}
          )
        end

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove subscriptions for dead processes
    new_subscriptions =
      Enum.filter(state.subscriptions, fn {_ref, sub} -> sub.subscriber_pid != pid end)
      |> Map.new()

    new_stats = %{state.stats | active_subscriptions: map_size(new_subscriptions)}
    {:noreply, %{state | subscriptions: new_subscriptions, stats: new_stats}}
  end

  @impl GenServer
  def handle_info(:intelligence_update, state) do
    # Periodic intelligence health check and cleanup
    schedule_intelligence_update()

    # Clean up old data
    cleaned_state = cleanup_old_data(state)

    {:noreply, cleaned_state}
  end

  @impl GenServer
  def handle_info(msg, state) do
    Logger.debug(
      "Real-time Intelligence Coordinator received unexpected message: #{inspect(msg)}"
    )

    {:noreply, state}
  end

  # Private functions

  defp schedule_intelligence_update do
    Process.send_after(self(), :intelligence_update, @intelligence_update_interval)
  end

  defp analyze_killmail_for_battle(killmail) do
    # +1 for victim
    participant_count = length(killmail.attackers || []) + 1

    is_battle = participant_count >= @battle_participant_threshold

    if is_battle do
      battle_id = "battle_#{killmail.solar_system_id}_#{DateTime.to_unix(killmail.killmail_time)}"

      %{
        is_battle: true,
        battle_id: battle_id,
        participant_count: participant_count,
        opts: [
          isk_destroyed: killmail.total_value || 0,
          battle_status: :developing,
          involved_alliances: extract_alliances(killmail)
        ]
      }
    else
      %{is_battle: false}
    end
  end

  defp extract_participants(killmail) do
    attackers =
      Enum.map(killmail.attackers || [], fn attacker ->
        get_in(attacker, ["character_id"])
      end)

    victim = [killmail.victim_character_id]

    (attackers ++ victim)
    |> Enum.filter(& &1)
    |> Enum.uniq()
  end

  defp extract_alliances(killmail) do
    attacker_alliances =
      Enum.map(killmail.attackers || [], fn attacker ->
        get_in(attacker, ["alliance_id"])
      end)

    victim_alliance = [killmail.victim_alliance_id]

    (attacker_alliances ++ victim_alliance)
    |> Enum.filter(& &1)
    |> Enum.uniq()
  end

  defp update_participant_threats(participant_ids, _system_id) do
    # Spawn async tasks to update threat assessments
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      Enum.each(participant_ids, fn character_id ->
        # This would typically call the threat scoring system
        # For now, we'll simulate a threat update
        case ThreatScoringCoordinator.calculate_threat_score(character_id) do
          {:ok, threat_data} ->
            GenServer.cast(__MODULE__, {:update_character_threat, character_id, threat_data, nil})

          {:error, _reason} ->
            # Skip if threat scoring fails
            :ok
        end
      end)
    end)
  end

  defp update_system_activity_from_killmail(killmail) do
    # This would integrate with system activity monitoring
    # For now, we simulate activity data
    activity_data = %{
      current_level: 1,
      baseline_level: 0.5,
      activity_type: :killmail_volume,
      duration_minutes: 5,
      related_events: []
    }

    GenServer.cast(__MODULE__, {:update_system_activity, killmail.solar_system_id, activity_data})
  end

  defp calculate_threat_change(new_assessment, previous_assessment) do
    if previous_assessment do
      new_level = new_assessment.threat_level || 0.0
      previous_level = previous_assessment.threat_level || 0.0

      if previous_level > 0 do
        abs(new_level - previous_level) / previous_level
      else
        new_level
      end
    else
      # Always publish first assessment
      1.0
    end
  end

  defp activity_spike_detected?(current_activity, previous_activity) do
    current_level = current_activity.current_level || 0
    baseline_level = previous_activity.baseline_level || 0.1

    current_level / baseline_level >= @activity_spike_threshold
  end

  defp cleanup_old_data(state) do
    # Clean up data older than 1 hour
    cutoff_time = DateTime.add(DateTime.utc_now(), -3600, :second)

    # Filter recent battles
    new_recent_battles =
      Enum.filter(state.recent_battles, fn battle ->
        DateTime.compare(battle.detected_at, cutoff_time) == :gt
      end)

    %{state | recent_battles: new_recent_battles}
  end

  defp get_uptime do
    # Simple uptime calculation
    {:ok, started_at} = Application.get_env(:eve_dmv, :started_at, DateTime.utc_now())
    DateTime.diff(DateTime.utc_now(), started_at, :second)
  end
end
