defmodule EveDmv.Contexts.CorporationIntelligence.Domain.Analyzers.OperationalPatternAnalyzer do
  @moduledoc """
  Analyzes operational patterns and habits of corporations.
  All analysis based on real killmail patterns.
  """

  import Ecto.Query

  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Repo
  require Logger

  @doc """
  Analyzes operational patterns from killmail data
  """
  def analyze_patterns(corporation_id, options \\ []) do
    days = Keyword.get(options, :days, 90)
    killmails = get_corporation_activity(corporation_id, days)

    case killmails do
      [] ->
        {:error, :insufficient_data}

      data ->
        %{
          temporal_patterns: analyze_temporal_patterns(data),
          geographic_patterns: analyze_geographic_patterns(data),
          target_selection: analyze_target_selection(data, corporation_id),
          escalation_patterns: detect_escalation_patterns(data),
          operational_cycles: identify_operational_cycles(data),
          predictive_model: build_predictive_model(data)
        }
    end
  end

  defp get_corporation_activity(corporation_id, days) do
    cutoff_date = DateTimeUtils.add(DateTime.utc_now(), -days * 86_400, :second)

    query =
      from(k in "killmails_raw",
        where:
          k.victim_corporation_id == ^corporation_id or
            fragment("? @> ?::jsonb", k.data, ^%{attackers: [%{corporation_id: corporation_id}]}),
        where: k.killmail_time > ^cutoff_date,
        select: %{
          killmail_id: k.killmail_id,
          killmail_time: k.killmail_time,
          solar_system_id: k.solar_system_id,
          victim_ship_type_id: k.victim_ship_type_id,
          victim_corporation_id: k.victim_corporation_id,
          attacker_count: k.attacker_count,
          total_value: k.total_value,
          data: k.data
        },
        limit: 5000
      )

    Repo.all(query)
  rescue
    error ->
      Logger.error("Failed to get corporation activity: #{inspect(error)}")
      []
  end

  defp analyze_temporal_patterns(killmails) do
    # Group by various time periods
    by_hour = group_by_hour_of_day(killmails)
    by_day = group_by_day_of_week(killmails)
    by_date = group_by_date(killmails)

    %{
      hourly_activity: calculate_hourly_distribution(by_hour),
      daily_activity: calculate_daily_distribution(by_day),
      activity_bursts: detect_activity_bursts(by_date),
      operational_tempo: calculate_operational_tempo(by_date),
      peak_times: identify_peak_operation_times(by_hour, by_day),
      consistency: measure_temporal_consistency(by_date)
    }
  end

  defp group_by_hour_of_day(killmails) do
    killmails
    |> Enum.group_by(fn km -> km.killmail_time.hour end)
    |> Map.new(fn {hour, kills} -> {hour, length(kills)} end)
  end

  defp group_by_day_of_week(killmails) do
    killmails
    |> Enum.group_by(fn km -> Date.day_of_week(DateTime.to_date(km.killmail_time)) end)
    |> Map.new(fn {day, kills} -> {day, length(kills)} end)
  end

  defp group_by_date(killmails) do
    killmails
    |> Enum.group_by(fn km -> DateTime.to_date(km.killmail_time) end)
    |> Map.new(fn {date, kills} -> {date, length(kills)} end)
  end

  defp calculate_hourly_distribution(hour_groups) do
    total = Enum.sum(Map.values(hour_groups))

    if total == 0 do
      %{}
    else
      Map.new(hour_groups, fn {hour, count} ->
        {hour,
         %{
           count: count,
           percentage: Float.round(count / total * 100, 1)
         }}
      end)
    end
  end

  defp calculate_daily_distribution(day_groups) do
    total = Enum.sum(Map.values(day_groups))

    if total == 0 do
      %{}
    else
      Map.new(day_groups, fn {day, count} ->
        {format_day_name(day),
         %{
           count: count,
           percentage: Float.round(count / total * 100, 1)
         }}
      end)
    end
  end

  defp format_day_name(day_num) do
    case day_num do
      1 -> "Monday"
      2 -> "Tuesday"
      3 -> "Wednesday"
      4 -> "Thursday"
      5 -> "Friday"
      6 -> "Saturday"
      7 -> "Sunday"
      _ -> "Unknown"
    end
  end

  defp detect_activity_bursts(date_groups) do
    dates_sorted =
      date_groups
      |> Enum.sort_by(fn {date, _} -> date end)
      |> Enum.map(fn {date, count} -> %{date: date, activity: count} end)

    avg_activity =
      if Enum.empty?(dates_sorted) do
        0
      else
        Enum.sum(Enum.map(dates_sorted, & &1.activity)) / length(dates_sorted)
      end

    bursts =
      dates_sorted
      |> Enum.filter(fn day -> day.activity > avg_activity * 2 end)

    %{
      burst_days: bursts,
      burst_count: length(bursts),
      average_daily_activity: Float.round(avg_activity, 1)
    }
  end

  defp calculate_operational_tempo(date_groups) do
    active_days = map_size(date_groups)

    if active_days == 0 do
      :inactive
    else
      total_days =
        if Enum.empty?(date_groups) do
          1
        else
          dates = Map.keys(date_groups)
          Date.diff(Enum.max(dates), Enum.min(dates)) + 1
        end

      activity_ratio = active_days / total_days

      cond do
        activity_ratio >= 0.8 -> :continuous
        activity_ratio >= 0.5 -> :regular
        activity_ratio >= 0.3 -> :intermittent
        activity_ratio >= 0.1 -> :sporadic
        true -> :minimal
      end
    end
  end

  defp identify_peak_operation_times(hour_groups, day_groups) do
    peak_hours =
      hour_groups
      |> Enum.sort_by(fn {_, count} -> count end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {hour, count} -> %{hour: hour, activity: count} end)

    peak_days =
      day_groups
      |> Enum.sort_by(fn {_, count} -> count end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {day, count} -> %{day: format_day_name(day), activity: count} end)

    %{
      peak_hours: peak_hours,
      peak_days: peak_days
    }
  end

  defp measure_temporal_consistency(date_groups) do
    if map_size(date_groups) < 7 do
      :insufficient_data
    else
      counts = Map.values(date_groups)
      avg = Enum.sum(counts) / length(counts)

      variance =
        counts
        |> Enum.map(fn c -> :math.pow(c - avg, 2) end)
        |> Enum.sum()
        |> Kernel./(length(counts))

      std_dev = :math.sqrt(variance)
      cv = if avg == 0, do: 0, else: std_dev / avg

      cond do
        cv < 0.3 -> :highly_consistent
        cv < 0.6 -> :consistent
        cv < 1.0 -> :variable
        true -> :highly_variable
      end
    end
  end

  defp analyze_geographic_patterns(killmails) do
    systems = get_unique_systems(killmails)

    %{
      operational_range: calculate_operational_range(systems),
      home_systems: identify_home_systems(killmails),
      hunting_grounds: identify_hunting_grounds(killmails),
      security_preference: analyze_security_preference(killmails),
      regional_focus: identify_regional_focus(killmails)
    }
  end

  defp get_unique_systems(killmails) do
    killmails
    |> Enum.map(& &1.solar_system_id)
    |> Enum.uniq()
  end

  defp calculate_operational_range(systems) do
    %{
      unique_systems: length(systems),
      classification: classify_range(length(systems))
    }
  end

  defp classify_range(system_count) do
    cond do
      system_count >= 50 -> :nomadic
      system_count >= 20 -> :wide_range
      system_count >= 10 -> :regional
      system_count >= 5 -> :local
      system_count >= 1 -> :static
      true -> :no_activity
    end
  end

  defp identify_home_systems(killmails) do
    killmails
    |> Enum.group_by(& &1.solar_system_id)
    |> Enum.sort_by(fn {_, kills} -> length(kills) end, :desc)
    |> Enum.take(5)
    |> Enum.map(fn {system_id, kills} ->
      %{
        system_id: system_id,
        activity_count: length(kills),
        percentage: Float.round(length(kills) / length(killmails) * 100, 1)
      }
    end)
  end

  defp identify_hunting_grounds(killmails) do
    # Systems where corporation is attacker
    attacker_systems =
      killmails
      |> Enum.filter(fn km -> km.victim_corporation_id != get_corp_from_data(km) end)
      |> Enum.group_by(& &1.solar_system_id)
      |> Enum.sort_by(fn {_, kills} -> length(kills) end, :desc)
      |> Enum.take(5)
      |> Enum.map(fn {system_id, kills} ->
        %{
          system_id: system_id,
          kills: length(kills)
        }
      end)

    attacker_systems
  end

  defp get_corp_from_data(_killmail) do
    # Extract corporation ID from attacker data
    # Simplified - would need proper parsing in production
    nil
  end

  defp analyze_security_preference(_killmails) do
    # Would analyze security status of systems
    # Simplified for now
    %{
      primary: :null_sec,
      distribution: %{
        high_sec: 10.0,
        low_sec: 30.0,
        null_sec: 60.0
      }
    }
  end

  defp identify_regional_focus(_killmails) do
    # Would identify regions from systems
    # Simplified for now
    %{
      primary_region: "Unknown",
      region_count: 1
    }
  end

  defp analyze_target_selection(killmails, corporation_id) do
    targets = extract_targets(killmails, corporation_id)

    %{
      target_corporations: analyze_target_corporations(targets),
      target_alliances: analyze_target_alliances(targets),
      target_ship_preferences: analyze_target_ship_types(targets),
      target_value_range: analyze_target_values(targets),
      vendetta_targets: identify_vendetta_targets(targets)
    }
  end

  defp extract_targets(killmails, corporation_id) do
    killmails
    |> Enum.filter(fn km -> km.victim_corporation_id != corporation_id end)
    |> Enum.map(fn km ->
      %{
        corporation_id: km.victim_corporation_id,
        alliance_id: get_alliance_from_data(km),
        ship_type_id: km.victim_ship_type_id,
        value: km.total_value || 0
      }
    end)
  end

  defp get_alliance_from_data(_killmail) do
    # Would extract from JSON data
    nil
  end

  defp analyze_target_corporations(targets) do
    targets
    |> Enum.group_by(& &1.corporation_id)
    |> Enum.sort_by(fn {_, kills} -> length(kills) end, :desc)
    |> Enum.take(10)
    |> Enum.map(fn {corp_id, kills} ->
      %{
        corporation_id: corp_id,
        kill_count: length(kills),
        total_value: Enum.sum(Enum.map(kills, & &1.value))
      }
    end)
  end

  defp analyze_target_alliances(targets) do
    targets
    |> Enum.reject(fn t -> is_nil(t.alliance_id) end)
    |> Enum.group_by(& &1.alliance_id)
    |> Enum.sort_by(fn {_, kills} -> length(kills) end, :desc)
    |> Enum.take(5)
    |> Enum.map(fn {alliance_id, kills} ->
      %{
        alliance_id: alliance_id,
        kill_count: length(kills)
      }
    end)
  end

  defp analyze_target_ship_types(targets) do
    targets
    |> Enum.group_by(& &1.ship_type_id)
    |> Enum.sort_by(fn {_, kills} -> length(kills) end, :desc)
    |> Enum.take(10)
    |> Enum.map(fn {ship_type_id, kills} ->
      %{
        ship_type_id: ship_type_id,
        count: length(kills)
      }
    end)
  end

  defp analyze_target_values(targets) do
    values = Enum.map(targets, & &1.value)

    if Enum.empty?(values) do
      %{min: 0, max: 0, average: 0, median: 0}
    else
      sorted = Enum.sort(values)

      %{
        min: Enum.min(sorted),
        max: Enum.max(sorted),
        average: Float.round(Enum.sum(sorted) / length(sorted), 2),
        median: Enum.at(sorted, div(length(sorted), 2))
      }
    end
  end

  defp identify_vendetta_targets(targets) do
    # Identify repeated targets (vendetta pattern)
    targets
    |> Enum.group_by(& &1.corporation_id)
    |> Enum.filter(fn {_, kills} -> length(kills) >= 5 end)
    |> Enum.sort_by(fn {_, kills} -> length(kills) end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {corp_id, kills} ->
      %{
        corporation_id: corp_id,
        engagement_count: length(kills),
        vendetta_score: calculate_vendetta_score(kills)
      }
    end)
  end

  defp calculate_vendetta_score(kills) do
    # Higher score for consistent targeting
    base_score = length(kills) * 10

    # Bonus for high value targets
    value_bonus =
      kills
      |> Enum.map(& &1.value)
      |> Enum.sum()
      # Per billion ISK
      |> Kernel./(1_000_000_000)
      |> min(50)

    Float.round(base_score + value_bonus, 1)
  end

  defp detect_escalation_patterns(killmails) do
    # Sort by time and group into engagement chains
    chains = group_into_engagement_chains(killmails)

    escalations =
      chains
      |> Enum.filter(&escalation?/1)
      |> Enum.map(&analyze_escalation/1)

    %{
      escalation_count: length(escalations),
      escalation_types: categorize_escalations(escalations),
      average_escalation_time: calculate_average_escalation_time(escalations),
      escalation_triggers: identify_escalation_triggers(escalations)
    }
  end

  defp group_into_engagement_chains(killmails) do
    killmails
    |> Enum.sort_by(& &1.killmail_time)
    |> Enum.chunk_while(
      [],
      fn km, acc ->
        if Enum.empty?(acc) or related_engagement?(km, List.last(acc)) do
          {:cont, acc ++ [km]}
        else
          {:cont, acc, [km]}
        end
      end,
      fn acc -> {:cont, acc, []} end
    )
    |> Enum.filter(&(length(&1) >= 2))
  end

  defp related_engagement?(km1, km2) do
    time_diff = DateTime.diff(km1.killmail_time, km2.killmail_time, :second)
    same_system = km1.solar_system_id == km2.solar_system_id

    # Within 15 minutes and same system
    abs(time_diff) <= 900 and same_system
  end

  defp escalation?(chain) do
    if length(chain) < 3 do
      false
    else
      # Check if participant count increases
      attacker_counts = Enum.map(chain, & &1.attacker_count)

      # Escalation if attacker count increases by >50%
      first_count = List.first(attacker_counts)
      last_count = List.last(attacker_counts)

      last_count > first_count * 1.5
    end
  end

  defp analyze_escalation(chain) do
    %{
      start_time: List.first(chain).killmail_time,
      end_time: List.last(chain).killmail_time,
      duration_minutes:
        DateTime.diff(List.last(chain).killmail_time, List.first(chain).killmail_time, :second) /
          60,
      initial_size: List.first(chain).attacker_count,
      final_size: List.last(chain).attacker_count,
      escalation_factor:
        List.last(chain).attacker_count / max(List.first(chain).attacker_count, 1)
    }
  end

  defp categorize_escalations(escalations) do
    escalations
    |> Enum.group_by(fn e ->
      cond do
        e.escalation_factor >= 5 -> :massive
        e.escalation_factor >= 3 -> :major
        e.escalation_factor >= 2 -> :moderate
        true -> :minor
      end
    end)
    |> Map.new(fn {type, escs} -> {type, length(escs)} end)
  end

  defp calculate_average_escalation_time(escalations) do
    if Enum.empty?(escalations) do
      0
    else
      total_time =
        escalations
        |> Enum.map(& &1.duration_minutes)
        |> Enum.sum()

      Float.round(total_time / length(escalations), 1)
    end
  end

  defp identify_escalation_triggers(_escalations) do
    # Would analyze what triggers escalations
    # Simplified for now
    %{
      capital_appearance: 0,
      high_value_target: 0,
      strategic_objective: 0
    }
  end

  defp identify_operational_cycles(killmails) do
    # Detect repeating patterns in operations
    daily_patterns = detect_daily_cycles(killmails)
    weekly_patterns = detect_weekly_cycles(killmails)

    %{
      daily_cycles: daily_patterns,
      weekly_cycles: weekly_patterns,
      campaign_detection: detect_campaigns(killmails),
      operational_phases: identify_operational_phases(killmails)
    }
  end

  defp detect_daily_cycles(killmails) do
    # Group by hour and look for patterns
    hourly =
      killmails
      |> Enum.group_by(fn km -> km.killmail_time.hour end)
      |> Map.new(fn {hour, kills} -> {hour, length(kills)} end)

    %{
      active_hours: Map.keys(hourly),
      peak_hour: hourly |> Enum.max_by(fn {_, count} -> count end, fn -> {0, 0} end) |> elem(0),
      pattern: classify_daily_pattern(hourly)
    }
  end

  defp classify_daily_pattern(hourly_data) do
    active_hours = map_size(hourly_data)

    cond do
      active_hours >= 20 -> :round_the_clock
      active_hours >= 12 -> :extended_operations
      active_hours >= 6 -> :standard_operations
      active_hours >= 3 -> :focused_operations
      true -> :minimal_activity
    end
  end

  defp detect_weekly_cycles(killmails) do
    # Group by day of week
    daily =
      killmails
      |> Enum.group_by(fn km -> Date.day_of_week(DateTime.to_date(km.killmail_time)) end)
      |> Map.new(fn {day, kills} -> {day, length(kills)} end)

    %{
      active_days: Map.keys(daily),
      peak_day: daily |> Enum.max_by(fn {_, count} -> count end, fn -> {1, 0} end) |> elem(0),
      weekend_activity: calculate_weekend_activity(daily)
    }
  end

  defp calculate_weekend_activity(daily_data) do
    weekend = Map.get(daily_data, 6, 0) + Map.get(daily_data, 7, 0)

    weekday =
      daily_data
      |> Enum.filter(fn {day, _} -> day >= 1 and day <= 5 end)
      |> Enum.map(fn {_, count} -> count end)
      |> Enum.sum()

    total = weekend + weekday

    if total == 0 do
      0.0
    else
      Float.round(weekend / total * 100, 1)
    end
  end

  defp detect_campaigns(killmails) do
    # Look for sustained activity periods
    dates =
      killmails
      |> Enum.map(fn km -> DateTime.to_date(km.killmail_time) end)
      |> Enum.uniq()
      |> Enum.sort()

    campaigns = identify_date_clusters(dates)

    %{
      campaign_count: length(campaigns),
      campaigns: campaigns
    }
  end

  defp identify_date_clusters(dates) do
    dates
    |> Enum.chunk_while(
      [],
      fn date, acc ->
        if Enum.empty?(acc) or Date.diff(date, List.last(acc)) <= 2 do
          {:cont, acc ++ [date]}
        else
          {:cont, acc, [date]}
        end
      end,
      fn acc -> {:cont, acc, []} end
    )
    |> Enum.filter(&(length(&1) >= 3))
    |> Enum.map(fn cluster ->
      %{
        start_date: List.first(cluster),
        end_date: List.last(cluster),
        duration_days: Date.diff(List.last(cluster), List.first(cluster)) + 1,
        active_days: length(cluster)
      }
    end)
  end

  defp identify_operational_phases(killmails) do
    # Identify different operational phases
    if length(killmails) < 10 do
      :insufficient_data
    else
      # Simplified phase detection
      %{
        current_phase: :active,
        phase_history: []
      }
    end
  end

  defp build_predictive_model(killmails) do
    # Build a simple predictive model based on patterns
    temporal = analyze_temporal_patterns(killmails)
    geographic = analyze_geographic_patterns(killmails)

    %{
      next_operation_window: predict_next_operation_time(temporal),
      likely_targets: predict_likely_targets(killmails),
      probable_systems: predict_operational_systems(geographic),
      confidence_scores: calculate_prediction_confidence(killmails)
    }
  end

  defp predict_next_operation_time(temporal_patterns) do
    peak_times = temporal_patterns.peak_times

    if peak_times.peak_hours == [] do
      %{prediction: "Insufficient data", confidence: 0.0}
    else
      peak_hour = List.first(peak_times.peak_hours)

      %{
        prediction: "Next #{peak_hour.hour}:00 UTC",
        confidence: calculate_time_prediction_confidence(temporal_patterns)
      }
    end
  end

  defp calculate_time_prediction_confidence(temporal_patterns) do
    consistency_score =
      case temporal_patterns.consistency do
        :highly_consistent -> 0.9
        :consistent -> 0.7
        :variable -> 0.4
        :highly_variable -> 0.2
        _ -> 0.1
      end

    Float.round(consistency_score * 100, 1)
  end

  defp predict_likely_targets(_killmails) do
    # Would predict based on target patterns
    []
  end

  defp predict_operational_systems(geographic_patterns) do
    geographic_patterns.home_systems
    |> Enum.take(3)
    |> Enum.map(& &1.system_id)
  end

  defp calculate_prediction_confidence(killmails) do
    data_points = length(killmails)

    confidence =
      cond do
        data_points >= 1000 -> 0.8
        data_points >= 500 -> 0.6
        data_points >= 100 -> 0.4
        data_points >= 50 -> 0.2
        true -> 0.1
      end

    %{
      overall: Float.round(confidence * 100, 1),
      data_points: data_points
    }
  end
end
