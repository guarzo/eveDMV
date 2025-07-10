defmodule EveDmv.Contexts.CharacterIntelligence do
  @moduledoc """
  Context module for character intelligence and threat analysis.
  
  Provides the public API for character threat scoring, behavioral analysis,
  and combat effectiveness prediction.
  """
  
  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoringEngine
  
  @doc """
  Analyzes a character's threat level based on their combat history.
  
  Returns comprehensive threat scoring including:
  - Multi-dimensional threat score (0-100)
  - Combat effectiveness metrics
  - Behavioral patterns
  - Threat trends over time
  
  ## Examples
  
      iex> CharacterIntelligence.analyze_character_threat(character_id)
      {:ok, %{
        threat_score: 85,
        dimensions: %{combat_skill: 90, ship_mastery: 80, ...},
        behavioral_pattern: :solo_hunter,
        recent_activity: %{...}
      }}
  """
  def analyze_character_threat(character_id) do
    case ThreatScoringEngine.calculate_threat_score(character_id) do
      {:ok, threat_data} -> {:ok, threat_data}
      error -> error
    end
  end
  
  @doc """
  Detects behavioral patterns for a character based on their killmail history.
  
  Identifies patterns such as:
  - Solo hunter
  - Fleet anchor
  - Specialist
  - Opportunist
  """
  def detect_behavioral_patterns(character_id) do
    # Since ThreatScoringEngine includes behavioral analysis in the threat score,
    # we'll extract it from there
    case analyze_character_threat(character_id) do
      {:ok, threat_data} ->
        {:ok, %{
          primary_pattern: threat_data[:behavioral_pattern] || :unknown,
          patterns: extract_behavioral_patterns(threat_data),
          characteristics: generate_behavioral_characteristics(threat_data)
        }}
      error -> error
    end
  end
  
  @doc """
  Calculates threat trends for a character over time.
  
  Shows how their threat level has evolved based on recent performance.
  """
  def calculate_threat_trends(character_id, days_back \\ 90) do
    case ThreatScoringEngine.analyze_threat_trends(character_id, analysis_window_days: days_back) do
      {:ok, trends} -> {:ok, trends}
      error -> error
    end
  end
  
  @doc """
  Compares threat levels between multiple characters.
  
  Useful for identifying the most dangerous opponents in a group.
  """
  def compare_character_threats(character_ids) when is_list(character_ids) do
    threat_analyses = 
      character_ids
      |> Enum.map(fn id ->
        case analyze_character_threat(id) do
          {:ok, analysis} -> {id, analysis}
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(fn {_id, analysis} -> analysis.threat_score end, :desc)
    
    {:ok, threat_analyses}
  end
  
  @doc """
  Gets a comprehensive intelligence report for a character.
  
  Combines threat scoring, behavioral analysis, and performance metrics.
  """
  def get_character_intelligence_report(character_id) do
    with {:ok, threat_analysis} <- analyze_character_threat(character_id),
         {:ok, behavioral_patterns} <- detect_behavioral_patterns(character_id),
         {:ok, threat_trends} <- calculate_threat_trends(character_id),
         {:ok, character_info} <- get_character_info(character_id) do
      {:ok, %{
        character: character_info,
        threat_analysis: threat_analysis,
        behavioral_patterns: behavioral_patterns,
        threat_trends: threat_trends,
        summary: generate_intelligence_summary(threat_analysis, behavioral_patterns)
      }}
    end
  end
  
  # Private helper functions
  
  defp get_character_info(character_id) do
    # For now, just return basic info
    # In production, this would query the character table or EVE API
    {:ok, %{
      character_id: character_id,
      name: "Character #{character_id}",
      corporation_id: nil,
      corporation_name: nil,
      alliance_id: nil,
      alliance_name: nil
    }}
  end
  
  defp extract_behavioral_patterns(threat_data) do
    # Extract behavioral patterns from threat data dimensions
    dimensions = Map.get(threat_data, :dimensions, %{})
    
    patterns = []
    |> maybe_add_pattern(:solo_hunter, dimensions[:solo_effectiveness] > 70)
    |> maybe_add_pattern(:fleet_anchor, dimensions[:gang_effectiveness] > 80)
    |> maybe_add_pattern(:specialist, dimensions[:ship_focus] > 0.7)
    |> maybe_add_pattern(:opportunist, dimensions[:target_selection_variance] > 0.6)
    
    # Convert to pattern map with confidence scores
    Enum.map(patterns, fn pattern ->
      {pattern, calculate_pattern_confidence(pattern, dimensions)}
    end)
    |> Enum.into(%{})
  end
  
  defp maybe_add_pattern(patterns, pattern, true), do: [pattern | patterns]
  defp maybe_add_pattern(patterns, _pattern, false), do: patterns
  
  defp calculate_pattern_confidence(:solo_hunter, dimensions) do
    (Map.get(dimensions, :solo_effectiveness, 0) / 100.0)
  end
  defp calculate_pattern_confidence(:fleet_anchor, dimensions) do
    (Map.get(dimensions, :gang_effectiveness, 0) / 100.0)
  end
  defp calculate_pattern_confidence(:specialist, dimensions) do
    Map.get(dimensions, :ship_focus, 0)
  end
  defp calculate_pattern_confidence(:opportunist, dimensions) do
    Map.get(dimensions, :target_selection_variance, 0)
  end
  
  defp generate_behavioral_characteristics(threat_data) do
    dimensions = Map.get(threat_data, :dimensions, %{})
    characteristics = []
    
    # Add characteristics based on dimensions
    characteristics = if dimensions[:combat_skill] > 80 do
      ["Highly skilled combatant" | characteristics]
    else
      characteristics
    end
    
    characteristics = if dimensions[:ship_mastery] > 75 do
      ["Proficient with multiple ship types" | characteristics]
    else
      characteristics
    end
    
    characteristics = if dimensions[:gang_effectiveness] > 70 do
      ["Effective in fleet operations" | characteristics]
    else
      characteristics
    end
    
    characteristics = if dimensions[:unpredictability] > 60 do
      ["Unpredictable engagement patterns" | characteristics]
    else
      characteristics
    end
    
    characteristics
  end
  
  defp generate_intelligence_summary(threat_analysis, behavioral_patterns) do
    primary_pattern = behavioral_patterns |> Map.get(:primary_pattern, :unknown)
    threat_level = case threat_analysis.threat_score do
      score when score >= 90 -> "Extreme"
      score when score >= 75 -> "High"
      score when score >= 50 -> "Moderate"
      score when score >= 25 -> "Low"
      _ -> "Minimal"
    end
    
    %{
      threat_level: threat_level,
      threat_score: threat_analysis.threat_score,
      primary_behavior: primary_pattern,
      summary: "#{threat_level} threat #{primary_pattern |> to_string() |> String.replace("_", " ")} with #{threat_analysis.threat_score}/100 overall score",
      key_strengths: extract_key_strengths(threat_analysis.dimensions),
      recommendations: generate_tactical_recommendations(threat_analysis, behavioral_patterns)
    }
  end
  
  defp extract_key_strengths(dimensions) do
    dimensions
    |> Enum.sort_by(fn {_key, value} -> value end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {key, value} ->
      %{
        dimension: key |> to_string() |> String.replace("_", " ") |> String.capitalize(),
        score: value
      }
    end)
  end
  
  defp generate_tactical_recommendations(threat_analysis, behavioral_patterns) do
    pattern = behavioral_patterns.primary_pattern
    
    base_recommendations = case pattern do
      :solo_hunter -> [
        "Avoid isolated engagements",
        "Travel with backup when possible",
        "Use scout alts in adjacent systems"
      ]
      :fleet_anchor -> [
        "Primary target in fleet engagements",
        "Likely to have logistics support",
        "Disrupt their fleet coordination"
      ]
      :specialist -> [
        "Predictable ship choices",
        "Counter their preferred tactics",
        "Force them out of comfort zone"
      ]
      :opportunist -> [
        "Unpredictable target selection",
        "Avoid appearing as easy target",
        "Watch for baiting tactics"
      ]
      _ -> [
        "Gather more intelligence",
        "Observe engagement patterns",
        "Assess threat carefully"
      ]
    end
    
    # Add recommendations based on threat score
    threat_recommendations = if threat_analysis.threat_score >= 75 do
      ["Exercise extreme caution", "Consider avoiding direct engagement"]
    else
      []
    end
    
    base_recommendations ++ threat_recommendations
  end
end