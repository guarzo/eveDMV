defmodule EveDmv.Market.Strategies.JaniceStrategy do
  @moduledoc """
  Pricing strategy using the Janice API.

  Janice provides accurate real-time market data for most EVE items
  and is the primary fallback for non-abyssal items.
  """

  @behaviour EveDmv.Market.PricingStrategy

  require Logger
  alias EveDmv.Market.JaniceClient

  @impl true
  def priority, do: 2

  @impl true
  def name, do: "Janice"

  @impl true
  def supports?(_type_id, _item_attributes) do
    # Janice supports most items, so this is a general fallback
    true
  end

  @impl true
  def get_price(type_id, _item_attributes) do
    Logger.debug("Attempting Janice price lookup for #{type_id}")

    case JaniceClient.get_item_price(type_id) do
      {:ok, price_data} ->
        result = Map.put(price_data, :source, :janice)
        Logger.debug("Janice price lookup successful for #{type_id}")
        {:ok, result}

      error ->
        Logger.debug("Janice price lookup failed for #{type_id}: #{inspect(error)}")
        error
    end
  end
end
