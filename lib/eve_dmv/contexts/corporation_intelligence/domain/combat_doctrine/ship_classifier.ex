defmodule EveDmv.Contexts.CorporationIntelligence.Domain.CombatDoctrine.ShipClassifier do
  @moduledoc """
  Ship classification helpers for combat doctrine analysis.
  """

  alias EveDmv.Eve.ItemType
  alias EveDmv.StaticData.ShipTypes

  @spec classify_ship_type(integer() | nil) :: atom()
  def classify_ship_type(ship_type_id) do
    case ShipTypes.classify_ship_type(ship_type_id) do
      :unknown -> :other
      class -> class
    end
  end

  @spec get_ship_specialization(integer() | nil) :: atom()
  def get_ship_specialization(ship_type_id) do
    cond do
      ship_type_id in [11_978, 11_987, 11_985, 12_003] -> :logistics
      ship_type_id in [11_957, 11_958, 11_959, 11_961] -> :ewar
      ship_type_id in [22_456, 22_460, 22_464, 22_468] -> :interdiction
      ship_type_id in [12_013, 12_017, 12_021, 12_025] -> :heavy_interdiction
      ship_type_id in [22_470, 22_852, 17_918, 17_920] -> :command
      ship_type_id in [12_032, 12_036, 12_040, 12_044] -> :bombing
      ship_type_id in [11_182, 11_196, 11_200, 11_204] -> :interception
      ship_type_id in [11_365, 11_377, 11_379, 11_381] -> :assault
      true -> :general
    end
  end

  @spec specialized_ship?(integer() | nil) :: boolean()
  def specialized_ship?(ship_type_id), do: get_ship_specialization(ship_type_id) != :general

  @spec classify_ship_role(integer() | nil) :: atom()
  def classify_ship_role(ship_type_id) do
    case Ash.get(ItemType, ship_type_id, domain: EveDmv.Api) do
      {:ok, ship} -> classify_by_group_name(String.downcase(ship.group_name || ""))
      _ -> :unknown
    end
  end

  defp classify_by_group_name(group_name) do
    cond do
      String.contains?(group_name, "carrier") or String.contains?(group_name, "dreadnought") or
        String.contains?(group_name, "titan") or String.contains?(group_name, "supercarrier") ->
        :capital

      String.contains?(group_name, "logistics") ->
        :logistics

      String.contains?(group_name, "electronic attack") or
        String.contains?(group_name, "combat recon") or
          String.contains?(group_name, "force recon") ->
        :ewar

      String.contains?(group_name, "interceptor") or String.contains?(group_name, "interdictor") ->
        :tackle

      String.contains?(group_name, "frigate") ->
        :frigate

      String.contains?(group_name, "destroyer") ->
        :destroyer

      String.contains?(group_name, "cruiser") ->
        :cruiser

      String.contains?(group_name, "battlecruiser") ->
        :battlecruiser

      String.contains?(group_name, "battleship") ->
        :battleship

      true ->
        :dps
    end
  end

  @spec get_default_role(atom()) :: atom()
  def get_default_role(ship_class) do
    case ship_class do
      :frigate -> :tackle
      :destroyer -> :anti_support
      :cruiser -> :dps
      :battlecruiser -> :heavy_dps
      :battleship -> :main_dps
      :capital -> :capital_dps
      _ -> :general
    end
  end
end
