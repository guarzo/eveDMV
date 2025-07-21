defmodule EveDmv.Shared.MetricsCalculator do
  @moduledoc """
  Shared metrics calculation utilities for domain analyzers.

  Eliminates code duplication across corporation, player, and threat analyzers
  by providing common metrics calculation functions.
  """

  @doc """
  Calculate current metrics including average analysis time.

  Takes a state with :metrics and :recent_analysis_times fields and updates
  the average_analysis_time_ms metric based on recent analysis times.

  ## Parameters
  - state: Map containing :metrics and :recent_analysis_times keys

  ## Returns
  Updated metrics map with calculated average_analysis_time_ms

  ## Examples
      iex> state = %{
      ...>   metrics: %{average_analysis_time_ms: 0},
      ...>   recent_analysis_times: [100, 200, 150]
      ...> }
      iex> EveDmv.Shared.MetricsCalculator.calculate_current_metrics(state)
      %{average_analysis_time_ms: 150.0}
  """
  def calculate_current_metrics(state) do
    avg_time =
      if length(state.recent_analysis_times) > 0 do
        Enum.sum(state.recent_analysis_times) / length(state.recent_analysis_times)
      else
        0.0
      end

    %{state.metrics | average_analysis_time_ms: Float.round(avg_time, 2)}
  end

  @doc """
  Calculate average from a list of numeric values.

  ## Parameters
  - values: List of numeric values

  ## Returns
  Float average rounded to 2 decimal places, or 0 if list is empty

  ## Examples
      iex> EveDmv.Shared.MetricsCalculator.calculate_average([10, 20, 30])
      20.0

      iex> EveDmv.Shared.MetricsCalculator.calculate_average([])
      0.0
  """
  def calculate_average(values) when is_list(values) do
    if length(values) > 0 do
      Float.round(Enum.sum(values) / length(values), 2)
    else
      0.0
    end
  end

  @doc """
  Update metrics with calculated averages for common analyzer patterns.

  ## Parameters
  - metrics: Current metrics map
  - recent_times: List of recent timing values
  - field_name: Atom representing the field to update (defaults to :average_analysis_time_ms)

  ## Returns
  Updated metrics map
  """
  def update_metrics_with_average(metrics, recent_times, field_name \\ :average_analysis_time_ms) do
    avg_time = calculate_average(recent_times)
    Map.put(metrics, field_name, avg_time)
  end

  @doc """
  Calculate analyzer metrics from state data.

  ## Parameters
  - state: Map containing metrics data

  ## Returns
  Map with calculated analyzer metrics including rates and timestamp

  ## Examples
      iex> state = %{metrics: %{total_analyses: 100, cache_hits: 80, cache_misses: 20}}
      iex> EveDmv.Shared.MetricsCalculator.calculate_analyzer_metrics(state)
      %{total: 100, cache_hit_rate: 80.0, cache_miss_rate: 20.0, average_time_ms: 0, last_updated: ~U[...]}
  """
  def calculate_analyzer_metrics(state) when is_map(state) do
    metrics = Map.get(state, :metrics, %{})
    total = Map.get(metrics, :total_analyses, 0)

    if total == 0 do
      default_analyzer_metrics()
    else
      cache_hits = Map.get(metrics, :cache_hits, 0)
      cache_misses = Map.get(metrics, :cache_misses, 0)
      avg_time = Map.get(metrics, :average_analysis_time_ms, 0)

      %{
        total: total,
        cache_hit_rate: calculate_rate(cache_hits, total),
        cache_miss_rate: calculate_rate(cache_misses, total),
        average_time_ms: avg_time,
        last_updated: DateTime.utc_now()
      }
    end
  end

  def calculate_analyzer_metrics(_), do: default_analyzer_metrics()

  @doc """
  Calculate percentage rate from numerator and denominator.

  ## Parameters
  - numerator: The numerator value
  - denominator: The denominator value

  ## Returns
  Float percentage rounded to 2 decimal places, or 0.0 for invalid inputs

  ## Examples
      iex> EveDmv.Shared.MetricsCalculator.calculate_rate(80, 100)
      80.0

      iex> EveDmv.Shared.MetricsCalculator.calculate_rate(1, 3)
      33.33
  """
  def calculate_rate(numerator, denominator) do
    cond do
      not is_number(numerator) or not is_number(denominator) -> 0.0
      denominator == 0 -> 0.0
      true -> Float.round(numerator / denominator * 100, 2)
    end
  end

  @doc """
  Return default analyzer metrics structure.

  ## Returns
  Map with default analyzer metrics values

  ## Examples
      iex> EveDmv.Shared.MetricsCalculator.default_analyzer_metrics()
      %{total: 0, cache_hit_rate: 0.0, cache_miss_rate: 0.0, average_time_ms: 0, last_updated: ~U[...]}
  """
  def default_analyzer_metrics do
    %{
      total: 0,
      cache_hit_rate: 0.0,
      cache_miss_rate: 0.0,
      average_time_ms: 0,
      last_updated: DateTime.utc_now()
    }
  end
end
