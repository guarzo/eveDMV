defmodule EveDmv.Analytics.SystemActivityMetrics do
  @moduledoc """
  Service for analyzing and providing system activity metrics.

  Provides comprehensive insights into solar system activity patterns including:
  - Kill activity over time periods
  - Activity heatmaps by hour/day
  - System danger ratings
  - Alliance/corporation activity patterns
  - Ship class distribution per system
  - Activity trends and predictions
  """

  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Eve.NameResolver

  require Ash.Query

  @doc """
  Get comprehensive activity metrics for a specific system.
  """
  def get_system_metrics(system_id, timeframe \\ :last_7_days) do
    {start_time, _end_time} = get_timeframe_bounds(timeframe)

    # Get killmails for the system in the timeframe
    killmails = get_system_killmails(system_id, start_time)

    %{
      system_id: system_id,
      system_name: NameResolver.system_name(system_id),
      security_info: NameResolver.system_security(system_id),
      timeframe: timeframe,
      period_start: start_time,
      period_end: DateTime.utc_now(),

      # Basic metrics
      total_kills: Enum.count(killmails),
      total_isk_destroyed: calculate_total_isk(killmails),
      unique_characters: count_unique_characters(killmails),
      unique_corporations: count_unique_corporations(killmails),
      unique_alliances: count_unique_alliances(killmails),

      # Activity patterns
      hourly_activity: calculate_hourly_activity(killmails),
      daily_activity: calculate_daily_activity(killmails),
      activity_trends: calculate_activity_trends(killmails),

      # Ship analysis
      ship_class_distribution: analyze_ship_classes(killmails),
      most_dangerous_ships: identify_dangerous_ships(killmails),

      # Alliance/Corp activity
      top_alliances: analyze_alliance_activity(killmails),
      top_corporations: analyze_corporation_activity(killmails),

      # Danger analysis
      danger_rating: calculate_danger_rating(killmails),
      recent_escalations: detect_recent_escalations(killmails),

      # Activity quality
      activity_intensity: calculate_activity_intensity(killmails),
      pvp_quality_score: calculate_pvp_quality_score(killmails)
    }
  end

  @doc """
  Get activity metrics for multiple systems for comparison.
  """
  def get_regional_activity_metrics(system_ids, timeframe \\ :last_7_days)
      when is_list(system_ids) do
    {start_time, _end_time} = get_timeframe_bounds(timeframe)

    # Get killmails for all systems
    regional_killmails = get_regional_killmails(system_ids, start_time)

    # Calculate metrics per system
    system_metrics =
      system_ids
      |> Enum.map(fn system_id ->
        system_killmails = Enum.filter(regional_killmails, &(&1.solar_system_id == system_id))

        %{
          system_id: system_id,
          system_name: NameResolver.system_name(system_id),
          kill_count: Enum.count(system_killmails),
          isk_destroyed: calculate_total_isk(system_killmails),
          danger_rating: calculate_danger_rating(system_killmails),
          activity_score: calculate_activity_score(system_killmails),
          last_activity: get_last_activity_time(system_killmails)
        }
      end)
      |> Enum.sort_by(& &1.activity_score, :desc)

    %{
      timeframe: timeframe,
      period_start: start_time,
      period_end: DateTime.utc_now(),
      systems_analyzed: Enum.count(system_ids),
      total_kills: length(regional_killmails),
      total_isk_destroyed: calculate_total_isk(regional_killmails),
      system_metrics: system_metrics,
      regional_trends: calculate_regional_trends(regional_killmails),
      hotspots: identify_activity_hotspots(system_metrics)
    }
  end

  @doc """
  Get activity heatmap data for visualization.
  """
  def get_activity_heatmap(timeframe \\ :last_30_days, limit \\ 100) do
    {start_time, _end_time} = get_timeframe_bounds(timeframe)

    # Get top active systems
    active_systems = get_top_active_systems(start_time, limit)

    # Build heatmap data
    heatmap_data =
      active_systems
      |> Enum.map(fn system ->
        system_killmails = get_system_killmails(system.system_id, start_time)
        hourly_breakdown = calculate_hourly_activity(system_killmails)

        %{
          system_id: system.system_id,
          system_name: system.system_name,
          security_class: NameResolver.system_security(system.system_id).class,
          total_activity: system.kill_count,
          hourly_activity: hourly_breakdown,
          peak_hour: find_peak_activity_hour(hourly_breakdown),
          activity_variance: calculate_activity_variance(hourly_breakdown)
        }
      end)

    %{
      timeframe: timeframe,
      systems_count: Enum.count(heatmap_data),
      heatmap_data: heatmap_data,
      global_peak_hours: calculate_global_peak_hours(heatmap_data)
    }
  end

  @doc """
  Get activity trends over time for analytics dashboard.
  """
  def get_activity_trends(timeframe \\ :last_30_days) do
    {start_time, end_time} = get_timeframe_bounds(timeframe)

    # Get all killmails in timeframe
    killmails = get_killmails_in_timeframe(start_time, end_time)

    # Calculate daily trends
    daily_trends = calculate_daily_trends(killmails, start_time, end_time)

    # Calculate system trends
    system_trends = calculate_system_emergence_trends(killmails)

    %{
      timeframe: timeframe,
      period_start: start_time,
      period_end: end_time,
      total_kills_analyzed: Enum.count(killmails),
      daily_trends: daily_trends,
      system_trends: system_trends,
      activity_growth: calculate_activity_growth(daily_trends),
      emerging_hotspots: identify_emerging_systems(system_trends),
      declining_systems: identify_declining_systems(system_trends)
    }
  end

  # Private helper functions

  defp get_timeframe_bounds(timeframe) do
    now = DateTime.utc_now()

    case timeframe do
      :last_24_hours -> {DateTime.add(now, -24, :hour), now}
      :last_7_days -> {DateTime.add(now, -7, :day), now}
      :last_30_days -> {DateTime.add(now, -30, :day), now}
      :last_90_days -> {DateTime.add(now, -90, :day), now}
      {:custom, days} -> {DateTime.add(now, -days, :day), now}
    end
  end

  defp get_system_killmails(system_id, start_time) do
    KillmailRaw
    |> Ash.Query.new()
    |> Ash.Query.filter(solar_system_id == ^system_id)
    |> Ash.Query.filter(killmail_time >= ^start_time)
    |> Ash.Query.sort(killmail_time: :desc)
    # Reasonable limit for analysis
    |> Ash.Query.limit(1000)
    |> Ash.read!(domain: Api)
  end

  defp get_regional_killmails(system_ids, start_time) do
    KillmailRaw
    |> Ash.Query.new()
    |> Ash.Query.filter(solar_system_id in ^system_ids)
    |> Ash.Query.filter(killmail_time >= ^start_time)
    |> Ash.Query.sort(killmail_time: :desc)
    # Higher limit for regional analysis
    |> Ash.Query.limit(5000)
    |> Ash.read!(domain: Api)
  end

  defp get_killmails_in_timeframe(start_time, end_time) do
    KillmailRaw
    |> Ash.Query.new()
    |> Ash.Query.filter(killmail_time >= ^start_time and killmail_time <= ^end_time)
    |> Ash.Query.sort(killmail_time: :desc)
    # Large limit for trend analysis
    |> Ash.Query.limit(10_000)
    |> Ash.read!(domain: Api)
  end

  defp calculate_total_isk(killmails) do
    killmails
    |> Enum.map(&(&1.total_value || 0))
    |> Enum.sum()
    |> Decimal.new()
  end

  defp count_unique_characters(killmails) do
    killmails
    |> Enum.map(& &1.victim_character_id)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.count()
  end

  defp count_unique_corporations(killmails) do
    killmails
    |> Enum.map(& &1.victim_corporation_id)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.count()
  end

  defp count_unique_alliances(killmails) do
    killmails
    |> Enum.flat_map(fn killmail ->
      victim_alliance =
        if killmail.victim_alliance_id, do: [killmail.victim_alliance_id], else: []

      attacker_alliances =
        (killmail.raw_data["attackers"] || [])
        |> Enum.map(& &1["alliance_id"])
        |> Enum.reject(&is_nil/1)

      victim_alliance ++ attacker_alliances
    end)
    |> Enum.uniq()
    |> Enum.count()
  end

  defp calculate_hourly_activity(killmails) do
    killmails
    |> Enum.group_by(fn killmail ->
      killmail.killmail_time
      |> DateTime.to_time()
      |> Time.to_iso8601()
      |> String.slice(0, 2)
      |> String.to_integer()
    end)
    |> Enum.map(fn {hour, kills} ->
      %{hour: hour, kills: Enum.count(kills), isk_destroyed: calculate_total_isk(kills)}
    end)
    |> Enum.sort_by(& &1.hour)
  end

  defp calculate_daily_activity(killmails) do
    killmails
    |> Enum.group_by(fn killmail ->
      killmail.killmail_time |> DateTime.to_date() |> Date.to_iso8601()
    end)
    |> Enum.map(fn {date, kills} ->
      %{date: date, kills: Enum.count(kills), isk_destroyed: calculate_total_isk(kills)}
    end)
    |> Enum.sort_by(& &1.date)
  end

  defp calculate_activity_trends(killmails) do
    if Enum.count(killmails) < 2 do
      %{trend: :stable, change_percent: 0, confidence: :low}
    else
      daily_activity = calculate_daily_activity(killmails)

      if Enum.count(daily_activity) < 2 do
        %{trend: :stable, change_percent: 0, confidence: :low}
      else
        recent_avg = calculate_recent_average(daily_activity, 3)
        older_avg = calculate_older_average(daily_activity, 3)

        change_percent =
          if older_avg > 0 do
            (recent_avg - older_avg) / older_avg * 100
          else
            0
          end

        trend =
          cond do
            change_percent > 20 -> :increasing
            change_percent < -20 -> :decreasing
            true -> :stable
          end

        confidence = if Enum.count(daily_activity) >= 7, do: :high, else: :medium

        %{trend: trend, change_percent: Float.round(change_percent, 1), confidence: confidence}
      end
    end
  end

  defp analyze_ship_classes(killmails) do
    killmails
    |> Enum.map(&classify_ship_by_type_id(&1.victim_ship_type_id))
    |> Enum.frequencies()
    |> Enum.map(fn {ship_class, count} ->
      %{ship_class: ship_class, kill_count: count}
    end)
    |> Enum.sort_by(& &1.kill_count, :desc)
  end

  defp classify_ship_by_type_id(ship_type_id) when is_integer(ship_type_id) do
    # Simplified ship classification - in production, use static data
    cond do
      ship_type_id in 582..600 -> :frigate
      ship_type_id in 620..640 -> :cruiser
      ship_type_id in 638..658 -> :battleship
      ship_type_id > 20_000 -> :capital
      true -> :other
    end
  end

  defp classify_ship_by_type_id(_), do: :unknown

  defp identify_dangerous_ships(killmails) do
    killmails
    |> Enum.group_by(& &1.victim_ship_type_id)
    |> Enum.map(fn {ship_type_id, kills} ->
      total_value = calculate_total_isk(kills)

      avg_value =
        if not Enum.empty?(kills),
          do: Decimal.div(total_value, Enum.count(kills)),
          else: Decimal.new(0)

      %{
        ship_type_id: ship_type_id,
        ship_name: get_ship_name(ship_type_id),
        kill_count: Enum.count(kills),
        total_value_destroyed: total_value,
        avg_value: avg_value,
        danger_score: calculate_ship_danger_score(Enum.count(kills), total_value)
      }
    end)
    |> Enum.sort_by(& &1.danger_score, :desc)
    |> Enum.take(10)
  end

  defp analyze_alliance_activity(killmails) do
    killmails
    |> Enum.group_by(& &1.victim_alliance_id)
    |> Enum.reject(fn {alliance_id, _} -> is_nil(alliance_id) end)
    |> Enum.map(fn {alliance_id, kills} ->
      %{
        alliance_id: alliance_id,
        alliance_name: get_alliance_name_from_kills(kills),
        kill_count: Enum.count(kills),
        isk_lost: calculate_total_isk(kills),
        activity_score: calculate_alliance_activity_score(kills)
      }
    end)
    |> Enum.sort_by(& &1.activity_score, :desc)
    |> Enum.take(10)
  end

  defp analyze_corporation_activity(killmails) do
    killmails
    |> Enum.group_by(& &1.victim_corporation_id)
    |> Enum.reject(fn {corp_id, _} -> is_nil(corp_id) end)
    |> Enum.map(fn {corp_id, kills} ->
      %{
        corporation_id: corp_id,
        corporation_name: get_corporation_name_from_kills(kills),
        kill_count: Enum.count(kills),
        isk_lost: calculate_total_isk(kills),
        activity_score: calculate_corporation_activity_score(kills)
      }
    end)
    |> Enum.sort_by(& &1.activity_score, :desc)
    |> Enum.take(10)
  end

  defp calculate_danger_rating(killmails) do
    if Enum.empty?(killmails) do
      %{rating: :safe, score: 0, factors: []}
    else
      # kills per day
      kill_frequency = Enum.count(killmails) / 7.0

      avg_ship_value =
        calculate_total_isk(killmails) |> Decimal.to_float() |> Kernel./(Enum.count(killmails))

      capital_kills = Enum.count(killmails, &is_capital_ship?(&1.victim_ship_type_id))

      # Calculate danger score (0-100)
      # max 40 points
      frequency_score = min(kill_frequency * 10, 40)
      # max 30 points
      value_score = min(avg_ship_value / 100_000_000 * 20, 30)
      # max 30 points
      capital_score = min(capital_kills * 5, 30)

      total_score = frequency_score + value_score + capital_score

      rating =
        cond do
          total_score >= 80 -> :extreme
          total_score >= 60 -> :high
          total_score >= 40 -> :moderate
          total_score >= 20 -> :low
          true -> :safe
        end

      factors = []
      factors = if kill_frequency > 2, do: ["high_kill_frequency" | factors], else: factors
      factors = if avg_ship_value > 500_000_000, do: ["expensive_ships" | factors], else: factors
      factors = if capital_kills > 0, do: ["capital_activity" | factors], else: factors

      %{rating: rating, score: Float.round(total_score, 1), factors: factors}
    end
  end

  defp detect_recent_escalations(killmails) do
    # Look for sudden spikes in activity or ship value in last 24 hours
    recent_cutoff = DateTime.add(DateTime.utc_now(), -24, :hour)

    recent_kills =
      Enum.filter(killmails, &(DateTime.compare(&1.killmail_time, recent_cutoff) != :lt))

    older_kills =
      Enum.filter(killmails, &(DateTime.compare(&1.killmail_time, recent_cutoff) == :lt))

    if Enum.empty?(older_kills) do
      []
    else
      # per day
      recent_rate = Enum.count(recent_kills) / 1.0
      # per day (6 days of older data)
      older_rate = Enum.count(older_kills) / 6.0

      escalations = []

      # Check for kill frequency escalation
      if recent_rate > older_rate * 2 do
        escalations = [
          %{type: :kill_frequency, severity: :high, description: "Kill rate doubled in last 24h"}
          | escalations
        ]
      end

      # Check for capital escalation
      recent_capitals = Enum.count(recent_kills, &is_capital_ship?(&1.victim_ship_type_id))

      if recent_capitals > 0 and not Enum.empty?(recent_kills) do
        escalations = [
          %{type: :capital_activity, severity: :high, description: "Capital ships engaged"}
          | escalations
        ]
      end

      escalations
    end
  end

  defp calculate_activity_intensity(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      # Calculate intensity based on kills per hour and value
      duration_hours =
        if Enum.count(killmails) > 1 do
          first_kill = Enum.min_by(killmails, & &1.killmail_time)
          last_kill = Enum.max_by(killmails, & &1.killmail_time)
          DateTime.diff(last_kill.killmail_time, first_kill.killmail_time, :hour)
        else
          1
        end

      kills_per_hour = Enum.count(killmails) / max(duration_hours, 1)

      avg_value =
        calculate_total_isk(killmails) |> Decimal.to_float() |> Kernel./(Enum.count(killmails))

      # Normalize to 0-10 scale
      intensity = kills_per_hour * 2 + avg_value / 100_000_000
      min(intensity, 10.0) |> Float.round(2)
    end
  end

  defp calculate_pvp_quality_score(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      # Factors that indicate quality PvP
      avg_attackers =
        killmails
        |> Enum.map(& &1.attacker_count)
        |> Enum.sum()
        |> Kernel./(Enum.count(killmails))

      ship_variety = Enum.count(Enum.uniq_by(killmails, & &1.victim_ship_type_id))

      # Score components
      # More attackers = better fights
      attacker_score = min(avg_attackers / 5.0, 1.0) * 40
      # Ship variety
      variety_score = min(ship_variety / 10.0, 1.0) * 30
      # Activity level
      activity_score = min(Enum.count(killmails) / 20.0, 1.0) * 30

      total_score = attacker_score + variety_score + activity_score
      Float.round(total_score, 1)
    end
  end

  # Additional helper functions
  defp get_ship_name(ship_type_id) do
    # In production, use NameResolver or static data
    "Ship #{ship_type_id}"
  end

  defp get_alliance_name_from_kills(kills) do
    kills
    |> Enum.map(&get_alliance_name_from_raw_data(&1.raw_data))
    |> Enum.reject(&is_nil/1)
    |> List.first()
    |> Kernel.||("Unknown Alliance")
  end

  defp get_alliance_name_from_raw_data(raw_data) do
    case raw_data["victim"] do
      %{"alliance_name" => name} when is_binary(name) -> name
      _ -> nil
    end
  end

  defp get_corporation_name_from_kills(kills) do
    kills
    |> Enum.map(&get_corporation_name_from_raw_data(&1.raw_data))
    |> Enum.reject(&is_nil/1)
    |> List.first()
    |> Kernel.||("Unknown Corporation")
  end

  defp get_corporation_name_from_raw_data(raw_data) do
    case raw_data["victim"] do
      %{"corporation_name" => name} when is_binary(name) -> name
      _ -> nil
    end
  end

  defp is_capital_ship?(ship_type_id) when is_integer(ship_type_id) do
    # Simplified check
    ship_type_id > 20_000
  end

  defp is_capital_ship?(_), do: false

  defp calculate_ship_danger_score(kill_count, total_value) do
    value_float = Decimal.to_float(total_value)
    kill_count * 10 + value_float / 1_000_000_000
  end

  defp calculate_alliance_activity_score(kills) do
    Enum.count(kills) * 10 + Decimal.to_float(calculate_total_isk(kills)) / 1_000_000_000
  end

  defp calculate_corporation_activity_score(kills) do
    Enum.count(kills) * 8 + Decimal.to_float(calculate_total_isk(kills)) / 1_000_000_000
  end

  defp calculate_recent_average(daily_activity, days) do
    daily_activity
    |> Enum.take(-days)
    |> Enum.map(& &1.kills)
    |> case do
      [] -> 0
      kills -> Enum.sum(kills) / Enum.count(kills)
    end
  end

  defp calculate_older_average(daily_activity, days) do
    daily_activity
    |> Enum.drop(-days)
    |> Enum.take(-days)
    |> Enum.map(& &1.kills)
    |> case do
      [] -> 0
      kills -> Enum.sum(kills) / Enum.count(kills)
    end
  end

  # Stub implementations for complex analysis functions
  defp get_top_active_systems(_start_time, _limit), do: []
  defp find_peak_activity_hour(_hourly_breakdown), do: 12
  defp calculate_activity_variance(_hourly_breakdown), do: 0.5
  defp calculate_global_peak_hours(_heatmap_data), do: [12, 18, 20]
  defp calculate_daily_trends(_killmails, _start_time, _end_time), do: []
  defp calculate_system_emergence_trends(_killmails), do: []
  defp calculate_activity_growth(_daily_trends), do: %{growth_rate: 0.0, trend: :stable}
  defp identify_emerging_systems(_system_trends), do: []
  defp identify_declining_systems(_system_trends), do: []
  defp calculate_activity_score(_killmails), do: 0.0

  defp get_last_activity_time(killmails) do
    case killmails do
      [] -> nil
      _ -> Enum.max_by(killmails, & &1.killmail_time).killmail_time
    end
  end

  defp calculate_regional_trends(_killmails), do: %{}

  defp identify_activity_hotspots(system_metrics) do
    system_metrics
    |> Enum.filter(&(&1.activity_score > 50))
    |> Enum.take(5)
  end
end
