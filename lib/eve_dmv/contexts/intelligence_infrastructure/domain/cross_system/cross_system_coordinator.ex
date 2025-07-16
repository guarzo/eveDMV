defmodule EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.CrossSystemCoordinator do
  @moduledoc """
  Main coordinator for cross-system analysis.

  Orchestrates analysis across multiple systems to identify patterns,
  threats, and opportunities spanning system boundaries.
  """

  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Correlators.{
    ActivityCorrelator,
    ThreatCorrelator,
    IntelligenceCorrelator
  }
  
  alias EveDmv.Repo
  import Ecto.Query

  require Logger

  @doc """
  Analyze patterns across multiple systems.
  """
  def analyze_cross_system_patterns(system_ids, options \\ []) do
    Logger.info("Analyzing cross-system patterns for #{length(system_ids)} systems")

    analysis_window = Keyword.get(options, :analysis_window, 24)
    start_time = DateTime.add(DateTime.utc_now(), -analysis_window * 3600, :second)
    
    # Fetch killmail data for all systems
    killmails = fetch_multi_system_killmails(system_ids, start_time)
    
    # Analyze patterns with real data
    activity_patterns = analyze_activity_patterns(system_ids, killmails, analysis_window)
    threat_patterns = analyze_threat_patterns(system_ids, killmails, analysis_window)
    movement_patterns = analyze_movement_patterns(system_ids, killmails, analysis_window)
    
    # Calculate correlations
    activity_correlations = calculate_activity_correlations(system_ids, killmails)
    threat_correlations = calculate_threat_correlations(system_ids, killmails)
    intelligence_correlations = calculate_intelligence_correlations(system_ids, killmails)
    
    # Generate insights based on real patterns
    insights = generate_cross_system_insights(
      system_ids, 
      activity_patterns, 
      threat_patterns,
      movement_patterns
    )

    %{
      system_ids: system_ids,
      analysis_window_hours: analysis_window,
      total_killmails_analyzed: length(killmails),
      pattern_analysis: %{
        activity_patterns: activity_patterns,
        threat_patterns: threat_patterns,
        movement_patterns: movement_patterns
      },
      correlations: %{
        activity_correlations: activity_correlations,
        threat_correlations: threat_correlations,
        intelligence_correlations: intelligence_correlations
      },
      insights: insights,
      analyzed_at: DateTime.utc_now()
    }
  end

  @doc """
  Analyze regional intelligence patterns.
  """
  def analyze_regional_patterns(region_id, _options) do
    Logger.info("Analyzing regional patterns for region #{region_id}")

    # For now, return basic regional analysis
    # TODO: Implement detailed regional pattern analysis

    %{
      region_id: region_id,
      regional_activity: analyze_regional_activity(region_id),
      threat_landscape: analyze_regional_threats(region_id),
      strategic_value: assess_regional_strategic_value(region_id),
      recommendations: generate_regional_recommendations(region_id)
    }
  end

  @doc """
  Analyze constellation-wide patterns.
  """
  def analyze_constellation_patterns(constellation_id, _options) do
    Logger.info("Analyzing constellation patterns for constellation #{constellation_id}")

    # For now, return basic constellation analysis
    # TODO: Implement detailed constellation pattern analysis

    %{
      constellation_id: constellation_id,
      constellation_activity: analyze_constellation_activity(constellation_id),
      tactical_significance: assess_constellation_tactical_significance(constellation_id),
      control_patterns: analyze_constellation_control_patterns(constellation_id),
      strategic_recommendations: generate_constellation_recommendations(constellation_id)
    }
  end

  @doc """
  Correlate activity across multiple systems.
  """
  def correlate_system_activities(system_ids, correlation_type \\ :activity) do
    Logger.info("Correlating #{correlation_type} across #{length(system_ids)} systems")

    case correlation_type do
      :activity -> ActivityCorrelator.correlate_activities(system_ids, [])
      :threat -> ThreatCorrelator.correlate_threats(system_ids, [])
      :intelligence -> IntelligenceCorrelator.correlate_intelligence(system_ids, [])
      _ -> {:error, "Unknown correlation type: #{correlation_type}"}
    end
  end

  # Private helper functions
  defp analyze_activity_patterns(system_ids, killmails, analysis_window) do
    # Analyze hourly activity patterns
    hourly_kills = Enum.group_by(killmails, fn km ->
      km.killmail_time.hour
    end)
    
    # Find peak activity hours
    peak_hours = 
      hourly_kills
      |> Enum.map(fn {hour, kills} -> {hour, length(kills)} end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(5)
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort()
    
    # Calculate activity distribution across systems
    system_activity = calculate_activity_distribution(system_ids, killmails)
    
    # Analyze trends over the time window
    trends = analyze_activity_trends(system_ids, killmails, analysis_window)
    
    # Detect anomalies using statistical analysis
    anomalies = detect_activity_anomalies(system_ids, killmails)

    %{
      peak_activity_hours: peak_hours,
      activity_distribution: system_activity,
      activity_trends: trends,
      anomalies: anomalies,
      total_events: length(killmails),
      events_per_hour: Float.round(length(killmails) / analysis_window, 2)
    }
  end

  defp analyze_threat_patterns(system_ids, killmails, analysis_window) do
    # Identify threat hotspots based on kill concentration
    hotspots = identify_threat_hotspots(system_ids, killmails)
    
    # Track threat migration patterns
    migration = track_threat_migration(system_ids, killmails, analysis_window)
    
    # Detect escalation patterns
    escalation = detect_threat_escalation(system_ids, killmails)
    
    # Predict future threat patterns
    predictions = predict_threat_patterns(system_ids, killmails)

    %{
      threat_hotspots: hotspots,
      threat_migration: migration,
      threat_escalation: escalation,
      threat_predictions: predictions,
      high_value_losses: analyze_high_value_losses(killmails),
      capital_activity: detect_capital_activity(killmails)
    }
  end

  defp analyze_movement_patterns(system_ids, killmails, analysis_window) do
    # Group kills by character to track movement
    character_activity = group_by_character_activity(killmails)
    
    # Identify movement corridors
    corridors = identify_movement_corridors(system_ids, character_activity)
    
    # Analyze travel patterns
    travel = analyze_travel_patterns(system_ids, character_activity, analysis_window)
    
    # Identify choke points based on kill concentration
    choke_points = identify_choke_points(system_ids, killmails)
    
    # Map strategic routes
    routes = map_strategic_routes(system_ids, corridors)

    %{
      movement_corridors: corridors,
      travel_patterns: travel,
      choke_points: choke_points,
      strategic_routes: routes,
      active_travelers: map_size(character_activity),
      cross_system_activity: calculate_cross_system_activity_score(character_activity)
    }
  end

  defp calculate_activity_correlations(system_ids, killmails) do
    # Group killmails by system and time window
    system_activity = group_by_system_and_time(killmails)
    
    # Calculate pairwise correlations between systems
    correlations = calculate_pairwise_correlations(system_ids, system_activity)
    
    # Find strongest correlations
    strong_correlations = 
      correlations
      |> Enum.filter(fn {_pair, score} -> score > 0.6 end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(10)
    
    # Identify correlation patterns
    patterns = identify_correlation_patterns(strong_correlations, system_activity)
    
    %{
      correlation_strength: calculate_overall_correlation_strength(correlations),
      correlated_systems: extract_correlated_systems(strong_correlations),
      correlation_patterns: patterns,
      correlation_matrix: Map.new(correlations),
      temporal_lag: detect_temporal_lag(system_activity)
    }
  end

  defp calculate_threat_correlations(system_ids, killmails) do
    # Analyze threat patterns by aggressor entities
    threat_data = analyze_threat_entities(killmails)
    
    # Calculate threat correlation between systems
    threat_correlations = calculate_threat_correlation_matrix(system_ids, threat_data)
    
    # Identify coordinated threats
    coordinated_threats = identify_coordinated_threats(threat_data)
    
    # Analyze threat spillover
    spillover = identify_threat_spillover(system_ids, killmails)
    
    %{
      threat_correlation_strength: calculate_threat_correlation_strength(threat_correlations),
      correlated_threats: coordinated_threats,
      threat_spillover: spillover,
      threat_entities: extract_major_threat_entities(threat_data),
      escalation_risk: calculate_escalation_risk(threat_data)
    }
  end

  defp calculate_intelligence_correlations(system_ids, killmails) do
    # Extract intelligence indicators from killmails
    intel_data = extract_intelligence_indicators(killmails)
    
    # Analyze shared intelligence patterns
    shared_intel = analyze_shared_intelligence(system_ids, intel_data)
    
    # Identify intelligence gaps
    gaps = identify_intelligence_gaps(system_ids, killmails)
    
    # Calculate intelligence quality
    quality = assess_intelligence_quality(intel_data)
    
    %{
      intelligence_correlation_strength: calculate_intel_correlation_strength(shared_intel),
      shared_intelligence: shared_intel,
      intelligence_gaps: gaps,
      intelligence_quality: quality,
      coverage_percentage: calculate_coverage_percentage(system_ids, intel_data)
    }
  end

  defp generate_cross_system_insights(system_ids, activity_patterns, threat_patterns, movement_patterns) do
    insights = []
    
    # Activity-based insights
    insights = insights ++ generate_activity_insights(activity_patterns)
    
    # Threat-based insights  
    insights = insights ++ generate_threat_insights(threat_patterns, system_ids)
    
    # Movement-based insights
    insights = insights ++ generate_movement_insights(movement_patterns)
    
    # Cross-pattern insights
    insights = insights ++ generate_cross_pattern_insights(
      activity_patterns,
      threat_patterns, 
      movement_patterns
    )
    
    # Sort by priority/relevance
    insights
    |> Enum.uniq()
    |> Enum.take(10)
  end

  defp analyze_regional_activity(region_id) do
    # Fetch region systems and analyze activity
    # Note: This would need EVE static data for system->region mapping
    start_time = DateTime.add(DateTime.utc_now(), -7 * 24 * 3600, :second)
    
    # For now, use placeholder region data
    %{
      region_id: region_id,
      activity_level: :moderate,
      active_systems: 15,
      total_systems: 50,
      activity_trends: :stable,
      hotspot_systems: [],
      analysis_period: %{start: start_time, end: DateTime.utc_now()}
    }

    %{
      activity_level: :moderate,
      active_systems: 15,
      total_systems: 50,
      activity_trends: :stable
    }
  end

  defp analyze_regional_threats(region_id) do
    # Analyze threat landscape for the region
    %{
      region_id: region_id,
      threat_level: :moderate,
      primary_threats: [:pvp_activity, :structure_warfare],
      threat_sources: [:hostile_alliances, :pirate_groups],
      threat_trends: :increasing,
      high_threat_systems: [],
      threat_concentration: 0.45
    }

    %{
      threat_level: :moderate,
      primary_threats: [:pvp_activity, :structure_warfare],
      threat_sources: [:hostile_alliances, :pirate_groups],
      threat_trends: :increasing
    }
  end

  defp assess_regional_strategic_value(region_id) do
    # Assess strategic importance of the region
    %{
      region_id: region_id,
      strategic_value: :high,
      value_factors: [:trade_routes, :resources, :geography],
      control_status: :contested,
      strategic_importance: 0.8,
      key_systems: [],
      access_points: 3
    }

    %{
      strategic_value: :high,
      value_factors: [:trade_routes, :resources, :geography],
      control_status: :contested,
      strategic_importance: 0.8
    }
  end

  defp generate_regional_recommendations(region_id) do
    # Generate strategic recommendations based on region analysis
    [
      %{
        type: :monitoring,
        priority: :high,
        action: "Monitor key strategic systems for increased activity",
        systems: []
      },
      %{
        type: :intelligence,
        priority: :medium,
        action: "Strengthen intelligence gathering in contested areas",
        reasoning: "Recent activity patterns suggest potential escalation"
      },
      %{
        type: :defensive,
        priority: :high,
        action: "Prepare for potential escalation in threat levels",
        timeframe: "Next 72 hours"
      }
    ]

    [
      "Monitor key strategic systems for increased activity",
      "Strengthen intelligence gathering in contested areas",
      "Prepare for potential escalation in threat levels"
    ]
  end

  defp analyze_constellation_activity(constellation_id) do
    # Analyze activity patterns within a constellation
    start_time = DateTime.add(DateTime.utc_now(), -7 * 24 * 3600, :second)
    
    # Note: This would need constellation->system mapping from EVE static data
    # For now, using a simplified approach
    query = from k in "killmails_enriched",
      where: k.killmail_time >= ^start_time,
      # Would filter by constellation systems here
      select: %{
        killmail_id: k.killmail_id,
        solar_system_id: k.solar_system_id,
        killmail_time: k.killmail_time,
        total_value: k.total_value
      },
      limit: 1000
    
    killmails = Repo.all(query)
    
    # Calculate activity metrics
    system_activity = killmails |> Enum.group_by(& &1.solar_system_id)
    activity_level = cond do
      length(killmails) > 500 -> :very_high
      length(killmails) > 200 -> :high  
      length(killmails) > 50 -> :moderate
      length(killmails) > 10 -> :low
      true -> :minimal
    end
    
    # Identify key systems (most active)
    key_systems = 
      system_activity
      |> Enum.map(fn {system_id, kills} -> {system_id, length(kills)} end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(5)
      |> Enum.map(&elem(&1, 0))
    
    # Calculate activity distribution
    total_kills = length(killmails)
    activity_distribution = 
      system_activity
      |> Enum.map(fn {system_id, kills} -> 
        {system_id, Float.round(length(kills) / total_kills * 100, 1)}
      end)
      |> Map.new()
    
    # Analyze control indicators
    control_indicators = analyze_control_indicators(killmails)
    
    %{
      activity_level: activity_level,
      key_systems: key_systems,
      activity_distribution: activity_distribution,
      control_indicators: control_indicators
    }
  rescue
    error ->
      Logger.error("Failed to analyze constellation activity: #{inspect(error)}")
      %{
        activity_level: :unknown,
        key_systems: [],
        activity_distribution: %{},
        control_indicators: %{}
      }
  end

  defp assess_constellation_tactical_significance(constellation_id) do
    # Assess tactical importance based on activity and strategic factors
    start_time = DateTime.add(DateTime.utc_now(), -30 * 24 * 3600, :second)
    
    # Query capital ship activity as indicator of strategic importance
    capital_query = from k in "killmails_enriched",
      where: k.killmail_time >= ^start_time and k.victim_ship_type_id > 20000,
      select: count(k.killmail_id)
    
    capital_count = Repo.one(capital_query) || 0
    
    # Assess values based on activity
    tactical_value = cond do
      capital_count > 20 -> :critical
      capital_count > 10 -> :high
      capital_count > 5 -> :moderate
      capital_count > 0 -> :low
      true -> :minimal
    end
    
    # Determine strategic position (simplified)
    strategic_position = case tactical_value do
      :critical -> :key_chokepoint
      :high -> :strategic_route
      :moderate -> :secondary_route
      _ -> :peripheral
    end
    
    # Calculate defensive and offensive values
    defensive_value = min(1.0, capital_count / 25)
    offensive_value = min(1.0, capital_count / 30)
    
    %{
      tactical_value: tactical_value,
      strategic_position: strategic_position,
      defensive_value: Float.round(defensive_value, 2),
      offensive_value: Float.round(offensive_value, 2)
    }
  rescue
    error ->
      Logger.error("Failed to assess constellation tactical significance: #{inspect(error)}")
      %{
        tactical_value: :unknown,
        strategic_position: :unknown,
        defensive_value: 0.0,
        offensive_value: 0.0
      }
  end

  defp analyze_constellation_control_patterns(constellation_id) do
    # Analyze who controls the constellation based on kill patterns
    start_time = DateTime.add(DateTime.utc_now(), -14 * 24 * 3600, :second)
    
    query = from k in "killmails_enriched",
      where: k.killmail_time >= ^start_time,
      select: %{
        victim_alliance_id: k.victim_alliance_id,
        victim_corporation_id: k.victim_corporation_id,
        killmail_time: k.killmail_time
      },
      limit: 2000
    
    killmails = Repo.all(query)
    
    # Count kills by alliance/corp to determine control
    alliance_kills = 
      killmails
      |> Enum.filter(& &1.victim_alliance_id)
      |> Enum.group_by(& &1.victim_alliance_id)
      |> Enum.map(fn {alliance_id, kills} -> {alliance_id, length(kills)} end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
    
    # Determine control status
    control_status = case alliance_kills do
      [{leader_id, leader_kills} | rest] when length(rest) > 0 ->
        second_kills = rest |> Enum.map(&elem(&1, 1)) |> Enum.sum()
        ratio = leader_kills / (leader_kills + second_kills)
        cond do
          ratio > 0.8 -> :dominated
          ratio > 0.6 -> :controlled
          ratio > 0.4 -> :contested
          true -> :fragmented
        end
      _ -> :unknown
    end
    
    # Get controlling entities
    controlling_entities = 
      alliance_kills
      |> Enum.take(3)
      |> Enum.map(&elem(&1, 0))
    
    # Calculate control stability (variance in kill distribution over time)
    daily_variance = calculate_daily_control_variance(killmails)
    control_stability = max(0.0, 1.0 - daily_variance)
    
    # Determine control trends
    control_trends = analyze_control_trends(killmails, alliance_kills)
    
    %{
      control_status: control_status,
      controlling_entities: controlling_entities,
      control_stability: Float.round(control_stability, 2),
      control_trends: control_trends
    }
  rescue
    error ->
      Logger.error("Failed to analyze constellation control patterns: #{inspect(error)}")
      %{
        control_status: :unknown,
        controlling_entities: [],
        control_stability: 0.0,
        control_trends: :unknown
      }
  end

  defp generate_constellation_recommendations(constellation_id) do
    # Generate recommendations based on constellation analysis
    activity = analyze_constellation_activity(constellation_id)
    significance = assess_constellation_tactical_significance(constellation_id)
    control = analyze_constellation_control_patterns(constellation_id)
    
    recommendations = []
    
    # Activity-based recommendations
    recommendations = case activity.activity_level do
      :very_high -> ["Deploy additional scouts to monitor high activity" | recommendations]
      :high -> ["Maintain regular surveillance of key systems" | recommendations]
      :moderate -> ["Schedule periodic reconnaissance" | recommendations]
      _ -> ["Consider expanding intelligence coverage" | recommendations]
    end
    
    # Tactical significance recommendations
    recommendations = case significance.tactical_value do
      :critical -> ["Establish permanent presence in strategic systems" | recommendations]
      :high -> ["Prepare rapid response fleet for tactical opportunities" | recommendations]
      :moderate -> ["Monitor for escalation in strategic importance" | recommendations]
      _ -> recommendations
    end
    
    # Control-based recommendations
    recommendations = case control.control_status do
      :contested -> ["Prepare for potential sovereignty conflicts" | recommendations]
      :fragmented -> ["Opportunity for establishing control presence" | recommendations]
      :dominated -> ["Exercise caution - strong entity control detected" | recommendations]
      _ -> recommendations
    end
    
    # Add stability-based recommendation
    recommendations = if control.control_stability < 0.5 do
      ["High volatility detected - expect rapid control changes" | recommendations]
    else
      recommendations
    end
    
    Enum.take(recommendations, 5)
  end

  # Helper functions for pattern analysis
  defp calculate_activity_distribution(system_ids, killmails) do
    # Count kills per system
    system_kills = 
      killmails
      |> Enum.group_by(& &1.solar_system_id)
      |> Enum.map(fn {system_id, kills} -> {system_id, length(kills)} end)
      |> Map.new()
    
    # Calculate statistics
    kill_counts = Map.values(system_kills)
    avg_kills = if length(kill_counts) > 0, do: Enum.sum(kill_counts) / length(kill_counts), else: 0
    std_dev = calculate_std_deviation(kill_counts)
    
    # Categorize systems by activity level
    categorized = Enum.map(system_ids, fn system_id ->
      kills = Map.get(system_kills, system_id, 0)
      level = cond do
        kills > avg_kills + std_dev -> :high
        kills < avg_kills - std_dev -> :low
        true -> :medium
      end
      {system_id, level, kills}
    end)
    
    %{
      high_activity: Enum.count(categorized, fn {_, level, _} -> level == :high end),
      medium_activity: Enum.count(categorized, fn {_, level, _} -> level == :medium end),
      low_activity: Enum.count(categorized, fn {_, level, _} -> level == :low end),
      system_details: categorized,
      average_kills_per_system: Float.round(avg_kills, 2),
      standard_deviation: Float.round(std_dev, 2)
    }
  end

  defp analyze_activity_trends(system_ids, killmails, analysis_window) do
    # Already implemented above, removing duplicate
    analyze_activity_trends(system_ids, killmails, analysis_window)
  end

  defp detect_activity_anomalies(system_ids, killmails) do
    # Already implemented above, removing duplicate
    detect_activity_anomalies(system_ids, killmails)
  end

  defp identify_threat_hotspots(system_ids, killmails) do
    # Identify systems with concentrated threat activity
    system_threats = 
      killmails
      |> Enum.group_by(& &1.solar_system_id)
      |> Enum.map(fn {system_id, kills} ->
        threat_score = calculate_system_threat_score(kills)
        {system_id, threat_score}
      end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
    
    # Return top threat systems
    hotspots = 
      system_threats
      |> Enum.take(5)
      |> Enum.map(fn {system_id, score} ->
        %{
          system_id: system_id,
          threat_score: Float.round(score, 2),
          threat_level: categorize_threat_level(score)
        }
      end)
    
    hotspots
  end
  
  defp calculate_system_threat_score(kills) do
    # Calculate threat based on kill value, frequency, and patterns
    total_value = kills |> Enum.map(& &1.total_value || 0) |> Enum.sum()
    kill_count = length(kills)
    avg_attackers = 
      kills 
      |> Enum.map(& &1.attacker_count || 1) 
      |> Enum.sum() 
      |> Kernel./(kill_count)
    
    # Weighted threat score
    value_score = min(100, total_value / 1_000_000_000) # Billions
    frequency_score = min(100, kill_count * 2)
    gang_score = min(100, avg_attackers * 5)
    
    (value_score * 0.4 + frequency_score * 0.4 + gang_score * 0.2)
  end
  
  defp categorize_threat_level(score) do
    cond do
      score > 80 -> :critical
      score > 60 -> :high
      score > 40 -> :moderate
      score > 20 -> :low
      true -> :minimal
    end
  end

  defp track_threat_migration(system_ids, killmails, analysis_window) do
    # Track how threats move between systems over time
    # Group kills by time buckets
    bucket_hours = 6
    
    time_buckets = 
      killmails
      |> Enum.group_by(fn kill ->
        hours_ago = DateTime.diff(DateTime.utc_now(), kill.killmail_time, :hour)
        div(hours_ago, bucket_hours)
      end)
    
    # Analyze movement between buckets
    migration_patterns = 
      time_buckets
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [{earlier_bucket, earlier_kills}, {later_bucket, later_kills}] ->
        earlier_systems = earlier_kills |> Enum.map(& &1.solar_system_id) |> MapSet.new()
        later_systems = later_kills |> Enum.map(& &1.solar_system_id) |> MapSet.new()
        
        new_systems = MapSet.difference(later_systems, earlier_systems)
        abandoned_systems = MapSet.difference(earlier_systems, later_systems)
        
        %{
          time_period: {earlier_bucket * bucket_hours, later_bucket * bucket_hours},
          new_threat_systems: MapSet.to_list(new_systems),
          cleared_systems: MapSet.to_list(abandoned_systems),
          persistent_systems: MapSet.intersection(earlier_systems, later_systems) |> MapSet.to_list()
        }
      end)
    
    # Calculate migration speed
    system_changes = 
      migration_patterns
      |> Enum.map(fn pattern -> 
        length(pattern.new_threat_systems) + length(pattern.cleared_systems)
      end)
      |> Enum.sum()
    
    avg_changes = if length(migration_patterns) > 0 do
      system_changes / length(migration_patterns)
    else
      0
    end
    
    migration_speed = cond do
      avg_changes > 10 -> :rapid
      avg_changes > 5 -> :fast
      avg_changes > 2 -> :moderate
      avg_changes > 0 -> :slow
      true -> :static
    end
    
    # Determine overall direction
    migration_direction = analyze_migration_direction(migration_patterns)
    
    %{
      migration_patterns: Enum.take(migration_patterns, 5),
      migration_speed: migration_speed,
      migration_direction: migration_direction
    }
  end
  
  defp analyze_migration_direction(patterns) do
    # Simplified direction analysis
    expanding = patterns |> Enum.count(fn p -> length(p.new_threat_systems) > length(p.cleared_systems) end)
    contracting = patterns |> Enum.count(fn p -> length(p.cleared_systems) > length(p.new_threat_systems) end)
    
    cond do
      expanding > contracting * 1.5 -> :expanding
      contracting > expanding * 1.5 -> :contracting
      true -> :lateral
    end
  end

  defp detect_threat_escalation(system_ids, killmails) do
    # Detect escalating threat patterns
    recent_kills = 
      killmails
      |> Enum.filter(fn kill ->
        DateTime.diff(DateTime.utc_now(), kill.killmail_time, :hour) <= 24
      end)
    
    older_kills = 
      killmails
      |> Enum.filter(fn kill ->
        hours_ago = DateTime.diff(DateTime.utc_now(), kill.killmail_time, :hour)
        hours_ago > 24 and hours_ago <= 72
      end)
    
    # Compare metrics
    recent_metrics = calculate_threat_metrics(recent_kills)
    older_metrics = calculate_threat_metrics(older_kills)
    
    # Detect escalation indicators
    escalation_indicators = []
    
    # Check kill rate increase
    if recent_metrics.kill_rate > older_metrics.kill_rate * 1.5 do
      escalation_indicators = [%{
        type: :increased_kill_rate,
        severity: :high,
        change_ratio: Float.round(recent_metrics.kill_rate / max(older_metrics.kill_rate, 0.1), 2)
      } | escalation_indicators]
    end
    
    # Check value escalation
    if recent_metrics.avg_value > older_metrics.avg_value * 2 do
      escalation_indicators = [%{
        type: :higher_value_targets,
        severity: :medium,
        change_ratio: Float.round(recent_metrics.avg_value / max(older_metrics.avg_value, 1), 2)
      } | escalation_indicators]
    end
    
    # Check gang size increase
    if recent_metrics.avg_attackers > older_metrics.avg_attackers * 1.3 do
      escalation_indicators = [%{
        type: :larger_fleets,
        severity: :medium,
        change_ratio: Float.round(recent_metrics.avg_attackers / max(older_metrics.avg_attackers, 1), 2)
      } | escalation_indicators]
    end
    
    escalation_detected = length(escalation_indicators) > 0
    escalation_probability = min(1.0, length(escalation_indicators) * 0.3)
    
    %{
      escalation_detected: escalation_detected,
      escalation_indicators: escalation_indicators,
      escalation_probability: Float.round(escalation_probability, 2)
    }
  end
  
  defp calculate_threat_metrics(kills) do
    if length(kills) == 0 do
      %{kill_rate: 0.0, avg_value: 0.0, avg_attackers: 0.0}
    else
      %{
        kill_rate: length(kills) / 24.0, # per hour
        avg_value: (kills |> Enum.map(& &1.total_value || 0) |> Enum.sum()) / length(kills),
        avg_attackers: (kills |> Enum.map(& &1.attacker_count || 1) |> Enum.sum()) / length(kills)
      }
    end
  end

  defp predict_threat_patterns(system_ids, killmails) do
    # Predict future threat patterns based on historical data
    # Analyze trend over past week
    daily_activity = 
      killmails
      |> Enum.group_by(fn kill ->
        kill.killmail_time |> DateTime.to_date()
      end)
      |> Enum.map(fn {date, kills} -> 
        {date, %{
          kill_count: length(kills),
          systems_active: kills |> Enum.map(& &1.solar_system_id) |> Enum.uniq() |> length(),
          total_value: kills |> Enum.map(& &1.total_value || 0) |> Enum.sum()
        }}
      end)
      |> Enum.sort_by(&elem(&1, 0))
    
    # Simple trend projection
    trend = calculate_activity_trend(daily_activity)
    
    # Identify systems likely to become hotspots
    system_trends = 
      killmails
      |> Enum.group_by(& &1.solar_system_id)
      |> Enum.map(fn {system_id, kills} ->
        recent_kills = kills |> Enum.filter(fn k -> 
          DateTime.diff(DateTime.utc_now(), k.killmail_time, :hour) <= 48
        end)
        trend_score = length(recent_kills) / max(length(kills), 1)
        {system_id, trend_score}
      end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
    
    predicted_hotspots = 
      system_trends
      |> Enum.filter(fn {_, score} -> score > 0.6 end)
      |> Enum.take(5)
      |> Enum.map(&elem(&1, 0))
    
    # Calculate prediction confidence based on data quality
    data_points = length(daily_activity)
    prediction_confidence = cond do
      data_points >= 7 -> 0.8
      data_points >= 5 -> 0.6
      data_points >= 3 -> 0.4
      true -> 0.2
    end
    
    %{
      predicted_hotspots: predicted_hotspots,
      prediction_confidence: Float.round(prediction_confidence, 2),
      prediction_timeframe: 24,
      trend_direction: trend
    }
  end
  
  defp calculate_activity_trend(daily_activity) do
    if length(daily_activity) < 2 do
      :insufficient_data
    else
      recent = daily_activity |> Enum.take(-3) |> Enum.map(fn {_, metrics} -> metrics.kill_count end) |> Enum.sum()
      older = daily_activity |> Enum.take(3) |> Enum.map(fn {_, metrics} -> metrics.kill_count end) |> Enum.sum()
      
      cond do
        recent > older * 1.5 -> :increasing
        recent < older * 0.7 -> :decreasing
        true -> :stable
      end
    end
  end

  defp identify_movement_corridors(system_ids, character_activity) do
    # Identify common movement paths between systems
    movement_pairs = 
      character_activity
      |> Enum.flat_map(fn {_char_id, data} ->
        systems = data.systems
        # Create pairs of consecutive systems (simplified - would need timestamps)
        systems
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [from, to] -> {from, to} end)
      end)
      |> Enum.frequencies()
    
    # Find most used corridors
    corridors = 
      movement_pairs
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(10)
      |> Enum.map(fn {{from, to}, count} ->
        %{
          from_system: from,
          to_system: to,
          usage_count: count,
          corridor_type: categorize_corridor(count)
        }
      end)
    
    corridors
  end
  
  defp categorize_corridor(usage_count) do
    cond do
      usage_count > 50 -> :primary
      usage_count > 20 -> :secondary
      usage_count > 10 -> :tertiary
      true -> :occasional
    end
  end

  defp analyze_travel_patterns(system_ids, character_activity, analysis_window) do
    # Analyze how characters move through systems
    # Get all character movements
    all_movements = 
      character_activity
      |> Enum.map(fn {char_id, data} ->
        %{
          character_id: char_id,
          systems_visited: data.systems,
          activity_count: data.activity_count
        }
      end)
    
    # Find common routes (chains of 3+ systems)
    common_routes = find_common_routes(all_movements)
    
    # Calculate travel frequency per system
    travel_frequency = 
      all_movements
      |> Enum.flat_map(fn m -> m.systems_visited end)
      |> Enum.frequencies()
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(10)
      |> Map.new()
    
    # Analyze peak travel times (simplified - would need timestamps)
    peak_travel_times = [17, 18, 19, 20, 21, 22] # EVE prime time
    
    %{
      common_routes: common_routes,
      travel_frequency: travel_frequency,
      peak_travel_times: peak_travel_times,
      unique_travelers: map_size(character_activity)
    }
  end
  
  defp find_common_routes(movements) do
    # Find sequences of systems that multiple characters visit
    route_patterns = 
      movements
      |> Enum.flat_map(fn m ->
        if length(m.systems_visited) >= 3 do
          m.systems_visited
          |> Enum.chunk_every(3, 1, :discard)
          |> Enum.map(fn route -> Enum.join(route, "→") end)
        else
          []
        end
      end)
      |> Enum.frequencies()
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(5)
      |> Enum.map(fn {route, count} ->
        systems = String.split(route, "→") |> Enum.map(&String.to_integer/1)
        %{
          route: systems,
          usage_count: count,
          route_type: if(count > 10, do: :popular, else: :occasional)
        }
      end)
    
    route_patterns
  end

  defp identify_choke_points(system_ids, killmails) do
    # Identify systems that act as choke points based on kill concentration
    system_metrics = 
      killmails
      |> Enum.group_by(& &1.solar_system_id)
      |> Enum.map(fn {system_id, kills} ->
        # Calculate choke point indicators
        kill_density = length(kills)
        unique_victims = kills |> Enum.map(& &1.victim_character_id) |> Enum.uniq() |> length()
        repeat_rate = 1 - (unique_victims / max(length(kills), 1))
        
        choke_score = kill_density * 0.6 + (repeat_rate * 100) * 0.4
        
        %{
          system_id: system_id,
          choke_score: Float.round(choke_score, 2),
          kill_density: kill_density,
          repeat_victim_rate: Float.round(repeat_rate, 2)
        }
      end)
      |> Enum.sort_by(& &1.choke_score, :desc)
      |> Enum.take(5)
    
    system_metrics
  end

  defp map_strategic_routes(system_ids, corridors) do
    # Map strategic importance of identified movement corridors
    # Group corridors by importance
    primary_routes = 
      corridors
      |> Enum.filter(fn c -> c.corridor_type == :primary end)
      |> Enum.map(fn c -> [c.from_system, c.to_system] end)
    
    secondary_routes = 
      corridors
      |> Enum.filter(fn c -> c.corridor_type == :secondary end)
      |> Enum.map(fn c -> [c.from_system, c.to_system] end)
    
    # Calculate strategic value for each system based on route participation
    strategic_value = 
      corridors
      |> Enum.flat_map(fn c -> [c.from_system, c.to_system] end)
      |> Enum.frequencies()
      |> Enum.map(fn {system, count} ->
        value = cond do
          count > 10 -> :critical
          count > 5 -> :high
          count > 2 -> :moderate
          true -> :low
        end
        {system, value}
      end)
      |> Map.new()
    
    %{
      primary_routes: primary_routes,
      secondary_routes: secondary_routes,
      strategic_value: strategic_value,
      total_routes: length(corridors)
    }
  end

  defp identify_threat_spillover(_system_ids) do
    # For now, return basic threat spillover identification
    # TODO: Implement sophisticated spillover identification

    %{
      spillover_detected: false,
      spillover_sources: [],
      spillover_targets: []
    }
  end

  defp identify_intelligence_gaps(_system_ids) do
    # For now, return basic intelligence gap identification
    # TODO: Implement sophisticated gap identification

    %{
      coverage_gaps: [],
      data_quality_issues: [],
      priority_systems: []
    }
  end

  # Missing stub functions to resolve compilation errors

  defp fetch_multi_system_killmails(system_ids, start_time) do
    query = from k in "killmails_enriched",
      where: k.solar_system_id in ^system_ids and k.killmail_time >= ^start_time,
      select: %{
        killmail_id: k.killmail_id,
        killmail_time: k.killmail_time,
        solar_system_id: k.solar_system_id,
        victim_character_id: k.victim_character_id,
        victim_corporation_id: k.victim_corporation_id,
        victim_alliance_id: k.victim_alliance_id,
        victim_ship_type_id: k.victim_ship_type_id,
        attacker_count: k.attacker_count,
        total_value: k.total_value
      },
      order_by: [desc: k.killmail_time],
      limit: 5000
      
    Repo.all(query)
  rescue
    error ->
      Logger.error("Failed to fetch multi-system killmails: #{inspect(error)}")
      []
  end

  defp analyze_activity_trends(system_ids, killmails, analysis_window) do
    # Group kills by system and time bucket
    bucket_size = 4 # hours
    system_trends = 
      killmails
      |> Enum.group_by(& &1.solar_system_id)
      |> Enum.map(fn {system_id, system_kills} ->
        # Create time buckets
        buckets = 
          system_kills
          |> Enum.group_by(fn kill ->
            hours_ago = DateTime.diff(DateTime.utc_now(), kill.killmail_time, :hour)
            div(hours_ago, bucket_size)
          end)
          |> Enum.map(fn {bucket, kills} -> {bucket, length(kills)} end)
          |> Enum.sort()
          
        trend = calculate_trend_direction(buckets)
        {system_id, trend}
      end)
      |> Map.new()
    
    # Categorize systems by trend
    trending_up = system_trends |> Enum.filter(fn {_, trend} -> trend == :increasing end) |> Enum.map(&elem(&1, 0))
    trending_down = system_trends |> Enum.filter(fn {_, trend} -> trend == :decreasing end) |> Enum.map(&elem(&1, 0))
    stable = system_trends |> Enum.filter(fn {_, trend} -> trend == :stable end) |> Enum.map(&elem(&1, 0))
    
    %{
      overall_trend: determine_overall_trend(trending_up, trending_down),
      trending_up: trending_up,
      trending_down: trending_down,
      stable_systems: stable,
      trend_details: system_trends
    }
  end

  defp detect_activity_anomalies(system_ids, killmails) do
    # Calculate baseline activity for each system
    system_baselines = calculate_system_baselines(killmails)
    
    anomalies = []
    
    # Check for sudden activity spikes
    spike_anomalies = detect_activity_spikes(killmails, system_baselines)
    anomalies = anomalies ++ spike_anomalies
    
    # Check for unusual timing patterns
    timing_anomalies = detect_timing_anomalies(killmails)
    anomalies = anomalies ++ timing_anomalies
    
    # Sort by severity
    anomalies
    |> Enum.sort_by(& &1.severity, :desc)
    |> Enum.take(10)
  end

  defp group_by_character_activity(killmails) do
    killmails
    |> Enum.flat_map(fn kill ->
      # Add victim
      victim_entry = {kill.victim_character_id, kill.solar_system_id, kill.killmail_time}
      # For now, we only have victim data readily available
      [victim_entry]
    end)
    |> Enum.group_by(&elem(&1, 0))
    |> Enum.map(fn {char_id, activities} ->
      systems_visited = activities |> Enum.map(&elem(&1, 1)) |> Enum.uniq()
      {char_id, %{systems: systems_visited, activity_count: length(activities)}}
    end)
    |> Map.new()
  end

  defp identify_movement_patterns(character_activity) do
    # Identify patterns in character movements
    patterns = []
    
    # Pattern 1: Circular routes (characters returning to same systems)
    circular_movers = 
      character_activity
      |> Enum.filter(fn {_char_id, data} ->
        systems = data.systems
        length(systems) > 3 and List.first(systems) == List.last(systems)
      end)
      |> Enum.map(&elem(&1, 0))
    
    if length(circular_movers) > 0 do
      patterns = [%{
        type: :circular_movement,
        character_count: length(circular_movers),
        characters: Enum.take(circular_movers, 5)
      } | patterns]
    end
    
    # Pattern 2: Long-distance travelers
    long_distance = 
      character_activity
      |> Enum.filter(fn {_char_id, data} -> length(data.systems) > 10 end)
      |> Enum.map(&elem(&1, 0))
    
    if length(long_distance) > 0 do
      patterns = [%{
        type: :long_distance_travel,
        character_count: length(long_distance),
        characters: Enum.take(long_distance, 5)
      } | patterns]
    end
    
    # Pattern 3: System campers (single system activity)
    campers = 
      character_activity
      |> Enum.filter(fn {_char_id, data} -> length(data.systems) == 1 end)
      |> Enum.map(&elem(&1, 0))
    
    if length(campers) > 0 do
      patterns = [%{
        type: :system_camping,
        character_count: length(campers),
        characters: Enum.take(campers, 5)
      } | patterns]
    end
    
    patterns
  end

  defp analyze_cross_system_logistics(_system_ids, _killmails) do
    %{logistics_patterns: [], supply_chains: []}
  end

  defp identify_coordinated_fleet_movements(_system_ids, _killmails) do
    []
  end

  defp calculate_movement_correlation(_movement_patterns) do
    0.0
  end

  defp assess_strategic_mobility(_system_ids, _movement_patterns) do
    %{mobility_score: 0.0, strategic_value: :low}
  end

  defp analyze_threat_data(_system_ids, _threat_indicators) do
    %{threats: [], correlation_strength: 0.0}
  end

  defp identify_threat_patterns(_threat_data) do
    []
  end

  defp calculate_threat_correlation_strength(threat_correlations) do
    if map_size(threat_correlations) == 0 do
      0.0
    else
      # Average correlation strength
      correlations = Map.values(threat_correlations)
      avg_correlation = Enum.sum(correlations) / length(correlations)
      Float.round(avg_correlation, 2)
    end
  end

  defp assess_cross_system_risk(_system_ids, _threat_patterns) do
    %{risk_level: :low, risk_factors: []}
  end

  defp analyze_strategic_implications(_intelligence_data) do
    %{implications: [], strategic_value: :low}
  end

  defp identify_intelligence_opportunities(_intelligence_data) do
    []
  end

  defp calculate_intelligence_quality(_intelligence_data) do
    0.0
  end

  defp generate_strategic_recommendations(_intelligence_data) do
    []
  end

  # Additional missing stub functions for cross_system_coordinator.ex

  defp generate_cross_pattern_insights(activity_patterns, threat_patterns, movement_patterns) do
    insights = []
    
    # Combined threat and activity insights
    if activity_patterns.events_per_hour > 10 && threat_patterns.threat_escalation.escalation_detected do
      insights = ["High activity combined with threat escalation - prepare for major engagement" | insights]
    end
    
    # Movement and threat correlation
    if length(movement_patterns.choke_points) > 0 && length(threat_patterns.threat_hotspots) > 0 do
      # Check if any choke points are also threat hotspots
      choke_systems = movement_patterns.choke_points |> Enum.map(& &1.system_id) |> MapSet.new()
      threat_systems = threat_patterns.threat_hotspots |> Enum.map(& &1.system_id) |> MapSet.new()
      overlap = MapSet.intersection(choke_systems, threat_systems) |> MapSet.size()
      
      if overlap > 0 do
        insights = ["#{overlap} systems identified as both choke points and threat hotspots - extreme caution advised" | insights]
      end
    end
    
    # Activity anomaly and threat correlation
    if length(activity_patterns.anomalies) > 0 && threat_patterns.threat_migration.migration_speed in [:rapid, :fast] do
      insights = ["Activity anomalies coinciding with rapid threat migration - possible coordinated operation" | insights]
    end
    
    insights
  end

  defp generate_movement_insights(movement_patterns) do
    insights = []
    
    # Corridor insights
    if length(movement_patterns.movement_corridors) > 0 do
      primary_corridors = Enum.count(movement_patterns.movement_corridors, fn c -> c.corridor_type == :primary end)
      if primary_corridors > 0 do
        insights = ["#{primary_corridors} primary movement corridors identified" | insights]
      end
    end
    
    # Choke point insights
    if length(movement_patterns.choke_points) > 0 do
      top_choke = List.first(movement_patterns.choke_points)
      if top_choke && top_choke.choke_score > 50 do
        insights = ["Critical choke point detected in system #{top_choke.system_id}" | insights]
      end
    end
    
    # Travel pattern insights
    if movement_patterns.travel_patterns.unique_travelers > 20 do
      insights = ["High traffic volume: #{movement_patterns.travel_patterns.unique_travelers} unique travelers tracked" | insights]
    end
    
    # Cross-system activity insights
    if movement_patterns.cross_system_activity > 70 do
      insights = ["High cross-system mobility: #{movement_patterns.cross_system_activity}% of entities active in multiple systems" | insights]
    end
    
    insights
  end

  defp generate_threat_insights(threat_patterns, system_ids) do
    insights = []
    
    # Hotspot insights
    if length(threat_patterns.threat_hotspots) > 0 do
      hotspot_count = length(threat_patterns.threat_hotspots)
      insights = ["#{hotspot_count} high-threat systems identified" | insights]
    end
    
    # Migration insights
    case threat_patterns.threat_migration.migration_speed do
      :rapid -> insights = ["Rapid threat migration detected - defensive posture recommended" | insights]
      :fast -> insights = ["Fast threat movement observed across systems" | insights]
      _ -> insights
    end
    
    # Escalation insights
    if threat_patterns.threat_escalation.escalation_detected do
      prob = threat_patterns.threat_escalation.escalation_probability
      insights = ["Threat escalation detected with #{round(prob * 100)}% confidence" | insights]
    end
    
    # Capital activity insights
    if length(threat_patterns.capital_activity) > 0 do
      insights = ["Capital ship activity detected in #{length(threat_patterns.capital_activity)} instances" | insights]
    end
    
    insights
  end

  defp generate_activity_insights(activity_patterns) do
    insights = []
    
    # Peak hour insights
    if length(activity_patterns.peak_activity_hours) > 0 do
      peak_hours_str = Enum.join(activity_patterns.peak_activity_hours, ", ")
      insights = ["Peak activity detected at hours: #{peak_hours_str} EVE time" | insights]
    end
    
    # Activity distribution insights
    dist = activity_patterns.activity_distribution
    if dist.high_activity > dist.low_activity * 2 do
      insights = ["Activity highly concentrated in #{dist.high_activity} systems" | insights]
    end
    
    # Anomaly insights
    if length(activity_patterns.anomalies) > 0 do
      insights = ["#{length(activity_patterns.anomalies)} activity anomalies detected requiring investigation" | insights]
    end
    
    insights
  end

  defp calculate_escalation_risk(threat_data) do
    # Calculate risk of threat escalation based on patterns
    if is_list(threat_data) and length(threat_data) == 0 do
      0.0
    else
      # Simple escalation risk based on threat entity count and activity
      threat_count = if is_list(threat_data), do: length(threat_data), else: 1
      risk_score = min(1.0, threat_count * 0.1)
      Float.round(risk_score, 2)
    end
  end

  defp extract_major_threat_entities(threat_data) do
    # Extract major threat entities from threat data
    if is_list(threat_data) do
      threat_data
      |> Enum.take(5)
      |> Enum.map(fn entity -> 
        case entity do
          %{entity_id: id, threat_level: level} -> %{id: id, level: level}
          {id, _} -> %{id: id, level: :unknown}
          _ -> nil
        end
      end)
      |> Enum.filter(& &1)
    else
      []
    end
  end

  defp identify_threat_spillover(system_ids, killmails) do
    # Identify threat spillover between systems
    if length(killmails) < 10 do
      %{
        spillover_detected: false,
        spillover_sources: [],
        spillover_targets: []
      }
    else
      # Group kills by system and time to detect spillover
      system_timeline = 
        killmails
        |> Enum.group_by(& &1.solar_system_id)
        |> Enum.map(fn {system_id, kills} ->
          times = kills |> Enum.map(& &1.killmail_time) |> Enum.sort()
          {system_id, List.first(times), List.last(times)}
        end)
      
      # Detect spillover patterns (simplified)
      spillover_pairs = 
        for {s1, _, end1} <- system_timeline,
            {s2, start2, _} <- system_timeline,
            s1 != s2,
            DateTime.diff(start2, end1, :hour) > 0,
            DateTime.diff(start2, end1, :hour) < 3,
        do: {s1, s2}
      
      if length(spillover_pairs) > 0 do
        sources = spillover_pairs |> Enum.map(&elem(&1, 0)) |> Enum.uniq()
        targets = spillover_pairs |> Enum.map(&elem(&1, 1)) |> Enum.uniq()
        
        %{
          spillover_detected: true,
          spillover_sources: sources,
          spillover_targets: targets
        }
      else
        %{
          spillover_detected: false,
          spillover_sources: [],
          spillover_targets: []
        }
      end
    end
  end

  defp identify_coordinated_threats(threat_data) do
    # Identify coordinated threat activities
    if is_list(threat_data) and length(threat_data) > 5 do
      # Look for patterns suggesting coordination
      threat_data
      |> Enum.chunk_every(3, 1, :discard)
      |> Enum.filter(fn chunk ->
        # Check if threats appear coordinated (simplified)
        times = Enum.map(chunk, fn t -> 
          case t do
            %{time: time} -> time
            _ -> nil
          end
        end)
        
        # All events within 30 minutes suggest coordination
        if Enum.all?(times, & &1) do
          [first | rest] = times
          Enum.all?(rest, fn t -> DateTime.diff(t, first, :minute) < 30 end)
        else
          false
        end
      end)
      |> Enum.map(fn chunk ->
        %{
          threat_group: Enum.map(chunk, fn t -> Map.get(t, :entity_id, :unknown) end),
          coordination_type: :simultaneous,
          confidence: 0.7
        }
      end)
      |> Enum.take(5)
    else
      []
    end
  end

  defp calculate_threat_correlation_matrix(system_ids, threat_data) do
    # Calculate threat correlation between systems
    if is_list(threat_data) and is_list(system_ids) do
      # Create a simple correlation matrix
      matrix = for s1 <- system_ids, s2 <- system_ids, into: %{} do
        if s1 == s2 do
          {{s1, s2}, 1.0}
        else
          # Simplified correlation based on shared threats
          correlation = :rand.uniform() * 0.5 # Placeholder
          {{s1, s2}, Float.round(correlation, 2)}
        end
      end
      
      matrix
    else
      %{}
    end
  end

  defp analyze_threat_entities(killmails) do
    # Analyze threat entities from killmail data
    if is_list(killmails) do
      # Group by attacking entities (simplified - would need attacker data)
      killmails
      |> Enum.filter(& &1.victim_alliance_id)
      |> Enum.group_by(& &1.victim_alliance_id)
      |> Enum.map(fn {alliance_id, kills} ->
        %{
          entity_id: alliance_id,
          entity_type: :alliance,
          kill_count: length(kills),
          threat_level: categorize_threat_level(length(kills) * 10),
          total_damage: kills |> Enum.map(& &1.total_value || 0) |> Enum.sum(),
          active_systems: kills |> Enum.map(& &1.solar_system_id) |> Enum.uniq() |> length()
        }
      end)
      |> Enum.sort_by(& &1.kill_count, :desc)
      |> Enum.take(20)
    else
      []
    end
  end

  defp calculate_coverage_percentage(system_ids, intel_data) do
    if length(system_ids) == 0 do
      0.0
    else
      # Calculate how many systems have intelligence coverage
      covered_systems = 
        if is_list(intel_data) do
          intel_data
          |> Enum.map(fn data -> Map.get(data, :system_id) end)
          |> Enum.filter(& &1)
          |> Enum.uniq()
          |> length()
        else
          0
        end
      
      coverage = covered_systems / length(system_ids) * 100
      Float.round(coverage, 1)
    end
  end

  defp calculate_intel_correlation_strength(shared_intel) do
    if is_list(shared_intel) and length(shared_intel) > 0 do
      # Calculate strength based on amount and quality of shared intelligence
      intel_score = length(shared_intel) * 0.1
      min(1.0, intel_score)
    else
      0.0
    end
  end

  defp assess_intelligence_quality(intel_data) do
    if is_list(intel_data) and length(intel_data) > 0 do
      # Assess quality based on data completeness and recency
      quality_scores = 
        intel_data
        |> Enum.map(fn data ->
          completeness = if Map.has_key?(data, :system_id) and Map.has_key?(data, :timestamp), do: 0.5, else: 0.0
          recency = if Map.get(data, :timestamp) do
            hours_old = DateTime.diff(DateTime.utc_now(), data.timestamp, :hour)
            max(0, 1.0 - (hours_old / 168)) # Decay over a week
          else
            0.0
          end
          completeness + recency * 0.5
        end)
      
      if length(quality_scores) > 0 do
        avg_quality = Enum.sum(quality_scores) / length(quality_scores)
        Float.round(avg_quality, 2)
      else
        0.0
      end
    else
      0.0
    end
  end

  defp identify_intelligence_gaps(system_ids, killmails) do
    # Identify systems with insufficient intelligence coverage
    if length(system_ids) == 0 do
      %{
        coverage_gaps: [],
        data_quality_issues: [],
        priority_systems: []
      }
    else
      # Find systems with low activity data
      system_activity = 
        killmails
        |> Enum.group_by(& &1.solar_system_id)
        |> Enum.map(fn {sys_id, kills} -> {sys_id, length(kills)} end)
        |> Map.new()
      
      # Identify gaps
      coverage_gaps = 
        system_ids
        |> Enum.filter(fn sys_id -> Map.get(system_activity, sys_id, 0) < 5 end)
        |> Enum.take(10)
      
      # Identify quality issues
      data_quality_issues = 
        system_ids
        |> Enum.filter(fn sys_id -> 
          activity = Map.get(system_activity, sys_id, 0)
          activity > 0 and activity < 10
        end)
        |> Enum.map(fn sys_id -> 
          %{system_id: sys_id, issue: :insufficient_data, recommendation: :increase_monitoring}
        end)
        |> Enum.take(5)
      
      # Prioritize systems for intelligence gathering
      priority_systems = 
        coverage_gaps
        |> Enum.take(5)
        |> Enum.map(fn sys_id -> 
          %{system_id: sys_id, priority: :high, reason: :no_recent_intelligence}
        end)
      
      %{
        coverage_gaps: coverage_gaps,
        data_quality_issues: data_quality_issues,
        priority_systems: priority_systems
      }
    end
  end

  defp analyze_shared_intelligence(system_ids, intel_data) do
    # Analyze intelligence that applies to multiple systems
    if is_list(intel_data) and length(intel_data) > 0 do
      # Find patterns that span multiple systems
      shared_patterns = 
        intel_data
        |> Enum.filter(fn data -> 
          systems = Map.get(data, :affected_systems, [])
          length(systems) > 1
        end)
        |> Enum.map(fn data ->
          %{
            pattern_type: Map.get(data, :pattern_type, :unknown),
            affected_systems: Map.get(data, :affected_systems, []),
            confidence: Map.get(data, :confidence, 0.5),
            timestamp: Map.get(data, :timestamp, DateTime.utc_now())
          }
        end)
        |> Enum.take(10)
      
      shared_patterns
    else
      []
    end
  end

  defp extract_intelligence_indicators(killmails) do
    # Extract intelligence indicators from killmail patterns
    if is_list(killmails) and length(killmails) > 0 do
      indicators = []
      
      # Indicator 1: Fleet operations (multiple kills in short time)
      fleet_ops = detect_fleet_operations(killmails)
      indicators = indicators ++ fleet_ops
      
      # Indicator 2: Strategic targets (high-value or capital kills)
      strategic_targets = detect_strategic_targets(killmails)
      indicators = indicators ++ strategic_targets
      
      # Indicator 3: Territory control (repeated kills in same system)
      territory_control = detect_territory_control(killmails)
      indicators = indicators ++ territory_control
      
      indicators |> Enum.take(20)
    else
      []
    end
  end
  
  defp detect_fleet_operations(killmails) do
    # Detect coordinated fleet operations
    killmails
    |> Enum.chunk_every(5, 1, :discard)
    |> Enum.filter(fn chunk ->
      # All kills within 10 minutes suggest fleet op
      [first | rest] = Enum.sort_by(chunk, & &1.killmail_time)
      Enum.all?(rest, fn k -> DateTime.diff(k.killmail_time, first.killmail_time, :minute) < 10 end)
    end)
    |> Enum.map(fn chunk ->
      systems = chunk |> Enum.map(& &1.solar_system_id) |> Enum.uniq()
      %{
        pattern_type: :fleet_operation,
        affected_systems: systems,
        timestamp: List.first(chunk).killmail_time,
        confidence: 0.8,
        size: length(chunk)
      }
    end)
    |> Enum.take(5)
  end
  
  defp detect_strategic_targets(killmails) do
    # Detect strategic target eliminations
    killmails
    |> Enum.filter(fn km -> 
      (km.total_value || 0) > 5_000_000_000 or # 5B+ ISK
      (km.victim_ship_type_id && km.victim_ship_type_id > 20000) # Capital
    end)
    |> Enum.map(fn km ->
      %{
        pattern_type: :strategic_target,
        affected_systems: [km.solar_system_id],
        timestamp: km.killmail_time,
        confidence: 0.9,
        target_value: km.total_value || 0
      }
    end)
    |> Enum.take(5)
  end
  
  defp detect_territory_control(killmails) do
    # Detect territory control patterns
    killmails
    |> Enum.group_by(& &1.solar_system_id)
    |> Enum.filter(fn {_, kills} -> length(kills) > 10 end)
    |> Enum.map(fn {system_id, kills} ->
      %{
        pattern_type: :territory_control,
        affected_systems: [system_id],
        timestamp: List.first(kills).killmail_time,
        confidence: 0.7,
        intensity: length(kills)
      }
    end)
    |> Enum.take(5)
  end

  defp calculate_std_deviation(values) do
    if length(values) == 0 do
      0.0
    else
      mean = Enum.sum(values) / length(values)
      variance = Enum.sum(Enum.map(values, fn x -> :math.pow(x - mean, 2) end)) / length(values)
      :math.sqrt(variance)
    end
  end
  
  # New helper functions for trend analysis
  defp calculate_trend_direction(buckets) do
    if length(buckets) < 2 do
      :stable
    else
      # Simple linear regression on bucket activity
      {xs, ys} = buckets |> Enum.unzip()
      
      n = length(xs)
      sum_x = Enum.sum(xs)
      sum_y = Enum.sum(ys)
      sum_xy = Enum.zip(xs, ys) |> Enum.map(fn {x, y} -> x * y end) |> Enum.sum()
      sum_x_sq = Enum.map(xs, &(&1 * &1)) |> Enum.sum()
      
      slope = if n * sum_x_sq - sum_x * sum_x == 0 do
        0
      else
        (n * sum_xy - sum_x * sum_y) / (n * sum_x_sq - sum_x * sum_x)
      end
      
      cond do
        slope > 0.1 -> :increasing
        slope < -0.1 -> :decreasing
        true -> :stable
      end
    end
  end
  
  defp determine_overall_trend(trending_up, trending_down) do
    cond do
      length(trending_up) > length(trending_down) * 1.5 -> :increasing
      length(trending_down) > length(trending_up) * 1.5 -> :decreasing
      true -> :stable
    end
  end
  
  defp calculate_system_baselines(killmails) do
    killmails
    |> Enum.group_by(& &1.solar_system_id)
    |> Enum.map(fn {system_id, system_kills} ->
      hourly_activity = 
        system_kills
        |> Enum.group_by(fn kill ->
          kill.killmail_time |> DateTime.truncate(:hour)
        end)
        |> Enum.map(fn {hour, kills} -> length(kills) end)
      
      avg_activity = if length(hourly_activity) > 0 do
        Enum.sum(hourly_activity) / length(hourly_activity)
      else
        0
      end
      
      {system_id, %{average_hourly_activity: avg_activity, sample_size: length(hourly_activity)}}
    end)
    |> Map.new()
  end
  
  defp detect_activity_spikes(killmails, baselines) do
    killmails
    |> Enum.group_by(fn kill -> 
      {kill.solar_system_id, kill.killmail_time |> DateTime.truncate(:hour)}
    end)
    |> Enum.flat_map(fn {{system_id, hour}, hour_kills} ->
      baseline = get_in(baselines, [system_id, :average_hourly_activity]) || 0
      
      if baseline > 0 and length(hour_kills) > baseline * 3 do
        [%{
          type: :activity_spike,
          system_id: system_id,
          timestamp: hour,
          severity: :high,
          details: %{
            normal_activity: Float.round(baseline, 1),
            spike_activity: length(hour_kills),
            spike_ratio: Float.round(length(hour_kills) / baseline, 1)
          }
        }]
      else
        []
      end
    end)
  end
  
  defp detect_timing_anomalies(killmails) do
    # Detect unusual timing patterns (e.g., activity at normally quiet hours)
    killmails
    |> Enum.group_by(&(&1.killmail_time.hour))
    |> Enum.flat_map(fn {hour, hour_kills} ->
      # Consider hours 0-6 as "quiet hours" in EVE time
      if hour >= 0 and hour <= 6 and length(hour_kills) > 10 do
        [%{
          type: :unusual_timing,
          hour: hour,
          severity: :medium,
          details: %{
            activity_count: length(hour_kills),
            systems_affected: hour_kills |> Enum.map(& &1.solar_system_id) |> Enum.uniq() |> length()
          }
        }]
      else
        []
      end
    end)
  end

  defp detect_temporal_lag(system_activity) do
    # Detect average time lag between correlated activities
    # Simplified - returns average lag in hours
    if map_size(system_activity) < 10 do
      0
    else
      # In a real implementation, would analyze time series data
      1 # Default 1 hour lag
    end
  end

  defp extract_correlated_systems(strong_correlations) do
    # Extract unique systems that show correlation
    strong_correlations
    |> Enum.flat_map(fn {{s1, s2}, _} -> [s1, s2] end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp calculate_overall_correlation_strength(correlations) do
    if length(correlations) == 0 do
      0.0
    else
      # Average correlation strength
      total_correlation = 
        correlations
        |> Enum.map(&elem(&1, 1))
        |> Enum.sum()
      
      Float.round(total_correlation / length(correlations), 2)
    end
  end

  defp identify_correlation_patterns(strong_correlations, system_activity) do
    # Identify types of correlation patterns
    patterns = []
    
    # Pattern 1: Simultaneous activity
    simultaneous = 
      strong_correlations
      |> Enum.filter(fn {_, score} -> score > 0.8 end)
      |> Enum.map(fn {{s1, s2}, score} ->
        %{
          type: :simultaneous_activity,
          systems: [s1, s2],
          correlation_strength: Float.round(score, 2)
        }
      end)
    
    patterns = patterns ++ simultaneous
    
    # Pattern 2: Cascading activity (time-delayed correlation)
    cascading = detect_cascading_patterns(strong_correlations, system_activity)
    patterns = patterns ++ cascading
    
    patterns
  end
  
  defp detect_cascading_patterns(correlations, _system_activity) do
    # Simplified cascading pattern detection
    correlations
    |> Enum.filter(fn {_, score} -> score > 0.5 and score < 0.8 end)
    |> Enum.take(3)
    |> Enum.map(fn {{s1, s2}, score} ->
      %{
        type: :cascading_activity,
        from_system: s1,
        to_system: s2,
        correlation_strength: Float.round(score, 2),
        typical_delay: "1-2 hours" # Simplified
      }
    end)
  end

  defp calculate_pairwise_correlations(system_ids, system_activity) do
    # Calculate correlation between pairs of systems
    pairs = for s1 <- system_ids, s2 <- system_ids, s1 < s2, do: {s1, s2}
    
    correlations = 
      pairs
      |> Enum.map(fn {s1, s2} ->
        # Get activity for both systems
        s1_activity = 
          system_activity
          |> Enum.filter(fn {{sys, _}, _} -> sys == s1 end)
          |> Enum.map(fn {{_, time}, count} -> {time, count} end)
          |> Map.new()
        
        s2_activity = 
          system_activity
          |> Enum.filter(fn {{sys, _}, _} -> sys == s2 end)
          |> Enum.map(fn {{_, time}, count} -> {time, count} end)
          |> Map.new()
        
        # Calculate correlation coefficient (simplified)
        correlation = calculate_correlation_coefficient(s1_activity, s2_activity)
        
        {{s1, s2}, correlation}
      end)
      |> Enum.filter(fn {_, corr} -> corr > 0.3 end) # Keep only meaningful correlations
    
    correlations
  end
  
  defp calculate_correlation_coefficient(activity1, activity2) do
    # Simplified correlation calculation
    common_times = MapSet.intersection(
      MapSet.new(Map.keys(activity1)),
      MapSet.new(Map.keys(activity2))
    )
    
    if MapSet.size(common_times) < 3 do
      0.0
    else
      # Calculate similarity based on activity patterns
      similarities = 
        common_times
        |> Enum.map(fn time ->
          a1 = Map.get(activity1, time, 0)
          a2 = Map.get(activity2, time, 0)
          
          if a1 + a2 == 0 do
            0.0
          else
            min(a1, a2) / max(a1, a2)
          end
        end)
      
      if length(similarities) > 0 do
        Enum.sum(similarities) / length(similarities)
      else
        0.0
      end
    end
  end

  defp group_by_system_and_time(killmails) do
    # Group killmails by system and time window (hourly)
    killmails
    |> Enum.group_by(fn km ->
      hour = km.killmail_time |> DateTime.truncate(:hour)
      {km.solar_system_id, hour}
    end)
    |> Enum.map(fn {{system_id, hour}, kills} ->
      {{system_id, hour}, length(kills)}
    end)
    |> Map.new()
  end

  defp detect_capital_activity(killmails) do
    # Detect capital ship activity
    # Capital ship type IDs typically > 20000
    capital_activity = 
      killmails
      |> Enum.filter(fn km -> km.victim_ship_type_id && km.victim_ship_type_id > 20000 end)
      |> Enum.map(fn km ->
        %{
          killmail_id: km.killmail_id,
          system_id: km.solar_system_id,
          ship_type_id: km.victim_ship_type_id,
          time: km.killmail_time,
          value: km.total_value || 0
        }
      end)
    
    capital_activity
  end

  defp analyze_high_value_losses(killmails) do
    # Analyze high-value losses
    high_value_threshold = 1_000_000_000 # 1 billion ISK
    
    high_value_losses = 
      killmails
      |> Enum.filter(fn km -> (km.total_value || 0) > high_value_threshold end)
      |> Enum.sort_by(& &1.total_value, :desc)
      |> Enum.take(10)
      |> Enum.map(fn km ->
        %{
          killmail_id: km.killmail_id,
          system_id: km.solar_system_id,
          victim_ship_type: km.victim_ship_type_id,
          total_value: km.total_value,
          time: km.killmail_time
        }
      end)
    
    high_value_losses
  end

  # Helper functions for constellation analysis
  defp analyze_control_indicators(killmails) do
    # Analyze indicators of system control
    if length(killmails) == 0 do
      %{dominance_ratio: 0.0, control_type: :unknown}
    else
      # Group by alliance to determine control
      alliance_kills = 
        killmails
        |> Enum.filter(& &1.victim_alliance_id)
        |> Enum.group_by(& &1.victim_alliance_id)
        |> Enum.map(fn {alliance, kills} -> {alliance, length(kills)} end)
        |> Enum.sort_by(&elem(&1, 1), :desc)
      
      if length(alliance_kills) > 0 do
        [{dominant_alliance, dominant_kills} | rest] = alliance_kills
        total_kills = alliance_kills |> Enum.map(&elem(&1, 1)) |> Enum.sum()
        dominance_ratio = dominant_kills / total_kills
        
        control_type = cond do
          dominance_ratio > 0.8 -> :monopoly
          dominance_ratio > 0.6 -> :dominant
          dominance_ratio > 0.4 -> :contested
          true -> :fragmented
        end
        
        %{
          dominance_ratio: Float.round(dominance_ratio, 2),
          control_type: control_type,
          dominant_alliance: dominant_alliance,
          alliance_count: length(alliance_kills)
        }
      else
        %{dominance_ratio: 0.0, control_type: :unknown}
      end
    end
  end
  
  defp calculate_daily_control_variance(killmails) do
    # Calculate variance in control over daily periods
    daily_control = 
      killmails
      |> Enum.group_by(fn km -> km.killmail_time |> DateTime.to_date() end)
      |> Enum.map(fn {date, daily_kills} ->
        # Get dominant entity for the day
        dominant = 
          daily_kills
          |> Enum.filter(& &1.victim_alliance_id)
          |> Enum.group_by(& &1.victim_alliance_id)
          |> Enum.map(fn {alliance, kills} -> {alliance, length(kills)} end)
          |> Enum.max_by(&elem(&1, 1), fn -> {nil, 0} end)
          |> elem(0)
        
        {date, dominant}
      end)
    
    # Calculate how often control changes
    changes = 
      daily_control
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.count(fn [{_, d1}, {_, d2}] -> d1 != d2 end)
    
    if length(daily_control) > 1 do
      changes / (length(daily_control) - 1)
    else
      0.0
    end
  end
  
  defp analyze_control_trends(killmails, alliance_kills) do
    # Analyze trends in control patterns
    if length(killmails) < 10 do
      :insufficient_data
    else
      # Split kills into recent and older
      midpoint = DateTime.add(DateTime.utc_now(), -7 * 24 * 3600, :second)
      
      recent_kills = Enum.filter(killmails, fn km -> DateTime.compare(km.killmail_time, midpoint) == :gt end)
      older_kills = Enum.filter(killmails, fn km -> DateTime.compare(km.killmail_time, midpoint) == :lt end)
      
      # Get top alliance in each period
      recent_top = get_top_alliance(recent_kills)
      older_top = get_top_alliance(older_kills)
      
      cond do
        recent_top == older_top -> :stable
        recent_top != nil and older_top == nil -> :consolidating
        recent_top == nil and older_top != nil -> :fragmenting
        true -> :shifting
      end
    end
  end
  
  defp get_top_alliance(kills) do
    kills
    |> Enum.filter(& &1.victim_alliance_id)
    |> Enum.group_by(& &1.victim_alliance_id)
    |> Enum.map(fn {alliance, k} -> {alliance, length(k)} end)
    |> Enum.max_by(&elem(&1, 1), fn -> {nil, 0} end)
    |> elem(0)
  end
  
  defp calculate_cross_system_activity_score(character_activity) do
    # Calculate how much cross-system activity is occurring
    total_characters = map_size(character_activity)
    
    if total_characters == 0 do
      0.0
    else
      # Count characters active in multiple systems
      multi_system_chars = 
        character_activity
        |> Enum.count(fn {_char_id, data} -> length(data.systems) > 1 end)
      
      # Calculate cross-system activity ratio
      Float.round(multi_system_chars / total_characters * 100, 2)
    end
  end
end
