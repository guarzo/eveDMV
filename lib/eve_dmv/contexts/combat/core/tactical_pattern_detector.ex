defmodule EveDmv.Contexts.Combat.Core.TacticalPatternDetector do
  @moduledoc """
  Detects tactical patterns and strategies used in combat.

  Identifies patterns such as:
  - Focus fire coordination
  - Target calling effectiveness
  - Engagement tactics (kiting, brawling, etc.)
  - Electronic warfare usage
  - Capital deployment strategies
  - Bombing runs
  """
  """

  alias EveDmv.Contexts.Combat.Core.TimelineBuilder
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.StaticData.ShipTypes

  @doc """
  Detect tactical patterns from killmails and timeline data.
  """
  def detect_patterns(killmails, timeline) do
    patterns =
      []
      |> detect_focus_fire_patterns(killmails)
      |> detect_engagement_patterns(killmails, timeline)
      |> detect_ewar_patterns(killmails)
      |> detect_capital_patterns(killmails, timeline)
      |> detect_bombing_patterns(killmails)
      |> detect_coordination_patterns(killmails, timeline)

    {:ok,
     %{
       patterns: patterns,
       primary_tactics: identify_primary_tactics(patterns),
       coordination_score: calculate_coordination_score(patterns),
       tactical_timeline: build_tactical_timeline(patterns, timeline)
     }}
  end

  @doc """
  Analyze engagement tactics for a specific battle.
  """
  def analyze_engagement_tactics(killmails) do
    with {:ok, timeline} <- TimelineBuilder.build_timeline(killmails),
         {:ok, patterns} <- detect_patterns(killmails, timeline) do
      {:ok,
       %{
         engagement_style: determine_engagement_style(patterns),
         range_control: analyze_range_control(patterns),
         positioning: analyze_positioning(patterns),
         adaptability: measure_tactical_adaptability(patterns, timeline)
       }}
    end
  end

  # Pattern Detection Functions

  defp detect_focus_fire_patterns(patterns, killmails) do
    focus_fire_instances =
      killmails
      |> Enum.chunk_every(5, 1, :discard)
      |> Enum.filter(&focus_fire_sequence?/1)
      |> Enum.map(&analyze_focus_fire/1)

    if length(focus_fire_instances) > 0 do
      pattern = %{
        type: :focus_fire,
        instances: focus_fire_instances,
        effectiveness: calculate_focus_fire_effectiveness(focus_fire_instances),
        coordination_level: assess_coordination_level(focus_fire_instances)
      }

      [pattern | patterns]
    else
      patterns
    end
  end

  defp focus_fire_sequence?(killmail_chunk) do
    # Check if kills happen in rapid succession with overlapping attackers
    times = Enum.map(killmail_chunk, & &1.killmail_time)

    # All kills within 2 minutes
    first_time = List.first(times)
    last_time = List.last(times)
    time_span = DateTimeUtils.diff(last_time, first_time, :second)

    if time_span <= 120 do
      # Check for overlapping attackers
      attacker_sets =
        killmail_chunk
        |> Enum.map(fn km ->
          (km.attackers || [])
          |> Enum.map(& &1["character_id"])
          |> MapSet.new()
        end)

      # Find common attackers across kills
      common_attackers =
        Enum.reduce(attacker_sets, fn set, acc ->
          MapSet.intersection(acc, set)
        end)

      MapSet.size(common_attackers) >= 3
    else
      false
    end
  end

  defp analyze_focus_fire(killmail_sequence) do
    %{
      start_time: List.first(killmail_sequence).killmail_time,
      end_time: List.last(killmail_sequence).killmail_time,
      targets_eliminated: length(killmail_sequence),
      average_time_to_kill: calculate_average_ttk(killmail_sequence),
      participating_pilots: count_unique_attackers(killmail_sequence),
      target_progression: analyze_target_progression(killmail_sequence)
    }
  end

  defp analyze_target_progression(killmail_sequence) do
    # Analyze how targets were prioritized and eliminated
    targets =
      Enum.map(killmail_sequence, fn km ->
        %{
          character_id: get_in(km.victim, ["character_id"]),
          ship_type_id: get_in(km.victim, ["ship_type_id"]),
          time: km.killmail_time,
          value: get_in(km.zkb, ["totalValue"]) || 0
        }
      end)

    %{
      total_targets: length(targets),
      high_value_first: analyze_value_priority(targets),
      ship_type_focus: analyze_ship_type_priority(targets)
    }
  end

  defp analyze_value_priority(targets) do
    # Check if high-value targets were prioritized
    sorted_by_time = Enum.sort_by(targets, & &1.time)
    sorted_by_value = Enum.sort_by(targets, & &1.value, :desc)

    # Compare order correlation
    time_order = Enum.map(sorted_by_time, & &1.character_id)
    value_order = Enum.map(sorted_by_value, & &1.character_id)

    correlation_score = calculate_order_correlation(time_order, value_order)
    correlation_score > 0.5
  end

  defp analyze_ship_type_priority(targets) do
    # Analyze if certain ship types were targeted first
    ship_types = Enum.map(targets, & &1.ship_type_id)
    ship_type_counts = Enum.frequencies(ship_types)

    most_common =
      ship_type_counts
      |> Enum.max_by(fn {_ship, count} -> count end, fn -> {nil, 0} end)
      |> elem(0)

    %{most_targeted_ship_type: most_common}
  end

  defp calculate_order_correlation(list1, list2) do
    # Simple correlation calculation
    if length(list1) <= 1 do
      0.0
    else
      matches =
        Enum.zip(list1, list2)
        |> Enum.count(fn {a, b} -> a == b end)

      matches / length(list1)
    end
  end

  defp calculate_focus_fire_effectiveness(instances) do
    avg_ttk =
      instances
      |> Enum.map(& &1.average_time_to_kill)
      |> Enum.filter(&is_number/1)
      |> average()

    cond do
      avg_ttk < 20 -> :excellent
      avg_ttk < 40 -> :good
      avg_ttk < 60 -> :moderate
      true -> :poor
    end
  end

  defp assess_coordination_level(instances) do
    # Look at how consistently the same group attacks together
    pilot_consistency =
      instances
      |> Enum.map(& &1.participating_pilots)
      |> calculate_set_consistency()

    cond do
      pilot_consistency > 0.8 -> :high
      pilot_consistency > 0.6 -> :moderate
      pilot_consistency > 0.4 -> :low
      true -> :minimal
    end
  end

  defp detect_engagement_patterns(patterns, killmails, timeline) do
    engagement_pattern = analyze_engagement_style(killmails, timeline)

    if engagement_pattern do
      [engagement_pattern | patterns]
    else
      patterns
    end
  end

  defp analyze_engagement_style(killmails, timeline) do
    # Analyze positioning and movement patterns
    positions = extract_positions(killmails)
    ranges = calculate_engagement_ranges(positions)

    style =
      cond do
        kiting_pattern?(ranges, timeline) -> :kiting
        brawling_pattern?(ranges) -> :brawling
        hit_and_run?(timeline) -> :hit_and_run
        gate_camp?(positions) -> :gate_camp
        true -> :mixed
      end

    %{
      type: :engagement_style,
      style: style,
      average_range: average(ranges),
      range_variation: standard_deviation(ranges),
      positioning_data: analyze_positioning_tactics(positions)
    }
  end

  defp extract_positions(killmails) do
    killmails
    |> Enum.map(fn km ->
      %{
        time: km.killmail_time,
        position: get_in(km.victim, ["position"]),
        victim_id: get_in(km.victim, ["character_id"]),
        attackers: extract_attacker_positions(km)
      }
    end)
    |> Enum.reject(&is_nil(&1.position))
  end

  defp extract_attacker_positions(_killmail) do
    # In real implementation, would have attacker positions
    # For now, return empty list
    []
  end

  defp calculate_engagement_ranges(positions) do
    # Return empty ranges since position data is not available in killmails
    # This prevents analysis of range-based patterns until position data is implemented
    if Enum.empty?(positions) do
      []
    else
      # Return default range estimates based on ship types if available
      # Without actual position data, we cannot determine real engagement ranges
      []
    end
  end

  defp kiting_pattern?(ranges, _timeline) do
    # High average range with consistent distance maintenance
    avg_range = average(ranges)
    range_consistency = standard_deviation(ranges) / max(avg_range, 1)

    avg_range > 30 && range_consistency < 0.3
  end

  defp brawling_pattern?(ranges) do
    # Close range engagement
    avg_range = average(ranges)
    avg_range < 10
  end

  defp hit_and_run?(timeline) do
    # Check for engagement gaps in timeline
    phases = timeline[:phases] || []

    gap_count =
      phases
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.count(fn [p1, p2] ->
        DateTimeUtils.diff(p2.start_time, p1.end_time, :minute) > 5
      end)

    gap_count > 2
  end

  defp gate_camp?(positions) do
    # Check if kills happen at similar positions (near gate)
    unique_positions =
      positions
      |> Enum.map(& &1.position)
      |> Enum.uniq()

    length(unique_positions) == 1
  end

  defp detect_ewar_patterns(patterns, killmails) do
    ewar_usage = analyze_ewar_usage(killmails)

    if ewar_usage.total_ewar_ships > 0 do
      pattern = %{
        type: :electronic_warfare,
        ewar_types: ewar_usage.types_used,
        ewar_ship_count: ewar_usage.total_ewar_ships,
        effectiveness: ewar_usage.effectiveness,
        targets_affected: ewar_usage.affected_targets
      }

      [pattern | patterns]
    else
      patterns
    end
  end

  defp analyze_ewar_usage(killmails) do
    ewar_ships =
      killmails
      |> Enum.flat_map(fn km ->
        (km.attackers || [])
        |> Enum.filter(&ewar_ship?(&1["ship_type_id"]))
      end)

    %{
      total_ewar_ships: length(ewar_ships),
      types_used: detect_ewar_types(ewar_ships),
      effectiveness: estimate_ewar_effectiveness(ewar_ships, killmails),
      affected_targets: count_ewar_affected_targets(killmails)
    }
  end

  defp ewar_ship?(ship_type_id) do
    ship_type_id && ShipTypes.ewar?(ship_type_id)
  end

  defp detect_ewar_types(_ewar_ships) do
    # Would analyze actual ship types to determine ECM, damps, etc.
    [:ecm, :sensor_dampening, :target_painting]
  end

  defp estimate_ewar_effectiveness(_ewar_ships, _killmails) do
    # Would analyze impact on targets
    :moderate
  end

  defp count_ewar_affected_targets(_killmails) do
    # Would count unique targets affected by EWAR
    0
  end

  defp detect_capital_patterns(patterns, killmails, timeline) do
    capitals_involved =
      killmails
      |> Enum.filter(&involves_capital?/1)

    if length(capitals_involved) > 0 do
      pattern = %{
        type: :capital_warfare,
        deployment_strategy: analyze_capital_deployment(capitals_involved, timeline),
        capital_losses: count_capital_losses(capitals_involved),
        escalation_timeline: track_capital_escalation(capitals_involved),
        support_fleet_ratio: calculate_support_ratio(capitals_involved, killmails)
      }

      [pattern | patterns]
    else
      patterns
    end
  end

  defp involves_capital?(killmail) do
    capital_ship?(get_in(killmail.victim, ["ship_type_id"])) ||
      Enum.any?(killmail.attackers || [], fn attacker ->
        capital_ship?(attacker["ship_type_id"])
      end)
  end

  defp capital_ship?(ship_type_id) do
    ship_type_id && ShipTypes.is_ship_class?(ship_type_id, :capital)
  end

  defp analyze_capital_deployment(capital_kills, _timeline) do
    # Analyze how capitals were deployed
    cond do
      length(capital_kills) > 10 -> :mass_deployment
      length(capital_kills) > 5 -> :strategic_deployment
      length(capital_kills) > 2 -> :limited_deployment
      true -> :minimal_deployment
    end
  end

  defp count_capital_losses(capital_kills) do
    Enum.count(capital_kills, fn km ->
      capital_ship?(get_in(km.victim, ["ship_type_id"]))
    end)
  end

  defp track_capital_escalation(capital_kills) do
    # Track when capitals appeared in battle
    capital_kills
    |> Enum.map(& &1.killmail_time)
    |> Enum.sort()
    |> then(fn times ->
      %{
        first_capital: List.first(times),
        escalation_duration:
          if length(times) > 1 do
            DateTimeUtils.diff(List.last(times), List.first(times), :minute)
          else
            0
          end
      }
    end)
  end

  defp calculate_support_ratio(capital_kills, all_kills) do
    capital_count = length(capital_kills)
    total_count = length(all_kills)
    subcap_count = total_count - capital_count

    if capital_count > 0 do
      subcap_count / capital_count
    else
      0
    end
  end

  defp detect_bombing_patterns(patterns, killmails) do
    potential_bomb_runs =
      killmails
      |> detect_simultaneous_kills()
      |> Enum.filter(&could_be_bomb_run?/1)

    if length(potential_bomb_runs) > 0 do
      pattern = %{
        type: :bombing_runs,
        instances: potential_bomb_runs,
        success_rate: calculate_bombing_success(potential_bomb_runs),
        bomber_coordination: assess_bomber_coordination(potential_bomb_runs)
      }

      [pattern | patterns]
    else
      patterns
    end
  end

  defp detect_simultaneous_kills(killmails) do
    killmails
    |> Enum.group_by(fn km ->
      km.killmail_time
      |> DateTime.truncate(:minute)
    end)
    |> Enum.filter(fn {_time, kills} -> length(kills) >= 3 end)
    |> Enum.map(fn {time, kills} -> %{time: time, kills: kills} end)
  end

  defp could_be_bomb_run?(simultaneous_kills) do
    # Check if attackers are using bombers
    bomber_count =
      simultaneous_kills.kills
      |> Enum.flat_map(fn km ->
        (km.attackers || [])
        |> Enum.filter(&bomber?(&1["ship_type_id"]))
      end)
      |> length()

    bomber_count >= 5
  end

  defp bomber?(ship_type_id) do
    # Check if ship is a stealth bomber using database lookup
    if ship_type_id do
      case ShipTypes.classify_ship_type(ship_type_id) do
        :frigate ->
          # Query database for stealth bomber group specifically
          import Ecto.Query

          case from(i in EveDmv.Eve.ItemType,
                 where: i.type_id == ^ship_type_id and i.group_name == "Stealth Bomber",
                 select: i.type_id
               )
               |> EveDmv.Repo.one() do
            nil -> false
            _ -> true
          end

        _ ->
          false
      end
    else
      false
    end
  end

  defp calculate_bombing_success(bomb_runs) do
    successful =
      Enum.count(bomb_runs, fn run ->
        length(run.kills) >= 5
      end)

    if length(bomb_runs) > 0 do
      successful / length(bomb_runs) * 100
    else
      0
    end
  end

  defp assess_bomber_coordination(bomb_runs) do
    # Look at timing precision
    avg_kills_per_run =
      bomb_runs
      |> Enum.map(fn run -> length(run.kills) end)
      |> average()

    cond do
      avg_kills_per_run > 10 -> :excellent
      avg_kills_per_run > 5 -> :good
      avg_kills_per_run > 3 -> :moderate
      true -> :poor
    end
  end

  defp detect_coordination_patterns(patterns, killmails, timeline) do
    coordination_analysis = analyze_fleet_coordination(killmails, timeline)

    pattern = %{
      type: :fleet_coordination,
      target_calling_efficiency: coordination_analysis.target_efficiency,
      response_time: coordination_analysis.avg_response_time,
      fleet_cohesion: coordination_analysis.cohesion_score,
      command_structure: infer_command_structure(coordination_analysis)
    }

    [pattern | patterns]
  end

  defp analyze_fleet_coordination(killmails, _timeline) do
    # Analyze how well the fleet works together
    target_sequences = identify_target_sequences(killmails)

    %{
      target_efficiency: calculate_target_calling_efficiency(target_sequences),
      avg_response_time: calculate_average_response_time(target_sequences),
      cohesion_score: calculate_fleet_cohesion(killmails),
      pilot_coordination: analyze_pilot_coordination(killmails)
    }
  end

  defp identify_target_sequences(killmails) do
    # Group kills by corporation/alliance to identify coordinated targeting
    killmails
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.filter(fn chunk ->
      # Same victim corp/alliance in sequence
      victim_corps =
        chunk
        |> Enum.map(&get_in(&1.victim, ["corporation_id"]))
        |> Enum.uniq()

      length(victim_corps) == 1
    end)
  end

  defp calculate_target_calling_efficiency(sequences) do
    if length(sequences) > 0 do
      # High efficiency = quick target elimination
      avg_sequence_time =
        sequences
        |> Enum.map(fn seq ->
          first = List.first(seq).killmail_time
          last = List.last(seq).killmail_time
          DateTimeUtils.diff(last, first, :second)
        end)
        |> average()

      cond do
        avg_sequence_time < 60 -> :excellent
        avg_sequence_time < 120 -> :good
        avg_sequence_time < 180 -> :moderate
        true -> :poor
      end
    else
      :unknown
    end
  end

  defp calculate_average_response_time(_sequences) do
    # Would calculate time between target calls and kills
    # seconds
    30
  end

  defp calculate_fleet_cohesion(killmails) do
    # How well do pilots stick together on kills?
    attacker_overlap =
      killmails
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [km1, km2] ->
        attackers1 = (km1.attackers || []) |> Enum.map(& &1["character_id"]) |> MapSet.new()
        attackers2 = (km2.attackers || []) |> Enum.map(& &1["character_id"]) |> MapSet.new()

        if MapSet.size(attackers1) > 0 && MapSet.size(attackers2) > 0 do
          MapSet.size(MapSet.intersection(attackers1, attackers2)) /
            MapSet.size(MapSet.union(attackers1, attackers2))
        else
          0
        end
      end)
      |> average()

    attacker_overlap * 100
  end

  defp analyze_pilot_coordination(killmails) do
    # Analyze how pilots coordinate attacks
    %{
      average_pilots_per_kill: calculate_average_attackers(killmails),
      pilot_consistency: calculate_pilot_consistency(killmails)
    }
  end

  defp calculate_average_attackers(killmails) do
    killmails
    |> Enum.map(fn km -> length(km.attackers || []) end)
    |> average()
  end

  defp calculate_pilot_consistency(killmails) do
    # How consistently do the same pilots appear together?
    all_attacker_sets =
      killmails
      |> Enum.map(fn km ->
        (km.attackers || [])
        |> Enum.map(& &1["character_id"])
        |> MapSet.new()
      end)

    calculate_set_consistency(all_attacker_sets)
  end

  defp infer_command_structure(coordination_analysis) do
    # Infer command structure based on coordination patterns
    cond do
      coordination_analysis.target_efficiency == :excellent &&
          coordination_analysis.cohesion_score > 70 ->
        :centralized_fc

      coordination_analysis.cohesion_score > 50 ->
        :wing_commanders

      coordination_analysis.cohesion_score > 30 ->
        :squad_leaders

      true ->
        :minimal_structure
    end
  end

  # Helper Functions

  defp identify_primary_tactics(patterns) do
    patterns
    |> Enum.sort_by(&pattern_importance/1, :desc)
    |> Enum.take(3)
    |> Enum.map(& &1.type)
  end

  defp pattern_importance(pattern) do
    case pattern.type do
      :capital_warfare -> 10
      :bombing_runs -> 8
      :focus_fire -> 7
      :electronic_warfare -> 6
      :engagement_style -> 5
      :fleet_coordination -> 4
      _ -> 1
    end
  end

  defp calculate_coordination_score(patterns) do
    coordination_pattern = Enum.find(patterns, &(&1.type == :fleet_coordination))
    focus_fire_pattern = Enum.find(patterns, &(&1.type == :focus_fire))

    base_score = 50

    score_with_coordination =
      if coordination_pattern do
        base_score + effectiveness_to_score(coordination_pattern.target_calling_efficiency)
      else
        base_score
      end

    final_score =
      if focus_fire_pattern do
        score_with_coordination + effectiveness_to_score(focus_fire_pattern.effectiveness) * 0.5
      else
        score_with_coordination
      end

    min(final_score, 100)
  end

  defp effectiveness_to_score(:excellent), do: 40
  defp effectiveness_to_score(:good), do: 30
  defp effectiveness_to_score(:moderate), do: 20
  defp effectiveness_to_score(:poor), do: 10
  defp effectiveness_to_score(_), do: 0

  defp build_tactical_timeline(patterns, timeline) do
    # Merge tactical patterns with battle timeline
    events =
      (timeline[:events] || [])
      |> Enum.map(fn event ->
        relevant_patterns = find_patterns_at_time(patterns, event.time)
        Map.put(event, :tactical_patterns, relevant_patterns)
      end)

    %{
      events: events,
      pattern_progression: track_pattern_progression(patterns)
    }
  end

  defp find_patterns_at_time(patterns, time) do
    patterns
    |> Enum.filter(fn pattern ->
      case pattern do
        %{instances: instances} ->
          Enum.any?(instances, fn instance ->
            DateTimeUtils.compare(instance.start_time, time) != :gt &&
              DateTimeUtils.compare(instance.end_time, time) != :lt
          end)

        _ ->
          false
      end
    end)
    |> Enum.map(& &1.type)
  end

  defp track_pattern_progression(patterns) do
    # Track how tactics evolved during battle
    patterns
    |> Enum.sort_by(&pattern_start_time/1)
    |> Enum.map(fn pattern ->
      %{
        type: pattern.type,
        start_time: pattern_start_time(pattern),
        effectiveness: Map.get(pattern, :effectiveness, :unknown)
      }
    end)
  end

  defp pattern_start_time(pattern) do
    case pattern do
      %{instances: [first | _]} -> first.start_time
      %{time: time} -> time
      _ -> nil
    end
  end

  defp determine_engagement_style(patterns) do
    engagement = Enum.find(patterns, &(&1.type == :engagement_style))
    if engagement, do: engagement.style, else: :unknown
  end

  defp analyze_range_control(patterns) do
    engagement = Enum.find(patterns, &(&1.type == :engagement_style))

    if engagement do
      %{
        average_range: engagement.average_range,
        range_variation: engagement.range_variation,
        control_rating: rate_range_control(engagement)
      }
    else
      %{average_range: 0, range_variation: 0, control_rating: :unknown}
    end
  end

  defp rate_range_control(engagement) do
    # Low variation = good range control
    variation_ratio = engagement.range_variation / max(engagement.average_range, 1)

    cond do
      variation_ratio < 0.2 -> :excellent
      variation_ratio < 0.4 -> :good
      variation_ratio < 0.6 -> :moderate
      true -> :poor
    end
  end

  defp analyze_positioning(patterns) do
    engagement = Enum.find(patterns, &(&1.type == :engagement_style))

    if engagement && engagement[:positioning_data] do
      engagement.positioning_data
    else
      %{positioning_quality: :unknown}
    end
  end

  defp analyze_positioning_tactics(_positions) do
    # Would analyze actual positioning data
    %{
      positioning_quality: :moderate,
      formation_type: :spread,
      anchor_usage: false
    }
  end

  defp measure_tactical_adaptability(patterns, timeline) do
    # How well did tactics adapt during battle?
    pattern_changes = track_pattern_progression(patterns)
    phase_changes = timeline[:phases] || []

    %{
      adaptation_score: calculate_adaptation_score(pattern_changes, phase_changes),
      tactical_flexibility: assess_tactical_flexibility(patterns),
      response_to_threats: analyze_threat_response(patterns, timeline)
    }
  end

  defp calculate_adaptation_score(pattern_changes, phase_changes) do
    # More pattern changes in response to phase changes = higher score
    if length(phase_changes) > 0 do
      changes_per_phase = length(pattern_changes) / length(phase_changes)
      min(changes_per_phase * 30, 100)
    else
      50
    end
  end

  defp assess_tactical_flexibility(patterns) do
    unique_tactics =
      patterns
      |> Enum.map(& &1.type)
      |> Enum.uniq()
      |> length()

    cond do
      unique_tactics >= 5 -> :high
      unique_tactics >= 3 -> :moderate
      unique_tactics >= 2 -> :low
      true -> :minimal
    end
  end

  defp analyze_threat_response(_patterns, _timeline) do
    # Would analyze how tactics changed in response to threats
    :adaptive
  end

  # Utility functions

  defp average([]), do: 0

  defp average(list) do
    Enum.sum(list) / length(list)
  end

  defp standard_deviation([]), do: 0

  defp standard_deviation(list) do
    avg = average(list)

    variance =
      list
      |> Enum.map(fn x -> :math.pow(x - avg, 2) end)
      |> average()

    :math.sqrt(variance)
  end

  defp calculate_average_ttk(killmail_sequence) do
    if length(killmail_sequence) > 1 do
      times = Enum.map(killmail_sequence, & &1.killmail_time)
      first = List.first(times)
      last = List.last(times)

      DateTimeUtils.diff(last, first, :second) / (length(killmail_sequence) - 1)
    else
      0
    end
  end

  defp count_unique_attackers(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      (km.attackers || [])
      |> Enum.map(& &1["character_id"])
    end)
    |> Enum.uniq()
    |> length()
  end

  defp calculate_set_consistency(sets) do
    if length(sets) < 2 do
      1.0
    else
      overlaps =
        sets
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [set1, set2] ->
          if MapSet.size(set1) > 0 && MapSet.size(set2) > 0 do
            MapSet.size(MapSet.intersection(set1, set2)) /
              MapSet.size(MapSet.union(set1, set2))
          else
            0
          end
        end)

      average(overlaps)
    end
  end
end
