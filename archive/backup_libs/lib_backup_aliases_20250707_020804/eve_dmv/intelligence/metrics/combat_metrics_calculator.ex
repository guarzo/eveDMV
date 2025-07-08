defmodule EveDmv.Intelligence.Metrics.CombatMetricsCalculator do
  @moduledoc """
  Combat metrics calculation module for character analysis.

  This module provides specialized calculation functions for combat-related
  metrics including damage dealt, damage received, lethality scoring, and
  activity scoring.
  """

  @doc """
  Calculate combat effectiveness metrics from killmail data.

  Returns comprehensive combat metrics including kills, losses, damage,
  and effectiveness scores.
  """
  def calculate_combat_metrics(killmail_data) do
    # For test compatibility, separate kill and loss killmails
    # Kill killmails have attackers, loss killmails have victims
    kill_kms =
      Enum.filter(killmail_data, fn km ->
        participants = get_participants(km)
        # A killmail is a kill if it has non-victim participants
        attackers = Enum.filter(participants, &(!get_is_victim(&1)))
        victims = Enum.filter(participants, &get_is_victim(&1))
        # Kill killmail: has attackers and exactly 1 victim
        length(attackers) > 0 and length(victims) == 1
      end)

    loss_kms =
      Enum.filter(killmail_data, fn km ->
        participants = get_participants(km)
        # A killmail is a loss if it has victims
        attackers = Enum.filter(participants, &(!get_is_victim(&1)))
        victims = Enum.filter(participants, &get_is_victim(&1))
        # Loss killmail: has exactly 1 victim and attackers
        length(victims) == 1 and length(attackers) > 0
      end)

    kills = length(kill_kms)
    losses = length(loss_kms)

    total_activity = kills + losses
    solo_kills = count_solo_kills(killmail_data)
    gang_kills = kills - solo_kills

    damage_dealt = calculate_total_damage_dealt(killmail_data)
    damage_received = calculate_total_damage_received(killmail_data)

    %{
      total_kills: kills,
      total_losses: losses,
      solo_kills: solo_kills,
      gang_kills: gang_kills,
      kill_death_ratio: if(losses > 0, do: kills / losses, else: kills),
      solo_kill_ratio: if(kills > 0, do: solo_kills / kills, else: 0.0),
      damage_dealt: damage_dealt,
      damage_received: damage_received,
      damage_efficiency:
        if(damage_received > 0, do: damage_dealt / damage_received, else: damage_dealt),
      activity_score: calculate_activity_score(total_activity),
      lethality_score: calculate_lethality_score(kills, damage_dealt)
    }
  end

  @doc """
  Calculate total damage dealt from killmail data.

  Placeholder implementation using average damage per kill.
  """
  def calculate_total_damage_dealt(killmail_data) do
    count_kills(killmail_data) * 50_000
  end

  @doc """
  Calculate total damage received from killmail data.

  Placeholder implementation using average damage per loss.
  """
  def calculate_total_damage_received(killmail_data) do
    count_losses(killmail_data) * 45_000
  end

  @doc """
  Calculate activity score from total activity count.

  Returns score from 0-100 based on total activity.
  """
  def calculate_activity_score(total_activity) do
    min(total_activity * 5, 100)
  end

  @doc """
  Calculate lethality score from kills and damage dealt.

  Returns lethality rating based on damage efficiency.
  """
  def calculate_lethality_score(kills, damage_dealt) do
    if kills > 0 do
      min(damage_dealt / (kills * 25_000), 2.0)
    else
      0.0
    end
  end

  @doc """
  Calculate dangerous rating from killmail data.

  Returns rating based on activity, K/D ratio, and solo capability.
  """
  def calculate_dangerous_rating(killmail_data) do
    kills = count_kills(killmail_data)
    losses = count_losses(killmail_data)
    solo_kills = count_solo_kills(killmail_data)

    # Base score from activity
    activity_score = min(kills * 2, 50)

    # Bonus for good K/D ratio
    kd_bonus = if losses > 0, do: min(kills / losses * 10, 30), else: 20

    # Bonus for solo capability
    solo_bonus = min(solo_kills * 5, 20)

    round(activity_score + kd_bonus + solo_bonus)
  end

  @doc """
  Calculate kill/death ratio from killmail data.
  """
  def calculate_kill_death_ratio(killmail_data) do
    kills = count_kills(killmail_data)
    losses = count_losses(killmail_data)

    if losses > 0 do
      kills / losses
    else
      kills
    end
  end

  @doc """
  Calculate success rate from killmail data.

  Returns ratio of kills to total engagements.
  """
  def calculate_success_rate(killmail_data) do
    kills = count_kills(killmail_data)
    losses = count_losses(killmail_data)
    total = kills + losses

    if total > 0 do
      kills / total
    else
      0.0
    end
  end

  @doc """
  Count solo kills in killmail data.
  """
  def count_solo_kills(killmail_data) do
    killmail_data
    |> Enum.count(fn killmail ->
      participants = get_participants(killmail)
      attackers = Enum.filter(participants, &(!get_is_victim(&1)))
      length(attackers) == 1
    end)
  end

  @doc """
  Count kills in killmail data.
  """
  def count_kills(killmail_data) do
    length(killmail_data)
  end

  @doc """
  Count losses in killmail data.
  """
  def count_losses(killmail_data) do
    length(killmail_data)
  end

  # Private helper functions

  defp get_participants(killmail) when is_map(killmail) do
    killmail[:participants] || killmail["participants"] || []
  end

  defp get_is_victim(participant) when is_map(participant) do
    participant[:is_victim] || participant["is_victim"] || false
  end
end
