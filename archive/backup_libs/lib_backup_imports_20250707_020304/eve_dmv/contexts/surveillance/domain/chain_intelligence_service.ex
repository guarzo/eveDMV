defmodule EveDmv.Contexts.Surveillance.Domain.ChainIntelligenceService do
  use EveDmv.ErrorHandler
  use GenServer

    alias EveDmv.Contexts.Surveillance.Domain.AlertService
    alias EveDmv.DomainEvents.ChainThreatDetected
    alias EveDmv.Intelligence.WandererClient
  alias EveDmv.Contexts.Surveillance.Domain.NotificationService
  alias EveDmv.Contexts.ThreatAssessment.Analyzers.ThreatAnalyzer
  alias EveDmv.DomainEvents.ChainActivityPrediction
  alias EveDmv.DomainEvents.HostileMovement
  alias EveDmv.Infrastructure.EventBus
  alias EveDmv.Intelligence.ChainAnalysis.ChainMonitor
  alias EveDmv.Result

  require Logger
  @moduledoc """
  Chain-wide surveillance and intelligence service for wormhole operations.

  Provides real-time chain monitoring, hostile tracking, and predictive analytics
  by integrating with Wanderer API for chain topology and inhabitant data.

  Key capabilities:
  - Real-time chain topology monitoring via Wanderer API
  - Hostile movement tracking and alert generation
  - Chain activity timeline and pattern analysis
  - Threat escalation and response coordination
  - Predictive activity forecasting
  """



  # Chain monitoring intervals
  @topology_sync_interval_ms 30_000  # 30 seconds
  @threat_analysis_interval_ms 60_000  # 1 minute
  @activity_prediction_interval_ms 300_000  # 5 minutes

  # Threat escalation thresholds
  @high_threat_threshold 75
  @hostile_fleet_threshold 3
  @chain_breach_distance 2  # Systems from home

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start monitoring a wormhole chain for intelligence purposes.

  Integrates with Wanderer API to track chain topology, inhabitants,
  and generate real-time threat intelligence.
  """
  def monitor_chain(map_id, corporation_id, opts \\ []) do
    GenServer.call(__MODULE__, {:monitor_chain, map_id, corporation_id, opts})
  end

  @doc """
  Stop monitoring a specific chain.
  """
  def stop_monitoring_chain(map_id) do
    GenServer.call(__MODULE__, {:stop_monitoring_chain, map_id})
  end

  @doc """
  Get current chain intelligence status.
  """
  def get_chain_status(map_id) do
    GenServer.call(__MODULE__, {:get_chain_status, map_id})
  end

  @doc """
  Get chain activity timeline for the last N hours.
  """
  def get_activity_timeline(map_id, hours_back \\ 24) do
    GenServer.call(__MODULE__, {:get_activity_timeline, map_id, hours_back})
  end

  @doc """
  Get threat predictions for a chain.
  """
  def get_threat_predictions(map_id) do
    GenServer.call(__MODULE__, {:get_threat_predictions, map_id})
  end

  @doc """
  Manually trigger threat analysis for a chain.
  """
  def analyze_chain_threats(map_id) do
    GenServer.cast(__MODULE__, {:analyze_chain_threats, map_id})
  end

  @doc """
  Get all monitored chains status.
  """
  def get_all_chains_status do
    GenServer.call(__MODULE__, :get_all_chains_status)
  end

  @doc """
  Report hostile activity in a chain system.
  """
  def report_hostile_activity(map_id, system_id, hostile_data) do
    GenServer.cast(__MODULE__, {:report_hostile_activity, map_id, system_id, hostile_data})
  end

  # GenServer implementation

  @impl GenServer
  def init(opts) do
    # Subscribe to Wanderer real-time updates
    Phoenix.PubSub.subscribe(EveDmv.PubSub, "wanderer:chain_updates")
    Phoenix.PubSub.subscribe(EveDmv.PubSub, "wanderer:inhabitant_updates")

    # Subscribe to killmail events for chain activity correlation
    Phoenix.PubSub.subscribe(EveDmv.PubSub, "killmails:enriched")

    state = %{
      monitored_chains: %{},  # map_id -> chain_data
      chain_topologies: %{},  # map_id -> topology_data
      inhabitant_tracking: %{},  # map_id -> inhabitant_data
      activity_timelines: %{},  # map_id -> activity_events
      threat_predictions: %{},  # map_id -> prediction_data
      last_sync: %{},  # map_id -> last_sync_time
      metrics: %{
        chains_monitored: 0,
        threats_detected: 0,
        alerts_generated: 0,
        predictions_made: 0
      }
    }

    # Schedule periodic tasks
    schedule_topology_sync()
    schedule_threat_analysis()
    schedule_activity_prediction()

    Logger.info("ChainIntelligenceService started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:monitor_chain, map_id, corporation_id, opts}, _from, state) do
    try do
      # Initialize chain monitoring
      chain_data = %{
        map_id: map_id,
        corporation_id: corporation_id,
        home_system_id: Keyword.get(opts, :home_system_id),
        alert_enabled: Keyword.get(opts, :alert_enabled, true),
        threat_threshold: Keyword.get(opts, :threat_threshold, @high_threat_threshold),
        started_at: DateTime.utc_now(),
        last_activity: DateTime.utc_now()
      }

      # Start monitoring with existing chain monitor
      case ChainMonitor.monitor_chain(map_id, corporation_id) do
        :ok ->
          # Initialize chain data structures
          new_monitored = Map.put(state.monitored_chains, map_id, chain_data)
          new_topologies = Map.put(state.chain_topologies, map_id, %{})
          new_inhabitants = Map.put(state.inhabitant_tracking, map_id, %{})
          new_timelines = Map.put(state.activity_timelines, map_id, [])
          new_predictions = Map.put(state.threat_predictions, map_id, %{})

          # Initial topology fetch
          spawn_task(fn -> fetch_initial_chain_data(map_id) end)

          new_metrics = %{state.metrics | chains_monitored: state.metrics.chains_monitored + 1}

          new_state = %{
            state
            | monitored_chains: new_monitored,
              chain_topologies: new_topologies,
              inhabitant_tracking: new_inhabitants,
              activity_timelines: new_timelines,
              threat_predictions: new_predictions,
              metrics: new_metrics
          }

          Logger.info("Started chain intelligence monitoring for map #{map_id}")
          {:reply, {:ok, chain_data}, new_state}

        {:error, reason} ->
          Logger.error("Failed to start chain monitoring for #{map_id}: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    rescue
      exception ->
        Logger.error("Chain monitoring initialization error: #{inspect(exception)}")
        {:reply, {:error, :initialization_failed}, state}
    end
  end

  @impl GenServer
  def handle_call({:stop_monitoring_chain, map_id}, _from, state) do
    case Map.get(state.monitored_chains, map_id) do
      nil ->
        {:reply, {:error, :not_monitored}, state}

      _chain_data ->
        # Stop monitoring
        ChainMonitor.stop_monitoring(map_id)

        # Clean up state
        new_monitored = Map.delete(state.monitored_chains, map_id)
        new_topologies = Map.delete(state.chain_topologies, map_id)
        new_inhabitants = Map.delete(state.inhabitant_tracking, map_id)
        new_timelines = Map.delete(state.activity_timelines, map_id)
        new_predictions = Map.delete(state.threat_predictions, map_id)

        new_metrics = %{state.metrics | chains_monitored: max(0, state.metrics.chains_monitored - 1)}

        new_state = %{
          state
          | monitored_chains: new_monitored,
            chain_topologies: new_topologies,
            inhabitant_tracking: new_inhabitants,
            activity_timelines: new_timelines,
            threat_predictions: new_predictions,
            metrics: new_metrics
        }

        Logger.info("Stopped chain intelligence monitoring for map #{map_id}")
        {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call({:get_chain_status, map_id}, _from, state) do
    case Map.get(state.monitored_chains, map_id) do
      nil ->
        {:reply, {:error, :not_monitored}, state}

      chain_data ->
        topology = Map.get(state.chain_topologies, map_id, %{})
        inhabitants = Map.get(state.inhabitant_tracking, map_id, %{})
        timeline = Map.get(state.activity_timelines, map_id, [])
        predictions = Map.get(state.threat_predictions, map_id, %{})

        status = %{
          chain_info: chain_data,
          topology_summary: summarize_topology(topology),
          inhabitant_summary: summarize_inhabitants(inhabitants),
          recent_activity_count: length(Enum.take(timeline, 10)),
          threat_level: calculate_current_threat_level(inhabitants, predictions),
          last_update: Map.get(state.last_sync, map_id),
          monitoring_duration: calculate_monitoring_duration(chain_data.started_at)
        }

        {:reply, {:ok, status}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_activity_timeline, map_id, hours_back}, _from, state) do
    case Map.get(state.activity_timelines, map_id) do
      nil ->
        {:reply, {:error, :not_monitored}, state}

      timeline ->
        cutoff_time = DateTime.add(DateTime.utc_now(), -hours_back * 3600, :second)

        filtered_timeline =
          timeline
          |> Enum.filter(&(DateTime.compare(&1.timestamp, cutoff_time) == :gt))
          |> Enum.sort_by(&(&1.timestamp), {:desc, DateTime})

        {:reply, {:ok, filtered_timeline}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_threat_predictions, map_id}, _from, state) do
    case Map.get(state.threat_predictions, map_id) do
      nil ->
        {:reply, {:error, :not_monitored}, state}

      predictions ->
        {:reply, {:ok, predictions}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_all_chains_status, _from, state) do
    all_status =
      state.monitored_chains
      |> Enum.map(fn {map_id, chain_data} ->
        topology = Map.get(state.chain_topologies, map_id, %{})
        inhabitants = Map.get(state.inhabitant_tracking, map_id, %{})
        predictions = Map.get(state.threat_predictions, map_id, %{})

        {map_id, %{
          chain_info: chain_data,
          system_count: map_size(topology),
          inhabitant_count: count_total_inhabitants(inhabitants),
          threat_level: calculate_current_threat_level(inhabitants, predictions),
          last_update: Map.get(state.last_sync, map_id)
        }}
      end)
      |> Map.new()

    summary = %{
      chains: all_status,
      total_monitored: map_size(state.monitored_chains),
      metrics: state.metrics
    }

    {:reply, {:ok, summary}, state}
  end

  @impl GenServer
  def handle_cast({:analyze_chain_threats, map_id}, state) do
    case Map.get(state.monitored_chains, map_id) do
      nil ->
        {:noreply, state}

      _chain_data ->
        spawn_task(fn -> perform_threat_analysis(map_id) end)
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast({:report_hostile_activity, map_id, system_id, hostile_data}, state) do
    case Map.get(state.monitored_chains, map_id) do
      nil ->
        {:noreply, state}

      chain_data ->
        # Add to activity timeline
        activity_event = %{
          timestamp: DateTime.utc_now(),
          event_type: :hostile_reported,
          system_id: system_id,
          data: hostile_data,
          source: :manual_report
        }

        new_timeline = add_to_timeline(state.activity_timelines, map_id, activity_event)

        # Trigger immediate threat analysis
        spawn_task(fn ->
          analyze_hostile_report(map_id, system_id, hostile_data, chain_data)
        end)

        new_state = %{state | activity_timelines: new_timeline}
        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_info(:sync_topology, state) do
    # Sync topology for all monitored chains
    spawn_task(fn -> sync_all_chain_topologies(Map.keys(state.monitored_chains)) end)
    schedule_topology_sync()
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:analyze_threats, state) do
    # Analyze threats for all monitored chains
    Enum.each(Map.keys(state.monitored_chains), fn map_id ->
      spawn_task(fn -> perform_threat_analysis(map_id) end)
    end)

    schedule_threat_analysis()
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:predict_activity, state) do
    # Generate activity predictions for all monitored chains
    Enum.each(Map.keys(state.monitored_chains), fn map_id ->
      spawn_task(fn -> generate_activity_predictions(map_id) end)
    end)

    schedule_activity_prediction()
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:chain_topology_update, map_id, topology_data}, state) do
    if Map.has_key?(state.monitored_chains, map_id) do
      new_topologies = Map.put(state.chain_topologies, map_id, topology_data)
      new_last_sync = Map.put(state.last_sync, map_id, DateTime.utc_now())

      # Add topology change to timeline
      activity_event = %{
        timestamp: DateTime.utc_now(),
        event_type: :topology_update,
        system_id: nil,
        data: %{system_count: length(topology_data.systems || [])},
        source: :wanderer_api
      }

      new_timeline = add_to_timeline(state.activity_timelines, map_id, activity_event)

      new_state = %{
        state
        | chain_topologies: new_topologies,
          last_sync: new_last_sync,
          activity_timelines: new_timeline
      }

      # Trigger threat analysis if significant topology change
      if topology_changed_significantly?(
        Map.get(state.chain_topologies, map_id, %{}),
        topology_data
      ) do
        spawn_task(fn -> perform_threat_analysis(map_id) end)
      end

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:inhabitant_update, map_id, system_id, inhabitants}, state) do
    if Map.has_key?(state.monitored_chains, map_id) do
      # Update inhabitant tracking
      current_inhabitants = Map.get(state.inhabitant_tracking, map_id, %{})
      new_inhabitants = Map.put(current_inhabitants, system_id, inhabitants)
      new_inhabitant_tracking = Map.put(state.inhabitant_tracking, map_id, new_inhabitants)

      # Add inhabitant change to timeline
      activity_event = %{
        timestamp: DateTime.utc_now(),
        event_type: :inhabitant_update,
        system_id: system_id,
        data: %{inhabitant_count: length(inhabitants)},
        source: :wanderer_api
      }

      new_timeline = add_to_timeline(state.activity_timelines, map_id, activity_event)

      new_state = %{
        state
        | inhabitant_tracking: new_inhabitant_tracking,
          activity_timelines: new_timeline
      }

      # Check for new hostiles
      spawn_task(fn -> check_for_new_hostiles(map_id, system_id, inhabitants) end)

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:killmail_activity, killmail}, state) do
    # Correlate killmail with monitored chains
    if killmail.system_id do
      monitored_chains_in_system = find_chains_containing_system(state.monitored_chains, killmail.system_id)

      Enum.each(monitored_chains_in_system, fn map_id ->
        activity_event = %{
          timestamp: killmail.killmail_time,
          event_type: :killmail_activity,
          system_id: killmail.system_id,
          data: %{
            killmail_id: killmail.killmail_id,
            victim_corporation_id: killmail.victim_corporation_id,
            attacker_count: length(killmail.attackers || [])
          },
          source: :killmail_correlation
        }

        new_timeline = add_to_timeline(state.activity_timelines, map_id, activity_event)

        # Update state for this chain
        spawn_task(fn ->
          GenServer.cast(__MODULE__, {:update_timeline, map_id, activity_event})
        end)
      end)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:update_timeline, map_id, activity_event}, state) do
    new_timeline = add_to_timeline(state.activity_timelines, map_id, activity_event)
    new_state = %{state | activity_timelines: new_timeline}
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(_message, state) do
    {:noreply, state}
  end

  # Private functions

  defp schedule_topology_sync do
    Process.send_after(self(), :sync_topology, @topology_sync_interval_ms)
  end

  defp schedule_threat_analysis do
    Process.send_after(self(), :analyze_threats, @threat_analysis_interval_ms)
  end

  defp schedule_activity_prediction do
    Process.send_after(self(), :predict_activity, @activity_prediction_interval_ms)
  end

  defp spawn_task(fun) do
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fun)
  end

  defp fetch_initial_chain_data(map_id) do
    # Fetch topology
    case WandererClient.get_chain_topology(map_id) do
      {:ok, topology} ->
        send(self(), {:chain_topology_update, map_id, topology})

      {:error, reason} ->
        Logger.warning("Failed to fetch initial topology for #{map_id}: #{inspect(reason)}")
    end

    # Fetch inhabitants
    case WandererClient.get_system_inhabitants(map_id) do
      {:ok, inhabitants} ->
        grouped_inhabitants = Enum.group_by(inhabitants, & &1["system_id"])

        Enum.each(grouped_inhabitants, fn {system_id, system_inhabitants} ->
          send(self(), {:inhabitant_update, map_id, system_id, system_inhabitants})
        end)

      {:error, reason} ->
        Logger.warning("Failed to fetch initial inhabitants for #{map_id}: #{inspect(reason)}")
    end
  end

  defp sync_all_chain_topologies(map_ids) do
    Enum.each(map_ids, fn map_id ->
      case WandererClient.get_chain_topology(map_id) do
        {:ok, topology} ->
          send(self(), {:chain_topology_update, map_id, topology})

        {:error, reason} ->
          Logger.warning("Failed to sync topology for #{map_id}: #{inspect(reason)}")
      end
    end)
  end

  defp perform_threat_analysis(map_id) do
    # Get current inhabitants for threat analysis
    case WandererClient.get_system_inhabitants(map_id) do
      {:ok, inhabitants} ->
        # Group by system for analysis
        systems_with_inhabitants = Enum.group_by(inhabitants, & &1["system_id"])

        # Analyze each system for threats
        threat_results =
          Enum.map(systems_with_inhabitants, fn {system_id, system_inhabitants} ->
            analyze_system_threats(map_id, system_id, system_inhabitants)
          end)
          |> Enum.filter(&(&1 != nil))

        # Process threat results
        Enum.each(threat_results, fn threat_result ->
          handle_threat_detection(threat_result)
        end)

      {:error, reason} ->
        Logger.warning("Failed to fetch inhabitants for threat analysis #{map_id}: #{inspect(reason)}")
    end
  end

  defp analyze_system_threats(map_id, system_id, inhabitants) do
    # Convert inhabitants to pilot data for threat analysis
    pilot_list =
      inhabitants
      |> Enum.map(fn inhabitant ->
        {
          inhabitant["character_id"],
          inhabitant["corporation_id"],
          inhabitant["alliance_id"]
        }
      end)
      |> Enum.filter(fn {char_id, _corp_id, _alliance_id} ->
        char_id && char_id != 0
      end)

    if length(pilot_list) > 0 do
      # Bulk analyze threats
      case ThreatAnalyzer.analyze_pilots(pilot_list) do
        {:ok, threat_analysis} ->
          evaluate_system_threat_level(map_id, system_id, threat_analysis, inhabitants)

        {:error, reason} ->
          Logger.warning("Threat analysis failed for system #{system_id}: #{inspect(reason)}")
          nil
      end
    else
      nil
    end
  end

  defp evaluate_system_threat_level(map_id, system_id, threat_analysis, inhabitants) do
    total_pilots = map_size(threat_analysis.pilot_analyses)
    hostile_pilots = threat_analysis.threat_summary.high_threat_count
    average_threat = threat_analysis.threat_summary.average_threat_score
    high_bait_count = threat_analysis.threat_summary.high_bait_count

    # Calculate overall system threat level
    system_threat_level = cond do
      hostile_pilots >= @hostile_fleet_threshold -> :critical
      average_threat >= @high_threat_threshold -> :high
      high_bait_count > 0 -> :moderate
      total_pilots > 0 -> :low
      true -> :clear
    end

    if system_threat_level in [:critical, :high] do
      %{
        map_id: map_id,
        system_id: system_id,
        threat_level: system_threat_level,
        pilot_count: total_pilots,
        hostile_count: hostile_pilots,
        average_threat_score: average_threat,
        high_bait_count: high_bait_count,
        inhabitants: inhabitants,
        timestamp: DateTime.utc_now()
      }
    else
      nil
    end
  end

  defp handle_threat_detection(threat_result) do
    # Generate chain threat event
    EventBus.publish(%ChainThreatDetected{
      map_id: threat_result.map_id,
      system_id: threat_result.system_id,
      threat_level: threat_result.threat_level,
      pilot_count: threat_result.pilot_count,
      hostile_count: threat_result.hostile_count,
      timestamp: threat_result.timestamp
    })

    # Generate alert if appropriate
    if threat_result.threat_level == :critical do
      alert_data = %{
        alert_type: :chain_threat_critical,
        map_id: threat_result.map_id,
        system_id: threat_result.system_id,
        threat_data: threat_result,
        priority: :critical
      }

      AlertService.process_match(alert_data)
    end

    Logger.info("Threat detected in chain #{threat_result.map_id}, system #{threat_result.system_id}: #{threat_result.threat_level}")
  end

  defp check_for_new_hostiles(map_id, system_id, inhabitants) do
    # Quick threat check for new inhabitants
    if length(inhabitants) > 0 do
      spawn_task(fn ->
        case analyze_system_threats(map_id, system_id, inhabitants) do
          %{threat_level: threat_level} = threat_result when threat_level in [:critical, :high] ->
            # Publish hostile movement event
            EventBus.publish(%HostileMovement{
              system_id: system_id,
              character_id: 0,  # Placeholder for group movement
              threat_level: threat_level,
              timestamp: DateTime.utc_now()
            })

            handle_threat_detection(threat_result)

          _ ->
            :ok
        end
      end)
    end
  end

  defp generate_activity_predictions(map_id) do
    # Analyze activity timeline to generate predictions
    # This is a simplified implementation - real prediction would use ML
    timeline = get_activity_timeline(map_id, 168)  # Last 7 days

    case timeline do
      {:ok, events} when length(events) > 10 ->
        predictions = %{
          next_activity_window: predict_next_activity_window(events),
          threat_escalation_risk: assess_threat_escalation_risk(events),
          chain_stability: assess_chain_stability(events),
          predicted_at: DateTime.utc_now()
        }

        # Publish prediction event
        EventBus.publish(%ChainActivityPrediction{
          map_id: map_id,
          prediction_type: :traffic,
          predicted_activity: predictions,
          confidence_score: calculate_prediction_confidence(events),
          time_window: 3600,
          timestamp: DateTime.utc_now()
        })

        # Store predictions
        GenServer.cast(__MODULE__, {:update_predictions, map_id, predictions})

      _ ->
        :insufficient_data
    end
  end

  defp predict_next_activity_window(events) do
    # Analyze hourly patterns to predict next likely activity
    hourly_distribution =
      events
      |> Enum.group_by(&(&1.timestamp.hour))
      |> Enum.map(fn {hour, hour_events} -> {hour, length(hour_events)} end)
      |> Enum.sort_by(fn {_hour, count} -> count end, :desc)

    case hourly_distribution do
      [{peak_hour, _count} | _] ->
        now = DateTime.utc_now()

        next_window = if now.hour < peak_hour do
          DateTime.new!(now.date, Time.new!(peak_hour, 0, 0))
        else
          tomorrow = Date.add(now.date, 1)
          DateTime.new!(tomorrow, Time.new!(peak_hour, 0, 0))
        end

        %{
          predicted_time: next_window,
          confidence: :moderate,
          type: :activity_peak
        }

      [] ->
        %{predicted_time: nil, confidence: :low, type: :insufficient_data}
    end
  end

  defp assess_threat_escalation_risk(events) do
    # Look for patterns indicating escalating threats
    recent_threats =
      events
      |> Enum.filter(&(&1.event_type in [:hostile_reported, :killmail_activity]))
      |> Enum.take(10)

    threat_trend = length(recent_threats)

    cond do
      threat_trend >= 5 -> :high
      threat_trend >= 2 -> :moderate
      true -> :low
    end
  end

  defp assess_chain_stability(events) do
    # Assess how stable the chain topology has been
    topology_changes =
      Enum.count(events, &(&1.event_type == :topology_update))

    cond do
      topology_changes > 10 -> :unstable
      topology_changes > 5 -> :moderate
      true -> :stable
    end
  end

  defp calculate_prediction_confidence(events) do
    # Simple confidence based on data volume and recency
    event_count = length(events)
    recent_events = Enum.count(events, fn event ->
      DateTime.diff(DateTime.utc_now(), event.timestamp, :hour) <= 24
    end)

    cond do
      event_count > 50 and recent_events > 10 -> :high
      event_count > 20 and recent_events > 5 -> :moderate
      event_count > 10 -> :low
      true -> :very_low
    end
  end

  defp analyze_hostile_report(map_id, system_id, hostile_data, chain_data) do
    # Immediate response to manual hostile reports
    Logger.info("Hostile activity reported in chain #{map_id}, system #{system_id}")

    # Calculate distance from home system if configured
    distance_from_home = if chain_data.home_system_id do
      calculate_system_distance(chain_data.home_system_id, system_id, map_id)
    else
      nil
    end

    # Generate immediate alert if close to home
    if distance_from_home && distance_from_home <= @chain_breach_distance do
      alert_data = %{
        alert_type: :hostile_near_home,
        map_id: map_id,
        system_id: system_id,
        distance_from_home: distance_from_home,
        hostile_data: hostile_data,
        priority: :critical
      }

      AlertService.process_match(alert_data)
    end
  end

  defp calculate_system_distance(home_system_id, target_system_id, map_id) do
    # This would use the chain topology to calculate jump distance
    # Simplified implementation returns a mock distance
    if home_system_id == target_system_id do
      0
    else
      # Mock calculation - real implementation would use graph traversal
      Enum.random(1..5)
    end
  end

  defp topology_changed_significantly?(old_topology, new_topology) do
    old_system_count = length(Map.get(old_topology, :systems, []))
    new_system_count = length(Map.get(new_topology, :systems, []))

    # Significant if system count changed by more than 1
    abs(new_system_count - old_system_count) > 1
  end

  defp add_to_timeline(timelines, map_id, event) do
    current_timeline = Map.get(timelines, map_id, [])
    # Keep last 1000 events per chain
    new_timeline = [event | Enum.take(current_timeline, 999)]
    Map.put(timelines, map_id, new_timeline)
  end

  defp find_chains_containing_system(monitored_chains, system_id) do
    # This would query the topology to find which chains contain the system
    # Simplified implementation returns empty list
    []
  end

  defp summarize_topology(topology) do
    %{
      system_count: length(Map.get(topology, :systems, [])),
      last_updated: Map.get(topology, :last_updated)
    }
  end

  defp summarize_inhabitants(inhabitants) do
    total_inhabitants = count_total_inhabitants(inhabitants)
    systems_with_activity = map_size(inhabitants)

    %{
      total_inhabitants: total_inhabitants,
      active_systems: systems_with_activity,
      average_per_system: if(systems_with_activity > 0, do: total_inhabitants / systems_with_activity, else: 0)
    }
  end

  defp count_total_inhabitants(inhabitants) do
    inhabitants
    |> Map.values()
    |> Enum.map(&length/1)
    |> Enum.sum()
  end

  defp calculate_current_threat_level(inhabitants, predictions) do
    total_inhabitants = count_total_inhabitants(inhabitants)

    cond do
      total_inhabitants > 10 -> :high
      total_inhabitants > 5 -> :moderate
      total_inhabitants > 0 -> :low
      true -> :clear
    end
  end

  defp calculate_monitoring_duration(started_at) do
    DateTime.diff(DateTime.utc_now(), started_at, :second)
  end
end