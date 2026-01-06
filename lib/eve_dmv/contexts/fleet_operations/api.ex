defmodule EveDmv.Contexts.FleetOperations.Api do
  @moduledoc """
  Public API for the Fleet Operations bounded context.

  This module provides the external interface for fleet analysis,
  doctrine management, and fleet operations intelligence. All operations
  are validated through the FleetValidationService before processing.
  """

  alias EveDmv.Contexts.FleetOperations.Domain.DoctrineManager
  alias EveDmv.Contexts.FleetOperations.Domain.EffectivenessCalculator
  alias EveDmv.Contexts.FleetOperations.Domain.FleetAnalyzer
  alias EveDmv.Types

  require Logger

  # ============================================================================
  # Fleet Analysis API
  # ============================================================================

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
  @spec analyze_fleet_composition(map()) :: Types.analysis_result()
  defdelegate analyze_fleet_composition(fleet_data),
    to: FleetAnalyzer,
    as: :analyze_composition_validated

  @doc """
  Analyze a fleet engagement from killmail data.

  Provides detailed analysis of fleet performance, losses, and effectiveness.
  """
  @spec analyze_fleet_engagement(map()) :: Types.analysis_result()
  defdelegate analyze_fleet_engagement(engagement_data),
    to: FleetAnalyzer,
    as: :analyze_engagement_validated

  @doc """
  Check doctrine compliance for a fleet composition.
  """
  @spec get_doctrine_compliance(map(), String.t()) :: Types.analysis_result()
  defdelegate get_doctrine_compliance(fleet_data, doctrine_name),
    to: DoctrineManager,
    as: :check_compliance_validated

  @doc """
  Calculate fleet effectiveness metrics.

  Includes damage efficiency, survival rates, objective completion, and coordination scores.
  """
  @spec get_fleet_effectiveness_metrics(String.t()) :: Types.analysis_result()
  defdelegate get_fleet_effectiveness_metrics(fleet_id),
    to: EffectivenessCalculator,
    as: :calculate_fleet_effectiveness

  # ============================================================================
  # Doctrine Management API
  # ============================================================================

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
  @spec create_doctrine(map()) :: Types.result(map())
  defdelegate create_doctrine(doctrine_data),
    to: DoctrineManager,
    as: :create_doctrine_validated

  @doc """
  Update an existing fleet doctrine.
  """
  @spec update_doctrine(Types.doctrine_id(), map()) :: Types.result(map())
  defdelegate update_doctrine(doctrine_id, updates),
    to: DoctrineManager,
    as: :update_doctrine_validated

  @doc """
  Get a doctrine by ID.
  """
  @spec get_doctrine(Types.doctrine_id()) :: Types.result(map())
  defdelegate get_doctrine(doctrine_id), to: DoctrineManager

  @doc """
  List available doctrines with filtering.

  ## Options
  - corporation_id: Filter by corporation
  - doctrine_type: Filter by type (roam, defense, structure, etc.)
  - active_only: Only return active doctrines
  - mass_category: Filter by wormhole mass category
  """
  @spec list_doctrines(Types.opts()) :: Types.result([map()])
  defdelegate list_doctrines(opts \\ []), to: DoctrineManager

  @doc """
  Validate a fleet composition against a specific doctrine.
  """
  @spec validate_fleet_against_doctrine(map(), Types.doctrine_id()) :: Types.analysis_result()
  defdelegate validate_fleet_against_doctrine(fleet_data, doctrine_id),
    to: DoctrineManager,
    as: :validate_fleet_composition_validated

  # ============================================================================
  # Fleet Operations Intelligence API
  # ============================================================================

  @doc """
  Analyze fleet performance trends for a corporation.
  """
  @spec get_fleet_performance_trends(Types.corporation_id(), Types.time_range()) ::
          Types.analysis_result()
  defdelegate get_fleet_performance_trends(corporation_id, time_range \\ :last_90d),
    to: EffectivenessCalculator,
    as: :calculate_performance_trends

  @doc """
  Calculate mass analysis for wormhole operations.

  Provides total mass, wormhole class compatibility, and mass optimization suggestions.
  """
  @spec get_mass_analysis(map()) :: Types.analysis_result()
  defdelegate get_mass_analysis(fleet_data),
    to: FleetAnalyzer,
    as: :calculate_mass_analysis_validated

  # ============================================================================
  # Fleet Optimization API
  # ============================================================================

  @doc """
  Generate recommendations for fleet improvement.

  Analyzes current composition and suggests optimizations for effectiveness.
  """
  @spec recommend_fleet_improvements(map()) :: Types.analysis_result()
  defdelegate recommend_fleet_improvements(fleet_data),
    to: FleetAnalyzer,
    as: :generate_improvement_recommendations_validated

  @doc """
  Calculate optimal fleet composition for a doctrine and pilot count.
  """
  @spec get_optimal_fleet_composition(Types.doctrine_id(), pos_integer()) ::
          Types.analysis_result()
  defdelegate get_optimal_fleet_composition(doctrine_id, pilot_count),
    to: FleetAnalyzer,
    as: :calculate_optimal_composition_validated

  @doc """
  Analyze fleet losses and identify improvement areas.
  """
  @spec analyze_fleet_losses(map()) :: Types.analysis_result()
  defdelegate analyze_fleet_losses(fleet_data),
    to: EffectivenessCalculator,
    as: :analyze_fleet_losses_validated
end
