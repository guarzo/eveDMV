defmodule EveDmv.Intelligence.Analyzers.MemberActivityAnalyzer do
  @moduledoc """
  Member activity intelligence analyzer and early warning system.

  Analyzes member participation patterns, identifies engagement trends,
  and provides early warning for burnout or disengagement risks.

  This module serves as the main orchestrator, delegating calculations
  to MemberActivityMetrics and formatting to MemberActivityFormatter.

  Implements the Intelligence.Analyzer behavior for consistent interface and telemetry.
  """

  use EveDmv.Intelligence.Analyzer

  require Logger
  require Ash.Query
  # TimeUtils moved to extracted modules
  alias EveDmv.Intelligence.Core.{CacheHelper, TimeoutHelper, ValidationHelper, Config}

  # CharacterStats moved to CorporationAnalyzer
  # EngagementCalculator moved to EngagementAnalyzer
  alias EveDmv.Intelligence.Formatters.MemberActivityFormatter
  alias EveDmv.Intelligence.MemberActivityIntelligence
  alias EveDmv.Intelligence.Metrics.MemberActivityMetrics
  alias EveDmv.Intelligence.Analyzers.MemberActivityDataCollector
  alias EveDmv.Intelligence.Analyzers.MemberActivityPatternAnalyzer
  alias EveDmv.Intelligence.Analyzers.MemberParticipationAnalyzer
  alias EveDmv.Intelligence.Analyzers.MemberRiskAssessment
  # CommunicationPatternAnalyzer moved to ActivityHelpers
  # Extracted modules
  alias EveDmv.Intelligence.Analyzers.MemberActivityAnalyzer.{
    CorporationAnalyzer,
    EngagementAnalyzer,
    ActivityTrendAnalyzer,
    RecruitmentRetentionAnalyzer,
    ActivityHelpers
  }

  # Behavior implementations

  @impl true
  def analysis_type, do: :member_activity

  @impl true
  def validate_params(character_id, opts) do
    ValidationHelper.validate_character_analysis(character_id, opts)
  end

  @impl true
  def analyze(character_id, opts \\ %{}) do
    cache_ttl = Config.get_cache_ttl(:member_activity)

    CacheHelper.get_or_compute(:member_activity, character_id, cache_ttl, fn ->
      do_analyze_member_activity(character_id, opts)
    end)
  end

  @impl true
  def invalidate_cache(character_id) do
    CacheHelper.invalidate_analysis(:member_activity, character_id)
  end

  @doc """
  Legacy interface for backwards compatibility.
  Generate comprehensive member activity analysis for a character.

  Returns {:ok, analysis_record} or {:error, reason}
  """
  def analyze_member_activity(character_id, period_start, period_end, _options \\ []) do
    opts = %{period_start: period_start, period_end: period_end}

    case analyze_with_telemetry(character_id, opts) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        Logger.error(
          "Member activity analysis failed for character #{character_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # Private implementation functions

  defp do_analyze_member_activity(character_id, opts) do
    # Extract parameters from opts or use defaults
    period_start = Map.get(opts, :period_start, DateTime.add(DateTime.utc_now(), -30, :day))
    period_end = Map.get(opts, :period_end, DateTime.utc_now())

    perform_member_activity_analysis(character_id, period_start, period_end)
  end

  defp perform_member_activity_analysis(character_id, period_start, period_end) do
    with {:ok, character_info} <-
           TimeoutHelper.with_default_timeout(
             fn -> MemberActivityDataCollector.get_character_info(character_id) end,
             :query
           ),
         {:ok, activity_data} <-
           TimeoutHelper.with_default_timeout(
             fn ->
               MemberActivityDataCollector.collect_activity_data(
                 character_id,
                 period_start,
                 period_end
               )
             end,
             :analysis
           ),
         {:ok, participation_data} <-
           TimeoutHelper.with_default_timeout(
             fn ->
               MemberParticipationAnalyzer.analyze_participation_patterns(
                 character_id,
                 period_start,
                 period_end
               )
             end,
             :analysis
           ),
         {:ok, risk_assessment} <-
           TimeoutHelper.with_default_timeout(
             fn ->
               MemberRiskAssessment.assess_member_risks(
                 character_id,
                 activity_data,
                 participation_data
               )
             end,
             :analysis
           ),
         {:ok, timezone_analysis} <-
           TimeoutHelper.with_default_timeout(
             fn ->
               MemberActivityPatternAnalyzer.analyze_timezone_patterns(
                 character_id,
                 activity_data
               )
             end,
             :analysis
           ),
         {:ok, peer_comparison} <-
           TimeoutHelper.with_default_timeout(
             fn ->
               calculate_peer_comparison(
                 character_id,
                 character_info.corporation_id,
                 activity_data
               )
             end,
             :analysis
           ) do
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
        activity_trend: MemberActivityMetrics.determine_activity_trend(activity_data),
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

      try do
        case MemberActivityIntelligence.create(analysis_data) do
          {:ok, analysis} ->
            {:ok, analysis}

          {:error, reason} ->
            {:error, "Failed to create member activity analysis: #{inspect(reason)}"}
        end
      rescue
        error ->
          Logger.error("Error in member activity analysis calculation: #{inspect(error)}")
          {:error, "Member activity analysis calculation failed"}
      end
    else
      {:error, reason} ->
        {:error, "Failed to gather member activity analysis data: #{inspect(reason)}"}
    end
  end

  @doc """
  Update member activity intelligence with new activity data.
  """
  def record_member_activity(character_id, activity_type, activity_data \\ %{}) do
    case ActivityHelpers.record_member_activity(character_id, activity_type, activity_data) do
      {:create_analysis_needed, params} ->
        # Create analysis for the last 30 days
        analyze_member_activity(params.character_id, params.start_date, params.end_date)
      
      result ->
        result
    end
  end

  defdelegate generate_corporation_activity_report(corporation_id, options \\ []), to: CorporationAnalyzer

  defdelegate identify_members_needing_attention(corporation_id, options \\ []), to: CorporationAnalyzer

  @doc """
  Analyze corporation-wide activity patterns.
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

  # Helper functions for core analysis logic

  defdelegate calculate_peer_comparison(character_id, corporation_id, activity_data), to: CorporationAnalyzer

  defp get_latest_analysis(character_id) do
    case MemberActivityIntelligence.get_by_character(character_id) do
      {:ok, analysis} -> {:ok, analysis}
      {:error, reason} -> {:error, reason}
    end
  end

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

  # Simplified data collection helpers (would integrate with real data sources)

  defp count_active_members(member_analyses) do
    EngagementCalculator.count_active_members(member_analyses, 30)
  end

  defp calculate_average_engagement(member_analyses) do
    EngagementCalculator.calculate_average_engagement(member_analyses)
  end

  defp calculate_at_risk_percentage(member_analyses) do
    EngagementCalculator.calculate_at_risk_percentage(member_analyses)
  end

  defp calculate_high_performers_percentage(member_analyses) do
    EngagementCalculator.calculate_high_performers_percentage(member_analyses, 80)
  end

  # Public API functions expected by tests

  @doc """
  Calculate engagement score for a single member.
  """
  defdelegate calculate_engagement_score(member_data), to: EngagementAnalyzer

  @doc """
  Calculate member engagement from activity data.
  """
  defdelegate calculate_member_engagement(member_activities), to: EngagementAnalyzer
  # Engagement calculation functions delegated to EngagementAnalyzer

  @doc """
  Analyze activity trends over time.
  """
  defdelegate analyze_activity_trends(member_activities, days), to: ActivityTrendAnalyzer
  # Activity trend analysis functions delegated to ActivityTrendAnalyzer

  @doc """
  Identify members at risk of leaving or becoming inactive.
  """
  defdelegate identify_retention_risks(member_data), to: RecruitmentRetentionAnalyzer

  @doc """
  Generate recruitment insights from activity data.
  """
  defdelegate generate_recruitment_insights(activity_data), to: RecruitmentRetentionAnalyzer

  @doc """
  Calculate fleet participation metrics.
  """
  defdelegate calculate_fleet_participation_metrics(fleet_data), to: ActivityHelpers

  @doc """
  Classify activity level based on score.
  """
  defdelegate classify_activity_level(activity_score), to: EngagementAnalyzer

  @doc """
  Analyze communication patterns from member data.
  """
  defdelegate analyze_communication_patterns(communication_data), to: ActivityHelpers

  @doc """
  Generate activity recommendations based on analysis data.
  """
  defdelegate generate_activity_recommendations(analysis_data), to: RecruitmentRetentionAnalyzer

  @doc """
  Calculate trend direction from activity data.
  """
  defdelegate calculate_trend_direction(activity_data), to: ActivityTrendAnalyzer

  @doc """
  Calculate days since last activity.
  """
  defdelegate days_since_last_activity(last_activity, current_time), to: RecruitmentRetentionAnalyzer

  @doc """
  Fetch corporation members.
  """
  defdelegate fetch_corporation_members(corporation_id), to: CorporationAnalyzer

  @doc """
  Process member activity data.
  """
  defdelegate process_member_activity(member_data, current_time), to: RecruitmentRetentionAnalyzer
  # Helper functions moved to extracted modules:
  # - ActivityTrendAnalyzer: trend analysis, peak detection, seasonal patterns
  # - EngagementAnalyzer: engagement scoring and classification
  # - RecruitmentRetentionAnalyzer: retention risk and recruitment insights
  # - CorporationAnalyzer: corporation-wide analysis
  # - ActivityHelpers: utility functions
end
