defmodule Mix.Tasks.Eve.ImportShipAttributes do
  @moduledoc """
  Import ship attributes into the ship_attributes table.

  This task populates the ship_attributes table with estimated values
  based on ship classes and groups. In production, these would be
  replaced with actual calculated values from fitting data.

  ## Usage

      mix eve.import_ship_attributes

  ## Options

      --force - Force re-import even if attributes already exist
      --limit N - Only import N ships (for testing)
  """

  use Mix.Task

  @shortdoc "Import ship attributes into database"

  require Logger

  @impl Mix.Task
  def run(args) do
    # Start the application
    Mix.Task.run("app.start")

    # Parse options
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [force: :boolean, limit: :integer],
        aliases: [f: :force, l: :limit]
      )

    force = Keyword.get(opts, :force, false)
    limit = Keyword.get(opts, :limit, nil)

    Logger.info("Starting ship attribute import...")
    Logger.info("Options: force=#{force}, limit=#{inspect(limit)}")

    # Start the importer service
    {:ok, _pid} = EveDmv.StaticData.ShipAttributeImporter.start_link()

    # Run the import
    case EveDmv.StaticData.ShipAttributeImporter.import_all(force: force, limit: limit) do
      {:ok, results} ->
        Logger.info("""
        Ship attribute import completed:
        - Total ships: #{results.total_ships}
        - Successfully imported: #{results.imported}
        - Failed: #{results.failed}
        - Duration: #{results.duration_ms}ms
        """)

        if results.failed > 0 do
          Logger.warning("#{results.failed} ships failed to import. Check logs for details.")
        end

      {:error, reason} ->
        Logger.error("Ship attribute import failed: #{inspect(reason)}")
        Mix.raise("Import failed")
    end
  end
end
