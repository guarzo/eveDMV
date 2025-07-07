defmodule EveDmv.Killmails.KillmailPipeline do
  @moduledoc """
  Broadway pipeline for ingesting killmail data from SSE feeds.

  This pipeline consumes Server-Sent Events from wanderer-kills or similar feeds,
  transforms the JSON data into database records, and handles bulk insertion
  with proper error handling and retries.
  """

  use Broadway

  alias Broadway.Message
  alias EveDmv.Killmails.DatabaseInserter
  alias EveDmv.Killmails.DataProcessor
  alias EveDmv.Killmails.KillmailBroadcaster

  require Logger

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
        ],
        surveillance: [
          concurrency: 2,
          batch_size: Application.get_env(:eve_dmv, :surveillance_batch_size, 5),
          batch_timeout: Application.get_env(:eve_dmv, :surveillance_batch_timeout, 2000)
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
          [%Message{status: :ok} = processed_msg | _] ->
            # Insert to database (take first message since we create multiple for batchers)
            case handle_batch(:db_insert, [processed_msg], %{}, %{}) do
              [%Message{status: :ok}] -> {:ok, enriched}
              [%Message{status: {:failed, reason}}] -> {:error, reason}
              _ -> {:error, :batch_processing_failed}
            end

          [%Message{status: {:failed, reason}} | _] ->
            {:error, reason}

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

  @impl Broadway
  def handle_message(:default, %Message{data: enriched} = msg, _ctx) do
    start_time = System.monotonic_time(:microsecond)

    case DataProcessor.process_killmail(enriched) do
      {:ok, processed_data} ->
        killmail_id = DataProcessor.get_killmail_id(processed_data)
        {victim_name, system_name} = DataProcessor.get_victim_info(processed_data)

        Logger.info("⚔️  Processing killmail #{killmail_id}: #{victim_name} in #{system_name}")

        # Emit telemetry for successful processing
        processing_time = System.monotonic_time(:microsecond) - start_time

        :telemetry.execute(
          [:eve_dmv, :killmail, :processing_time],
          %{duration: processing_time},
          %{
            killmail_id: killmail_id
          }
        )

        :telemetry.execute([:eve_dmv, :killmail, :processed], %{count: 1}, %{})

        # Route to multiple batchers for parallel processing
        [
          msg
          |> Message.update_data(fn _ -> processed_data end)
          |> Message.put_batcher(:db_insert),
          msg
          |> Message.update_data(fn _ -> DataProcessor.extract_broadcast_data(processed_data) end)
          |> Message.put_batcher(:pubsub),
          msg
          |> Message.update_data(fn _ -> DataProcessor.extract_broadcast_data(processed_data) end)
          |> Message.put_batcher(:surveillance)
        ]

      {:error, error} ->
        # Emit telemetry for failed processing
        :telemetry.execute([:eve_dmv, :killmail, :failed], %{count: 1}, %{error: inspect(error)})
        Logger.error("Failed to process killmail: #{inspect(error)}")
        Message.failed(msg, error)
    end
  end

  @impl Broadway
  def handle_batch(:db_insert, messages, _batch_info, _ctx) do
    batch_start_time = System.monotonic_time(:microsecond)
    batch_size = length(messages)

    Logger.info("💾 Inserting batch of #{batch_size} killmails to database")

    # Extract data from messages using DataProcessor helper
    {raw_changesets, enriched_changesets, participants_lists} =
      messages
      |> Enum.map(fn message -> DataProcessor.extract_database_changesets(message.data) end)
      |> Enum.reduce({[], [], []}, fn {raw, enriched, participants},
                                      {raw_acc, enriched_acc, part_acc} ->
        {raw_acc ++ raw, enriched_acc ++ enriched, part_acc ++ participants}
      end)

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

      # Database insertion complete - return messages
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

  @impl Broadway
  def handle_batch(:pubsub, messages, _batch_info, _ctx) do
    Logger.info("📡 Broadcasting #{length(messages)} killmails to LiveView clients")

    try do
      # Broadcast killmails to LiveView clients
      KillmailBroadcaster.broadcast_killmails(messages)
      messages
    rescue
      error ->
        Logger.error("Failed to broadcast killmails: #{inspect(error)}")
        # Don't fail the pipeline for broadcasting issues
        messages
    end
  end

  @impl Broadway
  def handle_batch(:surveillance, messages, _batch_info, _ctx) do
    Logger.info("🔍 Checking #{length(messages)} killmails for surveillance matches")

    # Run surveillance matching asynchronously to avoid blocking
    Task.start(fn ->
      try do
        KillmailBroadcaster.check_surveillance_matches(messages)
      rescue
        error ->
          Logger.error("Failed to check surveillance matches: #{inspect(error)}")
      end
    end)

    # Return immediately - surveillance matching doesn't affect pipeline success
    messages
  end
end
