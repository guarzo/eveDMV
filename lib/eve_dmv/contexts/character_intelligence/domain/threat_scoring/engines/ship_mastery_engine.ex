defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.Engines.ShipMasteryEngine do
  @moduledoc """
  Ship mastery scoring engine for analyzing ship diversity and tactical adaptation.

  Analyzes ship class mastery, tactical usage patterns, and fitting optimization
  to determine ship mastery threat level.
  """

  require Logger
  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.SharedCalculations
  alias EveDmv.StaticData.ShipTypes

  # Normalization constants for ship mastery calculations
  @max_usage_count 10
  @max_ship_diversity 5
  @max_ship_classes 6

  # Specialization thresholds
  @overspecialized_threshold 0.7
  @generalist_threshold 0.3
  @diversity_bonus_limit 0.4

  # Fitting quality weights
  @survival_weight 0.6
  @damage_weight 0.4

  # Ship mastery insight thresholds
  @ship_diversity_excellence_threshold 0.8
  @class_mastery_excellence_threshold 0.75
  @specialization_balance_threshold 0.85

  # Specialization balance scoring
  @overspecialized_penalty 0.6
  @generalist_bonus 0.7
  @perfect_balance_score 1.0
  @diversity_denominator 10

  @doc """
  Calculate ship mastery score based on combat data.
  """
  def calculate_ship_mastery_score(combat_data) do
    Logger.debug("Calculating ship mastery score")

    all_killmails = Map.get(combat_data, :killmails, [])

    # Ship type diversity
    ship_types_used = extract_ship_types_used(all_killmails)
    ship_diversity = calculate_ship_diversity_index(ship_types_used)

    # Ship class mastery (comfort across different ship classes)
    class_mastery = analyze_ship_class_mastery(ship_types_used)

    # Fitting optimization indicators
    fitting_quality = assess_fitting_quality_from_performance(combat_data)

    # Tactical ship usage (right ship for right situation)
    tactical_usage = analyze_tactical_ship_usage(combat_data)

    # Ship specialization vs generalization balance
    specialization_score = calculate_specialization_balance(ship_types_used)

    raw_score =
      ship_diversity * 0.25 +
        class_mastery * 0.25 +
        fitting_quality * 0.20 +
        tactical_usage * 0.15 +
        specialization_score * 0.15

    %{
      raw_score: raw_score,
      normalized_score: normalize_to_10_scale(raw_score),
      components: %{
        ship_diversity: ship_diversity,
        class_mastery: class_mastery,
        fitting_quality: fitting_quality,
        tactical_usage: tactical_usage,
        specialization_score: specialization_score
      },
      ship_usage_breakdown: analyze_ship_usage_patterns(ship_types_used),
      insights:
        generate_ship_mastery_insights(ship_diversity, class_mastery, specialization_score)
    }
  end

  @doc """
  Analyze ship class mastery patterns.
  """
  def analyze_ship_class_mastery(ship_types_map) do
    Logger.debug("Analyzing ship class mastery for #{map_size(ship_types_map)} ship types")

    # Group ships by class and analyze mastery
    ship_classes =
      Enum.group_by(ship_types_map, fn {ship_type_id, _uses} ->
        classify_ship_type(ship_type_id)
      end)

    classes_used = map_size(ship_classes)

    mastery_scores =
      Enum.map(ship_classes, fn {_class, ships} ->
        total_uses = Enum.sum(Enum.map(ships, &elem(&1, 1)))
        ship_count = length(ships)

        # Mastery = usage frequency + diversity within class
        # Normalize to frequent usage
        usage_score = min(1.0, total_uses / @max_usage_count)
        # Normalize to good diversity
        diversity_score = min(1.0, ship_count / @max_ship_diversity)

        (usage_score + diversity_score) / 2
      end)

    if length(mastery_scores) > 0 do
      average_mastery = Enum.sum(mastery_scores) / length(mastery_scores)
      # Main ship classes
      class_breadth = min(1.0, classes_used / @max_ship_classes)

      average_mastery * 0.7 + class_breadth * 0.3
    else
      0.0
    end
  end

  @doc """
  Analyze tactical ship usage patterns.
  """
  def analyze_tactical_ship_usage(combat_data) do
    Logger.debug("Analyzing tactical ship usage")

    # Analyze if character uses appropriate ships for different situations
    ship_types = extract_ship_types_used(Map.get(combat_data, :killmails, []))

    # Check for tactical diversity
    has_tackle = Enum.any?(ship_types, fn {ship_type, _} -> tackle_ship?(ship_type) end)
    has_dps = Enum.any?(ship_types, fn {ship_type, _} -> dps_ship?(ship_type) end)
    has_support = Enum.any?(ship_types, fn {ship_type, _} -> support_ship?(ship_type) end)

    tactical_roles = Enum.count([has_tackle, has_dps, has_support], & &1)
    # Normalize to having all 3 roles
    min(1.0, tactical_roles / 3)
  end

  @doc """
  Analyze ship usage patterns and diversity.
  """
  def analyze_ship_usage_patterns(ship_types_map) do
    Logger.debug("Analyzing ship usage patterns for #{map_size(ship_types_map)} ship types")

    sorted_ships =
      ship_types_map
      |> Enum.sort_by(&elem(&1, 1), :desc)
      # Top 5 most used ships
      |> Enum.take(5)

    %{
      most_used_ships: sorted_ships,
      total_unique_ships: map_size(ship_types_map),
      usage_distribution: calculate_usage_distribution(ship_types_map),
      diversity_score: calculate_ship_diversity_index(ship_types_map),
      specialization_score: calculate_specialization_balance(ship_types_map),
      tactical_coverage: assess_tactical_coverage(ship_types_map)
    }
  end

  # Private helper functions

  defp extract_ship_types_used(killmails) do
    # Extract ship types used by the character
    ship_types =
      killmails
      |> Enum.flat_map(fn km ->
        # Ship type when victim
        victim_ship = if km.victim_character_id, do: [km.victim_ship_type_id], else: []

        # Ship type when attacker
        attacker_ships =
          case km.raw_data do
            %{"attackers" => attackers} when is_list(attackers) ->
              attackers
              |> Enum.filter(&(&1["character_id"] != nil))
              |> Enum.map(& &1["ship_type_id"])
              |> Enum.filter(&(&1 != nil))

            _ ->
              []
          end

        victim_ship ++ attacker_ships
      end)
      |> Enum.filter(&(&1 != nil))
      |> Enum.frequencies()

    ship_types
  end

  defp calculate_ship_diversity_index(ship_types_map) do
    if map_size(ship_types_map) == 0 do
      0.0
    else
      total_uses = ship_types_map |> Map.values() |> Enum.sum()
      unique_ships = map_size(ship_types_map)

      # Shannon diversity index adapted for ship usage
      shannon_diversity =
        ship_types_map
        |> Enum.map(fn {_ship, uses} ->
          proportion = uses / total_uses
          -proportion * :math.log(proportion)
        end)
        |> Enum.sum()

      # Normalize to 0-1 scale
      max_diversity = :math.log(unique_ships)
      if max_diversity > 0, do: shannon_diversity / max_diversity, else: 0.0
    end
  end

  defp classify_ship_type(ship_type_id) do
    case ShipTypes.classify_ship_type(ship_type_id) do
      :unknown -> :other
      type -> type
    end
  end

  defp assess_fitting_quality_from_performance(combat_data) do
    # Heuristic fitting quality assessment based on performance
    victim_killmails = Map.get(combat_data, :victim_killmails, [])
    attacker_killmails = Map.get(combat_data, :attacker_killmails, [])

    survival_rate = SharedCalculations.calculate_survival_rate(combat_data, victim_killmails)
    damage_efficiency = SharedCalculations.calculate_damage_efficiency(attacker_killmails)

    # Ships that survive longer and deal more damage likely have better fits
    survival_rate * @survival_weight + damage_efficiency * @damage_weight
  end

  defp tackle_ship?(ship_type_id) do
    ShipTypes.is_tackle_ship?(ship_type_id) or ShipTypes.is_interceptor?(ship_type_id)
  end

  defp dps_ship?(ship_type_id) do
    ShipTypes.is_dps_ship?(ship_type_id)
  end

  defp support_ship?(ship_type_id) do
    # EWAR, logistics, command ships
    ShipTypes.is_logistics?(ship_type_id) or ShipTypes.is_ewar?(ship_type_id)
  end

  defp calculate_specialization_balance(ship_types_map) do
    if map_size(ship_types_map) == 0 do
      0.5
    else
      total_uses = ship_types_map |> Map.values() |> Enum.sum()
      max_usage = ship_types_map |> Map.values() |> Enum.max()

      specialization_ratio = max_usage / total_uses
      diversity_count = map_size(ship_types_map)

      # Optimal balance: some specialization but also diversity
      specialization_score =
        cond do
          # Too specialized
          specialization_ratio > @overspecialized_threshold -> @overspecialized_penalty
          # Good generalization
          specialization_ratio < @generalist_threshold -> @generalist_bonus
          # Good balance
          true -> @perfect_balance_score
        end

      # Bonus for diversity
      diversity_bonus = min(@diversity_bonus_limit, diversity_count / @diversity_denominator)
      min(@perfect_balance_score, specialization_score + diversity_bonus)
    end
  end

  defp calculate_usage_distribution(ship_types_map) do
    total_uses = ship_types_map |> Map.values() |> Enum.sum()

    ship_types_map
    |> Enum.map(fn {ship_type, uses} ->
      {ship_type, Float.round(uses / total_uses, 3)}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  defp assess_tactical_coverage(ship_types_map) do
    # Assess how well ship choices cover different tactical roles
    has_tackle = Enum.any?(ship_types_map, fn {ship_type, _} -> tackle_ship?(ship_type) end)
    has_dps = Enum.any?(ship_types_map, fn {ship_type, _} -> dps_ship?(ship_type) end)
    has_support = Enum.any?(ship_types_map, fn {ship_type, _} -> support_ship?(ship_type) end)

    roles_covered = Enum.count([has_tackle, has_dps, has_support], & &1)
    # Normalize to 0-1
    roles_covered / 3
  end

  defp generate_ship_mastery_insights(ship_diversity, class_mastery, specialization_score) do
    insights = []

    insights =
      if ship_diversity > @ship_diversity_excellence_threshold do
        ["Excellent ship diversity - comfortable with many hull types" | insights]
      else
        insights
      end

    insights =
      if class_mastery > @class_mastery_excellence_threshold do
        ["Strong mastery across multiple ship classes" | insights]
      else
        insights
      end

    insights =
      if specialization_score > @specialization_balance_threshold do
        ["Good balance between specialization and versatility" | insights]
      else
        insights
      end

    insights
  end

  defp normalize_to_10_scale(score) do
    SharedCalculations.normalize_to_10_scale(score)
  end

  # Private helper functions - removed unused functions
  # calculate_ship_diversity/1 and analyze_fitting_optimization/1 were unused
  # Note: calculate_ship_diversity/1 has other implementations in the codebase that are used
end
