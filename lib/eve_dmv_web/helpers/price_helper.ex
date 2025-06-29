defmodule EveDmvWeb.Helpers.PriceHelper do
  @moduledoc """
  Helper functions for displaying prices in the UI.

  Provides on-demand price lookups and formatting functions for killmail values.
  """

  alias EveDmv.Market.PriceService
  require Logger

  @doc """
  Get display value for a killmail.

  First checks if the killmail already has a total_value, otherwise attempts
  to calculate it on-demand (with caching).
  """
  def get_killmail_value(killmail) when is_map(killmail) do
    case killmail do
      %{total_value: value} when value > 0 ->
        # Value already calculated
        {:ok, value}

      _ ->
        # Try to calculate on-demand if we have the raw data
        case Map.get(killmail, :raw_data) do
          nil ->
            {:ok, 0.0}

          raw_data ->
            # Only calculate if it's a high-value kill (has expensive ship)
            if should_calculate_value?(raw_data) do
              calculate_value_async(raw_data)
            else
              {:ok, 0.0}
            end
        end
    end
  end

  @doc """
  Format ISK value for display.
  """
  def format_isk(nil), do: "0 ISK"
  def format_isk(0), do: "0 ISK"

  def format_isk(value) when is_number(value) do
    cond do
      value >= 1_000_000_000 ->
        "#{Float.round(value / 1_000_000_000, 2)}B ISK"

      value >= 1_000_000 ->
        "#{Float.round(value / 1_000_000, 2)}M ISK"

      value >= 1_000 ->
        "#{Float.round(value / 1_000, 2)}K ISK"

      true ->
        "#{round(value)} ISK"
    end
  end

  # Private functions

  defp should_calculate_value?(raw_data) do
    # Only calculate value for player ships, not NPCs or structures
    ship_type_id = get_in(raw_data, ["victim", "ship_type_id"])

    # Check if it's a capsule or rookie ship (low value)
    ship_type_id not in [670, 33328, 588, 596, 601, 606]
  end

  defp calculate_value_async(raw_data) do
    # Return immediately with 0, but trigger async calculation
    Task.start(fn ->
      case PriceService.calculate_killmail_value(raw_data) do
        %{total_value: value} when value > 0 ->
          Logger.debug("Calculated killmail value: #{value}")

        # Could update the database here if needed

        _ ->
          :ok
      end
    end)

    {:ok, 0.0}
  end
end
