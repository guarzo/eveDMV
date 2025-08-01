defmodule EveDmv.Contexts.Combat.Core.ParticipantAnalyzer.ExperienceAnalyzer do
  @moduledoc """
  Analyzes participant experience levels based on combat patterns and historical data.
  """

  @doc """
  Analyze and estimate experience level of a participant.
  """
  def analyze_experience(participant) do
    %{
      level: determine_experience_level(participant),
      score: calculate_experience_score(participant),
      indicators: identify_experience_indicators(participant)
    }
  end

  defp determine_experience_level(participant) do
    score = calculate_experience_score(participant)

    cond do
      score >= 80 -> :veteran
      score >= 60 -> :experienced
      score >= 40 -> :intermediate
      score >= 20 -> :novice
      true -> :rookie
    end
  end

  defp calculate_experience_score(participant) do
    # Weight different factors that indicate experience
    combat_effectiveness = calculate_combat_effectiveness(participant) * 0.3
    survival_skills = calculate_survival_skills(participant) * 0.2
    tactical_awareness = calculate_tactical_awareness(participant) * 0.2
    ship_progression = calculate_ship_progression(participant) * 0.15
    engagement_quality = calculate_engagement_quality(participant) * 0.15

    combat_effectiveness + survival_skills + tactical_awareness +
      ship_progression + engagement_quality
  end

  defp calculate_combat_effectiveness(participant) do
    # Experienced pilots have better K/D ratios and damage efficiency
    kills = participant[:kills] || 0
    deaths = max(participant[:deaths] || 0, 1)
    kd_ratio = kills / deaths

    damage_ratio = participant[:efficiency_rating] || 0

    # Normalize to 0-100 scale
    kd_score = min(kd_ratio * 20, 50)
    damage_score = min(damage_ratio, 50)

    kd_score + damage_score
  end

  defp calculate_survival_skills(participant) do
    # Experienced pilots know when to disengage
    case participant[:survival_time] do
      :survived ->
        # Survived while being active is good
        if participant[:appearances] > 5, do: 100, else: 70

      time when is_number(time) ->
        # Longer survival time is better
        min(time * 2, 100)

      _ ->
        0
    end
  end

  defp calculate_tactical_awareness(participant) do
    # Look for signs of tactical thinking
    initial_score = 0

    # Target selection (final blow ratio)
    final_blow_ratio =
      if participant[:kills] > 0 do
        participant[:final_blows] / participant[:kills]
      else
        0
      end

    score_with_targeting = initial_score + final_blow_ratio * 30

    # Engagement timing (not always first to die)
    score_with_survival =
      if participant[:deaths] == 0 || participant[:survival_time] == :survived do
        score_with_targeting + 40
      else
        score_with_targeting
      end

    # Fleet participation vs solo
    final_score =
      if participant[:appearances] > 10 do
        score_with_survival + 30
      else
        score_with_survival
      end

    min(final_score, 100)
  end

  defp calculate_ship_progression(participant) do
    # Using appropriate ships for role shows experience
    ships_used = participant[:ships_used] || []

    cond do
      # Using specialized ships
      length(ships_used) > 1 -> 80
      # Using T2/T3 ships (simplified check)
      Enum.any?(ships_used, &(&1 > 10_000)) -> 60
      # Basic ships
      true -> 20
    end
  end

  defp calculate_engagement_quality(participant) do
    # Quality over quantity
    if participant[:kills] > 0 do
      # High damage per engagement
      avg_damage = participant[:total_damage_done] / participant[:appearances]

      cond do
        avg_damage > 50_000 -> 100
        avg_damage > 20_000 -> 70
        avg_damage > 10_000 -> 40
        true -> 20
      end
    else
      10
    end
  end

  defp identify_experience_indicators(participant) do
    initial_indicators = []

    # Positive indicators
    indicators_with_kd =
      if participant[:kills] > participant[:deaths] * 2 do
        ["positive_kd_ratio" | initial_indicators]
      else
        initial_indicators
      end

    indicators_with_survival =
      if participant[:survival_time] == :survived && participant[:appearances] > 5 do
        ["good_survival_instincts" | indicators_with_kd]
      else
        indicators_with_kd
      end

    indicators_with_efficiency =
      if participant[:efficiency_rating] > 70 do
        ["high_damage_efficiency" | indicators_with_survival]
      else
        indicators_with_survival
      end

    indicators_with_versatility =
      if length(participant[:ships_used] || []) > 2 do
        ["ship_versatility" | indicators_with_efficiency]
      else
        indicators_with_efficiency
      end

    # Negative indicators
    final_indicators =
      if participant[:deaths] > participant[:kills] * 2 do
        ["poor_engagement_choices" | indicators_with_versatility]
      else
        indicators_with_versatility
      end

    final_indicators
  end
end
