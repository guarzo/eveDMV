defmodule EveDmv.StaticData.ShipTypesTest do
  use EveDmv.DataCase, async: true
  alias EveDmv.StaticData.ShipTypes
  alias EveDmv.Eve.ItemType

  describe "classify_ship_type/1" do
    setup do
      # Create some test ship data
      {:ok, _rifter} =
        ItemType.create(%{
          type_id: 587,
          type_name: "Rifter",
          group_name: "Frigate",
          is_ship: true,
          published: true
        })

      {:ok, _caracal} =
        ItemType.create(%{
          type_id: 621,
          type_name: "Caracal",
          group_name: "Cruiser",
          is_ship: true,
          published: true
        })

      {:ok, _raven} =
        ItemType.create(%{
          type_id: 638,
          type_name: "Raven",
          group_name: "Battleship",
          is_ship: true,
          published: true
        })

      {:ok, _venture} =
        ItemType.create(%{
          type_id: 32_880,
          type_name: "Venture",
          group_name: "Mining Barge",
          is_ship: true,
          published: true
        })

      {:ok, _ares} =
        ItemType.create(%{
          type_id: 11202,
          type_name: "Ares",
          group_name: "Interceptor",
          is_ship: true,
          published: true
        })

      {:ok, _scimitar} =
        ItemType.create(%{
          type_id: 11978,
          type_name: "Scimitar",
          group_name: "Logistics Cruiser",
          is_ship: true,
          published: true
        })

      {:ok, _archon} =
        ItemType.create(%{
          type_id: 23757,
          type_name: "Archon",
          group_name: "Carrier",
          is_ship: true,
          published: true
        })

      {:ok, _avatar} =
        ItemType.create(%{
          type_id: 11567,
          type_name: "Avatar",
          group_name: "Titan",
          is_ship: true,
          published: true
        })

      :ok
    end

    test "classifies frigates correctly" do
      assert ShipTypes.classify_ship_type(587) == :frigate
      # Interceptor is a frigate
      assert ShipTypes.classify_ship_type(11_202) == :frigate
    end

    test "classifies cruisers correctly" do
      assert ShipTypes.classify_ship_type(621) == :cruiser
      # Logistics cruiser
      assert ShipTypes.classify_ship_type(11_978) == :cruiser
    end

    test "classifies battleships correctly" do
      assert ShipTypes.classify_ship_type(638) == :battleship
    end

    test "classifies mining ships correctly" do
      assert ShipTypes.classify_ship_type(32_880) == :mining
    end

    test "classifies capital ships correctly" do
      assert ShipTypes.classify_ship_type(23_757) == :capital
    end

    test "classifies supercapital ships correctly" do
      assert ShipTypes.classify_ship_type(11_567) == :supercapital
    end

    test "returns :unknown for non-existent ships" do
      assert ShipTypes.classify_ship_type(999_999) == :unknown
    end

    test "returns :unknown for non-integer input" do
      assert ShipTypes.classify_ship_type("not a number") == :unknown
      assert ShipTypes.classify_ship_type(nil) == :unknown
    end
  end

  describe "is_ship_class?/2" do
    setup do
      {:ok, _rifter} =
        ItemType.create(%{
          type_id: 587,
          type_name: "Rifter",
          group_name: "Frigate",
          is_ship: true,
          published: true
        })

      :ok
    end

    test "correctly identifies ship classes" do
      assert ShipTypes.is_ship_class?(587, :frigate) == true
      assert ShipTypes.is_ship_class?(587, :cruiser) == false
      assert ShipTypes.is_ship_class?(587, :battleship) == false
    end
  end

  describe "get_ship_ids_for_class/1" do
    setup do
      # Create multiple ships of the same class
      {:ok, _rifter} =
        ItemType.create(%{
          type_id: 587,
          type_name: "Rifter",
          group_name: "Frigate",
          is_ship: true,
          published: true
        })

      {:ok, _merlin} =
        ItemType.create(%{
          type_id: 603,
          type_name: "Merlin",
          group_name: "Frigate",
          is_ship: true,
          published: true
        })

      {:ok, _ares} =
        ItemType.create(%{
          type_id: 11202,
          type_name: "Ares",
          group_name: "Interceptor",
          is_ship: true,
          published: true
        })

      :ok
    end

    test "returns all ship IDs for a given class" do
      frigate_ids = ShipTypes.get_ship_ids_for_class(:frigate)
      assert 587 in frigate_ids
      assert 603 in frigate_ids
      # Interceptors are frigates
      assert 11_202 in frigate_ids
    end

    test "returns empty list for invalid class" do
      assert ShipTypes.get_ship_ids_for_class(:invalid_class) == []
    end
  end

  describe "tactical functions" do
    setup do
      {:ok, _rifter} =
        ItemType.create(%{
          type_id: 587,
          type_name: "Rifter",
          group_name: "Frigate",
          is_ship: true,
          published: true
        })

      {:ok, _caracal} =
        ItemType.create(%{
          type_id: 621,
          type_name: "Caracal",
          group_name: "Cruiser",
          is_ship: true,
          published: true
        })

      {:ok, _thrasher} =
        ItemType.create(%{
          type_id: 16242,
          type_name: "Thrasher",
          group_name: "Destroyer",
          is_ship: true,
          published: true
        })

      :ok
    end

    test "is_tackle_ship? identifies tackle ships" do
      # Frigate
      assert ShipTypes.is_tackle_ship?(587) == true
      # Destroyer
      assert ShipTypes.is_tackle_ship?(16_242) == true
      # Cruiser
      assert ShipTypes.is_tackle_ship?(621) == false
    end

    test "is_dps_ship? identifies DPS platforms" do
      # Cruiser
      assert ShipTypes.is_dps_ship?(621) == true
      # Frigate
      assert ShipTypes.is_dps_ship?(587) == false
      # Destroyer
      assert ShipTypes.is_dps_ship?(16_242) == false
    end

    test "tactical_ship_groups returns correct groupings" do
      groups = ShipTypes.tactical_ship_groups()

      assert groups.tackle == [:frigate, :destroyer]
      assert groups.dps == [:cruiser, :battlecruiser, :battleship]
      assert groups.support == [:cruiser, :battlecruiser]
      assert groups.capital == [:capital, :supercapital]
      assert groups.industrial == [:industrial, :mining]
    end
  end

  describe "specialized role detection" do
    setup do
      {:ok, _ares} =
        ItemType.create(%{
          type_id: 11202,
          type_name: "Ares",
          group_name: "Interceptor",
          is_ship: true,
          published: true
        })

      {:ok, _scimitar} =
        ItemType.create(%{
          type_id: 11978,
          type_name: "Scimitar",
          group_name: "Logistics Cruiser",
          is_ship: true,
          published: true
        })

      {:ok, _kitsune} =
        ItemType.create(%{
          type_id: 11174,
          type_name: "Kitsune",
          group_name: "Electronic Attack Frigate",
          is_ship: true,
          published: true
        })

      :ok
    end

    test "is_interceptor? correctly identifies interceptors" do
      assert ShipTypes.is_interceptor?(11_202) == true
      assert ShipTypes.is_interceptor?(11_978) == false
    end

    test "is_logistics? correctly identifies logistics ships" do
      assert ShipTypes.is_logistics?(11_978) == true
      assert ShipTypes.is_logistics?(11_202) == false
    end

    test "is_ewar? correctly identifies EWAR ships" do
      assert ShipTypes.is_ewar?(11_174) == true
      assert ShipTypes.is_ewar?(11_202) == false
    end

    test "is_support_ship? identifies both logistics and EWAR" do
      # Logistics
      assert ShipTypes.is_support_ship?(11_978) == true
      # EWAR
      assert ShipTypes.is_support_ship?(11_174) == true
      # Interceptor
      assert ShipTypes.is_support_ship?(11_202) == false
    end

    test "ship ID getter functions return correct lists" do
      interceptor_ids = ShipTypes.interceptor_ship_ids()
      logistics_ids = ShipTypes.logistics_ship_ids()
      ewar_ids = ShipTypes.ewar_ship_ids()

      assert 11_202 in interceptor_ids
      assert 11_978 in logistics_ids
      assert 11_174 in ewar_ids
    end
  end

  describe "edge cases and error handling" do
    test "handles non-ship items gracefully" do
      # Create a non-ship item
      {:ok, _ammo} =
        ItemType.create(%{
          type_id: 12345,
          type_name: "Some Ammo",
          group_name: "Projectile Ammo",
          is_ship: false,
          published: true
        })

      assert ShipTypes.classify_ship_type(12_345) == :unknown
    end

    test "handles unpublished ships" do
      # Create an unpublished ship
      {:ok, _test_ship} =
        ItemType.create(%{
          type_id: 99999,
          type_name: "Test Ship",
          group_name: "Frigate",
          is_ship: true,
          published: false
        })

      # Should not appear in class listings
      frigate_ids = ShipTypes.get_ship_ids_for_class(:frigate)
      refute 99_999 in frigate_ids
    end
  end

  describe "deprecated functions" do
    test "ship_type_ranges returns empty ranges" do
      ranges = ShipTypes.ship_type_ranges()

      assert ranges.frigate == []
      assert ranges.destroyer == []
      assert ranges.cruiser == []
      assert ranges.battlecruiser == []
      assert ranges.battleship == []
      assert ranges.capital == []
      assert ranges.industrial == []
      assert ranges.mining == []
      assert ranges.supercapital == []
    end
  end
end
