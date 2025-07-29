defmodule EveDmv.Contexts.Corporation.Api do
  @moduledoc """
  Public API for the Corporation context.
  
  This module provides the unified interface for all corporation analysis and
  intelligence functionality, including member activity analysis, recruitment
  insights, and organizational health metrics.
  """
  
  alias EveDmv.Contexts.Corporation.Core.{
    CorporationAnalyzer,
    MemberActivityAnalyzer,
    MemberRiskAssessment,
    ParticipationAnalyzer,
    RecruitmentAnalyzer,
    CombatDoctrineAnalyzer,
    OrganizationalHealthAnalyzer
  }
  
  alias EveDmv.Contexts.Corporation.Services.{
    CorporationService,
    MemberService,
    AnalyticsService,
    RecruitmentService
  }
  
  # Corporation Analysis
  defdelegate analyze_corporation(corporation_id, opts \\ []), to: CorporationAnalyzer
  defdelegate get_corporation_stats(corporation_id), to: CorporationAnalyzer
  defdelegate get_corporation_profile(corporation_id), to: CorporationAnalyzer
  defdelegate calculate_corporation_threat_level(corporation_id), to: CorporationAnalyzer
  
  # Member Activity Analysis
  defdelegate analyze_member_activity(corporation_id, opts \\ []), to: MemberActivityAnalyzer
  defdelegate get_member_activity_summary(corporation_id), to: MemberActivityAnalyzer
  defdelegate get_member_participation_rates(corporation_id), to: MemberActivityAnalyzer
  defdelegate analyze_member_trends(corporation_id, time_period), to: MemberActivityAnalyzer
  defdelegate get_inactive_members(corporation_id, threshold), to: MemberActivityAnalyzer
  defdelegate get_top_performers(corporation_id, limit \\ 10), to: MemberActivityAnalyzer
  
  # Member Risk Assessment
  defdelegate assess_member_risks(corporation_id), to: MemberRiskAssessment
  defdelegate identify_flight_risks(corporation_id), to: MemberRiskAssessment
  defdelegate assess_new_member_integration(corporation_id), to: MemberRiskAssessment
  defdelegate calculate_member_retention_score(corporation_id), to: MemberRiskAssessment
  
  # Participation Analysis
  defdelegate analyze_participation(corporation_id, opts \\ []), to: ParticipationAnalyzer
  defdelegate get_fleet_participation_rates(corporation_id), to: ParticipationAnalyzer
  defdelegate analyze_timezone_coverage(corporation_id), to: ParticipationAnalyzer
  defdelegate get_participation_trends(corporation_id, time_period), to: ParticipationAnalyzer
  
  # Recruitment Analysis
  defdelegate analyze_recruitment_pipeline(corporation_id), to: RecruitmentAnalyzer
  defdelegate get_recruitment_metrics(corporation_id), to: RecruitmentAnalyzer
  defdelegate assess_recruitment_effectiveness(corporation_id), to: RecruitmentAnalyzer
  defdelegate identify_recruitment_opportunities(corporation_id), to: RecruitmentAnalyzer
  defdelegate analyze_member_retention(corporation_id, cohort_period), to: RecruitmentAnalyzer
  
  # Combat Doctrine Analysis
  defdelegate analyze_combat_doctrine(corporation_id), to: CombatDoctrineAnalyzer
  defdelegate get_fleet_compositions(corporation_id), to: CombatDoctrineAnalyzer
  defdelegate analyze_ship_usage_patterns(corporation_id), to: CombatDoctrineAnalyzer
  defdelegate assess_doctrine_compliance(corporation_id), to: CombatDoctrineAnalyzer
  
  # Organizational Health
  defdelegate assess_organizational_health(corporation_id), to: OrganizationalHealthAnalyzer
  defdelegate get_health_metrics(corporation_id), to: OrganizationalHealthAnalyzer
  defdelegate identify_organizational_issues(corporation_id), to: OrganizationalHealthAnalyzer
  defdelegate get_leadership_effectiveness(corporation_id), to: OrganizationalHealthAnalyzer
  
  # Corporation Services
  defdelegate create_corporation_profile(corporation_data), to: CorporationService
  defdelegate update_corporation_data(corporation_id, data), to: CorporationService
  defdelegate get_corporation(corporation_id), to: CorporationService
  defdelegate search_corporations(search_params), to: CorporationService
  
  # Member Management
  defdelegate add_member(corporation_id, member_data), to: MemberService
  defdelegate update_member(member_id, data), to: MemberService
  defdelegate remove_member(member_id), to: MemberService
  defdelegate get_member_list(corporation_id, opts \\ []), to: MemberService
  defdelegate get_member_details(member_id), to: MemberService
  
  # Analytics Services
  defdelegate generate_corporation_report(corporation_id, report_type), to: AnalyticsService
  defdelegate export_analytics(corporation_id, format), to: AnalyticsService
  defdelegate get_comparative_analysis(corporation_ids), to: AnalyticsService
  defdelegate track_performance_metrics(corporation_id, metrics), to: AnalyticsService
  
  # Recruitment Services
  defdelegate manage_recruitment_pipeline(corporation_id, actions), to: RecruitmentService
  defdelegate process_applications(corporation_id, application_ids), to: RecruitmentService
  defdelegate generate_recruitment_insights(corporation_id), to: RecruitmentService
  defdelegate optimize_recruitment_strategy(corporation_id), to: RecruitmentService
  
  # Batch Operations
  defdelegate analyze_corporations(corporation_ids, opts \\ []), to: CorporationAnalyzer, as: :analyze_batch
  defdelegate assess_member_risks_batch(corporation_ids), to: MemberRiskAssessment, as: :assess_batch
  
  # Cache Management
  defdelegate refresh_corporation_cache(corporation_id), to: CorporationService
  defdelegate clear_corporation_cache(corporation_id), to: CorporationService
  
  # Real-time Updates
  defdelegate subscribe_to_corporation_updates(corporation_id), to: CorporationService
  defdelegate unsubscribe_from_corporation_updates(corporation_id), to: CorporationService
  
  # Intelligence Integration
  defdelegate get_member_intelligence_summary(corporation_id), to: CorporationAnalyzer
  defdelegate assess_corporation_threats(corporation_id), to: CorporationAnalyzer
  defdelegate analyze_enemy_corporations(corporation_ids), to: CorporationAnalyzer
end