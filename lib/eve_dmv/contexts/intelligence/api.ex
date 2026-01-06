defmodule EveDmv.Contexts.Intelligence.Api do
  @moduledoc """
  **DEPRECATED**: This module is being consolidated into `EveDmv.Contexts.CharacterIntelligence`.

  Please use `EveDmv.Contexts.CharacterIntelligence` for new code.

  ---

  Public API for the Intelligence context.

  This module provides the unified interface for all character intelligence and
  player profiling functionality, including threat assessment, behavioral analysis,
  and performance metrics.
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
  alias EveDmv.Types

  # ===========================================================================
  # Threat Assessment
  # ===========================================================================

  @spec assess_threat(Types.character_id(), Types.opts()) ::
          Types.result(Types.threat_assessment())
  defdelegate assess_threat(character_id, opts \\ []), to: ThreatAssessmentEngine

  @spec get_threat_score(Types.character_id()) :: Types.result(float())
  defdelegate get_threat_score(character_id), to: ThreatAssessmentEngine

  @spec calculate_danger_rating(Types.character_id()) :: Types.result(Types.threat_level())
  defdelegate calculate_danger_rating(character_id), to: ThreatAssessmentEngine

  @spec get_threat_breakdown(Types.character_id()) :: Types.result(map())
  defdelegate get_threat_breakdown(character_id), to: ThreatAssessmentEngine

  # ===========================================================================
  # Character Analysis
  # ===========================================================================

  @spec analyze_character(Types.character_id(), Types.opts()) :: Types.result(map())
  defdelegate analyze_character(character_id, opts \\ []), to: CharacterAnalyzer

  @spec get_character_stats(Types.character_id()) :: Types.result(Types.combat_stats())
  defdelegate get_character_stats(character_id), to: CharacterAnalyzer

  @spec get_character_profile(Types.character_id()) :: Types.result(map())
  defdelegate get_character_profile(character_id), to: CharacterAnalyzer

  @spec classify_pilot_type(Types.character_id()) :: Types.result(atom())
  defdelegate classify_pilot_type(character_id), to: CharacterAnalyzer

  # ===========================================================================
  # Combat Statistics
  # ===========================================================================

  @spec analyze_combat_stats(Types.character_id(), Types.opts()) :: Types.result(map())
  defdelegate analyze_combat_stats(character_id, opts \\ []), to: CombatStatsAnalyzer

  @spec get_kill_death_ratio(Types.character_id()) :: Types.result(float())
  defdelegate get_kill_death_ratio(character_id), to: CombatStatsAnalyzer

  @spec get_isk_efficiency(Types.character_id()) :: Types.result(float())
  defdelegate get_isk_efficiency(character_id), to: CombatStatsAnalyzer

  @spec get_weapon_preferences(Types.character_id()) :: Types.result([map()])
  defdelegate get_weapon_preferences(character_id), to: CombatStatsAnalyzer

  @spec get_engagement_patterns(Types.character_id()) :: Types.result(map())
  defdelegate get_engagement_patterns(character_id), to: CombatStatsAnalyzer

  # ===========================================================================
  # Ship Preferences
  # ===========================================================================

  @spec analyze_ship_preferences(Types.character_id()) :: Types.result(map())
  defdelegate analyze_ship_preferences(character_id), to: ShipPreferenceAnalyzer

  @spec get_favorite_ships(Types.character_id(), pos_integer()) :: Types.result([map()])
  defdelegate get_favorite_ships(character_id, limit \\ 10), to: ShipPreferenceAnalyzer

  @spec get_ship_progression(Types.character_id()) :: Types.result(map())
  defdelegate get_ship_progression(character_id), to: ShipPreferenceAnalyzer

  @spec get_fitting_patterns(Types.character_id()) :: Types.result([map()])
  defdelegate get_fitting_patterns(character_id), to: ShipPreferenceAnalyzer

  # ===========================================================================
  # Performance Analysis
  # ===========================================================================

  @spec analyze_performance(Types.character_id(), Types.opts()) :: Types.result(map())
  defdelegate analyze_performance(character_id, opts \\ []), to: PerformanceAnalyzer

  @spec get_performance_metrics(Types.character_id()) :: Types.result(map())
  defdelegate get_performance_metrics(character_id), to: PerformanceAnalyzer

  @spec get_peer_comparison(Types.character_id(), atom()) :: Types.result(map())
  defdelegate get_peer_comparison(character_id, peer_group), to: PerformanceAnalyzer

  @spec get_performance_trends(Types.character_id(), Types.time_range()) :: Types.result(map())
  defdelegate get_performance_trends(character_id, time_period), to: PerformanceAnalyzer

  # ===========================================================================
  # Behavioral Patterns
  # ===========================================================================

  @spec analyze_behavior(Types.character_id()) :: Types.result(map())
  defdelegate analyze_behavior(character_id), to: BehavioralPatternAnalyzer

  @spec get_activity_patterns(Types.character_id()) :: Types.result(map())
  defdelegate get_activity_patterns(character_id), to: BehavioralPatternAnalyzer

  @spec get_timezone_estimate(Types.character_id()) :: Types.result(String.t())
  defdelegate get_timezone_estimate(character_id), to: BehavioralPatternAnalyzer

  @spec get_gang_preferences(Types.character_id()) :: Types.result(map())
  defdelegate get_gang_preferences(character_id), to: BehavioralPatternAnalyzer

  @spec get_geographic_preferences(Types.character_id()) :: Types.result(map())
  defdelegate get_geographic_preferences(character_id), to: BehavioralPatternAnalyzer

  # ===========================================================================
  # Threat Scoring Coordination
  # ===========================================================================

  @spec coordinate_threat_analysis([Types.character_id()], Types.opts()) :: Types.result([map()])
  defdelegate coordinate_threat_analysis(character_ids, opts \\ []), to: ThreatScoringCoordinator

  @spec get_threat_comparison([Types.character_id()]) :: Types.result(map())
  defdelegate get_threat_comparison(character_ids), to: ThreatScoringCoordinator

  @spec get_gang_threat_assessment([Types.character_id()]) :: Types.result(map())
  defdelegate get_gang_threat_assessment(character_ids), to: ThreatScoringCoordinator

  # ===========================================================================
  # Character Services
  # ===========================================================================

  @spec create_character_profile(map()) :: Types.result(map())
  defdelegate create_character_profile(character_data), to: CharacterService

  @spec update_character_stats(Types.character_id(), map()) :: Types.result(map())
  defdelegate update_character_stats(character_id, stats), to: CharacterService

  @spec get_character(Types.character_id()) :: Types.result(map())
  defdelegate get_character(character_id), to: CharacterService

  @spec search_characters(map()) :: Types.result([map()])
  defdelegate search_characters(search_params), to: CharacterService

  # ===========================================================================
  # Comparison Services
  # ===========================================================================

  @spec compare_characters([Types.character_id()], atom() | [atom()]) :: Types.result(map())
  defdelegate compare_characters(character_ids, aspects \\ :all), to: ComparisonService

  @spec find_similar_characters(Types.character_id(), Types.opts()) :: Types.result([map()])
  defdelegate find_similar_characters(character_id, opts \\ []), to: ComparisonService

  @spec rank_characters([Types.character_id()], atom()) :: Types.result([map()])
  defdelegate rank_characters(character_ids, metric), to: ComparisonService

  # ===========================================================================
  # Profile Services
  # ===========================================================================

  @spec generate_full_profile(Types.character_id()) :: Types.result(map())
  defdelegate generate_full_profile(character_id), to: ProfileService

  @spec export_profile(Types.character_id(), atom()) :: Types.result(binary())
  defdelegate export_profile(character_id, format \\ :json), to: ProfileService

  @spec share_profile(Types.character_id(), map()) :: Types.result(map())
  defdelegate share_profile(character_id, sharing_options), to: ProfileService

  # ===========================================================================
  # Insights
  # ===========================================================================

  @spec generate_insights(Types.character_id()) :: Types.result([String.t()])
  defdelegate generate_insights(character_id), to: InsightGenerator

  @spec get_threat_mitigation_strategies(Types.character_id()) :: Types.result([map()])
  defdelegate get_threat_mitigation_strategies(character_id), to: InsightGenerator

  @spec get_engagement_recommendations(Types.character_id(), Types.character_id()) ::
          Types.result(map())
  defdelegate get_engagement_recommendations(attacker_id, target_id), to: InsightGenerator

  # ===========================================================================
  # Batch Operations
  # ===========================================================================

  @spec analyze_characters([Types.character_id()], Types.opts()) :: Types.result([map()])
  defdelegate analyze_characters(character_ids, opts \\ []),
    to: CharacterAnalyzer,
    as: :analyze_batch

  @spec assess_threats([Types.character_id()], Types.opts()) ::
          Types.result([Types.threat_assessment()])
  defdelegate assess_threats(character_ids, opts \\ []),
    to: ThreatAssessmentEngine,
    as: :assess_batch

  # ===========================================================================
  # Cache Management
  # ===========================================================================

  @spec refresh_character_cache(Types.character_id()) :: Types.void_result()
  defdelegate refresh_character_cache(character_id), to: CharacterService

  @spec clear_character_cache(Types.character_id()) :: Types.void_result()
  defdelegate clear_character_cache(character_id), to: CharacterService

  # ===========================================================================
  # Real-time Updates
  # ===========================================================================

  @spec subscribe_to_character_updates(Types.character_id()) :: Types.void_result()
  defdelegate subscribe_to_character_updates(character_id), to: CharacterService

  @spec unsubscribe_from_character_updates(Types.character_id()) :: Types.void_result()
  defdelegate unsubscribe_from_character_updates(character_id), to: CharacterService
end
