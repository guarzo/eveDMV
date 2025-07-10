defmodule EveDmv.Intelligence.WHFleetAnalyzerTest do
  @moduledoc """
  Comprehensive tests for WHFleetAnalyzer module.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Intelligence.Analyzers.WhFleetAnalyzer
  alias EveDmv.TestMocks

  # Wormhole type constants for testing
  @c3_static "O477"

  describe "analyze_fleet_composition/1" do
    test "analyzes fleet composition with member data" do
      members = [
        %{
          character_id: 123,
          character_name: "FC Pilot",
          # Damnation
          ship_type_id: 12_013,
          ship_name: "Damnation",
          ship_category: "command_ship",
          mass: 13_500_000,
          role: "fc"
        },
        %{
          character_id: 456,
          character_name: "DPS Pilot",
          # Legion
          ship_type_id: 12_011,
          ship_name: "Legion",
          ship_category: "strategic_cruiser",
          mass: 13_000_000,
          role: "dps"
        },
        %{
          character_id: 789,
          character_name: "Logi Pilot",
          # Guardian
          ship_type_id: 11_987,
          ship_name: "Guardian",
          ship_category: "logistics",
          mass: 11_800_000,
          role: "logistics"
        }
      ]

      result = WhFleetAnalyzer.analyze_fleet_composition_from_members(members)

      assert %{
               total_members: 3,
               ship_categories: categories,
               total_mass: total_mass,
               doctrine_compliance: compliance,
               role_distribution: roles
             } = result

      assert is_map(categories)
      assert is_number(total_mass)
      # Sum of ship masses
      assert total_mass > 30_000_000
      assert is_number(compliance)
      assert compliance >= 0 and compliance <= 100
      assert is_map(roles)
    end

    test "handles empty fleet" do
      result = WhFleetAnalyzer.analyze_fleet_composition_from_members([])

      assert %{
               total_members: 0,
               ship_categories: %{},
               total_mass: 0,
               doctrine_compliance: 0,
               role_distribution: %{}
             } = result
    end
  end

  describe "calculate_wormhole_viability/2" do
    test "calculates viability for different wormhole types" do
      fleet_data = %{
        # 50M kg
        total_mass: 50_000_000,
        ship_count: 4,
        average_ship_mass: 12_500_000
      }

      # Test with C3 static (medium mass limit)
      wormhole = %{
        # C3 static
        type: @c3_static,
        # 300M kg
        max_mass: 300_000_000,
        # 20M kg
        max_ship_mass: 20_000_000,
        stability: "stable"
      }

      result = WhFleetAnalyzer.calculate_wormhole_viability(fleet_data, wormhole)

      assert %{
               can_jump: can_jump,
               mass_efficiency: efficiency,
               ships_that_can_jump: ships_count,
               recommended_jump_order: jump_order
             } = result

      assert is_boolean(can_jump)
      assert is_number(efficiency)
      assert efficiency >= 0 and efficiency <= 100
      assert is_integer(ships_count)
      assert is_list(jump_order)
    end

    test "handles oversized ships" do
      fleet_data = %{
        total_mass: 100_000_000,
        ship_count: 2,
        # Very heavy ships
        average_ship_mass: 50_000_000
      }

      wormhole = %{
        # Small WH
        type: "D382",
        max_mass: 100_000_000,
        # Ships are too heavy
        max_ship_mass: 20_000_000,
        stability: "stable"
      }

      result = WhFleetAnalyzer.calculate_wormhole_viability(fleet_data, wormhole)

      # Should indicate ships can't jump
      assert result.ships_that_can_jump == 0
      assert result.can_jump == false
    end
  end

  describe "analyze_doctrine_compliance/1" do
    test "analyzes compliance with standard doctrines" do
      fleet_members = [
        %{ship_name: "Damnation", ship_category: "command_ship"},
        %{ship_name: "Legion", ship_category: "strategic_cruiser"},
        %{ship_name: "Legion", ship_category: "strategic_cruiser"},
        %{ship_name: "Guardian", ship_category: "logistics"},
        %{ship_name: "Guardian", ship_category: "logistics"},
        # Off-doctrine
        %{ship_name: "Rifter", ship_category: "frigate"}
      ]

      result = WhFleetAnalyzer.analyze_doctrine_compliance(fleet_members)

      assert %{
               compliance_score: score,
               doctrine_ships: doctrine_count,
               off_doctrine_ships: off_doctrine,
               identified_doctrine: doctrine_name
             } = result

      assert is_number(score)
      assert score >= 0 and score <= 100
      assert is_integer(doctrine_count)
      assert is_integer(off_doctrine)
      assert doctrine_count + off_doctrine == length(fleet_members)
      assert is_binary(doctrine_name) or is_nil(doctrine_name)
    end

    test "handles unknown doctrine" do
      mixed_fleet = [
        %{ship_name: "Rifter", ship_category: "frigate"},
        %{ship_name: "Punisher", ship_category: "frigate"},
        %{ship_name: "Bantam", ship_category: "frigate"}
      ]

      result = WhFleetAnalyzer.analyze_doctrine_compliance(mixed_fleet)

      # Should be low for unknown doctrine
      assert result.compliance_score < 50
      assert result.identified_doctrine == "unknown" or is_nil(result.identified_doctrine)
    end
  end

  describe "calculate_fleet_effectiveness/1" do
    test "calculates effectiveness metrics" do
      fleet_analysis = %{
        total_members: 10,
        ship_categories: %{
          "command_ship" => 1,
          "strategic_cruiser" => 4,
          "logistics" => 2,
          "interceptor" => 2,
          "electronic_warfare" => 1
        },
        doctrine_compliance: 85,
        role_distribution: %{
          "fc" => 1,
          "dps" => 6,
          "logistics" => 2,
          "tackle" => 1
        }
      }

      result = WhFleetAnalyzer.calculate_fleet_effectiveness(fleet_analysis)

      assert %{
               overall_effectiveness: overall,
               dps_rating: dps,
               survivability_rating: survivability,
               flexibility_rating: flexibility,
               fc_capability: fc_capable
             } = result

      assert is_number(overall)
      assert overall >= 0 and overall <= 100
      assert is_number(dps)
      assert is_number(survivability)
      assert is_number(flexibility)
      assert is_boolean(fc_capable)
    end

    test "penalizes unbalanced fleets" do
      # All DPS, no logistics
      unbalanced_fleet = %{
        total_members: 5,
        ship_categories: %{"strategic_cruiser" => 5},
        doctrine_compliance: 100,
        role_distribution: %{"dps" => 5}
      }

      result = WhFleetAnalyzer.calculate_fleet_effectiveness(unbalanced_fleet)

      # Should have lower survivability due to no logistics
      assert result.survivability_rating < 50
    end
  end

  describe "recommend_fleet_improvements/1" do
    test "recommends improvements for fleet composition" do
      fleet_data = %{
        total_members: 6,
        ship_categories: %{
          "strategic_cruiser" => 4,
          "interceptor" => 2
        },
        role_distribution: %{
          "dps" => 4,
          "tackle" => 2
        },
        doctrine_compliance: 60,
        effectiveness_metrics: %{
          overall_effectiveness: 65,
          # Low - no logistics
          survivability_rating: 30,
          dps_rating: 80,
          flexibility_rating: 70
        }
      }

      result = WhFleetAnalyzer.recommend_fleet_improvements(fleet_data)

      assert %{
               priority_improvements: priority,
               suggested_additions: additions,
               role_recommendations: roles,
               doctrine_suggestions: doctrine
             } = result

      assert is_list(priority)
      assert is_list(additions)
      assert is_map(roles)
      assert is_list(doctrine)

      # Should recommend logistics for low survivability
      all_recommendations = priority ++ additions ++ doctrine

      assert Enum.any?(all_recommendations, fn rec ->
               String.contains?(String.downcase(rec), "logistics") or
                 String.contains?(String.downcase(rec), "guardian") or
                 String.contains?(String.downcase(rec), "logi")
             end)
    end
  end

  describe "calculate_jump_mass_sequence/2" do
    test "calculates optimal jump sequence" do
      ships = [
        %{character_name: "Heavy", ship_mass: 15_000_000, ship_name: "Damnation"},
        %{character_name: "Medium", ship_mass: 12_000_000, ship_name: "Legion"},
        %{character_name: "Light", ship_mass: 8_000_000, ship_name: "Interceptor"}
      ]

      wormhole = %{
        max_mass: 100_000_000,
        max_ship_mass: 20_000_000,
        current_mass: 0
      }

      result = WhFleetAnalyzer.calculate_jump_mass_sequence(ships, wormhole)

      assert %{
               jump_order: order,
               mass_utilization: utilization,
               remaining_capacity: capacity
             } = result

      assert is_list(order)
      assert length(order) == length(ships)
      assert is_number(utilization)
      assert utilization >= 0 and utilization <= 100
      assert is_number(capacity)
      assert capacity >= 0
    end

    test "handles mass-limited scenarios" do
      heavy_ships = [
        %{character_name: "Ship1", ship_mass: 60_000_000, ship_name: "Capital"},
        %{character_name: "Ship2", ship_mass: 60_000_000, ship_name: "Capital"}
      ]

      small_wh = %{
        max_mass: 100_000_000,
        # Ships too heavy
        max_ship_mass: 50_000_000,
        current_mass: 0
      }

      result = WhFleetAnalyzer.calculate_jump_mass_sequence(heavy_ships, small_wh)

      # Should show no ships can jump
      assert Enum.empty?(result.jump_order)
      assert result.mass_utilization == 0
    end
  end

  describe "analyze_fleet_roles/1" do
    test "analyzes and categorizes fleet roles" do
      fleet_members = [
        %{character_name: "FC", ship_name: "Damnation", ship_category: "command_ship"},
        %{character_name: "DPS1", ship_name: "Legion", ship_category: "strategic_cruiser"},
        %{character_name: "DPS2", ship_name: "Legion", ship_category: "strategic_cruiser"},
        %{character_name: "Logi1", ship_name: "Guardian", ship_category: "logistics"},
        %{character_name: "Tackle", ship_name: "Ares", ship_category: "interceptor"},
        %{character_name: "EWAR", ship_name: "Crucifier", ship_category: "frigate"}
      ]

      result = WhFleetAnalyzer.analyze_fleet_roles(fleet_members)

      assert %{
               role_balance: balance,
               missing_roles: missing,
               role_coverage: coverage,
               recommended_ratio: ratio
             } = result

      assert is_map(balance)
      assert is_list(missing)
      assert is_map(coverage)
      assert is_map(ratio)

      # Should identify key roles
      assert Map.has_key?(balance, "dps")
      assert Map.has_key?(balance, "logistics")
      assert Map.has_key?(balance, "tackle")
    end
  end

  describe "helper functions" do
    test "categorize_ship_role/1 correctly identifies ship roles" do
      assert WhFleetAnalyzer.categorize_ship_role("Damnation") == "fc"
      assert WhFleetAnalyzer.categorize_ship_role("Legion") == "dps"
      assert WhFleetAnalyzer.categorize_ship_role("Guardian") == "logistics"
      assert WhFleetAnalyzer.categorize_ship_role("Ares") == "tackle"
      assert WhFleetAnalyzer.categorize_ship_role("Crucifier") == "ewar"
      assert WhFleetAnalyzer.categorize_ship_role("Unknown Ship") == "unknown"
    end

    test "calculate_ship_mass/1 returns realistic masses" do
      # Test with known ship types
      damnation_mass = WhFleetAnalyzer.calculate_ship_mass("Damnation")
      assert is_number(damnation_mass)
      # Should be heavy
      assert damnation_mass > 10_000_000

      rifter_mass = WhFleetAnalyzer.calculate_ship_mass("Rifter")
      assert is_number(rifter_mass)
      # Should be light
      assert rifter_mass < 5_000_000
    end

    test "doctrine_ship?/2 identifies doctrine compliance" do
      assert WhFleetAnalyzer.doctrine_ship?("Legion", "armor_cruiser") == true
      assert WhFleetAnalyzer.doctrine_ship?("Guardian", "armor_cruiser") == true
      assert WhFleetAnalyzer.doctrine_ship?("Rifter", "armor_cruiser") == false
      assert WhFleetAnalyzer.doctrine_ship?("Unknown", "any_doctrine") == false
    end

    test "calculate_logistics_ratio/1 computes correct ratios" do
      fleet_data = %{
        total_members: 10,
        ship_categories: %{
          "logistics" => 2,
          "strategic_cruiser" => 6,
          "command_ship" => 1,
          "interceptor" => 1
        }
      }

      ratio = WhFleetAnalyzer.calculate_logistics_ratio(fleet_data)
      # 2/10 = 20%
      assert ratio == 0.2
    end

    test "wormhole_mass_limit/1 returns correct limits" do
      # C3 static
      c3_limit = WhFleetAnalyzer.wormhole_mass_limit(@c3_static)
      assert is_number(c3_limit)
      # Should be substantial
      assert c3_limit > 100_000_000

      # Frigate hole
      frigate_limit = WhFleetAnalyzer.wormhole_mass_limit("D382")
      assert is_number(frigate_limit)
      # Should be smaller
      assert frigate_limit < c3_limit
    end
  end

  describe "doctrine identification" do
    test "identifies armor cruiser doctrine" do
      armor_fleet = [
        %{ship_name: "Legion", ship_category: "strategic_cruiser"},
        %{ship_name: "Legion", ship_category: "strategic_cruiser"},
        %{ship_name: "Damnation", ship_category: "command_ship"},
        %{ship_name: "Guardian", ship_category: "logistics"}
      ]

      doctrine = WhFleetAnalyzer.identify_fleet_doctrine(armor_fleet)
      assert doctrine == "armor_cruiser" or doctrine == "armor"
    end

    test "identifies shield doctrine" do
      shield_fleet = [
        %{ship_name: "Tengu", ship_category: "strategic_cruiser"},
        %{ship_name: "Nighthawk", ship_category: "command_ship"},
        %{ship_name: "Scimitar", ship_category: "logistics"}
      ]

      doctrine = WhFleetAnalyzer.identify_fleet_doctrine(shield_fleet)
      assert doctrine == "shield_cruiser" or doctrine == "shield"
    end

    test "handles mixed or unknown doctrines" do
      mixed_fleet = [
        %{ship_name: "Rifter", ship_category: "frigate"},
        %{ship_name: "Maller", ship_category: "cruiser"},
        %{ship_name: "Drake", ship_category: "battlecruiser"}
      ]

      doctrine = WhFleetAnalyzer.identify_fleet_doctrine(mixed_fleet)
      assert doctrine == "unknown" or doctrine == "mixed"
    end
  end

  describe "mass calculations" do
    test "calculates total fleet mass accurately" do
      fleet = [
        %{ship_mass: 10_000_000},
        %{ship_mass: 15_000_000},
        %{ship_mass: 8_000_000}
      ]

      total_mass = WhFleetAnalyzer.calculate_total_fleet_mass(fleet)
      assert total_mass == 33_000_000
    end

    test "handles empty fleet mass calculation" do
      total_mass = WhFleetAnalyzer.calculate_total_fleet_mass([])
      assert total_mass == 0
    end

    test "calculates average ship mass" do
      fleet = [
        %{ship_mass: 10_000_000},
        %{ship_mass: 20_000_000}
      ]

      avg_mass = WhFleetAnalyzer.calculate_average_ship_mass(fleet)
      assert avg_mass == 15_000_000
    end
  end

  describe "wormhole compatibility" do
    test "determines wormhole compatibility correctly" do
      light_fleet = %{total_mass: 50_000_000, max_ship_mass: 10_000_000}
      heavy_fleet = %{total_mass: 200_000_000, max_ship_mass: 30_000_000}

      # Frigate wormhole
      frigate_wh = %{max_mass: 100_000_000, max_ship_mass: 15_000_000}

      assert WhFleetAnalyzer.fleet_wormhole_compatible?(light_fleet, frigate_wh) == true
      assert WhFleetAnalyzer.fleet_wormhole_compatible?(heavy_fleet, frigate_wh) == false

      # Large wormhole
      large_wh = %{max_mass: 500_000_000, max_ship_mass: 50_000_000}

      assert WhFleetAnalyzer.fleet_wormhole_compatible?(light_fleet, large_wh) == true
      assert WhFleetAnalyzer.fleet_wormhole_compatible?(heavy_fleet, large_wh) == true
    end
  end

  describe "integration with mock data" do
    test "processes fleet composition with realistic data" do
      # Use mock data to test with realistic fleet composition
      fleet_members = [
        Map.merge(TestMocks.mock_member_activity(123), %{
          ship_name: "Damnation",
          ship_category: "command_ship",
          ship_mass: 13_500_000
        }),
        Map.merge(TestMocks.mock_member_activity(456), %{
          ship_name: "Legion",
          ship_category: "strategic_cruiser",
          ship_mass: 13_000_000
        }),
        Map.merge(TestMocks.mock_member_activity(789), %{
          ship_name: "Guardian",
          ship_category: "logistics",
          ship_mass: 11_800_000
        })
      ]

      result = WhFleetAnalyzer.analyze_fleet_composition_from_members(fleet_members)

      assert result.total_members == 3
      assert result.total_mass > 35_000_000
      assert Map.has_key?(result.ship_categories, "command_ship")
      assert Map.has_key?(result.ship_categories, "strategic_cruiser")
      assert Map.has_key?(result.ship_categories, "logistics")
    end
  end
end
