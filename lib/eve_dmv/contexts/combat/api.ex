defmodule EveDmv.Contexts.Combat.Api do
  @moduledoc """
  Public API for the Combat context.

  This module provides the unified interface for all combat-related functionality,
  including battle detection, analysis, timeline reconstruction, and tactical insights.
  """

  alias EveDmv.Contexts.BattleAnalysis.Core.BattleDetector
  alias EveDmv.Contexts.Combat.Core.BattleAnalyzer
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
  defdelegate detect_battles(killmails, opts \\ []), to: BattleDetector
  defdelegate detect_battles_in_timeframe(start_time, end_time, opts \\ []), to: BattleDetector

  # Battle Analysis
  defdelegate analyze_battle(battle_id), to: BattleAnalyzer
  defdelegate get_battle_metrics(battle_id), to: BattleAnalyzer
  defdelegate get_battle_summary(battle_id), to: BattleAnalyzer

  # Timeline
  defdelegate build_battle_timeline(battle_id), to: TimelineBuilder
  defdelegate get_battle_phases(battle_id), to: TimelineBuilder

  # Participants
  defdelegate analyze_participants(battle_id), to: ParticipantAnalyzer
  defdelegate get_participant_performance(battle_id, character_id), to: ParticipantAnalyzer
  defdelegate get_participant_roles(battle_id), to: ParticipantAnalyzer

  # Fleet Analysis
  defdelegate analyze_composition(killmails), to: FleetCompositionAnalyzer
  defdelegate get_fleet_effectiveness(killmails, side), to: FleetCompositionAnalyzer
  defdelegate compare_fleet_strengths(killmails), to: FleetCompositionAnalyzer

  # Tactical Analysis
  defdelegate detect_patterns(killmails, timeline), to: TacticalPatternDetector
  defdelegate analyze_engagement_tactics(killmails), to: TacticalPatternDetector

  # Performance Metrics
  defdelegate calculate_performance_metrics(battle_id), to: PerformanceCalculator
  defdelegate get_ship_performance(battle_id, ship_id), to: PerformanceCalculator

  # Services
  defdelegate import_from_zkillboard(battle_url), to: ZkillboardImporter
  defdelegate parse_combat_log(log_data), to: CombatLogParser
  defdelegate share_battle(battle_id, sharing_options), to: BattleSharingService

  # Battle Management
  defdelegate create_battle(params), to: BattleService
  defdelegate update_battle(battle_id, params), to: BattleService
  defdelegate get_battle(battle_id), to: BattleService
  defdelegate list_battles(filters \\ []), to: BattleService
  defdelegate delete_battle(battle_id), to: BattleService
end
