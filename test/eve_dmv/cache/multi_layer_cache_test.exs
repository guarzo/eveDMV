defmodule EveDmv.Platform.Cache.MultiLayerCacheTest do
  @moduledoc """
  Tests for the MultiLayerCache module.

  These tests verify the caching behavior without requiring the full
  application context. The tests focus on the public API.
  """
  use EveDmv.DataCase, async: false

  alias EveDmv.Platform.Cache.MultiLayerCache

  @moduletag :cache

  describe "get/2 and put/3" do
    test "returns :miss for non-existent key" do
      result = MultiLayerCache.get("definitely_not_exists_#{System.unique_integer()}")
      assert result == :miss
    end

    test "stores and retrieves a value" do
      key = "test_key_#{System.unique_integer()}"
      value = %{data: "test_value", count: 42}

      assert :ok == MultiLayerCache.put(key, value)
      assert {:ok, ^value} = MultiLayerCache.get(key)
    end
  end

  describe "get_or_compute/3" do
    test "computes value on cache miss" do
      key = "compute_test_#{System.unique_integer()}"

      result =
        MultiLayerCache.get_or_compute(key, fn ->
          %{computed: true}
        end)

      assert result == %{computed: true}
    end

    test "returns cached value on hit" do
      key = "compute_hit_#{System.unique_integer()}"
      original_value = %{original: true}

      MultiLayerCache.put(key, original_value)

      result =
        MultiLayerCache.get_or_compute(key, fn ->
          %{computed: true}
        end)

      assert result == original_value
    end
  end

  describe "delete/1" do
    test "removes value from cache" do
      key = "delete_test_#{System.unique_integer()}"
      MultiLayerCache.put(key, "to_delete")

      assert {:ok, "to_delete"} = MultiLayerCache.get(key)
      assert :ok == MultiLayerCache.delete(key)
      assert :miss == MultiLayerCache.get(key)
    end

    test "deleting non-existent key is safe" do
      assert :ok == MultiLayerCache.delete("does_not_exist_#{System.unique_integer()}")
    end
  end

  describe "clear_all/0" do
    test "clears all cached values" do
      key1 = "clear_test_1_#{System.unique_integer()}"
      key2 = "clear_test_2_#{System.unique_integer()}"

      MultiLayerCache.put(key1, "value1")
      MultiLayerCache.put(key2, "value2")

      assert :ok == MultiLayerCache.clear_all()

      assert :miss == MultiLayerCache.get(key1)
      assert :miss == MultiLayerCache.get(key2)
    end
  end

  describe "warm_cache/1" do
    test "returns :ok when warming cache" do
      key1 = "warm_1_#{System.unique_integer()}"
      key2 = "warm_2_#{System.unique_integer()}"

      # warm_cache populates L2 (ETS) cache
      result =
        MultiLayerCache.warm_cache([
          {key1, %{id: 1}},
          {key2, %{id: 2}}
        ])

      assert result == :ok
    end

    test "warm_cache accepts empty list" do
      assert :ok == MultiLayerCache.warm_cache([])
    end
  end
end
