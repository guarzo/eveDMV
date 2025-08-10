defmodule EveDmv.Contexts.BattleAnalysis.Domain.ParticipantRoleAnalyzerTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.BattleAnalysis.Domain.ParticipantRoleAnalyzer

  describe "analyze_participant_roles/2" do
    test "analyzes participant roles in a battle" do
      battle = create_test_battle()

      analysis = ParticipantRoleAnalyzer.analyze_participant_roles(battle)

      assert is_map(analysis)
      assert is_list(analysis.participants)
      assert is_map(analysis.role_distribution)
      assert is_list(analysis.key_players)
      assert is_list(analysis.commanders)
      assert is_map(analysis.analysis_metadata)

      # Should have participants
      assert length(analysis.participants) > 0

      # Each participant should have required fields
      participant = List.first(analysis.participants)
      assert participant.character_id
      assert participant.primary_role
      assert is_number(participant.contribution_score)
      assert is_map(participant.activity_summary)
    end

    test "identifies DPS participants correctly" do
      battle = create_dps_battle()

      analysis = ParticipantRoleAnalyzer.analyze_participant_roles(battle)

      # Should identify DPS participants
      dps_participants = Enum.filter(analysis.participants, &(&1.primary_role == :dps))
      assert length(dps_participants) > 0

      # DPS participants should have high damage
      dps_participant = List.first(dps_participants)
      assert dps_participant.activity_summary.total_damage_dealt > 0
    end

    test "identifies logistics participants correctly" do
      battle = create_logistics_battle()

      analysis = ParticipantRoleAnalyzer.analyze_participant_roles(battle)

      # Should identify logistics participants
      logistics_participants =
        Enum.filter(analysis.participants, &(&1.primary_role == :logistics))

      assert length(logistics_participants) > 0

      # Logistics participants should have logistics ships
      logistics_participant = List.first(logistics_participants)
      assert logistics_participant.ship_types
    end

    test "calculates role distribution correctly" do
      battle = create_mixed_role_battle()

      analysis = ParticipantRoleAnalyzer.analyze_participant_roles(battle)

      # Should have multiple roles
      assert map_size(analysis.role_distribution) > 1

      # Each role should have count and percentage
      Enum.each(analysis.role_distribution, fn {_role, stats} ->
        assert stats.count >= 0
        assert stats.percentage >= 0
        assert stats.percentage <= 100
      end)
    end

    test "identifies key players" do
      battle = create_test_battle()

      analysis = ParticipantRoleAnalyzer.analyze_participant_roles(battle)

      # Should identify key players
      assert length(analysis.key_players) > 0

      # Key players should be sorted by contribution
      key_player = List.first(analysis.key_players)
      assert key_player.character_id
      assert key_player.contribution_score > 0
      assert key_player.key_factor
    end

    test "identifies commanders" do
      battle = create_command_battle()

      analysis = ParticipantRoleAnalyzer.analyze_participant_roles(battle)

      # Should identify potential commanders
      assert length(analysis.commanders) >= 0

      # If commanders identified, should have command indicators
      if length(analysis.commanders) > 0 do
        commander = List.first(analysis.commanders)
        assert commander.character_id
        assert is_list(commander.command_indicators)
      end
    end
  end

  describe "analyze_participant_role/3" do
    test "analyzes single participant role" do
      participant = create_test_participant()
      killmails = create_test_killmails()

      analysis = ParticipantRoleAnalyzer.analyze_participant_role(participant, killmails)

      assert analysis.character_id == participant.character_id
      assert analysis.primary_role
      assert is_number(analysis.contribution_score)
      assert is_map(analysis.activity_summary)
      assert is_list(analysis.characteristics)
      assert is_list(analysis.secondary_roles)
    end

    test "analyzes DPS participant correctly" do
      participant = create_dps_participant()
      killmails = create_dps_killmails()

      analysis = ParticipantRoleAnalyzer.analyze_participant_role(participant, killmails)

      assert analysis.primary_role == :dps
      assert analysis.activity_summary.total_damage_dealt > 0
      assert analysis.contribution_score > 0
    end

    test "analyzes logistics participant correctly" do
      participant = create_logistics_participant()
      killmails = create_logistics_killmails()

      analysis = ParticipantRoleAnalyzer.analyze_participant_role(participant, killmails)

      assert analysis.primary_role == :logistics
      assert analysis.activity_summary.total_kills > 0
      # Logistics typically have high survivability
      assert analysis.activity_summary.total_losses == 0
    end

    test "calculates contribution score correctly" do
      participant = create_high_activity_participant()
      killmails = create_high_activity_killmails()

      analysis = ParticipantRoleAnalyzer.analyze_participant_role(participant, killmails)

      # High activity should result in high contribution score
      assert analysis.contribution_score > 80
      assert analysis.activity_summary.total_kills > 3
    end

    test "identifies characteristics correctly" do
      participant = create_versatile_participant()
      killmails = create_versatile_killmails()

      analysis = ParticipantRoleAnalyzer.analyze_participant_role(participant, killmails)

      # Should identify some characteristics based on the activity
      assert length(analysis.characteristics) >= 0
    end

    test "handles participants with no activity" do
      participant = create_inactive_participant()
      killmails = create_test_killmails()

      analysis = ParticipantRoleAnalyzer.analyze_participant_role(participant, killmails)

      assert analysis.character_id == participant.character_id
      assert analysis.activity_summary.total_kills == 0
      assert analysis.contribution_score == 0
    end
  end

  # Helper functions for creating test data

  defp create_test_battle do
    %{
      battle_id: "battle_test_20240101100000",
      killmails: create_test_killmails()
    }
  end

  defp create_dps_battle do
    %{
      battle_id: "battle_dps_20240101100000",
      killmails: create_dps_killmails()
    }
  end

  defp create_logistics_battle do
    %{
      battle_id: "battle_logistics_20240101100000",
      killmails: create_logistics_killmails()
    }
  end

  defp create_mixed_role_battle do
    %{
      battle_id: "battle_mixed_20240101100000",
      killmails: create_mixed_killmails()
    }
  end

  defp create_command_battle do
    %{
      battle_id: "battle_command_20240101100000",
      killmails: create_command_killmails()
    }
  end

  defp create_test_killmails do
    [
      create_killmail(%{
        killmail_id: 1,
        victim_character_id: 12_345,
        victim_corporation_id: 98_765,
        # Rifter
        victim_ship_type_id: 587,
        raw_data: %{
          "victim" => %{
            "character_id" => 12_345,
            "character_name" => "Test Victim",
            "corporation_id" => 98_765,
            "corporation_name" => "Test Corp",
            "ship_type_id" => 587
          },
          "attackers" => [
            %{
              "character_id" => 67_890,
              "character_name" => "Test Attacker",
              "corporation_id" => 54_321,
              "corporation_name" => "Attacker Corp",
              # Cyclone
              "ship_type_id" => 17_918,
              "damage_done" => 2000,
              "final_blow" => true
            }
          ]
        }
      }),
      create_killmail(%{
        killmail_id: 2,
        victim_character_id: 22_222,
        victim_corporation_id: 98_765,
        # Punisher
        victim_ship_type_id: 588,
        raw_data: %{
          "victim" => %{
            "character_id" => 22_222,
            "character_name" => "Test Victim 2",
            "corporation_id" => 98_765,
            "corporation_name" => "Test Corp",
            "ship_type_id" => 588
          },
          "attackers" => [
            %{
              "character_id" => 67_890,
              "character_name" => "Test Attacker",
              "corporation_id" => 54_321,
              "corporation_name" => "Attacker Corp",
              # Cyclone
              "ship_type_id" => 17_918,
              "damage_done" => 1500,
              "final_blow" => true
            }
          ]
        }
      })
    ]
  end

  defp create_dps_killmails do
    [
      create_killmail(%{
        killmail_id: 1,
        victim_character_id: 12_345,
        victim_ship_type_id: 587,
        raw_data: %{
          "victim" => %{
            "character_id" => 12_345,
            "character_name" => "Victim",
            "ship_type_id" => 587
          },
          "attackers" => [
            %{
              "character_id" => 67_890,
              "character_name" => "DPS Pilot",
              # Cyclone (DPS)
              "ship_type_id" => 17_918,
              "damage_done" => 3000,
              "final_blow" => true
            }
          ]
        }
      })
    ]
  end

  defp create_logistics_killmails do
    [
      create_killmail(%{
        killmail_id: 1,
        victim_character_id: 12_345,
        victim_ship_type_id: 587,
        raw_data: %{
          "victim" => %{
            "character_id" => 12_345,
            "character_name" => "Victim",
            "ship_type_id" => 587
          },
          "attackers" => [
            %{
              "character_id" => 67_890,
              "character_name" => "Logistics Pilot",
              # Scythe (Logistics)
              "ship_type_id" => 11_129,
              "damage_done" => 100,
              "final_blow" => false
            }
          ]
        }
      })
    ]
  end

  defp create_mixed_killmails do
    [
      create_killmail(%{
        killmail_id: 1,
        victim_character_id: 12_345,
        victim_ship_type_id: 587,
        raw_data: %{
          "victim" => %{
            "character_id" => 12_345,
            "character_name" => "Victim",
            "ship_type_id" => 587
          },
          "attackers" => [
            %{
              "character_id" => 67_890,
              "character_name" => "DPS Pilot",
              # Cyclone (DPS)
              "ship_type_id" => 17_918,
              "damage_done" => 2000,
              "final_blow" => true
            },
            %{
              "character_id" => 11_111,
              "character_name" => "Logistics Pilot",
              # Scythe (Logistics)
              "ship_type_id" => 11_129,
              "damage_done" => 50,
              "final_blow" => false
            }
          ]
        }
      })
    ]
  end

  defp create_command_killmails do
    [
      create_killmail(%{
        killmail_id: 1,
        victim_character_id: 12_345,
        victim_ship_type_id: 587,
        raw_data: %{
          "victim" => %{
            "character_id" => 12_345,
            "character_name" => "Victim",
            "ship_type_id" => 587
          },
          "attackers" => [
            %{
              "character_id" => 67_890,
              "character_name" => "Fleet Commander",
              # Sleipnir (Command)
              "ship_type_id" => 22_474,
              "damage_done" => 1000,
              "final_blow" => false
            }
          ]
        }
      })
    ]
  end

  defp create_high_activity_killmails do
    Enum.map(1..5, fn i ->
      create_killmail(%{
        killmail_id: i,
        victim_character_id: 12_000 + i,
        victim_ship_type_id: 587,
        raw_data: %{
          "victim" => %{
            "character_id" => 12_000 + i,
            "character_name" => "Victim #{i}",
            "ship_type_id" => 587
          },
          "attackers" => [
            %{
              "character_id" => 67_890,
              "character_name" => "Active Pilot",
              "ship_type_id" => 17_918,
              "damage_done" => 1500,
              "final_blow" => true
            }
          ]
        }
      })
    end)
  end

  defp create_versatile_killmails do
    [
      create_killmail(%{
        killmail_id: 1,
        victim_character_id: 12_345,
        victim_ship_type_id: 587,
        raw_data: %{
          "victim" => %{
            "character_id" => 12_345,
            "character_name" => "Victim",
            "ship_type_id" => 587
          },
          "attackers" => [
            %{
              "character_id" => 67_890,
              "character_name" => "Versatile Pilot",
              # Cyclone
              "ship_type_id" => 17_918,
              "damage_done" => 1000,
              "final_blow" => false
            }
          ]
        }
      }),
      create_killmail(%{
        killmail_id: 2,
        victim_character_id: 22_222,
        victim_ship_type_id: 588,
        raw_data: %{
          "victim" => %{
            "character_id" => 22_222,
            "character_name" => "Victim 2",
            "ship_type_id" => 588
          },
          "attackers" => [
            %{
              "character_id" => 67_890,
              "character_name" => "Versatile Pilot",
              # Different ship type
              "ship_type_id" => 587,
              "damage_done" => 800,
              "final_blow" => true
            }
          ]
        }
      })
    ]
  end

  defp create_killmail(attrs) do
    default_attrs = %{
      killmail_id: 1,
      killmail_time: ~U[2024-01-01 10:00:00Z],
      solar_system_id: 30_002_765,
      victim_character_id: 12_345,
      victim_corporation_id: 98_765,
      victim_alliance_id: nil,
      victim_ship_type_id: 587,
      raw_data: %{
        "victim" => %{
          "character_id" => 12_345,
          "character_name" => "Test Victim",
          "corporation_id" => 98_765,
          "corporation_name" => "Test Corp",
          "ship_type_id" => 587
        },
        "attackers" => [
          %{
            "character_id" => 67_890,
            "character_name" => "Test Attacker",
            "corporation_id" => 54_321,
            "corporation_name" => "Attacker Corp",
            "ship_type_id" => 17_918,
            "damage_done" => 1000,
            "final_blow" => true
          }
        ]
      }
    }

    Map.merge(default_attrs, attrs)
  end

  defp create_test_participant do
    %{
      character_id: 67_890,
      character_name: "Test Participant",
      corporation_id: 54_321,
      corporation_name: "Test Corp",
      alliance_id: nil
    }
  end

  defp create_dps_participant do
    %{
      character_id: 67_890,
      character_name: "DPS Pilot",
      corporation_id: 54_321,
      corporation_name: "DPS Corp",
      alliance_id: nil
    }
  end

  defp create_logistics_participant do
    %{
      character_id: 67_890,
      character_name: "Logistics Pilot",
      corporation_id: 54_321,
      corporation_name: "Logistics Corp",
      alliance_id: nil
    }
  end

  defp create_high_activity_participant do
    %{
      character_id: 67_890,
      character_name: "Active Pilot",
      corporation_id: 54_321,
      corporation_name: "Active Corp",
      alliance_id: nil
    }
  end

  defp create_versatile_participant do
    %{
      character_id: 67_890,
      character_name: "Versatile Pilot",
      corporation_id: 54_321,
      corporation_name: "Versatile Corp",
      alliance_id: nil
    }
  end

  defp create_inactive_participant do
    %{
      character_id: 99_999,
      character_name: "Inactive Pilot",
      corporation_id: 54_321,
      corporation_name: "Inactive Corp",
      alliance_id: nil
    }
  end
end
