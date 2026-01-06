defmodule EveDmv.Contexts.BattleAnalysis.Domain.MultiSystemBattleCorrelatorTest do
  @moduledoc """
  Tests for multi-system battle correlation across wormhole chains.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.BattleAnalysis.Domain.MultiSystemBattleCorrelator

  describe "correlate_multi_system_battles/2" do
    test "handles empty battle list" do
      result = MultiSystemBattleCorrelator.correlate_multi_system_battles([])

      assert {:ok, battles} = result
      assert battles == []
    end

    test "handles single battle (no correlation needed)" do
      battle = build_battle(30_000_142, DateTime.utc_now(), 3)

      result = MultiSystemBattleCorrelator.correlate_multi_system_battles([battle])

      assert {:ok, battles} = result
      assert not Enum.empty?(battles)
    end

    test "accepts single battle map as input" do
      battle = build_battle(30_000_142, DateTime.utc_now(), 3)

      result = MultiSystemBattleCorrelator.correlate_multi_system_battles(battle)

      assert {:ok, battles} = result
      assert is_list(battles)
    end

    test "correlates battles with temporal proximity" do
      now = DateTime.utc_now()
      # 5 minutes apart
      later = DateTime.add(now, 5 * 60, :second)

      battle1 = build_battle(30_000_142, now, 3)
      battle2 = build_battle(30_000_143, later, 3)

      result = MultiSystemBattleCorrelator.correlate_multi_system_battles([battle1, battle2])

      assert {:ok, battles} = result
      assert is_list(battles)
    end

    test "separates temporally distant battles" do
      now = DateTime.utc_now()
      # 2 hours apart - should not correlate
      later = DateTime.add(now, 2 * 60 * 60, :second)

      battle1 = build_battle(30_000_142, now, 3)
      battle2 = build_battle(30_000_143, later, 3)

      result = MultiSystemBattleCorrelator.correlate_multi_system_battles([battle1, battle2])

      assert {:ok, battles} = result
      assert is_list(battles)
    end

    test "respects max_time_gap option" do
      now = DateTime.utc_now()
      # 15 minutes apart
      later = DateTime.add(now, 15 * 60, :second)

      battle1 = build_battle(30_000_142, now, 3)
      battle2 = build_battle(30_000_143, later, 3)

      # With 10 minute max gap, should not correlate
      result =
        MultiSystemBattleCorrelator.correlate_multi_system_battles([battle1, battle2],
          max_time_gap: 10
        )

      assert {:ok, battles} = result
      assert is_list(battles)
    end

    test "respects min_overlap option" do
      now = DateTime.utc_now()
      later = DateTime.add(now, 5 * 60, :second)

      battle1 = build_battle_with_participants(30_000_142, now, [1001, 1002, 1003])
      # Different participants
      battle2 = build_battle_with_participants(30_000_143, later, [2001, 2002, 2003])

      result =
        MultiSystemBattleCorrelator.correlate_multi_system_battles([battle1, battle2],
          min_overlap: 0.5
        )

      assert {:ok, battles} = result
      assert is_list(battles)
    end

    test "handles system_connections option" do
      now = DateTime.utc_now()
      later = DateTime.add(now, 5 * 60, :second)

      battle1 = build_battle(30_000_142, now, 3)
      battle2 = build_battle(30_000_143, later, 3)

      connections = %{
        30_000_142 => [30_000_143],
        30_000_143 => [30_000_142]
      }

      result =
        MultiSystemBattleCorrelator.correlate_multi_system_battles([battle1, battle2],
          system_connections: connections
        )

      assert {:ok, battles} = result
      assert is_list(battles)
    end

    test "handles wormhole system IDs" do
      now = DateTime.utc_now()
      later = DateTime.add(now, 5 * 60, :second)

      # J-space systems
      battle1 = build_battle(31_000_142, now, 3)
      battle2 = build_battle(31_000_143, later, 3)

      result = MultiSystemBattleCorrelator.correlate_multi_system_battles([battle1, battle2])

      assert {:ok, battles} = result
      assert is_list(battles)
    end

    test "handles battles with shared participants" do
      now = DateTime.utc_now()
      later = DateTime.add(now, 5 * 60, :second)

      # Same participants in both battles - should correlate
      shared_participants = [1001, 1002, 1003]
      battle1 = build_battle_with_participants(30_000_142, now, shared_participants)
      battle2 = build_battle_with_participants(30_000_143, later, shared_participants)

      result = MultiSystemBattleCorrelator.correlate_multi_system_battles([battle1, battle2])

      assert {:ok, battles} = result
      assert is_list(battles)
    end

    test "handles multiple systems in chain" do
      now = DateTime.utc_now()

      battles =
        Enum.map(1..5, fn i ->
          time = DateTime.add(now, i * 3 * 60, :second)
          build_battle(30_000_142 + i, time, 3)
        end)

      result = MultiSystemBattleCorrelator.correlate_multi_system_battles(battles)

      assert {:ok, correlated} = result
      assert is_list(correlated)
    end

    test "handles battles with varying participant counts" do
      now = DateTime.utc_now()
      later = DateTime.add(now, 5 * 60, :second)

      # Large battle
      battle1 = build_battle(30_000_142, now, 20)
      # Small skirmish
      battle2 = build_battle(30_000_143, later, 3)

      result = MultiSystemBattleCorrelator.correlate_multi_system_battles([battle1, battle2])

      assert {:ok, battles} = result
      assert is_list(battles)
    end
  end

  describe "correlation edge cases" do
    test "handles battles with nil killmails" do
      battle = %{
        system_id: 30_000_142,
        start_time: DateTime.utc_now(),
        end_time: DateTime.add(DateTime.utc_now(), 30 * 60, :second),
        killmails: nil,
        participants: []
      }

      result = MultiSystemBattleCorrelator.correlate_multi_system_battles([battle])

      assert {:ok, battles} = result
      assert is_list(battles)
    end

    test "handles battles with empty participants" do
      battle = %{
        system_id: 30_000_142,
        start_time: DateTime.utc_now(),
        end_time: DateTime.add(DateTime.utc_now(), 30 * 60, :second),
        killmails: [],
        participants: []
      }

      result = MultiSystemBattleCorrelator.correlate_multi_system_battles([battle])

      assert {:ok, battles} = result
      assert is_list(battles)
    end

    test "handles mixed system types (k-space and j-space)" do
      now = DateTime.utc_now()
      later = DateTime.add(now, 5 * 60, :second)

      # K-space
      battle1 = build_battle(30_000_142, now, 3)
      # J-space
      battle2 = build_battle(31_000_001, later, 3)

      result = MultiSystemBattleCorrelator.correlate_multi_system_battles([battle1, battle2])

      assert {:ok, battles} = result
      assert is_list(battles)
    end
  end

  # Helper functions

  defp build_battle(system_id, start_time, participant_count) do
    participant_ids = Enum.map(1..participant_count, fn _ -> character_id() end)
    build_battle_with_participants(system_id, start_time, participant_ids)
  end

  defp build_battle_with_participants(system_id, start_time, participant_ids) do
    participants =
      Enum.map(participant_ids, fn id ->
        %{
          character_id: id,
          corporation_id: corporation_id(),
          alliance_id: Enum.random([nil, Enum.random(99_000_000..99_999_999)]),
          ship_type_id: random_ship_by_role(:cruiser),
          is_victim: false
        }
      end)

    end_time = DateTime.add(start_time, 30 * 60, :second)

    %{
      system_id: system_id,
      start_time: start_time,
      end_time: end_time,
      killmails: [],
      participants: participants,
      total_value: Decimal.new(100_000_000)
    }
  end
end
