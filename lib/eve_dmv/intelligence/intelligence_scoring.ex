# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmv.Intelligence.IntelligenceScoring do
  @moduledoc """
  Enhanced intelligence scoring system with sophisticated algorithms.

  Provides advanced scoring mechanisms for character analysis, threat assessment,
  and recruitment vetting using multiple data sources and statistical methods.
  """

  require Logger
  require Ash.Query
  alias EveDmv.Api
  alias EveDmv.Intelligence.AdvancedAnalytics
  alias EveDmv.Intelligence.CharacterStats

  # Extracted scoring modules
  alias EveDmv.Intelligence.IntelligenceScoring.CombatScoring
  alias EveDmv.Intelligence.IntelligenceScoring.BehavioralScoring
  alias EveDmv.Intelligence.IntelligenceScoring.RecruitmentScoring
  alias EveDmv.Intelligence.IntelligenceScoring.FleetScoring
  alias EveDmv.Intelligence.IntelligenceScoring.IntelligenceSuitability

  @doc """
  Calculate comprehensive intelligence score for a character.

  Combines multiple intelligence sources into a unified scoring framework.
  """
  def calculate_comprehensive_score(character_id) do
    Logger.info("Calculating comprehensive intelligence score for character #{character_id}")

    with {:ok, base_metrics} <- gather_base_metrics(character_id),
         {:ok, behavioral_analysis} <-
           AdvancedAnalytics.analyze_behavioral_patterns(character_id),
         {:ok, threat_assessment} <- AdvancedAnalytics.advanced_threat_assessment(character_id),
         {:ok, risk_analysis} <- AdvancedAnalytics.calculate_advanced_risk_score(character_id) do
      # Calculate component scores using extracted modules
      component_scores = %{
        combat_competency: CombatScoring.calculate_combat_competency_score(base_metrics),
        tactical_intelligence:
          CombatScoring.calculate_tactical_intelligence_score(base_metrics, behavioral_analysis),
        security_risk: BehavioralScoring.calculate_security_risk_score(risk_analysis),
        behavioral_stability:
          BehavioralScoring.calculate_behavioral_stability_score(behavioral_analysis),
        operational_value:
          CombatScoring.calculate_operational_value_score(base_metrics, threat_assessment),
        intelligence_reliability:
          BehavioralScoring.calculate_reliability_score(base_metrics, behavioral_analysis)
      }

      # Weight and combine scores
      overall_score = calculate_weighted_overall_score(component_scores)
      score_grade = assign_score_grade(overall_score)

      {:ok,
       %{
         overall_score: overall_score,
         score_grade: score_grade,
         component_scores: component_scores,
         scoring_methodology: "Multi-dimensional weighted intelligence scoring",
         confidence_level: calculate_scoring_confidence(component_scores),
         recommendations: generate_scoring_recommendations(component_scores, score_grade),
         analysis_timestamp: DateTime.utc_now()
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculate recruitment fitness score for a character.

  Specifically evaluates suitability for recruitment into a corporation.
  """
  def calculate_recruitment_fitness(character_id, corporation_requirements \\ %{}) do
    with {:ok, comprehensive_score} <- calculate_comprehensive_score(character_id) do
      RecruitmentScoring.calculate_recruitment_fitness(
        character_id,
        comprehensive_score,
        corporation_requirements
      )
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculate fleet readiness score for multiple characters.

  Evaluates how well a group of characters work together in fleet operations.
  """
  def calculate_fleet_readiness_score(character_ids) when is_list(character_ids) do
    FleetScoring.calculate_fleet_readiness_score(character_ids)
  end

  @doc """
  Calculate intelligence operation suitability score.

  Evaluates character suitability for intelligence and reconnaissance operations.
  """
  def calculate_intelligence_suitability(character_id) do
    IntelligenceSuitability.calculate_intelligence_suitability(character_id)
  end

  # Private helper functions

  defp gather_base_metrics(character_id) do
    case CharacterStats
         |> Ash.Query.new()
         |> Ash.Query.filter(character_id: character_id)
         |> Ash.Query.limit(1)
         |> Ash.read(domain: Api) do
      {:ok, [stats]} -> {:ok, stats}
      {:ok, []} -> {:error, "Character statistics not available"}
      {:error, reason} -> {:error, reason}
    end
  end


  defp calculate_weighted_overall_score(component_scores) do
    # Strategic weighting of different score components
    weights = %{
      combat_competency: 0.20,
      tactical_intelligence: 0.20,
      security_risk: 0.15,
      behavioral_stability: 0.15,
      operational_value: 0.15,
      intelligence_reliability: 0.15
    }

    weighted_score =
      Enum.reduce(component_scores, 0.0, fn {component, score}, acc ->
        weight = Map.get(weights, component, 0.0)
        acc + score * weight
      end)

    Float.round(weighted_score, 3)
  end

  defp assign_score_grade(score) do
    cond do
      score >= 0.9 -> "A+"
      score >= 0.85 -> "A"
      score >= 0.8 -> "A-"
      score >= 0.75 -> "B+"
      score >= 0.7 -> "B"
      score >= 0.65 -> "B-"
      score >= 0.6 -> "C+"
      score >= 0.55 -> "C"
      score >= 0.5 -> "C-"
      score >= 0.4 -> "D"
      true -> "F"
    end
  end

  defp calculate_scoring_confidence(component_scores) do
    # Confidence based on score consistency and data quality
    score_values = Map.values(component_scores)
    mean_score = Enum.sum(score_values) / length(score_values)

    # Calculate variance
    variance =
      Enum.reduce(score_values, 0.0, fn score, acc ->
        acc + :math.pow(score - mean_score, 2)
      end) / length(score_values)

    # Lower variance = higher confidence
    confidence = max(0.0, 1.0 - variance)
    Float.round(confidence, 2)
  end

  defp generate_scoring_recommendations(component_scores, score_grade) do
    # Grade-based recommendations
    base_recommendations =
      case score_grade do
        grade when grade in ["A+", "A", "A-"] ->
          ["Excellent candidate", "Fast-track approval recommended"]

        grade when grade in ["B+", "B", "B-"] ->
          ["Good candidate", "Standard approval process"]

        grade when grade in ["C+", "C", "C-"] ->
          ["Average candidate", "Additional assessment recommended"]

        "D" ->
          ["Below average candidate", "Probationary period recommended"]

        "F" ->
          ["Poor candidate", "Rejection recommended"]
      end

    # Component-specific recommendations
    security_recommendation =
      if component_scores.security_risk < 0.6 do
        ["Enhanced security screening required"]
      else
        []
      end

    behavioral_recommendation =
      if component_scores.behavioral_stability < 0.5 do
        ["Monitor for behavioral consistency"]
      else
        []
      end

    security_recommendation ++ behavioral_recommendation ++ base_recommendations
  end

  # Delegated function declarations for backward compatibility

  defdelegate assess_opsec_discipline(comprehensive_score, behavioral_patterns),
    to: IntelligenceSuitability

  defdelegate analyze_fleet_composition(individual_scores), to: FleetScoring
  defdelegate generate_fleet_optimization_recommendations(fleet_metrics), to: FleetScoring
  defdelegate assess_psychological_profile(behavioral_analysis, stats), to: BehavioralScoring
  defdelegate generate_behavioral_recommendations(psychological_profile), to: BehavioralScoring
end
