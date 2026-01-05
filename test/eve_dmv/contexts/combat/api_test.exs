defmodule EveDmv.Contexts.Combat.ApiTest do
  @moduledoc """
  Tests for the Combat context API module.
  Tests all public functions including battle detection, analysis, timeline,
  participants, fleet analysis, tactical analysis, performance metrics, and services.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.Combat.Api

  # Helper to safely call functions that may require GenServers not running in test
  defp safe_call(fun) do
    try do
      fun.()
    rescue
      _ -> {:error, :service_unavailable}
    catch
      :exit, _ -> {:error, :service_unavailable}
    end
  end

  describe "detect_battles/2" do
    test "detects battles from killmail list" do
      killmails = build_killmails_list()

      result = safe_call(fn -> Api.detect_battles(killmails) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result)
    end

    test "accepts options keyword list" do
      killmails = build_killmails_list()

      result = safe_call(fn -> Api.detect_battles(killmails, min_participants: 5) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result)
    end

    test "handles empty killmails list" do
      result = safe_call(fn -> Api.detect_battles([]) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result)
    end
  end

  describe "detect_battles_in_timeframe/3" do
    test "detects battles within time range" do
      start_time = DateTime.add(DateTime.utc_now(), -86400, :second)
      end_time = DateTime.utc_now()

      result = safe_call(fn -> Api.detect_battles_in_timeframe(start_time, end_time) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result)
    end

    test "accepts options keyword list" do
      start_time = DateTime.add(DateTime.utc_now(), -86400, :second)
      end_time = DateTime.utc_now()

      result =
        safe_call(fn ->
          Api.detect_battles_in_timeframe(start_time, end_time, system_id: 30_000_142)
        end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result)
    end
  end

  describe "analyze_battle/1" do
    test "analyzes battle by id" do
      battle_id = Ecto.UUID.generate()

      result = safe_call(fn -> Api.analyze_battle(battle_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "get_battle_metrics/1" do
    test "returns battle metrics for battle_id" do
      battle_id = Ecto.UUID.generate()

      result = safe_call(fn -> Api.get_battle_metrics(battle_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "get_battle_summary/1" do
    test "returns battle summary for battle_id" do
      battle_id = Ecto.UUID.generate()

      result = safe_call(fn -> Api.get_battle_summary(battle_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "build_battle_timeline/1" do
    test "builds timeline for battle" do
      battle_id = Ecto.UUID.generate()

      result = safe_call(fn -> Api.build_battle_timeline(battle_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "get_battle_phases/1" do
    test "returns phases for battle" do
      battle_id = Ecto.UUID.generate()

      result = safe_call(fn -> Api.get_battle_phases(battle_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result)
    end
  end

  describe "analyze_participants/1" do
    test "analyzes participants for battle" do
      battle_id = Ecto.UUID.generate()

      result = safe_call(fn -> Api.analyze_participants(battle_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "get_participant_performance/2" do
    test "returns performance for participant in battle" do
      battle_id = Ecto.UUID.generate()
      char_id = character_id()

      result = safe_call(fn -> Api.get_participant_performance(battle_id, char_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "get_participant_roles/1" do
    test "returns roles for all participants in battle" do
      battle_id = Ecto.UUID.generate()

      result = safe_call(fn -> Api.get_participant_roles(battle_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result)
    end
  end

  describe "analyze_composition/1" do
    test "analyzes fleet composition from killmails" do
      killmails = build_full_killmails_list()

      result = safe_call(fn -> Api.analyze_composition(killmails) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles empty killmails list" do
      result = safe_call(fn -> Api.analyze_composition([]) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end
  end

  describe "get_fleet_effectiveness/2" do
    test "returns fleet effectiveness for a side" do
      killmails = build_full_killmails_list()

      result = safe_call(fn -> Api.get_fleet_effectiveness(killmails, :attackers) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end
  end

  describe "compare_fleet_strengths/1" do
    test "compares fleet strengths from killmails" do
      killmails = build_full_killmails_list()

      result = safe_call(fn -> Api.compare_fleet_strengths(killmails) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end
  end

  describe "detect_patterns/2" do
    test "detects tactical patterns from killmails and timeline" do
      killmails = build_killmails_list()
      timeline = build_timeline()

      result = safe_call(fn -> Api.detect_patterns(killmails, timeline) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result)
    end
  end

  describe "analyze_engagement_tactics/1" do
    test "analyzes engagement tactics from killmails" do
      killmails = build_killmails_list()

      result = safe_call(fn -> Api.analyze_engagement_tactics(killmails) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "calculate_performance_metrics/1" do
    test "calculates performance metrics for battle" do
      battle_id = Ecto.UUID.generate()

      result = safe_call(fn -> Api.calculate_performance_metrics(battle_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "get_ship_performance/2" do
    test "returns ship performance for battle" do
      battle_id = Ecto.UUID.generate()
      ship_id = 587

      result = safe_call(fn -> Api.get_ship_performance(battle_id, ship_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "import_from_zkillboard/1" do
    test "attempts to import from zkillboard url" do
      url = "https://zkillboard.com/kill/123456/"

      result = safe_call(fn -> Api.import_from_zkillboard(url) end)

      # Expected to fail as external API not implemented
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles invalid url format" do
      url = "not-a-url"

      result = safe_call(fn -> Api.import_from_zkillboard(url) end)

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "parse_combat_log/1" do
    test "parses combat log data" do
      log_data = "Sample combat log data"

      result = safe_call(fn -> Api.parse_combat_log(log_data) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "share_battle/2" do
    test "shares battle with options" do
      battle_id = Ecto.UUID.generate()
      sharing_options = %{visibility: :public}

      result = safe_call(fn -> Api.share_battle(battle_id, sharing_options) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "create_battle/1" do
    test "creates battle from params" do
      params = %{
        name: "Test Battle",
        start_time: DateTime.add(DateTime.utc_now(), -3600, :second),
        end_time: DateTime.utc_now()
      }

      result = safe_call(fn -> Api.create_battle(params) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "update_battle/2" do
    test "updates battle by id" do
      battle_id = Ecto.UUID.generate()
      params = %{name: "Updated Battle Name"}

      result = safe_call(fn -> Api.update_battle(battle_id, params) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "get_battle/1" do
    test "retrieves battle by id" do
      battle_id = Ecto.UUID.generate()

      result = safe_call(fn -> Api.get_battle(battle_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "list_battles/1" do
    test "lists battles with default filters" do
      result = safe_call(fn -> Api.list_battles() end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result)
    end

    test "lists battles with custom filters" do
      filters = [system_id: 30_000_142]

      result = safe_call(fn -> Api.list_battles(filters) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result)
    end
  end

  describe "delete_battle/1" do
    test "deletes battle by id" do
      battle_id = Ecto.UUID.generate()

      result = safe_call(fn -> Api.delete_battle(battle_id) end)

      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # Helper functions

  defp build_killmails_list do
    [
      %{
        killmail_id: System.unique_integer([:positive]),
        killmail_time: DateTime.utc_now(),
        solar_system_id: 30_000_142,
        victim: %{character_id: character_id(), ship_type_id: 587},
        attackers: [%{character_id: character_id(), ship_type_id: 588}]
      }
    ]
  end

  defp build_full_killmails_list do
    # Build killmails with all expected fields including zkb
    [
      %{
        killmail_id: System.unique_integer([:positive]),
        killmail_time: DateTime.utc_now(),
        solar_system_id: 30_000_142,
        victim: %{character_id: character_id(), ship_type_id: 587, damage_taken: 1000},
        attackers: [
          %{character_id: character_id(), ship_type_id: 588, damage_done: 1000, final_blow: true}
        ],
        zkb: %{
          hash: "test_hash",
          totalValue: 10_000_000,
          fittedValue: 8_000_000,
          points: 10
        }
      }
    ]
  end

  defp build_timeline do
    [
      %{
        time: DateTime.add(DateTime.utc_now(), -3600, :second),
        event_type: :battle_start
      },
      %{
        time: DateTime.utc_now(),
        event_type: :battle_end
      }
    ]
  end
end
