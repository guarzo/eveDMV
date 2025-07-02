defmodule EveDmv.Intelligence.CorrelationEngine do
  @moduledoc """
  Cross-module intelligence correlation engine.

  Correlates data between different intelligence modules to provide
  comprehensive analysis and insights that aren't possible with
  individual module analysis alone.
  """

  require Logger

  alias EveDmv.Intelligence.{
    CharacterAnalyzer,
    CharacterStats,
    HomeDefenseAnalyzer,
    MemberActivityAnalyzer,
    WHFleetAnalyzer,
    WHVetting,
    WHVettingAnalyzer
  }

  alias EveDmv.Api

  @doc """
  Perform comprehensive cross-module correlation analysis for a character.

  Returns {:ok, correlation_data} or {:error, reason}
  """
  def analyze_cross_module_correlations(character_id) do
    Logger.info("Starting cross-module correlation analysis for character #{character_id}")

    with {:ok, character_analysis} <- get_character_analysis(character_id),
         {:ok, vetting_data} <- get_vetting_data(character_id),
         {:ok, activity_data} <- get_activity_data(character_id),
         {:ok, fleet_data} <- get_fleet_data(character_id) do
      # Perform correlation analysis
      correlations = %{
        threat_assessment: correlate_threat_indicators(character_analysis, vetting_data),
        competency_correlation:
          correlate_competency_metrics(character_analysis, fleet_data, activity_data),
        behavioral_patterns: correlate_behavioral_patterns(vetting_data, activity_data),
        skill_progression: correlate_skill_progression(character_analysis, fleet_data),
        social_connections:
          correlate_social_connections(character_analysis, vetting_data, activity_data),
        risk_factors: correlate_risk_factors(character_analysis, vetting_data, activity_data)
      }

      # Generate correlation summary
      summary = generate_correlation_summary(correlations)
      confidence_score = calculate_correlation_confidence(correlations)

      result = %{
        character_id: character_id,
        correlations: correlations,
        summary: summary,
        confidence_score: confidence_score,
        timestamp: DateTime.utc_now()
      }

      {:ok, result}
    else
      {:error, reason} ->
        Logger.error(
          "Cross-module correlation failed for character #{character_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Find correlation patterns between multiple characters.

  Useful for identifying alt networks, shared associations, etc.
  """
  def analyze_character_correlations(character_ids) when is_list(character_ids) do
    Logger.info("Analyzing correlations between #{length(character_ids)} characters")

    # Get analysis data for all characters
    character_data =
      character_ids
      |> Enum.map(fn char_id ->
        case analyze_cross_module_correlations(char_id) do
          {:ok, data} -> {char_id, data}
          {:error, _} -> {char_id, nil}
        end
      end)
      |> Enum.filter(fn {_id, data} -> not is_nil(data) end)
      |> Enum.into(%{})

    if map_size(character_data) < 2 do
      {:error, "Insufficient character data for correlation analysis"}
    else
      correlations = %{
        temporal_correlations: find_temporal_correlations(character_data),
        geographic_correlations: find_geographic_correlations(character_data),
        behavioral_correlations: find_behavioral_correlations(character_data),
        social_network: build_social_network(character_data),
        alt_likelihood: calculate_alt_likelihood(character_data)
      }

      {:ok, correlations}
    end
  end

  @doc """
  Correlate intelligence data with corporation-level patterns.
  """
  def analyze_corporation_intelligence_patterns(corporation_id) do
    Logger.info("Analyzing corporation intelligence patterns for corp #{corporation_id}")

    # Get all corporation members from recent activity
    case get_corporation_members_from_activity(corporation_id) do
      {:ok, member_ids} when length(member_ids) > 0 ->
        # Analyze patterns across corporation members
        member_analyses = get_bulk_character_analyses(member_ids)

        patterns = %{
          recruitment_patterns: analyze_recruitment_patterns(member_analyses),
          activity_coordination: analyze_activity_coordination(member_analyses),
          skill_distribution: analyze_corp_skill_distribution(member_analyses),
          risk_distribution: analyze_corp_risk_distribution(member_analyses),
          doctrine_adherence: analyze_doctrine_adherence(member_analyses)
        }

        {:ok, patterns}

      {:ok, []} ->
        {:error, "No recent activity found for corporation"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helper functions

  defp get_character_analysis(character_id) do
    case CharacterStats.get_by_character_id(character_id) do
      {:ok, [stats]} ->
        {:ok, stats}

      {:ok, []} ->
        # Try to generate fresh analysis
        case CharacterAnalyzer.analyze_character(character_id) do
          {:ok, stats} -> {:ok, stats}
          error -> error
        end

      error ->
        error
    end
  end

  defp get_vetting_data(character_id) do
    case WHVetting.get_by_character(character_id) do
      {:ok, [vetting]} -> {:ok, vetting}
      # No vetting data available
      {:ok, []} -> {:ok, nil}
      error -> error
    end
  end

  defp get_activity_data(character_id) do
    # Get recent activity summary
    activity_summary = MemberActivityAnalyzer.analyze_member_activity(character_id)
    {:ok, activity_summary}
  rescue
    error ->
      Logger.warning("Failed to get activity data for #{character_id}: #{inspect(error)}")
      {:ok, nil}
  end

  defp get_fleet_data(character_id) do
    # Get fleet performance data
    fleet_summary = WHFleetAnalyzer.analyze_pilot_performance(character_id)
    {:ok, fleet_summary}
  rescue
    error ->
      Logger.warning("Failed to get fleet data for #{character_id}: #{inspect(error)}")
      {:ok, nil}
  end

  defp correlate_threat_indicators(character_analysis, vetting_data) do
    threats = []

    # Correlate dangerous rating with vetting risk factors
    threats =
      if character_analysis && character_analysis.dangerous_rating > 7 do
        if vetting_data && length(vetting_data.risk_factors["security_flags"] || []) > 0 do
          ["high_threat_confirmed_by_vetting" | threats]
        else
          ["high_threat_rating_unconfirmed" | threats]
        end
      else
        threats
      end

    # Correlate awox probability with vetting behavioral flags
    threats =
      if character_analysis && character_analysis.awox_probability > 0.3 do
        if vetting_data &&
             "blue_killer" in (vetting_data.risk_factors["behavioral_red_flags"] || []) do
          ["awox_risk_confirmed" | threats]
        else
          threats
        end
      else
        threats
      end

    %{
      threat_indicators: threats,
      # Normalize to 0-1
      correlation_strength: length(threats) / 5.0
    }
  end

  defp correlate_competency_metrics(character_analysis, fleet_data, activity_data) do
    correlations = []

    # Correlate activity level with fleet performance
    if character_analysis && fleet_data && activity_data do
      activity_level = get_activity_level(activity_data)
      fleet_performance = get_fleet_performance_score(fleet_data)

      correlation = calculate_correlation_coefficient(activity_level, fleet_performance)

      correlations = [
        %{
          type: "activity_fleet_performance",
          correlation: correlation,
          strength: abs(correlation)
        }
        | correlations
      ]
    end

    # Correlate ship usage with combat effectiveness
    if character_analysis && fleet_data do
      ship_diversity = calculate_ship_diversity(character_analysis.ship_usage || %{})
      combat_effectiveness = get_combat_effectiveness(character_analysis)

      correlation = calculate_correlation_coefficient(ship_diversity, combat_effectiveness)

      correlations = [
        %{
          type: "ship_diversity_effectiveness",
          correlation: correlation,
          strength: abs(correlation)
        }
        | correlations
      ]
    end

    %{
      competency_correlations: correlations,
      overall_correlation: calculate_average_correlation(correlations)
    }
  end

  defp correlate_behavioral_patterns(vetting_data, activity_data) do
    patterns = []

    if vetting_data && activity_data do
      # Correlate corp hopping with activity patterns
      if "rapid_corp_changes" in (vetting_data.risk_factors["security_flags"] || []) do
        patterns = ["corp_hopping_confirmed" | patterns]
      end

      # Correlate scanning skills with J-space activity
      j_space_activity = get_j_space_activity_level(activity_data)

      if j_space_activity > 0.5 and vetting_data.j_space_activity do
        patterns = ["j_space_activity_correlation" | patterns]
      end
    end

    %{
      behavioral_patterns: patterns,
      consistency_score: calculate_behavioral_consistency(patterns)
    }
  end

  defp correlate_skill_progression(character_analysis, fleet_data) do
    if character_analysis && fleet_data do
      # Analyze if character's skill progression matches their ship usage
      ship_progression = analyze_ship_progression_consistency(character_analysis, fleet_data)

      %{
        skill_ship_consistency: ship_progression,
        progression_flags: detect_progression_anomalies(character_analysis, fleet_data)
      }
    else
      %{
        skill_ship_consistency: 0.5,
        progression_flags: []
      }
    end
  end

  defp correlate_social_connections(character_analysis, vetting_data, activity_data) do
    connections = []

    # Correlate potential alts with shared activity patterns
    if vetting_data && vetting_data.alt_analysis do
      potential_alts = vetting_data.alt_analysis["potential_alts"] || []

      if length(potential_alts) > 0 do
        connections = ["potential_alts_detected" | connections]
      end
    end

    # Correlate associates with corp membership patterns
    if character_analysis && character_analysis.associate_characters do
      associate_count = length(character_analysis.associate_characters)

      if associate_count > 10 do
        connections = ["high_social_connectivity" | connections]
      end
    end

    %{
      social_connections: connections,
      connectivity_score: calculate_connectivity_score(connections)
    }
  end

  defp correlate_risk_factors(character_analysis, vetting_data, activity_data) do
    risk_factors = []
    combined_risk_score = 0

    # Combine risk indicators from all modules
    if character_analysis do
      combined_risk_score = combined_risk_score + (character_analysis.dangerous_rating || 0)
    end

    if vetting_data do
      vetting_risk = vetting_data.overall_risk_score || 0
      combined_risk_score = combined_risk_score + vetting_risk
    end

    # Detect contradictory risk indicators
    if character_analysis && vetting_data do
      char_risk = character_analysis.dangerous_rating || 0
      vet_risk = vetting_data.overall_risk_score || 0

      if abs(char_risk - vet_risk) > 30 do
        risk_factors = ["contradictory_risk_indicators" | risk_factors]
      end
    end

    %{
      # Average of sources
      combined_risk_score: combined_risk_score / 2,
      risk_factors: risk_factors,
      risk_consistency: calculate_risk_consistency(character_analysis, vetting_data)
    }
  end

  defp generate_correlation_summary(correlations) do
    # Generate human-readable summary of correlations
    summary_points = []

    # Threat assessment summary
    threat_count = length(correlations.threat_assessment.threat_indicators)

    if threat_count > 0 do
      summary_points = [
        "#{threat_count} threat indicators confirmed across modules" | summary_points
      ]
    end

    # Competency correlation summary
    comp_correlation = correlations.competency_correlation.overall_correlation

    if comp_correlation > 0.7 do
      summary_points = ["Strong competency correlation across analysis modules" | summary_points]
    end

    # Risk factor summary
    combined_risk = correlations.risk_factors.combined_risk_score

    cond do
      combined_risk > 70 ->
        summary_points = ["High combined risk score across all modules" | summary_points]

      combined_risk > 40 ->
        summary_points = ["Moderate combined risk identified" | summary_points]

      true ->
        summary_points = ["Low risk profile confirmed across modules" | summary_points]
    end

    if Enum.empty?(summary_points) do
      "No significant cross-module correlations detected."
    else
      Enum.join(summary_points, ". ") <> "."
    end
  end

  defp calculate_correlation_confidence(correlations) do
    # Calculate overall confidence in correlation analysis
    confidence_factors = []

    # Factor in number of threat indicators
    threat_factor = min(1.0, length(correlations.threat_assessment.threat_indicators) / 3.0)
    confidence_factors = [threat_factor | confidence_factors]

    # Factor in competency correlation strength
    comp_factor = correlations.competency_correlation.overall_correlation
    confidence_factors = [comp_factor | confidence_factors]

    # Factor in behavioral consistency
    behavior_factor = correlations.behavioral_patterns.consistency_score
    confidence_factors = [behavior_factor | confidence_factors]

    # Factor in risk consistency
    risk_factor = correlations.risk_factors.risk_consistency
    confidence_factors = [risk_factor | confidence_factors]

    # Calculate weighted average
    if Enum.empty?(confidence_factors) do
      0.5
    else
      Enum.sum(confidence_factors) / length(confidence_factors)
    end
  end

  # Additional helper functions for specific correlation types

  defp find_temporal_correlations(character_data) do
    # Find characters with similar activity timing patterns
    # Placeholder implementation
    []
  end

  defp find_geographic_correlations(character_data) do
    # Find characters with overlapping system activity
    # Placeholder implementation
    []
  end

  defp find_behavioral_correlations(character_data) do
    # Find characters with similar behavioral patterns
    # Placeholder implementation
    []
  end

  defp build_social_network(character_data) do
    # Build social network graph from character associations
    # Placeholder implementation
    %{nodes: [], edges: []}
  end

  defp calculate_alt_likelihood(character_data) do
    # Calculate likelihood that characters are alts of each other
    # Placeholder implementation
    0.0
  end

  defp get_corporation_members_from_activity(corporation_id) do
    # Get corporation members from recent activity data
    # Placeholder implementation
    {:ok, []}
  end

  defp get_bulk_character_analyses(member_ids) do
    # Get character analyses for multiple members
    # Placeholder implementation
    []
  end

  defp analyze_recruitment_patterns(_member_analyses) do
    %{pattern_type: "unknown", confidence: 0.0}
  end

  defp analyze_activity_coordination(_member_analyses) do
    %{coordination_level: "low", evidence: []}
  end

  defp analyze_corp_skill_distribution(_member_analyses) do
    %{distribution_type: "normal", specializations: []}
  end

  defp analyze_corp_risk_distribution(_member_analyses) do
    %{risk_level: "medium", outliers: []}
  end

  defp analyze_doctrine_adherence(_member_analyses) do
    %{adherence_score: 0.5, deviations: []}
  end

  # Utility functions for calculations

  defp get_activity_level(activity_data) do
    # Extract activity level from activity data
    if activity_data do
      # Placeholder calculation
      0.5
    else
      0.0
    end
  end

  defp get_fleet_performance_score(fleet_data) do
    # Extract fleet performance score
    if fleet_data do
      # Placeholder calculation
      0.6
    else
      0.0
    end
  end

  defp calculate_correlation_coefficient(x, y) do
    # Simple correlation calculation (placeholder)
    abs(x - y)
  end

  defp calculate_ship_diversity(ship_usage) do
    # Calculate diversity of ship usage
    if map_size(ship_usage) > 0 do
      min(1.0, map_size(ship_usage) / 10.0)
    else
      0.0
    end
  end

  defp get_combat_effectiveness(character_analysis) do
    # Calculate combat effectiveness from character analysis
    if character_analysis.kill_death_ratio do
      min(1.0, character_analysis.kill_death_ratio / 5.0)
    else
      0.5
    end
  end

  defp calculate_average_correlation(correlations) do
    if Enum.empty?(correlations) do
      0.0
    else
      correlations
      |> Enum.map(& &1.strength)
      |> Enum.sum()
      |> Kernel./(length(correlations))
    end
  end

  defp get_j_space_activity_level(activity_data) do
    # Extract J-space activity level
    # Placeholder
    0.5
  end

  defp calculate_behavioral_consistency(patterns) do
    # Calculate consistency score from behavioral patterns
    if Enum.empty?(patterns) do
      # No contradictions
      1.0
    else
      # More patterns might indicate inconsistency
      max(0.0, 1.0 - length(patterns) / 10.0)
    end
  end

  defp analyze_ship_progression_consistency(character_analysis, fleet_data) do
    # Analyze if ship progression makes sense
    # Placeholder
    0.7
  end

  defp detect_progression_anomalies(character_analysis, fleet_data) do
    # Detect anomalies in skill/ship progression
    # Placeholder
    []
  end

  defp calculate_connectivity_score(connections) do
    # Calculate social connectivity score
    min(1.0, length(connections) / 5.0)
  end

  defp calculate_risk_consistency(character_analysis, vetting_data) do
    # Calculate consistency between risk assessments
    if character_analysis && vetting_data do
      char_risk = character_analysis.dangerous_rating || 0
      vet_risk = vetting_data.overall_risk_score || 0

      # Calculate consistency (lower difference = higher consistency)
      difference = abs(char_risk - vet_risk)
      max(0.0, 1.0 - difference / 100.0)
    else
      # Unknown consistency
      0.5
    end
  end
end
