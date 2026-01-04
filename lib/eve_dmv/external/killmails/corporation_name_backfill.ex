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
    {:ok, %{status: :pending}}
  end

  @impl GenServer
  def handle_info(:run_backfill, state) do
    Task.start(fn -> run_backfill() end)
    {:noreply, %{state | status: :running}}
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

        # Update raw_data JSONB in killmails_raw
        update_raw_data(all_corp_names)

        # Update participants table
        update_participants(all_corp_names)

        Logger.info("🏢 Corporation name backfill complete!")

      {:error, error} ->
        Logger.error("🏢 Failed to query corporations for backfill: #{inspect(error)}")
    end
  end

  defp update_raw_data(corp_names) do
    Enum.each(corp_names, fn {corp_id, corp_name} ->
      # Optimized: Use participants table to find killmail_ids first (indexed),
      # then update only those specific killmails instead of scanning all rows.
      # Uses idx_participants_corp_activity on (corporation_id, killmail_time)

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

        {:ok, _} ->
          :ok

        {:error, error} ->
          Logger.error(
            "🏢 Failed to update victim raw_data for corp #{corp_id}: #{inspect(error)}"
          )
      end

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

        {:ok, _} ->
          :ok

        {:error, error} ->
          Logger.error(
            "🏢 Failed to update attacker raw_data for corp #{corp_id}: #{inspect(error)}"
          )
      end
    end)
  end

  defp update_participants(corp_names) do
    Enum.each(corp_names, fn {corp_id, corp_name} ->
      update_query = """
      UPDATE participants
      SET corporation_name = $1
      WHERE corporation_id = $2
        AND (corporation_name IS NULL OR corporation_name = '')
      """

      case SQL.query(Repo, update_query, [corp_name, corp_id]) do
        {:ok, %{num_rows: num_rows}} when num_rows > 0 ->
          Logger.debug("🏢 Updated #{num_rows} participants for #{corp_name}")

        {:ok, _} ->
          :ok

        {:error, error} ->
          Logger.error("🏢 Failed to update participants for corp #{corp_id}: #{inspect(error)}")
      end
    end)
  end
end
