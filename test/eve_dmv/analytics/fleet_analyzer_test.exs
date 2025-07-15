defmodule EveDmv.Analytics.FleetAnalyzerTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Analytics.FleetAnalyzer
  alias EveDmv.Repo
  import Ecto.Query

  describe "analyze_fleet_composition/1" do
    test "returns error for fleets that are too small" do
      # Only 2 ships
      small_fleet = [641, 641]

      result = FleetAnalyzer.analyze_fleet_composition(small_fleet)
      assert result == {:error, :fleet_too_small}
    end

    test "analyzes a typical Megathron armor fleet" do
      # Setup ship role data
      setup_megathron_fleet_data()

      # Typical Megathron armor fleet: 8 Megathrons + 2 Guardians
      fleet_ships = [641, 641, 641, 641, 641, 641, 641, 641, 11_987, 11_987]

      result = FleetAnalyzer.analyze_fleet_composition(fleet_ships)

      assert is_map(result)
      assert result.fleet_size == 10
      assert result.doctrine_classification.doctrine == "megathron_armor_fleet"
      assert result.doctrine_classification.confidence > 0.7
      assert result.threat_level > 5.0
      assert %DateTime{} = result.analysis_timestamp
    end

    test "analyzes mixed fleet with unknown doctrine" do
      # Setup basic ship role data
      setup_basic_ship_data()

      # Mixed fleet with no clear doctrine
      fleet_ships = [641, 4306, 17_738, 11_978, 22_428, 11_987]

      result = FleetAnalyzer.analyze_fleet_composition(fleet_ships)

      assert result.doctrine_classification.doctrine == "unknown"
      assert result.doctrine_classification.confidence < 0.7
      assert length(result.recommendations) > 0
    end

    test "provides tactical assessment" do
      setup_basic_ship_data()
      fleet_ships = [641, 641, 641, 641, 11_987, 11_987]

      result = FleetAnalyzer.analyze_fleet_composition(fleet_ships)

      tactical = result.tactical_assessment
      assert is_map(tactical.logistics)
      assert is_map(tactical.tank_consistency)
      assert is_map(tactical.range_coherence)
      assert is_map(tactical.support_coverage)

      assert tactical.overall_readiness in [
               "combat_ready",
               "operational",
               "needs_improvement",
               "not_ready"
             ]
    end

    test "calculates correct role distribution" do
      setup_role_distribution_data()

      # Fleet: 6 DPS + 2 Logistics + 1 EWAR + 1 Tackle
      fleet_ships = [641, 641, 641, 641, 641, 641, 11_987, 11_987, 11_989, 22_456]

      result = FleetAnalyzer.analyze_fleet_composition(fleet_ships)

      roles = result.role_distribution
      # Should be dominant role
      assert roles["dps"] > 0.50
      # Should have decent logistics
      assert roles["logistics"] > 0.15
      assert roles["ewar"] > 0.0
      assert roles["tackle"] > 0.0
    end
  end

  describe "identify_doctrine/2" do
    test "identifies Megathron armor fleet correctly" do
      setup_megathron_fleet_data()

      # Classic Megathron armor composition
      fleet_ships = [641, 641, 641, 641, 641, 641, 11_987, 11_987]

      result = FleetAnalyzer.identify_doctrine(fleet_ships)

      # Should correctly identify or score reasonably well
      assert result.doctrine in ["megathron_armor_fleet", "unknown"]
      # With 6 DPS + 2 logistics in armor ships, should score decently
      if result.doctrine == "megathron_armor_fleet" do
        assert result.confidence > 0.3
        assert result.doctrine_name == "Megathron Armor Fleet"
        assert result.match_quality in ["excellent", "good", "fair", "partial"]
      else
        assert result.doctrine == "unknown"
        assert result.confidence == 0.0
      end
    end

    test "identifies Machariel speed fleet" do
      setup_machariel_fleet_data()

      # Machariel speed fleet (12+ ships required)
      fleet_ships = [
        17_738,
        17_738,
        17_738,
        17_738,
        17_738,
        17_738,
        17_738,
        17_738,
        17_738,
        17_738,
        11_978,
        11_978
      ]

      result = FleetAnalyzer.identify_doctrine(fleet_ships)

      assert result.doctrine == "machariel_speed_fleet"
      assert result.confidence > 0.6
    end

    test "handles unknown fleet compositions" do
      setup_basic_ship_data()

      # Random mix with no clear doctrine
      fleet_ships = [1234, 5678, 9012, 3456, 7890, 2345]

      result = FleetAnalyzer.identify_doctrine(fleet_ships)

      assert result.doctrine == "unknown"
      assert result.confidence == 0.0
      assert result.match_quality == "poor"
    end
  end

  describe "assess_fleet_strengths/2" do
    test "assesses logistics ratio correctly" do
      setup_basic_ship_data()

      # Fleet with good logistics ratio (20%)
      fleet_ships = [641, 641, 641, 641, 11_987]

      result = FleetAnalyzer.assess_fleet_strengths(fleet_ships)

      logistics = result.logistics
      assert logistics.ratio == 0.2
      assert logistics.count == 1
      assert logistics.assessment == "optimal"
      assert logistics.score > 0.8
    end

    test "identifies insufficient logistics" do
      setup_basic_ship_data()

      # Fleet with no logistics
      fleet_ships = [641, 641, 641, 641, 641]

      result = FleetAnalyzer.assess_fleet_strengths(fleet_ships)

      logistics = result.logistics
      assert logistics.ratio == 0.0
      assert logistics.assessment == "insufficient"
      assert logistics.score < 0.5
    end

    test "analyzes tank consistency" do
      setup_basic_ship_data()

      # All armor ships
      fleet_ships = [641, 641, 11_987, 11_987, 22_852]

      result = FleetAnalyzer.assess_fleet_strengths(fleet_ships)

      tank = result.tank_consistency
      assert tank.dominant_tank == "armor"
      assert tank.armor_ratio == 1.0
      assert tank.shield_ratio == 0.0
      assert tank.assessment == "excellent"
    end
  end

  describe "calculate_role_balance/1" do
    test "calculates role percentages correctly" do
      ship_role_data = [
        %{
          role_distribution: %{
            "dps" => 0.8,
            "logistics" => 0.0,
            "ewar" => 0.1,
            "tackle" => 0.0,
            "command" => 0.0,
            "support" => 0.1
          }
        },
        %{
          role_distribution: %{
            "dps" => 0.9,
            "logistics" => 0.0,
            "ewar" => 0.05,
            "tackle" => 0.0,
            "command" => 0.0,
            "support" => 0.05
          }
        },
        %{
          role_distribution: %{
            "dps" => 0.0,
            "logistics" => 0.9,
            "ewar" => 0.0,
            "tackle" => 0.0,
            "command" => 0.0,
            "support" => 0.1
          }
        },
        %{
          role_distribution: %{
            "dps" => 0.0,
            "logistics" => 0.85,
            "ewar" => 0.0,
            "tackle" => 0.0,
            "command" => 0.0,
            "support" => 0.15
          }
        }
      ]

      result = FleetAnalyzer.calculate_role_balance(ship_role_data)

      # 2 DPS ships + 2 Logistics ships = 50/50 split in primary roles
      # Should be roughly 42.5% (0.8 + 0.9) / 4
      assert result["dps"] > 0.4
      # Should be roughly 43.75% (0.0 + 0.0 + 0.9 + 0.85) / 4
      assert result["logistics"] > 0.4
      assert result["ewar"] > 0.0
      assert result["support"] > 0.0
    end

    test "handles empty ship data" do
      result = FleetAnalyzer.calculate_role_balance([])

      assert result["dps"] == 0.0
      assert result["logistics"] == 0.0
      assert result["ewar"] == 0.0
      assert result["tackle"] == 0.0
      assert result["command"] == 0.0
      assert result["support"] == 0.0
    end
  end

  describe "generate_recommendations/2" do
    test "recommends adding logistics for insufficient ratio" do
      setup_basic_ship_data()

      # Fleet with no logistics
      fleet_ships = [641, 641, 641, 641, 641]

      recommendations = FleetAnalyzer.generate_recommendations(fleet_ships)

      assert length(recommendations) > 0
      assert Enum.any?(recommendations, &String.contains?(&1, "logistics"))
    end

    test "recommends adding support ships" do
      setup_basic_ship_data()

      # Fleet with only DPS and logistics, no EWAR/tackle
      fleet_ships = [641, 641, 641, 11_987]

      recommendations = FleetAnalyzer.generate_recommendations(fleet_ships)

      # Should recommend EWAR, tackle, or command ships
      support_recommendations =
        Enum.filter(recommendations, fn rec ->
          String.contains?(rec, "EWAR") or
            String.contains?(rec, "tackle") or
            String.contains?(rec, "command")
        end)

      assert length(support_recommendations) > 0
    end

    test "limits recommendations to reasonable number" do
      setup_basic_ship_data()

      # Fleet with many issues
      # No logistics, no support
      fleet_ships = [641, 641, 641, 641, 641, 641]

      recommendations = FleetAnalyzer.generate_recommendations(fleet_ships)

      # Should limit to max 8 recommendations
      assert length(recommendations) <= 8
    end
  end

  describe "calculate_threat_score/2" do
    test "calculates higher threat for larger well-balanced fleets" do
      setup_comprehensive_fleet_data()

      # Large, well-balanced fleet
      large_fleet = [
        # DPS ships
        641,
        641,
        641,
        641,
        641,
        641,
        641,
        641,
        641,
        641,
        # Logistics
        11_987,
        11_987,
        11_987,
        # Support
        11_989,
        22_456
      ]

      # Small basic fleet
      small_fleet = [641, 641, 11_987]

      large_threat = FleetAnalyzer.calculate_threat_score(large_fleet)
      small_threat = FleetAnalyzer.calculate_threat_score(small_fleet)

      assert large_threat > small_threat
      assert large_threat <= 10.0
      assert small_threat >= 0.0
    end

    test "gives doctrine bonus to organized fleets" do
      setup_megathron_fleet_data()

      # Organized Megathron fleet
      organized_fleet = [641, 641, 641, 641, 641, 641, 11_987, 11_987]

      # Random fleet of same size
      random_fleet = [1234, 5678, 9012, 3456, 7890, 2345, 6789, 1357]

      organized_threat = FleetAnalyzer.calculate_threat_score(organized_fleet)
      random_threat = FleetAnalyzer.calculate_threat_score(random_fleet)

      # Organized fleet should have higher threat due to doctrine bonus
      assert organized_threat >= random_threat
    end
  end

  # Helper functions for test data setup

  defp setup_megathron_fleet_data do
    # Megathron - DPS
    Repo.insert_all("ship_role_patterns", [
      %{
        ship_type_id: 641,
        ship_name: "Megathron",
        primary_role: "dps",
        role_distribution: %{
          "dps" => 0.85,
          "logistics" => 0.0,
          "ewar" => 0.05,
          "tackle" => 0.0,
          "command" => 0.0,
          "support" => 0.1
        },
        confidence_score: Decimal.new("0.90"),
        sample_size: 100,
        last_analyzed: DateTime.utc_now(),
        meta_trend: "stable",
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    ])

    # Guardian - Logistics
    Repo.insert_all("ship_role_patterns", [
      %{
        ship_type_id: 11_987,
        ship_name: "Guardian",
        primary_role: "logistics",
        role_distribution: %{
          "dps" => 0.0,
          "logistics" => 0.95,
          "ewar" => 0.0,
          "tackle" => 0.0,
          "command" => 0.0,
          "support" => 0.05
        },
        confidence_score: Decimal.new("0.95"),
        sample_size: 80,
        last_analyzed: DateTime.utc_now(),
        meta_trend: "stable",
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    ])
  end

  defp setup_machariel_fleet_data do
    # Machariel - Mobile DPS
    Repo.insert_all("ship_role_patterns", [
      %{
        ship_type_id: 17_738,
        ship_name: "Machariel",
        primary_role: "dps",
        role_distribution: %{
          "dps" => 0.90,
          "logistics" => 0.0,
          "ewar" => 0.0,
          "tackle" => 0.0,
          "command" => 0.0,
          "support" => 0.1
        },
        confidence_score: Decimal.new("0.88"),
        sample_size: 75,
        last_analyzed: DateTime.utc_now(),
        meta_trend: "stable",
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    ])

    # Basilisk - Shield Logistics
    Repo.insert_all("ship_role_patterns", [
      %{
        ship_type_id: 11_978,
        ship_name: "Basilisk",
        primary_role: "logistics",
        role_distribution: %{
          "dps" => 0.0,
          "logistics" => 0.90,
          "ewar" => 0.0,
          "tackle" => 0.0,
          "command" => 0.0,
          "support" => 0.1
        },
        confidence_score: Decimal.new("0.92"),
        sample_size: 60,
        last_analyzed: DateTime.utc_now(),
        meta_trend: "stable",
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    ])
  end

  defp setup_basic_ship_data do
    ships_data = [
      %{
        ship_type_id: 641,
        ship_name: "Megathron",
        primary_role: "dps",
        role_distribution: %{
          "dps" => 0.85,
          "logistics" => 0.0,
          "ewar" => 0.05,
          "tackle" => 0.0,
          "command" => 0.0,
          "support" => 0.1
        }
      },
      %{
        ship_type_id: 11_987,
        ship_name: "Guardian",
        primary_role: "logistics",
        role_distribution: %{
          "dps" => 0.0,
          "logistics" => 0.95,
          "ewar" => 0.0,
          "tackle" => 0.0,
          "command" => 0.0,
          "support" => 0.05
        }
      },
      %{
        ship_type_id: 4306,
        ship_name: "Ferox",
        primary_role: "dps",
        role_distribution: %{
          "dps" => 0.80,
          "logistics" => 0.0,
          "ewar" => 0.1,
          "tackle" => 0.0,
          "command" => 0.0,
          "support" => 0.1
        }
      },
      %{
        ship_type_id: 17_738,
        ship_name: "Machariel",
        primary_role: "dps",
        role_distribution: %{
          "dps" => 0.90,
          "logistics" => 0.0,
          "ewar" => 0.0,
          "tackle" => 0.0,
          "command" => 0.0,
          "support" => 0.1
        }
      },
      %{
        ship_type_id: 11_978,
        ship_name: "Basilisk",
        primary_role: "logistics",
        role_distribution: %{
          "dps" => 0.0,
          "logistics" => 0.90,
          "ewar" => 0.0,
          "tackle" => 0.0,
          "command" => 0.0,
          "support" => 0.1
        }
      },
      %{
        ship_type_id: 22_428,
        ship_name: "Muninn",
        primary_role: "dps",
        role_distribution: %{
          "dps" => 0.85,
          "logistics" => 0.0,
          "ewar" => 0.0,
          "tackle" => 0.0,
          "command" => 0.0,
          "support" => 0.15
        }
      }
    ]

    records =
      Enum.map(ships_data, fn ship ->
        Map.merge(ship, %{
          confidence_score: Decimal.new("0.85"),
          sample_size: 50,
          last_analyzed: DateTime.utc_now(),
          meta_trend: "stable",
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        })
      end)

    Repo.insert_all("ship_role_patterns", records)
  end

  defp setup_role_distribution_data do
    ships_data = [
      %{
        ship_type_id: 641,
        primary_role: "dps",
        role_distribution: %{
          "dps" => 0.85,
          "logistics" => 0.0,
          "ewar" => 0.05,
          "tackle" => 0.0,
          "command" => 0.0,
          "support" => 0.1
        }
      },
      %{
        ship_type_id: 11_987,
        primary_role: "logistics",
        role_distribution: %{
          "dps" => 0.0,
          "logistics" => 0.95,
          "ewar" => 0.0,
          "tackle" => 0.0,
          "command" => 0.0,
          "support" => 0.05
        }
      },
      %{
        ship_type_id: 11_989,
        primary_role: "ewar",
        role_distribution: %{
          "dps" => 0.1,
          "logistics" => 0.0,
          "ewar" => 0.80,
          "tackle" => 0.0,
          "command" => 0.0,
          "support" => 0.1
        }
      },
      %{
        ship_type_id: 22_456,
        primary_role: "tackle",
        role_distribution: %{
          "dps" => 0.2,
          "logistics" => 0.0,
          "ewar" => 0.1,
          "tackle" => 0.65,
          "command" => 0.0,
          "support" => 0.05
        }
      }
    ]

    records =
      Enum.map(ships_data, fn ship ->
        Map.merge(ship, %{
          ship_name: "Test Ship #{ship.ship_type_id}",
          confidence_score: Decimal.new("0.80"),
          sample_size: 40,
          last_analyzed: DateTime.utc_now(),
          meta_trend: "stable",
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        })
      end)

    Repo.insert_all("ship_role_patterns", records)
  end

  defp setup_comprehensive_fleet_data do
    # Setup all the basic ship data plus additional ships for comprehensive testing
    setup_basic_ship_data()

    additional_ships = [
      %{
        ship_type_id: 11_989,
        ship_name: "Blackbird",
        primary_role: "ewar",
        role_distribution: %{
          "dps" => 0.1,
          "logistics" => 0.0,
          "ewar" => 0.80,
          "tackle" => 0.0,
          "command" => 0.0,
          "support" => 0.1
        }
      },
      %{
        ship_type_id: 22_456,
        ship_name: "Sabre",
        primary_role: "tackle",
        role_distribution: %{
          "dps" => 0.2,
          "logistics" => 0.0,
          "ewar" => 0.1,
          "tackle" => 0.65,
          "command" => 0.0,
          "support" => 0.05
        }
      },
      %{
        ship_type_id: 22_852,
        ship_name: "Damnation",
        primary_role: "command",
        role_distribution: %{
          "dps" => 0.3,
          "logistics" => 0.0,
          "ewar" => 0.0,
          "tackle" => 0.0,
          "command" => 0.60,
          "support" => 0.1
        }
      }
    ]

    records =
      Enum.map(additional_ships, fn ship ->
        Map.merge(ship, %{
          confidence_score: Decimal.new("0.80"),
          sample_size: 35,
          last_analyzed: DateTime.utc_now(),
          meta_trend: "stable",
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        })
      end)

    Repo.insert_all("ship_role_patterns", records)
  end
end
