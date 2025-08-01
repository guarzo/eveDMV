defmodule EveDmv.Contexts.Intelligence.Core.HistoricalTrendAnalysis do
  @moduledoc """
  Implements historical trend analysis for character behavior patterns.
  
  Tracks and analyzes trends in:
  - Kill/death ratios over time
  - ISK efficiency trends
  - Ship usage patterns
  - Activity levels by timezone
  - Threat score evolution
  """
  
  alias EveDmv.Database.KillmailRepository
  alias EveDmv.Intelligence.Cache.IntelligenceCache
  
  require Logger
  
  @cache_ttl :timer.hours(12)
  @trend_window_days 90
  
  @doc """
  Analyze threat trends for a character based on historical data.
  """
  def analyze_threat_trends(character_id, current_score) do
    cache_key = {:threat_trends, character_id}
    
    IntelligenceCache.get_or_compute(cache_key, fn ->
      perform_trend_analysis(character_id, current_score)
    end, ttl: @cache_ttl)
  end
  
  @doc """
  Get comprehensive historical analysis for a character.
  """
  def get_historical_analysis(character_id, opts \\ []) do
    days_back = Keyword.get(opts, :days, @trend_window_days)
    
    with {:ok, history} <- get_character_history(character_id, days_back) do
      analysis = %{
        kill_death_trend: analyze_kd_trend(history),
        isk_efficiency_trend: analyze_isk_trend(history),
        ship_usage_trend: analyze_ship_usage_trend(history),
        activity_pattern_trend: analyze_activity_trend(history),
        threat_evolution: analyze_threat_evolution(history, character_id),
        performance_metrics: calculate_performance_trends(history),
        analyzed_at: DateTime.utc_now()
      }
      
      {:ok, analysis}
    end
  end
  
  # Private implementation
  
  defp perform_trend_analysis(character_id, current_score) do
    case get_character_history(character_id, @trend_window_days) do
      {:ok, history} ->
        trends = %{
          kill_death_trend: analyze_kd_trend(history),
          isk_efficiency_trend: analyze_isk_trend(history),
          ship_usage_trend: analyze_ship_usage_trend(history),
          activity_pattern_trend: analyze_activity_trend(history),
          threat_score_trend: analyze_threat_score_trend(history, current_score)
        }
        
        %{
          trends: trends,
          direction: determine_overall_direction(trends),
          change_rate: calculate_change_rate(trends),
          projection: project_future_score(current_score, trends),
          momentum: calculate_momentum(trends),
          confidence: calculate_trend_confidence(history)
        }
        
      {:error, _} ->
        # Return default if no history available
        %{
          trends: %{},
          direction: :stable,
          change_rate: 0,
          projection: current_score,
          momentum: :neutral,
          confidence: :low
        }
    end
  end
  
  defp get_character_history(character_id, days_back) do
    start_date = DateTime.add(DateTime.utc_now(), -days_back * 24 * 3600, :second)
    
    KillmailRepository.get_by_character(character_id, start_date)
  end
  
  defp analyze_kd_trend(history) do
    # Group killmails by week
    weekly_stats = history
    |> Enum.group_by(&week_key(&1.killmail_time))
    |> Enum.map(fn {week, killmails} ->
      kills = Enum.count(killmails, fn km -> 
        km.victim_character_id != km.character_id 
      end)
      deaths = Enum.count(killmails, fn km -> 
        km.victim_character_id == km.character_id 
      end)
      
      ratio = if deaths > 0, do: kills / deaths, else: kills
      
      {week, %{kills: kills, deaths: deaths, ratio: ratio}}
    end)
    |> Enum.sort_by(&elem(&1, 0))
    
    if length(weekly_stats) < 2 do
      %{
        current: 0.0,
        direction: :insufficient_data,
        velocity: 0.0,
        volatility: 0.0,
        trend_line: []
      }
    else
      ratios = Enum.map(weekly_stats, fn {_, stats} -> stats.ratio end)
      current = List.last(ratios) || 0.0
      
      %{
        current: Float.round(current, 2),
        direction: calculate_direction(ratios),
        velocity: calculate_velocity(ratios),
        volatility: calculate_volatility(ratios),
        trend_line: build_trend_line(weekly_stats),
        weekly_breakdown: weekly_stats
      }
    end
  end
  
  defp analyze_isk_trend(history) do
    weekly_isk = history
    |> Enum.group_by(&week_key(&1.killmail_time))
    |> Enum.map(fn {week, killmails} ->
      destroyed = killmails
        |> Enum.filter(fn km -> km.victim_character_id != km.character_id end)
        |> Enum.map(&(&1.total_value || 0))
        |> Enum.sum()
      
      lost = killmails
        |> Enum.filter(fn km -> km.victim_character_id == km.character_id end)
        |> Enum.map(&(&1.total_value || 0))
        |> Enum.sum()
      
      efficiency = if lost > 0, do: destroyed / (destroyed + lost), else: 1.0
      
      {week, %{destroyed: destroyed, lost: lost, efficiency: efficiency}}
    end)
    |> Enum.sort_by(&elem(&1, 0))
    
    if length(weekly_isk) < 2 do
      %{
        current: 1.0,
        direction: :insufficient_data,
        velocity: 0.0,
        total_destroyed: 0,
        total_lost: 0
      }
    else
      efficiencies = Enum.map(weekly_isk, fn {_, stats} -> stats.efficiency end)
      current = List.last(efficiencies) || 1.0
      
      total_destroyed = weekly_isk |> Enum.map(fn {_, s} -> s.destroyed end) |> Enum.sum()
      total_lost = weekly_isk |> Enum.map(fn {_, s} -> s.lost end) |> Enum.sum()
      
      %{
        current: Float.round(current, 3),
        direction: calculate_direction(efficiencies),
        velocity: calculate_velocity(efficiencies),
        improvement_rate: calculate_improvement_rate(efficiencies),
        total_destroyed: total_destroyed,
        total_lost: total_lost,
        weekly_breakdown: weekly_isk
      }
    end
  end
  
  defp analyze_ship_usage_trend(history) do
    # Group by ship type and time period
    ship_usage = history
    |> Enum.group_by(&{week_key(&1.killmail_time), &1.victim_ship_type_id})
    |> Enum.map(fn {{week, ship_type}, killmails} ->
      {week, ship_type, length(killmails)}
    end)
    
    # Find most used ships
    ship_frequencies = history
    |> Enum.frequencies_by(&(&1.victim_ship_type_id))
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(10)
    
    # Analyze progression (e.g., frigate -> cruiser -> battleship)
    ship_progression = analyze_ship_progression(history)
    
    %{
      top_ships: ship_frequencies,
      progression: ship_progression,
      diversity_score: calculate_ship_diversity(ship_frequencies),
      specialization: detect_ship_specialization(ship_frequencies),
      recent_changes: detect_recent_ship_changes(ship_usage)
    }
  end
  
  defp analyze_activity_trend(history) do
    # Group by day and hour
    hourly_activity = history
    |> Enum.group_by(fn km ->
      DateTime.to_time(km.killmail_time).hour
    end)
    |> Enum.map(fn {hour, killmails} ->
      {hour, length(killmails)}
    end)
    |> Map.new()
    
    # Group by day of week
    daily_activity = history
    |> Enum.group_by(fn km ->
      Date.day_of_week(DateTime.to_date(km.killmail_time))
    end)
    |> Enum.map(fn {day, killmails} ->
      {day, length(killmails)}
    end)
    |> Map.new()
    
    # Activity over time
    weekly_activity = history
    |> Enum.group_by(&week_key(&1.killmail_time))
    |> Enum.map(fn {week, killmails} ->
      {week, length(killmails)}
    end)
    |> Enum.sort_by(&elem(&1, 0))
    
    %{
      peak_hours: find_peak_hours(hourly_activity),
      peak_days: find_peak_days(daily_activity),
      timezone_estimate: estimate_timezone(hourly_activity),
      consistency: calculate_activity_consistency(weekly_activity),
      activity_level: categorize_activity_level(history),
      weekly_trend: weekly_activity
    }
  end
  
  defp analyze_threat_score_trend(history, current_score) do
    # Simulate historical threat scores based on killmail patterns
    weekly_scores = history
    |> Enum.group_by(&week_key(&1.killmail_time))
    |> Enum.map(fn {week, killmails} ->
      # Calculate weekly threat indicators
      kill_count = Enum.count(killmails, fn km -> 
        km.victim_character_id != km.character_id 
      end)
      
      solo_kills = Enum.count(killmails, fn km ->
        km.victim_character_id != km.character_id and 
        length(km.attackers || []) == 1
      end)
      
      capital_kills = Enum.count(killmails, fn km ->
        km.victim_character_id != km.character_id and
        (km.victim_ship_type_id || 0) >= 20000
      end)
      
      # Simple threat score calculation
      week_score = kill_count * 10 + solo_kills * 20 + capital_kills * 50
      
      {week, Float.round(week_score / 10.0, 1)}
    end)
    |> Enum.sort_by(&elem(&1, 0))
    
    scores = Enum.map(weekly_scores, &elem(&1, 1))
    
    %{
      current: current_score,
      historical_scores: weekly_scores,
      direction: calculate_direction(scores ++ [current_score]),
      momentum: calculate_score_momentum(scores, current_score),
      volatility: calculate_volatility(scores),
      percentile_rank: calculate_percentile_rank(current_score)
    }
  end
  
  # Helper functions
  
  defp week_key(datetime) do
    {year, week} = :calendar.iso_week_number({
      DateTime.to_date(datetime).year,
      DateTime.to_date(datetime).month,
      DateTime.to_date(datetime).day
    })
    "#{year}-W#{String.pad_leading(to_string(week), 2, "0")}"
  end
  
  defp calculate_direction(values) when length(values) < 2, do: :insufficient_data
  defp calculate_direction(values) do
    # Compare recent average to older average
    midpoint = div(length(values), 2)
    older = Enum.take(values, midpoint)
    recent = Enum.drop(values, midpoint)
    
    older_avg = average(older)
    recent_avg = average(recent)
    
    cond do
      recent_avg > older_avg * 1.2 -> :strongly_improving
      recent_avg > older_avg * 1.05 -> :improving
      recent_avg < older_avg * 0.8 -> :strongly_declining
      recent_avg < older_avg * 0.95 -> :declining
      true -> :stable
    end
  end
  
  defp calculate_velocity(values) when length(values) < 2, do: 0.0
  defp calculate_velocity(values) do
    # Rate of change
    diffs = values
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] -> b - a end)
    
    if length(diffs) > 0 do
      Float.round(Enum.sum(diffs) / length(diffs), 3)
    else
      0.0
    end
  end
  
  defp calculate_volatility(values) when length(values) < 2, do: 0.0
  defp calculate_volatility(values) do
    mean = average(values)
    variance = values
    |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
    |> average()
    
    Float.round(:math.sqrt(variance), 3)
  end
  
  defp calculate_improvement_rate(values) when length(values) < 2, do: 0.0
  defp calculate_improvement_rate(values) do
    first = List.first(values)
    last = List.last(values)
    
    if first > 0 do
      Float.round((last - first) / first * 100, 1)
    else
      0.0
    end
  end
  
  defp build_trend_line(weekly_stats) do
    weekly_stats
    |> Enum.map(fn {week, stats} ->
      %{
        week: week,
        value: stats.ratio,
        kills: stats.kills,
        deaths: stats.deaths
      }
    end)
  end
  
  defp analyze_ship_progression(history) do
    # Sort by time and look for progression patterns
    ship_timeline = history
    |> Enum.sort_by(&(&1.killmail_time))
    |> Enum.map(&(&1.victim_ship_type_id))
    |> Enum.chunk_every(10, 10, :discard)
    |> Enum.map(fn chunk ->
      # Classify predominant ship class in each period
      chunk
      |> Enum.map(&classify_ship_class/1)
      |> Enum.frequencies()
      |> Enum.max_by(&elem(&1, 1), fn -> {:unknown, 0} end)
      |> elem(0)
    end)
    
    # Detect progression
    cond do
      ship_timeline == Enum.sort(ship_timeline) -> :ascending_progression
      ship_timeline == Enum.sort(ship_timeline, :desc) -> :descending_progression
      length(Enum.uniq(ship_timeline)) == 1 -> :specialized
      true -> :varied
    end
  end
  
  defp classify_ship_class(ship_type_id) when is_integer(ship_type_id) do
    cond do
      ship_type_id < 1000 -> :frigate
      ship_type_id < 2000 -> :destroyer
      ship_type_id < 5000 -> :cruiser
      ship_type_id < 10000 -> :battlecruiser
      ship_type_id < 20000 -> :battleship
      true -> :capital
    end
  end
  defp classify_ship_class(_), do: :unknown
  
  defp calculate_ship_diversity(ship_frequencies) do
    total_uses = ship_frequencies |> Enum.map(&elem(&1, 1)) |> Enum.sum()
    
    if total_uses > 0 do
      # Shannon entropy for diversity
      entropy = ship_frequencies
      |> Enum.map(fn {_, count} ->
        p = count / total_uses
        -p * :math.log2(p)
      end)
      |> Enum.sum()
      
      Float.round(entropy, 2)
    else
      0.0
    end
  end
  
  defp detect_ship_specialization(ship_frequencies) do
    if Enum.empty?(ship_frequencies) do
      :none
    else
      {_top_ship, top_count} = List.first(ship_frequencies)
      total = ship_frequencies |> Enum.map(&elem(&1, 1)) |> Enum.sum()
      
      specialization_ratio = top_count / total
      
      cond do
        specialization_ratio > 0.7 -> :highly_specialized
        specialization_ratio > 0.5 -> :specialized
        specialization_ratio > 0.3 -> :moderate_variety
        true -> :high_variety
      end
    end
  end
  
  defp detect_recent_ship_changes(ship_usage) do
    # Look for changes in last 2 weeks vs previous period
    recent_cutoff = week_key(DateTime.add(DateTime.utc_now(), -14 * 24 * 3600, :second))
    
    {recent, older} = ship_usage
    |> Enum.split_with(fn {week, _, _} -> week >= recent_cutoff end)
    
    recent_ships = recent |> Enum.map(fn {_, ship, _} -> ship end) |> Enum.uniq()
    older_ships = older |> Enum.map(fn {_, ship, _} -> ship end) |> Enum.uniq()
    
    new_ships = recent_ships -- older_ships
    abandoned_ships = older_ships -- recent_ships
    
    %{
      new_ships: new_ships,
      abandoned_ships: abandoned_ships,
      change_detected: length(new_ships) > 0 or length(abandoned_ships) > 0
    }
  end
  
  defp find_peak_hours(hourly_activity) do
    hourly_activity
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(3)
    |> Enum.map(&elem(&1, 0))
  end
  
  defp find_peak_days(daily_activity) do
    day_names = %{
      1 => :monday,
      2 => :tuesday,
      3 => :wednesday,
      4 => :thursday,
      5 => :friday,
      6 => :saturday,
      7 => :sunday
    }
    
    daily_activity
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(3)
    |> Enum.map(fn {day_num, _} -> Map.get(day_names, day_num, :unknown) end)
  end
  
  defp estimate_timezone(hourly_activity) do
    # Find the most active 4-hour window
    peak_window = 0..23
    |> Enum.map(fn start_hour ->
      activity = 0..3
      |> Enum.map(fn offset ->
        hour = rem(start_hour + offset, 24)
        Map.get(hourly_activity, hour, 0)
      end)
      |> Enum.sum()
      
      {start_hour, activity}
    end)
    |> Enum.max_by(&elem(&1, 1))
    |> elem(0)
    
    # Estimate timezone based on peak activity
    cond do
      peak_window >= 0 and peak_window <= 3 -> "AU TZ"
      peak_window >= 4 and peak_window <= 11 -> "EU TZ"
      peak_window >= 12 and peak_window <= 19 -> "US TZ"
      true -> "Mixed TZ"
    end
  end
  
  defp calculate_activity_consistency(weekly_activity) do
    if length(weekly_activity) < 4 do
      :insufficient_data
    else
      activity_values = Enum.map(weekly_activity, &elem(&1, 1))
      avg = average(activity_values)
      
      if avg > 0 do
        variance_ratio = calculate_volatility(activity_values) / avg
        
        cond do
          variance_ratio < 0.2 -> :very_consistent
          variance_ratio < 0.5 -> :consistent
          variance_ratio < 1.0 -> :variable
          true -> :erratic
        end
      else
        :inactive
      end
    end
  end
  
  defp categorize_activity_level(history) do
    kills_per_day = length(history) / @trend_window_days
    
    cond do
      kills_per_day >= 10 -> :hyperactive
      kills_per_day >= 5 -> :very_active
      kills_per_day >= 2 -> :active
      kills_per_day >= 0.5 -> :moderate
      kills_per_day >= 0.1 -> :low
      true -> :minimal
    end
  end
  
  defp calculate_performance_trends(history) do
    # Additional performance metrics
    %{
      solo_ratio: calculate_solo_ratio(history),
      gang_effectiveness: calculate_gang_effectiveness(history),
      target_selection: analyze_target_selection(history),
      engagement_success: calculate_engagement_success(history)
    }
  end
  
  defp calculate_solo_ratio(history) do
    kills = Enum.filter(history, fn km -> km.victim_character_id != km.character_id end)
    
    if Enum.empty?(kills) do
      0.0
    else
      solo_kills = Enum.count(kills, fn km ->
        length(km.attackers || []) == 1
      end)
      
      Float.round(solo_kills / length(kills), 3)
    end
  end
  
  defp calculate_gang_effectiveness(history) do
    gang_kills = history
    |> Enum.filter(fn km ->
      km.victim_character_id != km.character_id and
      length(km.attackers || []) > 1
    end)
    
    if Enum.empty?(gang_kills) do
      %{participation_rate: 0.0, average_gang_size: 0}
    else
      avg_size = gang_kills
      |> Enum.map(fn km -> length(km.attackers || []) end)
      |> average()
      
      %{
        participation_rate: Float.round(length(gang_kills) / length(history), 3),
        average_gang_size: Float.round(avg_size, 1)
      }
    end
  end
  
  defp analyze_target_selection(history) do
    victims = history
    |> Enum.filter(fn km -> km.victim_character_id != km.character_id end)
    |> Enum.map(fn km -> km.victim_ship_type_id end)
    |> Enum.reject(&is_nil/1)
    
    if Enum.empty?(victims) do
      %{preference: :none}
    else
      ship_classes = victims
      |> Enum.map(&classify_ship_class/1)
      |> Enum.frequencies()
      
      {preferred_class, _} = Enum.max_by(ship_classes, &elem(&1, 1), fn -> {:unknown, 0} end)
      
      %{
        preference: preferred_class,
        distribution: ship_classes
      }
    end
  end
  
  defp calculate_engagement_success(history) do
    # Simple success metric based on K/D in engagements
    engagements = history
    |> Enum.group_by(&(&1.killmail_hash))
    
    success_rate = engagements
    |> Enum.map(fn {_hash, kills} ->
      deaths = Enum.count(kills, fn km -> km.victim_character_id == km.character_id end)
      if deaths > 0, do: 0, else: 1
    end)
    |> average()
    
    Float.round(success_rate, 3)
  end
  
  defp determine_overall_direction(trends) do
    directions = [
      trends.kill_death_trend[:direction],
      trends.isk_efficiency_trend[:direction],
      trends.threat_score_trend[:direction]
    ]
    |> Enum.reject(&(&1 == :insufficient_data))
    
    if Enum.empty?(directions) do
      :insufficient_data
    else
      # Weight different trends
      direction_scores = %{
        strongly_improving: 2,
        improving: 1,
        stable: 0,
        declining: -1,
        strongly_declining: -2
      }
      
      avg_score = directions
      |> Enum.map(&Map.get(direction_scores, &1, 0))
      |> average()
      
      cond do
        avg_score >= 1.5 -> :strongly_improving
        avg_score >= 0.5 -> :improving
        avg_score <= -1.5 -> :strongly_declining
        avg_score <= -0.5 -> :declining
        true -> :stable
      end
    end
  end
  
  defp calculate_change_rate(trends) do
    # Average rate of change across metrics
    rates = [
      trends.kill_death_trend[:velocity] || 0,
      trends.isk_efficiency_trend[:velocity] || 0,
      trends.threat_score_trend[:velocity] || 0
    ]
    
    Float.round(average(rates), 3)
  end
  
  defp project_future_score(current_score, trends) do
    # Simple linear projection based on recent trends
    momentum_factor = case trends.threat_score_trend[:momentum] do
      :accelerating -> 1.2
      :steady -> 1.0
      :decelerating -> 0.8
      _ -> 1.0
    end
    
    change_rate = trends.threat_score_trend[:velocity] || 0
    
    projected = current_score + (change_rate * 4 * momentum_factor)  # 4 weeks projection
    
    # Clamp to reasonable range
    max(0, min(100, Float.round(projected, 1)))
  end
  
  defp calculate_momentum(trends) do
    # Determine if trends are accelerating or decelerating
    velocities = [
      trends.kill_death_trend[:velocity] || 0,
      trends.isk_efficiency_trend[:velocity] || 0
    ]
    |> Enum.reject(&(&1 == 0))
    
    if Enum.empty?(velocities) do
      :neutral
    else
      avg_velocity = average(velocities)
      
      cond do
        avg_velocity > 0.5 -> :positive_momentum
        avg_velocity < -0.5 -> :negative_momentum
        true -> :neutral
      end
    end
  end
  
  defp calculate_trend_confidence(history) do
    # Confidence based on data quantity and consistency
    data_points = length(history)
    
    cond do
      data_points >= 100 -> :high
      data_points >= 50 -> :medium
      data_points >= 20 -> :low
      true -> :insufficient_data
    end
  end
  
  defp calculate_score_momentum(historical_scores, current_score) do
    if length(historical_scores) < 3 do
      :insufficient_data
    else
      recent_scores = historical_scores
      |> Enum.take(-3)
      |> Enum.map(&elem(&1, 1))
      
      all_scores = recent_scores ++ [current_score]
      
      # Check if consistently increasing or decreasing
      diffs = all_scores
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a, b] -> b - a end)
      
      cond do
        Enum.all?(diffs, &(&1 > 0)) -> :accelerating
        Enum.all?(diffs, &(&1 < 0)) -> :decelerating
        true -> :fluctuating
      end
    end
  end
  
  defp calculate_percentile_rank(score) do
    # Estimate percentile rank based on score distribution
    # In production, would query actual distribution
    cond do
      score >= 90 -> 99
      score >= 80 -> 95
      score >= 70 -> 90
      score >= 60 -> 80
      score >= 50 -> 70
      score >= 40 -> 50
      score >= 30 -> 30
      score >= 20 -> 20
      true -> 10
    end
  end
  
  defp analyze_threat_evolution(history, character_id) do
    # Analyze how character's threat level has evolved over time
    threat_scores = history
    |> Enum.chunk_every(10)
    |> Enum.with_index()
    |> Enum.map(fn {chunk, idx} ->
      # Calculate threat score for this time period
      score = calculate_threat_score_for_period(chunk, character_id)
      {idx, score}
    end)
    
    %{
      threat_progression: threat_scores,
      current_threat_level: classify_threat_level(List.last(threat_scores)),
      trend_direction: determine_threat_trend_direction(threat_scores),
      evolution_pattern: identify_evolution_pattern(threat_scores)
    }
  end

  defp calculate_threat_score_for_period(killmails, _character_id) do
    # Simple threat scoring based on activity in the period
    kill_count = length(killmails)
    total_value = killmails
    |> Enum.map(&(&1.total_value || 0))
    |> Enum.sum()
    
    # Base score on activity and value
    base_score = min(50, kill_count * 2)
    value_score = min(30, total_value / 100_000_000)  # 100M ISK = 1 point
    
    Float.round(base_score + value_score, 1)
  end

  defp classify_threat_level({_period, score}) when is_number(score) do
    cond do
      score >= 80 -> :extreme
      score >= 60 -> :high
      score >= 40 -> :moderate
      score >= 20 -> :low
      true -> :minimal
    end
  end
  defp classify_threat_level(_), do: :unknown

  defp determine_threat_trend_direction(threat_scores) when length(threat_scores) >= 3 do
    scores = Enum.map(threat_scores, &elem(&1, 1))
    first_third = scores |> Enum.take(div(length(scores), 3)) |> average()
    last_third = scores |> Enum.drop(-div(length(scores), 3)) |> average()
    
    cond do
      last_third > first_third * 1.2 -> :escalating
      last_third < first_third * 0.8 -> :declining
      true -> :stable
    end
  end
  defp determine_threat_trend_direction(_), do: :insufficient_data

  defp identify_evolution_pattern(threat_scores) when length(threat_scores) >= 5 do
    scores = Enum.map(threat_scores, &elem(&1, 1))
    
    # Check for patterns
    cond do
      is_steadily_increasing?(scores) -> :steady_escalation
      is_steadily_decreasing?(scores) -> :gradual_decline
      has_spike_pattern?(scores) -> :periodic_activity
      true -> :irregular
    end
  end
  defp identify_evolution_pattern(_), do: :insufficient_data

  defp is_steadily_increasing?(scores) do
    scores
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] -> b >= a end)
    |> Enum.count(&(&1))
    |> Kernel./(length(scores) - 1)
    |> Kernel.>=(0.7)
  end

  defp is_steadily_decreasing?(scores) do
    scores
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] -> b <= a end)
    |> Enum.count(&(&1))
    |> Kernel./(length(scores) - 1)
    |> Kernel.>=(0.7)
  end

  defp has_spike_pattern?(scores) do
    # Check for alternating high/low pattern
    variance = calculate_volatility(scores)
    mean = average(scores)
    
    variance > mean * 0.5  # High variance indicates spiky pattern
  end

  defp average([]), do: 0.0
  defp average(list) do
    Enum.sum(list) / length(list)
  end
end