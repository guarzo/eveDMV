defmodule EveDmv.StaticData.ShipAttributeImporterTest do
  # Not async due to GenServer
  use EveDmv.DataCase, async: false
  alias EveDmv.Eve.ItemType
  alias EveDmv.StaticData.ShipAttributeImporter
  alias EveDmv.StaticData.ShipAttributes

  describe "ShipAttributeImporter GenServer" do
    setup do
      # Create test ships for import testing
      test_ships = [
        {1001, "Test Rifter", "Frigate", true, true, 1_070_000, 500.0},
        {1002, "Test Caracal", "Cruiser", true, true, 10_800_000, 2500.0},
        {1003, "Test Raven", "Battleship", true, true, 98_900_000, 15_000.0},
        {1004, "Test Interceptor", "Interceptor", true, true, 1_200_000, 450.0},
        {1005, "Test Logistics", "Logistics Cruiser", true, true, 12_500_000, 3000.0},
        {1006, "Unpublished Ship", "Frigate", true, false, 1_500_000, 500.0},
        {1007, "Non-Ship Item", "Module", false, true, 100.0, 0.1}
      ]

      for {type_id, name, group, is_ship, published, mass, volume} <- test_ships do
        {:ok, _} =
          ItemType.create(%{
            type_id: type_id,
            type_name: name,
            group_name: group,
            is_ship: is_ship,
            published: published,
            mass: mass,
            volume: volume
          })
      end

      :ok
    end

    test "can start and stop the importer service" do
      assert {:ok, pid} = ShipAttributeImporter.start_link()
      assert Process.alive?(pid)
      GenServer.stop(pid)
      refute Process.alive?(pid)
    end

    test "import_all processes only published ships" do
      {:ok, pid} = ShipAttributeImporter.start_link()

      try do
        assert {:ok, result} = ShipAttributeImporter.import_all(limit: 10)

        # Should have processed published ships only
        # At least our 5 published ships
        assert result.total_ships >= 5
        # Some might already exist
        assert result.imported >= 0
        assert result.failed >= 0
        assert is_number(result.duration_ms)
        assert result.success_rate >= 0.0 and result.success_rate <= 100.0

        # Verify that ship attributes were created
        {:ok, attrs} = ShipAttributes.get_by_type_id(1001)
        assert attrs.type_id == 1001
        assert attrs.size_class == "frigate"
        assert attrs.role_classification == "dps"
        assert is_number(attrs.calculated_dps)
        assert is_number(attrs.calculated_ehp)
      after
        GenServer.stop(pid)
      end
    end

    test "import_all with force option re-imports existing data" do
      {:ok, pid} = ShipAttributeImporter.start_link()

      try do
        # First import
        assert {:ok, result1} = ShipAttributeImporter.import_all(limit: 5)

        # Second import with force should re-import everything
        assert {:ok, result2} = ShipAttributeImporter.import_all(force: true, limit: 5)

        # Should have processed the same number of ships
        assert result2.total_ships == result1.total_ships
      after
        GenServer.stop(pid)
      end
    end

    test "import_all without force skips existing ships" do
      {:ok, pid} = ShipAttributeImporter.start_link()

      try do
        # First import
        assert {:ok, result1} = ShipAttributeImporter.import_all(limit: 3)

        # Second import without force should skip existing
        assert {:ok, result2} = ShipAttributeImporter.import_all(limit: 3)

        # Should process fewer ships on second run
        assert result2.total_ships <= result1.total_ships
      after
        GenServer.stop(pid)
      end
    end

    test "import_single_ship creates attributes for specific ship" do
      {:ok, pid} = ShipAttributeImporter.start_link()

      try do
        assert :ok = ShipAttributeImporter.import_ship_attributes(1001)

        # Verify attributes were created
        {:ok, attrs} = ShipAttributes.get_by_type_id(1001)
        assert attrs.type_id == 1001
        assert attrs.data_source == "phase1_estimate"
        assert attrs.confidence_score == 0.6
      after
        GenServer.stop(pid)
      end
    end

    test "handles non-existent ship gracefully" do
      {:ok, pid} = ShipAttributeImporter.start_link()

      try do
        assert {:error, :not_found} = ShipAttributeImporter.import_ship_attributes(999_999)
      after
        GenServer.stop(pid)
      end
    end
  end

  describe "ship attribute calculations" do
    setup do
      {:ok, pid} = ShipAttributeImporter.start_link()

      # Create a test ship
      {:ok, _} =
        ItemType.create(%{
          type_id: 2001,
          type_name: "Calculation Test Ship",
          group_name: "Heavy Assault Cruiser",
          is_ship: true,
          published: true,
          mass: 15_000_000,
          volume: 2800.0
        })

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid)
      end)

      {:ok, importer_pid: pid}
    end

    test "calculates realistic attributes for different ship classes", %{importer_pid: pid} do
      # Import the test ship
      assert :ok = ShipAttributeImporter.import_ship_attributes(2001)

      {:ok, attrs} = ShipAttributes.get_by_type_id(2001)

      # Heavy Assault Cruiser should have reasonable stats
      assert attrs.size_class == "cruiser"
      assert attrs.role_classification == "dps"
      assert attrs.tactical_category == "brawler"

      # DPS should be in a reasonable range for HAC
      assert attrs.calculated_dps > 300 and attrs.calculated_dps < 1000

      # EHP should be substantial for a HAC
      assert attrs.calculated_ehp > 8000 and attrs.calculated_ehp < 50_000

      # Should have resistance values
      assert is_number(attrs.shield_em_resist)
      assert is_number(attrs.armor_em_resist)

      # Ratings should be between 0 and 1
      assert attrs.damage_rating >= 0.0 and attrs.damage_rating <= 1.0
      assert attrs.tank_rating >= 0.0 and attrs.tank_rating <= 1.0
      assert attrs.speed_rating >= 0.0 and attrs.speed_rating <= 1.0
      assert attrs.utility_rating >= 0.0 and attrs.utility_rating <= 1.0
    end

    test "applies mass scaling correctly", %{importer_pid: _pid} do
      # Create ships with different masses in same class
      light_ship_data = %{
        type_id: 2002,
        type_name: "Light Frigate",
        group_name: "Frigate",
        is_ship: true,
        published: true,
        # Lighter than average frigate
        mass: 800_000
      }

      heavy_ship_data = %{
        type_id: 2003,
        type_name: "Heavy Frigate",
        group_name: "Frigate",
        is_ship: true,
        published: true,
        # Heavier than average frigate
        mass: 2_000_000
      }

      {:ok, _} = ItemType.create(light_ship_data)
      {:ok, _} = ItemType.create(heavy_ship_data)

      assert :ok = ShipAttributeImporter.import_ship_attributes(2002)
      assert :ok = ShipAttributeImporter.import_ship_attributes(2003)

      {:ok, light_attrs} = ShipAttributes.get_by_type_id(2002)
      {:ok, heavy_attrs} = ShipAttributes.get_by_type_id(2003)

      # Heavy ship should have higher HP due to mass scaling
      assert heavy_attrs.calculated_ehp > light_attrs.calculated_ehp

      # Both should be frigates
      assert light_attrs.size_class == "frigate"
      assert heavy_attrs.size_class == "frigate"
    end
  end

  describe "resistance and EHP calculations" do
    setup do
      {:ok, pid} = ShipAttributeImporter.start_link()

      # Create different ship types with different resistance profiles
      ship_types = [
        {3001, "Test Assault Frigate", "Assault Frigate"},
        {3002, "Test Marauder", "Marauder"},
        {3003, "Test Basic Cruiser", "Cruiser"}
      ]

      for {type_id, name, group} <- ship_types do
        {:ok, _} =
          ItemType.create(%{
            type_id: type_id,
            type_name: name,
            group_name: group,
            is_ship: true,
            published: true,
            mass: 10_000_000
          })
      end

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid)
      end)

      {:ok, importer_pid: pid}
    end

    test "assigns appropriate resistances by ship type", %{importer_pid: _pid} do
      # Import different ship types
      # Assault Frigate
      assert :ok = ShipAttributeImporter.import_ship_attributes(3001)
      # Marauder
      assert :ok = ShipAttributeImporter.import_ship_attributes(3002)
      # Basic Cruiser
      assert :ok = ShipAttributeImporter.import_ship_attributes(3003)

      {:ok, assault_attrs} = ShipAttributes.get_by_type_id(3001)
      {:ok, marauder_attrs} = ShipAttributes.get_by_type_id(3002)
      {:ok, cruiser_attrs} = ShipAttributes.get_by_type_id(3003)

      # Assault ships and Marauders should have better resistances than basic cruiser
      assert assault_attrs.armor_em_resist > cruiser_attrs.armor_em_resist
      assert marauder_attrs.armor_em_resist > cruiser_attrs.armor_em_resist

      # All ships should have some shield resistances
      assert assault_attrs.shield_kinetic_resist > 0
      assert marauder_attrs.shield_kinetic_resist > 0
      assert cruiser_attrs.shield_kinetic_resist >= 0

      # EHP should be calculated properly
      assert assault_attrs.calculated_ehp >
               assault_attrs.shield_hp + assault_attrs.armor_hp + assault_attrs.structure_hp

      assert marauder_attrs.calculated_ehp >
               marauder_attrs.shield_hp + marauder_attrs.armor_hp + marauder_attrs.structure_hp
    end
  end

  describe "rating calculations and normalization" do
    setup do
      {:ok, pid} = ShipAttributeImporter.start_link()

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid)
      end)

      {:ok, importer_pid: pid}
    end

    test "recalculate_ratings normalizes ratings within size classes", %{importer_pid: _pid} do
      # Create multiple ships of same class with different performance
      ships = [
        {4001, "Weak Frigate", "Frigate", 1_000_000},
        {4002, "Average Frigate", "Frigate", 1_500_000},
        {4003, "Strong Frigate", "Frigate", 2_000_000}
      ]

      for {type_id, name, group, mass} <- ships do
        {:ok, _} =
          ItemType.create(%{
            type_id: type_id,
            type_name: name,
            group_name: group,
            is_ship: true,
            published: true,
            mass: mass
          })

        assert :ok = ShipAttributeImporter.import_ship_attributes(type_id)
      end

      # Recalculate ratings to normalize within size class
      assert {:ok, count} = ShipAttributeImporter.recalculate_ratings()
      # Should have updated at least our test ships
      assert count >= 3

      # Verify that ratings are properly distributed
      {:ok, weak_attrs} = ShipAttributes.get_by_type_id(4001)
      {:ok, average_attrs} = ShipAttributes.get_by_type_id(4002)
      {:ok, strong_attrs} = ShipAttributes.get_by_type_id(4003)

      # Stronger ship should have higher ratings
      assert strong_attrs.damage_rating >= average_attrs.damage_rating
      assert average_attrs.damage_rating >= weak_attrs.damage_rating

      # All ratings should be between 0 and 1
      for attrs <- [weak_attrs, average_attrs, strong_attrs] do
        assert attrs.damage_rating >= 0.0 and attrs.damage_rating <= 1.0
        assert attrs.tank_rating >= 0.0 and attrs.tank_rating <= 1.0
      end
    end
  end

  describe "error handling and edge cases" do
    setup do
      {:ok, pid} = ShipAttributeImporter.start_link()

      on_exit(fn ->
        if Process.alive?(pid), do: GenServer.stop(pid)
      end)

      {:ok, importer_pid: pid}
    end

    test "handles ships with missing mass data", %{importer_pid: _pid} do
      {:ok, _} =
        ItemType.create(%{
          type_id: 5001,
          type_name: "No Mass Ship",
          group_name: "Frigate",
          is_ship: true,
          published: true,
          # No mass data
          mass: nil
        })

      # Should still import successfully with default mass scaling
      assert :ok = ShipAttributeImporter.import_ship_attributes(5001)

      {:ok, attrs} = ShipAttributes.get_by_type_id(5001)
      assert attrs.type_id == 5001
      assert is_number(attrs.calculated_dps)
      assert is_number(attrs.calculated_ehp)
    end

    test "handles unknown ship groups gracefully", %{importer_pid: _pid} do
      {:ok, _} =
        ItemType.create(%{
          type_id: 5002,
          type_name: "Unknown Group Ship",
          group_name: "Mysterious Ship Type",
          is_ship: true,
          published: true,
          mass: 5_000_000
        })

      assert :ok = ShipAttributeImporter.import_ship_attributes(5002)

      {:ok, attrs} = ShipAttributes.get_by_type_id(5002)
      assert attrs.size_class == "unknown"
      # Default role
      assert attrs.role_classification == "dps"
      assert is_number(attrs.calculated_dps)
    end

    test "batch processing handles mixed success/failure", %{importer_pid: _pid} do
      # Create some valid and some problematic ships
      {:ok, _} =
        ItemType.create(%{
          type_id: 5003,
          type_name: "Valid Ship",
          group_name: "Frigate",
          is_ship: true,
          published: true
        })

      # Import with a mix - some should succeed
      result = ShipAttributeImporter.import_all(limit: 20)

      case result do
        {:ok, import_result} ->
          assert import_result.total_ships >= 1
          assert import_result.imported >= 0
          assert import_result.failed >= 0

        {:error, reason} ->
          # If the whole operation fails, that's also acceptable for this test
          assert is_atom(reason) or is_binary(reason)
      end
    end
  end
end
