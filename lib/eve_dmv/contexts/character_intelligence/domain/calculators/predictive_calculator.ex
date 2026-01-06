defmodule EveDmv.Contexts.CharacterIntelligence.Domain.Calculators.PredictiveCalculator do
  @moduledoc """
  Calculator for predictive threat modeling and trend analysis.

  Analyzes historical threat data to predict future threat levels and identify trends.
  """

  alias EveDmv.Types

  require Logger

  @doc """
  Predict threat evolution over a specified time period.
  """
  @spec predict_threat_evolution([Types.historical_score()], keyword()) ::
          Types.result(Types.threat_evolution())
  def predict_threat_evolution(historical_scores, opts \\ [])

  def predict_threat_evolution([], _opts) do
    {:error, :insufficient_data}
  end

  def predict_threat_evolution([_], _opts) do
    {:error, :insufficient_data}
  end

  def predict_threat_evolution([_, _], _opts) do
    {:error, :insufficient_data}
  end

  def predict_threat_evolution(historical_scores, opts) when length(historical_scores) >= 3 do
    days = Keyword.get(opts, :days, 30)

    Logger.debug(
      "Predicting threat evolution for #{length(historical_scores)} historical scores over #{days} days"
    )

    trend = analyze_trend(historical_scores)
    prediction = predict_future_score(historical_scores, days)
    risk_indicators = identify_risk_indicators(historical_scores, trend)

    {:ok,
     %{
       predicted_score: prediction.score,
       confidence: prediction.confidence,
       trend: trend,
       prediction_window_days: days,
       risk_indicators: risk_indicators,
       recommendations: generate_predictive_recommendations(trend, prediction)
     }}
  end

  @doc """
  Calculate predictive threat score based on historical data.
  """
  @spec calculate_predictive_threat([Types.historical_score()], keyword()) ::
          Types.threat_evolution()
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
  @spec analyze_threat_trends([Types.historical_score()]) :: map()
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
  @spec calculate_momentum([Types.historical_score()], pos_integer()) ::
          Types.result(Types.momentum_analysis())
  def calculate_momentum(historical_scores, window_size \\ 7)

  def calculate_momentum(historical_scores, _window_size) when length(historical_scores) < 2 do
    {:error, :insufficient_data}
  end

  def calculate_momentum(historical_scores, window_size) do
    Logger.debug(
      "Calculating momentum for #{length(historical_scores)} scores with window size #{window_size}"
    )

    scores = Enum.map(historical_scores, fn {_date, score} -> score end)

    # For momentum calculation, we need at least 2*window_size scores to compare
    # If we don't have enough, use smaller windows
    adjusted_window = min(window_size, div(length(scores), 2))
    # At least 1
    final_window = max(1, adjusted_window)

    # Recent values are the LAST N scores (chronologically most recent)
    recent_values = Enum.take(scores, -final_window)
    # Older values come before recent values
    older_values =
      scores
      # Remove recent values
      |> Enum.drop(-final_window)
      # Take the N values before that
      |> Enum.take(-final_window)

    recent_avg = calculate_average(recent_values)

    older_avg =
      if Enum.empty?(older_values) do
        # If no older data, compare to overall average excluding recent
        all_but_recent = Enum.drop(scores, -final_window)

        if Enum.empty?(all_but_recent) do
          # No comparison possible
          recent_avg
        else
          calculate_average(all_but_recent)
        end
      else
        calculate_average(older_values)
      end

    momentum = recent_avg - older_avg
    momentum_strength = classify_momentum_strength(momentum)

    {:ok,
     %{
       momentum: momentum,
       momentum_strength: momentum_strength,
       recent_average: recent_avg,
       baseline_average: older_avg
     }}
  end

  @doc """
  Generate recommendations based on threat analysis.
  """
  @spec generate_recommendations([Types.historical_score()], Types.prediction()) :: [String.t()]
  def generate_recommendations(historical_scores, prediction) do
    trend = analyze_trend(historical_scores)
    generate_predictive_recommendations(trend, prediction)
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
    scores = Enum.map(historical_scores, fn {_date, score} -> score end)

    # Simple linear trend extrapolation
    current_score = List.last(scores)

    if length(scores) >= 2 do
      # Calculate average rate of change
      first_score = List.first(scores)
      rate_of_change = (current_score - first_score) / (length(scores) - 1)

      # Project forward by the rate of change
      raw_predicted_score = current_score + rate_of_change
      predicted_score = max(0.0, min(10.0, raw_predicted_score))

      # Confidence based on trend consistency
      variance = calculate_variance(scores)
      # Lower variance = higher confidence
      confidence = max(0.3, min(0.9, 1.0 - variance / 10.0))

      %{
        score: Float.round(predicted_score, 2),
        confidence: Float.round(confidence, 2)
      }
    else
      %{
        score: Float.round(current_score, 2),
        confidence: 0.5
      }
    end
  end

  defp calculate_variance(scores) when length(scores) > 1 do
    avg = calculate_average(scores)

    sum_sq_diff =
      Enum.reduce(scores, 0.0, fn val, acc ->
        acc + :math.pow(val - avg, 2)
      end)

    sum_sq_diff / length(scores)
  end

  defp calculate_variance(_scores), do: 1.0

  defp identify_risk_indicators(historical_scores, trend) do
    rapid_improvement_indicators =
      if trend.direction == :increasing and trend.strength > 0.3,
        do: ["rapid_improvement"],
        else: []

    declining_performance_indicators =
      if trend.direction == :decreasing and trend.strength > 0.3,
        do: ["declining_performance"],
        else: []

    # Check for sustained decline (6+ consecutive decreasing scores)
    sustained_decline_indicators =
      if check_sustained_decline(historical_scores),
        do: ["sustained_decline"],
        else: []

    volatility = calculate_volatility(historical_scores)

    volatility_indicators =
      if volatility > 0.5, do: ["high_volatility"], else: []

    rapid_improvement_indicators ++
      declining_performance_indicators ++
      sustained_decline_indicators ++ volatility_indicators
  end

  defp generate_predictive_recommendations(trend, prediction) do
    trend_recommendations =
      case trend.direction do
        :increasing ->
          [
            "Monitor for continued improvement",
            "Consider threat level escalation"
          ]

        :decreasing ->
          ["Potential threat reduction", "Monitor for performance recovery"]

        :stable ->
          ["Stable threat level", "Standard monitoring protocols"]

        _ ->
          ["Insufficient data for prediction"]
      end

    confidence_recommendations =
      if prediction.confidence < 0.5,
        do: ["Low confidence prediction", "Increase monitoring frequency"],
        else: []

    trend_recommendations ++ confidence_recommendations
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

      # Return the standard deviation as a proportion
      # Higher values (more spread) = higher volatility
      standard_deviation = :math.sqrt(variance)

      # Normalize to 0-1 scale where 1.0+ is very high volatility
      standard_deviation / 3.0
    end
  end

  defp calculate_average(scores) when scores != [] do
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

  defp check_sustained_decline(historical_scores) when length(historical_scores) < 6 do
    false
  end

  defp check_sustained_decline(historical_scores) do
    scores = Enum.map(historical_scores, fn {_date, score} -> score end)

    # Take the last 6 scores
    last_six = Enum.take(scores, 6)

    # Check if each score is less than the previous
    last_six
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [current, next] -> next < current end)
  end
end
