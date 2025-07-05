defmodule EveDmv.Killmails.DatabaseInserter do
  @moduledoc """
  Handles bulk database insertion operations for killmail data.

  Provides efficient bulk insertion methods for raw killmails, enriched killmails,
  and participants using Ash bulk operations with proper error handling and logging.
  """

  require Logger

  alias EveDmv.Api
  alias EveDmv.Killmails.{KillmailEnriched, KillmailRaw, Participant}

  @doc """
  Insert raw killmail records using bulk operations.

  Uses Ash.bulk_create for efficient insertion with error collection
  and partial success handling.
  """
  @spec insert_raw_killmails([map()]) :: :ok | :error
  def insert_raw_killmails(raw_changesets) do
    Logger.debug("Inserting #{length(raw_changesets)} raw killmails using bulk operation")

    # Use Ash bulk operation for much better performance
    case Ash.bulk_create(raw_changesets, KillmailRaw, :ingest_from_source,
           domain: Api,
           return_records?: false,
           return_errors?: true,
           stop_on_error?: false
         ) do
      %Ash.BulkResult{status: :success} ->
        success_count = length(raw_changesets)
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

  @doc """
  Insert enriched killmail records using bulk operations.

  Uses Ash.bulk_create for efficient insertion of enriched killmail data
  with comprehensive error handling.
  """
  @spec insert_enriched_killmails([map()]) :: :ok | :error
  def insert_enriched_killmails(enriched_changesets) do
    Logger.debug("Inserting #{length(enriched_changesets)} enriched killmails")

    # Use Ash bulk operation for enriched killmails
    case Ash.bulk_create(enriched_changesets, KillmailEnriched, :ingest_from_pipeline,
           domain: Api,
           return_records?: false,
           return_errors?: true,
           stop_on_error?: false
         ) do
      %Ash.BulkResult{status: :success} ->
        success_count = length(enriched_changesets)
        Logger.debug("Successfully bulk inserted #{success_count} enriched killmails")
        :ok

      %Ash.BulkResult{status: :partial_success} = result ->
        handle_partial_success(result, enriched_changesets, "enriched killmail")

      %Ash.BulkResult{status: :error} = result ->
        handle_bulk_error(result, "enriched killmail")
    end
  end

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
      perform_participant_bulk_insert(participants, valid_participants)
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

  defp handle_participant_success(all_participants, valid_participants) do
    success_count = length(valid_participants)
    skipped_count = length(all_participants) - length(valid_participants)

    if skipped_count > 0 do
      Logger.info(
        "Successfully bulk inserted #{success_count} participants, skipped #{skipped_count} invalid"
      )
    else
      Logger.debug("Successfully bulk inserted #{success_count} participants")
    end

    :ok
  end

  defp handle_participant_partial_success(result, valid_participants) do
    error_count = result.errors |> length()
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
    error_count = result.errors |> length()
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
end
