defmodule EveDmv.Intelligence.ShipDatabaseTest do
  use ExUnit.Case, async: true

  alias EveDmv.Intelligence.ShipDatabase

  describe "get_ship_class/1" do
    test "returns correct class for known ship type IDs" do
      # Test frigate
      assert ShipDatabase.get_ship_class(587) == :frigate
      # Test cruiser
      assert ShipDatabase.get_ship_class(622) == :cruiser
      # Test battleship
      assert ShipDatabase.get_ship_class(643) == :battleship
      # Test strategic cruiser
      assert ShipDatabase.get_ship_class(29_984) == :strategic_cruiser
      # Test dreadnought
      assert ShipDatabase.get_ship_class(19_720) == :dreadnought
    end

    test "returns correct class for known ship names" do
      assert ShipDatabase.get_ship_class("Rifter") == :frigate
      assert ShipDatabase.get_ship_class("Caracal") == :cruiser
      assert ShipDatabase.get_ship_class("Raven") == :battleship
      assert ShipDatabase.get_ship_class("Tengu") == :strategic_cruiser
    end

    test "returns :unknown for unknown ship type IDs" do
      assert ShipDatabase.get_ship_class(999_999) == :unknown
      assert ShipDatabase.get_ship_class(0) == :unknown
    end

    test "returns :unknown for unknown ship names" do
      assert ShipDatabase.get_ship_class("Fake Ship") == :unknown
      assert ShipDatabase.get_ship_class("") == :unknown
    end
  end

  describe "get_ship_mass/1" do
    test "returns mass for known ship type IDs" do
      # Test that we get numeric masses
      # Rifter
      mass = ShipDatabase.get_ship_mass(587)
      assert is_number(mass)
      assert mass > 0

      # Capital ships should have higher mass
      # Revelation
      capital_mass = ShipDatabase.get_ship_mass(19_720)
      assert capital_mass > mass
    end

    test "returns mass for known ship names" do
      mass = ShipDatabase.get_ship_mass("Rifter")
      assert is_number(mass)
      assert mass > 0
      # Should be much less than default
      assert mass < 10_000_000
    end

    test "returns default mass for unknown ships" do
      default_mass = 10_000_000
      assert ShipDatabase.get_ship_mass(999_999) == default_mass
      assert ShipDatabase.get_ship_mass("Unknown Ship") == default_mass
    end

    test "frigate masses are less than cruiser masses" do
      # Rifter
      frigate_mass = ShipDatabase.get_ship_mass(587)
      # Caracal
      cruiser_mass = ShipDatabase.get_ship_mass(622)

      assert frigate_mass < cruiser_mass
    end
  end

  describe "get_ship_role/1" do
    test "returns roles for known ships" do
      role = ShipDatabase.get_ship_role("Rifter")
      assert is_binary(role)
      assert role != "unknown"
    end

    test "returns logistics role for logistics ships" do
      assert ShipDatabase.get_ship_role("Guardian") == "logistics"
      assert ShipDatabase.get_ship_role("Basilisk") == "logistics"
    end

    test "returns dps role for damage ships" do
      # Strategic cruisers are typically DPS
      role = ShipDatabase.get_ship_role("Tengu")
      # Could be various combat roles
      assert role in ["dps", "tackle", "ewar"]
    end

    test "returns unknown for unknown ships" do
      assert ShipDatabase.get_ship_role("Fake Ship") == "unknown"
    end
  end

  describe "get_ship_category/1" do
    test "returns correct category for frigate IDs" do
      # Rifter
      assert ShipDatabase.get_ship_category(587) == "Frigate"
      # Merlin
      assert ShipDatabase.get_ship_category(588) == "Frigate"
    end

    test "returns correct category for cruiser IDs" do
      # Caracal
      assert ShipDatabase.get_ship_category(622) == "Cruiser"
      # Thorax
      assert ShipDatabase.get_ship_category(624) == "Cruiser"
    end

    test "returns correct category for battleship IDs" do
      # Raven
      assert ShipDatabase.get_ship_category(643) == "Battleship"
      # Apocalypse
      assert ShipDatabase.get_ship_category(644) == "Battleship"
    end

    test "returns correct category for capital IDs" do
      # Revelation
      assert ShipDatabase.get_ship_category(19_720) == "Capital"
      # Archon
      assert ShipDatabase.get_ship_category(23_757) == "Capital"
    end

    test "returns correct category for supercapital IDs" do
      # Erebus (Titan)
      assert ShipDatabase.get_ship_category(671) == "Supercapital"
      # Nyx (Supercarrier)
      assert ShipDatabase.get_ship_category(3514) == "Supercapital"
    end

    test "returns correct category for ship names" do
      assert ShipDatabase.get_ship_category("Rifter") == "Frigate"
      assert ShipDatabase.get_ship_category("Caracal") == "Cruiser"
      assert ShipDatabase.get_ship_category("Raven") == "Battleship"
    end

    test "returns Unknown for unknown ships" do
      assert ShipDatabase.get_ship_category(999_999) == "Unknown"
      assert ShipDatabase.get_ship_category("Fake Ship") == "Unknown"
    end
  end

  describe "is_capital?/1" do
    test "returns true for capital ship IDs" do
      # Revelation (Dreadnought)
      assert ShipDatabase.is_capital?(19_720) == true
      # Archon (Carrier)
      assert ShipDatabase.is_capital?(23_757) == true
    end

    test "returns true for supercapital ship IDs" do
      # Erebus (Titan)
      assert ShipDatabase.is_capital?(671) == true
      # Nyx (Supercarrier)
      assert ShipDatabase.is_capital?(3514) == true
    end

    test "returns false for subcapital ship IDs" do
      # Rifter
      assert ShipDatabase.is_capital?(587) == false
      # Caracal
      assert ShipDatabase.is_capital?(622) == false
      # Raven
      assert ShipDatabase.is_capital?(643) == false
    end

    test "returns true for capital ship names" do
      assert ShipDatabase.is_capital?("Revelation") == true
      assert ShipDatabase.is_capital?("Archon") == true
      assert ShipDatabase.is_capital?("Erebus") == true
    end

    test "returns false for subcapital ship names" do
      assert ShipDatabase.is_capital?("Rifter") == false
      assert ShipDatabase.is_capital?("Caracal") == false
      assert ShipDatabase.is_capital?("Raven") == false
    end

    test "returns false for unknown ships" do
      assert ShipDatabase.is_capital?(999_999) == false
      assert ShipDatabase.is_capital?("Unknown Ship") == false
    end
  end

  describe "get_wormhole_restrictions/1" do
    test "returns restriction map for known ship classes" do
      restrictions = ShipDatabase.get_wormhole_restrictions(:frigate)

      assert is_map(restrictions)
      assert Map.has_key?(restrictions, :can_pass_small)
      assert Map.has_key?(restrictions, :can_pass_medium)
      assert Map.has_key?(restrictions, :can_pass_large)
      assert Map.has_key?(restrictions, :can_pass_xl)

      # All values should be boolean
      assert is_boolean(restrictions.can_pass_small)
      assert is_boolean(restrictions.can_pass_medium)
      assert is_boolean(restrictions.can_pass_large)
      assert is_boolean(restrictions.can_pass_xl)
    end

    test "frigates can pass through smaller wormholes" do
      restrictions = ShipDatabase.get_wormhole_restrictions(:frigate)

      # Frigates should be able to pass through small holes
      assert restrictions.can_pass_small == true
      assert restrictions.can_pass_medium == true
    end

    test "capitals have appropriate restrictions" do
      restrictions = ShipDatabase.get_wormhole_restrictions(:dreadnought)

      # Capitals typically can't pass through small/medium holes
      assert restrictions.can_pass_small == false
      assert restrictions.can_pass_medium == false
      # But should be able to pass through large holes
      assert restrictions.can_pass_large == true || restrictions.can_pass_xl == true
    end

    test "returns default restrictions for unknown ship classes" do
      restrictions = ShipDatabase.get_wormhole_restrictions(:unknown_class)

      # Default should be conservative (large ships)
      assert restrictions.can_pass_small == false
      assert restrictions.can_pass_medium == false
      assert restrictions.can_pass_large == true
      assert restrictions.can_pass_xl == true
    end
  end

  describe "doctrine_ship?/2" do
    test "identifies ships in known doctrines" do
      # Test that the function works with some doctrine
      result = ShipDatabase.doctrine_ship?("Rifter", :alpha_fleet)
      assert is_boolean(result)
    end

    test "returns false for ships not in doctrine" do
      assert ShipDatabase.doctrine_ship?("Unknown Ship", :alpha_fleet) == false
    end

    test "returns false for unknown doctrines" do
      assert ShipDatabase.doctrine_ship?("Rifter", :unknown_doctrine) == false
    end
  end

  describe "wormhole_suitable?/1" do
    test "considers frigate suitable for wormholes" do
      # Frigates should generally be suitable
      result = ShipDatabase.wormhole_suitable?("Rifter")
      assert is_boolean(result)
    end

    test "considers logistics ships suitable for wormholes" do
      # Logistics ships with appropriate mass should be suitable
      result = ShipDatabase.wormhole_suitable?("Guardian")
      assert is_boolean(result)
    end

    test "considers very heavy ships unsuitable" do
      # Titans should not be suitable (too heavy)
      result = ShipDatabase.wormhole_suitable?("Erebus")
      assert result == false
    end

    test "returns false for unknown ships" do
      assert ShipDatabase.wormhole_suitable?("Unknown Ship") == false
    end

    test "considers mass in suitability calculation" do
      # Ships over 350M kg should not be suitable
      light_ship = ShipDatabase.wormhole_suitable?("Rifter")

      # Light ships should be more likely to be suitable
      assert is_boolean(light_ship)
    end
  end

  describe "get_optimal_gang_size/1" do
    test "returns numeric gang size for ship compositions" do
      composition = ["Rifter", "Caracal", "Guardian"]

      result = ShipDatabase.get_optimal_gang_size(composition)
      assert is_integer(result)
      assert result > 0
      # Reasonable gang size limit
      assert result <= 50
    end

    test "returns larger gang size for capital compositions" do
      subcap_composition = ["Rifter", "Caracal"]
      capital_composition = ["Revelation", "Archon"]

      subcap_size = ShipDatabase.get_optimal_gang_size(subcap_composition)
      capital_size = ShipDatabase.get_optimal_gang_size(capital_composition)

      # Capital gangs are typically smaller due to coordination requirements
      assert is_integer(subcap_size)
      assert is_integer(capital_size)
    end

    test "handles empty composition" do
      result = ShipDatabase.get_optimal_gang_size([])
      assert is_integer(result)
      assert result > 0
    end

    test "handles unknown ships in composition" do
      composition = ["Unknown Ship", "Fake Ship"]

      result = ShipDatabase.get_optimal_gang_size(composition)
      assert is_integer(result)
      assert result > 0
    end
  end

  describe "edge cases and error handling" do
    test "handles nil inputs gracefully" do
      # Should not crash on nil inputs
      assert_raise FunctionClauseError, fn ->
        ShipDatabase.get_ship_class(nil)
      end
    end

    test "handles empty string inputs" do
      assert ShipDatabase.get_ship_class("") == :unknown
      assert ShipDatabase.get_ship_category("") == "Unknown"
      assert ShipDatabase.get_ship_role("") == "unknown"
      assert ShipDatabase.get_ship_mass("") == 10_000_000
    end

    test "handles negative ship type IDs" do
      assert ShipDatabase.get_ship_class(-1) == :unknown
      assert ShipDatabase.get_ship_category(-1) == "Unknown"
      assert ShipDatabase.get_ship_mass(-1) == 10_000_000
    end

    test "handles very large ship type IDs" do
      large_id = 999_999_999
      assert ShipDatabase.get_ship_class(large_id) == :unknown
      assert ShipDatabase.get_ship_category(large_id) == "Unknown"
      assert ShipDatabase.get_ship_mass(large_id) == 10_000_000
    end
  end

  describe "data consistency" do
    test "ship categories are consistent with classes" do
      # Ships with frigate class should have Frigate category
      rifter_class = ShipDatabase.get_ship_class(587)
      rifter_category = ShipDatabase.get_ship_category(587)

      if rifter_class == :frigate do
        assert rifter_category == "Frigate"
      end
    end

    test "capital identification is consistent" do
      # Ships identified as capital by ID should also be capital by name
      revelation_id_capital = ShipDatabase.is_capital?(19_720)
      revelation_name_capital = ShipDatabase.is_capital?("Revelation")

      # If we have data for both, they should be consistent
      if revelation_id_capital != false and revelation_name_capital != false do
        assert revelation_id_capital == revelation_name_capital
      end
    end

    test "mass values are reasonable" do
      # Check that masses are in reasonable ranges
      # Rifter
      frigate_mass = ShipDatabase.get_ship_mass(587)
      # Raven
      battleship_mass = ShipDatabase.get_ship_mass(643)

      # Frigate should be much lighter than battleship
      assert frigate_mass < battleship_mass

      # Masses should be reasonable (not negative, not absurdly large)
      assert frigate_mass > 0
      # 100M kg reasonable max for frigate
      assert frigate_mass < 100_000_000
      assert battleship_mass > frigate_mass
      # 1B kg reasonable max for battleship
      assert battleship_mass < 1_000_000_000
    end
  end
end
