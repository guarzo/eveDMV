defmodule EveDmv.Intelligence.CharacterMetrics do
  @moduledoc """
  Character metrics calculation module for comprehensive character analysis.

  This module handles all numerical calculations, score computations,
  and metric derivations for character intelligence analysis.
  """

  require Logger

  @doc """
  Calculate all character metrics from killmail data.

  Returns a comprehensive metrics map containing combat effectiveness,
  ship usage patterns, geographic activity, temporal patterns, and associates.
  """
  def calculate_all_metrics(character_id, killmail_data) do
    Logger.info("Calculating comprehensive metrics for character #{character_id}")

    %{
      character_id: character_id,
      character_name: extract_character_name(killmail_data),
      combat_metrics: calculate_combat_metrics(killmail_data),
      ship_usage: calculate_ship_usage(killmail_data),
      geographic_patterns: calculate_geographic_patterns(killmail_data),
      temporal_patterns: calculate_temporal_patterns(killmail_data),
      associate_analysis: calculate_associate_analysis(killmail_data),
      total_kills: count_kills(killmail_data),
      total_losses: count_losses(killmail_data),
      avg_gang_size: calculate_average_gang_size(killmail_data),
      flies_capitals: detect_capital_usage(killmail_data),
      dangerous_rating: calculate_dangerous_rating(killmail_data),
      awox_probability: calculate_awox_probability(killmail_data),
      kill_death_ratio: calculate_kill_death_ratio(killmail_data),
      preferred_systems: extract_preferred_systems(killmail_data),
      activity_timeline: build_activity_timeline(killmail_data),
      threat_assessment: assess_threat_level(killmail_data)
    }
  end

  @doc """
  Calculate combat effectiveness metrics.
  """
  def calculate_combat_metrics(killmail_data) do
    kills = count_kills(killmail_data)
    losses = count_losses(killmail_data)
    total_activity = kills + losses

    solo_kills = count_solo_kills(killmail_data)
    gang_kills = kills - solo_kills

    damage_dealt = calculate_total_damage_dealt(killmail_data)
    damage_received = calculate_total_damage_received(killmail_data)

    %{
      total_kills: kills,
      total_losses: losses,
      solo_kills: solo_kills,
      gang_kills: gang_kills,
      kill_death_ratio: if(losses > 0, do: kills / losses, else: kills),
      solo_kill_ratio: if(kills > 0, do: solo_kills / kills, else: 0.0),
      damage_dealt: damage_dealt,
      damage_received: damage_received,
      damage_efficiency:
        if(damage_received > 0, do: damage_dealt / damage_received, else: damage_dealt),
      activity_score: calculate_activity_score(total_activity),
      lethality_score: calculate_lethality_score(kills, damage_dealt)
    }
  end

  @doc """
  Calculate ship usage patterns and preferences.
  """
  def calculate_ship_usage(killmail_data) do
    # Group by ship types used
    ship_usage =
      killmail_data
      |> Enum.flat_map(fn killmail ->
        (killmail.participants || [])
        |> Enum.map(fn participant ->
          %{
            ship_type_id: participant.ship_type_id,
            ship_name: participant.ship_name || "Unknown",
            is_victim: participant.is_victim
          }
        end)
      end)
      |> Enum.group_by(& &1.ship_name)
      |> Enum.map(fn {ship_name, usages} ->
        {ship_name,
         %{
           total_usage: length(usages),
           kills_in_ship: Enum.count(usages, &(!&1.is_victim)),
           losses_in_ship: Enum.count(usages, & &1.is_victim),
           ship_type_id: List.first(usages).ship_type_id
         }}
      end)
      |> Enum.into(%{})

    # Calculate ship categories
    ship_categories = categorize_ships(ship_usage)
    preferred_ships = identify_preferred_ships(ship_usage)

    %{
      ship_usage: ship_usage,
      ship_categories: ship_categories,
      preferred_ships: preferred_ships,
      ship_diversity: calculate_ship_diversity(ship_usage),
      capital_usage: extract_capital_ships(ship_usage),
      t2_usage: extract_t2_ships(ship_usage)
    }
  end

  @doc """
  Calculate geographic activity patterns.
  """
  def calculate_geographic_patterns(killmail_data) do
    # Analyze system activity
    system_activity =
      killmail_data
      |> Enum.group_by(& &1.solar_system_id)
      |> Enum.map(fn {system_id, killmails} ->
        {system_id,
         %{
           system_name: extract_system_name(killmails),
           activity_count: length(killmails),
           kills_in_system: count_kills(killmails),
           losses_in_system: count_losses(killmails)
         }}
      end)
      |> Enum.into(%{})

    # Identify region patterns
    region_activity = analyze_region_activity(killmail_data)
    wormhole_activity = analyze_wormhole_activity(killmail_data)

    %{
      system_activity: system_activity,
      region_activity: region_activity,
      wormhole_activity: wormhole_activity,
      home_systems: identify_home_systems(system_activity),
      roaming_patterns: detect_roaming_patterns(system_activity),
      geographic_diversity: calculate_geographic_diversity(system_activity)
    }
  end

  @doc """
  Calculate temporal activity patterns.
  """
  def calculate_temporal_patterns(killmail_data) do
    # Analyze activity by time periods
    hourly_activity = analyze_hourly_activity(killmail_data)
    daily_activity = analyze_daily_activity(killmail_data)
    weekly_activity = analyze_weekly_activity(killmail_data)

    %{
      hourly_activity: hourly_activity,
      daily_activity: daily_activity,
      weekly_activity: weekly_activity,
      peak_hours: identify_peak_hours(hourly_activity),
      activity_consistency: calculate_activity_consistency(daily_activity),
      timezone_estimation: estimate_timezone(hourly_activity)
    }
  end

  @doc """
  Calculate associate analysis - who they fly with.
  """
  def calculate_associate_analysis(killmail_data) do
    # Extract associates from killmail participants
    associates =
      killmail_data
      |> Enum.flat_map(fn killmail ->
        (killmail.participants || [])
        |> Enum.map(fn participant ->
          %{
            character_id: participant.character_id,
            character_name: participant.character_name,
            corporation_id: participant.corporation_id,
            alliance_id: participant.alliance_id
          }
        end)
      end)
      |> Enum.group_by(& &1.character_id)
      |> Enum.map(fn {char_id, instances} ->
        first = List.first(instances)

        {char_id,
         %{
           character_name: first.character_name,
           corporation_id: first.corporation_id,
           alliance_id: first.alliance_id,
           frequency: length(instances)
         }}
      end)
      |> Enum.into(%{})

    frequent_associates =
      associates
      |> Enum.filter(fn {_id, data} -> data.frequency > 2 end)
      |> Enum.sort_by(fn {_id, data} -> data.frequency end, :desc)
      |> Enum.take(20)
      |> Enum.into(%{})

    %{
      all_associates: associates,
      frequent_associates: frequent_associates,
      total_unique_associates: map_size(associates),
      corporation_diversity: calculate_corporation_diversity(associates),
      alliance_diversity: calculate_alliance_diversity(associates)
    }
  end

  # Private helper functions

  defp extract_character_name(killmail_data) do
    killmail_data
    |> Enum.flat_map(fn killmail ->
      (killmail.participants || [])
      |> Enum.map(& &1.character_name)
    end)
    |> Enum.find(&(&1 != nil))
    |> case do
      nil -> "Unknown"
      name -> name
    end
  end

  defp count_kills(killmail_data) do
    killmail_data
    |> Enum.flat_map(fn killmail ->
      (killmail.participants || [])
      |> Enum.filter(&(!&1.is_victim))
    end)
    |> length()
  end

  defp count_losses(killmail_data) do
    killmail_data
    |> Enum.flat_map(fn killmail ->
      (killmail.participants || [])
      |> Enum.filter(& &1.is_victim)
    end)
    |> length()
  end

  defp count_solo_kills(killmail_data) do
    killmail_data
    |> Enum.count(fn killmail ->
      participants = killmail.participants || []
      attackers = Enum.filter(participants, &(!&1.is_victim))
      length(attackers) == 1
    end)
  end

  defp calculate_average_gang_size(killmail_data) do
    if Enum.empty?(killmail_data) do
      1.0
    else
      total_gang_size =
        killmail_data
        |> Enum.map(fn killmail ->
          participants = killmail.participants || []
          attackers = Enum.filter(participants, &(!&1.is_victim))
          length(attackers)
        end)
        |> Enum.sum()

      total_gang_size / length(killmail_data)
    end
  end

  defp detect_capital_usage(killmail_data) do
    capital_ships = ["Dreadnought", "Carrier", "Supercarrier", "Titan", "Force Auxiliary"]

    killmail_data
    |> Enum.flat_map(fn killmail ->
      (killmail.participants || [])
      |> Enum.map(& &1.ship_name)
    end)
    |> Enum.any?(fn ship_name ->
      ship_str = to_string(ship_name)
      Enum.any?(capital_ships, &String.contains?(ship_str, &1))
    end)
  end

  defp calculate_dangerous_rating(killmail_data) do
    kills = count_kills(killmail_data)
    losses = count_losses(killmail_data)
    solo_kills = count_solo_kills(killmail_data)

    # Base score from activity
    activity_score = min(kills * 2, 50)

    # Bonus for good K/D ratio
    kd_bonus = if losses > 0, do: min(kills / losses * 10, 30), else: 20

    # Bonus for solo capability
    solo_bonus = min(solo_kills * 5, 20)

    round(activity_score + kd_bonus + solo_bonus)
  end

  defp calculate_awox_probability(killmail_data) do
    # Look for patterns that might indicate awoxing behavior
    # This is a simplified heuristic
    total_activity = length(killmail_data)

    if total_activity < 5 do
      0.0
    else
      # Look for kills against same corporation/alliance members
      friendly_fire = count_friendly_fire_incidents(killmail_data)
      friendly_fire / total_activity
    end
  end

  defp calculate_kill_death_ratio(killmail_data) do
    kills = count_kills(killmail_data)
    losses = count_losses(killmail_data)

    if losses > 0 do
      kills / losses
    else
      kills
    end
  end

  defp extract_preferred_systems(killmail_data) do
    killmail_data
    |> Enum.group_by(& &1.solar_system_id)
    |> Enum.map(fn {system_id, killmails} ->
      {system_id, length(killmails)}
    end)
    |> Enum.sort_by(fn {_id, count} -> count end, :desc)
    |> Enum.take(5)
    |> Enum.into(%{})
  end

  defp build_activity_timeline(killmail_data) do
    killmail_data
    |> Enum.map(fn killmail ->
      %{
        timestamp: killmail.killmail_time,
        system_id: killmail.solar_system_id,
        is_kill: count_kills([killmail]) > 0
      }
    end)
    |> Enum.sort_by(& &1.timestamp)
  end

  defp assess_threat_level(killmail_data) do
    dangerous_rating = calculate_dangerous_rating(killmail_data)

    cond do
      dangerous_rating > 80 -> :very_high
      dangerous_rating > 60 -> :high
      dangerous_rating > 40 -> :moderate
      dangerous_rating > 20 -> :low
      true -> :minimal
    end
  end

  # Additional helper functions for complex calculations

  defp calculate_total_damage_dealt(killmail_data) do
    # Placeholder - would need actual damage data from killmails
    count_kills(killmail_data) * 50_000
  end

  defp calculate_total_damage_received(killmail_data) do
    # Placeholder - would need actual damage data from killmails
    count_losses(killmail_data) * 45_000
  end

  defp calculate_activity_score(total_activity) do
    # Score from 0-100 based on total activity
    min(total_activity * 5, 100)
  end

  defp calculate_lethality_score(kills, damage_dealt) do
    # Simple lethality calculation
    if kills > 0 do
      min(damage_dealt / (kills * 25_000), 2.0)
    else
      0.0
    end
  end

  defp categorize_ships(ship_usage) do
    # Categorize ships by type
    categories = %{
      frigates: [],
      destroyers: [],
      cruisers: [],
      battlecruisers: [],
      battleships: [],
      capitals: [],
      other: []
    }

    Enum.reduce(ship_usage, categories, fn {ship_name, _data}, acc ->
      category = categorize_ship_type(ship_name)
      %{acc | category => [ship_name | Map.get(acc, category, [])]}
    end)
  end

  defp categorize_ship_type(ship_name) do
    ship_str = String.downcase(to_string(ship_name))

    cond do
      String.contains?(ship_str, "frigate") ->
        :frigates

      String.contains?(ship_str, "destroyer") ->
        :destroyers

      String.contains?(ship_str, "cruiser") and not String.contains?(ship_str, "battle") ->
        :cruisers

      String.contains?(ship_str, "battlecruiser") ->
        :battlecruisers

      String.contains?(ship_str, "battleship") ->
        :battleships

      String.contains?(ship_str, ["carrier", "dreadnought", "titan"]) ->
        :capitals

      true ->
        :other
    end
  end

  defp identify_preferred_ships(ship_usage) do
    ship_usage
    |> Enum.sort_by(fn {_name, data} -> data.total_usage end, :desc)
    |> Enum.take(5)
    |> Enum.into(%{})
  end

  defp calculate_ship_diversity(ship_usage) do
    # Simple diversity score based on number of different ships used
    ship_count = map_size(ship_usage)
    min(ship_count / 10.0, 1.0)
  end

  defp extract_capital_ships(ship_usage) do
    ship_usage
    |> Enum.filter(fn {ship_name, _data} ->
      ship_str = String.downcase(to_string(ship_name))
      String.contains?(ship_str, ["carrier", "dreadnought", "titan", "supercarrier"])
    end)
    |> Enum.into(%{})
  end

  defp extract_t2_ships(ship_usage) do
    ship_usage
    |> Enum.filter(fn {ship_name, _data} ->
      ship_str = String.downcase(to_string(ship_name))
      String.contains?(ship_str, ["t2", "tech2", "assault", "heavy assault", "interceptor"])
    end)
    |> Enum.into(%{})
  end

  defp extract_system_name(killmails) do
    # Extract system name from first killmail, or use ID
    case List.first(killmails) do
      %{solar_system_name: name} when not is_nil(name) -> name
      %{solar_system_id: id} -> "System #{id}"
      _ -> "Unknown System"
    end
  end

  defp analyze_region_activity(_killmail_data) do
    # Placeholder for region analysis
    %{total_regions: 1, primary_region: "Unknown"}
  end

  defp analyze_wormhole_activity(killmail_data) do
    # Look for wormhole system activity (system IDs 31000000+)
    wh_killmails =
      Enum.filter(killmail_data, fn km ->
        km.solar_system_id >= 31_000_000
      end)

    %{
      wormhole_activity_count: length(wh_killmails),
      wormhole_percentage:
        if(length(killmail_data) > 0, do: length(wh_killmails) / length(killmail_data), else: 0.0)
    }
  end

  defp identify_home_systems(system_activity) do
    system_activity
    |> Enum.sort_by(fn {_id, data} -> data.activity_count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {system_id, _data} -> system_id end)
  end

  defp detect_roaming_patterns(system_activity) do
    # Simple roaming detection based on system diversity
    %{
      systems_visited: map_size(system_activity),
      roaming_score: min(map_size(system_activity) / 20.0, 1.0)
    }
  end

  defp calculate_geographic_diversity(system_activity) do
    # Geographic diversity based on number of systems
    system_count = map_size(system_activity)
    min(system_count / 15.0, 1.0)
  end

  defp analyze_hourly_activity(killmail_data) do
    killmail_data
    |> Enum.group_by(fn km ->
      case km.killmail_time do
        %DateTime{} = dt -> dt.hour
        _ -> 0
      end
    end)
    |> Enum.map(fn {hour, killmails} -> {hour, length(killmails)} end)
    |> Enum.into(%{})
  end

  defp analyze_daily_activity(killmail_data) do
    killmail_data
    |> Enum.group_by(fn km ->
      case km.killmail_time do
        %DateTime{} = dt -> Date.day_of_week(dt)
        _ -> 1
      end
    end)
    |> Enum.map(fn {day, killmails} -> {day, length(killmails)} end)
    |> Enum.into(%{})
  end

  defp analyze_weekly_activity(killmail_data) do
    # Group by week
    killmail_data
    |> Enum.group_by(fn km ->
      case km.killmail_time do
        %DateTime{} = dt -> Date.beginning_of_week(dt)
        _ -> Date.utc_today()
      end
    end)
    |> Enum.map(fn {week, killmails} -> {week, length(killmails)} end)
    |> Enum.into(%{})
  end

  defp identify_peak_hours(hourly_activity) do
    hourly_activity
    |> Enum.sort_by(fn {_hour, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {hour, _count} -> hour end)
  end

  defp calculate_activity_consistency(daily_activity) do
    if map_size(daily_activity) < 2 do
      0.0
    else
      values = Map.values(daily_activity)
      mean = Enum.sum(values) / length(values)

      variance =
        Enum.reduce(values, 0, fn x, acc ->
          acc + :math.pow(x - mean, 2)
        end) / length(values)

      # Lower variance = higher consistency
      if mean > 0 do
        max(0.0, 1.0 - variance / mean)
      else
        0.0
      end
    end
  end

  defp estimate_timezone(hourly_activity) do
    # Find peak hour and estimate timezone
    peak_hour =
      hourly_activity
      |> Enum.max_by(fn {_hour, count} -> count end, fn -> {12, 0} end)
      |> elem(0)

    # Simple timezone estimation (very rough)
    cond do
      peak_hour in 18..23 or peak_hour in 0..2 -> "EU"
      peak_hour in 8..14 -> "AU"
      peak_hour in 2..8 -> "US"
      true -> "Unknown"
    end
  end

  defp calculate_corporation_diversity(associates) do
    corporations =
      associates
      |> Map.values()
      |> Enum.map(& &1.corporation_id)
      |> Enum.uniq()
      |> length()

    min(corporations / 10.0, 1.0)
  end

  defp calculate_alliance_diversity(associates) do
    alliances =
      associates
      |> Map.values()
      |> Enum.map(& &1.alliance_id)
      |> Enum.filter(&(&1 != nil))
      |> Enum.uniq()
      |> length()

    min(alliances / 5.0, 1.0)
  end

  defp count_friendly_fire_incidents(_killmail_data) do
    # Simplified friendly fire detection
    # This would need more sophisticated logic in reality
    0
  end
end
