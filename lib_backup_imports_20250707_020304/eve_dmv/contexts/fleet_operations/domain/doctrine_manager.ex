defmodule EveDmv.Contexts.FleetOperations.Domain.DoctrineManager do
  use EveDmv.ErrorHandler
  use GenServer

  alias EveDmv.Contexts.FleetOperations.Infrastructure.FleetRepository
  alias EveDmv.Result

  require Logger
  @moduledoc """
  Domain service for managing fleet doctrines.

  Handles creation, validation, and management of fleet doctrines,
  including compliance checking and doctrine optimization.
  """



  # Doctrine types
  @doctrine_types [:roam, :defense, :structure, :siege, :escort, :reconnaissance]

  # Mass categories for wormhole operations
  @mass_categories [:light, :medium, :heavy, :capital]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API

  @doc """
  Create a new fleet doctrine.
  """
  def create_doctrine(doctrine_data) do
    GenServer.call(__MODULE__, {:create_doctrine, doctrine_data})
  end

  @doc """
  Update an existing fleet doctrine.
  """
  def update_doctrine(doctrine_id, updates) do
    GenServer.call(__MODULE__, {:update_doctrine, doctrine_id, updates})
  end

  @doc """
  Get a doctrine by ID.
  """
  def get_doctrine(doctrine_id) do
    GenServer.call(__MODULE__, {:get_doctrine, doctrine_id})
  end

  @doc """
  Get a doctrine by name.
  """
  def get_doctrine_by_name(doctrine_name) do
    GenServer.call(__MODULE__, {:get_doctrine_by_name, doctrine_name})
  end

  @doc """
  List doctrines with filtering options.
  """
  def list_doctrines(opts \\ []) do
    GenServer.call(__MODULE__, {:list_doctrines, opts})
  end

  @doc """
  Check fleet compliance against a doctrine.
  """
  def check_compliance(fleet_data, doctrine) do
    GenServer.call(__MODULE__, {:check_compliance, fleet_data, doctrine})
  end

  @doc """
  Validate a fleet composition against a doctrine.
  """
  def validate_fleet_composition(fleet_data, doctrine) do
    GenServer.call(__MODULE__, {:validate_fleet_composition, fleet_data, doctrine})
  end

  @doc """
  Get doctrine statistics and usage metrics.
  """
  def get_doctrine_statistics(doctrine_id) do
    GenServer.call(__MODULE__, {:get_doctrine_statistics, doctrine_id})
  end

  # GenServer implementation

  @impl GenServer
  def init(opts) do
    state = %{
      doctrines: %{},
      next_id: 1,
      usage_statistics: %{},
      compliance_cache: %{}
    }

    Logger.info("DoctrineManager started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:create_doctrine, doctrine_data}, _from, state) do
    doctrine_id = generate_doctrine_id(state.next_id)

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

    new_doctrines = Map.put(state.doctrines, doctrine_id, doctrine)

    # Initialize usage statistics
    new_usage_statistics =
      Map.put(state.usage_statistics, doctrine_id, %{
        total_uses: 0,
        compliance_scores: [],
        last_used: nil,
        average_compliance: 0.0
      })

    new_state = %{
      state
      | doctrines: new_doctrines,
        usage_statistics: new_usage_statistics,
        next_id: state.next_id + 1
    }

    Logger.info("Created doctrine: #{doctrine.name} (#{doctrine_id})")

    {:reply, {:ok, doctrine}, new_state}
  end

  @impl GenServer
  def handle_call({:update_doctrine, doctrine_id, updates}, _from, state) do
    case Map.get(state.doctrines, doctrine_id) do
      nil ->
        {:reply, {:error, :doctrine_not_found}, state}

      existing_doctrine ->
        # Update mass category if ship requirements changed
        updated_doctrine =
          if Map.has_key?(updates, :ship_requirements) do
            new_mass_category =
              determine_mass_category(%{ship_requirements: updates.ship_requirements})

            Map.merge(existing_doctrine, Map.put(updates, :mass_category, new_mass_category))
          else
            Map.merge(existing_doctrine, updates)
          end

        updated_doctrine = Map.put(updated_doctrine, :updated_at, DateTime.utc_now())
        new_doctrines = Map.put(state.doctrines, doctrine_id, updated_doctrine)

        # Clear compliance cache for this doctrine
        new_compliance_cache =
          Map.reject(state.compliance_cache, fn {key, _} ->
            case key do
              {^doctrine_id, _} -> true
              _ -> false
            end
          end)

        new_state = %{
          state
          | doctrines: new_doctrines,
            compliance_cache: new_compliance_cache
        }

        Logger.info("Updated doctrine: #{doctrine_id}")

        {:reply, {:ok, updated_doctrine}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:get_doctrine, doctrine_id}, _from, state) do
    case Map.get(state.doctrines, doctrine_id) do
      nil -> {:reply, {:error, :doctrine_not_found}, state}
      doctrine -> {:reply, {:ok, doctrine}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_doctrine_by_name, doctrine_name}, _from, state) do
    matching_doctrine =
      state.doctrines
      |> Map.values()
      |> Enum.find(fn doctrine ->
        doctrine.name == doctrine_name and doctrine.is_active
      end)

    case matching_doctrine do
      nil -> {:reply, {:error, :doctrine_not_found}, state}
      doctrine -> {:reply, {:ok, doctrine}, state}
    end
  end

  @impl GenServer
  def handle_call({:list_doctrines, opts}, _from, state) do
    corporation_id = Keyword.get(opts, :corporation_id)
    doctrine_type = Keyword.get(opts, :doctrine_type)
    active_only = Keyword.get(opts, :active_only, true)
    mass_category = Keyword.get(opts, :mass_category)

    filtered_doctrines =
      state.doctrines
      |> Map.values()
      |> Enum.filter(fn doctrine ->
        corporation_match = is_nil(corporation_id) or doctrine.corporation_id == corporation_id
        type_match = is_nil(doctrine_type) or doctrine.doctrine_type == doctrine_type
        active_match = not active_only or doctrine.is_active
        mass_match = is_nil(mass_category) or doctrine.mass_category == mass_category

        corporation_match and type_match and active_match and mass_match
      end)
      |> Enum.sort_by(& &1.updated_at, {:desc, DateTime})

    {:reply, {:ok, filtered_doctrines}, state}
  end

  @impl GenServer
  def handle_call({:check_compliance, fleet_data, doctrine}, _from, state) do
    case calculate_doctrine_compliance(fleet_data, doctrine) do
      {:ok, compliance_result} ->
        # Update usage statistics
        new_usage_statistics =
          update_doctrine_usage_statistics(
            state.usage_statistics,
            doctrine.id,
            compliance_result.compliance_score
          )

        new_state = %{state | usage_statistics: new_usage_statistics}

        {:reply, {:ok, compliance_result}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:validate_fleet_composition, fleet_data, doctrine}, _from, state) do
    case perform_fleet_validation(fleet_data, doctrine) do
      {:ok, validation_result} ->
        {:reply, {:ok, validation_result}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_doctrine_statistics, doctrine_id}, _from, state) do
    case Map.get(state.usage_statistics, doctrine_id) do
      nil -> {:reply, {:error, :doctrine_not_found}, state}
      stats -> {:reply, {:ok, stats}, state}
    end
  end

  # Private functions

  defp generate_doctrine_id(next_id) do
    "doctrine_#{next_id}_#{System.unique_integer()}"
  end

  defp determine_mass_category(doctrine_data) do
    ship_requirements = doctrine_data[:ship_requirements] || %{}

    # Calculate estimated mass for typical doctrine composition
    estimated_mass =
      Enum.sum(Enum.map(ship_requirements, fn {ship_type_id, requirement} ->
        ship_class = get_ship_class_for_type(ship_type_id)
        ship_mass = get_estimated_ship_mass(ship_class)
        ship_mass * requirement[:min_count]
      end))

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
    # Simplified ship class determination
    case rem(ship_type_id, 10) do
      0..2 -> :frigate
      3..4 -> :destroyer
      5..6 -> :cruiser
      7 -> :battlecruiser
      8 -> :battleship
      9 -> :capital
    end
  end

  defp get_estimated_ship_mass(ship_class) do
    case ship_class do
      :frigate -> 1_000_000
      :destroyer -> 1_800_000
      :cruiser -> 10_000_000
      :battlecruiser -> 50_000_000
      :battleship -> 100_000_000
      :capital -> 1_200_000_000
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
        # Check if it's a logistics frigate
        if rem(participant.ship_type_id, 5) == 0, do: :logistics, else: :tackle

      :destroyer ->
        :dps

      :cruiser ->
        # Check if it's a logistics cruiser
        if rem(participant.ship_type_id, 3) == 0, do: :logistics, else: :dps

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
      Enum.sum(Enum.map(Map.values(doctrine.ship_requirements), fn req ->
        req[:min_count] || 0
      end))

    role_minimums =
      Enum.sum(Enum.map(Map.values(doctrine.role_requirements), fn req ->
        req[:min_count] || 0
      end))

    max(ship_minimums, role_minimums)
  end

  defp get_fleet_roles(participants) do
    Enum.reduce(participants, %{}, fn participant, acc ->
      role = determine_participant_role(participant)
      Map.update(acc, role, 1, &(&1 + 1))
    end)
  end

  defp calculate_fleet_mass(participants) do
    Enum.sum(Enum.map(participants, fn participant ->
      ship_class = get_ship_class_for_type(participant.ship_type_id)
      get_estimated_ship_mass(ship_class)
    end))
  end

  defp update_doctrine_usage_statistics(usage_statistics, doctrine_id, compliance_score) do
    current_stats =
      Map.get(usage_statistics, doctrine_id, %{
        total_uses: 0,
        compliance_scores: [],
        last_used: nil,
        average_compliance: 0.0
      })

    new_compliance_scores = [compliance_score | Enum.take(current_stats.compliance_scores, 99)]
    new_average_compliance = Enum.sum(new_compliance_scores) / length(new_compliance_scores)

    updated_stats = %{
      total_uses: current_stats.total_uses + 1,
      compliance_scores: new_compliance_scores,
      last_used: DateTime.utc_now(),
      average_compliance: Float.round(new_average_compliance, 3)
    }

    Map.put(usage_statistics, doctrine_id, updated_stats)
  end
end
