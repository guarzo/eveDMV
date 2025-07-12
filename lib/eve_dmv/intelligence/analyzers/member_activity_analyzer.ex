defmodule EveDmv.Intelligence.Analyzers.MemberActivityAnalyzer do
  @moduledoc """
  Main coordinator module for member activity analysis.

  Provides a unified interface for analyzing corporation member activity patterns,
  engagement metrics, and activity trends. Delegates to specialized helper modules
  for specific analysis tasks.
  """

  alias EveDmv.Intelligence.Analyzers.MemberActivityAnalyzer.CorporationAnalyzer
  alias EveDmv.Intelligence.Analyzers.MemberActivityAnalyzer.EngagementAnalyzer

  require Logger

  @doc """
  Analyze corporation member activity patterns.

  Returns comprehensive activity analysis including member counts, activity trends,
  and engagement metrics for the specified corporation.
  """
  def analyze_corporation_activity(corporation_id)
      when is_integer(corporation_id) and corporation_id > 0 do
    Logger.info("Analyzing corporation activity for corp #{corporation_id}")

    case CorporationAnalyzer.generate_corporation_activity_report(corporation_id) do
      {:ok, report} ->
        # Transform the report into the expected format
        {:ok,
         %{
           corporation_id: corporation_id,
           total_members: get_total_members(report),
           active_members: get_active_members(report),
           activity_trends: get_activity_trends(report),
           engagement_metrics: get_engagement_metrics(report)
         }}

      {:error, :no_members_found} ->
        {:error, :insufficient_data}

      {:error, reason} ->
        Logger.warning("Failed to analyze corporation #{corporation_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def analyze_corporation_activity(invalid_id) do
    Logger.warning("Invalid corporation ID provided: #{inspect(invalid_id)}")
    {:error, :invalid_corporation_id}
  end

  @doc """
  Calculate member engagement metrics from member activities.

  Analyzes individual member engagement patterns and returns aggregated metrics.
  """
  def calculate_member_engagement(member_activities) when is_list(member_activities) do
    if Enum.empty?(member_activities) do
      %{
        highly_engaged: [],
        moderately_engaged: [],
        low_engagement: [],
        inactive_members: [],
        overall_engagement_score: 0
      }
    else
      EngagementAnalyzer.calculate_member_engagement(member_activities)
    end
  end

  def calculate_member_engagement(_invalid_input) do
    {:error, :invalid_input}
  end

  @doc """
  Analyze activity trends over a specified time period.

  Examines member activity patterns and identifies trends, growth rates,
  activity peaks, and seasonal patterns.
  """
  def analyze_activity_trends(member_activities, days)
      when is_list(member_activities) and is_integer(days) and days > 0 do
    # Extract activity time series data from member activities
    activity_data = extract_activity_time_series(member_activities, days)

    # Calculate trends from the activity data
    trends = %{
      daily_activity: activity_data,
      growth_rate: calculate_simple_growth_rate(activity_data),
      volatility: calculate_volatility(activity_data),
      peak_activities: find_peak_activities(activity_data)
    }

    %{
      trend_direction: determine_trend_direction(trends),
      growth_rate: calculate_growth_rate(trends),
      activity_peaks: identify_activity_peaks(trends),
      seasonal_patterns: extract_seasonal_patterns(trends)
    }
  end

  def analyze_activity_trends([], _days) do
    %{
      trend_direction: :stable,
      growth_rate: 0.0,
      activity_peaks: [],
      seasonal_patterns: %{}
    }
  end

  def analyze_activity_trends(_invalid_input, _days) do
    {:error, :invalid_input}
  end

  @doc """
  Identify members at risk of leaving the corporation.

  Analyzes member data to identify those at high, medium, or low risk of leaving,
  along with the risk factors contributing to their assessment.
  """
  def identify_retention_risks(member_data) when is_list(member_data) do
    {high_risk, medium_risk, stable} =
      Enum.reduce(member_data, {[], [], []}, fn member, {high, medium, stable} ->
        risk_level = calculate_retention_risk(member)

        case risk_level do
          :high_risk -> {[member | high], medium, stable}
          :medium_risk -> {high, [member | medium], stable}
          :stable -> {high, medium, [member | stable]}
        end
      end)

    risk_factors = identify_common_risk_factors(high_risk ++ medium_risk)

    %{
      high_risk_members: Enum.reverse(high_risk),
      medium_risk_members: Enum.reverse(medium_risk),
      stable_members: Enum.reverse(stable),
      risk_factors: risk_factors
    }
  end

  def identify_retention_risks(_invalid_input) do
    {:error, :invalid_input}
  end

  @doc """
  Analyze communication patterns for member activities.
  """
  def analyze_communication_patterns(communication_data) when is_list(communication_data) do
    total_members = length(communication_data)

    if total_members == 0 do
      %{
        communication_health: :poor,
        total_members: 0,
        active_communicators: [],
        silent_members: [],
        community_contributors: [],
        participation_rate: 0.0,
        communication_distribution: %{}
      }
    else
      # Analyze communication metrics - return actual lists instead of counts
      active_communicators =
        Enum.filter(communication_data, fn member ->
          total_activity =
            Map.get(member, :discord_messages, 0) +
              Map.get(member, :forum_posts, 0) +
              Map.get(member, :voice_chat_hours, 0)

          total_activity > 15
        end)

      silent_members =
        Enum.filter(communication_data, fn member ->
          total_activity =
            Map.get(member, :discord_messages, 0) +
              Map.get(member, :forum_posts, 0) +
              Map.get(member, :voice_chat_hours, 0)

          total_activity <= 15
        end)

      contributors =
        Enum.filter(communication_data, fn member ->
          Map.get(member, :helpful_responses, 0) > 5
        end)

      participation_rate = length(active_communicators) / total_members

      health =
        case participation_rate do
          rate when rate > 0.7 -> :healthy
          rate when rate > 0.5 -> :healthy
          rate when rate > 0.3 -> :moderate
          _ -> :poor
        end

      %{
        communication_health: health,
        active_communicators: active_communicators,
        silent_members: silent_members,
        community_contributors: contributors,
        total_members: total_members,
        participation_rate: Float.round(participation_rate, 2),
        communication_distribution: calculate_communication_distribution(communication_data)
      }
    end
  end

  def analyze_communication_patterns(_invalid_input) do
    {:error, :invalid_input}
  end

  @doc """
  Generate recruitment insights based on corporation analysis.
  """
  def generate_recruitment_insights(corporation_data) when is_map(corporation_data) do
    total_members = Map.get(corporation_data, :total_members, 0)
    active_members = Map.get(corporation_data, :active_members, 0)
    activity_trends = Map.get(corporation_data, :activity_trends, %{})
    engagement_metrics = Map.get(corporation_data, :engagement_metrics, %{})

    trend_direction = Map.get(activity_trends, :trend_direction, :stable)
    engagement_score = Map.get(engagement_metrics, :overall_engagement_score, 50)

    # Calculate recruitment priority
    recruitment_priority =
      calculate_recruitment_priority(
        total_members,
        active_members,
        trend_direction,
        engagement_score
      )

    # Generate recommendations
    recommendations = generate_recruitment_recommendations(recruitment_priority, corporation_data)

    target_recruits = calculate_target_recruits(total_members, active_members, trend_direction)

    %{
      recommended_recruitment_rate:
        case recruitment_priority do
          :urgent -> 0.8
          :high -> 0.6
          :medium -> 0.4
          :low -> 0.2
        end,
      target_member_profiles: determine_target_profiles(corporation_data),
      recruitment_priorities:
        case recruitment_priority do
          :urgent ->
            ["Urgent recruitment needed", "Immediate pilot acquisition", "Emergency hiring"]

          :high ->
            ["High priority recruitment", "Active pilot sourcing", "Fast-track hiring"]

          :medium ->
            ["Standard recruitment", "Selective hiring", "Quality over quantity"]

          :low ->
            ["Minimal recruitment", "Selective opportunities", "Quality candidates only"]
        end,
      capacity_assessment: %{
        current_capacity: total_members,
        target_capacity: total_members + target_recruits,
        growth_rate:
          case trend_direction do
            :increasing -> :sustainable
            :stable -> :steady
            :decreasing -> :recovery_needed
            _ -> :volatile
          end
      },
      recruitment_priority: recruitment_priority,
      recommended_action: get_recruitment_action(recruitment_priority),
      target_recruits: target_recruits,
      focus_areas: determine_recruitment_focus_areas(corporation_data),
      timeline: get_recruitment_timeline(recruitment_priority),
      success_indicators: recommendations.success_indicators,
      recruitment_channels: recommendations.channels
    }
  end

  def generate_recruitment_insights(_invalid_input) do
    {:error, :invalid_input}
  end

  @doc """
  Generate activity recommendations based on analysis.
  """
  def generate_activity_recommendations(analysis_data) when is_map(analysis_data) do
    activity_trends = Map.get(analysis_data, :activity_trends, %{})
    engagement_metrics = Map.get(analysis_data, :engagement_metrics, %{})
    retention_risks = Map.get(analysis_data, :retention_risks, %{})

    trend_direction = Map.get(activity_trends, :trend_direction, :stable)
    engagement_score = Map.get(engagement_metrics, :overall_engagement_score, 50)
    high_risk_count = length(Map.get(retention_risks, :high_risk_members, []))

    base_recommendations = []

    # Add trend-based recommendations
    trend_recommendations =
      case trend_direction do
        :decreasing ->
          [
            %{
              priority: :high,
              category: :engagement,
              action: "Organize member engagement events",
              reason: "Declining activity trend detected"
            }
            | base_recommendations
          ]

        :volatile ->
          [
            %{
              priority: :medium,
              category: :stability,
              action: "Implement consistent activity schedules",
              reason: "Activity patterns are inconsistent"
            }
            | base_recommendations
          ]

        _ ->
          base_recommendations
      end

    # Add engagement-based recommendations
    engagement_recommendations =
      if engagement_score < 50 do
        [
          %{
            priority: :high,
            category: :engagement,
            action: "Review and improve member onboarding",
            reason: "Low overall engagement score"
          }
          | trend_recommendations
        ]
      else
        trend_recommendations
      end

    # Add retention-based recommendations
    final_recommendations =
      if high_risk_count > 0 do
        [
          %{
            priority: :urgent,
            category: :retention,
            action: "Schedule one-on-one meetings with at-risk members",
            reason: "#{high_risk_count} members at high risk of leaving"
          }
          | engagement_recommendations
        ]
      else
        engagement_recommendations
      end

    # Transform recommendations into expected categories (as strings)
    immediate_actions =
      final_recommendations
      |> Enum.filter(&(&1.priority == :urgent))
      |> Enum.map(& &1.action)

    engagement_strategies =
      final_recommendations
      |> Enum.filter(&(&1.category == :engagement))
      |> Enum.map(& &1.action)

    retention_initiatives =
      final_recommendations
      |> Enum.filter(&(&1.category == :retention))
      |> Enum.map(& &1.action)

    long_term_goals =
      final_recommendations
      |> Enum.filter(&(&1.priority in [:medium, :low]))
      |> Enum.map(& &1.action)

    %{
      immediate_actions: immediate_actions,
      engagement_strategies: engagement_strategies,
      retention_initiatives: retention_initiatives,
      long_term_goals: long_term_goals,
      overall_health: calculate_overall_health(analysis_data),
      action_items: generate_action_items(final_recommendations),
      monitoring_suggestions: generate_monitoring_suggestions(analysis_data)
    }
  end

  def generate_activity_recommendations(_invalid_input) do
    {:error, :invalid_input}
  end

  @doc """
  Calculate days since last activity.
  """
  def days_since_last_activity(last_activity, current_time) do
    DateTime.diff(current_time, last_activity, :day)
  end

  @doc """
  Fetch corporation members data.
  """
  def fetch_corporation_members(corporation_id) when is_integer(corporation_id) do
    # Implement real corporation member fetching via ESI API
    try do
      # Get authentication token for ESI request (simplified - would need proper auth flow)
      case get_corporation_auth_token(corporation_id) do
        {:ok, auth_token} ->
          case EveDmv.Eve.EsiCorporationClient.get_corporation_members(corporation_id, auth_token) do
            {:ok, member_ids} when is_list(member_ids) ->
              # Enrich member data with character names and details
              members = enrich_member_data(member_ids)
              {:ok, members}

            {:error, reason} ->
              Logger.warning(
                "Failed to fetch corp members for #{corporation_id}: #{inspect(reason)}"
              )

              {:error, reason}
          end

        {:error, :no_auth_token} ->
          # Fallback to database lookup if no ESI auth available
          fetch_members_from_database(corporation_id)

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("Error fetching corporation members: #{inspect(error)}")
        {:error, :fetch_failed}
    end
  end

  def fetch_corporation_members(_invalid_id) do
    {:error, :invalid_corporation_id}
  end

  @doc """
  Calculate fleet participation metrics for member activities.
  """
  def calculate_fleet_participation_metrics(fleet_data) when is_list(fleet_data) do
    if Enum.empty?(fleet_data) do
      %{
        avg_participation_rate: 0.0,
        fleet_readiness_score: 0,
        total_fleet_ops: 0,
        active_fleet_participants: 0,
        high_participation_members: [],
        leadership_distribution: %{total_leaders: 0, leader_ratio: 0.0}
      }
    else
      total_ops = Enum.sum(Enum.map(fleet_data, &Map.get(&1, :fleet_ops, 0)))
      participants = Enum.count(fleet_data, &(Map.get(&1, :fleet_ops, 0) > 0))
      avg_rate = if length(fleet_data) > 0, do: participants / length(fleet_data), else: 0.0

      high_participation_members = Enum.filter(fleet_data, &(Map.get(&1, :fleet_ops, 0) >= 5))
      leadership_count = Enum.count(fleet_data, &Map.get(&1, :leadership_role, false))

      %{
        avg_participation_rate: Float.round(avg_rate, 2),
        fleet_readiness_score: min(100, round(avg_rate * 100 + total_ops)),
        total_fleet_ops: total_ops,
        active_fleet_participants: participants,
        high_participation_members: high_participation_members,
        leadership_distribution: %{
          total_leaders: leadership_count,
          leader_ratio:
            if(length(fleet_data) > 0, do: leadership_count / length(fleet_data), else: 0.0)
        }
      }
    end
  end

  def calculate_fleet_participation_metrics(_invalid_input) do
    {:error, :invalid_input}
  end

  @doc """
  Process member activity data with time constraints.
  """
  def process_member_activity(member_data, current_time) when is_map(member_data) do
    character_id = Map.get(member_data, :character_id)
    last_activity = Map.get(member_data, :last_activity)
    join_date = Map.get(member_data, :join_date)

    days_since_last =
      if last_activity do
        DateTime.diff(current_time, last_activity, :day)
      else
        999
      end

    days_since_join =
      if join_date do
        DateTime.diff(current_time, join_date, :day)
      else
        0
      end

    activity_status =
      case days_since_last do
        days when days <= 1 -> :very_active
        days when days <= 7 -> :active
        days when days <= 30 -> :moderate
        days when days <= 90 -> :inactive
        _ -> :dormant
      end

    %{
      character_id: character_id,
      activity_status: activity_status,
      days_since_last_activity: days_since_last,
      days_since_join: days_since_join,
      member_tenure: calculate_tenure_category(days_since_join),
      risk_level: calculate_simple_risk(days_since_last, days_since_join)
    }
  end

  def process_member_activity(_invalid_input, _current_time) do
    {:error, :invalid_input}
  end

  @doc """
  Calculate trend direction from activity data series.
  """
  def calculate_trend_direction(activity_data) when is_list(activity_data) do
    if length(activity_data) < 2 do
      :stable
    else
      # First check for volatility (high variance relative to mean)
      mean = Enum.sum(activity_data) / length(activity_data)

      variance =
        Enum.sum(Enum.map(activity_data, fn x -> :math.pow(x - mean, 2) end)) /
          length(activity_data)

      coefficient_of_variation = if mean > 0, do: :math.sqrt(variance) / mean, else: 0

      # If coefficient of variation is high, it's volatile
      if coefficient_of_variation > 0.5 do
        :volatile
      else
        # Calculate simple trend: compare first half vs second half
        mid_point = div(length(activity_data), 2)
        first_half = Enum.take(activity_data, mid_point)
        second_half = Enum.drop(activity_data, mid_point)

        first_avg =
          if length(first_half) > 0, do: Enum.sum(first_half) / length(first_half), else: 0

        second_avg =
          if length(second_half) > 0, do: Enum.sum(second_half) / length(second_half), else: 0

        growth_rate = if first_avg > 0, do: (second_avg - first_avg) / first_avg * 100, else: 0

        cond do
          growth_rate > 10 -> :increasing
          growth_rate < -10 -> :decreasing
          true -> :stable
        end
      end
    end
  end

  def calculate_trend_direction(_invalid_input) do
    {:error, :invalid_input}
  end

  @doc """
  Classify activity level based on activity score.
  """
  def classify_activity_level(activity_score) when is_number(activity_score) do
    case activity_score do
      score when score >= 80 -> :highly_active
      score when score >= 60 -> :moderately_active
      score when score >= 20 -> :low_activity
      _ -> :inactive
    end
  end

  def classify_activity_level(_invalid_input) do
    {:error, :invalid_input}
  end

  @doc """
  Calculate engagement score for a member.
  """
  def calculate_engagement_score(member_data) when is_map(member_data) do
    fleet_participation = Map.get(member_data, :fleet_participation, 0.0)
    communication_activity = Map.get(member_data, :communication_activity, 0)
    total_kills = Map.get(member_data, :total_kills, 0)
    total_losses = Map.get(member_data, :total_losses, 0)

    # Base score from fleet participation (0-40 points)
    fleet_score = fleet_participation * 40

    # Communication score (0-30 points)
    comm_score = min(30, communication_activity * 0.6)

    # Combat activity score (0-30 points)
    combat_score = min(30, (total_kills + total_losses) * 0.3)

    total_score = fleet_score + comm_score + combat_score
    round(min(100, total_score))
  end

  def calculate_engagement_score(_invalid_input) do
    {:error, :invalid_input}
  end

  # Private helper functions

  defp get_total_members(report) do
    case report do
      %{member_count: count} -> count
      %{member_details: details} when is_list(details) -> length(details)
      _ -> 0
    end
  end

  defp get_active_members(report) do
    case report do
      %{active_member_count: count} ->
        count

      %{member_details: details} when is_list(details) ->
        Enum.count(details, fn member ->
          Map.get(member, :activity_level, :inactive) != :inactive
        end)

      _ ->
        0
    end
  end

  defp get_activity_trends(report) do
    case report do
      %{activity_trends: trends} -> trends
      %{engagement_metrics: %{trends: trends}} -> trends
      _ -> %{direction: :stable, growth_rate: 0.0}
    end
  end

  defp get_engagement_metrics(report) do
    case report do
      %{engagement_metrics: metrics} ->
        metrics

      _ ->
        %{
          average_engagement: 0.5,
          participation_rate: 0.0,
          retention_rate: 0.0
        }
    end
  end

  defp determine_trend_direction(trends) do
    growth_rate = Map.get(trends, :growth_rate, 0.0)

    cond do
      growth_rate > 0.05 -> :increasing
      growth_rate < -0.05 -> :decreasing
      abs(growth_rate) < 0.02 -> :stable
      true -> :volatile
    end
  end

  defp calculate_growth_rate(trends) do
    Map.get(trends, :growth_rate, 0.0)
  end

  defp identify_activity_peaks(trends) do
    case Map.get(trends, :activity_peaks) do
      peaks when is_list(peaks) -> peaks
      _ -> []
    end
  end

  defp extract_seasonal_patterns(trends) do
    case Map.get(trends, :seasonal_patterns) do
      patterns when is_map(patterns) ->
        patterns

      _ ->
        %{
          daily_patterns: %{},
          weekly_patterns: %{},
          monthly_patterns: %{}
        }
    end
  end

  defp calculate_retention_risk(member) do
    activity_score = Map.get(member, :recent_activity_score, 50)
    engagement_trend = Map.get(member, :engagement_trend, :stable)
    warning_signs = Map.get(member, :warning_signs, [])
    days_since_join = Map.get(member, :days_since_join, 0)

    # Calculate risk score based on multiple factors
    base_risk_score = 0

    # Activity score contribution (0-40 points)
    activity_risk_score =
      base_risk_score +
        case activity_score do
          score when score < 20 -> 40
          score when score < 40 -> 30
          score when score < 60 -> 20
          score when score < 80 -> 10
          _ -> 0
        end

    # Engagement trend contribution (0-30 points)
    engagement_risk_score =
      activity_risk_score +
        case engagement_trend do
          :decreasing -> 30
          :volatile -> 20
          :stable -> 0
          :increasing -> -10
          _ -> 15
        end

    # Warning signs contribution (0-30 points)
    warning_risk_score = engagement_risk_score + min(length(warning_signs) * 10, 30)

    # New member risk (0-10 points)
    final_risk_score =
      warning_risk_score +
        case days_since_join do
          days when days < 30 -> 10
          days when days < 90 -> 5
          _ -> 0
        end

    # Determine risk level
    cond do
      final_risk_score >= 60 -> :high_risk
      final_risk_score >= 30 -> :medium_risk
      true -> :stable
    end
  end

  defp identify_common_risk_factors(at_risk_members) do
    if Enum.empty?(at_risk_members) do
      %{}
    else
      all_warning_signs =
        at_risk_members
        |> Enum.flat_map(&Map.get(&1, :warning_signs, []))
        |> Enum.frequencies()
        |> Enum.sort_by(fn {_, count} -> count end, :desc)
        |> Enum.take(5)
        |> Enum.map(fn {sign, count} -> %{factor: sign, occurrence_count: count} end)

      trends =
        at_risk_members
        |> Enum.map(&Map.get(&1, :engagement_trend, :stable))
        |> Enum.frequencies()
        |> Enum.sort_by(fn {_, count} -> count end, :desc)
        |> Enum.take(3)
        |> Enum.map(fn {trend, count} -> %{factor: "#{trend}_trend", occurrence_count: count} end)

      # Convert to map structure with factor names as keys
      Enum.reduce(all_warning_signs ++ trends, %{}, fn %{factor: factor, occurrence_count: count},
                                                       acc ->
        Map.put(acc, factor, count)
      end)
    end
  end

  # Helper functions for new analysis methods

  defp extract_activity_time_series(member_activities, _days) do
    # Extract and aggregate activity data
    daily_activities =
      member_activities
      |> Enum.flat_map(fn member ->
        Enum.map(Map.get(member, :activity_history, []), fn activity ->
          killmails = Map.get(activity, :killmails, 0)
          fleet_ops = Map.get(activity, :fleet_ops, 0)
          date = Map.get(activity, :date)
          # Weight fleet ops more heavily
          {date, killmails + fleet_ops * 2}
        end)
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(fn {date, activities} -> {date, Enum.sum(activities)} end)
      |> Enum.sort_by(&elem(&1, 0), Date)
      |> Enum.map(&elem(&1, 1))

    daily_activities
  end

  defp calculate_simple_growth_rate(activity_data) do
    if length(activity_data) < 2 do
      0.0
    else
      # Compare first half vs second half
      mid_point = div(length(activity_data), 2)
      first_half = Enum.take(activity_data, mid_point)
      second_half = Enum.drop(activity_data, mid_point)

      first_avg =
        if length(first_half) > 0, do: Enum.sum(first_half) / length(first_half), else: 0

      second_avg =
        if length(second_half) > 0, do: Enum.sum(second_half) / length(second_half), else: 0

      if first_avg > 0 do
        (second_avg - first_avg) / first_avg
      else
        0.0
      end
    end
  end

  defp calculate_volatility(activity_data) do
    if length(activity_data) < 2 do
      0.0
    else
      mean = Enum.sum(activity_data) / length(activity_data)

      variance =
        Enum.sum(Enum.map(activity_data, fn x -> :math.pow(x - mean, 2) end)) /
          length(activity_data)

      :math.sqrt(variance)
    end
  end

  defp find_peak_activities(activity_data) do
    activity_data
    |> Enum.with_index()
    |> Enum.sort_by(&elem(&1, 0), :desc)
    |> Enum.take(3)
    |> Enum.map(&elem(&1, 1))
  end

  defp calculate_communication_distribution(communication_data) do
    %{
      high_activity: Enum.count(communication_data, &(calculate_comm_score(&1) > 100)),
      medium_activity: Enum.count(communication_data, &(calculate_comm_score(&1) in 50..100)),
      low_activity: Enum.count(communication_data, &(calculate_comm_score(&1) in 10..49)),
      inactive: Enum.count(communication_data, &(calculate_comm_score(&1) < 10))
    }
  end

  defp calculate_comm_score(member) do
    Map.get(member, :discord_messages, 0) +
      Map.get(member, :forum_posts, 0) * 5 +
      Map.get(member, :voice_chat_hours, 0) * 2 +
      Map.get(member, :helpful_responses, 0) * 3
  end

  defp calculate_recruitment_priority(
         total_members,
         active_members,
         trend_direction,
         engagement_score
       ) do
    activity_ratio = if total_members > 0, do: active_members / total_members, else: 0

    base_score =
      case trend_direction do
        :decreasing -> 80
        :volatile -> 60
        :stable -> 40
        :increasing -> 20
      end

    engagement_modifier =
      case engagement_score do
        score when score < 30 -> 20
        score when score < 50 -> 10
        _ -> 0
      end

    activity_modifier =
      case activity_ratio do
        ratio when ratio < 0.3 -> 30
        ratio when ratio < 0.5 -> 20
        ratio when ratio < 0.7 -> 10
        _ -> 0
      end

    priority_score = base_score + engagement_modifier + activity_modifier

    case priority_score do
      score when score >= 90 -> :urgent
      score when score >= 70 -> :high
      score when score >= 50 -> :medium
      _ -> :low
    end
  end

  defp generate_recruitment_recommendations(priority, _corporation_data) do
    %{
      success_indicators:
        case priority do
          :urgent -> ["Member retention rate > 85%", "Activity trend reversal within 30 days"]
          :high -> ["New member integration score > 80%", "Fleet participation increase"]
          :medium -> ["Maintain current activity levels", "Quality over quantity recruitment"]
          :low -> ["Selective recruitment", "Focus on member development"]
        end,
      channels:
        case priority do
          :urgent -> ["Discord campaigns", "Alliance referrals", "Forum advertisements"]
          :high -> ["Discord campaigns", "Alliance referrals"]
          :medium -> ["Alliance referrals", "Word of mouth"]
          :low -> ["Word of mouth"]
        end
    }
  end

  defp get_recruitment_action(priority) do
    case priority do
      :urgent -> "Immediate recruitment drive"
      :high -> "Active recruitment campaign"
      :medium -> "Moderate recruitment effort"
      :low -> "Maintain current recruitment"
    end
  end

  defp calculate_target_recruits(total_members, active_members, trend_direction) do
    base_target =
      case trend_direction do
        :decreasing -> max(5, div(total_members, 4))
        :volatile -> max(3, div(total_members, 6))
        :stable -> max(2, div(total_members, 8))
        :increasing -> max(1, div(total_members, 10))
      end

    # Adjust based on activity ratio
    activity_ratio = if total_members > 0, do: active_members / total_members, else: 0

    if activity_ratio < 0.5 do
      round(base_target * 1.5)
    else
      base_target
    end
  end

  defp determine_recruitment_focus_areas(_corporation_data) do
    ["PvP experience", "Fleet discipline", "Communication skills", "Time zone coverage"]
  end

  defp determine_target_profiles(_corporation_data) do
    [
      %{role: "DPS Pilot", experience: "Intermediate", priority: :high},
      %{role: "Logistics Pilot", experience: "Advanced", priority: :medium},
      %{role: "Fleet Commander", experience: "Expert", priority: :low}
    ]
  end

  defp get_recruitment_timeline(priority) do
    case priority do
      :urgent -> "Within 2 weeks"
      :high -> "Within 1 month"
      :medium -> "Within 2 months"
      :low -> "Ongoing, as opportunities arise"
    end
  end

  defp calculate_overall_health(analysis_data) do
    activity_trends = Map.get(analysis_data, :activity_trends, %{})
    engagement_metrics = Map.get(analysis_data, :engagement_metrics, %{})
    retention_risks = Map.get(analysis_data, :retention_risks, %{})

    trend_score =
      case Map.get(activity_trends, :trend_direction, :stable) do
        :increasing -> 100
        :stable -> 75
        :volatile -> 50
        :decreasing -> 25
      end

    engagement_score = Map.get(engagement_metrics, :overall_engagement_score, 50)

    high_risk_count = length(Map.get(retention_risks, :high_risk_members, []))
    retention_score = max(0, 100 - high_risk_count * 10)

    overall_score = (trend_score + engagement_score + retention_score) / 3

    case overall_score do
      score when score >= 80 -> :excellent
      score when score >= 60 -> :good
      score when score >= 40 -> :moderate
      _ -> :poor
    end
  end

  defp generate_action_items(recommendations) do
    recommendations
    |> Enum.with_index(1)
    |> Enum.map(fn {rec, index} ->
      %{
        id: index,
        priority: rec.priority,
        description: rec.action,
        category: rec.category,
        estimated_effort: estimate_effort(rec.category),
        timeline: estimate_timeline(rec.priority)
      }
    end)
  end

  defp generate_monitoring_suggestions(analysis_data) do
    base_suggestions = [
      "Monitor weekly activity trends",
      "Track member engagement scores",
      "Review retention risk factors monthly"
    ]

    activity_trends = Map.get(analysis_data, :activity_trends, %{})

    case Map.get(activity_trends, :trend_direction, :stable) do
      :decreasing ->
        [
          "Increase monitoring frequency to daily",
          "Focus on early warning indicators" | base_suggestions
        ]

      :volatile ->
        ["Analyze volatility patterns", "Identify stabilization opportunities" | base_suggestions]

      _ ->
        base_suggestions
    end
  end

  defp estimate_effort(category) do
    case category do
      :retention -> "High - requires one-on-one attention"
      :engagement -> "Medium - requires event planning"
      :stability -> "Medium - requires process changes"
      _ -> "Low - routine activities"
    end
  end

  defp estimate_timeline(priority) do
    case priority do
      :urgent -> "Immediate (within 24 hours)"
      :high -> "Short-term (within 1 week)"
      :medium -> "Medium-term (within 1 month)"
      :low -> "Long-term (within 3 months)"
    end
  end

  defp calculate_tenure_category(days_since_join) do
    case days_since_join do
      days when days < 30 -> :new_member
      days when days < 90 -> :recent_member
      days when days < 365 -> :established_member
      _ -> :veteran_member
    end
  end

  defp calculate_simple_risk(days_since_last, days_since_join) do
    case {days_since_last, days_since_join} do
      {last, _} when last > 90 -> :high_risk
      {last, join} when last > 30 and join < 90 -> :medium_risk
      {last, _} when last > 14 -> :medium_risk
      _ -> :low_risk
    end
  end

  # Helper functions for ESI integration

  defp get_corporation_auth_token(corporation_id) do
    # In a real implementation, this would check for valid auth tokens
    # For now, return an error to fallback to database lookup
    _ = corporation_id
    {:error, :no_auth_token}
  end

  defp enrich_member_data(member_ids) when is_list(member_ids) do
    # Enrich member IDs with character names and basic info
    member_ids
    |> Enum.map(fn character_id ->
      %{
        character_id: character_id,
        character_name: EveDmv.Eve.NameResolver.character_name(character_id),
        # Add basic member info - would be enhanced with more ESI calls
        join_date: nil,
        last_login: nil,
        roles: []
      }
    end)
  end

  defp fetch_members_from_database(corporation_id) do
    # Fallback: get members from participant/killmail data
    try do
      query = """
      SELECT DISTINCT p.character_id, p.character_name
      FROM participants p
      WHERE p.corporation_id = $1
        AND p.character_id IS NOT NULL
        AND p.killmail_time >= NOW() - INTERVAL '90 days'
      ORDER BY p.character_name
      LIMIT 1000
      """

      case Ecto.Adapters.SQL.query(EveDmv.Repo, query, [corporation_id]) do
        {:ok, %{rows: rows}} ->
          members =
            Enum.map(rows, fn [char_id, char_name] ->
              %{
                character_id: char_id,
                character_name: char_name,
                source: :database_fallback
              }
            end)

          {:ok, members}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("Database fallback failed: #{inspect(error)}")
        {:error, :database_fallback_failed}
    end
  end
end
