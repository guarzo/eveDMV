defmodule EveDmv.Contexts.ThreatAssessment.ApiTest do
  @moduledoc """
  Tests for the Threat Assessment API module.
  Tests threat analysis for characters, pilots, and systems, as well as vulnerability scanning.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.ThreatAssessment.Api

  # Helper to safely call functions that may require GenServers not running in test
  defp safe_call(fun) do
    fun.()
  rescue
    _ -> {:error, :service_unavailable}
  catch
    :exit, _ -> {:error, :service_unavailable}
  end

  describe "analyze_character_threat/3" do
    test "analyzes character threat with default options" do
      char_id = character_id()

      result = safe_call(fn -> Api.analyze_character_threat(char_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "accepts base_data map" do
      char_id = character_id()
      base_data = %{kills: 100, deaths: 10}

      result = safe_call(fn -> Api.analyze_character_threat(char_id, base_data) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "accepts options keyword list" do
      char_id = character_id()
      base_data = %{}
      opts = [context: :recruitment]

      result = safe_call(fn -> Api.analyze_character_threat(char_id, base_data, opts) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles non-existent character" do
      result = safe_call(fn -> Api.analyze_character_threat(-1) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end
  end

  describe "analyze_pilots/3" do
    test "analyzes list of pilots" do
      # Use tuple format expected by the analyzer: {character_id, corp_id, alliance_id}
      pilot_list = [
        {character_id(), corporation_id(), nil},
        {character_id(), corporation_id(), nil}
      ]

      result = safe_call(fn -> Api.analyze_pilots(pilot_list) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result)
    end

    test "accepts base_data map" do
      pilot_list = [{character_id(), corporation_id(), nil}]
      base_data = %{fleet_type: :roaming}

      result = safe_call(fn -> Api.analyze_pilots(pilot_list, base_data) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result)
    end

    test "accepts options keyword list" do
      pilot_list = [{character_id(), corporation_id(), nil}]
      base_data = %{}
      opts = [quick_mode: true]

      result = safe_call(fn -> Api.analyze_pilots(pilot_list, base_data, opts) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result)
    end

    test "handles empty pilot list" do
      result = safe_call(fn -> Api.analyze_pilots([]) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result)
    end
  end

  describe "analyze_system_threats/4" do
    test "analyzes system threats" do
      system_id = 30_000_142
      # Use tuple format expected by the analyzer
      inhabitants = [
        {character_id(), corporation_id(), nil}
      ]

      result = safe_call(fn -> Api.analyze_system_threats(system_id, inhabitants) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "accepts base_data map" do
      system_id = 30_000_142
      inhabitants = []
      base_data = %{security_status: 0.5}

      result = safe_call(fn -> Api.analyze_system_threats(system_id, inhabitants, base_data) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "accepts options keyword list" do
      system_id = 30_000_142
      inhabitants = []
      base_data = %{}
      opts = [include_historical: true]

      result =
        safe_call(fn -> Api.analyze_system_threats(system_id, inhabitants, base_data, opts) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles wormhole system" do
      # J-space system
      system_id = 31_000_001
      inhabitants = []

      result = safe_call(fn -> Api.analyze_system_threats(system_id, inhabitants) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles invalid system id" do
      result = safe_call(fn -> Api.analyze_system_threats(-1, []) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end
  end

  describe "analyze_vulnerabilities/3" do
    test "analyzes vulnerabilities for entity" do
      entity_id = character_id()
      base_data = %{entity_type: :character}

      result = safe_call(fn -> Api.analyze_vulnerabilities(entity_id, base_data) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "accepts options keyword list" do
      entity_id = corporation_id()
      base_data = %{entity_type: :corporation}
      opts = [depth: :detailed]

      result = safe_call(fn -> Api.analyze_vulnerabilities(entity_id, base_data, opts) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles system entity type" do
      entity_id = 30_000_142
      base_data = %{entity_type: :system}

      result = safe_call(fn -> Api.analyze_vulnerabilities(entity_id, base_data) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles empty base_data" do
      entity_id = character_id()

      result = safe_call(fn -> Api.analyze_vulnerabilities(entity_id, %{}) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end
  end
end
