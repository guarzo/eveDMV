defmodule EveDmv.Performance.IntelligencePerformanceTest do
  @moduledoc """
  Performance tests for intelligence module to ensure operations complete within acceptable time limits.
  These tests help prevent performance regressions.
  """
  use EveDmv.DataCase, async: false

  @moduletag :skip

  alias EveDmv.Intelligence.{
    CharacterAnalyzer,
    HomeDefenseAnalyzer,
    WHFleetAnalyzer,
    WHVettingAnalyzer
  }

  alias EveDmv.Api

  # milliseconds
  @max_character_analysis_time 500
  @max_home_defense_time 300
  @max_fleet_analysis_time 100
  @max_vetting_analysis_time 400
  @max_batch_analysis_time 2000

  describe "character analyzer performance" do
    test "analyzes character with moderate activity within time limit" do
      # Create character with 50 killmails
      character_id = 95_000_100
      create_perf_killmails_for_character(character_id, 50)

      {time_microseconds, {:ok, _result}} =
        :timer.tc(fn ->
          CharacterAnalyzer.analyze_character(character_id)
        end)

      time_ms = time_microseconds / 1000

      assert time_ms < @max_character_analysis_time,
             "Character analysis took #{time_ms}ms, expected < #{@max_character_analysis_time}ms"
    end

    test "handles character with extensive history efficiently" do
      # Create character with 200 killmails
      character_id = 95_000_101
      create_perf_killmails_for_character(character_id, 200)

      {time_microseconds, {:ok, _result}} =
        :timer.tc(fn ->
          CharacterAnalyzer.analyze_character(character_id)
        end)

      time_ms = time_microseconds / 1000
      # Allow 2x time for 4x data
      assert time_ms < @max_character_analysis_time * 2,
             "Heavy character analysis took #{time_ms}ms, expected < #{@max_character_analysis_time * 2}ms"
    end

    test "batch analyzes multiple characters efficiently" do
      # Create 5 characters with varying activity
      character_ids =
        for i <- 1..5 do
          character_id = 95_000_200 + i
          create_perf_killmails_for_character(character_id, i * 20)
          character_id
        end

      {time_microseconds, results} =
        :timer.tc(fn ->
          tasks =
            Enum.map(character_ids, fn char_id ->
              Task.async(fn -> CharacterAnalyzer.analyze_character(char_id) end)
            end)

          Task.await_many(tasks, 10_000)
        end)

      time_ms = time_microseconds / 1000

      assert time_ms < @max_batch_analysis_time,
             "Batch analysis took #{time_ms}ms, expected < #{@max_batch_analysis_time}ms"

      # All should succeed
      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)
    end
  end

  describe "home defense analyzer performance" do
    test "analyzes home defense patterns within time limit" do
      corporation_id = 1_000_100
      home_system_id = 30_000_142

      # Create 100 home defense killmails
      create_home_defense_activity(corporation_id, home_system_id, 100)

      {time_microseconds, {:ok, _result}} =
        :timer.tc(fn ->
          HomeDefenseAnalyzer.analyze_home_defense(corporation_id, home_system_id)
        end)

      time_ms = time_microseconds / 1000

      assert time_ms < @max_home_defense_time,
             "Home defense analysis took #{time_ms}ms, expected < #{@max_home_defense_time}ms"
    end

    test "identifies defense patterns efficiently" do
      corporation_id = 1_000_101
      home_system_id = 30_000_142

      # Create coordinated defense pattern
      create_coordinated_defense_activity(corporation_id, home_system_id)

      {time_microseconds, {:ok, _result}} =
        :timer.tc(fn ->
          HomeDefenseAnalyzer.identify_defense_patterns(corporation_id, home_system_id)
        end)

      time_ms = time_microseconds / 1000

      assert time_ms < @max_home_defense_time,
             "Defense pattern analysis took #{time_ms}ms, expected < #{@max_home_defense_time}ms"
    end
  end

  describe "wormhole fleet analyzer performance" do
    test "analyzes fleet composition quickly" do
      fleet_members = generate_fleet_members(20)

      {time_microseconds, result} =
        :timer.tc(fn ->
          WHFleetAnalyzer.analyze_fleet_composition_from_members(fleet_members)
        end)

      time_ms = time_microseconds / 1000

      assert time_ms < @max_fleet_analysis_time,
             "Fleet analysis took #{time_ms}ms, expected < #{@max_fleet_analysis_time}ms"

      assert result.total_members == 20
    end

    test "calculates mass sequences efficiently" do
      ships = generate_fleet_members(15)

      wormhole = %{
        max_mass: 500_000_000,
        max_ship_mass: 20_000_000,
        current_mass: 0
      }

      {time_microseconds, result} =
        :timer.tc(fn ->
          WHFleetAnalyzer.calculate_jump_mass_sequence(ships, wormhole)
        end)

      time_ms = time_microseconds / 1000

      assert time_ms < @max_fleet_analysis_time,
             "Mass sequence calculation took #{time_ms}ms, expected < #{@max_fleet_analysis_time}ms"

      assert is_list(result.jump_order)
    end
  end

  describe "wormhole vetting analyzer performance" do
    test "performs complete vetting analysis within time limit" do
      character_data = %{
        character_id: 95_465_499,
        character_name: "Test Pilot"
      }

      killmails = generate_vetting_killmails(150)
      employment_history = generate_employment_history(10)

      {time_microseconds, _results} =
        :timer.tc(fn ->
          %{
            j_space: WHVettingAnalyzer.calculate_j_space_experience(killmails),
            security:
              WHVettingAnalyzer.analyze_security_risks(character_data, employment_history),
            eviction: WHVettingAnalyzer.detect_eviction_groups(killmails),
            alts: WHVettingAnalyzer.analyze_alt_character_patterns(character_data, killmails),
            competency: WHVettingAnalyzer.calculate_small_gang_competency(killmails)
          }
        end)

      time_ms = time_microseconds / 1000

      assert time_ms < @max_vetting_analysis_time,
             "Complete vetting analysis took #{time_ms}ms, expected < #{@max_vetting_analysis_time}ms"
    end
  end

  describe "memory efficiency" do
    test "character analyzer doesn't leak memory with large datasets" do
      character_id = 95_000_300
      create_perf_killmails_for_character(character_id, 500)

      # Get initial memory
      :erlang.garbage_collect()
      initial_memory = :erlang.memory(:processes)

      # Run analysis multiple times
      for _ <- 1..10 do
        {:ok, _} = CharacterAnalyzer.analyze_character(character_id)
      end

      # Force garbage collection and check memory
      :erlang.garbage_collect()
      final_memory = :erlang.memory(:processes)

      # Memory growth should be minimal (< 10MB)
      memory_growth = final_memory - initial_memory

      assert memory_growth < 10_000_000,
             "Memory grew by #{memory_growth / 1_000_000}MB, expected < 10MB"
    end
  end

  describe "concurrent performance" do
    test "handles concurrent analyses without degradation" do
      # Create test data
      character_ids =
        for i <- 1..10 do
          char_id = 95_000_400 + i
          create_perf_killmails_for_character(char_id, 30)
          char_id
        end

      # Sequential baseline
      {seq_time, _} =
        :timer.tc(fn ->
          Enum.each(character_ids, fn char_id ->
            CharacterAnalyzer.analyze_character(char_id)
          end)
        end)

      # Concurrent execution
      {concurrent_time, _} =
        :timer.tc(fn ->
          tasks =
            Enum.map(character_ids, fn char_id ->
              Task.async(fn -> CharacterAnalyzer.analyze_character(char_id) end)
            end)

          Task.await_many(tasks, 30_000)
        end)

      # Concurrent should be significantly faster (at least 2x)
      speedup = seq_time / concurrent_time

      assert speedup > 2.0,
             "Concurrent execution only #{speedup}x faster, expected > 2x"
    end
  end

  # Helper functions

  defp create_perf_killmails_for_character(character_id, count) do
    killmails =
      for i <- 1..count do
        %{
          killmail_id: 90_000_000 + character_id + i,
          killmail_time: perf_random_datetime_in_past(90),
          solar_system_id: Enum.random(30_000_000..31_005_000),
          killmail_data: build_killmail_data(character_id, i),
          source: "performance_test"
        }
      end

    Ash.bulk_create(killmails, EveDmv.Killmails.KillmailRaw, :create,
      domain: Api,
      return_errors?: false
    )
  end

  defp create_home_defense_activity(corp_id, system_id, count) do
    killmails =
      for i <- 1..count do
        %{
          killmail_id: 91_000_000 + i,
          killmail_time: random_datetime_in_past(7),
          solar_system_id: system_id,
          killmail_data: build_defense_killmail_data(corp_id, system_id),
          source: "performance_test"
        }
      end

    Ash.bulk_create(killmails, EveDmv.Killmails.KillmailRaw, :create,
      domain: Api,
      return_errors?: false
    )
  end

  defp create_coordinated_defense_activity(corp_id, system_id) do
    fleet_members = [95_000_500, 95_000_501, 95_000_502, 95_000_503]

    killmails =
      for i <- 1..20 do
        %{
          killmail_id: 92_000_000 + i,
          killmail_time: random_datetime_in_past(3),
          solar_system_id: system_id,
          killmail_data: build_fleet_killmail_data(corp_id, fleet_members),
          source: "performance_test"
        }
      end

    Ash.bulk_create(killmails, EveDmv.Killmails.KillmailRaw, :create,
      domain: Api,
      return_errors?: false
    )
  end

  defp build_killmail_data(character_id, index) do
    is_victim = rem(index, 3) == 0

    %{
      "solar_system_id" => Enum.random(30_000_000..31_005_000),
      "attackers" => [
        %{
          "character_id" =>
            if(is_victim, do: Enum.random(90_000_000..95_000_000), else: character_id),
          "corporation_id" => Enum.random(1_000_000..2_000_000),
          "ship_type_id" => Enum.random([587, 588, 589, 17_738]),
          "final_blow" => true
        }
      ],
      "victim" => %{
        "character_id" =>
          if(is_victim, do: character_id, else: Enum.random(90_000_000..95_000_000)),
        "corporation_id" => Enum.random(1_000_000..2_000_000),
        "ship_type_id" => Enum.random([587, 588, 589])
      }
    }
  end

  defp build_defense_killmail_data(corp_id, system_id) do
    %{
      "solar_system_id" => system_id,
      "attackers" => [
        %{
          "character_id" => Enum.random(95_000_000..95_000_010),
          "corporation_id" => corp_id,
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
  end

  defp build_fleet_killmail_data(corp_id, fleet_members) do
    %{
      "attackers" =>
        Enum.map(fleet_members, fn member_id ->
          %{
            "character_id" => member_id,
            "corporation_id" => corp_id,
            "final_blow" => member_id == hd(fleet_members),
            "damage_done" => Enum.random(1000..5000)
          }
        end),
      "victim" => %{
        "character_id" => Enum.random(90_000_000..95_000_000),
        "ship_type_id" => Enum.random([587, 588, 589])
      }
    }
  end

  defp generate_fleet_members(count) do
    for i <- 1..count do
      role =
        case rem(i, 5) do
          0 -> {"Guardian", "logistics", 11_800_000}
          1 -> {"Damnation", "command_ship", 13_500_000}
          2 -> {"Sabre", "interdictor", 2_000_000}
          _ -> {"Legion", "strategic_cruiser", 13_000_000}
        end

      {ship_name, ship_category, mass} = role

      %{
        character_id: 100 + i,
        character_name: "Pilot #{i}",
        ship_name: ship_name,
        ship_category: ship_category,
        mass: mass
      }
    end
  end

  defp generate_vetting_killmails(count) do
    for i <- 1..count do
      %{
        killmail_id: 93_000_000 + i,
        solar_system_id:
          if(rem(i, 2) == 0,
            do: Enum.random(31_000_000..31_005_000),
            else: Enum.random(30_000_000..30_005_000)
          ),
        is_victim: rem(i, 4) == 0,
        attacker_count: Enum.random(1..10),
        attacker_character_name: "Pilot #{i}",
        attacker_corporation_name:
          if(rem(i, 50) == 0, do: "Hard Knocks Citizens", else: "Corp #{i}"),
        attacker_alliance_name: "Alliance #{i}",
        killmail_time: random_datetime_in_past(365)
      }
    end
  end

  defp generate_employment_history(count) do
    base_date = ~U[2022-01-01 00:00:00Z]

    for i <- 0..(count - 1) do
      %{
        start_date: DateTime.add(base_date, i * 30 * 24 * 3600, :second),
        corporation_id: 1000 + i
      }
    end
  end

  defp perf_random_datetime_in_past(days) do
    seconds_ago = Enum.random(1..days) * 24 * 3600
    DateTime.add(DateTime.utc_now(), -seconds_ago, :second)
  end
end
