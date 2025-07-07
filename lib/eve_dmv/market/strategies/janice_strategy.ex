defmodule EveDmv.Market.Strategies.JaniceStrategy do
  @moduledoc """
  Pricing strategy using the Janice API.

  Janice provides accurate real-time market data for most EVE items
  and is the primary fallback for non-abyssal items.
  """

  @behaviour EveDmv.Market.PricingStrategy

  alias EveDmv.Market.JaniceClient
  require Logger

  @impl EveDmv.Market.PricingStrategy
  def priority, do: 3

  @impl EveDmv.Market.PricingStrategy
  def name, do: "Janice"

  @impl EveDmv.Market.PricingStrategy
  def supports?(_type_id, _item_attributes) do
    # Check if Janice is enabled in configuration
    case Application.get_env(:eve_dmv, :janice, []) do
      config when is_list(config) ->
        Keyword.get(config, :enabled, true)

      _ ->
        true
    end
  end

  @impl EveDmv.Market.PricingStrategy
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
