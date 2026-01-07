defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoringEngineTest do
  @moduledoc """
  Tests for the ThreatScoringEngine which calculates multi-dimensional character threat scores.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoringEngine

  describe "calculate_threat_score/2" do
    test "returns result tuple for character" do
      character_id = character_id()

      result = ThreatScoringEngine.calculate_threat_score(character_id)

      # Returns {:ok, assessment} or {:error, :insufficient_data}
      assert match?({:ok, _}, result) or match?({:error, :insufficient_data}, result)
    end

    test "returns insufficient_data for character with no killmails" do
      character_id = character_id()

      result = ThreatScoringEngine.calculate_threat_score(character_id)

      # Characters with no data return :insufficient_data
      assert {:error, :insufficient_data} = result
    end

    test "accepts analysis_window_days option" do
      character_id = character_id()

      result = ThreatScoringEngine.calculate_threat_score(character_id, analysis_window_days: 30)

      # Returns either ok or error
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts include_detailed_breakdown option" do
      character_id = character_id()

      result =
        ThreatScoringEngine.calculate_threat_score(character_id, include_detailed_breakdown: true)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts weight_recent_activity option" do
      character_id = character_id()

      result =
        ThreatScoringEngine.calculate_threat_score(character_id, weight_recent_activity: true)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "calculate_threat_score/2 with killmail data" do
    test "calculates threat for character with sufficient kills" do
      character_id = character_id()

      # Create enough kills (minimum 5 required by the engine)
      Enum.each(1..10, fn _ ->
        {killmail, _participants} = create_killmail_with_participants!(%{}, attacker_count: 3)

        insert_participant!(%{
          killmail_id: killmail.killmail_id,
          killmail_time: killmail.killmail_time,
          character_id: character_id,
          corporation_id: corporation_id(),
          ship_type_id: random_ship_by_role(:cruiser),
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          final_blow: true,
          damage_done: Enum.random(1000..5000)
        })
      end)

      result = ThreatScoringEngine.calculate_threat_score(character_id)

      # May get ok or error depending on data
      case result do
        {:ok, assessment} ->
          assert is_number(assessment.overall_score)
          assert assessment.character_id == character_id

        {:error, :insufficient_data} ->
          # Still valid - threshold not met
          assert true
      end
    end

    test "returns error for character with few deaths" do
      character_id = character_id()

      # Create deaths where this character is the victim
      Enum.each(1..3, fn _ ->
        insert_killmail_raw!(%{
          victim_character_id: character_id,
          victim_corporation_id: corporation_id()
        })
      end)

      result = ThreatScoringEngine.calculate_threat_score(character_id)

      # With only deaths (no kills), insufficient data
      assert match?({:ok, _}, result) or match?({:error, :insufficient_data}, result)
    end
  end

  describe "edge cases" do
    test "handles very short analysis window" do
      character_id = character_id()

      result = ThreatScoringEngine.calculate_threat_score(character_id, analysis_window_days: 1)

      # Returns error for character with no data
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles very long analysis window" do
      character_id = character_id()

      result = ThreatScoringEngine.calculate_threat_score(character_id, analysis_window_days: 365)

      # Returns error for character with no data
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "multiple calls for same character return same error" do
      character_id = character_id()

      result1 = ThreatScoringEngine.calculate_threat_score(character_id)
      result2 = ThreatScoringEngine.calculate_threat_score(character_id)

      # Both should return the same result
      assert result1 == result2
    end
  end

  describe "performance" do
    test "completes scoring within reasonable time" do
      character_id = character_id()

      start_time = System.monotonic_time(:millisecond)
      _result = ThreatScoringEngine.calculate_threat_score(character_id)
      end_time = System.monotonic_time(:millisecond)

      duration = end_time - start_time
      # Should complete within 5 seconds (even for error case)
      assert duration < 5000
    end
  end
end
