defmodule EveDmv.Market.PricingStrategy do
  @moduledoc """
  Behavior for price resolution strategies.

  Each strategy implements a different method of obtaining item price data.
  Strategies are executed in order of priority until one succeeds.
  """

  @type price_data :: %{
          type_id: integer(),
          buy_price: float() | nil,
          sell_price: float() | nil,
          source: atom(),
          updated_at: DateTime.t()
        }

  @type item_attributes :: map() | nil

  @doc """
  Attempts to get price data for an item using this strategy.

  Returns {:ok, price_data} on success or {:error, reason} on failure.
  """
  @callback get_price(type_id :: integer(), item_attributes :: item_attributes()) ::
              {:ok, price_data()} | {:error, term()}

  @doc """
  Returns the priority of this strategy (lower numbers = higher priority).
  """
  @callback priority() :: integer()

  @doc """
  Returns whether this strategy can handle the given item type.
  """
  @callback supports?(type_id :: integer(), item_attributes :: item_attributes()) :: boolean()

  @doc """
  Returns a human-readable name for this strategy.
  """
  @callback name() :: String.t()
end
