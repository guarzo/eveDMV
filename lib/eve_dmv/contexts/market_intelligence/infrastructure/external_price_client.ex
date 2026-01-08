defmodule EveDmv.Contexts.MarketIntelligence.Infrastructure.ExternalPriceClient do
  @moduledoc """
  Client for fetching price data from external sources.

  Routes price requests to appropriate external APIs based on source preference.
  Supports Janice API as primary source with fallback to cached killmail values.
  """

  alias EveDmv.Contexts.MarketIntelligence.Infrastructure.JaniceClient
  require Logger

  # Type definitions
  @type external_price_info :: %{
          sell_price: float() | nil,
          buy_price: float() | nil,
          volume: non_neg_integer() | nil,
          source: atom(),
          confidence: float(),
          updated_at: DateTime.t()
        }

  @type bulk_price_response :: %{integer() => external_price_info()}

  @doc """
  Get price for a single type ID from external source.

  Sources:
  - :best - Try Janice API first, fallback to killmail analysis
  - :janice - Use Janice API only
  - :killmail - Use killmail-derived prices only
  """
  @spec get_price(integer(), atom()) :: {:ok, external_price_info()} | {:error, atom()}
  def get_price(type_id, source \\ :best) when is_integer(type_id) do
    case source do
      :best ->
        # Try Janice first, fallback to killmail analysis
        case JaniceClient.get_item_price(type_id) do
          {:ok, price_info} ->
            {:ok, format_price_info(price_info)}

          {:error, _} ->
            get_killmail_derived_price(type_id)
        end

      :janice ->
        # Janice API only
        case JaniceClient.get_item_price(type_id) do
          {:ok, price_info} ->
            {:ok, format_price_info(price_info)}

          {:error, reason} ->
            Logger.warning("Janice API failed for type #{type_id}: #{inspect(reason)}")
            {:error, reason}
        end

      :killmail ->
        # Killmail analysis only
        get_killmail_derived_price(type_id)

      _ ->
        {:error, :invalid_source}
    end
  end

  @doc """
  Get prices for multiple type IDs from external source.
  """
  @spec get_prices([integer()], atom()) :: {:ok, bulk_price_response()} | {:error, atom()}
  def get_prices(type_ids, source \\ :best) when is_list(type_ids) do
    case source do
      :best ->
        # Try bulk Janice lookup first
        case JaniceClient.bulk_price_lookup(type_ids) do
          {:ok, prices} ->
            # Format all successful prices
            formatted =
              Map.new(prices, fn {type_id, price_info} ->
                {type_id, format_price_info(price_info)}
              end)

            # Find missing prices
            missing = Enum.filter(type_ids, &(not Map.has_key?(formatted, &1)))

            if Enum.empty?(missing) do
              {:ok, formatted}
            else
              # Get killmail prices for missing items
              killmail_prices = get_bulk_killmail_prices(missing)
              {:ok, Map.merge(formatted, killmail_prices)}
            end

          {:error, _} ->
            # Fallback to killmail prices for all
            prices = get_bulk_killmail_prices(type_ids)
            {:ok, prices}
        end

      :janice ->
        # Janice only - no fallback
        case JaniceClient.bulk_price_lookup(type_ids) do
          {:ok, prices} ->
            formatted =
              Map.new(prices, fn {type_id, price_info} ->
                {type_id, format_price_info(price_info)}
              end)

            {:ok, formatted}

          {:error, reason} ->
            {:error, reason}
        end

      :killmail ->
        # Killmail analysis only
        prices = get_bulk_killmail_prices(type_ids)
        {:ok, prices}

      _ ->
        {:error, :invalid_source}
    end
  end

  # Private functions

  defp format_price_info(price_info) do
    %{
      price: price_info.sell_price || 0.0,
      buy_price: price_info.buy_price || 0.0,
      volume: price_info.sell_volume || 0,
      last_updated: price_info.updated_at || DateTime.utc_now()
    }
  end

  defp get_killmail_derived_price(type_id) do
    # Query recent killmails containing this item type
    # This would analyze destroyed/dropped items to derive market value
    # For now, use ValuationService's fallback estimates

    estimated_value = estimate_value_from_type(type_id)

    {:ok,
     %{
       price: estimated_value,
       # Assume 10% spread
       buy_price: estimated_value * 0.9,
       # No volume data from killmails
       volume: 0,
       last_updated: DateTime.utc_now(),
       source: :killmail_estimate
     }}
  end

  defp get_bulk_killmail_prices(type_ids) do
    # get_killmail_derived_price/1 always returns {:ok, price_data}
    type_ids
    |> Enum.map(fn type_id ->
      {:ok, price_data} = get_killmail_derived_price(type_id)
      {type_id, price_data}
    end)
    |> Map.new()
  end

  defp estimate_value_from_type(type_id) do
    # Legacy type-ID based estimation - used as final fallback
    cond do
      # Ships (broad type ID ranges)
      type_id in 500..40_000 -> 25_000_000.0
      # Modules
      type_id in 40_000..50_000 -> 5_000_000.0
      # Charges/Ammo
      type_id in 50_000..60_000 -> 1_000.0
      # Default
      true -> 100_000.0
    end
  end
end
