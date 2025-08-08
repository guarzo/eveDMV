defmodule EveDmv.Contexts.CharacterIntelligenceSimpleTest do
  use EveDmv.DataCase, async: true

  import EveDmv.Factories

  alias EveDmv.Api
  alias EveDmv.Contexts.CharacterIntelligence
  alias EveDmv.Killmails.KillmailRaw

  describe "analyze_character_threat/1" do
    setup do
      character_id = 95_123_456

      # Create test killmails with character as attacker
      killmail_attrs = killmail_raw_factory()

      {:ok, _killmail1} =
        Api.create(
          KillmailRaw,
          Map.merge(killmail_attrs, %{
            killmail_id: 101_000_001,
            killmail_time: ~U[2024-01-01 12:00:00Z],
            solar_system_id: 30_000_142,
            victim_character_id: 95_999_999,
            # Rifter
            victim_ship_type_id: 587,
            victim_corporation_id: 98_999_999,
            victim_alliance_id: nil,
            attacker_count: 1,
            total_value: Decimal.new("50000000.0"),
            raw_data: %{
              "attackers" => [
                %{
                  "character_id" => character_id,
                  # Tengu
                  "ship_type_id" => 29_984,
                  "final_blow" => true
                }
              ]
            }
          })
        )

      {:ok, _killmail2} =
        Api.create(
          KillmailRaw,
          Map.merge(killmail_attrs, %{
            killmail_id: 101_000_002,
            killmail_time: ~U[2024-01-02 14:00:00Z],
            solar_system_id: 30_000_142,
            victim_character_id: character_id,
            # Tengu
            victim_ship_type_id: 29_984,
            victim_corporation_id: 98_123_456,
            victim_alliance_id: nil,
            attacker_count: 3,
            total_value: Decimal.new("500000000.0"),
            raw_data: %{
              "victim" => %{"character_id" => character_id},
              "attackers" => [
                %{
                  "character_id" => 95_888_888,
                  # Harbinger
                  "ship_type_id" => 24_696,
                  "final_blow" => true
                }
              ]
            }
          })
        )

      %{character_id: character_id}
    end

    test "returns comprehensive threat analysis for character", %{character_id: character_id} do
      assert {:ok, analysis} = CharacterIntelligence.analyze_character_threat(character_id)

      assert analysis.character_id == character_id
      assert analysis.threat_score >= 0 and analysis.threat_score <= 100
      assert analysis.threat_level in [:minimal, :low, :medium, :high, :extreme]
      assert is_map(analysis.dimensions)
      assert Map.has_key?(analysis.dimensions, :combat_skill)
      assert Map.has_key?(analysis.dimensions, :ship_mastery)
      assert Map.has_key?(analysis.dimensions, :fleet_effectiveness)
      assert is_map(analysis.recent_activity)
      assert %DateTime{} = analysis.analysis_timestamp
    end

    test "handles character with no killmail history" do
      non_existent_id = 99_999_999
      assert {:ok, analysis} = CharacterIntelligence.analyze_character_threat(non_existent_id)

      assert analysis.threat_score == 0
      assert analysis.threat_level == :minimal
    end

    test "includes ship specialization when available", %{character_id: character_id} do
      assert {:ok, analysis} = CharacterIntelligence.analyze_character_threat(character_id)

      if Map.has_key?(analysis, :ship_specialization) do
        assert is_map(analysis.ship_specialization)
        assert Map.has_key?(analysis.ship_specialization, :preferred_roles)
      end
    end
  end

  describe "detect_behavioral_patterns/1" do
    setup do
      character_id = 95_234_567

      # Create solo kills
      for i <- 1..5 do
        killmail_attrs = killmail_raw_factory()

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 102_000_000 + i,
              killmail_time: DateTime.add(~U[2024-01-01 00:00:00Z], i * 86_400, :second),
              solar_system_id: 30_000_142,
              victim_character_id: 95_000_000 + i,
              victim_ship_type_id: 587,
              victim_corporation_id: 98_000_000 + i,
              attacker_count: 1,
              total_value: Decimal.new("#{10_000_000 * i}"),
              raw_data: %{
                "attackers" => [
                  %{
                    "character_id" => character_id,
                    "ship_type_id" => 29_984,
                    "final_blow" => true
                  }
                ]
              }
            })
          )
      end

      %{character_id: character_id}
    end

    test "detects behavioral patterns from killmail history", %{character_id: character_id} do
      assert {:ok, patterns} = CharacterIntelligence.detect_behavioral_patterns(character_id)

      assert patterns.character_id == character_id

      assert patterns.primary_pattern in [
               :unknown,
               :solo_hunter,
               :fleet_anchor,
               :specialist,
               :opportunist
             ]

      assert is_list(patterns.patterns)
      assert is_list(patterns.characteristics)
      assert patterns.confidence >= 0.0 and patterns.confidence <= 1.0
      assert %DateTime{} = patterns.analysis_timestamp
    end

    test "returns unknown pattern for insufficient data" do
      new_character_id = 95_999_888
      assert {:ok, patterns} = CharacterIntelligence.detect_behavioral_patterns(new_character_id)

      assert patterns.primary_pattern == :unknown
      assert patterns.confidence <= 0.7
    end
  end

  describe "calculate_threat_trends/2" do
    setup do
      character_id = 95_345_678

      # Create kills over time with increasing effectiveness
      for i <- 1..10 do
        killmail_attrs = killmail_raw_factory()

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 103_000_000 + i,
              killmail_time: DateTime.add(~U[2024-01-01 00:00:00Z], i * 86_400, :second),
              solar_system_id: 30_000_142,
              victim_character_id: 95_100_000 + i,
              victim_ship_type_id: 587 + i,
              victim_corporation_id: 98_100_000 + i,
              # Decreasing support needed
              attacker_count: max(1, 6 - div(i, 2)),
              # Increasing value kills
              total_value: Decimal.new("#{10_000_000 * i}"),
              raw_data: %{
                "attackers" => [
                  %{
                    "character_id" => character_id,
                    "ship_type_id" => 29_984,
                    "final_blow" => true
                  }
                ]
              }
            })
          )
      end

      %{character_id: character_id}
    end

    test "calculates threat trends over default period", %{character_id: character_id} do
      assert {:ok, trends} = CharacterIntelligence.calculate_threat_trends(character_id)

      assert trends.character_id == character_id
      assert trends.trend_direction in [:rising, :falling, :stable, :insufficient_data]
      assert is_float(trends.trend_strength)
      assert is_list(trends.historical_scores)
      assert trends.analysis_period_days == 90
      assert %DateTime{} = trends.analysis_timestamp
    end

    test "calculates threat trends over custom period", %{character_id: character_id} do
      assert {:ok, trends} = CharacterIntelligence.calculate_threat_trends(character_id, 30)

      assert trends.analysis_period_days == 30
    end

    test "returns insufficient_data for new character" do
      new_character_id = 95_999_777
      assert {:ok, trends} = CharacterIntelligence.calculate_threat_trends(new_character_id)

      assert trends.trend_direction == :insufficient_data
      assert trends.trend_strength == 0.0
    end
  end

  describe "compare_character_threats/1" do
    setup do
      character_ids =
        for i <- 1..3 do
          char_id = 95_400_000 + i

          # Create different amounts of kills for each character
          for j <- 1..(i * 2) do
            killmail_attrs = killmail_raw_factory()

            {:ok, _} =
              Api.create(
                KillmailRaw,
                Map.merge(killmail_attrs, %{
                  killmail_id: 104_000_000 + i * 100 + j,
                  killmail_time: ~U[2024-01-01 00:00:00Z],
                  solar_system_id: 30_000_142,
                  victim_character_id: 95_500_000 + j,
                  victim_ship_type_id: 587,
                  victim_corporation_id: 98_500_000 + j,
                  attacker_count: 1,
                  total_value: Decimal.new("#{10_000_000 * i}"),
                  raw_data: %{
                    "attackers" => [
                      %{
                        "character_id" => char_id,
                        "ship_type_id" => 29_984,
                        "final_blow" => true
                      }
                    ]
                  }
                })
              )
          end

          char_id
        end

      %{character_ids: character_ids}
    end

    test "compares multiple character threats and sorts by score", %{character_ids: character_ids} do
      assert {:ok, comparisons} = CharacterIntelligence.compare_character_threats(character_ids)

      assert length(comparisons) <= length(character_ids)

      # Check sorting (highest threat first)
      scores = Enum.map(comparisons, fn {_id, analysis} -> analysis.threat_score end)
      assert scores == Enum.sort(scores, :desc)

      # Verify structure
      for {char_id, analysis} <- comparisons do
        assert is_integer(char_id)
        assert char_id in character_ids
        assert is_map(analysis)
        assert Map.has_key?(analysis, :threat_score)
      end
    end

    test "handles empty character list" do
      assert {:ok, []} = CharacterIntelligence.compare_character_threats([])
    end
  end

  describe "gang synergy functions" do
    setup do
      character_ids = [96_001_001, 96_001_002, 96_001_003]

      # Create shared killmails for the first two characters
      for i <- 1..3 do
        killmail_attrs = killmail_raw_factory()

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 105_000_000 + i,
              killmail_time: ~U[2024-01-01 00:00:00Z],
              solar_system_id: 30_000_142,
              victim_character_id: 95_700_000 + i,
              victim_ship_type_id: 587,
              victim_corporation_id: 98_700_000 + i,
              attacker_count: 2,
              total_value: Decimal.new("50000000"),
              raw_data: %{
                "attackers" => [
                  %{"character_id" => Enum.at(character_ids, 0), "ship_type_id" => 29_984},
                  %{"character_id" => Enum.at(character_ids, 1), "ship_type_id" => 11_987}
                ]
              }
            })
          )
      end

      %{character_ids: character_ids}
    end

    test "analyzes gang synergy", %{character_ids: character_ids} do
      assert {:ok, synergy} = CharacterIntelligence.analyze_gang_synergy(character_ids)

      assert is_map(synergy)
      assert Map.has_key?(synergy, :coordination_score)
      assert Map.has_key?(synergy, :shared_victories)
    end

    test "analyzes character relationships", %{character_ids: character_ids} do
      assert {:ok, relationships} =
               CharacterIntelligence.analyze_character_relationships(character_ids)

      assert is_map(relationships)
      assert Map.has_key?(relationships, :relationship_matrix)
      assert Map.has_key?(relationships, :network_cohesion)
    end

    test "analyzes group patterns", %{character_ids: character_ids} do
      assert {:ok, patterns} = CharacterIntelligence.analyze_group_patterns(character_ids)

      assert is_map(patterns)
      assert Map.has_key?(patterns, :operation_types)
      assert Map.has_key?(patterns, :temporal_patterns)
    end

    test "predicts group behavior", %{character_ids: character_ids} do
      assert {:ok, prediction} = CharacterIntelligence.predict_group_behavior(character_ids)

      assert is_map(prediction)
      assert Map.has_key?(prediction, :likely_operation_times)
      assert Map.has_key?(prediction, :confidence_level)
    end

    test "analyzes gang effectiveness", %{character_ids: character_ids} do
      assert {:ok, effectiveness} =
               CharacterIntelligence.analyze_gang_effectiveness(character_ids)

      assert is_map(effectiveness)

      assert Map.has_key?(effectiveness, :coordination_score) or
               Map.has_key?(effectiveness, :synergy_score) or
               Map.has_key?(effectiveness, :effectiveness_rating)
    end
  end
end
