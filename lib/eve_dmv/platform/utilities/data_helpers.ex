defmodule EveDmv.Platform.Utilities.DataHelpers do
  @moduledoc """
  Common data manipulation and validation utilities used across the application.

  This module provides helper functions for:
  - Data structure manipulation
  - Validation and sanitization  
  - Format conversion
  - Common calculations
  """

  require Logger

  # Data structure manipulation

  @doc """
  Deep merge two maps, with the second map taking precedence.
  """
  @spec deep_merge(map(), map()) :: map()
  def deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, left_val, right_val ->
      if is_map(left_val) and is_map(right_val) do
        deep_merge(left_val, right_val)
      else
        right_val
      end
    end)
  end

  def deep_merge(left, _right), do: left

  @doc """
  Remove nil values from a map recursively.
  """
  @spec remove_nils(map()) :: map()
  def remove_nils(map) when is_map(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.map(fn {key, value} ->
      if is_map(value) do
        {key, remove_nils(value)}
      else
        {key, value}
      end
    end)
    |> Map.new()
  end

  def remove_nils(value), do: value

  @doc """
  Convert string keys to atom keys recursively.
  Only converts strings that already exist as atoms to avoid atom exhaustion.
  """
  @spec atomize_keys(map() | list()) :: map() | list()
  def atomize_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} ->
      atom_key = if is_binary(key), do: String.to_existing_atom(key), else: key
      {atom_key, atomize_keys(value)}
    end)
    |> Map.new()
  end

  def atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  def atomize_keys(value), do: value

  @doc """
  Convert atom keys to string keys recursively.
  """
  @spec stringify_keys(map() | list()) :: map() | list()
  def stringify_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} ->
      string_key = if is_atom(key), do: Atom.to_string(key), else: key
      {string_key, stringify_keys(value)}
    end)
    |> Map.new()
  end

  def stringify_keys(list) when is_list(list) do
    Enum.map(list, &stringify_keys/1)
  end

  def stringify_keys(value), do: value

  # Validation and sanitization

  @doc """
  Validate that a value is a positive integer.
  """
  @spec validate_positive_integer(any()) :: {:ok, integer()} | {:error, String.t()}
  def validate_positive_integer(value) when is_integer(value) and value > 0 do
    {:ok, value}
  end

  def validate_positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> {:ok, int}
      _ -> {:error, "Invalid positive integer"}
    end
  end

  def validate_positive_integer(_) do
    {:error, "Invalid positive integer"}
  end

  @doc """
  Validate that a value is a valid EVE character ID.
  """
  @spec validate_character_id(any()) :: {:ok, integer()} | {:error, String.t()}
  def validate_character_id(value) when is_integer(value) and value > 90_000_000 do
    {:ok, value}
  end

  def validate_character_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 90_000_000 -> {:ok, int}
      _ -> {:error, "Invalid character ID"}
    end
  end

  def validate_character_id(_) do
    {:error, "Invalid character ID"}
  end

  @doc """
  Sanitize a string by removing dangerous characters.
  """
  @spec sanitize_string(String.t()) :: String.t()
  def sanitize_string(string) when is_binary(string) do
    string
    |> String.replace(~r/[<>\"'&]/, "")
    |> String.trim()
  end

  def sanitize_string(_), do: ""

  # Format conversion

  @doc """
  Format ISK values with appropriate suffixes (K, M, B, T).
  """
  @spec format_isk(number()) :: String.t()
  def format_isk(isk) when is_number(isk) do
    cond do
      isk >= 1_000_000_000_000 -> "#{Float.round(isk / 1_000_000_000_000, 2)}T"
      isk >= 1_000_000_000 -> "#{Float.round(isk / 1_000_000_000, 2)}B"
      isk >= 1_000_000 -> "#{Float.round(isk / 1_000_000, 2)}M"
      isk >= 1_000 -> "#{Float.round(isk / 1_000, 2)}K"
      true -> "#{Float.round(isk, 2)}"
    end
  end

  def format_isk(_), do: "0"

  @doc """
  Format large numbers with comma separators.
  """
  @spec format_number(number()) :: String.t()
  def format_number(number) when is_number(number) do
    number
    |> trunc()
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.map(&Enum.join/1)
    |> Enum.join(",")
  end

  def format_number(_), do: "0"

  @doc """
  Format duration in seconds to human readable format.
  """
  @spec format_duration(integer()) :: String.t()
  def format_duration(seconds) when is_integer(seconds) and seconds >= 0 do
    cond do
      seconds >= 86_400 ->
        days = div(seconds, 86_400)
        hours = div(rem(seconds, 86_400), 3600)
        "#{days}d #{hours}h"

      seconds >= 3600 ->
        hours = div(seconds, 3600)
        minutes = div(rem(seconds, 3600), 60)
        "#{hours}h #{minutes}m"

      seconds >= 60 ->
        minutes = div(seconds, 60)
        secs = rem(seconds, 60)
        "#{minutes}m #{secs}s"

      true ->
        "#{seconds}s"
    end
  end

  def format_duration(_), do: "0s"

  # Common calculations

  @doc """
  Calculate percentage with specified decimal places.
  """
  @spec percentage(number(), number(), integer()) :: float()
  def percentage(part, total, decimal_places \\ 2)

  def percentage(_part, 0, _decimal_places), do: 0.0

  def percentage(part, total, decimal_places) when is_number(part) and is_number(total) do
    (part / total * 100)
    |> Float.round(decimal_places)
  end

  def percentage(_, _, _), do: 0.0

  @doc """
  Calculate efficiency ratio (0.0 to 1.0).
  """
  @spec efficiency_ratio(number(), number()) :: float()
  def efficiency_ratio(destroyed, lost) when is_number(destroyed) and is_number(lost) do
    if destroyed + lost > 0 do
      destroyed / (destroyed + lost)
    else
      1.0
    end
  end

  def efficiency_ratio(_, _), do: 0.0

  @doc """
  Safe division that returns 0 for division by zero.
  """
  @spec safe_divide(number(), number()) :: float()
  def safe_divide(_numerator, 0), do: 0.0
  def safe_divide(_numerator, +0.0), do: 0.0
  def safe_divide(_numerator, -0.0), do: 0.0

  def safe_divide(numerator, denominator) when is_number(numerator) and is_number(denominator) do
    numerator / denominator
  end

  def safe_divide(_, _), do: 0.0

  # Statistical calculations

  @doc """
  Calculate the mean of a list of numbers.
  """
  @spec mean([number()]) :: float()
  def mean([]), do: 0.0

  def mean(numbers) when is_list(numbers) do
    numbers
    |> Enum.filter(&is_number/1)
    |> case do
      [] -> 0.0
      filtered -> Enum.sum(filtered) / length(filtered)
    end
  end

  @doc """
  Calculate the median of a list of numbers.
  """
  @spec median([number()]) :: float()
  def median([]), do: 0.0

  def median(numbers) when is_list(numbers) do
    sorted =
      numbers
      |> Enum.filter(&is_number/1)
      |> Enum.sort()

    case length(sorted) do
      0 ->
        0.0

      len when rem(len, 2) == 1 ->
        Enum.at(sorted, div(len, 2)) * 1.0

      len ->
        mid1 = Enum.at(sorted, div(len, 2) - 1)
        mid2 = Enum.at(sorted, div(len, 2))
        (mid1 + mid2) / 2
    end
  end

  @doc """
  Calculate standard deviation of a list of numbers.
  """
  @spec standard_deviation([number()]) :: float()
  def standard_deviation([]), do: 0.0
  def standard_deviation([_]), do: 0.0

  def standard_deviation(numbers) when is_list(numbers) do
    filtered = Enum.filter(numbers, &is_number/1)

    case length(filtered) do
      0 ->
        0.0

      1 ->
        0.0

      _ ->
        avg = mean(filtered)

        variance =
          filtered
          |> Enum.map(fn x -> (x - avg) * (x - avg) end)
          |> mean()

        :math.sqrt(variance)
    end
  end

  # Date and time utilities

  @doc """
  Get the start of day for a given datetime.
  """
  @spec start_of_day(DateTime.t()) :: DateTime.t()
  def start_of_day(%DateTime{} = datetime) do
    %{datetime | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  @doc """
  Get the end of day for a given datetime.
  """
  @spec end_of_day(DateTime.t()) :: DateTime.t()
  def end_of_day(%DateTime{} = datetime) do
    %{datetime | hour: 23, minute: 59, second: 59, microsecond: {999_999, 6}}
  end

  @doc """
  Convert seconds to days (floating point).
  """
  @spec seconds_to_days(integer()) :: float()
  def seconds_to_days(seconds) when is_integer(seconds) do
    seconds / 86_400
  end

  def seconds_to_days(_), do: 0.0

  # Error handling utilities

  @doc """
  Safely execute a function and return a default value on error.
  """
  @spec safe_call((-> any()), any()) :: any()
  def safe_call(func, default \\ nil) when is_function(func, 0) do
    func.()
  rescue
    error ->
      Logger.warning("Safe call failed", %{
        error: inspect(error),
        default: inspect(default)
      })

      default
  end

  @doc """
  Log and return error tuple for debugging.
  """
  @spec log_error(String.t(), any()) :: {:error, any()}
  def log_error(message, error) do
    Logger.error(message, %{error: inspect(error)})
    {:error, error}
  end
end
