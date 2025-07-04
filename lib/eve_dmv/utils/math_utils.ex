defmodule EveDmv.Utils.MathUtils do
  @moduledoc """
  Shared mathematical utility functions for intelligence analysis.

  Provides centralized implementations of common mathematical operations
  used across intelligence modules including ratios, statistics, scoring,
  and normalization functions.
  """

  @doc """
  Safely divide two numbers, returning default value if division by zero.

  ## Examples

      iex> MathUtils.safe_division(10, 2)
      5.0
      
      iex> MathUtils.safe_division(10, 0)
      0.0
      
      iex> MathUtils.safe_division(10, 0, :infinity)
      :infinity
  """
  @spec safe_division(number(), number(), any()) :: float() | any()
  def safe_division(numerator, denominator, default \\ 0.0)
  def safe_division(_numerator, 0, default), do: default
  def safe_division(_numerator, denominator, default) when denominator == 0.0, do: default
  def safe_division(numerator, denominator, _default), do: numerator / denominator

  @doc """
  Calculate kill/death ratio with special handling for edge cases.

  ## Examples

      iex> MathUtils.calculate_kill_death_ratio(10, 2)
      5.0
      
      iex> MathUtils.calculate_kill_death_ratio(10, 0)
      10.0
      
      iex> MathUtils.calculate_kill_death_ratio(0, 5)
      0.0
  """
  @spec calculate_kill_death_ratio(number(), number()) :: float()
  def calculate_kill_death_ratio(kills, deaths) when deaths == 0 and kills > 0, do: kills * 1.0
  def calculate_kill_death_ratio(kills, deaths) when deaths == 0 and kills == 0, do: 1.0
  def calculate_kill_death_ratio(kills, deaths), do: safe_division(kills, deaths, 0.0)

  @doc """
  Calculate percentage ratio with bounds checking.

  ## Examples

      iex> MathUtils.calculate_percentage_ratio(25, 100)
      25.0
      
      iex> MathUtils.calculate_percentage_ratio(10, 0)
      0.0
  """
  @spec calculate_percentage_ratio(number(), number()) :: float()
  def calculate_percentage_ratio(part, whole) do
    safe_division(part * 100, whole, 0.0)
  end

  @doc """
  Calculate the arithmetic mean of a list of numbers.

  ## Examples

      iex> MathUtils.calculate_mean([1, 2, 3, 4, 5])
      3.0
      
      iex> MathUtils.calculate_mean([])
      0.0
  """
  @spec calculate_mean([number()]) :: float()
  def calculate_mean([]), do: 0.0

  def calculate_mean(values) when is_list(values) do
    safe_division(Enum.sum(values), length(values), 0.0)
  end

  @doc """
  Calculate weighted average of values.

  ## Examples

      iex> MathUtils.calculate_weighted_average([10, 20, 30], [1, 2, 3])
      23.33
  """
  @spec calculate_weighted_average([number()], [number()]) :: float()
  def calculate_weighted_average(values, weights) when length(values) == length(weights) do
    weighted_sum =
      values
      |> Enum.zip(weights)
      |> Enum.map(fn {value, weight} -> value * weight end)
      |> Enum.sum()

    total_weight = Enum.sum(weights)
    safe_division(weighted_sum, total_weight, 0.0)
  end

  def calculate_weighted_average(values, _weights), do: calculate_mean(values)

  @doc """
  Calculate variance of a dataset.

  ## Examples

      iex> MathUtils.calculate_variance([1, 2, 3, 4, 5])
      2.0
  """
  @spec calculate_variance([number()], float() | nil) :: float()
  def calculate_variance(values, mean \\ nil)
  def calculate_variance([], _mean), do: 0.0

  def calculate_variance(values, mean) when is_list(values) do
    mean_val = mean || calculate_mean(values)

    sum_squared_diffs =
      values
      |> Enum.map(fn x -> :math.pow(x - mean_val, 2) end)
      |> Enum.sum()

    safe_division(sum_squared_diffs, length(values), 0.0)
  end

  @doc """
  Calculate standard deviation of a dataset.

  ## Examples

      iex> MathUtils.calculate_standard_deviation([1, 2, 3, 4, 5])
      1.41
  """
  @spec calculate_standard_deviation([number()], float() | nil) :: float()
  def calculate_standard_deviation(values, mean \\ nil) do
    values
    |> calculate_variance(mean)
    |> :math.sqrt()
  end

  @doc """
  Calculate coefficient of variation (standard deviation / mean).

  Useful for measuring relative variability.
  """
  @spec calculate_coefficient_of_variation([number()]) :: float()
  def calculate_coefficient_of_variation([]), do: 0.0

  def calculate_coefficient_of_variation(values) do
    mean_val = calculate_mean(values)
    std_dev = calculate_standard_deviation(values, mean_val)
    safe_division(std_dev, mean_val, 0.0)
  end

  @doc """
  Calculate percentile ranking of a value within a dataset.

  ## Examples

      iex> MathUtils.calculate_percentile_ranking(75, [50, 60, 70, 80, 90])
      60.0
  """
  @spec calculate_percentile_ranking(number(), [number()]) :: float()
  def calculate_percentile_ranking(_value, []), do: 0.0

  def calculate_percentile_ranking(value, dataset) do
    count_below = Enum.count(dataset, fn x -> x < value end)
    safe_division(count_below * 100, length(dataset), 0.0)
  end

  @doc """
  Calculate weighted score from components and their weights.

  ## Examples

      iex> MathUtils.calculate_weighted_score([80, 90, 70], [0.5, 0.3, 0.2])
      81.0
  """
  @spec calculate_weighted_score([number()], [number()]) :: float()
  def calculate_weighted_score(components, weights) when length(components) == length(weights) do
    calculate_weighted_average(components, weights)
  end

  def calculate_weighted_score(components, _weights), do: calculate_mean(components)

  @doc """
  Normalize a score to a target range.

  ## Examples

      iex> MathUtils.normalize_score(75, {0, 100}, {0, 10})
      7.5
  """
  @spec normalize_score(number(), {number(), number()}, {number(), number()}) :: float()
  def normalize_score(value, {input_min, input_max}, {output_min, output_max}) do
    input_range = input_max - input_min
    output_range = output_max - output_min

    if input_range == 0 do
      output_min
    else
      normalized = (value - input_min) / input_range
      output_min + normalized * output_range
    end
  end

  @doc """
  Clamp a score to specified bounds.

  ## Examples

      iex> MathUtils.clamp_score(150, 0, 100)
      100
      
      iex> MathUtils.clamp_score(-10, 0, 100)
      0
  """
  @spec clamp_score(number(), number(), number()) :: number()
  def clamp_score(score, min_val \\ 0, max_val \\ 100) do
    score
    |> max(min_val)
    |> min(max_val)
  end

  @doc """
  Apply diminishing returns to a value above a threshold.

  ## Examples

      iex> MathUtils.apply_diminishing_returns(150, 100, 0.5)
      125.0
  """
  @spec apply_diminishing_returns(number(), number(), number()) :: float()
  def apply_diminishing_returns(value, threshold, _factor) when value <= threshold do
    value * 1.0
  end

  def apply_diminishing_returns(value, threshold, factor) do
    excess = value - threshold
    threshold + excess * factor
  end

  @doc """
  Calculate confidence from variance (inverse relationship).

  Lower variance = higher confidence.
  """
  @spec calculate_confidence_from_variance([number()]) :: float()
  def calculate_confidence_from_variance([]), do: 0.0

  def calculate_confidence_from_variance(values) do
    variance = calculate_variance(values)
    # Use inverse relationship: confidence = 1 / (1 + variance)
    1 / (1 + variance) * 100
  end

  @doc """
  Calculate data completeness score as percentage.

  ## Examples

      iex> MathUtils.calculate_data_completeness_score(8, 10)
      80.0
  """
  @spec calculate_data_completeness_score(integer(), integer()) :: float()
  def calculate_data_completeness_score(available, total) do
    calculate_percentage_ratio(available, total)
  end

  @doc """
  Invert a risk score to create a safety/quality score.

  ## Examples

      iex> MathUtils.invert_risk_score(20)
      80.0
  """
  @spec invert_risk_score(number(), number()) :: float()
  def invert_risk_score(risk_score, max_score \\ 100) do
    max_score - risk_score
  end

  @doc """
  Calculate activity frequency (activities per time period).

  ## Examples

      iex> MathUtils.calculate_activity_frequency(30, 7)
      4.29
  """
  @spec calculate_activity_frequency(number(), number()) :: float()
  def calculate_activity_frequency(activity_count, time_period_days) do
    safe_division(activity_count, time_period_days, 0.0)
  end

  @doc """
  Calculate temporal consistency using coefficient of variation.

  Lower values indicate more consistent activity patterns.
  """
  @spec calculate_temporal_consistency([number()]) :: float()
  def calculate_temporal_consistency(time_series_data) do
    # Consistency is inverse of coefficient of variation
    cv = calculate_coefficient_of_variation(time_series_data)
    # Convert to 0-100 scale where 100 = perfectly consistent
    max(0, 100 - cv * 100)
  end

  @doc """
  Calculate linear regression coefficients for trend analysis.

  Returns {slope, intercept, r_squared}.

  ## Examples

      iex> MathUtils.calculate_linear_regression([{1, 2}, {2, 4}, {3, 6}])
      {2.0, 0.0, 1.0}
  """
  @spec calculate_linear_regression([{number(), number()}]) :: {float(), float(), float()}
  def calculate_linear_regression([]), do: {0.0, 0.0, 0.0}

  def calculate_linear_regression(data_points) when length(data_points) < 2 do
    {0.0, 0.0, 0.0}
  end

  def calculate_linear_regression(data_points) do
    n = length(data_points)

    {x_values, y_values} = Enum.unzip(data_points)

    sum_x = Enum.sum(x_values)
    sum_y = Enum.sum(y_values)
    sum_x_squared = Enum.sum(Enum.map(x_values, fn x -> x * x end))

    sum_xy =
      data_points
      |> Enum.map(fn {x, y} -> x * y end)
      |> Enum.sum()

    # Calculate slope (m) and intercept (b) for y = mx + b
    denominator = n * sum_x_squared - sum_x * sum_x

    if denominator == 0 do
      {0.0, calculate_mean(y_values), 0.0}
    else
      slope = (n * sum_xy - sum_x * sum_y) / denominator
      intercept = (sum_y - slope * sum_x) / n

      # Calculate R-squared
      mean_y = calculate_mean(y_values)
      ss_tot = Enum.sum(Enum.map(y_values, fn y -> :math.pow(y - mean_y, 2) end))

      predicted_values = Enum.map(x_values, fn x -> slope * x + intercept end)

      ss_res =
        y_values
        |> Enum.zip(predicted_values)
        |> Enum.map(fn {actual, predicted} -> :math.pow(actual - predicted, 2) end)
        |> Enum.sum()

      r_squared = if ss_tot == 0, do: 1.0, else: 1 - ss_res / ss_tot

      {slope, intercept, max(0.0, r_squared)}
    end
  end

  @doc """
  Calculate trend direction and strength from regression results.

  Returns {direction, strength} where:
  - direction: :increasing, :decreasing, or :stable
  - strength: :weak, :moderate, or :strong
  """
  @spec calculate_trend_direction_and_strength({float(), float(), float()}) ::
          {atom(), atom()}
  def calculate_trend_direction_and_strength({slope, _intercept, r_squared}) do
    direction =
      cond do
        abs(slope) < 0.01 -> :stable
        slope > 0 -> :increasing
        true -> :decreasing
      end

    strength =
      cond do
        r_squared < 0.3 -> :weak
        r_squared < 0.7 -> :moderate
        true -> :strong
      end

    {direction, strength}
  end

  @doc """
  Calculate moving average over a specified window.

  ## Examples

      iex> MathUtils.calculate_moving_average([1, 2, 3, 4, 5], 3)
      [2.0, 3.0, 4.0]
  """
  @spec calculate_moving_average([number()], integer()) :: [float()]
  def calculate_moving_average(values, window_size) when window_size > length(values) do
    [calculate_mean(values)]
  end

  def calculate_moving_average(values, window_size) do
    values
    |> Enum.chunk_every(window_size, 1, :discard)
    |> Enum.map(&calculate_mean/1)
  end

  @doc """
  Categorize a score based on threshold mappings.

  ## Examples

      iex> thresholds = %{low: 30, medium: 70, high: 100}
      iex> MathUtils.categorize_by_thresholds(85, thresholds)
      :high
  """
  @spec categorize_by_thresholds(number(), map()) :: atom()
  def categorize_by_thresholds(score, thresholds) do
    thresholds
    |> Enum.sort_by(fn {_category, threshold} -> threshold end)
    |> Enum.find(fn {_category, threshold} -> score <= threshold end)
    |> case do
      {category, _threshold} -> category
      nil -> :maximum
    end
  end
end
