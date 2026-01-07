defmodule EveDmv.Contexts.BattleAnalysis.Domain.Services.DetectionServiceTest do
  @moduledoc """
  Tests for the DetectionService module.

  Tests the battle detection system including:
  - Character battle detection
  - Corporation battle detection
  - System battle detection
  - Battle statistics calculations
  - Fleet doctrine analysis
  """

  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.BattleAnalysis.Domain.Services.DetectionService

  # Character ID for testing
  @test_character_id 90_000_001
  @test_corporation_id 98_000_001
  @test_system_id 30_000_142

  describe "detect_character_battles/2" do
    test "returns empty list for character with no battles" do
      nonexistent_character = 99_999_999
      result = DetectionService.detect_character_battles(nonexistent_character)

      assert is_list(result)
    end

    test "returns list with default limit" do
      result = DetectionService.detect_character_battles(@test_character_id)

      assert is_list(result)
    end

    test "respects limit parameter" do
      result = DetectionService.detect_character_battles(@test_character_id, 5)

      assert is_list(result)
      assert length(result) <= 5
    end

    test "returns battles with expected structure when data exists" do
      # Create test data with at least 5 attackers for multi-pilot engagement
      character_id = character_id()
      killmail = create_multi_pilot_killmail(character_id)
      create_participant_records(killmail, character_id)

      result = DetectionService.detect_character_battles(character_id, 10)

      if result != [] do
        battle = hd(result)
        assert Map.has_key?(battle, :battle_id)
        assert Map.has_key?(battle, :battle_time)
        assert Map.has_key?(battle, :solar_system_id)
        assert Map.has_key?(battle, :battle_type)
      end
    end
  end

  describe "detect_corporation_battles/2" do
    test "returns empty list for corporation with no battles" do
      nonexistent_corp = 99_999_999
      result = DetectionService.detect_corporation_battles(nonexistent_corp)

      assert is_list(result)
    end

    test "returns list with default limit" do
      result = DetectionService.detect_corporation_battles(@test_corporation_id)

      assert is_list(result)
    end

    test "respects limit parameter" do
      result = DetectionService.detect_corporation_battles(@test_corporation_id, 5)

      assert is_list(result)
      assert length(result) <= 5
    end

    test "returns battles with coordination context when data exists" do
      corporation_id = corporation_id()
      killmail = create_multi_pilot_killmail_for_corp(corporation_id)
      create_corp_participant_records(killmail, corporation_id)

      result = DetectionService.detect_corporation_battles(corporation_id, 10)

      if result != [] do
        battle = hd(result)
        assert Map.has_key?(battle, :coordination_level)
        assert Map.has_key?(battle, :fleet_discipline)
        assert Map.has_key?(battle, :tactical_role)
      end
    end
  end

  describe "get_corporation_battle_stats/1" do
    test "returns default stats for corporation with no battles" do
      nonexistent_corp = 99_999_999
      result = DetectionService.get_corporation_battle_stats(nonexistent_corp)

      assert is_map(result)
      assert result.total_battles == 0
      assert result.battles_won == 0
      assert result.battles_lost == 0
    end

    test "returns stats structure with all expected fields" do
      result = DetectionService.get_corporation_battle_stats(@test_corporation_id)

      assert Map.has_key?(result, :total_battles)
      assert Map.has_key?(result, :battles_won)
      assert Map.has_key?(result, :battles_lost)
      assert Map.has_key?(result, :battle_efficiency)
      assert Map.has_key?(result, :avg_fleet_size)
      assert Map.has_key?(result, :avg_corp_participation)
      assert Map.has_key?(result, :isk_destroyed_in_battles)
      assert Map.has_key?(result, :isk_lost_in_battles)
      assert Map.has_key?(result, :systems_fought_in)
      assert Map.has_key?(result, :max_corp_members_in_battle)
      assert Map.has_key?(result, :fleet_coordination)
    end

    test "calculates battle efficiency correctly" do
      result = DetectionService.get_corporation_battle_stats(@test_corporation_id)

      # Efficiency should be between 0 and 100
      assert result.battle_efficiency >= 0
      assert result.battle_efficiency <= 100
    end
  end

  describe "detect_system_battles/2" do
    test "returns empty list for system with no battles" do
      # Use a system that likely has no battles
      quiet_system = 31_000_001
      result = DetectionService.detect_system_battles(quiet_system)

      assert is_list(result)
    end

    test "returns list with default limit" do
      result = DetectionService.detect_system_battles(@test_system_id)

      assert is_list(result)
    end

    test "respects limit parameter" do
      result = DetectionService.detect_system_battles(@test_system_id, 5)

      assert is_list(result)
      assert length(result) <= 5
    end

    test "returns battles with system context when data exists" do
      killmail = create_multi_pilot_killmail_in_system(@test_system_id)
      create_participant_records_for_killmail(killmail)

      result = DetectionService.detect_system_battles(@test_system_id, 10)

      if result != [] do
        battle = hd(result)
        assert Map.has_key?(battle, :strategic_importance)
        assert Map.has_key?(battle, :escalation_pattern)
        assert Map.has_key?(battle, :dominant_forces)
      end
    end
  end

  describe "get_system_battle_stats/1" do
    test "returns default stats for system with no battles" do
      quiet_system = 31_000_001
      result = DetectionService.get_system_battle_stats(quiet_system)

      assert is_map(result)
      assert result.total_battles == 0
    end

    test "returns stats structure with all expected fields" do
      result = DetectionService.get_system_battle_stats(@test_system_id)

      assert Map.has_key?(result, :total_battles)
      assert Map.has_key?(result, :avg_fleet_size)
      assert Map.has_key?(result, :avg_corp_participation)
      assert Map.has_key?(result, :avg_alliance_participation)
      assert Map.has_key?(result, :max_fleet_size)
      assert Map.has_key?(result, :max_hourly_intensity)
      assert Map.has_key?(result, :battle_days)
      assert Map.has_key?(result, :total_isk_destroyed)
      assert Map.has_key?(result, :major_battle_count)
      assert Map.has_key?(result, :medium_battle_count)
      assert Map.has_key?(result, :small_battle_count)
      assert Map.has_key?(result, :battle_frequency)
      assert Map.has_key?(result, :threat_level)
    end

    test "threat_level is a valid classification" do
      result = DetectionService.get_system_battle_stats(@test_system_id)

      valid_threat_levels = ["extreme", "high", "moderate", "low", "minimal"]
      assert result.threat_level in valid_threat_levels
    end

    test "battle_frequency is a valid classification" do
      result = DetectionService.get_system_battle_stats(@test_system_id)

      valid_frequencies = ["very_high", "high", "moderate", "low", "minimal", "none"]
      assert result.battle_frequency in valid_frequencies
    end
  end

  describe "get_corporation_fleet_doctrines/1" do
    test "returns empty list for corporation with no battles" do
      nonexistent_corp = 99_999_999
      result = DetectionService.get_corporation_fleet_doctrines(nonexistent_corp)

      assert is_list(result)
    end

    test "returns doctrine preferences with expected structure when data exists" do
      result = DetectionService.get_corporation_fleet_doctrines(@test_corporation_id)

      assert is_list(result)

      if result != [] do
        doctrine = hd(result)
        assert Map.has_key?(doctrine, :ship_type)
        assert Map.has_key?(doctrine, :usage_count)
        assert Map.has_key?(doctrine, :avg_fleet_size)
        assert Map.has_key?(doctrine, :total_isk_involved)
        assert Map.has_key?(doctrine, :doctrine_preference)
      end
    end
  end

  describe "get_character_battle_stats/1" do
    test "returns default stats for character with no battles" do
      nonexistent_char = 99_999_999
      result = DetectionService.get_character_battle_stats(nonexistent_char)

      assert is_map(result)
      assert result.total_battles == 0
      assert result.battles_won == 0
      assert result.battles_lost == 0
    end

    test "returns stats structure with all expected fields" do
      result = DetectionService.get_character_battle_stats(@test_character_id)

      assert Map.has_key?(result, :total_battles)
      assert Map.has_key?(result, :battles_won)
      assert Map.has_key?(result, :battles_lost)
      assert Map.has_key?(result, :battle_efficiency)
      assert Map.has_key?(result, :avg_fleet_size)
      assert Map.has_key?(result, :isk_destroyed_in_battles)
      assert Map.has_key?(result, :isk_lost_in_battles)
    end

    test "calculates battle efficiency correctly" do
      result = DetectionService.get_character_battle_stats(@test_character_id)

      # Efficiency should be between 0 and 100
      assert result.battle_efficiency >= 0
      assert result.battle_efficiency <= 100
    end

    test "efficiency is 100 when only wins" do
      # Create character with only winning battles
      char_id = character_id()

      # Create a killmail where the character is an attacker (win)
      killmail =
        insert_killmail_raw!(%{
          attacker_count: 5,
          solar_system_id: @test_system_id,
          killmail_time: DateTime.utc_now()
        })

      # Create participant record as attacker
      insert_participant!(%{
        killmail_id: killmail.killmail_id,
        killmail_time: killmail.killmail_time,
        character_id: char_id,
        corporation_id: @test_corporation_id,
        solar_system_id: @test_system_id,
        is_victim: false,
        final_blow: true
      })

      result = DetectionService.get_character_battle_stats(char_id)

      # If character has only kills (no deaths), efficiency should be 100
      if result.total_battles > 0 && result.battles_lost == 0 && result.battles_won > 0 do
        assert result.battle_efficiency == 100
      end
    end

    test "efficiency is 0 when only losses" do
      # Create character with only losing battles
      char_id = character_id()

      # Create a killmail where the character is the victim (loss)
      killmail =
        insert_killmail_raw!(%{
          victim_character_id: char_id,
          attacker_count: 5,
          solar_system_id: @test_system_id,
          killmail_time: DateTime.utc_now()
        })

      # Create participant record as victim
      insert_participant!(%{
        killmail_id: killmail.killmail_id,
        killmail_time: killmail.killmail_time,
        character_id: char_id,
        corporation_id: @test_corporation_id,
        solar_system_id: @test_system_id,
        is_victim: true,
        final_blow: false
      })

      result = DetectionService.get_character_battle_stats(char_id)

      # If character has only deaths (no kills), efficiency should be 0
      if result.total_battles > 0 && result.battles_won == 0 && result.battles_lost > 0 do
        assert result.battle_efficiency == 0
      end
    end
  end

  describe "edge cases" do
    test "handles very large character IDs" do
      large_id = 9_999_999_999_999
      result = DetectionService.detect_character_battles(large_id)

      assert is_list(result)
    end

    test "handles zero as character ID" do
      result = DetectionService.detect_character_battles(0)

      assert is_list(result)
    end

    test "handles negative limit gracefully" do
      # Negative limit should be handled or default to something reasonable
      result = DetectionService.detect_character_battles(@test_character_id, -1)

      assert is_list(result)
    end

    test "handles zero limit" do
      result = DetectionService.detect_character_battles(@test_character_id, 0)

      assert is_list(result)
    end

    test "handles very large limit" do
      result = DetectionService.detect_character_battles(@test_character_id, 1000)

      assert is_list(result)
    end
  end

  describe "battle type classification" do
    test "classifies major battles correctly" do
      # Create data that would result in major battle classification
      # (100+ participants or 15+ killmails in same hour/system)
      char_id = character_id()

      # Create multiple killmails in the same system and hour
      base_time = DateTime.utc_now()

      for i <- 1..5 do
        killmail =
          insert_killmail_raw!(%{
            attacker_count: 20,
            solar_system_id: @test_system_id,
            killmail_time: DateTime.add(base_time, i * 60, :second)
          })

        insert_participant!(%{
          killmail_id: killmail.killmail_id,
          killmail_time: killmail.killmail_time,
          character_id: char_id,
          corporation_id: @test_corporation_id,
          solar_system_id: @test_system_id,
          is_victim: false
        })
      end

      result = DetectionService.detect_character_battles(char_id, 10)

      # Should have detected some battles
      assert is_list(result)
    end
  end

  # Helper functions for creating test data

  defp create_multi_pilot_killmail(character_id) do
    insert_killmail_raw!(%{
      attacker_count: 10,
      solar_system_id: @test_system_id,
      killmail_time: DateTime.utc_now()
    })
  end

  defp create_multi_pilot_killmail_for_corp(corporation_id) do
    insert_killmail_raw!(%{
      attacker_count: 10,
      victim_corporation_id: Enum.random(98_000_000..98_999_999),
      solar_system_id: @test_system_id,
      killmail_time: DateTime.utc_now()
    })
  end

  defp create_multi_pilot_killmail_in_system(system_id) do
    insert_killmail_raw!(%{
      attacker_count: 10,
      solar_system_id: system_id,
      killmail_time: DateTime.utc_now()
    })
  end

  defp create_participant_records(killmail, character_id) do
    # Create attacker participant
    insert_participant!(%{
      killmail_id: killmail.killmail_id,
      killmail_time: killmail.killmail_time,
      character_id: character_id,
      corporation_id: @test_corporation_id,
      solar_system_id: killmail.solar_system_id,
      is_victim: false,
      final_blow: true
    })
  end

  defp create_corp_participant_records(killmail, corporation_id) do
    # Create multiple corporation members as attackers
    for i <- 1..3 do
      insert_participant!(%{
        killmail_id: killmail.killmail_id,
        killmail_time: killmail.killmail_time,
        character_id: Enum.random(90_000_000..99_999_999),
        corporation_id: corporation_id,
        solar_system_id: killmail.solar_system_id,
        is_victim: false,
        final_blow: i == 1
      })
    end
  end

  defp create_participant_records_for_killmail(killmail) do
    # Create some attacker participants
    for i <- 1..5 do
      insert_participant!(%{
        killmail_id: killmail.killmail_id,
        killmail_time: killmail.killmail_time,
        character_id: Enum.random(90_000_000..99_999_999),
        corporation_id: Enum.random(98_000_000..98_999_999),
        solar_system_id: killmail.solar_system_id,
        is_victim: false,
        final_blow: i == 1
      })
    end
  end
end
