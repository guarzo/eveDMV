defmodule EveDmvWeb.SearchHelpers do
  @moduledoc """
  Shared helper functions for formatting search result subtitles
  across search components and live views.
  """

  @doc """
  Formats a character subtitle from corporation and alliance names.

  Returns a formatted string showing the character's affiliation.

  ## Examples

      iex> format_character_subtitle("Corp Name", "Alliance Name")
      "Corp Name • Alliance Name"

      iex> format_character_subtitle("Corp Name", nil)
      "Corp Name"

      iex> format_character_subtitle(nil, nil)
      "Independent"
  """
  @spec format_character_subtitle(String.t() | nil, String.t() | nil) :: String.t()
  def format_character_subtitle(corp_name, alliance_name) do
    parts =
      [corp_name, alliance_name]
      |> Enum.filter(&non_blank?/1)

    case parts do
      [] -> "Independent"
      [single] -> single
      [corp, alliance] -> "#{corp} • #{alliance}"
      _ -> Enum.join(parts, " • ")
    end
  end

  defp non_blank?(nil), do: false
  defp non_blank?(str) when is_binary(str), do: String.trim(str) != ""
  defp non_blank?(_), do: false

  @doc """
  Formats a corporation subtitle from alliance name and optional member count.

  When member_count is nil, returns just the alliance name or "Independent".
  When member_count is provided, includes the member count in the subtitle.

  ## Examples

      iex> format_corporation_subtitle("Alliance Name", nil)
      "Alliance Name"

      iex> format_corporation_subtitle(nil, nil)
      "Independent"

      iex> format_corporation_subtitle("Alliance Name", 50)
      "Alliance Name • 50 active members"

      iex> format_corporation_subtitle("Alliance Name", 1)
      "Alliance Name • 1 active member"
  """
  @spec format_corporation_subtitle(String.t() | nil, integer() | nil) :: String.t()
  def format_corporation_subtitle(alliance_name, nil) do
    if alliance_name, do: alliance_name, else: "Independent"
  end

  def format_corporation_subtitle(alliance_name, member_count)
      when is_integer(member_count) and member_count >= 0 do
    alliance_part = if alliance_name, do: alliance_name, else: "Independent"
    member_text = if member_count == 1, do: "1 active member", else: "#{member_count} active members"
    "#{alliance_part} • #{member_text}"
  end

  def format_corporation_subtitle(alliance_name, _member_count) do
    format_corporation_subtitle(alliance_name, nil)
  end
end
