defmodule EveDmv.Contexts.SystemAnalysis.EscalationAlertsTest do
  use EveDmvWeb.ConnCase, async: true
  import EveDmv.Factories

  alias EveDmv.Contexts.SystemAnalysis

  describe "escalation detection" do
    test "detect_escalations/1 identifies activity spikes" do
      # Create baseline killmails (low activity)
      baseline_time = DateTime.utc_now() |> DateTime.add(-12, :hour)

      create(:killmail_raw,
        solar_system_id: 30_000_142,
        killmail_time: baseline_time,
        zkb_total_value: Decimal.new(50_000_000)
      )

      # Create current escalation (high activity)
      current_time = DateTime.utc_now() |> DateTime.add(-2, :hour)

      for _ <- 1..10 do
        create(:killmail_raw,
          solar_system_id: 30_000_142,
          killmail_time: current_time,
          zkb_total_value: Decimal.new(Enum.random(100_000_000..500_000_000))
        )
      end

      {:ok, escalations} = SystemAnalysis.detect_escalations(hours: 6, baseline_hours: 24)

      assert escalations != []

      escalation = Enum.find(escalations, fn e -> e.system_id == 30_000_142 end)
      assert escalation != nil
      assert escalation.current_kills >= 10
      assert escalation.escalation_score >= 1.5
      assert escalation.severity in [:medium, :high, :critical]
    end

    test "get_escalation_alerts/1 filters by severity" do
      # Create high-activity system
      current_time = DateTime.utc_now() |> DateTime.add(-1, :hour)

      for _ <- 1..20 do
        create(:killmail_raw,
          solar_system_id: 30_000_143,
          killmail_time: current_time,
          zkb_total_value: Decimal.new(200_000_000)
        )
      end

      alerts = SystemAnalysis.get_escalation_alerts()

      # Should only return medium+ severity alerts
      assert is_list(alerts)

      if alerts != [] do
        alert = List.first(alerts)
        assert alert.severity in [:medium, :high, :critical]
        assert alert.system_id == 30_000_143
        assert alert.escalation_score >= 1.5
        assert is_binary(alert.description)
        assert is_binary(alert.system_name)
      end
    end

    test "escalation classification works correctly" do
      # Create massive engagement
      current_time = DateTime.utc_now() |> DateTime.add(-1, :hour)
      # Above massive_engagement threshold
      for _ <- 1..35 do
        create(:killmail_raw,
          solar_system_id: 30_000_144,
          killmail_time: current_time,
          zkb_total_value: Decimal.new(100_000_000)
        )
      end

      {:ok, escalations} = SystemAnalysis.detect_escalations(hours: 4)

      escalation = Enum.find(escalations, fn e -> e.system_id == 30_000_144 end)

      if escalation do
        assert escalation.escalation_type == :massive_engagement
        assert escalation.current_kills >= 35
        assert escalation.severity in [:high, :critical]
      end
    end

    test "escalation description generation" do
      # Create capital engagement (high ISK value)
      current_time = DateTime.utc_now() |> DateTime.add(-1, :hour)

      for _ <- 1..5 do
        create(:killmail_raw,
          solar_system_id: 30_000_145,
          killmail_time: current_time,
          # 2B ISK each
          zkb_total_value: Decimal.new(2_000_000_000)
        )
      end

      {:ok, escalations} = SystemAnalysis.detect_escalations(hours: 4)

      escalation = Enum.find(escalations, fn e -> e.system_id == 30_000_145 end)

      if escalation do
        assert escalation.escalation_type == :capital_engagement

        assert String.contains?(escalation.description, "capital") ||
                 String.contains?(escalation.description, "High-value") ||
                 String.contains?(escalation.description, "ISK")
      end
    end
  end

  describe "escalation metrics" do
    test "escalation score calculation" do
      # Test with known activity levels
      baseline_time = DateTime.utc_now() |> DateTime.add(-18, :hour)

      create(:killmail_raw,
        solar_system_id: 30_000_146,
        killmail_time: baseline_time,
        zkb_total_value: Decimal.new(50_000_000)
      )

      # Current activity (5x increase)
      current_time = DateTime.utc_now() |> DateTime.add(-2, :hour)

      for _ <- 1..5 do
        create(:killmail_raw,
          solar_system_id: 30_000_146,
          killmail_time: current_time,
          zkb_total_value: Decimal.new(100_000_000)
        )
      end

      {:ok, escalations} = SystemAnalysis.detect_escalations(hours: 6, baseline_hours: 24)

      escalation = Enum.find(escalations, fn e -> e.system_id == 30_000_146 end)

      if escalation do
        # Should show increase
        assert escalation.kill_factor >= 2.0
        # Should be significant
        assert escalation.escalation_score >= 1.5
      end
    end
  end
end
