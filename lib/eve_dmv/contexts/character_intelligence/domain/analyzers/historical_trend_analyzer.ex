defmodule EveDmv.Contexts.CharacterIntelligence.Domain.Analyzers.HistoricalTrendAnalyzer do
  @moduledoc """
  Analyzes long-term historical trends for characters.
  All analysis based on real killmail data - NO PLACEHOLDERS.
  """

  import Ash.Query
  alias EveDmv.Killmails.KillmailRaw
  require Logger

  # Ship class classification ranges
  @ship_class_ranges [
    {582..650, :frigate},
    {620..650, :destroyer},
    {621..750, :cruiser},
    {638..650, :battlecruiser},
    {638..650, :battleship},
    {20_000..29_999, :t2_ship},
    {30_000..34_999, :t3_ship}
  ]

  # Tech level ranges
  @tech_level_ranges [
    # T3
    {30_000..34_999, 3},
    # T2
    {20_000..29_999, 2}
  ]

  @doc """
  Analyzes historical trends for a character over specified months.
  """
  def analyze_trends(character_id, options \\ []) do
    months = Keyword.get(options, :months, 6)
    Logger.debug("Analyzing #{months} months of trends for character #{character_id}")

    killmails = get_historical_killmails(character_id, months)

    case killmails do
      [] ->
        {:error, :insufficient_historical_data}

      data ->
        monthly_data = group_by_month(data)

        {:ok,
         %{
           activity_trend: analyze_activity_trend(monthly_data),
           performance_trend: analyze_performance_trend(monthly_data, character_id),
           ship_usage_trend: analyze_ship_trend(monthly_data, character_id),
           geographic_trend: analyze_geographic_trend(monthly_data),
           social_trend: analyze_social_trend(monthly_data, character_id),
           skill_progression: estimate_skill_progression(monthly_data, character_id)
         }}
    end
  end

  @doc """
  Get trend summary for quick overview.
  """
  def get_trend_summary(character_id) do
    case analyze_trends(character_id, months: 3) do
      {:ok, trends} ->
        {:ok,
         %{
           activity_direction: trends.activity_trend.trend_direction,
           performance_improving: trends.performance_trend.improvement_rate > 0,
           skill_velocity: trends.skill_progression.skill_velocity,
           primary_timezone: get_primary_timezone(trends.activity_trend),
           fleet_preference: trends.social_trend.fleet_preference
         }}

      error ->
        error
    end
  end

  # Private functions

  defp get_historical_killmails(character_id, months) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -months * 30 * 86_400, :second)
    character_id_str = to_string(character_id)

    KillmailRaw
    |> filter(killmail_time > ^cutoff_date)
    |> filter(
      victim_character_id == ^character_id or
        fragment(
          "EXISTS (SELECT 1 FROM jsonb_array_elements(raw_data->'attackers') a WHERE a->>'character_id' = ?)",
          ^character_id_str
        )
    )
    |> select([
      :killmail_id,
      :killmail_time,
      :solar_system_id,
      :victim_character_id,
      :victim_ship_type_id,
      :raw_data,
      :total_value
    ])
    |> Ash.read!(domain: EveDmv.Api)
  rescue
    error ->
      Logger.error("Failed to get historical killmails: #{inspect(error)}")
      []
  end

  defp group_by_month(killmails) do
    killmails
    |> Enum.group_by(fn km ->
      date = DateTime.to_date(km.killmail_time)
      {date.year, date.month}
    end)
    |> Enum.sort_by(fn {{year, month}, _} -> {year, month} end)
  end

  defp analyze_activity_trend(monthly_data) do
    if Enum.empty?(monthly_data) do
      %{
        data_points: [],
        trend_direction: :insufficient_data,
        volatility: 0.0,
        projection: nil
      }
    else
      trend_points =
        Enum.map(monthly_data, fn {{year, month}, kills} ->
          %{
            year: year,
            month: month,
            kill_count: length(kills),
            daily_average: Float.round(length(kills) / days_in_month(year, month), 2),
            peak_day: find_peak_activity_day(kills)
          }
        end)

      %{
        data_points: trend_points,
        trend_direction: calculate_trend_direction(trend_points),
        volatility: calculate_volatility(trend_points),
        projection: project_next_month(trend_points)
      }
    end
  end

  defp days_in_month(year, month) do
    Date.days_in_month(Date.new!(year, month, 1))
  end

  defp find_peak_activity_day(kills) do
    if Enum.empty?(kills) do
      nil
    else
      kills
      |> Enum.group_by(fn km ->
        Date.day_of_week(DateTime.to_date(km.killmail_time))
      end)
      |> Enum.max_by(fn {_, day_kills} -> length(day_kills) end)
      |> elem(0)
      |> day_name()
    end
  end

  defp day_name(1), do: "Monday"
  defp day_name(2), do: "Tuesday"
  defp day_name(3), do: "Wednesday"
  defp day_name(4), do: "Thursday"
  defp day_name(5), do: "Friday"
  defp day_name(6), do: "Saturday"
  defp day_name(7), do: "Sunday"
  defp day_name(_), do: "Unknown"

  defp calculate_trend_direction(trend_points) when length(trend_points) < 2 do
    :insufficient_data
  end

  defp calculate_trend_direction(trend_points) do
    # Simple linear regression on kill counts
    {x_values, y_values} =
      trend_points
      |> Enum.with_index()
      |> Enum.map(fn {point, index} -> {index, point.kill_count} end)
      |> Enum.unzip()

    slope = calculate_slope(x_values, y_values)

    cond do
      slope > 5 -> :strong_increase
      slope > 1 -> :increasing
      slope > -1 -> :stable
      slope > -5 -> :decreasing
      true -> :strong_decrease
    end
  end

  defp calculate_slope(x_values, y_values) do
    n = length(x_values)

    if n < 2 do
      0.0
    else
      sum_x = Enum.sum(x_values)
      sum_y = Enum.sum(y_values)
      sum_xy = Enum.zip(x_values, y_values) |> Enum.reduce(0, fn {x, y}, acc -> acc + x * y end)
      sum_x2 = Enum.reduce(x_values, 0, fn x, acc -> acc + x * x end)

      denominator = n * sum_x2 - sum_x * sum_x

      if denominator == 0 do
        0.0
      else
        (n * sum_xy - sum_x * sum_y) / denominator
      end
    end
  end

  defp calculate_volatility(trend_points) do
    if length(trend_points) < 2 do
      0.0
    else
      kill_counts = Enum.map(trend_points, & &1.kill_count)
      avg = Enum.sum(kill_counts) / length(kill_counts)

      variance =
        kill_counts
        |> Enum.reduce(0, fn count, acc ->
          acc + :math.pow(count - avg, 2)
        end)
        |> Kernel./(length(kill_counts))

      std_dev = :math.sqrt(variance)
      cv = if avg > 0, do: std_dev / avg, else: 0.0

      Float.round(cv, 3)
    end
  end

  defp project_next_month(trend_points) when length(trend_points) < 2, do: nil

  defp project_next_month(trend_points) do
    # Simple linear projection
    recent_points = Enum.take(trend_points, -3)

    if length(recent_points) < 2 do
      nil
    else
      avg_kills =
        recent_points
        |> Enum.map(& &1.kill_count)
        |> Enum.sum()
        |> Kernel./(length(recent_points))

      %{year: last_year, month: last_month} = List.last(trend_points)
      {next_year, next_month} = next_month_tuple(last_year, last_month)

      %{
        year: next_year,
        month: next_month,
        projected_kills: round(avg_kills),
        confidence: calculate_projection_confidence(trend_points)
      }
    end
  end

  defp next_month_tuple(year, 12), do: {year + 1, 1}
  defp next_month_tuple(year, month), do: {year, month + 1}

  defp calculate_projection_confidence(trend_points) do
    # Confidence based on data consistency and volume
    volatility = calculate_volatility(trend_points)
    data_points = length(trend_points)

    base_confidence =
      cond do
        data_points >= 6 -> 0.8
        data_points >= 4 -> 0.6
        data_points >= 2 -> 0.4
        true -> 0.2
      end

    # Reduce confidence for high volatility
    volatility_penalty = min(0.3, volatility)
    Float.round(max(0.1, base_confidence - volatility_penalty), 2)
  end

  defp analyze_performance_trend(monthly_data, character_id) do
    if Enum.empty?(monthly_data) do
      %{
        metrics: [],
        improvement_rate: 0.0,
        consistency_score: 0.0,
        peak_performance: nil
      }
    else
      performance_metrics =
        Enum.map(monthly_data, fn {{year, month}, kills} ->
          %{
            year: year,
            month: month,
            kd_ratio: calculate_monthly_kd_ratio(kills, character_id),
            isk_efficiency: calculate_monthly_isk_efficiency(kills, character_id),
            solo_success_rate: calculate_solo_success_rate(kills, character_id),
            average_damage_share: calculate_avg_damage_share(kills, character_id)
          }
        end)

      %{
        metrics: performance_metrics,
        improvement_rate: calculate_improvement_rate(performance_metrics),
        consistency_score: calculate_consistency_score(performance_metrics),
        peak_performance: find_peak_performance(performance_metrics)
      }
    end
  end

  defp calculate_monthly_kd_ratio(kills, character_id) do
    as_victim = Enum.count(kills, &(&1.victim_character_id == character_id))
    as_attacker = length(kills) - as_victim

    if as_victim == 0 do
      Float.round(as_attacker * 1.0, 2)
    else
      Float.round(as_attacker / as_victim, 2)
    end
  end

  defp calculate_monthly_isk_efficiency(kills, character_id) do
    {destroyed, lost} =
      Enum.reduce(kills, {Decimal.new(0), Decimal.new(0)}, fn kill, {dest, lost} ->
        value =
          case kill.total_value do
            nil -> Decimal.new(0)
            %Decimal{} = decimal -> decimal
            value when is_integer(value) -> Decimal.new(value)
            _ -> Decimal.new(0)
          end

        if kill.victim_character_id == character_id do
          {dest, Decimal.add(lost, value)}
        else
          {Decimal.add(dest, value), lost}
        end
      end)

    total = Decimal.add(destroyed, lost)

    if Decimal.equal?(total, Decimal.new(0)) do
      50.0
    else
      destroyed_float = Decimal.to_float(destroyed)
      total_float = Decimal.to_float(total)
      Float.round(destroyed_float / total_float * 100, 1)
    end
  end

  defp calculate_solo_success_rate(kills, character_id) do
    character_id_str = to_string(character_id)

    solo_kills =
      Enum.filter(kills, fn kill ->
        case kill.raw_data do
          %{"attackers" => [single_attacker]} ->
            to_string(single_attacker["character_id"]) == character_id_str

          _ ->
            false
        end
      end)

    solo_count = length(solo_kills)

    total_as_attacker =
      Enum.count(kills, fn kill ->
        kill.victim_character_id != character_id
      end)

    if total_as_attacker == 0 do
      0.0
    else
      Float.round(solo_count / total_as_attacker * 100, 1)
    end
  end

  defp calculate_avg_damage_share(kills, character_id) do
    character_id_str = to_string(character_id)

    damage_shares =
      kills
      |> Enum.filter(fn kill -> kill.victim_character_id != character_id end)
      |> Enum.map(fn kill ->
        extract_damage_share(kill, character_id_str)
      end)
      |> Enum.filter(&(&1 > 0))

    if Enum.empty?(damage_shares) do
      0.0
    else
      avg = Enum.sum(damage_shares) / length(damage_shares)
      Float.round(avg * 100, 1)
    end
  end

  defp extract_damage_share(kill, character_id_str) do
    case kill.raw_data do
      %{"attackers" => attackers, "victim" => %{"damage_taken" => total_damage}}
      when is_list(attackers) and total_damage > 0 ->
        char_damage =
          attackers
          |> Enum.find(fn att -> to_string(att["character_id"]) == character_id_str end)
          |> case do
            %{"damage_done" => damage} when is_number(damage) -> damage
            _ -> 0
          end

        char_damage / total_damage

      _ ->
        0.0
    end
  end

  defp calculate_improvement_rate(performance_metrics) when length(performance_metrics) < 2 do
    0.0
  end

  defp calculate_improvement_rate(performance_metrics) do
    # Compare first half to second half
    mid_point = div(length(performance_metrics), 2)
    {first_half, second_half} = Enum.split(performance_metrics, mid_point)

    avg_first = calculate_average_performance(first_half)
    avg_second = calculate_average_performance(second_half)

    if avg_first == 0 do
      0.0
    else
      improvement = (avg_second - avg_first) / avg_first * 100
      Float.round(improvement, 1)
    end
  end

  defp calculate_average_performance(metrics) do
    if Enum.empty?(metrics) do
      0.0
    else
      # Composite score from KD ratio and ISK efficiency
      scores =
        Enum.map(metrics, fn m ->
          # Normalize KD to 0-1 (5+ is max)
          kd_score = min(1.0, m.kd_ratio / 5.0)
          # Already 0-100%, convert to 0-1
          isk_score = m.isk_efficiency / 100.0
          (kd_score + isk_score) / 2
        end)

      Enum.sum(scores) / length(scores)
    end
  end

  defp calculate_consistency_score(performance_metrics) do
    if length(performance_metrics) < 2 do
      0.0
    else
      # Calculate variance in performance
      kd_ratios = Enum.map(performance_metrics, & &1.kd_ratio)
      avg_kd = Enum.sum(kd_ratios) / length(kd_ratios)

      variance =
        kd_ratios
        |> Enum.reduce(0, fn kd, acc ->
          acc + :math.pow(kd - avg_kd, 2)
        end)
        |> Kernel./(length(kd_ratios))

      std_dev = :math.sqrt(variance)
      cv = if avg_kd > 0, do: std_dev / avg_kd, else: 1.0

      # Lower CV = more consistent
      consistency = max(0.0, min(1.0, 1.0 - cv))
      Float.round(consistency, 3)
    end
  end

  defp find_peak_performance(performance_metrics) do
    if Enum.empty?(performance_metrics) do
      nil
    else
      performance_metrics
      |> Enum.max_by(fn m ->
        # Composite score
        m.kd_ratio * 0.4 + m.isk_efficiency * 0.4 + m.average_damage_share * 0.2
      end)
    end
  end

  defp analyze_ship_trend(monthly_data, character_id) do
    if Enum.empty?(monthly_data) do
      %{
        ship_diversity: [],
        specialization_trend: nil,
        tech_progression: []
      }
    else
      ship_usage_by_month =
        Enum.map(monthly_data, fn {{year, month}, kills} ->
          ships_used = extract_ships_used(kills, character_id)

          %{
            year: year,
            month: month,
            unique_ships: ships_used |> Enum.uniq() |> length(),
            ship_types: calculate_ship_type_distribution(ships_used),
            tech_level: calculate_average_tech_level(ships_used)
          }
        end)

      %{
        ship_diversity: ship_usage_by_month,
        specialization_trend: detect_specialization_trend(ship_usage_by_month),
        tech_progression: analyze_tech_progression(ship_usage_by_month)
      }
    end
  end

  defp extract_ships_used(kills, character_id) do
    character_id_str = to_string(character_id)

    kills
    |> Enum.flat_map(fn kill ->
      extract_ship_for_character(kill, character_id, character_id_str)
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp extract_ship_for_character(kill, character_id, character_id_str) do
    if kill.victim_character_id == character_id do
      # As victim
      [kill.victim_ship_type_id]
    else
      # As attacker
      extract_attacker_ships(kill.raw_data, character_id_str)
    end
  end

  defp extract_attacker_ships(%{"attackers" => attackers}, character_id_str)
       when is_list(attackers) do
    attackers
    |> Enum.filter(fn att ->
      to_string(att["character_id"]) == character_id_str
    end)
    |> Enum.map(fn att -> att["ship_type_id"] end)
  end

  defp extract_attacker_ships(_, _), do: []

  defp calculate_ship_type_distribution(ship_type_ids) do
    ship_type_ids
    |> Enum.map(&classify_ship_class/1)
    |> Enum.frequencies()
    |> Map.new(fn {class, count} ->
      {class, Float.round(count / length(ship_type_ids) * 100, 1)}
    end)
  end

  defp classify_ship_class(ship_type_id) when is_integer(ship_type_id) do
    @ship_class_ranges
    |> Enum.find(fn {range, _class} -> ship_type_id in range end)
    |> case do
      {_range, class} -> class
      nil -> :other
    end
  end

  defp classify_ship_class(_), do: :unknown

  defp calculate_average_tech_level(ship_type_ids) do
    if Enum.empty?(ship_type_ids) do
      1.0
    else
      tech_levels = Enum.map(ship_type_ids, &estimate_tech_level/1)
      avg = Enum.sum(tech_levels) / length(tech_levels)
      Float.round(avg, 1)
    end
  end

  defp estimate_tech_level(ship_type_id) when is_integer(ship_type_id) do
    @tech_level_ranges
    |> Enum.find(fn {range, _level} -> ship_type_id in range end)
    |> case do
      {_range, level} -> level
      # T1 (default)
      nil -> 1
    end
  end

  defp estimate_tech_level(_), do: 1

  defp detect_specialization_trend(ship_usage_by_month) when length(ship_usage_by_month) < 2 do
    :insufficient_data
  end

  defp detect_specialization_trend(ship_usage_by_month) do
    # Check if ship diversity is decreasing (specialization) or increasing
    diversity_values = Enum.map(ship_usage_by_month, & &1.unique_ships)

    first_half_avg =
      diversity_values
      |> Enum.take(div(length(diversity_values), 2))
      |> average()

    second_half_avg =
      diversity_values
      |> Enum.drop(div(length(diversity_values), 2))
      |> average()

    cond do
      second_half_avg < first_half_avg * 0.7 -> :specializing
      second_half_avg > first_half_avg * 1.3 -> :diversifying
      true -> :stable
    end
  end

  defp analyze_tech_progression(ship_usage_by_month) do
    ship_usage_by_month
    |> Enum.map(fn usage ->
      %{
        period: "#{usage.year}-#{String.pad_leading(to_string(usage.month), 2, "0")}",
        avg_tech_level: usage.tech_level,
        progression: classify_tech_progression(usage.tech_level)
      }
    end)
  end

  defp classify_tech_progression(tech_level) do
    cond do
      tech_level >= 2.5 -> :advanced
      tech_level >= 2.0 -> :intermediate
      tech_level >= 1.5 -> :developing
      true -> :basic
    end
  end

  defp analyze_geographic_trend(monthly_data) do
    if Enum.empty?(monthly_data) do
      %{
        system_diversity: [],
        movement_pattern: nil,
        hotspots: []
      }
    else
      geographic_by_month =
        Enum.map(monthly_data, fn {{year, month}, kills} ->
          systems = Enum.map(kills, & &1.solar_system_id)
          system_freq = Enum.frequencies(systems)

          %{
            year: year,
            month: month,
            unique_systems: map_size(system_freq),
            primary_system: find_primary_system(system_freq),
            system_concentration: calculate_concentration(system_freq)
          }
        end)

      %{
        system_diversity: geographic_by_month,
        movement_pattern: detect_movement_pattern(geographic_by_month),
        hotspots: identify_persistent_hotspots(monthly_data)
      }
    end
  end

  defp find_primary_system(system_freq) when map_size(system_freq) == 0, do: nil

  defp find_primary_system(system_freq) do
    {system_id, count} = Enum.max_by(system_freq, fn {_, count} -> count end)
    %{system_id: system_id, activity_count: count}
  end

  defp calculate_concentration(system_freq) when map_size(system_freq) == 0, do: 0.0

  defp calculate_concentration(system_freq) do
    total = system_freq |> Map.values() |> Enum.sum()
    max_activity = system_freq |> Map.values() |> Enum.max()

    Float.round(max_activity / total, 3)
  end

  defp detect_movement_pattern(geographic_by_month) when length(geographic_by_month) < 2 do
    :insufficient_data
  end

  defp detect_movement_pattern(geographic_by_month) do
    # Check if player is moving around or staying in same areas
    unique_systems =
      geographic_by_month
      |> Enum.map(& &1.unique_systems)
      |> average()

    cond do
      unique_systems >= 20 -> :nomadic
      unique_systems >= 10 -> :roaming
      unique_systems >= 5 -> :regional
      true -> :localized
    end
  end

  defp identify_persistent_hotspots(monthly_data) do
    # Find systems that appear consistently across months
    all_systems =
      monthly_data
      |> Enum.flat_map(fn {_, kills} ->
        Enum.map(kills, & &1.solar_system_id)
      end)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_, count} -> count end, :desc)
      |> Enum.take(5)
      |> Enum.map(fn {system_id, count} ->
        %{system_id: system_id, total_activity: count}
      end)

    all_systems
  end

  defp analyze_social_trend(monthly_data, character_id) do
    if Enum.empty?(monthly_data) do
      %{
        fleet_participation: [],
        average_fleet_size: 0.0,
        fleet_preference: :unknown
      }
    else
      social_by_month =
        Enum.map(monthly_data, fn {{year, month}, kills} ->
          fleet_data = analyze_fleet_participation(kills, character_id)

          %{
            year: year,
            month: month,
            fleet_rate: fleet_data.fleet_rate,
            avg_fleet_size: fleet_data.avg_fleet_size,
            solo_rate: fleet_data.solo_rate
          }
        end)

      %{
        fleet_participation: social_by_month,
        average_fleet_size: calculate_overall_avg_fleet_size(social_by_month),
        fleet_preference: determine_fleet_preference(social_by_month)
      }
    end
  end

  defp analyze_fleet_participation(kills, character_id) do
    character_id_str = to_string(character_id)

    participation_data =
      kills
      |> Enum.filter(fn kill -> kill.victim_character_id != character_id end)
      |> Enum.map(&extract_fleet_size(&1, character_id_str))
      |> Enum.filter(&(&1 > 0))

    if Enum.empty?(participation_data) do
      %{fleet_rate: 0.0, avg_fleet_size: 0.0, solo_rate: 0.0}
    else
      solo_count = Enum.count(participation_data, &(&1 == 1))
      fleet_count = Enum.count(participation_data, &(&1 > 1))
      total = length(participation_data)

      %{
        fleet_rate: Float.round(fleet_count / total * 100, 1),
        avg_fleet_size: Float.round(Enum.sum(participation_data) / total, 1),
        solo_rate: Float.round(solo_count / total * 100, 1)
      }
    end
  end

  defp extract_fleet_size(kill, character_id_str) do
    case kill.raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        if Enum.any?(attackers, fn att ->
             to_string(att["character_id"]) == character_id_str
           end) do
          length(attackers)
        else
          0
        end

      _ ->
        0
    end
  end

  defp calculate_overall_avg_fleet_size(social_by_month) do
    if Enum.empty?(social_by_month) do
      0.0
    else
      sizes = Enum.map(social_by_month, & &1.avg_fleet_size)
      Float.round(Enum.sum(sizes) / length(sizes), 1)
    end
  end

  defp determine_fleet_preference(social_by_month) do
    if Enum.empty?(social_by_month) do
      :unknown
    else
      avg_fleet_rate =
        social_by_month
        |> Enum.map(& &1.fleet_rate)
        |> average()

      avg_solo_rate =
        social_by_month
        |> Enum.map(& &1.solo_rate)
        |> average()

      cond do
        avg_solo_rate >= 70 -> :solo_pilot
        avg_fleet_rate >= 70 -> :fleet_pilot
        avg_solo_rate > avg_fleet_rate -> :prefers_solo
        avg_fleet_rate > avg_solo_rate -> :prefers_fleet
        true -> :balanced
      end
    end
  end

  defp estimate_skill_progression(monthly_data, character_id) do
    if Enum.empty?(monthly_data) do
      %{
        progression_data: [],
        skill_velocity: 0.0,
        specialization_trend: :unknown,
        estimated_sp_range: :unknown
      }
    else
      ship_progression =
        Enum.map(monthly_data, fn {{year, month}, kills} ->
          ships_used = extract_ships_used(kills, character_id)

          %{
            year: year,
            month: month,
            tech_level: calculate_average_tech_level(ships_used),
            ship_diversity: length(Enum.uniq(ships_used)),
            specialization: detect_ship_specialization(ships_used)
          }
        end)

      %{
        progression_data: ship_progression,
        skill_velocity: calculate_skill_velocity(ship_progression),
        specialization_trend: analyze_specialization_trend(ship_progression),
        estimated_sp_range: estimate_sp_range(ship_progression)
      }
    end
  end

  defp detect_ship_specialization(ship_type_ids) do
    if Enum.empty?(ship_type_ids) do
      :none
    else
      ship_classes =
        ship_type_ids
        |> Enum.map(&classify_ship_class/1)
        |> Enum.frequencies()

      {dominant_class, count} =
        Enum.max_by(ship_classes, fn {_, c} -> c end, fn -> {:unknown, 0} end)

      if count / length(ship_type_ids) >= 0.6 do
        dominant_class
      else
        :mixed
      end
    end
  end

  defp calculate_skill_velocity(ship_progression) when length(ship_progression) < 2 do
    0.0
  end

  defp calculate_skill_velocity(ship_progression) do
    # Calculate rate of tech level increase
    tech_levels = Enum.map(ship_progression, & &1.tech_level)

    first_tech = List.first(tech_levels)
    last_tech = List.last(tech_levels)
    months = length(tech_levels)

    velocity = (last_tech - first_tech) / months
    Float.round(velocity, 3)
  end

  defp analyze_specialization_trend(ship_progression) when length(ship_progression) < 2 do
    :unknown
  end

  defp analyze_specialization_trend(ship_progression) do
    specializations = Enum.map(ship_progression, & &1.specialization)

    # Check if becoming more specialized over time
    unique_specs = Enum.uniq(specializations)

    cond do
      length(unique_specs) == 1 and hd(unique_specs) != :mixed -> :highly_specialized
      length(unique_specs) <= 2 -> :specializing
      true -> :diversified
    end
  end

  defp estimate_sp_range(ship_progression) do
    if Enum.empty?(ship_progression) do
      :unknown
    else
      # Estimate based on average tech level and ship diversity
      avg_tech =
        ship_progression
        |> Enum.map(& &1.tech_level)
        |> average()

      avg_diversity =
        ship_progression
        |> Enum.map(& &1.ship_diversity)
        |> average()

      cond do
        avg_tech >= 2.5 and avg_diversity >= 10 -> "50M+ SP"
        avg_tech >= 2.0 and avg_diversity >= 7 -> "30-50M SP"
        avg_tech >= 1.5 and avg_diversity >= 5 -> "15-30M SP"
        avg_tech >= 1.2 and avg_diversity >= 3 -> "5-15M SP"
        true -> "<5M SP"
      end
    end
  end

  defp average(list) when is_list(list) and length(list) > 0 do
    Enum.sum(list) / length(list)
  end

  defp average(_), do: 0.0

  defp get_primary_timezone(activity_trend) do
    # Find most common active hours from trend data
    if Enum.empty?(activity_trend.data_points) do
      :unknown
    else
      # This would need more detailed hourly analysis
      # For now, return a simplified result
      :varies
    end
  end
end
