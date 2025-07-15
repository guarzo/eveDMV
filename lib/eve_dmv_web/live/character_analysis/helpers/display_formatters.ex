defmodule EveDmvWeb.CharacterAnalysis.Helpers.DisplayFormatters do
  @moduledoc """
  Helper module for formatting display data in character analysis views.
  """

  @doc """
  Format ISK values with appropriate suffixes (K, M, B, T).
  """
  def format_isk(isk) when is_number(isk) do
    cond do
      isk >= 1_000_000_000_000 -> "#{Float.round(isk / 1_000_000_000_000, 1)}T ISK"
      isk >= 1_000_000_000 -> "#{Float.round(isk / 1_000_000_000, 1)}B ISK"
      isk >= 1_000_000 -> "#{Float.round(isk / 1_000_000, 1)}M ISK"
      isk >= 1_000 -> "#{Float.round(isk / 1_000, 1)}K ISK"
      true -> "#{isk} ISK"
    end
  end

  def format_isk(_), do: "0 ISK"

  @doc """
  Get threat level color class based on score.
  """
  def threat_level_color(score) when score >= 90, do: "text-red-500"
  def threat_level_color(score) when score >= 75, do: "text-orange-500"
  def threat_level_color(score) when score >= 50, do: "text-yellow-500"
  def threat_level_color(score) when score >= 25, do: "text-blue-500"
  def threat_level_color(_), do: "text-green-500"

  @doc """
  Get threat level background class based on score.
  """
  def threat_level_bg(score) when score >= 90, do: "bg-red-900/20 border-red-800"
  def threat_level_bg(score) when score >= 75, do: "bg-orange-900/20 border-orange-800"
  def threat_level_bg(score) when score >= 50, do: "bg-yellow-900/20 border-yellow-800"
  def threat_level_bg(score) when score >= 25, do: "bg-blue-900/20 border-blue-800"
  def threat_level_bg(_), do: "bg-green-900/20 border-green-800"

  @doc """
  Format time for display (padding with zeros).
  """
  def format_time_hour(hour) when is_integer(hour) do
    String.pad_leading(Integer.to_string(hour), 2, "0") <> ":00 EVE"
  end

  def format_time_hour(_), do: "N/A"

  @doc """
  Format numbers with thousand separators.
  """
  def format_number(number) when is_number(number) do
    number
    |> to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.join/1)
    |> Enum.join(",")
    |> String.reverse()
  end

  def format_number(_), do: "0"

  @doc """
  Format percentage values.
  """
  def format_percentage(value) when is_number(value) do
    "#{Float.round(value, 1)}%"
  end

  def format_percentage(_), do: "0%"

  @doc """
  Format kill/death ratio.
  """
  def format_kd_ratio(kills, deaths) when is_number(kills) and is_number(deaths) do
    cond do
      deaths == 0 and kills > 0 -> "#{kills}:0"
      deaths == 0 -> "0:0"
      true -> "#{Float.round(kills / deaths, 2)}:1"
    end
  end

  def format_kd_ratio(_, _), do: "0:0"
end
