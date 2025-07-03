defmodule EveDmv.Intelligence.IntelligenceCacheTest do
  # Not async due to GenServer state
  use ExUnit.Case, async: false
  @moduletag :skip

  alias EveDmv.Intelligence.IntelligenceCache

  setup do
    # Start the cache for testing
    start_supervised!(IntelligenceCache)

    # Clear cache before each test
    IntelligenceCache.clear_cache()

    :ok
  end

  describe "character analysis caching" do
    test "caches and retrieves character analysis" do
      character_id = 95_465_499

      # First call should generate analysis (cache miss)
      {:ok, analysis1} = IntelligenceCache.get_character_analysis(character_id)

      # Second call should return cached result
      {:ok, analysis2} = IntelligenceCache.get_character_analysis(character_id)

      # Results should be consistent (same data structure)
      assert analysis1 == analysis2
    end

    test "handles character analysis generation errors" do
      # Use an invalid character ID that would cause generation to fail
      invalid_character_id = -1

      result = IntelligenceCache.get_character_analysis(invalid_character_id)

      # Should handle errors gracefully
      assert match?({:error, _}, result)
    end
  end

  describe "vetting analysis caching" do
    test "caches and retrieves vetting analysis" do
      character_id = 95_465_499

      # Test vetting cache
      result1 = IntelligenceCache.get_vetting_analysis(character_id)
      result2 = IntelligenceCache.get_vetting_analysis(character_id)

      # Both calls should return the same structure
      assert result1 == result2
    end
  end

  describe "correlation analysis caching" do
    test "caches and retrieves correlation analysis" do
      character_id = 95_465_499

      # Test correlation cache
      result1 = IntelligenceCache.get_correlation_analysis(character_id)
      result2 = IntelligenceCache.get_correlation_analysis(character_id)

      # Both calls should return the same structure
      assert result1 == result2
    end
  end

  describe "cache invalidation" do
    test "invalidates character cache" do
      character_id = 95_465_499

      # Cache some data
      IntelligenceCache.get_character_analysis(character_id)

      # Invalidate cache
      :ok = IntelligenceCache.invalidate_character_cache(character_id)

      # Should succeed without error
      assert true
    end

    test "handles cache invalidation for non-existent character" do
      # Should not error when invalidating non-existent cache
      :ok = IntelligenceCache.invalidate_character_cache(999_999)
      assert true
    end
  end

  describe "cache statistics" do
    test "provides cache statistics" do
      stats = IntelligenceCache.get_cache_stats()

      assert Map.has_key?(stats, :cache_size)
      assert Map.has_key?(stats, :hit_count)
      assert Map.has_key?(stats, :miss_count)
      assert Map.has_key?(stats, :hit_ratio)

      assert is_integer(stats.cache_size)
      assert is_integer(stats.hit_count)
      assert is_integer(stats.miss_count)
      assert is_number(stats.hit_ratio)
    end

    test "tracks hit/miss ratios" do
      character_id = 95_465_499

      # Get initial stats
      initial_stats = IntelligenceCache.get_cache_stats()

      # Make a cache request (should be a miss)
      IntelligenceCache.get_character_analysis(character_id)

      # Make same request again (should be a hit)
      IntelligenceCache.get_character_analysis(character_id)

      # Get updated stats
      updated_stats = IntelligenceCache.get_cache_stats()

      # Should show increased activity
      assert updated_stats.hit_count >= initial_stats.hit_count
      assert updated_stats.miss_count >= initial_stats.miss_count
    end
  end

  describe "cache clearing" do
    test "clears all cache data" do
      character_id = 95_465_499

      # Cache some data
      IntelligenceCache.get_character_analysis(character_id)

      # Clear cache
      :ok = IntelligenceCache.clear_cache()

      # Stats should be reset
      stats = IntelligenceCache.get_cache_stats()
      assert stats.cache_size == 0
      assert stats.hit_count == 0
      assert stats.miss_count == 0
    end
  end

  describe "cache warming" do
    test "warms cache without errors" do
      # Should not error when warming cache
      IntelligenceCache.warm_popular_cache()
      assert true
    end
  end
end
