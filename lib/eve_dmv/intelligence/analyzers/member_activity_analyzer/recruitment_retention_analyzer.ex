defmodule EveDmv.Intelligence.Analyzers.MemberActivityAnalyzer.RecruitmentRetentionAnalyzer do
  @moduledoc """
  Recruitment and retention analysis module for member activity analyzer.

  Identifies retention risks, generates recruitment insights, and provides
  recommendations for improving member retention and recruitment strategies.
  """

  alias EveDmv.Intelligence.Analyzers.MemberRiskAssessment
  alias EveDmv.Intelligence.Generators.RecommendationGenerator
  alias EveDmv.Intelligence.Generators.RecruitmentInsightGenerator
  require Logger

  @doc """
  Identify members at risk of leaving the corporation.

  Analyzes activity patterns, engagement levels, and warning signs
  to identify members who may be considering leaving.
  """
  def identify_retention_risks(member_data) when is_list(member_data) do
    at_risk_members =
      Enum.map(member_data, fn member ->
        risk_score = calculate_retention_risk_score(member)
        risk_factors = identify_risk_factors(member)

        %{
          character_id: member.character_id,
          character_name: member.character_name,
          risk_score: risk_score,
          risk_level: classify_risk_level(risk_score),
          risk_factors: risk_factors,
          last_activity: member.last_activity,
          days_inactive: calculate_days_inactive(member),
          recommended_actions: generate_retention_actions(risk_score, risk_factors)
        }
      end)

    _high_risk_members =
      at_risk_members
      |> Enum.filter(&(&1.risk_score > 30))
      |> Enum.sort_by(& &1.risk_score, :desc)

    %{
      at_risk_count: length(at_risk_members),
      total_members: length(member_data),
      risk_percentage: calculate_risk_percentage(length(at_risk_members), length(member_data)),
      at_risk_members: at_risk_members,
      retention_insights: generate_retention_insights(at_risk_members)
    }
  end

  @doc """
  Generate recruitment insights based on current member activity.

  Analyzes successful member patterns to identify ideal recruitment targets
  and provides recommendations for recruitment strategies.
  """
  def generate_recruitment_insights(activity_data) do
    RecruitmentInsightGenerator.generate_recruitment_insights(activity_data)
  end

  @doc """
  Process member activity data for risk assessment.
  """
  def process_member_activity(member_data, current_time) do
    MemberRiskAssessment.process_member_activity(member_data, current_time)
  end

  @doc """
  Generate activity recommendations based on analysis data.
  """
  def generate_activity_recommendations(analysis_data) when is_map(analysis_data) do
    RecommendationGenerator.generate_activity_recommendations(analysis_data)
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

  # Private helper functions

  defp calculate_retention_risk_score(member) do
    # Base risk factors
    days_inactive = calculate_days_inactive(member)
    engagement_score = Map.get(member, :engagement_score, 0)
    activity_trend = Map.get(member, :activity_trend, :stable)

    # Calculate risk components
    inactivity_risk = calculate_inactivity_risk(days_inactive)
    engagement_risk = calculate_engagement_risk(engagement_score)
    trend_risk = calculate_trend_risk(activity_trend)
    communication_risk = calculate_communication_risk(member)

    # Weight the components
    total_risk =
      inactivity_risk * 0.4 +
        engagement_risk * 0.3 +
        trend_risk * 0.2 +
        communication_risk * 0.1

    min(100, max(0, total_risk))
  end

  defp identify_risk_factors(member) do
    days_inactive = calculate_days_inactive(member)
    engagement_score = Map.get(member, :engagement_score, 0)

    base_factors = []

    inactivity_factors =
      if days_inactive > 14, do: [:prolonged_inactivity | base_factors], else: base_factors

    recent_factors =
      if days_inactive > 7,
        do: [:recent_inactivity | inactivity_factors],
        else: inactivity_factors

    engagement_factors =
      if engagement_score < 30, do: [:low_engagement | recent_factors], else: recent_factors

    activity_trend = Map.get(member, :activity_trend, :stable)

    trend_factors =
      if activity_trend == :decreasing,
        do: [:declining_activity | engagement_factors],
        else: engagement_factors

    fleet_participation = Map.get(member, :fleet_participations, 0)

    fleet_factors =
      if fleet_participation == 0,
        do: [:no_fleet_participation | trend_factors],
        else: trend_factors

    communication_score = Map.get(member, :communication_score, 0)

    final_factors =
      if communication_score < 10, do: [:low_communication | fleet_factors], else: fleet_factors

    Enum.reverse(final_factors)
  end

  defp classify_risk_level(risk_score) do
    cond do
      risk_score >= 80 -> :critical
      risk_score >= 60 -> :high
      risk_score >= 40 -> :moderate
      risk_score >= 20 -> :low
      true -> :minimal
    end
  end

  defp calculate_days_inactive(member) do
    case Map.get(member, :last_activity) do
      nil ->
        999

      last_activity ->
        days_since_last_activity(last_activity, DateTime.utc_now())
    end
  end

  defp calculate_inactivity_risk(days_inactive) do
    cond do
      days_inactive > 30 -> 100
      days_inactive > 14 -> 80
      days_inactive > 7 -> 60
      days_inactive > 3 -> 30
      true -> 0
    end
  end

  defp calculate_engagement_risk(engagement_score) do
    # Inverse relationship - lower engagement = higher risk
    100 - engagement_score
  end

  defp calculate_trend_risk(activity_trend) do
    case activity_trend do
      :decreasing -> 80
      :volatile -> 60
      :stable -> 30
      :increasing -> 0
      _ -> 50
    end
  end

  defp calculate_communication_risk(member) do
    comm_score = Map.get(member, :communication_score, 0)

    cond do
      comm_score == 0 -> 100
      comm_score < 10 -> 70
      comm_score < 30 -> 40
      true -> 0
    end
  end

  defp generate_retention_actions(risk_score, risk_factors) do
    base_actions =
      if risk_score >= 80 do
        ["Immediate leadership intervention required"]
      else
        []
      end

    inactivity_actions =
      if :prolonged_inactivity in risk_factors do
        ["Schedule one-on-one check-in" | base_actions]
      else
        base_actions
      end

    engagement_actions =
      if :low_engagement in risk_factors do
        ["Invite to specialized content or roles" | inactivity_actions]
      else
        inactivity_actions
      end

    fleet_actions =
      if :no_fleet_participation in risk_factors do
        ["Personal fleet invitation from FC" | engagement_actions]
      else
        engagement_actions
      end

    communication_actions =
      if :low_communication in risk_factors do
        ["Reach out via preferred communication channel" | fleet_actions]
      else
        fleet_actions
      end

    final_actions =
      if :declining_activity in risk_factors do
        ["Discuss any concerns or burnout" | communication_actions]
      else
        communication_actions
      end

    if final_actions == [] do
      ["Continue monitoring"]
    else
      Enum.reverse(final_actions)
    end
  end

  defp calculate_risk_percentage(at_risk_count, total_count) do
    if total_count > 0 do
      Float.round(at_risk_count / total_count * 100, 1)
    else
      0.0
    end
  end

  defp generate_retention_insights(at_risk_members) do
    if at_risk_members == [] do
      %{
        primary_risk_factors: [],
        recommended_focus: "No immediate retention risks identified",
        success_metrics: %{}
      }
    else
      # Analyze common risk factors
      all_factors =
        at_risk_members
        |> Enum.flat_map(& &1.risk_factors)
        |> Enum.frequencies()
        |> Enum.sort_by(fn {_factor, count} -> count end, :desc)
        |> Enum.take(3)
        |> Enum.map(fn {factor, _count} -> factor end)

      %{
        primary_risk_factors: all_factors,
        recommended_focus: determine_retention_focus(all_factors),
        success_metrics: calculate_retention_metrics(at_risk_members),
        intervention_priority: prioritize_interventions(at_risk_members)
      }
    end
  end

  defp determine_retention_focus(risk_factors) do
    cond do
      :prolonged_inactivity in risk_factors ->
        "Re-engagement campaign for inactive members"

      :low_engagement in risk_factors ->
        "Enhance member engagement through specialized content"

      :no_fleet_participation in risk_factors ->
        "Improve fleet accessibility and scheduling"

      :declining_activity in risk_factors ->
        "Address potential burnout and workload concerns"

      true ->
        "General retention improvement initiatives"
    end
  end

  defp calculate_retention_metrics(at_risk_members) do
    critical_count = Enum.count(at_risk_members, &(&1.risk_level == :critical))
    high_count = Enum.count(at_risk_members, &(&1.risk_level == :high))

    %{
      critical_risks: critical_count,
      high_risks: high_count,
      average_days_inactive: calculate_average_days_inactive(at_risk_members),
      # 70% retention target
      intervention_success_target: 0.7
    }
  end

  defp calculate_average_days_inactive(members) do
    if length(members) > 0 do
      total_days = Enum.sum(Enum.map(members, & &1.days_inactive))
      Float.round(total_days / length(members), 1)
    else
      0.0
    end
  end

  defp prioritize_interventions(at_risk_members) do
    at_risk_members
    |> Enum.filter(&(&1.risk_level in [:critical, :high]))
    |> Enum.sort_by(&{&1.risk_score, &1.days_inactive}, :desc)
    |> Enum.take(10)
    |> Enum.map(fn member ->
      %{
        character_name: member.character_name,
        priority: determine_intervention_priority(member),
        recommended_approach: determine_intervention_approach(member)
      }
    end)
  end

  defp determine_intervention_priority(member) do
    cond do
      member.risk_level == :critical and member.days_inactive > 14 -> :immediate
      member.risk_level == :critical -> :high
      member.risk_level == :high and member.days_inactive > 7 -> :high
      member.risk_level == :high -> :medium
      true -> :low
    end
  end

  defp determine_intervention_approach(member) do
    primary_factor = List.first(member.risk_factors)

    case primary_factor do
      :prolonged_inactivity ->
        "Personal outreach to understand absence and offer support"

      :low_engagement ->
        "Offer specialized roles or content matching their interests"

      :declining_activity ->
        "Check for burnout and discuss workload/expectations"

      :no_fleet_participation ->
        "Personal invitation to upcoming fleets with role guarantee"

      :low_communication ->
        "Reach out through their preferred communication method"

      _ ->
        "General wellness check and feedback session"
    end
  end
end
