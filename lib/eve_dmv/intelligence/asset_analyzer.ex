defmodule EveDmv.Intelligence.AssetAnalyzer do
  @moduledoc """
  Analyzes character and corporation assets to determine fleet readiness and ship availability.

  Integrates with ESI to fetch real asset data and provides:
  - Ship availability by doctrine role
  - Asset location analysis  
  - Fleet readiness scoring
  - Hangar management recommendations
  """

  require Logger
  alias EveDmv.Eve.EsiClient
  alias EveDmv.Intelligence.WHFleetComposition

  @doc """
  Analyze asset availability for a fleet composition.

  Returns a map with:
  - ship_availability: Map of ship types to available counts
  - location_analysis: Asset distribution across systems
  - readiness_score: 0-100 score for fleet readiness
  - recommendations: List of hangar management suggestions
  """
  def analyze_fleet_assets(composition_id, auth_token) do
    with {:ok, composition} <- get_composition(composition_id),
         {:ok, corp_assets} <- fetch_corporation_assets(composition.corporation_id, auth_token),
         {:ok, member_assets} <- fetch_member_assets(composition.corporation_id, auth_token) do
      all_assets = merge_assets(corp_assets, member_assets)
      ship_availability = analyze_ship_availability(all_assets, composition.doctrine_template)
      location_analysis = analyze_asset_locations(all_assets)

      readiness_score =
        calculate_readiness_score(ship_availability, composition.doctrine_template)

      recommendations =
        generate_recommendations(ship_availability, composition.doctrine_template)

      {:ok,
       %{
         ship_availability: ship_availability,
         location_analysis: location_analysis,
         readiness_score: readiness_score,
         recommendations: recommendations,
         total_ships_available: count_total_ships(ship_availability),
         assets_analyzed: length(all_assets)
       }}
    else
      {:error, reason} ->
        Logger.error("Failed to analyze fleet assets: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get ship availability for a specific corporation without a composition.
  """
  def get_corporation_ship_inventory(corporation_id, auth_token) do
    with {:ok, assets} <- EsiClient.get_corporation_assets(corporation_id, auth_token) do
      ship_assets = filter_ship_assets(assets)
      availability = group_ships_by_type(ship_assets)

      {:ok,
       %{
         ship_counts: availability,
         total_ships: count_total_from_groups(availability),
         ship_value: estimate_total_value(ship_assets)
       }}
    end
  end

  @doc """
  Get ship availability for a specific character.
  """
  def get_character_ship_inventory(character_id, auth_token) do
    with {:ok, assets} <- EsiClient.get_character_assets(character_id, auth_token) do
      ship_assets = filter_ship_assets(assets)
      availability = group_ships_by_type(ship_assets)

      {:ok,
       %{
         ship_counts: availability,
         total_ships: count_total_from_groups(availability),
         ship_value: estimate_total_value(ship_assets)
       }}
    end
  end

  # Private functions

  defp get_composition(composition_id) do
    case Ash.get(WHFleetComposition, composition_id, domain: EveDmv.Api) do
      {:ok, composition} -> {:ok, composition}
      error -> error
    end
  end

  defp fetch_corporation_assets(corporation_id, auth_token) do
    case EsiClient.get_corporation_assets(corporation_id, auth_token) do
      {:ok, assets} -> {:ok, filter_ship_assets(assets)}
      error -> error
    end
  end

  defp fetch_member_assets(_corporation_id, _auth_token) do
    # This would require individual member tokens
    # For now, return empty list
    {:ok, []}
  end

  defp merge_assets(corp_assets, member_assets) do
    corp_assets ++ member_assets
  end

  defp filter_ship_assets(assets) do
    # Filter for ship category (category_id 6)
    # This requires looking up type information
    assets
    |> Enum.filter(fn asset ->
      case get_type_category(asset.type_id) do
        # Ship category
        6 -> true
        _ -> false
      end
    end)
  end

  defp get_type_category(type_id) do
    case EsiClient.get_type(type_id) do
      {:ok, type_data} -> type_data.category_id
      _ -> nil
    end
  end

  defp analyze_ship_availability(assets, doctrine_template) do
    # Group assets by ship type
    available_ships = group_ships_by_type(assets)

    # Map doctrine requirements to available ships
    doctrine_template
    |> Enum.map(fn {role, role_config} ->
      preferred_ships = role_config["preferred_ships"] || []
      required_count = role_config["required"] || 0

      # Count available ships for this role
      available_count =
        preferred_ships
        |> Enum.map(fn ship_name ->
          Map.get(available_ships, ship_name, 0)
        end)
        |> Enum.sum()

      {role,
       %{
         "required" => required_count,
         "available" => available_count,
         "shortage" => max(0, required_count - available_count),
         "preferred_ships" => preferred_ships
       }}
    end)
    |> Enum.into(%{})
  end

  defp group_ships_by_type(assets) do
    assets
    |> Enum.group_by(fn asset ->
      case EsiClient.get_type(asset.type_id) do
        {:ok, type_data} -> type_data.name
        _ -> "Unknown Ship"
      end
    end)
    |> Enum.map(fn {ship_name, ship_assets} ->
      {ship_name, length(ship_assets)}
    end)
    |> Enum.into(%{})
  end

  defp analyze_asset_locations(assets) do
    assets
    |> Enum.group_by(& &1.location_id)
    |> Enum.map(fn {location_id, location_assets} ->
      {location_id,
       %{
         ship_count: length(location_assets),
         ship_types: location_assets |> Enum.map(& &1.type_id) |> Enum.uniq() |> length()
       }}
    end)
    |> Enum.into(%{})
    |> add_location_names()
  end

  defp add_location_names(location_map) do
    # In a real implementation, resolve location IDs to names
    # For now, return as-is
    location_map
  end

  defp calculate_readiness_score(ship_availability, doctrine_template) do
    # Calculate percentage of doctrine requirements met
    total_required =
      doctrine_template
      |> Enum.map(fn {_role, config} -> config["required"] || 0 end)
      |> Enum.sum()

    total_available =
      ship_availability
      |> Enum.map(fn {_role, availability} ->
        min(availability["available"], availability["required"])
      end)
      |> Enum.sum()

    if total_required > 0 do
      round(total_available / total_required * 100)
    else
      0
    end
  end

  defp generate_recommendations(ship_availability, _doctrine_template) do
    recommendations = []

    # Add recommendations for critical shortages
    critical_shortages =
      ship_availability
      |> Enum.filter(fn {_role, avail} ->
        avail["shortage"] > 0 and avail["required"] > 0
      end)
      |> Enum.map(fn {role, avail} ->
        "Critical shortage: Need #{avail["shortage"]} more ships for #{role} role"
      end)

    # Add recommendations for surplus
    surplus_roles =
      ship_availability
      |> Enum.filter(fn {_role, avail} ->
        avail["available"] > avail["required"] * 1.5
      end)
      |> Enum.map(fn {role, avail} ->
        "Surplus detected: #{avail["available"] - avail["required"]} extra ships for #{role} role"
      end)

    recommendations ++ critical_shortages ++ surplus_roles
  end

  defp count_total_ships(ship_availability) do
    ship_availability
    |> Enum.map(fn {_role, avail} -> avail["available"] end)
    |> Enum.sum()
  end

  defp count_total_from_groups(ship_groups) do
    ship_groups
    |> Map.values()
    |> Enum.sum()
  end

  defp estimate_total_value(ship_assets) do
    ship_assets
    |> Enum.map(fn asset ->
      case EsiClient.get_type(asset.type_id) do
        {:ok, _type_data} ->
          # Get market price
          case EsiClient.get_market_orders(asset.type_id, 10_000_002, :sell) do
            {:ok, [_ | _] = orders} ->
              orders
              |> Enum.map(& &1.price)
              |> Enum.min()
              |> Kernel.*(asset.quantity)

            _ ->
              # Default estimate
              50_000_000 * asset.quantity
          end

        _ ->
          50_000_000 * asset.quantity
      end
    end)
    |> Enum.sum()
  end
end
