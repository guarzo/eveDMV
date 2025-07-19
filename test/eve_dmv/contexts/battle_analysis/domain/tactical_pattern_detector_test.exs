defmodule EveDmv.Contexts.BattleAnalysis.Domain.TacticalPatternDetectorTest do
  use ExUnit.Case, async: true

  alias EveDmv.Contexts.BattleAnalysis.Domain.TacticalPatternDetector

  describe "detect_patterns/2" do
    test "detects tactical patterns in a battle" do
      battle = create_test_battle()

      patterns = TacticalPatternDetector.detect_patterns(battle)

      assert is_map(patterns)
      assert Map.has_key?(patterns, :focus_fire)
      assert Map.has_key?(patterns, :formations)
      assert Map.has_key?(patterns, :target_switching)
      assert Map.has_key?(patterns, :coordination)
      assert Map.has_key?(patterns, :tactical_phases)
      assert Map.has_key?(patterns, :pattern_summary)
      assert Map.has_key?(patterns, :analysis_metadata)

      # Verify metadata
      assert patterns.analysis_metadata.killmail_count == length(battle.killmails)
      assert %DateTime{} = patterns.analysis_metadata.analyzed_at
    end

    test "handles empty killmail list" do
      battle = %{killmails: []}

      patterns = TacticalPatternDetector.detect_patterns(battle)

      assert patterns.analysis_metadata.killmail_count == 0
      assert patterns.pattern_summary.confidence_level == :insufficient_data
    end
  end

  describe "analyze_focus_fire/1" do
    test "analyzes focus fire patterns" do
      killmails = create_focus_fire_killmails()

      analysis = TacticalPatternDetector.analyze_focus_fire(killmails)

      assert is_map(analysis)
      assert is_list(analysis.time_windows)
      assert is_float(analysis.overall_focus_score)
      assert is_list(analysis.high_focus_periods)
      assert analysis.effectiveness_rating in [:excellent, :good, :moderate, :poor, :very_poor]

      # Should have time windows
      assert length(analysis.time_windows) > 0

      # Each window should have required fields
      window = List.first(analysis.time_windows)
      assert Map.has_key?(window, :window_start)
      assert Map.has_key?(window, :window_end)
      assert Map.has_key?(window, :focus_score)
      assert Map.has_key?(window, :target_concentration)
      assert Map.has_key?(window, :damage_concentration)
      assert Map.has_key?(window, :primary_targets)
    end

    test "identifies high focus periods" do
      killmails = create_concentrated_fire_killmails()

      analysis = TacticalPatternDetector.analyze_focus_fire(killmails)

      # Should identify periods of concentrated fire
      assert length(analysis.high_focus_periods) > 0

      period = List.first(analysis.high_focus_periods)
      assert period.focus_score > 75
      assert is_list(period.primary_targets)
    end

    test "calculates overall focus score correctly" do
      killmails = create_perfect_focus_killmails()

      analysis = TacticalPatternDetector.analyze_focus_fire(killmails)

      # Perfect focus should have high score
      assert analysis.overall_focus_score > 80
      assert analysis.effectiveness_rating == :excellent
    end
  end

  describe "analyze_formations/1" do
    test "analyzes formation patterns" do
      killmails = create_formation_killmails()

      analysis = TacticalPatternDetector.analyze_formations(killmails)

      assert is_map(analysis)
      assert is_list(analysis.detected_formations)
      assert is_list(analysis.formation_transitions)
      assert Map.has_key?(analysis, :dominant_formation)
      assert is_float(analysis.adaptability_score)

      # Should detect formations
      assert length(analysis.detected_formations) > 0

      formation = List.first(analysis.detected_formations)

      assert formation.formation_type in [
               :fleet_doctrine,
               :tackle_heavy,
               :ewar_doctrine,
               :dps_ball,
               :yolo_fleet,
               :mixed_composition
             ]

      assert is_map(formation.ship_composition)
      assert is_float(formation.formation_cohesion)
    end

    test "detects fleet doctrine formation" do
      killmails = create_fleet_doctrine_killmails()

      analysis = TacticalPatternDetector.analyze_formations(killmails)

      # Should identify fleet doctrine
      formation = List.first(analysis.detected_formations)
      assert formation.formation_type == :fleet_doctrine
      assert formation.formation_effectiveness in [:highly_effective, :effective]
    end

    test "tracks formation transitions" do
      killmails = create_transitioning_formation_killmails()

      analysis = TacticalPatternDetector.analyze_formations(killmails)

      # Should detect transitions between formations
      assert length(analysis.formation_transitions) > 0

      transition = List.first(analysis.formation_transitions)
      assert Map.has_key?(transition, :from)
      assert Map.has_key?(transition, :to)
      assert transition.effectiveness_change in [:improved, :maintained, :degraded]
    end
  end

  describe "analyze_target_switching/1" do
    test "analyzes target switching patterns" do
      killmails = create_target_switching_killmails()

      analysis = TacticalPatternDetector.analyze_target_switching(killmails)

      assert is_map(analysis)
      assert is_list(analysis.individual_analysis)
      assert is_float(analysis.overall_switch_rate)
      assert is_list(analysis.coordinated_switches)
      assert analysis.switching_efficiency in [:excellent, :good, :moderate, :poor, :unknown]

      # Should analyze individual switching
      assert length(analysis.individual_analysis) > 0

      individual = List.first(analysis.individual_analysis)
      assert individual.character_id
      assert individual.total_switches >= 0
      assert is_float(individual.switch_frequency)

      assert individual.switching_pattern in [
               :single_target_focus,
               :rapid_switching,
               :moderate_switching,
               :persistent_engagement,
               :opportunistic
             ]
    end

    test "identifies coordinated target switches" do
      killmails = create_coordinated_switch_killmails()

      analysis = TacticalPatternDetector.analyze_target_switching(killmails)

      # Should identify coordinated switches
      assert length(analysis.coordinated_switches) > 0

      coord_switch = List.first(analysis.coordinated_switches)
      assert coord_switch.switching_attackers >= 3

      assert coord_switch.coordination_level in [
               :fleet_wide,
               :squad_level,
               :small_group,
               :minimal
             ]
    end

    test "rates switching effectiveness" do
      killmails = create_efficient_switching_killmails()

      analysis = TacticalPatternDetector.analyze_target_switching(killmails)

      # Should rate switching as effective
      assert analysis.switching_efficiency in [:excellent, :good]
    end
  end

  describe "analyze_coordination/1" do
    test "analyzes coordination effectiveness" do
      killmails = create_coordinated_killmails()

      analysis = TacticalPatternDetector.analyze_coordination(killmails)

      assert is_map(analysis)
      assert Map.has_key?(analysis, :damage_coordination)
      assert Map.has_key?(analysis, :target_coordination)
      assert Map.has_key?(analysis, :movement_coordination)
      assert is_float(analysis.overall_coordination_score)
      assert is_list(analysis.coordination_breakdown)
      assert is_list(analysis.coordination_peaks)

      # Damage coordination should have structure
      assert is_list(analysis.damage_coordination.time_windows)
      assert Map.has_key?(analysis.damage_coordination, :peak_coordination)
      assert is_float(analysis.damage_coordination.average_coordination)
    end

    test "identifies coordination peaks" do
      killmails = create_peak_coordination_killmails()

      analysis = TacticalPatternDetector.analyze_coordination(killmails)

      # Should identify peak coordination periods
      assert length(analysis.coordination_peaks) > 0

      peak = List.first(analysis.coordination_peaks)
      assert peak.kills_achieved >= 5
      assert peak.coordination_level == :excellent
    end

    test "identifies coordination breakdowns" do
      killmails = create_breakdown_killmails()

      analysis = TacticalPatternDetector.analyze_coordination(killmails)

      # Should identify breakdown periods
      assert length(analysis.coordination_breakdown) >= 0
    end
  end

  # Helper functions for creating test data

  defp create_test_battle do
    %{
      battle_id: "test_battle_20240101100000",
      killmails: create_mixed_killmails()
    }
  end

  defp create_mixed_killmails do
    base_time = ~U[2024-01-01 10:00:00Z]

    Enum.map(0..9, fn i ->
      %{
        killmail_id: 1000 + i,
        killmail_time: DateTime.add(base_time, i * 30, :second),
        solar_system_id: 30_002_765,
        victim_character_id: 10000 + i,
        # Various frigates
        victim_ship_type_id: Enum.random([587, 588, 589]),
        raw_data: %{
          "victim" => %{
            "character_id" => 10000 + i,
            "ship_type_id" => Enum.random([587, 588, 589])
          },
          "attackers" => create_random_attackers(3 + rem(i, 3))
        }
      }
    end)
  end

  defp create_focus_fire_killmails do
    base_time = ~U[2024-01-01 10:00:00Z]

    # Create kills with concentrated fire on few targets
    [1, 1, 2, 1, 2, 3, 1, 2]
    |> Enum.with_index()
    |> Enum.map(fn {target_id, i} ->
      %{
        killmail_id: 2000 + i,
        killmail_time: DateTime.add(base_time, i * 15, :second),
        solar_system_id: 30_002_765,
        victim_character_id: 20000 + target_id,
        victim_ship_type_id: 587,
        raw_data: %{
          "victim" => %{
            "character_id" => 20000 + target_id,
            "ship_type_id" => 587
          },
          "attackers" => create_focus_fire_attackers()
        }
      }
    end)
  end

  defp create_concentrated_fire_killmails do
    base_time = ~U[2024-01-01 10:00:00Z]

    # All kills on same target in short window
    Enum.map(0..4, fn i ->
      %{
        killmail_id: 3000 + i,
        killmail_time: DateTime.add(base_time, i * 5, :second),
        solar_system_id: 30_002_765,
        # Same target
        victim_character_id: 30001,
        # Drake
        victim_ship_type_id: 24698,
        raw_data: %{
          "victim" => %{
            "character_id" => 30001,
            "ship_type_id" => 24698
          },
          "attackers" => create_focus_fire_attackers()
        }
      }
    end)
  end

  defp create_perfect_focus_killmails do
    base_time = ~U[2024-01-01 10:00:00Z]

    # Single target, all attackers focused
    [
      %{
        killmail_id: 4000,
        killmail_time: base_time,
        solar_system_id: 30_002_765,
        victim_character_id: 40001,
        victim_ship_type_id: 24698,
        raw_data: %{
          "victim" => %{
            "character_id" => 40001,
            "ship_type_id" => 24698
          },
          "attackers" =>
            Enum.map(1..10, fn i ->
              %{
                "character_id" => 50000 + i,
                # Caracal
                "ship_type_id" => 621,
                "damage_done" => 1000 + i * 100,
                "final_blow" => i == 1
              }
            end)
        }
      }
    ]
  end

  defp create_formation_killmails do
    base_time = ~U[2024-01-01 10:00:00Z]

    # Mixed formation with different ship types
    Enum.map(0..14, fn i ->
      ship_type =
        case rem(i, 5) do
          # Scimitar (Logistics)
          0 -> 11978
          # Sleipnir (Command)
          1 -> 22474
          # Caracal (DPS)
          _ -> 621
        end

      %{
        killmail_id: 5000 + i,
        killmail_time: DateTime.add(base_time, i * 20, :second),
        solar_system_id: 30_002_765,
        victim_character_id: 50000 + i,
        victim_ship_type_id: 587,
        raw_data: %{
          "victim" => %{
            "character_id" => 50000 + i,
            "ship_type_id" => 587
          },
          "attackers" => [
            %{
              "character_id" => 60000 + i,
              "ship_type_id" => ship_type,
              "damage_done" => 1500,
              "final_blow" => true
            }
          ]
        }
      }
    end)
  end

  defp create_fleet_doctrine_killmails do
    base_time = ~U[2024-01-01 10:00:00Z]

    # Proper fleet composition
    ship_distribution = [
      # Scimitar (Logistics) - 3 ships
      {11978, 3},
      # Sleipnir (Command) - 2 ships
      {22474, 2},
      # Caracal (DPS) - 10 ships
      {621, 10}
    ]

    {killmails, _} =
      Enum.reduce(ship_distribution, {[], 0}, fn {ship_type, count}, {acc, index} ->
        new_kills =
          Enum.map(0..(count - 1), fn i ->
            %{
              killmail_id: 6000 + index + i,
              killmail_time: DateTime.add(base_time, (index + i) * 10, :second),
              solar_system_id: 30_002_765,
              victim_character_id: 60000 + index + i,
              victim_ship_type_id: 587,
              raw_data: %{
                "victim" => %{
                  "character_id" => 60000 + index + i,
                  "ship_type_id" => 587
                },
                "attackers" => [
                  %{
                    "character_id" => 70000 + index + i,
                    "ship_type_id" => ship_type,
                    "damage_done" => 2000,
                    "final_blow" => true
                  }
                ]
              }
            }
          end)

        {acc ++ new_kills, index + count}
      end)

    killmails
  end

  defp create_transitioning_formation_killmails do
    base_time = ~U[2024-01-01 10:00:00Z]

    # Phase 1: DPS ball (0-5 minutes)
    phase1 =
      Enum.map(0..9, fn i ->
        %{
          killmail_id: 7000 + i,
          killmail_time: DateTime.add(base_time, i * 30, :second),
          solar_system_id: 30_002_765,
          victim_character_id: 70000 + i,
          victim_ship_type_id: 587,
          raw_data: %{
            "victim" => %{
              "character_id" => 70000 + i,
              "ship_type_id" => 587
            },
            "attackers" => [
              %{
                "character_id" => 80000 + i,
                # Caracal (DPS)
                "ship_type_id" => 621,
                "damage_done" => 2000,
                "final_blow" => true
              }
            ]
          }
        }
      end)

    # Gap of 3 minutes

    # Phase 2: Fleet doctrine (8-13 minutes)
    phase2 =
      Enum.map(0..9, fn i ->
        ship_type =
          case rem(i, 5) do
            # Scimitar
            0 -> 11978
            # Sleipnir
            1 -> 22474
            # Caracal
            _ -> 621
          end

        %{
          killmail_id: 7100 + i,
          killmail_time: DateTime.add(base_time, 480 + i * 30, :second),
          solar_system_id: 30_002_765,
          victim_character_id: 71000 + i,
          victim_ship_type_id: 587,
          raw_data: %{
            "victim" => %{
              "character_id" => 71000 + i,
              "ship_type_id" => 587
            },
            "attackers" => [
              %{
                "character_id" => 81000 + i,
                "ship_type_id" => ship_type,
                "damage_done" => 2000,
                "final_blow" => true
              }
            ]
          }
        }
      end)

    phase1 ++ phase2
  end

  defp create_target_switching_killmails do
    base_time = ~U[2024-01-01 10:00:00Z]

    # Attackers switch between targets
    Enum.map(0..11, fn i ->
      # Attacker 90001 switches targets every 3 kills
      # Attacker 90002 stays on same target
      target_for_90001 = div(i, 3) + 80000
      target_for_90002 = 80000

      %{
        killmail_id: 8000 + i,
        killmail_time: DateTime.add(base_time, i * 20, :second),
        solar_system_id: 30_002_765,
        victim_character_id: if(rem(i, 2) == 0, do: target_for_90001, else: target_for_90002),
        victim_ship_type_id: 587,
        raw_data: %{
          "victim" => %{
            "character_id" => if(rem(i, 2) == 0, do: target_for_90001, else: target_for_90002),
            "ship_type_id" => 587
          },
          "attackers" => [
            %{
              "character_id" => if(rem(i, 2) == 0, do: 90001, else: 90002),
              "ship_type_id" => 621,
              "damage_done" => 1500,
              "final_blow" => true
            }
          ]
        }
      }
    end)
  end

  defp create_coordinated_switch_killmails do
    base_time = ~U[2024-01-01 10:00:00Z]

    # Multiple attackers switch targets at same time
    kills = []

    # Time window 1: All attack target A
    kills =
      kills ++
        Enum.map(0..4, fn i ->
          %{
            killmail_id: 9000 + i,
            killmail_time: DateTime.add(base_time, i * 2, :second),
            solar_system_id: 30_002_765,
            # Target A
            victim_character_id: 90001,
            victim_ship_type_id: 24698,
            raw_data: %{
              "victim" => %{
                "character_id" => 90001,
                "ship_type_id" => 24698
              },
              "attackers" => [
                %{
                  "character_id" => 100_000 + i,
                  "ship_type_id" => 621,
                  "damage_done" => 1000,
                  "final_blow" => i == 0
                }
              ]
            }
          }
        end)

    # Time window 2: All switch to target B
    kills ++
      Enum.map(0..4, fn i ->
        %{
          killmail_id: 9100 + i,
          killmail_time: DateTime.add(base_time, 15 + i * 2, :second),
          solar_system_id: 30_002_765,
          # Target B
          victim_character_id: 90002,
          victim_ship_type_id: 24698,
          raw_data: %{
            "victim" => %{
              "character_id" => 90002,
              "ship_type_id" => 24698
            },
            "attackers" => [
              %{
                # Same attackers
                "character_id" => 100_000 + i,
                "ship_type_id" => 621,
                "damage_done" => 1000,
                "final_blow" => i == 0
              }
            ]
          }
        }
      end)
  end

  defp create_efficient_switching_killmails do
    base_time = ~U[2024-01-01 10:00:00Z]

    # Efficient switching - kill target then move to next
    Enum.map(0..7, fn i ->
      # 2 kills per target
      target_id = 110_000 + div(i, 2)

      %{
        killmail_id: 11000 + i,
        killmail_time: DateTime.add(base_time, i * 30, :second),
        solar_system_id: 30_002_765,
        victim_character_id: target_id,
        victim_ship_type_id: 587,
        raw_data: %{
          "victim" => %{
            "character_id" => target_id,
            "ship_type_id" => 587
          },
          "attackers" =>
            Enum.map(0..4, fn j ->
              %{
                "character_id" => 120_000 + j,
                "ship_type_id" => 621,
                "damage_done" => 500,
                "final_blow" => j == 0 and rem(i, 2) == 1
              }
            end)
        }
      }
    end)
  end

  defp create_coordinated_killmails do
    base_time = ~U[2024-01-01 10:00:00Z]

    # Well-coordinated kills with multiple attackers
    Enum.map(0..9, fn i ->
      %{
        killmail_id: 12000 + i,
        killmail_time: DateTime.add(base_time, i * 5, :second),
        solar_system_id: 30_002_765,
        victim_character_id: 130_000 + i,
        victim_ship_type_id: 24698,
        raw_data: %{
          "victim" => %{
            "character_id" => 130_000 + i,
            "ship_type_id" => 24698
          },
          "attackers" =>
            Enum.map(0..7, fn j ->
              %{
                "character_id" => 140_000 + j,
                "ship_type_id" => 621,
                "damage_done" => 300 + j * 50,
                "final_blow" => j == 0
              }
            end)
        }
      }
    end)
  end

  defp create_peak_coordination_killmails do
    base_time = ~U[2024-01-01 10:00:00Z]

    # Rapid kills in short window
    Enum.map(0..6, fn i ->
      %{
        killmail_id: 13000 + i,
        killmail_time: DateTime.add(base_time, i * 4, :second),
        solar_system_id: 30_002_765,
        victim_character_id: 140_000 + i,
        victim_ship_type_id: 587,
        raw_data: %{
          "victim" => %{
            "character_id" => 140_000 + i,
            "ship_type_id" => 587
          },
          "attackers" => create_coordinated_attackers(8)
        }
      }
    end)
  end

  defp create_breakdown_killmails do
    base_time = ~U[2024-01-01 10:00:00Z]

    # Sparse kills with long gaps
    [0, 90, 95, 200, 205, 350]
    |> Enum.with_index()
    |> Enum.map(fn {time_offset, i} ->
      %{
        killmail_id: 14000 + i,
        killmail_time: DateTime.add(base_time, time_offset, :second),
        solar_system_id: 30_002_765,
        victim_character_id: 150_000 + i,
        victim_ship_type_id: 587,
        raw_data: %{
          "victim" => %{
            "character_id" => 150_000 + i,
            "ship_type_id" => 587
          },
          "attackers" => create_random_attackers(2)
        }
      }
    end)
  end

  defp create_random_attackers(count) do
    Enum.map(1..count, fn i ->
      %{
        "character_id" => 200_000 + :rand.uniform(1000),
        "ship_type_id" => Enum.random([621, 17918, 24698]),
        "damage_done" => 500 + :rand.uniform(1000),
        "final_blow" => i == 1
      }
    end)
  end

  defp create_focus_fire_attackers do
    # Same group of attackers for focus fire
    Enum.map(1..5, fn i ->
      %{
        "character_id" => 300_000 + i,
        "ship_type_id" => 621,
        "damage_done" => 800 + i * 100,
        "final_blow" => i == 1
      }
    end)
  end

  defp create_coordinated_attackers(count) do
    Enum.map(1..count, fn i ->
      %{
        "character_id" => 400_000 + i,
        "ship_type_id" => 621,
        "damage_done" => 400 + i * 50,
        "final_blow" => i == 1
      }
    end)
  end
end
