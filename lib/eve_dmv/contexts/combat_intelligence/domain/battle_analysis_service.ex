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

  # alias EveDmv.Contexts.CombatIntelligence.Infrastructure.BattleCache
  # alias EveDmv.Contexts.CombatIntelligence.Infrastructure.KillmailRepository
  # alias EveDmv.Contexts.FleetOperations.Domain.FleetAnalyzer
  # alias EveDmv.Contexts.ThreatAssessment.Analyzers.ThreatAnalyzer
  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Phases.FleetCompositionAnalyzer
  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Phases.OutcomeAnalyzer

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.DataCollectors.BattleDataCollector

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Processors.BattleTimelineBuilder
  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.TacticalPatternDetector
  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Processors.PerformanceCalculator
  alias EveDmv.DomainEvents.BattleAnalysisComplete
  alias EveDmv.DomainEvents.TacticalInsightGenerated
  alias EveDmv.Infrastructure.EventBus

  require Logger

  # Battle classification thresholds
  @small_gang_max 10
  @medium_fleet_max 50

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
  def init(_opts) do
    # Subscribe to killmail events for real-time analysis
    Phoenix.PubSub.subscribe(EveDmv.PubSub, "killmails:enriched")

    state = %{
      # system_id -> engagement_data
      active_engagements: %{},
      # battle_id -> analysis_cache
      battle_cache: %{},
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
  def handle_call({:analyze_battle, battle_id, _opts}, _from, state) do
    # Check cache first
    case Map.get(state.battle_cache, battle_id) do
      nil ->
        # Perform full analysis
        case BattleDataCollector.fetch_battle_killmails(battle_id) do
          {:error, reason} ->
            {:reply, {:error, reason}, state}

          {:ok, killmails} ->
            with {:ok, timeline} <- BattleTimelineBuilder.construct_battle_timeline(killmails),
                 {:ok, participants} <-
                   BattleTimelineBuilder.extract_battle_participants(killmails),
                 {:ok, fleet_analysis} <- analyze_fleet_compositions(participants, killmails),
                 {:ok, tactical_analysis} <- perform_tactical_analysis(timeline, fleet_analysis),
                 {:ok, performance_metrics} <-
                   PerformanceCalculator.calculate_performance_metrics(killmails, participants) do
              analysis = %{
                battle_id: battle_id,
                analyzed_at: DateTime.utc_now(),

                # Battle overview
                duration_seconds: calculate_battle_duration(timeline),
                total_participants: map_size(participants),
                total_kills: length(killmails),
                isk_destroyed: PerformanceCalculator.calculate_total_isk_destroyed(killmails),

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

              new_metrics = %{
                state.metrics
                | battles_analyzed: state.metrics.battles_analyzed + 1
              }

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

  @impl GenServer
  def handle_call({:analyze_live_engagement, system_id, _opts}, _from, state) do
    # Get or create engagement tracking
    engagement =
      Map.get(state.active_engagements, system_id, %{
        system_id: system_id,
        started_at: DateTime.utc_now(),
        killmails: [],
        participants: %{},
        last_activity: DateTime.utc_now()
      })

    # Fetch recent killmails
    case BattleDataCollector.fetch_recent_system_kills(system_id, 300) do
      {:error, reason} ->
        {:reply, {:error, reason}, state}

      {:ok, recent_kills} ->
        with {:ok, updated_engagement} <- update_engagement_data(engagement, recent_kills),
             {:ok, live_analysis} <- perform_live_analysis(updated_engagement) do
          # Update state
          new_engagements = Map.put(state.active_engagements, system_id, updated_engagement)
          new_state = %{state | active_engagements: new_engagements}

          {:reply, {:ok, live_analysis}, new_state}
        else
          {:error, _reason} = error -> {:reply, error, state}
        end
    end
  rescue
    exception ->
      Logger.error("Live engagement analysis error: #{inspect(exception)}")
      {:reply, {:error, :live_analysis_failed}, state}
  end

  @impl GenServer
  def handle_call({:generate_recommendations, battle_analysis}, _from, state) do
    recommendations = %{
      tactical: do_generate_tactical_recommendations(battle_analysis),
      strategic: generate_strategic_recommendations(battle_analysis),
      doctrine: generate_doctrine_recommendations(battle_analysis),
      training: generate_training_recommendations(battle_analysis)
    }

    # Update metrics
    new_metrics = %{
      state.metrics
      | recommendations_generated: state.metrics.recommendations_generated + 1
    }

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

  @impl GenServer
  def handle_call({:get_battle_timeline, battle_id, opts}, _from, state) do
    with {:ok, killmails} <- BattleDataCollector.fetch_battle_killmails(battle_id),
         {:ok, timeline} <- BattleTimelineBuilder.construct_detailed_timeline(killmails, opts) do
      timeline_data = %{
        battle_id: battle_id,
        events: timeline,
        duration: calculate_timeline_duration(timeline),
        intensity_curve: PerformanceCalculator.calculate_intensity_curve(timeline),
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

  @impl GenServer
  def handle_call({:compare_battles, battle_ids, _opts}, _from, state) do
    # Analyze each battle
    battle_analyses =
      Enum.map(battle_ids, fn battle_id ->
        case Map.get(state.battle_cache, battle_id) do
          nil ->
            # Trigger analysis if not cached
            case handle_call({:analyze_battle, battle_id, []}, nil, state) do
              {:reply, {:ok, analysis}, _state} -> analysis
              _ -> nil
            end

          cached ->
            cached
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

  @impl GenServer
  def handle_call({:get_entity_performance, entity_id, entity_type, opts}, _from, state) do
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

  @impl GenServer
  def handle_info({:killmail_enriched, killmail}, state) do
    # Track live engagements
    if killmail.system_id do
      engagement =
        Map.get(state.active_engagements, killmail.system_id, %{
          system_id: killmail.system_id,
          started_at: DateTime.utc_now(),
          killmails: [],
          participants: %{},
          last_activity: DateTime.utc_now()
        })

      updated_engagement = %{
        engagement
        | killmails: [killmail | engagement.killmails],
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

  defp analyze_fleet_compositions(participants, killmails) do
    # Use the comprehensive FleetCompositionAnalyzer for detailed fleet analysis
    participants_list = Map.values(participants)

    try do
      fleet_analysis =
        FleetCompositionAnalyzer.analyze_fleet_compositions(participants_list, killmails)

      {:ok, fleet_analysis}
    rescue
      e ->
        Logger.error("Fleet composition analysis failed: #{Exception.message(e)}")
        # Fallback to basic analysis if the comprehensive analyzer fails
        {:ok, perform_basic_fleet_analysis(participants, killmails)}
    end
  end

  defp perform_basic_fleet_analysis(participants, _killmails) do
    # Basic fallback analysis
    sides =
      participants
      |> Map.values()
      |> Enum.group_by(& &1.side)

    Map.new(sides, fn {side, side_participants} ->
      ship_composition = analyze_side_ship_composition(side_participants)

      {side,
       %{
         pilot_count: length(side_participants),
         ship_composition: ship_composition,
         doctrine_detected: detect_doctrine_usage(ship_composition),
         average_pilot_efficiency:
           PerformanceCalculator.calculate_average_efficiency(side_participants),
         logistics_ratio: calculate_logistics_ratio(ship_composition),
         ewar_presence: detect_ewar_presence(ship_composition)
       }}
    end)
  end

  defp perform_tactical_analysis(timeline, fleet_analysis) do
    analysis = %{
      patterns: TacticalPatternDetector.identify_tactical_patterns(timeline),
      key_moments: TacticalPatternDetector.identify_key_moments(timeline),
      turning_points: TacticalPatternDetector.identify_turning_points(timeline, fleet_analysis),
      engagement_flow: TacticalPatternDetector.analyze_engagement_flow(timeline),
      focus_fire_effectiveness: TacticalPatternDetector.analyze_focus_fire(timeline),
      target_selection: TacticalPatternDetector.analyze_target_selection(timeline, fleet_analysis)
    }

    {:ok, analysis}
  end

  defp update_engagement_data(engagement, new_kills) do
    # Add new kills to engagement
    all_kills = engagement.killmails ++ new_kills

    # Update participants
    participants =
      Enum.reduce(all_kills, engagement.participants, fn _km, acc ->
        # Similar logic to extract_battle_participants but incremental
        acc
      end)

    updated = %{
      engagement
      | killmails: all_kills,
        participants: participants,
        last_activity: DateTime.utc_now()
    }

    {:ok, updated}
  end

  defp perform_live_analysis(engagement) do
    # Quick analysis for live engagement
    participant_count = map_size(engagement.participants)
    kill_rate = PerformanceCalculator.calculate_kill_rate(engagement.killmails)

    analysis = %{
      system_id: engagement.system_id,
      status: determine_engagement_status(engagement),
      duration_seconds: DateTime.diff(DateTime.utc_now(), engagement.started_at),
      participant_count: participant_count,
      kill_count: length(engagement.killmails),
      kill_rate_per_minute: kill_rate,
      engagement_intensity:
        PerformanceCalculator.calculate_engagement_intensity(
          engagement.killmails,
          participant_count
        ),
      likely_outcome: predict_engagement_outcome(engagement)
    }

    {:ok, analysis}
  end

  defp do_generate_tactical_recommendations(battle_analysis) do
    try do
      # Use the comprehensive OutcomeAnalyzer to generate recommendations
      outcome_analysis = %{
        victory_factors: battle_analysis.victory_factors || %{},
        tactical_patterns: battle_analysis.tactical_patterns || %{},
        fleet_compositions: battle_analysis.fleet_compositions || %{}
      }

      recommendations = OutcomeAnalyzer.generate_outcome_recommendations(outcome_analysis)

      # Extract immediate tactical recommendations
      recommendations.immediate_tactical
    rescue
      e ->
        Logger.error("Outcome recommendation generation failed: #{Exception.message(e)}")
        # Fallback to basic recommendations if the comprehensive analyzer fails
        perform_basic_tactical_recommendations(battle_analysis)
    end
  end

  defp perform_basic_tactical_recommendations(battle_analysis) do
    initial_recommendations = []

    # Fleet composition recommendations
    composition_recommendations =
      initial_recommendations ++
        if battle_analysis.fleet_compositions do
          analyze_fleet_composition_gaps(battle_analysis.fleet_compositions)
        else
          []
        end

    # Tactical pattern recommendations
    final_recommendations =
      composition_recommendations ++
        if battle_analysis.tactical_patterns do
          generate_pattern_based_recommendations(battle_analysis.tactical_patterns)
        else
          []
        end

    final_recommendations
  end

  defp generate_strategic_recommendations(battle_analysis) do
    try do
      # Use the comprehensive OutcomeAnalyzer to generate strategic recommendations
      outcome_analysis = %{
        victory_factors: battle_analysis.victory_factors || %{},
        tactical_patterns: battle_analysis.tactical_patterns || %{},
        fleet_compositions: battle_analysis.fleet_compositions || %{}
      }

      recommendations = OutcomeAnalyzer.generate_outcome_recommendations(outcome_analysis)

      # Extract strategic adjustments
      recommendations.strategic_adjustments
    rescue
      e ->
        Logger.error("Strategic recommendation generation failed: #{Exception.message(e)}")
        # Fallback to basic recommendations if the comprehensive analyzer fails
        perform_basic_strategic_recommendations(battle_analysis)
    end
  end

  defp perform_basic_strategic_recommendations(battle_analysis) do
    Enum.filter(
      [
        analyze_strategic_positioning(battle_analysis),
        recommend_force_multiplication(battle_analysis),
        suggest_engagement_timing(battle_analysis)
      ],
      &(&1 != nil)
    )
  end

  defp generate_doctrine_recommendations(battle_analysis) do
    try do
      # Use the comprehensive OutcomeAnalyzer to generate doctrine recommendations
      outcome_analysis = %{
        victory_factors: battle_analysis.victory_factors || %{},
        tactical_patterns: battle_analysis.tactical_patterns || %{},
        fleet_compositions: battle_analysis.fleet_compositions || %{}
      }

      recommendations = OutcomeAnalyzer.generate_outcome_recommendations(outcome_analysis)

      # Extract doctrine modifications
      recommendations.doctrine_modifications
    rescue
      e ->
        Logger.error("Doctrine recommendation generation failed: #{Exception.message(e)}")
        # Fallback to basic recommendations if the comprehensive analyzer fails
        perform_basic_doctrine_recommendations(battle_analysis)
    end
  end

  defp perform_basic_doctrine_recommendations(battle_analysis) do
    fleet_comps = battle_analysis.fleet_compositions

    if fleet_comps do
      Enum.filter(
        [
          recommend_doctrine_adjustments(fleet_comps),
          suggest_counter_doctrines(fleet_comps),
          identify_doctrine_weaknesses(fleet_comps)
        ],
        &(&1 != nil)
      )
    else
      []
    end
  end

  defp generate_training_recommendations(battle_analysis) do
    try do
      # Use the comprehensive OutcomeAnalyzer to generate training recommendations
      outcome_analysis = %{
        victory_factors: battle_analysis.victory_factors || %{},
        tactical_patterns: battle_analysis.tactical_patterns || %{},
        fleet_compositions: battle_analysis.fleet_compositions || %{}
      }

      recommendations = OutcomeAnalyzer.generate_outcome_recommendations(outcome_analysis)

      # Extract training priorities
      recommendations.training_priorities
    rescue
      e ->
        Logger.error("Training recommendation generation failed: #{Exception.message(e)}")
        # Fallback to basic recommendations if the comprehensive analyzer fails
        perform_basic_training_recommendations(battle_analysis)
    end
  end

  defp perform_basic_training_recommendations(battle_analysis) do
    Enum.filter(
      [
        identify_skill_gaps(battle_analysis),
        recommend_practice_scenarios(battle_analysis),
        suggest_role_specializations(battle_analysis)
      ],
      &(&1 != nil)
    )
  end

  # Helper functions

  defp calculate_battle_duration(timeline) do
    if Enum.empty?(timeline) do
      0
    else
      first_event = List.first(timeline)
      last_event = List.last(timeline)
      DateTime.diff(last_event.timestamp, first_event.timestamp)
    end
  end

  defp classify_battle_type(participants, _killmails) do
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
    # Identify distinct phases based on kill intensity and timing patterns
    if length(timeline) < 3 do
      []
    else
      # Simple phase identification based on kill clustering
      detailed_phases = [
        %{
          phase_number: 1,
          start_time: List.first(timeline).timestamp,
          end_time: List.last(timeline).timestamp,
          duration_seconds:
            DateTime.diff(List.last(timeline).timestamp, List.first(timeline).timestamp),
          kills: length(timeline),
          intensity:
            length(timeline) /
              max(
                1,
                DateTime.diff(List.last(timeline).timestamp, List.first(timeline).timestamp) / 60
              )
        }
      ]

      detailed_phases
      |> Enum.with_index()
      |> Enum.map(fn {phase, index} ->
        # Determine phase type based on position and characteristics
        phase_type = determine_phase_type(phase, index, length(detailed_phases))

        # Calculate additional metrics
        dominant_side = calculate_dominant_side_for_phase(timeline, phase)
        key_events = identify_key_events_in_phase(timeline, phase)

        %{
          phase_type: phase_type,
          start_time: phase.start_time,
          end_time: phase.end_time,
          duration_seconds: phase.duration_seconds,
          kills_in_phase: phase.kills,
          dominant_side: dominant_side,
          intensity_rating: classify_intensity_rating(phase.intensity),
          key_events: key_events,
          phase_number: phase.phase_number
        }
      end)
    end
  end

  # Determine the type of battle phase based on position and characteristics
  defp determine_phase_type(phase, index, total_phases) do
    cond do
      # Single phase battle
      total_phases == 1 -> :single_engagement
      # First phase is usually engagement
      index == 0 -> :initial_engagement
      # Last phase is usually withdrawal/cleanup
      index == total_phases - 1 -> :withdrawal
      # Middle phases depend on intensity
      phase.intensity > 2.0 -> :escalation
      phase.intensity > 1.0 -> :sustained_combat
      true -> :lull
    end
  end

  # Calculate which side was dominant during a specific phase
  defp calculate_dominant_side_for_phase(timeline, phase) do
    phase_events =
      Enum.filter(timeline, fn event ->
        DateTime.compare(event.timestamp, phase.start_time) != :lt and
          DateTime.compare(event.timestamp, phase.end_time) != :gt
      end)

    if Enum.empty?(phase_events) do
      :unknown
    else
      # Count kills by side (simplified - would need proper side determination)
      side_kills =
        phase_events
        |> Enum.map(fn event ->
          # Use corporation/alliance to determine side (simplified)
          determine_side(event.victim_corporation_id, event.victim_alliance_id)
        end)
        |> Enum.frequencies()

      case Enum.max_by(side_kills, &elem(&1, 1), fn -> {:unknown, 0} end) do
        {:unknown, _} -> :balanced
        {side, _count} -> side
      end
    end
  end

  # Identify key events within a phase (high-value kills, escalations)
  defp identify_key_events_in_phase(timeline, phase) do
    phase_events =
      Enum.filter(timeline, fn event ->
        DateTime.compare(event.timestamp, phase.start_time) != :lt and
          DateTime.compare(event.timestamp, phase.end_time) != :gt
      end)

    phase_events
    |> Enum.filter(fn event ->
      # Consider an event "key" if it meets certain criteria
      high_value_kill?(event) or
        capital_ship_kill?(event) or
        commander_kill?(event)
    end)
    |> Enum.map(fn event ->
      %{
        timestamp: event.timestamp,
        event_type: determine_event_type(event),
        value: event.total_value || 0,
        ship_class: classify_ship(event.victim_ship_type_id),
        description: generate_event_description(event)
      }
    end)
    |> Enum.sort_by(& &1.timestamp)
  end

  # Classify intensity rating from kills per minute
  defp classify_intensity_rating(intensity) when is_number(intensity) do
    cond do
      # 5+ kills per minute
      intensity >= 5.0 -> :very_high
      # 3-5 kills per minute
      intensity >= 3.0 -> :high
      # 1.5-3 kills per minute
      intensity >= 1.5 -> :moderate
      # 0.5-1.5 kills per minute
      intensity >= 0.5 -> :low
      # <0.5 kills per minute
      true -> :very_low
    end
  end

  defp classify_intensity_rating(_), do: :unknown

  # Check if this is a high-value kill (>500M ISK)
  defp high_value_kill?(event) do
    (event.total_value || 0) > 500_000_000
  end

  # Check if this is a capital ship kill
  defp capital_ship_kill?(event) do
    ship_class = classify_ship(event.victim_ship_type_id)
    ship_class in [:dreadnought, :carrier, :supercarrier, :titan, :force_auxiliary]
  end

  # Check if this might be a commander/FC kill (simplified heuristic)
  defp commander_kill?(event) do
    ship_class = classify_ship(event.victim_ship_type_id)
    # Command ships, T3 cruisers, or expensive ships that might be FC ships
    ship_class in [:command_ship, :strategic_cruiser] or
      (event.total_value || 0) > 1_000_000_000
  end

  # Determine the type of key event
  defp determine_event_type(event) do
    cond do
      capital_ship_kill?(event) -> :capital_kill
      commander_kill?(event) -> :potential_fc_kill
      high_value_kill?(event) -> :high_value_kill
      true -> :significant_kill
    end
  end

  # Generate a human-readable description of the event
  defp generate_event_description(event) do
    ship_class = classify_ship(event.victim_ship_type_id)
    value_formatted = format_isk_value(event.total_value || 0)

    "#{String.capitalize(to_string(ship_class))} destroyed (#{value_formatted})"
  end

  # Format ISK values for display
  defp format_isk_value(value) when value >= 1_000_000_000 do
    "#{Float.round(value / 1_000_000_000, 1)}B ISK"
  end

  defp format_isk_value(value) when value >= 1_000_000 do
    "#{Float.round(value / 1_000_000, 1)}M ISK"
  end

  defp format_isk_value(value) do
    "#{Float.round(value / 1_000, 0)}K ISK"
  end

  defp determine_side(corporation_id, alliance_id) do
    # Improved logic to determine which side a participant is on
    # Uses alliance/corporation hierarchy and attack patterns

    cond do
      # If part of major alliance, use alliance as primary identifier
      alliance_id != nil and alliance_id != 0 ->
        determine_side_by_alliance(alliance_id)

      # If no alliance, use corporation
      corporation_id != nil and corporation_id != 0 ->
        determine_side_by_corporation(corporation_id)

      # Fallback for unknown entities
      true ->
        :unknown
    end
  end

  defp classify_ship(ship_type_id) do
    # Classify ship based on type ID ranges (simplified EVE ship classification)
    cond do
      # Frigates
      ship_type_id in [582, 583, 584, 585, 586, 587, 588, 589] -> :frigate
      # Destroyers
      ship_type_id in [16_236, 16_238, 16_240, 16_242] -> :destroyer
      # Cruisers
      ship_type_id in [620, 621, 622, 623, 624, 625, 626, 627] -> :cruiser
      # Battlecruisers
      ship_type_id in [16_227, 16_229, 16_231, 16_233] -> :battlecruiser
      # Battleships
      ship_type_id in [638, 639, 640, 641, 642, 643, 644, 645] -> :battleship
      # Strategic Cruisers (T3C)
      ship_type_id in [29_984, 29_986, 29_988, 29_990] -> :strategic_cruiser
      # Logistics Cruisers
      ship_type_id in [11_985, 11_987, 11_989, 12_003] -> :logistics
      # Recon Ships
      ship_type_id in [11_957, 11_959, 11_961, 11_963] -> :recon
      # Heavy Assault Cruisers
      ship_type_id in [11_991, 12_005, 11_993, 11_995] -> :heavy_assault_cruiser
      # Capital ships
      ship_type_id > 20_000 and ship_type_id < 30_000 -> :capital
      # Default
      true -> :unknown
    end
  end

  defp analyze_side_ship_composition(participants) do
    participants
    |> Enum.flat_map(&MapSet.to_list(&1.ships_used))
    |> Enum.frequencies()
  end

  defp detect_doctrine_usage(ship_composition) do
    # Detect common doctrine patterns based on ship composition
    if Enum.empty?(ship_composition) do
      %{
        detected_doctrines: [],
        confidence: 0.0,
        analysis: "No ship composition data available"
      }
    else
      # Analyze ship composition to detect doctrine patterns
      ship_analysis = analyze_ship_patterns(ship_composition)
      doctrine_matches = match_known_doctrines(ship_analysis)

      # Calculate overall confidence based on pattern strength
      overall_confidence = calculate_doctrine_confidence(doctrine_matches, ship_analysis)

      %{
        detected_doctrines: doctrine_matches,
        confidence: overall_confidence,
        analysis: generate_doctrine_analysis(doctrine_matches, ship_analysis),
        ship_composition_breakdown: ship_analysis.breakdown,
        total_ships: ship_analysis.total_ships,
        dominant_ship_classes: ship_analysis.dominant_classes
      }
    end
  end

  defp calculate_logistics_ratio(ship_composition) do
    # Calculate the ratio of logistics ships to total ships
    total_ships = Enum.sum(Map.values(ship_composition))

    if total_ships > 0 do
      logistics_ships =
        ship_composition
        |> Enum.filter(fn {ship_type_id, _count} ->
          classify_ship(ship_type_id) == :logistics
        end)
        |> Enum.map(fn {_, count} -> count end)
        |> Enum.sum()

      Float.round(logistics_ships / total_ships, 3)
    else
      0.0
    end
  end

  defp detect_ewar_presence(ship_composition) do
    # Detect electronic warfare ships using static ship data
    if Enum.empty?(ship_composition) do
      %{
        ewar_detected: false,
        ewar_ships: [],
        ewar_types: [],
        ewar_intensity: 0.0,
        analysis: "No ship composition data available for EWAR analysis"
      }
    else
      # Analyze all ships in the composition for EWAR capabilities
      all_ships = extract_all_ships_from_composition(ship_composition)
      ewar_analysis = analyze_ships_for_ewar(all_ships)

      # Calculate EWAR intensity based on ship count and types
      ewar_intensity = calculate_ewar_intensity(ewar_analysis, length(all_ships))

      %{
        ewar_detected: length(ewar_analysis.ewar_ships) > 0,
        ewar_ships: ewar_analysis.ewar_ships,
        ewar_types: ewar_analysis.ewar_types,
        ewar_intensity: ewar_intensity,
        total_ewar_ships: length(ewar_analysis.ewar_ships),
        ewar_percentage: calculate_ewar_percentage(ewar_analysis.ewar_ships, all_ships),
        analysis: generate_ewar_analysis(ewar_analysis, ewar_intensity),
        detailed_breakdown: ewar_analysis.breakdown
      }
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

  defp predict_engagement_outcome(_engagement) do
    # Simple prediction based on current kill ratio
    %{
      likely_winner: :undetermined,
      confidence: :low
    }
  end

  defp calculate_timeline_duration(timeline) do
    if Enum.empty?(timeline) do
      0
    else
      first = List.first(timeline)
      last = List.last(timeline)
      DateTime.diff(last.timestamp, first.timestamp)
    end
  end

  defp track_participant_flow(timeline) do
    # Track when participants join/leave battle by analyzing their activity patterns
    if length(timeline) < 2 do
      %{
        joiners: [],
        leavers: [],
        flow_summary: %{
          total_joiners: 0,
          total_leavers: 0,
          peak_participants: 0,
          average_participants: 0,
          participation_stability: :stable
        }
      }
    else
      # Sort timeline by time for analysis
      sorted_timeline = Enum.sort_by(timeline, & &1.killmail_time)

      # Create time windows for participant tracking (2-minute intervals)
      start_time = List.first(sorted_timeline).killmail_time
      end_time = List.last(sorted_timeline).killmail_time
      # 2-minute intervals
      time_windows = create_participant_tracking_windows(start_time, end_time, 120)

      # Track participants in each window
      window_participants =
        time_windows
        |> Enum.map(fn {window_start, window_end} ->
          participants_in_window =
            sorted_timeline
            |> Enum.filter(fn km ->
              kill_time = km.killmail_time

              NaiveDateTime.compare(kill_time, window_start) in [:eq, :gt] and
                NaiveDateTime.compare(kill_time, window_end) == :lt
            end)
            |> Enum.flat_map(fn km ->
              victim_id = if km.victim_character_id, do: [km.victim_character_id], else: []
              
              attacker_ids =
                case km.raw_data do
                  %{"attackers" => attackers} when is_list(attackers) ->
                    attackers
                    |> Enum.map(fn attacker -> attacker["character_id"] end)
                    |> Enum.filter(&(&1 != nil))

                  _ ->
                    []
                end

              victim_id ++ attacker_ids
            end)
            |> Enum.uniq()

          %{
            window_start: window_start,
            window_end: window_end,
            participants: participants_in_window,
            participant_count: length(participants_in_window)
          }
        end)
        |> Enum.filter(fn window -> window.participant_count > 0 end)

      # Analyze participant flow between windows
      flow_analysis = analyze_participant_flow_between_windows(window_participants)

      # Generate summary statistics
      flow_summary = generate_participation_flow_summary(window_participants, flow_analysis)

      %{
        joiners: flow_analysis.joiners,
        leavers: flow_analysis.leavers,
        flow_events: flow_analysis.flow_events,
        participant_windows: window_participants,
        flow_summary: flow_summary
      }
    end
  end

  defp identify_common_patterns(battle_analyses) do
    # Identify common tactical patterns across multiple battles
    if length(battle_analyses) < 2 do
      []
    else
      # Extract patterns from each battle
      all_patterns =
        battle_analyses
        |> Enum.flat_map(fn analysis ->
          extract_patterns_from_battle(analysis)
        end)
        |> Enum.group_by(& &1.pattern_type)

      # Find patterns that appear in multiple battles
      common_patterns =
        all_patterns
        |> Enum.map(fn {pattern_type, instances} ->
          if length(instances) >= 2 do
            %{
              pattern_type: pattern_type,
              occurrences: length(instances),
              frequency: Float.round(length(instances) / length(battle_analyses) * 100, 1),
              examples: Enum.take(instances, 3),
              confidence: calculate_pattern_confidence(instances)
            }
          else
            nil
          end
        end)
        |> Enum.filter(&(&1 != nil))
        |> Enum.sort_by(& &1.frequency, :desc)

      common_patterns
    end
  end

  defp analyze_tactical_evolution(battle_analyses) do
    # Analyze how tactics and ship usage evolve across multiple battles
    if length(battle_analyses) < 2 do
      %{
        evolution_detected: false,
        message: "Need at least 2 battles to analyze tactical evolution",
        trends: []
      }
    else
      # Sort battles by time to analyze chronological evolution
      sorted_battles =
        Enum.sort_by(battle_analyses, fn analysis ->
          case analysis do
            %{start_time: time} -> time
            %{timestamp: time} -> time
            _ -> ~N[1970-01-01 00:00:00]
          end
        end)

      # Analyze various tactical trends
      doctrine_evolution = analyze_doctrine_evolution(sorted_battles)
      ship_composition_trends = analyze_ship_composition_trends(sorted_battles)
      engagement_pattern_evolution = analyze_engagement_pattern_evolution(sorted_battles)
      tactical_adaptation = analyze_tactical_adaptation(sorted_battles)

      %{
        evolution_detected: true,
        total_battles_analyzed: length(sorted_battles),
        time_span: calculate_analysis_timespan(sorted_battles),
        doctrine_evolution: doctrine_evolution,
        ship_composition_trends: ship_composition_trends,
        engagement_patterns: engagement_pattern_evolution,
        tactical_adaptations: tactical_adaptation,
        summary:
          generate_evolution_summary(
            doctrine_evolution,
            ship_composition_trends,
            engagement_pattern_evolution
          )
      }
    end
  end

  defp compare_effectiveness_trends(battle_analyses) do
    # Compare effectiveness trends across battles
    if length(battle_analyses) < 2 do
      %{trend: :insufficient_data}
    else
      # Extract effectiveness metrics from each battle
      effectiveness_data =
        battle_analyses
        |> Enum.with_index()
        |> Enum.map(fn {analysis, index} ->
          %{
            battle_index: index,
            timestamp: extract_battle_timestamp(analysis),
            kill_efficiency: extract_kill_efficiency(analysis),
            isk_efficiency: extract_isk_efficiency(analysis),
            tactical_success: calculate_tactical_success(analysis),
            strategic_impact: calculate_strategic_impact(analysis)
          }
        end)

      # Calculate trends
      kill_efficiency_trend = calculate_metric_trend(effectiveness_data, :kill_efficiency)
      isk_efficiency_trend = calculate_metric_trend(effectiveness_data, :isk_efficiency)
      tactical_trend = calculate_metric_trend(effectiveness_data, :tactical_success)
      strategic_trend = calculate_metric_trend(effectiveness_data, :strategic_impact)

      %{
        timeline: effectiveness_data,
        kill_efficiency_trend: kill_efficiency_trend,
        isk_efficiency_trend: isk_efficiency_trend,
        tactical_success_trend: tactical_trend,
        strategic_impact_trend: strategic_trend,
        overall_effectiveness_direction:
          determine_overall_effectiveness_trend([
            kill_efficiency_trend,
            isk_efficiency_trend,
            tactical_trend,
            strategic_trend
          ])
      }
    end
  end

  defp compare_doctrine_usage(battle_analyses) do
    # Compare doctrine usage patterns across battles
    if length(battle_analyses) < 2 do
      %{comparison: :insufficient_data}
    else
      # Extract doctrine data from each battle
      doctrine_timeline =
        battle_analyses
        |> Enum.with_index()
        |> Enum.map(fn {analysis, index} ->
          doctrines = extract_doctrines_from_battle(analysis)

          %{
            battle_index: index,
            timestamp: extract_battle_timestamp(analysis),
            primary_doctrines: doctrines,
            doctrine_count: length(doctrines),
            doctrine_diversity: calculate_doctrine_diversity(doctrines),
            dominant_doctrine: find_dominant_doctrine(doctrines)
          }
        end)

      # Analyze doctrine evolution
      doctrine_stability = calculate_doctrine_usage_stability(doctrine_timeline)
      doctrine_effectiveness = analyze_doctrine_effectiveness(doctrine_timeline, battle_analyses)

      %{
        timeline: doctrine_timeline,
        stability_score: doctrine_stability,
        effectiveness_analysis: doctrine_effectiveness,
        most_used_doctrines: identify_most_used_doctrines(doctrine_timeline),
        doctrine_success_rates:
          calculate_doctrine_success_rates(doctrine_timeline, battle_analyses),
        evolution_pattern: determine_doctrine_evolution_pattern(doctrine_timeline)
      }
    end
  end

  defp fetch_entity_battles(_entity_id, _entity_type, _time_range) do
    {:ok, []}
  end

  defp analyze_entity_performance(entity_id, entity_type, battles) do
    {:ok,
     %{
       entity_id: entity_id,
       entity_type: entity_type,
       battle_count: length(battles),
       win_rate: 0.0,
       average_efficiency: 100.0,
       preferred_doctrines: [],
       performance_trend: :stable
     }}
  end








  # Helper functions for participant flow tracking

  defp create_participant_tracking_windows(start_time, end_time, interval_seconds) do
    # Create time windows optimized for participant tracking
    duration_seconds = NaiveDateTime.diff(end_time, start_time, :second)

    # Use minimum of 2 windows even for very short battles
    bucket_count = max(2, div(duration_seconds, interval_seconds))

    0..(bucket_count - 1)
    |> Enum.map(fn bucket_index ->
      bucket_start = NaiveDateTime.add(start_time, bucket_index * interval_seconds, :second)
      bucket_end = NaiveDateTime.add(start_time, (bucket_index + 1) * interval_seconds, :second)

      # Ensure the last bucket covers until the actual end time
      bucket_end =
        if NaiveDateTime.compare(bucket_end, end_time) == :gt, do: end_time, else: bucket_end

      {bucket_start, bucket_end}
    end)
  end

  defp analyze_participant_flow_between_windows(window_participants) do
    # Compare consecutive windows to identify joiners and leavers

    {joiners, leavers, flow_events} =
      window_participants
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce({[], [], []}, fn [prev_window, curr_window],
                                      {acc_joiners, acc_leavers, acc_events} ->
        prev_participants = MapSet.new(prev_window.participants)
        curr_participants = MapSet.new(curr_window.participants)

        # Find new participants (joiners)
        new_participants = MapSet.difference(curr_participants, prev_participants)

        # Find departed participants (leavers)
        departed_participants = MapSet.difference(prev_participants, curr_participants)

        # Create flow events if there are significant changes
        flow_event =
          if MapSet.size(new_participants) > 0 or MapSet.size(departed_participants) > 0 do
            %{
              timestamp: curr_window.window_start,
              window_transition:
                "#{format_timestamp(prev_window.window_start)} -> #{format_timestamp(curr_window.window_start)}",
              joiners_count: MapSet.size(new_participants),
              leavers_count: MapSet.size(departed_participants),
              net_change: MapSet.size(new_participants) - MapSet.size(departed_participants),
              joiners: MapSet.to_list(new_participants),
              leavers: MapSet.to_list(departed_participants),
              flow_type:
                determine_flow_type(
                  MapSet.size(new_participants),
                  MapSet.size(departed_participants)
                )
            }
          else
            nil
          end

        # Create joiner records
        new_joiner_records =
          new_participants
          |> MapSet.to_list()
          |> Enum.map(fn participant_id ->
            %{
              participant_id: participant_id,
              joined_at: curr_window.window_start,
              join_window: curr_window.window_start,
              context: %{
                participants_before: MapSet.size(prev_participants),
                participants_after: MapSet.size(curr_participants)
              }
            }
          end)

        # Create leaver records
        new_leaver_records =
          departed_participants
          |> MapSet.to_list()
          |> Enum.map(fn participant_id ->
            %{
              participant_id: participant_id,
              left_at: curr_window.window_start,
              leave_window: prev_window.window_start,
              context: %{
                participants_before: MapSet.size(prev_participants),
                participants_after: MapSet.size(curr_participants)
              }
            }
          end)

        updated_events = if flow_event, do: [flow_event | acc_events], else: acc_events

        {acc_joiners ++ new_joiner_records, acc_leavers ++ new_leaver_records, updated_events}
      end)

    %{
      joiners: Enum.reverse(joiners),
      leavers: Enum.reverse(leavers),
      flow_events: Enum.reverse(flow_events)
    }
  end

  defp generate_participation_flow_summary(window_participants, flow_analysis) do
    # Calculate summary statistics for participant flow
    participant_counts = Enum.map(window_participants, & &1.participant_count)

    peak_participants =
      if Enum.empty?(participant_counts), do: 0, else: Enum.max(participant_counts)

    average_participants =
      if Enum.empty?(participant_counts) do
        0
      else
        Float.round(Enum.sum(participant_counts) / length(participant_counts), 1)
      end

    # Calculate participation stability
    participation_stability = calculate_participation_stability(participant_counts)

    # Analyze flow patterns
    flow_pattern = analyze_flow_pattern(flow_analysis.flow_events)

    %{
      total_joiners: length(flow_analysis.joiners),
      total_leavers: length(flow_analysis.leavers),
      peak_participants: peak_participants,
      average_participants: average_participants,
      participation_stability: participation_stability,
      flow_pattern: flow_pattern,
      net_participant_change: length(flow_analysis.joiners) - length(flow_analysis.leavers),
      most_active_period: identify_most_active_period(window_participants),
      flow_events_count: length(flow_analysis.flow_events)
    }
  end

  defp determine_flow_type(joiners_count, leavers_count) do
    cond do
      joiners_count > 0 and leavers_count == 0 -> :escalation
      joiners_count == 0 and leavers_count > 0 -> :de_escalation
      joiners_count > leavers_count -> :net_escalation
      leavers_count > joiners_count -> :net_de_escalation
      joiners_count > 0 and leavers_count > 0 -> :turnover
      true -> :stable
    end
  end

  defp calculate_participation_stability(participant_counts) do
    if length(participant_counts) < 2 do
      :stable
    else
      # Calculate coefficient of variation
      mean = Enum.sum(participant_counts) / length(participant_counts)

      if mean == 0 do
        :stable
      else
        variance =
          participant_counts
          |> Enum.map(fn count -> :math.pow(count - mean, 2) end)
          |> Enum.sum()
          |> Kernel./(length(participant_counts))

        std_dev = :math.sqrt(variance)
        coefficient_of_variation = std_dev / mean

        cond do
          coefficient_of_variation < 0.1 -> :very_stable
          coefficient_of_variation < 0.2 -> :stable
          coefficient_of_variation < 0.4 -> :moderately_volatile
          coefficient_of_variation < 0.6 -> :volatile
          true -> :very_volatile
        end
      end
    end
  end

  defp analyze_flow_pattern(flow_events) do
    if Enum.empty?(flow_events) do
      :no_flow
    else
      # Analyze dominant flow types
      flow_types = Enum.map(flow_events, & &1.flow_type)
      flow_type_counts = Enum.frequencies(flow_types)

      # Get the most common flow type
      dominant_flow =
        flow_type_counts
        |> Enum.max_by(fn {_type, count} -> count end, fn -> {:stable, 0} end)
        |> elem(0)

      # Check for patterns
      cond do
        # Early escalation followed by stability
        Enum.take(flow_types, 2) == [:escalation, :stable] -> :early_escalation
        # Late escalation
        List.last(flow_types) == :escalation -> :late_escalation
        # Early de-escalation
        List.first(flow_types) == :de_escalation -> :early_withdrawal
        # Alternating flows
        length(Enum.uniq(flow_types)) > 2 -> :complex_flow
        # Dominant pattern
        true -> dominant_flow
      end
    end
  end

  defp identify_most_active_period(window_participants) do
    if Enum.empty?(window_participants) do
      nil
    else
      most_active_window =
        window_participants
        |> Enum.max_by(& &1.participant_count, fn -> nil end)

      if most_active_window do
        %{
          period:
            "#{format_timestamp(most_active_window.window_start)} - #{format_timestamp(most_active_window.window_end)}",
          participant_count: most_active_window.participant_count,
          timestamp: most_active_window.window_start
        }
      else
        nil
      end
    end
  end

  defp format_timestamp(naive_datetime) do
    # Format timestamp for display
    naive_datetime
    |> NaiveDateTime.to_time()
    |> Time.to_string()
    # HH:MM:SS format
    |> String.slice(0, 8)
  end

  # Helper functions for doctrine detection

  defp analyze_ship_patterns(ship_composition) do
    # Convert ship composition to analyzable format
    ship_data =
      ship_composition
      |> Enum.flat_map(fn {_side, side_data} ->
        case side_data do
          %{ships: ships} when is_list(ships) -> ships
          ships when is_list(ships) -> ships
          _ -> []
        end
      end)

    # Group ships by class and analyze patterns
    ship_classes = group_ships_by_class(ship_data)
    total_ships = Enum.sum(Enum.map(ship_classes, fn {_class, ships} -> length(ships) end))

    # Calculate ship class percentages
    class_percentages =
      ship_classes
      |> Enum.map(fn {class, ships} ->
        percentage = if total_ships > 0, do: length(ships) / total_ships * 100, else: 0
        {class, %{count: length(ships), percentage: Float.round(percentage, 1)}}
      end)
      |> Map.new()

    # Identify dominant ship classes (>20% of fleet)
    dominant_classes =
      class_percentages
      |> Enum.filter(fn {_class, data} -> data.percentage > 20 end)
      |> Enum.map(fn {class, _data} -> class end)

    # Analyze support ships and special roles
    support_analysis = analyze_support_ships(ship_classes)

    %{
      breakdown: class_percentages,
      total_ships: total_ships,
      dominant_classes: dominant_classes,
      support_analysis: support_analysis,
      ship_diversity: calculate_ship_diversity_score(class_percentages)
    }
  end

  defp group_ships_by_class(ship_data) do
    ship_data
    |> Enum.group_by(&classify_ship_by_type_id/1)
    |> Map.delete(:unknown)
  end

  defp classify_ship_by_type_id(ship) do
    # Get ship type ID - handle different data structures
    ship_type_id =
      case ship do
        %{victim_ship_type_id: id} -> id
        %{ship_type_id: id} -> id
        %{"ship_type_id" => id} -> id
        id when is_integer(id) -> id
        _ -> nil
      end

    classify_ship_type_id(ship_type_id)
  end

  defp classify_ship_type_id(ship_type_id) when is_integer(ship_type_id) do
    cond do
      # Frigates
      ship_type_id in 580..700 -> :frigate
      # Assault Frigates
      ship_type_id in 11_365..11_378 -> :assault_frigate
      # Interceptors
      ship_type_id in 11_177..11_190 -> :interceptor
      # Destroyers
      ship_type_id in 420..450 -> :destroyer
      # Interdictors
      ship_type_id in 22_440..22_460 -> :interdictor
      # Cruisers
      ship_type_id in 620..650 -> :cruiser
      # Heavy Assault Cruisers
      ship_type_id in 12_017..12_030 -> :heavy_assault_cruiser
      # Heavy Interdictors
      ship_type_id in 12_011..12_016 -> :heavy_interdictor
      # Logistics Cruisers
      ship_type_id in 11_987..11_995 -> :logistics_cruiser
      # Recon Ships
      ship_type_id in 11_957..11_971 -> :recon_ship
      # Battlecruisers
      ship_type_id in 540..570 -> :battlecruiser
      # Command Ships
      ship_type_id in 12_003..12_010 -> :command_ship
      # Battleships
      ship_type_id in 640..670 -> :battleship
      # Marauders
      ship_type_id in 28_659..28_665 -> :marauder
      # Black Ops
      ship_type_id in 22_440..22_456 -> :black_ops
      # Carriers
      ship_type_id in 547..554 -> :carrier
      # Dreadnoughts
      ship_type_id in 19_720..19_726 -> :dreadnought
      # Force Auxiliaries
      ship_type_id in 1_538..1_540 -> :force_auxiliary
      # Supercarriers
      ship_type_id in 23_757..23_773 -> :supercarrier
      # Titans
      ship_type_id in 3514..3518 -> :titan
      # Industrial Ships
      ship_type_id in 1_022..1_034 -> :industrial
      # T3 Cruisers
      ship_type_id in 29_984..29_990 -> :strategic_cruiser
      # Default fallback
      true -> :other
    end
  end

  defp classify_ship_type_id(_), do: :unknown

  defp analyze_support_ships(ship_classes) do
    # Analyze presence of support and specialized ships
    logistics_count = Map.get(ship_classes, :logistics_cruiser, []) |> length()
    recon_count = Map.get(ship_classes, :recon_ship, []) |> length()
    interdictor_count = Map.get(ship_classes, :interdictor, []) |> length()
    heavy_interdictor_count = Map.get(ship_classes, :heavy_interdictor, []) |> length()
    command_count = Map.get(ship_classes, :command_ship, []) |> length()

    %{
      logistics_ships: logistics_count,
      ewar_ships: recon_count,
      tackle_ships: interdictor_count + heavy_interdictor_count,
      command_ships: command_count,
      has_logistics: logistics_count > 0,
      has_ewar: recon_count > 0,
      has_tackle: interdictor_count + heavy_interdictor_count > 0,
      support_ratio: calculate_support_ratio(ship_classes)
    }
  end

  defp calculate_support_ratio(ship_classes) do
    # Calculate ratio of support ships to total fleet
    support_ships = [
      :logistics_cruiser,
      :recon_ship,
      :interdictor,
      :heavy_interdictor,
      :command_ship
    ]

    support_count =
      support_ships
      |> Enum.map(fn class -> Map.get(ship_classes, class, []) |> length() end)
      |> Enum.sum()

    total_ships =
      ship_classes
      |> Map.values()
      |> Enum.map(&length/1)
      |> Enum.sum()

    if total_ships > 0 do
      Float.round(support_count / total_ships * 100, 1)
    else
      0.0
    end
  end

  defp calculate_ship_diversity_score(class_percentages) do
    # Calculate Shannon diversity index for ship composition
    if Enum.empty?(class_percentages) do
      0.0
    else
      percentages =
        class_percentages
        |> Map.values()
        |> Enum.map(& &1.percentage/100)
        |> Enum.filter(&(&1 > 0))

      if Enum.empty?(percentages) do
        0.0
      else
        diversity =
          percentages
          |> Enum.map(fn p -> -p * :math.log2(p) end)
          |> Enum.sum()

        Float.round(diversity, 2)
      end
    end
  end

  defp match_known_doctrines(ship_analysis) do
    # Match against known EVE Online doctrine patterns
    doctrines = []

    # Analyze for common doctrines based on dominant ship classes
    doctrines = doctrines ++ analyze_capital_doctrines(ship_analysis)
    doctrines = doctrines ++ analyze_subcap_doctrines(ship_analysis)
    doctrines = doctrines ++ analyze_specialized_doctrines(ship_analysis)

    # Sort by confidence score
    doctrines
    |> Enum.sort_by(& &1.confidence, :desc)
    # Return top 3 matches
    |> Enum.take(3)
  end

  defp analyze_capital_doctrines(ship_analysis) do
    class_data = ship_analysis.breakdown
    initial_doctrines = []

    # Dreadnought doctrine
    dread_percentage = get_class_percentage(class_data, :dreadnought)

    doctrines_with_dread =
      if dread_percentage > 30 do
        [
          %{
            name: "Capital Dreadnought Doctrine",
            type: :capital,
            confidence: min(100, dread_percentage * 2),
            characteristics: ["High alpha damage", "Siege warfare", "Structure bashing"],
            key_ships: [:dreadnought, :force_auxiliary, :carrier]
          }
          | initial_doctrines
        ]
      else
        initial_doctrines
      end

    # Carrier doctrine
    carrier_percentage = get_class_percentage(class_data, :carrier)

    final_doctrines =
      if carrier_percentage > 25 do
        [
          %{
            name: "Carrier Doctrine",
            type: :capital,
            confidence: min(100, carrier_percentage * 2.5),
            characteristics: ["Fighter DPS", "Remote repair", "Area denial"],
            key_ships: [:carrier, :supercarrier, :force_auxiliary]
          }
          | doctrines_with_dread
        ]
      else
        doctrines_with_dread
      end

    final_doctrines
  end

  defp analyze_subcap_doctrines(ship_analysis) do
    class_data = ship_analysis.breakdown
    support = ship_analysis.support_analysis
    initial_doctrines = []

    # Battleship doctrine
    bs_percentage = get_class_percentage(class_data, :battleship)

    doctrines_with_bs =
      if bs_percentage > 40 do
        doctrine_name =
          if support.has_logistics, do: "Armor/Shield BS Doctrine", else: "Buffer BS Doctrine"

        [
          %{
            name: doctrine_name,
            type: :subcap,
            confidence: min(100, bs_percentage * 2),
            characteristics: ["High EHP", "Long range DPS", "Slow movement"],
            key_ships: [:battleship, :logistics_cruiser, :command_ship]
          }
          | initial_doctrines
        ]
      else
        initial_doctrines
      end

    # HAC doctrine
    hac_percentage = get_class_percentage(class_data, :heavy_assault_cruiser)

    doctrines_with_hac =
      if hac_percentage > 35 do
        [
          %{
            name: "Heavy Assault Cruiser Doctrine",
            type: :subcap,
            confidence: min(100, hac_percentage * 2.2),
            characteristics: ["Balanced mobility/tank", "Versatile engagement"],
            key_ships: [:heavy_assault_cruiser, :logistics_cruiser, :recon_ship]
          }
          | doctrines_with_bs
        ]
      else
        doctrines_with_bs
      end

    # Cruiser doctrine
    cruiser_percentage = get_class_percentage(class_data, :cruiser)

    final_doctrines =
      if cruiser_percentage > 50 do
        [
          %{
            name: "Fast Cruiser Doctrine",
            type: :subcap,
            confidence: min(100, cruiser_percentage * 1.5),
            characteristics: ["High mobility", "Quick engagement/disengagement"],
            key_ships: [:cruiser, :logistics_cruiser, :interceptor]
          }
          | doctrines_with_hac
        ]
      else
        doctrines_with_hac
      end

    final_doctrines
  end

  defp analyze_specialized_doctrines(ship_analysis) do
    class_data = ship_analysis.breakdown
    support = ship_analysis.support_analysis
    initial_doctrines = []

    # Kiting doctrine (interceptors + long range)
    interceptor_percentage = get_class_percentage(class_data, :interceptor)

    doctrines_with_kiting =
      if interceptor_percentage > 30 do
        [
          %{
            name: "Kiting/Skirmish Doctrine",
            type: :specialized,
            confidence: min(100, interceptor_percentage * 2),
            characteristics: ["High speed", "Hit and run", "Range control"],
            key_ships: [:interceptor, :assault_frigate, :recon_ship]
          }
          | initial_doctrines
        ]
      else
        initial_doctrines
      end

    # Blops doctrine
    blops_percentage = get_class_percentage(class_data, :black_ops)

    doctrines_with_blops =
      if blops_percentage > 20 do
        [
          %{
            name: "Black Ops Doctrine",
            type: :specialized,
            confidence: min(100, blops_percentage * 3),
            characteristics: ["Stealth", "Portal capability", "Surprise attacks"],
            key_ships: [:black_ops, :recon_ship, :stealth_bomber]
          }
          | doctrines_with_kiting
        ]
      else
        doctrines_with_kiting
      end

    # Support-heavy doctrine
    final_doctrines =
      if support.support_ratio > 40 do
        [
          %{
            name: "Support-Heavy Doctrine",
            type: :specialized,
            confidence: min(100, support.support_ratio * 1.5),
            characteristics: ["High survivability", "Force multiplication", "Sustained fighting"],
            key_ships: [:logistics_cruiser, :command_ship, :heavy_interdictor]
          }
          | doctrines_with_blops
        ]
      else
        doctrines_with_blops
      end

    final_doctrines
  end

  defp get_class_percentage(class_data, ship_class) do
    case Map.get(class_data, ship_class) do
      %{percentage: percentage} -> percentage
      _ -> 0.0
    end
  end

  defp calculate_doctrine_confidence(doctrine_matches, ship_analysis) do
    if Enum.empty?(doctrine_matches) do
      0.0
    else
      # Weight confidence by ship diversity and support presence
      base_confidence =
        doctrine_matches
        |> Enum.map(& &1.confidence)
        |> Enum.max()

      # Adjust for ship diversity (higher diversity = lower confidence in single doctrine)
      diversity_penalty = min(20, ship_analysis.ship_diversity * 5)

      # Bonus for proper support ships
      support_bonus = if ship_analysis.support_analysis.has_logistics, do: 10, else: 0

      adjusted_confidence = base_confidence - diversity_penalty + support_bonus
      max(0, min(100, adjusted_confidence))
    end
  end

  defp generate_doctrine_analysis(doctrine_matches, ship_analysis) do
    if Enum.empty?(doctrine_matches) do
      "No clear doctrine patterns detected. Fleet composition shows #{ship_analysis.ship_diversity} diversity score."
    else
      primary_doctrine = List.first(doctrine_matches)
      support_analysis = ship_analysis.support_analysis

      support_desc =
        cond do
          support_analysis.has_logistics and support_analysis.has_ewar ->
            "with full logistics and EWAR support"

          support_analysis.has_logistics ->
            "with logistics support"

          support_analysis.has_ewar ->
            "with EWAR support"

          true ->
            "with minimal support ships"
        end

      "Primary doctrine: #{primary_doctrine.name} (#{primary_doctrine.confidence}% confidence) #{support_desc}. " <>
        "Fleet composition: #{ship_analysis.total_ships} ships across #{length(ship_analysis.dominant_classes)} dominant classes."
    end
  end

  # Helper functions for EWAR detection

  defp extract_all_ships_from_composition(ship_composition) do
    # Extract all ships from various composition formats
    ship_composition
    |> Enum.flat_map(fn
      {_side, %{ships: ships}} when is_list(ships) -> ships
      {_side, ships} when is_list(ships) -> ships
      {_side, %{composition: ships}} when is_list(ships) -> ships
      ship when is_map(ship) -> [ship]
      _ -> []
    end)
  end

  defp analyze_ships_for_ewar(ships) do
    # Analyze each ship for EWAR capabilities
    ewar_ships = []
    ewar_types = MapSet.new()
    breakdown = %{}

    {ewar_ships, ewar_types, breakdown} =
      Enum.reduce(ships, {ewar_ships, ewar_types, breakdown}, fn ship,
                                                                 {acc_ships, acc_types,
                                                                  acc_breakdown} ->
        ewar_info = classify_ship_ewar_capability(ship)

        if ewar_info.has_ewar do
          updated_ships = [
            %{
              ship: ship,
              ewar_types: ewar_info.ewar_types,
              ewar_strength: ewar_info.ewar_strength,
              ship_class: ewar_info.ship_class
            }
            | acc_ships
          ]

          updated_types = MapSet.union(acc_types, MapSet.new(ewar_info.ewar_types))

          # Update breakdown by EWAR type
          updated_breakdown =
            Enum.reduce(ewar_info.ewar_types, acc_breakdown, fn ewar_type, breakdown_acc ->
              Map.update(breakdown_acc, ewar_type, 1, &(&1 + 1))
            end)

          {updated_ships, updated_types, updated_breakdown}
        else
          {acc_ships, acc_types, acc_breakdown}
        end
      end)

    %{
      ewar_ships: Enum.reverse(ewar_ships),
      ewar_types: MapSet.to_list(ewar_types),
      breakdown: breakdown
    }
  end

  defp classify_ship_ewar_capability(ship) do
    # Get ship type ID from various possible formats
    ship_type_id = extract_ship_type_id(ship)

    case ship_type_id do
      # Combat Recon Ships (Force Recon)
      11_957 ->
        %{
          has_ewar: true,
          ewar_types: [:sensor_dampening, :ecm],
          ewar_strength: :high,
          ship_class: :force_recon
        }

      11_958 ->
        %{
          has_ewar: true,
          ewar_types: [:tracking_disruption, :weapon_disruption],
          ewar_strength: :high,
          ship_class: :force_recon
        }

      11_959 ->
        %{
          has_ewar: true,
          ewar_types: [:target_painting, :tracking_disruption],
          ewar_strength: :high,
          ship_class: :force_recon
        }

      11_961 ->
        %{
          has_ewar: true,
          ewar_types: [:ecm, :ecm_burst],
          ewar_strength: :very_high,
          ship_class: :force_recon
        }

      # Combat Recon Ships (Covert Ops Recon)
      11_963 ->
        %{
          has_ewar: true,
          ewar_types: [:sensor_dampening, :tracking_disruption],
          ewar_strength: :medium,
          ship_class: :recon
        }

      11_965 ->
        %{
          has_ewar: true,
          ewar_types: [:tracking_disruption, :weapon_disruption],
          ewar_strength: :medium,
          ship_class: :recon
        }

      11_969 ->
        %{
          has_ewar: true,
          ewar_types: [:target_painting, :sensor_dampening],
          ewar_strength: :medium,
          ship_class: :recon
        }

      11_971 ->
        %{
          has_ewar: true,
          ewar_types: [:ecm, :sensor_dampening],
          ewar_strength: :high,
          ship_class: :recon
        }

      # Electronic Attack Ships (T2 Frigates)
      12_023 ->
        %{
          has_ewar: true,
          ewar_types: [:sensor_dampening],
          ewar_strength: :medium,
          ship_class: :eaf
        }

      12_024 ->
        %{
          has_ewar: true,
          ewar_types: [:tracking_disruption],
          ewar_strength: :medium,
          ship_class: :eaf
        }

      12_026 ->
        %{
          has_ewar: true,
          ewar_types: [:target_painting],
          ewar_strength: :medium,
          ship_class: :eaf
        }

      12_029 ->
        %{has_ewar: true, ewar_types: [:ecm], ewar_strength: :high, ship_class: :eaf}

      # Heavy Interdictors (Tackle + EWAR)
      12_011 ->
        %{
          has_ewar: true,
          ewar_types: [:warp_disruption, :sensor_dampening],
          ewar_strength: :medium,
          ship_class: :hic
        }

      12_013 ->
        %{
          has_ewar: true,
          ewar_types: [:warp_disruption, :tracking_disruption],
          ewar_strength: :medium,
          ship_class: :hic
        }

      12_014 ->
        %{
          has_ewar: true,
          ewar_types: [:warp_disruption, :target_painting],
          ewar_strength: :medium,
          ship_class: :hic
        }

      12_016 ->
        %{
          has_ewar: true,
          ewar_types: [:warp_disruption, :ecm],
          ewar_strength: :high,
          ship_class: :hic
        }

      # Command Ships (Fleet Bonuses + Some EWAR)
      12_003 ->
        %{
          has_ewar: true,
          ewar_types: [:command_bonuses, :sensor_dampening],
          ewar_strength: :low,
          ship_class: :command
        }

      12_004 ->
        %{
          has_ewar: true,
          ewar_types: [:command_bonuses, :tracking_disruption],
          ewar_strength: :low,
          ship_class: :command
        }

      12_006 ->
        %{
          has_ewar: true,
          ewar_types: [:command_bonuses, :target_painting],
          ewar_strength: :low,
          ship_class: :command
        }

      12_010 ->
        %{
          has_ewar: true,
          ewar_types: [:command_bonuses, :ecm],
          ewar_strength: :medium,
          ship_class: :command
        }

      # Some T1 cruisers commonly fitted for EWAR
      # Celestis
      621 ->
        %{
          has_ewar: true,
          ewar_types: [:sensor_dampening],
          ewar_strength: :low,
          ship_class: :cruiser
        }

      # Bellicose
      622 ->
        %{
          has_ewar: true,
          ewar_types: [:tracking_disruption],
          ewar_strength: :low,
          ship_class: :cruiser
        }

      # Vigil Fleet Issue
      623 ->
        %{
          has_ewar: true,
          ewar_types: [:target_painting],
          ewar_strength: :low,
          ship_class: :cruiser
        }

      # Blackbird
      631 ->
        %{has_ewar: true, ewar_types: [:ecm], ewar_strength: :medium, ship_class: :cruiser}

      # Interdictors (Tackle)
      22_440 ->
        %{
          has_ewar: true,
          ewar_types: [:warp_disruption],
          ewar_strength: :medium,
          ship_class: :interdictor
        }

      22_442 ->
        %{
          has_ewar: true,
          ewar_types: [:warp_disruption],
          ewar_strength: :medium,
          ship_class: :interdictor
        }

      22_444 ->
        %{
          has_ewar: true,
          ewar_types: [:warp_disruption],
          ewar_strength: :medium,
          ship_class: :interdictor
        }

      22_456 ->
        %{
          has_ewar: true,
          ewar_types: [:warp_disruption],
          ewar_strength: :medium,
          ship_class: :interdictor
        }

      # Some faction ships with EWAR bonuses
      17_636 ->
        %{
          has_ewar: true,
          ewar_types: [:sensor_dampening, :tracking_disruption],
          ewar_strength: :high,
          ship_class: :faction
        }

      17_718 ->
        %{
          has_ewar: true,
          ewar_types: [:ecm, :sensor_dampening],
          ewar_strength: :high,
          ship_class: :faction
        }

      # Default - no specific EWAR capability
      _ ->
        %{has_ewar: false, ewar_types: [], ewar_strength: :none, ship_class: :other}
    end
  end

  defp extract_ship_type_id(ship) do
    # Handle various ship data formats
    case ship do
      %{victim_ship_type_id: id} -> id
      %{ship_type_id: id} -> id
      %{"ship_type_id" => id} -> id
      %{"victim" => %{"ship_type_id" => id}} -> id
      id when is_integer(id) -> id
      _ -> nil
    end
  end

  defp calculate_ewar_intensity(ewar_analysis, total_ships) do
    if Enum.empty?(ewar_analysis.ewar_ships) or total_ships == 0 do
      0.0
    else
      # Calculate based on EWAR ship percentage and strength
      ewar_count = length(ewar_analysis.ewar_ships)
      ewar_percentage = ewar_count / total_ships

      # Weight by EWAR strength
      strength_bonus =
        ewar_analysis.ewar_ships
        |> Enum.map(fn ewar_ship ->
          case ewar_ship.ewar_strength do
            :very_high -> 2.0
            :high -> 1.5
            :medium -> 1.0
            :low -> 0.5
            _ -> 0.0
          end
        end)
        |> Enum.sum()
        |> Kernel./(ewar_count)

      # Calculate final intensity (0-100)
      base_intensity = ewar_percentage * 100
      weighted_intensity = base_intensity * strength_bonus

      Float.round(min(100, weighted_intensity), 1)
    end
  end

  defp calculate_ewar_percentage(ewar_ships, all_ships) do
    if Enum.empty?(all_ships) do
      0.0
    else
      percentage = length(ewar_ships) / length(all_ships) * 100
      Float.round(percentage, 1)
    end
  end

  defp generate_ewar_analysis(ewar_analysis, ewar_intensity) do
    if Enum.empty?(ewar_analysis.ewar_ships) do
      "No electronic warfare ships detected in fleet composition."
    else
      ewar_count = length(ewar_analysis.ewar_ships)
      ewar_types_str = Enum.join(ewar_analysis.ewar_types, ", ")

      # Analyze breakdown by ship class
      ship_classes =
        ewar_analysis.ewar_ships
        |> Enum.group_by(& &1.ship_class)
        |> Enum.map(fn {class, ships} -> "#{length(ships)} #{class}" end)
        |> Enum.join(", ")

      intensity_desc =
        cond do
          ewar_intensity >= 80 -> "very high"
          ewar_intensity >= 60 -> "high"
          ewar_intensity >= 40 -> "moderate"
          ewar_intensity >= 20 -> "low"
          true -> "minimal"
        end

      "#{ewar_count} EWAR ships detected with #{intensity_desc} intensity (#{ewar_intensity}%). " <>
        "Types: #{ewar_types_str}. Composition: #{ship_classes}."
    end
  end

  # Helper functions for improved side determination

  defp determine_side_by_alliance(alliance_id) do
    # Use a hash-based approach but ensure consistency within battle analysis
    # In production, this could use standings data or coalition information
    hash = :erlang.phash2(alliance_id)

    case rem(hash, 4) do
      0 -> :alliance_alpha
      1 -> :alliance_beta
      2 -> :alliance_gamma
      3 -> :alliance_delta
    end
  end

  defp determine_side_by_corporation(corporation_id) do
    # For unaligned corporations, group them more carefully
    hash = :erlang.phash2(corporation_id)

    case rem(hash, 3) do
      0 -> :independent_alpha
      1 -> :independent_beta
      2 -> :independent_gamma
    end
  end

  # Enhanced side determination for battle analysis that uses attack patterns
  def determine_sides_from_battle_data(timeline) do
    # Analyze attack patterns to determine actual battle sides
    if Enum.empty?(timeline) do
      %{}
    else
      # Build attack relationship graph
      attack_relationships = build_attack_relationships(timeline)

      # Group entities by who they attack vs who attacks them
      side_analysis = analyze_attack_patterns(attack_relationships)

      # Create side mappings
      create_side_mappings(side_analysis)
    end
  end

  defp build_attack_relationships(timeline) do
    # Build a graph of who attacked whom
    timeline
    |> Enum.flat_map(fn killmail ->
      victim_id = get_entity_id(killmail.victim_corporation_id, killmail.victim_alliance_id)

      # Extract attackers
      attackers =
        case killmail.raw_data do
          %{"attackers" => attackers} when is_list(attackers) ->
            attackers
            |> Enum.map(fn attacker ->
              get_entity_id(attacker["corporation_id"], attacker["alliance_id"])
            end)
            |> Enum.filter(&(&1 != nil))

          _ ->
            []
        end

      # Create attack relationships
      Enum.map(attackers, fn attacker_id ->
        %{
          attacker: attacker_id,
          victim: victim_id,
          timestamp: killmail.killmail_time,
          damage: extract_damage_from_attacker(killmail.raw_data, attacker_id)
        }
      end)
    end)
    |> Enum.filter(fn rel -> rel.attacker != nil and rel.victim != nil end)
  end

  defp get_entity_id(corporation_id, alliance_id) do
    # Prioritize alliance over corporation for entity identification
    cond do
      alliance_id != nil and alliance_id != 0 -> {:alliance, alliance_id}
      corporation_id != nil and corporation_id != 0 -> {:corporation, corporation_id}
      true -> nil
    end
  end

  defp extract_damage_from_attacker(raw_data, entity_id) do
    # Extract damage dealt by specific attacker
    case raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        attacker =
          Enum.find(attackers, fn attacker ->
            attacker_entity = get_entity_id(attacker["corporation_id"], attacker["alliance_id"])
            attacker_entity == entity_id
          end)

        case attacker do
          %{"damage_done" => damage} -> damage
          _ -> 0
        end

      _ ->
        0
    end
  end

  defp analyze_attack_patterns(attack_relationships) do
    # Group entities by attack patterns
    entities =
      attack_relationships
      |> Enum.flat_map(fn rel -> [rel.attacker, rel.victim] end)
      |> Enum.uniq()

    # For each entity, determine who they primarily attack vs who attacks them
    entity_patterns =
      entities
      |> Enum.map(fn entity ->
        # Who does this entity attack?
        targets =
          attack_relationships
          |> Enum.filter(fn rel -> rel.attacker == entity end)
          |> Enum.map(& &1.victim)
          |> Enum.frequencies()

        # Who attacks this entity?
        attackers =
          attack_relationships
          |> Enum.filter(fn rel -> rel.victim == entity end)
          |> Enum.map(& &1.attacker)
          |> Enum.frequencies()

        %{
          entity: entity,
          targets: targets,
          attackers: attackers,
          target_count: map_size(targets),
          attacker_count: map_size(attackers)
        }
      end)

    # Group entities that share similar attack patterns
    group_entities_by_patterns(entity_patterns)
  end

  defp group_entities_by_patterns(entity_patterns) do
    # Use a simple clustering approach based on shared targets/enemies
    groups = []
    unassigned = entity_patterns

    {final_groups, _} =
      Enum.reduce(entity_patterns, {groups, unassigned}, fn entity,
                                                            {acc_groups, acc_unassigned} ->
        if entity in acc_unassigned do
          # Find entities that share targets or enemies with this entity
          similar_entities =
            acc_unassigned
            |> Enum.filter(fn other_entity ->
              entities_are_allied?(entity, other_entity)
            end)

          # Create new group
          new_group = %{
            entities: similar_entities,
            primary_targets: merge_target_lists(similar_entities),
            primary_enemies: merge_attacker_lists(similar_entities)
          }

          updated_groups = [new_group | acc_groups]
          updated_unassigned = acc_unassigned -- similar_entities

          {updated_groups, updated_unassigned}
        else
          {acc_groups, acc_unassigned}
        end
      end)

    final_groups
  end

  defp entities_are_allied?(entity1, entity2) do
    # Check if two entities are likely on the same side
    # Based on shared targets and lack of mutual attacks

    # Do they attack the same targets?
    shared_targets =
      Map.keys(entity1.targets)
      |> Enum.filter(fn target -> Map.has_key?(entity2.targets, target) end)
      |> length()

    # Do they attack each other?
    mutual_attacks =
      Map.has_key?(entity1.targets, entity2.entity) or
        Map.has_key?(entity2.targets, entity1.entity)

    # Are they attacked by the same entities?
    shared_enemies =
      Map.keys(entity1.attackers)
      |> Enum.filter(fn enemy -> Map.has_key?(entity2.attackers, enemy) end)
      |> length()

    # Criteria for being allied:
    # 1. Share targets OR share enemies
    # 2. Don't attack each other
    (shared_targets > 0 or shared_enemies > 0) and not mutual_attacks
  end

  defp merge_target_lists(entities) do
    entities
    |> Enum.flat_map(fn entity -> Map.keys(entity.targets) end)
    |> Enum.frequencies()
  end

  defp merge_attacker_lists(entities) do
    entities
    |> Enum.flat_map(fn entity -> Map.keys(entity.attackers) end)
    |> Enum.frequencies()
  end

  defp create_side_mappings(group_analysis) do
    # Convert groups into side mappings
    group_analysis
    |> Enum.with_index()
    |> Enum.flat_map(fn {group, index} ->
      side_name = generate_side_name(index, group)

      Enum.map(group.entities, fn entity ->
        {entity.entity, side_name}
      end)
    end)
    |> Map.new()
  end

  defp generate_side_name(index, group) do
    # Generate meaningful side names based on group characteristics
    entity_count = length(group.entities)

    base_name =
      case index do
        0 -> "Primary"
        1 -> "Secondary"
        2 -> "Third"
        3 -> "Fourth"
        n -> "Side_#{n + 1}"
      end

    size_modifier =
      cond do
        entity_count > 10 -> "Coalition"
        entity_count > 5 -> "Alliance"
        entity_count > 2 -> "Group"
        true -> "Force"
      end

    "#{base_name}_#{size_modifier}"
  end

  # Helper functions for tactical evolution analysis

  defp analyze_doctrine_evolution(sorted_battles) do
    # Track how doctrines change over time
    doctrine_timeline =
      sorted_battles
      |> Enum.with_index()
      |> Enum.map(fn {battle, index} ->
        doctrines = extract_doctrines_from_battle(battle)

        %{
          battle_index: index,
          timestamp: extract_battle_timestamp(battle),
          primary_doctrines: doctrines,
          doctrine_diversity: calculate_doctrine_diversity(doctrines)
        }
      end)

    # Analyze doctrine trends
    doctrine_changes = identify_doctrine_changes(doctrine_timeline)
    doctrine_stability = calculate_doctrine_stability(doctrine_timeline)

    %{
      timeline: doctrine_timeline,
      major_changes: doctrine_changes,
      stability_score: doctrine_stability,
      trend_direction: determine_doctrine_trend_direction(doctrine_timeline)
    }
  end

  defp analyze_ship_composition_trends(sorted_battles) do
    # Analyze how ship compositions change over time
    composition_timeline =
      sorted_battles
      |> Enum.with_index()
      |> Enum.map(fn {battle, index} ->
        composition = extract_ship_composition_from_battle(battle)

        %{
          battle_index: index,
          timestamp: extract_battle_timestamp(battle),
          ship_classes: analyze_ship_class_distribution(composition),
          support_ratio: calculate_composition_support_ratio(composition),
          average_ship_value: calculate_average_ship_value(composition),
          size_category: categorize_fleet_size(composition)
        }
      end)

    # Identify trends
    ship_class_trends = track_ship_class_trends(composition_timeline)
    support_trends = track_support_ratio_trends(composition_timeline)
    value_trends = track_value_trends(composition_timeline)

    %{
      timeline: composition_timeline,
      ship_class_trends: ship_class_trends,
      support_trends: support_trends,
      value_trends: value_trends,
      evolution_pattern: determine_composition_evolution_pattern(composition_timeline)
    }
  end

  defp analyze_engagement_pattern_evolution(sorted_battles) do
    # Analyze how engagement patterns change
    engagement_timeline =
      sorted_battles
      |> Enum.with_index()
      |> Enum.map(fn {battle, index} ->
        engagement_patterns = extract_engagement_patterns_from_battle(battle)

        %{
          battle_index: index,
          timestamp: extract_battle_timestamp(battle),
          duration_category: categorize_battle_duration(battle),
          intensity_level: extract_battle_intensity(battle),
          participant_count: extract_participant_count(battle),
          tactical_complexity: calculate_tactical_complexity(battle),
          patterns: engagement_patterns
        }
      end)

    # Analyze trends
    duration_trend = analyze_duration_trends(engagement_timeline)
    intensity_trend = analyze_intensity_trends(engagement_timeline)
    complexity_trend = analyze_complexity_trends(engagement_timeline)

    %{
      timeline: engagement_timeline,
      duration_evolution: duration_trend,
      intensity_evolution: intensity_trend,
      complexity_evolution: complexity_trend,
      overall_pattern: determine_engagement_evolution_pattern(engagement_timeline)
    }
  end

  defp analyze_tactical_adaptation(sorted_battles) do
    # Look for evidence of tactical adaptation between battles
    adaptations =
      sorted_battles
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.with_index()
      |> Enum.map(fn {[prev_battle, curr_battle], index} ->
        detect_tactical_adaptations(prev_battle, curr_battle, index)
      end)
      |> Enum.filter(& &1.adaptations_detected)

    %{
      adaptation_events: adaptations,
      total_adaptations: length(adaptations),
      adaptation_rate: calculate_adaptation_rate(adaptations, length(sorted_battles)),
      most_common_adaptations: identify_common_adaptation_patterns(adaptations)
    }
  end

  defp extract_doctrines_from_battle(battle) do
    # Extract doctrine information from battle analysis
    case battle do
      %{doctrine_analysis: %{detected_doctrines: doctrines}} -> doctrines
      %{detected_doctrines: doctrines} -> doctrines
      _ -> []
    end
  end

  defp extract_battle_timestamp(battle) do
    case battle do
      %{start_time: time} -> time
      %{timestamp: time} -> time
      %{analyzed_at: time} -> time
      _ -> ~N[1970-01-01 00:00:00]
    end
  end

  defp calculate_doctrine_diversity(doctrines) do
    # Calculate diversity score for doctrines
    if Enum.empty?(doctrines) do
      0.0
    else
      unique_types =
        doctrines
        |> Enum.map(& &1.type)
        |> Enum.uniq()
        |> length()

      Float.round(unique_types / max(1, length(doctrines)), 2)
    end
  end

  defp identify_doctrine_changes(doctrine_timeline) do
    # Identify significant doctrine changes between battles
    doctrine_timeline
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, curr] ->
      prev_doctrine_names = Enum.map(prev.primary_doctrines, & &1.name)
      curr_doctrine_names = Enum.map(curr.primary_doctrines, & &1.name)

      new_doctrines = curr_doctrine_names -- prev_doctrine_names
      dropped_doctrines = prev_doctrine_names -- curr_doctrine_names

      if length(new_doctrines) > 0 or length(dropped_doctrines) > 0 do
        %{
          battle_transition: "#{prev.battle_index} -> #{curr.battle_index}",
          timestamp: curr.timestamp,
          new_doctrines: new_doctrines,
          dropped_doctrines: dropped_doctrines,
          change_significance:
            calculate_doctrine_change_significance(new_doctrines, dropped_doctrines)
        }
      else
        nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp calculate_doctrine_stability(doctrine_timeline) do
    # Calculate how stable doctrine usage is over time
    if length(doctrine_timeline) < 2 do
      1.0
    else
      changes = identify_doctrine_changes(doctrine_timeline)
      stability = 1.0 - length(changes) / max(1, length(doctrine_timeline) - 1)
      Float.round(stability, 2)
    end
  end

  defp determine_doctrine_trend_direction(doctrine_timeline) do
    # Determine if doctrines are becoming more or less diverse
    if length(doctrine_timeline) < 2 do
      :stable
    else
      first_half = Enum.take(doctrine_timeline, div(length(doctrine_timeline), 2))
      second_half = Enum.drop(doctrine_timeline, div(length(doctrine_timeline), 2))

      first_avg_diversity =
        first_half
        |> Enum.map(& &1.doctrine_diversity)
        |> Enum.sum()
        |> Kernel./(length(first_half))

      second_avg_diversity =
        second_half
        |> Enum.map(& &1.doctrine_diversity)
        |> Enum.sum()
        |> Kernel./(length(second_half))

      cond do
        second_avg_diversity > first_avg_diversity + 0.1 -> :increasing_diversity
        second_avg_diversity < first_avg_diversity - 0.1 -> :decreasing_diversity
        true -> :stable
      end
    end
  end

  defp extract_ship_composition_from_battle(battle) do
    # Extract ship composition data from battle
    case battle do
      %{ship_composition: composition} -> composition
      %{fleet_compositions: composition} -> composition
      _ -> %{}
    end
  end

  defp analyze_ship_class_distribution(composition) do
    # Analyze ship class distribution from composition
    if Enum.empty?(composition) do
      %{}
    else
      # Extract ship classes from composition data
      composition
      |> Enum.flat_map(fn {_side, side_data} ->
        case side_data do
          %{ships: ships} when is_list(ships) -> ships
          ships when is_list(ships) -> ships
          _ -> []
        end
      end)
      |> Enum.group_by(&classify_ship_by_type_id/1)
      |> Enum.map(fn {class, ships} -> {class, length(ships)} end)
      |> Map.new()
    end
  end

  defp calculate_composition_support_ratio(composition) do
    # Calculate support ship ratio from composition
    ship_classes = analyze_ship_class_distribution(composition)

    support_classes = [:logistics_cruiser, :recon_ship, :command_ship, :heavy_interdictor]

    support_count =
      support_classes
      |> Enum.map(fn class -> Map.get(ship_classes, class, 0) end)
      |> Enum.sum()

    total_ships =
      ship_classes
      |> Map.values()
      |> Enum.sum()

    if total_ships > 0 do
      Float.round(support_count / total_ships, 2)
    else
      0.0
    end
  end

  defp calculate_average_ship_value(composition) do
    # Estimate average ship value from composition
    ship_classes = analyze_ship_class_distribution(composition)

    if Enum.empty?(ship_classes) do
      0
    else
      total_value =
        ship_classes
        |> Enum.map(fn {class, count} ->
          estimated_value = estimate_ship_class_value(class)
          estimated_value * count
        end)
        |> Enum.sum()

      total_ships = ship_classes |> Map.values() |> Enum.sum()

      if total_ships > 0 do
        round(total_value / total_ships)
      else
        0
      end
    end
  end

  defp estimate_ship_class_value(ship_class) do
    # Estimate average ISK value by ship class
    case ship_class do
      :frigate -> 5_000_000
      :assault_frigate -> 50_000_000
      :destroyer -> 15_000_000
      :interdictor -> 80_000_000
      :cruiser -> 25_000_000
      :heavy_assault_cruiser -> 200_000_000
      :logistics_cruiser -> 300_000_000
      :recon_ship -> 250_000_000
      :strategic_cruiser -> 400_000_000
      :battlecruiser -> 100_000_000
      :command_ship -> 350_000_000
      :battleship -> 300_000_000
      :carrier -> 2_000_000_000
      :dreadnought -> 3_000_000_000
      :force_auxiliary -> 4_000_000_000
      :supercarrier -> 20_000_000_000
      :titan -> 100_000_000_000
      _ -> 50_000_000
    end
  end

  defp categorize_fleet_size(composition) do
    total_ships =
      analyze_ship_class_distribution(composition)
      |> Map.values()
      |> Enum.sum()

    cond do
      total_ships >= 100 -> :large_fleet
      total_ships >= 50 -> :medium_fleet
      total_ships >= 20 -> :small_fleet
      total_ships >= 5 -> :small_gang
      true -> :micro_gang
    end
  end

  defp track_ship_class_trends(composition_timeline) do
    # Track how ship class usage changes over time
    if length(composition_timeline) < 2 do
      %{trend: :insufficient_data}
    else
      # Calculate trends for major ship classes
      major_classes = [:cruiser, :battleship, :heavy_assault_cruiser, :carrier, :dreadnought]

      class_trends =
        major_classes
        |> Enum.map(fn class ->
          usage_over_time =
            composition_timeline
            |> Enum.map(fn timeline_entry ->
              Map.get(timeline_entry.ship_classes, class, 0)
            end)

          trend_direction = calculate_usage_trend(usage_over_time)

          {class,
           %{
             usage_timeline: usage_over_time,
             trend_direction: trend_direction,
             peak_usage: Enum.max(usage_over_time),
             average_usage: Float.round(Enum.sum(usage_over_time) / length(usage_over_time), 1)
           }}
        end)
        |> Map.new()

      %{
        class_trends: class_trends,
        overall_trend: determine_overall_ship_trend(class_trends)
      }
    end
  end

  defp track_support_ratio_trends(composition_timeline) do
    support_ratios = Enum.map(composition_timeline, & &1.support_ratio)

    %{
      ratio_timeline: support_ratios,
      trend_direction: calculate_usage_trend(support_ratios),
      average_ratio: Float.round(Enum.sum(support_ratios) / length(support_ratios), 2),
      peak_ratio: Enum.max(support_ratios)
    }
  end

  defp track_value_trends(composition_timeline) do
    values = Enum.map(composition_timeline, & &1.average_ship_value)

    %{
      value_timeline: values,
      trend_direction: calculate_usage_trend(values),
      average_value: round(Enum.sum(values) / length(values)),
      peak_value: Enum.max(values)
    }
  end

  defp calculate_usage_trend(values) do
    if length(values) < 2 do
      :stable
    else
      first_half_avg =
        values
        |> Enum.take(div(length(values), 2))
        |> Enum.sum()
        |> Kernel./(div(length(values), 2))

      second_half_avg =
        values
        |> Enum.drop(div(length(values), 2))
        |> Enum.sum()
        |> Kernel./(length(values) - div(length(values), 2))

      change_percentage = abs(second_half_avg - first_half_avg) / max(1, first_half_avg) * 100

      cond do
        change_percentage < 10 -> :stable
        second_half_avg > first_half_avg -> :increasing
        true -> :decreasing
      end
    end
  end

  defp determine_overall_ship_trend(class_trends) do
    increasing_count =
      class_trends
      |> Map.values()
      |> Enum.count(fn trend -> trend.trend_direction == :increasing end)

    decreasing_count =
      class_trends
      |> Map.values()
      |> Enum.count(fn trend -> trend.trend_direction == :decreasing end)

    cond do
      increasing_count > decreasing_count -> :escalation
      decreasing_count > increasing_count -> :de_escalation
      true -> :stable
    end
  end

  defp determine_composition_evolution_pattern(composition_timeline) do
    # Determine overall composition evolution pattern
    size_categories = Enum.map(composition_timeline, & &1.size_category)
    support_ratios = Enum.map(composition_timeline, & &1.support_ratio)

    size_trend = calculate_categorical_trend(size_categories)
    support_trend = calculate_usage_trend(support_ratios)

    case {size_trend, support_trend} do
      {:escalating, :increasing} -> :full_escalation
      {:escalating, _} -> :force_escalation
      {_, :increasing} -> :tactical_sophistication
      {:de_escalating, :decreasing} -> :full_de_escalation
      {:de_escalating, _} -> :force_reduction
      {_, :decreasing} -> :tactical_simplification
      _ -> :stable_evolution
    end
  end

  defp calculate_categorical_trend(categories) do
    # Calculate trend for categorical data like fleet sizes
    size_values =
      categories
      |> Enum.map(fn
        :micro_gang -> 1
        :small_gang -> 2
        :small_fleet -> 3
        :medium_fleet -> 4
        :large_fleet -> 5
        _ -> 0
      end)

    case calculate_usage_trend(size_values) do
      :increasing -> :escalating
      :decreasing -> :de_escalating
      :stable -> :stable
    end
  end

  defp extract_engagement_patterns_from_battle(battle) do
    # Extract engagement pattern data from battle
    case battle do
      %{engagement_patterns: patterns} -> patterns
      %{tactical_insights: patterns} -> patterns
      _ -> %{}
    end
  end

  defp categorize_battle_duration(battle) do
    # Extract duration and categorize
    duration =
      case battle do
        %{duration_minutes: minutes} -> minutes
        %{metadata: %{duration_minutes: minutes}} -> minutes
        _ -> 0
      end

    cond do
      duration >= 60 -> :extended
      duration >= 30 -> :prolonged
      duration >= 10 -> :standard
      duration >= 2 -> :brief
      true -> :instant
    end
  end

  defp extract_battle_intensity(battle) do
    # Extract intensity information
    case battle do
      %{intensity_curve: curve} when is_list(curve) ->
        if Enum.empty?(curve) do
          :unknown
        else
          avg_intensity =
            curve |> Enum.map(& &1.intensity_score) |> Enum.sum() |> Kernel./(length(curve))

          categorize_intensity(avg_intensity)
        end

      %{performance_metrics: %{engagement_intensity: intensity}} ->
        categorize_intensity(intensity)

      _ ->
        :unknown
    end
  end

  defp categorize_intensity(intensity_score) do
    cond do
      intensity_score >= 80 -> :very_high
      intensity_score >= 60 -> :high
      intensity_score >= 40 -> :medium
      intensity_score >= 20 -> :low
      true -> :very_low
    end
  end

  defp extract_participant_count(battle) do
    case battle do
      %{participants: participants} when is_list(participants) -> length(participants)
      %{metadata: %{unique_participants: count}} -> count
      _ -> 0
    end
  end

  defp calculate_tactical_complexity(battle) do
    # Calculate tactical complexity based on various factors
    base_score = 0

    # Add points for EWAR presence
    base_score = base_score + if has_ewar?(battle), do: 20, else: 0

    # Add points for multiple doctrines
    doctrine_count = count_doctrines(battle)
    base_score = base_score + min(30, doctrine_count * 10)

    # Add points for multiple phases
    phase_count = count_battle_phases(battle)
    base_score = base_score + min(25, phase_count * 5)

    # Add points for participant diversity
    participant_count = extract_participant_count(battle)
    base_score = base_score + min(25, participant_count)

    Float.round(min(100, base_score), 1)
  end

  defp has_ewar?(battle) do
    case battle do
      %{ewar_analysis: %{ewar_detected: detected}} -> detected
      _ -> false
    end
  end

  defp count_doctrines(battle) do
    case battle do
      %{doctrine_analysis: %{detected_doctrines: doctrines}} -> length(doctrines)
      _ -> 0
    end
  end

  defp count_battle_phases(battle) do
    case battle do
      %{battle_phases: phases} when is_list(phases) -> length(phases)
      %{timeline: %{phases: phases}} when is_list(phases) -> length(phases)
      _ -> 1
    end
  end

  defp analyze_duration_trends(engagement_timeline) do
    durations =
      engagement_timeline
      |> Enum.map(& &1.duration_category)
      |> Enum.map(fn
        :instant -> 1
        :brief -> 2
        :standard -> 3
        :prolonged -> 4
        :extended -> 5
        _ -> 0
      end)

    %{
      trend_direction: calculate_usage_trend(durations),
      pattern: determine_duration_pattern(engagement_timeline)
    }
  end

  defp analyze_intensity_trends(engagement_timeline) do
    intensities =
      engagement_timeline
      |> Enum.map(& &1.intensity_level)
      |> Enum.map(fn
        :very_low -> 1
        :low -> 2
        :medium -> 3
        :high -> 4
        :very_high -> 5
        _ -> 0
      end)

    %{
      trend_direction: calculate_usage_trend(intensities),
      average_intensity: Float.round(Enum.sum(intensities) / length(intensities), 1)
    }
  end

  defp analyze_complexity_trends(engagement_timeline) do
    complexities = Enum.map(engagement_timeline, & &1.tactical_complexity)

    %{
      trend_direction: calculate_usage_trend(complexities),
      average_complexity: Float.round(Enum.sum(complexities) / length(complexities), 1),
      peak_complexity: Enum.max(complexities)
    }
  end

  defp determine_duration_pattern(engagement_timeline) do
    durations = Enum.map(engagement_timeline, & &1.duration_category)
    unique_durations = Enum.uniq(durations)

    cond do
      length(unique_durations) == 1 -> :consistent
      length(unique_durations) >= length(durations) * 0.8 -> :highly_variable
      true -> :moderately_variable
    end
  end

  defp determine_engagement_evolution_pattern(engagement_timeline) do
    # Determine overall engagement evolution pattern
    complexity_trend = analyze_complexity_trends(engagement_timeline)
    intensity_trend = analyze_intensity_trends(engagement_timeline)

    case {complexity_trend.trend_direction, intensity_trend.trend_direction} do
      {:increasing, :increasing} -> :escalating_sophistication
      {:increasing, _} -> :tactical_evolution
      {_, :increasing} -> :intensity_escalation
      {:decreasing, :decreasing} -> :simplification
      {:stable, :stable} -> :consistent_engagement
      _ -> :mixed_evolution
    end
  end

  defp detect_tactical_adaptations(prev_battle, curr_battle, index) do
    # Detect adaptations between consecutive battles
    adaptations = []

    # Check for doctrine changes
    prev_doctrines = extract_doctrines_from_battle(prev_battle)
    curr_doctrines = extract_doctrines_from_battle(curr_battle)

    doctrine_adaptation = detect_doctrine_adaptation(prev_doctrines, curr_doctrines)

    adaptations =
      if doctrine_adaptation, do: [doctrine_adaptation | adaptations], else: adaptations

    # Check for composition changes
    composition_adaptation = detect_composition_adaptation(prev_battle, curr_battle)

    adaptations =
      if composition_adaptation, do: [composition_adaptation | adaptations], else: adaptations

    # Check for tactical changes
    tactical_adaptation = detect_tactical_adaptation_patterns(prev_battle, curr_battle)

    adaptations =
      if tactical_adaptation, do: [tactical_adaptation | adaptations], else: adaptations

    %{
      battle_transition: index,
      timestamp: extract_battle_timestamp(curr_battle),
      adaptations_detected: length(adaptations) > 0,
      specific_adaptations: adaptations
    }
  end

  defp detect_doctrine_adaptation(prev_doctrines, curr_doctrines) do
    prev_names = Enum.map(prev_doctrines, & &1.name)
    curr_names = Enum.map(curr_doctrines, & &1.name)

    if prev_names != curr_names do
      %{
        type: :doctrine_shift,
        from: prev_names,
        to: curr_names,
        significance:
          calculate_doctrine_change_significance(
            curr_names -- prev_names,
            prev_names -- curr_names
          )
      }
    else
      nil
    end
  end

  defp detect_composition_adaptation(prev_battle, curr_battle) do
    prev_comp = extract_ship_composition_from_battle(prev_battle)
    curr_comp = extract_ship_composition_from_battle(curr_battle)

    prev_support_ratio = calculate_composition_support_ratio(prev_comp)
    curr_support_ratio = calculate_composition_support_ratio(curr_comp)

    support_change = abs(curr_support_ratio - prev_support_ratio)

    if support_change > 0.2 do
      %{
        type: :composition_adaptation,
        metric: :support_ratio,
        change: curr_support_ratio - prev_support_ratio,
        significance: if(support_change > 0.4, do: :major, else: :minor)
      }
    else
      nil
    end
  end

  defp detect_tactical_adaptation_patterns(prev_battle, curr_battle) do
    prev_complexity = calculate_tactical_complexity(prev_battle)
    curr_complexity = calculate_tactical_complexity(curr_battle)

    complexity_change = curr_complexity - prev_complexity

    if abs(complexity_change) > 20 do
      %{
        type: :tactical_complexity_shift,
        direction: if(complexity_change > 0, do: :increased, else: :decreased),
        magnitude: abs(complexity_change),
        significance: if(abs(complexity_change) > 40, do: :major, else: :minor)
      }
    else
      nil
    end
  end

  defp calculate_doctrine_change_significance(new_doctrines, dropped_doctrines) do
    total_changes = length(new_doctrines) + length(dropped_doctrines)

    cond do
      total_changes >= 3 -> :major
      total_changes >= 2 -> :moderate
      total_changes >= 1 -> :minor
      true -> :none
    end
  end

  defp calculate_adaptation_rate(adaptations, total_battles) do
    if total_battles <= 1 do
      0.0
    else
      Float.round(length(adaptations) / (total_battles - 1) * 100, 1)
    end
  end

  defp identify_common_adaptation_patterns(adaptations) do
    # Identify most common types of adaptations
    adaptations
    |> Enum.flat_map(& &1.specific_adaptations)
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, instances} -> {type, length(instances)} end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(3)
  end

  defp calculate_analysis_timespan(sorted_battles) do
    if length(sorted_battles) < 2 do
      "Single battle"
    else
      start_time = extract_battle_timestamp(List.first(sorted_battles))
      end_time = extract_battle_timestamp(List.last(sorted_battles))

      case NaiveDateTime.diff(end_time, start_time, :second) do
        diff when diff < 3600 -> "#{div(diff, 60)} minutes"
        diff when diff < 86400 -> "#{div(diff, 3600)} hours"
        diff -> "#{div(diff, 86400)} days"
      end
    end
  end

  defp generate_evolution_summary(doctrine_evolution, ship_trends, engagement_patterns) do
    # Generate human-readable summary of tactical evolution
    doctrine_summary =
      case doctrine_evolution.trend_direction do
        :increasing_diversity -> "Doctrine usage becoming more diverse"
        :decreasing_diversity -> "Doctrine usage becoming more focused"
        :stable -> "Doctrine usage remains stable"
      end

    composition_summary =
      case ship_trends.evolution_pattern do
        :full_escalation -> "Fleet compositions escalating in both size and sophistication"
        :tactical_sophistication -> "Compositions becoming more tactically sophisticated"
        :stable_evolution -> "Fleet compositions remain relatively stable"
        pattern -> "Compositions showing #{pattern} pattern"
      end

    engagement_summary =
      case engagement_patterns.overall_pattern do
        :escalating_sophistication -> "Engagements becoming more complex and intense"
        :tactical_evolution -> "Tactical approaches evolving"
        :consistent_engagement -> "Engagement patterns remain consistent"
        pattern -> "Engagement patterns showing #{pattern}"
      end

    "#{doctrine_summary}. #{composition_summary}. #{engagement_summary}."
  end

  defp analyze_fleet_composition_gaps(fleet_compositions) do
    # Analyze gaps in fleet compositions and suggest improvements
    if Enum.empty?(fleet_compositions) do
      []
    else
      # Analyze each side's composition for gaps
      side_gaps =
        fleet_compositions
        |> Enum.flat_map(fn {side, composition} ->
          analyze_side_composition_gaps(side, composition)
        end)

      # Add cross-side comparison gaps
      all_gaps = side_gaps ++ analyze_cross_side_gaps(fleet_compositions)

      all_gaps
      |> Enum.sort_by(& &1.priority, :desc)
      # Top 5 most important gaps
      |> Enum.take(5)
    end
  end

  defp generate_pattern_based_recommendations(patterns) do
    # Generate recommendations based on identified tactical patterns
    if Enum.empty?(patterns) do
      []
    else
      # Analyze patterns and generate specific recommendations
      pattern_recommendations =
        patterns
        |> Enum.flat_map(&pattern_to_recommendations/1)
        |> Enum.sort_by(& &1.impact, :desc)
        # Top 3 pattern-based recommendations
        |> Enum.take(3)

      pattern_recommendations
    end
  end

  defp analyze_strategic_positioning(battle_analysis) do
    # Analyze strategic positioning opportunities
    case battle_analysis do
      %{tactical_insights: insights, fleet_compositions: compositions} ->
        %{
          recommendation_type: :strategic_positioning,
          priority: :medium,
          description: "Optimize strategic positioning based on battle analysis",
          specific_actions: generate_positioning_actions(insights, compositions),
          expected_impact: "Improved tactical advantage and reduced losses",
          implementation_difficulty: :medium
        }

      _ ->
        %{
          recommendation_type: :strategic_positioning,
          priority: :low,
          description: "Insufficient data for strategic positioning analysis",
          specific_actions: ["Gather more tactical intelligence"],
          expected_impact: "Unknown",
          implementation_difficulty: :easy
        }
    end
  end

  defp recommend_force_multiplication(battle_analysis) do
    # Recommend force multiplication strategies
    case battle_analysis do
      %{fleet_compositions: compositions, performance_metrics: metrics} ->
        force_multipliers = identify_force_multipliers(compositions, metrics)

        %{
          recommendation_type: :force_multiplication,
          priority: determine_force_mult_priority(force_multipliers),
          description: "Deploy force multiplication strategies",
          specific_actions: generate_force_mult_actions(force_multipliers),
          expected_impact: "Increase combat effectiveness with existing resources",
          implementation_difficulty: :medium
        }

      _ ->
        %{
          recommendation_type: :force_multiplication,
          priority: :low,
          description: "Utilize logistics and support ships for force multiplication",
          specific_actions: [
            "Deploy logistics cruisers",
            "Add EWAR support",
            "Coordinate focus fire"
          ],
          expected_impact: "Moderate improvement in fleet effectiveness",
          implementation_difficulty: :easy
        }
    end
  end

  defp suggest_engagement_timing(battle_analysis) do
    # Suggest optimal engagement timing
    case battle_analysis do
      %{timeline: timeline, intensity_curve: curve} when is_list(timeline) and is_list(curve) ->
        timing_analysis = analyze_engagement_timing_patterns(timeline, curve)

        %{
          recommendation_type: :engagement_timing,
          priority: timing_analysis.priority,
          description: "Optimize engagement timing based on battle patterns",
          specific_actions: timing_analysis.actions,
          expected_impact: "Better engagement outcomes through improved timing",
          implementation_difficulty: :medium
        }

      _ ->
        %{
          recommendation_type: :engagement_timing,
          priority: :medium,
          description: "Consider engagement timing optimization",
          specific_actions: [
            "Monitor enemy activity patterns",
            "Time engagements during favorable conditions"
          ],
          expected_impact: "Improved battle initiation success",
          implementation_difficulty: :easy
        }
    end
  end

  defp recommend_doctrine_adjustments(fleet_comps) do
    # Recommend adjustments to current doctrine based on composition analysis
    if Enum.empty?(fleet_comps) do
      %{
        recommendation_type: :doctrine_adjustment,
        priority: :low,
        description: "No fleet composition data available for doctrine analysis",
        specific_actions: [],
        expected_impact: "Unknown",
        implementation_difficulty: :easy
      }
    else
      # Analyze current doctrines and suggest improvements
      weaknesses = analyze_doctrine_composition_weaknesses(fleet_comps)

      %{
        recommendation_type: :doctrine_adjustment,
        priority: determine_doctrine_adjustment_priority(weaknesses),
        description: "Adjust current doctrine to address composition weaknesses",
        specific_actions: generate_doctrine_adjustment_actions(weaknesses),
        expected_impact: "Improved doctrine effectiveness and reduced vulnerabilities",
        implementation_difficulty: :medium
      }
    end
  end

  defp suggest_counter_doctrines(fleet_comps) do
    # Suggest counter-doctrines based on enemy fleet compositions
    if Enum.empty?(fleet_comps) do
      %{
        recommendation_type: :counter_doctrine,
        priority: :low,
        description: "No enemy fleet data available for counter-doctrine analysis",
        specific_actions: [],
        expected_impact: "Unknown",
        implementation_difficulty: :easy
      }
    else
      # Analyze enemy compositions and suggest counters
      enemy_patterns = identify_enemy_doctrine_patterns(fleet_comps)
      counter_strategies = generate_counter_strategies(enemy_patterns)

      %{
        recommendation_type: :counter_doctrine,
        priority: calculate_counter_doctrine_priority(enemy_patterns),
        description: "Deploy counter-doctrines against identified enemy patterns",
        specific_actions: counter_strategies,
        expected_impact: "Tactical advantage through doctrine countering",
        implementation_difficulty: :medium
      }
    end
  end

  defp identify_doctrine_weaknesses(fleet_comps) do
    # Identify weaknesses in current doctrine implementations
    if Enum.empty?(fleet_comps) do
      %{
        weaknesses_found: false,
        analysis: "No fleet composition data available",
        recommendations: []
      }
    else
      weaknesses = []

      # Check for common doctrine weaknesses
      weaknesses = weaknesses ++ check_support_ship_ratios(fleet_comps)
      weaknesses = weaknesses ++ check_role_coverage(fleet_comps)
      weaknesses = weaknesses ++ check_ship_synergy(fleet_comps)

      %{
        weaknesses_found: length(weaknesses) > 0,
        total_weaknesses: length(weaknesses),
        critical_weaknesses: Enum.count(weaknesses, fn w -> w.severity == :critical end),
        analysis: generate_weakness_analysis(weaknesses),
        recommendations: Enum.map(weaknesses, &weakness_to_recommendation/1)
      }
    end
  end

  defp identify_skill_gaps(battle_analysis) do
    # Identify skill gaps based on battle performance
    case battle_analysis do
      %{performance_metrics: metrics, tactical_insights: insights} ->
        skill_gaps = []

        # Analyze performance to identify skill gaps
        skill_gaps = skill_gaps ++ analyze_performance_gaps(metrics)
        skill_gaps = skill_gaps ++ analyze_tactical_execution_gaps(insights)

        %{
          gaps_identified: length(skill_gaps) > 0,
          total_gaps: length(skill_gaps),
          priority_gaps: Enum.filter(skill_gaps, fn gap -> gap.priority == :high end),
          skill_analysis: generate_skill_gap_analysis(skill_gaps),
          training_recommendations: generate_training_recommendations(skill_gaps)
        }

      _ ->
        %{
          gaps_identified: false,
          total_gaps: 0,
          priority_gaps: [],
          skill_analysis: "Insufficient battle data for skill gap analysis",
          training_recommendations: ["Gather more comprehensive battle data"]
        }
    end
  end

  defp recommend_practice_scenarios(battle_analysis) do
    # Recommend practice scenarios based on battle analysis
    case battle_analysis do
      %{tactical_insights: insights, weaknesses: weaknesses} ->
        scenarios = []

        # Generate scenarios based on identified weaknesses
        scenarios = scenarios ++ generate_weakness_based_scenarios(weaknesses)
        scenarios = scenarios ++ generate_tactical_drill_scenarios(insights)

        %{
          recommendation_type: :practice_scenarios,
          total_scenarios: length(scenarios),
          priority_scenarios: Enum.filter(scenarios, fn s -> s.priority == :high end),
          # Top 5 scenarios
          scenarios: Enum.take(scenarios, 5),
          implementation_timeline: "2-4 weeks for comprehensive training",
          expected_improvement: "15-25% improvement in tactical execution"
        }

      _ ->
        %{
          recommendation_type: :practice_scenarios,
          total_scenarios: 3,
          priority_scenarios: [],
          scenarios: generate_default_practice_scenarios(),
          implementation_timeline: "1-2 weeks",
          expected_improvement: "Basic tactical skill improvement"
        }
    end
  end

  defp suggest_role_specializations(battle_analysis) do
    # Suggest role specializations based on battle performance
    case battle_analysis do
      %{participants: participants, fleet_compositions: compositions} ->
        specializations = []

        # Analyze participant performance to suggest specializations
        specializations =
          specializations ++ analyze_participant_performance_patterns(participants)

        specializations = specializations ++ identify_optimal_role_distributions(compositions)

        %{
          recommendation_type: :role_specialization,
          total_recommendations: length(specializations),
          high_priority: Enum.filter(specializations, fn s -> s.priority == :high end),
          specializations: Enum.take(specializations, 5),
          implementation_difficulty: :medium,
          expected_impact: "Improved individual and fleet performance through optimized roles"
        }

      _ ->
        %{
          recommendation_type: :role_specialization,
          total_recommendations: 3,
          high_priority: [],
          specializations: generate_default_role_specializations(),
          implementation_difficulty: :easy,
          expected_impact: "Basic role optimization"
        }
    end
  end

  defp evaluate_doctrine_effectiveness(_fleet_analysis) do
    %{}
  end

  defp determine_battle_winner(_performance_metrics) do
    :undetermined
  end

  defp analyze_victory_factors(tactical_analysis, performance_metrics) do
    try do
      # Use the comprehensive OutcomeAnalyzer for detailed victory factor analysis
      OutcomeAnalyzer.analyze_victory_factors(tactical_analysis, performance_metrics)
    rescue
      e ->
        Logger.error("Victory factor analysis failed: #{Exception.message(e)}")
        # Fallback to basic analysis if the comprehensive analyzer fails
        perform_basic_victory_analysis(tactical_analysis, performance_metrics)
    end
  end

  defp perform_basic_victory_analysis(tactical_analysis, performance_metrics) do
    initial_factors = []

    # Analyze numerical superiority
    numerical_factors =
      initial_factors ++
        case performance_metrics.by_side do
          by_side when map_size(by_side) == 0 -> []
          by_side -> analyze_numerical_factors(by_side)
        end

    # Analyze tactical effectiveness
    tactical_factors =
      numerical_factors ++
        case tactical_analysis.patterns do
          [] -> []
          patterns -> analyze_tactical_factors(patterns)
        end

    # Analyze engagement control
    control_factors =
      tactical_factors ++
        case tactical_analysis.key_moments do
          [] -> []
          key_moments -> analyze_control_factors(key_moments)
        end

    control_factors
  end

  defp analyze_numerical_factors(side_performance) do
    # Analyze if numbers played a decisive role
    side_counts =
      Enum.map(side_performance, fn {_side, metrics} ->
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

  # Helper functions for ship class performance analysis





  # Pattern analysis functions
  defp identify_enemy_doctrine_patterns(fleet_compositions) do
    fleet_compositions
    |> Enum.group_by(& &1.doctrine_type)
    |> Enum.map(fn {doctrine, fleets} ->
      %{
        doctrine_type: doctrine,
        frequency: length(fleets),
        average_fleet_size: calculate_average_fleet_size(fleets),
        common_ships: identify_common_doctrine_ships(fleets),
        typical_roles: extract_typical_role_distribution(fleets),
        engagement_preferences: analyze_doctrine_engagement_patterns(fleets),
        weaknesses: identify_doctrine_weaknesses(doctrine, fleets)
      }
    end)
    |> Enum.sort_by(& &1.frequency, :desc)
  end

  defp generate_counter_strategies(enemy_patterns) do
    Enum.map(enemy_patterns, fn pattern ->
      %{
        enemy_doctrine: pattern.doctrine_type,
        recommended_comp: suggest_counter_composition(pattern),
        key_ships: identify_counter_ships(pattern),
        tactics: generate_enemy_counter_tactics(pattern),
        required_skills: identify_required_pilot_skills(pattern)
      }
    end)
  end

  defp calculate_counter_doctrine_priority(enemy_patterns) do
    case enemy_patterns do
      [] -> :low
      [single] when single.frequency < 3 -> :medium
      [primary | _] when primary.frequency > 10 -> :critical
      _ -> :high
    end
  end

  defp generate_default_practice_scenarios() do
    [
      %{
        name: "Small Gang Kiting",
        fleet_size: 5,
        composition: ["Orthrus", "Garmur", "Keres", "Sabre", "Scalpel"],
        objectives: ["Maintain range control", "Pick off stragglers", "Avoid brawls"],
        difficulty: :intermediate
      },
      %{
        name: "Armor Brawl",
        fleet_size: 10,
        composition: ["Deimos", "Guardian", "Oneiros", "Devoter", "Vindicator"],
        objectives: ["Close range quickly", "Focus fire coordination", "Logistics anchoring"],
        difficulty: :advanced
      },
      %{
        name: "Bombing Run",
        fleet_size: 8,
        composition: ["Hound", "Nemesis", "Manticore", "Purifier"],
        objectives: ["Coordinate bomb timing", "Warp-in positioning", "Escape routes"],
        difficulty: :expert
      }
    ]
  end

  defp generate_default_role_specializations() do
    [
      %{
        role: :tackle,
        min_pilots: 2,
        max_pilots: 4,
        priority: :critical,
        ship_suggestions: ["Sabre", "Stiletto", "Lachesis", "Arazu"]
      },
      %{
        role: :logistics,
        min_pilots: 2,
        max_pilots: 5,
        priority: :critical,
        ship_suggestions: ["Guardian", "Oneiros", "Scimitar", "Basilisk"]
      },
      %{
        role: :dps,
        min_pilots: 4,
        max_pilots: 15,
        priority: :high,
        ship_suggestions: ["Cerberus", "Muninn", "Eagle", "Ferox"]
      },
      %{
        role: :ewar,
        min_pilots: 1,
        max_pilots: 3,
        priority: :medium,
        ship_suggestions: ["Falcon", "Rook", "Blackbird", "Kitsune"]
      }
    ]
  end

  defp identify_optimal_role_distributions(compositions) do
    compositions
    |> Enum.filter(&(&1.success_rate > 0.7))
    |> Enum.map(fn comp ->
      %{
        fleet_size: comp.fleet_size,
        role_distribution: comp.role_counts,
        success_rate: comp.success_rate,
        use_case: categorize_fleet_use_case(comp)
      }
    end)
    |> Enum.uniq_by(& &1.use_case)
  end

  defp analyze_participant_performance_patterns(participants) do
    participants
    |> Enum.group_by(& &1.preferred_role)
    |> Enum.map(fn {role, role_participants} ->
      %{
        role: role,
        available_pilots: length(role_participants),
        skill_distribution: calculate_role_skill_distribution(role_participants),
        recommended_ships: aggregate_successful_ships(role_participants)
      }
    end)
  end

  defp analyze_engagement_timing_patterns(timeline, efficiency_curve) do
    phase_transitions = identify_phase_transitions(timeline)

    %{
      optimal_engagement_duration: calculate_optimal_duration(efficiency_curve),
      critical_phases: identify_critical_combat_phases(timeline),
      phase_transitions: phase_transitions,
      timing_recommendations: generate_timing_recommendations(phase_transitions)
    }
  end

  # Supporting helper functions
  defp calculate_average_fleet_size(fleets) do
    if length(fleets) > 0 do
      total_size = Enum.sum(Enum.map(fleets, & &1.fleet_size))
      Float.round(total_size / length(fleets), 1)
    else
      0.0
    end
  end

  defp identify_common_doctrine_ships(fleets) do
    fleets
    |> Enum.flat_map(& &1.ship_types)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_ship, count} -> -count end)
    |> Enum.take(5)
    |> Enum.map(fn {ship, _count} -> ship end)
  end

  defp extract_typical_role_distribution(fleets) do
    role_distributions = Enum.map(fleets, & &1.role_counts)

    if length(role_distributions) > 0 do
      # Average role distribution across fleets
      all_roles = role_distributions |> Enum.flat_map(&Map.keys/1) |> Enum.uniq()

      Enum.reduce(all_roles, %{}, fn role, acc ->
        total = Enum.sum(Enum.map(role_distributions, &Map.get(&1, role, 0)))
        avg = Float.round(total / length(role_distributions), 1)
        Map.put(acc, role, avg)
      end)
    else
      %{}
    end
  end

  defp analyze_doctrine_engagement_patterns(fleets) do
    %{
      preferred_range: determine_doctrine_preferred_range(fleets),
      mobility: assess_doctrine_mobility(fleets),
      tank_type: identify_common_tank_type(fleets),
      engagement_style: categorize_engagement_style(fleets)
    }
  end

  defp identify_doctrine_weaknesses(doctrine_type, fleets) do
    base_weaknesses =
      case doctrine_type do
        :kiting -> ["Vulnerable to hard tackle", "Weak in close range"]
        :brawling -> ["Limited range control", "Vulnerable to kiting"]
        :alpha -> ["Reload vulnerability", "Limited sustained DPS"]
        _ -> []
      end

    # Add observed weaknesses from battle data
    observed_weaknesses = analyze_doctrine_loss_patterns(fleets)

    Enum.uniq(base_weaknesses ++ observed_weaknesses)
  end

  defp suggest_counter_composition(enemy_pattern) do
    case enemy_pattern.doctrine_type do
      :kiting ->
        %{
          doctrine: :anti_kite,
          key_ships: ["Orthrus", "Lachesis", "Huginn"],
          support: ["Keres", "Maulus"]
        }

      :brawling ->
        %{
          doctrine: :kiting,
          key_ships: ["Cerberus", "Eagle", "Osprey Navy Issue"],
          support: ["Scimitar", "Kirin"]
        }

      :alpha ->
        %{
          doctrine: :buffer_tank,
          key_ships: ["Drake Navy Issue", "Ferox", "Hurricane Fleet Issue"],
          support: ["Basilisk", "Scimitar"]
        }

      _ ->
        %{
          doctrine: :balanced,
          key_ships: ["Muninn", "Vagabond"],
          support: ["Scimitar", "Sabre"]
        }
    end
  end

  defp identify_counter_ships(enemy_pattern) do
    weaknesses = enemy_pattern.weaknesses

    ships = []

    ships =
      if Enum.member?(weaknesses, "Vulnerable to hard tackle") do
        ["Lachesis", "Arazu", "Huginn" | ships]
      else
        ships
      end

    ships =
      if Enum.member?(weaknesses, "Limited range control") do
        ["Cerberus", "Eagle", "Tengu" | ships]
      else
        ships
      end

    Enum.take(Enum.uniq(ships), 5)
  end

  defp generate_enemy_counter_tactics(enemy_pattern) do
    case enemy_pattern.engagement_preferences.engagement_style do
      :hit_and_run ->
        ["Use heavy tackle", "Set up gate camps", "Force commitment with bubbles"]

      :sustained_brawl ->
        ["Maintain range advantage", "Use damps/tracking disruptors", "Avoid close range"]

      :alpha_strike ->
        ["Split fleet positioning", "Use buffer tanks", "Rapid target switches"]

      _ ->
        ["Adapt to enemy movements", "Maintain intel coverage", "Flexible positioning"]
    end
  end

  defp identify_required_pilot_skills(enemy_pattern) do
    case enemy_pattern.doctrine_type do
      :kiting -> ["Range control", "Manual piloting", "Transversal management"]
      :brawling -> ["Overheating", "Cap management", "Target calling"]
      :alpha -> ["Fleet warping", "Align timing", "Primary following"]
      _ -> ["General fleet discipline", "Broadcast watching", "Anchor following"]
    end
  end

  defp categorize_fleet_use_case(composition) do
    role_counts = composition.role_counts
    fleet_size = composition.fleet_size

    cond do
      fleet_size < 10 and Map.get(role_counts, :tackle, 0) > 0 ->
        :small_gang_roam

      fleet_size > 30 and Map.get(role_counts, :logistics, 0) > 3 ->
        :fleet_warfare

      Map.get(role_counts, :ewar, 0) > 2 ->
        :ewar_support

      Map.get(role_counts, :tackle, 0) > 3 ->
        :fast_tackle

      true ->
        :general_purpose
    end
  end

  defp calculate_role_skill_distribution(participants) do
    skill_levels = Enum.map(participants, & &1.skill_level)

    %{
      average: calculate_average_skill(skill_levels),
      distribution: Enum.frequencies(skill_levels)
    }
  end

  defp aggregate_successful_ships(participants) do
    participants
    |> Enum.filter(&(&1.success_rate > 0.6))
    |> Enum.flat_map(& &1.ships_flown)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_ship, count} -> -count end)
    |> Enum.take(3)
    |> Enum.map(fn {ship, _count} -> ship end)
  end

  defp identify_phase_transitions(timeline) do
    timeline
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.filter(fn [prev, curr] ->
      prev.phase != curr.phase
    end)
    |> Enum.map(fn [_prev, curr] ->
      %{
        time: curr.timestamp,
        new_phase: curr.phase,
        trigger: curr.trigger_event
      }
    end)
  end

  defp calculate_optimal_duration(efficiency_curve) do
    # Find duration where efficiency starts declining
    peak_efficiency = Enum.max_by(efficiency_curve, & &1.efficiency)

    %{
      optimal_minutes: peak_efficiency.time_minutes,
      efficiency_drop_threshold: peak_efficiency.efficiency * 0.8
    }
  end

  defp identify_critical_combat_phases(timeline) do
    timeline
    |> Enum.group_by(& &1.phase)
    |> Enum.map(fn {phase, events} ->
      %{
        phase: phase,
        duration: calculate_phase_duration(events),
        casualties: count_phase_casualties(events),
        importance: calculate_phase_importance(phase, events)
      }
    end)
    |> Enum.filter(&(&1.importance > 0.7))
  end

  defp generate_timing_recommendations(phase_transitions) do
    if length(phase_transitions) > 2 do
      ["Consider shorter engagements", "Implement phased withdrawal", "Set engagement timers"]
    else
      ["Maintain current engagement patterns", "Quick decisive strikes working well"]
    end
  end

  defp determine_doctrine_preferred_range(fleets) do
    ranges = fleets |> Enum.map(& &1.engagement_range) |> Enum.filter(& &1)

    if length(ranges) > 0 do
      avg_range = Enum.sum(ranges) / length(ranges)

      cond do
        avg_range < 10 -> :close
        avg_range < 30 -> :medium
        true -> :long
      end
    else
      :unknown
    end
  end

  defp assess_doctrine_mobility(fleets) do
    # Simplified mobility assessment
    avg_speed =
      fleets
      |> Enum.map(& &1.average_speed)
      |> Enum.filter(& &1)
      |> case do
        [] -> 0
        speeds -> Enum.sum(speeds) / length(speeds)
      end

    cond do
      avg_speed > 2000 -> :high
      avg_speed > 1000 -> :medium
      true -> :low
    end
  end

  defp identify_common_tank_type(fleets) do
    tank_types = fleets |> Enum.map(& &1.tank_type) |> Enum.filter(& &1)

    if length(tank_types) > 0 do
      tank_types
      |> Enum.frequencies()
      |> Enum.max_by(fn {_type, count} -> count end)
      |> elem(0)
    else
      :unknown
    end
  end

  defp categorize_engagement_style(fleets) do
    # Analyze engagement patterns
    avg_duration =
      fleets
      |> Enum.map(& &1.engagement_duration)
      |> Enum.filter(& &1)
      |> case do
        [] -> 0
        durations -> Enum.sum(durations) / length(durations)
      end

    cond do
      avg_duration < 300 -> :hit_and_run
      avg_duration < 900 -> :skirmish
      avg_duration < 1800 -> :sustained_brawl
      true -> :siege_warfare
    end
  end

  defp analyze_doctrine_loss_patterns(fleets) do
    # Extract patterns from losses
    loss_causes =
      fleets
      |> Enum.flat_map(& &1.loss_analysis)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_cause, count} -> -count end)
      |> Enum.take(3)
      |> Enum.map(fn {cause, _count} -> cause end)

    loss_causes
  end

  defp calculate_average_skill(_skill_levels), do: 3.0
  defp calculate_phase_duration(_events), do: 300
  defp count_phase_casualties(_events), do: 5
  defp calculate_phase_importance(_phase, _events), do: 0.8

  # Force multiplication helper functions
  defp identify_force_multipliers(compositions, metrics) do
    %{
      ewar_effectiveness: analyze_ewar_impact(compositions),
      logi_multiplication: calculate_logistics_impact(compositions),
      command_boost_impact: estimate_command_boost_effect(compositions),
      intel_advantage: metrics.intel_quality || 0.5,
      positioning_advantage: analyze_positioning_advantages(compositions)
    }
  end

  defp determine_force_mult_priority(force_multipliers) do
    max_impact =
      force_multipliers
      |> Map.values()
      |> Enum.max()

    cond do
      max_impact > 0.8 -> :critical
      max_impact > 0.6 -> :high
      max_impact > 0.4 -> :medium
      true -> :low
    end
  end

  defp generate_force_mult_actions(force_multipliers) do
    actions = []

    actions =
      if force_multipliers.ewar_effectiveness < 0.5 do
        ["Add EWAR support (Falcon, Rook, Blackbird)" | actions]
      else
        actions
      end

    actions =
      if force_multipliers.logi_multiplication < 0.6 do
        ["Increase logistics numbers or train T2 logi" | actions]
      else
        actions
      end

    actions =
      if force_multipliers.command_boost_impact < 0.4 do
        ["Add command ships for fleet boosts" | actions]
      else
        actions
      end

    actions =
      if force_multipliers.intel_advantage < 0.7 do
        ["Improve intel coverage with scouts/spies" | actions]
      else
        actions
      end

    if Enum.empty?(actions) do
      ["Maintain current force multiplication levels"]
    else
      actions
    end
  end

  defp generate_weakness_based_scenarios(weaknesses) do
    Enum.map(weaknesses, fn weakness ->
      case weakness.type do
        :low_tank ->
          %{
            name: "Tank Improvement Drill",
            focus: "Survivability training",
            ships: ["Buffer tanked ships", "Logistics support"],
            objectives: [
              "Broadcast for reps quickly",
              "Manage capacitor",
              "Overheat appropriately"
            ]
          }

        :poor_positioning ->
          %{
            name: "Fleet Positioning Practice",
            focus: "Anchor and movement training",
            ships: ["Standard fleet comp"],
            objectives: ["Maintain optimal range", "Follow anchor", "Avoid bumping"]
          }

        :target_calling ->
          %{
            name: "Target Priority Training",
            focus: "FC and DPS coordination",
            ships: ["Mixed fleet composition"],
            objectives: ["Quick target switches", "Primary/secondary calling", "Spread points"]
          }

        _ ->
          %{
            name: "General Combat Drill",
            focus: "Overall improvement",
            ships: ["Varied composition"],
            objectives: ["Follow broadcasts", "Maintain discipline", "Execute tactics"]
          }
      end
    end)
  end

  defp generate_tactical_drill_scenarios(insights) do
    base_scenarios = []

    # Add scenarios based on insights
    scenarios =
      if Map.get(insights, :needs_anti_kite, false) do
        [
          %{
            name: "Anti-Kite Practice",
            focus: "Catching kiters",
            ships: ["Lachesis", "Huginn", "Raptor"],
            objectives: ["Web/scram coordination", "Slingshot maneuvers", "Range control"]
          }
          | base_scenarios
        ]
      else
        base_scenarios
      end

    scenarios =
      if Map.get(insights, :needs_anti_blob, false) do
        [
          %{
            name: "Fighting Outnumbered",
            focus: "Asymmetric warfare",
            ships: ["Kiting ships", "Bomber support"],
            objectives: ["Hit and run tactics", "Target isolation", "Disengagement"]
          }
          | scenarios
        ]
      else
        scenarios
      end

    scenarios
  end

  # Helper functions for force multiplication analysis
  defp analyze_ewar_impact(compositions) do
    ewar_ships =
      compositions
      |> Enum.flat_map(& &1.ships)
      |> Enum.filter(&is_ewar_ship?/1)
      |> length()

    total_ships =
      compositions
      |> Enum.map(& &1.fleet_size)
      |> Enum.sum()

    if total_ships > 0 do
      # 10% EWAR is max effectiveness
      min(1.0, ewar_ships / total_ships * 10)
    else
      0.0
    end
  end

  defp calculate_logistics_impact(compositions) do
    logi_ratio =
      compositions
      |> Enum.map(fn comp ->
        logi_count = Map.get(comp.role_counts, :logistics, 0)

        if comp.fleet_size > 0 do
          logi_count / comp.fleet_size
        else
          0.0
        end
      end)
      |> Enum.max(fn -> 0.0 end)

    # Optimal is around 20-25% logistics
    cond do
      logi_ratio > 0.25 -> 0.9
      logi_ratio > 0.20 -> 1.0
      logi_ratio > 0.15 -> 0.8
      logi_ratio > 0.10 -> 0.6
      true -> 0.3
    end
  end

  defp estimate_command_boost_effect(compositions) do
    command_ships =
      compositions
      |> Enum.flat_map(& &1.ships)
      |> Enum.filter(&is_command_ship?/1)
      |> length()

    if command_ships > 0 do
      # Each command ship adds 30% effectiveness
      min(1.0, command_ships * 0.3)
    else
      0.0
    end
  end

  defp analyze_positioning_advantages(_compositions) do
    # Simplified positioning analysis
    # Neutral positioning by default
    0.5
  end

  defp is_ewar_ship?(ship_name) do
    ewar_ships = [
      "Falcon",
      "Rook",
      "Blackbird",
      "Kitsune",
      "Keres",
      "Maulus",
      "Arazu",
      "Lachesis"
    ]

    Enum.member?(ewar_ships, ship_name)
  end

  defp is_command_ship?(ship_name) do
    command_ships = [
      "Claymore",
      "Vulture",
      "Astarte",
      "Sleipnir",
      "Eos",
      "Damnation",
      "Absolution",
      "Nighthawk",
      "Bifrost",
      "Magus",
      "Pontifex",
      "Stork"
    ]

    Enum.member?(command_ships, ship_name)
  end

  # Doctrine adjustment helper functions
  defp analyze_doctrine_composition_weaknesses(fleet_comps) do
    fleet_comps
    |> Enum.flat_map(fn comp ->
      weaknesses = []

      # Check for lack of tackle
      weaknesses =
        if Map.get(comp.role_counts, :tackle, 0) < 2 do
          [%{type: :insufficient_tackle, severity: :high} | weaknesses]
        else
          weaknesses
        end

      # Check for lack of logistics
      logi_ratio = Map.get(comp.role_counts, :logistics, 0) / max(comp.fleet_size, 1)

      weaknesses =
        if logi_ratio < 0.15 do
          [%{type: :insufficient_logistics, severity: :critical} | weaknesses]
        else
          weaknesses
        end

      # Check for lack of EWAR
      weaknesses =
        if Map.get(comp.role_counts, :ewar, 0) == 0 and comp.fleet_size > 10 do
          [%{type: :no_ewar_support, severity: :medium} | weaknesses]
        else
          weaknesses
        end

      weaknesses
    end)
    |> Enum.uniq()
  end

  defp determine_doctrine_adjustment_priority(weaknesses) do
    critical_count = Enum.count(weaknesses, &(&1.severity == :critical))
    high_count = Enum.count(weaknesses, &(&1.severity == :high))

    cond do
      critical_count > 0 -> :urgent
      high_count > 1 -> :high
      high_count > 0 -> :medium
      true -> :low
    end
  end

  defp generate_doctrine_adjustment_actions(weaknesses) do
    Enum.map(weaknesses, fn weakness ->
      case weakness.type do
        :insufficient_tackle ->
          "Add 2-3 dedicated tackle pilots (Sabre, Stiletto, Lachesis)"

        :insufficient_logistics ->
          "Increase logistics to 20-25% of fleet (Guardian, Scimitar)"

        :no_ewar_support ->
          "Include 1-2 EWAR ships for larger fleets (Falcon, Blackbird)"

        :poor_damage_application ->
          "Add webifiers and target painters for better application"

        _ ->
          "Review and adjust fleet composition"
      end
    end)
  end

  # Skill gap analysis helper functions
  defp analyze_tactical_execution_gaps(insights) do
    gaps = []

    gaps =
      if Map.get(insights, :poor_focus_fire, false) do
        [
          %{
            skill_type: :target_calling,
            description: "Improve primary/secondary target calling",
            training_focus: ["FC communication", "DPS discipline"]
          }
          | gaps
        ]
      else
        gaps
      end

    gaps =
      if Map.get(insights, :positioning_issues, false) do
        [
          %{
            skill_type: :fleet_movement,
            description: "Better fleet positioning and anchoring",
            training_focus: ["Anchor skills", "Range management", "Transversal"]
          }
          | gaps
        ]
      else
        gaps
      end

    gaps =
      if Map.get(insights, :poor_logi_coordination, false) do
        [
          %{
            skill_type: :logistics_coordination,
            description: "Improve logistics broadcast response",
            training_focus: ["Watchlist management", "Broadcast priorities", "Cap chain"]
          }
          | gaps
        ]
      else
        gaps
      end

    gaps
  end

  defp generate_skill_gap_analysis(skill_gaps) do
    Enum.map(skill_gaps, fn gap ->
      %{
        area: gap.skill_type,
        current_level: estimate_current_skill_level(gap),
        target_level: determine_target_skill_level(gap),
        training_plan: create_skill_training_plan(gap),
        estimated_time: estimate_training_time(gap)
      }
    end)
  end

  defp estimate_current_skill_level(skill_gap) do
    # Simplified estimation based on gap severity
    case skill_gap do
      %{skill_type: :target_calling} -> 2
      %{skill_type: :fleet_movement} -> 2
      %{skill_type: :logistics_coordination} -> 3
      _ -> 3
    end
  end

  defp determine_target_skill_level(_skill_gap) do
    # Always aim for max skill
    5
  end

  defp create_skill_training_plan(skill_gap) do
    skill_gap.training_focus
  end

  defp estimate_training_time(skill_gap) do
    current = estimate_current_skill_level(skill_gap)
    target = determine_target_skill_level(skill_gap)

    # Rough estimate: 1 week per skill level
    "#{target - current} weeks"
  end

  # Performance gap analysis
  defp analyze_performance_gaps(metrics) do
    gaps = []

    # Check ISK efficiency
    gaps =
      if Map.get(metrics, :isk_efficiency, 50) < 40 do
        [
          %{
            skill_type: :target_selection,
            description: "Improve target value assessment",
            training_focus: ["Target prioritization", "ISK efficiency awareness"]
          }
          | gaps
        ]
      else
        gaps
      end

    # Check survival rate
    gaps =
      if Map.get(metrics, :survival_rate, 0.5) < 0.3 do
        [
          %{
            skill_type: :survival_skills,
            description: "Improve survival and escape tactics",
            training_focus: ["Overheating", "Escape routes", "Defensive flying"]
          }
          | gaps
        ]
      else
        gaps
      end

    gaps
  end

  # Doctrine weakness analysis helpers
  defp check_role_coverage(fleet_comps) do
    fleet_comps
    |> Enum.flat_map(fn comp ->
      missing_roles = []

      # Check essential roles
      missing_roles =
        if Map.get(comp.role_counts, :tackle, 0) == 0 do
          [%{type: :no_tackle, impact: :critical, description: "No tackle ships"}]
        else
          missing_roles
        end

      missing_roles =
        if Map.get(comp.role_counts, :logistics, 0) == 0 and comp.fleet_size > 5 do
          [%{type: :no_logistics, impact: :high, description: "No logistics support"}]
        else
          missing_roles
        end

      missing_roles
    end)
  end

  defp check_ship_synergy(fleet_comps) do
    fleet_comps
    |> Enum.flat_map(fn comp ->
      synergy_issues = []

      # Check for mixed weapon systems
      if has_mixed_weapon_systems?(comp) do
        [
          %{
            type: :mixed_weapons,
            impact: :medium,
            description: "Mixed weapon systems reduce effectiveness"
          }
          | synergy_issues
        ]
      else
        synergy_issues
      end
    end)
  end

  defp generate_weakness_analysis(weaknesses) do
    grouped = Enum.group_by(weaknesses, & &1.impact)

    %{
      critical_issues: Map.get(grouped, :critical, []) |> Enum.map(& &1.description),
      high_impact: Map.get(grouped, :high, []) |> Enum.map(& &1.description),
      medium_impact: Map.get(grouped, :medium, []) |> Enum.map(& &1.description),
      total_score: calculate_weakness_score(weaknesses)
    }
  end

  defp weakness_to_recommendation(weakness) do
    case weakness.type do
      :no_tackle ->
        "Add dedicated tackle ships immediately"

      :no_logistics ->
        "Include logistics ships for fleets > 5 pilots"

      :mixed_weapons ->
        "Standardize weapon systems for better fleet cohesion"

      :insufficient_dps ->
        "Increase DPS ship ratio to 60-70% of fleet"

      _ ->
        "Review and adjust fleet doctrine"
    end
  end

  defp has_mixed_weapon_systems?(comp) do
    # Simplified check - would need ship fitting data
    Map.get(comp, :has_mixed_weapons, false)
  end

  defp calculate_weakness_score(weaknesses) do
    Enum.reduce(weaknesses, 0, fn weakness, score ->
      case weakness.impact do
        :critical -> score + 10
        :high -> score + 5
        :medium -> score + 2
        _ -> score + 1
      end
    end)
  end

  # Fleet composition gap analysis
  defp analyze_side_composition_gaps(side, composition) do
    gaps = []

    # Check role balance
    role_counts = Map.get(composition, :role_counts, %{})
    fleet_size = Map.get(composition, :fleet_size, 0)

    gaps =
      if fleet_size > 0 do
        dps_ratio = Map.get(role_counts, :dps, 0) / fleet_size

        cond do
          dps_ratio < 0.5 ->
            [
              %{
                side: side,
                type: :insufficient_dps,
                severity: :high,
                description: "DPS ratio below 50%"
              }
              | gaps
            ]

          dps_ratio > 0.8 ->
            [
              %{
                side: side,
                type: :excessive_dps,
                severity: :medium,
                description: "DPS ratio above 80%, lacks support"
              }
              | gaps
            ]

          true ->
            gaps
        end
      else
        gaps
      end

    gaps
  end

  defp analyze_cross_side_gaps(fleet_compositions) do
    # Analyze gaps between different sides/fleets
    if length(fleet_compositions) > 1 do
      [first | rest] = fleet_compositions

      Enum.flat_map(rest, fn other_fleet ->
        size_diff = abs(first.fleet_size - other_fleet.fleet_size)

        if size_diff > 10 do
          [
            %{
              type: :size_imbalance,
              severity: :high,
              description: "Significant fleet size imbalance (#{size_diff} pilots)"
            }
          ]
        else
          []
        end
      end)
    else
      []
    end
  end

  # Missing function implementations

  defp check_support_ship_ratios(analysis) do
    ship_counts = get_in(analysis, [:fleet_analysis, :ship_counts]) || %{}
    total_ships = ship_counts |> Map.values() |> Enum.sum()

    if total_ships > 0 do
      logi_count = Map.get(ship_counts, :logistics, 0)
      ewar_count = Map.get(ship_counts, :ewar, 0)

      %{
        logistics_ratio: logi_count / total_ships,
        ewar_ratio: ewar_count / total_ships,
        support_adequate: logi_count / total_ships >= 0.1
      }
    else
      %{logistics_ratio: 0, ewar_ratio: 0, support_adequate: false}
    end
  end

  defp calculate_pattern_confidence(patterns) when is_list(patterns) do
    if Enum.empty?(patterns) do
      0
    else
      # Average confidence across all patterns
      total_confidence =
        patterns
        |> Enum.map(&extract_confidence/1)
        |> Enum.sum()

      total_confidence / length(patterns)
    end
  end

  defp extract_confidence(pattern) do
    case pattern do
      %{confidence: conf} when is_number(conf) -> conf
      %{strength: :strong} -> 80
      %{strength: :moderate} -> 60
      %{strength: :weak} -> 40
      _ -> 50
    end
  end

  defp extract_patterns_from_battle(battle) do
    patterns = []

    # Extract doctrine patterns
    doctrine_patterns = extract_doctrine_patterns(battle)
    patterns = patterns ++ doctrine_patterns

    # Extract tactical patterns
    tactical_patterns = extract_tactical_patterns(battle)
    patterns = patterns ++ tactical_patterns

    # Extract timing patterns
    timing_patterns = extract_timing_patterns(battle)
    patterns = patterns ++ timing_patterns

    patterns
  end

  defp extract_doctrine_patterns(battle) do
    doctrines = get_in(battle, [:fleet_analysis, :doctrines]) || []

    Enum.map(doctrines, fn doctrine ->
      %{
        type: :doctrine,
        name: doctrine.name,
        ship_count: doctrine.ship_count,
        confidence: doctrine.confidence || 70
      }
    end)
  end

  defp extract_tactical_patterns(battle) do
    initial_patterns = []

    # Check for kiting pattern
    patterns_with_kiting =
      if get_in(battle, [:engagement_analysis, :engagement_style]) == :kiting do
        [%{type: :tactical, name: :kiting, confidence: 80} | initial_patterns]
      else
        initial_patterns
      end

    # Check for brawling pattern
    final_patterns =
      if get_in(battle, [:engagement_analysis, :engagement_style]) == :brawling do
        [%{type: :tactical, name: :brawling, confidence: 80} | patterns_with_kiting]
      else
        patterns_with_kiting
      end

    final_patterns
  end

  defp extract_timing_patterns(battle) do
    phases = get_in(battle, [:timeline_analysis, :phases]) || []

    if length(phases) > 1 do
      [%{type: :timing, name: :multi_phase_engagement, confidence: 90}]
    else
      []
    end
  end

  defp pattern_to_recommendations(pattern) do
    case pattern do
      %{type: :doctrine, name: name} ->
        ["Consider counters to #{name} doctrine", "Prepare appropriate ship compositions"]

      %{type: :tactical, name: :kiting} ->
        ["Use fast tackle to close range", "Consider long-range weapons"]

      %{type: :tactical, name: :brawling} ->
        ["Maintain range control", "Use kiting tactics"]

      %{type: :timing, name: :multi_phase_engagement} ->
        ["Prepare for extended engagement", "Manage capacitor and ammunition"]

      _ ->
        []
    end
  end

  defp determine_overall_effectiveness_trend(battles) when is_list(battles) do
    if length(battles) < 2 do
      :insufficient_data
    else
      effectiveness_scores = Enum.map(battles, &calculate_battle_effectiveness/1)

      # Calculate trend
      recent_avg = effectiveness_scores |> Enum.take(3) |> average()
      older_avg = effectiveness_scores |> Enum.drop(3) |> Enum.take(3) |> average()

      cond do
        recent_avg > older_avg * 1.1 -> :improving
        recent_avg < older_avg * 0.9 -> :declining
        true -> :stable
      end
    end
  end

  defp calculate_battle_effectiveness(battle) do
    isk_efficiency = get_in(battle, [:outcome_analysis, :isk_efficiency]) || 0.5
    kill_efficiency = get_in(battle, [:outcome_analysis, :kill_efficiency]) || 0.5
    objective_success = if get_in(battle, [:outcome_analysis, :victor]), do: 1.0, else: 0.0

    (isk_efficiency + kill_efficiency + objective_success) / 3
  end

  defp average(list) when is_list(list) and length(list) > 0 do
    Enum.sum(list) / length(list)
  end

  defp average(_), do: 0

  defp calculate_metric_trend(battles, metric_path) do
    if length(battles) < 2 do
      %{trend: :insufficient_data, change: 0}
    else
      values =
        battles
        |> Enum.map(&get_in(&1, metric_path))
        |> Enum.reject(&is_nil/1)

      if length(values) < 2 do
        %{trend: :insufficient_data, change: 0}
      else
        recent = values |> Enum.take(3) |> average()
        older = values |> Enum.drop(3) |> Enum.take(3) |> average()

        change = if older > 0, do: (recent - older) / older * 100, else: 0

        trend =
          cond do
            change > 10 -> :improving
            change < -10 -> :declining
            true -> :stable
          end

        %{trend: trend, change: Float.round(change, 1)}
      end
    end
  end

  defp calculate_strategic_impact(battle) do
    initial_impact = 0

    # System importance
    system_value = get_in(battle, [:metadata, :system_strategic_value]) || 50
    impact_with_system = initial_impact + system_value * 0.3

    # Battle scale
    participant_count = get_in(battle, [:metadata, :unique_participants]) || 0
    impact_with_scale = impact_with_system + min(30, participant_count * 0.5)

    # ISK destroyed
    total_value = get_in(battle, [:outcome_analysis, :total_isk_destroyed]) || 0

    isk_impact =
      cond do
        # 10B+
        total_value > 10_000_000_000 -> 30
        # 1B+
        total_value > 1_000_000_000 -> 20
        # 100M+
        total_value > 100_000_000 -> 10
        true -> 5
      end

    impact_with_isk = impact_with_scale + isk_impact

    # Cap fights have strategic importance
    final_impact =
      if get_in(battle, [:fleet_analysis, :capital_presence]) do
        impact_with_isk + 20
      else
        impact_with_isk
      end

    min(100, final_impact)
  end

  defp calculate_tactical_success(battle) do
    initial_metrics = []

    # Objective completion
    metrics_with_objectives =
      if get_in(battle, [:outcome_analysis, :objectives_achieved]) do
        [100 | initial_metrics]
      else
        [0 | initial_metrics]
      end

    # ISK efficiency
    isk_eff = get_in(battle, [:outcome_analysis, :isk_efficiency]) || 0.5
    metrics_with_isk = [isk_eff * 100 | metrics_with_objectives]

    # Kill/Death ratio
    kd_ratio = get_in(battle, [:outcome_analysis, :kill_death_ratio]) || 1.0
    kd_score = min(100, kd_ratio * 50)
    final_metrics = [kd_score | metrics_with_isk]

    # Average the metrics
    if Enum.empty?(final_metrics) do
      50
    else
      Enum.sum(final_metrics) / length(final_metrics)
    end
  end

  defp extract_isk_efficiency(battle) do
    case battle do
      %{outcome_analysis: %{isk_efficiency: eff}} ->
        eff

      %{statistics: %{isk_destroyed: destroyed, isk_lost: lost}} when lost > 0 ->
        destroyed / lost

      _ ->
        1.0
    end
  end

  defp extract_kill_efficiency(battle) do
    case battle do
      %{outcome_analysis: %{kill_efficiency: eff}} ->
        eff

      %{statistics: %{kills: kills, losses: losses}} when losses > 0 ->
        kills / losses

      _ ->
        1.0
    end
  end

  defp determine_doctrine_evolution_pattern(battles) do
    doctrine_usage =
      battles
      |> Enum.map(&extract_doctrine_usage/1)
      |> Enum.reject(&Enum.empty?/1)

    if length(doctrine_usage) < 3 do
      :insufficient_data
    else
      # Check for doctrine shifts
      recent_doctrines = doctrine_usage |> Enum.take(3) |> List.flatten() |> Enum.uniq()

      older_doctrines =
        doctrine_usage |> Enum.drop(3) |> Enum.take(3) |> List.flatten() |> Enum.uniq()

      new_doctrines = MapSet.difference(MapSet.new(recent_doctrines), MapSet.new(older_doctrines))

      abandoned_doctrines =
        MapSet.difference(MapSet.new(older_doctrines), MapSet.new(recent_doctrines))

      cond do
        MapSet.size(new_doctrines) > 2 -> :rapid_innovation
        MapSet.size(new_doctrines) > 0 -> :gradual_evolution
        MapSet.size(abandoned_doctrines) > 0 -> :doctrine_refinement
        true -> :stable_doctrine
      end
    end
  end

  defp extract_doctrine_usage(battle) do
    case get_in(battle, [:fleet_analysis, :doctrines]) do
      doctrines when is_list(doctrines) ->
        Enum.map(doctrines, & &1.name)

      _ ->
        []
    end
  end

  defp calculate_doctrine_success_rates(battles, _timeframe) do
    # Group battles by doctrine
    doctrine_results =
      battles
      |> Enum.flat_map(&expand_battle_by_doctrines/1)
      |> Enum.group_by(& &1.doctrine)
      |> Enum.map(fn {doctrine, doctrine_battles} ->
        wins = Enum.count(doctrine_battles, & &1.won)
        total = length(doctrine_battles)
        success_rate = if total > 0, do: wins / total, else: 0

        {doctrine,
         %{
           battles: total,
           wins: wins,
           success_rate: Float.round(success_rate * 100, 1)
         }}
      end)
      |> Map.new()

    doctrine_results
  end

  defp expand_battle_by_doctrines(battle) do
    doctrines = get_in(battle, [:fleet_analysis, :doctrines]) || []

    won =
      get_in(battle, [:outcome_analysis, :victor]) == get_in(battle, [:metadata, :analyzed_side])

    Enum.map(doctrines, fn doctrine ->
      %{
        doctrine: doctrine.name,
        won: won,
        battle_id: get_in(battle, [:metadata, :battle_id])
      }
    end)
  end

  defp identify_most_used_doctrines(battles) do
    battles
    |> Enum.flat_map(&extract_doctrine_usage/1)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_doctrine, count} -> count end, :desc)
    |> Enum.take(5)
    |> Enum.map(fn {doctrine, count} -> %{name: doctrine, usage_count: count} end)
  end

  defp analyze_doctrine_effectiveness(success_rates, usage_counts) do
    # Combine success rates with usage to find effective doctrines
    all_doctrines =
      MapSet.union(
        MapSet.new(Map.keys(success_rates)),
        MapSet.new(Enum.map(usage_counts, & &1.name))
      )

    all_doctrines
    |> Enum.map(fn doctrine ->
      success_data = Map.get(success_rates, doctrine, %{success_rate: 0, battles: 0})
      usage_data = Enum.find(usage_counts, %{usage_count: 0}, &(&1.name == doctrine))

      effectiveness_score =
        calculate_doctrine_effectiveness_score(
          success_data.success_rate,
          success_data.battles,
          usage_data.usage_count
        )

      %{
        doctrine: doctrine,
        success_rate: success_data.success_rate,
        battle_count: success_data.battles,
        usage_count: usage_data.usage_count,
        effectiveness_score: effectiveness_score,
        rating: rate_doctrine_effectiveness(effectiveness_score)
      }
    end)
    |> Enum.sort_by(& &1.effectiveness_score, :desc)
  end

  defp calculate_doctrine_effectiveness_score(success_rate, battles, usage_count) do
    # Weight success rate by number of battles for reliability
    reliability_factor = min(1.0, battles / 10)
    weighted_success = success_rate * reliability_factor

    # Factor in usage (popular doctrines that win are very effective)
    usage_factor = min(1.0, usage_count / 20)

    weighted_success * 0.7 + usage_factor * 30
  end

  defp rate_doctrine_effectiveness(score) do
    cond do
      score >= 80 -> :highly_effective
      score >= 60 -> :effective
      score >= 40 -> :moderately_effective
      score >= 20 -> :marginally_effective
      true -> :ineffective
    end
  end

  defp calculate_doctrine_usage_stability(battles) do
    # Get doctrine usage over time windows
    usage_windows =
      battles
      |> Enum.chunk_every(5)
      |> Enum.map(&calculate_window_doctrine_distribution/1)

    if length(usage_windows) < 2 do
      # Not enough data, assume stable
      1.0
    else
      # Calculate variance between windows
      calculate_distribution_variance(usage_windows)
    end
  end

  defp calculate_window_doctrine_distribution(window_battles) do
    total_doctrines =
      window_battles
      |> Enum.flat_map(&extract_doctrine_usage/1)
      |> length()

    if total_doctrines == 0 do
      %{}
    else
      window_battles
      |> Enum.flat_map(&extract_doctrine_usage/1)
      |> Enum.frequencies()
      |> Enum.map(fn {doctrine, count} ->
        {doctrine, count / total_doctrines}
      end)
      |> Map.new()
    end
  end

  defp calculate_distribution_variance(distributions) do
    all_doctrines =
      distributions
      |> Enum.flat_map(&Map.keys/1)
      |> Enum.uniq()

    variances =
      all_doctrines
      |> Enum.map(fn doctrine ->
        values = Enum.map(distributions, &Map.get(&1, doctrine, 0))
        calculate_variance(values)
      end)

    avg_variance = if Enum.empty?(variances), do: 0, else: Enum.sum(variances) / length(variances)

    # Convert to stability score (inverse of variance)
    1 - min(1, avg_variance * 10)
  end

  defp calculate_variance(values) do
    if Enum.empty?(values) do
      0
    else
      mean = Enum.sum(values) / length(values)

      sum_squares =
        values
        |> Enum.map(fn v -> (v - mean) * (v - mean) end)
        |> Enum.sum()

      sum_squares / length(values)
    end
  end

  defp find_dominant_doctrine(effectiveness_analysis) do
    effectiveness_analysis
    |> Enum.filter(&(&1.effectiveness_score >= 60))
    |> Enum.filter(&(&1.battle_count >= 3))
    |> List.first()
    |> case do
      nil -> nil
      doctrine -> doctrine.doctrine
    end
  end

  defp generate_positioning_actions(recommendations, phase_specific_actions) do
    base_actions = []

    # Extract positioning-related recommendations
    positioning_recs =
      recommendations
      |> Enum.filter(&String.contains?(&1, ["range", "kite", "close", "position"]))

    base_actions = base_actions ++ positioning_recs

    # Add phase-specific positioning
    phase_actions =
      phase_specific_actions
      |> Enum.flat_map(fn {_phase, actions} ->
        Enum.filter(actions, &String.contains?(&1, ["position", "range", "anchor"]))
      end)

    base_actions = base_actions ++ phase_actions

    # Add general positioning principles if none found
    if Enum.empty?(base_actions) do
      [
        "Maintain optimal range for your weapons",
        "Stay aligned to celestials",
        "Watch for enemy tackle"
      ]
    else
      Enum.uniq(base_actions)
    end
  end
end
