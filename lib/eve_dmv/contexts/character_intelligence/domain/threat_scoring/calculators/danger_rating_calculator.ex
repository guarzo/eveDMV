defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.Calculators.DangerRatingCalculator do
  @moduledoc """
  Calculator for determining danger ratings based on threat scores.

  Converts raw threat scores into actionable danger ratings and risk assessments.
  """

  require Logger

  @danger_thresholds %{
    extreme: 9.0,
    very_high: 7.5,
    high: 6.0,
    moderate: 4.0,
    low: 2.0,
    minimal: 0.0
  }

  @doc """
  Calculate danger rating from threat score.
  """
  def calculate_danger_rating(threat_score, context \\ %{}) do
    Logger.debug("Calculating danger rating for threat score: #{threat_score}")

    danger_level = determine_danger_level(threat_score)
    risk_factors = identify_risk_factors(threat_score, context)

    %{
      danger_level: danger_level,
      numeric_rating: threat_score,
      risk_factors: risk_factors,
      confidence: calculate_confidence(threat_score, context),
      recommendations: generate_recommendations(danger_level, risk_factors)
    }
  end

  @doc """
  Calculate comparative danger ratings for multiple characters.
  """
  def compare_danger_ratings(threat_scores) when is_list(threat_scores) do
    Logger.debug("Comparing danger ratings for #{length(threat_scores)} characters")

    ratings =
      Enum.map(threat_scores, fn {character_id, score} ->
        {character_id, calculate_danger_rating(score)}
      end)

    %{
      ratings: ratings,
      highest_danger: find_highest_danger(ratings),
      average_danger: calculate_average_danger(threat_scores),
      distribution: calculate_danger_distribution(ratings)
    }
  end

  # Private helper functions
  defp determine_danger_level(score) when score >= @danger_thresholds.extreme, do: :extreme
  defp determine_danger_level(score) when score >= @danger_thresholds.very_high, do: :very_high
  defp determine_danger_level(score) when score >= @danger_thresholds.high, do: :high
  defp determine_danger_level(score) when score >= @danger_thresholds.moderate, do: :moderate
  defp determine_danger_level(score) when score >= @danger_thresholds.low, do: :low
  defp determine_danger_level(_), do: :minimal

  defp identify_risk_factors(threat_score, context) do
    risk_factors = []

    risk_factors =
      if threat_score > 8.0, do: ["extremely_dangerous" | risk_factors], else: risk_factors

    risk_factors =
      if threat_score > 6.0, do: ["high_combat_skill" | risk_factors], else: risk_factors

    risk_factors =
      if Map.get(context, :recent_activity, false),
        do: ["currently_active" | risk_factors],
        else: risk_factors

    risk_factors
  end

  defp calculate_confidence(_threat_score, context) do
    # Base confidence on data quality and recency
    base_confidence = 0.7

    # Adjust based on context
    data_quality = Map.get(context, :data_quality, 0.8)
    recency_factor = Map.get(context, :recency_factor, 1.0)

    base_confidence * data_quality * recency_factor
  end

  defp generate_recommendations(danger_level, risk_factors) do
    recommendations = []

    recommendations =
      case danger_level do
        :extreme -> ["Avoid engagement", "Extreme caution advised" | recommendations]
        :very_high -> ["Engage with overwhelming force", "High risk target" | recommendations]
        :high -> ["Engage with caution", "Prepare for skilled opponent" | recommendations]
        :moderate -> ["Standard engagement protocols", "Moderate threat level" | recommendations]
        :low -> ["Low risk engagement", "Suitable for training" | recommendations]
        :minimal -> ["Minimal threat", "Low priority target" | recommendations]
      end

    # Add specific recommendations based on risk factors
    recommendations =
      if "extremely_dangerous" in risk_factors,
        do: ["Consider fleet engagement only" | recommendations],
        else: recommendations

    recommendations =
      if "currently_active" in risk_factors,
        do: ["Monitor recent activity" | recommendations],
        else: recommendations

    recommendations
  end

  defp find_highest_danger(ratings) do
    Enum.max_by(ratings, fn {_character_id, rating} -> rating.numeric_rating end)
  end

  defp calculate_average_danger(threat_scores) do
    scores = Enum.map(threat_scores, fn {_character_id, score} -> score end)
    Enum.sum(scores) / length(scores)
  end

  defp calculate_danger_distribution(ratings) do
    Enum.reduce(
      ratings,
      %{extreme: 0, very_high: 0, high: 0, moderate: 0, low: 0, minimal: 0},
      fn {_character_id, rating}, acc ->
        Map.update!(acc, rating.danger_level, &(&1 + 1))
      end
    )
  end
end
