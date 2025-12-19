defmodule EveDmv.Contexts.CorporationAnalysis.Api do
  @moduledoc """
  Public API for the Corporation Analysis context.

  Provides access to corporation-level analysis including member activity,
  participation metrics, and organizational health assessment.

  Note: For comprehensive corporation analysis, prefer using
  `EveDmv.Contexts.Corporation.Core.CorporationAnalyzer` which is the
  canonical corporation analysis module.
  """

  alias EveDmv.Contexts.CorporationAnalysis.Analyzers.MemberActivityAnalyzer
  alias EveDmv.Contexts.CorporationAnalysis.Analyzers.ParticipationAnalyzer

  # Member Activity Analysis
  defdelegate analyze_member_activity(corporation_id, base_data \\ %{}),
    to: MemberActivityAnalyzer,
    as: :analyze

  # Participation Analysis
  defdelegate analyze_character_participation(character_id, base_data \\ %{}, opts \\ []),
    to: ParticipationAnalyzer,
    as: :analyze

  defdelegate analyze_corporation_participation(corporation_id, base_data \\ %{}, opts \\ []),
    to: ParticipationAnalyzer
end
