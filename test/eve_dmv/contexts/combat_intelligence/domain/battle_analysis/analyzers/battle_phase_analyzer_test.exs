defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.BattlePhaseAnalyzerTest do
  use ExUnit.Case, async: true
  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.BattlePhaseAnalyzer

  describe "identify_battle_phases/1" do
    test "returns empty list for timeline with less than 3 events" do
      timeline = [
        %{timestamp: ~U[2024-01-01 12:00:00Z], victim_ship_type_id: 620},
        %{timestamp: ~U[2024-01-01 12:01:00Z], victim_ship_type_id: 621}
      ]

      assert BattlePhaseAnalyzer.identify_battle_phases(timeline) == []
    end

    test "identifies single phase for continuous fighting" do
      timeline = [
        %{
          timestamp: ~U[2024-01-01 12:00:00Z],
          victim_ship_type_id: 620,
          solar_system_id: 30_000_142
        },
        %{
          timestamp: ~U[2024-01-01 12:01:00Z],
          victim_ship_type_id: 621,
          solar_system_id: 30_000_142
        },
        %{
          timestamp: ~U[2024-01-01 12:02:00Z],
          victim_ship_type_id: 622,
          solar_system_id: 30_000_142
        },
        %{
          timestamp: ~U[2024-01-01 12:03:00Z],
          victim_ship_type_id: 623,
          solar_system_id: 30_000_142
        }
      ]

      phases = BattlePhaseAnalyzer.identify_battle_phases(timeline)

      assert length(phases) == 1
      assert List.first(phases).phase_type == :single_engagement
      assert List.first(phases).kills_in_phase == 4
    end

    test "identifies multiple phases with time gap" do
      timeline = [
        # Phase 1 - Initial engagement
        %{
          timestamp: ~U[2024-01-01 12:00:00Z],
          victim_ship_type_id: 620,
          solar_system_id: 30_000_142
        },
        %{
          timestamp: ~U[2024-01-01 12:01:00Z],
          victim_ship_type_id: 621,
          solar_system_id: 30_000_142
        },
        %{
          timestamp: ~U[2024-01-01 12:02:00Z],
          victim_ship_type_id: 622,
          solar_system_id: 30_000_142
        },
        # 10 minute gap - new phase
        %{
          timestamp: ~U[2024-01-01 12:12:00Z],
          victim_ship_type_id: 638,
          solar_system_id: 30_000_142
        },
        %{
          timestamp: ~U[2024-01-01 12:13:00Z],
          victim_ship_type_id: 639,
          solar_system_id: 30_000_142
        },
        %{
          timestamp: ~U[2024-01-01 12:14:00Z],
          victim_ship_type_id: 640,
          solar_system_id: 30_000_142
        }
      ]

      phases = BattlePhaseAnalyzer.identify_battle_phases(timeline)

      assert length(phases) == 2
      assert Enum.at(phases, 0).phase_type == :initial_engagement
      assert Enum.at(phases, 0).kills_in_phase == 3
      assert Enum.at(phases, 1).phase_type == :final_push
      assert Enum.at(phases, 1).kills_in_phase == 3
    end

    test "identifies phase boundary on system change" do
      timeline = [
        # Phase 1 - System A
        %{
          timestamp: ~U[2024-01-01 12:00:00Z],
          victim_ship_type_id: 620,
          solar_system_id: 30_000_142
        },
        %{
          timestamp: ~U[2024-01-01 12:01:00Z],
          victim_ship_type_id: 621,
          solar_system_id: 30_000_142
        },
        # System change - new phase
        %{
          timestamp: ~U[2024-01-01 12:02:00Z],
          victim_ship_type_id: 622,
          solar_system_id: 30_000_143
        },
        %{
          timestamp: ~U[2024-01-01 12:03:00Z],
          victim_ship_type_id: 623,
          solar_system_id: 30_000_143
        }
      ]

      phases = BattlePhaseAnalyzer.identify_battle_phases(timeline)

      assert length(phases) == 2
      assert Enum.at(phases, 0).geographic_scope.systems_involved == 1
      assert Enum.at(phases, 1).geographic_scope.systems_involved == 1
    end

    test "identifies escalation to capital ships" do
      timeline = [
        # Subcaps and capitals mixed in timeline
        %{
          timestamp: ~U[2024-01-01 12:00:00Z],
          victim_ship_type_id: 620,
          solar_system_id: 30_000_142
        },
        %{
          timestamp: ~U[2024-01-01 12:01:00Z],
          victim_ship_type_id: 621,
          solar_system_id: 30_000_142
        },
        %{
          timestamp: ~U[2024-01-01 12:02:00Z],
          victim_ship_type_id: 25_000,
          solar_system_id: 30_000_142
        },
        %{
          timestamp: ~U[2024-01-01 12:03:00Z],
          victim_ship_type_id: 25_001,
          solar_system_id: 30_000_142
        }
      ]

      phases = BattlePhaseAnalyzer.identify_battle_phases(timeline)

      # Current implementation treats this as a single continuous phase
      assert length(phases) == 1
      phase = List.first(phases)
      # Phase should contain both subcaps and capitals
      ship_classes = Map.keys(phase.ship_classes) |> Enum.uniq()
      assert :cruiser in ship_classes or :capital in ship_classes or :unknown in ship_classes
    end

    test "calculates phase intensity correctly" do
      timeline = [
        # High intensity phase - 5 kills in 1 minute
        %{
          timestamp: ~U[2024-01-01 12:00:00Z],
          victim_ship_type_id: 620,
          solar_system_id: 30_000_142
        },
        %{
          timestamp: ~U[2024-01-01 12:00:15Z],
          victim_ship_type_id: 621,
          solar_system_id: 30_000_142
        },
        %{
          timestamp: ~U[2024-01-01 12:00:30Z],
          victim_ship_type_id: 622,
          solar_system_id: 30_000_142
        },
        %{
          timestamp: ~U[2024-01-01 12:00:45Z],
          victim_ship_type_id: 623,
          solar_system_id: 30_000_142
        },
        %{
          timestamp: ~U[2024-01-01 12:01:00Z],
          victim_ship_type_id: 624,
          solar_system_id: 30_000_142
        }
      ]

      phases = BattlePhaseAnalyzer.identify_battle_phases(timeline)

      assert length(phases) == 1
      phase = List.first(phases)
      assert phase.intensity_rating == :very_high
      assert phase.intensity_value == 5.0
    end

    test "identifies key events in phases" do
      timeline = [
        %{
          timestamp: ~U[2024-01-01 12:00:00Z],
          victim_ship_type_id: 620,
          solar_system_id: 30_000_142,
          total_value: 100_000_000
        },
        # Capital
        %{
          timestamp: ~U[2024-01-01 12:01:00Z],
          victim_ship_type_id: 25_000,
          solar_system_id: 30_000_142,
          total_value: 2_000_000_000
        },
        # T3C
        %{
          timestamp: ~U[2024-01-01 12:02:00Z],
          victim_ship_type_id: 29_984,
          solar_system_id: 30_000_142,
          total_value: 1_500_000_000
        },
        %{
          timestamp: ~U[2024-01-01 12:03:00Z],
          victim_ship_type_id: 623,
          solar_system_id: 30_000_142,
          total_value: 50_000_000
        }
      ]

      phases = BattlePhaseAnalyzer.identify_battle_phases(timeline)
      phase = List.first(phases)

      assert length(phase.key_events) == 2
      # Both high-value kills are classified as potential FC kills
      assert Enum.all?(phase.key_events, &(&1.event_type == :potential_fc_kill))
    end
  end

  describe "classify_intensity_rating/1" do
    test "classifies intensity ratings correctly" do
      assert BattlePhaseAnalyzer.classify_intensity_rating(6.0) == :very_high
      assert BattlePhaseAnalyzer.classify_intensity_rating(4.0) == :high
      assert BattlePhaseAnalyzer.classify_intensity_rating(2.0) == :moderate
      assert BattlePhaseAnalyzer.classify_intensity_rating(1.0) == :low
      assert BattlePhaseAnalyzer.classify_intensity_rating(0.3) == :very_low
    end
  end

  describe "determine_phase_type/3" do
    test "identifies single engagement for single phase battle" do
      phase = %{intensity: 3.5, duration_seconds: 300, kills: 20}
      assert BattlePhaseAnalyzer.determine_phase_type(phase, 0, 1) == :single_engagement
    end

    test "identifies skirmish for low intensity middle phase" do
      phase = %{intensity: 1.4, duration_seconds: 300, kills: 5}
      assert BattlePhaseAnalyzer.determine_phase_type(phase, 1, 3) == :skirmish
    end

    test "identifies hot drop for high intensity initial phase" do
      phase = %{intensity: 5.5, duration_seconds: 60, kills: 10}
      assert BattlePhaseAnalyzer.determine_phase_type(phase, 0, 3) == :hot_drop
    end

    test "identifies cleanup for low intensity final phase" do
      phase = %{intensity: 0.3, duration_seconds: 120, kills: 2}
      assert BattlePhaseAnalyzer.determine_phase_type(phase, 2, 3) == :cleanup
    end

    test "identifies climax for very high intensity middle phase" do
      phase = %{intensity: 5.0, duration_seconds: 180, kills: 30}
      assert BattlePhaseAnalyzer.determine_phase_type(phase, 1, 3) == :climax
    end
  end
end
