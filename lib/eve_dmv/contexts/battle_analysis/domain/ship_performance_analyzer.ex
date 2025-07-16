defmodule EveDmv.Contexts.BattleAnalysis.Domain.ShipPerformanceAnalyzer do
  @moduledoc """
  Sophisticated ship performance analysis system for EVE Online PvP.

  Analyzes individual ship performance within battles by comparing actual combat
  effectiveness against theoretical capabilities. Provides deep insights into:

  - DPS Efficiency: Actual damage dealt vs theoretical maximum
  - Survivability Analysis: Time alive vs expected based on ship class and threats
  - Tactical Contribution: EWAR effectiveness, tackle success, logistics efficiency
  - Role Effectiveness: How well ships fulfilled their intended combat role
  - Performance Optimization: Suggestions for improved fitting and tactics

  Uses real combat data, ship statistics, and advanced algorithms to provide
  actionable intelligence for fleet commanders and individual pilots.
  """

  alias EveDmv.Eve.NameResolver

  require Logger
  # Performance analysis parameters

  @doc """
  Analyzes ship performance within a battle context.

  Takes battle data and performs comprehensive analysis of each ship's performance
  relative to its theoretical capabilities and tactical role.

  ## Parameters
  - battle: Battle struct with killmails and tactical analysis
  - options: Analysis options
    - :focus_ship - Analyze specific ship type ID
    - :performance_metrics - Which metrics to calculate (:all, :efficiency, :survivability)
    - :include_recommendations - Generate tactical recommendations (default: true)

  ## Returns
  {:ok, performance_analysis} with detailed ship performance data
  """
  def analyze_battle_performance(battle, options \\ []) do
    focus_ship = Keyword.get(options, :focus_ship)
    metrics = Keyword.get(options, :performance_metrics, :all)
    include_recommendations = Keyword.get(options, :include_recommendations, true)

    Logger.info("Analyzing ship performance for battle #{battle.battle_id}")

    start_time = System.monotonic_time(:millisecond)

    with {:ok, ship_instances} <- extract_ship_instances(battle) do
      if Enum.empty?(ship_instances) do
        # Return empty analysis structure when no ships found
        empty_analysis = %{
          top_performers: [],
          fleet_stats: %{
            avg_dps_efficiency: 0,
            avg_survivability: 0,
            coordination_score: 0,
            tactical_diversity: 0
          },
          ship_performances: [],
          comparative_metrics: %{
            top_performers: [],
            role_comparisons: %{},
            efficiency_rankings: [],
            survivability_rankings: [],
            overall_battle_analysis: %{}
          },
          battle_summary: %{
            total_ships_analyzed: 0,
            average_performance: 0,
            recommendations: []
          }
        }

        {:ok, empty_analysis}
      else
        with {:ok, performance_data} <- calculate_performance_metrics(ship_instances, metrics),
             {:ok, role_analysis} <- analyze_tactical_roles(performance_data, battle),
             {:ok, comparative_analysis} <- perform_comparative_analysis(role_analysis),
             {:ok, final_analysis} <-
               maybe_generate_recommendations(comparative_analysis, include_recommendations) do
          # Filter by focus ship if specified
          filtered_analysis =
            case focus_ship do
              nil -> final_analysis
              ship_type_id -> filter_by_ship_type(final_analysis, ship_type_id)
            end

          end_time = System.monotonic_time(:millisecond)
          duration_ms = end_time - start_time

          Logger.info("""
          Ship performance analysis completed in #{duration_ms}ms:
          - Ships analyzed: #{length(filtered_analysis.ship_performances)}
          - Metrics calculated: #{metrics}
          - Battle duration: #{battle.metadata.duration_minutes} minutes
          """)

          {:ok, filtered_analysis}
        end
      end
    end
  end

  @doc """
  Analyzes a ship's performance in a battle by comparing expected vs actual stats.

  Legacy API compatibility method for existing battle analysis system.

  ## Parameters
  - ship_data: Map containing character_id, ship_type_id, fitting data
  - battle_data: Map containing killmails, combat logs, timeline
  - options: Additional analysis options

  ## Returns
  {:ok, legacy_performance_analysis}
  """
  def analyze_ship_performance(ship_data, battle_data, _options \\ []) do
    with {:ok, expected_stats} <- calculate_expected_stats(ship_data),
         {:ok, actual_performance} <- extract_actual_performance(ship_data, battle_data),
         {:ok, efficiency_metrics} <-
           calculate_efficiency_metrics(expected_stats, actual_performance) do
      recommendations = generate_recommendations(efficiency_metrics, actual_performance)

      {:ok,
       %{
         ship_info: build_ship_info(ship_data),
         expected_stats: expected_stats,
         actual_performance: actual_performance,
         efficiency_metrics: efficiency_metrics,
         recommendations: recommendations
       }}
    end
  end

  @doc """
  Compares ship performance across multiple battles to identify patterns.

  Analyzes performance trends, identifies consistently high/low performers,
  and provides insights into ship effectiveness in different battle contexts.
  """
  def analyze_performance_trends(battles, ship_type_id) do
    Logger.info("Analyzing performance trends for ship type #{ship_type_id}")

    performance_data =
      battles
      |> Enum.map(&analyze_battle_performance(&1, focus_ship: ship_type_id))
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(&elem(&1, 1))

    trend_analysis = %{
      ship_type_id: ship_type_id,
      battles_analyzed: length(performance_data),
      performance_trends: calculate_performance_trends(performance_data),
      optimal_conditions: identify_optimal_conditions(performance_data),
      improvement_areas: identify_improvement_areas(performance_data)
    }

    {:ok, trend_analysis}
  end

  # Private analysis implementation

  defp extract_ship_instances(battle) do
    # Create ship instance records from BOTH victims AND attackers
    victim_instances =
      battle.killmails
      |> Enum.map(&create_victim_ship_instance/1)
      |> Enum.filter(&(&1 != nil))

    attacker_instances =
      battle.killmails
      |> Enum.flat_map(&create_attacker_ship_instances/1)
      |> Enum.filter(&(&1 != nil))
      # Remove duplicates (same character_id + ship_type_id combo)
      |> Enum.uniq_by(&{&1.character_id, &1.ship_type_id})
      # Remove attackers who are already in victims (they died later)
      |> Enum.reject(fn attacker ->
        Enum.any?(victim_instances, fn victim ->
          victim.character_id == attacker.character_id &&
            victim.ship_type_id == attacker.ship_type_id
        end)
      end)

    ship_instances = victim_instances ++ attacker_instances

    if Enum.empty?(ship_instances) do
      Logger.warning("No valid ship instances found in battle #{battle.battle_id}")
      {:ok, []}
    else
      # Add battle context to each instance
      enhanced_instances =
        Enum.map(ship_instances, fn instance ->
          Map.merge(instance, %{
            battle_context: extract_battle_context(battle, instance),
            tactical_phases: Map.get(battle.metadata, :battle_phases, [])
          })
        end)

      {:ok, enhanced_instances}
    end
  end

  defp create_victim_ship_instance(killmail) do
    # Extract comprehensive ship instance data
    %{
      killmail_id: killmail.killmail_id,
      ship_type_id: killmail.victim_ship_type_id,
      character_id: killmail.victim_character_id,
      corporation_id: killmail.victim_corporation_id,
      alliance_id: killmail.victim_alliance_id,
      solar_system_id: killmail.solar_system_id,
      death_time: killmail.killmail_time,

      # Combat context
      attackers: extract_attacker_data(killmail),
      final_blow: extract_final_blow_data(killmail),
      damage_taken: calculate_total_damage_taken(killmail),

      # Ship characteristics (estimated from type)
      ship_class: determine_ship_class(killmail.victim_ship_type_id),
      estimated_fitting: estimate_ship_fitting(killmail),
      theoretical_stats: get_theoretical_ship_stats(killmail.victim_ship_type_id)
    }
  end

  defp create_attacker_ship_instances(killmail) do
    # Extract ship instances for all attackers who participated
    case killmail.raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        attackers
        |> Enum.filter(fn attacker ->
          # Only include attackers with character_id and ship_type_id
          attacker["character_id"] && attacker["ship_type_id"]
        end)
        |> Enum.map(fn attacker ->
          %{
            killmail_id: killmail.killmail_id,
            ship_type_id: attacker["ship_type_id"],
            character_id: attacker["character_id"],
            corporation_id: attacker["corporation_id"],
            alliance_id: attacker["alliance_id"],
            solar_system_id: killmail.solar_system_id,
            # Attackers survived this engagement
            death_time: nil,

            # Combat context - their performance in this kill
            damage_dealt: attacker["damage_done"] || 0,
            got_final_blow: attacker["final_blow"] || false,
            weapon_type_id: attacker["weapon_type_id"],

            # Ship characteristics (estimated from type)
            ship_class: determine_ship_class(attacker["ship_type_id"]),
            estimated_fitting: estimate_ship_fitting_from_attacker(attacker),
            theoretical_stats: get_theoretical_ship_stats(attacker["ship_type_id"])
          }
        end)

      _ ->
        []
    end
  end

  defp extract_battle_context(battle, ship_instance) do
    %{
      battle_duration: battle.metadata.duration_minutes,
      battle_type: battle.metadata.battle_type,
      total_participants: battle.metadata.unique_participants,
      friendly_count: estimate_friendly_count(battle, ship_instance),
      hostile_count: estimate_hostile_count(battle, ship_instance),
      battle_intensity: calculate_battle_intensity(battle)
    }
  end

  defp extract_attacker_data(killmail) do
    case killmail.raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        attackers
        |> Enum.map(fn attacker ->
          %{
            character_id: attacker["character_id"],
            corporation_id: attacker["corporation_id"],
            alliance_id: attacker["alliance_id"],
            ship_type_id: attacker["ship_type_id"],
            weapon_type_id: attacker["weapon_type_id"],
            damage_done: attacker["damage_done"] || 0,
            final_blow: attacker["final_blow"] || false
          }
        end)

      _ ->
        []
    end
  end

  defp extract_final_blow_data(killmail) do
    attackers = extract_attacker_data(killmail)
    Enum.find(attackers, &(&1.final_blow == true))
  end

  defp calculate_total_damage_taken(killmail) do
    attackers = extract_attacker_data(killmail)
    Enum.sum(Enum.map(attackers, & &1.damage_done))
  end

  defp determine_ship_class(ship_type_id) do
    # Classify ships by type ID ranges (simplified)
    cond do
      ship_type_id in 580..700 -> :frigate
      ship_type_id in 420..450 -> :destroyer
      ship_type_id in 620..650 -> :cruiser
      ship_type_id in 540..570 -> :battlecruiser
      ship_type_id in 640..670 -> :battleship
      ship_type_id in 19_720..19_740 -> :capital
      ship_type_id in 28_650..28_710 -> :strategic_cruiser
      true -> :unknown
    end
  end

  defp estimate_ship_fitting(killmail) do
    # Analyze attacker weapons to infer victim's likely fitting
    attackers = extract_attacker_data(killmail)
    weapon_types = attackers |> Enum.map(& &1.weapon_type_id) |> Enum.filter(&(&1 != nil))

    # Heuristic fitting estimation based on damage patterns
    damage_profile = analyze_damage_profile(attackers)

    %{
      estimated_tank_type: infer_tank_type(damage_profile),
      estimated_range_profile: infer_range_profile(weapon_types),
      estimated_role: infer_ship_role(killmail.victim_ship_type_id, damage_profile)
    }
  end

  defp analyze_damage_profile(attackers) do
    total_damage = Enum.sum(Enum.map(attackers, & &1.damage_done))

    damage_by_type =
      attackers
      |> Enum.group_by(fn attacker ->
        classify_damage_type(attacker.weapon_type_id)
      end)
      |> Enum.map(fn {damage_type, attackers_of_type} ->
        damage_amount = Enum.sum(Enum.map(attackers_of_type, & &1.damage_done))
        {damage_type, damage_amount}
      end)
      |> Map.new()

    %{
      total_damage: total_damage,
      damage_breakdown: damage_by_type,
      primary_damage_type: get_primary_damage_type(damage_by_type)
    }
  end

  defp classify_damage_type(weapon_type_id) do
    # Simplified weapon classification
    cond do
      weapon_type_id in 3000..3100 -> :kinetic
      weapon_type_id in 3200..3300 -> :thermal
      weapon_type_id in 3400..3500 -> :explosive
      weapon_type_id in 3600..3700 -> :em
      true -> :unknown
    end
  end

  defp get_primary_damage_type(damage_breakdown) do
    damage_breakdown
    |> Enum.max_by(fn {_type, damage} -> damage end, fn -> {:unknown, 0} end)
    |> elem(0)
  end

  defp infer_tank_type(damage_profile) do
    # Simple heuristic based on damage sustained
    if damage_profile.total_damage > 50_000 do
      # Higher EHP suggests armor tank
      :armor
    else
      # Lower EHP suggests shield tank or frigate
      :shield
    end
  end

  defp infer_range_profile(weapon_types) do
    # Analyze weapon types to determine engagement range
    long_range_weapons = Enum.count(weapon_types, &is_long_range_weapon/1)
    total_weapons = length(weapon_types)

    if total_weapons > 0 and long_range_weapons / total_weapons > 0.5 do
      :long_range
    else
      :short_range
    end
  end

  defp is_long_range_weapon(weapon_type_id) do
    # Simplified long-range weapon detection
    # Example: railgun type IDs
    weapon_type_id in [2488, 2489, 2490]
  end

  defp infer_ship_role(ship_type_id, damage_profile) do
    ship_class = determine_ship_class(ship_type_id)

    case {ship_class, damage_profile.total_damage} do
      {:frigate, damage} when damage < 10_000 -> :tackle
      {:frigate, damage} when damage >= 10_000 -> :assault
      {:destroyer, _} -> :anti_frigate
      {:cruiser, damage} when damage < 30_000 -> :support
      {:cruiser, damage} when damage >= 30_000 -> :dps
      {:battlecruiser, _} -> :heavy_dps
      {:battleship, _} -> :main_dps
      {:capital, _} -> :capital_dps
      _ -> :unknown
    end
  end

  defp get_theoretical_ship_stats(ship_type_id) do
    # Theoretical ship statistics (would come from static data in production)
    ship_class = determine_ship_class(ship_type_id)

    base_stats =
      case ship_class do
        :frigate ->
          %{
            base_hp: 3000,
            base_dps: 150,
            base_speed: 300,
            base_sig: 40,
            expected_survival_time: 45
          }

        :destroyer ->
          %{
            base_hp: 8000,
            base_dps: 250,
            base_speed: 200,
            base_sig: 70,
            expected_survival_time: 90
          }

        :cruiser ->
          %{
            base_hp: 15_000,
            base_dps: 300,
            base_speed: 150,
            base_sig: 120,
            expected_survival_time: 120
          }

        :battlecruiser ->
          %{
            base_hp: 30_000,
            base_dps: 500,
            base_speed: 100,
            base_sig: 200,
            expected_survival_time: 180
          }

        :battleship ->
          %{
            base_hp: 60_000,
            base_dps: 700,
            base_speed: 80,
            base_sig: 300,
            expected_survival_time: 240
          }

        _ ->
          %{
            base_hp: 10_000,
            base_dps: 200,
            base_speed: 150,
            base_sig: 100,
            expected_survival_time: 120
          }
      end

    Map.put(base_stats, :ship_class, ship_class)
  end

  defp calculate_performance_metrics(ship_instances, :all) do
    performance_data =
      ship_instances
      |> Enum.map(fn instance ->
        # Calculate basic metrics first
        survivability_score = calculate_survivability_score(instance)
        enhanced_instance = Map.put(instance, :survivability_score, survivability_score)

        dps_efficiency = calculate_dps_efficiency(enhanced_instance)
        tactical_contribution = calculate_tactical_contribution(enhanced_instance)

        # Add calculated metrics to instance for composite calculations
        fully_enhanced_instance =
          enhanced_instance
          |> Map.put(:dps_efficiency, dps_efficiency)
          |> Map.put(:tactical_contribution, tactical_contribution)

        %{
          ship_instance: fully_enhanced_instance,
          survivability_score: survivability_score,
          dps_efficiency: dps_efficiency,
          tactical_contribution: tactical_contribution,
          role_effectiveness: calculate_role_effectiveness(fully_enhanced_instance),
          threat_assessment: calculate_threat_assessment(fully_enhanced_instance)
        }
      end)

    {:ok, performance_data}
  end

  defp calculate_performance_metrics(ship_instances, metric)
       when metric in [:efficiency, :survivability] do
    # Calculate only specific metrics for performance
    performance_data =
      ship_instances
      |> Enum.map(fn instance ->
        base_data = %{ship_instance: instance}

        case metric do
          :efficiency ->
            Map.put(base_data, :dps_efficiency, calculate_dps_efficiency(instance))

          :survivability ->
            Map.put(base_data, :survivability_score, calculate_survivability_score(instance))
        end
      end)

    {:ok, performance_data}
  end

  defp calculate_survivability_score(instance) do
    # Handle attackers who survived (no death_time)
    if instance.death_time == nil do
      # Attackers survived the entire battle
      battle_duration_seconds = round(instance.battle_context.battle_duration * 60)
      expected_survival_time = instance.theoretical_stats.expected_survival_time

      %{
        # Survived = above average performance
        raw_score: 1.5,
        context_adjusted_score: 1.5,
        normalized_score: 1.0,
        actual_survival_seconds: battle_duration_seconds,
        expected_survival_seconds: expected_survival_time,
        threat_multiplier: 1.0
      }
    else
      # Calculate how long the ship survived vs expectations
      battle_start_time = estimate_battle_start_time(instance)
      actual_survival_time = NaiveDateTime.diff(instance.death_time, battle_start_time, :second)
      expected_survival_time = instance.theoretical_stats.expected_survival_time

      base_score =
        if expected_survival_time > 0 do
          actual_survival_time / expected_survival_time
        else
          1.0
        end

      # Adjust for battle context
      threat_multiplier = calculate_threat_multiplier(instance)
      context_adjusted_score = base_score / threat_multiplier

      # Normalize to 0-1 scale
      normalized_score = min(1.0, max(0.0, context_adjusted_score))

      %{
        raw_score: base_score,
        context_adjusted_score: context_adjusted_score,
        normalized_score: normalized_score,
        actual_survival_seconds: actual_survival_time,
        expected_survival_seconds: expected_survival_time,
        threat_multiplier: threat_multiplier
      }
    end
  end

  defp calculate_dps_efficiency(instance) do
    # Estimate actual DPS based on damage taken and time in combat
    actual_damage_dealt = estimate_damage_dealt(instance)
    theoretical_max_dps = instance.theoretical_stats.base_dps
    combat_duration = estimate_combat_duration(instance)

    if combat_duration > 0 and theoretical_max_dps > 0 do
      actual_dps = actual_damage_dealt / combat_duration
      efficiency_ratio = actual_dps / theoretical_max_dps

      %{
        actual_dps: actual_dps,
        theoretical_dps: theoretical_max_dps,
        efficiency_ratio: min(1.0, efficiency_ratio),
        combat_duration_seconds: combat_duration,
        total_damage_dealt: actual_damage_dealt
      }
    else
      %{
        actual_dps: 0,
        theoretical_dps: theoretical_max_dps,
        efficiency_ratio: 0.0,
        combat_duration_seconds: 0,
        total_damage_dealt: 0
      }
    end
  end

  defp calculate_tactical_contribution(instance) do
    # Assess ship's contribution to tactical objectives
    role = instance.estimated_fitting.estimated_role

    base_contribution =
      case role do
        :tackle -> calculate_tackle_effectiveness(instance)
        :dps -> calculate_dps_contribution(instance)
        :support -> calculate_support_effectiveness(instance)
        :logistics -> calculate_logistics_effectiveness(instance)
        # Default moderate contribution
        _ -> 0.5
      end

    %{
      role: role,
      base_contribution: base_contribution,
      tactical_value: assess_tactical_value(instance, base_contribution),
      strategic_impact: assess_strategic_impact(instance)
    }
  end

  defp calculate_role_effectiveness(instance) do
    # How well did the ship fulfill its intended role?
    role = instance.estimated_fitting.estimated_role
    ship_class = instance.ship_class

    effectiveness =
      case {role, ship_class} do
        {:tackle, :frigate} ->
          calculate_tackle_effectiveness(instance)

        {:dps, class} when class in [:cruiser, :battlecruiser, :battleship] ->
          calculate_dps_effectiveness(instance)

        {:support, :cruiser} ->
          calculate_support_effectiveness(instance)

        _ ->
          calculate_generic_effectiveness(instance)
      end

    %{
      role: role,
      ship_class: ship_class,
      effectiveness_score: effectiveness,
      role_appropriateness: assess_role_appropriateness(role, ship_class)
    }
  end

  defp calculate_threat_assessment(instance) do
    # Assess the threat level this ship posed to enemies
    damage_potential = instance.theoretical_stats.base_dps
    survival_time = instance.survivability_score.actual_survival_seconds
    tactical_value = instance.estimated_fitting.estimated_role

    # Threat per minute
    raw_threat = damage_potential * (survival_time / 60)

    role_multiplier =
      case tactical_value do
        # Tackle ships are high threat
        :tackle -> 1.5
        # DPS ships are moderate-high threat
        :dps -> 1.2
        # Logistics are very high threat
        :logistics -> 2.0
        # Support ships are moderate threat
        :support -> 1.1
        _ -> 1.0
      end

    # Normalize to 0-10 scale
    normalized_threat = raw_threat * role_multiplier / 1000

    %{
      raw_threat_score: raw_threat,
      role_multiplier: role_multiplier,
      normalized_threat: min(10.0, normalized_threat),
      threat_classification: classify_threat_level(normalized_threat)
    }
  end

  defp estimate_battle_start_time(instance) do
    # Estimate when the battle started relative to this ship's death
    # This is a heuristic - in reality we'd use battle detection data
    # Convert to seconds (ensure integer)
    estimated_battle_duration = round(instance.battle_context.battle_duration * 60)

    if instance.death_time do
      NaiveDateTime.add(instance.death_time, -estimated_battle_duration, :second)
    else
      # For attackers without death_time, use battle end time minus duration
      # This is a fallback - ideally we'd have actual battle start time
      DateTime.utc_now()
      |> DateTime.to_naive()
      |> NaiveDateTime.add(-estimated_battle_duration, :second)
    end
  end

  defp calculate_threat_multiplier(instance) do
    # Calculate threat multiplier based on enemy composition
    hostile_count = instance.battle_context.hostile_count
    friendly_count = instance.battle_context.friendly_count

    # Base threat from numbers
    numbers_threat =
      if friendly_count > 0 do
        hostile_count / friendly_count
      else
        # Assume outnumbered if no friendlies
        2.0
      end

    # Adjust for battle intensity
    intensity_multiplier =
      case instance.battle_context.battle_intensity do
        :low -> 0.8
        :medium -> 1.0
        :high -> 1.3
        :extreme -> 1.6
        _ -> 1.0
      end

    base_multiplier = min(3.0, numbers_threat * intensity_multiplier)
    # Minimum 0.5x, maximum 3.0x threat
    max(0.5, base_multiplier)
  end

  defp estimate_damage_dealt(instance) do
    # Heuristic: estimate damage based on ship type and survival time
    base_dps = instance.theoretical_stats.base_dps
    survival_seconds = instance.survivability_score.actual_survival_seconds

    # Assume ship was dealing damage for 70% of survival time
    effective_combat_time = survival_seconds * 0.7
    base_dps * effective_combat_time
  end

  defp estimate_combat_duration(instance) do
    # Estimate how long the ship was actively in combat
    survival_time = instance.survivability_score.actual_survival_seconds
    # Minimum 30 seconds, 80% of survival time
    max(30, survival_time * 0.8)
  end

  defp calculate_tackle_effectiveness(instance) do
    # Effectiveness of tackle ships (simplified)
    survival_time = instance.survivability_score.actual_survival_seconds

    # Tackle ships are effective if they survive long enough to matter
    if survival_time > 45 do
      # Full effectiveness at 2+ minutes
      min(1.0, survival_time / 120)
    else
      # Partial effectiveness
      survival_time / 45
    end
  end

  defp calculate_dps_contribution(instance) do
    dps_efficiency = instance.dps_efficiency.efficiency_ratio
    survival_impact = min(1.0, instance.survivability_score.actual_survival_seconds / 120)

    dps_efficiency * 0.7 + survival_impact * 0.3
  end

  defp calculate_support_effectiveness(instance) do
    # Support ships are effective if they survive and fulfill support role
    survival_score = instance.survivability_score.normalized_score

    # Support effectiveness is primarily about staying alive to provide value
    # Base 20% for being present
    survival_score * 0.8 + 0.2
  end

  defp calculate_logistics_effectiveness(instance) do
    # Logistics ships are extremely valuable if they survive
    survival_time = instance.survivability_score.actual_survival_seconds

    if survival_time > 60 do
      # Full effectiveness at 3+ minutes
      min(1.0, survival_time / 180)
    else
      # Reduced effectiveness for short survival
      survival_time / 60 * 0.7
    end
  end

  defp calculate_dps_effectiveness(instance) do
    dps_score = instance.dps_efficiency.efficiency_ratio
    survivability = instance.survivability_score.normalized_score

    # DPS effectiveness is combination of damage output and staying alive
    dps_score * 0.6 + survivability * 0.4
  end

  defp calculate_generic_effectiveness(instance) do
    # Generic effectiveness for unknown roles
    survivability = instance.survivability_score.normalized_score
    estimated_dps = instance.dps_efficiency.efficiency_ratio

    survivability * 0.5 + estimated_dps * 0.5
  end

  defp assess_role_appropriateness(role, ship_class) do
    # How appropriate is this role for this ship class?
    appropriate_combinations = %{
      frigate: [:tackle, :assault, :scout],
      destroyer: [:anti_frigate, :dps],
      cruiser: [:dps, :support, :logistics, :tackle],
      battlecruiser: [:heavy_dps, :dps],
      battleship: [:main_dps, :dps],
      capital: [:capital_dps, :logistics]
    }

    expected_roles = Map.get(appropriate_combinations, ship_class, [])

    if role in expected_roles do
      :optimal
    else
      :suboptimal
    end
  end

  defp assess_tactical_value(instance, base_contribution) do
    # Assess overall tactical value considering context
    battle_type = instance.battle_context.battle_type
    role = instance.estimated_fitting.estimated_role

    role_value_in_context =
      case {battle_type, role} do
        # Tackle very valuable in small gangs
        {:small_gang, :tackle} -> 1.2
        # Logistics crucial in large fights
        {:large_gang, :logistics} -> 1.4
        # DPS important in fleet battles
        {:fleet_battle, :dps} -> 1.1
        _ -> 1.0
      end

    base_contribution * role_value_in_context
  end

  defp assess_strategic_impact(instance) do
    # Long-term strategic impact of this ship's performance
    survival_time = instance.survivability_score.actual_survival_seconds
    role = instance.estimated_fitting.estimated_role

    case role do
      :logistics when survival_time > 120 -> :high_impact
      :tackle when survival_time > 60 -> :medium_impact
      :dps when survival_time > 90 -> :medium_impact
      _ -> :low_impact
    end
  end

  defp classify_threat_level(normalized_threat) do
    cond do
      normalized_threat >= 8.0 -> :extreme_threat
      normalized_threat >= 6.0 -> :high_threat
      normalized_threat >= 4.0 -> :moderate_threat
      normalized_threat >= 2.0 -> :low_threat
      true -> :minimal_threat
    end
  end

  defp analyze_tactical_roles(performance_data, battle) do
    # Enhance performance data with advanced ship intelligence
    try do
      # Use ship intelligence bridge for enhanced analysis
      enhanced_performance_data =
        EveDmv.Integrations.ShipIntelligenceBridge.enhance_ship_performance_data(
          performance_data,
          %{fleet_analysis: extract_fleet_context(battle)}
        )

      # Apply existing tactical analysis with enhancements
      final_data =
        Enum.map(enhanced_performance_data, fn perf ->
          # Original tactical analysis
          base_tactical_analysis = %{
            role_clarity: assess_role_clarity(perf),
            role_execution: assess_role_execution(perf),
            team_coordination: assess_team_coordination(perf, battle),
            adaptation_score: assess_tactical_adaptation(perf)
          }

          # Enhanced tactical analysis from ship intelligence
          enhanced_tactical = perf[:enhanced_tactical_analysis] || %{}

          # Merge analyses
          combined_tactical = Map.merge(base_tactical_analysis, enhanced_tactical)

          Map.put(perf, :tactical_analysis, combined_tactical)
        end)

      {:ok, final_data}
    rescue
      error ->
        Logger.warning(
          "Ship intelligence enhancement failed, falling back to basic analysis: #{inspect(error)}"
        )

        # Fallback to original implementation
        enhanced_data =
          Enum.map(performance_data, fn perf ->
            tactical_analysis = %{
              role_clarity: assess_role_clarity(perf),
              role_execution: assess_role_execution(perf),
              team_coordination: assess_team_coordination(perf, battle),
              adaptation_score: assess_tactical_adaptation(perf)
            }

            Map.put(perf, :tactical_analysis, tactical_analysis)
          end)

        {:ok, enhanced_data}
    end
  end

  defp extract_fleet_context(battle) do
    # Extract fleet composition data for enhanced analysis
    try do
      ship_types =
        battle.killmails
        |> Enum.map(fn killmail ->
          case killmail do
            %{"victim" => %{"ship_type_id" => ship_type_id}} -> ship_type_id
            %{victim: %{ship_type_id: ship_type_id}} -> ship_type_id
            _ -> nil
          end
        end)
        |> Enum.filter(& &1)

      if length(ship_types) > 0 do
        EveDmv.Analytics.FleetAnalyzer.analyze_fleet_composition(ship_types)
      else
        nil
      end
    rescue
      error ->
        Logger.debug("Failed to extract fleet context: #{inspect(error)}")
        nil
    end
  end

  defp assess_role_clarity(performance) do
    # How clearly defined was this ship's role?
    role = performance.ship_instance.estimated_fitting.estimated_role
    appropriateness = performance.role_effectiveness.role_appropriateness

    case {role, appropriateness} do
      {role, :optimal} when role != :unknown -> :clear
      {_role, :optimal} -> :somewhat_clear
      {_role, :suboptimal} -> :unclear
    end
  end

  defp assess_role_execution(performance) do
    effectiveness = performance.role_effectiveness.effectiveness_score

    cond do
      effectiveness >= 0.8 -> :excellent
      effectiveness >= 0.6 -> :good
      effectiveness >= 0.4 -> :fair
      true -> :poor
    end
  end

  defp assess_team_coordination(performance, battle) do
    # Simplified team coordination assessment
    survival_time = performance.survivability_score.actual_survival_seconds
    battle_duration_seconds = battle.metadata.duration_minutes * 60

    participation_ratio = survival_time / battle_duration_seconds

    cond do
      participation_ratio >= 0.7 -> :high_coordination
      participation_ratio >= 0.4 -> :medium_coordination
      true -> :low_coordination
    end
  end

  defp assess_tactical_adaptation(performance) do
    # How well did the ship adapt to changing battle conditions?
    threat_score = performance.threat_assessment.normalized_threat
    survival_score = performance.survivability_score.normalized_score

    adaptation = survival_score / max(0.1, threat_score / 10)

    cond do
      adaptation >= 1.2 -> :excellent_adaptation
      adaptation >= 0.8 -> :good_adaptation
      adaptation >= 0.5 -> :fair_adaptation
      true -> :poor_adaptation
    end
  end

  defp perform_comparative_analysis(performance_data) do
    # Compare performance across ships in the battle
    ship_performances = Enum.map(performance_data, & &1)

    comparative_metrics = %{
      top_performers: identify_top_performers(ship_performances),
      role_comparisons: compare_by_role(ship_performances),
      efficiency_rankings: rank_by_efficiency(ship_performances),
      survivability_rankings: rank_by_survivability(ship_performances),
      overall_battle_analysis: analyze_overall_battle_performance(ship_performances)
    }

    # Calculate fleet statistics for template compatibility
    fleet_stats = %{
      avg_dps_efficiency: calculate_avg_dps_efficiency(ship_performances),
      avg_survivability: calculate_avg_survivability(ship_performances),
      coordination_score: calculate_coordination_score(ship_performances),
      tactical_diversity: calculate_tactical_diversity(ship_performances)
    }

    final_analysis = %{
      # Template-expected fields
      top_performers: comparative_metrics.top_performers,
      fleet_stats: fleet_stats,
      # Additional analysis data
      ship_performances: ship_performances,
      comparative_metrics: comparative_metrics,
      battle_summary: create_battle_performance_summary(ship_performances)
    }

    {:ok, final_analysis}
  end

  defp identify_top_performers(performances) do
    performances
    |> Enum.sort_by(
      fn perf ->
        # Composite score prioritizing effectiveness and tactical contribution
        # Reduce survivability weight since it only applies to ships that died
        survivability = perf.survivability_score.normalized_score
        effectiveness = perf.role_effectiveness.effectiveness_score
        tactical_value = perf.tactical_contribution.tactical_value

        # Higher weight on effectiveness and tactical value
        # Lower weight on survivability to avoid bias toward losses
        survivability * 0.15 + effectiveness * 0.5 + tactical_value * 0.35
      end,
      :desc
    )
    |> Enum.take(5)
    |> Enum.map(fn perf ->
      score =
        perf.survivability_score.normalized_score * 0.15 +
          perf.role_effectiveness.effectiveness_score * 0.5 +
          perf.tactical_contribution.tactical_value * 0.35

      # Add a note if this was a ship loss vs survival
      status =
        if perf.ship_instance.death_time do
          "Lost ship"
        else
          "Survived"
        end

      %{
        character_id: perf.ship_instance.character_id,
        character_name: NameResolver.character_name(perf.ship_instance.character_id),
        ship_type_id: perf.ship_instance.ship_type_id,
        ship_name: NameResolver.ship_name(perf.ship_instance.ship_type_id),
        performance_score: round(score * 100),
        role: perf.ship_instance.estimated_fitting.estimated_role,
        survivability_score: round(perf.survivability_score.normalized_score * 100),
        effectiveness_score: round(perf.role_effectiveness.effectiveness_score * 100),
        battle_status: status
      }
    end)
  end

  defp compare_by_role(performances) do
    performances
    |> Enum.group_by(& &1.ship_instance.estimated_fitting.estimated_role)
    |> Enum.map(fn {role, role_performances} ->
      {role, calculate_role_statistics(role_performances)}
    end)
    |> Map.new()
  end

  defp calculate_role_statistics(role_performances) do
    if Enum.empty?(role_performances) do
      %{count: 0, avg_effectiveness: 0.0, avg_survival: 0.0}
    else
      count = length(role_performances)

      avg_effectiveness =
        average(Enum.map(role_performances, & &1.role_effectiveness.effectiveness_score))

      avg_survival =
        average(Enum.map(role_performances, & &1.survivability_score.normalized_score))

      %{
        count: count,
        avg_effectiveness: avg_effectiveness,
        avg_survival: avg_survival,
        best_performer:
          Enum.max_by(role_performances, & &1.role_effectiveness.effectiveness_score)
      }
    end
  end

  defp rank_by_efficiency(performances) do
    performances
    |> Enum.sort_by(& &1.dps_efficiency.efficiency_ratio, :desc)
    |> Enum.with_index(1)
    |> Enum.map(fn {perf, rank} -> {rank, perf} end)
  end

  defp rank_by_survivability(performances) do
    performances
    |> Enum.sort_by(& &1.survivability_score.normalized_score, :desc)
    |> Enum.with_index(1)
    |> Enum.map(fn {perf, rank} -> {rank, perf} end)
  end

  defp analyze_overall_battle_performance(performances) do
    total_ships = length(performances)

    if total_ships == 0 do
      %{total_ships: 0, avg_performance: 0.0, performance_distribution: %{}}
    else
      avg_effectiveness =
        average(Enum.map(performances, & &1.role_effectiveness.effectiveness_score))

      avg_survivability =
        average(Enum.map(performances, & &1.survivability_score.normalized_score))

      performance_distribution =
        performances
        |> Enum.group_by(&classify_overall_performance/1)
        |> Enum.map(fn {category, ships} -> {category, length(ships)} end)
        |> Map.new()

      %{
        total_ships: total_ships,
        avg_effectiveness: avg_effectiveness,
        avg_survivability: avg_survivability,
        performance_distribution: performance_distribution,
        battle_efficiency: calculate_battle_efficiency(performances)
      }
    end
  end

  defp classify_overall_performance(performance) do
    effectiveness = performance.role_effectiveness.effectiveness_score
    survivability = performance.survivability_score.normalized_score
    overall_score = (effectiveness + survivability) / 2

    cond do
      overall_score >= 0.8 -> :excellent
      overall_score >= 0.6 -> :good
      overall_score >= 0.4 -> :average
      true -> :poor
    end
  end

  defp calculate_battle_efficiency(performances) do
    if Enum.empty?(performances) do
      0.0
    else
      total_theoretical_dps =
        Enum.sum(Enum.map(performances, & &1.ship_instance.theoretical_stats.base_dps))

      total_actual_dps = Enum.sum(Enum.map(performances, & &1.dps_efficiency.actual_dps))

      if total_theoretical_dps > 0 do
        total_actual_dps / total_theoretical_dps
      else
        0.0
      end
    end
  end

  defp create_battle_performance_summary(performances) do
    %{
      total_ships_analyzed: length(performances),
      dominant_ship_classes: find_dominant_ship_classes(performances),
      tactical_roles_distribution: calculate_role_distribution(performances),
      key_insights: generate_key_insights(performances)
    }
  end

  defp find_dominant_ship_classes(performances) do
    performances
    |> Enum.group_by(& &1.ship_instance.ship_class)
    |> Enum.map(fn {class, ships} -> {class, length(ships)} end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(3)
  end

  defp calculate_role_distribution(performances) do
    performances
    |> Enum.group_by(& &1.ship_instance.estimated_fitting.estimated_role)
    |> Enum.map(fn {role, ships} -> {role, length(ships)} end)
    |> Map.new()
  end

  defp generate_key_insights(performances) do
    insights = []

    # High survivability insight
    high_survival_rate =
      Enum.count(performances, &(&1.survivability_score.normalized_score > 0.7)) /
        length(performances)

    insights =
      if high_survival_rate > 0.6 do
        ["High survivability battle - most ships performed well defensively" | insights]
      else
        insights
      end

    # DPS efficiency insight
    avg_dps_efficiency = average(Enum.map(performances, & &1.dps_efficiency.efficiency_ratio))

    insights =
      if avg_dps_efficiency > 0.8 do
        ["Excellent DPS efficiency - ships performed close to theoretical maximum" | insights]
      else
        insights
      end

    # Role effectiveness insight
    avg_role_effectiveness =
      average(Enum.map(performances, & &1.role_effectiveness.effectiveness_score))

    insights =
      if avg_role_effectiveness > 0.7 do
        ["Strong tactical coordination - ships fulfilled their roles effectively" | insights]
      else
        insights
      end

    insights
  end

  defp maybe_generate_recommendations(analysis, true) do
    recommendations = generate_performance_recommendations(analysis)
    enhanced_analysis = Map.put(analysis, :recommendations, recommendations)
    {:ok, enhanced_analysis}
  end

  defp maybe_generate_recommendations(analysis, false) do
    {:ok, analysis}
  end

  defp generate_performance_recommendations(analysis) do
    %{
      individual_recommendations: generate_individual_recommendations(analysis.ship_performances),
      fleet_recommendations: generate_fleet_recommendations(analysis.comparative_metrics),
      tactical_recommendations: generate_tactical_recommendations(analysis.battle_summary)
    }
  end

  defp generate_individual_recommendations(ship_performances) do
    ship_performances
    |> Enum.filter(&(&1.role_effectiveness.effectiveness_score < 0.6))
    |> Enum.map(&generate_ship_recommendation/1)
  end

  defp generate_ship_recommendation(performance) do
    recommendations = []

    # Survivability recommendations
    recommendations =
      if performance.survivability_score.normalized_score < 0.5 do
        ["Consider upgrading tank or improving positioning" | recommendations]
      else
        recommendations
      end

    # DPS efficiency recommendations
    recommendations =
      if performance.dps_efficiency.efficiency_ratio < 0.6 do
        ["Optimize fitting for better damage application" | recommendations]
      else
        recommendations
      end

    # Role recommendations
    recommendations =
      if performance.role_effectiveness.role_appropriateness == :suboptimal do
        ["Ship class may not be optimal for intended role" | recommendations]
      else
        recommendations
      end

    %{
      ship_type_id: performance.ship_instance.ship_type_id,
      character_id: performance.ship_instance.character_id,
      recommendations: recommendations
    }
  end

  defp generate_fleet_recommendations(comparative_metrics) do
    recommendations = []

    # Role balance recommendations
    role_distribution = comparative_metrics.role_comparisons

    recommendations =
      if Map.get(role_distribution, :logistics, %{count: 0}).count == 0 do
        ["Consider adding logistics ships for improved fleet survivability" | recommendations]
      else
        recommendations
      end

    # DPS recommendations
    avg_dps_efficiency = comparative_metrics.overall_battle_analysis.battle_efficiency

    recommendations =
      if avg_dps_efficiency < 0.6 do
        [
          "Fleet DPS efficiency is low - review fitting optimization and target calling"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations
  end

  defp generate_tactical_recommendations(battle_summary) do
    recommendations = []

    insights = battle_summary.key_insights

    recommendations =
      if "High survivability battle" in insights do
        recommendations
      else
        ["Focus on defensive positioning and tank optimization" | recommendations]
      end

    recommendations =
      if "Excellent DPS efficiency" in insights do
        recommendations
      else
        [
          "Improve damage application through better target selection and positioning"
          | recommendations
        ]
      end

    recommendations
  end

  # Legacy compatibility methods for existing battle analysis system

  @doc """
  Calculates expected ship statistics from fitting data.
  """
  def calculate_expected_stats(%{fitting_data: nil}), do: {:ok, %{status: :no_fitting_data}}

  def calculate_expected_stats(%{fitting_data: fitting, ship_type_id: ship_type_id}) do
    # In a real implementation, this would calculate from actual fitting data
    # For now, we'll use ship base stats with some reasonable assumptions

    base_stats = get_ship_base_stats(ship_type_id)

    # Simple calculation - in production would use pyfa or similar
    expected = %{
      ehp: %{
        # Assume some tank modules
        shield: base_stats.shield_hp * 1.2,
        armor: base_stats.armor_hp * 1.1,
        hull: base_stats.hull_hp,
        total: base_stats.shield_hp * 1.2 + base_stats.armor_hp * 1.1 + base_stats.hull_hp
      },
      dps: %{
        turret: estimate_weapon_dps(ship_type_id, fitting),
        missile: 0,
        drone: estimate_drone_dps(ship_type_id),
        total: estimate_weapon_dps(ship_type_id, fitting) + estimate_drone_dps(ship_type_id)
      },
      speed: %{
        # Assume prop mod
        max_velocity: base_stats.max_velocity * 1.15,
        sig_radius: base_stats.sig_radius
      },
      capacitor: %{
        capacity: base_stats.capacitor,
        recharge_rate: base_stats.cap_recharge_rate
      }
    }

    {:ok, expected}
  end

  @doc """
  Extracts actual performance data from battle data for a specific ship.
  """
  def extract_actual_performance(
        %{character_id: character_id, ship_type_id: ship_type_id},
        battle_data
      ) do
    # Find all killmails involving this character/ship combo
    involved_killmails =
      find_character_involvement(character_id, ship_type_id, battle_data.killmails)

    # Extract combat log data if available
    combat_events = extract_combat_events(character_id, battle_data[:combat_logs] || [])

    # Calculate actual metrics
    actual = %{
      damage_dealt: calculate_damage_dealt(character_id, involved_killmails, combat_events),
      damage_taken: calculate_damage_taken(character_id, involved_killmails, combat_events),
      kills: count_kills(character_id, involved_killmails),
      time_on_field: calculate_time_on_field(character_id, ship_type_id, battle_data),
      module_activations: count_module_activations(combat_events),
      movement_stats: analyze_movement(character_id, battle_data)
    }

    {:ok, actual}
  end

  @doc """
  Calculates efficiency metrics by comparing expected vs actual performance.
  """
  def calculate_efficiency_metrics(expected, _actual) when expected.status == :no_fitting_data do
    {:ok, %{status: :no_comparison_available}}
  end

  def calculate_efficiency_metrics(expected, actual) do
    time_minutes = max(actual.time_on_field / 60, 1)

    metrics = %{
      dps_efficiency: calculate_dps_efficiency_legacy(expected, actual, time_minutes),
      tank_efficiency: calculate_tank_efficiency_legacy(expected, actual),
      applied_vs_theoretical: calculate_application_efficiency(expected, actual),
      survival_rating: calculate_survival_rating_legacy(expected, actual),
      isk_efficiency: calculate_isk_efficiency_legacy(actual)
    }

    {:ok, metrics}
  end

  @doc """
  Generates recommendations based on performance analysis.
  """
  def generate_recommendations(efficiency_metrics, actual_performance) do
    recommendations = []

    # DPS recommendations
    recommendations =
      recommendations ++
        if efficiency_metrics[:dps_efficiency] &&
             efficiency_metrics.dps_efficiency[:percentage] < 50 do
          [
            "Consider improving application with webs/paints - achieving only #{round(efficiency_metrics.dps_efficiency.percentage)}% of potential DPS"
          ]
        else
          []
        end

    # Tank recommendations
    recommendations =
      recommendations ++
        if efficiency_metrics[:tank_efficiency] &&
             efficiency_metrics.tank_efficiency[:used_percentage] > 90 do
          [
            "Tank nearly depleted (#{round(efficiency_metrics.tank_efficiency.used_percentage)}% used) - consider more buffer or active reps"
          ]
        else
          []
        end

    # Survival recommendations
    # Less than 2 minutes
    recommendations =
      recommendations ++
        if actual_performance.time_on_field < 120 do
          [
            "Very short time on field (#{Float.round(actual_performance.time_on_field / 60, 1)} min) - consider safer engagement range"
          ]
        else
          []
        end

    recommendations
  end

  # Legacy helper functions for backward compatibility

  defp build_ship_info(ship_data) do
    %{
      character_id: ship_data.character_id,
      character_name:
        ship_data[:character_name] || NameResolver.character_name(ship_data.character_id),
      ship_type_id: ship_data.ship_type_id,
      ship_name: NameResolver.ship_name(ship_data.ship_type_id),
      fitting_source: ship_data[:fitting_source] || :estimated
    }
  end

  defp get_ship_base_stats(ship_type_id) do
    # In production, this would query the SDE for actual ship stats
    # For now, return reasonable defaults based on ship class

    # Simplified ship class detection
    cond do
      # Frigates
      ship_type_id in 582..650 ->
        %{
          shield_hp: 500,
          armor_hp: 400,
          hull_hp: 300,
          max_velocity: 400,
          sig_radius: 35,
          capacitor: 350,
          # ms
          cap_recharge_rate: 150_000
        }

      # Cruisers
      ship_type_id in 620..634 ->
        %{
          shield_hp: 2500,
          armor_hp: 2000,
          hull_hp: 1800,
          max_velocity: 250,
          sig_radius: 130,
          capacitor: 1500,
          cap_recharge_rate: 300_000
        }

      # Battleships
      ship_type_id in 638..645 ->
        %{
          shield_hp: 8000,
          armor_hp: 7000,
          hull_hp: 6500,
          max_velocity: 120,
          sig_radius: 400,
          capacitor: 5500,
          cap_recharge_rate: 900_000
        }

      # Default
      true ->
        %{
          shield_hp: 1000,
          armor_hp: 1000,
          hull_hp: 1000,
          max_velocity: 200,
          sig_radius: 100,
          capacitor: 1000,
          cap_recharge_rate: 250_000
        }
    end
  end

  defp estimate_weapon_dps(ship_type_id, _fitting) do
    # Simplified DPS estimation based on ship class
    cond do
      # Frigates
      ship_type_id in 582..650 -> 150
      # Cruisers
      ship_type_id in 620..634 -> 400
      # Battleships
      ship_type_id in 638..645 -> 800
      true -> 250
    end
  end

  defp estimate_drone_dps(ship_type_id) do
    # Simplified drone DPS estimation
    cond do
      # Tech 3 Destroyers
      ship_type_id in 29_984..29_990 -> 300
      # Cruisers
      ship_type_id in 620..634 -> 100
      # Battleships
      ship_type_id in 638..645 -> 200
      true -> 50
    end
  end

  defp find_character_involvement(character_id, ship_type_id, killmails) do
    Enum.filter(killmails, fn km ->
      # Check if character was victim
      victim_match =
        km.victim_character_id == character_id && km.victim_ship_type_id == ship_type_id

      # Check if character was attacker
      attacker_match =
        Enum.any?(km.raw_data["attackers"] || [], fn att ->
          att["character_id"] == character_id && att["ship_type_id"] == ship_type_id
        end)

      victim_match || attacker_match
    end)
  end

  defp extract_combat_events(character_id, combat_logs) do
    combat_logs
    |> Enum.filter(&(&1.pilot_name == character_id || &1.character_id == character_id))
    |> Enum.flat_map(&(&1.parsed_data[:events] || []))
  end

  defp calculate_damage_dealt(character_id, killmails, combat_events) do
    # From killmails
    km_damage =
      killmails
      |> Enum.flat_map(&(&1.raw_data["attackers"] || []))
      |> Enum.filter(&(&1["character_id"] == character_id))
      |> Enum.map(&(&1["damage_done"] || 0))
      |> Enum.sum()

    # From combat logs
    log_damage =
      combat_events
      |> Enum.filter(&(&1[:type] == :damage && &1[:from] == character_id))
      |> Enum.map(&(&1[:damage] || 0))
      |> Enum.sum()

    %{
      from_killmails: km_damage,
      from_logs: log_damage,
      total: km_damage + log_damage
    }
  end

  defp calculate_damage_taken(character_id, killmails, combat_events) do
    # From killmails (if they died)
    km_damage =
      killmails
      |> Enum.filter(&(&1.victim_character_id == character_id))
      |> Enum.map(&get_victim_damage_taken(&1))
      |> Enum.sum()

    # From combat logs
    log_damage =
      combat_events
      |> Enum.filter(&(&1[:type] == :damage && &1[:to] == character_id))
      |> Enum.map(&(&1[:damage] || 0))
      |> Enum.sum()

    %{
      from_killmails: km_damage,
      from_logs: log_damage,
      total: km_damage + log_damage
    }
  end

  defp count_kills(character_id, killmails) do
    killmails
    |> Enum.count(fn km ->
      Enum.any?(
        km.raw_data["attackers"] || [],
        &(&1["character_id"] == character_id && &1["final_blow"])
      )
    end)
  end

  defp calculate_time_on_field(character_id, ship_type_id, battle_data) do
    # If battle has timeline, use that
    if battle_data[:timeline] && battle_data.timeline[:events] do
      events = battle_data.timeline.events

      appearances =
        Enum.filter(events, fn event ->
          # Check victim
          victim_match =
            event.victim.character_id == character_id &&
              event.victim.ship_type_id == ship_type_id

          # Check attackers
          attacker_match =
            Enum.any?(event.attackers, fn att ->
              att.character_id == character_id && att.ship_type_id == ship_type_id
            end)

          victim_match || attacker_match
        end)

      if length(appearances) > 0 do
        first = List.first(appearances)
        last = List.last(appearances)

        # If they died, use that as end time
        death =
          Enum.find(appearances, fn e ->
            e.victim.character_id == character_id && e.victim.ship_type_id == ship_type_id
          end)

        end_time = if death, do: death.timestamp, else: last.timestamp

        NaiveDateTime.diff(end_time, first.timestamp, :second)
      else
        0
      end
    else
      # Fallback to killmail timestamps
      killmails = battle_data.killmails
      involved = find_character_involvement(character_id, ship_type_id, killmails)

      if length(involved) > 0 do
        timestamps = Enum.map(involved, & &1.killmail_time)
        first = Enum.min(timestamps)
        last = Enum.max(timestamps)

        NaiveDateTime.diff(last, first, :second)
      else
        0
      end
    end
  end

  defp count_module_activations(combat_events) do
    combat_events
    |> Enum.filter(&(&1[:type] == :ewar))
    |> Enum.group_by(& &1[:ewar_type])
    |> Enum.map(fn {type, events} -> {type, length(events)} end)
    |> Enum.into(%{})
  end

  defp analyze_movement(_character_id, _battle_data) do
    # Would analyze position changes from combat logs
    %{
      average_range: nil,
      speed_utilized: nil,
      position_changes: 0
    }
  end

  defp calculate_dps_efficiency_legacy(expected, actual, time_minutes) do
    expected_damage = expected.dps.total * time_minutes * 60
    actual_damage = actual.damage_dealt.total

    %{
      expected_damage: expected_damage,
      actual_damage: actual_damage,
      percentage: if(expected_damage > 0, do: actual_damage / expected_damage * 100, else: 0),
      dps_achieved: actual_damage / (time_minutes * 60)
    }
  end

  defp calculate_tank_efficiency_legacy(expected, actual) do
    damage_taken = actual.damage_taken.total
    ehp_total = expected.ehp.total

    %{
      damage_tanked: damage_taken,
      ehp_available: ehp_total,
      used_percentage: if(ehp_total > 0, do: damage_taken / ehp_total * 100, else: 0),
      survived: damage_taken < ehp_total
    }
  end

  defp calculate_application_efficiency(expected, actual) do
    # Calculate actual application efficiency from real data
    hit_percentage =
      if expected.expected_dps > 0 do
        min(
          100.0,
          actual.damage_dealt.total / (expected.expected_dps * actual.time_on_field) * 100.0
        )
      else
        0.0
      end

    # Estimate optimal range based on damage distribution
    optimal_range_percentage =
      if actual.damage_dealt.total > 0 do
        # Assume better application indicates better range management
        min(100.0, hit_percentage * 0.9)
      else
        0.0
      end

    # Tracking efficiency is typically related to hit percentage
    tracking_efficiency =
      if hit_percentage > 0 do
        min(100.0, hit_percentage * 0.95)
      else
        0.0
      end

    %{
      hit_percentage: Float.round(hit_percentage, 1),
      optimal_range_percentage: Float.round(optimal_range_percentage, 1),
      tracking_efficiency: Float.round(tracking_efficiency, 1)
    }
  end

  defp calculate_survival_rating_legacy(expected, actual) do
    base_score = 50.0

    # Adjust based on survival
    survival_bonus = if actual.damage_taken.total < expected.ehp.total, do: 25.0, else: 0.0

    # Adjust based on time on field
    # Max 25 points for 5+ minutes
    time_bonus = min(actual.time_on_field / 300 * 25, 25.0)

    base_score + survival_bonus + time_bonus
  end

  # Helper function to get damage taken from killmail
  defp get_victim_damage_taken(km) do
    case km.raw_data do
      %{"victim" => %{"damage_taken" => damage}} when is_number(damage) -> damage
      _ -> 0
    end
  end

  defp calculate_isk_efficiency_legacy(_actual) do
    # Would need ship values from market data
    %{
      # Placeholder
      isk_destroyed: 0,
      # Placeholder
      isk_lost: 0,
      # Placeholder
      efficiency: 0.0
    }
  end

  # Utility functions for sophisticated analysis

  defp estimate_friendly_count(battle, ship_instance) do
    # Estimate friendly ship count based on alliance/corporation
    same_alliance =
      battle.killmails
      |> Enum.count(
        &(&1.victim_alliance_id == ship_instance.alliance_id and &1.victim_alliance_id != nil)
      )

    same_corp =
      battle.killmails
      |> Enum.count(&(&1.victim_corporation_id == ship_instance.corporation_id))

    max(same_alliance, same_corp)
  end

  defp estimate_hostile_count(battle, ship_instance) do
    # Rough estimate of hostile count
    total_participants = battle.metadata.unique_participants
    friendly_count = estimate_friendly_count(battle, ship_instance)
    max(1, total_participants - friendly_count)
  end

  defp calculate_battle_intensity(battle) do
    kill_rate = length(battle.killmails) / max(1, battle.metadata.duration_minutes)

    cond do
      kill_rate >= 5.0 -> :extreme
      kill_rate >= 3.0 -> :high
      kill_rate >= 1.5 -> :medium
      true -> :low
    end
  end

  defp filter_by_ship_type(analysis, ship_type_id) do
    filtered_performances =
      analysis.ship_performances
      |> Enum.filter(&(&1.ship_instance.ship_type_id == ship_type_id))

    Map.put(analysis, :ship_performances, filtered_performances)
  end

  defp calculate_performance_trends(performance_data) do
    # Analyze trends across multiple battles
    if length(performance_data) < 2 do
      %{trend: :insufficient_data}
    else
      effectiveness_scores =
        performance_data
        |> Enum.flat_map(& &1.ship_performances)
        |> Enum.map(& &1.role_effectiveness.effectiveness_score)

      %{
        trend: calculate_trend(effectiveness_scores),
        avg_effectiveness: average(effectiveness_scores),
        improvement_rate: calculate_improvement_rate(effectiveness_scores)
      }
    end
  end

  defp identify_optimal_conditions(performance_data) do
    # Find conditions where ship performs best
    best_performance =
      performance_data
      |> Enum.flat_map(& &1.ship_performances)
      |> Enum.max_by(& &1.role_effectiveness.effectiveness_score, fn -> nil end)

    if best_performance do
      %{
        optimal_battle_type: best_performance.ship_instance.battle_context.battle_type,
        optimal_battle_size: best_performance.ship_instance.battle_context.total_participants,
        performance_score: best_performance.role_effectiveness.effectiveness_score
      }
    else
      %{optimal_conditions: :no_data}
    end
  end

  defp identify_improvement_areas(performance_data) do
    all_performances = performance_data |> Enum.flat_map(& &1.ship_performances)

    if Enum.empty?(all_performances) do
      []
    else
      avg_survivability =
        average(Enum.map(all_performances, & &1.survivability_score.normalized_score))

      avg_dps_efficiency =
        average(Enum.map(all_performances, & &1.dps_efficiency.efficiency_ratio))

      avg_role_effectiveness =
        average(Enum.map(all_performances, & &1.role_effectiveness.effectiveness_score))

      improvements = []

      improvements =
        if avg_survivability < 0.6 do
          ["Improve survivability through better tank or positioning" | improvements]
        else
          improvements
        end

      improvements =
        if avg_dps_efficiency < 0.6 do
          ["Optimize fitting for better damage application" | improvements]
        else
          improvements
        end

      improvements =
        if avg_role_effectiveness < 0.6 do
          ["Better role execution and tactical coordination needed" | improvements]
        else
          improvements
        end

      improvements
    end
  end

  defp calculate_trend(values) when length(values) < 2, do: :stable

  defp calculate_trend(values) do
    # Simple linear trend calculation
    n = length(values)
    indices = 1..n |> Enum.to_list()

    sum_x = Enum.sum(indices)
    sum_y = Enum.sum(values)
    sum_xy = indices |> Enum.zip(values) |> Enum.map(fn {x, y} -> x * y end) |> Enum.sum()
    sum_x2 = indices |> Enum.map(&(&1 * &1)) |> Enum.sum()

    slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)

    cond do
      slope > 0.05 -> :improving
      slope < -0.05 -> :declining
      true -> :stable
    end
  end

  defp calculate_improvement_rate(values) when length(values) < 2, do: 0.0

  defp calculate_improvement_rate(values) do
    first_half = values |> Enum.take(div(length(values), 2))
    second_half = values |> Enum.drop(div(length(values), 2))

    if length(first_half) > 0 and length(second_half) > 0 do
      avg_first = average(first_half)
      avg_second = average(second_half)

      if avg_first > 0 do
        (avg_second - avg_first) / avg_first
      else
        0.0
      end
    else
      0.0
    end
  end

  defp average([]), do: 0.0

  defp average(values) do
    Enum.sum(values) / length(values)
  end

  # Fleet statistics calculation functions for template compatibility

  defp calculate_avg_dps_efficiency([]), do: 0

  defp calculate_avg_dps_efficiency(ship_performances) do
    efficiencies = Enum.map(ship_performances, & &1.dps_efficiency.efficiency_ratio)
    # Convert to percentage
    round(average(efficiencies) * 100)
  end

  defp calculate_avg_survivability([]), do: 0

  defp calculate_avg_survivability(ship_performances) do
    survivabilities = Enum.map(ship_performances, & &1.survivability_score.normalized_score)
    # Convert to percentage
    round(average(survivabilities) * 100)
  end

  defp calculate_coordination_score([]), do: 0

  defp calculate_coordination_score(ship_performances) do
    # Coordination score based on role effectiveness and tactical contribution
    scores =
      Enum.map(ship_performances, fn perf ->
        role_score = perf.role_effectiveness.effectiveness_score
        tactical_score = perf.tactical_contribution.tactical_value
        (role_score + tactical_score) / 2
      end)

    # Convert to 0-10 scale
    round(average(scores) * 10)
  end

  defp calculate_tactical_diversity([]), do: 0

  defp calculate_tactical_diversity(ship_performances) do
    # Diversity score based on unique roles and ship types
    unique_roles =
      ship_performances
      |> Enum.map(& &1.ship_instance.estimated_fitting.estimated_role)
      |> Enum.uniq()
      |> length()

    unique_ship_types =
      ship_performances
      |> Enum.map(& &1.ship_instance.ship_type_id)
      |> Enum.uniq()
      |> length()

    total_ships = length(ship_performances)

    if total_ships > 0 do
      role_diversity = unique_roles / total_ships
      ship_diversity = unique_ship_types / total_ships
      # Convert to 0-10 scale
      round((role_diversity + ship_diversity) / 2 * 10)
    else
      0
    end
  end

  defp estimate_ship_fitting_from_attacker(attacker) do
    # Estimate fitting based on weapon type and ship type
    weapon_type_id = attacker["weapon_type_id"]
    ship_type_id = attacker["ship_type_id"]

    %{
      estimated_role: estimate_role_from_ship_and_weapon(ship_type_id, weapon_type_id),
      high_slots: estimate_high_slots(weapon_type_id),
      mid_slots: [],
      low_slots: [],
      rig_slots: [],
      estimated_value: 0
    }
  end

  defp estimate_role_from_ship_and_weapon(_ship_type_id, weapon_type_id) do
    # Simple role estimation based on weapon type
    cond do
      weapon_type_id == nil -> "Unknown"
      # Missile launchers
      weapon_type_id in 2410..2488 -> "DPS"
      # Turrets
      weapon_type_id in 2929..2969 -> "DPS"
      # Tackle modules
      weapon_type_id in 3520..3540 -> "Tackle"
      # Remote reps
      weapon_type_id in 3244..3246 -> "Logistics"
      true -> "Support"
    end
  end

  defp estimate_high_slots(weapon_type_id) when is_nil(weapon_type_id), do: []

  defp estimate_high_slots(weapon_type_id) do
    # Estimate high slot modules based on weapon
    [%{type_id: weapon_type_id, quantity: 1}]
  end
end
