defmodule EveDmv.Contexts.BattleAnalysis.Domain.BattleTimelineServiceTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.BattleAnalysis.Domain.BattleTimelineService

  describe "reconstruct_timeline/1" do
    test "creates detailed timeline from battle data" do
      battle = create_test_battle()

      timeline = BattleTimelineService.reconstruct_timeline(battle)

      assert timeline.battle_id == battle.battle_id
      assert timeline.start_time
      assert timeline.end_time
      assert timeline.duration_minutes
      assert is_list(timeline.events)
      assert is_list(timeline.phases)
      assert is_list(timeline.fleet_composition)
      assert is_list(timeline.key_moments)
      assert is_map(timeline.summary)
    end

    test "correctly identifies battle phases" do
      battle = create_escalation_battle()

      timeline = BattleTimelineService.reconstruct_timeline(battle)

      # Should have initial engagement and escalation phases
      assert length(timeline.phases) >= 2

      # First phase should be initial engagement
      first_phase = List.first(timeline.phases)
      assert first_phase.phase_type == :initial_engagement
      assert first_phase.event_count > 0

      # May have escalation phase depending on battle pattern
      escalation_phase = Enum.find(timeline.phases, &(&1.phase_type == :escalation))

      if escalation_phase do
        assert escalation_phase.event_count > 0
      end
    end

    test "tracks fleet composition changes over time" do
      battle = create_fleet_battle()

      timeline = BattleTimelineService.reconstruct_timeline(battle)

      assert Enum.any?(timeline.fleet_composition)

      composition_window = List.first(timeline.fleet_composition)
      assert composition_window.timestamp
      assert composition_window.active_attackers >= 0
      assert composition_window.active_victims >= 0
      assert is_list(composition_window.pilot_ships)
      assert is_map(composition_window.corporation_breakdown)
      assert is_list(composition_window.sides)
    end

    test "identifies key moments correctly" do
      battle = create_test_battle()

      timeline = BattleTimelineService.reconstruct_timeline(battle)

      assert Enum.any?(timeline.key_moments)

      # Should have first blood
      first_blood = Enum.find(timeline.key_moments, &(&1.type == :first_blood))
      assert first_blood
      assert first_blood.description == "First kill of the battle"

      # Should have largest engagement
      largest_engagement = Enum.find(timeline.key_moments, &(&1.type == :largest_engagement))
      assert largest_engagement
      assert String.contains?(largest_engagement.description, "attackers")
    end

    test "generates meaningful battle summary" do
      battle = create_test_battle()

      timeline = BattleTimelineService.reconstruct_timeline(battle)

      summary = timeline.summary
      assert summary.total_kills == length(battle.killmails)
      assert is_binary(summary.phases)
      assert is_integer(summary.key_moments)
      assert String.contains?(summary.description, "Battle with")
    end

    test "handles single killmail battle" do
      battle = create_single_kill_battle()

      timeline = BattleTimelineService.reconstruct_timeline(battle)

      assert timeline.battle_id == battle.battle_id
      assert length(timeline.events) == 1
      assert timeline.phases != []
      assert timeline.key_moments != []
    end

    test "correctly analyzes battle sides" do
      battle = create_multi_corp_battle()

      timeline = BattleTimelineService.reconstruct_timeline(battle)

      composition = List.first(timeline.fleet_composition)
      assert length(composition.sides) >= 2

      # Each side should have corporations
      Enum.each(composition.sides, fn side ->
        assert is_binary(side.side_id)
        assert is_list(side.corporations)
        assert Enum.any?(side.corporations)
        assert is_integer(side.participant_count)
      end)
    end
  end

  describe "analyze_battle_sequence/1" do
    test "analyzes connections between battles" do
      battles = [
        create_test_battle(%{battle_id: "battle_1_20240101100000"}),
        create_test_battle(%{battle_id: "battle_2_20240101103000"})
      ]

      sequence = BattleTimelineService.analyze_battle_sequence(battles)

      assert length(sequence.battles) == 2
      assert is_list(sequence.connections)
      assert is_list(sequence.escalation_pattern)
      assert is_list(sequence.participant_flow)
    end

    test "identifies connected battles" do
      # Create battles with shared participants
      battles = [
        create_connected_battle(1, ~U[2024-01-01 10:00:00Z], [12_345, 67_890]),
        create_connected_battle(2, ~U[2024-01-01 10:15:00Z], [67_890, 11_111])
      ]

      sequence = BattleTimelineService.analyze_battle_sequence(battles)

      # Should detect connection due to shared participant
      assert Enum.any?(sequence.connections)
      connection = List.first(sequence.connections)
      assert connection.connection_type in [:same_system_continuation, :roaming_gang]
      assert connection.time_gap_minutes == 15
    end

    test "tracks escalation patterns" do
      battles = [
        # 5 participants
        create_escalating_battle(1, 5),
        # 10 participants
        create_escalating_battle(2, 10),
        # 15 participants
        create_escalating_battle(3, 15)
      ]

      sequence = BattleTimelineService.analyze_battle_sequence(battles)

      escalation = sequence.escalation_pattern
      assert length(escalation) == 3

      # Should show increasing participant counts
      participant_counts = Enum.map(escalation, & &1.participant_count)
      assert participant_counts == [5, 10, 15]
    end

    test "tracks participant flow between battles" do
      battles = [
        create_flow_battle(1, [12_345, 67_890, 11_111]),
        create_flow_battle(2, [67_890, 11_111, 22_222])
      ]

      sequence = BattleTimelineService.analyze_battle_sequence(battles)

      assert length(sequence.participant_flow) == 1
      flow = List.first(sequence.participant_flow)
      # 67_890, 11_111
      assert flow.continuing_participants == 2
      # 22_222
      assert flow.new_participants == 1
      # 12_345
      assert flow.departing_participants == 1
    end
  end

  # Helper functions to create test data

  defp create_test_battle(attrs \\ %{}) do
    default_attrs = %{
      battle_id: "battle_1_20240101100000",
      metadata: %{
        primary_system: 30_002_765,
        system_id: 30_002_765,
        start_time: ~U[2024-01-01 10:00:00Z],
        end_time: ~U[2024-01-01 10:15:00Z],
        duration_minutes: 15,
        participant_count: 5,
        unique_participants: 5
      },
      killmails: [
        create_test_killmail(%{
          killmail_id: 1,
          killmail_time: ~U[2024-01-01 10:00:00Z],
          victim_character_id: 12_345,
          victim_corporation_id: 98_765,
          raw_data: %{
            "victim" => %{
              "character_id" => 12_345,
              "character_name" => "Victim One",
              "corporation_id" => 98_765,
              "corporation_name" => "Victim Corp",
              "ship_type_id" => 670,
              "ship_name" => "Capsule"
            },
            "attackers" => [
              %{
                "character_id" => 67_890,
                "character_name" => "Attacker One",
                "corporation_id" => 54_321,
                "corporation_name" => "Attacker Corp",
                "ship_type_id" => 587,
                "ship_name" => "Rifter",
                "damage_done" => 1000,
                "final_blow" => true
              },
              %{
                "character_id" => 11_111,
                "character_name" => "Attacker Two",
                "corporation_id" => 54_321,
                "corporation_name" => "Attacker Corp",
                "ship_type_id" => 588,
                "ship_name" => "Punisher",
                "damage_done" => 500,
                "final_blow" => false
              }
            ]
          }
        }),
        create_test_killmail(%{
          killmail_id: 2,
          killmail_time: ~U[2024-01-01 10:05:00Z],
          victim_character_id: 22_222,
          victim_corporation_id: 98_765,
          raw_data: %{
            "victim" => %{
              "character_id" => 22_222,
              "character_name" => "Victim Two",
              "corporation_id" => 98_765,
              "corporation_name" => "Victim Corp",
              "ship_type_id" => 587,
              "ship_name" => "Rifter"
            },
            "attackers" => [
              %{
                "character_id" => 67_890,
                "character_name" => "Attacker One",
                "corporation_id" => 54_321,
                "corporation_name" => "Attacker Corp",
                "ship_type_id" => 587,
                "ship_name" => "Rifter",
                "damage_done" => 1200,
                "final_blow" => true
              }
            ]
          }
        })
      ]
    }

    Map.merge(default_attrs, attrs)
  end

  defp create_escalation_battle do
    %{
      battle_id: "battle_esc_20240101100000",
      metadata: %{
        primary_system: 30_002_765,
        system_id: 30_002_765,
        start_time: ~U[2024-01-01 10:00:00Z],
        end_time: ~U[2024-01-01 10:30:00Z],
        duration_minutes: 30,
        participant_count: 10,
        unique_participants: 10
      },
      killmails: [
        # Initial engagement
        create_test_killmail(%{
          killmail_id: 1,
          killmail_time: ~U[2024-01-01 10:00:00Z],
          victim_character_id: 12_345
        }),
        create_test_killmail(%{
          killmail_id: 2,
          killmail_time: ~U[2024-01-01 10:01:00Z],
          victim_character_id: 22_222
        }),
        # Escalation phase - rapid kills
        create_test_killmail(%{
          killmail_id: 3,
          killmail_time: ~U[2024-01-01 10:10:00Z],
          victim_character_id: 33_333
        }),
        create_test_killmail(%{
          killmail_id: 4,
          killmail_time: ~U[2024-01-01 10:11:00Z],
          victim_character_id: 44_444
        }),
        create_test_killmail(%{
          killmail_id: 5,
          killmail_time: ~U[2024-01-01 10:12:00Z],
          victim_character_id: 55_555
        }),
        create_test_killmail(%{
          killmail_id: 6,
          killmail_time: ~U[2024-01-01 10:13:00Z],
          victim_character_id: 66_666
        })
      ]
    }
  end

  defp create_fleet_battle do
    %{
      battle_id: "battle_fleet_20240101100000",
      metadata: %{
        primary_system: 30_002_765,
        system_id: 30_002_765,
        start_time: ~U[2024-01-01 10:00:00Z],
        end_time: ~U[2024-01-01 10:20:00Z],
        duration_minutes: 20,
        participant_count: 20,
        unique_participants: 20
      },
      killmails: [
        # Multiple kills with different ship types
        create_test_killmail(%{
          killmail_id: 1,
          killmail_time: ~U[2024-01-01 10:00:00Z],
          victim_character_id: 12_345,
          raw_data: %{
            "victim" => %{
              "character_id" => 12_345,
              # Cyclone
              "ship_type_id" => 17_918,
              "ship_name" => "Cyclone"
            },
            "attackers" => [
              %{
                "character_id" => 67_890,
                # Rifter
                "ship_type_id" => 587,
                "ship_name" => "Rifter",
                "damage_done" => 500,
                "final_blow" => false
              },
              %{
                "character_id" => 11_111,
                # Scythe
                "ship_type_id" => 11_129,
                "ship_name" => "Scythe",
                "damage_done" => 0,
                "final_blow" => false
              },
              %{
                "character_id" => 22_222,
                # Cyclone
                "ship_type_id" => 17_918,
                "ship_name" => "Cyclone",
                "damage_done" => 2000,
                "final_blow" => true
              }
            ]
          }
        }),
        create_test_killmail(%{
          killmail_id: 2,
          killmail_time: ~U[2024-01-01 10:05:00Z],
          victim_character_id: 33_333,
          raw_data: %{
            "victim" => %{
              "character_id" => 33_333,
              # Scythe
              "ship_type_id" => 11_129,
              "ship_name" => "Scythe"
            },
            "attackers" => [
              %{
                "character_id" => 67_890,
                "ship_type_id" => 587,
                "ship_name" => "Rifter",
                "damage_done" => 1000,
                "final_blow" => true
              }
            ]
          }
        })
      ]
    }
  end

  defp create_single_kill_battle do
    %{
      battle_id: "battle_single_20240101100000",
      metadata: %{
        primary_system: 30_002_765,
        system_id: 30_002_765,
        start_time: ~U[2024-01-01 10:00:00Z],
        end_time: ~U[2024-01-01 10:00:00Z],
        duration_minutes: 0,
        participant_count: 2,
        unique_participants: 2
      },
      killmails: [
        create_test_killmail(%{
          killmail_id: 1,
          killmail_time: ~U[2024-01-01 10:00:00Z],
          victim_character_id: 12_345
        })
      ]
    }
  end

  defp create_multi_corp_battle do
    %{
      battle_id: "battle_multi_20240101100000",
      metadata: %{
        primary_system: 30_002_765,
        system_id: 30_002_765,
        start_time: ~U[2024-01-01 10:00:00Z],
        end_time: ~U[2024-01-01 10:10:00Z],
        duration_minutes: 10,
        participant_count: 6,
        unique_participants: 6
      },
      killmails: [
        create_test_killmail(%{
          killmail_id: 1,
          killmail_time: ~U[2024-01-01 10:00:00Z],
          victim_character_id: 12_345,
          victim_corporation_id: 98_765,
          raw_data: %{
            "victim" => %{
              "character_id" => 12_345,
              "corporation_id" => 98_765,
              "corporation_name" => "Victim Corp A"
            },
            "attackers" => [
              %{
                "character_id" => 67_890,
                "corporation_id" => 54_321,
                "corporation_name" => "Attacker Corp B",
                "damage_done" => 1000,
                "final_blow" => true
              },
              %{
                "character_id" => 11_111,
                "corporation_id" => 54_321,
                "corporation_name" => "Attacker Corp B",
                "damage_done" => 500,
                "final_blow" => false
              }
            ]
          }
        }),
        create_test_killmail(%{
          killmail_id: 2,
          killmail_time: ~U[2024-01-01 10:05:00Z],
          victim_character_id: 22_222,
          victim_corporation_id: 54_321,
          raw_data: %{
            "victim" => %{
              "character_id" => 22_222,
              "corporation_id" => 54_321,
              "corporation_name" => "Attacker Corp B"
            },
            "attackers" => [
              %{
                "character_id" => 33_333,
                "corporation_id" => 98_765,
                "corporation_name" => "Victim Corp A",
                "damage_done" => 1200,
                "final_blow" => true
              }
            ]
          }
        })
      ]
    }
  end

  defp create_connected_battle(battle_num, start_time, participant_ids) do
    %{
      battle_id: "battle_#{battle_num}_20240101100000",
      metadata: %{
        primary_system: 30_002_765,
        system_id: 30_002_765,
        start_time: start_time,
        end_time: NaiveDateTime.add(start_time, 300, :second),
        duration_minutes: 5,
        participant_count: length(participant_ids),
        unique_participants: length(participant_ids)
      },
      killmails: [
        create_test_killmail(%{
          killmail_id: battle_num,
          killmail_time: start_time,
          victim_character_id: List.first(participant_ids),
          raw_data: %{
            "victim" => %{
              "character_id" => List.first(participant_ids)
            },
            "attackers" =>
              participant_ids
              |> Enum.drop(1)
              |> Enum.map(fn pid ->
                %{
                  "character_id" => pid,
                  "damage_done" => 500,
                  "final_blow" => pid == List.last(participant_ids)
                }
              end)
          }
        })
      ]
    }
  end

  defp create_escalating_battle(battle_num, participant_count) do
    participant_ids = 1..participant_count |> Enum.map(&(&1 * 1000)) |> Enum.to_list()

    %{
      battle_id: "battle_#{battle_num}_20240101100000",
      metadata: %{
        primary_system: 30_002_765,
        system_id: 30_002_765,
        start_time: ~U[2024-01-01 10:00:00Z],
        end_time: ~U[2024-01-01 10:05:00Z],
        duration_minutes: 5,
        participant_count: participant_count,
        unique_participants: participant_count
      },
      killmails: [
        create_test_killmail(%{
          killmail_id: battle_num,
          killmail_time: ~U[2024-01-01 10:00:00Z],
          victim_character_id: List.first(participant_ids),
          raw_data: %{
            "victim" => %{
              "character_id" => List.first(participant_ids)
            },
            "attackers" =>
              participant_ids
              |> Enum.drop(1)
              |> Enum.map(fn pid ->
                %{
                  "character_id" => pid,
                  "damage_done" => 100,
                  "final_blow" => pid == List.last(participant_ids)
                }
              end)
          }
        })
      ]
    }
  end

  defp create_flow_battle(battle_num, participant_ids) do
    %{
      battle_id: "battle_#{battle_num}_20240101100000",
      metadata: %{
        primary_system: 30_002_765,
        system_id: 30_002_765,
        start_time: ~U[2024-01-01 10:00:00Z],
        end_time: ~U[2024-01-01 10:05:00Z],
        duration_minutes: 5,
        participant_count: length(participant_ids),
        unique_participants: length(participant_ids)
      },
      killmails: [
        create_test_killmail(%{
          killmail_id: battle_num,
          killmail_time: ~U[2024-01-01 10:00:00Z],
          victim_character_id: List.first(participant_ids),
          raw_data: %{
            "victim" => %{
              "character_id" => List.first(participant_ids)
            },
            "attackers" =>
              participant_ids
              |> Enum.drop(1)
              |> Enum.map(fn pid ->
                %{
                  "character_id" => pid,
                  "damage_done" => 200,
                  "final_blow" => pid == List.last(participant_ids)
                }
              end)
          }
        })
      ]
    }
  end

  defp create_test_killmail(attrs) do
    default_attrs = %{
      killmail_id: 1,
      killmail_time: ~U[2024-01-01 10:00:00Z],
      solar_system_id: 30_002_765,
      victim_character_id: 12_345,
      victim_corporation_id: 98_765,
      victim_alliance_id: nil,
      victim_ship_type_id: 670,
      raw_data: %{
        "victim" => %{
          "character_id" => 12_345,
          "character_name" => "Test Victim",
          "corporation_id" => 98_765,
          "corporation_name" => "Test Corp",
          "ship_type_id" => 670,
          "ship_name" => "Capsule"
        },
        "attackers" => [
          %{
            "character_id" => 67_890,
            "character_name" => "Test Attacker",
            "corporation_id" => 54_321,
            "corporation_name" => "Test Attacker Corp",
            "ship_type_id" => 587,
            "ship_name" => "Rifter",
            "damage_done" => 1000,
            "final_blow" => true
          }
        ]
      }
    }

    Map.merge(default_attrs, attrs)
  end
end
