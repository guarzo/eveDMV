defmodule EveDmv.Intelligence.Analyzers.AssetAnalyzer do
  @moduledoc """
  Analyzes character and corporation assets to determine fleet readiness and ship availability.

  Integrates with ESI to fetch real asset data and provides:
  - Ship availability by doctrine role
  - Asset location analysis
  - Fleet readiness scoring
  - Hangar management recommendations
  """

  alias EveDmv.Eve.EsiCache
  alias EveDmv.Eve.EsiClient
  alias EveDmv.Intelligence.WhSpace.FleetComposition

  require Logger

  @doc """
  Analyze asset availability for a fleet composition.

  Returns a map with:
  - ship_availability: Map of ship types to available counts
  - location_analysis: Asset distribution across systems
  - readiness_score: 0-100 score for fleet readiness
  - recommendations: List of hangar management suggestions
  """
  def analyze_fleet_assets(composition_id, auth_token) do
    case get_composition(composition_id) do
      {:ok, composition} ->
        # Try to fetch assets, but handle failures gracefully
        corp_assets =
          case fetch_corporation_assets(composition.corporation_id, auth_token) do
            {:ok, assets} -> assets
            {:error, _reason} -> []
          end

        # fetch_member_assets always returns {:ok, []}, no need for error handling
        {:ok, member_assets} = fetch_member_assets(composition.corporation_id, auth_token)

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

      {:error, reason} ->
        Logger.error("Failed to analyze fleet assets: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get ship availability for a specific corporation without a composition.
  """
  def get_corporation_ship_inventory(corporation_id, auth_token) do
    case EsiClient.get_corporation_assets(corporation_id, auth_token) do
      {:ok, assets} ->
        # Filter for ships and return inventory
        ships = Enum.filter(assets, &ship_asset?/1)
        {:ok, ships}

      {:error, reason} ->
        Logger.warning("Failed to fetch corporation assets: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get ship availability for a specific character.
  """
  def get_character_ship_inventory(character_id, auth_token) do
    case EsiClient.get_character_assets(character_id, auth_token) do
      {:ok, assets} ->
        # Filter for ships and return inventory
        ships = Enum.filter(assets, &ship_asset?/1)
        {:ok, ships}

      {:error, reason} ->
        Logger.warning("Failed to fetch character assets: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp ship_asset?(asset) do
    # Ships are typically in groups 25 (Frigate), 26 (Cruiser), 27 (Battleship), etc.
    # This is a simplified check - in practice you'd need to look up the type_id
    # in the EVE static data to determine if it's a ship
    Map.get(asset, "group_id", 0) in [
      25,
      26,
      27,
      28,
      29,
      30,
      31,
      237,
      324,
      358,
      380,
      419,
      420,
      463,
      485,
      513,
      540,
      541,
      543,
      547,
      659,
      830,
      831,
      832,
      833,
      834,
      883,
      893,
      894,
      898,
      900,
      902,
      906,
      941,
      963,
      1022,
      1201,
      1202,
      1283,
      1305,
      1527,
      1534,
      1538,
      1540,
      1972,
      1973,
      1974,
      1975,
      1976,
      2016
    ]
  end

  defp get_composition(composition_id) do
    case Ash.get(FleetComposition, composition_id, domain: EveDmv.Api) do
      {:ok, composition} -> {:ok, composition}
      error -> error
    end
  end

  defp fetch_corporation_assets(corporation_id, auth_token) do
    case EsiClient.get_corporation_assets(corporation_id, auth_token) do
      {:ok, assets} -> {:ok, assets}
      {:error, reason} -> {:error, reason}
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

  defp analyze_ship_availability(assets, doctrine_template) do
    # Group assets by ship type
    available_ships = group_ships_by_type(assets)

    # Map doctrine requirements to available ships
    Enum.into(
      Enum.map(doctrine_template, fn {role, role_config} ->
        preferred_ships = role_config["preferred_ships"] || []
        required_count = role_config["required"] || 0

        # Count available ships for this role
        available_count =
          Enum.sum(
            Enum.map(preferred_ships, fn ship_name ->
              Map.get(available_ships, ship_name, 0)
            end)
          )

        {role,
         %{
           "required" => required_count,
           "available" => available_count,
           "shortage" => max(0, required_count - available_count),
           "preferred_ships" => preferred_ships
         }}
      end),
      %{}
    )
  end

  defp group_ships_by_type(assets) do
    assets
    |> Enum.group_by(fn asset ->
      case EsiCache.get_type(asset.type_id) do
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
         ship_types: location_assets |> Stream.map(& &1.type_id) |> Enum.uniq() |> length()
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
      Enum.sum(Enum.map(doctrine_template, fn {_role, config} -> config["required"] || 0 end))

    total_available =
      Enum.sum(
        Enum.map(ship_availability, fn {_role, availability} ->
          min(availability["available"], availability["required"])
        end)
      )

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
      Enum.map(
        Enum.filter(ship_availability, fn {_role, avail} ->
          avail["shortage"] > 0 and avail["required"] > 0
        end),
        fn {role, avail} ->
          "Critical shortage: Need #{avail["shortage"]} more ships for #{role} role"
        end
      )

    # Add recommendations for surplus
    surplus_roles =
      Enum.map(
        Enum.filter(ship_availability, fn {_role, avail} ->
          avail["available"] > avail["required"] * 1.5
        end),
        fn {role, avail} ->
          "Surplus detected: #{avail["available"] - avail["required"]} extra ships for #{role} role"
        end
      )

    recommendations ++ critical_shortages ++ surplus_roles
  end

  defp count_total_ships(ship_availability) do
    Enum.sum(Enum.map(ship_availability, fn {_role, avail} -> avail["available"] end))
  end
end
