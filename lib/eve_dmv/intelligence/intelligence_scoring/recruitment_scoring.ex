defmodule EveDmv.Intelligence.IntelligenceScoring.RecruitmentScoring do
  @moduledoc """
  Recruitment fitness evaluation and scoring module.

  Handles assessment of candidate suitability for corporation recruitment,
  including skill fit, cultural alignment, security clearance, and growth potential.
  """

  require Logger

  @doc """
  Calculate recruitment fitness score for a character.

  Evaluates suitability for recruitment into a corporation based on
  comprehensive scoring and corporation-specific requirements.
  """
  def calculate_recruitment_fitness(
        character_id,
        comprehensive_score,
        corporation_requirements \\ %{}
      ) do
    Logger.info("Calculating recruitment fitness score for character #{character_id}")

    case get_vetting_data(character_id) do
      {:ok, vetting_data} ->
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

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Evaluate comprehensive score against corporation requirements.
  """
  def evaluate_corporation_requirements(comprehensive_score, requirements) do
    # Define requirement evaluation criteria
    requirement_checks = %{
      minimum_combat_score: check_minimum_combat_requirement(comprehensive_score, requirements),
      security_clearance: check_security_clearance_requirement(comprehensive_score, requirements),
      activity_level: check_activity_requirement(comprehensive_score, requirements),
      tactical_competency: check_tactical_requirement(comprehensive_score, requirements),
      behavioral_stability: check_behavioral_requirement(comprehensive_score, requirements)
    }

    # Calculate overall requirement satisfaction
    satisfied_requirements =
      requirement_checks
      |> Map.values()
      |> Enum.count(& &1.meets_requirement)

    total_requirements = map_size(requirement_checks)

    %{
      individual_checks: requirement_checks,
      satisfaction_rate: satisfied_requirements / total_requirements,
      overall_meets_requirements: satisfied_requirements == total_requirements
    }
  end

  @doc """
  Generate detailed recruitment recommendation.
  """
  def generate_recruitment_recommendation(score, components) do
    recommendation_base = determine_base_recommendation(score)
    specific_notes = generate_specific_recommendations(components)
    risk_assessment = assess_recruitment_risks(components)
    integration_plan = suggest_integration_approach(components)

    %{
      overall_recommendation: recommendation_base,
      confidence_level: calculate_recommendation_confidence(score, components),
      specific_notes: specific_notes,
      risk_assessment: risk_assessment,
      integration_plan: integration_plan,
      timeline_recommendation: suggest_recruitment_timeline(components)
    }
  end

  # Core fitness calculations

  defp calculate_skill_fitness(comprehensive_score) do
    # Assess technical and combat skill alignment
    combat_score = comprehensive_score.component_scores.combat_competency
    tactical_score = comprehensive_score.component_scores.tactical_intelligence

    (combat_score + tactical_score) / 2.0
  end

  defp calculate_cultural_fitness(comprehensive_score, vetting_data) do
    # Assess cultural alignment and social compatibility
    behavioral_score = comprehensive_score.component_scores.behavioral_stability
    social_indicators = Map.get(vetting_data, :social_compatibility, 0.5)
    communication_style = Map.get(vetting_data, :communication_style_fit, 0.5)

    (behavioral_score + social_indicators + communication_style) / 3.0
  end

  defp calculate_security_fitness(comprehensive_score) do
    # Assess security clearance and trustworthiness
    security_score = comprehensive_score.component_scores.security_risk
    reliability_score = comprehensive_score.component_scores.intelligence_reliability

    (security_score + reliability_score) / 2.0
  end

  defp calculate_operational_fitness(comprehensive_score, requirements) do
    # Assess operational capability alignment
    operational_score = comprehensive_score.component_scores.operational_value
    role_alignment = assess_role_alignment(comprehensive_score, requirements)

    (operational_score + role_alignment) / 2.0
  end

  defp calculate_growth_potential(comprehensive_score, vetting_data) do
    # Assess potential for development and growth
    base_scores = comprehensive_score.component_scores
    experience_level = Map.get(vetting_data, :experience_level, 0.5)
    learning_indicators = Map.get(vetting_data, :learning_aptitude, 0.5)

    # Higher potential for candidates with room to grow
    growth_ceiling = 1.0 - Enum.sum(Map.values(base_scores)) / map_size(base_scores)
    development_capacity = (experience_level + learning_indicators) / 2.0

    (growth_ceiling + development_capacity) / 2.0
  end

  defp calculate_recruitment_score(fitness_components) do
    # Weight different fitness components
    weights = %{
      skill_fit: 0.25,
      cultural_fit: 0.20,
      security_fit: 0.20,
      operational_fit: 0.20,
      growth_potential: 0.15
    }

    weighted_score =
      Enum.reduce(fitness_components, 0.0, fn {component, score}, acc ->
        weight = Map.get(weights, component, 0.0)
        acc + score * weight
      end)

    Float.round(weighted_score, 3)
  end

  # Requirement checking functions

  defp check_minimum_combat_requirement(comprehensive_score, requirements) do
    minimum_required = Map.get(requirements, :minimum_combat_score, 0.6)
    actual_score = comprehensive_score.component_scores.combat_competency

    %{
      requirement: "Minimum combat competency",
      required_score: minimum_required,
      actual_score: actual_score,
      meets_requirement: actual_score >= minimum_required,
      gap: max(0, minimum_required - actual_score)
    }
  end

  defp check_security_clearance_requirement(comprehensive_score, requirements) do
    minimum_security = Map.get(requirements, :minimum_security_clearance, 0.7)
    actual_security = comprehensive_score.component_scores.security_risk

    %{
      requirement: "Security clearance level",
      required_score: minimum_security,
      actual_score: actual_security,
      meets_requirement: actual_security >= minimum_security,
      gap: max(0, minimum_security - actual_security)
    }
  end

  defp check_activity_requirement(comprehensive_score, requirements) do
    minimum_activity = Map.get(requirements, :minimum_activity_level, 0.5)
    # Extract activity from operational value component
    actual_activity = comprehensive_score.component_scores.operational_value

    %{
      requirement: "Activity level",
      required_score: minimum_activity,
      actual_score: actual_activity,
      meets_requirement: actual_activity >= minimum_activity,
      gap: max(0, minimum_activity - actual_activity)
    }
  end

  defp check_tactical_requirement(comprehensive_score, requirements) do
    minimum_tactical = Map.get(requirements, :minimum_tactical_score, 0.6)
    actual_tactical = comprehensive_score.component_scores.tactical_intelligence

    %{
      requirement: "Tactical competency",
      required_score: minimum_tactical,
      actual_score: actual_tactical,
      meets_requirement: actual_tactical >= minimum_tactical,
      gap: max(0, minimum_tactical - actual_tactical)
    }
  end

  defp check_behavioral_requirement(comprehensive_score, requirements) do
    minimum_stability = Map.get(requirements, :minimum_behavioral_stability, 0.6)
    actual_stability = comprehensive_score.component_scores.behavioral_stability

    %{
      requirement: "Behavioral stability",
      required_score: minimum_stability,
      actual_score: actual_stability,
      meets_requirement: actual_stability >= minimum_stability,
      gap: max(0, minimum_stability - actual_stability)
    }
  end

  # Helper functions

  defp get_vetting_data(_character_id) do
    # This would typically fetch from a vetting system or database
    # For now, return mock data
    {:ok,
     %{
       social_compatibility: 0.7,
       communication_style_fit: 0.6,
       experience_level: 0.5,
       learning_aptitude: 0.8,
       background_check: :passed,
       references: :positive
     }}
  end

  defp assess_role_alignment(comprehensive_score, requirements) do
    # Assess how well the candidate fits the desired role
    preferred_roles = Map.get(requirements, :preferred_roles, [])
    candidate_strengths = identify_candidate_strengths(comprehensive_score)

    # Calculate alignment based on role overlap
    if Enum.empty?(preferred_roles) do
      # Default score if no specific roles defined
      0.7
    else
      role_match_score = calculate_role_match(candidate_strengths, preferred_roles)
      min(role_match_score, 1.0)
    end
  end

  defp identify_candidate_strengths(comprehensive_score) do
    component_scores = comprehensive_score.component_scores

    # Identify top 2 strengths
    component_scores
    |> Enum.sort_by(fn {_component, score} -> score end, :desc)
    |> Enum.take(2)
    |> Enum.map(fn {component, _score} -> component end)
  end

  defp calculate_role_match(candidate_strengths, preferred_roles) do
    # Simple overlap calculation - could be enhanced with role mapping
    role_keywords = extract_role_keywords(preferred_roles)
    strength_keywords = extract_strength_keywords(candidate_strengths)

    overlap_count =
      length(MapSet.intersection(MapSet.new(role_keywords), MapSet.new(strength_keywords)))

    total_keywords = length(role_keywords)

    if total_keywords > 0 do
      overlap_count / total_keywords
    else
      0.5
    end
  end

  defp extract_role_keywords(roles) do
    # Map roles to relevant keywords
    role_mappings = %{
      "combat" => ["combat_competency", "tactical_intelligence"],
      "logistics" => ["operational_value", "reliability"],
      "intelligence" => ["tactical_intelligence", "behavioral_stability"],
      "leadership" => ["operational_value", "tactical_intelligence"]
    }

    roles
    |> Enum.flat_map(fn role -> Map.get(role_mappings, role, []) end)
    |> Enum.uniq()
  end

  defp extract_strength_keywords(strengths) do
    Enum.map(strengths, &Atom.to_string/1)
  end

  # Recommendation generation functions

  defp determine_base_recommendation(score) do
    cond do
      score >= 0.8 -> :strongly_recommend
      score >= 0.7 -> :recommend
      score >= 0.6 -> :conditional_recommend
      score >= 0.5 -> :further_evaluation
      true -> :not_recommended
    end
  end

  defp generate_specific_recommendations(components) do
    initial_recommendations =
      if components.security_fit < 0.6 do
        ["Enhanced security vetting required"]
      else
        []
      end

    recommendations_with_culture =
      if components.cultural_fit < 0.5 do
        ["Cultural integration support recommended" | initial_recommendations]
      else
        initial_recommendations
      end

    recommendations_with_skills =
      if components.skill_fit < 0.7 do
        ["Skills development program recommended" | recommendations_with_culture]
      else
        recommendations_with_culture
      end

    recommendations_with_skills
  end

  defp assess_recruitment_risks(components) do
    # Default to stable
    behavioral_stability = Map.get(components, :behavioral_stability, 0.7)

    initial_risks =
      if behavioral_stability < 0.6 do
        ["Behavioral unpredictability risk"]
      else
        []
      end

    risks_with_security =
      if components.security_fit < 0.7 do
        ["Security risk concerns" | initial_risks]
      else
        initial_risks
      end

    risks_with_security
  end

  defp suggest_integration_approach(components) do
    if components.cultural_fit < 0.6 do
      "Mentorship program with cultural integration focus"
    else
      "Standard integration process"
    end
  end

  defp calculate_recommendation_confidence(score, components) do
    # Higher confidence for candidates with consistent scores across components
    component_values = Map.values(components)
    score_variance = calculate_variance(component_values)

    # Lower variance and higher overall score = higher confidence
    base_confidence = score
    variance_adjustment = 1.0 - score_variance

    min((base_confidence + variance_adjustment) / 2.0, 1.0)
  end

  defp suggest_recruitment_timeline(components) do
    average_score = components |> Map.values() |> Enum.sum() |> Kernel./(map_size(components))

    cond do
      average_score >= 0.8 -> "Immediate recruitment recommended"
      average_score >= 0.6 -> "Standard recruitment process (2-4 weeks)"
      true -> "Extended evaluation period (4-8 weeks)"
    end
  end

  defp calculate_variance(values) do
    mean = Enum.sum(values) / length(values)

    variance =
      values
      |> Enum.map(fn x -> :math.pow(x - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(length(values))

    :math.sqrt(variance)
  end

  defp identify_key_decision_factors(fitness_components) do
    # Sort components by score to identify strengths and weaknesses
    sorted_components =
      Enum.sort_by(fitness_components, fn {_component, score} -> score end, :desc)

    %{
      top_strengths: Enum.take(sorted_components, 2),
      key_concerns: Enum.take(sorted_components, -2)
    }
  end

  defp suggest_probation_terms(fitness_components) do
    average_score =
      fitness_components |> Map.values() |> Enum.sum() |> Kernel./(map_size(fitness_components))

    probation_duration =
      cond do
        average_score >= 0.8 -> "30 days"
        average_score >= 0.6 -> "60 days"
        true -> "90 days"
      end

    monitoring_focus =
      if fitness_components.security_fit < 0.7 do
        ["Security compliance", "Information handling"]
      else
        ["Performance metrics", "Cultural integration"]
      end

    %{
      duration: probation_duration,
      monitoring_focus: monitoring_focus,
      review_checkpoints: suggest_review_schedule(average_score)
    }
  end

  defp suggest_review_schedule(average_score) do
    if average_score >= 0.7 do
      ["30-day review", "Final evaluation"]
    else
      ["2-week check-in", "30-day review", "60-day evaluation", "Final assessment"]
    end
  end
end
