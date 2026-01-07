defmodule EveDmv.Contexts.KillmailProcessing.Domain.HistoricalService do
  @moduledoc """
  Service for handling historical killmail data fetching and processing.

  This module manages the asynchronous fetching of historical killmail data
  from external sources and integration with the main killmail processing pipeline.
  """

  alias EveDmv.Contexts.KillmailProcessing.Domain.KillmailValidators

  require Logger

  @doc """
  Validate and start a task to fetch historical killmails.

  This is the public entry point that validates character IDs before processing.
  """
  @spec start_fetch_validated([integer()], keyword()) :: {:ok, map()} | {:error, term()}
  def start_fetch_validated(character_ids, opts \\ []) do
    with :ok <- KillmailValidators.validate_character_ids(character_ids) do
      start_fetch_task(character_ids, opts)
    end
  end

  @doc """
  Start a task to fetch historical killmails for the given character IDs.

  Returns a task reference that can be used to monitor progress.
  """
  @spec start_fetch_task([integer()], keyword()) :: {:ok, map()} | {:error, term()}
  def start_fetch_task(character_ids, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 5)
    # 5 minutes
    _timeout = Keyword.get(opts, :timeout, 300_000)
    callback = Keyword.get(opts, :callback)

    Logger.info("Starting historical fetch task for #{length(character_ids)} characters")

    task_ref = make_ref()

    # Start the actual fetching process in a supervised task
    task_pid =
      Task.Supervisor.async_nolink(
        EveDmv.TaskSupervisor,
        fn ->
          perform_historical_fetch(character_ids, batch_size, callback, task_ref)
        end
      )

    {:ok,
     %{
       task_ref: task_ref,
       task_pid: task_pid.pid,
       character_count: length(character_ids),
       batch_size: batch_size,
       started_at: DateTime.utc_now(),
       status: :running
     }}
  rescue
    error ->
      Logger.error("Failed to start historical fetch task: #{inspect(error)}")
      {:error, :task_start_failed}
  end

  @doc """
  Get the status of a running historical fetch task.
  """
  @spec get_task_status(reference()) :: {:ok, map()}
  def get_task_status(task_ref) do
    # This would integrate with a task registry to track status
    # For now, return a basic response
    {:ok,
     %{
       task_ref: task_ref,
       status: :running,
       progress: %{
         characters_processed: 0,
         characters_total: 0,
         killmails_fetched: 0
       }
     }}
  end

  # Private functions

  defp perform_historical_fetch(character_ids, batch_size, callback, task_ref) do
    Logger.info("Performing historical fetch for #{length(character_ids)} characters")

    character_ids
    |> Enum.chunk_every(batch_size)
    |> Enum.with_index()
    |> Enum.each(fn {batch, index} ->
      Logger.debug("Processing batch #{index + 1} with #{length(batch)} characters")

      batch_results = process_character_batch(batch)

      # Call callback if provided
      if callback do
        callback.({:batch_complete, index + 1, batch_results})
      end

      # Small delay between batches to avoid overwhelming external APIs
      :timer.sleep(1000)
    end)

    Logger.info("Historical fetch completed for task #{inspect(task_ref)}")
    {:ok, :completed}
  rescue
    error ->
      Logger.error("Historical fetch failed: #{inspect(error)}")

      if callback do
        callback.({:error, error})
      end

      {:error, error}
  end

  defp process_character_batch(character_ids) do
    # Process each character in the batch

    Enum.map(character_ids, fn character_id ->
      # Fetch recent killmails from zkillboard for this character
      case fetch_character_killmails_from_zkillboard(character_id) do
        {:ok, killmails} ->
          # Process and store the killmails
          processed_count = process_historical_killmails(killmails, character_id)
          {:ok, character_id, processed_count}

        {:error, reason} ->
          Logger.warning(
            "Failed to fetch killmails for character #{character_id}: #{inspect(reason)}"
          )

          {:error, character_id, reason}
      end
    end)
  end

  defp fetch_character_killmails_from_zkillboard(character_id) do
    # Fetch recent kills from zkillboard API
    # Limited to last 200 kills to avoid overwhelming the system
    url = "https://zkillboard.com/api/characterID/#{character_id}/limit/200/"

    case EveDmv.Http.UnifiedClient.get(url, timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, killmails} when is_list(killmails) ->
            {:ok, killmails}

          _ ->
            {:error, :invalid_response}
        end

      {:ok, %{status: 404}} ->
        # No kills found for character
        {:ok, []}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp process_historical_killmails(killmails, character_id) do
    # Process and store the fetched killmails
    alias EveDmv.Killmails.KillmailRaw
    import Ash.Query

    successful_imports =
      killmails
      |> Enum.map(fn zkb_killmail ->
        # Transform zkillboard format to our internal format
        killmail_data = %{
          killmail_id: Map.get(zkb_killmail, "killmail_id"),
          killmail_time: Map.get(zkb_killmail, "killmail_time"),
          solar_system_id: Map.get(zkb_killmail, "solar_system_id"),
          victim: Map.get(zkb_killmail, "victim", %{}),
          attackers: Map.get(zkb_killmail, "attackers", []),
          zkb: Map.get(zkb_killmail, "zkb", %{}),
          raw_data: zkb_killmail
        }

        # Check if killmail already exists
        existing_query =
          KillmailRaw
          |> new()
          |> filter(killmail_id == ^killmail_data.killmail_id)
          |> Ash.Query.limit(1)

        case Ash.read(existing_query, domain: EveDmv.Api) do
          {:ok, []} ->
            # Create new killmail
            case Ash.create(KillmailRaw, killmail_data, domain: EveDmv.Api) do
              {:ok, _} -> 1
              {:error, _} -> 0
            end

          _ ->
            # Killmail already exists, skip
            0
        end
      end)
      |> Enum.sum()

    Logger.info(
      "Imported #{successful_imports} historical killmails for character #{character_id}"
    )

    successful_imports
  end

  # NOTE: Removed placeholder implementation of fetch_character_killmails
  # This function returned empty list and violated the "no placeholder" rule
  # If historical killmails are needed, implement with real zkillboard/ESI integration
end
