defmodule EveDmv.Intelligence.Generators.RecruitmentInsightGenerator do
  @moduledoc """
  Generates recruitment insights based on member activity analysis.

  Provides comprehensive recruitment analysis including priority assessment,
  target member profiles, and capacity evaluation for corporation growth.
  """

  @doc """
  Generate recruitment insights from activity data.

  Analyzes member count, engagement levels, and retention risks to provide
  actionable recruitment recommendations and priority assessments.
  """
  def generate_recruitment_insights(activity_data) do
    member_count = Map.get(activity_data, :total_members, 0)
    avg_engagement = Map.get(activity_data, :avg_engagement_score, 0)
    retention_risk_count = Map.get(activity_data, :high_risk_count, 0)

    # Generate insights based on the data
    initial_insights = []

    insights_with_members =
      if member_count < 20 do
        ["Corporation needs more active members" | initial_insights]
      else
        initial_insights
      end

    insights_with_engagement =
      if avg_engagement < 50 do
        ["Member engagement is below healthy levels" | insights_with_members]
      else
        insights_with_members
      end

    final_insights =
      if retention_risk_count > member_count * 0.2 do
        ["High number of members at retention risk" | insights_with_engagement]
      else
        insights_with_engagement
      end

    recruitment_priority =
      cond do
        member_count < 10 -> "critical"
        member_count < 20 -> "high"
        avg_engagement < 40 -> "medium"
        true -> "low"
      end

    recommended_recruit_count = max(0, 25 - member_count)
    # Calculate rate as percentage of current membership
    recommended_recruitment_rate =
      if member_count > 0,
        do: recommended_recruit_count / member_count,
        else: 0.25

    target_profiles = determine_target_member_profiles(activity_data)
    priorities = determine_recruitment_priorities(activity_data, recruitment_priority)
    capacity = assess_recruitment_capacity(activity_data, member_count)

    %{
      recruitment_priority: recruitment_priority,
      insights: final_insights,
      recommended_recruit_count: recommended_recruit_count,
      recommended_recruitment_rate: Float.round(recommended_recruitment_rate, 2),
      focus_areas: determine_recruitment_focus_areas(activity_data),
      target_member_profiles: target_profiles,
      recruitment_priorities: priorities,
      capacity_assessment: capacity
    }
  end

  # Private helper functions

  defp determine_target_member_profiles(activity_data) do
    avg_engagement = Map.get(activity_data, :avg_engagement_score, 0)

    base_profiles = ["Active PvP pilots", "Team players"]

    profiles =
      if avg_engagement < 50 do
        ["Experienced players with leadership potential" | base_profiles]
      else
        base_profiles
      end

    profiles
  end

  defp determine_recruitment_priorities(activity_data, recruitment_priority) do
    base_priorities = [recruitment_priority]

    member_count = Map.get(activity_data, :total_members, 0)
    trend_direction = get_in(activity_data, [:activity_trends, :trend_direction])

    priorities =
      cond do
        trend_direction == :decreasing -> ["urgent", "immediate" | base_priorities]
        member_count < 15 -> ["active_recruitment" | base_priorities]
        true -> base_priorities
      end

    priorities
  end

  defp determine_recruitment_focus_areas(activity_data) do
    areas = []

    avg_engagement = Map.get(activity_data, :avg_engagement_score, 0)
    member_count = Map.get(activity_data, :total_members, 0)

    areas_with_engagement =
      if avg_engagement < 50, do: ["engagement_improvement" | areas], else: areas

    final_areas =
      if member_count < 15,
        do: ["active_recruitment" | areas_with_engagement],
        else: areas_with_engagement

    if Enum.empty?(final_areas), do: ["maintain_current"], else: final_areas
  end

  defp assess_recruitment_capacity(_activity_data, member_count) do
    capacity_score = min(100, member_count * 2)

    %{
      current_capacity: capacity_score,
      optimal_size: 30,
      growth_potential: max(0, 30 - member_count),
      resource_availability: if(member_count < 20, do: "high", else: "medium")
    }
  end
end
