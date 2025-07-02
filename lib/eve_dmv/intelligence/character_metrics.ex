defmodule EveDmv.Intelligence.CharacterMetrics do
  @moduledoc """
  Character analysis calculations and scoring
  """

  require Logger

  def calculate_all_metrics(character_id, killmail_data) do
    basic_info = extract_basic_info_from_killmails(character_id, killmail_data)

    %{
      basic_stats: calculate_basic_stats(character_id, killmail_data),
      ship_usage: analyze_ship_usage(character_id, killmail_data),
      gang_composition: analyze_gang_composition(character_id, killmail_data),
      geographic_patterns: analyze_geographic_patterns(killmail_data),
      target_preferences: analyze_target_preferences(character_id, killmail_data),
      behavioral_patterns: analyze_behavioral_patterns(character_id, killmail_data),
      weaknesses: identify_weaknesses(character_id, killmail_data),
      temporal_patterns: analyze_temporal_patterns(killmail_data),
      danger_rating: calculate_danger_rating(killmail_data),
      frequent_associates: identify_frequent_associates(character_id, killmail_data),
      success_rate:
        calculate_success_rate(
          get_in(basic_info, [:kills, :count], 0),
          get_in(basic_info, [:losses, :count], 0)
        )
    }
  end

  def calculate_basic_stats(character_id, killmail_data) do
    kills = Enum.filter(killmail_data, &victim_is_not_character?(&1, character_id))
    losses = Enum.filter(killmail_data, &victim_is_character?(&1, character_id))
    solo_kills = Enum.filter(kills, &solo_kill?/1)
    solo_losses = Enum.filter(losses, &solo_loss?/1)

    %{
      kills: %{
        count: length(kills),
        solo: length(solo_kills),
        total_value: sum_killmail_values(kills),
        average_value: average_kill_value(kills)
      },
      losses: %{
        count: length(losses),
        solo: length(solo_losses),
        total_value: sum_killmail_values(losses),
        average_value: average_kill_value(losses)
      },
      kd_ratio: calculate_kd_ratio(length(kills), length(losses)),
      solo_ratio: calculate_solo_ratio(length(solo_kills), length(kills)),
      efficiency: calculate_efficiency(kills, losses)
    }
  end

  def analyze_ship_usage(character_id, killmail_data) do
    character_killmails =
      Enum.filter(killmail_data, fn km ->
        participant = find_character_participant(km, character_id)
        participant != nil
      end)

    ship_stats =
      character_killmails
      |> Enum.reduce(%{}, fn km, acc ->
        participant = find_character_participant(km, character_id)
        ship_type_id = participant["ship_type_id"]
        ship_name = participant["ship_name"] || "Unknown"

        Map.update(
          acc,
          ship_type_id,
          %{
            ship_type_id: ship_type_id,
            ship_name: ship_name,
            count: 1,
            kills: if(victim_is_not_character?(km, character_id), do: 1, else: 0),
            losses: if(victim_is_character?(km, character_id), do: 1, else: 0)
          },
          fn existing ->
            %{
              existing
              | count: existing.count + 1,
                kills:
                  existing.kills + if(victim_is_not_character?(km, character_id), do: 1, else: 0),
                losses:
                  existing.losses + if(victim_is_character?(km, character_id), do: 1, else: 0)
            }
          end
        )
      end)

    %{
      favorite_ships: get_favorite_ships(ship_stats),
      ship_categories: categorize_ships(ship_stats),
      effectiveness_by_ship: calculate_ship_effectiveness(ship_stats)
    }
  end

  def analyze_gang_composition(character_id, killmail_data) do
    kills = Enum.filter(killmail_data, &victim_is_not_character?(&1, character_id))

    gang_sizes =
      kills
      |> Enum.map(fn km ->
        attackers = km["attackers"] || []
        length(attackers)
      end)
      |> Enum.frequencies()

    %{
      average_gang_size: calculate_average_gang_size(gang_sizes),
      solo_percentage: calculate_solo_percentage(gang_sizes),
      small_gang_percentage: calculate_small_gang_percentage(gang_sizes),
      fleet_percentage: calculate_fleet_percentage(gang_sizes),
      preferred_gang_size: determine_preferred_gang_size(gang_sizes)
    }
  end

  def analyze_geographic_patterns(killmail_data) do
    systems =
      killmail_data
      |> Enum.map(& &1["solar_system_id"])
      |> Enum.reject(&is_nil/1)
      |> Enum.frequencies()

    regions =
      killmail_data
      |> Enum.map(&get_region_from_system(&1["solar_system_id"]))
      |> Enum.reject(&is_nil/1)
      |> Enum.frequencies()

    %{
      most_active_systems: get_top_locations(systems, 10),
      most_active_regions: get_top_locations(regions, 5),
      activity_spread: calculate_activity_spread(systems),
      wormhole_activity: calculate_wormhole_activity(systems),
      nullsec_activity: calculate_nullsec_activity(systems),
      lowsec_activity: calculate_lowsec_activity(systems),
      highsec_activity: calculate_highsec_activity(systems)
    }
  end

  def analyze_target_preferences(character_id, killmail_data) do
    kills = Enum.filter(killmail_data, &victim_is_not_character?(&1, character_id))

    targets =
      kills
      |> Enum.map(fn km ->
        victim = find_victim(km)

        %{
          ship_type: categorize_ship(victim["ship_type_id"]),
          ship_name: victim["ship_name"],
          corporation_id: victim["corporation_id"],
          alliance_id: victim["alliance_id"],
          value: km["zkb"]["totalValue"] || 0
        }
      end)

    %{
      preferred_target_ships: analyze_target_ship_preferences(targets),
      preferred_target_size: analyze_target_size_preferences(targets),
      average_target_value: calculate_average_target_value(targets),
      repeat_targets: identify_repeat_targets(targets)
    }
  end

  def analyze_behavioral_patterns(character_id, killmail_data) do
    kills = Enum.filter(killmail_data, &victim_is_not_character?(&1, character_id))
    losses = Enum.filter(killmail_data, &victim_is_character?(&1, character_id))

    %{
      risk_aversion: calculate_risk_aversion(kills, losses),
      aggression_level: calculate_aggression_level(kills, losses),
      target_selection: analyze_target_selection(kills),
      engagement_profile: analyze_engagement_profile(kills, losses),
      activity_consistency: calculate_activity_consistency(killmail_data),
      preferred_engagement_range: estimate_preferred_range(kills),
      bait_susceptibility: calculate_bait_susceptibility(losses)
    }
  end

  def identify_weaknesses(character_id, killmail_data) do
    losses = Enum.filter(killmail_data, &victim_is_character?(&1, character_id))

    loss_patterns = analyze_loss_patterns(losses)

    %{
      vulnerable_to_ship_types: loss_patterns.ship_types_died_to,
      vulnerable_times: identify_vulnerable_times(losses),
      repeated_mistakes: identify_repeated_mistakes(losses),
      common_loss_scenarios: categorize_loss_scenarios(losses),
      takes_bad_fights: takes_bad_fights?(character_id, killmail_data),
      overconfidence_indicator: calculate_overconfidence(character_id, killmail_data)
    }
  end

  def analyze_temporal_patterns(killmail_data) do
    timestamps = Enum.map(killmail_data, &parse_killmail_timestamp/1)

    hourly_activity =
      timestamps
      |> Enum.map(&extract_hour_from_datetime/1)
      |> Enum.frequencies()
      |> normalize_to_24_hours()

    daily_activity =
      timestamps
      |> Enum.map(&Date.day_of_week/1)
      |> Enum.frequencies()

    %{
      peak_hours: find_peak_activity_hours(hourly_activity),
      quiet_hours: find_quiet_hours(hourly_activity),
      most_active_days: find_most_active_days(daily_activity),
      weekend_warrior: weekend_warrior?(daily_activity),
      timezone_estimate: estimate_timezone_from_peaks(hourly_activity),
      activity_consistency: calculate_temporal_consistency(timestamps)
    }
  end

  def calculate_danger_rating(killmail_data) do
    metrics = %{
      kill_count: count_kills(killmail_data),
      solo_kills: count_solo_kills(killmail_data),
      capital_kills: count_capital_kills(killmail_data),
      recent_activity: calculate_recent_activity(killmail_data),
      kill_efficiency: calculate_kill_efficiency(killmail_data)
    }

    base_score = calculate_base_danger_score(metrics)
    multipliers = calculate_danger_multipliers(metrics)

    %{
      score: base_score * multipliers,
      rating: categorize_danger_level(base_score * multipliers),
      factors: metrics
    }
  end

  def identify_frequent_associates(character_id, killmail_data) do
    kills = Enum.filter(killmail_data, &victim_is_not_character?(&1, character_id))

    associates =
      kills
      |> Enum.flat_map(fn km ->
        attackers = km["attackers"] || []
        Enum.map(attackers, &extract_associate_info/1)
      end)
      |> Enum.reject(&(&1.character_id == character_id))
      |> Enum.group_by(& &1.character_id)
      |> Enum.map(fn {char_id, appearances} ->
        %{
          character_id: char_id,
          character_name: List.first(appearances).character_name,
          corporation_id: List.first(appearances).corporation_id,
          corporation_name: List.first(appearances).corporation_name,
          appearance_count: length(appearances),
          percentage: length(appearances) / length(kills) * 100
        }
      end)
      |> Enum.sort_by(& &1.appearance_count, :desc)
      |> Enum.take(20)

    %{
      top_associates: Enum.take(associates, 10),
      corporation_associates: group_by_corporation(associates),
      alliance_associates: group_by_alliance(associates)
    }
  end

  def calculate_success_rate(kills, losses) when kills == 0 and losses == 0, do: 0.0

  def calculate_success_rate(kills, losses) do
    kills / (kills + losses) * 100
  end

  def calculate_ship_preferences(killmail_data) do
    ship_usage =
      killmail_data
      |> Enum.map(&extract_ship_info/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_, count} -> count end, :desc)

    categories =
      ship_usage
      |> Enum.map(fn {ship_info, count} ->
        {categorize_ship_type(ship_info.ship_type_id), count}
      end)
      |> Enum.reduce(%{}, fn {category, count}, acc ->
        Map.update(acc, category, count, &(&1 + count))
      end)

    %{
      favorite_ships: Enum.take(ship_usage, 10),
      ship_categories: categories,
      specialization_score: calculate_specialization_score(categories)
    }
  end

  def calculate_target_preferences(killmail_data) do
    targets =
      killmail_data
      |> Enum.filter(&kill?/1)
      |> Enum.map(&extract_target_info/1)
      |> Enum.reject(&is_nil/1)

    %{
      preferred_ship_classes: analyze_target_ship_classes(targets),
      preferred_ship_sizes: analyze_target_ship_sizes(targets),
      preferred_factions: analyze_target_factions(targets),
      average_target_age: calculate_average_target_age(targets),
      risk_profile: analyze_target_risk_profile(targets)
    }
  end

  # Private helper functions

  defp extract_basic_info_from_killmails(character_id, killmail_data) do
    kills = Enum.filter(killmail_data, &victim_is_not_character?(&1, character_id))
    losses = Enum.filter(killmail_data, &victim_is_character?(&1, character_id))

    %{
      kills: %{count: length(kills)},
      losses: %{count: length(losses)}
    }
  end

  defp victim_is_character?(killmail, character_id) do
    victim = find_victim(killmail)
    victim && victim["character_id"] == character_id
  end

  defp victim_is_not_character?(killmail, character_id) do
    !victim_is_character?(killmail, character_id)
  end

  defp find_victim(killmail) do
    participants = killmail["participants"] || killmail["attackers"] || []
    victim = killmail["victim"]

    if victim do
      victim
    else
      Enum.find(participants, &(&1["is_victim"] == true))
    end
  end

  defp find_character_participant(killmail, character_id) do
    participants = killmail["participants"] || killmail["attackers"] || []
    victim = killmail["victim"]

    if victim && victim["character_id"] == character_id do
      victim
    else
      Enum.find(participants, &(&1["character_id"] == character_id))
    end
  end

  defp solo_kill?(killmail) do
    attackers = killmail["attackers"] || []
    length(attackers) == 1
  end

  defp solo_loss?(killmail) do
    attackers = killmail["attackers"] || []
    length(attackers) == 1
  end

  defp sum_killmail_values(killmails) do
    Enum.reduce(killmails, 0, fn km, acc ->
      value = get_in(km, ["zkb", "totalValue"]) || 0
      acc + value
    end)
  end

  defp average_kill_value([]), do: 0

  defp average_kill_value(killmails) do
    sum_killmail_values(killmails) / length(killmails)
  end

  defp calculate_kd_ratio(kills, losses) when losses == 0, do: kills
  defp calculate_kd_ratio(kills, losses), do: kills / losses

  defp calculate_solo_ratio(_, 0), do: 0
  defp calculate_solo_ratio(solo_kills, total_kills), do: solo_kills / total_kills

  defp calculate_efficiency([], []), do: 50.0

  defp calculate_efficiency(kills, losses) do
    kill_value = sum_killmail_values(kills)
    loss_value = sum_killmail_values(losses)

    if kill_value + loss_value == 0 do
      50.0
    else
      kill_value / (kill_value + loss_value) * 100
    end
  end

  defp categorize_ship(ship_type_id) when is_nil(ship_type_id), do: "Unknown"

  defp categorize_ship(ship_type_id) do
    # This would normally use static data
    cond do
      ship_type_id in 25..40 -> "Frigate"
      ship_type_id in 419..420 -> "Destroyer"
      ship_type_id in 620..660 -> "Cruiser"
      ship_type_id in 1200..1300 -> "Battlecruiser"
      ship_type_id in 630..650 -> "Battleship"
      true -> "Other"
    end
  end

  defp categorize_ship_type(ship_type_id) do
    categorize_ship(ship_type_id)
  end

  defp get_favorite_ships(ship_stats) do
    ship_stats
    |> Map.values()
    |> Enum.sort_by(& &1.count, :desc)
    |> Enum.take(5)
  end

  defp categorize_ships(ship_stats) do
    ship_stats
    |> Map.values()
    |> Enum.group_by(&categorize_ship(&1.ship_type_id))
    |> Enum.map(fn {category, ships} ->
      {category, Enum.sum(Enum.map(ships, & &1.count))}
    end)
    |> Enum.into(%{})
  end

  defp calculate_ship_effectiveness(ship_stats) do
    ship_stats
    |> Map.values()
    |> Enum.map(fn stats ->
      effectiveness =
        if stats.losses == 0, do: 100.0, else: stats.kills / (stats.kills + stats.losses) * 100

      Map.put(stats, :effectiveness, effectiveness)
    end)
    |> Enum.sort_by(& &1.effectiveness, :desc)
  end

  defp calculate_average_gang_size(gang_sizes) do
    total_kills = Enum.sum(Map.values(gang_sizes))

    weighted_sum =
      Enum.reduce(gang_sizes, 0, fn {size, count}, acc ->
        acc + size * count
      end)

    if total_kills == 0, do: 0, else: weighted_sum / total_kills
  end

  defp calculate_solo_percentage(gang_sizes) do
    solo = Map.get(gang_sizes, 1, 0)
    total = Enum.sum(Map.values(gang_sizes))

    if total == 0, do: 0, else: solo / total * 100
  end

  defp calculate_small_gang_percentage(gang_sizes) do
    small_gang =
      gang_sizes
      |> Enum.filter(fn {size, _} -> size >= 2 && size <= 10 end)
      |> Enum.map(fn {_, count} -> count end)
      |> Enum.sum()

    total = Enum.sum(Map.values(gang_sizes))
    if total == 0, do: 0, else: small_gang / total * 100
  end

  defp calculate_fleet_percentage(gang_sizes) do
    fleet =
      gang_sizes
      |> Enum.filter(fn {size, _} -> size > 10 end)
      |> Enum.map(fn {_, count} -> count end)
      |> Enum.sum()

    total = Enum.sum(Map.values(gang_sizes))
    if total == 0, do: 0, else: fleet / total * 100
  end

  defp determine_preferred_gang_size(gang_sizes) do
    gang_sizes
    |> Enum.max_by(fn {_size, count} -> count end, fn -> {0, 0} end)
    |> elem(0)
  end

  defp get_region_from_system(_system_id) do
    # This would normally query static data
    "Unknown Region"
  end

  defp get_top_locations(locations, limit) do
    locations
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {location, count} -> %{location: location, count: count} end)
  end

  defp calculate_activity_spread(systems) do
    system_count = map_size(systems)

    cond do
      system_count <= 5 -> "Highly Concentrated"
      system_count <= 15 -> "Moderately Concentrated"
      system_count <= 30 -> "Moderately Spread"
      true -> "Highly Spread"
    end
  end

  defp calculate_wormhole_activity(_systems) do
    # Would check against actual wormhole system IDs
    0.0
  end

  defp calculate_nullsec_activity(_systems) do
    # Would check against actual nullsec system IDs
    0.0
  end

  defp calculate_lowsec_activity(_systems) do
    # Would check against actual lowsec system IDs
    0.0
  end

  defp calculate_highsec_activity(_systems) do
    # Would check against actual highsec system IDs
    0.0
  end

  defp analyze_target_ship_preferences(targets) do
    targets
    |> Enum.map(& &1.ship_type)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(5)
  end

  defp analyze_target_size_preferences(targets) do
    targets
    |> Enum.map(& &1.ship_type)
    |> Enum.frequencies()
    |> Enum.into(%{})
  end

  defp calculate_average_target_value(targets) do
    values = Enum.map(targets, & &1.value)
    if Enum.empty?(values), do: 0, else: Enum.sum(values) / length(values)
  end

  defp identify_repeat_targets(targets) do
    targets
    |> Enum.group_by(& &1.corporation_id)
    |> Enum.filter(fn {_, kills} -> length(kills) > 1 end)
    |> Enum.map(fn {corp_id, kills} -> %{corporation_id: corp_id, kill_count: length(kills)} end)
    |> Enum.sort_by(& &1.kill_count, :desc)
  end

  defp calculate_risk_aversion(kills, losses) do
    avg_kill_value = average_kill_value(kills)
    avg_loss_value = average_kill_value(losses)

    cond do
      avg_loss_value == 0 -> "Unknown"
      avg_kill_value / avg_loss_value > 2 -> "High Risk Aversion"
      avg_kill_value / avg_loss_value > 1 -> "Moderate Risk Aversion"
      avg_kill_value / avg_loss_value > 0.5 -> "Balanced"
      true -> "Risk Taker"
    end
  end

  defp calculate_aggression_level(kills, losses) do
    kill_count = length(kills)
    loss_count = length(losses)

    ratio = if loss_count == 0, do: kill_count, else: kill_count / loss_count

    cond do
      ratio > 5 -> "Very Aggressive"
      ratio > 2 -> "Aggressive"
      ratio > 1 -> "Moderate"
      ratio > 0.5 -> "Cautious"
      true -> "Very Cautious"
    end
  end

  defp analyze_target_selection(kills) do
    %{
      prefers_weak_targets: prefers_weak_targets?(kills),
      hunts_expensive_targets: hunts_expensive_targets?(kills),
      opportunistic: opportunistic?(kills)
    }
  end

  defp analyze_engagement_profile(kills, losses) do
    %{
      preferred_range: estimate_preferred_range(kills),
      engagement_duration: estimate_engagement_duration(kills ++ losses),
      uses_capital_ships: uses_capital_ships?(kills ++ losses),
      uses_support_ships: uses_support_ships?(kills ++ losses)
    }
  end

  defp calculate_activity_consistency(killmail_data) do
    dates =
      killmail_data
      |> Enum.map(&parse_killmail_timestamp/1)
      |> Enum.map(&DateTime.to_date/1)
      |> Enum.uniq()
      |> Enum.sort()

    if length(dates) < 2 do
      "Insufficient Data"
    else
      gaps = calculate_date_gaps(dates)
      avg_gap = Enum.sum(gaps) / length(gaps)

      cond do
        avg_gap <= 2 -> "Very Consistent"
        avg_gap <= 5 -> "Consistent"
        avg_gap <= 10 -> "Moderate"
        true -> "Sporadic"
      end
    end
  end

  defp estimate_preferred_range(kills) do
    # Would analyze weapon types used in kills
    "Unknown"
  end

  defp calculate_bait_susceptibility(losses) do
    # Would analyze loss scenarios
    "Unknown"
  end

  defp analyze_loss_patterns(losses) do
    ship_types_died_to =
      losses
      |> Enum.flat_map(fn loss ->
        attackers = loss["attackers"] || []
        Enum.map(attackers, & &1["ship_type_id"])
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&categorize_ship/1)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_, count} -> count end, :desc)
      |> Enum.take(5)

    %{
      ship_types_died_to: ship_types_died_to,
      common_loss_scenarios: categorize_loss_scenarios(losses)
    }
  end

  defp identify_vulnerable_times(losses) do
    losses
    |> Enum.map(&parse_killmail_timestamp/1)
    |> Enum.map(&extract_hour_from_datetime/1)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {hour, _} -> hour end)
  end

  defp identify_repeated_mistakes(_losses) do
    # Would analyze patterns in losses
    []
  end

  defp categorize_loss_scenarios(losses) do
    losses
    |> Enum.map(&categorize_single_loss/1)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
  end

  defp categorize_single_loss(loss) do
    attackers = loss["attackers"] || []
    attacker_count = length(attackers)

    cond do
      attacker_count == 0 -> "Unknown"
      attacker_count == 1 -> "Solo Loss"
      attacker_count <= 5 -> "Small Gang Loss"
      attacker_count <= 15 -> "Gang Loss"
      true -> "Blob Loss"
    end
  end

  defp takes_bad_fights?(character_id, killmail_data) do
    losses = Enum.filter(killmail_data, &victim_is_character?(&1, character_id))

    bad_fights = Enum.count(losses, &bad_fight?/1)
    total_fights = length(losses)

    if total_fights == 0 do
      false
    else
      bad_fights / total_fights > 0.3
    end
  end

  defp bad_fight?(loss) do
    attackers = loss["attackers"] || []
    length(attackers) > 5
  end

  defp calculate_overconfidence(character_id, killmail_data) do
    losses = Enum.filter(killmail_data, &victim_is_character?(&1, character_id))
    solo_losses = Enum.filter(losses, &solo_loss?/1)

    expensive_solo_losses =
      Enum.count(solo_losses, fn loss ->
        value = get_in(loss, ["zkb", "totalValue"]) || 0
        value > 100_000_000
      end)

    if Enum.empty?(solo_losses) do
      0.0
    else
      expensive_solo_losses / length(solo_losses) * 100
    end
  end

  defp parse_killmail_timestamp(killmail) do
    timestamp_str = killmail["killmail_time"] || killmail["timestamp"]

    case DateTime.from_iso8601(timestamp_str) do
      {:ok, datetime, _} -> datetime
      _ -> DateTime.utc_now()
    end
  end

  defp extract_hour_from_datetime(datetime) do
    datetime.hour
  end

  defp normalize_to_24_hours(hourly_frequencies) do
    0..23
    |> Enum.map(fn hour -> {hour, Map.get(hourly_frequencies, hour, 0)} end)
    |> Enum.into(%{})
  end

  defp find_peak_activity_hours(hourly_activity) do
    hourly_activity
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {hour, _} -> hour end)
  end

  defp find_quiet_hours(hourly_activity) do
    hourly_activity
    |> Enum.sort_by(fn {_, count} -> count end)
    |> Enum.take(6)
    |> Enum.map(fn {hour, _} -> hour end)
    |> Enum.sort()
  end

  defp find_most_active_days(daily_activity) do
    daily_activity
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {day, _} -> day_name(day) end)
  end

  defp weekend_warrior?(daily_activity) do
    weekend_activity = Map.get(daily_activity, 6, 0) + Map.get(daily_activity, 7, 0)
    total_activity = Enum.sum(Map.values(daily_activity))

    if total_activity == 0 do
      false
    else
      weekend_activity / total_activity > 0.4
    end
  end

  defp estimate_timezone_from_peaks(hourly_activity) do
    peaks = find_peak_activity_hours(hourly_activity)
    avg_peak = if Enum.empty?(peaks), do: 12, else: Enum.sum(peaks) / length(peaks)

    classify_timezone_by_peak(avg_peak)
  end

  defp classify_timezone_by_peak(avg_peak) do
    timezone_ranges = [
      {22, 2, "US West"},
      {2, 6, "US East"},
      {6, 10, "EU West"},
      {10, 14, "EU East"},
      {14, 18, "RU"},
      {18, 22, "AU"}
    ]
    Enum.find_value(timezone_ranges, "Unknown", fn
      {start, finish, zone} when start > finish ->
        if avg_peak >= start || avg_peak <= finish, do: zone
      {start, finish, zone} ->
        if avg_peak >= start && avg_peak <= finish, do: zone
    end)
  end

  defp calculate_temporal_consistency(timestamps) do
    if length(timestamps) < 2 do
      "Insufficient Data"
    else
      hourly_spread = calculate_hourly_spread(timestamps)

      cond do
        hourly_spread <= 3 -> "Very Consistent"
        hourly_spread <= 6 -> "Consistent"
        hourly_spread <= 12 -> "Variable"
        true -> "Highly Variable"
      end
    end
  end

  defp calculate_hourly_spread(timestamps) do
    hours = Enum.map(timestamps, & &1.hour)
    Enum.max(hours) - Enum.min(hours)
  end

  defp day_name(1), do: "Monday"
  defp day_name(2), do: "Tuesday"
  defp day_name(3), do: "Wednesday"
  defp day_name(4), do: "Thursday"
  defp day_name(5), do: "Friday"
  defp day_name(6), do: "Saturday"
  defp day_name(7), do: "Sunday"
  defp day_name(_), do: "Unknown"

  defp count_kills(killmail_data) do
    Enum.count(killmail_data, &kill?/1)
  end

  defp count_solo_kills(killmail_data) do
    killmail_data
    |> Enum.filter(&is_kill?/1)
    |> Enum.count(&solo_kill?/1)
  end

  defp count_capital_kills(killmail_data) do
    killmail_data
    |> Enum.filter(&is_kill?/1)
    |> Enum.count(&capital_kill?/1)
  end

  defp calculate_recent_activity(killmail_data) do
    recent =
      Enum.count(killmail_data, fn km ->
        timestamp = parse_killmail_timestamp(km)
        DateTime.diff(DateTime.utc_now(), timestamp, :day) <= 30
      end)

    recent / max(length(killmail_data), 1) * 100
  end

  defp calculate_kill_efficiency(killmail_data) do
    kills = Enum.filter(killmail_data, &kill?/1)
    losses = Enum.reject(killmail_data, &kill?/1)

    calculate_efficiency(kills, losses)
  end

  defp calculate_base_danger_score(metrics) do
    kill_score = metrics.kill_count * 1.0
    solo_score = metrics.solo_kills * 2.0
    capital_score = metrics.capital_kills * 5.0
    efficiency_score = metrics.kill_efficiency / 10

    kill_score + solo_score + capital_score + efficiency_score
  end

  defp calculate_danger_multipliers(metrics) do
    recent_multiplier = if metrics.recent_activity > 50, do: 1.5, else: 1.0
    efficiency_multiplier = if metrics.kill_efficiency > 75, do: 1.3, else: 1.0

    recent_multiplier * efficiency_multiplier
  end

  defp categorize_danger_level(score) do
    cond do
      score >= 100 -> "Extremely Dangerous"
      score >= 50 -> "Very Dangerous"
      score >= 25 -> "Dangerous"
      score >= 10 -> "Moderate Threat"
      true -> "Low Threat"
    end
  end

  defp kill?(killmail) do
    # Check if this killmail represents a kill (not a loss) for the perspective character
    # This is simplified - would need character context
    true
  end

  defp capital_kill?(killmail) do
    victim = find_victim(killmail)
    ship_type_id = victim["ship_type_id"]

    # Simplified capital ship detection
    ship_type_id in [
      # Carrier IDs
      23_757,
      23_911,
      23_915,
      24_483,
      # Dreadnought IDs
      19_720,
      19_722,
      19_724,
      19_726,
      # Supercarrier IDs
      3514,
      22_852,
      23_913,
      23_917,
      23_919,
      # Titan IDs
      671,
      3764,
      11_567,
      23_773
    ]
  end

  defp extract_associate_info(attacker) do
    %{
      character_id: attacker["character_id"],
      character_name: attacker["character_name"] || "Unknown",
      corporation_id: attacker["corporation_id"],
      corporation_name: attacker["corporation_name"] || "Unknown Corp",
      alliance_id: attacker["alliance_id"],
      alliance_name: attacker["alliance_name"]
    }
  end

  defp group_by_corporation(associates) do
    associates
    |> Enum.group_by(& &1.corporation_id)
    |> Enum.map(fn {corp_id, members} ->
      %{
        corporation_id: corp_id,
        corporation_name: List.first(members).corporation_name,
        member_count: length(members),
        total_appearances: Enum.sum(Enum.map(members, & &1.appearance_count))
      }
    end)
    |> Enum.sort_by(& &1.total_appearances, :desc)
    |> Enum.take(10)
  end

  defp group_by_alliance(associates) do
    associates
    |> Enum.reject(&is_nil(&1.alliance_id))
    |> Enum.group_by(& &1.alliance_id)
    |> Enum.map(fn {alliance_id, members} ->
      %{
        alliance_id: alliance_id,
        alliance_name: List.first(members).alliance_name,
        member_count: length(members),
        total_appearances: Enum.sum(Enum.map(members, & &1.appearance_count))
      }
    end)
    |> Enum.sort_by(& &1.total_appearances, :desc)
    |> Enum.take(5)
  end

  defp extract_ship_info(killmail) do
    # Extract ship info from killmail
    # This is simplified
    %{
      ship_type_id: killmail["ship_type_id"],
      ship_name: killmail["ship_name"]
    }
  end

  defp calculate_specialization_score(categories) do
    total = Enum.sum(Map.values(categories))

    if total == 0 do
      0.0
    else
      max_category =
        categories
        |> Map.values()
        |> Enum.max(fn -> 0 end)

      max_category / total * 100
    end
  end

  defp extract_target_info(killmail) do
    victim = find_victim(killmail)

    %{
      ship_type_id: victim["ship_type_id"],
      ship_name: victim["ship_name"],
      character_age: calculate_character_age(victim),
      corporation_id: victim["corporation_id"],
      alliance_id: victim["alliance_id"]
    }
  end

  defp analyze_target_ship_classes(targets) do
    targets
    |> Enum.map(&categorize_ship(&1.ship_type_id))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
  end

  defp analyze_target_ship_sizes(targets) do
    targets
    |> Enum.map(&ship_size_category(&1.ship_type_id))
    |> Enum.frequencies()
  end

  defp analyze_target_factions(_targets) do
    # Would analyze NPC factions if applicable
    %{}
  end

  defp calculate_average_target_age(targets) do
    ages =
      targets
      |> Enum.map(& &1.character_age)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(ages) do
      0
    else
      Enum.sum(ages) / length(ages)
    end
  end

  defp analyze_target_risk_profile(targets) do
    # Analyze whether pilot picks easy or hard targets
    "Balanced"
  end

  defp calculate_character_age(_victim) do
    # Would calculate based on character creation date
    # days
    365
  end

  defp ship_size_category(ship_type_id) do
    category = categorize_ship(ship_type_id)

    cond do
      category in ["Frigate", "Destroyer"] -> "Small"
      category in ["Cruiser", "Battlecruiser"] -> "Medium"
      category in ["Battleship"] -> "Large"
      true -> "Other"
    end
  end

  defp prefers_weak_targets?(_kills) do
    # Would analyze target selection patterns
    false
  end

  defp hunts_expensive_targets?(kills) do
    avg_value = average_kill_value(kills)
    avg_value > 100_000_000
  end

  defp opportunistic?(_kills) do
    # Would analyze engagement patterns
    true
  end

  defp estimate_engagement_duration(_killmails) do
    # Would analyze damage patterns
    "Unknown"
  end

  defp uses_capital_ships?(killmails) do
    Enum.any?(killmails, fn km ->
      participant = find_character_participant(km, nil)
      participant && capital_ship?(participant["ship_type_id"])
    end)
  end

  defp uses_support_ships?(killmails) do
    Enum.any?(killmails, fn km ->
      participant = find_character_participant(km, nil)
      participant && support_ship?(participant["ship_type_id"])
    end)
  end

  defp capital_ship?(ship_type_id) do
    ship_type_id in [
      # Carrier IDs
      23_757,
      23_911,
      23_915,
      24_483,
      # Dreadnought IDs
      19_720,
      19_722,
      19_724,
      19_726,
      # FAX IDs
      37_604,
      37_605,
      37_606,
      37_607,
      # Supercarrier IDs
      3514,
      22_852,
      23_913,
      23_917,
      23_919,
      # Titan IDs
      671,
      3764,
      11_567,
      23_773
    ]
  end

  defp support_ship?(ship_type_id) do
    ship_type_id in [
      # Logistics Cruisers
      11_985,
      11_987,
      11_989,
      11_993,
      # Command Ships
      22_442,
      22_444,
      22_446,
      22_448,
      # Interdictors
      22_452,
      22_456,
      22_460,
      22_464
    ]
  end

  defp calculate_date_gaps([_]), do: []

  defp calculate_date_gaps([date1, date2 | rest]) do
    gap = Date.diff(date2, date1)
    [gap | calculate_date_gaps([date2 | rest])]
  end
end
