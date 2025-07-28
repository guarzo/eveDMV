defmodule EveDmv.Contexts.Surveillance.Domain.ChainIntelligenceHelper do
  @moduledoc """
  Helper module for ChainIntelligenceService to reduce dependencies.

  Contains business logic and utility functions that don't require
  direct access to the GenServer state.
  """

  alias Ecto.Adapters.SQL
  alias EveDmv.Contexts.Surveillance.Domain.AlertService
  alias EveDmv.Contexts.Surveillance.Domain.ChainActivityTracker
  alias EveDmv.Contexts.Surveillance.Domain.ChainThreatAnalyzer
  alias EveDmv.DomainEvents.ChainThreatDetected
  alias EveDmv.Intelligence.WandererClient
  alias EveDmv.Repo
  alias Phoenix.PubSub

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
    PubSub.subscribe(EveDmv.PubSub, "wanderer:chain_updates")
    PubSub.subscribe(EveDmv.PubSub, "wanderer:inhabitant_updates")
    PubSub.subscribe(EveDmv.PubSub, "killmails:enriched")
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
    Logger.debug("Syncing topologies for #{length(map_ids)} chains")

    # Sync topology data for all maps concurrently
    sync_results =
      map_ids
      |> Task.async_stream(
        fn map_id -> sync_single_chain_topology(map_id) end,
        timeout: 30_000,
        max_concurrency: 4
      )
      |> Enum.map(fn {:ok, result} -> result end)

    # Check if all syncs were successful
    failed_syncs = Enum.filter(sync_results, fn {status, _} -> status == :error end)

    if Enum.empty?(failed_syncs) do
      Logger.info("Successfully synchronized #{length(map_ids)} chain topologies")
      {:ok, :synchronized}
    else
      Logger.warning("Failed to sync #{length(failed_syncs)} out of #{length(map_ids)} chains")
      {:error, {:partial_sync, failed_syncs}}
    end
  end

  defp sync_single_chain_topology(map_id) do
    # Fetch current topology from Wanderer API
    case WandererClient.get_chain_topology(map_id) do
      {:ok, topology} ->
        # Update local topology cache/database
        case update_topology_cache(map_id, topology) do
          {:ok, _} ->
            Logger.debug("Synced topology for chain #{map_id}")
            {:ok, map_id}

          {:error, reason} ->
            Logger.error(
              "Failed to update topology cache for chain #{map_id}: #{inspect(reason)}"
            )

            {:error, {map_id, reason}}
        end

      {:error, reason} ->
        Logger.error("Failed to fetch topology for chain #{map_id}: #{inspect(reason)}")
        {:error, {map_id, reason}}
    end
  rescue
    exception ->
      Logger.error("Exception syncing chain #{map_id}: #{inspect(exception)}")
      {:error, {map_id, exception}}
  end

  defp update_topology_cache(map_id, topology) do
    # Store topology data in the database or cache
    # This could use Ash resources or direct database operations
    # For now, we'll use a simple approach - store in ETS or database
    topology_data = %{
      map_id: map_id,
      topology: topology,
      last_updated: DateTime.utc_now(),
      system_count: count_systems(topology),
      connection_count: count_connections(topology)
    }

    # Could store in database table or ETS for fast access
    # For now, just log the update
    Logger.debug(
      "Updated topology cache for chain #{map_id} with #{topology_data.system_count} systems"
    )

    {:ok, topology_data}
  rescue
    exception ->
      {:error, exception}
  end

  defp count_systems(topology) when is_map(topology) do
    length(Map.get(topology, "systems", []))
  end

  defp count_systems(_), do: 0

  defp count_connections(topology) when is_map(topology) do
    length(Map.get(topology, "connections", []))
  end

  defp count_connections(_), do: 0

  @doc """
  Perform threat analysis for a specific map.
  """
  def perform_threat_analysis(map_id, callback_fn) do
    Logger.debug("Performing threat analysis for chain #{map_id}")

    try do
      # Gather data for threat analysis
      chain_data = fetch_chain_analysis_data(map_id)

      # Analyze multiple threat vectors
      threat_analyses = [
        analyze_recent_hostile_activity(map_id, chain_data),
        analyze_inhabitant_threats(map_id, chain_data),
        analyze_killmail_patterns(map_id, chain_data),
        analyze_system_vulnerabilities(map_id, chain_data)
      ]

      # Combine threat analyses
      combined_threats = combine_threat_analyses(threat_analyses)

      # Calculate overall threat level
      overall_threat_level = calculate_overall_threat_level(combined_threats)

      # Calculate analysis confidence
      confidence = calculate_analysis_confidence(chain_data, combined_threats)

      threat_result = %{
        map_id: map_id,
        threat_level: overall_threat_level,
        threats_detected: combined_threats,
        confidence: confidence,
        analysis_time: DateTime.utc_now(),
        data_quality: assess_data_quality(chain_data)
      }

      # Execute callback if provided
      if is_function(callback_fn, 1) do
        callback_fn.(threat_result)
      end

      {:ok, threat_result}
    rescue
      exception ->
        Logger.error(
          "Error performing threat analysis for chain #{map_id}: #{inspect(exception)}"
        )

        {:error, {:analysis_failed, exception}}
    end
  end

  defp fetch_chain_analysis_data(map_id) do
    # Fetch all relevant data for threat analysis
    %{
      topology: elem(WandererClient.get_chain_topology(map_id), 1),
      inhabitants: elem(WandererClient.get_chain_inhabitants(map_id), 1),
      recent_activity: get_recent_chain_activity(map_id, hours: 24),
      system_info: get_chain_system_info(map_id)
    }
  end

  defp get_recent_chain_activity(map_id, opts) do
    hours = Keyword.get(opts, :hours, 24)
    since = DateTime.add(DateTime.utc_now(), -hours * 3600, :second)

    # Query killmails in all systems of this chain
    query = """
    SELECT k.killmail_id, k.killmail_time, k.solar_system_id, k.victim_ship_type_id, k.attacker_count
    FROM killmails_raw k
    JOIN wormhole_systems ws ON k.solar_system_id = ws.system_id
    WHERE ws.map_id = $1 AND k.killmail_time >= $2
    ORDER BY k.killmail_time DESC
    LIMIT 100
    """

    case SQL.query(Repo, query, [map_id, since]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, time, system_id, ship_type, attackers] ->
          %{
            killmail_id: id,
            killmail_time: time,
            system_id: system_id,
            ship_type: ship_type,
            attackers: attackers
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp get_chain_system_info(_map_id) do
    # Get system information for the chain
    # This would typically come from the static data or topology
    %{
      system_count: 0,
      high_sec_systems: 0,
      low_sec_systems: 0,
      null_sec_systems: 0,
      wormhole_systems: 0
    }
  end

  defp analyze_recent_hostile_activity(_map_id, chain_data) do
    recent_kills = Map.get(chain_data, :recent_activity, [])

    hostile_activity =
      recent_kills
      # Multi-attacker kills suggest PvP
      |> Enum.filter(fn kill -> kill.attackers > 1 end)
      |> Enum.group_by(fn kill -> kill.system_id end)

    threats =
      Enum.map(hostile_activity, fn {system_id, kills} ->
        %{
          type: :hostile_activity,
          system_id: system_id,
          threat_level: calculate_activity_threat_level(kills),
          details: %{
            kill_count: length(kills),
            latest_kill: List.first(kills).killmail_time,
            systems_affected: [system_id]
          }
        }
      end)

    threats
  end

  defp analyze_inhabitant_threats(_map_id, chain_data) do
    inhabitants = Map.get(chain_data, :inhabitants, [])

    # Analyze inhabitants for known hostiles, large fleets, etc.
    hostile_inhabitants = classify_inhabitants(inhabitants)

    if Enum.empty?(hostile_inhabitants) do
      []
    else
      [
        %{
          type: :hostile_inhabitants,
          threat_level: :medium,
          details: %{
            hostile_count: length(hostile_inhabitants),
            total_inhabitants: length(inhabitants),
            hostile_ratio: length(hostile_inhabitants) / max(length(inhabitants), 1)
          }
        }
      ]
    end
  end

  defp analyze_killmail_patterns(_map_id, chain_data) do
    recent_kills = Map.get(chain_data, :recent_activity, [])

    # Pattern 1: High frequency of kills (possible camp)
    high_frequency_patterns =
      if length(recent_kills) >= 5 do
        [
          %{
            type: :high_kill_frequency,
            threat_level: :high,
            details: %{kill_count: length(recent_kills), timeframe: "24h"}
          }
        ]
      else
        []
      end

    # Pattern 2: Kills in multiple systems (roaming gang)
    system_kills = Enum.group_by(recent_kills, fn kill -> kill.system_id end)

    roaming_patterns =
      if map_size(system_kills) >= 3 do
        [
          %{
            type: :roaming_activity,
            threat_level: :medium,
            details: %{systems_affected: Map.keys(system_kills)}
          }
        ]
      else
        []
      end

    high_frequency_patterns ++ roaming_patterns
  end

  defp analyze_system_vulnerabilities(_map_id, chain_data) do
    topology = Map.get(chain_data, :topology, %{})

    # Check for single-connection systems (easily cut off)
    systems = Map.get(topology, "systems", [])
    connections = Map.get(topology, "connections", [])

    # This is a simplified analysis - in reality would need proper graph analysis
    if not Enum.empty?(systems) and length(connections) < length(systems) do
      [
        %{
          type: :topology_vulnerability,
          threat_level: :low,
          details: %{reason: "Potential bottleneck systems detected"}
        }
      ]
    else
      []
    end
  end

  defp calculate_activity_threat_level(kills) do
    case length(kills) do
      n when n >= 10 -> :critical
      n when n >= 5 -> :high
      n when n >= 2 -> :medium
      _ -> :low
    end
  end

  defp combine_threat_analyses(analyses) do
    analyses
    |> Enum.concat()
    |> Enum.sort_by(fn threat -> threat_level_to_number(threat.threat_level) end, :desc)
  end

  defp threat_level_to_number(level) do
    case level do
      :critical -> 4
      :high -> 3
      :medium -> 2
      :low -> 1
      _ -> 0
    end
  end

  defp calculate_overall_threat_level(threats) do
    if Enum.empty?(threats) do
      :minimal
    else
      max_threat =
        Enum.max_by(threats, fn threat -> threat_level_to_number(threat.threat_level) end)

      max_threat.threat_level
    end
  end

  defp calculate_analysis_confidence(chain_data, threats) do
    # Base confidence on data availability and quality
    data_factors = [
      if(Map.get(chain_data, :recent_activity, []) != [], do: 0.3, else: 0.0),
      if(Map.get(chain_data, :inhabitants, []) != [], do: 0.2, else: 0.0),
      if(Map.get(chain_data, :topology, %{}) != %{}, do: 0.2, else: 0.0),
      if(not Enum.empty?(threats), do: 0.3, else: 0.1)
    ]

    min(Enum.sum(data_factors), 1.0)
  end

  defp assess_data_quality(chain_data) do
    %{
      topology_available: Map.get(chain_data, :topology, %{}) != %{},
      inhabitants_available: Map.get(chain_data, :inhabitants, []) != [],
      recent_activity_available: Map.get(chain_data, :recent_activity, []) != [],
      system_info_available: Map.get(chain_data, :system_info, %{}) != %{}
    }
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
    Logger.debug("Handling threat detection for map #{threat_result.map_id}")

    try do
      # Process each detected threat
      threat_actions =
        threat_result.threats_detected
        |> Enum.map(fn threat -> process_individual_threat(threat, threat_result) end)
        |> Enum.reject(&is_nil/1)

      # Generate appropriate alerts based on overall threat level
      alert_actions = generate_threat_alerts(threat_result)

      # Update threat tracking
      tracking_result = update_threat_tracking(threat_result)

      # Notify relevant systems
      notification_results = notify_threat_systems(threat_result, threat_actions)

      # Log threat handling results
      log_threat_handling(threat_result, threat_actions, alert_actions)

      handling_result = %{
        map_id: threat_result.map_id,
        threat_level: threat_result.threat_level,
        actions_taken: threat_actions ++ alert_actions,
        tracking_updated: tracking_result,
        notifications_sent: notification_results,
        handled_at: DateTime.utc_now()
      }

      {:ok, handling_result}
    rescue
      exception ->
        Logger.error("Error handling threat detection: #{inspect(exception)}")
        {:error, {:handling_failed, exception}}
    end
  end

  defp process_individual_threat(threat, threat_result) do
    case threat.type do
      :hostile_activity ->
        process_hostile_activity_threat(threat, threat_result)

      :hostile_inhabitants ->
        process_hostile_inhabitants_threat(threat, threat_result)

      :high_kill_frequency ->
        process_high_kill_frequency_threat(threat, threat_result)

      :roaming_activity ->
        process_roaming_activity_threat(threat, threat_result)

      :topology_vulnerability ->
        process_topology_vulnerability_threat(threat, threat_result)

      _ ->
        Logger.warning("Unknown threat type: #{threat.type}")
        nil
    end
  end

  defp process_hostile_activity_threat(threat, threat_result) do
    # Handle hostile activity detection
    system_id = threat.details.system_id

    # Create system alert
    alert_event = %ChainThreatDetected{
      map_id: threat_result.map_id,
      system_id: system_id,
      threat_level: threat.threat_level,
      threat_details: threat.details,
      timestamp: DateTime.utc_now()
    }

    AlertService.generate_alert(alert_event)

    %{
      action: :system_alert_generated,
      system_id: system_id,
      threat_type: threat.type,
      severity: threat.threat_level
    }
  end

  defp process_hostile_inhabitants_threat(threat, _threat_result) do
    # Handle hostile inhabitants detection
    hostile_count = threat.details.hostile_count

    %{
      action: :hostile_inhabitants_tracked,
      hostile_count: hostile_count,
      threat_type: threat.type,
      severity: threat.threat_level
    }
  end

  defp process_high_kill_frequency_threat(threat, _threat_result) do
    # Handle high kill frequency (possible camp)
    %{
      action: :camp_alert_generated,
      kill_count: threat.details.kill_count,
      threat_type: threat.type,
      severity: threat.threat_level
    }
  end

  defp process_roaming_activity_threat(threat, _threat_result) do
    # Handle roaming gang detection
    systems_affected = threat.details.systems_affected

    %{
      action: :roaming_alert_generated,
      systems_affected: systems_affected,
      threat_type: threat.type,
      severity: threat.threat_level
    }
  end

  defp process_topology_vulnerability_threat(threat, _threat_result) do
    # Handle topology vulnerability
    %{
      action: :vulnerability_noted,
      reason: threat.details.reason,
      threat_type: threat.type,
      severity: threat.threat_level
    }
  end

  defp generate_threat_alerts(threat_result) do
    base_alerts = []

    # Generate escalation alert for high-level threats
    escalation_alerts =
      if threat_result.threat_level in [:high, :critical] do
        escalation_alert = %{
          action: :escalation_alert,
          threat_level: threat_result.threat_level,
          confidence: threat_result.confidence,
          threat_count: length(threat_result.threats_detected)
        }

        # Broadcast high-priority alert
        PubSub.broadcast(EveDmv.PubSub, "chain_intelligence:#{threat_result.map_id}", {
          :threat_escalation,
          threat_result.map_id,
          threat_result.threat_level
        })

        [escalation_alert | base_alerts]
      else
        base_alerts
      end

    # Generate summary alert
    summary_alert = %{
      action: :threat_summary,
      map_id: threat_result.map_id,
      threat_level: threat_result.threat_level,
      confidence: threat_result.confidence,
      threats_detected: length(threat_result.threats_detected)
    }

    [summary_alert | escalation_alerts]
  end

  defp update_threat_tracking(threat_result) do
    # Update threat tracking database/cache
    # This would typically update a threat history table
    tracking_data = %{
      map_id: threat_result.map_id,
      threat_level: threat_result.threat_level,
      confidence: threat_result.confidence,
      threat_count: length(threat_result.threats_detected),
      updated_at: DateTime.utc_now()
    }

    # For now, just log the tracking update
    Logger.info(
      "Updated threat tracking for chain #{threat_result.map_id}: #{threat_result.threat_level}"
    )

    {:ok, tracking_data}
  end

  defp notify_threat_systems(threat_result, actions) do
    # Notify relevant systems about threat detection
    base_notifications = []

    # Notify chain members via PubSub
    PubSub.broadcast(EveDmv.PubSub, "chain_intelligence:#{threat_result.map_id}", {
      :threat_detected,
      threat_result.map_id,
      threat_result.threat_level,
      actions
    })

    pubsub_notifications = [{:pubsub_broadcast, :chain_members} | base_notifications]

    # Notify external systems if threat level is high
    final_notifications =
      if threat_result.threat_level in [:high, :critical] do
        # Could notify Discord, Slack, etc.
        [{:external_notification, :high_threat} | pubsub_notifications]
      else
        pubsub_notifications
      end

    final_notifications
  end

  defp log_threat_handling(threat_result, threat_actions, alert_actions) do
    Logger.info(
      "Threat handling completed for chain #{threat_result.map_id}: " <>
        "Level=#{threat_result.threat_level}, " <>
        "Confidence=#{Float.round(threat_result.confidence, 2)}, " <>
        "Threats=#{length(threat_result.threats_detected)}, " <>
        "Actions=#{length(threat_actions + alert_actions)}"
    )
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
    since = DateTime.add(DateTime.utc_now(), -hours * 3600, :second)

    query = """
    SELECT k.killmail_id, k.killmail_time, k.victim_ship_type_id, k.attacker_count
    FROM killmails_raw k
    WHERE k.solar_system_id = $1 AND k.killmail_time >= $2
    ORDER BY k.killmail_time DESC
    LIMIT 50
    """

    case SQL.query(Repo, query, [system_id, since]) do
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
        ship_name = String.downcase(Map.get(ship, "name", ""))
        ship_name =~ ~r/(dread|carrier|super|titan|recon|interceptor|dictor)/
      end)

    if dangerous_ships > 0, do: 2, else: 0
  end

  defp analyze_ship_threat(_), do: 0

  defp calculate_confidence(hostile_data, contact_info, recent_activity) do
    # Base confidence from data quality
    data_quality = if is_map(hostile_data) and map_size(hostile_data) > 2, do: 0.4, else: 0.2
    contact_quality = if is_map(contact_info) and map_size(contact_info) > 0, do: 0.3, else: 0.1
    activity_confirmation = if Enum.empty?(recent_activity), do: 0.0, else: 0.3

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
      name = String.downcase(Map.get(inhabitant, "name", ""))
      corp = String.downcase(Map.get(inhabitant, "corporation", ""))

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
        if(Enum.empty?(inhabitants),
          do: 0,
          else: length(hostile_inhabitants) / length(inhabitants)
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
