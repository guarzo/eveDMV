defmodule EveDmv.Shared.Strategic.Patterns.TerritorialPattern do
  @moduledoc """
  Identifies territorial control and expansion patterns.

  Responsible for:
  - Territorial expansion pattern detection
  - Defensive consolidation identification
  - Control zone analysis
  - Territory stability assessment
  """

  alias EveDmv.Core.Utils.DateTimeUtils

  require Logger

  @territorial_control_threshold 0.6
  # @expansion_threshold 0.3  # Currently unused

  @doc """
  Identifies territorial expansion patterns.
  """
  def identify_territorial_expansion(strategic_data) do
    case strategic_data.scope do
      :multi_system ->
        analyze_multi_system_expansion(strategic_data)

      :single_system ->
        %{
          type: :territorial_expansion,
          category: :territorial,
          confidence: 0.0,
          description: "Single system - no expansion pattern possible",
          indicators: []
        }
    end
  end

  @doc """
  Identifies defensive consolidation patterns.
  """
  def identify_defensive_consolidation(strategic_data) do
    metrics = calculate_consolidation_metrics(strategic_data)
    indicators = identify_consolidation_indicators(strategic_data, metrics)

    confidence = calculate_consolidation_confidence(indicators, metrics)

    %{
      type: :defensive_consolidation,
      category: :territorial,
      confidence: confidence,
      description: describe_consolidation_pattern(indicators, metrics),
      metrics: metrics,
      indicators: indicators,
      spatial_data: extract_spatial_data(strategic_data),
      temporal_data: extract_temporal_data(strategic_data)
    }
  end

  @doc """
  Analyzes control zones within territories.
  """
  def analyze_control_zones(strategic_data) do
    case strategic_data.scope do
      :multi_system ->
        systems = extract_systems(strategic_data)
        activity_levels = calculate_system_activity_levels(strategic_data)

        zones = identify_control_zones(systems, activity_levels)
        stability = assess_zone_stability(zones, strategic_data)

        %{
          control_zones: zones,
          zone_stability: stability,
          dominant_entities: identify_dominant_entities(zones, strategic_data),
          contested_areas: identify_contested_areas(zones, activity_levels)
        }

      :single_system ->
        %{
          control_zones: [%{systems: [strategic_data.system_id], control_level: 1.0}],
          zone_stability: 1.0,
          dominant_entities: [],
          contested_areas: []
        }
    end
  end

  # Private functions

  defp analyze_multi_system_expansion(strategic_data) do
    time_windows = create_analysis_windows(strategic_data.time_range)

    expansion_metrics =
      time_windows
      |> Enum.map(fn window ->
        calculate_window_expansion(strategic_data, window)
      end)

    indicators = identify_expansion_indicators(expansion_metrics, strategic_data)
    confidence = calculate_expansion_confidence(indicators, expansion_metrics)

    %{
      type: :territorial_expansion,
      category: :territorial,
      confidence: confidence,
      description: describe_expansion_pattern(indicators, expansion_metrics),
      metrics: aggregate_expansion_metrics(expansion_metrics),
      indicators: indicators,
      spatial_data: extract_spatial_data(strategic_data),
      temporal_data: extract_temporal_data(strategic_data),
      expansion_trajectory: determine_expansion_trajectory(expansion_metrics)
    }
  end

  defp create_analysis_windows(time_range) do
    total_duration = DateTimeUtils.diff(time_range.until, time_range.since, :hour)
    # At least daily windows
    window_size = max(24, div(total_duration, 7))

    Stream.unfold(time_range.since, fn current ->
      if DateTimeUtils.compare(current, time_range.until) == :lt do
        window_end = DateTimeUtils.add(current, window_size * 3600, :second)

        window_end =
          if DateTimeUtils.compare(window_end, time_range.until) == :gt do
            time_range.until
          else
            window_end
          end

        {{current, window_end}, window_end}
      else
        nil
      end
    end)
    |> Enum.to_list()
  end

  defp calculate_window_expansion(strategic_data, {window_start, window_end}) do
    active_systems =
      strategic_data.killmail_data
      |> Enum.filter(fn system_data ->
        has_activity_in_window?(system_data.killmails, window_start, window_end)
      end)
      |> Enum.map(& &1.system_id)

    entity_presence = calculate_entity_presence(strategic_data, window_start, window_end)

    %{
      window: {window_start, window_end},
      active_systems: active_systems,
      system_count: length(active_systems),
      entity_spread: calculate_entity_spread(entity_presence),
      activity_intensity: calculate_window_intensity(strategic_data, window_start, window_end)
    }
  end

  defp has_activity_in_window?(killmails, window_start, window_end) do
    Enum.any?(killmails, fn km ->
      DateTimeUtils.compare(km.timestamp, window_start) != :lt &&
        DateTimeUtils.compare(km.timestamp, window_end) == :lt
    end)
  end

  defp calculate_entity_presence(strategic_data, window_start, window_end) do
    strategic_data.killmail_data
    |> Enum.flat_map(fn system_data ->
      system_data.killmails
      |> Enum.filter(fn km ->
        DateTimeUtils.compare(km.timestamp, window_start) != :lt &&
          DateTimeUtils.compare(km.timestamp, window_end) == :lt
      end)
      |> Enum.flat_map(fn km ->
        entities =
          [km.victim.corporation_id | Enum.map(km.attackers, & &1.corporation_id)]
          |> Enum.reject(&is_nil/1)

        Enum.map(entities, fn entity -> {entity, system_data.system_id} end)
      end)
    end)
    |> Enum.group_by(fn {entity, _} -> entity end, fn {_, system} -> system end)
    |> Enum.map(fn {entity, systems} -> {entity, Enum.uniq(systems)} end)
    |> Map.new()
  end

  defp calculate_entity_spread(entity_presence) do
    if map_size(entity_presence) == 0 do
      0.0
    else
      spreads = Enum.map(entity_presence, fn {_, systems} -> length(systems) end)
      Enum.sum(spreads) / length(spreads)
    end
  end

  defp calculate_window_intensity(strategic_data, window_start, window_end) do
    kill_count =
      strategic_data.killmail_data
      |> Enum.map(fn system_data ->
        Enum.count(system_data.killmails, fn km ->
          DateTimeUtils.compare(km.timestamp, window_start) != :lt &&
            DateTimeUtils.compare(km.timestamp, window_end) == :lt
        end)
      end)
      |> Enum.sum()

    hours = DateTimeUtils.diff(window_end, window_start, :hour)
    if hours > 0, do: kill_count / hours, else: 0.0
  end

  defp identify_expansion_indicators(expansion_metrics, _strategic_data) do
    indicators = []

    # System count increase
    system_counts = Enum.map(expansion_metrics, & &1.system_count)

    if length(system_counts) >= 2 do
      first = List.first(system_counts)
      last = List.last(system_counts)

      if last > first do
        indicators ++ [{:system_count_increase, (last - first) / first}]
      else
        indicators
      end
    else
      indicators
    end

    # Entity spread increase
    |> then(fn indicators ->
      spreads = Enum.map(expansion_metrics, & &1.entity_spread)

      if length(spreads) >= 2 && List.last(spreads) > List.first(spreads) do
        indicators ++ [{:entity_spread_increase, List.last(spreads) - List.first(spreads)}]
      else
        indicators
      end
    end)

    # New system activity
    |> then(fn indicators ->
      all_systems =
        expansion_metrics
        |> Enum.flat_map(& &1.active_systems)
        |> Enum.uniq()

      early_systems =
        expansion_metrics
        |> Enum.take(max(1, div(length(expansion_metrics), 3)))
        |> Enum.flat_map(& &1.active_systems)
        |> Enum.uniq()

      new_systems = length(all_systems) - length(early_systems)

      if new_systems > 0 do
        indicators ++ [{:new_system_activity, new_systems}]
      else
        indicators
      end
    end)
  end

  defp calculate_expansion_confidence(indicators, expansion_metrics) do
    base_confidence = length(indicators) * 0.2

    # Trend consistency bonus
    trend_bonus =
      if shows_consistent_trend?(expansion_metrics) do
        0.2
      else
        0.0
      end

    # Activity level bonus
    activity_bonus =
      if sufficient_activity?(expansion_metrics) do
        0.1
      else
        0.0
      end

    min(1.0, base_confidence + trend_bonus + activity_bonus)
  end

  defp shows_consistent_trend?(expansion_metrics) do
    system_counts = Enum.map(expansion_metrics, & &1.system_count)

    if length(system_counts) >= 3 do
      differences =
        system_counts
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [a, b] -> b - a end)

      # All positive or all non-negative
      Enum.all?(differences, &(&1 >= 0)) || Enum.all?(differences, &(&1 <= 0))
    else
      false
    end
  end

  defp sufficient_activity?(expansion_metrics) do
    total_activity =
      expansion_metrics
      |> Enum.map(& &1.activity_intensity)
      |> Enum.sum()

    total_activity >= 10.0
  end

  defp describe_expansion_pattern(indicators, _expansion_metrics) do
    indicator_types = Enum.map(indicators, fn {type, _} -> type end)

    cond do
      :system_count_increase in indicator_types && :entity_spread_increase in indicator_types ->
        "Aggressive territorial expansion with increased presence across multiple systems"

      :system_count_increase in indicator_types ->
        "Territorial expansion into new systems"

      :entity_spread_increase in indicator_types ->
        "Consolidating control within existing territory"

      :new_system_activity in indicator_types ->
        "Exploratory expansion into previously uncontested systems"

      true ->
        "Limited territorial activity detected"
    end
  end

  defp aggregate_expansion_metrics(expansion_metrics) do
    %{
      total_systems:
        expansion_metrics
        |> Enum.flat_map(& &1.active_systems)
        |> Enum.uniq()
        |> length(),
      average_spread:
        expansion_metrics
        |> Enum.map(& &1.entity_spread)
        |> then(fn spreads ->
          if Enum.empty?(spreads), do: 0.0, else: Enum.sum(spreads) / length(spreads)
        end),
      peak_activity:
        expansion_metrics
        |> Enum.map(& &1.activity_intensity)
        |> Enum.max(fn -> 0.0 end)
    }
  end

  defp determine_expansion_trajectory(expansion_metrics) do
    if length(expansion_metrics) < 2 do
      :insufficient_data
    else
      system_progression = Enum.map(expansion_metrics, & &1.system_count)

      first_half_avg =
        system_progression
        |> Enum.take(div(length(system_progression), 2))
        |> average()

      second_half_avg =
        system_progression
        |> Enum.drop(div(length(system_progression), 2))
        |> average()

      cond do
        second_half_avg > first_half_avg * 1.2 -> :accelerating
        second_half_avg < first_half_avg * 0.8 -> :decelerating
        true -> :steady
      end
    end
  end

  defp average(list) do
    if Enum.empty?(list) do
      0.0
    else
      Enum.sum(list) / length(list)
    end
  end

  defp calculate_consolidation_metrics(strategic_data) do
    case strategic_data.scope do
      :multi_system ->
        %{
          system_concentration: calculate_system_concentration(strategic_data),
          defensive_activity: calculate_defensive_activity(strategic_data),
          response_times: calculate_response_times(strategic_data),
          force_concentration: calculate_force_concentration(strategic_data)
        }

      :single_system ->
        %{
          system_concentration: 1.0,
          defensive_activity: calculate_single_system_defensive_activity(strategic_data),
          response_times: 0.0,
          force_concentration: 1.0
        }
    end
  end

  defp calculate_system_concentration(strategic_data) do
    total_kills =
      strategic_data.killmail_data
      |> Enum.map(& &1.kill_count)
      |> Enum.sum()

    if total_kills == 0 do
      0.0
    else
      # Herfindahl index for concentration
      strategic_data.killmail_data
      |> Enum.map(fn data ->
        share = data.kill_count / total_kills
        share * share
      end)
      |> Enum.sum()
      |> then(&Float.round(&1, 3))
    end
  end

  defp calculate_defensive_activity(strategic_data) do
    killmails =
      strategic_data.killmail_data
      |> Enum.flat_map(& &1.killmails)

    defensive_kills =
      Enum.count(killmails, fn km ->
        # Simple heuristic: more attackers than usual suggests defensive action
        length(km.attackers) >= 5
      end)

    if Enum.empty?(killmails) do
      0.0
    else
      Float.round(defensive_kills / length(killmails), 3)
    end
  end

  defp calculate_single_system_defensive_activity(strategic_data) do
    defensive_kills =
      Enum.count(strategic_data.killmails, fn km ->
        length(km.attackers) >= 5
      end)

    total = length(strategic_data.killmails)

    if total > 0 do
      Float.round(defensive_kills / total, 3)
    else
      0.0
    end
  end

  defp calculate_response_times(strategic_data) do
    # Simplified: look for rapid succession of kills indicating quick response
    killmails =
      strategic_data.killmail_data
      |> Enum.flat_map(& &1.killmails)
      |> Enum.sort_by(& &1.timestamp, DateTime)

    response_intervals =
      killmails
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [km1, km2] ->
        DateTimeUtils.diff(km2.timestamp, km1.timestamp, :minute)
      end)
      # Responses within 30 minutes
      |> Enum.filter(&(&1 <= 30))

    if Enum.empty?(response_intervals) do
      0.0
    else
      avg_response = Enum.sum(response_intervals) / length(response_intervals)
      # Convert to score (lower is better)
      Float.round(1.0 - min(avg_response / 30, 1.0), 3)
    end
  end

  defp calculate_force_concentration(strategic_data) do
    # Measure how concentrated forces are (unique pilots per system)
    system_forces =
      strategic_data.killmail_data
      |> Enum.map(fn data ->
        unique_pilots =
          data.killmails
          |> Enum.flat_map(fn km ->
            [km.victim.character_id | Enum.map(km.attackers, & &1.character_id)]
          end)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()
          |> length()

        {data.system_id, unique_pilots}
      end)

    if Enum.empty?(system_forces) do
      0.0
    else
      total_pilots = Enum.sum(Enum.map(system_forces, fn {_, pilots} -> pilots end))
      max_concentration = Enum.max(Enum.map(system_forces, fn {_, pilots} -> pilots end))

      if total_pilots > 0 do
        Float.round(max_concentration / total_pilots, 3)
      else
        0.0
      end
    end
  end

  defp identify_consolidation_indicators(_strategic_data, metrics) do
    base_indicators = []

    # High system concentration
    concentration_indicators =
      if metrics.system_concentration > @territorial_control_threshold do
        base_indicators ++ [{:high_concentration, metrics.system_concentration}]
      else
        base_indicators
      end

    # Defensive activity
    defensive_indicators =
      if metrics.defensive_activity > 0.3 do
        concentration_indicators ++ [{:defensive_operations, metrics.defensive_activity}]
      else
        concentration_indicators
      end

    # Quick response times
    response_indicators =
      if metrics.response_times > 0.5 do
        defensive_indicators ++ [{:rapid_response, metrics.response_times}]
      else
        defensive_indicators
      end

    # Force concentration
    if metrics.force_concentration > 0.6 do
      response_indicators ++ [{:concentrated_forces, metrics.force_concentration}]
    else
      response_indicators
    end
  end

  defp calculate_consolidation_confidence(indicators, metrics) do
    base_confidence = length(indicators) * 0.2

    # Metric strength bonus
    metric_bonus =
      [
        metrics.system_concentration,
        metrics.defensive_activity,
        metrics.response_times,
        metrics.force_concentration
      ]
      |> Enum.filter(&(&1 > 0.5))
      |> length()
      |> Kernel.*(0.1)

    min(1.0, base_confidence + metric_bonus)
  end

  defp describe_consolidation_pattern(indicators, _metrics) do
    indicator_types = Enum.map(indicators, fn {type, _} -> type end)

    cond do
      :high_concentration in indicator_types && :defensive_operations in indicator_types ->
        "Strong defensive consolidation with concentrated forces and active defense"

      :rapid_response in indicator_types && :concentrated_forces in indicator_types ->
        "Organized defensive posture with rapid response capabilities"

      :high_concentration in indicator_types ->
        "Consolidating forces in key systems"

      :defensive_operations in indicator_types ->
        "Increased defensive operations detected"

      true ->
        "Limited consolidation activity"
    end
  end

  defp extract_spatial_data(strategic_data) do
    systems = extract_systems(strategic_data)

    %{
      systems: systems,
      system_count: length(systems),
      geographic_spread: calculate_geographic_spread(systems)
    }
  end

  defp extract_systems(strategic_data) do
    case strategic_data.scope do
      :single_system -> [strategic_data.system_id]
      :multi_system -> Enum.map(strategic_data.killmail_data, & &1.system_id)
    end
  end

  defp calculate_geographic_spread(systems) do
    # Simplified - would use actual system coordinates in production
    length(Enum.uniq(systems))
  end

  defp extract_temporal_data(strategic_data) do
    %{
      start_time: strategic_data.time_range.since,
      end_time: strategic_data.time_range.until,
      duration_days:
        DateTimeUtils.diff(
          strategic_data.time_range.until,
          strategic_data.time_range.since,
          :day
        )
    }
  end

  defp calculate_system_activity_levels(strategic_data) do
    total_kills =
      strategic_data.killmail_data
      |> Enum.map(& &1.kill_count)
      |> Enum.sum()

    if total_kills == 0 do
      %{}
    else
      strategic_data.killmail_data
      |> Enum.map(fn data ->
        {data.system_id, data.kill_count / total_kills}
      end)
      |> Map.new()
    end
  end

  defp identify_control_zones(_systems, activity_levels) do
    # Group adjacent high-activity systems
    high_activity_systems =
      activity_levels
      |> Enum.filter(fn {_, level} -> level > 0.1 end)
      |> Enum.map(fn {system, _} -> system end)

    # For now, treat each high-activity system as its own zone
    Enum.map(high_activity_systems, fn system ->
      %{
        systems: [system],
        control_level: Map.get(activity_levels, system, 0.0),
        type: classify_zone_type(Map.get(activity_levels, system, 0.0))
      }
    end)
  end

  defp classify_zone_type(control_level) do
    cond do
      control_level >= 0.5 -> :stronghold
      control_level >= 0.3 -> :controlled
      control_level >= 0.1 -> :contested
      true -> :minimal
    end
  end

  defp assess_zone_stability(zones, strategic_data) do
    # Simplified stability based on activity consistency
    if Enum.empty?(zones) do
      1.0
    else
      # Check for consistent activity patterns
      killmail_data = strategic_data.killmail_data
      time_windows = create_analysis_windows(strategic_data.time_range)

      stability_scores =
        zones
        |> Enum.map(fn zone ->
          system = List.first(zone.systems)
          calculate_zone_stability(system, killmail_data, time_windows)
        end)

      if Enum.empty?(stability_scores) do
        0.0
      else
        Float.round(Enum.sum(stability_scores) / length(stability_scores), 3)
      end
    end
  end

  defp calculate_zone_stability(system, killmail_data, time_windows) do
    system_data = Enum.find(killmail_data, fn data -> data.system_id == system end)

    if system_data do
      window_activities =
        time_windows
        |> Enum.map(fn {start_time, end_time} ->
          Enum.count(system_data.killmails, fn km ->
            DateTimeUtils.compare(km.timestamp, start_time) != :lt &&
              DateTimeUtils.compare(km.timestamp, end_time) == :lt
          end)
        end)

      if length(window_activities) > 1 do
        # Calculate coefficient of variation
        mean = Enum.sum(window_activities) / length(window_activities)

        if mean > 0 do
          variance = calculate_variance(window_activities, mean)

          cv = :math.sqrt(variance) / mean
          max(0.0, min(1.0, 1.0 - cv))
        else
          0.0
        end
      else
        0.5
      end
    else
      0.0
    end
  end

  defp identify_dominant_entities(zones, strategic_data) do
    zones
    |> Enum.map(fn zone ->
      system = List.first(zone.systems)

      system_data =
        Enum.find(strategic_data.killmail_data, fn data ->
          data.system_id == system
        end)

      if system_data do
        entity_kills = count_entity_kills(system_data.killmails)
        dominant = identify_dominant_entity(entity_kills)

        %{
          zone: zone,
          dominant_entity: dominant,
          control_percentage: calculate_control_percentage(dominant, entity_kills)
        }
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp count_entity_kills(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      # Count kills by attacker corporations
      km.attackers
      |> Enum.map(& &1.corporation_id)
      |> Enum.reject(&is_nil/1)
    end)
    |> Enum.frequencies()
  end

  defp identify_dominant_entity(entity_kills) do
    if map_size(entity_kills) > 0 do
      {entity, _count} = Enum.max_by(entity_kills, fn {_, count} -> count end)
      entity
    else
      nil
    end
  end

  defp calculate_control_percentage(dominant_entity, entity_kills) do
    if dominant_entity && map_size(entity_kills) > 0 do
      total = Enum.sum(Map.values(entity_kills))
      dominant_count = Map.get(entity_kills, dominant_entity, 0)

      Float.round(dominant_count / total, 3)
    else
      0.0
    end
  end

  defp identify_contested_areas(zones, activity_levels) do
    zones
    |> Enum.filter(&(&1.type == :contested))
    |> Enum.map(fn zone ->
      %{
        systems: zone.systems,
        contestation_level: 1.0 - zone.control_level,
        activity_intensity: Map.get(activity_levels, List.first(zone.systems), 0.0)
      }
    end)
  end

  defp calculate_variance(values, mean) do
    values
    |> Enum.map(fn x -> :math.pow(x - mean, 2) end)
    |> Enum.sum()
    |> Kernel./(length(values))
  end
end
