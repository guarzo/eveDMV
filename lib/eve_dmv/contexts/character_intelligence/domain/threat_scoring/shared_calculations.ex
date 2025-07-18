defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.SharedCalculations do
  @moduledoc """
  Shared calculations for threat scoring engines.

  Contains common functions used across multiple threat scoring engines
  to ensure consistency and reduce code duplication.
  """

  @doc """
  Calculate survival rate based on combat data and victim killmails.
  """
  def calculate_survival_rate(combat_data, victim_killmails) do
    total_engagements = Map.get(combat_data, :total_engagements, 0)
    victim_count = length(victim_killmails)

    if total_engagements > 0 do
      Float.round((total_engagements - victim_count) / total_engagements, 2)
    else
      # Default survival rate
      0.5
    end
  end

  @doc """
  Calculate damage efficiency from attacker killmails.
  """
  def calculate_damage_efficiency(attacker_killmails) do
    if Enum.empty?(attacker_killmails) do
      0.0
    else
      damage_contributions =
        attacker_killmails
        |> Enum.map(&extract_damage_contribution/1)
        |> Enum.filter(&(&1 > 0))

      if Enum.empty?(damage_contributions) do
        0.0
      else
        # Average damage contribution
        avg_contribution = Enum.sum(damage_contributions) / length(damage_contributions)
        # Cap at 1.0
        min(1.0, avg_contribution * 2)
      end
    end
  end

  @doc """
  Extract damage contribution from a killmail for a specific character.
  """
  def extract_damage_contribution(killmail, character_id) do
    case killmail.raw_data do
      %{"victim" => %{"damage_taken" => total_damage}, "attackers" => attackers}
      when is_list(attackers) and is_number(total_damage) and total_damage > 0 ->
        character_damage =
          attackers
          |> Enum.find(&(&1["character_id"] == character_id))
          |> case do
            %{"damage_done" => damage} when is_number(damage) -> damage
            _ -> 0
          end

        character_damage / total_damage

      _ ->
        0.0
    end
  end

  @doc """
  Extract damage contribution from a killmail (for backward compatibility).
  This version assumes the character is the victim, which is likely incorrect.
  Use extract_damage_contribution/2 with the character_id parameter instead.
  """
  def extract_damage_contribution(killmail) do
    # This is a compatibility shim - it's likely incorrect
    # as it looks for the victim as an attacker
    victim_id = Map.get(killmail, :victim_character_id)
    extract_damage_contribution(killmail, victim_id)
  end

  @doc """
  Normalize a score to a 0-10 scale.
  """
  def normalize_to_10_scale(score) do
    min(10.0, max(0.0, score * 10))
  end
end
