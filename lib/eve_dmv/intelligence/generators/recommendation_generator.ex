defmodule EveDmv.Intelligence.Generators.RecommendationGenerator do
  @moduledoc """
  Generates activity-based recommendations for member engagement and retention.

  Provides comprehensive recommendation analysis based on activity trends,
  engagement metrics, fleet participation, and communication patterns.
  """

  @doc """
  Generate comprehensive activity recommendations based on analysis data.

  Takes analysis data and returns categorized recommendations for immediate actions,
  engagement strategies, retention initiatives, and long-term goals.
  """
  def generate_activity_recommendations(analysis_data) when is_map(analysis_data) do
    activity_trends = Map.get(analysis_data, :activity_trends, %{})
    engagement_metrics = Map.get(analysis_data, :engagement_metrics, %{})
    fleet_participation = Map.get(analysis_data, :fleet_participation, %{})
    communication_health = Map.get(analysis_data, :communication_health, :moderate)
    retention_risks = Map.get(analysis_data, :retention_risks, %{})

    recommendations = []

    # Activity trend recommendations
    activity_recommendations =
      case Map.get(activity_trends, :trend_direction) do
        :decreasing ->
          ["Implement engagement initiatives to reverse declining activity" | recommendations]

        :volatile ->
          ["Focus on activity consistency and member retention" | recommendations]

        _ ->
          recommendations
      end

    # Engagement recommendations
    overall_engagement = Map.get(engagement_metrics, :overall_engagement_score, 0)

    engagement_recommendations =
      if overall_engagement < 50 do
        ["Plan more engaging fleet operations and events" | activity_recommendations]
      else
        activity_recommendations
      end

    # Fleet participation recommendations
    avg_participation = Map.get(fleet_participation, :avg_participation_rate, 0.0)

    fleet_recommendations =
      if avg_participation < 0.5 do
        ["Improve fleet scheduling to increase participation" | engagement_recommendations]
      else
        engagement_recommendations
      end

    # Communication recommendations
    communication_recommendations =
      case communication_health do
        :poor ->
          ["Enhance communication channels and engagement" | fleet_recommendations]

        :moderate ->
          ["Monitor communication patterns for improvement opportunities" | fleet_recommendations]

        _ ->
          fleet_recommendations
      end

    # Retention risk recommendations
    high_risk_count = length(Map.get(retention_risks, :high_risk_members, []))

    final_recommendations =
      if high_risk_count > 0 do
        [
          "Immediate attention needed for #{high_risk_count} at-risk members"
          | communication_recommendations
        ]
      else
        communication_recommendations
      end

    %{
      immediate_actions: Enum.take(final_recommendations, 2),
      engagement_strategies: filter_engagement_recommendations(final_recommendations),
      retention_initiatives: filter_leadership_recommendations(final_recommendations),
      long_term_goals: filter_operational_recommendations(final_recommendations)
    }
  end

  # Private helper functions

  defp filter_engagement_recommendations(recommendations) do
    engagement_keywords = ["engagement", "events", "engaging"]

    Enum.filter(recommendations, fn rec ->
      Enum.any?(engagement_keywords, &String.contains?(rec, &1))
    end)
  end

  defp filter_leadership_recommendations(recommendations) do
    leadership_keywords = ["attention", "leadership", "contact"]

    Enum.filter(recommendations, fn rec ->
      Enum.any?(leadership_keywords, &String.contains?(rec, &1))
    end)
  end

  defp filter_operational_recommendations(recommendations) do
    operational_keywords = ["fleet", "scheduling", "operations", "communication"]

    Enum.filter(recommendations, fn rec ->
      Enum.any?(operational_keywords, &String.contains?(rec, &1))
    end)
  end
end
