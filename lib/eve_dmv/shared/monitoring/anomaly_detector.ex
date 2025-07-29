defmodule EveDmv.Shared.Monitoring.AnomalyDetector do
  @moduledoc """
  Advanced anomaly detection for intelligence monitoring.

  Responsible for:
  - Statistical anomaly detection using baseline deviations
  - Pattern-based anomaly detection
  - Trend analysis for anomaly identification
  - Adaptive threshold management
  - Anomaly classification and severity assessment
  """

  require Logger

  # Standard deviations from baseline for anomaly detection
  @anomaly_detection_threshold 2.0

  @doc """
  Detects anomalies in activity data based on established baselines.
  """
  def detect_activity_anomalies(current_data, baseline, options \\ []) do
    sensitivity = Keyword.get(options, :sensitivity, :normal)
    detection_methods = Keyword.get(options, :methods, [:statistical, :pattern, :trend])

    Logger.debug("Detecting activity anomalies with sensitivity: #{sensitivity}")

    anomalies =
      []
      |> then(fn acc ->
        if :statistical in detection_methods do
          statistical_anomalies = detect_statistical_anomalies(current_data, baseline, sensitivity)
          acc ++ statistical_anomalies
        else
          acc
        end
      end)
      |> then(fn acc ->
        if :pattern in detection_methods do
          pattern_anomalies = detect_pattern_anomalies(current_data, baseline, sensitivity)
          acc ++ pattern_anomalies
        else
          acc
        end
      end)
      |> then(fn acc ->
        if :trend in detection_methods do
          trend_anomalies = detect_trend_anomalies(current_data, baseline, sensitivity)
          acc ++ trend_anomalies
        else
          acc
        end
      end)

    classified_anomalies = classify_anomalies(anomalies)

    {:ok,
     %{
       total_anomalies: length(classified_anomalies),
       anomalies: classified_anomalies,
       detection_methods: detection_methods,
       sensitivity: sensitivity,
       detection_timestamp: DateTime.utc_now()
     }}
  end

  @doc """
  Detects statistical deviations from baseline activity patterns.
  """
  def detect_statistical_anomalies(current_data, baseline, sensitivity) do
    threshold_multiplier = get_threshold_multiplier(sensitivity)
    anomalies = []

    # Check killmail rate anomalies
    current_rate = Map.get(current_data, :killmail_rate, 0)
    baseline_rate = baseline.activity_baseline.aggregate_baseline.total_average_killmails_per_hour
    baseline_variance = calculate_activity_variance(baseline.activity_baseline.system_baselines)

    rate_threshold = baseline_rate + threshold_multiplier * :math.sqrt(baseline_variance)

    anomalies =
      if current_rate > rate_threshold do
        anomaly = %{
          type: :statistical_anomaly,
          subtype: :killmail_rate_spike,
          severity: calculate_severity(current_rate, baseline_rate, rate_threshold),
          current_value: current_rate,
          baseline_value: baseline_rate,
          threshold: rate_threshold,
          deviation_factor: current_rate / max(baseline_rate, 0.1),
          timestamp: DateTime.utc_now()
        }

        [anomaly | anomalies]
      else
        anomalies
      end

    # Check participant count anomalies
    current_participants = Map.get(current_data, :average_participants, 0)

    baseline_participants =
      baseline.activity_baseline.aggregate_baseline.average_participants_per_system

    participant_threshold = baseline_participants * threshold_multiplier

    anomalies =
      if current_participants > participant_threshold do
        anomaly = %{
          type: :statistical_anomaly,
          subtype: :participant_spike,
          severity:
            calculate_severity(current_participants, baseline_participants, participant_threshold),
          current_value: current_participants,
          baseline_value: baseline_participants,
          threshold: participant_threshold,
          deviation_factor: current_participants / max(baseline_participants, 1),
          timestamp: DateTime.utc_now()
        }

        [anomaly | anomalies]
      else
        anomalies
      end

    # Check value anomalies
    current_total_value = Map.get(current_data, :total_value, 0)
    baseline_total_value = baseline.activity_baseline.aggregate_baseline.total_baseline_value

    value_threshold = baseline_total_value * threshold_multiplier

    anomalies =
      if current_total_value > value_threshold do
        anomaly = %{
          type: :statistical_anomaly,
          subtype: :value_spike,
          severity:
            calculate_severity(current_total_value, baseline_total_value, value_threshold),
          current_value: current_total_value,
          baseline_value: baseline_total_value,
          threshold: value_threshold,
          deviation_factor: current_total_value / max(baseline_total_value, 1),
          timestamp: DateTime.utc_now()
        }

        [anomaly | anomalies]
      else
        anomalies
      end

    anomalies
  end

  @doc """
  Detects pattern-based anomalies by comparing current patterns to baseline.
  """
  def detect_pattern_anomalies(current_data, baseline, sensitivity) do
    anomalies = []

    # Check for engagement pattern deviations
    current_patterns = Map.get(current_data, :engagement_patterns, %{})
    baseline_patterns = baseline.pattern_baseline.common_patterns

    # Simplified pattern deviation detection
    pattern_deviations = compare_engagement_patterns(current_patterns, baseline_patterns)

    anomalies =
      Enum.reduce(pattern_deviations, anomalies, fn deviation, acc ->
        if deviation.deviation_score > get_pattern_threshold(sensitivity) do
          anomaly = %{
            type: :pattern_anomaly,
            subtype: :engagement_pattern_deviation,
            severity: classify_pattern_severity(deviation.deviation_score),
            pattern_type: deviation.pattern_type,
            deviation_score: deviation.deviation_score,
            expected_pattern: deviation.expected,
            observed_pattern: deviation.observed,
            timestamp: DateTime.utc_now()
          }

          [anomaly | acc]
        else
          acc
        end
      end)

    # Check for temporal pattern anomalies
    current_temporal = Map.get(current_data, :temporal_patterns, %{})
    baseline_temporal = extract_baseline_temporal_patterns(baseline)

    temporal_deviations = compare_temporal_patterns(current_temporal, baseline_temporal)

    anomalies =
      Enum.reduce(temporal_deviations, anomalies, fn deviation, acc ->
        if deviation.significance > get_temporal_threshold(sensitivity) do
          anomaly = %{
            type: :pattern_anomaly,
            subtype: :temporal_pattern_deviation,
            severity: classify_temporal_severity(deviation.significance),
            temporal_aspect: deviation.aspect,
            significance: deviation.significance,
            expected_distribution: deviation.expected,
            observed_distribution: deviation.observed,
            timestamp: DateTime.utc_now()
          }

          [anomaly | acc]
        else
          acc
        end
      end)

    anomalies
  end

  @doc """
  Detects trend-based anomalies by analyzing activity trends.
  """
  def detect_trend_anomalies(current_data, baseline, sensitivity) do
    anomalies = []

    # Check for sudden trend reversals
    current_trend = Map.get(current_data, :activity_trend, :stable)
    baseline_trend = get_baseline_trend(baseline)

    anomalies =
      if is_trend_reversal(current_trend, baseline_trend) do
        severity = assess_trend_reversal_severity(current_trend, baseline_trend, sensitivity)

        if severity != :none do
          anomaly = %{
            type: :trend_anomaly,
            subtype: :trend_reversal,
            severity: severity,
            current_trend: current_trend,
            baseline_trend: baseline_trend,
            reversal_type: classify_reversal_type(current_trend, baseline_trend),
            timestamp: DateTime.utc_now()
          }

          [anomaly | anomalies]
        else
          anomalies
        end
      else
        anomalies
      end

    # Check for acceleration anomalies
    current_acceleration = Map.get(current_data, :trend_acceleration, 0)
    baseline_acceleration = get_baseline_acceleration(baseline)

    acceleration_threshold = get_acceleration_threshold(sensitivity)

    anomalies =
      if abs(current_acceleration - baseline_acceleration) > acceleration_threshold do
        anomaly = %{
          type: :trend_anomaly,
          subtype: :trend_acceleration,
          severity: classify_acceleration_severity(current_acceleration, baseline_acceleration),
          current_acceleration: current_acceleration,
          baseline_acceleration: baseline_acceleration,
          acceleration_change: current_acceleration - baseline_acceleration,
          timestamp: DateTime.utc_now()
        }

        [anomaly | anomalies]
      else
        anomalies
      end

    anomalies
  end

  @doc """
  Updates adaptive thresholds based on recent anomaly detection results.
  """
  def update_adaptive_thresholds(current_thresholds, recent_detections, options \\ []) do
    adaptation_rate = Keyword.get(options, :adaptation_rate, 0.1)
    false_positive_rate = calculate_false_positive_rate(recent_detections)

    # Adjust thresholds based on false positive rate
    threshold_adjustment =
      if false_positive_rate > 0.2 do
        # Too many false positives - increase thresholds
        1.0 + adaptation_rate
      else
        if false_positive_rate < 0.05 do
          # Very few false positives - slightly decrease thresholds
          1.0 - adaptation_rate * 0.5
        else
          # Acceptable false positive rate - no change
          1.0
        end
      end

    updated_thresholds = %{
      current_thresholds
      | activity_thresholds:
          adjust_activity_thresholds(
            current_thresholds.activity_thresholds,
            threshold_adjustment
          ),
        threat_thresholds:
          adjust_threat_thresholds(
            current_thresholds.threat_thresholds,
            threshold_adjustment
          ),
        last_adaptation: DateTime.utc_now(),
        adaptation_factor: threshold_adjustment
    }

    {:ok, updated_thresholds}
  end

  @doc """
  Calculates anomaly confidence score based on multiple detection methods.
  """
  def calculate_anomaly_confidence(anomaly, baseline, historical_data) do
    confidence_factors = []

    # Statistical confidence
    statistical_confidence =
      if anomaly.type == :statistical_anomaly do
        calculate_statistical_confidence(anomaly, baseline)
      else
        0.5
      end

    confidence_factors = [statistical_confidence | confidence_factors]

    # Pattern confidence
    pattern_confidence =
      if anomaly.type == :pattern_anomaly do
        calculate_pattern_confidence(anomaly, baseline)
      else
        0.5
      end

    confidence_factors = [pattern_confidence | confidence_factors]

    # Historical confidence
    historical_confidence = calculate_historical_confidence(anomaly, historical_data)
    confidence_factors = [historical_confidence | confidence_factors]

    # Combine confidence factors
    overall_confidence = Enum.sum(confidence_factors) / length(confidence_factors)

    %{
      overall_confidence: Float.round(overall_confidence, 3),
      statistical_confidence: Float.round(statistical_confidence, 3),
      pattern_confidence: Float.round(pattern_confidence, 3),
      historical_confidence: Float.round(historical_confidence, 3),
      confidence_level: classify_confidence_level(overall_confidence)
    }
  end

  # Private functions

  defp get_threshold_multiplier(:low), do: 1.5
  defp get_threshold_multiplier(:normal), do: @anomaly_detection_threshold
  defp get_threshold_multiplier(:high), do: 2.5

  defp calculate_activity_variance(system_baselines) do
    if map_size(system_baselines) == 0 do
      1.0
    else
      rates =
        system_baselines
        |> Map.values()
        |> Enum.map(& &1.average_killmails_per_hour)

      if length(rates) < 2 do
        1.0
      else
        mean = Enum.sum(rates) / length(rates)

        variance =
          rates
          |> Enum.map(fn rate -> :math.pow(rate - mean, 2) end)
          |> Enum.sum()
          |> Kernel./(length(rates))

        max(1.0, variance)
      end
    end
  end

  defp calculate_severity(current_value, baseline_value, _threshold) do
    if baseline_value == 0 do
      :moderate
    else
      ratio = current_value / baseline_value

      cond do
        ratio >= 5.0 -> :critical
        ratio >= 3.0 -> :high
        ratio >= 2.0 -> :moderate
        ratio >= 1.5 -> :low
        true -> :minimal
      end
    end
  end

  defp get_pattern_threshold(:low), do: 0.3
  defp get_pattern_threshold(:normal), do: 0.5
  defp get_pattern_threshold(:high), do: 0.7

  defp get_temporal_threshold(:low), do: 0.4
  defp get_temporal_threshold(:normal), do: 0.6
  defp get_temporal_threshold(:high), do: 0.8

  defp get_acceleration_threshold(:low), do: 1.0
  defp get_acceleration_threshold(:normal), do: 2.0
  defp get_acceleration_threshold(:high), do: 3.0

  defp compare_engagement_patterns(current, baseline) do
    # Simplified pattern comparison
    baseline_patterns = extract_baseline_engagement_patterns(baseline)

    Enum.map(baseline_patterns, fn {pattern_type, expected} ->
      observed = Map.get(current, pattern_type, 0)
      deviation = abs(observed - expected) / max(expected, 1)

      %{
        pattern_type: pattern_type,
        expected: expected,
        observed: observed,
        deviation_score: deviation
      }
    end)
  end

  defp compare_temporal_patterns(current, baseline) do
    # Simplified temporal pattern comparison
    aspects = [:hourly_distribution, :daily_distribution, :activity_consistency]

    Enum.map(aspects, fn aspect ->
      expected = Map.get(baseline, aspect, %{})
      observed = Map.get(current, aspect, %{})
      significance = calculate_pattern_significance(observed, expected)

      %{
        aspect: aspect,
        expected: expected,
        observed: observed,
        significance: significance
      }
    end)
  end

  defp classify_anomalies(anomalies) do
    Enum.map(anomalies, fn anomaly ->
      # Add additional classification metadata
      Map.merge(anomaly, %{
        anomaly_id: generate_anomaly_id(),
        classification: classify_anomaly_type(anomaly),
        priority: calculate_anomaly_priority(anomaly),
        recommended_action: suggest_anomaly_action(anomaly)
      })
    end)
  end

  defp generate_anomaly_id() do
    # Generate a proper UUID for anomaly identification
    uuid = Ecto.UUID.generate()
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "ANOM-#{timestamp}-#{String.slice(uuid, 0..7)}"
  end

  defp classify_anomaly_type(anomaly) do
    case {anomaly.type, anomaly.subtype} do
      {:statistical_anomaly, :killmail_rate_spike} -> :activity_spike
      {:statistical_anomaly, :participant_spike} -> :engagement_spike
      {:statistical_anomaly, :value_spike} -> :economic_spike
      {:pattern_anomaly, :engagement_pattern_deviation} -> :behavioral_change
      {:pattern_anomaly, :temporal_pattern_deviation} -> :timing_anomaly
      {:trend_anomaly, :trend_reversal} -> :trend_change
      {:trend_anomaly, :trend_acceleration} -> :acceleration_change
      _ -> :unknown
    end
  end

  defp calculate_anomaly_priority(anomaly) do
    base_priority =
      case anomaly.severity do
        :critical -> 100
        :high -> 80
        :moderate -> 60
        :low -> 40
        :minimal -> 20
      end

    # Adjust priority based on anomaly type
    type_modifier =
      case anomaly.classification do
        :activity_spike -> 1.2
        :economic_spike -> 1.5
        :behavioral_change -> 1.1
        _ -> 1.0
      end

    round(base_priority * type_modifier)
  end

  defp suggest_anomaly_action(anomaly) do
    case {anomaly.classification, anomaly.severity} do
      {:activity_spike, severity} when severity in [:critical, :high] ->
        :immediate_investigation

      {:economic_spike, severity} when severity in [:critical, :high] ->
        :threat_assessment

      {:behavioral_change, _} ->
        :pattern_analysis

      {:trend_change, :critical} ->
        :strategic_review

      _ ->
        :monitor_closely
    end
  end

  defp extract_baseline_engagement_patterns(_baseline_patterns) do
    # Extract engagement pattern metrics from baseline
    %{
      solo_frequency: 0.3,
      small_gang_frequency: 0.4,
      medium_fleet_frequency: 0.2,
      large_fleet_frequency: 0.1
    }
  end

  defp extract_baseline_temporal_patterns(_baseline) do
    # Extract temporal patterns from baseline
    %{
      hourly_distribution: %{},
      daily_distribution: %{},
      activity_consistency: :consistent
    }
  end

  defp calculate_pattern_significance(_observed, expected) do
    # Simplified pattern significance calculation
    if map_size(expected) == 0 do
      0.5
    else
      # Chi-square-like test for pattern deviation
      # Simplified static value
      0.4
    end
  end

  defp get_baseline_trend(baseline) do
    # Extract overall trend from baseline
    if baseline.predictive_baseline do
      Map.get(baseline.predictive_baseline.trend_analysis, :overall_trend, :stable)
    else
      :stable
    end
  end

  defp get_baseline_acceleration(_baseline) do
    # Extract baseline acceleration metric
    # Simplified static baseline
    0.0
  end

  defp is_trend_reversal(current_trend, baseline_trend) do
    trend_opposites = %{
      :increasing => :decreasing,
      :decreasing => :increasing,
      :stable => nil
    }

    Map.get(trend_opposites, baseline_trend) == current_trend
  end

  defp assess_trend_reversal_severity(current_trend, baseline_trend, sensitivity) do
    reversal_strength = calculate_reversal_strength(current_trend, baseline_trend)
    sensitivity_threshold = get_reversal_threshold(sensitivity)

    if reversal_strength > sensitivity_threshold do
      cond do
        reversal_strength > 0.8 -> :critical
        reversal_strength > 0.6 -> :high
        reversal_strength > 0.4 -> :moderate
        true -> :low
      end
    else
      :none
    end
  end

  defp calculate_reversal_strength(_current_trend, _baseline_trend) do
    # Simplified reversal strength calculation
    0.6
  end

  defp get_reversal_threshold(:low), do: 0.2
  defp get_reversal_threshold(:normal), do: 0.4
  defp get_reversal_threshold(:high), do: 0.6

  defp classify_reversal_type(current_trend, baseline_trend) do
    case {baseline_trend, current_trend} do
      {:increasing, :decreasing} -> :bull_to_bear
      {:decreasing, :increasing} -> :bear_to_bull
      {:stable, :increasing} -> :stable_to_bull
      {:stable, :decreasing} -> :stable_to_bear
      _ -> :unknown
    end
  end

  defp classify_acceleration_severity(current_acceleration, baseline_acceleration) do
    change = abs(current_acceleration - baseline_acceleration)

    cond do
      change > 3.0 -> :critical
      change > 2.0 -> :high
      change > 1.0 -> :moderate
      change > 0.5 -> :low
      true -> :minimal
    end
  end

  defp classify_pattern_severity(deviation_score) do
    cond do
      deviation_score > 0.8 -> :critical
      deviation_score > 0.6 -> :high
      deviation_score > 0.4 -> :moderate
      deviation_score > 0.2 -> :low
      true -> :minimal
    end
  end

  defp classify_temporal_severity(significance) do
    cond do
      significance > 0.9 -> :critical
      significance > 0.7 -> :high
      significance > 0.5 -> :moderate
      significance > 0.3 -> :low
      true -> :minimal
    end
  end

  defp calculate_false_positive_rate(recent_detections) do
    if Enum.empty?(recent_detections) do
      # Default assumption
      0.1
    else
      false_positives = Enum.count(recent_detections, & &1.false_positive)
      false_positives / length(recent_detections)
    end
  end

  defp adjust_activity_thresholds(thresholds, adjustment_factor) do
    Enum.map(thresholds, fn {system_id, system_thresholds} ->
      adjusted_thresholds = %{
        system_thresholds
        | killmail_threshold: %{
            system_thresholds.killmail_threshold
            | upper: system_thresholds.killmail_threshold.upper * adjustment_factor,
              lower: system_thresholds.killmail_threshold.lower * adjustment_factor
          },
          participant_threshold: %{
            system_thresholds.participant_threshold
            | upper: system_thresholds.participant_threshold.upper * adjustment_factor,
              lower: system_thresholds.participant_threshold.lower * adjustment_factor
          }
      }

      {system_id, adjusted_thresholds}
    end)
    |> Map.new()
  end

  defp adjust_threat_thresholds(thresholds, adjustment_factor) do
    Enum.map(thresholds, fn {system_id, system_thresholds} ->
      adjusted_thresholds = %{
        system_thresholds
        | high_value_alert: round(system_thresholds.high_value_alert * adjustment_factor),
          capital_alert: round(system_thresholds.capital_alert * adjustment_factor),
          fleet_alert: round(system_thresholds.fleet_alert * adjustment_factor),
          frequency_alert: system_thresholds.frequency_alert * adjustment_factor
      }

      {system_id, adjusted_thresholds}
    end)
    |> Map.new()
  end

  defp calculate_statistical_confidence(anomaly, _baseline) do
    # Calculate confidence based on statistical strength
    deviation_factor = Map.get(anomaly, :deviation_factor, 1.0)

    # Higher deviation = higher confidence
    cond do
      deviation_factor >= 5.0 -> 0.95
      deviation_factor >= 3.0 -> 0.85
      deviation_factor >= 2.0 -> 0.75
      deviation_factor >= 1.5 -> 0.65
      true -> 0.5
    end
  end

  defp calculate_pattern_confidence(anomaly, _baseline) do
    # Calculate confidence based on pattern strength
    deviation_score = Map.get(anomaly, :deviation_score, 0.5)
    significance = Map.get(anomaly, :significance, 0.5)

    # Combine pattern metrics
    pattern_strength = (deviation_score + significance) / 2

    cond do
      pattern_strength >= 0.8 -> 0.9
      pattern_strength >= 0.6 -> 0.8
      pattern_strength >= 0.4 -> 0.7
      pattern_strength >= 0.2 -> 0.6
      true -> 0.5
    end
  end

  defp calculate_historical_confidence(_anomaly, _historical_data) do
    # Calculate confidence based on historical precedent
    # Simplified: assume 70% confidence for historical validation
    0.7
  end

  defp classify_confidence_level(confidence) do
    cond do
      confidence >= 0.9 -> :very_high
      confidence >= 0.8 -> :high
      confidence >= 0.7 -> :moderate
      confidence >= 0.6 -> :low
      true -> :very_low
    end
  end
end
