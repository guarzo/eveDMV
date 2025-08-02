defmodule EveDmv.StaticData.ShipTypes do
  @moduledoc """
  Ship type classification using EVE static data.

  This module provides ship type IDs and classifications based on
  queries against the eve_item_types table which contains the full
  EVE Online static data export (SDE).

  For optimal performance, ship classifications are cached at compile time,
  but the module also provides runtime queries against the database.
  """

  import Ecto.Query
  alias EveDmv.Api
  alias EveDmv.Eve.ItemType
  alias EveDmv.Repo
  alias EveDmv.StaticData.ShipAttributes

  @doc """
  Classify a ship by its type ID using database lookup.

  This performs a runtime query against the eve_item_types table.
  For better performance in hot paths, consider caching results.

  Returns the ship class as an atom, or :unknown if not found.
  """
  @type ship_class :: :frigate | :destroyer | :cruiser | :battlecruiser | :battleship |
                      :capital | :supercapital | :industrial | :mining | :logistics |
                      :structure | :unknown
  @spec classify_ship_type(integer() | any()) :: ship_class()
  def classify_ship_type(type_id) when is_integer(type_id) do
    # Query the database for the ship's group name
    case from(i in ItemType,
           where: i.type_id == ^type_id and i.is_ship == true,
           select: i.group_name
         )
         |> Repo.one() do
      nil -> :unknown
      group_name -> classify_by_group_name(group_name)
    end
  end

  def classify_ship_type(_), do: :unknown

  @doc """
  Check if a ship is Tech 2 based on its group name.
  """
  def t2_ship?(type_id) when is_integer(type_id) do
    case get_ship_group_name(type_id) do
      nil -> false
      group_name -> t2_group?(group_name)
    end
  end

  def t2_ship?(_), do: false

  @doc """
  Check if a ship is Tech 3 (Strategic Cruiser) based on its group name.
  """
  def t3_ship?(type_id) when is_integer(type_id) do
    case get_ship_group_name(type_id) do
      nil -> false
      "Strategic Cruiser" -> true
      _ -> false
    end
  end

  def t3_ship?(_), do: false

  @doc """
  Check if a ship is a faction ship based on its group name.
  """
  def faction_ship?(type_id) when is_integer(type_id) do
    case get_ship_group_name(type_id) do
      nil -> false
      group_name -> faction_group?(group_name)
    end
  end

  def faction_ship?(_), do: false

  # Helper function to get ship group name
  defp get_ship_group_name(type_id) do
    from(i in ItemType,
      where: i.type_id == ^type_id and i.is_ship == true,
      select: i.group_name
    )
    |> Repo.one()
  end

  # Check if group name indicates T2 ship
  defp t2_group?(group_name) do
    group_name in [
      "Assault Frigate",
      "Covert Ops",
      "Electronic Attack Frigate",
      "Interceptor",
      "Stealth Bomber",
      "Heavy Assault Cruiser",
      "Heavy Interdictor",
      "Logistics",
      "Recon Ship",
      "Interdictor",
      "Command Ship",
      "Black Ops",
      "Marauder"
    ]
  end

  # Check if group name indicates faction ship
  defp faction_group?(group_name) do
    group_name in [
      "Faction Frigate",
      "Faction Cruiser",
      "Faction Battleship",
      "Pirate Frigate",
      "Pirate Cruiser",
      "Pirate Battleship"
    ] or String.contains?(group_name, ["Navy", "Fleet", "Faction"])
  end

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
      # Structures
      "Control Tower" -> :structure
      "Citadel" -> :structure
      "Engineering Complex" -> :structure
      "Refinery" -> :structure
      "POS Module" -> :structure
      "Starbase" -> :structure
      "Territorial Claim Unit" -> :structure
      "Infrastructure Hub" -> :structure
      "Sovereignty Blockade Unit" -> :structure
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

    from(i in ItemType,
      where: i.group_name in ^group_names and i.is_ship == true and i.published == true,
      select: i.type_id
    )
    |> Repo.all()
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

  defp get_group_names_for_class(:structure) do
    [
      "Control Tower",
      "Citadel",
      "Engineering Complex",
      "Refinery",
      "POS Module",
      "Starbase",
      "Territorial Claim Unit",
      "Infrastructure Hub",
      "Sovereignty Blockade Unit"
    ]
  end

  defp get_group_names_for_class(:stealth_bomber) do
    ["Stealth Bomber"]
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
  def tackle_ship?(type_id) do
    classify_ship_type(type_id) in [:frigate, :destroyer]
  end

  @doc """
  Check if a ship is typically a DPS platform.
  """
  def dps_ship?(type_id) do
    classify_ship_type(type_id) in [:cruiser, :battlecruiser, :battleship]
  end

  @doc """
  Check if a ship is a support vessel.

  Note: This queries the database to check for logistics and EWAR ships specifically.
  """
  def support_ship?(type_id) do
    logistics?(type_id) or ewar?(type_id)
  end

  @doc """
  Get interceptor ship type IDs from the database.
  """
  def interceptor_ship_ids do
    from(i in ItemType,
      where: i.group_name == "Interceptor" and i.is_ship == true and i.published == true,
      select: i.type_id
    )
    |> Repo.all()
  end

  @doc """
  Get logistics ship type IDs from the database.
  """
  def logistics_ship_ids do
    from(i in ItemType,
      where:
        i.group_name in ["Logistics Cruiser", "Logistics Frigate", "Force Auxiliary"] and
          i.is_ship == true and i.published == true,
      select: i.type_id
    )
    |> Repo.all()
  end

  @doc """
  Get electronic warfare ship type IDs from the database.
  """
  def ewar_ship_ids do
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
    |> Repo.all()
  end

  @doc """
  Check if a ship type ID is an interceptor.
  """
  def is_interceptor?(type_id) when is_integer(type_id) do
    case from(i in ItemType,
           where:
             i.type_id == ^type_id and i.group_name == "Interceptor" and
               i.is_ship == true and i.published == true
         )
         |> Repo.one() do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Check if a ship type ID is a logistics ship.
  """
  def logistics?(type_id) when is_integer(type_id) do
    case from(i in ItemType,
           where:
             i.type_id == ^type_id and
               i.group_name in ["Logistics Cruiser", "Logistics Frigate", "Force Auxiliary"] and
               i.is_ship == true and i.published == true
         )
         |> Repo.one() do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Check if a ship type ID is an EWAR ship.
  """
  def ewar?(type_id) when is_integer(type_id) do
    case from(i in ItemType,
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
         |> Repo.one() do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Get comprehensive ship attributes including DPS, EHP, and tactical data.

  Returns real calculated values from ship_attributes table.
  """
  def get_ship_attributes(type_id) when is_integer(type_id) do
    case Api.read(ShipAttributes, action: :get_by_type_id, type_id: type_id) do
      {:ok, [attributes]} -> {:ok, attributes}
      {:ok, []} -> {:error, :not_found}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Get ship DPS using real calculated values.

  Replaces hardcoded DPS values in fleet analysis.
  """
  def get_ship_dps(type_id) when is_integer(type_id) do
    case get_ship_attributes(type_id) do
      {:ok, attributes} ->
        dps = attributes.calculated_dps || 0.0
        {:ok, dps}

      {:error, :not_found} ->
        # Fallback: estimate DPS from ship classification
        estimate_dps_from_classification(type_id)

      error ->
        error
    end
  end

  @doc """
  Get ship EHP using real calculated values.

  Replaces hardcoded EHP values in fleet analysis.
  """
  def get_ship_ehp(type_id) when is_integer(type_id) do
    case get_ship_attributes(type_id) do
      {:ok, attributes} ->
        ehp = attributes.calculated_ehp || 0.0
        {:ok, ehp}

      {:error, :not_found} ->
        # Fallback: estimate EHP from ship classification
        estimate_ehp_from_classification(type_id)

      error ->
        error
    end
  end

  @doc """
  Get ship tactical role using database classification.

  Returns role like "dps", "logistics", "tackle", "ewar", etc.
  """
  def get_ship_role(type_id) when is_integer(type_id) do
    case get_ship_attributes(type_id) do
      {:ok, attributes} ->
        role = attributes.role_classification || "dps"
        {:ok, role}

      {:error, :not_found} ->
        # Fallback: determine role from group name
        case classify_ship_type(type_id) do
          :unknown -> {:error, :not_found}
          class -> {:ok, classify_role_from_class(class)}
        end

      error ->
        error
    end
  end

  @doc """
  Calculate fleet composition statistics using real ship data.

  Takes a map of ship_type_id => count and returns aggregate stats.
  """
  def calculate_fleet_stats(ship_composition) when is_map(ship_composition) do
    ship_data = get_ship_data_batch(Map.keys(ship_composition))

    total_dps = calculate_total_dps(ship_composition, ship_data)
    total_ehp = calculate_total_ehp(ship_composition, ship_data)
    role_distribution = calculate_role_distribution(ship_composition, ship_data)
    fleet_effectiveness = calculate_fleet_effectiveness(total_dps, total_ehp, role_distribution)

    %{
      total_ships: Enum.sum(Map.values(ship_composition)),
      total_dps: Float.round(total_dps, 1),
      total_ehp: Float.round(total_ehp, 0),
      average_dps_per_ship:
        if(map_size(ship_composition) > 0,
          do: Float.round(total_dps / Enum.sum(Map.values(ship_composition)), 1),
          else: 0.0
        ),
      role_distribution: role_distribution,
      effectiveness_score: fleet_effectiveness,
      composition_diversity: calculate_composition_diversity(ship_composition, ship_data)
    }
  end

  @doc """
  Get ships by role classification.
  """
  def get_ships_by_role(role) when is_binary(role) do
    case Api.read(ShipAttributes, action: :list_by_role, role_classification: role) do
      {:ok, ships} -> {:ok, ships}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Get top DPS ships for fleet composition optimization.
  """
  def get_high_dps_ships(min_dps \\ 500.0) do
    case Api.read(ShipAttributes, action: :high_dps_ships, min_dps: min_dps) do
      {:ok, ships} -> {:ok, ships}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Get tank-focused ships for fleet composition optimization.
  """
  def get_tank_ships(min_ehp \\ 50_000.0) do
    case Api.read(ShipAttributes, action: :tank_ships, min_ehp: min_ehp) do
      {:ok, ships} -> {:ok, ships}
      {:error, error} -> {:error, error}
    end
  end

  # Private helper functions

  defp estimate_dps_from_classification(type_id) do
    case classify_ship_type(type_id) do
      :frigate -> {:ok, 150.0}
      :destroyer -> {:ok, 250.0}
      :cruiser -> {:ok, 400.0}
      :battlecruiser -> {:ok, 600.0}
      :battleship -> {:ok, 800.0}
      :capital -> {:ok, 2000.0}
      :supercapital -> {:ok, 5000.0}
      _ -> {:ok, 200.0}
    end
  end

  defp estimate_ehp_from_classification(type_id) do
    case classify_ship_type(type_id) do
      :frigate -> {:ok, 3000.0}
      :destroyer -> {:ok, 5000.0}
      :cruiser -> {:ok, 12_000.0}
      :battlecruiser -> {:ok, 20_000.0}
      :battleship -> {:ok, 35_000.0}
      :capital -> {:ok, 200_000.0}
      :supercapital -> {:ok, 500_000.0}
      _ -> {:ok, 10_000.0}
    end
  end

  defp classify_role_from_class(class) do
    case class do
      :frigate -> "tackle"
      :destroyer -> "dps"
      :cruiser -> "dps"
      :battlecruiser -> "dps"
      :battleship -> "dps"
      :capital -> "support"
      :supercapital -> "dps"
      _ -> "dps"
    end
  end

  defp get_ship_data_batch(type_ids) do
    # Get ship attributes for multiple ships efficiently
    type_ids
    |> Enum.map(fn type_id ->
      case get_ship_attributes(type_id) do
        {:ok, attributes} -> {type_id, attributes}
        {:error, _} -> {type_id, nil}
      end
    end)
    |> Map.new()
  end

  defp calculate_total_dps(ship_composition, ship_data) do
    ship_composition
    |> Enum.reduce(0.0, fn {type_id, count}, acc ->
      case Map.get(ship_data, type_id) do
        nil ->
          # Fallback to estimated DPS
          {:ok, dps} = estimate_dps_from_classification(type_id)
          acc + dps * count

        attributes ->
          dps = attributes.calculated_dps || 0.0
          acc + dps * count
      end
    end)
  end

  defp calculate_total_ehp(ship_composition, ship_data) do
    ship_composition
    |> Enum.reduce(0.0, fn {type_id, count}, acc ->
      case Map.get(ship_data, type_id) do
        nil ->
          # Fallback to estimated EHP
          {:ok, ehp} = estimate_ehp_from_classification(type_id)
          acc + ehp * count

        attributes ->
          ehp = attributes.calculated_ehp || 0.0
          acc + ehp * count
      end
    end)
  end

  defp calculate_role_distribution(ship_composition, ship_data) do
    ship_composition
    |> Enum.reduce(%{}, fn {type_id, count}, acc ->
      role =
        case Map.get(ship_data, type_id) do
          nil -> classify_role_from_class(classify_ship_type(type_id))
          attributes -> attributes.role_classification || "dps"
        end

      Map.update(acc, role, count, &(&1 + count))
    end)
  end

  defp calculate_fleet_effectiveness(total_dps, total_ehp, role_distribution) do
    # Calculate fleet effectiveness based on balanced composition
    total_ships = Enum.sum(Map.values(role_distribution))

    if total_ships == 0 do
      0.0
    else
      # Base effectiveness from DPS/EHP ratio
      base_effectiveness = if total_ehp > 0, do: total_dps / (total_ehp / 1000), else: 0.0

      # Role balance bonus (reward balanced fleets)
      role_balance = calculate_role_balance_bonus(role_distribution, total_ships)

      # Final effectiveness (0.0 - 1.0 scale)
      effectiveness = min(base_effectiveness * role_balance / 100, 1.0)
      Float.round(effectiveness, 3)
    end
  end

  defp calculate_role_balance_bonus(role_distribution, _total_ships) do
    # Reward fleets with good role distribution
    role_count = map_size(role_distribution)

    cond do
      # Very balanced fleet
      role_count >= 4 -> 1.2
      # Good balance
      role_count == 3 -> 1.1
      # Some balance
      role_count == 2 -> 1.0
      # Mono-composition penalty
      true -> 0.8
    end
  end

  defp calculate_composition_diversity(ship_composition, _ship_data) do
    # Calculate Shannon diversity index for ship types
    total_ships = Enum.sum(Map.values(ship_composition))

    if total_ships == 0 do
      0.0
    else
      proportions = Map.values(ship_composition) |> Enum.map(&(&1 / total_ships))

      entropy =
        proportions
        |> Enum.map(fn p -> if p > 0, do: -p * :math.log2(p), else: 0 end)
        |> Enum.sum()

      # Normalize to 0-1 scale
      max_entropy = :math.log2(map_size(ship_composition))
      if max_entropy > 0, do: Float.round(entropy / max_entropy, 3), else: 0.0
    end
  end

  @doc """
  Get ship type information by type ID.

  Returns comprehensive ship information including name, group, and attributes.
  """
  def get_ship_type(type_id) when is_integer(type_id) do
    case from(i in ItemType,
           where: i.type_id == ^type_id and i.is_ship == true,
           select: %{
             type_id: i.type_id,
             type_name: i.type_name,
             group_name: i.group_name,
             mass: i.mass,
             volume: i.volume,
             capacity: i.capacity
           }
         )
         |> Repo.one() do
      nil ->
        {:error, :not_found}

      ship_info ->
        # Add classification to the info
        classification = classify_by_group_name(ship_info.group_name)
        info_with_class = Map.put(ship_info, :classification, classification)
        {:ok, info_with_class}
    end
  end

  def get_ship_type(_), do: {:error, :invalid_type_id}

  @doc """
  Get ship classification. Delegates to main StaticData module.
  """
  def get_ship_class(ship_identifier) do
    EveDmv.StaticData.get_ship_class(ship_identifier)
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
