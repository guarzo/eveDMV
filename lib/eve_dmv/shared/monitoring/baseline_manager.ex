defmodule EveDmv.Shared.Monitoring.BaselineManager do
  @moduledoc """
  Manages intelligence baselines for monitoring systems.

  Responsible for:
  - Baseline data collection
  - Activity baseline calculation
  - Pattern baseline calculation
  - Threat baseline calculation
  - Baseline validation and quality assessment
  """

  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw

  require Logger

  @baseline_establishment_window_hours 24

  @doc """
  Establishes intelligence baseline for the specified monitoring scope.
  """
  def establish_intelligence_baseline(monitored_systems, options \\ []) do
    baseline_window_hours =
      Keyword.get(options, :baseline_window_hours, @baseline_establishment_window_hours)

    include_predictive_baseline = Keyword.get(options, :include_predictive_baseline, true)
    baseline_confidence_threshold = Keyword.get(options, :confidence_threshold, 0.7)

    Logger.info("Establishing intelligence baseline for #{length(monitored_systems)} systems")

    start_time = System.monotonic_time(:millisecond)

    with {:ok, historical_data} <-
           collect_baseline_data(monitored_systems, baseline_window_hours),
         {:ok, activity_baseline} <- calculate_activity_baseline(historical_data),
         {:ok, pattern_baseline} <- calculate_pattern_baseline(historical_data),
         {:ok, threat_baseline} <- calculate_threat_baseline(historical_data),
         {:ok, predictive_baseline} <-
           maybe_calculate_predictive_baseline(historical_data, include_predictive_baseline),
         {:ok, baseline_metrics} <-
           compile_baseline_metrics(
             activity_baseline,
             pattern_baseline,
             threat_baseline,
             predictive_baseline
           ),
         {:ok, baseline_validation} <-
           validate_baseline_quality(baseline_metrics, baseline_confidence_threshold) do
      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      Logger.info("Intelligence baseline established in #{duration_ms}ms")

      {:ok,
       %{
         monitored_systems: monitored_systems,
         baseline_window:
           {DateTime.utc_now() |> DateTime.add(-baseline_window_hours * 3600, :second),
            DateTime.utc_now()},
         activity_baseline: activity_baseline,
         pattern_baseline: pattern_baseline,
         threat_baseline: threat_baseline,
         predictive_baseline: predictive_baseline,
         baseline_metrics: baseline_metrics,
         baseline_validation: baseline_validation,
         establishment_duration_ms: duration_ms,
         established_at: DateTime.utc_now()
       }}
    else
      error -> error
    end
  end

  # Private functions

  defp collect_baseline_data(monitored_systems, baseline_window_hours) do
    since = DateTime.utc_now() |> DateTime.add(-baseline_window_hours * 3600, :second)

    try do
      system_data =
        Enum.map(monitored_systems, fn system_id ->
          killmails =
            Api.read!(KillmailRaw,
              filter: [
                solar_system_id: system_id,
                timestamp: [greater_than: since]
              ],
              limit: 1000
            )

          {system_id,
           %{
             killmails: killmails,
             system_id: system_id,
             data_window: {since, DateTime.utc_now()},
             killmail_count: length(killmails)
           }}
        end)
        |> Enum.into(%{})

      total_killmails =
        system_data
        |> Map.values()
        |> Enum.map(& &1.killmail_count)
        |> Enum.sum()

      data_quality_assessment = assess_baseline_data_quality(system_data)

      {:ok,
       %{
         systems: system_data,
         total_killmails: total_killmails,
         data_collection_window: {since, DateTime.utc_now()},
         data_quality: data_quality_assessment
       }}
    catch
      error ->
        Logger.error("Failed to collect baseline data: #{inspect(error)}")
        {:error, :baseline_data_collection_failed}
    end
  end

  defp assess_baseline_data_quality(system_data) do
    system_count = map_size(system_data)

    systems_with_data =
      system_data
      |> Map.values()
      |> Enum.count(&(&1.killmail_count > 0))

    total_killmails =
      system_data
      |> Map.values()
      |> Enum.map(& &1.killmail_count)
      |> Enum.sum()

    average_per_system = if system_count > 0, do: total_killmails / system_count, else: 0

    data_coverage = if system_count > 0, do: systems_with_data / system_count, else: 0

    quality_score =
      cond do
        data_coverage >= 0.8 && average_per_system >= 10 -> :excellent
        data_coverage >= 0.6 && average_per_system >= 5 -> :good
        data_coverage >= 0.4 && average_per_system >= 2 -> :fair
        true -> :poor
      end

    %{
      total_systems: system_count,
      systems_with_data: systems_with_data,
      data_coverage: Float.round(data_coverage, 3),
      total_killmails: total_killmails,
      average_per_system: Float.round(average_per_system, 2),
      quality_score: quality_score
    }
  end

  defp calculate_activity_baseline(historical_data) do
    system_baselines =
      historical_data.systems
      |> Enum.map(fn {system_id, system_data} ->
        killmails = system_data.killmails

        activity_metrics = %{
          average_killmails_per_hour: calculate_average_killmails_per_hour(killmails),
          peak_activity_hours: identify_peak_activity_hours(killmails),
          activity_variance: calculate_activity_variance(killmails),
          participant_baseline: calculate_participant_baseline(killmails),
          value_baseline: calculate_value_baseline(killmails),
          temporal_patterns: analyze_temporal_patterns(killmails)
        }

        {system_id, activity_metrics}
      end)
      |> Map.new()

    aggregate_baseline = calculate_aggregate_activity_baseline(system_baselines)
    confidence = calculate_activity_baseline_confidence(system_baselines)
    anomaly_thresholds = calculate_activity_anomaly_thresholds(system_baselines)

    {:ok,
     %{
       system_baselines: system_baselines,
       aggregate_baseline: aggregate_baseline,
       confidence: confidence,
       anomaly_thresholds: anomaly_thresholds
     }}
  end

  defp calculate_average_killmails_per_hour(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      time_span_hours = calculate_time_span_hours(killmails)

      if time_span_hours > 0 do
        length(killmails) / time_span_hours
      else
        0.0
      end
    end
  end

  defp calculate_time_span_hours(killmails) do
    if length(killmails) < 2 do
      1.0
    else
      first = Enum.min_by(killmails, & &1.timestamp).timestamp
      last = Enum.max_by(killmails, & &1.timestamp).timestamp
      max(1.0, DateTime.diff(last, first, :hour))
    end
  end

  defp identify_peak_activity_hours(killmails) do
    killmails
    |> group_killmails_by_hour()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {hour, count} -> %{hour: hour, kill_count: count} end)
  end

  defp calculate_activity_variance(killmails) do
    hourly_counts =
      killmails
      |> group_killmails_by_hour()
      |> Map.values()

    if length(hourly_counts) < 2 do
      0.0
    else
      mean = Enum.sum(hourly_counts) / length(hourly_counts)

      variance =
        hourly_counts
        |> Enum.map(fn count -> :math.pow(count - mean, 2) end)
        |> Enum.sum()
        |> Kernel./(length(hourly_counts))

      Float.round(variance, 3)
    end
  end

  defp calculate_participant_baseline(killmails) do
    participants =
      killmails
      |> Enum.flat_map(fn km ->
        [km.victim.character_id | Enum.map(km.attackers, & &1.character_id)]
      end)
      |> Enum.reject(&is_nil/1)

    unique_participants = Enum.uniq(participants)

    %{
      total_participants: length(participants),
      unique_participants: length(unique_participants),
      participation_ratio:
        if(Enum.empty?(participants),
          do: 0,
          else: length(unique_participants) / length(participants)
        ),
      average_participants_per_kill:
        if(Enum.empty?(killmails), do: 0, else: length(participants) / length(killmails))
    }
  end

  defp calculate_value_baseline(killmails) do
    values = Enum.map(killmails, &Map.get(&1, :zkb_total_value, 0))

    if Enum.empty?(values) do
      %{total_value: 0, average_value: 0, median_value: 0, max_value: 0}
    else
      sorted_values = Enum.sort(values)
      median_value = Enum.at(sorted_values, div(length(sorted_values), 2))

      %{
        total_value: Enum.sum(values),
        average_value: Enum.sum(values) / length(values),
        median_value: median_value,
        max_value: Enum.max(values),
        value_concentration: calculate_value_concentration(values)
      }
    end
  end

  defp calculate_value_concentration(values) do
    # Simplified Gini coefficient calculation
    if length(values) < 2 do
      0.0
    else
      sorted = Enum.sort(values)
      total = Enum.sum(sorted)

      if total == 0 do
        0.0
      else
        top_20_percent =
          sorted
          |> Enum.reverse()
          |> Enum.take(max(1, div(length(sorted), 5)))
          |> Enum.sum()

        Float.round(top_20_percent / total, 3)
      end
    end
  end

  defp analyze_temporal_patterns(killmails) do
    clustering = assess_temporal_clustering_baseline(killmails)
    consistency = calculate_temporal_consistency(killmails)

    %{
      temporal_clustering: clustering,
      temporal_consistency: consistency
    }
  end

  defp assess_temporal_clustering_baseline(killmails) do
    if length(killmails) < 3 do
      %{clustering_detected: false, cluster_count: 0, average_cluster_size: 0}
    else
      sorted_kills = Enum.sort_by(killmails, & &1.timestamp, DateTime)

      # 1 hour clusters
      clusters = find_temporal_clusters(sorted_kills, 3600)

      %{
        clustering_detected: not Enum.empty?(clusters),
        cluster_count: length(clusters),
        average_cluster_size:
          if(Enum.empty?(clusters),
            do: 0,
            else: Enum.sum(Enum.map(clusters, &length/1)) / length(clusters)
          )
      }
    end
  end

  defp find_temporal_clusters([], _), do: []

  defp find_temporal_clusters([first | rest], max_gap_seconds) do
    {cluster, remaining} = build_cluster([first], rest, max_gap_seconds)

    if length(cluster) >= 2 do
      [cluster | find_temporal_clusters(remaining, max_gap_seconds)]
    else
      find_temporal_clusters(remaining, max_gap_seconds)
    end
  end

  defp build_cluster(cluster, [], _), do: {cluster, []}

  defp build_cluster(cluster, [next | rest], max_gap_seconds) do
    last_time = List.last(cluster).timestamp

    if DateTime.diff(next.timestamp, last_time, :second) <= max_gap_seconds do
      build_cluster(cluster ++ [next], rest, max_gap_seconds)
    else
      {cluster, [next | rest]}
    end
  end

  defp calculate_temporal_consistency(killmails) do
    if length(killmails) < 2 do
      1.0
    else
      intervals =
        killmails
        |> Enum.sort_by(& &1.timestamp, DateTime)
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [k1, k2] -> DateTime.diff(k2.timestamp, k1.timestamp, :second) end)

      if Enum.empty?(intervals) do
        1.0
      else
        mean_interval = Enum.sum(intervals) / length(intervals)

        if mean_interval == 0 do
          1.0
        else
          calculate_consistency_score(intervals, mean_interval)
        end
      end
    end
  end

  defp calculate_consistency_score(intervals, mean_interval) do
    variance = calculate_variance(intervals, mean_interval)
    cv = :math.sqrt(variance) / mean_interval
    Float.round(max(0.0, 1.0 - cv), 3)
  end

  defp group_killmails_by_hour(killmails) do
    killmails
    |> Enum.group_by(fn km -> km.timestamp.hour end)
    |> Enum.map(fn {hour, kms} -> {hour, length(kms)} end)
    |> Map.new()
  end

  defp calculate_aggregate_activity_baseline(system_baselines) do
    if map_size(system_baselines) == 0 do
      %{
        total_killmails_per_hour: 0.0,
        average_participants: 0.0,
        overall_activity_level: :minimal,
        confidence: 0.0
      }
    else
      total_killmails_per_hour =
        system_baselines
        |> Map.values()
        |> Enum.map(& &1.average_killmails_per_hour)
        |> Enum.sum()

      avg_participants =
        system_baselines
        |> Map.values()
        |> Enum.map(& &1.participant_baseline.average_participants_per_kill)
        |> Enum.sum()
        |> Kernel./(map_size(system_baselines))

      overall_level = classify_overall_activity_level(total_killmails_per_hour, avg_participants)

      %{
        total_killmails_per_hour: Float.round(total_killmails_per_hour, 2),
        average_participants: Float.round(avg_participants, 2),
        overall_activity_level: overall_level,
        systems_analyzed: map_size(system_baselines)
      }
    end
  end

  defp classify_overall_activity_level(total_killmails_per_hour, avg_participants) do
    cond do
      total_killmails_per_hour >= 10 && avg_participants >= 5 -> :very_high
      total_killmails_per_hour >= 5 && avg_participants >= 3 -> :high
      total_killmails_per_hour >= 2 && avg_participants >= 2 -> :moderate
      total_killmails_per_hour >= 0.5 -> :low
      true -> :minimal
    end
  end

  defp calculate_activity_baseline_confidence(system_baselines) do
    if map_size(system_baselines) == 0 do
      0.0
    else
      # Confidence based on data consistency across systems
      variances =
        system_baselines
        |> Map.values()
        |> Enum.map(& &1.activity_variance)

      temporal_consistencies =
        system_baselines
        |> Map.values()
        |> Enum.map(& &1.temporal_patterns.temporal_consistency)

      avg_variance = Enum.sum(variances) / length(variances)
      avg_consistency = Enum.sum(temporal_consistencies) / length(temporal_consistencies)

      # Lower variance and higher consistency = higher confidence
      confidence = (avg_consistency + (1.0 - min(1.0, avg_variance / 10))) / 2
      Float.round(confidence, 3)
    end
  end

  defp calculate_activity_anomaly_thresholds(system_baselines) do
    if map_size(system_baselines) == 0 do
      %{
        killmail_rate_threshold: 0,
        participant_threshold: 0,
        value_threshold: 0
      }
    else
      # Calculate thresholds as 2 standard deviations from baseline
      killmail_rates = Enum.map(Map.values(system_baselines), & &1.average_killmails_per_hour)

      participant_counts =
        Enum.map(
          Map.values(system_baselines),
          & &1.participant_baseline.average_participants_per_kill
        )

      values = Enum.map(Map.values(system_baselines), & &1.value_baseline.average_value)

      %{
        killmail_rate_threshold: calculate_threshold(killmail_rates, 2.0),
        participant_threshold: calculate_threshold(participant_counts, 2.0),
        value_threshold: calculate_threshold(values, 2.0)
      }
    end
  end

  defp calculate_threshold(values, std_devs) do
    if length(values) < 2 do
      0
    else
      mean = Enum.sum(values) / length(values)

      variance =
        values
        |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
        |> Enum.sum()
        |> Kernel./(length(values))

      std_dev = :math.sqrt(variance)

      Float.round(mean + std_devs * std_dev, 2)
    end
  end

  defp calculate_pattern_baseline(_historical_data) do
    # Simplified pattern baseline - would use actual pattern detection in production
    {:ok,
     %{
       engagement_patterns: %{diversity: 0.5, peak_hours: [18, 19, 20]},
       participant_patterns: %{key_players: [], participation_distribution: :normal},
       value_patterns: %{high_value_frequency: 0.1, concentration: 0.3},
       confidence: 0.7
     }}
  end

  defp calculate_threat_baseline(historical_data) do
    all_killmails =
      historical_data.systems
      |> Map.values()
      |> Enum.flat_map(& &1.killmails)

    threat_indicators = %{
      high_value_threats: count_high_value_threats(all_killmails),
      capital_ship_threats: count_capital_ship_threats(all_killmails),
      fleet_threats: count_fleet_threats(all_killmails),
      pod_kills: count_pod_kills(all_killmails),
      threat_frequency: calculate_threat_frequency(all_killmails),
      threat_severity: assess_threat_severity(all_killmails)
    }

    aggregate_baseline = calculate_aggregate_threat_baseline(threat_indicators)
    confidence = calculate_threat_baseline_confidence(threat_indicators)
    alert_thresholds = calculate_threat_alert_thresholds(threat_indicators)

    {:ok,
     %{
       threat_indicators: threat_indicators,
       aggregate_baseline: aggregate_baseline,
       confidence: confidence,
       alert_thresholds: alert_thresholds
     }}
  end

  defp count_high_value_threats(killmails) do
    Enum.count(killmails, &(Map.get(&1, :zkb_total_value, 0) > 100_000_000))
  end

  defp count_capital_ship_threats(killmails) do
    # Simplified - would use actual ship type data
    Enum.count(killmails, fn km ->
      ship_type_id = km.victim.ship_type_id
      # Use actual ship classification
      case EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id) do
        {:ok, ship_class}
        when ship_class in [:carrier, :dreadnought, :titan, :supercarrier, :force_auxiliary] ->
          true

        _ ->
          false
      end
    end)
  end

  defp count_fleet_threats(killmails) do
    Enum.count(killmails, &(length(&1.attackers) >= 10))
  end

  defp count_pod_kills(killmails) do
    # Use actual pod ship type IDs
    # Capsule (pod) type_id is 670 and Capsule - Genolution 'Auroral' 197-variant is 33328
    pod_type_ids = [670, 33328]

    Enum.count(killmails, fn km ->
      km.victim.ship_type_id in pod_type_ids
    end)
  end

  defp calculate_threat_frequency(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      time_span = calculate_time_span_hours(killmails)
      threat_count = count_high_value_threats(killmails) + count_capital_ship_threats(killmails)

      if time_span > 0 do
        Float.round(threat_count / time_span, 3)
      else
        0.0
      end
    end
  end

  defp assess_threat_severity(killmails) do
    if Enum.empty?(killmails) do
      :minimal
    else
      high_value_ratio = count_high_value_threats(killmails) / length(killmails)
      capital_ratio = count_capital_ship_threats(killmails) / length(killmails)

      cond do
        high_value_ratio > 0.3 || capital_ratio > 0.1 -> :critical
        high_value_ratio > 0.1 || capital_ratio > 0.05 -> :high
        high_value_ratio > 0.05 -> :moderate
        true -> :low
      end
    end
  end

  defp calculate_aggregate_threat_baseline(threat_indicators) do
    overall_level =
      assess_overall_threat_level(
        threat_indicators.high_value_threats,
        threat_indicators.capital_ship_threats,
        threat_indicators.fleet_threats,
        threat_indicators.threat_frequency
      )

    %{
      overall_threat_level: overall_level,
      primary_threat_types: identify_primary_threat_types(threat_indicators),
      threat_frequency_baseline: threat_indicators.threat_frequency
    }
  end

  defp assess_overall_threat_level(high_value_count, capital_count, fleet_count, avg_frequency) do
    threat_score =
      high_value_count * 0.3 +
        capital_count * 0.4 +
        fleet_count * 0.2 +
        avg_frequency * 10 * 0.1

    cond do
      threat_score > 10 -> :critical
      threat_score > 5 -> :high
      threat_score > 2 -> :moderate
      threat_score > 0.5 -> :low
      true -> :minimal
    end
  end

  defp identify_primary_threat_types(threat_indicators) do
    threats =
      []
      |> then(fn threats ->
        if threat_indicators.high_value_threats > 2 do
          threats ++ [:high_value_targets]
        else
          threats
        end
      end)
      |> then(fn threats ->
        if threat_indicators.capital_ship_threats > 1 do
          threats ++ [:capital_ships]
        else
          threats
        end
      end)
      |> then(fn threats ->
        if threat_indicators.fleet_threats > 3 do
          threats ++ [:fleet_operations]
        else
          threats
        end
      end)

    if Enum.empty?(threats), do: [:minimal_threats], else: threats
  end

  defp calculate_threat_baseline_confidence(threat_indicators) do
    # Confidence based on threat data availability
    data_points = [
      threat_indicators.high_value_threats,
      threat_indicators.capital_ship_threats,
      threat_indicators.fleet_threats,
      threat_indicators.pod_kills
    ]

    total_data = Enum.sum(data_points)

    cond do
      total_data >= 20 -> 0.9
      total_data >= 10 -> 0.7
      total_data >= 5 -> 0.5
      total_data >= 1 -> 0.3
      true -> 0.1
    end
  end

  defp calculate_threat_alert_thresholds(threat_indicators) do
    base_multiplier = 2.0

    %{
      high_value_threshold: max(1, round(threat_indicators.high_value_threats * base_multiplier)),
      capital_ship_threshold:
        max(1, round(threat_indicators.capital_ship_threats * base_multiplier)),
      fleet_threshold: max(2, round(threat_indicators.fleet_threats * base_multiplier)),
      frequency_threshold: threat_indicators.threat_frequency * base_multiplier
    }
  end

  defp maybe_calculate_predictive_baseline(historical_data, true) do
    calculate_predictive_patterns(historical_data)
  end

  defp maybe_calculate_predictive_baseline(_historical_data, false) do
    {:ok, %{enabled: false}}
  end

  defp calculate_predictive_patterns(_historical_data) do
    # Simplified predictive baseline
    {:ok,
     %{
       enabled: true,
       trend_indicators: %{activity_trend: :stable, threat_trend: :stable},
       seasonal_patterns: %{detected: false},
       escalation_indicators: %{likelihood: :low},
       confidence: 0.5
     }}
  end

  defp compile_baseline_metrics(
         activity_baseline,
         pattern_baseline,
         threat_baseline,
         predictive_baseline
       ) do
    overall_quality =
      calculate_overall_baseline_quality(
        activity_baseline.confidence,
        pattern_baseline.confidence,
        threat_baseline.confidence
      )

    completeness =
      assess_baseline_completeness(activity_baseline, pattern_baseline, threat_baseline)

    anomaly_readiness = assess_anomaly_detection_readiness(activity_baseline, threat_baseline)

    {:ok,
     %{
       overall_quality: overall_quality,
       completeness: completeness,
       anomaly_detection_readiness: anomaly_readiness,
       predictive_capabilities: Map.get(predictive_baseline, :enabled, false)
     }}
  end

  defp calculate_overall_baseline_quality(activity_conf, pattern_conf, threat_conf) do
    Float.round((activity_conf + pattern_conf + threat_conf) / 3, 3)
  end

  defp assess_baseline_completeness(activity_baseline, pattern_baseline, threat_baseline) do
    components = %{
      activity_data: map_size(activity_baseline.system_baselines) > 0,
      pattern_data: pattern_baseline.confidence > 0,
      threat_data: threat_baseline.confidence > 0,
      thresholds_configured: map_size(activity_baseline.anomaly_thresholds) > 0
    }

    complete_count = Enum.count(Map.values(components), & &1)

    %{
      components: components,
      completeness_percentage: Float.round(complete_count / 4 * 100, 1),
      is_complete: complete_count == 4
    }
  end

  defp assess_anomaly_detection_readiness(activity_baseline, threat_baseline) do
    activity_ready = activity_baseline.confidence > 0.5
    threat_ready = threat_baseline.confidence > 0.5
    thresholds_set = map_size(activity_baseline.anomaly_thresholds) > 0

    readiness_score =
      [activity_ready, threat_ready, thresholds_set]
      |> Enum.count(& &1)
      |> Kernel./(3)

    %{
      ready: readiness_score >= 0.67,
      readiness_score: Float.round(readiness_score, 3),
      missing_components:
        identify_missing_components(activity_ready, threat_ready, thresholds_set)
    }
  end

  defp identify_missing_components(activity_ready, threat_ready, thresholds_set) do
    []
    |> then(fn missing -> if activity_ready, do: missing, else: missing ++ [:activity_baseline] end)
    |> then(fn missing -> if threat_ready, do: missing, else: missing ++ [:threat_baseline] end)
    |> then(fn missing -> if thresholds_set, do: missing, else: missing ++ [:anomaly_thresholds] end)
  end

  defp validate_baseline_quality(baseline_metrics, confidence_threshold) do
    quality_score = baseline_metrics.overall_quality

    validation_result = %{
      meets_threshold: quality_score >= confidence_threshold,
      quality_score: quality_score,
      confidence_threshold: confidence_threshold,
      validation_status: if(quality_score >= confidence_threshold, do: :passed, else: :failed),
      recommendations:
        generate_quality_recommendations(baseline_metrics, quality_score, confidence_threshold)
    }

    if validation_result.meets_threshold do
      {:ok, validation_result}
    else
      {:error, {:baseline_quality_insufficient, validation_result}}
    end
  end

  defp generate_quality_recommendations(baseline_metrics, quality_score, threshold) do
    recommendations =
      []
      |> then(fn recommendations ->
        if quality_score < threshold do
          recommendations ++ ["Increase baseline data collection window"]
        else
          recommendations
        end
      end)
      |> then(fn recommendations ->
        if baseline_metrics.completeness.is_complete do
          recommendations
        else
          recommendations ++ ["Ensure all baseline components are collected"]
        end
      end)
      |> then(fn recommendations ->
        if baseline_metrics.anomaly_detection_readiness.ready do
          recommendations
        else
          recommendations ++ ["Configure anomaly detection thresholds"]
        end
      end)

    if Enum.empty?(recommendations) do
      ["Baseline quality meets requirements"]
    else
      recommendations
    end
  end

  defp calculate_variance(intervals, mean_interval) do
    intervals
    |> Enum.map(fn i -> :math.pow(i - mean_interval, 2) end)
    |> Enum.sum()
    |> Kernel./(length(intervals))
  end
end
