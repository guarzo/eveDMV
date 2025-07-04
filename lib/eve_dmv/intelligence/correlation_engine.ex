defmodule EveDmv.Intelligence.CorrelationEngine do
  @moduledoc """
  Cross-module intelligence correlation engine.

  Correlates data between different intelligence modules to provide
  comprehensive analysis and insights that aren't possible with
  individual module analysis alone.
  """

  require Logger
  require Ash.Query

  alias EveDmv.Api
  alias EveDmv.Intelligence.MemberActivityAnalyzer

  alias EveDmv.Intelligence.{CharacterAnalyzer, CharacterStats}
  alias EveDmv.Intelligence.WhSpace.Vetting, as: WHVetting

  alias EveDmv.Database.{QueryCache, QueryUtils}

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

    case get_corporation_members_from_activity(corporation_id) do
      {:ok, []} ->
        {:error, "No recent activity found for corporation"}

      {:ok, members} ->
        perform_actual_corporation_analysis(members, corporation_id)
    end
  end

  # Private helper functions

  defp get_character_analysis(character_id) do
    case CharacterStats
         |> Ash.Query.new()
         |> Ash.Query.filter(character_id: character_id)
         |> Ash.Query.limit(1)
         |> Ash.read(domain: Api) do
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
    # Analyze skill progression consistency and detect anomalies
    progression_consistency = analyze_ship_progression_consistency(character_analysis, fleet_data)
    progression_anomalies = detect_progression_anomalies(character_analysis, fleet_data)
    doctrine_adherence = analyze_doctrine_adherence(character_analysis, fleet_data)

    %{
      skill_ship_consistency: progression_consistency,
      progression_flags: progression_anomalies,
      doctrine_adherence: doctrine_adherence
    }
  end

  defp correlate_skill_progression(_character_analysis, _fleet_data) do
    %{
      skill_ship_consistency: 0.5,
      progression_flags: [],
      doctrine_adherence: %{
        overall_adherence_score: 0.5,
        doctrine_scores: [],
        preferred_doctrines: [],
        doctrine_flexibility: 0.5
      }
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
    # Get corporation members from recent activity data using actual queries
    Logger.debug("Fetching corporation members for #{corporation_id}")

    # Query recent killmails to identify active corporation members
    end_date = DateTime.utc_now()
    # Last 30 days
    start_date = DateTime.add(end_date, -30 * 24 * 3600, :second)

    case QueryUtils.query_killmails_by_corporation(corporation_id, start_date, end_date) do
      {:ok, killmails} ->
        members = extract_unique_corporation_members(killmails, corporation_id)
        {:ok, members}

      {:error, reason} ->
        Logger.warning("Failed to fetch corporation activity: #{inspect(reason)}")
        # Return empty list instead of error to allow graceful degradation
        {:ok, []}
    end
  rescue
    error ->
      Logger.error("Error fetching corporation members: #{inspect(error)}")
      {:ok, []}
  end

  defp perform_actual_corporation_analysis(members, corporation_id) when is_list(members) do
    if Enum.empty?(members) do
      {:error, "No active members found for analysis"}
    else
      # Analyze member patterns, activity coordination, risk distribution
      member_correlations = analyze_member_correlations(members)
      activity_patterns = analyze_corporation_activity_patterns(members)
      risk_distribution = analyze_corporation_risk_distribution(members)
      coordination_analysis = analyze_member_coordination(members)

      analysis = %{
        corporation_id: corporation_id,
        member_count: length(members),
        member_correlations: member_correlations,
        activity_patterns: activity_patterns,
        risk_distribution: risk_distribution,
        coordination_analysis: coordination_analysis,
        analysis_timestamp: DateTime.utc_now(),
        confidence_score: calculate_analysis_confidence(members)
      }

      {:ok, analysis}
    end
  end

  defp extract_unique_corporation_members(killmails, corporation_id) do
    killmails
    |> Enum.flat_map(fn killmail ->
      (killmail.participants || [])
      |> Enum.filter(&(&1.corporation_id == corporation_id))
    end)
    |> Enum.group_by(& &1.character_id)
    |> Enum.map(fn {character_id, participations} ->
      first_participation = List.first(participations)

      %{
        character_id: character_id,
        character_name: first_participation.character_name || "Unknown",
        corporation_id: corporation_id,
        activity_count: length(participations),
        kills: Enum.count(participations, &(&1.is_victim == false)),
        losses: Enum.count(participations, &(&1.is_victim == true))
      }
    end)
    |> Enum.sort_by(& &1.activity_count, :desc)
  end

  defp analyze_member_correlations(members) do
    # Analyze patterns between members (similar ship usage, timing, etc.)
    high_activity_members = Enum.filter(members, &(&1.activity_count > 5))

    %{
      total_active_members: length(high_activity_members),
      activity_distribution: calculate_activity_distribution(members),
      potential_alt_networks: identify_potential_alt_networks(members),
      shared_operations: analyze_shared_operations(members)
    }
  end

  defp analyze_corporation_activity_patterns(members) do
    # Analyze when and how the corporation operates
    total_activity = Enum.sum(Enum.map(members, & &1.activity_count))
    avg_activity = if length(members) > 0, do: total_activity / length(members), else: 0

    %{
      total_corporation_activity: total_activity,
      average_member_activity: avg_activity,
      activity_concentration: calculate_activity_concentration(members),
      operational_style: determine_operational_style(members)
    }
  end

  defp analyze_corporation_risk_distribution(members) do
    # Analyze risk factors across the corporation
    total_losses = Enum.sum(Enum.map(members, & &1.losses))
    total_kills = Enum.sum(Enum.map(members, & &1.kills))

    %{
      corporation_kd_ratio:
        if(total_losses > 0, do: total_kills / total_losses, else: total_kills),
      high_risk_members: count_high_risk_members(members),
      loss_distribution: analyze_loss_distribution(members),
      risk_concentration: calculate_risk_concentration(members)
    }
  end

  defp analyze_member_coordination(members) do
    # Analyze how well members coordinate activities
    %{
      coordination_score: calculate_coordination_score(members),
      fleet_participation_rate: calculate_fleet_participation_rate(members),
      synchronized_activity: detect_synchronized_activity(members)
    }
  end

  # Helper functions for corporation analysis

  defp calculate_activity_distribution(members) do
    activity_counts = Enum.map(members, & &1.activity_count)

    %{
      min_activity: Enum.min(activity_counts, fn -> 0 end),
      max_activity: Enum.max(activity_counts, fn -> 0 end),
      median_activity: calculate_median(activity_counts),
      activity_variance: calculate_variance(activity_counts)
    }
  end

  defp identify_potential_alt_networks(members) do
    # Look for members with similar activity patterns that might be alts
    # This is a simplified heuristic-based approach
    suspicious_patterns =
      members
      |> Enum.filter(&(&1.activity_count > 0))
      |> Enum.group_by(& &1.activity_count)
      |> Enum.filter(fn {_count, member_list} -> length(member_list) > 1 end)
      |> Enum.map(fn {activity_count, member_list} ->
        %{
          activity_level: activity_count,
          potentially_linked_members: Enum.map(member_list, & &1.character_id),
          confidence: calculate_alt_confidence(member_list)
        }
      end)

    %{
      potential_networks: suspicious_patterns,
      network_count: length(suspicious_patterns)
    }
  end

  defp analyze_shared_operations(members) do
    # Analyze how often members participate in operations together
    active_members = Enum.filter(members, &(&1.activity_count > 2))

    %{
      active_member_count: length(active_members),
      estimated_fleet_operations: estimate_fleet_operations(active_members),
      coordination_indicators: detect_coordination_indicators(active_members)
    }
  end

  defp calculate_activity_concentration(members) do
    # Calculate how concentrated activity is among top performers
    sorted_members = Enum.sort_by(members, & &1.activity_count, :desc)
    total_activity = Enum.sum(Enum.map(members, & &1.activity_count))

    if total_activity > 0 and length(members) > 0 do
      top_20_percent = max(1, div(length(members), 5))

      top_activity =
        sorted_members
        |> Enum.take(top_20_percent)
        |> Enum.map(& &1.activity_count)
        |> Enum.sum()

      top_activity / total_activity
    else
      0.0
    end
  end

  defp determine_operational_style(members) do
    # Determine if corporation prefers large fleets, small gangs, or solo operations
    total_activity = Enum.sum(Enum.map(members, & &1.activity_count))
    active_member_count = Enum.count(members, &(&1.activity_count > 0))

    cond do
      active_member_count > 20 and total_activity / active_member_count > 5 ->
        :large_fleet_focused

      active_member_count in 5..20 and total_activity / active_member_count > 3 ->
        :small_gang_focused

      active_member_count < 5 ->
        :solo_focused

      true ->
        :mixed_operations
    end
  end

  defp count_high_risk_members(members) do
    # Members with poor K/D ratios might be higher risk
    Enum.count(members, fn member ->
      member.losses > member.kills and member.activity_count > 2
    end)
  end

  defp analyze_loss_distribution(members) do
    loss_counts = Enum.map(members, & &1.losses)
    total_losses = Enum.sum(loss_counts)

    %{
      total_losses: total_losses,
      average_losses_per_member:
        if(length(members) > 0, do: total_losses / length(members), else: 0),
      loss_concentration: calculate_loss_concentration(members, total_losses)
    }
  end

  defp calculate_risk_concentration(members) do
    # Calculate how risk is distributed across members
    loss_counts = Enum.map(members, & &1.losses)
    total_losses = Enum.sum(loss_counts)

    if total_losses > 0 do
      # Calculate Gini coefficient for loss distribution
      calculate_gini_coefficient(loss_counts)
    else
      0.0
    end
  end

  defp calculate_coordination_score(members) do
    # Simple heuristic: more active members with similar activity levels = better coordination
    if length(members) > 1 do
      activity_counts = Enum.map(members, & &1.activity_count)
      avg_activity = Enum.sum(activity_counts) / length(activity_counts)
      variance = calculate_variance(activity_counts)

      # Lower variance relative to mean indicates better coordination
      if avg_activity > 0 do
        max(0.0, 1.0 - variance / avg_activity)
      else
        0.0
      end
    else
      0.0
    end
  end

  defp calculate_fleet_participation_rate(members) do
    # Estimate fleet participation based on activity patterns
    active_members = Enum.count(members, &(&1.activity_count > 2))
    total_members = length(members)

    if total_members > 0 do
      active_members / total_members
    else
      0.0
    end
  end

  defp detect_synchronized_activity(members) do
    # Look for patterns that suggest coordinated activity
    high_activity_members = Enum.filter(members, &(&1.activity_count > 5))

    %{
      synchronized_members: length(high_activity_members),
      synchronization_score: calculate_synchronization_score(high_activity_members)
    }
  end

  # Utility calculation functions

  defp calculate_median(list) when is_list(list) and length(list) > 0 do
    sorted = Enum.sort(list)
    len = length(sorted)

    if rem(len, 2) == 0 do
      mid1 = Enum.at(sorted, div(len, 2) - 1)
      mid2 = Enum.at(sorted, div(len, 2))
      (mid1 + mid2) / 2
    else
      Enum.at(sorted, div(len, 2))
    end
  end

  defp calculate_median(_), do: 0

  defp calculate_variance(list) when is_list(list) and length(list) > 1 do
    mean = Enum.sum(list) / length(list)
    sum_squares = Enum.reduce(list, 0, fn x, acc -> acc + :math.pow(x - mean, 2) end)
    sum_squares / length(list)
  end

  defp calculate_variance(_), do: 0

  defp calculate_alt_confidence(member_list) do
    # Simple confidence based on identical activity patterns
    if length(member_list) > 1 do
      min(0.8, length(member_list) * 0.2)
    else
      0.0
    end
  end

  defp estimate_fleet_operations(active_members) do
    # Rough estimate of fleet operations based on member activity overlap
    total_activity = Enum.sum(Enum.map(active_members, & &1.activity_count))
    member_count = length(active_members)

    if member_count > 1 do
      # Assume some portion of activity is coordinated fleet ops
      div(total_activity, max(2, member_count))
    else
      0
    end
  end

  defp detect_coordination_indicators(active_members) do
    # Look for signs of coordination
    avg_activity =
      if length(active_members) > 0 do
        Enum.sum(Enum.map(active_members, & &1.activity_count)) / length(active_members)
      else
        0
      end

    %{
      consistent_activity_levels: avg_activity > 3,
      multiple_active_members: length(active_members) > 1,
      coordination_likelihood:
        if(avg_activity > 3 and length(active_members) > 1, do: :high, else: :low)
    }
  end

  defp calculate_loss_concentration(members, total_losses) do
    if total_losses > 0 and length(members) > 0 do
      # Calculate what percentage of losses come from top 20% of members by loss count
      sorted_by_losses = Enum.sort_by(members, & &1.losses, :desc)
      top_20_percent = max(1, div(length(members), 5))

      top_losses =
        sorted_by_losses
        |> Enum.take(top_20_percent)
        |> Enum.map(& &1.losses)
        |> Enum.sum()

      top_losses / total_losses
    else
      0.0
    end
  end

  defp calculate_gini_coefficient(values) do
    # Simplified Gini coefficient calculation
    sorted_values = Enum.sort(values)
    n = length(sorted_values)

    if n > 1 do
      sum_values = Enum.sum(sorted_values)

      if sum_values > 0 do
        numerator =
          sorted_values
          |> Enum.with_index()
          |> Enum.reduce(0, fn {value, index}, acc ->
            acc + (2 * (index + 1) - n - 1) * value
          end)

        numerator / (n * sum_values)
      else
        0.0
      end
    else
      0.0
    end
  end

  defp calculate_synchronization_score(high_activity_members) do
    # Score based on how similar activity levels are among high-activity members
    if length(high_activity_members) > 1 do
      activity_counts = Enum.map(high_activity_members, & &1.activity_count)
      variance = calculate_variance(activity_counts)
      mean = Enum.sum(activity_counts) / length(activity_counts)

      if mean > 0 do
        # Lower relative variance = higher synchronization
        max(0.0, 1.0 - variance / mean)
      else
        0.0
      end
    else
      0.0
    end
  end

  defp calculate_analysis_confidence(members) do
    # Calculate confidence in the analysis based on data quality
    member_count = length(members)
    total_activity = Enum.sum(Enum.map(members, & &1.activity_count))

    # Confidence factors:
    # - More members = higher confidence
    # - More total activity = higher confidence
    # - Minimum threshold for meaningful analysis

    member_score = min(1.0, member_count / 10.0)
    activity_score = min(1.0, total_activity / 50.0)

    (member_score + activity_score) / 2
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

  defp get_j_space_activity_level(activity_data) when is_map(activity_data) do
    # Extract J-space activity level by analyzing actual J-space killmail participation
    j_space_kills = Map.get(activity_data, :j_space_kills, 0)
    total_kills = Map.get(activity_data, :total_kills, 0)
    j_space_systems_visited = Map.get(activity_data, :j_space_systems_visited, [])

    # Calculate activity level based on multiple factors
    participation_ratio =
      if total_kills > 0 do
        j_space_kills / total_kills
      else
        0.0
      end

    # Bonus for visiting multiple J-space systems (indicates regular activity)
    system_diversity_bonus = min(0.3, length(j_space_systems_visited) * 0.05)

    # Activity frequency bonus
    frequency_bonus =
      if j_space_kills > 10 do
        min(0.2, j_space_kills / 50.0)
      else
        0.0
      end

    # Combine factors
    base_score = participation_ratio * 0.5
    total_score = base_score + system_diversity_bonus + frequency_bonus

    min(1.0, max(0.0, total_score))
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

  # Analyze how well a character adheres to known fleet doctrines.
  defp analyze_doctrine_adherence(character_analysis, fleet_data)
       when is_map(character_analysis) and is_map(fleet_data) do
    # Implement actual doctrine adherence analysis
    # Check ship usage against known doctrines
    ship_usage = Map.get(character_analysis, :ship_usage, %{})
    known_doctrines = get_known_fleet_doctrines()

    adherence_scores =
      Enum.map(known_doctrines, fn doctrine ->
        calculate_doctrine_adherence_score(ship_usage, doctrine)
      end)

    %{
      overall_adherence_score: calculate_average_adherence(adherence_scores),
      doctrine_scores: adherence_scores,
      preferred_doctrines: identify_preferred_doctrines(adherence_scores, known_doctrines),
      doctrine_flexibility: calculate_doctrine_flexibility(ship_usage, known_doctrines)
    }
  end

  defp analyze_doctrine_adherence(_character_analysis, _fleet_data) do
    # Default when data is unavailable
    %{
      overall_adherence_score: 0.5,
      doctrine_scores: [],
      preferred_doctrines: [],
      doctrine_flexibility: 0.5
    }
  end

  defp get_known_fleet_doctrines do
    # Define common EVE Online fleet doctrines for wormhole corporations
    [
      %{
        name: "Armor HAC",
        core_ships: ["Legion", "Sacrilege", "Zealot", "Deimos"],
        support_ships: ["Guardian", "Curse", "Pilgrim"],
        doctrine_type: :armor_heavy
      },
      %{
        name: "Shield HAC",
        core_ships: ["Tengu", "Cerberus", "Eagle", "Muninn"],
        support_ships: ["Basilisk", "Rapier", "Huginn"],
        doctrine_type: :shield_heavy
      },
      %{
        name: "Battleship Brawl",
        core_ships: ["Rattlesnake", "Dominix", "Megathron", "Typhoon"],
        support_ships: ["Guardian", "Basilisk", "Bhaalgorn"],
        doctrine_type: :battleship
      },
      %{
        name: "Assault Frigate",
        core_ships: ["Retribution", "Enyo", "Jaguar", "Wolf"],
        support_ships: ["Deacon", "Kirin", "Bifrost"],
        doctrine_type: :small_gang
      },
      %{
        name: "Stealth Bomber",
        core_ships: ["Purifier", "Manticore", "Hound", "Nemesis"],
        support_ships: ["Sabre", "Flycatcher", "Heretic"],
        doctrine_type: :bomber_wing
      }
    ]
  end

  defp calculate_doctrine_adherence_score(ship_usage, doctrine) do
    # Calculate how well ship usage matches a specific doctrine
    total_ships_used = map_size(ship_usage)

    if total_ships_used == 0 do
      %{doctrine_name: doctrine.name, adherence_score: 0.0, usage_count: 0}
    else
      doctrine_ships = doctrine.core_ships ++ doctrine.support_ships

      # Count how many ships used match this doctrine
      doctrine_usage_count =
        ship_usage
        |> Enum.count(fn {ship_name, _count} ->
          ship_name_str = to_string(ship_name)
          Enum.any?(doctrine_ships, &String.contains?(ship_name_str, &1))
        end)

      # Calculate adherence score
      adherence_score =
        if total_ships_used > 0 do
          doctrine_usage_count / total_ships_used
        else
          0.0
        end

      %{
        doctrine_name: doctrine.name,
        adherence_score: adherence_score,
        usage_count: doctrine_usage_count,
        doctrine_type: doctrine.doctrine_type
      }
    end
  end

  defp calculate_average_adherence(adherence_scores) do
    if Enum.empty?(adherence_scores) do
      0.0
    else
      total_score = Enum.sum(Enum.map(adherence_scores, & &1.adherence_score))
      total_score / length(adherence_scores)
    end
  end

  defp identify_preferred_doctrines(adherence_scores, _known_doctrines) do
    # Identify which doctrines the character prefers based on usage
    adherence_scores
    # Significant usage threshold
    |> Enum.filter(&(&1.adherence_score > 0.3))
    |> Enum.sort_by(& &1.adherence_score, :desc)
    # Top 3 preferred doctrines
    |> Enum.take(3)
    |> Enum.map(& &1.doctrine_name)
  end

  defp calculate_doctrine_flexibility(ship_usage, known_doctrines) do
    # Calculate how flexible the character is across different doctrine types
    doctrine_types_used =
      known_doctrines
      |> Enum.filter(fn doctrine ->
        doctrine_ships = doctrine.core_ships ++ doctrine.support_ships

        # Check if character has used ships from this doctrine type
        Enum.any?(ship_usage, fn {ship_name, _count} ->
          ship_name_str = to_string(ship_name)
          Enum.any?(doctrine_ships, &String.contains?(ship_name_str, &1))
        end)
      end)
      |> Enum.map(& &1.doctrine_type)
      |> Enum.uniq()

    # Flexibility score based on how many different doctrine types used
    flexibility_score = length(doctrine_types_used) / length(known_doctrines)
    min(1.0, max(0.0, flexibility_score))
  end

  defp analyze_ship_progression_consistency(character_analysis, fleet_data)
       when is_map(character_analysis) and is_map(fleet_data) do
    # Analyze if ship progression makes logical sense based on character age and skills
    ship_usage = Map.get(character_analysis, :ship_usage, %{})
    character_age_days = calculate_character_age_days(character_analysis)

    # Evaluate ship progression consistency
    ship_categories = categorize_ships_by_complexity(ship_usage)
    progression_score = calculate_progression_score(ship_categories, character_age_days)

    max(0.0, min(1.0, progression_score))
  end

  defp analyze_ship_progression_consistency(_character_analysis, _fleet_data) do
    # Default when data is unavailable
    0.5
  end

  defp detect_progression_anomalies(character_analysis, fleet_data)
       when is_map(character_analysis) and is_map(fleet_data) do
    # Detect anomalies in skill/ship progression
    anomalies = []

    ship_usage = Map.get(character_analysis, :ship_usage, %{})
    character_age_days = calculate_character_age_days(character_analysis)

    anomalies
    |> maybe_add_rapid_progression_anomaly(ship_usage, character_age_days)
    |> maybe_add_skill_mismatch_anomaly(character_analysis, ship_usage)
    |> maybe_add_regression_anomaly(ship_usage, character_age_days)
  end

  defp detect_progression_anomalies(_character_analysis, _fleet_data) do
    # Default when data is unavailable
    []
  end

  defp calculate_character_age_days(character_analysis) do
    case Map.get(character_analysis, :character_created) do
      %DateTime{} = creation_date ->
        DateTime.diff(DateTime.utc_now(), creation_date, :day)

      _ ->
        # Default to 365 days if creation date unknown
        365
    end
  end

  defp categorize_ships_by_complexity(ship_usage) do
    # Categorize ships by training time and complexity
    complexity_categories = %{
      # Frigates, destroyers
      beginner: [],
      # Cruisers, battlecruisers
      intermediate: [],
      # Battleships, T2 ships
      advanced: [],
      # Capital ships, T3 ships
      specialist: []
    }

    Enum.reduce(ship_usage, complexity_categories, fn {ship_type, count}, acc ->
      category = determine_ship_complexity(ship_type)
      %{acc | category => [{ship_type, count} | Map.get(acc, category, [])]}
    end)
  end

  defp determine_ship_complexity(ship_type) when is_atom(ship_type) do
    ship_name = Atom.to_string(ship_type) |> String.downcase()

    cond do
      String.contains?(ship_name, ["frigate", "destroyer"]) ->
        :beginner

      String.contains?(ship_name, ["cruiser", "battlecruiser"]) ->
        :intermediate

      String.contains?(ship_name, ["battleship", "t2", "tech2"]) ->
        :advanced

      String.contains?(ship_name, ["capital", "t3", "tech3", "carrier", "dreadnought"]) ->
        :specialist

      true ->
        :intermediate
    end
  end

  defp determine_ship_complexity(_ship_type), do: :intermediate

  defp calculate_progression_score(ship_categories, character_age_days) do
    # Calculate logical progression score based on age and ship complexity
    base_score = 0.5

    # Younger characters should primarily use simpler ships
    age_factor =
      cond do
        # Very new
        character_age_days < 30 -> 1.0
        # New
        character_age_days < 90 -> 0.8
        # Intermediate
        character_age_days < 365 -> 0.6
        # Experienced
        true -> 0.4
      end

    # Check if ship usage matches expected progression
    total_ships = calculate_total_ship_usage(ship_categories)

    if total_ships == 0 do
      base_score
    else
      specialist_ratio = length(ship_categories.specialist) / total_ships
      advanced_ratio = length(ship_categories.advanced) / total_ships

      # Penalize new characters using too many advanced ships
      progression_penalty =
        cond do
          character_age_days < 90 and (specialist_ratio > 0.1 or advanced_ratio > 0.3) -> -0.3
          character_age_days < 30 and advanced_ratio > 0.1 -> -0.5
          true -> 0.0
        end

      base_score + progression_penalty + age_factor * 0.2
    end
  end

  defp calculate_total_ship_usage(ship_categories) do
    ship_categories
    |> Map.values()
    |> List.flatten()
    |> length()
  end

  defp maybe_add_rapid_progression_anomaly(anomalies, ship_usage, character_age_days) do
    specialist_ships = count_specialist_ships(ship_usage)

    if character_age_days < 60 and specialist_ships > 2 do
      ["rapid_capital_progression" | anomalies]
    else
      anomalies
    end
  end

  defp maybe_add_skill_mismatch_anomaly(anomalies, character_analysis, ship_usage) do
    # Check for ships that require skills the character shouldn't have yet
    skill_points = Map.get(character_analysis, :total_skill_points, 0)
    specialist_ships = count_specialist_ships(ship_usage)

    # Capital ships typically require 20M+ skill points
    if skill_points < 20_000_000 and specialist_ships > 0 do
      ["skill_point_ship_mismatch" | anomalies]
    else
      anomalies
    end
  end

  defp maybe_add_regression_anomaly(anomalies, ship_usage, character_age_days) do
    # Check if experienced character is only using very basic ships (possible sale/transfer)
    # 2+ years
    if character_age_days > 730 do
      advanced_ships = count_advanced_ships(ship_usage)
      total_ships = map_size(ship_usage)

      if total_ships > 5 and advanced_ships == 0 do
        ["experienced_character_basic_ships_only" | anomalies]
      else
        anomalies
      end
    else
      anomalies
    end
  end

  defp count_specialist_ships(ship_usage) do
    ship_usage
    |> Enum.count(fn {ship_type, _count} ->
      determine_ship_complexity(ship_type) == :specialist
    end)
  end

  defp count_advanced_ships(ship_usage) do
    ship_usage
    |> Enum.count(fn {ship_type, _count} ->
      complexity = determine_ship_complexity(ship_type)
      complexity in [:advanced, :specialist]
    end)
  end

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
