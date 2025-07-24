defmodule EveDmv.Killmails.DatabaseInserter do
  @moduledoc """
  Handles bulk database insertion operations for killmail data.

  Provides efficient bulk insertion methods for raw killmails, enriched killmails,
  and participants using Ash bulk operations with proper error handling and logging.
  """

  alias EveDmv.Api
  # REMOVED: KillmailEnriched - see /docs/architecture/enriched-raw-analysis.md
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Killmails.Participant

  require Logger

  @doc """
  Insert raw killmail records using bulk operations.

  Uses Ash.bulk_create for efficient insertion with error collection
  and partial success handling.
  """
  @spec insert_raw_killmails([map()]) :: :ok | :error
  def insert_raw_killmails(raw_changesets) do
    Logger.debug("Inserting #{length(raw_changesets)} raw killmails using bulk operation")

    # Deduplicate by killmail_id to prevent constraint violations in batch
    unique_changesets = deduplicate_killmails(raw_changesets)

    if length(unique_changesets) < length(raw_changesets) do
      Logger.debug(
        "Deduplicated #{length(raw_changesets)} -> #{length(unique_changesets)} raw killmails"
      )
    end

    # Use Ash bulk operation for much better performance
    case Ash.bulk_create(unique_changesets, KillmailRaw, :ingest_from_source,
           domain: Api,
           return_records?: false,
           return_errors?: true,
           stop_on_error?: false
         ) do
      %Ash.BulkResult{status: :success} ->
        success_count = length(unique_changesets)
        Logger.debug("Successfully bulk inserted #{success_count} raw killmails")
        :ok

      %Ash.BulkResult{status: :partial_success} = result ->
        handle_partial_success(result, raw_changesets, "raw killmail")

      %Ash.BulkResult{status: :error} = result ->
        handle_bulk_error(result, "raw killmail")

      other ->
        Logger.error("Unexpected bulk insert result: #{inspect(other)}")
        :error
    end
  end

  # REMOVED: insert_enriched_killmails function
  # Enriched table provides no value - see /docs/architecture/enriched-raw-analysis.md

  @doc """
  Insert participant records using bulk operations.

  Handles flattening of participant lists, validation filtering,
  and bulk insertion with comprehensive error handling.
  """
  @spec insert_participants([list()] | list()) :: :ok | :error
  def insert_participants(participants_lists) when is_list(participants_lists) do
    # Filter out any nil values before flattening
    valid_lists = Enum.filter(participants_lists, &(&1 != nil))
    participants = List.flatten(valid_lists)
    Logger.debug("Inserting #{length(participants)} participants using bulk operation")

    # Filter out any invalid participants before bulk operation
    valid_participants = Enum.filter(participants, &valid_participant?/1)

    if Enum.empty?(valid_participants) do
      Logger.debug("No valid participants to insert")
      :ok
    else
      # Deduplicate participants to prevent constraint violations in batch
      unique_participants = deduplicate_participants(valid_participants)

      if length(unique_participants) < length(valid_participants) do
        Logger.debug(
          "Deduplicated #{length(valid_participants)} -> #{length(unique_participants)} participants"
        )
      end

      perform_participant_bulk_insert(participants, unique_participants)
    end
  end

  @doc """
  Validate that a participant record has required fields.
  """
  @spec valid_participant?(map()) :: boolean()
  def valid_participant?(participant) when is_map(participant) do
    required_fields = [:killmail_id, :killmail_time, :ship_type_id]

    Enum.all?(required_fields, fn field ->
      value = Map.get(participant, field)
      not is_nil(value) and value != ""
    end)
  end

  def valid_participant?(_), do: false

  # Private helper functions

  defp perform_participant_bulk_insert(all_participants, valid_participants) do
    case Ash.bulk_create(valid_participants, Participant, :create,
           domain: Api,
           return_records?: false,
           return_errors?: true,
           stop_on_error?: false
         ) do
      %Ash.BulkResult{status: :success} ->
        handle_participant_success(all_participants, valid_participants)

      %Ash.BulkResult{status: :partial_success} = result ->
        handle_participant_partial_success(result, valid_participants)

      %Ash.BulkResult{status: :error} = result ->
        handle_bulk_error(result, "participant")
    end
  end

  defp handle_participant_success(all_participants, unique_participants) do
    success_count = length(unique_participants)
    skipped_count = length(all_participants) - length(unique_participants)

    if skipped_count > 0 do
      Logger.info(
        "Successfully bulk inserted #{success_count} participants, skipped #{skipped_count} invalid/duplicate"
      )
    else
      Logger.debug("Successfully bulk inserted #{success_count} participants")
    end

    :ok
  end

  defp handle_participant_partial_success(result, valid_participants) do
    error_count = length(result.errors)
    success_count = length(valid_participants) - error_count

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
  end

  defp handle_partial_success(result, changesets, entity_type) do
    error_count = length(result.errors)
    success_count = length(changesets) - error_count

    Logger.warning(
      "#{String.capitalize(entity_type)} bulk insert partially successful: #{success_count} succeeded, #{error_count} failed"
    )

    # Log first few errors for debugging
    result.errors
    |> Enum.take(3)
    |> Enum.each(fn error ->
      Logger.error("#{String.capitalize(entity_type)} bulk insert error: #{inspect(error)}")
    end)

    # Consider partial success as ok for pipeline resilience
    :ok
  end

  defp handle_bulk_error(result, entity_type) do
    Logger.error("#{String.capitalize(entity_type)} bulk insert failed completely")

    result.errors
    |> Enum.take(5)
    |> Enum.each(fn error ->
      Logger.error("#{String.capitalize(entity_type)} bulk insert error: #{inspect(error)}")
    end)

    :error
  end

  # Deduplication helpers

  defp deduplicate_killmails(raw_changesets) do
    raw_changesets
    |> Enum.uniq_by(fn changeset ->
      # Deduplicate by killmail_id to prevent constraint violations
      Map.get(changeset, :killmail_id)
    end)
  end

  defp deduplicate_participants(participants) do
    participants
    |> Enum.uniq_by(fn participant ->
      # Deduplicate by unique combination that matches the actual constraint:
      # unique_participant_per_killmail: [:killmail_id, :killmail_time, :character_id, :ship_type_id]
      {
        Map.get(participant, :killmail_id),
        Map.get(participant, :killmail_time),
        Map.get(participant, :character_id),
        Map.get(participant, :ship_type_id)
      }
    end)
  end
end
