defmodule EveDmv.Intelligence.CharacterMetricsTest do
  use EveDmv.IntelligenceCase, async: true

  alias EveDmv.Intelligence.CharacterMetrics

  describe "calculate_all_metrics/2" do
    test "returns complete metrics structure for character with activity" do
      character_id = 95_465_800
      killmail_data = create_test_killmail_data(character_id)

      metrics = CharacterMetrics.calculate_all_metrics(character_id, killmail_data)

      # Verify all expected metric categories are present
      assert Map.has_key?(metrics, :basic_stats)
      assert Map.has_key?(metrics, :ship_usage)
      assert Map.has_key?(metrics, :gang_composition)
      assert Map.has_key?(metrics, :geographic_patterns)
      assert Map.has_key?(metrics, :target_preferences)
      assert Map.has_key?(metrics, :behavioral_patterns)
      assert Map.has_key?(metrics, :weaknesses)
      assert Map.has_key?(metrics, :temporal_patterns)
      assert Map.has_key?(metrics, :danger_rating)
      assert Map.has_key?(metrics, :frequent_associates)
      assert Map.has_key?(metrics, :success_rate)
    end

    test "handles empty killmail data" do
      character_id = 95_465_801
      killmail_data = []

      metrics = CharacterMetrics.calculate_all_metrics(character_id, killmail_data)

      assert metrics.basic_stats.kills.count == 0
      assert metrics.basic_stats.losses.count == 0
      assert metrics.success_rate == 0.0
    end
  end

  describe "calculate_basic_stats/2" do
    test "correctly counts kills and losses" do
      character_id = 95_465_802

      # Create 15 kills and 5 losses
      kills = create_kills_for_character(character_id, 15)
      losses = create_losses_for_character(character_id, 5)
      killmail_data = kills ++ losses

      stats = CharacterMetrics.calculate_basic_stats(character_id, killmail_data)

      assert stats.kills.count == 15
      assert stats.losses.count == 5
      assert stats.kd_ratio == 3.0
    end

    test "identifies solo activity" do
      character_id = 95_465_803

      # Create solo kills
      solo_kills =
        for _i <- 1..8 do
          %{
            "killmail_id" => System.unique_integer([:positive]),
            "participants" => [
              %{"character_id" => Enum.random(90_000_000..100_000_000), "is_victim" => true},
              %{"character_id" => character_id, "is_victim" => false}
            ],
            "attackers" => [
              %{"character_id" => character_id, "is_victim" => false}
            ],
            "zkb" => %{"totalValue" => 10_000_000}
          }
        end

      # Create gang kills
      gang_kills =
        for _i <- 1..2 do
          %{
            "killmail_id" => System.unique_integer([:positive]),
            "participants" => [
              %{"character_id" => Enum.random(90_000_000..100_000_000), "is_victim" => true},
              %{"character_id" => character_id, "is_victim" => false},
              %{"character_id" => Enum.random(90_000_000..100_000_000), "is_victim" => false}
            ],
            "attackers" => [
              %{"character_id" => character_id, "is_victim" => false},
              %{"character_id" => Enum.random(90_000_000..100_000_000), "is_victim" => false}
            ],
            "zkb" => %{"totalValue" => 20_000_000}
          }
        end

      killmail_data = solo_kills ++ gang_kills
      stats = CharacterMetrics.calculate_basic_stats(character_id, killmail_data)

      assert stats.kills.solo == 8
      assert stats.solo_ratio == 0.8
    end

    test "calculates efficiency correctly" do
      character_id = 95_465_804

      # Create kills worth 100M ISK total
      kills = create_kills_with_value(character_id, 5, 20_000_000)
      # Create losses worth 50M ISK total
      losses = create_losses_with_value(character_id, 2, 25_000_000)

      killmail_data = kills ++ losses
      stats = CharacterMetrics.calculate_basic_stats(character_id, killmail_data)

      # Efficiency = kills_value / (kills_value + losses_value) * 100
      # = 100M / (100M + 50M) * 100 = 66.67%
      assert_in_delta stats.efficiency, 66.67, 0.1
    end
  end

  describe "analyze_ship_usage/2" do
    test "tracks ship usage statistics" do
      character_id = 95_465_805

      # Create kills in different ships
      rifter_kills = create_kills_in_ship(character_id, 587, "Rifter", 10)
      stabber_kills = create_kills_in_ship(character_id, 622, "Stabber", 5)

      # Create losses
      rifter_losses = create_losses_in_ship(character_id, 587, "Rifter", 2)

      killmail_data = rifter_kills ++ stabber_kills ++ rifter_losses
      ship_usage = CharacterMetrics.analyze_ship_usage(character_id, killmail_data)

      assert length(ship_usage.favorite_ships) > 0

      # Find Rifter in favorite ships
      rifter_stats =
        Enum.find(ship_usage.favorite_ships, fn ship ->
          ship.ship_type_id == 587
        end)

      assert rifter_stats != nil
      # 10 kills + 2 losses
      assert rifter_stats.count == 12
      assert rifter_stats.kills == 10
      assert rifter_stats.losses == 2
    end

    test "categorizes ships by type" do
      character_id = 95_465_806

      # Create activity in different ship categories
      frigate_kills = create_kills_in_ship(character_id, 587, "Rifter", 5)
      cruiser_kills = create_kills_in_ship(character_id, 622, "Stabber", 3)

      killmail_data = frigate_kills ++ cruiser_kills
      ship_usage = CharacterMetrics.analyze_ship_usage(character_id, killmail_data)

      assert Map.has_key?(ship_usage, :ship_categories)
      categories = ship_usage.ship_categories

      # Should have tracked both frigates and cruisers
      assert is_map(categories)
    end
  end

  describe "analyze_gang_composition/2" do
    test "calculates gang size preferences" do
      character_id = 95_465_807

      # Create solo kills
      solo_kills = create_gang_kills(character_id, 1, 5)
      # Create small gang kills
      small_gang_kills = create_gang_kills(character_id, 3, 3)
      # Create fleet kills
      fleet_kills = create_gang_kills(character_id, 15, 2)

      killmail_data = solo_kills ++ small_gang_kills ++ fleet_kills
      gang_comp = CharacterMetrics.analyze_gang_composition(character_id, killmail_data)

      # 5 out of 10 kills
      assert gang_comp.solo_percentage == 50.0
      assert gang_comp.average_gang_size > 1.0
      assert gang_comp.preferred_gang_size != nil
    end
  end

  describe "analyze_geographic_patterns/1" do
    test "identifies most active systems" do
      # Create kills in specific systems
      jita_kills = create_kills_in_system(30_000_142, "Jita", 10)
      amarr_kills = create_kills_in_system(30_002_187, "Amarr", 5)

      killmail_data = jita_kills ++ amarr_kills
      geo_patterns = CharacterMetrics.analyze_geographic_patterns(killmail_data)

      assert length(geo_patterns.most_active_systems) > 0

      # Jita should be the most active
      [top_system | _] = geo_patterns.most_active_systems
      assert top_system.system_id == 30_000_142
      assert top_system.activity_count == 10
    end

    test "calculates security space distribution" do
      # Create activity in different security spaces
      # Highsec
      highsec_kills = create_kills_in_system(30_000_142, "Jita", 5)
      # Lowsec
      lowsec_kills = create_kills_in_system(30_002_812, "Rancer", 8)
      # Nullsec
      nullsec_kills = create_kills_in_system(30_000_001, "J7HZ-F", 12)
      # Wormhole
      wh_kills = create_kills_in_system(31_000_001, "J123456", 3)

      killmail_data = highsec_kills ++ lowsec_kills ++ nullsec_kills ++ wh_kills
      geo_patterns = CharacterMetrics.analyze_geographic_patterns(killmail_data)

      assert geo_patterns.highsec_activity >= 0
      assert geo_patterns.lowsec_activity >= 0
      assert geo_patterns.nullsec_activity >= 0
      assert geo_patterns.wormhole_activity >= 0

      # Total should be 100%
      total =
        geo_patterns.highsec_activity + geo_patterns.lowsec_activity +
          geo_patterns.nullsec_activity + geo_patterns.wormhole_activity

      assert_in_delta total, 100.0, 0.1
    end
  end

  describe "analyze_target_preferences/2" do
    test "identifies preferred target ships" do
      character_id = 95_465_808

      # Create kills of specific ship types
      frigate_kills = create_kills_of_ship_type(character_id, 587, "Rifter", 10)
      cruiser_kills = create_kills_of_ship_type(character_id, 622, "Stabber", 5)

      killmail_data = frigate_kills ++ cruiser_kills
      target_prefs = CharacterMetrics.analyze_target_preferences(character_id, killmail_data)

      assert length(target_prefs.preferred_target_ships) > 0
      assert target_prefs.average_target_value >= 0
    end
  end

  describe "analyze_behavioral_patterns/2" do
    test "calculates risk aversion" do
      character_id = 95_465_809

      # Create even fights (1v1)
      # 2 total = 1v1
      even_kills = create_gang_kills(character_id, 2, 5)
      # Create ganks (5v1)
      gank_kills = create_gang_kills(character_id, 5, 10)

      killmail_data = even_kills ++ gank_kills
      behavioral = CharacterMetrics.analyze_behavioral_patterns(character_id, killmail_data)

      # Should show high risk aversion due to preference for ganking
      assert behavioral.risk_aversion != "Unknown"
      assert behavioral.aggression_level >= 0
    end
  end

  describe "identify_weaknesses/2" do
    test "identifies vulnerability patterns" do
      character_id = 95_465_810

      # Create losses to specific ship types
      losses_to_lokis = create_losses_to_ship_type(character_id, 29_990, "Loki", 5)
      losses_to_sabres = create_losses_to_ship_type(character_id, 22_456, "Sabre", 3)

      killmail_data = losses_to_lokis ++ losses_to_sabres
      weaknesses = CharacterMetrics.identify_weaknesses(character_id, killmail_data)

      assert length(weaknesses.vulnerable_to_ship_types) > 0
      assert weaknesses.takes_bad_fights != nil
      assert weaknesses.overconfidence_indicator >= 0
    end

    test "identifies vulnerable times" do
      character_id = 95_465_811

      # Create losses at specific times
      morning_losses = create_losses_at_hour(character_id, 8, 5)
      evening_losses = create_losses_at_hour(character_id, 20, 2)

      killmail_data = morning_losses ++ evening_losses
      weaknesses = CharacterMetrics.identify_weaknesses(character_id, killmail_data)

      assert weaknesses.vulnerable_times != nil
    end
  end

  describe "analyze_temporal_patterns/1" do
    test "identifies peak activity hours" do
      # Create activity at specific hours
      morning_kills = create_kills_at_hour(nil, 9, 10)
      evening_kills = create_kills_at_hour(nil, 21, 15)

      killmail_data = morning_kills ++ evening_kills
      temporal = CharacterMetrics.analyze_temporal_patterns(killmail_data)

      assert length(temporal.peak_hours) > 0
      assert temporal.timezone_estimate != nil
      assert temporal.activity_consistency >= 0
    end
  end

  describe "calculate_danger_rating/1" do
    test "rates low-threat character appropriately" do
      # Create mostly losses, few kills
      character_id = 95_465_812
      losses = create_losses_for_character(character_id, 20)
      kills = create_kills_for_character(character_id, 5)

      killmail_data = losses ++ kills
      danger_rating = CharacterMetrics.calculate_danger_rating(killmail_data, character_id)

      assert danger_rating.score < 2.5
      assert danger_rating.factors != nil
    end

    test "rates high-threat character appropriately" do
      # Create many kills, few losses, high efficiency
      character_id = 95_465_813
      kills = create_high_value_kills(character_id, 50)
      losses = create_losses_for_character(character_id, 2)

      killmail_data = kills ++ losses
      danger_rating = CharacterMetrics.calculate_danger_rating(killmail_data, character_id)

      assert danger_rating.score > 3.5
      assert danger_rating.factors != nil
    end
  end

  # Helper functions

  defp create_test_killmail_data(character_id) do
    kills = create_kills_for_character(character_id, 10)
    losses = create_losses_for_character(character_id, 5)
    kills ++ losses
  end

  defp create_kills_for_character(character_id, count) do
    for _i <- 1..count do
      %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "solar_system_id" => 30_000_142,
        "participants" => [
          %{"character_id" => Enum.random(90_000_000..100_000_000), "is_victim" => true},
          %{"character_id" => character_id, "is_victim" => false}
        ],
        "zkb" => %{"totalValue" => Enum.random(1_000_000..50_000_000)}
      }
    end
  end

  defp create_losses_for_character(character_id, count) do
    for _i <- 1..count do
      %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "solar_system_id" => 30_000_142,
        "participants" => [
          %{"character_id" => character_id, "is_victim" => true},
          %{"character_id" => Enum.random(90_000_000..100_000_000), "is_victim" => false}
        ],
        "zkb" => %{"totalValue" => Enum.random(1_000_000..20_000_000)}
      }
    end
  end

  defp create_kills_with_value(character_id, count, value_each) do
    for _i <- 1..count do
      %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "solar_system_id" => 30_000_142,
        "participants" => [
          %{"character_id" => Enum.random(90_000_000..100_000_000), "is_victim" => true},
          %{"character_id" => character_id, "is_victim" => false}
        ],
        "zkb" => %{"totalValue" => value_each}
      }
    end
  end

  defp create_losses_with_value(character_id, count, value_each) do
    for _i <- 1..count do
      %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "solar_system_id" => 30_000_142,
        "participants" => [
          %{"character_id" => character_id, "is_victim" => true},
          %{"character_id" => Enum.random(90_000_000..100_000_000), "is_victim" => false}
        ],
        "zkb" => %{"totalValue" => value_each}
      }
    end
  end

  defp create_kills_in_ship(character_id, ship_type_id, ship_name, count) do
    for _i <- 1..count do
      %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "solar_system_id" => 30_000_142,
        "participants" => [
          %{"character_id" => Enum.random(90_000_000..100_000_000), "is_victim" => true},
          %{
            "character_id" => character_id,
            "is_victim" => false,
            "ship_type_id" => ship_type_id,
            "ship_name" => ship_name
          }
        ],
        "zkb" => %{"totalValue" => 10_000_000}
      }
    end
  end

  defp create_losses_in_ship(character_id, ship_type_id, ship_name, count) do
    for _i <- 1..count do
      %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "solar_system_id" => 30_000_142,
        "participants" => [
          %{
            "character_id" => character_id,
            "is_victim" => true,
            "ship_type_id" => ship_type_id,
            "ship_name" => ship_name
          },
          %{"character_id" => Enum.random(90_000_000..100_000_000), "is_victim" => false}
        ],
        "zkb" => %{"totalValue" => 10_000_000}
      }
    end
  end

  defp create_gang_kills(character_id, gang_size, count) do
    for _i <- 1..count do
      attackers =
        for j <- 1..gang_size do
          if j == 1 do
            %{"character_id" => character_id, "is_victim" => false}
          else
            %{"character_id" => Enum.random(90_000_000..100_000_000), "is_victim" => false}
          end
        end

      %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "solar_system_id" => 30_000_142,
        "participants" => [
          %{"character_id" => Enum.random(90_000_000..100_000_000), "is_victim" => true}
          | attackers
        ],
        "attackers" => attackers,
        "zkb" => %{"totalValue" => 10_000_000}
      }
    end
  end

  defp create_kills_in_system(system_id, system_name, count) do
    for _i <- 1..count do
      %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "solar_system_id" => system_id,
        "solar_system_name" => system_name,
        "participants" => [
          %{"character_id" => Enum.random(90_000_000..100_000_000), "is_victim" => true},
          %{"character_id" => Enum.random(90_000_000..100_000_000), "is_victim" => false}
        ],
        "zkb" => %{"totalValue" => 10_000_000}
      }
    end
  end

  defp create_kills_of_ship_type(character_id, victim_ship_type_id, victim_ship_name, count) do
    for _i <- 1..count do
      %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "solar_system_id" => 30_000_142,
        "participants" => [
          %{
            "character_id" => Enum.random(90_000_000..100_000_000),
            "is_victim" => true,
            "ship_type_id" => victim_ship_type_id,
            "ship_name" => victim_ship_name
          },
          %{"character_id" => character_id, "is_victim" => false}
        ],
        "zkb" => %{"totalValue" => 10_000_000}
      }
    end
  end

  defp create_losses_to_ship_type(character_id, attacker_ship_type_id, attacker_ship_name, count) do
    for _i <- 1..count do
      %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "solar_system_id" => 30_000_142,
        "participants" => [
          %{"character_id" => character_id, "is_victim" => true},
          %{
            "character_id" => Enum.random(90_000_000..100_000_000),
            "is_victim" => false,
            "ship_type_id" => attacker_ship_type_id,
            "ship_name" => attacker_ship_name
          }
        ],
        "attackers" => [
          %{
            "character_id" => Enum.random(90_000_000..100_000_000),
            "ship_type_id" => attacker_ship_type_id,
            "ship_name" => attacker_ship_name
          }
        ],
        "zkb" => %{"totalValue" => 10_000_000}
      }
    end
  end

  defp create_losses_at_hour(character_id, hour, count) do
    for _i <- 1..count do
      time =
        DateTime.utc_now()
        |> Map.put(:hour, hour)
        |> Map.put(:minute, 0)
        |> Map.put(:second, 0)
        |> DateTime.to_iso8601()

      %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" => time,
        "solar_system_id" => 30_000_142,
        "participants" => [
          %{"character_id" => character_id, "is_victim" => true},
          %{"character_id" => Enum.random(90_000_000..100_000_000), "is_victim" => false}
        ],
        "zkb" => %{"totalValue" => 10_000_000}
      }
    end
  end

  defp create_kills_at_hour(_character_id, hour, count) do
    for _i <- 1..count do
      time =
        DateTime.utc_now()
        |> Map.put(:hour, hour)
        |> Map.put(:minute, 0)
        |> Map.put(:second, 0)
        |> DateTime.to_iso8601()

      %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" => time,
        "solar_system_id" => 30_000_142,
        "participants" => [
          %{"character_id" => Enum.random(90_000_000..100_000_000), "is_victim" => true},
          %{"character_id" => Enum.random(90_000_000..100_000_000), "is_victim" => false}
        ],
        "zkb" => %{"totalValue" => 10_000_000}
      }
    end
  end

  defp create_high_value_kills(character_id, count) do
    for _i <- 1..count do
      %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "solar_system_id" => 30_000_142,
        "participants" => [
          %{"character_id" => Enum.random(90_000_000..100_000_000), "is_victim" => true},
          %{"character_id" => character_id, "is_victim" => false}
        ],
        "zkb" => %{"totalValue" => Enum.random(100_000_000..1_000_000_000)}
      }
    end
  end
end
