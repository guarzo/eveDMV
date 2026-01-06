defmodule EveDmv.Contexts.Corporation.Api do
  @moduledoc """
  Public API for the Corporation context.

  This module provides the unified interface for all corporation analysis and
  intelligence functionality, including member activity analysis, recruitment
  insights, and organizational health metrics.
  """

  alias EveDmv.Contexts.Corporation.Core.CombatDoctrineAnalyzer
  alias EveDmv.Contexts.Corporation.Core.CorporationAnalyzer
  alias EveDmv.Contexts.Corporation.Core.MemberActivityAnalyzer
  alias EveDmv.Contexts.Corporation.Core.MemberRiskAssessment
  alias EveDmv.Contexts.Corporation.Core.OrganizationalHealthAnalyzer
  alias EveDmv.Contexts.Corporation.Core.ParticipationAnalyzer
  alias EveDmv.Contexts.Corporation.Core.RecruitmentAnalyzer
  alias EveDmv.Contexts.Corporation.Services.AnalyticsService
  alias EveDmv.Contexts.Corporation.Services.CorporationService
  alias EveDmv.Contexts.Corporation.Services.MemberService
  alias EveDmv.Contexts.Corporation.Services.RecruitmentService
  alias EveDmv.Types

  # ===========================================================================
  # Corporation Analysis
  # ===========================================================================

  @spec analyze_corporation(Types.corporation_id(), Types.opts()) :: Types.result(map())
  defdelegate analyze_corporation(corporation_id, opts \\ []), to: CorporationAnalyzer

  @spec get_corporation_stats(Types.corporation_id()) :: Types.result(map())
  defdelegate get_corporation_stats(corporation_id), to: CorporationAnalyzer

  @spec get_corporation_profile(Types.corporation_id()) :: Types.result(map())
  defdelegate get_corporation_profile(corporation_id), to: CorporationAnalyzer

  @spec calculate_corporation_threat_level(Types.corporation_id()) ::
          Types.result(Types.threat_level())
  defdelegate calculate_corporation_threat_level(corporation_id), to: CorporationAnalyzer

  # ===========================================================================
  # Member Activity Analysis
  # ===========================================================================

  @spec analyze_member_activity(Types.corporation_id(), Types.opts()) :: Types.result(map())
  defdelegate analyze_member_activity(corporation_id, opts \\ []), to: MemberActivityAnalyzer

  @spec get_member_activity_summary(Types.corporation_id()) :: Types.result(map())
  defdelegate get_member_activity_summary(corporation_id), to: MemberActivityAnalyzer

  @spec get_member_participation_rates(Types.corporation_id()) :: Types.result(map())
  defdelegate get_member_participation_rates(corporation_id), to: MemberActivityAnalyzer

  @spec analyze_member_trends(Types.corporation_id(), Types.time_range()) :: Types.result(map())
  defdelegate analyze_member_trends(corporation_id, time_period), to: MemberActivityAnalyzer

  @spec get_inactive_members(Types.corporation_id(), pos_integer()) :: Types.result([map()])
  defdelegate get_inactive_members(corporation_id, threshold \\ 30), to: ParticipationAnalyzer

  @spec get_top_performers(Types.corporation_id(), pos_integer()) :: Types.result([map()])
  defdelegate get_top_performers(corporation_id, limit \\ 10), to: ParticipationAnalyzer

  # ===========================================================================
  # Member Risk Assessment
  # ===========================================================================

  @spec assess_member_risks(Types.corporation_id()) :: Types.result(map())
  defdelegate assess_member_risks(corporation_id), to: MemberRiskAssessment

  @spec identify_flight_risks(Types.corporation_id()) :: Types.result([map()])
  defdelegate identify_flight_risks(corporation_id), to: MemberRiskAssessment

  @spec assess_new_member_integration(Types.corporation_id()) :: Types.result(map())
  defdelegate assess_new_member_integration(corporation_id), to: MemberRiskAssessment

  @spec calculate_member_retention_score(Types.corporation_id()) :: Types.result(float())
  defdelegate calculate_member_retention_score(corporation_id), to: MemberRiskAssessment

  # ===========================================================================
  # Participation Analysis
  # ===========================================================================

  @spec analyze_participation(Types.corporation_id(), Types.opts()) :: Types.result(map())
  defdelegate analyze_participation(corporation_id, opts \\ []), to: ParticipationAnalyzer

  @spec get_fleet_participation_rates(Types.corporation_id()) :: Types.result(map())
  defdelegate get_fleet_participation_rates(corporation_id), to: ParticipationAnalyzer

  @spec analyze_timezone_coverage(Types.corporation_id()) :: Types.result(map())
  defdelegate analyze_timezone_coverage(corporation_id), to: ParticipationAnalyzer

  @spec get_participation_trends(Types.corporation_id(), Types.time_range()) ::
          Types.result(map())
  defdelegate get_participation_trends(corporation_id, time_period), to: ParticipationAnalyzer

  # ===========================================================================
  # Recruitment Analysis
  # ===========================================================================

  @spec analyze_recruitment_pipeline(Types.corporation_id()) :: Types.result(map())
  defdelegate analyze_recruitment_pipeline(corporation_id), to: RecruitmentAnalyzer

  @spec get_recruitment_metrics(Types.corporation_id()) :: Types.result(map())
  defdelegate get_recruitment_metrics(corporation_id), to: RecruitmentAnalyzer

  @spec assess_recruitment_effectiveness(Types.corporation_id()) :: Types.result(map())
  defdelegate assess_recruitment_effectiveness(corporation_id), to: RecruitmentAnalyzer

  @spec identify_recruitment_opportunities(Types.corporation_id()) :: Types.result([map()])
  defdelegate identify_recruitment_opportunities(corporation_id), to: RecruitmentAnalyzer

  @spec analyze_member_retention(Types.corporation_id(), Types.time_range()) ::
          Types.result(map())
  defdelegate analyze_member_retention(corporation_id, cohort_period), to: RecruitmentAnalyzer

  # ===========================================================================
  # Combat Doctrine Analysis
  # ===========================================================================

  @spec analyze_combat_doctrine(Types.corporation_id()) :: Types.result(map())
  defdelegate analyze_combat_doctrine(corporation_id), to: CombatDoctrineAnalyzer

  @spec get_fleet_compositions(Types.corporation_id()) :: Types.result([map()])
  defdelegate get_fleet_compositions(corporation_id), to: CombatDoctrineAnalyzer

  @spec analyze_ship_usage_patterns(Types.corporation_id()) :: Types.result(map())
  defdelegate analyze_ship_usage_patterns(corporation_id), to: CombatDoctrineAnalyzer

  @spec assess_doctrine_compliance(Types.corporation_id()) :: Types.result(map())
  defdelegate assess_doctrine_compliance(corporation_id), to: CombatDoctrineAnalyzer

  # ===========================================================================
  # Organizational Health
  # ===========================================================================

  @spec assess_organizational_health(Types.corporation_id()) :: Types.result(map())
  defdelegate assess_organizational_health(corporation_id), to: OrganizationalHealthAnalyzer

  @spec get_health_metrics(Types.corporation_id()) :: Types.result(map())
  defdelegate get_health_metrics(corporation_id), to: OrganizationalHealthAnalyzer

  @spec identify_organizational_issues(Types.corporation_id()) :: Types.result([map()])
  defdelegate identify_organizational_issues(corporation_id), to: OrganizationalHealthAnalyzer

  @spec get_leadership_effectiveness(Types.corporation_id()) :: Types.result(map())
  defdelegate get_leadership_effectiveness(corporation_id), to: OrganizationalHealthAnalyzer

  # ===========================================================================
  # Corporation Services
  # ===========================================================================

  @spec create_corporation_profile(map()) :: Types.result(map())
  defdelegate create_corporation_profile(corporation_data), to: CorporationService

  @spec update_corporation_data(Types.corporation_id(), map()) :: Types.result(map())
  defdelegate update_corporation_data(corporation_id, data), to: CorporationService

  @spec get_corporation(Types.corporation_id()) :: Types.result(map())
  defdelegate get_corporation(corporation_id), to: CorporationService

  @spec search_corporations(map()) :: Types.result([map()])
  defdelegate search_corporations(search_params), to: CorporationService

  # ===========================================================================
  # Member Management
  # ===========================================================================

  @spec add_member(Types.corporation_id(), map()) :: Types.result(map())
  defdelegate add_member(corporation_id, member_data), to: MemberService

  @spec update_member(Types.character_id(), map()) :: Types.result(map())
  defdelegate update_member(member_id, data), to: MemberService

  @spec remove_member(Types.character_id()) :: Types.void_result()
  defdelegate remove_member(member_id), to: MemberService

  @spec get_member_list(Types.corporation_id(), Types.opts()) :: Types.result([map()])
  defdelegate get_member_list(corporation_id, opts \\ []), to: MemberService

  @spec get_member_details(Types.character_id()) :: Types.result(map())
  defdelegate get_member_details(member_id), to: MemberService

  # ===========================================================================
  # Analytics Services
  # ===========================================================================

  @spec generate_corporation_report(Types.corporation_id(), atom()) :: Types.result(map())
  defdelegate generate_corporation_report(corporation_id, report_type), to: AnalyticsService

  @spec export_analytics(Types.corporation_id(), atom()) :: Types.result(binary())
  defdelegate export_analytics(corporation_id, format), to: AnalyticsService

  @spec get_comparative_analysis([Types.corporation_id()]) :: Types.result(map())
  defdelegate get_comparative_analysis(corporation_ids), to: AnalyticsService

  @spec track_performance_metrics(Types.corporation_id(), map()) :: Types.result(map())
  defdelegate track_performance_metrics(corporation_id, metrics), to: AnalyticsService

  # ===========================================================================
  # Recruitment Services
  # ===========================================================================

  @spec manage_recruitment_pipeline(Types.corporation_id(), [map()]) :: Types.result(map())
  defdelegate manage_recruitment_pipeline(corporation_id, actions), to: RecruitmentService

  @spec process_applications(Types.corporation_id(), [pos_integer()]) :: Types.result(map())
  defdelegate process_applications(corporation_id, application_ids), to: RecruitmentService

  @spec generate_recruitment_insights(Types.corporation_id()) :: Types.result(map())
  defdelegate generate_recruitment_insights(corporation_id), to: RecruitmentService

  @spec optimize_recruitment_strategy(Types.corporation_id()) :: Types.result(map())
  defdelegate optimize_recruitment_strategy(corporation_id), to: RecruitmentService

  # ===========================================================================
  # Batch Operations
  # ===========================================================================

  @spec analyze_corporations([Types.corporation_id()], Types.opts()) :: Types.result([map()])
  defdelegate analyze_corporations(corporation_ids, opts \\ []),
    to: CorporationAnalyzer,
    as: :analyze_batch

  @spec assess_member_risks_batch([Types.corporation_id()]) :: Types.result([map()])
  defdelegate assess_member_risks_batch(corporation_ids),
    to: MemberRiskAssessment,
    as: :assess_batch

  # ===========================================================================
  # Cache Management
  # ===========================================================================

  @spec refresh_corporation_cache(Types.corporation_id()) :: Types.void_result()
  defdelegate refresh_corporation_cache(corporation_id), to: CorporationService

  @spec clear_corporation_cache(Types.corporation_id()) :: Types.void_result()
  defdelegate clear_corporation_cache(corporation_id), to: CorporationService

  # ===========================================================================
  # Real-time Updates
  # ===========================================================================

  @spec subscribe_to_corporation_updates(Types.corporation_id()) :: Types.void_result()
  defdelegate subscribe_to_corporation_updates(corporation_id), to: CorporationService

  @spec unsubscribe_from_corporation_updates(Types.corporation_id()) :: Types.void_result()
  defdelegate unsubscribe_from_corporation_updates(corporation_id), to: CorporationService

  # ===========================================================================
  # Intelligence Integration
  # ===========================================================================

  @spec get_member_intelligence_summary(Types.corporation_id()) :: Types.result(map())
  defdelegate get_member_intelligence_summary(corporation_id), to: CorporationAnalyzer

  @spec assess_corporation_threats(Types.corporation_id()) :: Types.result(map())
  defdelegate assess_corporation_threats(corporation_id), to: CorporationAnalyzer

  @spec analyze_enemy_corporations([Types.corporation_id()]) :: Types.result([map()])
  defdelegate analyze_enemy_corporations(corporation_ids), to: CorporationAnalyzer
end
