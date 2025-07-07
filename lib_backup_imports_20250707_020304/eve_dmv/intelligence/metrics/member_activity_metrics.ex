defmodule EveDmv.Intelligence.Metrics.MemberActivityMetrics do
  @moduledoc """
  Calculations and metrics for member activity analysis.

  This module handles all numerical calculations, score computations,
  and metric derivations for member activity intelligence.
  """

  @doc """
  Calculate overall engagement score from activity and participation data.
  """
  def calculate_engagement_score(activity_data, participation_data) do
    # Base activity scoring (40% weight)
    activity_score = calculate_activity_score(activity_data)

    # Participation scoring (35% weight)
    participation_score = calculate_participation_score(participation_data)

    # Consistency scoring (25% weight)
    consistency_score = calculate_consistency_score(activity_data)

    # Weighted average
    (activity_score * 0.4 + participation_score * 0.35 + consistency_score * 0.25)
    |> round()
    |> max(0)
    |> min(100)
  end

  @doc """
  Calculate activity score based on PvP participation.
  """
  def calculate_activity_score(activity_data) do
    kills = activity_data[:total_kills] || 0
    losses = activity_data[:total_losses] || 0
    total_activity = kills + losses

    # Score based on total activity with diminishing returns
    # Max 80 from activity alone
    base_score = min(total_activity * 2, 80)

    # Bonus for kill/death ratio
    kd_bonus =
      if losses > 0 do
        ratio = kills / losses
        # Max 20 bonus
        min(ratio * 5, 20)
      else
        if kills > 0, do: 20, else: 0
      end

    round(base_score + kd_bonus)
  end

  @doc """
  Calculate participation score based on fleet and operation involvement.
  """
  def calculate_participation_score(participation_data) do
    home_defense = participation_data[:home_defense_count] || 0
    chain_ops = participation_data[:chain_operations_count] || 0
    fleet_ops = participation_data[:fleet_count] || 0

    # Weight different types of participation
    # Home defense is most important
    # Chain operations are valuable
    # General fleet participation
    weighted_participation =
      home_defense * 3 +
        chain_ops * 2 +
        fleet_ops

    # Convert to 0-100 score with diminishing returns
    min(weighted_participation * 3, 100)
  end

  @doc """
  Calculate consistency score based on activity patterns.
  """
  def calculate_consistency_score(activity_data) do
    activity_by_day = activity_data[:daily_activity] || %{}

    if map_size(activity_by_day) < 7 do
      # Not enough data for consistency calculation
      50
    else
      activities = Map.values(activity_by_day)
      mean_activity = Enum.sum(activities) / length(activities)

      if mean_activity == 0 do
        0
      else
        # Calculate coefficient of variation (lower is more consistent)
        variance =
          Enum.reduce(activities, 0, fn activity, acc ->
            acc + :math.pow(activity - mean_activity, 2)
          end) / length(activities)

        std_dev = :math.sqrt(variance)
        cv = std_dev / mean_activity

        # Convert to consistency score (100 - CV*100, capped)
        max(0, round(100 - cv * 100))
      end
    end
  end

  @doc """
  Calculate burnout risk score based on activity patterns and trends.
  """
  def calculate_burnout_risk(activity_data, participation_data, trend_data) do
    # High activity with declining trend indicates burnout risk
    current_activity = calculate_activity_score(activity_data)
    trend_direction = trend_data[:direction] || :stable
    trend_strength = trend_data[:strength] || 0

    base_risk =
      cond do
        current_activity > 80 and trend_direction == :declining -> 70
        current_activity > 60 and trend_direction == :declining -> 50
        current_activity > 40 and trend_direction == :declining -> 30
        true -> 10
      end

    # Increase risk based on trend strength
    trend_risk =
      if trend_direction == :declining do
        round(trend_strength * 30)
      else
        0
      end

    # Reduce risk if participation is still high (indicates engagement)
    participation_score = calculate_participation_score(participation_data)

    participation_adjustment =
      if participation_score > 60 do
        -20
      else
        0
      end

    (base_risk + trend_risk + participation_adjustment)
    |> max(0)
    |> min(100)
  end

  @doc """
  Calculate disengagement risk based on low participation patterns.
  """
  def calculate_disengagement_risk(activity_data, participation_data, timezone_data) do
    activity_score = calculate_activity_score(activity_data)
    participation_score = calculate_participation_score(participation_data)

    # Base risk from low scores
    base_risk =
      cond do
        activity_score < 20 and participation_score < 20 -> 80
        activity_score < 30 and participation_score < 30 -> 60
        activity_score < 40 or participation_score < 40 -> 40
        true -> 10
      end

    # Additional risk factors
    timezone_risk = calculate_timezone_isolation_risk(timezone_data)

    (base_risk + timezone_risk)
    |> max(0)
    |> min(100)
  end

  @doc """
  Calculate risk from timezone isolation.
  """
  def calculate_timezone_isolation_risk(timezone_data) do
    active_timezone = timezone_data[:primary_timezone]
    corp_timezone_distribution = timezone_data[:corp_distribution] || %{}

    if active_timezone && Map.has_key?(corp_timezone_distribution, active_timezone) do
      # Check what percentage of corp is in same timezone
      same_tz_percentage = corp_timezone_distribution[active_timezone] || 0

      cond do
        # Very isolated
        same_tz_percentage < 0.1 -> 30
        # Somewhat isolated
        same_tz_percentage < 0.2 -> 20
        # Slightly isolated
        same_tz_percentage < 0.3 -> 10
        # Good timezone coverage
        true -> 0
      end
    else
      # Unknown timezone - moderate risk
      15
    end
  end

  @doc """
  Determine activity trend direction and strength.
  """
  def determine_activity_trend(activity_data) do
    # Get historical activity data (simplified for now)
    daily_activities = activity_data[:daily_activity] || %{}

    if map_size(daily_activities) < 14 do
      %{direction: :unknown, strength: 0, confidence: :low}
    else
      activities =
        Enum.sort_by(daily_activities, fn {date, _} -> date end)
        |> Enum.map(fn {_, activity} -> activity end)

      trend = calculate_linear_trend(activities)

      %{
        direction: trend.direction,
        strength: abs(trend.slope),
        confidence: trend.confidence
      }
    end
  end

  @doc """
  Calculate linear trend from activity data points.
  """
  def calculate_linear_trend(data_points) when length(data_points) < 5 do
    %{direction: :unknown, slope: 0, confidence: :low}
  end

  def calculate_linear_trend(data_points) do
    n = length(data_points)
    x_values = Enum.to_list(1..n)
    y_values = data_points

    # Calculate linear regression
    x_mean = Enum.sum(x_values) / n
    y_mean = Enum.sum(y_values) / n

    zipped_xy = Enum.zip(x_values, y_values)

    numerator =
      zipped_xy
      |> Enum.reduce(0, fn {x, y}, acc ->
        acc + (x - x_mean) * (y - y_mean)
      end)

    denominator =
      Enum.reduce(x_values, 0, fn x, acc ->
        acc + :math.pow(x - x_mean, 2)
      end)

    slope = if denominator != 0, do: numerator / denominator, else: 0

    direction =
      cond do
        slope > 0.1 -> :increasing
        slope < -0.1 -> :declining
        true -> :stable
      end

    # Calculate R-squared for confidence
    y_pred =
      Enum.map(x_values, fn x ->
        y_mean + slope * (x - x_mean)
      end)

    zipped_values = Enum.zip(y_values, y_pred)

    ss_res =
      Enum.reduce(zipped_values, 0, fn {y, y_p}, acc ->
        acc + :math.pow(y - y_p, 2)
      end)

    ss_tot =
      Enum.reduce(y_values, 0, fn y, acc ->
        acc + :math.pow(y - y_mean, 2)
      end)

    r_squared = if ss_tot != 0, do: 1 - ss_res / ss_tot, else: 0

    confidence =
      cond do
        r_squared > 0.7 -> :high
        r_squared > 0.4 -> :medium
        true -> :low
      end

    %{direction: direction, slope: slope, confidence: confidence, r_squared: r_squared}
  end

  @doc """
  Calculate peer comparison percentile ranking.
  """
  def calculate_percentile_ranking(member_score, corp_scores) when is_list(corp_scores) do
    if length(corp_scores) < 2 do
      # Default to 50th percentile if insufficient data
      50
    else
      scores_below = Enum.count(corp_scores, fn score -> score < member_score end)
      total_scores = length(corp_scores)

      round(scores_below / total_scores * 100)
    end
  end

  @doc """
  Calculate how many standard deviations from corp mean.
  """
  def calculate_standard_deviation_score(member_score, corp_scores) when is_list(corp_scores) do
    if length(corp_scores) < 2 do
      0.0
    else
      mean = Enum.sum(corp_scores) / length(corp_scores)

      variance =
        Enum.reduce(corp_scores, 0, fn score, acc ->
          acc + :math.pow(score - mean, 2)
        end) / length(corp_scores)

      std_dev = :math.sqrt(variance)

      if std_dev > 0 do
        (member_score - mean) / std_dev
      else
        0.0
      end
    end
  end

  @doc """
  Calculate attention urgency score for leadership intervention.
  """
  def calculate_attention_urgency(member_analysis) do
    burnout_risk = member_analysis.burnout_risk_score || 0
    disengagement_risk = member_analysis.disengagement_risk_score || 0
    engagement_score = member_analysis.engagement_score || 50

    # Calculate base urgency from risk scores
    base_urgency = calculate_base_urgency(burnout_risk, disengagement_risk, engagement_score)

    # Apply trend adjustment
    apply_trend_adjustment(base_urgency, member_analysis.activity_trend || %{})
  end

  defp calculate_base_urgency(burnout_risk, disengagement_risk, engagement_score) do
    max_risk = max(burnout_risk, disengagement_risk)

    cond do
      max_risk > 70 -> 90
      max_risk > 50 -> 70
      engagement_score < 30 -> 60
      engagement_score < 40 -> 40
      true -> 20
    end
  end

  defp apply_trend_adjustment(urgency, trend) do
    adjustment =
      if trend[:direction] == :declining and trend[:confidence] == :high do
        10
      else
        0
      end

    min(100, urgency + adjustment)
  end

  @doc """
  Calculate contact priority for leadership outreach.
  """
  def calculate_contact_priority(member_analysis) do
    urgency = calculate_attention_urgency(member_analysis)

    # Additional factors for contact priority
    recent_activity = member_analysis.total_pvp_kills || 0

    participation =
      (member_analysis.home_defense_participations || 0) +
        (member_analysis.chain_operations_participations || 0)

    # Higher priority for recently active members showing concerning trends
    activity_multiplier =
      cond do
        # High value member
        recent_activity > 10 and participation > 5 -> 1.2
        # Moderate value
        recent_activity > 5 or participation > 3 -> 1.1
        # Standard priority
        true -> 1.0
      end

    round(urgency * activity_multiplier)
  end

  @doc """
  Build activity patterns summary.
  """
  def build_activity_patterns(activity_data) do
    %{
      peak_activity_hours: identify_peak_hours(activity_data),
      activity_consistency: calculate_consistency_score(activity_data),
      preferred_activities: identify_preferred_activities(activity_data),
      seasonal_patterns: identify_seasonal_patterns(activity_data)
    }
  end

  @doc """
  Build participation metrics summary.
  """
  def build_participation_metrics(participation_data) do
    total_events =
      (participation_data[:home_defense_count] || 0) +
        (participation_data[:chain_operations_count] || 0) +
        (participation_data[:fleet_count] || 0)

    %{
      total_events: total_events,
      home_defense_ratio: safe_ratio(participation_data[:home_defense_count], total_events),
      chain_ops_ratio: safe_ratio(participation_data[:chain_operations_count], total_events),
      fleet_ops_ratio: safe_ratio(participation_data[:fleet_count], total_events),
      solo_vs_group_ratio: safe_ratio(participation_data[:solo_count], total_events),
      participation_score: calculate_participation_score(participation_data)
    }
  end

  # Helper functions

  defp identify_peak_hours(activity_data) do
    hourly_activity = activity_data[:hourly_activity] || %{}

    Enum.sort_by(hourly_activity, fn {_, count} -> count end, :desc)
    # Top 6 hours
    |> Enum.take(6)
    |> Enum.map(fn {hour, _} -> hour end)
  end

  defp identify_preferred_activities(activity_data) do
    activities = [
      {"PvP Combat", (activity_data[:total_kills] || 0) + (activity_data[:total_losses] || 0)},
      {"Fleet Operations", activity_data[:fleet_participations] || 0},
      {"Solo Activities", activity_data[:solo_activities] || 0},
      {"Chain Operations", activity_data[:chain_operations] || 0}
    ]

    Enum.sort_by(activities, fn {_, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {activity, _} -> activity end)
  end

  defp identify_seasonal_patterns(activity_data) do
    # Simplified seasonal analysis
    monthly_activity = activity_data[:monthly_activity] || %{}

    if map_size(monthly_activity) >= 3 do
      activities = Map.values(monthly_activity)
      mean = Enum.sum(activities) / length(activities)

      %{
        has_seasonal_variation: Enum.any?(activities, fn a -> abs(a - mean) > mean * 0.3 end),
        peak_months: identify_peak_months(monthly_activity),
        low_months: identify_low_months(monthly_activity)
      }
    else
      %{has_seasonal_variation: false, peak_months: [], low_months: []}
    end
  end

  defp identify_peak_months(monthly_activity) do
    Enum.sort_by(monthly_activity, fn {_, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {month, _} -> month end)
  end

  defp identify_low_months(monthly_activity) do
    Enum.sort_by(monthly_activity, fn {_, count} -> count end)
    |> Enum.take(2)
    |> Enum.map(fn {month, _} -> month end)
  end

  defp safe_ratio(numerator, denominator) when is_nil(numerator) or is_nil(denominator), do: 0.0
  defp safe_ratio(_, 0), do: 0.0
  defp safe_ratio(numerator, denominator), do: numerator / denominator
end
