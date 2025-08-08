defmodule EveDmv.Contexts.CharacterIntelligence.PerformanceTest do
  @moduledoc """
  Performance benchmarks for character intelligence analysis.
  Ensures all operations meet performance targets defined in Phase 2 requirements.
  """

  use EveDmv.DataCase, async: false

  import EveDmv.Factories
  alias EveDmv.Api
  alias EveDmv.Contexts.CharacterIntelligence
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Killmails.KillmailRaw

  require Logger

  describe "threat analysis performance" do
    setup do
      # Create test data for multiple characters
      character_ids = for i <- 1..20, do: 97_000_000 + i

      # Create killmails for each character
      for char_id <- character_ids do
        for j <- 1..10 do
          killmail_attrs = killmail_raw_factory()

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 500_000_000 + char_id * 100 + j,
                killmail_time: DateTime.utc_now() |> DateTime.add(-(j * 2 + 10), :day),
                solar_system_id: 30_000_142 + rem(j, 5),
                victim_character_id: if(rem(j, 2) == 0, do: char_id, else: 97_999_000 + j),
                victim_ship_type_id: Enum.random([587, 624, 29_984, 11_987]),
                victim_corporation_id: 98_000_000 + rem(char_id, 10),
                attacker_count: rem(j, 5) + 1,
                total_value: Decimal.new("#{10_000_000 * (j + 1)}"),
                raw_data: %{
                  "attackers" => [
                    %{
                      "character_id" => if(rem(j, 2) == 0, do: 97_888_888, else: char_id),
                      "ship_type_id" => Enum.random([29_984, 24_696, 11_987]),
                      "final_blow" => true
                    }
                  ]
                }
              })
            )
        end
      end

      %{character_ids: character_ids}
    end

    test "analyze_character_threat completes within 500ms for single character", %{
      character_ids: character_ids
    } do
      char_id = Enum.at(character_ids, 0)

      {time_micros, result} =
        :timer.tc(fn ->
          CharacterIntelligence.analyze_character_threat(char_id)
        end)

      time_ms = time_micros / 1000

      assert {:ok, _} = result
      assert time_ms < 500, "Threat analysis took #{time_ms}ms, expected < 500ms"

      Logger.info("Single character threat analysis: #{time_ms}ms")
    end

    test "batch threat analysis for 20 characters completes within 5 seconds", %{
      character_ids: character_ids
    } do
      {time_micros, results} =
        :timer.tc(fn ->
          Enum.map(character_ids, fn char_id ->
            CharacterIntelligence.analyze_character_threat(char_id)
          end)
        end)

      time_ms = time_micros / 1000

      assert time_ms < 5000,
             "Batch analysis of 20 characters took #{time_ms}ms, expected < 5000ms"

      assert length(results) == 20

      successful =
        Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      assert successful >= 18, "Expected at least 18/20 successful analyses, got #{successful}"

      Logger.info(
        "Batch threat analysis for 20 characters: #{time_ms}ms (#{time_ms / 20}ms per character)"
      )
    end

    test "compare_character_threats handles 10 characters efficiently", %{
      character_ids: character_ids
    } do
      test_chars = Enum.take(character_ids, 10)

      {time_micros, result} =
        :timer.tc(fn ->
          CharacterIntelligence.compare_character_threats(test_chars)
        end)

      time_ms = time_micros / 1000

      assert {:ok, comparisons} = result
      assert time_ms < 3000, "Comparison of 10 characters took #{time_ms}ms, expected < 3000ms"
      assert is_list(comparisons)

      Logger.info("Character threat comparison for 10 characters: #{time_ms}ms")
    end
  end

  describe "gang synergy performance" do
    setup do
      # Create a gang of characters with shared killmails
      gang_ids = for i <- 1..10, do: 96_000_000 + i

      # Create shared killmails (gang operations)
      for kill_num <- 1..30 do
        killmail_attrs = killmail_raw_factory()
        victim_id = 96_999_000 + kill_num

        # Build attackers list with gang members
        attackers =
          Enum.take_random(gang_ids, rem(kill_num, 5) + 2)
          |> Enum.with_index()
          |> Enum.map(fn {char_id, idx} ->
            %{
              "character_id" => char_id,
              "ship_type_id" => Enum.random([29_984, 24_696, 11_987, 641]),
              "final_blow" => idx == 0,
              "damage_done" => 1000 * (idx + 1)
            }
          end)

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 510_000_000 + kill_num,
              killmail_time: DateTime.utc_now() |> DateTime.add(-kill_num, :day),
              solar_system_id: 30_000_142,
              victim_character_id: victim_id,
              victim_ship_type_id: 643,
              victim_corporation_id: 98_500_000,
              attacker_count: length(attackers),
              total_value: Decimal.new("#{50_000_000 * length(attackers)}"),
              raw_data: %{
                "victim" => %{"character_id" => victim_id},
                "attackers" => attackers
              }
            })
          )
      end

      %{gang_ids: gang_ids}
    end

    test "gang synergy analysis for 10 characters completes within 5 seconds", %{
      gang_ids: gang_ids
    } do
      {time_micros, result} =
        :timer.tc(fn ->
          CharacterIntelligence.analyze_gang_synergy(gang_ids)
        end)

      time_ms = time_micros / 1000

      assert {:ok, synergy} = result
      assert time_ms < 5000, "Gang synergy analysis took #{time_ms}ms, expected < 5000ms"
      assert Map.has_key?(synergy, :coordination_score)

      Logger.info("Gang synergy analysis for 10 characters: #{time_ms}ms")
    end

    test "gang effectiveness analysis scales with group size", %{gang_ids: gang_ids} do
      # Test with different group sizes
      sizes_and_limits = [
        # 5 characters should complete in 2s
        {5, 2000},
        # 10 characters should complete in 5s
        {10, 5000},
        # 15 characters should complete in 8s
        {15, 8000}
      ]

      # Create additional character IDs for larger groups
      extended_ids = gang_ids ++ for i <- 11..15, do: 96_000_000 + i

      for {size, limit_ms} <- sizes_and_limits do
        test_group = Enum.take(extended_ids, size)

        {time_micros, result} =
          :timer.tc(fn ->
            CharacterIntelligence.analyze_gang_effectiveness(test_group)
          end)

        time_ms = time_micros / 1000

        assert {:ok, _} = result

        assert time_ms < limit_ms,
               "Gang effectiveness for #{size} characters took #{time_ms}ms, expected < #{limit_ms}ms"

        Logger.info("Gang effectiveness for #{size} characters: #{time_ms}ms")
      end
    end
  end

  describe "behavioral pattern detection performance" do
    setup do
      # Create characters with distinct patterns
      characters = [
        # Solo operations
        {96_100_001, :solo_hunter, 1},
        # Large fleet operations
        {96_100_002, :fleet_anchor, 10},
        # Small gang specialist
        {96_100_003, :small_gang, 3}
      ]

      for {char_id, pattern, gang_size} <- characters do
        for i <- 1..20 do
          killmail_attrs = killmail_raw_factory()

          # Create pattern-specific killmails
          attackers =
            for j <- 1..gang_size do
              %{
                "character_id" => if(j == 1, do: char_id, else: 96_200_000 + j),
                "ship_type_id" =>
                  case pattern do
                    # T3Cs
                    :solo_hunter -> Enum.random([29_984, 29_986, 29_988])
                    # Battleships
                    :fleet_anchor -> Enum.random([641, 643, 645])
                    # Cruisers
                    :small_gang -> Enum.random([624, 621, 622])
                  end,
                "final_blow" => j == 1
              }
            end

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 520_000_000 + char_id * 100 + i,
                killmail_time: DateTime.utc_now() |> DateTime.add(-i * 2, :day),
                solar_system_id: 30_000_142,
                victim_character_id: 96_300_000 + i,
                victim_ship_type_id: 587,
                victim_corporation_id: 98_600_000,
                attacker_count: gang_size,
                total_value: Decimal.new("#{10_000_000 * gang_size}"),
                raw_data: %{
                  "victim" => %{"character_id" => 96_300_000 + i},
                  "attackers" => attackers
                }
              })
            )
        end
      end

      %{character_ids: Enum.map(characters, &elem(&1, 0))}
    end

    test "detect_behavioral_patterns completes quickly", %{character_ids: character_ids} do
      for char_id <- character_ids do
        {time_micros, result} =
          :timer.tc(fn ->
            CharacterIntelligence.detect_behavioral_patterns(char_id)
          end)

        time_ms = time_micros / 1000

        assert {:ok, patterns} = result
        assert time_ms < 1000, "Pattern detection took #{time_ms}ms, expected < 1000ms"
        assert Map.has_key?(patterns, :primary_pattern)

        Logger.info("Behavioral pattern detection for #{char_id}: #{time_ms}ms")
      end
    end
  end

  describe "historical trend analysis performance" do
    setup do
      # Create character with extensive history
      char_id = 96_400_001

      # Create 365 days of killmail history
      for day <- 1..365 do
        # Variable activity (0-5 kills per day)
        kills_today = rem(day, 6)

        for kill <- 1..kills_today do
          killmail_attrs = killmail_raw_factory()

          {:ok, _} =
            Api.create(
              KillmailRaw,
              Map.merge(killmail_attrs, %{
                killmail_id: 530_000_000 + day * 100 + kill,
                killmail_time: DateTime.utc_now() |> DateTime.add(-day, :day),
                solar_system_id: 30_000_142 + rem(day, 10),
                victim_character_id: 96_500_000 + day * 10 + kill,
                victim_ship_type_id: Enum.random([587, 624, 29_984]),
                victim_corporation_id: 98_700_000 + rem(day, 50),
                attacker_count: rem(day, 5) + 1,
                total_value: Decimal.new("#{5_000_000 * (rem(day, 10) + 1)}"),
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
      end

      %{character_id: char_id}
    end

    test "analyze 365 days of history efficiently", %{character_id: char_id} do
      {time_micros, result} =
        :timer.tc(fn ->
          CharacterIntelligence.analyze_historical_trends(char_id, days: 365)
        end)

      time_ms = time_micros / 1000

      assert {:ok, trends} = result
      assert time_ms < 3000, "365-day trend analysis took #{time_ms}ms, expected < 3000ms"
      assert Map.has_key?(trends, :activity_trend)

      Logger.info("365-day historical trend analysis: #{time_ms}ms")
    end

    test "calculate_threat_trends performs well with large datasets", %{character_id: char_id} do
      periods = [30, 90, 180, 365]

      for days <- periods do
        {time_micros, result} =
          :timer.tc(fn ->
            CharacterIntelligence.calculate_threat_trends(char_id, days)
          end)

        time_ms = time_micros / 1000
        # 5ms per day of history as rough guideline
        expected_limit = days * 5

        assert {:ok, _} = result

        assert time_ms < expected_limit,
               "#{days}-day threat trend took #{time_ms}ms, expected < #{expected_limit}ms"

        Logger.info("#{days}-day threat trend calculation: #{time_ms}ms")
      end
    end
  end

  describe "memory usage benchmarks" do
    test "memory usage remains reasonable for large character sets" do
      # Create 100 character IDs
      character_ids = for i <- 1..100, do: 96_600_000 + i

      # Measure memory before
      :erlang.garbage_collect()
      {_, initial_memory} = :erlang.process_info(self(), :memory)

      # Create minimal killmails for each
      for char_id <- character_ids do
        killmail_attrs = killmail_raw_factory()

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 540_000_000 + char_id,
              killmail_time: DateTime.utc_now() |> DateTime.add(-30, :day),
              solar_system_id: 30_000_142,
              victim_character_id: char_id,
              victim_ship_type_id: 587,
              victim_corporation_id: 98_800_000,
              attacker_count: 1,
              total_value: Decimal.new("10000000"),
              raw_data: %{
                "victim" => %{"character_id" => char_id},
                "attackers" => [
                  %{
                    "character_id" => 96_700_000,
                    "ship_type_id" => 29_984,
                    "final_blow" => true
                  }
                ]
              }
            })
          )
      end

      # Analyze all characters
      results =
        Enum.map(character_ids, fn char_id ->
          CharacterIntelligence.analyze_character_threat(char_id)
        end)

      # Measure memory after
      {_, final_memory} = :erlang.process_info(self(), :memory)
      memory_used_mb = (final_memory - initial_memory) / 1_048_576

      assert length(results) == 100
      assert memory_used_mb < 100, "Memory usage #{memory_used_mb}MB exceeds 100MB limit"

      Logger.info("Memory usage for 100 character analysis: #{Float.round(memory_used_mb, 2)}MB")
    end
  end

  describe "concurrent request handling" do
    setup do
      # Create test data for concurrent testing
      character_ids = for i <- 1..50, do: 96_800_000 + i

      for char_id <- character_ids do
        killmail_attrs = killmail_raw_factory()

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 550_000_000 + char_id,
              killmail_time: DateTime.utc_now() |> DateTime.add(-30, :day),
              solar_system_id: 30_000_142,
              victim_character_id: 96_900_000 + char_id,
              victim_ship_type_id: 587,
              victim_corporation_id: 98_900_000,
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

      %{character_ids: character_ids}
    end

    test "handles 50 concurrent threat analyses", %{character_ids: character_ids} do
      {time_micros, results} =
        :timer.tc(fn ->
          character_ids
          |> Task.async_stream(
            fn char_id ->
              CharacterIntelligence.analyze_character_threat(char_id)
            end,
            max_concurrency: 50,
            timeout: 10_000
          )
          |> Enum.to_list()
        end)

      time_ms = time_micros / 1000

      assert length(results) == 50
      assert time_ms < 10_000, "50 concurrent analyses took #{time_ms}ms, expected < 10000ms"

      successful =
        Enum.count(results, fn
          {:ok, {:ok, _}} -> true
          _ -> false
        end)

      assert successful >= 45,
             "Expected at least 45/50 successful concurrent analyses, got #{successful}"

      Logger.info("50 concurrent threat analyses: #{time_ms}ms total (#{time_ms / 50}ms average)")
    end
  end
end
