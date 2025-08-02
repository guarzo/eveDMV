defmodule EveDmv.Market.Strategies.EsiStrategy do
  @moduledoc """
  Pricing strategy using EVE ESI market data.

  This strategy queries the EVE Online ESI API for market data,
  typically from major trade hubs like Jita.
  """

  @behaviour EveDmv.Market.PricingStrategy

  alias EveDmv.Eve.EsiMarketClient

  require Logger

  # Default region ID for The Forge (Jita) - can be overridden by config
  @default_region_id 10_000_002

  @impl EveDmv.Market.PricingStrategy
  def priority, do: 2

  @impl EveDmv.Market.PricingStrategy
  def name, do: "ESI Market Data"

  @impl EveDmv.Market.PricingStrategy
  def supports?(_type_id, _item_attributes) do
    # ESI supports all published items
    true
  end

  @impl EveDmv.Market.PricingStrategy
  def get_price(type_id, _item_attributes) do
    Logger.debug("Attempting ESI market data lookup for #{type_id}")

    # Use configured region or default to The Forge (Jita)
    region_id = Application.get_env(:eve_dmv, :market_region_id, @default_region_id)

    case EsiMarketClient.get_market_orders(type_id, region_id) do
      {:ok, orders} ->
        # Handle potential double-wrapping from fallback mechanisms
        actual_orders =
          case orders do
            {:ok, %{body: order_list}} when is_list(order_list) ->
              Logger.debug("ESI strategy: unwrapping double-wrapped response for #{type_id}")
              order_list

            order_list when is_list(order_list) ->
              order_list

            other ->
              Logger.warning(
                "ESI strategy: unexpected orders format for #{type_id}: #{inspect(other)}"
              )

              []
          end

        Logger.debug("ESI strategy received #{length(actual_orders)} orders for type #{type_id}")
        # Calculate median price from sell orders
        case calculate_market_price(actual_orders) do
          {:ok, price} ->
            Logger.debug("ESI market price for #{type_id}: #{price}")

            price_data = %{
              type_id: type_id,
              buy_price: price,
              # Add 5% margin for sell price
              sell_price: price * 1.05,
              source: :esi,
              updated_at: DateTime.utc_now()
            }

            {:ok, price_data}

          {:error, reason} ->
            Logger.debug("Failed to calculate market price for #{type_id}: #{reason}")
            {:error, reason}
        end

      {:error, reason} = error ->
        Logger.debug("ESI market lookup failed for #{type_id}: #{inspect(reason)}")
        error
    end
  end

  # Calculate a representative market price from order data
  defp calculate_market_price([]), do: {:error, :no_orders}

  defp calculate_market_price(orders) do
    Logger.debug(
      "calculate_market_price called with: is_list=#{inspect(is_list(orders))}, length=#{if is_list(orders), do: length(orders), else: "N/A"}"
    )

    # Filter sell orders only (is_buy_order: false)
    sell_orders =
      orders
      |> Enum.filter(&(!&1["is_buy_order"]))
      |> Enum.sort_by(& &1["price"])

    case sell_orders do
      [] ->
        {:error, :no_sell_orders}

      sell_orders ->
        # Use the lowest 20% of sell orders to get market price
        count = length(sell_orders)
        sample_size = max(1, div(count, 5))

        price_sample =
          sell_orders
          |> Enum.take(sample_size)
          |> Enum.map(& &1["price"])

        avg_price = Enum.sum(price_sample) / length(price_sample)
        {:ok, avg_price}
    end
  end
end
