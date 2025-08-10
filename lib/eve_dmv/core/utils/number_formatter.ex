defmodule EveDmv.Core.Utils.NumberFormatter do
  @moduledoc """
  Number formatting utilities for human-readable display.

  Provides functions to format numbers in human-readable formats,
  replacing the Number.Human dependency with local implementations.
  """

  @doc """
  Format a number in human-readable format with appropriate suffixes.

  Converts large numbers to abbreviated forms with K, M, B, T suffixes.

  ## Examples

      iex> EveDmv.Core.Utils.NumberFormatter.number_to_human(1500)
      "1.5K"

      iex> EveDmv.Core.Utils.NumberFormatter.number_to_human(2_500_000)
      "2.5M"

      iex> EveDmv.Core.Utils.NumberFormatter.number_to_human(1_200_000_000)
      "1.2B"

      iex> EveDmv.Core.Utils.NumberFormatter.number_to_human(500)
      "500"
  """
  @spec number_to_human(number()) :: String.t()
  def number_to_human(number) when is_number(number) do
    cond do
      abs(number) >= 1_000_000_000_000 ->
        format_with_suffix(number, 1_000_000_000_000, "T")

      abs(number) >= 1_000_000_000 ->
        format_with_suffix(number, 1_000_000_000, "B")

      abs(number) >= 1_000_000 ->
        format_with_suffix(number, 1_000_000, "M")

      abs(number) >= 1_000 ->
        format_with_suffix(number, 1_000, "K")

      true ->
        format_whole_number(number)
    end
  end

  @doc """
  Format ISK values in EVE Online format.

  Special formatting for ISK (currency) values with appropriate precision.

  ## Examples

      iex> EveDmv.Core.Utils.NumberFormatter.isk_to_human(1_500_000.50)
      "1.5M ISK"

      iex> EveDmv.Core.Utils.NumberFormatter.isk_to_human(250_000)
      "250K ISK"
  """
  @spec isk_to_human(number()) :: String.t()
  def isk_to_human(isk_value) when is_number(isk_value) do
    "#{number_to_human(isk_value)} ISK"
  end

  @doc """
  Format a percentage value.

  ## Examples

      iex> EveDmv.Core.Utils.NumberFormatter.percentage(0.156)
      "15.6%"

      iex> EveDmv.Core.Utils.NumberFormatter.percentage(0.9234, 1)
      "92.3%"
  """
  @spec percentage(number(), non_neg_integer()) :: String.t()
  def percentage(decimal_value, precision \\ 1) when is_number(decimal_value) do
    percentage_value = decimal_value * 100
    "#{Float.round(percentage_value, precision)}%"
  end

  @doc """
  Format large integers with thousand separators.

  ## Examples

      iex> EveDmv.Core.Utils.NumberFormatter.with_commas(1234567)
      "1,234,567"

      iex> EveDmv.Core.Utils.NumberFormatter.with_commas(999)
      "999"
  """
  @spec with_commas(integer()) :: String.t()
  def with_commas(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  @doc """
  Format a duration in seconds to human-readable format.

  ## Examples

      iex> EveDmv.Core.Utils.NumberFormatter.duration_to_human(3661)
      "1h 1m 1s"

      iex> EveDmv.Core.Utils.NumberFormatter.duration_to_human(90)
      "1m 30s"
  """
  @spec duration_to_human(integer()) :: String.t()
  def duration_to_human(seconds) when is_integer(seconds) and seconds >= 0 do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    remaining_seconds = rem(seconds, 60)

    []
    |> maybe_add_duration_part(hours > 0, "#{hours}h")
    |> maybe_add_duration_part(minutes > 0, "#{minutes}m")
    |> maybe_add_seconds_part(remaining_seconds)
    |> Enum.reverse()
    |> Enum.join(" ")
  end

  defp maybe_add_duration_part(parts, true, part), do: [part | parts]
  defp maybe_add_duration_part(parts, false, _part), do: parts

  defp maybe_add_seconds_part(parts, remaining_seconds) do
    if remaining_seconds > 0 or Enum.empty?(parts) do
      ["#{remaining_seconds}s" | parts]
    else
      parts
    end
  end

  # Private helper functions

  defp format_with_suffix(number, divisor, suffix) do
    divided = number / divisor

    if divided == trunc(divided) do
      "#{trunc(divided)}#{suffix}"
    else
      "#{Float.round(divided, 1)}#{suffix}"
    end
  end

  defp format_whole_number(number) when is_float(number) do
    if number == trunc(number) do
      Integer.to_string(trunc(number))
    else
      Float.to_string(number)
    end
  end

  defp format_whole_number(number) when is_integer(number) do
    Integer.to_string(number)
  end

  @doc """
  Format a decimal number with specified precision.

  ## Examples

      iex> EveDmv.Core.Utils.NumberFormatter.format_decimal(3.14159, 2)
      "3.14"

      iex> EveDmv.Core.Utils.NumberFormatter.format_decimal(42, 1)
      "42.0"
  """
  @spec format_decimal(number(), non_neg_integer()) :: String.t()
  def format_decimal(number, precision) when is_number(number) and is_integer(precision) do
    :erlang.float_to_binary(number / 1, decimals: precision)
  end

  @doc """
  Format a percentage value with specified precision.

  ## Examples

      iex> EveDmv.Core.Utils.NumberFormatter.format_percentage(0.156, 1)
      "15.6%"

      iex> EveDmv.Core.Utils.NumberFormatter.format_percentage(0.9234, 2)
      "92.34%"
  """
  @spec format_percentage(number(), non_neg_integer()) :: String.t()
  def format_percentage(decimal_value, precision)
      when is_number(decimal_value) and is_integer(precision) do
    percentage_value = decimal_value * 100
    formatted = :erlang.float_to_binary(percentage_value / 1, decimals: precision)
    "#{formatted}%"
  end

  @doc """
  Format ISK values in EVE Online format.

  ## Examples

      iex> EveDmv.Core.Utils.NumberFormatter.format_isk(1_500_000)
      "1.5M ISK"

      iex> EveDmv.Core.Utils.NumberFormatter.format_isk(250_000)
      "250K ISK"
  """
  @spec format_isk(number()) :: String.t()
  def format_isk(isk_value) when is_number(isk_value) do
    isk_to_human(isk_value)
  end
end
