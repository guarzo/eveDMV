defmodule EveDmv.Shared.Strategic.TrendAnalyzer do
  @moduledoc """
  Analyzes strategic trends and pattern evolution over time.

  Responsible for:
  - Activity trend analysis
  - Pattern evolution tracking
  - Momentum calculations
  - Trend prediction
  """

  require Logger

  @trend_analysis_minimum_points 5

  @doc """
  Analyzes strategic trends across the operational area.
  """
  def analyze_strategic_trends(strategic_data, pattern_analysis) do
    activity_trends = analyze_activity_trends(strategic_data)
    pattern_evolution = analyze_pattern_evolution(pattern_analysis)
    momentum_analysis = calculate_strategic_momentum(activity_trends, pattern_evolution)

    %{
      activity_trends: activity_trends,
      pattern_evolution: pattern_evolution,
      momentum: momentum_analysis,
      trend_prediction: predict_future_trends(activity_trends, pattern_evolution),
      inflection_points: identify_inflection_points(activity_trends),
      trend_strength: assess_trend_strength(activity_trends, pattern_evolution)
    }
  end

  @doc """
  Analyzes activity trends over time.
  """
  def analyze_activity_trends(strategic_data) do
    time_series = build_activity_time_series(strategic_data)

    if length(time_series) < @trend_analysis_minimum_points do
      %{
        trend_direction: :insufficient_data,
        trend_strength: 0.0,
        volatility: 0.0,
        seasonality: nil,
        forecast: nil
      }
    else
      trend_analysis = calculate_trend_metrics(time_series)
      seasonality = detect_seasonality(time_series)

      %{
        trend_direction: trend_analysis.direction,
        trend_strength: trend_analysis.strength,
        volatility: trend_analysis.volatility,
        seasonality: seasonality,
        forecast: generate_activity_forecast(time_series, trend_analysis),
        time_series: time_series
      }
    end
  end

  @doc """
  Tracks pattern evolution and transitions.
  """
  def analyze_pattern_evolution(pattern_analysis) do
    patterns = pattern_analysis.identified_patterns

    evolution_tracking = track_pattern_transitions(patterns)
    pattern_lifecycle = analyze_pattern_lifecycle(patterns)
    emergence_analysis = detect_emerging_patterns(patterns)

    %{
      active_patterns: Enum.map(patterns, & &1.type),
      pattern_transitions: evolution_tracking,
      lifecycle_analysis: pattern_lifecycle,
      emerging_patterns: emergence_analysis,
      pattern_stability: calculate_pattern_stability(patterns)
    }
  end

  @doc """
  Calculates strategic momentum indicators.
  """
  def calculate_strategic_momentum(activity_trends, pattern_evolution) do
    activity_momentum = calculate_activity_momentum(activity_trends)
    pattern_momentum = calculate_pattern_momentum(pattern_evolution)

    combined_momentum = (activity_momentum + pattern_momentum) / 2

    %{
      overall_momentum: Float.round(combined_momentum, 3),
      activity_momentum: activity_momentum,
      pattern_momentum: pattern_momentum,
      momentum_direction: classify_momentum_direction(combined_momentum),
      acceleration: calculate_momentum_acceleration(activity_trends)
    }
  end

  # Private functions

  defp build_activity_time_series(strategic_data) do
    case strategic_data.scope do
      :single_system ->
        build_single_system_series(strategic_data)

      :multi_system ->
        build_multi_system_series(strategic_data)
    end
  end

  defp build_single_system_series(strategic_data) do
    strategic_data.killmails
    |> Enum.group_by(fn km -> DateTime.to_date(km.timestamp) end)
    |> Enum.map(fn {date, kills} ->
      %{
        date: date,
        activity_level: length(kills),
        unique_entities: count_unique_entities(kills),
        conflict_intensity: calculate_daily_intensity(kills)
      }
    end)
    |> Enum.sort_by(& &1.date, Date)
  end

  defp build_multi_system_series(strategic_data) do
    all_kills =
      strategic_data.killmail_data
      |> Enum.flat_map(& &1.killmails)

    all_kills
    |> Enum.group_by(fn km -> DateTime.to_date(km.timestamp) end)
    |> Enum.map(fn {date, kills} ->
      %{
        date: date,
        activity_level: length(kills),
        active_systems: count_active_systems(kills),
        unique_entities: count_unique_entities(kills),
        conflict_intensity: calculate_daily_intensity(kills)
      }
    end)
    |> Enum.sort_by(& &1.date, Date)
  end

  defp count_unique_entities(killmails) do
    entities =
      killmails
      |> Enum.flat_map(fn km ->
        [km.victim.character_id | Enum.map(km.attackers, & &1.character_id)]
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    length(entities)
  end

  defp count_active_systems(killmails) do
    killmails
    |> Enum.map(& &1.solar_system_id)
    |> Enum.uniq()
    |> length()
  end

  defp calculate_daily_intensity(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      factors = %{
        kill_count: min(1.0, length(killmails) / 50),
        unique_entities: min(1.0, count_unique_entities(killmails) / 100),
        isk_destroyed: min(1.0, calculate_isk_destroyed(killmails) / 10_000_000_000)
      }

      weighted_intensity =
        factors.kill_count * 0.3 +
          factors.unique_entities * 0.3 +
          factors.isk_destroyed * 0.4

      Float.round(weighted_intensity, 3)
    end
  end

  defp calculate_isk_destroyed(killmails) do
    killmails
    |> Enum.map(&Map.get(&1, :zkb_total_value, 0))
    |> Enum.sum()
  end

  defp calculate_trend_metrics(time_series) do
    activity_values = Enum.map(time_series, & &1.activity_level)

    # Simple linear regression for trend
    trend_slope = calculate_linear_trend(activity_values)
    volatility = calculate_volatility(activity_values)

    %{
      direction: classify_trend_direction(trend_slope),
      strength: calculate_trend_strength(trend_slope, volatility),
      volatility: volatility,
      slope: trend_slope
    }
  end

  defp calculate_linear_trend(values) do
    n = length(values)

    if n < 2 do
      0.0
    else
      x_values = Enum.to_list(0..(n - 1))

      x_mean = Enum.sum(x_values) / n
      y_mean = Enum.sum(values) / n

      numerator =
        Enum.zip(x_values, values)
        |> Enum.map(fn {x, y} -> (x - x_mean) * (y - y_mean) end)
        |> Enum.sum()

      denominator =
        x_values
        |> Enum.map(fn x -> :math.pow(x - x_mean, 2) end)
        |> Enum.sum()

      if denominator > 0 do
        Float.round(numerator / denominator, 3)
      else
        0.0
      end
    end
  end

  defp calculate_volatility(values) do
    if length(values) < 2 do
      0.0
    else
      mean = Enum.sum(values) / length(values)

      variance =
        values
        |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
        |> Enum.sum()
        |> Kernel./(length(values))

      std_dev = :math.sqrt(variance)
      cv = if mean > 0, do: std_dev / mean, else: 0

      Float.round(cv, 3)
    end
  end

  defp classify_trend_direction(slope) do
    cond do
      slope > 0.5 -> :strong_growth
      slope > 0.1 -> :growth
      slope > -0.1 -> :stable
      slope > -0.5 -> :decline
      true -> :sharp_decline
    end
  end

  defp calculate_trend_strength(slope, volatility) do
    # Strong trend = high slope, low volatility
    slope_factor = min(1.0, abs(slope) / 2)
    volatility_factor = max(0.0, 1.0 - volatility)

    Float.round(slope_factor * volatility_factor, 3)
  end

  defp detect_seasonality(time_series) do
    # Need at least 2 weeks
    if length(time_series) < 14 do
      nil
    else
      daily_patterns = analyze_daily_patterns(time_series)
      weekly_patterns = analyze_weekly_patterns(time_series)

      %{
        daily_cycle: daily_patterns,
        weekly_cycle: weekly_patterns,
        seasonality_strength: calculate_seasonality_strength(daily_patterns, weekly_patterns)
      }
    end
  end

  defp analyze_daily_patterns(time_series) do
    # Group by day of week
    by_weekday =
      time_series
      |> Enum.group_by(fn entry -> Date.day_of_week(entry.date) end)
      |> Enum.map(fn {day, entries} ->
        avg_activity =
          entries
          |> Enum.map(& &1.activity_level)
          |> average()

        {day, avg_activity}
      end)
      |> Map.new()

    if map_size(by_weekday) >= 5 do
      %{
        pattern_detected: true,
        peak_days: identify_peak_days(by_weekday),
        variation: calculate_weekday_variation(by_weekday)
      }
    else
      %{pattern_detected: false}
    end
  end

  defp analyze_weekly_patterns(time_series) do
    # Look for weekly cycles
    if length(time_series) >= 14 do
      weekly_averages =
        time_series
        |> Enum.chunk_every(7)
        |> Enum.map(fn week ->
          week
          |> Enum.map(& &1.activity_level)
          |> average()
        end)

      if length(weekly_averages) >= 2 do
        %{
          pattern_detected: true,
          weekly_trend: calculate_linear_trend(weekly_averages),
          consistency: calculate_weekly_consistency(weekly_averages)
        }
      else
        %{pattern_detected: false}
      end
    else
      %{pattern_detected: false}
    end
  end

  defp identify_peak_days(weekday_activity) do
    avg_activity =
      weekday_activity
      |> Map.values()
      |> average()

    weekday_activity
    |> Enum.filter(fn {_, activity} -> activity > avg_activity * 1.2 end)
    |> Enum.map(fn {day, _} -> day_name(day) end)
  end

  defp day_name(1), do: :monday
  defp day_name(2), do: :tuesday
  defp day_name(3), do: :wednesday
  defp day_name(4), do: :thursday
  defp day_name(5), do: :friday
  defp day_name(6), do: :saturday
  defp day_name(7), do: :sunday

  defp calculate_weekday_variation(weekday_activity) do
    values = Map.values(weekday_activity)

    if length(values) < 2 do
      0.0
    else
      max_val = Enum.max(values)
      min_val = Enum.min(values)

      if max_val > 0 do
        Float.round((max_val - min_val) / max_val, 3)
      else
        0.0
      end
    end
  end

  defp calculate_weekly_consistency(weekly_averages) do
    if length(weekly_averages) < 2 do
      0.0
    else
      cv = calculate_volatility(weekly_averages)
      Float.round(max(0.0, 1.0 - cv), 3)
    end
  end

  defp calculate_seasonality_strength(daily_patterns, weekly_patterns) do
    daily_strength =
      if daily_patterns.pattern_detected do
        daily_patterns.variation * 0.5
      else
        0.0
      end

    weekly_strength =
      if weekly_patterns.pattern_detected do
        weekly_patterns.consistency * 0.5
      else
        0.0
      end

    Float.round(daily_strength + weekly_strength, 3)
  end

  defp generate_activity_forecast(time_series, trend_analysis) do
    last_value = List.last(time_series).activity_level

    # Simple linear forecast
    forecast_days = 7
    daily_change = trend_analysis.slope

    forecasts =
      1..forecast_days
      |> Enum.map(fn day ->
        forecasted_value = last_value + daily_change * day

        %{
          days_ahead: day,
          forecasted_activity: max(0, round(forecasted_value)),
          confidence: calculate_forecast_confidence(day, trend_analysis.volatility)
        }
      end)

    %{
      forecast_period: forecast_days,
      forecasts: forecasts,
      trend_continuation_probability: calculate_trend_continuation_probability(trend_analysis)
    }
  end

  defp calculate_forecast_confidence(days_ahead, volatility) do
    # Confidence decreases with time and volatility
    time_factor = :math.pow(0.9, days_ahead)
    volatility_factor = max(0.3, 1.0 - volatility)

    Float.round(time_factor * volatility_factor, 3)
  end

  defp calculate_trend_continuation_probability(trend_analysis) do
    # Based on trend strength and volatility
    if trend_analysis.strength > 0.7 && trend_analysis.volatility < 0.3 do
      0.8
    else
      if trend_analysis.strength > 0.5 do
        0.6
      else
        0.4
      end
    end
  end

  defp track_pattern_transitions(patterns) do
    # Track how patterns relate to each other
    pattern_types = Enum.map(patterns, & &1.type)

    transitions =
      pattern_types
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [from, to] -> {from, to} end)
      |> Enum.frequencies()

    %{
      observed_transitions: transitions,
      transition_count: map_size(transitions),
      common_sequences: identify_common_sequences(transitions)
    }
  end

  defp identify_common_sequences(transitions) do
    transitions
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {{from, to}, count} ->
      %{
        sequence: [from, to],
        frequency: count,
        interpretation: interpret_pattern_sequence(from, to)
      }
    end)
  end

  defp interpret_pattern_sequence(from, to) do
    case {from, to} do
      {:reconnaissance_operation, :offensive_preparation} ->
        "Intelligence gathering leading to offensive planning"

      {:offensive_preparation, :territorial_expansion} ->
        "Prepared offensive resulting in territorial gains"

      {:harassment_campaign, :defensive_consolidation} ->
        "Harassment forcing defensive response"

      _ ->
        "Pattern transition detected"
    end
  end

  defp analyze_pattern_lifecycle(patterns) do
    patterns
    |> Enum.map(fn pattern ->
      %{
        pattern: pattern.type,
        maturity: assess_pattern_maturity(pattern),
        sustainability: assess_pattern_sustainability(pattern),
        expected_duration: estimate_pattern_duration(pattern)
      }
    end)
  end

  defp assess_pattern_maturity(pattern) do
    # Based on confidence and indicators
    confidence = pattern.confidence
    indicator_count = length(pattern.indicators)

    cond do
      confidence > 0.8 && indicator_count >= 4 -> :mature
      confidence > 0.6 && indicator_count >= 2 -> :developing
      confidence > 0.4 -> :emerging
      true -> :nascent
    end
  end

  defp assess_pattern_sustainability(pattern) do
    # Estimate how sustainable the pattern is
    case pattern.type do
      :territorial_expansion ->
        if pattern.confidence > 0.7, do: :high, else: :medium

      :defensive_consolidation ->
        :high

      :harassment_campaign ->
        :medium

      :resource_control ->
        if pattern.confidence > 0.6, do: :high, else: :medium

      _ ->
        :low
    end
  end

  defp estimate_pattern_duration(pattern) do
    # Estimate in days based on pattern type
    case pattern.type do
      :territorial_expansion -> 14
      :defensive_consolidation -> 21
      :offensive_preparation -> 7
      :harassment_campaign -> 10
      :resource_control -> 30
      _ -> 7
    end
  end

  defp detect_emerging_patterns(patterns) do
    # Look for patterns with growing strength
    emerging =
      patterns
      |> Enum.filter(fn pattern ->
        maturity = assess_pattern_maturity(pattern)
        maturity in [:nascent, :emerging]
      end)
      |> Enum.map(fn pattern ->
        %{
          pattern_type: pattern.type,
          current_strength: pattern.confidence,
          growth_potential: assess_growth_potential(pattern),
          key_indicators: Enum.take(pattern.indicators, 3)
        }
      end)

    emerging
  end

  defp assess_growth_potential(pattern) do
    indicator_strength = min(1.0, length(pattern.indicators) / 5)
    confidence_factor = pattern.confidence

    potential = (indicator_strength + confidence_factor) / 2

    cond do
      potential > 0.7 -> :high
      potential > 0.4 -> :medium
      true -> :low
    end
  end

  defp calculate_pattern_stability(patterns) do
    if Enum.empty?(patterns) do
      0.0
    else
      # Stability based on pattern confidence consistency
      confidences = Enum.map(patterns, & &1.confidence)
      avg_confidence = average(confidences)

      if avg_confidence > 0.6 do
        0.8
      else
        if avg_confidence > 0.4 do
          0.5
        else
          0.2
        end
      end
    end
  end

  defp calculate_activity_momentum(activity_trends) do
    if activity_trends.trend_direction == :insufficient_data do
      0.5
    else
      direction_factor =
        case activity_trends.trend_direction do
          :strong_growth -> 1.0
          :growth -> 0.7
          :stable -> 0.5
          :decline -> 0.3
          :sharp_decline -> 0.0
        end

      strength_factor = activity_trends.trend_strength

      Float.round((direction_factor + strength_factor) / 2, 3)
    end
  end

  defp calculate_pattern_momentum(pattern_evolution) do
    stability_factor = pattern_evolution.pattern_stability

    emerging_factor =
      case length(pattern_evolution.emerging_patterns) do
        n when n >= 3 -> 0.8
        n when n >= 1 -> 0.5
        _ -> 0.2
      end

    Float.round((stability_factor + emerging_factor) / 2, 3)
  end

  defp classify_momentum_direction(momentum) do
    cond do
      momentum > 0.7 -> :strong_positive
      momentum > 0.5 -> :positive
      momentum > 0.3 -> :neutral
      momentum > 0.1 -> :negative
      true -> :strong_negative
    end
  end

  defp calculate_momentum_acceleration(activity_trends) do
    if activity_trends.trend_direction == :insufficient_data do
      0.0
    else
      # Check if trend is accelerating
      time_series = Map.get(activity_trends, :time_series, [])

      if length(time_series) >= 10 do
        first_half = Enum.take(time_series, div(length(time_series), 2))
        second_half = Enum.drop(time_series, div(length(time_series), 2))

        first_slope = calculate_linear_trend(Enum.map(first_half, & &1.activity_level))
        second_slope = calculate_linear_trend(Enum.map(second_half, & &1.activity_level))

        Float.round(second_slope - first_slope, 3)
      else
        0.0
      end
    end
  end

  defp predict_future_trends(activity_trends, pattern_evolution) do
    momentum_direction =
      classify_momentum_direction(
        (calculate_activity_momentum(activity_trends) +
           calculate_pattern_momentum(pattern_evolution)) / 2
      )

    likely_scenarios = generate_likely_scenarios(momentum_direction, pattern_evolution)

    %{
      short_term_outlook: determine_short_term_outlook(activity_trends, momentum_direction),
      medium_term_outlook: determine_medium_term_outlook(pattern_evolution, momentum_direction),
      likely_scenarios: likely_scenarios,
      confidence_level: calculate_prediction_confidence(activity_trends, pattern_evolution)
    }
  end

  defp determine_short_term_outlook(activity_trends, momentum_direction) do
    if activity_trends.trend_direction == :insufficient_data do
      :uncertain
    else
      case momentum_direction do
        :strong_positive -> :significant_escalation
        :positive -> :continued_growth
        :neutral -> :stable_activity
        :negative -> :declining_activity
        :strong_negative -> :significant_reduction
      end
    end
  end

  defp determine_medium_term_outlook(pattern_evolution, momentum_direction) do
    emerging_count = length(pattern_evolution.emerging_patterns)

    cond do
      emerging_count >= 3 && momentum_direction in [:positive, :strong_positive] ->
        :major_strategic_shift

      emerging_count >= 1 && momentum_direction == :positive ->
        :evolving_situation

      momentum_direction == :neutral ->
        :status_quo_maintenance

      momentum_direction in [:negative, :strong_negative] ->
        :strategic_withdrawal

      true ->
        :uncertain_evolution
    end
  end

  defp generate_likely_scenarios(momentum_direction, pattern_evolution) do
    base_scenarios =
      case momentum_direction do
        :strong_positive ->
          ["Rapid territorial expansion", "Major offensive operations"]

        :positive ->
          ["Gradual expansion", "Increased activity levels"]

        :neutral ->
          ["Maintenance of current positions", "Limited skirmishes"]

        :negative ->
          ["Defensive consolidation", "Resource conservation"]

        :strong_negative ->
          ["Strategic withdrawal", "Minimal engagement"]
      end

    # Add pattern-specific scenarios
    pattern_scenarios =
      pattern_evolution.emerging_patterns
      |> Enum.map(fn emerging ->
        case emerging.pattern_type do
          :offensive_preparation -> "Launch of prepared offensive"
          :defensive_consolidation -> "Fortification of key positions"
          :resource_control -> "Intensified resource competition"
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    Enum.uniq(base_scenarios ++ pattern_scenarios) |> Enum.take(3)
  end

  defp calculate_prediction_confidence(activity_trends, pattern_evolution) do
    trend_confidence =
      if activity_trends.trend_strength > 0.7 do
        0.8
      else
        0.5
      end

    pattern_confidence = min(1.0, pattern_evolution.pattern_stability)

    Float.round((trend_confidence + pattern_confidence) / 2, 3)
  end

  defp identify_inflection_points(activity_trends) do
    if activity_trends.trend_direction == :insufficient_data do
      []
    else
      time_series = Map.get(activity_trends, :time_series, [])

      if length(time_series) >= 5 do
        time_series
        |> Enum.map(& &1.activity_level)
        |> find_local_extrema()
        |> Enum.map(fn {index, type, value} ->
          %{
            date: Enum.at(time_series, index).date,
            type: type,
            activity_level: value,
            significance: calculate_inflection_significance(index, type, time_series)
          }
        end)
        |> Enum.filter(&(&1.significance > 0.5))
      else
        []
      end
    end
  end

  defp find_local_extrema(values) do
    values
    |> Enum.with_index()
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.flat_map(fn
      [{prev, _}, {curr, idx}, {next, _}] ->
        cond do
          curr > prev && curr > next -> [{idx, :peak, curr}]
          curr < prev && curr < next -> [{idx, :trough, curr}]
          true -> []
        end
    end)
  end

  defp calculate_inflection_significance(index, type, time_series) do
    # Significance based on magnitude of change
    point_value = Enum.at(time_series, index).activity_level
    surrounding_avg = calculate_surrounding_average(index, time_series)

    if surrounding_avg > 0 do
      change_magnitude = abs(point_value - surrounding_avg) / surrounding_avg

      significance =
        case type do
          :peak -> min(1.0, change_magnitude * 1.5)
          :trough -> min(1.0, change_magnitude * 1.2)
        end

      Float.round(significance, 3)
    else
      0.0
    end
  end

  defp calculate_surrounding_average(index, time_series) do
    window_size = 2
    start_idx = max(0, index - window_size)
    end_idx = min(length(time_series) - 1, index + window_size)

    surrounding =
      start_idx..end_idx
      |> Enum.map(fn i ->
        if i != index do
          Enum.at(time_series, i).activity_level
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(surrounding) do
      0.0
    else
      average(surrounding)
    end
  end

  defp assess_trend_strength(activity_trends, pattern_evolution) do
    activity_strength = Map.get(activity_trends, :trend_strength, 0.0)

    pattern_strength = Map.get(pattern_evolution, :pattern_stability, 0.0)

    volatility = Map.get(activity_trends, :volatility, 1.0)

    momentum_consistency =
      if is_number(volatility) and volatility < 0.3 do
        0.8
      else
        0.4
      end

    overall_strength =
      activity_strength * 0.4 +
        pattern_strength * 0.4 +
        momentum_consistency * 0.2

    %{
      overall_strength: Float.round(overall_strength, 3),
      components: %{
        activity: activity_strength,
        patterns: pattern_strength,
        consistency: momentum_consistency
      },
      classification: classify_trend_strength(overall_strength)
    }
  end

  defp classify_trend_strength(strength) do
    cond do
      strength > 0.7 -> :very_strong
      strength > 0.5 -> :strong
      strength > 0.3 -> :moderate
      strength > 0.1 -> :weak
      true -> :negligible
    end
  end

  defp average(list) do
    if Enum.empty?(list) do
      0.0
    else
      Enum.sum(list) / length(list)
    end
  end
end
