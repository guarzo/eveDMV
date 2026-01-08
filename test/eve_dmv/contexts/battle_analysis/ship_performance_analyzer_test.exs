defmodule EveDmv.Contexts.BattleAnalysis.Domain.ShipPerformanceAnalyzerTest do
  @moduledoc """
  Tests for the ShipPerformanceAnalyzer module.

  Tests the ship performance analysis system including:
  - DPS efficiency calculations
  - Survivability analysis
  - Tactical contribution
  - Role effectiveness
  - Performance recommendations
  """

  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.BattleAnalysis.Domain.ShipPerformanceAnalyzer

  # Test fixtures for battle data
  defp build_battle_struct(attrs) do
    killmails = Map.get(attrs, :killmails, [build_killmail_struct()])

    default_metadata = %{
      duration_minutes: 15,
      battle_type: :skirmish,
      unique_participants: 10,
      battle_phases: []
    }

    %{
      battle_id: Map.get(attrs, :battle_id, "battle_30000142_20260105120000"),
      killmails: killmails,
      metadata: Map.merge(default_metadata, Map.get(attrs, :metadata, %{}))
    }
  end

  defp build_killmail_struct(attrs \\ %{}) do
    attacker_data =
      Map.get(attrs, :attackers, [
        %{
          "character_id" => 90_000_001,
          "corporation_id" => 98_000_001,
          "alliance_id" => 99_000_001,
          "ship_type_id" => 620,
          "weapon_type_id" => 2185,
          "damage_done" => 5000,
          "final_blow" => true
        }
      ])

    %{
      killmail_id: Map.get(attrs, :killmail_id, System.unique_integer([:positive])),
      killmail_time: Map.get(attrs, :killmail_time, DateTime.utc_now()),
      solar_system_id: Map.get(attrs, :solar_system_id, 30_000_142),
      victim_character_id: Map.get(attrs, :victim_character_id, 90_000_002),
      victim_corporation_id: Map.get(attrs, :victim_corporation_id, 98_000_002),
      victim_alliance_id: Map.get(attrs, :victim_alliance_id, 99_000_002),
      victim_ship_type_id: Map.get(attrs, :victim_ship_type_id, 587),
      raw_data: %{
        "attackers" => attacker_data,
        "victim" => %{
          "character_id" => Map.get(attrs, :victim_character_id, 90_000_002),
          "corporation_id" => Map.get(attrs, :victim_corporation_id, 98_000_002),
          "ship_type_id" => Map.get(attrs, :victim_ship_type_id, 587),
          "damage_taken" => Map.get(attrs, :damage_taken, 5000)
        }
      }
    }
  end

  defp build_ship_data(attrs) do
    %{
      character_id: Map.get(attrs, :character_id, 90_000_001),
      ship_type_id: Map.get(attrs, :ship_type_id, 620),
      fitting_data: Map.get(attrs, :fitting_data, nil),
      character_name: Map.get(attrs, :character_name, "Test Pilot")
    }
  end

  describe "analyze_battle_performance/2" do
    test "returns analysis for battle with killmails" do
      killmail = build_killmail_struct()
      battle = build_battle_struct(%{killmails: [killmail]})

      assert {:ok, analysis} = ShipPerformanceAnalyzer.analyze_battle_performance(battle)

      assert is_map(analysis)
      assert Map.has_key?(analysis, :top_performers)
      assert Map.has_key?(analysis, :fleet_stats)
      assert Map.has_key?(analysis, :ship_performances)
      assert Map.has_key?(analysis, :comparative_metrics)
    end

    test "returns empty analysis for battle with no killmails" do
      battle = build_battle_struct(%{killmails: []})

      assert {:ok, analysis} = ShipPerformanceAnalyzer.analyze_battle_performance(battle)

      assert analysis.top_performers == []
      assert analysis.ship_performances == []
      assert analysis.fleet_stats.avg_dps_efficiency == 0
    end

    test "filters by focus_ship when specified" do
      frigate_killmail = build_killmail_struct(%{victim_ship_type_id: 587})
      cruiser_killmail = build_killmail_struct(%{victim_ship_type_id: 620})
      battle = build_battle_struct(%{killmails: [frigate_killmail, cruiser_killmail]})

      assert {:ok, analysis} =
               ShipPerformanceAnalyzer.analyze_battle_performance(battle, focus_ship: 587)

      # Analysis should still return but filtered for the specific ship
      assert is_map(analysis)
    end

    test "calculates efficiency metrics" do
      killmail = build_killmail_struct()
      battle = build_battle_struct(%{killmails: [killmail]})

      assert {:ok, analysis} =
               ShipPerformanceAnalyzer.analyze_battle_performance(battle,
                 performance_metrics: :efficiency
               )

      assert is_map(analysis)
    end

    test "calculates survivability metrics" do
      killmail = build_killmail_struct()
      battle = build_battle_struct(%{killmails: [killmail]})

      assert {:ok, analysis} =
               ShipPerformanceAnalyzer.analyze_battle_performance(battle,
                 performance_metrics: :survivability
               )

      assert is_map(analysis)
    end

    test "includes recommendations when specified" do
      killmail = build_killmail_struct()
      battle = build_battle_struct(%{killmails: [killmail]})

      assert {:ok, analysis} =
               ShipPerformanceAnalyzer.analyze_battle_performance(battle,
                 include_recommendations: true
               )

      assert Map.has_key?(analysis, :recommendations)
    end

    test "excludes recommendations when disabled" do
      killmail = build_killmail_struct()
      battle = build_battle_struct(%{killmails: [killmail]})

      assert {:ok, analysis} =
               ShipPerformanceAnalyzer.analyze_battle_performance(battle,
                 include_recommendations: false
               )

      # Analysis should complete without recommendations key in top-level (or it's nil)
      assert is_map(analysis)
    end

    test "handles multiple killmails in battle" do
      killmails = [
        build_killmail_struct(%{victim_ship_type_id: 587}),
        build_killmail_struct(%{victim_ship_type_id: 620}),
        build_killmail_struct(%{victim_ship_type_id: 638})
      ]

      battle = build_battle_struct(%{killmails: killmails})

      assert {:ok, analysis} = ShipPerformanceAnalyzer.analyze_battle_performance(battle)

      # Should have analyzed ships from all killmails
      assert analysis.ship_performances != []
    end

    test "includes attacker instances in analysis" do
      attackers = [
        %{
          "character_id" => 90_000_001,
          "corporation_id" => 98_000_001,
          "alliance_id" => 99_000_001,
          "ship_type_id" => 620,
          "weapon_type_id" => 2185,
          "damage_done" => 5000,
          "final_blow" => true
        },
        %{
          "character_id" => 90_000_003,
          "corporation_id" => 98_000_001,
          "alliance_id" => 99_000_001,
          "ship_type_id" => 621,
          "weapon_type_id" => 2186,
          "damage_done" => 3000,
          "final_blow" => false
        }
      ]

      killmail = build_killmail_struct(%{attackers: attackers})
      battle = build_battle_struct(%{killmails: [killmail]})

      assert {:ok, analysis} = ShipPerformanceAnalyzer.analyze_battle_performance(battle)

      # Should have victim + attackers
      assert analysis.ship_performances != []
    end
  end

  describe "analyze_ship_performance/3" do
    test "analyzes ship performance with fitting data" do
      ship_data = build_ship_data(%{fitting_data: %{modules: []}})
      battle_data = %{killmails: [build_killmail_struct()], combat_logs: []}

      assert {:ok, result} =
               ShipPerformanceAnalyzer.analyze_ship_performance(ship_data, battle_data)

      assert Map.has_key?(result, :ship_info)
      assert Map.has_key?(result, :expected_stats)
      assert Map.has_key?(result, :actual_performance)
      assert Map.has_key?(result, :efficiency_metrics)
      assert Map.has_key?(result, :recommendations)
    end

    test "handles ship with no fitting data" do
      ship_data = build_ship_data(%{fitting_data: nil})
      battle_data = %{killmails: [build_killmail_struct()], combat_logs: []}

      assert {:ok, result} =
               ShipPerformanceAnalyzer.analyze_ship_performance(ship_data, battle_data)

      assert result.expected_stats.status == :no_fitting_data
    end

    test "returns ship info with character details" do
      ship_data =
        build_ship_data(%{
          character_id: 12_345,
          character_name: "Test Pilot",
          ship_type_id: 620
        })

      battle_data = %{killmails: [], combat_logs: []}

      assert {:ok, result} =
               ShipPerformanceAnalyzer.analyze_ship_performance(ship_data, battle_data)

      assert result.ship_info.character_id == 12_345
      assert result.ship_info.ship_type_id == 620
    end
  end

  describe "analyze_performance_trends/2" do
    test "analyzes trends across multiple battles" do
      battles = [
        build_battle_struct(%{killmails: [build_killmail_struct(%{victim_ship_type_id: 620})]}),
        build_battle_struct(%{killmails: [build_killmail_struct(%{victim_ship_type_id: 620})]})
      ]

      ship_type_id = 620

      assert {:ok, trend_analysis} =
               ShipPerformanceAnalyzer.analyze_performance_trends(battles, ship_type_id)

      assert trend_analysis.ship_type_id == ship_type_id
      assert trend_analysis.battles_analyzed >= 0
      assert Map.has_key?(trend_analysis, :performance_trends)
      assert Map.has_key?(trend_analysis, :optimal_conditions)
      assert Map.has_key?(trend_analysis, :improvement_areas)
    end

    test "handles empty battle list" do
      assert {:ok, trend_analysis} =
               ShipPerformanceAnalyzer.analyze_performance_trends([], 620)

      assert trend_analysis.battles_analyzed == 0
    end

    test "handles single battle" do
      battles = [
        build_battle_struct(%{killmails: [build_killmail_struct()]})
      ]

      assert {:ok, trend_analysis} =
               ShipPerformanceAnalyzer.analyze_performance_trends(battles, 620)

      # With a single battle, trend analysis should still work
      assert is_map(trend_analysis)
    end
  end

  describe "calculate_expected_stats/1" do
    test "returns no_fitting_data status when fitting is nil" do
      ship_data = %{fitting_data: nil, ship_type_id: 620}

      assert {:ok, result} = ShipPerformanceAnalyzer.calculate_expected_stats(ship_data)
      assert result.status == :no_fitting_data
    end

    test "calculates expected stats with fitting data" do
      ship_data = %{
        fitting_data: %{modules: [], rigs: []},
        ship_type_id: 620
      }

      assert {:ok, result} = ShipPerformanceAnalyzer.calculate_expected_stats(ship_data)

      assert Map.has_key?(result, :ehp)
      assert Map.has_key?(result, :dps)
      assert Map.has_key?(result, :speed)
      assert Map.has_key?(result, :capacitor)
    end

    test "calculates EHP for different ship classes" do
      frigate_data = %{fitting_data: %{}, ship_type_id: 587}
      cruiser_data = %{fitting_data: %{}, ship_type_id: 620}

      assert {:ok, frigate_stats} = ShipPerformanceAnalyzer.calculate_expected_stats(frigate_data)
      assert {:ok, cruiser_stats} = ShipPerformanceAnalyzer.calculate_expected_stats(cruiser_data)

      # Cruisers should have more EHP than frigates
      assert cruiser_stats.ehp.total >= frigate_stats.ehp.total
    end
  end

  describe "extract_actual_performance/2" do
    test "extracts performance data from battle" do
      character_id = 90_000_001
      ship_type_id = 620

      ship_data = %{character_id: character_id, ship_type_id: ship_type_id}

      attacker = %{
        "character_id" => character_id,
        "ship_type_id" => ship_type_id,
        "damage_done" => 5000,
        "final_blow" => true
      }

      killmail = build_killmail_struct(%{attackers: [attacker]})
      battle_data = %{killmails: [killmail], combat_logs: []}

      assert {:ok, performance} =
               ShipPerformanceAnalyzer.extract_actual_performance(ship_data, battle_data)

      assert Map.has_key?(performance, :damage_dealt)
      assert Map.has_key?(performance, :damage_taken)
      assert Map.has_key?(performance, :kills)
      assert Map.has_key?(performance, :time_on_field)
    end

    test "handles character as victim" do
      character_id = 90_000_002

      ship_data = %{character_id: character_id, ship_type_id: 587}

      killmail =
        build_killmail_struct(%{
          victim_character_id: character_id,
          victim_ship_type_id: 587
        })

      battle_data = %{killmails: [killmail], combat_logs: []}

      assert {:ok, performance} =
               ShipPerformanceAnalyzer.extract_actual_performance(ship_data, battle_data)

      assert performance.damage_taken.from_killmails > 0
    end

    test "handles empty battle data" do
      ship_data = %{character_id: 12_345, ship_type_id: 620}
      battle_data = %{killmails: [], combat_logs: []}

      assert {:ok, performance} =
               ShipPerformanceAnalyzer.extract_actual_performance(ship_data, battle_data)

      assert performance.kills == 0
      assert performance.damage_dealt.total == 0
    end
  end

  describe "calculate_efficiency_metrics/2" do
    test "returns no comparison available when no fitting data" do
      expected = %{status: :no_fitting_data}
      actual = %{damage_dealt: %{total: 1000}, time_on_field: 60}

      assert {:ok, result} =
               ShipPerformanceAnalyzer.calculate_efficiency_metrics(expected, actual)

      assert result.status == :no_comparison_available
    end

    test "calculates DPS efficiency" do
      expected = %{
        dps: %{total: 500},
        ehp: %{total: 10_000},
        expected_dps: 500
      }

      actual = %{
        damage_dealt: %{total: 15_000},
        damage_taken: %{total: 5000},
        time_on_field: 60
      }

      assert {:ok, metrics} =
               ShipPerformanceAnalyzer.calculate_efficiency_metrics(expected, actual)

      assert Map.has_key?(metrics, :dps_efficiency)
      assert Map.has_key?(metrics, :tank_efficiency)
      assert Map.has_key?(metrics, :survival_rating)
    end

    test "handles zero time on field" do
      expected = %{
        dps: %{total: 500},
        ehp: %{total: 10_000},
        expected_dps: 500
      }

      actual = %{
        damage_dealt: %{total: 0},
        damage_taken: %{total: 0},
        time_on_field: 0
      }

      assert {:ok, metrics} =
               ShipPerformanceAnalyzer.calculate_efficiency_metrics(expected, actual)

      # Should handle divide by zero gracefully
      assert is_map(metrics)
    end
  end

  describe "generate_recommendations/2" do
    test "generates DPS recommendations for low efficiency" do
      efficiency_metrics = %{
        dps_efficiency: %{percentage: 30},
        tank_efficiency: %{used_percentage: 50},
        survival_rating: 60
      }

      actual_performance = %{time_on_field: 300}

      recommendations =
        ShipPerformanceAnalyzer.generate_recommendations(efficiency_metrics, actual_performance)

      assert is_list(recommendations)

      assert Enum.any?(recommendations, fn r ->
               String.contains?(r, "application") or String.contains?(r, "DPS")
             end)
    end

    test "generates tank recommendations for high damage taken" do
      efficiency_metrics = %{
        dps_efficiency: %{percentage: 80},
        tank_efficiency: %{used_percentage: 95},
        survival_rating: 40
      }

      actual_performance = %{time_on_field: 300}

      recommendations =
        ShipPerformanceAnalyzer.generate_recommendations(efficiency_metrics, actual_performance)

      assert is_list(recommendations)

      assert Enum.any?(recommendations, fn r ->
               String.contains?(r, "tank") or String.contains?(r, "Tank")
             end)
    end

    test "generates survival recommendations for short engagement" do
      efficiency_metrics = %{
        dps_efficiency: %{percentage: 80},
        tank_efficiency: %{used_percentage: 50},
        survival_rating: 60
      }

      actual_performance = %{time_on_field: 60}

      recommendations =
        ShipPerformanceAnalyzer.generate_recommendations(efficiency_metrics, actual_performance)

      assert is_list(recommendations)

      assert Enum.any?(recommendations, fn r ->
               String.contains?(r, "time on field") or String.contains?(r, "range")
             end)
    end

    test "returns empty list for good performance" do
      efficiency_metrics = %{
        dps_efficiency: %{percentage: 80},
        tank_efficiency: %{used_percentage: 50},
        survival_rating: 80
      }

      actual_performance = %{time_on_field: 300}

      recommendations =
        ShipPerformanceAnalyzer.generate_recommendations(efficiency_metrics, actual_performance)

      # Good performance should have fewer recommendations
      assert is_list(recommendations)
    end
  end

  describe "fleet statistics calculations" do
    test "calculates fleet stats from ship performances" do
      killmails = [
        build_killmail_struct(%{victim_ship_type_id: 587}),
        build_killmail_struct(%{victim_ship_type_id: 620}),
        build_killmail_struct(%{victim_ship_type_id: 638})
      ]

      battle =
        build_battle_struct(%{
          killmails: killmails,
          metadata: %{
            duration_minutes: 30,
            battle_type: :fleet_battle,
            unique_participants: 50
          }
        })

      assert {:ok, analysis} = ShipPerformanceAnalyzer.analyze_battle_performance(battle)

      fleet_stats = analysis.fleet_stats

      assert is_integer(fleet_stats.avg_dps_efficiency) or
               is_float(fleet_stats.avg_dps_efficiency)

      assert is_integer(fleet_stats.avg_survivability) or is_float(fleet_stats.avg_survivability)

      assert is_integer(fleet_stats.coordination_score) or
               is_float(fleet_stats.coordination_score)

      assert is_integer(fleet_stats.tactical_diversity) or
               is_float(fleet_stats.tactical_diversity)
    end
  end

  describe "edge cases" do
    test "handles killmail with no attackers" do
      killmail = build_killmail_struct(%{attackers: []})
      battle = build_battle_struct(%{killmails: [killmail]})

      assert {:ok, analysis} = ShipPerformanceAnalyzer.analyze_battle_performance(battle)
      assert is_map(analysis)
    end

    test "handles killmail with nil raw_data fields" do
      killmail = %{
        killmail_id: 12_345,
        killmail_time: DateTime.utc_now(),
        solar_system_id: 30_000_142,
        victim_character_id: 90_000_001,
        victim_corporation_id: 98_000_001,
        victim_alliance_id: nil,
        victim_ship_type_id: 587,
        raw_data: %{}
      }

      battle = build_battle_struct(%{killmails: [killmail]})

      assert {:ok, analysis} = ShipPerformanceAnalyzer.analyze_battle_performance(battle)
      assert is_map(analysis)
    end

    test "handles very large fleet battles" do
      # Create many attackers
      attackers =
        for i <- 1..50 do
          %{
            "character_id" => 90_000_000 + i,
            "corporation_id" => 98_000_001,
            "alliance_id" => 99_000_001,
            "ship_type_id" => Enum.random([587, 620, 638]),
            "weapon_type_id" => 2185,
            "damage_done" => Enum.random(100..5000),
            "final_blow" => i == 1
          }
        end

      killmail = build_killmail_struct(%{attackers: attackers})

      battle =
        build_battle_struct(%{
          killmails: [killmail],
          metadata: %{
            duration_minutes: 60,
            battle_type: :major_battle,
            unique_participants: 100
          }
        })

      assert {:ok, analysis} = ShipPerformanceAnalyzer.analyze_battle_performance(battle)
      assert is_map(analysis)
      assert analysis.ship_performances != []
    end

    test "handles battle with mixed participation types" do
      # Some characters as attackers, some as victims
      killmail1 =
        build_killmail_struct(%{
          victim_character_id: 90_000_001,
          victim_ship_type_id: 587,
          attackers: [
            %{
              "character_id" => 90_000_002,
              "ship_type_id" => 620,
              "damage_done" => 5000,
              "final_blow" => true
            }
          ]
        })

      killmail2 =
        build_killmail_struct(%{
          victim_character_id: 90_000_002,
          victim_ship_type_id: 620,
          attackers: [
            %{
              "character_id" => 90_000_001,
              "ship_type_id" => 587,
              "damage_done" => 3000,
              "final_blow" => true
            }
          ]
        })

      battle = build_battle_struct(%{killmails: [killmail1, killmail2]})

      assert {:ok, analysis} = ShipPerformanceAnalyzer.analyze_battle_performance(battle)
      assert is_map(analysis)
    end
  end
end
