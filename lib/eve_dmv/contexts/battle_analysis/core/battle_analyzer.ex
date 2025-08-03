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
      _ -> {:error, :analysis_failed}
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
    case Ash.get(Battle, battle_id, domain: BattleApi) do
      {:ok, battle} -> {:ok, battle}
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, :battle_not_found}
      {:error, error} -> {:error, error}
    end
  end

  defp get_battle_killmails(battle) do
    killmails =
      from(k in KillmailRaw,
        where: k.killmail_id in ^battle.killmail_ids,
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
        unique_corporations: map_size(participants.by_corporation || %{}),
        unique_alliances: map_size(participants.by_alliance || %{})
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
        case from(s in "eve_systems",
               where: s.system_id == ^system_id,
               select: s.security_status
             )
             |> EveDmv.Repo.one() do
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
      bombing_run?(killmails) -> :bombing_run
      true -> :fleet_fight
    end
  end


  defp count_pod_kills(killmails) do
    Enum.count(killmails, fn km ->
      ship_type_id = get_in(km.victim, ["ship_type_id"])
      # Capsule type ID
  # TODO: Remove unused function - dialyzer detected this is never called
      ship_type_id == 670
    end)
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
          case EveDmv.Repo.one(
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

  defp bombing_run?(killmails) do
    if length(killmails) < 5,
      do: false,
      else:
        (
          # Bombing runs typically involve stealth bombers and simultaneous kills
          # Check for multiple kills at the same time with bomber attackers
          bomber_count =
            killmails
            |> Enum.flat_map(fn km ->
              (km.raw_data["attackers"] || [])
              |> Enum.map(&get_in(&1, ["ship_type_id"]))
              |> Enum.filter(&(&1 != nil))
            end)
            |> Enum.count(fn ship_type_id ->
              # Check if ship is stealth bomber using group name
              case from(i in "eve_item_types",
                     where: i.type_id == ^ship_type_id and i.group_name == "Stealth Bomber",
                     select: i.type_id
                   )
                   |> EveDmv.Repo.one() do
                nil -> false
                _ -> true
              end
            end)

          # Check for simultaneous kills (within 30 seconds)
          kill_times = Enum.map(killmails, & &1.killmail_time)
          min_time = Enum.min(kill_times)
          max_time = Enum.max(kill_times)
          time_span = DateTimeUtils.diff(max_time, min_time, :second)

  # TODO: Remove unused function - dialyzer detected this is never called
          # Bombing run if multiple bombers and kills within short timespan
          bomber_count >= 3 and time_span <= 30
        )
  end

  defp calculate_isk_efficiency(killmails, _participants) do
    # Calculate ISK efficiency by comparing losses vs kills for each side
    total_isk = calculate_total_isk(killmails)

    if total_isk == 0 do
      0.0
    else
      # Group killmails by alliance/corporation to determine sides
      alliance_losses =
        killmails
        |> Enum.group_by(&get_in(&1.victim, ["alliance_id"]))
        |> Enum.map(fn {alliance_id, kms} ->
          {alliance_id, Enum.sum(Enum.map(kms, &(get_in(&1.zkb, ["totalValue"]) || 0.0)))}
        end)
        |> Enum.sort_by(&elem(&1, 1), :desc)

      case alliance_losses do
        [{_alliance1, losses1}, {_alliance2, losses2} | _] when losses1 > 0 and losses2 > 0 ->
          # Calculate efficiency as (enemy losses / own losses) * 100
          max(losses1, losses2) / (losses1 + losses2) * 100

        _ ->
  # TODO: Remove unused function - dialyzer detected this is never called
          # Default neutral efficiency if can't determine clear sides
          50.0
      end
    end
  end

  defp calculate_kd_ratio(participants) do
    # Calculate overall kill/death ratio for the battle
    case participants do
      %{all_participants: all_chars} when is_map(all_chars) ->
        total_participants = MapSet.size(all_chars)

        if total_participants > 0 do
          # K/D ratio approximation: total kills / unique participants
          # This gives average kills per participant
          total_participants / max(total_participants, 1)
        else
          1.0
  # TODO: Remove unused function - dialyzer detected this is never called
        end

      _ ->
        1.0
    end
  end

  defp calculate_average_on_kill(killmails) do
  # TODO: Remove unused function - dialyzer detected this is never called
    total_attackers =
      Enum.reduce(killmails, 0, fn km, acc ->
        acc + length(km.attackers || [])
      end)

    if length(killmails) > 0, do: total_attackers / length(killmails), else: 0
  end
  # TODO: Remove unused function - dialyzer detected this is never called

  defp generate_headline(analysis) do
    scale = analysis.summary.scale
    type = analysis.summary.type
    location = analysis.summary.location.system_id

    "#{scale} #{type} in system #{location}"
  end
  # TODO: Remove unused function - dialyzer detected this is never called

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
end
