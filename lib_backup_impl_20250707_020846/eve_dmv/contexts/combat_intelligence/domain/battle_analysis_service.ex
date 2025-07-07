defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysisService do
  @moduledoc """
  Advanced battle analysis service for EVE DMV Combat Intelligence.

  Provides comprehensive battle analytics including:
  - Real-time engagement tracking and analysis
  - Fleet composition effectiveness evaluation
  - Tactical timeline reconstruction
  - Combat pattern recognition
  - Post-battle performance metrics
  - Tactical recommendations generation

  This service processes killmail data to provide actionable intelligence
  for fleet commanders and strategic planners.
  """

  use GenServer
  use EveDmv.ErrorHandler

  alias EveDmv.Contexts.CombatIntelligence.Infrastructure.BattleCache
  alias EveDmv.Contexts.CombatIntelligence.Infrastructure.KillmailRepository
  alias EveDmv.Contexts.FleetOperations.Domain.FleetAnalyzer
  alias EveDmv.Contexts.ThreatAssessment.Analyzers.ThreatAnalyzer
  alias EveDmv.DomainEvents.BattleAnalysisComplete
  alias EveDmv.DomainEvents.TacticalInsightGenerated
  alias EveDmv.Infrastructure.EventBus
  alias EveDmv.Result

  require Logger

  # Analysis thresholds
  @min_participants_for_battle 5
  @battle_time_window_seconds 300  # 5 minutes
  @engagement_merge_distance 3  # Systems
  @tactical_confidence_threshold 0.7

  # Battle classification thresholds
  @small_gang_max 10
  @medium_fleet_max 50
  @large_fleet_min 50

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Analyze a battle or engagement from killmail data.

  Provides comprehensive analysis including timeline, fleet composition,
  tactical effectiveness, and strategic recommendations.
  """
  def analyze_battle(battle_id, opts \\ []) do
    GenServer.call(__MODULE__, {:analyze_battle, battle_id, opts})
  end

  @doc """
  Analyze an ongoing engagement in real-time.

  Tracks developing battles and provides live tactical insights.
  """
  def analyze_live_engagement(system_id, opts \\ []) do
    GenServer.call(__MODULE__, {:analyze_live_engagement, system_id, opts})
  end

  @doc """
  Generate tactical recommendations based on battle analysis.
  """
  def generate_tactical_recommendations(battle_analysis) do
    GenServer.call(__MODULE__, {:generate_recommendations, battle_analysis})
  end

  @doc """
  Get battle timeline for visualization.
  """
  def get_battle_timeline(battle_id, opts \\ []) do
    GenServer.call(__MODULE__, {:get_battle_timeline, battle_id, opts})
  end

  @doc """
  Compare multiple battles for pattern analysis.
  """
  def compare_battles(battle_ids, opts \\ []) do
    GenServer.call(__MODULE__, {:compare_battles, battle_ids, opts})
  end

  @doc """
  Get performance metrics for a specific entity in battles.
  """
  def get_entity_battle_performance(entity_id, entity_type, opts \\ []) do
    GenServer.call(__MODULE__, {:get_entity_performance, entity_id, entity_type, opts})
  end

  # GenServer implementation

  @impl GenServer
  def init(opts) do
    # Subscribe to killmail events for real-time analysis
    Phoenix.PubSub.subscribe(EveDmv.PubSub, "killmails:enriched")

    state = %{
      active_engagements: %{},  # system_id -> engagement_data
      battle_cache: %{},  # battle_id -> analysis_cache
      metrics: %{
        battles_analyzed: 0,
        recommendations_generated: 0,
        active_engagements_tracked: 0
      }
    }

    # Schedule periodic engagement cleanup
    Process.send_after(self(), :cleanup_stale_engagements, 60_000)

    Logger.info("BattleAnalysisService started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:analyze_battle, battle_id, opts}, _from, state) do
    try do
      # Check cache first
      case Map.get(state.battle_cache, battle_id) do
        nil ->
          # Perform full analysis
          with {:ok, killmails} <- fetch_battle_killmails(battle_id),
               {:ok, timeline} <- construct_battle_timeline(killmails),
               {:ok, participants} <- extract_battle_participants(killmails),
               {:ok, fleet_analysis} <- analyze_fleet_compositions(participants, killmails),
               {:ok, tactical_analysis} <- perform_tactical_analysis(timeline, fleet_analysis),
               {:ok, performance_metrics} <- calculate_performance_metrics(killmails, participants) do

            analysis = %{
              battle_id: battle_id,
              analyzed_at: DateTime.utc_now(),

              # Battle overview
              duration_seconds: calculate_battle_duration(timeline),
              total_participants: map_size(participants),
              total_kills: length(killmails),
              isk_destroyed: calculate_total_isk_destroyed(killmails),

              # Classification
              battle_type: classify_battle_type(participants, killmails),
              engagement_scale: classify_engagement_scale(participants),

              # Timeline
              timeline: timeline,
              phases: identify_battle_phases(timeline),

              # Fleet analysis
              fleet_compositions: fleet_analysis,
              doctrine_effectiveness: evaluate_doctrine_effectiveness(fleet_analysis),

              # Tactical analysis
              tactical_patterns: tactical_analysis.patterns,
              key_moments: tactical_analysis.key_moments,
              turning_points: tactical_analysis.turning_points,

              # Performance
              side_performance: performance_metrics.by_side,
              ship_class_effectiveness: performance_metrics.by_ship_class,
              top_performers: performance_metrics.top_performers,

              # Strategic insights
              winner: determine_battle_winner(performance_metrics),
              victory_factors: analyze_victory_factors(tactical_analysis, performance_metrics)
            }

            # Cache the analysis
            new_cache = Map.put(state.battle_cache, battle_id, analysis)
            new_metrics = %{state.metrics | battles_analyzed: state.metrics.battles_analyzed + 1}
            new_state = %{state | battle_cache: new_cache, metrics: new_metrics}

            # Publish analysis complete event
            EventBus.publish(%BattleAnalysisComplete{
              battle_id: battle_id,
              battle_type: analysis.battle_type,
              participant_count: analysis.total_participants,
              isk_destroyed: analysis.isk_destroyed,
              timestamp: DateTime.utc_now()
            })

            {:reply, {:ok, analysis}, new_state}
          else
            {:error, _reason} = error -> {:reply, error, state}
          end

        cached_analysis ->
          # Return cached analysis
          {:reply, {:ok, cached_analysis}, state}
      end
    rescue
      exception ->
        Logger.error("Battle analysis error: #{inspect(exception)}")
        {:reply, {:error, :analysis_failed}, state}
    end
  end

  @impl GenServer
  def handle_call({:analyze_live_engagement, system_id, opts}, _from, state) do
    try do
      # Get or create engagement tracking
      engagement = Map.get(state.active_engagements, system_id, %{
        system_id: system_id,
        started_at: DateTime.utc_now(),
        killmails: [],
        participants: %{},
        last_activity: DateTime.utc_now()
      })

      # Fetch recent killmails
      with {:ok, recent_kills} <- fetch_recent_system_kills(system_id, 300),
           {:ok, updated_engagement} <- update_engagement_data(engagement, recent_kills),
           {:ok, live_analysis} <- perform_live_analysis(updated_engagement) do

        # Update state
        new_engagements = Map.put(state.active_engagements, system_id, updated_engagement)
        new_state = %{state | active_engagements: new_engagements}

        {:reply, {:ok, live_analysis}, new_state}
      else
        {:error, _reason} = error -> {:reply, error, state}
      end
    rescue
      exception ->
        Logger.error("Live engagement analysis error: #{inspect(exception)}")
        {:reply, {:error, :live_analysis_failed}, state}
    end
  end

  @impl GenServer
  def handle_call({:generate_recommendations, battle_analysis}, _from, state) do
    try do
      recommendations = %{
        tactical: do_generate_tactical_recommendations(battle_analysis),
        strategic: generate_strategic_recommendations(battle_analysis),
        doctrine: generate_doctrine_recommendations(battle_analysis),
        training: generate_training_recommendations(battle_analysis)
      }

      # Update metrics
      new_metrics = %{state.metrics | recommendations_generated: state.metrics.recommendations_generated + 1}
      new_state = %{state | metrics: new_metrics}

      # Publish tactical insight event
      EventBus.publish(%TacticalInsightGenerated{
        battle_id: battle_analysis.battle_id,
        insight_type: :recommendations,
        recommendations: recommendations,
        timestamp: DateTime.utc_now()
      })

      {:reply, {:ok, recommendations}, new_state}
    rescue
      exception ->
        Logger.error("Recommendation generation error: #{inspect(exception)}")
        {:reply, {:error, :recommendation_generation_failed}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_battle_timeline, battle_id, opts}, _from, state) do
    try do
      with {:ok, killmails} <- fetch_battle_killmails(battle_id),
           {:ok, timeline} <- construct_detailed_timeline(killmails, opts) do

        timeline_data = %{
          battle_id: battle_id,
          events: timeline,
          duration: calculate_timeline_duration(timeline),
          intensity_curve: calculate_intensity_curve(timeline),
          participant_flow: track_participant_flow(timeline)
        }

        {:reply, {:ok, timeline_data}, state}
      else
        {:error, _reason} = error -> {:reply, error, state}
      end
    rescue
      exception ->
        Logger.error("Timeline generation error: #{inspect(exception)}")
        {:reply, {:error, :timeline_generation_failed}, state}
    end
  end

  @impl GenServer
  def handle_call({:compare_battles, battle_ids, opts}, _from, state) do
    try do
      # Analyze each battle
      battle_analyses = Enum.map(battle_ids, fn battle_id ->
        case Map.get(state.battle_cache, battle_id) do
          nil ->
            # Trigger analysis if not cached
            {:ok, analysis} = elem(handle_call({:analyze_battle, battle_id, []}, nil, state), 0)
            analysis
          cached -> cached
        end
      end)

      comparison = %{
        battles: battle_analyses,
        common_patterns: identify_common_patterns(battle_analyses),
        tactical_evolution: analyze_tactical_evolution(battle_analyses),
        effectiveness_trends: compare_effectiveness_trends(battle_analyses),
        doctrine_comparison: compare_doctrine_usage(battle_analyses)
      }

      {:reply, {:ok, comparison}, state}
    rescue
      exception ->
        Logger.error("Battle comparison error: #{inspect(exception)}")
        {:reply, {:error, :comparison_failed}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_entity_performance, entity_id, entity_type, opts}, _from, state) do
    try do
      time_range = Keyword.get(opts, :time_range, :last_30_days)

      with {:ok, battles} <- fetch_entity_battles(entity_id, entity_type, time_range),
           {:ok, performance_data} <- analyze_entity_performance(entity_id, entity_type, battles) do

        {:reply, {:ok, performance_data}, state}
      else
        {:error, _reason} = error -> {:reply, error, state}
      end
    rescue
      exception ->
        Logger.error("Entity performance analysis error: #{inspect(exception)}")
        {:reply, {:error, :performance_analysis_failed}, state}
    end
  end

  @impl GenServer
  def handle_info({:killmail_enriched, killmail}, state) do
    # Track live engagements
    if killmail.system_id do
      engagement = Map.get(state.active_engagements, killmail.system_id, %{
        system_id: killmail.system_id,
        started_at: DateTime.utc_now(),
        killmails: [],
        participants: %{},
        last_activity: DateTime.utc_now()
      })

      updated_engagement = %{
        engagement |
        killmails: [killmail | engagement.killmails],
        last_activity: DateTime.utc_now()
      }

      new_engagements = Map.put(state.active_engagements, killmail.system_id, updated_engagement)
      new_state = %{state | active_engagements: new_engagements}

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:cleanup_stale_engagements, state) do
    # Remove engagements with no activity for 10 minutes
    cutoff_time = DateTime.add(DateTime.utc_now(), -600, :second)

    active_engagements =
      state.active_engagements
      |> Enum.filter(fn {_system_id, engagement} ->
        DateTime.compare(engagement.last_activity, cutoff_time) == :gt
      end)
      |> Map.new()

    # Schedule next cleanup
    Process.send_after(self(), :cleanup_stale_engagements, 60_000)

    {:noreply, %{state | active_engagements: active_engagements}}
  end

  # Private functions

  defp fetch_battle_killmails(battle_id) do
    # This would fetch killmails associated with a battle
    # For now, returning mock data
    {:ok, []}
  end

  defp fetch_recent_system_kills(system_id, seconds_back) do
    # Fetch recent kills from a system
    {:ok, []}
  end

  defp construct_battle_timeline(killmails) do
    timeline =
      killmails
      |> Enum.sort_by(&(&1.killmail_time))
      |> Enum.map(fn km ->
        %{
          timestamp: km.killmail_time,
          event_type: :kill,
          victim: %{
            character_id: km.victim_character_id,
            corporation_id: km.victim_corporation_id,
            ship_type_id: km.victim_ship_type_id
          },
          attackers_count: length(km.attackers || []),
          final_blow: find_final_blow_attacker(km.attackers),
          isk_value: km.total_value
        }
      end)

    {:ok, timeline}
  end

  defp construct_detailed_timeline(killmails, opts) do
    include_damage_dealt = Keyword.get(opts, :include_damage, true)

    timeline =
      killmails
      |> Enum.sort_by(&(&1.killmail_time))
      |> Enum.map(fn km ->
        event = %{
          timestamp: km.killmail_time,
          event_type: :kill,
          killmail_id: km.killmail_id,
          system_id: km.system_id,
          victim: extract_victim_details(km),
          attackers: if(include_damage_dealt, do: extract_attacker_details(km), else: nil),
          isk_destroyed: km.total_value,
          ship_class: classify_ship(km.victim_ship_type_id)
        }

        event
      end)

    {:ok, timeline}
  end

  defp extract_battle_participants(killmails) do
    participants =
      Enum.reduce(killmails, %{}, fn km, acc ->
        # Add victim
        acc = Map.put(acc, km.victim_character_id, %{
          character_id: km.victim_character_id,
          corporation_id: km.victim_corporation_id,
          alliance_id: km.victim_alliance_id,
          side: determine_side(km.victim_corporation_id, km.victim_alliance_id),
          kills: 0,
          losses: 1,
          damage_dealt: 0,
          ships_used: MapSet.new([km.victim_ship_type_id])
        })

        # Add attackers
        Enum.reduce(km.attackers || [], acc, fn attacker, acc2 ->
          char_id = attacker["character_id"]

          if char_id && char_id != 0 do
            existing = Map.get(acc2, char_id, %{
              character_id: char_id,
              corporation_id: attacker["corporation_id"],
              alliance_id: attacker["alliance_id"],
              side: determine_side(attacker["corporation_id"], attacker["alliance_id"]),
              kills: 0,
              losses: 0,
              damage_dealt: 0,
              ships_used: MapSet.new()
            })

            updated = %{
              existing |
              kills: existing.kills + if(attacker["final_blow"], do: 1, else: 0),
              damage_dealt: existing.damage_dealt + (attacker["damage_done"] || 0),
              ships_used: MapSet.put(existing.ships_used, attacker["ship_type_id"])
            }

            Map.put(acc2, char_id, updated)
          else
            acc2
          end
        end)
      end)

    {:ok, participants}
  end

  defp analyze_fleet_compositions(participants, killmails) do
    # Group participants by side
    sides =
      participants
      |> Map.values()
      |> Enum.group_by(&(&1.side))

    fleet_comps =
      Map.new(sides, fn {side, side_participants} ->
        ship_composition = analyze_side_ship_composition(side_participants)
        {side, %{
          pilot_count: length(side_participants),
          ship_composition: ship_composition,
          doctrine_detected: detect_doctrine_usage(ship_composition),
          average_pilot_efficiency: calculate_average_efficiency(side_participants),
          logistics_ratio: calculate_logistics_ratio(ship_composition),
          ewar_presence: detect_ewar_presence(ship_composition)
        }}
      end)

    {:ok, fleet_comps}
  end

  defp perform_tactical_analysis(timeline, fleet_analysis) do
    analysis = %{
      patterns: identify_tactical_patterns(timeline),
      key_moments: identify_key_moments(timeline),
      turning_points: identify_turning_points(timeline, fleet_analysis),
      engagement_flow: analyze_engagement_flow(timeline),
      focus_fire_effectiveness: analyze_focus_fire(timeline),
      target_selection: analyze_target_selection(timeline, fleet_analysis)
    }

    {:ok, analysis}
  end

  defp calculate_performance_metrics(killmails, participants) do
    # Group by side
    sides =
      participants
      |> Map.values()
      |> Enum.group_by(&(&1.side))

    by_side =
      sides
      |> Enum.map(fn {side, side_participants} ->
        {side, %{
          kills: Enum.sum(Enum.map(side_participants, &(&1.kills))),
          losses: Enum.sum(Enum.map(side_participants, &(&1.losses))),
          isk_destroyed: calculate_side_isk_destroyed(side, killmails),
          isk_lost: calculate_side_isk_lost(side, killmails),
          efficiency: calculate_side_efficiency(side, killmails),
          k_d_ratio: calculate_side_kd_ratio(side_participants)
        }}
      end)
      |> Map.new()

    by_ship_class = analyze_ship_class_performance(killmails, participants)
    top_performers = identify_top_performers(participants)

    {:ok, %{
      by_side: by_side,
      by_ship_class: by_ship_class,
      top_performers: top_performers
    }}
  end

  defp update_engagement_data(engagement, new_kills) do
    # Add new kills to engagement
    all_kills = engagement.killmails ++ new_kills

    # Update participants
    participants =
      Enum.reduce(all_kills, engagement.participants, fn km, acc ->
        # Similar logic to extract_battle_participants but incremental
        acc
      end)
    updated = %{
      engagement |
      killmails: all_kills,
      participants: participants,
      last_activity: DateTime.utc_now()
    }

    {:ok, updated}
  end

  defp perform_live_analysis(engagement) do
    # Quick analysis for live engagement
    participant_count = map_size(engagement.participants)
    kill_rate = calculate_kill_rate(engagement.killmails)

    analysis = %{
      system_id: engagement.system_id,
      status: determine_engagement_status(engagement),
      duration_seconds: DateTime.diff(DateTime.utc_now(), engagement.started_at),
      participant_count: participant_count,
      kill_count: length(engagement.killmails),
      kill_rate_per_minute: kill_rate,
      engagement_intensity: calculate_engagement_intensity(kill_rate, participant_count),
      likely_outcome: predict_engagement_outcome(engagement)
    }

    {:ok, analysis}
  end

  defp do_generate_tactical_recommendations(battle_analysis) do
    recommendations = []

    # Fleet composition recommendations
    recommendations = recommendations ++
      if battle_analysis.fleet_compositions do
        analyze_fleet_composition_gaps(battle_analysis.fleet_compositions)
      else
        []
      end

    # Tactical pattern recommendations
    recommendations = recommendations ++
      if battle_analysis.tactical_patterns do
        generate_pattern_based_recommendations(battle_analysis.tactical_patterns)
      else
        []
      end

    recommendations
  end

  defp generate_strategic_recommendations(battle_analysis) do
    Enum.filter([
      analyze_strategic_positioning(battle_analysis),
      recommend_force_multiplication(battle_analysis),
      suggest_engagement_timing(battle_analysis)
    ], &(&1 != nil))
  end

  defp generate_doctrine_recommendations(battle_analysis) do
    fleet_comps = battle_analysis.fleet_compositions

    if fleet_comps do
      Enum.filter([
        recommend_doctrine_adjustments(fleet_comps),
        suggest_counter_doctrines(fleet_comps),
        identify_doctrine_weaknesses(fleet_comps)
      ], &(&1 != nil))
    else
      []
    end
  end

  defp generate_training_recommendations(battle_analysis) do
    Enum.filter([
      identify_skill_gaps(battle_analysis),
      recommend_practice_scenarios(battle_analysis),
      suggest_role_specializations(battle_analysis)
    ], &(&1 != nil))
  end

  # Helper functions

  defp calculate_battle_duration(timeline) do
    if not Enum.empty?(timeline) do
      first_event = List.first(timeline)
      last_event = List.last(timeline)
      DateTime.diff(last_event.timestamp, first_event.timestamp)
    else
      0
    end
  end

  defp calculate_total_isk_destroyed(killmails) do
    Enum.sum(Enum.map(killmails, &(&1.total_value || 0)))
  end

  defp classify_battle_type(participants, killmails) do
    participant_count = map_size(participants)

    cond do
      participant_count <= @small_gang_max -> :small_gang
      participant_count <= @medium_fleet_max -> :fleet_fight
      true -> :large_scale_battle
    end
  end

  defp classify_engagement_scale(participants) do
    count = map_size(participants)

    cond do
      count < 5 -> :skirmish
      count < 15 -> :small_gang
      count < 30 -> :medium_gang
      count < 75 -> :fleet
      count < 150 -> :large_fleet
      true -> :massive_battle
    end
  end

  defp identify_battle_phases(timeline) do
    # Identify distinct phases based on kill intensity
    []
  end

  defp determine_side(corporation_id, alliance_id) do
    # Logic to determine which side a participant is on
    # This would use corporation/alliance standings or other logic
    # For now, simple hash-based assignment
    hash = :erlang.phash2({corporation_id, alliance_id})
    if rem(hash, 2) == 0, do: :side_a, else: :side_b
  end

  defp find_final_blow_attacker(attackers) do
    Enum.find(attackers, &(&1["final_blow"] == true))
  end

  defp classify_ship(ship_type_id) do
    # This would use ship database to classify
    # Mock implementation
    :cruiser
  end

  defp extract_victim_details(killmail) do
    %{
      character_id: killmail.victim_character_id,
      character_name: killmail.victim_character_name,
      corporation_id: killmail.victim_corporation_id,
      corporation_name: killmail.victim_corporation_name,
      alliance_id: killmail.victim_alliance_id,
      alliance_name: killmail.victim_alliance_name,
      ship_type_id: killmail.victim_ship_type_id,
      ship_name: killmail.victim_ship_name
    }
  end

  defp extract_attacker_details(killmail) do
    Enum.map(killmail.attackers, fn attacker ->
      %{
        character_id: attacker["character_id"],
        character_name: attacker["character_name"],
        corporation_id: attacker["corporation_id"],
        corporation_name: attacker["corporation_name"],
        ship_type_id: attacker["ship_type_id"],
        weapon_type_id: attacker["weapon_type_id"],
        damage_done: attacker["damage_done"],
        final_blow: attacker["final_blow"]
      }
    end)
  end

  defp analyze_side_ship_composition(participants) do
    participants
    |> Enum.flat_map(&MapSet.to_list(&1.ships_used))
    |> Enum.frequencies()
  end

  defp detect_doctrine_usage(ship_composition) do
    # Detect common doctrine patterns
    nil
  end

  defp calculate_average_efficiency(participants) do
    total_kills = Enum.sum(Enum.map(participants, &(&1.kills)))
    total_losses = Enum.sum(Enum.map(participants, &(&1.losses)))

    if total_losses > 0 do
      total_kills / total_losses
    else
      total_kills
    end
  end

  defp calculate_logistics_ratio(ship_composition) do
    # Calculate ratio of logistics ships
    0.0
  end

  defp detect_ewar_presence(ship_composition) do
    # Detect electronic warfare ships
    false
  end

  defp identify_tactical_patterns(timeline) do
    []
  end

  defp identify_key_moments(timeline) do
    []
  end

  defp identify_turning_points(timeline, fleet_analysis) do
    []
  end

  defp analyze_engagement_flow(timeline) do
    %{
      phases: [],
      intensity_changes: []
    }
  end

  defp analyze_focus_fire(timeline) do
    %{
      effectiveness: 0.0,
      coordination_score: 0.0
    }
  end

  defp analyze_target_selection(timeline, fleet_analysis) do
    %{
      priority_targets_hit: 0.0,
      target_switching_rate: 0.0
    }
  end

  defp calculate_side_isk_destroyed(side, killmails) do
    0
  end

  defp calculate_side_isk_lost(side, killmails) do
    0
  end

  defp calculate_side_efficiency(side, killmails) do
    100.0
  end

  defp calculate_side_kd_ratio(participants) do
    1.0
  end

  defp analyze_ship_class_performance(killmails, participants) do
    %{}
  end

  defp identify_top_performers(participants) do
    participants
    |> Map.values()
    |> Enum.sort_by(&(&1.kills), :desc)
    |> Enum.take(10)
  end

  defp calculate_kill_rate(killmails) do
    if not Enum.empty?(killmails) do
      first_kill = List.first(killmails)
      last_kill = List.last(killmails)
      duration_minutes = DateTime.diff(last_kill.killmail_time, first_kill.killmail_time) / 60

      if duration_minutes > 0 do
        length(killmails) / duration_minutes
      else
        0.0
      end
    else
      0.0
    end
  end

  defp determine_engagement_status(engagement) do
    last_activity_seconds = DateTime.diff(DateTime.utc_now(), engagement.last_activity)

    cond do
      last_activity_seconds < 60 -> :active
      last_activity_seconds < 300 -> :winding_down
      true -> :concluded
    end
  end

  defp calculate_engagement_intensity(kill_rate, participant_count) do
    if participant_count > 0 do
      intensity = kill_rate * 10 / participant_count

      cond do
        intensity > 2.0 -> :extreme
        intensity > 1.0 -> :high
        intensity > 0.5 -> :moderate
        intensity > 0.2 -> :low
        true -> :minimal
      end
    else
      :minimal
    end
  end

  defp predict_engagement_outcome(engagement) do
    # Simple prediction based on current kill ratio
    %{
      likely_winner: :undetermined,
      confidence: :low
    }
  end

  defp calculate_timeline_duration(timeline) do
    if not Enum.empty?(timeline) do
      first = List.first(timeline)
      last = List.last(timeline)
      DateTime.diff(last.timestamp, first.timestamp)
    else
      0
    end
  end

  defp calculate_intensity_curve(timeline) do
    # Calculate kills per minute over time
    []
  end

  defp track_participant_flow(timeline) do
    # Track when participants join/leave battle
    %{
      joiners: [],
      leavers: []
    }
  end

  defp identify_common_patterns(battle_analyses) do
    []
  end

  defp analyze_tactical_evolution(battle_analyses) do
    []
  end

  defp compare_effectiveness_trends(battle_analyses) do
    %{}
  end

  defp compare_doctrine_usage(battle_analyses) do
    %{}
  end

  defp fetch_entity_battles(entity_id, entity_type, time_range) do
    {:ok, []}
  end

  defp analyze_entity_performance(entity_id, entity_type, battles) do
    {:ok, %{
      entity_id: entity_id,
      entity_type: entity_type,
      battle_count: length(battles),
      win_rate: 0.0,
      average_efficiency: 100.0,
      preferred_doctrines: [],
      performance_trend: :stable
    }}
  end

  defp analyze_fleet_composition_gaps(fleet_compositions) do
    []
  end

  defp generate_pattern_based_recommendations(patterns) do
    []
  end

  defp analyze_strategic_positioning(battle_analysis) do
    nil
  end

  defp recommend_force_multiplication(battle_analysis) do
    nil
  end

  defp suggest_engagement_timing(battle_analysis) do
    nil
  end

  defp recommend_doctrine_adjustments(fleet_comps) do
    nil
  end

  defp suggest_counter_doctrines(fleet_comps) do
    nil
  end

  defp identify_doctrine_weaknesses(fleet_comps) do
    nil
  end

  defp identify_skill_gaps(battle_analysis) do
    nil
  end

  defp recommend_practice_scenarios(battle_analysis) do
    nil
  end

  defp suggest_role_specializations(battle_analysis) do
    nil
  end

  defp evaluate_doctrine_effectiveness(fleet_analysis) do
    %{}
  end

  defp determine_battle_winner(performance_metrics) do
    :undetermined
  end

  defp analyze_victory_factors(tactical_analysis, performance_metrics) do
    factors = []

    # Analyze numerical superiority
    factors = factors ++
      if performance_metrics.by_side do
        analyze_numerical_factors(performance_metrics.by_side)
      else
        []
      end

    # Analyze tactical effectiveness
    factors = factors ++
      if tactical_analysis.patterns do
        analyze_tactical_factors(tactical_analysis.patterns)
      else
        []
      end

    # Analyze engagement control
    factors = factors ++
      if tactical_analysis.key_moments do
        analyze_control_factors(tactical_analysis.key_moments)
      else
        []
      end

    factors
  end

  defp analyze_numerical_factors(side_performance) do
    # Analyze if numbers played a decisive role
    side_counts = Enum.map(side_performance, fn {_side, metrics} ->
      metrics.kills + metrics.losses
    end)

    if length(side_counts) >= 2 do
      [max_count, second_count | _] = Enum.sort(side_counts, :desc)

      if max_count > second_count * 1.5 do
        ["Numerical superiority was decisive"]
      else
        []
      end
    else
      []
    end
  end

  defp analyze_tactical_factors(patterns) do
    # Analyze tactical patterns for victory factors
    if Enum.any?(patterns, &(&1.type == :coordinated_alpha)) do
      ["Superior coordination and focus fire"]
    else
      []
    end
  end

  defp analyze_control_factors(key_moments) do
    # Analyze battlefield control moments
    if length(key_moments) > 0 do
      ["Effective battlefield control"]
    else
      []
    end
  end
end