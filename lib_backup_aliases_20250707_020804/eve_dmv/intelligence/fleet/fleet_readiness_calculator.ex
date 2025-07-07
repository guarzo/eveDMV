defmodule EveDmv.Intelligence.Fleet.FleetReadinessCalculator do
  @moduledoc """
  Fleet readiness calculation module for wormhole operations.

  Provides fleet readiness metrics including skill readiness assessment,
  pilot availability analysis, and form-up time estimation.
  """

  @doc """
  Calculate comprehensive fleet readiness metrics.

  Takes pilot assignments and skill analysis to determine overall readiness.
  """
  def calculate_readiness_metrics(pilot_assignments, skill_analysis) do
    total_assigned = map_size(pilot_assignments)

    # Calculate skill readiness average
    avg_skill_readiness =
      Enum.map(pilot_assignments, fn {_id, pilot} -> pilot["skill_readiness"] || 0.0 end)
      |> Enum.sum()
      |> case do
        0 -> 0.0
        sum -> sum / total_assigned
      end

    # Factor in critical gaps
    critical_gaps = length(skill_analysis["critical_gaps"] || [])
    gap_penalty = min(50, critical_gaps * 15)

    readiness_percent = round(max(0, avg_skill_readiness * 100 - gap_penalty))

    %{
      readiness_percent: readiness_percent,
      pilots_available: total_assigned,
      # This would be calculated from doctrine requirements
      pilots_required: total_assigned,
      estimated_form_up_time: estimate_form_up_time(readiness_percent, total_assigned)
    }
  end

  @doc """
  Estimate time to form up the fleet based on readiness and size.

  Returns estimated form-up time in minutes.
  """
  def estimate_form_up_time(readiness_percent, pilot_count) do
    # Estimate time to form up the fleet
    # Base 15 minutes
    base_time = 15
    readiness_modifier = (100 - readiness_percent) / 10
    size_modifier = pilot_count / 3

    round(base_time + readiness_modifier + size_modifier)
  end
end
