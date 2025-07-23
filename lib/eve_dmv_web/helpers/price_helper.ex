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
    cond do
      has_calculated_value?(killmail) ->
        {:ok, killmail.total_value}

      has_raw_data?(killmail) and should_calculate_value?(killmail.raw_data) ->
        calculate_value_async(killmail.raw_data)

      true ->
        {:ok, 0.0}
    end
  end

  defp has_calculated_value?(killmail) do
    Map.get(killmail, :total_value, 0) > 0
  end

  defp has_raw_data?(killmail) do
    Map.has_key?(killmail, :raw_data) and not is_nil(killmail.raw_data)
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
    ship_type_id not in [670, 33_328, 588, 596, 601, 606]
  end

  defp calculate_value_async(raw_data) do
    # Return immediately with 0, but trigger async calculation
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
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
