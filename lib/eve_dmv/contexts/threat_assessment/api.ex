defmodule EveDmv.Contexts.ThreatAssessment.Api do
  @moduledoc """
  Public API for the Threat Assessment context.

  Provides threat analysis and vulnerability scanning capabilities
  for characters, corporations, and systems.
  """

  alias EveDmv.Contexts.ThreatAssessment.Analyzers.ThreatAnalyzer
  alias EveDmv.Contexts.ThreatAssessment.Analyzers.VulnerabilityScanner

  # Threat Analysis
  defdelegate analyze_character_threat(character_id, base_data \\ %{}, opts \\ []),
    to: ThreatAnalyzer,
    as: :analyze

  defdelegate analyze_pilots(pilot_list, base_data \\ %{}, opts \\ []), to: ThreatAnalyzer

  defdelegate analyze_system_threats(system_id, inhabitants, base_data \\ %{}, opts \\ []),
    to: ThreatAnalyzer

  # Vulnerability Scanning
  defdelegate analyze_vulnerabilities(entity_id, base_data, opts \\ []),
    to: VulnerabilityScanner,
    as: :analyze
end
