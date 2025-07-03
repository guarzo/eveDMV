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
    MemberActivityAnalyzer,
    WHVetting
  }

  alias EveDmv.Database.QueryCache

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

  defp bulk_analyze_character_correlations(character_ids) do
    # Use caching and bulk fetching to avoid N+1 queries
    character_ids
    |> Task.async_stream(
      fn char_id ->
        cache_key = "cross_module_correlation_#{char_id}"

        result =
          QueryCache.get_or_compute(
            cache_key,
            fn ->
              analyze_cross_module_correlations(char_id)
            end,
            # 15 minutes TTL
            900_000
          )

        case result do
          {:ok, data} -> {char_id, data}
          {:error, _} -> {char_id, nil}
        end
      end,
      max_concurrency: 10,
      timeout: 30_000
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, _} -> {nil, nil}
    end)
    |> Enum.filter(fn {_id, data} -> not is_nil(data) end)
    |> Enum.into(%{})
  end

  @doc """
  Find correlation patterns between multiple characters.

  Useful for identifying alt networks, shared associations, etc.
  """
  def analyze_character_correlations(character_ids) when is_list(character_ids) do
    Logger.info("Analyzing correlations between #{length(character_ids)} characters")

    # Optimize: Use bulk data fetching instead of individual calls
    character_data = bulk_analyze_character_correlations(character_ids)

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
    # Note: Currently get_corporation_members_from_activity always returns {:ok, []}
    # This is a placeholder implementation
    {:ok, members} = get_corporation_members_from_activity(corporation_id)

    if members == [] do
      {:error, "No recent activity found for corporation"}
    else
      {:ok, %{corporation_id: corporation_id, members: members, analysis: "not_implemented"}}
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
    # Get recent activity summary using proper function signature
    # Use 30 days ago as default period
    period_start = DateTime.utc_now() |> DateTime.add(-30 * 24 * 3600, :second)
    period_end = DateTime.utc_now()

    case MemberActivityAnalyzer.analyze_member_activity(character_id, period_start, period_end) do
      {:ok, activity_summary} -> {:ok, activity_summary}
      {:error, _reason} -> {:ok, nil}
    end
  rescue
    error ->
      Logger.warning("Failed to get activity data for #{character_id}: #{inspect(error)}")
      {:ok, nil}
  end

  defp get_fleet_data(_character_id) do
    # Fleet performance analysis not yet implemented
    # Return placeholder data structure
    {:ok,
     %{
       analysis_type: :fleet_performance,
       status: :not_implemented,
       message: "Fleet performance analysis coming soon"
     }}
  end

  defp correlate_threat_indicators(character_analysis, vetting_data) do
    threats =
      []
      |> add_dangerous_rating_threats(character_analysis, vetting_data)
      |> add_awox_probability_threats(character_analysis, vetting_data)

    %{
      threat_indicators: threats,
      # Normalize to 0-1
      correlation_strength: length(threats) / 5.0
    }
  end

  defp add_dangerous_rating_threats(threats, character_analysis, vetting_data) do
    if dangerous_rating_high?(character_analysis) do
      if vetting_confirms_security_risk?(vetting_data) do
        ["high_threat_confirmed_by_vetting" | threats]
      else
        ["high_threat_rating_unconfirmed" | threats]
      end
    else
      threats
    end
  end

  defp add_awox_probability_threats(threats, character_analysis, vetting_data) do
    if awox_probability_high?(character_analysis) do
      if vetting_confirms_awox_risk?(vetting_data) do
        ["awox_risk_confirmed" | threats]
      else
        threats
      end
    else
      threats
    end
  end

  defp dangerous_rating_high?(character_analysis) do
    is_map(character_analysis) && Map.get(character_analysis, :dangerous_rating, 0) > 7
  end

  defp vetting_confirms_security_risk?(vetting_data) do
    is_map(vetting_data) &&
      is_map(Map.get(vetting_data, :risk_factors)) &&
      length(get_in(vetting_data, [:risk_factors, "security_flags"]) || []) > 0
  end

  defp awox_probability_high?(character_analysis) do
    is_map(character_analysis) && Map.get(character_analysis, :awox_probability, 0) > 0.3
  end

  defp vetting_confirms_awox_risk?(vetting_data) do
    is_map(vetting_data) &&
      is_map(Map.get(vetting_data, :risk_factors)) &&
      "blue_killer" in (get_in(vetting_data, [:risk_factors, "behavioral_red_flags"]) || [])
  end

  defp correlate_competency_metrics(character_analysis, fleet_data, activity_data) do
    correlations =
      []
      |> maybe_add_activity_correlation(character_analysis, fleet_data, activity_data)
      |> maybe_add_ship_diversity_correlation(character_analysis, fleet_data)

    %{
      competency_correlations: correlations,
      overall_correlation: calculate_average_correlation(correlations)
    }
  end

  defp maybe_add_activity_correlation(correlations, character_analysis, fleet_data, activity_data)
       when is_map(character_analysis) and is_map(fleet_data) and is_map(activity_data) do
    activity_level = get_activity_level(activity_data)
    fleet_performance = get_fleet_performance_score(fleet_data)
    correlation = calculate_correlation_coefficient(activity_level, fleet_performance)

    [
      %{
        type: "activity_fleet_performance",
        correlation: correlation,
        strength: abs(correlation)
      }
      | correlations
    ]
  end

  defp maybe_add_activity_correlation(
         correlations,
         _character_analysis,
         _fleet_data,
         _activity_data
       ) do
    correlations
  end

  defp maybe_add_ship_diversity_correlation(correlations, character_analysis, fleet_data)
       when is_map(character_analysis) and is_map(fleet_data) do
    ship_usage = Map.get(character_analysis, :ship_usage, %{})
    ship_diversity = calculate_ship_diversity(ship_usage)
    combat_effectiveness = get_combat_effectiveness(character_analysis)
    correlation = calculate_correlation_coefficient(ship_diversity, combat_effectiveness)

    [
      %{
        type: "ship_diversity_effectiveness",
        correlation: correlation,
        strength: abs(correlation)
      }
      | correlations
    ]
  end

  defp maybe_add_ship_diversity_correlation(correlations, _character_analysis, _fleet_data) do
    correlations
  end

  defp correlate_behavioral_patterns(vetting_data, activity_data) do
    patterns =
      []
      |> maybe_add_corp_hopping_pattern(vetting_data, activity_data)
      |> maybe_add_j_space_pattern(vetting_data, activity_data)

    %{
      behavioral_patterns: patterns,
      consistency_score: calculate_behavioral_consistency(patterns)
    }
  end

  defp maybe_add_corp_hopping_pattern(patterns, vetting_data, activity_data)
       when is_map(vetting_data) and is_map(activity_data) do
    risk_factors = Map.get(vetting_data, :risk_factors, %{})
    security_flags = Map.get(risk_factors, "security_flags", [])

    if "rapid_corp_changes" in security_flags do
      ["corp_hopping_confirmed" | patterns]
    else
      patterns
    end
  end

  defp maybe_add_corp_hopping_pattern(patterns, _vetting_data, _activity_data), do: patterns

  defp maybe_add_j_space_pattern(patterns, vetting_data, activity_data)
       when is_map(vetting_data) and is_map(activity_data) do
    j_space_activity = get_j_space_activity_level(activity_data)
    has_j_space = Map.get(vetting_data, :j_space_activity, false)

    if j_space_activity > 0.5 and has_j_space do
      ["j_space_activity_correlation" | patterns]
    else
      patterns
    end
  end

  defp maybe_add_j_space_pattern(patterns, _vetting_data, _activity_data), do: patterns

  defp correlate_skill_progression(character_analysis, fleet_data)
       when is_map(character_analysis) and is_map(fleet_data) do
    # Currently fleet_data always has status: :not_implemented
    # This is a placeholder for future implementation
    %{
      skill_ship_consistency: 0.5,
      progression_flags: []
    }
  end

  defp correlate_skill_progression(_character_analysis, _fleet_data) do
    %{
      skill_ship_consistency: 0.5,
      progression_flags: []
    }
  end

  defp correlate_social_connections(character_analysis, vetting_data, _activity_data) do
    connections = []

    connections =
      if is_map(vetting_data),
        do: maybe_add_alts_connection(connections, vetting_data),
        else: connections

    connections =
      if is_map(character_analysis),
        do: maybe_add_associates_connection(connections, character_analysis),
        else: connections

    %{
      social_connections: connections,
      connectivity_score: calculate_connectivity_score(connections)
    }
  end

  defp maybe_add_alts_connection(connections, vetting_data) when is_map(vetting_data) do
    case Map.get(vetting_data, :alt_analysis) do
      %{} = alt_analysis ->
        potential_alts = alt_analysis["potential_alts"] || []

        if length(potential_alts) > 0 do
          ["potential_alts_detected" | connections]
        else
          connections
        end

      _ ->
        connections
    end
  end

  defp maybe_add_alts_connection(connections, _vetting_data), do: connections

  defp maybe_add_associates_connection(connections, character_analysis)
       when is_map(character_analysis) do
    case Map.get(character_analysis, :associate_characters) do
      associates when is_list(associates) ->
        if length(associates) > 10 do
          ["high_social_connectivity" | connections]
        else
          connections
        end

      _ ->
        connections
    end
  end

  defp maybe_add_associates_connection(connections, _character_analysis), do: connections

  defp correlate_risk_factors(character_analysis, vetting_data, _activity_data) do
    # Combine risk indicators from all modules
    char_risk =
      if is_map(character_analysis),
        do: Map.get(character_analysis, :dangerous_rating, 0),
        else: 0

    vet_risk = if is_map(vetting_data), do: Map.get(vetting_data, :overall_risk_score, 0), else: 0
    combined_risk_score = char_risk + vet_risk

    # Detect contradictory risk indicators
    risk_factors =
      []
      |> maybe_add_contradictory_risk(character_analysis, vetting_data)

    %{
      # Average of sources
      combined_risk_score: combined_risk_score / 2,
      risk_factors: risk_factors,
      risk_consistency: calculate_risk_consistency(character_analysis, vetting_data)
    }
  end

  defp maybe_add_contradictory_risk(risk_factors, character_analysis, vetting_data)
       when is_map(character_analysis) and is_map(vetting_data) do
    char_risk = Map.get(character_analysis, :dangerous_rating, 0)
    vet_risk = Map.get(vetting_data, :overall_risk_score, 0)

    if abs(char_risk - vet_risk) > 30 do
      ["contradictory_risk_indicators" | risk_factors]
    else
      risk_factors
    end
  end

  defp maybe_add_contradictory_risk(risk_factors, _character_analysis, _vetting_data),
    do: risk_factors

  defp generate_correlation_summary(correlations) do
    # Generate human-readable summary of correlations
    summary_points =
      []
      |> maybe_add_threat_summary(correlations.threat_assessment.threat_indicators)
      |> maybe_add_competency_summary(correlations.competency_correlation.overall_correlation)
      |> add_risk_summary(correlations.risk_factors.combined_risk_score)

    if Enum.empty?(summary_points) do
      "No significant cross-module correlations detected."
    else
      Enum.join(summary_points, ". ") <> "."
    end
  end

  defp maybe_add_threat_summary(summary_points, threat_indicators) do
    threat_count = length(threat_indicators)

    if threat_count > 0 do
      ["#{threat_count} threat indicators confirmed across modules" | summary_points]
    else
      summary_points
    end
  end

  defp maybe_add_competency_summary(summary_points, comp_correlation) do
    if comp_correlation > 0.7 do
      ["Strong competency correlation across analysis modules" | summary_points]
    else
      summary_points
    end
  end

  defp add_risk_summary(summary_points, combined_risk) do
    risk_message =
      cond do
        combined_risk > 70 -> "High combined risk score across all modules"
        combined_risk > 40 -> "Moderate combined risk identified"
        true -> "Low risk profile confirmed across modules"
      end

    [risk_message | summary_points]
  end

  defp calculate_correlation_confidence(correlations) do
    # Calculate overall confidence in correlation analysis
    confidence_factors = [
      # Factor in number of threat indicators
      min(1.0, length(correlations.threat_assessment.threat_indicators) / 3.0),
      # Factor in competency correlation strength
      correlations.competency_correlation.overall_correlation,
      # Factor in behavioral consistency
      correlations.behavioral_patterns.consistency_score,
      # Factor in risk consistency
      correlations.risk_factors.risk_consistency
    ]

    # Calculate weighted average
    if Enum.empty?(confidence_factors) do
      0.5
    else
      Enum.sum(confidence_factors) / length(confidence_factors)
    end
  end

  # Additional helper functions for specific correlation types

  defp find_temporal_correlations(_character_data) do
    # Find characters with similar activity timing patterns
    # Placeholder implementation
    []
  end

  defp find_geographic_correlations(_character_data) do
    # Find characters with overlapping system activity
    # Placeholder implementation
    []
  end

  defp find_behavioral_correlations(_character_data) do
    # Find characters with similar behavioral patterns
    # Placeholder implementation
    []
  end

  defp build_social_network(_character_data) do
    # Build social network graph from character associations
    # Placeholder implementation
    %{nodes: [], edges: []}
  end

  defp calculate_alt_likelihood(_character_data) do
    # Calculate likelihood that characters are alts of each other
    # Placeholder implementation
    0.0
  end

  defp get_corporation_members_from_activity(corporation_id) do
    # Get corporation members from recent activity data
    # This is a placeholder that should eventually query real data
    Logger.debug("Fetching corporation members for #{corporation_id}")
    # Always returns empty list for now
    {:ok, []}
  end

  # Utility functions for calculations

  defp get_activity_level(activity_data) when is_map(activity_data) do
    # Extract activity level from activity data
    # Placeholder calculation
    0.5
  end

  defp get_fleet_performance_score(fleet_data) when is_map(fleet_data) do
    # Extract fleet performance score
    # Currently all fleet data has status: :not_implemented
    # This is a placeholder for future implementation
    0.0
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

  defp get_combat_effectiveness(character_analysis) when is_map(character_analysis) do
    # Calculate combat effectiveness from character analysis
    kdr = Map.get(character_analysis, :kill_death_ratio)

    if kdr do
      min(1.0, kdr / 5.0)
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

  defp get_j_space_activity_level(_activity_data) do
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

  # defp analyze_ship_progression_consistency(_character_analysis, _fleet_data) do
  #   # Analyze if ship progression makes sense
  #   # Placeholder
  #   0.7
  # end
  #
  # defp detect_progression_anomalies(_character_analysis, _fleet_data) do
  #   # Detect anomalies in skill/ship progression
  #   # Placeholder
  #   []
  # end

  defp calculate_connectivity_score(connections) do
    # Calculate social connectivity score
    min(1.0, length(connections) / 5.0)
  end

  defp calculate_risk_consistency(character_analysis, vetting_data) do
    # Calculate consistency between risk assessments
    if is_map(character_analysis) && is_map(vetting_data) do
      char_risk = Map.get(character_analysis, :dangerous_rating, 0)
      vet_risk = Map.get(vetting_data, :overall_risk_score, 0)

      # Calculate consistency (lower difference = higher consistency)
      difference = abs(char_risk - vet_risk)
      max(0.0, 1.0 - difference / 100.0)
    else
      # Unknown consistency
      0.5
    end
  end
end
