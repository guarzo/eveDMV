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
  alias EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStats
  alias EveDmv.Contexts.CombatIntelligence
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Platform.Database.CharacterQueries
  alias EveDmv.Platform.Database.QueryPerformance
  require Logger

  # Module attribute for safe gang category string to atom conversion
  @valid_gang_categories %{
    "solo" => :solo,
    "small_gang" => :small_gang,
    "medium_gang" => :medium_gang,
    "large_gang" => :large_gang,
    "fleet" => :fleet
  }

  @doc """
  Analyze character data for the character analysis LiveView.
  """
  def analyze_character(character_id) do
    Logger.info("Starting analysis for character #{character_id}")

    ninety_days_ago = DateTime.utc_now() |> DateTimeUtils.add(-90 * 24 * 60 * 60, :second)

    # Get character stats using Ash-native CharacterStats resource
    stats =
      case QueryPerformance.tracked_query(
             "character_stats",
             fn -> CharacterStats.calculate_for_character(character_id, ninety_days_ago) end,
             metadata: %{character_id: character_id}
           ) do
        {:ok, char_stats} ->
          %{
            kills: char_stats.kills,
            deaths: char_stats.deaths,
            kd_ratio: EveDmv.Calculations.Helpers.kd_ratio(char_stats.kills, char_stats.deaths)
          }

        {:error, _} ->
          %{kills: 0, deaths: 0, kd_ratio: 0.0}
      end

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
    # Transform to the format expected by ActivityFeedComponent: [{ship_name, stats}]
    top_ships =
      case CharacterIntelligence.get_detailed_ship_preferences(character_id, ninety_days_ago) do
        {:ok, %{preferences: ships, stats: _stats}} ->
          Enum.map(ships, fn ship ->
            {
              ship.ship_name,
              %{
                ship_type_id: to_string(ship.ship_type_id),
                kills: ship.kills_in_ship,
                deaths: ship.losses_in_ship
              }
            }
          end)

        _ ->
          []
      end

    # Get ship loadouts (weapons grouped by ship) - only real data, no inference
    ship_loadouts =
      case CharacterIntelligence.get_ship_loadouts(character_id, ninety_days_ago) do
        {:ok, %{ship_loadouts: loadouts}} -> loadouts
        {:error, _} -> []
      end

    # Get weapon preferences (flat list for display)
    weapon_preferences =
      case CharacterIntelligence.get_weapon_preferences(character_id, ninety_days_ago) do
        {:ok, %{preferences: weapons}} ->
          Enum.map(weapons, fn %{weapon_name: wn, usage_count: uc} ->
            %{weapon_name: wn, usage_count: uc}
          end)

        {:error, _} ->
          []
      end

    # Calculate ISK efficiency
    isk_stats =
      CharacterIntelligence.calculate_isk_efficiency(character_id, ninety_days_ago)
      |> unwrap_or_default(%{efficiency_percentage: 0.0, isk_destroyed: 0.0, isk_lost: 0.0})

    # Get external groups analysis (15-day window for more recent activity)
    fifteen_days_ago = DateTime.utc_now() |> DateTimeUtils.add(-15 * 24 * 60 * 60, :second)

    external_groups =
      CombatIntelligence.get_external_groups(character_id, fifteen_days_ago)
      |> unwrap_or_default([])

    # Get gang size patterns - transform from list to map format for template
    gang_size_patterns =
      case CharacterIntelligence.get_gang_size_patterns(character_id, ninety_days_ago) do
        {:ok, %{patterns: patterns}} when is_list(patterns) ->
          # Convert list of patterns to map keyed by category atom
          # Use safe_string_to_category_atom/1 to avoid ArgumentError from unknown categories
          Enum.reduce(
            patterns,
            %{solo: %{}, small_gang: %{}, medium_gang: %{}, large_gang: %{}, fleet: %{}},
            fn pattern, acc ->
              case safe_string_to_category_atom(pattern.size_category) do
                {:ok, category} ->
                  Map.put(acc, category, %{
                    count: pattern.participation_count,
                    percentage: pattern.participation_percentage,
                    avg_size: pattern.avg_gang_size
                  })

                :error ->
                  # Unknown category, skip it
                  acc
              end
            end
          )

        {:ok, patterns} when is_map(patterns) ->
          patterns

        {:error, _} ->
          %{solo: %{}, small_gang: %{}, medium_gang: %{}, large_gang: %{}, fleet: %{}}
      end

    # Get known associates
    known_associates =
      CharacterIntelligence.get_known_associates(character_id, ninety_days_ago)
      |> unwrap_or_default(%{associates: [], total_associates: 0})

    # Get hunting grounds
    hunting_grounds =
      CharacterIntelligence.get_hunting_grounds(character_id, ninety_days_ago)
      |> unwrap_or_default(%{
        top_systems: [],
        security_preference: [],
        primary_security: "unknown"
      })

    # Get target selection patterns
    target_selection =
      CharacterIntelligence.get_target_selection(character_id, ninety_days_ago)
      |> unwrap_or_default(%{
        top_targets: [],
        class_breakdown: [],
        avg_victim_value: 0,
        target_assessment: "unknown"
      })

    # Get activity timeline (last 30 days)
    thirty_days_ago_for_timeline =
      DateTime.utc_now() |> DateTimeUtils.add(-30 * 24 * 60 * 60, :second)

    activity_timeline =
      CharacterIntelligence.get_activity_timeline(character_id, thirty_days_ago_for_timeline)
      |> unwrap_or_default(%{
        timeline: [],
        week_kills: 0,
        week_deaths: 0,
        activity_trend: "unknown"
      })

    # Get corp context
    corp_context =
      CharacterIntelligence.get_corp_context(character_id, ninety_days_ago)
      |> unwrap_or_default(%{active_pilots: 0, corp_kills: 0, corp_size_assessment: "unknown"})

    # Get bait indicators
    bait_indicators =
      CharacterIntelligence.get_bait_indicators(character_id, ninety_days_ago)
      |> unwrap_or_default(%{is_likely_bait: false, bait_assessment: "No data"})

    # Calculate activity metrics for the last 30 days
    thirty_days_ago = DateTime.utc_now() |> DateTimeUtils.add(-30 * 24 * 60 * 60, :second)

    activity_stats =
      case CharacterIntelligence.calculate_activity_stats(character_id, thirty_days_ago) do
        {:ok, %{stats: stats}} ->
          stats

        {:error, _} ->
          %{total_kills: 0, peak_activity_day: nil, peak_activity_hour: nil, active_days: 0}
      end

    # Calculate intelligence summary - build structure expected by component
    # The component expects: peak_activity_hour, top_location, primary_timezone
    raw_intelligence =
      CharacterIntelligence.get_intelligence_summary(character_id, ninety_days_ago)
      |> unwrap_or_default(%{})

    # Extract top region from regional_activity if available
    top_region =
      case Map.get(raw_intelligence, :regional_activity) do
        [first | _] when is_map(first) ->
          %{name: Map.get(first, "region")}

        _ ->
          %{}
      end

    # Build the structure expected by the component
    intelligence_summary = %{
      peak_activity_hour: activity_stats.peak_activity_hour,
      top_location: top_region,
      top_region: top_region,
      primary_timezone: derive_timezone(activity_stats.peak_activity_hour),
      # Also include the raw data for other uses
      total_events: Map.get(raw_intelligence, :total_events, 0),
      unique_systems: Map.get(raw_intelligence, :unique_systems, 0),
      regional_activity: Map.get(raw_intelligence, :regional_activity, [])
    }

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
      isk_efficiency: isk_stats.efficiency_percentage,
      isk_destroyed: isk_stats.isk_destroyed,
      isk_lost: isk_stats.isk_lost,
      top_ships: top_ships,
      weapon_preferences: weapon_preferences,
      ship_loadouts: ship_loadouts,
      external_groups: external_groups,
      gang_size_patterns: gang_size_patterns,
      recent_kills: activity_stats.total_kills,
      most_active_day: activity_stats.peak_activity_day,
      active_days: activity_stats.active_days,
      intelligence_summary: intelligence_summary,
      # Enhanced intelligence features
      known_associates: known_associates,
      hunting_grounds: hunting_grounds,
      target_selection: target_selection,
      activity_timeline: activity_timeline,
      corp_context: corp_context,
      bait_indicators: bait_indicators
    }

    {:ok, analysis}
  rescue
    error ->
      Logger.error("Analysis failed for character #{character_id}: #{inspect(error)}")
      {:error, "Failed to analyze character: #{inspect(error)}"}
  end

  # Derive timezone from peak activity hour (EVE time is UTC)
  # Maps peak activity UTC hour to the player's likely real-world timezone.
  #
  # EVE time is UTC. We infer timezone based on what would be "prime time" (evening hours)
  # for players in different regions:
  #
  # | UTC Hour   | US Time (EST)      | EU Time (CET)     | AU Time (AEDT)    |
  # |------------|-------------------|-------------------|-------------------|
  # | 00:00-08:00| 19:00-03:00 (eve) | 01:00-09:00 (night)| 11:00-19:00 (day)|
  # | 08:00-16:00| 03:00-11:00 (night)| 09:00-17:00 (day) | 19:00-03:00 (eve)|
  # | 16:00-24:00| 11:00-19:00 (day) | 17:00-01:00 (eve) | 03:00-11:00 (night)|
  #
  # Players most likely play during their evening hours (17:00-01:00 local).
  defp derive_timezone(nil), do: nil

  defp derive_timezone(peak_hour) when is_number(peak_hour) do
    # Convert to integer in case PostgreSQL returns a float from EXTRACT
    hour = trunc(peak_hour)

    cond do
      # 00:00-08:00 UTC = US evening/late night (19:00-03:00 EST)
      hour >= 0 and hour < 8 -> "US TZ"
      # 08:00-16:00 UTC = EU evening (09:00-17:00 CET) / AU evening (19:00-03:00 AEDT overlap)
      hour >= 8 and hour < 16 -> "EU TZ"
      # 16:00-24:00 UTC = EU late night / US daytime / potential AU
      hour >= 16 and hour < 20 -> "US TZ"
      # 20:00-24:00 UTC = Could be AU prime time or US afternoon
      hour >= 20 and hour < 24 -> "AU/NZ TZ"
      true -> nil
    end
  end

  defp derive_timezone(%Decimal{} = dec), do: derive_timezone(Decimal.to_float(dec) |> trunc())
  defp derive_timezone(_), do: nil

  # Helper to unwrap {:ok, data} or return default on {:error, _}
  defp unwrap_or_default({:ok, data}, _default), do: data
  defp unwrap_or_default({:error, _}, default), do: default

  # Safely convert gang size category string to atom without raising on unknown values.
  # Returns {:ok, atom} for known categories, :error for unknown.
  defp safe_string_to_category_atom(category) when is_binary(category) do
    case Map.fetch(@valid_gang_categories, category) do
      {:ok, atom} -> {:ok, atom}
      :error -> :error
    end
  end

  defp safe_string_to_category_atom(_), do: :error
end
