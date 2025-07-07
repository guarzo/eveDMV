defmodule EveDmv.Intelligence.Analyzers.CharacterAnalyzer do
  @moduledoc """
  Legacy Character Analyzer - Migrated to use Intelligence Engine.

  This module now delegates to the new Intelligence Engine plugin system
  while maintaining backward compatibility with existing code.

  MIGRATION STATUS: ✅ Migrated to Intelligence Engine
  - All analysis now routes through EveDmv.IntelligenceEngine
  - Uses CombatStats, BehavioralPatterns, and ShipPreferences plugins
  - Maintains full backward compatibility via LegacyAdapter
  """

  require Logger
  alias EveDmv.Intelligence.LegacyAdapter
  alias EveDmv.Intelligence.Formatters.CharacterFormatters

  @doc """
  Legacy cache invalidation - now delegates to Intelligence Engine.
  """
  def invalidate_character_cache(character_id) do
    LegacyAdapter.invalidate_character_cache(character_id)
  end

  @doc """
  Legacy interface for character analysis - now uses Intelligence Engine.

  This function maintains the exact same interface as before but now uses
  the new Intelligence Engine plugin system under the hood.
  """
  @spec analyze_character(integer()) :: {:ok, map()} | {:error, term()}
  def analyze_character(character_id) do
    Logger.info("Analyzing character #{character_id} via Intelligence Engine")
    LegacyAdapter.analyze_character(character_id)
  end

  @doc """
  Analyze multiple characters in batch - now uses Intelligence Engine.
  """
  def analyze_characters(character_ids) when is_list(character_ids) do
    Logger.info("Batch analyzing #{length(character_ids)} characters via Intelligence Engine")
    LegacyAdapter.analyze_characters(character_ids)
  end

  @doc """
  Get comprehensive character analysis using the Intelligence Engine.

  This provides more detailed analysis using multiple plugins including
  behavioral patterns, ship preferences, and threat assessment.
  """
  @spec get_comprehensive_analysis(integer()) :: {:ok, map()} | {:error, term()}
  def get_comprehensive_analysis(character_id) do
    Logger.info(
      "Performing comprehensive character analysis for #{character_id} via Intelligence Engine"
    )

    LegacyAdapter.get_comprehensive_character_analysis(character_id)
  end

  @doc """
  Process killmail data - maintained for backward compatibility.

  Note: This function is now primarily used for data conversion.
  The Intelligence Engine handles killmail processing internally.
  """
  def process_killmail_data(raw_killmail_data) do
    # Simple data structure conversion for backward compatibility
    participants = raw_killmail_data["participants"] || []

    processed = %{
      killmail_id: raw_killmail_data["killmail_id"],
      killmail_time: raw_killmail_data["killmail_time"],
      solar_system_id: raw_killmail_data["solar_system_id"],
      participants: participants,
      victim: Enum.find(participants, &(&1["is_victim"] == true)),
      attackers: Enum.reject(participants, &(&1["is_victim"] == true)),
      zkb: raw_killmail_data["zkb"] || %{}
    }

    {:ok, processed}
  end

  @doc """
  Calculate danger rating - maintained for backward compatibility.
  """
  def calculate_danger_rating(stats) when is_map(stats) do
    # Simplified danger rating calculation for legacy compatibility
    kills = get_in(stats, [:total_kills]) || get_in(stats, [:basic_stats, :total_kills]) || 0
    losses = get_in(stats, [:total_losses]) || get_in(stats, [:basic_stats, :total_losses]) || 0
    solo_kills = get_in(stats, [:solo_kills]) || get_in(stats, [:basic_stats, :solo_kills]) || 0

    efficiency =
      get_in(stats, [:isk_efficiency]) || get_in(stats, [:basic_stats, :isk_efficiency]) || 50.0

    kd_ratio = if losses > 0, do: kills / losses, else: kills

    # Calculate danger score (0-100)
    kd_weight = min(kd_ratio * 20, 40)
    solo_weight = min(solo_kills * 2, 30)
    activity_weight = min(kills / 10, 20)
    efficiency_weight = efficiency / 10

    score = kd_weight + solo_weight + activity_weight + efficiency_weight

    # Convert to 1-5 rating
    cond do
      score >= 80 -> 5
      score >= 60 -> 4
      score >= 40 -> 3
      score >= 20 -> 2
      true -> 1
    end
  end

  @doc """
  Format character summary - delegates to formatters.
  """
  def format_character_summary(analysis_results) do
    CharacterFormatters.format_character_summary(analysis_results)
  end

  @doc """
  Format analysis summary - delegates to formatters.
  """
  def format_analysis_summary(character_stats) do
    CharacterFormatters.format_analysis_summary(character_stats)
  end
end
