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

  alias EveDmv.Killmails.{
    KillmailDataTransformer,
    ParticipantBuilder,
    DatabaseInserter,
    KillmailBroadcaster
  }

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

  @doc """
  Process a single killmail for testing and direct ingestion.
  """
  def process_killmail(killmail_data) when is_map(killmail_data) do
    # Create a fake SSE message
    sse_message = %{event: "killmail", data: Jason.encode!(killmail_data)}

    # Transform to Broadway message
    messages = transform_sse(sse_message, [])

    case messages do
      [%Message{data: enriched} = msg] ->
        # Process the message through the pipeline
        case handle_message(:default, msg, %{}) do
          %Message{status: :ok} = processed_msg ->
            # Insert to database
            case handle_batch(:db_insert, [processed_msg], %{}, %{}) do
              [%Message{status: :ok}] -> {:ok, enriched}
              [%Message{status: {:failed, reason}}] -> {:error, reason}
              _ -> {:error, :batch_processing_failed}
            end

          %Message{status: {:failed, reason}} ->
            {:error, reason}
        end

      [] ->
        {:error, :invalid_killmail_data}

      _ ->
        {:error, :unexpected_message_count}
    end
  rescue
    e -> {:error, e}
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
      # Normalize common fields for DB insertion using extracted modules
      raw_changeset = KillmailDataTransformer.build_raw_changeset(enriched)
      enriched_changeset = KillmailDataTransformer.build_enriched_changeset(enriched)
      participants = ParticipantBuilder.build_participants(enriched)

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
      # Insert all database records using DatabaseInserter
      DatabaseInserter.insert_raw_killmails(raw_changesets)
      DatabaseInserter.insert_enriched_killmails(enriched_changesets)
      DatabaseInserter.insert_participants(participants_lists)

      # Emit telemetry for successful batch
      _batch_time = System.monotonic_time(:microsecond) - batch_start_time
      :telemetry.execute([:eve_dmv, :killmail, :batch_size], %{size: batch_size}, %{})
      :telemetry.execute([:eve_dmv, :killmail, :enriched], %{count: batch_size}, %{})

      Logger.info(
        "✅ Successfully processed #{length(raw_changesets)} killmails (raw + enriched + participants)"
      )

      # Broadcast to LiveView clients using KillmailBroadcaster
      KillmailBroadcaster.broadcast_killmails(messages)

      # Check surveillance profiles for matches using KillmailBroadcaster
      KillmailBroadcaster.check_surveillance_matches(messages)

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
          EveDmvWeb.Endpoint.broadcast!("kill_feed", "new_kill", blob)

        _ ->
          Logger.warning("No raw data to broadcast for killmail")
      end
    end

    {:ok, messages}
  end
end
