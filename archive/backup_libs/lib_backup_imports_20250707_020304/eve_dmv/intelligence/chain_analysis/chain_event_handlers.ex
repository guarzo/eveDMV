defmodule EveDmv.Intelligence.ChainAnalysis.ChainEventHandlers do
    alias EveDmv.Intelligence.ChainAnalysis.ChainConnection
  alias EveDmv.Api
  alias EveDmv.Intelligence.ChainAnalysis.ChainTopology
  alias EveDmv.Intelligence.ChainAnalysis.SystemInhabitantsManager

  require Ash.Query
  require Logger
  @moduledoc """
  Event handlers for real-time chain updates from Wanderer.

  This module processes various types of events received from Wanderer's
  real-time SSE streams and WebSocket connections, updating the local
  chain state accordingly.
  """




  @doc """
  Process a Wanderer event based on event type.

  Main dispatcher for handling different types of events from Wanderer.
  """
  def process_wanderer_event(map_id, event_type, event_data) do
    case event_type do
      "connection_added" ->
        handle_connection_added(map_id, event_data)

      "connection_removed" ->
        handle_connection_removed(map_id, event_data)

      "connection_updated" ->
        handle_connection_updated(map_id, event_data)

      "signature_added" ->
        handle_signature_added(map_id, event_data)

      "signature_removed" ->
        handle_signature_removed(map_id, event_data)

      "signatures_updated" ->
        handle_signatures_updated(map_id, event_data)

      "character_location_changed" ->
        handle_character_location_changed(map_id, event_data)

      "character_ship_changed" ->
        handle_character_ship_changed(map_id, event_data)

      "character_online_status_changed" ->
        handle_character_online_status_changed(map_id, event_data)

      "character_ready_status_changed" ->
        handle_character_ready_status_changed(map_id, event_data)

      "map_kill" ->
        handle_map_kill(map_id, event_data)

      _ ->
        Logger.debug("Unknown event type: #{event_type} for map #{map_id}")
    end
  end

  @doc """
  Process legacy system update events.

  Maintains backward compatibility with older event formats.
  """
  def process_system_update(map_id, data) do
    Logger.debug("Processing system update for map #{map_id}: #{inspect(data)}")

    # Update chain activity timestamp
    mark_chain_activity(map_id)
  end

  @doc """
  Process legacy connection update events.

  Maintains backward compatibility with older event formats.
  """
  def process_connection_update(map_id, data) do
    Logger.debug("Processing connection update for map #{map_id}: #{inspect(data)}")

    # Update chain activity timestamp
    mark_chain_activity(map_id)
  end

  # Connection Event Handlers

  defp handle_connection_added(map_id, payload) do
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        connection_data = %{
          chain_topology_id: topology.id,
          source_system_id: payload["source_system_id"],
          target_system_id: payload["target_system_id"],
          connection_type: payload["connection_type"] || "wormhole",
          mass_status: parse_mass_status(payload["mass_status"]),
          time_status: parse_time_status(payload["time_status"]),
          is_eol: payload["is_eol"] || false
        }

        Ash.create(ChainConnection, connection_data, domain: Api)

        # Update connection count
        Ash.update(
          topology,
          %{
            connection_count: topology.connection_count + 1,
            last_activity_at: DateTime.utc_now()
          },
          domain: Api
        )

        Logger.info(
          "Connection added to map #{map_id}: #{payload["from_name"]} -> #{payload["to_name"]}"
        )

      {:error, reason} ->
        Logger.error("Failed to add connection: #{inspect(reason)}")
    end
  end

  defp handle_connection_removed(map_id, payload) do
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        # Find and remove the connection
        source_id = payload["source_system_id"]
        target_id = payload["target_system_id"]

        case ChainConnection
             |> Ash.Query.filter(
               chain_topology_id == ^topology.id and source_system_id == ^source_id and
                 target_system_id == ^target_id
             )
             |> Ash.read(domain: Api) do
          {:ok, [connection]} ->
            Ash.destroy(connection, domain: Api)

            # Update connection count
            Ash.update(
              topology,
              %{
                connection_count: max(0, topology.connection_count - 1),
                last_activity_at: DateTime.utc_now()
              },
              domain: Api
            )

            Logger.info("Connection removed from map #{map_id}")

          {:ok, []} ->
            Logger.warning("Connection to remove not found in local data")
        end

      {:error, reason} ->
        Logger.error("Failed to remove connection: #{inspect(reason)}")
    end
  end

  defp handle_connection_updated(map_id, payload) do
    # Update connection status (mass, time, EOL)
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        source_id = payload["source_system_id"]
        target_id = payload["target_system_id"]

        case ChainConnection
             |> Ash.Query.filter(
               chain_topology_id == ^topology.id and source_system_id == ^source_id and
                 target_system_id == ^target_id
             )
             |> Ash.read(domain: Api) do
          {:ok, [connection]} ->
            Ash.update(
              connection,
              %{
                mass_status: parse_mass_status(payload["mass_status"]),
                time_status: parse_time_status(payload["time_status"]),
                is_eol: payload["is_eol"] || false
              },
              domain: Api
            )

            Logger.debug("Connection updated in map #{map_id}")

          {:ok, []} ->
            Logger.warning("Connection to update not found in local data")
        end

      {:error, reason} ->
        Logger.error("Failed to update connection: #{inspect(reason)}")
    end
  end

  # Signature Event Handlers

  defp handle_signature_added(map_id, _payload) do
    # Mark activity for signature events
    mark_chain_activity(map_id)
  end

  defp handle_signature_removed(map_id, _payload) do
    # Mark activity for signature events
    mark_chain_activity(map_id)
  end

  defp handle_signatures_updated(map_id, _payload) do
    # Mark activity for signature events
    mark_chain_activity(map_id)
  end

  # Character Event Handlers

  defp handle_character_location_changed(map_id, payload) do
    character_name = payload["character_name"]
    location = payload["current_location"]

    SystemInhabitantsManager.update_character_location(map_id, character_name, location)
  end

  defp handle_character_ship_changed(map_id, payload) do
    character_name = payload["character_name"]
    ship_info = payload["current_ship"]

    SystemInhabitantsManager.update_character_ship(map_id, character_name, ship_info)
  end

  defp handle_character_online_status_changed(map_id, payload) do
    character_name = payload["character_name"]
    online = payload["current_online"]

    SystemInhabitantsManager.update_character_online_status(map_id, character_name, online)
  end

  defp handle_character_ready_status_changed(map_id, payload) do
    character_name = payload["character_name"]
    ready = payload["ready"]

    SystemInhabitantsManager.update_character_ready_status(map_id, character_name, ready)
  end

  # Combat Event Handlers

  defp handle_map_kill(map_id, payload) do
    # Payload: %{"killmail_id" => 12345678, "system_name" => "J123456", "victim" => %{...}, "value" => 250_000_000}
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        Ash.update(topology, %{last_activity_at: DateTime.utc_now()}, domain: Api)

        # Broadcast kill event for alerts
        Phoenix.PubSub.broadcast(
          EveDmv.PubSub,
          "chain_intelligence:#{map_id}",
          {:map_kill_detected, payload}
        )

        Logger.info(
          "Kill detected in map #{map_id}: #{payload["victim"]["name"]} in #{payload["system_name"]}"
        )

      {:error, reason} ->
        Logger.error("Failed to process map kill: #{inspect(reason)}")
    end
  end

  # Utility Functions

  @doc """
  Mark chain activity by updating the last_activity_at timestamp.
  """
  def mark_chain_activity(map_id) do
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        Ash.update(topology, %{last_activity_at: DateTime.utc_now()}, domain: Api)

      _ ->
        :ok
    end
  end

  @doc """
  Parse mass status from string to atom.
  """
  def parse_mass_status(status) when is_binary(status) do
    case String.downcase(status) do
      "critical" -> :critical
      "destab" -> :destabilized
      "half" -> :half_mass
      "stable" -> :stable
      _ -> :unknown
    end
  end

  def parse_mass_status(_), do: :stable

  @doc """
  Parse time status from string to atom.
  """
  def parse_time_status(status) when is_binary(status) do
    case String.downcase(status) do
      "critical" -> :critical
      "eol" -> :end_of_life
      "stable" -> :stable
      _ -> :unknown
    end
  end

  def parse_time_status(_), do: :stable
end
