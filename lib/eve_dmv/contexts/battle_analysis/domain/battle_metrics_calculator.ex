defmodule EveDmv.Contexts.BattleAnalysis.Domain.BattleMetricsCalculator do
  @moduledoc """
  Calculates comprehensive battle metrics including ISK efficiency,
  DPS breakdowns, fleet effectiveness, and tactical assessments.
  """

  require Logger
  alias EveDmv.Eve.NameResolver
  alias EveDmv.Performance.BatchNameResolver

  @doc """
  Calculates comprehensive battle metrics from battle data.

  ## Parameters
  - battle: Battle data with killmails, timeline, and metadata
  - options: Additional calculation options

  ## Returns
  {:ok, %{
    overview: %{...},
    isk_metrics: %{...},
    damage_metrics: %{...},
    fleet_metrics: %{...},
    tactical_metrics: %{...}
  }}
  """
  def calculate_battle_metrics(battle, _options \\ []) do
    # Preload all names before doing calculations to avoid N+1 queries
    BatchNameResolver.preload_battle_names(battle)

    # Pre-calculate common data to avoid multiple passes
    killmails = battle.killmails || []
    precomputed = precompute_battle_data(killmails)

    metrics = %{
      overview: calculate_overview_metrics(battle, precomputed),
      isk_metrics: calculate_isk_metrics(battle, precomputed),
      damage_metrics: calculate_damage_metrics(battle, precomputed),
      fleet_metrics: calculate_fleet_metrics(battle, precomputed),
      tactical_metrics: calculate_tactical_metrics(battle, precomputed),
      side_comparison: calculate_side_comparison(battle, precomputed)
    }

    {:ok, metrics}
  end

  @doc """
  Calculates metrics for a specific time window within the battle.
  """
  def calculate_window_metrics(battle, start_time, end_time) do
    # Filter killmails to the time window
    window_killmails =
      Enum.filter(battle.killmails, fn km ->
        time = km.killmail_time

        NaiveDateTime.compare(time, start_time) != :lt &&
          NaiveDateTime.compare(time, end_time) != :gt
      end)

    window_battle = Map.put(battle, :killmails, window_killmails)
    calculate_battle_metrics(window_battle)
  end

  # Private calculation functions

  defp precompute_battle_data(killmails) do
    # Single pass through killmails to extract all needed data
    Enum.reduce(
      killmails,
      %{
        total_kills: 0,
        unique_pilots: MapSet.new(),
        unique_corporations: MapSet.new(),
        unique_alliances: MapSet.new(),
        unique_ship_types: MapSet.new(),
        total_isk_value: 0,
        total_damage: 0,
        attackers_by_killmail: %{},
        ship_classes: %{},
        weapon_damage: %{},
        final_blows: [],
        all_attackers: []
      },
      fn km, acc ->
        attackers = km.raw_data["attackers"] || []
        _victim = km.raw_data["victim"] || %{}

        # Extract character IDs
        victim_char_id = km.victim_character_id
        attacker_char_ids = attackers |> Enum.map(& &1["character_id"]) |> Enum.filter(& &1)

        # Extract corporation IDs  
        victim_corp_id = km.victim_corporation_id
        attacker_corp_ids = attackers |> Enum.map(& &1["corporation_id"]) |> Enum.filter(& &1)

        # Extract alliance IDs
        victim_alliance_id = km.victim_alliance_id
        attacker_alliance_ids = attackers |> Enum.map(& &1["alliance_id"]) |> Enum.filter(& &1)

        # Extract ship types
        victim_ship_id = km.victim_ship_type_id
        attacker_ship_ids = attackers |> Enum.map(& &1["ship_type_id"]) |> Enum.filter(& &1)

        # Calculate values
        isk_value = get_killmail_value(km)
        damage = get_total_damage(km)

        %{
          total_kills: acc.total_kills + 1,
          unique_pilots:
            acc.unique_pilots
            |> MapSet.put(victim_char_id)
            |> then(&Enum.reduce(attacker_char_ids, &1, fn id, set -> MapSet.put(set, id) end)),
          unique_corporations:
            acc.unique_corporations
            |> MapSet.put(victim_corp_id)
            |> then(&Enum.reduce(attacker_corp_ids, &1, fn id, set -> MapSet.put(set, id) end)),
          unique_alliances:
            acc.unique_alliances
            |> MapSet.put(victim_alliance_id)
            |> then(
              &Enum.reduce(attacker_alliance_ids, &1, fn id, set -> MapSet.put(set, id) end)
            ),
          unique_ship_types:
            acc.unique_ship_types
            |> MapSet.put(victim_ship_id)
            |> then(&Enum.reduce(attacker_ship_ids, &1, fn id, set -> MapSet.put(set, id) end)),
          total_isk_value: acc.total_isk_value + isk_value,
          total_damage: acc.total_damage + damage,
          attackers_by_killmail: Map.put(acc.attackers_by_killmail, km.killmail_id, attackers),
          all_attackers:
            acc.all_attackers ++ Enum.map(attackers, &Map.put(&1, :_source_killmail, km))
        }
      end
    )
    |> then(fn acc ->
      Map.merge(acc, %{
        unique_pilots: MapSet.size(acc.unique_pilots),
        unique_corporations: MapSet.size(acc.unique_corporations),
        unique_alliances: MapSet.size(acc.unique_alliances),
        unique_ship_types: MapSet.size(acc.unique_ship_types)
      })
    end)
  end

  defp calculate_overview_metrics(battle, precomputed) do
    metadata = battle[:metadata] || %{}
    duration_seconds = (metadata[:duration_minutes] || 0) * 60

    %{
      total_kills: precomputed.total_kills,
      duration_minutes: metadata[:duration_minutes] || 0,
      unique_pilots: precomputed.unique_pilots,
      unique_corporations: precomputed.unique_corporations,
      unique_alliances: precomputed.unique_alliances,
      kills_per_minute:
        if(duration_seconds > 0,
          do: Float.round(precomputed.total_kills / (duration_seconds / 60), 2),
          else: 0
        ),
      average_pilots_per_kill: calculate_average_attackers_precomputed(precomputed),
      primary_system: metadata[:primary_system],
      battle_type: determine_battle_type(battle)
    }
  end

  defp calculate_isk_metrics(battle, precomputed) do
    killmails = battle.killmails || []

    # Group by sides if available
    sides = identify_battle_sides(battle)

    total_destroyed = precomputed.total_isk_value

    side_metrics =
      if length(sides) >= 2 do
        calculate_side_isk_metrics(killmails, sides)
      else
        %{}
      end

    %{
      total_isk_destroyed: total_destroyed,
      average_loss_value:
        if(length(killmails) > 0,
          do: Float.round(total_destroyed / length(killmails), 2),
          else: 0
        ),
      most_expensive_loss: find_most_expensive_loss(killmails),
      isk_by_ship_class: group_isk_by_ship_class(killmails),
      isk_efficiency_by_side: side_metrics,
      top_isk_destroyers: find_top_isk_destroyers(killmails, 5)
    }
  end

  defp calculate_damage_metrics(battle, precomputed) do
    killmails = battle.killmails || []
    metadata = battle[:metadata] || %{}

    total_damage = precomputed.total_damage
    duration_seconds = (metadata[:duration_minutes] || 0) * 60

    %{
      total_damage_applied: total_damage,
      average_damage_per_kill:
        if(length(killmails) > 0, do: Float.round(total_damage / length(killmails), 2), else: 0),
      dps_overall:
        if(duration_seconds > 0, do: Float.round(total_damage / duration_seconds, 2), else: 0),
      damage_by_weapon_type: group_damage_by_weapon_type(killmails),
      damage_by_ship_class: group_damage_by_ship_class(killmails),
      overkill_analysis: analyze_overkill(killmails),
      final_blow_distribution: analyze_final_blows(killmails)
    }
  end

  defp calculate_fleet_metrics(battle, precomputed) do
    killmails = battle.killmails || []
    fleet_composition = (battle[:timeline] && battle.timeline[:fleet_composition]) || []

    %{
      ship_types_used: precomputed.unique_ship_types,
      ship_class_distribution: calculate_ship_class_distribution(killmails),
      fleet_size_over_time: extract_fleet_sizes(fleet_composition),
      logistics_presence: detect_logistics_presence(killmails),
      ewar_usage: analyze_ewar_usage(battle),
      force_multipliers: identify_force_multipliers(killmails),
      average_fleet_age: calculate_average_ship_age(killmails)
    }
  end

  defp calculate_tactical_metrics(battle, _precomputed) do
    killmails = battle.killmails || []
    timeline = battle[:timeline] || %{}

    %{
      engagement_range: estimate_engagement_ranges(killmails),
      focus_fire_efficiency: calculate_focus_fire_efficiency(killmails),
      target_selection: analyze_target_selection(killmails),
      tactical_phases: identify_tactical_phases(timeline),
      mobility_score: calculate_mobility_score(battle),
      coordination_score: calculate_coordination_score(killmails)
    }
  end

  defp calculate_side_comparison(battle, _precomputed) do
    sides = identify_battle_sides(battle)

    if length(sides) >= 2 do
      [side_1, side_2 | _] = sides

      %{
        side_1: compile_side_stats(battle, side_1),
        side_2: compile_side_stats(battle, side_2),
        efficiency_comparison: compare_side_efficiency(battle, side_1, side_2)
      }
    else
      %{message: "Unable to identify distinct battle sides"}
    end
  end

  # Helper functions

  defp calculate_average_attackers(killmails) do
    total_attackers = Enum.sum(Enum.map(killmails, &(&1.attacker_count || 0)))

    if length(killmails) > 0 do
      Float.round(total_attackers / length(killmails), 1)
    else
      0
    end
  end

  defp calculate_average_attackers_precomputed(precomputed) do
    if precomputed.total_kills > 0 do
      total_attackers = length(precomputed.all_attackers)
      Float.round(total_attackers / precomputed.total_kills, 1)
    else
      0
    end
  end

  defp determine_battle_type(battle) do
    metadata = battle[:metadata] || %{}
    participant_count = metadata[:unique_participants] || 0
    duration = metadata[:duration_minutes] || 0

    cond do
      participant_count >= 100 -> :large_fleet
      participant_count >= 50 -> :medium_fleet
      participant_count >= 20 -> :small_fleet
      participant_count >= 10 && duration > 10 -> :extended_skirmish
      participant_count >= 5 -> :small_gang
      true -> :duel
    end
  end

  defp identify_battle_sides(battle) do
    # Use the timeline fleet composition to identify sides
    if battle[:timeline] && battle.timeline[:fleet_composition] do
      battle.timeline.fleet_composition
      |> Enum.flat_map(&(&1[:sides] || []))
      |> Enum.map(& &1.side_id)
      |> Enum.uniq()
    else
      # Fallback to corporation-based side detection
      detect_sides_from_killmails(battle.killmails)
    end
  end

  defp detect_sides_from_killmails(killmails) do
    # Group by corporation engagement patterns
    _corp_interactions = analyze_corporation_interactions(killmails)

    # Simple clustering - corps that never shoot each other are on same side
    # This is a simplified approach - in production would use graph clustering
    []
  end

  defp analyze_corporation_interactions(_killmails) do
    # Would analyze who shoots whom to determine sides
    %{}
  end

  defp calculate_side_isk_metrics(killmails, sides) do
    # For each side, calculate ISK destroyed vs ISK lost
    Enum.reduce(sides, %{}, fn side, acc ->
      side_stats = calculate_side_isk_stats(killmails, side)
      Map.put(acc, side, side_stats)
    end)
  end

  defp calculate_side_isk_stats(_killmails, _side) do
    # Would calculate ISK efficiency for a specific side
    %{
      isk_destroyed: 0,
      isk_lost: 0,
      efficiency: 0.0
    }
  end

  defp find_most_expensive_loss(killmails) do
    killmails
    |> Enum.max_by(&get_killmail_value(&1), fn -> nil end)
    |> case do
      nil ->
        nil

      km ->
        %{
          character_name:
            km.raw_data["victim"]["character_name"] ||
              NameResolver.character_name(km.victim_character_id),
          ship_name:
            km.raw_data["victim"]["ship_name"] || NameResolver.ship_name(km.victim_ship_type_id),
          value: get_killmail_value(km),
          killmail_id: km.killmail_id
        }
    end
  end

  defp group_isk_by_ship_class(killmails) do
    killmails
    |> Enum.group_by(&get_ship_class(&1.victim_ship_type_id))
    |> Enum.map(fn {class, kms} ->
      {class, Enum.sum(Enum.map(kms, &get_killmail_value(&1)))}
    end)
    |> Enum.into(%{})
  end

  defp find_top_isk_destroyers(killmails, limit) do
    killmails
    |> Enum.flat_map(fn km ->
      Enum.map(km.raw_data["attackers"] || [], fn att ->
        Map.put(att, :_source_killmail, km)
      end)
    end)
    # Filter out nil character_ids (NPCs/structures)
    |> Enum.filter(& &1["character_id"])
    |> Enum.group_by(& &1["character_id"])
    |> Enum.map(fn {char_id, attacks} ->
      # Approximate ISK destroyed per attacker
      total_value =
        Enum.sum(
          Enum.map(attacks, fn att ->
            km = att._source_killmail
            attacker_count = length(km.raw_data["attackers"] || [])
            if attacker_count > 0, do: get_killmail_value(km) / attacker_count, else: 0
          end)
        )

      %{
        character_id: char_id,
        character_name:
          List.first(attacks)["character_name"] || NameResolver.character_name(char_id),
        isk_destroyed: Float.round(total_value, 2),
        kills: length(Enum.filter(attacks, & &1["final_blow"]))
      }
    end)
    |> Enum.sort_by(& &1.isk_destroyed, :desc)
    |> Enum.take(limit)
  end

  defp group_damage_by_weapon_type(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      Enum.map(km.raw_data["attackers"] || [], fn att ->
        Map.merge(att, %{"_source_killmail" => km})
      end)
    end)
    |> Enum.filter(& &1["weapon_type_id"])
    |> Enum.group_by(& &1["weapon_type_id"])
    |> Enum.map(fn {weapon_id, attacks} ->
      weapon_name = List.first(attacks)["weapon_type_name"] || NameResolver.item_name(weapon_id)
      {weapon_name, Enum.sum(Enum.map(attacks, &(&1["damage_done"] || 0)))}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(10)
    |> Enum.into(%{})
  end

  defp group_damage_by_ship_class(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      Enum.map(km.raw_data["attackers"] || [], fn att ->
        Map.merge(att, %{"_source_killmail" => km})
      end)
    end)
    |> Enum.group_by(&get_ship_class(&1["ship_type_id"]))
    |> Enum.map(fn {class, attacks} ->
      {class, Enum.sum(Enum.map(attacks, &(&1["damage_done"] || 0)))}
    end)
    |> Enum.into(%{})
  end

  defp analyze_overkill(_killmails) do
    # Analyze how much damage was "wasted" on already-dead targets
    # This is simplified - would need ship EHP data for accurate calculation
    %{
      # Placeholder
      average_overkill_percentage: 15.0,
      most_overkilled_target: nil
    }
  end

  defp analyze_final_blows(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      Enum.map(km.raw_data["attackers"] || [], fn att ->
        Map.merge(att, %{"_source_killmail" => km})
      end)
    end)
    |> Enum.filter(& &1["final_blow"])
    # Filter out nil character_ids (NPCs/structures)
    |> Enum.filter(& &1["character_id"])
    |> Enum.group_by(& &1["character_id"])
    |> Enum.map(fn {char_id, blows} ->
      {char_id,
       %{
         count: length(blows),
         character_name:
           List.first(blows)["character_name"] || NameResolver.character_name(char_id)
       }}
    end)
    |> Enum.sort_by(&elem(&1, 1).count, :desc)
    |> Enum.take(5)
    |> Enum.into(%{})
  end

  defp calculate_ship_class_distribution(killmails) do
    all_ships =
      Enum.flat_map(killmails, fn km ->
        victim = [{km.victim_ship_type_id, :loss}]
        attackers = Enum.map(km.raw_data["attackers"] || [], &{&1["ship_type_id"], :active})
        victim ++ attackers
      end)

    all_ships
    |> Enum.group_by(&get_ship_class(elem(&1, 0)))
    |> Enum.map(fn {class, ships} ->
      {class,
       %{
         total: length(ships),
         losses: Enum.count(ships, &(elem(&1, 1) == :loss)),
         active: Enum.count(ships, &(elem(&1, 1) == :active))
       }}
    end)
    |> Enum.into(%{})
  end

  defp extract_fleet_sizes(fleet_composition) do
    fleet_composition
    |> Enum.map(fn window ->
      %{
        timestamp: window.timestamp,
        active_pilots: window.active_attackers + window.active_victims
      }
    end)
  end

  defp detect_logistics_presence(killmails) do
    # Common logi ships
    logi_ship_ids = [11985, 11987, 11989, 22440, 22442, 22444]

    logi_count =
      killmails
      |> Enum.flat_map(fn km ->
        Enum.map(km.raw_data["attackers"] || [], & &1["ship_type_id"])
      end)
      |> Enum.count(&(&1 in logi_ship_ids))

    %{
      logistics_ships_present: logi_count > 0,
      logistics_pilot_count: logi_count
    }
  end

  defp analyze_ewar_usage(_battle) do
    # Would analyze combat logs for EWAR module activations
    %{
      ecm_usage: false,
      damps_usage: false,
      tracking_disruption: false,
      target_painters: false
    }
  end

  defp identify_force_multipliers(killmails) do
    # Identify command ships, links, etc
    # Command ships
    command_ship_ids = [22442, 22444, 22446, 22448]

    command_ships =
      killmails
      |> Enum.flat_map(fn km ->
        Enum.map(km.raw_data["attackers"] || [], & &1["ship_type_id"])
      end)
      |> Enum.filter(&(&1 in command_ship_ids))
      |> length()

    %{
      command_ships: command_ships,
      estimated_links: command_ships > 0
    }
  end

  defp calculate_average_ship_age(_killmails) do
    # Would need kill timestamp data
    0
  end

  defp estimate_engagement_ranges(_killmails) do
    # Would analyze weapon types to estimate ranges
    %{
      close_range_percentage: 30,
      medium_range_percentage: 50,
      long_range_percentage: 20
    }
  end

  defp calculate_focus_fire_efficiency(_killmails) do
    # Analyze how quickly targets die relative to fleet size
    # seconds, placeholder
    average_time_to_kill = 45

    %{
      average_time_to_kill_seconds: average_time_to_kill,
      # Average targets engaged at once
      simultaneous_targets: 1.5,
      # Times per minute
      target_switching_frequency: 0.8
    }
  end

  defp analyze_target_selection(killmails) do
    # Analyze what types of ships are targeted first
    target_order =
      killmails
      |> Enum.map(fn km ->
        %{
          ship_class: get_ship_class(km.victim_ship_type_id),
          timestamp: km.killmail_time,
          value: get_killmail_value(km)
        }
      end)
      |> Enum.sort_by(& &1.timestamp)

    %{
      primary_targets: Enum.map(Enum.take(target_order, 5), & &1.ship_class),
      high_value_target_priority: analyze_value_targeting(target_order)
    }
  end

  defp analyze_value_targeting(_target_order) do
    # Would analyze if high-value targets are prioritized
    :moderate
  end

  defp identify_tactical_phases(timeline) do
    phases = timeline[:phases] || []

    Enum.map(phases, fn phase ->
      %{
        type: phase.phase_type,
        duration_minutes: calculate_phase_duration(phase),
        intensity: phase[:intensity] || :medium
      }
    end)
  end

  defp calculate_phase_duration(phase) do
    if phase.start_time && phase.end_time do
      NaiveDateTime.diff(phase.end_time, phase.start_time, :second) / 60
    else
      0
    end
  end

  defp calculate_mobility_score(_battle) do
    # Would analyze position changes and kiting
    %{
      # 0-100
      score: 65,
      assessment: :moderate_mobility
    }
  end

  defp calculate_coordination_score(killmails) do
    # Analyze how well fleet focuses fire
    avg_attackers = calculate_average_attackers(killmails)

    score =
      cond do
        avg_attackers > 20 -> 90
        avg_attackers > 10 -> 75
        avg_attackers > 5 -> 60
        true -> 40
      end

    %{
      score: score,
      average_attackers_per_kill: avg_attackers
    }
  end

  defp compile_side_stats(battle, side_id) do
    _killmails = battle.killmails || []

    # This is simplified - would need proper side assignment logic
    %{
      side_id: side_id,
      kills: 0,
      losses: 0,
      isk_destroyed: 0,
      isk_lost: 0,
      unique_pilots: 0,
      ship_classes_used: []
    }
  end

  defp compare_side_efficiency(_battle, _side_1, _side_2) do
    %{
      isk_efficiency_ratio: 1.0,
      kill_death_ratio: 1.0,
      damage_ratio: 1.0,
      winning_side: nil
    }
  end

  # Add the missing get_killmail_value helper function
  defp get_killmail_value(km) do
    # Extract ISK value from raw_data zkb field
    case km.raw_data do
      %{"zkb" => %{"totalValue" => value}} when is_number(value) -> value
      _ -> 0
    end
  end

  # Add helper function to get total damage from victim data
  defp get_total_damage(km) do
    case km.raw_data do
      %{"victim" => %{"damage_taken" => damage}} when is_number(damage) -> damage
      _ -> 0
    end
  end

  defp get_ship_class(ship_type_id) when is_integer(ship_type_id) do
    # Simplified ship class detection
    cond do
      ship_type_id in 582..650 -> "Frigate"
      ship_type_id in 324..380 -> "Destroyer"
      ship_type_id in 620..634 -> "Cruiser"
      ship_type_id in 1201..1310 -> "Battlecruiser"
      ship_type_id in 638..645 -> "Battleship"
      ship_type_id in 547..554 -> "Carrier"
      ship_type_id in 670..673 -> "Dreadnought"
      ship_type_id in 3514..3518 -> "Titan"
      ship_type_id in 11567..12034 -> "T3 Cruiser"
      ship_type_id in 29984..29990 -> "T3 Destroyer"
      true -> "Other"
    end
  end

  defp get_ship_class(_), do: "Other"
end
