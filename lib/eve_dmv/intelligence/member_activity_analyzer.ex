defmodule EveDmv.Intelligence.MemberActivityAnalyzer do
  @moduledoc """
  Member activity intelligence analyzer and early warning system.

  Analyzes member participation patterns, identifies engagement trends,
  and provides early warning for burnout or disengagement risks.

  This module serves as the main orchestrator, delegating calculations
  to MemberActivityMetrics and formatting to MemberActivityFormatter.
  """

  require Logger
  alias EveDmv.Eve.EsiClient

  alias EveDmv.Intelligence.{
    CharacterStats,
    MemberActivityFormatter,
    MemberActivityIntelligence,
    MemberActivityMetrics
  }

  @doc """
  Generate comprehensive member activity analysis for a character.

  Returns {:ok, analysis_record} or {:error, reason}
  """
  def analyze_member_activity(character_id, period_start, period_end, _options \\ []) do
    Logger.info("Starting member activity analysis for character #{character_id}")

    with {:ok, character_info} <- get_character_info(character_id),
         {:ok, activity_data} <- collect_activity_data(character_id, period_start, period_end),
         {:ok, participation_data} <-
           analyze_participation_patterns(character_id, period_start, period_end),
         {:ok, risk_assessment} <-
           assess_member_risks(character_id, activity_data, participation_data),
         {:ok, timezone_analysis} <- analyze_timezone_patterns(character_id, activity_data),
         {:ok, peer_comparison} <-
           calculate_peer_comparison(character_id, character_info.corporation_id, activity_data) do
      analysis_data = %{
        character_id: character_id,
        character_name: character_info.character_name,
        corporation_id: character_info.corporation_id,
        corporation_name: character_info.corporation_name,
        alliance_id: character_info.alliance_id,
        alliance_name: character_info.alliance_name,
        activity_period_start: period_start,
        activity_period_end: period_end,
        total_pvp_kills: activity_data.total_kills,
        total_pvp_losses: activity_data.total_losses,
        home_defense_participations: participation_data.home_defense_count,
        chain_operations_participations: participation_data.chain_operations_count,
        fleet_participations: participation_data.fleet_count,
        solo_activities: participation_data.solo_count,
        engagement_score:
          MemberActivityMetrics.calculate_engagement_score(activity_data, participation_data),
        activity_trend:
          MemberActivityMetrics.determine_activity_trend(character_id, activity_data),
        burnout_risk_score: risk_assessment.burnout_risk,
        disengagement_risk_score: risk_assessment.disengagement_risk,
        activity_patterns: MemberActivityMetrics.build_activity_patterns(activity_data),
        participation_metrics:
          MemberActivityMetrics.build_participation_metrics(participation_data),
        warning_indicators: risk_assessment.warning_indicators,
        timezone_analysis: timezone_analysis,
        corp_percentile_ranking: peer_comparison.percentile_ranking,
        peer_comparison_score: peer_comparison.std_deviation_score
      }

      case MemberActivityIntelligence.create(analysis_data) do
        {:ok, analysis} ->
          Logger.info("Member activity analysis completed for character #{character_id}")
          {:ok, analysis}

        {:error, reason} ->
          Logger.error("Failed to create member activity analysis: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, reason} ->
        Logger.error(
          "Member activity analysis failed for character #{character_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Update member activity intelligence with new activity data.
  """
  def record_member_activity(character_id, activity_type, activity_data \\ %{}) do
    case get_latest_analysis(character_id) do
      {:ok, analysis} ->
        MemberActivityIntelligence.record_activity(analysis, activity_type, activity_data)

      {:error, reason} ->
        Logger.info(
          "No existing analysis found for character #{character_id}, creating new analysis: #{inspect(reason)}"
        )

        # Create analysis for the last 30 days
        end_date = DateTime.utc_now()
        start_date = DateTime.add(end_date, -30, :day)
        analyze_member_activity(character_id, start_date, end_date)
    end
  end

  @doc """
  Generate member activity report for corporation leadership.
  """
  def generate_corporation_activity_report(corporation_id, _options \\ []) do
    Logger.info("Generating corporation activity report for corp #{corporation_id}")

    case get_corporation_member_analyses(corporation_id) do
      {:ok, member_analyses} ->
        risk_summary = MemberActivityFormatter.generate_risk_summary(member_analyses)
        engagement_metrics = MemberActivityFormatter.calculate_engagement_metrics(member_analyses)

        recommendations =
          MemberActivityFormatter.generate_leadership_recommendations(member_analyses)

        report = %{
          corporation_id: corporation_id,
          generated_at: DateTime.utc_now(),
          member_count: length(member_analyses),
          risk_summary: risk_summary,
          engagement_metrics: engagement_metrics,
          recommendations: recommendations,
          member_details: MemberActivityFormatter.format_member_summaries(member_analyses)
        }

        {:ok, report}

      error ->
        Logger.error("Failed to generate corporation activity report: #{inspect(error)}")
        error
    end
  end

  @doc """
  Identify members requiring leadership attention.
  """
  def identify_members_needing_attention(corporation_id, options \\ []) do
    risk_threshold = Keyword.get(options, :risk_threshold, 60)

    case MemberActivityIntelligence.get_at_risk(corporation_id, risk_threshold) do
      {:ok, at_risk_members} ->
        attention_list =
          at_risk_members
          |> Enum.map(fn member ->
            %{
              character_id: member.character_id,
              character_name: member.character_name,
              primary_concern: MemberActivityFormatter.determine_primary_concern(member),
              urgency: MemberActivityMetrics.calculate_attention_urgency(member),
              recommended_action: MemberActivityFormatter.recommend_leadership_action(member),
              contact_priority: MemberActivityMetrics.calculate_contact_priority(member)
            }
          end)
          |> Enum.sort_by(& &1.contact_priority, :desc)

        {:ok, attention_list}

      error ->
        error
    end
  end

  @doc """
  Analyze corporation-wide activity patterns.
  """
  def analyze_corporation_activity(corporation_id) do
    Logger.info("Analyzing corporation activity patterns for corp #{corporation_id}")

    with {:ok, member_analyses} <- get_corporation_member_analyses(corporation_id),
         {:ok, activity_trends} <- analyze_corporation_trends(member_analyses),
         {:ok, engagement_health} <- assess_corporation_engagement_health(member_analyses) do
      {:ok,
       %{
         corporation_id: corporation_id,
         total_members: length(member_analyses),
         active_members: count_active_members(member_analyses),
         activity_trends: activity_trends,
         engagement_metrics: engagement_health
       }}
    else
      error -> error
    end
  end

  # Helper functions for core analysis logic

  defp get_character_info(character_id) do
    # First try ESI for the most up-to-date information
    with {:ok, char_data} <- EsiClient.get_character(character_id),
         {:ok, corp_data} <- EsiClient.get_corporation(char_data.corporation_id) do
      # Get alliance info if applicable
      alliance_info =
        if char_data.alliance_id do
          case EsiClient.get_alliance(char_data.alliance_id) do
            {:ok, alliance} -> %{alliance_id: alliance.alliance_id, alliance_name: alliance.name}
            _ -> %{alliance_id: nil, alliance_name: nil}
          end
        else
          %{alliance_id: nil, alliance_name: nil}
        end

      {:ok,
       %{
         character_name: char_data.name,
         corporation_id: char_data.corporation_id,
         corporation_name: corp_data.name,
         alliance_id: alliance_info.alliance_id,
         alliance_name: alliance_info.alliance_name
       }}
    else
      {:error, reason} ->
        Logger.warning(
          "Could not fetch character info from ESI for #{character_id}: #{inspect(reason)}"
        )

        # Fallback to placeholder data
        {:ok,
         %{
           character_name: "Character #{character_id}",
           corporation_id: 98_000_001,
           corporation_name: "Unknown Corporation",
           alliance_id: nil,
           alliance_name: nil
         }}
    end
  end

  defp collect_activity_data(character_id, period_start, period_end) do
    # Collect killmail data for the period
    case get_character_killmails(character_id, period_start, period_end) do
      {:ok, killmails} ->
        activity_data = %{
          total_kills: count_kills(killmails),
          total_losses: count_losses(killmails),
          total_activities: length(killmails),
          daily_activity: group_by_day(killmails),
          hourly_activity: group_by_hour(killmails),
          monthly_activity: group_by_month(killmails)
        }

        {:ok, activity_data}
    end
  end

  defp analyze_participation_patterns(character_id, period_start, period_end) do
    # Analyze fleet participation, home defense, chain ops
    participation_data = %{
      home_defense_count:
        count_home_defense_participation(character_id, period_start, period_end),
      chain_operations_count: count_chain_operations(character_id, period_start, period_end),
      fleet_count: count_fleet_operations(character_id, period_start, period_end),
      solo_count: count_solo_activities(character_id, period_start, period_end),
      participation_rate: calculate_participation_rate(character_id, period_start, period_end)
    }

    {:ok, participation_data}
  end

  defp assess_member_risks(character_id, activity_data, participation_data) do
    # Get trend data for risk assessment
    trend_data = MemberActivityMetrics.determine_activity_trend(character_id, activity_data)
    timezone_data = %{primary_timezone: "UTC", corp_distribution: %{"UTC" => 0.5}}

    risk_assessment = %{
      burnout_risk:
        MemberActivityMetrics.calculate_burnout_risk(
          activity_data,
          participation_data,
          trend_data
        ),
      disengagement_risk:
        MemberActivityMetrics.calculate_disengagement_risk(
          activity_data,
          participation_data,
          timezone_data
        ),
      warning_indicators: identify_warning_indicators(activity_data, participation_data)
    }

    {:ok, risk_assessment}
  end

  defp analyze_timezone_patterns(_character_id, _activity_data) do
    # Analyze when the member is most active
    timezone_analysis = %{
      primary_timezone: "UTC",
      active_hours: [18, 19, 20, 21, 22, 23],
      timezone_consistency: 0.8
    }

    {:ok, timezone_analysis}
  end

  defp calculate_peer_comparison(_character_id, corporation_id, activity_data) do
    # Compare member's activity to corporation peers
    case get_corporation_activity_scores(corporation_id) do
      {:ok, corp_scores} ->
        member_score = MemberActivityMetrics.calculate_activity_score(activity_data)

        comparison = %{
          percentile_ranking:
            MemberActivityMetrics.calculate_percentile_ranking(member_score, corp_scores),
          std_deviation_score:
            MemberActivityMetrics.calculate_standard_deviation_score(member_score, corp_scores)
        }

        {:ok, comparison}
    end
  end

  defp get_latest_analysis(character_id) do
    case MemberActivityIntelligence.get_by_character(character_id) do
      {:ok, analysis} -> {:ok, analysis}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_corporation_member_analyses(corporation_id) do
    case MemberActivityIntelligence.get_by_corporation(corporation_id) do
      {:ok, analyses} -> {:ok, analyses}
      {:error, reason} -> {:error, reason}
    end
  end

  defp analyze_corporation_trends(member_analyses) do
    trends = %{
      overall_direction: determine_overall_trend_direction(member_analyses),
      member_count_trend: calculate_member_count_trend(member_analyses),
      engagement_trend: calculate_engagement_trend(member_analyses)
    }

    {:ok, trends}
  end

  defp assess_corporation_engagement_health(member_analyses) do
    health_metrics = %{
      average_engagement: calculate_average_engagement(member_analyses),
      at_risk_percentage: calculate_at_risk_percentage(member_analyses),
      high_performers_percentage: calculate_high_performers_percentage(member_analyses)
    }

    {:ok, health_metrics}
  end

  # Simplified data collection helpers (would integrate with real data sources)

  defp get_character_killmails(_character_id, _period_start, _period_end) do
    # This would query the actual killmail database
    {:ok, []}
  end

  defp count_kills(killmails), do: Enum.count(killmails, &(&1.is_victim == false))
  defp count_losses(killmails), do: Enum.count(killmails, &(&1.is_victim == true))

  defp group_by_day(killmails) do
    killmails
    |> Enum.group_by(fn km -> Date.to_string(DateTime.to_date(km.killmail_time)) end)
    |> Enum.map(fn {date, kms} -> {date, length(kms)} end)
    |> Map.new()
  end

  defp group_by_hour(killmails) do
    killmails
    |> Enum.group_by(fn km -> km.killmail_time.hour end)
    |> Enum.map(fn {hour, kms} -> {hour, length(kms)} end)
    |> Map.new()
  end

  defp group_by_month(killmails) do
    killmails
    |> Enum.group_by(fn km -> "#{km.killmail_time.year}-#{km.killmail_time.month}" end)
    |> Enum.map(fn {month, kms} -> {month, length(kms)} end)
    |> Map.new()
  end

  defp count_home_defense_participation(_character_id, _period_start, _period_end), do: 0
  defp count_chain_operations(_character_id, _period_start, _period_end), do: 0
  defp count_fleet_operations(_character_id, _period_start, _period_end), do: 0
  defp count_solo_activities(_character_id, _period_start, _period_end), do: 0
  defp calculate_participation_rate(_character_id, _period_start, _period_end), do: 0.5

  defp identify_warning_indicators(_activity_data, _participation_data), do: []
  defp get_corporation_activity_scores(_corporation_id), do: {:ok, [50, 60, 70, 80]}

  defp count_active_members(member_analyses) do
    Enum.count(member_analyses, fn analysis ->
      (analysis.engagement_score || 0) > 30
    end)
  end

  defp determine_overall_trend_direction(_member_analyses), do: :stable
  defp calculate_member_count_trend(_member_analyses), do: :stable
  defp calculate_engagement_trend(_member_analyses), do: :stable

  defp calculate_average_engagement(member_analyses) do
    if length(member_analyses) > 0 do
      total_engagement = Enum.sum(Enum.map(member_analyses, &(&1.engagement_score || 0)))
      total_engagement / length(member_analyses)
    else
      0
    end
  end

  defp calculate_at_risk_percentage(member_analyses) do
    if length(member_analyses) > 0 do
      at_risk_count =
        Enum.count(member_analyses, fn analysis ->
          max(analysis.burnout_risk_score || 0, analysis.disengagement_risk_score || 0) > 50
        end)

      at_risk_count / length(member_analyses) * 100
    else
      0
    end
  end

  defp calculate_high_performers_percentage(member_analyses) do
    if length(member_analyses) > 0 do
      high_performer_count =
        Enum.count(member_analyses, fn analysis ->
          (analysis.engagement_score || 0) > 80
        end)

      high_performer_count / length(member_analyses) * 100
    else
      0
    end
  end

  # Public API functions expected by tests

  @doc """
  Calculate member engagement from activity data.
  """
  def calculate_member_engagement(member_activities) when is_list(member_activities) do
    if Enum.empty?(member_activities) do
      %{
        avg_engagement_score: 0,
        high_engagement_count: 0,
        low_engagement_count: 0,
        engagement_distribution: %{}
      }
    else
      # Calculate engagement scores for each member
      engagement_scores =
        Enum.map(member_activities, fn member ->
          killmail_score = min(50, (member.killmail_count || 0) * 2)
          participation_score = (member.fleet_participation || 0) * 30
          communication_score = min(20, member.communication_activity || 0)

          total_score = killmail_score + participation_score + communication_score
          min(100, total_score)
        end)

      avg_engagement =
        if length(engagement_scores) > 0,
          do: Enum.sum(engagement_scores) / length(engagement_scores),
          else: 0

      high_engagement = Enum.count(engagement_scores, &(&1 >= 70))
      low_engagement = Enum.count(engagement_scores, &(&1 < 30))

      # Create distribution buckets
      distribution = %{
        "high" => high_engagement,
        "medium" => length(engagement_scores) - high_engagement - low_engagement,
        "low" => low_engagement
      }

      %{
        avg_engagement_score: Float.round(avg_engagement, 1),
        high_engagement_count: high_engagement,
        low_engagement_count: low_engagement,
        engagement_distribution: distribution
      }
    end
  end

  @doc """
  Analyze activity trends over time.
  """
  def analyze_activity_trends(member_activities, days) when is_list(member_activities) do
    if Enum.empty?(member_activities) or days <= 0 do
      %{
        trend_direction: :stable,
        trend_strength: 0.0,
        activity_change_percent: 0.0,
        member_count: 0
      }
    else
      # Calculate trend based on activity changes
      cutoff_date = DateTime.add(DateTime.utc_now(), -days, :day)

      recent_activities =
        Enum.filter(member_activities, fn member ->
          case Map.get(member, :last_seen) do
            nil -> false
            last_seen -> DateTime.compare(last_seen, cutoff_date) != :lt
          end
        end)

      total_recent_activity =
        Enum.sum(Enum.map(recent_activities, &Map.get(&1, :killmail_count, 0)))

      total_historical_activity =
        Enum.sum(Enum.map(member_activities, &Map.get(&1, :killmail_count, 0)))

      activity_change_percent =
        if total_historical_activity > 0 do
          (total_recent_activity / length(recent_activities) -
             total_historical_activity / length(member_activities)) /
            (total_historical_activity / length(member_activities)) * 100
        else
          0.0
        end

      {trend_direction, trend_strength} = determine_trend_direction(activity_change_percent)

      %{
        trend_direction: trend_direction,
        trend_strength: Float.round(abs(trend_strength), 2),
        activity_change_percent: Float.round(activity_change_percent, 1),
        member_count: length(member_activities)
      }
    end
  end

  @doc """
  Identify members at risk of leaving or becoming inactive.
  """
  def identify_retention_risks(member_data) when is_list(member_data) do
    if Enum.empty?(member_data) do
      %{
        high_risk_members: [],
        medium_risk_members: [],
        risk_factors: %{},
        total_members_analyzed: 0
      }
    else
      {high_risk, medium_risk, risk_factors} = assess_retention_risks(member_data)

      %{
        high_risk_members: high_risk,
        medium_risk_members: medium_risk,
        risk_factors: risk_factors,
        total_members_analyzed: length(member_data)
      }
    end
  end

  @doc """
  Generate recruitment insights from activity data.
  """
  def generate_recruitment_insights(activity_data) do
    member_count = Map.get(activity_data, :total_members, 0)
    avg_engagement = Map.get(activity_data, :avg_engagement_score, 0)
    retention_risk_count = Map.get(activity_data, :high_risk_count, 0)

    # Generate insights based on the data
    insights = []

    insights =
      if member_count < 20 do
        ["Corporation needs more active members" | insights]
      else
        insights
      end

    insights =
      if avg_engagement < 50 do
        ["Member engagement is below healthy levels" | insights]
      else
        insights
      end

    insights =
      if retention_risk_count > member_count * 0.2 do
        ["High number of members at retention risk" | insights]
      else
        insights
      end

    recruitment_priority =
      cond do
        member_count < 10 -> "critical"
        member_count < 20 -> "high"
        avg_engagement < 40 -> "medium"
        true -> "low"
      end

    %{
      recruitment_priority: recruitment_priority,
      insights: insights,
      recommended_recruit_count: max(0, 25 - member_count),
      focus_areas: determine_recruitment_focus_areas(activity_data)
    }
  end

  @doc """
  Calculate fleet participation metrics.
  """
  def calculate_fleet_participation_metrics(fleet_data) when is_list(fleet_data) do
    if Enum.empty?(fleet_data) do
      %{
        avg_participation_rate: 0.0,
        avg_fleet_duration: 0.0,
        leadership_participation: 0.0,
        total_members: 0
      }
    else
      participation_rates =
        Enum.map(fleet_data, fn member ->
          attended = Map.get(member, :fleet_ops_attended, 0)
          available = Map.get(member, :fleet_ops_available, 1)
          attended / max(1, available)
        end)

      durations = Enum.map(fleet_data, &Map.get(&1, :avg_fleet_duration, 0))
      leadership_roles = Enum.sum(Enum.map(fleet_data, &Map.get(&1, :leadership_roles, 0)))

      avg_participation =
        if length(participation_rates) > 0,
          do: Enum.sum(participation_rates) / length(participation_rates),
          else: 0.0

      avg_duration =
        if length(durations) > 0, do: Enum.sum(durations) / length(durations), else: 0.0

      leadership_participation = leadership_roles / max(1, length(fleet_data))

      %{
        avg_participation_rate: Float.round(avg_participation * 100, 1),
        avg_fleet_duration: Float.round(avg_duration, 1),
        leadership_participation: Float.round(leadership_participation, 2),
        total_members: length(fleet_data)
      }
    end
  end

  @doc """
  Classify activity level based on score.
  """
  def classify_activity_level(activity_score) when is_number(activity_score) do
    cond do
      activity_score >= 80 -> :highly_active
      activity_score >= 60 -> :moderately_active
      activity_score >= 30 -> :low_activity
      true -> :inactive
    end
  end

  @doc """
  Calculate trend direction from activity data.
  """
  def calculate_trend_direction(activity_data) when is_list(activity_data) do
    if length(activity_data) < 2 do
      :stable
    else
      # Calculate variance to determine trend
      mean = Enum.sum(activity_data) / length(activity_data)

      variance =
        Enum.sum(Enum.map(activity_data, fn x -> :math.pow(x - mean, 2) end)) /
          length(activity_data)

      # Calculate overall trend (first vs last half)
      mid_point = div(length(activity_data), 2)
      first_half = Enum.take(activity_data, mid_point)
      second_half = Enum.drop(activity_data, mid_point)

      first_avg =
        if length(first_half) > 0, do: Enum.sum(first_half) / length(first_half), else: 0

      second_avg =
        if length(second_half) > 0, do: Enum.sum(second_half) / length(second_half), else: 0

      change_percent = if first_avg > 0, do: (second_avg - first_avg) / first_avg * 100, else: 0

      cond do
        variance > mean * 0.5 -> :volatile
        change_percent > 10 -> :increasing
        change_percent < -10 -> :decreasing
        true -> :stable
      end
    end
  end

  @doc """
  Calculate days since last activity.
  """
  def days_since_last_activity(last_activity, current_time) do
    if last_activity do
      DateTime.diff(current_time, last_activity, :day)
    else
      # Very old if no activity recorded
      999
    end
  end

  @doc """
  Fetch corporation members.
  """
  def fetch_corporation_members(corporation_id) do
    case Ash.read(CharacterStats, domain: EveDmv.Api, filter: [corporation_id: corporation_id]) do
      {:ok, [_ | _] = members} ->
        processed_members =
          Enum.map(members, fn member ->
            %{
              character_id: member.character_id,
              character_name: member.character_name || "Unknown",
              last_activity: member.last_killmail_date,
              activity_score: calculate_member_activity_score(member)
            }
          end)

        {:ok, processed_members}

      {:ok, []} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Process member activity data.
  """
  def process_member_activity(member_data, current_time) do
    character_id = Map.get(member_data, :character_id, 0)
    last_activity = Map.get(member_data, :last_activity)
    activity_score = Map.get(member_data, :activity_score, 0)

    days_since_activity =
      if last_activity do
        DateTime.diff(current_time, last_activity, :day)
      else
        999
      end

    activity_level = classify_activity_level(activity_score)
    risk_level = assess_individual_retention_risk(days_since_activity, activity_score)

    %{
      character_id: character_id,
      days_since_last_activity: days_since_activity,
      activity_level: activity_level,
      activity_score: activity_score,
      retention_risk: risk_level,
      processed_at: current_time
    }
  end

  # Helper functions for the new API functions

  defp determine_trend_direction(activity_change_percent) do
    cond do
      activity_change_percent > 20 -> {:increasing, activity_change_percent}
      activity_change_percent < -20 -> {:decreasing, activity_change_percent}
      abs(activity_change_percent) > 10 -> {:volatile, activity_change_percent}
      true -> {:stable, activity_change_percent}
    end
  end

  defp assess_retention_risks(member_data) do
    current_time = DateTime.utc_now()

    {high_risk, medium_risk, risk_factors} =
      Enum.reduce(member_data, {[], [], %{}}, fn member, {high, medium, factors} ->
        days_inactive =
          case Map.get(member, :last_seen) do
            nil -> 999
            last_seen -> DateTime.diff(current_time, last_seen, :day)
          end

        killmail_count = Map.get(member, :killmail_count, 0)
        fleet_participation = Map.get(member, :fleet_participation, 0.0)

        risk_score =
          calculate_retention_risk_score(days_inactive, killmail_count, fleet_participation)

        member_summary = %{
          character_id: Map.get(member, :character_id, 0),
          character_name: Map.get(member, :character_name, "Unknown"),
          risk_score: risk_score,
          days_inactive: days_inactive
        }

        cond do
          risk_score >= 70 ->
            {[member_summary | high], medium, Map.update(factors, "high_risk", 1, &(&1 + 1))}

          risk_score >= 40 ->
            {high, [member_summary | medium], Map.update(factors, "medium_risk", 1, &(&1 + 1))}

          true ->
            {high, medium, factors}
        end
      end)

    {high_risk, medium_risk, risk_factors}
  end

  defp calculate_retention_risk_score(days_inactive, killmail_count, fleet_participation) do
    # Base risk from inactivity
    inactivity_risk = min(50, days_inactive * 2)

    # Risk from low activity
    activity_risk = if killmail_count < 5, do: 20, else: 0

    # Risk from low participation
    participation_risk = if fleet_participation < 0.3, do: 20, else: 0

    min(100, inactivity_risk + activity_risk + participation_risk)
  end

  defp determine_recruitment_focus_areas(activity_data) do
    areas = []

    avg_engagement = Map.get(activity_data, :avg_engagement_score, 0)
    member_count = Map.get(activity_data, :total_members, 0)

    areas = if avg_engagement < 50, do: ["engagement_improvement" | areas], else: areas
    areas = if member_count < 15, do: ["active_recruitment" | areas], else: areas

    if Enum.empty?(areas), do: ["maintain_current"], else: areas
  end

  defp calculate_member_activity_score(member) do
    # Calculate activity score based on kills, losses, and recent activity
    total_activity = (member.total_kills || 0) + (member.total_losses || 0)
    base_score = min(80, total_activity * 2)

    # Recent activity bonus
    recent_bonus =
      case member.last_killmail_date do
        nil ->
          0

        last_date ->
          days_ago = DateTime.diff(DateTime.utc_now(), last_date, :day)
          max(0, 20 - days_ago)
      end

    min(100, base_score + recent_bonus)
  end

  defp assess_individual_retention_risk(days_since_activity, activity_score) do
    cond do
      days_since_activity > 30 and activity_score < 20 -> :high
      days_since_activity > 14 or activity_score < 40 -> :medium
      true -> :low
    end
  end
end
