defmodule EveDmv.Intelligence.Calculators.FleetParticipationCalculator do
  @moduledoc """
  Fleet participation calculation module for member activity analysis.

  Provides comprehensive fleet participation metrics including participation rates,
  high-performer identification, leadership distribution analysis, and fleet readiness scoring.
  """

  @doc """
  Calculate comprehensive fleet participation metrics.

  Takes fleet data and returns detailed participation analysis including
  participation rates, leadership distribution, and readiness scores.
  """
  def calculate_fleet_participation_metrics(fleet_data) when is_list(fleet_data) do
    if Enum.empty?(fleet_data) do
      %{
        avg_participation_rate: 0.0,
        high_participation_members: [],
        leadership_distribution: %{},
        fleet_readiness_score: 0
      }
    else
      participation_rates =
        Enum.map(fleet_data, fn member ->
          attended = Map.get(member, :fleet_ops_attended, 0)
          available = Map.get(member, :fleet_ops_available, 1)
          attended / max(1, available)
        end)

      durations = Enum.map(fleet_data, &Map.get(&1, :avg_fleet_duration, 0))
      leadership_roles = Enum.sum(Enum.map(fleet_data, &Map.get(&1, :leadership_roles, 0)))

      avg_participation =
        if length(participation_rates) > 0,
          do: Enum.sum(participation_rates) / length(participation_rates),
          else: 0.0

      _avg_duration =
        if length(durations) > 0, do: Enum.sum(durations) / length(durations), else: 0.0

      leadership_participation = leadership_roles / max(1, length(fleet_data))

      # Identify high participation members (>80% participation)
      high_participation_members =
        fleet_data
        |> Enum.zip(participation_rates)
        |> Enum.filter(fn {_member, rate} -> rate > 0.8 end)
        |> Enum.map(fn {member, _rate} -> member end)

      # Leadership distribution
      leadership_distribution = %{
        "fcs" => Enum.count(fleet_data, &(Map.get(&1, :role) == "fc")),
        "scouts" => Enum.count(fleet_data, &(Map.get(&1, :role) == "scout")),
        "logistics" => Enum.count(fleet_data, &(Map.get(&1, :role) == "logistics"))
      }

      # Fleet readiness score based on participation and leadership
      fleet_readiness_score = round(avg_participation * 100 + leadership_participation * 10)

      %{
        avg_participation_rate: Float.round(avg_participation, 3),
        high_participation_members: high_participation_members,
        leadership_distribution: leadership_distribution,
        fleet_readiness_score: min(100, fleet_readiness_score)
      }
    end
  end
end
