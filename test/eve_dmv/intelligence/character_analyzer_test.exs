defmodule EveDmv.Intelligence.CharacterAnalyzerTest do
  use EveDmv.IntelligenceCase, async: true

  alias EveDmv.Intelligence.CharacterAnalyzer
  alias EveDmv.Intelligence.CharacterStats

  describe "analyze_character/1" do
    test "analyzes character with killmail history" do
      character_id = 95_465_499

      # Create realistic test data
      killmails = create_realistic_killmail_set(character_id, count: 50)

      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)

      assert character_stats.character_id == character_id
      assert character_stats.dangerous_rating >= 0
      assert character_stats.dangerous_rating <= 5
      assert is_binary(character_stats.analysis_data)

      # Verify the analysis data contains expected fields
      {:ok, analysis_data} = Jason.decode(character_stats.analysis_data)
      assert is_map(analysis_data)
      assert Map.has_key?(analysis_data, "basic_stats")
      assert Map.has_key?(analysis_data, "danger_rating")
    end

    test "handles character with no killmail history" do
      character_id = 95_465_500

      result = CharacterAnalyzer.analyze_character(character_id)

      # Should return error for insufficient data
      assert {:error, :insufficient_data} = result
    end

    test "calculates dangerous rating accurately" do
      character_id = 95_465_501

      # Create high-threat killmail pattern
      create_high_threat_killmails(character_id)

      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)
      assert character_stats.dangerous_rating >= 4
    end

    test "identifies frequent systems correctly" do
      character_id = 95_465_502
      # Jita
      system_id = 30_000_142

      # Create multiple killmails in same system
      for _i <- 1..20 do
        create(:killmail_raw, %{
          solar_system_id: system_id,
          killmail_data: %{
            "victim" => %{"character_id" => character_id},
            "solar_system_id" => system_id
          }
        })
      end

      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)

      # Parse analysis data to check frequent systems
      {:ok, analysis_data} = Jason.decode(character_stats.analysis_data)
      geographic_patterns = Map.get(analysis_data, "geographic_patterns", %{})
      most_active_systems = Map.get(geographic_patterns, "most_active_systems", [])

      # System should be in the most active systems
      assert Enum.any?(most_active_systems, fn system ->
               Map.get(system, "system_id") == system_id
             end)
    end

    test "handles ESI failures gracefully" do
      character_id = 95_465_503

      # Create killmails for a character that won't exist in ESI
      create_realistic_killmail_set(character_id, count: 15)

      # Should still analyze based on killmail data
      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)
      assert character_stats.character_id == character_id
    end

    test "calculates kill/death ratio correctly" do
      character_id = 95_465_504

      # Create pattern with known K/D ratio
      # 30 kills
      create_pvp_pattern(character_id, :hunter, count: 30)
      # 10 losses
      create_pvp_pattern(character_id, :victim, count: 10)

      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)
      assert character_stats.kd_ratio == 3.0
    end

    test "identifies solo activity correctly" do
      character_id = 95_465_505

      # Create solo kills
      for _i <- 1..10 do
        victim_id = Enum.random(90_000_000..100_000_000)

        create(:killmail_raw, %{
          killmail_data: %{
            "victim" => %{"character_id" => victim_id},
            "attackers" => [
              %{
                "character_id" => character_id,
                "final_blow" => true
              }
            ]
          }
        })
      end

      # Create gang kills
      for _i <- 1..5 do
        victim_id = Enum.random(90_000_000..100_000_000)

        create(:killmail_raw, %{
          killmail_data: %{
            "victim" => %{"character_id" => victim_id},
            "attackers" => [
              %{
                "character_id" => character_id,
                "final_blow" => true
              },
              %{
                "character_id" => Enum.random(90_000_000..100_000_000),
                "final_blow" => false
              }
            ]
          }
        })
      end

      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)
      assert character_stats.solo_kill_count == 10
      # Solo ratio should be 10/15 = 0.67
      assert_in_delta character_stats.solo_ratio, 0.67, 0.01
    end
  end

  describe "dangerous_rating calculation" do
    property "dangerous rating is always between 0 and 5" do
      check all(
              killmail_count <- StreamData.integer(10..100),
              victim_ratio <- StreamData.float(min: 0.0, max: 1.0)
            ) do
        character_id = System.unique_integer([:positive]) + 90_000_000
        create_killmails_with_ratio(character_id, killmail_count, victim_ratio)

        {:ok, stats} = CharacterAnalyzer.analyze_character(character_id)
        assert stats.dangerous_rating >= 0
        assert stats.dangerous_rating <= 5
      end
    end
  end

  describe "analyze_characters/1" do
    test "batch analyzes multiple characters" do
      character_ids = [95_465_600, 95_465_601, 95_465_602]

      # Create killmails for each character
      for character_id <- character_ids do
        create_realistic_killmail_set(character_id, count: 15)
      end

      assert {:ok, results} = CharacterAnalyzer.analyze_characters(character_ids)
      assert length(results) == 3

      # Check each result
      Enum.each(results, fn result ->
        assert match?({:ok, _} | {:error, _}, result)
      end)
    end

    test "handles timeout in batch analysis" do
      # Create a large number of characters to potentially trigger timeout
      character_ids = Enum.map(1..10, fn i -> 95_465_700 + i end)

      assert {:ok, results} = CharacterAnalyzer.analyze_characters(character_ids)
      assert length(results) == 10
    end
  end

  describe "process_killmail_data/1" do
    test "processes raw killmail data correctly" do
      raw_killmail = %{
        "killmail_id" => 123_456,
        "killmail_time" => "2024-01-15T12:00:00Z",
        "solar_system_id" => 30_000_142,
        "participants" => [
          %{
            "character_id" => 95_465_499,
            "is_victim" => true,
            "ship_type_id" => 587
          },
          %{
            "character_id" => 95_465_500,
            "is_victim" => false,
            "final_blow" => true,
            "ship_type_id" => 588
          }
        ],
        "zkb" => %{
          "totalValue" => 10_000_000
        }
      }

      assert {:ok, processed} = CharacterAnalyzer.process_killmail_data(raw_killmail)

      assert processed.killmail_id == 123_456
      assert processed.solar_system_id == 30_000_142
      assert length(processed.participants) == 2
      assert processed.victim["character_id"] == 95_465_499
      assert length(processed.attackers) == 1
      assert is_map(processed.zkb)
    end

    test "handles missing zkb data" do
      raw_killmail = %{
        "killmail_id" => 123_457,
        "killmail_time" => "2024-01-15T12:00:00Z",
        "solar_system_id" => 30_000_142,
        "participants" => []
      }

      assert {:ok, processed} = CharacterAnalyzer.process_killmail_data(raw_killmail)
      assert processed.zkb == %{}
    end
  end

  describe "calculate_danger_rating/1" do
    test "calculates low danger rating for peaceful character" do
      stats = %{
        basic_stats: %{
          kills: %{count: 5, solo: 0, total_value: 50_000_000},
          losses: %{count: 20, solo: 15, total_value: 200_000_000},
          kd_ratio: 0.25,
          solo_ratio: 0.0,
          efficiency: 20.0
        },
        danger_rating: %{score: 1.5}
      }

      rating = CharacterAnalyzer.calculate_danger_rating(stats)
      assert rating <= 2
    end

    test "calculates high danger rating for dangerous character" do
      stats = %{
        basic_stats: %{
          kills: %{count: 100, solo: 80, total_value: 5_000_000_000},
          losses: %{count: 10, solo: 5, total_value: 100_000_000},
          kd_ratio: 10.0,
          solo_ratio: 0.8,
          efficiency: 98.0
        },
        danger_rating: %{score: 4.5}
      }

      rating = CharacterAnalyzer.calculate_danger_rating(stats)
      assert rating >= 4
    end
  end

  # Helper functions specific to this test

  defp create_high_threat_killmails(character_id) do
    # Create pattern indicating dangerous player
    for _i <- 1..20 do
      create(:killmail_raw, %{
        killmail_data: %{
          "attackers" => [
            %{
              "character_id" => character_id,
              "final_blow" => true,
              # Loki (T3 cruiser)
              "ship_type_id" => 17_738
            }
          ],
          "victim" => %{
            "character_id" => Enum.random(90_000_000..95_000_000),
            # Cheap ships
            "ship_type_id" => Enum.random([587, 588, 589])
          }
        }
      })
    end
  end

  defp create_killmails_with_ratio(character_id, total_count, victim_ratio) do
    victim_count = round(total_count * victim_ratio)
    attacker_count = total_count - victim_count

    # Create losses
    create_pvp_pattern(character_id, :victim, count: victim_count)

    # Create kills
    create_pvp_pattern(character_id, :hunter, count: attacker_count)
  end
end
