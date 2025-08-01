defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.ThreatScoringCoordinator.Generators.ComparisonEngine do
  @moduledoc """
  Compares threat levels across multiple characters for relative assessment.

  This module enables bulk threat comparison and ranking for intelligence
  analysis and operational planning. Based on existing implementation from
  threat_scoring_engine.ex with real data analysis.
  """

  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.ThreatScoringCoordinator

  require Logger

  @doc """
  Compares threat levels between multiple characters.

  Returns comprehensive comparative analysis including:
  - Threat distribution across characters
  - Top threat rankings
  - Comparative insights and patterns
  - Character-by-character threat assessment
  """
  @spec compare_multiple_threats(list(integer()), keyword()) :: {:ok, map()} | {:error, term()}
  def compare_multiple_threats(character_ids, options \\ []) when is_list(character_ids) do
    Logger.info("Comparing threat levels for #{length(character_ids)} characters")

    with {:ok, threat_assessments} <- fetch_threat_assessments(character_ids, options),
         {:ok, comparison_analysis} <- generate_comparison_analysis(threat_assessments, options) do
      {:ok, comparison_analysis}
    else
      error ->
        Logger.warning(
          "Failed to compare threats for #{length(character_ids)} characters: #{inspect(error)}"
        )

        {:error, "Failed to compare threats: #{inspect(error)}"}
    end
  end

  # Fetch threat assessments for all characters
  defp fetch_threat_assessments(character_ids, options) do
    threat_assessments =
      character_ids
      |> Enum.map(fn character_id ->
        case ThreatScoringCoordinator.calculate_threat_score_uncached(character_id, options) do
          {:ok, assessment} ->
            {:ok, Map.put(assessment, :character_id, character_id)}

          {:error, reason} ->
            Logger.debug("Failed to assess character #{character_id}: #{inspect(reason)}")
            {:error, reason}
        end
      end)
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(&elem(&1, 1))

    if Enum.empty?(threat_assessments) do
      {:error, "No valid threat assessments could be generated"}
    else
      {:ok, threat_assessments}
    end
  rescue
    error ->
      Logger.error("Error during threat assessment collection: #{inspect(error)}")
      {:error, "Assessment collection failed"}
  end

  # Generate comprehensive comparison analysis
  defp generate_comparison_analysis(threat_assessments, options) do
    analysis = %{
      characters_analyzed: length(threat_assessments),
      threat_distribution: analyze_threat_distribution(threat_assessments),
      top_threats: identify_top_threats(threat_assessments),
      threat_rankings: rank_by_threat_level(threat_assessments),
      comparative_insights: generate_comparative_insights(threat_assessments),
      analysis_metadata: %{
        analysis_timestamp: DateTime.utc_now(),
        options_used: options,
        success_rate: calculate_success_rate(threat_assessments, options)
      }
    }

    {:ok, analysis}
  rescue
    error ->
      Logger.error("Error generating comparison analysis: #{inspect(error)}")
      {:error, "Analysis generation failed"}
  end

  # Analyze distribution of threat levels
  defp analyze_threat_distribution(threat_assessments) do
    threat_assessments
    |> Enum.group_by(fn assessment ->
      categorize_threat_level(Map.get(assessment, :threat_score, 0.0))
    end)
    |> Enum.map(fn {level, assessments} -> {level, length(assessments)} end)
    |> Map.new()
  end

  # Identify top threats by score
  defp identify_top_threats(threat_assessments) do
    threat_assessments
    |> Enum.sort_by(
      fn assessment ->
        Map.get(assessment, :threat_score, 0.0)
      end,
      :desc
    )
    |> Enum.take(5)
    |> Enum.map(fn assessment ->
      %{
        character_id: Map.get(assessment, :character_id),
        threat_level: categorize_threat_level(Map.get(assessment, :threat_score, 0.0)),
        threat_score: Map.get(assessment, :threat_score, 0.0),
        primary_strength: extract_primary_strength(assessment)
      }
    end)
  end

  # Rank all characters by threat level
  defp rank_by_threat_level(threat_assessments) do
    threat_assessments
    |> Enum.sort_by(
      fn assessment ->
        Map.get(assessment, :threat_score, 0.0)
      end,
      :desc
    )
    |> Enum.with_index(1)
    |> Enum.map(fn {assessment, rank} ->
      threat_score = Map.get(assessment, :threat_score, 0.0)

      %{
        rank: rank,
        character_id: Map.get(assessment, :character_id),
        threat_level: categorize_threat_level(threat_score),
        threat_score: threat_score
      }
    end)
  end

  # Generate comparative insights from the assessment data
  defp generate_comparative_insights(threat_assessments) do
    if length(threat_assessments) < 2 do
      ["Insufficient data for comparative analysis"]
    else
      scores =
        Enum.map(threat_assessments, fn assessment ->
          Map.get(assessment, :threat_score, 0.0)
        end)

      avg_score = calculate_average(scores)
      max_score = Enum.max(scores)
      min_score = Enum.min(scores)

      insights = []

      # Score distribution insights
      insights = add_distribution_insights(insights, max_score, min_score, avg_score)

      # Threat level insights
      insights = add_threat_level_insights(insights, threat_assessments)

      # Activity pattern insights
      insights = add_activity_pattern_insights(insights, threat_assessments)

      Enum.reverse(insights)
    end
  end

  # Helper functions

  defp categorize_threat_level(score) when score >= 0.8, do: :extreme
  defp categorize_threat_level(score) when score >= 0.6, do: :high
  defp categorize_threat_level(score) when score >= 0.4, do: :moderate
  defp categorize_threat_level(score) when score >= 0.2, do: :low
  defp categorize_threat_level(_), do: :minimal

  defp extract_primary_strength(assessment) do
    insights = Map.get(assessment, :insights, [])

    case insights do
      [first_insight | _] -> first_insight
      [] -> "No specific strengths identified"
    end
  end

  defp calculate_average([]), do: 0.0

  defp calculate_average(scores) do
    Enum.sum(scores) / length(scores)
  end

  defp calculate_success_rate(threat_assessments, options) do
    requested_count = length(Keyword.get(options, :character_ids, []))

    if requested_count > 0 do
      length(threat_assessments) / requested_count
    else
      1.0
    end
  end

  # Add distribution-based insights
  defp add_distribution_insights(insights, max_score, min_score, avg_score)
       when max_score - min_score > 0.5 do
    spread_insight =
      "Wide threat level variation - from #{Float.round(min_score, 1)} to #{Float.round(max_score, 1)}"

    avg_insight = "Average threat level: #{Float.round(avg_score, 1)}"
    [avg_insight, spread_insight | insights]
  end

  defp add_distribution_insights(insights, _max_score, _min_score, avg_score) do
    ["Consistent threat levels across group - average: #{Float.round(avg_score, 1)}" | insights]
  end

  # Add threat level distribution insights
  defp add_threat_level_insights(insights, threat_assessments) do
    high_threat_count =
      Enum.count(threat_assessments, fn assessment ->
        Map.get(assessment, :threat_score, 0.0) >= 0.6
      end)

    total_count = length(threat_assessments)

    high_threat_percentage =
      if total_count > 0, do: high_threat_count / total_count * 100, else: 0

    if high_threat_percentage > 50 do
      ["High-threat group: #{round(high_threat_percentage)}% above threat level 0.6" | insights]
    else
      insights
    end
  end

  # Add activity pattern insights
  defp add_activity_pattern_insights(insights, threat_assessments) do
    active_characters =
      Enum.count(threat_assessments, fn assessment ->
        insights_list = Map.get(assessment, :insights, [])

        Enum.any?(insights_list, fn insight ->
          String.contains?(insight, "active") or String.contains?(insight, "combatant")
        end)
      end)

    total_count = length(threat_assessments)
    activity_percentage = if total_count > 0, do: active_characters / total_count * 100, else: 0

    if activity_percentage > 70 do
      [
        "Highly active group: #{round(activity_percentage)}% showing active combat patterns"
        | insights
      ]
    else
      insights
    end
  end
end
