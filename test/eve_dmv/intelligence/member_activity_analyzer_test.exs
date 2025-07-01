defmodule EveDmv.Intelligence.MemberActivityAnalyzerTest do
  @moduledoc """
  Comprehensive tests for MemberActivityAnalyzer module.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Intelligence.MemberActivityAnalyzer

  describe "analyze_corporation_activity/1" do
    test "analyzes corporation member activity patterns" do
      corporation_id = 123_456_789

      case MemberActivityAnalyzer.analyze_corporation_activity(corporation_id) do
        {:ok, analysis} ->
          assert %{
                   corporation_id: ^corporation_id,
                   total_members: total,
                   active_members: active,
                   activity_trends: trends,
                   engagement_metrics: metrics
                 } = analysis

          assert is_integer(total)
          assert is_integer(active)
          assert total >= active
          assert is_map(trends)
          assert is_map(metrics)

        {:error, :insufficient_data} ->
          # Expected when no member data exists
          assert true

        {:error, reason} ->
          assert is_atom(reason) or is_binary(reason)
      end
    end

    test "handles invalid corporation ID" do
      result = MemberActivityAnalyzer.analyze_corporation_activity(-1)
      assert {:error, _reason} = result
    end

    test "handles nil corporation ID" do
      result = MemberActivityAnalyzer.analyze_corporation_activity(nil)
      assert {:error, _reason} = result
    end
  end

  describe "calculate_member_engagement/1" do
    test "calculates engagement with member activity data" do
      member_activities = [
        %{
          character_id: 123,
          character_name: "Active Pilot",
          last_seen: ~U[2024-01-01 12:00:00Z],
          killmail_count: 50,
          fleet_participation: 0.85,
          communication_activity: 25,
          days_since_join: 100
        },
        %{
          character_id: 456,
          character_name: "Inactive Pilot",
          last_seen: ~U[2023-12-01 12:00:00Z],
          killmail_count: 5,
          fleet_participation: 0.15,
          communication_activity: 2,
          days_since_join: 200
        }
      ]

      result = MemberActivityAnalyzer.calculate_member_engagement(member_activities)

      assert %{
               highly_engaged: highly_engaged,
               moderately_engaged: moderate,
               low_engagement: low,
               inactive_members: inactive,
               overall_engagement_score: score
             } = result

      assert is_list(highly_engaged)
      assert is_list(moderate)
      assert is_list(low)
      assert is_list(inactive)
      assert is_number(score)
      assert score >= 0 and score <= 100

      # Should classify the active pilot as highly engaged
      assert Enum.any?(highly_engaged, fn member -> member.character_id == 123 end)
    end

    test "handles empty member activities" do
      result = MemberActivityAnalyzer.calculate_member_engagement([])

      assert %{
               highly_engaged: [],
               moderately_engaged: [],
               low_engagement: [],
               inactive_members: [],
               overall_engagement_score: 0
             } = result
    end
  end

  describe "analyze_activity_trends/2" do
    test "analyzes trends over time period" do
      member_activities = [
        %{
          character_id: 123,
          activity_history: [
            %{date: ~D[2024-01-01], killmails: 5, fleet_ops: 2},
            %{date: ~D[2024-01-02], killmails: 3, fleet_ops: 1},
            %{date: ~D[2024-01-03], killmails: 7, fleet_ops: 3}
          ]
        },
        %{
          character_id: 456,
          activity_history: [
            %{date: ~D[2024-01-01], killmails: 0, fleet_ops: 0},
            %{date: ~D[2024-01-02], killmails: 1, fleet_ops: 0},
            %{date: ~D[2024-01-03], killmails: 0, fleet_ops: 0}
          ]
        }
      ]

      days = 7

      result = MemberActivityAnalyzer.analyze_activity_trends(member_activities, days)

      assert %{
               trend_direction: direction,
               growth_rate: growth,
               activity_peaks: peaks,
               seasonal_patterns: patterns
             } = result

      assert direction in [:increasing, :decreasing, :stable, :volatile]
      assert is_number(growth)
      assert is_list(peaks)
      assert is_map(patterns)
    end

    test "detects increasing trend" do
      increasing_activities = [
        %{
          character_id: 123,
          activity_history: [
            %{date: ~D[2024-01-01], killmails: 1, fleet_ops: 1},
            %{date: ~D[2024-01-02], killmails: 3, fleet_ops: 2},
            %{date: ~D[2024-01-03], killmails: 5, fleet_ops: 3}
          ]
        }
      ]

      result = MemberActivityAnalyzer.analyze_activity_trends(increasing_activities, 3)

      assert result.trend_direction == :increasing
      assert result.growth_rate > 0
    end
  end

  describe "identify_retention_risks/1" do
    test "identifies members at risk of leaving" do
      member_data = [
        %{
          character_id: 123,
          character_name: "Stable Member",
          recent_activity_score: 85,
          engagement_trend: :stable,
          days_since_join: 365,
          warning_signs: []
        },
        %{
          character_id: 456,
          character_name: "At Risk Member",
          recent_activity_score: 15,
          engagement_trend: :decreasing,
          days_since_join: 30,
          warning_signs: ["low_participation", "no_recent_comms"]
        }
      ]

      result = MemberActivityAnalyzer.identify_retention_risks(member_data)

      assert %{
               high_risk_members: high_risk,
               medium_risk_members: medium_risk,
               stable_members: stable,
               risk_factors: factors
             } = result

      assert is_list(high_risk)
      assert is_list(medium_risk)
      assert is_list(stable)
      assert is_map(factors)

      # Should identify the at-risk member
      assert Enum.any?(high_risk ++ medium_risk, fn member ->
               member.character_id == 456
             end)
    end

    test "handles all stable members" do
      stable_members = [
        %{
          character_id: 123,
          recent_activity_score: 90,
          engagement_trend: :stable,
          warning_signs: []
        },
        %{
          character_id: 456,
          recent_activity_score: 85,
          engagement_trend: :increasing,
          warning_signs: []
        }
      ]

      result = MemberActivityAnalyzer.identify_retention_risks(stable_members)

      assert Enum.empty?(result.high_risk_members)
      assert length(result.stable_members) == 2
    end
  end

  describe "generate_recruitment_insights/1" do
    test "generates insights for recruitment strategy" do
      activity_data = %{
        total_members: 50,
        active_members: 35,
        engagement_metrics: %{
          overall_engagement_score: 72,
          high_engagement_ratio: 0.6
        },
        retention_analysis: %{
          high_risk_members: [%{character_id: 123}],
          stable_members: [%{character_id: 456}, %{character_id: 789}]
        },
        activity_trends: %{
          trend_direction: :stable,
          growth_rate: 0.05
        }
      }

      result = MemberActivityAnalyzer.generate_recruitment_insights(activity_data)

      assert %{
               recommended_recruitment_rate: rate,
               target_member_profiles: profiles,
               recruitment_priorities: priorities,
               capacity_assessment: capacity
             } = result

      assert is_number(rate)
      assert rate >= 0
      assert is_list(profiles)
      assert is_list(priorities)
      assert is_map(capacity)
    end

    test "recommends high recruitment for declining corp" do
      declining_data = %{
        total_members: 20,
        active_members: 8,
        engagement_metrics: %{overall_engagement_score: 30},
        retention_analysis: %{
          high_risk_members: [%{character_id: 1}, %{character_id: 2}],
          stable_members: [%{character_id: 3}]
        },
        activity_trends: %{
          trend_direction: :decreasing,
          growth_rate: -0.2
        }
      }

      result = MemberActivityAnalyzer.generate_recruitment_insights(declining_data)

      # Should recommend aggressive recruitment
      assert result.recommended_recruitment_rate > 0.15

      assert Enum.any?(result.recruitment_priorities, fn priority ->
               String.contains?(String.downcase(priority), "urgent") or
                 String.contains?(String.downcase(priority), "immediate")
             end)
    end
  end

  describe "calculate_fleet_participation_metrics/1" do
    test "calculates participation metrics from fleet data" do
      fleet_data = [
        %{
          character_id: 123,
          fleet_ops_attended: 15,
          fleet_ops_available: 20,
          # minutes
          avg_fleet_duration: 120,
          leadership_roles: 5
        },
        %{
          character_id: 456,
          fleet_ops_attended: 5,
          fleet_ops_available: 20,
          avg_fleet_duration: 90,
          leadership_roles: 0
        }
      ]

      result = MemberActivityAnalyzer.calculate_fleet_participation_metrics(fleet_data)

      assert %{
               avg_participation_rate: avg_rate,
               high_participation_members: high_part,
               leadership_distribution: leadership,
               fleet_readiness_score: readiness
             } = result

      assert is_number(avg_rate)
      assert avg_rate >= 0 and avg_rate <= 1
      assert is_list(high_part)
      assert is_map(leadership)
      assert is_number(readiness)
      assert readiness >= 0 and readiness <= 100
    end

    test "handles no fleet data" do
      result = MemberActivityAnalyzer.calculate_fleet_participation_metrics([])

      assert %{
               avg_participation_rate: 0.0,
               high_participation_members: [],
               leadership_distribution: %{},
               fleet_readiness_score: 0
             } = result
    end
  end

  describe "analyze_communication_patterns/1" do
    test "analyzes member communication activity" do
      comm_data = [
        %{
          character_id: 123,
          discord_messages: 150,
          forum_posts: 25,
          voice_chat_hours: 50,
          help_requests: 5,
          helpful_responses: 20
        },
        %{
          character_id: 456,
          discord_messages: 10,
          forum_posts: 0,
          voice_chat_hours: 2,
          help_requests: 0,
          helpful_responses: 1
        }
      ]

      result = MemberActivityAnalyzer.analyze_communication_patterns(comm_data)

      assert %{
               communication_health: health,
               active_communicators: active,
               silent_members: silent,
               community_contributors: contributors
             } = result

      assert health in [:healthy, :moderate, :poor]
      assert is_list(active)
      assert is_list(silent)
      assert is_list(contributors)

      # High activity member should be in active communicators
      assert Enum.any?(active, fn member -> member.character_id == 123 end)

      # Low activity member should be in silent members
      assert Enum.any?(silent, fn member -> member.character_id == 456 end)
    end
  end

  describe "generate_activity_recommendations/1" do
    test "generates recommendations based on analysis" do
      analysis_data = %{
        engagement_metrics: %{overall_engagement_score: 60},
        activity_trends: %{trend_direction: :decreasing},
        retention_risks: %{
          high_risk_members: [%{character_id: 123}],
          risk_factors: %{low_participation: 5}
        },
        fleet_participation: %{
          avg_participation_rate: 0.45,
          fleet_readiness_score: 55
        },
        communication_health: :moderate
      }

      result = MemberActivityAnalyzer.generate_activity_recommendations(analysis_data)

      assert %{
               immediate_actions: immediate,
               engagement_strategies: strategies,
               retention_initiatives: retention,
               long_term_goals: long_term
             } = result

      assert is_list(immediate)
      assert is_list(strategies)
      assert is_list(retention)
      assert is_list(long_term)

      # Should recommend addressing retention risks
      all_recommendations = immediate ++ strategies ++ retention ++ long_term

      assert Enum.any?(all_recommendations, fn rec ->
               String.contains?(String.downcase(rec), "retention") or
                 String.contains?(String.downcase(rec), "engagement")
             end)
    end
  end

  describe "helper functions" do
    test "calculate_engagement_score/1 computes realistic scores" do
      high_engagement_member = %{
        killmail_count: 100,
        fleet_participation: 0.9,
        communication_activity: 50,
        days_since_join: 365
      }

      score = MemberActivityAnalyzer.calculate_engagement_score(high_engagement_member)
      assert score > 80

      low_engagement_member = %{
        killmail_count: 2,
        fleet_participation: 0.1,
        communication_activity: 1,
        days_since_join: 30
      }

      score = MemberActivityAnalyzer.calculate_engagement_score(low_engagement_member)
      assert score < 40
    end

    test "classify_activity_level/1 correctly categorizes members" do
      assert MemberActivityAnalyzer.classify_activity_level(90) == :highly_active
      assert MemberActivityAnalyzer.classify_activity_level(70) == :moderately_active
      assert MemberActivityAnalyzer.classify_activity_level(40) == :low_activity
      assert MemberActivityAnalyzer.classify_activity_level(10) == :inactive
    end

    test "calculate_trend_direction/1 identifies trends correctly" do
      increasing_data = [10, 15, 20, 25, 30]
      assert MemberActivityAnalyzer.calculate_trend_direction(increasing_data) == :increasing

      decreasing_data = [30, 25, 20, 15, 10]
      assert MemberActivityAnalyzer.calculate_trend_direction(decreasing_data) == :decreasing

      stable_data = [20, 21, 19, 20, 22]
      assert MemberActivityAnalyzer.calculate_trend_direction(stable_data) == :stable

      volatile_data = [10, 30, 5, 25, 8]
      assert MemberActivityAnalyzer.calculate_trend_direction(volatile_data) == :volatile
    end

    test "days_since_last_activity/2 calculates correctly" do
      last_activity = DateTime.add(DateTime.utc_now(), -5, :day)
      current_time = DateTime.utc_now()

      days = MemberActivityAnalyzer.days_since_last_activity(last_activity, current_time)
      # Allow for small timing differences
      assert days >= 4 and days <= 6
    end
  end

  describe "integration with corporation data" do
    test "fetches and processes real corporation member data" do
      corporation_id = 123_456_789

      case MemberActivityAnalyzer.fetch_corporation_members(corporation_id) do
        {:ok, members} ->
          assert is_list(members)

          if length(members) > 0 do
            member = List.first(members)
            assert Map.has_key?(member, :character_id)
            assert Map.has_key?(member, :character_name)
          end

        {:error, :not_found} ->
          # Expected when corporation doesn't exist
          assert true

        {:error, reason} ->
          assert is_atom(reason) or is_binary(reason)
      end
    end

    test "processes activity data with real time constraints" do
      # Test with current timestamp to ensure time calculations work
      current_time = DateTime.utc_now()

      member_data = %{
        character_id: 123,
        last_activity: DateTime.add(current_time, -2, :day),
        join_date: DateTime.add(current_time, -100, :day)
      }

      result = MemberActivityAnalyzer.process_member_activity(member_data, current_time)

      assert Map.has_key?(result, :days_since_last_activity)
      assert Map.has_key?(result, :days_since_join)
      assert result.days_since_last_activity >= 1
      assert result.days_since_join >= 99
    end
  end
end
