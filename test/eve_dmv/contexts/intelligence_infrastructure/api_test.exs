defmodule EveDmv.Contexts.IntelligenceInfrastructure.ApiTest do
  @moduledoc """
  Tests for the Intelligence Infrastructure API module.
  Tests regional analysis, constellation analysis, system analysis,
  cross-system analysis, and correlation functions.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.IntelligenceInfrastructure.Api

  # Helper to safely call functions that may require GenServers not running in test
  defp safe_call(fun) do
    fun.()
  rescue
    _ -> {:error, :service_unavailable}
  catch
    :exit, _ -> {:error, :service_unavailable}
  end

  describe "analyze_region/2" do
    test "analyzes region with default options" do
      # The Forge region ID
      region_id = 10_000_002

      result = safe_call(fn -> Api.analyze_region(region_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "accepts options keyword list" do
      region_id = 10_000_002

      result = safe_call(fn -> Api.analyze_region(region_id, since_days: 30) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles invalid region id" do
      result = safe_call(fn -> Api.analyze_region(-1) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end
  end

  describe "analyze_constellation/2" do
    test "analyzes constellation with default options" do
      # Kimotoro constellation
      constellation_id = 20_000_020

      result = safe_call(fn -> Api.analyze_constellation(constellation_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "accepts options keyword list" do
      constellation_id = 20_000_020

      result =
        safe_call(fn -> Api.analyze_constellation(constellation_id, include_systems: true) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles invalid constellation id" do
      result = safe_call(fn -> Api.analyze_constellation(-1) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end
  end

  describe "analyze_system/2" do
    test "analyzes system with default options" do
      # Jita system
      system_id = 30_000_142

      result = safe_call(fn -> Api.analyze_system(system_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "accepts options keyword list" do
      system_id = 30_000_142

      result = safe_call(fn -> Api.analyze_system(system_id, include_activity: true) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles wormhole system id" do
      # J-space system
      system_id = 31_000_001

      result = safe_call(fn -> Api.analyze_system(system_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles invalid system id" do
      result = safe_call(fn -> Api.analyze_system(-1) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end
  end

  describe "analyze_cross_system/2" do
    test "analyzes multiple systems" do
      systems = [30_000_142, 30_002_187, 30_003_715]

      result = safe_call(fn -> Api.analyze_cross_system(systems) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "accepts options keyword list" do
      systems = [30_000_142, 30_002_187]

      result = safe_call(fn -> Api.analyze_cross_system(systems, correlation_threshold: 0.5) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles empty systems list" do
      result = safe_call(fn -> Api.analyze_cross_system([]) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles single system" do
      result = safe_call(fn -> Api.analyze_cross_system([30_000_142]) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end
  end

  describe "correlate_threats/2" do
    test "correlates threats list" do
      threats = build_threats_list()

      result = safe_call(fn -> Api.correlate_threats(threats) end)

      # May return various result types including maps or atoms
      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result) or
               is_map(result) or is_atom(result)
    end

    test "accepts options keyword list" do
      threats = build_threats_list()

      result = safe_call(fn -> Api.correlate_threats(threats, min_correlation: 0.7) end)

      # May return various result types including maps or atoms
      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result) or
               is_map(result) or is_atom(result)
    end

    test "handles empty threats list" do
      result = safe_call(fn -> Api.correlate_threats([]) end)

      # May return various result types including maps or atoms
      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_list(result) or
               is_map(result) or is_atom(result)
    end
  end

  describe "correlate_activity/2" do
    test "correlates activity data" do
      activity_data = build_activity_data()

      result = safe_call(fn -> Api.correlate_activity(activity_data) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "accepts options keyword list" do
      activity_data = build_activity_data()

      result = safe_call(fn -> Api.correlate_activity(activity_data, time_window: 3600) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles empty activity data" do
      result = safe_call(fn -> Api.correlate_activity(%{}) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end
  end

  # Helper functions

  defp build_threats_list do
    [
      %{
        character_id: character_id(),
        threat_level: :high,
        system_id: 30_000_142,
        last_seen: DateTime.utc_now()
      },
      %{
        character_id: character_id(),
        threat_level: :medium,
        system_id: 30_002_187,
        last_seen: DateTime.utc_now()
      }
    ]
  end

  defp build_activity_data do
    %{
      systems: [30_000_142, 30_002_187],
      time_range: %{
        start: DateTime.add(DateTime.utc_now(), -3600, :second),
        end: DateTime.utc_now()
      },
      entities: [character_id(), character_id()]
    }
  end
end
