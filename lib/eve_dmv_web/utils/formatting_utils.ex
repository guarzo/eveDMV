defmodule EveDmvWeb.Utils.FormattingUtils do
  @moduledoc """
  Shared formatting utilities for the EVE DMV web interface.
  """

  @doc """
  Formats ISK values in short form (K, M, B).

  Examples:
      iex> EveDmvWeb.Utils.FormattingUtils.format_isk_short(1_500_000)
      "1.5M"

      iex> EveDmvWeb.Utils.FormattingUtils.format_isk_short(2_300_000_000)
      "2.3B"
  """
  def format_isk_short(value) when is_number(value) do
    cond do
      value >= 1_000_000_000 -> "#{Float.round(value / 1_000_000_000, 1)}B"
      value >= 1_000_000 -> "#{Float.round(value / 1_000_000, 1)}M"
      value >= 1_000 -> "#{Float.round(value / 1_000, 1)}K"
      true -> "#{round(value)}"
    end
  end

  def format_isk_short(nil), do: "0"
  def format_isk_short(_), do: "0"

  @doc """
  Formats numeric values with commas as thousands separators.

  Examples:
      iex> EveDmvWeb.Utils.FormattingUtils.format_number_with_commas(1234567)
      "1,234,567"
  """
  def format_number_with_commas(value) when is_number(value) do
    value
    |> round()
    |> Integer.to_string()
    |> String.replace(~r/(\d)(?=(\d{3})+(?!\d))/, "\\1,")
  end

  def format_number_with_commas(_), do: "0"
end
