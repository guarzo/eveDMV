defmodule EveDmv.Contexts.MarketIntelligence.Infrastructure.ExternalPriceClient do
  @moduledoc """
  Client for fetching price data from external sources.

  Provides temporary stub implementation to resolve Dialyzer errors.
  This module should be fully implemented as part of the market intelligence feature.
  """

  @doc """
  Get price for a single type ID from external source.
  """
  @spec get_price(integer(), atom()) :: {:ok, map()}
  def get_price(_type_id, _source) do
    {:ok, %{price: 0.0, volume: 0, last_updated: DateTime.utc_now()}}
  end

  @doc """
  Get prices for multiple type IDs from external source.
  """
  @spec get_prices([integer()], atom()) :: {:ok, %{integer() => map()}}
  def get_prices(_type_ids, _source) do
    {:ok, %{}}
  end
end
