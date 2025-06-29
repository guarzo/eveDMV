defmodule EveDmv.Market.Strategies.EsiStrategy do
  @moduledoc """
  Pricing strategy using EVE ESI market data.

  This strategy queries the EVE Online ESI API for market data,
  typically from major trade hubs like Jita.
  """

  @behaviour EveDmv.Market.PricingStrategy

  require Logger
  alias EveDmv.Eve.EsiClient

  @impl true
  def priority, do: 2

  @impl true
  def name, do: "ESI Market Data"

  @impl true
  def supports?(_type_id, _item_attributes) do
    # ESI supports all published items
    true
  end

  @impl true
  def get_price(type_id, _item_attributes) do
    Logger.debug("Attempting ESI market data lookup for #{type_id}")

    # Use The Forge region (Jita) as default market hub
    region_id = 10_000_002

    case EsiClient.get_market_orders(type_id, region_id) do
      {:ok, orders} when orders != [] ->
        # Calculate prices from market orders
        market_stats = calculate_market_statistics(orders)

        {:ok,
         %{
           type_id: type_id,
           buy_price: market_stats.buy_price,
           sell_price: market_stats.sell_price,
           source: :esi,
           region_id: region_id,
           region_name: "The Forge",
           volume: market_stats.volume,
           buy_orders: market_stats.buy_orders_count,
           sell_orders: market_stats.sell_orders_count,
           updated_at: DateTime.utc_now()
         }}

      {:ok, []} ->
        # No orders found - might be a rarely traded item
        Logger.debug("No market orders found for #{type_id} in The Forge")
        {:error, "No market orders available"}

      {:error, :not_found} ->
        # Invalid type ID
        {:error, "Type #{type_id} not found"}

      {:error, reason} = error ->
        Logger.debug("ESI market lookup failed for #{type_id}: #{inspect(reason)}")
        error
    end
  end

  # Private functions

  defp calculate_market_statistics(orders) do
    buy_orders = Enum.filter(orders, & &1.is_buy_order)
    sell_orders = Enum.reject(orders, & &1.is_buy_order)

    %{
      buy_price: calculate_percentile_price(buy_orders, 0.95, :desc),
      sell_price: calculate_percentile_price(sell_orders, 0.05, :asc),
      volume: Enum.reduce(orders, 0, &(&1.volume_remain + &2)),
      buy_orders_count: length(buy_orders),
      sell_orders_count: length(sell_orders)
    }
  end

  defp calculate_percentile_price([], _percentile, _sort_order), do: nil

  defp calculate_percentile_price(orders, percentile, sort_order) do
    sorted_orders =
      case sort_order do
        :asc -> Enum.sort_by(orders, & &1.price)
        :desc -> Enum.sort_by(orders, & &1.price, :desc)
      end

    total_volume = Enum.reduce(sorted_orders, 0, &(&1.volume_remain + &2))
    target_volume = total_volume * percentile

    {_accumulated, price} =
      Enum.reduce_while(sorted_orders, {0, 0}, fn order, {acc_volume, _price} ->
        new_volume = acc_volume + order.volume_remain

        if new_volume >= target_volume do
          {:halt, {new_volume, order.price}}
        else
          {:cont, {new_volume, order.price}}
        end
      end)

    price
  end
end
