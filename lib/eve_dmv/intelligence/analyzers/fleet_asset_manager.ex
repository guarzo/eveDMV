defmodule EveDmv.Intelligence.Analyzers.FleetAssetManager do
  @moduledoc """
  Fleet Asset Management module with unified error handling.

  This module provides comprehensive asset management capabilities for fleet operations,
  including ship availability tracking, cost estimation, and asset requirement calculations.
  It integrates with ESI (EVE Swagger Interface) for real-time asset data when authentication
  tokens are provided.

  ## Features

  - **Ship Asset Tracking**: Track ship availability across multiple locations
  - **Cost Estimation**: Calculate ship costs based on categories and roles
  - **Asset Availability Analysis**: Determine readiness scores for fleet operations
  - **Ship Requirements**: Generate detailed ship requirements for doctrine compliance
  - **ESI Integration**: Fetch real-time asset data when auth tokens are available
  - **Wormhole Compatibility**: Assess ship suitability for wormhole operations

  ## Authentication

  Asset tracking requires valid ESI authentication tokens. Without tokens, the module
  provides placeholder data and cost estimations based on ship categories and roles.

  ## Usage

  ```elixir
  # Get asset availability for a fleet composition (using Result types)
  {:ok, asset_data} = FleetAssetManager.get_asset_availability(composition, auth_token)

  # Calculate ship costs
  cost = FleetAssetManager.estimate_ship_cost_by_category("Cruiser", "dps")

  # Build ship requirements for doctrine
  requirements = FleetAssetManager.build_ship_requirements(doctrine_template, ship_data)
  ```
  """

  use EveDmv.Intelligence.Analyzer

  alias EveDmv.Intelligence.{ShipDatabase}
  alias EveDmv.Intelligence.Analyzers.{AssetAnalyzer, MassCalculator}

  # Extracted modules
  alias EveDmv.Intelligence.Analyzers.FleetAssetManager.{
    AssetAvailability,
    ShipCostCalculator,
    RequirementsBuilder,
    ReadinessAnalyzer,
    AcquisitionPlanner
  }

  @impl EveDmv.Intelligence.AnalyzerV2
  def analysis_type, do: :fleet_asset_management

  @impl EveDmv.Intelligence.AnalyzerV2
  def analyze(_fleet_id, opts) do
    auth_token = Map.get(opts, :auth_token)
    composition = Map.get(opts, :composition)

    case get_asset_availability(composition, auth_token) do
      {:ok, asset_data} -> Result.ok(asset_data)
      {:error, reason} -> Result.error(:asset_analysis_failed, reason)
    end
  end

  @impl EveDmv.Intelligence.AnalyzerV2
  def validate_params(_fleet_id, opts) do
    if Map.has_key?(opts, :composition) do
      :ok
    else
      {:error, "Fleet composition is required"}
    end
  end

  # Custom error handling for asset management
  @impl EveDmv.ErrorHandler
  def handle_error(error, context) do
    case error.code do
      :esi_api_error ->
        # Provide fallback asset data when ESI is unavailable
        fallback_data = %{
          "asset_tracking_enabled" => false,
          "ship_availability" => %{},
          "readiness_score" => 0,
          "status" => :esi_unavailable,
          "message" => "Asset tracking unavailable - ESI service error"
        }

        {:fallback, fallback_data}

      :authentication_failed ->
        # Return no-auth asset data
        fallback_data = %{
          "asset_tracking_enabled" => false,
          "ship_availability" => %{},
          "readiness_score" => 0,
          "status" => :no_authentication,
          "message" => "Asset tracking requires authentication token"
        }

        {:fallback, fallback_data}

      _ ->
        {:propagate, error}
    end
  end

  @doc """
  Get asset availability for a fleet composition.

  This function analyzes asset availability for a given fleet composition, optionally
  using ESI authentication to fetch real-time asset data. When no auth token is provided,
  it returns placeholder data with cost estimations.

  ## Parameters

  - `composition` - Fleet composition record containing doctrine and requirements
  - `auth_token` - Optional ESI authentication token for real-time asset data

  ## Returns

  - `{:ok, asset_data}` - Asset availability data with readiness scores
  - `{:error, reason}` - Error information if asset fetching fails

  ## Examples

      # Without authentication (placeholder data)
      {:ok, assets} = FleetAssetManager.get_asset_availability(composition, nil)

      # With ESI authentication
      {:ok, assets} = FleetAssetManager.get_asset_availability(composition, auth_token)
  """
  # Delegation to AssetAvailability
  defdelegate get_asset_availability(composition, auth_token), to: AssetAvailability

  # Delegation to RequirementsBuilder
  defdelegate get_ship_info(ship_name), to: RequirementsBuilder

  # Delegation to ShipCostCalculator
  defdelegate estimate_ship_cost_by_category(category, role), to: ShipCostCalculator

  # Delegation to ShipCostCalculator
  defdelegate get_base_cost_by_category(category), to: ShipCostCalculator

  # Delegation to ShipCostCalculator
  defdelegate get_role_multiplier(role), to: ShipCostCalculator

  # Delegation to RequirementsBuilder
  defdelegate build_ship_requirements(doctrine_template, ship_data), to: RequirementsBuilder

  # Delegation to ShipCostCalculator
  defdelegate calculate_total_asset_value(ship_requirements), to: ShipCostCalculator

  # Delegation to ReadinessAnalyzer
  defdelegate analyze_asset_readiness(ship_requirements, asset_availability),
    to: ReadinessAnalyzer

  # Delegation to AssetAvailability
  defdelegate calculate_asset_distribution(asset_data), to: AssetAvailability

  # Delegation to AcquisitionPlanner
  defdelegate generate_asset_acquisition_recommendations(
                ship_requirements,
                current_assets,
                budget_limit \\ nil
              ),
              to: AcquisitionPlanner
end
