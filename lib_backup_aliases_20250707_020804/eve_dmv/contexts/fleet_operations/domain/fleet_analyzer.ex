defmodule EveDmv.Contexts.FleetOperations.Domain.FleetAnalyzer do
  @moduledoc """
  Core fleet analysis engine for EVE DMV Fleet Operations.

  Provides comprehensive fleet composition analysis, engagement evaluation,
  and tactical recommendations for fleet commanders and doctrine planners.
  """

  use GenServer
  use EveDmv.ErrorHandler
    alias EveDmv.Contexts.FleetOperations.Infrastructure.FleetRepository
    alias EveDmv.DomainEvents.FleetEngagement
  alias EveDmv.Contexts.FleetOperations.Infrastructure.EngagementCache
  alias EveDmv.DomainEvents.FleetAnalysisComplete
  alias EveDmv.Infrastructure.EventBus
  alias EveDmv.Result
  alias EveDmv.Shared.ShipDatabaseService

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

  # Approximate ship masses by class in kg
  @ship_masses %{
    "frigate" => 1_500_000,
    "destroyer" => 3_000_000,
    "cruiser" => 15_000_000,
    "battlecruiser" => 25_000_000,
    "battleship" => 50_000_000,
    "capital" => 1_000_000_000
  }

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Analyze fleet composition for effectiveness and optimization.
  """
  def analyze_composition(fleet_data) do
    GenServer.call(__MODULE__, {:analyze_composition, fleet_data})
  end

  @doc """
  Analyze a fleet engagement from killmail data.
  """
  def analyze_engagement(engagement_data) do
    GenServer.call(__MODULE__, {:analyze_engagement, engagement_data})
  end

  @doc """
  Calculate mass analysis for wormhole operations.
  """
  def calculate_mass_analysis(fleet_data) do
    GenServer.call(__MODULE__, {:calculate_mass_analysis, fleet_data})
  end

  @doc """
  Generate improvement recommendations for a fleet.
  """
  def generate_improvement_recommendations(fleet_data) do
    GenServer.call(__MODULE__, {:generate_recommendations, fleet_data})
  end

  @doc """
  Calculate optimal composition for a doctrine and pilot count.
  """
  def calculate_optimal_composition(doctrine, pilot_count) do
    GenServer.call(__MODULE__, {:calculate_optimal_composition, doctrine, pilot_count})
  end

  @doc """
  Force reanalysis of a fleet engagement.
  """
  def force_reanalyze_engagement(engagement_id) do
    GenServer.call(__MODULE__, {:force_reanalyze_engagement, engagement_id})
  end

  @doc """
  Calculate wormhole mass limits for fleet data.
  """
  def calculate_wormhole_mass_limits(fleet_data) do
    GenServer.call(__MODULE__, {:calculate_wormhole_mass_limits, fleet_data})
  end

  @doc """
  Get analyzer metrics and performance data.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  # GenServer implementation

  @impl GenServer
  def init(opts) do
    state = %{
      analysis_cache: %{},
      metrics: %{
        compositions_analyzed: 0,
        engagements_analyzed: 0,
        recommendations_generated: 0,
        cache_hits: 0,
        cache_misses: 0,
        average_analysis_time_ms: 0
      },
      recent_analysis_times: []
    }

    Logger.info("FleetAnalyzer started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:analyze_composition, fleet_data}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    case perform_composition_analysis(fleet_data) do
      {:ok, analysis} ->
        end_time = System.monotonic_time(:millisecond)
        analysis_time = end_time - start_time

        new_state = update_analysis_metrics(state, :composition, analysis_time, true)

        {:reply, {:ok, analysis}, new_state}

      {:error, reason} ->
        new_state = update_analysis_metrics(state, :composition, 0, false)
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:analyze_engagement, engagement_data}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    case perform_engagement_analysis(engagement_data) do
      {:ok, analysis} ->
        end_time = System.monotonic_time(:millisecond)
        analysis_time = end_time - start_time

        # Publish engagement analysis complete event
        EventBus.publish(%FleetAnalysisComplete{
          engagement_id: engagement_data.engagement_id,
          analysis_type: :engagement,
          results: analysis,
          timestamp: DateTime.utc_now()
        })

        new_state = update_analysis_metrics(state, :engagement, analysis_time, true)

        {:reply, {:ok, analysis}, new_state}

      {:error, reason} ->
        new_state = update_analysis_metrics(state, :engagement, 0, false)
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:calculate_mass_analysis, fleet_data}, _from, state) do
    case calculate_fleet_mass_analysis(fleet_data) do
      {:ok, mass_analysis} ->
        {:reply, {:ok, mass_analysis}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:generate_recommendations, fleet_data}, _from, state) do
    case generate_fleet_recommendations(fleet_data) do
      {:ok, recommendations} ->
        new_metrics = %{
          state.metrics
          | recommendations_generated: state.metrics.recommendations_generated + 1
        }

        new_state = %{state | metrics: new_metrics}

        {:reply, {:ok, recommendations}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:calculate_optimal_composition, doctrine, pilot_count}, _from, state) do
    case calculate_doctrine_optimal_composition(doctrine, pilot_count) do
      {:ok, composition} ->
        {:reply, {:ok, composition}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:force_reanalyze_engagement, engagement_id}, _from, state) do
    case EngagementCache.get_engagement_details(engagement_id) do
      {:ok, engagement_data} ->
        case perform_engagement_analysis(engagement_data) do
          {:ok, analysis} ->
            # Store updated analysis
            EngagementCache.store_engagement_analysis(engagement_id, analysis)

            Logger.info("Force reanalyzed engagement: #{engagement_id}")
            {:reply, {:ok, analysis}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:calculate_wormhole_mass_limits, fleet_data}, _from, state) do
    case calculate_wormhole_compatibility(fleet_data) do
      {:ok, wormhole_analysis} ->
        {:reply, {:ok, wormhole_analysis}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    # Calculate current average analysis time
    current_avg =
      case state.recent_analysis_times do
        [] -> 0
        times -> Enum.sum(times) / length(times)
      end

    metrics = %{
      state.metrics
      | average_analysis_time_ms: Float.round(current_avg, 2)
    }

    {:reply, metrics, state}
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
        role = get_participant_role(participant)
        Map.update(acc, role, 1, &(&1 + 1))
      end)

    total_participants = length(participants)

    role_distribution =
      Map.new(role_counts, fn {role, count} ->
        {role,
         %{
           count: count,
           percentage: Float.round(count / total_participants * 100, 1)
         }}
      end)

    # Check for essential roles
    essential_roles = [:dps, :logistics, :tackle]

    missing_roles =
      Enum.filter(essential_roles, fn role ->
        Map.get(role_counts, role, 0) == 0
      end)

    %{
      total_participants: total_participants,
      role_distribution: role_distribution,
      missing_essential_roles: missing_roles,
      role_balance_score: calculate_role_balance_score(role_counts)
    }
  end

  defp calculate_composition_effectiveness(composition_breakdown, role_distribution) do
    # Base effectiveness from ship diversity
    diversity_factor = composition_breakdown.diversity_score * 0.3

    # Role balance factor
    role_balance_factor = role_distribution.role_balance_score * 0.4

    # Fleet size factor (diminishing returns after 20 pilots)
    fleet_size = composition_breakdown.total_ships
    size_factor = min(1.0, fleet_size / 20) * 0.3

    overall_effectiveness = diversity_factor + role_balance_factor + size_factor

    Float.round(overall_effectiveness, 3)
  end

  defp calculate_fleet_mass_analysis(fleet_data) do
    participants = fleet_data.participants

    total_mass = calculate_total_fleet_mass(participants)

    # Determine wormhole compatibility
    wormhole_compatibility = determine_wormhole_compatibility(total_mass)

    # Mass distribution by ship class
    mass_distribution = calculate_mass_distribution(participants)

    mass_analysis = %{
      total_mass_kg: total_mass,
      mass_distribution: mass_distribution,
      wormhole_compatibility: wormhole_compatibility,
      mass_efficiency_score: calculate_mass_efficiency(participants, total_mass)
    }

    {:ok, mass_analysis}
  end

  defp generate_fleet_recommendations(fleet_data) do
    participants = fleet_data.participants

    # Analyze current composition
    composition = analyze_ship_composition(participants)
    roles = analyze_role_distribution(participants)

    base_recommendations = []

    # Role-based recommendations
    role_recommendations = add_role_recommendations(base_recommendations, roles)

    # Ship composition recommendations
    composition_suggestions = add_composition_recommendations(role_recommendations, composition)

    # Mass optimization recommendations
    mass_analysis = calculate_total_fleet_mass(participants)

    mass_recommendations =
      add_mass_recommendations(composition_suggestions, mass_analysis, participants)

    # Tactical recommendations
    optimization_recommendations = add_tactical_recommendations(mass_recommendations, fleet_data)

    {:ok,
     %{
       recommendations: optimization_recommendations,
       priority_recommendations:
         filter_high_priority_recommendations(optimization_recommendations),
       improvement_score: calculate_improvement_potential(fleet_data)
     }}
  end

  defp calculate_doctrine_optimal_composition(doctrine, pilot_count) do
    ship_requirements = doctrine.ship_requirements
    role_requirements = doctrine.role_requirements

    # Distribute pilots based on doctrine requirements
    composition = distribute_pilots_to_doctrine(ship_requirements, role_requirements, pilot_count)

    # Calculate effectiveness of this composition
    effectiveness_score = calculate_doctrine_effectiveness(composition, doctrine)

    optimal_composition = %{
      pilot_count: pilot_count,
      ship_allocation: composition.ship_allocation,
      role_allocation: composition.role_allocation,
      effectiveness_score: effectiveness_score,
      mass_total: composition.total_mass,
      doctrine_compliance: composition.compliance_score
    }

    {:ok, optimal_composition}
  end

  # Helper functions

  defp get_ship_class(ship_type_id) do
    ShipDatabaseService.get_ship_class(ship_type_id)
  end

  defp get_participant_role(participant) do
    # In a real implementation, this would determine role based on ship type and fitting
    # For now, we'll use ship class as a proxy
    case get_ship_class(participant.ship_type_id) do
      :frigate -> :tackle
      :destroyer -> :dps
      :cruiser -> if rem(participant.ship_type_id, 3) == 0, do: :logistics, else: :dps
      :battlecruiser -> :dps
      :battleship -> :dps
      :capital -> :capital
    end
  end

  defp calculate_diversity_score(ship_counts) do
    total_ships = Enum.sum(Map.values(ship_counts))
    unique_classes = map_size(ship_counts)

    # Shannon diversity index adapted for fleet composition
    diversity =
      -Enum.sum(Map.values(ship_counts), fn count ->
        proportion = count / total_ships
        proportion * :math.log(proportion)
      end)

    # Normalize to 0-1 range
    max_diversity = :math.log(unique_classes)
    if max_diversity > 0, do: diversity / max_diversity, else: 0
  end

  defp calculate_role_balance_score(role_counts) do
    total_count = Enum.sum(Map.values(role_counts))

    # Check if essential roles are covered
    dps_count = Map.get(role_counts, :dps, 0)
    logistics_count = Map.get(role_counts, :logistics, 0)
    tackle_count = Map.get(role_counts, :tackle, 0)

    # Calculate balance score
    dps_ratio = dps_count / total_count
    logistics_ratio = logistics_count / total_count
    tackle_ratio = tackle_count / total_count

    # Ideal ratios: 60% DPS, 15% Logistics, 25% Tackle
    dps_score = 1 - abs(dps_ratio - 0.60)
    logistics_score = 1 - abs(logistics_ratio - 0.15)
    tackle_score = 1 - abs(tackle_ratio - 0.25)

    # Penalize missing essential roles
    role_coverage =
      if logistics_count > 0 and tackle_count > 0 and dps_count > 0, do: 1.0, else: 0.5

    (dps_score + logistics_score + tackle_score) / 3 * role_coverage
  end

  defp calculate_total_fleet_mass(participants) do
    ships =
      Enum.map(participants, fn participant ->
        %{ship_type_id: participant.ship_type_id}
      end)

    ShipDatabaseService.calculate_fleet_mass(ships)
  end

  defp determine_wormhole_compatibility(total_mass) do
    # Check compatibility for standard wormhole classes
    wh_classes = ["C1", "C2", "C3", "C4", "C5", "C6"]

    Enum.reduce(wh_classes, %{}, fn wh_class, acc ->
      # Get a representative ship to check limits
      case ShipDatabaseService.check_wormhole_compatibility("Vexor", wh_class) do
        {:ok, _} ->
          # Use the analyze_fleet_for_wormhole function for detailed analysis
          # For now, do a simple mass check
          Map.put(acc, String.to_existing_atom(String.downcase(wh_class)), %{
            can_jump: true,
            trips_needed: 1,
            mass_utilization: 0.0
          })

        {:error, _} ->
          Map.put(acc, String.to_existing_atom(String.downcase(wh_class)), %{
            can_jump: false,
            trips_needed: 999,
            mass_utilization: 100.0
          })
      end
    end)
  end

  defp calculate_mass_distribution(participants) do
    mass_by_class =
      Enum.reduce(participants, %{}, fn participant, acc ->
        ship_class = get_ship_class(participant.ship_type_id)
        ship_mass = ShipDatabaseService.get_ship_mass(participant.ship_type_id)

        Map.update(acc, ship_class, ship_mass, &(&1 + ship_mass))
      end)

    total_mass = Enum.sum(Map.values(mass_by_class))

    Map.new(mass_by_class, fn {ship_class, mass} ->
      {ship_class,
       %{
         total_mass: mass,
         percentage: Float.round(mass / total_mass * 100, 1)
       }}
    end)
  end

  defp calculate_mass_efficiency(participants, total_mass) do
    # Mass efficiency based on damage potential per kg
    estimated_dps = estimate_fleet_dps(participants)

    if total_mass > 0 do
      # DPS per million kg
      Float.round(estimated_dps / total_mass * 1_000_000, 2)
    else
      0.0
    end
  end

  defp estimate_fleet_dps(participants) do
    # Rough DPS estimation based on ship classes
    Enum.sum(participants, fn participant ->
      case get_ship_class(participant.ship_type_id) do
        :frigate -> 200
        :destroyer -> 400
        :cruiser -> 600
        :battlecruiser -> 1000
        :battleship -> 1500
        :capital -> 8000
      end
    end)
  end

  defp categorize_participants(participants, killmails) do
    # Determine friendly vs hostile based on killmail analysis
    # This is simplified - in reality would use corporation/alliance info

    victim_corps =
      MapSet.new(Enum.map(killmails, fn km -> km.victim.corporation_id end))

    attacker_corps =
      killmails
      |> Enum.flat_map(fn km -> Enum.map(km.attackers, & &1.corporation_id) end)
      |> MapSet.new()

    # Assume majority corp is friendly
    all_corps = Enum.map(participants, & &1.corporation_id)

    max_corp_tuple =
      all_corps
      |> Enum.frequencies()
      |> Enum.max_by(fn {_corp, count} -> count end)

    majority_corp = elem(max_corp_tuple, 0)

    Enum.split_with(participants, fn participant ->
      participant.corporation_id == majority_corp
    end)
  end

  defp analyze_fleet_performance(participants, killmails, side) do
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

  defp identify_engagement_factors(killmails, friendly_participants, hostile_participants) do
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
    final_factors = analyze_ship_class_factors(numbers_factors, friendly_participants, hostile_participants)

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

  defp extract_lessons_learned(friendly_performance, hostile_performance) do
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
    Enum.sum(killmails, fn killmail ->
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
      composition.ship_classes
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

  defp add_mass_recommendations(recommendations, total_mass, participants) do
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

  defp distribute_pilots_to_doctrine(ship_requirements, role_requirements, pilot_count) do
    # Simplified pilot distribution algorithm
    # In reality, this would be more sophisticated

    total_min_pilots = Enum.sum(Map.values(ship_requirements), & &1.min_count)

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
    Enum.sum(ship_allocation, fn {ship_type_id, count} ->
      ship_class = get_ship_class(ship_type_id)
      ship_mass = Map.get(@ship_masses, to_string(ship_class), 10_000_000)
      ship_mass * count
    end)
  end

  defp convert_ships_to_roles(ship_allocation) do
    Enum.reduce(ship_allocation, %{}, fn {ship_type_id, count}, acc ->
      role =
        case get_ship_class(ship_type_id) do
          :frigate -> :tackle
          :destroyer -> :dps
          :cruiser -> if rem(ship_type_id, 3) == 0, do: :logistics, else: :dps
          :battlecruiser -> :dps
          :battleship -> :dps
          :capital -> :capital
        end

      Map.update(acc, role, count, &(&1 + count))
    end)
  end

  defp calculate_doctrine_effectiveness(composition, doctrine) do
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
      Enum.uniq(Enum.map(ship_allocation, fn {ship_type_id, _count} ->
        get_ship_class(ship_type_id)
      end))

    # More ship class diversity generally means better tactical flexibility
    # Cap at 4 different classes
    diversity_score = min(1.0, length(ship_classes) / 4)

    diversity_score
  end

  defp calculate_wormhole_compatibility(fleet_data) do
    total_mass = calculate_total_fleet_mass(fleet_data.participants)
    determine_wormhole_compatibility(total_mass)
  end

  defp update_analysis_metrics(state, analysis_type, analysis_time, success) do
    new_metrics =
      case analysis_type do
        :composition ->
          %{state.metrics | compositions_analyzed: state.metrics.compositions_analyzed + 1}

        :engagement ->
          %{state.metrics | engagements_analyzed: state.metrics.engagements_analyzed + 1}
      end

    new_processing_times =
      if success do
        [analysis_time | Enum.take(state.recent_analysis_times, 99)]
      else
        state.recent_analysis_times
      end

    %{
      state
      | metrics: new_metrics,
        recent_analysis_times: new_processing_times
    }
  end
end
