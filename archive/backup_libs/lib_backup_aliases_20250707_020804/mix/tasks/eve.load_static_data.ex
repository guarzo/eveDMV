defmodule Mix.Tasks.Eve.LoadStaticData do
  @moduledoc """
  Load EVE Online static data into the database.

  This task downloads and imports EVE static data including:
  - Solar systems (with security status and regions)
  - Item types (ships, modules, etc.)

  ## Usage

      mix eve.load_static_data         # Load all static data
      mix eve.load_static_data --force # Force reload even if data exists

  ## Examples

      $ mix eve.load_static_data
      Checking if static data is already loaded...
      Loading EVE static data...
      Loading solar systems... [====================] 100%
      Loaded 8,285 solar systems
      Loading item types... [====================] 100%
      Loaded 38,453 item types
      Static data loading complete!
  """

  use Mix.Task
  alias EveDmv.Eve.NameResolver
  alias EveDmv.Eve.StaticDataLoader

  @shortdoc "Load EVE static data if not already present"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    force = "--force" in args

    Mix.shell().info("Checking if static data is already loaded...")

    if not force and StaticDataLoader.static_data_loaded?() do
      Mix.shell().info("Static data already loaded. Use --force to reload.")
    else
      Mix.shell().info("Loading EVE static data...")

      case StaticDataLoader.load_all_static_data() do
        {:ok, %{item_types: item_count, solar_systems: system_count}} ->
          Mix.shell().info("Successfully loaded:")
          Mix.shell().info("  - #{format_number(item_count)} item types")
          Mix.shell().info("  - #{format_number(system_count)} solar systems")
          Mix.shell().info("Static data loading complete!")

          # Warm the cache after loading
          Mix.shell().info("Warming name resolver cache...")
          NameResolver.warm_cache()
          Mix.shell().info("Cache warmed successfully!")

        {:error, reason} ->
          Mix.shell().error("Failed to load static data: #{inspect(reason)}")
          exit(:normal)
      end
    end
  end

  defp format_number(n) do
    # Use Elixir's built-in number formatting with delimiter
    n
    |> Integer.to_string()
    |> String.replace(~r/(\d)(?=(\d{3})+(?!\d))/, "\\1,")
  end
end
