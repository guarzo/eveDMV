defmodule EveDmv.Contexts.Combat.Api do
  @moduledoc """
  Public API for the Combat context.

  This module provides the unified interface for all combat-related functionality,
  including battle detection, analysis, timeline reconstruction, and tactical insights.
  """

  alias EveDmv.Types

  alias EveDmv.Contexts.BattleAnalysis.Core.BattleDetector
  alias EveDmv.Contexts.BattleAnalysis.Core.OptimizedBattleAnalyzer
  alias EveDmv.Contexts.Combat.Core.FleetCompositionAnalyzer
  alias EveDmv.Contexts.Combat.Core.ParticipantAnalyzer
  alias EveDmv.Contexts.Combat.Core.PerformanceCalculator
  alias EveDmv.Contexts.Combat.Core.TacticalPatternDetector
  alias EveDmv.Contexts.Combat.Core.TimelineBuilder
  alias EveDmv.Contexts.Combat.Services.BattleService
  alias EveDmv.Contexts.Combat.Services.BattleSharingService
  alias EveDmv.Contexts.Combat.Services.CombatLogParser
  alias EveDmv.Contexts.Combat.Services.ZkillboardImporter

  # Battle Detection

  @doc "Detect battles from a list of killmails using clustering algorithm."
  @spec detect_battles([map()], Types.opts()) :: Types.result([map()])
  defdelegate detect_battles(killmails, opts \\ []), to: BattleDetector

  @doc "Detect battles within a specific time range."
  @spec detect_battles_in_timeframe(DateTime.t(), DateTime.t(), Types.opts()) ::
          Types.result([map()])
  defdelegate detect_battles_in_timeframe(start_time, end_time, opts \\ []), to: BattleDetector

  # Battle Analysis

  @doc "Perform comprehensive analysis of a battle."
  @spec analyze_battle(Types.battle_id()) :: Types.analysis_result()
  defdelegate analyze_battle(battle_id), to: OptimizedBattleAnalyzer

  @doc "Get metrics for a specific battle."
  @spec get_battle_metrics(Types.battle_id()) :: Types.analysis_result()
  defdelegate get_battle_metrics(battle_id), to: OptimizedBattleAnalyzer

  @doc "Get a summary of a specific battle."
  @spec get_battle_summary(Types.battle_id()) :: Types.analysis_result()
  defdelegate get_battle_summary(battle_id), to: OptimizedBattleAnalyzer

  # Timeline

  @doc "Build a timeline of events for a battle."
  @spec build_battle_timeline(Types.battle_id()) :: Types.analysis_result()
  defdelegate build_battle_timeline(battle_id), to: TimelineBuilder

  @doc "Get the distinct phases of a battle."
  @spec get_battle_phases(Types.battle_id()) :: Types.result([map()])
  defdelegate get_battle_phases(battle_id), to: TimelineBuilder

  # Participants

  @doc "Analyze all participants from a list of killmails."
  @spec analyze_participants([map()]) :: Types.analysis_result()
  defdelegate analyze_participants(killmails), to: ParticipantAnalyzer

  @doc "Get performance metrics for a specific participant in a set of killmails."
  @spec get_participant_performance([map()], Types.character_id()) :: Types.analysis_result()
  defdelegate get_participant_performance(killmails, character_id), to: ParticipantAnalyzer

  @doc "Get role assignments for participants in a set of killmails."
  @spec get_participant_roles([map()]) :: Types.analysis_result()
  defdelegate get_participant_roles(killmails), to: ParticipantAnalyzer

  # Fleet Analysis

  @doc "Analyze fleet composition from killmails."
  @spec analyze_composition([map()]) :: Types.analysis_result()
  defdelegate analyze_composition(killmails), to: FleetCompositionAnalyzer

  @doc "Calculate fleet effectiveness metrics for a specific side."
  @spec get_fleet_effectiveness([map()], Types.fleet_side()) :: Types.analysis_result()
  defdelegate get_fleet_effectiveness(killmails, side), to: FleetCompositionAnalyzer

  @doc "Compare relative strengths between opposing fleets."
  @spec compare_fleet_strengths([map()]) :: Types.analysis_result()
  defdelegate compare_fleet_strengths(killmails), to: FleetCompositionAnalyzer

  # Tactical Analysis

  @doc "Detect tactical patterns from killmails and timeline."
  @spec detect_patterns([map()], map()) :: Types.analysis_result()
  defdelegate detect_patterns(killmails, timeline), to: TacticalPatternDetector

  @doc "Analyze engagement tactics used in combat."
  @spec analyze_engagement_tactics([map()]) :: Types.analysis_result()
  defdelegate analyze_engagement_tactics(killmails), to: TacticalPatternDetector

  # Performance Metrics

  @doc "Calculate comprehensive performance metrics from killmails."
  @spec calculate_performance_metrics([map()]) :: Types.analysis_result()
  defdelegate calculate_performance_metrics(killmails), to: PerformanceCalculator

  @doc "Get performance metrics for a specific ship type in a set of killmails."
  @spec get_ship_performance([map()], Types.ship_id()) :: Types.analysis_result()
  defdelegate get_ship_performance(killmails, ship_id), to: PerformanceCalculator

  # Services

  @doc "Import battle data from a zKillboard URL."
  @spec import_from_zkillboard(String.t()) :: Types.analysis_result()
  defdelegate import_from_zkillboard(battle_url), to: ZkillboardImporter

  @doc "Parse combat log data into structured format."
  @spec parse_combat_log(String.t()) :: Types.analysis_result()
  defdelegate parse_combat_log(log_data), to: CombatLogParser

  @doc "Create a shareable battle report."
  @spec share_battle(Types.battle_id(), map()) :: Types.analysis_result()
  defdelegate share_battle(battle_id, sharing_options), to: BattleSharingService

  # Battle Management

  @doc "Create a new battle record."
  @spec create_battle(map()) :: Types.result(map())
  defdelegate create_battle(params), to: BattleService

  @doc "Update an existing battle record."
  @spec update_battle(Types.battle_id(), map()) :: Types.result(map())
  defdelegate update_battle(battle_id, params), to: BattleService

  @doc "Get a battle by ID."
  @spec get_battle(Types.battle_id()) :: Types.result(map())
  defdelegate get_battle(battle_id), to: BattleService

  @doc "List battles with optional filters."
  @spec list_battles(Types.opts()) :: Types.result([map()])
  defdelegate list_battles(filters \\ []), to: BattleService

  @doc "Delete a battle by ID."
  @spec delete_battle(Types.battle_id()) :: Types.void_result()
  defdelegate delete_battle(battle_id), to: BattleService
end
