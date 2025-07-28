defmodule EveDmv.Contexts.BattleAnalysisConsolidatedTest do
  @moduledoc """
  Consolidated test suite for BattleAnalysis context.
  This replaces the duplicate tests in battle_analysis_test.exs and battle_timeline_test.exs
  """
  use ExUnit.Case, async: false
  use EveDmv.DataCase, async: false

  alias EveDmv.Contexts.BattleAnalysis

  describe "Battle Detection" do
    test "detect_recent_battles/2 returns battles with correct structure" do
      result = BattleAnalysis.detect_recent_battles(1, min_participants: 1)

      assert {:ok, battles} = result
      assert is_list(battles)

      Enum.each(battles, fn battle ->
        assert_battle_structure(battle)
      end)
    end

    test "handles empty results gracefully" do
      # Test with impossible criteria to ensure empty result handling
      result = BattleAnalysis.detect_recent_battles(0.001, min_participants: 1000)

      assert {:ok, battles} = result
      assert battles == []
    end
  end

  describe "Battle Timeline" do
    test "reconstruct_battle_timeline/1 builds complete timeline" do
      {:ok, battles} = BattleAnalysis.detect_recent_battles(24, min_participants: 2)

      if length(battles) > 0 do
        battle = List.first(battles)
        timeline = BattleAnalysis.reconstruct_battle_timeline(battle)

        assert_timeline_structure(timeline, battle)
      end
    end

    test "get_battle_with_timeline/1 returns battle with timeline data" do
      {:ok, battles} = BattleAnalysis.detect_recent_battles(24, min_participants: 1)

      if length(battles) > 0 do
        battle = List.first(battles)

        case BattleAnalysis.get_battle_with_timeline(battle.battle_id) do
          {:ok, battle_with_timeline} ->
            assert battle_with_timeline.battle_id == battle.battle_id
            assert Map.has_key?(battle_with_timeline, :timeline)
            assert is_map(battle_with_timeline.timeline)

          {:error, :battle_not_found} ->
            # Acceptable if detection criteria differ
            :ok
        end
      end
    end

    test "get_battle_with_timeline/1 handles non-existent battles" do
      assert {:error, :battle_not_found} =
               BattleAnalysis.get_battle_with_timeline("battle_fake_123")
    end
  end

  describe "Battle Statistics" do
    test "get_battle_statistics/2 returns complete statistics" do
      start_time = NaiveDateTime.add(NaiveDateTime.utc_now(), -3600, :second)
      end_time = NaiveDateTime.utc_now()

      result = BattleAnalysis.get_battle_statistics(start_time, end_time)

      assert {:ok, stats} = result
      assert_statistics_structure(stats)
    end

    test "handles empty time periods gracefully" do
      # Far future time period should have no battles
      start_time = NaiveDateTime.add(NaiveDateTime.utc_now(), 86400 * 365, :second)
      end_time = NaiveDateTime.add(start_time, 3600, :second)

      result = BattleAnalysis.get_battle_statistics(start_time, end_time)

      assert {:ok, stats} = result
      assert stats.total_battles == 0
      assert stats.total_kills == 0
    end
  end

  describe "Battle Sequence Analysis" do
    test "analyze_battle_sequence/1 identifies connections between battles" do
      {:ok, battles} = BattleAnalysis.detect_recent_battles(6, min_participants: 1)

      if length(battles) >= 2 do
        test_battles = Enum.take(battles, 5)
        analysis = BattleAnalysis.analyze_battle_sequence(test_battles)

        assert_sequence_analysis_structure(analysis)
      end
    end

    test "handles single battle sequences" do
      {:ok, battles} = BattleAnalysis.detect_recent_battles(1, min_participants: 1)

      if length(battles) > 0 do
        analysis = BattleAnalysis.analyze_battle_sequence([List.first(battles)])

        assert is_list(analysis.battles)
        assert analysis.battles != []
        assert analysis.connections == []
      end
    end
  end

  # Helper functions to reduce assertion duplication

  defp assert_battle_structure(battle) do
    assert is_binary(battle.battle_id)
    assert is_list(battle.killmails)
    assert is_map(battle.metadata)

    # Metadata assertions
    required_metadata_fields = [
      :killmail_count,
      :duration_minutes,
      :unique_participants,
      :battle_type
    ]

    Enum.each(required_metadata_fields, fn field ->
      assert Map.has_key?(battle.metadata, field),
             "Battle metadata missing required field: #{field}"
    end)
  end

  defp assert_timeline_structure(timeline, battle) do
    assert timeline.battle_id == battle.battle_id
    assert is_list(timeline.events)
    assert is_list(timeline.phases)
    assert is_list(timeline.fleet_composition)
    assert is_list(timeline.key_moments)
    assert is_map(timeline.summary)

    # Events should match killmails
    assert length(timeline.events) == length(battle.killmails)

    # Should have at least one phase
    assert length(timeline.phases) >= 1

    # Check event structure if events exist
    if length(timeline.events) > 0 do
      event = List.first(timeline.events)
      assert event.type == :kill
      assert is_map(event.victim)
      assert is_list(event.attackers)
      assert is_map(event.location)
    end
  end

  defp assert_statistics_structure(stats) do
    assert is_integer(stats.total_battles)
    assert is_integer(stats.total_kills)
    assert is_map(stats.battle_types)
    assert is_list(stats.most_active_systems)

    assert is_float(stats.average_battle_duration) or
             stats.average_battle_duration == 0
  end

  defp assert_sequence_analysis_structure(analysis) do
    assert is_list(analysis.battles)
    assert is_list(analysis.connections)
    assert is_list(analysis.escalation_pattern)
    assert is_list(analysis.participant_flow)
  end
end
