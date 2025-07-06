defmodule EveDmv.Eve.EsiMarketClient do
  @moduledoc """
  Market data operations for EVE ESI API.

  This module handles all market-related API calls including
  market orders, market history, and price calculations.
  """

  alias EveDmv.Eve.EsiRequestClient

  @market_api_version "v1"

  @doc """
  Get market orders for a specific type in a region.

  ## Parameters
  - type_id: The type ID to get orders for
  - region_id: The region ID (defaults to The Forge/Jita region: 10000002)
  - order_type: :buy, :sell, or :all (defaults to :all)
  """
  @spec get_market_orders(integer(), integer(), atom()) ::
          {:ok, list(map())} | {:error, term()}
  def get_market_orders(type_id, region_id \\ 10_000_002, order_type \\ :all)
      when is_integer(type_id) and is_integer(region_id) do
    path = "/#{@market_api_version}/markets/#{region_id}/orders/"
    params = %{"type_id" => type_id}

    params =
      case order_type do
        :buy -> Map.put(params, "order_type", "buy")
        :sell -> Map.put(params, "order_type", "sell")
        :all -> params
        _ -> params
      end

    case EsiRequestClient.public_request("GET", path, params) do
      {:ok, response} ->
        {:ok, response.body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get market history for a specific type in a region.
  """
  @spec get_market_history(integer(), integer()) ::
          {:ok, list(map())} | {:error, term()}
  def get_market_history(type_id, region_id \\ 10_000_002)
      when is_integer(type_id) and is_integer(region_id) do
    path = "/#{@market_api_version}/markets/#{region_id}/history/"
    params = %{"type_id" => type_id}

    case EsiRequestClient.public_request("GET", path, params) do
      {:ok, response} ->
        {:ok, response.body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get market prices for multiple types efficiently.
  """
  @spec get_market_prices([integer()], integer()) :: {:ok, map()}
  def get_market_prices(type_ids, region_id \\ 10_000_002) when is_list(type_ids) do
    results =
      type_ids
      |> Task.async_stream(
        fn type_id ->
          case get_market_orders(type_id, region_id) do
            {:ok, orders} ->
              # Calculate best prices from orders
              best_prices = calculate_best_prices(orders)
              {type_id, best_prices}

            {:error, _} ->
              {type_id, nil}
          end
        end,
        timeout: 30_000
      )
      |> Enum.map(fn {:ok, result} -> result end)
      |> Enum.into(%{})

    {:ok, results}
  end

  # Private helper functions

  defp calculate_best_prices(orders) when is_list(orders) do
    buy_orders = Enum.filter(orders, &(&1["is_buy_order"] == true))
    sell_orders = Enum.filter(orders, &(&1["is_buy_order"] == false))

    %{
      best_buy: get_highest_price(buy_orders),
      best_sell: get_lowest_price(sell_orders)
    }
  end

  defp get_highest_price([]), do: nil

  defp get_highest_price(orders) do
    orders
    |> Enum.max_by(& &1["price"], fn -> nil end)
    |> case do
      nil -> nil
      order -> order["price"]
    end
  end

  defp get_lowest_price([]), do: nil

  defp get_lowest_price(orders) do
    orders
    |> Enum.min_by(& &1["price"], fn -> nil end)
    |> case do
      nil -> nil
      order -> order["price"]
    end
  end
end
