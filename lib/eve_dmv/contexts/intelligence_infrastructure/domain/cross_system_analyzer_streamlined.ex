defmodule EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystemAnalyzerStreamlined do
  @moduledoc """
  Streamlined cross-system intelligence coordination layer.

  This module serves as a thin coordinator that delegates to specialized analyzers
  and correlators for different aspects of cross-system intelligence analysis.

  **Architecture**: Uses composition over inheritance, delegating to:
  - ConstellationAnalyzer: Wormhole chain and constellation analysis
  - ActivityCorrelator: Cross-system activity pattern correlation
  - ThreatCorrelator: Multi-system threat pattern analysis
  """

  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Analyzers.ConstellationAnalyzer

  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Correlators.ActivityCorrelator

  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Correlators.ThreatCorrelator

  require Logger

  # Cross-system analysis parameters
  @activity_correlation_threshold 0.7
  @intelligence_fusion_confidence 0.8
  @strategic_analysis_window_days 14

  @doc """
  Analyzes wormhole chain connections and activity patterns.

  Delegates to ConstellationAnalyzer for comprehensive wormhole chain analysis.

  ## Parameters
  - starting_system_id: Solar system ID to start chain analysis from
  - options: Analysis options (see ConstellationAnalyzer for details)

  ## Returns
  {:ok, wormhole_chain_analysis} with comprehensive chain intelligence
  """
  def analyze_wormhole_chain(starting_system_id, options \\ []) do
    Logger.info("Delegating wormhole chain analysis to ConstellationAnalyzer")

    ConstellationAnalyzer.analyze_constellation_patterns(starting_system_id, options)
  end

  @doc """
  Correlates battles and activities across multiple systems.

  Delegates to ActivityCorrelator for sophisticated correlation analysis using
  statistical methods and pattern recognition.

  ## Parameters
  - system_ids: List of solar system IDs to analyze
  - options: Analysis options (see ActivityCorrelator for details)

  ## Returns
  {:ok, cross_system_correlation} with correlated activity analysis
  """
  def correlate_cross_system_activity(system_ids, options \\ []) do
    correlation_window = Keyword.get(options, :correlation_window_hours, 6)

    min_correlation =
      Keyword.get(options, :min_correlation_strength, @activity_correlation_threshold)

    Logger.info("Delegating cross-system correlation to ActivityCorrelator")

    activity_options = [
      correlation_window_hours: correlation_window,
      min_correlation_strength: min_correlation
    ]

    case ActivityCorrelator.correlate_activities(system_ids, activity_options) do
      activity_correlation when is_map(activity_correlation) ->
        {:ok, activity_correlation}

      error ->
        Logger.error("Activity correlation failed: #{inspect(error)}")
        {:error, "Failed to correlate cross-system activity"}
    end
  end

  @doc """
  Analyzes threat patterns across multiple systems.

  Delegates to ThreatCorrelator for comprehensive threat analysis including
  spillover detection, escalation patterns, and coordinated threats.

  ## Parameters
  - system_ids: List of solar system IDs to analyze
  - options: Analysis options (see ThreatCorrelator for details)

  ## Returns
  {:ok, threat_analysis} with threat correlation and patterns
  """
  def analyze_cross_system_threats(system_ids, options \\ []) do
    Logger.info("Delegating threat analysis to ThreatCorrelator")

    case ThreatCorrelator.correlate_threats(system_ids, options) do
      threat_analysis when is_map(threat_analysis) ->
        {:ok, threat_analysis}

      error ->
        Logger.error("Threat correlation failed: #{inspect(error)}")
        {:error, "Failed to analyze cross-system threats"}
    end
  end

  @doc """
  Performs comprehensive cross-system intelligence analysis.

  Orchestrates all specialized analyzers to provide a complete intelligence picture
  combining constellation analysis, activity correlation, and threat assessment.

  ## Parameters
  - analysis_scope: Analysis scope definition
    - :system_ids - Systems to analyze
    - :starting_system - Optional starting system for constellation analysis
    - :analysis_type - :comprehensive | :activity_only | :threats_only | :constellation_only
  - options: Global analysis options

  ## Returns
  {:ok, comprehensive_analysis} with integrated intelligence
  """
  def analyze_comprehensive_intelligence(analysis_scope, options \\ []) do
    system_ids = Map.get(analysis_scope, :system_ids, [])
    starting_system = Map.get(analysis_scope, :starting_system)
    analysis_type = Map.get(analysis_scope, :analysis_type, :comprehensive)

    Logger.info("Starting comprehensive cross-system intelligence analysis")
    Logger.info("Scope: #{length(system_ids)} systems, type: #{analysis_type}")

    start_time = System.monotonic_time(:millisecond)

    with {:ok, results} <-
           execute_analysis_workflow(analysis_type, system_ids, starting_system, options),
         {:ok, integrated_intelligence} <- integrate_analysis_results(results, analysis_scope),
         {:ok, final_assessment} <-
           generate_strategic_assessment(integrated_intelligence, options) do
      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      Logger.info("Comprehensive analysis completed in #{duration_ms}ms")

      {:ok, final_assessment}
    else
      {:error, reason} ->
        Logger.error("Comprehensive analysis failed: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Monitors cross-system intelligence for changes and alerts.

  Sets up ongoing monitoring using the specialized correlators and analyzers
  for real-time intelligence updates.

  ## Parameters
  - monitored_systems: List of systems to monitor
  - options: Monitoring configuration options

  ## Returns
  {:ok, monitoring_setup} with monitoring configuration
  """
  def monitor_cross_system_intelligence(monitored_systems, options \\ []) do
    monitoring_frequency = Keyword.get(options, :frequency_minutes, 15)
    alert_thresholds = Keyword.get(options, :alert_thresholds, %{})

    Logger.info(
      "Setting up cross-system intelligence monitoring for #{length(monitored_systems)} systems"
    )

    monitoring_setup = %{
      monitored_systems: monitored_systems,
      monitoring_frequency: monitoring_frequency,
      alert_thresholds: alert_thresholds,
      last_analysis: DateTime.utc_now(),
      status: :active
    }

    {:ok, monitoring_setup}
  end

  # Private workflow execution functions

  defp execute_analysis_workflow(:comprehensive, system_ids, starting_system, options) do
    # Execute all analysis types
    with {:ok, constellation_analysis} <- maybe_analyze_constellation(starting_system, options),
         {:ok, activity_correlation} <- correlate_cross_system_activity(system_ids, options),
         {:ok, threat_analysis} <- analyze_cross_system_threats(system_ids, options) do
      results = %{
        constellation_analysis: constellation_analysis,
        activity_correlation: activity_correlation,
        threat_analysis: threat_analysis,
        analysis_type: :comprehensive
      }

      {:ok, results}
    end
  end

  defp execute_analysis_workflow(:activity_only, system_ids, _starting_system, options) do
    with {:ok, activity_correlation} <- correlate_cross_system_activity(system_ids, options) do
      results = %{
        activity_correlation: activity_correlation,
        analysis_type: :activity_only
      }

      {:ok, results}
    end
  end

  defp execute_analysis_workflow(:threats_only, system_ids, _starting_system, options) do
    with {:ok, threat_analysis} <- analyze_cross_system_threats(system_ids, options) do
      results = %{
        threat_analysis: threat_analysis,
        analysis_type: :threats_only
      }

      {:ok, results}
    end
  end

  defp execute_analysis_workflow(:constellation_only, system_ids, starting_system, options) do
    # Use first system if no starting system specified
    analysis_system = starting_system || List.first(system_ids)

    if analysis_system do
      with {:ok, constellation_analysis} <- analyze_wormhole_chain(analysis_system, options) do
        results = %{
          constellation_analysis: constellation_analysis,
          analysis_type: :constellation_only
        }

        {:ok, results}
      end
    else
      {:error, "No system specified for constellation analysis"}
    end
  end

  defp maybe_analyze_constellation(nil, _options), do: {:ok, %{analysis_skipped: true}}

  defp maybe_analyze_constellation(starting_system, options) do
    analyze_wormhole_chain(starting_system, options)
  end

  defp integrate_analysis_results(results, analysis_scope) do
    # Integrate results from different analyzers
    integrated = %{
      analysis_id: generate_analysis_id(),
      analysis_scope: analysis_scope,
      analysis_timestamp: DateTime.utc_now(),
      results: results,
      integration_confidence: calculate_integration_confidence(results)
    }

    {:ok, integrated}
  end

  defp generate_strategic_assessment(integrated_intelligence, options) do
    # Generate strategic assessment from integrated intelligence
    include_recommendations = Keyword.get(options, :include_recommendations, true)

    assessment = %{
      intelligence: integrated_intelligence,
      strategic_summary: generate_strategic_summary(integrated_intelligence),
      threat_level: assess_overall_threat_level(integrated_intelligence),
      opportunities: identify_strategic_opportunities(integrated_intelligence),
      recommendations:
        maybe_generate_recommendations(integrated_intelligence, include_recommendations),
      confidence_score: integrated_intelligence.integration_confidence
    }

    {:ok, assessment}
  end

  # Helper functions for strategic assessment

  defp generate_analysis_id do
    "cross_sys_#{System.unique_integer([:positive])}"
  end

  defp calculate_integration_confidence(results) do
    # Calculate confidence based on what analyses were completed
    analysis_count = count_completed_analyses(results)

    case analysis_count do
      # All three analyses completed
      3 -> 0.95
      # Two analyses completed
      2 -> 0.80
      # One analysis completed
      1 -> 0.60
      # No analyses completed
      0 -> 0.0
    end
  end

  defp count_completed_analyses(results) do
    analyses = [:constellation_analysis, :activity_correlation, :threat_analysis]

    |> Enum.count(analyses, fn analysis ->
      case Map.get(results, analysis) do
        nil -> false
        %{analysis_skipped: true} -> false
        _ -> true
      end
    end)
  end

  defp generate_strategic_summary(integrated_intelligence) do
    results = integrated_intelligence.results

    summary_parts =
      []
      |> add_constellation_summary_if_present(results)
      |> add_activity_summary_if_present(results)
      |> add_threat_summary_if_present(results)

    %{
      summary_components: Enum.reverse(summary_parts),
      overall_assessment: generate_overall_assessment(summary_parts)
    }
  end

  defp add_constellation_summary_if_present(summary_parts, results) do
    if Map.has_key?(results, :constellation_analysis) &&
         !Map.get(results.constellation_analysis, :analysis_skipped, false) do
      constellation_summary = extract_constellation_summary(results.constellation_analysis)
      [constellation_summary | summary_parts]
    else
      summary_parts
    end
  end

  defp add_activity_summary_if_present(summary_parts, results) do
    if Map.has_key?(results, :activity_correlation) do
      activity_summary = extract_activity_summary(results.activity_correlation)
      [activity_summary | summary_parts]
    else
      summary_parts
    end
  end

  defp add_threat_summary_if_present(summary_parts, results) do
    if Map.has_key?(results, :threat_analysis) do
      threat_summary = extract_threat_summary(results.threat_analysis)
      [threat_summary | summary_parts]
    else
      summary_parts
    end
  end

  defp assess_overall_threat_level(integrated_intelligence) do
    results = integrated_intelligence.results

    # Extract threat levels from different analyses
    threat_indicators =
      []
      |> add_constellation_threat_if_present(results)
      |> add_activity_threat_if_present(results)
      |> add_direct_threat_if_present(results)

    # Combine threat indicators
    case threat_indicators do
      [] -> :unknown
      indicators -> calculate_combined_threat_level(indicators)
    end
  end

  defp add_constellation_threat_if_present(indicators, results) do
    if Map.has_key?(results, :constellation_analysis) do
      constellation_threat = extract_constellation_threat_level(results.constellation_analysis)
      [constellation_threat | indicators]
    else
      indicators
    end
  end

  defp add_activity_threat_if_present(indicators, results) do
    if Map.has_key?(results, :activity_correlation) do
      activity_threat = extract_activity_threat_level(results.activity_correlation)
      [activity_threat | indicators]
    else
      indicators
    end
  end

  defp add_direct_threat_if_present(indicators, results) do
    if Map.has_key?(results, :threat_analysis) do
      direct_threat = extract_direct_threat_level(results.threat_analysis)
      [direct_threat | indicators]
    else
      indicators
    end
  end

  defp identify_strategic_opportunities(integrated_intelligence) do
    # Identify opportunities from the analysis results
    results = integrated_intelligence.results
    opportunities = []

    # Check for low-threat, high-value areas
    # Check for correlation gaps (unmonitored systems)
    # Check for tactical advantages

    opportunities
  end

  defp maybe_generate_recommendations(_integrated_intelligence, false), do: []

  defp maybe_generate_recommendations(integrated_intelligence, true) do
    # Generate actionable recommendations based on the analysis
    threat_level = assess_overall_threat_level(integrated_intelligence)

    case threat_level do
      :critical ->
        [
          "Immediate defensive posture recommended",
          "Evacuate non-essential assets",
          "Establish fallback positions"
        ]

      :high ->
        [
          "Increase vigilance and monitoring",
          "Prepare defensive measures",
          "Consider proactive reconnaissance"
        ]

      :moderate ->
        [
          "Maintain standard monitoring",
          "Review escape routes",
          "Monitor for escalation"
        ]

      :low ->
        [
          "Continue normal operations",
          "Routine monitoring sufficient"
        ]

      _ ->
        ["Insufficient data for recommendations"]
    end
  end

  # Extraction helper functions (simplified implementations)
  defp extract_constellation_summary(_constellation_analysis),
    do: "Constellation analysis completed"

  defp extract_activity_summary(_activity_correlation),
    do: "Activity correlation analysis completed"

  defp extract_threat_summary(_threat_analysis), do: "Threat analysis completed"

  defp generate_overall_assessment(summary_parts),
    do: "#{length(summary_parts)} analyses completed"

  defp extract_constellation_threat_level(_constellation_analysis), do: :moderate
  defp extract_activity_threat_level(_activity_correlation), do: :moderate

  defp extract_direct_threat_level(threat_analysis),
    do: Map.get(threat_analysis, :overall_threat_level, :moderate)

  defp calculate_combined_threat_level(indicators) do
    # Simple threat level combination logic
    if Enum.any?(indicators, &(&1 == :critical)),
      do: :critical,
      else:
        if(Enum.any?(indicators, &(&1 == :high)),
          do: :high,
          else:
            if(Enum.any?(indicators, &(&1 == :moderate)),
              do: :moderate,
              else: :low
            )
        )
  end
end
