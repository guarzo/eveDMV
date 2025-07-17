defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.ThreatScoringCoordinator do
  @moduledoc """
  Main coordinator for threat scoring analysis.

  Orchestrates the various threat scoring engines and combines their results into
  a comprehensive threat assessment.
  """

  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.Engines.{
    CombatThreatEngine,
    ShipMasteryEngine,
    GangEffectivenessEngine,
    UnpredictabilityEngine
  }

  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Api

  import Ash.Query

  require Logger

  # Threat scoring parameters optimized for EVE PvP
  @analysis_window_days 90
  @minimum_killmails_for_scoring 5
  @combat_skill_weight 0.30
  @ship_mastery_weight 0.25
  @gang_effectiveness_weight 0.25
  @unpredictability_weight 0.10
  @recent_activity_weight 0.10

  @threat_levels %{
    extreme: 9.0,
    very_high: 7.5,
    high: 6.0,
    moderate: 4.0,
    low: 2.0,
    minimal: 0.0
  }

  @doc """
  Calculates comprehensive threat score for a character.
  """
  def calculate_threat_score(character_id, options \\ []) do
    Logger.info("Calculating threat score for character #{character_id}")

    analysis_window_days = Keyword.get(options, :analysis_window_days, @analysis_window_days)

    # Fetch real combat data from the database
    case fetch_character_combat_data(character_id, analysis_window_days) do
      {:error, :insufficient_data} ->
        {:error, :insufficient_data}

      {:ok, combat_data} ->
        # Calculate dimensional scores using the real engines with real data
        combat_score = CombatThreatEngine.calculate_combat_skill_score(combat_data)
        ship_score = ShipMasteryEngine.calculate_ship_mastery_score(combat_data)
        gang_score = GangEffectivenessEngine.calculate_gang_effectiveness_score(combat_data)

        unpredictability_score =
          UnpredictabilityEngine.calculate_unpredictability_score(combat_data)

        recent_activity_score = calculate_recent_activity_score(combat_data)

        dimensional_scores = %{
          combat_skill: combat_score,
          ship_mastery: ship_score,
          gang_effectiveness: gang_score,
          unpredictability: unpredictability_score,
          recent_activity: recent_activity_score
        }

        # Calculate weighted threat score
        weighted_score = calculate_weighted_threat_score(dimensional_scores)
        threat_level = determine_threat_level(weighted_score)

        {:ok,
         %{
           character_id: character_id,
           threat_score: weighted_score,
           threat_level: threat_level,
           confidence: calculate_confidence(dimensional_scores),
           analysis_window_days: analysis_window_days,
           total_killmails: length(combat_data.killmails),
           dimensional_scores: dimensional_scores,
           insights: generate_insights(dimensional_scores, threat_level),
           analyzed_at: DateTime.utc_now()
         }}

      {:error, reason} ->
        Logger.warning(
          "Failed to fetch combat data for character #{character_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Compare threat levels between multiple characters.
  """
  def compare_threat_levels(character_ids, options \\ []) when is_list(character_ids) do
    Logger.info("Comparing threat levels for #{length(character_ids)} characters")

    # For now, return placeholder comparison
    comparisons =
      Enum.map(character_ids, fn character_id ->
        {:ok, threat_data} = calculate_threat_score(character_id, options)
        threat_data
      end)

    {:ok,
     %{
       characters: comparisons,
       highest_threat: List.first(comparisons),
       average_threat: 5.0,
       threat_distribution: %{
         extreme: 0,
         very_high: 0,
         high: 0,
         moderate: length(character_ids),
         low: 0,
         minimal: 0
       }
     }}
  end

  @doc """
  Analyze threat trends for a character over time.
  """
  def analyze_threat_trends(character_id, _options \\ []) do
    Logger.info("Analyzing threat trends for character #{character_id}")

    # For now, return placeholder trend data
    {:ok,
     %{
       character_id: character_id,
       trend_direction: :stable,
       trend_strength: 0.1,
       historical_scores: [],
       recent_changes: [],
       prediction: %{
         next_30_days: 5.0,
         confidence: 0.7
       }
     }}
  end

  # Private helper functions

  defp calculate_weighted_threat_score(dimensional_scores) do
    dimensional_scores.combat_skill.normalized_score * @combat_skill_weight +
      dimensional_scores.ship_mastery.normalized_score * @ship_mastery_weight +
      dimensional_scores.gang_effectiveness.normalized_score * @gang_effectiveness_weight +
      dimensional_scores.unpredictability.normalized_score * @unpredictability_weight +
      dimensional_scores.recent_activity.normalized_score * @recent_activity_weight
  end

  defp determine_threat_level(score) do
    cond do
      score >= @threat_levels.extreme -> :extreme
      score >= @threat_levels.very_high -> :very_high
      score >= @threat_levels.high -> :high
      score >= @threat_levels.moderate -> :moderate
      score >= @threat_levels.low -> :low
      true -> :minimal
    end
  end

  defp calculate_recent_activity_score(combat_data) do
    killmails = combat_data.killmails
    analysis_window_days = combat_data.analysis_period_days

    if Enum.empty?(killmails) do
      %{
        normalized_score: 0.0,
        recent_kills: 0,
        activity_trend: :inactive,
        last_activity: nil
      }
    else
      # Calculate activity metrics
      total_killmails = length(killmails)
      attacker_killmails = length(combat_data.attacker_killmails)
      victim_killmails = length(combat_data.victim_killmails)

      # Recent activity score based on killmail frequency
      kills_per_day = total_killmails / analysis_window_days

      # Normalize activity score (5 kills/day = max score)
      activity_score = min(10.0, kills_per_day * 2.0)

      # Determine activity trend based on temporal distribution
      activity_trend = analyze_activity_trend(killmails)

      # Get last activity timestamp
      last_activity =
        killmails
        |> Enum.max_by(& &1.killmail_time, DateTime)
        |> Map.get(:killmail_time)

      %{
        normalized_score: activity_score,
        recent_kills: attacker_killmails,
        recent_losses: victim_killmails,
        total_engagements: total_killmails,
        kills_per_day: Float.round(kills_per_day, 2),
        activity_trend: activity_trend,
        last_activity: last_activity
      }
    end
  end

  defp calculate_confidence(dimensional_scores) do
    # Calculate confidence based on data quality and consistency
    scores = [
      dimensional_scores.combat_skill.normalized_score,
      dimensional_scores.ship_mastery.normalized_score,
      dimensional_scores.gang_effectiveness.normalized_score,
      dimensional_scores.unpredictability.normalized_score,
      dimensional_scores.recent_activity.normalized_score
    ]

    # Simple confidence calculation - higher variance means lower confidence
    variance =
      Enum.reduce(scores, 0, fn score, acc -> acc + (score - 5.0) * (score - 5.0) end) /
        length(scores)

    max(0.1, 1.0 - variance / 25.0)
  end

  defp generate_insights(dimensional_scores, threat_level) do
    insights = ["Character shows #{threat_level} threat level"]

    # Add specific insights based on dimensional scores
    insights =
      if dimensional_scores.combat_skill.normalized_score > 7.0 do
        insights ++ ["High combat proficiency detected"]
      else
        insights ++ ["Moderate combat capabilities"]
      end

    # Add more detailed insights from each dimensional score
    insights = insights ++ dimensional_scores.combat_skill.insights
    insights = insights ++ dimensional_scores.ship_mastery.insights
    insights = insights ++ dimensional_scores.gang_effectiveness.insights
    insights = insights ++ dimensional_scores.unpredictability.insights

    # Activity insights
    insights =
      case dimensional_scores.recent_activity.activity_trend do
        :increasing -> insights ++ ["Increasing activity levels - becoming more active"]
        :decreasing -> insights ++ ["Decreasing activity levels - less engaged recently"]
        :stable -> insights ++ ["Stable activity pattern"]
        :inactive -> insights ++ ["Low recent activity"]
      end

    insights
  end

  defp fetch_character_combat_data(character_id, analysis_window_days) do
    cutoff_date =
      DateTime.add(DateTime.utc_now(), -analysis_window_days * 24 * 60 * 60, :second)

    # Fetch killmails where character was victim
    victim_query =
      KillmailRaw
      |> new()
      |> filter(victim_character_id: character_id)
      |> filter(killmail_time: [gte: cutoff_date])
      |> sort(killmail_time: :desc)
      |> limit(500)

    # Fetch killmails where character was attacker (need to search raw_data)
    # This is a simplified approach - would be more efficient with proper indexing
    attacker_query =
      KillmailRaw
      |> new()
      |> filter(killmail_time: [gte: cutoff_date])
      |> limit(1000)

    with {:ok, victim_killmails} <- Ash.read(victim_query, domain: Api),
         {:ok, potential_attacker_killmails} <- Ash.read(attacker_query, domain: Api) do
      # Filter attacker killmails for this character
      attacker_killmails =
        Enum.filter(potential_attacker_killmails, fn km ->
          case km.raw_data do
            %{"attackers" => attackers} when is_list(attackers) ->
              Enum.any?(attackers, &(&1["character_id"] == character_id))

            _ ->
              false
          end
        end)

      all_killmails = Enum.uniq_by(victim_killmails ++ attacker_killmails, & &1.killmail_id)

      if length(all_killmails) < @minimum_killmails_for_scoring do
        {:error, :insufficient_data}
      else
        combat_data = %{
          killmails: all_killmails,
          analysis_period_days: analysis_window_days,
          data_cutoff: cutoff_date,
          victim_killmails: victim_killmails,
          attacker_killmails: attacker_killmails
        }

        {:ok, combat_data}
      end
    else
      error ->
        Logger.error("Failed to fetch combat data: #{inspect(error)}")
        {:error, :database_error}
    end
  end

  defp analyze_activity_trend(killmails) do
    if length(killmails) < 5 do
      :stable
    else
      # Sort killmails by time
      sorted_killmails = Enum.sort_by(killmails, & &1.killmail_time, DateTime)

      # Split into early and recent periods
      split_point = div(length(sorted_killmails), 2)
      early_period = Enum.take(sorted_killmails, split_point)
      recent_period = Enum.drop(sorted_killmails, split_point)

      early_count = length(early_period)
      recent_count = length(recent_period)

      # Calculate trend based on activity change
      cond do
        recent_count > early_count * 1.3 -> :increasing
        recent_count < early_count * 0.7 -> :decreasing
        true -> :stable
      end
    end
  end
end
