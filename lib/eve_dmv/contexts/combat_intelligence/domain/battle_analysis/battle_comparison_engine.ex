defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.BattleComparisonEngine do
  @moduledoc """
  Battle comparison and trend analysis engine.

  Provides comprehensive multi-battle analysis including:
  - Common pattern identification across battles
  - Tactical evolution analysis
  - Doctrine evolution tracking
  - Ship composition trend analysis
  - Adaptation detection and effectiveness measurement
  - Multi-battle comparison logic
  """

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Engines.FleetComparisonEngine
  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.TacticalAnalysisEngine

  require Logger

  @doc """
  Identify common patterns across multiple battles.
  """
  def identify_common_patterns(battle_analyses) do
    # Identify common tactical patterns across multiple battles
    if length(battle_analyses) < 2 do
      []
    else
      # Extract patterns from each battle
      all_patterns =
        battle_analyses
        |> Enum.flat_map(fn analysis ->
          extract_patterns_from_battle(analysis)
        end)
        |> Enum.group_by(& &1.pattern_type)

      # Find patterns that appear in multiple battles
      common_patterns =
        all_patterns
        |> Enum.map(fn {pattern_type, instances} ->
          if length(instances) >= 2 do
            %{
              pattern_type: pattern_type,
              occurrences: length(instances),
              frequency: Float.round(length(instances) / length(battle_analyses) * 100, 1),
              examples: Enum.take(instances, 3),
              confidence: calculate_pattern_confidence(instances)
            }
          else
            nil
          end
        end)
        |> Enum.filter(&(&1 != nil))
        |> Enum.sort_by(& &1.frequency, :desc)

      common_patterns
    end
  end

  @doc """
  Analyze tactical evolution across multiple battles.
  """
  def analyze_tactical_evolution(battle_analyses) do
    # Analyze how tactics and ship usage evolve across multiple battles
    if length(battle_analyses) < 2 do
      %{
        evolution_detected: false,
        message: "Need at least 2 battles to analyze tactical evolution",
        trends: []
      }
    else
      # Sort battles by time to analyze chronological evolution
      sorted_battles =
        Enum.sort_by(battle_analyses, fn analysis ->
          case analysis do
            %{start_time: time} -> time
            %{timestamp: time} -> time
            _ -> ~N[1970-01-01 00:00:00]
          end
        end)

      # Analyze various tactical trends
      doctrine_evolution = analyze_doctrine_evolution(sorted_battles)
      ship_composition_trends = analyze_ship_composition_trends(sorted_battles)

      engagement_pattern_evolution =
        TacticalAnalysisEngine.analyze_engagement_pattern_evolution(sorted_battles)

      tactical_adaptation = analyze_tactical_adaptation(sorted_battles)

      %{
        evolution_detected: true,
        total_battles_analyzed: length(sorted_battles),
        time_span: calculate_analysis_timespan(sorted_battles),
        doctrine_evolution: doctrine_evolution,
        ship_composition_trends: ship_composition_trends,
        engagement_patterns: engagement_pattern_evolution,
        tactical_adaptations: tactical_adaptation,
        summary:
          generate_evolution_summary(
            doctrine_evolution,
            ship_composition_trends,
            engagement_pattern_evolution
          )
      }
    end
  end

  @doc """
  Analyze doctrine evolution across battles.
  """
  def analyze_doctrine_evolution(sorted_battles) do
    # Track how fleet doctrines change over time
    doctrine_timeline =
      sorted_battles
      |> Enum.map(fn battle ->
        %{
          timestamp: get_battle_timestamp(battle),
          doctrines: extract_battle_doctrines(battle),
          effectiveness: get_battle_effectiveness(battle)
        }
      end)

    # Analyze doctrine trends
    doctrine_changes = track_doctrine_changes(doctrine_timeline)
    emerging_doctrines = identify_emerging_doctrines(doctrine_timeline)
    abandoned_doctrines = identify_abandoned_doctrines(doctrine_timeline)

    %{
      timeline: doctrine_timeline,
      changes: doctrine_changes,
      emerging_doctrines: emerging_doctrines,
      abandoned_doctrines: abandoned_doctrines,
      trend_direction: determine_doctrine_trend(doctrine_changes),
      innovation_rate: calculate_innovation_rate(doctrine_timeline)
    }
  end

  @doc """
  Analyze ship composition trends across battles.
  """
  def analyze_ship_composition_trends(sorted_battles) do
    # Track how ship compositions change over time
    composition_timeline =
      sorted_battles
      |> Enum.map(fn battle ->
        %{
          timestamp: get_battle_timestamp(battle),
          ship_classes: extract_ship_class_distribution(battle),
          total_ships: count_total_ships(battle),
          hull_types: categorize_hull_types(battle)
        }
      end)

    # Analyze composition trends
    class_usage_trends = analyze_class_usage_trends(composition_timeline)
    hull_type_evolution = analyze_hull_type_evolution(composition_timeline)

    %{
      timeline: composition_timeline,
      class_trends: class_usage_trends,
      hull_evolution: hull_type_evolution,
      evolution_pattern: determine_composition_evolution_pattern(composition_timeline)
    }
  end

  @doc """
  Analyze tactical adaptation between battles.
  """
  def analyze_tactical_adaptation(sorted_battles) do
    # Look for evidence of tactical adaptation between battles
    adaptations =
      sorted_battles
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.with_index()
      |> Enum.map(fn {[prev_battle, curr_battle], index} ->
        detect_tactical_adaptations(prev_battle, curr_battle, index)
      end)
      |> Enum.filter(& &1.adaptations_detected)

    %{
      adaptation_events: adaptations,
      total_adaptations: length(adaptations),
      adaptation_rate: calculate_adaptation_rate(adaptations, length(sorted_battles)),
      most_common_adaptations: identify_common_adaptation_patterns(adaptations)
    }
  end

  @doc """
  Compare effectiveness trends across battles.
  """
  def compare_effectiveness_trends(battle_analyses) do
    # Delegate to FleetComparisonEngine if available
    FleetComparisonEngine.compare_effectiveness_trends(battle_analyses)
  rescue
    _ -> perform_basic_effectiveness_comparison(battle_analyses)
  end

  @doc """
  Track doctrine changes across a timeline.
  """
  def track_doctrine_changes(doctrine_timeline) do
    doctrine_timeline
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, curr] ->
      prev_doctrines = MapSet.new(prev.doctrines)
      curr_doctrines = MapSet.new(curr.doctrines)

      %{
        timestamp: curr.timestamp,
        added_doctrines: MapSet.difference(curr_doctrines, prev_doctrines),
        removed_doctrines: MapSet.difference(prev_doctrines, curr_doctrines),
        retained_doctrines: MapSet.intersection(prev_doctrines, curr_doctrines)
      }
    end)
  end

  @doc """
  Identify emerging doctrines from timeline.
  """
  def identify_emerging_doctrines(doctrine_timeline) do
    # Find doctrines that appear in later battles but not earlier ones
    if length(doctrine_timeline) < 2 do
      []
    else
      early_battles = Enum.take(doctrine_timeline, div(length(doctrine_timeline), 2))
      late_battles = Enum.drop(doctrine_timeline, div(length(doctrine_timeline), 2))

      early_doctrines =
        early_battles
        |> Enum.flat_map(& &1.doctrines)
        |> MapSet.new()

      late_doctrines =
        late_battles
        |> Enum.flat_map(& &1.doctrines)
        |> MapSet.new()

      MapSet.difference(late_doctrines, early_doctrines)
      |> MapSet.to_list()
    end
  end

  @doc """
  Identify abandoned doctrines from timeline.
  """
  def identify_abandoned_doctrines(doctrine_timeline) do
    # Find doctrines that appear in earlier battles but not later ones
    if length(doctrine_timeline) < 2 do
      []
    else
      early_battles = Enum.take(doctrine_timeline, div(length(doctrine_timeline), 2))
      late_battles = Enum.drop(doctrine_timeline, div(length(doctrine_timeline), 2))

      early_doctrines =
        early_battles
        |> Enum.flat_map(& &1.doctrines)
        |> MapSet.new()

      late_doctrines =
        late_battles
        |> Enum.flat_map(& &1.doctrines)
        |> MapSet.new()

      MapSet.difference(early_doctrines, late_doctrines)
      |> MapSet.to_list()
    end
  end

  @doc """
  Analyze class usage trends across timeline.
  """
  def analyze_class_usage_trends(composition_timeline) do
    # Track how ship class usage changes over time
    all_classes =
      composition_timeline
      |> Enum.flat_map(fn entry -> Map.keys(entry.ship_classes) end)
      |> Enum.uniq()

    all_classes
    |> Enum.map(fn ship_class ->
      usage_data =
        composition_timeline
        |> Enum.map(fn entry ->
          count = Map.get(entry.ship_classes, ship_class, 0)
          percentage = if entry.total_ships > 0, do: count / entry.total_ships * 100, else: 0
          {entry.timestamp, percentage}
        end)

      trend = analyze_usage_trend(usage_data)

      {ship_class,
       %{
         usage_data: usage_data,
         trend: trend,
         average_usage: calculate_average_usage(usage_data)
       }}
    end)
    |> Map.new()
  end

  @doc """
  Detect tactical adaptations between battles.
  """
  def detect_tactical_adaptations(prev_battle, curr_battle, index) do
    # Detect adaptations between consecutive battles
    initial_adaptations = []

    # Check for doctrine adaptations
    prev_doctrines = extract_battle_doctrines(prev_battle)
    curr_doctrines = extract_battle_doctrines(curr_battle)

    doctrine_adaptation = detect_doctrine_adaptation(prev_doctrines, curr_doctrines)

    doctrine_adaptations =
      if doctrine_adaptation,
        do: [doctrine_adaptation | initial_adaptations],
        else: initial_adaptations

    # Check for composition adaptations
    composition_adaptation = detect_composition_adaptation(prev_battle, curr_battle)

    composition_adaptations =
      if composition_adaptation,
        do: [composition_adaptation | doctrine_adaptations],
        else: doctrine_adaptations

    # Check for tactical pattern adaptations
    tactical_adaptation =
      TacticalAnalysisEngine.detect_tactical_adaptation_patterns(prev_battle, curr_battle)

    final_adaptations =
      if tactical_adaptation,
        do: [tactical_adaptation | composition_adaptations],
        else: composition_adaptations

    %{
      battle_transition: "Battle #{index} → Battle #{index + 1}",
      timestamp: get_battle_timestamp(curr_battle),
      adaptations_detected: not Enum.empty?(final_adaptations),
      specific_adaptations: final_adaptations
    }
  end

  @doc """
  Calculate adaptation rate across battles.
  """
  def calculate_adaptation_rate(adaptations, total_battles) do
    if total_battles <= 1 do
      0.0
    else
      Float.round(length(adaptations) / (total_battles - 1) * 100, 1)
    end
  end

  @doc """
  Identify common adaptation patterns.
  """
  def identify_common_adaptation_patterns(adaptations) do
    # Identify most common types of adaptations
    adaptations
    |> Enum.flat_map(& &1.specific_adaptations)
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, instances} ->
      %{
        type: type,
        count: length(instances),
        frequency: Float.round(length(instances) / length(adaptations) * 100, 1)
      }
    end)
    |> Enum.sort_by(& &1.count, :desc)
  end

  @doc """
  Determine doctrine evolution pattern.
  """
  def determine_doctrine_evolution_pattern(battles) do
    if length(battles) < 3 do
      :insufficient_data
    else
      # Extract doctrine sets from battles
      doctrine_sets = Enum.map(battles, &extract_battle_doctrines/1)

      # Calculate changes between consecutive battles
      changes =
        doctrine_sets
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [prev, curr] ->
          prev_set = MapSet.new(prev)
          curr_set = MapSet.new(curr)

          new_doctrines = MapSet.difference(curr_set, prev_set)
          removed_doctrines = MapSet.difference(prev_set, curr_set)

          %{
            new_count: MapSet.size(new_doctrines),
            removed_count: MapSet.size(removed_doctrines),
            total_change: MapSet.size(new_doctrines) + MapSet.size(removed_doctrines)
          }
        end)

      # Determine pattern based on changes
      avg_change = Enum.sum(Enum.map(changes, & &1.total_change)) / length(changes)

      cond do
        avg_change < 0.5 -> :stable
        avg_change < 2.0 -> :gradual_evolution
        avg_change < 4.0 -> :rapid_evolution
        true -> :revolutionary_change
      end
    end
  end

  @doc """
  Determine composition evolution pattern.
  """
  def determine_composition_evolution_pattern(composition_timeline) do
    # Determine overall composition evolution pattern
    if length(composition_timeline) < 2 do
      :insufficient_data
    else
      # Calculate variance in ship class distribution
      class_variances = calculate_class_distribution_variance(composition_timeline)
      avg_variance = Enum.sum(Map.values(class_variances)) / map_size(class_variances)

      cond do
        avg_variance < 0.1 -> :stable_composition
        avg_variance < 0.3 -> :minor_adjustments
        avg_variance < 0.5 -> :moderate_evolution
        avg_variance < 0.7 -> :significant_changes
        true -> :radical_transformation
      end
    end
  end

  @doc """
  Generate evolution summary for battles.
  """
  def generate_evolution_summary(doctrine_evolution, ship_trends, engagement_patterns) do
    # Generate human-readable summary of tactical evolution
    doctrine_summary =
      case doctrine_evolution.trend_direction do
        :innovative -> "Doctrine innovation detected with new approaches emerging"
        :stable -> "Doctrine usage remains consistent"
        :abandoning -> "Older doctrines being phased out"
        _ -> "Mixed doctrine evolution patterns"
      end

    composition_summary =
      case ship_trends.evolution_pattern do
        :stable_composition -> "Ship compositions remain consistent"
        :minor_adjustments -> "Minor tactical adjustments in fleet composition"
        :moderate_evolution -> "Moderate evolution in ship selection"
        :significant_changes -> "Significant changes in fleet composition approach"
        :radical_transformation -> "Radical transformation in fleet composition strategy"
        _ -> "Complex composition evolution"
      end

    engagement_summary =
      case engagement_patterns.trend do
        :evolving -> "Engagement patterns show continuous evolution"
        :stable -> "Engagement approach remains consistent"
        _ -> "Mixed engagement pattern evolution"
      end

    "#{doctrine_summary}. #{composition_summary}. #{engagement_summary}."
  end

  @doc """
  Analyze engagement timing patterns.
  """
  def analyze_engagement_timing_patterns(timeline, efficiency_curve) do
    TacticalAnalysisEngine.analyze_engagement_timing_patterns(timeline, efficiency_curve)
  end

  @doc """
  Analyze duration trends across engagements.
  """
  def analyze_duration_trends(engagement_timeline) do
    durations = Enum.map(engagement_timeline, & &1.duration_seconds)

    %{
      average_duration: calculate_average(durations),
      trend: analyze_trend(durations),
      variance: calculate_variance(durations)
    }
  end

  @doc """
  Analyze intensity trends across engagements.
  """
  def analyze_intensity_trends(engagement_timeline) do
    intensities = Enum.map(engagement_timeline, & &1.intensity_score)

    %{
      average_intensity: calculate_average(intensities),
      trend: analyze_trend(intensities),
      peak_intensity: if(Enum.empty?(intensities), do: 0, else: Enum.max(intensities))
    }
  end

  @doc """
  Analyze complexity trends across engagements.
  """
  def analyze_complexity_trends(engagement_timeline) do
    complexities = Enum.map(engagement_timeline, & &1.tactical_complexity)

    %{
      average_complexity: calculate_average(complexities),
      trend: analyze_trend(complexities),
      complexity_evolution: determine_complexity_evolution(complexities)
    }
  end

  @doc """
  Analyze hull type evolution across timeline.
  """
  def analyze_hull_type_evolution(composition_timeline) do
    # Track evolution of hull type preferences
    hull_distributions =
      composition_timeline
      |> Enum.map(fn entry ->
        {entry.timestamp, entry.hull_types}
      end)

    %{
      timeline: hull_distributions,
      dominant_shifts: identify_hull_dominance_shifts(hull_distributions),
      diversification_trend: analyze_hull_diversification(hull_distributions)
    }
  end

  # Private helper functions

  defp extract_patterns_from_battle(analysis) do
    patterns = []

    # Extract tactical patterns
    tactical_patterns =
      case analysis do
        %{tactical_analysis: %{patterns: patterns}} -> patterns
        %{tactical_patterns: patterns} -> patterns
        _ -> []
      end

    # Extract positioning patterns
    positioning_patterns =
      case analysis do
        %{positioning_analysis: %{patterns: patterns}} -> patterns
        %{positioning_patterns: patterns} -> patterns
        _ -> []
      end

    patterns ++ tactical_patterns ++ positioning_patterns
  end

  defp calculate_pattern_confidence(instances) do
    # Base confidence on consistency and frequency
    if length(instances) < 2 do
      0.0
    else
      base_confidence = min(0.9, length(instances) * 0.2)
      Float.round(base_confidence, 2)
    end
  end

  defp get_battle_timestamp(battle) do
    case battle do
      %{start_time: time} -> time
      %{timestamp: time} -> time
      %{battle_time: time} -> time
      _ -> ~N[1970-01-01 00:00:00]
    end
  end

  defp extract_battle_doctrines(battle) do
    case battle do
      %{doctrine_analysis: %{detected_doctrines: doctrines}} -> doctrines
      %{fleet_analysis: %{doctrines: doctrines}} -> doctrines
      %{detected_doctrines: doctrines} -> doctrines
      _ -> []
    end
  end

  defp get_battle_effectiveness(battle) do
    case battle do
      %{effectiveness: eff} -> eff
      %{tactical_effectiveness: eff} -> eff
      %{performance: %{effectiveness: eff}} -> eff
      _ -> 0.5
    end
  end

  defp calculate_analysis_timespan(sorted_battles) do
    if length(sorted_battles) < 2 do
      0
    else
      first_time = get_battle_timestamp(List.first(sorted_battles))
      last_time = get_battle_timestamp(List.last(sorted_battles))

      # Calculate difference in days
      NaiveDateTime.diff(last_time, first_time, :day)
    end
  end

  defp determine_doctrine_trend(doctrine_changes) do
    if Enum.empty?(doctrine_changes) do
      :stable
    else
      # Count additions vs removals
      total_additions =
        doctrine_changes
        |> Enum.map(fn change -> MapSet.size(change.added_doctrines) end)
        |> Enum.sum()

      total_removals =
        doctrine_changes
        |> Enum.map(fn change -> MapSet.size(change.removed_doctrines) end)
        |> Enum.sum()

      cond do
        total_additions > total_removals * 2 -> :innovative
        total_removals > total_additions * 2 -> :abandoning
        abs(total_additions - total_removals) < 3 -> :stable
        true -> :evolving
      end
    end
  end

  defp calculate_innovation_rate(doctrine_timeline) do
    if length(doctrine_timeline) < 2 do
      0.0
    else
      # Calculate rate of new doctrine introduction
      changes = track_doctrine_changes(doctrine_timeline)

      new_doctrine_count =
        changes
        |> Enum.map(fn change -> MapSet.size(change.added_doctrines) end)
        |> Enum.sum()

      Float.round(new_doctrine_count / length(changes), 1)
    end
  end

  defp extract_ship_class_distribution(battle) do
    case battle do
      %{fleet_analysis: %{ship_classes: classes}} -> classes
      %{ship_composition: %{by_class: classes}} -> classes
      %{ship_classes: classes} -> classes
      _ -> %{}
    end
  end

  defp count_total_ships(battle) do
    case battle do
      %{fleet_analysis: %{total_ships: count}} -> count
      %{participant_count: count} -> count
      %{total_ships: count} -> count
      _ -> 0
    end
  end

  defp categorize_hull_types(battle) do
    ship_classes = extract_ship_class_distribution(battle)

    %{
      subcapital: count_subcapital_ships(ship_classes),
      capital: count_capital_ships(ship_classes),
      support: count_support_ships(ship_classes)
    }
  end

  defp count_subcapital_ships(ship_classes) do
    subcap_classes = [:frigate, :destroyer, :cruiser, :battlecruiser, :battleship]

    ship_classes
    |> Enum.filter(fn {class, _count} -> class in subcap_classes end)
    |> Enum.map(fn {_class, count} -> count end)
    |> Enum.sum()
  end

  defp count_capital_ships(ship_classes) do
    capital_classes = [:carrier, :dreadnought, :supercarrier, :titan]

    ship_classes
    |> Enum.filter(fn {class, _count} -> class in capital_classes end)
    |> Enum.map(fn {_class, count} -> count end)
    |> Enum.sum()
  end

  defp count_support_ships(ship_classes) do
    support_classes = [:logistics, :command, :ewar, :interdictor]

    ship_classes
    |> Enum.filter(fn {class, _count} -> class in support_classes end)
    |> Enum.map(fn {_class, count} -> count end)
    |> Enum.sum()
  end

  defp analyze_usage_trend(usage_data) do
    if length(usage_data) < 2 do
      :stable
    else
      values = Enum.map(usage_data, fn {_time, value} -> value end)

      # Simple trend analysis
      first_half = Enum.take(values, div(length(values), 2))
      second_half = Enum.drop(values, div(length(values), 2))

      first_avg = calculate_average(first_half)
      second_avg = calculate_average(second_half)

      cond do
        second_avg > first_avg * 1.2 -> :increasing
        second_avg < first_avg * 0.8 -> :decreasing
        true -> :stable
      end
    end
  end

  defp calculate_average_usage(usage_data) do
    if Enum.empty?(usage_data) do
      0.0
    else
      values = Enum.map(usage_data, fn {_time, value} -> value end)
      Float.round(Enum.sum(values) / length(values), 1)
    end
  end

  defp detect_doctrine_adaptation(prev_doctrines, curr_doctrines) do
    prev_set = MapSet.new(prev_doctrines)
    curr_set = MapSet.new(curr_doctrines)

    if MapSet.disjoint?(prev_set, curr_set) and not Enum.empty?(prev_doctrines) do
      %{
        type: :doctrine_adaptation,
        description: "Complete doctrine change detected",
        previous_doctrines: prev_doctrines,
        new_doctrines: curr_doctrines
      }
    else
      nil
    end
  end

  defp detect_composition_adaptation(prev_battle, curr_battle) do
    prev_comp = extract_ship_class_distribution(prev_battle)
    curr_comp = extract_ship_class_distribution(curr_battle)

    # Check for significant composition changes
    significant_changes =
      identify_significant_composition_changes(prev_comp, curr_comp)

    if not Enum.empty?(significant_changes) do
      %{
        type: :composition_adaptation,
        description: "Significant fleet composition changes",
        changes: significant_changes
      }
    else
      nil
    end
  end

  defp identify_significant_composition_changes(prev_comp, curr_comp) do
    all_classes =
      prev_comp
      |> Map.keys()
      |> MapSet.new()
      |> MapSet.union(MapSet.new(Map.keys(curr_comp)))

    all_classes
    |> Enum.map(fn ship_class ->
      prev_count = Map.get(prev_comp, ship_class, 0)
      curr_count = Map.get(curr_comp, ship_class, 0)

      change_ratio =
        if prev_count > 0 do
          (curr_count - prev_count) / prev_count
        else
          if curr_count > 0, do: 1.0, else: 0.0
        end

      if abs(change_ratio) > 0.5 do
        %{
          ship_class: ship_class,
          change: if(change_ratio > 0, do: :increased, else: :decreased),
          magnitude: Float.round(abs(change_ratio) * 100, 1)
        }
      else
        nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp perform_basic_effectiveness_comparison(battle_analyses) do
    effectiveness_values =
      battle_analyses
      |> Enum.map(&get_battle_effectiveness/1)

    %{
      average_effectiveness: calculate_average(effectiveness_values),
      trend: analyze_trend(effectiveness_values),
      improvement_rate: calculate_improvement_rate(effectiveness_values)
    }
  end

  defp calculate_average(values) do
    if Enum.empty?(values) do
      0.0
    else
      Float.round(Enum.sum(values) / length(values), 2)
    end
  end

  defp calculate_variance(values) do
    if length(values) < 2 do
      0.0
    else
      avg = calculate_average(values)

      variance =
        values
        |> Enum.map(fn value -> :math.pow(value - avg, 2) end)
        |> Enum.sum()
        |> Kernel./(length(values))

      Float.round(variance, 2)
    end
  end

  defp analyze_trend(values) do
    if length(values) < 2 do
      :stable
    else
      # Simple linear trend
      first = List.first(values)
      last = List.last(values)

      cond do
        last > first * 1.1 -> :increasing
        last < first * 0.9 -> :decreasing
        true -> :stable
      end
    end
  end

  defp calculate_improvement_rate(effectiveness_values) do
    if length(effectiveness_values) < 2 do
      0.0
    else
      improvements =
        effectiveness_values
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [prev, curr] -> curr > prev end)
        |> Enum.count(& &1)

      Float.round(improvements / (length(effectiveness_values) - 1) * 100, 1)
    end
  end

  defp calculate_class_distribution_variance(composition_timeline) do
    if length(composition_timeline) < 2 do
      %{}
    else
      # Get all ship classes
      all_classes =
        composition_timeline
        |> Enum.flat_map(fn entry -> Map.keys(entry.ship_classes) end)
        |> Enum.uniq()

      # Calculate variance for each class
      all_classes
      |> Enum.map(fn ship_class ->
        percentages =
          composition_timeline
          |> Enum.map(fn entry ->
            count = Map.get(entry.ship_classes, ship_class, 0)
            if entry.total_ships > 0, do: count / entry.total_ships, else: 0
          end)

        {ship_class, calculate_variance(percentages)}
      end)
      |> Map.new()
    end
  end

  defp determine_complexity_evolution(complexities) do
    trend = analyze_trend(complexities)

    case trend do
      :increasing -> :increasing_sophistication
      :decreasing -> :simplification
      :stable -> :consistent_complexity
    end
  end

  defp identify_hull_dominance_shifts(hull_distributions) do
    if length(hull_distributions) < 2 do
      []
    else
      hull_distributions
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [{_prev_time, prev_hulls}, {curr_time, curr_hulls}] ->
        prev_dominant = find_dominant_hull_type(prev_hulls)
        curr_dominant = find_dominant_hull_type(curr_hulls)

        if prev_dominant != curr_dominant do
          %{
            timestamp: curr_time,
            shift: "#{prev_dominant} → #{curr_dominant}"
          }
        else
          nil
        end
      end)
      |> Enum.filter(&(&1 != nil))
    end
  end

  defp find_dominant_hull_type(hull_types) do
    {dominant, _count} =
      hull_types
      |> Enum.max_by(fn {_type, count} -> count end, fn -> {:unknown, 0} end)

    dominant
  end

  defp analyze_hull_diversification(hull_distributions) do
    if Enum.empty?(hull_distributions) do
      :stable
    else
      # Calculate diversity scores
      diversity_scores =
        hull_distributions
        |> Enum.map(fn {_time, hulls} ->
          total = Enum.sum(Map.values(hulls))

          if total > 0 do
            # Shannon diversity index
            hulls
            |> Map.values()
            |> Enum.map(fn count -> count / total end)
            |> Enum.filter(&(&1 > 0))
            |> Enum.map(fn p -> -p * :math.log(p) end)
            |> Enum.sum()
          else
            0
          end
        end)

      trend = analyze_trend(diversity_scores)

      case trend do
        :increasing -> :diversifying
        :decreasing -> :specializing
        :stable -> :stable_diversity
      end
    end
  end
end
