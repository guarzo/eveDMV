defmodule EveDmv.Contexts.BattleAnalysisTest do
  use ExUnit.Case, async: false
  use EveDmv.DataCase, async: false

  alias EveDmv.Contexts.BattleAnalysis

  describe "detect_recent_battles/2" do
    test "returns ok tuple with battles list" do
      # Test with a small window to avoid too much data
      result = BattleAnalysis.detect_recent_battles(1, min_participants: 1)

      assert {:ok, battles} = result
      assert is_list(battles)

      # Each battle should have the expected structure
      Enum.each(battles, fn battle ->
        assert is_binary(battle.battle_id)
        assert is_list(battle.killmails)
        assert is_map(battle.metadata)

        # Metadata should have expected fields
        assert Map.has_key?(battle.metadata, :killmail_count)
        assert Map.has_key?(battle.metadata, :duration_minutes)
        assert Map.has_key?(battle.metadata, :unique_participants)
        assert Map.has_key?(battle.metadata, :battle_type)
      end)
    end
  end

  describe "get_battle_statistics/2" do
    test "returns statistics for a time period" do
      start_time = NaiveDateTime.add(NaiveDateTime.utc_now(), -3600, :second)
      end_time = NaiveDateTime.utc_now()

      result = BattleAnalysis.get_battle_statistics(start_time, end_time)

      assert {:ok, stats} = result
      assert is_integer(stats.total_battles)
      assert is_integer(stats.total_kills)
      assert is_map(stats.battle_types)
      assert is_list(stats.most_active_systems)
      assert is_float(stats.average_battle_duration)
    end
  end
end
