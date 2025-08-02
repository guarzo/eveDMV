defmodule EveDmv.Contexts.Intelligence.Core.ThreatScoringCoordinator do
  @moduledoc """
  Coordinates threat scoring across multiple characters and provides comparative analysis.
  """

  alias EveDmv.Contexts.Intelligence.Core.ThreatAssessmentEngine

  require Logger

  @doc """
  Calculate threat score for a single character.
  """
  def calculate_threat_score(character_id) do
    calculate_threat_score(character_id, [])
  end

  @doc """
  Calculate threat score for a single character with options.
  """
  def calculate_threat_score(character_id, opts) do
    case ThreatAssessmentEngine.assess_threat(character_id, opts) do
      {:ok, assessment} ->
        {:ok, assessment.overall_score}

      error ->
        error
    end
  end

  @doc """
  Coordinate threat analysis for multiple characters.
  """
  def coordinate_threat_analysis(character_ids, opts \\ []) do
    case ThreatAssessmentEngine.assess_batch(character_ids, opts) do
      {:ok, batch_results} ->
        coordination = %{
          individual_assessments: batch_results.assessments,
          failures: batch_results.failures,
          summary_stats: calculate_summary_stats(batch_results.assessments),
          comparative_rankings: rank_by_threat(batch_results.assessments)
        }

        {:ok, coordination}

      error ->
        error
    end
  end

  @doc """
  Compare threat levels between characters.
  """
  def get_threat_comparison(character_ids) do
    with {:ok, coordination} <- coordinate_threat_analysis(character_ids) do
      comparison = %{
        highest_threat: find_highest_threat(coordination.individual_assessments),
        lowest_threat: find_lowest_threat(coordination.individual_assessments),
        threat_distribution: analyze_threat_distribution(coordination.individual_assessments),
        relative_rankings: coordination.comparative_rankings
      }

      {:ok, comparison}
    end
  end

  @doc """
  Assess gang threat level based on member assessments.
  """
  def get_gang_threat_assessment(character_ids) do
    with {:ok, coordination} <- coordinate_threat_analysis(character_ids) do
      gang_assessment = %{
        individual_threats: coordination.individual_assessments,
        combined_threat_score: calculate_combined_threat(coordination.individual_assessments),
        gang_composition: analyze_gang_composition(coordination.individual_assessments),
        threat_multipliers: calculate_gang_multipliers(coordination.individual_assessments),
        engagement_recommendation:
          generate_gang_engagement_rec(coordination.individual_assessments)
      }

      {:ok, gang_assessment}
    end
  end

  # Private Functions

  defp calculate_summary_stats(assessments) do
    if map_size(assessments) == 0 do
      %{
        count: 0,
        avg_threat_score: 0,
        min_threat_score: 0,
        max_threat_score: 0,
        threat_level_distribution: %{}
      }
    else
      scores = assessments |> Map.values() |> Enum.map(& &1.overall_score)
      levels = assessments |> Map.values() |> Enum.map(& &1.threat_level) |> Enum.frequencies()

      %{
        count: map_size(assessments),
        avg_threat_score: Float.round(Enum.sum(scores) / length(scores), 2),
        min_threat_score: Enum.min(scores),
        max_threat_score: Enum.max(scores),
        threat_level_distribution: levels
      }
    end
  end

  defp rank_by_threat(assessments) do
    assessments
    |> Enum.map(fn {char_id, assessment} ->
      {char_id, assessment.overall_score, assessment.threat_level}
    end)
    |> Enum.sort_by(fn {_, score, _} -> score end, :desc)
    |> Enum.with_index(1)
    |> Enum.map(fn {{char_id, score, level}, rank} ->
      %{
        character_id: char_id,
        rank: rank,
        threat_score: score,
        threat_level: level
      }
    end)
  end

  defp find_highest_threat(assessments) do
    case Enum.max_by(assessments, fn {_, assessment} -> assessment.overall_score end, fn ->
           nil
         end) do
      nil ->
        nil

      {char_id, assessment} ->
        %{
          character_id: char_id,
          threat_score: assessment.overall_score,
          threat_level: assessment.threat_level,
          primary_threats: assessment.analysis.primary_threats
        }
    end
  end

  defp find_lowest_threat(assessments) do
    case Enum.min_by(assessments, fn {_, assessment} -> assessment.overall_score end, fn ->
           nil
         end) do
      nil ->
        nil

      {char_id, assessment} ->
        %{
          character_id: char_id,
          threat_score: assessment.overall_score,
          threat_level: assessment.threat_level
        }
    end
  end

  defp analyze_threat_distribution(assessments) do
    if map_size(assessments) == 0 do
      %{critical: 0, high: 0, moderate: 0, low: 0, minimal: 0}
    else
      assessments
      |> Map.values()
      |> Enum.map(& &1.threat_level)
      |> Enum.frequencies()
      |> Map.merge(%{critical: 0, high: 0, moderate: 0, low: 0, minimal: 0})
    end
  end

  defp calculate_combined_threat(assessments) do
    if map_size(assessments) == 0 do
      0.0
    else
      scores = assessments |> Map.values() |> Enum.map(& &1.overall_score)

      # Calculate combined threat using different methods
      # Average
      base_threat = Enum.sum(scores) / length(scores)
      # Highest individual
      peak_threat = Enum.max(scores)
      # Numbers advantage
      mass_threat = :math.log10(length(scores) + 1) * 10

      # Weighted combination
      combined = base_threat * 0.5 + peak_threat * 0.3 + mass_threat * 0.2
      Float.round(min(combined, 100), 2)
    end
  end

  defp analyze_gang_composition(assessments) do
    if map_size(assessments) == 0 do
      %{size: 0, threat_levels: %{}, specializations: []}
    else
      threat_levels =
        assessments
        |> Map.values()
        |> Enum.map(& &1.threat_level)
        |> Enum.frequencies()

      # Analyze specializations from aspect scores
      specializations =
        assessments
        |> Map.values()
        |> Enum.flat_map(fn assessment ->
          assessment.aspect_scores
          |> Enum.filter(fn {_, score} -> score > 70 end)
          |> Enum.map(fn {aspect, _} -> aspect end)
        end)
        |> Enum.frequencies()
        |> Enum.sort_by(fn {_, count} -> count end, :desc)
        |> Enum.take(5)

      %{
        size: map_size(assessments),
        threat_levels: threat_levels,
        specializations: specializations,
        composition_rating: assess_composition_quality(threat_levels, specializations)
      }
    end
  end

  defp assess_composition_quality(threat_levels, specializations) do
    # High-threat members
    elite_count = Map.get(threat_levels, :critical, 0) + Map.get(threat_levels, :high, 0)

    # Specialization diversity
    spec_diversity = length(specializations)

    cond do
      elite_count > 2 and spec_diversity > 3 -> :elite_gang
      elite_count > 1 and spec_diversity > 2 -> :dangerous_gang
      elite_count > 0 or spec_diversity > 1 -> :competent_gang
      true -> :basic_gang
    end
  end

  defp calculate_gang_multipliers(assessments) do
    if map_size(assessments) <= 1 do
      %{size_multiplier: 1.0, coordination_multiplier: 1.0, total_multiplier: 1.0}
    else
      gang_size = map_size(assessments)

      # Size multiplier (diminishing returns)
      size_mult =
        cond do
          gang_size >= 50 -> 3.0
          gang_size >= 20 -> 2.5
          gang_size >= 10 -> 2.0
          gang_size >= 5 -> 1.5
          gang_size >= 3 -> 1.2
          true -> 1.0
        end

      # Coordination multiplier based on threat diversity
      avg_threat =
        assessments
        |> Map.values()
        |> Enum.map(& &1.overall_score)
        |> Enum.sum()
        |> Kernel./(gang_size)

      coord_mult = if avg_threat > 60, do: 1.3, else: 1.0

      total_mult = size_mult * coord_mult

      %{
        size_multiplier: Float.round(size_mult, 1),
        coordination_multiplier: Float.round(coord_mult, 1),
        total_multiplier: Float.round(total_mult, 1)
      }
    end
  end

  defp generate_gang_engagement_rec(assessments) do
    if map_size(assessments) == 0 do
      "No threat assessment available"
    else
      gang_size = map_size(assessments)
      combined_threat = calculate_combined_threat(assessments)

      high_threats =
        assessments
        |> Map.values()
        |> Enum.count(fn assessment ->
          assessment.threat_level in [:critical, :high]
        end)

      cond do
        combined_threat > 80 or high_threats > 2 ->
          "Extreme caution required - consider avoiding engagement unless heavily outnumbering"

        combined_threat > 60 or high_threats > 0 ->
          "High risk engagement - ensure numerical advantage and proper intel"

        gang_size > 10 and combined_threat > 40 ->
          "Organized gang detected - coordinate response and use scouts"

        combined_threat > 40 ->
          "Standard caution advised - assess situation before engaging"

        true ->
          "Low to moderate threat - standard engagement protocols"
      end
    end
  end
end
