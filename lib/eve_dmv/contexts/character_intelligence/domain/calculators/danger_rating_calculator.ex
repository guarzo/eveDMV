defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.Calculators.DangerRatingCalculator do
  @moduledoc """
  Calculator for determining danger ratings based on threat scores.

  Converts raw threat scores into actionable danger ratings and risk assessments.
  """
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
    []
    |> maybe_add_risk_factor("extremely_dangerous", threat_score > 8.0)
    |> maybe_add_risk_factor("high_combat_skill", threat_score > 6.0)
    |> maybe_add_risk_factor("currently_active", Map.get(context, :recent_activity, false))
  end

  defp maybe_add_risk_factor(factors, _factor, false), do: factors
  defp maybe_add_risk_factor(factors, factor, true), do: [factor | factors]

  defp calculate_confidence(_threat_score, context) do
    # Base confidence on data quality and recency
    base_confidence = 0.7

    # Adjust based on context
    data_quality = Map.get(context, :data_quality, 0.8)
    recency_factor = Map.get(context, :recency_factor, 1.0)

    base_confidence * data_quality * recency_factor
  end

  defp generate_recommendations(danger_level, risk_factors) do
    base_recommendations =
      case danger_level do
        :extreme -> ["Avoid engagement", "Extreme caution advised"]
        :very_high -> ["Engage with overwhelming force", "High risk target"]
        :high -> ["Engage with caution", "Prepare for skilled opponent"]
        :moderate -> ["Standard engagement protocols", "Moderate threat level"]
        :low -> ["Low risk engagement", "Suitable for training"]
        :minimal -> ["Minimal threat", "Low priority target"]
      end

    # Add specific recommendations based on risk factors
    base_recommendations
    |> maybe_add_recommendation(
      "Consider fleet engagement only",
      "extremely_dangerous" in risk_factors
    )
    |> maybe_add_recommendation("Monitor recent activity", "currently_active" in risk_factors)
  end

  defp maybe_add_recommendation(recommendations, _recommendation, false), do: recommendations

  defp maybe_add_recommendation(recommendations, recommendation, true),
    do: [recommendation | recommendations]

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
