defmodule EveDmv.Contexts.MarketIntelligence.Domain.ValuationService do
  @moduledoc """
  Service for calculating asset and killmail valuations.

  Provides market value calculations for killmails and fleet compositions
  using cached price data and fallback estimates.
  """

  require Logger

  # Common ship base prices (in ISK) for estimation
  @ship_base_prices %{
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

  @doc """
  Calculate the total value of a killmail.
  """
  @spec calculate_killmail_value(map()) :: {:ok, map()} | {:error, term()}
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
  @spec calculate_fleet_value([map()]) :: {:ok, map()} | {:error, term()}
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
      average_ship_value: if(total_ships > 0, do: div(total_value, total_ships), else: 0),
      ship_values: ship_values,
      value_by_class: by_class,
      calculated_at: DateTime.utc_now()
    }

    {:ok, fleet_valuation}
  end

  # Private helper functions

  defp estimate_ship_value(ship_type_id) when is_integer(ship_type_id) do
    # Use cached prices or fallback to estimates
    case Map.get(@ship_base_prices, ship_type_id) do
      nil ->
        # Estimate based on ship type ID ranges
        cond do
          # Tech 1 frigates
          ship_type_id < 1000 -> 1_000_000
          # Tech 1 cruisers
          ship_type_id < 2000 -> 10_000_000
          # Tech 1 battleships
          ship_type_id < 5000 -> 100_000_000
          # Tech 2 ships
          ship_type_id < 20_000 -> 200_000_000
          # Capitals
          ship_type_id < 30_000 -> 1_000_000_000
          # Supercapitals
          true -> 5_000_000_000
        end

      price ->
        price
    end
  end

  # Default fallback
  defp estimate_ship_value(_), do: 10_000_000

  defp calculate_item_values(items) do
    # Calculate destroyed and dropped values from killmail items
    destroyed = 0
    dropped = 0

    {destroyed_total, dropped_total} =
      Enum.reduce(items, {destroyed, dropped}, fn item, {dest_acc, drop_acc} ->
        quantity = item["quantity_destroyed"] || 0
        dropped_qty = item["quantity_dropped"] || 0

        # Estimate item value based on type
        item_value = estimate_item_value(item["item_type_id"])

        {
          dest_acc + quantity * item_value,
          drop_acc + dropped_qty * item_value
        }
      end)

    {destroyed_total, dropped_total}
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
    # Basic item value estimation
    cond do
      # Modules
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

  defp estimate_item_value(_), do: 100_000

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
