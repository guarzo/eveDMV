defmodule EveDmv.Contexts.Combat.Core.FleetCompositionAnalyzer do
  @moduledoc """
  Analyzes fleet compositions to understand force structure and capabilities.

  Consolidates fleet analysis functionality including:
  - Ship class distribution
  - Doctrine detection
  - Fleet effectiveness evaluation
  - Force comparison
  """

  alias EveDmv.Contexts.Combat.Core.ParticipantAnalyzer

  @doc """
  Analyze the composition of forces in a battle.
  """
  def analyze_composition(killmails) when is_list(killmails) do
    # Extract all ships involved
    ships = extract_all_ships(killmails)

    # Group by affiliation/side
    sides = group_ships_by_side(ships, killmails)

    # Analyze each side's composition
    compositions =
      Enum.map(sides, fn {side, side_ships} ->
        {side, analyze_side_composition(side_ships)}
      end)
      |> Map.new()

    {:ok,
     %{
       sides: compositions,
       comparison: compare_compositions(compositions),
       doctrines: detect_doctrines(compositions),
       effectiveness: calculate_overall_effectiveness(compositions)
     }}
  end

  @doc """
  Get fleet effectiveness for a specific side.
  """
  def get_fleet_effectiveness(killmails, side) do
    with {:ok, composition} <- analyze_composition(killmails) do
      side_comp = Map.get(composition.sides, side)

      if side_comp do
        {:ok, calculate_side_effectiveness(side_comp)}
      else
        {:error, :side_not_found}
      end
    end
  end

  @doc """
  Compare fleet strengths between sides.
  """
  def compare_fleet_strengths(killmails) do
    with {:ok, composition} <- analyze_composition(killmails) do
      {:ok, composition.comparison}
    end
  end

  # Private Functions

  defp extract_all_ships(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      victim_ship = build_ship_entry(km.victim, :victim, km)

      attacker_ships =
        (km.attackers || [])
        |> Enum.map(&build_ship_entry(&1, :attacker, km))
        |> Enum.reject(&is_nil(&1.ship_type_id))

      [victim_ship | attacker_ships]
    end)
  end

  defp build_ship_entry(entity, role, killmail) do
    %{
      character_id: entity["character_id"],
      character_name: entity["character_name"],
      corporation_id: entity["corporation_id"],
      corporation_name: entity["corporation_name"],
      alliance_id: entity["alliance_id"],
      alliance_name: entity["alliance_name"],
      ship_type_id: entity["ship_type_id"],
      ship_name: entity["ship_name"] || entity["ship_type_name"],
      role: role,
      killmail_id: killmail.killmail_id,
      killmail_time: killmail.killmail_time,
      value: if(role == :victim, do: get_in(killmail.zkb, ["totalValue"]) || 0, else: 0)
    }
  end

  defp group_ships_by_side(ships, killmails) do
    # Use participant analyzer to determine sides
    {:ok, participants} = ParticipantAnalyzer.analyze_participants(killmails)

    # Create affiliation map
    affiliation_map =
      participants.all_participants
      |> Enum.map(fn p -> {p.character_id, p[:affiliation] || :unknown} end)
      |> Map.new()

    # Group ships by their pilot's affiliation
    ships
    |> Enum.group_by(fn ship ->
      Map.get(affiliation_map, ship.character_id, :unknown)
    end)
  end

  defp analyze_side_composition(ships) do
    ship_types = group_by_ship_type(ships)
    ship_classes = group_by_ship_class(ships)

    %{
      total_ships: length(ships),
      unique_pilots: ships |> Enum.map(& &1.character_id) |> Enum.uniq() |> length(),
      ship_types: ship_types,
      ship_classes: ship_classes,
      composition_breakdown: calculate_composition_breakdown(ship_classes),
      average_ship_value: calculate_average_value(ships),
      fleet_metrics: calculate_fleet_metrics(ships, ship_classes),
      capabilities: assess_fleet_capabilities(ship_classes),
      weaknesses: identify_weaknesses(ship_classes)
    }
  end

  defp group_by_ship_type(ships) do
    ships
    |> Enum.group_by(& &1.ship_type_id)
    |> Enum.map(fn {type_id, ships} ->
      %{
        type_id: type_id,
        type_name: List.first(ships).ship_name,
        count: length(ships),
        pilots: Enum.map(ships, & &1.character_id) |> Enum.uniq()
      }
    end)
    |> Enum.sort_by(& &1.count, :desc)
  end

  defp group_by_ship_class(ships) do
    ships
    |> Enum.group_by(&classify_ship(&1.ship_type_id))
    |> Enum.map(fn {class, class_ships} ->
      {class,
       %{
         count: length(class_ships),
         ships: Enum.map(class_ships, & &1.ship_type_id) |> Enum.uniq(),
         percentage: length(class_ships) / max(length(ships), 1) * 100
       }}
    end)
    |> Map.new()
  end

  defp classify_ship(ship_type_id) do
    # Use actual ship classification from ShipTypes using EVE static data
    EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id)
  end

  defp calculate_composition_breakdown(ship_classes) do
    total =
      ship_classes
      |> Map.values()
      |> Enum.reduce(0, &(&1.count + &2))

    %{
      dps_percentage:
        calculate_class_percentage(ship_classes, [:battleship, :battlecruiser, :cruiser], total),
      support_percentage: calculate_class_percentage(ship_classes, [:frigate, :destroyer], total),
      capital_percentage: calculate_class_percentage(ship_classes, [:capital], total),
      logistics_percentage: estimate_logistics_percentage(ship_classes)
    }
  end

  defp calculate_class_percentage(ship_classes, class_list, total) do
    if total > 0 do
      count =
        class_list
        |> Enum.reduce(0, fn class, acc ->
          acc + get_in(ship_classes, [class, :count]) || 0
        end)

      count / total * 100
    else
      0
    end
  end

  defp estimate_logistics_percentage(ship_classes) do
    total_ships = ship_classes |> Map.values() |> Enum.reduce(0, &(&1.count + &2))

    if total_ships > 0 do
      logistics_count = calculate_logistics_count(ship_classes)
      Float.round(logistics_count / total_ships * 100, 1)
    else
      0.0
    end
  end

  defp calculate_logistics_count(ship_classes) do
    # Get actual logistics ship type IDs from the database
    logistics_ids = EveDmv.StaticData.ShipTypes.logistics_ship_ids()

    ship_classes
    |> Enum.reduce(0, fn {_class, %{ships: ship_ids}}, acc ->
      logistics_in_class = Enum.count(ship_ids, &(&1 in logistics_ids))
      acc + logistics_in_class
    end)
  end

  defp calculate_average_value(ships) do
    values = Enum.map(ships, & &1.value)
    total = Enum.sum(values)
    count = Enum.count(values, &(&1 > 0))

    if count > 0, do: total / count, else: 0
  end

  defp calculate_fleet_metrics(ships, ship_classes) do
    %{
      fleet_size: length(ships),
      unique_hulls: ships |> Enum.map(& &1.ship_type_id) |> Enum.uniq() |> length(),
      force_projection: calculate_force_projection(ship_classes),
      mobility_rating: calculate_mobility_rating(ship_classes),
      tank_rating: calculate_tank_rating(ship_classes),
      electronic_warfare_capability: estimate_ewar_capability(ship_classes)
    }
  end

  defp calculate_force_projection(ship_classes) do
    # Higher rating for more capitals and battleships
    capital_weight = (ship_classes[:capital][:count] || 0) * 10
    battleship_weight = (ship_classes[:battleship][:count] || 0) * 5
    battlecruiser_weight = (ship_classes[:battlecruiser][:count] || 0) * 3
    cruiser_weight = (ship_classes[:cruiser][:count] || 0) * 2

    capital_weight + battleship_weight + battlecruiser_weight + cruiser_weight
  end

  defp calculate_mobility_rating(ship_classes) do
    # Higher rating for more frigates and destroyers
    frigate_weight = (ship_classes[:frigate][:count] || 0) * 3
    destroyer_weight = (ship_classes[:destroyer][:count] || 0) * 2
    cruiser_weight = ship_classes[:cruiser][:count] || 0

    total_ships =
      ship_classes
      |> Map.values()
      |> Enum.reduce(0, &(&1.count + &2))

    if total_ships > 0 do
      (frigate_weight + destroyer_weight + cruiser_weight) / total_ships * 10
    else
      0
    end
  end

  defp calculate_tank_rating(ship_classes) do
    # Estimate based on ship class distribution
    battleship_weight = (ship_classes[:battleship][:count] || 0) * 5
    capital_weight = (ship_classes[:capital][:count] || 0) * 10
    cruiser_weight = (ship_classes[:cruiser][:count] || 0) * 2

    battleship_weight + capital_weight + cruiser_weight
  end

  defp estimate_ewar_capability(ship_classes) do
    ewar_ids = EveDmv.StaticData.ShipTypes.ewar_ship_ids()

    total_ewar_ships =
      ship_classes
      |> Enum.reduce(0, fn {_class, %{ships: ship_ids}}, acc ->
        ewar_in_class = Enum.count(ship_ids, &(&1 in ewar_ids))
        acc + ewar_in_class
      end)

    case total_ewar_ships do
      0 -> :none
      n when n <= 2 -> :light
      n when n <= 5 -> :moderate
      _ -> :heavy
    end
  end

  defp assess_fleet_capabilities(ship_classes) do
    []
    |> maybe_add_capital_warfare(ship_classes)
    |> maybe_add_subcapital_superiority(ship_classes)
    |> maybe_add_tackle_capability(ship_classes)
  end

  defp maybe_add_capital_warfare(capabilities, ship_classes) do
    if (ship_classes[:capital][:count] || 0) > 0 do
      [:capital_warfare | capabilities]
    else
      capabilities
    end
  end

  defp maybe_add_subcapital_superiority(capabilities, ship_classes) do
    subcap_count =
      [:battleship, :battlecruiser, :cruiser]
      |> Enum.reduce(0, fn class, acc ->
        acc + (ship_classes[class][:count] || 0)
      end)

    if subcap_count > 10 do
      [:subcapital_superiority | capabilities]
    else
      capabilities
    end
  end

  defp maybe_add_tackle_capability(capabilities, ship_classes) do
    tackle_count = (ship_classes[:frigate][:count] || 0) + (ship_classes[:destroyer][:count] || 0)

    if tackle_count > 5 do
      [:tackle_capability | capabilities]
    else
      capabilities
    end
  end

  defp identify_weaknesses(ship_classes) do
    tackle_count = (ship_classes[:frigate][:count] || 0) + (ship_classes[:destroyer][:count] || 0)

    total_ships =
      ship_classes
      |> Map.values()
      |> Enum.reduce(0, &(&1.count + &2))

    max_class_percentage =
      if total_ships > 0 do
        ship_classes
        |> Map.values()
        |> Enum.map(& &1.percentage)
        |> Enum.max()
      else
        0
      end

    []
    |> maybe_add_fleet_weakness(
      estimate_logistics_percentage(ship_classes) < 10,
      :insufficient_logistics
    )
    |> maybe_add_fleet_weakness(tackle_count < 3, :insufficient_tackle)
    |> maybe_add_fleet_weakness(
      total_ships > 0 && max_class_percentage > 60,
      :unbalanced_composition
    )
  end

  defp compare_compositions(side_compositions) do
    sides = Map.keys(side_compositions) |> Enum.sort()

    case sides do
      [side1, side2 | _] ->
        comp1 = side_compositions[side1]
        comp2 = side_compositions[side2]

        %{
          numerical_advantage: compare_numbers(comp1, comp2),
          force_projection_comparison: compare_force_projection(comp1, comp2),
          mobility_comparison: compare_mobility(comp1, comp2),
          composition_matchup: analyze_matchup(comp1, comp2),
          predicted_advantage: predict_advantage(comp1, comp2)
        }

      _ ->
        %{error: :insufficient_sides}
    end
  end

  defp compare_numbers(comp1, comp2) do
    ratio = comp1.total_ships / max(comp2.total_ships, 1)

    cond do
      ratio > 1.5 -> {comp1.total_ships, :significant_advantage}
      ratio > 1.2 -> {comp1.total_ships, :slight_advantage}
      ratio > 0.8 -> {comp1.total_ships, :roughly_equal}
      ratio > 0.67 -> {comp2.total_ships, :slight_disadvantage}
      true -> {comp2.total_ships, :significant_disadvantage}
    end
  end

  defp compare_force_projection(comp1, comp2) do
    fp1 = comp1.fleet_metrics.force_projection
    fp2 = comp2.fleet_metrics.force_projection

    cond do
      fp1 > fp2 * 1.5 -> :dominant
      fp1 > fp2 * 1.2 -> :superior
      fp1 > fp2 * 0.8 -> :comparable
      true -> :inferior
    end
  end

  defp compare_mobility(comp1, comp2) do
    mob1 = comp1.fleet_metrics.mobility_rating
    mob2 = comp2.fleet_metrics.mobility_rating

    cond do
      mob1 > mob2 * 1.3 -> :much_more_mobile
      mob1 > mob2 * 1.1 -> :more_mobile
      mob1 > mob2 * 0.9 -> :similar_mobility
      true -> :less_mobile
    end
  end

  defp analyze_matchup(comp1, comp2) do
    # Analyze how well the compositions match up against each other
    cap1 = get_in(comp1.ship_classes, [:capital, :count]) || 0
    cap2 = get_in(comp2.ship_classes, [:capital, :count]) || 0

    []
    |> assess_capital_advantage(cap1, cap2)
    |> maybe_add_anti_capital_advantage(comp1, cap2)
  end

  defp assess_capital_advantage(advantages, cap1, cap2) do
    cond do
      cap1 > cap2 * 2 -> [:capital_supremacy | advantages]
      cap1 > cap2 -> [:capital_advantage | advantages]
      true -> advantages
    end
  end

  defp maybe_add_anti_capital_advantage(advantages, comp1, cap2) do
    if cap2 > 0 && has_anti_capital_capability?(comp1) do
      [:anti_capital_doctrine | advantages]
    else
      advantages
    end
  end

  defp has_anti_capital_capability?(composition) do
    # Simplified check - would need actual ship type analysis
    battleship_count = get_in(composition.ship_classes, [:battleship, :count]) || 0
    battleship_count > 5
  end

  defp predict_advantage(comp1, comp2) do
    # Simple prediction based on multiple factors
    score1 = calculate_composition_score(comp1)
    score2 = calculate_composition_score(comp2)

    ratio = score1 / max(score2, 1)

    cond do
      ratio > 1.3 -> :strong_advantage_side1
      ratio > 1.1 -> :slight_advantage_side1
      ratio > 0.9 -> :even_match
      ratio > 0.77 -> :slight_advantage_side2
      true -> :strong_advantage_side2
    end
  end

  defp calculate_composition_score(composition) do
    # Weighted score based on various factors
    force_score = composition.fleet_metrics.force_projection * 0.4
    tank_score = composition.fleet_metrics.tank_rating * 0.3
    numbers_score = composition.total_ships * 0.2
    balance_score = (100 - length(composition.weaknesses) * 20) * 0.1

    force_score + tank_score + numbers_score + balance_score
  end

  defp detect_doctrines(side_compositions) do
    side_compositions
    |> Enum.map(fn {side, composition} ->
      {side, identify_doctrine_patterns(composition)}
    end)
    |> Map.new()
  end

  defp identify_doctrine_patterns(composition) do
    patterns = []

    # Check for common doctrine patterns
    patterns = patterns ++ check_armor_doctrine(composition)
    patterns = patterns ++ check_shield_doctrine(composition)
    patterns = patterns ++ check_alpha_doctrine(composition)
    patterns = patterns ++ check_kiting_doctrine(composition)

    %{
      detected_patterns: patterns,
      primary_doctrine: determine_primary_doctrine(patterns),
      doctrine_cohesion: calculate_doctrine_cohesion(composition)
    }
  end

  defp check_armor_doctrine(composition) do
    # Check for armor tanked ships (simplified)
    armor_ships =
      composition.ship_classes
      |> Map.get(:battleship, %{count: 0})
      |> Map.get(:count, 0)

    if armor_ships > 5 do
      [:armor_doctrine]
    else
      []
    end
  end

  defp check_shield_doctrine(_composition) do
    # Would need actual fitting data to properly detect
    []
  end

  defp check_alpha_doctrine(composition) do
    # Check for high-alpha ships like artillery battleships
    battleship_count = get_in(composition.ship_classes, [:battleship, :count]) || 0

    if battleship_count > 10 do
      [:alpha_strike]
    else
      []
    end
  end

  defp check_kiting_doctrine(composition) do
    # High mobility with good range projection
    if composition.fleet_metrics.mobility_rating > 7 do
      [:kiting_doctrine]
    else
      []
    end
  end

  defp determine_primary_doctrine(patterns) do
    # Pick the most likely doctrine
    List.first(patterns) || :mixed_doctrine
  end

  defp calculate_doctrine_cohesion(composition) do
    # How well does the fleet follow a single doctrine?
    unique_ships = composition.ship_types |> length()
    total_ships = composition.total_ships

    if total_ships > 0 do
      diversity_ratio = unique_ships / total_ships

      cond do
        diversity_ratio < 0.2 -> :high_cohesion
        diversity_ratio < 0.4 -> :moderate_cohesion
        diversity_ratio < 0.6 -> :low_cohesion
        true -> :no_cohesion
      end
    else
      :unknown
    end
  end

  defp calculate_overall_effectiveness(side_compositions) do
    side_compositions
    |> Enum.map(fn {side, comp} ->
      {side, calculate_side_effectiveness(comp)}
    end)
    |> Map.new()
  end

  defp calculate_side_effectiveness(composition) do
    # Calculate overall effectiveness score
    scores = %{
      composition_score: rate_composition_balance(composition),
      capability_score: rate_capabilities(composition),
      weakness_penalty: calculate_weakness_penalty(composition),
      doctrine_bonus: calculate_doctrine_bonus(composition)
    }

    overall =
      (scores.composition_score + scores.capability_score +
         scores.doctrine_bonus - scores.weakness_penalty) / 3

    %{
      overall_rating: categorize_effectiveness(overall),
      overall_score: overall,
      breakdown: scores,
      recommendations: generate_recommendations(composition, scores)
    }
  end

  defp rate_composition_balance(composition) do
    # Rate how well-balanced the fleet composition is
    breakdown = composition.composition_breakdown

    # Ideal ratios (simplified)
    dps_score = rate_percentage(breakdown.dps_percentage, 40, 60) * 40
    support_score = rate_percentage(breakdown.support_percentage, 20, 40) * 30
    logi_score = rate_percentage(breakdown.logistics_percentage, 10, 20) * 30

    dps_score + support_score + logi_score
  end

  defp rate_percentage(actual, min_ideal, max_ideal) do
    cond do
      actual >= min_ideal && actual <= max_ideal -> 1.0
      actual < min_ideal -> actual / min_ideal
      actual > max_ideal -> max_ideal / actual
    end
  end

  defp rate_capabilities(composition) do
    # More capabilities = higher score
    length(composition.capabilities) * 20
  end

  defp calculate_weakness_penalty(composition) do
    # More weaknesses = higher penalty
    length(composition.weaknesses) * 15
  end

  defp calculate_doctrine_bonus(composition) do
    # Calculate doctrine effectiveness based on detected patterns and cohesion
    doctrine_info = identify_doctrine_patterns(composition)

    base_bonus =
      case doctrine_info.primary_doctrine do
        # Well-coordinated armor fleets are effective
        :armor_doctrine -> 15
        # Alpha doctrine provides tactical advantage
        :alpha_strike -> 12
        # Kiting requires good coordination
        :kiting_doctrine -> 10
        # Mixed doctrines are less optimal
        :mixed_doctrine -> 5
        _ -> 0
      end

    # Cohesion multiplier
    cohesion_multiplier =
      case doctrine_info.doctrine_cohesion do
        # Highly cohesive fleets get bonus
        :high_cohesion -> 1.5
        # Moderate cohesion gets small bonus
        :moderate_cohesion -> 1.2
        # Low cohesion is neutral
        :low_cohesion -> 1.0
        # No cohesion penalizes effectiveness
        :no_cohesion -> 0.8
        _ -> 1.0
      end

    # Fleet size bonus - larger fleets benefit more from doctrine
    size_bonus =
      case composition.total_ships do
        # Large fleets benefit from doctrine
        n when n >= 50 -> 5
        # Medium fleets get some benefit
        n when n >= 20 -> 3
        # Small fleets don't benefit much
        _ -> 0
      end

    # Role balance bonus - balanced fleets are more effective
    balance_bonus = calculate_role_balance_bonus(composition)

    final_bonus = (base_bonus + size_bonus + balance_bonus) * cohesion_multiplier
    Float.round(final_bonus, 1)
  end

  defp calculate_role_balance_bonus(composition) do
    # Analyze role distribution for balance
    logistics_pct = composition.composition_breakdown.logistics_percentage
    dps_pct = composition.composition_breakdown.dps_percentage
    support_pct = composition.composition_breakdown.support_percentage

    # Ideal fleet composition bonuses
    logistics_score =
      cond do
        # Optimal logistics ratio
        logistics_pct >= 10 && logistics_pct <= 20 -> 5
        # Good logistics ratio
        logistics_pct >= 7 && logistics_pct <= 25 -> 3
        # Minimal logistics
        logistics_pct >= 4 -> 1
        # No logistics penalty
        true -> -2
      end

    dps_score =
      cond do
        # Good DPS backbone
        dps_pct >= 40 && dps_pct <= 70 -> 3
        # Adequate DPS
        dps_pct >= 30 -> 1
        # Insufficient DPS
        true -> -1
      end

    support_score =
      cond do
        # Good support presence
        support_pct >= 15 && support_pct <= 35 -> 2
        # Some support
        support_pct >= 10 -> 1
        # No support bonus
        true -> 0
      end

    logistics_score + dps_score + support_score
  end

  defp categorize_effectiveness(score) do
    cond do
      score >= 80 -> :excellent
      score >= 60 -> :good
      score >= 40 -> :adequate
      score >= 20 -> :poor
      true -> :critical
    end
  end

  defp generate_recommendations(composition, scores) do
    []
    |> maybe_add_composition_recommendation(scores.composition_score < 50)
    |> add_weakness_recommendations(composition.weaknesses)
  end

  defp maybe_add_composition_recommendation(recommendations, true) do
    ["Improve fleet composition balance" | recommendations]
  end

  defp maybe_add_composition_recommendation(recommendations, false), do: recommendations

  defp add_weakness_recommendations(recommendations, weaknesses) do
    weakness_recommendations =
      Enum.map(weaknesses, fn weakness ->
        case weakness do
          :insufficient_logistics -> "Add more logistics ships"
          :insufficient_tackle -> "Add more tackle frigates/dictors"
          :unbalanced_composition -> "Diversify ship types"
          _ -> "Address #{weakness}"
        end
      end)

    recommendations ++ weakness_recommendations
  end

  defp maybe_add_fleet_weakness(weaknesses, true, weakness), do: [weakness | weaknesses]
  defp maybe_add_fleet_weakness(weaknesses, false, _weakness), do: weaknesses
end
