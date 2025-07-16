defmodule EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Correlators.ThreatCorrelator do
  @moduledoc """
  Correlator for threat patterns across multiple systems.
  """

  alias EveDmv.Repo
  import Ecto.Query
  require Logger

  @doc """
  Correlate threat patterns across systems.
  """
  def correlate_threats(system_ids, _options \\ []) do
    Logger.debug("Correlating threats across #{length(system_ids)} systems")

    %{
      threat_correlation_strength: calculate_threat_correlation_strength(system_ids),
      correlated_threats: identify_correlated_threats(system_ids),
      threat_spillover: analyze_threat_spillover(system_ids),
      threat_escalation_patterns: analyze_threat_escalation(system_ids)
    }
  end

  defp calculate_threat_correlation_strength(system_ids) do
    # Calculate threat correlation strength based on shared threat entities
    if length(system_ids) < 2 do
      0.0
    else
      # Get threat data for all systems
      threat_data = fetch_threat_data(system_ids)
      
      if map_size(threat_data) == 0 do
        0.0
      else
        # Calculate how many threat entities appear in multiple systems
        threat_entities = 
          threat_data
          |> Enum.flat_map(fn {_system_id, threats} -> 
            threats |> Enum.map(& &1.attacker_alliance_id)
          end)
          |> Enum.filter(& &1) # Remove nil values
          |> Enum.frequencies()
        
        # Count entities active in multiple systems
        multi_system_threats = 
          threat_entities
          |> Enum.count(fn {_entity, count} -> count > 1 end)
        
        total_threats = map_size(threat_entities)
        
        if total_threats > 0 do
          # Calculate correlation strength
          base_correlation = multi_system_threats / total_threats
          
          # Adjust for system count
          system_factor = min(1.0, length(system_ids) / 5)
          
          Float.round(min(1.0, base_correlation * (1 + system_factor * 0.3)), 2)
        else
          0.0
        end
      end
    end
  end

  defp identify_correlated_threats(system_ids) do
    # Identify specific threat patterns that correlate across systems
    if length(system_ids) < 2 do
      []
    else
      threat_data = fetch_threat_data(system_ids)
      
      # Analyze different threat types
      threat_patterns = []
      
      # Pattern 1: Coordinated PvP activity
      pvp_correlation = analyze_pvp_correlation(threat_data)
      if pvp_correlation.is_correlated do
        threat_patterns = [%{
          type: :coordinated_pvp,
          confidence: pvp_correlation.confidence,
          affected_systems: pvp_correlation.systems,
          entities: pvp_correlation.entities
        } | threat_patterns]
      end
      
      # Pattern 2: Structure attacks
      structure_attacks = analyze_structure_attacks(threat_data)
      if structure_attacks.detected do
        threat_patterns = [%{
          type: :structure_warfare,
          confidence: structure_attacks.confidence,
          affected_systems: structure_attacks.systems,
          target_types: structure_attacks.target_types
        } | threat_patterns]
      end
      
      # Pattern 3: Fleet movements
      fleet_movements = analyze_fleet_movements(threat_data)
      if fleet_movements.detected do
        threat_patterns = [%{
          type: :fleet_operations,
          confidence: fleet_movements.confidence,
          fleet_size: fleet_movements.avg_fleet_size,
          movement_pattern: fleet_movements.pattern
        } | threat_patterns]
      end
      
      # Pattern 4: Capital escalation
      capital_activity = analyze_capital_threats(threat_data)
      if capital_activity.detected do
        threat_patterns = [%{
          type: :capital_escalation,
          confidence: capital_activity.confidence,
          capital_types: capital_activity.ship_types,
          threat_level: :critical
        } | threat_patterns]
      end
      
      threat_patterns
    end
  end

  defp analyze_threat_spillover(system_ids) do
    # Analyze how threats move between systems
    if length(system_ids) < 2 do
      %{
        spillover_detected: false,
        spillover_probability: 0.0,
        spillover_vectors: []
      }
    else
      # Get time-ordered threat data
      threat_timeline = fetch_threat_timeline(system_ids)
      
      # Detect spillover patterns
      spillover_vectors = detect_spillover_patterns(threat_timeline)
      
      spillover_detected = length(spillover_vectors) > 0
      
      # Calculate spillover probability
      spillover_probability = if spillover_detected do
        # Based on historical patterns and current activity
        vector_strength = spillover_vectors
          |> Enum.map(& &1.confidence)
          |> Enum.sum()
          |> Kernel./(length(spillover_vectors))
        
        Float.round(min(1.0, vector_strength * 1.2), 2)
      else
        0.0
      end
      
      %{
        spillover_detected: spillover_detected,
        spillover_probability: spillover_probability,
        spillover_vectors: spillover_vectors,
        spillover_timeline: build_spillover_timeline(spillover_vectors),
        affected_systems: extract_affected_systems(spillover_vectors)
      }
    end
  end

  defp analyze_threat_escalation(system_ids) do
    # Analyze threat escalation patterns across systems
    if length(system_ids) == 0 do
      %{
        escalation_detected: false,
        escalation_indicators: [],
        escalation_probability: 0.0
      }
    else
      # Get recent vs historical threat metrics
      recent_metrics = fetch_recent_threat_metrics(system_ids)
      historical_metrics = fetch_historical_threat_metrics(system_ids)
      
      escalation_indicators = []
      
      # Check for kill rate escalation
      if recent_metrics.kill_rate > historical_metrics.kill_rate * 1.5 do
        escalation_indicators = [%{
          type: :increased_activity,
          severity: :high,
          metric: :kill_rate,
          change_ratio: Float.round(recent_metrics.kill_rate / max(historical_metrics.kill_rate, 0.1), 2)
        } | escalation_indicators]
      end
      
      # Check for value escalation
      if recent_metrics.avg_kill_value > historical_metrics.avg_kill_value * 2 do
        escalation_indicators = [%{
          type: :higher_stakes,
          severity: :medium,
          metric: :kill_value,
          change_ratio: Float.round(recent_metrics.avg_kill_value / max(historical_metrics.avg_kill_value, 1), 2)
        } | escalation_indicators]
      end
      
      # Check for gang size escalation
      if recent_metrics.avg_gang_size > historical_metrics.avg_gang_size * 1.3 do
        escalation_indicators = [%{
          type: :larger_fleets,
          severity: :medium,
          metric: :gang_size,
          change_ratio: Float.round(recent_metrics.avg_gang_size / max(historical_metrics.avg_gang_size, 1), 2)
        } | escalation_indicators]
      end
      
      # Check for geographic escalation
      if recent_metrics.active_systems > historical_metrics.active_systems * 1.5 do
        escalation_indicators = [%{
          type: :geographic_expansion,
          severity: :high,
          metric: :system_spread,
          change_ratio: Float.round(recent_metrics.active_systems / max(historical_metrics.active_systems, 1), 2)
        } | escalation_indicators]
      end
      
      escalation_detected = length(escalation_indicators) > 0
      escalation_probability = calculate_escalation_probability(escalation_indicators)
      
      %{
        escalation_detected: escalation_detected,
        escalation_indicators: escalation_indicators,
        escalation_probability: escalation_probability,
        escalation_trajectory: predict_escalation_trajectory(escalation_indicators),
        recommended_response: recommend_response(escalation_indicators)
      }
    end
  end
  
  # Helper functions
  
  defp fetch_threat_data(system_ids) do
    # Fetch killmail data for threat analysis
    start_time = DateTime.add(DateTime.utc_now(), -24 * 3600, :second)
    
    query = from k in "killmails_enriched",
      where: k.solar_system_id in ^system_ids and k.killmail_time >= ^start_time,
      select: %{
        killmail_id: k.killmail_id,
        solar_system_id: k.solar_system_id,
        killmail_time: k.killmail_time,
        victim_alliance_id: k.victim_alliance_id,
        victim_corporation_id: k.victim_corporation_id,
        victim_ship_type_id: k.victim_ship_type_id,
        attacker_count: k.attacker_count,
        total_value: k.total_value,
        # Note: In real implementation, would parse attacker data from raw_data
        attacker_alliance_id: k.victim_alliance_id # Placeholder
      },
      limit: 5000
    
    killmails = Repo.all(query)
    
    # Group by system
    killmails
    |> Enum.group_by(& &1.solar_system_id)
  rescue
    error ->
      Logger.error("Failed to fetch threat data: #{inspect(error)}")
      %{}
  end
  
  defp analyze_pvp_correlation(threat_data) do
    # Analyze if PvP activity is correlated across systems
    if map_size(threat_data) < 2 do
      %{is_correlated: false, confidence: 0.0, systems: [], entities: []}
    else
      # Check for simultaneous activity
      time_windows = create_time_windows(threat_data)
      simultaneous_activity = find_simultaneous_activity(time_windows)
      
      # Check for same entities across systems
      common_entities = find_common_threat_entities(threat_data)
      
      is_correlated = length(simultaneous_activity) > 3 or length(common_entities) > 2
      confidence = calculate_correlation_confidence(simultaneous_activity, common_entities)
      
      %{
        is_correlated: is_correlated,
        confidence: confidence,
        systems: Map.keys(threat_data),
        entities: common_entities
      }
    end
  end
  
  defp analyze_structure_attacks(threat_data) do
    # Detect structure warfare patterns
    structure_kills = 
      threat_data
      |> Enum.flat_map(fn {_system, kills} -> kills end)
      |> Enum.filter(fn kill -> 
        # Structure type IDs typically > 35000
        kill.victim_ship_type_id && kill.victim_ship_type_id > 35000
      end)
    
    if length(structure_kills) > 0 do
      affected_systems = structure_kills |> Enum.map(& &1.solar_system_id) |> Enum.uniq()
      target_types = structure_kills |> Enum.map(& &1.victim_ship_type_id) |> Enum.uniq()
      
      %{
        detected: true,
        confidence: min(1.0, length(structure_kills) * 0.2),
        systems: affected_systems,
        target_types: target_types,
        structure_count: length(structure_kills)
      }
    else
      %{detected: false, confidence: 0.0, systems: [], target_types: []}
    end
  end
  
  defp analyze_fleet_movements(threat_data) do
    # Detect coordinated fleet operations
    fleet_indicators = 
      threat_data
      |> Enum.flat_map(fn {_system, kills} -> 
        # Group kills by time window to find fleet ops
        kills
        |> Enum.chunk_by(fn k -> 
          k.killmail_time |> DateTime.truncate(:minute)
        end)
        |> Enum.filter(fn chunk -> length(chunk) > 3 end)
      end)
    
    if length(fleet_indicators) > 0 do
      avg_fleet_size = 
        fleet_indicators
        |> Enum.map(&length/1)
        |> Enum.sum()
        |> Kernel./(length(fleet_indicators))
      
      pattern = cond do
        avg_fleet_size > 20 -> :large_fleet
        avg_fleet_size > 10 -> :medium_fleet
        avg_fleet_size > 5 -> :small_gang
        true -> :skirmish
      end
      
      %{
        detected: true,
        confidence: min(1.0, length(fleet_indicators) * 0.15),
        avg_fleet_size: Float.round(avg_fleet_size, 1),
        pattern: pattern,
        fleet_count: length(fleet_indicators)
      }
    else
      %{detected: false, confidence: 0.0, avg_fleet_size: 0, pattern: :none}
    end
  end
  
  defp analyze_capital_threats(threat_data) do
    # Detect capital ship involvement
    capital_kills = 
      threat_data
      |> Enum.flat_map(fn {_system, kills} -> kills end)
      |> Enum.filter(fn kill -> 
        # Capital ship type IDs
        kill.victim_ship_type_id && kill.victim_ship_type_id > 20000 && kill.victim_ship_type_id < 30000
      end)
    
    if length(capital_kills) > 0 do
      ship_types = capital_kills |> Enum.map(& &1.victim_ship_type_id) |> Enum.uniq()
      
      %{
        detected: true,
        confidence: min(1.0, length(capital_kills) * 0.3),
        ship_types: ship_types,
        capital_count: length(capital_kills)
      }
    else
      %{detected: false, confidence: 0.0, ship_types: []}
    end
  end
  
  defp fetch_threat_timeline(system_ids) do
    # Fetch time-ordered threat data for spillover analysis
    start_time = DateTime.add(DateTime.utc_now(), -48 * 3600, :second)
    
    query = from k in "killmails_enriched",
      where: k.solar_system_id in ^system_ids and k.killmail_time >= ^start_time,
      select: %{
        killmail_id: k.killmail_id,
        solar_system_id: k.solar_system_id,
        killmail_time: k.killmail_time,
        attacker_alliance_id: k.victim_alliance_id # Placeholder
      },
      order_by: [asc: k.killmail_time],
      limit: 2000
    
    Repo.all(query)
  rescue
    error ->
      Logger.error("Failed to fetch threat timeline: #{inspect(error)}")
      []
  end
  
  defp detect_spillover_patterns(threat_timeline) do
    # Detect threats moving between systems
    if length(threat_timeline) < 10 do
      []
    else
      # Group by entity and analyze movement
      entity_movements = 
        threat_timeline
        |> Enum.group_by(& &1.attacker_alliance_id)
        |> Enum.filter(fn {entity, _} -> entity != nil end)
        |> Enum.flat_map(fn {entity, events} ->
          # Find sequential system changes
          events
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.filter(fn [e1, e2] -> 
            e1.solar_system_id != e2.solar_system_id and
            DateTime.diff(e2.killmail_time, e1.killmail_time, :hour) < 3
          end)
          |> Enum.map(fn [e1, e2] ->
            %{
              entity: entity,
              from_system: e1.solar_system_id,
              to_system: e2.solar_system_id,
              time_gap: DateTime.diff(e2.killmail_time, e1.killmail_time, :minute),
              confidence: 0.7
            }
          end)
        end)
      
      # Aggregate and return top spillover vectors
      entity_movements
      |> Enum.group_by(fn m -> {m.from_system, m.to_system} end)
      |> Enum.map(fn {{from, to}, movements} ->
        %{
          from_system: from,
          to_system: to,
          frequency: length(movements),
          entities: movements |> Enum.map(& &1.entity) |> Enum.uniq(),
          avg_time_gap: Enum.sum(Enum.map(movements, & &1.time_gap)) / length(movements),
          confidence: min(1.0, length(movements) * 0.2)
        }
      end)
      |> Enum.sort_by(& &1.frequency, :desc)
      |> Enum.take(5)
    end
  end
  
  defp build_spillover_timeline(spillover_vectors) do
    # Build a timeline of spillover events
    spillover_vectors
    |> Enum.map(fn vector ->
      %{
        route: [vector.from_system, vector.to_system],
        frequency: vector.frequency,
        typical_delay: "#{round(vector.avg_time_gap)} minutes"
      }
    end)
  end
  
  defp extract_affected_systems(spillover_vectors) do
    spillover_vectors
    |> Enum.flat_map(fn v -> [v.from_system, v.to_system] end)
    |> Enum.uniq()
    |> Enum.sort()
  end
  
  defp fetch_recent_threat_metrics(system_ids) do
    # Get metrics for last 24 hours
    start_time = DateTime.add(DateTime.utc_now(), -24 * 3600, :second)
    fetch_threat_metrics(system_ids, start_time)
  end
  
  defp fetch_historical_threat_metrics(system_ids) do
    # Get metrics for 3-7 days ago
    start_time = DateTime.add(DateTime.utc_now(), -7 * 24 * 3600, :second)
    end_time = DateTime.add(DateTime.utc_now(), -3 * 24 * 3600, :second)
    fetch_threat_metrics(system_ids, start_time, end_time)
  end
  
  defp fetch_threat_metrics(system_ids, start_time, end_time \\ nil) do
    end_time = end_time || DateTime.utc_now()
    
    query = from k in "killmails_enriched",
      where: k.solar_system_id in ^system_ids and 
             k.killmail_time >= ^start_time and 
             k.killmail_time <= ^end_time,
      select: %{
        kill_count: count(k.killmail_id),
        total_value: sum(k.total_value),
        total_attackers: sum(k.attacker_count),
        unique_systems: count(fragment("DISTINCT ?", k.solar_system_id))
      }
    
    result = Repo.one(query) || %{}
    
    hours = DateTime.diff(end_time, start_time, :hour)
    kill_count = Map.get(result, :kill_count, 0)
    
    %{
      kill_rate: if(hours > 0, do: kill_count / hours, else: 0),
      avg_kill_value: if(kill_count > 0, do: Map.get(result, :total_value, 0) / kill_count, else: 0),
      avg_gang_size: if(kill_count > 0, do: Map.get(result, :total_attackers, 0) / kill_count, else: 0),
      active_systems: Map.get(result, :unique_systems, 0)
    }
  rescue
    error ->
      Logger.error("Failed to fetch threat metrics: #{inspect(error)}")
      %{kill_rate: 0, avg_kill_value: 0, avg_gang_size: 0, active_systems: 0}
  end
  
  defp calculate_escalation_probability(indicators) do
    if length(indicators) == 0 do
      0.0
    else
      # Weight by severity
      severity_weights = %{high: 0.4, medium: 0.3, low: 0.2}
      
      weighted_sum = 
        indicators
        |> Enum.map(fn ind -> 
          weight = Map.get(severity_weights, ind.severity, 0.1)
          weight * min(ind.change_ratio, 3) / 3
        end)
        |> Enum.sum()
      
      Float.round(min(1.0, weighted_sum), 2)
    end
  end
  
  defp predict_escalation_trajectory(indicators) do
    cond do
      length(indicators) == 0 -> :stable
      length(Enum.filter(indicators, & &1.severity == :high)) > 1 -> :rapid_escalation
      Enum.any?(indicators, & &1.type == :geographic_expansion) -> :expanding
      Enum.any?(indicators, & &1.type == :larger_fleets) -> :intensifying
      true -> :gradual_escalation
    end
  end
  
  defp recommend_response(indicators) do
    severity_count = indicators |> Enum.filter(& &1.severity == :high) |> length()
    
    cond do
      severity_count >= 2 -> :immediate_defensive_posture
      severity_count == 1 -> :heightened_alert
      length(indicators) > 2 -> :increased_monitoring
      length(indicators) > 0 -> :standard_vigilance
      true -> :normal_operations
    end
  end
  
  defp create_time_windows(threat_data) do
    # Create 15-minute time windows for correlation analysis
    threat_data
    |> Enum.flat_map(fn {system, kills} ->
      kills |> Enum.map(fn k -> {system, k.killmail_time |> DateTime.truncate(:minute)} end)
    end)
    |> Enum.group_by(&elem(&1, 1))
  end
  
  defp find_simultaneous_activity(time_windows) do
    # Find time windows with activity in multiple systems
    time_windows
    |> Enum.filter(fn {_time, entries} -> 
      systems = entries |> Enum.map(&elem(&1, 0)) |> Enum.uniq()
      length(systems) > 1
    end)
    |> Enum.map(fn {time, entries} ->
      systems = entries |> Enum.map(&elem(&1, 0)) |> Enum.uniq()
      %{time: time, systems: systems, correlation_strength: length(systems) / 10}
    end)
  end
  
  defp find_common_threat_entities(threat_data) do
    # Find entities active in multiple systems
    threat_data
    |> Enum.flat_map(fn {system, kills} ->
      kills |> Enum.map(fn k -> {k.attacker_alliance_id, system} end)
    end)
    |> Enum.filter(fn {entity, _} -> entity != nil end)
    |> Enum.group_by(&elem(&1, 0))
    |> Enum.filter(fn {_entity, locations} -> 
      systems = locations |> Enum.map(&elem(&1, 1)) |> Enum.uniq()
      length(systems) > 1
    end)
    |> Enum.map(fn {entity, _} -> entity end)
  end
  
  defp calculate_correlation_confidence(simultaneous_activity, common_entities) do
    activity_score = min(1.0, length(simultaneous_activity) * 0.1)
    entity_score = min(1.0, length(common_entities) * 0.15)
    
    combined_score = (activity_score + entity_score) / 2
    Float.round(combined_score, 2)
  end
end
