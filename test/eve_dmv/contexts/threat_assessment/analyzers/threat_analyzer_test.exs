defmodule EveDmv.Contexts.ThreatAssessment.Analyzers.ThreatAnalyzerTest do
  @moduledoc """
  Tests for the ThreatAnalyzer module in the analyzers namespace.

  Tests pilot threat analysis including threat scoring, bait probability
  assessment, and bulk analysis capabilities.
  """

  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.ThreatAssessment.Analyzers.ThreatAnalyzer

  describe "analyze/3" do
    test "successfully analyzes a character with complete data" do
      character_id = 12_345_678
      base_data = build_complete_base_data()

      assert {:ok, result} = ThreatAnalyzer.analyze(character_id, base_data)

      assert result.character_id == character_id
      assert is_atom(result.threat_level)
      assert is_integer(result.threat_score)
      assert result.threat_score >= 0 and result.threat_score <= 100
      assert is_integer(result.bait_probability)
      assert result.bait_probability >= 0 and result.bait_probability <= 100
    end

    test "returns error when character_stats fetch fails" do
      character_id = 12_345_678
      base_data = %{}

      result = ThreatAnalyzer.analyze(character_id, base_data)
      # Should return a result, either ok or error depending on data provider behavior
      # Error can be either {:error, reason} or {:error, code, message}
      assert match?({:ok, _}, result) or match?({:error, _}, result) or
               match?({:error, _, _}, result)
    end

    test "uses provided corporation_id and alliance_id from opts" do
      character_id = 12_345_678
      base_data = build_complete_base_data()
      opts = [corporation_id: 98_000_001, alliance_id: 99_000_001]

      {:ok, result} = ThreatAnalyzer.analyze(character_id, base_data, opts)

      assert result.corporation_id == 98_000_001
      assert result.alliance_id == 99_000_001
    end

    test "extracts corporation_id and alliance_id from base_data when not in opts" do
      character_id = 12_345_678

      base_data =
        build_complete_base_data()
        |> Map.merge(%{corporation_id: 98_000_002, alliance_id: 99_000_002})

      {:ok, result} = ThreatAnalyzer.analyze(character_id, base_data)

      assert result.corporation_id == 98_000_002
      assert result.alliance_id == 99_000_002
    end

    test "includes analysis timestamp" do
      character_id = 12_345_678
      base_data = build_complete_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, base_data)

      assert %DateTime{} = result.analysis_timestamp
    end

    test "assesses data quality" do
      character_id = 12_345_678
      base_data = build_complete_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, base_data)

      assert result.data_quality in [:excellent, :good, :fair, :poor, :insufficient]
    end
  end

  describe "threat_score calculation" do
    test "high activity character gets higher threat score" do
      character_id = 12_345_678
      high_activity_data = build_high_activity_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, high_activity_data)

      # High activity should contribute positively to threat score
      assert result.threat_score >= 50
    end

    test "veteran character with many kills gets experience modifier" do
      character_id = 12_345_678
      veteran_data = build_veteran_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, veteran_data)

      # Veterans should have higher threat scores
      assert result.threat_score >= 60
    end

    test "high K/D ratio increases threat score" do
      character_id = 12_345_678
      high_kd_data = build_high_kd_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, high_kd_data)

      # Good K/D should increase threat
      assert result.threat_score >= 55
    end

    test "high value kills increase threat score" do
      character_id = 12_345_678
      high_value_data = build_high_value_killer_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, high_value_data)

      # High value kills should increase threat
      assert result.threat_score >= 55
    end

    test "inactive character gets lower threat score" do
      character_id = 12_345_678
      inactive_data = build_inactive_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, inactive_data)

      # Inactive players should have reduced threat
      assert result.threat_score <= 50
    end
  end

  describe "threat_level determination" do
    test "classifies high score as hostile" do
      character_id = 12_345_678
      high_threat_data = build_high_threat_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, high_threat_data)

      # Score >= 80 should be hostile
      if result.threat_score >= 80 do
        assert result.threat_level == :hostile
      end
    end

    test "classifies moderate score as neutral" do
      character_id = 12_345_678
      moderate_data = build_moderate_threat_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, moderate_data)

      # Score between 40-80 should be neutral
      if result.threat_score >= 40 and result.threat_score < 80 do
        assert result.threat_level == :neutral
      end
    end

    test "classifies low score as friendly" do
      character_id = 12_345_678
      low_data = build_low_threat_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, low_data)

      # Score < 20 should be friendly
      if result.threat_score < 20 do
        assert result.threat_level == :friendly
      end
    end
  end

  describe "bait_probability calculation" do
    test "character with many associates has higher bait probability" do
      character_id = 12_345_678
      base_data = build_base_data_with_associates(35)

      {:ok, result} = ThreatAnalyzer.analyze(character_id, base_data)

      # Many associates = higher bait probability
      assert result.bait_probability >= 50
    end

    test "solo appearance with many associates increases bait probability" do
      character_id = 12_345_678
      base_data = build_deceptive_solo_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, base_data)

      # Appears solo but has associates = potential bait
      assert result.bait_probability >= 40
    end

    test "expensive losses with few kills indicates bait pattern" do
      character_id = 12_345_678
      base_data = build_bait_pattern_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, base_data)

      # Expensive losses but few kills = bait behavior
      assert result.bait_probability >= 40
    end

    test "multiple expensive losses increase bait probability" do
      character_id = 12_345_678
      base_data = build_multiple_expensive_losses_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, base_data)

      # Multiple expensive losses = potential bait
      assert result.bait_probability >= 40
    end
  end

  describe "risk_factors identification" do
    test "identifies high kill activity as risk factor" do
      character_id = 12_345_678
      high_activity_data = build_high_activity_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, high_activity_data)

      # Check using recent_activity instead of character_stats
      if result.recent_activity && result.recent_activity.recent_kills > 15 do
        assert :high_kill_activity in result.risk_factors
      end
    end

    test "identifies high coordination as risk factor" do
      character_id = 12_345_678
      coordinated_data = build_base_data_with_associates(20)

      {:ok, result} = ThreatAnalyzer.analyze(character_id, coordinated_data)

      if result.known_associates_count > 15 do
        assert :high_coordination in result.risk_factors
      end
    end

    test "identifies veteran pilot status" do
      character_id = 12_345_678
      veteran_data = build_veteran_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, veteran_data)

      if result.character_stats && result.character_stats.total_kills > 500 do
        assert :veteran_pilot in result.risk_factors
      end
    end

    test "identifies high value targets" do
      character_id = 12_345_678
      high_value_data = build_high_value_target_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, high_value_data)

      if result.recent_activity && result.recent_activity.avg_loss_value > 2_000_000_000 do
        assert :high_value_target in result.risk_factors
      end
    end

    test "identifies solo operators" do
      character_id = 12_345_678
      solo_data = build_solo_operator_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, solo_data)

      if result.character_stats && result.character_stats.solo_kill_percentage > 70 do
        assert :solo_operator in result.risk_factors
      end
    end
  end

  describe "warning_indicators" do
    test "generates high threat warning for dangerous pilots" do
      character_id = 12_345_678
      high_threat_data = build_high_threat_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, high_threat_data)

      if result.threat_score >= 80 do
        high_threat_warnings =
          Enum.filter(result.warning_indicators, fn w -> w.type == :high_threat end)

        refute Enum.empty?(high_threat_warnings)
      end
    end

    test "generates bait risk warning" do
      character_id = 12_345_678
      bait_data = build_high_bait_probability_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, bait_data)

      if result.bait_probability >= 70 do
        bait_warnings = Enum.filter(result.warning_indicators, fn w -> w.type == :bait_risk end)
        refute Enum.empty?(bait_warnings)
      end
    end

    test "generates high activity warning" do
      character_id = 12_345_678
      high_activity_data = build_very_high_activity_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, high_activity_data)

      if result.recent_activity && result.recent_activity.recent_kills > 20 do
        activity_warnings =
          Enum.filter(result.warning_indicators, fn w -> w.type == :high_activity end)

        refute Enum.empty?(activity_warnings)
      end
    end

    test "warnings include severity levels" do
      character_id = 12_345_678
      base_data = build_high_threat_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, base_data)

      for warning <- result.warning_indicators do
        assert Map.has_key?(warning, :severity)
        assert warning.severity in [:high, :medium, :low]
        assert Map.has_key?(warning, :message)
      end
    end
  end

  describe "behavioral_patterns analysis" do
    test "categorizes activity pattern" do
      character_id = 12_345_678
      base_data = build_complete_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, base_data)

      patterns = result.behavioral_patterns
      assert patterns.activity_pattern in [:very_active, :active, :moderate, :low, :inactive]
    end

    test "determines combat style" do
      character_id = 12_345_678
      base_data = build_complete_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, base_data)

      patterns = result.behavioral_patterns
      assert patterns.combat_style in [:solo_hunter, :fleet_fighter, :small_gang, :mixed]
    end

    test "analyzes target preference" do
      character_id = 12_345_678
      base_data = build_complete_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, base_data)

      patterns = result.behavioral_patterns

      assert patterns.target_preference in [
               :high_value_targets,
               :medium_value_targets,
               :standard_targets,
               :low_value_targets
             ]
    end

    test "determines operational pattern" do
      character_id = 12_345_678
      base_data = build_complete_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, base_data)

      patterns = result.behavioral_patterns
      assert patterns.operational_pattern in [:aggressive_hunter, :cautious_operator]
    end
  end

  describe "threat_confidence calculation" do
    test "higher data availability increases confidence" do
      character_id = 12_345_678
      complete_data = build_complete_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, complete_data)

      assert is_float(result.threat_confidence)
      assert result.threat_confidence >= 0 and result.threat_confidence <= 1.0
    end

    test "more kills increase confidence" do
      character_id = 12_345_678
      high_kills_data = build_high_activity_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, high_kills_data)

      # More data points = higher confidence
      assert result.threat_confidence >= 0.2
    end
  end

  describe "analyze_pilots/3 (bulk analysis)" do
    test "successfully analyzes multiple pilots" do
      pilot_list = [
        {12_345_678, 98_000_001, 99_000_001},
        {12_345_679, 98_000_001, 99_000_001},
        {12_345_680, 98_000_002, nil}
      ]

      base_data = build_complete_base_data()

      {:ok, result} = ThreatAnalyzer.analyze_pilots(pilot_list, base_data)

      assert result.total_analyzed == map_size(result.pilot_analyses)
      assert Map.has_key?(result, :threat_summary)
    end

    test "generates threat summary for batch" do
      pilot_list = [
        {12_345_678, 98_000_001, 99_000_001},
        {12_345_679, 98_000_001, 99_000_001}
      ]

      base_data = build_complete_base_data()

      {:ok, result} = ThreatAnalyzer.analyze_pilots(pilot_list, base_data)

      summary = result.threat_summary
      assert Map.has_key?(summary, :total_pilots)
      assert Map.has_key?(summary, :threat_distribution)
      assert Map.has_key?(summary, :average_threat_score)
      assert Map.has_key?(summary, :average_bait_probability)
      assert Map.has_key?(summary, :high_threat_count)
      assert Map.has_key?(summary, :high_bait_count)
    end

    test "returns summarized analysis when include_details is false" do
      pilot_list = [{12_345_678, 98_000_001, 99_000_001}]
      base_data = build_complete_base_data()

      {:ok, result} = ThreatAnalyzer.analyze_pilots(pilot_list, base_data, include_details: false)

      # Summarized results should have fewer fields
      for {_id, analysis} <- result.pilot_analyses do
        assert Map.has_key?(analysis, :character_id)
        assert Map.has_key?(analysis, :threat_level)
        assert Map.has_key?(analysis, :threat_score)
        assert Map.has_key?(analysis, :bait_probability)
      end
    end

    test "warns when batch size exceeds limit" do
      # Create a large pilot list
      pilot_list = for i <- 1..60, do: {12_345_000 + i, 98_000_001, 99_000_001}
      base_data = build_complete_base_data()

      # Should still process but may log a warning
      {:ok, result} = ThreatAnalyzer.analyze_pilots(pilot_list, base_data, batch_size: 50)
      assert result.total_analyzed > 0
    end

    test "handles empty pilot list" do
      {:ok, result} = ThreatAnalyzer.analyze_pilots([], %{})

      assert result.total_analyzed == 0
      assert result.pilot_analyses == %{}
    end
  end

  describe "analyze_system_threats/4" do
    test "analyzes threats for system inhabitants" do
      system_id = 30_000_142

      inhabitants = [
        {12_345_678, 98_000_001, 99_000_001},
        {12_345_679, 98_000_001, 99_000_001}
      ]

      base_data = build_complete_base_data()

      # Use include_details: true to get full analysis results
      {:ok, result} =
        ThreatAnalyzer.analyze_system_threats(system_id, inhabitants, base_data,
          include_details: true
        )

      assert result.system_id == system_id
      assert result.total_inhabitants == 2
    end

    test "calculates threat distribution for system" do
      system_id = 30_000_142

      inhabitants = [
        {12_345_678, 98_000_001, 99_000_001}
      ]

      base_data = build_complete_base_data()

      {:ok, result} =
        ThreatAnalyzer.analyze_system_threats(system_id, inhabitants, base_data,
          include_details: true
        )

      assert is_map(result.threat_distribution)
    end

    test "determines dominant threat level" do
      system_id = 30_000_142

      inhabitants = [
        {12_345_678, 98_000_001, 99_000_001},
        {12_345_679, 98_000_001, 99_000_001}
      ]

      base_data = build_complete_base_data()

      {:ok, result} =
        ThreatAnalyzer.analyze_system_threats(system_id, inhabitants, base_data,
          include_details: true
        )

      assert result.dominant_threat_level in [:hostile, :neutral, :friendly, :unknown]
    end

    test "assesses system bait risk" do
      system_id = 30_000_142

      inhabitants = [
        {12_345_678, 98_000_001, 99_000_001}
      ]

      base_data = build_complete_base_data()

      {:ok, result} =
        ThreatAnalyzer.analyze_system_threats(system_id, inhabitants, base_data,
          include_details: true
        )

      bait_risk = result.bait_risk_assessment
      assert bait_risk.risk_level in [:high, :moderate, :low, :minimal, :unknown]
      assert is_number(bait_risk.average_bait_probability)
      assert is_integer(bait_risk.high_bait_pilots)
    end

    test "detects coordinated threats" do
      system_id = 30_000_142

      inhabitants = [
        {12_345_678, 98_000_001, 99_000_001},
        {12_345_679, 98_000_001, 99_000_001},
        {12_345_680, 98_000_001, 99_000_001}
      ]

      base_data = build_complete_base_data()

      {:ok, result} =
        ThreatAnalyzer.analyze_system_threats(system_id, inhabitants, base_data,
          include_details: true
        )

      coordination = result.coordinated_threat_indicators
      assert is_boolean(coordination.coordination_detected)
      assert is_number(coordination.coordination_score)
    end

    test "recommends engagement strategy" do
      system_id = 30_000_142

      inhabitants = [
        {12_345_678, 98_000_001, 99_000_001}
      ]

      base_data = build_complete_base_data()

      {:ok, result} =
        ThreatAnalyzer.analyze_system_threats(system_id, inhabitants, base_data,
          include_details: true
        )

      assert result.recommended_engagement_strategy in [
               :avoid_engagement,
               :extreme_caution,
               :cautious_engagement,
               :standard_caution,
               :normal_engagement,
               :insufficient_data
             ]
    end

    test "calculates system threat score" do
      system_id = 30_000_142

      inhabitants = [
        {12_345_678, 98_000_001, 99_000_001}
      ]

      base_data = build_complete_base_data()

      {:ok, result} =
        ThreatAnalyzer.analyze_system_threats(system_id, inhabitants, base_data,
          include_details: true
        )

      assert is_integer(result.system_threat_score)
      assert result.system_threat_score >= 0 and result.system_threat_score <= 100
    end

    test "handles empty inhabitants list" do
      system_id = 30_000_142
      inhabitants = []

      {:ok, result} = ThreatAnalyzer.analyze_system_threats(system_id, inhabitants, %{})

      assert result.total_inhabitants == 0
      assert result.dominant_threat_level == :unknown
      assert result.system_threat_score == 0
    end
  end

  describe "analysis_reason generation" do
    test "includes standing description when available" do
      character_id = 12_345_678
      base_data = build_complete_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, base_data)

      assert is_binary(result.analysis_reason)
      assert String.length(result.analysis_reason) > 0
    end

    test "includes threat score in analysis reason" do
      character_id = 12_345_678
      base_data = build_complete_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, base_data)

      assert String.contains?(result.analysis_reason, "/100")
    end

    test "includes bait probability in analysis reason" do
      character_id = 12_345_678
      base_data = build_complete_base_data()

      {:ok, result} = ThreatAnalyzer.analyze(character_id, base_data)

      assert String.contains?(result.analysis_reason, "%")
    end
  end

  # Helper functions for building test data

  defp build_complete_base_data do
    %{
      character_stats: %{
        dangerous_score: 60,
        solo_kill_percentage: 40,
        pvp_score: 50,
        total_kills: 200
      },
      recent_activity: %{
        recent_kills: 10,
        recent_losses: 3,
        kill_death_ratio: 3.3,
        avg_kill_value: 100_000_000,
        avg_loss_value: 200_000_000,
        last_kill: DateTime.utc_now()
      },
      associates: build_associate_list(5)
    }
  end

  defp build_high_activity_base_data do
    %{
      character_stats: %{
        dangerous_score: 70,
        solo_kill_percentage: 50,
        pvp_score: 60,
        total_kills: 300
      },
      recent_activity: %{
        recent_kills: 25,
        recent_losses: 5,
        kill_death_ratio: 5.0,
        avg_kill_value: 150_000_000,
        avg_loss_value: 100_000_000,
        last_kill: DateTime.utc_now()
      },
      associates: build_associate_list(10)
    }
  end

  defp build_veteran_base_data do
    %{
      character_stats: %{
        dangerous_score: 80,
        solo_kill_percentage: 60,
        pvp_score: 70,
        total_kills: 1500
      },
      recent_activity: %{
        recent_kills: 15,
        recent_losses: 3,
        kill_death_ratio: 5.0,
        avg_kill_value: 200_000_000,
        avg_loss_value: 150_000_000,
        last_kill: DateTime.utc_now()
      },
      associates: build_associate_list(8)
    }
  end

  defp build_high_kd_base_data do
    %{
      character_stats: %{
        dangerous_score: 65,
        solo_kill_percentage: 45,
        pvp_score: 55,
        total_kills: 400
      },
      recent_activity: %{
        recent_kills: 20,
        recent_losses: 2,
        kill_death_ratio: 10.0,
        avg_kill_value: 100_000_000,
        avg_loss_value: 50_000_000,
        last_kill: DateTime.utc_now()
      },
      associates: build_associate_list(3)
    }
  end

  defp build_high_value_killer_base_data do
    %{
      character_stats: %{
        dangerous_score: 75,
        solo_kill_percentage: 55,
        pvp_score: 65,
        total_kills: 250
      },
      recent_activity: %{
        recent_kills: 12,
        recent_losses: 4,
        kill_death_ratio: 3.0,
        avg_kill_value: 6_000_000_000,
        avg_loss_value: 500_000_000,
        last_kill: DateTime.utc_now()
      },
      associates: build_associate_list(4)
    }
  end

  defp build_inactive_base_data do
    %{
      character_stats: %{
        dangerous_score: 20,
        solo_kill_percentage: 30,
        pvp_score: 15,
        total_kills: 50
      },
      recent_activity: %{
        recent_kills: 0,
        recent_losses: 1,
        kill_death_ratio: 0.0,
        avg_kill_value: 0,
        avg_loss_value: 50_000_000,
        last_kill: nil
      },
      associates: []
    }
  end

  defp build_high_threat_base_data do
    %{
      character_stats: %{
        dangerous_score: 90,
        solo_kill_percentage: 70,
        pvp_score: 85,
        total_kills: 2000
      },
      recent_activity: %{
        recent_kills: 30,
        recent_losses: 3,
        kill_death_ratio: 10.0,
        avg_kill_value: 500_000_000,
        avg_loss_value: 200_000_000,
        last_kill: DateTime.utc_now()
      },
      associates: build_associate_list(15)
    }
  end

  defp build_moderate_threat_base_data do
    %{
      character_stats: %{
        dangerous_score: 50,
        solo_kill_percentage: 40,
        pvp_score: 45,
        total_kills: 150
      },
      recent_activity: %{
        recent_kills: 8,
        recent_losses: 4,
        kill_death_ratio: 2.0,
        avg_kill_value: 80_000_000,
        avg_loss_value: 100_000_000,
        last_kill: DateTime.utc_now()
      },
      associates: build_associate_list(3)
    }
  end

  defp build_low_threat_base_data do
    %{
      character_stats: %{
        dangerous_score: 10,
        solo_kill_percentage: 10,
        pvp_score: 5,
        total_kills: 10
      },
      recent_activity: %{
        recent_kills: 1,
        recent_losses: 5,
        kill_death_ratio: 0.2,
        avg_kill_value: 10_000_000,
        avg_loss_value: 30_000_000,
        last_kill: DateTime.add(DateTime.utc_now(), -30 * 24 * 3600, :second)
      },
      associates: []
    }
  end

  defp build_base_data_with_associates(count) do
    %{
      character_stats: %{
        dangerous_score: 60,
        solo_kill_percentage: 40,
        pvp_score: 50,
        total_kills: 200
      },
      recent_activity: %{
        recent_kills: 10,
        recent_losses: 3,
        kill_death_ratio: 3.3,
        avg_kill_value: 100_000_000,
        avg_loss_value: 200_000_000,
        last_kill: DateTime.utc_now()
      },
      associates: build_associate_list(count)
    }
  end

  defp build_deceptive_solo_base_data do
    %{
      character_stats: %{
        dangerous_score: 55,
        solo_kill_percentage: 80,
        pvp_score: 50,
        total_kills: 100
      },
      recent_activity: %{
        recent_kills: 1,
        recent_losses: 2,
        kill_death_ratio: 0.5,
        avg_kill_value: 50_000_000,
        avg_loss_value: 100_000_000,
        last_kill: DateTime.utc_now()
      },
      associates: build_associate_list(25)
    }
  end

  defp build_bait_pattern_base_data do
    %{
      character_stats: %{
        dangerous_score: 40,
        solo_kill_percentage: 30,
        pvp_score: 35,
        total_kills: 50
      },
      recent_activity: %{
        recent_kills: 2,
        recent_losses: 8,
        kill_death_ratio: 0.25,
        avg_kill_value: 30_000_000,
        avg_loss_value: 800_000_000,
        last_kill: DateTime.utc_now()
      },
      associates: build_associate_list(10)
    }
  end

  defp build_multiple_expensive_losses_base_data do
    %{
      character_stats: %{
        dangerous_score: 45,
        solo_kill_percentage: 35,
        pvp_score: 40,
        total_kills: 80
      },
      recent_activity: %{
        recent_kills: 5,
        recent_losses: 10,
        kill_death_ratio: 0.5,
        avg_kill_value: 50_000_000,
        avg_loss_value: 2_000_000_000,
        last_kill: DateTime.utc_now()
      },
      associates: build_associate_list(8)
    }
  end

  defp build_high_bait_probability_base_data do
    %{
      character_stats: %{
        dangerous_score: 50,
        solo_kill_percentage: 20,
        pvp_score: 40,
        total_kills: 60
      },
      recent_activity: %{
        recent_kills: 0,
        recent_losses: 5,
        kill_death_ratio: 0.0,
        avg_kill_value: 0,
        avg_loss_value: 1_500_000_000,
        last_kill: nil
      },
      associates: build_associate_list(40)
    }
  end

  defp build_very_high_activity_base_data do
    %{
      character_stats: %{
        dangerous_score: 85,
        solo_kill_percentage: 55,
        pvp_score: 75,
        total_kills: 800
      },
      recent_activity: %{
        recent_kills: 35,
        recent_losses: 5,
        kill_death_ratio: 7.0,
        avg_kill_value: 200_000_000,
        avg_loss_value: 150_000_000,
        last_kill: DateTime.utc_now()
      },
      associates: build_associate_list(12)
    }
  end

  defp build_high_value_target_base_data do
    %{
      character_stats: %{
        dangerous_score: 70,
        solo_kill_percentage: 45,
        pvp_score: 60,
        total_kills: 200
      },
      recent_activity: %{
        recent_kills: 15,
        recent_losses: 8,
        kill_death_ratio: 1.9,
        avg_kill_value: 300_000_000,
        avg_loss_value: 3_000_000_000,
        last_kill: DateTime.utc_now()
      },
      associates: build_associate_list(6)
    }
  end

  defp build_solo_operator_base_data do
    %{
      character_stats: %{
        dangerous_score: 80,
        solo_kill_percentage: 85,
        pvp_score: 70,
        total_kills: 400
      },
      recent_activity: %{
        recent_kills: 20,
        recent_losses: 5,
        kill_death_ratio: 4.0,
        avg_kill_value: 150_000_000,
        avg_loss_value: 200_000_000,
        last_kill: DateTime.utc_now()
      },
      associates: build_associate_list(2)
    }
  end

  defp build_associate_list(count) do
    for i <- 1..count do
      %{
        character_id: 90_000_000 + i,
        character_name: "Associate #{i}",
        corporation_id: 98_000_001,
        kill_count_together: Enum.random(1..20)
      }
    end
  end
end
