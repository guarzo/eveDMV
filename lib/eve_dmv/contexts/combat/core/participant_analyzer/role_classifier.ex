defmodule EveDmv.Contexts.Combat.Core.ParticipantAnalyzer.RoleClassifier do
  @moduledoc """
  Classifies participant roles based on their ship types, damage patterns, and behavior.
  """

  # Ship type ID ranges for classification (simplified)
  @logistics_ships [11_985, 11_987, 11_989, 11_978, 11_969, 11_940, 11_936, 11_938]
  @ewar_ships [11_963, 11_965, 11_959, 11_961, 11_957, 11_969, 11_971, 584, 585, 586, 587]
  @tackle_ships [585, 586, 587, 588, 589, 590, 591, 592, 593, 594, 595, 596]
  @capital_ships 20_000..30_000

  @doc """
  Classify a participant's role based on their combat behavior and ship choices.
  """
  def classify_role(participant) do
    role = determine_primary_role(participant)

    participant
    |> Map.put(:role, role)
    |> Map.put(:role_confidence, calculate_role_confidence(participant, role))
    |> Map.put(:secondary_roles, determine_secondary_roles(participant, role))
  end

  defp determine_primary_role(participant) do
    ship_types = participant[:ships_used] || []

    cond do
      # Check ship-based roles first
      using_logistics_ship?(ship_types) -> :logistics
      using_ewar_ship?(ship_types) -> :electronic_warfare
      using_tackle_ship?(ship_types) -> :tackle
      using_capital_ship?(ship_types) -> :capital_pilot
      # Then behavior-based roles
      is_fleet_commander?(participant) -> :fleet_commander
      is_damage_dealer?(participant) -> :damage_dealer
      is_scout?(participant) -> :scout
      is_hunter?(participant) -> :hunter
      # Default role
      true -> :line_member
    end
  end

  defp determine_secondary_roles(participant, primary_role) do
    roles = []

    # A participant can have multiple secondary roles
    roles =
      if is_high_damage_dealer?(participant) && primary_role != :damage_dealer do
        [:damage_dealer | roles]
      else
        roles
      end

    roles =
      if has_tackle_behavior?(participant) && primary_role != :tackle do
        [:tackle | roles]
      else
        roles
      end

    roles =
      if has_command_behavior?(participant) && primary_role != :fleet_commander do
        [:squad_leader | roles]
      else
        roles
      end

    Enum.uniq(roles)
  end

  defp calculate_role_confidence(participant, role) do
    # Calculate confidence score based on how well the participant fits the role
    base_confidence = 0.5

    modifiers =
      case role do
        :logistics -> calculate_logistics_confidence(participant)
        :electronic_warfare -> calculate_ewar_confidence(participant)
        :damage_dealer -> calculate_dps_confidence(participant)
        :fleet_commander -> calculate_fc_confidence(participant)
        _ -> 0
      end

    min(base_confidence + modifiers, 1.0)
  end

  # Role detection helpers

  defp using_logistics_ship?(ship_types) do
    Enum.any?(ship_types, &(&1 in @logistics_ships))
  end

  defp using_ewar_ship?(ship_types) do
    Enum.any?(ship_types, &(&1 in @ewar_ships))
  end

  defp using_tackle_ship?(ship_types) do
    Enum.any?(ship_types, &(&1 in @tackle_ships))
  end

  defp using_capital_ship?(ship_types) do
    Enum.any?(ship_types, &(&1 in @capital_ships))
  end

  defp is_fleet_commander?(participant) do
    # FCs typically:
    # - Stay alive longer
    # - Are on many killmails but with lower damage
    # - Are primary targets (high incoming damage when they die)

    survival_time = participant[:survival_time]
    kill_participation = participant[:appearances] || 0
    avg_damage = (participant[:total_damage_done] || 0) / max(kill_participation, 1)

    # Low damage per kill suggests non-DPS role
    survival_time == :survived &&
      kill_participation >= 10 &&
      avg_damage < 5000
  end

  defp is_damage_dealer?(participant) do
    total_damage = participant[:total_damage_done] || 0
    appearances = participant[:appearances] || 1
    avg_damage = total_damage / appearances

    avg_damage > 10000 || participant[:final_blows] > 3
  end

  defp is_scout?(participant) do
    # Scouts typically:
    # - Use fast ships
    # - Have fewer kills but high survival
    # - Appear early in battles

    participant[:kills] < 3 &&
      participant[:deaths] == 0 &&
      participant[:appearances] >= 5
  end

  defp is_hunter?(participant) do
    # Hunters have high solo kill ratios
    solo_kills = participant[:solo_kills] || 0
    total_kills = participant[:kills] || 0

    solo_kills > 0 && solo_kills / max(total_kills, 1) > 0.3
  end

  defp is_high_damage_dealer?(participant) do
    avg_damage = (participant[:total_damage_done] || 0) / max(participant[:appearances] || 1, 1)
    avg_damage > 20000
  end

  defp has_tackle_behavior?(participant) do
    # Tackle pilots are often on many kills but die frequently
    participant[:kills] > 5 && participant[:deaths] > 0
  end

  defp has_command_behavior?(participant) do
    # Squad leaders have moderate kill participation and good survival
    participant[:appearances] >= 7 &&
      participant[:survival_time] == :survived
  end

  # Confidence calculators

  defp calculate_logistics_confidence(participant) do
    confidence = 0.0

    # Using logistics ship is strong indicator
    confidence =
      if using_logistics_ship?(participant[:ships_used] || []) do
        confidence + 0.4
      else
        confidence
      end

    # Low damage output expected
    confidence =
      if participant[:total_damage_done] < 1000 do
        confidence + 0.1
      else
        confidence
      end

    confidence
  end

  defp calculate_ewar_confidence(participant) do
    confidence = 0.0

    confidence =
      if using_ewar_ship?(participant[:ships_used] || []) do
        confidence + 0.4
      else
        confidence
      end

    # EWAR pilots often have many kill participations but low damage
    confidence =
      if participant[:appearances] > 10 && participant[:total_damage_done] < 5000 do
        confidence + 0.2
      else
        confidence
      end

    confidence
  end

  defp calculate_dps_confidence(participant) do
    avg_damage = (participant[:total_damage_done] || 0) / max(participant[:appearances] || 1, 1)

    cond do
      avg_damage > 50000 -> 0.5
      avg_damage > 20000 -> 0.3
      avg_damage > 10000 -> 0.2
      true -> 0.0
    end
  end

  defp calculate_fc_confidence(participant) do
    confidence = 0.0

    # High appearance count
    confidence =
      if participant[:appearances] >= 15 do
        confidence + 0.2
      else
        confidence
      end

    # Survived the battle
    confidence =
      if participant[:survival_time] == :survived do
        confidence + 0.2
      else
        confidence
      end

    # Low average damage (not primary DPS)
    avg_damage = (participant[:total_damage_done] || 0) / max(participant[:appearances] || 1, 1)

    confidence =
      if avg_damage < 5000 do
        confidence + 0.1
      else
        confidence
      end

    confidence
  end
end
