defmodule EveDmv.Intelligence.ChainAnalysis.ChainDataSync do
  @moduledoc """
  Chain data synchronization module for Wanderer API integration.

  This module handles the synchronization of chain topology data,
  system inhabitants, and connections from the Wanderer API.
  """

  require Logger
  require Ash.Query

  alias EveDmv.Api
  alias EveDmv.Intelligence.ChainAnalysis.ChainConnection
  alias EveDmv.Intelligence.ChainAnalysis.ChainTopology
  alias EveDmv.Intelligence.SystemInhabitant
  alias EveDmv.Intelligence.WandererClient

  @doc """
  Sync all data for a specific chain from Wanderer API.

  Returns :ok on success or {:error, reason} on failure.
  """
  def sync_chain_data(map_id) do
    with {:ok, topology_data} <- WandererClient.get_chain_topology(map_id),
         {:ok, inhabitants_data} <- WandererClient.get_system_inhabitants(map_id),
         {:ok, connections_data} <- WandererClient.get_connections(map_id) do
      # Update topology
      update_chain_topology(map_id, topology_data)

      # Update inhabitants
      update_system_inhabitants(map_id, inhabitants_data)

      # Update connections
      update_chain_connections(map_id, connections_data)

      # Broadcast update
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "chain_intelligence:#{map_id}",
        {:chain_updated, map_id}
      )

      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Create or update chain topology record.

  Returns {:ok, topology} on success or {:error, reason} on failure.
  """
  def create_or_update_chain_topology(map_id, corporation_id) do
    # Try to find existing topology
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read!(domain: Api) do
      [topology] ->
        # Chain already exists, update monitoring status
        Ash.update!(topology, %{monitoring_enabled: true}, domain: Api)
        {:ok, topology}

      [] ->
        # Create new chain topology
        topology =
          Ash.create!(
            ChainTopology,
            %{
              map_id: map_id,
              corporation_id: corporation_id,
              monitoring_enabled: true
            },
            domain: Api
          )

        {:ok, topology}
    end
  rescue
    error ->
      {:error, error}
  end

  @doc """
  Update chain topology with latest data from Wanderer.

  Returns {:ok, topology} on success or {:error, reason} on failure.
  """
  def update_chain_topology(map_id, topology_data) do
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read!(domain: Api) do
      [topology] ->
        Ash.update!(
          topology,
          %{
            topology_data: topology_data,
            system_count: length(Map.get(topology_data, "systems", [])),
            last_activity_at: DateTime.utc_now()
          },
          domain: Api
        )

        {:ok, topology}

      [] ->
        Logger.warning("Chain topology not found for map_id: #{map_id}")
        {:error, :not_found}
    end
  rescue
    error ->
      {:error, error}
  end

  @doc """
  Update system inhabitants from Wanderer data.

  Returns :ok on success or {:error, reason} on failure.
  """
  def update_system_inhabitants(map_id, inhabitants_data) do
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        # Mark all current inhabitants as departed
        mark_all_departed(topology.id)

        # Process new inhabitant data in bulk
        bulk_update_or_create_inhabitants(topology.id, inhabitants_data)

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Update chain connections from Wanderer data.

  Returns :ok on success or {:error, reason} on failure.
  """
  def update_chain_connections(map_id, connections_data) do
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        # Process connections in bulk
        bulk_update_or_create_connections(topology.id, connections_data)

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helper functions

  defp mark_all_departed(chain_topology_id) do
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

  defp bulk_update_or_create_inhabitants(chain_topology_id, inhabitants_data) do
    # Get all existing inhabitants for this chain
    {:ok, existing} =
      SystemInhabitant
      |> Ash.Query.filter(chain_topology_id == ^chain_topology_id)
      |> Ash.read(domain: Api)

    existing_map =
      Map.new(existing, fn inhabitant ->
        {inhabitant.character_id, inhabitant}
      end)

    # Prepare bulk data
    {updates, creates} =
      inhabitants_data
      |> Enum.reduce({[], []}, fn inhabitant_data, {updates, creates} ->
        character_id = Map.get(inhabitant_data, "character_id")
        system_id = Map.get(inhabitant_data, "system_id")

        attrs = %{
          chain_topology_id: chain_topology_id,
          character_id: character_id,
          character_name: Map.get(inhabitant_data, "character_name", "Unknown"),
          corporation_id: Map.get(inhabitant_data, "corporation_id", 1),
          corporation_name: Map.get(inhabitant_data, "corporation_name", "Unknown"),
          system_id: system_id,
          system_name: Map.get(inhabitant_data, "system_name", "Unknown"),
          ship_type_id: Map.get(inhabitant_data, "ship_type_id"),
          present: true
        }

        case Map.get(existing_map, character_id) do
          nil ->
            # New inhabitant - add to creates
            {updates, [attrs | creates]}

          existing ->
            # Existing inhabitant - add to updates if changed
            if existing.system_id != system_id or not existing.present do
              update_attrs = Map.put(attrs, :id, existing.id)
              {[update_attrs | updates], creates}
            else
              {updates, creates}
            end
        end
      end)

    # Perform bulk operations
    if creates != [] do
      Ash.bulk_create(creates, SystemInhabitant, :create,
        domain: Api,
        return_records?: false,
        return_errors?: false,
        stop_on_error?: false,
        batch_size: 500
      )
    end

    if updates != [] do
      Enum.each(updates, fn update_attrs ->
        case Ash.get(SystemInhabitant, update_attrs.id, domain: Api) do
          {:ok, record} ->
            update_data = Map.delete(update_attrs, :id)
            Ash.update!(record, update_data, domain: Api)

          {:error, _} ->
            # Record not found, skip
            :ok
        end
      end)
    end

    :ok
  end

  defp bulk_update_or_create_connections(chain_topology_id, connections_data) do
    # Get all existing connections for this chain
    {:ok, existing} =
      ChainConnection
      |> Ash.Query.filter(chain_topology_id == ^chain_topology_id)
      |> Ash.read(domain: Api)

    existing_map =
      Map.new(existing, fn connection ->
        {"#{connection.source_system_id}-#{connection.target_system_id}", connection}
      end)

    # Prepare bulk data
    {updates, creates} =
      connections_data
      |> Enum.reduce({[], []}, fn connection_data, {updates, creates} ->
        source_id = Map.get(connection_data, "source_system_id")
        target_id = Map.get(connection_data, "target_system_id")
        connection_key = "#{source_id}-#{target_id}"

        attrs = %{
          chain_topology_id: chain_topology_id,
          source_system_id: source_id,
          target_system_id: target_id,
          connection_type: Map.get(connection_data, "connection_type", "wormhole"),
          mass_status: Map.get(connection_data, "mass_status", "stable"),
          time_status: Map.get(connection_data, "time_status", "stable"),
          is_eol: Map.get(connection_data, "is_eol", false)
        }

        case Map.get(existing_map, connection_key) do
          nil ->
            # New connection - add to creates
            {updates, [attrs | creates]}

          existing ->
            # Existing connection - add to updates if changed
            update_attrs = Map.put(attrs, :id, existing.id)
            {[update_attrs | updates], creates}
        end
      end)

    # Perform bulk operations
    if creates != [] do
      Ash.bulk_create(creates, ChainConnection, :create,
        domain: Api,
        return_records?: false,
        return_errors?: false,
        stop_on_error?: false,
        batch_size: 100
      )
    end

    if updates != [] do
      Enum.each(updates, fn update_attrs ->
        case Ash.get(ChainConnection, update_attrs.id, domain: Api) do
          {:ok, record} ->
            update_data = Map.delete(update_attrs, :id)
            Ash.update!(record, update_data, domain: Api)

          {:error, _} ->
            # Record not found, skip
            :ok
        end
      end)
    end

    :ok
  end
end
