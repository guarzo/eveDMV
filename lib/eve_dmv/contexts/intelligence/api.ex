defmodule EveDmv.Contexts.Intelligence.Api do
  @moduledoc """
  Public API for the Intelligence context.

  This module provides the unified interface for all character intelligence and
  player profiling functionality, including threat assessment, behavioral analysis,
  and performance metrics.
  """
  """

  alias EveDmv.Contexts.Intelligence.Core.BehavioralPatternAnalyzer
  alias EveDmv.Contexts.Intelligence.Core.CharacterAnalyzer
  alias EveDmv.Contexts.Intelligence.Core.CombatStatsAnalyzer
  alias EveDmv.Contexts.Intelligence.Core.PerformanceAnalyzer
  alias EveDmv.Contexts.Intelligence.Core.ShipPreferenceAnalyzer
  alias EveDmv.Contexts.Intelligence.Core.ThreatAssessmentEngine
  alias EveDmv.Contexts.Intelligence.Core.ThreatScoringCoordinator
  alias EveDmv.Contexts.Intelligence.Services.CharacterService
  alias EveDmv.Contexts.Intelligence.Services.ComparisonService
  alias EveDmv.Contexts.Intelligence.Services.InsightGenerator
  alias EveDmv.Contexts.Intelligence.Services.ProfileService

  # Threat Assessment
  defdelegate assess_threat(character_id, opts \\ []), to: ThreatAssessmentEngine
  defdelegate get_threat_score(character_id), to: ThreatAssessmentEngine
  defdelegate calculate_danger_rating(character_id), to: ThreatAssessmentEngine
  defdelegate get_threat_breakdown(character_id), to: ThreatAssessmentEngine

  # Character Analysis
  defdelegate analyze_character(character_id, opts \\ []), to: CharacterAnalyzer
  defdelegate get_character_stats(character_id), to: CharacterAnalyzer
  defdelegate get_character_profile(character_id), to: CharacterAnalyzer
  defdelegate classify_pilot_type(character_id), to: CharacterAnalyzer

  # Combat Statistics
  defdelegate analyze_combat_stats(character_id, opts \\ []), to: CombatStatsAnalyzer
  defdelegate get_kill_death_ratio(character_id), to: CombatStatsAnalyzer
  defdelegate get_isk_efficiency(character_id), to: CombatStatsAnalyzer
  defdelegate get_weapon_preferences(character_id), to: CombatStatsAnalyzer
  defdelegate get_engagement_patterns(character_id), to: CombatStatsAnalyzer

  # Ship Preferences
  defdelegate analyze_ship_preferences(character_id), to: ShipPreferenceAnalyzer
  defdelegate get_favorite_ships(character_id, limit \\ 10), to: ShipPreferenceAnalyzer
  defdelegate get_ship_progression(character_id), to: ShipPreferenceAnalyzer
  defdelegate get_fitting_patterns(character_id), to: ShipPreferenceAnalyzer

  # Performance Analysis
  defdelegate analyze_performance(character_id, opts \\ []), to: PerformanceAnalyzer
  defdelegate get_performance_metrics(character_id), to: PerformanceAnalyzer
  defdelegate get_peer_comparison(character_id, peer_group), to: PerformanceAnalyzer
  defdelegate get_performance_trends(character_id, time_period), to: PerformanceAnalyzer

  # Behavioral Patterns
  defdelegate analyze_behavior(character_id), to: BehavioralPatternAnalyzer
  defdelegate get_activity_patterns(character_id), to: BehavioralPatternAnalyzer
  defdelegate get_timezone_estimate(character_id), to: BehavioralPatternAnalyzer
  defdelegate get_gang_preferences(character_id), to: BehavioralPatternAnalyzer
  defdelegate get_geographic_preferences(character_id), to: BehavioralPatternAnalyzer

  # Threat Scoring Coordination
  defdelegate coordinate_threat_analysis(character_ids, opts \\ []), to: ThreatScoringCoordinator
  defdelegate get_threat_comparison(character_ids), to: ThreatScoringCoordinator
  defdelegate get_gang_threat_assessment(character_ids), to: ThreatScoringCoordinator

  # Services
  defdelegate create_character_profile(character_data), to: CharacterService
  defdelegate update_character_stats(character_id, stats), to: CharacterService
  defdelegate get_character(character_id), to: CharacterService
  defdelegate search_characters(search_params), to: CharacterService

  # Comparison Services
  defdelegate compare_characters(character_ids, aspects \\ :all), to: ComparisonService
  defdelegate find_similar_characters(character_id, opts \\ []), to: ComparisonService
  defdelegate rank_characters(character_ids, metric), to: ComparisonService

  # Profile Services
  defdelegate generate_full_profile(character_id), to: ProfileService
  defdelegate export_profile(character_id, format \\ :json), to: ProfileService
  defdelegate share_profile(character_id, sharing_options), to: ProfileService

  # Insights
  defdelegate generate_insights(character_id), to: InsightGenerator
  defdelegate get_threat_mitigation_strategies(character_id), to: InsightGenerator
  defdelegate get_engagement_recommendations(attacker_id, target_id), to: InsightGenerator

  # Batch Operations
  defdelegate analyze_characters(character_ids, opts \\ []),
    to: CharacterAnalyzer,
    as: :analyze_batch

  defdelegate assess_threats(character_ids, opts \\ []),
    to: ThreatAssessmentEngine,
    as: :assess_batch

  # Cache Management
  defdelegate refresh_character_cache(character_id), to: CharacterService
  defdelegate clear_character_cache(character_id), to: CharacterService

  # Real-time Updates
  defdelegate subscribe_to_character_updates(character_id), to: CharacterService
  defdelegate unsubscribe_from_character_updates(character_id), to: CharacterService
end
