defmodule EveDmv.Contexts.KillmailProcessing.Domain.HistoricalFetchManager do
  @moduledoc """
  Manages historical fetch status records.

  Provides functions to retrieve, create, and transform historical fetch
  status records for the 2-year killmail fetch feature.
  """

  alias EveDmv.Contexts.KillmailProcessing.Domain.HistoricalFetchWorker
  alias EveDmv.Contexts.KillmailProcessing.Resources.HistoricalFetchStatus

  @doc """
  Gets or creates a historical fetch status record for an entity.

  If a status record exists, returns it. Otherwise, creates a new one
  with default values.

  ## Parameters
  - `entity_type` - The type of entity (:character, :corporation, :system, :alliance)
  - `entity_id` - The entity's EVE Online ID

  ## Returns
  - `{:ok, status}` - The existing or newly created status record
  - `{:error, reason}` - If creation fails
  """
  @spec get_or_create_fetch_status(atom(), integer()) ::
          {:ok, HistoricalFetchStatus.t()} | {:error, term()}
  def get_or_create_fetch_status(entity_type, entity_id) do
    case HistoricalFetchStatus.get_by_entity(entity_type, entity_id) do
      {:ok, [status]} ->
        {:ok, status}

      {:ok, []} ->
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: entity_type, entity_id: entity_id},
          action: :create,
          domain: EveDmv.Api
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Converts a HistoricalFetchStatus struct to a plain map.

  Used for API responses and PubSub broadcasts where a plain map
  is preferred over an Ash resource struct.

  ## Parameters
  - `status` - A HistoricalFetchStatus struct

  ## Returns
  A map with all relevant status fields
  """
  @spec status_to_map(HistoricalFetchStatus.t()) :: map()
  def status_to_map(status) do
    %{
      id: status.id,
      entity_type: status.entity_type,
      entity_id: status.entity_id,
      status: status.status,
      phase1_completed_at: status.phase1_completed_at,
      phase2_started_at: status.phase2_started_at,
      phase2_completed_at: status.phase2_completed_at,
      oldest_killmail_date: status.oldest_killmail_date,
      target_date: status.target_date,
      killmails_fetched: status.killmails_fetched,
      current_page: status.current_page,
      last_error: status.last_error,
      retry_count: status.retry_count
    }
  end

  @doc """
  Completes Phase 1 and queues Phase 2 processing for an entity.

  Marks the 90-day fetch as complete and queues the entity for 2-year fetch.

  ## Parameters
  - `entity_type` - The type of entity (:character, :corporation, :system, :alliance)
  - `entity_id` - The entity's EVE Online ID

  ## Returns
  - `{:ok, status_map}` - The updated status as a plain map
  - `{:error, reason}` - If the operation fails
  """
  @spec complete_phase1_and_queue_phase2(atom(), integer()) ::
          {:ok, map()} | {:error, term()}
  def complete_phase1_and_queue_phase2(entity_type, entity_id)
      when entity_type in [:character, :corporation, :system, :alliance] and is_integer(entity_id) do
    with {:ok, status} <- get_or_create_fetch_status(entity_type, entity_id),
         {:ok, updated} <- mark_phase1_complete(status) do
      HistoricalFetchWorker.queue_fetch(entity_type, entity_id)
      {:ok, status_to_map(updated)}
    end
  end

  def complete_phase1_and_queue_phase2(_, _), do: {:error, :invalid_entity}

  defp mark_phase1_complete(status) do
    Ash.update(status, %{}, action: :mark_phase1_complete, domain: EveDmv.Api)
  end
end
