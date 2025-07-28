defmodule EveDmv.Contexts.FleetOperations.Domain.DoctrineManager do
  @moduledoc """
  Domain service for managing fleet doctrines.

  Handles creation, validation, and management of fleet doctrines,
  including compliance checking and doctrine optimization.

  Converted from GenServer to simple module for stateless operations.
  """

  use EveDmv.ErrorHandler

  alias EveDmv.StaticData

  require Logger

  # Note: Doctrine types and mass categories are defined inline where needed

  # Public API

  @doc """
  Create a new fleet doctrine.

  In a real implementation, this would persist to database.
  Currently returns a mock doctrine for development.
  """
  def create_doctrine(doctrine_data) do
    doctrine_id = generate_doctrine_id()

    doctrine = %{
      id: doctrine_id,
      name: doctrine_data.name,
      description: doctrine_data[:description] || "",
      doctrine_type: doctrine_data[:doctrine_type] || :roam,
      ship_requirements: doctrine_data.ship_requirements,
      role_requirements: doctrine_data.role_requirements,
      optional_ships: doctrine_data[:optional_ships] || [],
      mass_limits: doctrine_data[:mass_limits] || %{},
      mass_category: determine_mass_category(doctrine_data),
      corporation_id: doctrine_data[:corporation_id],
      is_active: doctrine_data[:is_active] || true,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      created_by: doctrine_data[:created_by],
      usage_count: 0,
      last_used_at: nil
    }

    Logger.info("Created doctrine: #{doctrine.name} (#{doctrine_id})")

    # TODO: Persist to database
    {:ok, doctrine}
  end

  @doc """
  Update an existing fleet doctrine.

  In a real implementation, this would update the database.
  """
  def update_doctrine(doctrine_id, updates) do
    # TODO: Load from database
    # For now, return error as we don't have persistence
    Logger.info("Attempted to update doctrine: #{doctrine_id}")
    {:error, :not_implemented}
  end

  @doc """
  Get a doctrine by ID.

  In a real implementation, this would query the database.
  """
  def get_doctrine(doctrine_id) do
    # TODO: Load from database
    Logger.info("Attempted to get doctrine: #{doctrine_id}")
    {:error, :not_implemented}
  end

  @doc """
  Get a doctrine by name.

  In a real implementation, this would query the database.
  """
  def get_doctrine_by_name(doctrine_name) do
    # TODO: Load from database
    Logger.info("Attempted to get doctrine by name: #{doctrine_name}")
    {:error, :not_implemented}
  end

  @doc """
  List doctrines with filtering options.

  In a real implementation, this would query the database.
  """
  def list_doctrines(opts \\ []) do
    # TODO: Query database with filters
    Logger.info("Attempted to list doctrines with opts: #{inspect(opts)}")
    {:ok, []}
  end

  @doc """
  Check fleet compliance against a doctrine.
  """
  def check_compliance(fleet_data, doctrine) do
    calculate_doctrine_compliance(fleet_data, doctrine)
  end

  @doc """
  Validate a fleet composition against a doctrine.
  """
  def validate_fleet_composition(fleet_data, doctrine) do
    perform_fleet_validation(fleet_data, doctrine)
  end

  @doc """
  Get doctrine statistics and usage metrics.

  In a real implementation, this would query aggregated data from the database.
  """
  def get_doctrine_statistics(doctrine_id) do
    # TODO: Query statistics from database
    Logger.info("Attempted to get doctrine statistics: #{doctrine_id}")
    {:error, :not_implemented}
  end

  # Private functions

  defp generate_doctrine_id do
    "doctrine_#{System.unique_integer([:positive])}_#{:os.system_time(:millisecond)}"
  end

  defp determine_mass_category(doctrine_data) do
    ship_requirements = doctrine_data[:ship_requirements] || %{}

    # Calculate estimated mass for typical doctrine composition
    estimated_mass =
      Enum.sum(
        Enum.map(ship_requirements, fn {ship_type_id, requirement} ->
          ship_mass = get_ship_mass(ship_type_id)
          ship_mass * requirement[:min_count]
        end)
      )

    cond do
      # < 100M kg
      estimated_mass < 100_000_000 -> :light
      # < 500M kg
      estimated_mass < 500_000_000 -> :medium
      # < 1.5B kg
      estimated_mass < 1_500_000_000 -> :heavy
      # >= 1.5B kg
      true -> :capital
    end
  end

  defp get_ship_class_for_type(ship_type_id) do
    # Real ship class determination using static data
    case StaticData.get_ship_class(ship_type_id) do
      :frigate -> :frigate
      :assault_frigate -> :frigate
      :covert_ops -> :frigate
      :interceptor -> :frigate
      :interdictor -> :frigate
      :electronic_attack_frigate -> :frigate
      :logistics_frigate -> :frigate
      :destroyer -> :destroyer
      :tactical_destroyer -> :destroyer
      :command_destroyer -> :destroyer
      :cruiser -> :cruiser
      :heavy_assault_cruiser -> :cruiser
      :heavy_interdictor -> :cruiser
      :force_recon -> :cruiser
      :combat_recon -> :cruiser
      :logistics_cruiser -> :cruiser
      :strategic_cruiser -> :cruiser
      :battlecruiser -> :battlecruiser
      :attack_battlecruiser -> :battlecruiser
      :battleship -> :battleship
      :marauder -> :battleship
      :black_ops -> :battleship
      :dreadnought -> :capital
      :carrier -> :capital
      :supercarrier -> :capital
      :titan -> :capital
      :force_auxiliary -> :capital
      # Default for unknown or special ships
      _ -> :frigate
    end
  end

  defp get_estimated_ship_mass(ship_class) do
    # Use average mass values for ship classes based on static data
    # In production, this could be cached for performance
    case ship_class do
      # Average T1/T2 frigate mass
      :frigate -> 1_500_000
      # Average destroyer mass
      :destroyer -> 2_000_000
      # Average cruiser mass
      :cruiser -> 12_000_000
      # Average battlecruiser mass
      :battlecruiser -> 60_000_000
      # Average battleship mass
      :battleship -> 110_000_000
      # Average capital mass
      :capital -> 1_300_000_000
    end
  end

  @doc """
  Get actual ship mass from static data.
  Falls back to estimated class mass if not found.
  """
  def get_ship_mass(ship_type_id) when is_integer(ship_type_id) do
    case StaticData.get_ship_mass(ship_type_id) do
      {:ok, mass} ->
        round(mass)

      {:error, _} ->
        ship_class = get_ship_class_for_type(ship_type_id)
        get_estimated_ship_mass(ship_class)
    end
  end

  defp calculate_doctrine_compliance(fleet_data, doctrine) do
    participants = fleet_data.participants
    ship_requirements = doctrine.ship_requirements
    role_requirements = doctrine.role_requirements

    # Check ship requirements compliance
    ship_compliance = calculate_ship_compliance(participants, ship_requirements)

    # Check role requirements compliance
    role_compliance = calculate_role_compliance(participants, role_requirements)

    # Calculate overall compliance score
    overall_compliance = (ship_compliance.score + role_compliance.score) / 2

    # Determine compliance level
    compliance_level = determine_compliance_level(overall_compliance)

    # Generate compliance issues
    compliance_issues = ship_compliance.issues ++ role_compliance.issues

    # Generate recommendations
    recommendations = generate_compliance_recommendations(ship_compliance, role_compliance)

    compliance_result = %{
      compliance_score: Float.round(overall_compliance, 3),
      compliance_level: compliance_level,
      ship_compliance: ship_compliance,
      role_compliance: role_compliance,
      issues: compliance_issues,
      recommendations: recommendations,
      participants_count: length(participants),
      doctrine_name: doctrine.name
    }

    {:ok, compliance_result}
  end

  defp calculate_ship_compliance(participants, ship_requirements) do
    # Count actual ships in fleet
    actual_ships =
      Enum.reduce(participants, %{}, fn participant, acc ->
        Map.update(acc, participant.ship_type_id, 1, &(&1 + 1))
      end)

    # Check each ship requirement
    {compliance_scores, issues} =
      Enum.reduce(ship_requirements, {[], []}, fn {ship_type_id, requirement},
                                                  {scores_acc, issues_acc} ->
        actual_count = Map.get(actual_ships, ship_type_id, 0)
        required_count = requirement[:min_count] || 0
        max_count = requirement[:max_count]

        {score, issue} =
          cond do
            actual_count < required_count ->
              shortage = required_count - actual_count
              {actual_count / required_count, {:shortage, ship_type_id, shortage}}

            not is_nil(max_count) and actual_count > max_count ->
              excess = actual_count - max_count
              {1.0, {:excess, ship_type_id, excess}}

            true ->
              {1.0, nil}
          end

        new_issues = if issue, do: [issue | issues_acc], else: issues_acc
        {[score | scores_acc], new_issues}
      end)

    # Calculate average ship compliance
    ship_score =
      if length(compliance_scores) > 0 do
        Enum.sum(compliance_scores) / length(compliance_scores)
      else
        1.0
      end

    %{
      score: ship_score,
      issues: issues,
      actual_ships: actual_ships,
      required_ships: ship_requirements
    }
  end

  defp calculate_role_compliance(participants, role_requirements) do
    # Count actual roles in fleet
    actual_roles =
      Enum.reduce(participants, %{}, fn participant, acc ->
        role = determine_participant_role(participant)
        Map.update(acc, role, 1, &(&1 + 1))
      end)

    # Check each role requirement
    {compliance_scores, issues} =
      Enum.reduce(role_requirements, {[], []}, fn {role, requirement}, {scores_acc, issues_acc} ->
        actual_count = Map.get(actual_roles, role, 0)
        required_count = requirement[:min_count] || 0
        max_count = requirement[:max_count]

        {score, issue} =
          cond do
            actual_count < required_count ->
              shortage = required_count - actual_count
              {actual_count / required_count, {:role_shortage, role, shortage}}

            not is_nil(max_count) and actual_count > max_count ->
              excess = actual_count - max_count
              {1.0, {:role_excess, role, excess}}

            true ->
              {1.0, nil}
          end

        new_issues = if issue, do: [issue | issues_acc], else: issues_acc
        {[score | scores_acc], new_issues}
      end)

    # Calculate average role compliance
    role_score =
      if length(compliance_scores) > 0 do
        Enum.sum(compliance_scores) / length(compliance_scores)
      else
        1.0
      end

    %{
      score: role_score,
      issues: issues,
      actual_roles: actual_roles,
      required_roles: role_requirements
    }
  end

  defp determine_participant_role(participant) do
    # Determine role based on ship type and fitting
    # This is simplified - real implementation would consider ship bonuses and modules
    ship_class = get_ship_class_for_type(participant.ship_type_id)

    case ship_class do
      :frigate ->
        # Check if it's a logistics frigate using actual ship classification
        case StaticData.get_ship_class(participant.ship_type_id) do
          :logistics_frigate -> :logistics
          :electronic_attack_frigate -> :ewar
          :interceptor -> :tackle
          :interdictor -> :tackle
          _ -> :tackle
        end

      :destroyer ->
        :dps

      :cruiser ->
        # Check if it's a logistics cruiser using actual ship classification
        case StaticData.get_ship_class(participant.ship_type_id) do
          :logistics_cruiser -> :logistics
          :force_recon -> :ewar
          :combat_recon -> :ewar
          :heavy_interdictor -> :tackle
          _ -> :dps
        end

      :battlecruiser ->
        :command

      :battleship ->
        :dps

      :capital ->
        :capital
    end
  end

  defp determine_compliance_level(compliance_score) do
    cond do
      compliance_score >= 0.9 -> :excellent
      compliance_score >= 0.8 -> :good
      compliance_score >= 0.7 -> :acceptable
      compliance_score >= 0.5 -> :poor
      true -> :critical
    end
  end

  defp generate_compliance_recommendations(ship_compliance, role_compliance) do
    compliance_recommendations = []

    # Ship-based recommendations
    ship_recommendations =
      Enum.reduce(ship_compliance.issues, compliance_recommendations, fn issue, acc ->
        case issue do
          {:shortage, ship_type_id, shortage} ->
            [
              %{
                type: :ship_shortage,
                priority: :high,
                ship_type_id: ship_type_id,
                shortage: shortage,
                description: "Add #{shortage} more ships of type #{ship_type_id}"
              }
              | acc
            ]

          {:excess, ship_type_id, excess} ->
            [
              %{
                type: :ship_excess,
                priority: :medium,
                ship_type_id: ship_type_id,
                excess: excess,
                description: "Consider removing #{excess} ships of type #{ship_type_id}"
              }
              | acc
            ]

          _ ->
            acc
        end
      end)

    # Role-based recommendations
    doctrine_validation =
      Enum.reduce(role_compliance.issues, ship_recommendations, fn issue, acc ->
        case issue do
          {:role_shortage, role, shortage} ->
            [
              %{
                type: :role_shortage,
                priority: :high,
                role: role,
                shortage: shortage,
                description: "Add #{shortage} more pilots in #{role} role"
              }
              | acc
            ]

          {:role_excess, role, excess} ->
            [
              %{
                type: :role_excess,
                priority: :low,
                role: role,
                excess: excess,
                description: "Consider rebalancing #{excess} pilots from #{role} role"
              }
              | acc
            ]

          _ ->
            acc
        end
      end)

    doctrine_validation
  end

  defp perform_fleet_validation(fleet_data, doctrine) do
    participants = fleet_data.participants

    # Basic validation checks
    validation_results = []

    # Check minimum fleet size
    min_fleet_size = calculate_minimum_fleet_size(doctrine)

    size_validation_results =
      if length(participants) < min_fleet_size do
        [
          %{
            type: :fleet_size,
            status: :fail,
            message: "Fleet size #{length(participants)} below minimum required #{min_fleet_size}"
          }
          | validation_results
        ]
      else
        [
          %{
            type: :fleet_size,
            status: :pass,
            message: "Fleet size meets minimum requirements"
          }
          | validation_results
        ]
      end

    # Check essential roles presence
    essential_roles = [:dps, :logistics]
    fleet_roles = get_fleet_roles(participants)

    role_validation_results =
      Enum.reduce(essential_roles, size_validation_results, fn role, acc ->
        if Map.get(fleet_roles, role, 0) > 0 do
          [
            %{
              type: :essential_role,
              role: role,
              status: :pass,
              message: "Essential role #{role} is present"
            }
            | acc
          ]
        else
          [
            %{
              type: :essential_role,
              role: role,
              status: :fail,
              message: "Essential role #{role} is missing"
            }
            | acc
          ]
        end
      end)

    # Check mass limits if specified
    complete_validation_results =
      if Map.has_key?(doctrine.mass_limits, :max_total_mass) do
        fleet_mass = calculate_fleet_mass(participants)
        max_mass = doctrine.mass_limits.max_total_mass

        if fleet_mass <= max_mass do
          [
            %{
              type: :mass_limit,
              status: :pass,
              message: "Fleet mass within limits",
              fleet_mass: fleet_mass,
              max_mass: max_mass
            }
            | role_validation_results
          ]
        else
          [
            %{
              type: :mass_limit,
              status: :fail,
              message: "Fleet mass #{fleet_mass} exceeds limit #{max_mass}",
              fleet_mass: fleet_mass,
              max_mass: max_mass
            }
            | role_validation_results
          ]
        end
      else
        role_validation_results
      end

    # Determine overall validation status
    overall_status =
      if Enum.any?(complete_validation_results, &(&1.status == :fail)) do
        :fail
      else
        :pass
      end

    validation_result = %{
      overall_status: overall_status,
      validation_checks: Enum.reverse(complete_validation_results),
      doctrine_name: doctrine.name,
      fleet_size: length(participants),
      validated_at: DateTime.utc_now()
    }

    {:ok, validation_result}
  end

  defp calculate_minimum_fleet_size(doctrine) do
    ship_minimums =
      doctrine
      |> Map.get(:ship_requirements, %{})
      |> Map.values()
      |> Enum.map(fn req -> req[:min_count] || 0 end)
      |> Enum.sum()

    role_minimums =
      doctrine
      |> Map.get(:role_requirements, %{})
      |> Map.values()
      |> Enum.map(fn req -> req[:min_count] || 0 end)
      |> Enum.sum()

    max(ship_minimums, role_minimums)
  end

  defp get_fleet_roles(participants) do
    Enum.reduce(participants, %{}, fn participant, acc ->
      role = determine_participant_role(participant)
      Map.update(acc, role, 1, &(&1 + 1))
    end)
  end

  defp calculate_fleet_mass(participants) do
    Enum.sum(
      Enum.map(participants, fn participant ->
        get_ship_mass(participant.ship_type_id)
      end)
    )
  end
end
