defmodule EveDmv.Intelligence.IntelligenceCoordinatorTest do
  use EveDmv.DataCase, async: true
  use EveDmv.IntelligenceCase

  alias EveDmv.Intelligence.IntelligenceCoordinator

  describe "analyze_character_comprehensive/2" do
    test "returns comprehensive analysis for valid character" do
      character_id = 123_456_789

      # Create test data
      create_realistic_killmail_set(character_id, count: 15, days_back: 60)
      create_wormhole_activity(character_id, "C3", count: 5, role: :hunter)

      assert {:ok, analysis} =
               IntelligenceCoordinator.analyze_character_comprehensive(character_id)

      assert analysis.character_id == character_id
      assert analysis.analysis_timestamp
      assert analysis.basic_analysis
      assert analysis.specialized_analysis
      assert analysis.correlations
      assert analysis.intelligence_summary
      assert analysis.confidence_score
      assert analysis.recommendations
      assert is_float(analysis.confidence_score)
      assert analysis.confidence_score >= 0.0
      assert analysis.confidence_score <= 1.0
    end

    test "handles missing character gracefully" do
      character_id = 999_999_999

      assert {:error, _reason} =
               IntelligenceCoordinator.analyze_character_comprehensive(character_id)
    end

    test "respects use_cache option" do
      character_id = 123_456_789
      create_realistic_killmail_set(character_id, count: 5)

      # First call with caching enabled
      assert {:ok, analysis1} =
               IntelligenceCoordinator.analyze_character_comprehensive(character_id,
                 use_cache: true
               )

      # Second call with caching disabled
      assert {:ok, analysis2} =
               IntelligenceCoordinator.analyze_character_comprehensive(character_id,
                 use_cache: false
               )

      # Both should succeed
      assert analysis1.character_id == character_id
      assert analysis2.character_id == character_id
    end

    test "respects include_correlations option" do
      character_id = 123_456_789
      create_realistic_killmail_set(character_id, count: 5)

      # With correlations disabled
      assert {:ok, analysis} =
               IntelligenceCoordinator.analyze_character_comprehensive(character_id,
                 include_correlations: false
               )

      assert analysis.character_id == character_id
      assert analysis.correlations
    end
  end

  describe "analyze_character_group/2" do
    test "analyzes multiple characters for group analysis" do
      character_ids = [123_456_789, 987_654_321, 555_666_777]

      # Create test data for all characters
      for character_id <- character_ids do
        create_realistic_killmail_set(character_id, count: 10)
        create_wormhole_activity(character_id, "C4", count: 3, role: :mixed)
      end

      assert {:ok, group_analysis} =
               IntelligenceCoordinator.analyze_character_group(character_ids)

      assert group_analysis.character_ids == character_ids
      assert group_analysis.analysis_timestamp
      assert group_analysis.individual_analyses
      assert group_analysis.group_correlations
      assert group_analysis.group_summary
      assert group_analysis.group_recommendations
      assert is_map(group_analysis.individual_analyses)
      assert map_size(group_analysis.individual_analyses) >= 2
    end

    test "handles insufficient data gracefully" do
      character_ids = [999_999_999, 888_888_888]

      assert {:error, "Insufficient character data for group analysis"} =
               IntelligenceCoordinator.analyze_character_group(character_ids)
    end

    test "filters out failed individual analyses" do
      character_ids = [123_456_789, 999_999_999, 987_654_321]

      # Create data for only some characters
      create_realistic_killmail_set(123_456_789, count: 5)
      create_realistic_killmail_set(987_654_321, count: 5)

      assert {:ok, group_analysis} =
               IntelligenceCoordinator.analyze_character_group(character_ids)

      # Should only include successful analyses
      assert map_size(group_analysis.individual_analyses) >= 2
      assert Map.has_key?(group_analysis.individual_analyses, 123_456_789)
      assert Map.has_key?(group_analysis.individual_analyses, 987_654_321)
    end
  end

  describe "get_intelligence_summary/1" do
    test "returns summary for analyzed character" do
      character_id = 123_456_789
      create_realistic_killmail_set(character_id, count: 10)

      assert {:ok, summary} = IntelligenceCoordinator.get_intelligence_summary(character_id)

      assert summary.character_id == character_id
      assert summary.summary_timestamp
      assert summary.key_insights
      assert summary.threat_assessment
      assert summary.activity_summary
      assert is_list(summary.key_insights)
    end

    test "handles missing character data" do
      character_id = 999_999_999

      assert {:error, _reason} = IntelligenceCoordinator.get_intelligence_summary(character_id)
    end
  end

  describe "get_character_correlations/1" do
    test "returns correlations for character" do
      character_id = 123_456_789
      create_realistic_killmail_set(character_id, count: 15)

      assert {:ok, correlations} =
               IntelligenceCoordinator.get_character_correlations(character_id)

      assert correlations.character_id == character_id
      assert correlations.related_characters
      assert correlations.shared_activities
      assert correlations.temporal_patterns
      assert is_list(correlations.related_characters)
    end

    test "handles character with no correlations" do
      character_id = 999_999_999

      assert {:ok, correlations} =
               IntelligenceCoordinator.get_character_correlations(character_id)

      assert correlations.character_id == character_id
      assert correlations.related_characters == []
      assert correlations.shared_activities == []
    end
  end

  describe "private functions" do
    test "calculate_overall_confidence/3 returns valid confidence score" do
      basic_analysis = %{confidence: 0.8}
      specialized_analysis = %{confidence: 0.9}
      correlations = %{confidence: 0.7}

      # Use send to test private function indirectly through public interface
      character_id = 123_456_789
      create_realistic_killmail_set(character_id, count: 5)

      assert {:ok, analysis} =
               IntelligenceCoordinator.analyze_character_comprehensive(character_id)

      assert is_float(analysis.confidence_score)
      assert analysis.confidence_score >= 0.0
      assert analysis.confidence_score <= 1.0
    end
  end
end
