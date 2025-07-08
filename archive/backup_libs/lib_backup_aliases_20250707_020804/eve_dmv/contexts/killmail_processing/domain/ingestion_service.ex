defmodule EveDmv.Contexts.KillmailProcessing.Domain.IngestionService do
  @moduledoc """
  Domain service for killmail ingestion and processing.

  This service encapsulates the core business logic for:
  - Validating incoming killmail data
  - Orchestrating enrichment processes
  - Managing storage operations
  - Publishing appropriate domain events
  """

  require Logger
  alias EveDmv.Contexts.KillmailProcessing.Domain
  alias EveDmv.Contexts.KillmailProcessing.Infrastructure
  alias EveDmv.Result

  @doc """
  Ingest a raw killmail through the complete processing pipeline.

  Steps:
  1. Validate the raw killmail data
  2. Enrich with additional metadata and ISK values
  3. Store both raw and enriched data
  4. Publish domain events

  Returns detailed processing results including what was stored
  and which events were published.
  """
  @spec ingest(map()) :: Result.t(map())
  def ingest(raw_killmail) do
    processing_start = System.monotonic_time(:millisecond)

    Logger.debug("Starting killmail ingestion", %{
      killmail_id: raw_killmail[:killmail_id],
      killmail_time: raw_killmail[:killmail_time]
    })

    with {:ok, validated_killmail} <-
           Domain.ValidationService.validate_raw_killmail(raw_killmail),
         {:ok, enriched_data} <- Domain.EnrichmentService.enrich_killmail(validated_killmail),
         {:ok, storage_result} <-
           Domain.StorageService.store_killmail(validated_killmail, enriched_data),
         {:ok, events_published} <- publish_ingestion_events(validated_killmail, enriched_data) do
      processing_time = System.monotonic_time(:millisecond) - processing_start

      result = %{
        killmail_id: validated_killmail.killmail_id,
        processing_time_ms: processing_time,
        raw_inserted: storage_result.raw_inserted,
        enriched_inserted: storage_result.enriched_inserted,
        participants_inserted: storage_result.participants_inserted,
        events_published: events_published,
        enrichment_data: %{
          total_value: enriched_data.total_value,
          ship_value: enriched_data.ship_value,
          fitted_value: enriched_data.fitted_value,
          cargo_value: enriched_data.cargo_value
        }
      }

      Logger.info(
        "Killmail ingestion completed",
        Map.take(result, [:killmail_id, :processing_time_ms, :events_published])
      )

      # Record telemetry
      :telemetry.execute(
        [:eve_dmv, :killmail_processing, :ingestion, :completed],
        %{processing_time_ms: processing_time},
        %{killmail_id: validated_killmail.killmail_id}
      )

      {:ok, result}
    else
      {:error, reason} = error ->
        processing_time = System.monotonic_time(:millisecond) - processing_start

        Logger.error("Killmail ingestion failed", %{
          killmail_id: raw_killmail[:killmail_id],
          reason: inspect(reason),
          processing_time_ms: processing_time
        })

        # Record failure telemetry
        :telemetry.execute(
          [:eve_dmv, :killmail_processing, :ingestion, :failed],
          %{processing_time_ms: processing_time},
          %{killmail_id: raw_killmail[:killmail_id], reason: reason}
        )

        # Publish failure event
        publish_failure_event(raw_killmail, reason)

        error
    end
  end

  @doc """
  Batch ingest multiple killmails for efficiency.

  Processes killmails in parallel with controlled concurrency
  to optimize throughput while managing resource usage.
  """
  @spec ingest_batch([map()], keyword()) :: Result.t(map())
  def ingest_batch(killmails, opts \\ []) do
    max_concurrency = Keyword.get(opts, :max_concurrency, 10)
    timeout = Keyword.get(opts, :timeout, :timer.minutes(5))

    Logger.info("Starting batch killmail ingestion", %{
      killmail_count: length(killmails),
      max_concurrency: max_concurrency
    })

    batch_start = System.monotonic_time(:millisecond)

    results =
      killmails
      |> Task.async_stream(
        &ingest/1,
        max_concurrency: max_concurrency,
        timeout: timeout,
        on_timeout: :kill_task
      )
      |> Enum.to_list()

    processing_time = System.monotonic_time(:millisecond) - batch_start

    # Analyze results
    {successful, failed} =
      results
      |> Enum.split_with(fn
        {:ok, {:ok, _}} -> true
        _ -> false
      end)

    successful_results = Enum.map(successful, fn {:ok, {:ok, result}} -> result end)

    failed_results =
      Enum.map(failed, fn
        {:ok, {:error, reason}} -> {:error, reason}
        {:exit, reason} -> {:error, {:timeout, reason}}
      end)
    batch_result = %{
      total_processed: length(killmails),
      successful: length(successful_results),
      failed: length(failed_results),
      processing_time_ms: processing_time,
      throughput_per_second: length(killmails) / (processing_time / 1000),
      results: successful_results,
      errors: failed_results
    }

    Logger.info(
      "Batch killmail ingestion completed",
      Map.take(batch_result, [:total_processed, :successful, :failed, :processing_time_ms])
    )

    # Record batch telemetry
    :telemetry.execute(
      [:eve_dmv, :killmail_processing, :batch_ingestion, :completed],
      %{
        total_processed: length(killmails),
        successful: length(successful_results),
        failed: length(failed_results),
        processing_time_ms: processing_time
      },
      %{}
    )

    {:ok, batch_result}
  end

  # Private functions

  defp publish_ingestion_events(killmail, enriched_data) do
    events_to_publish = [
      create_killmail_received_event(killmail),
      create_killmail_enriched_event(killmail, enriched_data)
    ]

    # Publish events through the infrastructure layer
    case Infrastructure.EventPublisher.publish_events(events_to_publish) do
      :ok -> {:ok, length(events_to_publish)}
      error -> error
    end
  end

  defp publish_failure_event(raw_killmail, reason) do
    failure_event = create_killmail_failed_event(raw_killmail, reason)
    Infrastructure.EventPublisher.publish_event(failure_event)
  end

  defp create_killmail_received_event(killmail) do
    %{
      type: :killmail_received,
      data: %{
        killmail_id: killmail.killmail_id,
        hash: Map.get(killmail, :hash, ""),
        occurred_at: killmail.killmail_time,
        solar_system_id: Map.get(killmail, :solar_system_id),
        victim: extract_victim_summary(killmail),
        attackers: extract_attackers_summary(killmail),
        zkb_data: Map.get(killmail, :zkb),
        received_at: DateTime.utc_now()
      }
    }
  end

  defp create_killmail_enriched_event(killmail, enriched_data) do
    %{
      type: :killmail_enriched,
      data: %{
        killmail_id: killmail.killmail_id,
        enriched_data: %{
          total_value: enriched_data.total_value,
          ship_value: enriched_data.ship_value,
          fitted_value: enriched_data.fitted_value,
          cargo_value: enriched_data.cargo_value,
          kill_categories: enriched_data.kill_categories,
          ship_categories: enriched_data.ship_categories,
          noteworthy_modules: enriched_data.noteworthy_modules,
          module_tags: enriched_data.module_tags
        },
        enrichment_duration_ms: enriched_data.processing_time_ms,
        timestamp: DateTime.utc_now()
      }
    }
  end

  defp create_killmail_failed_event(raw_killmail, reason) do
    stage = determine_failure_stage(reason)

    %{
      type: :killmail_failed,
      data: %{
        killmail_id: raw_killmail[:killmail_id],
        reason: reason,
        stage: stage,
        error_details: %{
          raw_killmail_present: not is_nil(raw_killmail),
          killmail_time: raw_killmail[:killmail_time],
          victim_present: not is_nil(raw_killmail[:victim]),
          attackers_count: length(raw_killmail[:attackers] || [])
        },
        timestamp: DateTime.utc_now()
      }
    }
  end

  defp determine_failure_stage(reason) do
    case reason do
      {:validation_error, _} -> :ingestion
      {:enrichment_error, _} -> :enrichment
      {:storage_error, _} -> :storage
      _ -> :ingestion
    end
  end

  defp extract_victim_summary(killmail) do
    victim = killmail.victim

    %{
      character_id: Map.get(victim, :character_id),
      corporation_id: Map.get(victim, :corporation_id),
      alliance_id: Map.get(victim, :alliance_id),
      ship_type_id: Map.get(victim, :ship_type_id),
      damage_taken: Map.get(victim, :damage_taken, 0)
    }
  end

  defp extract_attackers_summary(killmail) do
    killmail.attackers
    # Limit to top 5 attackers for event
    |> Enum.take(5)
    |> Enum.map(fn attacker ->
      %{
        character_id: Map.get(attacker, :character_id),
        corporation_id: Map.get(attacker, :corporation_id),
        alliance_id: Map.get(attacker, :alliance_id),
        ship_type_id: Map.get(attacker, :ship_type_id),
        damage_done: Map.get(attacker, :damage_done, 0),
        final_blow: Map.get(attacker, :final_blow, false)
      }
    end)
  end
end
