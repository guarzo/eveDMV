defmodule EveDmv.Eve.StaticDataLoader.FileManagerTest do
  use ExUnit.Case, async: true

  alias EveDmv.Eve.StaticDataLoader.FileManager

  describe "get_files_for_source/0" do
    test "returns CCP file mappings" do
      files = FileManager.get_files_for_source()

      assert is_map(files)
      assert Map.has_key?(files, :item_types)
      assert Map.has_key?(files, :item_groups)
      assert Map.has_key?(files, :item_categories)
      assert Map.has_key?(files, :solar_systems)
      assert Map.has_key?(files, :regions)
      assert Map.has_key?(files, :constellations)

      # CCP files are JSONL format
      assert String.ends_with?(files.item_types, ".jsonl")
      assert String.ends_with?(files.solar_systems, ".jsonl")
    end
  end

  describe "get_data_directory/0" do
    test "returns priv/static_data path" do
      dir = FileManager.get_data_directory()

      assert is_binary(dir)
      assert String.contains?(dir, "static_data")
    end
  end

  describe "get_required_files/0" do
    test "returns CCP file mappings" do
      files = FileManager.get_required_files()

      assert is_map(files)
      assert Map.has_key?(files, :item_types)
      assert String.ends_with?(files.item_types, ".jsonl")
    end
  end

  describe "get_cache_info/0" do
    test "returns cache info structure" do
      info = FileManager.get_cache_info()

      assert is_map(info)
      assert info.source == :ccp
      assert Map.has_key?(info, :directory)
      assert Map.has_key?(info, :extracted_dir)
      assert Map.has_key?(info, :files)
      assert Map.has_key?(info, :total_size)
    end
  end

  describe "ensure_sde_files/1" do
    test "function exists and accepts a list of keys" do
      assert function_exported?(FileManager, :ensure_sde_files, 1)
    end
  end

  describe "ensure_ccp_files/1" do
    test "function exists" do
      assert function_exported?(FileManager, :ensure_ccp_files, 1)
    end
  end

  describe "clear_cache/0" do
    test "succeeds even when cache doesn't exist" do
      result = FileManager.clear_cache()
      assert result == :ok
    end
  end

  describe "CCP JSONL format" do
    test "CCP files use JSONL format" do
      ccp_files = FileManager.get_files_for_source()

      # All CCP files should be JSONL (from ZIP archive)
      Enum.each(ccp_files, fn {_key, filename} ->
        assert String.ends_with?(filename, ".jsonl"),
               "CCP file #{filename} should be JSONL format"
      end)
    end
  end

  describe "source configuration" do
    test "required file keys include all data types" do
      ccp_files = FileManager.get_files_for_source()

      required_keys = [
        :item_types,
        :item_groups,
        :item_categories,
        :solar_systems,
        :regions,
        :constellations
      ]

      Enum.each(required_keys, fn key ->
        assert Map.has_key?(ccp_files, key), "Missing required key: #{key}"
      end)
    end
  end
end
