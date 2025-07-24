defmodule EveDmv.Intelligence.AlertSystem do
  @moduledoc """
  Real-time intelligence alert system.

  Monitors intelligence data for significant events and threats,
  generating real-time alerts for security personnel and administrators.
  """

  use GenServer

  require Logger

  # Alert configuration
  @critical_threat_threshold 8
  @high_risk_vetting_threshold 80
  # @eviction_group_threshold 0.8
  # @alt_correlation_threshold 0.9
  # @new_member_monitoring_days 30

  ## Public API

  @doc """
  Start the alert system.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Process a new character analysis for alerts.
  """
  def process_character_analysis(character_analysis) do
    GenServer.cast(__MODULE__, {:character_analysis, character_analysis})
  end

  @doc """
  Process a new vetting analysis for alerts.
  """
  def process_vetting_analysis(vetting_analysis) do
    GenServer.cast(__MODULE__, {:vetting_analysis, vetting_analysis})
  end

  @doc """
  Process a new killmail for threat monitoring.
  """
  def process_killmail(killmail) do
    GenServer.cast(__MODULE__, {:new_killmail, killmail})
  end

  @doc """
  Get active alerts.
  """
  def get_active_alerts do
    GenServer.call(__MODULE__, :get_active_alerts)
  end

  @doc """
  Acknowledge an alert.
  """
  def acknowledge_alert(alert_id, acknowledged_by) do
    GenServer.cast(__MODULE__, {:acknowledge_alert, alert_id, acknowledged_by})
  end

  ## GenServer Implementation

  def init(_opts) do
    # Schedule periodic monitoring
    :timer.send_interval(:timer.minutes(5), :periodic_monitoring)

    state = %{
      active_alerts: %{},
      alert_history: [],
      monitored_characters: MapSet.new(),
      threat_watchlist: MapSet.new()
    }

    Logger.info("Intelligence alert system started")
    {:ok, state}
  end

  def handle_call(:get_active_alerts, _from, state) do
    alerts =
      state.active_alerts
      |> Map.values()
      |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})

    {:reply, alerts, state}
  end

  def handle_cast({:character_analysis, analysis}, state) do
    alerts = check_character_analysis_alerts(analysis)
    new_state = process_new_alerts(alerts, state)
    {:noreply, new_state}
  end

  def handle_cast({:vetting_analysis, vetting}, state) do
    alerts = check_vetting_analysis_alerts(vetting)
    new_state = process_new_alerts(alerts, state)
    {:noreply, new_state}
  end

  def handle_cast({:new_killmail, killmail}, state) do
    alerts = check_killmail_alerts(killmail)
    new_state = process_new_alerts(alerts, state)
    {:noreply, new_state}
  end

  def handle_cast({:acknowledge_alert, alert_id, acknowledged_by}, state) do
    case Map.get(state.active_alerts, alert_id) do
      nil ->
        {:noreply, state}

      alert ->
        updated_alert = %{
          alert
          | status: :acknowledged,
            acknowledged_by: acknowledged_by,
            acknowledged_at: DateTime.utc_now()
        }

        new_active_alerts = Map.delete(state.active_alerts, alert_id)
        new_history = Enum.take([updated_alert | state.alert_history], 100)

        new_state = %{state | active_alerts: new_active_alerts, alert_history: new_history}

        Logger.info("Alert #{alert_id} acknowledged by #{acknowledged_by}")
        {:noreply, new_state}
    end
  end

  def handle_info(:periodic_monitoring, state) do
    # Perform periodic threat monitoring
    spawn(fn -> perform_periodic_monitoring() end)
    {:noreply, state}
  end

  ## Alert Generation Logic

  defp check_character_analysis_alerts(analysis) do
    character_id = analysis.character_id

    # Critical threat rating alert
    base_alerts =
      if analysis.dangerous_rating >= @critical_threat_threshold do
        [
          create_threat_alert(character_id, analysis.dangerous_rating, "critical_threat_rating")
        ]
      else
        []
      end

    # High awox probability alert
    awox_alerts =
      if analysis.awox_probability > 0.7 do
        [
          create_threat_alert(character_id, analysis.awox_probability, "high_awox_probability")
          | base_alerts
        ]
      else
        base_alerts
      end

    # Suspicious activity patterns
    final_alerts =
      if analysis.activity_patterns && length(analysis.activity_patterns.red_flags || []) > 3 do
        [
          create_behavioral_alert(
            character_id,
            analysis.activity_patterns.red_flags,
            "multiple_red_flags"
          )
          | awox_alerts
        ]
      else
        awox_alerts
      end

    final_alerts
  end

  defp check_vetting_analysis_alerts(vetting) do
    character_id = vetting.character_id

    # High risk vetting score
    base_alerts =
      if vetting.overall_risk_score >= @high_risk_vetting_threshold do
        [
          create_vetting_alert(character_id, vetting.overall_risk_score, "high_risk_vetting")
        ]
      else
        []
      end

    # Eviction group associations
    eviction_alerts =
      if vetting.eviction_associations &&
           length(vetting.eviction_associations["known_eviction_groups"] || []) > 0 do
        [
          create_security_alert(
            character_id,
            vetting.eviction_associations,
            "eviction_group_association"
          )
          | base_alerts
        ]
      else
        base_alerts
      end

    # Character bazaar indicators
    bazaar_alerts =
      if vetting.alt_analysis &&
           vetting.alt_analysis["character_bazaar_indicators"]["likely_purchased"] do
        [
          create_security_alert(character_id, vetting.alt_analysis, "character_bazaar_purchase")
          | eviction_alerts
        ]
      else
        eviction_alerts
      end

    # Seed/scout indicators
    final_alerts =
      if vetting.eviction_associations &&
           vetting.eviction_associations["seed_scout_indicators"]["information_gathering"] do
        [
          create_security_alert(
            character_id,
            vetting.eviction_associations,
            "seed_scout_behavior"
          )
          | bazaar_alerts
        ]
      else
        bazaar_alerts
      end

    final_alerts
  end

  defp check_killmail_alerts(killmail) do
    # Check for blue killing (friendly fire)
    base_alerts =
      if blue_kill?(killmail) do
        [create_incident_alert(killmail, "blue_kill")]
      else
        []
      end

    # Check for capital ship losses in home systems
    capital_alerts =
      if capital_loss_in_home?(killmail) do
        [create_incident_alert(killmail, "capital_loss_home") | base_alerts]
      else
        base_alerts
      end

    # Check for structure losses
    final_alerts =
      if structure_loss?(killmail) do
        [create_incident_alert(killmail, "structure_loss") | capital_alerts]
      else
        capital_alerts
      end

    final_alerts
  end

  defp perform_periodic_monitoring do
    Logger.info("Performing periodic threat monitoring")

    # Monitor for new high-threat characters
    monitor_new_threats()

    # Monitor for correlation patterns
    monitor_correlation_patterns()

    # Monitor for activity anomalies
    monitor_activity_anomalies()
  end

  defp monitor_new_threats do
    # Query recent character analyses with high threat ratings
    cutoff_date = DateTime.add(DateTime.utc_now(), -24, :hour)

    try do
      # This would query the character stats for recent high-threat individuals
      # Placeholder implementation
      Logger.debug("Monitoring for new threats since #{cutoff_date}")
    rescue
      error ->
        Logger.error("Failed to monitor new threats: #{inspect(error)}")
    end
  end

  defp monitor_correlation_patterns do
    # Look for suspicious correlation patterns
    # This would analyze recent correlation data for anomalies
    Logger.debug("Monitoring correlation patterns")
  rescue
    error ->
      Logger.error("Failed to monitor correlation patterns: #{inspect(error)}")
  end

  defp monitor_activity_anomalies do
    # Monitor for unusual activity patterns
    # This would analyze recent activity for anomalies
    Logger.debug("Monitoring activity anomalies")
  rescue
    error ->
      Logger.error("Failed to monitor activity anomalies: #{inspect(error)}")
  end

  ## Alert Creation Functions

  defp create_threat_alert(character_id, threat_value, alert_type) do
    %{
      id: generate_alert_id(),
      type: :threat,
      subtype: alert_type,
      severity: get_threat_severity(threat_value),
      character_id: character_id,
      title: format_threat_title(alert_type, threat_value),
      message: format_threat_message(alert_type, character_id, threat_value),
      data: %{threat_value: threat_value},
      timestamp: DateTime.utc_now(),
      status: :active,
      acknowledged_by: nil,
      acknowledged_at: nil
    }
  end

  defp create_vetting_alert(character_id, risk_score, alert_type) do
    %{
      id: generate_alert_id(),
      type: :vetting,
      subtype: alert_type,
      severity: get_vetting_severity(risk_score),
      character_id: character_id,
      title: format_vetting_title(alert_type, risk_score),
      message: format_vetting_message(alert_type, character_id, risk_score),
      data: %{risk_score: risk_score},
      timestamp: DateTime.utc_now(),
      status: :active,
      acknowledged_by: nil,
      acknowledged_at: nil
    }
  end

  defp create_security_alert(character_id, data, alert_type) do
    %{
      id: generate_alert_id(),
      type: :security,
      subtype: alert_type,
      severity: :high,
      character_id: character_id,
      title: format_security_title(alert_type),
      message: format_security_message(alert_type, character_id),
      data: data,
      timestamp: DateTime.utc_now(),
      status: :active,
      acknowledged_by: nil,
      acknowledged_at: nil
    }
  end

  defp create_behavioral_alert(character_id, red_flags, alert_type) do
    %{
      id: generate_alert_id(),
      type: :behavioral,
      subtype: alert_type,
      severity: :medium,
      character_id: character_id,
      title: format_behavioral_title(alert_type),
      message: format_behavioral_message(alert_type, character_id, red_flags),
      data: %{red_flags: red_flags},
      timestamp: DateTime.utc_now(),
      status: :active,
      acknowledged_by: nil,
      acknowledged_at: nil
    }
  end

  defp create_incident_alert(killmail, alert_type) do
    %{
      id: generate_alert_id(),
      type: :incident,
      subtype: alert_type,
      severity: get_incident_severity(alert_type),
      character_id: killmail.victim_character_id,
      killmail_id: killmail.killmail_id,
      title: format_incident_title(alert_type),
      message: format_incident_message(alert_type, killmail),
      data: %{killmail: killmail},
      timestamp: DateTime.utc_now(),
      status: :active,
      acknowledged_by: nil,
      acknowledged_at: nil
    }
  end

  ## Helper Functions

  defp process_new_alerts(alerts, state) do
    new_state =
      Enum.reduce(alerts, state, fn alert, acc_state ->
        # Add to active alerts
        new_active_alerts = Map.put(acc_state.active_alerts, alert.id, alert)

        # Broadcast alert
        broadcast_alert(alert)

        # Log alert
        Logger.warning("Intelligence alert: #{alert.title} - #{alert.message}")

        %{acc_state | active_alerts: new_active_alerts}
      end)

    new_state
  end

  defp broadcast_alert(alert) do
    # Broadcast to dashboard
    Phoenix.PubSub.broadcast(
      EveDmv.PubSub,
      "intelligence:alerts",
      {:threat_alert, alert}
    )

    # Broadcast to character-specific channel if applicable
    if alert.character_id do
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "character:#{alert.character_id}",
        {:character_alert, alert}
      )
    end
  end

  defp generate_alert_id do
    "alert_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end

  defp get_threat_severity(threat_value) when is_number(threat_value) do
    cond do
      threat_value >= 9 -> :critical
      threat_value >= 7 -> :high
      threat_value >= 5 -> :medium
      true -> :low
    end
  end

  defp get_threat_severity(_), do: :medium

  defp get_vetting_severity(risk_score) when is_number(risk_score) do
    cond do
      risk_score >= 90 -> :critical
      risk_score >= 80 -> :high
      risk_score >= 60 -> :medium
      true -> :low
    end
  end

  defp get_vetting_severity(_), do: :medium

  defp get_incident_severity(alert_type) do
    case alert_type do
      "capital_loss_home" -> :critical
      "structure_loss" -> :high
      "blue_kill" -> :medium
      _ -> :low
    end
  end

  defp format_threat_title("critical_threat_rating", threat_value) do
    "Critical Threat Rating: #{threat_value}/10"
  end

  defp format_threat_title("high_awox_probability", prob) do
    "High Awox Probability: #{round(prob * 100)}%"
  end

  defp format_threat_title(type, _), do: "Threat Alert: #{type}"

  defp format_threat_message("critical_threat_rating", character_id, threat_value) do
    "Character #{character_id} has a critical threat rating of #{threat_value}/10. Immediate review recommended."
  end

  defp format_threat_message("high_awox_probability", character_id, prob) do
    "Character #{character_id} has a #{round(prob * 100)}% probability of awoxing. Exercise extreme caution."
  end

  defp format_threat_message(type, character_id, value) do
    "Character #{character_id} triggered threat alert: #{type} (#{value})"
  end

  defp format_vetting_title("high_risk_vetting", risk_score) do
    "High Risk Vetting Score: #{risk_score}/100"
  end

  defp format_vetting_title(type, _), do: "Vetting Alert: #{type}"

  defp format_vetting_message("high_risk_vetting", character_id, risk_score) do
    "Character #{character_id} has a high vetting risk score of #{risk_score}/100. Review vetting analysis."
  end

  defp format_vetting_message(type, character_id, value) do
    "Character #{character_id} triggered vetting alert: #{type} (#{value})"
  end

  defp format_security_title("eviction_group_association") do
    "Eviction Group Association Detected"
  end

  defp format_security_title("character_bazaar_purchase") do
    "Character Bazaar Purchase Detected"
  end

  defp format_security_title("seed_scout_behavior") do
    "Seed/Scout Behavior Detected"
  end

  defp format_security_title(type), do: "Security Alert: #{type}"

  defp format_security_message("eviction_group_association", character_id) do
    "Character #{character_id} has confirmed associations with known eviction groups."
  end

  defp format_security_message("character_bazaar_purchase", character_id) do
    "Character #{character_id} shows strong indicators of being purchased on the character bazaar."
  end

  defp format_security_message("seed_scout_behavior", character_id) do
    "Character #{character_id} exhibits patterns consistent with seed/scout behavior."
  end

  defp format_security_message(type, character_id) do
    "Character #{character_id} triggered security alert: #{type}"
  end

  defp format_behavioral_title("multiple_red_flags") do
    "Multiple Behavioral Red Flags"
  end

  defp format_behavioral_title(type), do: "Behavioral Alert: #{type}"

  defp format_behavioral_message("multiple_red_flags", character_id, red_flags) do
    "Character #{character_id} has #{length(red_flags)} behavioral red flags: #{Enum.join(red_flags, ", ")}"
  end

  defp format_behavioral_message(type, character_id, _data) do
    "Character #{character_id} triggered behavioral alert: #{type}"
  end

  defp format_incident_title("blue_kill") do
    "Friendly Fire Incident"
  end

  defp format_incident_title("capital_loss_home") do
    "Capital Ship Loss in Home System"
  end

  defp format_incident_title("structure_loss") do
    "Structure Loss"
  end

  defp format_incident_title(type), do: "Incident Alert: #{type}"

  defp format_incident_message("blue_kill", killmail) do
    "Friendly fire incident detected involving #{killmail.victim_character_name || killmail.victim_character_id}"
  end

  defp format_incident_message("capital_loss_home", killmail) do
    "Capital ship loss in home system: #{killmail.ship_name || killmail.ship_type_id}"
  end

  defp format_incident_message("structure_loss", killmail) do
    "Structure destroyed: #{killmail.ship_name || killmail.ship_type_id} in #{killmail.solar_system_name || killmail.solar_system_id}"
  end

  defp format_incident_message(type, _killmail) do
    "Incident alert: #{type}"
  end

  # Killmail analysis functions

  defp blue_kill?(_killmail) do
    # Simplified logic - would need more sophisticated alliance/blue list checking
    false
  end

  defp capital_loss_in_home?(_killmail) do
    # Check if capital ship was lost in a home system
    # Simplified implementation
    false
  end

  defp structure_loss?(killmail) do
    # Check if killmail involves a structure
    ship_name = killmail.ship_name || ""
    String.contains?(ship_name, ["Citadel", "Engineering", "Refinery", "Station"])
  end
end
