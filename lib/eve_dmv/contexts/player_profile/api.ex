defmodule EveDmv.Contexts.PlayerProfile.Api do
  @moduledoc """
  Public API for the Player Profile context.

  Provides player profiling capabilities including combat statistics,
  ship preferences, and behavioral analysis.

  Note: For comprehensive character analysis, prefer using
  `EveDmv.Contexts.Intelligence.Core.CharacterAnalyzer` which is the
  canonical character analysis module.
  """

  alias EveDmv.Contexts.PlayerProfile.Analyzers.CombatStatsAnalyzer
  alias EveDmv.Contexts.PlayerProfile.Analyzers.ShipPreferencesAnalyzer
  alias EveDmv.Contexts.PlayerProfile.Domain.PlayerAnalyzer
  alias EveDmv.Contexts.PlayerProfile.Formatters.CharacterDisplayFormatter

  # Player Analysis
  defdelegate analyze_player(character_id, opts \\ []), to: PlayerAnalyzer
  defdelegate analyze_players(character_ids, opts \\ []), to: PlayerAnalyzer
  defdelegate get_analysis_component(character_id, component), to: PlayerAnalyzer

  # Combat Stats
  defdelegate get_combat_stats(character_id, opts \\ []), to: CombatStatsAnalyzer, as: :analyze

  # Ship Preferences
  defdelegate get_ship_preferences(character_id, opts \\ []),
    to: ShipPreferencesAnalyzer,
    as: :analyze

  # Formatting
  defdelegate format_analysis_summary(character_stats), to: CharacterDisplayFormatter
  defdelegate format_character_summary(analysis_results), to: CharacterDisplayFormatter
end
