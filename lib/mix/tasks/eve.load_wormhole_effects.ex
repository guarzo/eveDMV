defmodule Mix.Tasks.Eve.LoadWormholeEffects do
  @shortdoc "Load wormhole effect types from reference data"

  @moduledoc """
  Loads wormhole effect types from reference data files (tmp/wormholeSystems.json
  and tmp/effects.json) and updates the solar systems table with effect information.

  This task maps specific wormhole systems to their environmental effect types
  (Pulsar, Black Hole, Magnetar, etc.) based on reference data.

  ## Usage

      mix eve.load_wormhole_effects
      
  ## Options

    * `--dry-run` - Show what would be updated without making changes
    * `--force` - Force update even if data seems current
    
  ## Examples

      mix eve.load_wormhole_effects
      mix eve.load_wormhole_effects --dry-run
      mix eve.load_wormhole_effects --force
  """

  use Mix.Task

  alias EveDmv.Eve.StaticDataLoader.WormholeEffectsLoader

  def run(args) do
    # Start the application to access the database
    Mix.Task.run("app.start")

    {opts, _args} = OptionParser.parse!(args, strict: [dry_run: :boolean, force: :boolean])

    if opts[:dry_run] do
      Mix.shell().info("DRY RUN: Would load wormhole effects data from reference files")
      Mix.shell().info("Use without --dry-run to perform actual update")
    else
      case WormholeEffectsLoader.load_wormhole_effects() do
        {:ok, updated_count} ->
          Mix.shell().info(
            "✅ Successfully updated #{updated_count} solar systems with wormhole effect data"
          )

        {:error, reason} ->
          Mix.shell().error("❌ Failed to load wormhole effects data: #{reason}")
          System.halt(1)
      end
    end
  end
end
