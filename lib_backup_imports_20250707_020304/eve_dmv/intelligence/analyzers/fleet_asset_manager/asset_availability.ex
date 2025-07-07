defmodule EveDmv.Intelligence.Analyzers.FleetAssetManager.AssetAvailability do
  alias EveDmv.Intelligence.Analyzers.AssetAnalyzer

  require Logger
  @moduledoc """
  Asset availability tracking and ESI integration module.

  Handles real-time asset tracking through ESI integration and provides
  fallback placeholder data when authentication tokens are not available.
  """



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
  """
  def get_asset_availability(_composition, nil) do
    # No auth token provided, return placeholder data
    {:ok,
     %{
       "asset_tracking_enabled" => false,
       "ship_availability" => %{},
       "readiness_score" => 0,
       "message" => "Asset tracking requires authentication token"
     }}
  end

  def get_asset_availability(composition, auth_token) do
    # Use AssetAnalyzer to get real asset data
    case AssetAnalyzer.analyze_fleet_assets(composition.id, auth_token) do
      {:error, reason} ->
        Logger.warning("Failed to fetch asset data: #{inspect(reason)}")

        # Return empty asset data on failure
        {:ok,
         %{
           "asset_tracking_enabled" => false,
           "ship_availability" => %{},
           "readiness_score" => 0,
           "error" => "Failed to fetch asset data"
         }}

      {:ok, asset_analysis} ->
        {:ok, Map.put(asset_analysis, "asset_tracking_enabled", true)}
    end
  end

  @doc """
  Calculate asset distribution across locations.

  This function analyzes how assets are distributed across different stations
  and systems, useful for logistics planning and asset consolidation.
  """
  def calculate_asset_distribution(_asset_data) do
    # Mock implementation for demonstration
    # In production, this would analyze real ESI asset data
    %{
      locations: [
        %{name: "Jita IV - Moon 4", ships: 15, systems: ["Jita"]},
        %{name: "Amarr VIII - Emperor Family Academy", ships: 8, systems: ["Amarr"]},
        %{name: "Dodixie IX - Moon 20", ships: 3, systems: ["Dodixie"]}
      ],
      consolidation_score: 65,
      primary_staging: "Jita IV - Moon 4",
      logistics_complexity: 35
    }
  end

  @doc """
  Extract ship availability data from ESI asset response.
  """
  def extract_ship_availability(asset_data) do
    Map.get(asset_data, "ship_availability", %{})
  end

  @doc """
  Validate asset tracking authentication.
  """
  def validate_auth_token(nil), do: {:error, :no_token}
  def validate_auth_token(""), do: {:error, :empty_token}
  def validate_auth_token(token) when is_binary(token), do: {:ok, token}
  def validate_auth_token(_), do: {:error, :invalid_token}

  @doc """
  Get asset tracking status.
  """
  def get_tracking_status(asset_data) do
    enabled = Map.get(asset_data, "asset_tracking_enabled", false)
    score = Map.get(asset_data, "readiness_score", 0)

    %{
      enabled: enabled,
      readiness_score: score,
      tracking_quality: determine_tracking_quality(enabled, score)
    }
  end

  # Private functions

  defp determine_tracking_quality(false, _), do: "unavailable"
  defp determine_tracking_quality(true, score) when score >= 80, do: "excellent"
  defp determine_tracking_quality(true, score) when score >= 60, do: "good"
  defp determine_tracking_quality(true, score) when score >= 40, do: "fair"
  defp determine_tracking_quality(true, _), do: "poor"
end
