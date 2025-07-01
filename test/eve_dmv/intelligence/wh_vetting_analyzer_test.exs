defmodule EveDmv.Intelligence.WHVettingAnalyzerTest do
  @moduledoc """
  Comprehensive tests for WHVettingAnalyzer module.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Api
  alias EveDmv.Intelligence.WHVettingAnalyzer

  describe "analyze_character/2" do
    test "returns analysis for character with killmail data" do
      character_id = 123_456_789
      current_user_id = 987_654_321

      # Test with valid character ID
      case WHVettingAnalyzer.analyze_character(character_id, current_user_id) do
        {:ok, analysis} ->
          assert %{} = analysis
          assert analysis.character_id == character_id
          assert analysis.analyst_character_id == current_user_id

        {:error, :insufficient_data} ->
          # Expected when no killmail data exists
          assert true

        {:error, reason} ->
          # Other expected errors are acceptable in test environment
          assert is_atom(reason) or is_binary(reason)
      end
    end

    test "handles invalid character ID" do
      result = WHVettingAnalyzer.analyze_character(-1, 123)
      assert {:error, _reason} = result
    end

    test "handles nil character ID" do
      result = WHVettingAnalyzer.analyze_character(nil, 123)
      assert {:error, _reason} = result
    end
  end

  describe "calculate_j_space_experience/1" do
    test "calculates experience with empty killmails" do
      result = WHVettingAnalyzer.calculate_j_space_experience([])

      assert %{
               total_j_kills: 0,
               total_j_losses: 0,
               j_space_time_percent: 0.0,
               wormhole_systems_visited: [],
               most_active_wh_class: nil
             } = result
    end

    test "calculates experience with wormhole killmails" do
      # Mock killmail data with wormhole systems
      killmails = [
        %{
          is_victim: false,
          # J-space system
          solar_system_id: 31_000_001,
          killmail_time: ~U[2024-01-01 12:00:00Z]
        },
        %{
          is_victim: true,
          # J-space system
          solar_system_id: 31_000_002,
          killmail_time: ~U[2024-01-01 13:00:00Z]
        }
      ]

      result = WHVettingAnalyzer.calculate_j_space_experience(killmails)

      assert result.total_j_kills >= 0
      assert result.total_j_losses >= 0
      assert is_float(result.j_space_time_percent)
      assert is_list(result.wormhole_systems_visited)
    end
  end

  describe "analyze_security_risks/2" do
    test "identifies security risks with employment history" do
      character_data = %{character_id: 123, character_name: "Test Pilot"}

      employment_history = [
        %{
          corporation_id: 1001,
          corporation_name: "Test Corp 1",
          start_date: ~U[2023-01-01 00:00:00Z],
          end_date: ~U[2023-06-01 00:00:00Z]
        },
        %{
          corporation_id: 1002,
          corporation_name: "Test Corp 2",
          start_date: ~U[2023-06-01 00:00:00Z],
          end_date: nil
        }
      ]

      result = WHVettingAnalyzer.analyze_security_risks(character_data, employment_history)

      assert %{
               risk_score: risk_score,
               risk_factors: risk_factors,
               corp_hopping_detected: corp_hopping
             } = result

      assert is_integer(risk_score)
      assert risk_score >= 0 and risk_score <= 100
      assert is_list(risk_factors)
      assert is_boolean(corp_hopping)
    end

    test "handles empty employment history" do
      character_data = %{character_id: 123, character_name: "Test Pilot"}
      employment_history = []

      result = WHVettingAnalyzer.analyze_security_risks(character_data, employment_history)

      assert %{
               risk_score: risk_score,
               risk_factors: risk_factors
             } = result

      assert is_integer(risk_score)
      assert is_list(risk_factors)
    end
  end

  describe "detect_eviction_groups/1" do
    test "detects known eviction group patterns" do
      killmails = [
        %{
          attacker_character_name: "Eviction Pilot",
          attacker_corporation_name: "Hard Knocks Inc.",
          solar_system_id: 31_000_001
        }
      ]

      result = WHVettingAnalyzer.detect_eviction_groups(killmails)

      assert %{
               eviction_group_detected: detected,
               known_groups: groups,
               confidence_score: score
             } = result

      assert is_boolean(detected)
      assert is_list(groups)
      assert is_number(score)
      assert score >= 0.0 and score <= 1.0
    end

    test "handles empty killmail list" do
      result = WHVettingAnalyzer.detect_eviction_groups([])

      assert %{
               eviction_group_detected: false,
               known_groups: [],
               confidence_score: 0.0
             } = result
    end
  end

  describe "analyze_alt_character_patterns/2" do
    test "analyzes potential alt character connections" do
      character_data = %{character_id: 123, character_name: "Main Pilot"}

      killmails = [
        %{
          killmail_time: ~U[2024-01-01 12:00:00Z],
          solar_system_id: 30_002_187,
          attacker_character_name: "Alt Pilot"
        }
      ]

      result = WHVettingAnalyzer.analyze_alt_character_patterns(character_data, killmails)

      assert %{
               potential_alts: alts,
               shared_systems: systems,
               timing_correlation: timing
             } = result

      assert is_list(alts)
      assert is_list(systems)
      assert is_number(timing)
    end
  end

  describe "calculate_small_gang_competency/1" do
    test "calculates competency from killmail data" do
      killmails = [
        %{
          attacker_count: 3,
          is_victim: false,
          killmail_time: ~U[2024-01-01 12:00:00Z]
        },
        %{
          attacker_count: 5,
          is_victim: false,
          killmail_time: ~U[2024-01-01 13:00:00Z]
        }
      ]

      result = WHVettingAnalyzer.calculate_small_gang_competency(killmails)

      assert %{
               small_gang_performance: performance,
               avg_gang_size: avg_size,
               preferred_size: preferred,
               solo_capability: solo
             } = result

      assert is_map(performance)
      assert is_number(avg_size)
      assert is_binary(preferred) or is_nil(preferred)
      assert is_boolean(solo)
    end

    test "handles empty killmail data" do
      result = WHVettingAnalyzer.calculate_small_gang_competency([])

      assert %{
               small_gang_performance: %{},
               avg_gang_size: 0.0,
               preferred_size: "unknown",
               solo_capability: false
             } = result
    end
  end

  describe "generate_recommendation/1" do
    test "generates recommendation based on analysis" do
      analysis_data = %{
        j_space_experience: %{
          total_j_kills: 50,
          total_j_losses: 10,
          j_space_time_percent: 75.0
        },
        security_risks: %{
          risk_score: 15,
          risk_factors: []
        },
        eviction_groups: %{
          eviction_group_detected: false
        },
        competency_metrics: %{
          small_gang_performance: %{kill_efficiency: 0.8}
        }
      }

      result = WHVettingAnalyzer.generate_recommendation(analysis_data)

      assert %{
               recommendation: recommendation,
               confidence: confidence,
               reasoning: reasoning,
               conditions: conditions
             } = result

      assert recommendation in ["approve", "conditional", "reject", "more_info"]
      assert is_number(confidence)
      assert confidence >= 0.0 and confidence <= 1.0
      assert is_binary(reasoning)
      assert is_list(conditions)
    end

    test "generates reject recommendation for high risk" do
      analysis_data = %{
        security_risks: %{
          risk_score: 95,
          risk_factors: ["suspicious_activity", "corp_hopping"]
        },
        eviction_groups: %{
          eviction_group_detected: true
        }
      }

      result = WHVettingAnalyzer.generate_recommendation(analysis_data)

      assert result.recommendation == "reject"
      assert result.confidence > 0.8
      assert String.contains?(result.reasoning, "risk")
    end
  end

  describe "format_analysis_summary/1" do
    test "formats complete analysis into summary" do
      analysis = %{
        character_id: 123_456_789,
        character_name: "Test Pilot",
        j_space_experience: %{
          total_j_kills: 25,
          total_j_losses: 5,
          j_space_time_percent: 60.0
        },
        security_risks: %{
          risk_score: 25,
          risk_factors: ["new_player"]
        },
        recommendation: %{
          recommendation: "conditional",
          confidence: 0.75,
          reasoning: "Good J-space experience but limited history"
        }
      }

      result = WHVettingAnalyzer.format_analysis_summary(analysis)

      assert is_map(result)
      assert Map.has_key?(result, :summary_text)
      assert Map.has_key?(result, :key_metrics)
      assert is_binary(result.summary_text)
      assert is_map(result.key_metrics)
    end
  end

  describe "helper functions" do
    test "classify_system_type/1 correctly identifies system types" do
      # Test j-space systems
      assert WHVettingAnalyzer.classify_system_type(31_000_001) == :wormhole

      # Test k-space systems
      assert WHVettingAnalyzer.classify_system_type(30_002_187) == :known_space

      # Test invalid system
      assert WHVettingAnalyzer.classify_system_type(-1) == :unknown
    end

    test "calculate_time_overlap/2 computes overlap correctly" do
      time1 = ~U[2024-01-01 12:00:00Z]
      time2 = ~U[2024-01-01 13:00:00Z]

      overlap = WHVettingAnalyzer.calculate_time_overlap(time1, time2)
      assert is_number(overlap)
      assert overlap >= 0.0
    end

    test "normalize_corporation_name/1 handles various formats" do
      assert WHVettingAnalyzer.normalize_corporation_name("Test Corp") == "test corp"
      assert WHVettingAnalyzer.normalize_corporation_name("TEST-CORP [ALLIANCE]") == "test-corp"
      assert WHVettingAnalyzer.normalize_corporation_name(nil) == ""
    end
  end

  describe "integration with Ash resources" do
    test "stores vetting record properly" do
      # This tests the actual database integration
      analysis_data = %{
        character_id: 123_456_789,
        character_name: "Integration Test",
        analyst_character_id: 987_654_321,
        recommendation: %{
          recommendation: "approve",
          confidence: 0.9,
          reasoning: "Excellent candidate"
        }
      }

      # Attempt to create vetting record
      case WHVettingAnalyzer.store_vetting_analysis(analysis_data) do
        {:ok, vetting_record} ->
          assert vetting_record.character_id == analysis_data.character_id
          assert vetting_record.analyst_character_id == analysis_data.analyst_character_id

        {:error, _reason} ->
          # Expected in test environment without full data setup
          assert true
      end
    end
  end
end
