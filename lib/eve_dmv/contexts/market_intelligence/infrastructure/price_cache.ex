defmodule EveDmv.Contexts.MarketIntelligence.Infrastructure.PriceCache do
  @moduledoc """
  Cache implementation for market price data.

  Provides temporary stub implementation to resolve Dialyzer errors.
  This module should be fully implemented as part of the market intelligence feature.
  """

  @doc """
  Get cached price data for a type ID.
  """
  @spec get(integer()) :: {:ok, map()} | {:error, :not_found}
  def get(_type_id) do
    {:error, :not_found}
  end

  @doc """
  Store price data in cache.
  """
  @spec put(integer(), map(), keyword()) :: :ok | {:error, term()}
  def put(_type_id, _price_data, _opts \\ []) do
    :ok
  end

  @doc """
  Get cache statistics.
  """
  @spec stats() :: %{size: non_neg_integer(), memory_bytes: non_neg_integer()}
  def stats do
    %{size: 0, memory_bytes: 0}
  end

  @doc """
  Invalidate all cached price data.
  """
  @spec invalidate_all() :: :ok
  def invalidate_all do
    :ok
  end

  @doc """
  Get hot items (frequently accessed prices).
  """
  @spec get_hot_items(pos_integer()) :: [map()]
  def get_hot_items(_limit) do
    []
  end
end
