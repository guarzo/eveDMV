defmodule EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Analyzers.SingleSystemAnalyzerTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Analyzers.SingleSystemAnalyzer
  alias EveDmv.Eve.SolarSystem
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Killmails.Participant

  describe "analyze_system/2" do
    setup do
      # Create test solar systems
      {:ok, jita} =
        SolarSystem.create(%{
          system_id: 30_000_142,
          system_name: "Jita",
          constellation_id: 20_000_020,
          region_id: 10_000_002,
          security_status: Decimal.new("1.0"),
          security_class: "highsec"
        })

      {:ok, perimeter} =
        SolarSystem.create(%{
          system_id: 30_000_144,
          system_name: "Perimeter",
          constellation_id: 20_000_020,
          region_id: 10_000_002,
          security_status: Decimal.new("0.9"),
          security_class: "highsec"
        })

      {:ok, maurasi} =
        SolarSystem.create(%{
          system_id: 30_000_145,
          system_name: "Maurasi",
          constellation_id: 20_000_020,
          region_id: 10_000_002,
          security_status: Decimal.new("0.9"),
          security_class: "highsec"
        })

      {:ok, _wh_system} =
        SolarSystem.create(%{
          system_id: 31_000_001,
          system_name: "J123456",
          constellation_id: 21_000_001,
          region_id: 11_000_001,
          security_status: Decimal.new("-1.0"),
          security_class: "wormhole",
          wormhole_class_id: 3
        })

      {:ok, _null_system} =
        SolarSystem.create(%{
          system_id: 30_001_234,
          system_name: "Some Null",
          constellation_id: 20_001_234,
          region_id: 10_001_234,
          security_status: Decimal.new("-0.5"),
          security_class: "nullsec"
        })

      %{jita: jita, perimeter: perimeter, maurasi: maurasi}
    end

    test "analyzes system with basic information", %{jita: jita} do
      result = SingleSystemAnalyzer.analyze_system(jita.system_id)

      assert result.system_id == 30_000_142
      assert result.system_name == "Jita"
      assert result.security_class == "highsec"
      # Jita is a major trade hub
      assert result.strategic_value == :critical
    end

    test "handles non-existent system gracefully" do
      result = SingleSystemAnalyzer.analyze_system(99_999_999)

      assert result.system_id == 99_999_999
      assert result.activity_level == :unknown
      assert result.threat_level == :unknown
      assert result.strategic_value == :unknown
      assert result.error == "System not found"
    end

    test "analyzes activity level based on killmails", %{jita: jita} do
      # Create killmails in different time windows
      now = DateTime.utc_now()
      # 1 hour ago
      recent = DateTime.add(now, -3600, :second)
      # 8 days ago
      old = DateTime.add(now, -8 * 24 * 3600, :second)

      # Recent killmails (should be counted)
      for i <- 1..25 do
        {:ok, _} =
          KillmailRaw.create(%{
            killmail_id: i,
            solar_system_id: jita.system_id,
            killmail_time: recent,
            total_value: Decimal.new("1000000")
          })
      end

      # Old killmails (should not be counted with default 7-day window)
      for i <- 26..35 do
        {:ok, _} =
          KillmailRaw.create(%{
            killmail_id: i,
            solar_system_id: jita.system_id,
            killmail_time: old,
            total_value: Decimal.new("1000000")
          })
      end

      result = SingleSystemAnalyzer.analyze_system(jita.system_id)
      # 25 kills = moderate
      assert result.activity_level == :moderate
    end

    test "respects custom time window", %{jita: jita} do
      # Create killmail 2 hours ago
      two_hours_ago = DateTime.add(DateTime.utc_now(), -2 * 3600, :second)

      {:ok, _} =
        KillmailRaw.create(%{
          killmail_id: 1,
          solar_system_id: jita.system_id,
          killmail_time: two_hours_ago,
          total_value: Decimal.new("1000000")
        })

      # With 1-hour window, should see no activity
      result_1h = SingleSystemAnalyzer.analyze_system(jita.system_id, time_window: 1)
      assert result_1h.activity_level == :none

      # With 3-hour window, should see activity
      result_3h = SingleSystemAnalyzer.analyze_system(jita.system_id, time_window: 3)
      assert result_3h.activity_level == :minimal
    end

    test "analyzes threat level based on high-value losses", %{jita: jita} do
      now = DateTime.utc_now()
      recent = DateTime.add(now, -3600, :second)

      # Create high-value killmails
      for i <- 1..12 do
        {:ok, _} =
          KillmailRaw.create(%{
            killmail_id: i,
            solar_system_id: jita.system_id,
            killmail_time: recent,
            # 500M each
            total_value: Decimal.new("500000000")
          })
      end

      result = SingleSystemAnalyzer.analyze_system(jita.system_id)
      # 12 high-value kills = high threat
      assert result.threat_level == :high
    end

    test "calculates strategic value correctly" do
      # Test trade hub
      jita_result = SingleSystemAnalyzer.analyze_system(30_000_142)
      assert jita_result.strategic_value == :critical

      # Test wormhole
      wh_result = SingleSystemAnalyzer.analyze_system(31_000_001)
      assert wh_result.strategic_value == :high

      # Test nullsec
      null_result = SingleSystemAnalyzer.analyze_system(30_001_234)
      assert null_result.strategic_value == :high
    end

    test "analyzes system connections", %{jita: jita, perimeter: perimeter, maurasi: maurasi} do
      result = SingleSystemAnalyzer.analyze_system(jita.system_id)

      # Including Jita itself
      assert result.connections.constellation_systems == 3
      assert length(result.connections.direct_connections) > 0

      # Should include Perimeter and Maurasi in connections
      system_ids = Enum.map(result.connections.direct_connections, & &1.system_id)
      assert perimeter.system_id in system_ids
      assert maurasi.system_id in system_ids
    end

    test "identifies strategic connections between security classes" do
      # Create a lowsec system in the same constellation as highsec
      {:ok, _lowsec} =
        SolarSystem.create(%{
          system_id: 30_000_146,
          system_name: "Lowsec Gateway",
          # Same as Jita
          constellation_id: 20_000_020,
          region_id: 10_000_002,
          security_status: Decimal.new("0.4"),
          security_class: "lowsec"
        })

      # Jita
      result = SingleSystemAnalyzer.analyze_system(30_000_142)

      # Should identify the lowsec system as a strategic connection
      strategic_ids = Enum.map(result.connections.strategic_connections, & &1.system_id)
      assert 30_000_146 in strategic_ids
    end

    test "calculates influence radius based on participant activity" do
      now = DateTime.utc_now()
      recent = DateTime.add(now, -3600, :second)

      # Create killmails with participants
      for i <- 1..15 do
        {:ok, km} =
          KillmailRaw.create(%{
            killmail_id: i,
            # Spread across systems
            solar_system_id: 30_000_142 + rem(i, 5),
            killmail_time: recent,
            total_value: Decimal.new("1000000")
          })

        # Add participant that would match our system
        {:ok, _} =
          Participant.create(%{
            killmail_id: km.killmail_id,
            # Will match system_id modulo
            character_id: 30_000_142 * 10 + i,
            corporation_id: 1000 + i,
            alliance_id: if(i > 5, do: 99_999, else: nil),
            ship_type_id: 587,
            final_blow: false,
            damage_done: 1000,
            security_status: Decimal.new("5.0"),
            is_victim: false
          })
      end

      result = SingleSystemAnalyzer.analyze_system(30_000_142)
      assert result.influence_radius > 0
    end
  end

  describe "activity level thresholds" do
    setup do
      {:ok, system} =
        SolarSystem.create(%{
          system_id: 30_000_999,
          system_name: "Test System",
          constellation_id: 20_000_999,
          region_id: 10_000_999,
          security_status: Decimal.new("0.5"),
          security_class: "highsec"
        })

      %{system: system}
    end

    test "correctly categorizes activity levels", %{system: system} do
      now = DateTime.utc_now()
      recent = DateTime.add(now, -3600, :second)

      # Test each threshold
      test_cases = [
        {0, :none},
        {3, :minimal},
        {10, :low},
        {30, :moderate},
        {60, :high},
        {150, :very_high}
      ]

      for {kill_count, expected_level} <- test_cases do
        # Clear existing killmails
        Repo.delete_all(KillmailRaw)

        # Create the specified number of killmails
        for i <- 1..kill_count do
          {:ok, _} =
            KillmailRaw.create(%{
              killmail_id: 1000 + i,
              solar_system_id: system.system_id,
              killmail_time: recent,
              total_value: Decimal.new("1000000")
            })
        end

        result = SingleSystemAnalyzer.analyze_system(system.system_id)

        assert result.activity_level == expected_level,
               "Expected #{expected_level} for #{kill_count} kills, got #{result.activity_level}"
      end
    end
  end

  describe "threat level calculations" do
    setup do
      {:ok, system} =
        SolarSystem.create(%{
          system_id: 30_000_998,
          system_name: "Threat Test System",
          constellation_id: 20_000_998,
          region_id: 10_000_998,
          security_status: Decimal.new("0.5"),
          security_class: "highsec"
        })

      %{system: system}
    end

    test "threat level based on kill count and value", %{system: system} do
      now = DateTime.utc_now()
      recent = DateTime.add(now, -3600, :second)

      # Test critical threat - many high-value kills
      for i <- 1..25 do
        {:ok, _} =
          KillmailRaw.create(%{
            killmail_id: 2000 + i,
            solar_system_id: system.system_id,
            killmail_time: recent,
            # 600M each
            total_value: Decimal.new("600000000")
          })
      end

      result = SingleSystemAnalyzer.analyze_system(system.system_id)
      assert result.threat_level == :critical
    end

    test "filters out low-value kills for threat assessment", %{system: system} do
      now = DateTime.utc_now()
      recent = DateTime.add(now, -3600, :second)

      # Create many low-value kills (should be ignored)
      for i <- 1..50 do
        {:ok, _} =
          KillmailRaw.create(%{
            killmail_id: 3000 + i,
            solar_system_id: system.system_id,
            killmail_time: recent,
            # 50M each, below 100M threshold
            total_value: Decimal.new("50000000")
          })
      end

      result = SingleSystemAnalyzer.analyze_system(system.system_id)
      # Low-value kills don't count
      assert result.threat_level == :minimal
    end
  end
end
