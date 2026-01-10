defmodule EveDmv.Platform.Database.QueryCacheTest do
  @moduledoc """
  Tests for the QueryCache module with prefix index optimization.

  These tests verify:
  1. Basic cache operations (put, get, delete)
  2. Pattern matching with the prefix index (O(1) for prefix patterns)
  3. Fallback to full scan for suffix and complex patterns (O(n))
  4. Performance characteristics

  Note: These tests create their own ETS tables and don't require the full
  application to be started. They test the QueryCache module in isolation.
  """
  use ExUnit.Case, async: false

  alias EveDmv.Platform.Database.QueryCache

  # We need to start the cache before tests
  setup do
    # Ensure the cache ETS tables exist
    # The cache may already be started by the application, but we handle both cases
    # We catch errors since the ETS table may already exist
    try do
      QueryCache.start_link([])
    rescue
      # ETS table already exists (from application startup or previous test)
      ArgumentError -> :ok
    catch
      # Handle other potential issues
      :exit, _ -> :ok
    end

    # Clear any existing data - safe even if tables don't exist
    QueryCache.clear_all()

    on_exit(fn ->
      # Clean up after tests
      QueryCache.clear_all()
    end)

    :ok
  end

  describe "basic operations" do
    test "put and get a value" do
      assert :ok = QueryCache.put("test_key", "test_value")
      assert {:ok, "test_value"} = QueryCache.get("test_key")
    end

    test "get returns :miss for non-existent key" do
      assert :miss = QueryCache.get("nonexistent_key")
    end

    test "delete removes a key" do
      QueryCache.put("delete_test", "value")
      assert {:ok, "value"} = QueryCache.get("delete_test")

      QueryCache.delete("delete_test")
      assert :miss = QueryCache.get("delete_test")
    end

    test "clear_all removes all entries" do
      QueryCache.put("key1", "value1")
      QueryCache.put("key2", "value2")

      QueryCache.clear_all()

      assert :miss = QueryCache.get("key1")
      assert :miss = QueryCache.get("key2")
    end

    test "invalidate_key removes specific key" do
      QueryCache.put("invalidate_test", "value")
      assert {:ok, "value"} = QueryCache.get("invalidate_test")

      QueryCache.invalidate_key("invalidate_test")
      assert :miss = QueryCache.get("invalidate_test")
    end
  end

  describe "get_keys_by_pattern/1 with prefix patterns" do
    test "finds keys matching simple prefix pattern" do
      # Add keys with common prefix
      QueryCache.put("character_123_stats", "stats_data")
      QueryCache.put("character_123_history", "history_data")
      QueryCache.put("character_456_stats", "other_stats")
      QueryCache.put("corporation_789_info", "corp_data")

      # Should find both character_123_* keys
      keys = QueryCache.get_keys_by_pattern("character_123_*")
      assert length(keys) == 2
      assert "character_123_stats" in keys
      assert "character_123_history" in keys
      refute "character_456_stats" in keys
      refute "corporation_789_info" in keys
    end

    test "finds keys matching broader prefix pattern" do
      QueryCache.put("character_123_stats", "data1")
      QueryCache.put("character_456_stats", "data2")
      QueryCache.put("corporation_789_info", "data3")

      # Should find all character_* keys
      keys = QueryCache.get_keys_by_pattern("character_*")
      assert length(keys) == 2
      assert "character_123_stats" in keys
      assert "character_456_stats" in keys
    end

    test "returns empty list for non-matching prefix" do
      QueryCache.put("character_123_stats", "data")

      keys = QueryCache.get_keys_by_pattern("nonexistent_*")
      assert keys == []
    end

    test "works with colon delimiter" do
      QueryCache.put("user:123:profile", "profile_data")
      QueryCache.put("user:123:settings", "settings_data")
      QueryCache.put("user:456:profile", "other_profile")

      keys = QueryCache.get_keys_by_pattern("user:123:*")
      assert length(keys) == 2
      assert "user:123:profile" in keys
      assert "user:123:settings" in keys
    end
  end

  describe "get_keys_by_pattern/1 with suffix patterns" do
    test "finds keys matching suffix pattern (O(n) scan)" do
      QueryCache.put("character_123_stats", "data1")
      QueryCache.put("corporation_456_stats", "data2")
      QueryCache.put("character_789_history", "data3")

      keys = QueryCache.get_keys_by_pattern("*_stats")
      assert length(keys) == 2
      assert "character_123_stats" in keys
      assert "corporation_456_stats" in keys
      refute "character_789_history" in keys
    end
  end

  describe "get_keys_by_pattern/1 with complex patterns" do
    test "finds keys matching complex pattern with wildcard in middle" do
      QueryCache.put("user_john_profile", "data1")
      QueryCache.put("user_jane_profile", "data2")
      QueryCache.put("user_bob_settings", "data3")
      QueryCache.put("admin_alice_profile", "data4")

      keys = QueryCache.get_keys_by_pattern("user_*_profile")
      assert length(keys) == 2
      assert "user_john_profile" in keys
      assert "user_jane_profile" in keys
    end

    test "handles multiple wildcards" do
      QueryCache.put("a_b_c", "data1")
      QueryCache.put("a_x_c", "data2")
      QueryCache.put("a_b_d", "data3")

      keys = QueryCache.get_keys_by_pattern("a_*_c")
      assert length(keys) == 2
      assert "a_b_c" in keys
      assert "a_x_c" in keys
    end
  end

  describe "prefix index maintenance" do
    test "index is updated on delete" do
      QueryCache.put("test_key_1", "value1")
      QueryCache.put("test_key_2", "value2")

      # Both should be found
      initial_keys = QueryCache.get_keys_by_pattern("test_*")
      assert length(initial_keys) == 2

      # Delete one
      QueryCache.delete("test_key_1")

      # Only one should remain
      remaining_keys = QueryCache.get_keys_by_pattern("test_*")
      assert length(remaining_keys) == 1
      assert "test_key_2" in remaining_keys
    end

    test "index is cleared on clear_all" do
      QueryCache.put("prefix_a_1", "value1")
      QueryCache.put("prefix_a_2", "value2")

      QueryCache.clear_all()

      keys = QueryCache.get_keys_by_pattern("prefix_a_*")
      assert keys == []
    end

    test "index is updated on invalidate_key" do
      QueryCache.put("inv_test_1", "value1")
      QueryCache.put("inv_test_2", "value2")

      QueryCache.invalidate_key("inv_test_1")

      keys = QueryCache.get_keys_by_pattern("inv_*")
      assert length(keys) == 1
      assert "inv_test_2" in keys
    end
  end

  describe "performance characteristics" do
    @tag :performance
    test "prefix and full scan lookups complete successfully for large datasets" do
      # Insert many keys
      num_keys = 500

      for i <- 1..num_keys do
        QueryCache.put("entity_#{i}_data", "value_#{i}")
      end

      # Add a few keys with a specific prefix we'll search for
      for i <- 1..10 do
        QueryCache.put("target_#{i}_data", "target_value_#{i}")
      end

      # Measure prefix lookup time (uses index)
      {prefix_time, prefix_result} =
        :timer.tc(fn ->
          QueryCache.get_keys_by_pattern("target_*")
        end)

      # Measure complex pattern time (full scan)
      {scan_time, scan_result} =
        :timer.tc(fn ->
          QueryCache.get_keys_by_pattern("*_data")
        end)

      # Verify correctness
      assert length(prefix_result) == 10
      assert length(scan_result) == num_keys + 10

      # Verify both lookups complete successfully with valid timing
      assert is_integer(prefix_time)
      assert is_integer(scan_time)
      assert prefix_time >= 0
      assert scan_time >= 0

      # Soft timing assertion: prefix lookup should not be dramatically slower than full scan
      # We use a generous 10x multiplier to account for test environment variance
      # In practice, prefix lookup (O(1) index lookup) should be faster than full scan (O(n))
      # Guard against zero scan_time to avoid flaky assertion
      effective_scan_time = max(scan_time, 1)

      assert prefix_time <= effective_scan_time * 10,
             "Prefix lookup (#{prefix_time}us) was unexpectedly slow compared to full scan (#{effective_scan_time}us)"
    end
  end

  describe "edge cases" do
    test "handles empty pattern" do
      QueryCache.put("key1", "value1")

      # Empty pattern with wildcard should match all
      keys = QueryCache.get_keys_by_pattern("*")
      assert "key1" in keys
    end

    test "handles pattern with no wildcards (O(1) exact lookup)" do
      QueryCache.put("exact_key", "value")

      # Pattern without wildcard - uses O(1) direct cache lookup
      # instead of falling back to O(n) regex scan
      keys = QueryCache.get_keys_by_pattern("exact_key")
      assert keys == ["exact_key"]
    end

    test "exact pattern returns empty list for non-existent key" do
      QueryCache.put("existing_key", "value")

      # Non-existent key with no wildcards returns empty list
      keys = QueryCache.get_keys_by_pattern("nonexistent_key")
      assert keys == []
    end

    test "handles special regex characters in pattern" do
      QueryCache.put("key.with.dots", "value1")
      QueryCache.put("key_with_underscores", "value2")

      # The . should be escaped, not treated as regex wildcard
      keys = QueryCache.get_keys_by_pattern("key.with.*")
      assert length(keys) == 1
      assert "key.with.dots" in keys
    end

    test "handles keys with mixed delimiters" do
      QueryCache.put("user:123_profile:active", "data")
      QueryCache.put("user:123_profile:inactive", "data")

      keys = QueryCache.get_keys_by_pattern("user:123_*")
      assert length(keys) == 2
    end
  end

  describe "performance regression tests for O(n) patterns" do
    @tag :performance
    test "suffix patterns perform full scan (O(n) behavior)" do
      # This test verifies the O(n) behavior warning in the docstring
      # by checking that suffix patterns correctly scan all entries
      num_keys = 100

      for i <- 1..num_keys do
        QueryCache.put("prefix_" <> Integer.to_string(i) <> "_suffix", "value")
      end

      # Add keys with different suffix
      for i <- 1..10 do
        QueryCache.put("prefix_" <> Integer.to_string(i) <> "_other", "value")
      end

      # Suffix pattern requires full scan
      keys = QueryCache.get_keys_by_pattern("*_suffix")
      assert length(keys) == num_keys

      # Verify all expected keys are found
      for i <- 1..num_keys do
        assert ("prefix_" <> Integer.to_string(i) <> "_suffix") in keys
      end
    end

    @tag :performance
    test "complex patterns with middle wildcards perform full scan" do
      # This verifies pattern_to_regex is used correctly
      for i <- 1..50 do
        QueryCache.put("user_" <> Integer.to_string(i) <> "_profile", "data")
        QueryCache.put("user_" <> Integer.to_string(i) <> "_settings", "data")
      end

      # Middle wildcard pattern: user_*_profile
      profile_keys = QueryCache.get_keys_by_pattern("user_*_profile")
      assert length(profile_keys) == 50

      settings_keys = QueryCache.get_keys_by_pattern("user_*_settings")
      assert length(settings_keys) == 50
    end

    @tag :performance
    test "prefix patterns use index for O(m) lookup" do
      # Create many keys with different prefixes
      for i <- 1..100 do
        QueryCache.put("alpha_" <> Integer.to_string(i), "value")
        QueryCache.put("beta_" <> Integer.to_string(i), "value")
        QueryCache.put("gamma_" <> Integer.to_string(i), "value")
      end

      # Prefix lookup should only return keys with that prefix
      alpha_keys = QueryCache.get_keys_by_pattern("alpha_*")
      assert length(alpha_keys) == 100

      beta_keys = QueryCache.get_keys_by_pattern("beta_*")
      assert length(beta_keys) == 100

      # Verify no cross-contamination
      Enum.each(alpha_keys, fn key ->
        assert String.starts_with?(key, "alpha_")
      end)
    end

    @tag :performance
    test "pattern_to_regex correctly escapes special characters" do
      # Test that regex special characters are properly escaped
      QueryCache.put("key.with.dots", "value1")
      QueryCache.put("key+with+plus", "value2")
      QueryCache.put("key[with]brackets", "value3")
      QueryCache.put("keywithplain", "value4")

      # The . in the pattern should match literal dots, not any character
      keys = QueryCache.get_keys_by_pattern("key.with.*")
      assert length(keys) == 1
      assert "key.with.dots" in keys

      # Verify + is escaped
      plus_keys = QueryCache.get_keys_by_pattern("key+with+*")
      assert length(plus_keys) == 1
      assert "key+with+plus" in plus_keys
    end
  end
end
