defmodule EveDmv.Shared.Monitoring.Facade do
  @moduledoc """
  Facade for the monitoring system providing backward compatibility.

  Coordinates between the modular monitoring components:
  - BaselineManager: Baseline establishment and validation
  - StreamManager: Real-time streaming and processing
  - AnomalyDetector: Anomaly detection and classification
  - AlertManager: Alert generation and delivery

  Maintains the same interface as the original MonitoringEngine.
  """

  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Shared.Monitoring.AlertManager
  alias EveDmv.Shared.Monitoring.AnomalyDetector
  alias EveDmv.Shared.Monitoring.BaselineManager
  alias EveDmv.Shared.Monitoring.StreamManager

  require Logger

  @doc """
  Establishes intelligence baseline for the specified monitoring scope.
  """
  def establish_intelligence_baseline(monitored_systems, options \\ []) do
    BaselineManager.establish_intelligence_baseline(monitored_systems, options)
  end

  @doc """
  Sets up intelligence monitoring with configured parameters.
  """
  def setup_intelligence_monitoring(monitored_systems, baseline, options \\ []) do
    monitoring_interval = Keyword.get(options, :monitoring_interval_minutes, 5)
    alert_thresholds = Keyword.get(options, :alert_thresholds, %{})
    enable_predictive_monitoring = Keyword.get(options, :enable_predictive_monitoring, true)
    monitoring_focus = Keyword.get(options, :monitoring_focus, [:activity, :patterns, :threats])

    Logger.info("Setting up monitoring for #{length(monitored_systems)} systems")

    with {:ok, validated_config} <-
           validate_monitoring_config(
             monitored_systems,
             baseline,
             monitoring_interval,
             alert_thresholds,
             monitoring_focus
           ),
         {:ok, monitoring_state} <- initialize_monitoring_state(validated_config),
         {:ok, alert_system} <-
           AlertManager.setup_alert_system(validated_config.alert_thresholds),
         {:ok, predictive_monitors} <-
           maybe_setup_predictive_monitoring(baseline, enable_predictive_monitoring) do
      {:ok,
       %{
         monitoring_id: generate_monitoring_id(),
         monitored_systems: monitored_systems,
         baseline_reference: baseline,
         monitoring_config: validated_config,
         monitoring_state: monitoring_state,
         alert_system: alert_system,
         predictive_monitors: predictive_monitors,
         setup_timestamp: DateTime.utc_now(),
         status: :configured
       }}
    else
      error -> error
    end
  end

  @doc """
  Starts real-time intelligence streaming and monitoring.
  """
  def start_intelligence_stream(monitoring_setup, stream_options \\ []) do
    StreamManager.start_intelligence_stream(monitoring_setup, stream_options)
  end

  @doc """
  Detects anomalies in current monitoring data.
  """
  def detect_anomalies(current_data, baseline, options \\ []) do
    AnomalyDetector.detect_activity_anomalies(current_data, baseline, options)
  end

  @doc """
  Generates and processes alerts for detected anomalies.
  """
  def process_anomaly_alerts(anomalies, baseline, alert_manager, options \\ []) do
    with {:ok, alert_result} <- AlertManager.generate_alerts(anomalies, baseline, options),
         {:ok, processing_result} <-
           AlertManager.process_alert_queue(alert_manager, alert_result.alerts) do
      {:ok,
       %{
         alerts_generated: alert_result.alerts_generated,
         alerts_processed: length(processing_result.processed_alerts),
         alerts: alert_result.alerts,
         processed_alerts: processing_result.processed_alerts,
         updated_alert_manager: processing_result.alert_manager
       }}
    else
      error -> error
    end
  end

  @doc """
  Updates adaptive monitoring thresholds based on detection results.
  """
  @spec update_monitoring_thresholds(map(), list(), keyword()) :: no_return()
  def update_monitoring_thresholds(monitoring_setup, recent_detections, options \\ []) do
    current_thresholds = get_current_thresholds(monitoring_setup)

    case AnomalyDetector.update_adaptive_thresholds(
           current_thresholds,
           recent_detections,
           options
         ) do
      {:ok, updated_thresholds} ->
        updated_setup = update_monitoring_setup_thresholds(monitoring_setup, updated_thresholds)

        {:ok,
         %{
           updated_monitoring_setup: updated_setup,
           threshold_changes: calculate_threshold_changes(current_thresholds, updated_thresholds),
           update_timestamp: DateTime.utc_now()
         }}
    end
  end

  @doc """
  Handles alert escalation and delivery.
  """
  def handle_alert_escalation(alert_manager, options \\ []) do
    current_time = Keyword.get(options, :current_time, DateTime.utc_now())

    case AlertManager.handle_alert_escalation(alert_manager, current_time) do
      {:ok, escalated_alerts} ->
        if Enum.empty?(escalated_alerts) do
          {:ok,
           %{
             escalations: [],
             updated_active_alerts: alert_manager[:alert_queue] || []
           }}
        else
          Logger.warning("#{length(escalated_alerts)} alerts escalated")

          # Deliver escalated alerts
          notification_channels = get_escalation_channels(alert_manager)

          case AlertManager.deliver_alerts(escalated_alerts, notification_channels) do
            {:ok, delivery_result} ->
              {:ok,
               %{
                 escalations: escalated_alerts,
                 delivery_result: delivery_result,
                 updated_active_alerts: alert_manager[:alert_queue] || []
               }}
          end
        end
    end
  end

  @doc """
  Generates comprehensive monitoring summary.
  """
  def generate_monitoring_summary(monitoring_setup, alert_manager, options \\ []) do
    time_window_hours = Keyword.get(options, :time_window_hours, 24)

    case AlertManager.generate_alert_summary(alert_manager, time_window_hours) do
      {:ok, alert_summary} ->
        monitoring_summary = %{
          monitoring_id: monitoring_setup.monitoring_id,
          monitoring_status: monitoring_setup.status,
          monitored_systems: length(monitoring_setup.monitored_systems),
          baseline_quality: monitoring_setup.baseline_reference.baseline_metrics.overall_quality,
          monitoring_uptime: calculate_monitoring_uptime(monitoring_setup),
          alert_summary: alert_summary,
          performance_metrics: extract_performance_metrics(monitoring_setup),
          summary_timestamp: DateTime.utc_now()
        }

        {:ok, monitoring_summary}
    end
  end

  @doc """
  Correlates alerts to reduce notification noise.
  """
  def correlate_monitoring_alerts(alerts, options \\ []) do
    correlation_window = Keyword.get(options, :correlation_window_minutes, 30)
    AlertManager.correlate_alerts(alerts, correlation_window)
  end

  @doc """
  Calculates anomaly confidence for detected anomalies.
  """
  def calculate_anomaly_confidence(anomaly, baseline, historical_data \\ []) do
    AnomalyDetector.calculate_anomaly_confidence(anomaly, baseline, historical_data)
  end

  @doc """
  Gets current monitoring metrics and status.
  """
  def get_monitoring_status(monitoring_setup, stream_state \\ nil) do
    base_status = %{
      monitoring_id: monitoring_setup.monitoring_id,
      status: monitoring_setup.status,
      monitored_systems: length(monitoring_setup.monitored_systems),
      setup_timestamp: monitoring_setup.setup_timestamp,
      baseline_quality: monitoring_setup.baseline_reference.baseline_metrics.overall_quality
    }

    if stream_state do
      stream_metrics = StreamManager.get_stream_metrics(stream_state)
      Map.merge(base_status, %{stream_metrics: stream_metrics})
    else
      base_status
    end
  end

  # Private helper functions

  defp validate_monitoring_config(
         monitored_systems,
         baseline,
         monitoring_interval,
         alert_thresholds,
         monitoring_focus
       ) do
    base_errors = []

    # Validate systems
    system_errors =
      if Enum.empty?(monitored_systems) do
        ["No systems specified for monitoring" | base_errors]
      else
        base_errors
      end

    # Validate baseline
    baseline_errors =
      if baseline.baseline_validation.validation_status == :invalid do
        ["Baseline validation failed" | system_errors]
      else
        system_errors
      end

    # Validate monitoring interval
    interval_errors =
      if monitoring_interval < 1 or monitoring_interval > 60 do
        ["Invalid monitoring interval (must be 1-60 minutes)" | baseline_errors]
      else
        baseline_errors
      end

    # Validate monitoring focus
    valid_focus_areas = [:activity, :patterns, :threats, :predictive]
    invalid_focus = monitoring_focus -- valid_focus_areas

    final_errors =
      if Enum.empty?(invalid_focus) do
        interval_errors
      else
        ["Invalid monitoring focus areas: #{Enum.join(invalid_focus, ", ")}" | interval_errors]
      end

    if Enum.empty?(final_errors) do
      {:ok,
       %{
         monitored_systems: monitored_systems,
         baseline: baseline,
         monitoring_interval_minutes: monitoring_interval,
         alert_thresholds: merge_default_alert_thresholds(alert_thresholds),
         monitoring_focus: monitoring_focus,
         validation_timestamp: DateTime.utc_now()
       }}
    else
      {:error, {:validation_failed, final_errors}}
    end
  end

  defp merge_default_alert_thresholds(custom_thresholds) do
    default_thresholds = %{
      activity_spike: 2.0,
      value_spike: 5.0,
      participant_spike: 3.0,
      threat_escalation: 1.5,
      pattern_anomaly: 0.8
    }

    Map.merge(default_thresholds, custom_thresholds)
  end

  defp initialize_monitoring_state(validated_config) do
    {:ok,
     %{
       status: :initialized,
       monitored_systems: validated_config.monitored_systems,
       monitoring_interval: validated_config.monitoring_interval_minutes,
       last_check_timestamp: nil,
       consecutive_checks: 0,
       error_count: 0,
       alert_cooldowns: %{},
       monitoring_statistics: %{
         total_checks_performed: 0,
         anomalies_detected: 0,
         alerts_generated: 0,
         false_positives: 0,
         monitoring_uptime_percentage: 100.0,
         average_check_duration_ms: 0,
         last_statistics_reset: DateTime.utc_now()
       },
       state_transitions: [
         %{from: nil, to: :initialized, timestamp: DateTime.utc_now()}
       ]
     }}
  end

  defp maybe_setup_predictive_monitoring(baseline, true) do
    if baseline.predictive_baseline do
      {:ok,
       %{
         enabled: true,
         prediction_horizon_hours: baseline.predictive_baseline.prediction_horizon_hours,
         prediction_confidence_threshold: 0.7,
         trend_monitoring: %{
           enabled: true,
           trend_data: baseline.predictive_baseline.trend_analysis,
           last_trend_update: DateTime.utc_now()
         },
         escalation_monitoring: %{
           enabled: true,
           escalation_indicators: baseline.predictive_baseline.escalation_indicators,
           escalation_watch_list: [],
           last_escalation_check: DateTime.utc_now()
         }
       }}
    else
      {:ok, nil}
    end
  end

  defp maybe_setup_predictive_monitoring(_baseline, false) do
    {:ok, nil}
  end

  defp get_current_thresholds(monitoring_setup) do
    baseline = monitoring_setup.baseline_reference

    %{
      activity_thresholds: baseline.activity_baseline.anomaly_thresholds,
      threat_thresholds: baseline.threat_baseline.alert_thresholds,
      adaptation_rate: 0.1,
      adaptation_factor: 1.0,
      last_adaptation: DateTime.utc_now()
    }
  end

  defp update_monitoring_setup_thresholds(monitoring_setup, updated_thresholds) do
    updated_baseline = %{
      monitoring_setup.baseline_reference
      | activity_baseline: %{
          monitoring_setup.baseline_reference.activity_baseline
          | anomaly_thresholds: updated_thresholds.activity_thresholds
        },
        threat_baseline: %{
          monitoring_setup.baseline_reference.threat_baseline
          | alert_thresholds: updated_thresholds.threat_thresholds
        }
    }

    %{monitoring_setup | baseline_reference: updated_baseline}
  end

  defp calculate_threshold_changes(old_thresholds, new_thresholds) do
    %{
      activity_threshold_changes:
        compare_activity_thresholds(
          old_thresholds.activity_thresholds,
          new_thresholds.activity_thresholds
        ),
      threat_threshold_changes:
        compare_threat_thresholds(
          old_thresholds.threat_thresholds,
          new_thresholds.threat_thresholds
        ),
      adaptation_factor: new_thresholds.adaptation_factor
    }
  end

  defp compare_activity_thresholds(old_thresholds, new_thresholds) do
    # Compare threshold changes across systems
    common_systems = Map.keys(old_thresholds) |> Enum.filter(&Map.has_key?(new_thresholds, &1))

    Enum.map(common_systems, fn system_id ->
      old_sys = old_thresholds[system_id]
      new_sys = new_thresholds[system_id]

      {system_id,
       %{
         killmail_threshold_change:
           calculate_threshold_change(
             old_sys.killmail_threshold.upper,
             new_sys.killmail_threshold.upper
           ),
         participant_threshold_change:
           calculate_threshold_change(
             old_sys.participant_threshold.upper,
             new_sys.participant_threshold.upper
           )
       }}
    end)
    |> Map.new()
  end

  defp compare_threat_thresholds(old_thresholds, new_thresholds) do
    # Compare threat threshold changes
    common_systems = Map.keys(old_thresholds) |> Enum.filter(&Map.has_key?(new_thresholds, &1))

    Enum.map(common_systems, fn system_id ->
      old_sys = old_thresholds[system_id]
      new_sys = new_thresholds[system_id]

      {system_id,
       %{
         high_value_alert_change:
           calculate_threshold_change(
             old_sys.high_value_alert,
             new_sys.high_value_alert
           ),
         frequency_alert_change:
           calculate_threshold_change(
             old_sys.frequency_alert,
             new_sys.frequency_alert
           )
       }}
    end)
    |> Map.new()
  end

  defp calculate_threshold_change(old_value, new_value) do
    if old_value == 0 do
      if new_value == 0, do: 0.0, else: 1.0
    else
      Float.round((new_value - old_value) / old_value, 3)
    end
  end

  defp get_escalation_channels(alert_manager) do
    # Extract notification channels from alert manager
    Map.get(alert_manager, :notification_channels, %{
      log: %{enabled: true, level: :info},
      monitoring_dashboard: %{enabled: true, level: :warning}
    })
  end

  defp calculate_monitoring_uptime(monitoring_setup) do
    # Calculate uptime since monitoring started
    start_time = monitoring_setup.setup_timestamp
    current_time = DateTime.utc_now()

    uptime_seconds = DateTimeUtils.diff(current_time, start_time, :second)

    # Convert to hours and round
    Float.round(uptime_seconds / 3600, 2)
  end

  defp extract_performance_metrics(monitoring_setup) do
    stats = monitoring_setup.monitoring_state.monitoring_statistics

    %{
      total_checks: stats.total_checks_performed,
      anomalies_detected: stats.anomalies_detected,
      alerts_generated: stats.alerts_generated,
      false_positive_rate:
        if(stats.alerts_generated > 0,
          do: stats.false_positives / stats.alerts_generated,
          else: 0.0
        ),
      uptime_percentage: stats.monitoring_uptime_percentage,
      average_check_duration_ms: stats.average_check_duration_ms
    }
  end

  defp generate_monitoring_id do
    # Generate a proper UUID-based monitoring ID
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    uuid = Ecto.UUID.generate()
    "MON-#{timestamp}-#{String.slice(uuid, 0..7)}"
  end
end
