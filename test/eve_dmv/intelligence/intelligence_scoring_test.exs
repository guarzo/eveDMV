defmodule EveDmv.Intelligence.IntelligenceScoringTest do
  use EveDmv.IntelligenceCase, async: true

  alias EveDmv.Intelligence.IntelligenceScoring

  describe "calculate_comprehensive_score/1" do
    test "calculates comprehensive score for character with complete data" do
      character_id = 123_456_789

      # Create realistic test data
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id,
        count: 20,
        days_back: 90
      )

      EveDmv.IntelligenceCase.create_wormhole_activity(character_id, "C5",
        count: 8,
        role: :hunter
      )

      # Create character stats that the scoring functions need
      EveDmv.IntelligenceCase.create_character_stats(character_id)
      EveDmv.IntelligenceCase.create_mock_analytics_data(character_id)

      assert {:ok, score_data} = IntelligenceScoring.calculate_comprehensive_score(character_id)

      assert is_float(score_data.overall_score)
      assert score_data.overall_score >= 0.0
      assert score_data.overall_score <= 10.0
      assert score_data.score_grade in ["A+", "A", "A-", "B+", "B", "B-", "C+", "C", "C-", "D", "F"]
      assert is_map(score_data.component_scores)
      assert score_data.scoring_methodology
      assert is_float(score_data.confidence_level)
      assert score_data.confidence_level >= 0.0
      assert score_data.confidence_level <= 1.0
      assert is_list(score_data.recommendations)
      assert score_data.analysis_timestamp
    end

    test "handles character with limited data" do
      character_id = 555_666_777

      # Create minimal test data
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 3, days_back: 30)

      # Create character stats that the scoring functions need with inconsistent data for high variance
      EveDmv.IntelligenceCase.create_character_stats(character_id, 
        kill_count: 3, 
        loss_count: 2,
        # Create inconsistent patterns to increase variance in component scores
        aggression_index: 1.0,  # Very low
        avg_gang_size: 1.0,     # Solo player
        isk_efficiency: 30.0,   # Poor efficiency
        dangerous_rating: 1     # Low danger
      )
      
      # Create mock analytics data with lower confidence for limited data
      limited_behavioral_analysis = %{
        confidence_score: 0.2,  # Very low confidence for limited data
        patterns: %{
          anomaly_detection: %{anomaly_count: 3},  # More anomalies = lower confidence
          activity_rhythm: %{consistency_score: 0.1},
          operational_patterns: %{strategic_thinking: 0.1},
          risk_progression: %{stability_score: 0.1}
        }
      }
      
      limited_threat_assessment = %{
        threat_score: 0.2,
        threat_level: "low",
        threat_indicators: %{
          combat_effectiveness: 0.3,
          tactical_sophistication: 0.2
        }
      }
      
      limited_risk_analysis = %{
        advanced_risk_score: 0.2
      }
      
      Process.put(:"behavioral_analysis_#{character_id}", limited_behavioral_analysis)
      Process.put(:"threat_assessment_#{character_id}", limited_threat_assessment)
      Process.put(:"risk_analysis_#{character_id}", limited_risk_analysis)

      assert {:ok, score_data} = IntelligenceScoring.calculate_comprehensive_score(character_id)

      assert is_float(score_data.overall_score)
      assert score_data.component_scores
      # Confidence should be calculated from component scores variance
      assert score_data.confidence_level >= 0.0
      assert score_data.confidence_level <= 1.0
    end

    test "returns error for character with no data" do
      character_id = 999_999_999

      assert {:error, _reason} = IntelligenceScoring.calculate_comprehensive_score(character_id)
    end

    test "component scores are within valid ranges" do
      character_id = 123_456_789
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 15)

      # Create character stats that the scoring functions need
      EveDmv.IntelligenceCase.create_character_stats(character_id)

      assert {:ok, score_data} = IntelligenceScoring.calculate_comprehensive_score(character_id)

      # Each component score should be 0-10
      for {component, score} <- score_data.component_scores do
        assert is_float(score), "#{component} should be a float"
        assert score >= 0.0, "#{component} should be >= 0.0"
        assert score <= 10.0, "#{component} should be <= 10.0"
      end
    end
  end

  describe "calculate_recruitment_fitness/2" do
    test "calculates recruitment fitness with default requirements" do
      character_id = 123_456_789
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 15)
      EveDmv.IntelligenceCase.create_wormhole_activity(character_id, "C4", count: 5, role: :mixed)

      # Create character stats that the scoring functions need
      EveDmv.IntelligenceCase.create_character_stats(character_id)

      assert {:ok, fitness_data} = IntelligenceScoring.calculate_recruitment_fitness(character_id)

      assert is_float(fitness_data.recruitment_score)
      assert fitness_data.recruitment_score >= 0.0
      assert fitness_data.recruitment_score <= 10.0

      assert is_map(fitness_data.recruitment_recommendation)
      assert fitness_data.recruitment_recommendation.decision in ["approve", "conditional", "probation", "reject"]

      assert is_map(fitness_data.fitness_components)
      assert is_map(fitness_data.requirement_scores)
      assert is_list(fitness_data.decision_factors)
      assert is_list(fitness_data.probation_recommendations)
      assert fitness_data.analysis_timestamp
    end

    test "calculates recruitment fitness with custom requirements" do
      character_id = 123_456_789
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 10)

      # Create character stats that the scoring functions need
      EveDmv.IntelligenceCase.create_character_stats(character_id)
      EveDmv.IntelligenceCase.create_mock_analytics_data(character_id)

      requirements = %{
        minimum_experience_days: 365,
        minimum_pvp_score: 5.0,
        security_clearance_required: true,
        preferred_timezone: "EU"
      }

      assert {:ok, fitness_data} =
               IntelligenceScoring.calculate_recruitment_fitness(character_id, requirements)

      assert fitness_data.recruitment_score
      assert fitness_data.requirement_scores
      # Should have evaluated against custom requirements
      assert Map.has_key?(fitness_data.requirement_scores, :combat_requirement_met) ||
               Map.has_key?(fitness_data.requirement_scores, :security_requirement_met)
    end

    test "fitness components are within valid ranges" do
      character_id = 123_456_789
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 10)

      # Create character stats that the scoring functions need
      EveDmv.IntelligenceCase.create_character_stats(character_id)

      assert {:ok, fitness_data} = IntelligenceScoring.calculate_recruitment_fitness(character_id)

      # Each fitness component should be 0-10
      for {component, score} <- fitness_data.fitness_components do
        assert is_float(score), "#{component} should be a float"
        assert score >= 0.0, "#{component} should be >= 0.0"
        assert score <= 10.0, "#{component} should be <= 10.0"
      end
    end
  end

  describe "calculate_fleet_readiness/1" do
    test "calculates fleet readiness for multiple characters" do
      character_ids = [123_456_789, 987_654_321, 555_666_777]

      # Create test data for all characters
      for character_id <- character_ids do
        EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 12)

        EveDmv.IntelligenceCase.create_wormhole_activity(character_id, "C4",
          count: 4,
          role: :mixed
        )
        
        EveDmv.IntelligenceCase.create_character_stats(character_id)
        EveDmv.IntelligenceCase.create_mock_analytics_data(character_id)
      end

      assert {:ok, fleet_data} =
               IntelligenceScoring.calculate_fleet_readiness_score(character_ids)

      assert is_float(fleet_data.fleet_readiness_score)
      assert fleet_data.fleet_readiness_score >= 0.0
      assert fleet_data.fleet_readiness_score <= 10.0
      assert fleet_data.fleet_grade in ["A+", "A", "A-", "B+", "B", "B-", "C+", "C", "C-", "D", "F"]
      assert is_map(fleet_data.fleet_metrics)
      assert fleet_data.character_count == length(character_ids)
      assert is_list(fleet_data.optimization_suggestions)
      assert fleet_data.analysis_timestamp
    end

    test "handles insufficient character data gracefully" do
      character_ids = [999_999_999, 888_888_888]

      result = IntelligenceScoring.calculate_fleet_readiness_score(character_ids)
      assert {:error, _reason} = result
    end

    test "filters out characters with no data" do
      character_ids = [123_456_789, 999_999_999, 987_654_321]

      # Create data for only some characters
      EveDmv.IntelligenceCase.create_realistic_killmail_set(123_456_789, count: 10)
      EveDmv.IntelligenceCase.create_realistic_killmail_set(987_654_321, count: 8)
      EveDmv.IntelligenceCase.create_character_stats(123_456_789)
      EveDmv.IntelligenceCase.create_character_stats(987_654_321)
      EveDmv.IntelligenceCase.create_mock_analytics_data(123_456_789)
      EveDmv.IntelligenceCase.create_mock_analytics_data(987_654_321)

      assert {:ok, fleet_data} =
               IntelligenceScoring.calculate_fleet_readiness_score(character_ids)

      # Should only include characters with valid data
      assert fleet_data.character_count >= 2
      assert is_map(fleet_data.fleet_metrics)
      assert fleet_data.fleet_readiness_score >= 0.0
    end
  end

  describe "calculate_intelligence_suitability/1" do
    test "calculates intelligence operation suitability" do
      character_id = 123_456_789

      # Create data suggesting good intelligence capabilities
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 15)

      EveDmv.IntelligenceCase.create_wormhole_activity(character_id, "C6",
        count: 6,
        role: :hunter
      )
      
      EveDmv.IntelligenceCase.create_character_stats(character_id)

      assert {:ok, intel_data} =
               IntelligenceScoring.calculate_intelligence_suitability(character_id)

      assert is_float(intel_data.intelligence_suitability_score)
      assert intel_data.intelligence_suitability_score >= 0.0
      assert intel_data.intelligence_suitability_score <= 10.0
      assert intel_data.suitability_level in ["highly_suitable", "suitable", "conditionally_suitable", "limited_suitability", "not_suitable"]
      assert is_map(intel_data.intel_components)
      assert is_list(intel_data.recommended_roles)
      assert is_list(intel_data.training_recommendations)

      assert intel_data.security_clearance_level in [
               "secret",
               "confidential", 
               "restricted",
               "public"
             ]

      assert intel_data.analysis_timestamp
    end

    test "intel components are within valid ranges" do
      character_id = 123_456_789
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 10)
      EveDmv.IntelligenceCase.create_character_stats(character_id)

      assert {:ok, intel_data} =
               IntelligenceScoring.calculate_intelligence_suitability(character_id)

      # Each intel component should be 0-10
      for {component, score} <- intel_data.intel_components do
        assert is_float(score), "#{component} should be a float"
        assert score >= 0.0, "#{component} should be >= 0.0"
        assert score <= 10.0, "#{component} should be <= 10.0"
      end
    end

    test "returns error for character with insufficient data" do
      character_id = 999_999_999

      assert {:error, _reason} =
               IntelligenceScoring.calculate_intelligence_suitability(character_id)
    end
  end

  describe "edge cases and error handling" do
    test "handles character with only losses" do
      character_id = 123_456_789
      create_pvp_pattern(character_id, :victim, count: 10)
      EveDmv.IntelligenceCase.create_character_stats(character_id, kill_count: 0, loss_count: 10)
      EveDmv.IntelligenceCase.create_mock_analytics_data(character_id)

      assert {:ok, score_data} = IntelligenceScoring.calculate_comprehensive_score(character_id)

      # Should still provide a score, likely lower
      assert is_float(score_data.overall_score)
      assert score_data.overall_score >= 0.0
    end

    test "handles character with only kills" do
      character_id = 123_456_789
      create_pvp_pattern(character_id, :hunter, count: 15)
      EveDmv.IntelligenceCase.create_character_stats(character_id, kill_count: 15, loss_count: 0)
      EveDmv.IntelligenceCase.create_mock_analytics_data(character_id)

      assert {:ok, score_data} = IntelligenceScoring.calculate_comprehensive_score(character_id)

      # Should provide a score, likely higher
      assert is_float(score_data.overall_score)
      assert score_data.overall_score >= 0.0
    end

    test "handles empty character ID list for fleet analysis" do
      assert {:error, "Fleet readiness requires at least 2 characters"} =
               IntelligenceScoring.calculate_fleet_readiness_score([])
    end

    test "handles single character for fleet analysis" do
      character_id = 123_456_789
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 10)

      assert {:error, "Fleet readiness requires at least 2 characters"} =
               IntelligenceScoring.calculate_fleet_readiness_score([character_id])
    end
  end

  describe "scoring consistency" do
    test "repeated calls return consistent scores for same character" do
      character_id = 123_456_789
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 15)
      EveDmv.IntelligenceCase.create_character_stats(character_id)

      assert {:ok, score_data1} = IntelligenceScoring.calculate_comprehensive_score(character_id)
      assert {:ok, score_data2} = IntelligenceScoring.calculate_comprehensive_score(character_id)

      # Scores should be identical for same data
      assert abs(score_data1.overall_score - score_data2.overall_score) < 0.01
    end

    test "more PvP activity generally results in higher scores" do
      character_id_low = 111_111_111
      character_id_high = 222_222_222

      # Low activity character
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id_low,
        count: 3,
        days_back: 90
      )
      EveDmv.IntelligenceCase.create_character_stats(character_id_low, kill_count: 3, loss_count: 2)

      # High activity character
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id_high,
        count: 25,
        days_back: 30
      )

      EveDmv.IntelligenceCase.create_wormhole_activity(character_id_high, "C5",
        count: 10,
        role: :hunter
      )
      EveDmv.IntelligenceCase.create_character_stats(character_id_high, kill_count: 25, loss_count: 5)

      assert {:ok, score_low} =
               IntelligenceScoring.calculate_comprehensive_score(character_id_low)

      assert {:ok, score_high} =
               IntelligenceScoring.calculate_comprehensive_score(character_id_high)

      # High activity should generally result in higher scores
      assert score_high.overall_score >= score_low.overall_score ||
               score_high.confidence_level > score_low.confidence_level
    end
  end
end
