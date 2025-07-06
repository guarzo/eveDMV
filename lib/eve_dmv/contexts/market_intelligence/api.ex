defmodule EveDmv.Contexts.MarketIntelligence.Api do
  @moduledoc """
  Public API for the Market Intelligence bounded context.

  This module defines the external interface that other contexts
  can use to interact with market intelligence functionality.
  All functions return either {:ok, result} or {:error, reason}.
  """

  alias EveDmv.Contexts.MarketIntelligence.Domain
  alias EveDmv.Result

  @type type_id :: integer()
  @type price_options :: [
          source: :janice | :mutamarket | :esi | :best,
          region_id: integer(),
          cache_ttl: integer()
        ]
  @type price_result :: %{
          type_id: type_id(),
          price: float(),
          source: atom(),
          updated_at: DateTime.t()
        }

  @doc """
  Get the current price for a single item type.

  Options:
  - source: Preferred pricing source (:janice, :mutamarket, :esi, :best)
  - region_id: EVE region for regional pricing (defaults to The Forge)
  - cache_ttl: Cache time-to-live in seconds (defaults to 1 hour)

  ## Examples

      iex> get_price(34)  # Tritanium
      {:ok, %{type_id: 34, price: 5.2, source: :janice, updated_at: ~U[2024-01-01 12:00:00Z]}}
      
      iex> get_price(34, source: :mutamarket, region_id: 10000043)
      {:ok, %{type_id: 34, price: 5.1, source: :mutamarket, updated_at: ~U[2024-01-01 12:00:00Z]}}
  """
  @spec get_price(type_id()) :: Result.t(price_result())
  @spec get_price(type_id(), price_options()) :: Result.t(price_result())
  def get_price(type_id, options \\ []) do
    with :ok <- validate_type_id(type_id),
         {:ok, price_data} <- Domain.PriceService.get_price(type_id, options) do
      {:ok, price_data}
    end
  end

  @doc """
  Get prices for multiple item types in a single request.

  More efficient than multiple individual get_price/2 calls.
  Returns a map with type_id as keys and price_result as values.
  """
  @spec get_prices([type_id()], price_options()) :: Result.t(%{type_id() => price_result()})
  def get_prices(type_ids, options \\ []) do
    with :ok <- validate_type_ids(type_ids),
         {:ok, prices} <- Domain.PriceService.get_prices(type_ids, options) do
      {:ok, prices}
    end
  end

  @doc """
  Calculate the total ISK value of a killmail.

  Includes ship hull, modules, cargo, and implants if available.
  Returns detailed breakdown by category.
  """
  @spec calculate_killmail_value(map()) ::
          Result.t(%{
            total_value: float(),
            ship_value: float(),
            modules_value: float(),
            cargo_value: float(),
            implants_value: float(),
            breakdown: [
              %{
                type_id: type_id(),
                quantity: integer(),
                unit_price: float(),
                total_price: float()
              }
            ]
          })
  def calculate_killmail_value(killmail) do
    with :ok <- validate_killmail(killmail),
         {:ok, valuation} <- Domain.ValuationService.calculate_killmail_value(killmail) do
      {:ok, valuation}
    end
  end

  @doc """
  Calculate the total value of a fleet composition.

  Input should be a list of ships with their fits.
  """
  @spec calculate_fleet_value([map()]) ::
          Result.t(%{
            total_value: float(),
            ship_count: integer(),
            average_ship_value: float(),
            value_by_ship_class: %{},
            breakdown: [%{ship_type_id: type_id(), fit_value: float(), count: integer()}]
          })
  def calculate_fleet_value(ships) do
    with :ok <- validate_fleet_composition(ships),
         {:ok, valuation} <- Domain.ValuationService.calculate_fleet_value(ships) do
      {:ok, valuation}
    end
  end

  @doc """
  Analyze market trends for specified item types over a time period.

  Returns trend data including price changes, volume patterns, and anomalies.
  """
  @spec analyze_market_trends([type_id()], period :: :day | :week | :month) ::
          Result.t(%{
            period: atom(),
            trends: [
              %{
                type_id: type_id(),
                price_change_percent: float(),
                volume_change_percent: float(),
                trend_direction: :increasing | :decreasing | :stable,
                anomalies: [map()]
              }
            ]
          })
  def analyze_market_trends(type_ids, period \\ :week) do
    with :ok <- validate_type_ids(type_ids),
         :ok <- validate_period(period),
         {:ok, analysis} <- Domain.MarketAnalyzer.analyze_trends(type_ids, period) do
      {:ok, analysis}
    end
  end

  @doc """
  Get cached price statistics for monitoring and debugging.
  """
  @spec get_price_cache_stats() :: Result.t(map())
  def get_price_cache_stats do
    stats = Domain.PriceService.get_cache_stats()
    {:ok, stats}
  end

  @doc """
  Force refresh prices for specific item types.

  Bypasses cache and fetches fresh data from external sources.
  """
  @spec refresh_prices([type_id()], price_options()) :: Result.t(:ok)
  def refresh_prices(type_ids, options \\ []) do
    with :ok <- validate_type_ids(type_ids),
         :ok <- Domain.PriceService.refresh_prices(type_ids, options) do
      {:ok, :ok}
    end
  end

  # Private validation functions

  defp validate_type_id(type_id) when is_integer(type_id) and type_id > 0, do: :ok
  defp validate_type_id(_), do: {:error, :invalid_type_id}

  defp validate_type_ids(type_ids) when is_list(type_ids) do
    if Enum.all?(type_ids, &is_integer/1) and Enum.all?(type_ids, &(&1 > 0)) do
      :ok
    else
      {:error, :invalid_type_ids}
    end
  end

  defp validate_type_ids(_), do: {:error, :invalid_type_ids}

  defp validate_killmail(killmail) when is_map(killmail) do
    required_fields = [:killmail_id, :victim, :attackers]

    if Enum.all?(required_fields, &Map.has_key?(killmail, &1)) do
      :ok
    else
      {:error, :invalid_killmail_format}
    end
  end

  defp validate_killmail(_), do: {:error, :invalid_killmail_format}

  defp validate_fleet_composition(ships) when is_list(ships) do
    if Enum.all?(ships, &is_map/1) do
      :ok
    else
      {:error, :invalid_fleet_composition}
    end
  end

  defp validate_fleet_composition(_), do: {:error, :invalid_fleet_composition}

  defp validate_period(period) when period in [:day, :week, :month], do: :ok
  defp validate_period(_), do: {:error, :invalid_period}
end
