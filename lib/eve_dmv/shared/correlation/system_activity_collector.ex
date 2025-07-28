defmodule EveDmv.Shared.Correlation.SystemActivityCollector do
  @moduledoc """
  Collects and processes activity data from multiple systems.

  Responsible for:
  - Fetching killmail data across multiple systems
  - Processing raw killmail data into structured activities
  - Extracting pilot, corporation, and ship activity data
  - Creating temporal markers for correlation analysis
  - Classifying activity types and participants
  """

  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw

  require Logger

  @doc """
  Fetches activity data for multiple systems within a time window.
  """
  def fetch_system_activities(system_ids, time_window_hours) do
    since = DateTime.utc_now() |> DateTime.add(-time_window_hours * 3600, :second)

    activities =
      Enum.map(system_ids, fn system_id ->
        case get_system_killmails(system_id, since) do
          {:ok, killmails} ->
            %{
              system_id: system_id,
              activities: process_killmail_activities(killmails),
              pilot_activity: extract_pilot_activity_data(killmails),
              corp_activity: extract_corp_activity_data(killmails),
              ship_activity: extract_ship_activity_data(killmails),
              temporal_markers: extract_temporal_markers(killmails)
            }

          {:error, _reason} ->
            %{
              system_id: system_id,
              activities: [],
              pilot_activity: %{},
              corp_activity: %{},
              ship_activity: %{},
              temporal_markers: []
            }
        end
      end)

    {:ok, activities}
  end

  @doc """
  Processes killmail data into structured activity information.
  """
  def process_killmail_activities(killmails) do
    Enum.map(killmails, fn killmail ->
      %{
        killmail_id: killmail.killmail_id,
        timestamp: killmail.timestamp,
        system_id: killmail.solar_system_id,
        activity_type: classify_activity_type(killmail),
        participants: count_participants(killmail),
        value: killmail.total_value || 0,
        ship_types: extract_ship_types_from_killmail(killmail),
        involved_pilots: extract_all_participants_from_killmail(killmail),
        involved_corps: extract_corp_ids_from_killmail(killmail)
      }
    end)
  end

  @doc """
  Extracts pilot activity patterns from killmail data.
  """
  def extract_pilot_activity_data(killmails) do
    killmails
    |> Enum.flat_map(&extract_all_participants_from_killmail/1)
    |> Enum.frequencies()
    |> Enum.map(fn {pilot_id, participations} ->
      pilot_activities =
        Enum.filter(killmails, fn km ->
          pilot_id in extract_all_participants_from_killmail(km)
        end)

      {pilot_id,
       %{
         participations: participations,
         activity_frequency: classify_activity_frequency(participations, 24),
         engagements: analyze_pilot_activity_pattern(pilot_activities),
         preferred_ship: find_preferred_ship(pilot_activities),
         systems_active: pilot_activities |> Enum.map(& &1.solar_system_id) |> Enum.uniq()
       }}
    end)
    |> Map.new()
  end

  @doc """
  Extracts corporation activity patterns from killmail data.
  """
  def extract_corp_activity_data(killmails) do
    killmails
    |> Enum.flat_map(&extract_corp_ids_from_killmail/1)
    |> Enum.frequencies()
    |> Enum.map(fn {corp_id, participations} ->
      corp_activities =
        Enum.filter(killmails, fn km ->
          corp_id in extract_corp_ids_from_killmail(km)
        end)

      {corp_id,
       %{
         participations: participations,
         engagement_type: classify_corp_engagements(participations),
         systems_active: corp_activities |> Enum.map(& &1.solar_system_id) |> Enum.uniq(),
         member_count: estimate_active_members(corp_activities),
         preferred_ships: analyze_corp_ship_preferences(corp_activities),
         activity_timeline: extract_corp_timeline(corp_activities)
       }}
    end)
    |> Map.new()
  end

  @doc """
  Extracts ship activity patterns from killmail data.
  """
  def extract_ship_activity_data(killmails) do
    killmails
    |> Enum.flat_map(&extract_ship_types_from_killmail/1)
    |> Enum.frequencies()
    |> Enum.map(fn {ship_type_id, usage_count} ->
      ship_activities =
        Enum.filter(killmails, fn km ->
          ship_type_id in extract_ship_types_from_killmail(km)
        end)

      {ship_type_id,
       %{
         usage_count: usage_count,
         ship_classification: classify_ship_type(ship_type_id),
         systems_used: ship_activities |> Enum.map(& &1.solar_system_id) |> Enum.uniq(),
         average_engagement_size: calculate_average_engagement_size(ship_activities),
         survival_rate: calculate_ship_survival_rate(ship_type_id, ship_activities)
       }}
    end)
    |> Map.new()
  end

  @doc """
  Creates temporal markers for activity correlation analysis.
  """
  def extract_temporal_markers(killmails) do
    timestamps = Enum.map(killmails, & &1.timestamp) |> Enum.sort(DateTime)

    if length(timestamps) < 2 do
      []
    else
      patterns = identify_temporal_patterns(timestamps)

      %{
        total_events: length(killmails),
        time_span_hours: calculate_time_span_hours(timestamps),
        temporal_patterns: patterns,
        activity_density: calculate_activity_density(timestamps),
        peak_periods: identify_peak_activity_periods(timestamps),
        quiet_periods: identify_quiet_periods(calculate_time_gaps(timestamps))
      }
    end
  end

  @doc """
  Analyzes activity density and distribution patterns.
  """
  def analyze_activity_distribution(activities) do
    if Enum.empty?(activities) do
      %{distribution_type: :no_activity}
    else
      timestamps = Enum.map(activities, & &1.timestamp)
      hourly_distribution = group_by_hour(timestamps)
      daily_distribution = group_by_day_of_week(timestamps)

      %{
        distribution_type: :temporal_analysis,
        hourly_distribution: hourly_distribution,
        daily_distribution: daily_distribution,
        peak_hour: find_peak_hour(hourly_distribution),
        peak_day: find_peak_day(daily_distribution),
        activity_consistency: calculate_activity_consistency(hourly_distribution),
        distribution_entropy: calculate_distribution_entropy(hourly_distribution)
      }
    end
  end

  # Private functions

  defp get_system_killmails(system_id, since) do
    try do
      killmails =
        Api.read!(KillmailRaw,
          filter: [
            solar_system_id: system_id,
            timestamp: [greater_than: since]
          ],
          limit: 1000
        )

      {:ok, killmails}
    rescue
      e ->
        Logger.error("Failed to fetch killmails for system #{system_id}: #{inspect(e)}")
        {:error, :fetch_failed}
    end
  end

  defp classify_activity_type(killmail) do
    participant_count = count_participants(killmail)
    value = killmail.total_value || 0

    cond do
      participant_count == 1 -> :solo_kill
      participant_count <= 5 -> :small_gang
      participant_count <= 15 -> :medium_fleet
      participant_count > 15 -> :large_fleet
      value >= 1_000_000_000 -> :high_value_kill
      true -> :standard_engagement
    end
  end

  defp count_participants(killmail) do
    # Count victim + attackers
    base_count = 1

    attacker_count =
      case killmail.zkb_data do
        %{"attackers" => attackers} when is_list(attackers) ->
          length(attackers)

        _ ->
          0
      end

    base_count + attacker_count
  end

  defp extract_all_participants_from_killmail(killmail) do
    # Extract victim
    victim_ids = [killmail.victim_character_id] |> Enum.filter(& &1)

    # Extract attackers
    attacker_ids =
      case killmail.zkb_data do
        %{"attackers" => attackers} when is_list(attackers) ->
          Enum.map(attackers, & &1["character_id"]) |> Enum.filter(& &1)

        _ ->
          []
      end

    (victim_ids ++ attacker_ids) |> Enum.uniq()
  end

  defp extract_corp_ids_from_killmail(killmail) do
    # Extract victim corp
    victim_corps =
      case killmail.zkb_data do
        %{"victim" => %{"corporation_id" => corp_id}} when is_integer(corp_id) ->
          [corp_id]

        _ ->
          []
      end

    # Extract attacker corps
    attacker_corps =
      case killmail.zkb_data do
        %{"attackers" => attackers} when is_list(attackers) ->
          Enum.map(attackers, fn attacker ->
            Map.get(attacker, "corporation_id")
          end)
          |> Enum.filter(&is_integer(&1))

        _ ->
          []
      end

    (victim_corps ++ attacker_corps) |> Enum.uniq()
  end

  defp extract_ship_types_from_killmail(killmail) do
    # Extract victim ship
    victim_ships = [killmail.victim_ship_type_id] |> Enum.filter(& &1)

    # Extract attacker ships
    attacker_ships =
      case killmail.zkb_data do
        %{"attackers" => attackers} when is_list(attackers) ->
          Enum.map(attackers, & &1["ship_type_id"]) |> Enum.filter(& &1)

        _ ->
          []
      end

    (victim_ships ++ attacker_ships) |> Enum.uniq()
  end

  defp identify_temporal_patterns(timestamps) do
    if length(timestamps) < 3 do
      %{pattern_type: :insufficient_data}
    else
      gaps = calculate_time_gaps(timestamps)
      avg_gap = calculate_average_gap(gaps)
      burst_periods = identify_burst_periods(timestamps)
      periodicity = detect_periodicity(gaps)

      %{
        pattern_type: :temporal_analysis,
        average_gap_minutes: avg_gap,
        burst_periods: burst_periods,
        periodicity: periodicity,
        temporal_clustering: assess_temporal_clustering(gaps)
      }
    end
  end

  defp calculate_time_gaps([]), do: []
  defp calculate_time_gaps([_]), do: []

  defp calculate_time_gaps([t1, t2 | rest]) do
    gap_minutes = DateTime.diff(t2, t1, :minute)
    [gap_minutes | calculate_time_gaps([t2 | rest])]
  end

  defp calculate_average_gap([]), do: 0

  defp calculate_average_gap(gaps) do
    Enum.sum(gaps) / length(gaps)
  end

  defp identify_burst_periods(timestamps) do
    # Group timestamps into 30-minute windows
    windows = group_timestamps_into_windows(timestamps, 30)

    # Identify windows with high activity
    window_threshold = calculate_burst_threshold(windows)

    Enum.filter(windows, fn {_window_start, events} ->
      length(events) >= window_threshold
    end)
    |> Enum.map(fn {window_start, events} ->
      %{
        window_start: window_start,
        event_count: length(events),
        duration_minutes: 30,
        intensity: length(events) / 30.0
      }
    end)
  end

  defp detect_periodicity(gaps) do
    if length(gaps) < 5 do
      %{periodic: false}
    else
      # Simple periodicity detection
      mean_gap = Enum.sum(gaps) / length(gaps)
      variance = calculate_variance(gaps, mean_gap)

      # If variance is low relative to mean, gaps are regular
      coefficient_of_variation = if mean_gap > 0, do: :math.sqrt(variance) / mean_gap, else: 0

      %{
        periodic: coefficient_of_variation < 0.5,
        mean_interval_minutes: Float.round(mean_gap, 1),
        regularity_score: Float.round(1.0 - min(1.0, coefficient_of_variation), 2)
      }
    end
  end

  defp calculate_variance(values, mean) do
    if length(values) <= 1 do
      0.0
    else
      sum_squared_diffs = Enum.sum(Enum.map(values, fn v -> :math.pow(v - mean, 2) end))
      sum_squared_diffs / length(values)
    end
  end

  defp identify_quiet_periods(gaps) do
    # Identify gaps longer than 2 hours (120 minutes)
    long_gaps = Enum.filter(gaps, &(&1 > 120))

    Enum.map(long_gaps, fn gap_minutes ->
      %{
        duration_minutes: gap_minutes,
        significance: classify_gap_significance(gap_minutes)
      }
    end)
  end

  defp classify_gap_significance(gap_minutes) do
    cond do
      # > 12 hours
      gap_minutes > 720 -> :major_quiet_period
      # > 6 hours  
      gap_minutes > 360 -> :significant_gap
      # > 3 hours
      gap_minutes > 180 -> :moderate_gap
      true -> :minor_gap
    end
  end

  defp assess_temporal_clustering(gaps) do
    if length(gaps) < 3 do
      :insufficient_data
    else
      # Short gaps indicate clustering
      # 30 minutes or less
      short_gaps = Enum.count(gaps, &(&1 <= 30))
      clustering_ratio = short_gaps / length(gaps)

      cond do
        clustering_ratio >= 0.7 -> :highly_clustered
        clustering_ratio >= 0.5 -> :moderately_clustered
        clustering_ratio >= 0.3 -> :weakly_clustered
        true -> :distributed
      end
    end
  end

  defp calculate_time_span_hours(timestamps) do
    if length(timestamps) < 2 do
      0
    else
      first = List.first(timestamps)
      last = List.last(timestamps)
      DateTime.diff(last, first, :hour)
    end
  end

  defp calculate_activity_density(timestamps) do
    time_span_hours = calculate_time_span_hours(timestamps)

    if time_span_hours > 0 do
      length(timestamps) / time_span_hours
    else
      0.0
    end
  end

  defp identify_peak_activity_periods(timestamps) do
    # Group into hourly buckets and find peaks
    hourly_counts = group_by_hour(timestamps)

    if map_size(hourly_counts) == 0 do
      []
    else
      avg_hourly =
        hourly_counts |> Map.values() |> Enum.sum() |> Kernel./(map_size(hourly_counts))

      threshold = avg_hourly * 1.5

      hourly_counts
      |> Enum.filter(fn {_hour, count} -> count >= threshold end)
      |> Enum.map(fn {hour, count} -> %{hour: hour, event_count: count} end)
    end
  end

  defp group_by_hour(timestamps) do
    timestamps
    |> Enum.group_by(& &1.hour)
    |> Enum.map(fn {hour, hour_timestamps} -> {hour, length(hour_timestamps)} end)
    |> Map.new()
  end

  defp group_by_day_of_week(timestamps) do
    timestamps
    |> Enum.group_by(&Date.day_of_week(&1))
    |> Enum.map(fn {day, day_timestamps} -> {day, length(day_timestamps)} end)
    |> Map.new()
  end

  defp find_peak_hour(hourly_distribution) do
    if map_size(hourly_distribution) == 0 do
      nil
    else
      hourly_distribution
      |> Enum.max_by(fn {_hour, count} -> count end)
      |> elem(0)
    end
  end

  defp find_peak_day(daily_distribution) do
    if map_size(daily_distribution) == 0 do
      nil
    else
      daily_distribution
      |> Enum.max_by(fn {_day, count} -> count end)
      |> elem(0)
    end
  end

  defp calculate_activity_consistency(hourly_distribution) do
    if map_size(hourly_distribution) < 3 do
      :insufficient_data
    else
      counts = Map.values(hourly_distribution)
      mean = Enum.sum(counts) / length(counts)
      variance = calculate_variance(counts, mean)
      cv = if mean > 0, do: :math.sqrt(variance) / mean, else: 0

      cond do
        cv <= 0.3 -> :very_consistent
        cv <= 0.6 -> :consistent
        cv <= 1.0 -> :moderately_consistent
        true -> :inconsistent
      end
    end
  end

  defp calculate_distribution_entropy(distribution) do
    if map_size(distribution) == 0 do
      0.0
    else
      total = distribution |> Map.values() |> Enum.sum()

      if total == 0 do
        0.0
      else
        entropy =
          distribution
          |> Map.values()
          |> Enum.map(fn count ->
            p = count / total
            if p > 0, do: -p * :math.log2(p), else: 0
          end)
          |> Enum.sum()

        Float.round(entropy, 3)
      end
    end
  end

  defp group_timestamps_into_windows(timestamps, window_minutes) do
    if Enum.empty?(timestamps) do
      []
    else
      first_timestamp = List.first(timestamps)
      window_size_seconds = window_minutes * 60

      timestamps
      |> Enum.group_by(fn ts ->
        # Calculate which window this timestamp falls into
        seconds_since_first = DateTime.diff(ts, first_timestamp, :second)
        window_index = div(seconds_since_first, window_size_seconds)
        DateTime.add(first_timestamp, window_index * window_size_seconds, :second)
      end)
      |> Enum.to_list()
    end
  end

  defp calculate_burst_threshold(windows) do
    if Enum.empty?(windows) do
      2
    else
      event_counts = Enum.map(windows, fn {_start, events} -> length(events) end)
      avg_events = Enum.sum(event_counts) / length(event_counts)
      max(2, round(avg_events * 1.5))
    end
  end

  defp classify_activity_frequency(activity_count, time_span_hours) do
    rate = activity_count / max(1, time_span_hours)

    cond do
      rate >= 5.0 -> :very_high
      rate >= 2.0 -> :high
      rate >= 1.0 -> :moderate
      rate >= 0.5 -> :low
      true -> :minimal
    end
  end

  defp analyze_pilot_activity_pattern(pilot_activities) do
    if Enum.empty?(pilot_activities) do
      %{pattern: :no_activity}
    else
      victim_count =
        Enum.count(pilot_activities, fn km ->
          km.victim_character_id in extract_all_participants_from_killmail(km)
        end)

      attacker_count = length(pilot_activities) - victim_count

      %{
        total_engagements: length(pilot_activities),
        as_victim: victim_count,
        as_attacker: attacker_count,
        survival_rate:
          if(length(pilot_activities) > 0,
            do: attacker_count / length(pilot_activities),
            else: 0
          ),
        activity_span_hours:
          calculate_time_span_hours(Enum.map(pilot_activities, & &1.timestamp)),
        engagement_pattern: classify_engagement_pattern(victim_count, attacker_count)
      }
    end
  end

  defp classify_engagement_pattern(victim_count, attacker_count) do
    total = victim_count + attacker_count

    if total == 0 do
      :no_pattern
    else
      victim_ratio = victim_count / total

      cond do
        victim_ratio >= 0.8 -> :frequent_victim
        victim_ratio >= 0.6 -> :victim_leaning
        victim_ratio >= 0.4 -> :balanced
        victim_ratio >= 0.2 -> :aggressor_leaning
        true -> :aggressive_hunter
      end
    end
  end

  defp find_preferred_ship(pilot_activities) do
    if Enum.empty?(pilot_activities) do
      nil
    else
      ship_usage =
        pilot_activities
        |> Enum.flat_map(&extract_ship_types_from_killmail/1)
        |> Enum.frequencies()

      if map_size(ship_usage) == 0 do
        nil
      else
        ship_usage
        |> Enum.max_by(fn {_ship_id, count} -> count end)
        |> elem(0)
      end
    end
  end

  defp estimate_active_members(corp_activities) do
    corp_activities
    |> Enum.flat_map(&extract_all_participants_from_killmail/1)
    |> Enum.uniq()
    |> length()
  end

  defp analyze_corp_ship_preferences(corp_activities) do
    ship_usage =
      corp_activities
      |> Enum.flat_map(&extract_ship_types_from_killmail/1)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_ship, count} -> -count end)
      |> Enum.take(5)

    Enum.map(ship_usage, fn {ship_type_id, count} ->
      %{
        ship_type_id: ship_type_id,
        usage_count: count,
        ship_class: classify_ship_type(ship_type_id)
      }
    end)
  end

  defp extract_corp_timeline(corp_activities) do
    corp_activities
    |> Enum.map(fn km ->
      %{
        timestamp: km.timestamp,
        system_id: km.solar_system_id,
        activity_type: classify_activity_type(km),
        participants: count_participants(km)
      }
    end)
    |> Enum.sort_by(& &1.timestamp, DateTime)
  end

  defp classify_ship_type(ship_type_id) do
    # Simplified ship classification based on type ID ranges
    cond do
      ship_type_id >= 30000 -> :capital_ship
      ship_type_id >= 20000 -> :battleship
      ship_type_id >= 15000 -> :cruiser
      ship_type_id >= 10000 -> :destroyer_frigate
      ship_type_id >= 5000 -> :industrial
      true -> :other
    end
  end

  defp calculate_average_engagement_size(ship_activities) do
    if Enum.empty?(ship_activities) do
      0
    else
      total_participants = Enum.sum(Enum.map(ship_activities, &count_participants/1))
      total_participants / length(ship_activities)
    end
  end

  defp calculate_ship_survival_rate(ship_type_id, ship_activities) do
    victim_count =
      Enum.count(ship_activities, fn km ->
        km.victim_ship_type_id == ship_type_id
      end)

    total_usage =
      Enum.count(ship_activities, fn km ->
        ship_type_id in extract_ship_types_from_killmail(km)
      end)

    if total_usage > 0 do
      Float.round((total_usage - victim_count) / total_usage, 3)
    else
      0.0
    end
  end

  defp classify_corp_engagements(participations) do
    cond do
      participations >= 50 -> :major_participant
      participations >= 20 -> :regular_participant
      participations >= 10 -> :moderate_participant
      participations >= 5 -> :occasional_participant
      true -> :minor_participant
    end
  end
end
