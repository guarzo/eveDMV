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
  alias EveDmv.Eve.TypeResolver
  alias EveDmv.Killmails.{KillmailEnriched, KillmailRaw, Participant}
  alias EveDmv.Surveillance.{MatchingEngine, NotificationService}
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
    Logger.debug("Inserting #{length(raw_changesets)} raw killmails")

    results =
      Enum.map(raw_changesets, fn changeset ->
        case Ash.create(KillmailRaw, changeset,
               action: :ingest_from_source,
               domain: EveDmv.Api
             ) do
          {:ok, _record} -> :ok
          {:error, error} -> {:error, error}
        end
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if length(errors) > 0 do
      Logger.error("Failed to insert #{length(errors)} raw killmails")

      Enum.each(errors, fn {:error, error} ->
        Logger.error("Raw killmail insert error: #{inspect(error)}")
      end)

      :error
    else
      Logger.debug("Successfully inserted #{length(raw_changesets)} raw killmails")
      :ok
    end
  end

  defp insert_enriched_killmails(enriched_changesets) do
    Logger.debug("Inserting #{length(enriched_changesets)} enriched killmails")

    results =
      Enum.map(enriched_changesets, fn changeset ->
        case Ash.create(KillmailEnriched, changeset,
               action: :upsert,
               domain: EveDmv.Api
             ) do
          {:ok, _record} -> :ok
          {:error, error} -> {:error, error}
        end
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if length(errors) > 0 do
      Logger.error("Failed to insert #{length(errors)} enriched killmails")

      Enum.each(errors, fn {:error, error} ->
        Logger.error("Enriched killmail insert error: #{inspect(error)}")
      end)

      :error
    else
      Logger.debug("Successfully inserted #{length(enriched_changesets)} enriched killmails")
      :ok
    end
  end

  defp insert_participants(participants_lists) do
    participants = List.flatten(participants_lists)
    Logger.debug("Inserting #{length(participants)} participants")

    results = Enum.map(participants, &insert_single_participant/1)

    errors = Enum.filter(results, &match?({:error, _}, &1))
    successes = Enum.filter(results, &(&1 == :ok))

    if length(errors) > 0 do
      Logger.error("Failed to insert #{length(errors)} participants")

      Enum.each(errors, fn {:error, error} ->
        Logger.error("Participant insert error: #{inspect(error)}")
      end)

      :error
    else
      skipped_count = length(participants) - length(successes)

      if skipped_count > 0 do
        Logger.info(
          "Successfully inserted #{length(successes)} participants, skipped #{skipped_count} invalid participants"
        )
      else
        Logger.debug("Successfully inserted #{length(participants)} participants")
      end

      :ok
    end
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

    :ok
  end

  defp check_surveillance_matches(messages) do
    Logger.debug("🔍 Checking #{length(messages)} killmails against surveillance profiles")

    for %Message{data: {raw_changeset, _enriched_changeset, _}} <- messages do
      case raw_changeset do
        %{raw_data: killmail_data} when not is_nil(killmail_data) ->
          # Run surveillance matching in background to avoid blocking pipeline
          spawn(fn ->
            try do
              matches = MatchingEngine.match_killmail(killmail_data)

              if length(matches) > 0 do
                Logger.info(
                  "🎯 Killmail #{killmail_data["killmail_id"]} matched #{length(matches)} surveillance profiles"
                )

                # Create persistent notifications for matches
                NotificationService.create_batch_match_notifications(killmail_data, matches)

                # Broadcast surveillance match notification (legacy support)
                Endpoint.broadcast!("surveillance", "profile_match", %{
                  killmail: killmail_data,
                  profile_ids: matches
                })
              end
            rescue
              error ->
                Logger.error("Error in surveillance matching: #{inspect(error)}")
            end
          end)

        _ ->
          Logger.debug("No killmail data for surveillance matching")
      end
    end

    :ok
  end

  defp insert_single_participant(participant) do
    case Ash.create(Participant, participant, action: :create, domain: EveDmv.Api) do
      {:ok, _record} ->
        :ok

      {:error, error} ->
        Logger.debug("Participant insertion failed, analyzing error type: #{inspect(error)}")
        handle_participant_error(participant, error)
    end
  end

  defp handle_participant_error(participant, error) do
    cond do
      ship_type_constraint_error?(error) ->
        ship_type_id = extract_ship_type_id_from_error(error)
        Logger.info("Detected foreign key constraint error for ship_type_id: #{ship_type_id}")
        handle_missing_ship_type(participant, ship_type_id)

      weapon_type_constraint_error?(error) ->
        weapon_type_id = extract_weapon_type_id_from_error(error)
        Logger.info("Detected foreign key constraint error for weapon_type_id: #{weapon_type_id}")
        handle_missing_weapon_type(participant, weapon_type_id)

      true ->
        log_unexpected_participant_error(participant, error)
        {:error, error}
    end
  end

  defp log_unexpected_participant_error(participant, error) do
    character_name = participant[:character_name] || "Unknown"
    character_id = participant[:character_id]
    killmail_id = participant[:killmail_id]

    Logger.warning(
      "Unexpected participant error for #{character_name} (character_id: #{character_id}) " <>
        "in killmail #{killmail_id}: #{inspect(error)}"
    )
  end

  # Helper functions for handling missing ship types

  defp ship_type_constraint_error?(%Ash.Error.Invalid{errors: errors}) do
    result =
      Enum.any?(errors, fn error ->
        case error do
          %Ash.Error.Changes.InvalidAttribute{
            field: :ship_type_id,
            private_vars: private_vars
          } ->
            constraint_name = Keyword.get(private_vars, :constraint)
            constraint_type = Keyword.get(private_vars, :constraint_type)
            detail = Keyword.get(private_vars, :detail)

            Logger.debug("Checking constraint: #{constraint_name}, type: #{constraint_type}")
            Logger.debug("Detail: #{detail}")

            # Check if it's a foreign key constraint error by constraint name OR constraint type
            is_fkey_constraint =
              constraint_name == "participants_ship_type_id_fkey" or
                constraint_type == :foreign_key

            # Also check if the detail message contains the expected pattern
            has_fkey_detail =
              is_binary(detail) and String.contains?(detail, "is not present in table")

            result = is_fkey_constraint and has_fkey_detail

            Logger.debug(
              "Is FK constraint: #{is_fkey_constraint}, has FK detail: #{has_fkey_detail}, result: #{result}"
            )

            result

          _ ->
            false
        end
      end)

    Logger.debug("Foreign key constraint error detected: #{result}")
    result
  end

  defp ship_type_constraint_error?(_), do: false

  defp extract_ship_type_id_from_error(%Ash.Error.Invalid{errors: errors}) do
    result = Enum.find_value(errors, &extract_ship_type_from_error/1)
    Logger.debug("Final extracted ship_type_id: #{result}")
    result
  end

  defp extract_ship_type_from_error(%Ash.Error.Changes.InvalidAttribute{
         field: :ship_type_id,
         private_vars: private_vars
       }) do
    detail = Keyword.get(private_vars, :detail)
    Logger.debug("Extracting ship_type_id from detail: #{detail}")
    parse_ship_type_id_from_detail(detail)
  end

  defp extract_ship_type_from_error(_), do: nil

  defp parse_ship_type_id_from_detail(detail) when is_binary(detail) do
    case Regex.run(~r/Key \(ship_type_id\)=\((\d+)\)/, detail) do
      [_, ship_type_id_str] ->
        ship_type_id = String.to_integer(ship_type_id_str)
        Logger.debug("Extracted ship_type_id: #{ship_type_id}")
        ship_type_id

      _ ->
        Logger.debug("Could not parse ship_type_id from detail")
        nil
    end
  end

  defp parse_ship_type_id_from_detail(detail) do
    Logger.debug("Detail is not a string: #{inspect(detail)}")
    nil
  end

  defp handle_missing_ship_type(participant, ship_type_id) when is_integer(ship_type_id) do
    Logger.info("Resolving missing ship type #{ship_type_id} for participant")

    case TypeResolver.resolve_item_type(ship_type_id) do
      {:ok, _item_type} ->
        # Now retry the participant insertion
        case Ash.create(Participant, participant,
               action: :create,
               domain: EveDmv.Api
             ) do
          {:ok, _record} ->
            Logger.info(
              "Successfully inserted participant after resolving ship type #{ship_type_id}"
            )

            :ok

          {:error, error} ->
            Logger.error(
              "Failed to insert participant even after resolving ship type #{ship_type_id}: #{inspect(error)}"
            )

            {:error, error}
        end

      {:error, error} ->
        Logger.error("Failed to resolve ship type #{ship_type_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp handle_missing_ship_type(_participant, nil) do
    Logger.warning("Could not extract ship_type_id from constraint error for participant")
    {:error, :missing_ship_type_id}
  end

  # Weapon type error detection and handling

  defp weapon_type_constraint_error?(%Ash.Error.Invalid{errors: errors}) do
    result =
      Enum.any?(errors, fn error ->
        case error do
          %Ash.Error.Changes.InvalidAttribute{
            field: :weapon_type_id,
            private_vars: private_vars
          } ->
            constraint_name = Keyword.get(private_vars, :constraint)
            constraint_type = Keyword.get(private_vars, :constraint_type)
            detail = Keyword.get(private_vars, :detail)

            Logger.debug(
              "Checking weapon constraint: #{constraint_name}, type: #{constraint_type}"
            )

            # Check if it's a foreign key constraint error by constraint name OR constraint type
            is_fkey_constraint =
              constraint_name == "participants_weapon_type_id_fkey" or
                constraint_type == :foreign_key

            # Also check if the detail message contains the expected pattern
            has_fkey_detail =
              is_binary(detail) and String.contains?(detail, "is not present in table")

            result = is_fkey_constraint and has_fkey_detail

            Logger.debug(
              "Is weapon FK constraint: #{is_fkey_constraint}, has FK detail: #{has_fkey_detail}, result: #{result}"
            )

            result

          _ ->
            false
        end
      end)

    Logger.debug("Weapon foreign key constraint error detected: #{result}")
    result
  end

  defp weapon_type_constraint_error?(_), do: false

  defp extract_weapon_type_id_from_error(%Ash.Error.Invalid{errors: errors}) do
    result = Enum.find_value(errors, &extract_weapon_type_from_error/1)
    Logger.debug("Final extracted weapon_type_id: #{result}")
    result
  end

  defp extract_weapon_type_from_error(%Ash.Error.Changes.InvalidAttribute{
         field: :weapon_type_id,
         private_vars: private_vars
       }) do
    detail = Keyword.get(private_vars, :detail)
    Logger.debug("Extracting weapon_type_id from detail: #{detail}")
    parse_weapon_type_id_from_detail(detail)
  end

  defp extract_weapon_type_from_error(_), do: nil

  defp parse_weapon_type_id_from_detail(detail) when is_binary(detail) do
    case Regex.run(~r/Key \(weapon_type_id\)=\((\d+)\)/, detail) do
      [_, weapon_type_id_str] ->
        weapon_type_id = String.to_integer(weapon_type_id_str)
        Logger.debug("Extracted weapon_type_id: #{weapon_type_id}")
        weapon_type_id

      _ ->
        Logger.debug("Could not parse weapon_type_id from detail")
        nil
    end
  end

  defp parse_weapon_type_id_from_detail(detail) do
    Logger.debug("Weapon detail is not a string: #{inspect(detail)}")
    nil
  end

  defp handle_missing_weapon_type(participant, weapon_type_id) when is_integer(weapon_type_id) do
    Logger.info("Resolving missing weapon type #{weapon_type_id} for participant")

    case TypeResolver.resolve_item_type(weapon_type_id) do
      {:ok, _item_type} ->
        # Now retry the participant insertion
        case Ash.create(Participant, participant,
               action: :create,
               domain: EveDmv.Api
             ) do
          {:ok, _record} ->
            Logger.info(
              "Successfully inserted participant after resolving weapon type #{weapon_type_id}"
            )

            :ok

          {:error, error} ->
            Logger.error(
              "Failed to insert participant even after resolving weapon type #{weapon_type_id}: #{inspect(error)}"
            )

            {:error, error}
        end

      {:error, error} ->
        Logger.error("Failed to resolve weapon type #{weapon_type_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp handle_missing_weapon_type(_participant, nil) do
    Logger.warning("Could not extract weapon_type_id from constraint error for participant")
    {:error, :missing_weapon_type_id}
  end
end
