defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.ThreatScoringCoordinator.Analyzers.TrendAnalyzer do
  @moduledoc """
  Analyzes threat trends for characters over time.

  This module is responsible for:
  - Analyzing threat score trends over multiple time periods
  - Calculating trend direction and strength
  - Predicting future threat levels
  - Analyzing recent changes and patterns
  """

  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.ThreatScoringCoordinator.DataFetchers.CombatDataFetcher

  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.ThreatScoringCoordinator.Calculators.ThreatScoreCalculator

  require Logger

  @doc """
  Analyze threat trends for a character over multiple time periods.

  ## Parameters
  - character_id: Character to analyze
  - options: Analysis options

  ## Returns
  - {:ok, trend_analysis} - Complete trend analysis
  - {:error, reason} - Error details
  """
  def analyze_character_threat_trends(character_id, options \\ []) do
    Logger.debug("Analyzing threat trends for character #{character_id}")

    # Calculate threat scores for different time periods
    analysis_periods = [30, 60, 90]

    historical_scores =
      analysis_periods

    Enum.map(fn days ->
      calculate_period_threat_score(character_id, days, options)
    end)

    Enum.reject(&is_nil/1)

    if length(historical_scores) < 2 do
      {:error, :insufficient_data_for_trend_analysis}
    else
      # Analyze trend patterns
      trend_analysis = build_trend_analysis(character_id, historical_scores, analysis_periods)

      Logger.info("Completed trend analysis for character #{character_id}")
      {:ok, trend_analysis}
    end
  end

  # Private analysis functions

  defp calculate_period_threat_score(character_id, days, options) do
    period_options = Keyword.put(options, :analysis_window_days, days)

    case CombatDataFetcher.fetch_character_combat_data(character_id, period_options) do
      {:ok, combat_data} ->
        case ThreatScoreCalculator.calculate_comprehensive_score(combat_data, period_options) do
          {:ok, threat_assessment} ->
            %{
              period_days: days,
              threat_score: threat_assessment.threat_score,
              threat_level: threat_assessment.threat_level,
              total_killmails: threat_assessment.total_killmails,
              confidence: threat_assessment.confidence
            }

          {:error, _} ->
            nil
        end

      {:error, _} ->
        nil
    end
  end

  defp build_trend_analysis(character_id, historical_scores, analysis_periods) do
    scores = Enum.map(historical_scores, & &1.threat_score)
    {trend_direction, trend_strength} = calculate_trend_metrics(scores)

    # Analyze recent changes
    recent_changes = analyze_recent_changes(historical_scores)

    # Generate predictions
    latest_score = List.first(scores)
    predicted_score = latest_score + trend_strength * 0.5
    prediction_confidence = calculate_trend_confidence(historical_scores)

    %{
      character_id: character_id,
      trend_direction: trend_direction,
      trend_strength: Float.round(trend_strength, 3),
      historical_scores: historical_scores,
      recent_changes: recent_changes,
      prediction: %{
        next_30_days: Float.round(max(0.0, min(10.0, predicted_score)), 2),
        confidence: Float.round(prediction_confidence, 2)
      },
      analysis_periods: analysis_periods,
      analyzed_at: DateTime.utc_now()
    }
  end

  defp calculate_trend_metrics(scores) when length(scores) >= 2 do
    # Calculate linear trend between most recent and oldest scores
    first_score = List.first(scores)
    last_score = List.last(scores)

    trend_strength = first_score - last_score

    trend_direction =
      cond do
        trend_strength > 0.5 -> :increasing
        trend_strength < -0.5 -> :decreasing
        true -> :stable
      end

    {trend_direction, trend_strength}
  end

  defp analyze_recent_changes(historical_scores) do
    if length(historical_scores) >= 2 do
      recent_30_day = Enum.find(historical_scores, &(&1.period_days == 30))
      recent_60_day = Enum.find(historical_scores, &(&1.period_days == 60))

      if recent_30_day && recent_60_day do
        score_change = recent_30_day.threat_score - recent_60_day.threat_score

        level_change =
          if recent_30_day.threat_level != recent_60_day.threat_level do
            "#{recent_60_day.threat_level} -> #{recent_30_day.threat_level}"
          else
            "stable at #{recent_30_day.threat_level}"
          end

        [
          %{
            change_type: :threat_score,
            value: Float.round(score_change, 2),
            description: if(score_change > 0, do: "threat increasing", else: "threat decreasing")
          },
          %{
            change_type: :threat_level,
            value: level_change,
            description: "threat level change"
          }
        ]
      else
        []
      end
    else
      []
    end
  end

  defp calculate_trend_confidence(historical_scores) do
    # Confidence based on data volume and consistency
    total_killmails = Enum.sum(Enum.map(historical_scores, & &1.total_killmails))

    avg_confidence =
      Enum.sum(Enum.map(historical_scores, & &1.confidence)) / length(historical_scores)

    # More killmails and higher individual confidence = higher trend confidence
    # 50+ killmails = max confidence
    killmail_factor = min(1.0, total_killmails / 50.0)

    avg_confidence * killmail_factor
  end
end
