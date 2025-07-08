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

  @doc """
  Build a changeset for the enriched killmail table.

  Takes enriched killmail data and creates a map with calculated values,
  price information, and categorization data.
  """
  @spec build_enriched_changeset(map()) :: map()
  def build_enriched_changeset(enriched) do
    price_values = calculate_price_values(enriched)
    victim_data = extract_victim_data(enriched)
    system_data = extract_system_data(enriched)

    Map.merge(
      victim_data,
      Map.merge(system_data, %{
        killmail_id: enriched["killmail_id"],
        killmail_time: parse_timestamp(enriched["timestamp"] || enriched["kill_time"]),
        total_value: price_values.total_value,
        ship_value: price_values.ship_value,
        fitted_value: price_values.fitted_value,
        attacker_count: count_attackers(enriched),
        final_blow_character_id: get_final_blow_character_id(enriched),
        final_blow_character_name: get_final_blow_character_name(enriched),
        kill_category: determine_kill_category(enriched),
        victim_ship_category: determine_ship_category(enriched),
        module_tags: enriched["module_tags"] || [],
        noteworthy_modules: enriched["noteworthy_modules"] || [],
        price_data_source: price_values.price_data_source
      })
    )
  end

  @doc """
  Calculate price values from killmail data.

  Extracts total value, ship value, and fitted value from various data sources.
  Prefers pre-calculated values from killmail data over API lookups.
  """
  @spec calculate_price_values(map()) :: %{
          total_value: float(),
          ship_value: float(),
          fitted_value: float(),
          price_data_source: String.t()
        }
  def calculate_price_values(enriched) do
    # Use values from the killmail data if available, otherwise default to 0
    # Wanderer-kills may provide these values pre-calculated
    zkb_value = get_in(enriched, ["zkb", "totalValue"])

    total_value =
      case enriched["total_value"] || enriched["value"] || zkb_value do
        nil -> 0.0
        value -> parse_decimal(value)
      end

    # If we don't have a total value, we won't try to calculate individual components
    # This avoids making unnecessary API calls during ingestion
    %{
      total_value: total_value,
      # Will be calculated on-demand if needed
      ship_value: 0.0,
      # Will be calculated on-demand if needed
      fitted_value: 0.0,
      price_data_source: "wanderer_kills"
    }
  end

  @doc """
  Extract victim-specific data from killmail.
  """
  @spec extract_victim_data(map()) :: map()
  def extract_victim_data(enriched) do
    victim = enriched["victim"] || %{}

    %{
      victim_character_id: victim["character_id"],
      victim_character_name: victim["character_name"],
      victim_corporation_id: victim["corporation_id"],
      victim_corporation_name: victim["corporation_name"],
      victim_alliance_id: victim["alliance_id"],
      victim_alliance_name: victim["alliance_name"],
      victim_ship_type_id: victim["ship_type_id"],
      victim_ship_name: victim["ship_name"]
    }
  end

  @doc """
  Extract system-specific data from killmail.
  """
  @spec extract_system_data(map()) :: map()
  def extract_system_data(enriched) do
    %{
      solar_system_id: enriched["solar_system_id"] || enriched["system_id"],
      solar_system_name: enriched["solar_system_name"] || enriched["system_name"],
      region_id: enriched["region_id"],
      region_name: enriched["region_name"],
      constellation_id: enriched["constellation_id"],
      constellation_name: enriched["constellation_name"],
      security_status: parse_decimal(enriched["security_status"] || enriched["security"] || 0.0)
    }
  end

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

  defp get_final_blow_character_id(enriched) do
    case enriched["attackers"] do
      attackers when is_list(attackers) ->
        final_blow = Enum.find(attackers, & &1["final_blow"])
        final_blow && final_blow["character_id"]

      _ ->
        nil
    end
  end

  defp get_final_blow_character_name(enriched) do
    case enriched["attackers"] do
      attackers when is_list(attackers) ->
        final_blow = Enum.find(attackers, & &1["final_blow"])
        final_blow && final_blow["character_name"]

      _ ->
        nil
    end
  end

  defp determine_kill_category(enriched) do
    # Determine kill category based on ship type, location, etc.
    cond do
      pod_kill?(enriched) -> "pod"
      structure_kill?(enriched) -> "structure"
      capital_kill?(enriched) -> "capital"
      wormhole_kill?(enriched) -> "wormhole"
      true -> "standard"
    end
  end

  defp determine_ship_category(enriched) do
    # Determine ship category from ship type ID
    ship_type_id = get_victim_ship_type_id(enriched)

    cond do
      is_nil(ship_type_id) -> "unknown"
      # Capsule
      ship_type_id in [670] -> "capsule"
      ship_type_id >= 23_757 and ship_type_id <= 23_915 -> "frigate"
      ship_type_id >= 16_227 and ship_type_id <= 17_920 -> "cruiser"
      ship_type_id >= 17_922 and ship_type_id <= 17_932 -> "battlecruiser"
      ship_type_id >= 17_734 and ship_type_id <= 17_738 -> "battleship"
      true -> "other"
    end
  end

  defp pod_kill?(enriched) do
    ship_type_id = get_victim_ship_type_id(enriched)
    # Capsule
    ship_type_id == 670
  end

  defp structure_kill?(enriched) do
    # Structure type IDs typically start in the 35000+ range
    ship_type_id = get_victim_ship_type_id(enriched)
    ship_type_id && ship_type_id >= 35_000
  end

  defp capital_kill?(enriched) do
    # Capital ship type IDs (rough approximation)
    ship_type_id = get_victim_ship_type_id(enriched)
    ship_type_id && ship_type_id >= 19_720 and ship_type_id <= 19_726
  end

  defp wormhole_kill?(enriched) do
    system_id = enriched["solar_system_id"] || enriched["system_id"]
    system_id && system_id >= 31_000_000 and system_id < 32_000_000
  end

  defp parse_decimal(nil), do: 0.0
  defp parse_decimal(value) when is_number(value), do: value * 1.0

  defp parse_decimal(value) when is_binary(value) do
    case Float.parse(value) do
      {float_val, _} -> float_val
      :error -> 0.0
    end
  end

  defp parse_decimal(_), do: 0.0
end
