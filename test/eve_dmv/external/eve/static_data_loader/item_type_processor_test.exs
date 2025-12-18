defmodule EveDmv.Eve.StaticDataLoader.ItemTypeProcessorTest do
  use ExUnit.Case, async: true

  alias EveDmv.Eve.StaticDataLoader.ItemTypeProcessor

  @fixtures_dir Path.join([__DIR__, "..", "..", "..", "..", "fixtures", "sde"])

  describe "get_killmail_category_ids/0" do
    test "returns the list of killmail-relevant category IDs" do
      category_ids = ItemTypeProcessor.get_killmail_category_ids()

      assert is_list(category_ids)
      # Ship
      assert 6 in category_ids
      # Module
      assert 7 in category_ids
      # Charge
      assert 8 in category_ids
      # Drone
      assert 18 in category_ids
      # Implant
      assert 20 in category_ids
      # Deployable
      assert 22 in category_ids
      # Structure
      assert 65 in category_ids
      # Fighter
      assert 87 in category_ids

      # Should not include Blueprint
      refute 9 in category_ids
    end
  end

  describe "killmail_category?/1" do
    test "returns true for killmail-relevant categories" do
      assert ItemTypeProcessor.killmail_category?(6)
      assert ItemTypeProcessor.killmail_category?(7)
      assert ItemTypeProcessor.killmail_category?(8)
      assert ItemTypeProcessor.killmail_category?(18)
      assert ItemTypeProcessor.killmail_category?(20)
      assert ItemTypeProcessor.killmail_category?(22)
      assert ItemTypeProcessor.killmail_category?(65)
      assert ItemTypeProcessor.killmail_category?(87)
    end

    test "returns false for non-killmail categories" do
      # Blueprint
      refute ItemTypeProcessor.killmail_category?(9)
      # Skill
      refute ItemTypeProcessor.killmail_category?(16)
      # Material
      refute ItemTypeProcessor.killmail_category?(4)
    end
  end

  describe "should_import_type?/3" do
    test "returns true for published killmail-relevant items when filtering" do
      type = %{published: true, name: "Test Ship"}
      # Ship category
      assert ItemTypeProcessor.should_import_type?(type, 6, true)
      # Module category
      assert ItemTypeProcessor.should_import_type?(type, 7, true)
    end

    test "returns false for unpublished items when filtering" do
      type = %{published: false, name: "Unpublished Ship"}
      refute ItemTypeProcessor.should_import_type?(type, 6, true)
    end

    test "returns false for non-killmail categories when filtering" do
      type = %{published: true, name: "Blueprint"}
      # Blueprint category
      refute ItemTypeProcessor.should_import_type?(type, 9, true)
    end

    test "returns true for all items when not filtering" do
      type = %{published: false, name: "Unpublished Blueprint"}
      # Blueprint category, but filtering disabled
      assert ItemTypeProcessor.should_import_type?(type, 9, false)
    end
  end

  describe "get_ship_group_ids/0" do
    test "returns the list of ship group IDs" do
      group_ids = ItemTypeProcessor.get_ship_group_ids()

      assert is_list(group_ids)
      # Frigate
      assert 25 in group_ids
      # Cruiser
      assert 26 in group_ids
      # Battleship
      assert 27 in group_ids
      # Interdictor
      assert 541 in group_ids
      # Force Auxiliary
      assert 1538 in group_ids
    end
  end

  describe "ship_group?/1" do
    test "returns true for ship groups" do
      assert ItemTypeProcessor.ship_group?(25)
      assert ItemTypeProcessor.ship_group?(26)
      assert ItemTypeProcessor.ship_group?(27)
    end

    test "returns false for non-ship groups" do
      # Damage Control
      refute ItemTypeProcessor.ship_group?(55)
      # Hybrid Charge
      refute ItemTypeProcessor.ship_group?(83)
    end
  end

  describe "process_item_data_jsonl/2" do
    test "processes JSONL files and returns item types" do
      file_paths = %{
        item_types: Path.join(@fixtures_dir, "types_extended.jsonl"),
        item_groups: Path.join(@fixtures_dir, "groups_extended.jsonl"),
        item_categories: Path.join(@fixtures_dir, "categories_sample.jsonl")
      }

      assert {:ok, item_types} = ItemTypeProcessor.process_item_data_jsonl(file_paths)
      assert is_list(item_types)
      assert length(item_types) > 0
    end

    test "filters to killmail-relevant categories by default" do
      file_paths = %{
        item_types: Path.join(@fixtures_dir, "types_extended.jsonl"),
        item_groups: Path.join(@fixtures_dir, "groups_extended.jsonl"),
        item_categories: Path.join(@fixtures_dir, "categories_sample.jsonl")
      }

      assert {:ok, item_types} = ItemTypeProcessor.process_item_data_jsonl(file_paths)

      # Should include ships
      ships = Enum.filter(item_types, & &1.is_ship)
      assert length(ships) > 0

      # Should not include blueprints (category 9)
      blueprints = Enum.filter(item_types, & &1.is_blueprint)
      assert Enum.empty?(blueprints)

      # Should not include unpublished items
      unpublished = Enum.filter(item_types, &(!&1.published))
      assert Enum.empty?(unpublished)
    end

    test "imports all items when filter_categories is false" do
      file_paths = %{
        item_types: Path.join(@fixtures_dir, "types_extended.jsonl"),
        item_groups: Path.join(@fixtures_dir, "groups_extended.jsonl"),
        item_categories: Path.join(@fixtures_dir, "categories_sample.jsonl")
      }

      assert {:ok, item_types} =
               ItemTypeProcessor.process_item_data_jsonl(file_paths, filter_categories: false)

      # Should include blueprints when not filtering
      total_count = length(item_types)

      assert {:ok, filtered_types} = ItemTypeProcessor.process_item_data_jsonl(file_paths)
      filtered_count = length(filtered_types)

      # Unfiltered should have more items
      assert total_count > filtered_count
    end

    test "includes sde_version in processed items" do
      file_paths = %{
        item_types: Path.join(@fixtures_dir, "types_extended.jsonl"),
        item_groups: Path.join(@fixtures_dir, "groups_extended.jsonl"),
        item_categories: Path.join(@fixtures_dir, "categories_sample.jsonl")
      }

      assert {:ok, item_types} =
               ItemTypeProcessor.process_item_data_jsonl(file_paths, sde_version: "test-version")

      assert Enum.all?(item_types, &(&1.sde_version == "test-version"))
    end

    test "includes sde_build_number when provided" do
      file_paths = %{
        item_types: Path.join(@fixtures_dir, "types_extended.jsonl"),
        item_groups: Path.join(@fixtures_dir, "groups_extended.jsonl"),
        item_categories: Path.join(@fixtures_dir, "categories_sample.jsonl")
      }

      assert {:ok, item_types} =
               ItemTypeProcessor.process_item_data_jsonl(file_paths, sde_build_number: 3_142_455)

      assert Enum.all?(item_types, &(&1.sde_build_number == 3_142_455))
    end

    test "correctly identifies ships" do
      file_paths = %{
        item_types: Path.join(@fixtures_dir, "types_extended.jsonl"),
        item_groups: Path.join(@fixtures_dir, "groups_extended.jsonl"),
        item_categories: Path.join(@fixtures_dir, "categories_sample.jsonl")
      }

      assert {:ok, item_types} = ItemTypeProcessor.process_item_data_jsonl(file_paths)

      # Find the Rifter (frigate, group 25)
      rifter = Enum.find(item_types, &(&1.type_id == 587))
      assert rifter != nil
      assert rifter.is_ship == true
      assert rifter.type_name == "Rifter"
      assert rifter.category_name == "Ship"
    end

    test "correctly identifies modules" do
      file_paths = %{
        item_types: Path.join(@fixtures_dir, "types_extended.jsonl"),
        item_groups: Path.join(@fixtures_dir, "groups_extended.jsonl"),
        item_categories: Path.join(@fixtures_dir, "categories_sample.jsonl")
      }

      assert {:ok, item_types} = ItemTypeProcessor.process_item_data_jsonl(file_paths)

      # Find the Damage Control I
      dc = Enum.find(item_types, &(&1.type_id == 2048))
      assert dc != nil
      assert dc.is_module == true
      assert dc.category_name == "Module"
    end

    test "correctly identifies drones" do
      file_paths = %{
        item_types: Path.join(@fixtures_dir, "types_extended.jsonl"),
        item_groups: Path.join(@fixtures_dir, "groups_extended.jsonl"),
        item_categories: Path.join(@fixtures_dir, "categories_sample.jsonl")
      }

      assert {:ok, item_types} = ItemTypeProcessor.process_item_data_jsonl(file_paths)

      # Find the Hobgoblin I
      hobgoblin = Enum.find(item_types, &(&1.type_id == 2456))
      assert hobgoblin != nil
      assert hobgoblin.is_drone == true
      assert hobgoblin.category_name == "Drone"
    end

    test "correctly identifies charges" do
      file_paths = %{
        item_types: Path.join(@fixtures_dir, "types_extended.jsonl"),
        item_groups: Path.join(@fixtures_dir, "groups_extended.jsonl"),
        item_categories: Path.join(@fixtures_dir, "categories_sample.jsonl")
      }

      assert {:ok, item_types} = ItemTypeProcessor.process_item_data_jsonl(file_paths)

      # Find the Antimatter Charge S
      ammo = Enum.find(item_types, &(&1.type_id == 220))
      assert ammo != nil
      assert ammo.is_charge == true
      assert ammo.category_name == "Charge"
    end

    test "correctly identifies implants" do
      file_paths = %{
        item_types: Path.join(@fixtures_dir, "types_extended.jsonl"),
        item_groups: Path.join(@fixtures_dir, "groups_extended.jsonl"),
        item_categories: Path.join(@fixtures_dir, "categories_sample.jsonl")
      }

      assert {:ok, item_types} = ItemTypeProcessor.process_item_data_jsonl(file_paths)

      # Find the Snake Alpha
      implant = Enum.find(item_types, &(&1.type_id == 10220))
      assert implant != nil
      assert implant.is_implant == true
      assert implant.category_name == "Implant"
    end

    test "correctly identifies deployables" do
      file_paths = %{
        item_types: Path.join(@fixtures_dir, "types_extended.jsonl"),
        item_groups: Path.join(@fixtures_dir, "groups_extended.jsonl"),
        item_categories: Path.join(@fixtures_dir, "categories_sample.jsonl")
      }

      assert {:ok, item_types} = ItemTypeProcessor.process_item_data_jsonl(file_paths)

      # Find the Mobile Depot
      depot = Enum.find(item_types, &(&1.type_id == 28846))
      assert depot != nil
      assert depot.is_deployable == true
      assert depot.category_name == "Deployable"
    end

    test "correctly identifies fighters" do
      file_paths = %{
        item_types: Path.join(@fixtures_dir, "types_extended.jsonl"),
        item_groups: Path.join(@fixtures_dir, "groups_extended.jsonl"),
        item_categories: Path.join(@fixtures_dir, "categories_sample.jsonl")
      }

      assert {:ok, item_types} = ItemTypeProcessor.process_item_data_jsonl(file_paths)

      # Find the Dragonfly I
      fighter = Enum.find(item_types, &(&1.type_id == 40340))
      assert fighter != nil
      assert fighter.is_fighter == true
      assert fighter.category_name == "Fighter"
    end

    test "correctly identifies structures" do
      file_paths = %{
        item_types: Path.join(@fixtures_dir, "types_extended.jsonl"),
        item_groups: Path.join(@fixtures_dir, "groups_extended.jsonl"),
        item_categories: Path.join(@fixtures_dir, "categories_sample.jsonl")
      }

      assert {:ok, item_types} = ItemTypeProcessor.process_item_data_jsonl(file_paths)

      # Find the Astrahus
      structure = Enum.find(item_types, &(&1.type_id == 35833))
      assert structure != nil
      assert structure.is_deployable == true
      assert structure.category_name == "Structure"
    end

    test "builds search keywords correctly" do
      file_paths = %{
        item_types: Path.join(@fixtures_dir, "types_extended.jsonl"),
        item_groups: Path.join(@fixtures_dir, "groups_extended.jsonl"),
        item_categories: Path.join(@fixtures_dir, "categories_sample.jsonl")
      }

      assert {:ok, item_types} = ItemTypeProcessor.process_item_data_jsonl(file_paths)

      rifter = Enum.find(item_types, &(&1.type_id == 587))
      assert rifter != nil
      assert is_list(rifter.search_keywords)
      assert "rifter" in rifter.search_keywords
      assert "frigate" in rifter.search_keywords
      assert "ship" in rifter.search_keywords
    end
  end

  describe "analyze_item_types/1" do
    test "returns statistics about item types" do
      file_paths = %{
        item_types: Path.join(@fixtures_dir, "types_extended.jsonl"),
        item_groups: Path.join(@fixtures_dir, "groups_extended.jsonl"),
        item_categories: Path.join(@fixtures_dir, "categories_sample.jsonl")
      }

      assert {:ok, item_types} = ItemTypeProcessor.process_item_data_jsonl(file_paths)

      stats = ItemTypeProcessor.analyze_item_types(item_types)

      assert is_map(stats)
      assert Map.has_key?(stats, :total_count)
      assert Map.has_key?(stats, :ships)
      assert Map.has_key?(stats, :modules)
      assert Map.has_key?(stats, :charges)
      assert Map.has_key?(stats, :deployables)

      # Verify counts are reasonable
      assert stats.total_count > 0
      assert stats.ships > 0
    end
  end

  describe "get_ship_types/1" do
    test "filters to only ship types" do
      file_paths = %{
        item_types: Path.join(@fixtures_dir, "types_extended.jsonl"),
        item_groups: Path.join(@fixtures_dir, "groups_extended.jsonl"),
        item_categories: Path.join(@fixtures_dir, "categories_sample.jsonl")
      }

      assert {:ok, item_types} = ItemTypeProcessor.process_item_data_jsonl(file_paths)

      ships = ItemTypeProcessor.get_ship_types(item_types)

      assert Enum.all?(ships, & &1.is_ship)
      assert length(ships) > 0
    end
  end

  describe "get_module_types/1" do
    test "filters to only module types" do
      file_paths = %{
        item_types: Path.join(@fixtures_dir, "types_extended.jsonl"),
        item_groups: Path.join(@fixtures_dir, "groups_extended.jsonl"),
        item_categories: Path.join(@fixtures_dir, "categories_sample.jsonl")
      }

      assert {:ok, item_types} = ItemTypeProcessor.process_item_data_jsonl(file_paths)

      modules = ItemTypeProcessor.get_module_types(item_types)

      assert Enum.all?(modules, & &1.is_module)
    end
  end
end
