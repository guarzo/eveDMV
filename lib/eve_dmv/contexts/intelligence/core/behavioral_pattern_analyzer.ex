defmodule EveDmv.Contexts.Intelligence.Core.BehavioralPatternAnalyzer do
  @compile {:nowarn_unused_function}
  @moduledoc """
  Analyzes behavioral patterns including activity times, geographic preferences,
  and operational patterns.

  Consolidates functionality from:
  - Character Intelligence pattern analysis
  - Player Profile behavioral analysis
  """

  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Platform.Cache.Cache
  alias EveDmv.Platform.Database.CharacterRepository
  alias EveDmv.Platform.Database.KillmailRepository
  alias EveDmv.StaticData.SystemData

  require Logger

  @cache_ttl :timer.hours(12)

  @doc """
  Analyze behavioral patterns for a character.
  """
  @spec analyze_behavior(integer()) :: {:ok, map()} | {:error, term()}
  def analyze_behavior(character_id) do
    cache_key = {:behavioral_patterns, character_id}

    result =
      Cache.get_or_compute(
        :analysis,
        cache_key,
        fn ->
          case perform_behavioral_analysis(character_id) do
            {:ok, analysis} -> analysis
            {:error, _reason} -> :error
          end
        end,
        ttl: @cache_ttl
      )

    case result do
      :error -> {:error, :analysis_failed}
      analysis -> {:ok, analysis}
    end
  end

  @doc """
  Get activity patterns including peak times and consistency.
  """
  @spec get_activity_patterns(integer()) :: {:ok, map()} | {:error, term()}
  def get_activity_patterns(character_id) do
    case analyze_behavior(character_id) do
      {:ok, patterns} -> {:ok, patterns.activity_patterns}
      error -> error
    end
  end

  @doc """
  Get estimated timezone based on activity.
  """
  @spec get_timezone_estimate(integer()) :: {:ok, String.t()} | {:error, term()}
  def get_timezone_estimate(character_id) do
    case analyze_behavior(character_id) do
      {:ok, patterns} -> {:ok, patterns.timezone}
      error -> error
    end
  end

  @doc """
  Get gang size preferences.
  """
  @spec get_gang_preferences(integer()) :: {:ok, map()} | {:error, term()}
  def get_gang_preferences(character_id) do
    case analyze_behavior(character_id) do
      {:ok, patterns} -> {:ok, patterns.gang_preferences}
      error -> error
    end
  end

  @doc """
  Get geographic operational preferences.
  """
  @spec get_geographic_preferences(integer()) :: {:ok, map()} | {:error, term()}
  def get_geographic_preferences(character_id) do
    case analyze_behavior(character_id) do
      {:ok, patterns} -> {:ok, patterns.geographic_preferences}
      error -> error
    end
  end

  # Private Functions

  defp perform_behavioral_analysis(character_id) do
    with {:ok, killmails} <- get_character_killmails(character_id),
         {:ok, activity_data} <- get_activity_data(character_id) do
      patterns = %{
        character_id: character_id,
        activity_patterns: analyze_activity_patterns(killmails),
        timezone: estimate_timezone(killmails),
        gang_preferences: analyze_gang_preferences(killmails, character_id),
        geographic_preferences: analyze_geographic_patterns(killmails, activity_data),
        operational_patterns: analyze_operational_patterns(killmails),
        consistency_metrics: calculate_consistency_metrics(killmails),
        predictability: calculate_predictability_score(killmails),
        engagement_patterns: analyze_engagement_behavior(killmails, character_id),
        risk_tolerance: assess_risk_tolerance(killmails, character_id),
        analyzed_at: DateTime.utc_now()
      }

      {:ok, patterns}
    end
  end

  defp get_character_killmails(character_id) do
    start_date = DateTime.utc_now() |> DateTimeUtils.add(-90 * 24 * 60 * 60, :second)

    case KillmailRepository.get_by_character(character_id, start_date: start_date, limit: 1000) do
      {:ok, killmails} when is_list(killmails) -> {:ok, killmails}
    end
  end

  defp get_activity_data(character_id) do
    case CharacterRepository.get_character_stats(character_id) do
      {:ok, stats} -> {:ok, stats}
    end
  end

  defp analyze_activity_patterns(killmails) do
    # Group by hour of day
    hourly_activity =
      killmails
      |> Enum.group_by(fn km ->
        DateTime.to_time(km.killmail_time).hour
      end)
      |> Enum.map(fn {hour, kms} -> {hour, length(kms)} end)
      |> Map.new()

    # Group by day of week
    daily_activity =
      killmails
      |> Enum.group_by(fn km ->
        Date.day_of_week(DateTime.to_date(km.killmail_time))
      end)
      |> Enum.map(fn {day, kms} -> {day, length(kms)} end)
      |> Map.new()

    # Find peak hours
    peak_hours =
      hourly_activity
      |> Enum.sort_by(fn {_hour, count} -> count end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {hour, _} -> hour end)

    # Find peak days
    peak_days =
      daily_activity
      |> Enum.sort_by(fn {_day, count} -> count end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {day, _} -> day end)

    %{
      hourly_distribution: hourly_activity,
      daily_distribution: daily_activity,
      peak_hours: peak_hours,
      peak_days: peak_days,
      activity_level: classify_activity_level(length(killmails)),
      session_patterns: analyze_session_patterns(killmails)
    }
  end

  defp classify_activity_level(killmail_count) do
    cond do
      killmail_count >= 500 -> :very_high
      killmail_count >= 200 -> :high
      killmail_count >= 50 -> :moderate
      killmail_count >= 10 -> :low
      true -> :minimal
    end
  end

  defp analyze_session_patterns(killmails) do
    # Group killmails into sessions (activity within 2 hours)
    sessions =
      killmails
      |> Enum.sort_by(& &1.killmail_time)
      |> Enum.reduce([], fn km, sessions ->
        case sessions do
          [] ->
            [[km]]

          [current_session | rest] ->
            last_km = List.last(current_session)
            time_diff = DateTimeUtils.diff(km.killmail_time, last_km.killmail_time, :minute)

            # Within 2 hours
            if time_diff <= 120 do
              [[km | current_session] | rest]
            else
              [[km] | sessions]
            end
        end
      end)

    session_lengths =
      sessions
      |> Enum.map(&length/1)

    %{
      average_session_length: calculate_average(session_lengths),
      session_count: length(sessions),
      longest_session: Enum.max(session_lengths, fn -> 0 end),
      session_regularity: calculate_session_regularity(sessions)
    }
  end

  defp calculate_average(list) when is_list(list) do
    if list == [] do
      0.0
    else
      list_length = length(list)

      if list_length > 0 do
        Enum.sum(list) / list_length
      else
        0.0
      end
    end
  end

  defp calculate_average(_), do: 0

  defp calculate_session_regularity(sessions) do
    if Enum.count(sessions) < 2 do
      :insufficient_data
    else
      # Calculate time between session starts
      intervals =
        sessions
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [s1, s2] ->
          s1_first =
            case List.first(s1) do
              nil -> %{killmail_time: DateTime.utc_now()}
              km -> km
            end

          s2_first =
            case List.first(s2) do
              nil -> %{killmail_time: DateTime.utc_now()}
              km -> km
            end

          DateTimeUtils.diff(
            s2_first.killmail_time,
            s1_first.killmail_time,
            :hour
          )
        end)

      avg_interval = calculate_average(intervals)
      variance = calculate_variance(intervals, avg_interval)

      cond do
        variance < 24 -> :very_regular
        variance < 72 -> :regular
        variance < 168 -> :irregular
        true -> :sporadic
      end
    end
  end

  defp calculate_variance(values, mean) do
    if values == [] do
      0
    else
      values_length = length(values)

      if values_length > 0 do
        sum_squares =
          values
          |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
          |> Enum.sum()

        sum_squares / values_length
      else
        0
      end
    end
  end

  defp estimate_timezone(killmails) do
    if Enum.count(killmails) < 10 do
      "Unknown"
    else
      # Find the most active 4-hour window
      hourly_counts =
        killmails
        |> Enum.map(fn km -> DateTime.to_time(km.killmail_time).hour end)
        |> Enum.frequencies()

      # Calculate activity for each 4-hour window
      prime_windows =
        for start_hour <- 0..23 do
          hours = Enum.map(0..3, fn offset -> rem(start_hour + offset, 24) end)

          activity =
            hours
            |> Enum.map(fn h -> Map.get(hourly_counts, h, 0) end)
            |> Enum.sum()

          {start_hour, activity}
        end

      {peak_start, _} = Enum.max_by(prime_windows, fn {_, activity} -> activity end)

      # Estimate timezone based on peak activity
      estimate_tz_from_peak_hour(peak_start)
    end
  end

  defp estimate_tz_from_peak_hour(peak_hour) do
    # Assume peak activity is between 19:00-23:00 local time
    # 21:00 UTC as baseline
    offset = peak_hour - 21

    cond do
      offset >= -2 and offset <= 2 -> "EU-TZ"
      offset >= -7 and offset <= -4 -> "US-TZ"
      offset >= 6 and offset <= 10 -> "AU-TZ"
      true -> "Other"
    end
  end

  defp analyze_gang_preferences(killmails, character_id) do
    gang_sizes =
      killmails
      |> Enum.map(fn km ->
        if km.victim.character_id == character_id do
          # On losses, count attackers
          length(km.attackers)
        else
          # On kills, count allies
          length(km.attackers)
        end
      end)

    gang_distribution =
      gang_sizes
      |> Enum.map(fn size ->
        cond do
          size == 1 -> :solo
          size <= 5 -> :small_gang
          size <= 15 -> :medium_gang
          size <= 50 -> :large_gang
          true -> :fleet
        end
      end)
      |> Enum.frequencies()

    total = length(gang_sizes)

    avg_gang_size =
      if total > 0 do
        Enum.sum(gang_sizes) / total
      else
        1.0
      end

    %{
      average_gang_size: Float.round(avg_gang_size, 1),
      gang_distribution: gang_distribution,
      preferred_size: determine_preferred_gang_size(gang_distribution, total),
      flexibility: assess_gang_flexibility(gang_sizes)
    }
  end

  defp determine_preferred_gang_size(distribution, total) do
    if total == 0 do
      :unknown
    else
      distribution
      |> Enum.max_by(fn {_size, count} -> count end, fn -> {:unknown, 0} end)
      |> elem(0)
    end
  end

  defp assess_gang_flexibility(gang_sizes) do
    unique_sizes = gang_sizes |> Enum.uniq() |> length()

    cond do
      unique_sizes >= 10 -> :very_flexible
      unique_sizes >= 5 -> :flexible
      unique_sizes >= 3 -> :moderate
      unique_sizes >= 2 -> :limited
      true -> :fixed
    end
  end

  defp analyze_geographic_patterns(killmails, activity_data) do
    # System activity
    system_activity =
      killmails
      |> Enum.group_by(& &1.solar_system_id)
      |> Enum.map(fn {system_id, kms} ->
        {system_id, length(kms)}
      end)
      |> Enum.sort_by(fn {_, count} -> count end, :desc)

    # Region activity from activity data
    region_activity = activity_data[:regions] || %{}

    # Security preferences
    security_distribution =
      system_activity
      |> Enum.map(fn {system_id, count} ->
        sec = SystemData.get_security_status(system_id)
        sec_status = classify_security(sec)
        {sec_status, count}
      end)
      |> Enum.reduce(%{}, fn {sec, count}, acc ->
        Map.update(acc, sec, count, &(&1 + count))
      end)

    %{
      active_systems: length(system_activity),
      home_systems: identify_home_systems(system_activity),
      security_preferences: security_distribution,
      regional_focus: analyze_regional_focus(region_activity),
      roaming_range: calculate_roaming_range(system_activity)
    }
  end

  defp classify_security(sec) do
    cond do
      sec >= 0.5 -> :highsec
      sec > 0.0 -> :lowsec
      sec == 0.0 -> :nullsec
      true -> :wormhole
    end
  end

  defp identify_home_systems(system_activity) do
    total_activity =
      system_activity
      |> Enum.map(fn {_, count} -> count end)
      |> Enum.sum()

    if total_activity > 0 do
      system_activity
      |> Enum.filter(fn {_, count} ->
        # More than 10% of activity
        count / total_activity > 0.1
      end)
    else
      []
    end
    |> Enum.take(3)
    |> Enum.map(fn {system_id, _} -> system_id end)
  end

  defp analyze_regional_focus(region_activity) do
    if map_size(region_activity) == 0 do
      :unknown
    else
      region_count = map_size(region_activity)

      cond do
        region_count == 1 -> :single_region
        region_count <= 3 -> :focused
        region_count <= 7 -> :moderate
        true -> :nomadic
      end
    end
  end

  defp calculate_roaming_range(system_activity) do
    system_count = length(system_activity)

    cond do
      system_count <= 5 -> :local
      system_count <= 15 -> :regional
      system_count <= 30 -> :inter_regional
      true -> :nomadic
    end
  end

  defp analyze_operational_patterns(killmails) do
    %{
      hunt_patterns: detect_hunting_patterns(killmails),
      defensive_patterns: detect_defensive_patterns(killmails),
      tactical_preferences: analyze_tactical_preferences(killmails),
      target_selection: analyze_target_selection(killmails)
    }
  end

  defp detect_hunting_patterns(killmails) do
    # Analyze how the player hunts
    kill_locations =
      killmails
      |> Enum.filter(fn km ->
        km.victim.character_id != List.first(killmails).victim.character_id
      end)
      |> Enum.map(& &1.location)
      |> Enum.filter(& &1)

    %{
      prefers_gates:
        Enum.count(kill_locations, &String.contains?(&1, "Stargate")) >
          length(kill_locations) * 0.3,
      camps_stations:
        Enum.count(kill_locations, &String.contains?(&1, "Station")) >
          length(kill_locations) * 0.2,
      roams_systems: length(Enum.uniq(Enum.map(killmails, & &1.solar_system_id))) > 10
    }
  end

  defp detect_defensive_patterns(killmails) do
    # Analyze defensive behavior
    losses =
      Enum.filter(killmails, fn km ->
        km.victim.character_id == List.first(killmails).victim.character_id
      end)

    %{
      fights_to_death: analyze_pod_losses(losses),
      # Would need additional data
      uses_scouts: false,
      risk_averse: length(losses) < length(killmails) * 0.2
    }
  end

  defp analyze_pod_losses(losses) do
    pod_losses =
      Enum.count(losses, fn km ->
        # Check if ship is a pod/capsule
        # Capsule type ID
        km.victim.ship_type_id == 670
      end)

    pod_losses > length(losses) * 0.1
  end

  defp analyze_tactical_preferences(_killmails) do
    %{
      # Would need positioning data
      prefers_ambush: false,
      # Would need environmental data
      uses_terrain: false,
      # Would need timing analysis
      coordinated_attacks: false
    }
  end

  defp analyze_target_selection(killmails) do
    kills =
      Enum.filter(killmails, fn km ->
        km.victim.character_id != List.first(killmails).victim.character_id
      end)

    target_sizes =
      kills
      |> Enum.map(fn km -> classify_target_size(km.victim.ship_type_id) end)
      |> Enum.frequencies()

    %{
      preferred_targets: target_sizes,
      opportunistic: map_size(target_sizes) > 3,
      specialized: map_size(target_sizes) <= 2
    }
  end

  defp classify_target_size(ship_type_id) do
    # Simplified classification
    cond do
      ship_type_id < 1000 -> :small
      ship_type_id < 2000 -> :medium
      ship_type_id < 3000 -> :large
      true -> :capital
    end
  end

  defp calculate_consistency_metrics(killmails) do
    # Group by day
    daily_activity =
      killmails
      |> Enum.group_by(fn km -> DateTime.to_date(km.killmail_time) end)
      |> Map.values()
      |> Enum.map(&length/1)

    %{
      activity_variance: calculate_variance(daily_activity, calculate_average(daily_activity)),
      consistency_score: calculate_consistency_score(daily_activity),
      reliability_rating: assess_reliability(daily_activity)
    }
  end

  defp calculate_consistency_score(daily_counts) do
    if Enum.count(daily_counts) < 7 do
      0.0
    else
      # Calculate coefficient of variation
      mean = calculate_average(daily_counts)
      std_dev = :math.sqrt(calculate_variance(daily_counts, mean))

      if mean > 0 do
        1.0 - std_dev / mean
      else
        0.0
      end
    end
  end

  defp assess_reliability(daily_counts) do
    consistency = calculate_consistency_score(daily_counts)

    cond do
      consistency > 0.8 -> :very_reliable
      consistency > 0.6 -> :reliable
      consistency > 0.4 -> :moderate
      consistency > 0.2 -> :unreliable
      true -> :unpredictable
    end
  end

  defp calculate_predictability_score(killmails) do
    # Analyze patterns to determine predictability
    hourly_activity =
      killmails
      |> Enum.map(fn km -> DateTime.to_time(km.killmail_time).hour end)
      |> Enum.frequencies()
      |> Map.values()

    system_activity =
      killmails
      |> Enum.map(& &1.solar_system_id)
      |> Enum.frequencies()
      |> Map.values()

    # Higher concentration = higher predictability
    hour_concentration =
      if hourly_activity == [] do
        0
      else
        hour_sum = Enum.sum(hourly_activity)

        if hour_sum > 0 do
          Enum.max(hourly_activity) / hour_sum
        else
          0
        end
      end

    system_concentration =
      if system_activity == [] do
        0
      else
        system_sum = Enum.sum(system_activity)

        if system_sum > 0 do
          Enum.max(system_activity) / system_sum
        else
          0
        end
      end

    Float.round((hour_concentration + system_concentration) / 2, 2)
  end

  defp analyze_engagement_behavior(killmails, character_id) do
    kills = Enum.filter(killmails, fn km -> km.victim.character_id != character_id end)
    losses = Enum.filter(killmails, fn km -> km.victim.character_id == character_id end)

    %{
      aggression_level: calculate_aggression_level(kills, losses),
      target_selection: analyze_detailed_target_selection(kills),
      escape_tendency: analyze_escape_patterns(losses),
      revenge_seeking: detect_revenge_patterns(killmails)
    }
  end

  defp calculate_aggression_level(kills, losses) do
    kill_count = length(kills)
    loss_count = length(losses)

    if kill_count + loss_count == 0 do
      :unknown
    else
      aggression_ratio = kill_count / (kill_count + loss_count)

      cond do
        aggression_ratio > 0.8 -> :very_aggressive
        aggression_ratio > 0.6 -> :aggressive
        aggression_ratio > 0.4 -> :balanced
        aggression_ratio > 0.2 -> :defensive
        true -> :very_defensive
      end
    end
  end

  defp analyze_detailed_target_selection(_kills) do
    # More detailed than earlier analysis
    %{
      # Would need ship comparison
      picks_weak_targets: false,
      # Would need pilot comparison
      challenges_stronger: false,
      opportunistic: true
    }
  end

  defp analyze_escape_patterns(_losses) do
    # Would need warp-off data
    :unknown
  end

  defp detect_revenge_patterns(_killmails) do
    # Would need to track repeated engagements
    false
  end

  defp assess_risk_tolerance(killmails, character_id) do
    losses = Enum.filter(killmails, fn km -> km.victim.character_id == character_id end)

    expensive_losses =
      losses
      |> Enum.filter(fn km -> km.total_value > 100_000_000 end)
      |> length()

    killmail_count = length(killmails)

    loss_ratio =
      if killmail_count > 0 do
        length(losses) / killmail_count
      else
        0
      end

    cond do
      expensive_losses > 5 and loss_ratio < 0.3 -> :high_risk_tolerance
      expensive_losses > 0 and loss_ratio < 0.5 -> :moderate_risk_tolerance
      loss_ratio > 0.7 -> :risk_averse
      true -> :balanced_risk_profile
    end
  end
end
