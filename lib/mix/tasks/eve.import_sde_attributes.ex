defmodule Mix.Tasks.Eve.ImportSdeAttributes do
  @moduledoc """
  Import EVE Online SDE ship attributes from Fuzzwork.

  This task downloads the latest SDE data from Fuzzwork and imports
  real ship attribute data including HP values and resistances.

  ## Usage

      mix eve.import_sde_attributes

  ## Options

    * `--force` - Force re-import even if data already exists
    
  ## Examples

      # Import SDE ship attributes
      mix eve.import_sde_attributes
      
      # Force re-import
      mix eve.import_sde_attributes --force
  """

  use Mix.Task

  alias EveDmv.StaticData.SdeImporter

  @shortdoc "Import EVE Online SDE ship attributes"

  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, switches: [force: :boolean])

    if opts[:force] || should_import?() do
      Mix.shell().info("Starting SDE ship attributes import...")

      case SdeImporter.import_ship_attributes() do
        {:ok, count} ->
          Mix.shell().info("✅ Successfully imported #{count} ship attributes from SDE")

        {:error, reason} ->
          Mix.shell().error("❌ Failed to import SDE data: #{inspect(reason)}")
          System.halt(1)
      end
    else
      Mix.shell().info("SDE data already exists. Use --force to re-import.")
    end
  end

  defp should_import? do
    case EveDmv.Repo.query(
           "SELECT COUNT(*) FROM ship_attributes WHERE data_source = 'sde_import'"
         ) do
      {:ok, %{rows: [[0]]}} -> true
      _ -> false
    end
  end
end
