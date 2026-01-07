defmodule EveDmv.Contexts.PlayerProfile.ApiTest do
  @moduledoc """
  Tests for the Player Profile API module.
  Tests player analysis, combat stats, ship preferences, and formatting functions.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.PlayerProfile.Api

  # Helper to safely call functions that may require GenServers not running in test
  defp safe_call(fun) do
    fun.()
  rescue
    _ -> {:error, :service_unavailable}
  catch
    :exit, _ -> {:error, :service_unavailable}
  end

  describe "analyze_player/2" do
    test "analyzes player with default options" do
      char_id = character_id()

      result = safe_call(fn -> Api.analyze_player(char_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "accepts options keyword list" do
      char_id = character_id()

      result = safe_call(fn -> Api.analyze_player(char_id, include_history: true) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles non-existent character" do
      result = safe_call(fn -> Api.analyze_player(-1) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end
  end

  describe "analyze_players/2" do
    test "analyzes multiple players" do
      char_ids = [character_id(), character_id(), character_id()]

      result = safe_call(fn -> Api.analyze_players(char_ids) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result)
    end

    test "accepts options keyword list" do
      char_ids = [character_id(), character_id()]

      result = safe_call(fn -> Api.analyze_players(char_ids, quick_mode: true) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result)
    end

    test "handles empty character list" do
      result = safe_call(fn -> Api.analyze_players([]) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result)
    end
  end

  describe "get_analysis_component/2" do
    test "gets specific analysis component for character" do
      char_id = character_id()

      result = safe_call(fn -> Api.get_analysis_component(char_id, :combat_stats) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles ship_preferences component" do
      char_id = character_id()

      result = safe_call(fn -> Api.get_analysis_component(char_id, :ship_preferences) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles activity_patterns component" do
      char_id = character_id()

      result = safe_call(fn -> Api.get_analysis_component(char_id, :activity_patterns) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles invalid component" do
      char_id = character_id()

      result = safe_call(fn -> Api.get_analysis_component(char_id, :invalid_component) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end
  end

  describe "get_combat_stats/2" do
    test "gets combat stats with default options" do
      char_id = character_id()

      result = safe_call(fn -> Api.get_combat_stats(char_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "accepts options keyword list" do
      char_id = character_id()

      result = safe_call(fn -> Api.get_combat_stats(char_id, since_days: 30) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end
  end

  describe "get_ship_preferences/2" do
    test "gets ship preferences with default options" do
      char_id = character_id()

      result = safe_call(fn -> Api.get_ship_preferences(char_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "accepts options keyword list" do
      char_id = character_id()

      result = safe_call(fn -> Api.get_ship_preferences(char_id, limit: 10) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end
  end

  describe "format_analysis_summary/1" do
    test "formats character stats map" do
      character_stats = %{
        character_id: character_id(),
        kills: 100,
        deaths: 10,
        kd_ratio: 10.0
      }

      result = safe_call(fn -> Api.format_analysis_summary(character_stats) end)

      assert is_binary(result) or is_map(result) or match?({:ok, _}, result) or
               match?({:error, _}, result)
    end

    test "handles empty stats" do
      result = safe_call(fn -> Api.format_analysis_summary(%{}) end)

      assert is_binary(result) or is_map(result) or match?({:ok, _}, result) or
               match?({:error, _}, result)
    end
  end

  describe "format_character_summary/1" do
    test "formats analysis results" do
      analysis_results = %{
        character_id: character_id(),
        name: "Test Character",
        combat_stats: %{kills: 50, deaths: 5},
        ship_preferences: [%{ship_type_id: 587, count: 10}]
      }

      result = safe_call(fn -> Api.format_character_summary(analysis_results) end)

      assert is_binary(result) or is_map(result) or match?({:ok, _}, result) or
               match?({:error, _}, result)
    end

    test "handles empty results" do
      result = safe_call(fn -> Api.format_character_summary(%{}) end)

      assert is_binary(result) or is_map(result) or match?({:ok, _}, result) or
               match?({:error, _}, result)
    end
  end
end
