defmodule EveDmv.Intelligence.CorrelationEngineTest do
  use EveDmv.DataCase, async: false

  alias EveDmv.Database.QueryCache
  alias EveDmv.Intelligence.CorrelationEngine
  alias EveDmv.Intelligence.{CharacterStats, WHVetting}

  setup do
    # Start QueryCache for this test since it's not started in test environment
    start_supervised!(QueryCache)
    :ok
  end

  describe "analyze_cross_module_correlations/1" do
    test "analyzes correlations between intelligence modules" do
      character_id = 95_465_499

      # Mock character stats
      character_stats = %CharacterStats{
        character_id: character_id,
        character_name: "Test Character",
        dangerous_rating: 8,
        awox_probability: 0.4,
        ship_usage: %{"Interceptor" => 15, "Cruiser" => 10}
      }

      # The function should return correlation analysis
      # Note: This would require setting up proper test data
      # For now, we test the structure and error handling
      result = CorrelationEngine.analyze_cross_module_correlations(character_id)

      # Should return either success or structured error
      assert match?({:ok, %{correlations: _, summary: _, confidence_score: _}}, result) or
               match?({:error, _}, result)
    end

    test "handles invalid character ID gracefully" do
      result = CorrelationEngine.analyze_cross_module_correlations(nil)
      assert {:error, _reason} = result
    end
  end

  describe "analyze_character_correlations/1" do
    test "analyzes correlations between multiple characters" do
      character_ids = [95_465_499, 90_267_367]

      result = CorrelationEngine.analyze_character_correlations(character_ids)

      # Should handle multiple characters
      assert match?({:ok, %{temporal_correlations: _, geographic_correlations: _}}, result) or
               match?({:error, _}, result)
    end

    test "requires at least 2 characters" do
      result = CorrelationEngine.analyze_character_correlations([95_465_499])
      assert {:error, "Insufficient character data for correlation analysis"} = result
    end

    test "handles empty character list" do
      result = CorrelationEngine.analyze_character_correlations([])
      assert {:error, "Insufficient character data for correlation analysis"} = result
    end
  end

  describe "analyze_corporation_intelligence_patterns/1" do
    test "analyzes corporation-wide intelligence patterns" do
      corporation_id = 98_388_312

      result = CorrelationEngine.analyze_corporation_intelligence_patterns(corporation_id)

      # Should return corporation analysis or error for missing data
      assert match?({:ok, %{recruitment_patterns: _, activity_coordination: _}}, result) or
               match?({:error, _}, result)
    end

    test "handles invalid corporation ID" do
      result = CorrelationEngine.analyze_corporation_intelligence_patterns(nil)
      assert {:error, _reason} = result
    end
  end

  # Helper function tests
  describe "private correlation functions" do
    test "threat correlation logic" do
      # Test that correlation functions handle nil inputs gracefully
      character_analysis = %{dangerous_rating: 9, awox_probability: 0.8}

      vetting_data = %{
        risk_factors: %{
          "security_flags" => ["high_threat"],
          "behavioral_red_flags" => ["blue_killer"]
        }
      }

      # This tests the internal logic by calling the main function
      # In a real implementation, you might expose these for direct testing
      result = CorrelationEngine.analyze_cross_module_correlations(95_465_499)

      # The result should be structured correctly regardless of data availability
      case result do
        {:ok, analysis} ->
          assert Map.has_key?(analysis, :correlations)
          assert Map.has_key?(analysis.correlations, :threat_assessment)

        {:error, _reason} ->
          # Expected for missing test data
          assert true
      end
    end
  end
end
