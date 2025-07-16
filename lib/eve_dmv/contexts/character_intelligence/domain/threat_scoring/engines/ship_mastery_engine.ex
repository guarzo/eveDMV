defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.Engines.ShipMasteryEngine do
  @moduledoc """
  Ship mastery scoring engine for analyzing ship diversity and tactical adaptation.

  Analyzes ship class mastery, tactical usage patterns, and fitting optimization
  to determine ship mastery threat level.
  """

  require Logger

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
      insights: generate_ship_mastery_insights(ship_diversity, class_mastery, specialization_score)
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
        usage_score = min(1.0, total_uses / 10)      # Normalize to frequent usage
        diversity_score = min(1.0, ship_count / 5)   # Normalize to good diversity

        (usage_score + diversity_score) / 2
      end)

    if length(mastery_scores) > 0 do
      average_mastery = Enum.sum(mastery_scores) / length(mastery_scores)
      class_breadth = min(1.0, classes_used / 6)     # 6 main ship classes

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
      |> Enum.take(5)  # Top 5 most used ships

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
    cond do
      ship_type_id in 580..700 -> :frigate
      ship_type_id in 420..450 -> :destroyer
      ship_type_id in 620..650 -> :cruiser
      ship_type_id in 540..570 -> :battlecruiser
      ship_type_id in 640..670 -> :battleship
      ship_type_id in 19_720..19_740 -> :capital
      true -> :other
    end
  end

  defp assess_fitting_quality_from_performance(combat_data) do
    # Heuristic fitting quality assessment based on performance
    victim_killmails = Map.get(combat_data, :victim_killmails, [])
    attacker_killmails = Map.get(combat_data, :attacker_killmails, [])

    survival_rate = calculate_survival_rate(combat_data, victim_killmails)
    damage_efficiency = calculate_damage_efficiency(attacker_killmails)

    # Ships that survive longer and deal more damage likely have better fits
    survival_rate * 0.6 + damage_efficiency * 0.4
  end

  defp calculate_survival_rate(combat_data, victim_killmails) do
    all_killmails = Map.get(combat_data, :killmails, [])
    total_engagements = length(all_killmails)
    deaths = length(victim_killmails)

    if total_engagements > 0 do
      (total_engagements - deaths) / total_engagements
    else
      0.5  # Neutral score for no data
    end
  end

  defp calculate_damage_efficiency(attacker_killmails) do
    if Enum.empty?(attacker_killmails) do
      0.5
    else
      total_damage_contribution =
        attacker_killmails
        |> Enum.map(&extract_damage_contribution/1)
        |> Enum.sum()

      average_contribution = total_damage_contribution / length(attacker_killmails)
      # Normalize damage contribution (15% average = 1.0 score)
      min(1.0, average_contribution / 0.15)
    end
  end

  defp extract_damage_contribution(killmail) do
    case killmail.raw_data do
      %{"victim" => %{"damage_taken" => total_damage}, "attackers" => attackers}
      when is_list(attackers) and is_number(total_damage) and total_damage > 0 ->
        character_damage =
          attackers
          |> Enum.find(&(&1["character_id"] == killmail.victim_character_id))
          |> case do
            %{"damage_done" => damage} when is_number(damage) -> damage
            _ -> 0
          end

        character_damage / total_damage

      _ ->
        0.0
    end
  end

  defp tackle_ship?(ship_type_id) do
    # Frigates and some cruisers commonly used for tackle
    ship_type_id in 580..700 or ship_type_id in [11_182, 11_196]  # Interceptors
  end

  defp dps_ship?(ship_type_id) do
    # Most cruisers, battlecruisers, battleships
    ship_type_id in 620..670
  end

  defp support_ship?(ship_type_id) do
    # EWAR, logistics, command ships
    ship_type_id in [11_978, 11_987, 11_985, 12_003] or  # Logistics
      ship_type_id in [11_957, 11_958, 11_959, 11_961]     # Force Recon
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
          specialization_ratio > 0.7 -> 0.6    # Too specialized
          specialization_ratio < 0.3 -> 0.7    # Good generalization
          true -> 1.0                          # Good balance
        end

      # Bonus for diversity
      diversity_bonus = min(0.4, diversity_count / 10)
      min(1.0, specialization_score + diversity_bonus)
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
    roles_covered / 3  # Normalize to 0-1
  end

  defp generate_ship_mastery_insights(ship_diversity, class_mastery, specialization_score) do
    insights = []

    insights =
      if ship_diversity > 0.8 do
        ["Excellent ship diversity - comfortable with many hull types" | insights]
      else
        insights
      end

    insights =
      if class_mastery > 0.8 do
        ["Strong mastery across multiple ship classes" | insights]
      else
        insights
      end

    insights =
      if specialization_score > 0.8 do
        ["Good balance between specialization and versatility" | insights]
      else
        insights
      end

    insights
  end

  defp normalize_to_10_scale(score) do
    min(10.0, max(0.0, score * 10))
  end

  # Private helper functions - removed unused functions
  # calculate_ship_diversity/1 and analyze_fitting_optimization/1 were unused
  # Note: calculate_ship_diversity/1 has other implementations in the codebase that are used
end
