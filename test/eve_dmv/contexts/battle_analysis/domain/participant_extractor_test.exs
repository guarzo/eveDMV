defmodule EveDmv.Contexts.BattleAnalysis.Domain.ParticipantExtractorTest do
  use ExUnit.Case, async: true

  alias EveDmv.Contexts.BattleAnalysis.Domain.ParticipantExtractor

  describe "extract_participants/1" do
    test "extracts participant IDs from killmail with victim and attackers" do
      killmail = %{
        victim_character_id: 12345,
        raw_data: %{
          "victim" => %{
            "character_id" => 12345
          },
          "attackers" => [
            %{"character_id" => 67890},
            %{"character_id" => 11111},
            %{"character_id" => nil}
          ]
        }
      }

      result = ParticipantExtractor.extract_participants(killmail)

      assert Enum.sort(result) == [11111, 12345, 67890]
    end

    test "handles string character IDs" do
      killmail = %{
        victim_character_id: 12345,
        raw_data: %{
          "attackers" => [
            %{"character_id" => "67890"},
            %{"character_id" => "11111"}
          ]
        }
      }

      result = ParticipantExtractor.extract_participants(killmail)

      assert Enum.sort(result) == [11111, 12345, 67890]
    end

    test "returns empty list for killmail with no attackers" do
      killmail = %{
        victim_character_id: 12345,
        raw_data: %{}
      }

      result = ParticipantExtractor.extract_participants(killmail)

      assert result == [12345]
    end
  end

  describe "extract_attacker_details/1" do
    test "extracts comprehensive attacker information" do
      killmail = %{
        raw_data: %{
          "attackers" => [
            %{
              "character_id" => 67890,
              "character_name" => "Test Character",
              "corporation_id" => 98765,
              "corporation_name" => "Test Corp",
              "corporation_ticker" => "TEST",
              "alliance_id" => 54321,
              "alliance_name" => "Test Alliance",
              "alliance_ticker" => "TESTA",
              "ship_type_id" => 588,
              "ship_name" => "Rifter",
              "weapon_type_id" => 2889,
              "weapon_name" => "Autocannon II",
              "damage_done" => 1500,
              "final_blow" => true,
              "security_status" => -2.5,
              "faction_id" => 500_001,
              "faction_name" => "Caldari State"
            }
          ]
        }
      }

      result = ParticipantExtractor.extract_attacker_details(killmail)

      assert length(result) == 1
      attacker = hd(result)

      assert attacker.character_id == 67890
      assert attacker.character_name == "Test Character"
      assert attacker.corporation_id == 98765
      assert attacker.corporation_name == "Test Corp"
      assert attacker.corporation_ticker == "TEST"
      assert attacker.alliance_id == 54321
      assert attacker.alliance_name == "Test Alliance"
      assert attacker.alliance_ticker == "TESTA"
      assert attacker.ship_type_id == 588
      assert attacker.ship_name == "Rifter"
      assert attacker.weapon_type_id == 2889
      assert attacker.weapon_name == "Autocannon II"
      assert attacker.damage_done == 1500
      assert attacker.final_blow == true
      assert attacker.security_status == -2.5
      assert attacker.faction_id == 500_001
      assert attacker.faction_name == "Caldari State"
    end

    test "handles missing optional fields" do
      killmail = %{
        raw_data: %{
          "attackers" => [
            %{
              "character_id" => 67890,
              "ship_type_id" => 588
            }
          ]
        }
      }

      result = ParticipantExtractor.extract_attacker_details(killmail)

      assert length(result) == 1
      attacker = hd(result)

      assert attacker.character_id == 67890
      assert attacker.ship_type_id == 588
      assert attacker.damage_done == 0
      assert attacker.final_blow == false
      assert is_nil(attacker.character_name)
      assert is_nil(attacker.security_status)
    end
  end

  describe "extract_victim_details/1" do
    test "extracts victim information from raw_data" do
      killmail = %{
        raw_data: %{
          "victim" => %{
            "character_id" => 12345,
            "character_name" => "Victim Name",
            "corporation_id" => 98765,
            "ship_type_id" => 588,
            "damage_taken" => 5000,
            "security_status" => 0.5
          }
        }
      }

      result = ParticipantExtractor.extract_victim_details(killmail)

      assert result.character_id == 12345
      assert result.character_name == "Victim Name"
      assert result.corporation_id == 98765
      assert result.ship_type_id == 588
      assert result.damage_taken == 5000
      assert result.final_blow == false
      assert result.security_status == 0.5
      assert is_nil(result.weapon_type_id)
    end

    test "falls back to killmail direct fields when no raw_data victim" do
      killmail = %{
        victim_character_id: 12345,
        victim_corporation_id: 98765,
        victim_alliance_id: 54321,
        victim_ship_type_id: 588,
        raw_data: %{}
      }

      result = ParticipantExtractor.extract_victim_details(killmail)

      assert result.character_id == 12345
      assert result.corporation_id == 98765
      assert result.alliance_id == 54321
      assert result.ship_type_id == 588
      assert result.final_blow == false
      assert is_nil(result.damage_taken)
    end
  end

  describe "find_final_blow_attacker/1" do
    test "finds the attacker with final_blow: true" do
      killmail = %{
        raw_data: %{
          "attackers" => [
            %{"character_id" => 111, "final_blow" => false},
            %{"character_id" => 222, "final_blow" => true},
            %{"character_id" => 333, "final_blow" => false}
          ]
        }
      }

      result = ParticipantExtractor.find_final_blow_attacker(killmail)

      assert result.character_id == 222
      assert result.final_blow == true
    end

    test "returns nil when no final blow attacker" do
      killmail = %{
        raw_data: %{
          "attackers" => [
            %{"character_id" => 111, "final_blow" => false},
            %{"character_id" => 222, "final_blow" => false}
          ]
        }
      }

      result = ParticipantExtractor.find_final_blow_attacker(killmail)

      assert is_nil(result)
    end
  end

  describe "calculate_total_damage/1" do
    test "sums damage from all attackers" do
      killmail = %{
        raw_data: %{
          "attackers" => [
            %{"character_id" => 111, "damage_done" => 1000},
            %{"character_id" => 222, "damage_done" => 2500},
            %{"character_id" => 333, "damage_done" => 1500}
          ]
        }
      }

      result = ParticipantExtractor.calculate_total_damage(killmail)

      assert result == 5000
    end

    test "handles missing damage_done fields" do
      killmail = %{
        raw_data: %{
          "attackers" => [
            %{"character_id" => 111, "damage_done" => 1000},
            %{"character_id" => 222},
            %{"character_id" => 333, "damage_done" => 1500}
          ]
        }
      }

      result = ParticipantExtractor.calculate_total_damage(killmail)

      assert result == 2500
    end
  end

  describe "extract_corporation_ids/1" do
    test "extracts unique corporation IDs from all participants" do
      killmail = %{
        victim_character_id: 12345,
        raw_data: %{
          "victim" => %{
            "character_id" => 12345,
            "corporation_id" => 98765
          },
          "attackers" => [
            %{"character_id" => 111, "corporation_id" => 98765},
            %{"character_id" => 222, "corporation_id" => 54321},
            %{"character_id" => 333, "corporation_id" => 98765}
          ]
        }
      }

      result = ParticipantExtractor.extract_corporation_ids(killmail)

      assert Enum.sort(result) == [54321, 98765]
    end
  end

  describe "extract_alliance_ids/1" do
    test "extracts unique alliance IDs from all participants" do
      killmail = %{
        raw_data: %{
          "victim" => %{
            "character_id" => 12345,
            "alliance_id" => 11111
          },
          "attackers" => [
            %{"character_id" => 111, "alliance_id" => 22222},
            %{"character_id" => 222, "alliance_id" => 11111},
            %{"character_id" => 333, "alliance_id" => 33333}
          ]
        }
      }

      result = ParticipantExtractor.extract_alliance_ids(killmail)

      assert Enum.sort(result) == [11111, 22222, 33333]
    end
  end

  describe "extract_ship_type_ids/1" do
    test "extracts unique ship type IDs from all participants" do
      killmail = %{
        raw_data: %{
          "victim" => %{
            "character_id" => 12345,
            "ship_type_id" => 588
          },
          "attackers" => [
            %{"character_id" => 111, "ship_type_id" => 589},
            %{"character_id" => 222, "ship_type_id" => 588},
            %{"character_id" => 333, "ship_type_id" => 590}
          ]
        }
      }

      result = ParticipantExtractor.extract_ship_type_ids(killmail)

      assert Enum.sort(result) == [588, 589, 590]
    end
  end

  describe "extract_weapon_type_ids/1" do
    test "extracts unique weapon type IDs from attackers" do
      killmail = %{
        raw_data: %{
          "attackers" => [
            %{"character_id" => 111, "weapon_type_id" => 2889},
            %{"character_id" => 222, "weapon_type_id" => 2890},
            %{"character_id" => 333, "weapon_type_id" => 2889}
          ]
        }
      }

      result = ParticipantExtractor.extract_weapon_type_ids(killmail)

      assert Enum.sort(result) == [2889, 2890]
    end
  end
end
