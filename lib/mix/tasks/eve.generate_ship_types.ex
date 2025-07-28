defmodule Mix.Tasks.Eve.GenerateShipTypes do
  @moduledoc """
  Generates ship type classifications based on actual EVE SDE data.

  ## Usage

      mix eve.generate_ship_types
  """

  @shortdoc "Generate ship type classifications from EVE static data"

  use Mix.Task
  import Ecto.Query
  alias EveDmv.Repo
  alias EveDmv.Eve.ItemType

  @group_mappings %{
    # Frigates
    "Frigate" => :frigate,
    "Assault Frigate" => :frigate,
    "Covert Ops" => :frigate,
    "Electronic Attack Frigate" => :frigate,
    "Interceptor" => :frigate,
    "Logistics Frigate" => :frigate,
    "Expedition Frigate" => :frigate,

    # Destroyers
    "Destroyer" => :destroyer,
    "Interdictor" => :destroyer,
    "Command Destroyer" => :destroyer,
    "Tactical Destroyer" => :destroyer,

    # Cruisers
    "Cruiser" => :cruiser,
    "Heavy Assault Cruiser" => :cruiser,
    "Heavy Interdiction Cruiser" => :cruiser,
    "Logistics Cruiser" => :cruiser,
    "Recon Ship" => :cruiser,
    "Strategic Cruiser" => :cruiser,
    "Combat Recon Ship" => :cruiser,
    "Force Recon Ship" => :cruiser,

    # Battlecruisers
    "Battlecruiser" => :battlecruiser,
    "Combat Battlecruiser" => :battlecruiser,
    "Attack Battlecruiser" => :battlecruiser,
    "Command Ship" => :battlecruiser,

    # Battleships
    "Battleship" => :battleship,
    "Black Ops" => :battleship,
    "Marauder" => :battleship,

    # Capitals
    "Carrier" => :capital,
    "Dreadnought" => :capital,
    "Force Auxiliary" => :capital,
    "Capital Industrial Ship" => :capital,

    # Supercapitals
    "Supercarrier" => :supercapital,
    "Titan" => :supercapital,

    # Industrial
    "Industrial" => :industrial,
    "Transport Ship" => :industrial,
    "Blockade Runner" => :industrial,
    "Deep Space Transport" => :industrial,
    "Industrial Command Ship" => :industrial,
    "Freighter" => :industrial,
    "Jump Freighter" => :industrial,

    # Mining
    "Mining Barge" => :mining,
    "Exhumer" => :mining
  }

  def run(_args) do
    Mix.Task.run("app.start")

    Mix.shell().info("Analyzing ship types from EVE static data...")

    # Get all ship groups
    groups =
      ItemType
      |> where([i], i.is_ship == true and i.published == true)
      |> distinct([i], i.group_name)
      |> select([i], {i.group_id, i.group_name})
      |> order_by([i], i.group_name)
      |> Repo.all()

    Mix.shell().info("Found #{length(groups)} ship groups")

    # Build classification maps
    classifications =
      Enum.reduce(groups, %{}, fn {group_id, group_name}, acc ->
        if class = @group_mappings[group_name] do
          ship_ids =
            ItemType
            |> where([i], i.group_id == ^group_id and i.is_ship == true and i.published == true)
            |> select([i], i.type_id)
            |> Repo.all()

          Mix.shell().info("  #{group_name}: #{length(ship_ids)} ships")

          Map.update(acc, class, ship_ids, &(&1 ++ ship_ids))
        else
          acc
        end
      end)

    # Get specific role ships
    interceptor_ids = get_ships_by_group_name("Interceptor")
    logistics_cruiser_ids = get_ships_by_group_name("Logistics Cruiser")
    logistics_frigate_ids = get_ships_by_group_name("Logistics Frigate")
    ewar_frigate_ids = get_ships_by_group_name("Electronic Attack Frigate")

    recon_ids =
      get_ships_by_group_name("Recon Ship") ++
        get_ships_by_group_name("Combat Recon Ship") ++
        get_ships_by_group_name("Force Recon Ship")

    logistics_ids = logistics_cruiser_ids ++ logistics_frigate_ids
    ewar_ids = ewar_frigate_ids ++ recon_ids

    # Generate the new module
    generate_module(classifications, interceptor_ids, logistics_ids, ewar_ids)

    Mix.shell().info("Successfully generated ship_types.ex with real EVE data!")
  end

  defp get_ships_by_group_name(group_name) do
    ItemType
    |> where([i], i.group_name == ^group_name and i.is_ship == true and i.published == true)
    |> select([i], i.type_id)
    |> Repo.all()
  end

  defp generate_module(classifications, interceptor_ids, logistics_ids, ewar_ids) do
    content = """
    defmodule EveDmv.StaticData.ShipTypes do
      @moduledoc \"\"\"
      Ship type classification using real EVE static data.

      This module provides ship type IDs and classifications based on
      actual EVE Online static data export (SDE).

      Last generated: #{DateTime.utc_now() |> DateTime.to_string()}
      \"\"\"

      # Ship type IDs by classification
      # Generated from EVE SDE data

      @frigate_ids #{inspect(Enum.sort(classifications[:frigate] || []))}

      @destroyer_ids #{inspect(Enum.sort(classifications[:destroyer] || []))}

      @cruiser_ids #{inspect(Enum.sort(classifications[:cruiser] || []))}

      @battlecruiser_ids #{inspect(Enum.sort(classifications[:battlecruiser] || []))}

      @battleship_ids #{inspect(Enum.sort(classifications[:battleship] || []))}

      @capital_ids #{inspect(Enum.sort(classifications[:capital] || []))}

      @supercapital_ids #{inspect(Enum.sort(classifications[:supercapital] || []))}

      @industrial_ids #{inspect(Enum.sort(classifications[:industrial] || []))}

      @mining_ids #{inspect(Enum.sort(classifications[:mining] || []))}

      # Specific role ships
      @interceptor_ids #{inspect(Enum.sort(interceptor_ids))}

      @logistics_ids #{inspect(Enum.sort(logistics_ids))}

      @ewar_ids #{inspect(Enum.sort(ewar_ids))}

      @doc \"\"\"
      Get all ship type IDs by class.
      \"\"\"
      def ship_type_ids do
        %{
          frigate: @frigate_ids,
          destroyer: @destroyer_ids,
          cruiser: @cruiser_ids,
          battlecruiser: @battlecruiser_ids,
          battleship: @battleship_ids,
          capital: @capital_ids,
          supercapital: @supercapital_ids,
          industrial: @industrial_ids,
          mining: @mining_ids
        }
      end

      @doc \"\"\"
      Classify a ship by its type ID.

      Returns the ship class as an atom, or :unknown if not found.
      \"\"\"
      def classify_ship_type(type_id) when is_integer(type_id) do
        cond do
          type_id in @frigate_ids -> :frigate
          type_id in @destroyer_ids -> :destroyer
          type_id in @cruiser_ids -> :cruiser
          type_id in @battlecruiser_ids -> :battlecruiser
          type_id in @battleship_ids -> :battleship
          type_id in @capital_ids -> :capital
          type_id in @supercapital_ids -> :supercapital
          type_id in @industrial_ids -> :industrial
          type_id in @mining_ids -> :mining
          true -> :unknown
        end
      end

      def classify_ship_type(_), do: :unknown

      @doc \"\"\"
      Check if a ship type ID belongs to a specific class.
      \"\"\"
      def is_ship_class?(type_id, :frigate), do: type_id in @frigate_ids
      def is_ship_class?(type_id, :destroyer), do: type_id in @destroyer_ids
      def is_ship_class?(type_id, :cruiser), do: type_id in @cruiser_ids
      def is_ship_class?(type_id, :battlecruiser), do: type_id in @battlecruiser_ids
      def is_ship_class?(type_id, :battleship), do: type_id in @battleship_ids
      def is_ship_class?(type_id, :capital), do: type_id in @capital_ids
      def is_ship_class?(type_id, :supercapital), do: type_id in @supercapital_ids
      def is_ship_class?(type_id, :industrial), do: type_id in @industrial_ids
      def is_ship_class?(type_id, :mining), do: type_id in @mining_ids
      def is_ship_class?(_, _), do: false

      @doc \"\"\"
      Get all ship type IDs for a specific class.
      \"\"\"
      def get_ship_ids_for_class(:frigate), do: @frigate_ids
      def get_ship_ids_for_class(:destroyer), do: @destroyer_ids
      def get_ship_ids_for_class(:cruiser), do: @cruiser_ids
      def get_ship_ids_for_class(:battlecruiser), do: @battlecruiser_ids
      def get_ship_ids_for_class(:battleship), do: @battleship_ids
      def get_ship_ids_for_class(:capital), do: @capital_ids
      def get_ship_ids_for_class(:supercapital), do: @supercapital_ids
      def get_ship_ids_for_class(:industrial), do: @industrial_ids
      def get_ship_ids_for_class(:mining), do: @mining_ids
      def get_ship_ids_for_class(_), do: []

      @doc \"\"\"
      Commonly used ship groups for tactical analysis.
      \"\"\"
      def tactical_ship_groups do
        %{
          tackle: [:frigate, :destroyer],
          dps: [:cruiser, :battlecruiser, :battleship],
          support: [:cruiser, :battlecruiser],
          capital: [:capital, :supercapital],
          industrial: [:industrial, :mining]
        }
      end

      @doc \"\"\"
      Check if a ship is typically used for tackling.
      \"\"\"
      def is_tackle_ship?(type_id) do
        classify_ship_type(type_id) in [:frigate, :destroyer]
      end

      @doc \"\"\"
      Check if a ship is typically a DPS platform.
      \"\"\"
      def is_dps_ship?(type_id) do
        classify_ship_type(type_id) in [:cruiser, :battlecruiser, :battleship]
      end

      @doc \"\"\"
      Check if a ship is a support vessel.

      Note: This includes both logistics and EWAR ships based on actual type IDs.
      \"\"\"
      def is_support_ship?(type_id) do
        is_logistics?(type_id) or is_ewar?(type_id)
      end

      @doc \"\"\"
      Get interceptor ship type IDs.

      Interceptors are fast, agile frigates used for tackling and fleet scouting.
      \"\"\"
      def interceptor_ship_ids, do: @interceptor_ids

      @doc \"\"\"
      Get logistics ship type IDs.

      Logistics ships provide remote repair capabilities to fleets.
      \"\"\"
      def logistics_ship_ids, do: @logistics_ids

      @doc \"\"\"
      Get electronic warfare ship type IDs.

      EWAR ships provide electronic disruption capabilities.
      \"\"\"
      def ewar_ship_ids, do: @ewar_ids

      @doc \"\"\"
      Check if a ship type ID is an interceptor.
      \"\"\"
      def is_interceptor?(type_id), do: type_id in @interceptor_ids

      @doc \"\"\"
      Check if a ship type ID is a logistics ship.
      \"\"\"
      def is_logistics?(type_id), do: type_id in @logistics_ids

      @doc \"\"\"
      Check if a ship type ID is an EWAR ship.
      \"\"\"
      def is_ewar?(type_id), do: type_id in @ewar_ids

      @doc \"\"\"
      DEPRECATED: Returns ship type ranges. Use classify_ship_type/1 instead.

      This function is kept for backward compatibility but returns empty ranges.
      \"\"\"
      @deprecated "Use classify_ship_type/1 or get_ship_ids_for_class/1 instead"
      def ship_type_ranges do
        # Return empty ranges - all classification is now done via actual type IDs
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
    """

    File.write!("lib/eve_dmv/static_data/ship_types.ex", content)
  end
end
