defmodule EveDmv.Intelligence.Analyzers.MemberActivityPatternAnalyzer.ConsistencyCalculator do
  alias EveDmv.Intelligence.Analyzers.MemberActivityPatternAnalyzer.TimezoneAnalyzer
  @moduledoc """
  Specialized calculator for activity consistency metrics.

  This module focuses on calculating consistency patterns in member activity,
  including weekly patterns, overall consistency, and activity regularity.
  """


  @doc """
  Analyze consistency patterns in activity data.

  Calculates various consistency metrics including hourly, weekly,
  and overall consistency scores.

  ## Parameters
  - `activity_data` - Activity data containing hourly and weekly patterns

  ## Returns
  - `{:ok, consistency_metrics}` - Consistency analysis results
  """
  def analyze_consistency_patterns(activity_data) do
    # Analyze consistency in activity patterns
    hourly_activity = Map.get(activity_data, :hourly_activity, %{})
    weekly_activity = Map.get(activity_data, :weekly_activity, %{})

    consistency_metrics = %{
      hourly_consistency: TimezoneAnalyzer.calculate_timezone_consistency(hourly_activity),
      weekly_consistency: calculate_weekly_consistency(weekly_activity),
      overall_consistency: calculate_overall_consistency(activity_data)
    }

    {:ok, consistency_metrics}
  end

  @doc """
  Calculate weekly consistency based on activity distribution.

  Determines how consistent a member's activity is across different days
  of the week.

  ## Parameters
  - `weekly_activity` - Map of day_of_week -> activity count

  ## Returns
  - Float between 0.0 and 1.0 (higher = more consistent)
  """
  def calculate_weekly_consistency(weekly_activity) do
    if map_size(weekly_activity) > 0 do
      values = Map.values(weekly_activity)
      calculate_regularity(values)
    else
      0.0
    end
  end

  @doc """
  Calculate overall consistency score based on multiple factors.

  Combines timezone consistency and weekly consistency to provide
  an overall consistency score.

  ## Parameters
  - `activity_data` - Complete activity data

  ## Returns
  - Float between 0.0 and 1.0 (higher = more consistent)
  """
  def calculate_overall_consistency(activity_data) do
    # Calculate overall consistency score based on multiple factors
    timezone_consistency =
      TimezoneAnalyzer.calculate_timezone_consistency(
        Map.get(activity_data, :hourly_activity, %{})
      )

    weekly_consistency =
      calculate_weekly_consistency(Map.get(activity_data, :weekly_activity, %{}))

    (timezone_consistency + weekly_consistency) / 2
  end

  @doc """
  Calculate activity regularity from hourly and daily patterns.

  Determines how regular activity patterns are across different time scales.

  ## Parameters
  - `hourly_activity` - Map of hour -> activity count
  - `daily_activity` - Map of day -> activity count

  ## Returns
  - Float between 0.0 and 1.0 (higher = more regular)
  """
  def calculate_activity_regularity(hourly_activity, daily_activity) do
    hourly_regularity =
      if map_size(hourly_activity) > 0,
        do: calculate_regularity(Map.values(hourly_activity)),
        else: 0.0

    daily_regularity =
      if map_size(daily_activity) > 0,
        do: calculate_regularity(Map.values(daily_activity)),
        else: 0.0

    (hourly_regularity + daily_regularity) / 2
  end

  @doc """
  Calculate variance of a list of numeric values.

  ## Parameters
  - `values` - List of numeric values

  ## Returns
  - Float variance value
  """
  def calculate_variance(values) do
    if length(values) > 0 do
      mean = Enum.sum(values) / length(values)
      Enum.sum(Enum.map(values, fn x -> :math.pow(x - mean, 2) end)) / length(values)
    else
      0.0
    end
  end

  @doc """
  Calculate activity spread from a list of values.

  Determines the range of activity as a ratio of max to min values.

  ## Parameters
  - `values` - List of numeric values

  ## Returns
  - Float between 0.0 and 1.0 representing activity spread
  """
  def calculate_activity_spread(values) do
    if length(values) > 0 do
      max_val = Enum.max(values)
      min_val = Enum.min(values)
      if max_val > 0, do: (max_val - min_val) / max_val, else: 0.0
    else
      0.0
    end
  end

  @doc """
  Calculate daily consistency from activity values.

  ## Parameters
  - `values` - List of daily activity values

  ## Returns
  - Float between 0.0 and 1.0 (higher = more consistent)
  """
  def calculate_daily_consistency(values) do
    if length(values) > 1 do
      variance = calculate_variance(values)
      mean = Enum.sum(values) / length(values)
      if mean > 0, do: 1.0 - variance / (mean * mean), else: 0.0
    else
      0.0
    end
  end

  @doc """
  Calculate regularity score from activity values.

  Determines how regular (predictable) activity patterns are based on
  variance relative to the mean.

  ## Parameters
  - `values` - List of activity values

  ## Returns
  - Float between 0.0 and 1.0 (higher = more regular)
  """
  def calculate_regularity(values) do
    if length(values) > 1 do
      variance = calculate_variance(values)
      mean = Enum.sum(values) / length(values)
      if mean > 0, do: max(0.0, 1.0 - variance / (mean * mean)), else: 0.0
    else
      0.0
    end
  end
end
