defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.ThreatScoringCoordinator.Calculators.ThreatScoreCalculator do
  @moduledoc """
  Handles threat score calculations and weighting algorithms.

  This module is responsible for:
  - Calculating dimensional threat scores using existing engines
  - Applying weighted scoring algorithms
  - Determining threat levels and confidence scores
  - Processing recent activity metrics
  """

  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.Engines.CombatThreatEngine
  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.Engines.ShipMasteryEngine
  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.Engines.GangEffectivenessEngine
  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.Engines.UnpredictabilityEngine

  require Logger

  # Threat scoring weights optimized for EVE PvP
  @combat_skill_weight 0.30
  @ship_mastery_weight 0.25
  @gang_effectiveness_weight 0.25
  @unpredictability_weight 0.10
  @recent_activity_weight 0.10

  # Threat level thresholds
  @threat_levels %{
    extreme: 9.0,
    very_high: 7.5,
    high: 6.0,
    moderate: 4.0,
    low: 2.0,
    minimal: 0.0
  }

  @doc """
  Calculate comprehensive threat score from combat data.

  ## Parameters
  - combat_data: Structured combat data from CombatDataFetcher
  - options: Calculation options

  ## Returns
  - {:ok, threat_assessment} - Complete threat assessment
  - {:error, reason} - Error details
  """
  def calculate_comprehensive_score(combat_data, _options) do
    Logger.debug(
      "Calculating comprehensive threat score for character #{combat_data.character_id}"
    )

    # Calculate dimensional scores using existing engines
    dimensional_scores = calculate_dimensional_scores(combat_data)

    # Calculate weighted threat score
    weighted_score = calculate_weighted_threat_score(dimensional_scores)
    threat_level = determine_threat_level(weighted_score)

    # Build comprehensive assessment
    threat_assessment = %{
      character_id: combat_data.character_id,
      threat_score: weighted_score,
      threat_level: threat_level,
      confidence: calculate_confidence(dimensional_scores),
      analysis_window_days: combat_data.analysis_period_days,
      total_killmails: combat_data.total_killmails,
      dimensional_scores: dimensional_scores,
      analyzed_at: DateTime.utc_now()
    }

    Logger.info(
      "Calculated threat score #{weighted_score} (#{threat_level}) for character #{combat_data.character_id}"
    )

    {:ok, threat_assessment}
  rescue
    error ->
      Logger.error("Exception during threat score calculation: #{inspect(error)}")
      {:error, :calculation_error}
  end

  # Private calculation functions

  defp calculate_dimensional_scores(combat_data) do
    %{
      combat_skill: CombatThreatEngine.calculate_combat_skill_score(combat_data),
      ship_mastery: ShipMasteryEngine.calculate_ship_mastery_score(combat_data),
      gang_effectiveness: GangEffectivenessEngine.calculate_gang_effectiveness_score(combat_data),
      unpredictability: UnpredictabilityEngine.calculate_unpredictability_score(combat_data),
      recent_activity: calculate_recent_activity_score(combat_data)
    }
  end

  defp calculate_weighted_threat_score(dimensional_scores) do
    weighted_score =
      dimensional_scores.combat_skill.normalized_score * @combat_skill_weight +
        dimensional_scores.ship_mastery.normalized_score * @ship_mastery_weight +
        dimensional_scores.gang_effectiveness.normalized_score * @gang_effectiveness_weight +
        dimensional_scores.unpredictability.normalized_score * @unpredictability_weight +
        dimensional_scores.recent_activity.normalized_score * @recent_activity_weight

    Float.round(weighted_score, 2)
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
      # 5 kills/day = max score
      activity_score = min(10.0, kills_per_day * 2.0)

      # Determine activity trend
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

  defp analyze_activity_trend(killmails) do
    if length(killmails) < 5 do
      :stable
    else
      # Sort killmails by time and analyze trend
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

  defp calculate_confidence(dimensional_scores) do
    # Calculate confidence based on data quality and consistency
    scores = [
      dimensional_scores.combat_skill.normalized_score,
      dimensional_scores.ship_mastery.normalized_score,
      dimensional_scores.gang_effectiveness.normalized_score,
      dimensional_scores.unpredictability.normalized_score,
      dimensional_scores.recent_activity.normalized_score
    ]

    # Lower variance = higher confidence
    mean_score = Enum.sum(scores) / length(scores)

    variance =
      Enum.reduce(scores, 0, fn score, acc ->
        acc + (score - mean_score) * (score - mean_score)
      end) / length(scores)

    confidence = max(0.1, 1.0 - variance / 25.0)
    Float.round(confidence, 2)
  end
end
