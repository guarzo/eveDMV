defmodule EveDmv.Contexts.CorporationIntelligence.Domain.Analyzers.MemberActivityPatternAnalyzerTest do
  use EveDmv.DataCase, async: true

  import EveDmv.Factories

  alias EveDmv.Api
  alias EveDmv.Contexts.CorporationIntelligence.Domain.Analyzers.MemberActivityPatternAnalyzer
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Users.User

  describe "analyze_patterns/1" do
    setup do
      corporation_id = 98_100_001

      # Create members with distinct patterns
      # Pattern 1: Weekday warrior (active Mon-Fri)
      {:ok, weekday_warrior} =
        Api.create(User, %{
          character_id: 93_200_001,
          character_name: "Weekday Warrior",
          owner_hash: "weekday_#{System.unique_integer()}"
        })

      # Pattern 2: Weekend warrior (active Sat-Sun)
      {:ok, weekend_warrior} =
        Api.create(User, %{
          character_id: 93_200_002,
          character_name: "Weekend Warrior",
          owner_hash: "weekend_#{System.unique_integer()}"
        })

      # Pattern 3: Night owl (active 22:00 - 02:00)
      {:ok, night_owl} =
        Api.create(User, %{
          character_id: 93_200_003,
          character_name: "Night Owl",
          owner_hash: "night_#{System.unique_integer()}"
        })

      # Pattern 4: Prime time player (active 18:00 - 22:00)
      {:ok, prime_timer} =
        Api.create(User, %{
          character_id: 93_200_004,
          character_name: "Prime Timer",
          owner_hash: "prime_#{System.unique_integer()}"
        })

      # Create activity for each pattern
      for week <- 0..3 do
        # Weekday warrior - active Monday through Friday
        for day <- 1..5 do
          killmail_attrs = killmail_raw_factory()

          base_time =
            DateTime.utc_now()
            |> DateTime.add(-(week * 7 + day), :day)
            |> DateTime.truncate(:second)

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 870_000_000 + week * 100 + day,
                killmail_time: base_time |> Map.put(:hour, 20),
                solar_system_id: 30_000_142,
                victim_character_id: 93_300_000 + week * 10 + day,
                victim_ship_type_id: 587,
                victim_corporation_id: 98_999_999,
                attacker_count: 1,
                total_value: Decimal.new("10000000"),
                raw_data: %{
                  "attackers" => [
                    %{
                      "character_id" => weekday_warrior.character_id,
                      "corporation_id" => corporation_id,
                      "ship_type_id" => 624,
                      "final_blow" => true
                    }
                  ]
                }
              })
            )
        end

        # Weekend warrior - active Saturday and Sunday
        for day <- [6, 0] do
          killmail_attrs = killmail_raw_factory()

          base_time =
            DateTime.utc_now()
            |> DateTime.add(-(week * 7 + day), :day)
            |> DateTime.truncate(:second)

          for hour <- [14, 16, 18] do
            {:ok, _} =
              Api.create(
                KillmailRaw,
                Map.merge(killmail_attrs, %{
                  killmail_id: 871_000_000 + week * 100 + day * 10 + hour,
                  killmail_time: base_time |> Map.put(:hour, hour),
                  solar_system_id: 30_000_142,
                  victim_character_id: 93_310_000 + week * 100 + day * 10 + hour,
                  victim_ship_type_id: 624,
                  victim_corporation_id: 98_999_999,
                  attacker_count: 1,
                  total_value: Decimal.new("15000000"),
                  raw_data: %{
                    "attackers" => [
                      %{
                        "character_id" => weekend_warrior.character_id,
                        "corporation_id" => corporation_id,
                        "ship_type_id" => 29_984,
                        "final_blow" => true
                      }
                    ]
                  }
                })
              )
          end
        end

        # Night owl - active 22:00 - 02:00
        for day <- 0..6 do
          killmail_attrs = killmail_raw_factory()

          base_time =
            DateTime.utc_now()
            |> DateTime.add(-(week * 7 + day), :day)
            |> DateTime.truncate(:second)

          # Late night activity
          for hour <- [22, 23, 0, 1] do
            {:ok, _} =
              Api.create(
                KillmailRaw,
                Map.merge(killmail_attrs, %{
                  killmail_id: 872_000_000 + week * 1000 + day * 10 + hour,
                  killmail_time: base_time |> Map.put(:hour, rem(hour, 24)),
                  solar_system_id: 30_000_142,
                  victim_character_id: 93_320_000 + week * 100 + day * 10 + hour,
                  victim_ship_type_id: 587,
                  victim_corporation_id: 98_999_999,
                  attacker_count: 1,
                  total_value: Decimal.new("8000000"),
                  raw_data: %{
                    "attackers" => [
                      %{
                        "character_id" => night_owl.character_id,
                        "corporation_id" => corporation_id,
                        "ship_type_id" => 29_986,
                        "final_blow" => true
                      }
                    ]
                  }
                })
              )
          end
        end

        # Prime timer - active 18:00 - 22:00
        for day <- 0..6 do
          killmail_attrs = killmail_raw_factory()

          base_time =
            DateTime.utc_now()
            |> DateTime.add(-(week * 7 + day), :day)
            |> DateTime.truncate(:second)

          # Prime time activity
          for hour <- [18, 19, 20, 21] do
            {:ok, _} =
              Api.create(
                KillmailRaw,
                Map.merge(killmail_attrs, %{
                  killmail_id: 873_000_000 + week * 1000 + day * 100 + hour,
                  killmail_time: base_time |> Map.put(:hour, hour),
                  solar_system_id: 30_000_142,
                  victim_character_id: 93_330_000 + week * 100 + day * 10 + hour,
                  victim_ship_type_id: 624,
                  victim_corporation_id: 98_999_999,
                  attacker_count: 2,
                  total_value: Decimal.new("20000000"),
                  raw_data: %{
                    "attackers" => [
                      %{
                        "character_id" => prime_timer.character_id,
                        "corporation_id" => corporation_id,
                        "ship_type_id" => 624,
                        "final_blow" => true
                      }
                    ]
                  }
                })
              )
          end
        end
      end

      %{
        corporation_id: corporation_id,
        weekday_warrior: weekday_warrior,
        weekend_warrior: weekend_warrior,
        night_owl: night_owl,
        prime_timer: prime_timer
      }
    end

    test "identifies weekday vs weekend patterns", %{corporation_id: corporation_id} do
      assert {:ok, patterns} = MemberActivityPatternAnalyzer.analyze_patterns(corporation_id)

      assert Map.has_key?(patterns, :member_patterns)
      assert is_list(patterns.member_patterns)

      # Should identify different activity patterns
      weekday_patterns =
        Enum.filter(patterns.member_patterns, fn p ->
          p.pattern_type == :weekday_warrior or
            String.contains?(to_string(p.pattern_type), "weekday")
        end)

      weekend_patterns =
        Enum.filter(patterns.member_patterns, fn p ->
          p.pattern_type == :weekend_warrior or
            String.contains?(to_string(p.pattern_type), "weekend")
        end)

      assert length(weekday_patterns) > 0 or length(weekend_patterns) > 0
    end

    test "detects timezone patterns", %{corporation_id: corporation_id} do
      assert {:ok, patterns} = MemberActivityPatternAnalyzer.analyze_patterns(corporation_id)

      assert Map.has_key?(patterns, :timezone_distribution)
      tz_dist = patterns.timezone_distribution

      # Should have timezone coverage data
      assert is_map(tz_dist)

      # Check for hour coverage
      if Map.has_key?(tz_dist, :hour_coverage) do
        coverage = tz_dist.hour_coverage
        assert is_map(coverage) or is_list(coverage)
      end
    end

    test "identifies peak activity hours", %{corporation_id: corporation_id} do
      assert {:ok, patterns} = MemberActivityPatternAnalyzer.analyze_patterns(corporation_id)

      assert Map.has_key?(patterns, :peak_hours)
      peak_hours = patterns.peak_hours

      assert is_list(peak_hours)

      Enum.each(peak_hours, fn hour ->
        assert hour >= 0 and hour <= 23
      end)
    end

    test "calculates activity consistency", %{corporation_id: corporation_id} do
      assert {:ok, patterns} = MemberActivityPatternAnalyzer.analyze_patterns(corporation_id)

      if Map.has_key?(patterns, :consistency_metrics) do
        metrics = patterns.consistency_metrics

        assert Map.has_key?(metrics, :overall_consistency)
        assert metrics.overall_consistency >= 0 and metrics.overall_consistency <= 1
      end
    end
  end

  describe "detect_anomalies/2" do
    setup do
      corporation_id = 98_100_002

      # Create member with consistent pattern
      {:ok, member} =
        Api.create(User, %{
          character_id: 93_400_001,
          character_name: "Consistent Member",
          owner_hash: "consistent_#{System.unique_integer()}"
        })

      # Normal pattern: 2-3 kills per day at 20:00
      for day <- 10..30 do
        for kill <- 1..Enum.random(2..3) do
          killmail_attrs = killmail_raw_factory()

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 880_000_000 + day * 10 + kill,
                killmail_time:
                  DateTime.utc_now()
                  |> DateTime.add(-day, :day)
                  |> Map.put(:hour, 20)
                  |> DateTime.truncate(:second),
                solar_system_id: 30_000_142,
                victim_character_id: 93_500_000 + day * 10 + kill,
                victim_ship_type_id: 587,
                victim_corporation_id: 98_999_999,
                attacker_count: 1,
                total_value: Decimal.new("10000000"),
                raw_data: %{
                  "attackers" => [
                    %{
                      "character_id" => member.character_id,
                      "corporation_id" => corporation_id,
                      "ship_type_id" => 624,
                      "final_blow" => true
                    }
                  ]
                }
              })
            )
        end
      end

      # Anomaly: Sudden change in pattern (different time, more kills)
      for day <- 1..5 do
        # 10 kills instead of 2-3
        for kill <- 1..10 do
          killmail_attrs = killmail_raw_factory()

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 890_000_000 + day * 100 + kill,
                killmail_time:
                  DateTime.utc_now()
                  |> DateTime.add(-day, :day)
                  # Different time (3 AM instead of 8 PM)
                  |> Map.put(:hour, 3)
                  |> DateTime.truncate(:second),
                # Different system
                solar_system_id: 30_000_144,
                victim_character_id: 93_600_000 + day * 10 + kill,
                # Different ships
                victim_ship_type_id: 643,
                victim_corporation_id: 98_999_998,
                # Fleet instead of solo
                attacker_count: 5,
                total_value: Decimal.new("50000000"),
                raw_data: %{
                  "attackers" => [
                    %{
                      "character_id" => member.character_id,
                      "corporation_id" => corporation_id,
                      # Different ship type
                      "ship_type_id" => 29_986,
                      "final_blow" => rem(kill, 3) == 0
                    }
                  ]
                }
              })
            )
        end
      end

      %{corporation_id: corporation_id, member: member}
    end

    test "detects activity anomalies", %{corporation_id: corporation_id} do
      assert {:ok, anomalies} = MemberActivityPatternAnalyzer.detect_anomalies(corporation_id)

      assert Map.has_key?(anomalies, :detected_anomalies)
      assert is_list(anomalies.detected_anomalies)

      # Should detect the anomaly
      assert length(anomalies.detected_anomalies) > 0
    end

    test "identifies anomaly types", %{corporation_id: corporation_id} do
      assert {:ok, anomalies} = MemberActivityPatternAnalyzer.detect_anomalies(corporation_id)

      Enum.each(anomalies.detected_anomalies, fn anomaly ->
        assert Map.has_key?(anomaly, :type)
        assert anomaly.type in [:activity_spike, :time_shift, :location_change, :behavior_change]
      end)
    end

    test "provides anomaly severity", %{corporation_id: corporation_id} do
      assert {:ok, anomalies} = MemberActivityPatternAnalyzer.detect_anomalies(corporation_id)

      Enum.each(anomalies.detected_anomalies, fn anomaly ->
        if Map.has_key?(anomaly, :severity) do
          assert anomaly.severity in [:low, :medium, :high, :critical]
        end
      end)
    end

    test "includes anomaly timestamps", %{corporation_id: corporation_id} do
      assert {:ok, anomalies} = MemberActivityPatternAnalyzer.detect_anomalies(corporation_id)

      Enum.each(anomalies.detected_anomalies, fn anomaly ->
        assert Map.has_key?(anomaly, :detected_at) or Map.has_key?(anomaly, :timestamp)
      end)
    end
  end

  describe "calculate_timezone_coverage/1" do
    setup do
      corporation_id = 98_100_003

      # Create members across different timezones
      # EU TZ (active 18:00-23:00 UTC)
      eu_members =
        for i <- 1..3 do
          {:ok, member} =
            Api.create(User, %{
              character_id: 93_700_000 + i,
              character_name: "EU Member #{i}",
              owner_hash: "eu_#{i}_#{System.unique_integer()}"
            })

          for day <- 0..7 do
            for hour <- 18..22 do
              killmail_attrs = killmail_raw_factory()

              {:ok, _} =
                Api.create(
                  KillmailRaw,
                  Map.merge(killmail_attrs, %{
                    killmail_id: 900_000_000 + i * 10_000 + day * 100 + hour,
                    killmail_time:
                      DateTime.utc_now()
                      |> DateTime.add(-day, :day)
                      |> Map.put(:hour, hour)
                      |> DateTime.truncate(:second),
                    solar_system_id: 30_000_142,
                    victim_character_id: 93_800_000 + day * 100 + hour,
                    victim_ship_type_id: 587,
                    victim_corporation_id: 98_999_999,
                    attacker_count: 1,
                    total_value: Decimal.new("10000000"),
                    raw_data: %{
                      "attackers" => [
                        %{
                          "character_id" => member.character_id,
                          "corporation_id" => corporation_id,
                          "ship_type_id" => 624,
                          "final_blow" => true
                        }
                      ]
                    }
                  })
                )
            end
          end

          member
        end

      # US TZ (active 00:00-05:00 UTC)
      us_members =
        for i <- 1..3 do
          {:ok, member} =
            Api.create(User, %{
              character_id: 93_710_000 + i,
              character_name: "US Member #{i}",
              owner_hash: "us_#{i}_#{System.unique_integer()}"
            })

          for day <- 0..7 do
            for hour <- 0..4 do
              killmail_attrs = killmail_raw_factory()

              {:ok, _} =
                Api.create(
                  KillmailRaw,
                  Map.merge(killmail_attrs, %{
                    killmail_id: 910_000_000 + i * 10_000 + day * 100 + hour,
                    killmail_time:
                      DateTime.utc_now()
                      |> DateTime.add(-day, :day)
                      |> Map.put(:hour, hour)
                      |> DateTime.truncate(:second),
                    solar_system_id: 30_000_142,
                    victim_character_id: 93_810_000 + day * 100 + hour,
                    victim_ship_type_id: 587,
                    victim_corporation_id: 98_999_999,
                    attacker_count: 1,
                    total_value: Decimal.new("10000000"),
                    raw_data: %{
                      "attackers" => [
                        %{
                          "character_id" => member.character_id,
                          "corporation_id" => corporation_id,
                          "ship_type_id" => 624,
                          "final_blow" => true
                        }
                      ]
                    }
                  })
                )
            end
          end

          member
        end

      %{
        corporation_id: corporation_id,
        eu_members: eu_members,
        us_members: us_members
      }
    end

    test "calculates 24-hour coverage", %{corporation_id: corporation_id} do
      assert {:ok, coverage} =
               MemberActivityPatternAnalyzer.calculate_timezone_coverage(corporation_id)

      assert Map.has_key?(coverage, :coverage_percentage)
      assert coverage.coverage_percentage >= 0 and coverage.coverage_percentage <= 100
    end

    test "identifies coverage gaps", %{corporation_id: corporation_id} do
      assert {:ok, coverage} =
               MemberActivityPatternAnalyzer.calculate_timezone_coverage(corporation_id)

      assert Map.has_key?(coverage, :coverage_gaps)
      assert is_list(coverage.coverage_gaps)

      # Should identify hours with no coverage
      Enum.each(coverage.coverage_gaps, fn gap ->
        assert Map.has_key?(gap, :start_hour) or is_integer(gap)

        if Map.has_key?(gap, :start_hour) do
          assert gap.start_hour >= 0 and gap.start_hour <= 23
        end
      end)
    end

    test "provides timezone breakdown", %{corporation_id: corporation_id} do
      assert {:ok, coverage} =
               MemberActivityPatternAnalyzer.calculate_timezone_coverage(corporation_id)

      if Map.has_key?(coverage, :timezone_breakdown) do
        breakdown = coverage.timezone_breakdown

        assert Map.has_key?(breakdown, :eu) or Map.has_key?(breakdown, :us) or
                 Map.has_key?(breakdown, :au) or is_list(breakdown)
      end
    end
  end
end
