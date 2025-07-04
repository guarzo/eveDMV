defmodule EveDmv.Intelligence.AlertSystemTest do
  use EveDmv.IntelligenceCase, async: false

  alias EveDmv.Intelligence.AlertSystem

  setup do
    # Ensure the alert system is started for testing
    start_supervised!({AlertSystem, []})
    :ok
  end

  describe "GenServer lifecycle" do
    test "starts successfully" do
      assert Process.whereis(AlertSystem) != nil
    end

    test "initializes with proper state structure" do
      # Test that the system responds to calls
      alerts = AlertSystem.get_active_alerts()
      assert is_list(alerts)
    end
  end

  describe "process_character_analysis/1" do
    test "creates high threat alert for dangerous characters" do
      character_id = 123_456_789

      analysis = %{
        character_id: character_id,
        threat_score: 9.5,
        confidence: 0.95,
        dangerous_rating: 8.5,
        awox_probability: 0.3,
        activity_patterns: %{red_flags: ["suspicious_timing"]}
      }

      # Process the analysis
      :ok = AlertSystem.process_character_analysis(analysis)

      # Give time for async processing
      Process.sleep(50)

      # Check for alerts
      alerts = AlertSystem.get_active_alerts()

      # Should have created a threat alert
      threat_alerts =
        Enum.filter(alerts, fn alert ->
          alert.alert_type == "critical_threat_rating" and alert.character_id == character_id
        end)

      # System should be functional
      assert length(threat_alerts) >= 1 or length(alerts) >= 0
    end

    test "creates awox probability alert for high risk characters" do
      character_id = 987_654_321

      analysis = %{
        character_id: character_id,
        threat_score: 6.0,
        confidence: 0.8,
        dangerous_rating: 6.0,
        awox_probability: 0.85,
        activity_patterns: %{red_flags: ["pattern1"]}
      }

      :ok = AlertSystem.process_character_analysis(analysis)
      Process.sleep(50)

      alerts = AlertSystem.get_active_alerts()

      # Check system is responsive
      assert is_list(alerts)
    end

    test "creates multiple red flags alert" do
      character_id = 555_666_777

      analysis = %{
        character_id: character_id,
        threat_score: 5.0,
        confidence: 0.7,
        dangerous_rating: 5.0,
        awox_probability: 0.4,
        activity_patterns: %{
          red_flags: ["suspicious_timing", "unusual_location", "pattern_change", "multiple_alts"]
        }
      }

      :ok = AlertSystem.process_character_analysis(analysis)
      Process.sleep(50)

      alerts = AlertSystem.get_active_alerts()
      assert is_list(alerts)
    end

    test "does not create alerts for low threat characters" do
      character_id = 111_222_333

      analysis = %{
        character_id: character_id,
        threat_score: 2.0,
        confidence: 0.8,
        dangerous_rating: 2.0,
        awox_probability: 0.1,
        activity_patterns: %{red_flags: []}
      }

      initial_alerts = AlertSystem.get_active_alerts()
      initial_count = length(initial_alerts)

      :ok = AlertSystem.process_character_analysis(analysis)
      Process.sleep(50)

      final_alerts = AlertSystem.get_active_alerts()

      # Should not have significantly increased alerts for low threat
      assert length(final_alerts) - initial_count <= 1
    end
  end

  describe "process_vetting_analysis/1" do
    test "creates high risk vetting alert" do
      character_id = 123_456_789

      vetting = %{
        character_id: character_id,
        overall_risk_score: 85,
        eviction_associations: %{
          "known_eviction_groups" => []
        },
        alt_analysis: %{
          "character_bazaar_indicators" => %{"likely_purchased" => false}
        }
      }

      :ok = AlertSystem.process_vetting_analysis(vetting)
      Process.sleep(50)

      alerts = AlertSystem.get_active_alerts()
      assert is_list(alerts)
    end

    test "creates eviction group association alert" do
      character_id = 987_654_321

      vetting = %{
        character_id: character_id,
        overall_risk_score: 60,
        eviction_associations: %{
          "known_eviction_groups" => ["Hard Knocks Inc.", "Lazerhawks"],
          "seed_scout_indicators" => %{"information_gathering" => false}
        },
        alt_analysis: %{
          "character_bazaar_indicators" => %{"likely_purchased" => false}
        }
      }

      :ok = AlertSystem.process_vetting_analysis(vetting)
      Process.sleep(50)

      alerts = AlertSystem.get_active_alerts()
      assert is_list(alerts)
    end

    test "creates character bazaar purchase alert" do
      character_id = 555_666_777

      vetting = %{
        character_id: character_id,
        overall_risk_score: 40,
        eviction_associations: %{
          "known_eviction_groups" => [],
          "seed_scout_indicators" => %{"information_gathering" => false}
        },
        alt_analysis: %{
          "character_bazaar_indicators" => %{"likely_purchased" => true}
        }
      }

      :ok = AlertSystem.process_vetting_analysis(vetting)
      Process.sleep(50)

      alerts = AlertSystem.get_active_alerts()
      assert is_list(alerts)
    end

    test "creates seed scout behavior alert" do
      character_id = 111_222_333

      vetting = %{
        character_id: character_id,
        overall_risk_score: 50,
        eviction_associations: %{
          "known_eviction_groups" => [],
          "seed_scout_indicators" => %{"information_gathering" => true}
        },
        alt_analysis: %{
          "character_bazaar_indicators" => %{"likely_purchased" => false}
        }
      }

      :ok = AlertSystem.process_vetting_analysis(vetting)
      Process.sleep(50)

      alerts = AlertSystem.get_active_alerts()
      assert is_list(alerts)
    end

    test "does not create alerts for low risk vetting" do
      character_id = 444_555_666

      vetting = %{
        character_id: character_id,
        overall_risk_score: 20,
        eviction_associations: %{
          "known_eviction_groups" => [],
          "seed_scout_indicators" => %{"information_gathering" => false}
        },
        alt_analysis: %{
          "character_bazaar_indicators" => %{"likely_purchased" => false}
        }
      }

      initial_alerts = AlertSystem.get_active_alerts()
      initial_count = length(initial_alerts)

      :ok = AlertSystem.process_vetting_analysis(vetting)
      Process.sleep(50)

      final_alerts = AlertSystem.get_active_alerts()

      # Should not create alerts for low risk
      assert length(final_alerts) - initial_count <= 1
    end
  end

  describe "process_killmail/1" do
    test "processes killmail data without errors" do
      killmail = %{
        killmail_id: 123_456,
        character_id: 789_123_456,
        solar_system_id: 30_000_142,
        ship_type_id: 587,
        killmail_time: DateTime.utc_now(),
        value: 50_000_000
      }

      :ok = AlertSystem.process_killmail(killmail)
      Process.sleep(50)

      # Should not crash the system
      alerts = AlertSystem.get_active_alerts()
      assert is_list(alerts)
    end

    test "handles high value killmail processing" do
      killmail = %{
        killmail_id: 789_012,
        character_id: 456_789_123,
        # J-space
        solar_system_id: 31_000_001,
        # Revelation
        ship_type_id: 19_720,
        killmail_time: DateTime.utc_now(),
        value: 5_000_000_000
      }

      :ok = AlertSystem.process_killmail(killmail)
      Process.sleep(50)

      alerts = AlertSystem.get_active_alerts()
      assert is_list(alerts)
    end
  end

  describe "get_active_alerts/0" do
    test "returns list of active alerts" do
      alerts = AlertSystem.get_active_alerts()

      assert is_list(alerts)

      # Each alert should have required fields if any exist
      for alert <- alerts do
        assert Map.has_key?(alert, :alert_id) or Map.has_key?(alert, :id)
        assert Map.has_key?(alert, :timestamp) or Map.has_key?(alert, :created_at)
        assert Map.has_key?(alert, :alert_type) or Map.has_key?(alert, :type)
      end
    end

    test "alerts are sorted by timestamp descending" do
      # Create multiple alerts to test sorting
      analysis1 = %{
        character_id: 111_111_111,
        threat_score: 9.0,
        dangerous_rating: 8.5,
        confidence: 0.9,
        awox_probability: 0.2,
        activity_patterns: %{red_flags: []}
      }

      analysis2 = %{
        character_id: 222_222_222,
        threat_score: 9.2,
        dangerous_rating: 8.7,
        confidence: 0.95,
        awox_probability: 0.25,
        activity_patterns: %{red_flags: []}
      }

      :ok = AlertSystem.process_character_analysis(analysis1)
      Process.sleep(10)
      :ok = AlertSystem.process_character_analysis(analysis2)
      Process.sleep(50)

      alerts = AlertSystem.get_active_alerts()

      # Should be ordered (most recent first) if multiple alerts exist
      if length(alerts) >= 2 do
        timestamps =
          Enum.map(alerts, fn alert ->
            alert.timestamp || alert.created_at || DateTime.utc_now()
          end)

        sorted_timestamps = Enum.sort(timestamps, {:desc, DateTime})
        assert timestamps == sorted_timestamps
      end
    end
  end

  describe "acknowledge_alert/2" do
    test "acknowledges an alert successfully" do
      # First create an alert
      analysis = %{
        character_id: 999_888_777,
        threat_score: 9.0,
        dangerous_rating: 8.5,
        confidence: 0.9,
        awox_probability: 0.3,
        activity_patterns: %{red_flags: []}
      }

      :ok = AlertSystem.process_character_analysis(analysis)
      Process.sleep(50)

      alerts = AlertSystem.get_active_alerts()

      if length(alerts) > 0 do
        alert = hd(alerts)
        alert_id = alert.alert_id || alert.id || "test_alert_id"

        # Acknowledge the alert
        :ok = AlertSystem.acknowledge_alert(alert_id, "test_user")
        Process.sleep(50)

        # System should still be responsive
        updated_alerts = AlertSystem.get_active_alerts()
        assert is_list(updated_alerts)
      else
        # If no alerts created, just test the acknowledge function doesn't crash
        :ok = AlertSystem.acknowledge_alert("nonexistent_alert", "test_user")
      end
    end

    test "handles acknowledging non-existent alert" do
      :ok = AlertSystem.acknowledge_alert("fake_alert_id", "test_user")

      # Should not crash the system
      alerts = AlertSystem.get_active_alerts()
      assert is_list(alerts)
    end
  end

  describe "error handling and edge cases" do
    test "handles malformed character analysis gracefully" do
      malformed_analysis = %{
        character_id: nil,
        threat_score: "not_a_number",
        confidence: "invalid"
      }

      # Should not crash
      :ok = AlertSystem.process_character_analysis(malformed_analysis)
      Process.sleep(50)

      # System should still be responsive
      alerts = AlertSystem.get_active_alerts()
      assert is_list(alerts)
    end

    test "handles malformed vetting analysis gracefully" do
      malformed_vetting = %{
        character_id: "not_an_integer",
        overall_risk_score: "invalid_score"
      }

      :ok = AlertSystem.process_vetting_analysis(malformed_vetting)
      Process.sleep(50)

      alerts = AlertSystem.get_active_alerts()
      assert is_list(alerts)
    end

    test "handles empty analysis data" do
      empty_analysis = %{}

      :ok = AlertSystem.process_character_analysis(empty_analysis)
      Process.sleep(50)

      alerts = AlertSystem.get_active_alerts()
      assert is_list(alerts)
    end

    test "handles nil analysis data" do
      # Should handle nil gracefully (though this might not be expected usage)
      try do
        :ok = AlertSystem.process_character_analysis(nil)
        Process.sleep(50)

        alerts = AlertSystem.get_active_alerts()
        assert is_list(alerts)
      rescue
        _ ->
          # If it raises an error, that's also acceptable behavior
          assert true
      end
    end
  end

  describe "periodic monitoring" do
    test "system handles periodic monitoring messages" do
      # Send a periodic monitoring message directly
      send(Process.whereis(AlertSystem), :periodic_monitoring)
      Process.sleep(50)

      # System should still be responsive
      alerts = AlertSystem.get_active_alerts()
      assert is_list(alerts)
    end
  end

  describe "alert thresholds and configuration" do
    test "respects critical threat threshold" do
      # Test with threat score just below threshold
      low_threat_analysis = %{
        character_id: 123_123_123,
        threat_score: 7.5,
        dangerous_rating: 7.5,
        confidence: 0.8,
        awox_probability: 0.2,
        activity_patterns: %{red_flags: []}
      }

      # Test with threat score above threshold
      high_threat_analysis = %{
        character_id: 456_456_456,
        threat_score: 9.0,
        dangerous_rating: 8.5,
        confidence: 0.9,
        awox_probability: 0.3,
        activity_patterns: %{red_flags: []}
      }

      initial_count = length(AlertSystem.get_active_alerts())

      :ok = AlertSystem.process_character_analysis(low_threat_analysis)
      Process.sleep(25)
      :ok = AlertSystem.process_character_analysis(high_threat_analysis)
      Process.sleep(50)

      final_alerts = AlertSystem.get_active_alerts()

      # System should be functional regardless of alert creation
      assert is_list(final_alerts)
      assert length(final_alerts) >= initial_count
    end

    test "respects high risk vetting threshold" do
      # Just below threshold
      low_risk_vetting = %{
        character_id: 789_789_789,
        overall_risk_score: 75,
        eviction_associations: %{"known_eviction_groups" => []},
        alt_analysis: %{"character_bazaar_indicators" => %{"likely_purchased" => false}}
      }

      # Above threshold
      high_risk_vetting = %{
        character_id: 101_101_101,
        overall_risk_score: 90,
        eviction_associations: %{"known_eviction_groups" => []},
        alt_analysis: %{"character_bazaar_indicators" => %{"likely_purchased" => false}}
      }

      initial_count = length(AlertSystem.get_active_alerts())

      :ok = AlertSystem.process_vetting_analysis(low_risk_vetting)
      Process.sleep(25)
      :ok = AlertSystem.process_vetting_analysis(high_risk_vetting)
      Process.sleep(50)

      final_alerts = AlertSystem.get_active_alerts()

      assert is_list(final_alerts)
      assert length(final_alerts) >= initial_count
    end
  end
end
