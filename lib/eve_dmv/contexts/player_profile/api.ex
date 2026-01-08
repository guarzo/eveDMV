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
  alias EveDmv.Result
  alias EveDmv.Types

  # Player Analysis

  @doc """
  Perform comprehensive player analysis.

  Returns analysis including combat stats, ship preferences, archetype classification,
  and behavioral patterns.
  """
  @spec analyze_player(Types.character_id(), Types.opts()) :: {:ok, map()} | {:error, term()}
  defdelegate analyze_player(character_id, opts \\ []), to: PlayerAnalyzer

  @doc """
  Analyze multiple players in batch.

  Returns batch analysis results with successful and failed analyses.
  """
  @spec analyze_players([Types.character_id()], Types.opts()) :: {:ok, map()} | {:error, term()}
  defdelegate analyze_players(character_ids, opts \\ []), to: PlayerAnalyzer

  @doc """
  Get specific analysis component for a player.

  Component must be :combat or :ships.
  """
  @spec get_analysis_component(Types.character_id(), :combat | :ships) ::
          Result.t(map()) | {:ok, map()}
  defdelegate get_analysis_component(character_id, component), to: PlayerAnalyzer

  # Combat Stats

  @doc """
  Analyze combat statistics for a character.

  Returns detailed combat analysis including basic stats, weapon preferences,
  engagement patterns, and performance metrics.
  """
  @spec get_combat_stats(Types.character_id(), map() | keyword()) :: Result.t(map())
  defdelegate get_combat_stats(character_id, opts \\ []), to: CombatStatsAnalyzer, as: :analyze

  # Ship Preferences

  @doc """
  Analyze ship preferences for a character.

  Returns ship usage patterns, role specialization, fitting preferences,
  and deployment patterns.

  Accepts either a map or keyword list for options.
  """
  @spec get_ship_preferences(Types.character_id(), map() | keyword()) :: Result.t(map())
  def get_ship_preferences(character_id, opts \\ %{})

  def get_ship_preferences(character_id, opts) when is_list(opts) do
    get_ship_preferences(character_id, Enum.into(opts, %{}))
  end

  def get_ship_preferences(character_id, opts) when is_map(opts) do
    ShipPreferencesAnalyzer.analyze(character_id, opts)
  end

  # Formatting

  @doc """
  Format complete character analysis for display.

  Returns formatted overview, combat summary, ship usage, and recommendations.
  """
  @spec format_analysis_summary(map()) :: map()
  defdelegate format_analysis_summary(character_stats), to: CharacterDisplayFormatter

  @doc """
  Format character summary for quick overview.

  Returns threat assessment, key statistics, and tactical recommendations.
  """
  @spec format_character_summary(map()) :: map()
  defdelegate format_character_summary(analysis_results), to: CharacterDisplayFormatter
end
