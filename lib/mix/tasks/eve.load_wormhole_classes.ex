defmodule Mix.Tasks.Eve.LoadWormholeClasses do
  @shortdoc "Load wormhole class data from Fuzzwork"

  @moduledoc """
  Loads wormhole class data from Fuzzwork's mapLocationWormholeClasses.csv
  and updates the solar systems table with wormhole class information.

  This task fetches the latest wormhole class data from Fuzzwork and updates
  the eve_solar_systems table with wormhole_class_id values.

  ## Usage

      mix eve.load_wormhole_classes
      
  ## Options

    * `--dry-run` - Show what would be updated without making changes
    * `--force` - Force update even if data seems current
    
  ## Examples

      mix eve.load_wormhole_classes
      mix eve.load_wormhole_classes --dry-run
      mix eve.load_wormhole_classes --force
  """

  use Mix.Task

  alias EveDmv.Eve.StaticDataLoader.WormholeClassLoader

  def run(args) do
    # Start the application to access the database
    Mix.Task.run("app.start")

    {opts, _args} = OptionParser.parse!(args, strict: [dry_run: :boolean, force: :boolean])

    if opts[:dry_run] do
      Mix.shell().info("DRY RUN: Would load wormhole class data from Fuzzwork")
      Mix.shell().info("Use without --dry-run to perform actual update")
    else
      case WormholeClassLoader.load_wormhole_classes() do
        {:ok, updated_count} ->
          Mix.shell().info(
            "✅ Successfully updated #{updated_count} solar systems with wormhole class data"
          )

        {:error, reason} ->
          Mix.shell().error("❌ Failed to load wormhole class data: #{reason}")
          System.halt(1)
      end
    end
  end
end
