defmodule EveDmv.Analytics.AnalyticsEngine do
  @moduledoc """
  Main analytics engine that coordinates player and ship statistics calculations.

  This module serves as a facade that delegates to specialized engines for better
  code organization and maintainability.
  """

  alias EveDmv.Analytics.ShipStatsEngine
  alias EveDmv.Contexts.Intelligence.Services.PlayerStatsEngine

  @doc """
  Calculate and update player statistics for all active characters.

  Delegates to PlayerStatsEngine for actual processing.
  """
  def calculate_player_stats(opts \\ []) do
    PlayerStatsEngine.calculate_player_stats(opts)
  end

  @doc """
  Calculate and update ship statistics for all ship types.

  Delegates to ShipStatsEngine for actual processing.
  """
  def calculate_ship_stats(opts \\ []) do
    ShipStatsEngine.calculate_ship_stats(opts)
  end

  @doc """
  Calculate both player and ship statistics in sequence.
  """
  def calculate_all_stats(opts \\ []) do
    case calculate_player_stats(opts) do
      :ok ->
        calculate_ship_stats(opts)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
