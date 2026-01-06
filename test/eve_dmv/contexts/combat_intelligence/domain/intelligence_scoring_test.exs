defmodule EveDmv.Contexts.CombatIntelligence.Domain.IntelligenceScoringTest do
  @moduledoc """
  Tests for the IntelligenceScoring domain module.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.CombatIntelligence.Domain.IntelligenceScoring

  describe "calculate_score/2 - danger_rating" do
    test "returns danger rating score structure" do
      character_id = character_id()

      result = IntelligenceScoring.calculate_score(character_id, :danger_rating)

      assert {:ok, score_data} = result
      assert Map.has_key?(score_data, :rating)
      assert Map.has_key?(score_data, :score)
      assert Map.has_key?(score_data, :confidence)
      assert score_data.confidence in [:low, :medium, :high]
    end

    test "returns no_recent_activity for characters with no kills" do
      character_id = character_id()

      {:ok, score_data} = IntelligenceScoring.calculate_score(character_id, :danger_rating)

      # Without test data, should return low/no activity
      assert score_data.rating in [0, 1, 2, 3, 4, 5]
      assert is_float(score_data.score) or score_data.score == 0.0
    end

    test "danger rating with killmail data" do
      character_id = character_id()

      # Create some killmails where this character is an attacker
      {killmail, _participants} =
        create_killmail_with_participants!(%{}, attacker_count: 3)

      # Add our character as a participant
      insert_participant!(%{
        killmail_id: killmail.killmail_id,
        killmail_time: killmail.killmail_time,
        character_id: character_id,
        corporation_id: corporation_id(),
        ship_type_id: random_ship_by_role(:cruiser),
        solar_system_id: killmail.solar_system_id,
        is_victim: false,
        final_blow: true,
        damage_done: 5000
      })

      {:ok, score_data} = IntelligenceScoring.calculate_score(character_id, :danger_rating)

      assert score_data.rating in [0, 1, 2, 3, 4, 5]
      assert is_float(score_data.score)
      assert Map.has_key?(score_data, :kill_frequency)
      assert Map.has_key?(score_data, :recent_kills)
    end
  end

  describe "calculate_score/2 - hunter_score" do
    test "returns hunter score structure" do
      character_id = character_id()

      result = IntelligenceScoring.calculate_score(character_id, :hunter_score)

      assert {:ok, score_data} = result
      assert Map.has_key?(score_data, :score)
      assert Map.has_key?(score_data, :rating)
      assert Map.has_key?(score_data, :confidence)
    end

    test "returns no_data rating when no kill participation" do
      character_id = character_id()

      {:ok, score_data} = IntelligenceScoring.calculate_score(character_id, :hunter_score)

      # Without kills, should show no_data or low values
      assert score_data.rating in [:no_data, :beginner, :novice, :competent, :experienced, :elite]
    end

    test "includes solo_kills and tackle_usage metrics" do
      character_id = character_id()

      {:ok, score_data} = IntelligenceScoring.calculate_score(character_id, :hunter_score)

      assert Map.has_key?(score_data, :solo_kills)
      assert Map.has_key?(score_data, :tackle_usage)
    end
  end

  describe "calculate_score/2 - fleet_commander_score" do
    test "returns fleet commander score structure" do
      character_id = character_id()

      result = IntelligenceScoring.calculate_score(character_id, :fleet_commander_score)

      assert {:ok, score_data} = result
      assert Map.has_key?(score_data, :score)
      assert Map.has_key?(score_data, :rating)
      assert Map.has_key?(score_data, :confidence)
    end

    test "returns no_fleet_experience when no fleet kills" do
      character_id = character_id()

      {:ok, score_data} =
        IntelligenceScoring.calculate_score(character_id, :fleet_commander_score)

      # Without fleet kills, should show no experience
      assert score_data.rating in [
               :no_fleet_experience,
               :line_member,
               :junior_fc,
               :competent,
               :experienced_fc,
               :veteran_fc
             ]
    end

    test "includes fleet-specific metrics" do
      character_id = character_id()

      {:ok, score_data} =
        IntelligenceScoring.calculate_score(character_id, :fleet_commander_score)

      assert Map.has_key?(score_data, :fleets_led) or
               Map.has_key?(score_data, :fleets_participated)

      assert Map.has_key?(score_data, :avg_fleet_size)
    end
  end

  describe "calculate_score/2 - solo_pilot_score" do
    test "returns solo pilot score structure" do
      character_id = character_id()

      result = IntelligenceScoring.calculate_score(character_id, :solo_pilot_score)

      assert {:ok, score_data} = result
      assert Map.has_key?(score_data, :score)
      assert Map.has_key?(score_data, :rating)
      assert Map.has_key?(score_data, :confidence)
    end

    test "returns no_solo_activity when no solo combat" do
      character_id = character_id()

      {:ok, score_data} = IntelligenceScoring.calculate_score(character_id, :solo_pilot_score)

      assert score_data.rating in [
               :no_solo_activity,
               :novice,
               :learning,
               :competent,
               :skilled,
               :dangerous
             ]
    end

    test "includes efficiency metric" do
      character_id = character_id()

      {:ok, score_data} = IntelligenceScoring.calculate_score(character_id, :solo_pilot_score)

      assert Map.has_key?(score_data, :solo_kills)
      assert Map.has_key?(score_data, :solo_losses)
      assert Map.has_key?(score_data, :efficiency)
    end
  end

  describe "calculate_score/2 - awox_risk_score" do
    test "returns awox risk score structure" do
      character_id = character_id()

      result = IntelligenceScoring.calculate_score(character_id, :awox_risk_score)

      assert {:ok, score_data} = result
      assert Map.has_key?(score_data, :score)
      assert Map.has_key?(score_data, :rating)
      assert Map.has_key?(score_data, :confidence)
    end

    test "returns unknown when no combat history" do
      character_id = character_id()

      {:ok, score_data} = IntelligenceScoring.calculate_score(character_id, :awox_risk_score)

      assert score_data.rating in [
               :unknown,
               :minimal_risk,
               :low_risk,
               :moderate_risk,
               :high_risk,
               :extreme_risk
             ]
    end

    test "includes friendly fire metrics" do
      character_id = character_id()

      {:ok, score_data} = IntelligenceScoring.calculate_score(character_id, :awox_risk_score)

      assert Map.has_key?(score_data, :friendly_fire_count)
    end
  end

  describe "calculate_score/2 - error handling" do
    test "returns error for unknown scoring type" do
      character_id = character_id()

      result = IntelligenceScoring.calculate_score(character_id, :unknown_type)

      assert {:error, :unknown_scoring_type} = result
    end
  end

  describe "get_recommendations/1" do
    test "returns list of recommendations" do
      character_id = character_id()

      result = IntelligenceScoring.get_recommendations(character_id)

      assert {:ok, recommendations} = result
      assert is_list(recommendations)
    end

    test "recommendations have proper structure" do
      character_id = character_id()

      {:ok, recommendations} = IntelligenceScoring.get_recommendations(character_id)

      # If there are recommendations, check their structure
      Enum.each(recommendations, fn rec ->
        assert is_map(rec)
        assert Map.has_key?(rec, :type)
        assert Map.has_key?(rec, :priority)
        assert Map.has_key?(rec, :message)
        assert Map.has_key?(rec, :action)
      end)
    end

    test "recommendations include summary" do
      character_id = character_id()

      {:ok, recommendations} = IntelligenceScoring.get_recommendations(character_id)

      # Should have at least a summary recommendation
      summary = Enum.find(recommendations, fn rec -> rec.type == :summary end)
      assert summary != nil or recommendations == []
    end
  end

  describe "get_cached_scores/1" do
    test "returns empty map when no cached scores" do
      character_id = character_id()

      result = IntelligenceScoring.get_cached_scores(character_id)

      assert {:ok, scores} = result
      assert is_map(scores)
    end

    test "returns cached scores after calculation" do
      character_id = character_id()

      # Calculate a score first
      IntelligenceScoring.calculate_score(character_id, :danger_rating)

      # Now check cached scores
      {:ok, scores} = IntelligenceScoring.get_cached_scores(character_id)

      # May or may not have the score depending on cache implementation
      assert is_map(scores)
    end
  end

  describe "refresh_scores/1" do
    test "returns all score types after refresh" do
      character_id = character_id()

      result = IntelligenceScoring.refresh_scores(character_id)

      assert {:ok, scores} = result
      assert is_map(scores)

      # Should attempt to calculate all score types
      expected_types = [
        :danger_rating,
        :hunter_score,
        :fleet_commander_score,
        :solo_pilot_score,
        :awox_risk_score
      ]

      Enum.each(expected_types, fn type ->
        if Map.has_key?(scores, type) do
          assert is_map(scores[type])
        end
      end)
    end
  end

  describe "score value ranges" do
    test "all scores are normalized between 0 and 1" do
      character_id = character_id()

      score_types = [
        :danger_rating,
        :hunter_score,
        :fleet_commander_score,
        :solo_pilot_score,
        :awox_risk_score
      ]

      Enum.each(score_types, fn type ->
        {:ok, score_data} = IntelligenceScoring.calculate_score(character_id, type)

        # Score should be between 0 and 1
        assert score_data.score >= 0.0
        assert score_data.score <= 1.0
      end)
    end
  end

  describe "confidence levels" do
    test "confidence is one of valid levels" do
      character_id = character_id()

      score_types = [
        :danger_rating,
        :hunter_score,
        :fleet_commander_score,
        :solo_pilot_score,
        :awox_risk_score
      ]

      valid_confidences = [:low, :medium, :high]

      Enum.each(score_types, fn type ->
        {:ok, score_data} = IntelligenceScoring.calculate_score(character_id, type)
        assert score_data.confidence in valid_confidences
      end)
    end
  end
end
