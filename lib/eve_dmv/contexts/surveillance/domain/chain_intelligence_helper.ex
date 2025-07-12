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
    ChainThreatAnalyzer.analyze_chain_threats(chain_data, %{
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

  @doc """
  Synchronize all chain topologies.
  """
  def sync_all_chain_topologies(map_ids) do
    # TODO: Implement real topology synchronization
    # Requires: API calls to sync topology data for all maps
    Logger.debug("Syncing topologies for #{length(map_ids)} chains")
    {:error, :not_implemented}
  end

  @doc """
  Perform threat analysis for a specific map.
  """
  def perform_threat_analysis(map_id, callback_fn) do
    # TODO: Implement real threat analysis
    # Requires: Threat detection algorithms, pattern analysis
    Logger.debug("Performing threat analysis for chain #{map_id}")

    # Placeholder threat analysis
    threat_result = %{
      map_id: map_id,
      threat_level: :low,
      threats_detected: [],
      confidence: 0.5
    }

    if is_function(callback_fn, 1) do
      callback_fn.(threat_result)
    end

    {:error, :not_implemented}
  end

  @doc """
  Analyze system threats for inhabitants.
  """
  def analyze_system_threats(map_id, system_id, inhabitants) do
    # Implement real system threat analysis based on inhabitant data and recent activity
    Logger.debug("Analyzing system threats for #{system_id} in chain #{map_id}")

    try do
      # Get recent killmail activity in this system
      recent_kills = get_recent_system_activity(system_id, hours: 6)

      # Analyze inhabitants for known hostiles
      hostile_inhabitants = classify_inhabitants(inhabitants)

      # Calculate threat metrics
      inhabitant_count = length(inhabitants)
      hostile_count = length(hostile_inhabitants)
      recent_kill_count = length(recent_kills)

      # Determine overall threat level
      threat_level = determine_system_threat_level(hostile_count, recent_kill_count, inhabitants)

      # Calculate risk factors
      risk_factors = calculate_risk_factors(hostile_inhabitants, recent_kills, inhabitants)

      threat_assessment = %{
        system_id: system_id,
        map_id: map_id,
        inhabitant_count: inhabitant_count,
        hostile_count: hostile_count,
        recent_kills: recent_kill_count,
        threat_level: threat_level,
        risk_factors: risk_factors,
        hostile_inhabitants: hostile_inhabitants,
        analysis_time: DateTime.utc_now()
      }

      {:ok, threat_assessment}
    rescue
      error ->
        Logger.error("Error analyzing system threats: #{inspect(error)}")
        {:error, :analysis_failed}
    end
  end

  @doc """
  Handle threat detection results.
  """
  def handle_threat_detection(threat_result) do
    # TODO: Implement real threat handling
    # Requires: Alert generation, notification systems
    Logger.debug("Handling threat detection: #{inspect(threat_result)}")
    {:error, :not_implemented}
  end

  @doc """
  Analyze hostile reports with context.
  """
  def analyze_hostile_report(map_id, system_id, hostile_data, contact_info, context) do
    # Implement real hostile report analysis based on available data
    Logger.debug("Analyzing hostile report for system #{system_id} in chain #{map_id}")

    try do
      # Analyze recent killmail activity in the system
      recent_activity = get_recent_system_activity(system_id, hours: 2)

      # Analyze hostile fleet composition if available
      hostile_ships = extract_hostile_ships(hostile_data)
      hostile_count = length(hostile_ships)

      # Determine threat level based on multiple factors
      threat_level =
        calculate_threat_level(hostile_count, hostile_ships, recent_activity, context)

      # Calculate confidence based on data quality
      confidence = calculate_confidence(hostile_data, contact_info, recent_activity)

      # Generate recommendations
      actions = generate_recommendations(threat_level, hostile_count, context)

      analysis = %{
        threat_level: threat_level,
        confidence: confidence,
        hostile_count: hostile_count,
        hostile_ships: hostile_ships,
        recent_kills: length(recent_activity),
        recommended_actions: actions,
        analysis_time: DateTime.utc_now()
      }

      {:ok, analysis}
    rescue
      error ->
        Logger.error("Error analyzing hostile report: #{inspect(error)}")
        {:error, :analysis_failed}
    end
  end

  # Private helper functions for real analysis implementation

  defp get_recent_system_activity(system_id, opts) do
    hours = Keyword.get(opts, :hours, 2)
    since = DateTime.utc_now() |> DateTime.add(-hours * 3600, :second)

    query = """
    SELECT k.killmail_id, k.killmail_time, k.victim_ship_type_id, k.attacker_count
    FROM killmails_raw k
    WHERE k.solar_system_id = $1 AND k.killmail_time >= $2
    ORDER BY k.killmail_time DESC
    LIMIT 50
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query, [system_id, since]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, time, ship_type, attackers] ->
          %{killmail_id: id, killmail_time: time, ship_type: ship_type, attackers: attackers}
        end)

      {:error, _} ->
        []
    end
  end

  defp extract_hostile_ships(hostile_data) when is_map(hostile_data) do
    ships = Map.get(hostile_data, "ships", []) || Map.get(hostile_data, :ships, [])
    if is_list(ships), do: ships, else: []
  end

  defp extract_hostile_ships(_), do: []

  defp calculate_threat_level(hostile_count, hostile_ships, recent_activity, context) do
    # Base threat calculation
    base_threat =
      cond do
        hostile_count >= 10 -> :critical
        hostile_count >= 5 -> :high
        hostile_count >= 2 -> :medium
        hostile_count >= 1 -> :low
        true -> :minimal
      end

    # Adjust based on ship types and recent activity
    ship_threat = analyze_ship_threat(hostile_ships)
    activity_threat = if length(recent_activity) > 3, do: 1, else: 0
    context_threat = Map.get(context || %{}, :escalation_factor, 0)

    # Escalate threat level if needed
    case {base_threat, ship_threat + activity_threat + context_threat} do
      {:minimal, factor} when factor >= 2 -> :low
      {:low, factor} when factor >= 2 -> :medium
      {:medium, factor} when factor >= 2 -> :high
      {:high, factor} when factor >= 1 -> :critical
      {level, _} -> level
    end
  end

  defp analyze_ship_threat(ships) when is_list(ships) do
    # Count dangerous ship types
    dangerous_ships =
      Enum.count(ships, fn ship ->
        ship_name = Map.get(ship, "name", "") |> String.downcase()
        ship_name =~ ~r/(dread|carrier|super|titan|recon|interceptor|dictor)/
      end)

    if dangerous_ships > 0, do: 2, else: 0
  end

  defp analyze_ship_threat(_), do: 0

  defp calculate_confidence(hostile_data, contact_info, recent_activity) do
    # Base confidence from data quality
    data_quality = if is_map(hostile_data) and map_size(hostile_data) > 2, do: 0.4, else: 0.2
    contact_quality = if is_map(contact_info) and map_size(contact_info) > 0, do: 0.3, else: 0.1
    activity_confirmation = if length(recent_activity) > 0, do: 0.3, else: 0.0

    min(1.0, data_quality + contact_quality + activity_confirmation)
  end

  defp generate_recommendations(threat_level, _hostile_count, context) do
    base_actions =
      case threat_level do
        :critical -> [:immediate_evacuation, :alert_all, :request_backup, :avoid_system]
        :high -> [:alert_members, :prepare_evacuation, :increase_intel, :avoid_solo_ops]
        :medium -> [:monitor_closely, :alert_members, :safe_up_if_solo]
        :low -> [:monitor, :share_intel]
        :minimal -> [:note_activity]
      end

    # Add context-specific actions
    context_actions =
      case Map.get(context || %{}, :operation_type) do
        :mining -> [:recall_miners, :secure_ore]
        :ratting -> [:recall_ratters, :dock_up]
        :exploration -> [:safe_up_explorers]
        _ -> []
      end

    Enum.uniq(base_actions ++ context_actions)
  end

  defp classify_inhabitants(inhabitants) when is_list(inhabitants) do
    # Simple classification based on known patterns
    # In a real implementation, this would check against standings, known hostile lists, etc.
    Enum.filter(inhabitants, fn inhabitant ->
      name = Map.get(inhabitant, "name", "") |> String.downcase()
      corp = Map.get(inhabitant, "corporation", "") |> String.downcase()

      # Check for known hostile patterns (simplified)
      name =~ ~r/(hostile|enemy|pirate)/ or corp =~ ~r/(pirate|hostile)/
    end)
  end

  defp classify_inhabitants(_), do: []

  defp determine_system_threat_level(hostile_count, recent_kill_count, _inhabitants) do
    cond do
      hostile_count >= 5 or recent_kill_count >= 5 -> :critical
      hostile_count >= 3 or recent_kill_count >= 3 -> :high
      hostile_count >= 1 or recent_kill_count >= 1 -> :medium
      true -> :low
    end
  end

  defp calculate_risk_factors(hostile_inhabitants, recent_kills, inhabitants) do
    %{
      hostile_ratio:
        if(length(inhabitants) > 0,
          do: length(hostile_inhabitants) / length(inhabitants),
          else: 0
        ),
      recent_violence: length(recent_kills),
      escalation_potential: calculate_escalation_potential(hostile_inhabitants, recent_kills),
      evacuation_difficulty: calculate_evacuation_difficulty(inhabitants)
    }
  end

  defp calculate_escalation_potential(hostiles, recent_kills) do
    # Simple escalation calculation
    base = length(hostiles) * 0.2
    activity = length(recent_kills) * 0.1
    min(1.0, base + activity)
  end

  defp calculate_evacuation_difficulty(inhabitants) do
    # Difficulty based on number of friendlies to evacuate
    case length(inhabitants) do
      n when n >= 10 -> 0.9
      n when n >= 5 -> 0.6
      n when n >= 2 -> 0.3
      _ -> 0.1
    end
  end
end
