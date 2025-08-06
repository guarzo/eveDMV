defmodule EveDmv.Shared.Strategic.PatternRecognition do
  @moduledoc """
  Base pattern recognition framework for strategic analysis.

  Responsible for:
  - Pattern identification across different types
  - Pattern relationship analysis
  - Confidence assessment
  - Pattern classification
  """

  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Shared.Strategic.Patterns.ResourcePattern
  alias EveDmv.Shared.Strategic.Patterns.TacticalPatterns
  alias EveDmv.Shared.Strategic.Patterns.TerritorialPattern

  require Logger

  # Pattern types for classification
  @strategic_patterns [
    :territorial_expansion,
    :resource_control,
    :chokepoint_dominance,
    :harassment_campaign,
    :reconnaissance_operation,
    :supply_line_disruption,
    :defensive_consolidation,
    :offensive_preparation
  ]

  @pattern_significance_threshold 0.7

  @doc """
  Identifies strategic patterns in the provided data.
  """
  def identify_strategic_patterns(strategic_data, pattern_focus \\ @strategic_patterns) do
    Logger.info("Identifying strategic patterns: #{inspect(pattern_focus)}")

    patterns =
      pattern_focus
      |> Enum.map(fn pattern_type ->
        identify_pattern(pattern_type, strategic_data)
      end)
      |> Enum.reject(&is_nil/1)

    relationships = analyze_pattern_relationships(patterns)
    confidence = assess_pattern_confidence(patterns, strategic_data)

    {:ok,
     %{
       identified_patterns: patterns,
       pattern_count: length(patterns),
       pattern_relationships: relationships,
       overall_confidence: confidence,
       dominant_pattern: identify_dominant_pattern(patterns),
       pattern_summary: summarize_patterns(patterns)
     }}
  end

  @doc """
  Analyzes relationships between identified patterns.
  """
  def analyze_pattern_relationships(patterns) do
    patterns
    |> Enum.with_index()
    |> Enum.flat_map(fn {pattern1, i} ->
      patterns
      |> Enum.drop(i + 1)
      |> Enum.map(fn pattern2 ->
        analyze_pattern_pair(pattern1, pattern2)
      end)
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Assesses confidence in pattern identification.
  """
  def assess_pattern_confidence(patterns, strategic_data) do
    if Enum.empty?(patterns) do
      0.0
    else
      individual_confidences = Enum.map(patterns, & &1.confidence)
      data_quality = assess_data_quality(strategic_data)
      pattern_consistency = assess_pattern_consistency(patterns)

      weighted_confidence =
        Enum.sum(individual_confidences) / length(individual_confidences) * 0.5 +
          data_quality * 0.3 +
          pattern_consistency * 0.2

      Float.round(weighted_confidence, 3)
    end
  end

  @doc """
  Determines pattern evolution over time.
  """
  def analyze_pattern_evolution(patterns, time_windows) do
    patterns
    |> Enum.map(fn pattern ->
      evolution_phases = detect_evolution_phases(pattern, time_windows)

      %{
        pattern_type: pattern.type,
        evolution_phases: evolution_phases,
        trend: determine_pattern_trend(evolution_phases),
        stability: calculate_pattern_stability(evolution_phases)
      }
    end)
  end

  # Private functions

  defp identify_pattern(pattern_type, strategic_data) do
    result =
      case pattern_type do
        :territorial_expansion ->
          TerritorialPattern.identify_territorial_expansion(strategic_data)

        :resource_control ->
          ResourcePattern.identify_resource_control(strategic_data)

        :chokepoint_dominance ->
          TacticalPatterns.identify_chokepoint_dominance(strategic_data)

        :harassment_campaign ->
          TacticalPatterns.identify_harassment_campaign(strategic_data)

        :reconnaissance_operation ->
          TacticalPatterns.identify_reconnaissance_operation(strategic_data)

        :supply_line_disruption ->
          TacticalPatterns.identify_supply_line_disruption(strategic_data)

        :defensive_consolidation ->
          TerritorialPattern.identify_defensive_consolidation(strategic_data)

        :offensive_preparation ->
          TacticalPatterns.identify_offensive_preparation(strategic_data)

        _ ->
          nil
      end

    if result && result.confidence >= @pattern_significance_threshold do
      result
    else
      nil
    end
  end

  defp analyze_pattern_pair(pattern1, pattern2) do
    relationship_type = determine_relationship_type(pattern1.type, pattern2.type)

    if relationship_type do
      %{
        patterns: [pattern1.type, pattern2.type],
        relationship_type: relationship_type,
        strength: calculate_relationship_strength(pattern1, pattern2),
        implications: determine_relationship_implications(relationship_type)
      }
    else
      nil
    end
  end

  defp determine_relationship_type(type1, type2) do
    cond do
      type1 == :territorial_expansion && type2 == :resource_control ->
        :expansion_for_resources

      type1 == :harassment_campaign && type2 == :defensive_consolidation ->
        :action_reaction

      type1 == :reconnaissance_operation && type2 == :offensive_preparation ->
        :preparation_sequence

      type1 == :chokepoint_dominance && type2 == :supply_line_disruption ->
        :strategic_control

      true ->
        nil
    end
  end

  defp calculate_relationship_strength(pattern1, pattern2) do
    # Base strength on confidence and temporal overlap
    confidence_factor = (pattern1.confidence + pattern2.confidence) / 2

    temporal_overlap =
      calculate_temporal_overlap(
        pattern1.temporal_data,
        pattern2.temporal_data
      )

    spatial_overlap =
      calculate_spatial_overlap(
        pattern1.spatial_data,
        pattern2.spatial_data
      )

    strength = confidence_factor * 0.4 + temporal_overlap * 0.3 + spatial_overlap * 0.3
    Float.round(strength, 3)
  end

  defp calculate_temporal_overlap(temporal1, temporal2) do
    # Simplified temporal overlap calculation
    if temporal1 && temporal2 do
      start1 = Map.get(temporal1, :start_time)
      end1 = Map.get(temporal1, :end_time)
      start2 = Map.get(temporal2, :start_time)
      end2 = Map.get(temporal2, :end_time)

      if start1 && end1 && start2 && end2 do
        overlap_start = max_datetime(start1, start2)
        overlap_end = min_datetime(end1, end2)

        calculate_overlap_ratio(overlap_start, overlap_end, start1, start2, end1, end2)
      else
        # Default overlap if temporal data missing
        0.5
      end
    else
      0.5
    end
  end

  defp max_datetime(dt1, dt2) do
    if DateTimeUtils.compare(dt1, dt2) == :gt, do: dt1, else: dt2
  end

  defp min_datetime(dt1, dt2) do
    if DateTimeUtils.compare(dt1, dt2) == :lt, do: dt1, else: dt2
  end

  defp calculate_spatial_overlap(spatial1, spatial2) do
    if spatial1 && spatial2 do
      systems1 = MapSet.new(Map.get(spatial1, :systems, []))
      systems2 = MapSet.new(Map.get(spatial2, :systems, []))

      if MapSet.size(systems1) > 0 && MapSet.size(systems2) > 0 do
        intersection = MapSet.intersection(systems1, systems2)
        union = MapSet.union(systems1, systems2)

        Float.round(MapSet.size(intersection) / MapSet.size(union), 3)
      else
        0.0
      end
    else
      # Default overlap if spatial data missing
      0.5
    end
  end

  defp determine_relationship_implications(relationship_type) do
    case relationship_type do
      :expansion_for_resources ->
        "Territory expansion driven by resource acquisition goals"

      :action_reaction ->
        "Defensive response to harassment activities"

      :preparation_sequence ->
        "Reconnaissance preceding offensive operations"

      :strategic_control ->
        "Control of key positions for strategic advantage"

      _ ->
        "Pattern relationship identified"
    end
  end

  defp assess_data_quality(strategic_data) do
    killmail_count =
      case strategic_data.scope do
        :single_system ->
          length(strategic_data.killmails)

        :multi_system ->
          strategic_data.killmail_data
          |> Enum.map(& &1.kill_count)
          |> Enum.sum()
      end

    time_coverage = calculate_time_coverage(strategic_data)

    quality_score =
      cond do
        killmail_count >= 100 && time_coverage >= 0.8 -> 1.0
        killmail_count >= 50 && time_coverage >= 0.6 -> 0.8
        killmail_count >= 20 && time_coverage >= 0.4 -> 0.6
        killmail_count >= 10 -> 0.4
        true -> 0.2
      end

    Float.round(quality_score, 2)
  end

  defp calculate_time_coverage(strategic_data) do
    time_range = strategic_data.time_range
    total_hours = DateTimeUtils.diff(time_range.until, time_range.since, :hour)

    killmails =
      case strategic_data.scope do
        :single_system -> strategic_data.killmails
        :multi_system -> Enum.flat_map(strategic_data.killmail_data, & &1.killmails)
      end

    if Enum.empty?(killmails) || total_hours == 0 do
      0.0
    else
      hours_with_activity =
        killmails
        |> Enum.map(& &1.timestamp.hour)
        |> Enum.uniq()
        |> length()

      min(1.0, hours_with_activity / min(total_hours, 24))
    end
  end

  defp assess_pattern_consistency(patterns) do
    if length(patterns) < 2 do
      # Single pattern is consistent by definition
      1.0
    else
      # Check for conflicting patterns
      conflict_count =
        patterns
        |> Enum.with_index()
        |> Enum.flat_map(fn {p1, i} ->
          patterns
          |> Enum.drop(i + 1)
          |> Enum.map(fn p2 -> {p1.type, p2.type} end)
        end)
        |> Enum.count(&conflicting_pattern_pair?/1)

      max_conflicts = div(length(patterns) * (length(patterns) - 1), 2)

      if max_conflicts > 0 do
        Float.round(1.0 - conflict_count / max_conflicts, 3)
      else
        1.0
      end
    end
  end

  defp conflicting_pattern_pair?({type1, type2}) do
    conflicting_pairs = [
      {:offensive_preparation, :defensive_consolidation},
      {:territorial_expansion, :defensive_consolidation},
      {:harassment_campaign, :resource_control}
    ]

    Enum.any?(conflicting_pairs, fn {t1, t2} ->
      (type1 == t1 && type2 == t2) || (type1 == t2 && type2 == t1)
    end)
  end

  defp identify_dominant_pattern(patterns) do
    if Enum.empty?(patterns) do
      nil
    else
      patterns
      |> Enum.max_by(& &1.confidence)
      |> Map.get(:type)
    end
  end

  defp summarize_patterns(patterns) do
    patterns
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category, category_patterns} ->
      %{
        category: category,
        pattern_count: length(category_patterns),
        patterns: Enum.map(category_patterns, & &1.type),
        average_confidence: calculate_average_confidence(category_patterns)
      }
    end)
  end

  defp calculate_average_confidence(patterns) do
    if Enum.empty?(patterns) do
      0.0
    else
      total = Enum.sum(Enum.map(patterns, & &1.confidence))
      Float.round(total / length(patterns), 3)
    end
  end

  defp detect_evolution_phases(pattern, time_windows) do
    time_windows
    |> Enum.map(fn window ->
      intensity = calculate_pattern_intensity(pattern, window)

      %{
        time_window: window,
        intensity: intensity,
        phase: classify_evolution_phase(intensity)
      }
    end)
  end

  defp calculate_pattern_intensity(pattern, time_window) do
    # Simplified intensity calculation
    if pattern.temporal_data do
      events_in_window =
        Map.get(pattern, :events, [])
        |> Enum.count(fn event ->
          event_time = Map.get(event, :timestamp)

          event_time &&
            DateTimeUtils.compare(event_time, time_window.start) != :lt &&
            DateTimeUtils.compare(event_time, time_window.end) == :lt
        end)

      Float.round(events_in_window / max(1, time_window.duration_hours), 3)
    else
      0.0
    end
  end

  defp classify_evolution_phase(intensity) do
    cond do
      intensity >= 0.8 -> :peak
      intensity >= 0.5 -> :growth
      intensity >= 0.2 -> :stable
      intensity > 0 -> :decline
      true -> :dormant
    end
  end

  defp determine_pattern_trend(evolution_phases) do
    if length(evolution_phases) < 2 do
      :insufficient_data
    else
      phase_values = Enum.map(evolution_phases, &phase_to_value(&1.phase))

      first_half_avg =
        phase_values
        |> Enum.take(div(length(phase_values), 2))
        |> average()

      second_half_avg =
        phase_values
        |> Enum.drop(div(length(phase_values), 2))
        |> average()

      cond do
        second_half_avg > first_half_avg * 1.2 -> :increasing
        second_half_avg < first_half_avg * 0.8 -> :decreasing
        true -> :stable
      end
    end
  end

  defp phase_to_value(:peak), do: 4
  defp phase_to_value(:growth), do: 3
  defp phase_to_value(:stable), do: 2
  defp phase_to_value(:decline), do: 1
  defp phase_to_value(:dormant), do: 0

  defp average(list) do
    if Enum.empty?(list) do
      0.0
    else
      Enum.sum(list) / length(list)
    end
  end

  defp calculate_pattern_stability(evolution_phases) do
    if length(evolution_phases) < 2 do
      0.0
    else
      phase_values = Enum.map(evolution_phases, &phase_to_value(&1.phase))
      mean = average(phase_values)

      variance =
        phase_values
        |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
        |> average()

      cv = if mean > 0, do: :math.sqrt(variance) / mean, else: 1.0

      # Convert to stability score (0-1)
      Float.round(max(0.0, min(1.0, 1.0 - cv)), 3)
    end
  end

  defp calculate_overlap_ratio(overlap_start, overlap_end, start1, start2, end1, end2) do
    if DateTimeUtils.compare(overlap_start, overlap_end) == :lt do
      overlap_duration = DateTimeUtils.diff(overlap_end, overlap_start, :second)

      total_duration =
        DateTimeUtils.diff(
          max_datetime(end1, end2),
          min_datetime(start1, start2),
          :second
        )

      if total_duration > 0 do
        Float.round(overlap_duration / total_duration, 3)
      else
        0.0
      end
    else
      0.0
    end
  end
end
