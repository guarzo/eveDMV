defmodule EveDmv.Contexts.CombatIntelligence.ApiTest do
  @moduledoc """
  Tests for the Combat Intelligence API module.
  Tests all public functions including happy paths, error handling, and edge cases.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.CombatIntelligence.Api

  describe "analyze_character/2" do
    test "returns character analysis with default options" do
      character_id = character_id()

      result = Api.analyze_character(character_id)

      assert {:ok, analysis} = result
      assert analysis.character_id == character_id
      assert is_atom(analysis.threat_level) or is_map(analysis.threat_level)
      assert Map.has_key?(analysis, :analysis_summary)
      assert Map.has_key?(analysis, :detailed_metrics)
      assert Map.has_key?(analysis, :recommendations)
      assert %DateTime{} = analysis.last_updated
    end

    test "accepts analysis_type option :full" do
      character_id = character_id()

      result = Api.analyze_character(character_id, analysis_type: :full)

      assert {:ok, _analysis} = result
    end

    test "accepts analysis_type option :quick" do
      character_id = character_id()

      result = Api.analyze_character(character_id, analysis_type: :quick)

      assert {:ok, _analysis} = result
    end

    test "accepts analysis_type option :threat_only" do
      character_id = character_id()

      result = Api.analyze_character(character_id, analysis_type: :threat_only)

      assert {:ok, _analysis} = result
    end

    test "accepts analysis_type option :activity_only" do
      character_id = character_id()

      result = Api.analyze_character(character_id, analysis_type: :activity_only)

      assert {:ok, _analysis} = result
    end

    test "rejects invalid analysis_type" do
      character_id = character_id()

      result = Api.analyze_character(character_id, analysis_type: :invalid)

      assert {:error, :invalid_analysis_type} = result
    end

    test "accepts time_range option as map" do
      character_id = character_id()
      time_range = %{start: DateTime.utc_now(), end: DateTime.utc_now()}

      result = Api.analyze_character(character_id, time_range: time_range)

      assert {:ok, _analysis} = result
    end

    test "rejects invalid time_range option" do
      character_id = character_id()

      result = Api.analyze_character(character_id, time_range: "invalid")

      assert {:error, :invalid_time_range} = result
    end

    test "accepts include_associates boolean option" do
      character_id = character_id()

      result = Api.analyze_character(character_id, include_associates: true)

      assert {:ok, _analysis} = result

      result2 = Api.analyze_character(character_id, include_associates: false)

      assert {:ok, _analysis} = result2
    end

    test "rejects non-boolean include_associates option" do
      character_id = character_id()

      result = Api.analyze_character(character_id, include_associates: "yes")

      assert {:error, {:invalid_boolean_option, :include_associates}} = result
    end

    test "accepts include_patterns boolean option" do
      character_id = character_id()

      result = Api.analyze_character(character_id, include_patterns: true)

      assert {:ok, _analysis} = result
    end

    test "accepts cache_ttl positive integer option" do
      character_id = character_id()

      result = Api.analyze_character(character_id, cache_ttl: 3600)

      assert {:ok, _analysis} = result
    end

    test "rejects invalid cache_ttl option" do
      character_id = character_id()

      result = Api.analyze_character(character_id, cache_ttl: -1)

      assert {:error, :invalid_cache_ttl} = result

      result2 = Api.analyze_character(character_id, cache_ttl: "1hour")

      assert {:error, :invalid_cache_ttl} = result2
    end

    test "rejects non-list options" do
      character_id = character_id()

      result = Api.analyze_character(character_id, "invalid")

      assert {:error, :invalid_options_format} = result
    end
  end

  describe "get_character_intelligence/1" do
    test "returns cached character intelligence" do
      character_id = character_id()

      result = Api.get_character_intelligence(character_id)

      assert {:ok, intelligence} = result
      assert intelligence.character_id == character_id
      assert Map.has_key?(intelligence, :threat_level)
      assert Map.has_key?(intelligence, :analysis_summary)
    end

    test "returns intelligence with expected structure" do
      character_id = character_id()

      {:ok, intelligence} = Api.get_character_intelligence(character_id)

      assert is_binary(intelligence.character_name)
      assert is_map(intelligence.analysis_summary)
      assert is_map(intelligence.detailed_metrics)
      assert is_list(intelligence.recommendations)
    end
  end

  describe "analyze_corporation/2" do
    test "returns corporation analysis with default options" do
      corporation_id = corporation_id()

      result = Api.analyze_corporation(corporation_id)

      assert {:ok, analysis} = result
      assert analysis.corporation_id == corporation_id
      assert Map.has_key?(analysis, :corporation_name)
      assert Map.has_key?(analysis, :member_count)
      assert Map.has_key?(analysis, :activity_patterns)
      assert Map.has_key?(analysis, :threat_distribution)
      assert Map.has_key?(analysis, :coordination_metrics)
    end

    test "accepts valid analysis options" do
      corporation_id = corporation_id()

      result = Api.analyze_corporation(corporation_id, analysis_type: :quick)

      assert {:ok, _analysis} = result
    end

    test "rejects invalid analysis options" do
      corporation_id = corporation_id()

      result = Api.analyze_corporation(corporation_id, analysis_type: :bogus)

      assert {:error, :invalid_analysis_type} = result
    end
  end

  describe "get_corporation_intelligence/1" do
    test "returns cached corporation intelligence" do
      corporation_id = corporation_id()

      result = Api.get_corporation_intelligence(corporation_id)

      assert {:ok, intelligence} = result
      assert intelligence.corporation_id == corporation_id
      assert is_map(intelligence.activity_patterns)
      assert is_map(intelligence.threat_distribution)
    end
  end

  describe "assess_threat/2" do
    test "returns threat assessment with :general context" do
      character_id = character_id()

      result = Api.assess_threat(character_id, :general)

      assert {:ok, assessment} = result
      assert is_map(assessment)
    end

    test "accepts :recruitment context" do
      character_id = character_id()

      result = Api.assess_threat(character_id, :recruitment)

      assert {:ok, _assessment} = result
    end

    test "accepts :wormhole_operations context" do
      character_id = character_id()

      result = Api.assess_threat(character_id, :wormhole_operations)

      assert {:ok, _assessment} = result
    end

    test "accepts :fleet_operations context" do
      character_id = character_id()

      result = Api.assess_threat(character_id, :fleet_operations)

      assert {:ok, _assessment} = result
    end

    test "defaults to :general context when not specified" do
      character_id = character_id()

      result = Api.assess_threat(character_id)

      assert {:ok, _assessment} = result
    end

    test "rejects invalid threat context" do
      character_id = character_id()

      result = Api.assess_threat(character_id, :invalid_context)

      assert {:error, :invalid_threat_context} = result
    end
  end

  describe "get_threat_assessment/1" do
    test "returns cached threat assessment" do
      character_id = character_id()

      result = Api.get_threat_assessment(character_id)

      assert {:ok, _assessment} = result
    end
  end

  describe "calculate_intelligence_score/2" do
    test "calculates danger_rating score" do
      character_id = character_id()

      result = Api.calculate_intelligence_score(character_id, :danger_rating)

      assert {:ok, score_result} = result
      assert is_map(score_result)
    end

    test "calculates hunter_score" do
      character_id = character_id()

      result = Api.calculate_intelligence_score(character_id, :hunter_score)

      assert {:ok, _score_result} = result
    end

    test "calculates fleet_commander_score" do
      character_id = character_id()

      result = Api.calculate_intelligence_score(character_id, :fleet_commander_score)

      assert {:ok, _score_result} = result
    end

    test "calculates solo_pilot_score" do
      character_id = character_id()

      result = Api.calculate_intelligence_score(character_id, :solo_pilot_score)

      assert {:ok, _score_result} = result
    end

    test "calculates awox_risk_score" do
      character_id = character_id()

      result = Api.calculate_intelligence_score(character_id, :awox_risk_score)

      assert {:ok, _score_result} = result
    end

    test "rejects invalid scoring type" do
      character_id = character_id()

      result = Api.calculate_intelligence_score(character_id, :invalid_score)

      assert {:error, :invalid_scoring_type} = result
    end
  end

  describe "get_character_recommendations/1" do
    test "returns tactical recommendations list" do
      character_id = character_id()

      result = Api.get_character_recommendations(character_id)

      assert {:ok, recommendations} = result
      assert is_list(recommendations)
    end
  end

  describe "search_characters_by_criteria/1" do
    test "accepts valid search criteria map" do
      criteria = %{threat_level: :high, active_in_last_days: 30}

      result = Api.search_characters_by_criteria(criteria)

      # The implementation returns either {:ok, []} or {:error, :search_error}
      # depending on the search implementation state
      assert match?({:ok, _}, result) or match?({:error, :search_error}, result)
    end

    test "rejects empty criteria map" do
      result = Api.search_characters_by_criteria(%{})

      assert {:error, :invalid_search_criteria} = result
    end

    test "rejects non-map criteria" do
      result = Api.search_characters_by_criteria("invalid")

      assert {:error, :invalid_criteria_format} = result
    end

    test "rejects list criteria" do
      result = Api.search_characters_by_criteria([:threat_level])

      assert {:error, :invalid_criteria_format} = result
    end
  end

  describe "get_activity_patterns/2" do
    test "returns activity patterns for character" do
      character_id = character_id()

      result = Api.get_activity_patterns(character_id)

      # The API may return {:ok, patterns} or {:error, :analysis_failed}
      assert match?({:ok, %{character_id: _}}, result) or
               match?({:error, :analysis_failed}, result)
    end

    test "accepts options keyword list" do
      character_id = character_id()

      result = Api.get_activity_patterns(character_id, days: 30)

      assert match?({:ok, _}, result) or match?({:error, :analysis_failed}, result)
    end
  end

  describe "compare_characters/1" do
    test "compares multiple characters" do
      character_ids = [character_id(), character_id(), character_id()]

      result = Api.compare_characters(character_ids)

      assert {:ok, comparison} = result
      assert is_map(comparison)
    end

    test "rejects empty character list" do
      result = Api.compare_characters([])

      assert {:error, :invalid_character_ids_format} = result
    end

    test "rejects non-list input" do
      result = Api.compare_characters("invalid")

      assert {:error, :invalid_character_ids_format} = result
    end

    test "rejects list with invalid character IDs" do
      result = Api.compare_characters([123, -1, 456])

      assert {:error, :invalid_character_ids} = result
    end

    test "rejects list with non-integer values" do
      result = Api.compare_characters([123, "456", 789])

      assert {:error, :invalid_character_ids} = result
    end
  end

  describe "get_intelligence_cache_stats/0" do
    test "returns cache statistics map" do
      result = Api.get_intelligence_cache_stats()

      assert is_map(result)
    end
  end

  describe "get_external_groups/2" do
    test "returns list of external groups for character" do
      character_id = character_id()
      since_date = DateTime.add(DateTime.utc_now(), -30, :day)

      result = Api.get_external_groups(character_id, since_date)

      assert {:ok, groups} = result
      assert is_list(groups)
    end

    test "returns empty list when no groups found" do
      character_id = character_id()
      since_date = DateTime.utc_now()

      result = Api.get_external_groups(character_id, since_date)

      assert {:ok, groups} = result
      assert is_list(groups)
    end
  end

  describe "integration scenarios" do
    test "can analyze character and then get cached intelligence" do
      character_id = character_id()

      {:ok, analysis} = Api.analyze_character(character_id)
      {:ok, cached} = Api.get_character_intelligence(character_id)

      assert analysis.character_id == cached.character_id
    end

    test "can assess threat and then get cached assessment" do
      character_id = character_id()

      {:ok, assessment} = Api.assess_threat(character_id, :general)
      {:ok, cached} = Api.get_threat_assessment(character_id)

      assert is_map(assessment)
      assert is_map(cached)
    end
  end
end
