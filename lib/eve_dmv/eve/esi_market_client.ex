defmodule EveDmv.Eve.EsiMarketClient do
  @moduledoc """
  Market data operations for EVE ESI API.

  This module handles all market-related API calls including
  market orders, market history, and price calculations.
  """

  require Logger
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
          {:error, :invalid_response | :service_unavailable}
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

    case EsiRequestClient.get_request(path, params) do
      error ->
        error
    end
  end

  @doc """
  Get market history for a specific type in a region.
  """
  @spec get_market_history(integer(), integer()) ::
          {:error, :invalid_response | :service_unavailable}
  def get_market_history(type_id, region_id \\ 10_000_002)
      when is_integer(type_id) and is_integer(region_id) do
    path = "/#{@market_api_version}/markets/#{region_id}/history/"
    params = %{"type_id" => type_id}

    case EsiRequestClient.get_request(path, params) do
      error ->
        error
    end
  end

  @doc """
  Get market prices for multiple types efficiently.
  """
  @spec get_market_prices([integer()], integer()) :: {:ok, any()}
  def get_market_prices(type_ids, region_id \\ 10_000_002) when is_list(type_ids) do
    results =
      type_ids
      |> Enum.map(fn type_id ->
        Task.async(fn ->
          case get_market_orders(type_id, region_id) do
            {:error, _} -> {type_id, nil}
          end
        end)
      end)
      |> Enum.map(&Task.await(&1, 30_000))
      |> Enum.into(%{})

    {:ok, results}
  end
end
