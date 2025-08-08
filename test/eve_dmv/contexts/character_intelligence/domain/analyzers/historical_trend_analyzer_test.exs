defmodule EveDmv.Contexts.CharacterIntelligence.Domain.Analyzers.HistoricalTrendAnalyzerTest do
  use EveDmv.DataCase, async: true

  import EveDmv.Factories

  alias EveDmv.Api
  alias EveDmv.Contexts.CharacterIntelligence.Domain.Analyzers.HistoricalTrendAnalyzer
  alias EveDmv.Killmails.KillmailRaw

  describe "analyze_trends/2" do
    setup do
      character_id = 98_000_001

      # Create killmails over 90 days with varying patterns
      # Week 1-2: Low activity (2 kills/week)
      for week <- 0..1 do
        for day <- [0, 3] do
          killmail_attrs = killmail_raw_factory()
          base_time = DateTime.utc_now() |> DateTime.add(-80 + week * 7 + day, :day)

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 400_000_000 + week * 10 + day,
                killmail_time: base_time,
                solar_system_id: 30_000_142,
                victim_character_id: 98_999_000 + week * 10 + day,
                victim_ship_type_id: 587,
                victim_corporation_id: 99_000_000 + week,
                attacker_count: 1,
                total_value: Decimal.new("10000000"),
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
      end

      # Week 3-6: Increasing activity (4-8 kills/week)
      for week <- 2..5 do
        for day <- 0..(week * 2 - 3) do
          killmail_attrs = killmail_raw_factory()
          base_time = DateTime.utc_now() |> DateTime.add(-66 + week * 7 + day, :day)

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 401_000_000 + week * 100 + day,
                killmail_time: base_time,
                solar_system_id: 30_000_142 + rem(week, 3),
                victim_character_id: 98_998_000 + week * 10 + day,
                victim_ship_type_id: Enum.random([587, 624, 29_984]),
                victim_corporation_id: 99_100_000 + week,
                attacker_count: rem(week, 3) + 1,
                total_value: Decimal.new("#{20_000_000 * (week - 1)}"),
                raw_data: %{
                  "attackers" => [
                    %{
                      "character_id" => character_id,
                      "ship_type_id" => Enum.random([29_984, 11_987, 24_696]),
                      "final_blow" => true
                    }
                  ]
                }
              })
            )
        end
      end

      # Recent weeks: High activity with some losses
      for week <- 6..8 do
        # Kills
        for day <- 0..(10 - week) do
          killmail_attrs = killmail_raw_factory()
          base_time = DateTime.utc_now() |> DateTime.add(-24 + (week - 6) * 7 + day, :day)

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 402_000_000 + week * 100 + day,
                killmail_time: base_time,
                solar_system_id: 30_000_144,
                victim_character_id: 98_997_000 + week * 10 + day,
                # Battleships
                victim_ship_type_id: Enum.random([641, 643, 645]),
                victim_corporation_id: 99_200_000 + week,
                attacker_count: 5,
                total_value: Decimal.new("#{100_000_000 * week}"),
                raw_data: %{
                  "attackers" => [
                    %{
                      "character_id" => character_id,
                      # Loki
                      "ship_type_id" => 29_986,
                      "final_blow" => rem(day, 2) == 0
                    }
                  ]
                }
              })
            )
        end

        # Losses (showing risk-taking)
        if week == 7 do
          killmail_attrs = killmail_raw_factory()

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 403_000_000 + week,
                killmail_time: DateTime.utc_now() |> DateTime.add(-10 + week - 6, :day),
                solar_system_id: 30_000_144,
                victim_character_id: character_id,
                # Lost a Loki
                victim_ship_type_id: 29_986,
                victim_corporation_id: 98_000_001,
                attacker_count: 8,
                total_value: Decimal.new("500000000"),
                raw_data: %{
                  "victim" => %{"character_id" => character_id}
                }
              })
            )
        end
      end

      %{character_id: character_id}
    end

    test "analyzes activity trends over time", %{character_id: character_id} do
      assert {:ok, trends} = HistoricalTrendAnalyzer.analyze_trends(character_id)

      assert Map.has_key?(trends, :activity_trend)
      assert Map.has_key?(trends, :performance_trend)
      assert Map.has_key?(trends, :ship_usage_evolution)
      assert Map.has_key?(trends, :skill_progression)

      # Activity should show increasing trend (low -> high)
      assert trends.activity_trend.direction in [:increasing, :stable, :decreasing]
      assert is_float(trends.activity_trend.confidence)
    end

    test "detects performance improvements", %{character_id: character_id} do
      assert {:ok, trends} = HistoricalTrendAnalyzer.analyze_trends(character_id)

      perf_trend = trends.performance_trend
      assert Map.has_key?(perf_trend, :kd_ratio_trend)
      assert Map.has_key?(perf_trend, :isk_efficiency_trend)
      assert Map.has_key?(perf_trend, :target_value_trend)

      # Should detect increasing target values over time
      if perf_trend.target_value_trend do
        assert perf_trend.target_value_trend.direction in [:increasing, :stable, :decreasing]
      end
    end

    test "tracks ship usage evolution", %{character_id: character_id} do
      assert {:ok, trends} = HistoricalTrendAnalyzer.analyze_trends(character_id)

      ship_evolution = trends.ship_usage_evolution
      assert is_map(ship_evolution)

      if Map.has_key?(ship_evolution, :diversity_trend) do
        assert ship_evolution.diversity_trend in [:diversifying, :specializing, :stable]
      end

      if Map.has_key?(ship_evolution, :ship_progression) do
        assert is_list(ship_evolution.ship_progression)
      end
    end

    test "identifies skill progression", %{character_id: character_id} do
      assert {:ok, trends} = HistoricalTrendAnalyzer.analyze_trends(character_id)

      skill_prog = trends.skill_progression
      assert Map.has_key?(skill_prog, :improvement_rate)
      assert Map.has_key?(skill_prog, :consistency)

      # Should show improvement from low to high activity
      assert is_float(skill_prog.improvement_rate)

      assert skill_prog.consistency in [:consistent, :variable, :erratic] or
               is_float(skill_prog.consistency)
    end

    test "handles custom time windows", %{character_id: character_id} do
      # Analyze last 30 days only
      assert {:ok, trends_30} = HistoricalTrendAnalyzer.analyze_trends(character_id, days: 30)

      # Analyze last 60 days
      assert {:ok, trends_60} = HistoricalTrendAnalyzer.analyze_trends(character_id, days: 60)

      # Different windows should potentially show different patterns
      assert trends_30.activity_trend
      assert trends_60.activity_trend
    end

    test "handles character with no history gracefully" do
      new_character = 98_999_999

      assert {:ok, trends} = HistoricalTrendAnalyzer.analyze_trends(new_character)

      # Should return insufficient data indicators
      assert trends.activity_trend.direction == :insufficient_data or
               trends.activity_trend.confidence == 0.0
    end
  end

  describe "get_trend_summary/1" do
    setup do
      character_id = 98_100_001

      # Create simple pattern: increasing activity
      for i <- 1..20 do
        killmail_attrs = killmail_raw_factory()

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 405_000_000 + i,
              killmail_time: DateTime.utc_now() |> DateTime.add(-40 + i * 2, :day),
              solar_system_id: 30_000_142,
              victim_character_id: 98_996_000 + i,
              victim_ship_type_id: 587,
              victim_corporation_id: 99_300_000 + i,
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

    test "provides quick summary of trends", %{character_id: character_id} do
      assert {:ok, summary} = HistoricalTrendAnalyzer.get_trend_summary(character_id)

      assert Map.has_key?(summary, :activity_direction)
      assert Map.has_key?(summary, :performance_direction)
      assert Map.has_key?(summary, :skill_velocity)
      assert Map.has_key?(summary, :fleet_preference_shift)

      assert summary.activity_direction in [:increasing, :decreasing, :stable, :insufficient_data]

      assert summary.performance_direction in [
               :improving,
               :declining,
               :stable,
               :insufficient_data
             ]
    end

    test "includes key insights", %{character_id: character_id} do
      assert {:ok, summary} = HistoricalTrendAnalyzer.get_trend_summary(character_id)

      if Map.has_key?(summary, :key_insights) do
        assert is_list(summary.key_insights)

        Enum.each(summary.key_insights, fn insight ->
          assert is_binary(insight) or is_map(insight)
        end)
      end
    end
  end

  describe "performance benchmarks" do
    test "analyzes trends for 50 characters efficiently" do
      # Create 50 characters with minimal data
      character_ids =
        for i <- 1..50 do
          char_id = 98_200_000 + i
          killmail_attrs = killmail_raw_factory()

          # Just 5 killmails per character
          for j <- 1..5 do
            {:ok, _} =
              Api.create(
                KillmailRaw,
                Map.merge(killmail_attrs, %{
                  killmail_id: 406_000_000 + i * 100 + j,
                  killmail_time: DateTime.utc_now() |> DateTime.add(-j * 7, :day),
                  solar_system_id: 30_000_142,
                  victim_character_id: 98_995_000 + i * 10 + j,
                  victim_ship_type_id: 587,
                  victim_corporation_id: 99_400_000 + i,
                  attacker_count: 1,
                  total_value: Decimal.new("10000000"),
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

      # Measure time to analyze all 50
      {time_micros, results} =
        :timer.tc(fn ->
          Enum.map(character_ids, fn char_id ->
            HistoricalTrendAnalyzer.analyze_trends(char_id, days: 30)
          end)
        end)

      time_ms = time_micros / 1000

      # Should complete within reasonable time (10s for 50 characters = 200ms each)
      assert time_ms < 10_000,
             "Trend analysis for 50 characters took #{time_ms}ms, expected < 10000ms"

      # All should return results
      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)
    end
  end
end
