defmodule EveDmv.Killmails.KillmailPipeline do
  @moduledoc """
  Broadway pipeline for ingesting killmail data from SSE feeds.

  This pipeline consumes Server-Sent Events from wanderer-kills or similar feeds,
  transforms the JSON data into database records, and handles bulk insertion
  with proper error handling and retries.
  """

  use Broadway
  use EveDmv.ErrorHandler

  alias Broadway.Message
  alias EveDmv.Killmails.DatabaseInserter
  alias EveDmv.Killmails.DataProcessor
  alias EveDmv.Killmails.KillmailBroadcaster
  alias EveDmv.Monitoring.PipelineMonitor
  alias EveDmv.Error

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
          concurrency: Application.get_env(:eve_dmv, :pipeline_concurrency, 12)
        ]
      ],
      batchers: [
        db_insert: [
          concurrency: Application.get_env(:eve_dmv, :batcher_concurrency, 4),
          batch_size: Application.get_env(:eve_dmv, :batch_size, 100),
          batch_timeout: Application.get_env(:eve_dmv, :batch_timeout, 30000)
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

    # Record message received
    PipelineMonitor.record_message_received()

    case DataProcessor.process_killmail(enriched) do
      {:ok, processed_data} ->
        killmail_id = DataProcessor.get_killmail_id(processed_data)
        {victim_name, system_name} = DataProcessor.get_victim_info(processed_data)

        Logger.info("⚔️  Processing killmail #{killmail_id}: #{victim_name} in #{system_name}")

        # Calculate processing time
        processing_time = System.monotonic_time(:microsecond) - start_time

        # Record successful processing
        PipelineMonitor.record_message_processed(processing_time)

        # Emit telemetry for successful processing
        :telemetry.execute(
          [:eve_dmv, :killmail, :processing_time],
          %{duration: processing_time},
          %{
            killmail_id: killmail_id
          }
        )

        :telemetry.execute([:eve_dmv, :killmail, :processed], %{count: 1}, %{})

        # Route to database insertion batcher
        # Note: Broadway handle_message must return a single message, not a list
        # We'll handle broadcasting and surveillance in the database batcher
        msg
        |> Message.update_data(fn _ -> processed_data end)
        |> Message.put_batcher(:db_insert)

      {:error, reason} ->
        # Normalize error
        error = Error.normalize(reason)

        # Record failed processing
        PipelineMonitor.record_message_failed(error)

        # Emit telemetry for failed processing
        :telemetry.execute([:eve_dmv, :killmail, :failed], %{count: 1}, %{error: error.code})

        Logger.error("Failed to process killmail: #{error.message} (code: #{error.code})")
        Message.failed(msg, error)
    end
  end

  @impl Broadway
  def handle_batch(:db_insert, messages, _batch_info, _ctx) do
    batch_start_time = System.monotonic_time(:microsecond)
    batch_size = length(messages)

    Logger.info("💾 Inserting batch of #{batch_size} killmails to database")

    # Extract data from messages using DataProcessor helper
    {raw_changesets, participants_lists} =
      messages
      |> Enum.map(fn message -> DataProcessor.extract_database_changesets(message.data) end)
      |> Enum.reduce({[], []}, fn {raw, participants}, {raw_acc, part_acc} ->
        {raw_acc ++ raw, part_acc ++ participants}
      end)

    # Use error handler for database operations
    result =
      with_error_handling(
        fn ->
          # Insert all database records using DatabaseInserter
          DatabaseInserter.insert_raw_killmails(raw_changesets)

          # REMOVED: Enriched table provides no value - see /docs/architecture/enriched-raw-analysis.md
          # DatabaseInserter.insert_enriched_killmails(enriched_changesets)
          DatabaseInserter.insert_participants(participants_lists)
          :ok
        end,
        %{operation: :batch_insert, batch_size: batch_size}
      )

    case result do
      {:ok, _} ->
        # Calculate batch processing time
        batch_time = System.monotonic_time(:microsecond) - batch_start_time

        # Record successful batch
        PipelineMonitor.record_batch_processed(batch_size, batch_time)

        # Emit telemetry for successful batch
        :telemetry.execute([:eve_dmv, :killmail, :batch_size], %{size: batch_size}, %{})
        :telemetry.execute([:eve_dmv, :killmail, :enriched], %{count: batch_size}, %{})

        Logger.info(
          "✅ Successfully processed #{length(raw_changesets)} killmails (raw + participants)"
        )

        # After successful database insertion, handle broadcasting and surveillance
        broadcast_messages =
          Enum.map(messages, fn message ->
            Message.update_data(message, fn data -> DataProcessor.extract_broadcast_data(data) end)
          end)

        # Handle broadcasting
        try do
          Logger.info(
            "📡 Broadcasting #{length(broadcast_messages)} killmails to LiveView clients"
          )

          KillmailBroadcaster.broadcast_killmails(broadcast_messages)
        rescue
          error ->
            normalized_error = Error.normalize(error)
            Logger.error("Failed to broadcast killmails: #{normalized_error.message}")
            # Don't fail the pipeline for broadcasting issues
        end

        # Handle surveillance matching asynchronously
        Task.start(fn ->
          try do
            Logger.info(
              "🔍 Checking #{length(broadcast_messages)} killmails for surveillance matches"
            )

            KillmailBroadcaster.check_surveillance_matches(broadcast_messages)
          rescue
            error ->
              normalized_error = Error.normalize(error)
              Logger.error("Failed to check surveillance matches: #{normalized_error.message}")
          end
        end)

        # Database insertion complete - return messages
        messages

      {:error, error} ->
        # Record batch failure
        PipelineMonitor.record_batch_failed(batch_size, error)

        # Emit telemetry for failed batch
        :telemetry.execute([:eve_dmv, :killmail, :failed], %{count: batch_size}, %{
          error: error.code
        })

        Logger.error("Failed to insert killmail batch: #{error.message} (code: #{error.code})")

        # Return failed messages
        Enum.map(messages, &Message.failed(&1, error))
    end
  end
end
