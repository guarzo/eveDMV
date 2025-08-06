defmodule EveDmv.Analytics.PerformanceCalculator do
  @moduledoc """
  Shared performance calculation utilities for analytics.

  This module extracts common calculation logic used by both player and ship statistics
  to ensure consistency and reduce code duplication.
  """

  @doc """
  Calculate kill/death ratio with safe division handling.

  Returns:
  - Decimal representing K/D ratio
  - If losses is 0, returns total_kills as Decimal
  - If both are 0, returns 0
  """
  def calculate_kill_death_ratio(total_kills, total_losses)
      when is_integer(total_kills) and is_integer(total_losses) do
    if total_losses > 0 do
      Decimal.div(total_kills, total_losses)
    else
      Decimal.new(total_kills)
    end
  end

  @doc """
  Calculate ISK efficiency percentage.

  ISK efficiency = (ISK destroyed / (ISK destroyed + ISK lost)) * 100

  Returns:
  - Decimal percentage (0-100)
  - Returns 0 if total ISK is 0
  """
  def calculate_isk_efficiency(isk_destroyed, isk_lost) do
    isk_destroyed = ensure_decimal(isk_destroyed)
    isk_lost = ensure_decimal(isk_lost)

    total_isk = Decimal.add(isk_destroyed, isk_lost)

    if Decimal.gt?(total_isk, 0) do
      Decimal.mult(Decimal.div(isk_destroyed, total_isk), 100)
    else
      Decimal.new(0)
    end
  end

  @doc """
  Calculate average ISK value per kill.

  Returns:
  - Decimal average value
  - Returns 0 if no kills
  """
  def calculate_average_kill_value(total_isk_destroyed, total_kills)
      when is_integer(total_kills) do
    isk_destroyed = ensure_decimal(total_isk_destroyed)

    if total_kills > 0 do
      Decimal.div(isk_destroyed, total_kills)
    else
      Decimal.new(0)
    end
  end

  @doc """
  Calculate average ISK value per loss.

  Returns:
  - Decimal average value
  - Returns 0 if no losses
  """
  def calculate_average_loss_value(total_isk_lost, total_losses) when is_integer(total_losses) do
    isk_lost = ensure_decimal(total_isk_lost)

    if total_losses > 0 do
      Decimal.div(isk_lost, total_losses)
    else
      Decimal.new(0)
    end
  end

  @doc """
  Calculate survival rate percentage.

  Survival rate = (total_kills / (total_kills + total_losses)) * 100

  Returns:
  - Decimal percentage (0-100)
  - Returns 0 if no activity
  """
  def calculate_survival_rate(total_kills, total_losses)
      when is_integer(total_kills) and is_integer(total_losses) do
    total_activity = total_kills + total_losses

    if total_activity > 0 do
      Decimal.mult(Decimal.div(total_kills, total_activity), 100)
    else
      Decimal.new(0)
    end
  end

  @doc """
  Calculate solo performance ratio with safe division.

  Solo performance = solo_kills / solo_losses when solo_losses > 0
  When solo_losses = 0, returns solo_kills as the ratio

  Returns:
  - Decimal ratio
  - If solo_losses is 0, returns solo_kills as Decimal
  - If both are 0, returns 0
  """
  def calculate_solo_performance_ratio(solo_kills, solo_losses)
      when is_integer(solo_kills) and is_integer(solo_losses) do
    if solo_losses > 0 do
      Decimal.div(solo_kills, solo_losses)
    else
      Decimal.new(solo_kills)
    end
  end

  @doc """
  Calculate solo kill percentage.

  Solo percentage = (solo_kills / total_kills) * 100

  Returns:
  - Decimal percentage (0-100)
  - Returns 0 if no kills
  """
  def calculate_solo_kill_percentage(solo_kills, total_kills)
      when is_integer(solo_kills) and is_integer(total_kills) do
    if total_kills > 0 do
      Decimal.mult(Decimal.div(solo_kills, total_kills), 100)
    else
      Decimal.new(0)
    end
  end

  # Private helper to ensure values are Decimal
  defp ensure_decimal(value) when is_number(value), do: Decimal.new(value)
  defp ensure_decimal(%Decimal{} = value), do: value
  defp ensure_decimal(_), do: Decimal.new(0)
end
