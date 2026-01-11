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
      []
      |> then(&if(alliance_name, do: [alliance_name | &1], else: &1))
      |> then(&if(corp_name, do: [corp_name | &1], else: &1))

    case parts do
      [] -> "Independent"
      [corp] -> corp
      [corp, alliance] -> "#{corp} • #{alliance}"
      _ -> Enum.join(parts, " • ")
    end
  end

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
  """
  @spec format_corporation_subtitle(String.t() | nil, integer() | nil) :: String.t()
  def format_corporation_subtitle(alliance_name, nil) do
    if alliance_name, do: alliance_name, else: "Independent"
  end

  def format_corporation_subtitle(alliance_name, member_count) do
    alliance_part = if alliance_name, do: alliance_name, else: "Independent"
    "#{alliance_part} • #{member_count} active members"
  end
end
