defmodule EveDmv.Intelligence.CharacterFormatters do
  @moduledoc """
  Character analysis display formatting
  """

  alias EveDmv.Presentation.Formatters

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

  def format_character_summary(analysis_results) do
    %{
      threat_assessment: format_threat_assessment(analysis_results),
      key_statistics: format_key_statistics(analysis_results),
      behavioral_profile: format_behavioral_profile(analysis_results),
      tactical_recommendations: format_tactical_recommendations(analysis_results),
      detailed_breakdown: format_detailed_breakdown(analysis_results)
    }
  end

  def format_ship_usage_display(ship_usage) do
    %{
      favorite_ships: format_favorite_ships(ship_usage.favorite_ships),
      ship_categories: format_ship_categories(ship_usage.ship_categories),
      effectiveness: format_ship_effectiveness(ship_usage.effectiveness_by_ship)
    }
  end

  # Private formatting functions

  defp format_overview(character_stats) do
    """
    Character Analysis Overview:
    - Danger Rating: #{character_stats.danger_rating.rating}
    - Success Rate: #{Formatters.format_percentage(character_stats.success_rate)}
    - Primary Timezone: #{character_stats.temporal_patterns.timezone_estimate}
    - Activity Level: #{format_activity_level(character_stats)}
    """
  end

  defp format_combat_summary(character_stats) do
    basic_stats = character_stats.basic_stats

    """
    Combat Performance:
    - Kills: #{basic_stats.kills.count} (#{basic_stats.kills.solo} solo)
    - Losses: #{basic_stats.losses.count} (#{basic_stats.losses.solo} solo)
    - K/D Ratio: #{Float.round(basic_stats.kd_ratio, 2)}
    - ISK Efficiency: #{Formatters.format_percentage(basic_stats.efficiency)}
    - Average Kill Value: #{Formatters.format_isk(basic_stats.kills.average_value)}
    """
  end

  defp format_geographic_summary(geographic_patterns) do
    top_systems =
      geographic_patterns.most_active_systems
      |> Enum.take(3)
      |> Enum.map(&format_system_activity/1)
      |> Enum.join("\n")

    """
    Geographic Activity:
    - Activity Spread: #{geographic_patterns.activity_spread}
    - Space Preference: #{format_space_preference(geographic_patterns)}

    Top Systems:
    #{top_systems}
    """
  end

  defp format_temporal_summary(temporal_patterns) do
    peak_hours =
      temporal_patterns.peak_hours
      |> Enum.map(&format_hour/1)
      |> Enum.join(", ")

    """
    Activity Patterns:
    - Peak Hours: #{peak_hours}
    - Most Active Days: #{Enum.join(temporal_patterns.most_active_days, ", ")}
    - Weekend Warrior: #{if temporal_patterns.weekend_warrior, do: "Yes", else: "No"}
    - Consistency: #{temporal_patterns.activity_consistency}
    """
  end

  defp format_associates_summary(frequent_associates) do
    return_value =
      if frequent_associates == nil || frequent_associates.top_associates == nil ||
           Enum.empty?(frequent_associates.top_associates) do
        "No significant associates identified."
      else
        top_associates =
          frequent_associates.top_associates
          |> Enum.take(5)
          |> Enum.map(&format_associate/1)
          |> Enum.join("\n")

        """
        Frequent Associates:
        #{top_associates}

        #{format_corporation_associations(frequent_associates.corporation_associates)}
        """
      end

    return_value
  end

  defp format_weaknesses_summary(weaknesses) do
    return_value =
      if weaknesses == nil do
        "Insufficient data to identify weaknesses."
      else
        vulnerabilities = []

        vulnerabilities =
          if weaknesses.takes_bad_fights do
            ["Tendency to take unfavorable engagements" | vulnerabilities]
          else
            vulnerabilities
          end

        vulnerabilities =
          if weaknesses.vulnerable_times && length(weaknesses.vulnerable_times) > 0 do
            [
              "Most vulnerable at: #{format_vulnerable_times(weaknesses.vulnerable_times)}"
              | vulnerabilities
            ]
          else
            vulnerabilities
          end

        vulnerabilities =
          if weaknesses.vulnerable_to_ship_types &&
               length(weaknesses.vulnerable_to_ship_types) > 0 do
            [
              "Struggles against: #{format_ship_types(weaknesses.vulnerable_to_ship_types)}"
              | vulnerabilities
            ]
          else
            vulnerabilities
          end

        if Enum.empty?(vulnerabilities) do
          "No significant weaknesses identified."
        else
          Enum.join(vulnerabilities, "\n")
        end
      end

    return_value
  end

  defp format_threat_assessment(analysis_results) do
    danger_rating = analysis_results.danger_rating
    behavioral = analysis_results.behavioral_patterns

    threat_level = assess_threat_level(danger_rating.score, behavioral)

    %{
      level: threat_level,
      score: danger_rating.score,
      factors: format_threat_factors(danger_rating.factors),
      recommendation: generate_threat_recommendation(threat_level)
    }
  end

  defp format_key_statistics(analysis_results) do
    stats = analysis_results.basic_stats

    %{
      kills: stats.kills.count,
      losses: stats.losses.count,
      kd_ratio: Float.round(stats.kd_ratio, 2),
      efficiency: Formatters.format_percentage(stats.efficiency),
      solo_percentage: Formatters.format_percentage(stats.solo_ratio * 100),
      avg_gang_size: Float.round(analysis_results.gang_composition.average_gang_size, 1)
    }
  end

  defp format_behavioral_profile(analysis_results) do
    behavioral = analysis_results.behavioral_patterns
    temporal = analysis_results.temporal_patterns

    %{
      aggression: behavioral.aggression_level,
      risk_profile: behavioral.risk_aversion,
      activity_pattern: behavioral.activity_consistency,
      timezone: temporal.timezone_estimate,
      engagement_preference: format_engagement_preference(analysis_results.gang_composition)
    }
  end

  defp format_tactical_recommendations(analysis_results) do
    recommendations = generate_counter_recommendations(analysis_results)

    %{
      counter_ships: recommendations.ship_recommendations,
      engagement_advice: recommendations.engagement_advice,
      timing_advice: recommendations.timing_advice,
      general_tips: recommendations.general_tips
    }
  end

  defp format_detailed_breakdown(analysis_results) do
    %{
      ship_analysis: format_detailed_ship_analysis(analysis_results.ship_usage),
      geographic_analysis:
        format_detailed_geographic_analysis(analysis_results.geographic_patterns),
      associate_analysis:
        format_detailed_associate_analysis(analysis_results.frequent_associates),
      weakness_analysis: format_detailed_weakness_analysis(analysis_results.weaknesses)
    }
  end

  defp format_activity_level(character_stats) do
    kill_count = character_stats.basic_stats.kills.count
    recent_activity = character_stats.danger_rating.factors.recent_activity

    cond do
      recent_activity > 75 && kill_count > 50 -> "Very High"
      recent_activity > 50 && kill_count > 25 -> "High"
      recent_activity > 25 && kill_count > 10 -> "Moderate"
      recent_activity > 10 -> "Low"
      true -> "Minimal"
    end
  end

  defp format_space_preference(geographic_patterns) do
    wh = geographic_patterns.wormhole_activity
    null = geographic_patterns.nullsec_activity
    low = geographic_patterns.lowsec_activity
    high = geographic_patterns.highsec_activity

    preferences = []
    preferences = if wh > 25, do: ["Wormhole" | preferences], else: preferences
    preferences = if null > 25, do: ["Nullsec" | preferences], else: preferences
    preferences = if low > 25, do: ["Lowsec" | preferences], else: preferences
    preferences = if high > 25, do: ["Highsec" | preferences], else: preferences

    if Enum.empty?(preferences) do
      "Mixed"
    else
      Enum.join(preferences, "/")
    end
  end

  defp format_system_activity(system_info) do
    "  - #{system_info.location}: #{system_info.count} kills"
  end

  defp format_hour(hour) do
    "#{String.pad_leading(Integer.to_string(hour), 2, "0")}:00"
  end

  defp format_associate(associate) do
    "  - #{associate.character_name} (#{associate.corporation_name}): #{associate.appearance_count} joint ops"
  end

  defp format_corporation_associations(corp_associates) do
    if corp_associates && length(corp_associates) > 0 do
      corps =
        corp_associates
        |> Enum.take(3)
        |> Enum.map(&"  - #{&1.corporation_name}: #{&1.total_appearances} appearances")
        |> Enum.join("\n")

      "Top Corporation Associations:\n#{corps}"
    else
      ""
    end
  end

  defp format_vulnerable_times(times) do
    times
    |> Enum.map(&format_hour/1)
    |> Enum.join(", ")
  end

  defp format_ship_types(ship_types) do
    ship_types
    |> Enum.take(3)
    |> Enum.map(fn {ship_type, _count} -> ship_type end)
    |> Enum.join(", ")
  end

  defp assess_threat_level(score, behavioral) do
    aggression_modifier = get_aggression_modifier(behavioral.aggression_level)
    modified_score = score + score * aggression_modifier * 0.1

    score_to_threat_level(modified_score)
  end

  defp get_aggression_modifier(aggression_level) do
    case aggression_level do
      "Very Aggressive" -> 1
      "Aggressive" -> 0
      _ -> -1
    end
  end

  defp score_to_threat_level(score) do
    cond do
      score >= 100 -> "Extreme"
      score >= 50 -> "Very High"
      score >= 25 -> "High"
      score >= 10 -> "Moderate"
      true -> "Low"
    end
  end

  defp format_threat_factors(factors) do
    [
      "Total Kills: #{factors.kill_count}",
      "Solo Kills: #{factors.solo_kills}",
      "Capital Kills: #{factors.capital_kills}",
      "Recent Activity: #{Formatters.format_percentage(factors.recent_activity)}",
      "Kill Efficiency: #{Formatters.format_percentage(factors.kill_efficiency)}"
    ]
  end

  defp generate_threat_recommendation(threat_level) do
    case threat_level do
      "Extreme" ->
        "Extreme caution advised. Avoid engagement unless you have significant numerical or tactical advantage."

      "Very High" ->
        "Very dangerous opponent. Engage only with proper support and intel."

      "High" ->
        "Dangerous pilot. Ensure you have backup and proper ship composition before engaging."

      "Moderate" ->
        "Competent pilot. Standard precautions recommended."

      "Low" ->
        "Limited threat. Normal engagement protocols apply."
    end
  end

  defp format_engagement_preference(gang_composition) do
    cond do
      gang_composition.solo_percentage > 60 -> "Solo"
      gang_composition.small_gang_percentage > 50 -> "Small Gang"
      gang_composition.fleet_percentage > 40 -> "Fleet"
      true -> "Mixed"
    end
  end

  defp generate_counter_recommendations(character_stats) do
    ship_prefs = character_stats.ship_usage
    weaknesses = character_stats.weaknesses
    behavioral = character_stats.behavioral_patterns

    %{
      ship_recommendations: recommend_counter_ships(ship_prefs),
      engagement_advice: recommend_engagement_tactics(behavioral, weaknesses),
      timing_advice: recommend_timing(character_stats.temporal_patterns),
      general_tips: generate_general_tips(character_stats)
    }
  end

  defp recommend_counter_ships(ship_usage) do
    # This would use actual game mechanics knowledge
    favorite_categories = Map.keys(ship_usage.ship_categories)

    counters =
      Enum.flat_map(favorite_categories, fn category ->
        case category do
          "Frigate" -> ["Destroyer", "Cruiser with light drones"]
          "Destroyer" -> ["Cruiser", "Battlecruiser"]
          "Cruiser" -> ["Battlecruiser", "Battleship"]
          "Battlecruiser" -> ["Battleship", "Multiple cruisers"]
          "Battleship" -> ["Bomber wing", "Dreadnought"]
          _ -> ["Flexible composition"]
        end
      end)
      |> Enum.uniq()

    counters
  end

  defp recommend_engagement_tactics(behavioral, weaknesses) do
    tactics = []

    tactics =
      if behavioral.risk_aversion == "Risk Taker" do
        ["Use bait tactics - pilot takes risks" | tactics]
      else
        tactics
      end

    tactics =
      if weaknesses.takes_bad_fights do
        ["Can be baited into unfavorable engagements" | tactics]
      else
        tactics
      end

    tactics =
      case behavioral.engagement_profile.preferred_range do
        "Close" -> ["Maintain range control, kite at distance" | tactics]
        "Long" -> ["Rush to close range, use tackle" | tactics]
        _ -> tactics
      end

    if Enum.empty?(tactics) do
      ["Standard engagement protocols recommended"]
    else
      tactics
    end
  end

  defp recommend_timing(temporal_patterns) do
    quiet_hours = temporal_patterns.quiet_hours

    if length(quiet_hours) > 0 do
      "Target is least active during #{format_hour_range(quiet_hours)}"
    else
      "No clear activity gaps identified"
    end
  end

  defp generate_general_tips(character_stats) do
    tips = []

    tips =
      if character_stats.frequent_associates.top_associates &&
           length(character_stats.frequent_associates.top_associates) > 0 do
        ["Watch for backup - pilot often flies with associates" | tips]
      else
        tips
      end

    tips =
      if character_stats.ship_usage.ship_categories["Capital"] &&
           character_stats.ship_usage.ship_categories["Capital"] > 0 do
        ["Has capital ship experience - check for cyno alts" | tips]
      else
        tips
      end

    tips =
      if character_stats.danger_rating.score > 50 do
        ["High-threat target - ensure proper preparation" | tips]
      else
        tips
      end

    tips
  end

  defp format_favorite_ships(ships) do
    ships
    |> Enum.take(5)
    |> Enum.map(fn ship ->
      %{
        name: ship.ship_name,
        usage_count: ship.count,
        effectiveness: Float.round(ship.effectiveness || 0.0, 1)
      }
    end)
  end

  defp format_ship_categories(categories) do
    categories
    |> Enum.map(fn {category, count} ->
      %{category: category, count: count}
    end)
    |> Enum.sort_by(& &1.count, :desc)
  end

  defp format_ship_effectiveness(effectiveness_data) do
    effectiveness_data
    |> Enum.take(10)
    |> Enum.map(fn ship ->
      %{
        ship: ship.ship_name,
        kills: ship.kills,
        losses: ship.losses,
        effectiveness: Float.round(ship.effectiveness, 1)
      }
    end)
  end

  defp format_hour_range(hours) do
    if length(hours) <= 2 do
      hours |> Enum.map(&format_hour/1) |> Enum.join(" and ")
    else
      min_hour = Enum.min(hours)
      max_hour = Enum.max(hours)
      "#{format_hour(min_hour)} - #{format_hour(max_hour)}"
    end
  end

  defp format_detailed_ship_analysis(ship_usage) do
    %{
      summary: "Pilot shows preference for #{identify_ship_preference(ship_usage)}",
      favorite_hulls: format_favorite_ships(ship_usage.favorite_ships),
      category_breakdown: ship_usage.ship_categories,
      effectiveness_analysis: analyze_ship_effectiveness(ship_usage.effectiveness_by_ship)
    }
  end

  defp format_detailed_geographic_analysis(geographic_patterns) do
    %{
      summary: "Operating in #{geographic_patterns.activity_spread} pattern",
      primary_regions: geographic_patterns.most_active_regions,
      primary_systems: geographic_patterns.most_active_systems,
      space_distribution: %{
        wormhole: geographic_patterns.wormhole_activity,
        nullsec: geographic_patterns.nullsec_activity,
        lowsec: geographic_patterns.lowsec_activity,
        highsec: geographic_patterns.highsec_activity
      }
    }
  end

  defp format_detailed_associate_analysis(frequent_associates) do
    %{
      summary: format_associate_summary(frequent_associates),
      individuals: frequent_associates.top_associates,
      corporations: frequent_associates.corporation_associates,
      alliances: frequent_associates.alliance_associates
    }
  end

  defp format_detailed_weakness_analysis(weaknesses) do
    %{
      summary: summarize_weaknesses(weaknesses),
      vulnerable_times: weaknesses.vulnerable_times,
      vulnerable_to: weaknesses.vulnerable_to_ship_types,
      behavioral_weaknesses: identify_behavioral_weaknesses(weaknesses)
    }
  end

  defp identify_ship_preference(ship_usage) do
    top_category =
      ship_usage.ship_categories
      |> Enum.max_by(fn {_, count} -> count end, fn -> {"Unknown", 0} end)
      |> elem(0)

    "#{top_category} class vessels"
  end

  defp analyze_ship_effectiveness(effectiveness_data) do
    avg_effectiveness =
      if Enum.empty?(effectiveness_data) do
        0.0
      else
        total = Enum.sum(Enum.map(effectiveness_data, & &1.effectiveness))
        total / length(effectiveness_data)
      end

    %{
      average_effectiveness: Float.round(avg_effectiveness, 1),
      best_performing: Enum.take(effectiveness_data, 3),
      worst_performing: effectiveness_data |> Enum.reverse() |> Enum.take(3)
    }
  end

  defp format_associate_summary(frequent_associates) do
    count = length(frequent_associates.top_associates || [])

    cond do
      count == 0 -> "Operates primarily solo"
      count <= 3 -> "Works with small, consistent group"
      count <= 10 -> "Has regular flying partners"
      true -> "Part of active corporation/alliance operations"
    end
  end

  defp summarize_weaknesses(weaknesses) do
    weakness_count = count_identified_weaknesses(weaknesses)

    cond do
      weakness_count == 0 -> "No significant weaknesses identified"
      weakness_count <= 2 -> "Limited exploitable weaknesses"
      weakness_count <= 4 -> "Several potential vulnerabilities"
      true -> "Multiple exploitable weaknesses identified"
    end
  end

  defp identify_behavioral_weaknesses(weaknesses) do
    behavioral = []

    behavioral =
      if weaknesses.takes_bad_fights do
        ["Prone to taking unfavorable engagements" | behavioral]
      else
        behavioral
      end

    behavioral =
      if weaknesses.overconfidence_indicator > 30 do
        ["Shows signs of overconfidence" | behavioral]
      else
        behavioral
      end

    behavioral
  end

  defp count_identified_weaknesses(weaknesses) do
    count = 0
    count = if weaknesses.takes_bad_fights, do: count + 1, else: count

    count =
      if weaknesses.vulnerable_times && length(weaknesses.vulnerable_times) > 0,
        do: count + 1,
        else: count

    count =
      if weaknesses.vulnerable_to_ship_types && length(weaknesses.vulnerable_to_ship_types) > 0,
        do: count + 1,
        else: count

    count =
      if weaknesses.repeated_mistakes && length(weaknesses.repeated_mistakes) > 0,
        do: count + 1,
        else: count

    count
  end
end
