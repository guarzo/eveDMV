defmodule EveDmv.Shared.Strategic.Patterns.TacticalPatterns do
  @moduledoc """
  Identifies tactical patterns including chokepoint dominance, harassment,
  reconnaissance, supply disruption, and offensive preparation.

  Handles multiple tactical pattern types in a single module since they
  share similar analysis approaches.
  """

  require Logger

  @doc """
  Identifies chokepoint dominance patterns.
  """
  def identify_chokepoint_dominance(strategic_data) do
    case strategic_data.scope do
      :multi_system ->
        analyze_chokepoint_control(strategic_data)

      :single_system ->
        %{
          type: :chokepoint_dominance,
          category: :tactical,
          confidence: 0.0,
          description: "Single system - chokepoint analysis requires multiple systems",
          indicators: []
        }
    end
  end

  @doc """
  Identifies harassment campaign patterns.
  """
  def identify_harassment_campaign(strategic_data) do
    harassment_metrics = analyze_harassment_activity(strategic_data)
    indicators = identify_harassment_indicators(harassment_metrics)

    confidence = calculate_pattern_confidence(indicators, harassment_metrics)

    %{
      type: :harassment_campaign,
      category: :tactical,
      confidence: confidence,
      description: describe_harassment_pattern(indicators, harassment_metrics),
      metrics: harassment_metrics,
      indicators: indicators,
      spatial_data: extract_spatial_data(strategic_data),
      temporal_data: extract_temporal_data(strategic_data)
    }
  end

  @doc """
  Identifies reconnaissance operation patterns.
  """
  def identify_reconnaissance_operation(strategic_data) do
    recon_metrics = analyze_reconnaissance_activity(strategic_data)
    indicators = identify_recon_indicators(recon_metrics)

    confidence = calculate_pattern_confidence(indicators, recon_metrics)

    %{
      type: :reconnaissance_operation,
      category: :tactical,
      confidence: confidence,
      description: describe_recon_pattern(indicators, recon_metrics),
      metrics: recon_metrics,
      indicators: indicators,
      spatial_data: extract_spatial_data(strategic_data),
      temporal_data: extract_temporal_data(strategic_data)
    }
  end

  @doc """
  Identifies supply line disruption patterns.
  """
  def identify_supply_line_disruption(strategic_data) do
    disruption_metrics = analyze_supply_disruption(strategic_data)
    indicators = identify_disruption_indicators(disruption_metrics)

    confidence = calculate_pattern_confidence(indicators, disruption_metrics)

    %{
      type: :supply_line_disruption,
      category: :tactical,
      confidence: confidence,
      description: describe_disruption_pattern(indicators, disruption_metrics),
      metrics: disruption_metrics,
      indicators: indicators,
      spatial_data: extract_spatial_data(strategic_data),
      temporal_data: extract_temporal_data(strategic_data)
    }
  end

  @doc """
  Identifies offensive preparation patterns.
  """
  def identify_offensive_preparation(strategic_data) do
    prep_metrics = analyze_offensive_preparation(strategic_data)
    indicators = identify_preparation_indicators(prep_metrics)

    confidence = calculate_pattern_confidence(indicators, prep_metrics)

    %{
      type: :offensive_preparation,
      category: :tactical,
      confidence: confidence,
      description: describe_preparation_pattern(indicators, prep_metrics),
      metrics: prep_metrics,
      indicators: indicators,
      spatial_data: extract_spatial_data(strategic_data),
      temporal_data: extract_temporal_data(strategic_data)
    }
  end

  # Private functions - Chokepoint Analysis

  defp analyze_chokepoint_control(strategic_data) do
    systems = Enum.map(strategic_data.killmail_data, & &1.system_id)

    # Identify potential chokepoints (systems with high traffic)
    system_traffic = calculate_system_traffic(strategic_data)
    chokepoints = identify_chokepoints(system_traffic)

    control_metrics =
      chokepoints
      |> Enum.map(fn chokepoint ->
        analyze_chokepoint_control_metrics(chokepoint, strategic_data)
      end)

    overall_confidence = calculate_chokepoint_confidence(control_metrics)

    %{
      type: :chokepoint_dominance,
      category: :tactical,
      confidence: overall_confidence,
      description: describe_chokepoint_control(chokepoints, control_metrics),
      metrics: %{
        identified_chokepoints: chokepoints,
        control_metrics: control_metrics,
        traffic_analysis: system_traffic
      },
      indicators: extract_chokepoint_indicators(control_metrics),
      spatial_data: %{systems: systems, chokepoints: Enum.map(chokepoints, & &1.system_id)},
      temporal_data: extract_temporal_data(strategic_data)
    }
  end

  defp calculate_system_traffic(strategic_data) do
    strategic_data.killmail_data
    |> Enum.map(fn data ->
      unique_entities = count_unique_entities(data.killmails)

      %{
        system_id: data.system_id,
        traffic_volume: unique_entities,
        kill_density: data.kill_count,
        traffic_score: unique_entities * 0.7 + data.kill_count * 0.3
      }
    end)
    |> Enum.sort_by(& &1.traffic_score, :desc)
  end

  defp count_unique_entities(killmails) do
    entities =
      killmails
      |> Enum.flat_map(fn km ->
        [km.victim.character_id | Enum.map(km.attackers, & &1.character_id)]
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    length(entities)
  end

  defp identify_chokepoints(system_traffic) do
    if Enum.empty?(system_traffic) do
      []
    else
      avg_traffic =
        system_traffic
        |> Enum.map(& &1.traffic_score)
        |> average()

      system_traffic
      |> Enum.filter(&(&1.traffic_score > avg_traffic * 1.5))
      |> Enum.take(3)
    end
  end

  defp analyze_chokepoint_control_metrics(chokepoint, strategic_data) do
    system_data = Enum.find(strategic_data.killmail_data, &(&1.system_id == chokepoint.system_id))

    if system_data do
      dominant_entity = identify_dominant_controller(system_data.killmails)
      control_percentage = calculate_control_percentage(dominant_entity, system_data.killmails)
      persistence = calculate_control_persistence(dominant_entity, system_data.killmails)

      %{
        system_id: chokepoint.system_id,
        dominant_controller: dominant_entity,
        control_percentage: control_percentage,
        control_persistence: persistence,
        contestation_level: 1.0 - control_percentage
      }
    else
      %{
        system_id: chokepoint.system_id,
        dominant_controller: nil,
        control_percentage: 0.0,
        control_persistence: 0.0,
        contestation_level: 1.0
      }
    end
  end

  defp identify_dominant_controller(killmails) do
    killmails
    |> Enum.flat_map(& &1.attackers)
    |> Enum.map(& &1.corporation_id)
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.max_by(fn {_, count} -> count end, fn -> {nil, 0} end)
    |> elem(0)
  end

  defp calculate_control_percentage(nil, _), do: 0.0

  defp calculate_control_percentage(dominant_entity, killmails) do
    total_kills = length(killmails)

    if total_kills == 0 do
      0.0
    else
      controlled_kills =
        killmails
        |> Enum.count(fn km ->
          Enum.any?(km.attackers, &(&1.corporation_id == dominant_entity))
        end)

      Float.round(controlled_kills / total_kills, 3)
    end
  end

  defp calculate_control_persistence(nil, _), do: 0.0

  defp calculate_control_persistence(dominant_entity, killmails) do
    # Check how consistently the entity maintains control over time
    time_windows = create_hourly_windows(killmails)

    windows_with_control =
      time_windows
      |> Enum.count(fn window ->
        window_kills =
          killmails
          |> Enum.filter(fn km ->
            DateTime.compare(km.timestamp, window) != :lt &&
              DateTime.compare(km.timestamp, DateTime.add(window, 3600, :second)) == :lt
          end)

        if not Enum.empty?(window_kills) do
          window_controller = identify_dominant_controller(window_kills)
          window_controller == dominant_entity
        else
          false
        end
      end)

    if not Enum.empty?(time_windows) do
      Float.round(windows_with_control / length(time_windows), 3)
    else
      0.0
    end
  end

  defp create_hourly_windows(killmails) do
    if Enum.empty?(killmails) do
      []
    else
      min_time = Enum.min_by(killmails, & &1.timestamp).timestamp
      max_time = Enum.max_by(killmails, & &1.timestamp).timestamp

      hours_diff = div(DateTime.diff(max_time, min_time, :second), 3600)

      Enum.map(0..hours_diff, fn h ->
        DateTime.add(min_time, h * 3600, :second)
      end)
    end
  end

  defp calculate_chokepoint_confidence(control_metrics) do
    if Enum.empty?(control_metrics) do
      0.0
    else
      # Average control percentage across all chokepoints
      avg_control =
        control_metrics
        |> Enum.map(& &1.control_percentage)
        |> average()

      # Persistence bonus
      avg_persistence =
        control_metrics
        |> Enum.map(& &1.control_persistence)
        |> average()

      Float.round(avg_control * 0.6 + avg_persistence * 0.4, 3)
    end
  end

  defp describe_chokepoint_control(chokepoints, control_metrics) do
    if Enum.empty?(chokepoints) do
      "No significant chokepoints identified"
    else
      controlled_count = Enum.count(control_metrics, &(&1.control_percentage > 0.5))

      cond do
        controlled_count == length(chokepoints) ->
          "Strong control over all identified chokepoints"

        controlled_count > 0 ->
          "Partial control over #{controlled_count} of #{length(chokepoints)} chokepoints"

        true ->
          "Contested chokepoints with no clear dominance"
      end
    end
  end

  defp extract_chokepoint_indicators(control_metrics) do
    control_metrics
    |> Enum.flat_map(fn metrics ->
      indicators = []

      indicators =
        if metrics.control_percentage > 0.6 do
          indicators ++ [{:strong_control, metrics.system_id}]
        else
          indicators
        end

      indicators =
        if metrics.control_persistence > 0.7 do
          indicators ++ [{:persistent_control, metrics.system_id}]
        else
          indicators
        end

      if metrics.contestation_level > 0.5 do
        indicators ++ [{:contested_chokepoint, metrics.system_id}]
      else
        indicators
      end
    end)
  end

  # Private functions - Harassment Campaign

  defp analyze_harassment_activity(strategic_data) do
    killmails = extract_all_killmails(strategic_data)

    %{
      hit_and_run_attacks: identify_hit_and_run(killmails),
      target_distribution: analyze_target_distribution(killmails),
      timing_patterns: analyze_harassment_timing(killmails),
      effectiveness: calculate_harassment_effectiveness(killmails)
    }
  end

  defp identify_hit_and_run(killmails) do
    # Look for quick kills with minimal losses
    potential_harassment =
      killmails
      |> Enum.filter(fn km ->
        # Small gang indicators
        attacker_count = length(km.attackers)
        attacker_count >= 2 && attacker_count <= 10
      end)

    %{
      count: length(potential_harassment),
      average_gang_size: calculate_average_gang_size(potential_harassment),
      target_types: identify_harassment_targets(potential_harassment)
    }
  end

  defp calculate_average_gang_size(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      total_attackers =
        killmails
        |> Enum.map(&length(&1.attackers))
        |> Enum.sum()

      Float.round(total_attackers / length(killmails), 1)
    end
  end

  defp identify_harassment_targets(killmails) do
    killmails
    |> Enum.map(&classify_ship_type(&1.victim.ship_type_id))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(5)
  end

  defp analyze_target_distribution(killmails) do
    victim_corps =
      killmails
      |> Enum.map(& &1.victim.corporation_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.frequencies()

    %{
      unique_targets: map_size(victim_corps),
      target_concentration: calculate_target_concentration(victim_corps),
      primary_targets: identify_primary_targets(victim_corps)
    }
  end

  defp calculate_target_concentration(victim_corps) do
    if map_size(victim_corps) == 0 do
      0.0
    else
      total = Enum.sum(Map.values(victim_corps))
      max_hits = Enum.max(Map.values(victim_corps))
      Float.round(max_hits / total, 3)
    end
  end

  defp identify_primary_targets(victim_corps) do
    victim_corps
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {corp_id, count} ->
      %{corporation_id: corp_id, harassment_count: count}
    end)
  end

  defp analyze_harassment_timing(killmails) do
    # Look for patterns in attack timing
    time_gaps = calculate_attack_intervals(killmails)

    %{
      attack_frequency: calculate_attack_frequency(killmails),
      average_interval: average(time_gaps),
      pattern_type: classify_timing_pattern(time_gaps),
      peak_times: identify_peak_harassment_times(killmails)
    }
  end

  defp calculate_attack_intervals(killmails) do
    killmails
    |> Enum.sort_by(& &1.timestamp, DateTime)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [km1, km2] ->
      DateTime.diff(km2.timestamp, km1.timestamp, :hour)
    end)
  end

  defp calculate_attack_frequency(killmails) do
    if length(killmails) < 2 do
      0.0
    else
      time_span =
        DateTime.diff(
          Enum.max_by(killmails, & &1.timestamp).timestamp,
          Enum.min_by(killmails, & &1.timestamp).timestamp,
          :hour
        )

      if time_span > 0 do
        Float.round(length(killmails) / time_span, 2)
      else
        0.0
      end
    end
  end

  defp classify_timing_pattern(time_gaps) do
    if length(time_gaps) < 2 do
      :insufficient_data
    else
      avg_gap = average(time_gaps)
      variance = calculate_variance(time_gaps, avg_gap)
      cv = if avg_gap > 0, do: :math.sqrt(variance) / avg_gap, else: 1.0

      cond do
        cv < 0.3 -> :regular_intervals
        cv < 0.7 -> :semi_regular
        true -> :irregular
      end
    end
  end

  defp calculate_variance(values, mean) do
    if Enum.empty?(values) do
      0.0
    else
      squared_diffs = Enum.map(values, fn v -> :math.pow(v - mean, 2) end)
      Enum.sum(squared_diffs) / length(values)
    end
  end

  defp identify_peak_harassment_times(killmails) do
    killmails
    |> Enum.group_by(& &1.timestamp.hour)
    |> Enum.map(fn {hour, kms} -> {hour, length(kms)} end)
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {hour, count} -> %{hour: hour, attack_count: count} end)
  end

  defp calculate_harassment_effectiveness(killmails) do
    # Simplified effectiveness based on ISK efficiency
    total_destroyed =
      killmails
      |> Enum.map(&Map.get(&1, :zkb_total_value, 0))
      |> Enum.sum()

    harassment_losses =
      killmails
      |> Enum.filter(fn km ->
        # Check if harassers took losses (simplified)
        length(km.attackers) <= 10
      end)
      |> length()

    %{
      total_damage_isk: total_destroyed,
      efficiency_ratio:
        if(harassment_losses > 0, do: total_destroyed / harassment_losses, else: total_destroyed),
      success_rate:
        Float.round((length(killmails) - harassment_losses) / max(1, length(killmails)), 3)
    }
  end

  defp identify_harassment_indicators(metrics) do
    []
    |> then(fn indicators ->
      # Frequent attacks
      if metrics.timing_patterns.attack_frequency > 0.5 do
        indicators ++ [{:high_frequency_attacks, metrics.timing_patterns.attack_frequency}]
      else
        indicators
      end
    end)
    |> then(fn indicators ->
      # Multiple targets
      if metrics.target_distribution.unique_targets >= 5 do
        indicators ++ [{:multiple_targets, metrics.target_distribution.unique_targets}]
      else
        indicators
      end
    end)
    |> then(fn indicators ->
      # Small gang activity
      if metrics.hit_and_run_attacks.average_gang_size <= 10 &&
           metrics.hit_and_run_attacks.count >= 5 do
        indicators ++ [{:small_gang_activity, metrics.hit_and_run_attacks.count}]
      else
        indicators
      end
    end)
    |> then(fn indicators ->
      # High effectiveness
      if metrics.effectiveness.success_rate > 0.7 do
        indicators ++ [{:effective_harassment, metrics.effectiveness.success_rate}]
      else
        indicators
      end
    end)
  end

  defp describe_harassment_pattern(indicators, _metrics) do
    indicator_types = Enum.map(indicators, fn {type, _} -> type end)

    cond do
      :high_frequency_attacks in indicator_types && :effective_harassment in indicator_types ->
        "Sustained and effective harassment campaign with high success rate"

      :multiple_targets in indicator_types && :small_gang_activity in indicator_types ->
        "Distributed harassment targeting multiple entities with small gangs"

      :high_frequency_attacks in indicator_types ->
        "Frequent harassment attacks detected"

      :small_gang_activity in indicator_types ->
        "Small gang harassment activity present"

      true ->
        "Limited harassment activity"
    end
  end

  # Private functions - Reconnaissance

  defp analyze_reconnaissance_activity(strategic_data) do
    killmails = extract_all_killmails(strategic_data)

    %{
      scout_losses: identify_scout_activity(killmails),
      exploration_patterns: analyze_exploration_patterns(strategic_data),
      intelligence_gathering: detect_intelligence_gathering(killmails),
      coverage_analysis: analyze_system_coverage(strategic_data)
    }
  end

  defp identify_scout_activity(killmails) do
    # Look for typical scout ships
    scout_types = [:interceptor, :covert_ops, :frigate]

    scout_losses =
      killmails
      |> Enum.filter(fn km ->
        ship_class = classify_ship_type(km.victim.ship_type_id)
        ship_class in scout_types && length(km.attackers) <= 5
      end)

    %{
      count: length(scout_losses),
      scout_types: group_scout_types(scout_losses),
      loss_locations: extract_loss_locations(scout_losses)
    }
  end

  defp group_scout_types(scout_losses) do
    scout_losses
    |> Enum.map(&classify_ship_type(&1.victim.ship_type_id))
    |> Enum.frequencies()
  end

  defp extract_loss_locations(scout_losses) do
    scout_losses
    |> Enum.map(& &1.solar_system_id)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(5)
  end

  defp analyze_exploration_patterns(strategic_data) do
    case strategic_data.scope do
      :multi_system ->
        system_visits = track_system_visits(strategic_data)

        %{
          systems_explored: length(system_visits),
          exploration_sequence: determine_exploration_sequence(system_visits),
          coverage_percentage: calculate_coverage_percentage(system_visits, strategic_data)
        }

      :single_system ->
        %{
          systems_explored: 1,
          exploration_sequence: [],
          coverage_percentage: 1.0
        }
    end
  end

  defp track_system_visits(strategic_data) do
    strategic_data.killmail_data
    |> Enum.filter(&(&1.kill_count > 0))
    |> Enum.map(fn data ->
      first_activity =
        data.killmails
        |> Enum.min_by(& &1.timestamp, fn -> nil end)

      %{
        system_id: data.system_id,
        first_visit: if(first_activity, do: first_activity.timestamp, else: nil),
        activity_count: data.kill_count
      }
    end)
    |> Enum.reject(&is_nil(&1.first_visit))
    |> Enum.sort_by(& &1.first_visit, DateTime)
  end

  defp determine_exploration_sequence(system_visits) do
    system_visits
    |> Enum.map(& &1.system_id)
  end

  defp calculate_coverage_percentage(system_visits, strategic_data) do
    total_systems = length(strategic_data.killmail_data)
    visited_systems = length(system_visits)

    if total_systems > 0 do
      Float.round(visited_systems / total_systems, 3)
    else
      0.0
    end
  end

  defp detect_intelligence_gathering(killmails) do
    # Look for patterns suggesting intelligence gathering
    low_engagement_kills =
      killmails
      |> Enum.filter(&(length(&1.attackers) <= 3))

    probe_activity =
      low_engagement_kills
      |> Enum.count(fn km ->
        # Simplified check for probe-like activity
        classify_ship_type(km.victim.ship_type_id) in [:frigate, :destroyer]
      end)

    %{
      probe_kills: probe_activity,
      low_engagement_ratio:
        Float.round(length(low_engagement_kills) / max(1, length(killmails)), 3),
      intelligence_indicators: probe_activity > 3
    }
  end

  defp analyze_system_coverage(strategic_data) do
    case strategic_data.scope do
      :multi_system ->
        active_systems =
          strategic_data.killmail_data
          |> Enum.filter(&(&1.kill_count > 0))
          |> length()

        total_systems = length(strategic_data.killmail_data)

        %{
          coverage_ratio: Float.round(active_systems / max(1, total_systems), 3),
          system_penetration: classify_penetration(active_systems, total_systems)
        }

      :single_system ->
        %{
          coverage_ratio: 1.0,
          system_penetration: :complete
        }
    end
  end

  defp classify_penetration(active, total) do
    ratio = active / max(1, total)

    cond do
      ratio >= 0.8 -> :comprehensive
      ratio >= 0.5 -> :moderate
      ratio >= 0.3 -> :limited
      true -> :minimal
    end
  end

  defp identify_recon_indicators(metrics) do
    base_indicators = []

    # Scout activity
    scout_indicators =
      if metrics.scout_losses.count >= 3 do
        base_indicators ++ [{:scout_activity, metrics.scout_losses.count}]
      else
        base_indicators
      end

    # System exploration
    exploration_indicators =
      if metrics.exploration_patterns.systems_explored >= 5 do
        scout_indicators ++ [{:systematic_exploration, metrics.exploration_patterns.systems_explored}]
      else
        scout_indicators
      end

    # Intelligence gathering
    intelligence_indicators =
      if metrics.intelligence_gathering.intelligence_indicators do
        exploration_indicators ++ [{:intelligence_collection, metrics.intelligence_gathering.probe_kills}]
      else
        exploration_indicators
      end

    # Coverage
    if metrics.coverage_analysis.coverage_ratio > 0.5 do
      intelligence_indicators ++ [{:broad_coverage, metrics.coverage_analysis.coverage_ratio}]
    else
      intelligence_indicators
    end
  end

  defp describe_recon_pattern(indicators, _metrics) do
    indicator_types = Enum.map(indicators, fn {type, _} -> type end)

    cond do
      :systematic_exploration in indicator_types && :intelligence_collection in indicator_types ->
        "Comprehensive reconnaissance operation with systematic exploration"

      :scout_activity in indicator_types && :broad_coverage in indicator_types ->
        "Active scouting operation covering multiple systems"

      :systematic_exploration in indicator_types ->
        "Systematic exploration of target area"

      :scout_activity in indicator_types ->
        "Scout activity detected in operational area"

      true ->
        "Limited reconnaissance activity"
    end
  end

  # Private functions - Supply Line Disruption

  defp analyze_supply_disruption(strategic_data) do
    killmails = extract_all_killmails(strategic_data)

    %{
      hauler_interdiction: analyze_hauler_kills(killmails),
      route_disruption: analyze_route_disruption(strategic_data),
      timing_analysis: analyze_disruption_timing(killmails),
      effectiveness: calculate_disruption_effectiveness(killmails)
    }
  end

  defp analyze_hauler_kills(killmails) do
    hauler_types = [:hauler, :freighter, :transport, :industrial]

    hauler_kills =
      killmails
      |> Enum.filter(fn km ->
        classify_ship_type(km.victim.ship_type_id) in hauler_types
      end)

    %{
      count: length(hauler_kills),
      cargo_value_destroyed: estimate_cargo_destroyed(hauler_kills),
      interdiction_systems: identify_interdiction_systems(hauler_kills),
      hauler_types: classify_hauler_types(hauler_kills)
    }
  end

  defp estimate_cargo_destroyed(hauler_kills) do
    hauler_kills
    |> Enum.map(&Map.get(&1, :zkb_total_value, 0))
    |> Enum.sum()
  end

  defp identify_interdiction_systems(hauler_kills) do
    hauler_kills
    |> Enum.map(& &1.solar_system_id)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {system, count} ->
      %{system_id: system, interdiction_count: count}
    end)
  end

  defp classify_hauler_types(hauler_kills) do
    hauler_kills
    |> Enum.map(&classify_ship_type(&1.victim.ship_type_id))
    |> Enum.frequencies()
  end

  defp analyze_route_disruption(strategic_data) do
    case strategic_data.scope do
      :multi_system ->
        hauler_losses_by_system = identify_hauler_losses_by_system(strategic_data)
        potential_routes = identify_potential_routes(hauler_losses_by_system)

        %{
          disrupted_systems: Map.keys(hauler_losses_by_system),
          potential_routes: potential_routes,
          disruption_coverage: calculate_route_coverage(hauler_losses_by_system, strategic_data)
        }

      :single_system ->
        %{
          disrupted_systems: [strategic_data.system_id],
          potential_routes: [],
          disruption_coverage: 1.0
        }
    end
  end

  defp identify_hauler_losses_by_system(strategic_data) do
    strategic_data.killmail_data
    |> Enum.map(fn data ->
      hauler_count =
        data.killmails
        |> Enum.count(fn km ->
          classify_ship_type(km.victim.ship_type_id) in [
            :hauler,
            :freighter,
            :transport,
            :industrial
          ]
        end)

      {data.system_id, hauler_count}
    end)
    |> Enum.filter(fn {_, count} -> count > 0 end)
    |> Map.new()
  end

  defp identify_potential_routes(hauler_losses_by_system) do
    # Simplified route identification
    systems = Map.keys(hauler_losses_by_system)

    if length(systems) >= 2 do
      [
        %{
          systems: systems,
          disruption_level: :high,
          route_type: :supply_line
        }
      ]
    else
      []
    end
  end

  defp calculate_route_coverage(hauler_losses_by_system, strategic_data) do
    disrupted = map_size(hauler_losses_by_system)
    total = length(strategic_data.killmail_data)

    if total > 0 do
      Float.round(disrupted / total, 3)
    else
      0.0
    end
  end

  defp analyze_disruption_timing(killmails) do
    hauler_kills =
      killmails
      |> Enum.filter(fn km ->
        classify_ship_type(km.victim.ship_type_id) in [
          :hauler,
          :freighter,
          :transport,
          :industrial
        ]
      end)

    %{
      peak_disruption_times: identify_peak_disruption_times(hauler_kills),
      disruption_pattern: classify_disruption_pattern(hauler_kills),
      consistency: calculate_disruption_consistency(hauler_kills)
    }
  end

  defp identify_peak_disruption_times(hauler_kills) do
    hauler_kills
    |> Enum.group_by(& &1.timestamp.hour)
    |> Enum.map(fn {hour, kills} -> {hour, length(kills)} end)
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {hour, count} -> %{hour: hour, disruption_count: count} end)
  end

  defp classify_disruption_pattern(hauler_kills) do
    if length(hauler_kills) < 3 do
      :insufficient_data
    else
      time_distribution =
        hauler_kills
        |> Enum.map(& &1.timestamp.hour)
        |> Enum.frequencies()

      if map_size(time_distribution) <= 3 do
        :focused_timeframe
      else
        :distributed_disruption
      end
    end
  end

  defp calculate_disruption_consistency(hauler_kills) do
    if length(hauler_kills) < 2 do
      0.0
    else
      intervals =
        hauler_kills
        |> Enum.sort_by(& &1.timestamp, DateTime)
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [k1, k2] ->
          DateTime.diff(k2.timestamp, k1.timestamp, :hour)
        end)

      if not Enum.empty?(intervals) do
        avg_interval = average(intervals)
        variance = calculate_variance(intervals, avg_interval)
        cv = if avg_interval > 0, do: :math.sqrt(variance) / avg_interval, else: 1.0

        Float.round(max(0.0, min(1.0, 1.0 - cv)), 3)
      else
        0.0
      end
    end
  end

  defp calculate_disruption_effectiveness(killmails) do
    total_kills = length(killmails)

    hauler_kills =
      Enum.count(killmails, fn km ->
        classify_ship_type(km.victim.ship_type_id) in [
          :hauler,
          :freighter,
          :transport,
          :industrial
        ]
      end)

    %{
      hauler_kill_ratio:
        if(total_kills > 0, do: Float.round(hauler_kills / total_kills, 3), else: 0.0),
      focus_level: classify_focus_level(hauler_kills, total_kills)
    }
  end

  defp classify_focus_level(hauler_kills, total_kills) do
    if total_kills > 0 do
      ratio = hauler_kills / total_kills

      cond do
        ratio >= 0.5 -> :highly_focused
        ratio >= 0.3 -> :focused
        ratio >= 0.1 -> :moderate
        true -> :opportunistic
      end
    else
      :no_activity
    end
  end

  defp identify_disruption_indicators(metrics) do
    base_indicators = []

    # Hauler interdiction
    interdiction_indicators =
      if metrics.hauler_interdiction.count >= 5 do
        base_indicators ++ [{:active_interdiction, metrics.hauler_interdiction.count}]
      else
        base_indicators
      end

    # High cargo value
    value_indicators =
      if metrics.hauler_interdiction.cargo_value_destroyed > 1_000_000_000 do
        interdiction_indicators ++
          [{:high_value_disruption, metrics.hauler_interdiction.cargo_value_destroyed}]
      else
        interdiction_indicators
      end

    # Route coverage
    route_indicators =
      if metrics.route_disruption.disruption_coverage > 0.3 do
        value_indicators ++ [{:route_coverage, metrics.route_disruption.disruption_coverage}]
      else
        value_indicators
      end

    # Focused disruption
    if metrics.effectiveness.focus_level in [:highly_focused, :focused] do
      route_indicators ++ [{:focused_campaign, metrics.effectiveness.focus_level}]
    else
      route_indicators
    end
  end

  defp describe_disruption_pattern(indicators, _metrics) do
    indicator_types = Enum.map(indicators, fn {type, _} -> type end)

    cond do
      :active_interdiction in indicator_types && :high_value_disruption in indicator_types ->
        "Major supply line disruption with high-value targets destroyed"

      :focused_campaign in indicator_types && :route_coverage in indicator_types ->
        "Systematic disruption of supply routes across multiple systems"

      :active_interdiction in indicator_types ->
        "Active interdiction of supply vessels"

      :high_value_disruption in indicator_types ->
        "High-value cargo interdiction operations"

      true ->
        "Limited supply disruption activity"
    end
  end

  # Private functions - Offensive Preparation

  defp analyze_offensive_preparation(strategic_data) do
    killmails = extract_all_killmails(strategic_data)

    %{
      force_buildup: analyze_force_buildup(strategic_data),
      staging_activity: identify_staging_activity(strategic_data),
      combat_readiness: assess_combat_readiness(killmails),
      coordination_indicators: detect_coordination_patterns(killmails)
    }
  end

  defp analyze_force_buildup(strategic_data) do
    time_windows = create_time_windows(strategic_data.time_range)

    force_progression =
      time_windows
      |> Enum.map(fn {start_time, end_time} ->
        active_pilots = count_active_pilots_in_window(strategic_data, start_time, end_time)
        combat_ships = count_combat_ships_in_window(strategic_data, start_time, end_time)

        %{
          window: {start_time, end_time},
          active_pilots: active_pilots,
          combat_ships: combat_ships,
          force_index: active_pilots * 0.4 + combat_ships * 0.6
        }
      end)

    %{
      force_trend: determine_force_trend(force_progression),
      peak_force: Enum.max_by(force_progression, & &1.force_index, fn -> %{force_index: 0} end),
      buildup_rate: calculate_buildup_rate(force_progression)
    }
  end

  defp create_time_windows(time_range) do
    duration_days = DateTime.diff(time_range.until, time_range.since, :day)
    window_size = max(1, div(duration_days, 7))

    Stream.unfold(time_range.since, fn current ->
      if DateTime.compare(current, time_range.until) == :lt do
        window_end = DateTime.add(current, window_size * 24 * 3600, :second)

        window_end =
          if DateTime.compare(window_end, time_range.until) == :gt do
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

  defp count_active_pilots_in_window(strategic_data, start_time, end_time) do
    killmails = extract_all_killmails(strategic_data)

    killmails
    |> Enum.filter(fn km ->
      DateTime.compare(km.timestamp, start_time) != :lt &&
        DateTime.compare(km.timestamp, end_time) == :lt
    end)
    |> Enum.flat_map(fn km ->
      [km.victim.character_id | Enum.map(km.attackers, & &1.character_id)]
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> length()
  end

  defp count_combat_ships_in_window(strategic_data, start_time, end_time) do
    killmails = extract_all_killmails(strategic_data)

    killmails
    |> Enum.filter(fn km ->
      DateTime.compare(km.timestamp, start_time) != :lt &&
        DateTime.compare(km.timestamp, end_time) == :lt
    end)
    |> Enum.count(fn km ->
      ship_class = classify_ship_type(km.victim.ship_type_id)
      ship_class in [:battleship, :battlecruiser, :cruiser, :assault_frigate]
    end)
  end

  defp determine_force_trend(force_progression) do
    if length(force_progression) < 2 do
      :insufficient_data
    else
      indices = Enum.map(force_progression, & &1.force_index)

      first_half_avg =
        indices
        |> Enum.take(div(length(indices), 2))
        |> average()

      second_half_avg =
        indices
        |> Enum.drop(div(length(indices), 2))
        |> average()

      cond do
        second_half_avg > first_half_avg * 1.3 -> :rapid_buildup
        second_half_avg > first_half_avg * 1.1 -> :steady_buildup
        abs(second_half_avg - first_half_avg) < first_half_avg * 0.1 -> :stable
        true -> :declining
      end
    end
  end

  defp calculate_buildup_rate(force_progression) do
    if length(force_progression) < 2 do
      0.0
    else
      first = List.first(force_progression).force_index
      last = List.last(force_progression).force_index

      if first > 0 do
        Float.round((last - first) / first, 3)
      else
        0.0
      end
    end
  end

  defp identify_staging_activity(strategic_data) do
    case strategic_data.scope do
      :multi_system ->
        system_concentrations = calculate_system_concentrations(strategic_data)
        staging_systems = identify_staging_systems(system_concentrations)

        %{
          potential_staging: staging_systems,
          concentration_level: calculate_max_concentration(system_concentrations),
          staging_pattern: classify_staging_pattern(staging_systems)
        }

      :single_system ->
        %{
          potential_staging: [strategic_data.system_id],
          concentration_level: 1.0,
          staging_pattern: :single_system
        }
    end
  end

  defp calculate_system_concentrations(strategic_data) do
    total_activity =
      strategic_data.killmail_data
      |> Enum.map(& &1.kill_count)
      |> Enum.sum()

    if total_activity > 0 do
      strategic_data.killmail_data
      |> Enum.map(fn data ->
        concentration = data.kill_count / total_activity

        %{
          system_id: data.system_id,
          concentration: Float.round(concentration, 3),
          activity_level: data.kill_count
        }
      end)
      |> Enum.sort_by(& &1.concentration, :desc)
    else
      []
    end
  end

  defp identify_staging_systems(system_concentrations) do
    system_concentrations
    |> Enum.filter(&(&1.concentration > 0.2))
    |> Enum.take(3)
    |> Enum.map(& &1.system_id)
  end

  defp calculate_max_concentration(system_concentrations) do
    if not Enum.empty?(system_concentrations) do
      system_concentrations
      |> Enum.map(& &1.concentration)
      |> Enum.max()
    else
      0.0
    end
  end

  defp classify_staging_pattern(staging_systems) do
    case length(staging_systems) do
      0 -> :no_staging
      1 -> :centralized
      2 -> :dual_staging
      _ -> :distributed
    end
  end

  defp assess_combat_readiness(killmails) do
    combat_ships =
      killmails
      |> Enum.filter(fn km ->
        ship_class = classify_ship_type(km.victim.ship_type_id)
        ship_class in [:battleship, :battlecruiser, :cruiser, :assault_frigate]
      end)

    fleet_indicators = detect_fleet_activity(killmails)

    %{
      combat_ship_ratio: Float.round(length(combat_ships) / max(1, length(killmails)), 3),
      fleet_activity: fleet_indicators,
      engagement_readiness: calculate_engagement_readiness(killmails)
    }
  end

  defp detect_fleet_activity(killmails) do
    fleet_kills =
      killmails
      |> Enum.filter(&(length(&1.attackers) >= 10))

    %{
      fleet_engagements: length(fleet_kills),
      average_fleet_size: calculate_average_fleet_size(fleet_kills),
      fleet_ratio: Float.round(length(fleet_kills) / max(1, length(killmails)), 3)
    }
  end

  defp calculate_average_fleet_size(fleet_kills) do
    if Enum.empty?(fleet_kills) do
      0.0
    else
      total_attackers =
        fleet_kills
        |> Enum.map(&length(&1.attackers))
        |> Enum.sum()

      Float.round(total_attackers / length(fleet_kills), 1)
    end
  end

  defp calculate_engagement_readiness(killmails) do
    # Look for practice engagements or coordination
    coordinated_kills =
      killmails
      |> Enum.count(fn km ->
        # Multiple attackers from same corp
        corp_attackers =
          km.attackers
          |> Enum.map(& &1.corporation_id)
          |> Enum.reject(&is_nil/1)
          |> Enum.frequencies()
          |> Map.values()

        Enum.any?(corp_attackers, &(&1 >= 3))
      end)

    if not Enum.empty?(killmails) do
      Float.round(coordinated_kills / length(killmails), 3)
    else
      0.0
    end
  end

  defp detect_coordination_patterns(killmails) do
    # Look for signs of coordination
    time_clustered_kills = find_time_clusters(killmails)
    corp_coordination = analyze_corp_coordination(killmails)

    %{
      time_coordination: time_clustered_kills,
      corp_coordination: corp_coordination,
      coordination_score: calculate_coordination_score(time_clustered_kills, corp_coordination)
    }
  end

  defp find_time_clusters(killmails) do
    if length(killmails) < 3 do
      []
    else
      sorted_kills = Enum.sort_by(killmails, & &1.timestamp, DateTime)

      clusters =
        sorted_kills
        |> Enum.chunk_every(3, 1, :discard)
        |> Enum.filter(fn [k1, _k2, k3] ->
          DateTime.diff(k3.timestamp, k1.timestamp, :minute) <= 30
        end)

      %{
        cluster_count: length(clusters),
        clustering_ratio: Float.round(length(clusters) * 3 / max(1, length(killmails)), 3)
      }
    end
  end

  defp analyze_corp_coordination(killmails) do
    corp_kills =
      killmails
      |> Enum.group_by(fn km ->
        km.attackers
        |> Enum.map(& &1.corporation_id)
        |> Enum.reject(&is_nil/1)
        |> Enum.frequencies()
        |> Enum.max_by(fn {_, count} -> count end, fn -> {nil, 0} end)
        |> elem(0)
      end)

    coordinated_corps =
      corp_kills
      |> Enum.count(fn {corp, kills} -> corp != nil && length(kills) >= 3 end)

    %{
      coordinated_corporations: coordinated_corps,
      coordination_level: classify_coordination_level(coordinated_corps)
    }
  end

  defp classify_coordination_level(coordinated_corps) do
    cond do
      coordinated_corps >= 3 -> :high
      coordinated_corps >= 2 -> :moderate
      coordinated_corps >= 1 -> :low
      true -> :none
    end
  end

  defp calculate_coordination_score(time_clusters, corp_coordination) do
    time_score = min(1.0, time_clusters.clustering_ratio * 2)

    corp_score =
      case corp_coordination.coordination_level do
        :high -> 1.0
        :moderate -> 0.6
        :low -> 0.3
        :none -> 0.0
      end

    Float.round((time_score + corp_score) / 2, 3)
  end

  defp identify_preparation_indicators(metrics) do
    base_indicators = []

    # Force buildup
    buildup_indicators =
      if metrics.force_buildup.force_trend in [:rapid_buildup, :steady_buildup] do
        base_indicators ++ [{:force_buildup, metrics.force_buildup.buildup_rate}]
      else
        base_indicators
      end

    # Staging activity
    staging_indicators =
      if metrics.staging_activity.concentration_level > 0.3 do
        buildup_indicators ++ [{:staging_concentration, metrics.staging_activity.concentration_level}]
      else
        buildup_indicators
      end

    # Combat readiness
    readiness_indicators =
      if metrics.combat_readiness.combat_ship_ratio > 0.5 do
        staging_indicators ++ [{:combat_ready, metrics.combat_readiness.combat_ship_ratio}]
      else
        staging_indicators
      end

    # Coordination
    if metrics.coordination_indicators.coordination_score > 0.5 do
      readiness_indicators ++ [{:coordinated_activity, metrics.coordination_indicators.coordination_score}]
    else
      readiness_indicators
    end
  end

  defp describe_preparation_pattern(indicators, _metrics) do
    indicator_types = Enum.map(indicators, fn {type, _} -> type end)

    cond do
      :force_buildup in indicator_types && :coordinated_activity in indicator_types ->
        "Coordinated offensive preparation with force buildup"

      :staging_concentration in indicator_types && :combat_ready in indicator_types ->
        "Combat forces staging for potential offensive operations"

      :force_buildup in indicator_types ->
        "Military buildup detected suggesting offensive preparation"

      :coordinated_activity in indicator_types ->
        "Coordinated activity patterns indicating preparation phase"

      true ->
        "Limited offensive preparation indicators"
    end
  end

  # Shared helper functions

  defp extract_all_killmails(strategic_data) do
    case strategic_data.scope do
      :single_system -> strategic_data.killmails
      :multi_system -> Enum.flat_map(strategic_data.killmail_data, & &1.killmails)
    end
  end

  defp extract_spatial_data(strategic_data) do
    systems =
      case strategic_data.scope do
        :single_system -> [strategic_data.system_id]
        :multi_system -> Enum.map(strategic_data.killmail_data, & &1.system_id)
      end

    %{
      systems: systems,
      system_count: length(Enum.uniq(systems))
    }
  end

  defp extract_temporal_data(strategic_data) do
    %{
      start_time: strategic_data.time_range.since,
      end_time: strategic_data.time_range.until,
      duration_days:
        DateTime.diff(
          strategic_data.time_range.until,
          strategic_data.time_range.since,
          :day
        )
    }
  end

  defp calculate_pattern_confidence(indicators, metrics) do
    # Base confidence on number of indicators
    base_confidence = length(indicators) * 0.2

    # Add metric-specific bonuses
    metric_bonus = calculate_metric_bonus(metrics)

    min(1.0, base_confidence + metric_bonus)
  end

  defp calculate_metric_bonus(metrics) do
    # Generic bonus calculation based on metric strength
    metric_values = extract_metric_values(metrics)

    strong_metrics = Enum.count(metric_values, &(&1 > 0.5))
    strong_metrics * 0.1
  end

  defp extract_metric_values(metrics) do
    # Extract numeric values from metrics map
    metrics
    |> Map.values()
    |> Enum.flat_map(fn
      value when is_number(value) -> [value]
      value when is_map(value) -> extract_metric_values(value)
      _ -> []
    end)
  end

  defp classify_ship_type(ship_type_id) do
    # Use actual ship classification from static data
    case EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id) do
      {:ok, ship_class} -> ship_class
      {:error, _} -> :unknown
    end
  end

  defp average(list) do
    if Enum.empty?(list) do
      0.0
    else
      Enum.sum(list) / length(list)
    end
  end
end
