defmodule EveDmv.Contexts.CharacterIntelligenceTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Api
  alias EveDmv.Contexts.CharacterIntelligence
  alias EveDmv.Killmails.KillmailRaw

  describe "analyze_character_threat/1" do
    setup do
      # Create test character
      # Create test character data
      character = %{
        character_id: 95_123_456,
        character_name: "Test Pilot",
        corporation_id: 98_123_456
      }

      # Create test killmails with recent dates
      recent_time = DateTime.add(DateTime.utc_now(), -10, :day)

      {:ok, _killmail1} =
        Api.create(
          KillmailRaw,
          %{
            killmail_id: 101_000_001,
            killmail_time: recent_time,
            killmail_hash: "test_hash_101000001",
            solar_system_id: 30_000_142,
            victim_character_id: 95_999_999,
            # Rifter
            victim_ship_type_id: 587,
            victim_corporation_id: 98_999_999,
            victim_alliance_id: nil,
            attacker_count: 1,
            total_value: Decimal.new("50000000"),
            raw_data: %{
              "attackers" => [
                %{
                  "character_id" => character.character_id,
                  "ship_type_id" => 29_984,
                  "corporation_id" => character.corporation_id,
                  "final_blow" => true
                }
              ]
            },
            source: "test"
          },
          domain: Api
        )

      {:ok, _killmail2} =
        Api.create(
          KillmailRaw,
          %{
            killmail_id: 101_000_002,
            killmail_time: DateTime.add(recent_time, 1, :day),
            killmail_hash: "test_hash_101000002",
            solar_system_id: 30_000_142,
            victim_character_id: character.character_id,
            # Tengu
            victim_ship_type_id: 29_984,
            victim_corporation_id: character.corporation_id,
            victim_alliance_id: nil,
            attacker_count: 3,
            total_value: Decimal.new("500000000"),
            raw_data: %{
              "attackers" => [
                %{
                  "character_id" => 95_888_888,
                  "ship_type_id" => 24_696,
                  "corporation_id" => 98_888_888,
                  "final_blow" => true
                }
              ]
            },
            source: "test"
          },
          domain: Api
        )

      # Add more killmails to meet minimum threshold (5 killmails)
      for i <- 3..6 do
        {:ok, _} =
          Api.create(
            KillmailRaw,
            %{
              killmail_id: 101_000_000 + i,
              killmail_time: DateTime.add(recent_time, i, :day),
              killmail_hash: "test_hash_10100000#{i}",
              solar_system_id: 30_000_142,
              victim_character_id: 95_999_900 + i,
              victim_ship_type_id: 587,
              victim_corporation_id: 98_999_900 + i,
              attacker_count: 1,
              total_value: Decimal.new("75000000"),
              raw_data: %{
                "attackers" => [
                  %{
                    "character_id" => character.character_id,
                    "ship_type_id" => 29_984,
                    "corporation_id" => character.corporation_id,
                    "final_blow" => true
                  }
                ]
              },
              source: "test"
            },
            domain: Api
          )
      end

      %{character_id: character.character_id}
    end

    test "returns comprehensive threat analysis for character", %{character_id: character_id} do
      assert {:ok, analysis} = CharacterIntelligence.analyze_character_threat(character_id)

      assert analysis.character_id == character_id
      assert analysis.overall_score >= 0 and analysis.overall_score <= 100
      assert analysis.threat_level in [:minimal, :low, :moderate, :high, :very_high, :extreme]

      # Check for either dimensions or detailed_breakdown
      breakdown = Map.get(analysis, :dimensions) || Map.get(analysis, :detailed_breakdown)
      assert is_map(breakdown)
      assert Map.has_key?(breakdown, :combat_skill)
      assert Map.has_key?(breakdown, :ship_mastery)

      assert Map.has_key?(breakdown, :gang_effectiveness) ||
               Map.has_key?(breakdown, :fleet_effectiveness)

      # Check for metadata with analysis timestamp
      assert is_map(analysis.metadata)
      assert analysis.metadata.analysis_timestamp
    end

    test "handles character with no killmail history" do
      non_existent_id = 99_999_999

      # Character with no killmail history returns insufficient_data error
      assert {:error, :insufficient_data} =
               CharacterIntelligence.analyze_character_threat(non_existent_id)
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
      # Create character with varied killmail history
      # Create test character data
      character = %{
        character_id: 95_234_567,
        character_name: "Pattern Test Pilot",
        corporation_id: 98_234_567
      }

      # Create solo kills with recent dates
      recent_time = DateTime.add(DateTime.utc_now(), -30, :day)

      for i <- 1..5 do
        {:ok, _} =
          Api.create(
            KillmailRaw,
            %{
              killmail_id: 102_000_000 + i,
              killmail_time: DateTime.add(recent_time, i * 86_400, :second),
              killmail_hash: "test_hash_#{102_000_000 + i}",
              solar_system_id: 30_000_142,
              victim_character_id: 95_000_000 + i,
              victim_ship_type_id: 587,
              victim_corporation_id: 98_000_000 + i,
              attacker_count: 1,
              total_value: Decimal.new("#{10_000_000 * i}"),
              raw_data: %{
                "attackers" => [
                  %{
                    "character_id" => character.character_id,
                    "ship_type_id" => 29_984,
                    "corporation_id" => character.corporation_id,
                    "final_blow" => true
                  }
                ]
              },
              source: "test"
            },
            domain: Api
          )
      end

      %{character_id: character.character_id}
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

    test "returns error for insufficient data" do
      new_character_id = 95_999_888

      # Character with insufficient data returns error
      assert {:error, :insufficient_data} =
               CharacterIntelligence.detect_behavioral_patterns(new_character_id)
    end
  end

  describe "calculate_threat_trends/2" do
    setup do
      # Create test character data
      character = %{
        character_id: 95_345_678,
        character_name: "Trend Test Pilot",
        corporation_id: 98_345_678
      }

      # Create kills over time with increasing effectiveness
      recent_time = DateTime.add(DateTime.utc_now(), -70, :day)

      for i <- 1..10 do
        {:ok, _} =
          Api.create(
            KillmailRaw,
            %{
              killmail_id: 103_000_000 + i,
              killmail_time: DateTime.add(recent_time, i * 86_400, :second),
              killmail_hash: "test_hash_#{103_000_000 + i}",
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
                    "character_id" => character.character_id,
                    "ship_type_id" => 29_984,
                    "corporation_id" => character.corporation_id,
                    "final_blow" => true
                  }
                ]
              },
              source: "test"
            },
            domain: Api
          )
      end

      %{character_id: character.character_id}
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
          # Create test character data
          char = %{
            character_id: 95_400_000 + i,
            character_name: "Compare Test #{i}",
            corporation_id: 98_400_000 + i
          }

          # Create different amounts of kills for each character
          for j <- 1..(i * 2) do
            {:ok, _} =
              Api.create(
                KillmailRaw,
                %{
                  killmail_id: 104_000_000 + i * 100 + j,
                  killmail_time: DateTime.utc_now() |> DateTime.add(-7, :day),
                  killmail_hash: "test_hash_#{104_000_000 + i * 100 + j}",
                  solar_system_id: 30_000_142,
                  victim_character_id: 95_500_000 + j,
                  victim_ship_type_id: 587,
                  victim_corporation_id: 98_500_000 + j,
                  attacker_count: 1,
                  total_value: Decimal.new("#{10_000_000 * i}"),
                  raw_data: %{
                    "attackers" => [
                      %{
                        "character_id" => char.character_id,
                        "ship_type_id" => 29_984,
                        "corporation_id" => char.corporation_id,
                        "final_blow" => true
                      }
                    ]
                  },
                  source: "test"
                },
                domain: Api
              )
          end

          char.character_id
        end

      %{character_ids: character_ids}
    end

    test "compares multiple character threats and sorts by score", %{character_ids: character_ids} do
      assert {:ok, comparisons} = CharacterIntelligence.compare_character_threats(character_ids)

      assert length(comparisons) <= length(character_ids)

      # Check sorting (highest threat first) - use overall_score field
      scores =
        Enum.map(comparisons, fn {_id, analysis} ->
          Map.get(analysis, :threat_score, Map.get(analysis, :overall_score, 0))
        end)

      assert scores == Enum.sort(scores, :desc)

      # Verify structure
      for {char_id, analysis} <- comparisons do
        assert is_integer(char_id)
        assert char_id in character_ids
        assert is_map(analysis)
        assert Map.has_key?(analysis, :threat_score) or Map.has_key?(analysis, :overall_score)
      end
    end

    test "handles empty character list" do
      assert {:ok, []} = CharacterIntelligence.compare_character_threats([])
    end

    test "filters out characters with analysis errors" do
      # Create a character with sufficient killmail data
      valid_id = 95_400_001
      recent_time = DateTime.add(DateTime.utc_now(), -20, :day)

      # Create 5 killmails for valid_id to meet minimum threshold
      for i <- 1..5 do
        {:ok, _} =
          Api.create(
            KillmailRaw,
            %{
              killmail_id: 104_000_000 + i,
              killmail_time: DateTime.add(recent_time, i, :day),
              killmail_hash: "test_hash_10400000#{i}",
              solar_system_id: 30_000_142,
              victim_character_id: 96_000_000 + i,
              victim_ship_type_id: 587,
              victim_corporation_id: 98_400_000 + i,
              attacker_count: 1,
              total_value: Decimal.new("50000000"),
              raw_data: %{
                "attackers" => [
                  %{
                    "character_id" => valid_id,
                    "ship_type_id" => 29_984,
                    "corporation_id" => 98_400_001,
                    "final_blow" => true
                  }
                ]
              },
              source: "test"
            },
            domain: Api
          )
      end

      invalid_id = 99_999_999

      assert {:ok, comparisons} =
               CharacterIntelligence.compare_character_threats([valid_id, invalid_id])

      comparison_ids = Enum.map(comparisons, fn {id, _} -> id end)
      # Valid ID should be in results, invalid ID should be filtered out
      assert valid_id in comparison_ids
      refute invalid_id in comparison_ids
    end
  end

  describe "get_character_intelligence_report/1" do
    setup do
      # Create test character data
      character = %{
        character_id: 95_456_789,
        character_name: "Report Test Pilot",
        corporation_id: 98_456_789
      }

      # Create killmails for the character
      recent_time = DateTime.add(DateTime.utc_now(), -15, :day)

      for i <- 1..5 do
        {:ok, _} =
          Api.create(
            KillmailRaw,
            %{
              killmail_id: 105_000_000 + i,
              killmail_time: DateTime.add(recent_time, i, :day),
              killmail_hash: "test_hash_10500000#{i}",
              solar_system_id: 30_000_142,
              victim_character_id: 96_100_000 + i,
              victim_ship_type_id: 587,
              victim_corporation_id: 98_500_000 + i,
              attacker_count: 1,
              total_value: Decimal.new("60000000"),
              raw_data: %{
                "attackers" => [
                  %{
                    "character_id" => character.character_id,
                    "ship_type_id" => 24_696,
                    "corporation_id" => character.corporation_id,
                    "final_blow" => true
                  }
                ]
              },
              source: "test"
            },
            domain: Api
          )
      end

      %{character_id: character.character_id}
    end

    test "returns comprehensive intelligence report", %{character_id: character_id} do
      assert {:ok, report} = CharacterIntelligence.get_character_intelligence_report(character_id)

      assert report.character_id == character_id
      assert Map.has_key?(report, :threat_analysis)
      assert is_map(report.threat_analysis)
      assert %DateTime{} = report.report_generated_at
    end
  end

  describe "ship intelligence integration" do
    setup do
      # Create test character data
      character = %{
        character_id: 95_567_890,
        character_name: "Ship Test Pilot",
        corporation_id: 98_567_890
      }

      # Create kills with various ships
      # Tengu, Rifter, Harbinger, Guardian, Heron
      ships = [29_984, 587, 24_696, 11_987, 621]

      for {ship_id, i} <- Enum.with_index(ships, 1) do
        {:ok, _} =
          Api.create(
            KillmailRaw,
            %{
              killmail_id: 105_000_000 + i,
              killmail_time: DateTime.utc_now() |> DateTime.add(-7, :day),
              killmail_hash: "test_hash_#{105_000_000 + i}",
              solar_system_id: 30_000_142,
              victim_character_id: 95_600_000 + i,
              victim_ship_type_id: 587,
              victim_corporation_id: 98_600_000 + i,
              attacker_count: 1,
              total_value: Decimal.new("10000000"),
              raw_data: %{
                "attackers" => [
                  %{
                    "character_id" => character.character_id,
                    "ship_type_id" => ship_id,
                    "corporation_id" => character.corporation_id,
                    "final_blow" => true
                  }
                ]
              },
              source: "test"
            },
            domain: Api
          )
      end

      %{character_id: character.character_id}
    end

    test "get_character_ship_intelligence/1 returns ship specialization", %{
      character_id: character_id
    } do
      assert {:ok, ship_intel} =
               CharacterIntelligence.get_character_ship_intelligence(character_id)

      assert Map.has_key?(ship_intel, :preferred_roles)
      assert Map.has_key?(ship_intel, :ship_mastery)
      assert Map.has_key?(ship_intel, :expertise_level)
      assert Map.has_key?(ship_intel, :total_killmails)
    end

    test "get_ship_preferences/1 returns summary", %{character_id: character_id} do
      preferences = CharacterIntelligence.get_ship_preferences(character_id)

      assert is_map(preferences)

      if map_size(preferences) > 0 do
        assert Map.has_key?(preferences, :top_ships) or
                 Map.has_key?(preferences, :preferred_roles) or
                 Map.has_key?(preferences, :ship_classes)
      end
    end
  end
end
