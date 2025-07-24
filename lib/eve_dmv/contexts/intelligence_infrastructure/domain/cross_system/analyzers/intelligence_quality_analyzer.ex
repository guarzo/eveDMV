defmodule EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Analyzers.IntelligenceQualityAnalyzer do
  @moduledoc """
  Specialized analyzer for intelligence quality assessment across multiple systems.

  This module handles intelligence-related analysis including quality assessment,
  coverage analysis, gap identification, and shared intelligence correlation.

  ## Key Responsibilities

  - **Coverage Analysis**: Assesses intelligence coverage across systems
  - **Quality Assessment**: Evaluates intelligence data quality and reliability
  - **Gap Identification**: Identifies intelligence gaps and blind spots
  - **Shared Intelligence**: Analyzes shared intelligence between systems
  - **Correlation Analysis**: Determines intelligence correlation strength

  ## Usage

      # Calculate coverage percentage
      coverage = IntelligenceQualityAnalyzer.calculate_coverage_percentage(system_ids, intel_data)
      
      # Assess intelligence quality
      quality = IntelligenceQualityAnalyzer.assess_intelligence_quality(intel_data)
      
      # Identify intelligence gaps
      gaps = IntelligenceQualityAnalyzer.identify_intelligence_gaps(system_ids, killmails)
  """

  require Logger

  @doc """
  Calculate intelligence coverage percentage across systems.
  """
  def calculate_coverage_percentage(system_ids, intel_data) do
    if Enum.empty?(system_ids) do
      0.0
    else
      covered_systems =
        intel_data
        |> Map.get(:coverage_map, %{})
        |> Map.keys()
        |> Enum.count(fn system_id -> system_id in system_ids end)

      covered_systems / length(system_ids) * 100.0
    end
  end

  @doc """
  Calculate intelligence correlation strength between systems.
  """
  def calculate_intel_correlation_strength(shared_intel) do
    if Enum.empty?(shared_intel) do
      0.0
    else
      correlation_scores =
        shared_intel
        |> Enum.map(fn intel_item ->
          Map.get(intel_item, :reliability_score, 0.5)
        end)

      Enum.sum(correlation_scores) / length(correlation_scores)
    end
  end

  @doc """
  Assess overall intelligence quality for given data.
  """
  def assess_intelligence_quality(intel_data) do
    base_quality = 0.6

    coverage_bonus = calculate_coverage_bonus(intel_data)
    recency_bonus = calculate_recency_bonus(intel_data)
    reliability_bonus = calculate_reliability_bonus(intel_data)

    total_quality = min(base_quality + coverage_bonus + recency_bonus + reliability_bonus, 1.0)

    %{
      overall_quality: total_quality,
      coverage_score: coverage_bonus,
      recency_score: recency_bonus,
      reliability_score: reliability_bonus,
      quality_grade: classify_quality_grade(total_quality),
      improvement_recommendations: generate_quality_improvements(intel_data),
      data_freshness: assess_data_freshness(intel_data),
      source_diversity: assess_source_diversity(intel_data),
      confidence_level: calculate_confidence_level(total_quality)
    }
  end

  @doc """
  Identify intelligence gaps across the specified systems.
  """
  def identify_intelligence_gaps(system_ids, killmails) do
    # Analyze killmail distribution to identify gaps
    system_activity =
      killmails
      |> Enum.group_by(& &1.solar_system_id)
      |> Enum.into(%{}, fn {system_id, kills} -> {system_id, length(kills)} end)

    gaps =
      system_ids
      |> Enum.map(fn system_id ->
        activity_level = Map.get(system_activity, system_id, 0)

        %{
          system_id: system_id,
          activity_level: activity_level,
          gap_severity: classify_gap_severity(activity_level),
          recommended_actions: suggest_gap_mitigation(activity_level),
          priority_level: calculate_gap_priority(system_id, activity_level)
        }
      end)
      |> Enum.filter(fn gap -> gap.gap_severity != :no_gap end)
      |> Enum.sort_by(& &1.priority_level, :desc)

    %{
      identified_gaps: gaps,
      total_gaps: length(gaps),
      critical_gaps: Enum.count(gaps, &(&1.gap_severity == :critical)),
      coverage_percentage: calculate_system_coverage(system_ids, gaps),
      gap_trend: analyze_gap_trend(gaps),
      mitigation_strategy: develop_mitigation_strategy(gaps)
    }
  end

  @doc """
  Analyze shared intelligence between systems.
  """
  def analyze_shared_intelligence(_system_ids, intel_data) do
    shared_entities = extract_shared_entities(intel_data)
    cross_system_patterns = identify_cross_system_patterns(intel_data)
    intelligence_flow = analyze_intelligence_flow(intel_data)

    %{
      shared_entities: shared_entities,
      cross_system_patterns: cross_system_patterns,
      intelligence_flow_analysis: intelligence_flow,
      shared_threat_indicators: extract_shared_threat_indicators(intel_data),
      coordination_opportunities: identify_coordination_opportunities(intel_data),
      information_gaps: identify_information_sharing_gaps(intel_data)
    }
  end

  @doc """
  Extract intelligence indicators from killmail data.
  """
  def extract_intelligence_indicators(killmails) do
    fleet_operations = detect_fleet_operations(killmails)
    strategic_targets = detect_strategic_targets(killmails)
    territory_control = detect_territory_control(killmails)

    %{
      fleet_operations: fleet_operations,
      strategic_target_activity: strategic_targets,
      territory_control_indicators: territory_control,
      activity_hotspots: identify_activity_hotspots(killmails),
      threat_level_indicators: calculate_threat_level_indicators(killmails),
      operational_patterns: analyze_operational_patterns(killmails)
    }
  end

  @doc """
  Detect fleet operations from killmail patterns.
  """
  def detect_fleet_operations(killmails) do
    # Group killmails by time proximity to detect fleet operations
    time_grouped =
      killmails
      |> Enum.group_by(fn killmail ->
        killmail.killmail_time |> DateTime.truncate(:hour)
      end)

    fleet_operations =
      time_grouped
      |> Enum.map(fn {time_window, window_kills} ->
        if length(window_kills) >= 5 do
          %{
            operation_time: time_window,
            participant_count: count_unique_participants(window_kills),
            systems_involved: count_unique_systems(window_kills),
            operation_type: classify_operation_type(window_kills),
            fleet_size_estimate: estimate_fleet_size(window_kills),
            coordination_level: assess_coordination_level(window_kills)
          }
        end
      end)
      |> Enum.filter(& &1)
      |> Enum.sort_by(& &1.participant_count, :desc)

    %{
      detected_operations: fleet_operations,
      total_operations: length(fleet_operations),
      largest_operation: List.first(fleet_operations),
      operation_frequency: calculate_operation_frequency(fleet_operations)
    }
  end

  @doc """
  Detect strategic targets from killmail data.
  """
  def detect_strategic_targets(killmails) do
    strategic_kills =
      killmails
      |> Enum.filter(fn killmail ->
        strategic_target?(killmail)
      end)

    target_analysis =
      strategic_kills
      |> Enum.group_by(& &1.victim_ship_name)
      |> Enum.map(fn {ship_type, kills} ->
        %{
          target_type: ship_type,
          frequency: length(kills),
          systems_affected: kills |> Enum.map(& &1.solar_system_id) |> Enum.uniq(),
          threat_level: calculate_strategic_threat_level(kills),
          targeting_pattern: analyze_targeting_pattern(kills)
        }
      end)
      |> Enum.sort_by(& &1.threat_level, :desc)

    %{
      strategic_targets: target_analysis,
      total_strategic_kills: length(strategic_kills),
      high_value_targets: Enum.filter(target_analysis, &(&1.threat_level > 0.7)),
      targeting_trend: analyze_strategic_targeting_trend(target_analysis)
    }
  end

  @doc """
  Detect territory control indicators from killmail patterns.
  """
  def detect_territory_control(killmails) do
    system_control =
      killmails
      |> Enum.group_by(& &1.solar_system_id)
      |> Enum.map(fn {system_id, system_kills} ->
        dominant_entities = identify_dominant_entities(system_kills)
        control_strength = calculate_control_strength(system_kills)

        %{
          system_id: system_id,
          dominant_entities: dominant_entities,
          control_strength: control_strength,
          contested: contested_system?(system_kills),
          activity_level: length(system_kills),
          control_trend: analyze_control_trend(system_kills)
        }
      end)
      |> Enum.sort_by(& &1.control_strength, :desc)

    %{
      system_control_analysis: system_control,
      contested_systems: Enum.filter(system_control, & &1.contested),
      dominant_systems: Enum.filter(system_control, &(&1.control_strength > 0.7)),
      control_shift_indicators: identify_control_shifts(system_control)
    }
  end

  # Private helper functions
  defp calculate_coverage_bonus(intel_data) do
    coverage = Map.get(intel_data, :coverage_percentage, 50.0)
    min(coverage / 100.0 * 0.2, 0.2)
  end

  defp calculate_recency_bonus(intel_data) do
    last_update = Map.get(intel_data, :last_update, DateTime.utc_now())
    hours_old = DateTime.diff(DateTime.utc_now(), last_update, :hour)

    cond do
      hours_old < 6 -> 0.2
      hours_old < 24 -> 0.1
      true -> 0.0
    end
  end

  defp calculate_reliability_bonus(intel_data) do
    reliability = Map.get(intel_data, :reliability_score, 0.5)
    min(reliability * 0.2, 0.2)
  end

  defp classify_quality_grade(quality) do
    cond do
      quality >= 0.9 -> :excellent
      quality >= 0.7 -> :good
      quality >= 0.5 -> :fair
      true -> :poor
    end
  end

  defp generate_quality_improvements(intel_data) do
    improvements = []

    coverage = Map.get(intel_data, :coverage_percentage, 50.0)

    improvements_with_coverage =
      if coverage < 70.0, do: ["Improve system coverage" | improvements], else: improvements

    recency = Map.get(intel_data, :hours_since_update, 24)

    final_improvements =
      if recency > 12, do: ["Increase data refresh frequency" | improvements_with_coverage], else: improvements_with_coverage

    final_improvements
  end

  defp assess_data_freshness(intel_data) do
    last_update = Map.get(intel_data, :last_update, DateTime.utc_now())
    hours_old = DateTime.diff(DateTime.utc_now(), last_update, :hour)

    cond do
      hours_old < 1 -> :very_fresh
      hours_old < 6 -> :fresh
      hours_old < 24 -> :acceptable
      true -> :stale
    end
  end

  defp assess_source_diversity(_intel_data) do
    # Simplified source diversity assessment
    :medium
  end

  defp calculate_confidence_level(quality) do
    cond do
      quality >= 0.8 -> :high
      quality >= 0.6 -> :medium
      true -> :low
    end
  end

  defp classify_gap_severity(activity_level) do
    cond do
      activity_level == 0 -> :critical
      activity_level < 3 -> :high
      activity_level < 10 -> :medium
      true -> :no_gap
    end
  end

  defp suggest_gap_mitigation(activity_level) do
    case activity_level do
      0 -> ["Deploy intelligence assets", "Establish monitoring presence"]
      n when n < 3 -> ["Increase patrol frequency", "Deploy additional sensors"]
      n when n < 10 -> ["Enhance data collection", "Improve reporting frequency"]
      _ -> []
    end
  end

  defp calculate_gap_priority(_system_id, activity_level) do
    # Higher priority for systems with less activity (bigger gaps)
    case activity_level do
      0 -> 1.0
      n when n < 3 -> 0.8
      n when n < 10 -> 0.5
      _ -> 0.2
    end
  end

  defp calculate_system_coverage(system_ids, gaps) do
    covered_systems = length(system_ids) - length(gaps)
    covered_systems / length(system_ids) * 100.0
  end

  defp analyze_gap_trend(_gaps), do: :stable

  defp develop_mitigation_strategy(_gaps),
    do: "Implement comprehensive intelligence collection strategy"

  defp extract_shared_entities(_intel_data), do: []
  defp identify_cross_system_patterns(_intel_data), do: []
  defp analyze_intelligence_flow(_intel_data), do: %{}
  defp extract_shared_threat_indicators(_intel_data), do: []
  defp identify_coordination_opportunities(_intel_data), do: []
  defp identify_information_sharing_gaps(_intel_data), do: []

  defp identify_activity_hotspots(_killmails), do: []
  defp calculate_threat_level_indicators(_killmails), do: %{}
  defp analyze_operational_patterns(_killmails), do: []

  defp count_unique_participants(killmails) do
    killmails
    |> Enum.flat_map(fn km -> [km.attacker_character_id, km.victim_character_id] end)
    |> Enum.uniq()
    |> Enum.filter(& &1)
    |> length()
  end

  defp count_unique_systems(killmails) do
    killmails |> Enum.map(& &1.solar_system_id) |> Enum.uniq() |> length()
  end

  defp classify_operation_type(killmails) do
    system_count = count_unique_systems(killmails)

    cond do
      system_count == 1 -> :system_control
      system_count <= 3 -> :regional_operation
      true -> :campaign_operation
    end
  end

  defp estimate_fleet_size(killmails) do
    unique_participants = count_unique_participants(killmails)

    # Estimate fleet size based on unique participants (assuming not all participants appear in killmails)
    round(unique_participants * 1.5)
  end

  defp assess_coordination_level(killmails) do
    time_span = calculate_operation_timespan(killmails)

    cond do
      time_span < 30 -> :high
      time_span < 120 -> :medium
      true -> :low
    end
  end

  defp calculate_operation_frequency(operations) do
    if length(operations) < 2 do
      :insufficient_data
    else
      # Simplified
      :regular
    end
  end

  defp strategic_target?(killmail) do
    strategic_ships = ["Logistics", "Command", "Capital", "Supercarrier", "Titan", "Dreadnought"]

    Enum.any?(strategic_ships, fn ship_type ->
      killmail.victim_ship_name && String.contains?(killmail.victim_ship_name, ship_type)
    end)
  end

  defp calculate_strategic_threat_level(kills) do
    min(length(kills) * 0.1, 1.0)
  end

  defp analyze_targeting_pattern(_kills), do: :systematic
  defp analyze_strategic_targeting_trend(_analysis), do: :stable

  defp identify_dominant_entities(system_kills) do
    system_kills
    |> Enum.group_by(& &1.attacker_character_id)
    |> Enum.map(fn {char_id, kills} -> {char_id, length(kills)} end)
    |> Enum.sort_by(fn {_char_id, kill_count} -> kill_count end, :desc)
    |> Enum.take(5)
  end

  defp calculate_control_strength(system_kills) do
    if Enum.empty?(system_kills) do
      0.0
    else
      dominant_kills = system_kills |> identify_dominant_entities() |> List.first() |> elem(1)
      min(dominant_kills / length(system_kills), 1.0)
    end
  end

  defp contested_system?(system_kills) do
    entities = identify_dominant_entities(system_kills)

    if length(entities) < 2 do
      false
    else
      [{_, top_kills}, {_, second_kills} | _] = entities
      second_kills / top_kills > 0.5
    end
  end

  defp analyze_control_trend(_system_kills), do: :stable
  defp identify_control_shifts(_system_control), do: []

  defp calculate_operation_timespan(killmails) do
    times = Enum.map(killmails, & &1.killmail_time)
    min_time = Enum.min(times)
    max_time = Enum.max(times)
    DateTime.diff(max_time, min_time, :minute)
  end
end
