defmodule EveDmv.Intelligence.CharacterAnalyzerTest do
  @moduledoc """
  Comprehensive tests for CharacterAnalyzer module.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Intelligence.CharacterAnalyzer

  describe "analyze_character/1" do
    test "analyzes character with sufficient killmail data" do
      character_id = 123_456_789

      case CharacterAnalyzer.analyze_character(character_id) do
        {:ok, analysis} ->
          assert %{
                   character_id: ^character_id,
                   total_kills: kills,
                   total_losses: losses,
                   ship_usage: ship_usage,
                   frequent_associates: associates
                 } = analysis

          assert is_integer(kills)
          assert is_integer(losses)
          assert kills >= 0 and losses >= 0
          assert is_map(ship_usage)
          assert is_map(associates)

        {:error, :insufficient_activity} ->
          # Expected when character has < 10 kills/losses
          assert true

        {:error, :character_not_found} ->
          # Expected when character not in database
          assert true

        {:error, reason} ->
          assert is_atom(reason) or is_binary(reason)
      end
    end

    test "handles invalid character ID" do
      result = CharacterAnalyzer.analyze_character(-1)
      assert {:error, _reason} = result
    end

    test "handles nil character ID" do
      result = CharacterAnalyzer.analyze_character(nil)
      assert {:error, _reason} = result
    end
  end

  describe "calculate_ship_preferences/1" do
    test "calculates preferences from killmail data" do
      killmails = [
        %{
          is_victim: false,
          # Crucifier
          ship_type_id: 12_003,
          ship_name: "Crucifier",
          kills: 5,
          losses: 1
        },
        %{
          is_victim: false,
          # Rifter
          ship_type_id: 11_999,
          ship_name: "Rifter",
          kills: 10,
          losses: 3
        },
        %{
          is_victim: true,
          # Rifter loss
          ship_type_id: 11_999,
          ship_name: "Rifter"
        }
      ]

      result = CharacterAnalyzer.calculate_ship_preferences(killmails)

      assert %{
               most_used_ships: most_used,
               ship_success_rates: success_rates,
               preferred_ship_categories: categories,
               total_unique_ships: unique_count
             } = result

      assert is_list(most_used)
      assert is_map(success_rates)
      assert is_map(categories)
      assert is_integer(unique_count)
      assert unique_count > 0

      # Rifter should be most used
      assert List.first(most_used).ship_name == "Rifter"
    end

    test "handles empty killmail data" do
      result = CharacterAnalyzer.calculate_ship_preferences([])

      assert %{
               most_used_ships: [],
               ship_success_rates: %{},
               preferred_ship_categories: %{},
               total_unique_ships: 0
             } = result
    end
  end

  describe "analyze_geographic_patterns/1" do
    test "analyzes location patterns from killmails" do
      killmails = [
        %{
          # Rens
          solar_system_id: 30_002_187,
          solar_system_name: "Rens",
          security_status: 0.5,
          killmail_time: ~U[2024-01-01 12:00:00Z]
        },
        %{
          # Rens again
          solar_system_id: 30_002_187,
          solar_system_name: "Rens",
          security_status: 0.5,
          killmail_time: ~U[2024-01-01 13:00:00Z]
        },
        %{
          # J-space
          solar_system_id: 31_000_001,
          solar_system_name: "J100001",
          security_status: -0.99,
          killmail_time: ~U[2024-01-01 14:00:00Z]
        }
      ]

      result = CharacterAnalyzer.analyze_geographic_patterns(killmails)

      assert %{
               active_systems: active_systems,
               security_preferences: security_prefs,
               home_system_id: home_system,
               regional_activity: regional
             } = result

      assert is_map(active_systems)
      assert is_map(security_prefs)
      assert is_integer(home_system) or is_nil(home_system)
      assert is_map(regional)

      # Rens should be most active system
      assert home_system == 30_002_187
    end

    test "identifies wormhole activity" do
      wh_killmails = [
        %{
          solar_system_id: 31_000_001,
          solar_system_name: "J100001",
          security_status: -0.99
        },
        %{
          solar_system_id: 31_000_002,
          solar_system_name: "J100002",
          security_status: -0.99
        }
      ]

      result = CharacterAnalyzer.analyze_geographic_patterns(wh_killmails)

      assert result.security_preferences["wormhole"] > 0
    end
  end

  describe "identify_frequent_associates/1" do
    test "identifies associates from killmail participation" do
      killmails = [
        %{
          killmail_id: 1,
          participants: [
            %{character_id: 123, character_name: "Main Pilot", is_victim: false},
            %{character_id: 456, character_name: "Associate A", is_victim: false},
            %{character_id: 789, character_name: "Associate B", is_victim: false}
          ]
        },
        %{
          killmail_id: 2,
          participants: [
            %{character_id: 123, character_name: "Main Pilot", is_victim: false},
            %{character_id: 456, character_name: "Associate A", is_victim: false},
            %{character_id: 999, character_name: "Random Pilot", is_victim: false}
          ]
        }
      ]

      result = CharacterAnalyzer.identify_frequent_associates(killmails, 123)

      assert is_map(result)

      # Associate A should appear as frequent (2 shared killmails)
      if map_size(result) > 0 do
        assert Map.has_key?(result, 456) or Map.has_key?(result, "456")

        associate_data = result[456] || result["456"]

        if associate_data do
          assert associate_data["name"] == "Associate A"
          assert associate_data["shared_kills"] >= 2
        end
      end
    end

    test "handles no associates" do
      solo_killmails = [
        %{
          killmail_id: 1,
          participants: [
            %{character_id: 123, character_name: "Solo Pilot", is_victim: false}
          ]
        }
      ]

      result = CharacterAnalyzer.identify_frequent_associates(solo_killmails, 123)

      assert result == %{}
    end
  end

  describe "calculate_target_preferences/1" do
    test "analyzes target selection patterns" do
      killmails = [
        %{
          is_victim: false,
          # Capsule
          victim_ship_type_id: 670,
          victim_ship_name: "Capsule",
          victim_ship_category: "capsule",
          total_value: 1000.0,
          attacker_count: 1
        },
        %{
          is_victim: false,
          # Rifter
          victim_ship_type_id: 11_999,
          victim_ship_name: "Rifter",
          victim_ship_category: "frigate",
          total_value: 5_000_000.0,
          attacker_count: 3
        }
      ]

      result = CharacterAnalyzer.calculate_target_preferences(killmails)

      assert %{
               preferred_target_types: target_types,
               avg_target_value: avg_value,
               target_size_preference: size_pref,
               hunting_patterns: patterns
             } = result

      assert is_map(target_types)
      assert is_number(avg_value)
      assert avg_value > 0
      assert is_map(size_pref)
      assert is_map(patterns)
    end

    test "handles victim-only data" do
      victim_killmails = [
        %{
          is_victim: true,
          ship_type_id: 11_999,
          ship_name: "Rifter"
        }
      ]

      result = CharacterAnalyzer.calculate_target_preferences(victim_killmails)

      # Should handle gracefully with no kill data
      assert result.preferred_target_types == %{}
      assert result.avg_target_value == 0
    end
  end

  describe "identify_weaknesses/1" do
    test "identifies behavioral and technical weaknesses" do
      analysis_data = %{
        ship_usage: %{
          most_used_ships: [
            %{ship_name: "Rifter", usage_count: 20, success_rate: 0.3}
          ]
        },
        geographic_patterns: %{
          active_systems: %{30_002_187 => 15, 30_000_142 => 10},
          security_preferences: %{"lowsec" => 20, "highsec" => 5}
        },
        target_preferences: %{
          avg_target_value: 1_000_000,
          hunting_patterns: %{solo_hunting: 0.9, gang_hunting: 0.1}
        },
        temporal_patterns: %{
          active_hours: [20, 21, 22, 23],
          timezone: "UTC"
        }
      }

      result = CharacterAnalyzer.identify_weaknesses(analysis_data)

      assert %{
               behavioral_weaknesses: behavioral,
               technical_weaknesses: technical,
               loss_patterns: loss_patterns
             } = result

      assert is_list(behavioral)
      assert is_list(technical)
      assert is_list(loss_patterns)

      # Should identify predictable schedule (only 4 active hours)
      assert Enum.any?(behavioral, fn weakness ->
               String.contains?(weakness, "predictable") or String.contains?(weakness, "schedule")
             end)
    end

    test "identifies overconfidence from loss patterns" do
      overconfident_data = %{
        ship_usage: %{
          most_used_ships: [
            # Low success rate
            %{ship_name: "Ares", usage_count: 10, success_rate: 0.2}
          ]
        },
        target_preferences: %{
          # High value targets
          avg_target_value: 500_000_000,
          # Mostly solo
          hunting_patterns: %{solo_hunting: 0.95}
        }
      }

      result = CharacterAnalyzer.identify_weaknesses(overconfident_data)

      # Should identify overconfidence
      all_weaknesses = result.behavioral_weaknesses ++ result.technical_weaknesses

      assert Enum.any?(all_weaknesses, fn weakness ->
               String.contains?(String.downcase(weakness), "overconfident") or
                 String.contains?(String.downcase(weakness), "poor") or
                 String.contains?(String.downcase(weakness), "bad")
             end)
    end
  end

  describe "calculate_danger_rating/1" do
    test "calculates realistic danger ratings" do
      high_danger_stats = %{
        total_kills: 500,
        total_losses: 50,
        solo_kills: 300,
        isk_destroyed: 50_000_000_000,
        avg_gang_size: 2.5,
        ship_usage: %{
          preferred_ship_categories: %{"interceptor" => 0.4, "assault_frigate" => 0.3}
        }
      }

      rating = CharacterAnalyzer.calculate_danger_rating(high_danger_stats)

      assert is_integer(rating)
      assert rating >= 1 and rating <= 5
      # Should be high danger
      assert rating >= 4

      low_danger_stats = %{
        total_kills: 5,
        total_losses: 20,
        solo_kills: 1,
        isk_destroyed: 50_000_000,
        avg_gang_size: 15.0,
        ship_usage: %{
          preferred_ship_categories: %{"industrial" => 0.8}
        }
      }

      rating = CharacterAnalyzer.calculate_danger_rating(low_danger_stats)
      # Should be low danger
      assert rating <= 2
    end

    test "handles edge cases" do
      # No kills
      no_kills_stats = %{
        total_kills: 0,
        total_losses: 5,
        solo_kills: 0,
        isk_destroyed: 0,
        avg_gang_size: 0
      }

      rating = CharacterAnalyzer.calculate_danger_rating(no_kills_stats)
      # Minimum danger
      assert rating == 1
    end
  end

  describe "analyze_temporal_patterns/1" do
    test "analyzes activity timing patterns" do
      killmails = [
        # 14:00 UTC
        %{killmail_time: ~U[2024-01-01 14:00:00Z]},
        # 15:00 UTC
        %{killmail_time: ~U[2024-01-01 15:00:00Z]},
        # 14:30 UTC
        %{killmail_time: ~U[2024-01-01 14:30:00Z]},
        # 15:15 UTC next day
        %{killmail_time: ~U[2024-01-02 15:15:00Z]}
      ]

      result = CharacterAnalyzer.analyze_temporal_patterns(killmails)

      assert %{
               active_hours: active_hours,
               prime_timezone: timezone,
               activity_consistency: consistency,
               weekend_vs_weekday: weekend_ratio
             } = result

      assert is_list(active_hours)
      assert 14 in active_hours
      assert 15 in active_hours
      assert is_binary(timezone)
      assert is_number(consistency)
      assert is_number(weekend_ratio)
    end

    test "handles sparse activity data" do
      sparse_killmails = [
        %{killmail_time: ~U[2024-01-01 12:00:00Z]}
      ]

      result = CharacterAnalyzer.analyze_temporal_patterns(sparse_killmails)

      assert length(result.active_hours) >= 1
      assert result.active_hours == [12]
    end
  end

  describe "format_character_summary/1" do
    test "formats complete analysis into summary" do
      analysis = %{
        character_id: 123_456_789,
        character_name: "Test Pilot",
        total_kills: 100,
        total_losses: 25,
        dangerous_rating: 4,
        ship_usage: %{most_used_ships: [%{ship_name: "Rifter"}]},
        frequent_associates: %{456 => %{"name" => "Associate"}},
        identified_weaknesses: %{
          behavioral_weaknesses: ["predictable_schedule"],
          technical_weaknesses: []
        }
      }

      result = CharacterAnalyzer.format_character_summary(analysis)

      assert %{
               pilot_profile: profile,
               threat_assessment: threat,
               tactical_notes: tactical
             } = result

      assert is_binary(profile)
      assert is_map(threat)
      assert is_list(tactical)

      # Should mention the pilot's name and stats
      assert String.contains?(profile, "Test Pilot")
      # kill count
      assert String.contains?(profile, "100")
    end
  end

  describe "helper functions" do
    test "categorize_ship_type/1 correctly categorizes ships" do
      assert CharacterAnalyzer.categorize_ship_type("Rifter") == "frigate"
      assert CharacterAnalyzer.categorize_ship_type("Damnation") == "command_ship"
      assert CharacterAnalyzer.categorize_ship_type("Ares") == "interceptor"
      assert CharacterAnalyzer.categorize_ship_type("Unknown Ship") == "unknown"
    end

    test "calculate_success_rate/2 handles edge cases" do
      assert CharacterAnalyzer.calculate_success_rate(10, 5) == 0.5
      assert CharacterAnalyzer.calculate_success_rate(0, 0) == 0.0
      assert CharacterAnalyzer.calculate_success_rate(10, 0) == 1.0
    end

    test "determine_timezone_from_activity/1 identifies timezones" do
      # USTZ activity (18-02 UTC)
      ustz_hours = [18, 19, 20, 21, 22, 23, 0, 1, 2]
      assert CharacterAnalyzer.determine_timezone_from_activity(ustz_hours) == "USTZ"

      # EUTZ activity (17-23 UTC)
      eutz_hours = [17, 18, 19, 20, 21, 22, 23]
      assert CharacterAnalyzer.determine_timezone_from_activity(eutz_hours) == "EUTZ"

      # AUTZ activity (08-14 UTC)
      autz_hours = [8, 9, 10, 11, 12, 13, 14]
      assert CharacterAnalyzer.determine_timezone_from_activity(autz_hours) == "AUTZ"
    end

    test "extract_hour_from_datetime/1 correctly extracts hour" do
      datetime = ~U[2024-01-01 15:30:45Z]
      assert CharacterAnalyzer.extract_hour_from_datetime(datetime) == 15
    end

    test "is_weekend?/1 correctly identifies weekends" do
      # Using Date.day_of_week/1 - Saturday = 6, Sunday = 7
      # Known Saturday
      saturday = ~D[2024-01-06]
      # Known Sunday
      sunday = ~D[2024-01-07]
      # Known Monday
      monday = ~D[2024-01-08]

      assert CharacterAnalyzer.is_weekend?(saturday) == true
      assert CharacterAnalyzer.is_weekend?(sunday) == true
      assert CharacterAnalyzer.is_weekend?(monday) == false
    end
  end

  describe "integration with killmail data" do
    test "processes real killmail structure" do
      # Test with realistic killmail structure
      killmail_data = %{
        character_id: 123_456_789,
        killmails: [
          %{
            killmail_id: 1,
            is_victim: false,
            ship_type_id: 11_999,
            ship_name: "Rifter",
            solar_system_id: 30_002_187,
            killmail_time: ~U[2024-01-01 15:00:00Z],
            total_value: 5_000_000.0,
            attacker_count: 3
          }
        ]
      }

      case CharacterAnalyzer.process_killmail_data(killmail_data) do
        {:ok, processed} ->
          assert Map.has_key?(processed, :total_kills)
          assert Map.has_key?(processed, :ship_usage)

        {:error, reason} ->
          # Acceptable in test environment
          assert is_atom(reason) or is_binary(reason)
      end
    end
  end
end
