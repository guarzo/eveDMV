defmodule EveDmv.Shared.Correlation.Facade do
  @moduledoc """
  Facade for the correlation analysis system providing backward compatibility.

  Coordinates between the modular correlation components:
  - SystemActivityCollector: Fetches and processes activity data
  - TimelineManager: Timeline building and management
  - TemporalCorrelationAnalyzer: Statistical correlation analysis

  Maintains the same interface as the original ActivityCorrelator.
  """
  """

  alias EveDmv.Shared.Correlation.SystemActivityCollector
  alias EveDmv.Shared.Correlation.TemporalCorrelationAnalyzer
  alias EveDmv.Shared.Correlation.TimelineManager

  require Logger

  @doc """
  Fetches activity data for multiple systems within a time window.
  """
  def fetch_system_activities(system_ids, time_window_hours) do
    SystemActivityCollector.fetch_system_activities(system_ids, time_window_hours)
  end

  @doc """
  Builds a comprehensive activity timeline from system activities.
  """
  def build_activity_timeline(system_activities) do
    TimelineManager.build_activity_timeline(system_activities)
  end

  @doc """
  Analyzes temporal correlations between activities in timeline.
  """
  def analyze_temporal_correlations(activity_timeline) do
    TemporalCorrelationAnalyzer.analyze_temporal_correlations(activity_timeline)
  end

  @doc """
  Tracks pilot movements across systems.
  """
  def track_pilot_movements(system_activities) do
    # Extract pilot movement data from system activities
    pilot_movements =
      Enum.flat_map(system_activities, fn system_data ->
        pilots = Map.keys(system_data.pilot_activity)

        Enum.map(pilots, fn pilot_id ->
          pilot_data = system_data.pilot_activity[pilot_id]

          %{
            pilot_id: pilot_id,
            system_id: system_data.system_id,
            activity_count: pilot_data.participations,
            systems_visited: pilot_data.systems_active,
            movement_pattern: analyze_pilot_movement_pattern(pilot_data)
          }
        end)
      end)

    # Group by pilot to track cross-system movements
    pilot_movement_analysis =
      pilot_movements
      |> Enum.group_by(& &1.pilot_id)
      |> Enum.map(fn {pilot_id, movements} ->
        systems_visited = movements |> Enum.flat_map(& &1.systems_visited) |> Enum.uniq()
        total_activity = movements |> Enum.map(& &1.activity_count) |> Enum.sum()

        %{
          pilot_id: pilot_id,
          systems_visited: systems_visited,
          system_count: length(systems_visited),
          total_activity: total_activity,
          movement_frequency:
            classify_movement_frequency(length(systems_visited), total_activity),
          primary_system: find_primary_system(movements)
        }
      end)

    %{
      total_pilots_tracked: length(pilot_movement_analysis),
      multi_system_pilots: Enum.count(pilot_movement_analysis, &(&1.system_count > 1)),
      pilot_movements: pilot_movement_analysis,
      movement_summary: summarize_movement_patterns(pilot_movement_analysis)
    }
  end

  @doc """
  Analyzes corporation activities across systems.
  """
  def analyze_corp_activities(system_activities) do
    corp_analysis =
      Enum.flat_map(system_activities, fn system_data ->
        corps = Map.keys(system_data.corp_activity)

        Enum.map(corps, fn corp_id ->
          corp_data = system_data.corp_activity[corp_id]

          %{
            corp_id: corp_id,
            system_id: system_data.system_id,
            activity_level: corp_data.engagement_type,
            systems_active: corp_data.systems_active,
            member_count: corp_data.member_count,
            preferred_ships: corp_data.preferred_ships
          }
        end)
      end)

    # Group by corporation
    corp_summaries =
      corp_analysis
      |> Enum.group_by(& &1.corp_id)
      |> Enum.map(fn {corp_id, activities} ->
        all_systems = activities |> Enum.flat_map(& &1.systems_active) |> Enum.uniq()
        total_members = activities |> Enum.map(& &1.member_count) |> Enum.max(fn -> 0 end)

        %{
          corp_id: corp_id,
          systems_active: all_systems,
          system_count: length(all_systems),
          estimated_active_members: total_members,
          activity_distribution: analyze_corp_activity_distribution(activities),
          corp_classification: classify_corp_activity(activities)
        }
      end)

    # Identify potential alliances and conflicts
    alliance_analysis = identify_potential_alliances(corp_summaries)
    conflict_analysis = identify_potential_conflicts(corp_summaries)

    %{
      corporations_analyzed: length(corp_summaries),
      corp_summaries: corp_summaries,
      alliance_indicators: alliance_analysis,
      conflict_indicators: conflict_analysis,
      multi_system_corps: Enum.count(corp_summaries, &(&1.system_count > 1))
    }
  end

  @doc """
  Identifies activity bursts within timeline events.
  """
  def identify_activity_bursts(timeline_events) do
    TimelineManager.identify_activity_bursts(timeline_events)
  end

  @doc """
  Calculates correlation between two activity sequences.
  """
  def calculate_activity_correlation(activities1, activities2, options \\ []) do
    TemporalCorrelationAnalyzer.calculate_activity_correlation(activities1, activities2, options)
  end

  @doc """
  Identifies lag relationships between system activities.
  """
  def identify_lag_relationships(system_timelines, options \\ []) do
    TemporalCorrelationAnalyzer.identify_lag_relationships(system_timelines, options)
  end

  @doc """
  Detects synchronized activity patterns across systems.
  """
  def detect_synchronized_patterns(system_timelines, options \\ []) do
    TemporalCorrelationAnalyzer.detect_synchronized_patterns(system_timelines, options)
  end

  @doc """
  Analyzes activity dependencies between systems.
  """
  def analyze_activity_dependencies(system_timelines, options \\ []) do
    TemporalCorrelationAnalyzer.analyze_activity_dependencies(system_timelines, options)
  end

  @doc """
  Creates time-windowed views of the timeline.
  """
  def create_timeline_windows(timeline_events, window_size_minutes) do
    TimelineManager.create_timeline_windows(timeline_events, window_size_minutes)
  end

  @doc """
  Identifies coordinated operations from timeline analysis.
  """
  def identify_coordinated_operations(timeline_events) do
    TimelineManager.identify_coordinated_operations(timeline_events)
  end

  @doc """
  Calculates comprehensive timeline statistics.
  """
  def calculate_timeline_statistics(timeline_events) do
    TimelineManager.calculate_timeline_statistics(timeline_events)
  end

  # Private helper functions

  defp analyze_pilot_movement_pattern(pilot_data) do
    system_count = length(pilot_data.systems_active)
    activity_frequency = pilot_data.activity_frequency

    case {system_count, activity_frequency} do
      {1, _} -> :stationary
      {count, :very_high} when count >= 3 -> :highly_mobile
      {count, freq} when count >= 2 and freq in [:high, :moderate] -> :mobile
      {count, _} when count >= 2 -> :occasional_traveler
      _ -> :stationary
    end
  end

  defp classify_movement_frequency(system_count, total_activity) do
    mobility_score = system_count * (total_activity / 10)

    cond do
      mobility_score >= 20 -> :very_high
      mobility_score >= 10 -> :high
      mobility_score >= 5 -> :moderate
      mobility_score >= 2 -> :low
      true -> :minimal
    end
  end

  defp find_primary_system(movements) do
    movements
    |> Enum.max_by(& &1.activity_count, fn -> %{system_id: nil} end)
    |> Map.get(:system_id)
  end

  defp summarize_movement_patterns(pilot_movements) do
    total_pilots = length(pilot_movements)

    if total_pilots == 0 do
      %{total_pilots: 0, patterns: %{}}
    else
      pattern_distribution =
        pilot_movements
        |> Enum.map(& &1.movement_frequency)
        |> Enum.frequencies()

      avg_systems_per_pilot =
        pilot_movements
        |> Enum.map(& &1.system_count)
        |> Enum.sum()
        |> Kernel./(total_pilots)

      %{
        total_pilots: total_pilots,
        pattern_distribution: pattern_distribution,
        average_systems_per_pilot: Float.round(avg_systems_per_pilot, 1),
        most_mobile_pilots:
          Enum.count(pilot_movements, &(&1.movement_frequency in [:very_high, :high]))
      }
    end
  end

  defp analyze_corp_activity_distribution(activities) do
    # Analyze how corporation activity is distributed across systems
    system_activities =
      activities
      |> Enum.group_by(& &1.system_id)
      |> Enum.map(fn {system_id, system_activities} ->
        total_members = system_activities |> Enum.map(& &1.member_count) |> Enum.sum()
        {system_id, total_members}
      end)
      |> Map.new()

    total_activity = system_activities |> Map.values() |> Enum.sum()

    if total_activity > 0 do
      # Calculate concentration
      max_system_activity = system_activities |> Map.values() |> Enum.max(fn -> 0 end)
      concentration = max_system_activity / total_activity

      %{
        system_distribution: system_activities,
        total_activity: total_activity,
        concentration: Float.round(concentration, 3),
        distribution_type: classify_distribution_type(concentration)
      }
    else
      %{
        system_distribution: %{},
        total_activity: 0,
        concentration: 0.0,
        distribution_type: :no_activity
      }
    end
  end

  defp classify_distribution_type(concentration) do
    cond do
      concentration >= 0.8 -> :highly_concentrated
      concentration >= 0.6 -> :concentrated
      concentration >= 0.4 -> :moderately_distributed
      true -> :widely_distributed
    end
  end

  defp classify_corp_activity(activities) do
    system_count = activities |> Enum.map(& &1.system_id) |> Enum.uniq() |> length()
    max_members = activities |> Enum.map(& &1.member_count) |> Enum.max(fn -> 0 end)

    cond do
      system_count >= 5 and max_members >= 50 -> :major_alliance_corp
      system_count >= 3 and max_members >= 20 -> :regional_corp
      system_count >= 2 and max_members >= 10 -> :active_corp
      max_members >= 5 -> :small_corp
      true -> :minimal_corp
    end
  end

  defp identify_potential_alliances(corp_summaries) do
    # Look for corporations operating in the same systems
    system_corps =
      corp_summaries
      |> Enum.flat_map(fn corp ->
        Enum.map(corp.systems_active, fn system_id ->
          {system_id, corp.corp_id}
        end)
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    # Find systems with multiple active corporations
    potential_alliances =
      system_corps
      |> Enum.filter(fn {_system_id, corps} -> length(corps) >= 2 end)
      |> Enum.map(fn {system_id, corps} ->
        %{
          system_id: system_id,
          corporations: corps,
          corp_count: length(corps),
          alliance_likelihood: assess_alliance_likelihood(corps, corp_summaries)
        }
      end)
      |> Enum.filter(&(&1.alliance_likelihood >= 0.6))

    %{
      potential_alliances: potential_alliances,
      total_alliance_systems: length(potential_alliances)
    }
  end

  defp identify_potential_conflicts(corp_summaries) do
    # Look for overlapping territories that might indicate conflicts
    _territorial_overlaps = []

    # Compare each pair of corporations
    corp_pairs =
      for corp1 <- corp_summaries,
          corp2 <- corp_summaries,
          corp1.corp_id < corp2.corp_id,
          do: {corp1, corp2}

    conflicts =
      Enum.reduce(corp_pairs, [], fn {corp1, corp2}, acc ->
        common_systems = corp1.systems_active -- corp1.systems_active -- corp2.systems_active

        if length(common_systems) >= 2 do
          conflict_likelihood = assess_conflict_likelihood(corp1, corp2, common_systems)

          if conflict_likelihood >= 0.5 do
            conflict = %{
              corp1: corp1.corp_id,
              corp2: corp2.corp_id,
              contested_systems: common_systems,
              conflict_likelihood: conflict_likelihood
            }

            [conflict | acc]
          else
            acc
          end
        else
          acc
        end
      end)

    %{
      potential_conflicts: conflicts,
      total_conflicts: length(conflicts)
    }
  end

  defp assess_alliance_likelihood(corps, corp_summaries) do
    # Simple alliance likelihood based on corp sizes and activity patterns
    corp_data = Enum.filter(corp_summaries, fn corp -> corp.corp_id in corps end)

    if length(corp_data) < 2 do
      0.0
    else
      # Alliances more likely with similarly sized, active corporations
      member_counts = Enum.map(corp_data, & &1.estimated_active_members)

      activity_levels =
        Enum.map(corp_data, fn corp ->
          case corp.corp_classification do
            :major_alliance_corp -> 5
            :regional_corp -> 4
            :active_corp -> 3
            :small_corp -> 2
            _ -> 1
          end
        end)

      # Calculate similarity scores
      member_similarity = calculate_similarity_score(member_counts)
      activity_similarity = calculate_similarity_score(activity_levels)

      # Higher similarity suggests alliance potential
      Float.round((member_similarity + activity_similarity) / 2, 3)
    end
  end

  defp assess_conflict_likelihood(corp1, corp2, common_systems) do
    # Conflict more likely with different sized corps in same territory
    size_diff = abs(corp1.estimated_active_members - corp2.estimated_active_members)
    territory_overlap = length(common_systems)

    # More overlap and size difference = higher conflict likelihood
    overlap_score = min(1.0, territory_overlap / 3.0)
    size_score = min(1.0, size_diff / 20.0)

    Float.round((overlap_score + size_score) / 2, 3)
  end

  defp calculate_similarity_score(values) do
    if length(values) < 2 do
      1.0
    else
      mean = Enum.sum(values) / length(values)

      if mean > 0 do
        variance =
          values
          |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
          |> Enum.sum()
          |> Kernel./(length(values))

        cv = :math.sqrt(variance) / mean

        # Lower coefficient of variation = higher similarity
        Float.round(1.0 / (1.0 + cv), 3)
      else
        1.0
      end
    end
  end
end
