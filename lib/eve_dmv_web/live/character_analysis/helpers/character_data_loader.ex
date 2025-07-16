defmodule EveDmvWeb.CharacterAnalysis.Helpers.CharacterDataLoader do
  @moduledoc """
  Helper module for loading and processing character analysis data.
  """

  # alias EveDmv.Repo
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

      # Get ship and weapon preferences
      top_ships = get_ship_preferences(character_id, ninety_days_ago)
      weapon_preferences = get_weapon_preferences(character_id, ninety_days_ago)

      # Calculate ISK efficiency
      isk_stats = calculate_isk_efficiency(character_id, ninety_days_ago)

      # Get external groups analysis (15-day window for more recent activity)
      fifteen_days_ago = DateTime.utc_now() |> DateTime.add(-15, :day)
      external_groups = get_external_groups(character_id, fifteen_days_ago)

      # Get gang size patterns
      gang_size_patterns = get_gang_size_patterns(character_id, ninety_days_ago)

      # Calculate activity metrics for the last 30 days
      thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)
      activity_stats = calculate_activity_stats(character_id, thirty_days_ago)

      # Calculate intelligence summary
      intelligence_summary =
        calculate_character_intelligence_summary(character_id, ninety_days_ago)

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
        most_active_day: activity_stats.most_active_day,
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

  # Placeholder implementations - these would need to be moved from the original file
  # defp get_character_name(_character_id), do: "Unknown Pilot"
  defp get_ship_preferences(_character_id, _date), do: []
  defp get_weapon_preferences(_character_id, _date), do: []
  defp calculate_isk_efficiency(_character_id, _date), do: %{efficiency: 0, destroyed: 0, lost: 0}
  defp get_external_groups(_character_id, _date), do: []
  defp get_gang_size_patterns(_character_id, _date), do: %{}

  defp calculate_activity_stats(_character_id, _date),
    do: %{recent_kills: 0, most_active_day: nil, active_days: 0}

  defp calculate_character_intelligence_summary(_character_id, _date),
    do: %{peak_activity_hour: nil, top_location: nil, primary_timezone: nil}

  # defp get_corporation_alliance_from_killmails(_character_id), do: {nil, nil, nil, nil}
end
