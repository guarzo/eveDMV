defmodule EveDmvWeb.ChainIntelligenceLive do
  @moduledoc """
  LiveView for real-time wormhole chain intelligence surveillance.

  Displays chain topology, system inhabitants, and provides real-time
  threat monitoring for wormhole corporations.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Api

  alias EveDmv.Intelligence.{
    ChainConnection,
    ChainMonitor,
    ChainTopology,
    SystemInhabitant,
    ThreatAnalyzer
  }

  @impl true
  def mount(_params, session, socket) do
    user = session["user"]

    if user do
      # Subscribe to chain intelligence updates
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "chain_intelligence:*")

      socket =
        socket
        |> assign(:user, user)
        |> assign(:monitored_chains, [])
        |> assign(:selected_chain, nil)
        |> assign(:chain_data, %{})
        |> assign(:loading, false)
        |> assign(:error, nil)
        |> load_user_chains()

      {:ok, socket}
    else
      {:ok, redirect(socket, to: ~p"/")}
    end
  end

  @impl true
  def handle_params(%{"map_id" => map_id}, _uri, socket) do
    socket =
      socket
      |> assign(:selected_chain, map_id)
      |> load_chain_data(map_id)

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("monitor_chain", %{"map_id" => map_id}, socket) do
    user = socket.assigns.user
    # Default corp if not set
    corporation_id = user.corporation_id || 1

    case ChainMonitor.monitor_chain(map_id, corporation_id) do
      :ok ->
        socket =
          socket
          |> put_flash(:info, "Started monitoring chain #{map_id}")
          |> load_user_chains()

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to monitor chain: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("stop_monitoring", %{"map_id" => map_id}, socket) do
    case ChainMonitor.stop_monitoring(map_id) do
      :ok ->
        socket =
          socket
          |> put_flash(:info, "Stopped monitoring chain #{map_id}")
          |> load_user_chains()

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to stop monitoring: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("refresh_chain", %{"map_id" => map_id}, socket) do
    ChainMonitor.force_sync()

    socket =
      socket
      |> put_flash(:info, "Refreshing chain data...")
      |> load_chain_data(map_id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("analyze_pilot", %{"character_id" => character_id}, socket) do
    character_id = String.to_integer(character_id)

    # Spawn async analysis to avoid blocking UI
    pid = self()

    Task.start(fn ->
      analysis = ThreatAnalyzer.analyze_pilot(character_id)
      send(pid, {:pilot_analysis, character_id, analysis})
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:pilot_analysis, character_id, analysis}, socket) do
    # Update the chain data with pilot analysis
    chain_data = socket.assigns.chain_data

    updated_inhabitants =
      Enum.map(chain_data.inhabitants || [], fn inhabitant ->
        if inhabitant.character_id == character_id do
          Map.merge(inhabitant, %{threat_analysis: analysis})
        else
          inhabitant
        end
      end)

    updated_chain_data = Map.put(chain_data, :inhabitants, updated_inhabitants)

    socket =
      socket
      |> assign(:chain_data, updated_chain_data)
      |> put_flash(:info, "Pilot analysis complete")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:chain_updated, map_id}, socket) do
    if socket.assigns.selected_chain == map_id do
      socket = load_chain_data(socket, map_id)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:system_updated, map_id, _data}, socket) do
    if socket.assigns.selected_chain == map_id do
      socket = load_chain_data(socket, map_id)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:connection_updated, map_id, _data}, socket) do
    if socket.assigns.selected_chain == map_id do
      socket = load_chain_data(socket, map_id)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # Private Functions

  defp load_user_chains(socket) do
    user = socket.assigns.user
    corporation_id = user.corporation_id || 1

    case Ash.read(ChainTopology,
           filter: [corporation_id: corporation_id, monitoring_enabled: true],
           domain: Api
         ) do
      {:ok, chains} ->
        assign(socket, :monitored_chains, chains)

      {:error, reason} ->
        socket
        |> assign(:monitored_chains, [])
        |> put_flash(:error, "Failed to load chains: #{inspect(reason)}")
    end
  end

  defp load_chain_data(socket, map_id) do
    case Ash.read(ChainTopology, filter: [map_id: map_id], domain: Api) do
      {:ok, [topology]} ->
        inhabitants = load_chain_inhabitants(topology.id)
        connections = load_chain_connections(topology.id)

        chain_data = %{
          topology: topology,
          inhabitants: inhabitants,
          connections: connections,
          last_updated: DateTime.utc_now()
        }

        assign(socket, :chain_data, chain_data)

      {:ok, []} ->
        socket
        |> assign(:chain_data, %{})
        |> put_flash(:error, "Chain not found")

      {:error, reason} ->
        socket
        |> assign(:chain_data, %{})
        |> put_flash(:error, "Failed to load chain: #{inspect(reason)}")
    end
  end

  defp load_chain_inhabitants(chain_topology_id) do
    case Ash.read(SystemInhabitant,
           filter: [chain_topology_id: chain_topology_id, present: true],
           domain: Api
         ) do
      {:ok, inhabitants} -> inhabitants
      {:error, _} -> []
    end
  end

  defp load_chain_connections(chain_topology_id) do
    case Ash.read(ChainConnection, filter: [chain_topology_id: chain_topology_id], domain: Api) do
      {:ok, connections} -> connections
      {:error, _} -> []
    end
  end

  defp threat_level_class(:hostile), do: "text-red-600 bg-red-50"
  defp threat_level_class(:neutral), do: "text-yellow-600 bg-yellow-50"
  defp threat_level_class(:friendly), do: "text-green-600 bg-green-50"
  defp threat_level_class(:unknown), do: "text-gray-600 bg-gray-50"

  defp threat_level_icon(:hostile), do: "⚠️"
  defp threat_level_icon(:neutral), do: "❓"
  defp threat_level_icon(:friendly), do: "✅"
  defp threat_level_icon(:unknown), do: "❔"

  defp mass_status_class(:stable), do: "text-green-600"
  defp mass_status_class(:destab), do: "text-yellow-600"
  defp mass_status_class(:critical), do: "text-red-600"
  defp mass_status_class(:unknown), do: "text-gray-600"

  defp time_since(datetime) when is_nil(datetime), do: "Never"

  defp time_since(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end
end
