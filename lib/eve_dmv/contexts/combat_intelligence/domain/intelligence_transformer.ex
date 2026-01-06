defmodule EveDmv.Contexts.CombatIntelligence.Domain.IntelligenceTransformer do
  @moduledoc """
  Transforms analyzer results into standardized API response structures.

  Provides consistent transformation of raw analysis data into the
  public API format expected by consumers.
  """

  @doc """
  Transforms character analysis results into the public API structure.

  ## Parameters
  - `analysis_result` - Raw analysis result from CharacterAnalyzer

  ## Returns
  A standardized map with:
  - `:character_id` - The analyzed character's ID
  - `:character_name` - Character name or "Unknown"
  - `:threat_level` - Threat level assessment
  - `:analysis_summary` - Summary metrics
  - `:detailed_metrics` - All other analysis data
  - `:recommendations` - List of recommendations (empty by default)
  - `:last_updated` - Timestamp of analysis
  """
  @spec transform_character_analysis(map()) :: map()
  def transform_character_analysis(analysis_result) do
    %{
      character_id: analysis_result.character_id,
      character_name: Map.get(analysis_result, :character_name, "Unknown"),
      threat_level: Map.get(analysis_result, :threat_level, :unknown),
      analysis_summary: %{
        combat_effectiveness: Map.get(analysis_result, :combat_effectiveness, 0.0),
        analyzed_at: Map.get(analysis_result, :analyzed_at, DateTime.utc_now())
      },
      detailed_metrics:
        Map.drop(analysis_result, [
          :character_id,
          :character_name,
          :threat_level,
          :combat_effectiveness,
          :analyzed_at
        ]),
      recommendations: [],
      last_updated: Map.get(analysis_result, :analyzed_at, DateTime.utc_now())
    }
  end

  @doc """
  Transforms corporation analysis results into the public API structure.

  ## Parameters
  - `analysis_result` - Raw analysis result from CorporationAnalyzer

  ## Returns
  A standardized map with:
  - `:corporation_id` - The analyzed corporation's ID
  - `:corporation_name` - Corporation name or "Unknown"
  - `:member_count` - Number of members
  - `:activity_patterns` - Activity pattern data
  - `:threat_distribution` - Threat distribution across members
  - `:coordination_metrics` - Coordination metrics
  - `:last_updated` - Timestamp of analysis
  """
  @spec transform_corporation_analysis(map()) :: map()
  def transform_corporation_analysis(analysis_result) do
    %{
      corporation_id: analysis_result.corporation_id,
      corporation_name: Map.get(analysis_result, :corporation_name, "Unknown"),
      member_count: Map.get(analysis_result, :member_count, 0),
      activity_patterns: Map.get(analysis_result, :activity_patterns, %{}),
      threat_distribution: Map.get(analysis_result, :threat_distribution, %{}),
      coordination_metrics: Map.get(analysis_result, :coordination_metrics, %{}),
      last_updated: Map.get(analysis_result, :analysis_timestamp, DateTime.utc_now())
    }
  end
end
