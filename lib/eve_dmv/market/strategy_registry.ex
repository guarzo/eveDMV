defmodule EveDmv.Market.StrategyRegistry do
  @moduledoc """
  Registry for price resolution strategies.

  Manages the available pricing strategies and provides functions to
  get strategies in priority order or filter by capability.
  """

  alias EveDmv.Market.Strategies.{
    BasePriceStrategy,
    EsiStrategy,
    JaniceStrategy,
    MutamarketStrategy
  }

  @doc """
  Returns all available pricing strategies in priority order.
  """
  @spec all_strategies() :: [module()]
  def all_strategies do
    [
      BasePriceStrategy,
      EsiStrategy,
      JaniceStrategy,
      MutamarketStrategy
    ]
    |> Enum.sort_by(& &1.priority())
  end

  @doc """
  Returns strategies that can handle the given item type and attributes.
  """
  @spec strategies_for(integer(), map() | nil) :: [module()]
  def strategies_for(type_id, item_attributes \\ nil) do
    all_strategies()
    |> Enum.filter(& &1.supports?(type_id, item_attributes))
  end

  @doc """
  Returns the strategy with the given name.
  """
  @spec strategy_by_name(String.t()) :: {:ok, module()} | {:error, :not_found}
  def strategy_by_name(name) do
    case Enum.find(all_strategies(), &(&1.name() == name)) do
      nil -> {:error, :not_found}
      strategy -> {:ok, strategy}
    end
  end

  @doc """
  Returns information about all strategies.
  """
  @spec strategy_info() :: [%{name: String.t(), priority: integer(), module: module()}]
  def strategy_info do
    all_strategies()
    |> Enum.map(fn strategy ->
      %{
        name: strategy.name(),
        priority: strategy.priority(),
        module: strategy
      }
    end)
  end
end
