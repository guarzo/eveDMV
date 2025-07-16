defmodule EveDmv.Contexts.MarketIntelligence.Domain.ValuationService do
  @moduledoc """
  Service for calculating asset and killmail valuations.

  Provides market value calculations for killmails and fleet compositions
  using Janice API for accurate market pricing with fallback estimates.
  """

  alias EveDmv.Contexts.MarketIntelligence.Infrastructure.JaniceClient
  require Logger

  # Fallback ship base prices (in ISK) for when API is unavailable
  @fallback_ship_prices %{
    # Frigates
    582 => 500_000,
    583 => 500_000,
    584 => 500_000,
    585 => 500_000,
    # Cruisers
    620 => 10_000_000,
    621 => 10_000_000,
    622 => 10_000_000,
    623 => 10_000_000,
    # Battleships
    638 => 150_000_000,
    639 => 150_000_000,
    640 => 150_000_000,
    641 => 150_000_000,
    # Strategic Cruisers
    29_984 => 300_000_000,
    29_986 => 300_000_000,
    29_988 => 300_000_000,
    29_990 => 300_000_000,
    # Capitals
    19_724 => 1_500_000_000,
    19_722 => 1_500_000_000,
    19_726 => 1_500_000_000,
    19_720 => 1_500_000_000
  }

  # Ship value estimates by category for fallback valuation
  @ship_estimates_by_category %{
    "frigate" => 1_500_000,
    "destroyer" => 3_000_000,
    "cruiser" => 15_000_000,
    "battlecruiser" => 60_000_000,
    "battleship" => 150_000_000,
    "capital" => 1_200_000_000,
    "supercapital" => 20_000_000_000,
    "unknown" => 10_000_000
  }

  @doc """
  Calculate the total value of a killmail.
  """
  @spec calculate_killmail_value(map()) :: {:ok, map()}
  def calculate_killmail_value(killmail) do
    Logger.debug("Calculating value for killmail #{killmail[:killmail_id]}")

    # Calculate ship hull value
    ship_value = estimate_ship_value(killmail[:victim_ship_type_id])

    # Calculate module values from items
    {destroyed_value, dropped_value} = calculate_item_values(killmail[:items] || [])

    # Calculate cargo value if present
    cargo_value = calculate_cargo_value(killmail[:cargo_items] || [])

    total_value = ship_value + destroyed_value + dropped_value + cargo_value

    valuation = %{
      killmail_id: killmail[:killmail_id],
      ship_value: ship_value,
      destroyed_value: destroyed_value,
      dropped_value: dropped_value,
      cargo_value: cargo_value,
      total_value: total_value,
      calculated_at: DateTime.utc_now()
    }

    {:ok, valuation}
  end

  @doc """
  Calculate the total value of a fleet composition.
  """
  @spec calculate_fleet_value([map()]) :: {:ok, map()}
  def calculate_fleet_value(ships) do
    Logger.debug("Calculating fleet value for #{length(ships)} ships")

    # Calculate individual ship values
    ship_values =
      Enum.map(ships, fn ship ->
        ship_type_id = ship[:type_id] || ship["type_id"]
        quantity = ship[:quantity] || ship["quantity"] || 1

        unit_value = estimate_ship_value(ship_type_id)
        total_value = unit_value * quantity

        %{
          ship_type_id: ship_type_id,
          ship_name: ship[:type_name] || ship["type_name"] || "Unknown Ship",
          quantity: quantity,
          unit_value: unit_value,
          total_value: total_value
        }
      end)

    # Calculate fleet summary
    total_ships = Enum.sum(Enum.map(ship_values, & &1.quantity))
    total_value = Enum.sum(Enum.map(ship_values, & &1.total_value))

    # Group by ship class for analysis
    by_class = group_ships_by_class(ship_values)

    fleet_valuation = %{
      total_ships: total_ships,
      total_value: total_value,
      average_ship_value: if(total_ships > 0, do: total_value / total_ships, else: 0.0),
      ship_values: ship_values,
      value_by_class: by_class,
      calculated_at: DateTime.utc_now()
    }

    {:ok, fleet_valuation}
  end

  # Private helper functions

  defp estimate_ship_value(ship_type_id) when is_integer(ship_type_id) do
    # First try to get price from Janice API
    case JaniceClient.get_ship_price(ship_type_id) do
      {:ok, price_info} ->
        # Use sell price as the primary value (what it costs to buy the ship)
        price = price_info.sell_price
        
        if price > 0 do
          Logger.debug("Got ship price from Janice: type_id=#{ship_type_id}, price=#{price}")
          price
        else
          # Fallback to estimates if API returns zero price
          fallback_ship_value(ship_type_id)
        end
        
      {:error, :rate_limited} ->
        Logger.warning("Janice API rate limited, using fallback for ship #{ship_type_id}")
        fallback_ship_value(ship_type_id)
        
      {:error, :not_found} ->
        Logger.debug("Ship type #{ship_type_id} not found in Janice, using fallback")
        fallback_ship_value(ship_type_id)
        
      {:error, reason} ->
        Logger.warning("Janice API error for ship #{ship_type_id}: #{inspect(reason)}, using fallback")
        fallback_ship_value(ship_type_id)
    end
  end

  # Default fallback
  defp estimate_ship_value(_), do: 10_000_000
  
  # Fallback function when API is unavailable
  defp fallback_ship_value(ship_type_id) do
    # First check if we have a hardcoded fallback price
    case Map.get(@fallback_ship_prices, ship_type_id) do
      nil ->
        # Use ship classification for better categorization
        category = EveDmv.Intelligence.ShipDatabase.get_ship_category(ship_type_id)
        category_key = String.downcase(category)
        Map.get(@ship_estimates_by_category, category_key, @ship_estimates_by_category["unknown"])
        
      price ->
        price
    end
  end

  defp calculate_item_values(items) do
    # Extract all unique item type IDs for bulk pricing
    item_type_ids = 
      items
      |> Enum.map(&(&1["item_type_id"]))
      |> Enum.uniq()
      |> Enum.filter(&is_integer/1)
    
    # Get prices in bulk for efficiency
    item_prices = get_bulk_item_prices(item_type_ids)
    
    # Calculate destroyed and dropped values from killmail items
    {destroyed_total, dropped_total} =
      Enum.reduce(items, {0, 0}, fn item, {dest_acc, drop_acc} ->
        quantity = item["quantity_destroyed"] || 0
        dropped_qty = item["quantity_dropped"] || 0
        item_type_id = item["item_type_id"]
        
        # Get price from bulk lookup or estimate
        item_value = Map.get(item_prices, item_type_id, estimate_item_value(item_type_id))
        
        {
          dest_acc + quantity * item_value,
          drop_acc + dropped_qty * item_value
        }
      end)

    {destroyed_total, dropped_total}
  end
  
  # Helper function to get bulk prices
  defp get_bulk_item_prices([]), do: %{}
  
  defp get_bulk_item_prices(type_ids) when length(type_ids) <= 100 do
    case JaniceClient.bulk_price_lookup(type_ids) do
      {:ok, prices} ->
        # Convert price info to simple price map
        Map.new(prices, fn {type_id, price_info} ->
          {type_id, price_info.sell_price}
        end)
        
      {:error, reason} ->
        Logger.warning("Bulk price lookup failed: #{inspect(reason)}, using individual lookups")
        %{}
    end
  end
  
  defp get_bulk_item_prices(type_ids) do
    # Split into chunks of 100 for API limits
    type_ids
    |> Enum.chunk_every(100)
    |> Enum.reduce(%{}, fn chunk, acc ->
      chunk_prices = get_bulk_item_prices(chunk)
      Map.merge(acc, chunk_prices)
    end)
  end

  defp calculate_cargo_value(cargo_items) do
    # Simple cargo valuation
    Enum.sum(
      Enum.map(cargo_items, fn item ->
        quantity = item["quantity"] || 0
        estimate_item_value(item["item_type_id"]) * quantity
      end)
    )
  end

  defp estimate_item_value(item_type_id) when is_integer(item_type_id) do
    # Use Janice API for accurate item pricing
    case JaniceClient.get_item_price(item_type_id) do
      {:ok, price_info} ->
        # Use sell price as the primary value
        price = price_info.sell_price
        
        if price > 0 do
          price
        else
          # Fallback to estimates if API returns zero price
          fallback_item_value(item_type_id)
        end
        
      {:error, :rate_limited} ->
        # Silently fallback on rate limit for items (too many to log)
        fallback_item_value(item_type_id)
        
      {:error, _reason} ->
        # Use fallback for any API errors
        fallback_item_value(item_type_id)
    end
  end

  defp estimate_item_value(_), do: 100_000
  
  # Fallback function for item values when API is unavailable
  defp fallback_item_value(item_type_id) do
    # Basic item value estimation based on type ID ranges
    cond do
      # High-value module ranges (deadspace/faction/officer)
      item_type_id in 14_000..15_000 -> 50_000_000
      item_type_id in 17_000..18_000 -> 100_000_000
      item_type_id in 19_000..20_000 -> 500_000_000
      # Standard modules
      item_type_id < 10_000 -> 1_000_000
      # Ammo/Charges
      item_type_id < 20_000 -> 1_000
      # Drones
      item_type_id < 30_000 -> 500_000
      # Implants
      item_type_id < 40_000 -> 10_000_000
      # Default
      true -> 100_000
    end
  end

  defp group_ships_by_class(ship_values) do
    ship_values
    |> Enum.group_by(&classify_ship_by_value(&1.unit_value))
    |> Enum.map(fn {class, ships} ->
      {class,
       %{
         count: Enum.sum(Enum.map(ships, & &1.quantity)),
         value: Enum.sum(Enum.map(ships, & &1.total_value))
       }}
    end)
    |> Map.new()
  end

  defp classify_ship_by_value(value) do
    cond do
      value < 5_000_000 -> :frigate
      value < 50_000_000 -> :cruiser
      value < 200_000_000 -> :battlecruiser
      value < 500_000_000 -> :battleship
      value < 2_000_000_000 -> :capital
      true -> :supercapital
    end
  end
end
