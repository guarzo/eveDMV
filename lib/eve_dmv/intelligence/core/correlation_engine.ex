defmodule EveDmv.Intelligence.Core.CorrelationEngine do
  @moduledoc """
  Refactored cross-module intelligence correlation engine.

  This simplified version delegates complex analysis to specialized modules
  and focuses on coordination and high-level correlation logic.
  """

  require Logger

  alias EveDmv.Api

  alias EveDmv.Intelligence.Analyzers.{
    CharacterAnalyzer,
    CorporationAnalyzer,
    DoctrineAnalyzer,
    StatisticalAnalyzer,
    MemberActivityAnalyzer
  }

  alias EveDmv.Intelligence.Wormhole.Vetting, as: WHVetting
  alias EveDmv.Utils.Cache

  @doc """
  Perform comprehensive cross-module correlation analysis for a character.

  This refactored version is much simpler and delegates to specialized analyzers.
  """
  @spec analyze_cross_module_correlations(integer()) :: {:ok, map()} | {:error, String.t()}
  def analyze_cross_module_correlations(character_id) do
    Logger.info("Starting cross-module correlation analysis for character #{character_id}")

    with {:ok, character_analysis} <- get_character_analysis(character_id),
         {:ok, vetting_data} <- get_vetting_data(character_id),
         {:ok, activity_data} <- get_activity_data(character_id),
         {:ok, fleet_data} <- get_fleet_data(character_id) do
      # Perform simplified correlation analysis
      correlations = %{
        threat_assessment: correlate_threat_indicators(character_analysis, vetting_data),
        competency_correlation:
          correlate_competency_metrics(character_analysis, fleet_data, activity_data),
        behavioral_patterns: correlate_behavioral_patterns(vetting_data, activity_data),
        doctrine_analysis:
          DoctrineAnalyzer.analyze_doctrine_adherence(character_analysis, fleet_data),
        progression_analysis:
          DoctrineAnalyzer.analyze_ship_progression_consistency(character_analysis, fleet_data)
      }

      # Generate correlation summary using statistical analyzer
      confidence_score = StatisticalAnalyzer.calculate_correlation_confidence(correlations)
      anomalies = StatisticalAnalyzer.detect_progression_anomalies(character_analysis, fleet_data)

      result = %{
        character_id: character_id,
        correlations: correlations,
        confidence_score: confidence_score,
        anomalies: anomalies,
        analysis_timestamp: DateTime.utc_now(),
        analysis_version: "2.0_refactored"
      }

      {:ok, result}
    else
      {:error, reason} ->
        Logger.error("Correlation analysis failed for character #{character_id}: #{reason}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.error("Unexpected error in correlation analysis: #{inspect(error)}")
      {:error, "Analysis failed due to unexpected error"}
  end

  @doc """
  Analyze corporation intelligence patterns using the specialized corporation analyzer.
  """
  @spec analyze_corporation_intelligence_patterns(integer()) ::
          {:ok, map()} | {:error, String.t()}
  def analyze_corporation_intelligence_patterns(corporation_id) do
    Logger.info("Starting corporation intelligence analysis for corp #{corporation_id}")
    CorporationAnalyzer.analyze_corporation(corporation_id)
  end

  @doc """
  Bulk analyze character correlations for multiple characters.
  """
  @spec analyze_character_correlations(list(integer())) ::
          {:ok, list(map())} | {:error, String.t()}
  def analyze_character_correlations(character_ids) when is_list(character_ids) do
    Logger.info(
      "Starting bulk character correlation analysis for #{length(character_ids)} characters"
    )

    results =
      character_ids
      |> Enum.map(&analyze_cross_module_correlations/1)
      |> Enum.filter(fn
        {:ok, _} -> true
        {:error, _} -> false
      end)
      |> Enum.map(&elem(&1, 1))

    {:ok, results}
  rescue
    error ->
      Logger.error("Bulk analysis failed: #{inspect(error)}")
      {:error, "Bulk analysis failed"}
  end

  # Private helper functions - greatly simplified

  defp get_character_analysis(character_id) do
    Cache.get_or_compute(
      {:character_analysis, character_id},
      :timer.hours(1),
      fn -> CharacterAnalyzer.analyze_character(character_id) end
    )
  end

  defp get_vetting_data(character_id) do
    # Simplified vetting data retrieval
    case Ash.read(WHVetting, actor: nil, character_id: character_id, domain: Api) do
      {:ok, [vetting | _]} -> {:ok, vetting}
      {:ok, []} -> {:ok, %{status: :not_vetted, recommendation: :unknown}}
      {:error, reason} -> {:error, "Failed to get vetting data: #{inspect(reason)}"}
    end
  end

  defp get_activity_data(character_id) do
    # Simplified activity data using member activity analyzer
    try do
      period_start = DateTime.add(DateTime.utc_now(), -30, :day)
      period_end = DateTime.utc_now()

      case MemberActivityAnalyzer.analyze_member_activity(
             character_id,
             period_start,
             period_end,
             %{}
           ) do
        {:ok, activity} -> {:ok, activity}
        {:error, reason} -> {:error, "Failed to get activity data: #{inspect(reason)}"}
        activity when is_map(activity) -> {:ok, activity}
        _ -> {:ok, %{activity_level: :unknown}}
      end
    rescue
      error ->
        Logger.warning("Activity data retrieval failed: #{inspect(error)}")
        {:ok, %{activity_level: :unknown}}
    end
  end

  defp get_fleet_data(_character_id) do
    # Placeholder for fleet data - simplified
    {:ok,
     %{
       ship_usage: %{},
       fleet_participation: 0,
       preferred_roles: []
     }}
  end

  defp correlate_threat_indicators(character_analysis, vetting_data) do
    # Simplified threat correlation
    base_threat = Map.get(character_analysis, :threat_score, 0)

    vetting_modifier =
      case Map.get(vetting_data, :recommendation) do
        :accept -> -10
        :reject -> 20
        :caution -> 5
        _ -> 0
      end

    final_threat = max(0, min(100, base_threat + vetting_modifier))

    %{
      threat_level: classify_threat_level(final_threat),
      threat_score: final_threat,
      correlation_strength: if(vetting_modifier != 0, do: :strong, else: :weak)
    }
  end

  defp correlate_competency_metrics(character_analysis, fleet_data, activity_data) do
    # Simplified competency correlation
    skill_level = Map.get(character_analysis, :skill_level, 0)
    activity_level = Map.get(activity_data, :activity_score, 0)
    fleet_participation = Map.get(fleet_data, :fleet_participation, 0)

    competency_score = (skill_level + activity_level + fleet_participation) / 3

    %{
      competency_score: round(competency_score),
      skill_activity_correlation:
        StatisticalAnalyzer.calculate_correlation_coefficient([skill_level], [activity_level]),
      overall_assessment: classify_competency(competency_score)
    }
  end

  defp correlate_behavioral_patterns(vetting_data, activity_data) do
    # Simplified behavioral pattern correlation
    vetting_status = Map.get(vetting_data, :status, :unknown)
    activity_level = Map.get(activity_data, :activity_score, 0)

    %{
      pattern_consistency: assess_pattern_consistency(vetting_status, activity_level),
      behavioral_risk: assess_behavioral_risk(vetting_status, activity_level),
      reliability_indicator: classify_reliability(vetting_status, activity_level)
    }
  end

  # Simple classification helpers

  defp classify_threat_level(score) when score >= 70, do: :high
  defp classify_threat_level(score) when score >= 40, do: :medium
  defp classify_threat_level(_score), do: :low

  defp classify_competency(score) when score >= 80, do: :excellent
  defp classify_competency(score) when score >= 60, do: :good
  defp classify_competency(score) when score >= 40, do: :average
  defp classify_competency(_score), do: :poor

  defp assess_pattern_consistency(:accept, activity) when activity > 50, do: :consistent
  defp assess_pattern_consistency(:reject, activity) when activity < 30, do: :consistent
  defp assess_pattern_consistency(_, _), do: :inconsistent

  defp assess_behavioral_risk(:reject, _), do: :high
  defp assess_behavioral_risk(:caution, activity) when activity > 70, do: :medium
  defp assess_behavioral_risk(_, _), do: :low

  defp classify_reliability(:accept, activity) when activity > 60, do: :high
  defp classify_reliability(:not_vetted, activity) when activity > 40, do: :medium
  defp classify_reliability(_, _), do: :low
end
