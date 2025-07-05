defmodule EveDmv.Intelligence.IntelligenceScoring.CombatScoring do
  @moduledoc """
  Combat competency and tactical intelligence scoring module.

  Handles assessment of combat effectiveness, tactical decision-making,
  operational value, and combat-related intelligence metrics.
  """

  @doc """
  Calculate combat competency score based on character statistics.
  """
  def calculate_combat_competency_score(stats) do
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

  @doc """
  Calculate tactical intelligence score combining stats and behavioral analysis.
  """
  def calculate_tactical_intelligence_score(stats, behavioral_analysis) do
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

  @doc """
  Calculate operational value score for organization assessment.
  """
  def calculate_operational_value_score(stats, threat_assessment) do
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

  # Combat effectiveness calculations

  defp calculate_kill_efficiency(stats) do
    total_kills = Map.get(stats, :total_kills, 0)
    # Avoid division by zero
    total_losses = Map.get(stats, :total_losses, 1)

    # Sophisticated kill efficiency calculation
    base_efficiency = total_kills / (total_kills + total_losses)

    # Factor in solo kills and fleet participation
    solo_kills = Map.get(stats, :solo_kills, 0)
    solo_factor = if total_kills > 0, do: solo_kills / total_kills, else: 0

    # Weight solo kills higher as they indicate individual skill
    adjusted_efficiency = base_efficiency * (1 + solo_factor * 0.5)

    # Cap at 1.0
    min(adjusted_efficiency, 1.0)
  end

  defp calculate_experience_breadth(stats) do
    # Assess variety of combat experience
    ship_types = Map.get(stats, :unique_ship_types, [])
    system_types = Map.get(stats, :unique_system_types, [])
    engagement_types = Map.get(stats, :engagement_types, [])

    # Normalize breadth scores
    ship_breadth = min(length(ship_types) / 10.0, 1.0)
    system_breadth = min(length(system_types) / 20.0, 1.0)
    engagement_breadth = min(length(engagement_types) / 5.0, 1.0)

    (ship_breadth + system_breadth + engagement_breadth) / 3.0
  end

  defp calculate_survival_rate(stats) do
    total_engagements = Map.get(stats, :total_kills, 0) + Map.get(stats, :total_losses, 0)

    if total_engagements == 0 do
      0.5
    else
      survival_rate = Map.get(stats, :total_kills, 0) / total_engagements
      min(survival_rate, 1.0)
    end
  end

  defp calculate_engagement_frequency(stats) do
    # Assess activity level and engagement consistency
    recent_activity = Map.get(stats, :recent_activity_score, 0.5)
    activity_consistency = Map.get(stats, :activity_consistency, 0.5)

    (recent_activity + activity_consistency) / 2.0
  end

  # Tactical assessment functions

  defp assess_tactical_adaptability(stats) do
    # Analyze adaptability based on ship usage patterns and engagement variety
    ship_diversity = Map.get(stats, :ship_type_diversity, 0.5)
    tactical_variety = Map.get(stats, :tactical_variety, 0.5)

    # Bonus for pilots who adapt their ship choices to situations
    adaptability_indicators = [
      ship_diversity,
      tactical_variety,
      assess_situational_ship_choices(stats)
    ]

    Enum.sum(adaptability_indicators) / length(adaptability_indicators)
  end

  defp assess_decision_quality(stats) do
    # Assess quality of tactical decisions based on engagement outcomes
    efficiency = calculate_kill_efficiency(stats)
    survival = calculate_survival_rate(stats)
    target_selection = assess_target_selection_quality(stats)

    (efficiency + survival + target_selection) / 3.0
  end

  defp assess_situational_awareness(behavioral_analysis) do
    # Extract situational awareness indicators from behavioral patterns
    Map.get(behavioral_analysis, :situational_awareness_score, 0.5)
  end

  defp assess_leadership_potential(stats) do
    # Assess potential for fleet command and leadership roles
    fleet_participation = Map.get(stats, :fleet_participation_rate, 0.0)
    command_experience = Map.get(stats, :command_experience, 0.0)
    coordination_score = Map.get(stats, :coordination_score, 0.5)

    leadership_indicators = [fleet_participation, command_experience, coordination_score]
    Enum.sum(leadership_indicators) / length(leadership_indicators)
  end

  defp assess_operational_versatility(stats) do
    # Assess ability to fulfill different operational roles
    role_variety = Map.get(stats, :operational_roles, []) |> length() |> min(5) |> Kernel./(5)
    cross_training = Map.get(stats, :cross_training_score, 0.5)

    (role_variety + cross_training) / 2.0
  end

  # Helper assessment functions

  defp assess_situational_ship_choices(stats) do
    # Analyze if pilot chooses appropriate ships for different situations
    # This would be enhanced with actual engagement context analysis
    Map.get(stats, :situational_adaptation_score, 0.5)
  end

  defp assess_target_selection_quality(stats) do
    # Assess quality of target selection in engagements
    # Higher score for engaging appropriate targets vs. poor target selection
    target_appropriateness = Map.get(stats, :target_selection_score, 0.5)
    engagement_efficiency = Map.get(stats, :engagement_efficiency, 0.5)

    (target_appropriateness + engagement_efficiency) / 2.0
  end
end
