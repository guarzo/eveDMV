# Backfill corporation names for existing participants
#
# Run with: mix run priv/repo/scripts/backfill_corporation_names.exs
#
# This script finds all unique corporation_ids in the participants table
# that don't have names, resolves them via ESI, and updates the records.

alias Ecto.Adapters.SQL
alias EveDmv.Eve.NameResolver
alias EveDmv.Repo

require Logger

Logger.info("Starting corporation name backfill...")

# Find all unique corporation IDs without names
query = """
SELECT DISTINCT corporation_id
FROM participants
WHERE corporation_id IS NOT NULL
  AND (corporation_name IS NULL OR corporation_name = '')
LIMIT 1000
"""

{:ok, %{rows: rows}} = SQL.query(Repo, query)
corp_ids = Enum.map(rows, fn [id] -> id end)

Logger.info("Found #{length(corp_ids)} corporations needing name resolution")

if Enum.empty?(corp_ids) do
  Logger.info("No corporations to backfill - all done!")
else
  # Batch resolve corporation names
  Logger.info("Resolving corporation names from ESI...")
  corp_names = NameResolver.corporation_names(corp_ids)

  Logger.info("Resolved #{map_size(corp_names)} corporation names")

  # Build arrays for bulk update
  {ids, names} =
    corp_names
    |> Enum.map(fn {corp_id, corp_name} -> {corp_id, corp_name} end)
    |> Enum.unzip()

  if Enum.empty?(ids) do
    Logger.info("No resolved names to update - skipping bulk update")
  else
    # Perform a single bulk UPDATE using PostgreSQL UNNEST
    bulk_update_query = """
    UPDATE participants p
    SET corporation_name = t.corporation_name
    FROM (
      SELECT unnest($1::text[]) AS corporation_name,
             unnest($2::integer[]) AS corporation_id
    ) t
    WHERE p.corporation_id = t.corporation_id
      AND (p.corporation_name IS NULL OR p.corporation_name = '')
    """

    case SQL.query(Repo, bulk_update_query, [names, ids]) do
      {:ok, %{num_rows: num_rows}} ->
        Logger.info(
          "Bulk updated #{num_rows} participants for #{length(ids)} corporations"
        )

      {:error, error} ->
        Logger.error("Bulk update failed: #{inspect(error)}")
    end
  end

  Logger.info("Corporation name backfill complete!")
end
