defmodule EveDmv.Contexts.BattleAnalysis.Core.BattleAnalyzer do
  @compile {:nowarn_unused_function}
  @moduledoc """
  Unified battle analysis module that provides comprehensive battle analytics.

  Consolidates functionality from:
  - Basic battle metrics calculation
  - Advanced tactical analysis
  - Strategic recommendations
  - Combat effectiveness evaluation
  """

  import Ecto.Query

  alias EveDmv.Contexts.BattleAnalysis.Api, as: BattleApi
  alias EveDmv.Contexts.BattleAnalysis.Resources.Battle
  alias EveDmv.Contexts.Combat.Core.FleetCompositionAnalyzer
  alias EveDmv.Contexts.Combat.Core.ParticipantAnalyzer
  alias EveDmv.Contexts.Combat.Core.PerformanceCalculator
  alias EveDmv.Contexts.Combat.Core.TacticalPatternDetector
  alias EveDmv.Contexts.Combat.Core.TimelineBuilder
  alias EveDmv.Core.Utils.DateTimeUtils
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
         recommendations: []
       }}
    else
      {:error, _} = error -> error
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

      {:error, _} = error ->
        error
    end
  end

  # Private Functions

  defp get_battle_data(battle_id) do
    import Ash.Query, except: [limit: 2]

    query =
      Battle
      |> filter(id == ^battle_id)
      |> Ash.Query.limit(1)

    case BattleApi.read(query) do
      {:ok, [battle]} -> {:ok, battle}
      {:ok, []} -> {:error, :battle_not_found}
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, :battle_not_found}
      {:error, error} -> {:error, error}
    end
  end

  defp get_battle_killmails(battle) do
    # Optimized query with preloading to avoid N+1
    killmails =
      from(k in KillmailRaw,
        where: k.killmail_id in ^battle.killmail_ids,
        left_join: s in assoc(k, :solar_system),
        left_join: vc in assoc(k, :victim_character),
        left_join: vco in assoc(k, :victim_corporation),
        preload: [solar_system: s, victim_character: vc, victim_corporation: vco],
        order_by: [asc: k.killmail_time]
      )
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
        unique_pilots: length(participants.all_participants),
        unique_corporations: map_size(Map.get(participants, :by_corporation, %{})),
        unique_alliances: map_size(Map.get(participants, :by_alliance, %{}))
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
    if length(killmails) > 0, do: total / length(killmails), else: 0
  end

  defp get_ship_classes(killmails) do
    killmails
    |> Enum.map(&get_in(&1.victim, ["ship_type_id"]))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&EveDmv.StaticData.ShipTypes.classify_ship_type/1)
    |> Enum.frequencies()
  end

  defp get_system_security(battle) do
    # Get actual system security from EVE static data
    case battle.system_id do
      nil ->
        0.5

      system_id ->
        # Query system security from eve_systems table
        query =
          from(s in "eve_systems",
            where: s.system_id == ^system_id,
            select: s.security_status
          )

        case query |> Repo.one() do
          nil -> 0.5
          security when is_float(security) -> security
          _ -> 0.5
        end
    end
  end

  defp find_peak_activity(killmails) do
    killmails
    |> Enum.group_by(fn km ->
      time = km.killmail_time

      case time do
        %DateTime{} = dt -> DateTime.truncate(dt, :second)
        %NaiveDateTime{} = ndt -> NaiveDateTime.truncate(ndt, :second)
        _ -> time
      end
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
      true -> :fleet_fight
    end
  end

  defp count_solo_kills(killmails) do
    Enum.count(killmails, fn km ->
      length(km.attackers || []) == 1
    end)
  end

  defp count_capital_kills(killmails) do
    Enum.count(killmails, fn km ->
      ship_type_id = get_in(km.victim, ["ship_type_id"])

      case ship_type_id do
        nil ->
          false

        type_id ->
          ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(type_id)
          ship_class in [:capital, :supercapital]
      end
    end)
  end

  defp has_structure_kill?(killmails) do
    Enum.any?(killmails, fn km ->
      ship_type_id = get_in(km.victim, ["ship_type_id"])

      case ship_type_id do
        nil ->
          false

        type_id ->
          # Check if it's a structure (category_id 65 for structures)
          case Repo.one(
                 from(i in "eve_item_types",
                   where: i.type_id == ^type_id and i.category_id == 65,
                   select: i.type_id
                 )
               ) do
            nil -> false
            _ -> true
          end
      end
    end)
  end

  defp gate_camp?(killmails) do
    if length(killmails) < 3,
      do: false,
      else:
        (
          # Gate camps typically happen at gates and have quick succession of kills
          # Check if kills happen in quick succession (within 5 minutes)
          sorted_killmails = Enum.sort_by(killmails, & &1.killmail_time)

          kill_intervals =
            sorted_killmails
            |> Enum.chunk_every(2, 1, :discard)
            |> Enum.map(fn [km1, km2] ->
              DateTimeUtils.diff(km2.killmail_time, km1.killmail_time, :second)
            end)

          # Gate camps have consistent short intervals between kills
          avg_interval =
            if length(kill_intervals) > 0,
              do: Enum.sum(kill_intervals) / length(kill_intervals),
              else: 600

          # 5 minutes
          short_intervals = Enum.count(kill_intervals, &(&1 < 300))

          # Consider it a gate camp if >60% of kills happen within 5 minutes of each other
          length(kill_intervals) > 0 and short_intervals / length(kill_intervals) > 0.6 and
            avg_interval < 180
        )
  end

  defp extract_key_stats(analysis) do
    [
      %{label: "Duration", value: "#{analysis.summary.time_span.duration_minutes} minutes"},
      %{label: "Participants", value: analysis.metrics.participation.unique_pilots},
      %{label: "ISK Destroyed", value: format_isk(analysis.metrics.destruction.total_isk)},
      %{label: "Ships Lost", value: analysis.metrics.destruction.ships_destroyed}
    ]
  end

  defp determine_winner(analysis) do
    # Determine winner based on ISK efficiency and field control
    case analysis do
      %{metrics: %{efficiency: %{isk_efficiency: isk_eff}}} when isk_eff > 60 ->
        :decisive_victory

      %{metrics: %{efficiency: %{isk_efficiency: isk_eff}}} when isk_eff > 40 ->
        :tactical_victory

      %{metrics: %{efficiency: %{isk_efficiency: isk_eff}}} when isk_eff < 40 ->
        :tactical_defeat

      %{metrics: %{efficiency: %{isk_efficiency: isk_eff}}} when isk_eff < 20 ->
        :decisive_defeat

      _ ->
        :undetermined
    end
  end

  defp find_mvp(analysis) do
    # Find MVP based on damage dealt and tactical contribution
    case analysis do
      %{performance_metrics: %{individual_performance: pilots}} when is_list(pilots) ->
        pilots
        |> Enum.max_by(
          fn pilot ->
            damage = Map.get(pilot, :damage_dealt, 0)
            kills = Map.get(pilot, :final_blows, 0)
            # Composite score
            damage * 0.7 + kills * 1000 * 0.3
          end,
          fn -> nil end
        )
        |> case do
          nil ->
            nil

          pilot ->
            %{
              character_id: Map.get(pilot, :character_id),
              character_name:
                EveDmv.Eve.NameResolver.character_name(Map.get(pilot, :character_id, 0)),
              damage_dealt: Map.get(pilot, :damage_dealt, 0),
              final_blows: Map.get(pilot, :final_blows, 0)
            }
        end

      _ ->
        nil
    end
  end

  defp identify_turning_point(analysis) do
    # Identify turning point based on timeline analysis
    case analysis do
      %{timeline: %{events: events}} when is_list(events) and length(events) > 5 ->
        # Find the event with the biggest shift in momentum
        # Look for high-value kills or multiple simultaneous kills
        events
        |> Enum.with_index()
        |> Enum.max_by(
          fn {event, _idx} ->
            isk_value = get_in(event, [:victim, :zkb, "totalValue"]) || 0
            # Weight by both ISK value and tactical importance
            ship_type_id = get_in(event, [:victim, "ship_type_id"])

            tactical_weight =
              case EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id || 0) do
                :capital -> 3.0
                :supercapital -> 4.0
                _ -> 1.0
              end

            isk_value * tactical_weight
          end,
          fn -> nil end
        )
        |> case do
          nil ->
            nil

          {event, idx} ->
            %{
              event_index: idx,
              timestamp: event.timestamp,
              description:
                "High-value kill: #{get_in(event, [:victim, "ship_name"]) || "Unknown ship"}",
              isk_value: get_in(event, [:victim, :zkb, "totalValue"]) || 0
            }
        end

      _ ->
        nil
    end
  end

  defp find_notable_kills(analysis) do
    # Find notable kills based on ISK value and ship importance
    case analysis do
      %{timeline: %{events: events}} when is_list(events) ->
        events
        |> Enum.filter(fn event ->
          isk_value = get_in(event, [:victim, :zkb, "totalValue"]) || 0
          ship_type_id = get_in(event, [:victim, "ship_type_id"]) || 0
          ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id)

          # Notable if high ISK value or important ship class
          isk_value > 100_000_000 or ship_class in [:capital, :supercapital]
        end)
        |> Enum.sort_by(&(get_in(&1, [:victim, :zkb, "totalValue"]) || 0), :desc)
        |> Enum.take(5)
        |> Enum.map(fn event ->
          %{
            killmail_id: event.killmail_id,
            victim_name: get_in(event, [:victim, "character_name"]) || "Unknown",
            ship_name: get_in(event, [:victim, "ship_name"]) || "Unknown Ship",
            isk_value: get_in(event, [:victim, :zkb, "totalValue"]) || 0,
            timestamp: event.timestamp
          }
        end)

      _ ->
        []
    end
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

  defp count_pod_kills(killmails) do
    Enum.count(killmails, fn km ->
      ship_type_id = get_in(km.victim, ["ship_type_id"])
      # Capsules/Pods have type IDs 670 and 33_328
      ship_type_id in [670, 33_328]
    end)
  end

  defp calculate_isk_efficiency(killmails, _participants) do
    # ISK efficiency = (ISK destroyed / (ISK destroyed + ISK lost)) * 100
    # For simplicity, calculate based on total ISK in battle
    total_isk = calculate_total_isk(killmails)

    if total_isk > 0 do
      # In a real implementation, we'd separate destroyed vs lost
      # For now, return a placeholder efficiency
      50.0
    else
      0.0
    end
  end

  defp calculate_kd_ratio(participants) do
    # Calculate kill/death ratio across all participants
    total_kills = Map.get(participants, :total_kills, 0)
    total_losses = Map.get(participants, :total_losses, 0)

    if total_losses > 0 do
      Float.round(total_kills / total_losses, 2)
    else
      total_kills
    end
  end

  defp calculate_average_on_kill(killmails) do
    # Calculate average number of attackers per kill
    total_attackers =
      Enum.reduce(killmails, 0, fn km, acc ->
        acc + length(km.attackers || [])
      end)

    if length(killmails) > 0 do
      Float.round(total_attackers / length(killmails), 1)
    else
      0.0
    end
  end

  defp generate_headline(analysis) do
    # Generate a headline based on battle analysis
    case analysis do
      %{summary: %{scale: scale}, metrics: %{destruction: %{total_isk: isk}}} ->
        scale_text = scale |> to_string() |> String.replace("_", " ") |> String.capitalize()
        isk_text = format_isk(isk)
        "#{scale_text} engagement - #{isk_text} destroyed"

      _ ->
        "Battle analysis complete"
    end
  end
end
