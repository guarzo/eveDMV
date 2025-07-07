defmodule EveDmv.Intelligence.IntelligenceScoring.IntelligenceSuitability do
  @moduledoc """
  Intelligence operation suitability assessment module.

  Handles evaluation of character suitability for intelligence and reconnaissance
  operations, including stealth capability, analytical thinking, and operational security.
  """

  alias EveDmv.Intelligence.AdvancedAnalytics
  require Logger

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

  @doc """
  Assess operational security (OPSEC) discipline.
  """
  def assess_opsec_discipline(comprehensive_score, behavioral_patterns) do
    # Comprehensive OPSEC assessment
    opsec_components = %{
      behavioral_consistency: assess_behavioral_opsec(behavioral_patterns),
      information_discipline: assess_information_discipline(behavioral_patterns),
      pattern_masking: assess_pattern_masking_ability(behavioral_patterns),
      communication_security: assess_communication_security(behavioral_patterns),
      operational_awareness: assess_operational_awareness(comprehensive_score)
    }

    # Weighted OPSEC score
    weights = %{
      behavioral_consistency: 0.25,
      information_discipline: 0.25,
      pattern_masking: 0.20,
      communication_security: 0.15,
      operational_awareness: 0.15
    }

    opsec_score =
      Enum.reduce(opsec_components, 0.0, fn {component, score}, acc ->
        weight = Map.get(weights, component, 0.0)
        acc + score * weight
      end)

    %{
      overall_opsec_score: opsec_score,
      component_scores: opsec_components,
      opsec_recommendations: generate_opsec_recommendations(opsec_components),
      risk_assessment: assess_opsec_risks(opsec_components)
    }
  end

  @doc """
  Generate detailed intelligence role recommendations.
  """
  def generate_intelligence_role_recommendations(intel_components) do
    role_assessments = %{
      reconnaissance: assess_reconnaissance_suitability(intel_components),
      infiltration: assess_infiltration_suitability(intel_components),
      intelligence_analysis: assess_analysis_suitability(intel_components),
      threat_assessment: assess_threat_assessment_suitability(intel_components),
      technical_intelligence: assess_technical_intelligence_suitability(intel_components),
      counterintelligence: assess_counterintelligence_suitability(intel_components),
      cyber_operations: assess_cyber_operations_suitability(intel_components),
      human_intelligence: assess_humint_suitability(intel_components)
    }

    # Sort roles by suitability score
    # Top 3 roles
    sorted_roles =
      Enum.take(Enum.sort_by(role_assessments, fn {_role, score} -> score end, :desc), 3)

    %{
      primary_recommendations: sorted_roles,
      role_assessments: role_assessments,
      specialization_suggestions: generate_specialization_suggestions(intel_components),
      development_priorities: identify_development_priorities(intel_components)
    }
  end

  # Core intelligence assessment functions

  defp assess_stealth_capability(comprehensive_score) do
    # Stealth based on survival rate, security awareness, and tactical intelligence
    stealth_factors = [
      comprehensive_score.component_scores.security_risk,
      comprehensive_score.component_scores.tactical_intelligence,
      # Predictable behavior aids stealth
      comprehensive_score.component_scores.behavioral_stability
    ]

    Enum.sum(stealth_factors) / length(stealth_factors)
  end

  defp assess_information_gathering_skill(comprehensive_score) do
    # Information gathering based on tactical intelligence and operational value
    gathering_factors = [
      comprehensive_score.component_scores.tactical_intelligence,
      # Operational skills matter
      comprehensive_score.component_scores.operational_value * 0.8,
      # Reliability in gathering
      comprehensive_score.component_scores.intelligence_reliability * 0.6
    ]

    Enum.sum(gathering_factors) / length(gathering_factors)
  end

  defp assess_analytical_capability(behavioral_patterns) do
    # Extract analytical indicators from behavioral patterns
    analytical_indicators = [
      Map.get(behavioral_patterns, :pattern_recognition_score, 0.5),
      Map.get(behavioral_patterns, :logical_reasoning_score, 0.5),
      Map.get(behavioral_patterns, :strategic_thinking_score, 0.5),
      Map.get(behavioral_patterns, :detail_orientation_score, 0.5)
    ]

    Enum.sum(analytical_indicators) / length(analytical_indicators)
  end

  defp assess_discretion_level(behavioral_patterns) do
    # Assess ability to maintain confidentiality and exercise discretion
    discretion_indicators = [
      Map.get(behavioral_patterns, :information_discipline_score, 0.5),
      Map.get(behavioral_patterns, :communication_restraint_score, 0.5),
      Map.get(behavioral_patterns, :confidentiality_adherence_score, 0.5),
      assess_social_engineering_resistance(behavioral_patterns)
    ]

    Enum.sum(discretion_indicators) / length(discretion_indicators)
  end

  defp assess_technical_competency(comprehensive_score) do
    # Technical competency for intelligence operations
    technical_factors = [
      comprehensive_score.component_scores.tactical_intelligence,
      comprehensive_score.component_scores.operational_value * 0.7,
      assess_technical_aptitude(comprehensive_score)
    ]

    Enum.sum(technical_factors) / length(technical_factors)
  end

  defp calculate_intelligence_score(intel_components) do
    # Weighted intelligence scoring
    weights = %{
      stealth_capability: 0.20,
      information_gathering: 0.20,
      operational_security: 0.20,
      analytical_thinking: 0.15,
      discretion_level: 0.15,
      technical_competency: 0.10
    }

    Enum.reduce(intel_components, 0.0, fn {component, score}, acc ->
      weight = Map.get(weights, component, 0.0)

      # Extract numeric score from complex data structures
      numeric_score =
        case score do
          %{overall_opsec_score: opsec_score} when component == :operational_security ->
            opsec_score

          score when is_number(score) ->
            score

          _ ->
            # Default fallback score
            0.5
        end

      acc + numeric_score * weight
    end)
  end

  defp classify_intelligence_suitability(score) do
    cond do
      score >= 0.85 -> :elite_operative
      score >= 0.75 -> :highly_suitable
      score >= 0.65 -> :suitable
      score >= 0.55 -> :conditionally_suitable
      score >= 0.45 -> :limited_suitability
      true -> :not_suitable
    end
  end

  # OPSEC assessment functions

  defp assess_behavioral_opsec(behavioral_patterns) do
    # Assess behavioral consistency for OPSEC
    consistency_score = Map.get(behavioral_patterns, :behavioral_consistency, 0.5)
    pattern_variance = Map.get(behavioral_patterns, :pattern_variance, 0.3)

    # Lower variance indicates better OPSEC
    opsec_score = consistency_score * (1.0 - pattern_variance)
    min(opsec_score, 1.0)
  end

  defp assess_information_discipline(behavioral_patterns) do
    # Assess discipline in information handling
    Map.get(behavioral_patterns, :information_sharing_restraint, 0.5)
  end

  defp assess_pattern_masking_ability(behavioral_patterns) do
    # Assess ability to mask operational patterns
    Map.get(behavioral_patterns, :pattern_masking_capability, 0.5)
  end

  defp assess_communication_security(behavioral_patterns) do
    # Assess secure communication practices
    Map.get(behavioral_patterns, :secure_communication_usage, 0.5)
  end

  defp assess_operational_awareness(comprehensive_score) do
    # Assess awareness of operational security needs
    (comprehensive_score.component_scores.security_risk +
       comprehensive_score.component_scores.tactical_intelligence) / 2.0
  end

  # Role-specific suitability assessments

  defp assess_reconnaissance_suitability(intel_components) do
    # Reconnaissance requires stealth, information gathering, and technical skills
    intel_components.stealth_capability * 0.4 +
      intel_components.information_gathering * 0.3 +
      intel_components.technical_competency * 0.3
  end

  defp assess_infiltration_suitability(intel_components) do
    # Infiltration requires high stealth, OPSEC, and discretion
    opsec_score =
      case intel_components.operational_security do
        %{overall_opsec_score: score} -> score
        score when is_number(score) -> score
        _ -> 0.5
      end

    intel_components.stealth_capability * 0.4 +
      opsec_score * 0.35 +
      intel_components.discretion_level * 0.25
  end

  defp assess_analysis_suitability(intel_components) do
    # Analysis requires analytical thinking and technical competency
    intel_components.analytical_thinking * 0.5 +
      intel_components.technical_competency * 0.3 +
      intel_components.information_gathering * 0.2
  end

  defp assess_threat_assessment_suitability(intel_components) do
    # Threat assessment combines analysis with operational understanding
    opsec_score =
      case intel_components.operational_security do
        %{overall_opsec_score: score} -> score
        score when is_number(score) -> score
        _ -> 0.5
      end

    intel_components.analytical_thinking * 0.4 +
      intel_components.information_gathering * 0.3 +
      opsec_score * 0.3
  end

  defp assess_technical_intelligence_suitability(intel_components) do
    # Technical intelligence prioritizes technical skills and analysis
    intel_components.technical_competency * 0.5 +
      intel_components.analytical_thinking * 0.3 +
      intel_components.information_gathering * 0.2
  end

  defp assess_counterintelligence_suitability(intel_components) do
    # Counterintelligence requires high OPSEC, discretion, and analytical skills
    opsec_score =
      case intel_components.operational_security do
        %{overall_opsec_score: score} -> score
        score when is_number(score) -> score
        _ -> 0.5
      end

    opsec_score * 0.4 +
      intel_components.discretion_level * 0.3 +
      intel_components.analytical_thinking * 0.3
  end

  defp assess_cyber_operations_suitability(intel_components) do
    # Cyber operations require technical skills and OPSEC
    opsec_score =
      case intel_components.operational_security do
        %{overall_opsec_score: score} -> score
        score when is_number(score) -> score
        _ -> 0.5
      end

    intel_components.technical_competency * 0.5 +
      opsec_score * 0.3 +
      intel_components.analytical_thinking * 0.2
  end

  defp assess_humint_suitability(intel_components) do
    # Human intelligence requires discretion, information gathering, and social skills
    opsec_score =
      case intel_components.operational_security do
        %{overall_opsec_score: score} -> score
        score when is_number(score) -> score
        _ -> 0.5
      end

    intel_components.discretion_level * 0.4 +
      intel_components.information_gathering * 0.35 +
      opsec_score * 0.25
  end

  # Recommendation and training functions

  defp suggest_intelligence_roles(intel_components) do
    role_scores = %{
      reconnaissance: assess_reconnaissance_suitability(intel_components),
      infiltration: assess_infiltration_suitability(intel_components),
      intelligence_analysis: assess_analysis_suitability(intel_components),
      threat_assessment: assess_threat_assessment_suitability(intel_components),
      technical_intelligence: assess_technical_intelligence_suitability(intel_components),
      counterintelligence: assess_counterintelligence_suitability(intel_components),
      cyber_operations: assess_cyber_operations_suitability(intel_components),
      human_intelligence: assess_humint_suitability(intel_components)
    }

    # Return top 3 roles
    role_scores
    |> Enum.sort_by(fn {_role, score} -> score end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {role, _score} -> role end)
  end

  defp suggest_intelligence_training(intel_components) do
    initial_training = []

    opsec_score =
      case intel_components.operational_security do
        %{overall_opsec_score: score} -> score
        score when is_number(score) -> score
        _ -> 0.5
      end

    training_with_opsec =
      if opsec_score < 0.6 do
        ["OPSEC fundamentals", "Information security protocols" | initial_training]
      else
        initial_training
      end

    training_with_analytical =
      if intel_components.analytical_thinking < 0.6 do
        [
          "Intelligence analysis methods",
          "Pattern recognition training" | training_with_opsec
        ]
      else
        training_with_opsec
      end

    training_with_technical =
      if intel_components.technical_competency < 0.5 do
        [
          "Technical skills development",
          "Intelligence tools and software" | training_with_analytical
        ]
      else
        training_with_analytical
      end

    training_with_stealth =
      if intel_components.stealth_capability < 0.6 do
        ["Stealth and evasion techniques", "Surveillance detection" | training_with_technical]
      else
        training_with_technical
      end

    training_with_discretion =
      if intel_components.discretion_level < 0.7 do
        ["Confidentiality training", "Social engineering resistance" | training_with_stealth]
      else
        training_with_stealth
      end

    if Enum.empty?(training_with_discretion) do
      ["Advanced intelligence specialization"]
    else
      training_with_discretion
    end
  end

  defp recommend_clearance_level(score, intel_components) do
    # Recommend security clearance based on overall score and specific components
    base_clearance =
      cond do
        score >= 0.8 -> :top_secret
        score >= 0.7 -> :secret
        score >= 0.6 -> :confidential
        score >= 0.5 -> :restricted
        true -> :public
      end

    # Adjust based on OPSEC and discretion scores
    opsec_score =
      case intel_components.operational_security do
        %{overall_opsec_score: score} -> score
        score when is_number(score) -> score
        _ -> 0.5
      end

    opsec_adjustment =
      if opsec_score < 0.6 or intel_components.discretion_level < 0.6 do
        downgrade_clearance(base_clearance)
      else
        base_clearance
      end

    opsec_adjustment
  end

  # Helper functions

  defp assess_social_engineering_resistance(behavioral_patterns) do
    # Assess resistance to social engineering attacks
    Map.get(behavioral_patterns, :social_engineering_resistance, 0.5)
  end

  defp assess_technical_aptitude(comprehensive_score) do
    # Assess technical learning and adaptation capability
    # This would be enhanced with actual technical assessment data
    comprehensive_score.component_scores.tactical_intelligence * 0.8
  end

  defp generate_opsec_recommendations(opsec_components) do
    initial_recommendations = []

    recommendations_with_behavior =
      if opsec_components.behavioral_consistency < 0.6 do
        ["Improve behavioral pattern consistency" | initial_recommendations]
      else
        initial_recommendations
      end

    recommendations_with_discipline =
      if opsec_components.information_discipline < 0.7 do
        ["Enhance information sharing discipline" | recommendations_with_behavior]
      else
        recommendations_with_behavior
      end

    recommendations_with_masking =
      if opsec_components.pattern_masking < 0.6 do
        ["Develop pattern masking techniques" | recommendations_with_discipline]
      else
        recommendations_with_discipline
      end

    recommendations_with_comms =
      if opsec_components.communication_security < 0.7 do
        ["Improve communication security practices" | recommendations_with_masking]
      else
        recommendations_with_masking
      end

    if Enum.empty?(recommendations_with_comms) do
      ["OPSEC practices are satisfactory"]
    else
      recommendations_with_comms
    end
  end

  defp assess_opsec_risks(opsec_components) do
    initial_risks = []

    risks_with_behavior =
      if opsec_components.behavioral_consistency < 0.5 do
        ["Predictable behavioral patterns" | initial_risks]
      else
        initial_risks
      end

    risks_with_discipline =
      if opsec_components.information_discipline < 0.5 do
        ["Information leakage risk" | risks_with_behavior]
      else
        risks_with_behavior
      end

    risks_with_comms =
      if opsec_components.communication_security < 0.6 do
        ["Communication intercept vulnerability" | risks_with_discipline]
      else
        risks_with_discipline
      end

    if Enum.empty?(risks_with_comms) do
      ["Low OPSEC risk profile"]
    else
      risks_with_comms
    end
  end

  defp generate_specialization_suggestions(intel_components) do
    # Suggest specialization based on strongest components
    sorted_components =
      Enum.take(Enum.sort_by(intel_components, fn {_component, score} -> score end, :desc), 2)

    specializations =
      Enum.map(sorted_components, fn {component, _score} ->
        case component do
          :stealth_capability -> "Stealth operations specialist"
          :information_gathering -> "Information collection specialist"
          :operational_security -> "OPSEC specialist"
          :analytical_thinking -> "Intelligence analyst specialist"
          :discretion_level -> "Confidential operations specialist"
          :technical_competency -> "Technical intelligence specialist"
        end
      end)

    specializations
  end

  defp identify_development_priorities(intel_components) do
    # Identify areas for improvement based on lowest scores
    sorted_components =
      Enum.take(Enum.sort_by(intel_components, fn {_component, score} -> score end, :asc), 2)

    priorities =
      Enum.map(sorted_components, fn {component, _score} ->
        case component do
          :stealth_capability -> "Develop stealth and evasion skills"
          :information_gathering -> "Enhance information collection techniques"
          :operational_security -> "Strengthen OPSEC practices"
          :analytical_thinking -> "Improve analytical and reasoning skills"
          :discretion_level -> "Develop confidentiality and discretion"
          :technical_competency -> "Build technical competencies"
        end
      end)

    priorities
  end

  defp downgrade_clearance(clearance) do
    case clearance do
      :top_secret -> :secret
      :secret -> :confidential
      :confidential -> :restricted
      :restricted -> :public
      :public -> :public
    end
  end

  # Placeholder for comprehensive score calculation
  defp calculate_comprehensive_score(_character_id) do
    # This would normally delegate to the main IntelligenceScoring module
    {:ok,
     %{
       overall_score: 0.75,
       component_scores: %{
         combat_competency: 0.7,
         tactical_intelligence: 0.8,
         security_risk: 0.75,
         behavioral_stability: 0.7,
         operational_value: 0.8,
         intelligence_reliability: 0.75
       }
     }}
  end
end
