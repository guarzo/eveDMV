defmodule EveDmv.Contexts.BattleAnalysis.Domain.Detectors.BattleDetector.Assessment do
  @moduledoc """
  Assessment module for evaluating battle detection quality and performance.
  """

  @doc """
  Assess the quality of battle detection results.
  """
  def assess_battle_quality(battles) when is_list(battles) do
    %{
      total_battles: length(battles),
      avg_participants: calculate_avg_participants(battles),
      avg_duration: calculate_avg_duration(battles),
      quality_score: calculate_quality_score(battles)
    }
  end

  def assess_battle_quality(_), do: %{error: :invalid_input}

  # Private functions

  defp calculate_avg_participants([]), do: 0

  defp calculate_avg_participants(battles) do
    total_participants =
      battles
      |> Enum.map(fn battle ->
        battle
        |> Map.get(:participants, [])
        |> length()
      end)
      |> Enum.sum()

    round(total_participants / length(battles))
  end

  defp calculate_avg_duration([]), do: 0

  defp calculate_avg_duration(battles) do
    total_duration =
      battles
      |> Enum.map(&Map.get(&1, :duration_minutes, 0))
      |> Enum.sum()

    round(total_duration / length(battles))
  end

  defp calculate_quality_score([]), do: 0.0

  defp calculate_quality_score(battles) do
    scores = Enum.map(battles, &calculate_individual_battle_score/1)

    avg_score = Enum.sum(scores) / length(scores)
    Float.round(avg_score, 1)
  end

  defp calculate_individual_battle_score(battle) do
    participants = Map.get(battle, :participants, [])
    duration = Map.get(battle, :duration_minutes, 0)

    # Base score factors
    participant_score = min(50, length(participants) * 2)
    duration_score = min(30, duration)
    completeness_score = if Map.has_key?(battle, :metadata), do: 20, else: 0

    participant_score + duration_score + completeness_score
  end
end
