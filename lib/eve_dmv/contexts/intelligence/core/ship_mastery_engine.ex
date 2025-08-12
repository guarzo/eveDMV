defmodule EveDmv.Contexts.Intelligence.Core.ShipMasteryEngine do
  @moduledoc """
  Analyzes ship mastery and specialization levels.
  Part of the multi-dimensional threat assessment system.
  """

  alias EveDmv.Contexts.Intelligence.Core.ShipPreferenceAnalyzer
  alias EveDmv.Platform.Database.CharacterRepository

  require Logger

  @doc """
  Analyze ship mastery for a character.
  """
  def analyze(character_id) do
    with {:ok, ship_prefs} <- ShipPreferenceAnalyzer.analyze_ship_preferences(character_id),
         {:ok, ship_stats} <- get_ship_performance_stats(character_id) do
      analysis = %{
        character_id: character_id,
        mastery_score: calculate_mastery_score(ship_prefs, ship_stats),
        specialization_level: ship_prefs.specialization_index,
        primary_ships: get_mastered_ships(ship_prefs, ship_stats),
        ship_diversity: ship_prefs.ship_diversity,
        capital_proficiency: ship_prefs.capital_usage,
        advanced_ship_usage: calculate_advanced_usage(ship_prefs),
        progression_stage: ship_prefs.ship_progression.current_stage,
        analyzed_at: DateTime.utc_now()
      }

      {:ok, analysis}
    end
  end

  defp get_ship_performance_stats(character_id) do
    case CharacterRepository.get_character_ship_stats(character_id) do
      {:ok, stats} -> {:ok, stats}
      _ -> {:ok, %{}}
    end
  end

  defp calculate_mastery_score(ship_prefs, _ship_stats) do
    # Base score from favorite ships performance
    ship_scores =
      ship_prefs.favorite_ships
      |> Enum.take(5)
      |> Enum.map(fn ship ->
        efficiency = ship.efficiency
        usage_weight = min(ship.times_used / 50, 1.0)

        # Higher efficiency with significant usage = mastery
        efficiency * usage_weight
      end)

    avg_ship_score =
      if Enum.empty?(ship_scores) do
        0.0
      else
        Enum.sum(ship_scores) / length(ship_scores)
      end

    # Factor in diversity vs specialization
    specialization_bonus = ship_prefs.specialization_index * 0.3

    # Factor in progression
    progression_bonus =
      case ship_prefs.ship_progression.current_stage do
        :capital_pilot -> 0.2
        :advanced_pilot -> 0.15
        :experienced_pilot -> 0.1
        :developing_pilot -> 0.05
        _ -> 0
      end

    # Calculate total mastery score (0-1 scale)
    total = avg_ship_score * 0.5 + specialization_bonus + progression_bonus
    Float.round(min(total, 1.0), 3)
  end

  defp get_mastered_ships(ship_prefs, ship_stats) do
    ship_prefs.favorite_ships
    |> Enum.filter(fn ship ->
      # Consider a ship "mastered" if:
      # - Used more than 20 times
      # - Efficiency > 2.0 (2:1 K/D ratio)
      # - Or high usage with decent efficiency
      (ship.times_used > 20 and ship.efficiency > 2.0) or
        (ship.times_used > 50 and ship.efficiency > 1.0)
    end)
    |> Enum.map(fn ship ->
      stats = Map.get(ship_stats, to_string(ship.ship_type_id), %{})

      %{
        ship_type_id: ship.ship_type_id,
        ship_name: ship.ship_name,
        ship_class: ship.ship_class,
        mastery_level: calculate_ship_mastery_level(ship, stats),
        total_uses: ship.times_used,
        efficiency: ship.efficiency
      }
    end)
    |> Enum.take(10)
  end

  defp calculate_ship_mastery_level(ship, stats) do
    usage_score =
      cond do
        ship.times_used > 100 -> 1.0
        ship.times_used > 50 -> 0.7
        ship.times_used > 20 -> 0.4
        true -> 0.2
      end

    efficiency_score =
      cond do
        ship.efficiency > 5.0 -> 1.0
        ship.efficiency > 3.0 -> 0.7
        ship.efficiency > 2.0 -> 0.4
        ship.efficiency > 1.0 -> 0.2
        true -> 0.1
      end

    # Check for consistent recent usage
    recency_score = if Map.get(stats, "recent_uses", 0) > 5, do: 0.2, else: 0

    total_score = (usage_score + efficiency_score + recency_score) / 2.2

    cond do
      total_score > 0.8 -> :master
      total_score > 0.6 -> :expert
      total_score > 0.4 -> :proficient
      total_score > 0.2 -> :competent
      true -> :learning
    end
  end

  defp calculate_advanced_usage(ship_prefs) do
    tech_dist = ship_prefs.ship_progression.tech_advancement

    # Advanced usage is T2/T3/Faction percentage
    advanced_percentage =
      Map.get(tech_dist, :tech2, 0) +
        Map.get(tech_dist, :tech3, 0) +
        Map.get(tech_dist, :faction, 0)

    Float.round(advanced_percentage / 100, 3)
  end
end
