defmodule EveDmv.Killmails.CorporationNameBackfill do
  @moduledoc """
  Background worker that backfills missing corporation names in killmail data.

  This runs on startup to fix existing data that was ingested before corporation
  name enrichment was added to the pipeline. New killmails are enriched at
  ingestion time in DataProcessor.enrich_entity_names/1.

  Updates both:
  - participants table (corporation_name column)
  - killmails_raw table (raw_data JSONB - victim and attackers)

  The worker runs in batches to avoid overwhelming ESI and processes up to
  1000 corporations per run. If there are more, subsequent restarts will
  continue the backfill.

  ## Error Handling

  JSONB updates to `killmails_raw` are performed on a best-effort basis. Individual
  update failures are logged but do not halt the backfill process. This allows the
  backfill to make progress even if some records have corrupt data or constraint
  violations. Failed updates are logged with corporation ID for manual investigation.
  Subsequent restarts will re-attempt updates for corporations that still have
  missing names in the participants table.

  The function returns a summary of successes and failures, which is logged at
  the end of the backfill run. Critical failures (e.g., participants bulk update
  failure) will cause the overall backfill to return an error.
  """

  use GenServer

  alias Ecto.Adapters.SQL
  alias EveDmv.Eve.NameResolver
  alias EveDmv.Repo

  require Logger

  @batch_size 100

  @doc """
  Starts the corporation name backfill worker.

  ## Arguments

    * `opts` - GenServer options (typically empty list from supervisor)

  ## Returns

    * `{:ok, pid}` - Successfully started the worker
    * `{:error, reason}` - Failed to start

  ## Usage

  This GenServer is typically started as part of the application supervision tree.
  After a 10-second delay, it automatically begins backfilling missing corporation
  names by querying ESI in batches of #{@batch_size} corporations.

  ## Example

      # Started via supervisor (typical usage)
      children = [
        EveDmv.Killmails.CorporationNameBackfill
      ]

      # Manual start (for testing)
      {:ok, pid} = EveDmv.Killmails.CorporationNameBackfill.start_link([])

  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    # Run backfill after a short delay to let the app fully start
    Process.send_after(self(), :run_backfill, :timer.seconds(10))
    {:ok, %{status: :pending, task_ref: nil}}
  end

  @impl GenServer
  def handle_info(:run_backfill, state) do
    task = Task.async(fn -> run_backfill() end)
    {:noreply, %{state | status: :running, task_ref: task.ref}}
  end

  # Handle task completion from Task.async - the task returns its result automatically
  @impl GenServer
  def handle_info({ref, result}, %{task_ref: ref} = state) do
    Process.demonitor(ref, [:flush])

    case result do
      :ok ->
        {:noreply, %{state | status: :completed}}

      {:error, reason} ->
        Logger.error("🏢 Corporation name backfill failed: #{inspect(reason)}")
        {:noreply, %{state | status: :failed, error: reason}}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{task_ref: ref} = state) do
    # Task crashed
    Logger.error("🏢 Corporation name backfill task crashed: #{inspect(reason)}")
    {:noreply, %{state | status: :failed, error: reason}}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Unrelated DOWN message, ignore
    {:noreply, state}
  end

  defp run_backfill do
    Logger.info("🏢 Starting corporation name backfill...")

    # Optimized: Find corporation IDs needing names via indexed participants table
    # Uses participants_corporation_idx on (corporation_id)
    # This is much faster than scanning raw_data JSONB in killmails_raw
    query = """
    SELECT DISTINCT p.corporation_id as corp_id
    FROM participants p
    WHERE p.corporation_id IS NOT NULL
      AND (p.corporation_name IS NULL OR p.corporation_name = '')
    LIMIT 1000
    """

    case SQL.query(Repo, query) do
      {:ok, %{rows: []}} ->
        Logger.info("🏢 No corporations need backfill - all names are present")
        :ok

      {:ok, %{rows: rows}} ->
        corp_ids = rows |> Enum.map(fn [id] -> id end) |> Enum.reject(&is_nil/1)
        Logger.info("🏢 Found #{length(corp_ids)} corporations needing name resolution")

        # Batch resolve all corporation names first
        all_corp_names =
          corp_ids
          |> Enum.chunk_every(@batch_size)
          |> Enum.with_index(1)
          |> Enum.reduce(%{}, fn {batch, batch_num}, acc ->
            Logger.info("🏢 Resolving batch #{batch_num} (#{length(batch)} corporations)")
            names = NameResolver.corporation_names(batch)
            # Be nice to ESI
            Process.sleep(100)
            Map.merge(acc, names)
          end)

        Logger.info(
          "🏢 Resolved #{map_size(all_corp_names)} corporation names, updating database..."
        )

        # Update raw_data JSONB in killmails_raw (best-effort, errors logged but don't halt)
        raw_data_result = update_raw_data(all_corp_names)
        log_raw_data_summary(raw_data_result)

        # Update participants table (using bulk update for efficiency)
        # This is critical - if it fails, we return an error
        case update_participants(all_corp_names) do
          :ok ->
            Logger.info("🏢 Corporation name backfill complete!")
            :ok

          {:error, error} ->
            # Participants update is critical, propagate the error
            {:error, {:participants_update_failed, error}}
        end

      {:error, error} ->
        Logger.error("🏢 Failed to query corporations for backfill: #{inspect(error)}")
        {:error, error}
    end
  end

  @typep raw_data_summary :: %{
           victim_updates: non_neg_integer(),
           attacker_updates: non_neg_integer(),
           victim_errors: non_neg_integer(),
           attacker_errors: non_neg_integer()
         }

  defp log_raw_data_summary({:ok, summary}) do
    Logger.info(
      "🏢 Raw data JSONB updates complete: " <>
        "#{summary.victim_updates} victim rows, #{summary.attacker_updates} attacker rows updated"
    )
  end

  defp log_raw_data_summary({:error, summary}) do
    total_errors = summary.victim_errors + summary.attacker_errors
    total_updates = summary.victim_updates + summary.attacker_updates

    Logger.warning(
      "🏢 Raw data JSONB updates completed with #{total_errors} errors (best-effort): " <>
        "#{summary.victim_updates} victim rows, #{summary.attacker_updates} attacker rows updated; " <>
        "#{summary.victim_errors} victim errors, #{summary.attacker_errors} attacker errors. " <>
        "Failed corporations will be retried on next restart."
    )

    # Return the summary for potential future use, but don't propagate as error
    # since raw_data updates are best-effort
    {:ok, total_updates}
  end

  @spec update_raw_data(map()) :: {:ok, raw_data_summary()} | {:error, raw_data_summary()}
  defp update_raw_data(corp_names) do
    initial_summary = %{
      victim_updates: 0,
      attacker_updates: 0,
      victim_errors: 0,
      attacker_errors: 0
    }

    summary =
      Enum.reduce(corp_names, initial_summary, fn {corp_id, corp_name}, acc ->
        # Optimized: Use participants table to find killmail_ids first (indexed),
        # then update only those specific killmails instead of scanning all rows.
        # Uses idx_participants_corp_activity on (corporation_id, killmail_time)

        acc = update_victim_raw_data(corp_id, corp_name, acc)
        update_attacker_raw_data(corp_id, corp_name, acc)
      end)

    if summary.victim_errors > 0 or summary.attacker_errors > 0 do
      {:error, summary}
    else
      {:ok, summary}
    end
  end

  defp update_victim_raw_data(corp_id, corp_name, acc) do
    # Update victim corporation_name in raw_data JSONB
    # First find killmails where this corp was the victim via indexed participants lookup
    update_victim_query = """
    UPDATE killmails_raw k
    SET raw_data = jsonb_set(raw_data, '{victim,corporation_name}', $1::jsonb)
    FROM (
      SELECT DISTINCT p.killmail_id, p.killmail_time
      FROM participants p
      WHERE p.corporation_id = $2
        AND p.is_victim = true
        AND (p.corporation_name IS NULL OR p.corporation_name = '')
    ) victim_kills
    WHERE k.killmail_id = victim_kills.killmail_id
      AND k.killmail_time = victim_kills.killmail_time
      AND (k.raw_data->'victim'->>'corporation_name' IS NULL
           OR k.raw_data->'victim'->>'corporation_name' = '')
    """

    case SQL.query(Repo, update_victim_query, [Jason.encode!(corp_name), corp_id]) do
      {:ok, %{num_rows: num_rows}} when num_rows > 0 ->
        Logger.debug("🏢 Updated #{num_rows} killmail victims for #{corp_name}")
        %{acc | victim_updates: acc.victim_updates + num_rows}

      {:ok, _} ->
        acc

      {:error, error} ->
        Logger.error("🏢 Failed to update victim raw_data for corp #{corp_id}: #{inspect(error)}")

        %{acc | victim_errors: acc.victim_errors + 1}
    end
  end

  defp update_attacker_raw_data(corp_id, corp_name, acc) do
    # Update attacker corporation_names in raw_data JSONB
    # First find killmails where this corp was an attacker via indexed participants lookup
    update_attackers_query = """
    UPDATE killmails_raw k
    SET raw_data = jsonb_set(
      raw_data,
      '{attackers}',
      (
        SELECT jsonb_agg(
          CASE
            WHEN (attacker->>'corporation_id')::bigint = $2
                 AND (attacker->>'corporation_name' IS NULL OR attacker->>'corporation_name' = '')
            THEN jsonb_set(attacker, '{corporation_name}', $1::jsonb)
            ELSE attacker
          END
        )
        FROM jsonb_array_elements(raw_data->'attackers') AS attacker
      )
    )
    FROM (
      SELECT DISTINCT p.killmail_id, p.killmail_time
      FROM participants p
      WHERE p.corporation_id = $2
        AND p.is_victim = false
        AND (p.corporation_name IS NULL OR p.corporation_name = '')
    ) attacker_kills
    WHERE k.killmail_id = attacker_kills.killmail_id
      AND k.killmail_time = attacker_kills.killmail_time
      AND k.raw_data->'attackers' IS NOT NULL
    """

    case SQL.query(Repo, update_attackers_query, [Jason.encode!(corp_name), corp_id]) do
      {:ok, %{num_rows: num_rows}} when num_rows > 0 ->
        Logger.debug("🏢 Updated #{num_rows} killmail attackers for #{corp_name}")
        %{acc | attacker_updates: acc.attacker_updates + num_rows}

      {:ok, _} ->
        acc

      {:error, error} ->
        Logger.error(
          "🏢 Failed to update attacker raw_data for corp #{corp_id}: #{inspect(error)}"
        )

        %{acc | attacker_errors: acc.attacker_errors + 1}
    end
  end

  defp update_participants(corp_names) when map_size(corp_names) == 0 do
    :ok
  end

  defp update_participants(corp_names) do
    # Bulk update using UNNEST for efficiency - single query instead of N queries
    # This is the same pattern used in backfill_corporation_names.exs
    {corp_ids, names} = Enum.unzip(corp_names)

    update_query = """
    UPDATE participants p
    SET corporation_name = updates.corp_name
    FROM (
      SELECT UNNEST($1::bigint[]) as corp_id, UNNEST($2::text[]) as corp_name
    ) updates
    WHERE p.corporation_id = updates.corp_id
      AND (p.corporation_name IS NULL OR p.corporation_name = '')
    """

    case SQL.query(Repo, update_query, [corp_ids, names]) do
      {:ok, %{num_rows: num_rows}} ->
        Logger.info("🏢 Bulk updated #{num_rows} participant records")
        :ok

      {:error, error} ->
        Logger.error("🏢 Failed to bulk update participants: #{inspect(error)}")
        {:error, error}
    end
  end
end
