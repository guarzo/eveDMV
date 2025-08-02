defmodule EveDmv.Shared.Strategic.ResourceAnalyzer do
  @moduledoc """
  Analyzes resource competition and control patterns.

  Responsible for:
  - Resource competition analysis
  - Control stability assessment
  - Value estimation
  - Resource flow analysis
  """

  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Shared.Strategic.Patterns.ResourcePattern

  require Logger

  @doc """
  Analyzes resource competition across the area of operations.
  """
  def analyze_resource_competition(strategic_data, _options \\ []) do
    resource_patterns = ResourcePattern.identify_resource_control(strategic_data)
    competition_analysis = ResourcePattern.analyze_resource_competition(strategic_data)

    control_stability = assess_control_stability(strategic_data, resource_patterns)
    resource_flows = analyze_resource_flows(strategic_data)

    %{
      resource_activity: resource_patterns.metrics,
      competition: competition_analysis,
      control_stability: control_stability,
      resource_flows: resource_flows,
      strategic_value:
        ResourcePattern.assess_strategic_value(resource_patterns.metrics, strategic_data),
      recommendations: generate_resource_recommendations(competition_analysis, control_stability)
    }
  end

  @doc """
  Assesses stability of resource control over time.
  """
  def assess_control_stability(strategic_data, resource_patterns) do
    time_windows = create_analysis_windows(strategic_data)

    stability_metrics =
      time_windows
      |> Enum.map(fn window ->
        window_control = analyze_window_resource_control(strategic_data, window)

        %{
          window: window,
          dominant_extractor: window_control.dominant,
          control_percentage: window_control.control_percentage,
          competition_level: window_control.competition_level
        }
      end)

    %{
      overall_stability: calculate_overall_stability(stability_metrics),
      control_changes: detect_control_changes(stability_metrics),
      stability_trend: determine_stability_trend(stability_metrics),
      risk_assessment: assess_control_risks(stability_metrics, resource_patterns)
    }
  end

  @doc """
  Analyzes resource flow patterns between systems.
  """
  def analyze_resource_flows(strategic_data) do
    case strategic_data.scope do
      :multi_system ->
        hauling_routes = identify_hauling_routes(strategic_data)
        flow_patterns = analyze_flow_patterns(hauling_routes)
        bottlenecks = identify_bottlenecks(flow_patterns)

        %{
          identified_routes: hauling_routes,
          flow_patterns: flow_patterns,
          bottlenecks: bottlenecks,
          flow_efficiency: calculate_flow_efficiency(flow_patterns),
          disruption_risk: assess_disruption_risk(bottlenecks)
        }

      :single_system ->
        %{
          identified_routes: [],
          flow_patterns: %{},
          bottlenecks: [],
          flow_efficiency: 1.0,
          disruption_risk: :low
        }
    end
  end

  @doc """
  Estimates resource extraction rates and values.
  """
  def estimate_resource_extraction(strategic_data, resource_patterns) do
    mining_activity = resource_patterns.metrics.mining_activity
    hauling_activity = resource_patterns.metrics.hauling_activity

    extraction_rate = estimate_extraction_rate(mining_activity, hauling_activity)
    resource_value = estimate_resource_value(extraction_rate, strategic_data)

    %{
      extraction_rate: extraction_rate,
      estimated_value: resource_value,
      extraction_efficiency: calculate_extraction_efficiency(mining_activity),
      value_per_hour: calculate_hourly_value(resource_value, strategic_data)
    }
  end

  # Private functions

  defp create_analysis_windows(strategic_data) do
    time_range = strategic_data.time_range
    duration_hours = DateTimeUtils.diff(time_range.until, time_range.since, :hour)
    # At least daily windows
    window_size = max(24, div(duration_hours, 7))

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

  defp analyze_window_resource_control(strategic_data, {start_time, end_time}) do
    window_kills = filter_resource_kills_by_window(strategic_data, start_time, end_time)

    if Enum.empty?(window_kills) do
      %{
        dominant: nil,
        control_percentage: 0.0,
        competition_level: 0.0
      }
    else
      entities = extract_resource_entities(window_kills)

      if map_size(entities) == 0 do
        %{
          dominant: nil,
          control_percentage: 0.0,
          competition_level: 0.0
        }
      else
        {dominant, max_count} = Enum.max_by(entities, fn {_, count} -> count end)
        total = Enum.sum(Map.values(entities))

        %{
          dominant: dominant,
          control_percentage: Float.round(max_count / total, 3),
          competition_level: calculate_competition_level(entities)
        }
      end
    end
  end

  defp filter_resource_kills_by_window(strategic_data, start_time, end_time) do
    resource_types = [:venture, :retriever, :hulk, :orca, :rorqual, :hauler, :freighter]

    case strategic_data.scope do
      :single_system ->
        strategic_data.killmails
        |> Enum.filter(fn km ->
          DateTimeUtils.compare(km.timestamp, start_time) != :lt &&
            DateTimeUtils.compare(km.timestamp, end_time) == :lt &&
            classify_ship_type(km.victim.ship_type_id) in resource_types
        end)

      :multi_system ->
        strategic_data.killmail_data
        |> Enum.flat_map(& &1.killmails)
        |> Enum.filter(fn km ->
          DateTimeUtils.compare(km.timestamp, start_time) != :lt &&
            DateTimeUtils.compare(km.timestamp, end_time) == :lt &&
            classify_ship_type(km.victim.ship_type_id) in resource_types
        end)
    end
  end

  defp extract_resource_entities(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      # Both victims and attackers involved in resource operations
      victim = if km.victim.corporation_id, do: [km.victim.corporation_id], else: []

      attackers =
        km.attackers
        |> Enum.map(& &1.corporation_id)
        |> Enum.reject(&is_nil/1)

      victim ++ attackers
    end)
    |> Enum.frequencies()
  end

  defp calculate_competition_level(entities) do
    if map_size(entities) <= 1 do
      0.0
    else
      # Herfindahl-Hirschman Index inverse for competition
      total = Enum.sum(Map.values(entities))

      hhi =
        entities
        |> Map.values()
        |> Enum.map(fn count ->
          share = count / total
          share * share
        end)
        |> Enum.sum()

      Float.round(1.0 - hhi, 3)
    end
  end

  defp calculate_overall_stability(stability_metrics) do
    if Enum.empty?(stability_metrics) do
      1.0
    else
      # Stability based on control consistency
      control_percentages = Enum.map(stability_metrics, & &1.control_percentage)

      if length(control_percentages) < 2 do
        0.5
      else
        mean = Enum.sum(control_percentages) / length(control_percentages)

        variance =
          control_percentages
          |> Enum.map(fn p -> :math.pow(p - mean, 2) end)
          |> Enum.sum()
          |> Kernel./(length(control_percentages))

        cv = if mean > 0, do: :math.sqrt(variance) / mean, else: 1.0

        Float.round(max(0.0, min(1.0, 1.0 - cv)), 3)
      end
    end
  end

  defp detect_control_changes(stability_metrics) do
    if length(stability_metrics) < 2 do
      []
    else
      stability_metrics
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [prev, curr] ->
        if prev.dominant_extractor != curr.dominant_extractor do
          %{
            window: curr.window,
            previous_controller: prev.dominant_extractor,
            new_controller: curr.dominant_extractor,
            control_shift: curr.control_percentage - prev.control_percentage
          }
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)
    end
  end

  defp determine_stability_trend(stability_metrics) do
    if length(stability_metrics) < 3 do
      :insufficient_data
    else
      competition_levels = Enum.map(stability_metrics, & &1.competition_level)

      first_half = Enum.take(competition_levels, div(length(competition_levels), 2))
      second_half = Enum.drop(competition_levels, div(length(competition_levels), 2))

      first_avg = average(first_half)
      second_avg = average(second_half)

      cond do
        second_avg > first_avg * 1.2 -> :increasing_competition
        second_avg < first_avg * 0.8 -> :consolidating_control
        true -> :stable_competition
      end
    end
  end

  defp assess_control_risks(stability_metrics, resource_patterns) do
    competition_level = average(Enum.map(stability_metrics, & &1.competition_level))
    control_changes = detect_control_changes(stability_metrics)
    conflict_intensity = Map.get(resource_patterns.metrics.resource_conflicts, :conflict_count, 0)

    risk_score =
      competition_level * 0.4 +
        min(1.0, length(control_changes) / 5) * 0.3 +
        min(1.0, conflict_intensity / 10) * 0.3

    %{
      risk_level: classify_risk_level(risk_score),
      risk_factors: identify_risk_factors(competition_level, control_changes, conflict_intensity),
      mitigation_recommendations: suggest_risk_mitigation(risk_score)
    }
  end

  defp classify_risk_level(risk_score) do
    cond do
      risk_score >= 0.7 -> :high
      risk_score >= 0.4 -> :medium
      risk_score >= 0.2 -> :low
      true -> :minimal
    end
  end

  defp identify_risk_factors(competition_level, control_changes, conflict_intensity) do
    base_factors = []

    competition_factors =
      if competition_level > 0.5 do
        base_factors ++ [:high_competition]
      else
        base_factors
      end

    control_factors =
      if length(control_changes) > 2 do
        competition_factors ++ [:unstable_control]
      else
        competition_factors
      end

    final_factors =
      if conflict_intensity > 5 do
        control_factors ++ [:active_conflicts]
      else
        control_factors
      end

    final_factors
  end

  defp suggest_risk_mitigation(risk_score) do
    if risk_score >= 0.7 do
      [
        "Increase defensive operations around resource extraction",
        "Consider temporary reduction in extraction activities",
        "Establish stronger territorial control"
      ]
    else
      if risk_score >= 0.4 do
        [
          "Monitor competition closely",
          "Maintain regular security patrols",
          "Consider alliances with other extractors"
        ]
      else
        ["Maintain current security posture"]
      end
    end
  end

  defp identify_hauling_routes(strategic_data) do
    hauler_kills =
      strategic_data.killmail_data
      |> Enum.flat_map(fn data ->
        data.killmails
        |> Enum.filter(fn km ->
          classify_ship_type(km.victim.ship_type_id) in [:hauler, :freighter, :transport]
        end)
        |> Enum.map(fn km ->
          %{
            system_id: data.system_id,
            timestamp: km.timestamp,
            ship_type: classify_ship_type(km.victim.ship_type_id),
            value: Map.get(km, :zkb_total_value, 0)
          }
        end)
      end)

    # Group by time proximity to identify routes
    hauler_kills
    |> Enum.sort_by(& &1.timestamp, DateTime)
    |> identify_route_segments()
    |> Enum.filter(&(length(&1) >= 2))
  end

  defp identify_route_segments(hauler_data) do
    # Group hauler losses that occur within 2 hours of each other
    chunk_fun = fn item, acc ->
      if acc == [] do
        {:cont, [item]}
      else
        last = List.last(acc)

        if DateTimeUtils.diff(item.timestamp, last.timestamp, :hour) <= 2 do
          {:cont, acc ++ [item]}
        else
          {:cont, acc, [item]}
        end
      end
    end

    after_fun = fn
      [] -> {:cont, []}
      acc -> {:cont, acc, []}
    end

    hauler_data
    |> Enum.chunk_while([], chunk_fun, after_fun)
  end

  defp analyze_flow_patterns(hauling_routes) do
    routes =
      hauling_routes
      |> Enum.map(fn segment ->
        systems = Enum.map(segment, & &1.system_id) |> Enum.uniq()

        %{
          systems: systems,
          segment_count: length(segment),
          total_value: Enum.sum(Enum.map(segment, & &1.value)),
          route_type: classify_route_type(systems)
        }
      end)

    %{
      identified_routes: length(routes),
      total_hauler_losses: Enum.sum(Enum.map(routes, & &1.segment_count)),
      high_value_routes: Enum.filter(routes, &(&1.total_value > 1_000_000_000)),
      route_classification: Enum.frequencies_by(routes, & &1.route_type)
    }
  end

  defp classify_route_type(systems) do
    case length(systems) do
      1 -> :local
      2 -> :direct
      _ -> :multi_hop
    end
  end

  defp identify_bottlenecks(flow_patterns) do
    if map_size(flow_patterns) == 0 do
      []
    else
      # Systems that appear in multiple routes
      system_frequency =
        flow_patterns.high_value_routes
        |> Enum.flat_map(& &1.systems)
        |> Enum.frequencies()
        |> Enum.filter(fn {_, count} -> count >= 2 end)
        |> Enum.sort_by(fn {_, count} -> count end, :desc)
        |> Enum.take(3)
        |> Enum.map(fn {system, count} ->
          %{
            system_id: system,
            route_count: count,
            bottleneck_severity: classify_bottleneck_severity(count)
          }
        end)

      system_frequency
    end
  end

  defp classify_bottleneck_severity(route_count) do
    cond do
      route_count >= 5 -> :critical
      route_count >= 3 -> :significant
      route_count >= 2 -> :minor
      true -> :negligible
    end
  end

  defp calculate_flow_efficiency(flow_patterns) do
    if flow_patterns.total_hauler_losses == 0 do
      # No losses = perfect efficiency
      1.0
    else
      # Efficiency based on value lost vs routes identified
      value_lost =
        flow_patterns.high_value_routes
        |> Enum.map(& &1.total_value)
        |> Enum.sum()

      if value_lost > 0 do
        # Lower value per loss = better efficiency
        efficiency = 1.0 - min(1.0, value_lost / 10_000_000_000)
        Float.round(efficiency, 3)
      else
        # Some losses but low value
        0.8
      end
    end
  end

  defp assess_disruption_risk(bottlenecks) do
    critical_bottlenecks = Enum.count(bottlenecks, &(&1.bottleneck_severity == :critical))
    significant_bottlenecks = Enum.count(bottlenecks, &(&1.bottleneck_severity == :significant))

    cond do
      critical_bottlenecks > 0 -> :high
      significant_bottlenecks >= 2 -> :medium
      significant_bottlenecks >= 1 -> :low
      true -> :minimal
    end
  end

  defp estimate_extraction_rate(mining_activity, hauling_activity) do
    # Estimate based on ship losses and hauling
    # 100M per mining ship
    mining_ship_factor = mining_activity.mining_losses * 100_000_000
    # 500M capacity per hauler
    hauling_capacity = hauling_activity.hauling_losses * 500_000_000

    # Average of the two estimates
    Float.round((mining_ship_factor + hauling_capacity) / 2, 0)
  end

  defp estimate_resource_value(extraction_rate, strategic_data) do
    time_factor =
      DateTimeUtils.diff(
        strategic_data.time_range.until,
        strategic_data.time_range.since,
        :hour
      )

    if time_factor > 0 do
      extraction_rate * time_factor
    else
      0
    end
  end

  defp calculate_extraction_efficiency(mining_activity) do
    if mining_activity.mining_losses == 0 do
      # No losses = perfect efficiency
      1.0
    else
      # Efficiency based on losses vs estimated output
      loss_factor = min(1.0, mining_activity.mining_losses / 10)
      Float.round(1.0 - loss_factor * 0.5, 3)
    end
  end

  defp calculate_hourly_value(total_value, strategic_data) do
    hours =
      DateTimeUtils.diff(
        strategic_data.time_range.until,
        strategic_data.time_range.since,
        :hour
      )

    if hours > 0 do
      round(total_value / hours)
    else
      0
    end
  end

  defp generate_resource_recommendations(competition_analysis, control_stability) do
    base_recommendations = []

    # Competition-based recommendations
    competition_recommendations =
      if competition_analysis.competition_intensity > 0.7 do
        base_recommendations ++
          [
            "High competition detected - consider defensive mining operations",
            "Coordinate with allies to secure resource extraction"
          ]
      else
        base_recommendations
      end

    # Stability-based recommendations
    stability_recommendations =
      case control_stability.stability_trend do
        :increasing_competition ->
          competition_recommendations ++
            ["Competition increasing - prepare for resource conflicts"]

        :consolidating_control ->
          competition_recommendations ++
            ["Control consolidating - opportunity to expand operations"]

        _ ->
          competition_recommendations
      end

    # Risk-based recommendations
    final_recommendations =
      if control_stability.risk_assessment.risk_level in [:high, :medium] do
        stability_recommendations ++ control_stability.risk_assessment.mitigation_recommendations
      else
        stability_recommendations
      end

    if Enum.empty?(final_recommendations) do
      ["Maintain current resource extraction operations"]
    else
      final_recommendations
    end
  end

  defp average(list) do
    if Enum.empty?(list) do
      0.0
    else
      Enum.sum(list) / length(list)
    end
  end

  defp classify_ship_type(ship_type_id) do
    # Map specific ship type IDs to their roles
    # This is based on EVE Online ship type IDs
    case ship_type_id do
      # Freighters
      20183 -> :freighter   # Providence
      20185 -> :freighter   # Charon
      20187 -> :freighter   # Obelisk
      20189 -> :freighter   # Fenrir
      
      # Jump Freighters  
      28844 -> :freighter   # Rhea
      28846 -> :freighter   # Nomad
      28848 -> :freighter   # Anshar
      28850 -> :freighter   # Ark
      
      # Deep Space Transports
      12729 -> :transport   # Crane
      12731 -> :transport   # Bustard
      12733 -> :transport   # Mastodon
      12735 -> :transport   # Impel
      
      # Blockade Runners
      12743 -> :transport   # Prowler
      12745 -> :transport   # Viator
      12747 -> :transport   # Prorator
      12749 -> :transport   # Wideload
      
      # T1 Haulers
      648 -> :hauler        # Badger
      649 -> :hauler        # Tayra
      650 -> :hauler        # Nereus
      651 -> :hauler        # Hoarder
      652 -> :hauler        # Mammoth
      653 -> :hauler        # Wreathe
      654 -> :hauler        # Kryos
      655 -> :hauler        # Epithal
      656 -> :hauler        # Miasmos
      657 -> :hauler        # Iteron Mark V
      
      # Default classification based on group
      _ ->
        ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id)
        if ship_class == :unknown, do: :other, else: ship_class
    end
  end
end
