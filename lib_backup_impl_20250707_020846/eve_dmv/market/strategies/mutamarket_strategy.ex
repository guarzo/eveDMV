defmodule EveDmv.Market.Strategies.MutamarketStrategy do
  # Abyssal module type ID ranges
  @abyssal_module_range 47_800..49_000
  # Abyssal filament type ID ranges
  @abyssal_filament_range 52_227..52_230
  @moduledoc """
  Pricing strategy for abyssal modules using the Mutamarket API.

  This strategy has the highest priority for abyssal modules as it provides
  the most accurate pricing for mutated modules with custom attributes.
  """

  @behaviour EveDmv.Market.PricingStrategy

  alias EveDmv.Market.MutamarketClient
  require Logger

  @impl true
  def priority, do: 1

  @impl true
  def name, do: "Mutamarket"

  @impl true
  def supports?(type_id, item_attributes) do
    abyssal_item?(type_id, item_attributes)
  end

  @impl true
  def get_price(type_id, item_attributes) do
    Logger.debug("Attempting Mutamarket price lookup for #{type_id}")

    # Only attempt Mutamarket pricing if we have attributes
    # (regular items without mutations should use other strategies)
    if not is_nil(item_attributes) and map_size(item_attributes) > 0 do
      case MutamarketClient.estimate_abyssal_price(type_id, item_attributes) do
        {:ok, price_data} ->
          # Convert Mutamarket response to our standard price format
          {:ok,
           %{
             type_id: type_id,
             buy_price: price_data.estimated_price,
             # Add 10% markup for sell price
             sell_price: price_data.estimated_price * 1.1,
             source: :mutamarket,
             confidence: price_data.confidence,
             similar_count: price_data.similar_count,
             updated_at: price_data.updated_at || DateTime.utc_now()
           }}

        {:error, reason} = error ->
          Logger.debug("Mutamarket price lookup failed for #{type_id}: #{inspect(reason)}")
          error
      end
    else
      # No attributes provided - try to get type statistics instead
      case MutamarketClient.get_type_statistics(type_id) do
        {:ok, stats} ->
          {:ok,
           %{
             type_id: type_id,
             buy_price: stats.average_price || stats.median_price,
             sell_price: (stats.average_price || stats.median_price) * 1.1,
             source: :mutamarket,
             total_listed: stats.total_listed,
             price_range: stats.price_range,
             updated_at: stats.updated_at || DateTime.utc_now()
           }}

        {:error, :not_found} ->
          # Not an abyssal type
          {:error, "Type #{type_id} not found in Mutamarket"}

        {:error, reason} = error ->
          Logger.debug("Mutamarket type stats lookup failed for #{type_id}: #{inspect(reason)}")
          error
      end
    end
  end

  # Private functions

  defp abyssal_item?(type_id, attributes) do
    cond do
      # Specific abyssal type ID ranges
      type_id in @abyssal_module_range ->
        true

      # Abyssal filaments
      type_id in @abyssal_filament_range ->
        true

      # Check attributes if provided
      not is_nil(attributes) and map_size(attributes) > 0 ->
        MutamarketClient.abyssal_module?(%{"type_id" => type_id, "attributes" => attributes})

      # Default to false
      true ->
        false
    end
  end
end
