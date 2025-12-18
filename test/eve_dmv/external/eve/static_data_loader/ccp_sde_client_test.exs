defmodule EveDmv.Eve.StaticDataLoader.CcpSdeClientTest do
  use ExUnit.Case, async: true

  alias EveDmv.Eve.StaticDataLoader.CcpSdeClient

  describe "module configuration" do
    test "returns correct version URL" do
      assert CcpSdeClient.version_url() ==
               "https://developers.eveonline.com/static-data/tranquility/latest.jsonl"
    end

    test "returns correct archive URL" do
      assert CcpSdeClient.latest_archive_url() ==
               "https://developers.eveonline.com/static-data/eve-online-static-data-latest-jsonl.zip"
    end

    test "returns list of required files" do
      required = CcpSdeClient.required_files()

      assert is_list(required)
      assert "types.jsonl" in required
      assert "groups.jsonl" in required
      assert "categories.jsonl" in required
      assert "mapSolarSystems.jsonl" in required
      assert "mapRegions.jsonl" in required
      assert "mapConstellations.jsonl" in required
    end
  end

  describe "validate_required_files/1" do
    setup do
      # Create a temporary directory with test files
      tmp_dir = Path.join(System.tmp_dir!(), "sde_test_#{:erlang.unique_integer([:positive])}")
      File.mkdir_p!(tmp_dir)

      on_exit(fn ->
        File.rm_rf!(tmp_dir)
      end)

      {:ok, tmp_dir: tmp_dir}
    end

    test "returns error when files are missing", %{tmp_dir: tmp_dir} do
      assert {:error, {:missing_files, missing}} = CcpSdeClient.validate_required_files(tmp_dir)
      assert length(missing) == 6
    end

    test "returns ok with file paths when all files exist", %{tmp_dir: tmp_dir} do
      # Create all required files
      required_files = [
        "types.jsonl",
        "groups.jsonl",
        "categories.jsonl",
        "mapSolarSystems.jsonl",
        "mapRegions.jsonl",
        "mapConstellations.jsonl"
      ]

      Enum.each(required_files, fn file ->
        File.write!(Path.join(tmp_dir, file), "{}")
      end)

      assert {:ok, file_paths} = CcpSdeClient.validate_required_files(tmp_dir)
      assert is_map(file_paths)
      assert Map.has_key?(file_paths, :item_types)
      assert Map.has_key?(file_paths, :item_groups)
      assert Map.has_key?(file_paths, :item_categories)
      assert Map.has_key?(file_paths, :solar_systems)
      assert Map.has_key?(file_paths, :regions)
      assert Map.has_key?(file_paths, :constellations)
    end

    test "finds files in nested directories", %{tmp_dir: tmp_dir} do
      # Create files in a nested directory (like CCP SDE structure)
      nested_dir = Path.join([tmp_dir, "sde", "fsd"])
      File.mkdir_p!(nested_dir)

      required_files = [
        "types.jsonl",
        "groups.jsonl",
        "categories.jsonl",
        "mapSolarSystems.jsonl",
        "mapRegions.jsonl",
        "mapConstellations.jsonl"
      ]

      Enum.each(required_files, fn file ->
        File.write!(Path.join(nested_dir, file), "{}")
      end)

      assert {:ok, file_paths} = CcpSdeClient.validate_required_files(tmp_dir)
      assert map_size(file_paths) == 6

      # Verify paths point to nested directory
      assert String.contains?(file_paths.item_types, "sde/fsd")
    end
  end

  describe "extract_archive/2" do
    setup do
      tmp_dir =
        Path.join(System.tmp_dir!(), "sde_extract_test_#{:erlang.unique_integer([:positive])}")

      File.mkdir_p!(tmp_dir)

      on_exit(fn ->
        File.rm_rf!(tmp_dir)
      end)

      {:ok, tmp_dir: tmp_dir}
    end

    test "extracts valid zip archive", %{tmp_dir: tmp_dir} do
      # Create a simple test zip file
      zip_path = Path.join(tmp_dir, "test.zip")
      extract_dir = Path.join(tmp_dir, "extracted")

      # Create test content
      test_file_content = "test content"

      # Create zip with Erlang :zip module
      {:ok, _} =
        :zip.create(
          String.to_charlist(zip_path),
          [{~c"test.txt", test_file_content}]
        )

      assert {:ok, ^extract_dir} = CcpSdeClient.extract_archive(zip_path, extract_dir)
      assert File.exists?(Path.join(extract_dir, "test.txt"))
      assert File.read!(Path.join(extract_dir, "test.txt")) == test_file_content
    end

    test "returns error for invalid archive", %{tmp_dir: tmp_dir} do
      invalid_zip_path = Path.join(tmp_dir, "invalid.zip")
      extract_dir = Path.join(tmp_dir, "extracted")

      File.write!(invalid_zip_path, "not a zip file")

      assert {:error, {:extraction_failed, _reason}} =
               CcpSdeClient.extract_archive(invalid_zip_path, extract_dir)
    end

    test "returns error for non-existent archive", %{tmp_dir: tmp_dir} do
      non_existent_path = Path.join(tmp_dir, "does_not_exist.zip")
      extract_dir = Path.join(tmp_dir, "extracted")

      assert {:error, {:extraction_failed, _reason}} =
               CcpSdeClient.extract_archive(non_existent_path, extract_dir)
    end
  end

  describe "download_sde_archive/2" do
    setup do
      tmp_dir =
        Path.join(System.tmp_dir!(), "sde_download_test_#{:erlang.unique_integer([:positive])}")

      File.mkdir_p!(tmp_dir)

      on_exit(fn ->
        File.rm_rf!(tmp_dir)
      end)

      {:ok, tmp_dir: tmp_dir}
    end

    test "creates output directory if it doesn't exist", %{tmp_dir: tmp_dir} do
      non_existent_dir = Path.join(tmp_dir, "new_dir")
      refute File.exists?(non_existent_dir)

      # This will fail due to network, but directory should be created
      _result = CcpSdeClient.download_sde_archive(non_existent_dir)

      assert File.exists?(non_existent_dir)
    end
  end
end
