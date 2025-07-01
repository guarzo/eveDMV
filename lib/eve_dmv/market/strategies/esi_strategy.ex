defmodule EveDmv.Market.Strategies.EsiStrategy do
  # Default region ID for The Forge (Jita) - can be overridden by config
  @default_region_id 10_000_002
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

    # Use configured region or default to The Forge (Jita)
    region_id = Application.get_env(:eve_dmv, :market_region_id, @default_region_id)

    case EsiClient.get_market_orders(type_id, region_id) do
      {:error, reason} = error ->
        Logger.debug("ESI market lookup failed for #{type_id}: #{inspect(reason)}")
        error
    end
  end
end
