defmodule EveDmv.Shared.Strategic.Facade do
  @moduledoc """
  Simplified interface for the strategic analysis system.

  Provides backward compatibility and a clean API for the modular
  strategic analysis components.
  """
  """

  alias EveDmv.Shared.Strategic.AssessmentCompiler
  alias EveDmv.Shared.Strategic.CorrelationEngine
  alias EveDmv.Shared.Strategic.DataCollector
  alias EveDmv.Shared.Strategic.OpportunityIdentifier
  alias EveDmv.Shared.Strategic.PatternRecognition
  alias EveDmv.Shared.Strategic.RecommendationEngine
  alias EveDmv.Shared.Strategic.ResourceAnalyzer
  alias EveDmv.Shared.Strategic.TemporalAnalyzer
  alias EveDmv.Shared.Strategic.TerritorialAnalyzer
  alias EveDmv.Shared.Strategic.TrendAnalyzer

  require Logger

  @doc """
  Main entry point for strategic pattern analysis.

  This maintains the same interface as the original StrategicPatternAnalyzer.
  """
  def analyze_strategic_patterns(analysis_scope, options \\ []) do
    Logger.info("Analyzing strategic patterns for scope: #{inspect(analysis_scope)}")

    start_time = System.monotonic_time(:millisecond)

    # Collect strategic data
    analysis_window_days = Keyword.get(options, :analysis_window_days, 14)

    with {:ok, strategic_data} <-
           DataCollector.collect_strategic_data(analysis_scope, analysis_window_days),
         # Pattern analysis
         {:ok, pattern_analysis} <-
           PatternRecognition.identify_strategic_patterns(strategic_data, options[:pattern_focus]),
         # Territorial analysis
         territorial_analysis <-
           analyze_territorial_patterns(
             strategic_data,
             Keyword.get(options, :include_territorial_analysis, true)
           ),
         # Resource analysis
         resource_analysis <-
           analyze_resource_patterns(
             strategic_data,
             Keyword.get(options, :include_resource_analysis, true)
           ),
         # Trend analysis
         trend_analysis <-
           TrendAnalyzer.analyze_strategic_trends(strategic_data, pattern_analysis),
         # Opportunity analysis
         opportunity_analysis <-
           OpportunityIdentifier.identify_strategic_opportunities(
             pattern_analysis,
             territorial_analysis,
             resource_analysis
           ),
         # Final assessment
         final_assessment <-
           AssessmentCompiler.compile_strategic_assessment(
             analysis_scope,
             strategic_data,
             %{
               pattern_analysis: pattern_analysis,
               territorial_analysis: territorial_analysis,
               resource_analysis: resource_analysis,
               trend_analysis: trend_analysis,
               opportunity_analysis: opportunity_analysis
             }
           ) do
      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      Logger.info("Strategic pattern analysis completed in #{duration_ms}ms")

      {:ok, Map.put(final_assessment, :analysis_duration_ms, duration_ms)}
    else
      error -> error
    end
  end

  @doc """
  Simplified analysis focusing only on patterns.
  """
  def identify_patterns(strategic_data, pattern_focus \\ nil) do
    PatternRecognition.identify_strategic_patterns(strategic_data, pattern_focus)
  end

  @doc """
  Generates strategic recommendations.
  """
  def generate_strategic_recommendations(
        pattern_analysis,
        territorial_analysis,
        resource_analysis,
        trend_analysis
      ) do
    RecommendationEngine.generate_strategic_recommendations(
      pattern_analysis,
      territorial_analysis,
      resource_analysis,
      trend_analysis
    )
  end

  @doc """
  Identifies strategic opportunities.
  """
  def identify_strategic_opportunities(pattern_analysis, territorial_analysis, resource_analysis) do
    OpportunityIdentifier.identify_strategic_opportunities(
      pattern_analysis,
      territorial_analysis,
      resource_analysis
    )
  end

  @doc """
  Performs temporal analysis on strategic data.
  """
  def analyze_temporal_patterns(strategic_data) do
    %{
      temporal_distribution: TemporalAnalyzer.analyze_temporal_distribution(strategic_data),
      activity_consistency:
        TemporalAnalyzer.calculate_activity_consistency(
          TemporalAnalyzer.analyze_temporal_distribution(strategic_data)
        ),
      temporal_clusters: TemporalAnalyzer.identify_temporal_clusters(strategic_data)
    }
  end

  @doc """
  Performs correlation analysis across systems.
  """
  def analyze_system_correlations(strategic_data, options \\ []) do
    CorrelationEngine.analyze_system_correlations(strategic_data, options)
  end

  @doc """
  Generates a strategic briefing from full assessment.
  """
  def generate_strategic_briefing(full_assessment) do
    AssessmentCompiler.generate_strategic_briefing(full_assessment)
  end

  # Private helper functions

  defp analyze_territorial_patterns(strategic_data, true) do
    TerritorialAnalyzer.analyze_territorial_control(strategic_data)
  end

  defp analyze_territorial_patterns(_, false), do: nil

  defp analyze_resource_patterns(strategic_data, true) do
    ResourceAnalyzer.analyze_resource_competition(strategic_data)
  end

  defp analyze_resource_patterns(_, false), do: nil
end
