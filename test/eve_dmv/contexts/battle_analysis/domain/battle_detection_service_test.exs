defmodule EveDmv.Contexts.BattleAnalysis.Domain.BattleDetectionServiceTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.BattleAnalysis.Domain.BattleDetectionService

  describe "detect_battles/3" do
    test "clusters killmails by time and space into battles" do
      # Create sample killmails in database
      {:ok, _killmail1} =
        create_killmail(%{
          killmail_id: 1,
          killmail_time: ~U[2024-01-01 10:00:00Z],
          solar_system_id: 30_002_765,
          victim_character_id: 12_345,
          raw_data: %{
            "victim" => %{"character_id" => 12_345},
            "attackers" => [%{"character_id" => 67_890}]
          }
        })

      {:ok, _killmail2} =
        create_killmail(%{
          killmail_id: 2,
          killmail_time: ~U[2024-01-01 10:05:00Z],
          solar_system_id: 30_002_765,
          victim_character_id: 11_111,
          raw_data: %{
            "victim" => %{"character_id" => 11_111},
            "attackers" => [%{"character_id" => 67_890}]
          }
        })

      # Different system, should be separate battle
      {:ok, _killmail3} =
        create_killmail(%{
          killmail_id: 3,
          killmail_time: ~U[2024-01-01 10:10:00Z],
          solar_system_id: 30_002_766,
          victim_character_id: 22_222,
          raw_data: %{
            "victim" => %{"character_id" => 22_222},
            "attackers" => [%{"character_id" => 33_333}]
          }
        })

      start_time = ~U[2024-01-01 09:00:00Z]
      end_time = ~U[2024-01-01 11:00:00Z]

      assert {:ok, battles} = BattleDetectionService.detect_battles(start_time, end_time)

      # Should detect 2 battles (one for each system)
      assert length(battles) == 2

      # First battle should contain killmail1 and killmail2
      first_battle = Enum.find(battles, &(&1.metadata.primary_system == 30_002_765))
      assert first_battle
      assert length(first_battle.killmails) == 2
      killmail_ids = Enum.map(first_battle.killmails, & &1.killmail_id)
      assert 1 in killmail_ids
      assert 2 in killmail_ids

      # Second battle should contain killmail3
      second_battle = Enum.find(battles, &(&1.metadata.primary_system == 30_002_766))
      assert second_battle
      assert length(second_battle.killmails) == 1
      assert hd(second_battle.killmails).killmail_id == 3
    end

    test "filters battles by minimum participant count" do
      # Create killmail with only 1 participant (victim only)
      {:ok, _killmail} =
        create_killmail(%{
          killmail_id: 1,
          killmail_time: ~U[2024-01-01 10:00:00Z],
          solar_system_id: 30_002_765,
          victim_character_id: 12_345,
          raw_data: %{
            "victim" => %{"character_id" => 12_345}
            # No attackers - should be filtered out
          }
        })

      start_time = ~U[2024-01-01 09:00:00Z]
      end_time = ~U[2024-01-01 11:00:00Z]

      assert {:ok, battles} = BattleDetectionService.detect_battles(start_time, end_time)

      # Should have no battles due to minimum participant requirement
      assert battles == []
    end

    test "respects max_time_gap option" do
      # Create killmails with large time gap
      {:ok, _killmail1} =
        create_killmail(%{
          killmail_id: 1,
          killmail_time: ~U[2024-01-01 10:00:00Z],
          solar_system_id: 30_002_765,
          victim_character_id: 12_345,
          raw_data: %{
            "victim" => %{"character_id" => 12_345},
            "attackers" => [%{"character_id" => 67_890}]
          }
        })

      {:ok, _killmail2} =
        create_killmail(%{
          killmail_id: 2,
          # 40 minutes later
          killmail_time: ~U[2024-01-01 10:40:00Z],
          solar_system_id: 30_002_765,
          victim_character_id: 11_111,
          raw_data: %{
            "victim" => %{"character_id" => 11_111},
            "attackers" => [%{"character_id" => 99_999}]
          }
        })

      start_time = ~U[2024-01-01 09:00:00Z]
      end_time = ~U[2024-01-01 11:00:00Z]

      # With default max_time_gap (30 minutes), should be separate battles
      assert {:ok, battles} = BattleDetectionService.detect_battles(start_time, end_time)
      assert length(battles) == 2

      # With larger max_time_gap, should be same battle
      assert {:ok, battles} =
               BattleDetectionService.detect_battles(start_time, end_time, max_time_gap: 60)

      assert length(battles) == 1
      assert length(hd(battles).killmails) == 2
    end

    test "handles participant overlap for longer time gaps" do
      # Create killmails with same participants but longer time gap
      {:ok, _killmail1} =
        create_killmail(%{
          killmail_id: 1,
          killmail_time: ~U[2024-01-01 10:00:00Z],
          solar_system_id: 30_002_765,
          victim_character_id: 12_345,
          raw_data: %{
            "victim" => %{"character_id" => 12_345},
            "attackers" => [%{"character_id" => 67_890}, %{"character_id" => 11_111}]
          }
        })

      {:ok, _killmail2} =
        create_killmail(%{
          killmail_id: 2,
          # 45 minutes later
          killmail_time: ~U[2024-01-01 10:45:00Z],
          solar_system_id: 30_002_765,
          victim_character_id: 22_222,
          raw_data: %{
            "victim" => %{"character_id" => 22_222},
            # Same attacker
            "attackers" => [%{"character_id" => 67_890}]
          }
        })

      start_time = ~U[2024-01-01 09:00:00Z]
      end_time = ~U[2024-01-01 11:00:00Z]

      assert {:ok, battles} = BattleDetectionService.detect_battles(start_time, end_time)

      # Should cluster into same battle due to participant overlap
      assert length(battles) == 1
      battle = hd(battles)
      assert length(battle.killmails) == 2

      # Verify battle metadata
      assert battle.metadata.unique_participants >= 3
      assert battle.metadata.primary_system == 30_002_765
    end
  end

  describe "detect_battles_in_system/4" do
    test "only detects battles in specified system" do
      # Create killmails in different systems
      {:ok, _killmail1} =
        create_killmail(%{
          killmail_id: 1,
          killmail_time: ~U[2024-01-01 10:00:00Z],
          solar_system_id: 30_002_765,
          victim_character_id: 12_345,
          raw_data: %{
            "victim" => %{"character_id" => 12_345},
            "attackers" => [%{"character_id" => 67_890}]
          }
        })

      {:ok, _killmail2} =
        create_killmail(%{
          killmail_id: 2,
          killmail_time: ~U[2024-01-01 10:05:00Z],
          # Different system
          solar_system_id: 30_002_766,
          victim_character_id: 11_111,
          raw_data: %{
            "victim" => %{"character_id" => 11_111},
            "attackers" => [%{"character_id" => 67_890}]
          }
        })

      start_time = ~U[2024-01-01 09:00:00Z]
      end_time = ~U[2024-01-01 11:00:00Z]

      assert {:ok, battles} =
               BattleDetectionService.detect_battles_in_system(30_002_765, start_time, end_time)

      # Should only find battles in the specified system
      assert length(battles) == 1
      battle = hd(battles)
      assert battle.metadata.primary_system == 30_002_765
      assert length(battle.killmails) == 1
      assert hd(battle.killmails).killmail_id == 1
    end
  end

  describe "analyze_battle_from_killmail_ids/1" do
    test "analyzes battle from specific killmail IDs" do
      # Create killmails
      {:ok, _killmail1} =
        create_killmail(%{
          killmail_id: 1,
          killmail_time: ~U[2024-01-01 10:00:00Z],
          solar_system_id: 30_002_765,
          victim_character_id: 12_345,
          raw_data: %{
            "victim" => %{"character_id" => 12_345},
            "attackers" => [%{"character_id" => 67_890}]
          }
        })

      {:ok, _killmail2} =
        create_killmail(%{
          killmail_id: 2,
          killmail_time: ~U[2024-01-01 10:05:00Z],
          solar_system_id: 30_002_765,
          victim_character_id: 11_111,
          raw_data: %{
            "victim" => %{"character_id" => 11_111},
            "attackers" => [%{"character_id" => 67_890}]
          }
        })

      assert {:ok, battle} = BattleDetectionService.analyze_battle_from_killmail_ids([1, 2])

      assert battle.battle_id
      assert length(battle.killmails) == 2
      assert battle.metadata.unique_participants >= 2
      assert battle.metadata.primary_system == 30_002_765
    end

    test "handles single killmail" do
      {:ok, _killmail} =
        create_killmail(%{
          killmail_id: 1,
          killmail_time: ~U[2024-01-01 10:00:00Z],
          solar_system_id: 30_002_765,
          victim_character_id: 12_345,
          raw_data: %{
            "victim" => %{"character_id" => 12_345},
            "attackers" => [%{"character_id" => 67_890}]
          }
        })

      assert {:ok, battle} = BattleDetectionService.analyze_battle_from_killmail_ids([1])

      assert battle.battle_id
      assert length(battle.killmails) == 1
      assert hd(battle.killmails).killmail_id == 1
    end

    test "returns error for non-existent killmail IDs" do
      assert {:error, :no_killmails_found} =
               BattleDetectionService.analyze_battle_from_killmail_ids([999])
    end
  end

  # Helper function to create killmails
  defp create_killmail(attrs) do
    # Set required attributes with defaults
    attrs =
      Map.merge(
        %{
          killmail_hash: "hash_#{attrs.killmail_id}",
          source: "test",
          victim_ship_type_id: 587,
          attacker_count: length(get_in(attrs, [:raw_data, "attackers"]) || [])
        },
        attrs
      )

    Ash.create(EveDmv.Killmails.KillmailRaw, attrs, domain: EveDmv.Api)
  end
end
