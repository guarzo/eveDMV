defmodule EveDmv.Intelligence.IntelligenceScoring.BehavioralScoring do
  @moduledoc """
  Behavioral analysis and stability scoring module.

  Handles assessment of behavioral patterns, psychological stability,
  reliability metrics, and consistency analysis.
  """

  @doc """
  Calculate behavioral stability score based on behavioral analysis.
  """
  def calculate_behavioral_stability_score(behavioral_analysis) do
    # Assess behavioral predictability and stability
    stability_factors = [
      behavioral_analysis.confidence_score,
      calculate_anomaly_stability(behavioral_analysis),
      get_activity_consistency(behavioral_analysis)
    ]

    Enum.sum(stability_factors) / length(stability_factors)
  end

  @doc """
  Calculate reliability score combining stats and behavioral analysis.
  """
  def calculate_reliability_score(stats, behavioral_analysis) do
    # Assess reliability and trustworthiness
    reliability_factors = [
      behavioral_analysis.confidence_score,
      calculate_activity_consistency(stats),
      assess_commitment_level(stats)
    ]

    Enum.sum(reliability_factors) / length(reliability_factors)
  end

  @doc """
  Calculate security risk score from risk analysis.
  """
  def calculate_security_risk_score(risk_analysis) do
    # Invert risk score for positive scoring
    1.0 - risk_analysis.advanced_risk_score
  end

  @doc """
  Assess overall psychological profile for intelligence work.
  """
  def assess_psychological_profile(behavioral_analysis, stats) do
    %{
      stability: calculate_behavioral_stability_score(behavioral_analysis),
      reliability: calculate_reliability_score(stats, behavioral_analysis),
      predictability: assess_behavioral_predictability(behavioral_analysis),
      stress_tolerance: assess_stress_tolerance(behavioral_analysis),
      decision_consistency: assess_decision_consistency(behavioral_analysis),
      emotional_control: assess_emotional_control(behavioral_analysis)
    }
  end

  @doc """
  Generate behavioral recommendations for character development.
  """
  def generate_behavioral_recommendations(psychological_profile) do
    initial_recommendations =
      if psychological_profile.stability < 0.7 do
        ["Focus on establishing consistent behavioral patterns"]
      else
        []
      end

    recommendations_with_reliability =
      if psychological_profile.reliability < 0.6 do
        ["Improve activity consistency and commitment levels" | initial_recommendations]
      else
        initial_recommendations
      end

    recommendations_with_stress =
      if psychological_profile.stress_tolerance < 0.5 do
        [
          "Consider stress management training for high-pressure situations"
          | recommendations_with_reliability
        ]
      else
        recommendations_with_reliability
      end

    if Enum.empty?(recommendations_with_stress) do
      ["Behavioral profile shows strong psychological foundations"]
    else
      recommendations_with_stress
    end
  end

  # Behavioral analysis calculations

  defp calculate_anomaly_stability(behavioral_analysis) do
    # Lower anomaly count indicates higher stability
    anomaly_count =
      get_in(behavioral_analysis, [:patterns, :anomaly_detection, :anomaly_count]) || 0

    anomaly_stability = 1.0 - anomaly_count * 0.1
    max(anomaly_stability, 0.0)
  end

  defp get_activity_consistency(behavioral_analysis) do
    # Extract consistency score from behavioral patterns
    get_in(behavioral_analysis, [:patterns, :activity_rhythm, :consistency_score]) || 0.5
  end

  defp calculate_activity_consistency(stats) do
    # Assess consistency in activity patterns over time
    activity_variance = Map.get(stats, :activity_variance, 0.5)
    login_regularity = Map.get(stats, :login_regularity, 0.5)
    engagement_consistency = Map.get(stats, :engagement_consistency, 0.5)

    consistency_factors = [
      # Lower variance = higher consistency
      1.0 - activity_variance,
      login_regularity,
      engagement_consistency
    ]

    Enum.sum(consistency_factors) / length(consistency_factors)
  end

  defp assess_commitment_level(stats) do
    # Assess long-term commitment and dedication
    activity_duration = Map.get(stats, :activity_duration_months, 0)
    engagement_depth = Map.get(stats, :engagement_depth, 0.0)
    investment_level = Map.get(stats, :investment_level, 0.0)

    # Normalize commitment indicators
    # 12 months = full score
    duration_score = min(activity_duration / 12.0, 1.0)

    commitment_factors = [duration_score, engagement_depth, investment_level]
    Enum.sum(commitment_factors) / length(commitment_factors)
  end

  # Psychological assessment functions

  defp assess_behavioral_predictability(behavioral_analysis) do
    # Assess how predictable the character's behavior is
    pattern_strength = Map.get(behavioral_analysis, :pattern_strength, 0.5)
    routine_adherence = Map.get(behavioral_analysis, :routine_adherence, 0.5)

    (pattern_strength + routine_adherence) / 2.0
  end

  defp assess_stress_tolerance(behavioral_analysis) do
    # Assess ability to perform under pressure
    stress_indicators = Map.get(behavioral_analysis, :stress_indicators, %{})
    performance_degradation = Map.get(stress_indicators, :performance_degradation, 0.3)

    # Higher degradation = lower tolerance
    1.0 - performance_degradation
  end

  defp assess_decision_consistency(behavioral_analysis) do
    # Assess consistency in decision-making patterns
    decision_patterns = Map.get(behavioral_analysis, :decision_patterns, %{})
    consistency_score = Map.get(decision_patterns, :consistency, 0.5)

    consistency_score
  end

  defp assess_emotional_control(behavioral_analysis) do
    # Assess emotional stability and control
    emotional_indicators = Map.get(behavioral_analysis, :emotional_indicators, %{})
    stability_score = Map.get(emotional_indicators, :stability, 0.5)
    volatility = Map.get(emotional_indicators, :volatility, 0.3)

    # Combine stability (positive) and volatility (negative)
    emotional_control = (stability_score + (1.0 - volatility)) / 2.0
    max(emotional_control, 0.0)
  end

  @doc """
  Assess OPSEC (Operational Security) discipline.
  """
  def assess_opsec_discipline(behavioral_analysis) do
    # Assess operational security awareness and discipline
    opsec_indicators = Map.get(behavioral_analysis, :opsec_indicators, %{})

    %{
      information_sharing: Map.get(opsec_indicators, :information_sharing_discipline, 0.5),
      pattern_masking: Map.get(opsec_indicators, :pattern_masking_ability, 0.5),
      communication_security: Map.get(opsec_indicators, :secure_communication_usage, 0.5),
      identity_protection: Map.get(opsec_indicators, :identity_protection_practices, 0.5)
    }
  end

  @doc """
  Assess discretion and confidentiality capability.
  """
  def assess_discretion_level(behavioral_patterns) do
    # Assess ability to maintain confidentiality and exercise discretion
    discretion_indicators = [
      Map.get(behavioral_patterns, :information_discipline, 0.5),
      Map.get(behavioral_patterns, :communication_restraint, 0.5),
      Map.get(behavioral_patterns, :confidentiality_adherence, 0.5)
    ]

    Enum.sum(discretion_indicators) / length(discretion_indicators)
  end

  @doc """
  Assess analytical thinking capability.
  """
  def assess_analytical_capability(behavioral_patterns) do
    # Assess analytical thinking and problem-solving abilities
    analytical_indicators = [
      Map.get(behavioral_patterns, :pattern_recognition, 0.5),
      Map.get(behavioral_patterns, :logical_reasoning, 0.5),
      Map.get(behavioral_patterns, :strategic_thinking, 0.5),
      Map.get(behavioral_patterns, :detail_orientation, 0.5)
    ]

    Enum.sum(analytical_indicators) / length(analytical_indicators)
  end
end
