defmodule EveDmv.Contexts.MarketIntelligence.Infrastructure.ExternalPriceClient do
  @moduledoc """
  Client for fetching price data from external sources.

  Provides temporary stub implementation to resolve Dialyzer errors.
  This module should be fully implemented as part of the market intelligence feature.
  """

  @doc """
  Get price for a single type ID from external source.
  """
  @spec get_price(integer(), atom()) :: {:ok, map()} | {:error, term()}
  def get_price(_type_id, _source) do
    {:error, :not_implemented}
  end

  @doc """
  Get prices for multiple type IDs from external source.
  """
  @spec get_prices([integer()], atom()) :: {:ok, %{integer() => map()}} | {:error, term()}
  def get_prices(_type_ids, _source) do
    {:error, :not_implemented}
  end
end
