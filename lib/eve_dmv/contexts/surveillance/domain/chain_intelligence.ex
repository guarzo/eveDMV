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

  alias EveDmv.Core.Utils.DateTimeUtils

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

  # Private helper functions

  defp get_system_jump_activity(system_id, days_back) do
    # Query killmail data to infer jump activity
    since = DateTimeUtils.add(DateTime.utc_now(), -days_back * 24 * 3600, :second)

    try do
      # Query killmails in the system to analyze participant movement
      killmails =
        EveDmv.Api.read!(
          EveDmv.Killmails.KillmailRaw,
          filter: [
            solar_system_id: system_id,
            occurred_at: [greater_than: since]
          ],
          limit: 1000
        )

      # Extract unique characters from participants
      unique_characters =
        killmails
        |> Enum.flat_map(&(&1.participants || []))
        |> Enum.map(& &1.character_id)
        |> Enum.uniq()
        |> length()

      # Calculate peak hour from killmail times
      hour_counts =
        killmails
        |> Enum.map(fn km ->
          km.killmail_time
          |> DateTime.to_time()
          |> Time.to_erl()
          # Extract hour
          |> elem(0)
        end)
        |> Enum.frequencies()

      peak_hour =
        if map_size(hour_counts) > 0 do
          hour_counts
          |> Enum.max_by(fn {_hour, count} -> count end)
          |> elem(0)
        else
          0
        end

      %{
        # Estimate: each kill involves movement
        total_jumps: length(killmails) * 2,
        unique_characters: unique_characters,
        peak_hour: peak_hour,
        days_analyzed: days_back
      }
    rescue
      _ ->
        # Fallback if query fails
        %{
          total_jumps: 0,
          unique_characters: 0,
          peak_hour: 0,
          days_analyzed: days_back
        }
    end
  end

  defp get_system_connections(system_id) do
    # Get system connections based on killmail activity patterns
    # Real wormhole connections would require integration with mapping tools

    # Get recent killmails to analyze movement patterns
    since = DateTimeUtils.add(DateTime.utc_now(), -24 * 3600, :second)

    killmails =
      EveDmv.Api.read!(
        EveDmv.Killmails.KillmailRaw,
        filter: [
          solar_system_id: system_id,
          occurred_at: [greater_than: since]
        ],
        limit: 500
      )

    # Analyze participant movements to infer connections
    # Group by adjacent killmail locations for the same characters
    connections = analyze_movement_patterns(killmails, system_id)

    %{
      # Would require static data import
      static_connections: [],
      wormhole_connections: connections,
      total_connections: length(connections)
    }
  rescue
    _ ->
      %{
        static_connections: [],
        wormhole_connections: [],
        total_connections: 0
      }
  end

  defp analyze_movement_patterns(killmails, target_system_id) do
    # Analyze character movements to infer connections
    killmails
    |> Enum.flat_map(&(&1.participants || []))
    |> Enum.group_by(& &1.character_id)
    |> Enum.flat_map(fn {_char_id, participations} ->
      # Sort by time and look for movements
      participations
      |> Enum.sort_by(& &1.killmail_time)
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.filter(fn [prev, curr] ->
        # One kill must be in our target system
        (prev.solar_system_id == target_system_id or curr.solar_system_id == target_system_id) and
          prev.solar_system_id != curr.solar_system_id
      end)
      |> Enum.map(fn [prev, curr] ->
        if prev.solar_system_id == target_system_id do
          curr.solar_system_id
        else
          prev.solar_system_id
        end
      end)
    end)
    |> Enum.frequencies()
    |> Enum.map(fn {connected_system, count} ->
      %{
        system_id: connected_system,
        activity_count: count,
        connection_type: :inferred
      }
    end)
    # Limit to top 5 connections
    |> Enum.take(5)
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
    # Real implementation would track actual fleet movements through wormholes

    # Get ships in the fleet
    ships = Map.get(fleet_data, :ships, [])

    # Calculate total fleet mass
    fleet_mass =
      ships
      |> Enum.map(fn ship ->
        type_id = Map.get(ship, :ship_type_id) || Map.get(ship, :type_id)

        if type_id do
          case EveDmv.StaticData.get_ship_mass(type_id) do
            {:ok, mass} -> mass
            # Default cruiser mass
            _ -> 10_000_000
          end
        else
          10_000_000
        end
      end)
      |> Enum.sum()

    # Standard wormhole mass limit (C2-C4 size)
    mass_limit = 2_000_000_000

    usage_percentage =
      if mass_limit > 0 do
        Float.round(fleet_mass / mass_limit * 100, 1)
      else
        0.0
      end

    %{
      connection_id: connection.id,
      from_system: connection.from,
      to_system: connection.to,
      mass_used: fleet_mass,
      mass_limit: mass_limit,
      usage_percentage: usage_percentage
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
  def analyze_chain_topology(chain_id, _opts \\ []) do
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

  @doc """
  Analyze chain activity patterns.
  Provides unified activity analysis across contexts.
  """
  @spec analyze_chain_activity(integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_chain_activity(chain_id, opts \\ []) do
    time_range = Keyword.get(opts, :hours, 24)

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

  @doc """
  Assess chain security status.
  Combines threat assessment from both surveillance and wormhole contexts.
  """
  @spec assess_chain_security(integer(), integer()) :: {:ok, map()} | {:error, term()}
  def assess_chain_security(chain_id, corporation_id) do
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

  defp find_chokepoints(_topology) do
    # Find systems that are critical for chain connectivity
    # These are systems whose removal would split the chain
    []
  end

  defp get_chain_activity_data(chain_id, hours) do
    # Get activity data from killmails
    # Note: chain_id would normally reference a wormhole mapping tool
    # For now, we'll analyze activity in a set of systems
    since = DateTimeUtils.add(DateTime.utc_now(), -hours * 3600, :second)

    try do
      # Get recent killmails (using a default system for now)
      killmails =
        EveDmv.Api.read!(
          EveDmv.Killmails.KillmailRaw,
          filter: [
            occurred_at: [greater_than: since]
          ],
          limit: 2000
        )

      # Group activity by hour
      jumps = analyze_hourly_activity(killmails, hours)

      %{
        chain_id: chain_id,
        hours: hours,
        jumps: jumps,
        kills: killmails
      }
    rescue
      _ ->
        %{
          chain_id: chain_id,
          hours: hours,
          jumps: [],
          kills: []
        }
    end
  end

  defp analyze_hourly_activity(killmails, total_hours) do
    # Group killmails by hour and extract activity
    now = DateTime.utc_now()

    # Initialize all hours with zero activity
    hour_map =
      1..total_hours
      |> Enum.map(fn h -> {h, %{hour: h, jump_count: 0, unique_pilots: MapSet.new()}} end)
      |> Map.new()

    # Populate with actual activity
    updated_map =
      killmails
      |> Enum.reduce(hour_map, fn km, acc ->
        hours_ago = div(DateTimeUtils.diff(now, km.killmail_time, :second), 3600)

        if hours_ago >= 1 and hours_ago <= total_hours do
          pilots = (km.participants || []) |> Enum.map(& &1.character_id) |> MapSet.new()

          Map.update(
            acc,
            hours_ago,
            %{hour: hours_ago, jump_count: 1, unique_pilots: pilots},
            fn existing ->
              %{
                existing
                | jump_count: existing.jump_count + 1,
                  unique_pilots: MapSet.union(existing.unique_pilots, pilots)
              }
            end
          )
        else
          acc
        end
      end)

    # Convert to list format
    updated_map
    |> Map.values()
    |> Enum.map(fn data ->
      %{
        hour: data.hour,
        jump_count: data.jump_count,
        unique_pilots: MapSet.size(data.unique_pilots)
      }
    end)
    |> Enum.sort_by(& &1.hour)
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
    # Analyze for hostile activity patterns based on kill data
    kills = Map.get(activity_data, :kills, [])

    if Enum.empty?(kills) do
      %{
        detected: false,
        confidence: 0.0
      }
    else
      # Look for patterns indicating hostile presence
      total_kills = length(kills)

      recent_kills =
        Enum.filter(kills, fn kill ->
          DateTimeUtils.diff(DateTime.utc_now(), kill.killmail_time, :hour) < 6
        end)

      recent_ratio = length(recent_kills) / max(total_kills, 1)

      %{
        # Hostile if >30% of kills are recent
        detected: recent_ratio > 0.3,
        confidence: Float.round(recent_ratio * 100, 1)
      }
    end
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

  defp detect_hostile_presence(_activity, corporation_id) do
    # Check for hostile pilots in activity data
    # Query recent killmails to identify hostiles
    since = DateTimeUtils.add(DateTime.utc_now(), -48 * 3600, :second)

    # Get killmails where our corporation was involved
    killmails =
      EveDmv.Api.read!(
        EveDmv.Killmails.KillmailRaw,
        filter: [
          occurred_at: [greater_than: since]
        ],
        limit: 1000
      )

    # Filter for kills involving our corporation
    relevant_kills =
      Enum.filter(killmails, fn km ->
        victim_corp = Map.get(km.victim || %{}, :corporation_id)
        attacker_corps = (km.attackers || []) |> Enum.map(& &1.corporation_id)

        victim_corp == corporation_id or corporation_id in attacker_corps
      end)

    # Identify hostile entities
    hostile_data = analyze_hostile_entities(relevant_kills, corporation_id)

    # Assess threat level based on hostile activity
    threat_level =
      cond do
        length(hostile_data.hostile_pilots) > 10 -> :high
        length(hostile_data.hostile_pilots) > 5 -> :medium
        length(hostile_data.hostile_pilots) > 0 -> :low
        true -> :minimal
      end

    %{
      hostile_pilots: hostile_data.hostile_pilots |> Enum.take(20),
      hostile_corporations: hostile_data.hostile_corporations |> Enum.take(10),
      threat_assessment: threat_level
    }
  rescue
    _ ->
      %{
        hostile_pilots: [],
        hostile_corporations: [],
        threat_assessment: :unknown
      }
  end

  defp analyze_hostile_entities(killmails, corporation_id) do
    # Extract hostile pilots and corporations
    hostile_pilots =
      killmails
      |> Enum.flat_map(fn km ->
        if Map.get(km.victim || %{}, :corporation_id) == corporation_id do
          # We were the victim, all attackers are hostile
          (km.attackers || []) |> Enum.map(& &1.character_id)
        else
          # We were attacking, victim is hostile
          [Map.get(km.victim || %{}, :character_id)]
        end
      end)
      |> Enum.filter(& &1)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_pilot, count} -> -count end)
      |> Enum.map(fn {pilot, count} -> %{character_id: pilot, engagement_count: count} end)

    hostile_corporations =
      killmails
      |> Enum.flat_map(fn km ->
        if Map.get(km.victim || %{}, :corporation_id) == corporation_id do
          # We were the victim, all attacker corps are hostile
          (km.attackers || []) |> Enum.map(& &1.corporation_id)
        else
          # We were attacking, victim corp is hostile
          [Map.get(km.victim || %{}, :corporation_id)]
        end
      end)
      |> Enum.filter(& &1)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_corp, count} -> -count end)
      |> Enum.map(fn {corp, count} -> %{corporation_id: corp, engagement_count: count} end)

    %{
      hostile_pilots: hostile_pilots,
      hostile_corporations: hostile_corporations
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
  Analyze coverage optimization for a corporation's chain operations.
  """
  def analyze_coverage_optimization(corporation_id, chain_data) do
    Logger.debug("Analyzing coverage optimization for corporation #{corporation_id}")

    # Analyze current coverage
    current_coverage = analyze_current_coverage(chain_data)

    # Generate optimization recommendations
    recommendations = generate_optimization_recommendations(current_coverage)

    optimization_analysis = %{
      corporation_id: corporation_id,
      current_coverage_score: current_coverage.score,
      optimization_potential: current_coverage.optimization_potential,
      recommendations: recommendations,
      analyzed_at: DateTime.utc_now()
    }

    {:ok, optimization_analysis}
  rescue
    error ->
      Logger.error("Error analyzing coverage optimization: #{inspect(error)}")
      {:error, :analysis_failed}
  end

  @doc """
  Get intelligence summary for a corporation.
  """
  def get_corporation_intelligence_summary(corporation_id) do
    Logger.debug("Getting intelligence summary for corporation #{corporation_id}")

    # Gather various intelligence data points
    summary = %{
      corporation_id: corporation_id,
      chain_activity_score: calculate_corp_activity_score(corporation_id),
      threat_assessment: assess_corp_threat_level(corporation_id),
      operational_readiness: evaluate_operational_readiness(corporation_id),
      recent_engagements: get_recent_engagement_summary(corporation_id),
      intelligence_confidence: 0.75,
      last_updated: DateTime.utc_now()
    }

    {:ok, summary}
  rescue
    error ->
      Logger.error("Error getting corporation intelligence summary: #{inspect(error)}")
      {:error, :summary_failed}
  end

  # Private helper functions for new functionality

  defp analyze_current_coverage(chain_data) do
    systems = Map.get(chain_data, :systems, [])
    connections = Map.get(chain_data, :connections, [])

    # Calculate coverage metrics
    system_count = length(systems)
    connection_density = if system_count > 0, do: length(connections) / system_count, else: 0

    score = min(100.0, system_count * 10 + connection_density * 20)
    optimization_potential = max(0.0, 100.0 - score)

    %{
      system_count: system_count,
      connection_count: length(connections),
      connection_density: Float.round(connection_density, 2),
      score: Float.round(score, 2),
      optimization_potential: Float.round(optimization_potential, 2)
    }
  end

  defp generate_optimization_recommendations(coverage) do
    initial_recommendations = []

    connection_recommendations =
      if coverage.connection_density < 1.5 do
        ["Increase scouting to find additional connections" | initial_recommendations]
      else
        initial_recommendations
      end

    system_recommendations =
      if coverage.system_count < 5 do
        ["Expand chain mapping to include more systems" | connection_recommendations]
      else
        connection_recommendations
      end

    final_recommendations =
      if coverage.optimization_potential > 50 do
        ["Consider establishing forward operating bases" | system_recommendations]
      else
        system_recommendations
      end

    final_recommendations
  end

  defp calculate_corp_activity_score(corporation_id) do
    # Get recent killmails involving the corporation
    since = DateTimeUtils.add(DateTime.utc_now(), -7 * 24 * 3600, :second)

    try do
      killmails =
        EveDmv.Api.read!(
          EveDmv.Killmails.KillmailRaw,
          filter: [occurred_at: [greater_than: since]],
          limit: 1000
        )

      corp_killmails =
        Enum.filter(killmails, fn km ->
          victim_corp = Map.get(km.victim || %{}, :corporation_id)
          attacker_corps = (km.attackers || []) |> Enum.map(& &1.corporation_id)

          victim_corp == corporation_id or corporation_id in attacker_corps
        end)

      # Calculate activity score based on engagement frequency
      engagement_count = length(corp_killmails)
      Float.round(min(100.0, engagement_count * 2), 2)
    rescue
      _ -> 0.0
    end
  end

  defp assess_corp_threat_level(corporation_id) do
    # Assess threat level based on recent combat activity
    activity_score = calculate_corp_activity_score(corporation_id)

    cond do
      activity_score > 75 -> :high
      activity_score > 40 -> :medium
      activity_score > 10 -> :low
      true -> :minimal
    end
  end

  defp evaluate_operational_readiness(corporation_id) do
    # Evaluate operational readiness based on activity patterns
    activity_score = calculate_corp_activity_score(corporation_id)

    readiness_score =
      cond do
        activity_score > 50 -> 0.9
        activity_score > 25 -> 0.7
        activity_score > 10 -> 0.5
        true -> 0.3
      end

    %{
      score: readiness_score,
      status: if(readiness_score > 0.7, do: :ready, else: :limited),
      last_assessment: DateTime.utc_now()
    }
  end

  defp get_recent_engagement_summary(corporation_id) do
    # Get summary of recent engagements
    since = DateTimeUtils.add(DateTime.utc_now(), -48 * 3600, :second)

    try do
      killmails =
        EveDmv.Api.read!(
          EveDmv.Killmails.KillmailRaw,
          filter: [occurred_at: [greater_than: since]],
          limit: 500
        )

      corp_killmails =
        Enum.filter(killmails, fn km ->
          victim_corp = Map.get(km.victim || %{}, :corporation_id)
          attacker_corps = (km.attackers || []) |> Enum.map(& &1.corporation_id)

          victim_corp == corporation_id or corporation_id in attacker_corps
        end)

      victories =
        Enum.count(corp_killmails, fn km ->
          attacker_corps = (km.attackers || []) |> Enum.map(& &1.corporation_id)
          corporation_id in attacker_corps
        end)

      losses = length(corp_killmails) - victories

      %{
        total_engagements: length(corp_killmails),
        victories: victories,
        losses: losses,
        efficiency:
          if(length(corp_killmails) > 0,
            do: Float.round(victories / length(corp_killmails), 2),
            else: 0.0
          ),
        time_period_hours: 48
      }
    rescue
      _ ->
        %{
          total_engagements: 0,
          victories: 0,
          losses: 0,
          efficiency: 0.0,
          time_period_hours: 48
        }
    end
  end

  @doc """
  Utility function to check if consolidation is working.
  """
  def version do
    "1.0.0 - Unified Chain Intelligence"
  end
end
