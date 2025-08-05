defmodule EveDmv.Contexts.Corporation.Core.OrganizationalHealthAnalyzer do
  @moduledoc """
  Analyzes corporation organizational health including leadership effectiveness,
  member satisfaction, and structural stability.

  Consolidates functionality from:
  - Corporation Analysis organizational metrics
  - Corporation Intelligence health monitoring
  """

  @dialyzer {:nowarn_function, assess_organizational_health: 1}

  alias EveDmv.Contexts.Corporation.Core.MemberActivityAnalyzer
  alias EveDmv.Contexts.Corporation.Core.MemberRiskAssessment
  alias EveDmv.Contexts.Corporation.Core.ParticipationAnalyzer
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Platform.Cache.Corporation.CorporationCache
  alias EveDmv.Platform.Database.CorporationRepository
  alias EveDmv.Utils.DateHelper

  require Logger

  @cache_ttl :timer.hours(4)

  @doc """
  Assess overall organizational health for a corporation.
  """
  def assess_organizational_health(corporation_id) do
    cache_key = {:organizational_health, corporation_id}

    case CorporationCache.get(cache_key) do
      nil ->
        result = perform_organizational_health_assessment(corporation_id)

        if match?({:ok, _}, result) do
          {:ok, assessment} = result
          CorporationCache.put(cache_key, assessment, ttl: @cache_ttl)
        end

        result

      cached_result ->
        {:ok, cached_result}
    end
  end

  @doc """
  Get health metrics for a corporation.
  """
  def get_health_metrics(corporation_id) do
    case assess_organizational_health(corporation_id) do
      {:ok, assessment} -> {:ok, assessment.health_metrics}
      error -> error
    end
  end

  @doc """
  Identify organizational issues.
  """
  def identify_organizational_issues(corporation_id) do
    case assess_organizational_health(corporation_id) do
      {:ok, assessment} -> {:ok, assessment.issues}
      error -> error
    end
  end

  @doc """
  Assess leadership effectiveness.
  """
  def get_leadership_effectiveness(corporation_id) do
    case assess_organizational_health(corporation_id) do
      {:ok, assessment} -> {:ok, assessment.leadership_effectiveness}
      error -> error
    end
  end

  # Private Functions

  defp perform_organizational_health_assessment(corporation_id) do
    Logger.info("Assessing organizational health for corporation #{corporation_id}")

    with {:ok, members} <- CorporationRepository.get_corporation_members(corporation_id),
         {:ok, activity_data} <- MemberActivityAnalyzer.analyze_member_activity(corporation_id),
         {:ok, risk_data} <- MemberRiskAssessment.assess_member_risks(corporation_id),
         {:ok, participation_data} <- ParticipationAnalyzer.analyze_participation(corporation_id),
         {:ok, leadership_data} <- analyze_leadership_structure(members),
         {:ok, stability_data} <-
           assess_organizational_stability(members, activity_data, risk_data) do
      health_metrics =
        calculate_health_metrics(activity_data, risk_data, participation_data, leadership_data)

      assessment = %{
        corporation_id: corporation_id,
        overall_health_score: calculate_overall_health_score(health_metrics),
        health_assessment: categorize_health_level(health_metrics),
        health_metrics: health_metrics,
        leadership_effectiveness: leadership_data,
        organizational_stability: stability_data,
        member_satisfaction: assess_member_satisfaction(activity_data, risk_data),
        communication_health: assess_communication_health(participation_data),
        growth_sustainability: assess_growth_sustainability(members, activity_data),
        issues: identify_health_issues(health_metrics, leadership_data, stability_data),
        recommendations:
          generate_health_recommendations(health_metrics, leadership_data, stability_data),
        assessed_at: DateTime.utc_now()
      }

      {:ok, assessment}
    end
  end

  defp analyze_leadership_structure(members) do
    # Analyze leadership structure and effectiveness
    leadership_analysis = %{
      leadership_depth: assess_leadership_depth(members),
      leadership_activity: assess_leadership_activity(members),
      succession_planning: assess_succession_planning(members),
      decision_making_efficiency: assess_decision_making(),
      leadership_distribution: analyze_leadership_distribution(members),
      mentorship_programs: assess_mentorship_effectiveness(members)
    }

    {:ok, leadership_analysis}
  end

  defp assess_leadership_depth(members) do
    # Identify members in leadership roles
    leaders =
      members
      |> Enum.filter(fn member ->
        # Would check actual roles - simplified here
        has_leadership_role?(member) || has_high_activity_score?(member)
      end)

    total_members = length(members)
    leader_count = length(leaders)

    leadership_ratio =
      if total_members > 0 do
        leader_count / total_members
      else
        0
      end

    # Assess leadership depth quality
    depth_assessment =
      cond do
        # >15% might indicate role inflation
        leadership_ratio > 0.15 -> :too_many_leaders
        # 8-15% is healthy
        leadership_ratio > 0.08 -> :healthy_leadership
        # 3-8% is adequate
        leadership_ratio > 0.03 -> :adequate_leadership
        # <3% indicates shortage
        true -> :leadership_shortage
      end

    %{
      total_leaders: leader_count,
      leadership_ratio: Float.round(leadership_ratio * 100, 1),
      depth_assessment: depth_assessment,
      leader_details: summarize_leaders(leaders),
      leadership_gaps: identify_leadership_gaps(leaders, total_members)
    }
  end

  defp has_high_activity_score?(member) do
    # Consider highly active members as informal leaders
    member.recent_activity_score && member.recent_activity_score > 80
  end

  defp summarize_leaders(leaders) do
    leaders
    |> Enum.map(fn leader ->
      %{
        character_id: leader.character_id,
        character_name: leader.character_name,
        roles: leader.roles || [],
        activity_score: leader.recent_activity_score || 0,
        tenure_days: calculate_tenure_days(leader.join_date),
        leadership_type: determine_leadership_type(leader)
      }
    end)
    |> Enum.sort_by(& &1.activity_score, :desc)
  end

  defp determine_leadership_type(leader) do
    cond do
      leader.roles && "CEO" in leader.roles ->
        :executive

      leader.roles && ("Director" in leader.roles || "Personnel Manager" in leader.roles) ->
        :management

      leader.roles && "Fleet Commander" in leader.roles ->
        :operational

      leader.recent_activity_score && leader.recent_activity_score > 80 ->
        :informal_leader

      true ->
        :other
    end
  end

  defp identify_leadership_gaps(leaders, total_members) do
    has_ceo = Enum.any?(leaders, fn leader -> leader.roles && "CEO" in leader.roles end)

    has_fc =
      Enum.any?(leaders, fn leader -> leader.roles && "Fleet Commander" in leader.roles end)

    []
    |> maybe_add_ceo_gap(has_ceo)
    |> maybe_add_leadership_size_gap(total_members, length(leaders))
    |> maybe_add_fc_gap(has_fc)
    |> Enum.reverse()
  end

  defp maybe_add_ceo_gap(gaps, true), do: gaps
  defp maybe_add_ceo_gap(gaps, false), do: ["No active CEO identified" | gaps]

  defp maybe_add_leadership_size_gap(gaps, total_members, leader_count)
       when total_members > 100 and leader_count < 5 do
    ["Insufficient leadership for corporation size" | gaps]
  end

  defp maybe_add_leadership_size_gap(gaps, _total_members, _leader_count), do: gaps

  defp maybe_add_fc_gap(gaps, true), do: gaps
  defp maybe_add_fc_gap(gaps, false), do: ["No fleet commanders identified" | gaps]

  defp assess_leadership_activity(members) do
    leaders = Enum.filter(members, &has_leadership_role?/1)

    if Enum.empty?(leaders) do
      %{
        activity_score: 0,
        assessment: :no_leadership_data,
        inactive_leaders: 0
      }
    else
      # Calculate average leadership activity
      activity_scores =
        leaders
        |> Enum.map(&(&1.recent_activity_score || 0))

      avg_activity = Enum.sum(activity_scores) / length(activity_scores)

      # Count inactive leaders (no activity in 30 days)
      inactive_leaders =
        Enum.count(leaders, fn leader ->
          is_nil(leader.last_seen) ||
            DateTimeUtils.diff(DateTime.utc_now(), leader.last_seen, :day) > 30
        end)

      assessment =
        cond do
          avg_activity >= 70 -> :highly_active_leadership
          avg_activity >= 50 -> :active_leadership
          avg_activity >= 30 -> :moderately_active
          true -> :inactive_leadership
        end

      %{
        activity_score: Float.round(avg_activity, 1),
        assessment: assessment,
        inactive_leaders: inactive_leaders,
        total_leaders: length(leaders)
      }
    end
  end

  defp assess_succession_planning(members) do
    leaders = Enum.filter(members, &has_leadership_role?/1)
    potential_leaders = identify_potential_leaders(members)

    # Assess age distribution of current leadership
    leader_tenures =
      leaders
      |> Enum.map(&calculate_tenure_days(&1.join_date))

    avg_tenure =
      if Enum.empty?(leader_tenures) do
        0
      else
        Enum.sum(leader_tenures) / length(leader_tenures)
      end

    succession_health =
      cond do
        length(potential_leaders) >= length(leaders) -> :excellent_succession
        length(potential_leaders) >= div(length(leaders), 2) -> :adequate_succession
        length(potential_leaders) > 0 -> :limited_succession
        true -> :poor_succession
      end

    %{
      current_leaders: length(leaders),
      potential_successors: length(potential_leaders),
      avg_leader_tenure: Float.round(avg_tenure, 1),
      succession_health: succession_health,
      succession_risks: identify_succession_risks(leaders, potential_leaders)
    }
  end

  defp identify_potential_leaders(members) do
    # Identify members who could become leaders
    members
    |> Enum.filter(fn member ->
      # High activity, good tenure, not currently in leadership
      not has_leadership_role?(member) &&
        (member.recent_activity_score || 0) > 60 &&
        calculate_tenure_days(member.join_date) > 90
    end)
    |> Enum.sort_by(&(&1.recent_activity_score || 0), :desc)
    |> Enum.take(10)
  end

  defp identify_succession_risks(leaders, potential_leaders) do
    risks = []

    # Single point of failure risk
    ceos =
      Enum.count(leaders, fn leader ->
        leader.roles && "CEO" in leader.roles
      end)

    succession_risks =
      if ceos <= 1 do
        ["Single CEO creates succession risk" | risks]
      else
        risks
      end

    # Aging leadership risk
    old_leaders =
      Enum.count(leaders, fn leader ->
        # 2+ years
        calculate_tenure_days(leader.join_date) > 365 * 2
      end)

    aging_risks =
      if old_leaders > length(leaders) * 0.7 do
        ["Leadership team lacks fresh perspective" | succession_risks]
      else
        succession_risks
      end

    # Insufficient pipeline risk
    pipeline_risks =
      if length(potential_leaders) < 3 do
        ["Insufficient leadership pipeline" | aging_risks]
      else
        aging_risks
      end

    Enum.reverse(pipeline_risks)
  end

  defp assess_decision_making do
    # Would analyze decision-making speed and effectiveness
    # Simplified implementation
    %{
      decision_speed: :moderate,
      member_input_level: :adequate,
      transparency: :good,
      consistency: :moderate
    }
  end

  defp analyze_leadership_distribution(members) do
    leaders = Enum.filter(members, &has_leadership_role?/1)

    # Analyze leadership by role type
    role_distribution =
      leaders
      |> Enum.flat_map(fn leader -> leader.roles || [] end)
      |> Enum.frequencies()

    # Analyze leadership geographic/timezone distribution
    timezone_distribution = analyze_leadership_timezones(leaders)

    %{
      role_distribution: role_distribution,
      timezone_distribution: timezone_distribution,
      concentration_risk: assess_leadership_concentration(leaders)
    }
  end

  defp analyze_leadership_timezones(leaders) do
    # Analyze actual activity patterns to determine timezone distribution
    if Enum.empty?(leaders) do
      %{"Unknown" => 100}
    else
      # Analyze each leader's activity patterns
      timezone_assignments =
        leaders
        |> Enum.map(fn leader ->
          # Get leader's peak activity hours from their metrics
          peak_hours = leader[:peak_activity_hours] || []
          timezone = determine_timezone_from_activity(peak_hours)
          {timezone, 1}
        end)
        |> Enum.group_by(fn {tz, _} -> tz end, fn {_, count} -> count end)
        |> Enum.map(fn {tz, counts} -> {tz, Enum.sum(counts)} end)

      total_leaders = length(leaders)

      # Calculate percentages
      timezone_assignments
      |> Enum.map(fn {tz, count} ->
        {tz, Float.round(count / total_leaders * 100, 1)}
      end)
      |> Map.new()
    end
  end

  defp determine_timezone_from_activity(peak_hours) do
    if Enum.empty?(peak_hours) do
      "Unknown"
    else
      # Calculate average peak hour
      avg_hour = Enum.sum(peak_hours) / length(peak_hours)

      # Map to approximate timezone based on EVE prime times
      cond do
        # Australian/Asian timezone
        avg_hour >= 0 && avg_hour < 8 -> "AU-TZ"
        # European timezone
        avg_hour >= 8 && avg_hour < 16 -> "EU-TZ"
        # US timezone
        avg_hour >= 16 && avg_hour < 24 -> "US-TZ"
        true -> "Other"
      end
    end
  end

  defp assess_leadership_concentration(leaders) do
    # Assess if leadership is too concentrated in one area/group
    # Simplified assessment
    if length(leaders) < 3 do
      :high_concentration_risk
    else
      :distributed_leadership
    end
  end

  defp assess_mentorship_effectiveness(_members) do
    # Would analyze mentorship program effectiveness
    # Simplified implementation
    %{
      mentorship_programs: :basic,
      mentor_count: 5,
      mentee_success_rate: 0.65,
      program_effectiveness: :moderate
    }
  end

  defp assess_organizational_stability(members, activity_data, risk_data) do
    stability_metrics = %{
      member_turnover: calculate_member_turnover(members),
      activity_consistency: assess_activity_consistency(activity_data),
      risk_profile: assess_organizational_risk_profile(risk_data),
      growth_pattern: analyze_growth_pattern(members),
      structural_stability: assess_structural_stability(members)
    }

    {:ok, stability_metrics}
  end

  defp calculate_member_turnover(members) do
    # Calculate turnover metrics
    total_members = length(members)

    # Recent recruits (last 90 days)
    recent_cutoff = DateTime.utc_now() |> DateTimeUtils.add(-90 * 24 * 60 * 60, :second)

    recent_recruits =
      Enum.count(members, fn member ->
        member.join_date && DateTimeUtils.compare(member.join_date, recent_cutoff) == :gt
      end)

    # Inactive members (30+ days)
    inactive_cutoff = DateTime.utc_now() |> DateTimeUtils.add(-30 * 24 * 60 * 60, :second)

    inactive_members =
      Enum.count(members, fn member ->
        is_nil(member.last_seen) ||
          DateTimeUtils.compare(member.last_seen, inactive_cutoff) == :lt
      end)

    recruitment_rate =
      if total_members > 0 do
        recent_recruits / total_members * 100
      else
        0
      end

    inactivity_rate =
      if total_members > 0 do
        inactive_members / total_members * 100
      else
        0
      end

    %{
      total_members: total_members,
      recent_recruits: recent_recruits,
      inactive_members: inactive_members,
      recruitment_rate: Float.round(recruitment_rate, 1),
      inactivity_rate: Float.round(inactivity_rate, 1),
      turnover_assessment: assess_turnover_health(recruitment_rate, inactivity_rate)
    }
  end

  defp assess_turnover_health(recruitment_rate, inactivity_rate) do
    net_growth = recruitment_rate - inactivity_rate

    cond do
      inactivity_rate > 40 -> :unhealthy_turnover
      inactivity_rate > 25 -> :concerning_turnover
      net_growth > 5 -> :healthy_growth
      net_growth > -5 -> :stable_membership
      true -> :declining_membership
    end
  end

  defp assess_activity_consistency(activity_data) do
    # Analyze consistency in member activity
    member_metrics = activity_data.member_metrics || []

    if Enum.empty?(member_metrics) do
      %{consistency: 0, assessment: :no_data}
    else
      # Calculate activity score variance
      activity_scores = Enum.map(member_metrics, & &1.activity_score)
      mean_score = Enum.sum(activity_scores) / length(activity_scores)

      variance =
        activity_scores
        |> Enum.map(fn score -> :math.pow(score - mean_score, 2) end)
        |> Enum.sum()
        |> Kernel./(length(activity_scores))

      std_dev = :math.sqrt(variance)
      cv = if mean_score > 0, do: std_dev / mean_score, else: 1

      consistency_score = max(0, 100 * (1 - cv))

      assessment =
        cond do
          consistency_score >= 70 -> :highly_consistent
          consistency_score >= 50 -> :moderately_consistent
          consistency_score >= 30 -> :inconsistent
          true -> :highly_inconsistent
        end

      %{
        consistency_score: Float.round(consistency_score, 1),
        assessment: assessment,
        activity_variance: Float.round(variance, 1)
      }
    end
  end

  defp assess_organizational_risk_profile(risk_data) do
    # Aggregate risk assessment from individual member risks
    flight_risks = length(risk_data.flight_risks || [])
    total_members = risk_data.total_members || 1

    high_risk_ratio = flight_risks / total_members

    risk_profile =
      cond do
        high_risk_ratio > 0.3 -> :high_organizational_risk
        high_risk_ratio > 0.15 -> :moderate_organizational_risk
        high_risk_ratio > 0.05 -> :low_organizational_risk
        true -> :stable_organization
      end

    %{
      risk_profile: risk_profile,
      high_risk_member_ratio: Float.round(high_risk_ratio * 100, 1),
      primary_risk_factors: identify_primary_organizational_risks(risk_data)
    }
  end

  defp identify_primary_organizational_risks(risk_data) do
    risks = []

    # High flight risk
    flight_risk_count = length(risk_data.flight_risks || [])

    flight_risks =
      if flight_risk_count > 5 do
        ["High number of flight risks (#{flight_risk_count})" | risks]
      else
        risks
      end

    # Integration issues
    integration_assessment = risk_data.integration_assessment || %{}
    integration_health = Map.get(integration_assessment, :overall_integration_health, :unknown)

    integration_risks =
      if integration_health in [:poor, :critical] do
        ["Poor new member integration" | flight_risks]
      else
        flight_risks
      end

    # Retention issues
    retention_score = risk_data.retention_score || %{}
    retention_assessment = Map.get(retention_score, :assessment, :unknown)

    retention_risks =
      if retention_assessment in [:concerning_retention, :poor_retention] do
        ["Member retention concerns" | integration_risks]
      else
        integration_risks
      end

    Enum.reverse(retention_risks)
  end

  defp analyze_growth_pattern(members) do
    # Analyze member growth over time
    monthly_growth =
      members
      |> Enum.filter(& &1.join_date)
      |> Enum.group_by(fn member ->
        _date = DateTime.to_date(member.join_date)
        {DateHelper.get_year(member.join_date), DateHelper.get_month(member.join_date)}
      end)
      |> Enum.map(fn {month, month_members} ->
        {month, length(month_members)}
      end)
      |> Enum.sort()
      # Last 12 months
      |> Enum.take(-12)

    # Calculate growth trend
    growth_trend =
      if length(monthly_growth) >= 3 do
        recent_months = Enum.take(monthly_growth, -3)
        older_months = Enum.take(monthly_growth, 3)

        recent_avg = recent_months |> Enum.map(&elem(&1, 1)) |> Enum.sum() |> Kernel./(3)
        older_avg = older_months |> Enum.map(&elem(&1, 1)) |> Enum.sum() |> Kernel./(3)

        cond do
          recent_avg > older_avg * 1.2 -> :accelerating_growth
          recent_avg > older_avg * 0.8 -> :stable_growth
          true -> :declining_growth
        end
      else
        :insufficient_data
      end

    %{
      monthly_growth: monthly_growth,
      growth_trend: growth_trend,
      avg_monthly_growth: calculate_avg_monthly_growth(monthly_growth)
    }
  end

  defp calculate_avg_monthly_growth(monthly_growth) do
    if Enum.empty?(monthly_growth) do
      0
    else
      total_recruits = monthly_growth |> Enum.map(&elem(&1, 1)) |> Enum.sum()
      Float.round(total_recruits / length(monthly_growth), 1)
    end
  end

  defp assess_structural_stability(members) do
    # Assess structural stability indicators
    total_members = length(members)

    # Member age distribution
    tenure_distribution =
      members
      |> Enum.map(&calculate_tenure_days(&1.join_date))
      |> analyze_tenure_distribution()

    # Core member stability (members with 1+ year tenure)
    core_members =
      Enum.count(members, fn member ->
        calculate_tenure_days(member.join_date) > 365
      end)

    core_ratio =
      if total_members > 0 do
        core_members / total_members
      else
        0
      end

    stability_assessment =
      cond do
        core_ratio > 0.4 -> :highly_stable
        core_ratio > 0.25 -> :stable
        core_ratio > 0.15 -> :moderately_stable
        true -> :unstable
      end

    %{
      total_members: total_members,
      core_members: core_members,
      core_member_ratio: Float.round(core_ratio * 100, 1),
      tenure_distribution: tenure_distribution,
      stability_assessment: stability_assessment
    }
  end

  defp analyze_tenure_distribution(tenures) do
    %{
      "0-30 days" => Enum.count(tenures, &(&1 <= 30)),
      "31-90 days" => Enum.count(tenures, &(&1 > 30 and &1 <= 90)),
      "91-365 days" => Enum.count(tenures, &(&1 > 90 and &1 <= 365)),
      "1+ years" => Enum.count(tenures, &(&1 > 365))
    }
  end

  defp assess_member_satisfaction(activity_data, risk_data) do
    # Infer member satisfaction from activity and risk data
    member_metrics = activity_data.member_metrics || []

    if Enum.empty?(member_metrics) do
      %{satisfaction_score: 0, assessment: :no_data}
    else
      # Calculate satisfaction indicators
      high_activity_members = Enum.count(member_metrics, &(&1.activity_score > 70))
      total_members = length(member_metrics)

      engagement_rate = high_activity_members / max(total_members, 1)

      # Factor in flight risk
      flight_risk_count = length(risk_data.flight_risks || [])
      flight_risk_ratio = flight_risk_count / max(total_members, 1)

      # Calculate satisfaction score (inverse of flight risk, positive from engagement)
      satisfaction_score = engagement_rate * 60 + (1 - flight_risk_ratio) * 40

      assessment =
        cond do
          satisfaction_score >= 80 -> :high_satisfaction
          satisfaction_score >= 60 -> :moderate_satisfaction
          satisfaction_score >= 40 -> :low_satisfaction
          true -> :poor_satisfaction
        end

      %{
        satisfaction_score: Float.round(satisfaction_score, 1),
        assessment: assessment,
        engagement_rate: Float.round(engagement_rate * 100, 1),
        satisfaction_indicators: identify_satisfaction_indicators(activity_data, risk_data)
      }
    end
  end

  defp identify_satisfaction_indicators(activity_data, risk_data) do
    indicators = []

    # Positive indicators
    summary = activity_data.summary || %{}
    participation_rate = Map.get(summary, :participation_rate, 0)

    participation_indicators =
      if participation_rate > 70 do
        ["High member participation rate" | indicators]
      else
        indicators
      end

    # Negative indicators
    retention_score = risk_data.retention_score || %{}
    retention_assessment = Map.get(retention_score, :assessment, :unknown)

    retention_indicators =
      if retention_assessment in [:concerning_retention, :poor_retention] do
        ["Member retention concerns" | participation_indicators]
      else
        participation_indicators
      end

    Enum.reverse(retention_indicators)
  end

  defp assess_communication_health(participation_data) do
    # Assess communication health from participation patterns
    participation_summary = participation_data.participation_summary || %{}

    participation_rate = Map.get(participation_summary, :participation_rate, 0)
    fleet_participation = Map.get(participation_summary, :fleet_participation_rate, 0)

    # Communication health indicators
    communication_score = participation_rate * 0.6 + fleet_participation * 0.4

    assessment =
      cond do
        communication_score >= 70 -> :excellent_communication
        communication_score >= 50 -> :good_communication
        communication_score >= 30 -> :adequate_communication
        true -> :poor_communication
      end

    %{
      communication_score: Float.round(communication_score, 1),
      assessment: assessment,
      participation_indicators: analyze_communication_indicators(participation_data)
    }
  end

  defp analyze_communication_indicators(participation_data) do
    timezone_coverage = participation_data.timezone_coverage || %{}
    timezone_strength = Map.get(timezone_coverage, :timezone_strength, :unknown)

    indicators = []

    timezone_indicators =
      case timezone_strength do
        :excellent_coverage -> ["Excellent timezone coverage" | indicators]
        :good_coverage -> ["Good timezone coverage" | indicators]
        :poor_coverage -> ["Poor timezone coverage affecting communication" | indicators]
        :very_poor_coverage -> ["Very poor timezone coverage" | indicators]
        _ -> indicators
      end

    Enum.reverse(timezone_indicators)
  end

  defp assess_growth_sustainability(members, activity_data) do
    # Assess if current growth pattern is sustainable
    total_members = length(members)

    # Calculate growth sustainability metrics
    recent_recruits =
      Enum.count(members, fn member ->
        if member.join_date do
          DateTimeUtils.diff(DateTime.utc_now(), member.join_date, :day) <= 90
        else
          false
        end
      end)

    growth_rate = recent_recruits / max(total_members, 1)

    # Activity capacity assessment
    summary = activity_data.summary || %{}
    avg_activity = Map.get(summary, :avg_activity_score, 0)

    # Sustainability assessment
    sustainability =
      cond do
        # >50% growth in 90 days
        growth_rate > 0.5 -> :unsustainable_growth
        growth_rate > 0.2 and avg_activity < 40 -> :strained_growth
        growth_rate > 0.1 and avg_activity > 50 -> :healthy_growth
        growth_rate > 0.05 -> :moderate_growth
        true -> :slow_growth
      end

    %{
      growth_rate: Float.round(growth_rate * 100, 1),
      sustainability: sustainability,
      capacity_utilization: assess_capacity_utilization(total_members, avg_activity),
      growth_recommendations: generate_growth_recommendations(sustainability, avg_activity)
    }
  end

  defp assess_capacity_utilization(_total_members, avg_activity) do
    # Assess how well the corporation is utilizing its member capacity
    utilization = avg_activity

    cond do
      utilization >= 70 -> :high_utilization
      utilization >= 50 -> :moderate_utilization
      utilization >= 30 -> :low_utilization
      true -> :very_low_utilization
    end
  end

  defp generate_growth_recommendations(sustainability, avg_activity) do
    recommendations = []

    sustainability_recommendations =
      case sustainability do
        :unsustainable_growth ->
          ["Slow recruitment to focus on member integration" | recommendations]

        :strained_growth ->
          ["Improve member engagement before recruiting more" | recommendations]

        :slow_growth ->
          ["Consider increasing recruitment efforts" | recommendations]

        _ ->
          recommendations
      end

    activity_recommendations =
      if avg_activity < 40 do
        ["Focus on increasing member activity and engagement" | sustainability_recommendations]
      else
        sustainability_recommendations
      end

    Enum.reverse(activity_recommendations)
  end

  defp calculate_health_metrics(activity_data, risk_data, participation_data, leadership_data) do
    # Calculate comprehensive health metrics

    # Activity health (0-100)
    activity_health = calculate_activity_health(activity_data)

    # Leadership health (0-100)
    leadership_health = calculate_leadership_health(leadership_data)

    # Member retention health (0-100)
    retention_health = calculate_retention_health(risk_data)

    # Participation health (0-100)
    participation_health = calculate_participation_health(participation_data)

    %{
      activity_health: activity_health,
      leadership_health: leadership_health,
      retention_health: retention_health,
      participation_health: participation_health,
      component_weights: %{
        activity: 0.3,
        leadership: 0.25,
        retention: 0.25,
        participation: 0.2
      }
    }
  end

  defp calculate_activity_health(activity_data) do
    summary = activity_data.summary || %{}

    participation_rate = Map.get(summary, :participation_rate, 0)
    avg_activity = Map.get(summary, :avg_activity_score, 0)

    # Weighted health score
    health_score = participation_rate * 0.6 + avg_activity * 0.4
    Float.round(health_score, 1)
  end

  defp calculate_leadership_health(leadership_data) do
    safe_leadership_data =
      case leadership_data do
        data when is_map(data) -> data
        _ -> %{}
      end

    depth = Map.get(safe_leadership_data, :leadership_depth, %{})
    activity = Map.get(safe_leadership_data, :leadership_activity, %{})

    # Leadership depth score (0-100)
    depth_score =
      case Map.get(depth, :depth_assessment, :leadership_shortage) do
        :healthy_leadership -> 90
        :adequate_leadership -> 70
        # Can be problematic
        :too_many_leaders -> 60
        :leadership_shortage -> 30
      end

    # Leadership activity score
    activity_score = Map.get(activity, :activity_score, 0)

    # Combined leadership health
    health_score = depth_score * 0.6 + activity_score * 0.4
    Float.round(health_score, 1)
  end

  defp calculate_retention_health(risk_data) do
    safe_risk_data =
      case risk_data do
        data when is_map(data) -> data
        _ -> %{}
      end

    retention_score = Map.get(safe_risk_data, :retention_score, %{})
    base_score = Map.get(retention_score, :score, 0)

    Float.round(base_score, 1)
  end

  defp calculate_participation_health(participation_data) do
    safe_participation_data =
      case participation_data do
        data when is_map(data) -> data
        _ -> %{}
      end

    summary = Map.get(safe_participation_data, :participation_summary, %{})

    participation_rate = Map.get(summary, :participation_rate, 0)
    fleet_participation = Map.get(summary, :fleet_participation_rate, 0)

    # Participation health score
    health_score = participation_rate * 0.7 + fleet_participation * 0.3
    Float.round(health_score, 1)
  end

  defp calculate_overall_health_score(health_metrics) do
    weights =
      Map.get(health_metrics, :component_weights, %{
        activity: 0.25,
        leadership: 0.25,
        retention: 0.25,
        participation: 0.25
      })

    total_score =
      Map.get(health_metrics, :activity_health, 0) * Map.get(weights, :activity, 0.25) +
        Map.get(health_metrics, :leadership_health, 0) * Map.get(weights, :leadership, 0.25) +
        Map.get(health_metrics, :retention_health, 0) * Map.get(weights, :retention, 0.25) +
        Map.get(health_metrics, :participation_health, 0) * Map.get(weights, :participation, 0.25)

    Float.round(total_score, 1)
  end

  defp categorize_health_level(health_metrics) do
    overall_score = calculate_overall_health_score(health_metrics)

    cond do
      overall_score >= 80 -> :excellent_health
      overall_score >= 65 -> :good_health
      overall_score >= 50 -> :fair_health
      overall_score >= 35 -> :poor_health
      true -> :critical_health
    end
  end

  defp identify_health_issues(health_metrics, leadership_data, stability_data) do
    []
    |> maybe_add_activity_issue(health_metrics.activity_health)
    |> maybe_add_leadership_issue(health_metrics.leadership_health)
    |> maybe_add_stability_issue(stability_data.structural_stability)
    |> maybe_add_succession_issue(leadership_data.succession_planning)
    |> Enum.reverse()
  end

  defp maybe_add_activity_issue(issues, activity_health) when activity_health < 50 do
    ["Low member activity levels affecting corporation health" | issues]
  end

  defp maybe_add_activity_issue(issues, _activity_health), do: issues

  defp maybe_add_leadership_issue(issues, leadership_health) when leadership_health < 50 do
    ["Leadership effectiveness concerns" | issues]
  end

  defp maybe_add_leadership_issue(issues, _leadership_health), do: issues

  defp maybe_add_stability_issue(issues, stability) do
    safe_stability =
      case stability do
        data when is_map(data) -> data
        _ -> %{}
      end

    if Map.get(safe_stability, :stability_assessment) in [:unstable, :moderately_stable] do
      ["Structural stability concerns" | issues]
    else
      issues
    end
  end

  defp maybe_add_succession_issue(issues, succession) do
    safe_succession =
      case succession do
        data when is_map(data) -> data
        _ -> %{}
      end

    if Map.get(safe_succession, :succession_health) in [:poor_succession, :limited_succession] do
      ["Leadership succession planning inadequate" | issues]
    else
      issues
    end
  end

  defp generate_health_recommendations(health_metrics, _leadership_data, stability_data) do
    safe_stability_data =
      case stability_data do
        data when is_map(data) -> data
        _ -> %{}
      end

    stability = Map.get(safe_stability_data, :structural_stability, %{})
    core_ratio = Map.get(stability, :core_member_ratio, 0)

    []
    |> maybe_add_activity_recommendation(health_metrics.activity_health)
    |> maybe_add_leadership_recommendation(health_metrics.leadership_health)
    |> maybe_add_retention_recommendation(health_metrics.retention_health)
    |> maybe_add_stability_recommendation(core_ratio)
    |> Enum.reverse()
  end

  defp maybe_add_activity_recommendation(recommendations, activity_health)
       when activity_health < 60 do
    ["Implement member engagement initiatives to improve activity" | recommendations]
  end

  defp maybe_add_activity_recommendation(recommendations, _activity_health), do: recommendations

  defp maybe_add_leadership_recommendation(recommendations, leadership_health)
       when leadership_health < 60 do
    ["Strengthen leadership structure and development programs" | recommendations]
  end

  defp maybe_add_leadership_recommendation(recommendations, _leadership_health),
    do: recommendations

  defp maybe_add_retention_recommendation(recommendations, retention_health)
       when retention_health < 60 do
    ["Address member retention issues through improved onboarding" | recommendations]
  end

  defp maybe_add_retention_recommendation(recommendations, _retention_health), do: recommendations

  defp maybe_add_stability_recommendation(recommendations, core_ratio) when core_ratio < 25 do
    ["Build core member base for long-term stability" | recommendations]
  end

  defp maybe_add_stability_recommendation(recommendations, _core_ratio), do: recommendations

  defp calculate_tenure_days(nil), do: 0

  defp calculate_tenure_days(join_date) do
    DateTimeUtils.diff(DateTime.utc_now(), join_date, :day)
  end

  defp has_leadership_role?(member) do
    leadership_roles = [
      "CEO",
      "Director",
      "Executor",
      "Station Manager",
      "Fleet Commander",
      "Wing Commander",
      "Squad Commander",
      "Recruiter",
      "Diplomat",
      "Personnel Manager"
    ]

    roles = member.roles || []
    Enum.any?(roles, fn role -> role in leadership_roles end)
  end
end
