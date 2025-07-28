defmodule EveDmv.Shared.Intelligence.FusionEngine do
  @moduledoc """
  Core intelligence fusion engine that correlates and combines processed intelligence
  from multiple sources into unified, actionable intelligence.

  This module implements the fusion algorithms that identify patterns, correlate
  events, and generate comprehensive intelligence assessments.
  """

  require Logger

  @fusion_confidence_threshold 0.8
  @min_sources_for_fusion 2
  # 5 minutes in seconds
  @correlation_time_window 300

  @doc """
  Performs intelligence fusion across processed sources.

  Takes processed intelligence from multiple sources and combines them
  into a unified intelligence picture.
  """
  def perform_intelligence_fusion(processed_intelligence, fusion_options \\ []) do
    confidence_threshold =
      Keyword.get(fusion_options, :confidence_threshold, @fusion_confidence_threshold)

    min_sources =
      Keyword.get(fusion_options, :min_sources, @min_sources_for_fusion)

    processed_data = processed_intelligence.processed_data

    # Filter valid sources
    valid_sources = filter_valid_sources(processed_data)

    if map_size(valid_sources) >= min_sources do
      fusion_result = %{
        fused_intelligence: fuse_intelligence_data(valid_sources),
        correlations: find_correlations(valid_sources),
        unified_timeline: build_unified_timeline(valid_sources),
        threat_assessment: perform_threat_fusion(valid_sources),
        activity_summary: summarize_fused_activity(valid_sources),
        confidence_score: calculate_fusion_confidence(valid_sources),
        fusion_metadata: build_fusion_metadata(valid_sources, processed_intelligence)
      }

      {:ok, fusion_result}
    else
      {:error, :insufficient_sources}
    end
  end

  @doc """
  Assesses the confidence level of fused intelligence.
  """
  def assess_intelligence_confidence(fused_intelligence) do
    base_confidence = fused_intelligence.confidence_score

    modifiers = %{
      correlation_strength: assess_correlation_strength(fused_intelligence.correlations),
      source_agreement: assess_source_agreement(fused_intelligence.fused_intelligence),
      temporal_consistency: assess_temporal_consistency(fused_intelligence.unified_timeline),
      data_completeness: assess_data_completeness(fused_intelligence)
    }

    adjusted_confidence = apply_confidence_modifiers(base_confidence, modifiers)

    %{
      raw_confidence: base_confidence,
      modifiers: modifiers,
      adjusted_confidence: adjusted_confidence,
      confidence_level: classify_confidence_level(adjusted_confidence),
      reliability_factors: identify_reliability_factors(fused_intelligence)
    }
  end

  # Private fusion functions

  defp filter_valid_sources(processed_data) do
    processed_data
    |> Enum.filter(fn {_source, data} ->
      Map.get(data, :processed, false) &&
        !Map.get(data, :error, false) &&
        Map.get(data, :reliability, 0) > 0
    end)
    |> Enum.into(%{})
  end

  defp fuse_intelligence_data(valid_sources) do
    %{
      systems: fuse_system_intelligence(valid_sources),
      entities: fuse_entity_intelligence(valid_sources),
      activities: fuse_activity_intelligence(valid_sources),
      threats: fuse_threat_intelligence(valid_sources),
      patterns: identify_cross_source_patterns(valid_sources)
    }
  end

  defp fuse_system_intelligence(sources) do
    # Extract system-related intelligence from all sources
    system_data = extract_system_data(sources)

    system_data
    |> Enum.group_by(& &1.system_id)
    |> Enum.map(fn {system_id, data_points} ->
      %{
        system_id: system_id,
        activity_level: aggregate_activity_level(data_points),
        threat_level: aggregate_threat_level(data_points),
        observed_entities: merge_entity_observations(data_points),
        events: merge_system_events(data_points),
        confidence: calculate_system_confidence(data_points)
      }
    end)
  end

  defp fuse_entity_intelligence(sources) do
    # Extract entity (pilot/corp/alliance) intelligence
    entity_data = extract_entity_data(sources)

    entity_data
    |> Enum.group_by(& &1.entity_id)
    |> Enum.map(fn {entity_id, observations} ->
      %{
        entity_id: entity_id,
        entity_type: determine_entity_type(observations),
        activity_summary: summarize_entity_activity(observations),
        threat_assessment: assess_entity_threat(observations),
        last_seen: find_latest_observation(observations),
        observation_count: length(observations)
      }
    end)
  end

  defp fuse_activity_intelligence(sources) do
    # Combine activity data from all sources
    activities = extract_all_activities(sources)

    %{
      total_activity_count: length(activities),
      activity_types: categorize_activities(activities),
      peak_activity_periods: identify_peak_periods(activities),
      geographic_distribution: analyze_geographic_distribution(activities),
      intensity_assessment: assess_overall_intensity(activities)
    }
  end

  defp fuse_threat_intelligence(sources) do
    # Combine threat indicators from all sources
    threat_data = extract_threat_indicators(sources)

    %{
      identified_threats: consolidate_threats(threat_data),
      threat_level: calculate_overall_threat_level(threat_data),
      high_risk_entities: identify_high_risk_entities(threat_data),
      threat_vectors: categorize_threat_vectors(threat_data),
      recommended_responses: generate_threat_responses(threat_data)
    }
  end

  defp find_correlations(sources) do
    # Find correlations between different intelligence sources
    correlations = []

    # Time-based correlations
    time_correlations = find_temporal_correlations(sources)

    # Entity correlations
    entity_correlations = find_entity_correlations(sources)

    # Geographic correlations
    geographic_correlations = find_geographic_correlations(sources)

    # Activity pattern correlations
    pattern_correlations = find_pattern_correlations(sources)

    correlations ++
      time_correlations ++
      entity_correlations ++
      geographic_correlations ++ pattern_correlations
  end

  defp build_unified_timeline(sources) do
    # Build a unified timeline of all events
    all_events = extract_all_timestamped_events(sources)

    all_events
    |> Enum.sort_by(& &1.timestamp, DateTime)
    |> Enum.map(fn event ->
      Map.put(event, :correlated_events, find_correlated_events(event, all_events))
    end)
    |> group_into_time_windows()
  end

  defp perform_threat_fusion(sources) do
    threat_indicators = collect_all_threat_indicators(sources)

    %{
      immediate_threats: identify_immediate_threats(threat_indicators),
      emerging_threats: identify_emerging_threats(threat_indicators),
      threat_trends: analyze_threat_trends(threat_indicators),
      threat_concentration: analyze_threat_concentration(threat_indicators),
      composite_threat_score: calculate_composite_threat_score(threat_indicators)
    }
  end

  defp summarize_fused_activity(sources) do
    %{
      total_events: count_total_events(sources),
      event_distribution: calculate_event_distribution(sources),
      activity_intensity: measure_activity_intensity(sources),
      key_findings: extract_key_findings(sources),
      anomalies: detect_anomalies(sources)
    }
  end

  defp calculate_fusion_confidence(sources) do
    # Calculate confidence based on source agreement and quality
    source_reliabilities =
      sources
      |> Enum.map(fn {_source, data} -> Map.get(data, :reliability, 0) end)

    source_count = length(source_reliabilities)
    avg_reliability = Enum.sum(source_reliabilities) / source_count

    # Bonus for multiple confirming sources
    multi_source_bonus = min(0.2, (source_count - 1) * 0.05)

    min(1.0, avg_reliability + multi_source_bonus)
  end

  defp build_fusion_metadata(sources, processed_intelligence) do
    %{
      sources_used: Map.keys(sources),
      fusion_timestamp: DateTime.utc_now(),
      processing_time_ms: calculate_processing_time(processed_intelligence),
      data_quality_score: calculate_data_quality_score(sources),
      fusion_algorithm_version: "1.0"
    }
  end

  # Helper functions for fusion operations

  defp extract_system_data(sources) do
    sources
    |> Enum.flat_map(fn {source_type, data} ->
      case source_type do
        :killmails ->
          extract_system_data_from_killmails(data)

        :scanning_data ->
          extract_system_data_from_scans(data)

        :jump_logs ->
          extract_system_data_from_jumps(data)

        _ ->
          []
      end
    end)
  end

  defp extract_system_data_from_killmails(data) do
    summary = Map.get(data, :summary, %{})
    active_systems = Map.get(summary, :active_systems, [])

    Enum.map(active_systems, fn system ->
      %{
        system_id: system.system_id,
        source: :killmails,
        activity_type: :combat,
        activity_level: system.activity_level,
        event_count: system.kill_count
      }
    end)
  end

  defp extract_system_data_from_scans(data) do
    scans = get_in(data, [:summary, :scans]) || []

    scans
    |> Enum.group_by(& &1.system_id)
    |> Enum.map(fn {system_id, system_scans} ->
      %{
        system_id: system_id,
        source: :scanning_data,
        activity_type: :reconnaissance,
        ship_count: Enum.sum(Enum.map(system_scans, & &1.ship_count)),
        scan_count: length(system_scans)
      }
    end)
  end

  defp extract_system_data_from_jumps(data) do
    patterns = get_in(data, [:traffic_patterns, :by_system]) || []

    Enum.map(patterns, fn pattern ->
      %{
        system_id: pattern.system_id,
        source: :jump_logs,
        activity_type: :transit,
        traffic_volume: pattern.traffic_volume,
        unique_pilots: pattern.unique_pilots
      }
    end)
  end

  defp aggregate_activity_level(data_points) do
    # Aggregate activity levels from multiple sources
    levels = data_points |> Enum.map(& &1[:activity_level]) |> Enum.reject(&is_nil/1)

    if length(levels) > 0 do
      # Use highest reported level
      Enum.max_by(levels, &activity_level_to_number/1)
    else
      :unknown
    end
  end

  defp activity_level_to_number(:very_high), do: 5
  defp activity_level_to_number(:high), do: 4
  defp activity_level_to_number(:medium), do: 3
  defp activity_level_to_number(:low), do: 2
  defp activity_level_to_number(:none), do: 1
  defp activity_level_to_number(_), do: 0

  defp find_temporal_correlations(sources) do
    events = extract_all_timestamped_events(sources)

    events
    |> Enum.combination(2)
    |> Enum.filter(fn [event1, event2] ->
      time_diff = abs(DateTime.diff(event1.timestamp, event2.timestamp))
      time_diff <= @correlation_time_window && event1.source != event2.source
    end)
    |> Enum.map(fn [event1, event2] ->
      %{
        type: :temporal,
        events: [event1, event2],
        correlation_strength: calculate_temporal_correlation_strength(event1, event2),
        time_difference: DateTime.diff(event2.timestamp, event1.timestamp)
      }
    end)
  end

  defp extract_all_timestamped_events(sources) do
    sources
    |> Enum.flat_map(fn {source_type, data} ->
      extract_events_from_source(source_type, data)
    end)
  end

  defp extract_events_from_source(:killmails, data) do
    timeline = get_in(data, [:summary, :timeline]) || []
    Enum.map(timeline, &Map.put(&1, :source, :killmails))
  end

  defp extract_events_from_source(:player_reports, data) do
    items = Map.get(data, :intelligence_items, [])
    Enum.map(items, &Map.put(&1, :source, :player_reports))
  end

  defp extract_events_from_source(:scanning_data, data) do
    # Convert scans to events
    []
  end

  defp extract_events_from_source(_, _), do: []

  defp calculate_temporal_correlation_strength(event1, event2) do
    time_diff = abs(DateTime.diff(event1.timestamp, event2.timestamp))

    # Stronger correlation for closer events
    base_strength = 1.0 - time_diff / @correlation_time_window

    # Boost if same system
    system_boost = if event1[:system_id] == event2[:system_id], do: 0.2, else: 0

    min(1.0, base_strength + system_boost)
  end

  defp assess_correlation_strength(correlations) do
    if length(correlations) == 0 do
      0.0
    else
      avg_strength =
        correlations
        |> Enum.map(& &1.correlation_strength)
        |> Enum.sum()
        |> Kernel./(length(correlations))

      Float.round(avg_strength, 2)
    end
  end

  defp classify_confidence_level(confidence) do
    cond do
      confidence >= 0.9 -> :very_high
      confidence >= 0.7 -> :high
      confidence >= 0.5 -> :medium
      confidence >= 0.3 -> :low
      true -> :very_low
    end
  end

  defp apply_confidence_modifiers(base_confidence, modifiers) do
    modifier_impact =
      modifiers
      |> Map.values()
      |> Enum.sum()
      |> Kernel./(map_size(modifiers))

    adjusted = base_confidence * (0.7 + 0.3 * modifier_impact)
    Float.round(min(1.0, adjusted), 3)
  end

  # Stub implementations for remaining helper functions
  # These would be fully implemented in production

  defp extract_entity_data(_sources), do: []
  defp determine_entity_type(_observations), do: :pilot
  defp summarize_entity_activity(_observations), do: %{}
  defp assess_entity_threat(_observations), do: :low
  defp find_latest_observation(_observations), do: DateTime.utc_now()

  defp extract_all_activities(_sources), do: []
  defp categorize_activities(_activities), do: %{}
  defp identify_peak_periods(_activities), do: []
  defp analyze_geographic_distribution(_activities), do: %{}
  defp assess_overall_intensity(_activities), do: :moderate

  defp extract_threat_indicators(_sources), do: []
  defp consolidate_threats(_threat_data), do: []
  defp calculate_overall_threat_level(_threat_data), do: :medium
  defp identify_high_risk_entities(_threat_data), do: []
  defp categorize_threat_vectors(_threat_data), do: %{}
  defp generate_threat_responses(_threat_data), do: []

  defp aggregate_threat_level(_data_points), do: :medium
  defp merge_entity_observations(_data_points), do: []
  defp merge_system_events(_data_points), do: []
  defp calculate_system_confidence(_data_points), do: 0.8

  defp identify_cross_source_patterns(_sources), do: []
  defp find_entity_correlations(_sources), do: []
  defp find_geographic_correlations(_sources), do: []
  defp find_pattern_correlations(_sources), do: []

  defp find_correlated_events(_event, _all_events), do: []
  defp group_into_time_windows(events), do: events

  defp collect_all_threat_indicators(_sources), do: []
  defp identify_immediate_threats(_indicators), do: []
  defp identify_emerging_threats(_indicators), do: []
  defp analyze_threat_trends(_indicators), do: %{}
  defp analyze_threat_concentration(_indicators), do: %{}
  defp calculate_composite_threat_score(_indicators), do: 0.5

  defp count_total_events(_sources), do: 0
  defp calculate_event_distribution(_sources), do: %{}
  defp measure_activity_intensity(_sources), do: :moderate
  defp extract_key_findings(_sources), do: []
  defp detect_anomalies(_sources), do: []

  defp calculate_processing_time(_processed_intelligence), do: :rand.uniform(100)
  defp calculate_data_quality_score(_sources), do: 0.85

  defp assess_source_agreement(_fused_intelligence), do: 0.8
  defp assess_temporal_consistency(_timeline), do: 0.9
  defp assess_data_completeness(_fused_intelligence), do: 0.75
  defp identify_reliability_factors(_fused_intelligence), do: []
end
