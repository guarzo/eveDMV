defmodule EveDmv.Calculations.Helpers do
  @moduledoc """
  Helper functions for Ash calculations.
  Pure functions for common mathematical operations used across resources.

  All functions are designed to be safe with edge cases (zero division, nil values, etc.)
  and can be imported into calculation modules.
  """

  @doc """
  Safely divide, returning default if denominator is zero or negative.

  ## Examples

      iex> safe_divide(10, 2)
      5.0

      iex> safe_divide(10, 0)
      0.0

      iex> safe_divide(10, 0, nil)
      nil
  """
  @spec safe_divide(number(), number(), any()) :: float() | any()
  def safe_divide(numerator, denominator, default \\ 0.0) do
    if is_number(denominator) and denominator > 0 do
      numerator / denominator
    else
      default
    end
  end

  @doc """
  Calculate percentage of part to whole.

  Returns 0.0 if whole is zero or negative.

  ## Examples

      iex> percentage(25, 100)
      25.0

      iex> percentage(1, 4)
      25.0

      iex> percentage(10, 0)
      0.0
  """
  @spec percentage(number(), number()) :: float()
  def percentage(part, whole) do
    safe_divide(part * 100, whole)
  end

  @doc """
  Calculate K/D ratio with proper zero-death handling.

  When deaths is 0, returns kills as float (effectively infinite K/D).

  ## Examples

      iex> kd_ratio(10, 5)
      2.0

      iex> kd_ratio(10, 0)
      10.0

      iex> kd_ratio(0, 5)
      0.0
  """
  @spec kd_ratio(integer(), integer()) :: float()
  def kd_ratio(kills, deaths) when is_integer(deaths) and deaths > 0 do
    Float.round(kills / deaths, 2)
  end

  def kd_ratio(kills, _deaths) when is_integer(kills) do
    kills * 1.0
  end

  def kd_ratio(_, _), do: 0.0

  @doc """
  Calculate ISK efficiency as a percentage.

  ISK efficiency = (ISK destroyed / (ISK destroyed + ISK lost)) * 100

  ## Examples

      iex> isk_efficiency(100_000_000, 50_000_000)
      66.67

      iex> isk_efficiency(0, 0)
      0.0
  """
  @spec isk_efficiency(number(), number()) :: float()
  def isk_efficiency(isk_destroyed, isk_lost) do
    total = isk_destroyed + isk_lost

    if total > 0 do
      Float.round(isk_destroyed / total * 100, 2)
    else
      0.0
    end
  end

  @doc """
  Normalize a value to a 0.0-1.0 scale based on a max threshold.

  Values at or above the threshold return 1.0.

  ## Examples

      iex> normalize(5, 10)
      0.5

      iex> normalize(15, 10)
      1.0

      iex> normalize(0, 10)
      0.0
  """
  @spec normalize(number(), number()) :: float()
  def normalize(value, max_threshold) when max_threshold > 0 do
    min(1.0, value / max_threshold)
  end

  def normalize(_, _), do: 0.0

  @doc """
  Clamp a value between min and max bounds.

  ## Examples

      iex> clamp(5, 0, 10)
      5

      iex> clamp(-5, 0, 10)
      0

      iex> clamp(15, 0, 10)
      10
  """
  @spec clamp(number(), number(), number()) :: number()
  def clamp(value, min_val, max_val) do
    value
    |> max(min_val)
    |> min(max_val)
  end

  @doc """
  Calculate weighted average from a list of {value, weight} tuples.

  Returns 0.0 if total weight is zero.

  ## Examples

      iex> weighted_average([{10, 2}, {20, 3}])
      16.0  # (10*2 + 20*3) / (2+3) = 80/5

      iex> weighted_average([])
      0.0
  """
  @spec weighted_average([{number(), number()}]) :: float()
  def weighted_average(value_weight_pairs) when is_list(value_weight_pairs) do
    {weighted_sum, total_weight} =
      Enum.reduce(value_weight_pairs, {0.0, 0.0}, fn {value, weight}, {sum, total} ->
        {sum + value * weight, total + weight}
      end)

    safe_divide(weighted_sum, total_weight)
  end

  @doc """
  Round a decimal to specified precision, handling Decimal type.

  ## Examples

      iex> round_decimal(Decimal.new("123.456789"), 2)
      #Decimal<123.46>
  """
  @spec round_decimal(Decimal.t() | number(), non_neg_integer()) :: Decimal.t()
  def round_decimal(%Decimal{} = value, precision) do
    Decimal.round(value, precision)
  end

  def round_decimal(value, precision) when is_number(value) do
    value
    |> Decimal.from_float()
    |> Decimal.round(precision)
  end
end
