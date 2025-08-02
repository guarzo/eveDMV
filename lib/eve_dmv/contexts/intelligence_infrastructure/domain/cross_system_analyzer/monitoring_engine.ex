defmodule EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystemAnalyzer.MonitoringEngine do
  @moduledoc """
  Real-time monitoring engine for cross-system intelligence operations.

  This module has been refactored to use a modular monitoring system.
  All functionality is now delegated to specialized modules:
  - BaselineManager: Baseline establishment and validation
  - StreamManager: Real-time streaming and processing
  - AnomalyDetector: Anomaly detection and classification
  - AlertManager: Alert generation and delivery

  The Facade module coordinates these components while maintaining
  backward compatibility with the original MonitoringEngine interface.
  """
  """

  # Delegate all functions to the new modular monitoring facade
  defdelegate establish_intelligence_baseline(monitored_systems, options \\ []),
    to: EveDmv.Shared.Monitoring.Facade

  defdelegate setup_intelligence_monitoring(monitored_systems, baseline, options \\ []),
    to: EveDmv.Shared.Monitoring.Facade

  defdelegate start_intelligence_stream(monitoring_setup, stream_options \\ []),
    to: EveDmv.Shared.Monitoring.Facade

  defdelegate detect_anomalies(current_data, baseline, options \\ []),
    to: EveDmv.Shared.Monitoring.Facade

  defdelegate process_anomaly_alerts(anomalies, baseline, alert_manager, options \\ []),
    to: EveDmv.Shared.Monitoring.Facade

  defdelegate update_monitoring_thresholds(monitoring_setup, recent_detections, options \\ []),
    to: EveDmv.Shared.Monitoring.Facade

  defdelegate handle_alert_escalation(alert_manager, options \\ []),
    to: EveDmv.Shared.Monitoring.Facade

  defdelegate generate_monitoring_summary(monitoring_setup, alert_manager, options \\ []),
    to: EveDmv.Shared.Monitoring.Facade

  defdelegate correlate_monitoring_alerts(alerts, options \\ []),
    to: EveDmv.Shared.Monitoring.Facade

  defdelegate calculate_anomaly_confidence(anomaly, baseline, historical_data \\ []),
    to: EveDmv.Shared.Monitoring.Facade

  defdelegate get_monitoring_status(monitoring_setup, stream_state \\ nil),
    to: EveDmv.Shared.Monitoring.Facade
end
