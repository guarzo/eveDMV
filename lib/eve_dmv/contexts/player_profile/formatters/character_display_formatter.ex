defmodule EveDmv.Contexts.PlayerProfile.Formatters.CharacterDisplayFormatter do
  @moduledoc """
  Character analysis display formatting for Player Profile context.

  Provides formatted output for character analysis results including
  combat summaries, ship usage patterns, and behavioral insights.
  """

  # alias EveDmv.Presentation.Formatters
  alias EveDmv.Utils.MathUtils

  @doc """
  Format complete character analysis for display.
  """
  def format_analysis_summary(character_stats) do
    %{
      overview: format_overview(character_stats),
      combat_summary: format_combat_summary(character_stats),
      ship_usage: format_ship_usage_display(character_stats.ship_usage),
      geographic_activity: format_geographic_summary(character_stats.geographic_patterns),
      temporal_patterns: format_temporal_summary(character_stats.temporal_patterns),
      associates: format_associates_summary(character_stats.frequent_associates),
      weaknesses: format_weaknesses_summary(character_stats.weaknesses),
      recommendations: generate_counter_recommendations(character_stats)
    }
  end

  @doc """
  Format character summary for quick overview.
  """
  def format_character_summary(analysis_results) do
    %{
      threat_assessment: format_threat_assessment(analysis_results),
      key_statistics: format_key_statistics(analysis_results),
      behavioral_profile: format_behavioral_profile(analysis_results),
      tactical_recommendations: format_tactical_recommendations(analysis_results),
      detailed_breakdown: format_detailed_breakdown(analysis_results)
    }
  end

  # Private formatting functions

  defp format_overview(character_stats) do
    %{
      character_name: character_stats.character_name,
      activity_level:
        classify_activity_level(character_stats.total_kills + character_stats.total_losses),
      experience_level: classify_experience_level(character_stats),
      primary_role: determine_primary_combat_role(character_stats),
      threat_level: classify_threat_level(character_stats.combat_effectiveness)
    }
  end

  defp format_combat_summary(character_stats) do
    %{
      total_kills: character_stats.total_kills,
      total_losses: character_stats.total_losses,
      efficiency: MathUtils.safe_round(character_stats.combat_effectiveness, 2),
      favorite_ships: format_top_ships(character_stats.ship_usage),
      preferred_regions: format_top_regions(character_stats.geographic_patterns)
    }
  end

  defp format_ship_usage_display(ship_usage) when is_map(ship_usage) do
    ship_usage
    |> Enum.sort_by(fn {_ship, count} -> count end, :desc)
    |> Enum.take(10)
    |> Enum.map(fn {ship_name, usage_count} ->
      %{
        ship_name: ship_name,
        usage_count: usage_count,
        percentage: calculate_ship_percentage(ship_usage, ship_name, usage_count)
      }
    end)
  end

  defp format_ship_usage_display(_), do: []

  defp format_geographic_summary(geographic_patterns) when is_map(geographic_patterns) do
    %{
      highsec_activity: Map.get(geographic_patterns, :highsec_percentage, 0),
      lowsec_activity: Map.get(geographic_patterns, :lowsec_percentage, 0),
      nullsec_activity: Map.get(geographic_patterns, :nullsec_percentage, 0),
      wormhole_activity: Map.get(geographic_patterns, :wormhole_percentage, 0),
      preferred_regions: format_preferred_regions(geographic_patterns)
    }
  end

  defp format_geographic_summary(_), do: %{}

  defp format_temporal_summary(temporal_patterns) when is_map(temporal_patterns) do
    %{
      peak_activity_hour: Map.get(temporal_patterns, :peak_hour, "Unknown"),
      activity_distribution: Map.get(temporal_patterns, :hour_distribution, %{}),
      weekend_ratio: Map.get(temporal_patterns, :weekend_ratio, 0.0),
      timezone_estimate: estimate_timezone(temporal_patterns)
    }
  end

  defp format_temporal_summary(_), do: %{}

  defp format_associates_summary(associates) when is_list(associates) do
    Enum.map(Enum.take(associates, 5), fn associate ->
      %{
        character_name: associate.character_name,
        corporation: associate.corporation_name,
        shared_kills: associate.shared_kills,
        relationship_strength: classify_relationship_strength(associate.shared_kills)
      }
    end)
  end

  defp format_associates_summary(_), do: []

  defp format_weaknesses_summary(weaknesses) when is_list(weaknesses) do
    Enum.map(Enum.take(weaknesses, 5), fn weakness ->
      %{
        weakness_type: weakness.type,
        severity: weakness.severity,
        description: weakness.description,
        exploitation_difficulty: weakness.exploitation_difficulty
      }
    end)
  end

  defp format_weaknesses_summary(_), do: []

  defp generate_counter_recommendations(character_stats) do
    recommendations = []

    # Ship-based recommendations
    ship_recommendations = generate_ship_counter_recommendations(character_stats.ship_usage)

    # Tactical recommendations
    tactical_recommendations = generate_tactical_recommendations_from_stats(character_stats)

    # Geographic recommendations
    geographic_recommendations =
      generate_geographic_recommendations(character_stats.geographic_patterns)

    Enum.take(
      recommendations ++
        ship_recommendations ++ tactical_recommendations ++ geographic_recommendations,
      5
    )
  end

  defp format_threat_assessment(analysis_results) do
    %{
      threat_level: Map.get(analysis_results, :threat_level, :unknown),
      risk_factors: Map.get(analysis_results, :risk_factors, []),
      confidence_score: Map.get(analysis_results, :confidence_score, 0.0)
    }
  end

  defp format_key_statistics(analysis_results) do
    %{
      combat_score: Map.get(analysis_results, :combat_score, 0),
      activity_score: Map.get(analysis_results, :activity_score, 0),
      versatility_score: Map.get(analysis_results, :versatility_score, 0)
    }
  end

  defp format_behavioral_profile(analysis_results) do
    %{
      aggression_level: Map.get(analysis_results, :aggression_level, :moderate),
      risk_tolerance: Map.get(analysis_results, :risk_tolerance, :moderate),
      social_tendencies: Map.get(analysis_results, :social_tendencies, :balanced)
    }
  end

  defp format_tactical_recommendations(analysis_results) do
    Enum.map(Map.get(analysis_results, :tactical_recommendations, []), fn rec ->
      %{
        category: rec.category,
        recommendation: rec.text,
        priority: rec.priority
      }
    end)
  end

  defp format_detailed_breakdown(analysis_results) do
    %{
      ship_preferences: Map.get(analysis_results, :ship_analysis, %{}),
      combat_patterns: Map.get(analysis_results, :combat_patterns, %{}),
      fleet_behavior: Map.get(analysis_results, :fleet_behavior, %{})
    }
  end

  # Helper functions

  defp classify_activity_level(total_activity) do
    cond do
      total_activity > 1000 -> :very_high
      total_activity > 500 -> :high
      total_activity > 100 -> :moderate
      total_activity > 20 -> :low
      true -> :very_low
    end
  end

  defp classify_experience_level(character_stats) do
    total_activity = character_stats.total_kills + character_stats.total_losses
    diversity = character_stats.ship_diversity_index || 0.0

    cond do
      total_activity > 1000 and diversity > 0.7 -> :veteran
      total_activity > 500 and diversity > 0.5 -> :experienced
      total_activity > 100 -> :intermediate
      total_activity > 20 -> :novice
      true -> :rookie
    end
  end

  defp determine_primary_combat_role(character_stats) do
    ship_usage = character_stats.ship_usage || %{}

    # Simplified role determination based on ship usage
    cond do
      has_significant_usage?(ship_usage, ["Logistics", "Guardian", "Basilisk"]) -> :logistics
      has_significant_usage?(ship_usage, ["Interceptor", "Assault Frigate"]) -> :tackle
      has_significant_usage?(ship_usage, ["Battleship", "Marauder"]) -> :heavy_dps
      has_significant_usage?(ship_usage, ["Cruiser", "Heavy Assault Cruiser"]) -> :dps
      true -> :generalist
    end
  end

  defp classify_threat_level(combat_effectiveness) do
    cond do
      combat_effectiveness > 0.8 -> :high
      combat_effectiveness > 0.6 -> :moderate
      combat_effectiveness > 0.4 -> :low
      true -> :minimal
    end
  end

  defp format_top_ships(ship_usage) when is_map(ship_usage) do
    ship_usage
    |> Enum.sort_by(fn {_ship, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {ship_name, count} -> %{ship: ship_name, count: count} end)
  end

  defp format_top_ships(_), do: []

  defp format_top_regions(geographic_patterns) when is_map(geographic_patterns) do
    region_data = Map.get(geographic_patterns, :region_activity, %{})

    region_data
    |> Enum.sort_by(fn {_region, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {region_name, count} -> %{region: region_name, activity: count} end)
  end

  defp format_top_regions(_), do: []

  defp calculate_ship_percentage(ship_usage, _ship_name, usage_count) do
    total_usage = Enum.sum(Map.values(ship_usage))

    if total_usage > 0 do
      Float.round(usage_count / total_usage * 100, 1)
    else
      0.0
    end
  end

  defp format_preferred_regions(geographic_patterns) do
    geographic_patterns
    |> Map.get(:region_activity, %{})
    |> Enum.sort_by(fn {_region, activity} -> activity end, :desc)
    |> Enum.take(5)
    |> Enum.map(fn {region, activity} -> %{region: region, activity_count: activity} end)
  end

  defp estimate_timezone(temporal_patterns) do
    peak_hour = Map.get(temporal_patterns, :peak_hour, 12)

    # Rough timezone estimation based on peak activity hour
    cond do
      peak_hour >= 18 and peak_hour <= 23 -> "EU (UTC+1)"
      peak_hour >= 0 and peak_hour <= 6 -> "US East (UTC-5)"
      peak_hour >= 22 or peak_hour <= 4 -> "US West (UTC-8)"
      peak_hour >= 8 and peak_hour <= 14 -> "Asia/Pacific (UTC+8)"
      true -> "Unknown"
    end
  end

  defp classify_relationship_strength(shared_kills) do
    cond do
      shared_kills > 50 -> :very_strong
      shared_kills > 20 -> :strong
      shared_kills > 10 -> :moderate
      shared_kills > 5 -> :weak
      true -> :minimal
    end
  end

  defp generate_ship_counter_recommendations(ship_usage) when is_map(ship_usage) do
    top_ships =
      ship_usage
      |> Enum.sort_by(fn {_ship, count} -> count end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {ship_name, _count} -> ship_name end)

    Enum.map(top_ships, fn ship_name ->
      %{
        category: :ship_counter,
        text:
          "Consider using #{get_ship_counter(ship_name)} against their preferred #{ship_name}",
        priority: :medium
      }
    end)
  end

  defp generate_ship_counter_recommendations(_), do: []

  defp generate_tactical_recommendations_from_stats(character_stats) do
    solo_ratio = character_stats.solo_ratio || 0.5
    initial_recommendations = []

    solo_recommendations =
      if solo_ratio > 0.7 do
        [
          %{
            category: :tactical,
            text: "Target likely operates solo - consider gang tactics",
            priority: :high
          }
          | initial_recommendations
        ]
      else
        initial_recommendations
      end

    final_recommendations =
      if character_stats.combat_effectiveness < 0.5 do
        [
          %{
            category: :tactical,
            text: "Target shows poor combat performance - aggressive approach viable",
            priority: :medium
          }
          | solo_recommendations
        ]
      else
        solo_recommendations
      end

    final_recommendations
  end

  defp generate_geographic_recommendations(geographic_patterns)
       when is_map(geographic_patterns) do
    initial_recommendations = []

    wh_percentage = Map.get(geographic_patterns, :wormhole_percentage, 0)
    nullsec_percentage = Map.get(geographic_patterns, :nullsec_percentage, 0)

    wh_recommendations =
      if wh_percentage > 50 do
        [
          %{
            category: :geographic,
            text: "Target favors wormhole space - prepare for unknown system tactics",
            priority: :high
          }
          | initial_recommendations
        ]
      else
        initial_recommendations
      end

    if nullsec_percentage > 70 do
      [
        %{
          category: :geographic,
          text: "Target operates primarily in nullsec - expect advanced tactics",
          priority: :medium
        }
        | wh_recommendations
      ]
    else
      wh_recommendations
    end
  end

  defp generate_geographic_recommendations(_), do: []

  defp has_significant_usage?(ship_usage, ship_types) do
    total_usage = Enum.sum(Map.values(ship_usage))

    relevant_usage =
      ship_types
      |> Enum.map(fn ship_type ->
        ship_usage
        |> Map.to_list()
        |> Enum.map(fn {ship_name, count} ->
          if String.contains?(ship_name, ship_type), do: count, else: 0
        end)
        |> Enum.sum()
      end)
      |> Enum.sum()

    if total_usage > 0 do
      relevant_usage / total_usage > 0.3
    else
      false
    end
  end

  defp get_ship_counter(ship_name) do
    cond do
      String.contains?(ship_name, "Interceptor") -> "Heavy Interdictors"
      String.contains?(ship_name, "Battleship") -> "Bombers or HACs"
      String.contains?(ship_name, "Cruiser") -> "Battlecruisers"
      String.contains?(ship_name, "Frigate") -> "Destroyers"
      true -> "appropriate counter ships"
    end
  end
end
