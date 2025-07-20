defmodule EveDmv.Utils.DataTransform do
  @moduledoc """
  Common data transformation utilities to reduce duplication.
  
  Part of Sprint 22 Quality Standards - Code Duplication Elimination.
  """

  @doc """
  Safe integer parsing with default.
  """
  def safe_to_integer(value, default \\ 0)

  def safe_to_integer(value, default) when is_integer(value), do: value
  def safe_to_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> default
    end
  end
  def safe_to_integer(_, default), do: default

  @doc """
  Safe float parsing with default.
  """
  def safe_to_float(value, default \\ 0.0)

  def safe_to_float(value, default) when is_float(value), do: value
  def safe_to_float(value, default) when is_integer(value), do: value / 1
  def safe_to_float(value, default) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> float
      _ -> default
    end
  end
  def safe_to_float(_, default), do: default

  @doc """
  Convert map keys from strings to atoms safely.
  """
  def atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) ->
        try do
          {String.to_existing_atom(key), atomize_keys(value)}
        rescue
          ArgumentError -> {key, atomize_keys(value)}
        end
      {key, value} -> {key, atomize_keys(value)}
    end)
  end

  def atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  def atomize_keys(value), do: value

  @doc """
  Deep merge two maps.
  """
  def deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _k, v1, v2 ->
      if is_map(v1) and is_map(v2) do
        deep_merge(v1, v2)
      else
        v2
      end
    end)
  end

  def deep_merge(left, right), do: right

  @doc """
  Calculate percentage safely.
  """
  def safe_percentage(numerator, denominator, precision \\ 2)

  def safe_percentage(_, 0, _), do: 0.0
  def safe_percentage(0, _, _), do: 0.0
  def safe_percentage(numerator, denominator, precision) do
    Float.round(numerator / denominator * 100, precision)
  end

  @doc """
  Calculate ratio safely.
  """
  def safe_ratio(numerator, denominator, precision \\ 2)

  def safe_ratio(_, 0, _), do: 0.0
  def safe_ratio(numerator, denominator, precision) do
    Float.round(numerator / denominator, precision)
  end

  @doc """
  Filter map by keys, removing nil values.
  """
  def compact_map(map, allowed_keys \\ nil) when is_map(map) do
    map
    |> Map.take(allowed_keys || Map.keys(map))
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  @doc """
  Ensure value is within bounds.
  """
  def clamp(value, min_val, max_val) do
    value
    |> max(min_val)
    |> min(max_val)
  end
end