defmodule EveDmv.Contexts.CorporationIntelligence.Domain.HealthAssessor do
  @moduledoc """
  Corporation health assessment service.

  Evaluates overall corporation health based on multiple factors including
  member coordination, ISK efficiency, growth trajectory, and operational patterns.
  Provides health scores, ratings, and actionable recommendations.
  """

  @doc """
  Calculates an overall health score (0-100) for a corporation.

  Weights:
  - Member count: 15%
  - Coordination score: 25%
  - ISK efficiency: 25%
  - Growth score: 20%
  - Consistency score: 15%

  ## Parameters
  - `base` - Base corporation analysis data
  - `performance` - Performance metrics data
  - `patterns` - Operational patterns data (currently unused but reserved for future)

  ## Returns
  Float between 0.0 and 100.0
  """
  @spec calculate_health_score(map(), map(), map()) :: float()
  def calculate_health_score(base, performance, _patterns) do
    member_score = min(base[:member_count] || 0, 100)
    coordination_score = base[:coordination_analysis][:coordination_score] || 0
    efficiency_score = performance[:efficiency_metrics][:isk_efficiency] || 0
    growth_score = growth_trajectory_to_score(performance[:growth_indicators][:growth_trajectory])
    consistency_score = performance[:performance_trends][:consistency_score] || 0

    total =
      member_score * 0.15 +
        coordination_score * 0.25 +
        efficiency_score * 0.25 +
        growth_score * 0.20 +
        consistency_score * 0.15

    Float.round(total, 1)
  end

  @doc """
  Categorizes a health score into a rating.

  ## Ratings
  - `:excellent` - Score >= 80
  - `:good` - Score >= 60
  - `:fair` - Score >= 40
  - `:poor` - Score >= 20
  - `:critical` - Score < 20
  """
  @spec categorize_health_score(number()) :: atom()
  def categorize_health_score(score) do
    cond do
      score >= 80 -> :excellent
      score >= 60 -> :good
      score >= 40 -> :fair
      score >= 20 -> :poor
      true -> :critical
    end
  end

  @doc """
  Identifies corporation strengths based on analysis data.

  ## Returns
  List of strength descriptions, or ["Established presence"] if none identified.
  """
  @spec identify_strengths(map(), map(), map()) :: [String.t()]
  def identify_strengths(base, performance, patterns) do
    []
    |> add_if(
      base[:coordination_analysis][:coordination_score] > 70,
      "Excellent member coordination"
    )
    |> add_if(performance[:efficiency_metrics][:isk_efficiency] > 60, "High ISK efficiency")
    |> add_growth_strength(performance[:growth_indicators][:growth_trajectory])
    |> add_if(
      patterns[:geographic_patterns][:operational_range][:classification] in [
        :nomadic,
        :wide_range
      ],
      "Wide operational range"
    )
    |> finalize_list("Established presence")
  end

  @doc """
  Identifies corporation weaknesses based on analysis data.

  ## Returns
  List of weakness descriptions, or ["No significant weaknesses identified"] if none found.
  """
  @spec identify_weaknesses(map(), map(), map()) :: [String.t()]
  def identify_weaknesses(base, performance, patterns) do
    []
    |> add_if(base[:member_count] < 10, "Low member count")
    |> add_if(performance[:efficiency_metrics][:isk_efficiency] < 40, "Poor ISK efficiency")
    |> add_if(
      performance[:performance_trends][:consistency_score] < 30,
      "Inconsistent performance"
    )
    |> add_if(
      patterns[:temporal_patterns][:operational_tempo] in [:sporadic, :minimal],
      "Low operational tempo"
    )
    |> finalize_list("No significant weaknesses identified")
  end

  @doc """
  Generates actionable recommendations based on analysis data.

  ## Returns
  List of recommendations, or ["Maintain current operational excellence"] if no improvements needed.
  """
  @spec generate_recommendations(map(), map(), map()) :: [String.t()]
  def generate_recommendations(base, performance, patterns) do
    []
    |> add_if(base[:member_count] < 20, "Focus on recruitment to increase member base")
    |> add_if(
      performance[:efficiency_metrics][:kill_death_ratio] < 1.0,
      "Improve combat tactics and target selection"
    )
    |> add_timezone_recommendation(base[:activity_patterns][:primary_timezones][:coverage])
    |> add_if(
      patterns[:geographic_patterns][:operational_range][:classification] in [:static, :local],
      "Expand operational range to new systems"
    )
    |> finalize_list("Maintain current operational excellence")
  end

  @doc """
  Identifies potential risk factors for the corporation.

  ## Returns
  List of risk factors, or ["No significant risks identified"] if none found.
  """
  @spec identify_risk_factors(map(), map(), map()) :: [String.t()]
  def identify_risk_factors(base, performance, patterns) do
    []
    |> add_growth_risk(performance[:growth_indicators][:growth_trajectory])
    |> add_if(
      performance[:growth_indicators][:member_retention_rate] < 50,
      "Low member retention rate"
    )
    |> add_concentration_risk(patterns[:geographic_patterns][:home_systems])
    |> add_if(base[:coordination_analysis][:coordination_score] < 30, "Poor member coordination")
    |> finalize_list("No significant risks identified")
  end

  # Private helpers

  defp growth_trajectory_to_score(trajectory) do
    case trajectory do
      :rapid_growth -> 100
      :steady_growth -> 80
      :slow_growth -> 60
      :stable -> 50
      :declining -> 30
      :rapid_decline -> 10
      _ -> 40
    end
  end

  defp add_if(list, condition, item) do
    if condition, do: [item | list], else: list
  end

  defp add_growth_strength(list, trajectory) when trajectory in [:rapid_growth, :steady_growth] do
    ["Positive growth trajectory" | list]
  end

  defp add_growth_strength(list, _), do: list

  defp add_timezone_recommendation(list, coverage) when coverage in [nil, ""], do: list

  defp add_timezone_recommendation(list, coverage) do
    if String.contains?(coverage, ["Limited", "Minimal"]) do
      ["Expand timezone coverage for better operational flexibility" | list]
    else
      list
    end
  end

  defp add_growth_risk(list, trajectory) when trajectory in [:declining, :rapid_decline] do
    ["Declining activity levels" | list]
  end

  defp add_growth_risk(list, _), do: list

  defp add_concentration_risk(list, nil), do: list
  defp add_concentration_risk(list, []), do: list

  defp add_concentration_risk(list, [first | _]) do
    if first[:percentage] > 50 do
      ["Over-concentrated in few systems" | list]
    else
      list
    end
  end

  defp finalize_list([], default), do: [default]
  defp finalize_list(list, _default), do: Enum.reverse(list)
end
