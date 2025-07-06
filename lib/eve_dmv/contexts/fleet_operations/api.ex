defmodule EveDmv.Contexts.FleetOperations.Api do
  @moduledoc """
  Public API for the Fleet Operations bounded context.

  This module provides the external interface for fleet analysis,
  doctrine management, and fleet operations intelligence. All operations
  are validated and provide comprehensive fleet insights.
  """

  use EveDmv.ErrorHandler
  alias EveDmv.Result
  alias EveDmv.Utils.ValidationUtils

  alias EveDmv.Contexts.FleetOperations.Domain.{
    FleetAnalyzer,
    DoctrineManager,
    EffectivenessCalculator
  }

  alias EveDmv.Contexts.FleetOperations.Infrastructure.{FleetRepository, EngagementCache}

  require Logger

  # Fleet Analysis API

  @doc """
  Analyze fleet composition for effectiveness and recommendations.

  ## Parameters
  - fleet_data: Map containing fleet information
    - participants: List of fleet members with ships and roles
    - engagement_context: Combat context (roam, defense, structure, etc.)
    - doctrine_target: Optional target doctrine for comparison

  ## Returns
  - {:ok, analysis} with composition breakdown, effectiveness score, and recommendations
  - {:error, reason} on failure
  """
  def analyze_fleet_composition(fleet_data) do
    with {:ok, validated_data} <- validate_fleet_data(fleet_data),
         {:ok, analysis} <- FleetAnalyzer.analyze_composition(validated_data) do
      Logger.info(
        "Analyzed fleet composition with #{length(validated_data.participants)} participants"
      )

      {:ok, analysis}
    else
      {:error, reason} ->
        Logger.warning("Failed to analyze fleet composition: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Analyze a fleet engagement from killmail data.

  Provides detailed analysis of fleet performance, losses, and effectiveness.
  """
  def analyze_fleet_engagement(engagement_data) do
    with {:ok, validated_data} <- validate_engagement_data(engagement_data),
         {:ok, analysis} <- FleetAnalyzer.analyze_engagement(validated_data) do
      Logger.info("Analyzed fleet engagement: #{engagement_data.engagement_id}")
      {:ok, analysis}
    else
      {:error, reason} ->
        Logger.warning("Failed to analyze fleet engagement: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get comprehensive fleet statistics over a time range.
  """
  def get_fleet_statistics(fleet_id, time_range \\ :last_30d) do
    EngagementCache.get_fleet_statistics(fleet_id, time_range)
  end

  @doc """
  Check doctrine compliance for a fleet composition.
  """
  def get_doctrine_compliance(fleet_data, doctrine_name) do
    with {:ok, validated_data} <- validate_fleet_data(fleet_data),
         {:ok, doctrine} <- DoctrineManager.get_doctrine_by_name(doctrine_name),
         {:ok, compliance} <- DoctrineManager.check_compliance(validated_data, doctrine) do
      {:ok, compliance}
    end
  end

  @doc """
  Calculate fleet effectiveness metrics.

  Includes damage efficiency, survival rates, objective completion, and coordination scores.
  """
  def get_fleet_effectiveness_metrics(fleet_id) do
    EffectivenessCalculator.calculate_fleet_effectiveness(fleet_id)
  end

  # Doctrine Management API

  @doc """
  Create a new fleet doctrine.

  ## Parameters
  - doctrine_data: Map containing doctrine configuration
    - name: Doctrine name
    - description: Purpose and usage notes
    - ship_requirements: Required ship types and quantities
    - role_requirements: Fleet roles and minimum counts
    - optional_ships: Ships that can fill gaps
    - mass_limits: Wormhole mass constraints
  """
  def create_doctrine(doctrine_data) do
    with {:ok, validated_data} <- validate_doctrine_data(doctrine_data),
         {:ok, doctrine} <- DoctrineManager.create_doctrine(validated_data) do
      Logger.info("Created fleet doctrine: #{doctrine.name}")
      {:ok, doctrine}
    else
      {:error, reason} ->
        Logger.warning("Failed to create doctrine: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Update an existing fleet doctrine.
  """
  def update_doctrine(doctrine_id, updates) do
    with {:ok, validated_updates} <- validate_doctrine_updates(updates),
         {:ok, doctrine} <- DoctrineManager.update_doctrine(doctrine_id, validated_updates) do
      Logger.info("Updated doctrine: #{doctrine_id}")
      {:ok, doctrine}
    else
      {:error, reason} ->
        Logger.warning("Failed to update doctrine #{doctrine_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get a doctrine by ID.
  """
  def get_doctrine(doctrine_id) do
    DoctrineManager.get_doctrine(doctrine_id)
  end

  @doc """
  List available doctrines with filtering.

  ## Options
  - corporation_id: Filter by corporation
  - doctrine_type: Filter by type (roam, defense, structure, etc.)
  - active_only: Only return active doctrines
  - mass_category: Filter by wormhole mass category
  """
  def list_doctrines(opts \\ []) do
    DoctrineManager.list_doctrines(opts)
  end

  @doc """
  Validate a fleet composition against a specific doctrine.
  """
  def validate_fleet_against_doctrine(fleet_data, doctrine_id) do
    with {:ok, validated_fleet} <- validate_fleet_data(fleet_data),
         {:ok, doctrine} <- DoctrineManager.get_doctrine(doctrine_id),
         {:ok, validation_result} <-
           DoctrineManager.validate_fleet_composition(validated_fleet, doctrine) do
      {:ok, validation_result}
    end
  end

  # Fleet Operations Intelligence API

  @doc """
  Get fleet engagements with filtering and pagination.

  ## Options
  - corporation_id: Filter by corporation
  - since: Return engagements since this timestamp
  - engagement_type: Filter by engagement type
  - min_participants: Minimum fleet size
  - limit: Maximum results to return
  """
  def get_fleet_engagements(opts \\ []) do
    EngagementCache.get_fleet_engagements(opts)
  end

  @doc """
  Get detailed information about a specific fleet engagement.
  """
  def get_engagement_details(engagement_id) do
    EngagementCache.get_engagement_details(engagement_id)
  end

  @doc """
  Analyze fleet performance trends for a corporation.
  """
  def get_fleet_performance_trends(corporation_id, time_range \\ :last_90d) do
    EffectivenessCalculator.calculate_performance_trends(corporation_id, time_range)
  end

  @doc """
  Calculate mass analysis for wormhole operations.

  Provides total mass, wormhole class compatibility, and mass optimization suggestions.
  """
  def get_mass_analysis(fleet_data) do
    with {:ok, validated_data} <- validate_fleet_data(fleet_data),
         {:ok, mass_analysis} <- FleetAnalyzer.calculate_mass_analysis(validated_data) do
      {:ok, mass_analysis}
    end
  end

  # Fleet Optimization API

  @doc """
  Generate recommendations for fleet improvement.

  Analyzes current composition and suggests optimizations for effectiveness.
  """
  def recommend_fleet_improvements(fleet_data) do
    with {:ok, validated_data} <- validate_fleet_data(fleet_data),
         {:ok, recommendations} <-
           FleetAnalyzer.generate_improvement_recommendations(validated_data) do
      {:ok, recommendations}
    end
  end

  @doc """
  Calculate optimal fleet composition for a doctrine and pilot count.
  """
  def get_optimal_fleet_composition(doctrine_id, pilot_count) do
    with {:ok, doctrine} <- DoctrineManager.get_doctrine(doctrine_id),
         {:ok, composition} <- FleetAnalyzer.calculate_optimal_composition(doctrine, pilot_count) do
      {:ok, composition}
    end
  end

  @doc """
  Analyze fleet losses and identify improvement areas.
  """
  def analyze_fleet_losses(fleet_data) do
    with {:ok, validated_data} <- validate_fleet_data(fleet_data),
         {:ok, loss_analysis} <- EffectivenessCalculator.analyze_fleet_losses(validated_data) do
      {:ok, loss_analysis}
    end
  end

  # Private validation functions

  defp validate_fleet_data(fleet_data) do
    required_fields = [:participants]

    with :ok <- ValidationUtils.validate_required_fields(fleet_data, required_fields),
         :ok <- validate_participants(fleet_data.participants) do
      {:ok, fleet_data}
    end
  end

  defp validate_engagement_data(engagement_data) do
    required_fields = [:engagement_id, :participants, :killmails]

    with :ok <- ValidationUtils.validate_required_fields(engagement_data, required_fields),
         :ok <- validate_participants(engagement_data.participants),
         :ok <- validate_killmails(engagement_data.killmails) do
      {:ok, engagement_data}
    end
  end

  defp validate_doctrine_data(doctrine_data) do
    required_fields = [:name, :ship_requirements, :role_requirements]

    with :ok <- ValidationUtils.validate_required_fields(doctrine_data, required_fields),
         :ok <- validate_doctrine_name(doctrine_data.name),
         :ok <- validate_ship_requirements(doctrine_data.ship_requirements),
         :ok <- validate_role_requirements(doctrine_data.role_requirements) do
      {:ok, doctrine_data}
    end
  end

  defp validate_doctrine_updates(updates) do
    allowed_fields = [
      :name,
      :description,
      :ship_requirements,
      :role_requirements,
      :optional_ships,
      :mass_limits,
      :is_active
    ]

    filtered_updates = Map.take(updates, allowed_fields)

    with :ok <- validate_update_fields(filtered_updates) do
      {:ok, filtered_updates}
    end
  end

  defp validate_participants(participants) when is_list(participants) do
    if length(participants) > 0 do
      case validate_participant_structure(participants) do
        :ok -> :ok
        {:error, reason} -> {:error, {:invalid_participants, reason}}
      end
    else
      {:error, :no_participants}
    end
  end

  defp validate_participants(_), do: {:error, :invalid_participants_type}

  defp validate_participant_structure(participants) do
    Enum.reduce_while(participants, :ok, fn participant, :ok ->
      required_participant_fields = [:character_id, :ship_type_id]

      case ValidationUtils.validate_required_fields(participant, required_participant_fields) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_killmails(killmails) when is_list(killmails) do
    if length(killmails) > 0 do
      case validate_killmail_structure(killmails) do
        :ok -> :ok
        {:error, reason} -> {:error, {:invalid_killmails, reason}}
      end
    else
      {:error, :no_killmails}
    end
  end

  defp validate_killmails(_), do: {:error, :invalid_killmails_type}

  defp validate_killmail_structure(killmails) do
    Enum.reduce_while(killmails, :ok, fn killmail, :ok ->
      required_killmail_fields = [:killmail_id, :victim, :attackers]

      case ValidationUtils.validate_required_fields(killmail, required_killmail_fields) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_doctrine_name(name) when is_binary(name) do
    cond do
      String.length(name) < 3 -> {:error, :name_too_short}
      String.length(name) > 50 -> {:error, :name_too_long}
      String.trim(name) == "" -> {:error, :name_empty}
      not Regex.match?(~r/^[a-zA-Z0-9\s\-_]+$/, name) -> {:error, :invalid_name_characters}
      true -> :ok
    end
  end

  defp validate_doctrine_name(_), do: {:error, :invalid_name_type}

  defp validate_ship_requirements(ship_requirements) when is_map(ship_requirements) do
    if map_size(ship_requirements) > 0 do
      # Validate each ship requirement entry
      Enum.reduce_while(ship_requirements, :ok, fn {ship_type_id, requirement}, :ok ->
        case validate_ship_requirement(ship_type_id, requirement) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, {ship_type_id, reason}}}
        end
      end)
    else
      {:error, :no_ship_requirements}
    end
  end

  defp validate_ship_requirements(_), do: {:error, :invalid_ship_requirements_type}

  defp validate_ship_requirement(ship_type_id, requirement)
       when is_integer(ship_type_id) and is_map(requirement) do
    required_fields = [:min_count]

    with :ok <- ValidationUtils.validate_required_fields(requirement, required_fields),
         :ok <- validate_min_count(requirement.min_count) do
      :ok
    end
  end

  defp validate_ship_requirement(_ship_type_id, _requirement),
    do: {:error, :invalid_requirement_structure}

  defp validate_role_requirements(role_requirements) when is_map(role_requirements) do
    valid_roles = [:dps, :logistics, :tackle, :ewar, :command, :support]

    Enum.reduce_while(role_requirements, :ok, fn {role, requirement}, :ok ->
      cond do
        role not in valid_roles -> {:halt, {:error, {:invalid_role, role}}}
        not is_map(requirement) -> {:halt, {:error, {:invalid_role_requirement, role}}}
        true -> {:cont, :ok}
      end
    end)
  end

  defp validate_role_requirements(_), do: {:error, :invalid_role_requirements_type}

  defp validate_min_count(count) when is_integer(count) and count >= 0, do: :ok
  defp validate_min_count(_), do: {:error, :invalid_min_count}

  defp validate_update_fields(updates) do
    Enum.reduce_while(updates, :ok, fn {field, value}, :ok ->
      case validate_update_field(field, value) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {field, reason}}}
      end
    end)
  end

  defp validate_update_field(:name, name), do: validate_doctrine_name(name)
  defp validate_update_field(:description, desc) when is_binary(desc), do: :ok
  defp validate_update_field(:ship_requirements, reqs), do: validate_ship_requirements(reqs)
  defp validate_update_field(:role_requirements, reqs), do: validate_role_requirements(reqs)
  defp validate_update_field(:optional_ships, ships) when is_list(ships), do: :ok
  defp validate_update_field(:mass_limits, limits) when is_map(limits), do: :ok
  defp validate_update_field(:is_active, active) when is_boolean(active), do: :ok
  defp validate_update_field(field, _value), do: {:error, {:invalid_field, field}}
end
