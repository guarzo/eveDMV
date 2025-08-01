defmodule EveDmv.Contexts.Combat.Core.BattleAnalyzer do
  @moduledoc """
  Unified battle analysis module that provides comprehensive battle analytics.

  Consolidates functionality from:
  - Basic battle metrics calculation
  - Advanced tactical analysis
  - Strategic recommendations
  - Combat effectiveness evaluation
  """

  import Ecto.Query

  alias EveDmv.Contexts.BattleAnalysis.Resources.Battle
  alias EveDmv.Contexts.Combat.Core.FleetCompositionAnalyzer
  alias EveDmv.Contexts.Combat.Core.ParticipantAnalyzer
  alias EveDmv.Contexts.Combat.Core.PerformanceCalculator
  alias EveDmv.Contexts.Combat.Core.TacticalPatternDetector
  alias EveDmv.Contexts.Combat.Core.TimelineBuilder
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Repo

  @doc """
  Perform comprehensive analysis of a battle.

  Returns a complete battle analysis including:
  - Battle summary and key metrics
  - Timeline of events
  - Participant performance
  - Fleet compositions
  - Tactical patterns
  - Strategic insights
  """
  def analyze_battle(battle_id) do
    with {:ok, battle} <- get_battle_data(battle_id),
         {:ok, killmails} <- get_battle_killmails(battle),
         {:ok, timeline} <- TimelineBuilder.build_timeline(killmails),
         {:ok, participants} <- ParticipantAnalyzer.analyze_participants(killmails),
         {:ok, fleet_comp} <- FleetCompositionAnalyzer.analyze_composition(killmails),
         {:ok, tactics} <- TacticalPatternDetector.detect_patterns(killmails, timeline),
         {:ok, performance} <- PerformanceCalculator.calculate_metrics(killmails, participants) do
      {:ok,
       %{
         battle_id: battle_id,
         summary: build_battle_summary(battle, killmails),
         metrics: calculate_battle_metrics(killmails, participants),
         timeline: timeline,
         participants: participants,
         fleet_composition: fleet_comp,
         tactical_patterns: tactics,
         performance_metrics: performance,
         recommendations: generate_recommendations(tactics, fleet_comp, performance)
       }}
    end
  end

  @doc """
  Get battle metrics for a specific battle.
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
    with {:ok, analysis} <- analyze_battle(battle_id) do
      summary = %{
        headline: generate_headline(analysis),
        key_stats: extract_key_stats(analysis),
        winning_side: determine_winner(analysis),
        mvp_pilot: find_mvp(analysis),
        turning_point: identify_turning_point(analysis),
        notable_kills: find_notable_kills(analysis)
      }

      {:ok, summary}
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

  defp build_battle_summary(battle, killmails) do
    %{
      battle_id: battle.id,
      location: %{
        system_id: battle.system_id,
        region_id: battle.region_id,
        constellation_id: battle.constellation_id
      },
      time_span: %{
        start: List.first(killmails).killmail_time,
        end: List.last(killmails).killmail_time,
        duration_minutes: calculate_duration(killmails)
      },
      scale: categorize_battle_scale(killmails),
      intensity: calculate_intensity(killmails),
      type: identify_battle_type(killmails)
    }
  end

  defp calculate_battle_metrics(killmails, participants) do
    %{
      destruction: %{
        total_isk: calculate_total_isk(killmails),
        ships_destroyed: length(killmails),
        pods_killed: count_pod_kills(killmails)
      },
      participation: %{
        unique_pilots: MapSet.size(participants.all_participants),
        unique_corporations: length(participants.by_corporation),
        unique_alliances: length(participants.by_alliance)
      },
      efficiency: %{
        isk_efficiency: calculate_isk_efficiency(killmails, participants),
        kill_death_ratio: calculate_kd_ratio(participants)
      },
      engagement: %{
        average_on_kill: calculate_average_on_kill(killmails),
        solo_kills: count_solo_kills(killmails),
        capital_kills: count_capital_kills(killmails)
      }
    }
  end

  defp calculate_duration(killmails) when length(killmails) < 2, do: 0

  defp calculate_duration(killmails) do
    first = List.first(killmails).killmail_time
    last = List.last(killmails).killmail_time
    DateTime.diff(last, first, :minute)
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
    if length(killmails) > 0, do: total / length(killmails), else: 0
  end

  defp get_ship_classes(killmails) do
    killmails
    |> Enum.map(&get_in(&1.victim, ["ship_type_id"]))
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()

    # TODO: Map to actual ship classes
  end

  defp get_system_security(_battle) do
    # TODO: Get actual system security
    0.5
  end

  defp find_peak_activity(killmails) do
    killmails
    |> Enum.group_by(fn km ->
      km.killmail_time
      |> DateTime.truncate(:minute)
    end)
    |> Enum.max_by(fn {_time, kms} -> length(kms) end, fn -> {nil, []} end)
    |> elem(0)
  end

  defp categorize_battle_scale(killmails) do
    participants = count_unique_participants(killmails)

    cond do
      participants <= 10 -> :small_gang
      participants <= 25 -> :medium_gang
      participants <= 50 -> :small_fleet
      participants <= 150 -> :medium_fleet
      true -> :large_fleet
    end
  end

  defp calculate_intensity(killmails) do
    duration = max(calculate_duration(killmails), 1)
    kill_rate = length(killmails) / duration

    cond do
      kill_rate >= 2.0 -> :extreme
      kill_rate >= 1.0 -> :high
      kill_rate >= 0.5 -> :moderate
      true -> :low
    end
  end

  defp identify_battle_type(killmails) do
    # Analyze patterns to determine battle type
    capital_ratio = count_capital_kills(killmails) / max(length(killmails), 1)

    cond do
      capital_ratio > 0.3 -> :capital_brawl
      has_structure_kill?(killmails) -> :structure_bash
      gate_camp?(killmails) -> :gate_camp
      bombing_run?(killmails) -> :bombing_run
      true -> :fleet_fight
    end
  end

  defp generate_recommendations(_tactics, _fleet_comp, _performance) do
    # Recommendations feature removed - too complex for current scope
    []
  end

  defp count_pod_kills(killmails) do
    Enum.count(killmails, fn km ->
      ship_type_id = get_in(km.victim, ["ship_type_id"])
      # Capsule type ID
      ship_type_id == 670
    end)
  end

  defp count_solo_kills(killmails) do
    Enum.count(killmails, fn km ->
      length(km.attackers || []) == 1
    end)
  end

  defp count_capital_kills(killmails) do
    # TODO: Check against actual capital ship type IDs
    Enum.count(killmails, fn km ->
      ship_type_id = get_in(km.victim, ["ship_type_id"])
      # Rough approximation
      ship_type_id && ship_type_id > 20_000
    end)
  end

  defp has_structure_kill?(_killmails) do
    # TODO: Check for structure type IDs
    false
  end

  defp gate_camp?(_killmails) do
    # TODO: Analyze location patterns
    false
  end

  defp bombing_run?(_killmails) do
    # TODO: Check for bomber patterns
    false
  end

  defp calculate_isk_efficiency(_killmails, _participants) do
    # TODO: Calculate proper ISK efficiency
    50.0
  end

  defp calculate_kd_ratio(_participants) do
    # TODO: Calculate kill/death ratio
    1.0
  end

  defp calculate_average_on_kill(killmails) do
    total_attackers =
      Enum.reduce(killmails, 0, fn km, acc ->
        acc + length(km.attackers || [])
      end)

    if length(killmails) > 0, do: total_attackers / length(killmails), else: 0
  end

  defp generate_headline(analysis) do
    scale = analysis.summary.scale
    type = analysis.summary.type
    location = analysis.summary.location.system_id

    "#{scale} #{type} in system #{location}"
  end

  defp extract_key_stats(analysis) do
    [
      %{label: "Duration", value: "#{analysis.summary.time_span.duration_minutes} minutes"},
      %{label: "Participants", value: analysis.metrics.participation.unique_pilots},
      %{label: "ISK Destroyed", value: format_isk(analysis.metrics.destruction.total_isk)},
      %{label: "Ships Lost", value: analysis.metrics.destruction.ships_destroyed}
    ]
  end

  defp determine_winner(_analysis) do
    # TODO: Implement winner determination logic
    :undetermined
  end

  defp find_mvp(_analysis) do
    # TODO: Implement MVP selection logic
    nil
  end

  defp identify_turning_point(_analysis) do
    # TODO: Implement turning point detection
    nil
  end

  defp find_notable_kills(_analysis) do
    # TODO: Implement notable kill detection
    []
  end

  defp format_isk(amount) when amount >= 1_000_000_000 do
    "#{Float.round(amount / 1_000_000_000, 1)}B ISK"
  end

  defp format_isk(amount) when amount >= 1_000_000 do
    "#{Float.round(amount / 1_000_000, 1)}M ISK"
  end

  defp format_isk(amount) do
    "#{round(amount)} ISK"
  end
end
