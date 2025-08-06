defmodule EveDmv.Contexts.Combat.Core.PerformanceCalculator do
  @moduledoc """
  Calculates comprehensive performance metrics for battles, ships, and participants.

  Provides metrics including:
  - Individual pilot performance
  - Ship effectiveness ratings
  - Fleet performance analysis
  - ISK efficiency calculations
  - Damage application metrics
  """

  alias EveDmv.Core.Utils.DateTimeUtils

  @doc """
  Calculate comprehensive performance metrics for a battle.
  """
  def calculate_metrics(killmails, participants) do
    {:ok,
     %{
       battle_metrics: calculate_battle_metrics(killmails),
       participant_metrics: calculate_participant_metrics(killmails, participants),
       ship_performance: calculate_ship_performance(killmails),
       efficiency_metrics: calculate_efficiency_metrics(killmails, participants),
       damage_metrics: calculate_damage_metrics(killmails)
     }}
  end

  @doc """
  Calculate performance metrics for a specific ship in battle.
  """
  def get_ship_performance(killmails, ship_id) do
    ship_killmails =
      killmails
      |> Enum.filter(fn km ->
        involves_ship?(km, ship_id)
      end)

    if length(ship_killmails) > 0 do
      {:ok, analyze_ship_performance(ship_killmails, ship_id)}
    else
      {:error, :ship_not_found}
    end
  end

  @doc """
  Calculate overall battle performance metrics.
  """
  def calculate_performance_metrics(killmails) do
    {:ok,
     %{
       intensity: calculate_battle_intensity(killmails),
       efficiency: calculate_overall_efficiency(killmails),
       lethality: calculate_lethality_rating(killmails),
       decisiveness: calculate_decisiveness(killmails)
     }}
  end

  # Battle Metrics

  defp calculate_battle_metrics(killmails) do
    %{
      total_damage_dealt: calculate_total_damage(killmails),
      average_time_to_kill: calculate_average_ttk(killmails),
      kill_velocity: calculate_kill_velocity(killmails),
      isk_velocity: calculate_isk_velocity(killmails),
      peak_performance_window: find_peak_performance_window(killmails),
      performance_consistency: calculate_performance_consistency(killmails)
    }
  end

  defp calculate_total_damage(killmails) do
    Enum.reduce(killmails, 0, fn km, acc ->
      victim_damage = get_in(km.victim, ["damage_taken"]) || 0
      acc + victim_damage
    end)
  end

  defp calculate_average_ttk(killmails) do
    # Group kills by time windows to estimate TTK
    time_windows =
      killmails
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [km1, km2] ->
        DateTimeUtils.diff(km2.killmail_time, km1.killmail_time, :second)
      end)
      # Only consider kills within 5 minutes
      |> Enum.filter(&(&1 < 300))

    if length(time_windows) > 0 do
      Enum.sum(time_windows) / length(time_windows)
    else
      0
    end
  end

  defp calculate_kill_velocity(killmails) do
    if length(killmails) < 2 do
      0
    else
      duration =
        DateTimeUtils.diff(
          List.last(killmails).killmail_time,
          List.first(killmails).killmail_time,
          :minute
        )

      if duration > 0 do
        length(killmails) / duration
      else
        length(killmails)
      end
    end
  end

  defp calculate_isk_velocity(killmails) do
    total_isk =
      Enum.reduce(killmails, 0.0, fn km, acc ->
        acc + (get_in(km.zkb, ["totalValue"]) || 0.0)
      end)

    if length(killmails) < 2 do
      total_isk
    else
      duration =
        DateTimeUtils.diff(
          List.last(killmails).killmail_time,
          List.first(killmails).killmail_time,
          :minute
        )

      if duration > 0 do
        total_isk / duration
      else
        total_isk
      end
    end
  end

  defp find_peak_performance_window(killmails) do
    # Find 5-minute window with highest activity
    windows =
      killmails
      |> Enum.chunk_every(10, 1, :discard)
      |> Enum.filter(fn window ->
        first = List.first(window).killmail_time
        last = List.last(window).killmail_time
        DateTimeUtils.diff(last, first, :minute) <= 5
      end)
      |> Enum.map(fn window ->
        %{
          start_time: List.first(window).killmail_time,
          end_time: List.last(window).killmail_time,
          kills: length(window),
          isk_destroyed:
            Enum.reduce(window, 0.0, fn km, acc ->
              acc + (get_in(km.zkb, ["totalValue"]) || 0.0)
            end)
        }
      end)

    Enum.max_by(windows, & &1.kills, fn -> nil end)
  end

  defp calculate_performance_consistency(killmails) do
    # Measure how consistent kill rate is
    # 2-minute slots
    time_slots = create_time_slots(killmails, 2)

    kills_per_slot = Enum.map(time_slots, & &1.kill_count)

    if length(kills_per_slot) > 1 do
      avg = Enum.sum(kills_per_slot) / length(kills_per_slot)

      variance =
        kills_per_slot
        |> Enum.map(fn count -> :math.pow(count - avg, 2) end)
        |> Enum.sum()
        |> Kernel./(length(kills_per_slot))

      std_dev = :math.sqrt(variance)

      # Lower coefficient of variation = more consistent
      if avg > 0 do
        consistency = 1 - std_dev / avg
        max(consistency * 100, 0)
      else
        0
      end
    else
      # Single slot is perfectly consistent
      100
    end
  end

  # Participant Metrics

  defp calculate_participant_metrics(killmails, participants) do
    participants.all_participants
    |> Enum.map(fn participant ->
      metrics = calculate_individual_performance(participant, killmails)
      {participant.character_id, metrics}
    end)
    |> Map.new()
  end

  defp calculate_individual_performance(participant, killmails) do
    _participant_kills = filter_participant_kills(killmails, participant.character_id)

    %{
      kills: participant[:kills] || 0,
      deaths: participant[:deaths] || 0,
      damage_dealt: participant[:total_damage_done] || 0,
      damage_taken: participant[:total_damage_taken] || 0,
      final_blows: participant[:final_blows] || 0,
      kill_participation_rate: calculate_participation_rate(participant, killmails),
      efficiency_rating: calculate_participant_efficiency(participant),
      performance_score: calculate_performance_score(participant),
      activity_metrics: %{
        first_appearance: participant[:first_appearance],
        last_appearance: participant[:last_appearance],
        active_duration: participant[:active_duration],
        engagement_rate: participant[:engagement_rate]
      }
    }
  end

  defp filter_participant_kills(killmails, character_id) do
    Enum.filter(killmails, fn km ->
      victim_match = get_in(km.victim, ["character_id"]) == character_id

      attacker_match =
        Enum.any?(km.attackers || [], fn attacker ->
          attacker["character_id"] == character_id
        end)

      victim_match || attacker_match
    end)
  end

  defp calculate_participation_rate(participant, killmails) do
    appearances = participant[:appearances] || 0
    total_kills = length(killmails)

    if total_kills > 0 do
      appearances / total_kills * 100
    else
      0
    end
  end

  defp calculate_participant_efficiency(participant) do
    damage_dealt = participant[:total_damage_done] || 0
    damage_taken = participant[:total_damage_taken] || 1

    kills = participant[:kills] || 0
    deaths = max(participant[:deaths] || 0, 1)

    # Combined efficiency score
    damage_efficiency = damage_dealt / damage_taken
    kd_efficiency = kills / deaths

    (damage_efficiency * 0.6 + kd_efficiency * 0.4) * 100
  end

  defp calculate_performance_score(participant) do
    # Comprehensive performance score
    base_score = 50

    # Positive factors
    kill_score = (participant[:kills] || 0) * 5
    final_blow_score = (participant[:final_blows] || 0) * 3
    damage_score = (participant[:total_damage_done] || 0) / 1_000_000 * 2
    survival_bonus = if participant[:deaths] == 0, do: 20, else: 0

    # Negative factors
    death_penalty = (participant[:deaths] || 0) * 10

    score =
      base_score + kill_score + final_blow_score + damage_score +
        survival_bonus - death_penalty

    max(score, 0)
  end

  # Ship Performance

  defp calculate_ship_performance(killmails) do
    killmails
    |> extract_all_ships()
    |> Enum.group_by(& &1.ship_type_id)
    |> Enum.map(fn {ship_type_id, instances} ->
      {ship_type_id, analyze_ship_type_performance(instances, killmails)}
    end)
    |> Map.new()
  end

  defp extract_all_ships(killmails) do
    victim_ships =
      killmails
      |> Enum.map(fn km ->
        %{
          ship_type_id: get_in(km.victim, ["ship_type_id"]),
          ship_name: get_in(km.victim, ["ship_name"]),
          role: :victim,
          character_id: get_in(km.victim, ["character_id"]),
          damage_taken: get_in(km.victim, ["damage_taken"]) || 0,
          value: get_in(km.zkb, ["totalValue"]) || 0
        }
      end)

    attacker_ships =
      killmails
      |> Enum.flat_map(fn km ->
        (km.attackers || [])
        |> Enum.map(fn attacker ->
          %{
            ship_type_id: attacker["ship_type_id"],
            ship_name: attacker["ship_type_name"],
            role: :attacker,
            character_id: attacker["character_id"],
            damage_done: attacker["damage_done"] || 0,
            final_blow: attacker["final_blow"] || false
          }
        end)
      end)

    victim_ships ++ attacker_ships
  end

  defp analyze_ship_type_performance(instances, _killmails) do
    losses = Enum.count(instances, &(&1.role == :victim))
    fielded = length(Enum.uniq_by(instances, & &1.character_id))

    damage_dealt =
      instances
      |> Enum.filter(&(&1.role == :attacker))
      |> Enum.reduce(0, &(&1.damage_done + &2))

    damage_taken =
      instances
      |> Enum.filter(&(&1.role == :victim))
      |> Enum.reduce(0, &(&1.damage_taken + &2))

    final_blows =
      instances
      |> Enum.count(&(&1[:final_blow] == true))

    %{
      fielded_count: fielded,
      losses: losses,
      survival_rate: calculate_survival_rate(fielded, losses),
      damage_dealt: damage_dealt,
      damage_taken: damage_taken,
      damage_ratio: calculate_damage_ratio(damage_dealt, damage_taken),
      final_blows: final_blows,
      effectiveness_rating: calculate_ship_effectiveness(instances),
      average_lifetime: estimate_average_lifetime(instances)
    }
  end

  defp calculate_survival_rate(fielded, losses) do
    if fielded > 0 do
      (fielded - losses) / fielded * 100
    else
      0
    end
  end

  defp calculate_damage_ratio(dealt, taken) do
    if taken > 0 do
      dealt / taken
    else
      dealt
    end
  end

  defp calculate_ship_effectiveness(instances) do
    # Consider multiple factors for ship effectiveness
    attacker_instances = Enum.filter(instances, &(&1.role == :attacker))
    victim_instances = Enum.filter(instances, &(&1.role == :victim))

    attack_score =
      if length(attacker_instances) > 0 do
        avg_damage =
          Enum.sum(Enum.map(attacker_instances, & &1.damage_done)) /
            length(attacker_instances)

        # Max 50 points for damage
        min(avg_damage / 10_000 * 50, 50)
      else
        0
      end

    survival_score =
      if length(instances) > 0 do
        survival_rate = (length(instances) - length(victim_instances)) / length(instances)
        # Max 50 points for survival
        survival_rate * 50
      else
        0
      end

    attack_score + survival_score
  end

  defp estimate_average_lifetime(_instances) do
    # Would need actual time data for each ship appearance
    # For now, return placeholder
    "~5 minutes"
  end

  defp analyze_ship_performance(killmails, ship_id) do
    ship_instances =
      killmails
      |> extract_all_ships()
      |> Enum.filter(fn ship ->
        ship.ship_type_id == ship_id || ship[:ship_id] == ship_id
      end)

    analyze_ship_type_performance(ship_instances, killmails)
  end

  # Efficiency Metrics

  defp calculate_efficiency_metrics(killmails, participants) do
    sides = participants.by_affiliation || %{}

    %{
      overall_efficiency: calculate_overall_efficiency(killmails),
      isk_efficiency: calculate_isk_efficiency(killmails, sides),
      damage_efficiency: calculate_damage_efficiency(killmails),
      target_selection_efficiency: calculate_target_selection_efficiency(killmails),
      force_application_efficiency: calculate_force_application_efficiency(killmails)
    }
  end

  defp calculate_overall_efficiency(killmails) do
    # Composite efficiency score
    kill_rate = calculate_kill_velocity(killmails)
    isk_rate = calculate_isk_velocity(killmails)

    # Normalize and combine
    normalized_kills = min(kill_rate * 10, 50)
    normalized_isk = min(isk_rate / 1_000_000_000 * 50, 50)

    normalized_kills + normalized_isk
  end

  defp calculate_isk_efficiency(killmails, sides) do
    # Calculate ISK efficiency for each side
    sides
    |> Enum.map(fn {side, members} ->
      member_ids = MapSet.new(Enum.map(members, & &1.character_id))

      destroyed =
        killmails
        |> Enum.filter(fn km ->
          Enum.any?(km.attackers || [], fn attacker ->
            MapSet.member?(member_ids, attacker["character_id"])
          end)
        end)
        |> Enum.reduce(0.0, fn km, acc ->
          acc + (get_in(km.zkb, ["totalValue"]) || 0.0)
        end)

      lost =
        killmails
        |> Enum.filter(fn km ->
          MapSet.member?(member_ids, get_in(km.victim, ["character_id"]))
        end)
        |> Enum.reduce(0.0, fn km, acc ->
          acc + (get_in(km.zkb, ["totalValue"]) || 0.0)
        end)

      efficiency =
        if lost > 0 do
          destroyed / (destroyed + lost) * 100
        else
          100.0
        end

      {side,
       %{
         destroyed: destroyed,
         lost: lost,
         efficiency: efficiency
       }}
    end)
    |> Map.new()
  end

  defp calculate_damage_efficiency(killmails) do
    total_damage_dealt = calculate_total_damage(killmails)
    total_ships_destroyed = length(killmails)

    if total_ships_destroyed > 0 do
      %{
        average_damage_per_kill: total_damage_dealt / total_ships_destroyed,
        overkill_percentage: estimate_overkill_percentage(killmails),
        damage_distribution: analyze_damage_distribution(killmails)
      }
    else
      %{
        average_damage_per_kill: 0,
        overkill_percentage: 0,
        damage_distribution: :unknown
      }
    end
  end

  defp estimate_overkill_percentage(killmails) do
    # Estimate based on number of attackers vs typical requirements
    overkill_instances =
      Enum.count(killmails, fn km ->
        attacker_count = length(km.attackers || [])
        ship_class = classify_ship_size(get_in(km.victim, ["ship_type_id"]))

        case ship_class do
          :frigate -> attacker_count > 3
          :cruiser -> attacker_count > 10
          :battleship -> attacker_count > 20
          :capital -> attacker_count > 50
          _ -> false
        end
      end)

    if length(killmails) > 0 do
      overkill_instances / length(killmails) * 100
    else
      0
    end
  end

  defp classify_ship_size(ship_type_id) do
    cond do
      ship_type_id < 1000 -> :frigate
      ship_type_id < 3000 -> :cruiser
      ship_type_id < 5000 -> :battleship
      ship_type_id >= 20_000 -> :capital
      true -> :unknown
    end
  end

  defp analyze_damage_distribution(killmails) do
    distributions =
      killmails
      |> Enum.map(fn km ->
        attackers = km.attackers || []

        if length(attackers) > 0 do
          damages = Enum.map(attackers, &(&1["damage_done"] || 0))
          max_damage = Enum.max(damages, fn -> 0 end)
          total_damage = Enum.sum(damages)

          classify_damage_concentration(max_damage, total_damage)
        else
          :unknown
        end
      end)

    # Most common distribution pattern
    distributions
    |> Enum.frequencies()
    |> Enum.max_by(fn {_pattern, count} -> count end, fn -> {:unknown, 0} end)
    |> elem(0)
  end

  defp classify_damage_concentration(max_damage, total_damage) do
    if total_damage > 0 do
      concentration = max_damage / total_damage

      cond do
        concentration > 0.7 -> :highly_concentrated
        concentration > 0.4 -> :moderately_concentrated
        true -> :well_distributed
      end
    else
      :unknown
    end
  end

  defp calculate_target_selection_efficiency(killmails) do
    # Analyze how well targets were prioritized
    target_values =
      killmails
      |> Enum.with_index()
      |> Enum.map(fn {km, index} ->
        %{
          index: index,
          value: get_in(km.zkb, ["totalValue"]) || 0,
          ship_class: classify_ship_size(get_in(km.victim, ["ship_type_id"])),
          strategic_value: assess_strategic_value(km)
        }
      end)

    %{
      high_value_target_priority: calculate_hvt_priority(target_values),
      strategic_target_focus: calculate_strategic_focus(target_values),
      target_selection_pattern: identify_targeting_pattern(target_values)
    }
  end

  defp assess_strategic_value(killmail) do
    ship_type = get_in(killmail.victim, ["ship_type_id"])

    cond do
      logistics_ship?(ship_type) -> :critical
      command_ship?(ship_type) -> :high
      ewar_ship?(ship_type) -> :high
      capital_ship?(ship_type) -> :very_high
      true -> :standard
    end
  end

  defp logistics_ship?(ship_type) do
    EveDmv.StaticData.ShipRoles.logistics_ship?(ship_type)
  end

  defp command_ship?(ship_type) do
    EveDmv.StaticData.ShipRoles.command_ship?(ship_type)
  end

  defp ewar_ship?(ship_type) do
    EveDmv.StaticData.ShipRoles.ewar_ship?(ship_type)
  end

  defp capital_ship?(ship_type) when is_integer(ship_type), do: ship_type >= 20_000

  defp calculate_hvt_priority(target_values) do
    # Check if high-value targets were killed early
    high_value_threshold =
      target_values
      |> Enum.map(& &1.value)
      |> Enum.sort(:desc)
      |> Enum.take(div(length(target_values), 4))
      |> List.last()
      |> Kernel.||(0)

    hvt_positions =
      target_values
      |> Enum.filter(&(&1.value >= high_value_threshold))
      |> Enum.map(& &1.index)

    if length(hvt_positions) > 0 do
      avg_position = Enum.sum(hvt_positions) / length(hvt_positions)
      total_targets = length(target_values)

      # Lower average position = killed earlier = better
      priority_score = (1 - avg_position / total_targets) * 100

      cond do
        priority_score > 70 -> :excellent
        priority_score > 50 -> :good
        priority_score > 30 -> :moderate
        true -> :poor
      end
    else
      :unknown
    end
  end

  defp calculate_strategic_focus(target_values) do
    strategic_targets =
      Enum.filter(target_values, fn target ->
        target.strategic_value in [:critical, :high, :very_high]
      end)

    if length(target_values) > 0 do
      focus_percentage = length(strategic_targets) / length(target_values) * 100

      cond do
        focus_percentage > 50 -> :highly_focused
        focus_percentage > 30 -> :moderately_focused
        focus_percentage > 10 -> :some_focus
        true -> :unfocused
      end
    else
      :unknown
    end
  end

  defp identify_targeting_pattern(target_values) do
    # Analyze the order of target elimination
    ship_class_order =
      target_values
      |> Enum.map(& &1.ship_class)

    cond do
      starts_with_small_ships?(ship_class_order) -> :bottom_up
      starts_with_large_ships?(ship_class_order) -> :top_down
      true -> :opportunistic
    end
  end

  defp starts_with_small_ships?(ship_classes) do
    first_third = Enum.take(ship_classes, div(length(ship_classes), 3))
    Enum.count(first_third, &(&1 == :frigate)) > length(first_third) / 2
  end

  defp starts_with_large_ships?(ship_classes) do
    first_third = Enum.take(ship_classes, div(length(ship_classes), 3))
    Enum.count(first_third, &(&1 in [:battleship, :capital])) > length(first_third) / 2
  end

  defp calculate_force_application_efficiency(killmails) do
    # How efficiently was force applied?
    %{
      average_attackers_per_kill: calculate_average_attackers(killmails),
      force_concentration: analyze_force_concentration(killmails),
      simultaneous_engagements: count_simultaneous_engagements(killmails),
      alpha_strike_usage: detect_alpha_strikes(killmails)
    }
  end

  defp calculate_average_attackers(killmails) do
    total_attackers =
      killmails
      |> Enum.reduce(0, fn km, acc ->
        acc + length(km.attackers || [])
      end)

    if length(killmails) > 0 do
      total_attackers / length(killmails)
    else
      0
    end
  end

  defp analyze_force_concentration(killmails) do
    # Measure how well force was concentrated vs spread
    attacker_distributions =
      killmails
      |> Enum.map(fn km ->
        length(km.attackers || [])
      end)

    if length(attacker_distributions) > 0 do
      avg = Enum.sum(attacker_distributions) / length(attacker_distributions)

      variance =
        attacker_distributions
        |> Enum.map(fn count -> :math.pow(count - avg, 2) end)
        |> Enum.sum()
        |> Kernel./(length(attacker_distributions))

      std_dev = :math.sqrt(variance)
      cv = if avg > 0, do: std_dev / avg, else: 0

      cond do
        cv < 0.3 -> :highly_concentrated
        cv < 0.6 -> :moderately_concentrated
        cv < 0.9 -> :somewhat_spread
        true -> :highly_spread
      end
    else
      :unknown
    end
  end

  defp count_simultaneous_engagements(killmails) do
    # Count kills happening within 30 seconds of each other
    killmails
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.count(fn [km1, km2] ->
      DateTimeUtils.diff(km2.killmail_time, km1.killmail_time, :second) <= 30
    end)
  end

  defp detect_alpha_strikes(killmails) do
    # Detect coordinated high-damage attacks
    alpha_candidates =
      killmails
      |> Enum.filter(fn km ->
        victim_ehp = estimate_ship_ehp(get_in(km.victim, ["ship_type_id"]))
        damage_taken = get_in(km.victim, ["damage_taken"]) || 0
        attacker_count = length(km.attackers || [])

        # High damage relative to EHP with many attackers suggests alpha
        damage_taken > victim_ehp * 0.8 && attacker_count > 10
      end)

    %{
      alpha_strike_count: length(alpha_candidates),
      alpha_strike_percentage:
        if length(killmails) > 0 do
          length(alpha_candidates) / length(killmails) * 100
        else
          0
        end
    }
  end

  defp estimate_ship_ehp(ship_type_id) do
    # Simplified EHP estimation
    cond do
      ship_type_id < 1000 -> 5_000
      ship_type_id < 3000 -> 30_000
      ship_type_id < 5000 -> 100_000
      ship_type_id >= 20_000 -> 1_000_000
      true -> 20_000
    end
  end

  # Damage Metrics

  defp calculate_damage_metrics(killmails) do
    %{
      total_damage: calculate_total_damage(killmails),
      damage_patterns: analyze_damage_patterns(killmails),
      weapon_effectiveness: analyze_weapon_effectiveness(killmails),
      damage_types: analyze_damage_types(killmails)
    }
  end

  defp analyze_damage_patterns(killmails) do
    %{
      burst_damage_usage: detect_burst_damage(killmails),
      sustained_damage_rating: rate_sustained_damage(killmails),
      focus_fire_effectiveness: analyze_focus_fire_damage(killmails)
    }
  end

  defp detect_burst_damage(killmails) do
    # Look for high damage in short time
    burst_instances =
      killmails
      |> Enum.filter(fn km ->
        damage = get_in(km.victim, ["damage_taken"]) || 0
        ehp = estimate_ship_ehp(get_in(km.victim, ["ship_type_id"]))
        damage > ehp * 1.5
      end)

    %{
      burst_kill_count: length(burst_instances),
      burst_percentage:
        if length(killmails) > 0 do
          length(burst_instances) / length(killmails) * 100
        else
          0
        end
    }
  end

  defp rate_sustained_damage(killmails) do
    # Rate ability to maintain damage output
    damage_over_time = create_damage_timeline(killmails)

    if length(damage_over_time) > 1 do
      consistency = calculate_output_consistency(damage_over_time)

      cond do
        consistency > 0.8 -> :excellent
        consistency > 0.6 -> :good
        consistency > 0.4 -> :moderate
        true -> :poor
      end
    else
      :unknown
    end
  end

  defp create_damage_timeline(killmails) do
    killmails
    |> Enum.group_by(fn km ->
      km.killmail_time
      |> DateTimeUtils.truncate_to_minute()
    end)
    |> Enum.map(fn {time, kills} ->
      total_damage =
        kills
        |> Enum.reduce(0, fn km, acc ->
          acc + (get_in(km.victim, ["damage_taken"]) || 0)
        end)

      %{time: time, damage: total_damage}
    end)
    |> Enum.sort_by(& &1.time)
  end

  defp calculate_output_consistency(damage_timeline) do
    damages = Enum.map(damage_timeline, & &1.damage)

    if length(damages) > 0 do
      avg = Enum.sum(damages) / length(damages)

      variance =
        damages
        |> Enum.map(fn d -> :math.pow(d - avg, 2) end)
        |> Enum.sum()
        |> Kernel./(length(damages))

      std_dev = :math.sqrt(variance)

      if avg > 0 do
        1 - std_dev / avg
      else
        0
      end
    else
      0
    end
  end

  defp analyze_focus_fire_damage(killmails) do
    # Analyze how well damage was focused
    focus_scores =
      killmails
      |> Enum.map(fn km ->
        attackers = km.attackers || []

        if length(attackers) > 1 do
          damages = Enum.map(attackers, &(&1["damage_done"] || 0))
          total = Enum.sum(damages)
          max_damage = Enum.max(damages, fn -> 0 end)

          # Measure damage concentration
          if total > 0 do
            1 - max_damage / total
          else
            0
          end
        else
          # Single attacker is perfect focus
          1.0
        end
      end)

    avg_focus =
      if length(focus_scores) > 0 do
        Enum.sum(focus_scores) / length(focus_scores)
      else
        0
      end

    %{
      average_focus_score: avg_focus * 100,
      rating:
        cond do
          avg_focus > 0.8 -> :excellent
          avg_focus > 0.6 -> :good
          avg_focus > 0.4 -> :moderate
          true -> :poor
        end
    }
  end

  defp analyze_weapon_effectiveness(killmails) do
    weapon_stats =
      killmails
      |> Enum.flat_map(fn km ->
        (km.attackers || [])
        |> Enum.map(fn attacker ->
          %{
            weapon_type: attacker["weapon_type_id"],
            damage_done: attacker["damage_done"] || 0,
            final_blow: attacker["final_blow"] || false
          }
        end)
      end)
      |> Enum.group_by(& &1.weapon_type)
      |> Enum.map(fn {weapon_type, uses} ->
        {weapon_type,
         %{
           total_damage: Enum.sum(Enum.map(uses, & &1.damage_done)),
           usage_count: length(uses),
           final_blows: Enum.count(uses, & &1.final_blow),
           average_damage: Enum.sum(Enum.map(uses, & &1.damage_done)) / max(length(uses), 1)
         }}
      end)
      |> Map.new()

    %{
      weapon_diversity: map_size(weapon_stats),
      most_effective_weapons:
        weapon_stats
        |> Enum.sort_by(fn {_type, stats} -> stats.average_damage end, :desc)
        |> Enum.take(5),
      weapon_statistics: weapon_stats
    }
  end

  defp analyze_damage_types(_killmails) do
    # Would analyze actual damage types (EM, Thermal, etc.)
    # For now return placeholder
    %{
      primary_damage_type: :mixed,
      damage_type_distribution: %{
        em: 25,
        thermal: 25,
        kinetic: 25,
        explosive: 25
      }
    }
  end

  # Helper Functions

  defp create_time_slots(killmails, slot_duration_minutes) do
    if Enum.empty?(killmails) do
      []
    else
      sorted = Enum.sort_by(killmails, & &1.killmail_time)
      start_time = List.first(sorted).killmail_time
      end_time = List.last(sorted).killmail_time

      slot_count =
        div(DateTimeUtils.diff(end_time, start_time, :minute), slot_duration_minutes) + 1

      0..(slot_count - 1)
      |> Enum.map(fn i ->
        slot_start = DateTimeUtils.add(start_time, i * slot_duration_minutes * 60, :second)
        slot_end = DateTimeUtils.add(slot_start, slot_duration_minutes * 60, :second)

        kills_in_slot =
          Enum.filter(sorted, fn km ->
            DateTimeUtils.compare(km.killmail_time, slot_start) != :lt &&
              DateTimeUtils.compare(km.killmail_time, slot_end) == :lt
          end)

        %{
          start_time: slot_start,
          end_time: slot_end,
          kill_count: length(kills_in_slot),
          kills: kills_in_slot
        }
      end)
    end
  end

  defp involves_ship?(killmail, ship_id) do
    victim_match = get_in(killmail.victim, ["ship_type_id"]) == ship_id

    attacker_match =
      Enum.any?(killmail.attackers || [], fn attacker ->
        attacker["ship_type_id"] == ship_id
      end)

    victim_match || attacker_match
  end

  defp calculate_battle_intensity(killmails) do
    kill_velocity = calculate_kill_velocity(killmails)

    cond do
      kill_velocity > 2.0 -> :extreme
      kill_velocity > 1.0 -> :high
      kill_velocity > 0.5 -> :moderate
      kill_velocity > 0.2 -> :low
      true -> :minimal
    end
  end

  defp calculate_lethality_rating(killmails) do
    avg_ttk = calculate_average_ttk(killmails)
    burst_damage = detect_burst_damage(killmails)

    base_lethality_score = 50

    # Quick kills increase lethality
    lethality_with_ttk_bonus =
      if avg_ttk < 30 do
        base_lethality_score + 30
      else
        base_lethality_score + max(30 - avg_ttk / 10, 0)
      end

    # Burst damage increases lethality
    final_lethality_score = lethality_with_ttk_bonus + burst_damage.burst_percentage * 0.2

    %{
      score: min(final_lethality_score, 100),
      rating:
        cond do
          final_lethality_score > 80 -> :extreme
          final_lethality_score > 60 -> :high
          final_lethality_score > 40 -> :moderate
          final_lethality_score > 20 -> :low
          true -> :minimal
        end
    }
  end

  defp calculate_decisiveness(killmails) do
    # How decisive was the engagement?
    if length(killmails) < 2 do
      :inconclusive
    else
      duration =
        DateTimeUtils.diff(
          List.last(killmails).killmail_time,
          List.first(killmails).killmail_time,
          :minute
        )

      kills_per_minute = length(killmails) / max(duration, 1)

      cond do
        kills_per_minute > 1.0 && duration < 10 -> :swift_victory
        kills_per_minute > 0.5 && duration < 20 -> :decisive
        duration > 60 -> :prolonged_engagement
        true -> :standard_engagement
      end
    end
  end
end
