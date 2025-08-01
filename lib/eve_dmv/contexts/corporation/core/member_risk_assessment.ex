defmodule EveDmv.Contexts.Corporation.Core.MemberRiskAssessment do
  @moduledoc """
  Analyzes member risks including flight risk, integration issues, and retention concerns.

  Consolidates functionality from:
  - Corporation Intelligence member risk assessment
  - Corporation Analysis risk analytics
  """

  alias EveDmv.Contexts.Corporation.Core.MemberActivityAnalyzer
  alias EveDmv.Platform.Cache.Corporation.CorporationCache
  alias EveDmv.Platform.Database.CorporationRepository

  require Logger

  @cache_ttl :timer.hours(6)

  @doc """
  Assess member risks for a corporation.
  """
  def assess_member_risks(corporation_id) do
    cache_key = {:member_risks, corporation_id}

    case CorporationCache.get(cache_key) do
      nil ->
        result = perform_risk_assessment(corporation_id)

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
  Identify members at high risk of leaving.
  """
  def identify_flight_risks(corporation_id) do
    case assess_member_risks(corporation_id) do
      {:ok, assessment} -> {:ok, assessment.flight_risks}
      error -> error
    end
  end

  @doc """
  Assess how well new members are integrating.
  """
  def assess_new_member_integration(corporation_id) do
    case assess_member_risks(corporation_id) do
      {:ok, assessment} -> {:ok, assessment.integration_assessment}
      error -> error
    end
  end

  @doc """
  Calculate overall member retention score.
  """
  def calculate_member_retention_score(corporation_id) do
    case assess_member_risks(corporation_id) do
      {:ok, assessment} -> {:ok, assessment.retention_score}
      error -> error
    end
  end

  @doc """
  Batch assess risks for multiple corporations.
  """
  def assess_batch(corporation_ids) do
    corporation_ids
    |> Task.async_stream(
      fn corp_id ->
        {corp_id, assess_member_risks(corp_id)}
      end,
      max_concurrency: 5,
      timeout: 30_000
    )
    |> Enum.reduce({[], []}, fn
      {:ok, {corp_id, {:ok, assessment}}}, {successes, failures} ->
        {[{corp_id, assessment} | successes], failures}

      {:ok, {corp_id, {:error, reason}}}, {successes, failures} ->
        {successes, [{corp_id, reason} | failures]}

      {:exit, reason}, {successes, failures} ->
        Logger.error("Risk assessment batch failed: #{inspect(reason)}")
        {successes, failures}
    end)
    |> then(fn {successes, failures} ->
      {:ok,
       %{
         assessments: Map.new(Enum.reverse(successes)),
         failures: Enum.reverse(failures)
       }}
    end)
  end

  # Private Functions

  defp perform_risk_assessment(corporation_id) do
    Logger.info("Performing member risk assessment for corporation #{corporation_id}")

    with {:ok, members} <- CorporationRepository.get_corporation_members(corporation_id),
         {:ok, activity_analysis} <-
           MemberActivityAnalyzer.analyze_member_activity(corporation_id),
         {:ok, risk_data} <- analyze_member_risk_factors(members, activity_analysis) do
      assessment = %{
        corporation_id: corporation_id,
        total_members: length(members),
        flight_risks: identify_flight_risk_members(risk_data),
        integration_assessment: assess_member_integration(risk_data, members),
        retention_score: calculate_retention_score(risk_data),
        risk_distribution: analyze_risk_distribution(risk_data),
        early_warning_indicators: identify_early_warning_signs(risk_data),
        recommendations: generate_risk_mitigation_recommendations(risk_data),
        assessed_at: DateTime.utc_now()
      }

      {:ok, assessment}
    end
  end

  defp analyze_member_risk_factors(members, activity_analysis) do
    risk_data =
      members
      |> Task.async_stream(
        fn member ->
          {member.character_id, calculate_member_risk_profile(member, activity_analysis)}
        end,
        max_concurrency: 15,
        timeout: 10_000
      )
      |> Enum.reduce(%{}, fn
        {:ok, {char_id, risk_profile}}, acc ->
          Map.put(acc, char_id, risk_profile)

        {:exit, reason}, acc ->
          Logger.warning("Member risk calculation failed: #{inspect(reason)}")
          acc
      end)

    {:ok, risk_data}
  end

  defp calculate_member_risk_profile(member, activity_analysis) do
    # Find member activity data
    member_activity =
      activity_analysis.member_metrics
      |> Enum.find(fn m -> m.character_id == member.character_id end)

    # Calculate various risk factors
    activity_risk = calculate_activity_risk(member_activity)
    tenure_risk = calculate_tenure_risk(member)
    engagement_risk = calculate_engagement_risk(member_activity)
    social_risk = calculate_social_risk(member, member_activity)
    performance_risk = calculate_performance_risk(member_activity)

    # Overall risk score
    overall_risk =
      activity_risk * 0.3 + tenure_risk * 0.2 +
        engagement_risk * 0.2 + social_risk * 0.15 +
        performance_risk * 0.15

    %{
      character_id: member.character_id,
      character_name: member.character_name,
      overall_risk_score: Float.round(overall_risk, 2),
      risk_level: categorize_risk_level(overall_risk),
      risk_factors: %{
        activity_risk: activity_risk,
        tenure_risk: tenure_risk,
        engagement_risk: engagement_risk,
        social_risk: social_risk,
        performance_risk: performance_risk
      },
      risk_indicators: identify_specific_risk_indicators(member, member_activity),
      join_date: member.join_date,
      last_seen: member.last_seen,
      tenure_days: calculate_tenure_days(member.join_date),
      activity_score: (member_activity && member_activity.activity_score) || 0
    }
  end

  # No activity data = high risk
  defp calculate_activity_risk(nil), do: 100.0

  defp calculate_activity_risk(member_activity) do
    # Higher risk for lower activity
    activity_score = member_activity.activity_score

    # Days since last activity
    days_inactive =
      if member_activity.last_seen do
        DateTime.diff(DateTime.utc_now(), member_activity.last_seen, :day)
      else
        # Very high if never seen
        999
      end

    # Activity trend risk
    consistency_risk = 100 - member_activity.consistency_score

    # Combined activity risk
    # Lower activity = higher risk
    base_risk = 100 - activity_score
    # Up to 50 points for inactivity
    inactivity_penalty = min(days_inactive * 2, 50)

    total_risk = base_risk + inactivity_penalty + consistency_risk * 0.3
    Float.round(min(total_risk, 100), 2)
  end

  defp calculate_tenure_risk(member) do
    tenure_days = calculate_tenure_days(member.join_date)

    cond do
      # Very new members are flight risk
      tenure_days < 7 -> 80.0
      # Still settling in
      tenure_days < 30 -> 60.0
      # Getting established
      tenure_days < 90 -> 40.0
      # Moderately established
      tenure_days < 365 -> 25.0
      # Long-term members are lower risk
      true -> 10.0
    end
  end

  defp calculate_engagement_risk(nil), do: 80.0

  defp calculate_engagement_risk(member_activity) do
    # Risk based on engagement quality and patterns
    engagement_quality = member_activity.engagement_quality.quality_score
    participation_days = member_activity.participation_days

    # Low engagement quality = higher risk
    quality_risk = 100 - engagement_quality

    # Low participation frequency = higher risk
    participation_risk = if participation_days < 5, do: 50, else: max(0, 30 - participation_days)

    # Gang participation risk (solo players might be less committed)
    solo_ratio = member_activity.gang_participation.solo_ratio
    isolation_risk = if solo_ratio > 0.8, do: 20, else: 0

    total_risk = quality_risk * 0.5 + participation_risk * 0.3 + isolation_risk * 0.2
    Float.round(total_risk, 2)
  end

  defp calculate_social_risk(member, member_activity) do
    # Risk based on social integration indicators
    base_risk = 30.0

    # New members have higher social risk
    tenure_days = calculate_tenure_days(member.join_date)
    newbie_risk = if tenure_days < 30, do: 30, else: 0

    # Solo players might have higher social risk
    isolation_risk =
      if member_activity do
        solo_ratio = member_activity.gang_participation.solo_ratio
        if solo_ratio > 0.9, do: 25, else: 0
      else
        # No activity data suggests poor integration
        20
      end

    # Low participation in corp activities
    participation_risk =
      if member_activity && member_activity.participation_days < 3 do
        20
      else
        0
      end

    total_risk = base_risk + newbie_risk + isolation_risk + participation_risk
    Float.round(min(total_risk, 100), 2)
  end

  defp calculate_performance_risk(nil), do: 50.0

  defp calculate_performance_risk(member_activity) do
    # Risk based on combat performance
    engagement_quality = member_activity.engagement_quality

    # Poor performance might indicate frustration
    if engagement_quality.assessment in [:poor, :below_average] do
      60.0
    else
      case engagement_quality.assessment do
        :excellent -> 5.0
        :good -> 15.0
        :average -> 30.0
        _ -> 45.0
      end
    end
  end

  defp categorize_risk_level(risk_score) do
    cond do
      risk_score >= 80 -> :critical_risk
      risk_score >= 60 -> :high_risk
      risk_score >= 40 -> :moderate_risk
      risk_score >= 20 -> :low_risk
      true -> :minimal_risk
    end
  end

  defp identify_specific_risk_indicators(member, member_activity) do
    initial_indicators = []

    # Inactivity indicators
    indicators_with_inactivity =
      if member.last_seen do
        days_inactive = DateTime.diff(DateTime.utc_now(), member.last_seen, :day)

        if days_inactive > 14 do
          ["Extended inactivity (#{days_inactive} days)" | initial_indicators]
        else
          initial_indicators
        end
      else
        ["Never seen active" | initial_indicators]
      end

    # New member indicators
    tenure_days = calculate_tenure_days(member.join_date)

    indicators_with_tenure =
      if tenure_days < 7 do
        ["Very new member (#{tenure_days} days)" | indicators_with_inactivity]
      else
        indicators_with_inactivity
      end

    # Performance indicators
    final_indicators =
      if member_activity do
        indicators_with_activity =
          if member_activity.activity_score < 20 do
            ["Low activity score (#{member_activity.activity_score})" | indicators_with_tenure]
          else
            indicators_with_tenure
          end

        indicators_with_performance =
          if member_activity.engagement_quality.assessment == :poor do
            ["Poor combat performance" | indicators_with_activity]
          else
            indicators_with_activity
          end

        if member_activity.consistency_score < 30 do
          ["Inconsistent activity patterns" | indicators_with_performance]
        else
          indicators_with_performance
        end
      else
        indicators_with_tenure
      end

    Enum.reverse(final_indicators)
  end

  defp identify_flight_risk_members(risk_data) do
    risk_data
    |> Enum.filter(fn {_char_id, profile} ->
      profile.risk_level in [:critical_risk, :high_risk]
    end)
    |> Enum.sort_by(fn {_char_id, profile} -> profile.overall_risk_score end, :desc)
    |> Enum.map(fn {_char_id, profile} ->
      %{
        character_id: profile.character_id,
        character_name: profile.character_name,
        risk_score: profile.overall_risk_score,
        risk_level: profile.risk_level,
        primary_risk_factors: identify_primary_risk_factors(profile),
        risk_indicators: profile.risk_indicators,
        recommended_actions: generate_member_specific_actions(profile)
      }
    end)
  end

  defp identify_primary_risk_factors(profile) do
    profile.risk_factors
    |> Enum.sort_by(fn {_factor, score} -> score end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {factor, score} ->
      %{
        factor: factor,
        score: score,
        severity: categorize_factor_severity(score)
      }
    end)
  end

  defp categorize_factor_severity(score) do
    cond do
      score >= 80 -> :critical
      score >= 60 -> :high
      score >= 40 -> :moderate
      score >= 20 -> :low
      true -> :minimal
    end
  end

  defp generate_member_specific_actions(profile) do
    initial_actions = []

    # Activity-based actions
    actions_with_activity =
      if profile.risk_factors.activity_risk > 60 do
        ["Reach out to encourage participation in corp activities" | initial_actions]
      else
        initial_actions
      end

    # Tenure-based actions
    actions_with_tenure =
      if profile.tenure_days < 30 do
        ["Assign mentor or buddy for new member integration" | actions_with_activity]
      else
        actions_with_activity
      end

    # Engagement-based actions
    actions_with_engagement =
      if profile.risk_factors.engagement_risk > 50 do
        ["Provide combat training or doctrine guidance" | actions_with_tenure]
      else
        actions_with_tenure
      end

    # Social risk actions
    final_actions =
      if profile.risk_factors.social_risk > 50 do
        ["Include in social events and fleet operations" | actions_with_engagement]
      else
        actions_with_engagement
      end

    if Enum.empty?(final_actions) do
      ["Monitor for continued engagement"]
    else
      Enum.reverse(final_actions)
    end
  end

  defp assess_member_integration(risk_data, members) do
    # Focus on recent recruits (last 90 days)
    recent_cutoff = DateTime.utc_now() |> DateTime.add(-90, :day)

    recent_recruits =
      members
      |> Enum.filter(fn member ->
        member.join_date && DateTime.compare(member.join_date, recent_cutoff) == :gt
      end)

    if Enum.empty?(recent_recruits) do
      %{
        total_recent_recruits: 0,
        integration_status: :no_recent_recruits
      }
    else
      integration_scores =
        recent_recruits
        |> Enum.map(fn member ->
          risk_profile = Map.get(risk_data, member.character_id, %{overall_risk_score: 100})
          integration_score = calculate_integration_score(risk_profile, member)

          %{
            character_id: member.character_id,
            character_name: member.character_name,
            integration_score: integration_score,
            days_since_join: DateTime.diff(DateTime.utc_now(), member.join_date, :day),
            integration_status: categorize_integration_status(integration_score)
          }
        end)
        |> Enum.sort_by(& &1.integration_score)

      avg_integration =
        integration_scores
        |> Enum.map(& &1.integration_score)
        |> then(fn scores ->
          if Enum.empty?(scores), do: 0, else: Enum.sum(scores) / length(scores)
        end)

      %{
        total_recent_recruits: length(recent_recruits),
        average_integration_score: Float.round(avg_integration, 1),
        integration_distribution: analyze_integration_distribution(integration_scores),
        struggling_recruits:
          Enum.filter(integration_scores, &(&1.integration_status == :struggling)),
        successful_integrations:
          Enum.filter(integration_scores, &(&1.integration_status == :successful)),
        overall_integration_health: assess_overall_integration_health(avg_integration)
      }
    end
  end

  defp calculate_integration_score(risk_profile, member) do
    # Lower risk = better integration
    base_score = 100 - (risk_profile[:overall_risk_score] || 100)

    # Tenure adjustment (newer members expected to have some risk)
    tenure_days = calculate_tenure_days(member.join_date)

    tenure_adjustment =
      cond do
        # Very new, expected to have issues
        tenure_days < 7 -> -20
        # Still adjusting
        tenure_days < 30 -> -10
        # Should be well integrated by now
        true -> 0
      end

    adjusted_score = base_score + tenure_adjustment
    Float.round(max(0, min(100, adjusted_score)), 1)
  end

  defp categorize_integration_status(score) do
    cond do
      score >= 70 -> :successful
      score >= 50 -> :progressing
      score >= 30 -> :concerning
      true -> :struggling
    end
  end

  defp analyze_integration_distribution(integration_scores) do
    integration_scores
    |> Enum.map(& &1.integration_status)
    |> Enum.frequencies()
  end

  defp assess_overall_integration_health(avg_score) do
    cond do
      avg_score >= 70 -> :excellent
      avg_score >= 60 -> :good
      avg_score >= 50 -> :concerning
      avg_score >= 30 -> :poor
      true -> :critical
    end
  end

  defp calculate_retention_score(risk_data) do
    if map_size(risk_data) == 0 do
      %{score: 0, assessment: :no_data}
    else
      # Calculate average risk (lower risk = better retention)
      avg_risk =
        risk_data
        |> Map.values()
        |> Enum.map(& &1.overall_risk_score)
        |> then(fn scores -> Enum.sum(scores) / length(scores) end)

      retention_score = 100 - avg_risk

      # Risk distribution analysis
      risk_levels =
        risk_data
        |> Map.values()
        |> Enum.map(& &1.risk_level)
        |> Enum.frequencies()

      high_risk_ratio =
        (Map.get(risk_levels, :critical_risk, 0) +
           Map.get(risk_levels, :high_risk, 0)) / map_size(risk_data)

      %{
        score: Float.round(retention_score, 1),
        assessment: categorize_retention_health(retention_score),
        risk_distribution: risk_levels,
        high_risk_member_ratio: Float.round(high_risk_ratio * 100, 1),
        total_members_analyzed: map_size(risk_data)
      }
    end
  end

  defp categorize_retention_health(score) do
    cond do
      score >= 80 -> :excellent_retention
      score >= 70 -> :good_retention
      score >= 60 -> :acceptable_retention
      score >= 50 -> :concerning_retention
      true -> :poor_retention
    end
  end

  defp analyze_risk_distribution(risk_data) do
    risk_data
    |> Map.values()
    |> Enum.map(& &1.risk_level)
    |> Enum.frequencies()
  end

  defp identify_early_warning_signs(risk_data) do
    initial_warnings = []

    # Check for sudden activity drops
    recent_inactives =
      risk_data
      |> Map.values()
      |> Enum.count(fn profile ->
        profile.risk_factors.activity_risk > 70 and profile.tenure_days > 30
      end)

    warnings_with_inactivity =
      if recent_inactives > 0 do
        ["#{recent_inactives} established members showing sudden inactivity" | initial_warnings]
      else
        initial_warnings
      end

    # Check for poor new member integration
    new_member_struggles =
      risk_data
      |> Map.values()
      |> Enum.count(fn profile ->
        profile.tenure_days < 30 and profile.risk_level in [:critical_risk, :high_risk]
      end)

    warnings_with_integration =
      if new_member_struggles > 2 do
        [
          "#{new_member_struggles} new members struggling with integration"
          | warnings_with_inactivity
        ]
      else
        warnings_with_inactivity
      end

    # Check for performance-related risks
    performance_issues =
      risk_data
      |> Map.values()
      |> Enum.count(fn profile ->
        profile.risk_factors.performance_risk > 60
      end)

    final_warnings =
      if performance_issues > map_size(risk_data) * 0.2 do
        [
          "High number of members with performance-related risks (#{performance_issues})"
          | warnings_with_integration
        ]
      else
        warnings_with_integration
      end

    Enum.reverse(final_warnings)
  end

  defp generate_risk_mitigation_recommendations(risk_data) do
    initial_recommendations = []
    total_members = map_size(risk_data)

    # High-risk member recommendations
    high_risk_count =
      risk_data
      |> Map.values()
      |> Enum.count(fn profile -> profile.risk_level in [:critical_risk, :high_risk] end)

    recommendations_with_retention =
      if high_risk_count > total_members * 0.15 do
        [
          "Implement member retention program - #{high_risk_count} high-risk members identified"
          | initial_recommendations
        ]
      else
        initial_recommendations
      end

    # New member integration recommendations
    integration_issues =
      risk_data
      |> Map.values()
      |> Enum.count(fn profile ->
        profile.tenure_days < 30 and profile.risk_level != :minimal_risk
      end)

    recommendations_with_integration =
      if integration_issues > 3 do
        [
          "Improve new member onboarding process - integration issues detected"
          | recommendations_with_retention
        ]
      else
        recommendations_with_retention
      end

    # Activity engagement recommendations
    low_activity_count =
      risk_data
      |> Map.values()
      |> Enum.count(fn profile -> profile.risk_factors.activity_risk > 50 end)

    final_recommendations =
      if low_activity_count > total_members * 0.3 do
        [
          "Increase member engagement activities - high number of low-activity members"
          | recommendations_with_integration
        ]
      else
        recommendations_with_integration
      end

    if Enum.empty?(final_recommendations) do
      ["Continue monitoring member satisfaction and engagement levels"]
    else
      Enum.reverse(final_recommendations)
    end
  end

  defp calculate_tenure_days(nil), do: 0

  defp calculate_tenure_days(join_date) do
    DateTime.diff(DateTime.utc_now(), join_date, :day)
  end
end
