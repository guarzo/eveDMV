defmodule EveDmv.Intelligence.Calculators.TrendCalculator do
  @moduledoc """
  Trend calculation module for activity data analysis.

  Provides statistical analysis capabilities for determining trend direction,
  volatility detection, and activity pattern recognition using mathematical
  variance and standard deviation calculations.
  """

  @doc """
  Calculate trend direction from activity data.

  Analyzes a list of activity data points to determine if the trend is:
  - :stable - consistent activity levels
  - :volatile - high variance relative to mean
  - :increasing - upward trend over time
  - :decreasing - downward trend over time
  """
  def calculate_trend_direction(activity_data) when is_list(activity_data) do
    if length(activity_data) < 2 do
      :stable
    else
      # Calculate variance to determine volatility first
      mean = Enum.sum(activity_data) / length(activity_data)

      variance =
        Enum.sum(Enum.map(activity_data, fn x -> :math.pow(x - mean, 2) end)) /
          length(activity_data)

      std_deviation = :math.sqrt(variance)

      # Check for volatility first - high variance relative to mean
      if std_deviation > mean * 0.6 and mean > 0 do
        :volatile
      else
        # Calculate overall trend (first vs last half)
        mid_point = div(length(activity_data), 2)
        first_half = Enum.take(activity_data, mid_point)
        second_half = Enum.drop(activity_data, mid_point)

        first_avg =
          if length(first_half) > 0, do: Enum.sum(first_half) / length(first_half), else: 0

        second_avg =
          if length(second_half) > 0, do: Enum.sum(second_half) / length(second_half), else: 0

        change_percent = if first_avg > 0, do: (second_avg - first_avg) / first_avg * 100, else: 0

        cond do
          change_percent > 10 -> :increasing
          change_percent < -10 -> :decreasing
          true -> :stable
        end
      end
    end
  end

  @doc """
  Calculate statistical variance of activity data.
  """
  def calculate_variance(data) when is_list(data) do
    if length(data) < 2 do
      0.0
    else
      mean = Enum.sum(data) / length(data)
      Enum.sum(Enum.map(data, fn x -> :math.pow(x - mean, 2) end)) / length(data)
    end
  end

  @doc """
  Calculate standard deviation of activity data.
  """
  def calculate_standard_deviation(data) when is_list(data) do
    :math.sqrt(calculate_variance(data))
  end

  @doc """
  Determine if data shows high volatility relative to mean.
  """
  def volatile?(data, threshold \\ 0.6) when is_list(data) do
    if length(data) < 2 do
      false
    else
      mean = Enum.sum(data) / length(data)
      std_dev = calculate_standard_deviation(data)
      std_dev > mean * threshold and mean > 0
    end
  end
end
