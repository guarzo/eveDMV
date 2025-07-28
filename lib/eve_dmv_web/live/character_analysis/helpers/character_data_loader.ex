defmodule EveDmvWeb.CharacterAnalysis.Helpers.CharacterDataLoader do
  @moduledoc """
  Helper module for loading and processing character analysis data.
  Acts as a thin orchestration layer between LiveView and context modules.

  This module was refactored as part of Phase 5 of the Large File Refactoring Plan.
  Data analysis logic has been moved to appropriate context modules:

  - CharacterIntelligence: Ship preferences, weapon preferences, ISK efficiency,
    gang patterns, activity stats, intelligence summary
  - CombatIntelligence: External group collaboration analysis

  The module now serves as a lightweight coordinator that calls context functions
  and aggregates the results for the LiveView.
  """

  alias EveDmv.Contexts.CharacterIntelligence
  alias EveDmv.Contexts.CombatIntelligence
  alias EveDmv.Database.CharacterQueries
  alias EveDmv.Database.QueryPerformance
  require Logger

  @doc """
  Analyze character data for the character analysis LiveView.
  """
  def analyze_character(character_id) do
    try do
      Logger.info("Starting analysis for character #{character_id}")

      # Use optimized queries from CharacterQueries module
      ninety_days_ago = DateTime.utc_now() |> DateTime.add(-90, :day)

      # Get character stats using optimized query
      stats =
        QueryPerformance.tracked_query(
          "character_stats",
          fn -> CharacterQueries.get_character_stats(character_id, ninety_days_ago) end,
          metadata: %{character_id: character_id}
        )

      # Get character name from killmail data
      character_name =
        QueryPerformance.tracked_query(
          "character_name",
          fn -> CharacterQueries.get_character_name_from_killmails(character_id) end
        )

      Logger.info("Found character name: #{character_name || "Unknown"}")

      Logger.info(
        "Found #{stats.kills} kills and #{stats.deaths} deaths for character #{character_id}"
      )

      # Get affiliations
      affiliations =
        QueryPerformance.tracked_query(
          "character_affiliations",
          fn -> CharacterQueries.get_character_affiliations(character_id) end
        )

      # Get ship and weapon preferences from CharacterIntelligence context
      top_ships =
        case CharacterIntelligence.get_detailed_ship_preferences(character_id, ninety_days_ago) do
          {:ok, ships} -> ships
          {:error, _} -> []
        end

      weapon_preferences =
        case CharacterIntelligence.get_weapon_preferences(character_id, ninety_days_ago) do
          {:ok, weapons} -> weapons
          {:error, _} -> []
        end

      # Calculate ISK efficiency
      isk_stats =
        case CharacterIntelligence.calculate_isk_efficiency(character_id, ninety_days_ago) do
          {:ok, stats} -> stats
          {:error, _} -> %{efficiency: 0, destroyed: 0, lost: 0}
        end

      # Get external groups analysis (15-day window for more recent activity)
      fifteen_days_ago = DateTime.utc_now() |> DateTime.add(-15, :day)

      external_groups =
        case CombatIntelligence.get_external_groups(character_id, fifteen_days_ago) do
          {:ok, groups} -> groups
          {:error, _} -> []
        end

      # Get gang size patterns
      gang_size_patterns =
        case CharacterIntelligence.get_gang_size_patterns(character_id, ninety_days_ago) do
          {:ok, patterns} ->
            patterns

          {:error, _} ->
            %{solo: %{}, small_gang: %{}, medium_gang: %{}, large_gang: %{}, fleet: %{}}
        end

      # Calculate activity metrics for the last 30 days
      thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

      activity_stats =
        case CharacterIntelligence.calculate_activity_stats(character_id, thirty_days_ago) do
          {:ok, stats} -> stats
          {:error, _} -> %{recent_kills: 0, most_active_weekday: nil, active_days: 0}
        end

      # Calculate intelligence summary
      intelligence_summary =
        case CharacterIntelligence.get_intelligence_summary(character_id, ninety_days_ago) do
          {:ok, summary} -> summary
          {:error, _} -> %{peak_activity_hour: nil, top_location: %{}, top_region: %{}}
        end

      analysis = %{
        character_id: character_id,
        character_name: character_name,
        corporation_name: affiliations.corporation_name,
        corporation_id: affiliations.corporation_id,
        alliance_name: affiliations.alliance_name,
        alliance_id: affiliations.alliance_id,
        total_kills: stats.kills,
        total_deaths: stats.deaths,
        kd_ratio: stats.kd_ratio,
        isk_efficiency: isk_stats.efficiency,
        isk_destroyed: isk_stats.destroyed,
        isk_lost: isk_stats.lost,
        top_ships: top_ships,
        weapon_preferences: weapon_preferences,
        external_groups: external_groups,
        gang_size_patterns: gang_size_patterns,
        recent_kills: activity_stats.recent_kills,
        most_active_day: activity_stats.most_active_weekday,
        active_days: activity_stats.active_days,
        intelligence_summary: intelligence_summary
      }

      {:ok, analysis}
    rescue
      error ->
        Logger.error("Analysis failed for character #{character_id}: #{inspect(error)}")
        {:error, "Failed to analyze character: #{inspect(error)}"}
    end
  end
end
