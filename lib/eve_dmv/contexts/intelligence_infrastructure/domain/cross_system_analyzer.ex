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

  This module serves as the main API interface and delegates to specialized submodules:
  - WormholeChainAnalyzer: Wormhole chain mapping and analysis
  - ActivityCorrelator: Cross-system activity correlation
  - IntelligenceFusion: Multi-source intelligence fusion
  - StrategicPatternAnalyzer: Strategic pattern analysis
  - MonitoringEngine: Real-time monitoring and alerting
  """
  """

  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystemAnalyzer.ActivityCorrelator
  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystemAnalyzer.MonitoringEngine

  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystemAnalyzer.WormholeChainAnalyzer

  # Use new modular intelligence system
  alias EveDmv.Shared.Intelligence.Facade, as: IntelligenceFusion

  # Use new modular strategic analysis system
  alias EveDmv.Shared.Strategic.Facade, as: StrategicPatternAnalyzer

  require Logger

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
    time_window_hours = Keyword.get(options, :time_window_hours, 24)

    Logger.info("Analyzing wormhole chain from system #{starting_system_id}")

    with {:ok, chain_map} <-
           WormholeChainAnalyzer.map_wormhole_chain(starting_system_id, max_depth),
         {:ok, connection_data} <-
           WormholeChainAnalyzer.analyze_wormhole_connections(chain_map, time_window_hours) do
      Logger.info("Wormhole chain analysis completed for system #{starting_system_id}")

      {:ok,
       %{
         starting_system_id: starting_system_id,
         chain_map: chain_map,
         connection_data: connection_data,
         analysis_timestamp: DateTime.utc_now()
       }}
    else
      error -> error
    end
  end

  @doc """
  Correlates activity patterns across multiple systems.

  Analyzes temporal correlations, movement patterns, and cross-system behaviors
  to identify coordinated activities and strategic patterns.

  ## Parameters
  - system_ids: List of system IDs to analyze for correlations
  - options: Analysis options
    - :time_window_hours - Hours of data to analyze (default: 24)
    - :correlation_threshold - Minimum correlation strength (default: 0.7)
    - :include_movement_tracking - Track pilot movements (default: true)
    - :include_corp_analysis - Analyze corporation behaviors (default: true)

  ## Returns
  {:ok, cross_system_activity_analysis} with correlation patterns and insights
  """
  def correlate_cross_system_activity(system_ids, options \\ []) do
    time_window_hours = Keyword.get(options, :time_window_hours, 24)
    include_movement = Keyword.get(options, :include_movement_tracking, true)
    include_corp_analysis = Keyword.get(options, :include_corp_analysis, true)

    Logger.info("Correlating activity across #{Kernel.length(system_ids)} systems")

    with {:ok, system_activities} <-
           ActivityCorrelator.fetch_system_activities(system_ids, time_window_hours),
         {:ok, timeline} <- {:ok, ActivityCorrelator.build_activity_timeline(system_activities)},
         {:ok, correlations} <- {:ok, ActivityCorrelator.analyze_temporal_correlations(timeline)},
         {:ok, movement_analysis} <- maybe_track_movements(system_activities, include_movement),
         {:ok, corp_analysis} <- maybe_analyze_corps(system_activities, include_corp_analysis) do
      Logger.info("Cross-system activity correlation completed")

      {:ok,
       %{
         system_ids: system_ids,
         timeline: timeline,
         correlations: correlations,
         movement_analysis: movement_analysis,
         corp_analysis: corp_analysis,
         analysis_timestamp: DateTime.utc_now()
       }}
    else
      error -> error
    end
  end

  @doc """
  Fuses intelligence from multiple sources for comprehensive analysis.

  Combines killmail data, player reports, scanning data, market activity,
  and jump logs to create a comprehensive intelligence picture.

  ## Parameters
  - analysis_area: Area specification (systems, region, etc.)
  - options: Fusion options
    - :time_window_hours - Hours of data to collect (default: 24)
    - :sources - Intelligence sources to use (default: all available)
    - :confidence_threshold - Minimum confidence for fusion (default: 0.8)
    - :include_raw_data - Include raw data in output (default: false)

  ## Returns
  {:ok, intelligence_report} with fused intelligence analysis
  """
  def fuse_intelligence_sources(analysis_area, options \\ []) do
    _time_window_hours = Keyword.get(options, :time_window_hours, 24)
    confidence_threshold = Keyword.get(options, :confidence_threshold, 0.8)
    include_raw_data = Keyword.get(options, :include_raw_data, false)

    Logger.info("Fusing intelligence sources for area: #{inspect(analysis_area)}")

    with {:ok, raw_intelligence} <-
           IntelligenceFusion.collect_raw_intelligence(analysis_area, options),
         {:ok, processed_intelligence} <-
           {:ok, IntelligenceFusion.process_intelligence_sources(raw_intelligence)},
         {:ok, fused_intelligence} <-
           {:ok,
            IntelligenceFusion.perform_intelligence_fusion(processed_intelligence,
              confidence_threshold: confidence_threshold
            )},
         {:ok, confidence_assessment} <-
           {:ok, IntelligenceFusion.assess_intelligence_confidence(fused_intelligence)},
         {:ok, intelligence_report} <-
           {:ok,
            IntelligenceFusion.compile_intelligence_report(
              fused_intelligence,
              confidence_assessment,
              include_raw_data: include_raw_data
            )} do
      Logger.info(
        "Intelligence fusion completed with confidence: #{confidence_assessment.overall_confidence}"
      )

      {:ok, intelligence_report}
    else
      error -> error
    end
  end

  @doc """
  Analyzes strategic patterns for long-term intelligence assessment.

  Identifies territorial control patterns, resource competition, strategic trends,
  and opportunities across the specified scope and timeframe.

  ## Parameters
  - analysis_scope: Strategic analysis scope (systems, region, etc.)
  - options: Analysis options
    - :analysis_window_days - Days of data for strategic analysis (default: 14)
    - :include_territorial_analysis - Include territorial control analysis (default: true)
    - :include_resource_analysis - Include resource competition analysis (default: true)
    - :pattern_focus - Specific patterns to focus on (default: all)

  ## Returns
  {:ok, strategic_assessment} with comprehensive strategic analysis
  """
  def analyze_strategic_patterns(analysis_scope, options \\ []) do
    Logger.info("Analyzing strategic patterns for scope: #{inspect(analysis_scope)}")

    StrategicPatternAnalyzer.analyze_strategic_patterns(analysis_scope, options)
  end

  @doc """
  Sets up real-time cross-system intelligence monitoring.

  Establishes baseline intelligence patterns and starts continuous monitoring
  for anomalies, threats, and strategic developments.

  ## Parameters
  - monitored_systems: List of system IDs to monitor
  - options: Monitoring options
    - :monitoring_interval_minutes - How often to check for changes (default: 5)
    - :baseline_window_hours - Hours of data for baseline (default: 24)
    - :alert_thresholds - Custom alert thresholds (default: standard)
    - :enable_predictive_monitoring - Enable predictive analysis (default: true)

  ## Returns
  {:ok, monitoring_setup} with monitoring configuration and status
  """
  def monitor_cross_system_intelligence(monitored_systems, options \\ []) do
    baseline_window_hours = Keyword.get(options, :baseline_window_hours, 24)

    Logger.info(
      "Setting up intelligence monitoring for #{Kernel.length(monitored_systems)} systems"
    )

    with {:ok, baseline} <-
           MonitoringEngine.establish_intelligence_baseline(monitored_systems,
             baseline_window_hours: baseline_window_hours
           ),
         {:ok, monitoring_setup} <-
           MonitoringEngine.setup_intelligence_monitoring(monitored_systems, baseline, options),
         {:ok, stream_setup} <- MonitoringEngine.start_intelligence_stream(monitoring_setup) do
      Logger.info(
        "Intelligence monitoring established for #{Kernel.length(monitored_systems)} systems"
      )

      {:ok,
       %{
         monitoring_id: monitoring_setup.monitoring_id,
         monitored_systems: monitored_systems,
         baseline: baseline,
         monitoring_setup: monitoring_setup,
         stream_setup: stream_setup,
         status: :active,
         started_at: DateTime.utc_now()
       }}
    else
      error -> error
    end
  end

  @doc """
  Estimates traffic volume through a wormhole connection.
  """
  defdelegate estimate_traffic_volume(connection, time_window_hours), to: WormholeChainAnalyzer

  @doc """
  Estimates time until wormhole collapse based on mass usage.
  """
  defdelegate estimate_collapse_time(connection_data), to: WormholeChainAnalyzer

  @doc """
  Identifies activity bursts across systems.
  """
  defdelegate identify_activity_bursts(timeline_events), to: ActivityCorrelator

  @doc """
  Assesses intelligence value for strategic planning.
  """
  defdelegate assess_intelligence_value(intelligence_report, assessment_criteria \\ []),
    to: IntelligenceFusion

  @doc """
  Identifies strategic opportunities based on pattern analysis.
  """
  defdelegate identify_strategic_opportunities(
                pattern_analysis,
                territorial_analysis,
                resource_analysis
              ),
              to: StrategicPatternAnalyzer

  @doc """
  Generates strategic recommendations based on comprehensive analysis.
  """
  defdelegate generate_strategic_recommendations(
                pattern_analysis,
                territorial_analysis,
                resource_analysis,
                trend_analysis
              ),
              to: StrategicPatternAnalyzer

  # Private helper functions

  defp maybe_track_movements(system_activities, true) do
    {:ok, ActivityCorrelator.track_pilot_movements(system_activities)}
  end

  defp maybe_track_movements(_system_activities, false) do
    {:ok, nil}
  end

  defp maybe_analyze_corps(system_activities, true) do
    {:ok, ActivityCorrelator.analyze_corp_activities(system_activities)}
  end

  defp maybe_analyze_corps(_system_activities, false) do
    {:ok, nil}
  end
end
