defmodule EveDmv.Contexts.Surveillance.Domain.AlertServiceTest do
  use ExUnit.Case, async: true

  alias EveDmv.Contexts.Surveillance.Domain.AlertService

  describe "alert priority determination" do
    test "assigns critical priority for high confidence matches" do
      match = %{
        id: "test_match",
        profile_id: "test_profile",
        killmail_id: "test_killmail",
        confidence_score: 0.95,
        matched_criteria: [%{type: :victim}],
        timestamp: DateTime.utc_now()
      }

      alert = AlertService.generate_alert(match)

      # Critical priority
      assert {:ok, %{priority: 1}} = alert
    end

    test "assigns appropriate priority based on criteria types" do
      match = %{
        id: "test_match",
        profile_id: "test_profile",
        killmail_id: "test_killmail",
        confidence_score: 0.8,
        matched_criteria: [%{type: :high_value_target}],
        timestamp: DateTime.utc_now()
      }

      alert = AlertService.generate_alert(match)

      assert {:ok, %{priority: priority}} = alert
      # Should be high or critical priority
      assert priority <= 2
    end
  end

  describe "alert type determination" do
    test "identifies target killed alerts" do
      match = %{
        id: "test_match",
        profile_id: "test_profile",
        killmail_id: "test_killmail",
        confidence_score: 0.8,
        matched_criteria: [%{type: :victim}],
        timestamp: DateTime.utc_now()
      }

      alert = AlertService.generate_alert(match)

      assert {:ok, %{alert_type: :target_killed}} = alert
    end

    test "identifies target activity alerts" do
      match = %{
        id: "test_match",
        profile_id: "test_profile",
        killmail_id: "test_killmail",
        confidence_score: 0.8,
        matched_criteria: [%{type: :attacker}],
        timestamp: DateTime.utc_now()
      }

      alert = AlertService.generate_alert(match)

      assert {:ok, %{alert_type: :target_active}} = alert
    end

    test "identifies location activity alerts" do
      match = %{
        id: "test_match",
        profile_id: "test_profile",
        killmail_id: "test_killmail",
        confidence_score: 0.8,
        matched_criteria: [%{type: :system}],
        timestamp: DateTime.utc_now()
      }

      alert = AlertService.generate_alert(match)

      assert {:ok, %{alert_type: :location_activity}} = alert
    end
  end

  describe "alert metadata extraction" do
    test "extracts relevant metadata from matches" do
      match = %{
        id: "test_match",
        profile_id: "test_profile",
        killmail_id: "test_killmail",
        confidence_score: 0.8,
        matched_criteria: [
          %{type: :victim},
          %{type: :attacker}
        ],
        timestamp: DateTime.utc_now()
      }

      alert = AlertService.generate_alert(match)

      assert {:ok, %{metadata: metadata}} = alert
      assert metadata.criteria_count == 2
      assert metadata.has_victim_match == true
      assert metadata.has_attacker_match == true
    end
  end
end
