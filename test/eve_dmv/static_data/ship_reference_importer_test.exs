defmodule EveDmv.StaticData.ShipReferenceImporterTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.StaticData.ShipReferenceImporter
  alias EveDmv.Repo
  import Ecto.Query

  describe "parse_ship_data/1" do
    test "parses ship data correctly" do
      sample_content = """
      # EVE Online Fleet Ship Reference

      ## Battleships (Mainline DPS and Support)

      - **Megathron** (Type ID: 641) – Gallente battleship known for its hybrid turrets.
      """

      {:ok, ships} = ShipReferenceImporter.parse_ship_data(sample_content)

      assert is_list(ships)
      assert length(ships) > 0

      # Find Megathron in the parsed data
      megathron = Enum.find(ships, &(&1.type_id == 641))
      assert megathron != nil
      assert megathron.name == "Megathron"
      assert megathron.reference_role == "sniper_dps"
      assert megathron.tank_type == "armor"
      assert megathron.engagement_range == "long"
      assert is_binary(megathron.tactical_notes)
      assert is_list(megathron.typical_doctrines)
    end

    test "includes major ship categories" do
      {:ok, ships} = ShipReferenceImporter.parse_ship_data("")

      ship_names = Enum.map(ships, & &1.name)

      # Check for key ships from different categories
      # Battleship
      assert "Megathron" in ship_names
      # Battlecruiser
      assert "Ferox" in ship_names
      # HAC
      assert "Muninn" in ship_names
      # Logistics
      assert "Guardian" in ship_names
      # Interdictor
      assert "Sabre" in ship_names
      # Pirate faction
      assert "Machariel" in ship_names
    end

    test "assigns appropriate roles to ships" do
      {:ok, ships} = ShipReferenceImporter.parse_ship_data("")

      ships_by_name = Enum.into(ships, %{}, &{&1.name, &1})

      # Test role assignments
      assert ships_by_name["Guardian"].reference_role == "armor_logistics"
      assert ships_by_name["Sabre"].reference_role == "fast_tackle"
      assert ships_by_name["Muninn"].reference_role == "alpha_dps"
      assert ships_by_name["Scorpion"].reference_role == "ewar_support"
      assert ships_by_name["Damnation"].reference_role == "armor_command"
    end
  end

  describe "parse_doctrine_data/1" do
    test "parses doctrine data correctly" do
      {:ok, doctrines} = ShipReferenceImporter.parse_doctrine_data("")

      assert is_list(doctrines)
      assert length(doctrines) > 0

      # Find a specific doctrine
      mach_fleet = Enum.find(doctrines, &(&1.doctrine_name == "mach_speed_fleet"))
      assert mach_fleet != nil
      assert mach_fleet.tank_type == "shield"
      assert mach_fleet.engagement_range == "medium_long"
      assert mach_fleet.tactical_role == "mobile_dps"
      assert mach_fleet.reference_source == "ship_info.md"
      assert is_map(mach_fleet.ship_composition)
    end

    test "includes major doctrine types" do
      {:ok, doctrines} = ShipReferenceImporter.parse_doctrine_data("")

      doctrine_names = Enum.map(doctrines, & &1.doctrine_name)

      # Check for key doctrines
      assert "armor_bs_sniper" in doctrine_names
      assert "mach_speed_fleet" in doctrine_names
      assert "ferox_railgun_fleet" in doctrine_names
      assert "muninn_artillery_fleet" in doctrine_names
    end
  end

  describe "database import (integration tests)" do
    test "imports ship patterns successfully" do
      # Test data
      ship_data = [
        %{
          type_id: 999_001,
          name: "Test Ship Alpha",
          reference_role: "test_dps",
          typical_doctrines: ["test_doctrine"],
          tank_type: "shield",
          engagement_range: "medium",
          tactical_notes: "Test ship for unit testing"
        }
      ]

      # Import the data
      {:ok, stats} = ShipReferenceImporter.import_ship_patterns(ship_data)

      assert stats.inserted >= 1

      # Verify data was inserted
      imported =
        Repo.one(
          from(s in "ship_role_patterns",
            where: s.ship_type_id == 999_001,
            select: %{
              ship_type_id: s.ship_type_id,
              ship_name: s.ship_name,
              primary_role: s.primary_role,
              reference_role: s.reference_role,
              tactical_notes: s.tactical_notes
            }
          )
        )

      assert imported != nil
      assert imported.ship_name == "Test Ship Alpha"
      assert imported.reference_role == "test_dps"
      assert imported.primary_role == "test_dps"
      assert imported.tactical_notes == "Test ship for unit testing"
    end

    test "imports doctrine patterns successfully" do
      # Test data
      doctrine_data = [
        %{
          doctrine_name: "test_doctrine",
          ship_composition: %{999_001 => 10, 999_002 => 2},
          tank_type: "armor",
          engagement_range: "long",
          tactical_role: "sniper",
          reference_source: "test"
        }
      ]

      # Import the data
      {:ok, stats} = ShipReferenceImporter.import_doctrine_patterns(doctrine_data)

      assert stats.inserted >= 1

      # Verify data was inserted
      imported =
        Repo.one(
          from(d in "doctrine_patterns",
            where: d.doctrine_name == "test_doctrine",
            select: %{
              doctrine_name: d.doctrine_name,
              ship_composition: d.ship_composition,
              tank_type: d.tank_type,
              engagement_range: d.engagement_range,
              tactical_role: d.tactical_role
            }
          )
        )

      assert imported != nil
      assert imported.tank_type == "armor"
      assert imported.engagement_range == "long"
      assert imported.tactical_role == "sniper"
      assert imported.ship_composition == %{"999001" => 10, "999002" => 2}
    end

    test "handles upserts correctly" do
      ship_data = [
        %{
          type_id: 999_003,
          name: "Test Ship Beta",
          reference_role: "test_role",
          typical_doctrines: ["test"],
          tank_type: "armor",
          engagement_range: "close",
          tactical_notes: "Original notes"
        }
      ]

      # First import
      {:ok, stats1} = ShipReferenceImporter.import_ship_patterns(ship_data)
      assert stats1.inserted >= 1

      # Update the data
      updated_ship_data = [
        %{
          type_id: 999_003,
          name: "Test Ship Beta Updated",
          reference_role: "updated_role",
          typical_doctrines: ["updated_test"],
          tank_type: "shield",
          engagement_range: "long",
          tactical_notes: "Updated notes"
        }
      ]

      # Second import (should update)
      {:ok, stats2} = ShipReferenceImporter.import_ship_patterns(updated_ship_data)
      assert stats2.updated >= 1

      # Verify update
      updated =
        Repo.one(
          from(s in "ship_role_patterns",
            where: s.ship_type_id == 999_003,
            select: %{
              ship_type_id: s.ship_type_id,
              ship_name: s.ship_name,
              primary_role: s.primary_role,
              reference_role: s.reference_role,
              tactical_notes: s.tactical_notes
            }
          )
        )

      assert updated.ship_name == "Test Ship Beta Updated"
      assert updated.reference_role == "updated_role"
      assert updated.tactical_notes == "Updated notes"
    end
  end

  describe "full import process" do
    @tag timeout: 60_000
    test "imports all reference data successfully" do
      # This test requires the actual ship_info.md file to exist
      case File.exists?("docs/reference/ship_info.md") do
        true ->
          {:ok, stats} = ShipReferenceImporter.import_all()

          assert stats.ships_imported > 0
          assert stats.doctrines_imported > 0

          # Verify some key ships were imported
          megathron =
            Repo.one(
              from(s in "ship_role_patterns",
                where: s.ship_type_id == 641,
                select: %{
                  ship_type_id: s.ship_type_id,
                  ship_name: s.ship_name,
                  primary_role: s.primary_role
                }
              )
            )

          assert megathron != nil
          assert megathron.ship_name == "Megathron"

          # Verify some doctrines were imported
          doctrine_count = Repo.one(from(d in "doctrine_patterns", select: count(d.id)))
          assert doctrine_count > 0

        false ->
          # Skip test if file doesn't exist
          assert true
      end
    end
  end
end
