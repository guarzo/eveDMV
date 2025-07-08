defmodule EveDmv.Contexts.Surveillance.Domain.ChainIntelligenceHelper do
  @moduledoc """
  Helper module for ChainIntelligenceService to reduce dependencies.

  Contains business logic and utility functions that don't require
  direct access to the GenServer state.
  """

  alias EveDmv.Contexts.Surveillance.Domain.AlertService
  alias EveDmv.Contexts.Surveillance.Domain.ChainActivityTracker
  alias EveDmv.Contexts.Surveillance.Domain.ChainThreatAnalyzer
  alias EveDmv.DomainEvents.ChainThreatDetected
  alias EveDmv.Intelligence.WandererClient

  require Logger

  @doc """
  Fetch initial chain data from Wanderer API.
  """
  def fetch_initial_chain_data(map_id) do
    Logger.info("Fetching initial chain data for map #{map_id}")

    with {:ok, topology} <- WandererClient.get_chain_topology(map_id),
         {:ok, inhabitants} <- WandererClient.get_chain_inhabitants(map_id) do
      %{topology: topology, inhabitants: inhabitants}
    else
      {:error, reason} ->
        Logger.warning("Failed to fetch initial chain data: #{inspect(reason)}")
        %{topology: %{}, inhabitants: %{}}
    end
  end

  @doc """
  Analyze chain for threats using collected data.
  """
  def analyze_chain_threats(chain_data, topology, inhabitants) do
    ChainThreatAnalyzer.analyze_threats(%{
      chain_data: chain_data,
      topology: topology,
      inhabitants: inhabitants
    })
  end

  @doc """
  Generate activity predictions for a chain.
  """
  def generate_activity_predictions(map_id, activity_timeline) do
    ChainActivityTracker.predict_activity(map_id, activity_timeline)
  end

  @doc """
  Process hostile activity report.
  """
  def process_hostile_activity(map_id, system_id, hostile_data, chain_data) do
    threat_level = calculate_threat_level(hostile_data, chain_data)

    if threat_level >= chain_data.threat_threshold do
      generate_threat_alert(map_id, system_id, hostile_data, threat_level)
    end

    {:ok, threat_level}
  end

  @doc """
  Subscribe to PubSub channels for chain intelligence.
  """
  def subscribe_to_channels do
    Phoenix.PubSub.subscribe(EveDmv.PubSub, "wanderer:chain_updates")
    Phoenix.PubSub.subscribe(EveDmv.PubSub, "wanderer:inhabitant_updates")
    Phoenix.PubSub.subscribe(EveDmv.PubSub, "killmails:enriched")
  end

  @doc """
  Spawn a task using the task supervisor.
  """
  def spawn_monitored_task(fun) do
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fun)
  end

  # Private functions

  defp calculate_threat_level(hostile_data, chain_data) do
    # Simplified threat calculation
    base_threat = Map.get(hostile_data, :ship_count, 1) * 10
    distance_modifier = calculate_distance_modifier(hostile_data, chain_data)

    base_threat * distance_modifier
  end

  defp calculate_distance_modifier(hostile_data, chain_data) do
    home_system = chain_data.home_system_id
    hostile_system = Map.get(hostile_data, :system_id)

    if home_system && hostile_system do
      # Simplified distance calculation - in real implementation would use topology
      if home_system == hostile_system, do: 3.0, else: 1.0
    else
      1.0
    end
  end

  defp generate_threat_alert(map_id, system_id, hostile_data, threat_level) do
    event = %ChainThreatDetected{
      map_id: map_id,
      system_id: system_id,
      threat_level: threat_level,
      threat_details: hostile_data,
      timestamp: DateTime.utc_now()
    }

    AlertService.generate_alert(event)
  end
end
