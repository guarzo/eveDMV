defmodule EveDmv.Contexts.SystemAnalysis.Api do
  @moduledoc """
  API for System Analysis functionality.
  Provides access to heatmap generation, activity analysis, regional correlations, and escalation detection.
  """

  alias EveDmv.Contexts.SystemAnalysis.Domain.ActivityIntensityCalculator
  alias EveDmv.Contexts.SystemAnalysis.Domain.EscalationDetector
  alias EveDmv.Contexts.SystemAnalysis.Domain.HeatmapGenerator
  alias EveDmv.Contexts.SystemAnalysis.Domain.RegionalCorrelationAnalyzer

  # Heatmap Generation

  @doc """
  Generates heatmap data for a region within a timeframe.
  Returns system coordinates with activity intensity.
  """
  def generate_region_heatmap(region_id, opts \\ []) do
    HeatmapGenerator.generate_heatmap_data(region_id, opts)
  end

  @doc """
  Generates detailed constellation-level heatmap.
  """
  def generate_constellation_heatmap(constellation_id, opts \\ []) do
    HeatmapGenerator.generate_constellation_heatmap(constellation_id, opts)
  end

  # Activity Intensity Analysis

  @doc """
  Calculates comprehensive intensity score for a system.
  """
  def calculate_system_intensity(system_id, opts \\ []) do
    ActivityIntensityCalculator.calculate_intensity(system_id, opts)
  end

  @doc """
  Calculates relative intensity compared to neighboring systems.
  """
  def calculate_relative_intensity(system_id, neighbor_ids, opts \\ []) do
    ActivityIntensityCalculator.calculate_relative_intensity(system_id, neighbor_ids, opts)
  end

  # Regional Correlation Analysis

  @doc """
  Analyzes activity correlations across a region.
  Identifies patterns, clusters, and escalation chains.
  """
  def analyze_regional_correlations(region_id, opts \\ []) do
    RegionalCorrelationAnalyzer.analyze_regional_correlations(region_id, opts)
  end

  @doc """
  Detects activity spillover between systems.
  """
  def analyze_activity_spillover(source_system_id, opts \\ []) do
    RegionalCorrelationAnalyzer.analyze_activity_spillover(source_system_id, opts)
  end

  # Escalation Detection

  @doc """
  Detects escalation patterns in a system or region.
  """
  def detect_escalations(scope, opts \\ []) do
    EscalationDetector.detect_escalations(scope, opts)
  end

  @doc """
  Real-time escalation monitoring for a system.
  """
  def monitor_escalation(system_id, window_minutes \\ 30) do
    EscalationDetector.monitor_escalation(system_id, window_minutes)
  end

  # Combined Analysis Functions

  @doc """
  Comprehensive system analysis combining all analysis types.
  Returns a complete picture of system activity, intensity, correlations, and escalation risk.
  """
  def comprehensive_system_analysis(system_id, opts \\ []) do
    timeframe_opts = Keyword.take(opts, [:hours, :days])

    with {:ok, intensity} <- calculate_system_intensity(system_id, timeframe_opts),
         {:ok, escalations} <- detect_escalations({:system, system_id}, timeframe_opts),
         {:ok, monitoring} <-
           monitor_escalation(system_id, Keyword.get(opts, :window_minutes, 30)) do
      {:ok,
       %{
         system_id: system_id,
         timeframe: build_timeframe(timeframe_opts),
         intensity_analysis: intensity,
         escalation_analysis: escalations,
         real_time_monitoring: monitoring,
         risk_assessment: assess_combined_risk(intensity, escalations, monitoring),
         recommendations: generate_recommendations(intensity, escalations, monitoring),
         generated_at: DateTime.utc_now()
       }}
    end
  end

  @doc """
  Regional dashboard data combining heatmaps with correlation analysis.
  """
  def regional_dashboard(region_id, opts \\ []) do
    timeframe_opts = Keyword.take(opts, [:hours, :days])

    with {:ok, heatmap} <- generate_region_heatmap(region_id, timeframe_opts),
         {:ok, correlations} <- analyze_regional_correlations(region_id, timeframe_opts) do
      {:ok,
       %{
         region_id: region_id,
         timeframe: build_timeframe(timeframe_opts),
         heatmap_data: heatmap,
         correlation_analysis: correlations,
         summary: generate_regional_summary(heatmap, correlations),
         hotspot_rankings: rank_regional_hotspots(heatmap, correlations),
         generated_at: DateTime.utc_now()
       }}
    end
  end

  @doc """
  Activity spillover analysis for multiple systems.
  Useful for understanding activity propagation patterns.
  """
  def multi_system_spillover_analysis(source_systems, opts \\ []) when is_list(source_systems) do
    timeframe_opts = Keyword.take(opts, [:hours, :days])

    spillover_analyses =
      source_systems
      |> Enum.map(fn system_id ->
        case analyze_activity_spillover(system_id, timeframe_opts) do
          {:ok, analysis} -> {system_id, analysis}
          {:error, _} -> {system_id, %{error: "Analysis failed"}}
        end
      end)
      |> Map.new()

    {:ok,
     %{
       source_systems: source_systems,
       timeframe: build_timeframe(timeframe_opts),
       spillover_analyses: spillover_analyses,
       network_effects: analyze_network_effects(spillover_analyses),
       propagation_patterns: identify_propagation_patterns(spillover_analyses),
       generated_at: DateTime.utc_now()
     }}
  end

  # Helper Functions

  defp build_timeframe(opts) do
    default_hours = Keyword.get(opts, :hours, 24)
    default_days = Keyword.get(opts, :days, 0)

    total_hours = default_hours + default_days * 24

    %{
      start_time: DateTime.add(DateTime.utc_now(), -total_hours * 3600, :second),
      end_time: DateTime.utc_now(),
      duration_hours: total_hours
    }
  end

  defp assess_combined_risk(intensity, escalations, monitoring) do
    # Combine risk indicators from all analysis types
    intensity_risk =
      case intensity.classification do
        :extreme -> 90
        :high -> 70
        :moderate -> 50
        :low -> 30
        :minimal -> 10
      end

    escalation_risk =
      case escalations.risk_assessment do
        :critical -> 90
        :high -> 70
        :moderate -> 50
        :low -> 30
        :minimal -> 10
      end

    monitoring_risk = monitoring.risk_score

    # Weighted combination
    combined_risk = intensity_risk * 0.3 + escalation_risk * 0.4 + monitoring_risk * 0.3

    %{
      combined_risk_score: Float.round(combined_risk, 1),
      risk_level: classify_combined_risk(combined_risk),
      primary_risk_factor:
        identify_primary_risk(intensity_risk, escalation_risk, monitoring_risk),
      confidence: calculate_risk_confidence(intensity, escalations, monitoring)
    }
  end

  defp classify_combined_risk(score) do
    cond do
      score >= 80 -> :critical
      score >= 60 -> :high
      score >= 40 -> :moderate
      score >= 20 -> :low
      true -> :minimal
    end
  end

  defp identify_primary_risk(intensity_risk, escalation_risk, monitoring_risk) do
    risks = [
      {:intensity, intensity_risk},
      {:escalation, escalation_risk},
      {:real_time, monitoring_risk}
    ]

    risks
    |> Enum.max_by(fn {_type, risk} -> risk end)
    |> elem(0)
  end

  defp calculate_risk_confidence(intensity, escalations, monitoring) do
    # Base confidence on data quality and recency
    base_confidence = 0.8

    # Reduce confidence if data is limited
    data_factors = [
      intensity.raw_metrics.total_kills > 10,
      escalations.escalations_detected > 0,
      monitoring.indicators.participant_growth.current_participants > 0
    ]

    active_factors = Enum.count(data_factors, & &1)
    confidence_adjustment = active_factors / 3 * 0.2

    Float.round(base_confidence + confidence_adjustment, 2)
  end

  defp generate_recommendations(intensity, escalations, monitoring) do
    # Intensity-based recommendations
    intensity_recommendations =
      case intensity.classification do
        :extreme ->
          ["Extreme activity detected - consider avoiding or bringing strong fleet"]

        :high ->
          ["High activity system - proceed with caution and scouts"]

        :moderate ->
          ["Moderate activity - standard precautions recommended"]

        _ ->
          []
      end

    # Escalation-based recommendations
    escalation_recommendations =
      if escalations.escalations_detected > 0 do
        ["Active escalations detected - expect reinforcements"]
      else
        []
      end

    # Real-time monitoring recommendations
    monitoring_recommendations =
      case monitoring.risk_level do
        :critical ->
          ["CRITICAL: Major engagement in progress - avoid or commit fully"]

        :high ->
          ["HIGH: Escalation in progress - consider tactical withdrawal"]

        _ ->
          []
      end

    # Combine all recommendations
    all_recommendations =
      intensity_recommendations ++ escalation_recommendations ++ monitoring_recommendations

    # Default recommendation if none triggered
    case all_recommendations do
      [] -> ["System appears quiet - normal operations can proceed"]
      recs -> recs
    end
  end

  defp generate_regional_summary(heatmap, correlations) do
    %{
      total_systems: heatmap.metadata.total_systems,
      active_systems: heatmap.metadata.active_systems,
      activity_percentage:
        Float.round(
          heatmap.metadata.active_systems / max(heatmap.metadata.total_systems, 1) * 100,
          1
        ),
      total_kills: heatmap.metadata.total_kills,
      total_isk_destroyed: heatmap.metadata.total_isk_destroyed,
      hottest_system: heatmap.metadata.hottest_system,
      activity_clusters: length(correlations.activity_clusters),
      escalation_chains: length(correlations.escalation_chains),
      network_cohesion: correlations.network_metrics.network_cohesion
    }
  end

  defp rank_regional_hotspots(heatmap, correlations) do
    # Combine heatmap intensity with correlation influence
    system_rankings =
      heatmap.systems
      |> Enum.map(fn system ->
        # Find matching hotspot data
        hotspot_data =
          correlations.hotspot_systems
          |> Enum.find(%{influence_score: 0}, fn h -> h.system_id == system.system_id end)

        combined_score =
          system.activity_metrics.intensity_score +
            hotspot_data.influence_score / 10

        %{
          system_id: system.system_id,
          system_name: system.system_name,
          intensity_score: system.activity_metrics.intensity_score,
          influence_score: hotspot_data.influence_score,
          combined_score: combined_score,
          danger_rating: system.activity_metrics.danger_rating,
          classification: hotspot_data.classification || :quiet
        }
      end)
      |> Enum.sort_by(& &1.combined_score, :desc)
      |> Enum.take(10)

    system_rankings
  end

  defp analyze_network_effects(spillover_analyses) do
    # Analyze overall network connectivity and influence patterns
    successful_analyses =
      spillover_analyses
      |> Enum.filter(fn {_id, analysis} -> !Map.has_key?(analysis, :error) end)

    case successful_analyses do
      [] ->
        %{
          network_connectivity: 0.0,
          average_influence_radius: 0.0,
          propagation_strength: 0.0
        }

      analyses ->
        influence_radii =
          Enum.map(analyses, fn {_id, analysis} ->
            analysis.influence_radius
          end)

        propagation_speeds =
          Enum.map(analyses, fn {_id, analysis} ->
            analysis.propagation_speed
          end)

        %{
          network_connectivity: calculate_average(influence_radii) / 10,
          average_influence_radius: calculate_average(influence_radii),
          propagation_strength: calculate_average(propagation_speeds)
        }
    end
  end

  defp identify_propagation_patterns(spillover_analyses) do
    # Identify common patterns in how activity spreads
    successful_analyses =
      spillover_analyses
      |> Enum.filter(fn {_id, analysis} -> !Map.has_key?(analysis, :error) end)

    patterns =
      successful_analyses
      |> Enum.flat_map(fn {source_id, analysis} ->
        analysis.spillover_effects
        |> Enum.filter(fn effect -> effect.spillover_score > 0.1 end)
        |> Enum.map(fn effect ->
          %{
            source: source_id,
            target: effect.system_id,
            strength: effect.spillover_score,
            correlation: effect.correlation,
            time_lag: effect.time_lag
          }
        end)
      end)
      |> Enum.sort_by(& &1.strength, :desc)

    %{
      strong_connections: Enum.take(patterns, 10),
      pattern_count: length(patterns),
      average_strength: calculate_average(Enum.map(patterns, & &1.strength)),
      directional_flow: analyze_directional_patterns(patterns)
    }
  end

  defp analyze_directional_patterns(patterns) do
    # Simplified directional analysis
    # In production, would do more sophisticated flow analysis
    case patterns do
      [] ->
        %{dominant_direction: :none, flow_strength: 0.0}

      _ ->
        %{
          dominant_direction: :bidirectional,
          flow_strength: calculate_average(Enum.map(patterns, & &1.strength))
        }
    end
  end

  defp calculate_average([]), do: 0.0
  defp calculate_average(values), do: Enum.sum(values) / length(values)
end
