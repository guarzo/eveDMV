defmodule EveDmv.Killmails.ParticipantBuilder do
  @moduledoc """
  Handles building participant records from killmail data.

  Extracts victim and attacker information from raw killmail data and
  creates properly formatted participant records for database insertion.
  """

  require Logger

  @doc """
  Build all participant records from enriched killmail data.

  Creates both victim and attacker participant records with proper
  validation and data normalization.
  """
  @spec build_participants(map()) :: [map()]
  def build_participants(enriched) do
    victim = enriched["victim"] || %{}
    attackers = normalize_attackers(enriched["attackers"])

    victim_participants = build_victim_participant(victim, enriched)
    attacker_participants = build_attacker_participants(attackers, enriched)

    all_participants = victim_participants ++ attacker_participants
    log_participants_summary(enriched, attackers, all_participants)

    all_participants
  end

  @doc """
  Build victim participant record.

  Creates a participant record for the victim with is_victim=true.
  Validates that the victim has a valid ship_type_id.
  """
  @spec build_victim_participant(map(), map()) :: [map()]
  def build_victim_participant(victim, enriched) do
    case victim["ship_type_id"] do
      nil ->
        log_skipped_participant("victim", victim, enriched["killmail_id"])
        []

      ship_type_id when is_integer(ship_type_id) ->
        [build_participant_data(victim, enriched, true)]
    end
  end

  @doc """
  Build attacker participant records.

  Creates participant records for all valid attackers with is_victim=false.
  Filters out attackers without valid ship_type_id.
  """
  @spec build_attacker_participants([map()], map()) :: [map()]
  def build_attacker_participants(attackers, enriched) do
    attackers
    |> Enum.filter(&has_valid_ship_type_id?(&1, enriched["killmail_id"]))
    |> Enum.map(&build_participant_data(&1, enriched, false))
  end

  @doc """
  Build individual participant data record.

  Creates a standardized participant record with all required fields.
  Handles differences between victim and attacker data structure.
  """
  @spec build_participant_data(map(), map(), boolean()) :: map()
  def build_participant_data(participant, enriched, is_victim) do
    %{
      killmail_id: enriched["killmail_id"],
      killmail_time: parse_timestamp(enriched["timestamp"] || enriched["kill_time"]),
      character_id: participant["character_id"],
      character_name: participant["character_name"],
      corporation_id: participant["corporation_id"],
      corporation_name: participant["corporation_name"],
      alliance_id: participant["alliance_id"],
      alliance_name: participant["alliance_name"],
      faction_id: participant["faction_id"],
      faction_name: participant["faction_name"],
      ship_type_id: participant["ship_type_id"],
      ship_name: participant["ship_name"],
      weapon_type_id: if(is_victim, do: nil, else: participant["weapon_type_id"]),
      weapon_name: if(is_victim, do: nil, else: participant["weapon_name"]),
      damage_done: get_damage_done(participant, is_victim),
      security_status: participant["security_status"],
      is_victim: is_victim,
      final_blow: if(is_victim, do: false, else: participant["final_blow"] || false),
      solar_system_id: enriched["solar_system_id"] || enriched["system_id"]
    }
  end

  # Private helper functions

  defp normalize_attackers(attackers) do
    case attackers do
      nil -> []
      attackers when is_list(attackers) -> attackers
      _ -> []
    end
  end

  defp has_valid_ship_type_id?(participant, killmail_id) do
    case participant["ship_type_id"] do
      nil ->
        log_skipped_participant("attacker", participant, killmail_id)
        false

      ship_type_id when is_integer(ship_type_id) ->
        true
    end
  end

  defp get_damage_done(participant, true), do: participant["damage_taken"] || 0
  defp get_damage_done(participant, false), do: participant["damage_done"] || 0

  defp log_skipped_participant(type, participant, killmail_id) do
    name = participant["character_name"] || "Unknown"
    character_id = participant["character_id"]

    Logger.debug(
      "Skipping #{type} with missing ship_type_id: #{name} (character_id: #{character_id}) in killmail #{killmail_id}. " <>
        "This may be a structure, deployable, or invalid killmail data."
    )
  end

  defp log_participants_summary(enriched, attackers, all_participants) do
    total_possible = 1 + length(attackers)
    total_valid = length(all_participants)
    skipped_count = total_possible - total_valid

    if skipped_count > 0 do
      Logger.debug(
        "Built #{total_valid} valid participants for killmail #{enriched["killmail_id"]}, skipped #{skipped_count} invalid participants"
      )
    end
  end

  defp parse_timestamp(nil), do: DateTime.utc_now()

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _offset} ->
        datetime

      {:error, _reason} ->
        Logger.warning("Failed to parse timestamp: #{timestamp}")
        DateTime.utc_now()
    end
  end

  defp parse_timestamp(%DateTime{} = datetime), do: datetime
  defp parse_timestamp(_), do: DateTime.utc_now()
end
