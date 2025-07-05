defmodule EveDmv.Intelligence.Analyzers.StatisticalAnalyzer do
  @moduledoc """
  Statistical analysis module for intelligence data.

  Provides statistical correlation analysis, anomaly detection,
  and mathematical operations for intelligence processing.
  """

  @doc """
  Calculate correlation confidence score based on data quality and patterns.
  """
  @spec calculate_correlation_confidence(map()) :: float()
  def calculate_correlation_confidence(correlations) when is_map(correlations) do
    # Base confidence starts at 50%
    base_confidence = 50.0

    # Add confidence based on available correlation types
    type_bonus = map_size(correlations) * 5.0

    # Adjust based on correlation quality
    quality_bonus = assess_correlation_quality(correlations)

    # Cap at 95% maximum confidence
    min(95.0, base_confidence + type_bonus + quality_bonus)
  end

  @doc """
  Detect statistical anomalies in character progression data.
  """
  @spec detect_progression_anomalies(map(), map()) :: list()
  def detect_progression_anomalies(character_analysis, fleet_data) do
    []
    |> maybe_add_skill_mismatch_anomaly(character_analysis, fleet_data)
    |> maybe_add_rapid_progression_anomaly(character_analysis)
    |> maybe_add_regression_anomaly(character_analysis, fleet_data)
  end

  @doc """
  Calculate statistical correlation between different data sets.
  """
  @spec calculate_correlation_coefficient(list(number()), list(number())) :: float()
  def calculate_correlation_coefficient(x_values, y_values)
      when is_list(x_values) and is_list(y_values) and length(x_values) == length(y_values) do
    if length(x_values) < 2 do
      0.0
    else
      n = length(x_values)

      sum_x = Enum.sum(x_values)
      sum_y = Enum.sum(y_values)
      sum_xy = Enum.zip(x_values, y_values) |> Enum.map(fn {x, y} -> x * y end) |> Enum.sum()
      sum_x2 = Enum.map(x_values, &(&1 * &1)) |> Enum.sum()
      sum_y2 = Enum.map(y_values, &(&1 * &1)) |> Enum.sum()

      numerator = n * sum_xy - sum_x * sum_y
      denominator = :math.sqrt((n * sum_x2 - sum_x * sum_x) * (n * sum_y2 - sum_y * sum_y))

      if denominator == 0, do: 0.0, else: numerator / denominator
    end
  end

  @doc """
  Calculate variance for a list of numerical values.
  """
  @spec calculate_variance(list(number())) :: float()
  def calculate_variance([]), do: 0.0
  def calculate_variance([_single]), do: 0.0

  def calculate_variance(values) when is_list(values) do
    mean = Enum.sum(values) / length(values)
    sum_squared_diff = Enum.sum(Enum.map(values, &:math.pow(&1 - mean, 2)))
    sum_squared_diff / (length(values) - 1)
  end

  @doc """
  Calculate standard deviation for a list of numerical values.
  """
  @spec calculate_standard_deviation(list(number())) :: float()
  def calculate_standard_deviation(values) when is_list(values) do
    :math.sqrt(calculate_variance(values))
  end

  @doc """
  Detect outliers using the IQR method.
  """
  @spec detect_outliers(list(number())) :: {list(number()), list(number())}
  def detect_outliers([]), do: {[], []}

  def detect_outliers(values) when is_list(values) do
    sorted = Enum.sort(values)
    n = length(sorted)

    q1_index = round(n * 0.25)
    q3_index = round(n * 0.75)

    q1 = Enum.at(sorted, max(0, q1_index - 1))
    q3 = Enum.at(sorted, min(n - 1, q3_index - 1))

    iqr = q3 - q1
    lower_bound = q1 - 1.5 * iqr
    upper_bound = q3 + 1.5 * iqr

    outliers = Enum.filter(values, &(&1 < lower_bound or &1 > upper_bound))
    normal_values = Enum.filter(values, &(&1 >= lower_bound and &1 <= upper_bound))

    {normal_values, outliers}
  end

  @doc """
  Normalize values to a 0-100 scale.
  """
  @spec normalize_to_scale(list(number()), number()) :: list(float())
  def normalize_to_scale(values, scale \\ 100)
  def normalize_to_scale([], _scale), do: []

  def normalize_to_scale(values, scale) when is_list(values) do
    {min_val, max_val} = Enum.min_max(values)
    range = max_val - min_val

    if range == 0 do
      Enum.map(values, fn _ -> scale / 2 end)
    else
      Enum.map(values, &((&1 - min_val) / range * scale))
    end
  end

  # Private helper functions

  defp assess_correlation_quality(correlations) do
    # Simple quality assessment based on correlation completeness
    # Expected correlation types
    total_possible = 6
    actual_count = map_size(correlations)

    actual_count / total_possible * 20.0
  end

  defp maybe_add_skill_mismatch_anomaly(anomalies, character_analysis, fleet_data) do
    # Check for skill/ship usage mismatches
    case {character_analysis, fleet_data} do
      {%{skill_level: skill}, %{ship_complexity: complexity}}
      when is_number(skill) and is_number(complexity) ->
        if abs(skill - complexity) > 30 do
          [
            %{
              type: :skill_mismatch,
              severity: :medium,
              description: "Character skill level doesn't match ship complexity",
              confidence: 0.75
            }
            | anomalies
          ]
        else
          anomalies
        end

      _ ->
        anomalies
    end
  end

  defp maybe_add_rapid_progression_anomaly(anomalies, character_analysis) do
    # Check for unusually rapid skill progression
    case character_analysis do
      %{skill_progression_rate: rate} when is_number(rate) and rate > 85 ->
        [
          %{
            type: :rapid_progression,
            severity: :low,
            description: "Character shows unusually rapid skill progression",
            confidence: 0.6
          }
          | anomalies
        ]

      _ ->
        anomalies
    end
  end

  defp maybe_add_regression_anomaly(anomalies, character_analysis, fleet_data) do
    # Check for performance regression patterns
    case {character_analysis, fleet_data} do
      {%{recent_performance: recent}, %{historical_performance: historical}}
      when is_number(recent) and is_number(historical) ->
        if recent < historical * 0.6 do
          [
            %{
              type: :performance_regression,
              severity: :medium,
              description: "Character shows significant performance decline",
              confidence: 0.7
            }
            | anomalies
          ]
        else
          anomalies
        end

      _ ->
        anomalies
    end
  end
end
