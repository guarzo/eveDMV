defmodule EveDmv.Intelligence.ChainAnalysis.SystemInhabitantsManager do
  @moduledoc """
  System inhabitants management module for chain monitoring.

  This module handles the tracking and updating of character presence
  within wormhole chain systems, including arrivals, departures, and
  ship changes.
  """

  require Logger
  require Ash.Query

  alias EveDmv.Api
  alias EveDmv.Intelligence.SystemInhabitant

  @doc """
  Update or create an inhabitant record for a character.

  Used for real-time updates when characters move between systems
  or change ships.
  """
  def update_or_create_inhabitant(chain_topology_id, inhabitant_data) do
    character_id = Map.get(inhabitant_data, "character_id")
    system_id = Map.get(inhabitant_data, "system_id")

    case SystemInhabitant
         |> Ash.Query.filter(
           chain_topology_id == ^chain_topology_id and character_id == ^character_id and
             system_id == ^system_id
         )
         |> Ash.read(domain: Api) do
      {:ok, [inhabitant]} ->
        # Update existing inhabitant
        Ash.update(
          inhabitant,
          %{
            present: true,
            last_seen_at: DateTime.utc_now(),
            ship_type_id: Map.get(inhabitant_data, "ship_type_id"),
            departure_time: nil
          },
          domain: Api
        )

      {:ok, []} ->
        # Create new inhabitant
        Ash.create(
          SystemInhabitant,
          %{
            chain_topology_id: chain_topology_id,
            character_id: character_id,
            character_name: Map.get(inhabitant_data, "character_name", "Unknown"),
            corporation_id: Map.get(inhabitant_data, "corporation_id", 1),
            corporation_name: Map.get(inhabitant_data, "corporation_name", "Unknown"),
            system_id: system_id,
            system_name: Map.get(inhabitant_data, "system_name", "Unknown"),
            ship_type_id: Map.get(inhabitant_data, "ship_type_id"),
            present: true
          },
          domain: Api
        )
    end
  end

  @doc """
  Update character location within the chain.

  Used for Wanderer SSE events when characters move between systems.
  """
  def update_character_location(map_id, character_name, location_data) do
    system_name = location_data["solar_system_name"]
    system_id = location_data["solar_system_id"]

    update_or_create_inhabitant(map_id, %{
      character_name: character_name,
      solar_system_id: system_id,
      solar_system_name: system_name,
      present: true,
      arrival_time: DateTime.utc_now()
    })
  end

  @doc """
  Update character ship information.

  Used when characters switch ships within the chain.
  """
  def update_character_ship(map_id, character_name, ship_info) do
    ship_name = ship_info["ship"]
    ship_type_id = ship_info["ship_type_id"]

    Logger.debug("Character #{character_name} switched to #{ship_name} in map #{map_id}")

    # Update inhabitant with new ship information
    case find_character_inhabitant(map_id, character_name) do
      {:ok, inhabitant} ->
        try do
          Ash.update!(
            inhabitant,
            %{
              ship_type_id: ship_type_id,
              ship_name: ship_name,
              last_activity_at: DateTime.utc_now()
            },
            domain: Api
          )
        rescue
          error ->
            Logger.error("Failed to update inhabitant ship: #{inspect(error)}")
        end

      _ ->
        Logger.warning(
          "Could not find inhabitant for character #{character_name} in map #{map_id}"
        )
    end
  end

  @doc """
  Update character online status.

  Used when characters come online or go offline.
  """
  def update_character_online_status(map_id, character_name, online) do
    Logger.debug(
      "Character #{character_name} went #{if online, do: "online", else: "offline"} in map #{map_id}"
    )

    # Update inhabitant online status
    case find_character_inhabitant(map_id, character_name) do
      {:ok, inhabitant} ->
        try do
          Ash.update!(
            inhabitant,
            %{
              online: online,
              last_activity_at: DateTime.utc_now()
            },
            domain: Api
          )
        rescue
          error ->
            Logger.error("Failed to update inhabitant online status: #{inspect(error)}")
        end

      _ ->
        Logger.warning(
          "Could not find inhabitant for character #{character_name} in map #{map_id}"
        )
    end
  end

  @doc """
  Update character ready status for fleet operations.

  Used when characters mark themselves as ready/not ready for fleet ops.
  """
  def update_character_ready_status(map_id, character_name, ready) do
    Logger.debug(
      "Character #{character_name} is now #{if ready, do: "ready", else: "not ready"} in map #{map_id}"
    )

    # Update inhabitant ready status (could be used for fleet readiness)
    case find_character_inhabitant(map_id, character_name) do
      {:ok, inhabitant} ->
        try do
          # Add ready status to metadata if the field doesn't exist
          metadata = Map.get(inhabitant, :metadata, %{}) || %{}
          updated_metadata = Map.put(metadata, "ready", ready)

          Ash.update!(
            inhabitant,
            %{
              metadata: updated_metadata,
              last_activity_at: DateTime.utc_now()
            },
            domain: Api
          )
        rescue
          error ->
            Logger.error("Failed to update inhabitant ready status: #{inspect(error)}")
        end

      _ ->
        Logger.warning(
          "Could not find inhabitant for character #{character_name} in map #{map_id}"
        )
    end
  end

  @doc """
  Find a character's current inhabitant record.

  Returns {:ok, inhabitant} if found, {:error, reason} otherwise.
  """
  def find_character_inhabitant(_map_id, character_name) do
    case SystemInhabitant
         |> Ash.Query.filter(character_name == ^character_name and present == true)
         |> Ash.read!(domain: Api) do
      [inhabitant | _] -> {:ok, inhabitant}
      [] -> {:error, :not_found}
    end
  rescue
    error ->
      {:error, error}
  end

  @doc """
  Mark all inhabitants in a chain as departed.

  Used during full chain synchronization to reset presence status.
  """
  def mark_all_departed(chain_topology_id) do
    {:ok, inhabitants} =
      SystemInhabitant
      |> Ash.Query.filter(chain_topology_id == ^chain_topology_id and present == true)
      |> Ash.read(domain: Api)

    # Bulk update all inhabitants to mark as departed
    departure_time = DateTime.utc_now()

    Enum.each(inhabitants, fn inhabitant ->
      Ash.update!(inhabitant, %{present: false, departure_time: departure_time}, domain: Api)
    end)
  end

  @doc """
  Get current inhabitants for a chain.

  Returns list of currently present inhabitants.
  """
  def get_current_inhabitants(chain_topology_id) do
    SystemInhabitant
    |> Ash.Query.filter(chain_topology_id == ^chain_topology_id and present == true)
    |> Ash.read(domain: Api)
  end

  @doc """
  Get inhabitant activity statistics for a chain.

  Returns summary statistics about inhabitant activity.
  """
  def get_inhabitant_statistics(chain_topology_id) do
    case get_current_inhabitants(chain_topology_id) do
      {:ok, inhabitants} ->
        total_present = length(inhabitants)
        online_count = Enum.count(inhabitants, & &1.online)

        unique_corporations =
          Enum.map(inhabitants, & &1.corporation_id) |> Enum.uniq() |> length()

        ship_types =
          Enum.map(inhabitants, & &1.ship_type_id)
          |> Enum.filter(&(&1 != nil))
          |> Enum.frequencies()

        %{
          total_present: total_present,
          online_count: online_count,
          offline_count: total_present - online_count,
          unique_corporations: unique_corporations,
          ship_distribution: ship_types,
          last_updated: DateTime.utc_now()
        }

      {:error, reason} ->
        Logger.error("Failed to get inhabitant statistics: #{inspect(reason)}")

        %{
          total_present: 0,
          online_count: 0,
          offline_count: 0,
          unique_corporations: 0,
          ship_distribution: %{},
          last_updated: DateTime.utc_now()
        }
    end
  end
end
