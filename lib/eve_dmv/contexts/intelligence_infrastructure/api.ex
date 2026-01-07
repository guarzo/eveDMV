defmodule EveDmv.Contexts.IntelligenceInfrastructure.Api do
  @moduledoc """
  Public API for the Intelligence Infrastructure context.

  Provides shared infrastructure components for intelligence analysis
  including cross-system analysis, regional analysis, and threat correlation.
  """

  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Analyzers.ConstellationAnalyzer
  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Analyzers.RegionalAnalyzer

  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Analyzers.SingleSystemAnalyzer

  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Correlators.ActivityCorrelator

  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Correlators.ThreatCorrelator
  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystemAnalyzer
  alias EveDmv.Types

  # Regional Analysis

  @doc """
  Analyze regional patterns and trends.

  Returns activity patterns, threat landscape, strategic assessment,
  and trend analysis for the specified region.
  """
  @spec analyze_region(Types.region_id(), Types.opts()) :: map()
  defdelegate analyze_region(region_id, opts \\ []),
    to: RegionalAnalyzer,
    as: :analyze_regional_patterns

  @doc """
  Analyze constellation-wide patterns.

  Returns activity analysis, threat assessment, and strategic patterns
  for the specified constellation.
  """
  @spec analyze_constellation(Types.constellation_id(), Types.opts()) :: map()
  defdelegate analyze_constellation(constellation_id, opts \\ []),
    to: ConstellationAnalyzer,
    as: :analyze_constellation_patterns

  @doc """
  Analyze a single system for cross-system context.

  Returns activity metrics, threat assessment, and system characteristics.
  """
  @spec analyze_system(Types.system_id(), Types.opts()) :: map()
  defdelegate analyze_system(system_id, opts \\ []), to: SingleSystemAnalyzer, as: :analyze_system

  # Cross-System Analysis

  @doc """
  Analyze strategic patterns across multiple systems.

  Returns cross-system correlations, movement patterns, and strategic insights.
  """
  @spec analyze_cross_system([Types.system_id()] | map(), Types.opts()) ::
          {:ok, map()} | {:error, term()}
  defdelegate analyze_cross_system(systems, opts \\ []),
    to: CrossSystemAnalyzer,
    as: :analyze_strategic_patterns

  # Correlation Analysis

  @doc """
  Correlate threats across multiple systems.

  Returns threat correlation strength, correlated threats, and threat patterns.
  """
  @spec correlate_threats([map()] | [Types.system_id()], Types.opts()) :: map()
  defdelegate correlate_threats(threats, opts \\ []), to: ThreatCorrelator, as: :correlate_threats

  @doc """
  Correlate activity patterns across systems.

  Returns correlation strength, correlated patterns, and activity synchronization.
  """
  @spec correlate_activity([Types.system_id()], Types.opts()) :: Types.activity_correlation()
  defdelegate correlate_activity(activity_data, opts \\ []),
    to: ActivityCorrelator,
    as: :correlate_activities
end
