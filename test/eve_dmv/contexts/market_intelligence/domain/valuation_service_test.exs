defmodule EveDmv.Contexts.MarketIntelligence.Domain.ValuationServiceTest do
  use ExUnit.Case, async: false
  use EveDmv.DataCase, async: false
  alias EveDmv.Contexts.MarketIntelligence.Domain.ValuationService
  import Mox

  setup :verify_on_exit!

  # All tests in this module require Janice API mocking
  # Skipping until proper HTTP client mocking is implemented
  @moduletag :skip

  describe "calculate_killmail_value/1" do
    @tag :skip
    test "calculates value for killmail with ship only" do
      # This test requires mocking the Janice API client
      # Skipping until proper HTTP mocking is implemented
      killmail = %{
        killmail_id: 123_456,
        # Rifter
        victim_ship_type_id: 587,
        items: [],
        cargo_items: []
      }

      {:ok, valuation} = ValuationService.calculate_killmail_value(killmail)

      assert valuation.killmail_id == 123_456
      assert valuation.ship_value > 0
      assert valuation.destroyed_value == 0
      assert valuation.dropped_value == 0
      assert valuation.cargo_value == 0
      assert valuation.total_value == valuation.ship_value
    end

    test "calculates value for killmail with items" do
      killmail = %{
        killmail_id: 123_456,
        # Rifter
        victim_ship_type_id: 587,
        items: [
          # Damage Control
          %{"item_type_id" => 2048, "quantity_destroyed" => 1, "quantity_dropped" => 0},
          # Medium Shield Extender
          %{"item_type_id" => 3831, "quantity_destroyed" => 0, "quantity_dropped" => 1}
        ],
        cargo_items: []
      }

      {:ok, valuation} = ValuationService.calculate_killmail_value(killmail)

      assert valuation.destroyed_value > 0
      assert valuation.dropped_value > 0
      assert valuation.total_value > valuation.ship_value
    end

    test "uses fallback values when ship type is unknown" do
      killmail = %{
        killmail_id: 123_456,
        # Unknown ship
        victim_ship_type_id: 999_999,
        items: [],
        cargo_items: []
      }

      {:ok, valuation} = ValuationService.calculate_killmail_value(killmail)

      # Should use fallback value
      # Default unknown ship value
      assert valuation.ship_value == 10_000_000
    end
  end

  describe "calculate_fleet_value/1" do
    test "calculates total fleet value" do
      ships = [
        %{type_id: 587, type_name: "Rifter", quantity: 5},
        %{type_id: 620, type_name: "Osprey", quantity: 2},
        %{type_id: 638, type_name: "Raven", quantity: 1}
      ]

      {:ok, fleet_valuation} = ValuationService.calculate_fleet_value(ships)

      # 5 + 2 + 1
      assert fleet_valuation.total_ships == 8
      assert fleet_valuation.total_value > 0
      assert fleet_valuation.average_ship_value > 0
      assert length(fleet_valuation.ship_values) == 3
      assert is_map(fleet_valuation.value_by_class)
    end

    test "handles empty fleet" do
      {:ok, fleet_valuation} = ValuationService.calculate_fleet_value([])

      assert fleet_valuation.total_ships == 0
      assert fleet_valuation.total_value == 0
      assert fleet_valuation.average_ship_value == 0
      assert fleet_valuation.ship_values == []
    end

    test "groups ships by class based on value" do
      ships = [
        # Frigate
        %{type_id: 587, type_name: "Rifter", quantity: 10},
        # Cruiser
        %{type_id: 620, type_name: "Osprey", quantity: 5},
        # Battleship
        %{type_id: 638, type_name: "Raven", quantity: 2},
        # Capital
        %{type_id: 19724, type_name: "Thanatos", quantity: 1}
      ]

      {:ok, fleet_valuation} = ValuationService.calculate_fleet_value(ships)

      # Check that different ship classes are represented
      assert map_size(fleet_valuation.value_by_class) >= 3
      assert Map.has_key?(fleet_valuation.value_by_class, :frigate)
      assert Map.has_key?(fleet_valuation.value_by_class, :cruiser)
    end
  end
end
