defmodule EveDmv.Contexts.Surveillance.Domain.ChainStatusService do
  @moduledoc """
  Chain status and data retrieval service.

  Handles status queries and data formatting for chain surveillance.
  """

  require Logger

  @doc """
  Get status for a specific chain.
  """
  def get_chain_status(map_id, state) do
    case Map.get(state.chains, map_id) do
      nil ->
        {:error, :chain_not_found}

      chain_data ->
        status = %{
          map_id: map_id,
          status: Map.get(chain_data, :status, :inactive),
          last_update: Map.get(chain_data, :last_update),
          corporation_id: Map.get(chain_data, :corporation_id),
          system_count: count_systems(chain_data),
          inhabitant_count: count_total_inhabitants(chain_data),
          threat_level: calculate_current_threat_level(chain_data)
        }

        {:ok, status}
    end
  end

  @doc """
  Get status for all monitored chains.
  """
  def get_all_chains_status(state) do
    chains_status =
      state.chains
      |> Enum.map(fn {map_id, _chain_data} ->
        case get_chain_status(map_id, state) do
          {:ok, status} -> status
          {:error, _} -> nil
        end
      end)
      |> Enum.filter(&(&1 != nil))

    {:ok, chains_status}
  end

  @doc """
  Format chain data for external consumption.
  """
  def format_chain_data(chain_data) do
    %{
      topology: format_topology(Map.get(chain_data, :topology, %{})),
      inhabitants: format_inhabitants(Map.get(chain_data, :inhabitants, %{})),
      activity: format_recent_activity(Map.get(chain_data, :activity_timeline, [])),
      threats: format_threats(Map.get(chain_data, :threats, [])),
      last_updated: Map.get(chain_data, :last_update)
    }
  end

  # Private helper functions

  defp count_systems(chain_data) do
    topology = Map.get(chain_data, :topology, %{})
    map_size(topology)
  end

  defp count_total_inhabitants(chain_data) do
    inhabitants = Map.get(chain_data, :inhabitants, %{})

    inhabitants
    |> Map.values()
    |> Enum.map(&length/1)
    |> Enum.sum()
  end

  defp calculate_current_threat_level(chain_data) do
    threats = Map.get(chain_data, :threats, [])

    if threats == [] do
      0
    else
      threats
      |> Enum.map(& &1.threat_level)
      |> Enum.max()
    end
  end

  defp format_topology(topology) do
    Enum.map(topology, fn {system_id, system_data} ->
      %{
        system_id: system_id,
        system_name: Map.get(system_data, :name),
        security_class: Map.get(system_data, :security_class),
        connections: Map.get(system_data, :connections, [])
      }
    end)
  end

  defp format_inhabitants(inhabitants) do
    Enum.map(inhabitants, fn {system_id, system_inhabitants} ->
      %{
        system_id: system_id,
        inhabitants: format_system_inhabitants(system_inhabitants)
      }
    end)
  end

  defp format_system_inhabitants(inhabitants) do
    Enum.map(inhabitants, fn inhabitant ->
      %{
        character_id: Map.get(inhabitant, :character_id),
        character_name: Map.get(inhabitant, :character_name),
        corporation_id: Map.get(inhabitant, :corporation_id),
        ship_type: Map.get(inhabitant, :ship_type),
        last_seen: Map.get(inhabitant, :last_seen),
        standing: Map.get(inhabitant, :standing, :unknown)
      }
    end)
  end

  defp format_recent_activity(timeline) do
    timeline
    # Last 10 activities
    |> Enum.take(10)
    |> Enum.map(fn activity ->
      %{
        type: Map.get(activity, :type),
        timestamp: Map.get(activity, :timestamp),
        system_id: Map.get(activity, :system_id),
        summary: generate_activity_summary(activity)
      }
    end)
  end

  defp format_threats(threats) do
    Enum.map(threats, fn threat ->
      %{
        type: Map.get(threat, :type),
        threat_level: Map.get(threat, :threat_level),
        system_id: Map.get(threat, :system_id),
        detected_at: Map.get(threat, :detected_at),
        details: Map.get(threat, :details, %{})
      }
    end)
  end

  defp generate_activity_summary(activity) do
    case Map.get(activity, :type) do
      :killmail ->
        details = Map.get(activity, :details, %{})
        "Killmail: #{details[:attacker_count]} vs 1"

      :inhabitant_change ->
        details = Map.get(activity, :details, %{})
        "Inhabitant #{details[:change_type]}: #{details[:character_name]}"

      :topology_change ->
        "Chain topology updated"

      _ ->
        "Unknown activity"
    end
  end
end
