defmodule EveDmv.Contexts.CharacterIntelligence.Domain.Analyzers.GangSynergyAnalyzerTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.CharacterIntelligence.Domain.Analyzers.GangSynergyAnalyzer
  alias EveDmv.Eve.Character
  alias EveDmv.Killmails.KillmailRaw

  describe "analyze_synergy/1" do
    setup do
      # Create test characters
      character_ids =
        for i <- 1..3 do
          {:ok, char} =
            Character.create(%{
              character_id: 96_000_000 + i,
              character_name: "Gang Member #{i}",
              corporation_id: 98_000_000 + i
            })

          char.character_id
        end

      [char1, char2, char3] = character_ids

      # Create shared killmails (char1 and char2 working together)
      for i <- 1..5 do
        killmail_id = 200_000_000 + i
        victim_id = 97_000_000 + i

        {:ok, _} =
          KillmailRaw.create(%{
            killmail_id: killmail_id,
            killmail_time: DateTime.add(~U[2024-01-01 00:00:00Z], i * 3600, :second),
            solar_system_id: 30_000_142,
            victim_character_id: victim_id,
            # Rifter
            victim_ship_type_id: 587,
            victim_corporation_id: 98_999_000 + i,
            final_blow_character_id: char1,
            # Tengu
            final_blow_ship_type_id: 29_984,
            final_blow_corporation_id: 98_000_001,
            attackers_count: 2,
            total_value: 50_000_000.0
          })

        # Add attacker records (simplified - in real scenario would be separate table)
        {:ok, _} =
          KillmailRaw.create(%{
            killmail_id: killmail_id + 1000,
            killmail_time: DateTime.add(~U[2024-01-01 00:00:00Z], i * 3600, :second),
            solar_system_id: 30_000_142,
            victim_character_id: victim_id,
            victim_ship_type_id: 587,
            victim_corporation_id: 98_999_000 + i,
            final_blow_character_id: char2,
            # Guardian (logi)
            final_blow_ship_type_id: 11_987,
            final_blow_corporation_id: 98_000_002,
            attackers_count: 2,
            total_value: 50_000_000.0
          })
      end

      # Create solo kills for char3
      for i <- 1..3 do
        {:ok, _} =
          KillmailRaw.create(%{
            killmail_id: 201_000_000 + i,
            killmail_time: DateTime.add(~U[2024-01-02 00:00:00Z], i * 3600, :second),
            solar_system_id: 30_000_143,
            victim_character_id: 97_100_000 + i,
            victim_ship_type_id: 587,
            victim_corporation_id: 98_999_100 + i,
            final_blow_character_id: char3,
            # Harbinger
            final_blow_ship_type_id: 24_696,
            final_blow_corporation_id: 98_000_003,
            attackers_count: 1,
            total_value: 25_000_000.0
          })
      end

      %{character_ids: character_ids, char1: char1, char2: char2, char3: char3}
    end

    test "analyzes synergy between characters with shared kills", %{char1: char1, char2: char2} do
      assert {:ok, synergy} = GangSynergyAnalyzer.analyze_synergy([char1, char2])

      assert synergy.coordination_score >= 0.0 and synergy.coordination_score <= 1.0
      assert synergy.shared_victories >= 0
      assert is_float(synergy.synergy_rating)
      assert is_list(synergy.role_compatibility)
      assert is_list(synergy.temporal_patterns)
      assert is_list(synergy.geographic_patterns)
      assert is_map(synergy.effectiveness_metrics)

      # Should detect shared victories
      assert synergy.shared_victories > 0
      # Should have high coordination since they work together
      assert synergy.coordination_score > 0.5
    end

    test "analyzes synergy for characters without shared kills", %{char1: char1, char3: char3} do
      assert {:ok, synergy} = GangSynergyAnalyzer.analyze_synergy([char1, char3])

      # Should have low or zero coordination
      assert synergy.coordination_score < 0.3
      assert synergy.shared_victories == 0 or synergy.shared_victories < 2
    end

    test "handles single character gracefully" do
      single_char = 96_000_001
      assert {:ok, synergy} = GangSynergyAnalyzer.analyze_synergy([single_char])

      assert synergy.coordination_score == 0.0
      assert synergy.shared_victories == 0
      assert synergy.synergy_rating == 0.0
    end

    test "analyzes synergy for larger group", %{character_ids: character_ids} do
      assert {:ok, synergy} = GangSynergyAnalyzer.analyze_synergy(character_ids)

      assert length(character_ids) == 3
      assert is_float(synergy.coordination_score)
      assert is_integer(synergy.shared_victories)

      # Check for subgroup analysis
      if Map.has_key?(synergy, :subgroup_dynamics) do
        assert is_list(synergy.subgroup_dynamics)
      end
    end

    test "returns error for empty character list" do
      assert {:error, :no_characters} = GangSynergyAnalyzer.analyze_synergy([])
    end

    test "performance: handles 10 characters efficiently" do
      # Create 10 characters
      large_group =
        for i <- 1..10 do
          {:ok, char} =
            Character.create(%{
              character_id: 96_100_000 + i,
              character_name: "Large Group #{i}",
              corporation_id: 98_100_000 + i
            })

          char.character_id
        end

      # Measure execution time
      {time_micros, {:ok, synergy}} =
        :timer.tc(fn ->
          GangSynergyAnalyzer.analyze_synergy(large_group)
        end)

      time_ms = time_micros / 1000

      # Should complete within 5 seconds (5000ms)
      assert time_ms < 5000, "Gang synergy took #{time_ms}ms, expected < 5000ms"
      assert is_map(synergy)
    end
  end

  describe "role compatibility analysis" do
    setup do
      # Create characters with specific ship preferences
      dps_char = 96_200_001
      logi_char = 96_200_002
      ewar_char = 96_200_003

      {:ok, _} =
        Character.create(%{
          character_id: dps_char,
          character_name: "DPS Specialist",
          corporation_id: 98_200_001
        })

      {:ok, _} =
        Character.create(%{
          character_id: logi_char,
          character_name: "Logi Pilot",
          corporation_id: 98_200_002
        })

      {:ok, _} =
        Character.create(%{
          character_id: ewar_char,
          character_name: "EWAR Specialist",
          corporation_id: 98_200_003
        })

      # Create kills with role-specific ships
      # DPS kills
      for i <- 1..5 do
        {:ok, _} =
          KillmailRaw.create(%{
            killmail_id: 202_000_000 + i,
            killmail_time: ~U[2024-01-01 00:00:00Z],
            solar_system_id: 30_000_142,
            victim_character_id: 97_200_000 + i,
            victim_ship_type_id: 587,
            victim_corporation_id: 98_999_200 + i,
            final_blow_character_id: dps_char,
            # Harbinger (DPS)
            final_blow_ship_type_id: 24_696,
            final_blow_corporation_id: 98_200_001,
            attackers_count: 3,
            total_value: 100_000_000.0
          })
      end

      # Logi support
      for i <- 1..5 do
        {:ok, _} =
          KillmailRaw.create(%{
            killmail_id: 202_100_000 + i,
            killmail_time: ~U[2024-01-01 00:00:00Z],
            solar_system_id: 30_000_142,
            victim_character_id: 97_200_000 + i,
            victim_ship_type_id: 587,
            victim_corporation_id: 98_999_200 + i,
            final_blow_character_id: logi_char,
            # Guardian (Logistics)
            final_blow_ship_type_id: 11_987,
            final_blow_corporation_id: 98_200_002,
            attackers_count: 3,
            total_value: 100_000_000.0
          })
      end

      # EWAR support
      for i <- 1..5 do
        {:ok, _} =
          KillmailRaw.create(%{
            killmail_id: 202_200_000 + i,
            killmail_time: ~U[2024-01-01 00:00:00Z],
            solar_system_id: 30_000_142,
            victim_character_id: 97_200_000 + i,
            victim_ship_type_id: 587,
            victim_corporation_id: 98_999_200 + i,
            final_blow_character_id: ewar_char,
            # Rook (EWAR)
            final_blow_ship_type_id: 11_959,
            final_blow_corporation_id: 98_200_003,
            attackers_count: 3,
            total_value: 100_000_000.0
          })
      end

      %{dps_char: dps_char, logi_char: logi_char, ewar_char: ewar_char}
    end

    test "identifies complementary roles", %{dps_char: dps, logi_char: logi, ewar_char: ewar} do
      assert {:ok, synergy} = GangSynergyAnalyzer.analyze_synergy([dps, logi, ewar])

      assert is_list(synergy.role_compatibility)

      # Should identify role diversity as positive
      if length(synergy.role_compatibility) > 0 do
        role_compat = hd(synergy.role_compatibility)

        assert Map.has_key?(role_compat, :compatibility_score) or
                 Map.has_key?(role_compat, :roles) or
                 is_binary(role_compat)
      end
    end
  end

  describe "temporal pattern analysis" do
    setup do
      # Create characters active at different times
      morning_char = 96_300_001
      evening_char = 96_300_002

      {:ok, _} =
        Character.create(%{
          character_id: morning_char,
          character_name: "Morning Pilot",
          corporation_id: 98_300_001
        })

      {:ok, _} =
        Character.create(%{
          character_id: evening_char,
          character_name: "Evening Pilot",
          corporation_id: 98_300_002
        })

      # Morning kills (06:00 - 12:00)
      for i <- 1..5 do
        {:ok, _} =
          KillmailRaw.create(%{
            killmail_id: 203_000_000 + i,
            killmail_time: DateTime.add(~U[2024-01-01 08:00:00Z], i * 86_400, :second),
            solar_system_id: 30_000_142,
            victim_character_id: 97_300_000 + i,
            victim_ship_type_id: 587,
            victim_corporation_id: 98_999_300 + i,
            final_blow_character_id: morning_char,
            final_blow_ship_type_id: 29_984,
            final_blow_corporation_id: 98_300_001,
            attackers_count: 1,
            total_value: 50_000_000.0
          })
      end

      # Evening kills (18:00 - 00:00)
      for i <- 1..5 do
        {:ok, _} =
          KillmailRaw.create(%{
            killmail_id: 203_100_000 + i,
            killmail_time: DateTime.add(~U[2024-01-01 20:00:00Z], i * 86_400, :second),
            solar_system_id: 30_000_142,
            victim_character_id: 97_300_100 + i,
            victim_ship_type_id: 587,
            victim_corporation_id: 98_999_400 + i,
            final_blow_character_id: evening_char,
            final_blow_ship_type_id: 24_696,
            final_blow_corporation_id: 98_300_002,
            attackers_count: 1,
            total_value: 50_000_000.0
          })
      end

      %{morning_char: morning_char, evening_char: evening_char}
    end

    test "identifies temporal patterns", %{morning_char: morning, evening_char: evening} do
      assert {:ok, synergy} = GangSynergyAnalyzer.analyze_synergy([morning, evening])

      assert is_list(synergy.temporal_patterns)

      # Should identify different activity times
      if length(synergy.temporal_patterns) > 0 do
        pattern = hd(synergy.temporal_patterns)
        assert is_map(pattern) or is_binary(pattern)
      end

      # Low temporal overlap should result in lower coordination
      assert synergy.coordination_score < 0.5
    end
  end
end
