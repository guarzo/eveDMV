defmodule EveDmv.Intelligence.Fleet.FleetEffectivenessCalculator do
  @moduledoc """
  Fleet effectiveness calculation module for wormhole operations.

  Provides comprehensive effectiveness metrics including DPS, tank, mobility,
  and utility ratings based on pilot assignments and fleet composition.
  """

  @doc """
  Calculate overall fleet effectiveness based on composition and pilot assignments.

  Returns a map with detailed effectiveness ratings.
  """
  def calculate_fleet_effectiveness(composition, pilot_assignments) do
    # Calculate various effectiveness metrics
    pilot_count = map_size(pilot_assignments)

    %{
      "dps_rating" => calculate_dps_rating(composition, pilot_assignments),
      "tank_rating" => calculate_tank_rating(composition, pilot_assignments),
      "mobility_rating" => calculate_mobility_rating(composition, pilot_assignments),
      "utility_rating" => calculate_utility_rating(composition, pilot_assignments),
      "overall_rating" => calculate_overall_effectiveness(pilot_count, composition.optimal_pilots)
    }
  end

  @doc """
  Calculate DPS effectiveness based on ship composition and pilot assignments.
  """
  def calculate_dps_rating(composition, pilot_assignments) do
    # Calculate DPS effectiveness based on ship composition
    dps_pilots =
      Enum.count(pilot_assignments, fn {_id, pilot_data} ->
        pilot_data["assigned_role"] in ["dps", "fleet_commander"]
      end)

    min(1.0, dps_pilots / max(1, composition.optimal_pilots * 0.6))
  end

  @doc """
  Calculate tank/survivability rating based on logistics coverage.
  """
  def calculate_tank_rating(composition, pilot_assignments) do
    # Calculate tank/survivability rating
    logi_pilots =
      Enum.count(pilot_assignments, fn {_id, pilot_data} ->
        pilot_data["assigned_role"] == "logistics"
      end)

    min(1.0, logi_pilots / max(1, composition.optimal_pilots * 0.25))
  end

  @doc """
  Calculate mobility/tackle rating based on tackle pilot coverage.
  """
  def calculate_mobility_rating(composition, pilot_assignments) do
    # Calculate mobility/tackle rating
    tackle_pilots =
      Enum.count(pilot_assignments, fn {_id, pilot_data} ->
        pilot_data["assigned_role"] == "tackle"
      end)

    min(1.0, tackle_pilots / max(1, composition.optimal_pilots * 0.2))
  end

  @doc """
  Calculate utility/EWAR rating based on support pilot coverage.
  """
  def calculate_utility_rating(composition, pilot_assignments) do
    # Calculate utility/EWAR rating
    utility_pilots =
      Enum.count(pilot_assignments, fn {_id, pilot_data} ->
        pilot_data["assigned_role"] in ["ewar", "support"]
      end)

    # Utility is optional, so base rating is higher
    0.7 + min(0.3, utility_pilots / max(1, composition.optimal_pilots * 0.15))
  end

  @doc """
  Calculate overall effectiveness based on pilot fill rate and role balance.
  """
  def calculate_overall_effectiveness(current_pilots, optimal_pilots) do
    # Overall effectiveness based on pilot fill rate and role balance
    fill_rate = current_pilots / max(1, optimal_pilots)
    effectiveness_from_fill_rate(fill_rate)
  end

  @doc """
  Convert pilot fill rate to effectiveness score.
  """
  def effectiveness_from_fill_rate(fill_rate) when fill_rate >= 1.0, do: 0.9
  def effectiveness_from_fill_rate(fill_rate) when fill_rate >= 0.8, do: 0.75
  def effectiveness_from_fill_rate(fill_rate) when fill_rate >= 0.6, do: 0.6
  def effectiveness_from_fill_rate(fill_rate) when fill_rate >= 0.4, do: 0.4
  def effectiveness_from_fill_rate(_fill_rate), do: 0.2
end
