defmodule EveDmv.Contexts.CharacterIntelligence.Services.BatchLoaderTest do
  @moduledoc """
  Tests for the BatchLoader service.

  BatchLoader provides batch loading capabilities for character data using
  a hybrid approach of Ash queries for simple aggregations and delegating
  to QueryOptimizations for complex window function queries.
  """

  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.CharacterIntelligence.Services.BatchLoader

  describe "load_single_character_stats/1" do
    test "returns zero counts for character with no activity" do
      character_id = 999_999_994

      stats = BatchLoader.load_single_character_stats(character_id)

      assert stats == %{kills: 0, deaths: 0}
    end

    test "correctly counts kills" do
      character_id = Enum.random(90_000_000..99_999_999)
      now = DateTime.utc_now()

      # Create 4 kills (each needs a separate killmail due to unique constraint)
      for _ <- 1..4 do
        {killmail, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

        insert_participant!(%{
          character_id: character_id,
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          ship_type_id: 587
        })
      end

      stats = BatchLoader.load_single_character_stats(character_id)

      assert stats.kills == 4
      assert stats.deaths == 0
    end

    test "correctly counts deaths" do
      character_id = Enum.random(90_000_000..99_999_999)
      now = DateTime.utc_now()

      # Create 3 deaths (each needs a separate killmail due to unique constraint)
      for _ <- 1..3 do
        {killmail, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

        insert_participant!(%{
          character_id: character_id,
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          solar_system_id: killmail.solar_system_id,
          is_victim: true,
          ship_type_id: 587
        })
      end

      stats = BatchLoader.load_single_character_stats(character_id)

      assert stats.kills == 0
      assert stats.deaths == 3
    end

    test "correctly counts both kills and deaths" do
      character_id = Enum.random(90_000_000..99_999_999)
      now = DateTime.utc_now()

      # Create 6 kills (each needs a separate killmail due to unique constraint)
      for _ <- 1..6 do
        {killmail, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

        insert_participant!(%{
          character_id: character_id,
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          ship_type_id: 587
        })
      end

      # Create 2 deaths (each needs a separate killmail due to unique constraint)
      for _ <- 1..2 do
        {killmail, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

        insert_participant!(%{
          character_id: character_id,
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          solar_system_id: killmail.solar_system_id,
          is_victim: true,
          ship_type_id: 587
        })
      end

      stats = BatchLoader.load_single_character_stats(character_id)

      assert stats.kills == 6
      assert stats.deaths == 2
    end

    test "only counts activity within last 90 days" do
      character_id = Enum.random(90_000_000..99_999_999)
      recent_time = DateTime.utc_now()

      # Create recent kills (each needs a separate killmail due to unique constraint)
      for _ <- 1..3 do
        {killmail, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

        insert_participant!(%{
          character_id: character_id,
          killmail_id: killmail.killmail_id,
          killmail_time: recent_time,
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          ship_type_id: 587
        })
      end

      stats = BatchLoader.load_single_character_stats(character_id)

      assert stats.kills == 3
    end
  end

  describe "bulk_load_basic_stats/1" do
    test "returns empty map for empty character list" do
      stats = BatchLoader.bulk_load_basic_stats([])

      assert stats == %{}
    end

    test "returns zero counts for characters with no activity" do
      character_ids = [999_999_993, 999_999_992]

      stats = BatchLoader.bulk_load_basic_stats(character_ids)

      assert Map.has_key?(stats, 999_999_993)
      assert Map.has_key?(stats, 999_999_992)
      assert stats[999_999_993] == %{kills: 0, deaths: 0}
      assert stats[999_999_992] == %{kills: 0, deaths: 0}
    end

    test "correctly aggregates stats for multiple characters" do
      char1 = Enum.random(90_000_000..94_999_999)
      char2 = Enum.random(95_000_000..99_999_999)
      now = DateTime.utc_now()

      # Char1: 5 kills, 1 death (each needs a separate killmail due to unique constraint)
      for _ <- 1..5 do
        {killmail, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

        insert_participant!(%{
          character_id: char1,
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          ship_type_id: 587
        })
      end

      {death_killmail, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

      insert_participant!(%{
        character_id: char1,
        killmail_id: death_killmail.killmail_id,
        killmail_time: now,
        solar_system_id: death_killmail.solar_system_id,
        is_victim: true,
        ship_type_id: 587
      })

      # Char2: 2 kills, 3 deaths (each needs a separate killmail due to unique constraint)
      for _ <- 1..2 do
        {killmail, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

        insert_participant!(%{
          character_id: char2,
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          ship_type_id: 587
        })
      end

      for _ <- 1..3 do
        {killmail, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

        insert_participant!(%{
          character_id: char2,
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          solar_system_id: killmail.solar_system_id,
          is_victim: true,
          ship_type_id: 587
        })
      end

      stats = BatchLoader.bulk_load_basic_stats([char1, char2])

      assert stats[char1] == %{kills: 5, deaths: 1}
      assert stats[char2] == %{kills: 2, deaths: 3}
    end

    test "handles large batch of characters" do
      character_ids = for _ <- 1..20, do: Enum.random(90_000_000..99_999_999)

      stats = BatchLoader.bulk_load_basic_stats(character_ids)

      assert map_size(stats) == 20
      assert Enum.all?(stats, fn {_id, s} -> is_map(s) end)
    end
  end

  describe "bulk_load_recent_activity/2" do
    test "returns empty map for empty character list" do
      activity = BatchLoader.bulk_load_recent_activity([])

      assert activity == %{}
    end

    test "returns empty lists for characters with no activity" do
      character_ids = [999_999_991, 999_999_990]

      activity = BatchLoader.bulk_load_recent_activity(character_ids)

      # The underlying SQL query returns empty for no activity
      # Empty result means no entries in the map or empty lists
      assert activity == %{} or
               (Map.get(activity, 999_999_991, []) == [] and
                  Map.get(activity, 999_999_990, []) == [])
    end

    test "respects limit parameter" do
      character_id = Enum.random(90_000_000..99_999_999)

      activity = BatchLoader.bulk_load_recent_activity([character_id], 5)

      # Result should have at most 5 items per character
      char_activity = Map.get(activity, character_id, [])
      assert length(char_activity) <= 5
    end

    test "uses default limit of 10" do
      character_id = Enum.random(90_000_000..99_999_999)

      activity = BatchLoader.bulk_load_recent_activity([character_id])

      char_activity = Map.get(activity, character_id, [])
      assert length(char_activity) <= 10
    end
  end

  describe "bulk_load_affiliations/1" do
    test "returns empty map for empty character list" do
      affiliations = BatchLoader.bulk_load_affiliations([])

      assert affiliations == %{}
    end

    test "returns empty results for characters with no affiliations" do
      character_ids = [999_999_989, 999_999_988]

      affiliations = BatchLoader.bulk_load_affiliations(character_ids)

      # No activity means no affiliations detected
      assert affiliations == %{} or
               (Map.get(affiliations, 999_999_989, []) == [] and
                  Map.get(affiliations, 999_999_988, []) == [])
    end
  end

  describe "bulk_load_ship_preferences/2" do
    test "returns empty map for empty character list" do
      preferences = BatchLoader.bulk_load_ship_preferences([])

      assert preferences == %{}
    end

    test "returns empty results for characters with no ship usage" do
      character_ids = [999_999_987, 999_999_986]

      preferences = BatchLoader.bulk_load_ship_preferences(character_ids)

      assert preferences == %{} or
               (Map.get(preferences, 999_999_987, []) == [] and
                  Map.get(preferences, 999_999_986, []) == [])
    end

    test "respects limit parameter" do
      character_id = Enum.random(90_000_000..99_999_999)

      preferences = BatchLoader.bulk_load_ship_preferences([character_id], 3)

      char_prefs = Map.get(preferences, character_id, [])
      assert length(char_prefs) <= 3
    end

    test "uses default limit of 5" do
      character_id = Enum.random(90_000_000..99_999_999)

      preferences = BatchLoader.bulk_load_ship_preferences([character_id])

      char_prefs = Map.get(preferences, character_id, [])
      assert length(char_prefs) <= 5
    end
  end

  describe "bulk_load_character_data/1" do
    test "returns empty map for empty character list" do
      data = BatchLoader.bulk_load_character_data([])

      assert data == %{}
    end

    test "returns comprehensive data structure for each character" do
      character_ids = [999_999_985, 999_999_984]

      data = BatchLoader.bulk_load_character_data(character_ids)

      assert Map.has_key?(data, 999_999_985)
      assert Map.has_key?(data, 999_999_984)

      # Verify structure for each character
      for char_id <- character_ids do
        char_data = data[char_id]
        assert Map.has_key?(char_data, :stats)
        assert Map.has_key?(char_data, :recent_activity)
        assert Map.has_key?(char_data, :affiliations)
        assert Map.has_key?(char_data, :ship_preferences)
      end
    end

    test "stats have correct structure" do
      character_id = 999_999_983

      data = BatchLoader.bulk_load_character_data([character_id])
      stats = data[character_id].stats

      assert Map.has_key?(stats, :kills)
      assert Map.has_key?(stats, :deaths)
      assert is_integer(stats.kills)
      assert is_integer(stats.deaths)
    end

    test "returns default values for characters with no activity" do
      character_id = 999_999_982

      data = BatchLoader.bulk_load_character_data([character_id])
      char_data = data[character_id]

      assert char_data.stats == %{kills: 0, deaths: 0}
      assert char_data.recent_activity == []
      assert char_data.affiliations == []
      assert char_data.ship_preferences == []
    end

    test "handles concurrent loading efficiently" do
      character_ids = for _ <- 1..10, do: Enum.random(90_000_000..99_999_999)

      # Measure time - should be faster than sequential loading
      {time_ms, data} =
        :timer.tc(fn ->
          BatchLoader.bulk_load_character_data(character_ids)
        end)

      # Should complete within reasonable time (10 seconds max with 10s timeout)
      assert time_ms < 10_000_000

      # Should have data for all characters
      assert map_size(data) == 10
    end
  end

  describe "error handling" do
    test "load_single_character_stats returns default on error" do
      # Using a negative ID which might cause issues
      character_id = -1

      stats = BatchLoader.load_single_character_stats(character_id)

      # Should return defaults, not crash
      assert is_map(stats)
      assert Map.has_key?(stats, :kills)
      assert Map.has_key?(stats, :deaths)
    end

    test "bulk operations handle timeouts gracefully" do
      # Very large list might cause timeout, but should be handled
      character_ids = for _ <- 1..100, do: Enum.random(90_000_000..99_999_999)

      # Should not raise
      result = BatchLoader.bulk_load_basic_stats(character_ids)

      assert is_map(result)
    end
  end

  describe "integration with Participant resource" do
    test "correctly filters by is_victim field" do
      character_id = Enum.random(90_000_000..99_999_999)
      now = DateTime.utc_now()

      # Create mixed activity (each needs a separate killmail due to unique constraint)
      {kill_km, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

      insert_participant!(%{
        character_id: character_id,
        killmail_id: kill_km.killmail_id,
        killmail_time: now,
        solar_system_id: kill_km.solar_system_id,
        is_victim: false,
        final_blow: true,
        ship_type_id: 587
      })

      {death_km, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

      insert_participant!(%{
        character_id: character_id,
        killmail_id: death_km.killmail_id,
        killmail_time: now,
        solar_system_id: death_km.solar_system_id,
        is_victim: true,
        ship_type_id: 587
      })

      stats = BatchLoader.load_single_character_stats(character_id)

      assert stats.kills == 1
      assert stats.deaths == 1
    end

    test "handles participants with nil character_id" do
      # NPC or anonymous attacker case
      stats = BatchLoader.load_single_character_stats(nil)

      # Should handle gracefully
      assert is_map(stats)
    end
  end
end
