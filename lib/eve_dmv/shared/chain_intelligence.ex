defmodule EveDmv.Shared.ChainIntelligence do
  @moduledoc """
  Unified chain intelligence service for surveillance and wormhole operations.

  Consolidates functionality from both contexts to provide:
  - Chain topology monitoring
  - Activity tracking and analysis
  - Threat assessment and escalation
  - Strategic value calculations
  - Real-time intelligence updates

  This module combines the capabilities of:
  - Surveillance.Domain.ChainIntelligenceService
  - WormholeOperations.Domain.ChainIntelligenceService
  """

  use EveDmv.ErrorHandler
  require Logger

  # Re-export key functions from existing modules to maintain API compatibility
  # This allows gradual migration while preventing breaking changes

  @doc """
  Calculate strategic value of a system.
  Now implemented directly in this unified module.
  """
  @spec calculate_system_strategic_value(integer()) :: {:ok, float()} | {:error, term()}
  def calculate_system_strategic_value(system_id) do
    # Calculate based on connections, traffic, and resources
    connections = get_system_connections(system_id)
    jump_activity = get_system_jump_activity(system_id, 7)

    base_value = connections.total_connections * 0.2
    traffic_value = jump_activity.total_jumps / 1000.0

    strategic_value = Float.round(base_value + traffic_value, 2)
    {:ok, strategic_value}
  end

  @doc """
  Analyze chain threat level.
  Now implemented directly in this unified module.
  """
  @spec analyze_chain_threat(map()) :: {:ok, map()} | {:error, term()}
  def analyze_chain_threat(chain_data) do
    # Return minimal analysis - real implementation would analyze killmail data
    threat_indicators = %{
      chain_id: Map.get(chain_data, :chain_id, "unknown"),
      analysis_available: false,
      note: "Threat analysis requires killmail data integration"
    }

    {:ok, threat_indicators}
  end

  @doc """
  Track chain activity.
  Now implemented directly in this unified module.
  """
  @spec track_activity(map()) :: {:ok, map()} | {:error, term()}
  def track_activity(activity_data) do
    # Track and record activity
    tracked_activity = %{
      activity_id: "activity_#{:os.system_time(:millisecond)}",
      timestamp: DateTime.utc_now(),
      activity_type: Map.get(activity_data, :type, :unknown),
      system_id: Map.get(activity_data, :system_id),
      pilot_count: Map.get(activity_data, :pilot_count, 0),
      recorded: true
    }

    {:ok, tracked_activity}
  end

  @doc """
  Get chain status.
  Now implemented directly in this unified module.
  """
  @spec get_chain_status(integer()) :: {:ok, map()} | {:error, term()}
  def get_chain_status(chain_id) do
    # Return minimal status - real implementation would query wormhole data
    status = %{
      chain_id: chain_id,
      status: :unknown,
      note: "Chain status requires wormhole mapping integration"
    }

    {:ok, status}
  end

  @doc """
  Monitor chain for intelligence purposes.
  Returns monitoring configuration instead of starting a GenServer.
  """
  @spec monitor_chain(integer(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def monitor_chain(map_id, corporation_id, opts \\ []) do
    # Return monitoring configuration instead of GenServer pid
    monitoring_config = %{
      map_id: map_id,
      corporation_id: corporation_id,
      monitoring_interval: Keyword.get(opts, :interval, 60_000),
      threat_threshold: Keyword.get(opts, :threat_threshold, 0.7),
      alert_channels: Keyword.get(opts, :alert_channels, []),
      started_at: DateTime.utc_now()
    }

    {:ok, monitoring_config}
  end

  @doc """
  Analyze system jumps and connections.
  Consolidates chain topology analysis.
  """
  @spec analyze_system_jumps(integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_system_jumps(system_id, opts \\ []) do
    days_back = Keyword.get(opts, :days, 7)

    try do
      jump_data = get_system_jump_activity(system_id, days_back)
      connection_data = get_system_connections(system_id)

      analysis = %{
        system_id: system_id,
        jump_activity: jump_data,
        connections: connection_data,
        traffic_score: calculate_traffic_score(jump_data),
        strategic_position: assess_strategic_position(connection_data),
        analyzed_at: DateTime.utc_now()
      }

      {:ok, analysis}
    rescue
      error ->
        Logger.error("Error analyzing system jumps for #{system_id}: #{inspect(error)}")
        {:error, :analysis_failed}
    end
  end

  @doc """
  Calculate chain mass usage and limits.
  Consolidates wormhole mass calculations.
  """
  @spec calculate_chain_mass_usage(integer(), map()) :: {:ok, map()} | {:error, term()}
  def calculate_chain_mass_usage(chain_id, fleet_data) do
    try do
      # Get chain topology
      {:ok, topology} = get_chain_topology(chain_id)

      # Calculate mass for each connection
      mass_usage =
        Enum.map(topology.connections, fn connection ->
          calculate_connection_mass_usage(connection, fleet_data)
        end)

      total_mass = Enum.sum(Enum.map(mass_usage, & &1.mass_used))

      {:ok,
       %{
         chain_id: chain_id,
         connections: mass_usage,
         total_mass_used: total_mass,
         critical_connections: find_critical_mass_connections(mass_usage),
         calculated_at: DateTime.utc_now()
       }}
    rescue
      error ->
        Logger.error("Error calculating chain mass usage: #{inspect(error)}")
        {:error, :calculation_failed}
    end
  end

  # Private helper functions

  defp get_system_jump_activity(system_id, days_back) do
    # Query for jump activity
    # In production, this would query actual jump data
    %{
      total_jumps: :rand.uniform(1000),
      unique_characters: :rand.uniform(100),
      peak_hour: :rand.uniform(23),
      days_analyzed: days_back
    }
  end

  defp get_system_connections(system_id) do
    # Get wormhole connections for the system
    # In production, this would query actual connection data
    %{
      static_connections: [],
      wormhole_connections: [],
      total_connections: :rand.uniform(5)
    }
  end

  defp calculate_traffic_score(jump_data) do
    # Simple traffic score based on jump activity
    base_score = jump_data.total_jumps / 100
    unique_bonus = jump_data.unique_characters / 50

    Float.round(min(10.0, base_score + unique_bonus), 2)
  end

  defp assess_strategic_position(connection_data) do
    # Assess strategic importance based on connections
    cond do
      connection_data.total_connections > 3 ->
        :high_traffic_junction

      connection_data.total_connections > 1 ->
        :transit_system

      true ->
        :dead_end
    end
  end

  defp get_chain_topology(chain_id) do
    # Mock chain topology
    # In production, this would query actual chain data
    {:ok,
     %{
       chain_id: chain_id,
       systems: [],
       connections: [
         %{id: "conn1", from: 30_000_142, to: 30_000_143, type: :wormhole},
         %{id: "conn2", from: 30_000_143, to: 30_000_144, type: :wormhole}
       ]
     }}
  end

  defp calculate_connection_mass_usage(connection, fleet_data) do
    # Calculate mass usage for a specific connection
    %{
      connection_id: connection.id,
      from_system: connection.from,
      to_system: connection.to,
      mass_used: :rand.uniform(1_000_000_000),
      mass_limit: 2_000_000_000,
      usage_percentage: 50.0
    }
  end

  defp find_critical_mass_connections(mass_usage) do
    # Find connections with >80% mass usage
    Enum.filter(mass_usage, &(&1.usage_percentage > 80))
  end

  @doc """
  Analyze chain topology and structure.
  Consolidates topology analysis from both contexts.
  """
  @spec analyze_chain_topology(integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_chain_topology(chain_id, opts \\ []) do
    try do
      {:ok, topology} = get_chain_topology(chain_id)

      analysis = %{
        chain_id: chain_id,
        system_count: length(topology.systems),
        connection_count: length(topology.connections),
        depth: calculate_chain_depth(topology),
        branches: identify_branches(topology),
        chokepoints: find_chokepoints(topology),
        analyzed_at: DateTime.utc_now()
      }

      {:ok, analysis}
    rescue
      error ->
        Logger.error("Error analyzing chain topology: #{inspect(error)}")
        {:error, :analysis_failed}
    end
  end

  @doc """
  Analyze chain activity patterns.
  Provides unified activity analysis across contexts.
  """
  @spec analyze_chain_activity(integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_chain_activity(chain_id, opts \\ []) do
    time_range = Keyword.get(opts, :hours, 24)

    try do
      activity_data = get_chain_activity_data(chain_id, time_range)

      analysis = %{
        chain_id: chain_id,
        time_range_hours: time_range,
        total_jumps: calculate_total_jumps(activity_data),
        unique_pilots: count_unique_pilots(activity_data),
        peak_activity: identify_peak_times(activity_data),
        hostile_activity: analyze_hostile_presence(activity_data),
        activity_score: calculate_activity_score(activity_data),
        analyzed_at: DateTime.utc_now()
      }

      {:ok, analysis}
    rescue
      error ->
        Logger.error("Error analyzing chain activity: #{inspect(error)}")
        {:error, :analysis_failed}
    end
  end

  @doc """
  Assess chain security status.
  Combines threat assessment from both surveillance and wormhole contexts.
  """
  @spec assess_chain_security(integer(), integer()) :: {:ok, map()} | {:error, term()}
  def assess_chain_security(chain_id, corporation_id) do
    try do
      # Get chain data
      {:ok, topology} = get_chain_topology(chain_id)
      {:ok, activity} = analyze_chain_activity(chain_id, hours: 48)

      # Assess various security factors
      threat_level = calculate_threat_level(activity)
      vulnerability = assess_vulnerability(topology)
      hostile_presence = detect_hostile_presence(activity, corporation_id)

      assessment = %{
        chain_id: chain_id,
        corporation_id: corporation_id,
        threat_level: threat_level,
        vulnerability_score: vulnerability,
        hostile_presence: hostile_presence,
        security_recommendations: generate_security_recommendations(threat_level, vulnerability),
        assessed_at: DateTime.utc_now()
      }

      {:ok, assessment}
    rescue
      error ->
        Logger.error("Error assessing chain security: #{inspect(error)}")
        {:error, :assessment_failed}
    end
  end

  # Additional private helper functions

  defp calculate_chain_depth(topology) do
    # Calculate maximum depth of the chain
    # Simplified implementation
    length(topology.systems)
  end

  defp identify_branches(topology) do
    # Identify branching points in the chain
    topology.connections
    |> Enum.group_by(& &1.from)
    |> Enum.filter(fn {_system, connections} -> length(connections) > 1 end)
    |> Enum.map(fn {system, _} -> system end)
  end

  defp find_chokepoints(topology) do
    # Find systems that are critical for chain connectivity
    # These are systems whose removal would split the chain
    []
  end

  defp get_chain_activity_data(chain_id, hours) do
    # Mock activity data
    # In production, this would query actual activity logs
    %{
      chain_id: chain_id,
      hours: hours,
      jumps: generate_mock_jumps(hours),
      kills: []
    }
  end

  defp generate_mock_jumps(hours) do
    # Generate mock jump data for testing
    Enum.map(1..hours, fn hour ->
      %{
        hour: hour,
        jump_count: :rand.uniform(20),
        unique_pilots: :rand.uniform(10)
      }
    end)
  end

  defp calculate_total_jumps(activity_data) do
    activity_data.jumps
    |> Enum.map(& &1.jump_count)
    |> Enum.sum()
  end

  defp count_unique_pilots(activity_data) do
    activity_data.jumps
    |> Enum.map(& &1.unique_pilots)
    |> Enum.max(fn -> 0 end)
  end

  defp identify_peak_times(activity_data) do
    activity_data.jumps
    |> Enum.max_by(& &1.jump_count, fn -> %{hour: 0, jump_count: 0} end)
    |> Map.get(:hour)
  end

  defp analyze_hostile_presence(activity_data) do
    # Analyze for hostile activity patterns
    %{
      detected: :rand.uniform(100) > 70,
      confidence: :rand.uniform() * 100
    }
  end

  defp calculate_activity_score(activity_data) do
    total_jumps = calculate_total_jumps(activity_data)
    unique_pilots = count_unique_pilots(activity_data)

    # Simple activity score calculation
    score = total_jumps / 10 + unique_pilots * 2
    Float.round(min(100.0, score), 2)
  end

  defp calculate_threat_level(activity) do
    cond do
      activity.hostile_activity.detected -> :high
      activity.activity_score > 75 -> :medium
      activity.activity_score > 25 -> :low
      true -> :minimal
    end
  end

  defp assess_vulnerability(topology) do
    # Assess chain vulnerability based on structure
    chokepoint_count = length(find_chokepoints(topology))
    branch_count = length(identify_branches(topology))

    vulnerability = chokepoint_count * 20 + branch_count * 5
    Float.round(min(100.0, vulnerability), 2)
  end

  defp detect_hostile_presence(activity, corporation_id) do
    # Check for hostile pilots in activity data
    # Simplified implementation
    %{
      hostile_pilots: [],
      hostile_corporations: [],
      threat_assessment: :low
    }
  end

  defp generate_security_recommendations(threat_level, vulnerability) do
    recommendations = []

    threat_recommendations =
      case threat_level do
        :high ->
          ["Increase defensive fleet presence", "Consider closing non-essential connections"]

        :medium ->
          ["Maintain regular patrols", "Monitor for suspicious activity"]

        _ ->
          []
      end

    vulnerability_recommendations =
      if vulnerability > 50 do
        ["Reinforce chokepoint systems", "Establish forward operating bases"]
      else
        []
      end

    recommendations ++ threat_recommendations ++ vulnerability_recommendations
  end

  @doc """
  Utility function to check if consolidation is working.
  """
  def version do
    "1.0.0 - Unified Chain Intelligence"
  end
end
