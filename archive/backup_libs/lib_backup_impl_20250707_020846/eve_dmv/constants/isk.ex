defmodule EveDmv.Constants.Isk do
  @moduledoc """
  ISK (InterStellar Kredits) value constants and formatting utilities.

  Centralizes all ISK-related multipliers and calculations to ensure consistency
  across the application and make it easier to maintain.
  """

  # ISK multiplier constants
  @thousand 1_000
  @million 1_000_000
  @billion 1_000_000_000
  @trillion 1_000_000_000_000

  @doc """
  ISK value constants for calculations.
  """
  def thousand, do: @thousand
  def million, do: @million
  def billion, do: @billion
  def trillion, do: @trillion

  @doc """
  Convert ISK value to billions for calculations.

  Useful for danger rating calculations and other analytics that work with
  ISK efficiency in billions.
  """
  @spec to_billions(number() | Decimal.t()) :: float()
  def to_billions(value) when is_struct(value, Decimal) do
    value
    |> Decimal.to_float()
    |> to_billions()
  end

  def to_billions(value) when is_number(value) do
    value / @billion
  end

  def to_billions(_), do: 0.0

  @doc """
  Convert ISK value to millions for calculations.
  """
  @spec to_millions(number() | Decimal.t()) :: float()
  def to_millions(value) when is_struct(value, Decimal) do
    value
    |> Decimal.to_float()
    |> to_millions()
  end

  def to_millions(value) when is_number(value) do
    value / @million
  end

  def to_millions(_), do: 0.0

  @doc """
  Check if an ISK value is considered "high value".

  Currently defined as over 1 billion ISK.
  """
  @spec high_value?(number() | Decimal.t()) :: boolean()
  def high_value?(value) when is_struct(value, Decimal) do
    Decimal.compare(value, Decimal.new(@billion)) != :lt
  end

  def high_value?(value) when is_number(value) do
    value >= @billion
  end

  def high_value?(_), do: false

  @doc """
  Format ISK value with appropriate suffix (K, M, B, T).

  This function is used across the application for consistent ISK display.
  """
  @spec format_isk(number() | Decimal.t()) :: String.t()
  def format_isk(decimal_value) when is_struct(decimal_value, Decimal) do
    decimal_value
    |> Decimal.to_float()
    |> format_isk()
  end

  def format_isk(value) when is_number(value) do
    cond do
      value >= @trillion -> "#{Float.round(value / @trillion, 1)}T ISK"
      value >= @billion -> "#{Float.round(value / @billion, 1)}B ISK"
      value >= @million -> "#{Float.round(value / @million, 1)}M ISK"
      value >= @thousand -> "#{Float.round(value / @thousand, 1)}K ISK"
      true -> "#{trunc(value)} ISK"
    end
  end

  def format_isk(_), do: "0 ISK"

  @doc """
  Get the appropriate ISK multiplier for calculations based on scale.

  Returns the divisor value for the given scale.
  """
  @spec get_multiplier(:thousand | :million | :billion | :trillion) :: pos_integer()
  def get_multiplier(:thousand), do: @thousand
  def get_multiplier(:million), do: @million
  def get_multiplier(:billion), do: @billion
  def get_multiplier(:trillion), do: @trillion
end
