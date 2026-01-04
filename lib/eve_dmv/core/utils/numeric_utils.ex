defmodule EveDmv.Core.Utils.NumericUtils do
  @moduledoc """
  Shared numeric utility functions for type conversion and common calculations.

  Provides centralized implementations for:
  - Converting Decimal, integer, float, and nil values to rounded floats
  - Calculating kill/death ratios with consistent return types

  ## Return Type Standardization

  The `calculate_kd_ratio/2` function always returns a float to ensure consistent
  type handling across the codebase:
  - When deaths > 0: Returns kills / deaths rounded to 2 decimal places
  - When deaths = 0 and kills > 0: Returns kills as a float (representing "perfect" ratio)
  - When both are 0: Returns 0.0

  This avoids runtime type mismatches that could occur if some callers expect
  atoms like `:infinite` while others expect floats.
  """

  @default_precision 2

  @doc """
  Safely converts various numeric types to a rounded float.

  Handles Decimal, integer, float, and nil values. Returns 0.0 for nil or
  unrecognized types.

  ## Parameters
  - `value` - The value to convert (Decimal, integer, float, or nil)
  - `precision` - Number of decimal places to round to (default: 2)

  ## Examples

      iex> NumericUtils.decimal_to_rounded_float(Decimal.new("3.14159"))
      3.14

      iex> NumericUtils.decimal_to_rounded_float(42)
      42.0

      iex> NumericUtils.decimal_to_rounded_float(3.14159, 3)
      3.142

      iex> NumericUtils.decimal_to_rounded_float(nil)
      0.0
  """
  @spec decimal_to_rounded_float(Decimal.t() | integer() | float() | nil, non_neg_integer()) ::
          float()
  def decimal_to_rounded_float(value, precision \\ @default_precision)

  def decimal_to_rounded_float(nil, _precision), do: 0.0

  def decimal_to_rounded_float(%Decimal{} = value, precision) do
    value |> Decimal.to_float() |> Float.round(precision)
  end

  def decimal_to_rounded_float(value, precision) when is_float(value) do
    Float.round(value, precision)
  end

  def decimal_to_rounded_float(value, _precision) when is_integer(value) do
    value * 1.0
  end

  def decimal_to_rounded_float(_value, _precision), do: 0.0

  @doc """
  Safely converts a value to a float without rounding.

  Useful for intermediate calculations where rounding should be deferred.

  ## Examples

      iex> NumericUtils.to_float(Decimal.new("3.14159"))
      3.14159

      iex> NumericUtils.to_float(42)
      42.0

      iex> NumericUtils.to_float(nil)
      nil
  """
  @spec to_float(Decimal.t() | integer() | float() | nil) :: float() | nil
  def to_float(nil), do: nil
  def to_float(%Decimal{} = value), do: Decimal.to_float(value)
  def to_float(value) when is_integer(value), do: value * 1.0
  def to_float(value) when is_float(value), do: value
  def to_float(_), do: nil

  @doc """
  Calculates kill/death ratio with consistent float return type.

  This function standardizes KD ratio calculation across the codebase.
  It always returns a float to avoid runtime type mismatches.

  ## Parameters
  - `kills` - Number of kills (Decimal, integer, float, or nil)
  - `deaths` - Number of deaths (Decimal, integer, float, or nil)

  ## Return Values
  - When deaths > 0: Returns kills / deaths rounded to 2 decimal places
  - When deaths = 0 and kills > 0: Returns kills as a float (represents "undefeated")
  - When both are 0: Returns 0.0

  ## Examples

      iex> NumericUtils.calculate_kd_ratio(10, 5)
      2.0

      iex> NumericUtils.calculate_kd_ratio(10, 3)
      3.33

      iex> NumericUtils.calculate_kd_ratio(10, 0)
      10.0

      iex> NumericUtils.calculate_kd_ratio(0, 0)
      0.0

      iex> NumericUtils.calculate_kd_ratio(Decimal.new("15"), Decimal.new("3"))
      5.0
  """
  @spec calculate_kd_ratio(
          Decimal.t() | integer() | float() | nil,
          Decimal.t() | integer() | float() | nil
        ) :: float()
  def calculate_kd_ratio(kills, deaths) do
    k = to_float(kills) || 0.0
    d = to_float(deaths) || 0.0

    cond do
      d > 0 -> Float.round(k / d, @default_precision)
      k > 0 -> k * 1.0
      true -> 0.0
    end
  end
end
