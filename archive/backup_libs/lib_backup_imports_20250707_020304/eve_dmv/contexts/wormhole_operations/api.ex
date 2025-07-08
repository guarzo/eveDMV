defmodule EveDmv.Contexts.WormholeOperations.Api do
  use EveDmv.ErrorHandler

    alias EveDmv.Contexts.WormholeOperations.Domain.RecruitmentVetter
    alias EveDmv.Contexts.WormholeOperations.Infrastructure.VettingRepository
  alias EveDmv.Contexts.WormholeOperations.Domain.ChainIntelligenceService
  alias EveDmv.Contexts.WormholeOperations.Domain.HomeDefenseAnalyzer
  alias EveDmv.Contexts.WormholeOperations.Domain.MassOptimizer
  alias EveDmv.Contexts.WormholeOperations.Domain.OperationalSecurityMonitor
  alias EveDmv.Contexts.WormholeOperations.Infrastructure.DefenseMetricsCache
  alias EveDmv.Result
  alias EveDmv.Utils.ValidationUtils

  require Logger
  @moduledoc """
  Public API for the Wormhole Operations bounded context.

  This module provides the external interface for wormhole-specific
  operations including recruitment vetting, home defense analysis,
  mass optimization, and operational security monitoring.
  """





  # Recruitment and Vetting API

  @doc """
  Perform comprehensive vetting analysis for a recruitment candidate.

  ## Parameters
  - character_id: EVE character ID to vet
  - vetting_criteria: Corporation-specific vetting requirements
    - min_sp: Minimum skill points
    - min_age_days: Minimum character age
    - corp_history_analysis: Whether to analyze corporation history
    - killboard_analysis: Whether to analyze killboard activity
    - opsec_checks: Whether to perform OpSec validation

  ## Returns
  - {:ok, vetting_report} with comprehensive analysis and recommendations
  - {:error, reason} on failure
  """
  def vet_recruitment_candidate(character_id, vetting_criteria) do
    with {:ok, validated_criteria} <- validate_vetting_criteria(vetting_criteria),
         {:ok, vetting_report} <-
           RecruitmentVetter.perform_vetting_analysis(character_id, validated_criteria) do
      Logger.info("Completed vetting analysis for character: #{character_id}")
      {:ok, vetting_report}
    else
      {:error, reason} ->
        Logger.warning("Failed to vet recruitment candidate #{character_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get a previously generated vetting report.
  """
  def get_vetting_report(vetting_id) do
    VettingRepository.get_vetting_report(vetting_id)
  end

  @doc """
  Get recruitment recommendations based on character analysis.
  """
  def get_recruitment_recommendations(character_id) do
    RecruitmentVetter.generate_recruitment_recommendations(character_id)
  end

  @doc """
  Update corporation vetting criteria.
  """
  def update_vetting_criteria(corporation_id, criteria) do
    with {:ok, validated_criteria} <- validate_vetting_criteria(criteria),
         {:ok, updated_criteria} <-
           VettingRepository.update_corporation_criteria(corporation_id, validated_criteria) do
      Logger.info("Updated vetting criteria for corporation: #{corporation_id}")
      {:ok, updated_criteria}
    else
      {:error, reason} ->
        Logger.warning(
          "Failed to update vetting criteria for corp #{corporation_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Get vetting statistics for a corporation over a time range.
  """
  def get_vetting_statistics(corporation_id, time_range \\ :last_30d) do
    VettingRepository.get_vetting_statistics(corporation_id, time_range)
  end

  # Home Defense Analysis API

  @doc """
  Analyze home defense capabilities for a wormhole corporation.

  Evaluates defensive fleet composition, pilot availability across timezones,
  structure defenses, and response coordination capabilities.
  """
  def analyze_home_defense_capabilities(corporation_id) do
    with {:ok, defense_analysis} <-
           HomeDefenseAnalyzer.analyze_defense_capabilities(corporation_id) do
      Logger.info("Analyzed home defense capabilities for corporation: #{corporation_id}")
      {:ok, defense_analysis}
    else
      {:error, reason} ->
        Logger.warning(
          "Failed to analyze home defense for corp #{corporation_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Get vulnerability assessment for a specific wormhole system.
  """
  def get_defense_vulnerability_assessment(system_id) do
    HomeDefenseAnalyzer.assess_system_vulnerabilities(system_id)
  end

  @doc """
  Calculate defense readiness score for a corporation.
  """
  def calculate_defense_readiness_score(corporation_id) do
    HomeDefenseAnalyzer.calculate_defense_readiness_score(corporation_id)
  end

  @doc """
  Generate defense improvement recommendations.
  """
  def get_defense_recommendations(corporation_id) do
    HomeDefenseAnalyzer.generate_defense_recommendations(corporation_id)
  end

  @doc """
  Track defense metrics over time.
  """
  def track_defense_metrics(corporation_id, time_range \\ :last_30d) do
    DefenseMetricsCache.get_defense_metrics(corporation_id, time_range)
  end

  # Mass Optimization API

  @doc """
  Optimize fleet composition for specific wormhole class constraints.

  ## Parameters
  - fleet_data: Current fleet composition and pilot availability
  - wormhole_class: Target wormhole class (C1-C6, or specific mass limit)

  ## Returns
  Optimized fleet composition that maximizes effectiveness within mass constraints.
  """
  def optimize_fleet_for_wormhole(fleet_data, wormhole_class) do
    with {:ok, validated_fleet} <- validate_fleet_data(fleet_data),
         {:ok, validated_class} <- validate_wormhole_class(wormhole_class),
         {:ok, optimization} <-
           MassOptimizer.optimize_fleet_composition(validated_fleet, validated_class) do
      Logger.info("Optimized fleet for #{wormhole_class} wormhole operations")
      {:ok, optimization}
    else
      {:error, reason} ->
        Logger.warning("Failed to optimize fleet for wormhole: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Calculate mass efficiency metrics for a fleet.
  """
  def calculate_mass_efficiency(fleet_data) do
    with {:ok, validated_fleet} <- validate_fleet_data(fleet_data),
         {:ok, efficiency_metrics} <- MassOptimizer.calculate_mass_efficiency(validated_fleet) do
      {:ok, efficiency_metrics}
    end
  end

  @doc """
  Get mass optimization suggestions for a target wormhole class.
  """
  def get_mass_optimization_suggestions(fleet_data, target_class) do
    with {:ok, validated_fleet} <- validate_fleet_data(fleet_data),
         {:ok, validated_class} <- validate_wormhole_class(target_class),
         {:ok, suggestions} <-
           MassOptimizer.generate_optimization_suggestions(validated_fleet, validated_class) do
      {:ok, suggestions}
    end
  end

  @doc """
  Validate fleet against wormhole mass constraints.
  """
  def validate_fleet_mass_limits(fleet_data, wormhole_constraints) do
    with {:ok, validated_fleet} <- validate_fleet_data(fleet_data),
         {:ok, validated_constraints} <- validate_wormhole_constraints(wormhole_constraints),
         {:ok, validation_result} <-
           MassOptimizer.validate_mass_constraints(validated_fleet, validated_constraints) do
      {:ok, validation_result}
    end
  end

  # Operational Security API

  @doc """
  Assess OpSec compliance for a wormhole corporation.

  Evaluates information security practices, communication discipline,
  and operational security procedures specific to wormhole operations.
  """
  def assess_opsec_compliance(corporation_id) do
    with {:ok, compliance_assessment} <-
           OperationalSecurityMonitor.assess_opsec_compliance(corporation_id) do
      Logger.info("Assessed OpSec compliance for corporation: #{corporation_id}")
      {:ok, compliance_assessment}
    else
      {:error, reason} ->
        Logger.warning(
          "Failed to assess OpSec compliance for corp #{corporation_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Get OpSec violations detected over a time range.
  """
  def get_opsec_violations(corporation_id, time_range \\ :last_30d) do
    OperationalSecurityMonitor.get_opsec_violations(corporation_id, time_range)
  end

  @doc """
  Generate OpSec improvement recommendations.
  """
  def generate_opsec_recommendations(corporation_id) do
    OperationalSecurityMonitor.generate_opsec_recommendations(corporation_id)
  end

  @doc """
  Monitor ongoing OpSec metrics.
  """
  def monitor_opsec_metrics(corporation_id) do
    OperationalSecurityMonitor.get_opsec_metrics(corporation_id)
  end

  # Chain Intelligence API

  @doc """
  Analyze activity patterns in a wormhole chain.

  ## Parameters
  - chain_data: Map containing chain structure and activity information
    - systems: List of connected wormhole systems
    - connections: Wormhole connections and their properties
    - activity_data: Recent activity in each system

  ## Returns
  Analysis of chain activity, threat levels, and strategic opportunities.
  """
  def analyze_chain_activity(chain_data) do
    with {:ok, validated_chain} <- validate_chain_data(chain_data),
         {:ok, activity_analysis} <-
           ChainIntelligenceService.analyze_chain_activity(validated_chain) do
      Logger.info("Analyzed chain activity for #{length(validated_chain.systems)} systems")
      {:ok, activity_analysis}
    else
      {:error, reason} ->
        Logger.warning("Failed to analyze chain activity: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get threat assessment for a wormhole chain.
  """
  def get_chain_threat_assessment(chain_data) do
    with {:ok, validated_chain} <- validate_chain_data(chain_data),
         {:ok, threat_assessment} <-
           ChainIntelligenceService.assess_chain_threats(validated_chain) do
      {:ok, threat_assessment}
    end
  end

  @doc """
  Optimize chain coverage and monitoring priorities.
  """
  def optimize_chain_coverage(corporation_id, chain_data) do
    with {:ok, validated_chain} <- validate_chain_data(chain_data),
         {:ok, coverage_optimization} <-
           ChainIntelligenceService.optimize_chain_coverage(corporation_id, validated_chain) do
      {:ok, coverage_optimization}
    end
  end

  @doc """
  Get intelligence summary for corporation's chain operations.
  """
  def get_chain_intelligence_summary(corporation_id) do
    ChainIntelligenceService.get_intelligence_summary(corporation_id)
  end

  # Private validation functions

  defp validate_vetting_criteria(criteria) do
    # Vetting criteria are optional with defaults
    required_fields = []

    with :ok <-
           validate_optional_fields(criteria, [
             :min_sp,
             :min_age_days,
             :corp_history_analysis,
             :killboard_analysis,
             :opsec_checks
           ]) do
      # Set defaults for missing criteria
      default_criteria = %{
        min_sp: 5_000_000,
        min_age_days: 30,
        corp_history_analysis: true,
        killboard_analysis: true,
        opsec_checks: true
      }

      validated_criteria = Map.merge(default_criteria, criteria)
      {:ok, validated_criteria}
    end
  end

  defp validate_fleet_data(fleet_data) do
    required_fields = [:participants]

    with :ok <- ValidationUtils.validate_required_fields(fleet_data, required_fields),
         :ok <- validate_participants(fleet_data.participants) do
      {:ok, fleet_data}
    end
  end

  defp validate_wormhole_class(wormhole_class)
       when wormhole_class in [:c1, :c2, :c3, :c4, :c5, :c6] do
    {:ok, wormhole_class}
  end

  defp validate_wormhole_class(wormhole_class) when is_map(wormhole_class) do
    # Custom wormhole constraints
    case validate_custom_wormhole_constraints(wormhole_class) do
      :ok -> {:ok, wormhole_class}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_wormhole_class(_), do: {:error, :invalid_wormhole_class}

  defp validate_wormhole_constraints(constraints) when is_map(constraints) do
    allowed_fields = [:max_mass_kg, :max_ship_mass_kg, :max_total_mass_kg, :regeneration_rate]

    filtered_constraints = Map.take(constraints, allowed_fields)

    case validate_constraint_values(filtered_constraints) do
      :ok -> {:ok, filtered_constraints}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_wormhole_constraints(_), do: {:error, :invalid_constraints_format}

  defp validate_chain_data(chain_data) do
    required_fields = [:systems, :connections]

    with :ok <- ValidationUtils.validate_required_fields(chain_data, required_fields),
         :ok <- validate_chain_systems(chain_data.systems),
         :ok <- validate_chain_connections(chain_data.connections) do
      {:ok, chain_data}
    end
  end

  defp validate_optional_fields(data, optional_fields) do
    # Validate that provided optional fields have correct types
    Enum.reduce_while(optional_fields, :ok, fn field, :ok ->
      case Map.get(data, field) do
        # Optional field not provided
        nil ->
          {:cont, :ok}

        value ->
          case validate_optional_field(field, value) do
            :ok -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, {field, reason}}}
          end
      end
    end)
  end

  defp validate_optional_field(:min_sp, value) when is_integer(value) and value >= 0, do: :ok

  defp validate_optional_field(:min_age_days, value) when is_integer(value) and value >= 0,
    do: :ok

  defp validate_optional_field(:corp_history_analysis, value) when is_boolean(value), do: :ok
  defp validate_optional_field(:killboard_analysis, value) when is_boolean(value), do: :ok
  defp validate_optional_field(:opsec_checks, value) when is_boolean(value), do: :ok
  defp validate_optional_field(field, _value), do: {:error, {:invalid_field_type, field}}

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

  defp validate_custom_wormhole_constraints(constraints) do
    case validate_constraint_values(constraints) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_constraint_values(constraints) do
    Enum.reduce_while(constraints, :ok, fn {field, value}, :ok ->
      case validate_constraint_value(field, value) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {field, reason}}}
      end
    end)
  end

  defp validate_constraint_value(:max_mass_kg, value) when is_integer(value) and value > 0,
    do: :ok

  defp validate_constraint_value(:max_ship_mass_kg, value) when is_integer(value) and value > 0,
    do: :ok

  defp validate_constraint_value(:max_total_mass_kg, value) when is_integer(value) and value > 0,
    do: :ok

  defp validate_constraint_value(:regeneration_rate, value) when is_number(value) and value > 0,
    do: :ok

  defp validate_constraint_value(field, _value), do: {:error, {:invalid_constraint_value, field}}

  defp validate_chain_systems(systems) when is_list(systems) do
    if length(systems) > 0 do
      case validate_system_structure(systems) do
        :ok -> :ok
        {:error, reason} -> {:error, {:invalid_systems, reason}}
      end
    else
      {:error, :no_systems}
    end
  end

  defp validate_chain_systems(_), do: {:error, :invalid_systems_type}

  defp validate_chain_connections(connections) when is_list(connections) do
    case validate_connection_structure(connections) do
      :ok -> :ok
      {:error, reason} -> {:error, {:invalid_connections, reason}}
    end
  end

  defp validate_chain_connections(_), do: {:error, :invalid_connections_type}

  defp validate_system_structure(systems) do
    Enum.reduce_while(systems, :ok, fn system, :ok ->
      required_system_fields = [:system_id, :system_class]

      case ValidationUtils.validate_required_fields(system, required_system_fields) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_connection_structure(connections) do
    Enum.reduce_while(connections, :ok, fn connection, :ok ->
      required_connection_fields = [:from_system, :to_system, :wormhole_type]

      case ValidationUtils.validate_required_fields(connection, required_connection_fields) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end
