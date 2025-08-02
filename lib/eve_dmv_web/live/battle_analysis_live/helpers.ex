defmodule EveDmvWeb.BattleAnalysisLive.Helpers do
  @moduledoc """
  Helper functions for BattleAnalysisLive to reduce dependency count.
  Contains utility functions for formatting, name resolution, and data manipulation.
  """

  alias EveDmv.Eve.NameResolver
  alias EveDmvWeb.Utils.FormattingUtils

  @doc """
  Resolves ship name from type ID.
  """
  def resolve_ship_name(type_id) when is_integer(type_id) do
    NameResolver.ship_name(type_id)
  end

  def resolve_ship_name(_), do: "Unknown Ship"

  @doc """
  Resolves corporation name from corp ID.
  """
  def resolve_corporation_name(corp_id) when is_integer(corp_id) do
    NameResolver.corporation_name(corp_id)
  end

  def resolve_corporation_name(_), do: "Unknown Corp"

  @doc """
  Resolves alliance name from alliance ID.
  """
  def resolve_alliance_name(alliance_id) when is_integer(alliance_id) do
    NameResolver.alliance_name(alliance_id)
  end

  def resolve_alliance_name(_), do: nil

  @doc """
  Generates character portrait URL.
  """
  def character_portrait(character_id, size \\ 64) do
    "https://images.evetech.net/characters/#{character_id}/portrait?size=#{size}"
  end

  @doc """
  Generates corporation logo URL.
  """
  def corporation_logo(corp_id, size \\ 64) do
    "https://images.evetech.net/corporations/#{corp_id}/logo?size=#{size}"
  end

  @doc """
  Generates alliance logo URL.
  """
  def alliance_logo(alliance_id, size \\ 64) do
    "https://images.evetech.net/alliances/#{alliance_id}/logo?size=#{size}"
  end

  @doc """
  Generates ship render URL.
  """
  def ship_render(type_id, size \\ 64) do
    "https://images.evetech.net/types/#{type_id}/render?size=#{size}"
  end

  @doc """
  Gets weapon name from attacker data.
  """
  def get_weapon_name(attacker) do
    case attacker[:weapon_type_id] do
      nil ->
        nil

      weapon_id ->
        weapon_name = NameResolver.item_name(weapon_id)
        if String.starts_with?(weapon_name, "Unknown"), do: nil, else: weapon_name
    end
  end

  @doc """
  Formats ISK values in short form (1.2B, 850M, etc).
  """
  def format_isk_short(value) do
    FormattingUtils.format_isk_short(value)
  end

  @doc """
  Humanizes upload errors for user display.
  """
  def humanize_upload_error(:too_large), do: "File too large (max 10MB)"
  def humanize_upload_error(:not_accepted), do: "Invalid file type (only .txt or .log allowed)"
  def humanize_upload_error(error), do: "Upload error: #{inspect(error)}"

  @doc """
  Determines ship class from type ID using simplified mapping.
  """
  def ship_class_from_id(type_id) when is_integer(type_id) do
    # This is a simplified mapping - in production would use SDE data
    cond do
      type_id in 582..650 -> "Frigate"
      type_id in 324..380 -> "Destroyer"
      type_id in 620..634 -> "Cruiser"
      type_id in 1201..1310 -> "Battlecruiser"
      type_id in 638..645 -> "Battleship"
      type_id in 547..554 -> "Carrier"
      type_id in 671..671 -> "Dreadnought"
      type_id in 3514..3518 -> "Titan"
      type_id in 11_567..12_034 -> "Tech 3 Cruiser"
      type_id in 29_984..29_990 -> "Tech 3 Destroyer"
      type_id in 35_779..35_781 -> "Triglavian"
      true -> "Ship"
    end
  end

  def ship_class_from_id(_), do: "Unknown"

  @doc """
  Gets effective ship side (manual assignment or automatic).
  """
  def get_ship_side(pilot, ship_side_assignments) do
    # Use character_id and ship_type_id for unique pilot/ship combo
    pilot_key = "pilot_#{pilot.character_id}_#{pilot.ship_type_id}"

    case Map.get(ship_side_assignments, pilot_key) do
      nil ->
        # Use automatic side detection based on pilot's analyzed side
        pilot[:side] || "unassigned"

      manual_side ->
        manual_side
    end
  end
end
