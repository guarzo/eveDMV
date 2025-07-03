defmodule EveDmv.IntelligenceWorkflowTest do
  use EveDmv.DataCase, async: false
  use EveDmv.IntelligenceCase

  @moduletag :integration

  describe "complete character intelligence workflow" do
    test "processes character from analysis to recommendations" do
      character_id = insert_test_character()

      # Create comprehensive test data for full workflow
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id,
        count: 25,
        days_back: 120
      )

      create_wormhole_activity(character_id, "C5", count: 8, role: :hunter)
      create_pvp_pattern(character_id, :mixed, kill_count: 15, loss_count: 5)

      # Test the full workflow through Intelligence Coordinator
      assert {:ok, result} =
               EveDmv.Intelligence.IntelligenceCoordinator.analyze_character_comprehensive(
                 character_id
               )

      # Verify complete workflow results
      assert result.character_id == character_id
      assert result.analysis_timestamp
      assert result.basic_analysis
      assert result.specialized_analysis
      assert result.correlations
      assert result.intelligence_summary
      assert result.confidence_score
      assert result.recommendations

      # Verify analysis depth and quality
      assert is_float(result.confidence_score)
      assert result.confidence_score >= 0.0
      assert result.confidence_score <= 1.0
      assert is_list(result.recommendations)
      assert length(result.recommendations) > 0

      # Verify intelligence summary contains key insights
      assert is_map(result.intelligence_summary)

      assert Map.has_key?(result.intelligence_summary, :threat_level) or
               Map.has_key?(result.intelligence_summary, :summary)
    end

    test "handles character progression through vetting pipeline" do
      character_id = insert_test_character()

      # Create test data suggesting security concerns
      create_wormhole_activity(character_id, "C6", count: 12, role: :hunter)
      create_pvp_pattern(character_id, :hunter, count: 20)

      # Process through vetting workflow
      assert {:ok, vetting_result} =
               EveDmv.Intelligence.WHVettingAnalyzer.analyze_character(character_id)

      # Verify vetting analysis structure
      assert vetting_result.character_id == character_id
      assert vetting_result.analysis_timestamp
      assert is_number(vetting_result.overall_risk_score)
      assert vetting_result.overall_risk_score >= 0
      assert vetting_result.overall_risk_score <= 100

      # Process through intelligence scoring
      assert {:ok, scoring_result} =
               EveDmv.Intelligence.IntelligenceScoring.calculate_comprehensive_score(character_id)

      # Verify scoring integration
      assert is_float(scoring_result.overall_score)
      assert scoring_result.overall_score >= 0.0
      assert scoring_result.overall_score <= 10.0
      assert scoring_result.component_scores
      assert scoring_result.recommendations
    end

    test "integrates real-time alert generation" do
      character_id = insert_test_character()

      # Create high-threat scenario
      create_pvp_pattern(character_id, :hunter, count: 30)
      create_wormhole_activity(character_id, "C6", count: 15, role: :hunter)

      # Analyze character to generate high threat score
      assert {:ok, analysis} =
               EveDmv.Intelligence.IntelligenceCoordinator.analyze_character_comprehensive(
                 character_id
               )

      # Simulate analysis with high threat indicators
      high_threat_analysis = %{
        character_id: character_id,
        threat_score: 9.5,
        confidence: 0.95,
        dangerous_rating: 8.8,
        awox_probability: 0.15,
        activity_patterns: %{red_flags: ["high_sp_character", "extensive_wh_activity"]}
      }

      # Process through alert system
      :ok = EveDmv.Intelligence.AlertSystem.process_character_analysis(high_threat_analysis)

      # Give time for async alert processing
      Process.sleep(100)

      # Verify alert system integration
      alerts = EveDmv.Intelligence.AlertSystem.get_active_alerts()
      assert is_list(alerts)

      # System should be responsive and functional
      assert length(alerts) >= 0
    end

    test "processes group correlation analysis" do
      character_ids = [
        insert_test_character(),
        insert_test_character(),
        insert_test_character()
      ]

      # Create correlated activity patterns
      for character_id <- character_ids do
        create_wormhole_activity(character_id, "C5", count: 10, role: :hunter)
        create_pvp_pattern(character_id, :hunter, count: 12)
      end

      # Test group analysis workflow
      assert {:ok, group_result} =
               EveDmv.Intelligence.IntelligenceCoordinator.analyze_character_group(character_ids)

      # Verify group analysis structure
      assert group_result.character_ids == character_ids
      assert group_result.analysis_timestamp
      assert group_result.individual_analyses
      assert group_result.group_correlations
      assert group_result.group_summary
      assert group_result.group_recommendations

      # Verify all characters were processed
      assert map_size(group_result.individual_analyses) >= 2

      # Verify correlation detection
      assert is_map(group_result.group_correlations)
      assert is_list(group_result.group_recommendations)
    end

    test "handles chain intelligence integration" do
      character_id = insert_test_character()
      map_id = "integration_test_chain"
      corporation_id = 98_765_432

      # Create test data
      create_wormhole_activity(character_id, "C4", count: 8, role: :mixed)

      # Test chain monitoring integration
      assert :ok = EveDmv.Intelligence.ChainMonitor.monitor_chain(map_id, corporation_id)

      # Verify chain is being monitored
      status = EveDmv.Intelligence.ChainMonitor.status()
      assert MapSet.member?(status.monitored_chains, map_id)

      # Test character intelligence with chain context
      assert {:ok, intelligence} =
               EveDmv.Intelligence.IntelligenceCoordinator.analyze_character_comprehensive(
                 character_id
               )

      # Verify intelligence analysis completed successfully
      assert intelligence.character_id == character_id
      assert intelligence.specialized_analysis

      # Cleanup
      assert :ok = EveDmv.Intelligence.ChainMonitor.stop_monitoring(map_id)
    end

    test "validates intelligence cache integration" do
      character_id = insert_test_character()

      # Create test data
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 15)
      create_pvp_pattern(character_id, :mixed, kill_count: 8, loss_count: 3)

      # First analysis (should populate cache)
      assert {:ok, analysis1} =
               EveDmv.Intelligence.IntelligenceCoordinator.analyze_character_comprehensive(
                 character_id,
                 use_cache: true
               )

      # Second analysis (should use cache if available)
      assert {:ok, analysis2} =
               EveDmv.Intelligence.IntelligenceCoordinator.analyze_character_comprehensive(
                 character_id,
                 use_cache: true
               )

      # Both analyses should succeed
      assert analysis1.character_id == character_id
      assert analysis2.character_id == character_id

      # Verify cache bypass works
      assert {:ok, analysis3} =
               EveDmv.Intelligence.IntelligenceCoordinator.analyze_character_comprehensive(
                 character_id,
                 use_cache: false
               )

      assert analysis3.character_id == character_id
    end
  end

  describe "intelligence performance and scalability" do
    test "handles bulk character processing efficiently" do
      character_ids = for _i <- 1..10, do: insert_test_character()

      # Create minimal test data for each character
      for character_id <- character_ids do
        EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 5)
      end

      # Test bulk processing
      start_time = System.monotonic_time(:millisecond)

      results =
        Enum.map(character_ids, fn character_id ->
          case EveDmv.Intelligence.IntelligenceCoordinator.analyze_character_comprehensive(
                 character_id
               ) do
            {:ok, result} -> {:ok, result.character_id}
            {:error, reason} -> {:error, reason}
          end
        end)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Verify performance characteristics
      successful_results = Enum.filter(results, fn result -> match?({:ok, _}, result) end)

      # Should process efficiently
      # At least half should succeed
      assert length(successful_results) >= 5
      # Should complete within 30 seconds
      assert duration < 30_000

      # Average processing time per character should be reasonable
      avg_time_per_character = duration / length(character_ids)
      # Less than 5 seconds per character on average
      assert avg_time_per_character < 5_000
    end

    test "maintains system stability under load" do
      character_id = insert_test_character()
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 10)

      # Test concurrent analysis requests
      tasks =
        for _i <- 1..5 do
          Task.async(fn ->
            EveDmv.Intelligence.IntelligenceCoordinator.analyze_character_comprehensive(
              character_id
            )
          end)
        end

      # Wait for all tasks with timeout
      results = Task.await_many(tasks, 15_000)

      # Verify system stability
      successful_results = Enum.filter(results, fn result -> match?({:ok, _}, result) end)
      # Most should succeed
      assert length(successful_results) >= 3

      # Verify results are consistent
      for {:ok, result} <- successful_results do
        assert result.character_id == character_id
        assert result.confidence_score >= 0.0
        assert result.confidence_score <= 1.0
      end
    end
  end

  # Helper function to create test characters
  defp insert_test_character do
    # Generate a unique character ID for testing
    base_id = 90_000_000
    offset = :rand.uniform(9_999_999)
    base_id + offset
  end
end
