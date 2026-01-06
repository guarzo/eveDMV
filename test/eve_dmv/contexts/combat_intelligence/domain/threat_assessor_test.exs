defmodule EveDmv.Contexts.CombatIntelligence.Domain.ThreatAssessorTest do
  @moduledoc """
  Tests for the ThreatAssessor domain module.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.CombatIntelligence.Domain.ThreatAssessor

  describe "assess_threat/2" do
    test "returns threat assessment for general context" do
      character_id = character_id()

      result = ThreatAssessor.assess_threat(character_id, :general)

      assert {:ok, assessment} = result
      assert assessment.character_id == character_id
      assert assessment.threat_level == :medium
      assert is_float(assessment.threat_score)
      assert is_map(assessment.factors)
      assert is_list(assessment.recommendations)
      assert %DateTime{} = assessment.assessed_at
    end

    test "returns threat assessment for recruitment context" do
      character_id = character_id()

      result = ThreatAssessor.assess_threat(character_id, :recruitment)

      assert {:ok, assessment} = result
      assert assessment.character_id == character_id
      assert assessment.threat_level == :low
      assert Map.has_key?(assessment, :awox_risk)
      assert is_map(assessment.factors)
    end

    test "returns threat assessment for wormhole_operations context" do
      character_id = character_id()

      result = ThreatAssessor.assess_threat(character_id, :wormhole_operations)

      assert {:ok, assessment} = result
      assert assessment.character_id == character_id
      assert assessment.threat_level == :high
      assert Map.has_key?(assessment.factors, :wormhole_experience)
      assert Map.has_key?(assessment.factors, :hunter_effectiveness)
    end

    test "returns threat assessment for fleet_operations context" do
      character_id = character_id()

      result = ThreatAssessor.assess_threat(character_id, :fleet_operations)

      assert {:ok, assessment} = result
      assert assessment.character_id == character_id
      assert assessment.threat_level == :medium
      assert Map.has_key?(assessment.factors, :fleet_command_experience)
      assert Map.has_key?(assessment.factors, :reliability)
    end

    test "defaults to general context for unknown context" do
      character_id = character_id()

      result = ThreatAssessor.assess_threat(character_id, :unknown_context)

      assert {:ok, assessment} = result
      assert assessment.threat_level == :medium
    end
  end

  describe "get_assessment/1" do
    test "returns assessment, triggering new analysis if not cached" do
      character_id = character_id()

      result = ThreatAssessor.get_assessment(character_id)

      assert {:ok, assessment} = result
      assert assessment.character_id == character_id
      assert is_map(assessment.factors)
    end

    test "returns cached assessment if available" do
      character_id = character_id()

      # First call to populate cache
      {:ok, first_assessment} = ThreatAssessor.assess_threat(character_id, :general)

      # Second call should return cached
      {:ok, cached_assessment} = ThreatAssessor.get_assessment(character_id)

      assert first_assessment.character_id == cached_assessment.character_id
      assert first_assessment.threat_level == cached_assessment.threat_level
    end
  end

  describe "refresh_assessment/1" do
    test "invalidates cache and returns fresh assessment" do
      character_id = character_id()

      # First assessment
      {:ok, first_assessment} = ThreatAssessor.assess_threat(character_id, :general)

      # Refresh
      {:ok, refreshed_assessment} = ThreatAssessor.refresh_assessment(character_id)

      assert refreshed_assessment.character_id == character_id
      assert is_map(refreshed_assessment.factors)
      # Refreshed should have newer timestamp
      assert DateTime.compare(refreshed_assessment.assessed_at, first_assessment.assessed_at) in [
               :gt,
               :eq
             ]
    end
  end

  describe "batch_assess_threats/2" do
    test "assesses multiple characters in batch" do
      character_ids = [character_id(), character_id(), character_id()]

      result = ThreatAssessor.batch_assess_threats(character_ids, :general)

      assert {:ok, assessments} = result
      assert is_map(assessments)
      assert map_size(assessments) == 3

      Enum.each(character_ids, fn id ->
        assert Map.has_key?(assessments, id)
        assert {:ok, assessment} = Map.get(assessments, id)
        assert assessment.character_id == id
      end)
    end

    test "handles empty list" do
      result = ThreatAssessor.batch_assess_threats([], :general)

      assert {:ok, assessments} = result
      assert assessments == %{}
    end

    test "works with different contexts" do
      character_ids = [character_id(), character_id()]

      {:ok, recruitment_assessments} =
        ThreatAssessor.batch_assess_threats(character_ids, :recruitment)

      {:ok, wh_assessments} =
        ThreatAssessor.batch_assess_threats(character_ids, :wormhole_operations)

      # Recruitment should have lower threat level generally
      Enum.each(character_ids, fn id ->
        {:ok, recruitment} = Map.get(recruitment_assessments, id)
        {:ok, wh} = Map.get(wh_assessments, id)
        assert recruitment.threat_level == :low
        assert wh.threat_level == :high
      end)
    end
  end

  describe "get_threat_factors/1" do
    test "returns threat factor breakdown for character" do
      character_id = character_id()

      result = ThreatAssessor.get_threat_factors(character_id)

      assert {:ok, factors} = result
      assert factors.character_id == character_id
      assert Map.has_key?(factors, :combat_skills)
      assert Map.has_key?(factors, :kill_death_ratio)
      assert Map.has_key?(factors, :corp_reputation)
      assert Map.has_key?(factors, :behavioral_patterns)
      assert Map.has_key?(factors, :recent_activity)

      # All factors should be numbers between 0 and 1
      assert factors.combat_skills >= 0.0 and factors.combat_skills <= 1.0
      assert factors.kill_death_ratio >= 0.0 and factors.kill_death_ratio <= 1.0
    end
  end

  describe "context-specific assessment factors" do
    test "general context includes combat-focused factors" do
      character_id = character_id()

      {:ok, assessment} = ThreatAssessor.assess_threat(character_id, :general)

      assert Map.has_key?(assessment.factors, :combat_effectiveness)
      assert Map.has_key?(assessment.factors, :aggression_level)
      assert Map.has_key?(assessment.factors, :target_selection)
      assert Map.has_key?(assessment.factors, :fleet_participation)
    end

    test "recruitment context includes loyalty/trust factors" do
      character_id = character_id()

      {:ok, assessment} = ThreatAssessor.assess_threat(character_id, :recruitment)

      assert Map.has_key?(assessment.factors, :corporation_history)
      assert Map.has_key?(assessment.factors, :kill_patterns)
      assert Map.has_key?(assessment.factors, :social_connections)
      assert Map.has_key?(assessment.factors, :character_age)
    end

    test "wormhole context includes J-space specific factors" do
      character_id = character_id()

      {:ok, assessment} = ThreatAssessor.assess_threat(character_id, :wormhole_operations)

      assert Map.has_key?(assessment.factors, :wormhole_experience)
      assert Map.has_key?(assessment.factors, :cloaky_camping_risk)
      assert Map.has_key?(assessment.factors, :hunter_effectiveness)
      assert Map.has_key?(assessment.factors, :chain_mapping_skills)
    end

    test "fleet context includes coordination factors" do
      character_id = character_id()

      {:ok, assessment} = ThreatAssessor.assess_threat(character_id, :fleet_operations)

      assert Map.has_key?(assessment.factors, :fleet_command_experience)
      assert Map.has_key?(assessment.factors, :target_calling_ability)
      assert Map.has_key?(assessment.factors, :coordination_skills)
      assert Map.has_key?(assessment.factors, :reliability)
    end
  end

  describe "recommendations" do
    test "general context provides relevant recommendations" do
      character_id = character_id()

      {:ok, assessment} = ThreatAssessor.assess_threat(character_id, :general)

      assert is_list(assessment.recommendations)
      assert not Enum.empty?(assessment.recommendations)

      Enum.each(assessment.recommendations, fn rec ->
        assert is_binary(rec)
      end)
    end

    test "recruitment context provides vetting recommendations" do
      character_id = character_id()

      {:ok, assessment} = ThreatAssessor.assess_threat(character_id, :recruitment)

      recommendations = assessment.recommendations

      # Should contain vetting-related recommendations
      assert Enum.any?(recommendations, &String.contains?(&1, "corporation"))
      assert Enum.any?(recommendations, &String.contains?(&1, "connection"))
    end

    test "wormhole context provides J-space recommendations" do
      character_id = character_id()

      {:ok, assessment} = ThreatAssessor.assess_threat(character_id, :wormhole_operations)

      recommendations = assessment.recommendations

      # Should contain WH-specific recommendations
      assert Enum.any?(recommendations, &String.contains?(&1, "wormhole"))
      assert Enum.any?(recommendations, &String.contains?(&1, "hunter"))
    end
  end
end
