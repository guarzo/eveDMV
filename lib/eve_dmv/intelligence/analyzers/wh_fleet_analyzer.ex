# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmv.Intelligence.Analyzers.WhFleetAnalyzer do
  @moduledoc """
  Wormhole fleet composition analysis and optimization engine.

  Provides intelligent fleet composition recommendations, skill gap analysis,
  mass calculations, and doctrine effectiveness evaluation for wormhole operations.
  """

  alias EveDmv.Intelligence.Analyzers.FleetAssetManager
  alias EveDmv.Intelligence.Analyzers.FleetPilotAnalyzer
  alias EveDmv.Intelligence.Analyzers.FleetSkillAnalyzer
  alias EveDmv.Intelligence.Analyzers.MassCalculator
  alias EveDmv.Intelligence.Analyzers.WhFleetAnalyzer.DoctrineManager
  alias EveDmv.Intelligence.Analyzers.WhFleetAnalyzer.FleetAnalyzer
  alias EveDmv.Intelligence.Analyzers.WhFleetAnalyzer.FleetOptimizer
  alias EveDmv.Intelligence.Analyzers.WhFleetAnalyzer.WormholeCompatibility
  alias EveDmv.Intelligence.Core.TimeoutHelper
  alias EveDmv.Intelligence.Fleet.FleetReadinessCalculator
  alias EveDmv.Intelligence.Wormhole.FleetComposition

  require Ash.Query
  require Logger

  @doc """
  Analyze and optimize a fleet composition for wormhole operations.

  Options:
  - auth_token: ESI auth token for asset tracking (optional)

  Returns {:ok, composition_record} or {:error, reason}
  """
  def analyze_fleet_composition(composition_id, options \\ []) do
    Logger.info("Starting fleet composition analysis for composition #{composition_id}")

    auth_token = Keyword.get(options, :auth_token)

    with {:ok, composition} <-
           TimeoutHelper.with_default_timeout(
             fn -> get_composition_record(composition_id) end,
             :query
           ),
         {:ok, available_pilots} <-
           TimeoutHelper.with_default_timeout(
             fn -> FleetPilotAnalyzer.get_available_pilots(composition.corporation_id) end,
             :analysis
           ),
         {:ok, ship_data} <-
           TimeoutHelper.with_default_timeout(
             fn -> get_ship_data(composition.doctrine_template) end,
             :query
           ),
         {:ok, asset_data} <-
           TimeoutHelper.with_default_timeout(
             fn -> FleetAssetManager.get_asset_availability(composition, auth_token) end,
             :api
           ),
         {:ok, skill_analysis} <-
           TimeoutHelper.with_default_timeout(
             fn ->
               FleetSkillAnalyzer.analyze_skill_requirements(
                 composition.doctrine_template,
                 available_pilots
               )
             end,
             :analysis
           ),
         {:ok, mass_analysis} <-
           TimeoutHelper.with_default_timeout(
             fn ->
               MassCalculator.calculate_mass_efficiency(composition.doctrine_template, ship_data)
             end,
             :analysis
           ),
         {:ok, pilot_assignments} <-
           TimeoutHelper.with_default_timeout(
             fn ->
               FleetPilotAnalyzer.optimize_pilot_assignments(
                 composition.doctrine_template,
                 available_pilots,
                 skill_analysis
               )
             end,
             :analysis
           ),
         {:ok, optimization_results} <-
           TimeoutHelper.with_default_timeout(
             fn ->
               FleetOptimizer.generate_optimization_recommendations(
                 composition,
                 skill_analysis,
                 mass_analysis,
                 pilot_assignments
               )
             end,
             :analysis
           ) do
      try do
        ship_requirements =
          FleetAssetManager.build_ship_requirements(composition.doctrine_template, ship_data)

        readiness_metrics =
          FleetReadinessCalculator.calculate_readiness_metrics(pilot_assignments, skill_analysis)

        updated_composition = %{
          ship_requirements: ship_requirements,
          pilot_assignments: pilot_assignments,
          skill_gaps: skill_analysis,
          mass_calculations: mass_analysis,
          optimization_results: optimization_results,
          asset_availability: asset_data,
          current_readiness_percent: readiness_metrics.readiness_percent,
          pilots_available: readiness_metrics.pilots_available,
          pilots_required: readiness_metrics.pilots_required,
          estimated_form_up_time_minutes: readiness_metrics.estimated_form_up_time,
          effectiveness_rating:
            optimization_results["fleet_effectiveness"]["overall_rating"] || 0.0
        }

        FleetComposition.update_doctrine(composition, updated_composition)
      rescue
        error ->
          Logger.error("Error in fleet composition analysis calculation: #{inspect(error)}")
          {:error, "Fleet composition analysis calculation failed"}
      end
    else
      {:error, reason} ->
        {:error, "Failed to gather fleet composition analysis data: #{inspect(reason)}"}
    end
  end

  @doc """
  Create a new fleet composition doctrine for a corporation.
  """
  def create_fleet_doctrine(corporation_id, doctrine_params, options \\ []) do
    case DoctrineManager.create_fleet_doctrine(corporation_id, doctrine_params, options) do
      {:ok, composition} ->
        # Immediately analyze the new composition
        analyze_fleet_composition(composition.id)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Generate counter-doctrine recommendations against a specific threat.
  """
  defdelegate generate_counter_doctrine(threat_analysis, corporation_id, options \\ []),
    to: DoctrineManager

  # Helper functions for composition analysis
  defp get_composition_record(composition_id) do
    case Ash.get(FleetComposition, composition_id, domain: EveDmv.Api) do
      {:ok, composition} -> {:ok, composition}
      {:error, reason} -> {:error, "Composition not found: #{reason}"}
    end
  end

  defp get_ship_data(doctrine_template) do
    # Extract ship types from doctrine and get their data
    ship_types = DoctrineManager.extract_ship_types_from_doctrine(doctrine_template)

    ship_data =
      ship_types
      |> Enum.map(fn ship_name ->
        {ship_name, FleetAssetManager.get_ship_info(ship_name)}
      end)
      |> Enum.into(%{})

    {:ok, ship_data}
  end

  # Public API functions - delegated to specialized modules

  @doc """
  Enhanced fleet composition analysis using ShipDatabase.
  Provides detailed ship-by-ship analysis with wormhole suitability.
  """
  defdelegate analyze_enhanced_fleet_composition(ship_list), to: FleetAnalyzer

  @doc """
  Analyze fleet composition from member data.
  """
  defdelegate analyze_fleet_composition_from_members(members), to: FleetAnalyzer

  @doc """
  Calculate wormhole viability for a fleet.
  """
  defdelegate calculate_wormhole_viability(fleet_data, wormhole), to: WormholeCompatibility

  @doc """
  Analyze doctrine compliance of a fleet.
  """
  defdelegate analyze_doctrine_compliance(fleet_members), to: FleetAnalyzer

  @doc """
  Calculate fleet effectiveness metrics.
  """
  defdelegate calculate_fleet_effectiveness(fleet_analysis), to: FleetAnalyzer

  @doc """
  Recommend fleet improvements.
  """
  defdelegate recommend_fleet_improvements(fleet_data), to: FleetAnalyzer

  @doc """
  Calculate optimal jump sequence for mass management.
  """
  defdelegate calculate_jump_mass_sequence(ships, wormhole), to: WormholeCompatibility

  @doc """
  Analyze fleet roles and balance.
  """
  defdelegate analyze_fleet_roles(fleet_members), to: FleetAnalyzer

  @doc """
  Categorize ship role based on ship name.
  """
  defdelegate categorize_ship_role(ship_name), to: FleetAnalyzer

  @doc """
  Calculate ship mass based on ship name.
  """
  defdelegate calculate_ship_mass(ship_name), to: WormholeCompatibility

  @doc """
  Check if ship is part of a specific doctrine.
  """
  defdelegate doctrine_ship?(ship_name, doctrine), to: FleetAnalyzer

  @doc """
  Calculate logistics ratio for a fleet.
  """
  defdelegate calculate_logistics_ratio(fleet_data), to: FleetAnalyzer

  @doc """
  Get wormhole mass limit by type.
  """
  defdelegate wormhole_mass_limit(wormhole_type), to: WormholeCompatibility

  @doc """
  Identify the primary doctrine of a fleet.
  """
  defdelegate identify_fleet_doctrine(fleet_members), to: FleetAnalyzer

  @doc """
  Calculate total fleet mass.
  """
  defdelegate calculate_total_fleet_mass(fleet_members), to: WormholeCompatibility

  @doc """
  Calculate average ship mass.
  """
  defdelegate calculate_average_ship_mass(fleet_members), to: WormholeCompatibility

  @doc """
  Check if fleet is compatible with wormhole.
  """
  defdelegate fleet_wormhole_compatible?(fleet_data, wormhole), to: WormholeCompatibility
end
