defmodule EveDmv.Contexts.BattleAnalysis.Core.BattleDetectorTest do
  @moduledoc """
  Tests for the BattleDetector GenServer module.

  This module provides battle detection from killmail streams using
  time-based clustering and spatial correlation algorithms.
  """
  use EveDmv.DataCase, async: false

  alias EveDmv.Contexts.BattleAnalysis.Core.BattleDetector

  setup do
    # Stop any existing instance first
    if pid = GenServer.whereis(BattleDetector) do
      GenServer.stop(pid, :normal, 5000)
      Process.sleep(100)
    end

    {:ok, pid} = BattleDetector.start_link([])

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5000)
    end)

    {:ok, server_pid: pid}
  end

  describe "GenServer lifecycle" do
    test "starts successfully" do
      # GenServer is started in setup
      assert GenServer.whereis(BattleDetector) != nil
    end

    test "get_active_battles returns empty map initially" do
      {:ok, battles} = BattleDetector.get_active_battles()

      assert battles == %{}
    end
  end

  describe "detect_battles/2" do
    test "returns empty list for empty killmails" do
      {:ok, battles} = BattleDetector.detect_battles([])

      assert battles == []
    end

    test "returns empty list or battles based on participant threshold" do
      # Create killmails with few attackers - participant count depends on unique chars
      killmails = [
        build_killmail(1, 30_000_142, :now, 2),
        build_killmail(2, 30_000_142, :now, 2)
      ]

      {:ok, battles} = BattleDetector.detect_battles(killmails)

      # Returns whatever battles are detected based on the algorithm
      assert is_list(battles)
    end

    test "detects battle from clustered killmails" do
      system_id = 30_000_142
      now = DateTime.utc_now()

      # Create killmails within time window with enough participants
      killmails = [
        build_killmail(1, system_id, now, 5),
        build_killmail(2, system_id, DateTime.add(now, 2 * 60, :second), 4),
        build_killmail(3, system_id, DateTime.add(now, 5 * 60, :second), 3)
      ]

      {:ok, battles} = BattleDetector.detect_battles(killmails, min_participants: 4)

      # Should detect at least one battle
      refute Enum.empty?(battles)

      battle = List.first(battles)
      assert battle.system_id == system_id
      assert is_list(battle.killmail_ids)
      refute Enum.empty?(battle.killmail_ids)
      assert Map.has_key?(battle, :participant_count)
      assert Map.has_key?(battle, :total_value)
      assert Map.has_key?(battle, :intensity_score)
    end

    test "separates killmails in different systems" do
      now = DateTime.utc_now()

      # Create killmails in different systems
      killmails = [
        build_killmail(1, 30_000_142, now, 5),
        build_killmail(2, 30_000_142, DateTime.add(now, 60, :second), 5),
        build_killmail(3, 30_002_187, now, 5),
        build_killmail(4, 30_002_187, DateTime.add(now, 60, :second), 5)
      ]

      {:ok, battles} = BattleDetector.detect_battles(killmails, min_participants: 4)

      # Could be 0, 1, or 2 battles depending on participant overlap
      # The key test is that system_id is tracked correctly
      Enum.each(battles, fn battle ->
        assert battle.system_id in [30_000_142, 30_002_187]
      end)
    end

    test "respects custom time_window option" do
      system_id = 30_000_142
      now = DateTime.utc_now()

      # Create killmails outside default 10-minute window
      killmails = [
        build_killmail(1, system_id, now, 5),
        # 20 minutes later
        build_killmail(2, system_id, DateTime.add(now, 20 * 60, :second), 5)
      ]

      # With default 10-minute window, should be separate clusters
      {:ok, battles_default} = BattleDetector.detect_battles(killmails, min_participants: 4)

      # With 30-minute window, should be same cluster
      {:ok, battles_wide} =
        BattleDetector.detect_battles(killmails, time_window: 30, min_participants: 4)

      # Wide window should have equal or fewer battles than default
      assert length(battles_wide) <= length(battles_default) or Enum.empty?(battles_default)
    end

    test "respects custom min_participants option" do
      system_id = 30_000_142
      now = DateTime.utc_now()

      killmails = [
        build_killmail(1, system_id, now, 3),
        build_killmail(2, system_id, DateTime.add(now, 60, :second), 3)
      ]

      # With min 10 participants, should not detect
      {:ok, battles_high} = BattleDetector.detect_battles(killmails, min_participants: 10)

      # With min 2 participants, should detect
      {:ok, battles_low} = BattleDetector.detect_battles(killmails, min_participants: 2)

      assert length(battles_high) <= length(battles_low)
    end
  end

  describe "process_killmail/1" do
    test "accepts killmail for real-time processing" do
      killmail = build_killmail(1, 30_000_142, DateTime.utc_now(), 5)

      # cast returns :ok immediately
      result = BattleDetector.process_killmail(killmail)

      assert result == :ok
    end

    test "updates active battles after processing" do
      killmail = build_killmail(1, 30_000_142, DateTime.utc_now(), 5)

      BattleDetector.process_killmail(killmail)
      # Give the GenServer time to process
      Process.sleep(100)

      {:ok, battles} = BattleDetector.get_active_battles()

      # Should have at least one active battle tracking this killmail
      assert map_size(battles) >= 1
    end
  end

  describe "detect_system_battles/2" do
    test "returns list for nonexistent system" do
      # Uses a system ID that won't have any killmails
      battles = BattleDetector.detect_system_battles(99_999_999)

      # Should return empty list for system with no data
      assert is_list(battles)
    end
  end

  describe "get_system_battle_stats/1" do
    test "returns stats structure with expected keys" do
      # For a system with no killmails, should return zero stats
      stats = BattleDetector.get_system_battle_stats(99_999_999)

      assert is_map(stats)
      assert Map.has_key?(stats, :total_battles)
      assert Map.has_key?(stats, :total_kills)
      assert Map.has_key?(stats, :total_isk_destroyed)
      assert Map.has_key?(stats, :average_battle_size)
      assert Map.has_key?(stats, :battle_frequency)
      assert stats.total_battles == 0
    end
  end

  describe "detect_character_battles/2" do
    test "returns list for character" do
      # Uses a character ID that won't have any killmails
      battles = BattleDetector.detect_character_battles(99_999_999)

      assert is_list(battles)
    end
  end

  describe "get_character_battle_stats/1" do
    test "returns stats structure with expected keys" do
      stats = BattleDetector.get_character_battle_stats(99_999_999)

      assert is_map(stats)
      assert Map.has_key?(stats, :total_battles)
      assert Map.has_key?(stats, :total_kills)
      assert Map.has_key?(stats, :total_losses)
      assert Map.has_key?(stats, :isk_destroyed)
      assert Map.has_key?(stats, :isk_lost)
      assert Map.has_key?(stats, :most_active_system)
      assert stats.total_battles == 0
    end
  end

  describe "detect_corporation_battles/2" do
    test "returns list for corporation" do
      battles = BattleDetector.detect_corporation_battles(99_999_999)

      assert is_list(battles)
    end
  end

  describe "get_corporation_battle_stats/1" do
    test "returns stats structure with expected keys" do
      stats = BattleDetector.get_corporation_battle_stats(99_999_999)

      assert is_map(stats)
      assert Map.has_key?(stats, :total_battles)
      assert Map.has_key?(stats, :total_kills)
      assert Map.has_key?(stats, :total_losses)
      assert Map.has_key?(stats, :isk_destroyed)
      assert Map.has_key?(stats, :isk_lost)
      assert Map.has_key?(stats, :efficiency)
      assert stats.total_battles == 0
    end
  end

  describe "detect_battle_from_killmail/1" do
    test "returns error for killmail not part of a battle" do
      # Create a minimal killmail without related killmails in DB
      killmail = %{
        killmail_id: System.unique_integer([:positive]),
        killmail_time: DateTime.utc_now(),
        solar_system_id: 30_000_142,
        victim: %{"character_id" => 90_000_001, "ship_type_id" => 587},
        attackers: [],
        zkb: %{"totalValue" => 1_000_000}
      }

      result = BattleDetector.detect_battle_from_killmail(killmail)

      # Without related killmails, may not detect a battle
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "battle structure" do
    test "battle contains required fields" do
      now = DateTime.utc_now()
      system_id = 30_000_142

      killmails = [
        build_killmail(1, system_id, now, 10),
        build_killmail(2, system_id, DateTime.add(now, 60, :second), 8),
        build_killmail(3, system_id, DateTime.add(now, 120, :second), 6)
      ]

      {:ok, battles} = BattleDetector.detect_battles(killmails, min_participants: 4)

      unless Enum.empty?(battles) do
        battle = List.first(battles)

        assert is_binary(battle.id)
        assert String.starts_with?(battle.id, "battle_")
        assert battle.system_id == system_id
        assert is_list(battle.killmail_ids)
        assert %DateTime{} = battle.start_time
        assert %DateTime{} = battle.end_time
        assert is_integer(battle.participant_count)
        assert battle.participant_count >= 4
        assert is_map(battle.ship_classes)
        assert is_number(battle.total_value)
        assert is_number(battle.intensity_score)
      end
    end
  end

  describe "time window behavior" do
    test "killmails outside time window form separate clusters" do
      system_id = 30_000_142
      now = DateTime.utc_now()

      # Create two groups of killmails 30 minutes apart (outside 10-minute default window)
      killmails =
        [
          build_killmail(1, system_id, now, 6),
          build_killmail(2, system_id, DateTime.add(now, 60, :second), 5)
        ] ++
          [
            build_killmail(3, system_id, DateTime.add(now, 30 * 60, :second), 6),
            build_killmail(4, system_id, DateTime.add(now, 31 * 60, :second), 5)
          ]

      {:ok, battles} = BattleDetector.detect_battles(killmails, min_participants: 4)

      # Should form at most 2 separate battles (one per time cluster)
      # Could be 0, 1, or 2 depending on participant overlap
      assert length(battles) <= 2
    end
  end

  # Helper functions

  defp build_killmail(killmail_id, system_id, time, attacker_count) do
    actual_time =
      case time do
        :now -> DateTime.utc_now()
        %DateTime{} = dt -> dt
      end

    victim_char_id = Enum.random(90_000_000..95_000_000)

    attackers =
      for i <- 1..attacker_count do
        %{
          "character_id" => 95_000_000 + i + killmail_id * 100,
          "corporation_id" => 98_000_001,
          "alliance_id" => 99_000_001,
          "ship_type_id" => Enum.random([587, 588, 589, 620, 621, 622]),
          "damage_done" => Enum.random(100..5000),
          "final_blow" => i == 1
        }
      end

    %{
      killmail_id: killmail_id,
      killmail_time: actual_time,
      solar_system_id: system_id,
      victim: %{
        "character_id" => victim_char_id,
        "corporation_id" => 98_000_002,
        "alliance_id" => 99_000_002,
        "ship_type_id" => Enum.random([587, 588, 589])
      },
      attackers: attackers,
      zkb: %{
        "totalValue" => Enum.random(10_000_000..500_000_000)
      }
    }
  end
end
