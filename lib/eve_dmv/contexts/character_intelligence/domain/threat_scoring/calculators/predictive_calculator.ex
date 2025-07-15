defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.Calculators.PredictiveCalculator do
  @moduledoc """
  Calculator for predictive threat modeling and trend analysis.

  Analyzes historical threat data to predict future threat levels and identify trends.
  """

  require Logger

  @doc """
  Calculate predictive threat score based on historical data.
  """
  def calculate_predictive_threat(historical_scores, options \\ []) do
    Logger.debug(
      "Calculating predictive threat for #{length(historical_scores)} historical scores"
    )

    prediction_window = Keyword.get(options, :prediction_window, 30)
    _confidence_threshold = Keyword.get(options, :confidence_threshold, 0.7)

    trend = analyze_trend(historical_scores)
    prediction = predict_future_score(historical_scores, prediction_window)

    %{
      predicted_score: prediction.score,
      confidence: prediction.confidence,
      trend: trend,
      prediction_window_days: prediction_window,
      risk_indicators: identify_risk_indicators(historical_scores, trend),
      recommendations: generate_predictive_recommendations(trend, prediction)
    }
  end

  @doc """
  Analyze threat trend patterns.
  """
  def analyze_threat_trends(historical_scores) do
    Logger.debug("Analyzing threat trends for #{length(historical_scores)} data points")

    if length(historical_scores) < 2 do
      %{
        trend_direction: :insufficient_data,
        trend_strength: 0.0,
        volatility: 0.0,
        stability: 0.0
      }
    else
      trend_direction = calculate_trend_direction(historical_scores)
      trend_strength = calculate_trend_strength(historical_scores)
      volatility = calculate_volatility(historical_scores)

      %{
        trend_direction: trend_direction,
        trend_strength: trend_strength,
        volatility: volatility,
        stability: 1.0 - volatility
      }
    end
  end

  @doc """
  Calculate threat score momentum.
  """
  def calculate_momentum(historical_scores, window_size \\ 7) do
    Logger.debug(
      "Calculating momentum for #{length(historical_scores)} scores with window size #{window_size}"
    )

    if length(historical_scores) < window_size do
      %{momentum: 0.0, momentum_strength: :weak}
    else
      recent_scores = Enum.take(historical_scores, window_size)
      older_scores = Enum.drop(historical_scores, window_size) |> Enum.take(window_size)

      recent_avg = calculate_average(recent_scores)
      older_avg = calculate_average(older_scores)

      momentum = recent_avg - older_avg
      momentum_strength = classify_momentum_strength(momentum)

      %{
        momentum: momentum,
        momentum_strength: momentum_strength,
        recent_average: recent_avg,
        baseline_average: older_avg
      }
    end
  end

  # Private helper functions
  defp analyze_trend(historical_scores) when length(historical_scores) < 2 do
    %{direction: :insufficient_data, strength: 0.0}
  end

  defp analyze_trend(historical_scores) do
    # Simple linear trend analysis
    scores = Enum.map(historical_scores, fn {_date, score} -> score end)

    first_half = Enum.take(scores, div(length(scores), 2))
    second_half = Enum.drop(scores, div(length(scores), 2))

    first_avg = calculate_average(first_half)
    second_avg = calculate_average(second_half)

    direction =
      cond do
        second_avg > first_avg + 0.5 -> :increasing
        second_avg < first_avg - 0.5 -> :decreasing
        true -> :stable
      end

    strength = abs(second_avg - first_avg) / 10.0

    %{direction: direction, strength: strength}
  end

  defp predict_future_score(historical_scores, _prediction_window) do
    # Simple prediction based on recent trend
    recent_scores = Enum.take(historical_scores, 10)
    current_avg = calculate_average(Enum.map(recent_scores, fn {_date, score} -> score end))

    # For now, predict stability with slight variation
    predicted_score = current_avg + :rand.uniform() * 0.5 - 0.25
    predicted_score = max(0.0, min(10.0, predicted_score))

    %{
      score: predicted_score,
      confidence: 0.7
    }
  end

  defp identify_risk_indicators(historical_scores, trend) do
    risk_indicators = []

    risk_indicators =
      if trend.direction == :increasing and trend.strength > 0.3,
        do: ["rapid_improvement" | risk_indicators],
        else: risk_indicators

    risk_indicators =
      if trend.direction == :decreasing and trend.strength > 0.3,
        do: ["declining_performance" | risk_indicators],
        else: risk_indicators

    volatility = calculate_volatility(historical_scores)

    risk_indicators =
      if volatility > 0.7, do: ["high_volatility" | risk_indicators], else: risk_indicators

    risk_indicators
  end

  defp generate_predictive_recommendations(trend, prediction) do
    recommendations = []

    recommendations =
      case trend.direction do
        :increasing ->
          [
            "Monitor for continued improvement",
            "Consider threat level escalation" | recommendations
          ]

        :decreasing ->
          ["Potential threat reduction", "Monitor for performance recovery" | recommendations]

        :stable ->
          ["Stable threat level", "Standard monitoring protocols" | recommendations]

        _ ->
          ["Insufficient data for prediction" | recommendations]
      end

    recommendations =
      if prediction.confidence < 0.5,
        do: ["Low confidence prediction", "Increase monitoring frequency" | recommendations],
        else: recommendations

    recommendations
  end

  defp calculate_trend_direction(historical_scores) do
    scores = Enum.map(historical_scores, fn {_date, score} -> score end)
    first_score = List.first(scores)
    last_score = List.last(scores)

    cond do
      last_score > first_score + 0.5 -> :increasing
      last_score < first_score - 0.5 -> :decreasing
      true -> :stable
    end
  end

  defp calculate_trend_strength(historical_scores) do
    scores = Enum.map(historical_scores, fn {_date, score} -> score end)

    if length(scores) < 2 do
      0.0
    else
      first_score = List.first(scores)
      last_score = List.last(scores)
      abs(last_score - first_score) / 10.0
    end
  end

  defp calculate_volatility(historical_scores) do
    scores = Enum.map(historical_scores, fn {_date, score} -> score end)

    if length(scores) < 2 do
      0.0
    else
      avg = calculate_average(scores)

      variance =
        Enum.reduce(scores, 0.0, fn score, acc -> acc + :math.pow(score - avg, 2) end) /
          length(scores)

      :math.sqrt(variance) / 10.0
    end
  end

  defp calculate_average(scores) when length(scores) > 0 do
    Enum.sum(scores) / length(scores)
  end

  defp calculate_average(_), do: 0.0

  defp classify_momentum_strength(momentum) do
    cond do
      abs(momentum) > 1.0 -> :strong
      abs(momentum) > 0.5 -> :moderate
      abs(momentum) > 0.1 -> :weak
      true -> :minimal
    end
  end
end
