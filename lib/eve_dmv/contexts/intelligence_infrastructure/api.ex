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

  # Regional Analysis
  defdelegate analyze_region(region_id, opts \\ []),
    to: RegionalAnalyzer,
    as: :analyze_regional_patterns

  defdelegate analyze_constellation(constellation_id, opts \\ []),
    to: ConstellationAnalyzer,
    as: :analyze_constellation_patterns

  defdelegate analyze_system(system_id, opts \\ []), to: SingleSystemAnalyzer, as: :analyze_system

  # Cross-System Analysis
  defdelegate analyze_cross_system(systems, opts \\ []),
    to: CrossSystemAnalyzer,
    as: :analyze_strategic_patterns

  # Correlation Analysis
  defdelegate correlate_threats(threats, opts \\ []), to: ThreatCorrelator, as: :correlate_threats

  defdelegate correlate_activity(activity_data, opts \\ []),
    to: ActivityCorrelator,
    as: :correlate_activities
end
