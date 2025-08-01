defmodule EveDmv.StaticData.ShipAttributesService do
  @moduledoc """
  Service for retrieving ship attributes from static data.

  Provides convenient access to ship statistics for replacing hardcoded values
  in battle analysis and fleet composition modules.
  """

  alias EveDmv.StaticData.ShipAttributes
  import Ash.Query
  require Logger

  @doc """
  Get ship attributes by type ID.

  Returns ship attributes from the database or calculates defaults if not found.
  """
  def get_ship_attributes(type_id) when is_integer(type_id) do
    case ShipAttributes.get_by_type_id!(type_id) do
      nil ->
        # If no attributes found, try to get basic ship info and calculate defaults
        case get_basic_ship_info(type_id) do
          {:ok, ship_info} -> calculate_default_attributes(ship_info)
          error -> error
        end

      attributes ->
        {:ok, attributes}
    end
  rescue
    Ash.Error.Query.NotFound ->
      # Try fallback calculation
      case get_basic_ship_info(type_id) do
        {:ok, ship_info} -> calculate_default_attributes(ship_info)
        error -> error
      end
  end

  @doc """
  Get ship EHP (Effective Hit Points).
  """
  def get_ship_ehp(type_id) when is_integer(type_id) do
    case get_ship_attributes(type_id) do
      {:ok, attrs} when not is_nil(attrs.calculated_ehp) ->
        {:ok, attrs.calculated_ehp}

      {:ok, attrs} ->
        # Calculate EHP from individual HP pools and resistances
        calculate_ehp_from_attributes(attrs)

      error ->
        error
    end
  end

  @doc """
  Get ship DPS potential.
  """
  def get_ship_dps(type_id) when is_integer(type_id) do
    case get_ship_attributes(type_id) do
      {:ok, attrs} when not is_nil(attrs.calculated_dps) ->
        {:ok, attrs.calculated_dps}

      {:ok, attrs} ->
        # Use damage rating and size class to estimate DPS
        estimate_dps_from_attributes(attrs)

      error ->
        error
    end
  end

  @doc """
  Get ship classification (frigate, cruiser, etc).
  """
  def get_ship_class(type_id) when is_integer(type_id) do
    case get_ship_attributes(type_id) do
      {:ok, attrs} when not is_nil(attrs.size_class) ->
        {:ok, String.to_existing_atom(attrs.size_class)}

      {:ok, _} ->
        # Try to get class from item type data
        get_ship_class_from_item_type(type_id)

      error ->
        error
    end
  end

  @doc """
  Get ship tactical role (dps, logistics, ewar, etc).
  """
  def get_ship_role(type_id) when is_integer(type_id) do
    case get_ship_attributes(type_id) do
      {:ok, attrs} when not is_nil(attrs.role_classification) ->
        {:ok, String.to_existing_atom(attrs.role_classification)}

      {:ok, _} ->
        # Try to determine role from ship name or group
        estimate_ship_role(type_id)

      error ->
        error
    end
  end

  @doc """
  Get comprehensive combat attributes for a ship.
  """
  def get_combat_attributes(type_id) when is_integer(type_id) do
    with {:ok, attrs} <- get_ship_attributes(type_id),
         {:ok, ehp} <- get_ship_ehp(type_id),
         {:ok, dps} <- get_ship_dps(type_id),
         {:ok, ship_class} <- get_ship_class(type_id),
         {:ok, role} <- get_ship_role(type_id) do
      {:ok,
       %{
         type_id: type_id,
         ehp: ehp,
         dps: dps,
         ship_class: ship_class,
         role: role,
         attributes: attrs
       }}
    end
  end

  @doc """
  Get tank type preference (shield or armor) for a ship.
  """
  def get_tank_type(type_id) when is_integer(type_id) do
    case get_ship_attributes(type_id) do
      {:ok, attrs} ->
        shield_hp = attrs.shield_hp || 0
        armor_hp = attrs.armor_hp || 0

        cond do
          shield_hp > armor_hp * 1.5 -> {:ok, :shield}
          armor_hp > shield_hp * 1.5 -> {:ok, :armor}
          true -> {:ok, :hybrid}
        end

      error ->
        error
    end
  end

  # Private helper functions

  defp get_basic_ship_info(type_id) do
    # Try to get basic info from eve_item_types table
    import Ecto.Query
    alias EveDmv.Repo

    query =
      from(t in "eve_item_types",
        where: t.type_id == ^type_id,
        select: %{
          type_id: t.type_id,
          type_name: t.type_name,
          group_id: t.group_id,
          category_id: t.category_id,
          mass: t.mass,
          volume: t.volume
        }
      )

    case Repo.one(query) do
      nil -> {:error, :ship_not_found}
      ship_info -> {:ok, ship_info}
    end
  end

  defp calculate_default_attributes(ship_info) do
    ship_class = classify_ship_by_group(ship_info.group_id)

    # Default HP values by ship class
    {shield_hp, armor_hp, structure_hp} =
      case ship_class do
        :frigate -> {800, 600, 400}
        :destroyer -> {1_200, 800, 600}
        :cruiser -> {2_500, 2_000, 1_500}
        :battlecruiser -> {4_000, 3_500, 2_500}
        :battleship -> {6_000, 5_500, 4_000}
        :capital -> {50_000, 45_000, 35_000}
        :supercapital -> {200_000, 180_000, 150_000}
        _ -> {1_000, 800, 600}
      end

    # Default resistances (base ship resistances)
    # EM, Thermal, Kinetic, Explosive
    base_shield_resists = [0.0, 0.20, 0.40, 0.50]
    base_armor_resists = [0.50, 0.35, 0.25, 0.10]

    # Estimate DPS and role
    estimated_dps =
      case ship_class do
        :frigate -> 150
        :destroyer -> 250
        :cruiser -> 400
        :battlecruiser -> 600
        :battleship -> 800
        :capital -> 2_000
        :supercapital -> 5_000
        _ -> 200
      end

    attributes = %{
      type_id: ship_info.type_id,
      shield_hp: shield_hp,
      armor_hp: armor_hp,
      structure_hp: structure_hp,
      shield_em_resist: Enum.at(base_shield_resists, 0),
      shield_thermal_resist: Enum.at(base_shield_resists, 1),
      shield_kinetic_resist: Enum.at(base_shield_resists, 2),
      shield_explosive_resist: Enum.at(base_shield_resists, 3),
      armor_em_resist: Enum.at(base_armor_resists, 0),
      armor_thermal_resist: Enum.at(base_armor_resists, 1),
      armor_kinetic_resist: Enum.at(base_armor_resists, 2),
      armor_explosive_resist: Enum.at(base_armor_resists, 3),
      calculated_dps: estimated_dps,
      # Will be calculated
      calculated_ehp: nil,
      size_class: Atom.to_string(ship_class),
      # Default role
      role_classification: "dps",
      data_source: "calculated_default",
      # Low confidence for calculated values
      confidence_score: 0.3
    }

    # Calculate EHP
    ehp =
      calculate_ehp_from_hp_and_resists(
        shield_hp,
        armor_hp,
        structure_hp,
        base_shield_resists,
        base_armor_resists
      )

    {:ok, Map.put(attributes, :calculated_ehp, ehp)}
  end

  defp calculate_ehp_from_attributes(attrs) do
    shield_hp = attrs.shield_hp || 0
    armor_hp = attrs.armor_hp || 0
    structure_hp = attrs.structure_hp || 0

    shield_resists = [
      attrs.shield_em_resist || 0.0,
      attrs.shield_thermal_resist || 0.0,
      attrs.shield_kinetic_resist || 0.0,
      attrs.shield_explosive_resist || 0.0
    ]

    armor_resists = [
      attrs.armor_em_resist || 0.0,
      attrs.armor_thermal_resist || 0.0,
      attrs.armor_kinetic_resist || 0.0,
      attrs.armor_explosive_resist || 0.0
    ]

    ehp =
      calculate_ehp_from_hp_and_resists(
        shield_hp,
        armor_hp,
        structure_hp,
        shield_resists,
        armor_resists
      )

    {:ok, ehp}
  end

  defp calculate_ehp_from_hp_and_resists(
         shield_hp,
         armor_hp,
         structure_hp,
         shield_resists,
         armor_resists
       ) do
    # Use worst-case resistance for EHP calculation
    worst_shield_resist = Enum.min(shield_resists)
    worst_armor_resist = Enum.min(armor_resists)

    shield_ehp =
      if worst_shield_resist < 1.0 do
        shield_hp / (1.0 - worst_shield_resist)
      else
        shield_hp
      end

    armor_ehp =
      if worst_armor_resist < 1.0 do
        armor_hp / (1.0 - worst_armor_resist)
      else
        armor_hp
      end

    # Structure has no resistances
    total_ehp = shield_ehp + armor_ehp + structure_hp
    round(total_ehp)
  end

  defp estimate_dps_from_attributes(attrs) do
    # Calculate DPS based on ship class and role rather than hardcoded values
    base_dps = calculate_base_dps_by_class_and_role(attrs.size_class, attrs.role_classification)
    damage_rating = attrs.damage_rating || 0.5

    # Scale base DPS by damage rating and bonuses
    role_multiplier = get_role_damage_multiplier(attrs.role_classification)
    estimated_dps = base_dps * (0.8 + damage_rating * 0.4) * role_multiplier

    {:ok, round(estimated_dps)}
  end

  defp get_ship_class_from_item_type(type_id) do
    case get_basic_ship_info(type_id) do
      {:ok, ship_info} ->
        ship_class = classify_ship_by_group(ship_info.group_id)
        {:ok, ship_class}

      error ->
        error
    end
  end

  defp classify_ship_by_group(group_id) when is_integer(group_id) do
    # Map group IDs to ship classes (same as in original plan)
    case group_id do
      # Frigates
      id when id in [25, 237, 324, 830, 831, 893, 1283] -> :frigate
      # Destroyers
      id when id in [420, 541, 1305] -> :destroyer
      # Cruisers
      id when id in [26, 358, 833, 832, 894, 906, 963] -> :cruiser
      # Battlecruisers
      id when id in [419, 540] -> :battlecruiser
      # Battleships
      id when id in [27, 898, 900] -> :battleship
      # Capitals
      id when id in [485, 547, 902, 883] -> :capital
      # Supercapitals
      id when id in [659, 30] -> :supercapital
      # Default
      _ -> :unknown
    end
  end

  defp estimate_ship_role(_type_id) do
    # For now, default to DPS role
    # In the future, this could analyze ship name, bonuses, etc.
    {:ok, :dps}
  end

  defp calculate_base_dps_by_class_and_role(size_class, role) when is_binary(size_class) do
    # More realistic DPS calculations based on typical weapon configurations
    base_dps =
      case size_class do
        "frigate" ->
          # T1 frigates: 1-2 small weapons, ~80-120 DPS
          # T2 frigates: specialized roles, 100-180 DPS
          100

        "destroyer" ->
          # 6-8 small weapons, good tracking, ~180-250 DPS
          200

        "cruiser" ->
          # 4-6 medium weapons, ~300-450 DPS
          350

        "battlecruiser" ->
          # 6-8 large weapons or many mediums, ~500-700 DPS
          600

        "battleship" ->
          # 6-8 large weapons, ~700-1000 DPS
          800

        "capital" ->
          # Capital weapons, ~2000-4000 DPS
          3000

        "supercapital" ->
          # Multiple capital weapons, 8000+ DPS
          12000

        _ ->
          # Default for unknown classes
          120
      end

    # Adjust for role specialization
    case role do
      "dps" -> base_dps
      "attack" -> base_dps
      # Assault ships get damage bonus
      "assault" -> round(base_dps * 1.1)
      # Logistics ships have minimal weapons
      "logistics" -> round(base_dps * 0.2)
      # EWAR ships sacrifice damage for utility
      "ewar" -> round(base_dps * 0.4)
      # Tackle ships focus on speed/point
      "tackle" -> round(base_dps * 0.6)
      # Support ships have reduced damage
      "support" -> round(base_dps * 0.8)
      # Haulers have minimal weapons
      "transport" -> round(base_dps * 0.3)
      _ -> base_dps
    end
  end

  defp get_role_damage_multiplier(role) when is_binary(role) do
    # Ship role bonuses (many ships get role bonuses to damage)
    case role do
      "dps" -> 1.0
      "attack" -> 1.0
      # HACs and AFs get damage bonuses
      "assault" -> 1.15
      # Logistics ships focus on reps
      "logistics" -> 0.25
      # EWAR ships sacrifice damage
      "ewar" -> 0.4
      # Interceptors/dictors moderate damage
      "tackle" -> 0.7
      # Command ships still do decent damage
      "support" -> 0.8
      # Haulers minimal combat capability
      "transport" -> 0.3
      _ -> 1.0
    end
  end
end
