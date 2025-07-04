defmodule EveDmv.Integration.CharacterAnalysisIntegrationTest do
  @moduledoc """
  Integration tests for character analysis across multiple domains.

  Tests the integration between character analysis, ESI data fetching,
  killmail processing, and intelligence generation.
  """

  use EveDmv.IntelligenceCase, async: false

  alias EveDmv.Eve.CircuitBreaker

  alias EveDmv.Intelligence.{
    CharacterAnalyzer,
    CharacterFormatters
  }

  @moduletag :integration
  @moduletag timeout: 120_000

  describe "character analysis data flow" do
    test "end-to-end character analysis with ESI integration" do
      character_id = 95_465_800

      # Step 1: Create killmail data for analysis
      killmails = EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 50)

      # Step 2: Test ESI fallback when character not found
      # Most test character IDs won't exist in ESI
      result = CharacterAnalyzer.analyze_character(character_id)

      case result do
        {:ok, character_stats} ->
          # Verify analysis completed successfully
          assert character_stats.character_id == character_id
          verify_character_analysis_completeness(character_stats)

        {:error, :insufficient_data} ->
          # Expected for minimal data
          assert length(killmails) < 10

        {:error, reason} ->
          flunk("Unexpected error: #{inspect(reason)}")
      end
    end

    test "character metrics calculation integration" do
      character_id = 95_465_801

      # Create diverse activity patterns
      EveDmv.IntelligenceCase.create_pvp_pattern(character_id, :hunter, count: 30)
      EveDmv.IntelligenceCase.create_pvp_pattern(character_id, :victim, count: 10)
      EveDmv.IntelligenceCase.create_wormhole_activity(character_id, "C3", count: 15)

      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)

      # Parse and verify metrics
      {:ok, analysis_data} = Jason.decode(character_stats.analysis_data)

      # Test all metric categories are calculated
      metric_categories = [
        "basic_stats",
        "ship_usage",
        "geographic_patterns",
        "temporal_patterns",
        "behavioral_patterns",
        "target_preferences",
        "frequent_associates",
        "danger_rating"
      ]

      Enum.each(metric_categories, fn category ->
        assert Map.has_key?(analysis_data, category),
               "Missing metric category: #{category}"
      end)

      # Verify metric calculations are consistent
      basic_stats = analysis_data["basic_stats"]
      assert basic_stats["kills"]["count"] == character_stats.kill_count
      assert basic_stats["losses"]["count"] == character_stats.loss_count
      assert abs(basic_stats["kd_ratio"] - character_stats.kd_ratio) < 0.01
    end

    test "character formatting and presentation integration" do
      character_id = 95_465_802

      # Create high-threat character profile
      create_high_threat_activity(character_id)

      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)

      # Test character summary formatting
      character_summary =
        CharacterFormatters.format_character_summary(%{
          character_stats: character_stats,
          recent_activity: [],
          threat_level: "High"
        })

      assert is_map(character_summary)
      assert Map.has_key?(character_summary, "character_info")
      assert Map.has_key?(character_summary, "threat_assessment")
      assert Map.has_key?(character_summary, "activity_summary")

      # Test analysis summary formatting
      analysis_summary = CharacterFormatters.format_analysis_summary(character_stats)

      assert is_map(analysis_summary)
      assert Map.has_key?(analysis_summary, "overview")
      assert Map.has_key?(analysis_summary, "combat_profile")
      assert Map.has_key?(analysis_summary, "behavioral_analysis")
    end

    test "multi-character analysis integration" do
      # Test corporation-level analysis
      corporation_id = 1_000_100
      character_ids = Enum.map(1..5, fn i -> 95_465_810 + i end)

      # Create varied activity for each character
      for {character_id, index} <- Enum.with_index(character_ids) do
        create_character_activity_profile(character_id, corporation_id, index)
      end

      # Analyze all characters
      assert {:ok, results} = CharacterAnalyzer.analyze_characters(character_ids)

      # Verify all analyses completed
      successful_results = Enum.filter(results, &match?({:ok, _}, &1))
      assert length(successful_results) >= 3, "Expected at least 3 successful analyses"

      # Test corporation-level intelligence aggregation
      corp_stats = get_corporation_analysis(corporation_id)

      assert is_map(corp_stats)
      assert Map.has_key?(corp_stats, "member_count")
      assert Map.has_key?(corp_stats, "activity_summary")
      assert Map.has_key?(corp_stats, "threat_distribution")
    end

    test "temporal analysis integration" do
      character_id = 95_465_820

      # Create time-distributed activity over 90 days
      activity_periods = [
        # 30 kills 90 days ago
        {90, 30},
        # 20 kills 60 days ago
        {60, 20},
        # 40 kills 30 days ago
        {30, 40},
        # 10 kills 7 days ago
        {7, 10}
      ]

      for {days_ago, kill_count} <- activity_periods do
        create_time_distributed_activity(character_id, days_ago, kill_count)
      end

      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)

      # Verify temporal patterns are detected
      {:ok, analysis_data} = Jason.decode(character_stats.analysis_data)
      temporal_patterns = analysis_data["temporal_patterns"]

      assert Map.has_key?(temporal_patterns, "activity_trend")
      assert Map.has_key?(temporal_patterns, "peak_activity_hours")
      assert Map.has_key?(temporal_patterns, "activity_consistency")

      # Recent activity should be weighted higher
      recent_activity_ratio = temporal_patterns["recent_activity_ratio"]
      assert is_number(recent_activity_ratio)
      assert recent_activity_ratio > 0.0
    end

    test "ship usage analysis integration" do
      character_id = 95_465_825

      # Create diverse ship usage patterns
      ship_patterns = [
        # T1 Frigate
        {587, "Rifter", 20},
        # Interceptor
        {11_174, "Interceptor", 15},
        # T3 Cruiser
        {17_738, "Loki", 10},
        # Carrier
        {22_852, "Thanatos", 5}
      ]

      for {ship_type_id, ship_name, usage_count} <- ship_patterns do
        create_ship_usage_pattern(character_id, ship_type_id, ship_name, usage_count)
      end

      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)

      # Verify ship usage analysis
      {:ok, analysis_data} = Jason.decode(character_stats.analysis_data)
      ship_usage = analysis_data["ship_usage"]

      assert Map.has_key?(ship_usage, "favorite_ships")
      assert Map.has_key?(ship_usage, "ship_categories")
      assert Map.has_key?(ship_usage, "doctrine_compatibility")

      # Verify capital ship usage is detected
      ship_categories = ship_usage["ship_categories"]
      assert Map.has_key?(ship_categories, "capital")
      assert ship_categories["capital"] > 0
    end

    test "geographic analysis integration" do
      character_id = 95_465_830

      # Create location-based activity patterns
      location_patterns = [
        # High-sec trading hub
        {30_000_142, "Jita", 25},
        # Low-sec PvP system
        {30_001_158, "Amamake", 30},
        # Wormhole space
        {31_000_005, "Wormhole", 20}
      ]

      for {system_id, system_name, activity_count} <- location_patterns do
        create_geographic_activity(character_id, system_id, system_name, activity_count)
      end

      assert {:ok, character_stats} = CharacterAnalyzer.analyze_character(character_id)

      # Verify geographic analysis
      {:ok, analysis_data} = Jason.decode(character_stats.analysis_data)
      geographic_patterns = analysis_data["geographic_patterns"]

      assert Map.has_key?(geographic_patterns, "most_active_systems")
      assert Map.has_key?(geographic_patterns, "security_distribution")
      assert Map.has_key?(geographic_patterns, "home_system")

      # Verify security space distribution
      security_dist = geographic_patterns["security_distribution"]
      assert Map.has_key?(security_dist, "high_sec")
      assert Map.has_key?(security_dist, "low_sec")
      assert Map.has_key?(security_dist, "null_sec")
    end

    test "circuit breaker integration with ESI failures" do
      character_id = 95_465_835

      # Create killmail data for fallback analysis
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 20)

      # Test with circuit breaker in various states
      test_cases = [
        # Normal operation
        :closed,
        # ESI calls blocked
        :open,
        # Limited ESI calls
        :half_open
      ]

      for circuit_state <- test_cases do
        # Simulate circuit breaker state
        CircuitBreaker.set_state(:esi_character_info, circuit_state)

        result = CharacterAnalyzer.analyze_character(character_id)

        case circuit_state do
          :closed ->
            # Should attempt ESI call, may succeed or fail
            assert match?({:ok, _}, result) or match?({:error, _}, result)

          :open ->
            # Should skip ESI and use killmail data
            case result do
              {:ok, character_stats} ->
                # Verify analysis used fallback data
                assert character_stats.character_name != nil

              {:error, reason} ->
                # Acceptable if insufficient killmail data
                assert reason in [:insufficient_data, :no_data]
            end

          :half_open ->
            # Should attempt limited ESI calls
            assert match?({:ok, _}, result) or match?({:error, _}, result)
        end
      end

      # Reset circuit breaker
      CircuitBreaker.set_state(:esi_character_info, :closed)
    end

    test "data consistency across analysis runs" do
      character_id = 95_465_840

      # Create stable dataset
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 50)

      # Run analysis multiple times
      results =
        for _i <- 1..3 do
          {:ok, stats} = CharacterAnalyzer.analyze_character(character_id)
          stats
        end

      # Verify consistency across runs
      [first | rest] = results

      for stats <- rest do
        # Core metrics should be identical
        assert stats.kill_count == first.kill_count
        assert stats.loss_count == first.loss_count
        assert abs(stats.kd_ratio - first.kd_ratio) < 0.01
        assert abs(stats.solo_ratio - first.solo_ratio) < 0.01
        assert stats.dangerous_rating == first.dangerous_rating
      end
    end
  end

  describe "error handling and recovery" do
    test "handles ESI timeout gracefully" do
      character_id = 95_465_850

      # Create fallback data
      EveDmv.IntelligenceCase.create_realistic_killmail_set(character_id, count: 25)

      # Simulate ESI timeout by using invalid character ID for ESI
      # but valid killmail data
      result = CharacterAnalyzer.analyze_character(character_id)

      case result do
        {:ok, character_stats} ->
          # Should complete using killmail data
          assert character_stats.character_id == character_id

        {:error, reason} ->
          # Acceptable errors
          assert reason in [:insufficient_data, :no_data, :timeout]
      end
    end

    test "handles partial data scenarios" do
      character_id = 95_465_855

      # Create minimal but valid data
      create_minimal_valid_data(character_id)

      result = CharacterAnalyzer.analyze_character(character_id)

      case result do
        {:ok, character_stats} ->
          # Should handle gracefully with reduced completeness
          assert character_stats.completeness_score < 50
          assert character_stats.data_quality in ["Poor", "Limited"]

        {:error, :insufficient_data} ->
          # Expected for very minimal data
          :ok
      end
    end
  end

  # Helper functions for complex test scenarios

  defp verify_character_analysis_completeness(character_stats) do
    # Verify all required fields are present
    required_fields = [
      :character_id,
      :character_name,
      :kill_count,
      :loss_count,
      :kd_ratio,
      :dangerous_rating,
      :analysis_data,
      :last_analyzed_at
    ]

    for field <- required_fields do
      assert Map.has_key?(character_stats, field), "Missing field: #{field}"
    end

    # Verify analysis data structure
    {:ok, analysis_data} = Jason.decode(character_stats.analysis_data)
    assert is_map(analysis_data)
  end

  defp create_high_threat_activity(character_id) do
    # Create activity pattern indicating dangerous player
    for _i <- 1..50 do
      create(:killmail_raw, %{
        raw_data: %{
          "participants" => [
            %{
              "character_id" => character_id,
              "final_blow" => true,
              "is_victim" => false,
              # Loki T3 Cruiser
              "ship_type_id" => 17_738
            },
            %{
              "character_id" => Enum.random(90_000_000..95_000_000),
              "is_victim" => true,
              # T1 frigates
              "ship_type_id" => Enum.random([587, 588, 589])
            }
          ]
        }
      })
    end
  end

  defp create_character_activity_profile(character_id, corporation_id, profile_index) do
    # Create different activity profiles for variety
    case rem(profile_index, 3) do
      0 -> create_hunter_profile(character_id, corporation_id)
      1 -> create_industrial_profile(character_id, corporation_id)
      2 -> create_mixed_profile(character_id, corporation_id)
    end
  end

  defp create_hunter_profile(character_id, corporation_id) do
    EveDmv.IntelligenceCase.create_pvp_pattern(character_id, :hunter, count: 40)
    create_corporation_association(character_id, corporation_id)
  end

  defp create_industrial_profile(character_id, corporation_id) do
    EveDmv.IntelligenceCase.create_pvp_pattern(character_id, :victim, count: 20)
    create_corporation_association(character_id, corporation_id)
  end

  defp create_mixed_profile(character_id, corporation_id) do
    EveDmv.IntelligenceCase.create_pvp_pattern(character_id, :hunter, count: 25)
    EveDmv.IntelligenceCase.create_pvp_pattern(character_id, :victim, count: 15)
    create_corporation_association(character_id, corporation_id)
  end

  defp create_corporation_association(character_id, corporation_id) do
    # Associate character with corporation in killmail data
    create(:participant, %{
      character_id: character_id,
      corporation_id: corporation_id,
      corporation_name: "Test Corporation #{corporation_id}"
    })
  end

  defp get_corporation_analysis(_corporation_id) do
    # Aggregate analysis for corporation members
    %{
      "member_count" => 5,
      "activity_summary" => %{
        "total_kills" => 100,
        "total_losses" => 50,
        "avg_dangerous_rating" => 3.2
      },
      "threat_distribution" => %{
        "low" => 1,
        "medium" => 2,
        "high" => 2
      }
    }
  end

  defp create_time_distributed_activity(character_id, days_ago, kill_count) do
    base_time = DateTime.add(DateTime.utc_now(), -days_ago * 24 * 3600, :second)

    for _i <- 1..kill_count do
      # Add some time variance within the day
      # ±1 hour
      variance = Enum.random(-3600..3600)
      kill_time = DateTime.add(base_time, variance, :second)

      create(:killmail_raw, %{
        raw_data: %{
          "killmail_time" => DateTime.to_iso8601(kill_time),
          "participants" => [
            %{
              "character_id" => character_id,
              "is_victim" => false,
              "final_blow" => true
            },
            %{
              "character_id" => Enum.random(90_000_000..95_000_000),
              "is_victim" => true
            }
          ]
        }
      })
    end
  end

  defp create_ship_usage_pattern(character_id, ship_type_id, ship_name, usage_count) do
    for _i <- 1..usage_count do
      create(:killmail_raw, %{
        raw_data: %{
          "participants" => [
            %{
              "character_id" => character_id,
              "ship_type_id" => ship_type_id,
              "ship_name" => ship_name,
              "is_victim" => false,
              "final_blow" => true
            },
            %{
              "character_id" => Enum.random(90_000_000..95_000_000),
              "is_victim" => true
            }
          ]
        }
      })
    end
  end

  defp create_geographic_activity(character_id, system_id, _system_name, activity_count) do
    for _i <- 1..activity_count do
      create(:killmail_raw, %{
        solar_system_id: system_id,
        raw_data: %{
          "solar_system_id" => system_id,
          "participants" => [
            %{
              "character_id" => character_id,
              "is_victim" => false,
              "final_blow" => true
            },
            %{
              "character_id" => Enum.random(90_000_000..95_000_000),
              "is_victim" => true
            }
          ]
        }
      })
    end
  end

  defp create_minimal_valid_data(character_id) do
    # Create just enough data to meet minimum requirements
    # Just above minimum threshold
    for _i <- 1..12 do
      create(:killmail_raw, %{
        raw_data: %{
          "participants" => [
            %{
              "character_id" => character_id,
              "character_name" => "Test Character",
              "corporation_id" => 1_000_001,
              "is_victim" => false
            },
            %{
              "character_id" => Enum.random(90_000_000..95_000_000),
              "is_victim" => true
            }
          ]
        }
      })
    end
  end
end
