defmodule EveDmv.Utils.ParsingUtils do
  @moduledoc """
  Common parsing utilities used across the application.

  This module consolidates duplicate parsing functions to reduce code duplication
  and provide consistent parsing behavior throughout the codebase.
  """

  @doc """
  Parse a value into a Decimal, returning Decimal.new(0) for invalid inputs.

  ## Examples

      iex> parse_decimal(123)
      #Decimal<123>

      iex> parse_decimal(123.45)
      #Decimal<123.45>

      iex> parse_decimal("123.45")
      #Decimal<123.45>

      iex> parse_decimal(nil)
      #Decimal<0>

      iex> parse_decimal("invalid")
      #Decimal<0>
  """
  @spec parse_decimal(term()) :: Decimal.t()
  def parse_decimal(nil), do: Decimal.new(0)
  def parse_decimal(value) when is_integer(value), do: Decimal.new(value)
  def parse_decimal(value) when is_float(value), do: Decimal.from_float(value)

  def parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> Decimal.new(0)
    end
  end

  def parse_decimal(_), do: Decimal.new(0)

  @doc """
  Parse a DateTime from an ISO8601 string, returning nil for invalid inputs.

  ## Examples

      iex> parse_datetime("2024-01-01T12:00:00Z")
      ~U[2024-01-01 12:00:00Z]

      iex> parse_datetime(nil)
      nil

      iex> parse_datetime("invalid")
      nil
  """
  @spec parse_datetime(String.t() | nil) :: DateTime.t() | nil
  def parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  def parse_datetime(_), do: nil

  @doc """
  Parse an integer, returning a default value for invalid inputs.

  ## Examples

      iex> parse_integer("123")
      123

      iex> parse_integer("123", 0)
      123

      iex> parse_integer("invalid", 0)
      0

      iex> parse_integer(nil, 42)
      42
  """
  @spec parse_integer(term(), integer()) :: integer()
  def parse_integer(value, default \\ 0)
  def parse_integer(value, _default) when is_integer(value), do: value

  def parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {integer, _} -> integer
      :error -> default
    end
  end

  def parse_integer(_, default), do: default

  @doc """
  Parse a float, returning a default value for invalid inputs.

  ## Examples

      iex> parse_float("123.45")
      123.45

      iex> parse_float("invalid", 0.0)
      0.0

      iex> parse_float(nil, 1.0)
      1.0
  """
  @spec parse_float(term(), float()) :: float()
  def parse_float(value, default \\ 0.0)
  def parse_float(value, _default) when is_float(value), do: value
  def parse_float(value, _default) when is_integer(value), do: value / 1

  def parse_float(value, default) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> default
    end
  end

  def parse_float(_, default), do: default
end
