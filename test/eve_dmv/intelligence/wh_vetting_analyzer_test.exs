defmodule EveDmv.Intelligence.WHVettingAnalyzerTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Intelligence.WHVettingAnalyzer

  describe "calculate_j_space_experience/1" do
    test "calculates J-space experience from killmails" do
      # Mock killmail data
      killmails = [
        %{
          # J-space system
          solar_system_id: 31_000_123,
          is_victim: false
        },
        %{
          # J-space system
          solar_system_id: 31_000_456,
          is_victim: true
        },
        %{
          # K-space system
          solar_system_id: 30_002_187,
          is_victim: false
        }
      ]

      result = WHVettingAnalyzer.calculate_j_space_experience(killmails)

      assert %{
               total_j_kills: 1,
               total_j_losses: 1,
               j_space_time_percent: 66.7,
               wormhole_systems_visited: [31_000_123, 31_000_456],
               most_active_wh_class: "C1"
             } = result
    end

    test "handles empty killmail list" do
      result = WHVettingAnalyzer.calculate_j_space_experience([])

      assert %{
               total_j_kills: 0,
               total_j_losses: 0,
               j_space_time_percent: 0.0,
               wormhole_systems_visited: [],
               most_active_wh_class: nil
             } = result
    end

    test "handles killmails with no J-space activity" do
      killmails = [
        %{
          # K-space system
          solar_system_id: 30_002_187,
          is_victim: false
        },
        %{
          # K-space system
          solar_system_id: 30_000_142,
          is_victim: true
        }
      ]

      result = WHVettingAnalyzer.calculate_j_space_experience(killmails)

      assert %{
               total_j_kills: 0,
               total_j_losses: 0,
               j_space_time_percent: 0.0,
               wormhole_systems_visited: [],
               most_active_wh_class: nil
             } = result
    end
  end

  describe "analyze_security_risks/2" do
    test "analyzes security risks from character data" do
      character_data = %{character_id: 95_465_499}

      employment_history = [
        %{start_date: ~U[2023-01-01 00:00:00Z], corporation_id: 1001},
        %{start_date: ~U[2023-02-15 00:00:00Z], corporation_id: 1002},
        %{start_date: ~U[2023-03-01 00:00:00Z], corporation_id: 1003}
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

    test "detects corp hopping patterns" do
      character_data = %{character_id: 95_465_499}

      # Create employment history with rapid corp changes
      employment_history = [
        %{start_date: ~U[2023-01-01 00:00:00Z], corporation_id: 1001},
        # 14 days
        %{start_date: ~U[2023-01-15 00:00:00Z], corporation_id: 1002},
        # 17 days
        %{start_date: ~U[2023-02-01 00:00:00Z], corporation_id: 1003},
        # 9 days
        %{start_date: ~U[2023-02-10 00:00:00Z], corporation_id: 1004},
        # 10 days
        %{start_date: ~U[2023-02-20 00:00:00Z], corporation_id: 1005}
      ]

      result = WHVettingAnalyzer.analyze_security_risks(character_data, employment_history)

      assert result.corp_hopping_detected == true
      assert "corp_hopping" in result.risk_factors
      # Should be high risk
      assert result.risk_score > 50
    end

    test "handles empty employment history" do
      character_data = %{character_id: 95_465_499}
      employment_history = []

      result = WHVettingAnalyzer.analyze_security_risks(character_data, employment_history)

      assert "no_employment_history" in result.risk_factors
      # Should have some risk for no history
      assert result.risk_score > 30
    end
  end

  describe "detect_eviction_groups/1" do
    test "detects known eviction groups" do
      killmails = [
        %{
          attacker_corporation_name: "Hard Knocks Citizens",
          attacker_alliance_name: "Hard Knocks Citizens"
        },
        %{
          attacker_corporation_name: "Lazerhawks",
          attacker_alliance_name: "Lazerhawks"
        },
        %{
          attacker_corporation_name: "Some Other Corp",
          attacker_alliance_name: "Random Alliance"
        }
      ]

      result = WHVettingAnalyzer.detect_eviction_groups(killmails)

      assert result.eviction_group_detected == true
      assert "hard knocks" in result.known_groups
      assert "lazerhawks" in result.known_groups
      assert result.confidence_score > 0.6
    end

    test "handles killmails with no eviction groups" do
      killmails = [
        %{
          attacker_corporation_name: "Some Random Corp",
          attacker_alliance_name: "Random Alliance"
        },
        %{
          attacker_corporation_name: "Another Corp",
          attacker_alliance_name: "Another Alliance"
        }
      ]

      result = WHVettingAnalyzer.detect_eviction_groups(killmails)

      assert result.eviction_group_detected == false
      assert Enum.empty?(result.known_groups)
      assert result.confidence_score == 0.0
    end

    test "handles empty killmail list" do
      result = WHVettingAnalyzer.detect_eviction_groups([])

      assert result.eviction_group_detected == false
      assert Enum.empty?(result.known_groups)
      assert result.confidence_score == 0.0
    end
  end

  describe "analyze_alt_character_patterns/2" do
    test "analyzes potential alt character patterns" do
      character_data = %{character_name: "Test Character"}

      killmails = [
        %{
          attacker_character_name: "Alt Character 1",
          solar_system_id: 31_000_123,
          killmail_time: ~U[2023-01-01 12:00:00Z]
        },
        %{
          attacker_character_name: "Alt Character 2",
          solar_system_id: 31_000_123,
          killmail_time: ~U[2023-01-01 12:05:00Z]
        },
        %{
          attacker_character_name: "Alt Character 1",
          solar_system_id: 31_000_456,
          killmail_time: ~U[2023-01-01 12:10:00Z]
        }
      ]

      result = WHVettingAnalyzer.analyze_alt_character_patterns(character_data, killmails)

      assert %{
               potential_alts: potential_alts,
               shared_systems: shared_systems,
               timing_correlation: timing_correlation
             } = result

      assert "Alt Character 1" in potential_alts
      assert "Alt Character 2" in potential_alts
      assert 31_000_123 in shared_systems
      assert 31_000_456 in shared_systems
      assert is_float(timing_correlation)
      assert timing_correlation >= 0.0 and timing_correlation <= 1.0
    end

    test "handles killmails with no alt patterns" do
      character_data = %{character_name: "Test Character"}
      killmails = []

      result = WHVettingAnalyzer.analyze_alt_character_patterns(character_data, killmails)

      assert Enum.empty?(result.potential_alts)
      assert Enum.empty?(result.shared_systems)
      assert result.timing_correlation == 0.0
    end
  end

  describe "calculate_small_gang_competency/1" do
    test "calculates small gang competency from killmails" do
      killmails = [
        # Small gang kill
        %{attacker_count: 3, is_victim: false},
        # Solo kill
        %{attacker_count: 1, is_victim: false},
        # Medium gang kill
        %{attacker_count: 5, is_victim: false},
        # Small gang loss
        %{attacker_count: 2, is_victim: true}
      ]

      result = WHVettingAnalyzer.calculate_small_gang_competency(killmails)

      assert %{
               small_gang_performance: performance,
               avg_gang_size: avg_size,
               preferred_size: preferred,
               solo_capability: solo
             } = result

      assert is_map(performance)
      assert Map.has_key?(performance, :kill_efficiency)
      assert Map.has_key?(performance, :total_engagements)

      assert is_float(avg_size)
      assert avg_size > 0

      assert preferred in ["solo", "small_gang", "medium_gang", "large_gang", "fleet"]
      assert is_boolean(solo)
    end

    test "handles empty killmail list" do
      result = WHVettingAnalyzer.calculate_small_gang_competency([])

      assert result.avg_gang_size == 0.0
      assert result.preferred_size == "unknown"
      assert result.solo_capability == false
    end
  end

  describe "generate_recommendation/1" do
    test "generates recommendation based on analysis data" do
      # High quality candidate
      analysis_data = %{
        j_space_experience: %{
          total_j_kills: 35,
          j_space_time_percent: 70.0
        },
        security_risks: %{
          risk_score: 20
        },
        eviction_groups: %{
          eviction_group_detected: false
        },
        competency_metrics: %{
          avg_gang_size: 4.0
        }
      }

      result = WHVettingAnalyzer.generate_recommendation(analysis_data)

      assert result.recommendation == "approve"
      assert result.confidence >= 0.8
      assert is_binary(result.reasoning)
      assert is_list(result.conditions)
    end

    test "rejects candidates with eviction group associations" do
      analysis_data = %{
        j_space_experience: %{
          total_j_kills: 35,
          j_space_time_percent: 70.0
        },
        security_risks: %{
          risk_score: 20
        },
        eviction_groups: %{
          eviction_group_detected: true
        },
        competency_metrics: %{}
      }

      result = WHVettingAnalyzer.generate_recommendation(analysis_data)

      assert result.recommendation == "reject"
      assert result.confidence >= 0.9
      assert String.contains?(result.reasoning, "eviction group")
    end

    test "handles insufficient data scenarios" do
      analysis_data = %{
        j_space_experience: %{
          total_j_kills: 2,
          j_space_time_percent: 10.0
        },
        security_risks: %{
          risk_score: 30
        },
        eviction_groups: %{
          eviction_group_detected: false
        },
        competency_metrics: %{}
      }

      result = WHVettingAnalyzer.generate_recommendation(analysis_data)

      assert result.recommendation in ["more_info", "conditional"]
      assert result.confidence < 0.8
    end
  end

  describe "classify_system_type/1" do
    test "classifies wormhole systems" do
      assert WHVettingAnalyzer.classify_system_type(31_000_123) == :wormhole
      assert WHVettingAnalyzer.classify_system_type(31_005_999) == :wormhole
    end

    test "classifies known space systems" do
      assert WHVettingAnalyzer.classify_system_type(30_002_187) == :known_space
      assert WHVettingAnalyzer.classify_system_type(30_000_142) == :known_space
    end

    test "handles invalid system IDs" do
      assert WHVettingAnalyzer.classify_system_type(0) == :unknown
      assert WHVettingAnalyzer.classify_system_type(-1) == :unknown
      assert WHVettingAnalyzer.classify_system_type(nil) == :unknown
    end
  end

  describe "format_analysis_summary/1" do
    test "formats comprehensive analysis summary" do
      analysis = %{
        character_name: "Test Character",
        j_space_experience: %{
          total_j_kills: 25,
          total_j_losses: 5,
          j_space_time_percent: 60.5
        },
        security_risks: %{
          risk_score: 35
        },
        recommendation: %{
          recommendation: "conditional",
          confidence: 0.75,
          reasoning: "Good experience but moderate risk"
        }
      }

      result = WHVettingAnalyzer.format_analysis_summary(analysis)

      assert %{
               summary_text: summary,
               key_metrics: metrics
             } = result

      assert is_binary(summary)
      assert String.contains?(summary, "Test Character")
      assert String.contains?(summary, "25 kills")
      assert String.contains?(summary, "CONDITIONAL")

      assert %{
               j_space_kills: 25,
               j_space_losses: 5,
               j_space_percentage: 60.5,
               risk_score: 35,
               recommendation: "conditional",
               confidence: 0.75
             } = metrics
    end
  end
end
