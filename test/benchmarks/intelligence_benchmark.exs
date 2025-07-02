defmodule EveDmv.IntelligenceBenchmark do
  @moduledoc """
  Performance benchmarks for intelligence module calculations.
  Tests the performance of critical intelligence analysis functions.
  """

  alias EveDmv.Intelligence.{
    CharacterAnalyzer,
    HomeDefenseAnalyzer,
    WHFleetAnalyzer,
    WHVettingAnalyzer
  }

  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw

  def run do
    # Setup test data
    setup_benchmark_data()

    # Run benchmarks
    Benchee.run(
      %{
        "character_analyzer" => fn -> benchmark_character_analyzer() end,
        "home_defense_analyzer" => fn -> benchmark_home_defense_analyzer() end,
        "wh_fleet_analyzer" => fn -> benchmark_wh_fleet_analyzer() end,
        "wh_vetting_analyzer" => fn -> benchmark_wh_vetting_analyzer() end,
        "batch_character_analysis" => fn -> benchmark_batch_analysis() end,
        "high_volume_killmail_analysis" => fn -> benchmark_high_volume_analysis() end
      },
      time: 10,
      memory_time: 2,
      warmup: 2,
      parallel: 4,
      formatters: [
        {Benchee.Formatters.Console, extended_statistics: true},
        {Benchee.Formatters.HTML, file: "bench/intelligence_benchmark.html"}
      ],
      profile_after: true
    )
  end

  defp setup_benchmark_data do
    # Create test characters with varying amounts of activity
    @test_characters =
      for i <- 1..10 do
        character_id = 95_000_000 + i
        create_character_activity(character_id, i * 10)
        character_id
      end

    @test_corporation_id = 1_000_100
    @test_home_system_id = 30_000_142

    # Create home defense activity
    create_home_defense_data(@test_corporation_id, @test_home_system_id)

    # Create fleet data
    @test_fleet_members = create_fleet_members()
  end

  defp benchmark_character_analyzer do
    # Test with medium activity character
    character_id = Enum.at(@test_characters, 4)
    {:ok, _analysis} = CharacterAnalyzer.analyze_character(character_id)
  end

  defp benchmark_home_defense_analyzer do
    {:ok, _analysis} =
      HomeDefenseAnalyzer.analyze_home_defense(
        @test_corporation_id,
        @test_home_system_id
      )
  end

  defp benchmark_wh_fleet_analyzer do
    WHFleetAnalyzer.analyze_fleet_composition_from_members(@test_fleet_members)
  end

  defp benchmark_wh_vetting_analyzer do
    # Simulate vetting analysis with killmail data
    character_data = %{
      character_id: 95_465_499,
      character_name: "Test Pilot"
    }

    killmails = generate_killmail_history(100)
    employment_history = generate_employment_history()

    %{
      j_space_experience: WHVettingAnalyzer.calculate_j_space_experience(killmails),
      security_risks:
        WHVettingAnalyzer.analyze_security_risks(character_data, employment_history),
      eviction_groups: WHVettingAnalyzer.detect_eviction_groups(killmails),
      alt_patterns: WHVettingAnalyzer.analyze_alt_character_patterns(character_data, killmails),
      small_gang_competency: WHVettingAnalyzer.calculate_small_gang_competency(killmails)
    }
  end

  defp benchmark_batch_analysis do
    # Analyze multiple characters in parallel
    tasks =
      for character_id <- @test_characters do
        Task.async(fn ->
          CharacterAnalyzer.analyze_character(character_id)
        end)
      end

    Task.await_many(tasks, 30_000)
  end

  defp benchmark_high_volume_analysis do
    # Test with a character that has extensive history
    character_id = 95_999_999
    create_character_activity(character_id, 1000)

    {:ok, _analysis} = CharacterAnalyzer.analyze_character(character_id)
  end

  # Helper functions to create test data

  defp create_character_activity(character_id, kill_count) do
    for i <- 1..kill_count do
      killmail_data = %{
        "killmail_id" => 80_000_000 + character_id + i,
        "killmail_time" => random_datetime_in_past(90),
        "solar_system_id" => Enum.random(30_000_000..31_005_000),
        "attackers" => [
          %{
            "character_id" =>
              if(rem(i, 3) == 0, do: Enum.random(90_000_000..95_000_000), else: character_id),
            "corporation_id" => Enum.random(1_000_000..2_000_000),
            "ship_type_id" => Enum.random([587, 588, 589, 17_738, 29_984]),
            "final_blow" => true,
            "damage_done" => Enum.random(1000..10_000)
          }
        ],
        "victim" => %{
          "character_id" =>
            if(rem(i, 3) == 0, do: character_id, else: Enum.random(90_000_000..95_000_000)),
          "corporation_id" => Enum.random(1_000_000..2_000_000),
          "ship_type_id" => Enum.random([587, 588, 589, 17_738, 29_984]),
          "damage_taken" => Enum.random(1000..10_000)
        }
      }

      # Create raw killmail
      Ash.bulk_create(
        [
          %{
            killmail_id: killmail_data["killmail_id"],
            killmail_time: killmail_data["killmail_time"],
            solar_system_id: killmail_data["solar_system_id"],
            killmail_data: killmail_data,
            source: "benchmark"
          }
        ],
        KillmailRaw,
        :create,
        domain: Api,
        return_errors?: false
      )
    end
  end

  defp create_home_defense_data(corporation_id, home_system_id) do
    # Create 50 defensive killmails
    for i <- 1..50 do
      killmail_data = %{
        "killmail_id" => 81_000_000 + i,
        "killmail_time" => random_datetime_in_past(7),
        "solar_system_id" => home_system_id,
        "attackers" => [
          %{
            "character_id" => Enum.random(95_000_000..95_000_010),
            "corporation_id" => corporation_id,
            "ship_type_id" => Enum.random([587, 588, 589, 17_738]),
            "final_blow" => true
          }
        ],
        "victim" => %{
          "character_id" => Enum.random(90_000_000..95_000_000),
          "corporation_id" => Enum.random(2_000_000..3_000_000),
          "ship_type_id" => Enum.random([587, 588, 589])
        }
      }

      Ash.bulk_create(
        [
          %{
            killmail_id: killmail_data["killmail_id"],
            killmail_time: killmail_data["killmail_time"],
            solar_system_id: home_system_id,
            killmail_data: killmail_data,
            source: "benchmark"
          }
        ],
        KillmailRaw,
        :create,
        domain: Api,
        return_errors?: false
      )
    end
  end

  defp create_fleet_members do
    [
      %{
        character_id: 123,
        character_name: "FC Pilot",
        ship_type_id: 12_013,
        ship_name: "Damnation",
        ship_category: "command_ship",
        mass: 13_500_000,
        role: "fc"
      },
      %{
        character_id: 456,
        character_name: "DPS Pilot 1",
        ship_type_id: 12_011,
        ship_name: "Legion",
        ship_category: "strategic_cruiser",
        mass: 13_000_000,
        role: "dps"
      },
      %{
        character_id: 789,
        character_name: "DPS Pilot 2",
        ship_type_id: 12_011,
        ship_name: "Legion",
        ship_category: "strategic_cruiser",
        mass: 13_000_000,
        role: "dps"
      },
      %{
        character_id: 101,
        character_name: "Logi Pilot 1",
        ship_type_id: 11_987,
        ship_name: "Guardian",
        ship_category: "logistics",
        mass: 11_800_000,
        role: "logistics"
      },
      %{
        character_id: 102,
        character_name: "Logi Pilot 2",
        ship_type_id: 11_987,
        ship_name: "Guardian",
        ship_category: "logistics",
        mass: 11_800_000,
        role: "logistics"
      },
      %{
        character_id: 103,
        character_name: "Tackle Pilot",
        ship_type_id: 11_379,
        ship_name: "Sabre",
        ship_category: "interdictor",
        mass: 2_000_000,
        role: "tackle"
      }
    ]
  end

  defp generate_killmail_history(count) do
    for i <- 1..count do
      %{
        killmail_id: 82_000_000 + i,
        solar_system_id:
          if(rem(i, 2) == 0,
            do: Enum.random(31_000_000..31_005_000),
            else: Enum.random(30_000_000..30_005_000)
          ),
        is_victim: rem(i, 4) == 0,
        attacker_count: Enum.random(1..10),
        attacker_character_name: "Pilot #{i}",
        attacker_corporation_name:
          if(rem(i, 20) == 0, do: "Hard Knocks Citizens", else: "Corp #{i}"),
        attacker_alliance_name:
          if(rem(i, 20) == 0, do: "Hard Knocks Citizens", else: "Alliance #{i}"),
        killmail_time: random_datetime_in_past(365)
      }
    end
  end

  defp generate_employment_history do
    base_date = ~U[2022-01-01 00:00:00Z]

    for i <- 0..9 do
      %{
        start_date: DateTime.add(base_date, i * 30 * 24 * 3600, :second),
        corporation_id: 1000 + i
      }
    end
  end

  defp random_datetime_in_past(days) do
    seconds_ago = Enum.random(1..days) * 24 * 3600
    DateTime.add(DateTime.utc_now(), -seconds_ago, :second)
  end
end

# Run benchmarks if executed directly
if System.get_env("RUN_BENCHMARKS") == "true" do
  EveDmv.IntelligenceBenchmark.run()
end