defmodule EveDmvWeb.CharacterAnalysis.Helpers.CharacterDataLoader do
  @moduledoc """
  Helper module for loading and processing character analysis data.
  """

  alias EveDmv.Repo
  require Logger

  @doc """
  Analyze character data for the character analysis LiveView.
  """
  def analyze_character(character_id) do
    try do
      Logger.info("Starting analysis for character #{character_id}")

      # First, try to get character name from killmail data
      character_name = get_character_name(character_id)
      Logger.info("Found character name: #{character_name || "Unknown"}")

      # Simple count queries
      ninety_days_ago = DateTime.utc_now() |> DateTime.add(-90, :day)

      # Query kills (simplified)
      kills_query = """
      SELECT COUNT(DISTINCT km.killmail_id) as kill_count
      FROM killmails_raw km,
           jsonb_array_elements(raw_data->'attackers') as attacker
      WHERE attacker->>'character_id' = $1
        AND km.killmail_time >= $2
      """

      # Query deaths (simplified)
      deaths_query = """
      SELECT COUNT(*) as death_count
      FROM killmails_raw km
      WHERE victim_character_id = $1
        AND killmail_time >= $2
      """

      Logger.info("Executing kill query for character #{character_id}")

      {:ok, %{rows: [[kill_count]]}} =
        Repo.query(kills_query, [to_string(character_id), ninety_days_ago])

      Logger.info("Found #{kill_count} kills for character #{character_id}")

      {:ok, %{rows: [[death_count]]}} =
        Repo.query(deaths_query, [character_id, ninety_days_ago])

      Logger.info("Found #{death_count} deaths for character #{character_id}")

      # Calculate simple metrics
      kd_ratio =
        if death_count > 0, do: Float.round(kill_count / death_count, 2), else: kill_count

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

      # Get corporation and alliance info from killmail data
      {corp_name, alliance_name, corp_id, alliance_id} =
        get_corporation_alliance_from_killmails(character_id)

      analysis = %{
        character_id: character_id,
        character_name: character_name,
        corporation_name: corp_name,
        corporation_id: corp_id,
        alliance_name: alliance_name,
        alliance_id: alliance_id,
        total_kills: kill_count,
        total_deaths: death_count,
        kd_ratio: kd_ratio,
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
  defp get_character_name(_character_id), do: "Unknown Pilot"
  defp get_ship_preferences(_character_id, _date), do: []
  defp get_weapon_preferences(_character_id, _date), do: []
  defp calculate_isk_efficiency(_character_id, _date), do: %{efficiency: 0, destroyed: 0, lost: 0}
  defp get_external_groups(_character_id, _date), do: []
  defp get_gang_size_patterns(_character_id, _date), do: %{}

  defp calculate_activity_stats(_character_id, _date),
    do: %{recent_kills: 0, most_active_day: nil, active_days: 0}

  defp calculate_character_intelligence_summary(_character_id, _date),
    do: %{peak_activity_hour: nil, top_location: nil, primary_timezone: nil}

  defp get_corporation_alliance_from_killmails(_character_id), do: {nil, nil, nil, nil}
end
