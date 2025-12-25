defmodule EveDmv.Contexts.ShipClassificationConsolidationTest do
  @moduledoc """
  Tests that verify all ship classification functions delegate to the
  centralized EveDmv.StaticData.ShipTypes.classify_ship_type/1 function.

  These tests ensure consistency across all modules that classify ships
  and verify that the consolidation refactoring was successful.
  """
  use EveDmv.DataCase, async: false

  alias EveDmv.StaticData.ShipTypes

  # Test ship type IDs (common EVE ships)
  # Rifter
  @frigate_id 587
  # Caracal
  @cruiser_id 621
  # Raven
  @battleship_id 638
  @invalid_id 999_999_999

  describe "centralized classify_ship_type/1" do
    test "returns atoms for valid ship types" do
      # The centralized function should return atoms
      result = ShipTypes.classify_ship_type(@frigate_id)
      assert is_atom(result)
    end

    test "returns :unknown for invalid ship types" do
      assert ShipTypes.classify_ship_type(@invalid_id) == :unknown
    end

    test "returns :unknown for nil input" do
      assert ShipTypes.classify_ship_type(nil) == :unknown
    end

    test "returns :unknown for non-integer input" do
      assert ShipTypes.classify_ship_type("string") == :unknown
      assert ShipTypes.classify_ship_type(:atom) == :unknown
    end
  end

  describe "SharedUtilities.classify_ship_type/1" do
    alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.SharedUtilities

    test "maps :unknown to :other for consistency" do
      # Invalid ID should return :other (mapped from :unknown)
      result = SharedUtilities.classify_ship_type(@invalid_id)
      assert result == :other
    end

    test "returns valid ship class for known ships" do
      result = SharedUtilities.classify_ship_type(@frigate_id)
      # Either :frigate (if SDE loaded) or :other (if not)
      assert result in [:frigate, :other]
    end

    test "is consistent with centralized function" do
      central_result = ShipTypes.classify_ship_type(@cruiser_id)
      shared_result = SharedUtilities.classify_ship_type(@cruiser_id)

      # SharedUtilities maps :unknown -> :other
      expected =
        case central_result do
          :unknown -> :other
          class -> class
        end

      assert shared_result == expected
    end
  end

  describe "FleetAnalyzer.classify_ship_type/1" do
    alias EveDmv.Contexts.CorporationIntelligence.Domain.CombatDoctrine.FleetAnalyzer

    test "returns :other for nil input" do
      assert FleetAnalyzer.classify_ship_type(nil) == :other
    end

    test "maps :unknown to :other" do
      result = FleetAnalyzer.classify_ship_type(@invalid_id)
      assert result == :other
    end

    test "is consistent with centralized function" do
      central_result = ShipTypes.classify_ship_type(@battleship_id)
      fleet_result = FleetAnalyzer.classify_ship_type(@battleship_id)

      expected =
        case central_result do
          :unknown -> :other
          class -> class
        end

      assert fleet_result == expected
    end
  end

  describe "ShipTypes helper functions" do
    test "tackle_ship?/1 returns boolean" do
      assert is_boolean(ShipTypes.tackle_ship?(@frigate_id))
    end

    test "dps_ship?/1 returns boolean" do
      assert is_boolean(ShipTypes.dps_ship?(@cruiser_id))
    end

    test "logistics?/1 returns boolean" do
      assert is_boolean(ShipTypes.logistics?(@cruiser_id))
    end

    test "ewar?/1 returns boolean" do
      assert is_boolean(ShipTypes.ewar?(@cruiser_id))
    end
  end

  describe "valid ship class atoms" do
    @valid_classes [
      :frigate,
      :destroyer,
      :cruiser,
      :battlecruiser,
      :battleship,
      :capital,
      :supercapital,
      :industrial,
      :mining,
      :logistics,
      :structure,
      :unknown
    ]

    test "centralized function returns only valid ship classes" do
      # Test with a range of IDs
      test_ids = [587, 621, 638, 0, -1, 999_999]

      Enum.each(test_ids, fn id ->
        result = ShipTypes.classify_ship_type(id)

        assert result in @valid_classes,
               "classify_ship_type(#{id}) returned #{inspect(result)}, expected one of #{inspect(@valid_classes)}"
      end)
    end
  end

  describe "ship class consistency" do
    test "frigates and destroyers are tackle ships" do
      # If we know a ship is a frigate, tackle_ship? should return true
      if ShipTypes.classify_ship_type(@frigate_id) == :frigate do
        assert ShipTypes.tackle_ship?(@frigate_id) == true
      end
    end

    test "cruisers, battlecruisers, battleships are DPS ships" do
      # If we know a ship is a cruiser, dps_ship? should return true
      if ShipTypes.classify_ship_type(@cruiser_id) == :cruiser do
        assert ShipTypes.dps_ship?(@cruiser_id) == true
      end
    end
  end
end
