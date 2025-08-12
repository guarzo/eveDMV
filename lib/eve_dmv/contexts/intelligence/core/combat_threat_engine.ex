defmodule EveDmv.Contexts.Intelligence.Core.CombatThreatEngine do
  @moduledoc """
  Analyzes combat effectiveness and threat level based on killmail data.
  Part of the multi-dimensional threat assessment system.
  """

  alias EveDmv.Contexts.Intelligence.Core.CombatStatsAnalyzer
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Platform.Database.KillmailRepository

  require Logger

  @doc """
  Analyze combat threat level for a character.
  """
  def analyze(character_id) do
    with {:ok, combat_stats} <- CombatStatsAnalyzer.analyze_combat_stats(character_id),
         {:ok, recent_activity} <- analyze_recent_activity(character_id) do
      threat_analysis = %{
        character_id: character_id,
        threat_score: calculate_threat_score(combat_stats, recent_activity),
        kill_death_ratio: combat_stats.kill_death_ratio,
        isk_efficiency: combat_stats.isk_efficiency,
        solo_effectiveness: combat_stats.solo_ratio,
        recent_activity_level: recent_activity.activity_level,
        high_value_kills: recent_activity.high_value_kills,
        capital_usage: recent_activity.capital_usage,
        analyzed_at: DateTime.utc_now()
      }

      {:ok, threat_analysis}
    end
  end

  defp analyze_recent_activity(character_id) do
    # Last 30 days
    start_date = DateTime.utc_now() |> DateTimeUtils.add(-30 * 24 * 60 * 60, :second)

    case KillmailRepository.get_by_character(character_id, start_date: start_date, limit: 1000) do
      {:ok, killmails} ->
        activity = %{
          activity_level: classify_activity_level(length(killmails)),
          high_value_kills: count_high_value_kills(killmails, character_id),
          capital_usage: detect_capital_usage(killmails, character_id),
          kill_frequency: calculate_kill_frequency(killmails, character_id)
        }

        {:ok, activity}

      error ->
        error
    end
  end

  defp classify_activity_level(count) do
    cond do
      count >= 100 -> :hyperactive
      count >= 50 -> :very_active
      count >= 20 -> :active
      count >= 5 -> :moderate
      true -> :low
    end
  end

  defp count_high_value_kills(killmails, character_id) do
    killmails
    |> Enum.filter(fn km ->
      # 1 billion ISK
      km.victim.character_id != character_id and
        km.total_value > 1_000_000_000
    end)
    |> length()
  end

  defp detect_capital_usage(killmails, character_id) do
    capital_ship_ids = [
      # Carriers
      23_757,
      23_911,
      23_915,
      24_483,
      # Dreadnoughts
      19_720,
      19_722,
      19_724,
      19_726,
      # Supercarriers
      23_913,
      23_917,
      23_919,
      3514,
      # Titans
      671,
      3764,
      11_567,
      23_773
    ]

    killmails
    |> Enum.any?(fn km ->
      # Check if character used capitals
      if km.victim.character_id == character_id do
        km.victim.ship_type_id in capital_ship_ids
      else
        Enum.any?(km.attackers, fn att ->
          att.character_id == character_id and
            att.ship_type_id in capital_ship_ids
        end)
      end
    end)
  end

  defp calculate_kill_frequency(killmails, character_id) do
    kills = Enum.filter(killmails, fn km -> km.victim.character_id != character_id end)

    if length(kills) >= 2 do
      # Average time between kills
      sorted_kills = Enum.sort_by(kills, & &1.killmail_time)

      intervals =
        sorted_kills
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [km1, km2] ->
          DateTimeUtils.diff(km2.killmail_time, km1.killmail_time, :hour)
        end)

      avg_interval = Enum.sum(intervals) / max(length(intervals), 1)

      cond do
        avg_interval < 6 -> :very_frequent
        avg_interval < 24 -> :frequent
        avg_interval < 72 -> :regular
        true -> :sporadic
      end
    else
      :insufficient_data
    end
  end

  defp calculate_threat_score(combat_stats, recent_activity) do
    # Base score from K/D ratio (0-30 points)
    kd_score = min(combat_stats.kill_death_ratio * 10, 30)

    # ISK efficiency (0-20 points)
    isk_score = min(combat_stats.isk_efficiency / 5, 20)

    # Solo effectiveness (0-20 points)
    solo_score = combat_stats.solo_ratio * 20

    # Recent activity (0-15 points)
    activity_score =
      case recent_activity.activity_level do
        :hyperactive -> 15
        :very_active -> 12
        :active -> 8
        :moderate -> 4
        :low -> 1
      end

    # High value kills (0-10 points)
    hvk_score = min(recent_activity.high_value_kills * 2, 10)

    # Capital usage (0-5 points)
    capital_score = if recent_activity.capital_usage, do: 5, else: 0

    # Calculate total
    total = kd_score + isk_score + solo_score + activity_score + hvk_score + capital_score

    # Normalize to 0-1 scale
    Float.round(total / 100, 3)
  end
end
