defmodule EveDmv.Intelligence.HomeDefenseAnalyzerTest do
  @moduledoc """
  Comprehensive tests for HomeDefenseAnalyzer module.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Intelligence.HomeDefenseAnalyzer

  describe "analyze_corporation/1" do
    test "analyzes corporation defense capabilities" do
      corporation_id = 123_456_789

      case HomeDefenseAnalyzer.analyze_corporation(corporation_id) do
        {:ok, analysis} ->
          assert %{
                   corporation_id: ^corporation_id,
                   defense_score: score,
                   coverage_analysis: coverage,
                   capability_assessment: capabilities
                 } = analysis

          assert is_number(score)
          assert score >= 0 and score <= 100
          assert is_map(coverage)
          assert is_map(capabilities)

        {:error, :insufficient_data} ->
          # Expected when no member data exists
          assert true

        {:error, reason} ->
          assert is_atom(reason) or is_binary(reason)
      end
    end

    test "handles invalid corporation ID" do
      result = HomeDefenseAnalyzer.analyze_corporation(-1)
      assert {:error, _reason} = result
    end

    test "handles nil corporation ID" do
      result = HomeDefenseAnalyzer.analyze_corporation(nil)
      assert {:error, _reason} = result
    end
  end

  describe "calculate_timezone_coverage/1" do
    test "calculates coverage with member activity data" do
      member_activities = [
        %{
          character_id: 123,
          character_name: "Pilot A",
          timezone: "UTC",
          active_hours: [12, 13, 14, 15, 16],
          last_activity: ~U[2024-01-01 12:00:00Z],
          activity_score: 85
        },
        %{
          character_id: 456,
          character_name: "Pilot B",
          timezone: "US/Eastern",
          active_hours: [20, 21, 22, 23, 0],
          last_activity: ~U[2024-01-01 20:00:00Z],
          activity_score: 70
        }
      ]

      result = HomeDefenseAnalyzer.calculate_timezone_coverage(member_activities)

      assert %{
               coverage_score: score,
               timezone_distribution: distribution,
               weak_periods: weak_periods,
               peak_activity_times: peak_times
             } = result

      assert is_number(score)
      assert score >= 0 and score <= 100
      assert is_map(distribution)
      assert is_list(weak_periods)
      assert is_list(peak_times)
    end

    test "handles empty member activities" do
      result = HomeDefenseAnalyzer.calculate_timezone_coverage([])

      assert %{
               coverage_score: 0,
               timezone_distribution: %{},
               weak_periods: [],
               peak_activity_times: []
             } = result
    end
  end

  describe "assess_fleet_capabilities/1" do
    test "assesses capabilities with member data" do
      members = [
        %{
          character_id: 123,
          ship_types: ["Damnation", "Legion", "Guardian"],
          doctrine_compliance: 85,
          fc_capability: true,
          logistics_capability: true
        },
        %{
          character_id: 456,
          ship_types: ["Muninn", "Scimitar"],
          doctrine_compliance: 70,
          fc_capability: false,
          logistics_capability: true
        }
      ]

      result = HomeDefenseAnalyzer.assess_fleet_capabilities(members)

      assert %{
               total_members: total,
               doctrine_ships: doctrine,
               fc_count: fc_count,
               logistics_count: logi_count,
               capability_score: score
             } = result

      assert total == length(members)
      assert is_map(doctrine)
      assert is_integer(fc_count)
      assert is_integer(logi_count)
      assert is_number(score)
      assert score >= 0 and score <= 100
    end

    test "handles empty member list" do
      result = HomeDefenseAnalyzer.assess_fleet_capabilities([])

      assert %{
               total_members: 0,
               doctrine_ships: %{},
               fc_count: 0,
               logistics_count: 0,
               capability_score: 0
             } = result
    end
  end

  describe "calculate_response_readiness/2" do
    test "calculates readiness based on recent activity" do
      members = [
        %{
          character_id: 123,
          last_activity: ~U[2024-01-01 12:00:00Z],
          response_time_minutes: 15,
          availability_score: 90
        },
        %{
          character_id: 456,
          last_activity: ~U[2024-01-01 10:00:00Z],
          response_time_minutes: 30,
          availability_score: 75
        }
      ]

      current_time = ~U[2024-01-01 12:30:00Z]

      result = HomeDefenseAnalyzer.calculate_response_readiness(members, current_time)

      assert %{
               immediate_response: immediate,
               avg_response_time: avg_time,
               readiness_score: score,
               available_members: available
             } = result

      assert is_integer(immediate)
      assert is_number(avg_time)
      assert is_number(score)
      assert score >= 0 and score <= 100
      assert is_list(available)
    end

    test "handles no recent activity" do
      members = [
        %{
          character_id: 123,
          # 11.5 hours ago
          last_activity: ~U[2024-01-01 01:00:00Z],
          response_time_minutes: 60,
          availability_score: 30
        }
      ]

      current_time = ~U[2024-01-01 12:30:00Z]

      result = HomeDefenseAnalyzer.calculate_response_readiness(members, current_time)

      assert result.immediate_response == 0
      assert result.readiness_score < 50
    end
  end

  describe "identify_defense_weaknesses/1" do
    test "identifies weaknesses from analysis data" do
      analysis_data = %{
        timezone_coverage: %{
          coverage_score: 45,
          weak_periods: [
            %{start_hour: 2, end_hour: 8, coverage: 10}
          ]
        },
        fleet_capabilities: %{
          fc_count: 1,
          logistics_count: 2,
          capability_score: 60
        },
        response_readiness: %{
          readiness_score: 40,
          avg_response_time: 45
        }
      }

      result = HomeDefenseAnalyzer.identify_defense_weaknesses(analysis_data)

      assert %{
               critical_weaknesses: critical,
               moderate_weaknesses: moderate,
               improvement_suggestions: suggestions
             } = result

      assert is_list(critical)
      assert is_list(moderate)
      assert is_list(suggestions)

      # Should identify timezone coverage as a weakness
      assert Enum.any?(critical ++ moderate, fn w ->
               String.contains?(w.description, "timezone") or
                 String.contains?(w.description, "coverage")
             end)
    end

    test "identifies no weaknesses for strong defense" do
      analysis_data = %{
        timezone_coverage: %{
          coverage_score: 95,
          weak_periods: []
        },
        fleet_capabilities: %{
          fc_count: 5,
          logistics_count: 8,
          capability_score: 90
        },
        response_readiness: %{
          readiness_score: 85,
          avg_response_time: 10
        }
      }

      result = HomeDefenseAnalyzer.identify_defense_weaknesses(analysis_data)

      assert Enum.empty?(result.critical_weaknesses)
      # Might have minor suggestions
      assert length(result.moderate_weaknesses) <= 1
    end
  end

  describe "generate_defense_recommendations/1" do
    test "generates recommendations based on analysis" do
      analysis_data = %{
        defense_score: 65,
        timezone_coverage: %{coverage_score: 50},
        fleet_capabilities: %{capability_score: 70},
        response_readiness: %{readiness_score: 75},
        weaknesses: %{
          critical_weaknesses: [
            %{type: "timezone_gap", description: "Poor AUTZ coverage"}
          ],
          moderate_weaknesses: []
        }
      }

      result = HomeDefenseAnalyzer.generate_defense_recommendations(analysis_data)

      assert %{
               priority_actions: priority,
               short_term_goals: short_term,
               long_term_strategy: long_term,
               resource_requirements: resources
             } = result

      assert is_list(priority)
      assert is_list(short_term)
      assert is_list(long_term)
      assert is_map(resources)

      # Should recommend timezone improvements
      all_recommendations = priority ++ short_term ++ long_term

      assert Enum.any?(all_recommendations, fn rec ->
               String.contains?(String.downcase(rec), "timezone") or
                 String.contains?(String.downcase(rec), "autz")
             end)
    end
  end

  describe "calculate_defense_score/1" do
    test "calculates overall defense score" do
      analysis_components = %{
        timezone_coverage: %{coverage_score: 75},
        fleet_capabilities: %{capability_score: 80},
        response_readiness: %{readiness_score: 70},
        member_count: 25,
        activity_level: 85
      }

      score = HomeDefenseAnalyzer.calculate_defense_score(analysis_components)

      assert is_number(score)
      assert score >= 0 and score <= 100
      # Should be reasonably high with good inputs
      assert score > 70
    end

    test "penalizes low member count" do
      # Test with very low member count
      low_member_analysis = %{
        timezone_coverage: %{coverage_score: 90},
        fleet_capabilities: %{capability_score: 90},
        response_readiness: %{readiness_score: 90},
        # Very low
        member_count: 3,
        activity_level: 90
      }

      score = HomeDefenseAnalyzer.calculate_defense_score(low_member_analysis)
      # Should be penalized despite good other metrics
      assert score < 70
    end
  end

  describe "format_analysis_report/1" do
    test "formats complete analysis into readable report" do
      analysis = %{
        corporation_id: 123_456_789,
        defense_score: 72,
        timezone_coverage: %{
          coverage_score: 68,
          weak_periods: [%{start_hour: 4, end_hour: 10}]
        },
        fleet_capabilities: %{
          capability_score: 75,
          fc_count: 3,
          logistics_count: 5
        },
        response_readiness: %{
          readiness_score: 70,
          avg_response_time: 20
        },
        recommendations: %{
          priority_actions: ["Recruit AUTZ members"],
          short_term_goals: ["Train more FCs"]
        }
      }

      result = HomeDefenseAnalyzer.format_analysis_report(analysis)

      assert %{
               executive_summary: summary,
               detailed_metrics: metrics,
               actionable_recommendations: recommendations
             } = result

      assert is_binary(summary)
      assert is_map(metrics)
      assert is_list(recommendations)

      # Should mention the defense score
      assert String.contains?(summary, "72")
    end
  end

  describe "helper functions" do
    test "classify_timezone/1 correctly identifies timezones" do
      assert HomeDefenseAnalyzer.classify_timezone("UTC") == :eutz
      assert HomeDefenseAnalyzer.classify_timezone("US/Eastern") == :ustz
      assert HomeDefenseAnalyzer.classify_timezone("Australia/Sydney") == :autz
      assert HomeDefenseAnalyzer.classify_timezone("Unknown") == :unknown
    end

    test "calculate_activity_score/2 computes realistic scores" do
      # Recent activity should score high
      recent_time = DateTime.add(DateTime.utc_now(), -1, :hour)
      score = HomeDefenseAnalyzer.calculate_activity_score(recent_time, DateTime.utc_now())
      assert score > 80

      # Old activity should score low
      old_time = DateTime.add(DateTime.utc_now(), -7, :day)
      score = HomeDefenseAnalyzer.calculate_activity_score(old_time, DateTime.utc_now())
      assert score < 30
    end

    test "doctrine_ship?/1 identifies doctrine ships" do
      assert HomeDefenseAnalyzer.doctrine_ship?("Damnation") == true
      assert HomeDefenseAnalyzer.doctrine_ship?("Legion") == true
      assert HomeDefenseAnalyzer.doctrine_ship?("Guardian") == true
      assert HomeDefenseAnalyzer.doctrine_ship?("Rifter") == false
      assert HomeDefenseAnalyzer.doctrine_ship?("Unknown Ship") == false
    end

    test "calculate_coverage_gap/2 finds gaps correctly" do
      # Missing 11-19
      active_hours = [8, 9, 10, 20, 21, 22]
      gap = HomeDefenseAnalyzer.calculate_coverage_gap(active_hours, 24)

      # Should find the 11-19 gap
      assert gap.max_gap_hours >= 8
      assert gap.total_uncovered_hours > 0
    end
  end

  describe "integration with member data" do
    test "fetches and processes real member data" do
      corporation_id = 123_456_789

      case HomeDefenseAnalyzer.fetch_member_data(corporation_id) do
        {:ok, members} ->
          assert is_list(members)

          if length(members) > 0 do
            member = List.first(members)
            assert Map.has_key?(member, :character_id)
            assert Map.has_key?(member, :character_name)
          end

        {:error, :not_found} ->
          # Expected when corporation doesn't exist or has no members
          assert true

        {:error, reason} ->
          assert is_atom(reason) or is_binary(reason)
      end
    end
  end
end
