defmodule EveDmv.Shared.Monitoring.AlertManager do
  @moduledoc """

  Alert management system for monitoring anomalies and generating notifications.

  Provides functionality for:
  - Alert generation based on anomalies
  - Alert queue processing and prioritization
  - Alert escalation and delivery
  - Alert correlation and summarization
  """

  alias EveDmv.Core.Utils.DateTimeUtils
  require Logger

  @doc """
  Sets up the alert system with configuration.
  """
  def setup_alert_system(alert_thresholds) do
    Logger.debug("Setting up alert system with thresholds: #{inspect(alert_thresholds)}")
    {:ok, %{thresholds: alert_thresholds, alert_queue: []}}
  end

  @doc """
  Generates alerts from anomalies and baseline data.
  """
  def generate_alerts(anomalies, baseline, options \\ []) do
    severity_threshold = Keyword.get(options, :severity_threshold, 0.7)

    alerts =
      anomalies
      |> Enum.filter(fn anomaly ->
        Map.get(anomaly, :severity, 0) >= severity_threshold
      end)
      |> Enum.map(&create_alert_from_anomaly(&1, baseline))

    {:ok, %{alerts: alerts, alert_count: length(alerts)}}
  end

  @doc """
  Processes the alert queue with the alert manager.
  """
  def process_alert_queue(alert_manager, alerts) do
    processed_alerts =
      alerts
      |> Enum.map(&process_single_alert(&1, alert_manager))
      |> Enum.filter(&(&1 != nil))

    {:ok, %{processed: processed_alerts, count: length(processed_alerts)}}
  end

  @doc """
  Handles alert escalation based on time and severity.
  """
  def handle_alert_escalation(alert_manager, current_time) do
    # 1 hour
    escalation_window = 3600

    escalated_alerts =
      alert_manager[:alert_queue]
      |> Enum.filter(fn alert ->
        time_diff = DateTimeUtils.diff(current_time, alert[:created_at], :second)
        time_diff > escalation_window and alert[:severity] > 0.8
      end)

    {:ok, escalated_alerts}
  end

  @doc """
  Delivers alerts through notification channels.
  """
  def deliver_alerts(alerts, notification_channels) do
    delivery_results =
      Enum.map(alerts, fn alert ->
        Enum.map(notification_channels, fn channel ->
          deliver_to_channel(alert, channel)
        end)
      end)
      |> List.flatten()

    successful_deliveries = Enum.count(delivery_results, &(&1 == :ok))

    {:ok,
     %{
       total_attempts: length(delivery_results),
       successful: successful_deliveries,
       failed: length(delivery_results) - successful_deliveries
     }}
  end

  @doc """
  Generates a summary of alerts for a time window.
  """
  def generate_alert_summary(alert_manager, time_window_hours) do
    cutoff_time = DateTimeUtils.add(DateTime.utc_now(), -time_window_hours * 3600, :second)

    recent_alerts =
      alert_manager[:alert_queue]
      |> Enum.filter(fn alert ->
        DateTime.compare(alert[:created_at], cutoff_time) == :gt
      end)

    summary = %{
      time_window_hours: time_window_hours,
      # Named :alert_count to follow AlertBatcher counter naming convention ("_count" suffix)
      alert_count: length(recent_alerts),
      by_severity: group_alerts_by_severity(recent_alerts),
      by_type: group_alerts_by_type(recent_alerts),
      critical_count: count_critical_alerts(recent_alerts)
    }

    {:ok, summary}
  end

  @doc """
  Correlates alerts to identify patterns and relationships.
  """
  def correlate_alerts(alerts, correlation_window) do
    correlation_window_seconds = correlation_window * 60

    correlated_groups =
      alerts
      |> Enum.sort_by(& &1[:created_at], DateTime)
      |> group_by_time_window(correlation_window_seconds)
      |> Enum.filter(fn group -> length(group) > 1 end)
      |> Enum.map(&analyze_correlation_group/1)

    %{
      correlation_groups: correlated_groups,
      group_count: length(correlated_groups),
      isolated_alerts: count_isolated_alerts(alerts, correlated_groups)
    }
  end

  # Private helper functions

  defp create_alert_from_anomaly(anomaly, baseline) do
    %{
      id: generate_alert_id(),
      type: determine_alert_type(anomaly),
      severity: Map.get(anomaly, :severity, 0.5),
      message: create_alert_message(anomaly, baseline),
      created_at: DateTime.utc_now(),
      source: anomaly[:source] || "unknown",
      metadata: %{
        anomaly_data: anomaly,
        baseline_reference: baseline[:id]
      }
    }
  end

  defp process_single_alert(alert, alert_manager) do
    thresholds = alert_manager[:thresholds] || %{}

    # Check if alert meets processing thresholds
    if alert[:severity] >= Map.get(thresholds, :min_severity, 0.5) do
      %{alert | status: :processed, processed_at: DateTime.utc_now()}
    else
      nil
    end
  end

  defp deliver_to_channel(alert, channel) do
    case channel[:type] do
      :email ->
        # Would integrate with email service
        Logger.info("Alert delivered via email: #{alert[:message]}")
        :ok

      :webhook ->
        # Would make HTTP request to webhook
        Logger.info("Alert delivered via webhook: #{alert[:message]}")
        :ok

      :slack ->
        # Would integrate with Slack API
        Logger.info("Alert delivered via Slack: #{alert[:message]}")
        :ok

      _ ->
        Logger.warning("Unknown notification channel: #{channel[:type]}")
        :error
    end
  end

  defp group_alerts_by_severity(alerts) do
    alerts
    |> Enum.group_by(fn alert ->
      severity = alert[:severity] || 0

      cond do
        severity >= 0.9 -> :critical
        severity >= 0.7 -> :high
        severity >= 0.5 -> :medium
        severity >= 0.3 -> :low
        true -> :info
      end
    end)
    |> Enum.map(fn {severity, group} -> {severity, length(group)} end)
    |> Map.new()
  end

  defp group_alerts_by_type(alerts) do
    alerts
    |> Enum.group_by(& &1[:type])
    |> Enum.map(fn {type, group} -> {type, length(group)} end)
    |> Map.new()
  end

  defp count_critical_alerts(alerts) do
    Enum.count(alerts, fn alert ->
      (alert[:severity] || 0) >= 0.9
    end)
  end

  defp group_by_time_window(alerts, window_seconds) do
    alerts
    |> Enum.group_by(fn alert ->
      timestamp_seconds = DateTime.to_unix(alert[:created_at])
      div(timestamp_seconds, window_seconds)
    end)
    |> Map.values()
  end

  defp analyze_correlation_group(alert_group) do
    %{
      alerts: alert_group,
      correlation_score: calculate_correlation_score(alert_group),
      common_attributes: find_common_attributes(alert_group),
      time_span: calculate_time_span(alert_group)
    }
  end

  defp count_isolated_alerts(all_alerts, correlated_groups) do
    correlated_alert_ids =
      correlated_groups
      |> Enum.flat_map(& &1[:alerts])
      |> Enum.map(& &1[:id])
      |> MapSet.new()

    all_alerts
    |> Enum.count(fn alert ->
      not MapSet.member?(correlated_alert_ids, alert[:id])
    end)
  end

  defp generate_alert_id do
    # Generate a proper UUID-based alert ID
    uuid = Ecto.UUID.generate()
    "alert_#{System.system_time(:second)}_#{String.slice(uuid, 0..7)}"
  end

  defp determine_alert_type(anomaly) do
    case anomaly[:type] do
      :spike -> :performance_spike
      :drop -> :performance_drop
      :pattern_change -> :behavior_change
      _ -> :general_anomaly
    end
  end

  defp create_alert_message(anomaly, baseline) do
    "Anomaly detected: #{anomaly[:description] || "Unknown anomaly"} " <>
      "(Severity: #{Float.round(anomaly[:severity] || 0, 2)}, " <>
      "Baseline: #{baseline[:name] || "Default"})"
  end

  defp calculate_correlation_score(alert_group) do
    # Simplified correlation scoring
    if length(alert_group) > 1 do
      # Higher score for more alerts in tight time window
      time_span = calculate_time_span(alert_group)
      base_score = min(length(alert_group) / 5.0, 1.0)
      # Decay over 5 minutes
      time_factor = max(0, 1.0 - time_span / 300.0)

      Float.round((base_score + time_factor) / 2, 3)
    else
      0.0
    end
  end

  defp find_common_attributes(alert_group) do
    if length(alert_group) < 2 do
      %{}
    else
      # Find attributes that are common across all alerts
      first_alert = List.first(alert_group)

      [:type, :source, :severity]
      |> Enum.filter(fn attr ->
        value = first_alert[attr]
        Enum.all?(alert_group, &(&1[attr] == value))
      end)
      |> Enum.map(fn attr -> {attr, first_alert[attr]} end)
      |> Map.new()
    end
  end

  defp calculate_time_span(alert_group) do
    if length(alert_group) < 2 do
      0
    else
      timestamps = Enum.map(alert_group, & &1[:created_at])
      earliest = Enum.min(timestamps, DateTime)
      latest = Enum.max(timestamps, DateTime)

      DateTimeUtils.diff(latest, earliest, :second)
    end
  end
end
