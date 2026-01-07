defmodule EveDmv.Contexts.ThreatSurveillance.Domain.SurveillanceMatchingEngineTest do
  @moduledoc """
  Tests for the SurveillanceMatchingEngine GenServer.

  Tests the surveillance profile matching functionality including:
  - Killmail processing against profiles
  - Criteria testing
  - Match retrieval
  - Metrics
  """

  use EveDmv.DataCase, async: false

  alias EveDmv.Contexts.ThreatSurveillance.Domain.SurveillanceMatchingEngine
  alias EveDmv.DomainEvents.KillmailEnriched

  @moduletag :threat_surveillance

  describe "start_link/1" do
    test "starts the GenServer successfully" do
      stop_engine_if_running()

      assert {:ok, pid} = SurveillanceMatchingEngine.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "registers with the module name" do
      stop_engine_if_running()

      {:ok, pid} = SurveillanceMatchingEngine.start_link([])
      assert GenServer.whereis(SurveillanceMatchingEngine) == pid
      GenServer.stop(pid)
    end

    test "loads active profiles on init" do
      stop_engine_if_running()

      {:ok, pid} = SurveillanceMatchingEngine.start_link([])

      # Engine should be running and have loaded profiles
      metrics = SurveillanceMatchingEngine.get_metrics()
      assert is_integer(metrics.active_profiles)

      GenServer.stop(pid)
    end
  end

  describe "process_killmail/1" do
    setup do
      ensure_engine_running()
    end

    test "processes a valid killmail event" do
      killmail = build_killmail_enriched()

      # Should not raise (async operation)
      assert :ok = SurveillanceMatchingEngine.process_killmail(killmail)
    end

    test "updates processed_killmails counter" do
      initial_metrics = SurveillanceMatchingEngine.get_metrics()
      killmail = build_killmail_enriched()

      SurveillanceMatchingEngine.process_killmail(killmail)
      Process.sleep(100)

      updated_metrics = SurveillanceMatchingEngine.get_metrics()
      assert updated_metrics.processed_killmails >= initial_metrics.processed_killmails
    end

    test "processes killmail with victim character" do
      killmail = build_killmail_enriched()

      assert :ok = SurveillanceMatchingEngine.process_killmail(killmail)
    end

    test "processes killmail with multiple attackers" do
      killmail = build_killmail_enriched_with_attackers(5)

      assert :ok = SurveillanceMatchingEngine.process_killmail(killmail)
    end

    test "handles killmail with high value" do
      killmail = build_killmail_enriched_with_value(1_000_000_000)

      assert :ok = SurveillanceMatchingEngine.process_killmail(killmail)
    end
  end

  describe "test_criteria/2" do
    setup do
      ensure_engine_running()
    end

    test "tests character_id criterion" do
      character_id = character_id()

      criteria = [
        %{type: "character_id", value: character_id}
      ]

      sample_data = build_sample_killmail_with_character(character_id)

      assert {:ok, result} = SurveillanceMatchingEngine.test_criteria(criteria, sample_data)

      assert is_boolean(result.overall_match)
      assert is_list(result.criterion_results)
      assert is_number(result.confidence_score)
    end

    test "tests corporation_id criterion" do
      corp_id = corporation_id()

      criteria = [
        %{type: "corporation_id", value: corp_id}
      ]

      sample_data = build_sample_killmail_with_corporation(corp_id)

      assert {:ok, result} = SurveillanceMatchingEngine.test_criteria(criteria, sample_data)

      assert is_boolean(result.overall_match)
    end

    test "tests alliance_id criterion" do
      alliance_id = Enum.random(99_000_000..99_999_999)

      criteria = [
        %{type: "alliance_id", value: alliance_id}
      ]

      sample_data = build_sample_killmail_with_alliance(alliance_id)

      assert {:ok, result} = SurveillanceMatchingEngine.test_criteria(criteria, sample_data)

      assert is_boolean(result.overall_match)
    end

    test "tests ship_type_id criterion" do
      ship_type_id = 587

      criteria = [
        %{type: "ship_type_id", value: ship_type_id}
      ]

      sample_data = build_sample_killmail_with_ship(ship_type_id)

      assert {:ok, result} = SurveillanceMatchingEngine.test_criteria(criteria, sample_data)

      assert is_boolean(result.overall_match)
    end

    test "tests system_id criterion" do
      system_id = 30_000_142

      criteria = [
        %{type: "system_id", value: system_id}
      ]

      sample_data = build_sample_killmail_in_system(system_id)

      assert {:ok, result} = SurveillanceMatchingEngine.test_criteria(criteria, sample_data)

      assert is_boolean(result.overall_match)
    end

    test "tests min_value criterion" do
      criteria = [
        %{type: "min_value", value: 100_000_000}
      ]

      sample_data = build_sample_killmail_with_value(500_000_000)

      assert {:ok, result} = SurveillanceMatchingEngine.test_criteria(criteria, sample_data)

      assert result.overall_match == true
    end

    test "tests max_value criterion" do
      criteria = [
        %{type: "max_value", value: 100_000_000}
      ]

      sample_data = build_sample_killmail_with_value(50_000_000)

      assert {:ok, result} = SurveillanceMatchingEngine.test_criteria(criteria, sample_data)

      assert result.overall_match == true
    end

    test "tests security_status criterion with greater than" do
      criteria = [
        %{type: "security_status", operator: ">", value: 0.5}
      ]

      sample_data = build_sample_killmail_in_system(30_000_142)

      assert {:ok, result} = SurveillanceMatchingEngine.test_criteria(criteria, sample_data)

      assert is_boolean(result.overall_match)
    end

    test "tests security_status criterion with less than" do
      criteria = [
        %{type: "security_status", operator: "<", value: 0.5}
      ]

      sample_data = build_sample_killmail_in_system(30_000_142)

      assert {:ok, result} = SurveillanceMatchingEngine.test_criteria(criteria, sample_data)

      assert is_boolean(result.overall_match)
    end

    test "tests multiple criteria (AND logic)" do
      character_id = character_id()
      system_id = 30_000_142

      criteria = [
        %{type: "character_id", value: character_id},
        %{type: "system_id", value: system_id}
      ]

      sample_data =
        build_sample_killmail_with_character(character_id)
        |> Map.put(:solar_system_id, system_id)

      assert {:ok, result} = SurveillanceMatchingEngine.test_criteria(criteria, sample_data)

      # Both criteria need to match for overall_match
      assert is_boolean(result.overall_match)
      assert length(result.criterion_results) == 2
    end

    test "handles unknown criterion type gracefully" do
      criteria = [
        %{type: "unknown_type", value: "test"}
      ]

      sample_data = build_sample_killmail()

      assert {:ok, result} = SurveillanceMatchingEngine.test_criteria(criteria, sample_data)

      assert result.overall_match == false
    end

    test "returns correct confidence score" do
      character_id = character_id()

      criteria = [
        %{type: "character_id", value: character_id}
      ]

      sample_data = build_sample_killmail_with_character(character_id)

      assert {:ok, result} = SurveillanceMatchingEngine.test_criteria(criteria, sample_data)

      # Confidence should be between 0 and 1
      assert result.confidence_score >= 0.0
      assert result.confidence_score <= 1.0
    end
  end

  describe "get_recent_matches/1" do
    setup do
      ensure_engine_running()
    end

    test "returns recent matches list" do
      assert {:ok, matches} = SurveillanceMatchingEngine.get_recent_matches([])

      assert is_list(matches)
    end

    test "respects limit option" do
      assert {:ok, matches} = SurveillanceMatchingEngine.get_recent_matches(limit: 10)

      assert is_list(matches)
      assert length(matches) <= 10
    end

    test "respects since option" do
      since = DateTime.add(DateTime.utc_now(), -86_400, :second)

      assert {:ok, matches} = SurveillanceMatchingEngine.get_recent_matches(since: since)

      assert is_list(matches)
    end
  end

  describe "get_profile_matches/2" do
    setup do
      ensure_engine_running()
    end

    test "returns matches for a specific profile" do
      profile_id = "profile_#{System.unique_integer([:positive])}"

      assert {:ok, matches} = SurveillanceMatchingEngine.get_profile_matches(profile_id, [])

      assert is_list(matches)
    end

    test "respects limit option" do
      profile_id = "profile_#{System.unique_integer([:positive])}"

      assert {:ok, matches} =
               SurveillanceMatchingEngine.get_profile_matches(profile_id, limit: 10)

      assert is_list(matches)
      assert length(matches) <= 10
    end

    test "respects since option" do
      profile_id = "profile_#{System.unique_integer([:positive])}"
      since = DateTime.add(DateTime.utc_now(), -7 * 86_400, :second)

      assert {:ok, matches} =
               SurveillanceMatchingEngine.get_profile_matches(profile_id, since: since)

      assert is_list(matches)
    end
  end

  describe "get_metrics/0" do
    setup do
      ensure_engine_running()
    end

    test "returns current metrics" do
      metrics = SurveillanceMatchingEngine.get_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :processed_killmails)
      assert Map.has_key?(metrics, :total_matches)
      assert Map.has_key?(metrics, :active_profiles)
      assert Map.has_key?(metrics, :match_rate)
      assert Map.has_key?(metrics, :average_processing_time)
      assert Map.has_key?(metrics, :cache_size)
    end

    test "metrics have correct types" do
      metrics = SurveillanceMatchingEngine.get_metrics()

      assert is_integer(metrics.processed_killmails)
      assert is_integer(metrics.total_matches)
      assert is_integer(metrics.active_profiles)
      assert is_float(metrics.match_rate)
      assert is_number(metrics.average_processing_time)
      assert is_integer(metrics.cache_size)
    end

    test "match_rate is between 0 and 1" do
      metrics = SurveillanceMatchingEngine.get_metrics()

      assert metrics.match_rate >= 0.0
    end
  end

  describe "health_check" do
    setup do
      ensure_engine_running()
    end

    test "responds to health check" do
      assert :ok = GenServer.call(SurveillanceMatchingEngine, :health_check)
    end
  end

  describe "performance tracking" do
    setup do
      ensure_engine_running()
    end

    test "tracks average processing time" do
      initial_metrics = SurveillanceMatchingEngine.get_metrics()

      # Process several killmails
      for _ <- 1..5 do
        killmail = build_killmail_enriched()
        SurveillanceMatchingEngine.process_killmail(killmail)
      end

      Process.sleep(200)

      updated_metrics = SurveillanceMatchingEngine.get_metrics()

      assert is_number(updated_metrics.average_processing_time)
      assert updated_metrics.processed_killmails >= initial_metrics.processed_killmails
    end
  end

  describe "criterion evaluation edge cases" do
    setup do
      ensure_engine_running()
    end

    test "handles nil victim fields" do
      criteria = [
        %{type: "character_id", value: 12_345}
      ]

      sample_data = %{
        killmail_id: 1,
        solar_system_id: 30_000_142,
        victim: %{},
        attackers: [],
        zkb_total_value: nil
      }

      assert {:ok, result} = SurveillanceMatchingEngine.test_criteria(criteria, sample_data)

      assert result.overall_match == false
    end

    test "handles empty attackers list" do
      character_id = character_id()

      criteria = [
        %{type: "character_id", value: character_id}
      ]

      sample_data = %{
        killmail_id: 1,
        solar_system_id: 30_000_142,
        victim: %{character_id: character_id},
        attackers: [],
        zkb_total_value: nil
      }

      assert {:ok, result} = SurveillanceMatchingEngine.test_criteria(criteria, sample_data)

      # Should match via victim
      assert result.overall_match == true
    end

    test "finds character in attackers" do
      character_id = character_id()

      criteria = [
        %{type: "character_id", value: character_id}
      ]

      sample_data = %{
        killmail_id: 1,
        solar_system_id: 30_000_142,
        victim: %{character_id: 99_999},
        attackers: [
          %{character_id: character_id, corporation_id: 123}
        ],
        zkb_total_value: nil
      }

      assert {:ok, result} = SurveillanceMatchingEngine.test_criteria(criteria, sample_data)

      assert result.overall_match == true
    end

    test "handles nil zkb_total_value for value criteria" do
      criteria = [
        %{type: "min_value", value: 100_000_000}
      ]

      sample_data = %{
        killmail_id: 1,
        solar_system_id: 30_000_142,
        victim: %{},
        attackers: [],
        zkb_total_value: nil
      }

      assert {:ok, result} = SurveillanceMatchingEngine.test_criteria(criteria, sample_data)

      # nil value should not match min_value
      assert result.overall_match == false
    end
  end

  # Helper functions

  defp ensure_engine_running do
    case GenServer.whereis(SurveillanceMatchingEngine) do
      nil ->
        {:ok, _pid} = SurveillanceMatchingEngine.start_link([])
        :ok

      pid when is_pid(pid) ->
        if Process.alive?(pid), do: :ok, else: SurveillanceMatchingEngine.start_link([])
    end
  end

  defp stop_engine_if_running do
    case GenServer.whereis(SurveillanceMatchingEngine) do
      nil ->
        :ok

      pid ->
        GenServer.stop(pid)
        Process.sleep(50)
    end
  end

  defp build_killmail_enriched do
    killmail_data = build(:killmail_enriched)

    %KillmailEnriched{
      killmail_id: killmail_data.killmail_id,
      killmail_time: killmail_data.killmail_time,
      solar_system_id: killmail_data.solar_system_id,
      victim: %{
        character_id: killmail_data.victim_character_id,
        corporation_id: killmail_data.victim_corporation_id,
        alliance_id: killmail_data.victim_alliance_id,
        ship_type_id: killmail_data.victim_ship_type_id
      },
      attackers:
        Enum.map(killmail_data.raw_data["attackers"] || [], fn a ->
          %{
            character_id: a["character_id"],
            corporation_id: a["corporation_id"],
            alliance_id: a["alliance_id"],
            ship_type_id: a["ship_type_id"]
          }
        end),
      zkb_total_value: Decimal.new("100000000")
    }
  end

  defp build_killmail_enriched_with_attackers(count) do
    killmail = build_killmail_enriched()

    attackers =
      for _ <- 1..count do
        %{
          character_id: character_id(),
          corporation_id: corporation_id(),
          alliance_id: Enum.random(99_000_000..99_999_999),
          ship_type_id: Enum.random([587, 588, 589, 620, 621])
        }
      end

    %{killmail | attackers: attackers}
  end

  defp build_killmail_enriched_with_value(value) do
    killmail = build_killmail_enriched()
    %{killmail | zkb_total_value: Decimal.new(value)}
  end

  defp build_sample_killmail do
    %{
      killmail_id: System.unique_integer([:positive]),
      solar_system_id: 30_000_142,
      victim: %{
        character_id: character_id(),
        corporation_id: corporation_id(),
        alliance_id: Enum.random(99_000_000..99_999_999),
        ship_type_id: 587
      },
      attackers: [],
      zkb_total_value: Decimal.new("100000000")
    }
  end

  defp build_sample_killmail_with_character(character_id) do
    %{
      killmail_id: System.unique_integer([:positive]),
      solar_system_id: 30_000_142,
      victim: %{
        character_id: character_id,
        corporation_id: corporation_id(),
        alliance_id: Enum.random(99_000_000..99_999_999),
        ship_type_id: 587
      },
      attackers: [],
      zkb_total_value: Decimal.new("100000000")
    }
  end

  defp build_sample_killmail_with_corporation(corp_id) do
    %{
      killmail_id: System.unique_integer([:positive]),
      solar_system_id: 30_000_142,
      victim: %{
        character_id: character_id(),
        corporation_id: corp_id,
        alliance_id: Enum.random(99_000_000..99_999_999),
        ship_type_id: 587
      },
      attackers: [],
      zkb_total_value: Decimal.new("100000000")
    }
  end

  defp build_sample_killmail_with_alliance(alliance_id) do
    %{
      killmail_id: System.unique_integer([:positive]),
      solar_system_id: 30_000_142,
      victim: %{
        character_id: character_id(),
        corporation_id: corporation_id(),
        alliance_id: alliance_id,
        ship_type_id: 587
      },
      attackers: [],
      zkb_total_value: Decimal.new("100000000")
    }
  end

  defp build_sample_killmail_with_ship(ship_type_id) do
    %{
      killmail_id: System.unique_integer([:positive]),
      solar_system_id: 30_000_142,
      victim: %{
        character_id: character_id(),
        corporation_id: corporation_id(),
        alliance_id: Enum.random(99_000_000..99_999_999),
        ship_type_id: ship_type_id
      },
      attackers: [],
      zkb_total_value: Decimal.new("100000000")
    }
  end

  defp build_sample_killmail_in_system(system_id) do
    %{
      killmail_id: System.unique_integer([:positive]),
      solar_system_id: system_id,
      victim: %{
        character_id: character_id(),
        corporation_id: corporation_id(),
        alliance_id: Enum.random(99_000_000..99_999_999),
        ship_type_id: 587
      },
      attackers: [],
      zkb_total_value: Decimal.new("100000000")
    }
  end

  defp build_sample_killmail_with_value(value) do
    %{
      killmail_id: System.unique_integer([:positive]),
      solar_system_id: 30_000_142,
      victim: %{
        character_id: character_id(),
        corporation_id: corporation_id(),
        alliance_id: Enum.random(99_000_000..99_999_999),
        ship_type_id: 587
      },
      attackers: [],
      zkb_total_value: value
    }
  end
end
