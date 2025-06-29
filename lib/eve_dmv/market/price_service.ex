defmodule EveDmv.Market.PriceService do
  @moduledoc """
  Unified price resolution service with fallback chain.

  Priority order:
  1. Mutamarket API (for abyssal modules only)
  2. Janice API (most accurate for current market)
  3. ESI market data (fallback)
  4. Base price from static data (last resort)

  All prices are cached to reduce API calls.
  """

  require Logger
  alias EveDmv.Market.{JaniceClient, MutamarketClient}

  # @default_market_hub "jita"  # Reserved for future use

  # Public API

  @doc """
  Get the best available price for an item.

  Returns the buy price by default, which is typically used for killmail values.

  ## Examples

      iex> PriceService.get_item_price(587)
      {:ok, 350_000.0}
      
      iex> PriceService.get_item_price(587, :sell)
      {:ok, 380_000.0}
  """
  @spec get_item_price(integer(), :buy | :sell) :: {:ok, float()} | {:error, term()}
  def get_item_price(type_id, price_type \\ :buy) do
    with {:ok, price_data} <- get_item_price_data(type_id) do
      price =
        case price_type do
          :buy -> price_data.buy_price
          :sell -> price_data.sell_price
        end

      {:ok, price}
    end
  end

  @doc """
  Get complete price data for an item including buy/sell prices and source.

  ## Examples

      iex> PriceService.get_item_price_data(587)
      {:ok, %{
        type_id: 587,
        buy_price: 350_000.0,
        sell_price: 380_000.0,
        source: :janice,
        updated_at: ~U[2024-01-01 12:00:00Z]
      }}
  """
  @spec get_item_price_data(integer()) :: {:ok, map()} | {:error, String.t()}
  def get_item_price_data(type_id, item_attributes \\ nil) do
    # Check if this might be an abyssal module
    if abyssal_item?(type_id, item_attributes) do
      # Try Mutamarket first for abyssal modules
      with {:error, _} <- try_mutamarket(type_id, item_attributes),
           {:error, _} <- try_janice(type_id),
           {:error, _} <- try_base_price(type_id) do
        Logger.warning("No price found for abyssal item #{type_id}")
        {:error, "No price available"}
      end
    else
      # Regular item pricing flow
      with {:error, _} <- try_janice(type_id),
           {:error, _} <- try_esi(type_id),
           {:error, _} <- try_base_price(type_id) do
        Logger.warning("No price found for item #{type_id}")
        {:error, "No price available"}
      end
    end
  end

  @doc """
  Get prices for multiple items efficiently.

  ## Examples

      iex> PriceService.get_item_prices([587, 588, 589])
      {:ok, %{
        587 => %{buy_price: 350_000.0, sell_price: 380_000.0, source: :janice},
        588 => %{buy_price: 450_000.0, sell_price: 480_000.0, source: :janice},
        589 => %{buy_price: 550_000.0, sell_price: 580_000.0, source: :esi}
      }}
  """
  @spec get_item_prices([integer()]) :: {:ok, map()}
  def get_item_prices(type_ids) do
    results =
      type_ids
      |> Enum.map(fn type_id ->
        case get_item_price_data(type_id) do
          {:ok, price_data} -> {type_id, price_data}
          {:error, _} -> {type_id, nil}
        end
      end)
      |> Enum.reject(fn {_type_id, data} -> is_nil(data) end)
      |> Map.new()

    {:ok, results}
  end

  @doc """
  Calculate total value for a killmail.

  Includes destroyed value and dropped value.
  """
  @spec calculate_killmail_value(map()) :: map()
  def calculate_killmail_value(killmail) do
    # Get all unique type IDs from victim and items
    type_ids = extract_type_ids(killmail)

    # Fetch prices
    {:ok, prices} = get_item_prices(type_ids)

    # Calculate victim ship value
    victim_ship_value =
      case get_in(killmail, ["victim", "ship_type_id"]) do
        nil -> 0.0
        ship_type_id ->
          case prices[ship_type_id] do
            nil -> 0.0
            price_data -> price_data.buy_price
          end
      end

    # Calculate items value
    {destroyed_value, dropped_value} =
      case get_in(killmail, ["victim", "items"]) do
        nil ->
          {0.0, 0.0}

        items ->
          items
          |> Enum.reduce({0.0, 0.0}, fn item, {destroyed, dropped} ->
            quantity = item["quantity_destroyed"] || 0
            dropped_qty = item["quantity_dropped"] || 0

            unit_price =
              case prices[item["item_type_id"]] do
                nil -> 0.0
                price_data -> price_data.buy_price
              end

            {
              destroyed + quantity * unit_price,
              dropped + dropped_qty * unit_price
            }
          end)
      end

    fitted_value = destroyed_value + dropped_value

    %{
      total_value: victim_ship_value + fitted_value,
      ship_value: victim_ship_value,
      fitted_value: fitted_value,
      price_source: determine_primary_source(prices)
    }
  end

  # Private functions

  defp try_mutamarket(type_id, attributes) do
    # TODO: Implement Mutamarket integration for abyssal modules
    # This function should query Mutamarket API for abyssal item pricing
    Logger.debug(
      "Mutamarket price lookup attempted for #{type_id} with attributes: #{inspect(attributes)}"
    )

    {:error, "Mutamarket not available"}
  end

  defp try_janice(type_id) do
    case JaniceClient.get_item_price(type_id) do
      {:ok, price_data} ->
        {:ok, Map.put(price_data, :source, :janice)}

      error ->
        Logger.debug("Janice price lookup failed for #{type_id}: #{inspect(error)}")
        error
    end
  end

  defp try_esi(type_id) do
    # TODO: Implement ESI market data integration
    # This function should query EVE ESI API for market pricing data
    Logger.debug("ESI price lookup skipped for #{type_id} - using other sources")
    {:error, "ESI not implemented"}
  end

  defp try_base_price(type_id) do
    # Look up base price from static data
    case Ash.get(EveDmv.Eve.ItemType, type_id, domain: EveDmv.Api) do
      {:ok, item} ->
        # Use base price as both buy and sell with 10% margin
        base = Decimal.to_float(item.base_price || Decimal.new(0))

        if base > 0 do
          {:ok,
           %{
             type_id: type_id,
             # 10% below base
             buy_price: base * 0.9,
             # 10% above base
             sell_price: base * 1.1,
             source: :base_price,
             updated_at: DateTime.utc_now()
           }}
        else
          {:error, "No base price"}
        end

      error ->
        error
    end
  end

  defp extract_type_ids(killmail) do
    victim_type = get_in(killmail, ["victim", "ship_type_id"])

    item_types =
      case get_in(killmail, ["victim", "items"]) do
        nil -> []
        items when is_list(items) ->
          items
          |> Enum.map(& &1["item_type_id"])
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()
        _ -> []
      end

    attacker_types =
      case killmail["attackers"] do
        nil -> []
        attackers when is_list(attackers) ->
          attackers
          |> Enum.map(& &1["ship_type_id"])
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()
        _ -> []
      end

    [victim_type | item_types ++ attacker_types]
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp determine_primary_source(prices) do
    sources =
      prices
      |> Map.values()
      |> Enum.map(& &1.source)
      |> Enum.frequencies()

    # Return the most common source
    sources
    |> Enum.max_by(fn {_source, count} -> count end, fn -> {:unknown, 0} end)
    |> elem(0)
  end

  defp abyssal_item?(type_id, attributes) do
    # Check if this is likely an abyssal module
    cond do
      # Specific abyssal type ID ranges
      type_id in 47_800..49_000 ->
        true

      # Abyssal filaments
      type_id in 52_227..52_230 ->
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
