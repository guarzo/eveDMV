defmodule EveDmv.StaticData.ShipTypes do
  @moduledoc """
  Ship type classification using EVE static data.

  This module provides ship type IDs and classifications based on
  queries against the eve_item_types table which contains the full
  EVE Online static data export (SDE).

  For optimal performance, ship classifications are cached at compile time,
  but the module also provides runtime queries against the database.
  """

  alias EveDmv.Repo
  alias EveDmv.Eve.ItemType
  import Ecto.Query

  @doc """
  Classify a ship by its type ID using database lookup.

  This performs a runtime query against the eve_item_types table.
  For better performance in hot paths, consider caching results.

  Returns the ship class as an atom, or :unknown if not found.
  """
  def classify_ship_type(type_id) when is_integer(type_id) do
    # Query the database for the ship's group name
    case Repo.one(
           from(i in ItemType,
             where: i.type_id == ^type_id and i.is_ship == true,
             select: i.group_name
           )
         ) do
      nil -> :unknown
      group_name -> classify_by_group_name(group_name)
    end
  end

  def classify_ship_type(_), do: :unknown

  # Classify a ship based on its group name from the SDE
  defp classify_by_group_name(group_name) do
    case group_name do
      # Frigates
      "Frigate" -> :frigate
      "Assault Frigate" -> :frigate
      "Covert Ops" -> :frigate
      "Electronic Attack Frigate" -> :frigate
      "Interceptor" -> :frigate
      "Logistics Frigate" -> :frigate
      "Expedition Frigate" -> :frigate
      "Stealth Bomber" -> :frigate
      # Destroyers
      "Destroyer" -> :destroyer
      "Interdictor" -> :destroyer
      "Command Destroyer" -> :destroyer
      "Tactical Destroyer" -> :destroyer
      # Cruisers
      "Cruiser" -> :cruiser
      "Heavy Assault Cruiser" -> :cruiser
      "Heavy Interdiction Cruiser" -> :cruiser
      "Logistics Cruiser" -> :cruiser
      "Recon Ship" -> :cruiser
      "Strategic Cruiser" -> :cruiser
      "Combat Recon Ship" -> :cruiser
      "Force Recon Ship" -> :cruiser
      # Battlecruisers
      "Battlecruiser" -> :battlecruiser
      "Combat Battlecruiser" -> :battlecruiser
      "Attack Battlecruiser" -> :battlecruiser
      "Command Ship" -> :battlecruiser
      # Battleships
      "Battleship" -> :battleship
      "Black Ops" -> :battleship
      "Marauder" -> :battleship
      # Capitals
      "Carrier" -> :capital
      "Dreadnought" -> :capital
      "Force Auxiliary" -> :capital
      "Capital Industrial Ship" -> :capital
      # Supercapitals
      "Supercarrier" -> :supercapital
      "Titan" -> :supercapital
      # Industrial
      "Industrial" -> :industrial
      "Transport Ship" -> :industrial
      "Blockade Runner" -> :industrial
      "Deep Space Transport" -> :industrial
      "Industrial Command Ship" -> :industrial
      "Freighter" -> :industrial
      "Jump Freighter" -> :industrial
      # Mining
      "Mining Barge" -> :mining
      "Exhumer" -> :mining
      # Default
      _ -> :unknown
    end
  end

  @doc """
  Check if a ship type ID belongs to a specific class.
  """
  def is_ship_class?(type_id, class) when is_atom(class) do
    classify_ship_type(type_id) == class
  end

  @doc """
  Get all ship type IDs for a specific class from the database.

  This performs a runtime query and should be cached if used frequently.
  """
  def get_ship_ids_for_class(class) when is_atom(class) do
    group_names = get_group_names_for_class(class)

    Repo.all(
      from(i in ItemType,
        where: i.group_name in ^group_names and i.is_ship == true and i.published == true,
        select: i.type_id
      )
    )
  end

  # Helper to map ship classes to their group names
  defp get_group_names_for_class(:frigate) do
    [
      "Frigate",
      "Assault Frigate",
      "Covert Ops",
      "Electronic Attack Frigate",
      "Interceptor",
      "Logistics Frigate",
      "Expedition Frigate",
      "Stealth Bomber"
    ]
  end

  defp get_group_names_for_class(:destroyer) do
    ["Destroyer", "Interdictor", "Command Destroyer", "Tactical Destroyer"]
  end

  defp get_group_names_for_class(:cruiser) do
    [
      "Cruiser",
      "Heavy Assault Cruiser",
      "Heavy Interdiction Cruiser",
      "Logistics Cruiser",
      "Recon Ship",
      "Strategic Cruiser",
      "Combat Recon Ship",
      "Force Recon Ship"
    ]
  end

  defp get_group_names_for_class(:battlecruiser) do
    ["Battlecruiser", "Combat Battlecruiser", "Attack Battlecruiser", "Command Ship"]
  end

  defp get_group_names_for_class(:battleship) do
    ["Battleship", "Black Ops", "Marauder"]
  end

  defp get_group_names_for_class(:capital) do
    ["Carrier", "Dreadnought", "Force Auxiliary", "Capital Industrial Ship"]
  end

  defp get_group_names_for_class(:supercapital) do
    ["Supercarrier", "Titan"]
  end

  defp get_group_names_for_class(:industrial) do
    [
      "Industrial",
      "Transport Ship",
      "Blockade Runner",
      "Deep Space Transport",
      "Industrial Command Ship",
      "Freighter",
      "Jump Freighter"
    ]
  end

  defp get_group_names_for_class(:mining) do
    ["Mining Barge", "Exhumer"]
  end

  defp get_group_names_for_class(_), do: []

  @doc """
  Commonly used ship groups for tactical analysis.
  """
  def tactical_ship_groups do
    %{
      tackle: [:frigate, :destroyer],
      dps: [:cruiser, :battlecruiser, :battleship],
      support: [:cruiser, :battlecruiser],
      capital: [:capital, :supercapital],
      industrial: [:industrial, :mining]
    }
  end

  @doc """
  Check if a ship is typically used for tackling.
  """
  def is_tackle_ship?(type_id) do
    classify_ship_type(type_id) in [:frigate, :destroyer]
  end

  @doc """
  Check if a ship is typically a DPS platform.
  """
  def is_dps_ship?(type_id) do
    classify_ship_type(type_id) in [:cruiser, :battlecruiser, :battleship]
  end

  @doc """
  Check if a ship is a support vessel.

  Note: This queries the database to check for logistics and EWAR ships specifically.
  """
  def is_support_ship?(type_id) do
    is_logistics?(type_id) or is_ewar?(type_id)
  end

  @doc """
  Get interceptor ship type IDs from the database.
  """
  def interceptor_ship_ids do
    Repo.all(
      from(i in ItemType,
        where: i.group_name == "Interceptor" and i.is_ship == true and i.published == true,
        select: i.type_id
      )
    )
  end

  @doc """
  Get logistics ship type IDs from the database.
  """
  def logistics_ship_ids do
    Repo.all(
      from(i in ItemType,
        where:
          i.group_name in ["Logistics Cruiser", "Logistics Frigate", "Force Auxiliary"] and
            i.is_ship == true and i.published == true,
        select: i.type_id
      )
    )
  end

  @doc """
  Get electronic warfare ship type IDs from the database.
  """
  def ewar_ship_ids do
    Repo.all(
      from(i in ItemType,
        where:
          i.group_name in [
            "Electronic Attack Frigate",
            "Combat Recon Ship",
            "Force Recon Ship",
            "Recon Ship"
          ] and
            i.is_ship == true and i.published == true,
        select: i.type_id
      )
    )
  end

  @doc """
  Check if a ship type ID is an interceptor.
  """
  def is_interceptor?(type_id) when is_integer(type_id) do
    case Repo.one(
           from(i in ItemType,
             where:
               i.type_id == ^type_id and i.group_name == "Interceptor" and
                 i.is_ship == true and i.published == true
           )
         ) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Check if a ship type ID is a logistics ship.
  """
  def is_logistics?(type_id) when is_integer(type_id) do
    case Repo.one(
           from(i in ItemType,
             where:
               i.type_id == ^type_id and
                 i.group_name in ["Logistics Cruiser", "Logistics Frigate", "Force Auxiliary"] and
                 i.is_ship == true and i.published == true
           )
         ) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Check if a ship type ID is an EWAR ship.
  """
  def is_ewar?(type_id) when is_integer(type_id) do
    case Repo.one(
           from(i in ItemType,
             where:
               i.type_id == ^type_id and
                 i.group_name in [
                   "Electronic Attack Frigate",
                   "Combat Recon Ship",
                   "Force Recon Ship",
                   "Recon Ship"
                 ] and
                 i.is_ship == true and i.published == true
           )
         ) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  DEPRECATED: Returns ship type ranges. Use classify_ship_type/1 instead.

  This function is kept for backward compatibility.
  """
  @deprecated "Use classify_ship_type/1 or database queries instead"
  def ship_type_ranges do
    # Return empty ranges - all classification is now done via database queries
    %{
      frigate: [],
      destroyer: [],
      cruiser: [],
      battlecruiser: [],
      battleship: [],
      capital: [],
      industrial: [],
      mining: [],
      supercapital: []
    }
  end
end
