defmodule EveDmv.Contexts.FleetOperations.Domain.FleetAnalyzer do
  @moduledoc """
  Core fleet analysis engine for EVE DMV Fleet Operations.

  Provides comprehensive fleet composition analysis, engagement evaluation,
  and tactical recommendations for fleet commanders and doctrine planners.

  Converted from GenServer to simple module for stateless operations.
  """

  use EveDmv.ErrorHandler
  alias EveDmv.DomainEvents.FleetAnalysisComplete
  alias EveDmv.Infrastructure.EventBus
  alias EveDmv.StaticData

  require Logger

  # Wormhole mass limits in kg
  @wormhole_mass_limits %{
    c1: 20_000_000,
    c2: 300_000_000,
    c3: 1_350_000_000,
    c4: 1_800_000_000,
    c5: 1_800_000_000,
    c6: 1_800_000_000
  }

  # Public API

  @doc """
  Analyze fleet composition for effectiveness and optimization.
  """
  def analyze_composition(fleet_data) do
    perform_composition_analysis(fleet_data)
  end

  @doc """
  Analyze a fleet engagement from killmail data.
  """
  def analyze_engagement(engagement_data) do
    {:ok, analysis} = perform_engagement_analysis(engagement_data)

    # Publish engagement analysis complete event
    EventBus.publish(%FleetAnalysisComplete{
      engagement_id: engagement_data.engagement_id,
      analysis_type: :engagement,
      results: analysis,
      timestamp: DateTime.utc_now()
    })

    {:ok, analysis}
  end

  @doc """
  Calculate mass analysis for wormhole operations.
  """
  def calculate_mass_analysis(fleet_data) do
    calculate_fleet_mass_analysis(fleet_data)
  end

  @doc """
  Generate improvement recommendations for a fleet.
  """
  def generate_improvement_recommendations(fleet_data) do
    generate_fleet_recommendations(fleet_data)
  end

  @doc """
  Calculate optimal composition for a doctrine and pilot count.
  """
  def calculate_optimal_composition(doctrine, pilot_count) do
    calculate_doctrine_optimal_composition(doctrine, pilot_count)
  end

  @doc """
  Force reanalysis of a fleet engagement.

  In a real implementation, this would load and reanalyze engagement data.
  """
  def force_reanalyze_engagement(engagement_id) do
    Logger.info(
      "Force reanalyzed engagement requested for: #{engagement_id} (no engagement data available)"
    )

    {:error, :no_engagement_data}
  end

  @doc """
  Calculate wormhole mass limits for fleet data.
  """
  def calculate_wormhole_mass_limits(fleet_data) do
    calculate_wormhole_compatibility(fleet_data)
  end

  @doc """
  Get analyzer metrics and performance data.

  Since this is now stateless, returns empty metrics.
  """
  def get_metrics do
    %{
      compositions_analyzed: 0,
      engagements_analyzed: 0,
      recommendations_generated: 0,
      cache_hits: 0,
      cache_misses: 0,
      average_analysis_time_ms: 0.0
    }
  end

  # Private analysis functions

  defp perform_composition_analysis(fleet_data) do
    participants = fleet_data.participants

    # Basic composition breakdown
    composition_breakdown = analyze_ship_composition(participants)
    role_distribution = analyze_role_distribution(participants)

    # Calculate effectiveness metrics
    effectiveness_score =
      calculate_composition_effectiveness(composition_breakdown, role_distribution)

    # Mass analysis
    mass_analysis = calculate_total_fleet_mass(participants)

    # Generate composition score
    composition_score = calculate_composition_score(composition_breakdown)

    analysis = %{
      composition_breakdown: composition_breakdown,
      role_distribution: role_distribution,
      effectiveness_score: effectiveness_score,
      composition_score: composition_score,
      mass_analysis: mass_analysis,
      participant_count: length(participants),
      analysis_timestamp: DateTime.utc_now()
    }

    {:ok, analysis}
  end

  defp perform_engagement_analysis(engagement_data) do
    participants = engagement_data.participants
    killmails = engagement_data.killmails

    # Separate friendly and hostile participants
    {friendly_participants, hostile_participants} =
      categorize_participants(participants, killmails)

    # Analyze fleet performance
    friendly_performance = analyze_fleet_performance(friendly_participants, killmails, :friendly)
    hostile_performance = analyze_fleet_performance(hostile_participants, killmails, :hostile)

    # Calculate engagement outcome
    engagement_outcome = determine_engagement_outcome(friendly_performance, hostile_performance)

    # Identify key factors
    key_factors =
      identify_engagement_factors(killmails, friendly_participants, hostile_participants)

    # Generate tactical analysis
    tactical_analysis =
      generate_tactical_analysis(engagement_data, friendly_performance, hostile_performance)

    analysis = %{
      engagement_id: engagement_data.engagement_id,
      friendly_fleet: %{
        participants: friendly_participants,
        performance: friendly_performance
      },
      hostile_fleet: %{
        participants: hostile_participants,
        performance: hostile_performance
      },
      engagement_outcome: engagement_outcome,
      key_factors: key_factors,
      tactical_analysis: tactical_analysis,
      analysis_timestamp: DateTime.utc_now()
    }

    {:ok, analysis}
  end

  defp analyze_ship_composition(participants) do
    ship_counts =
      Enum.reduce(participants, %{}, fn participant, acc ->
        ship_class = get_ship_class(participant.ship_type_id)
        Map.update(acc, ship_class, 1, &(&1 + 1))
      end)

    total_ships = length(participants)

    ship_distribution =
      Map.new(ship_counts, fn {ship_class, count} ->
        {ship_class,
         %{
           count: count,
           percentage: Float.round(count / total_ships * 100, 1)
         }}
      end)

    %{
      total_ships: total_ships,
      ship_classes: ship_distribution,
      diversity_score: calculate_diversity_score(ship_counts)
    }
  end

  defp analyze_role_distribution(participants) do
    role_counts =
      Enum.reduce(participants, %{}, fn participant, acc ->
        role = determine_participant_role(participant)
        Map.update(acc, role, 1, &(&1 + 1))
      end)

    # Check for essential roles
    essential_roles = [:dps, :logistics, :tackle]

    missing_essential_roles =
      Enum.filter(essential_roles, fn role ->
        Map.get(role_counts, role, 0) == 0
      end)

    %{
      roles: role_counts,
      missing_essential_roles: missing_essential_roles,
      role_balance_score: calculate_role_balance_score(role_counts)
    }
  end

  defp determine_participant_role(participant) do
    # Determine role based on ship type
    ship_class = get_ship_class(participant.ship_type_id)

    case ship_class do
      :frigate ->
        case StaticData.get_ship_class(participant.ship_type_id) do
          :logistics_frigate -> :logistics
          :electronic_attack_frigate -> :ewar
          :interceptor -> :tackle
          :interdictor -> :tackle
          _ -> :tackle
        end

      :cruiser ->
        case StaticData.get_ship_class(participant.ship_type_id) do
          :logistics_cruiser -> :logistics
          :force_recon -> :ewar
          :combat_recon -> :ewar
          :heavy_interdictor -> :tackle
          _ -> :dps
        end

      :destroyer ->
        :dps

      :battlecruiser ->
        :command

      :battleship ->
        :dps

      :capital ->
        :capital
    end
  end

  defp calculate_composition_effectiveness(composition_breakdown, role_distribution) do
    diversity_score = composition_breakdown.diversity_score
    role_balance_score = role_distribution.role_balance_score

    # Penalty for missing essential roles
    essential_role_penalty = length(role_distribution.missing_essential_roles) * 0.2

    effectiveness = (diversity_score + role_balance_score) / 2 - essential_role_penalty
    max(0.0, min(1.0, effectiveness))
  end

  defp calculate_diversity_score(ship_counts) do
    ship_count = map_size(ship_counts)
    total_ships = Enum.sum(Map.values(ship_counts))

    if total_ships > 0 do
      # Shannon diversity index
      ship_counts
      |> Map.values()
      |> Enum.map(fn count ->
        p = count / total_ships
        -p * :math.log(p)
      end)
      |> Enum.sum()
      |> (fn h -> h / :math.log(ship_count) end).()
    else
      0.0
    end
  end

  defp calculate_role_balance_score(role_counts) do
    total_count = Enum.sum(Map.values(role_counts))

    if total_count > 0 do
      # Ideal role distribution
      ideal_distribution = %{
        dps: 0.5,
        logistics: 0.2,
        tackle: 0.15,
        ewar: 0.1,
        command: 0.05
      }

      # Calculate deviation from ideal
      deviation =
        Enum.sum(
          Enum.map(ideal_distribution, fn {role, ideal_ratio} ->
            actual_ratio = Map.get(role_counts, role, 0) / total_count
            abs(actual_ratio - ideal_ratio)
          end)
        )

      # Convert to score (lower deviation = higher score)
      1.0 - min(1.0, deviation)
    else
      0.0
    end
  end

  defp calculate_total_fleet_mass(participants) do
    total_mass =
      Enum.sum(
        Enum.map(participants, fn participant ->
          case StaticData.get_ship_mass(participant.ship_type_id) do
            {:ok, mass} -> mass
            {:error, _} -> estimate_ship_mass(participant.ship_type_id)
          end
        end)
      )

    wormhole_compatibility = determine_wormhole_compatibility(total_mass)

    %{
      total_mass: round(total_mass),
      mass_category: categorize_mass(total_mass),
      wormhole_compatibility: wormhole_compatibility,
      per_pilot_average: round(total_mass / max(1, length(participants)))
    }
  end

  defp determine_wormhole_compatibility(total_mass) do
    Enum.map(@wormhole_mass_limits, fn {class, limit} ->
      {class,
       %{
         fits: total_mass <= limit,
         remaining_mass: max(0, limit - total_mass),
         usage_percentage: Float.round(total_mass / limit * 100, 1)
       }}
    end)
    |> Enum.into(%{})
  end

  defp categorize_mass(mass) do
    cond do
      mass < 100_000_000 -> :light
      mass < 500_000_000 -> :medium
      mass < 1_500_000_000 -> :heavy
      true -> :capital
    end
  end

  defp get_ship_class(ship_type_id) do
    case StaticData.get_ship_class(ship_type_id) do
      class when is_atom(class) ->
        cond do
          class in [
            :frigate,
            :assault_frigate,
            :covert_ops,
            :interceptor,
            :interdictor,
            :electronic_attack_frigate,
            :logistics_frigate
          ] ->
            :frigate

          class in [:destroyer, :tactical_destroyer, :command_destroyer] ->
            :destroyer

          class in [
            :cruiser,
            :heavy_assault_cruiser,
            :heavy_interdictor,
            :force_recon,
            :combat_recon,
            :logistics_cruiser,
            :strategic_cruiser
          ] ->
            :cruiser

          class in [:battlecruiser, :attack_battlecruiser] ->
            :battlecruiser

          class in [:battleship, :marauder, :black_ops] ->
            :battleship

          class in [:dreadnought, :carrier, :supercarrier, :titan, :force_auxiliary] ->
            :capital

          true ->
            :frigate
        end

      _ ->
        :frigate
    end
  end

  defp estimate_ship_mass(ship_type_id) do
    # Estimate based on ship type ID ranges if not in static data
    cond do
      # Frigate mass
      ship_type_id < 1000 -> 1_500_000
      # Cruiser mass
      ship_type_id < 2000 -> 12_000_000
      # Battleship mass
      ship_type_id < 3000 -> 110_000_000
      # Capital mass
      true -> 1_300_000_000
    end
  end

  defp calculate_fleet_mass_analysis(fleet_data) do
    mass_analysis = calculate_total_fleet_mass(fleet_data.participants)
    {:ok, mass_analysis}
  end

  defp generate_fleet_recommendations(fleet_data) do
    participants = fleet_data.participants

    composition_breakdown = analyze_ship_composition(participants)
    role_distribution = analyze_role_distribution(participants)
    mass_analysis = calculate_total_fleet_mass(participants)

    recommendations =
      []
      |> add_role_recommendations(role_distribution)
      |> add_composition_recommendations(composition_breakdown.ship_classes)
      |> add_mass_recommendations(mass_analysis.total_mass, participants)
      |> add_tactical_recommendations(fleet_data)

    high_priority_recs = filter_high_priority_recommendations(recommendations)
    improvement_potential = calculate_improvement_potential(fleet_data)

    recommendation_result = %{
      recommendations: recommendations,
      high_priority_count: length(high_priority_recs),
      improvement_potential_percentage: improvement_potential,
      generated_at: DateTime.utc_now()
    }

    {:ok, recommendation_result}
  end

  defp calculate_doctrine_optimal_composition(doctrine, pilot_count) do
    # Validate inputs
    if pilot_count <= 0 do
      {:error, :invalid_pilot_count}
    else
      # Get doctrine requirements
      ship_requirements = Map.get(doctrine, :ship_requirements, %{})
      role_requirements = Map.get(doctrine, :role_requirements, %{})

      # Calculate optimal distribution
      optimal_composition =
        distribute_pilots_to_doctrine(ship_requirements, role_requirements, pilot_count)

      # Calculate effectiveness
      effectiveness = calculate_doctrine_effectiveness(optimal_composition, doctrine)

      result = %{
        doctrine_name: doctrine.name,
        pilot_count: pilot_count,
        optimal_composition: optimal_composition,
        effectiveness_score: Float.round(effectiveness, 3),
        mass_category: categorize_mass(optimal_composition.total_mass),
        compliance_score: optimal_composition.compliance_score
      }

      {:ok, result}
    end
  end

  defp estimate_fleet_dps(participants) do
    # Calculate fleet DPS using real ship attributes
    Enum.sum(
      Enum.map(participants, fn participant ->
        case EveDmv.StaticData.ShipTypes.get_ship_dps(participant.ship_type_id) do
          {:ok, dps} ->
            dps

          {:error, _} ->
            # Fallback to ship class estimation if no data available
            case get_ship_class(participant.ship_type_id) do
              :frigate -> 200
              :destroyer -> 400
              :cruiser -> 600
              :battlecruiser -> 1000
              :battleship -> 1500
              :capital -> 8000
            end
        end
      end)
    )
  end

  defp categorize_participants(participants, killmails) do
    # Determine friendly vs hostile based on killmail analysis
    # This is simplified - in reality would use corporation/alliance info

    _victim_corps =
      MapSet.new(Enum.map(killmails, fn km -> km.victim.corporation_id end))

    _attacker_corps =
      killmails
      |> Enum.flat_map(fn km -> Enum.map(km.attackers, & &1.corporation_id) end)
      |> MapSet.new()

    # Assume majority corp is friendly
    all_corps = Enum.map(participants, & &1.corporation_id)

    max_corp_tuple =
      Enum.frequencies(all_corps)
      |> Enum.max_by(fn {_corp, count} -> count end)

    majority_corp = elem(max_corp_tuple, 0)

    Enum.split_with(participants, fn participant ->
      participant.corporation_id == majority_corp
    end)
  end

  defp analyze_fleet_performance(participants, killmails, _side) do
    participant_ids = MapSet.new(participants, & &1.character_id)

    # Count kills and losses for this fleet
    {kills, losses} =
      Enum.reduce(killmails, {0, 0}, fn killmail, {kill_acc, loss_acc} ->
        victim_in_fleet = MapSet.member?(participant_ids, killmail.victim.character_id)

        attackers_in_fleet =
          Enum.any?(killmail.attackers, fn attacker ->
            MapSet.member?(participant_ids, attacker.character_id)
          end)

        cond do
          victim_in_fleet -> {kill_acc, loss_acc + 1}
          attackers_in_fleet -> {kill_acc + 1, loss_acc}
          true -> {kill_acc, loss_acc}
        end
      end)

    # Calculate ISK efficiency
    isk_destroyed = calculate_isk_for_side(killmails, participant_ids, :destroyed)
    isk_lost = calculate_isk_for_side(killmails, participant_ids, :lost)

    isk_efficiency =
      if isk_destroyed + isk_lost > 0 do
        isk_destroyed / (isk_destroyed + isk_lost) * 100
      else
        50.0
      end

    %{
      participant_count: length(participants),
      kills: kills,
      losses: losses,
      kill_death_ratio: if(losses > 0, do: kills / losses, else: kills),
      isk_destroyed: isk_destroyed,
      isk_lost: isk_lost,
      isk_efficiency: Float.round(isk_efficiency, 2),
      survival_rate:
        if(length(participants) > 0,
          do: (length(participants) - losses) / length(participants) * 100,
          else: 0
        )
    }
  end

  defp determine_engagement_outcome(friendly_performance, hostile_performance) do
    friendly_score = calculate_performance_score(friendly_performance)
    hostile_score = calculate_performance_score(hostile_performance)

    cond do
      friendly_score > hostile_score * 1.2 -> :decisive_victory
      friendly_score > hostile_score -> :victory
      abs(friendly_score - hostile_score) < 0.1 -> :stalemate
      hostile_score > friendly_score -> :defeat
      hostile_score > friendly_score * 1.2 -> :decisive_defeat
    end
  end

  defp calculate_performance_score(performance) do
    # Weighted performance score
    isk_weight = 0.4
    kd_weight = 0.3
    survival_weight = 0.3

    isk_score = performance.isk_efficiency / 100
    # Cap at 3:1 ratio
    kd_score = min(1.0, performance.kill_death_ratio / 3.0)
    survival_score = performance.survival_rate / 100

    isk_score * isk_weight + kd_score * kd_weight + survival_score * survival_weight
  end

  defp identify_engagement_factors(_killmails, friendly_participants, hostile_participants) do
    initial_factors = []

    # Numbers advantage
    friendly_count = length(friendly_participants)
    hostile_count = length(hostile_participants)

    numbers_factors =
      if friendly_count > hostile_count * 1.5 do
        [
          %{type: :numbers_advantage, side: :friendly, ratio: friendly_count / hostile_count}
          | initial_factors
        ]
      else
        initial_factors
      end

    # Ship class advantages
    final_factors =
      analyze_ship_class_factors(numbers_factors, friendly_participants, hostile_participants)

    final_factors
  end

  defp analyze_ship_class_factors(factors, friendly_participants, hostile_participants) do
    friendly_capitals = count_capitals(friendly_participants)
    hostile_capitals = count_capitals(hostile_participants)

    if friendly_capitals > 0 and hostile_capitals == 0 do
      [%{type: :capital_advantage, side: :friendly, capital_count: friendly_capitals} | factors]
    else
      factors
    end
  end

  defp count_capitals(participants) do
    Enum.count(participants, fn participant ->
      get_ship_class(participant.ship_type_id) == :capital
    end)
  end

  defp generate_tactical_analysis(engagement_data, friendly_performance, hostile_performance) do
    %{
      engagement_summary:
        generate_engagement_summary(engagement_data, friendly_performance, hostile_performance),
      lessons_learned: extract_lessons_learned(friendly_performance, hostile_performance),
      improvement_areas: identify_improvement_areas(friendly_performance),
      tactical_recommendations: generate_tactical_recommendations(engagement_data)
    }
  end

  defp generate_engagement_summary(engagement_data, friendly_performance, hostile_performance) do
    outcome = determine_engagement_outcome(friendly_performance, hostile_performance)

    "Fleet engagement #{engagement_data.engagement_id} resulted in #{outcome}. " <>
      "Friendly fleet: #{friendly_performance.kills} kills, #{friendly_performance.losses} losses. " <>
      "ISK efficiency: #{friendly_performance.isk_efficiency}%."
  end

  defp extract_lessons_learned(friendly_performance, _hostile_performance) do
    base_lessons = []

    # ISK efficiency lessons
    efficiency_lessons =
      if friendly_performance.isk_efficiency < 40 do
        [
          "Poor ISK efficiency suggests need for better target selection or fleet composition"
          | base_lessons
        ]
      else
        base_lessons
      end

    # Survival rate lessons
    tactical_lessons =
      if friendly_performance.survival_rate < 60 do
        [
          "Low survival rate indicates need for better logistics support or tactical withdrawal"
          | efficiency_lessons
        ]
      else
        efficiency_lessons
      end

    tactical_lessons
  end

  defp identify_improvement_areas(performance) do
    improvement_areas = []

    efficiency_areas =
      if performance.isk_efficiency < 50,
        do: [:target_selection, :fleet_composition | improvement_areas],
        else: improvement_areas

    survival_areas =
      if performance.survival_rate < 70,
        do: [:logistics_support, :positioning | efficiency_areas],
        else: efficiency_areas

    focus_areas =
      if performance.kill_death_ratio < 1.0,
        do: [:engagement_tactics, :fleet_coordination | survival_areas],
        else: survival_areas

    focus_areas
  end

  defp generate_tactical_recommendations(_engagement_data) do
    [
      "Review fleet composition for optimal role distribution",
      "Consider doctrine compliance for improved coordination",
      "Analyze positioning and engagement range optimization"
    ]
  end

  defp calculate_isk_for_side(killmails, participant_ids, side) do
    Enum.sum(
      Enum.map(killmails, fn killmail ->
        case side do
          :destroyed ->
            # ISK destroyed by this fleet
            attackers_in_fleet =
              Enum.any?(killmail.attackers, fn attacker ->
                MapSet.member?(participant_ids, attacker.character_id)
              end)

            if attackers_in_fleet, do: killmail.zkb_total_value || 0, else: 0

          :lost ->
            # ISK lost by this fleet
            victim_in_fleet = MapSet.member?(participant_ids, killmail.victim.character_id)
            if victim_in_fleet, do: killmail.zkb_total_value || 0, else: 0
        end
      end)
    )
  end

  # Recommendation generation helpers

  defp add_role_recommendations(recommendations, roles) do
    missing_roles = roles.missing_essential_roles

    fleet_recommendations =
      Enum.map(missing_roles, fn role ->
        %{
          type: :missing_role,
          priority: :high,
          role: role,
          description: "Fleet lacks essential #{role} support",
          suggestion: get_role_suggestion(role)
        }
      end)

    recommendations ++ fleet_recommendations
  end

  defp add_composition_recommendations(recommendations, composition) do
    composition_recommendations = []

    # Check for over-concentration in single ship class
    max_percentage =
      composition
      |> Map.values()
      |> Enum.map(& &1.percentage)
      |> Enum.max(fn -> 0 end)

    diversity_recommendations =
      if max_percentage > 70 do
        [
          %{
            type: :ship_diversity,
            priority: :medium,
            description: "Fleet composition lacks diversity",
            suggestion: "Consider adding different ship classes for tactical flexibility"
          }
          | composition_recommendations
        ]
      else
        composition_recommendations
      end

    recommendations ++ diversity_recommendations
  end

  defp add_mass_recommendations(recommendations, total_mass, _participants) do
    mass_recommendations = []

    # Check wormhole compatibility
    c2_limit = @wormhole_mass_limits.c2

    wormhole_optimization_recommendations =
      if total_mass > c2_limit do
        [
          %{
            type: :mass_optimization,
            priority: :medium,
            description: "Fleet exceeds C2 wormhole mass limits",
            suggestion: "Consider lighter ship options for wormhole operations",
            current_mass: total_mass,
            c2_limit: c2_limit
          }
          | mass_recommendations
        ]
      else
        mass_recommendations
      end

    recommendations ++ wormhole_optimization_recommendations
  end

  defp add_tactical_recommendations(recommendations, _fleet_data) do
    tactical_recs = [
      %{
        type: :tactical,
        priority: :low,
        description: "Standard tactical recommendations",
        suggestion: "Ensure proper fleet coordination and communication protocols"
      }
    ]

    recommendations ++ tactical_recs
  end

  defp filter_high_priority_recommendations(recommendations) do
    Enum.filter(recommendations, &(&1.priority == :high))
  end

  defp calculate_improvement_potential(fleet_data) do
    # Calculate how much the fleet could be improved
    participants = fleet_data.participants

    current_effectiveness =
      calculate_composition_effectiveness(
        analyze_ship_composition(participants),
        analyze_role_distribution(participants)
      )

    # Theoretical maximum effectiveness
    max_effectiveness = 1.0

    improvement_potential = (max_effectiveness - current_effectiveness) / max_effectiveness

    Float.round(improvement_potential * 100, 1)
  end

  defp get_role_suggestion(role) do
    case role do
      :logistics -> "Add logistics cruisers for fleet sustainability"
      :tackle -> "Include fast tackle ships for engagement control"
      :dps -> "Ensure sufficient damage dealing capability"
      :ewar -> "Consider electronic warfare for tactical advantage"
    end
  end

  defp distribute_pilots_to_doctrine(ship_requirements, _role_requirements, pilot_count) do
    # Simplified pilot distribution algorithm
    # In reality, this would be more sophisticated

    total_min_pilots = Map.values(ship_requirements) |> Enum.map(& &1.min_count) |> Enum.sum()

    if pilot_count < total_min_pilots do
      # Not enough pilots for minimum requirements
      %{
        ship_allocation: %{},
        role_allocation: %{},
        total_mass: 0,
        compliance_score: 0.0
      }
    else
      # Distribute pilots proportionally
      ship_allocation =
        Map.new(ship_requirements, fn {ship_type_id, requirement} ->
          allocated_count =
            max(
              requirement.min_count,
              round(pilot_count * requirement.min_count / total_min_pilots)
            )

          {ship_type_id, allocated_count}
        end)

      # Calculate mass and compliance
      total_mass = calculate_allocation_mass(ship_allocation)
      # Perfect compliance since we're following doctrine
      compliance_score = 1.0

      %{
        ship_allocation: ship_allocation,
        role_allocation: convert_ships_to_roles(ship_allocation),
        total_mass: total_mass,
        compliance_score: compliance_score
      }
    end
  end

  defp calculate_allocation_mass(ship_allocation) do
    Enum.sum(
      Enum.map(ship_allocation, fn {ship_type_id, count} ->
        ship_mass =
          case StaticData.get_ship_mass(ship_type_id) do
            {:ok, mass} -> mass
            # Realistic cruiser mass fallback
            {:error, _} -> 12_000_000.0
          end

        ship_mass * count
      end)
    )
  end

  defp convert_ships_to_roles(ship_allocation) do
    Enum.reduce(ship_allocation, %{}, fn {ship_type_id, count}, acc ->
      role =
        case get_ship_class(ship_type_id) do
          :frigate ->
            :tackle

          :destroyer ->
            :dps

          :cruiser ->
            case StaticData.get_ship_class(ship_type_id) do
              :logistics_cruiser -> :logistics
              :force_recon -> :ewar
              :combat_recon -> :ewar
              :heavy_interdictor -> :tackle
              _ -> :dps
            end

          :battlecruiser ->
            :dps

          :battleship ->
            :dps

          :capital ->
            :capital
        end

      Map.update(acc, role, count, &(&1 + count))
    end)
  end

  defp calculate_doctrine_effectiveness(composition, _doctrine) do
    # Calculate how effective this composition would be
    # Based on role balance, ship synergy, and doctrine optimization

    role_balance = calculate_role_balance_from_allocation(composition.role_allocation)
    ship_synergy = calculate_ship_synergy(composition.ship_allocation)
    doctrine_optimization = composition.compliance_score

    (role_balance + ship_synergy + doctrine_optimization) / 3
  end

  defp calculate_composition_score(composition_breakdown) do
    # Calculate a score based on ship diversity and balance
    total_ships = Enum.sum(Map.values(composition_breakdown))

    if total_ships > 0 do
      # Diversity bonus (more ship types = higher score up to a point)
      diversity_count = map_size(composition_breakdown)
      # Optimal around 8 ship types
      diversity_score = min(1.0, diversity_count / 8.0)

      # Balance penalty for heavy concentration in single ship type
      max_concentration = Enum.max(Map.values(composition_breakdown)) / total_ships
      # Penalty if >40% in single type
      balance_score = 1.0 - (max_concentration - 0.4)

      # Combined score
      Float.round((diversity_score + max(0.0, balance_score)) / 2.0, 2)
    else
      0.0
    end
  end

  defp calculate_role_balance_from_allocation(role_allocation) do
    total_pilots = Enum.sum(Map.values(role_allocation))

    if total_pilots > 0 do
      dps_ratio = Map.get(role_allocation, :dps, 0) / total_pilots
      logistics_ratio = Map.get(role_allocation, :logistics, 0) / total_pilots
      tackle_ratio = Map.get(role_allocation, :tackle, 0) / total_pilots

      # Ideal ratios: 60% DPS, 15% Logistics, 25% Tackle
      dps_score = 1 - abs(dps_ratio - 0.60)
      logistics_score = 1 - abs(logistics_ratio - 0.15)
      tackle_score = 1 - abs(tackle_ratio - 0.25)

      (dps_score + logistics_score + tackle_score) / 3
    else
      0.0
    end
  end

  defp calculate_ship_synergy(ship_allocation) do
    # Calculate how well ships work together
    # This is simplified - real implementation would consider ship bonuses, ranges, etc.

    ship_classes =
      Enum.uniq(
        Enum.map(ship_allocation, fn {ship_type_id, _count} ->
          get_ship_class(ship_type_id)
        end)
      )

    # More ship class diversity generally means better tactical flexibility
    # Cap at 4 different classes
    diversity_score = min(1.0, length(ship_classes) / 4)

    diversity_score
  end

  defp calculate_wormhole_compatibility(fleet_data) do
    total_mass = calculate_total_fleet_mass(fleet_data.participants)
    determine_wormhole_compatibility(total_mass)
  end
end
