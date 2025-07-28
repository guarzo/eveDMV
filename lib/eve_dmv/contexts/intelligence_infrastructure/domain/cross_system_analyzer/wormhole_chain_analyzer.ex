defmodule EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystemAnalyzer.WormholeChainAnalyzer do
  @moduledoc """
  Specialized analyzer for wormhole chain mapping and analysis.

  Handles all wormhole-specific analysis including:
  - Chain mapping and connection analysis
  - Wormhole type classification and characteristics
  - Mass capacity and stability calculations
  - Traffic volume estimation
  - Strategic value assessment of connections
  """

  require Logger

  # Wormhole type classifications based on depth patterns
  @wormhole_types %{
    "C1" => %{mass_limit: 2_000_000_000, jump_mass: 500_000_000, lifetime: 16},
    "C2" => %{mass_limit: 2_000_000_000, jump_mass: 1_000_000_000, lifetime: 16},
    "C3" => %{mass_limit: 2_000_000_000, jump_mass: 1_000_000_000, lifetime: 16},
    "C4" => %{mass_limit: 2_000_000_000, jump_mass: 1_000_000_000, lifetime: 24},
    "C5" => %{mass_limit: 3_000_000_000, jump_mass: 1_800_000_000, lifetime: 24},
    "C6" => %{mass_limit: 3_000_000_000, jump_mass: 1_800_000_000, lifetime: 24}
  }

  @doc """
  Maps wormhole chain connections from a starting system.
  """
  def map_wormhole_chain(starting_system_id, max_depth) do
    # For now, simulate the chain. In production, this would query actual wormhole data
    # from Wanderer or similar wormhole mapping tools
    simulate_wormhole_chain(starting_system_id, max_depth)
  end

  @doc """
  Analyzes connections within a wormhole chain.
  """
  def analyze_wormhole_connections(chain_map, time_window_hours) do
    connections = chain_map.connections

    connection_analysis =
      Enum.map(connections, fn connection ->
        %{
          connection_id: generate_connection_id(connection),
          from_system: connection.from_system_id,
          to_system: connection.to_system_id,
          wormhole_type: connection.type,
          mass_capacity: calculate_mass_capacity(connection.type),
          stability: determine_stability(connection.type),
          estimated_lifetime_hours: get_wormhole_lifetime(connection.type),
          strategic_value: assess_connection_strategic_value(connection, chain_map),
          threat_level: assess_connection_threat_level(connection),
          created_at: DateTime.utc_now()
        }
      end)

    {:ok,
     %{
       total_connections: Kernel.length(connections),
       connection_details: connection_analysis,
       critical_connections: identify_critical_connections(connection_analysis),
       chain_mass_capacity: calculate_total_mass_capacity(connection_analysis),
       analysis_timestamp: DateTime.utc_now()
     }}
  end

  @doc """
  Estimates traffic volume through a wormhole connection.
  """
  def estimate_traffic_volume(connection, time_window_hours) do
    # Simplified traffic estimation
    # In production, would analyze actual jump logs and ship movements
    base_traffic = :rand.uniform(20) + 5

    %{
      ships_per_hour: base_traffic,
      total_ships: base_traffic * time_window_hours,
      peak_traffic_time: estimate_peak_traffic_time(),
      traffic_pattern: classify_traffic_pattern(base_traffic)
    }
  end

  @doc """
  Estimates time until wormhole collapse based on mass usage.
  """
  def estimate_collapse_time(connection_data) do
    remaining_mass = connection_data.mass_capacity * (connection_data.stability / 100)
    # 100m kg average
    average_ship_mass = 100_000_000
    ships_per_hour = connection_data.traffic_volume.ships_per_hour

    hours_until_collapse = remaining_mass / (ships_per_hour * average_ship_mass)

    %{
      estimated_hours: Float.round(hours_until_collapse, 1),
      confidence: calculate_collapse_confidence(connection_data),
      factors: [
        "current_stability: #{connection_data.stability}%",
        "traffic_rate: #{ships_per_hour} ships/hour",
        "remaining_mass: #{remaining_mass}"
      ]
    }
  end

  # Private functions

  defp simulate_wormhole_chain(starting_system_id, max_depth) do
    # Simulate a chain structure for development
    # In production, this would integrate with actual wormhole mapping data

    connections = generate_simulated_connections(starting_system_id, max_depth)
    systems = extract_systems_from_connections(connections)

    {:ok,
     %{
       root_system_id: starting_system_id,
       systems: systems,
       connections: connections,
       max_depth: max_depth,
       mapped_at: DateTime.utc_now()
     }}
  end

  defp generate_simulated_connections(starting_system_id, max_depth) do
    # Generate a tree-like structure of connections
    generate_connections_recursive(starting_system_id, 0, max_depth, [])
  end

  defp generate_connections_recursive(_system_id, current_depth, max_depth, acc)
       when current_depth >= max_depth do
    acc
  end

  defp generate_connections_recursive(system_id, current_depth, max_depth, acc) do
    # Generate 1-3 connections from this system
    num_connections = :rand.uniform(3)

    new_connections =
      Enum.map(1..num_connections, fn i ->
        to_system_id = system_id + (current_depth + 1) * 1000 + i

        %{
          from_system_id: system_id,
          to_system_id: to_system_id,
          type: determine_wormhole_type(current_depth),
          depth: current_depth + 1
        }
      end)

    # Recursively generate connections from the new systems
    deeper_connections =
      Enum.flat_map(new_connections, fn conn ->
        generate_connections_recursive(
          conn.to_system_id,
          current_depth + 1,
          max_depth,
          []
        )
      end)

    acc ++ new_connections ++ deeper_connections
  end

  defp extract_systems_from_connections(connections) do
    all_systems =
      connections
      |> Enum.flat_map(fn conn -> [conn.from_system_id, conn.to_system_id] end)
      |> Enum.uniq()

    Enum.map(all_systems, fn system_id ->
      %{
        system_id: system_id,
        security_class: classify_system_security(system_id),
        static_connections: count_system_connections(system_id, connections)
      }
    end)
  end

  defp classify_system_security(system_id) do
    # Simplified classification
    case Kernel.rem(system_id, 6) do
      0 -> "C1"
      1 -> "C2"
      2 -> "C3"
      3 -> "C4"
      4 -> "C5"
      _ -> "C6"
    end
  end

  defp count_system_connections(system_id, connections) do
    Enum.count(connections, fn conn ->
      conn.from_system_id == system_id or conn.to_system_id == system_id
    end)
  end

  defp determine_wormhole_type(depth) do
    # Wormhole types based on depth in chain
    # Deeper connections tend to be higher class
    cond do
      depth == 0 -> Enum.random(["C2", "C3"])
      depth == 1 -> Enum.random(["C2", "C3", "C4"])
      depth == 2 -> Enum.random(["C3", "C4", "C5"])
      true -> Enum.random(["C4", "C5", "C6"])
    end
  end

  defp calculate_mass_capacity(wormhole_type) do
    case Map.get(@wormhole_types, wormhole_type) do
      # Default 2B kg
      nil -> 2_000_000_000
      type_info -> type_info.mass_limit
    end
  end

  defp determine_stability(wormhole_type) do
    # Stability as percentage (100% = fresh, 0% = critical)
    # Simulate various stability states
    case :rand.uniform(4) do
      # Fresh (90-100%)
      1 -> 90 + :rand.uniform(10)
      # Stable (50-90%)
      2 -> 50 + :rand.uniform(40)
      # Destabilized (20-50%)
      3 -> 20 + :rand.uniform(30)
      # Critical (5-20%)
      4 -> 5 + :rand.uniform(15)
    end
  end

  defp get_wormhole_lifetime(wormhole_type) do
    case Map.get(@wormhole_types, wormhole_type) do
      # Default 16 hours
      nil -> 16
      type_info -> type_info.lifetime
    end
  end

  defp generate_connection_id(connection) do
    "WH-#{connection.from_system_id}-#{connection.to_system_id}-#{:rand.uniform(9999)}"
  end

  defp assess_connection_strategic_value(connection, chain_map) do
    # Assess based on position in chain and connected systems
    depth_score = max(0, 10 - connection.depth) * 10

    # Check if it's a bottleneck (only connection between chain segments)
    bottleneck_score = if is_bottleneck?(connection, chain_map), do: 30, else: 0

    # Higher class wormholes have more strategic value
    type_score =
      case connection.type do
        "C6" -> 30
        "C5" -> 25
        "C4" -> 20
        "C3" -> 15
        "C2" -> 10
        _ -> 5
      end

    min(100, depth_score + bottleneck_score + type_score)
  end

  defp is_bottleneck?(connection, chain_map) do
    # Check if removing this connection would split the chain
    # Simplified check - in production would use graph algorithms
    connections_from_source =
      Enum.count(chain_map.connections, fn c ->
        c.from_system_id == connection.from_system_id
      end)

    connections_from_source == 1
  end

  defp assess_connection_threat_level(connection) do
    # Assess threat based on wormhole characteristics
    base_threat =
      case connection.type do
        # C6 space is dangerous
        "C6" -> 80
        "C5" -> 70
        "C4" -> 50
        "C3" -> 40
        "C2" -> 30
        _ -> 20
      end

    # Add randomness for traffic/activity
    activity_modifier = :rand.uniform(20) - 10

    max(0, min(100, base_threat + activity_modifier))
  end

  defp identify_critical_connections(connection_analysis) do
    connection_analysis
    |> Enum.filter(fn conn ->
      conn.strategic_value >= 70 or
        conn.threat_level >= 70 or
        conn.stability <= 20
    end)
    |> Enum.map(fn conn ->
      %{
        connection_id: conn.connection_id,
        reason: determine_critical_reason(conn),
        priority: calculate_priority(conn)
      }
    end)
  end

  defp determine_critical_reason(conn) do
    cond do
      conn.stability <= 20 -> "critical_stability"
      conn.threat_level >= 70 -> "high_threat"
      conn.strategic_value >= 70 -> "high_strategic_value"
      true -> "unknown"
    end
  end

  defp calculate_priority(conn) do
    stability_priority = if conn.stability <= 20, do: 30, else: 0
    threat_priority = max(0, conn.threat_level - 50)
    strategic_priority = max(0, conn.strategic_value - 50)

    stability_priority + threat_priority + strategic_priority
  end

  defp calculate_total_mass_capacity(connection_analysis) do
    connection_analysis
    |> Enum.map(& &1.mass_capacity)
    |> Enum.sum()
  end

  defp estimate_peak_traffic_time() do
    # Simulate peak traffic times
    hour = :rand.uniform(24) - 1

    ~T[00:00:00]
    |> Time.add(hour * 3600)
  end

  defp classify_traffic_pattern(ships_per_hour) do
    cond do
      ships_per_hour < 10 -> "light"
      ships_per_hour < 20 -> "moderate"
      ships_per_hour < 30 -> "heavy"
      true -> "extreme"
    end
  end

  defp calculate_collapse_confidence(connection_data) do
    # Confidence based on stability and data quality
    stability_factor = connection_data.stability / 100
    # Simulated data quality
    data_quality_factor = 0.8

    Float.round(stability_factor * data_quality_factor * 100, 1)
  end
end
