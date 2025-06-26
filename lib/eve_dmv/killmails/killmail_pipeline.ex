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
  alias EveDmv.Repo
  alias EveDmvWeb.Endpoint

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
          batch_size: 50,
          batch_timeout: 1000
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

    victim_name =
      get_in(enriched, ["participants"])
      |> Enum.find(& &1["is_victim"])
      |> get_in(["character_name"])

    system_name = enriched["solar_system_name"] || "Unknown System"

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

    # Bulk insert raw killmails, enriched killmails, and participants
    raw_changesets = Enum.map(messages, &elem(&1.data, 0))
    enriched_changesets = Enum.map(messages, &elem(&1.data, 1))
    participants_lists = Enum.map(messages, &elem(&1.data, 2))

    try do
      Repo.transaction(fn ->
        # Use Ash.bulk_create for proper resource handling
        raw_changesets
        |> Enum.chunk_every(100)
        |> Enum.each(fn chunk ->
          Ash.bulk_create(KillmailRaw, chunk, :ingest_from_source,
            upsert?: true,
            upsert_identity: :unique_killmail,
            return_errors?: false,
            return_records?: false
          )
        end)

        enriched_changesets
        |> Enum.chunk_every(100)
        |> Enum.each(fn chunk ->
          Ash.bulk_create(KillmailEnriched, chunk, :create,
            upsert?: true,
            upsert_identity: :unique_killmail,
            return_errors?: false,
            return_records?: false
          )
        end)

        participants_lists
        |> List.flatten()
        |> Enum.chunk_every(100)
        |> Enum.each(fn chunk ->
          Ash.bulk_create(Participant, chunk, :create,
            upsert?: true,
            upsert_identity: :unique_participant_per_killmail,
            return_errors?: false,
            return_records?: false
          )
        end)
      end)

      # Forward all messages to PubSub batcher
      messages
      |> Enum.map(&Message.put_batcher(&1, :pubsub))
    rescue
      error ->
        Logger.error("Failed to insert killmail batch: #{inspect(error)}")
        # Return failed messages
        Enum.map(messages, &Message.failed(&1, error))
    end
  end

  @impl true
  def handle_batch(:pubsub, messages, _batch_info, _ctx) do
    Logger.info("📡 Broadcasting #{length(messages)} killmails to LiveView clients")

    for %Message{data: {_, enriched_changeset, _}} <- messages do
      # Broadcast the original enriched JSON blob
      case enriched_changeset do
        %{enrichment_blob: blob} when not is_nil(blob) ->
          Endpoint.broadcast!("kill_feed", "new_kill", blob)

        _ ->
          Logger.warning("No enrichment blob to broadcast for killmail")
      end
    end

    {:ok, messages}
  end

  # Private helper functions

  defp build_raw_changeset(enriched) do
    %{
      killmail_id: enriched["killmail_id"],
      killmail_time: parse_timestamp(enriched["timestamp"]),
      killmail_hash: enriched["killmail_hash"] || generate_hash(enriched),
      solar_system_id: get_in(enriched, ["system", "id"]) || enriched["solar_system_id"],
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
    %{
      killmail_id: enriched["killmail_id"],
      killmail_time: parse_timestamp(enriched["timestamp"]),
      victim_character_id: get_victim_character_id(enriched),
      victim_character_name: get_victim_character_name(enriched),
      victim_corporation_id: get_victim_corporation_id(enriched),
      victim_corporation_name: get_victim_corporation_name(enriched),
      victim_alliance_id: get_victim_alliance_id(enriched),
      victim_alliance_name: get_victim_alliance_name(enriched),
      solar_system_id: get_in(enriched, ["system", "id"]) || enriched["solar_system_id"],
      solar_system_name: get_in(enriched, ["system", "name"]) || enriched["solar_system_name"],
      victim_ship_type_id:
        get_in(enriched, ["ship", "type_id"]) || get_victim_ship_type_id(enriched),
      victim_ship_name: get_in(enriched, ["ship", "name"]) || get_victim_ship_name(enriched),
      total_value: parse_decimal(enriched["isk_value"] || enriched["total_value"]),
      ship_value: parse_decimal(enriched["ship_value"]),
      fitted_value: parse_decimal(enriched["fitted_value"]),
      attacker_count: count_attackers(enriched),
      final_blow_character_id: get_final_blow_character_id(enriched),
      final_blow_character_name: get_final_blow_character_name(enriched),
      kill_category: determine_kill_category(enriched),
      victim_ship_category: determine_ship_category(enriched),
      module_tags: enriched["module_tags"] || [],
      noteworthy_modules: enriched["noteworthy_modules"] || [],
      price_data_source: enriched["price_data_source"] || "wanderer-kills"
    }
  end

  defp build_participants(enriched) do
    participants = enriched["participants"] || []

    Enum.map(participants, fn p ->
      %{
        killmail_id: enriched["killmail_id"],
        killmail_time: parse_timestamp(enriched["timestamp"]),
        character_id: p["character_id"],
        character_name: p["character_name"],
        corporation_id: p["corporation_id"],
        corporation_name: p["corporation_name"],
        alliance_id: p["alliance_id"],
        alliance_name: p["alliance_name"],
        faction_id: p["faction_id"],
        faction_name: p["faction_name"],
        ship_type_id: p["ship_type_id"],
        ship_name: p["ship_name"],
        weapon_type_id: p["weapon_type_id"],
        weapon_name: p["weapon_name"],
        damage_done: p["damage_done"] || 0,
        security_status: p["security_status"],
        is_victim: p["is_victim"] || false,
        final_blow: p["final_blow"] || false,
        solar_system_id: get_in(enriched, ["system", "id"]) || enriched["solar_system_id"]
      }
    end)
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
  defp parse_decimal(value) when is_number(value), do: Decimal.new(value)

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
    case find_victim(enriched) do
      %{"character_id" => id} -> id
      _ -> nil
    end
  end

  defp get_victim_character_name(enriched) do
    case find_victim(enriched) do
      %{"character_name" => name} -> name
      _ -> nil
    end
  end

  defp get_victim_corporation_id(enriched) do
    case find_victim(enriched) do
      %{"corporation_id" => id} -> id
      _ -> nil
    end
  end

  defp get_victim_corporation_name(enriched) do
    case find_victim(enriched) do
      %{"corporation_name" => name} -> name
      _ -> nil
    end
  end

  defp get_victim_alliance_id(enriched) do
    case find_victim(enriched) do
      %{"alliance_id" => id} -> id
      _ -> nil
    end
  end

  defp get_victim_alliance_name(enriched) do
    case find_victim(enriched) do
      %{"alliance_name" => name} -> name
      _ -> nil
    end
  end

  defp get_victim_ship_type_id(enriched) do
    case find_victim(enriched) do
      %{"ship_type_id" => id} -> id
      _ -> nil
    end
  end

  defp get_victim_ship_name(enriched) do
    case find_victim(enriched) do
      %{"ship_name" => name} -> name
      _ -> nil
    end
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

  defp find_victim(enriched) do
    participants = enriched["participants"] || []
    Enum.find(participants, fn p -> p["is_victim"] end)
  end

  defp find_final_blow_attacker(enriched) do
    participants = enriched["participants"] || []
    Enum.find(participants, fn p -> p["final_blow"] && !p["is_victim"] end)
  end

  defp count_attackers(enriched) do
    participants = enriched["participants"] || []
    attackers = Enum.filter(participants, fn p -> !p["is_victim"] end)
    length(attackers)
  end

  defp determine_kill_category(enriched) do
    # Basic kill categorization based on attacker count
    case enriched.attacker_count do
      1 -> "solo"
      n when n <= 5 -> "small_gang"
      n when n <= 20 -> "fleet"
      _ -> "large_fleet"
    end
  end

  defp determine_ship_category(enriched) do
    # Basic ship categorization - simplified for now
    # Full implementation would use EVE static data
    ship_id = enriched.victim_ship_type_id

    cond do
      ship_id in 580..650 -> "frigate"
      ship_id in 16_000..16_100 -> "destroyer"
      ship_id in 620..650 -> "cruiser"
      ship_id in 416..456 -> "battlecruiser"
      ship_id in 640..680 -> "battleship"
      ship_id in 19_000..24_000 -> "capital"
      true -> "other"
    end
  end
end
