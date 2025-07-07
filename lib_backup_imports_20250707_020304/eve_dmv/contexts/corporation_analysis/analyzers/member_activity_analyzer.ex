defmodule EveDmv.Contexts.CorporationAnalysis.Analyzers.MemberActivityAnalyzer do
  use EveDmv.ErrorHandler

  alias EveDmv.Result

  require Logger
  @moduledoc """
  Member activity analyzer for corporation analysis.

  Analyzes corporation member activity patterns, participation levels,
  and organizational health metrics. Provides insights into member
  engagement, timezone coverage, and activity trends.
  """


  @doc """
  Analyze member activity for a corporation.
  """
  @spec analyze(integer(), map()) :: Result.t(map())
  def analyze(corporation_id, base_data \\ %{}) when is_integer(corporation_id) do
    try do
      corporation_data = get_corporation_data(base_data, corporation_id)
      member_stats = get_member_statistics(base_data, corporation_id)

      activity_analysis = %{
        overall_activity: analyze_overall_activity(corporation_data, member_stats),
        member_engagement: analyze_member_engagement(member_stats),
        activity_distribution: analyze_activity_distribution(member_stats),
        timezone_coverage: analyze_timezone_coverage(member_stats),
        participation_metrics: calculate_participation_metrics(member_stats),
        retention_indicators: analyze_retention_patterns(corporation_data),
        leadership_activity: analyze_leadership_activity(corporation_data, member_stats),
        activity_summary: generate_activity_summary(corporation_data, member_stats)
      }

      Result.ok(activity_analysis)
    rescue
      exception ->
        Logger.error("Member activity analysis failed",
          corporation_id: corporation_id,
          error: Exception.format(:error, exception)
        )

        Result.error(:analysis_failed, "Member activity analysis error: #{inspect(exception)}")
    end
  end

  # Core analysis functions

  defp analyze_overall_activity(corporation_data, member_stats) do
    total_members = Map.get(corporation_data, :member_count, 0)
    active_members = count_active_members(member_stats)

    # Calculate activity metrics
    activity_rate = safe_divide(active_members, total_members)
    recent_activity = calculate_recent_activity(member_stats)

    # Analyze activity trends
    activity_trend = determine_activity_trend(member_stats)

    %{
      total_members: total_members,
      active_members: active_members,
      inactive_members: total_members - active_members,
      activity_rate: activity_rate,
      recent_activity_score: recent_activity,
      activity_trend: activity_trend,
      last_updated: DateTime.utc_now()
    }
  end

  defp analyze_member_engagement(member_stats) do
    # Categorize members by engagement level
    engagement_categories =
      Enum.reduce(member_stats, %{very_high: 0, high: 0, medium: 0, low: 0, inactive: 0}, fn member, acc ->
        engagement_level = categorize_engagement_level(member)
        Map.update!(acc, engagement_level, &(&1 + 1))
      end)

    # Calculate engagement metrics
    total_members = length(member_stats)
    engagement_score = calculate_overall_engagement_score(member_stats)

    # Identify highly engaged members
    top_performers =
      member_stats
      |> Enum.sort_by(fn member -> calculate_member_activity_score(member) end, :desc)
      |> Enum.take(10)
      |> Enum.map(fn member ->
        %{
          character_id: Map.get(member, :character_id),
          character_name: Map.get(member, :character_name),
          activity_score: calculate_member_activity_score(member),
          last_active: Map.get(member, :last_active),
          role: Map.get(member, :corp_role, "Member")
        }
      end)

    %{
      engagement_distribution: engagement_categories,
      total_members_analyzed: total_members,
      overall_engagement_score: engagement_score,
      top_performers: top_performers,
      engagement_trends: analyze_engagement_trends(member_stats)
    }
  end

  defp analyze_activity_distribution(member_stats) do
    # Analyze activity by different dimensions

    # By timezone/hour
    activity_by_hour =
      Enum.flat_map(member_stats, fn member ->
        activity_by_hour = Map.get(member, :activity_by_hour, %{})
        Map.to_list(activity_by_hour)
      end)
      |> Enum.reduce(%{}, fn {hour, activity}, acc ->
        Map.update(acc, hour, activity, &(&1 + activity))
      end)

    # By day of week
    activity_by_day =
      Enum.flat_map(member_stats, fn member ->
        activity_by_day = Map.get(member, :activity_by_day, %{})
        Map.to_list(activity_by_day)
      end)
      |> Enum.reduce(%{}, fn {day, activity}, acc ->
        Map.update(acc, day, activity, &(&1 + activity))
      end)

    # By activity type
    activity_by_type = analyze_activity_types(member_stats)

    %{
      hourly_distribution: activity_by_hour,
      daily_distribution: activity_by_day,
      activity_type_breakdown: activity_by_type,
      peak_activity_hours: identify_peak_hours(activity_by_hour),
      activity_patterns: identify_activity_patterns(activity_by_hour, activity_by_day)
    }
  end

  defp analyze_timezone_coverage(member_stats) do
    # Analyze timezone distribution of members
    timezone_data =
      member_stats
      |> Enum.group_by(fn member ->
        determine_member_timezone(member)
      end)
      |> Enum.map(fn {timezone, members} ->
        {timezone,
         %{
           member_count: length(members),
           active_count: Enum.count(members, &member_active?/1),
           coverage_score: calculate_timezone_coverage_score(members)
         }}
      end)
      |> Enum.into(%{})

    # Calculate overall coverage metrics
    coverage_gaps = identify_coverage_gaps(timezone_data)
    coverage_strengths = identify_coverage_strengths(timezone_data)

    %{
      timezone_distribution: timezone_data,
      coverage_gaps: coverage_gaps,
      coverage_strengths: coverage_strengths,
      overall_coverage_score: calculate_overall_coverage(timezone_data),
      recommended_recruitment_timezones: suggest_recruitment_timezones(timezone_data)
    }
  end

  defp calculate_participation_metrics(member_stats) do
    # Calculate various participation metrics

    # PvP participation
    pvp_participants =
      Enum.count(member_stats, fn member ->
        Map.get(member, :recent_kills, 0) + Map.get(member, :recent_losses, 0) > 0
      end)

    # Fleet participation (estimated from group activity)
    fleet_participants =
      Enum.count(member_stats, fn member ->
        Map.get(member, :group_activity_ratio, 0.0) > 0.3
      end)

    # Corporate activity participation
    corp_activity_participants =
      Enum.count(member_stats, fn member ->
        corp_score = Map.get(member, :corp_activity_score)
        corp_score && corp_score > 50
      end)

    total_members = length(member_stats)

    %{
      pvp_participation: %{
        participants: pvp_participants,
        rate: safe_divide(pvp_participants, total_members)
      },
      fleet_participation: %{
        participants: fleet_participants,
        rate: safe_divide(fleet_participants, total_members)
      },
      corporate_activity: %{
        participants: corp_activity_participants,
        rate: safe_divide(corp_activity_participants, total_members)
      },
      overall_participation_score: calculate_overall_participation(member_stats)
    }
  end

  defp analyze_retention_patterns(corporation_data) do
    member_history = Map.get(corporation_data, :member_history, [])
    recent_joins = Map.get(corporation_data, :recent_joins, [])
    recent_departures = Map.get(corporation_data, :recent_departures, [])

    # Calculate retention metrics
    monthly_retention = calculate_monthly_retention(member_history)

    # Analyze departure patterns
    departure_analysis = analyze_departure_patterns(recent_departures)

    # Recruitment effectiveness
    recruitment_metrics = analyze_recruitment_effectiveness(recent_joins, recent_departures)

    %{
      monthly_retention_rate: monthly_retention,
      recent_joins: length(recent_joins),
      recent_departures: length(recent_departures),
      net_member_change: length(recent_joins) - length(recent_departures),
      departure_analysis: departure_analysis,
      recruitment_effectiveness: recruitment_metrics,
      retention_risk_factors: identify_retention_risks(corporation_data)
    }
  end

  defp analyze_leadership_activity(_corporation_data, member_stats) do
    # Identify leadership roles
    leadership_members =
      Enum.filter(member_stats, fn member ->
        corp_role = Map.get(member, :corp_role)
        corp_role && corp_role in ["CEO", "Director", "Personnel Manager"]
      end)

    # Analyze leadership activity levels
    leadership_activity =
      leadership_members
      |> Enum.map(fn leader ->
        %{
          character_id: Map.get(leader, :character_id),
          character_name: Map.get(leader, :character_name),
          role: Map.get(leader, :corp_role),
          activity_score: calculate_member_activity_score(leader),
          last_active: Map.get(leader, :last_active),
          leadership_effectiveness: assess_leadership_effectiveness(leader)
        }
      end)

    # Overall leadership health
    leadership_health = assess_leadership_health(leadership_activity)

    %{
      leadership_count: length(leadership_members),
      leadership_activity: leadership_activity,
      leadership_health_score: leadership_health,
      active_leadership_count: Enum.count(leadership_activity, &(&1.activity_score > 50)),
      leadership_recommendations: generate_leadership_recommendations(leadership_activity)
    }
  end

  defp generate_activity_summary(corporation_data, member_stats) do
    total_members = length(member_stats)
    active_members = count_active_members(member_stats)

    # Generate overall health assessment
    health_score = calculate_corp_health_score(corporation_data, member_stats)
    health_rating = categorize_health_rating(health_score)

    # Identify key strengths and weaknesses
    strengths = identify_corp_strengths(corporation_data, member_stats)
    weaknesses = identify_corp_weaknesses(corporation_data, member_stats)

    %{
      corporation_name: Map.get(corporation_data, :name, "Unknown Corporation"),
      total_members: total_members,
      active_members: active_members,
      activity_rate: safe_divide(active_members, total_members),
      health_score: health_score,
      health_rating: health_rating,
      key_strengths: strengths,
      key_weaknesses: weaknesses,
      recommendations: generate_corp_recommendations(corporation_data, member_stats),
      analysis_timestamp: DateTime.utc_now()
    }
  end

  # Helper functions

  defp get_corporation_data(base_data, corporation_id) do
    case get_in(base_data, [:corporation_data, corporation_id]) do
      nil -> %{}
      corp_data -> corp_data
    end
  end

  defp get_member_statistics(base_data, corporation_id) do
    case get_in(base_data, [:member_statistics, corporation_id]) do
      nil -> []
      member_stats -> member_stats
    end
  end

  defp count_active_members(member_stats) do
    Enum.count(member_stats, &member_active?/1)
  end

  defp member_active?(member) do
    # Consider a member active if they have recent activity
    recent_activity = Map.get(member, :recent_kills, 0) + Map.get(member, :recent_losses, 0)
    last_active_days = days_since_last_active(Map.get(member, :last_active))

    recent_activity > 0 && last_active_days <= 30
  end

  defp days_since_last_active(nil), do: 999

  defp days_since_last_active(last_active) when is_binary(last_active) do
    case DateTime.from_iso8601(last_active) do
      {:ok, datetime, _} ->
        DateTime.diff(DateTime.utc_now(), datetime, :day)

      _ ->
        999
    end
  end

  defp days_since_last_active(_), do: 999

  defp calculate_recent_activity(member_stats) do
    total_recent_activity =
      member_stats
      |> Enum.map(fn member ->
        Map.get(member, :recent_kills, 0) + Map.get(member, :recent_losses, 0)
      end)
      |> Enum.sum()

    # Normalize by member count
    member_count = length(member_stats)
    if member_count > 0, do: total_recent_activity / member_count, else: 0.0
  end

  defp determine_activity_trend(_member_stats) do
    # Placeholder - would analyze activity over time
    :stable
  end

  defp categorize_engagement_level(member) do
    activity_score = calculate_member_activity_score(member)

    cond do
      activity_score >= 90 -> :very_high
      activity_score >= 70 -> :high
      activity_score >= 50 -> :medium
      activity_score >= 25 -> :low
      true -> :inactive
    end
  end

  defp calculate_member_activity_score(member) do
    # Calculate a composite activity score
    recent_kills = Map.get(member, :recent_kills, 0)
    recent_losses = Map.get(member, :recent_losses, 0)
    days_since_active = days_since_last_active(Map.get(member, :last_active))

    # Base score from recent activity
    activity_score = min(100, (recent_kills + recent_losses) * 2)

    # Penalty for inactivity
    inactivity_penalty = min(50, days_since_active)

    max(0, activity_score - inactivity_penalty)
  end

  defp calculate_overall_engagement_score(member_stats) do
    if Enum.empty?(member_stats), do: 0.0

    total_score =
      Enum.sum(Enum.map(member_stats, &calculate_member_activity_score/1))

    total_score / length(member_stats)
  end

  defp analyze_engagement_trends(_member_stats) do
    # Placeholder for engagement trend analysis
    %{trend: :stable, trend_strength: 0.1}
  end

  defp analyze_activity_types(_member_stats) do
    # Placeholder for activity type breakdown
    %{
      pvp: 0.6,
      pve: 0.3,
      industrial: 0.1
    }
  end

  defp identify_peak_hours(activity_by_hour) do
    Enum.sort_by(activity_by_hour, fn {_hour, activity} -> activity end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {hour, activity} -> %{hour: hour, activity: activity} end)
  end

  defp identify_activity_patterns(_activity_by_hour, _activity_by_day) do
    # Placeholder for pattern identification
    [:timezone_concentrated, :weekend_activity]
  end

  defp determine_member_timezone(member) do
    # Simplified timezone determination based on peak activity
    case Map.get(member, :prime_timezone) do
      tz when is_binary(tz) -> tz
      # Default timezone
      _ -> "UTC"
    end
  end

  defp calculate_timezone_coverage_score(members) do
    active_members = Enum.count(members, &member_active?/1)
    total_members = length(members)

    safe_divide(active_members, total_members) * 100
  end

  defp identify_coverage_gaps(_timezone_data) do
    # Placeholder for coverage gap analysis
    ["Late US", "Early EU"]
  end

  defp identify_coverage_strengths(_timezone_data) do
    # Placeholder for coverage strength analysis
    ["Prime EU", "AU TZ"]
  end

  defp calculate_overall_coverage(_timezone_data) do
    # Placeholder for overall coverage calculation
    75.0
  end

  defp suggest_recruitment_timezones(_timezone_data) do
    # Placeholder for recruitment suggestions
    ["US East", "US West"]
  end

  defp calculate_overall_participation(_member_stats) do
    # Placeholder for overall participation calculation
    65.0
  end

  defp safe_divide(numerator, denominator) when denominator > 0, do: numerator / denominator
  defp safe_divide(_, _), do: 0.0

  # Placeholder implementations for remaining helper functions
  defp calculate_monthly_retention(_member_history), do: 0.85
  defp analyze_departure_patterns(_recent_departures), do: %{common_reasons: ["Inactivity"]}

  defp analyze_recruitment_effectiveness(_recent_joins, _recent_departures),
    do: %{effectiveness: 0.7}

  defp identify_retention_risks(_corporation_data), do: ["Low leadership activity"]
  defp assess_leadership_effectiveness(_leader), do: 75
  defp assess_leadership_health(_leadership_activity), do: 80
  defp generate_leadership_recommendations(_leadership_activity), do: ["Recruit more directors"]
  defp calculate_corp_health_score(_corp_data, _member_stats), do: 75.0

  defp categorize_health_rating(score) when score >= 80, do: :excellent
  defp categorize_health_rating(score) when score >= 60, do: :good
  defp categorize_health_rating(score) when score >= 40, do: :fair
  defp categorize_health_rating(_), do: :poor

  defp identify_corp_strengths(_corp_data, _member_stats),
    do: ["Active membership", "Good timezone coverage"]

  defp identify_corp_weaknesses(_corp_data, _member_stats),
    do: ["Leadership gaps", "Low retention"]

  defp generate_corp_recommendations(_corp_data, _member_stats),
    do: ["Focus on member retention", "Recruit active leaders"]
end
