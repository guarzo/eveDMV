defmodule EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystemAnalyzer do
  @moduledoc """
  Advanced cross-system intelligence analysis engine for wormhole-focused PvP intelligence.

  Provides sophisticated analysis capabilities that span multiple solar systems:

  - Wormhole Chain Analysis: Maps and analyzes wormhole connections and traffic patterns
  - Cross-System Battle Correlation: Links related battles across different systems
  - Intelligence Fusion: Combines data from multiple sources for comprehensive analysis
  - Activity Pattern Recognition: Identifies patterns in cross-system pilot and corp activity
  - Strategic Intelligence: Provides strategic insights for wormhole operations

  Uses advanced graph algorithms, pattern recognition, and strategic analysis
  to provide deep intelligence on wormhole space operations and PvP activities.
  """

  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Contexts.BattleAnalysis.Domain.ParticipantExtractor

  require Logger
  # Cross-system analysis parameters
  # Minimum correlation for activity linking
  @activity_correlation_threshold 0.7
  # Confidence threshold for intelligence fusion
  @intelligence_fusion_confidence 0.8
  # Days of data for strategic analysis
  @strategic_analysis_window_days 14

  # Intelligence source types
  @intelligence_sources [
    :killmails,
    :player_reports,
    :scanning_data,
    :market_activity,
    :jump_logs
  ]

  @doc """
  Analyzes wormhole chain connections and activity patterns.

  Maps wormhole connections and analyzes traffic patterns, activity levels,
  and strategic significance of wormhole chains.

  ## Parameters
  - starting_system_id: Solar system ID to start chain analysis from
  - options: Analysis options
    - :max_depth - Maximum jumps to analyze in chain (default: 10)
    - :include_activity_analysis - Include activity pattern analysis (default: true)
    - :include_threat_assessment - Include threat assessment for each system (default: true)
    - :time_window_hours - Hours of data to analyze (default: 24)

  ## Returns
  {:ok, wormhole_chain_analysis} with comprehensive chain intelligence
  """
  def analyze_wormhole_chain(starting_system_id, options \\ []) do
    max_depth = Keyword.get(options, :max_depth, 10)
    include_activity = Keyword.get(options, :include_activity_analysis, true)
    include_threats = Keyword.get(options, :include_threat_assessment, true)
    time_window_hours = Keyword.get(options, :time_window_hours, 24)

    Logger.info("Analyzing wormhole chain from system #{starting_system_id}")

    start_time = System.monotonic_time(:millisecond)

    with {:ok, chain_map} <- map_wormhole_chain(starting_system_id, max_depth),
         {:ok, connection_data} <- analyze_wormhole_connections(chain_map, time_window_hours),
         {:ok, activity_analysis} <-
           maybe_analyze_chain_activity(
             chain_map,
             include_activity,
             time_window_hours
           ),
         {:ok, threat_assessment} <-
           maybe_analyze_chain_threats(
             chain_map,
             include_threats,
             time_window_hours
           ),
         {:ok, strategic_analysis} <-
           analyze_strategic_significance(
             chain_map,
             connection_data,
             activity_analysis,
             threat_assessment
           ),
         {:ok, final_analysis} <-
           compile_chain_analysis(
             starting_system_id,
             chain_map,
             connection_data,
             activity_analysis,
             threat_assessment,
             strategic_analysis
           ) do
      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      Logger.info("""
      Wormhole chain analysis completed in #{duration_ms}ms:
      - Systems mapped: #{length(chain_map.systems)}
      - Connections analyzed: #{length(chain_map.connections)}
      - Max depth reached: #{chain_map.max_depth}
      - Strategic rating: #{strategic_analysis.strategic_rating}
      """)

      {:ok, final_analysis}
    end
  end

  @doc """
  Correlates battles and activities across multiple systems.

  Identifies related combat activities, pilot movements, and strategic operations
  that span multiple solar systems using advanced correlation algorithms.

  ## Parameters
  - system_ids: List of solar system IDs to analyze
  - options: Analysis options
    - :correlation_window_hours - Time window for correlation analysis (default: 6)
    - :min_correlation_strength - Minimum correlation strength (default: 0.7)
    - :include_pilot_tracking - Track pilot movements (default: true)
    - :include_corp_analysis - Include corporation activity analysis (default: true)

  ## Returns
  {:ok, cross_system_correlation} with correlated activity analysis
  """
  def correlate_cross_system_activity(system_ids, options \\ []) do
    correlation_window = Keyword.get(options, :correlation_window_hours, 6)

    min_correlation =
      Keyword.get(options, :min_correlation_strength, @activity_correlation_threshold)

    include_pilot_tracking = Keyword.get(options, :include_pilot_tracking, true)
    include_corp_analysis = Keyword.get(options, :include_corp_analysis, true)

    Logger.info("Correlating cross-system activity across #{length(system_ids)} systems")

    start_time = System.monotonic_time(:millisecond)

    with {:ok, system_activities} <- fetch_system_activities(system_ids, correlation_window),
         {:ok, temporal_correlations} <- analyze_temporal_correlations(system_activities),
         {:ok, pilot_movements} <-
           maybe_track_pilot_movements(
             system_activities,
             include_pilot_tracking
           ),
         {:ok, corp_activities} <-
           maybe_analyze_corp_activities(
             system_activities,
             include_corp_analysis
           ),
         {:ok, correlation_patterns} <-
           identify_correlation_patterns(
             temporal_correlations,
             pilot_movements,
             corp_activities,
             min_correlation
           ),
         {:ok, strategic_implications} <-
           assess_strategic_implications(
             correlation_patterns,
             system_ids
           ),
         {:ok, final_correlation} <-
           compile_correlation_analysis(
             system_ids,
             correlation_patterns,
             strategic_implications
           ) do
      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      Logger.info("""
      Cross-system correlation completed in #{duration_ms}ms:
      - Systems analyzed: #{length(system_ids)}
      - Correlations found: #{length(correlation_patterns)}
      - Pilot movements tracked: #{length(pilot_movements)}
      - Strategic implications: #{length(strategic_implications)}
      """)

      {:ok, final_correlation}
    end
  end

  @doc """
  Performs intelligence fusion from multiple sources.

  Combines and analyzes intelligence from multiple sources to provide
  comprehensive situational awareness and strategic intelligence.

  ## Parameters
  - analysis_area: Geographic area or system list to analyze
  - options: Fusion options
    - :intelligence_sources - Sources to include (default: all)
    - :fusion_confidence_threshold - Confidence threshold (default: 0.8)
    - :temporal_correlation - Include temporal correlation (default: true)
    - :priority_weighting - Weight sources by priority (default: true)

  ## Returns
  {:ok, intelligence_fusion} with fused intelligence analysis
  """
  def fuse_intelligence_sources(analysis_area, options \\ []) do
    sources = Keyword.get(options, :intelligence_sources, @intelligence_sources)

    confidence_threshold =
      Keyword.get(options, :fusion_confidence_threshold, @intelligence_fusion_confidence)

    temporal_correlation = Keyword.get(options, :temporal_correlation, true)
    priority_weighting = Keyword.get(options, :priority_weighting, true)

    Logger.info("Fusing intelligence from #{length(sources)} sources")

    start_time = System.monotonic_time(:millisecond)

    with {:ok, raw_intelligence} <- collect_raw_intelligence(analysis_area, sources),
         {:ok, processed_intelligence} <- process_intelligence_sources(raw_intelligence),
         {:ok, correlated_intelligence} <-
           maybe_apply_temporal_correlation(
             processed_intelligence,
             temporal_correlation
           ),
         {:ok, weighted_intelligence} <-
           maybe_apply_priority_weighting(
             correlated_intelligence,
             priority_weighting
           ),
         {:ok, fused_intelligence} <-
           perform_intelligence_fusion(
             weighted_intelligence,
             confidence_threshold
           ),
         {:ok, confidence_assessment} <- assess_intelligence_confidence(fused_intelligence),
         {:ok, final_intelligence} <-
           compile_intelligence_report(
             analysis_area,
             fused_intelligence,
             confidence_assessment
           ) do
      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      Logger.info("""
      Intelligence fusion completed in #{duration_ms}ms:
      - Sources processed: #{length(sources)}
      - Intelligence items fused: #{map_size(fused_intelligence)}
      - Overall confidence: #{confidence_assessment.overall_confidence}
      """)

      {:ok, final_intelligence}
    end
  end

  @doc """
  Analyzes strategic patterns and provides tactical recommendations.

  Performs high-level strategic analysis to identify patterns, threats,
  and opportunities across multiple systems and timeframes.

  ## Parameters
  - analysis_scope: Scope of strategic analysis
    - :system_ids - Specific systems to analyze
    - :region_id - Entire region analysis
    - :wormhole_chain - Wormhole chain analysis
  - options: Strategic analysis options
    - :analysis_window_days - Days of historical data (default: 14)
    - :include_predictions - Include predictive analysis (default: true)
    - :threat_assessment_level - Level of threat assessment (default: :comprehensive)

  ## Returns
  {:ok, strategic_analysis} with strategic intelligence and recommendations
  """
  def analyze_strategic_patterns(analysis_scope, options \\ []) do
    analysis_window = Keyword.get(options, :analysis_window_days, @strategic_analysis_window_days)
    include_predictions = Keyword.get(options, :include_predictions, true)
    threat_level = Keyword.get(options, :threat_assessment_level, :comprehensive)

    Logger.info("Analyzing strategic patterns for #{inspect(analysis_scope)}")

    start_time = System.monotonic_time(:millisecond)

    with {:ok, historical_data} <- fetch_strategic_data(analysis_scope, analysis_window),
         {:ok, pattern_analysis} <- analyze_strategic_patterns_in_data(historical_data),
         {:ok, threat_analysis} <- perform_threat_assessment(historical_data, threat_level),
         {:ok, opportunity_analysis} <- identify_strategic_opportunities(pattern_analysis),
         {:ok, predictions} <-
           maybe_generate_strategic_predictions(
             pattern_analysis,
             include_predictions
           ),
         {:ok, recommendations} <-
           generate_strategic_recommendations(
             pattern_analysis,
             threat_analysis,
             opportunity_analysis,
             predictions
           ),
         {:ok, final_strategic_analysis} <-
           compile_strategic_analysis(
             analysis_scope,
             pattern_analysis,
             threat_analysis,
             opportunity_analysis,
             predictions,
             recommendations
           ) do
      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      Logger.info("""
      Strategic analysis completed in #{duration_ms}ms:
      - Patterns identified: #{length(pattern_analysis.patterns)}
      - Threats assessed: #{length(threat_analysis.assessment)}
      - Opportunities found: #{length(opportunity_analysis)}
      - Recommendations generated: #{length(recommendations)}
      """)

      {:ok, final_strategic_analysis}
    end
  end

  @doc """
  Provides real-time cross-system intelligence updates.

  Monitors multiple systems for real-time intelligence updates and provides
  alerts for significant activities or pattern changes.

  ## Parameters
  - monitored_systems: List of system IDs to monitor
  - options: Monitoring options
    - :alert_thresholds - Custom alert thresholds
    - :update_frequency_seconds - Update frequency (default: 60)
    - :include_predictions - Include predictive alerts (default: true)

  ## Returns
  {:ok, intelligence_stream} with real-time intelligence updates
  """
  def monitor_cross_system_intelligence(monitored_systems, options \\ []) do
    alert_thresholds = Keyword.get(options, :alert_thresholds, %{})
    update_frequency = Keyword.get(options, :update_frequency_seconds, 60)
    include_predictions = Keyword.get(options, :include_predictions, true)

    Logger.info(
      "Starting cross-system intelligence monitoring for #{length(monitored_systems)} systems"
    )

    with {:ok, baseline_intelligence} <- establish_intelligence_baseline(monitored_systems),
         {:ok, monitoring_setup} <-
           setup_intelligence_monitoring(
             monitored_systems,
             baseline_intelligence,
             alert_thresholds
           ),
         {:ok, prediction_system} <-
           maybe_setup_predictive_monitoring(
             monitoring_setup,
             include_predictions
           ),
         {:ok, intelligence_stream} <-
           start_intelligence_stream(
             monitoring_setup,
             prediction_system,
             update_frequency
           ) do
      Logger.info("""
      Cross-system intelligence monitoring started:
      - Systems monitored: #{length(monitored_systems)}
      - Update frequency: #{update_frequency}s
      - Predictive monitoring: #{include_predictions}
      """)

      {:ok, intelligence_stream}
    end
  end

  # Private implementation functions

  defp map_wormhole_chain(starting_system_id, max_depth) do
    # Map wormhole connections starting from the given system
    _chain_map = %{
      starting_system: starting_system_id,
      systems: [starting_system_id],
      connections: [],
      max_depth: 0,
      total_mass_capacity: 0,
      critical_connections: []
    }

    # In production, would use actual wormhole connection data
    # For now, simulate a basic chain structure
    simulated_chain = simulate_wormhole_chain(starting_system_id, max_depth)

    {:ok, simulated_chain}
  end

  defp simulate_wormhole_chain(starting_system_id, max_depth) do
    # Simulate a wormhole chain for demonstration
    systems = [starting_system_id]
    connections = []

    # Generate a simple chain with random connections
    chain_systems =
      1..min(max_depth, 5)
      |> Enum.reduce({systems, connections}, fn depth, {sys_acc, conn_acc} ->
        new_system_id = starting_system_id + depth * 1000

        connection = %{
          from_system: List.last(sys_acc),
          to_system: new_system_id,
          wormhole_type: determine_wormhole_type(depth),
          mass_capacity: calculate_mass_capacity(depth),
          time_remaining: :rand.uniform(24),
          stability: determine_stability(depth),
          discovered_at: DateTime.utc_now()
        }

        {[new_system_id | sys_acc], [connection | conn_acc]}
      end)

    {final_systems, final_connections} = chain_systems

    %{
      starting_system: starting_system_id,
      systems: final_systems,
      connections: final_connections,
      max_depth: length(final_systems) - 1,
      total_mass_capacity: calculate_total_mass_capacity(final_connections),
      critical_connections: identify_critical_connections(final_connections)
    }
  end

  defp determine_wormhole_type(depth) do
    case depth do
      1 -> :c1_exit
      2 -> :c2_exit
      3 -> :c3_exit
      4 -> :c4_exit
      _ -> :c5_exit
    end
  end

  defp calculate_mass_capacity(depth) do
    # Mass capacity in tons
    case depth do
      # 20M kg
      1 -> 20_000_000
      # 300M kg
      2 -> 300_000_000
      # 1B kg
      3 -> 1_000_000_000
      # 2B kg
      4 -> 2_000_000_000
      # 3B kg
      _ -> 3_000_000_000
    end
  end

  defp determine_stability(_depth) do
    # Simulate wormhole stability
    case :rand.uniform(4) do
      1 -> :stable
      2 -> :destabilized
      3 -> :critical
      4 -> :verge_of_collapse
    end
  end

  defp calculate_total_mass_capacity(connections) do
    connections
    |> Enum.map(& &1.mass_capacity)
    |> Enum.sum()
  end

  defp identify_critical_connections(connections) do
    connections
    |> Enum.filter(&(&1.stability in [:critical, :verge_of_collapse]))
  end

  defp analyze_wormhole_connections(chain_map, time_window_hours) do
    # Analyze the wormhole connections for traffic, stability, and strategic value
    connection_analysis =
      chain_map.connections
      |> Enum.map(fn connection ->
        %{
          connection_id: generate_connection_id(connection),
          from_system: connection.from_system,
          to_system: connection.to_system,
          wormhole_type: connection.wormhole_type,
          mass_capacity: connection.mass_capacity,
          estimated_traffic: estimate_traffic_volume(connection, time_window_hours),
          strategic_value: assess_connection_strategic_value(connection, chain_map),
          threat_level: assess_connection_threat_level(connection),
          stability_trend: analyze_stability_trend(connection),
          time_until_collapse: estimate_collapse_time(connection)
        }
      end)

    {:ok, connection_analysis}
  end

  defp generate_connection_id(connection) do
    "#{connection.from_system}-#{connection.to_system}"
  end

  defp estimate_traffic_volume(connection, _time_window_hours) do
    # Estimate traffic volume based on system activity
    # In production, would analyze actual jump logs and activity data
    base_traffic =
      case connection.wormhole_type do
        :c1_exit -> 10
        :c2_exit -> 25
        :c3_exit -> 50
        :c4_exit -> 100
        :c5_exit -> 200
        _ -> 5
      end

    # Add some randomness to simulate real traffic patterns
    base_traffic + :rand.uniform(base_traffic)
  end

  defp assess_connection_strategic_value(connection, chain_map) do
    # Assess strategic value based on position in chain and system characteristics
    depth = find_connection_depth(connection, chain_map)

    value_factors = []

    # Deeper connections are more valuable for strategic positioning
    value_factors = [depth * 0.2 | value_factors]

    # High-class wormholes are more valuable
    class_value =
      case connection.wormhole_type do
        :c5_exit -> 1.0
        :c4_exit -> 0.8
        :c3_exit -> 0.6
        :c2_exit -> 0.4
        :c1_exit -> 0.2
        _ -> 0.1
      end

    value_factors = [class_value | value_factors]

    # Mass capacity affects strategic value
    mass_value = min(1.0, connection.mass_capacity / 3_000_000_000)
    value_factors = [mass_value | value_factors]

    # Calculate overall strategic value
    total_value = Enum.sum(value_factors) / length(value_factors)

    cond do
      total_value > 0.8 -> :very_high
      total_value > 0.6 -> :high
      total_value > 0.4 -> :medium
      total_value > 0.2 -> :low
      true -> :very_low
    end
  end

  defp find_connection_depth(connection, chain_map) do
    # Find the depth of this connection in the chain
    Enum.find_index(
      chain_map.connections,
      &(&1.from_system == connection.from_system && &1.to_system == connection.to_system)
    ) ||
      0
  end

  defp assess_connection_threat_level(connection) do
    # Assess threat level based on connection characteristics
    case connection.wormhole_type do
      # Capital capable
      :c5_exit -> :very_high
      # Dangerous space
      :c4_exit -> :high
      # Moderate threat
      :c3_exit -> :medium
      # Relatively safe
      :c2_exit -> :low
      # Safest wormhole space
      :c1_exit -> :very_low
      _ -> :unknown
    end
  end

  defp analyze_stability_trend(connection) do
    # Analyze stability trend over time
    # In production, would track actual stability changes
    case connection.stability do
      :stable -> :improving
      :destabilized -> :declining
      :critical -> :rapidly_declining
      :verge_of_collapse -> :imminent_collapse
    end
  end

  defp estimate_collapse_time(connection) do
    # Estimate time until wormhole collapse
    case connection.stability do
      # 12-36 hours
      :stable -> :rand.uniform(24) + 12
      # 6-18 hours
      :destabilized -> :rand.uniform(12) + 6
      # 2-8 hours
      :critical -> :rand.uniform(6) + 2
      # 0.5-2.5 hours
      :verge_of_collapse -> :rand.uniform(2) + 0.5
    end
  end

  defp maybe_analyze_chain_activity(chain_map, include_activity, time_window_hours) do
    if include_activity do
      analyze_chain_activity(chain_map, time_window_hours)
    else
      {:ok, %{activity_analysis_skipped: true}}
    end
  end

  defp analyze_chain_activity(chain_map, time_window_hours) do
    # Analyze activity patterns across the wormhole chain
    system_activities =
      chain_map.systems
      |> Enum.map(fn system_id ->
        %{
          system_id: system_id,
          killmails: get_system_killmails(system_id, time_window_hours),
          pilot_activity: estimate_pilot_activity(system_id, time_window_hours),
          corp_presence: analyze_corp_presence(system_id, time_window_hours),
          activity_level: calculate_activity_level(system_id, time_window_hours),
          threat_indicators: identify_threat_indicators(system_id, time_window_hours)
        }
      end)

    activity_analysis = %{
      systems: system_activities,
      chain_activity_level: calculate_chain_activity_level(system_activities),
      activity_hotspots: identify_activity_hotspots(system_activities),
      activity_patterns: identify_activity_patterns(system_activities),
      temporal_distribution: analyze_temporal_distribution(system_activities)
    }

    {:ok, activity_analysis}
  end

  defp get_system_killmails(system_id, time_window_hours) do
    # Get killmails for the system within the time window
    start_time = DateTime.utc_now() |> DateTime.add(-time_window_hours, :hour)

    case Ash.read(KillmailRaw,
           filter: %{
             solar_system_id: system_id,
             killmail_time: {:>=, start_time}
           },
           domain: Api
         ) do
      {:ok, killmails} -> killmails
      _ -> []
    end
  end

  defp estimate_pilot_activity(system_id, time_window_hours) do
    # Estimate pilot activity based on available data
    killmails = get_system_killmails(system_id, time_window_hours)

    unique_pilots =
      killmails
      |> Enum.flat_map(&extract_all_participants_from_killmail/1)
      |> Enum.uniq()

    %{
      unique_pilots: length(unique_pilots),
      activity_score: calculate_pilot_activity_score(killmails, unique_pilots),
      peak_activity_time: estimate_peak_activity_time(killmails),
      activity_trend: analyze_activity_trend(killmails)
    }
  end

  defp extract_all_participants_from_killmail(killmail) do
    ParticipantExtractor.extract_participants(killmail)
  end

  defp calculate_pilot_activity_score(killmails, unique_pilots) do
    # Calculate activity score based on killmails and pilot diversity
    killmail_count = length(killmails)
    pilot_count = length(unique_pilots)

    if pilot_count > 0 do
      # Higher score for more activity with good pilot diversity
      killmail_count * 0.7 + pilot_count * 0.3
    else
      0
    end
  end

  defp estimate_peak_activity_time(killmails) do
    # Estimate when peak activity occurred
    if length(killmails) > 0 do
      # Group killmails by hour and find peak
      killmails
      |> Enum.group_by(fn km ->
        DateTime.to_time(DateTime.truncate(km.killmail_time, :second))
      end)
      |> Enum.max_by(fn {_hour, kms} -> length(kms) end)
      |> elem(0)
    else
      nil
    end
  end

  defp analyze_activity_trend(killmails) do
    # Analyze if activity is increasing or decreasing
    if length(killmails) < 2 do
      :insufficient_data
    else
      # Split killmails into two halves and compare
      sorted_killmails = Enum.sort_by(killmails, & &1.killmail_time)
      mid_point = div(length(sorted_killmails), 2)

      first_half = Enum.take(sorted_killmails, mid_point)
      second_half = Enum.drop(sorted_killmails, mid_point)

      first_half_count = length(first_half)
      second_half_count = length(second_half)

      cond do
        second_half_count > first_half_count * 1.5 -> :increasing
        second_half_count < first_half_count * 0.5 -> :decreasing
        true -> :stable
      end
    end
  end

  defp analyze_corp_presence(system_id, time_window_hours) do
    # Analyze corporation presence in the system
    killmails = get_system_killmails(system_id, time_window_hours)

    corp_participation =
      killmails
      |> Enum.flat_map(&extract_corp_ids_from_killmail/1)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_corp_id, count} -> count end, :desc)
      |> Enum.take(10)

    %{
      active_corporations: length(corp_participation),
      dominant_corps: Enum.take(corp_participation, 3),
      corp_diversity: calculate_corp_diversity(corp_participation),
      potential_conflicts: identify_potential_conflicts(corp_participation)
    }
  end

  defp extract_corp_ids_from_killmail(killmail) do
    # Extract corporation IDs from killmail
    corp_ids = [killmail.victim_corporation_id]

    attacker_corps =
      case killmail.raw_data do
        %{"attackers" => attackers} when is_list(attackers) ->
          attackers
          |> Enum.map(& &1["corporation_id"])
          |> Enum.filter(&(&1 != nil))
          |> Enum.map(fn
            id when is_binary(id) -> String.to_integer(id)
            id when is_integer(id) -> id
          end)

        _ ->
          []
      end

    corp_ids ++ attacker_corps
  end

  defp calculate_corp_diversity(corp_participation) do
    # Calculate diversity using Shannon diversity index
    total_participation =
      corp_participation
      |> Enum.map(fn {_corp_id, count} -> count end)
      |> Enum.sum()

    if total_participation > 0 do
      diversity =
        corp_participation
        |> Enum.map(fn {_corp_id, count} ->
          proportion = count / total_participation

          if proportion > 0 do
            -proportion * :math.log2(proportion)
          else
            0
          end
        end)
        |> Enum.sum()

      diversity
    else
      0.0
    end
  end

  defp identify_potential_conflicts(corp_participation) do
    # Identify potential conflicts based on corp participation patterns
    # Simplified analysis - in production would use historical conflict data
    if length(corp_participation) > 5 do
      [:high_competition]
    else
      []
    end
  end

  defp calculate_activity_level(system_id, time_window_hours) do
    # Calculate overall activity level for the system
    killmails = get_system_killmails(system_id, time_window_hours)
    killmail_count = length(killmails)

    # Activity level based on killmail frequency
    activity_per_hour = killmail_count / time_window_hours

    cond do
      activity_per_hour > 5 -> :very_high
      activity_per_hour > 2 -> :high
      activity_per_hour > 1 -> :medium
      activity_per_hour > 0.5 -> :low
      true -> :very_low
    end
  end

  defp identify_threat_indicators(system_id, time_window_hours) do
    # Identify threat indicators in the system
    killmails = get_system_killmails(system_id, time_window_hours)

    threat_indicators = []

    # Check for capital ship activity
    threat_indicators =
      if Enum.any?(killmails, &has_capital_ships/1) do
        [:capital_activity | threat_indicators]
      else
        threat_indicators
      end

    # Check for high-value targets
    threat_indicators =
      if Enum.any?(killmails, &is_high_value_target/1) do
        [:high_value_targets | threat_indicators]
      else
        threat_indicators
      end

    # Check for fleet activity
    threat_indicators =
      if has_fleet_activity(killmails) do
        [:fleet_activity | threat_indicators]
      else
        threat_indicators
      end

    threat_indicators
  end

  defp has_capital_ships(killmail) do
    # Check if killmail involves capital ships
    ship_type_id = killmail.victim_ship_type_id

    # Capital ship type ID ranges (simplified)
    ship_type_id in 19_720..19_740 or
      (killmail.raw_data["attackers"] || [])
      |> Enum.any?(fn attacker ->
        case attacker["ship_type_id"] do
          id when is_integer(id) -> id in 19_720..19_740
          id when is_binary(id) -> String.to_integer(id) in 19_720..19_740
          _ -> false
        end
      end)
  end

  defp is_high_value_target(killmail) do
    # Check if killmail represents a high-value target
    ship_type_id = killmail.victim_ship_type_id

    # High-value ship types (simplified)
    # Capitals
    # T3 Cruisers (example range)
    ship_type_id in 19_720..19_740 or
      ship_type_id in 28_352..28_356
  end

  defp has_fleet_activity(killmails) do
    # Check if there's evidence of fleet activity
    # Look for killmails with many attackers
    Enum.any?(killmails, fn km ->
      attacker_count =
        case km.raw_data do
          %{"attackers" => attackers} when is_list(attackers) -> length(attackers)
          _ -> 0
        end

      # Arbitrary threshold for fleet activity
      attacker_count > 5
    end)
  end

  defp calculate_chain_activity_level(system_activities) do
    # Calculate overall activity level for the entire chain
    total_activity =
      system_activities
      |> Enum.map(fn system ->
        case system.activity_level do
          :very_high -> 5
          :high -> 4
          :medium -> 3
          :low -> 2
          :very_low -> 1
        end
      end)
      |> Enum.sum()

    average_activity = total_activity / length(system_activities)

    cond do
      average_activity > 4 -> :very_high
      average_activity > 3 -> :high
      average_activity > 2 -> :medium
      average_activity > 1 -> :low
      true -> :very_low
    end
  end

  defp identify_activity_hotspots(system_activities) do
    # Identify systems with highest activity
    system_activities
    |> Enum.filter(fn system ->
      system.activity_level in [:high, :very_high]
    end)
    |> Enum.sort_by(& &1.pilot_activity.activity_score, :desc)
    |> Enum.take(3)
  end

  defp identify_activity_patterns(system_activities) do
    # Identify patterns in activity distribution
    patterns = []

    # Check for activity concentration
    hotspot_count = length(identify_activity_hotspots(system_activities))
    total_systems = length(system_activities)

    patterns =
      if hotspot_count / total_systems > 0.5 do
        [:distributed_activity | patterns]
      else
        [:concentrated_activity | patterns]
      end

    # Check for temporal patterns
    patterns =
      if has_synchronized_activity(system_activities) do
        [:synchronized_activity | patterns]
      else
        patterns
      end

    patterns
  end

  defp has_synchronized_activity(system_activities) do
    # Check if systems have synchronized activity patterns
    # Simplified - would analyze temporal correlations in production
    peak_times =
      system_activities
      |> Enum.map(& &1.pilot_activity.peak_activity_time)
      |> Enum.filter(&(&1 != nil))

    if length(peak_times) > 1 do
      # Check if peak times are within 2 hours of each other
      time_differences =
        peak_times
        |> Enum.map(&Time.to_seconds_after_midnight/1)
        |> Enum.sort()

      max_time = List.last(time_differences)
      min_time = List.first(time_differences)

      # 2 hours in seconds
      max_time - min_time < 7200
    else
      false
    end
  end

  defp analyze_temporal_distribution(system_activities) do
    # Analyze temporal distribution of activity
    all_killmails =
      system_activities
      |> Enum.flat_map(& &1.killmails)

    if length(all_killmails) > 0 do
      # Group by hour of day
      hourly_distribution =
        all_killmails
        |> Enum.group_by(fn km ->
          DateTime.to_time(km.killmail_time).hour
        end)
        |> Enum.map(fn {hour, kms} ->
          {hour, length(kms)}
        end)
        |> Enum.sort_by(fn {hour, _count} -> hour end)

      peak_hour =
        hourly_distribution
        |> Enum.max_by(fn {_hour, count} -> count end)
        |> elem(0)

      %{
        hourly_distribution: hourly_distribution,
        peak_hour: peak_hour,
        activity_spread: calculate_activity_spread(hourly_distribution)
      }
    else
      %{
        hourly_distribution: [],
        peak_hour: nil,
        activity_spread: 0.0
      }
    end
  end

  defp calculate_activity_spread(hourly_distribution) do
    # Calculate how spread out the activity is across hours
    if length(hourly_distribution) > 0 do
      total_activity =
        hourly_distribution |> Enum.map(fn {_hour, count} -> count end) |> Enum.sum()

      # Calculate variance
      # 24 hours
      mean_activity = total_activity / 24

      variance =
        hourly_distribution
        |> Enum.map(fn {_hour, count} -> :math.pow(count - mean_activity, 2) end)
        |> Enum.sum()
        |> div(24)

      :math.sqrt(variance)
    else
      0.0
    end
  end

  defp maybe_analyze_chain_threats(chain_map, include_threats, time_window_hours) do
    if include_threats do
      analyze_chain_threats(chain_map, time_window_hours)
    else
      {:ok, %{threat_analysis_skipped: true}}
    end
  end

  defp analyze_chain_threats(chain_map, time_window_hours) do
    # Analyze threats across the wormhole chain
    system_threats =
      chain_map.systems
      |> Enum.map(fn system_id ->
        analyze_system_threats(system_id, time_window_hours)
      end)

    chain_threat_analysis = %{
      system_threats: system_threats,
      overall_threat_level: calculate_overall_threat_level(system_threats),
      threat_vectors: identify_threat_vectors(system_threats),
      recommended_actions: generate_threat_recommendations(system_threats)
    }

    {:ok, chain_threat_analysis}
  end

  defp analyze_system_threats(system_id, time_window_hours) do
    # Analyze threats for a specific system
    killmails = get_system_killmails(system_id, time_window_hours)

    %{
      system_id: system_id,
      threat_level: calculate_system_threat_level(killmails),
      hostile_entities: identify_hostile_entities(killmails),
      threat_trends: analyze_threat_trends(killmails),
      vulnerability_assessment: assess_system_vulnerabilities(killmails)
    }
  end

  defp calculate_system_threat_level(killmails) do
    # Calculate threat level based on killmail analysis
    threat_score = 0

    # Factor in killmail frequency
    threat_score = threat_score + length(killmails) * 2

    # Factor in capital ship presence
    threat_score = threat_score + (killmails |> Enum.count(&has_capital_ships/1)) * 10

    # Factor in fleet activity
    threat_score = threat_score + if has_fleet_activity(killmails), do: 20, else: 0

    # Factor in high-value targets
    threat_score = threat_score + (killmails |> Enum.count(&is_high_value_target/1)) * 5

    # Convert to threat level
    cond do
      threat_score > 100 -> :critical
      threat_score > 50 -> :high
      threat_score > 20 -> :medium
      threat_score > 5 -> :low
      true -> :minimal
    end
  end

  defp identify_hostile_entities(killmails) do
    # Identify potentially hostile entities based on killmail patterns
    # This is simplified - in production would use more sophisticated analysis

    aggressor_corps =
      killmails
      |> Enum.flat_map(&extract_aggressor_corps/1)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_corp_id, count} -> count end, :desc)
      |> Enum.take(5)

    %{
      hostile_corporations: aggressor_corps,
      threat_assessment: assess_entity_threats(aggressor_corps)
    }
  end

  defp extract_aggressor_corps(killmail) do
    # Extract corporation IDs of attackers
    case killmail.raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        attackers
        |> Enum.map(& &1["corporation_id"])
        |> Enum.filter(&(&1 != nil))
        |> Enum.map(fn
          id when is_binary(id) -> String.to_integer(id)
          id when is_integer(id) -> id
        end)

      _ ->
        []
    end
  end

  defp assess_entity_threats(aggressor_corps) do
    # Assess threat level of different entities
    aggressor_corps
    |> Enum.map(fn {corp_id, activity_count} ->
      threat_level =
        case activity_count do
          count when count > 10 -> :high
          count when count > 5 -> :medium
          _ -> :low
        end

      %{
        corporation_id: corp_id,
        activity_count: activity_count,
        threat_level: threat_level
      }
    end)
  end

  defp analyze_threat_trends(killmails) do
    # Analyze how threats are trending over time
    if length(killmails) > 4 do
      # Split into quarters and analyze trend
      sorted_killmails = Enum.sort_by(killmails, & &1.killmail_time)
      quarter_size = div(length(sorted_killmails), 4)

      quarters = [
        Enum.slice(sorted_killmails, 0, quarter_size),
        Enum.slice(sorted_killmails, quarter_size, quarter_size),
        Enum.slice(sorted_killmails, 2 * quarter_size, quarter_size),
        Enum.slice(sorted_killmails, 3 * quarter_size, quarter_size)
      ]

      quarter_threat_scores =
        quarters
        |> Enum.map(&calculate_system_threat_level/1)
        |> Enum.map(&threat_level_to_score/1)

      # Analyze trend
      trend = analyze_score_trend(quarter_threat_scores)

      %{
        trend: trend,
        threat_progression: quarter_threat_scores,
        confidence: calculate_trend_confidence(quarter_threat_scores)
      }
    else
      %{
        trend: :insufficient_data,
        threat_progression: [],
        confidence: 0.0
      }
    end
  end

  defp threat_level_to_score(threat_level) do
    case threat_level do
      :critical -> 5
      :high -> 4
      :medium -> 3
      :low -> 2
      :minimal -> 1
    end
  end

  defp analyze_score_trend(scores) do
    if length(scores) < 2 do
      :insufficient_data
    else
      # Calculate linear trend
      n = length(scores)
      x_values = 1..n |> Enum.to_list()
      y_values = scores

      # Simple linear regression
      x_mean = Enum.sum(x_values) / n
      y_mean = Enum.sum(y_values) / n

      numerator =
        Enum.zip(x_values, y_values)
        |> Enum.map(fn {x, y} -> (x - x_mean) * (y - y_mean) end)
        |> Enum.sum()

      denominator =
        x_values
        |> Enum.map(fn x -> :math.pow(x - x_mean, 2) end)
        |> Enum.sum()

      if denominator > 0 do
        slope = numerator / denominator

        cond do
          slope > 0.5 -> :increasing
          slope < -0.5 -> :decreasing
          true -> :stable
        end
      else
        :stable
      end
    end
  end

  defp calculate_trend_confidence(scores) do
    # Calculate confidence in trend analysis
    if length(scores) > 2 do
      # Use standard deviation as a measure of confidence
      mean = Enum.sum(scores) / length(scores)

      variance =
        scores
        |> Enum.map(fn score -> :math.pow(score - mean, 2) end)
        |> Enum.sum()
        |> div(length(scores))

      std_dev = :math.sqrt(variance)

      # Lower standard deviation = higher confidence
      max(0.0, 1.0 - std_dev / 5.0)
    else
      0.0
    end
  end

  defp assess_system_vulnerabilities(killmails) do
    # Assess vulnerabilities based on killmail patterns
    vulnerabilities = []

    # Check for predictable activity patterns
    vulnerabilities =
      if has_predictable_patterns(killmails) do
        [:predictable_activity | vulnerabilities]
      else
        vulnerabilities
      end

    # Check for defensive weaknesses
    vulnerabilities =
      if has_defensive_weaknesses(killmails) do
        [:weak_defenses | vulnerabilities]
      else
        vulnerabilities
      end

    # Check for strategic vulnerabilities
    vulnerabilities =
      if has_strategic_vulnerabilities(killmails) do
        [:strategic_exposure | vulnerabilities]
      else
        vulnerabilities
      end

    vulnerabilities
  end

  defp has_predictable_patterns(killmails) do
    # Check if activity follows predictable patterns
    # Simplified - would analyze temporal patterns in production
    length(killmails) > 0 and rem(length(killmails), 4) == 0
  end

  defp has_defensive_weaknesses(killmails) do
    # Check for evidence of defensive weaknesses
    # Look for lopsided killmails (many attackers, few defenders)
    Enum.any?(killmails, fn km ->
      attacker_count =
        case km.raw_data do
          %{"attackers" => attackers} when is_list(attackers) -> length(attackers)
          _ -> 0
        end

      # High attacker count suggests weak defense
      attacker_count > 10
    end)
  end

  defp has_strategic_vulnerabilities(killmails) do
    # Check for strategic vulnerabilities
    # Look for high-value losses that suggest strategic exposure
    Enum.count(killmails, &is_high_value_target/1) > 2
  end

  defp calculate_overall_threat_level(system_threats) do
    # Calculate overall threat level for the chain
    threat_scores =
      system_threats
      |> Enum.map(fn system ->
        threat_level_to_score(system.threat_level)
      end)

    if length(threat_scores) > 0 do
      average_threat = Enum.sum(threat_scores) / length(threat_scores)

      cond do
        average_threat > 4 -> :critical
        average_threat > 3 -> :high
        average_threat > 2 -> :medium
        average_threat > 1 -> :low
        true -> :minimal
      end
    else
      :minimal
    end
  end

  defp identify_threat_vectors(system_threats) do
    # Identify primary threat vectors across the chain
    all_threat_vectors =
      system_threats
      |> Enum.flat_map(fn system ->
        system.vulnerability_assessment
      end)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_vector, count} -> count end, :desc)

    all_threat_vectors
  end

  defp generate_threat_recommendations(system_threats) do
    # Generate recommendations based on threat analysis
    recommendations = []

    # Check for high-threat systems
    high_threat_systems =
      system_threats
      |> Enum.filter(fn system -> system.threat_level in [:high, :critical] end)

    recommendations =
      if length(high_threat_systems) > 0 do
        ["Increase monitoring of high-threat systems" | recommendations]
      else
        recommendations
      end

    # Check for defensive weaknesses
    vulnerable_systems =
      system_threats
      |> Enum.filter(fn system -> :weak_defenses in system.vulnerability_assessment end)

    recommendations =
      if length(vulnerable_systems) > 0 do
        ["Strengthen defensive capabilities in vulnerable systems" | recommendations]
      else
        recommendations
      end

    # Check for strategic exposure
    exposed_systems =
      system_threats
      |> Enum.filter(fn system -> :strategic_exposure in system.vulnerability_assessment end)

    recommendations =
      if length(exposed_systems) > 0 do
        ["Review strategic positioning and exposure" | recommendations]
      else
        recommendations
      end

    recommendations
  end

  defp analyze_strategic_significance(
         chain_map,
         connection_data,
         activity_analysis,
         threat_assessment
       ) do
    # Analyze the strategic significance of the wormhole chain
    strategic_factors = []

    # Factor in chain depth
    depth_significance =
      case chain_map.max_depth do
        depth when depth > 5 -> :very_high
        depth when depth > 3 -> :high
        depth when depth > 1 -> :medium
        _ -> :low
      end

    strategic_factors = [{:chain_depth, depth_significance} | strategic_factors]

    # Factor in connection quality
    high_value_connections =
      connection_data
      |> Enum.count(fn conn -> conn.strategic_value in [:high, :very_high] end)

    connection_significance =
      case high_value_connections do
        count when count > 3 -> :very_high
        count when count > 1 -> :high
        count when count > 0 -> :medium
        _ -> :low
      end

    strategic_factors = [{:connection_quality, connection_significance} | strategic_factors]

    # Factor in activity level
    activity_significance =
      case activity_analysis do
        %{chain_activity_level: level} -> level
        _ -> :unknown
      end

    strategic_factors = [{:activity_level, activity_significance} | strategic_factors]

    # Factor in threat level
    threat_significance =
      case threat_assessment do
        %{overall_threat_level: level} -> level
        _ -> :unknown
      end

    strategic_factors = [{:threat_level, threat_significance} | strategic_factors]

    # Calculate overall strategic rating
    strategic_rating = calculate_strategic_rating(strategic_factors)

    strategic_analysis = %{
      strategic_factors: strategic_factors,
      strategic_rating: strategic_rating,
      key_advantages: identify_strategic_advantages(strategic_factors),
      key_risks: identify_strategic_risks(strategic_factors),
      strategic_recommendations: generate_strategic_recommendations(strategic_factors)
    }

    {:ok, strategic_analysis}
  end

  defp calculate_strategic_rating(strategic_factors) do
    # Calculate overall strategic rating
    factor_scores =
      strategic_factors
      |> Enum.map(fn {_factor, significance} ->
        case significance do
          :very_high -> 5
          :high -> 4
          :medium -> 3
          :low -> 2
          :minimal -> 1
          _ -> 0
        end
      end)

    if length(factor_scores) > 0 do
      average_score = Enum.sum(factor_scores) / length(factor_scores)

      cond do
        average_score > 4 -> :exceptional
        average_score > 3 -> :high
        average_score > 2 -> :moderate
        average_score > 1 -> :low
        true -> :minimal
      end
    else
      :unknown
    end
  end

  defp identify_strategic_advantages(strategic_factors) do
    # Identify strategic advantages
    advantages = []

    advantages =
      if get_factor_value(strategic_factors, :chain_depth) in [:high, :very_high] do
        ["Deep chain provides strategic depth" | advantages]
      else
        advantages
      end

    advantages =
      if get_factor_value(strategic_factors, :connection_quality) in [:high, :very_high] do
        ["High-quality connections enable strategic mobility" | advantages]
      else
        advantages
      end

    advantages =
      if get_factor_value(strategic_factors, :activity_level) in [:high, :very_high] do
        ["High activity provides intelligence opportunities" | advantages]
      else
        advantages
      end

    advantages
  end

  defp identify_strategic_risks(strategic_factors) do
    # Identify strategic risks
    risks = []

    risks =
      if get_factor_value(strategic_factors, :threat_level) in [:high, :critical] do
        ["High threat level increases operational risk" | risks]
      else
        risks
      end

    risks =
      if get_factor_value(strategic_factors, :activity_level) in [:high, :very_high] do
        ["High activity increases detection risk" | risks]
      else
        risks
      end

    risks
  end

  defp generate_strategic_recommendations(strategic_factors) do
    # Generate strategic recommendations
    recommendations = []

    # Recommendations based on chain depth
    recommendations =
      case get_factor_value(strategic_factors, :chain_depth) do
        depth when depth in [:high, :very_high] ->
          ["Leverage deep chain for strategic positioning" | recommendations]

        :low ->
          ["Consider expanding chain depth for strategic advantage" | recommendations]

        _ ->
          recommendations
      end

    # Recommendations based on threat level
    recommendations =
      case get_factor_value(strategic_factors, :threat_level) do
        threat when threat in [:high, :critical] ->
          ["Implement enhanced security measures" | recommendations]

        _ ->
          recommendations
      end

    recommendations
  end

  defp get_factor_value(strategic_factors, factor_key) do
    strategic_factors
    |> Enum.find(fn {key, _value} -> key == factor_key end)
    |> case do
      {_key, value} -> value
      nil -> :unknown
    end
  end

  defp compile_chain_analysis(
         starting_system_id,
         chain_map,
         connection_data,
         activity_analysis,
         threat_assessment,
         strategic_analysis
       ) do
    # Compile comprehensive chain analysis
    final_analysis = %{
      analysis_id: generate_analysis_id(),
      starting_system_id: starting_system_id,
      chain_map: chain_map,
      connection_analysis: connection_data,
      activity_analysis: activity_analysis,
      threat_assessment: threat_assessment,
      strategic_analysis: strategic_analysis,
      analysis_metadata: %{
        analyzed_at: DateTime.utc_now(),
        analysis_type: :wormhole_chain,
        analysis_scope: :cross_system,
        confidence_level:
          calculate_analysis_confidence(chain_map, connection_data, activity_analysis)
      }
    }

    {:ok, final_analysis}
  end

  defp generate_analysis_id do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  defp calculate_analysis_confidence(chain_map, connection_data, activity_analysis) do
    # Calculate confidence in the analysis
    confidence_factors = []

    # Factor in data availability
    data_availability =
      case activity_analysis do
        %{systems: systems} when systems != [] -> 0.8
        _ -> 0.3
      end

    confidence_factors = [data_availability | confidence_factors]

    # Factor in chain completeness
    chain_completeness = min(1.0, length(chain_map.systems) / 10)
    confidence_factors = [chain_completeness | confidence_factors]

    # Factor in connection data quality
    connection_quality = min(1.0, length(connection_data) / length(chain_map.connections))
    confidence_factors = [connection_quality | confidence_factors]

    # Calculate overall confidence
    if length(confidence_factors) > 0 do
      Enum.sum(confidence_factors) / length(confidence_factors)
    else
      0.0
    end
  end

  # Cross-system correlation algorithm implementations

  defp fetch_system_activities(system_ids, time_window_hours) do
    # Fetch comprehensive activity data for all specified systems
    start_time = DateTime.utc_now() |> DateTime.add(-time_window_hours, :hour)

    Logger.info("Fetching activity data for #{length(system_ids)} systems from #{start_time}")

    system_activities =
      system_ids
      |> Enum.map(fn system_id ->
        killmails = get_system_killmails(system_id, time_window_hours)

        %{
          system_id: system_id,
          killmails: killmails,
          activity_timeline: build_activity_timeline(killmails),
          pilot_activity: extract_pilot_activity_data(killmails),
          corp_activity: extract_corp_activity_data(killmails),
          ship_activity: extract_ship_activity_data(killmails),
          temporal_markers: extract_temporal_markers(killmails)
        }
      end)

    {:ok,
     %{
       systems: system_activities,
       time_window: time_window_hours,
       analysis_period: {start_time, DateTime.utc_now()},
       total_systems: length(system_ids)
     }}
  end

  defp build_activity_timeline(killmails) do
    # Build detailed timeline of activity events
    killmails
    |> Enum.map(fn km ->
      %{
        timestamp: km.killmail_time,
        event_type: :killmail,
        participants: extract_all_participants_from_killmail(km),
        system_id: km.solar_system_id,
        activity_intensity: calculate_killmail_intensity(km)
      }
    end)
    |> Enum.sort_by(& &1.timestamp)
  end

  defp extract_pilot_activity_data(killmails) do
    # Extract detailed pilot activity patterns
    pilot_data =
      killmails
      |> Enum.flat_map(&extract_all_participants_from_killmail/1)
      |> Enum.frequencies()
      |> Enum.map(fn {pilot_id, activity_count} ->
        pilot_killmails = Enum.filter(killmails, &pilot_participated_in_killmail?(&1, pilot_id))

        %{
          pilot_id: pilot_id,
          activity_count: activity_count,
          first_seen: get_first_activity_time(pilot_killmails),
          last_seen: get_last_activity_time(pilot_killmails),
          activity_pattern: analyze_pilot_activity_pattern(pilot_killmails),
          ship_preferences: extract_pilot_ship_usage(pilot_killmails, pilot_id)
        }
      end)

    %{
      unique_pilots: length(pilot_data),
      pilot_details: pilot_data,
      activity_distribution: calculate_pilot_activity_distribution(pilot_data)
    }
  end

  defp extract_corp_activity_data(killmails) do
    # Extract corporation activity patterns
    corp_data =
      killmails
      |> Enum.flat_map(&extract_corp_ids_from_killmail/1)
      |> Enum.frequencies()
      |> Enum.map(fn {corp_id, activity_count} ->
        corp_killmails = Enum.filter(killmails, &corp_participated_in_killmail?(&1, corp_id))

        %{
          corp_id: corp_id,
          activity_count: activity_count,
          first_activity: get_first_activity_time(corp_killmails),
          last_activity: get_last_activity_time(corp_killmails),
          engagement_style: analyze_corp_engagement_style(corp_killmails),
          territorial_focus: analyze_corp_territorial_focus(corp_killmails)
        }
      end)

    %{
      active_corporations: length(corp_data),
      corp_details: corp_data,
      alliance_patterns: extract_alliance_patterns(corp_data)
    }
  end

  defp extract_ship_activity_data(killmails) do
    # Extract ship type usage patterns
    ship_usage =
      killmails
      |> Enum.flat_map(&extract_ship_types_from_killmail/1)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_ship_type, count} -> count end, :desc)

    %{
      ship_type_distribution: ship_usage,
      dominant_ship_classes: Enum.take(ship_usage, 10),
      tactical_composition: analyze_tactical_ship_composition(ship_usage)
    }
  end

  defp extract_temporal_markers(killmails) do
    # Extract temporal markers for correlation analysis
    killmails
    |> Enum.map(fn km ->
      %{
        timestamp: km.killmail_time,
        hour_of_day: km.killmail_time.hour,
        day_of_week: Date.day_of_week(DateTime.to_date(km.killmail_time)),
        # 15-minute buckets
        minute_marker: div(km.killmail_time.minute, 15) * 15
      }
    end)
  end

  defp analyze_temporal_correlations(system_activities) do
    # Implement sophisticated temporal correlation analysis
    Logger.info(
      "Analyzing temporal correlations across #{length(system_activities.systems)} systems"
    )

    # Extract time series data for each system
    time_series_data =
      system_activities.systems
      |> Enum.map(fn system ->
        {system.system_id, build_time_series(system.activity_timeline)}
      end)
      |> Enum.into(%{})

    # Calculate cross-correlations between systems
    correlations = calculate_cross_correlations(time_series_data)

    # Identify temporal patterns
    patterns = identify_temporal_patterns(time_series_data, correlations)

    # Calculate confidence in correlation analysis
    confidence = calculate_correlation_confidence(correlations, time_series_data)

    {:ok,
     %{
       correlations: correlations,
       patterns: patterns,
       confidence: confidence,
       time_series_analysis: %{
         systems_analyzed: length(system_activities.systems),
         correlation_pairs: length(correlations),
         significant_correlations: count_significant_correlations(correlations)
       }
     }}
  end

  defp build_time_series(activity_timeline) do
    # Build time series with 15-minute buckets
    timeline_start =
      case activity_timeline do
        [first | _] -> first.timestamp
        [] -> DateTime.utc_now() |> DateTime.add(-24, :hour)
      end

    timeline_end = DateTime.utc_now()

    # Create 15-minute buckets
    # 15 minutes = 900 seconds
    bucket_count = div(DateTime.diff(timeline_end, timeline_start, :second), 900)

    buckets =
      0..bucket_count
      |> Enum.map(fn bucket_index ->
        bucket_start = DateTime.add(timeline_start, bucket_index * 900, :second)
        bucket_end = DateTime.add(bucket_start, 900, :second)

        bucket_activity =
          activity_timeline
          |> Enum.filter(fn event ->
            DateTime.compare(event.timestamp, bucket_start) in [:gt, :eq] and
              DateTime.compare(event.timestamp, bucket_end) == :lt
          end)

        %{
          bucket_index: bucket_index,
          timestamp: bucket_start,
          activity_count: length(bucket_activity),
          intensity_sum: Enum.sum(Enum.map(bucket_activity, & &1.activity_intensity))
        }
      end)

    buckets
  end

  defp calculate_cross_correlations(time_series_data) do
    # Calculate cross-correlations between all system pairs
    system_ids = Map.keys(time_series_data)

    system_ids
    |> combinations(2)
    |> Enum.map(fn [system_a, system_b] ->
      series_a = time_series_data[system_a]
      series_b = time_series_data[system_b]

      correlation = calculate_pearson_correlation(series_a, series_b)
      lag_correlation = calculate_lag_correlation(series_a, series_b)

      %{
        system_pair: {system_a, system_b},
        correlation_coefficient: correlation,
        lag_analysis: lag_correlation,
        significance: assess_correlation_significance(correlation, length(series_a))
      }
    end)
  end

  defp calculate_pearson_correlation(series_a, series_b) do
    # Calculate Pearson correlation coefficient between two time series
    if length(series_a) != length(series_b) or length(series_a) < 2 do
      0.0
    else
      values_a = Enum.map(series_a, & &1.activity_count)
      values_b = Enum.map(series_b, & &1.activity_count)

      n = length(values_a)
      mean_a = Enum.sum(values_a) / n
      mean_b = Enum.sum(values_b) / n

      numerator =
        Enum.zip(values_a, values_b)
        |> Enum.map(fn {a, b} -> (a - mean_a) * (b - mean_b) end)
        |> Enum.sum()

      sum_sq_a = Enum.map(values_a, fn a -> :math.pow(a - mean_a, 2) end) |> Enum.sum()
      sum_sq_b = Enum.map(values_b, fn b -> :math.pow(b - mean_b, 2) end) |> Enum.sum()

      denominator = :math.sqrt(sum_sq_a * sum_sq_b)

      if denominator > 0 do
        numerator / denominator
      else
        0.0
      end
    end
  end

  defp calculate_lag_correlation(series_a, series_b) do
    # Calculate correlation at different time lags
    # Up to 12 buckets (3 hours) or 1/4 series length
    max_lag = min(12, div(length(series_a), 4))

    lag_correlations =
      -max_lag..max_lag
      |> Enum.map(fn lag ->
        shifted_correlation = calculate_shifted_correlation(series_a, series_b, lag)
        {lag, shifted_correlation}
      end)
      |> Enum.into(%{})

    best_lag =
      lag_correlations
      |> Enum.max_by(fn {_lag, correlation} -> abs(correlation) end)

    %{
      lag_correlations: lag_correlations,
      best_lag: best_lag,
      max_correlation: elem(best_lag, 1)
    }
  end

  defp calculate_shifted_correlation(series_a, series_b, lag) do
    # Calculate correlation with series_b shifted by lag
    if lag == 0 do
      calculate_pearson_correlation(series_a, series_b)
    else
      if lag > 0 do
        # Positive lag: series_b leads series_a
        truncated_a = Enum.drop(series_a, lag)
        truncated_b = Enum.take(series_b, length(series_a) - lag)
        calculate_pearson_correlation(truncated_a, truncated_b)
      else
        # Negative lag: series_a leads series_b
        abs_lag = abs(lag)
        truncated_a = Enum.take(series_a, length(series_a) - abs_lag)
        truncated_b = Enum.drop(series_b, abs_lag)
        calculate_pearson_correlation(truncated_a, truncated_b)
      end
    end
  end

  defp assess_correlation_significance(correlation, sample_size) do
    # Assess statistical significance of correlation
    abs_correlation = abs(correlation)

    cond do
      sample_size < 10 -> :insufficient_data
      abs_correlation > 0.8 and sample_size > 20 -> :very_significant
      abs_correlation > 0.6 and sample_size > 15 -> :significant
      abs_correlation > 0.4 and sample_size > 10 -> :moderate
      abs_correlation > 0.2 -> :weak
      true -> :not_significant
    end
  end

  defp identify_temporal_patterns(time_series_data, correlations) do
    # Identify meaningful temporal patterns
    patterns = []

    # Pattern 1: Synchronized activity bursts
    patterns =
      if has_synchronized_bursts(time_series_data) do
        [:synchronized_activity_bursts | patterns]
      else
        patterns
      end

    # Pattern 2: Sequential activity waves
    patterns =
      if has_sequential_waves(correlations) do
        [:sequential_activity_waves | patterns]
      else
        patterns
      end

    # Pattern 3: Anti-correlated activity (one system active when others quiet)
    patterns =
      if has_anti_correlation(correlations) do
        [:anti_correlated_activity | patterns]
      else
        patterns
      end

    # Pattern 4: Periodic activity cycles
    patterns =
      if has_periodic_cycles(time_series_data) do
        [:periodic_activity_cycles | patterns]
      else
        patterns
      end

    patterns
  end

  defp has_synchronized_bursts(time_series_data) do
    # Check for synchronized activity bursts across systems
    all_series = Map.values(time_series_data)

    if length(all_series) > 1 do
      # Find high-activity periods for each system
      burst_periods =
        all_series
        |> Enum.map(&identify_activity_bursts/1)

      # Check for overlapping burst periods
      has_overlapping_bursts(burst_periods)
    else
      false
    end
  end

  defp identify_activity_bursts(time_series) do
    # Identify periods of significantly high activity
    if length(time_series) > 0 do
      activity_values = Enum.map(time_series, & &1.activity_count)
      mean_activity = Enum.sum(activity_values) / length(activity_values)
      std_dev = calculate_standard_deviation(activity_values, mean_activity)

      burst_threshold = mean_activity + 1.5 * std_dev

      time_series
      |> Enum.with_index()
      |> Enum.filter(fn {bucket, _index} -> bucket.activity_count > burst_threshold end)
      |> Enum.map(fn {bucket, index} -> {index, bucket.timestamp} end)
    else
      []
    end
  end

  defp has_overlapping_bursts(burst_periods_list) do
    # Check if different systems have overlapping burst periods
    if length(burst_periods_list) > 1 do
      all_burst_indices =
        burst_periods_list
        |> Enum.flat_map(fn burst_periods ->
          Enum.map(burst_periods, fn {index, _timestamp} -> index end)
        end)
        |> Enum.frequencies()

      # If any time bucket has bursts from multiple systems, they're synchronized
      all_burst_indices
      |> Map.values()
      |> Enum.any?(fn count -> count > 1 end)
    else
      false
    end
  end

  defp has_sequential_waves(correlations) do
    # Check for sequential activity waves (lag correlations)
    correlations
    |> Enum.any?(fn correlation ->
      correlation.lag_analysis.best_lag != {0, correlation.correlation_coefficient} and
        abs(elem(correlation.lag_analysis.best_lag, 1)) > 0.5
    end)
  end

  defp has_anti_correlation(correlations) do
    # Check for anti-correlated activity patterns
    correlations
    |> Enum.any?(fn correlation ->
      correlation.correlation_coefficient < -0.4 and
        correlation.significance in [:significant, :very_significant]
    end)
  end

  defp has_periodic_cycles(time_series_data) do
    # Check for periodic activity cycles
    all_series = Map.values(time_series_data)

    all_series
    |> Enum.any?(fn series ->
      detect_periodicity(series)
    end)
  end

  defp detect_periodicity(time_series) do
    # Simple periodicity detection using autocorrelation
    # Need at least 6 hours of data
    if length(time_series) > 24 do
      activity_values = Enum.map(time_series, & &1.activity_count)

      # Check for daily patterns (96 buckets = 24 hours)
      daily_lag = min(96, div(length(activity_values), 2))

      if daily_lag > 12 do
        daily_correlation = calculate_autocorrelation(activity_values, daily_lag)
        abs(daily_correlation) > 0.3
      else
        false
      end
    else
      false
    end
  end

  defp calculate_autocorrelation(values, lag) do
    # Calculate autocorrelation at specified lag
    if lag >= length(values) do
      0.0
    else
      series_1 = Enum.take(values, length(values) - lag)
      series_2 = Enum.drop(values, lag)

      # Use mock series structures for correlation calculation
      mock_series_1 = Enum.map(series_1, fn val -> %{activity_count: val} end)
      mock_series_2 = Enum.map(series_2, fn val -> %{activity_count: val} end)

      calculate_pearson_correlation(mock_series_1, mock_series_2)
    end
  end

  defp calculate_standard_deviation(values, mean) do
    if length(values) > 1 do
      variance =
        values
        |> Enum.map(fn val -> :math.pow(val - mean, 2) end)
        |> Enum.sum()
        |> Kernel./(length(values) - 1)

      :math.sqrt(variance)
    else
      0.0
    end
  end

  defp calculate_correlation_confidence(correlations, time_series_data) do
    # Calculate overall confidence in correlation analysis
    confidence_factors = []

    # Factor 1: Sample size adequacy
    min_sample_size =
      time_series_data
      |> Map.values()
      |> Enum.map(&length/1)
      |> Enum.min()

    # 50 buckets = ~12.5 hours
    sample_confidence = min(1.0, min_sample_size / 50.0)
    confidence_factors = [sample_confidence | confidence_factors]

    # Factor 2: Number of significant correlations
    significant_count = count_significant_correlations(correlations)
    total_pairs = length(correlations)

    significance_confidence =
      if total_pairs > 0 do
        min(1.0, significant_count / total_pairs)
      else
        0.0
      end

    confidence_factors = [significance_confidence | confidence_factors]

    # Factor 3: Consistency of correlation strengths
    correlation_values = Enum.map(correlations, & &1.correlation_coefficient)
    consistency_confidence = 1.0 - calculate_coefficient_of_variation(correlation_values)

    confidence_factors = [max(0.0, consistency_confidence) | confidence_factors]

    # Calculate weighted average
    Enum.sum(confidence_factors) / length(confidence_factors)
  end

  defp count_significant_correlations(correlations) do
    correlations
    |> Enum.count(fn correlation ->
      correlation.significance in [:significant, :very_significant]
    end)
  end

  defp calculate_coefficient_of_variation(values) do
    if length(values) > 0 do
      mean = Enum.sum(values) / length(values)

      if mean != 0 do
        std_dev = calculate_standard_deviation(values, mean)
        abs(std_dev / mean)
      else
        0.0
      end
    else
      0.0
    end
  end

  defp maybe_track_pilot_movements(system_activities, include_tracking) do
    if include_tracking do
      track_pilot_movements(system_activities)
    else
      {:ok, []}
    end
  end

  defp track_pilot_movements(system_activities) do
    # Track pilot movements across systems
    Logger.info("Tracking pilot movements across systems")

    # Extract all pilot activities with timestamps and locations
    all_pilot_activities =
      system_activities.systems
      |> Enum.flat_map(fn system ->
        system.pilot_activity.pilot_details
        |> Enum.map(fn pilot ->
          %{
            pilot_id: pilot.pilot_id,
            system_id: system.system_id,
            first_seen: pilot.first_seen,
            last_seen: pilot.last_seen,
            activity_count: pilot.activity_count
          }
        end)
      end)

    # Group by pilot and analyze movement patterns
    pilot_movements =
      all_pilot_activities
      |> Enum.group_by(& &1.pilot_id)
      |> Enum.map(fn {pilot_id, activities} ->
        analyze_pilot_movement_pattern(pilot_id, activities)
      end)
      # Only multi-system pilots
      |> Enum.filter(fn movement -> movement.systems_visited > 1 end)

    {:ok, pilot_movements}
  end

  defp analyze_pilot_movement_pattern(pilot_id, activities) do
    # Analyze movement pattern for a specific pilot
    sorted_activities = Enum.sort_by(activities, & &1.first_seen)

    systems_visited =
      activities
      |> Enum.map(& &1.system_id)
      |> Enum.uniq()

    movement_timeline =
      sorted_activities
      |> Enum.map(fn activity ->
        %{
          system_id: activity.system_id,
          entry_time: activity.first_seen,
          exit_time: activity.last_seen,
          dwell_time: DateTime.diff(activity.last_seen, activity.first_seen, :second)
        }
      end)

    %{
      pilot_id: pilot_id,
      systems_visited: length(systems_visited),
      system_sequence: Enum.map(movement_timeline, & &1.system_id),
      movement_timeline: movement_timeline,
      total_movement_duration: calculate_total_movement_duration(movement_timeline),
      movement_velocity: calculate_movement_velocity(movement_timeline),
      movement_pattern: classify_movement_pattern(movement_timeline)
    }
  end

  defp calculate_total_movement_duration(movement_timeline) do
    if length(movement_timeline) > 1 do
      first_entry = List.first(movement_timeline).entry_time
      last_exit = List.last(movement_timeline).exit_time
      DateTime.diff(last_exit, first_entry, :second)
    else
      0
    end
  end

  defp calculate_movement_velocity(movement_timeline) do
    # Calculate average time between system changes
    if length(movement_timeline) > 1 do
      transitions =
        movement_timeline
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [prev, curr] ->
          DateTime.diff(curr.entry_time, prev.exit_time, :second)
        end)

      if length(transitions) > 0 do
        Enum.sum(transitions) / length(transitions)
      else
        0
      end
    else
      0
    end
  end

  defp classify_movement_pattern(movement_timeline) do
    case length(movement_timeline) do
      0 -> :no_movement
      1 -> :stationary
      2 -> :simple_transition
      count when count <= 5 -> :limited_roaming
      _ -> :extensive_roaming
    end
  end

  defp maybe_analyze_corp_activities(system_activities, include_analysis) do
    if include_analysis do
      analyze_corp_activities(system_activities)
    else
      {:ok, %{corporations: [], activities: [], analysis_complete: false}}
    end
  end

  defp analyze_corp_activities(system_activities) do
    # Analyze corporation activity patterns across systems
    Logger.info("Analyzing corporation activities across systems")

    # Aggregate corp activities across all systems
    all_corp_activities =
      system_activities.systems
      |> Enum.flat_map(fn system ->
        system.corp_activity.corp_details
        |> Enum.map(fn corp ->
          %{
            corp_id: corp.corp_id,
            system_id: system.system_id,
            activity_count: corp.activity_count,
            first_activity: corp.first_activity,
            last_activity: corp.last_activity,
            engagement_style: corp.engagement_style
          }
        end)
      end)

    # Group by corporation and analyze patterns
    corp_analyses =
      all_corp_activities
      |> Enum.group_by(& &1.corp_id)
      |> Enum.map(fn {corp_id, activities} ->
        analyze_corp_cross_system_behavior(corp_id, activities)
      end)

    {:ok,
     %{
       corporations: length(corp_analyses),
       corp_analyses: corp_analyses,
       multi_system_corps: Enum.filter(corp_analyses, &(&1.systems_active > 1)),
       analysis_complete: true
     }}
  end

  defp analyze_corp_cross_system_behavior(corp_id, activities) do
    # Analyze corporation behavior across multiple systems
    systems_active =
      activities
      |> Enum.map(& &1.system_id)
      |> Enum.uniq()
      |> length()

    total_activity = Enum.sum(Enum.map(activities, & &1.activity_count))

    territorial_analysis = analyze_corp_territorial_behavior(activities)
    temporal_analysis = analyze_corp_temporal_behavior(activities)

    %{
      corp_id: corp_id,
      systems_active: systems_active,
      total_activity: total_activity,
      territorial_behavior: territorial_analysis,
      temporal_behavior: temporal_analysis,
      strategic_focus: determine_corp_strategic_focus(activities, territorial_analysis)
    }
  end

  defp analyze_corp_territorial_behavior(activities) do
    # Analyze territorial control and focus patterns
    system_activity_distribution =
      activities
      |> Enum.map(fn activity -> {activity.system_id, activity.activity_count} end)
      |> Enum.into(%{})

    _total_activity = Enum.sum(Map.values(system_activity_distribution))

    # Calculate territorial concentration (Gini coefficient)
    concentration = calculate_territorial_concentration(system_activity_distribution)

    dominant_system =
      system_activity_distribution
      |> Enum.max_by(fn {_system, activity} -> activity end)

    %{
      territorial_concentration: concentration,
      dominant_system: dominant_system,
      system_distribution: system_activity_distribution,
      territorial_focus: classify_territorial_focus(concentration, length(activities))
    }
  end

  defp calculate_territorial_concentration(activity_distribution) do
    # Calculate Gini coefficient for territorial concentration
    activities = Map.values(activity_distribution) |> Enum.sort()
    n = length(activities)

    if n > 1 do
      total = Enum.sum(activities)

      numerator =
        activities
        |> Enum.with_index(1)
        |> Enum.map(fn {activity, index} -> (2 * index - n - 1) * activity end)
        |> Enum.sum()

      gini = numerator / (n * total)
      max(0.0, min(1.0, gini))
    else
      # Complete concentration in single system
      1.0
    end
  end

  defp classify_territorial_focus(concentration, system_count) do
    cond do
      concentration > 0.8 or system_count == 1 -> :highly_concentrated
      concentration > 0.6 -> :concentrated
      concentration > 0.4 -> :moderately_distributed
      true -> :widely_distributed
    end
  end

  defp analyze_corp_temporal_behavior(activities) do
    # Analyze temporal patterns of corporation activity
    if length(activities) > 1 do
      all_timestamps =
        activities
        |> Enum.flat_map(fn activity ->
          [activity.first_activity, activity.last_activity]
        end)
        |> Enum.filter(&(&1 != nil))
        |> Enum.sort()

      if length(all_timestamps) > 0 do
        activity_span =
          DateTime.diff(List.last(all_timestamps), List.first(all_timestamps), :hour)

        %{
          activity_span_hours: activity_span,
          first_seen: List.first(all_timestamps),
          last_seen: List.last(all_timestamps),
          temporal_pattern: classify_temporal_pattern(activity_span, length(activities))
        }
      else
        %{activity_span_hours: 0, temporal_pattern: :unknown}
      end
    else
      %{activity_span_hours: 0, temporal_pattern: :single_system}
    end
  end

  defp classify_temporal_pattern(activity_span_hours, system_count) do
    cond do
      activity_span_hours < 1 -> :rapid_deployment
      activity_span_hours < 6 and system_count > 2 -> :coordinated_operation
      activity_span_hours < 24 -> :sustained_campaign
      # 1 week
      activity_span_hours < 168 -> :weekly_operations
      true -> :long_term_presence
    end
  end

  defp determine_corp_strategic_focus(activities, territorial_analysis) do
    # Determine strategic focus based on activity patterns
    systems_count = length(Enum.uniq(Enum.map(activities, & &1.system_id)))
    total_activity = Enum.sum(Enum.map(activities, & &1.activity_count))

    cond do
      systems_count == 1 and total_activity > 10 ->
        :territorial_control

      systems_count > 3 and territorial_analysis.territorial_concentration < 0.5 ->
        :nomadic_operations

      territorial_analysis.territorial_focus == :highly_concentrated ->
        :stronghold_defense

      systems_count > 2 and total_activity > 20 ->
        :aggressive_expansion

      true ->
        :opportunistic_operations
    end
  end

  defp identify_correlation_patterns(
         temporal_correlations,
         pilot_movements,
         corp_activities,
         min_correlation
       ) do
    # Identify meaningful correlation patterns from all analyses
    Logger.info("Identifying correlation patterns with minimum correlation #{min_correlation}")

    patterns = []

    # Pattern 1: Strong temporal correlations
    strong_temporal_patterns =
      identify_strong_temporal_patterns(temporal_correlations, min_correlation)

    patterns = patterns ++ strong_temporal_patterns

    # Pattern 2: Coordinated pilot movements
    movement_patterns = identify_coordinated_movement_patterns(pilot_movements)
    patterns = patterns ++ movement_patterns

    # Pattern 3: Corporation coordination patterns
    corp_coordination_patterns = identify_corp_coordination_patterns(corp_activities)
    patterns = patterns ++ corp_coordination_patterns

    # Pattern 4: Combined tactical patterns
    tactical_patterns =
      identify_combined_tactical_patterns(temporal_correlations, pilot_movements, corp_activities)

    patterns = patterns ++ tactical_patterns

    {:ok, patterns}
  end

  defp identify_strong_temporal_patterns(temporal_correlations, min_correlation) do
    # Identify strong temporal correlation patterns
    strong_correlations =
      temporal_correlations.correlations
      |> Enum.filter(fn corr ->
        abs(corr.correlation_coefficient) >= min_correlation and
          corr.significance in [:significant, :very_significant]
      end)

    patterns = []

    # Synchronized activity pattern
    patterns =
      if length(strong_correlations) > 0 do
        sync_pattern = %{
          pattern_type: :synchronized_activity,
          description: "Strong temporal correlation between systems",
          system_pairs: Enum.map(strong_correlations, & &1.system_pair),
          strength: calculate_average_correlation_strength(strong_correlations),
          confidence: temporal_correlations.confidence
        }

        [sync_pattern | patterns]
      else
        patterns
      end

    # Lag-based patterns (one system leads another)
    lag_patterns = identify_lag_based_patterns(strong_correlations)
    patterns ++ lag_patterns
  end

  defp identify_lag_based_patterns(correlations) do
    # Identify patterns where one system leads activity in another
    correlations
    |> Enum.filter(fn corr ->
      best_lag_info = corr.lag_analysis.best_lag
      lag = elem(best_lag_info, 0)
      correlation_at_lag = elem(best_lag_info, 1)

      lag != 0 and abs(correlation_at_lag) > 0.5
    end)
    |> Enum.map(fn corr ->
      {lag, correlation_strength} = corr.lag_analysis.best_lag

      {leader_system, follower_system} =
        if lag > 0 do
          {elem(corr.system_pair, 1), elem(corr.system_pair, 0)}
        else
          {elem(corr.system_pair, 0), elem(corr.system_pair, 1)}
        end

      %{
        pattern_type: :sequential_activity,
        description: "One system leads activity in another",
        leader_system: leader_system,
        follower_system: follower_system,
        # Convert bucket lag to minutes
        lag_minutes: abs(lag) * 15,
        strength: abs(correlation_strength),
        pattern_significance: :high
      }
    end)
  end

  defp identify_coordinated_movement_patterns(pilot_movements) do
    # Identify patterns in pilot movements that suggest coordination
    multi_system_pilots = Enum.filter(pilot_movements, &(&1.systems_visited > 1))

    if length(multi_system_pilots) > 1 do
      # Look for pilots following similar routes
      route_patterns = identify_common_routes(multi_system_pilots)

      # Look for synchronized timing
      timing_patterns = identify_synchronized_movements(multi_system_pilots)

      route_patterns ++ timing_patterns
    else
      []
    end
  end

  defp identify_common_routes(pilot_movements) do
    # Identify common movement routes
    route_signatures =
      pilot_movements
      |> Enum.map(fn movement ->
        {movement.pilot_id, movement.system_sequence}
      end)
      |> Enum.group_by(fn {_pilot_id, route} -> route end)

    common_routes =
      route_signatures
      |> Enum.filter(fn {_route, pilots} -> length(pilots) > 1 end)
      |> Enum.map(fn {route, pilots} ->
        %{
          pattern_type: :common_movement_route,
          description: "Multiple pilots following same route",
          route_sequence: route,
          pilot_count: length(pilots),
          pilots: Enum.map(pilots, fn {pilot_id, _route} -> pilot_id end),
          coordination_likelihood: :moderate
        }
      end)

    common_routes
  end

  defp identify_synchronized_movements(pilot_movements) do
    # Identify pilots moving at similar times
    # Group movements by time windows
    synchronized_groups =
      pilot_movements
      |> Enum.group_by(fn movement ->
        # Group by hour to find synchronized movements
        if movement.movement_timeline != [] do
          first_movement = List.first(movement.movement_timeline)
          first_movement.entry_time.hour
        else
          -1
        end
      end)
      |> Enum.filter(fn {hour, movements} -> hour != -1 and length(movements) > 1 end)
      |> Enum.map(fn {hour, movements} ->
        %{
          pattern_type: :synchronized_movement,
          description: "Multiple pilots moving during same time window",
          time_window: hour,
          pilot_count: length(movements),
          pilots: Enum.map(movements, & &1.pilot_id),
          coordination_likelihood: :high
        }
      end)

    synchronized_groups
  end

  defp identify_corp_coordination_patterns(corp_activities) do
    # Identify coordination patterns between corporations
    multi_system_corps =
      corp_activities.corp_analyses
      |> Enum.filter(&(&1.systems_active > 1))

    if length(multi_system_corps) > 1 do
      # Look for corporations active in same systems
      system_overlap_patterns = identify_corp_system_overlaps(multi_system_corps)

      # Look for temporal coordination between corporations
      temporal_coordination_patterns = identify_corp_temporal_coordination(multi_system_corps)

      system_overlap_patterns ++ temporal_coordination_patterns
    else
      []
    end
  end

  defp identify_corp_system_overlaps(corp_activities) do
    # Identify corporations active in the same systems
    corp_activities
    |> combinations(2)
    |> Enum.map(fn [corp_a, corp_b] ->
      systems_a = Map.keys(corp_a.territorial_behavior.system_distribution)
      systems_b = Map.keys(corp_b.territorial_behavior.system_distribution)

      common_systems =
        MapSet.intersection(MapSet.new(systems_a), MapSet.new(systems_b)) |> MapSet.to_list()

      if length(common_systems) > 0 do
        %{
          pattern_type: :corp_system_overlap,
          description: "Corporations active in same systems",
          corp_pair: {corp_a.corp_id, corp_b.corp_id},
          common_systems: common_systems,
          overlap_significance:
            classify_overlap_significance(common_systems, systems_a, systems_b),
          potential_relationship: :competitive_or_allied
        }
      else
        nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp classify_overlap_significance(common_systems, systems_a, systems_b) do
    overlap_ratio_a = length(common_systems) / length(systems_a)
    overlap_ratio_b = length(common_systems) / length(systems_b)
    max_overlap = max(overlap_ratio_a, overlap_ratio_b)

    cond do
      max_overlap > 0.8 -> :very_high
      max_overlap > 0.6 -> :high
      max_overlap > 0.3 -> :moderate
      true -> :low
    end
  end

  defp identify_corp_temporal_coordination(corp_activities) do
    # Identify temporal coordination between corporations
    corp_activities
    |> combinations(2)
    |> Enum.map(fn [corp_a, corp_b] ->
      temporal_overlap = analyze_corp_temporal_overlap(corp_a, corp_b)

      if temporal_overlap.coordination_likelihood != :none do
        %{
          pattern_type: :corp_temporal_coordination,
          description: "Corporations showing temporal coordination",
          corp_pair: {corp_a.corp_id, corp_b.corp_id},
          coordination_type: temporal_overlap.coordination_type,
          coordination_likelihood: temporal_overlap.coordination_likelihood,
          temporal_details: temporal_overlap
        }
      else
        nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp analyze_corp_temporal_overlap(corp_a, corp_b) do
    # Analyze temporal overlap between two corporations
    time_a = corp_a.temporal_behavior
    time_b = corp_b.temporal_behavior

    cond do
      overlapping_timeframes(time_a, time_b) ->
        %{
          coordination_type: :overlapping_operations,
          coordination_likelihood: :high,
          overlap_hours: calculate_temporal_overlap_hours(time_a, time_b)
        }

      sequential_timeframes(time_a, time_b) ->
        %{
          coordination_type: :sequential_operations,
          coordination_likelihood: :moderate,
          sequence_gap_hours: calculate_temporal_gap_hours(time_a, time_b)
        }

      true ->
        %{coordination_likelihood: :none}
    end
  end

  defp overlapping_timeframes(time_a, time_b) do
    # Check if two timeframes overlap
    time_a[:first_seen] != nil and time_a[:last_seen] != nil and
      time_b[:first_seen] != nil and time_b[:last_seen] != nil and
      DateTime.compare(time_a[:first_seen], time_b[:last_seen]) in [:lt, :eq] and
      DateTime.compare(time_a[:last_seen], time_b[:first_seen]) in [:gt, :eq]
  end

  defp sequential_timeframes(time_a, time_b) do
    # Check if timeframes are sequential (within 6 hours)
    if time_a[:last_seen] != nil and time_b[:first_seen] != nil do
      gap_hours = DateTime.diff(time_b[:first_seen], time_a[:last_seen], :hour)
      gap_hours >= 0 and gap_hours <= 6
    else
      false
    end
  end

  defp calculate_temporal_overlap_hours(time_a, time_b) do
    # Calculate hours of temporal overlap
    overlap_start = max_datetime(time_a[:first_seen], time_b[:first_seen])
    overlap_end = min_datetime(time_a[:last_seen], time_b[:last_seen])

    if DateTime.compare(overlap_start, overlap_end) == :lt do
      DateTime.diff(overlap_end, overlap_start, :hour)
    else
      0
    end
  end

  defp calculate_temporal_gap_hours(time_a, time_b) do
    # Calculate gap between sequential timeframes
    if time_a[:last_seen] != nil and time_b[:first_seen] != nil do
      DateTime.diff(time_b[:first_seen], time_a[:last_seen], :hour)
    else
      0
    end
  end

  defp max_datetime(dt1, dt2) do
    case DateTime.compare(dt1, dt2) do
      :gt -> dt1
      _ -> dt2
    end
  end

  defp min_datetime(dt1, dt2) do
    case DateTime.compare(dt1, dt2) do
      :lt -> dt1
      _ -> dt2
    end
  end

  defp identify_combined_tactical_patterns(
         temporal_correlations,
         pilot_movements,
         corp_activities
       ) do
    # Identify complex patterns combining temporal, movement, and corp data
    patterns = []

    # Pattern: Coordinated multi-corp operation
    if length(pilot_movements) > 2 and length(corp_activities.corp_analyses) > 1 do
      coordinated_op_pattern =
        detect_coordinated_operation(temporal_correlations, pilot_movements, corp_activities)

      _patterns =
        if coordinated_op_pattern, do: [coordinated_op_pattern | patterns], else: patterns
    end

    # Pattern: Tactical reconnaissance sweep
    recon_pattern = detect_reconnaissance_pattern(pilot_movements, temporal_correlations)
    patterns = if recon_pattern, do: [recon_pattern | patterns], else: patterns

    patterns
  end

  defp detect_coordinated_operation(temporal_correlations, pilot_movements, corp_activities) do
    # Detect coordinated multi-corporation operation
    strong_correlations =
      temporal_correlations.correlations
      |> Enum.filter(&(&1.significance in [:significant, :very_significant]))

    multi_system_pilots = Enum.filter(pilot_movements, &(&1.systems_visited > 1))
    multi_system_corps = Enum.filter(corp_activities.corp_analyses, &(&1.systems_active > 1))

    if length(strong_correlations) > 0 and length(multi_system_pilots) > 2 and
         length(multi_system_corps) > 1 do
      %{
        pattern_type: :coordinated_multi_corp_operation,
        description: "Large-scale coordinated operation across multiple systems",
        participating_corps: length(multi_system_corps),
        mobile_pilots: length(multi_system_pilots),
        correlated_systems: length(strong_correlations),
        operation_scale: classify_operation_scale(multi_system_pilots, multi_system_corps),
        tactical_significance: :very_high
      }
    else
      nil
    end
  end

  defp detect_reconnaissance_pattern(pilot_movements, temporal_correlations) do
    # Detect reconnaissance sweep patterns
    rapid_movers =
      pilot_movements
      |> Enum.filter(fn movement ->
        # Moving to new system within 1 hour
        movement.movement_pattern in [:limited_roaming, :extensive_roaming] and
          movement.movement_velocity < 3600
      end)

    if length(rapid_movers) > 0 and temporal_correlations.confidence > 0.6 do
      %{
        pattern_type: :reconnaissance_sweep,
        description: "Rapid pilot movements suggesting reconnaissance activity",
        recon_pilots: length(rapid_movers),
        average_systems_per_pilot: calculate_average_systems_visited(rapid_movers),
        coordination_confidence: temporal_correlations.confidence,
        tactical_significance: :high
      }
    else
      nil
    end
  end

  defp classify_operation_scale(pilot_movements, corp_activities) do
    total_pilots = length(pilot_movements)
    total_corps = length(corp_activities)

    cond do
      total_pilots > 10 and total_corps > 3 -> :major_operation
      total_pilots > 5 and total_corps > 2 -> :significant_operation
      total_pilots > 2 or total_corps > 1 -> :minor_operation
      true -> :individual_activity
    end
  end

  defp calculate_average_systems_visited(pilot_movements) do
    if length(pilot_movements) > 0 do
      total_systems = Enum.sum(Enum.map(pilot_movements, & &1.systems_visited))
      Float.round(total_systems / length(pilot_movements), 1)
    else
      0.0
    end
  end

  defp calculate_average_correlation_strength(correlations) do
    if length(correlations) > 0 do
      total_strength =
        correlations
        |> Enum.map(&abs(&1.correlation_coefficient))
        |> Enum.sum()

      Float.round(total_strength / length(correlations), 3)
    else
      0.0
    end
  end

  defp assess_strategic_implications(correlation_patterns, system_ids) do
    # Assess strategic implications of discovered patterns
    Logger.info("Assessing strategic implications for #{length(system_ids)} systems")

    implications = []

    # Implication 1: Coordinated threat assessment
    coordinated_threats = assess_coordinated_threats(correlation_patterns)
    implications = implications ++ coordinated_threats

    # Implication 2: Strategic opportunity identification
    strategic_opportunities = identify_strategic_opportunities_from_patterns(correlation_patterns)
    implications = implications ++ strategic_opportunities

    # Implication 3: Intelligence value assessment
    intelligence_insights = assess_intelligence_value(correlation_patterns, system_ids)
    implications = implications ++ intelligence_insights

    {:ok, implications}
  end

  defp assess_coordinated_threats(patterns) do
    # Assess threat implications from correlation patterns
    threat_implications = []

    # Check for coordinated operations
    coordinated_ops =
      Enum.filter(patterns, &(&1.pattern_type == :coordinated_multi_corp_operation))

    if length(coordinated_ops) > 0 do
      _threat_implications = [
        %{
          implication_type: :coordinated_threat,
          severity: :high,
          description: "Multiple corporations coordinating operations",
          affected_systems: extract_systems_from_patterns(coordinated_ops),
          recommended_actions: [
            "Increase security posture",
            "Monitor coordination patterns",
            "Prepare defensive measures"
          ]
        }
        | threat_implications
      ]
    end

    # Check for reconnaissance activity
    recon_patterns = Enum.filter(patterns, &(&1.pattern_type == :reconnaissance_sweep))

    if length(recon_patterns) > 0 do
      _threat_implications = [
        %{
          implication_type: :reconnaissance_threat,
          severity: :medium,
          description: "Active reconnaissance detected",
          intelligence_risk: :high,
          recommended_actions: [
            "Implement OPSEC measures",
            "Counter-surveillance",
            "Information security"
          ]
        }
        | threat_implications
      ]
    end

    threat_implications
  end

  defp identify_strategic_opportunities_from_patterns(patterns) do
    # Identify strategic opportunities from patterns
    opportunities = []

    # Opportunity 1: Predictable enemy movement patterns
    movement_patterns =
      Enum.filter(
        patterns,
        &(&1.pattern_type in [:common_movement_route, :synchronized_movement])
      )

    if length(movement_patterns) > 0 do
      _opportunities = [
        %{
          opportunity_type: :predictable_movements,
          potential_value: :high,
          description: "Enemy movements show predictable patterns",
          exploitation_methods: [
            "Ambush positioning",
            "Route interdiction",
            "Predictive deployment"
          ],
          success_probability: :high
        }
        | opportunities
      ]
    end

    # Opportunity 2: Temporal coordination windows
    temporal_patterns = Enum.filter(patterns, &(&1.pattern_type == :synchronized_activity))

    if length(temporal_patterns) > 0 do
      _opportunities = [
        %{
          opportunity_type: :temporal_windows,
          potential_value: :medium,
          description: "Synchronized activity creates predictable timing",
          exploitation_methods: [
            "Timing-based operations",
            "Counter-timing strategies",
            "Window exploitation"
          ],
          success_probability: :medium
        }
        | opportunities
      ]
    end

    opportunities
  end

  defp assess_intelligence_value(patterns, _system_ids) do
    # Assess intelligence value of discovered patterns
    intelligence_insights = []

    # Insight 1: Network topology understanding
    if length(patterns) > 3 do
      _intelligence_insights = [
        %{
          insight_type: :network_topology,
          intelligence_value: :high,
          description: "Comprehensive understanding of enemy network topology",
          applications: ["Strategic planning", "Force deployment", "Intelligence targeting"],
          confidence_level: :high
        }
        | intelligence_insights
      ]
    end

    # Insight 2: Operational patterns
    operational_patterns =
      Enum.filter(
        patterns,
        &(&1.pattern_type in [:coordinated_multi_corp_operation, :corp_temporal_coordination])
      )

    if length(operational_patterns) > 0 do
      _intelligence_insights = [
        %{
          insight_type: :operational_patterns,
          intelligence_value: :very_high,
          description: "Enemy operational patterns and doctrine identified",
          applications: ["Tactical planning", "Threat assessment", "Strategic intelligence"],
          pattern_count: length(operational_patterns),
          confidence_level: :high
        }
        | intelligence_insights
      ]
    end

    intelligence_insights
  end

  defp extract_systems_from_patterns(patterns) do
    # Extract system IDs mentioned in patterns
    patterns
    |> Enum.flat_map(fn pattern ->
      case pattern do
        %{system_pairs: pairs} -> Enum.flat_map(pairs, fn {a, b} -> [a, b] end)
        %{common_systems: systems} -> systems
        _ -> []
      end
    end)
    |> Enum.uniq()
  end

  defp compile_correlation_analysis(system_ids, patterns, implications) do
    # Compile comprehensive correlation analysis
    analysis_summary = %{
      systems_analyzed: length(system_ids),
      patterns_identified: length(patterns),
      strategic_implications: length(implications),
      analysis_confidence: calculate_overall_analysis_confidence(patterns, implications)
    }

    pattern_categories = categorize_patterns(patterns)
    threat_assessment = assess_overall_threat_level(implications)

    {:ok,
     %{
       system_ids: system_ids,
       correlation_patterns: patterns,
       pattern_categories: pattern_categories,
       strategic_implications: implications,
       threat_assessment: threat_assessment,
       analysis_summary: analysis_summary,
       analysis_timestamp: DateTime.utc_now()
     }}
  end

  defp calculate_overall_analysis_confidence(patterns, implications) do
    # Calculate confidence in overall analysis
    confidence_factors = []

    # Factor 1: Number of patterns found
    pattern_confidence = min(1.0, length(patterns) / 5.0)
    confidence_factors = [pattern_confidence | confidence_factors]

    # Factor 2: Diversity of pattern types
    unique_pattern_types =
      patterns
      |> Enum.map(& &1.pattern_type)
      |> Enum.uniq()
      |> length()

    diversity_confidence = min(1.0, unique_pattern_types / 6.0)
    confidence_factors = [diversity_confidence | confidence_factors]

    # Factor 3: Strategic implications generated
    implications_confidence = min(1.0, length(implications) / 3.0)
    confidence_factors = [implications_confidence | confidence_factors]

    if length(confidence_factors) > 0 do
      Enum.sum(confidence_factors) / length(confidence_factors)
    else
      0.0
    end
  end

  defp categorize_patterns(patterns) do
    # Categorize patterns by type for summary
    patterns
    |> Enum.group_by(& &1.pattern_type)
    |> Enum.map(fn {pattern_type, pattern_list} ->
      %{
        category: pattern_type,
        count: length(pattern_list),
        significance: assess_category_significance(pattern_type, pattern_list)
      }
    end)
  end

  defp assess_category_significance(pattern_type, _pattern_list) do
    # Assess significance of each pattern category
    case pattern_type do
      :coordinated_multi_corp_operation -> :very_high
      :reconnaissance_sweep -> :high
      :synchronized_activity -> :high
      :sequential_activity -> :medium
      :corp_temporal_coordination -> :medium
      _ -> :low
    end
  end

  defp assess_overall_threat_level(implications) do
    # Assess overall threat level from implications
    threat_implications =
      Enum.filter(
        implications,
        &(&1[:implication_type] in [:coordinated_threat, :reconnaissance_threat])
      )

    if length(threat_implications) > 0 do
      max_severity =
        threat_implications
        |> Enum.map(& &1[:severity])
        |> Enum.max_by(fn severity ->
          case severity do
            :very_high -> 4
            :high -> 3
            :medium -> 2
            :low -> 1
            _ -> 0
          end
        end)

      %{
        overall_threat_level: max_severity,
        threat_count: length(threat_implications),
        primary_threats: Enum.take(threat_implications, 3)
      }
    else
      %{
        overall_threat_level: :minimal,
        threat_count: 0,
        primary_threats: []
      }
    end
  end

  defp collect_raw_intelligence(analysis_area, sources) do
    {:ok, %{data: [], sources: sources, area: analysis_area}}
  end

  defp process_intelligence_sources(_raw_intelligence) do
    {:ok, %{processed: [], confidence: 0.0}}
  end

  defp maybe_apply_temporal_correlation(intelligence, _apply_correlation) do
    {:ok, intelligence}
  end

  defp maybe_apply_priority_weighting(intelligence, _apply_weighting) do
    {:ok, intelligence}
  end

  defp perform_intelligence_fusion(intelligence, _confidence_threshold) do
    {:ok, %{fused: intelligence, confidence: 0.0}}
  end

  defp assess_intelligence_confidence(_fused_intelligence) do
    {:ok, %{confidence: 0.0, factors: []}}
  end

  defp compile_intelligence_report(analysis_area, intelligence, confidence) do
    {:ok, %{area: analysis_area, intelligence: intelligence, confidence: confidence}}
  end

  defp fetch_strategic_data(analysis_scope, analysis_window) do
    {:ok, %{scope: analysis_scope, window: analysis_window, data: []}}
  end

  defp analyze_strategic_patterns_in_data(_historical_data) do
    {:ok, %{patterns: [], confidence: 0.0}}
  end

  defp perform_threat_assessment(_historical_data, threat_level) do
    {:ok, %{threat_level: threat_level, assessment: [], confidence: 0.0}}
  end

  defp identify_strategic_opportunities(_pattern_analysis) do
    {:ok, []}
  end

  defp maybe_generate_strategic_predictions(_pattern_analysis, _include_predictions) do
    {:ok, []}
  end

  defp generate_strategic_recommendations(
         _pattern_analysis,
         _threat_analysis,
         _opportunity_analysis,
         _predictions
       ) do
    {:ok, []}
  end

  defp compile_strategic_analysis(
         analysis_scope,
         pattern_analysis,
         threat_analysis,
         opportunity_analysis,
         predictions,
         recommendations
       ) do
    {:ok,
     %{
       scope: analysis_scope,
       patterns: pattern_analysis,
       threats: threat_analysis,
       opportunities: opportunity_analysis,
       predictions: predictions,
       recommendations: recommendations
     }}
  end

  defp establish_intelligence_baseline(monitored_systems) do
    {:ok, %{baseline: [], systems: monitored_systems}}
  end

  defp setup_intelligence_monitoring(systems, baseline, thresholds) do
    {:ok, %{monitoring: true, systems: systems, baseline: baseline, thresholds: thresholds}}
  end

  defp maybe_setup_predictive_monitoring(setup, _include_predictions) do
    {:ok, setup}
  end

  defp start_intelligence_stream(setup, prediction_system, frequency) do
    {:ok,
     %{stream_active: true, setup: setup, predictions: prediction_system, frequency: frequency}}
  end

  # Helper functions for cross-system correlation algorithms

  defp combinations(_list, 0), do: [[]]
  defp combinations([], _), do: []

  defp combinations([h | t], n) do
    Enum.map(combinations(t, n - 1), &[h | &1]) ++ combinations(t, n)
  end

  defp calculate_killmail_intensity(killmail) do
    # Calculate intensity based on participants and ship values
    base_intensity = 1.0

    # Factor in number of attackers
    attacker_count =
      case killmail.raw_data do
        %{"attackers" => attackers} when is_list(attackers) -> length(attackers)
        _ -> 1
      end

    intensity_from_attackers = min(attacker_count * 0.1, 2.0)

    # Factor in ship value (simplified)
    ship_value_factor =
      if is_high_value_target(killmail) do
        2.0
      else
        1.0
      end

    base_intensity + intensity_from_attackers + ship_value_factor
  end

  defp pilot_participated_in_killmail?(killmail, pilot_id) do
    # Check if pilot participated in this killmail
    participants = extract_all_participants_from_killmail(killmail)
    pilot_id in participants
  end

  defp corp_participated_in_killmail?(killmail, corp_id) do
    # Check if corporation participated in this killmail
    corp_ids = extract_corp_ids_from_killmail(killmail)
    corp_id in corp_ids
  end

  defp get_first_activity_time(killmails) do
    case killmails do
      [_first | _] ->
        killmails
        |> Enum.map(& &1.killmail_time)
        |> Enum.min()

      [] ->
        nil
    end
  end

  defp get_last_activity_time(killmails) do
    case killmails do
      [_ | _] ->
        killmails
        |> Enum.map(& &1.killmail_time)
        |> Enum.max()

      [] ->
        nil
    end
  end

  defp analyze_pilot_activity_pattern(killmails) do
    # Analyze activity pattern for a pilot
    if length(killmails) > 1 do
      time_gaps = calculate_time_gaps_between_activities(killmails)

      %{
        activity_frequency: classify_activity_frequency(length(killmails), time_gaps),
        consistency: calculate_activity_consistency(time_gaps),
        peak_periods: identify_peak_activity_periods(killmails)
      }
    else
      %{activity_frequency: :low, consistency: 0.0, peak_periods: []}
    end
  end

  defp calculate_time_gaps_between_activities(killmails) do
    sorted_killmails = Enum.sort_by(killmails, & &1.killmail_time)

    sorted_killmails
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, curr] ->
      DateTime.diff(curr.killmail_time, prev.killmail_time, :hour)
    end)
  end

  defp classify_activity_frequency(_killmail_count, time_gaps) do
    if length(time_gaps) > 0 do
      avg_gap_hours = Enum.sum(time_gaps) / length(time_gaps)

      cond do
        avg_gap_hours < 2 -> :very_high
        avg_gap_hours < 6 -> :high
        avg_gap_hours < 24 -> :moderate
        # 1 week
        avg_gap_hours < 168 -> :low
        true -> :very_low
      end
    else
      :single_event
    end
  end

  defp calculate_activity_consistency(time_gaps) do
    if length(time_gaps) > 1 do
      mean_gap = Enum.sum(time_gaps) / length(time_gaps)

      variance =
        time_gaps
        |> Enum.map(fn gap -> :math.pow(gap - mean_gap, 2) end)
        |> Enum.sum()
        |> Kernel./(length(time_gaps))

      std_dev = :math.sqrt(variance)

      # Consistency is inverse of coefficient of variation
      if mean_gap > 0 do
        1.0 - min(1.0, std_dev / mean_gap)
      else
        0.0
      end
    else
      1.0
    end
  end

  defp identify_peak_activity_periods(killmails) do
    # Group by hour and identify peak periods
    hourly_activity =
      killmails
      |> Enum.group_by(fn km -> km.killmail_time.hour end)
      |> Enum.map(fn {hour, kms} -> {hour, length(kms)} end)
      |> Enum.sort_by(fn {_hour, count} -> count end, :desc)

    # Take top 3 hours as peaks
    Enum.take(hourly_activity, 3)
  end

  defp extract_pilot_ship_usage(killmails, pilot_id) do
    # Extract ship types used by specific pilot
    pilot_ships =
      killmails
      |> Enum.filter(&pilot_participated_in_killmail?(&1, pilot_id))
      |> Enum.flat_map(&extract_pilot_ships_from_killmail(&1, pilot_id))
      |> Enum.frequencies()

    %{
      ship_types_used: pilot_ships,
      ship_diversity: length(Map.keys(pilot_ships)),
      preferred_ship: find_preferred_ship(pilot_ships)
    }
  end

  defp extract_pilot_ships_from_killmail(killmail, pilot_id) do
    # Extract ship types for specific pilot from killmail
    ships = []

    # Check if pilot was victim
    ships =
      if killmail.victim_character_id == pilot_id do
        [killmail.victim_ship_type_id | ships]
      else
        ships
      end

    # Check if pilot was attacker
    attacker_ships =
      case killmail.raw_data do
        %{"attackers" => attackers} when is_list(attackers) ->
          attackers
          |> Enum.filter(fn attacker ->
            case attacker["character_id"] do
              ^pilot_id ->
                true

              pilot_id_str when is_binary(pilot_id_str) ->
                String.to_integer(pilot_id_str) == pilot_id

              _ ->
                false
            end
          end)
          |> Enum.map(fn attacker ->
            case attacker["ship_type_id"] do
              id when is_integer(id) -> id
              id when is_binary(id) -> String.to_integer(id)
              _ -> nil
            end
          end)
          |> Enum.filter(&(&1 != nil))

        _ ->
          []
      end

    ships ++ attacker_ships
  end

  defp find_preferred_ship(ship_usage) do
    case Enum.max_by(ship_usage, fn {_ship, count} -> count end, fn -> nil end) do
      {ship_type_id, _count} -> ship_type_id
      nil -> nil
    end
  end

  defp calculate_pilot_activity_distribution(pilot_data) do
    # Calculate distribution metrics for pilot activity
    activity_counts = Enum.map(pilot_data, & &1.activity_count)

    if length(activity_counts) > 0 do
      mean_activity = Enum.sum(activity_counts) / length(activity_counts)
      max_activity = Enum.max(activity_counts)
      min_activity = Enum.min(activity_counts)

      %{
        mean_activity: mean_activity,
        max_activity: max_activity,
        min_activity: min_activity,
        activity_range: max_activity - min_activity,
        high_activity_pilots:
          Enum.count(activity_counts, fn count -> count > mean_activity * 1.5 end)
      }
    else
      %{
        mean_activity: 0,
        max_activity: 0,
        min_activity: 0,
        activity_range: 0,
        high_activity_pilots: 0
      }
    end
  end

  defp analyze_corp_engagement_style(killmails) do
    # Analyze corporation's preferred engagement style
    if length(killmails) > 0 do
      solo_engagements = count_solo_engagements(killmails)
      fleet_engagements = count_fleet_engagements(killmails)

      solo_ratio = solo_engagements / length(killmails)
      fleet_ratio = fleet_engagements / length(killmails)

      cond do
        solo_ratio > 0.7 -> :solo_focused
        fleet_ratio > 0.7 -> :fleet_focused
        true -> :mixed_engagement
      end
    else
      :unknown
    end
  end

  defp count_solo_engagements(killmails) do
    Enum.count(killmails, fn km ->
      case km.raw_data do
        %{"attackers" => attackers} when is_list(attackers) -> length(attackers) <= 2
        _ -> true
      end
    end)
  end

  defp count_fleet_engagements(killmails) do
    Enum.count(killmails, fn km ->
      case km.raw_data do
        %{"attackers" => attackers} when is_list(attackers) -> length(attackers) > 5
        _ -> false
      end
    end)
  end

  defp analyze_corp_territorial_focus(killmails) do
    # Analyze corporation's territorial focus
    systems =
      killmails
      |> Enum.map(& &1.solar_system_id)
      |> Enum.frequencies()

    if map_size(systems) > 0 do
      max_system_activity = systems |> Map.values() |> Enum.max()
      total_activity = systems |> Map.values() |> Enum.sum()

      concentration = max_system_activity / total_activity

      cond do
        concentration > 0.8 -> :highly_territorial
        concentration > 0.5 -> :moderately_territorial
        true -> :nomadic
      end
    else
      :unknown
    end
  end

  defp extract_alliance_patterns(_corp_data) do
    # Extract alliance patterns from corporation data
    # This would be enhanced with actual alliance data
    %{
      potential_alliances: [],
      alliance_indicators: [],
      coordination_evidence: :insufficient_data
    }
  end

  defp extract_ship_types_from_killmail(killmail) do
    # Extract all ship types involved in killmail
    ships = [killmail.victim_ship_type_id]

    attacker_ships =
      case killmail.raw_data do
        %{"attackers" => attackers} when is_list(attackers) ->
          attackers
          |> Enum.map(fn attacker ->
            case attacker["ship_type_id"] do
              id when is_integer(id) -> id
              id when is_binary(id) -> String.to_integer(id)
              _ -> nil
            end
          end)
          |> Enum.filter(&(&1 != nil))

        _ ->
          []
      end

    ships ++ attacker_ships
  end

  defp analyze_tactical_ship_composition(ship_usage) do
    # Analyze tactical composition of ship types
    total_ships = ship_usage |> Enum.map(fn {_ship, count} -> count end) |> Enum.sum()

    if total_ships > 0 do
      # Categorize ships (simplified categories)
      categories = %{
        frigates: count_ships_in_range(ship_usage, 585..593),
        destroyers: count_ships_in_range(ship_usage, 420..430),
        cruisers: count_ships_in_range(ship_usage, 358..380),
        battleships: count_ships_in_range(ship_usage, 27..30),
        capitals: count_ships_in_range(ship_usage, 19720..19740)
      }

      %{
        composition: categories,
        diversity_index: calculate_ship_diversity_index(ship_usage),
        tactical_focus: determine_tactical_focus(categories, total_ships)
      }
    else
      %{composition: %{}, diversity_index: 0.0, tactical_focus: :unknown}
    end
  end

  defp count_ships_in_range(ship_usage, range) do
    ship_usage
    |> Enum.filter(fn {ship_type_id, _count} -> ship_type_id in range end)
    |> Enum.map(fn {_ship, count} -> count end)
    |> Enum.sum()
  end

  defp calculate_ship_diversity_index(ship_usage) do
    # Shannon diversity index for ship types
    total_count = ship_usage |> Enum.map(fn {_ship, count} -> count end) |> Enum.sum()

    if total_count > 0 do
      ship_usage
      |> Enum.map(fn {_ship, count} ->
        proportion = count / total_count
        if proportion > 0, do: -proportion * :math.log2(proportion), else: 0
      end)
      |> Enum.sum()
    else
      0.0
    end
  end

  defp determine_tactical_focus(categories, total_ships) do
    max_category =
      categories
      |> Enum.max_by(fn {_category, count} -> count end)

    case max_category do
      {category, count} when count / total_ships > 0.6 -> category
      _ -> :mixed_doctrine
    end
  end
end
