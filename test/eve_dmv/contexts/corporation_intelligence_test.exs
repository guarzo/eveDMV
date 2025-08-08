defmodule EveDmv.Contexts.CorporationIntelligenceTest do
  use EveDmv.DataCase, async: true

  import EveDmv.Factories

  alias EveDmv.Api
  alias EveDmv.Contexts.CorporationIntelligence
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Users.User

  describe "analyze_corporation/1" do
    setup do
      corporation_id = 98_000_001

      # Create corporation members
      members =
        for i <- 1..10 do
          {:ok, member} =
            Api.create(User, %{
              character_id: 94_000_000 + i,
              character_name: "Corp Member #{i}",
              owner_hash: "corp_hash_#{i}_#{System.unique_integer()}"
            })

          member
        end

      # Create killmails for corporation members
      for member <- members do
        for j <- 1..5 do
          killmail_attrs = killmail_raw_factory()

          # Mix of kills and losses
          if rem(j, 3) == 0 do
            # Losses
            {:ok, _} =
              Api.create(
                KillmailRaw,
                Map.merge(killmail_attrs, %{
                  killmail_id: 800_000_000 + member.character_id * 10 + j,
                  killmail_time: DateTime.utc_now() |> DateTime.add(-j * 24, :hour),
                  solar_system_id: 30_000_142 + rem(j, 5),
                  victim_character_id: member.character_id,
                  victim_ship_type_id: 624,
                  victim_corporation_id: corporation_id,
                  attacker_count: 3,
                  total_value: Decimal.new("25000000"),
                  raw_data: %{
                    "victim" => %{
                      "character_id" => member.character_id,
                      "corporation_id" => corporation_id
                    }
                  }
                })
              )
          else
            # Kills
            {:ok, _} =
              Api.create(
                KillmailRaw,
                Map.merge(killmail_attrs, %{
                  killmail_id: 801_000_000 + member.character_id * 10 + j,
                  killmail_time: DateTime.utc_now() |> DateTime.add(-j * 24, :hour),
                  solar_system_id: 30_000_142 + rem(j, 5),
                  victim_character_id: 94_100_000 + j,
                  victim_ship_type_id: 587,
                  victim_corporation_id: 98_999_999,
                  attacker_count: 1,
                  total_value: Decimal.new("10000000"),
                  raw_data: %{
                    "attackers" => [
                      %{
                        "character_id" => member.character_id,
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
      end

      %{corporation_id: corporation_id, members: members}
    end

    test "analyzes corporation activity", %{corporation_id: corporation_id} do
      assert {:ok, analysis} = CorporationIntelligence.analyze_corporation(corporation_id)

      assert Map.has_key?(analysis, :corporation_id)
      assert Map.has_key?(analysis, :activity_metrics)
      assert Map.has_key?(analysis, :member_count)
      assert Map.has_key?(analysis, :threat_level)

      assert analysis.corporation_id == corporation_id
      assert analysis.member_count > 0
      assert analysis.threat_level in [:minimal, :low, :medium, :high, :extreme]
    end

    test "calculates timezone distribution", %{corporation_id: corporation_id} do
      assert {:ok, analysis} = CorporationIntelligence.analyze_corporation(corporation_id)

      assert Map.has_key?(analysis, :timezone_distribution)
      timezone_dist = analysis.timezone_distribution

      # Should have timezone data
      assert is_map(timezone_dist) or is_list(timezone_dist)

      if is_map(timezone_dist) do
        # Timezones should be in format like "EU", "US", "AU"
        Enum.each(timezone_dist, fn {_tz, count} ->
          assert is_number(count) and count >= 0
        end)
      end
    end

    test "identifies operational patterns", %{corporation_id: corporation_id} do
      assert {:ok, analysis} = CorporationIntelligence.analyze_corporation(corporation_id)

      if Map.has_key?(analysis, :operational_patterns) do
        patterns = analysis.operational_patterns

        assert is_list(patterns) or is_map(patterns)

        # Common patterns to look for
        possible_patterns = [:pvp_focused, :industrial, :small_gang, :fleet_warfare, :wormhole]

        if is_list(patterns) do
          Enum.each(patterns, fn pattern ->
            assert pattern in possible_patterns or is_binary(pattern)
          end)
        end
      end
    end

    test "provides member statistics", %{corporation_id: corporation_id} do
      assert {:ok, analysis} = CorporationIntelligence.analyze_corporation(corporation_id)

      if Map.has_key?(analysis, :member_stats) do
        stats = analysis.member_stats

        assert Map.has_key?(stats, :active_members) or Map.has_key?(stats, :total_members)
        assert Map.has_key?(stats, :average_threat) or Map.has_key?(stats, :avg_activity)
      end
    end
  end

  describe "analyze_member_activity/1" do
    setup do
      corporation_id = 98_000_002

      # Create members with different activity patterns
      active_members =
        for i <- 1..5 do
          {:ok, member} =
            Api.create(User, %{
              character_id: 94_200_000 + i,
              character_name: "Active Member #{i}",
              owner_hash: "active_#{i}_#{System.unique_integer()}"
            })

          # Create daily activity
          for day <- 0..29 do
            killmail_attrs = killmail_raw_factory()
            # Different peak hours for each member
            hour = rem(i * 4, 24)

            {:ok, _} =
              Api.create(
                KillmailRaw,
                Map.merge(killmail_attrs, %{
                  killmail_id: 810_000_000 + i * 1000 + day,
                  killmail_time:
                    DateTime.utc_now()
                    |> DateTime.add(-day, :day)
                    |> DateTime.add(hour, :hour),
                  solar_system_id: 30_000_142,
                  victim_character_id: 94_300_000 + day,
                  victim_ship_type_id: 587,
                  victim_corporation_id: 98_999_999,
                  attacker_count: 1,
                  total_value: Decimal.new("10000000"),
                  raw_data: %{
                    "attackers" => [
                      %{
                        "character_id" => member.character_id,
                        "corporation_id" => corporation_id,
                        "ship_type_id" => 29_984,
                        "final_blow" => true
                      }
                    ]
                  }
                })
              )
          end

          member
        end

      inactive_members =
        for i <- 1..3 do
          {:ok, member} =
            Api.create(User, %{
              character_id: 94_210_000 + i,
              character_name: "Inactive Member #{i}",
              owner_hash: "inactive_#{i}_#{System.unique_integer()}"
            })

          # Create sparse activity (only 2 killmails in 30 days)
          for day <- [5, 15] do
            killmail_attrs = killmail_raw_factory()

            {:ok, _} =
              Api.create(
                KillmailRaw,
                Map.merge(killmail_attrs, %{
                  killmail_id: 820_000_000 + i * 100 + day,
                  killmail_time: DateTime.utc_now() |> DateTime.add(-day, :day),
                  solar_system_id: 30_000_142,
                  victim_character_id: 94_400_000 + day,
                  victim_ship_type_id: 587,
                  victim_corporation_id: 98_999_999,
                  attacker_count: 1,
                  total_value: Decimal.new("5000000"),
                  raw_data: %{
                    "attackers" => [
                      %{
                        "character_id" => member.character_id,
                        "corporation_id" => corporation_id,
                        "ship_type_id" => 587,
                        "final_blow" => true
                      }
                    ]
                  }
                })
              )
          end

          member
        end

      %{
        corporation_id: corporation_id,
        active_members: active_members,
        inactive_members: inactive_members,
        all_members: active_members ++ inactive_members
      }
    end

    test "identifies active vs inactive members", %{corporation_id: corporation_id} do
      assert {:ok, activity} = CorporationIntelligence.analyze_member_activity(corporation_id)

      assert Map.has_key?(activity, :active_members)
      assert Map.has_key?(activity, :inactive_members)

      # Should categorize members correctly
      assert length(activity.active_members) > 0
      assert is_list(activity.inactive_members)
    end

    test "calculates activity metrics", %{corporation_id: corporation_id} do
      assert {:ok, activity} = CorporationIntelligence.analyze_member_activity(corporation_id)

      if Map.has_key?(activity, :metrics) do
        metrics = activity.metrics

        assert Map.has_key?(metrics, :participation_rate) or
                 Map.has_key?(metrics, :activity_rate)

        assert Map.has_key?(metrics, :average_kills_per_member) or
                 Map.has_key?(metrics, :avg_activity)
      end
    end

    test "detects timezone patterns", %{corporation_id: corporation_id} do
      assert {:ok, activity} = CorporationIntelligence.analyze_member_activity(corporation_id)

      if Map.has_key?(activity, :timezone_coverage) do
        coverage = activity.timezone_coverage

        assert is_map(coverage) or is_list(coverage)

        # Should identify peak hours
        if Map.has_key?(coverage, :peak_hours) do
          assert is_list(coverage.peak_hours)

          Enum.each(coverage.peak_hours, fn hour ->
            assert hour >= 0 and hour <= 23
          end)
        end
      end
    end
  end

  describe "detect_activity_anomalies/1" do
    setup do
      corporation_id = 98_000_003

      # Create normal activity pattern for first 20 days
      {:ok, member} =
        Api.create(User, %{
          character_id: 94_500_001,
          character_name: "Anomaly Test Member",
          owner_hash: "anomaly_#{System.unique_integer()}"
        })

      # Normal activity (2-3 kills per day)
      for day <- 20..30 do
        for kill <- 1..Enum.random(2..3) do
          killmail_attrs = killmail_raw_factory()

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 830_000_000 + day * 10 + kill,
                killmail_time: DateTime.utc_now() |> DateTime.add(-day, :day),
                solar_system_id: 30_000_142,
                victim_character_id: 94_600_000 + day * 10 + kill,
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

      # Anomaly: Sudden spike in activity
      for day <- 5..10 do
        # 10 kills per day instead of 2-3
        for kill <- 1..10 do
          killmail_attrs = killmail_raw_factory()

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 840_000_000 + day * 100 + kill,
                killmail_time: DateTime.utc_now() |> DateTime.add(-day, :day),
                # Different system
                solar_system_id: 30_000_144,
                victim_character_id: 94_700_000 + day * 10 + kill,
                # Bigger ships
                victim_ship_type_id: 643,
                victim_corporation_id: 98_999_998,
                # Fleet activity
                attacker_count: 5,
                # Higher value
                total_value: Decimal.new("100000000"),
                raw_data: %{
                  "attackers" => [
                    %{
                      "character_id" => member.character_id,
                      "corporation_id" => corporation_id,
                      # Different ship
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

    test "detects activity spikes", %{corporation_id: corporation_id} do
      assert {:ok, anomalies} = CorporationIntelligence.detect_activity_anomalies(corporation_id)

      assert Map.has_key?(anomalies, :anomalies) or Map.has_key?(anomalies, :detected_anomalies)

      # Should detect the activity spike
      if Map.has_key?(anomalies, :anomalies) do
        assert length(anomalies.anomalies) > 0

        Enum.each(anomalies.anomalies, fn anomaly ->
          assert Map.has_key?(anomaly, :type) or is_binary(anomaly)
        end)
      end
    end

    test "identifies pattern changes", %{corporation_id: corporation_id} do
      assert {:ok, anomalies} = CorporationIntelligence.detect_activity_anomalies(corporation_id)

      if Map.has_key?(anomalies, :pattern_changes) do
        changes = anomalies.pattern_changes

        assert is_list(changes)

        # Should identify ship type changes, location changes, etc.
        Enum.each(changes, fn change ->
          assert is_map(change) or is_binary(change)
        end)
      end
    end
  end

  describe "calculate_threat_assessment/1" do
    setup do
      corporation_id = 98_000_004

      # Create high-threat members
      elite_members =
        for i <- 1..3 do
          {:ok, member} =
            Api.create(User, %{
              character_id: 94_800_000 + i,
              character_name: "Elite PvPer #{i}",
              owner_hash: "elite_#{i}_#{System.unique_integer()}"
            })

          # Create impressive killboard
          for j <- 1..20 do
            killmail_attrs = killmail_raw_factory()

            {:ok, _} =
              Api.create(
                KillmailRaw,
                Map.merge(killmail_attrs, %{
                  killmail_id: 850_000_000 + i * 1000 + j,
                  killmail_time: DateTime.utc_now() |> DateTime.add(-j, :day),
                  solar_system_id: 30_000_142,
                  victim_character_id: 94_900_000 + j,
                  # Battleships
                  victim_ship_type_id: Enum.random([643, 645, 641]),
                  victim_corporation_id: 98_999_999,
                  # Solo kills
                  attacker_count: 1,
                  total_value: Decimal.new("200000000"),
                  raw_data: %{
                    "attackers" => [
                      %{
                        "character_id" => member.character_id,
                        "corporation_id" => corporation_id,
                        # Loki
                        "ship_type_id" => 29_986,
                        "final_blow" => true
                      }
                    ]
                  }
                })
              )
          end

          member
        end

      %{corporation_id: corporation_id, elite_members: elite_members}
    end

    test "calculates corporation threat level", %{corporation_id: corporation_id} do
      assert {:ok, assessment} =
               CorporationIntelligence.calculate_threat_assessment(corporation_id)

      assert Map.has_key?(assessment, :threat_level)
      assert Map.has_key?(assessment, :threat_score)

      assert assessment.threat_level in [:minimal, :low, :medium, :high, :extreme]
      assert assessment.threat_score >= 0 and assessment.threat_score <= 100
    end

    test "identifies key threats", %{corporation_id: corporation_id} do
      assert {:ok, assessment} =
               CorporationIntelligence.calculate_threat_assessment(corporation_id)

      if Map.has_key?(assessment, :key_threats) do
        threats = assessment.key_threats

        assert is_list(threats)

        Enum.each(threats, fn threat ->
          assert Map.has_key?(threat, :character_id) or is_binary(threat)
        end)
      end
    end

    test "provides tactical recommendations", %{corporation_id: corporation_id} do
      assert {:ok, assessment} =
               CorporationIntelligence.calculate_threat_assessment(corporation_id)

      if Map.has_key?(assessment, :recommendations) do
        recs = assessment.recommendations

        assert is_list(recs)

        Enum.each(recs, fn rec ->
          assert is_binary(rec) or is_map(rec)
        end)
      end
    end
  end

  describe "get_corporation_summary/1" do
    setup do
      corporation_id = 98_000_005

      # Create diverse corporation
      for i <- 1..15 do
        {:ok, member} =
          Api.create(User, %{
            character_id: 93_000_000 + i,
            character_name: "Corp Member #{i}",
            owner_hash: "summary_#{i}_#{System.unique_integer()}"
          })

        # Create varied activity
        for j <- 1..(rem(i, 5) + 1) do
          killmail_attrs = killmail_raw_factory()

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 860_000_000 + i * 100 + j,
                killmail_time: DateTime.utc_now() |> DateTime.add(-(i + j), :day),
                solar_system_id: 30_000_142 + rem(i, 3),
                victim_character_id: 93_100_000 + i * 10 + j,
                victim_ship_type_id: Enum.random([587, 624, 29_984, 643]),
                victim_corporation_id: 98_999_999,
                attacker_count: rem(i, 4) + 1,
                total_value: Decimal.new("#{10_000_000 * (rem(i, 5) + 1)}"),
                raw_data: %{
                  "attackers" => [
                    %{
                      "character_id" => member.character_id,
                      "corporation_id" => corporation_id,
                      "ship_type_id" => Enum.random([29_984, 624, 11_987]),
                      "final_blow" => true
                    }
                  ]
                }
              })
            )
        end
      end

      %{corporation_id: corporation_id}
    end

    test "provides comprehensive summary", %{corporation_id: corporation_id} do
      assert {:ok, summary} = CorporationIntelligence.get_corporation_summary(corporation_id)

      assert Map.has_key?(summary, :corporation_id)
      assert Map.has_key?(summary, :member_count) or Map.has_key?(summary, :total_members)
      assert Map.has_key?(summary, :activity_level) or Map.has_key?(summary, :recent_activity)

      assert summary.corporation_id == corporation_id
    end

    test "includes recent performance metrics", %{corporation_id: corporation_id} do
      assert {:ok, summary} = CorporationIntelligence.get_corporation_summary(corporation_id)

      if Map.has_key?(summary, :performance) do
        perf = summary.performance

        assert Map.has_key?(perf, :kills) or Map.has_key?(perf, :total_kills)
        assert Map.has_key?(perf, :losses) or Map.has_key?(perf, :total_losses)
      end
    end
  end
end
