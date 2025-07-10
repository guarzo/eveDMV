defmodule EveDmv.Killmails.KillmailDataTransformer do
  @moduledoc """
  Handles transformation of raw killmail data into database-ready changesets.

  Provides functions for building raw and enriched changeset data from
  various killmail data sources including SSE feeds and API responses.
  """

  require Logger

  @doc """
  Build a changeset for the raw killmail table.

  Takes enriched killmail data and creates a map suitable for KillmailRaw.
  """
  @spec build_raw_changeset(map()) :: map()
  def build_raw_changeset(enriched) do
    %{
      killmail_id: enriched["killmail_id"],
      killmail_time: parse_timestamp(enriched["timestamp"] || enriched["kill_time"]),
      killmail_hash: enriched["killmail_hash"] || generate_hash(enriched),
      solar_system_id: enriched["solar_system_id"] || enriched["system_id"],
      victim_character_id: get_victim_character_id(enriched),
      victim_corporation_id: get_victim_corporation_id(enriched),
      victim_alliance_id: get_victim_alliance_id(enriched),
      victim_ship_type_id:
        get_in(enriched, ["ship", "type_id"]) || get_victim_ship_type_id(enriched),
      attacker_count: count_attackers(enriched),
      raw_data: enriched,
      source: "wanderer-kills"
    }
  end

  # REMOVED: build_enriched_changeset function
  # Enriched table provides no value - see /docs/architecture/enriched-raw-analysis.md

  # REMOVED: Functions only used by enriched changeset building
  # - calculate_price_values
  # - extract_victim_data  
  # - extract_system_data
  # See /docs/architecture/enriched-raw-analysis.md

  # Helper functions for data extraction

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

  defp generate_hash(enriched) do
    # Generate a simple hash from killmail_id and timestamp
    killmail_id = enriched["killmail_id"]
    timestamp = enriched["timestamp"] || enriched["kill_time"]

    Base.encode16(:crypto.hash(:sha256, "#{killmail_id}:#{timestamp}"), case: :lower)
  end

  defp get_victim_character_id(enriched) do
    get_in(enriched, ["victim", "character_id"]) ||
      enriched["victim_character_id"]
  end

  defp get_victim_corporation_id(enriched) do
    get_in(enriched, ["victim", "corporation_id"]) ||
      enriched["victim_corporation_id"]
  end

  defp get_victim_alliance_id(enriched) do
    get_in(enriched, ["victim", "alliance_id"]) ||
      enriched["victim_alliance_id"]
  end

  defp get_victim_ship_type_id(enriched) do
    get_in(enriched, ["victim", "ship_type_id"]) ||
      enriched["victim_ship_type_id"]
  end

  defp count_attackers(enriched) do
    case enriched["attackers"] do
      attackers when is_list(attackers) -> length(attackers)
      _ -> 1
    end
  end

  # REMOVED: Helper functions only used by enriched changeset building
  # - get_final_blow_character_id
  # - get_final_blow_character_name
  # - determine_kill_category
  # - determine_ship_category
  # - pod_kill?
  # - structure_kill?
  # - capital_kill?
  # - wormhole_kill?
  # - parse_decimal
  # See /docs/architecture/enriched-raw-analysis.md
end
