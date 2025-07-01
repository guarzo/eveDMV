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
          batch_size: Application.get_env(:eve_dmv, :pubsub_batch_size, 1),
          batch_timeout: Application.get_env(:eve_dmv, :pubsub_batch_timeout, 100)
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
    start_time = System.monotonic_time(:microsecond)
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

    try do
      # Normalize common fields for DB insertion
      raw_changeset = build_raw_changeset(enriched)
      enriched_changeset = build_enriched_changeset(enriched)
      participants = build_participants(enriched)

      # Emit telemetry for successful processing
      processing_time = System.monotonic_time(:microsecond) - start_time

      :telemetry.execute([:eve_dmv, :killmail, :processing_time], %{duration: processing_time}, %{
        killmail_id: killmail_id
      })

      :telemetry.execute([:eve_dmv, :killmail, :processed], %{count: 1}, %{})

      msg
      |> Message.update_data(fn _ -> {raw_changeset, enriched_changeset, participants} end)
    rescue
      error ->
        # Emit telemetry for failed processing
        :telemetry.execute([:eve_dmv, :killmail, :failed], %{count: 1}, %{error: inspect(error)})
        Logger.error("Failed to parse killmail: #{inspect(error)}")
        Message.failed(msg, error)
    end
  end

  @impl true
  def handle_batch(:db_insert, messages, _batch_info, _ctx) do
    batch_start_time = System.monotonic_time(:microsecond)
    batch_size = length(messages)

    Logger.info("💾 Inserting batch of #{batch_size} killmails to database")

    # Extract data from messages
    raw_changesets = Enum.map(messages, &elem(&1.data, 0))
    enriched_changesets = Enum.map(messages, &elem(&1.data, 1))
    participants_lists = Enum.map(messages, &elem(&1.data, 2))

    try do
      # Insert all database records
      insert_raw_killmails(raw_changesets)
      insert_enriched_killmails(enriched_changesets)
      insert_participants(participants_lists)

      # Emit telemetry for successful batch
      _batch_time = System.monotonic_time(:microsecond) - batch_start_time
      :telemetry.execute([:eve_dmv, :killmail, :batch_size], %{size: batch_size}, %{})
      :telemetry.execute([:eve_dmv, :killmail, :enriched], %{count: batch_size}, %{})

      Logger.info(
        "✅ Successfully processed #{length(raw_changesets)} killmails (raw + enriched + participants)"
      )

      # Broadcast to LiveView clients
      broadcast_killmails(messages)

      # Check surveillance profiles for matches
      check_surveillance_matches(messages)

      # Return messages for Broadway
      messages
    rescue
      error ->
        # Emit telemetry for failed batch
        :telemetry.execute([:eve_dmv, :killmail, :failed], %{count: batch_size}, %{
          error: inspect(error)
        })

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

  defp calculate_price_values(enriched) do
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
    victim = enriched["victim"] || %{}
    attackers = normalize_attackers(enriched["attackers"])

    victim_participants = build_victim_participant(victim, enriched)
    attacker_participants = build_attacker_participants(attackers, enriched)

    all_participants = victim_participants ++ attacker_participants
    log_participants_summary(enriched, attackers, all_participants)

    all_participants
  end

  defp normalize_attackers(attackers) do
    case attackers do
      nil -> []
      attackers when is_list(attackers) -> attackers
      _ -> []
    end
  end

  defp build_victim_participant(victim, enriched) do
    case victim["ship_type_id"] do
      nil ->
        log_skipped_participant("victim", victim, enriched["killmail_id"])
        []

      ship_type_id when is_integer(ship_type_id) ->
        [build_participant_data(victim, enriched, true)]
    end
  end

  defp build_attacker_participants(attackers, enriched) do
    attackers
    |> Enum.filter(&has_valid_ship_type_id?(&1, enriched["killmail_id"]))
    |> Enum.map(&build_participant_data(&1, enriched, false))
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

  defp build_participant_data(participant, enriched, is_victim) do
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
  # NOTE: Using individual inserts instead of bulk operations for better error visibility.
  # Monitor performance in production - if throughput becomes an issue, consider switching
  # to batched inserts with error collection (maintaining error detail while improving performance).

  defp insert_raw_killmails(raw_changesets) do
    Logger.debug("Inserting #{length(raw_changesets)} raw killmails using bulk operation")

    # Use Ash bulk operation for much better performance
    case Ash.bulk_create(raw_changesets, KillmailRaw, :ingest_from_source,
           domain: EveDmv.Api,
           return_records?: false,
           return_errors?: true,
           stop_on_error?: false
         ) do
      %Ash.BulkResult{status: :success} = result ->
        success_count = result.records |> length()
        Logger.debug("Successfully bulk inserted #{success_count} raw killmails")
        :ok

      %Ash.BulkResult{status: :partial_success} = result ->
        success_count = result.records |> length()
        error_count = result.errors |> length()

        Logger.warning(
          "Bulk insert partially successful: #{success_count} succeeded, #{error_count} failed"
        )

        # Log first few errors for debugging
        result.errors
        |> Enum.take(3)
        |> Enum.each(fn error ->
          Logger.error("Raw killmail bulk insert error: #{inspect(error)}")
        end)

        # Consider partial success as ok for pipeline resilience
        :ok

      %Ash.BulkResult{status: :error} = result ->
        Logger.error("Bulk insert failed completely")

        result.errors
        |> Enum.take(5)
        |> Enum.each(fn error ->
          Logger.error("Raw killmail bulk insert error: #{inspect(error)}")
        end)

        :error

      other ->
        Logger.error("Unexpected bulk insert result: #{inspect(other)}")
        :error
    end
  end

  defp insert_enriched_killmails(enriched_changesets) do
    Logger.debug("Inserting #{length(enriched_changesets)} enriched killmails")

    # Use Ash bulk operation for enriched killmails
    case Ash.bulk_create(enriched_changesets, KillmailEnriched, :ingest_from_pipeline,
           domain: EveDmv.Api,
           return_records?: false,
           return_errors?: true,
           stop_on_error?: false
         ) do
      %Ash.BulkResult{status: :success} = result ->
        success_count = result.records |> length()
        Logger.debug("Successfully bulk inserted #{success_count} enriched killmails")
        :ok

      %Ash.BulkResult{status: :partial_success} = result ->
        success_count = result.records |> length()
        error_count = result.errors |> length()

        Logger.warning(
          "Enriched killmail bulk insert partially successful: #{success_count} succeeded, #{error_count} failed"
        )

        # Log first few errors for debugging
        result.errors
        |> Enum.take(3)
        |> Enum.each(fn error ->
          Logger.error("Enriched killmail bulk insert error: #{inspect(error)}")
        end)

        # Consider partial success as ok for pipeline resilience
        :ok

      %Ash.BulkResult{status: :error} = result ->
        Logger.error("Enriched killmail bulk insert failed completely")

        result.errors
        |> Enum.take(5)
        |> Enum.each(fn error ->
          Logger.error("Enriched killmail bulk insert error: #{inspect(error)}")
        end)

        :error
    end
  end

  defp insert_participants(participants_lists) do
    participants = List.flatten(participants_lists)
    Logger.debug("Inserting #{length(participants)} participants using bulk operation")

    # Filter out any invalid participants before bulk operation
    valid_participants = Enum.filter(participants, &valid_participant?/1)

    if Enum.empty?(valid_participants) do
      Logger.debug("No valid participants to insert")
      :ok
    else
      # Use Ash bulk operation for much better performance
      case Ash.bulk_create(valid_participants, Participant, :create,
             domain: EveDmv.Api,
             return_records?: false,
             return_errors?: true,
             stop_on_error?: false
           ) do
        %Ash.BulkResult{status: :success} = result ->
          success_count = result.records |> length()
          skipped_count = length(participants) - length(valid_participants)

          if skipped_count > 0 do
            Logger.info(
              "Successfully bulk inserted #{success_count} participants, skipped #{skipped_count} invalid"
            )
          else
            Logger.debug("Successfully bulk inserted #{success_count} participants")
          end

          :ok

        %Ash.BulkResult{status: :partial_success} = result ->
          success_count = result.records |> length()
          error_count = result.errors |> length()

          Logger.warning(
            "Bulk participant insert partially successful: #{success_count} succeeded, #{error_count} failed"
          )

          # Log first few errors for debugging
          result.errors
          |> Enum.take(3)
          |> Enum.each(fn error ->
            Logger.error("Participant bulk insert error: #{inspect(error)}")
          end)

          # Consider partial success as ok for pipeline resilience
          :ok

        %Ash.BulkResult{status: :error} = result ->
          Logger.error("Participant bulk insert failed completely")

          result.errors
          |> Enum.take(5)
          |> Enum.each(fn error ->
            Logger.error("Participant bulk insert error: #{inspect(error)}")
          end)

          :error
      end
    end
  end

  # Simple validation helper for participants
  defp valid_participant?(participant) when is_map(participant) do
    # Basic validation - ensure required fields are present
    participant[:killmail_id] != nil and
      participant[:character_id] != nil and
      participant[:ship_type_id] != nil
  end

  defp valid_participant?(_), do: false

  # Broadcast killmails to LiveView clients via PubSub
  defp broadcast_killmails(messages) do
    for %Message{data: killmail_data} <- messages do
      try do
        EveDmvWeb.Endpoint.broadcast!("killmail_feed", "new_killmail", killmail_data)
      rescue
        error ->
          Logger.warning("Failed to broadcast killmail: #{inspect(error)}")
      end
    end
  end

  # Check surveillance profiles for matches
  defp check_surveillance_matches(messages) do
    Logger.debug("Checking surveillance matches for #{length(messages)} killmails")

    for %Message{data: killmail_data} <- messages do
      try do
        # This would integrate with the surveillance matching engine
        # For now, just log that we would check for matches
        Logger.debug(
          "Would check surveillance matches for killmail #{killmail_data["killmail_id"]}"
        )
      rescue
        error ->
          Logger.warning("Failed to check surveillance matches: #{inspect(error)}")
      end
    end
  end
end
