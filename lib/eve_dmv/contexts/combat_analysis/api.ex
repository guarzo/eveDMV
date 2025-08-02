defmodule EveDmv.Contexts.CombatAnalysis.Api do
  @moduledoc """
  API module for the unified Combat Analysis context.

  Provides a clean interface for all combat analysis functionality
  including battle analysis, combat intelligence, and battle sharing.
  """
  """

  alias EveDmv.Contexts.CombatAnalysis

  ## Battle Analysis API

  @doc """
  Analyze a battle from killmail data.
  """
  defdelegate analyze_battle(battle_data, options \\ []), to: CombatAnalysis

  @doc """
  Get battle timeline and tactical phases.
  """
  defdelegate get_battle_timeline(battle_id), to: CombatAnalysis

  @doc """
  Analyze fleet composition and effectiveness.
  """
  defdelegate analyze_fleet_composition(participants), to: CombatAnalysis

  ## Combat Intelligence API

  @doc """
  Analyze character combat patterns and behavior.
  """
  defdelegate analyze_character_combat(character_id, options \\ []), to: CombatAnalysis

  @doc """
  Assess threat level for character or corporation.
  """
  defdelegate assess_threat(entity_id, entity_type, options \\ []), to: CombatAnalysis

  @doc """
  Get comprehensive combat intelligence summary.
  """
  defdelegate get_combat_intelligence(entity_id, options \\ []), to: CombatAnalysis

  ## Battle Sharing API

  @doc """
  Create a shareable battle report with video integration.
  """
  defdelegate create_battle_report(battle_id, creator_id, options \\ []), to: CombatAnalysis

  @doc """
  Rate a battle report (1-5 stars).
  """
  defdelegate rate_battle_report(report_id, user_id, rating), to: CombatAnalysis

  ## Cache and Monitoring API

  @doc """
  Get combat analysis cache statistics.
  """
  defdelegate get_cache_stats(), to: CombatAnalysis

  @doc """
  Clear combat analysis cache.
  """
  defdelegate clear_cache(), to: CombatAnalysis

  @doc """
  Perform health check on combat analysis services.
  """
  defdelegate health_check(), to: CombatAnalysis
end
