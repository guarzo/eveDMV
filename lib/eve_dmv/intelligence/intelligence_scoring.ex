defmodule EveDmv.Intelligence.IntelligenceScoring do
  @moduledoc """
  Enhanced intelligence scoring system with sophisticated algorithms.

  Provides advanced scoring mechanisms for character analysis, threat assessment,
  and recruitment vetting using multiple data sources and statistical methods.
  """

  require Logger
  alias EveDmv.Intelligence.{AdvancedAnalytics, CharacterStats, WHVetting, CorrelationEngine}

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
      # Calculate component scores
      component_scores = %{
        combat_competency: calculate_combat_competency_score(base_metrics),
        tactical_intelligence:
          calculate_tactical_intelligence_score(base_metrics, behavioral_analysis),
        security_risk: calculate_security_risk_score(risk_analysis),
        behavioral_stability: calculate_behavioral_stability_score(behavioral_analysis),
        operational_value: calculate_operational_value_score(base_metrics, threat_assessment),
        intelligence_reliability: calculate_reliability_score(base_metrics, behavioral_analysis)
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
    Logger.info("Calculating recruitment fitness score for character #{character_id}")

    with {:ok, comprehensive_score} <- calculate_comprehensive_score(character_id),
         {:ok, vetting_data} <- get_vetting_data(character_id) do
      # Evaluate against corporation requirements
      requirement_scores =
        evaluate_corporation_requirements(comprehensive_score, corporation_requirements)

      # Calculate fit scores
      fitness_components = %{
        skill_fit: calculate_skill_fitness(comprehensive_score),
        cultural_fit: calculate_cultural_fitness(comprehensive_score, vetting_data),
        security_fit: calculate_security_fitness(comprehensive_score),
        operational_fit:
          calculate_operational_fitness(comprehensive_score, corporation_requirements),
        growth_potential: calculate_growth_potential(comprehensive_score, vetting_data)
      }

      recruitment_score = calculate_recruitment_score(fitness_components)

      recruitment_recommendation =
        generate_recruitment_recommendation(recruitment_score, fitness_components)

      {:ok,
       %{
         recruitment_score: recruitment_score,
         recruitment_recommendation: recruitment_recommendation,
         fitness_components: fitness_components,
         requirement_scores: requirement_scores,
         decision_factors: identify_key_decision_factors(fitness_components),
         probation_recommendations: suggest_probation_terms(fitness_components),
         analysis_timestamp: DateTime.utc_now()
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculate fleet readiness score for multiple characters.

  Evaluates how well a group of characters work together in fleet operations.
  """
  def calculate_fleet_readiness_score(character_ids) when is_list(character_ids) do
    Logger.info("Calculating fleet readiness score for #{length(character_ids)} characters")

    if length(character_ids) < 2 do
      {:error, "Fleet readiness requires at least 2 characters"}
    else
      # Get individual scores
      individual_scores =
        Enum.map(character_ids, fn char_id ->
          case calculate_comprehensive_score(char_id) do
            {:ok, score} -> {char_id, score}
            {:error, _} -> {char_id, nil}
          end
        end)
        |> Enum.filter(fn {_, score} -> not is_nil(score) end)

      if length(individual_scores) >= 2 do
        # Calculate fleet synergy
        with {:ok, correlation_analysis} <-
               AdvancedAnalytics.advanced_character_correlation(character_ids) do
          fleet_metrics = %{
            individual_competency: calculate_fleet_individual_competency(individual_scores),
            role_balance: calculate_fleet_role_balance(individual_scores),
            synergy_factor: calculate_fleet_synergy(correlation_analysis),
            command_structure: assess_fleet_command_structure(individual_scores),
            tactical_coherence: assess_tactical_coherence(individual_scores),
            operational_reliability: assess_operational_reliability(individual_scores)
          }

          fleet_score = calculate_overall_fleet_score(fleet_metrics)
          fleet_grade = assign_fleet_grade(fleet_score)

          {:ok,
           %{
             fleet_readiness_score: fleet_score,
             fleet_grade: fleet_grade,
             fleet_metrics: fleet_metrics,
             character_count: length(individual_scores),
             optimization_suggestions: suggest_fleet_optimizations(fleet_metrics),
             analysis_timestamp: DateTime.utc_now()
           }}
        else
          {:error, "Could not analyze character correlations"}
        end
      else
        {:error, "Insufficient valid character data for fleet analysis"}
      end
    end
  end

  @doc """
  Calculate intelligence operation suitability score.

  Evaluates character suitability for intelligence and reconnaissance operations.
  """
  def calculate_intelligence_suitability(character_id) do
    Logger.info("Calculating intelligence operation suitability for character #{character_id}")

    with {:ok, comprehensive_score} <- calculate_comprehensive_score(character_id),
         {:ok, behavioral_patterns} <- AdvancedAnalytics.analyze_behavioral_patterns(character_id) do
      intel_components = %{
        stealth_capability: assess_stealth_capability(comprehensive_score),
        information_gathering: assess_information_gathering_skill(comprehensive_score),
        operational_security: assess_opsec_discipline(comprehensive_score, behavioral_patterns),
        analytical_thinking: assess_analytical_capability(behavioral_patterns),
        discretion_level: assess_discretion_level(behavioral_patterns),
        technical_competency: assess_technical_competency(comprehensive_score)
      }

      intelligence_score = calculate_intelligence_score(intel_components)
      suitability_level = classify_intelligence_suitability(intelligence_score)

      {:ok,
       %{
         intelligence_suitability_score: intelligence_score,
         suitability_level: suitability_level,
         intel_components: intel_components,
         recommended_roles: suggest_intelligence_roles(intel_components),
         training_recommendations: suggest_intelligence_training(intel_components),
         security_clearance_level:
           recommend_clearance_level(intelligence_score, intel_components),
         analysis_timestamp: DateTime.utc_now()
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helper functions

  defp gather_base_metrics(character_id) do
    case CharacterStats.get_by_character_id(character_id) do
      {:ok, [stats]} -> {:ok, stats}
      _ -> {:error, "Character statistics not available"}
    end
  end

  defp get_vetting_data(character_id) do
    case WHVetting.get_by_character(character_id) do
      {:ok, [vetting]} -> {:ok, vetting}
      # Return empty map if no vetting data
      _ -> {:ok, %{}}
    end
  end

  defp calculate_combat_competency_score(stats) do
    # Multi-factor combat competency assessment
    factors = %{
      kill_efficiency: calculate_kill_efficiency(stats),
      experience_breadth: calculate_experience_breadth(stats),
      survival_rate: calculate_survival_rate(stats),
      engagement_frequency: calculate_engagement_frequency(stats)
    }

    # Weighted combination
    weights = %{
      kill_efficiency: 0.3,
      experience_breadth: 0.25,
      survival_rate: 0.25,
      engagement_frequency: 0.2
    }

    Enum.reduce(factors, 0.0, fn {factor, value}, acc ->
      acc + value * Map.get(weights, factor, 0.0)
    end)
  end

  defp calculate_tactical_intelligence_score(stats, behavioral_analysis) do
    # Assess tactical decision-making capability
    tactical_factors = %{
      pattern_recognition: behavioral_analysis.confidence_score,
      adaptability: assess_tactical_adaptability(stats),
      decision_quality: assess_decision_quality(stats),
      situational_awareness: assess_situational_awareness(behavioral_analysis)
    }

    # Equal weighting for tactical factors
    tactical_factors
    |> Map.values()
    |> Enum.sum()
    |> Kernel./(map_size(tactical_factors))
  end

  defp calculate_security_risk_score(risk_analysis) do
    # Invert risk score for positive scoring
    1.0 - risk_analysis.advanced_risk_score
  end

  defp calculate_behavioral_stability_score(behavioral_analysis) do
    # Assess behavioral predictability and stability
    stability_factors = [
      behavioral_analysis.confidence_score,
      1.0 - behavioral_analysis.patterns.anomaly_detection.anomaly_count * 0.1,
      behavioral_analysis.patterns.activity_rhythm.consistency_score
    ]

    Enum.sum(stability_factors) / length(stability_factors)
  end

  defp calculate_operational_value_score(stats, threat_assessment) do
    # Assess overall operational value to organization
    value_factors = %{
      combat_effectiveness: threat_assessment.threat_indicators.combat_effectiveness,
      tactical_sophistication: threat_assessment.threat_indicators.tactical_sophistication,
      leadership_potential: assess_leadership_potential(stats),
      versatility: assess_operational_versatility(stats)
    }

    Enum.reduce(value_factors, 0.0, fn {_factor, value}, acc ->
      acc + value
    end) / map_size(value_factors)
  end

  defp calculate_reliability_score(stats, behavioral_analysis) do
    # Assess reliability and trustworthiness
    reliability_factors = [
      behavioral_analysis.confidence_score,
      calculate_activity_consistency(stats),
      assess_commitment_level(stats)
    ]

    Enum.sum(reliability_factors) / length(reliability_factors)
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
    recommendations = []

    # Grade-based recommendations
    recommendations =
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
    if component_scores.security_risk < 0.6 do
      recommendations = ["Enhanced security screening required" | recommendations]
    end

    if component_scores.behavioral_stability < 0.5 do
      recommendations = ["Monitor for behavioral consistency" | recommendations]
    end

    recommendations
  end

  # Recruitment fitness helper functions
  defp evaluate_corporation_requirements(comprehensive_score, requirements) do
    # Evaluate against specific corp requirements
    default_requirements = %{
      min_combat_score: 0.6,
      min_security_score: 0.7,
      min_reliability_score: 0.6
    }

    reqs = Map.merge(default_requirements, requirements)

    %{
      combat_requirement_met:
        comprehensive_score.component_scores.combat_competency >= reqs.min_combat_score,
      security_requirement_met:
        comprehensive_score.component_scores.security_risk >= reqs.min_security_score,
      reliability_requirement_met:
        comprehensive_score.component_scores.intelligence_reliability >=
          reqs.min_reliability_score
    }
  end

  defp calculate_skill_fitness(comprehensive_score) do
    # Average of combat and tactical scores
    (comprehensive_score.component_scores.combat_competency +
       comprehensive_score.component_scores.tactical_intelligence) / 2.0
  end

  defp calculate_cultural_fitness(comprehensive_score, _vetting_data) do
    # Assess cultural fit based on behavioral patterns
    comprehensive_score.component_scores.behavioral_stability * 0.8 +
      comprehensive_score.component_scores.intelligence_reliability * 0.2
  end

  defp calculate_security_fitness(comprehensive_score) do
    comprehensive_score.component_scores.security_risk
  end

  defp calculate_operational_fitness(comprehensive_score, _requirements) do
    comprehensive_score.component_scores.operational_value
  end

  defp calculate_growth_potential(comprehensive_score, _vetting_data) do
    # Assess potential for improvement and development
    base_potential = comprehensive_score.component_scores.tactical_intelligence

    # Young characters with good fundamentals have higher growth potential
    # This would be enhanced with character age data
    base_potential
  end

  defp calculate_recruitment_score(fitness_components) do
    weights = %{
      skill_fit: 0.25,
      cultural_fit: 0.20,
      security_fit: 0.20,
      operational_fit: 0.20,
      growth_potential: 0.15
    }

    Enum.reduce(fitness_components, 0.0, fn {component, score}, acc ->
      weight = Map.get(weights, component, 0.0)
      acc + score * weight
    end)
  end

  defp generate_recruitment_recommendation(score, _components) do
    cond do
      score >= 0.8 ->
        %{decision: "approve", priority: "high", notes: "Excellent candidate"}

      score >= 0.7 ->
        %{decision: "approve", priority: "normal", notes: "Good candidate"}

      score >= 0.6 ->
        %{
          decision: "conditional",
          priority: "normal",
          notes: "Conditional approval with monitoring"
        }

      score >= 0.5 ->
        %{decision: "probation", priority: "low", notes: "Probationary period recommended"}

      true ->
        %{decision: "reject", priority: "none", notes: "Does not meet minimum standards"}
    end
  end

  defp identify_key_decision_factors(fitness_components) do
    # Identify the most important factors in the decision
    sorted_components =
      fitness_components
      |> Enum.sort_by(fn {_component, score} -> score end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {component, _score} -> component end)

    sorted_components
  end

  defp suggest_probation_terms(fitness_components) do
    terms = []

    if fitness_components.security_fit < 0.7 do
      terms = ["Enhanced background monitoring" | terms]
    end

    if fitness_components.cultural_fit < 0.6 do
      terms = ["Cultural integration mentoring" | terms]
    end

    if fitness_components.skill_fit < 0.6 do
      terms = ["Skills development program" | terms]
    end

    terms
  end

  # Additional helper functions (placeholders for complex calculations)
  defp calculate_kill_efficiency(stats) do
    kills = stats.total_kills || 0
    losses = stats.total_losses || 0

    if kills + losses > 0 do
      kills / (kills + losses)
    else
      0.0
    end
  end

  defp calculate_experience_breadth(stats) do
    # Assess breadth of experience based on ship diversity
    if stats.ship_usage do
      ship_types = map_size(stats.ship_usage)
      min(1.0, ship_types / 10.0)
    else
      0.0
    end
  end

  defp calculate_survival_rate(stats) do
    # Same calculation for now
    calculate_kill_efficiency(stats)
  end

  defp calculate_engagement_frequency(stats) do
    activity = (stats.total_kills || 0) + (stats.total_losses || 0)
    age_days = max(1, stats.character_age_days || 365)

    # Normalize to monthly frequency
    min(1.0, activity / age_days * 30)
  end

  defp assess_tactical_adaptability(stats) do
    # Assess based on ship usage diversity and gang size variation
    if stats.ship_usage do
      diversity_score = min(1.0, map_size(stats.ship_usage) / 8.0)
      gang_flexibility = if (stats.avg_gang_size || 1.0) > 1.0, do: 0.3, else: 0.0

      diversity_score * 0.7 + gang_flexibility
    else
      0.0
    end
  end

  defp assess_decision_quality(stats) do
    # Quality based on survival rate and efficiency
    (calculate_survival_rate(stats) + calculate_kill_efficiency(stats)) / 2.0
  end

  defp assess_situational_awareness(_behavioral_analysis) do
    # Placeholder
    0.6
  end

  defp assess_leadership_potential(stats) do
    # Leadership potential based on activity level and gang participation
    activity_factor = min(1.0, (stats.total_kills || 0) / 50.0)
    gang_factor = if (stats.avg_gang_size || 1.0) > 3.0, do: 0.4, else: 0.0

    activity_factor * 0.6 + gang_factor
  end

  defp assess_operational_versatility(stats) do
    calculate_experience_breadth(stats)
  end

  defp calculate_activity_consistency(_stats) do
    # Placeholder
    0.7
  end

  defp assess_commitment_level(stats) do
    # Commitment based on character age and activity
    age_factor = min(1.0, (stats.character_age_days || 365) / 1000.0)
    activity_factor = min(1.0, ((stats.total_kills || 0) + (stats.total_losses || 0)) / 100.0)

    (age_factor + activity_factor) / 2.0
  end

  # Fleet scoring helper functions
  defp calculate_fleet_individual_competency(individual_scores) do
    scores = Enum.map(individual_scores, fn {_id, score} -> score.overall_score end)
    Enum.sum(scores) / length(scores)
  end

  defp calculate_fleet_role_balance(_individual_scores) do
    # Placeholder for role balance calculation
    0.7
  end

  defp calculate_fleet_synergy(correlation_analysis) do
    correlation_analysis.overall_correlation_score
  end

  defp assess_fleet_command_structure(_individual_scores) do
    # Placeholder for command structure assessment
    0.6
  end

  defp assess_tactical_coherence(_individual_scores) do
    # Placeholder for tactical coherence assessment
    0.7
  end

  defp assess_operational_reliability(individual_scores) do
    reliability_scores =
      Enum.map(individual_scores, fn {_id, score} ->
        score.component_scores.intelligence_reliability
      end)

    Enum.sum(reliability_scores) / length(reliability_scores)
  end

  defp calculate_overall_fleet_score(fleet_metrics) do
    weights = %{
      individual_competency: 0.25,
      role_balance: 0.20,
      synergy_factor: 0.20,
      command_structure: 0.15,
      tactical_coherence: 0.10,
      operational_reliability: 0.10
    }

    Enum.reduce(fleet_metrics, 0.0, fn {metric, score}, acc ->
      weight = Map.get(weights, metric, 0.0)
      acc + score * weight
    end)
  end

  defp assign_fleet_grade(score) do
    # Reuse the same grading system
    assign_score_grade(score)
  end

  defp suggest_fleet_optimizations(_fleet_metrics) do
    ["Consider role specialization", "Enhance coordination training", "Develop tactical SOPs"]
  end

  # Intelligence suitability helper functions
  defp assess_stealth_capability(comprehensive_score) do
    # Stealth based on survival rate and tactical intelligence
    (comprehensive_score.component_scores.security_risk +
       comprehensive_score.component_scores.tactical_intelligence) / 2.0
  end

  defp assess_information_gathering_skill(comprehensive_score) do
    comprehensive_score.component_scores.tactical_intelligence
  end

  defp assess_opsec_discipline(_comprehensive_score, behavioral_patterns) do
    behavioral_patterns.confidence_score
  end

  defp assess_analytical_capability(behavioral_patterns) do
    behavioral_patterns.patterns.operational_patterns.strategic_thinking
  end

  defp assess_discretion_level(behavioral_patterns) do
    # Higher stability suggests better discretion
    behavioral_patterns.patterns.risk_progression.stability_score
  end

  defp assess_technical_competency(comprehensive_score) do
    comprehensive_score.component_scores.tactical_intelligence
  end

  defp calculate_intelligence_score(intel_components) do
    # Equal weighting for intelligence components
    scores = Map.values(intel_components)
    Enum.sum(scores) / length(scores)
  end

  defp classify_intelligence_suitability(score) do
    cond do
      score >= 0.8 -> "highly_suitable"
      score >= 0.7 -> "suitable"
      score >= 0.6 -> "conditionally_suitable"
      score >= 0.5 -> "limited_suitability"
      true -> "not_suitable"
    end
  end

  defp suggest_intelligence_roles(intel_components) do
    roles = []

    if intel_components.stealth_capability > 0.7 do
      roles = ["reconnaissance", "infiltration" | roles]
    end

    if intel_components.analytical_thinking > 0.7 do
      roles = ["intelligence_analysis", "threat_assessment" | roles]
    end

    if intel_components.technical_competency > 0.6 do
      roles = ["technical_intelligence", "cyber_operations" | roles]
    end

    if Enum.empty?(roles) do
      ["support_operations"]
    else
      roles
    end
  end

  defp suggest_intelligence_training(intel_components) do
    training = []

    if intel_components.operational_security < 0.6 do
      training = ["OpSec fundamentals", "Security protocols" | training]
    end

    if intel_components.analytical_thinking < 0.6 do
      training = ["Intelligence analysis methods", "Pattern recognition" | training]
    end

    if intel_components.technical_competency < 0.5 do
      training = ["Technical skills development", "Tools and software" | training]
    end

    training
  end

  defp recommend_clearance_level(score, _intel_components) do
    cond do
      score >= 0.8 -> "secret"
      score >= 0.7 -> "confidential"
      score >= 0.6 -> "restricted"
      true -> "public"
    end
  end
end
