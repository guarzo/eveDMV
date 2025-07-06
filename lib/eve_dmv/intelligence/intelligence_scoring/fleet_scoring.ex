defmodule EveDmv.Intelligence.IntelligenceScoring.FleetScoring do
  @moduledoc """
  Fleet readiness and synergy analysis module.

  Handles assessment of fleet composition, command structure, tactical coherence,
  and multi-character collaboration effectiveness.
  """

  require Logger
  alias EveDmv.Intelligence.AdvancedAnalytics

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
      mapped_scores =
        Enum.map(character_ids, fn char_id ->
          case calculate_comprehensive_score(char_id) do
            {:ok, score} -> {char_id, score}
            {:error, _} -> {char_id, nil}
          end
        end)

      individual_scores = Enum.filter(mapped_scores, fn {_, score} -> not is_nil(score) end)

      if length(individual_scores) >= 2 do
        # Calculate fleet synergy
        case AdvancedAnalytics.advanced_character_correlation(character_ids) do
          {:ok, correlation_analysis} ->
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

          _ ->
            {:error, "Could not analyze character correlations"}
        end
      else
        {:error, "Insufficient valid character data for fleet analysis"}
      end
    end
  end

  @doc """
  Analyze fleet composition and role distribution.
  """
  def analyze_fleet_composition(individual_scores) do
    %{
      role_distribution: calculate_role_distribution(individual_scores),
      competency_balance: assess_competency_balance(individual_scores),
      experience_spread: assess_experience_spread(individual_scores),
      leadership_coverage: assess_leadership_coverage(individual_scores)
    }
  end

  @doc """
  Generate fleet optimization recommendations.
  """
  def generate_fleet_optimization_recommendations(fleet_metrics) do
    recommendations = []

    recommendations =
      if fleet_metrics.role_balance < 0.7 do
        ["Consider diversifying fleet roles for better balance" | recommendations]
      else
        recommendations
      end

    recommendations =
      if fleet_metrics.command_structure < 0.6 do
        ["Establish clearer command hierarchy and leadership roles" | recommendations]
      else
        recommendations
      end

    recommendations =
      if fleet_metrics.tactical_coherence < 0.7 do
        ["Improve tactical coordination through training exercises" | recommendations]
      else
        recommendations
      end

    recommendations =
      if fleet_metrics.synergy_factor < 0.6 do
        ["Focus on team building and communication protocols" | recommendations]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["Fleet composition and readiness are optimal"]
    else
      recommendations
    end
  end

  # Fleet scoring calculations

  defp calculate_fleet_individual_competency(individual_scores) do
    scores = Enum.map(individual_scores, fn {_id, score} -> score.overall_score end)
    Enum.sum(scores) / length(scores)
  end

  defp calculate_fleet_role_balance(individual_scores) do
    # Analyze role distribution and balance
    role_strengths = extract_role_strengths(individual_scores)
    role_coverage = assess_role_coverage(role_strengths)
    role_redundancy = assess_role_redundancy(role_strengths)

    # Balance score considers both coverage and appropriate redundancy
    (role_coverage + (1.0 - role_redundancy)) / 2.0
  end

  defp calculate_fleet_synergy(correlation_analysis) do
    correlation_analysis.overall_correlation_score
  end

  defp assess_fleet_command_structure(individual_scores) do
    # Assess leadership distribution and command potential
    leadership_scores = extract_leadership_scores(individual_scores)
    command_distribution = assess_command_distribution(leadership_scores)

    # Good command structure has clear leadership without too many chiefs
    # ~1 leader per 5 members
    optimal_leaders = max(1, div(length(individual_scores), 5))
    actual_leaders = count_potential_leaders(leadership_scores)

    leadership_balance = 1.0 - abs(actual_leaders - optimal_leaders) * 0.2

    (command_distribution + max(leadership_balance, 0.0)) / 2.0
  end

  defp assess_tactical_coherence(individual_scores) do
    # Assess how well the fleet can execute coordinated tactics
    tactical_scores = extract_tactical_scores(individual_scores)

    coherence_indicators = [
      assess_tactical_consistency(tactical_scores),
      assess_communication_capability(individual_scores),
      assess_coordination_potential(individual_scores)
    ]

    Enum.sum(coherence_indicators) / length(coherence_indicators)
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

  defp suggest_fleet_optimizations(fleet_metrics) do
    optimizations = []

    optimizations =
      if fleet_metrics.role_balance < 0.7 do
        ["Role diversification needed" | optimizations]
      else
        optimizations
      end

    optimizations =
      if fleet_metrics.command_structure < 0.6 do
        ["Leadership development required" | optimizations]
      else
        optimizations
      end

    optimizations =
      if fleet_metrics.tactical_coherence < 0.7 do
        ["Tactical coordination training" | optimizations]
      else
        optimizations
      end

    if Enum.empty?(optimizations) do
      ["Fleet optimization is well-balanced"]
    else
      optimizations
    end
  end

  # Role and composition analysis

  defp extract_role_strengths(individual_scores) do
    Enum.map(individual_scores, fn {char_id, score} ->
      component_scores = score.component_scores

      # Determine primary and secondary role strengths
      sorted_components =
        component_scores
        |> Enum.sort_by(fn {_component, score} -> score end, :desc)
        |> Enum.take(2)

      {char_id, sorted_components}
    end)
  end

  defp assess_role_coverage(role_strengths) do
    # Check if all major roles are covered
    required_roles = [
      :combat_competency,
      :tactical_intelligence,
      :operational_value,
      :behavioral_stability
    ]

    covered_roles =
      role_strengths
      |> Enum.flat_map(fn {_id, strengths} ->
        Enum.map(strengths, fn {role, _score} -> role end)
      end)
      |> Enum.uniq()

    coverage_ratio =
      length(MapSet.intersection(MapSet.new(required_roles), MapSet.new(covered_roles))) /
        length(required_roles)

    min(coverage_ratio, 1.0)
  end

  defp assess_role_redundancy(role_strengths) do
    # Assess if there's appropriate redundancy without over-specialization
    role_counts =
      role_strengths
      |> Enum.flat_map(fn {_id, strengths} ->
        Enum.map(strengths, fn {role, _score} -> role end)
      end)
      |> Enum.frequencies()

    total_assignments = Enum.sum(Map.values(role_counts))
    ideal_distribution = total_assignments / map_size(role_counts)

    # Calculate variance from ideal distribution
    variance =
      role_counts
      |> Map.values()
      |> Enum.map(fn count -> :math.pow(count - ideal_distribution, 2) end)
      |> Enum.sum()
      |> Kernel./(map_size(role_counts))

    # Normalize variance to 0-1 scale (lower variance = lower redundancy score)
    normalized_variance = min(variance / (ideal_distribution * ideal_distribution), 1.0)
    normalized_variance
  end

  defp extract_leadership_scores(individual_scores) do
    Enum.map(individual_scores, fn {char_id, score} ->
      # Extract leadership indicators from component scores
      leadership_score =
        (score.component_scores.tactical_intelligence +
           score.component_scores.operational_value +
           score.component_scores.behavioral_stability) / 3.0

      {char_id, leadership_score}
    end)
  end

  defp assess_command_distribution(leadership_scores) do
    # Assess if leadership potential is well distributed
    scores = Enum.map(leadership_scores, fn {_id, score} -> score end)
    avg_leadership = Enum.sum(scores) / length(scores)

    # Good distribution has reasonable average with not too much variance
    variance =
      scores
      |> Enum.map(fn score -> :math.pow(score - avg_leadership, 2) end)
      |> Enum.sum()
      |> Kernel./(length(scores))

    # Lower variance indicates better distribution
    max(0.0, 1.0 - variance)
  end

  defp count_potential_leaders(leadership_scores) do
    # Count characters with leadership potential (score > 0.7)
    leadership_scores
    |> Enum.count(fn {_id, score} -> score > 0.7 end)
  end

  defp extract_tactical_scores(individual_scores) do
    Enum.map(individual_scores, fn {_id, score} ->
      score.component_scores.tactical_intelligence
    end)
  end

  defp assess_tactical_consistency(tactical_scores) do
    # Assess consistency in tactical capability across the fleet
    if length(tactical_scores) < 2 do
      1.0
    else
      avg_tactical = Enum.sum(tactical_scores) / length(tactical_scores)

      variance =
        tactical_scores
        |> Enum.map(fn score -> :math.pow(score - avg_tactical, 2) end)
        |> Enum.sum()
        |> Kernel./(length(tactical_scores))

      # Lower variance = higher consistency
      max(0.0, 1.0 - variance * 2.0)
    end
  end

  defp assess_communication_capability(individual_scores) do
    # Assess fleet's communication and coordination capability
    communication_scores =
      Enum.map(individual_scores, fn {_id, score} ->
        # Use behavioral stability as proxy for communication reliability
        score.component_scores.behavioral_stability
      end)

    Enum.sum(communication_scores) / length(communication_scores)
  end

  defp assess_coordination_potential(individual_scores) do
    # Assess how well the fleet can coordinate complex operations
    coordination_indicators =
      Enum.map(individual_scores, fn {_id, score} ->
        # Combine tactical intelligence and operational value for coordination potential
        (score.component_scores.tactical_intelligence +
           score.component_scores.operational_value) / 2.0
      end)

    Enum.sum(coordination_indicators) / length(coordination_indicators)
  end

  defp calculate_role_distribution(individual_scores) do
    # Detailed analysis of role distribution within the fleet
    role_assignments = extract_role_strengths(individual_scores)

    %{
      primary_roles: extract_primary_roles(role_assignments),
      secondary_roles: extract_secondary_roles(role_assignments),
      role_gaps: identify_role_gaps(role_assignments),
      over_represented_roles: identify_over_representation(role_assignments)
    }
  end

  defp assess_competency_balance(individual_scores) do
    # Assess if competency levels are balanced across the fleet
    competency_scores = Enum.map(individual_scores, fn {_id, score} -> score.overall_score end)

    min_competency = Enum.min(competency_scores)
    max_competency = Enum.max(competency_scores)
    avg_competency = Enum.sum(competency_scores) / length(competency_scores)

    # Good balance has minimal gap between min and max, high average
    competency_range = max_competency - min_competency
    balance_score = 1.0 - competency_range * 0.5

    (max(balance_score, 0.0) + avg_competency) / 2.0
  end

  defp assess_experience_spread(individual_scores) do
    # Assess the spread of experience levels across the fleet
    # This would be enhanced with actual experience data
    # For now, use overall scores as proxy for experience
    competency_scores = Enum.map(individual_scores, fn {_id, score} -> score.overall_score end)

    # Good spread has mix of experience levels
    sorted_scores = Enum.sort(competency_scores)
    quartiles = calculate_quartiles(sorted_scores)

    # Assess if all quartiles are represented
    quartile_representation = assess_quartile_distribution(quartiles)
    quartile_representation
  end

  defp assess_leadership_coverage(individual_scores) do
    leadership_scores = extract_leadership_scores(individual_scores)
    strong_leaders = Enum.count(leadership_scores, fn {_id, score} -> score > 0.8 end)
    potential_leaders = Enum.count(leadership_scores, fn {_id, score} -> score > 0.6 end)

    fleet_size = length(individual_scores)
    # 1 strong leader per 8 members
    optimal_strong_leaders = max(1, div(fleet_size, 8))
    # 1 potential leader per 4 members
    optimal_potential_leaders = max(2, div(fleet_size, 4))

    strong_coverage = min(strong_leaders / optimal_strong_leaders, 1.0)
    potential_coverage = min(potential_leaders / optimal_potential_leaders, 1.0)

    (strong_coverage + potential_coverage) / 2.0
  end

  # Helper functions for comprehensive score calculation
  # These would normally be imported from the main module
  defp calculate_comprehensive_score(_character_id) do
    # This is a placeholder - in the actual implementation, this would delegate
    # to the main IntelligenceScoring module
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

  # Additional helper functions

  defp extract_primary_roles(role_assignments) do
    Enum.map(role_assignments, fn {char_id, strengths} ->
      {primary_role, _score} = List.first(strengths)
      {char_id, primary_role}
    end)
  end

  defp extract_secondary_roles(role_assignments) do
    Enum.map(role_assignments, fn {char_id, strengths} ->
      {secondary_role, _score} = List.last(strengths)
      {char_id, secondary_role}
    end)
  end

  defp identify_role_gaps(role_assignments) do
    # Identify roles that are underrepresented
    all_roles = [
      :combat_competency,
      :tactical_intelligence,
      :operational_value,
      :behavioral_stability,
      :security_risk,
      :intelligence_reliability
    ]

    represented_roles =
      role_assignments
      |> Enum.flat_map(fn {_id, strengths} ->
        Enum.map(strengths, fn {role, _score} -> role end)
      end)
      |> Enum.uniq()

    all_roles -- represented_roles
  end

  defp identify_over_representation(role_assignments) do
    # Identify roles that are over-represented
    role_counts =
      role_assignments
      |> Enum.flat_map(fn {_id, strengths} ->
        Enum.map(strengths, fn {role, _score} -> role end)
      end)
      |> Enum.frequencies()

    fleet_size = length(role_assignments)
    # More than 1/3 of fleet in same role
    threshold = max(1, div(fleet_size, 3))

    role_counts
    |> Enum.filter(fn {_role, count} -> count > threshold end)
    |> Enum.map(fn {role, _count} -> role end)
  end

  defp calculate_quartiles(sorted_scores) do
    length = length(sorted_scores)
    q1_index = div(length, 4)
    q2_index = div(length, 2)
    q3_index = div(length * 3, 4)

    %{
      q1: Enum.at(sorted_scores, q1_index),
      q2: Enum.at(sorted_scores, q2_index),
      q3: Enum.at(sorted_scores, q3_index)
    }
  end

  defp assess_quartile_distribution(quartiles) do
    # Assess if quartile distribution indicates good experience spread
    q_range = quartiles.q3 - quartiles.q1

    # Good spread has reasonable range between quartiles
    if q_range > 0.3 do
      # Good spread
      0.8
    else
      # Limited spread
      0.5
    end
  end
end
