defmodule EveDmv.Market.PriceService do
  @moduledoc """
  Unified price resolution service using pluggable pricing strategies.

  Uses a strategy pattern to resolve prices through multiple sources:
  1. Mutamarket API (for abyssal modules only)
  2. Janice API (most accurate for current market)
  3. ESI market data (fallback)
  4. Base price from static data (last resort)

  Strategies are executed in priority order until one succeeds.
  All prices are cached to reduce API calls.
  """

  alias EveDmv.Market.Strategies.BasePriceStrategy
  alias EveDmv.Market.Strategies.EsiStrategy
  alias EveDmv.Market.Strategies.JaniceStrategy
  alias EveDmv.Market.Strategies.MutamarketStrategy

  require Logger

  # @default_market_hub "jita"  # Reserved for future use

  # Static list of pricing strategies in priority order
  @pricing_strategies [
    BasePriceStrategy,
    EsiStrategy,
    JaniceStrategy,
    MutamarketStrategy
  ]

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

      case price do
        nil -> {:error, "No price available for price type #{price_type}"}
        price -> {:ok, price}
      end
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
    # Get all strategies that can handle this item type
    strategies = strategies_for_item(type_id, item_attributes)

    # Try each strategy in priority order
    case try_strategies(strategies, type_id, item_attributes) do
      {:ok, price_data} ->
        {:ok, price_data}

      {:error, _} ->
        Logger.warning("No price found for item #{type_id} using any available strategy")
        {:error, "No price available"}
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
  Get information about available pricing strategies.

  ## Examples

      iex> PriceService.strategy_info()
      [
        %{name: "Mutamarket", priority: 1, module: EveDmv.Market.Strategies.MutamarketStrategy},
        %{name: "Janice", priority: 2, module: EveDmv.Market.Strategies.JaniceStrategy},
        ...
      ]
  """
  @spec strategy_info() :: [%{module: atom(), name: String.t(), priority: integer()}]
  def strategy_info do
    @pricing_strategies
    |> Enum.sort_by(& &1.priority())
    |> Enum.map(fn strategy ->
      %{
        name: strategy.name(),
        priority: strategy.priority(),
        module: strategy
      }
    end)
  end

  @doc """
  Calculate total value for a killmail.

  Includes destroyed value and dropped value.
  """
  @spec calculate_killmail_value(map()) :: map()
  def calculate_killmail_value(killmail) do
    # First try to use existing zKillboard value (much faster)
    case extract_zkb_value(killmail) do
      {:ok, zkb_value} ->
        %{
          total_value: zkb_value,
          # Estimate ship is ~70% of total
          ship_value: zkb_value * 0.7,
          # Total fitting value
          fitted_value: zkb_value * 0.3,
          # Estimate destroyed items ~20%
          destroyed_value: zkb_value * 0.2,
          # Estimate dropped items ~10%
          dropped_value: zkb_value * 0.1,
          price_source: :zkillboard
        }

      {:error, _reason} ->
        # Fallback to expensive price calculation
        Logger.debug("No zKillboard value found, calculating prices manually")
        calculate_killmail_value_from_market(killmail)
    end
  end

  # Fallback method using market price lookups (slow)
  defp calculate_killmail_value_from_market(killmail) do
    # Get all unique type IDs from victim and items
    type_ids = extract_type_ids(killmail)

    # Fetch prices
    {:ok, prices} = get_item_prices(type_ids)

    # Calculate values
    victim_ship_value = calculate_ship_value(killmail, prices)
    {destroyed_value, dropped_value} = calculate_items_value(killmail, prices)
    fitted_value = destroyed_value + dropped_value

    %{
      total_value: victim_ship_value + fitted_value,
      ship_value: victim_ship_value,
      fitted_value: fitted_value,
      destroyed_value: destroyed_value,
      dropped_value: dropped_value,
      price_source: determine_primary_source(prices)
    }
  end

  # Private functions

  defp extract_zkb_value(killmail) do
    case killmail do
      # Handle Ash resource format
      %{raw_data: %{"zkb" => %{"totalValue" => value}}} when is_number(value) ->
        {:ok, value}

      # Handle raw map format  
      %{"zkb" => %{"totalValue" => value}} when is_number(value) ->
        {:ok, value}

      _ ->
        {:error, :no_zkb_value}
    end
  end

  defp strategies_for_item(type_id, item_attributes) do
    @pricing_strategies
    |> Enum.sort_by(& &1.priority())
    |> Enum.filter(& &1.supports?(type_id, item_attributes))
  end

  defp calculate_ship_value(killmail, prices) do
    ship_type_id =
      case killmail do
        %{raw_data: %{"victim" => victim}} -> victim["ship_type_id"]
        %{"victim" => victim} -> victim["ship_type_id"]
        _ -> nil
      end

    case ship_type_id do
      nil -> 0.0
      ship_type_id -> get_item_price_from_data(prices, ship_type_id)
    end
  end

  defp calculate_items_value(killmail, prices) do
    items =
      case killmail do
        %{raw_data: %{"victim" => %{"items" => items}}} -> items
        %{"victim" => %{"items" => items}} -> items
        _ -> nil
      end

    case items do
      nil ->
        {0.0, 0.0}

      items ->
        Enum.reduce(items, {0.0, 0.0}, fn item, {destroyed, dropped} ->
          quantity = item["quantity_destroyed"] || 0
          dropped_qty = item["quantity_dropped"] || 0
          unit_price = get_item_price_from_data(prices, item["item_type_id"])

          {
            destroyed + quantity * unit_price,
            dropped + dropped_qty * unit_price
          }
        end)
    end
  end

  defp get_item_price_from_data(prices, type_id) do
    case prices[type_id] do
      nil -> 0.0
      price_data -> price_data.buy_price || 0.0
    end
  end

  defp try_strategies([], _type_id, _item_attributes) do
    {:error, "No strategies available"}
  end

  defp try_strategies([strategy | rest], type_id, item_attributes) do
    case strategy.get_price(type_id, item_attributes) do
      {:ok, price_data} ->
        Logger.debug("Price resolved for #{type_id} using #{strategy.name()}")
        {:ok, price_data}

      {:error, reason} ->
        Logger.debug("Strategy #{strategy.name()} failed for #{type_id}: #{inspect(reason)}")
        try_strategies(rest, type_id, item_attributes)
    end
  end

  defp extract_type_ids(killmail) do
    # Handle both Ash structs and raw maps
    victim_type =
      case killmail do
        %{raw_data: %{"victim" => victim}} -> victim["ship_type_id"]
        %{"victim" => victim} -> victim["ship_type_id"]
        _ -> nil
      end

    item_types =
      case killmail do
        %{raw_data: %{"victim" => %{"items" => items}}} when is_list(items) ->
          items
          |> Enum.map(& &1["item_type_id"])
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()

        %{"victim" => %{"items" => items}} when is_list(items) ->
          items
          |> Enum.map(& &1["item_type_id"])
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()

        _ ->
          []
      end

    attacker_types =
      case killmail do
        %{raw_data: %{"attackers" => attackers}} when is_list(attackers) ->
          attackers
          |> Enum.map(& &1["ship_type_id"])
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()

        %{"attackers" => attackers} when is_list(attackers) ->
          attackers
          |> Enum.map(& &1["ship_type_id"])
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()

        _ ->
          []
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
    {preferred_source, _count} =
      Enum.max_by(sources, fn {_source, count} -> count end, fn -> {:unknown, 0} end)

    preferred_source
  end
end
