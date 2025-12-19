defmodule EveDmv.Contexts.Combat.Core.BattleAnalyzer do
  @moduledoc """
  Battle analysis module for the Combat context.

  **DEPRECATED**: This module is being consolidated. Use the canonical implementations:
  - `EveDmv.Contexts.BattleAnalysis.Core.OptimizedBattleAnalyzer` for optimized analysis
  - `EveDmv.Contexts.BattleAnalysis.Core.CachedBattleAnalyzer` for cached analysis

  This module now delegates to the canonical implementations where possible
  while maintaining backward compatibility for existing callers.
  """

  import Ecto.Query

  alias EveDmv.Contexts.BattleAnalysis.Core.OptimizedBattleAnalyzer
  alias EveDmv.Contexts.BattleAnalysis.Resources.Battle
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Repo

  require Logger

  @doc """
  Perform comprehensive analysis of a battle.

  **DEPRECATED**: Use `EveDmv.Contexts.BattleAnalysis.Core.OptimizedBattleAnalyzer.analyze_battle/1` instead.
  """
  @deprecated "Use EveDmv.Contexts.BattleAnalysis.Core.OptimizedBattleAnalyzer.analyze_battle/1 instead"
  def analyze_battle(battle_id) do
    # Delegate to canonical implementation
    OptimizedBattleAnalyzer.analyze_battle(battle_id)
  end

  @doc """
  Get battle metrics for a specific battle.

  This function provides metrics not available in the OptimizedBattleAnalyzer.
  It will be migrated to the canonical module in a future release.
  """
  def get_battle_metrics(battle_id) do
    with {:ok, battle} <- get_battle_data(battle_id),
         {:ok, killmails} <- get_battle_killmails(battle) do
      metrics = %{
        duration_minutes: calculate_duration(killmails),
        total_kills: length(killmails),
        total_isk_destroyed: calculate_total_isk(killmails),
        unique_participants: count_unique_participants(killmails),
        unique_corporations: count_unique_corporations(killmails),
        unique_alliances: count_unique_alliances(killmails),
        kills_per_minute: calculate_kill_rate(killmails),
        average_kill_value: calculate_average_kill_value(killmails),
        ship_classes_involved: get_ship_classes(killmails),
        system_security: get_system_security(battle),
        peak_activity_time: find_peak_activity(killmails)
      }

      {:ok, metrics}
    end
  end

  @doc """
  Generate a battle summary suitable for display.
  """
  def get_battle_summary(battle_id) do
    case analyze_battle(battle_id) do
      {:ok, analysis} ->
        summary = %{
          headline: generate_headline(analysis),
          key_stats: extract_key_stats(analysis),
          winning_side: determine_winner(analysis),
          mvp_pilot: find_mvp(analysis),
          turning_point: identify_turning_point(analysis),
          notable_kills: find_notable_kills(analysis)
        }

        {:ok, summary}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private Functions

  defp get_battle_data(battle_id) do
    case Repo.get(Battle, battle_id) do
      nil -> {:error, :battle_not_found}
      battle -> {:ok, battle}
    end
  end

  defp get_battle_killmails(battle) do
    killmails =
      KillmailRaw
      |> where([k], k.killmail_id in ^battle.killmail_ids)
      |> order_by([k], asc: k.killmail_time)
      |> Repo.all()

    {:ok, killmails}
  end

  defp calculate_duration([]), do: 0
  defp calculate_duration([_]), do: 0

  defp calculate_duration(killmails) do
    first = List.first(killmails).killmail_time
    last = List.last(killmails).killmail_time
    DateTimeUtils.diff(last, first, :minute)
  end

  defp calculate_total_isk(killmails) do
    Enum.reduce(killmails, 0.0, fn km, acc ->
      acc + (get_in(km.zkb, ["totalValue"]) || 0.0)
    end)
  end

  defp count_unique_participants(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      victim_id = get_in(km.victim, ["character_id"])

      attacker_ids =
        (km.attackers || [])
        |> Enum.map(&get_in(&1, ["character_id"]))
        |> Enum.reject(&is_nil/1)

      [victim_id | attacker_ids] |> Enum.reject(&is_nil/1)
    end)
    |> Enum.uniq()
    |> length()
  end

  defp count_unique_corporations(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      victim_corp = get_in(km.victim, ["corporation_id"])

      attacker_corps =
        (km.attackers || [])
        |> Enum.map(&get_in(&1, ["corporation_id"]))
        |> Enum.reject(&is_nil/1)

      [victim_corp | attacker_corps] |> Enum.reject(&is_nil/1)
    end)
    |> Enum.uniq()
    |> length()
  end

  defp count_unique_alliances(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      victim_alliance = get_in(km.victim, ["alliance_id"])

      attacker_alliances =
        (km.attackers || [])
        |> Enum.map(&get_in(&1, ["alliance_id"]))
        |> Enum.reject(&is_nil/1)

      [victim_alliance | attacker_alliances] |> Enum.reject(&is_nil/1)
    end)
    |> Enum.uniq()
    |> length()
  end

  defp calculate_kill_rate(killmails) do
    duration = calculate_duration(killmails)
    if duration > 0, do: length(killmails) / duration, else: 0
  end

  defp calculate_average_kill_value(killmails) do
    total = calculate_total_isk(killmails)
    count = length(killmails)
    if count > 0, do: total / count, else: 0
  end

  defp get_ship_classes(killmails) do
    killmails
    |> Enum.map(&get_in(&1.victim, ["ship_type_id"]))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&{&1, EveDmv.StaticData.ShipTypes.classify_ship_type(&1)})
    |> Enum.group_by(fn {_type_id, class} -> class end)
    |> Enum.map(fn {class, ships} -> {class, length(ships)} end)
    |> Map.new()
  end

  defp get_system_security(battle) do
    EveDmv.StaticData.SystemData.get_security_status(battle.system_id)
  end

  defp find_peak_activity(killmails) do
    killmails
    |> Enum.group_by(fn km ->
      km.killmail_time
      |> DateTimeUtils.truncate_to_minute()
    end)
    |> Enum.max_by(fn {_time, kms} -> length(kms) end, fn -> {nil, []} end)
    |> elem(0)
  end

  defp generate_headline(_analysis), do: "Battle Summary"
  defp extract_key_stats(_analysis), do: []
  defp determine_winner(_analysis), do: :unknown
  defp find_mvp(_analysis), do: nil
  defp identify_turning_point(_analysis), do: nil
  defp find_notable_kills(_analysis), do: []
end
