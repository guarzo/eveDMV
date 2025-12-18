defmodule EveDmv.Eve.StaticDataLoader.JsonlParserTest do
  use ExUnit.Case, async: true

  alias EveDmv.Eve.StaticDataLoader.JsonlParser

  @fixtures_dir Path.join([__DIR__, "..", "..", "..", "..", "fixtures", "sde"])

  describe "stream_file/2" do
    test "returns error for non-existent file" do
      assert {:error, {:file_not_found, _}} =
               JsonlParser.stream_file("/non/existent/file.jsonl")
    end

    test "streams file content" do
      file_path = Path.join(@fixtures_dir, "types_sample.jsonl")
      assert {:ok, stream} = JsonlParser.stream_file(file_path)
      assert is_function(stream, 2) or match?(%Stream{}, stream)

      # Consume the stream
      items = Enum.to_list(stream)
      assert length(items) == 3
    end

    test "applies transform function" do
      file_path = Path.join(@fixtures_dir, "types_sample.jsonl")

      transform = fn item -> Map.put(item, :transformed, true) end

      assert {:ok, stream} = JsonlParser.stream_file(file_path, transform: transform)

      items = Enum.to_list(stream)
      assert Enum.all?(items, &Map.get(&1, :transformed))
    end

    test "applies filter function" do
      file_path = Path.join(@fixtures_dir, "types_sample.jsonl")

      # Filter to only items with _id == 587 (Rifter)
      filter = fn item -> Map.get(item, "_id") == 587 end

      assert {:ok, stream} = JsonlParser.stream_file(file_path, filter: filter)

      items = Enum.to_list(stream)
      assert length(items) == 1
      assert hd(items)["_id"] == 587
    end
  end

  describe "parse_file/2" do
    test "parses entire file into list" do
      file_path = Path.join(@fixtures_dir, "types_sample.jsonl")
      assert {:ok, items} = JsonlParser.parse_file(file_path)

      assert is_list(items)
      assert length(items) == 3
    end
  end

  describe "parse_types/1" do
    test "parses types.jsonl with correct field mapping" do
      file_path = Path.join(@fixtures_dir, "types_sample.jsonl")
      assert {:ok, stream} = JsonlParser.parse_types(file_path)

      types = Enum.to_list(stream)
      assert length(types) == 3

      # Find the Rifter
      rifter = Enum.find(types, &(&1.type_id == 587))
      assert rifter != nil
      assert rifter.name == "Rifter"
      assert rifter.group_id == 25
      assert rifter.mass == 1_067_000.0
      assert rifter.volume == 27_289.0
      assert rifter.capacity == 140.0
      assert rifter.base_price == 18_000.0
      assert rifter.published == true
      assert rifter.race_id == 2
      assert rifter.graphic_id == 44
      assert rifter.description == "The Rifter is a very powerful combat frigate."
    end

    test "handles missing optional fields" do
      file_path = Path.join(@fixtures_dir, "types_sample.jsonl")
      assert {:ok, stream} = JsonlParser.parse_types(file_path)

      types = Enum.to_list(stream)

      # Tempest Fleet Issue doesn't have graphic_id
      tempest = Enum.find(types, &(&1.type_id == 17703))
      assert tempest != nil
      assert tempest.graphic_id == nil
    end
  end

  describe "parse_solar_systems/1" do
    test "parses mapSolarSystems.jsonl with correct field mapping" do
      file_path = Path.join(@fixtures_dir, "solar_systems_sample.jsonl")
      assert {:ok, stream} = JsonlParser.parse_solar_systems(file_path)

      systems = Enum.to_list(stream)
      assert length(systems) == 3

      # Find Jita
      jita = Enum.find(systems, &(&1.system_id == 30_000_142))
      assert jita != nil
      assert jita.name == "Jita"
      assert jita.constellation_id == 20_000_020
      assert jita.region_id == 10_000_002
      assert_in_delta jita.security, 0.946, 0.01
      assert jita.security_class == "B"
      assert jita.is_hub == true
      assert jita.is_regional == true
      assert jita.is_border == false
      assert jita.sun_type_id == 45041
    end

    test "handles boolean flags correctly" do
      file_path = Path.join(@fixtures_dir, "solar_systems_sample.jsonl")
      assert {:ok, stream} = JsonlParser.parse_solar_systems(file_path)

      systems = Enum.to_list(stream)

      # All test systems are hubs
      assert Enum.all?(systems, & &1.is_hub)

      # None are border systems
      assert Enum.all?(systems, &(!&1.is_border))
    end
  end

  describe "parse_groups/1" do
    test "parses groups.jsonl with correct field mapping" do
      file_path = Path.join(@fixtures_dir, "groups_sample.jsonl")
      assert {:ok, stream} = JsonlParser.parse_groups(file_path)

      groups = Enum.to_list(stream)
      assert length(groups) == 3

      # Find Frigate group
      frigate = Enum.find(groups, &(&1.group_id == 25))
      assert frigate != nil
      assert frigate.name == "Frigate"
      assert frigate.category_id == 6
      assert frigate.published == true
    end
  end

  describe "parse_to_map/3" do
    test "creates map keyed by specified field" do
      file_path = Path.join(@fixtures_dir, "types_sample.jsonl")

      transform = fn data ->
        %{
          type_id: data["_id"],
          name: get_in(data, ["name", "en"])
        }
      end

      assert {:ok, map} = JsonlParser.parse_to_map(file_path, :type_id, transform: transform)

      assert is_map(map)
      assert Map.has_key?(map, 587)
      assert Map.has_key?(map, 24690)
      assert Map.has_key?(map, 17703)

      assert map[587].name == "Rifter"
    end
  end

  describe "_key/_value wrapper handling" do
    test "unwraps CCP format correctly" do
      # Create a temp file with wrapped format
      tmp_file =
        Path.join(System.tmp_dir!(), "test_wrapped_#{:erlang.unique_integer([:positive])}.jsonl")

      content = """
      {"_key": 100, "_value": {"name": {"en": "Test Item"}, "groupID": 1}}
      {"_key": 200, "_value": {"name": {"en": "Another Item"}, "groupID": 2}}
      """

      File.write!(tmp_file, content)

      on_exit(fn -> File.rm(tmp_file) end)

      assert {:ok, stream} = JsonlParser.stream_file(tmp_file)
      items = Enum.to_list(stream)

      assert length(items) == 2

      # _id should be set from _key
      assert Enum.at(items, 0)["_id"] == 100
      assert Enum.at(items, 1)["_id"] == 200

      # Original data should be accessible
      assert get_in(Enum.at(items, 0), ["name", "en"]) == "Test Item"
    end
  end

  describe "localized name extraction" do
    test "extracts English name from localized format" do
      file_path = Path.join(@fixtures_dir, "types_sample.jsonl")
      assert {:ok, stream} = JsonlParser.parse_types(file_path)

      types = Enum.to_list(stream)
      rifter = Enum.find(types, &(&1.type_id == 587))

      # Should extract "en" locale
      assert rifter.name == "Rifter"
    end
  end

  describe "numeric conversion" do
    test "converts floats correctly" do
      file_path = Path.join(@fixtures_dir, "types_sample.jsonl")
      assert {:ok, stream} = JsonlParser.parse_types(file_path)

      types = Enum.to_list(stream)
      rifter = Enum.find(types, &(&1.type_id == 587))

      assert is_float(rifter.mass)
      assert is_float(rifter.volume)
      assert is_float(rifter.capacity)
    end

    test "handles nil values" do
      file_path = Path.join(@fixtures_dir, "types_sample.jsonl")
      assert {:ok, stream} = JsonlParser.parse_types(file_path)

      types = Enum.to_list(stream)

      # All items should have numeric fields (defaulting to 0.0 if nil)
      Enum.each(types, fn type ->
        assert is_float(type.mass)
        assert is_float(type.volume)
      end)
    end
  end

  describe "error handling" do
    test "skips invalid JSON lines and continues" do
      tmp_file =
        Path.join(System.tmp_dir!(), "test_invalid_#{:erlang.unique_integer([:positive])}.jsonl")

      content = """
      {"_key": 1, "_value": {"name": {"en": "Valid"}}}
      this is not valid json
      {"_key": 2, "_value": {"name": {"en": "Also Valid"}}}
      """

      File.write!(tmp_file, content)

      on_exit(fn -> File.rm(tmp_file) end)

      assert {:ok, stream} = JsonlParser.stream_file(tmp_file)

      # Should have 2 valid items (invalid line skipped with warning)
      items = Enum.to_list(stream)
      assert length(items) == 2
    end

    test "handles empty file" do
      tmp_file =
        Path.join(System.tmp_dir!(), "test_empty_#{:erlang.unique_integer([:positive])}.jsonl")

      File.write!(tmp_file, "")

      on_exit(fn -> File.rm(tmp_file) end)

      assert {:ok, stream} = JsonlParser.stream_file(tmp_file)
      assert Enum.to_list(stream) == []
    end

    test "handles file with only whitespace" do
      tmp_file =
        Path.join(
          System.tmp_dir!(),
          "test_whitespace_#{:erlang.unique_integer([:positive])}.jsonl"
        )

      File.write!(tmp_file, "   \n\n   \n")

      on_exit(fn -> File.rm(tmp_file) end)

      assert {:ok, stream} = JsonlParser.stream_file(tmp_file)
      assert Enum.to_list(stream) == []
    end
  end
end
