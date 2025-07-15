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
        case fetch_battle_killmails(battle_id) do
          {:error, reason} ->
            {:reply, {:error, reason}, state}

          {:ok, killmails} ->
            with {:ok, timeline} <- construct_battle_timeline(killmails),
                 {:ok, participants} <- extract_battle_participants(killmails),
                 {:ok, fleet_analysis} <- analyze_fleet_compositions(participants, killmails),
                 {:ok, tactical_analysis} <- perform_tactical_analysis(timeline, fleet_analysis),
                 {:ok, performance_metrics} <-
                   calculate_performance_metrics(killmails, participants) do
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
    case fetch_recent_system_kills(system_id, 300) do
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

  defp fetch_battle_killmails(battle_id) do
    # Fetch killmails related to a specific battle
    # For now, we'll extract system_id and time range from battle_id
    # In a real implementation, this would query a battle_killmails junction table
    Logger.debug("Fetching killmails for battle #{battle_id}")

    # Parse battle_id to extract system_id and time range
    # Format: "system_#{system_id}_#{unix_timestamp}"
    case String.split(battle_id, "_") do
      ["system", system_id_str, timestamp_str] ->
        with {system_id, ""} <- Integer.parse(system_id_str),
             {timestamp, ""} <- Integer.parse(timestamp_str) do
          # Create intelligent time window around the battle based on activity patterns
          battle_time = DateTime.from_unix!(timestamp)
          {start_time, end_time} = calculate_optimal_battle_window(system_id, battle_time)

          query = """
          SELECT 
            killmail_id,
            killmail_time,
            killmail_hash,
            solar_system_id,
            victim_character_id,
            victim_corporation_id,
            victim_alliance_id,
            victim_ship_type_id,
            attacker_count,
            raw_data,
            source
          FROM killmails_raw
          WHERE solar_system_id = $1
            AND killmail_time >= $2
            AND killmail_time <= $3
          ORDER BY killmail_time ASC
          """

          case Ecto.Adapters.SQL.query(EveDmv.Repo, query, [system_id, start_time, end_time]) do
            {:ok, %{rows: rows}} ->
              killmails =
                Enum.map(rows, fn [
                                    killmail_id,
                                    killmail_time,
                                    killmail_hash,
                                    solar_system_id,
                                    victim_character_id,
                                    victim_corporation_id,
                                    victim_alliance_id,
                                    victim_ship_type_id,
                                    attacker_count,
                                    raw_data,
                                    source
                                  ] ->
                  %{
                    killmail_id: killmail_id,
                    killmail_time: killmail_time,
                    killmail_hash: killmail_hash,
                    solar_system_id: solar_system_id,
                    victim_character_id: victim_character_id,
                    victim_corporation_id: victim_corporation_id,
                    victim_alliance_id: victim_alliance_id,
                    victim_ship_type_id: victim_ship_type_id,
                    attacker_count: attacker_count,
                    raw_data: raw_data,
                    source: source,
                    # Extract additional fields from raw_data
                    total_value: get_in(raw_data, ["zkb", "totalValue"]) || 0,
                    attackers: raw_data["attackers"] || [],
                    victim: raw_data["victim"] || %{}
                  }
                end)

              Logger.debug("Found #{length(killmails)} killmails for battle #{battle_id}")
              {:ok, killmails}

            {:error, error} ->
              Logger.error("Database error fetching battle killmails: #{inspect(error)}")
              {:error, :database_error}
          end
        else
          _ ->
            Logger.warning("Invalid battle_id format: #{battle_id}")
            {:error, :invalid_battle_id}
        end

      _ ->
        Logger.warning("Invalid battle_id format: #{battle_id}")
        {:error, :invalid_battle_id}
    end
  rescue
    error ->
      Logger.error("Exception fetching battle killmails: #{inspect(error)}")
      {:error, :fetch_failed}
  end

  defp fetch_recent_system_kills(system_id, seconds_back) do
    # Fetch recent kills in a specific system
    Logger.debug("Fetching kills in system #{system_id} from last #{seconds_back} seconds")

    # Calculate the time window
    cutoff_time = DateTime.add(DateTime.utc_now(), -seconds_back, :second)

    query = """
    SELECT 
      killmail_id,
      killmail_time,
      killmail_hash,
      solar_system_id,
      victim_character_id,
      victim_corporation_id,
      victim_alliance_id,
      victim_ship_type_id,
      attacker_count,
      raw_data,
      source
    FROM killmails_raw
    WHERE solar_system_id = $1
      AND killmail_time >= $2
    ORDER BY killmail_time DESC
    LIMIT 500
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query, [system_id, cutoff_time]) do
      {:ok, %{rows: rows}} ->
        killmails =
          Enum.map(rows, fn [
                              killmail_id,
                              killmail_time,
                              killmail_hash,
                              solar_system_id,
                              victim_character_id,
                              victim_corporation_id,
                              victim_alliance_id,
                              victim_ship_type_id,
                              attacker_count,
                              raw_data,
                              source
                            ] ->
            %{
              killmail_id: killmail_id,
              killmail_time: killmail_time,
              killmail_hash: killmail_hash,
              solar_system_id: solar_system_id,
              victim_character_id: victim_character_id,
              victim_corporation_id: victim_corporation_id,
              victim_alliance_id: victim_alliance_id,
              victim_ship_type_id: victim_ship_type_id,
              attacker_count: attacker_count,
              raw_data: raw_data,
              source: source,
              # Extract additional fields from raw_data for analysis
              total_value: get_in(raw_data, ["zkb", "totalValue"]) || 0,
              attackers: raw_data["attackers"] || [],
              victim: raw_data["victim"] || %{}
            }
          end)

        Logger.debug(
          "Found #{length(killmails)} killmails in system #{system_id} from last #{seconds_back} seconds"
        )

        {:ok, killmails}

      {:error, error} ->
        Logger.error("Database error fetching recent system kills: #{inspect(error)}")
        {:error, :database_error}
    end
  rescue
    error ->
      Logger.error("Exception fetching recent system kills: #{inspect(error)}")
      {:error, :fetch_failed}
  end

  defp construct_battle_timeline(killmails) do
    timeline =
      killmails
      |> Enum.sort_by(& &1.killmail_time)
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
      |> Enum.sort_by(& &1.killmail_time)
      |> Enum.map(fn km ->
        event = %{
          timestamp: km.killmail_time,
          event_type: :kill,
          killmail_id: km.killmail_id,
          system_id: km.solar_system_id,
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
        acc =
          Map.put(acc, km.victim_character_id, %{
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
            existing =
              Map.get(acc2, char_id, %{
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
              existing
              | kills: existing.kills + if(attacker["final_blow"], do: 1, else: 0),
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

  defp analyze_fleet_compositions(participants, _killmails) do
    # Group participants by side
    sides =
      participants
      |> Map.values()
      |> Enum.group_by(& &1.side)

    fleet_comps =
      Map.new(sides, fn {side, side_participants} ->
        ship_composition = analyze_side_ship_composition(side_participants)

        {side,
         %{
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
      |> Enum.group_by(& &1.side)

    by_side =
      sides
      |> Enum.map(fn {side, side_participants} ->
        {side,
         %{
           kills: Enum.sum(Enum.map(side_participants, & &1.kills)),
           losses: Enum.sum(Enum.map(side_participants, & &1.losses)),
           isk_destroyed: calculate_side_isk_destroyed(side, killmails),
           isk_lost: calculate_side_isk_lost(side, killmails),
           efficiency: calculate_side_efficiency(side, killmails),
           k_d_ratio: calculate_side_kd_ratio(side_participants)
         }}
      end)
      |> Map.new()

    by_ship_class = analyze_ship_class_performance(killmails, participants)
    top_performers = identify_top_performers(participants)

    {:ok,
     %{
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

  defp calculate_total_isk_destroyed(killmails) do
    Enum.sum(Enum.map(killmails, &(&1.total_value || 0)))
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

  defp identify_battle_phases(_timeline) do
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

  defp detect_doctrine_usage(_ship_composition) do
    # Detect common doctrine patterns
    nil
  end

  defp calculate_average_efficiency(participants) do
    total_kills = Enum.sum(Enum.map(participants, & &1.kills))
    total_losses = Enum.sum(Enum.map(participants, & &1.losses))

    if total_losses > 0 do
      total_kills / total_losses
    else
      total_kills
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

  defp detect_ewar_presence(_ship_composition) do
    # Detect electronic warfare ships
    false
  end

  defp identify_tactical_patterns(timeline) do
    # Identify common tactical patterns from the engagement timeline
    patterns = []

    # Pattern 1: Alpha strike (many kills in short time)
    patterns = patterns ++ identify_alpha_strike_pattern(timeline)

    # Pattern 2: Kiting (consistent damage over time with minimal losses)
    patterns = patterns ++ identify_kiting_pattern(timeline)

    # Pattern 3: Brawling (high kill rate on both sides)
    patterns = patterns ++ identify_brawling_pattern(timeline)

    patterns
  end

  defp identify_alpha_strike_pattern(timeline) do
    # Group kills by 30-second windows
    windows =
      Enum.chunk_by(timeline, fn event ->
        div(DateTime.to_unix(event.timestamp), 30)
      end)

    # Find windows with high kill concentration
    alpha_strikes =
      windows
      |> Enum.filter(fn window -> length(window) >= 3 end)
      |> Enum.map(fn window ->
        %{
          pattern: :alpha_strike,
          timestamp: List.first(window).timestamp,
          kills: length(window),
          duration_seconds: 30
        }
      end)

    alpha_strikes
  end

  defp identify_kiting_pattern(_timeline) do
    # TODO: Implement kiting pattern detection algorithm
    # Should analyze for:
    # - Consistent damage over time with minimal losses
    # - Range-based engagement patterns
    # - Hit-and-run tactical indicators
    # Related to Sprint 15 IMPL-15: Complete tactical pattern extraction
    []
  end

  defp identify_brawling_pattern(_timeline) do
    # TODO: Implement brawling pattern detection algorithm
    # Should analyze for:
    # - High reciprocal damage patterns
    # - Close-range engagement indicators
    # - Simultaneous kill/loss events
    # Related to Sprint 15 IMPL-15: Complete tactical pattern extraction
    []
  end

  defp identify_key_moments(timeline) do
    # Identify significant moments in the battle
    moments = []

    # Find high-value kills (top 10% by ISK value)
    if length(timeline) > 0 do
      isk_values = Enum.map(timeline, & &1.isk_value)
      threshold = Enum.max(isk_values) * 0.9

      high_value_kills =
        timeline
        |> Enum.filter(&(&1.isk_value >= threshold))
        |> Enum.map(fn event ->
          %{
            type: :high_value_kill,
            timestamp: event.timestamp,
            isk_value: event.isk_value,
            victim: event.victim
          }
        end)

      moments = moments ++ high_value_kills
      moments
    end

    # Find first blood
    moments =
      if first_kill = List.first(timeline) do
        [
          %{
            type: :first_blood,
            timestamp: first_kill.timestamp,
            victim: first_kill.victim
          }
          | moments
        ]
      else
        moments
      end

    # Sort by timestamp
    Enum.sort_by(moments, & &1.timestamp)
  end

  defp identify_turning_points(timeline, fleet_analysis) do
    # Identify moments where battle momentum shifted
    turning_points = []

    # Analyze kill rate changes over time
    if length(timeline) >= 5 do
      # Group kills into 2-minute windows
      windows =
        timeline
        |> Enum.chunk_by(fn event ->
          div(DateTime.to_unix(event.timestamp), 120)
        end)
        |> Enum.filter(fn window -> length(window) > 0 end)

      # Calculate kill rates for each side per window
      window_stats =
        Enum.map(windows, fn window ->
          side_a_kills =
            Enum.count(window, fn event ->
              victim_side = determine_victim_side(event.victim, fleet_analysis)
              victim_side == :side_b
            end)

          side_b_kills =
            Enum.count(window, fn event ->
              victim_side = determine_victim_side(event.victim, fleet_analysis)
              victim_side == :side_a
            end)

          %{
            timestamp: List.first(window).timestamp,
            side_a_kills: side_a_kills,
            side_b_kills: side_b_kills,
            momentum: side_a_kills - side_b_kills
          }
        end)

      # Find momentum shifts
      turning_points =
        window_stats
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.filter(fn [prev, curr] ->
          # Momentum reversed
          (prev.momentum > 0 and curr.momentum < 0) or
            (prev.momentum < 0 and curr.momentum > 0)
        end)
        |> Enum.map(fn [_prev, curr] ->
          %{
            type: :momentum_shift,
            timestamp: curr.timestamp,
            new_momentum: curr.momentum
          }
        end)

      turning_points
    end

    turning_points
  end

  defp determine_victim_side(victim, fleet_analysis) do
    cond do
      victim.corporation_id in Map.keys(fleet_analysis.side_a.corporations) -> :side_a
      victim.corporation_id in Map.keys(fleet_analysis.side_b.corporations) -> :side_b
      true -> :unknown
    end
  end

  defp analyze_engagement_flow(timeline) do
    # Analyze the flow and phases of the engagement
    phases = identify_battle_phases_detailed(timeline)
    intensity_changes = identify_intensity_changes(timeline)

    %{
      phases: phases,
      intensity_changes: intensity_changes
    }
  end

  defp identify_battle_phases_detailed(timeline) do
    # Identify distinct phases based on kill clustering
    if length(timeline) < 3 do
      []
    else
      # Find gaps of more than 5 minutes between kills
      phases =
        timeline
        |> Enum.chunk_while(
          [],
          fn event, acc ->
            case acc do
              [] ->
                {:cont, [event]}

              _ ->
                last_event = List.last(acc)
                gap_seconds = DateTime.diff(event.timestamp, last_event.timestamp)

                # 5 minute gap
                if gap_seconds > 300 do
                  {:cont, acc, [event]}
                else
                  {:cont, acc ++ [event]}
                end
            end
          end,
          fn
            [] -> {:cont, []}
            acc -> {:cont, acc, []}
          end
        )
        |> Enum.reject(&Enum.empty?/1)
        |> Enum.with_index(1)
        |> Enum.map(fn {phase_events, index} ->
          %{
            phase_number: index,
            start_time: List.first(phase_events).timestamp,
            end_time: List.last(phase_events).timestamp,
            duration_seconds:
              DateTime.diff(
                List.last(phase_events).timestamp,
                List.first(phase_events).timestamp
              ),
            kills: length(phase_events),
            intensity:
              length(phase_events) /
                max(
                  DateTime.diff(
                    List.last(phase_events).timestamp,
                    List.first(phase_events).timestamp
                  ) / 60,
                  1
                )
          }
        end)

      phases
    end
  end

  defp identify_intensity_changes(timeline) do
    # Calculate rolling kill rate and find significant changes
    if length(timeline) < 5 do
      []
    else
      # Calculate kills per minute in 3-minute windows
      intensities =
        timeline
        |> Enum.chunk_every(3, 1, :discard)
        |> Enum.map(fn window ->
          duration_minutes =
            DateTime.diff(
              List.last(window).timestamp,
              List.first(window).timestamp
            ) / 60

          %{
            # Middle of window
            timestamp: Enum.at(window, 1).timestamp,
            kills_per_minute:
              if(duration_minutes > 0, do: length(window) / duration_minutes, else: 0)
          }
        end)

      # Find significant intensity changes (>50% change)
      intensity_changes =
        intensities
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.filter(fn [prev, curr] ->
          change_ratio =
            if prev.kills_per_minute > 0 do
              abs(curr.kills_per_minute - prev.kills_per_minute) / prev.kills_per_minute
            else
              1.0
            end

          change_ratio > 0.5
        end)
        |> Enum.map(fn [prev, curr] ->
          %{
            timestamp: curr.timestamp,
            previous_intensity: Float.round(prev.kills_per_minute, 2),
            new_intensity: Float.round(curr.kills_per_minute, 2),
            change_type:
              if(curr.kills_per_minute > prev.kills_per_minute,
                do: :escalation,
                else: :deescalation
              )
          }
        end)

      intensity_changes
    end
  end

  defp analyze_focus_fire(timeline) do
    # Analyze how well fleets focused their damage
    if length(timeline) < 2 do
      %{
        effectiveness: 0.0,
        coordination_score: 0.0
      }
    else
      # Group kills by 30-second windows
      windows =
        timeline
        |> Enum.chunk_by(fn event ->
          div(DateTime.to_unix(event.timestamp), 30)
        end)
        |> Enum.filter(fn window -> length(window) > 1 end)

      if Enum.empty?(windows) do
        %{
          effectiveness: 0.0,
          coordination_score: 0.0
        }
      else
        # Calculate focus fire metrics for each window
        window_metrics =
          Enum.map(windows, fn window ->
            # Count unique targets
            unique_targets =
              window
              |> Enum.map(& &1.victim.character_id)
              |> Enum.uniq()
              |> length()

            # Perfect focus fire = 1 target per window
            focus_score = 1.0 / unique_targets

            # Time spread - how close together were the kills
            time_score =
              if length(window) > 1 do
                time_spread =
                  DateTime.diff(
                    List.last(window).timestamp,
                    List.first(window).timestamp
                  )

                # Normalize to 0-1 where <10s = 1.0
                max(0, 1.0 - time_spread / 30.0)
              else
                1.0
              end

            %{
              focus_score: focus_score,
              time_score: time_score,
              kills: length(window)
            }
          end)

        # Weight by number of kills in each window
        total_kills = Enum.sum(Enum.map(window_metrics, & &1.kills))

        weighted_focus =
          window_metrics
          |> Enum.map(&(&1.focus_score * &1.kills))
          |> Enum.sum()
          |> Kernel./(total_kills)

        weighted_coordination =
          window_metrics
          |> Enum.map(&(&1.time_score * &1.kills))
          |> Enum.sum()
          |> Kernel./(total_kills)

        %{
          effectiveness: Float.round(weighted_focus, 3),
          coordination_score: Float.round(weighted_coordination, 3)
        }
      end
    end
  end

  defp analyze_target_selection(timeline, _fleet_analysis) do
    # Analyze target prioritization effectiveness
    if Enum.empty?(timeline) do
      %{
        priority_targets_hit: 0.0,
        target_switching_rate: 0.0
      }
    else
      # Identify priority targets (logistics, fleet commanders, high-value ships)
      priority_kills =
        timeline
        |> Enum.filter(fn event ->
          ship_class = classify_ship(event.victim.ship_type_id)
          # 1B+ ISK
          ship_class in [:logistics, :strategic_cruiser, :capital] or
            event.isk_value > 1_000_000_000
        end)

      priority_ratio =
        if length(timeline) > 0 do
          Float.round(length(priority_kills) / length(timeline), 3)
        else
          0.0
        end

      # Calculate target switching rate
      target_switches =
        timeline
        |> Enum.map(& &1.victim.character_id)
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.count(fn [prev, curr] -> prev != curr end)

      switching_rate =
        if length(timeline) > 1 do
          Float.round(target_switches / (length(timeline) - 1), 3)
        else
          0.0
        end

      %{
        priority_targets_hit: priority_ratio,
        target_switching_rate: switching_rate
      }
    end
  end

  defp calculate_side_isk_destroyed(side, killmails) do
    # Sum ISK value of all kills made by this side
    killmails
    |> Enum.filter(fn km ->
      # Check if any attacker is from this side
      Enum.any?(km.attackers || [], fn attacker ->
        corp_id = attacker["corporation_id"]
        corp_id && corp_id in Map.keys(side.corporations)
      end)
    end)
    |> Enum.map(&(&1.total_value || 0))
    |> Enum.sum()
  end

  defp calculate_side_isk_lost(side, killmails) do
    # Sum ISK value of all losses by this side
    killmails
    |> Enum.filter(fn km ->
      # Check if victim is from this side
      km.victim_corporation_id in Map.keys(side.corporations)
    end)
    |> Enum.map(&(&1.total_value || 0))
    |> Enum.sum()
  end

  defp calculate_side_efficiency(side, killmails) do
    # Calculate ISK efficiency: destroyed / (destroyed + lost) * 100
    destroyed = calculate_side_isk_destroyed(side, killmails)
    lost = calculate_side_isk_lost(side, killmails)

    total = destroyed + lost

    if total > 0 do
      Float.round(destroyed / total * 100, 2)
    else
      # No activity = neutral efficiency
      50.0
    end
  end

  defp calculate_side_kd_ratio(_participants) do
    # TODO: Implement actual kill/death ratio calculation
    # Should calculate: total_kills / max(total_deaths, 1)
    # Related to Sprint 15 IMPL-3: Implement battle intensity calculations
    1.0
  end

  defp analyze_ship_class_performance(_killmails, _participants) do
    # TODO: Implement ship class performance analysis
    # Should analyze:
    # - Effectiveness by ship class (frigate, cruiser, battleship, etc.)
    # - Class-specific kill/loss ratios
    # - Tactical role performance metrics
    # Related to Sprint 15 IMPL-5: Implement basic fleet composition analysis
    %{}
  end

  defp identify_top_performers(participants) do
    participants
    |> Map.values()
    |> Enum.sort_by(& &1.kills, :desc)
    |> Enum.take(10)
  end

  defp calculate_kill_rate(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      first_kill = List.first(killmails)
      last_kill = List.last(killmails)
      duration_minutes = DateTime.diff(last_kill.killmail_time, first_kill.killmail_time) / 60

      if duration_minutes > 0 do
        length(killmails) / duration_minutes
      else
        0.0
      end
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

  defp calculate_intensity_curve(_timeline) do
    # Calculate kills per minute over time
    []
  end

  defp track_participant_flow(_timeline) do
    # Track when participants join/leave battle
    %{
      joiners: [],
      leavers: []
    }
  end

  defp identify_common_patterns(_battle_analyses) do
    []
  end

  defp analyze_tactical_evolution(_battle_analyses) do
    []
  end

  defp compare_effectiveness_trends(_battle_analyses) do
    %{}
  end

  defp compare_doctrine_usage(_battle_analyses) do
    %{}
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

  defp analyze_fleet_composition_gaps(_fleet_compositions) do
    []
  end

  defp generate_pattern_based_recommendations(_patterns) do
    []
  end

  defp analyze_strategic_positioning(_battle_analysis) do
    nil
  end

  defp recommend_force_multiplication(_battle_analysis) do
    nil
  end

  defp suggest_engagement_timing(_battle_analysis) do
    nil
  end

  defp recommend_doctrine_adjustments(_fleet_comps) do
    nil
  end

  defp suggest_counter_doctrines(_fleet_comps) do
    nil
  end

  defp identify_doctrine_weaknesses(_fleet_comps) do
    nil
  end

  defp identify_skill_gaps(_battle_analysis) do
    nil
  end

  defp recommend_practice_scenarios(_battle_analysis) do
    nil
  end

  defp suggest_role_specializations(_battle_analysis) do
    nil
  end

  defp evaluate_doctrine_effectiveness(_fleet_analysis) do
    %{}
  end

  defp determine_battle_winner(_performance_metrics) do
    :undetermined
  end

  defp analyze_victory_factors(tactical_analysis, performance_metrics) do
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

  # Calculate intelligent time window around a battle based on activity patterns
  defp calculate_optimal_battle_window(system_id, battle_time) do
    # Get killmail activity around the battle time to determine optimal window
    # Look 1 hour before
    base_start = DateTime.add(battle_time, -60 * 60, :second)
    # Look 1 hour after
    base_end = DateTime.add(battle_time, 60 * 60, :second)

    # Query for killmail activity in the system around this time
    activity_query = """
    SELECT 
      killmail_time,
      COUNT(*) as kill_count
    FROM killmails_enriched 
    WHERE solar_system_id = $1 
      AND killmail_time BETWEEN $2 AND $3
    GROUP BY 
      DATE_TRUNC('minute', killmail_time)
    ORDER BY killmail_time
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, activity_query, [
           system_id,
           base_start,
           base_end
         ]) do
      {:ok, %{rows: [_ | _] = rows}} ->
        # Analyze activity pattern to find optimal bounds
        analyze_activity_pattern(rows, battle_time)

      {:error, reason} ->
        Logger.warning("Failed to analyze battle activity pattern: #{inspect(reason)}")
        # Fallback to 30-minute window
        default_battle_window(battle_time)

      _ ->
        # No activity data, use default window
        default_battle_window(battle_time)
    end
  rescue
    error ->
      Logger.error("Error calculating optimal battle window: #{inspect(error)}")
      default_battle_window(battle_time)
  end

  defp analyze_activity_pattern(activity_rows, battle_time) do
    # Convert activity data to time/count pairs
    activity_minutes =
      Enum.map(activity_rows, fn [timestamp, count] ->
        {timestamp, count}
      end)

    if Enum.empty?(activity_minutes) do
      default_battle_window(battle_time)
    else
      # Find the start and end of sustained activity
      battle_unix = DateTime.to_unix(battle_time)

      # Group activity into 5-minute windows for noise reduction
      smoothed_activity =
        activity_minutes
        |> Enum.chunk_every(5)
        |> Enum.map(fn chunk ->
          avg_time =
            chunk
            |> Enum.map(&elem(&1, 0))
            |> Enum.map(&DateTime.to_unix/1)
            |> Enum.sum()
            |> div(length(chunk))

          total_kills = chunk |> Enum.map(&elem(&1, 1)) |> Enum.sum()
          {avg_time, total_kills}
        end)

      # Find activity threshold (10% of peak activity)
      max_activity = smoothed_activity |> Enum.map(&elem(&1, 1)) |> Enum.max(fn -> 0 end)
      threshold = max(1, div(max_activity, 10))

      # Find start of significant activity before battle
      start_time =
        smoothed_activity
        |> Enum.filter(fn {time, _count} -> time <= battle_unix end)
        |> Enum.reverse()
        |> find_activity_start(threshold)
        |> case do
          # Default 30min before
          nil -> DateTime.add(battle_time, -30 * 60, :second)
          unix_time -> DateTime.from_unix!(unix_time)
        end

      # Find end of significant activity after battle  
      end_time =
        smoothed_activity
        |> Enum.filter(fn {time, _count} -> time >= battle_unix end)
        |> find_activity_end(threshold)
        |> case do
          # Default 30min after
          nil -> DateTime.add(battle_time, 30 * 60, :second)
          unix_time -> DateTime.from_unix!(unix_time)
        end

      # Ensure minimum 20-minute window and maximum 2-hour window
      min_start = DateTime.add(battle_time, -10 * 60, :second)
      max_start = DateTime.add(battle_time, -120 * 60, :second)
      min_end = DateTime.add(battle_time, 10 * 60, :second)
      max_end = DateTime.add(battle_time, 120 * 60, :second)

      final_start = max(start_time, max_start) |> min(min_start)
      final_end = max(end_time, min_end) |> min(max_end)

      {final_start, final_end}
    end
  end

  defp find_activity_start(reversed_activity, threshold) do
    # Find first period of low activity working backwards from battle
    reversed_activity
    |> Enum.find(fn {_time, count} -> count < threshold end)
    |> case do
      nil -> nil
      {time, _count} -> time
    end
  end

  defp find_activity_end(forward_activity, threshold) do
    # Find first period of low activity working forwards from battle
    forward_activity
    |> Enum.find(fn {_time, count} -> count < threshold end)
    |> case do
      nil -> nil
      {time, _count} -> time
    end
  end

  defp default_battle_window(battle_time) do
    # Default 30-minute window around battle
    start_time = DateTime.add(battle_time, -30 * 60, :second)
    end_time = DateTime.add(battle_time, 30 * 60, :second)
    {start_time, end_time}
  end
end
