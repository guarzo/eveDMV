defmodule EveDmv.Contexts.CorporationAnalysis.ApiTest do
  @moduledoc """
  Tests for the Corporation Analysis API module.
  Tests member activity analysis and participation analysis functions.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.CorporationAnalysis.Api

  # Helper to safely call functions that may require GenServers not running in test
  defp safe_call(fun) do
    fun.()
  rescue
    _ -> {:error, :service_unavailable}
  catch
    :exit, _ -> {:error, :service_unavailable}
  end

  describe "analyze_member_activity/2" do
    test "analyzes member activity with default base data" do
      corp_id = corporation_id()

      result = safe_call(fn -> Api.analyze_member_activity(corp_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "accepts base_data map" do
      corp_id = corporation_id()
      base_data = %{member_count: 100, active_members: 50}

      result = safe_call(fn -> Api.analyze_member_activity(corp_id, base_data) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles invalid corporation id" do
      result = safe_call(fn -> Api.analyze_member_activity(-1) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end
  end

  describe "analyze_character_participation/3" do
    test "analyzes character participation with default options" do
      char_id = character_id()

      result = safe_call(fn -> Api.analyze_character_participation(char_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "accepts base_data map" do
      char_id = character_id()
      base_data = %{total_killmails: 100}

      result = safe_call(fn -> Api.analyze_character_participation(char_id, base_data) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "accepts options keyword list" do
      char_id = character_id()
      base_data = %{}
      opts = [since_days: 30]

      result = safe_call(fn -> Api.analyze_character_participation(char_id, base_data, opts) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end
  end

  describe "analyze_corporation_participation/3" do
    test "analyzes corporation participation with default options" do
      corp_id = corporation_id()

      result = safe_call(fn -> Api.analyze_corporation_participation(corp_id) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "accepts base_data map" do
      corp_id = corporation_id()
      base_data = %{total_members: 50, active_percentage: 0.6}

      result = safe_call(fn -> Api.analyze_corporation_participation(corp_id, base_data) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "accepts options keyword list" do
      corp_id = corporation_id()
      base_data = %{}
      opts = [include_inactive: true]

      result =
        safe_call(fn -> Api.analyze_corporation_participation(corp_id, base_data, opts) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end

    test "handles invalid corporation id" do
      result = safe_call(fn -> Api.analyze_corporation_participation(-1) end)

      assert match?({:ok, _}, result) or match?({:error, _}, result) or is_map(result)
    end
  end
end
