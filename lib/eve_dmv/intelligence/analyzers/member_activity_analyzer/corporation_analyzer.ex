defmodule EveDmv.Intelligence.Analyzers.MemberActivityAnalyzer.CorporationAnalyzer do
  @moduledoc """
  Corporation-wide activity analysis module for member activity analyzer.

  Handles corporation-level analysis including activity reports, member attention lists,
  and overall corporation engagement health assessments.
  """

  alias EveDmv.Api
  alias EveDmv.Intelligence.Analyzers.MemberActivityDataCollector
  alias EveDmv.Intelligence.CharacterStats
  alias EveDmv.Intelligence.Formatters.MemberActivityFormatter
  alias EveDmv.Intelligence.MemberActivityIntelligence
  alias EveDmv.Intelligence.Metrics.MemberActivityMetrics
  alias EveDmv.Utils.TimeUtils

  require Ash.Query
  require Logger

  @doc """
  Generate member activity report for corporation leadership.

  Provides comprehensive activity analysis including risk summary, engagement metrics,
  and leadership recommendations for all corporation members.
  """
  def generate_corporation_activity_report(corporation_id, _options \\ []) do
    Logger.info("Generating corporation activity report for corp #{corporation_id}")

    case MemberActivityDataCollector.get_corporation_member_analyses(corporation_id) do
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

  Filters corporation members based on risk thresholds and provides
  prioritized list with recommended actions.
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

  Provides overall corporation activity analysis including trends,
  engagement health, and member participation metrics.
  """
  def analyze_corporation_activity(corporation_id) do
    Logger.info("Analyzing corporation activity patterns for corp #{corporation_id}")

    # Validate corporation ID
    if corporation_id < 0 do
      {:error, "Invalid corporation ID"}
    else
      with {:ok, member_analyses} <-
             MemberActivityDataCollector.get_corporation_member_analyses(corporation_id),
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
  end

  @doc """
  Fetch corporation members with basic activity data.
  """
  def fetch_corporation_members(corporation_id) do
    members =
      CharacterStats
      |> Ash.Query.filter(corporation_id: corporation_id)
      |> Ash.read!(domain: Api)

    case members do
      [_ | _] = members ->
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

      [] ->
        {:ok, []}
    end
  rescue
    error ->
      {:error, error}
  end

  @doc """
  Calculate peer comparison metrics for a character within their corporation.
  """
  def calculate_peer_comparison(_character_id, corporation_id, activity_data) do
    # Compare member's activity to corporation peers
    case MemberActivityDataCollector.get_corporation_activity_scores(corporation_id) do
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

  # Private helper functions

  defp analyze_corporation_trends(_member_analyses) do
    trends = %{
      overall_direction: :stable,
      member_count_trend: :stable,
      engagement_trend: :stable
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

  defp count_active_members(member_analyses) do
    Enum.count(member_analyses, &(&1.engagement_score > 30))
  end

  defp calculate_average_engagement(member_analyses) do
    if length(member_analyses) > 0 do
      total = Enum.sum(Enum.map(member_analyses, & &1.engagement_score))
      Float.round(total / length(member_analyses), 2)
    else
      0.0
    end
  end

  defp calculate_at_risk_percentage(member_analyses) do
    if length(member_analyses) > 0 do
      at_risk_count = Enum.count(member_analyses, &(&1.burnout_risk_score > 60))
      Float.round(at_risk_count / length(member_analyses) * 100, 2)
    else
      0.0
    end
  end

  defp calculate_high_performers_percentage(member_analyses) do
    if length(member_analyses) > 0 do
      high_performers = Enum.count(member_analyses, &(&1.engagement_score > 80))
      Float.round(high_performers / length(member_analyses) * 100, 2)
    else
      0.0
    end
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
          days_ago = TimeUtils.days_since(last_date)
          max(0, 20 - days_ago)
      end

    min(100, base_score + recent_bonus)
  end
end
