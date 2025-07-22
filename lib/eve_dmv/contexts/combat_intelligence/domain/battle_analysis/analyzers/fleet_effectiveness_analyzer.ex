defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.FleetEffectivenessAnalyzer do
  @moduledoc """
  Fleet effectiveness analysis module.

  Handles calculations for fleet performance, synergy, balance, and combat metrics
  extracted from the larger FleetCompositionAnalyzer for better modularity.
  """

  require Logger

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.ShipClassificationAnalyzer

  @doc """
  Calculate doctrine adherence for a fleet.
  """
  def calculate_doctrine_adherence(participants) do
    if Enum.empty?(participants) do
      %{score: 0.0, coherence: 0.0, doctrine_type: :unknown}
    else
      ship_classes = ShipClassificationAnalyzer.classify_ships_by_class(participants)
      coherence = calculate_doctrine_coherence(ship_classes)
      doctrine_type = identify_doctrine(participants)

      %{
        score: coherence,
        coherence: coherence,
        doctrine_type: doctrine_type
      }
    end
  end

  @doc """
  Calculate role balance score for a fleet.
  """
  def calculate_role_balance_score(role_distribution) do
    if Enum.empty?(role_distribution) do
      0.0
    else
      # Check for presence of key roles
      has_dps =
        Map.has_key?(role_distribution, :battleship) or Map.has_key?(role_distribution, :cruiser)

      has_logistics = Map.has_key?(role_distribution, :logistics)

      has_tackle =
        Map.has_key?(role_distribution, :frigate) or Map.has_key?(role_distribution, :destroyer)

      base_score =
        cond do
          has_dps and has_logistics and has_tackle -> 0.8
          has_dps and (has_logistics or has_tackle) -> 0.6
          has_dps -> 0.4
          true -> 0.2
        end

      # Adjust for role distribution balance
      role_counts = Map.values(role_distribution) |> Enum.map(& &1.count)
      variance = calculate_variance(role_counts)
      balance_penalty = min(variance / 100.0, 0.3)

      max(0.0, base_score - balance_penalty)
    end
  end

  @doc """
  Calculate class consistency score.
  """
  def calculate_class_consistency_score(ship_classes) do
    if Enum.empty?(ship_classes) do
      0.0
    else
      total_ships = Map.values(ship_classes) Enum.sum()
      class_count = map_size(ship_classes)

      # Higher consistency when fewer ship classes are used
      case class_count do
        1 -> 1.0
        2 -> 0.8
        3 -> 0.6
        4 -> 0.4
        _ -> 0.2
      end
    end
  end

  @doc """
  Calculate critical roles score.
  """
  def calculate_critical_roles_score(role_distribution) do
    if Enum.empty?(role_distribution) do
      0.0
    else
      critical_roles = [:logistics, :command_ship, :force_auxiliary]
      present_critical = Enum.count(critical_roles, &Map.has_key?(role_distribution, &1))
      present_critical / length(critical_roles)
    end
  end

  @doc """
  Calculate fleet size score.
  """
  def calculate_fleet_size_score(fleet_size) do
    cond do
      fleet_size >= 100 -> 1.0
      fleet_size >= 50 -> 0.8
      fleet_size >= 25 -> 0.6
      fleet_size >= 10 -> 0.4
      fleet_size >= 5 -> 0.2
      true -> 0.1
    end
  end

  @doc """
  Calculate fleet synergy between participants.
  """
  def calculate_fleet_synergy(participants) do
    if Enum.empty?(participants) do
      %{overall: 0.0, dps_logi: 0.0, tackle_dps: 0.0, ewar: 0.0, range_coherence: 0.0}
    else
      role_distribution = ShipClassificationAnalyzer.calculate_role_distribution(participants)
      ship_classes = ShipClassificationAnalyzer.classify_ships_by_class(participants)

      %{
        overall: calculate_overall_synergy(role_distribution, ship_classes, participants),
        dps_logi: calculate_dps_logi_synergy(role_distribution),
        tackle_dps: calculate_tackle_dps_synergy(role_distribution),
        ewar: calculate_ewar_synergy(role_distribution),
        range_coherence: calculate_range_coherence(participants)
      }
    end
  end

  @doc """
  Estimate fleet effectiveness based on composition.
  """
  def estimate_fleet_effectiveness(participants) do
    if Enum.empty?(participants) do
      %{overall: 0.0, firepower: 0.0, survivability: 0.0, force_multiplier: 0.0, mobility: 0.0}
    else
      %{
        overall: calculate_overall_effectiveness(participants),
        firepower: calculate_firepower_potential(participants),
        survivability: calculate_survivability_score(participants),
        force_multiplier: calculate_force_multiplier_score(participants),
        mobility: calculate_mobility_score(participants)
      }
    end
  end

  @doc """
  Calculate survival rate for ships in killmails.
  """
  def calculate_survival_rate(ships, killmails) do
    if Enum.empty?(ships) do
      0.0
    else
      lost_ships = count_ships_lost(ships, killmails)
      surviving_ships = length(ships) - lost_ships
      surviving_ships / length(ships)
    end
  end

  @doc """
  Count ships lost in killmails.
  """
  def count_ships_lost(ships, killmails) do
    ship_ids = MapSet.new(ships, & &1.character_id)

    killmails
    Enum.count(fn km -> MapSet.member?(ship_ids, km.victim_character_id) end)
  end

  @doc """
  Calculate fleet strength score.
  """
  def calculate_fleet_strength(participants) do
    if Enum.empty?(participants) do
      0.0
    else
      ship_classes = ShipClassificationAnalyzer.classify_ships_by_class(participants)

      # Weight different ship classes by their strength
      strength_weights = %{
        titan: 1000,
        supercarrier: 800,
        carrier: 400,
        dreadnought: 350,
        force_auxiliary: 300,
        battleship: 100,
        command_ship: 80,
        battlecruiser: 60,
        cruiser: 40,
        destroyer: 20,
        frigate: 10,
        logistics: 50
      }

      total_strength =
    ship_classes
    Enum.reduce(0, fn {class, count}, acc ->
          weight = Map.get(strength_weights, class, 10)
          acc + count * weight
        end)

    total_strength
    end
  end

  @doc """
  Rate fleet strength based on total strength score.
  """
  def rate_fleet_strength(total_strength) do
    cond do
      total_strength >= 10000 -> :overwhelming
      total_strength >= 5000 -> :very_strong
      total_strength >= 2000 -> :strong
      total_strength >= 1000 -> :moderate
      total_strength >= 500 -> :weak
      true -> :very_weak
    end
  end

  @doc """
  Analyze composition balance.
  """
  def analyze_composition_balance(role_distribution) do
    if Enum.empty?(role_distribution) do
      %{score: 0.0, rating: :very_poor, issues: ["No ships present"]}
    else
      issues = []

      # Check for essential roles
      issues =
        if not Map.has_key?(role_distribution, :logistics),
          do: ["Missing logistics support" | issues],
          else: issues

      issues =
        if not (Map.has_key?(role_distribution, :battleship) or
                  Map.has_key?(role_distribution, :cruiser)),
           do: ["Missing primary DPS ships" | issues],
           else: issues

      issues =
        if not (Map.has_key?(role_distribution, :frigate) or
                  Map.has_key?(role_distribution, :destroyer)),
           do: ["Missing tackle ships" | issues],
           else: issues

      # Calculate balance score
      balance_score = calculate_role_balance_score(role_distribution)
      rating = rate_balance(balance_score)

      %{
        score: balance_score,
        rating: rating,
        issues: issues
      }
    end
  end

  @doc """
  Rate balance score.
  """
  def rate_balance(balance_score) do
    cond do
      balance_score >= 0.8 -> :excellent
      balance_score >= 0.6 -> :good
      balance_score >= 0.4 -> :fair
      balance_score >= 0.2 -> :poor
      true -> :very_poor
    end
  end

  # Private helper functions

  defp calculate_doctrine_coherence(ship_classes) do
    if Enum.empty?(ship_classes) do
      0.0
    else
      total_ships = Map.values(ship_classes) Enum.sum()
      largest_class_count = Map.values(ship_classes) Enum.max()
      largest_class_count / total_ships
    end
  end

  defp identify_doctrine(participants) do
    ship_classes = ShipClassificationAnalyzer.classify_ships_by_class(participants)

    # Determine doctrine based on dominant ship class
    dominant_class =
    ship_classes
    Enum.max_by(fn {_class, count} -> count end, fn -> {:unknown, 0} end)
    elem(0)

    case dominant_class do
      :battleship -> :battleship_doctrine
      :cruiser -> :cruiser_doctrine
      :frigate -> :frigate_doctrine
      :destroyer -> :destroyer_doctrine
      :titan -> :capital_doctrine
      :supercarrier -> :capital_doctrine
      :carrier -> :capital_doctrine
      _ -> :mixed_doctrine
    end
  end

  defp calculate_overall_synergy(role_distribution, ship_classes, participants) do
    synergy_components = [
      calculate_dps_logi_synergy(role_distribution),
      calculate_tackle_dps_synergy(role_distribution),
      calculate_ewar_synergy(role_distribution),
      calculate_class_compatibility(ship_classes),
      calculate_range_coherence(participants)
    ]

    Enum.sum(synergy_components) / length(synergy_components)
  end

  defp calculate_dps_logi_synergy(role_distribution) do
    dps_count =
      Map.get(role_distribution, :battleship, %{count: 0}).count +
        Map.get(role_distribution, :cruiser, %{count: 0}).count

    logi_count = Map.get(role_distribution, :logistics, %{count: 0}).count

    if dps_count > 0 and logi_count > 0 do
      # Optimal ratio is approximately 4:1 DPS to Logistics
      ratio = dps_count / logi_count
      optimal_ratio = 4.0

      # Calculate how close we are to optimal
      ratio_score = 1.0 - abs(ratio - optimal_ratio) / optimal_ratio
      max(0.0, ratio_score)
    else
      0.0
    end
  end

  defp calculate_tackle_dps_synergy(role_distribution) do
    dps_count =
      Map.get(role_distribution, :battleship, %{count: 0}).count +
        Map.get(role_distribution, :cruiser, %{count: 0}).count

    tackle_count =
      Map.get(role_distribution, :frigate, %{count: 0}).count +
        Map.get(role_distribution, :destroyer, %{count: 0}).count

    if dps_count > 0 and tackle_count > 0 do
      # Some synergy exists when both are present
      min(1.0, tackle_count / dps_count + 0.2)
    else
      0.0
    end
  end

  defp calculate_ewar_synergy(role_distribution) do
    ewar_count =
      Map.get(role_distribution, :cruiser, %{count: 0}).count +
        Map.get(role_distribution, :frigate, %{count: 0}).count

    total_count = Map.values(role_distribution) |> Enum.map(& &1.count) Enum.sum()

    if total_count > 0 do
      ewar_ratio = ewar_count / total_count
      # Optimal EWAR presence is around 20-30%
      optimal_ratio = 0.25
      ratio_score = 1.0 - abs(ewar_ratio - optimal_ratio) / optimal_ratio
      max(0.0, ratio_score)
    else
      0.0
    end
  end

  defp calculate_class_compatibility(ship_classes) do
    if map_size(ship_classes) <= 3 do
      # Good compatibility with few ship classes
      0.8
    else
      # Lower compatibility with many different classes
      0.4
    end
  end

  defp calculate_range_coherence(participants) do
    if Enum.empty?(participants) do
      0.0
    else
      # Estimate based on ship type ranges
      range_categories = Enum.map(participants, &estimate_engagement_range/1)

      dominant_range =
        Enum.frequencies(range_categories) |> Enum.max_by(&elem(&1, 1)) |> elem(0)

      dominant_count = Enum.count(range_categories, &(&1 == dominant_range))

      dominant_count / length(range_categories)
    end
  end

  defp estimate_engagement_range(participant) do
    role = ShipClassificationAnalyzer.classify_ship_role(participant)

    case role do
      :battleship -> :long_range
      :cruiser -> :medium_range
      :destroyer -> :short_range
      :frigate -> :short_range
      :titan -> :long_range
      :carrier -> :long_range
      _ -> :medium_range
    end
  end

  defp calculate_overall_effectiveness(participants) do
    components = [
      calculate_firepower_potential(participants),
      calculate_survivability_score(participants),
      calculate_force_multiplier_score(participants),
      calculate_mobility_score(participants)
    ]

    Enum.sum(components) / length(components)
  end

  defp calculate_firepower_potential(participants) do
    if Enum.empty?(participants) do
      0.0
    else
      # Estimate based on ship types and their typical DPS weights
      total_dps_weight = Enum.reduce(participants, 0, &(&2 + estimate_ship_dps_weight(&1)))
      # Normalize to 0-1 scale based on fleet size
      min(1.0, total_dps_weight / (length(participants) * 500))
    end
  end

  defp estimate_ship_dps_weight(participant) do
    role = ShipClassificationAnalyzer.classify_ship_role(participant)

    case role do
      :titan -> 2000
      :supercarrier -> 1500
      :carrier -> 800
      :dreadnought -> 1200
      :battleship -> 600
      :battlecruiser -> 400
      :cruiser -> 250
      :destroyer -> 150
      :frigate -> 100
      _ -> 200
    end
  end

  defp calculate_survivability_score(participants) do
    if Enum.empty?(participants) do
      0.0
    else
      ship_classes = ShipClassificationAnalyzer.classify_ships_by_class(participants)
      total_ships = length(participants)

      tankiness = calculate_average_tankiness(ship_classes, total_ships)
      logi_support = Map.get(ship_classes, :logistics, 0) / total_ships

      base_survivability = tankiness * 0.7 + logi_support * 0.3
      min(1.0, base_survivability)
    end
  end

  defp calculate_average_tankiness(ship_classes, total_ships) do
    if total_ships == 0 do
      0.0
    else
      # Tank weights for different ship classes
      tank_weights = %{
        titan: 1.0,
        supercarrier: 0.9,
        carrier: 0.8,
        dreadnought: 0.8,
        force_auxiliary: 0.9,
        battleship: 0.7,
        command_ship: 0.6,
        battlecruiser: 0.5,
        cruiser: 0.4,
        destroyer: 0.2,
        frigate: 0.1,
        logistics: 0.5
      }

      weighted_tankiness =
    ship_classes
    Enum.reduce(0.0, fn {class, count}, acc ->
          weight = Map.get(tank_weights, class, 0.3)
          acc + weight * count
        end)

      weighted_tankiness / total_ships
    end
  end

  defp calculate_force_multiplier_score(participants) do
    if Enum.empty?(participants) do
      0.0
    else
      ship_classes = ShipClassificationAnalyzer.classify_ships_by_class(participants)
      total_ships = length(participants)

      # Force multipliers: logistics, command ships, EWAR
      logistics_ratio = Map.get(ship_classes, :logistics, 0) / total_ships
      command_ratio = Map.get(ship_classes, :command_ship, 0) / total_ships

      multiplier_score = logistics_ratio * 0.6 + command_ratio * 0.4
      # Scale up since these are typically low percentages
      min(1.0, multiplier_score * 3)
    end
  end

  defp calculate_mobility_score(participants) do
    if Enum.empty?(participants) do
      0.0
    else
      fast_ships = ShipClassificationAnalyzer.count_fast_ships(participants)
      total_ships = length(participants)

      mobility_ratio = fast_ships / total_ships
      # Scale mobility score
      case mobility_ratio do
        ratio when ratio >= 0.5 -> 1.0
        ratio when ratio >= 0.3 -> 0.8
        ratio when ratio >= 0.1 -> 0.6
        _ -> 0.4
      end
    end
  end

  defp calculate_variance(values) do
    if Enum.empty?(values) do
      0.0
    else
      mean = Enum.sum(values) / length(values)

      variance =
        values |> Enum.map(&:math.pow(&1 - mean, 2)) Enum.sum() |> Kernel./(length(values))

      :math.sqrt(variance)
    end
  end
end
