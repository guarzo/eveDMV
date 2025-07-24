defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.ThreatScoringCoordinator.Generators.InsightGenerator do
  @moduledoc """
  Generates actionable insights from threat assessment data.

  This module analyzes threat scores and patterns to produce
  human-readable insights for intelligence reporting.

  All insights are based on real data analysis and statistical patterns.
  """

  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw

  require Logger

  @doc """
  Generates threat insights from a comprehensive threat assessment.

  Returns structured insights based on real data analysis including:
  - Threat level categorization
  - Activity pattern analysis
  - Combat behavior insights
  - Temporal activity patterns
  """
  @spec generate_threat_insights(map()) :: {:ok, list()} | {:error, term()}
  def generate_threat_insights(%{character_id: character_id, threat_score: score} = assessment)
      when is_integer(character_id) and is_number(score) do
    Logger.debug("Generating threat insights for character #{character_id} with score #{score}")

    with {:ok, recent_activity} <- fetch_recent_activity(character_id),
         {:ok, threat_patterns} <- analyze_threat_patterns(recent_activity),
         {:ok, insights} <- compile_insights(assessment, threat_patterns) do
      {:ok, insights}
    else
      error ->
        Logger.warning(
          "Failed to generate insights for character #{character_id}: #{inspect(error)}"
        )

        {:error, "Failed to generate insights: #{inspect(error)}"}
    end
  end

  def generate_threat_insights(invalid_assessment) do
    Logger.error("Invalid threat assessment provided: #{inspect(invalid_assessment)}")
    {:error, "Invalid threat assessment format"}
  end

  # Fetch killmail activity from the last 30 days
  defp fetch_recent_activity(character_id) do
    try do
      thirty_days_ago = DateTime.add(DateTime.utc_now(), -30, :day)

      # Query killmails where character was involved as victim or attacker
      victim_killmails =
        KillmailRaw
        |> Api.read!()
        |> Enum.filter(fn km ->
        km.victim_character_id == character_id and
          km.killmail_time >= thirty_days_ago
      end)

      attacker_killmails =
        KillmailRaw
        |> Api.read!()
        |> Enum.filter(fn km ->
        km.killmail_time >= thirty_days_ago and
          Enum.any?(km.attackers || [], fn attacker ->
            attacker.character_id == character_id
          end)
      end)

      all_killmails = Enum.uniq_by(victim_killmails ++ attacker_killmails, & &1.killmail_id)

      {:ok, all_killmails}
    rescue
      error ->
        Logger.error(
          "Error fetching recent activity for character #{character_id}: #{inspect(error)}"
        )

        {:error, "Database query failed"}
    end
  end

  # Analyze patterns in killmail data to extract threat indicators
  defp analyze_threat_patterns(killmails) do
    try do
      patterns = %{
        aggression_frequency: calculate_aggression_frequency(killmails),
        victim_frequency: calculate_victim_frequency(killmails),
        target_preferences: analyze_target_preferences(killmails),
        fleet_patterns: analyze_fleet_participation(killmails),
        timezone_activity: analyze_timezone_patterns(killmails),
        activity_level: calculate_activity_level(killmails)
      }

      {:ok, patterns}
    rescue
      error ->
        Logger.error("Error analyzing threat patterns: #{inspect(error)}")
        {:error, "Pattern analysis failed"}
    end
  end

  # Compile human-readable insights from assessment and patterns
  defp compile_insights(assessment, patterns) do
    insights = []

    # Threat level insights
    insights = add_threat_level_insights(insights, assessment.threat_score)

    # Activity pattern insights
    insights = add_activity_insights(insights, patterns)

    # Combat behavior insights
    insights = add_combat_insights(insights, patterns)

    # Temporal pattern insights
    insights = add_temporal_insights(insights, patterns)

    {:ok, Enum.reverse(insights)}
  rescue
    error ->
      Logger.error("Error compiling insights: #{inspect(error)}")
      {:error, "Insight compilation failed"}
  end

  # Calculate frequency of aggressive actions (as attacker)
  defp calculate_aggression_frequency(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      attacker_count =
        Enum.count(killmails, fn km ->
          Enum.any?(km.attackers || [], fn attacker ->
            is_integer(attacker.character_id) and attacker.character_id > 0
          end)
        end)

      attacker_count / length(killmails)
    end
  end

  # Calculate frequency of being a victim
  defp calculate_victim_frequency(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      victim_count =
        Enum.count(killmails, fn km ->
          is_integer(km.victim_character_id) and km.victim_character_id > 0
        end)

      victim_count / length(killmails)
    end
  end

  # Analyze preferred target ship types
  defp analyze_target_preferences(killmails) do
    killmails
    |> Enum.filter(fn km -> is_integer(km.victim_ship_type_id) end)
    |> Enum.map(& &1.victim_ship_type_id)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(5)
  end

  # Analyze fleet participation patterns (average fleet size)
  defp analyze_fleet_participation(killmails) do
    fleet_sizes =
      killmails
      |> Enum.map(fn km -> length(km.attackers || []) end)
      |> Enum.filter(fn size -> size > 0 end)

    case fleet_sizes do
      [] -> 0.0
      sizes -> Enum.sum(sizes) / length(sizes)
    end
  end

  # Analyze activity by hour of day
  defp analyze_timezone_patterns(killmails) do
    killmails
    |> Enum.filter(fn km -> km.killmail_time != nil end)
    |> Enum.map(fn km -> km.killmail_time.hour end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(3)
  end

  # Calculate overall activity level (killmails per day)
  defp calculate_activity_level(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      # Assume 30-day period
      length(killmails) / 30.0
    end
  end

  # Add threat level categorization insights
  defp add_threat_level_insights(insights, score) when score >= 0.8 do
    ["Extreme threat level - Exercise maximum caution in all interactions" | insights]
  end

  defp add_threat_level_insights(insights, score) when score >= 0.6 do
    ["High threat level detected - Recommend defensive posture" | insights]
  end

  defp add_threat_level_insights(insights, score) when score >= 0.4 do
    ["Moderate threat level - Standard precautions advised" | insights]
  end

  defp add_threat_level_insights(insights, score) when score >= 0.2 do
    ["Low threat level - Minimal risk expected" | insights]
  end

  defp add_threat_level_insights(insights, _score) do
    ["Minimal threat detected - Low combat activity" | insights]
  end

  # Add activity-based insights
  defp add_activity_insights(insights, %{activity_level: level}) when level > 2.0 do
    ["Highly active combatant - #{Float.round(level, 1)} engagements per day average" | insights]
  end

  defp add_activity_insights(insights, %{activity_level: level}) when level > 0.5 do
    ["Moderately active - #{Float.round(level, 1)} engagements per day average" | insights]
  end

  defp add_activity_insights(insights, %{activity_level: level}) when level > 0.1 do
    [
      "Occasional combat activity - #{Float.round(level, 1)} engagements per day average"
      | insights
    ]
  end

  defp add_activity_insights(insights, _patterns) do
    ["Limited combat activity in recent period" | insights]
  end

  # Add combat behavior insights
  defp add_combat_insights(insights, %{aggression_frequency: aggr, victim_frequency: _victim})
       when aggr > 0.7 do
    [
      "Primarily aggressive combatant - #{Float.round(aggr * 100, 0)}% of engagements as attacker"
      | insights
    ]
  end

  defp add_combat_insights(insights, %{aggression_frequency: _aggr, victim_frequency: victim})
       when victim > 0.7 do
    ["Frequently targeted - #{Float.round(victim * 100, 0)}% of engagements as victim" | insights]
  end

  defp add_combat_insights(insights, %{fleet_patterns: avg_fleet}) when avg_fleet > 20 do
    [
      "Large fleet participant - Average fleet size #{Float.round(avg_fleet, 0)} pilots"
      | insights
    ]
  end

  defp add_combat_insights(insights, %{fleet_patterns: avg_fleet}) when avg_fleet > 5 do
    ["Small gang combatant - Average fleet size #{Float.round(avg_fleet, 0)} pilots" | insights]
  end

  defp add_combat_insights(insights, %{fleet_patterns: avg_fleet}) when avg_fleet > 1 do
    ["Solo/duo fighter - Average fleet size #{Float.round(avg_fleet, 0)} pilots" | insights]
  end

  defp add_combat_insights(insights, _patterns) do
    insights
  end

  # Add temporal activity insights
  defp add_temporal_insights(insights, %{timezone_activity: timezone_data})
       when length(timezone_data) > 0 do
    [{peak_hour, _count} | _] = timezone_data
    ["Most active during #{format_hour(peak_hour)} UTC" | insights]
  end

  defp add_temporal_insights(insights, _patterns) do
    insights
  end

  # Format hour for display
  defp format_hour(hour) when hour < 10, do: "0#{hour}:00"
  defp format_hour(hour), do: "#{hour}:00"
end
