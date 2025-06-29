defmodule EveDmv.Killmails.KillmailPipeline do
  @moduledoc """
  Broadway pipeline for ingesting killmail data from SSE feeds.

  This pipeline consumes Server-Sent Events from wanderer-kills or similar feeds,
  transforms the JSON data into database records, and handles bulk insertion
  with proper error handling and retries.
  """

  use Broadway

  require Logger

  alias Broadway.Message
  alias EveDmv.Killmails.{KillmailEnriched, KillmailRaw, Participant}
  alias EveDmvWeb.Endpoint

  require EveDmv.Api

  # Broadway configuration
  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {
          EveDmv.Killmails.HTTPoisonSSEProducer,
          url: Application.get_env(:eve_dmv, :wanderer_kills_sse_url, "http://localhost:8080/sse")
        }
      ],
      processors: [
        default: [
          concurrency: Application.get_env(:eve_dmv, :pipeline_concurrency, 4)
        ]
      ],
      batchers: [
        db_insert: [
          concurrency: 2,
          batch_size: Application.get_env(:eve_dmv, :batch_size, 10),
          batch_timeout: Application.get_env(:eve_dmv, :batch_timeout, 5000)
        ],
        pubsub: [
          concurrency: 1,
          batch_size: 1,
          batch_timeout: 100
        ]
      ]
    )
  end

  # Transform SSE events into Broadway messages (public for Broadway transformer)
  def transform_sse(%{event: event, data: payload}, _opts) do
    # Only process killmail events
    case event do
      "killmail" ->
        case Jason.decode(payload) do
          {:ok, %{"killmail_id" => _} = enriched} ->
            [
              %Message{
                data: enriched,
                acknowledger: Broadway.NoopAcknowledger.init(),
                batcher: :db_insert,
                batch_key: :default,
                batch_mode: :bulk,
                status: :ok
              }
            ]

          {:ok, _other_json} ->
            Logger.debug("Received non-killmail JSON data: #{inspect(payload)}")
            []

          {:error, reason} ->
            Logger.warning("Failed to decode killmail JSON: #{inspect(reason)}")
            []
        end

      _ ->
        # Skip non-killmail events (like "connected")
        Logger.debug("Skipping non-killmail event: #{event}")
        []
    end
  rescue
    error ->
      Logger.error("Failed to transform SSE payload: #{inspect(error)}")
      []
  end

  @impl true
  def handle_message(:default, %Message{data: enriched} = msg, _ctx) do
    killmail_id = enriched["killmail_id"]

    # The wanderer-kills data has victim directly in the main structure, not participants
    victim_name = enriched["victim"]["character_name"] || "Unknown Pilot"

    # Use name resolution for system name in logs too
    system_id = enriched["solar_system_id"] || enriched["system_id"]

    system_name =
      case enriched["solar_system_name"] do
        name when name in [nil, "", "Unknown System"] and not is_nil(system_id) ->
          EveDmv.Eve.NameResolver.system_name(system_id)

        name when not is_nil(name) ->
          name

        _ ->
          "Unknown System"
      end

    Logger.info("⚔️  Processing killmail #{killmail_id}: #{victim_name} in #{system_name}")

    # Normalize common fields for DB insertion
    raw_changeset = build_raw_changeset(enriched)
    enriched_changeset = build_enriched_changeset(enriched)
    participants = build_participants(enriched)

    msg
    |> Message.update_data(fn _ -> {raw_changeset, enriched_changeset, participants} end)
  rescue
    error ->
      Logger.error("Failed to parse killmail: #{inspect(error)}")
      Message.failed(msg, error)
  end

  @impl true
  def handle_batch(:db_insert, messages, _batch_info, _ctx) do
    Logger.info("💾 Inserting batch of #{length(messages)} killmails to database")

    # Extract data from messages
    raw_changesets = Enum.map(messages, &elem(&1.data, 0))
    enriched_changesets = Enum.map(messages, &elem(&1.data, 1))
    participants_lists = Enum.map(messages, &elem(&1.data, 2))

    try do
      # Insert all database records
      insert_raw_killmails(raw_changesets)
      insert_enriched_killmails(enriched_changesets)
      insert_participants(participants_lists)

      Logger.info(
        "✅ Successfully processed #{length(raw_changesets)} killmails (raw + enriched + participants)"
      )

      # Broadcast to LiveView clients
      broadcast_killmails(messages)

      # Return messages for Broadway
      messages
    rescue
      error ->
        Logger.error("Failed to insert killmail batch: #{inspect(error)}")
        Logger.error("Error type: #{inspect(error.__struct__)}")
        Logger.error("Stack trace: #{inspect(__STACKTRACE__)}")
        # Return failed messages
        Enum.map(messages, &Message.failed(&1, error))
    end
  end

  @impl true
  def handle_batch(:pubsub, messages, _batch_info, _ctx) do
    Logger.info("📡 Broadcasting #{length(messages)} killmails to LiveView clients")
    Logger.debug("PubSub batch received with #{length(messages)} messages")

    for %Message{data: {raw_changeset, _enriched_changeset, _}} <- messages do
      # Broadcast the original raw data which contains all the enriched info
      case raw_changeset do
        %{raw_data: blob} when not is_nil(blob) ->
          Endpoint.broadcast!("kill_feed", "new_kill", blob)

        _ ->
          Logger.warning("No raw data to broadcast for killmail")
      end
    end

    {:ok, messages}
  end

  # Private helper functions

  defp build_raw_changeset(enriched) do
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

  defp build_enriched_changeset(enriched) do
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
        destroyed_value: price_values.destroyed_value,
        dropped_value: price_values.dropped_value,
        fitted_value:
          parse_decimal(get_in(enriched, ["zkb", "fittedValue"]) || enriched["fitted_value"]),
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

  defp calculate_price_values(enriched) do
    price_result = EveDmv.Market.PriceService.calculate_killmail_value(enriched)

    %{
      total_value: parse_decimal(price_result.total_value),
      ship_value: parse_decimal(price_result.ship_value),
      destroyed_value: parse_decimal(price_result.destroyed_value),
      dropped_value: parse_decimal(price_result.dropped_value),
      price_data_source: Atom.to_string(price_result.price_source)
    }
  end

  defp extract_victim_data(enriched) do
    %{
      victim_character_id: get_victim_character_id(enriched),
      victim_character_name: get_victim_character_name(enriched),
      victim_corporation_id: get_victim_corporation_id(enriched),
      victim_corporation_name: get_victim_corporation_name(enriched),
      victim_alliance_id: get_victim_alliance_id(enriched),
      victim_alliance_name: get_victim_alliance_name(enriched),
      victim_ship_type_id:
        get_in(enriched, ["ship", "type_id"]) || get_victim_ship_type_id(enriched),
      victim_ship_name: get_in(enriched, ["ship", "name"]) || get_victim_ship_name(enriched)
    }
  end

  defp extract_system_data(enriched) do
    %{
      solar_system_id: enriched["solar_system_id"] || enriched["system_id"],
      solar_system_name: enriched["solar_system_name"] || "Unknown System"
    }
  end

  defp build_participants(enriched) do
    # Wanderer-kills has separate victim and attackers structures
    victim = enriched["victim"] || %{}

    attackers =
      case enriched["attackers"] do
        nil -> []
        attackers when is_list(attackers) -> attackers
        _ -> []
      end

    # Build victim participant
    victim_participant = %{
      killmail_id: enriched["killmail_id"],
      killmail_time: parse_timestamp(enriched["timestamp"] || enriched["kill_time"]),
      character_id: victim["character_id"],
      character_name: victim["character_name"],
      corporation_id: victim["corporation_id"],
      corporation_name: victim["corporation_name"],
      alliance_id: victim["alliance_id"],
      alliance_name: victim["alliance_name"],
      faction_id: victim["faction_id"],
      faction_name: victim["faction_name"],
      ship_type_id: victim["ship_type_id"],
      ship_name: victim["ship_name"],
      weapon_type_id: nil,
      weapon_name: nil,
      damage_done: victim["damage_taken"] || 0,
      security_status: victim["security_status"],
      is_victim: true,
      final_blow: false,
      solar_system_id: enriched["solar_system_id"] || enriched["system_id"]
    }

    # Build attacker participants
    attacker_participants =
      Enum.map(attackers, fn a ->
        %{
          killmail_id: enriched["killmail_id"],
          killmail_time: parse_timestamp(enriched["timestamp"] || enriched["kill_time"]),
          character_id: a["character_id"],
          character_name: a["character_name"],
          corporation_id: a["corporation_id"],
          corporation_name: a["corporation_name"],
          alliance_id: a["alliance_id"],
          alliance_name: a["alliance_name"],
          faction_id: a["faction_id"],
          faction_name: a["faction_name"],
          ship_type_id: a["ship_type_id"],
          ship_name: a["ship_name"],
          weapon_type_id: a["weapon_type_id"],
          weapon_name: a["weapon_name"],
          damage_done: a["damage_done"] || 0,
          security_status: a["security_status"],
          is_victim: false,
          final_blow: a["final_blow"] || false,
          solar_system_id: enriched["solar_system_id"] || enriched["system_id"]
        }
      end)

    [victim_participant | attacker_participants]
  end

  # Helper functions for data extraction and normalization

  defp parse_timestamp(nil), do: DateTime.utc_now()

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp parse_timestamp(%DateTime{} = dt), do: dt
  defp parse_timestamp(_), do: DateTime.utc_now()

  defp parse_decimal(nil), do: Decimal.new(0)
  defp parse_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp parse_decimal(value) when is_float(value), do: Decimal.from_float(value)

  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> Decimal.new(0)
    end
  end

  defp parse_decimal(_), do: Decimal.new(0)

  defp generate_hash(enriched) do
    # Generate a simple hash from killmail_id and timestamp
    id = enriched["killmail_id"]
    timestamp = enriched["timestamp"]
    :crypto.hash(:sha256, "#{id}-#{timestamp}") |> Base.encode16(case: :lower)
  end

  defp get_victim_character_id(enriched) do
    get_in(enriched, ["victim", "character_id"])
  end

  defp get_victim_character_name(enriched) do
    get_in(enriched, ["victim", "character_name"])
  end

  defp get_victim_corporation_id(enriched) do
    get_in(enriched, ["victim", "corporation_id"])
  end

  defp get_victim_corporation_name(enriched) do
    get_in(enriched, ["victim", "corporation_name"])
  end

  defp get_victim_alliance_id(enriched) do
    get_in(enriched, ["victim", "alliance_id"])
  end

  defp get_victim_alliance_name(enriched) do
    get_in(enriched, ["victim", "alliance_name"])
  end

  defp get_victim_ship_type_id(enriched) do
    get_in(enriched, ["victim", "ship_type_id"])
  end

  defp get_victim_ship_name(enriched) do
    get_in(enriched, ["victim", "ship_name"])
  end

  defp get_final_blow_character_id(enriched) do
    case find_final_blow_attacker(enriched) do
      %{"character_id" => id} -> id
      _ -> nil
    end
  end

  defp get_final_blow_character_name(enriched) do
    case find_final_blow_attacker(enriched) do
      %{"character_name" => name} -> name
      _ -> nil
    end
  end

  defp find_final_blow_attacker(enriched) do
    attackers = enriched["attackers"] || []
    Enum.find(attackers, fn a -> a["final_blow"] end)
  end

  defp count_attackers(enriched) do
    # Wanderer-kills provides attacker_count directly
    enriched["attacker_count"] || length(enriched["attackers"] || [])
  end

  defp determine_kill_category(enriched) do
    # Basic kill categorization based on attacker count
    attacker_count = count_attackers(enriched)

    case attacker_count do
      1 -> "solo"
      n when n <= 5 -> "small_gang"
      n when n <= 20 -> "fleet"
      _ -> "large_fleet"
    end
  end

  defp determine_ship_category(enriched) do
    # Basic ship categorization - simplified for now
    # Full implementation would use EVE static data
    ship_id = get_victim_ship_type_id(enriched)

    cond do
      is_nil(ship_id) -> "unknown"
      ship_id in 580..650 -> "frigate"
      ship_id in 16_000..16_100 -> "destroyer"
      ship_id in 620..650 -> "cruiser"
      ship_id in 416..456 -> "battlecruiser"
      ship_id in 640..680 -> "battleship"
      ship_id in 19_000..24_000 -> "capital"
      true -> "other"
    end
  end

  # Helper functions for database insertion

  defp insert_raw_killmails(raw_changesets) do
    raw_changesets
    |> Enum.each(fn changeset ->
      Logger.debug("Attempting to insert raw killmail: #{changeset.killmail_id}")

      case Ash.create(KillmailRaw, changeset,
             action: :ingest_from_source,
             domain: EveDmv.Api
           ) do
        {:ok, record} ->
          Logger.debug("Successfully inserted raw killmail: #{record.killmail_id}")

        {:error, error} ->
          Logger.error("Failed to insert raw killmail: #{inspect(error)}")
      end
    end)
  end

  defp insert_enriched_killmails(enriched_changesets) do
    enriched_changesets
    |> Enum.each(fn changeset ->
      Logger.debug("Attempting to insert enriched killmail: #{changeset.killmail_id}")

      case Ash.create(KillmailEnriched, changeset,
             action: :create,
             domain: EveDmv.Api
           ) do
        {:ok, record} ->
          Logger.debug("Successfully inserted enriched killmail: #{record.killmail_id}")

        {:error, error} ->
          Logger.error("Failed to insert enriched killmail: #{inspect(error)}")
      end
    end)
  end

  defp insert_participants(participants_lists) do
    participants_lists
    |> List.flatten()
    |> Enum.each(fn participant ->
      Logger.debug("Attempting to insert participant: #{participant.character_name || "Unknown"}")

      case Ash.create(Participant, participant,
             action: :create,
             domain: EveDmv.Api
           ) do
        {:ok, record} ->
          Logger.debug("Successfully inserted participant: #{record.character_name || "Unknown"}")

        {:error, error} ->
          Logger.error("Failed to insert participant: #{inspect(error)}")
      end
    end)
  end

  defp broadcast_killmails(messages) do
    Logger.info("📡 Broadcasting #{length(messages)} killmails to LiveView clients")

    for %Message{data: {raw_changeset, _enriched_changeset, _}} <- messages do
      case raw_changeset do
        %{raw_data: blob} when not is_nil(blob) ->
          Logger.debug("Broadcasting killmail #{blob["killmail_id"]} to LiveView")
          Endpoint.broadcast!("kill_feed", "new_kill", blob)

        _ ->
          Logger.warning("No raw data to broadcast for killmail")
      end
    end
  end
end
