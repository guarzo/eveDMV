defmodule EveDmv.Intelligence.HomeDefenseAnalyzerTest do
  use EveDmv.IntelligenceCase, async: true
  @moduletag :skip

  alias EveDmv.Intelligence.HomeDefenseAnalyzer

  describe "analyze_home_defense/2" do
    test "analyzes home system defense patterns" do
      corporation_id = 1_000_100
      # Jita
      home_system_id = 30_000_142

      # Create home defense activity
      create_home_defense_activity(corporation_id, home_system_id)

      assert {:ok, analysis} =
               HomeDefenseAnalyzer.analyze_home_defense(corporation_id, home_system_id)

      assert analysis.corporation_id == corporation_id
      assert analysis.home_system_id == home_system_id
      assert analysis.defense_rating >= 0
      assert analysis.defense_rating <= 5
      assert is_list(analysis.active_defenders)
      assert is_map(analysis.threat_assessment)
    end

    test "identifies active defenders correctly" do
      corporation_id = 1_000_101
      # Amarr
      home_system_id = 30_002_187

      # Create specific defender activity
      defender_ids = [95_000_100, 95_000_101, 95_000_102]

      for defender_id <- defender_ids do
        # Create kills by defenders in home system
        for _i <- 1..5 do
          create(:killmail_raw, %{
            solar_system_id: home_system_id,
            killmail_data: %{
              "solar_system_id" => home_system_id,
              "attackers" => [
                %{
                  "character_id" => defender_id,
                  "corporation_id" => corporation_id,
                  "final_blow" => true
                }
              ],
              "victim" => %{
                "character_id" => Enum.random(90_000_000..95_000_000),
                "corporation_id" => Enum.random(2_000_000..3_000_000)
              }
            }
          })
        end
      end

      assert {:ok, analysis} =
               HomeDefenseAnalyzer.analyze_home_defense(corporation_id, home_system_id)

      # Should identify all active defenders
      active_defender_ids = Enum.map(analysis.active_defenders, & &1.character_id)
      assert length(active_defender_ids) == 3
      assert Enum.all?(defender_ids, &(&1 in active_defender_ids))
    end

    test "calculates defense rating based on activity" do
      corporation_id = 1_000_102
      home_system_id = 30_000_142

      # Create high defense activity
      create_strong_defense_pattern(corporation_id, home_system_id)

      assert {:ok, analysis} =
               HomeDefenseAnalyzer.analyze_home_defense(corporation_id, home_system_id)

      # Strong defense should have high rating
      assert analysis.defense_rating >= 4.0
      assert analysis.response_time_minutes < 10
    end

    test "detects recent threats in home system" do
      corporation_id = 1_000_103
      home_system_id = 30_000_142
      threat_character_id = 95_999_999

      # Create recent hostile activity
      for _i <- 1..3 do
        create(:killmail_raw, %{
          solar_system_id: home_system_id,
          # 1 hour ago
          killmail_time: DateTime.add(DateTime.utc_now(), -3600, :second),
          killmail_data: %{
            "solar_system_id" => home_system_id,
            "attackers" => [
              %{
                "character_id" => threat_character_id,
                "corporation_id" => 2_000_000,
                "final_blow" => true
              }
            ],
            "victim" => %{
              "character_id" => Enum.random(95_000_000..95_000_100),
              "corporation_id" => corporation_id
            }
          }
        })
      end

      assert {:ok, analysis} =
               HomeDefenseAnalyzer.analyze_home_defense(corporation_id, home_system_id)

      # Should identify the threat
      assert length(analysis.recent_threats) > 0
      threat = Enum.find(analysis.recent_threats, &(&1.character_id == threat_character_id))
      assert threat != nil
      assert threat.kill_count == 3
    end

    test "analyzes timezone coverage" do
      corporation_id = 1_000_104
      home_system_id = 30_000_142

      # Create activity across different timezones
      create_timezone_distributed_activity(corporation_id, home_system_id)

      assert {:ok, analysis} =
               HomeDefenseAnalyzer.analyze_home_defense(corporation_id, home_system_id)

      # Should have timezone analysis
      assert is_map(analysis.timezone_coverage)
      assert Map.has_key?(analysis.timezone_coverage, "USTZ")
      assert Map.has_key?(analysis.timezone_coverage, "EUTZ")
      assert Map.has_key?(analysis.timezone_coverage, "AUTZ")

      # Should identify coverage gaps
      assert is_list(analysis.coverage_gaps)
    end

    test "handles no home defense activity" do
      corporation_id = 1_000_105
      home_system_id = 30_000_142

      # No activity created

      assert {:ok, analysis} =
               HomeDefenseAnalyzer.analyze_home_defense(corporation_id, home_system_id)

      assert analysis.defense_rating == 0
      assert analysis.active_defenders == []
      assert analysis.recent_threats == []
    end
  end

  describe "analyze_member_response_times/2" do
    test "calculates member response times to threats" do
      corporation_id = 1_000_106
      home_system_id = 30_000_142

      # Create threat and response pattern
      # 2 hours ago
      threat_time = DateTime.add(DateTime.utc_now(), -7200, :second)
      threat_character_id = 95_999_998

      # Initial threat
      create(:killmail_raw, %{
        solar_system_id: home_system_id,
        killmail_time: threat_time,
        killmail_data: %{
          "attackers" => [
            %{
              "character_id" => threat_character_id,
              "final_blow" => true
            }
          ],
          "victim" => %{
            "character_id" => 95_000_200,
            "corporation_id" => corporation_id
          }
        }
      })

      # Corp member responses at different times
      # minutes
      response_times = [5, 10, 15, 20]

      for {minutes, defender_id} <- Enum.zip(response_times, 95_000_300..95_000_303) do
        response_time = DateTime.add(threat_time, minutes * 60, :second)

        create(:killmail_raw, %{
          solar_system_id: home_system_id,
          killmail_time: response_time,
          killmail_data: %{
            "attackers" => [
              %{
                "character_id" => defender_id,
                "corporation_id" => corporation_id,
                "final_blow" => true
              }
            ],
            "victim" => %{
              "character_id" => threat_character_id
            }
          }
        })
      end

      assert {:ok, response_analysis} =
               HomeDefenseAnalyzer.analyze_member_response_times(corporation_id, home_system_id)

      assert response_analysis.average_response_time > 0
      assert response_analysis.fastest_response_time == 5
      assert length(response_analysis.responder_list) == 4
    end
  end

  describe "identify_defense_patterns/2" do
    test "identifies coordinated defense patterns" do
      corporation_id = 1_000_107
      home_system_id = 30_000_142

      # Create coordinated defense activity
      create_coordinated_defense_pattern(corporation_id, home_system_id)

      assert {:ok, patterns} =
               HomeDefenseAnalyzer.identify_defense_patterns(corporation_id, home_system_id)

      assert patterns.coordination_score > 0.7
      assert patterns.fleet_formation_detected == true
      assert length(patterns.common_fleet_members) >= 3
    end

    test "detects standing fleet activity" do
      corporation_id = 1_000_108
      home_system_id = 30_000_142

      # Create standing fleet pattern
      fleet_members = [95_000_400, 95_000_401, 95_000_402]

      # Fleet members consistently killing together
      for _i <- 1..10 do
        victim_id = Enum.random(90_000_000..95_000_000)
        kill_time = random_datetime_in_past(7)

        create(:killmail_raw, %{
          solar_system_id: home_system_id,
          killmail_time: kill_time,
          killmail_data: %{
            "attackers" =>
              Enum.map(fleet_members, fn member_id ->
                %{
                  "character_id" => member_id,
                  "corporation_id" => corporation_id,
                  "final_blow" => member_id == hd(fleet_members)
                }
              end),
            "victim" => %{
              "character_id" => victim_id
            }
          }
        })
      end

      assert {:ok, patterns} =
               HomeDefenseAnalyzer.identify_defense_patterns(corporation_id, home_system_id)

      assert patterns.standing_fleet_active == true
      assert MapSet.new(patterns.common_fleet_members) == MapSet.new(fleet_members)
    end
  end

  describe "defense rating calculation" do
    test "defense rating is always between 0 and 5" do
      # Test various scenarios
      scenarios = [
        # No defenders, no kills, slow response
        {0, 0, 60},
        # Some defenders, many kills, average response
        {10, 50, 30},
        # Many defenders, many kills, fast response
        {20, 100, 1},
        # Few defenders, few kills, fast response
        {5, 10, 15}
      ]

      for {defender_count, kill_count, response_time} <- scenarios do
        stats = %{
          active_defenders: List.duplicate(%{}, defender_count),
          total_kills: kill_count,
          average_response_time: response_time,
          timezone_coverage: %{"USTZ" => 0.5, "EUTZ" => 0.3, "AUTZ" => 0.2}
        }

        rating = HomeDefenseAnalyzer.calculate_defense_rating(stats)
        assert rating >= 0
        assert rating <= 5
      end
    end
  end

  describe "threat assessment" do
    test "correctly prioritizes threats by danger level" do
      corporation_id = 1_000_109
      home_system_id = 30_000_142

      # Create threats with different danger levels
      threats = [
        # High threat - many kills in Loki
        {95_999_001, 10, 17_738},
        # Medium threat - some kills in Rifter
        {95_999_002, 5, 587},
        # Low threat - one kill
        {95_999_003, 1, 588}
      ]

      for {threat_id, kill_count, ship_type} <- threats do
        for _i <- 1..kill_count do
          create(:killmail_raw, %{
            solar_system_id: home_system_id,
            killmail_data: %{
              "attackers" => [
                %{
                  "character_id" => threat_id,
                  "ship_type_id" => ship_type,
                  "final_blow" => true
                }
              ],
              "victim" => %{
                "character_id" => Enum.random(95_000_000..95_000_100),
                "corporation_id" => corporation_id
              }
            }
          })
        end
      end

      assert {:ok, analysis} =
               HomeDefenseAnalyzer.analyze_home_defense(corporation_id, home_system_id)

      # Threats should be sorted by danger level
      threat_ids = Enum.map(analysis.recent_threats, & &1.character_id)
      # Highest threat first
      assert hd(threat_ids) == 95_999_001
    end
  end

  # Helper functions specific to home defense testing

  defp create_home_defense_activity(corporation_id, home_system_id) do
    # Create mix of defensive kills in home system
    for _i <- 1..20 do
      defender_id = Enum.random(95_000_000..95_000_010)

      create(:killmail_raw, %{
        solar_system_id: home_system_id,
        killmail_data: %{
          "solar_system_id" => home_system_id,
          "attackers" => [
            %{
              "character_id" => defender_id,
              "corporation_id" => corporation_id,
              "final_blow" => true
            }
          ],
          "victim" => %{
            "character_id" => Enum.random(90_000_000..95_000_000),
            "corporation_id" => Enum.random(2_000_000..3_000_000)
          }
        }
      })
    end
  end

  defp create_strong_defense_pattern(corporation_id, home_system_id) do
    # Create pattern showing strong, coordinated defense
    defender_group = [95_000_050, 95_000_051, 95_000_052, 95_000_053]

    # Multiple quick responses to threats
    for _incident <- 1..5 do
      threat_time = random_datetime_in_past(7)

      # Quick coordinated response (within 5 minutes)
      for {defender_id, delay} <- Enum.zip(defender_group, 0..3) do
        response_time = DateTime.add(threat_time, delay * 60, :second)

        create(:killmail_raw, %{
          solar_system_id: home_system_id,
          killmail_time: response_time,
          killmail_data: %{
            "attackers" => [
              %{
                "character_id" => defender_id,
                "corporation_id" => corporation_id,
                "final_blow" => delay == 0
              }
            ],
            "victim" => %{
              "character_id" => Enum.random(90_000_000..95_000_000)
            }
          }
        })
      end
    end
  end

  defp create_timezone_distributed_activity(corporation_id, home_system_id) do
    # USTZ: 00:00 - 08:00 EVE time
    # EUTZ: 08:00 - 16:00 EVE time
    # AUTZ: 16:00 - 24:00 EVE time

    timezones = [
      # USTZ
      {0, 8},
      # EUTZ
      {8, 16},
      # AUTZ
      {16, 24}
    ]

    for {start_hour, end_hour} <- timezones do
      # Create activity in each timezone
      for _i <- 1..5 do
        hour = Enum.random(start_hour..(end_hour - 1))

        kill_time =
          DateTime.utc_now()
          # Past week
          |> DateTime.add(-Enum.random(1..7) * 86_400, :second)
          |> Map.put(:hour, hour)
          |> Map.put(:minute, Enum.random(0..59))

        create(:killmail_raw, %{
          solar_system_id: home_system_id,
          killmail_time: kill_time,
          killmail_data: %{
            "attackers" => [
              %{
                "character_id" => Enum.random(95_000_000..95_000_100),
                "corporation_id" => corporation_id,
                "final_blow" => true
              }
            ],
            "victim" => %{
              "character_id" => Enum.random(90_000_000..95_000_000)
            }
          }
        })
      end
    end
  end

  defp create_coordinated_defense_pattern(corporation_id, home_system_id) do
    # Create kills showing coordinated fleet action
    fleet_members = [95_000_200, 95_000_201, 95_000_202, 95_000_203]

    for _engagement <- 1..8 do
      kill_time = random_datetime_in_past(3)
      victim_id = Enum.random(90_000_000..95_000_000)

      # All fleet members on the kill
      attackers =
        Enum.map(fleet_members, fn member_id ->
          %{
            "character_id" => member_id,
            "corporation_id" => corporation_id,
            "final_blow" => member_id == hd(fleet_members),
            "damage_done" => Enum.random(1000..5000)
          }
        end)

      create(:killmail_raw, %{
        solar_system_id: home_system_id,
        killmail_time: kill_time,
        killmail_data: %{
          "attackers" => attackers,
          "victim" => %{
            "character_id" => victim_id,
            "ship_type_id" => Enum.random([587, 588, 589])
          }
        }
      })
    end
  end
end
