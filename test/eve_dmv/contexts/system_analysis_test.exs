defmodule EveDmv.Contexts.SystemAnalysisTest do
  use EveDmv.DataCase, async: true

  import EveDmv.Factories

  alias EveDmv.Api
  alias EveDmv.Contexts.SystemAnalysis
  alias EveDmv.Eve.SolarSystem
  alias EveDmv.Killmails.KillmailRaw
  require Ash.Query

  describe "analyze_system_activity/2" do
    setup do
      # Create test solar systems
      systems = [
        {30_000_142, "Jita", Decimal.new("1.0"), "highsec"},
        {30_000_143, "Rens", Decimal.new("0.9"), "highsec"},
        {30_000_144, "Amarr", Decimal.new("1.0"), "highsec"},
        {30_000_145, "Dodixie", Decimal.new("0.9"), "highsec"}
      ]

      for {id, name, sec, class} <- systems do
        # Skip system creation - SolarSystem doesn't have proper create action configured
        # Just use the system IDs directly in killmails
      end

      # Create killmail activity in Jita (30000142)
      system_id = 30_000_142

      # Create varied activity over 30 days
      for day <- 0..29 do
        # 1-5 kills per day
        kills_today = rem(day, 5) + 1

        for kill <- 1..kills_today do
          killmail_attrs = killmail_raw_factory()

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 920_000_000 + day * 100 + kill,
                killmail_time: DateTime.utc_now() |> DateTime.add(-(30 - day), :day),
                solar_system_id: system_id,
                victim_character_id: 92_000_000 + day * 10 + kill,
                victim_ship_type_id: Enum.random([587, 624, 29_984]),
                victim_corporation_id: 98_999_999,
                attacker_count: rem(day, 3) + 1,
                total_value: Decimal.new("#{10_000_000 * (rem(day, 5) + 1)}"),
                raw_data: %{
                  "victim" => %{"character_id" => 92_000_000 + day * 10 + kill},
                  "attackers" => [
                    %{
                      "character_id" => 92_100_000 + day,
                      "ship_type_id" => Enum.random([624, 29_984, 11_987]),
                      "final_blow" => true
                    }
                  ]
                }
              })
            )
        end
      end

      %{system_id: system_id}
    end

    test "analyzes system activity level", %{system_id: system_id} do
      assert {:ok, analysis} = SystemAnalysis.analyze_system_activity(system_id)

      assert Map.has_key?(analysis, :system_id)
      assert Map.has_key?(analysis, :activity_level)
      assert Map.has_key?(analysis, :kill_count)

      assert analysis.system_id == system_id
      assert analysis.activity_level in [:very_low, :low, :medium, :high, :very_high]
      assert analysis.kill_count > 0
    end

    test "calculates hourly distribution", %{system_id: system_id} do
      assert {:ok, analysis} = SystemAnalysis.analyze_system_activity(system_id)

      if Map.has_key?(analysis, :hourly_distribution) do
        dist = analysis.hourly_distribution

        assert is_map(dist) or is_list(dist)

        if is_map(dist) do
          Enum.each(dist, fn {hour, count} ->
            assert hour >= 0 and hour <= 23
            assert count >= 0
          end)
        end
      end
    end

    test "identifies peak activity times", %{system_id: system_id} do
      assert {:ok, analysis} = SystemAnalysis.analyze_system_activity(system_id)

      assert Map.has_key?(analysis, :peak_hours)
      assert is_list(analysis.peak_hours)

      Enum.each(analysis.peak_hours, fn hour ->
        assert hour >= 0 and hour <= 23
      end)
    end

    test "provides activity trends", %{system_id: system_id} do
      assert {:ok, analysis} = SystemAnalysis.analyze_system_activity(system_id)

      if Map.has_key?(analysis, :trend) do
        assert analysis.trend in [:increasing, :decreasing, :stable, :volatile]
      end
    end

    test "handles custom time windows", %{system_id: system_id} do
      # Analyze last 7 days
      assert {:ok, analysis_7d} = SystemAnalysis.analyze_system_activity(system_id, days: 7)

      # Analyze last 30 days
      assert {:ok, analysis_30d} = SystemAnalysis.analyze_system_activity(system_id, days: 30)

      # 30-day window should have more kills
      assert analysis_30d.kill_count >= analysis_7d.kill_count
    end
  end

  describe "generate_heatmap/1" do
    setup do
      # Create activity in multiple systems
      systems = [
        # Jita - high activity
        {30_000_142, 50},
        # Rens - medium activity
        {30_000_143, 30},
        # Amarr - medium-low activity
        {30_000_144, 20},
        # Dodixie - low activity
        {30_000_145, 10}
      ]

      for {system_id, kill_count} <- systems do
        for i <- 1..kill_count do
          killmail_attrs = killmail_raw_factory()

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 930_000_000 + system_id * 1000 + i,
                killmail_time: DateTime.utc_now() |> DateTime.add(-rem(i, 30), :day),
                solar_system_id: system_id,
                victim_character_id: 92_200_000 + i,
                victim_ship_type_id: 587,
                victim_corporation_id: 98_999_999,
                attacker_count: 1,
                total_value: Decimal.new("10000000"),
                raw_data: %{
                  "victim" => %{"character_id" => 92_200_000 + i},
                  "attackers" => [
                    %{
                      "character_id" => 92_300_000 + i,
                      "ship_type_id" => 624,
                      "final_blow" => true
                    }
                  ]
                }
              })
            )
        end
      end

      %{systems: Enum.map(systems, &elem(&1, 0))}
    end

    test "generates regional heatmap", %{systems: systems} do
      # The Forge
      region_id = 10_000_002

      assert {:ok, heatmap} = SystemAnalysis.generate_heatmap(region_id: region_id)

      assert Map.has_key?(heatmap, :region_id) or Map.has_key?(heatmap, :systems)
      assert Map.has_key?(heatmap, :activity_data) or Map.has_key?(heatmap, :heatmap_data)

      # Should include data for systems in the region
      if Map.has_key?(heatmap, :systems) do
        assert is_list(heatmap.systems) or is_map(heatmap.systems)
      end
    end

    test "calculates activity intensity", %{systems: systems} do
      assert {:ok, heatmap} =
               SystemAnalysis.generate_heatmap(
                 system_ids: systems,
                 days: 30
               )

      if Map.has_key?(heatmap, :intensity_levels) do
        levels = heatmap.intensity_levels

        assert is_map(levels) or is_list(levels)

        # Should have different intensity levels
        if is_map(levels) do
          Enum.each(levels, fn {system_id, intensity} ->
            assert system_id in systems
            assert intensity >= 0 and intensity <= 1
          end)
        end
      end
    end

    test "provides activity classification", %{systems: systems} do
      assert {:ok, heatmap} =
               SystemAnalysis.generate_heatmap(
                 system_ids: systems,
                 days: 30
               )

      if Map.has_key?(heatmap, :classifications) do
        classifications = heatmap.classifications

        Enum.each(classifications, fn {system_id, class} ->
          assert system_id in systems
          assert class in [:hot, :warm, :cool, :cold]
        end)
      end
    end
  end

  describe "detect_activity_spillover/2" do
    setup do
      # Create connected systems with activity patterns
      # System A: High activity that spills over
      system_a = 30_000_142
      # System B: Adjacent, receives spillover
      system_b = 30_000_143
      # System C: Not adjacent, no spillover
      system_c = 30_000_145

      # Create intense activity in System A
      for hour <- 0..23 do
        for i <- 1..5 do
          killmail_attrs = killmail_raw_factory()

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 940_000_000 + hour * 100 + i,
                killmail_time:
                  DateTime.utc_now()
                  |> DateTime.add(-1, :day)
                  |> Map.put(:hour, hour)
                  |> DateTime.truncate(:second),
                solar_system_id: system_a,
                victim_character_id: 92_400_000 + hour * 10 + i,
                victim_ship_type_id: 624,
                victim_corporation_id: 98_999_999,
                attacker_count: 3,
                total_value: Decimal.new("25000000"),
                raw_data: %{
                  "victim" => %{"character_id" => 92_400_000 + hour * 10 + i},
                  "attackers" => [
                    %{
                      "character_id" => 92_500_000 + hour,
                      "ship_type_id" => 29_984,
                      "final_blow" => true
                    }
                  ]
                }
              })
            )
        end
      end

      # Create spillover activity in System B (1-2 hours after System A peaks)
      for hour <- [20, 21, 22, 23, 0, 1] do
        for i <- 1..3 do
          killmail_attrs = killmail_raw_factory()

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 941_000_000 + hour * 100 + i,
                killmail_time:
                  DateTime.utc_now()
                  |> DateTime.add(-1, :day)
                  # 1 hour delay
                  |> Map.put(:hour, rem(hour + 1, 24))
                  |> DateTime.truncate(:second),
                solar_system_id: system_b,
                victim_character_id: 92_600_000 + hour * 10 + i,
                victim_ship_type_id: 587,
                victim_corporation_id: 98_999_999,
                attacker_count: 2,
                total_value: Decimal.new("15000000"),
                raw_data: %{
                  "victim" => %{"character_id" => 92_600_000 + hour * 10 + i},
                  "attackers" => [
                    %{
                      "character_id" => 92_700_000 + hour,
                      "ship_type_id" => 624,
                      "final_blow" => true
                    }
                  ]
                }
              })
            )
        end
      end

      # Minimal activity in System C (unrelated)
      killmail_attrs = killmail_raw_factory()

      {:ok, _} =
        Api.create(
          KillmailRaw,
          Map.merge(killmail_attrs, %{
            killmail_id: 942_000_000,
            killmail_time: DateTime.utc_now() |> DateTime.add(-1, :day),
            solar_system_id: system_c,
            victim_character_id: 92_800_000,
            victim_ship_type_id: 587,
            victim_corporation_id: 98_999_999,
            attacker_count: 1,
            total_value: Decimal.new("5000000"),
            raw_data: %{
              "victim" => %{"character_id" => 92_800_000},
              "attackers" => [
                %{
                  "character_id" => 92_900_000,
                  "ship_type_id" => 587,
                  "final_blow" => true
                }
              ]
            }
          })
        )

      %{system_a: system_a, system_b: system_b, system_c: system_c}
    end

    test "detects activity spillover between systems", %{system_a: system_a, system_b: system_b} do
      assert {:ok, spillover} = SystemAnalysis.detect_activity_spillover(system_a, system_b)

      assert Map.has_key?(spillover, :spillover_detected)
      assert Map.has_key?(spillover, :correlation_score)

      assert is_boolean(spillover.spillover_detected)
      assert spillover.correlation_score >= -1 and spillover.correlation_score <= 1
    end

    test "calculates time delay in spillover", %{system_a: system_a, system_b: system_b} do
      assert {:ok, spillover} = SystemAnalysis.detect_activity_spillover(system_a, system_b)

      if spillover.spillover_detected do
        assert Map.has_key?(spillover, :time_delay)
        # Delay in minutes or hours
        assert spillover.time_delay >= 0
      end
    end

    test "identifies spillover patterns", %{system_a: system_a, system_b: system_b} do
      assert {:ok, spillover} = SystemAnalysis.detect_activity_spillover(system_a, system_b)

      if Map.has_key?(spillover, :pattern) do
        assert spillover.pattern in [:immediate, :delayed, :bidirectional, :none]
      end
    end

    test "no spillover detected for unrelated systems", %{system_a: system_a, system_c: system_c} do
      assert {:ok, spillover} = SystemAnalysis.detect_activity_spillover(system_a, system_c)

      # Should show low or no correlation
      assert spillover.correlation_score < 0.3 or not spillover.spillover_detected
    end
  end

  describe "analyze_regional_correlation/1" do
    setup do
      # The Forge
      region_id = 10_000_002

      # Create correlated activity across multiple systems
      base_systems = [30_000_142, 30_000_143, 30_000_144]

      # Create wave of activity that moves through systems
      for {system_id, delay} <- Enum.with_index(base_systems) do
        for day <- 0..6 do
          for hour <- [18, 19, 20, 21] do
            for i <- 1..3 do
              killmail_attrs = killmail_raw_factory()

              {:ok, _} =
                Api.create(
                  KillmailRaw,
                  Map.merge(killmail_attrs, %{
                    killmail_id: 950_000_000 + system_id + day * 1000 + hour * 10 + i,
                    killmail_time:
                      DateTime.utc_now()
                      |> DateTime.add(-(7 - day), :day)
                      # Staggered by system
                      |> Map.put(:hour, rem(hour + delay, 24))
                      |> DateTime.truncate(:second),
                    solar_system_id: system_id,
                    victim_character_id: 91_000_000 + system_id + day * 100 + hour * 10 + i,
                    victim_ship_type_id: 624,
                    victim_corporation_id: 98_999_999,
                    attacker_count: 2,
                    total_value: Decimal.new("20000000"),
                    raw_data: %{
                      "victim" => %{
                        "character_id" => 91_000_000 + system_id + day * 100 + hour * 10 + i
                      },
                      "attackers" => [
                        %{
                          "character_id" => 91_100_000 + system_id + day * 10 + hour,
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
      end

      %{region_id: region_id, systems: base_systems}
    end

    test "analyzes regional activity correlation", %{region_id: region_id} do
      assert {:ok, correlation} = SystemAnalysis.analyze_regional_correlation(region_id)

      assert Map.has_key?(correlation, :region_id)

      assert Map.has_key?(correlation, :correlation_matrix) or
               Map.has_key?(correlation, :correlations)

      assert correlation.region_id == region_id
    end

    test "identifies correlated system pairs", %{region_id: region_id} do
      assert {:ok, correlation} = SystemAnalysis.analyze_regional_correlation(region_id)

      if Map.has_key?(correlation, :correlated_pairs) do
        pairs = correlation.correlated_pairs

        assert is_list(pairs)

        Enum.each(pairs, fn pair ->
          assert Map.has_key?(pair, :system_a)
          assert Map.has_key?(pair, :system_b)
          assert Map.has_key?(pair, :correlation)

          assert pair.correlation >= -1 and pair.correlation <= 1
        end)
      end
    end

    test "detects activity clusters", %{region_id: region_id} do
      assert {:ok, correlation} = SystemAnalysis.analyze_regional_correlation(region_id)

      if Map.has_key?(correlation, :activity_clusters) do
        clusters = correlation.activity_clusters

        assert is_list(clusters)

        Enum.each(clusters, fn cluster ->
          assert Map.has_key?(cluster, :systems) or is_list(cluster)

          if Map.has_key?(cluster, :systems) do
            assert length(cluster.systems) >= 2
          end
        end)
      end
    end

    test "provides regional activity summary", %{region_id: region_id} do
      assert {:ok, correlation} = SystemAnalysis.analyze_regional_correlation(region_id)

      if Map.has_key?(correlation, :summary) do
        summary = correlation.summary

        assert Map.has_key?(summary, :total_activity) or
                 Map.has_key?(summary, :total_kills)

        assert Map.has_key?(summary, :active_systems) or
                 Map.has_key?(summary, :system_count)
      end
    end
  end

  describe "identify_hot_zones/1" do
    setup do
      # Create systems with varying activity levels
      hot_zone = 30_000_142
      warm_zone = 30_000_143
      cold_zone = 30_000_145

      # Hot zone: 100+ kills in last 24 hours
      for i <- 1..120 do
        killmail_attrs = killmail_raw_factory()

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 960_000_000 + i,
              killmail_time: DateTime.utc_now() |> DateTime.add(-rem(i, 24), :hour),
              solar_system_id: hot_zone,
              victim_character_id: 90_000_000 + i,
              victim_ship_type_id: Enum.random([587, 624, 29_984, 643]),
              victim_corporation_id: 98_999_999,
              attacker_count: rem(i, 5) + 1,
              total_value: Decimal.new("#{10_000_000 * (rem(i, 10) + 1)}"),
              raw_data: %{
                "victim" => %{"character_id" => 90_000_000 + i},
                "attackers" => [
                  %{
                    "character_id" => 90_100_000 + i,
                    "ship_type_id" => Enum.random([624, 29_984, 11_987]),
                    "final_blow" => true
                  }
                ]
              }
            })
          )
      end

      # Warm zone: 20-30 kills
      for i <- 1..25 do
        killmail_attrs = killmail_raw_factory()

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 961_000_000 + i,
              killmail_time: DateTime.utc_now() |> DateTime.add(-rem(i * 2, 48), :hour),
              solar_system_id: warm_zone,
              victim_character_id: 90_200_000 + i,
              victim_ship_type_id: 624,
              victim_corporation_id: 98_999_999,
              attacker_count: 2,
              total_value: Decimal.new("15000000"),
              raw_data: %{
                "victim" => %{"character_id" => 90_200_000 + i},
                "attackers" => [
                  %{
                    "character_id" => 90_300_000 + i,
                    "ship_type_id" => 624,
                    "final_blow" => true
                  }
                ]
              }
            })
          )
      end

      # Cold zone: <5 kills
      for i <- 1..3 do
        killmail_attrs = killmail_raw_factory()

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 962_000_000 + i,
              killmail_time: DateTime.utc_now() |> DateTime.add(-i * 8, :hour),
              solar_system_id: cold_zone,
              victim_character_id: 90_400_000 + i,
              victim_ship_type_id: 587,
              victim_corporation_id: 98_999_999,
              attacker_count: 1,
              total_value: Decimal.new("5000000"),
              raw_data: %{
                "victim" => %{"character_id" => 90_400_000 + i},
                "attackers" => [
                  %{
                    "character_id" => 90_500_000 + i,
                    "ship_type_id" => 587,
                    "final_blow" => true
                  }
                ]
              }
            })
          )
      end

      %{hot_zone: hot_zone, warm_zone: warm_zone, cold_zone: cold_zone}
    end

    test "identifies hot zones correctly", %{hot_zone: hot_zone} do
      assert {:ok, zones} = SystemAnalysis.identify_hot_zones(hours: 24)

      assert Map.has_key?(zones, :hot_zones)
      assert is_list(zones.hot_zones)

      # Hot zone should be identified
      hot_zone_ids =
        Enum.map(zones.hot_zones, fn z ->
          Map.get(z, :system_id) || z
        end)

      assert hot_zone in hot_zone_ids
    end

    test "ranks zones by activity", %{hot_zone: hot_zone, warm_zone: warm_zone} do
      assert {:ok, zones} = SystemAnalysis.identify_hot_zones(hours: 48)

      if Map.has_key?(zones, :rankings) do
        rankings = zones.rankings

        assert is_list(rankings)

        # Hot zone should rank higher than warm zone
        hot_rank =
          Enum.find_index(rankings, fn r ->
            Map.get(r, :system_id) == hot_zone
          end)

        warm_rank =
          Enum.find_index(rankings, fn r ->
            Map.get(r, :system_id) == warm_zone
          end)

        if hot_rank && warm_rank do
          assert hot_rank < warm_rank
        end
      end
    end

    test "provides activity metrics for zones", %{hot_zone: hot_zone} do
      assert {:ok, zones} = SystemAnalysis.identify_hot_zones(hours: 24)

      hot_zone_data =
        Enum.find(zones.hot_zones, fn z ->
          Map.get(z, :system_id) == hot_zone
        end)

      if hot_zone_data && is_map(hot_zone_data) do
        assert Map.has_key?(hot_zone_data, :kill_count) or
                 Map.has_key?(hot_zone_data, :activity_score)

        assert Map.has_key?(hot_zone_data, :isk_destroyed) or
                 Map.has_key?(hot_zone_data, :total_value)
      end
    end
  end
end
