defmodule EveDmv.Contexts.SystemAnalysis.Domain.RegionalCorrelationAnalyzer do
  @moduledoc """
  Analyzes correlations between system activities within a region.
  Identifies patterns, clusters, and escalation chains.
  """

  import Ash.Query

  alias EveDmv.Eve.SolarSystem
  alias EveDmv.Killmails.KillmailRaw

  @doc """
  Analyzes activity correlations across a region
  """
  def analyze_regional_correlations(region_id, timeframe_opts \\ []) do
    timeframe = build_timeframe(timeframe_opts)

    with {:ok, systems} <- get_region_systems(region_id),
         {:ok, activity_data} <- get_temporal_activity_data(systems, timeframe) do
      # Calculate correlation matrix
      correlation_matrix = calculate_correlation_matrix(activity_data)

      # Identify patterns
      clusters = identify_activity_clusters(correlation_matrix, systems)
      escalations = detect_escalation_patterns(activity_data)
      hotspots = identify_hotspot_systems(activity_data, correlation_matrix)
      corridors = identify_activity_corridors(activity_data, systems)

      {:ok,
       %{
         region_id: region_id,
         timeframe: timeframe,
         correlation_matrix: correlation_matrix,
         activity_clusters: clusters,
         escalation_chains: escalations,
         hotspot_systems: hotspots,
         activity_corridors: corridors,
         network_metrics: calculate_network_metrics(correlation_matrix),
         predictions: generate_activity_predictions(activity_data, correlation_matrix)
       }}
    end
  end

  @doc """
  Detects activity spillover between systems
  """
  def analyze_activity_spillover(source_system_id, timeframe_opts \\ []) do
    timeframe = build_timeframe(timeframe_opts)

    with {:ok, source_activity} <- get_system_activity(source_system_id, timeframe),
         {:ok, neighbors} <- get_connected_systems(source_system_id),
         {:ok, neighbor_activities} <- get_multi_system_activity(neighbors, timeframe) do
      spillover_analysis =
        Enum.map(neighbor_activities, fn {neighbor_id, activity} ->
          %{
            system_id: neighbor_id,
            spillover_score: calculate_spillover_score(source_activity, activity),
            time_lag: detect_time_lag(source_activity, activity),
            correlation: calculate_correlation(source_activity, activity),
            causality_probability: estimate_causality(source_activity, activity)
          }
        end)

      {:ok,
       %{
         source_system: source_system_id,
         spillover_effects: spillover_analysis,
         influence_radius: calculate_influence_radius(spillover_analysis),
         propagation_speed: estimate_propagation_speed(spillover_analysis)
       }}
    end
  end

  defp build_timeframe(opts) do
    default_hours = Keyword.get(opts, :hours, 24)
    default_days = Keyword.get(opts, :days, 0)

    total_hours = default_hours + default_days * 24

    %{
      start_time: DateTime.add(DateTime.utc_now(), -total_hours * 3600, :second),
      end_time: DateTime.utc_now(),
      duration_hours: total_hours
    }
  end

  defp get_region_systems(region_id) do
    systems =
      SolarSystem
      |> filter(region_id == ^region_id)
      |> Ash.read!(domain: EveDmv.Api)

    {:ok, systems}
  rescue
    error ->
      {:error, {:region_query_failed, error}}
  end

  defp get_temporal_activity_data(systems, timeframe) do
    system_ids = Enum.map(systems, & &1.system_id)

    # Get hourly activity for correlation analysis
    killmails =
      KillmailRaw
      |> filter(solar_system_id in ^system_ids)
      |> filter(killmail_time >= ^timeframe.start_time)
      |> filter(killmail_time <= ^timeframe.end_time)
      |> select([:killmail_id, :solar_system_id, :killmail_time])
      |> Ash.read!(domain: EveDmv.Api)

    hourly_data = group_by_hour_and_system(killmails)

    {:ok, hourly_data}
  rescue
    error ->
      {:error, {:temporal_data_query_failed, error}}
  end

  defp group_by_hour_and_system(killmails) do
    killmails
    |> Enum.group_by(& &1.solar_system_id)
    |> Enum.map(fn {system_id, system_kills} ->
      # Group by hour for correlation analysis
      hourly_counts =
        system_kills
        |> Enum.group_by(fn kill ->
          DateTime.to_unix(kill.killmail_time, :second)
          # Group by hour
          |> div(3600)
          # Back to timestamp
          |> Kernel.*(3600)
        end)
        |> Enum.map(fn {hour_timestamp, kills} ->
          {hour_timestamp, length(kills)}
        end)
        |> Map.new()

      {system_id, hourly_counts}
    end)
    |> Map.new()
  end

  defp calculate_correlation_matrix(activity_data) do
    systems = Map.keys(activity_data)

    # Build correlation matrix
    matrix =
      for system1 <- systems, into: %{} do
        correlations =
          for system2 <- systems, into: %{} do
            correlation =
              if system1 == system2 do
                1.0
              else
                calculate_pearson_correlation(
                  activity_data[system1],
                  activity_data[system2]
                )
              end

            {system2, correlation}
          end

        {system1, correlations}
      end

    matrix
  end

  defp identify_activity_clusters(correlation_matrix, systems) do
    # Use correlation threshold to identify clusters
    threshold = 0.6

    clusters =
      systems
      |> Enum.reduce([], fn system, acc ->
        correlated_systems =
          correlation_matrix[system.system_id]
          |> Enum.filter(fn {_sys_id, corr} -> corr > threshold end)
          |> Enum.map(fn {sys_id, _corr} -> sys_id end)

        if length(correlated_systems) > 1 do
          [{system.system_id, correlated_systems} | acc]
        else
          acc
        end
      end)
      |> merge_overlapping_clusters()
      |> Enum.map(fn cluster ->
        %{
          systems: cluster,
          cohesion: calculate_cluster_cohesion(cluster, correlation_matrix),
          centroid: find_cluster_centroid(cluster, systems),
          classification: classify_cluster(cluster, systems)
        }
      end)

    clusters
  end

  defp detect_escalation_patterns(activity_data) do
    # Detect cascading activity patterns
    escalations = []

    # For each system, check if activity spike propagates
    Enum.reduce(activity_data, escalations, fn {system_id, activity}, acc ->
      spikes = detect_activity_spikes(activity)

      Enum.reduce(spikes, acc, fn spike, escalations ->
        chain = trace_escalation_chain(spike, system_id, activity_data)

        if length(chain) > 1 do
          [
            %{
              origin: system_id,
              chain: chain,
              start_time: spike.time,
              duration: calculate_chain_duration(chain),
              intensity: calculate_chain_intensity(chain),
              systems_affected: length(chain)
            }
            | escalations
          ]
        else
          escalations
        end
      end)
    end)
  end

  defp identify_hotspot_systems(activity_data, correlation_matrix) do
    # Identify systems that drive regional activity
    influence_scores =
      Enum.map(activity_data, fn {system_id, activity} ->
        # Calculate influence based on correlations and activity level
        correlations = Map.get(correlation_matrix, system_id, %{})

        influence =
          correlations
          |> Enum.reduce(0, fn {other_id, correlation}, acc ->
            if other_id != system_id do
              other_activity = Map.get(activity_data, other_id, %{})
              activity_level = Map.values(other_activity) |> Enum.sum()
              acc + correlation * activity_level
            else
              acc
            end
          end)

        activity_level = Map.values(activity) |> Enum.sum()

        %{
          system_id: system_id,
          influence_score: influence,
          activity_level: activity_level,
          correlation_strength: calculate_avg_correlation(correlations),
          classification: classify_hotspot(influence, activity_level)
        }
      end)
      |> Enum.sort_by(& &1.influence_score, :desc)
      # Top 10 hotspots
      |> Enum.take(10)

    influence_scores
  end

  defp identify_activity_corridors(activity_data, systems) do
    # Find paths of connected systems with correlated activity
    # Simplified implementation - would use actual stargate data in production
    corridors =
      systems
      # Groups of 3 consecutive systems
      |> Enum.chunk_every(3, 1, :discard)
      |> Enum.filter(fn system_group ->
        system_ids = Enum.map(system_group, & &1.system_id)
        has_correlated_activity?(system_ids, activity_data)
      end)
      |> Enum.map(fn corridor_systems ->
        system_ids = Enum.map(corridor_systems, & &1.system_id)

        %{
          systems: system_ids,
          activity_flow: analyze_flow_direction(system_ids, activity_data),
          throughput: calculate_corridor_throughput(system_ids, activity_data),
          importance: calculate_corridor_importance(system_ids),
          chokepoints: identify_corridor_chokepoints(system_ids)
        }
      end)
      |> Enum.sort_by(& &1.importance, :desc)
      # Top 5 corridors
      |> Enum.take(5)

    corridors
  end

  defp calculate_pearson_correlation(series1_map, series2_map) do
    # Get common time points
    common_times =
      MapSet.new(Map.keys(series1_map))
      |> MapSet.intersection(MapSet.new(Map.keys(series2_map)))

    if MapSet.size(common_times) < 2 do
      0.0
    else
      # Extract values for common times
      s1 = Enum.map(common_times, &Map.get(series1_map, &1, 0))
      s2 = Enum.map(common_times, &Map.get(series2_map, &1, 0))

      n = length(s1)

      # Calculate means
      mean1 = Enum.sum(s1) / n
      mean2 = Enum.sum(s2) / n

      # Calculate correlation
      numerator =
        Enum.zip(s1, s2)
        |> Enum.reduce(0, fn {x, y}, acc ->
          acc + (x - mean1) * (y - mean2)
        end)

      denominator1 =
        :math.sqrt(
          Enum.reduce(s1, 0, fn x, acc ->
            acc + :math.pow(x - mean1, 2)
          end)
        )

      denominator2 =
        :math.sqrt(
          Enum.reduce(s2, 0, fn y, acc ->
            acc + :math.pow(y - mean2, 2)
          end)
        )

      if denominator1 * denominator2 == 0 do
        0.0
      else
        numerator / (denominator1 * denominator2)
      end
    end
  end

  defp calculate_network_metrics(correlation_matrix) do
    # Calculate overall network cohesion and structure
    all_correlations =
      correlation_matrix
      |> Enum.flat_map(fn {_sys, corrs} ->
        Enum.map(corrs, fn {_other, corr} -> corr end)
      end)
      # Remove self-correlations
      |> Enum.reject(&(&1 == 1.0))

    case all_correlations do
      [] ->
        %{
          average_correlation: 0.0,
          max_correlation: 0.0,
          min_correlation: 0.0,
          network_cohesion: 0.0,
          clustering_coefficient: 0.0,
          modularity: 0.0
        }

      correlations ->
        %{
          average_correlation: calculate_average(correlations),
          max_correlation: Enum.max(correlations),
          min_correlation: Enum.min(correlations),
          network_cohesion: calculate_cohesion(correlations),
          clustering_coefficient: calculate_clustering_coefficient(correlation_matrix),
          modularity: calculate_modularity(correlation_matrix)
        }
    end
  end

  defp calculate_average(values) do
    case values do
      [] -> 0.0
      list -> Enum.sum(list) / length(list)
    end
  end

  defp calculate_cohesion(correlations) do
    # Network cohesion based on positive correlations
    positive_corrs = Enum.filter(correlations, &(&1 > 0))

    case positive_corrs do
      [] -> 0.0
      corrs -> calculate_average(corrs)
    end
  end

  defp calculate_clustering_coefficient(_correlation_matrix) do
    # Simplified clustering coefficient calculation
    # Would implement proper graph clustering in production
    0.5
  end

  defp calculate_modularity(_correlation_matrix) do
    # Simplified modularity calculation
    # Would implement proper community detection in production
    0.3
  end

  defp generate_activity_predictions(activity_data, correlation_matrix) do
    # Generate predictions based on current patterns
    %{
      next_hotspot: predict_next_hotspot(activity_data, correlation_matrix),
      escalation_risk: assess_escalation_risk(activity_data),
      quiet_periods: predict_quiet_periods(activity_data),
      activity_forecast: generate_24h_forecast(activity_data, correlation_matrix)
    }
  end

  # Helper functions for spillover analysis

  defp get_system_activity(system_id, timeframe) do
    killmails =
      KillmailRaw
      |> filter(solar_system_id == ^system_id)
      |> filter(killmail_time >= ^timeframe.start_time)
      |> filter(killmail_time <= ^timeframe.end_time)
      |> select([:killmail_id, :killmail_time])
      |> Ash.read!(domain: EveDmv.Api)

    # Group by hour
    hourly_activity =
      killmails
      |> Enum.group_by(fn kill ->
        DateTime.to_unix(kill.killmail_time, :second) |> div(3600)
      end)
      |> Enum.map(fn {hour, kills} -> {hour, length(kills)} end)
      |> Map.new()

    {:ok, hourly_activity}
  rescue
    error ->
      {:error, {:system_activity_query_failed, error}}
  end

  defp get_connected_systems(system_id) do
    # Simplified - would query actual stargate connections in production
    # For now, get systems in same constellation
    system =
      SolarSystem
      |> filter(system_id == ^system_id)
      |> Ash.read_one!(domain: EveDmv.Api)

    neighbors =
      case system do
        nil ->
          []

        sys ->
          SolarSystem
          |> filter(constellation_id == ^sys.constellation_id)
          |> filter(system_id != ^system_id)
          |> limit(10)
          |> Ash.read!(domain: EveDmv.Api)
          |> Enum.map(& &1.system_id)
      end

    {:ok, neighbors}
  rescue
    error ->
      {:error, {:neighbor_query_failed, error}}
  end

  defp get_multi_system_activity(system_ids, timeframe) do
    activities =
      system_ids
      |> Enum.map(fn system_id ->
        case get_system_activity(system_id, timeframe) do
          {:ok, activity} -> {system_id, activity}
          _ -> {system_id, %{}}
        end
      end)
      |> Map.new()

    {:ok, activities}
  end

  # Simplified implementations for complex analysis functions

  defp merge_overlapping_clusters(clusters) do
    # Simplified cluster merging
    clusters
    |> Enum.map(&elem(&1, 1))
    |> Enum.uniq()
  end

  defp calculate_cluster_cohesion(cluster, correlation_matrix) do
    if length(cluster) < 2 do
      1.0
    else
      correlations =
        for s1 <- cluster, s2 <- cluster, s1 != s2 do
          correlation_matrix[s1][s2] || 0.0
        end

      calculate_average(correlations)
    end
  end

  defp find_cluster_centroid(cluster, systems) do
    # Find geographic center of cluster
    cluster_systems =
      systems
      |> Enum.filter(fn system -> system.system_id in cluster end)

    case cluster_systems do
      [] ->
        nil

      sys_list ->
        avg_x = sys_list |> Enum.map(& &1.x_coordinate) |> calculate_average()
        avg_y = sys_list |> Enum.map(& &1.y_coordinate) |> calculate_average()
        avg_z = sys_list |> Enum.map(& &1.z_coordinate) |> calculate_average()

        %{x: avg_x, y: avg_y, z: avg_z}
    end
  end

  defp classify_cluster(cluster, systems) do
    cluster_systems =
      systems
      |> Enum.filter(fn system -> system.system_id in cluster end)

    security_classes =
      cluster_systems
      |> Enum.map(& &1.security_class)
      |> Enum.uniq()

    cond do
      length(security_classes) > 1 -> :mixed_security
      "nullsec" in security_classes -> :nullsec_cluster
      "lowsec" in security_classes -> :lowsec_cluster
      "highsec" in security_classes -> :highsec_cluster
      true -> :unknown
    end
  end

  defp detect_activity_spikes(activity_map) do
    # Detect unusual activity spikes
    values = Map.values(activity_map)

    case values do
      [] ->
        []

      activity_values ->
        avg = calculate_average(activity_values)
        # Spike threshold
        threshold = avg * 2

        activity_map
        |> Enum.filter(fn {_time, count} -> count > threshold end)
        |> Enum.map(fn {time, count} ->
          %{time: time, intensity: count, threshold_multiplier: count / max(avg, 1)}
        end)
    end
  end

  defp trace_escalation_chain(spike, system_id, _activity_data) do
    # Trace how activity spreads from spike origin
    # Simplified implementation
    [%{system_id: system_id, time: spike.time, intensity: spike.intensity}]
  end

  defp calculate_chain_duration(chain) do
    case chain do
      [] ->
        0

      [_single] ->
        0

      multiple ->
        times = Enum.map(multiple, & &1.time)
        Enum.max(times) - Enum.min(times)
    end
  end

  defp calculate_chain_intensity(chain) do
    chain
    |> Enum.map(& &1.intensity)
    |> Enum.sum()
  end

  defp calculate_avg_correlation(correlations) do
    values =
      Map.values(correlations)
      # Remove self-correlation
      |> Enum.reject(&(&1 == 1.0))

    calculate_average(values)
  end

  defp classify_hotspot(influence, activity_level) do
    combined_score = influence + activity_level

    cond do
      combined_score > 100 -> :major_hub
      combined_score > 50 -> :regional_hub
      combined_score > 20 -> :local_hotspot
      combined_score > 5 -> :minor_activity
      true -> :quiet
    end
  end

  defp has_correlated_activity?(system_ids, activity_data) do
    # Check if systems have correlated activity
    activities = Enum.map(system_ids, &Map.get(activity_data, &1, %{}))

    # Simple check - if multiple systems have activity in same time periods
    all_times =
      activities
      |> Enum.flat_map(&Map.keys/1)
      |> Enum.uniq()

    overlap_count =
      all_times
      |> Enum.count(fn time ->
        Enum.count(activities, &Map.has_key?(&1, time)) > 1
      end)

    overlap_count > 0
  end

  defp analyze_flow_direction(system_ids, activity_data) do
    # Simplified flow analysis
    activities =
      Enum.map(system_ids, fn id ->
        Map.get(activity_data, id, %{}) |> Map.values() |> Enum.sum()
      end)

    case activities do
      [a, b, c] when a > b and b > c -> :decreasing
      [a, b, c] when a < b and b < c -> :increasing
      _ -> :mixed
    end
  end

  defp calculate_corridor_throughput(system_ids, activity_data) do
    system_ids
    |> Enum.map(fn id ->
      Map.get(activity_data, id, %{}) |> Map.values() |> Enum.sum()
    end)
    |> Enum.sum()
  end

  defp calculate_corridor_importance(system_ids) do
    # Simplified importance calculation based on system count
    length(system_ids) * 10
  end

  defp identify_corridor_chokepoints(_system_ids) do
    # Simplified chokepoint identification
    []
  end

  defp calculate_spillover_score(source_activity, neighbor_activity) do
    # Calculate how much source activity affects neighbor
    source_total = Map.values(source_activity) |> Enum.sum()
    neighbor_total = Map.values(neighbor_activity) |> Enum.sum()

    correlation = calculate_pearson_correlation(source_activity, neighbor_activity)

    # Spillover score combines correlation and activity levels
    correlation * :math.sqrt(source_total * neighbor_total) / 100
  end

  defp detect_time_lag(_source_activity, _neighbor_activity) do
    # Detect time delay between source and neighbor activity
    # Simplified - would use cross-correlation in production
    0
  end

  defp calculate_correlation(source_activity, neighbor_activity) do
    calculate_pearson_correlation(source_activity, neighbor_activity)
  end

  defp estimate_causality(_source_activity, _neighbor_activity) do
    # Simplified causality estimation
    # Would use Granger causality or similar in production
    0.5
  end

  defp calculate_influence_radius(spillover_analysis) do
    # Calculate how far influence extends
    spillover_analysis
    |> Enum.filter(fn analysis -> analysis.spillover_score > 0.1 end)
    |> length()
  end

  defp estimate_propagation_speed(_spillover_analysis) do
    # Estimate how fast activity propagates
    # Would analyze time lags in production
    # minutes
    5.0
  end

  # Prediction helper functions (simplified)

  defp predict_next_hotspot(activity_data, _correlation_matrix) do
    # Find system with increasing trend
    activity_data
    |> Enum.max_by(
      fn {_id, activity} ->
        Map.values(activity) |> Enum.sum()
      end,
      fn -> {nil, %{}} end
    )
    |> elem(0)
  end

  defp assess_escalation_risk(activity_data) do
    # Assess risk of activity escalation
    total_activity =
      activity_data
      |> Enum.map(fn {_id, activity} -> Map.values(activity) |> Enum.sum() end)
      |> Enum.sum()

    cond do
      total_activity > 100 -> :high
      total_activity > 50 -> :moderate
      total_activity > 10 -> :low
      true -> :minimal
    end
  end

  defp predict_quiet_periods(_activity_data) do
    # Predict when activity will be low
    # Simplified - would use historical patterns in production
    []
  end

  defp generate_24h_forecast(_activity_data, _correlation_matrix) do
    # Generate 24-hour activity forecast
    # Simplified prediction
    %{
      peak_hours: [18, 19, 20, 21],
      quiet_hours: [6, 7, 8, 9],
      confidence: 0.6
    }
  end
end
