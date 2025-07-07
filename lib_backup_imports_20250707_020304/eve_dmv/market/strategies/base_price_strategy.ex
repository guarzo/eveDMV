defmodule EveDmv.Market.Strategies.BasePriceStrategy do
  require Logger
  @moduledoc """
  Fallback pricing strategy using EVE SDE base prices.

  This strategy uses the base NPC prices from the Static Data Export
  as a last resort when no market data is available.
  """

  @behaviour EveDmv.Market.PricingStrategy


  @impl true
  def priority, do: 4

  @impl true
  def name, do: "Base Price"

  @impl true
  def supports?(_type_id, _item_attributes) do
    # Base price strategy supports all items as a last resort
    true
  end

  @impl true
  def get_price(type_id, _item_attributes) do
    Logger.debug("Attempting base price lookup for #{type_id}")

    case Ash.get(EveDmv.Eve.ItemType, type_id, domain: EveDmv.Api) do
      {:ok, item} ->
        handle_base_price_result(type_id, item)

      error ->
        Logger.debug("Base price lookup failed for #{type_id}: #{inspect(error)}")
        error
    end
  end

  # Private functions

  defp handle_base_price_result(type_id, item) do
    base_decimal = item.base_price || Decimal.new(0)

    if Decimal.gt?(base_decimal, 0) do
      # Calculate buy/sell prices with 10% margin using Decimal arithmetic
      buy_price_decimal = Decimal.mult(base_decimal, Decimal.new("0.9"))
      sell_price_decimal = Decimal.mult(base_decimal, Decimal.new("1.1"))

      result = %{
        type_id: type_id,
        # Convert to float only at the final step for compatibility
        buy_price: Decimal.to_float(buy_price_decimal),
        sell_price: Decimal.to_float(sell_price_decimal),
        source: :base_price,
        updated_at: DateTime.utc_now()
      }

      Logger.debug("Base price lookup successful for #{type_id}")
      {:ok, result}
    else
      Logger.debug("No base price available for #{type_id}")
      {:error, "No base price available"}
    end
  end
end
