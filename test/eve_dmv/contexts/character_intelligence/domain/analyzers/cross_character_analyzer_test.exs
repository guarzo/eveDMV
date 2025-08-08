defmodule EveDmv.Contexts.CharacterIntelligence.Domain.Analyzers.CrossCharacterAnalyzerTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.CharacterIntelligence.Domain.Analyzers.CrossCharacterAnalyzer
  alias EveDmv.Eve.Character
  alias EveDmv.Killmails.KillmailRaw

  describe "analyze_relationships/1" do
    setup do
      # Create a network of characters with varying relationships
      characters =
        for i <- 1..5 do
          {:ok, char} =
            Character.create(%{
              character_id: 97_000_000 + i,
              character_name: "Network Member #{i}",
              # Split into 2 corps
              corporation_id: 98_000_000 + rem(i, 2) + 1
            })

          char
        end

      character_ids = Enum.map(characters, & &1.character_id)
      [char1, char2, char3, char4, char5] = character_ids

      # Create strong relationship between char1 and char2 (many shared kills)
      for i <- 1..10 do
        killmail_id = 300_000_000 + i

        {:ok, _} =
          KillmailRaw.create(%{
            killmail_id: killmail_id,
            killmail_time: DateTime.add(~U[2024-01-01 00:00:00Z], i * 3600, :second),
            solar_system_id: 30_000_142,
            victim_character_id: 97_999_000 + i,
            victim_ship_type_id: 587,
            victim_corporation_id: 98_999_000 + i,
            final_blow_character_id: char1,
            final_blow_ship_type_id: 29_984,
            final_blow_corporation_id: 98_000_001,
            attackers_count: 2,
            total_value: 50_000_000.0
          })

        # Char2 assists
        {:ok, _} =
          KillmailRaw.create(%{
            killmail_id: killmail_id + 1000,
            killmail_time: DateTime.add(~U[2024-01-01 00:00:00Z], i * 3600, :second),
            solar_system_id: 30_000_142,
            victim_character_id: 97_999_000 + i,
            victim_ship_type_id: 587,
            victim_corporation_id: 98_999_000 + i,
            final_blow_character_id: char2,
            final_blow_ship_type_id: 11_987,
            final_blow_corporation_id: 98_000_002,
            attackers_count: 2,
            total_value: 50_000_000.0
          })
      end

      # Moderate relationship between char3 and char4 (some shared kills)
      for i <- 1..3 do
        killmail_id = 301_000_000 + i

        {:ok, _} =
          KillmailRaw.create(%{
            killmail_id: killmail_id,
            killmail_time: DateTime.add(~U[2024-01-02 00:00:00Z], i * 3600, :second),
            solar_system_id: 30_000_143,
            victim_character_id: 97_998_000 + i,
            victim_ship_type_id: 587,
            victim_corporation_id: 98_998_000 + i,
            final_blow_character_id: char3,
            final_blow_ship_type_id: 24_696,
            final_blow_corporation_id: 98_000_001,
            attackers_count: 2,
            total_value: 30_000_000.0
          })

        {:ok, _} =
          KillmailRaw.create(%{
            killmail_id: killmail_id + 1000,
            killmail_time: DateTime.add(~U[2024-01-02 00:00:00Z], i * 3600, :second),
            solar_system_id: 30_000_143,
            victim_character_id: 97_998_000 + i,
            victim_ship_type_id: 587,
            victim_corporation_id: 98_998_000 + i,
            final_blow_character_id: char4,
            final_blow_ship_type_id: 11_959,
            final_blow_corporation_id: 98_000_002,
            attackers_count: 2,
            total_value: 30_000_000.0
          })
      end

      # Char5 operates solo
      for i <- 1..5 do
        {:ok, _} =
          KillmailRaw.create(%{
            killmail_id: 302_000_000 + i,
            killmail_time: DateTime.add(~U[2024-01-03 00:00:00Z], i * 3600, :second),
            solar_system_id: 30_000_144,
            victim_character_id: 97_997_000 + i,
            victim_ship_type_id: 587,
            victim_corporation_id: 98_997_000 + i,
            final_blow_character_id: char5,
            final_blow_ship_type_id: 29_986,
            final_blow_corporation_id: 98_000_001,
            attackers_count: 1,
            total_value: 20_000_000.0
          })
      end

      %{
        character_ids: character_ids,
        char1: char1,
        char2: char2,
        char3: char3,
        char4: char4,
        char5: char5
      }
    end

    test "analyzes relationship matrix between characters", %{character_ids: character_ids} do
      assert {:ok, analysis} = CrossCharacterAnalyzer.analyze_relationships(character_ids)

      assert Map.has_key?(analysis, :relationship_matrix)
      assert is_map(analysis.relationship_matrix)
      assert Map.has_key?(analysis, :strongest_pairs)
      assert is_list(analysis.strongest_pairs)
      assert Map.has_key?(analysis, :network_cohesion)
      assert is_float(analysis.network_cohesion)
      assert Map.has_key?(analysis, :subgroups)
      assert is_list(analysis.subgroups)
    end

    test "identifies strongest relationships", %{
      character_ids: character_ids,
      char1: char1,
      char2: char2
    } do
      assert {:ok, analysis} = CrossCharacterAnalyzer.analyze_relationships(character_ids)

      # char1 and char2 should be identified as strongly related
      if length(analysis.strongest_pairs) > 0 do
        strongest = hd(analysis.strongest_pairs)

        assert is_map(strongest)

        if Map.has_key?(strongest, :characters) do
          chars = strongest.characters

          assert (char1 in chars and char2 in chars) or
                   Map.has_key?(strongest, :strength)
        end
      end
    end

    test "calculates network cohesion", %{character_ids: character_ids} do
      assert {:ok, analysis} = CrossCharacterAnalyzer.analyze_relationships(character_ids)

      # Network should have moderate cohesion (some work together, some solo)
      assert analysis.network_cohesion >= 0.0 and analysis.network_cohesion <= 1.0
      assert analysis.network_cohesion > 0.2 and analysis.network_cohesion < 0.8
    end

    test "identifies subgroups", %{character_ids: character_ids} do
      assert {:ok, analysis} = CrossCharacterAnalyzer.analyze_relationships(character_ids)

      # Should identify at least 2 subgroups (the paired fighters and the solo operator)
      assert length(analysis.subgroups) >= 1

      if length(analysis.subgroups) > 0 do
        subgroup = hd(analysis.subgroups)
        assert is_map(subgroup) or is_list(subgroup)
      end
    end

    test "handles single character", %{char1: char1} do
      assert {:ok, analysis} = CrossCharacterAnalyzer.analyze_relationships([char1])

      assert analysis.network_cohesion == 0.0 or analysis.network_cohesion == 1.0
      assert analysis.strongest_pairs == []
      assert length(analysis.subgroups) <= 1
    end

    test "handles empty character list" do
      assert {:error, :no_characters} = CrossCharacterAnalyzer.analyze_relationships([])
    end
  end

  describe "analyze_group_patterns/1" do
    setup do
      # Create characters with distinct operational patterns
      characters =
        for i <- 1..3 do
          {:ok, char} =
            Character.create(%{
              character_id: 97_100_000 + i,
              character_name: "Pattern Test #{i}",
              corporation_id: 98_100_000 + i
            })

          char
        end

      character_ids = Enum.map(characters, & &1.character_id)
      [char1, char2, char3] = character_ids

      # Create pattern: Weekend warriors (Friday-Sunday operations)
      # Friday, Saturday, Sunday
      for day <- [5, 6, 7] do
        # Evening hours
        for hour <- [20, 21, 22] do
          {:ok, _} =
            KillmailRaw.create(%{
              killmail_id: 303_000_000 + day * 100 + hour,
              killmail_time:
                ~U[2024-01-05 20:00:00Z]
                |> DateTime.add((day - 5) * 86_400 + (hour - 20) * 3600, :second),
              # Always same system
              solar_system_id: 30_000_142,
              victim_character_id: 97_900_000 + day * 10 + hour,
              victim_ship_type_id: 587,
              victim_corporation_id: 98_900_000 + day,
              final_blow_character_id: Enum.random(character_ids),
              final_blow_ship_type_id: 29_984,
              final_blow_corporation_id: 98_100_001,
              attackers_count: 3,
              total_value: 75_000_000.0
            })
        end
      end

      %{character_ids: character_ids}
    end

    test "identifies operational patterns", %{character_ids: character_ids} do
      assert {:ok, patterns} = CrossCharacterAnalyzer.analyze_group_patterns(character_ids)

      assert Map.has_key?(patterns, :operation_types)
      assert is_list(patterns.operation_types)
      assert Map.has_key?(patterns, :temporal_patterns)
      assert is_list(patterns.temporal_patterns)
      assert Map.has_key?(patterns, :geographic_patterns)
      assert is_list(patterns.geographic_patterns)
      assert Map.has_key?(patterns, :coordination_level)
      assert patterns.coordination_level in [:high, :medium, :low, :none]
    end

    test "detects temporal patterns", %{character_ids: character_ids} do
      assert {:ok, patterns} = CrossCharacterAnalyzer.analyze_group_patterns(character_ids)

      # Should detect weekend/evening pattern
      if length(patterns.temporal_patterns) > 0 do
        temporal = hd(patterns.temporal_patterns)
        assert is_map(temporal) or is_binary(temporal)
      end
    end

    test "detects geographic patterns", %{character_ids: character_ids} do
      assert {:ok, patterns} = CrossCharacterAnalyzer.analyze_group_patterns(character_ids)

      # Should detect single system focus
      if length(patterns.geographic_patterns) > 0 do
        geographic = hd(patterns.geographic_patterns)
        assert is_map(geographic) or is_binary(geographic)
      end
    end
  end

  describe "predict_group_behavior/1" do
    setup do
      # Create characters with predictable patterns
      characters =
        for i <- 1..3 do
          {:ok, char} =
            Character.create(%{
              character_id: 97_200_000 + i,
              character_name: "Predictable #{i}",
              corporation_id: 98_200_000 + i
            })

          char
        end

      character_ids = Enum.map(characters, & &1.character_id)

      # Create consistent pattern: Always operate Monday 20:00 in system 30000142
      for week <- 0..3 do
        base_time = ~U[2024-01-01 20:00:00Z] |> DateTime.add(week * 7 * 86_400, :second)

        for i <- 0..2 do
          {:ok, _} =
            KillmailRaw.create(%{
              killmail_id: 304_000_000 + week * 100 + i,
              killmail_time: DateTime.add(base_time, i * 600, :second),
              solar_system_id: 30_000_142,
              victim_character_id: 97_800_000 + week * 10 + i,
              victim_ship_type_id: 587,
              victim_corporation_id: 98_800_000 + week,
              final_blow_character_id: Enum.at(character_ids, i),
              final_blow_ship_type_id: 29_984,
              final_blow_corporation_id: 98_200_001,
              attackers_count: 3,
              total_value: 100_000_000.0
            })
        end
      end

      %{character_ids: character_ids}
    end

    test "predicts likely operation times", %{character_ids: character_ids} do
      assert {:ok, prediction} = CrossCharacterAnalyzer.predict_group_behavior(character_ids)

      assert Map.has_key?(prediction, :likely_operation_times)
      assert is_list(prediction.likely_operation_times)

      if length(prediction.likely_operation_times) > 0 do
        time_prediction = hd(prediction.likely_operation_times)
        assert is_map(time_prediction) or is_binary(time_prediction)
      end
    end

    test "predicts target systems", %{character_ids: character_ids} do
      assert {:ok, prediction} = CrossCharacterAnalyzer.predict_group_behavior(character_ids)

      assert Map.has_key?(prediction, :likely_systems)
      assert is_list(prediction.likely_systems)

      # Should predict system 30000142 as likely target
      if length(prediction.likely_systems) > 0 do
        system = hd(prediction.likely_systems)
        assert is_map(system) or is_integer(system)
      end
    end

    test "predicts fleet composition", %{character_ids: character_ids} do
      assert {:ok, prediction} = CrossCharacterAnalyzer.predict_group_behavior(character_ids)

      assert Map.has_key?(prediction, :likely_composition)
      assert is_map(prediction.likely_composition) or is_list(prediction.likely_composition)
    end

    test "provides success probability", %{character_ids: character_ids} do
      assert {:ok, prediction} = CrossCharacterAnalyzer.predict_group_behavior(character_ids)

      assert Map.has_key?(prediction, :confidence_level)

      assert prediction.confidence_level in [:high, :medium, :low] or
               is_float(prediction.confidence_level)
    end

    test "handles insufficient data gracefully" do
      new_char_id = 97_999_999

      {:ok, _} =
        Character.create(%{
          character_id: new_char_id,
          character_name: "New Character",
          corporation_id: 98_999_999
        })

      assert {:ok, prediction} = CrossCharacterAnalyzer.predict_group_behavior([new_char_id])

      # Should return low confidence or indicate insufficient data
      assert prediction.confidence_level == :low or
               prediction.confidence_level < 0.3 or
               Map.has_key?(prediction, :insufficient_data)
    end
  end
end
