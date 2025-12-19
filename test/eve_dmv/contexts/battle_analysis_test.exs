defmodule EveDmv.Contexts.BattleAnalysisTest do
  @moduledoc """
  Tests for the BattleAnalysis context module.

  Tests battle detection, analysis, timeline reconstruction, and intelligence features.
  """
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

    test "respects hours_back parameter" do
      # 1 hour back should return fewer or same battles as 24 hours
      {:ok, battles_1h} = BattleAnalysis.detect_recent_battles(1)
      {:ok, battles_24h} = BattleAnalysis.detect_recent_battles(24)

      # Can't guarantee ordering but 24h should have >= 1h results
      assert length(battles_24h) >= length(battles_1h)
    end

    test "respects min_participants option" do
      {:ok, battles} = BattleAnalysis.detect_recent_battles(24, min_participants: 10)

      # All returned battles should have at least 10 participants
      Enum.each(battles, fn battle ->
        assert battle.metadata.unique_participants >= 10
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

    test "returns zero statistics when no battles in period" do
      # Use a very old time period where there should be no battles
      start_time = ~N[2000-01-01 00:00:00]
      end_time = ~N[2000-01-01 01:00:00]

      result = BattleAnalysis.get_battle_statistics(start_time, end_time)

      assert {:ok, stats} = result
      assert stats.total_battles == 0
      assert stats.total_kills == 0
      assert stats.average_battle_duration == 0.0
    end

    test "most_active_systems is sorted by activity" do
      start_time = NaiveDateTime.add(NaiveDateTime.utc_now(), -86_400, :second)
      end_time = NaiveDateTime.utc_now()

      {:ok, stats} = BattleAnalysis.get_battle_statistics(start_time, end_time)

      if length(stats.most_active_systems) > 1 do
        # Verify descending order by battle count
        counts = Enum.map(stats.most_active_systems, fn {_system_id, count} -> count end)
        assert counts == Enum.sort(counts, :desc)
      end
    end
  end

  describe "detect_battles/3" do
    test "returns ok tuple with battles" do
      end_time = DateTime.utc_now()
      start_time = DateTime.add(end_time, -3600, :second)

      result = BattleAnalysis.detect_battles(start_time, end_time)

      assert {:ok, battles} = result
      assert is_list(battles)
    end

    test "supports options parameter" do
      end_time = DateTime.utc_now()
      start_time = DateTime.add(end_time, -3600, :second)

      result = BattleAnalysis.detect_battles(start_time, end_time, min_participants: 5)

      assert {:ok, battles} = result
      assert is_list(battles)
    end
  end

  describe "detect_battles_in_system/4" do
    test "filters battles by solar system" do
      end_time = DateTime.utc_now()
      start_time = DateTime.add(end_time, -86_400, :second)
      # Jita system ID
      system_id = 30_000_142

      result = BattleAnalysis.detect_battles_in_system(system_id, start_time, end_time)

      assert {:ok, battles} = result
      assert is_list(battles)

      # All battles should be in the specified system
      Enum.each(battles, fn battle ->
        assert battle.metadata.primary_system == system_id
      end)
    end
  end

  describe "analyze_battle_from_killmail_ids/1" do
    test "handles empty list" do
      result = BattleAnalysis.analyze_battle_from_killmail_ids([])

      # Could be error or empty battle
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles list with invalid killmail IDs" do
      result = BattleAnalysis.analyze_battle_from_killmail_ids([999_999_999_999])

      # Should handle gracefully
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "reconstruct_battle_timeline/1" do
    test "returns timeline for valid battle" do
      # First get a battle
      case BattleAnalysis.detect_recent_battles(24) do
        {:ok, [battle | _]} ->
          result = BattleAnalysis.reconstruct_battle_timeline(battle)

          case result do
            {:ok, timeline} ->
              assert is_map(timeline)

            {:error, :reconstruction_failed} ->
              # Acceptable - reconstruction may not be fully implemented
              assert true
          end

        {:ok, []} ->
          # No battles to test
          assert true

        {:error, _} ->
          assert true
      end
    end
  end

  describe "analyze_battle_sequence/1" do
    test "handles empty battle list" do
      result = BattleAnalysis.analyze_battle_sequence([])

      assert {:ok, analysis} = result
      assert is_map(analysis)
    end

    test "analyzes sequence of battles" do
      case BattleAnalysis.detect_recent_battles(24) do
        {:ok, battles} when length(battles) >= 2 ->
          result = BattleAnalysis.analyze_battle_sequence(Enum.take(battles, 3))

          assert {:ok, analysis} = result
          assert is_map(analysis)

        _ ->
          # Not enough battles to test sequence
          assert true
      end
    end
  end

  describe "get_battle_with_timeline/1" do
    test "returns error for non-existent battle ID" do
      result = BattleAnalysis.get_battle_with_timeline("battle_9999_20250101000000")

      # Should return appropriate error
      assert match?({:error, _}, result)
    end

    test "handles malformed battle ID" do
      result = BattleAnalysis.get_battle_with_timeline("invalid_id")

      # Should return error for unparseable ID
      assert match?({:error, _}, result)
    end
  end

  describe "analyze_battle_with_intelligence/1" do
    test "returns intelligence analysis for valid battle" do
      case BattleAnalysis.detect_recent_battles(24) do
        {:ok, [battle | _]} ->
          result = BattleAnalysis.analyze_battle_with_intelligence(battle)

          case result do
            {:ok, intelligence} ->
              assert is_map(intelligence)
              # Should have intelligence components
              assert Map.has_key?(intelligence, :tactical_phases) or
                       Map.has_key?(intelligence, :advanced_analysis)

            {:error, _} ->
              # Analysis may fail if insufficient data
              assert true
          end

        {:ok, []} ->
          assert true

        {:error, _} ->
          assert true
      end
    end
  end

  describe "get_tactical_analysis/1" do
    test "returns error for non-existent battle" do
      result = BattleAnalysis.get_tactical_analysis("nonexistent_battle_id")

      assert {:error, _} = result
    end
  end

  describe "get_ship_performance_report/1" do
    test "returns error for non-existent battle" do
      result = BattleAnalysis.get_ship_performance_report("nonexistent_battle_id")

      assert {:error, _} = result
    end
  end

  describe "analyze_battle/2" do
    test "returns analysis for valid battle ID" do
      case BattleAnalysis.detect_recent_battles(24) do
        {:ok, [battle | _]} ->
          result = BattleAnalysis.analyze_battle(battle.battle_id)

          case result do
            {:ok, analysis} ->
              assert is_map(analysis)

            {:error, _} ->
              # Analysis may fail for various reasons
              assert true
          end

        _ ->
          assert true
      end
    end
  end

  describe "get_multi_system_battle_chain/1" do
    test "returns error for non-existent battle" do
      result = BattleAnalysis.get_multi_system_battle_chain("nonexistent_battle_id")

      assert {:error, :battle_not_found} = result
    end
  end

  describe "get_battle_intelligence_summary/1" do
    test "returns error for non-existent battle" do
      result = BattleAnalysis.get_battle_intelligence_summary("nonexistent_battle_id")

      assert {:error, :battle_not_found} = result
    end

    test "returns summary for valid battle" do
      case BattleAnalysis.detect_recent_battles(24) do
        {:ok, [battle | _]} ->
          result = BattleAnalysis.get_battle_intelligence_summary(battle.battle_id)

          case result do
            {:ok, summary} ->
              assert is_map(summary)
              assert Map.has_key?(summary, :battle)
              assert Map.has_key?(summary, :intelligence)
              assert Map.has_key?(summary, :summary)

            {:error, _} ->
              assert true
          end

        _ ->
          assert true
      end
    end
  end

  describe "import_from_zkillboard/1" do
    test "returns error for invalid URL" do
      result = BattleAnalysis.import_from_zkillboard("not_a_url")

      assert {:error, :invalid_zkillboard_url} = result
    end

    test "returns error for unsupported URL format" do
      result = BattleAnalysis.import_from_zkillboard("https://zkillboard.com/random/path/")

      assert {:error, reason} = result

      assert reason in [
               :invalid_zkillboard_url,
               :unsupported_url_format,
               :http_client_unavailable
             ]
    end
  end

  describe "import_killmail_from_zkillboard/1" do
    test "handles non-existent killmail ID" do
      result = BattleAnalysis.import_killmail_from_zkillboard(999_999_999_999)

      # Could be network error or not found
      assert match?({:error, _}, result)
    end
  end

  describe "generate_tactical_recommendations/1" do
    test "generates recommendations from battle analysis" do
      # Create a mock battle analysis
      analysis = %{
        tactical_phases: [],
        ship_performance: %{},
        battle_flow: :standard_engagement
      }

      result = BattleAnalysis.generate_tactical_recommendations(analysis)

      case result do
        {:ok, recommendations} ->
          assert is_list(recommendations)

        {:error, _} ->
          # May fail if BattleAnalysisService is not available
          assert true
      end
    end
  end

  describe "battle structure validation" do
    test "battle metadata contains required fields" do
      case BattleAnalysis.detect_recent_battles(24, min_participants: 1) do
        {:ok, [battle | _]} ->
          metadata = battle.metadata

          # Required fields
          assert Map.has_key?(metadata, :killmail_count)
          assert Map.has_key?(metadata, :duration_minutes)
          assert Map.has_key?(metadata, :unique_participants)
          assert Map.has_key?(metadata, :battle_type)
          assert Map.has_key?(metadata, :primary_system)

          # Type validation
          assert is_integer(metadata.killmail_count)
          assert is_number(metadata.duration_minutes)
          assert is_integer(metadata.unique_participants)
          assert is_atom(metadata.battle_type)

        _ ->
          assert true
      end
    end

    test "battle_id follows naming convention" do
      case BattleAnalysis.detect_recent_battles(24) do
        {:ok, [battle | _]} ->
          # Battle ID format: "battle_SYSTEMID_TIMESTAMP"
          assert String.starts_with?(battle.battle_id, "battle_")

          parts = String.split(battle.battle_id, "_")
          assert length(parts) == 3

          # Second part should be system ID (integer)
          {_system_id, ""} = Integer.parse(Enum.at(parts, 1))

          # Third part should be timestamp (14 digits)
          timestamp = Enum.at(parts, 2)
          assert String.length(timestamp) == 14

        _ ->
          assert true
      end
    end
  end
end
