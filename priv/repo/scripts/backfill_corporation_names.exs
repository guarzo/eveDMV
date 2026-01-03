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

  # Update participants in batches
  Enum.each(corp_names, fn {corp_id, corp_name} ->
    update_query = """
    UPDATE participants
    SET corporation_name = $1
    WHERE corporation_id = $2
      AND (corporation_name IS NULL OR corporation_name = '')
    """

    case SQL.query(Repo, update_query, [corp_name, corp_id]) do
      {:ok, %{num_rows: num_rows}} ->
        Logger.info("Updated #{num_rows} participants for corporation #{corp_id}: #{corp_name}")

      {:error, error} ->
        Logger.error("Failed to update corporation #{corp_id}: #{inspect(error)}")
    end
  end)

  Logger.info("Corporation name backfill complete!")
end
