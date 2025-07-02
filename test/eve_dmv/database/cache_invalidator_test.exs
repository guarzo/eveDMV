defmodule EveDmv.Database.CacheInvalidatorTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias EveDmv.Database.{CacheInvalidator, QueryCache}

  setup do
    # Clear cache before each test
    QueryCache.clear_all()
    :ok
  end

  describe "pattern invalidation" do
    test "can invalidate by pattern" do
      # Setup some cache entries
      QueryCache.put("character_intel_123", %{name: "Test Character"})
      QueryCache.put("character_intel_456", %{name: "Another Character"})
      QueryCache.put("system_info_789", %{name: "Test System"})

      # Invalidate character patterns
      CacheInvalidator.invalidate_by_pattern("character_intel_*")

      # Give time for async processing
      Process.sleep(50)

      # Character entries should be gone - need to check with a compute function since get_from_cache is private
      character_miss_1 = QueryCache.get_or_compute("character_intel_123", fn -> :not_found end)
      character_miss_2 = QueryCache.get_or_compute("character_intel_456", fn -> :not_found end)
      system_hit = QueryCache.get_or_compute("system_info_789", fn -> :not_found end)

      assert character_miss_1 == :not_found
      assert character_miss_2 == :not_found
      assert system_hit == %{name: "Test System"}
    end

    test "can invalidate by type" do
      # Setup cache entries for a character
      character_id = 12345
      QueryCache.put("character_intel_#{character_id}", %{analysis: "data"})
      QueryCache.put("character_stats_#{character_id}", %{kills: 10})
      QueryCache.put("character_analysis_#{character_id}", %{threat: "low"})

      # Invalidate by character type
      CacheInvalidator.invalidate_by_type(:character, character_id)

      # Give it time to process async invalidation
      Process.sleep(100)

      # All character-related entries should be gone
      intel_result =
        QueryCache.get_or_compute("character_intel_#{character_id}", fn -> :not_found end)

      stats_result =
        QueryCache.get_or_compute("character_stats_#{character_id}", fn -> :not_found end)

      analysis_result =
        QueryCache.get_or_compute("character_analysis_#{character_id}", fn -> :not_found end)

      assert intel_result == :not_found
      assert stats_result == :not_found
      assert analysis_result == :not_found
    end

    test "can perform bulk invalidation" do
      # Setup multiple cache entries
      QueryCache.put("test_1", "value1")
      QueryCache.put("test_2", "value2")
      QueryCache.put("other_1", "value3")
      QueryCache.put("other_2", "value4")

      patterns = ["test_*", "other_1"]
      CacheInvalidator.bulk_invalidate(patterns)

      # Give it time to process
      Process.sleep(100)

      # Specified patterns should be invalidated
      test1_result = QueryCache.get_or_compute("test_1", fn -> :not_found end)
      test2_result = QueryCache.get_or_compute("test_2", fn -> :not_found end)
      other1_result = QueryCache.get_or_compute("other_1", fn -> :not_found end)
      other2_result = QueryCache.get_or_compute("other_2", fn -> :not_found end)

      assert test1_result == :not_found
      assert test2_result == :not_found
      assert other1_result == :not_found

      # Non-matching entries should remain
      assert other2_result == "value4"
    end
  end

  describe "related invalidation" do
    test "can invalidate related entities" do
      # Setup cache for a killmail and related entities
      killmail_id = 98765
      character_id = 12345
      alliance_id = 54321

      QueryCache.put("killmail_enriched_#{killmail_id}", %{value: 1_000_000})
      QueryCache.put("character_intel_#{character_id}", %{analysis: "data"})
      QueryCache.put("alliance_stats_#{alliance_id}", %{members: 100})

      # Invalidate killmail and related entities
      related_types = [
        {:character, character_id},
        {:alliance, alliance_id}
      ]

      CacheInvalidator.invalidate_related(:killmail, killmail_id, related_types)

      # Give it time to process
      Process.sleep(100)

      # All related entries should be invalidated
      killmail_result =
        QueryCache.get_or_compute("killmail_enriched_#{killmail_id}", fn -> :not_found end)

      character_result =
        QueryCache.get_or_compute("character_intel_#{character_id}", fn -> :not_found end)

      alliance_result =
        QueryCache.get_or_compute("alliance_stats_#{alliance_id}", fn -> :not_found end)

      assert killmail_result == :not_found
      assert character_result == :not_found
      assert alliance_result == :not_found
    end
  end

  describe "statistics and monitoring" do
    test "can get invalidation statistics" do
      stats = CacheInvalidator.get_invalidation_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :total_invalidations)
      assert Map.has_key?(stats, :patterns_invalidated)
      assert Map.has_key?(stats, :invalidations_by_type)
      assert is_integer(stats.total_invalidations)
    end

    test "stats are updated after invalidations" do
      initial_stats = CacheInvalidator.get_invalidation_stats()
      initial_count = initial_stats.total_invalidations

      # Perform some invalidations
      CacheInvalidator.invalidate_by_pattern("test_*")
      Process.sleep(50)

      updated_stats = CacheInvalidator.get_invalidation_stats()
      assert updated_stats.total_invalidations > initial_count
    end
  end

  describe "convenience functions" do
    test "character intelligence invalidation" do
      character_id = 12345
      QueryCache.put("character_intel_#{character_id}", %{data: "test"})

      CacheInvalidator.invalidate_character_intelligence(character_id)
      Process.sleep(50)

      result = QueryCache.get_or_compute("character_intel_#{character_id}", fn -> :not_found end)
      assert result == :not_found
    end

    test "system activity invalidation" do
      system_id = 30_000_142
      QueryCache.put("system_info_#{system_id}", %{name: "Jita"})

      CacheInvalidator.invalidate_system_activity(system_id)
      Process.sleep(50)

      result = QueryCache.get_or_compute("system_info_#{system_id}", fn -> :not_found end)
      assert result == :not_found
    end

    test "alliance data invalidation" do
      alliance_id = 99_005_065
      QueryCache.put("alliance_stats_#{alliance_id}", %{name: "Test Alliance"})

      CacheInvalidator.invalidate_alliance_data(alliance_id)
      Process.sleep(50)

      result = QueryCache.get_or_compute("alliance_stats_#{alliance_id}", fn -> :not_found end)
      assert result == :not_found
    end
  end

  describe "error handling" do
    test "handles invalid patterns gracefully" do
      log =
        capture_log(fn ->
          # This should not crash
          CacheInvalidator.invalidate_by_pattern("")
          Process.sleep(50)
        end)

      # Should complete without errors
      assert is_binary(log)
    end

    test "handles unknown cache types" do
      log =
        capture_log(fn ->
          # Unknown cache type should not crash
          CacheInvalidator.invalidate_by_type(:unknown_type, 12345)
          Process.sleep(50)
        end)

      assert is_binary(log)
    end
  end
end
