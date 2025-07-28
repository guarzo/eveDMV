defmodule EveDmv.StaticData.ShipAttributeImporter do
  @moduledoc """
  Service for importing and calculating ship attributes from EVE SDE data.

  This service populates the ship_attributes table with calculated DPS, EHP,
  and tactical classifications derived from existing EVE item type data.

  Phase 1: Use basic ship data and estimates
  Phase 2: Import full dogma attributes when available
  """

  use GenServer
  require Logger
  require Ash.Query

  alias EveDmv.Api
  alias EveDmv.Eve.ItemType
  alias EveDmv.StaticData.{ShipAttributes, ShipTypes}

  import Ash.Expr

  @doc """
  Start the importer service.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Import ship attributes for all published ships.
  """
  def import_all_ship_attributes do
    GenServer.call(__MODULE__, :import_all, 30_000)
  end

  @doc """
  Import ship attributes with options.
  """
  def import_all(opts \\ []) do
    force = Keyword.get(opts, :force, false)
    limit = Keyword.get(opts, :limit, nil)

    GenServer.call(__MODULE__, {:import_all_with_options, force, limit}, 60_000)
  end

  @doc """
  Import attributes for a specific ship type.
  """
  def import_ship_attributes(type_id) do
    GenServer.call(__MODULE__, {:import_ship, type_id})
  end

  @doc """
  Recalculate all ship ratings and classifications.
  """
  def recalculate_ratings do
    GenServer.call(__MODULE__, :recalculate_ratings, 30_000)
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    Logger.info("ShipAttributeImporter started")
    {:ok, %{imported_count: 0, failed_count: 0}}
  end

  @impl GenServer
  def handle_call(:import_all, from, state) do
    handle_call({:import_all_with_options, false, nil}, from, state)
  end

  @impl GenServer
  def handle_call({:import_all_with_options, force, limit}, _from, state) do
    Logger.info("Starting bulk ship attribute import (force=#{force}, limit=#{inspect(limit)})")

    # Get all published ship types
    # Query for all ships
    query =
      ItemType
      |> Ash.Query.new()
      |> Ash.Query.filter(expr(is_ship == true and published == true))
      |> Ash.Query.select([:type_id, :type_name, :group_name, :category_name, :mass, :volume])

    # Apply limit if specified
    query =
      if limit do
        Ash.Query.limit(query, limit)
      else
        query
      end

    case Ash.read(query, domain: EveDmv.Api) do
      {:ok, ships} ->
        # Filter out existing attributes if not forcing
        ships_to_import =
          if force do
            ships
          else
            filter_existing_attributes(ships)
          end

        total_count = length(ships_to_import)
        Logger.info("Found #{total_count} ships to import")

        start_time = System.monotonic_time(:millisecond)
        {imported, failed} = import_ships_batch(ships_to_import)
        duration_ms = System.monotonic_time(:millisecond) - start_time

        result = %{
          total_ships: total_count,
          imported: imported,
          failed: failed,
          success_rate:
            if(total_count > 0, do: Float.round(imported / total_count * 100, 1), else: 0.0),
          duration_ms: duration_ms
        }

        Logger.info(
          "Ship attribute import complete: #{imported}/#{total_count} successful in #{duration_ms}ms"
        )

        {:reply, {:ok, result}, %{state | imported_count: imported, failed_count: failed}}

      {:error, error} ->
        Logger.error("Failed to query ship types: #{inspect(error)}")
        {:reply, {:error, :query_failed}, state}
    end
  end

  @impl GenServer
  def handle_call({:import_ship, type_id}, _from, state) do
    case import_single_ship(type_id) do
      :ok ->
        {:reply, :ok, %{state | imported_count: state.imported_count + 1}}

      error ->
        {:reply, error, %{state | failed_count: state.failed_count + 1}}
    end
  end

  @impl GenServer
  def handle_call(:recalculate_ratings, _from, state) do
    Logger.info("Recalculating ship performance ratings")

    case recalculate_all_ratings() do
      {:ok, count} ->
        Logger.info("Updated ratings for #{count} ships")
        {:reply, {:ok, count}, state}

      error ->
        Logger.error("Failed to recalculate ratings: #{inspect(error)}")
        {:reply, error, state}
    end
  end

  # Private functions

  defp filter_existing_attributes(ships) do
    # Get list of type_ids that already have attributes
    existing_query =
      ShipAttributes
      |> Ash.Query.new()
      |> Ash.Query.select([:type_id])

    case Ash.read(existing_query, domain: EveDmv.Api) do
      {:ok, existing_attributes} ->
        existing_type_ids = MapSet.new(existing_attributes, & &1.type_id)

        Enum.reject(ships, fn ship ->
          MapSet.member?(existing_type_ids, ship.type_id)
        end)

      {:error, _} ->
        # If we can't query existing, import all
        ships
    end
  end

  defp import_ships_batch(ships) do
    ships
    # Process in batches
    |> Enum.chunk_every(50)
    |> Enum.reduce({0, 0}, fn batch, {imported_acc, failed_acc} ->
      batch_results = Enum.map(batch, &import_single_ship_safe/1)

      imported = Enum.count(batch_results, &(&1 == :ok))
      failed = length(batch_results) - imported

      {imported_acc + imported, failed_acc + failed}
    end)
  end

  defp import_single_ship_safe(ship) do
    try do
      import_single_ship(ship.type_id)
    rescue
      error ->
        Logger.warning(
          "Failed to import ship #{ship.type_id} (#{ship.type_name}): #{inspect(error)}"
        )

        :error
    end
  end

  defp import_single_ship(target_type_id) when is_integer(target_type_id) do
    # Get ship basic info
    case ItemType.get_by_id(target_type_id) do
      {:ok, ship} ->
        attributes = calculate_ship_attributes(ship)
        create_or_update_attributes(attributes)

      {:error, :not_found} ->
        Logger.warning("Ship type #{target_type_id} not found")
        {:error, :not_found}

      {:error, error} ->
        Logger.error("Failed to query ship #{target_type_id}: #{inspect(error)}")
        {:error, :query_failed}
    end
  end

  defp import_single_ship(%{type_id: type_id}) do
    import_single_ship(type_id)
  end

  defp calculate_ship_attributes(ship) do
    # Phase 1: Basic attribute calculation using available data
    # TODO: Replace with full dogma calculation when SDE import is complete

    size_class = determine_size_class(ship.group_name)
    role_classification = determine_role_classification(ship.group_name, ship.type_name)
    tactical_category = determine_tactical_category(ship.group_name, role_classification)

    # Estimate base stats from ship class and mass
    estimated_stats = estimate_ship_stats(ship, size_class, role_classification)

    %{
      type_id: ship.type_id,
      shield_hp: estimated_stats.shield_hp,
      armor_hp: estimated_stats.armor_hp,
      structure_hp: estimated_stats.structure_hp,

      # Basic resistance estimates by ship type
      shield_em_resist: estimated_stats.shield_resists.em,
      shield_thermal_resist: estimated_stats.shield_resists.thermal,
      shield_kinetic_resist: estimated_stats.shield_resists.kinetic,
      shield_explosive_resist: estimated_stats.shield_resists.explosive,
      armor_em_resist: estimated_stats.armor_resists.em,
      armor_thermal_resist: estimated_stats.armor_resists.thermal,
      armor_kinetic_resist: estimated_stats.armor_resists.kinetic,
      armor_explosive_resist: estimated_stats.armor_resists.explosive,
      calculated_dps: estimated_stats.dps,
      calculated_ehp: estimated_stats.ehp,
      calculated_ehp_uniform: estimated_stats.ehp_uniform,
      role_classification: role_classification,
      size_class: size_class,
      tactical_category: tactical_category,
      damage_rating: estimated_stats.damage_rating,
      tank_rating: estimated_stats.tank_rating,
      speed_rating: estimated_stats.speed_rating,
      utility_rating: estimated_stats.utility_rating,
      data_source: "phase1_estimate",
      confidence_score: estimated_stats.confidence,
      last_updated: DateTime.utc_now()
    }
  end

  defp determine_size_class(group_name) do
    case group_name do
      name
      when name in [
             "Frigate",
             "Assault Frigate",
             "Covert Ops",
             "Electronic Attack Frigate",
             "Interceptor",
             "Logistics Frigate",
             "Expedition Frigate",
             "Stealth Bomber"
           ] ->
        "frigate"

      name when name in ["Destroyer", "Interdictor", "Command Destroyer", "Tactical Destroyer"] ->
        "destroyer"

      name
      when name in [
             "Cruiser",
             "Heavy Assault Cruiser",
             "Heavy Interdiction Cruiser",
             "Logistics Cruiser",
             "Recon Ship",
             "Strategic Cruiser",
             "Combat Recon Ship",
             "Force Recon Ship"
           ] ->
        "cruiser"

      name
      when name in [
             "Battlecruiser",
             "Combat Battlecruiser",
             "Attack Battlecruiser",
             "Command Ship"
           ] ->
        "battlecruiser"

      name when name in ["Battleship", "Black Ops", "Marauder"] ->
        "battleship"

      name
      when name in ["Carrier", "Dreadnought", "Force Auxiliary", "Capital Industrial Ship"] ->
        "capital"

      name when name in ["Supercarrier", "Titan"] ->
        "supercapital"

      _ ->
        "unknown"
    end
  end

  defp determine_role_classification(group_name, type_name) do
    # Determine primary tactical role
    cond do
      group_name in ["Logistics Cruiser", "Logistics Frigate", "Force Auxiliary"] ->
        "logistics"

      group_name in ["Electronic Attack Frigate", "Combat Recon Ship", "Force Recon Ship"] ->
        "ewar"

      group_name in ["Interceptor", "Interdictor", "Heavy Interdiction Cruiser"] ->
        "tackle"

      group_name in ["Assault Frigate", "Heavy Assault Cruiser", "Attack Battlecruiser"] ->
        "dps"

      group_name in ["Command Ship", "Command Destroyer"] ->
        "support"

      group_name in ["Marauder", "Black Ops"] ->
        "dps"

      group_name in ["Carrier", "Supercarrier"] ->
        "support"

      group_name in ["Dreadnought", "Titan"] ->
        "dps"

      String.contains?(type_name, ["Guardian", "Basilisk", "Scimitar", "Oneiros"]) ->
        "logistics"

      # Default for most combat ships
      true ->
        "dps"
    end
  end

  defp determine_tactical_category(group_name, role) do
    case {group_name, role} do
      {_, "logistics"} -> "logistics"
      {_, "ewar"} -> "ewar"
      {_, "tackle"} -> "tackler"
      {"Stealth Bomber", _} -> "bomber"
      {"Interceptor", _} -> "tackler"
      {"Assault Frigate", _} -> "brawler"
      {"Heavy Assault Cruiser", _} -> "brawler"
      {"Battleship", _} -> "brawler"
      {"Battlecruiser", _} -> "brawler"
      {"Strategic Cruiser", _} -> "kiter"
      {"Tactical Destroyer", _} -> "kiter"
      {"Covert Ops", _} -> "ewar"
      # Default
      _ -> "brawler"
    end
  end

  defp estimate_ship_stats(ship, size_class, role) do
    # Phase 1: Basic estimates based on ship class and role
    # TODO: Replace with real dogma calculations

    base_stats = get_base_stats_by_size(size_class)
    role_multipliers = get_role_multipliers(role)

    # Apply mass scaling if available
    mass_multiplier =
      if ship.mass do
        calculate_mass_multiplier(ship.mass, size_class)
      else
        1.0
      end

    # Calculate final stats
    shield_hp = trunc(base_stats.shield_hp * mass_multiplier)
    armor_hp = trunc(base_stats.armor_hp * mass_multiplier)
    structure_hp = trunc(base_stats.structure_hp * mass_multiplier)

    total_hp = shield_hp + armor_hp + structure_hp

    # Resistance estimates by race/type (simplified)
    resistances = get_resistance_estimates(ship.group_name)

    # Calculate EHP
    ehp = calculate_ehp(shield_hp, armor_hp, structure_hp, resistances)
    ehp_uniform = calculate_ehp_uniform(total_hp, resistances)

    # DPS estimates
    dps = base_stats.dps * role_multipliers.damage * mass_multiplier

    %{
      shield_hp: shield_hp,
      armor_hp: armor_hp,
      structure_hp: structure_hp,
      shield_resists: resistances.shield,
      armor_resists: resistances.armor,
      dps: Float.round(dps, 1),
      ehp: Float.round(ehp, 0),
      ehp_uniform: Float.round(ehp_uniform, 0),
      damage_rating: calculate_damage_rating(dps, size_class),
      tank_rating: calculate_tank_rating(ehp, size_class),
      speed_rating: estimate_speed_rating(size_class, ship.mass),
      utility_rating: role_multipliers.utility,
      # Phase 1 estimates are moderate confidence
      confidence: 0.6
    }
  end

  defp get_base_stats_by_size(size_class) do
    case size_class do
      "frigate" -> %{shield_hp: 800, armor_hp: 600, structure_hp: 400, dps: 150}
      "destroyer" -> %{shield_hp: 1200, armor_hp: 900, structure_hp: 600, dps: 250}
      "cruiser" -> %{shield_hp: 2500, armor_hp: 2000, structure_hp: 1500, dps: 400}
      "battlecruiser" -> %{shield_hp: 4000, armor_hp: 3500, structure_hp: 3000, dps: 600}
      "battleship" -> %{shield_hp: 8000, armor_hp: 7000, structure_hp: 6000, dps: 800}
      "capital" -> %{shield_hp: 50000, armor_hp: 45000, structure_hp: 40000, dps: 2000}
      "supercapital" -> %{shield_hp: 150_000, armor_hp: 120_000, structure_hp: 100_000, dps: 5000}
      _ -> %{shield_hp: 1000, armor_hp: 1000, structure_hp: 1000, dps: 200}
    end
  end

  defp get_role_multipliers(role) do
    case role do
      "dps" -> %{damage: 1.2, tank: 0.9, utility: 0.7}
      "tank" -> %{damage: 0.7, tank: 1.5, utility: 0.8}
      "logistics" -> %{damage: 0.3, tank: 1.1, utility: 1.5}
      "ewar" -> %{damage: 0.5, tank: 0.8, utility: 1.3}
      "tackle" -> %{damage: 0.8, tank: 0.7, utility: 1.2}
      "support" -> %{damage: 0.9, tank: 1.1, utility: 1.2}
      _ -> %{damage: 1.0, tank: 1.0, utility: 1.0}
    end
  end

  defp calculate_mass_multiplier(mass, size_class) when is_number(mass) do
    # Scale stats based on mass relative to size class average
    avg_mass =
      case size_class do
        "frigate" -> 1_500_000
        "destroyer" -> 2_500_000
        "cruiser" -> 12_000_000
        "battlecruiser" -> 16_000_000
        "battleship" -> 100_000_000
        "capital" -> 1_200_000_000
        "supercapital" -> 2_500_000_000
        _ -> 10_000_000
      end

    ratio = mass / avg_mass
    # Clamp multiplier to reasonable bounds
    min(max(ratio, 0.5), 2.0)
  end

  defp calculate_mass_multiplier(_, _), do: 1.0

  defp get_resistance_estimates(group_name) do
    # Basic resistance estimates by group
    # TODO: Replace with real dogma resistances
    case group_name do
      name when name in ["Assault Frigate", "Heavy Assault Cruiser"] ->
        # Assault ships have better resistances
        %{
          shield: %{em: 0.2, thermal: 0.4, kinetic: 0.5, explosive: 0.1},
          armor: %{em: 0.5, thermal: 0.2, kinetic: 0.3, explosive: 0.1}
        }

      name when name in ["Marauder", "Black Ops"] ->
        # T2 battleships have strong resistances
        %{
          shield: %{em: 0.2, thermal: 0.4, kinetic: 0.5, explosive: 0.1},
          armor: %{em: 0.6, thermal: 0.3, kinetic: 0.4, explosive: 0.1}
        }

      _ ->
        # Standard resistances
        %{
          shield: %{em: 0.0, thermal: 0.2, kinetic: 0.4, explosive: 0.0},
          armor: %{em: 0.5, thermal: 0.2, kinetic: 0.25, explosive: 0.1}
        }
    end
  end

  defp calculate_ehp(shield_hp, armor_hp, structure_hp, resistances) do
    # Calculate EHP against worst-case damage type
    # Explosive usually worst for shield
    shield_ehp = shield_hp / (1 - resistances.shield.explosive)
    # EM usually worst for armor
    armor_ehp = armor_hp / (1 - resistances.armor.em)
    # No base resistances on structure
    structure_ehp = structure_hp

    shield_ehp + armor_ehp + structure_ehp
  end

  defp calculate_ehp_uniform(total_hp, resistances) do
    # Calculate EHP against uniform damage distribution
    avg_shield_resist =
      (resistances.shield.em + resistances.shield.thermal +
         resistances.shield.kinetic + resistances.shield.explosive) / 4

    avg_armor_resist =
      (resistances.armor.em + resistances.armor.thermal +
         resistances.armor.kinetic + resistances.armor.explosive) / 4

    # Simplified uniform EHP calculation
    total_hp / (1 - (avg_shield_resist + avg_armor_resist) / 2)
  end

  defp calculate_damage_rating(dps, size_class) do
    # Rate damage relative to size class
    max_dps =
      case size_class do
        "frigate" -> 300
        "destroyer" -> 500
        "cruiser" -> 800
        "battlecruiser" -> 1200
        "battleship" -> 1500
        "capital" -> 5000
        "supercapital" -> 10000
        _ -> 1000
      end

    min(dps / max_dps, 1.0)
  end

  defp calculate_tank_rating(ehp, size_class) do
    # Rate tank relative to size class
    max_ehp =
      case size_class do
        "frigate" -> 5000
        "destroyer" -> 8000
        "cruiser" -> 15000
        "battlecruiser" -> 25000
        "battleship" -> 40000
        "capital" -> 200_000
        "supercapital" -> 500_000
        _ -> 20000
      end

    min(ehp / max_ehp, 1.0)
  end

  defp estimate_speed_rating(size_class, mass) do
    # Estimate speed rating based on size and mass
    base_rating =
      case size_class do
        "frigate" -> 0.9
        "destroyer" -> 0.8
        "cruiser" -> 0.6
        "battlecruiser" -> 0.4
        "battleship" -> 0.3
        "capital" -> 0.1
        "supercapital" -> 0.05
        _ -> 0.5
      end

    # Adjust for mass if available
    if mass do
      mass_factor = min(max(50_000_000 / mass, 0.1), 2.0)
      min(base_rating * mass_factor, 1.0)
    else
      base_rating
    end
  end

  defp create_or_update_attributes(attributes) do
    case Ash.create(ShipAttributes, attributes,
           domain: EveDmv.Api,
           upsert?: true,
           upsert_identity: :type_id
         ) do
      {:ok, _ship_attributes} ->
        :ok

      {:error, error} ->
        Logger.error(
          "Failed to create ship attributes for type #{attributes.type_id}: #{inspect(error)}"
        )

        {:error, :create_failed}
    end
  end

  defp recalculate_all_ratings do
    # Recalculate relative ratings across all ships
    # This normalizes ratings to ensure good distribution

    attributes_query =
      ShipAttributes
      |> Ash.Query.select([:type_id, :calculated_dps, :calculated_ehp, :size_class])

    case Ash.read(attributes_query, domain: EveDmv.Api) do
      {:ok, all_attributes} ->
        # Group by size class and recalculate ratings
        grouped = Enum.group_by(all_attributes, & &1.size_class)

        updates =
          Enum.flat_map(grouped, fn {size_class, ships} ->
            recalculate_ratings_for_size_class(ships, size_class)
          end)

        # Apply updates
        update_count = apply_rating_updates(updates)
        {:ok, update_count}

      {:error, error} ->
        {:error, error}
    end
  end

  defp recalculate_ratings_for_size_class(ships, _size_class) do
    # Find max values in this size class
    max_dps = ships |> Enum.map(&(&1.calculated_dps || 0)) |> Enum.max(fn -> 1 end)
    max_ehp = ships |> Enum.map(&(&1.calculated_ehp || 0)) |> Enum.max(fn -> 1 end)

    Enum.map(ships, fn ship ->
      damage_rating = if max_dps > 0, do: (ship.calculated_dps || 0) / max_dps, else: 0.0
      tank_rating = if max_ehp > 0, do: (ship.calculated_ehp || 0) / max_ehp, else: 0.0

      %{
        type_id: ship.type_id,
        damage_rating: Float.round(damage_rating, 3),
        tank_rating: Float.round(tank_rating, 3)
      }
    end)
  end

  defp apply_rating_updates(updates) do
    # Apply rating updates in batches
    updates
    |> Enum.chunk_every(50)
    |> Enum.reduce(0, fn batch, acc ->
      batch_count =
        Enum.reduce(batch, 0, fn update, count ->
          case Ash.update(ShipAttributes, update, domain: EveDmv.Api, action: :update) do
            {:ok, _} -> count + 1
            {:error, _} -> count
          end
        end)

      acc + batch_count
    end)
  end
end
