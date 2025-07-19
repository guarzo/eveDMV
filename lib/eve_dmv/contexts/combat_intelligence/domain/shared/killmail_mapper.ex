defmodule EveDmv.Contexts.CombatIntelligence.Domain.Shared.KillmailMapper do
  @moduledoc """
  Shared utilities for mapping killmail data across combat intelligence services.
  """

  @doc """
  Maps a killmail database row to a structured killmail record.

  Transforms raw database columns into a consistent killmail structure with
  extracted fields for easier processing.
  """
  def map_killmail_row([
        killmail_id,
        killmail_time,
        killmail_hash,
        solar_system_id,
        victim_character_id,
        victim_corporation_id,
        victim_alliance_id,
        victim_ship_type_id,
        attacker_count,
        raw_data,
        source
      ]) do
    %{
      killmail_id: killmail_id,
      killmail_time: killmail_time,
      killmail_hash: killmail_hash,
      solar_system_id: solar_system_id,
      victim_character_id: victim_character_id,
      victim_corporation_id: victim_corporation_id,
      victim_alliance_id: victim_alliance_id,
      victim_ship_type_id: victim_ship_type_id,
      attacker_count: attacker_count,
      raw_data: raw_data,
      source: source,
      # Extract additional fields from raw_data
      total_value: get_in(raw_data, ["zkb", "totalValue"]) || 0,
      attackers: raw_data["attackers"] || [],
      victim: raw_data["victim"] || %{}
    }
  end
end
