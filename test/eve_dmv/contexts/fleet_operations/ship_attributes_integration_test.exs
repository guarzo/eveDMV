defmodule EveDmv.Contexts.FleetOperations.ShipAttributesIntegrationTest do
  use EveDmv.DataCase, async: true
  alias EveDmv.Contexts.FleetOperations.Analyzers.CompositionAnalyzer
  alias EveDmv.Contexts.FleetOperations.Domain.FleetAnalyzer
  alias EveDmv.Eve.ItemType
  alias EveDmv.StaticData.ShipAttributes
  alias EveDmv.StaticData.ShipTypes

  describe "FleetAnalyzer integration with ship attributes" do
    setup do
      # Create test ships and their attributes
      test_ships = [
        {1001, "Test Rifter", "Frigate", 150.0, 1200.0},
        {1002, "Test Caracal", "Cruiser", 400.0, 4500.0},
        {1003, "Test Raven", "Battleship", 800.0, 18_000.0},
        {1004, "Test Scimitar", "Logistics Cruiser", 80.0, 6000.0},
        {1005, "Test Interceptor", "Interceptor", 180.0, 900.0}
      ]

      for {type_id, name, group, dps, ehp} <- test_ships do
        # Create ship type
        {:ok, _} =
          ItemType.create(%{
            type_id: type_id,
            type_name: name,
            group_name: group,
            is_ship: true,
            published: true,
            mass: 10_000_000
          })

        # Create ship attributes
        {:ok, _} =
          ShipAttributes.create(%{
            type_id: type_id,
            calculated_dps: dps,
            calculated_ehp: ehp,
            role_classification: determine_role(group),
            size_class: determine_size(group),
            tactical_category: "brawler"
          })
      end

      :ok
    end

    test "ShipTypes.get_ship_dps returns real attribute values" do
      assert {:ok, 150.0} = ShipTypes.get_ship_dps(1001)
      assert {:ok, 400.0} = ShipTypes.get_ship_dps(1002)
      assert {:ok, 800.0} = ShipTypes.get_ship_dps(1003)
      assert {:ok, 80.0} = ShipTypes.get_ship_dps(1004)
      assert {:ok, 180.0} = ShipTypes.get_ship_dps(1005)
    end

    test "ShipTypes.get_ship_ehp returns real attribute values" do
      assert {:ok, 1200.0} = ShipTypes.get_ship_ehp(1001)
      assert {:ok, 4500.0} = ShipTypes.get_ship_ehp(1002)
      assert {:ok, 18_000.0} = ShipTypes.get_ship_ehp(1003)
      assert {:ok, 6000.0} = ShipTypes.get_ship_ehp(1004)
      assert {:ok, 900.0} = ShipTypes.get_ship_ehp(1005)
    end

    test "fleet composition analysis uses real ship data" do
      # Create mock fleet data
      fleet_data = %{
        fleet_id: 123,
        total_pilots: 5
      }

      participant_data = [
        %{ship_type_id: 1001, character_name: "Pilot1", ship_value: 5_000_000},
        %{ship_type_id: 1002, character_name: "Pilot2", ship_value: 25_000_000},
        %{ship_type_id: 1003, character_name: "Pilot3", ship_value: 150_000_000},
        %{ship_type_id: 1004, character_name: "Pilot4", ship_value: 80_000_000},
        %{ship_type_id: 1005, character_name: "Pilot5", ship_value: 15_000_000}
      ]

      # Analyze the fleet composition
      assert {:ok, analysis} =
               CompositionAnalyzer.analyze(123, %{
                 fleet_data: fleet_data,
                 participant_data: participant_data
               })

      # Verify that effectiveness metrics use real ship data
      effectiveness = analysis.effectiveness_metrics

      # Total DPS should be sum of real DPS values: 150 + 400 + 800 + 80 + 180 = 1610
      assert effectiveness.estimated_fleet_dps == 1610

      # Alpha strike should be roughly 2x DPS
      assert effectiveness.alpha_strike_potential >= 3000

      # EHP should be sum of real EHP values: 1200 + 4500 + 18_000 + 6000 + 900 = 30_600
      assert effectiveness.estimated_effective_hp == 30_600

      # Overall effectiveness should be calculated from real values
      assert is_number(effectiveness.overall_effectiveness)
      assert effectiveness.overall_effectiveness > 0
    end

    test "fleet analyzer falls back gracefully for unknown ships" do
      # Create ship without attributes
      {:ok, _} =
        ItemType.create(%{
          type_id: 9999,
          type_name: "Unknown Ship",
          group_name: "Frigate",
          is_ship: true,
          published: true
        })

      participant_data = [%{ship_type_id: 9999}]

      # Should fall back to classification-based estimation
      # Frigate fallback
      assert {:ok, 200} = ShipTypes.get_ship_dps(9999)
      # Frigate fallback
      assert {:ok, 15_000} = ShipTypes.get_ship_ehp(9999)
    end

    test "mixed fleet with real and fallback data" do
      # Create ship without attributes
      {:ok, _} =
        ItemType.create(%{
          type_id: 8888,
          type_name: "Fallback Ship",
          group_name: "Cruiser",
          is_ship: true,
          published: true
        })

      participant_data = [
        # Has real attributes (150 DPS)
        %{ship_type_id: 1001},
        # Falls back to cruiser estimate (600 DPS)
        %{ship_type_id: 8888}
      ]

      fleet_data = %{fleet_id: 456, total_pilots: 2}

      assert {:ok, analysis} =
               CompositionAnalyzer.analyze(456, %{
                 fleet_data: fleet_data,
                 participant_data: participant_data
               })

      # Should use mix of real and fallback data
      # 150 (real) + 600 (fallback) = 750
      assert analysis.effectiveness_metrics.estimated_fleet_dps == 750
    end
  end

  describe "CompositionAnalyzer real data integration" do
    setup do
      # Create diverse fleet with different ship types
      ships = [
        {2001, "DPS Frigate", "Assault Frigate", 220.0, 1800.0, "dps", "frigate"},
        {2002, "DPS Cruiser", "Heavy Assault Cruiser", 480.0, 8500.0, "dps", "cruiser"},
        {2003, "Logistics Ship", "Logistics Cruiser", 60.0, 7200.0, "logistics", "cruiser"},
        {2004, "EWAR Ship", "Electronic Attack Frigate", 90.0, 1100.0, "ewar", "frigate"},
        {2005, "Command Ship", "Command Ship", 350.0, 12_000.0, "support", "battlecruiser"}
      ]

      for {type_id, name, group, dps, ehp, role, size} <- ships do
        {:ok, _} =
          ItemType.create(%{
            type_id: type_id,
            type_name: name,
            group_name: group,
            is_ship: true,
            published: true
          })

        {:ok, _} =
          ShipAttributes.create(%{
            type_id: type_id,
            calculated_dps: dps,
            calculated_ehp: ehp,
            role_classification: role,
            size_class: size,
            tactical_category: "brawler"
          })
      end

      :ok
    end

    test "role distribution analysis uses real ship roles" do
      participant_data = [
        # DPS
        %{ship_type_id: 2001, character_name: "Pilot1"},
        # DPS
        %{ship_type_id: 2002, character_name: "Pilot2"},
        # Logistics
        %{ship_type_id: 2003, character_name: "Pilot3"},
        # EWAR
        %{ship_type_id: 2004, character_name: "Pilot4"},
        # Support
        %{ship_type_id: 2005, character_name: "Pilot5"}
      ]

      fleet_data = %{fleet_id: 789, total_pilots: 5}

      assert {:ok, analysis} =
               CompositionAnalyzer.analyze(789, %{
                 fleet_data: fleet_data,
                 participant_data: participant_data
               })

      role_dist = analysis.role_distribution

      # Should identify different roles based on ship attributes
      assert Map.has_key?(role_dist, "dps")
      assert Map.has_key?(role_dist, "logistics")
      assert Map.has_key?(role_dist, "ewar")
      assert Map.has_key?(role_dist, "support")

      # DPS ships should be counted correctly
      dps_info = role_dist["dps"]
      # 2 DPS ships
      assert dps_info.count == 2
      assert 2001 in dps_info.ship_types
      assert 2002 in dps_info.ship_types
    end

    test "tactical capabilities reflect real ship performance" do
      participant_data = [
        # High DPS
        %{ship_type_id: 2002, character_name: "Heavy DPS"},
        # Low DPS, high tank
        %{ship_type_id: 2003, character_name: "Logistics"},
        # Medium DPS, high tank
        %{ship_type_id: 2005, character_name: "Command"}
      ]

      fleet_data = %{fleet_id: 999, total_pilots: 3}

      assert {:ok, analysis} =
               CompositionAnalyzer.analyze(999, %{
                 fleet_data: fleet_data,
                 participant_data: participant_data
               })

      tactical = analysis.tactical_capabilities

      # Should calculate based on real ship performance
      # Total DPS: 480 + 60 + 350 = 890
      assert tactical.damage_projection >= 800 and tactical.damage_projection <= 1000

      # Should have logistics power from the logistics ship
      assert tactical.logistics_power > 0

      # Should reflect actual ship capabilities
      assert is_number(tactical.alpha_strike_capability)
      assert is_number(tactical.sustained_engagement_capability)
    end

    test "balance assessment uses real ship data for recommendations" do
      # Unbalanced fleet - all DPS, no support
      participant_data = [
        %{ship_type_id: 2001, character_name: "DPS1"},
        %{ship_type_id: 2002, character_name: "DPS2"},
        %{ship_type_id: 2001, character_name: "DPS3"}
      ]

      fleet_data = %{fleet_id: 111, total_pilots: 3}

      assert {:ok, analysis} =
               CompositionAnalyzer.analyze(111, %{
                 fleet_data: fleet_data,
                 participant_data: participant_data
               })

      balance = analysis.balance_assessment

      # Should identify lack of logistics/support based on real ship roles
      assert balance.lacks_logistics == true
      assert balance.lacks_ewar == true

      # Should have good DPS since all ships are DPS-focused
      assert balance.dps_rating >= 0.7
    end
  end

  describe "performance and edge cases" do
    test "handles large fleet efficiently" do
      # Create many ships of the same type
      {:ok, _} =
        ItemType.create(%{
          type_id: 3001,
          type_name: "Fleet Ship",
          group_name: "Frigate",
          is_ship: true,
          published: true
        })

      {:ok, _} =
        ShipAttributes.create(%{
          type_id: 3001,
          calculated_dps: 175.0,
          calculated_ehp: 1300.0,
          role_classification: "dps",
          size_class: "frigate"
        })

      # Create large participant list
      participant_data =
        for i <- 1..100 do
          %{ship_type_id: 3001, character_name: "Pilot#{i}"}
        end

      fleet_data = %{fleet_id: 777, total_pilots: 100}

      # Should handle efficiently without timeout
      start_time = System.monotonic_time(:millisecond)

      assert {:ok, analysis} =
               CompositionAnalyzer.analyze(777, %{
                 fleet_data: fleet_data,
                 participant_data: participant_data
               })

      duration = System.monotonic_time(:millisecond) - start_time

      # Should complete reasonably quickly (under 1 second)
      assert duration < 1000

      # Results should be correct for 100 ships
      # 100 * 175
      assert analysis.effectiveness_metrics.estimated_fleet_dps == 17_500
      # 100 * 1300
      assert analysis.effectiveness_metrics.estimated_effective_hp == 130_000
    end

    test "handles empty fleet gracefully" do
      fleet_data = %{fleet_id: 888, total_pilots: 0}
      participant_data = []

      assert {:ok, analysis} =
               CompositionAnalyzer.analyze(888, %{
                 fleet_data: fleet_data,
                 participant_data: participant_data
               })

      # Should handle empty fleet without errors
      assert analysis.effectiveness_metrics.estimated_fleet_dps == 0
      assert analysis.effectiveness_metrics.estimated_effective_hp == 0
      assert analysis.fleet_overview.total_ships == 0
    end
  end

  # Helper functions for test setup
  defp determine_role(group_name) do
    cond do
      group_name in ["Logistics Cruiser", "Logistics Frigate"] -> "logistics"
      group_name in ["Electronic Attack Frigate", "Combat Recon Ship"] -> "ewar"
      group_name in ["Command Ship"] -> "support"
      true -> "dps"
    end
  end

  defp determine_size(group_name) do
    cond do
      group_name in ["Frigate", "Assault Frigate", "Electronic Attack Frigate", "Interceptor"] ->
        "frigate"

      group_name in ["Cruiser", "Heavy Assault Cruiser", "Logistics Cruiser"] ->
        "cruiser"

      group_name in ["Battleship"] ->
        "battleship"

      group_name in ["Command Ship"] ->
        "battlecruiser"

      true ->
        "unknown"
    end
  end
end
