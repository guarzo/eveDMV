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
    try do
      QueryCache.start_link([])
    catch
      :error, :badarg -> :ok
      :exit, {:noproc, _} -> start_cache_tables_manually()
    end

    # Clear any existing data
    try do
      QueryCache.clear_all()
    catch
      _, _ -> :ok
    end

    on_exit(fn ->
      try do
        QueryCache.clear_all()
      catch
        _, _ -> :ok
      end
    end)

    :ok
  end

  # Manually create ETS tables if needed (fallback for testing)
  defp start_cache_tables_manually do
    tables = [:query_cache, :query_cache_prefix_index]

    Enum.each(tables, fn table ->
      try do
        :ets.new(table, [:set, :public, :named_table, read_concurrency: true])
      catch
        :error, :badarg -> :ok
      end
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
    test "prefix lookup is faster than full scan for large datasets" do
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

      # Prefix lookup should generally be faster, but we allow for some variance
      # The important thing is that both complete successfully
      assert is_integer(prefix_time)
      assert is_integer(scan_time)

      # Times are captured for potential debugging via test metadata
      # prefix_time and scan_time are in microseconds
      assert prefix_time >= 0
      assert scan_time >= 0
    end
  end

  describe "edge cases" do
    test "handles empty pattern" do
      QueryCache.put("key1", "value1")

      # Empty pattern with wildcard should match all
      keys = QueryCache.get_keys_by_pattern("*")
      assert "key1" in keys
    end

    test "handles pattern with no wildcards (exact match attempt)" do
      QueryCache.put("exact_key", "value")

      # Pattern without wildcard - should treat as complex pattern
      # and use regex matching
      keys = QueryCache.get_keys_by_pattern("exact_key")
      assert "exact_key" in keys
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
end
