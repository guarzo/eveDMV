defmodule EveDmv.Intelligence.Analyzers.FleetAssetManager.ReadinessAnalyzer do
  @moduledoc """
  Asset readiness analysis and deployment assessment module.

  Analyzes fleet readiness for immediate deployment based on asset availability,
  ship requirements, and critical role coverage.
  """

  @doc """
  Analyze asset readiness for immediate fleet deployment.

  This function evaluates how ready a fleet is for immediate deployment
  based on asset availability, ship requirements, and pilot assignments.

  ## Parameters

  - `ship_requirements` - Ship requirements from build_ship_requirements/2
  - `asset_availability` - Asset availability data from get_asset_availability/2

  ## Returns

  Readiness analysis map with:
  - `:overall_readiness` - Overall readiness percentage (0-100)
  - `:missing_ships` - List of ships that are short
  - `:surplus_ships` - List of ships with excess availability
  - `:deployment_blockers` - Critical missing assets that prevent deployment
  """
  def analyze_asset_readiness(ship_requirements, asset_availability) do
    # Extract ship availability data
    _ship_availability = Map.get(asset_availability, "ship_availability", %{})

    # Calculate readiness for each ship type
    ship_readiness =
      Enum.map(ship_requirements, fn {_type_id, ship_data} ->
        ship_name = Map.get(ship_data, "ship_name", "Unknown")
        needed = Map.get(ship_data, "quantity_needed", 1)
        available = Map.get(ship_data, "quantity_available", 0)

        readiness_ratio = if needed > 0, do: min(1.0, available / needed), else: 1.0

        %{
          ship_name: ship_name,
          needed: needed,
          available: available,
          readiness_ratio: readiness_ratio,
          is_critical: Map.get(ship_data, "role") in ["logistics", "fc"]
        }
      end)

    # Calculate overall readiness
    overall_readiness = calculate_overall_readiness(ship_readiness)

    # Identify missing ships
    missing_ships =
      Enum.map(
        Enum.filter(ship_readiness, fn ship -> ship.available < ship.needed end),
        & &1.ship_name
      )

    # Identify surplus ships
    surplus_ships =
      Enum.map(
        Enum.filter(ship_readiness, fn ship -> ship.available > ship.needed end),
        & &1.ship_name
      )

    # Identify deployment blockers (critical missing ships)
    deployment_blockers =
      Enum.map(
        Enum.filter(ship_readiness, fn ship ->
          ship.is_critical and ship.available < ship.needed
        end),
        & &1.ship_name
      )

    %{
      overall_readiness: overall_readiness,
      missing_ships: missing_ships,
      surplus_ships: surplus_ships,
      deployment_blockers: deployment_blockers,
      readiness_details: ship_readiness,
      deployment_status: determine_deployment_status(overall_readiness, deployment_blockers)
    }
  end

  @doc """
  Calculate readiness score for a specific role.
  """
  def calculate_role_readiness(ship_requirements, role) do
    role_ships =
      Enum.filter(ship_requirements, fn {_type_id, ship_data} ->
        Map.get(ship_data, "role") == role
      end)

    if role_ships == [] do
      %{readiness: 100, status: "not_required"}
    else
      readiness_scores =
        Enum.map(role_ships, fn {_type_id, ship_data} ->
          needed = Map.get(ship_data, "quantity_needed", 1)
          available = Map.get(ship_data, "quantity_available", 0)
          if needed > 0, do: min(1.0, available / needed), else: 1.0
        end)

      avg_readiness = Enum.sum(readiness_scores) / length(readiness_scores)

      %{
        readiness: round(avg_readiness * 100),
        status: determine_role_status(avg_readiness),
        ships_count: length(role_ships)
      }
    end
  end

  @doc """
  Generate readiness report for all roles.
  """
  def generate_readiness_report(ship_requirements) do
    roles = get_unique_roles(ship_requirements)

    role_readiness_list =
      Enum.map(roles, fn role ->
        readiness = calculate_role_readiness(ship_requirements, role)
        {role, readiness}
      end)

    role_readiness = Map.new(role_readiness_list)

    critical_roles = ["logistics", "fc"]

    critical_readiness =
      Enum.filter(role_readiness, fn {role, _} -> role in critical_roles end)

    %{
      role_readiness: role_readiness,
      critical_roles_status: assess_critical_roles(critical_readiness),
      overall_assessment: assess_overall_fleet_readiness(role_readiness),
      recommendations: generate_readiness_recommendations(role_readiness)
    }
  end

  @doc """
  Check if fleet meets minimum deployment requirements.
  """
  def meets_deployment_requirements?(ship_requirements, min_requirements \\ %{}) do
    default_minimums = %{
      "logistics" => 1,
      "dps" => 3,
      "tackle" => 1
    }

    requirements = Map.merge(default_minimums, min_requirements)

    actual_counts =
      Enum.reduce(ship_requirements, %{}, fn {_type_id, ship_data}, acc ->
        role = Map.get(ship_data, "role", "unknown")
        available = Map.get(ship_data, "quantity_available", 0)
        Map.update(acc, role, available, &(&1 + available))
      end)

    Enum.all?(requirements, fn {role, min_count} ->
      Map.get(actual_counts, role, 0) >= min_count
    end)
  end

  @doc """
  Calculate time to readiness based on current gaps.
  """
  def calculate_time_to_readiness(ship_requirements, acquisition_rate \\ 1) do
    missing_ships_count =
      Enum.reduce(ship_requirements, 0, fn {_type_id, ship_data}, acc ->
        needed = Map.get(ship_data, "quantity_needed", 1)
        available = Map.get(ship_data, "quantity_available", 0)
        shortage = max(0, needed - available)
        acc + shortage
      end)

    if missing_ships_count == 0 do
      %{time_days: 0, status: "ready_now"}
    else
      estimated_days = ceil(missing_ships_count / acquisition_rate)

      %{
        time_days: estimated_days,
        status: "acquisition_needed",
        missing_count: missing_ships_count
      }
    end
  end

  # Private functions

  defp calculate_overall_readiness(ship_readiness) do
    if length(ship_readiness) > 0 do
      avg_readiness =
        Enum.sum(Enum.map(ship_readiness, & &1.readiness_ratio)) / length(ship_readiness)

      round(avg_readiness * 100)
    else
      0
    end
  end

  defp determine_deployment_status(overall_readiness, deployment_blockers) do
    cond do
      length(deployment_blockers) > 0 -> "blocked"
      overall_readiness >= 90 -> "ready"
      overall_readiness >= 70 -> "mostly_ready"
      overall_readiness >= 50 -> "partially_ready"
      true -> "not_ready"
    end
  end

  defp determine_role_status(readiness) when readiness >= 0.9, do: "excellent"
  defp determine_role_status(readiness) when readiness >= 0.7, do: "good"
  defp determine_role_status(readiness) when readiness >= 0.5, do: "adequate"
  defp determine_role_status(readiness) when readiness >= 0.3, do: "poor"
  defp determine_role_status(_), do: "critical"

  defp get_unique_roles(ship_requirements) do
    roles_list =
      Enum.map(ship_requirements, fn {_type_id, ship_data} ->
        Map.get(ship_data, "role", "unknown")
      end)

    Enum.uniq(roles_list)
  end

  defp assess_critical_roles(critical_readiness) do
    if critical_readiness == [] do
      "no_critical_roles"
    else
      statuses = Enum.map(critical_readiness, fn {_role, data} -> data.status end)

      cond do
        Enum.all?(statuses, &(&1 in ["excellent", "good"])) -> "all_good"
        Enum.any?(statuses, &(&1 == "critical")) -> "critical_issues"
        true -> "needs_attention"
      end
    end
  end

  defp assess_overall_fleet_readiness(role_readiness) do
    if role_readiness == %{} do
      "no_data"
    else
      readiness_scores = Enum.map(role_readiness, fn {_role, data} -> data.readiness end)
      avg_readiness = Enum.sum(readiness_scores) / length(readiness_scores)

      cond do
        avg_readiness >= 90 -> "excellent"
        avg_readiness >= 75 -> "good"
        avg_readiness >= 60 -> "adequate"
        avg_readiness >= 40 -> "poor"
        true -> "critical"
      end
    end
  end

  defp generate_readiness_recommendations(role_readiness) do
    # Check for critical role issues
    critical_role_recommendations =
      if has_critical_role_issues?(role_readiness) do
        ["Prioritize acquiring logistics and FC ships"]
      else
        []
      end

    # Check for low DPS
    dps_readiness = get_in(role_readiness, ["dps", :readiness]) || 100

    dps_recommendations =
      if dps_readiness < 70 do
        ["Increase DPS ship availability for fleet effectiveness" | critical_role_recommendations]
      else
        critical_role_recommendations
      end

    # Check for missing tackle
    tackle_readiness = get_in(role_readiness, ["tackle", :readiness]) || 100

    final_recommendations =
      if tackle_readiness < 60 do
        ["Acquire more tackle ships for fleet mobility" | dps_recommendations]
      else
        dps_recommendations
      end

    if final_recommendations == [] do
      ["Fleet readiness is good - no immediate actions needed"]
    else
      final_recommendations
    end
  end

  defp has_critical_role_issues?(role_readiness) do
    critical_roles = ["logistics", "fc"]

    Enum.any?(critical_roles, fn role ->
      status = get_in(role_readiness, [role, :status])
      status in ["poor", "critical"]
    end)
  end
end
