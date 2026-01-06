defmodule EveDmv.Contexts.ThreatAssessment.Api do
  @moduledoc """
  Public API for the Threat Assessment context.

  Provides threat analysis and vulnerability scanning capabilities
  for characters, corporations, and systems.
  """

  alias EveDmv.Contexts.ThreatAssessment.Analyzers.ThreatAnalyzer
  alias EveDmv.Contexts.ThreatAssessment.Analyzers.VulnerabilityScanner
  alias EveDmv.Result
  alias EveDmv.Types

  # Threat Analysis

  @doc """
  Analyze a character's threat level.

  Returns comprehensive threat assessment including threat score, bait probability,
  activity patterns, and associate analysis.
  """
  @spec analyze_character_threat(Types.character_id(), map(), Types.opts()) :: Result.t(map())
  defdelegate analyze_character_threat(character_id, base_data \\ %{}, opts \\ []),
    to: ThreatAnalyzer,
    as: :analyze

  @doc """
  Analyze multiple pilots in batch.

  Returns bulk analysis with individual pilot assessments and aggregate statistics.
  """
  @spec analyze_pilots([map()], map(), Types.opts()) :: Result.t(map())
  defdelegate analyze_pilots(pilot_list, base_data \\ %{}, opts \\ []), to: ThreatAnalyzer

  @doc """
  Analyze threats for all inhabitants in a system.

  Returns system-wide threat assessment including threat distribution,
  bait risk, and coordinated threat indicators.
  """
  @spec analyze_system_threats(Types.system_id(), [map()], map(), Types.opts()) :: Result.t(map())
  defdelegate analyze_system_threats(system_id, inhabitants, base_data \\ %{}, opts \\ []),
    to: ThreatAnalyzer

  # Vulnerability Scanning

  @doc """
  Analyze vulnerabilities for an entity.

  Returns comprehensive vulnerability analysis including behavioral, tactical,
  operational, and social vulnerabilities.
  """
  @spec analyze_vulnerabilities(pos_integer(), map(), Types.opts()) :: Result.t(map())
  defdelegate analyze_vulnerabilities(entity_id, base_data, opts \\ []),
    to: VulnerabilityScanner,
    as: :analyze
end
