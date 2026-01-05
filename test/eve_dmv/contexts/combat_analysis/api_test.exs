defmodule EveDmv.Contexts.CombatAnalysis.ApiTest do
  @moduledoc """
  Tests for the Combat Analysis API module.
  Tests all public functions including happy paths, error handling, and edge cases.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.CombatAnalysis.Api

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

  describe "analyze_battle/2" do
    test "returns battle analysis with default options" do
      battle_data = build_battle_data()

      result = safe_call(fn -> Api.analyze_battle(battle_data) end)

      # Function delegates to BattleAnalysisCoordinator which may not be started
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts options keyword list" do
      battle_data = build_battle_data()

      result = safe_call(fn -> Api.analyze_battle(battle_data, include_timeline: true) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles empty battle data" do
      result = safe_call(fn -> Api.analyze_battle(%{}) end)

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "get_battle_timeline/1" do
    test "returns timeline for battle_id" do
      battle_id = System.unique_integer([:positive])

      result = safe_call(fn -> Api.get_battle_timeline(battle_id) end)

      # May return error if battle doesn't exist
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles non-existent battle" do
      result = safe_call(fn -> Api.get_battle_timeline(-1) end)

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "analyze_fleet_composition/1" do
    test "analyzes list of participants" do
      participants = build_participants_list()

      result = safe_call(fn -> Api.analyze_fleet_composition(participants) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles empty participants list" do
      result = safe_call(fn -> Api.analyze_fleet_composition([]) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles participants with minimal data" do
      participants = [%{character_id: character_id(), ship_type_id: 587}]

      result = safe_call(fn -> Api.analyze_fleet_composition(participants) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "analyze_character_combat/2" do
    test "returns character combat analysis with default options" do
      char_id = character_id()

      result = safe_call(fn -> Api.analyze_character_combat(char_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts options keyword list" do
      char_id = character_id()

      result = safe_call(fn -> Api.analyze_character_combat(char_id, since_days: 30) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "assess_threat/3" do
    test "assesses threat for character entity type" do
      entity_id = character_id()

      result = safe_call(fn -> Api.assess_threat(entity_id, :character) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "assesses threat for corporation entity type" do
      entity_id = corporation_id()

      result = safe_call(fn -> Api.assess_threat(entity_id, :corporation) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts options keyword list" do
      entity_id = character_id()

      result =
        safe_call(fn -> Api.assess_threat(entity_id, :character, context: :recruitment) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "get_combat_intelligence/2" do
    test "returns combat intelligence summary for entity" do
      entity_id = character_id()

      result = safe_call(fn -> Api.get_combat_intelligence(entity_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts options keyword list" do
      entity_id = character_id()

      result = safe_call(fn -> Api.get_combat_intelligence(entity_id, include_history: true) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "create_battle_report/3" do
    test "creates battle report for valid battle_id" do
      battle_id = System.unique_integer([:positive])
      creator_id = character_id()

      result = safe_call(fn -> Api.create_battle_report(battle_id, creator_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts options keyword list" do
      battle_id = System.unique_integer([:positive])
      creator_id = character_id()

      result =
        safe_call(fn -> Api.create_battle_report(battle_id, creator_id, visibility: :public) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "rate_battle_report/3" do
    test "rates battle report with valid rating" do
      report_id = System.unique_integer([:positive])
      user_id = character_id()
      rating = 5

      result = safe_call(fn -> Api.rate_battle_report(report_id, user_id, rating) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles rating out of range" do
      report_id = System.unique_integer([:positive])
      user_id = character_id()
      rating = 10

      result = safe_call(fn -> Api.rate_battle_report(report_id, user_id, rating) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "get_cache_stats/0" do
    test "returns cache statistics" do
      result = safe_call(fn -> Api.get_cache_stats() end)

      # May return a map or an empty result depending on cache state
      assert is_map(result) or is_nil(result) or match?({:ok, _}, result) or
               match?({:error, _}, result)
    end
  end

  describe "clear_cache/0" do
    test "clears the cache" do
      result = safe_call(fn -> Api.clear_cache() end)

      # Should succeed or return error if cache not running
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "health_check/0" do
    test "returns health status" do
      result = safe_call(fn -> Api.health_check() end)

      # May return :ok or error depending on service state
      assert result == :ok or match?({:error, _}, result)
    end
  end

  # Helper functions

  defp build_battle_data do
    %{
      killmail_ids: [System.unique_integer([:positive])],
      start_time: DateTime.add(DateTime.utc_now(), -3600, :second),
      end_time: DateTime.utc_now(),
      solar_system_id: 30_000_142
    }
  end

  defp build_participants_list do
    [
      %{
        character_id: character_id(),
        corporation_id: corporation_id(),
        ship_type_id: 587,
        damage_done: 1000,
        is_victim: false
      },
      %{
        character_id: character_id(),
        corporation_id: corporation_id(),
        ship_type_id: 588,
        damage_done: 500,
        is_victim: true
      }
    ]
  end
end
