defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Processors.BattleTimelineBuilder do
  @moduledoc """
  Handles timeline construction and event sequencing for battle analysis.
  
  Responsible for:
  - Constructing battle timelines from killmail data
  - Creating detailed event sequences
  - Extracting battle participants and their activities
  - Organizing event data for analysis
  """

  require Logger

  @doc """
  Construct a basic battle timeline from killmails.
  """
  def construct_battle_timeline(killmails) do
    timeline =
      killmails
      |> Enum.sort_by(& &1.killmail_time)
      |> Enum.map(fn km ->
        %{
          timestamp: km.killmail_time,
          event_type: :kill,
          victim: %{
            character_id: km.victim_character_id,
            corporation_id: km.victim_corporation_id,
            ship_type_id: km.victim_ship_type_id
          },
          attackers_count: length(km.attackers || []),
          final_blow: find_final_blow_attacker(km.attackers),
          isk_value: km.total_value
        }
      end)

    {:ok, timeline}
  end

  @doc """
  Construct a detailed battle timeline with comprehensive event data.
  """
  def construct_detailed_timeline(killmails, opts \\ []) do
    include_damage_dealt = Keyword.get(opts, :include_damage, true)

    timeline =
      killmails
      |> Enum.sort_by(& &1.killmail_time)
      |> Enum.map(fn km ->
        %{
          timestamp: km.killmail_time,
          event_type: :kill,
          killmail_id: km.killmail_id,
          system_id: km.solar_system_id,
          victim: extract_victim_details(km),
          attackers: if(include_damage_dealt, do: extract_attacker_details(km), else: nil),
          isk_destroyed: km.total_value,
          ship_class: classify_ship(km.victim_ship_type_id)
        }
      end)

    {:ok, timeline}
  end

  @doc """
  Extract battle participants from killmail data.
  """
  def extract_battle_participants(killmails) do
    participants =
      Enum.reduce(killmails, %{}, fn km, acc ->
        # Add victim
        acc =
          Map.put(acc, km.victim_character_id, %{
            character_id: km.victim_character_id,
            corporation_id: km.victim_corporation_id,
            alliance_id: km.victim_alliance_id,
            side: determine_side(km.victim_corporation_id, km.victim_alliance_id),
            kills: 0,
            losses: 1,
            damage_dealt: 0,
            ships_used: MapSet.new([km.victim_ship_type_id])
          })

        # Add attackers
        Enum.reduce(km.attackers || [], acc, fn attacker, acc2 ->
          char_id = attacker["character_id"]

          if char_id && char_id != 0 do
            existing =
              Map.get(acc2, char_id, %{
                character_id: char_id,
                corporation_id: attacker["corporation_id"],
                alliance_id: attacker["alliance_id"],
                side: determine_side(attacker["corporation_id"], attacker["alliance_id"]),
                kills: 0,
                losses: 0,
                damage_dealt: 0,
                ships_used: MapSet.new()
              })

            updated = %{
              existing
              | kills: existing.kills + if(attacker["final_blow"], do: 1, else: 0),
                damage_dealt: existing.damage_dealt + (attacker["damage_done"] || 0),
                ships_used: MapSet.put(existing.ships_used, attacker["ship_type_id"])
            }

            Map.put(acc2, char_id, updated)
          else
            acc2
          end
        end)
      end)

    {:ok, participants}
  end

  # Private helper functions

  defp find_final_blow_attacker(attackers) when is_list(attackers) do
    case Enum.find(attackers, &(&1["final_blow"] == true)) do
      nil -> nil
      attacker -> 
        %{
          character_id: attacker["character_id"],
          corporation_id: attacker["corporation_id"],
          ship_type_id: attacker["ship_type_id"],
          damage_done: attacker["damage_done"]
        }
    end
  end

  defp find_final_blow_attacker(_), do: nil

  defp extract_victim_details(km) do
    %{
      character_id: km.victim_character_id,
      corporation_id: km.victim_corporation_id,
      alliance_id: km.victim_alliance_id,
      ship_type_id: km.victim_ship_type_id,
      ship_class: classify_ship(km.victim_ship_type_id),
      position: get_in(km.raw_data, ["victim", "position"]),
      damage_taken: get_in(km.raw_data, ["victim", "damageTaken"])
    }
  end

  defp extract_attacker_details(km) do
    (km.attackers || [])
    |> Enum.map(fn attacker ->
      %{
        character_id: attacker["character_id"],
        corporation_id: attacker["corporation_id"],
        alliance_id: attacker["alliance_id"],
        ship_type_id: attacker["ship_type_id"],
        ship_class: classify_ship(attacker["ship_type_id"]),
        weapon_type_id: attacker["weapon_type_id"],
        damage_done: attacker["damage_done"],
        final_blow: attacker["final_blow"],
        security_status: attacker["security_status"]
      }
    end)
  end

  defp classify_ship(ship_type_id) do
    # Placeholder classification - would integrate with ship data service
    cond do
      ship_type_id in [670, 671, 672] -> :frigate
      ship_type_id in [620, 621, 622] -> :cruiser
      ship_type_id in [623, 624, 625] -> :battleship
      ship_type_id in [485, 540, 541] -> :dreadnought
      true -> :unknown
    end
  end

  defp determine_side(corporation_id, alliance_id) do
    # Simplified side determination - would integrate with alliance/standings service
    cond do
      alliance_id && alliance_id > 0 -> "alliance_#{alliance_id}"
      corporation_id && corporation_id > 0 -> "corp_#{corporation_id}"
      true -> "unknown"
    end
  end
end