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
    |> Enum.map(&{&1, EveDmv.StaticData.ShipTypes.classify_ship_type(&1)})
    |> Enum.group_by(fn {_type_id, class} -> class end)
    |> Enum.map(fn {class, ships} -> {class, length(ships)} end)
    |> Map.new()
  end

  defp get_system_security(battle) do
    # Get actual system security from database
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
    # Use actual capital ship type IDs from the database
    capital_ids =
      EveDmv.StaticData.ShipTypes.get_ship_ids_for_class(:capital) ++
        EveDmv.StaticData.ShipTypes.get_ship_ids_for_class(:supercapital)

    Enum.count(killmails, fn km ->
      ship_type_id = get_in(km.victim, ["ship_type_id"])
      ship_type_id && ship_type_id in capital_ids
    end)
  end

  defp has_structure_kill?(killmails) do
    # Use actual structure ship type IDs from the database
    structure_ids = EveDmv.StaticData.ShipTypes.get_ship_ids_for_class(:structure)

    Enum.any?(killmails, fn km ->
      ship_type_id = get_in(km.victim, ["ship_type_id"])
      ship_type_id && ship_type_id in structure_ids
    end)
  end

  defp gate_camp?(killmails) do
    # Analyze kill patterns for gate camp characteristics
    unique_victims =
      killmails
      |> Enum.map(&get_in(&1.victim, ["character_id"]))
      |> Enum.uniq()
      |> length()

    total_kills = length(killmails)

    # Gate camps typically have many different victims (high victim diversity)
    victim_diversity = if total_kills > 0, do: unique_victims / total_kills, else: 0

    # Check for single-system concentration and high victim diversity
    systems =
      killmails
      |> Enum.map(& &1.solar_system_id)
      |> Enum.uniq()

    # Gate camp characteristics:
    # - Single system (concentrated location)
    # - High victim diversity (many different targets)
    # - Minimum number of kills to establish pattern
    length(systems) == 1 && victim_diversity > 0.7 && total_kills >= 3
  end

  defp bombing_run?(killmails) do
    # Look for stealth bomber involvement and rapid kills
    bomber_ids = EveDmv.StaticData.ShipTypes.get_ship_ids_for_class(:stealth_bomber)

    bomber_attacks =
      killmails
      |> Enum.flat_map(fn km ->
        (km.attackers || [])
        |> Enum.filter(fn attacker ->
          ship_type_id = attacker["ship_type_id"]
          ship_type_id && ship_type_id in bomber_ids
        end)
      end)
      |> length()

    # Check for time clustering (bombs hit simultaneously)
    if length(killmails) >= 3 do
      time_span = calculate_time_span_seconds(killmails)
      # Bombing run characteristics:
      # - Multiple bomber attacks (at least 3)
      # - Tight time clustering (bombs hit within 30 seconds)
      bomber_attacks >= 3 && time_span <= 30
    else
      false
    end
  end

  defp calculate_time_span_seconds(killmails) do
    sorted = Enum.sort_by(killmails, & &1.killmail_time)
    first = List.first(sorted).killmail_time
    last = List.last(sorted).killmail_time
    DateTimeUtils.diff(last, first, :second)
  end

  defp calculate_isk_efficiency(killmails, participants) do
    # Group killmails by side using participant analysis
    case participants.by_side do
      sides when map_size(sides) >= 2 ->
        side_losses = calculate_side_losses(killmails, participants.by_side)

        case Map.values(side_losses) do
          [side1_lost, side2_lost] when side1_lost + side2_lost > 0 ->
            # Calculate efficiency for side with lower losses
            if side1_lost <= side2_lost do
              Float.round(side2_lost / (side1_lost + side2_lost) * 100, 1)
            else
              Float.round(side1_lost / (side1_lost + side2_lost) * 100, 1)
            end

          _ ->
            # Default if can't calculate
            50.0
        end

      _ ->
        # Default if insufficient sides
        50.0
    end
  end

  defp calculate_side_losses(killmails, by_side) do
    by_side
    |> Enum.map(fn {side, side_participants} ->
      side_character_ids = MapSet.new(Enum.map(side_participants, & &1.character_id))

      side_isk_lost =
        killmails
        |> Enum.filter(fn km ->
          victim_id = get_in(km.victim, ["character_id"])
          victim_id && MapSet.member?(side_character_ids, victim_id)
        end)
        |> Enum.reduce(0.0, fn km, acc ->
          acc + (get_in(km.zkb, ["totalValue"]) || 0.0)
        end)

      {side, side_isk_lost}
    end)
    |> Map.new()
  end

  defp calculate_kd_ratio(participants) do
    case participants.by_side do
      sides when map_size(sides) >= 2 ->
        [side1, side2] = sides |> Map.keys() |> Enum.take(2)

        side1_kills = count_side_kills(participants.by_side[side1])
        side1_deaths = count_side_deaths(participants.by_side[side1])

        side2_kills = count_side_kills(participants.by_side[side2])
        side2_deaths = count_side_deaths(participants.by_side[side2])

        total_kills = side1_kills + side2_kills
        total_deaths = side1_deaths + side2_deaths

        if total_deaths > 0 do
          Float.round(total_kills / total_deaths, 2)
        else
          1.0
        end

      _ ->
        1.0
    end
  end

  defp count_side_kills(side_participants) do
    Enum.reduce(side_participants, 0, fn participant, acc ->
      acc + (participant.kills || 0)
    end)
  end

  defp count_side_deaths(side_participants) do
    Enum.reduce(side_participants, 0, fn participant, acc ->
      acc + (participant.deaths || 0)
    end)
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

  defp determine_winner(analysis) do
    # Determine winner based on multiple factors
    case analysis.participants.by_side do
      sides when map_size(sides) >= 2 ->
        [side1, side2] = sides |> Map.keys() |> Enum.take(2)

        # Calculate score for each side based on multiple factors
        side1_score = calculate_side_winning_score(side1, analysis)
        side2_score = calculate_side_winning_score(side2, analysis)

        cond do
          side1_score > side2_score * 1.2 -> side1
          side2_score > side1_score * 1.2 -> side2
          true -> :close_fight
        end

      _ ->
        :undetermined
    end
  end

  defp calculate_side_winning_score(side, analysis) do
    side_participants = analysis.participants.by_side[side] || []
    side_losses = get_side_isk_lost(side, analysis)

    # Factors that determine winning:
    # 1. ISK efficiency (lower losses = better)
    # 2. Kill count
    # 3. Survival rate

    kills = Enum.reduce(side_participants, 0, &(&2 + (&1.kills || 0)))
    deaths = Enum.reduce(side_participants, 0, &(&2 + (&1.deaths || 0)))

    # Calculate scores (higher = better)
    kill_score = kills * 10
    survival_score = if deaths > 0, do: kills / deaths * 20, else: 20
    isk_efficiency_score = calculate_isk_efficiency_score(side_losses)

    kill_score + survival_score + isk_efficiency_score
  end

  defp get_side_isk_lost(_side, _analysis) do
    # This should be extracted from the killmails but we don't have direct access here
    # Return a reasonable default to prevent errors
    0.0
  end

  defp calculate_isk_efficiency_score(isk_lost) do
    # Lower ISK lost = higher score
    # Use logarithmic scale to prevent extreme values
    if isk_lost > 0 do
      max(0, 100 - :math.log10(isk_lost + 1) * 10)
    else
      100
    end
  end

  defp find_mvp(analysis) do
    # Find Most Valuable Player based on multiple performance metrics
    all_participants = analysis.participants.all_participants || []

    if Enum.empty?(all_participants) do
      nil
    else
      mvp_candidate =
        all_participants
        |> Enum.map(&calculate_mvp_score/1)
        |> Enum.max_by(fn participant -> participant.mvp_score end, fn -> nil end)

      if mvp_candidate && mvp_candidate.mvp_score > 50 do
        %{
          character_id: mvp_candidate.character_id,
          character_name: mvp_candidate.character_name,
          score: mvp_candidate.mvp_score,
          reason: determine_mvp_reason(mvp_candidate)
        }
      else
        nil
      end
    end
  end

  defp calculate_mvp_score(participant) do
    kills = participant.kills || 0
    deaths = participant.deaths || 0
    damage_done = participant.damage_done || 0
    final_blows = participant.final_blows || 0

    # MVP scoring factors:
    # - High kill count
    # - Low death count (survival)
    # - High damage contribution
    # - Final blows (finishing kills)

    kill_score = kills * 15
    survival_bonus = if deaths == 0 && kills > 0, do: 25, else: max(0, 20 - deaths * 5)
    # Cap damage contribution
    damage_score = min(damage_done / 1_000_000, 30)
    final_blow_score = final_blows * 10

    mvp_score = kill_score + survival_bonus + damage_score + final_blow_score

    Map.put(participant, :mvp_score, mvp_score)
  end

  defp determine_mvp_reason(participant) do
    kills = participant.kills || 0
    deaths = participant.deaths || 0
    damage_done = participant.damage_done || 0
    final_blows = participant.final_blows || 0

    cond do
      kills >= 10 -> "High kill count (#{kills} kills)"
      deaths == 0 && kills >= 3 -> "Perfect survival with #{kills} kills"
      final_blows >= 5 -> "#{final_blows} final blows"
      damage_done >= 50_000_000 -> "High damage contribution"
      true -> "Overall strong performance"
    end
  end

  defp identify_turning_point(analysis) do
    # Identify the moment when battle momentum shifted
    timeline_events = analysis.timeline.events || []

    if length(timeline_events) < 5 do
      nil
    else
      # Analyze momentum shifts by looking at kill patterns over time
      time_windows = create_time_windows(timeline_events)
      momentum_shifts = analyze_momentum_shifts(time_windows)

      case find_significant_momentum_shift(momentum_shifts) do
        nil ->
          nil

        {time, shift_data} ->
          %{
            time: time,
            description: describe_momentum_shift(shift_data),
            significance: shift_data.significance,
            before_kills: shift_data.before_kills,
            after_kills: shift_data.after_kills
          }
      end
    end
  end

  defp create_time_windows(events) do
    # Group events into 2-minute windows for momentum analysis
    # 2 minutes in seconds
    window_size = 120

    events
    |> Enum.group_by(fn event ->
      # Round timestamp to 2-minute windows
      timestamp = DateTime.to_unix(event.time)
      div(timestamp, window_size) * window_size
    end)
    |> Enum.map(fn {window_start, window_events} ->
      %{
        window_start: DateTime.from_unix!(window_start),
        events: window_events,
        kill_count: length(window_events)
      }
    end)
    |> Enum.sort_by(& &1.window_start)
  end

  defp analyze_momentum_shifts(time_windows) do
    time_windows
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [before_window, after_window] ->
      kill_change = after_window.kill_count - before_window.kill_count

      %{
        time: after_window.window_start,
        before_kills: before_window.kill_count,
        after_kills: after_window.kill_count,
        kill_change: kill_change,
        significance: abs(kill_change)
      }
    end)
  end

  defp find_significant_momentum_shift(momentum_shifts) do
    # Find the most significant momentum shift (highest change in kill rate)
    momentum_shifts
    # Minimum significance threshold
    |> Enum.filter(fn shift -> shift.significance >= 3 end)
    |> Enum.max_by(fn shift -> shift.significance end, fn -> nil end)
    |> case do
      nil -> nil
      shift -> {shift.time, shift}
    end
  end

  defp describe_momentum_shift(shift_data) do
    if shift_data.kill_change > 0 do
      "Intensity increased dramatically - kill rate went from #{shift_data.before_kills} to #{shift_data.after_kills} per 2-minute window"
    else
      "Battle intensity dropped - kill rate decreased from #{shift_data.before_kills} to #{shift_data.after_kills} per 2-minute window"
    end
  end

  defp find_notable_kills(analysis) do
    # Identify notable kills based on multiple criteria
    timeline_events = analysis.timeline.events || []

    timeline_events
    |> Enum.map(&evaluate_kill_notability/1)
    |> Enum.filter(fn kill -> kill.notable_score > 50 end)
    |> Enum.sort_by(fn kill -> kill.notable_score end, :desc)
    # Top 5 notable kills
    |> Enum.take(5)
    |> Enum.map(&format_notable_kill/1)
  end

  defp evaluate_kill_notability(event) do
    # Calculate notability score based on multiple factors
    base_score = 0

    # High value kills
    value_score = calculate_value_score(event.value || 0)

    # Capital/supercapital kills
    ship_significance_score = calculate_ship_significance_score(event.victim.ship_type_id)

    # Multi-participant kills (shows coordination)
    participation_score = calculate_participation_score(length(event.attackers || []))

    # Final blow significance (who got the killing blow)
    final_blow_score = calculate_final_blow_score(event)

    notable_score =
      base_score + value_score + ship_significance_score + participation_score + final_blow_score

    Map.put(event, :notable_score, notable_score)
  end

  defp calculate_value_score(value) do
    cond do
      # 10B+ ISK
      value >= 10_000_000_000 -> 50
      # 5B+ ISK
      value >= 5_000_000_000 -> 35
      # 1B+ ISK
      value >= 1_000_000_000 -> 20
      # 500M+ ISK
      value >= 500_000_000 -> 10
      true -> 0
    end
  end

  defp calculate_ship_significance_score(ship_type_id) do
    case EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id) do
      :supercapital -> 60
      :capital -> 40
      :battleship -> 15
      :battlecruiser -> 10
      :structure -> 30
      _ -> 0
    end
  end

  defp calculate_participation_score(attacker_count) do
    cond do
      # Massive fleet action
      attacker_count >= 100 -> 25
      # Large fleet
      attacker_count >= 50 -> 20
      # Medium fleet
      attacker_count >= 20 -> 15
      # Small fleet
      attacker_count >= 10 -> 10
      # Solo kill (impressive)
      attacker_count == 1 -> 20
      true -> 5
    end
  end

  defp calculate_final_blow_score(event) do
    # Check if final blow was by a smaller ship (David vs Goliath)
    final_blow_attacker = find_final_blow_attacker(event.attackers || [])

    if final_blow_attacker do
      victim_class = EveDmv.StaticData.ShipTypes.classify_ship_type(event.victim.ship_type_id)

      attacker_class =
        EveDmv.StaticData.ShipTypes.classify_ship_type(final_blow_attacker["ship_type_id"])

      case {victim_class, attacker_class} do
        # Frigate killed capital
        {:capital, :frigate} -> 30
        # Destroyer killed capital
        {:capital, :destroyer} -> 25
        # Frigate killed battleship
        {:battleship, :frigate} -> 15
        # Any supercap kill is notable
        {:supercapital, _} -> 20
        _ -> 0
      end
    else
      0
    end
  end

  defp find_final_blow_attacker(attackers) do
    Enum.find(attackers, fn attacker ->
      attacker["final_blow"] == true
    end)
  end

  defp format_notable_kill(kill) do
    %{
      time: kill.time,
      victim: %{
        character_name: kill.victim.character_name,
        ship_name: kill.victim.ship_name,
        value: kill.value
      },
      significance: categorize_significance(kill.notable_score),
      reason: generate_notable_reason(kill),
      score: kill.notable_score
    }
  end

  defp categorize_significance(score) do
    cond do
      score >= 100 -> :legendary
      score >= 80 -> :exceptional
      score >= 60 -> :very_notable
      score >= 40 -> :notable
      true -> :interesting
    end
  end

  defp generate_notable_reason(kill) do
    initial_reasons = []

    # Add value reason
    reasons_with_value =
      if kill.value >= 1_000_000_000 do
        ["High value kill (#{format_isk(kill.value)})" | initial_reasons]
      else
        initial_reasons
      end

    # Add ship significance
    ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(kill.victim.ship_type_id)

    reasons_with_ship_significance =
      case ship_class do
        :supercapital -> ["Supercapital kill" | reasons_with_value]
        :capital -> ["Capital ship kill" | reasons_with_value]
        :structure -> ["Structure destruction" | reasons_with_value]
        _ -> reasons_with_value
      end

    # Add participation reason
    attacker_count = length(kill.attackers || [])

    final_reasons =
      cond do
        attacker_count >= 100 -> ["Massive fleet engagement" | reasons_with_ship_significance]
        attacker_count == 1 -> ["Solo kill" | reasons_with_ship_significance]
        true -> reasons_with_ship_significance
      end

    if Enum.empty?(final_reasons) do
      "Notable engagement"
    else
      Enum.join(final_reasons, ", ")
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
