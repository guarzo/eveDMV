defmodule EveDmv.Contexts.FleetOperations.Domain.DoctrineManager do
  @moduledoc """
  Domain service for managing fleet doctrines.

  Handles creation, validation, and management of fleet doctrines,
  including compliance checking and doctrine optimization.

  Converted from GenServer to simple module for stateless operations.
  """
  """

  use EveDmv.ErrorHandler

  alias EveDmv.StaticData

  require Logger

  # Note: Doctrine types and mass categories are defined inline where needed

  # Public API

  @doc """
  Create a new fleet doctrine.

  Persists the doctrine to the database using the Ash resource.
  """
  def create_doctrine(doctrine_data) do
    # Prepare attributes for Ash resource
    attributes = %{
      name: doctrine_data.name,
      description: doctrine_data[:description],
      doctrine_type: doctrine_data[:doctrine_type] || :roam,
      ship_requirements: normalize_requirements(doctrine_data.ship_requirements),
      role_requirements: normalize_requirements(doctrine_data.role_requirements),
      optional_ships: doctrine_data[:optional_ships] || [],
      mass_limits: doctrine_data[:mass_limits] || %{},
      minimum_pilots: doctrine_data[:minimum_pilots] || calculate_minimum_pilots(doctrine_data),
      optimal_pilots: doctrine_data[:optimal_pilots],
      corporation_id: doctrine_data[:corporation_id],
      is_active: Map.get(doctrine_data, :is_active, true),
      is_public: Map.get(doctrine_data, :is_public, false),
      created_by: doctrine_data[:created_by] || doctrine_data[:creator_id],
      tags: doctrine_data[:tags] || [],
      fitting_notes: doctrine_data[:fitting_notes]
    }

    case Ash.create(
           EveDmv.Contexts.FleetOperations.Resources.FleetDoctrine,
           attributes,
           domain: EveDmv.Contexts.FleetOperations.Domain
         ) do
      {:ok, doctrine} ->
        Logger.info("Created doctrine: #{doctrine.name} (#{doctrine.id})")
        {:ok, doctrine}

      {:error, changeset} ->
        Logger.error("Failed to create doctrine: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @doc """
  Update an existing fleet doctrine.

  Updates the doctrine in the database using the Ash resource.
  """
  def update_doctrine(doctrine_id, updates) do
    case Ash.get(EveDmv.Contexts.FleetOperations.Resources.FleetDoctrine, doctrine_id,
           domain: EveDmv.Contexts.FleetOperations.Domain
         ) do
      {:ok, doctrine} ->
        # Normalize requirement maps if being updated
        normalized_updates =
          updates
          |> Map.update(:ship_requirements, nil, &normalize_requirements/1)
          |> Map.update(:role_requirements, nil, &normalize_requirements/1)
          |> Enum.filter(fn {_, v} -> v != nil end)
          |> Map.new()

        case Ash.update(doctrine, normalized_updates,
               domain: EveDmv.Contexts.FleetOperations.Domain
             ) do
          {:ok, updated_doctrine} ->
            Logger.info("Updated doctrine: #{updated_doctrine.name}")
            {:ok, updated_doctrine}

          {:error, changeset} ->
            Logger.error("Failed to update doctrine: #{inspect(changeset.errors)}")
            {:error, changeset}
        end

      {:error, _} ->
        {:error, :not_found}
    end
  end

  @doc """
  Get a doctrine by ID.

  Queries the database for the specific doctrine.
  """
  def get_doctrine(doctrine_id) do
    case Ash.get(EveDmv.Contexts.FleetOperations.Resources.FleetDoctrine, doctrine_id,
           domain: EveDmv.Contexts.FleetOperations.Domain
         ) do
      {:ok, doctrine} -> {:ok, doctrine}
      {:error, _} -> {:error, :not_found}
    end
  end

  @doc """
  Get a doctrine by name.

  Queries the database for a doctrine with the given name.
  """
  def get_doctrine_by_name(name, corporation_id \\ nil) do
    import Ash.Query

    query =
      EveDmv.Contexts.FleetOperations.Resources.FleetDoctrine
      |> filter(name == ^name)

    final_query =
      if corporation_id do
        filter(query, corporation_id == ^corporation_id or is_public == true)
      else
        query
      end

    case Ash.read_one(final_query, domain: EveDmv.Contexts.FleetOperations.Domain) do
      {:ok, doctrine} -> {:ok, doctrine}
      {:error, _} -> {:error, :not_found}
    end
  end

  @doc """
  List doctrines with filtering options.

  Options:
  - corporation_id: Filter by corporation (includes public doctrines)
  - doctrine_type: Filter by doctrine type
  - is_active: Filter by active status (default: true)
  - search: Search in name, description, and tags
  """
  def list_doctrines(opts \\ []) do
    import Ash.Query

    query = EveDmv.Contexts.FleetOperations.Resources.FleetDoctrine

    # Apply filters
    base_query =
      if corporation_id = opts[:corporation_id] do
        # Use the custom action
        args = %{corporation_id: corporation_id}

        EveDmv.Contexts.FleetOperations.Resources.FleetDoctrine
        |> Ash.Query.for_read(:by_corporation, args)
      else
        query
      end

    type_filtered_query =
      if type = opts[:doctrine_type] do
        filter(base_query, doctrine_type == ^type)
      else
        base_query
      end

    active_filtered_query =
      if Keyword.get(opts, :is_active, true) do
        filter(type_filtered_query, is_active == true)
      else
        type_filtered_query
      end

    search_filtered_query =
      if search_term = opts[:search] do
        # Use the custom search action
        args = %{query: search_term}

        EveDmv.Contexts.FleetOperations.Resources.FleetDoctrine
        |> Ash.Query.for_read(:search, args)
      else
        active_filtered_query
      end

    # Sort by usage and name
    final_query =
      search_filtered_query
      |> sort(usage_count: :desc, name: :asc)
      |> load([:total_minimum_pilots, :completeness_score])

    case Ash.read(final_query, domain: EveDmv.Contexts.FleetOperations.Domain) do
      {:ok, doctrines} ->
        {:ok, doctrines}

      {:error, error} ->
        Logger.error("Failed to list doctrines: #{inspect(error)}")
        {:error, error}
    end
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

  Returns usage statistics and performance metrics for a doctrine.
  """
  def get_doctrine_statistics(doctrine_id) do
    case get_doctrine(doctrine_id) do
      {:ok, doctrine} ->
        # In a full implementation, we'd query fleet history
        # For now, return basic statistics from the doctrine itself
        stats = %{
          doctrine_id: doctrine.id,
          doctrine_name: doctrine.name,
          usage_count: doctrine.usage_count,
          last_used_at: doctrine.last_used_at,
          effectiveness_rating: doctrine.effectiveness_rating || 0.0,
          completeness_score: calculate_completeness_score(doctrine),
          total_minimum_pilots: calculate_total_minimum_pilots(doctrine),
          created_at: doctrine.created_at,
          updated_at: doctrine.updated_at
        }

        {:ok, stats}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Delete a doctrine.
  """
  def delete_doctrine(doctrine_id) do
    case get_doctrine(doctrine_id) do
      {:ok, doctrine} ->
        case Ash.destroy(doctrine, domain: EveDmv.Contexts.FleetOperations.Domain) do
          :ok ->
            Logger.info("Deleted doctrine: #{doctrine.name}")
            :ok

          {:error, error} ->
            Logger.error("Failed to delete doctrine: #{inspect(error)}")
            {:error, error}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Record doctrine usage in a fleet.
  """
  def record_doctrine_usage(doctrine_id) do
    case get_doctrine(doctrine_id) do
      {:ok, doctrine} ->
        Ash.update(doctrine, %{},
          domain: EveDmv.Contexts.FleetOperations.Domain,
          action: :increment_usage
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Update doctrine effectiveness rating based on fleet performance.
  """
  def update_doctrine_effectiveness(doctrine_id, rating) when rating >= 0.0 and rating <= 1.0 do
    case get_doctrine(doctrine_id) do
      {:ok, doctrine} ->
        Ash.update(doctrine, %{},
          domain: EveDmv.Contexts.FleetOperations.Domain,
          action: :update_effectiveness,
          arguments: %{rating: rating}
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp normalize_requirements(requirements) when is_map(requirements) do
    # Ensure all values are properly formatted maps with string keys
    requirements
    |> Enum.map(fn {k, v} ->
      key = to_string(k)

      value =
        case v do
          %{} = map ->
            map
            |> Enum.map(fn {mk, mv} -> {to_string(mk), mv} end)
            |> Map.new()

          _ ->
            %{"min_count" => 1}
        end

      {key, value}
    end)
    |> Map.new()
  end

  defp normalize_requirements(_), do: %{}

  defp calculate_minimum_pilots(doctrine_data) do
    ship_mins =
      doctrine_data[:ship_requirements]
      |> normalize_requirements()
      |> Map.values()
      |> Enum.map(&Map.get(&1, "min_count", 0))
      |> Enum.sum()

    role_mins =
      doctrine_data[:role_requirements]
      |> normalize_requirements()
      |> Map.values()
      |> Enum.map(&Map.get(&1, "min_count", 0))
      |> Enum.sum()

    max(ship_mins, role_mins)
  end

  defp calculate_total_minimum_pilots(doctrine) do
    ship_mins =
      doctrine.ship_requirements
      |> Map.values()
      |> Enum.map(&Map.get(&1, "min_count", 0))
      |> Enum.sum()

    role_mins =
      doctrine.role_requirements
      |> Map.values()
      |> Enum.map(&Map.get(&1, "min_count", 0))
      |> Enum.sum()

    max(ship_mins, role_mins)
  end

  defp calculate_completeness_score(doctrine) do
    ship_score = if map_size(doctrine.ship_requirements) > 0, do: 0.25, else: 0
    role_score = if map_size(doctrine.role_requirements) > 0, do: 0.25, else: 0

    desc_score =
      if doctrine.description && String.length(doctrine.description) > 50, do: 0.2, else: 0

    fitting_score =
      if doctrine.fitting_notes && String.length(doctrine.fitting_notes) > 100, do: 0.2, else: 0

    effectiveness_score = if doctrine.effectiveness_rating, do: 0.1, else: 0

    ship_score + role_score + desc_score + fitting_score + effectiveness_score
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
      if Enum.empty?(compliance_scores) do
        1.0
      else
        Enum.sum(compliance_scores) / length(compliance_scores)
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
      if Enum.empty?(compliance_scores) do
        1.0
      else
        Enum.sum(compliance_scores) / length(compliance_scores)
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
