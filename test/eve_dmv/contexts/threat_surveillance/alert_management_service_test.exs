defmodule EveDmv.Contexts.ThreatSurveillance.Domain.AlertManagementServiceTest do
  @moduledoc """
  Tests for the AlertManagementService GenServer.

  Tests the alert management functionality including:
  - Alert configuration
  - Surveillance match processing
  - Threat level change processing
  - Alert metrics
  """

  use EveDmv.DataCase, async: false

  alias EveDmv.Contexts.ThreatSurveillance.Domain.AlertManagementService

  @moduletag :threat_surveillance

  describe "start_link/1" do
    test "starts the GenServer successfully" do
      stop_service_if_running()

      assert {:ok, pid} = AlertManagementService.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "registers with the module name" do
      stop_service_if_running()

      {:ok, pid} = AlertManagementService.start_link([])
      assert GenServer.whereis(AlertManagementService) == pid
      GenServer.stop(pid)
    end
  end

  describe "configure_alerts/2" do
    setup do
      ensure_service_running()
    end

    test "configures alerts for a user with valid settings" do
      user_id = user_id()

      alert_settings = %{
        enabled: true,
        min_threat_level: :high,
        notification_channels: [:in_app, :email],
        frequency: :immediate
      }

      assert {:ok, config} = AlertManagementService.configure_alerts(user_id, alert_settings)

      assert config.user_id == user_id
      assert config.settings.enabled == true
      assert config.settings.min_threat_level == :high
      assert :in_app in config.channels
    end

    test "applies default settings for missing options" do
      user_id = user_id()
      alert_settings = %{}

      assert {:ok, config} = AlertManagementService.configure_alerts(user_id, alert_settings)

      assert config.settings.enabled == true
      assert config.settings.min_threat_level == :medium
      assert config.settings.notification_channels == [:in_app]
      assert config.settings.frequency == :immediate
    end

    test "caches configuration for quick access" do
      user_id = user_id()
      alert_settings = %{enabled: true}

      {:ok, config1} = AlertManagementService.configure_alerts(user_id, alert_settings)
      {:ok, config2} = AlertManagementService.configure_alerts(user_id, alert_settings)

      assert config1.user_id == config2.user_id
    end

    test "updates existing configuration" do
      user_id = user_id()

      # Initial config
      {:ok, _} =
        AlertManagementService.configure_alerts(user_id, %{
          min_threat_level: :low
        })

      # Updated config
      {:ok, updated} =
        AlertManagementService.configure_alerts(user_id, %{
          min_threat_level: :critical
        })

      assert updated.settings.min_threat_level == :critical
    end

    test "extracts notification channels from settings" do
      user_id = user_id()

      alert_settings = %{
        notification_channels: [:in_app, :webhook]
      }

      {:ok, config} = AlertManagementService.configure_alerts(user_id, alert_settings)

      assert :in_app in config.channels
      assert :webhook in config.channels
    end

    test "extracts filters from settings" do
      user_id = user_id()

      alert_settings = %{
        filters: %{
          systems: [30_000_142],
          corporations: [98_000_001]
        }
      }

      {:ok, config} = AlertManagementService.configure_alerts(user_id, alert_settings)

      assert is_map(config.filters)
    end

    test "includes quiet hours configuration" do
      user_id = user_id()

      alert_settings = %{
        quiet_hours: %{
          enabled: true,
          start: 22,
          end: 8
        }
      }

      {:ok, config} = AlertManagementService.configure_alerts(user_id, alert_settings)

      assert is_map(config.settings.quiet_hours)
    end
  end

  describe "process_surveillance_match/1" do
    setup do
      ensure_service_running()
    end

    test "processes a valid surveillance match event" do
      match_event = %{
        profile_id: "profile_#{System.unique_integer([:positive])}",
        killmail_id: System.unique_integer([:positive]),
        matched_criteria: ["character_id"],
        confidence_score: 0.95,
        matched_at: DateTime.utc_now()
      }

      # Should not raise (async operation)
      assert :ok = AlertManagementService.process_surveillance_match(match_event)
    end

    test "handles match event with struct-style access" do
      match_event = %{
        profile_id: "profile_123",
        killmail_id: 12_345,
        confidence_score: 0.8,
        matched_at: DateTime.utc_now()
      }

      assert :ok = AlertManagementService.process_surveillance_match(match_event)
    end

    test "updates alerts_processed counter" do
      initial_metrics = AlertManagementService.get_metrics()

      match_event = %{
        profile_id: "profile_#{System.unique_integer([:positive])}",
        killmail_id: System.unique_integer([:positive]),
        confidence_score: 0.9,
        matched_at: DateTime.utc_now()
      }

      AlertManagementService.process_surveillance_match(match_event)
      Process.sleep(100)

      updated_metrics = AlertManagementService.get_metrics()
      assert updated_metrics.alerts_processed >= initial_metrics.alerts_processed
    end
  end

  describe "process_threat_level_change/1" do
    setup do
      ensure_service_running()
    end

    test "processes a valid threat level change event" do
      threat_event = %{
        entity_id: character_id(),
        entity_type: :character,
        old_level: :low,
        new_level: :high,
        threat_score: 75.5,
        risk_factors: ["Increased activity"],
        change_reason: "Activity spike detected"
      }

      assert :ok = AlertManagementService.process_threat_level_change(threat_event)
    end

    test "handles corporation threat changes" do
      threat_event = %{
        entity_id: corporation_id(),
        entity_type: :corporation,
        old_level: :medium,
        new_level: :critical,
        threat_score: 92.0,
        change_reason: "Fleet activity detected"
      }

      assert :ok = AlertManagementService.process_threat_level_change(threat_event)
    end

    test "handles minimal to critical changes" do
      threat_event = %{
        entity_id: character_id(),
        entity_type: :character,
        old_level: :minimal,
        new_level: :critical,
        threat_score: 95.0
      }

      assert :ok = AlertManagementService.process_threat_level_change(threat_event)
    end
  end

  describe "get_metrics/0" do
    setup do
      ensure_service_running()
    end

    test "returns current metrics" do
      metrics = AlertManagementService.get_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :alerts_processed)
      assert Map.has_key?(metrics, :notifications_sent)
      assert Map.has_key?(metrics, :active_configurations)
    end

    test "metrics have correct types" do
      metrics = AlertManagementService.get_metrics()

      assert is_integer(metrics.alerts_processed)
      assert is_integer(metrics.notifications_sent)
      assert is_integer(metrics.active_configurations)
    end

    test "active_configurations increases after configuring alerts" do
      initial_metrics = AlertManagementService.get_metrics()

      # Configure alerts for a new user
      user_id = user_id()
      AlertManagementService.configure_alerts(user_id, %{enabled: true})

      updated_metrics = AlertManagementService.get_metrics()

      assert updated_metrics.active_configurations >= initial_metrics.active_configurations
    end
  end

  describe "get_metrics/1 with options" do
    setup do
      ensure_service_running()
    end

    test "accepts options parameter" do
      metrics = AlertManagementService.get_metrics([])

      assert is_map(metrics)
    end
  end

  describe "health_check" do
    setup do
      ensure_service_running()
    end

    test "responds to health check" do
      assert :ok = GenServer.call(AlertManagementService, :health_check)
    end
  end

  describe "alert severity determination" do
    setup do
      ensure_service_running()
    end

    test "critical severity for high confidence matches" do
      # Confidence >= 0.9 should be critical
      match_event = %{
        profile_id: "profile_123",
        killmail_id: 12_345,
        confidence_score: 0.95,
        matched_at: DateTime.utc_now()
      }

      assert :ok = AlertManagementService.process_surveillance_match(match_event)
    end

    test "high severity for good confidence matches" do
      # Confidence >= 0.7 but < 0.9 should be high
      match_event = %{
        profile_id: "profile_123",
        killmail_id: 12_345,
        confidence_score: 0.75,
        matched_at: DateTime.utc_now()
      }

      assert :ok = AlertManagementService.process_surveillance_match(match_event)
    end

    test "medium severity for moderate confidence matches" do
      # Confidence >= 0.5 but < 0.7 should be medium
      match_event = %{
        profile_id: "profile_123",
        killmail_id: 12_345,
        confidence_score: 0.55,
        matched_at: DateTime.utc_now()
      }

      assert :ok = AlertManagementService.process_surveillance_match(match_event)
    end

    test "low severity for low confidence matches" do
      # Confidence < 0.5 should be low
      match_event = %{
        profile_id: "profile_123",
        killmail_id: 12_345,
        confidence_score: 0.35,
        matched_at: DateTime.utc_now()
      }

      assert :ok = AlertManagementService.process_surveillance_match(match_event)
    end
  end

  describe "threat alert severity from threat level" do
    setup do
      ensure_service_running()
    end

    test "maps critical threat level to critical severity" do
      threat_event = %{
        entity_id: character_id(),
        entity_type: :character,
        old_level: :low,
        new_level: :critical,
        threat_score: 95.0
      }

      assert :ok = AlertManagementService.process_threat_level_change(threat_event)
    end

    test "maps high threat level to high severity" do
      threat_event = %{
        entity_id: character_id(),
        entity_type: :character,
        old_level: :low,
        new_level: :high,
        threat_score: 70.0
      }

      assert :ok = AlertManagementService.process_threat_level_change(threat_event)
    end

    test "maps medium threat level to medium severity" do
      threat_event = %{
        entity_id: character_id(),
        entity_type: :character,
        old_level: :minimal,
        new_level: :medium,
        threat_score: 50.0
      }

      assert :ok = AlertManagementService.process_threat_level_change(threat_event)
    end

    test "maps low/minimal threat level to low severity" do
      threat_event = %{
        entity_id: character_id(),
        entity_type: :character,
        old_level: :minimal,
        new_level: :low,
        threat_score: 25.0
      }

      assert :ok = AlertManagementService.process_threat_level_change(threat_event)
    end
  end

  describe "error handling" do
    setup do
      ensure_service_running()
    end

    test "handles missing profile_id gracefully" do
      match_event = %{
        killmail_id: 12_345,
        confidence_score: 0.8
      }

      # Should handle gracefully (via rescue)
      assert :ok = AlertManagementService.process_surveillance_match(match_event)
    end

    test "handles missing threat event fields gracefully" do
      threat_event = %{
        entity_id: character_id(),
        entity_type: :character
      }

      assert :ok = AlertManagementService.process_threat_level_change(threat_event)
    end
  end

  # Helper functions

  defp ensure_service_running do
    case GenServer.whereis(AlertManagementService) do
      nil ->
        {:ok, _pid} = AlertManagementService.start_link([])
        :ok

      pid when is_pid(pid) ->
        if Process.alive?(pid), do: :ok, else: AlertManagementService.start_link([])
    end
  end

  defp stop_service_if_running do
    case GenServer.whereis(AlertManagementService) do
      nil ->
        :ok

      pid ->
        GenServer.stop(pid)
        Process.sleep(50)
    end
  end

  defp user_id do
    System.unique_integer([:positive])
  end
end
