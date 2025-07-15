defmodule EveDmv.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  require Logger
  @app :eve_dmv

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  def import_historical_killmails(archive_dir, batch_size) do
    load_app()
    Application.ensure_all_started(@app)

    # Get archive files to import
    archive_files = Path.wildcard(Path.join(archive_dir, "*.json"))

    Logger.info("Found #{length(archive_files)} files to import")

    # First, read all killmails from all files
    Logger.info("Reading killmails from all files...")

    all_killmails =
      Enum.flat_map(archive_files, fn file ->
        Logger.debug("Reading #{Path.basename(file)}...")

        case File.read(file) do
          {:ok, content} ->
            case Jason.decode(content) do
              {:ok, data} when is_list(data) ->
                data

              # Single killmail
              {:ok, data} ->
                [data]

              {:error, reason} ->
                Logger.error("Error parsing #{file}: #{inspect(reason)}")
                []
            end

          {:error, reason} ->
            Logger.error("Error reading #{file}: #{inspect(reason)}")
            []
        end
      end)

    Logger.info("Found #{length(all_killmails)} total killmails to import")

    # Now batch the killmails by the specified batch_size
    total_batches = ceil(length(all_killmails) / batch_size)

    all_killmails
    |> Enum.chunk_every(batch_size)
    |> Enum.with_index()
    |> Enum.each(fn {killmail_batch, batch_index} ->
      Logger.info(
        "Processing batch #{batch_index + 1}/#{total_batches} (#{length(killmail_batch)} killmails)"
      )

      # Transform killmails for database insertion
      changesets =
        Enum.map(killmail_batch, fn killmail ->
          %{
            killmail_id: killmail["killmail_id"],
            killmail_time: parse_killmail_time(killmail["killmail_time"]),
            killmail_hash: killmail["zkb"]["hash"],
            solar_system_id: killmail["solar_system_id"],
            victim_character_id: get_in(killmail, ["victim", "character_id"]),
            victim_corporation_id: get_in(killmail, ["victim", "corporation_id"]),
            victim_alliance_id: get_in(killmail, ["victim", "alliance_id"]),
            victim_ship_type_id: get_in(killmail, ["victim", "ship_type_id"]),
            attacker_count: length(killmail["attackers"] || []),
            raw_data: killmail,
            source: "historical_import"
          }
        end)

      # Insert using the database inserter
      case EveDmv.Killmails.DatabaseInserter.insert_raw_killmails(changesets) do
        :ok ->
          Logger.info(
            "Successfully imported #{length(killmail_batch)} killmails from batch #{batch_index + 1}"
          )

        :error ->
          Logger.error("Failed to import batch #{batch_index + 1}")
      end
    end)

    Logger.info("Import completed!")
  end

  defp parse_killmail_time(time_string) when is_binary(time_string) do
    case DateTime.from_iso8601(time_string) do
      {:ok, datetime, _offset} ->
        datetime

      {:error, reason} ->
        Logger.warning("Failed to parse killmail time '#{time_string}': #{inspect(reason)}")
        DateTime.utc_now()
    end
  end

  defp parse_killmail_time(_), do: DateTime.utc_now()
end
