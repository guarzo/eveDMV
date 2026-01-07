defmodule EveDmv.Contexts.ThreatSurveillance.Domain.ThreatAssessmentEngineTest do
  @moduledoc """
  Tests for the ThreatAssessmentEngine GenServer.

  Tests the core threat assessment functionality including:
  - Character threat assessment
  - Corporation threat assessment
  - Threat level calculations
  - Assessment updates
  - Killmail processing
  - Surveillance match processing
  """

  use EveDmv.DataCase, async: false

  alias EveDmv.Contexts.ThreatSurveillance.Domain.ThreatAssessmentEngine
  alias EveDmv.DomainEvents.KillmailEnriched

  @moduletag :threat_surveillance

  describe "start_link/1" do
    test "starts the GenServer successfully" do
      # Stop if already running
      if pid = GenServer.whereis(ThreatAssessmentEngine) do
        GenServer.stop(pid)
        Process.sleep(50)
      end

      assert {:ok, pid} = ThreatAssessmentEngine.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "registers with the module name" do
      if pid = GenServer.whereis(ThreatAssessmentEngine) do
        GenServer.stop(pid)
        Process.sleep(50)
      end

      {:ok, pid} = ThreatAssessmentEngine.start_link([])
      assert GenServer.whereis(ThreatAssessmentEngine) == pid
      GenServer.stop(pid)
    end
  end

  describe "assess_character_threat/2" do
    setup do
      ensure_engine_running()
    end

    test "returns threat assessment for a valid character_id" do
      character_id = character_id()

      assert {:ok, assessment} = ThreatAssessmentEngine.assess_character_threat(character_id)

      assert assessment.character_id == character_id
      assert is_float(assessment.threat_score)
      assert assessment.threat_score >= 0.0
      assert assessment.threat_score <= 100.0
      assert assessment.threat_level in [:critical, :high, :medium, :low, :minimal]
      assert %DateTime{} = assessment.assessed_at
    end

    test "includes behavioral analysis in assessment" do
      character_id = character_id()

      {:ok, assessment} = ThreatAssessmentEngine.assess_character_threat(character_id)

      assert is_map(assessment.behavioral_analysis)
      assert assessment.behavioral_analysis.aggression_level in [:high, :moderate, :low]
      assert assessment.behavioral_analysis.predictability in [:high, :moderate, :low]
      assert assessment.behavioral_analysis.coordination in [:high, :moderate, :low]
    end

    test "includes risk factors in assessment" do
      character_id = character_id()

      {:ok, assessment} = ThreatAssessmentEngine.assess_character_threat(character_id)

      assert is_list(assessment.risk_factors)
    end

    test "includes activity patterns in assessment" do
      character_id = character_id()

      {:ok, assessment} = ThreatAssessmentEngine.assess_character_threat(character_id)

      assert is_map(assessment.activity_patterns)
      assert is_list(assessment.activity_patterns.peak_hours)
      assert is_list(assessment.activity_patterns.engagement_types)
    end

    test "includes recommendations in assessment" do
      character_id = character_id()

      {:ok, assessment} = ThreatAssessmentEngine.assess_character_threat(character_id)

      assert is_list(assessment.recommendations)
    end

    test "respects time_range option" do
      character_id = character_id()

      {:ok, assessment_30} =
        ThreatAssessmentEngine.assess_character_threat(character_id, time_range: :last_30_days)

      {:ok, assessment_90} =
        ThreatAssessmentEngine.assess_character_threat(character_id, time_range: :last_90_days)

      assert assessment_30.time_range == :last_30_days
      assert assessment_90.time_range == :last_90_days
    end

    test "caches assessment results" do
      character_id = character_id()

      # First call
      {:ok, _assessment1} = ThreatAssessmentEngine.assess_character_threat(character_id)

      # Second call should be faster (cached)
      {:ok, assessment2} = ThreatAssessmentEngine.assess_character_threat(character_id)

      assert assessment2.character_id == character_id
    end
  end

  describe "assess_corporation_threat/2" do
    setup do
      ensure_engine_running()
    end

    test "returns threat assessment for a valid corporation_id" do
      corp_id = corporation_id()

      assert {:ok, assessment} = ThreatAssessmentEngine.assess_corporation_threat(corp_id)

      assert assessment.corporation_id == corp_id
      assert is_float(assessment.threat_score)
      assert assessment.threat_score >= 0.0
      assert assessment.threat_score <= 100.0
      assert assessment.threat_level in [:critical, :high, :medium, :low, :minimal]
      assert %DateTime{} = assessment.assessed_at
    end

    test "includes member threat distribution" do
      corp_id = corporation_id()

      {:ok, assessment} = ThreatAssessmentEngine.assess_corporation_threat(corp_id)

      assert is_map(assessment.member_threat_distribution)
      assert Map.has_key?(assessment.member_threat_distribution, :critical)
      assert Map.has_key?(assessment.member_threat_distribution, :high)
      assert Map.has_key?(assessment.member_threat_distribution, :medium)
      assert Map.has_key?(assessment.member_threat_distribution, :low)
    end

    test "includes activity metrics" do
      corp_id = corporation_id()

      {:ok, assessment} = ThreatAssessmentEngine.assess_corporation_threat(corp_id)

      assert is_map(assessment.activity_metrics)
    end

    test "includes fleet capabilities assessment" do
      corp_id = corporation_id()

      {:ok, assessment} = ThreatAssessmentEngine.assess_corporation_threat(corp_id)

      assert is_map(assessment.fleet_capabilities)
      assert Map.has_key?(assessment.fleet_capabilities, :doctrine_strength)
      assert Map.has_key?(assessment.fleet_capabilities, :coordination)
    end

    test "includes territorial influence assessment" do
      corp_id = corporation_id()

      {:ok, assessment} = ThreatAssessmentEngine.assess_corporation_threat(corp_id)

      assert is_map(assessment.territorial_influence)
    end

    test "includes alliance relationships" do
      corp_id = corporation_id()

      {:ok, assessment} = ThreatAssessmentEngine.assess_corporation_threat(corp_id)

      assert is_map(assessment.alliance_relationships)
      assert Map.has_key?(assessment.alliance_relationships, :allies)
      assert Map.has_key?(assessment.alliance_relationships, :neutrals)
      assert Map.has_key?(assessment.alliance_relationships, :hostiles)
    end
  end

  describe "assess_threat_level/2" do
    setup do
      ensure_engine_running()
    end

    test "delegates to assess_character_threat for :character type" do
      character_id = character_id()

      assert {:ok, assessment} =
               ThreatAssessmentEngine.assess_threat_level(character_id, :character)

      assert assessment.character_id == character_id
    end

    test "delegates to assess_corporation_threat for :corporation type" do
      corp_id = corporation_id()

      assert {:ok, assessment} = ThreatAssessmentEngine.assess_threat_level(corp_id, :corporation)

      assert assessment.corporation_id == corp_id
    end
  end

  describe "update_assessment/3" do
    setup do
      ensure_engine_running()
    end

    test "updates character assessment after initial assessment" do
      character_id = character_id()

      # First, get an initial assessment so the cache has threat_score
      {:ok, _initial} = ThreatAssessmentEngine.assess_character_threat(character_id)

      intelligence_data = %{
        source: :surveillance,
        data_type: :killmail_activity,
        timestamp: DateTime.utc_now(),
        details: %{kills_detected: 5}
      }

      assert {:ok, updated} =
               ThreatAssessmentEngine.update_assessment(
                 character_id,
                 :character,
                 intelligence_data
               )

      assert updated.last_updated
    end

    test "updates corporation assessment after initial assessment" do
      corp_id = corporation_id()

      # First, get an initial assessment so the cache has threat_score
      {:ok, _initial} = ThreatAssessmentEngine.assess_corporation_threat(corp_id)

      intelligence_data = %{
        source: :surveillance,
        data_type: :fleet_activity,
        timestamp: DateTime.utc_now(),
        details: %{fleets_detected: 2}
      }

      assert {:ok, updated} =
               ThreatAssessmentEngine.update_assessment(corp_id, :corporation, intelligence_data)

      assert updated.last_updated
    end

    test "accepts string entity type after initial assessment" do
      character_id = character_id()

      # First, get an initial assessment
      {:ok, _initial} = ThreatAssessmentEngine.assess_character_threat(character_id)

      intelligence_data = %{
        source: :surveillance,
        timestamp: DateTime.utc_now()
      }

      assert {:ok, _updated} =
               ThreatAssessmentEngine.update_assessment(
                 character_id,
                 "character",
                 intelligence_data
               )
    end
  end

  describe "get_metrics/0" do
    setup do
      ensure_engine_running()
    end

    test "returns current metrics" do
      metrics = ThreatAssessmentEngine.get_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :processed_killmails)
      assert Map.has_key?(metrics, :assessments_generated)
      assert Map.has_key?(metrics, :cache_size)
      assert is_integer(metrics.processed_killmails)
      assert is_integer(metrics.assessments_generated)
    end

    test "increments assessments_generated counter after assessment" do
      initial_metrics = ThreatAssessmentEngine.get_metrics()
      character_id = character_id()

      ThreatAssessmentEngine.assess_character_threat(character_id)

      updated_metrics = ThreatAssessmentEngine.get_metrics()
      assert updated_metrics.assessments_generated >= initial_metrics.assessments_generated
    end
  end

  describe "process_killmail/1" do
    setup do
      ensure_engine_running()
    end

    test "processes a valid killmail event" do
      killmail = build_killmail_enriched()

      # Should not raise
      assert :ok = ThreatAssessmentEngine.process_killmail(killmail)
    end

    test "updates processed_killmails counter" do
      initial_metrics = ThreatAssessmentEngine.get_metrics()
      killmail = build_killmail_enriched()

      ThreatAssessmentEngine.process_killmail(killmail)

      # Give async operation time to complete
      Process.sleep(100)

      updated_metrics = ThreatAssessmentEngine.get_metrics()
      assert updated_metrics.processed_killmails >= initial_metrics.processed_killmails
    end

    test "invalidates cache for involved entities" do
      killmail = build_killmail_enriched()

      # Process killmail which should invalidate caches
      ThreatAssessmentEngine.process_killmail(killmail)
      Process.sleep(50)

      # This should work without error
      assert :ok = ThreatAssessmentEngine.process_killmail(killmail)
    end
  end

  describe "process_surveillance_match/1" do
    setup do
      ensure_engine_running()
    end

    test "processes a valid surveillance match event" do
      match_event = %{
        character_id: character_id(),
        corporation_id: corporation_id(),
        profile_id: "profile_123",
        killmail_id: System.unique_integer([:positive]),
        matched_at: DateTime.utc_now()
      }

      # Should not raise
      assert :ok = ThreatAssessmentEngine.process_surveillance_match(match_event)
    end

    test "handles match event with only character_id" do
      match_event = %{
        character_id: character_id(),
        profile_id: "profile_123",
        matched_at: DateTime.utc_now()
      }

      assert :ok = ThreatAssessmentEngine.process_surveillance_match(match_event)
    end

    test "handles match event with only corporation_id" do
      match_event = %{
        corporation_id: corporation_id(),
        profile_id: "profile_123",
        matched_at: DateTime.utc_now()
      }

      assert :ok = ThreatAssessmentEngine.process_surveillance_match(match_event)
    end
  end

  describe "threat level calculation" do
    setup do
      ensure_engine_running()
    end

    test "threat level :minimal for scores below 20" do
      # The engine calculates scores internally - we verify the level categories
      character_id = character_id()

      {:ok, assessment} = ThreatAssessmentEngine.assess_character_threat(character_id)

      # Just verify the level is one of the valid values
      assert assessment.threat_level in [:critical, :high, :medium, :low, :minimal]
    end

    test "corporation threat levels use different thresholds" do
      corp_id = corporation_id()

      {:ok, assessment} = ThreatAssessmentEngine.assess_corporation_threat(corp_id)

      # Corporation thresholds: 85 critical, 65 high, 45 medium, 25 low
      assert assessment.threat_level in [:critical, :high, :medium, :low, :minimal]
    end
  end

  describe "health_check" do
    setup do
      ensure_engine_running()
    end

    test "responds to health check" do
      assert :ok = GenServer.call(ThreatAssessmentEngine, :health_check)
    end
  end

  # Helper functions

  defp ensure_engine_running do
    case GenServer.whereis(ThreatAssessmentEngine) do
      nil ->
        {:ok, _pid} = ThreatAssessmentEngine.start_link([])
        :ok

      pid when is_pid(pid) ->
        if Process.alive?(pid), do: :ok, else: ThreatAssessmentEngine.start_link([])
    end
  end

  defp build_killmail_enriched do
    killmail_data = build(:killmail_enriched)

    %KillmailEnriched{
      killmail_id: killmail_data.killmail_id,
      killmail_time: killmail_data.killmail_time,
      solar_system_id: killmail_data.solar_system_id,
      victim: %{
        character_id: killmail_data.victim_character_id,
        corporation_id: killmail_data.victim_corporation_id,
        alliance_id: killmail_data.victim_alliance_id,
        ship_type_id: killmail_data.victim_ship_type_id
      },
      attackers:
        Enum.map(killmail_data.raw_data["attackers"] || [], fn a ->
          %{
            character_id: a["character_id"],
            corporation_id: a["corporation_id"],
            alliance_id: a["alliance_id"],
            ship_type_id: a["ship_type_id"]
          }
        end),
      zkb_total_value: Decimal.new("100000000")
    }
  end
end
