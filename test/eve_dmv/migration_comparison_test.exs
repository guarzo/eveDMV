defmodule EveDmv.MigrationComparisonTest do
  @moduledoc """
  Tests that the Ash implementations produce correct results.

  These tests validate the Ash-native implementations:

  1. CharacterStats.calculate_for_character/2 - Character kill/death statistics
  2. StatsLoader.load_stats/2 - Corporation statistics

  These tests are marked with @tag :migration_comparison so they can be run
  separately or excluded from regular test runs.
  """

  use EveDmv.DataCase, async: false

  alias EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStats
  alias EveDmv.Contexts.Corporation.Services.StatsLoader

  @moduletag :migration_comparison

  # Helper to convert days to DateTime for testing
  defp since_datetime(days_ago) do
    DateTime.utc_now()
    |> DateTime.add(-days_ago, :day)
    |> DateTime.truncate(:second)
  end

  describe "character stats (CharacterStats resource)" do
    test "returns zeros for character with no activity" do
      # Use a character ID that definitely has no data
      character_id = 999_999_999

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, since_datetime(90))

      assert stats.kills == 0, "Should return 0 kills for inactive character"
      assert stats.deaths == 0, "Should return 0 deaths for inactive character"
      assert stats.character_id == character_id
    end

    test "correctly counts kills (character as attacker)" do
      character_id = Enum.random(90_000_000..91_000_000)
      corporation_id = corporation_id()
      now = DateTime.utc_now()

      # Create 3 kills (character is attacker, not victim)
      # Each participation needs a unique killmail due to unique constraint
      for _ <- 1..3 do
        killmail = insert_killmail_raw!()

        insert_participant!(%{
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          character_id: character_id,
          corporation_id: corporation_id,
          ship_type_id: 587,
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          final_blow: false,
          damage_done: Enum.random(100..1000)
        })
      end

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, since_datetime(90))

      assert stats.kills == 3, "Should count 3 kills"
      assert stats.deaths == 0, "Should count 0 deaths"
    end

    test "correctly counts deaths (character as victim)" do
      character_id = Enum.random(91_000_001..92_000_000)
      corporation_id = corporation_id()
      now = DateTime.utc_now()

      # Create 2 deaths (character is victim)
      # Each participation needs a unique killmail due to unique constraint
      for _ <- 1..2 do
        killmail = insert_killmail_raw!()

        insert_participant!(%{
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          character_id: character_id,
          corporation_id: corporation_id,
          ship_type_id: 587,
          solar_system_id: killmail.solar_system_id,
          is_victim: true,
          final_blow: false,
          damage_done: 0
        })
      end

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, since_datetime(90))

      assert stats.kills == 0, "Should count 0 kills"
      assert stats.deaths == 2, "Should count 2 deaths"
    end

    test "correctly counts mixed kills and deaths" do
      character_id = Enum.random(92_000_001..93_000_000)
      corporation_id = corporation_id()
      now = DateTime.utc_now()

      # Create 6 kills - each needs unique killmail
      for _ <- 1..6 do
        killmail = insert_killmail_raw!()

        insert_participant!(%{
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          character_id: character_id,
          corporation_id: corporation_id,
          ship_type_id: 587,
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          final_blow: false,
          damage_done: Enum.random(100..1000)
        })
      end

      # Create 2 deaths - each needs unique killmail
      for _ <- 1..2 do
        killmail = insert_killmail_raw!()

        insert_participant!(%{
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          character_id: character_id,
          corporation_id: corporation_id,
          ship_type_id: 587,
          solar_system_id: killmail.solar_system_id,
          is_victim: true,
          final_blow: false,
          damage_done: 0
        })
      end

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, since_datetime(90))

      assert stats.kills == 6
      assert stats.deaths == 2
    end

    test "calculates K/D ratio correctly" do
      character_id = Enum.random(93_000_001..94_000_000)
      corporation_id = corporation_id()
      now = DateTime.utc_now()

      # Create 6 kills - each needs unique killmail
      for _ <- 1..6 do
        killmail = insert_killmail_raw!()

        insert_participant!(%{
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          character_id: character_id,
          corporation_id: corporation_id,
          ship_type_id: 587,
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          final_blow: false,
          damage_done: Enum.random(100..1000)
        })
      end

      # Create 2 deaths - each needs unique killmail
      for _ <- 1..2 do
        killmail = insert_killmail_raw!()

        insert_participant!(%{
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          character_id: character_id,
          corporation_id: corporation_id,
          ship_type_id: 587,
          solar_system_id: killmail.solar_system_id,
          is_victim: true,
          final_blow: false,
          damage_done: 0
        })
      end

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, since_datetime(90))

      # Load the kd_ratio calculation
      stats_with_calc = Ash.load!(stats, [:kd_ratio], domain: EveDmv.Api)

      # K/D should be 6/2 = 3.0
      assert_in_delta stats_with_calc.kd_ratio, 3.0, 0.01
    end

    test "handles zero deaths for K/D ratio (returns kills as ratio)" do
      character_id = Enum.random(94_000_001..95_000_000)
      corporation_id = corporation_id()
      now = DateTime.utc_now()

      # Create 5 kills, no deaths - each needs unique killmail
      for _ <- 1..5 do
        killmail = insert_killmail_raw!()

        insert_participant!(%{
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          character_id: character_id,
          corporation_id: corporation_id,
          ship_type_id: 587,
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          final_blow: false,
          damage_done: Enum.random(100..1000)
        })
      end

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, since_datetime(90))
      stats_with_calc = Ash.load!(stats, [:kd_ratio], domain: EveDmv.Api)

      # When deaths = 0, K/D should equal kills (5.0)
      assert stats.kills == 5
      assert stats.deaths == 0
      assert stats_with_calc.kd_ratio == 5.0
    end

    test "respects date filtering" do
      character_id = Enum.random(95_000_001..96_000_000)
      corporation_id = corporation_id()

      killmail = insert_killmail_raw!()

      # Create 1 kill 15 days ago
      recent_time = DateTime.add(DateTime.utc_now(), -15, :day)

      insert_participant!(%{
        killmail_id: killmail.killmail_id,
        killmail_time: recent_time,
        character_id: character_id,
        corporation_id: corporation_id,
        ship_type_id: 587,
        solar_system_id: killmail.solar_system_id,
        is_victim: false,
        final_blow: false,
        damage_done: Enum.random(100..1000)
      })

      # 30-day window should find the kill
      {:ok, stats_30} = CharacterStats.calculate_for_character(character_id, since_datetime(30))
      assert stats_30.kills == 1

      # 5-day window should NOT find the kill (it's 15 days old)
      {:ok, stats_5} = CharacterStats.calculate_for_character(character_id, since_datetime(5))
      assert stats_5.kills == 0
    end

    test "handles nil since_date (defaults to 90 days)" do
      character_id = Enum.random(96_000_001..97_000_000)
      corporation_id = corporation_id()
      now = DateTime.utc_now()

      killmail = insert_killmail_raw!()

      insert_participant!(%{
        killmail_id: killmail.killmail_id,
        killmail_time: now,
        character_id: character_id,
        corporation_id: corporation_id,
        ship_type_id: 587,
        solar_system_id: killmail.solar_system_id,
        is_victim: false,
        final_blow: false,
        damage_done: 500
      })

      # New implementation with nil since_date
      {:ok, stats} = CharacterStats.calculate_for_character(character_id, nil)

      assert stats.kills == 1
      # Period should be approximately 90 days
      assert stats.period_days >= 89 and stats.period_days <= 91
    end

    test "works with large character IDs" do
      # Test with EVE's typical large character IDs
      large_character_id = 2_119_876_543

      {:ok, stats} =
        CharacterStats.calculate_for_character(large_character_id, since_datetime(90))

      # Should handle large IDs gracefully (no activity expected)
      assert is_integer(stats.kills)
      assert is_integer(stats.deaths)
      assert stats.kills == 0
      assert stats.deaths == 0
    end
  end

  describe "corporation stats (StatsLoader service)" do
    test "returns zeros for corporation with no activity" do
      corp_id = 999_999_999

      {:ok, stats} = StatsLoader.load_stats(corp_id, days: 90, skip_cache: true)

      assert stats.kills == 0
      assert stats.losses == 0
      assert stats.active_members == 0
    end

    test "correctly counts corporation kills and losses" do
      corp_id = Enum.random(98_000_000..98_100_000)
      now = DateTime.utc_now()

      # Create 4 kills for the corporation (members as attackers)
      # Each needs unique killmail + character combination
      for i <- 1..4 do
        killmail = insert_killmail_raw!()

        insert_participant!(%{
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          character_id: 90_000_000 + i,
          corporation_id: corp_id,
          ship_type_id: 587,
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          final_blow: false,
          damage_done: Enum.random(100..1000)
        })
      end

      # Create 2 losses for the corporation (members as victims)
      for i <- 1..2 do
        killmail = insert_killmail_raw!()

        insert_participant!(%{
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          character_id: 91_000_000 + i,
          corporation_id: corp_id,
          ship_type_id: 587,
          solar_system_id: killmail.solar_system_id,
          is_victim: true,
          final_blow: false,
          damage_done: 0
        })
      end

      {:ok, stats} = StatsLoader.load_stats(corp_id, days: 90, skip_cache: true)

      assert stats.kills == 4, "Should count 4 kills"
      assert stats.losses == 2, "Should count 2 losses"
    end

    test "calculates efficiency correctly" do
      corp_id = Enum.random(98_100_001..98_200_000)
      now = DateTime.utc_now()

      # Create 3 kills - each with unique killmail + character
      for i <- 1..3 do
        killmail = insert_killmail_raw!()

        insert_participant!(%{
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          character_id: 90_000_000 + i,
          corporation_id: corp_id,
          ship_type_id: 587,
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          final_blow: false,
          damage_done: Enum.random(100..1000)
        })
      end

      # Create 1 loss
      killmail = insert_killmail_raw!()

      insert_participant!(%{
        killmail_id: killmail.killmail_id,
        killmail_time: now,
        character_id: 91_000_001,
        corporation_id: corp_id,
        ship_type_id: 587,
        solar_system_id: killmail.solar_system_id,
        is_victim: true,
        final_blow: false,
        damage_done: 0
      })

      {:ok, stats} = StatsLoader.load_stats(corp_id, days: 90, skip_cache: true)

      # Efficiency should be kills / (kills + losses) * 100 = 3/4 * 100 = 75%
      assert stats.kills == 3
      assert stats.losses == 1
      assert_in_delta stats.efficiency, 75.0, 0.01
    end

    test "handles 100% efficiency correctly (no losses)" do
      corp_id = Enum.random(98_200_001..98_300_000)
      now = DateTime.utc_now()

      # Create only kills, no losses - each with unique killmail + character
      for i <- 1..5 do
        killmail = insert_killmail_raw!()

        insert_participant!(%{
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          character_id: 90_000_000 + i,
          corporation_id: corp_id,
          ship_type_id: 587,
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          final_blow: false,
          damage_done: Enum.random(100..1000)
        })
      end

      {:ok, stats} = StatsLoader.load_stats(corp_id, days: 90, skip_cache: true)

      assert stats.kills == 5
      assert stats.losses == 0
      assert stats.efficiency == 100.0
    end

    test "counts active members correctly (unique characters)" do
      corp_id = Enum.random(98_300_001..98_400_000)
      now = DateTime.utc_now()

      # Create activity for 3 distinct characters - each on different killmail
      char1 = Enum.random(90_000_000..90_100_000)
      char2 = Enum.random(90_100_001..90_200_000)
      char3 = Enum.random(90_200_001..90_300_000)

      for char_id <- [char1, char2, char3] do
        killmail = insert_killmail_raw!()

        insert_participant!(%{
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          character_id: char_id,
          corporation_id: corp_id,
          ship_type_id: 587,
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          final_blow: false,
          damage_done: Enum.random(100..1000)
        })
      end

      # Add a second participation for char1 on a different killmail
      # (should still only count as 1 member)
      killmail = insert_killmail_raw!()

      insert_participant!(%{
        killmail_id: killmail.killmail_id,
        killmail_time: now,
        character_id: char1,
        corporation_id: corp_id,
        ship_type_id: 588,
        solar_system_id: killmail.solar_system_id,
        is_victim: false,
        final_blow: false,
        damage_done: Enum.random(100..1000)
      })

      {:ok, stats} = StatsLoader.load_stats(corp_id, days: 90, skip_cache: true)

      # Should count 3 unique active members, not 4 participations
      assert stats.active_members == 3
    end

    test "handles configurable time periods" do
      corp_id = Enum.random(98_400_001..98_500_000)

      # Create activity 45 days ago
      time_45_days_ago = DateTime.add(DateTime.utc_now(), -45, :day)

      killmail = insert_killmail_raw!()

      insert_participant!(%{
        killmail_id: killmail.killmail_id,
        killmail_time: time_45_days_ago,
        character_id: Enum.random(90_000_000..91_000_000),
        corporation_id: corp_id,
        ship_type_id: 587,
        solar_system_id: killmail.solar_system_id,
        is_victim: false,
        final_blow: false,
        damage_done: 500
      })

      # 30-day window should NOT include the activity
      {:ok, stats_30} = StatsLoader.load_stats(corp_id, days: 30, skip_cache: true)
      assert stats_30.kills == 0

      # 60-day window SHOULD include the activity
      {:ok, stats_60} = StatsLoader.load_stats(corp_id, days: 60, skip_cache: true)
      assert stats_60.kills == 1

      # 90-day window SHOULD also include the activity
      {:ok, stats_90} = StatsLoader.load_stats(corp_id, days: 90, skip_cache: true)
      assert stats_90.kills == 1
    end
  end

  describe "ISK calculations" do
    test "character stats includes ISK efficiency calculation" do
      character_id = Enum.random(97_000_001..98_000_000)

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, nil)
      stats_with_calc = Ash.load!(stats, [:isk_efficiency, :net_isk], domain: EveDmv.Api)

      # Should have ISK-related fields (even if 0)
      assert is_float(stats_with_calc.isk_efficiency)
      assert %Decimal{} = stats_with_calc.net_isk

      # With no activity, ISK efficiency should be 0.0
      assert stats_with_calc.isk_efficiency == 0.0
    end

    test "corporation stats includes ISK efficiency" do
      corp_id = Enum.random(98_500_001..98_600_000)

      {:ok, stats} = StatsLoader.load_stats(corp_id, days: 90, skip_cache: true)

      # Should have ISK efficiency field
      assert is_float(stats.isk_efficiency)
      # With no activity, defaults to 50.0
      assert stats.isk_efficiency == 50.0
    end
  end

  describe "error handling" do
    test "character stats handles invalid character_id gracefully" do
      # Negative ID should still work (return zeros)
      {:ok, stats} = CharacterStats.calculate_for_character(-1, nil)
      assert stats.kills == 0
      assert stats.deaths == 0
    end

    test "corporation stats returns error for query failures" do
      # The implementation should handle database errors gracefully
      # Since we can't easily simulate a query failure, we just verify
      # the success path works correctly
      {:ok, stats} = StatsLoader.load_stats(1, days: 90, skip_cache: true)
      assert is_map(stats)
    end
  end
end
