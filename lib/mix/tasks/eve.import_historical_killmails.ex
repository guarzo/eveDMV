defmodule Mix.Tasks.Eve.ImportHistoricalKillmails do
  @moduledoc """
  Import historical killmail data from JSON archives.

  This task safely imports historical killmail data into the production database
  using Ash's upsert functionality to handle duplicates.

  ## Usage

      # Import all archives
      mix eve.import_historical_killmails
      
      # Import specific file
      mix eve.import_historical_killmails --file tmp/2024-01-killmails.json
      
      # Dry run (validate data without importing)
      mix eve.import_historical_killmails --dry-run
      
      # Import with custom batch size
      mix eve.import_historical_killmails --batch-size 100

  ## Options

    * `--file` - Import single file instead of all archives
    * `--dry-run` - Validate data without importing to database
    * `--batch-size` - Number of records per batch (default: 500)
    * `--skip-validation` - Skip data validation (faster but riskier)
  """

  use Mix.Task
  require Logger

  @shortdoc "Import historical killmail data from JSON archives"

  @default_batch_size 500
  @archive_pattern "/workspace/tmp/*.json"

  def run(args) do
    Mix.Task.run("app.start")

    {opts, _args} =
      OptionParser.parse!(args,
        strict: [
          file: :string,
          dry_run: :boolean,
          batch_size: :integer,
          skip_validation: :boolean
        ],
        aliases: [f: :file, d: :dry_run, b: :batch_size, s: :skip_validation]
      )

    batch_size = opts[:batch_size] || @default_batch_size
    dry_run = opts[:dry_run] || false
    skip_validation = opts[:skip_validation] || false

    Logger.info("Starting historical killmail import")
    Logger.info("Batch size: #{batch_size}")
    Logger.info("Dry run: #{dry_run}")
    Logger.info("Skip validation: #{skip_validation}")

    files = get_files(opts[:file])

    if length(files) == 0 do
      Logger.error("No archive files found")
      exit({:shutdown, 1})
    end

    Logger.info("Found #{length(files)} archive files")

    # Pre-flight checks
    unless skip_validation do
      validate_environment()
      validate_files(files)
    end

    # Import each file
    total_imported = 0
    total_errors = 0

    for file <- files do
      Logger.info("Processing #{Path.basename(file)}")

      case import_file(file, batch_size, dry_run) do
        {:ok, imported} ->
          _total_imported = total_imported + imported
          Logger.info("✅ Imported #{imported} records from #{Path.basename(file)}")

        {:error, reason} ->
          _total_errors = total_errors + 1
          Logger.error("❌ Failed to import #{Path.basename(file)}: #{reason}")
      end
    end

    Logger.info("Import complete:")
    Logger.info("  Total imported: #{total_imported}")
    Logger.info("  Files with errors: #{total_errors}")

    if total_errors > 0 do
      exit({:shutdown, 1})
    end
  end

  defp get_files(nil), do: Path.wildcard(@archive_pattern)
  defp get_files(file) when is_binary(file), do: [file]

  defp validate_environment do
    # Ensure we're connected to the right database
    case Application.get_env(:eve_dmv, EveDmv.Repo) do
      nil ->
        Logger.error("Database configuration not found")
        exit({:shutdown, 1})

      config ->
        url = config[:url]

        if is_nil(url) or String.contains?(url, "localhost") do
          Logger.warning("⚠️  Database appears to be localhost - confirm this is correct")

          unless confirm("Continue with localhost database?") do
            exit({:shutdown, 1})
          end
        end

        Logger.info("Database: #{obscure_url(url)}")
    end

    # Check table exists
    case Ecto.Adapters.SQL.query(EveDmv.Repo, "SELECT COUNT(*) FROM killmails_raw LIMIT 1", []) do
      {:ok, _} ->
        Logger.info("✅ killmails_raw table exists")

      {:error, reason} ->
        Logger.error("❌ Cannot access killmails_raw table: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp validate_files(files) do
    Logger.info("Validating #{length(files)} files...")

    for file <- files do
      case validate_file_structure(file) do
        :ok ->
          Logger.debug("✅ #{Path.basename(file)} structure valid")

        {:error, reason} ->
          Logger.error("❌ #{Path.basename(file)} invalid: #{reason}")
          exit({:shutdown, 1})
      end
    end

    Logger.info("✅ All files validated")
  end

  defp validate_file_structure(file_path) do
    try do
      case File.read(file_path) do
        {:ok, content} ->
          data = Jason.decode!(content)

          unless is_list(data) do
            raise "Root element must be array"
          end

          if length(data) == 0 do
            raise "File is empty"
          end

          # Validate first record structure
          first_record = hd(data)
          validate_killmail_structure(first_record)

          :ok

        {:error, reason} ->
          {:error, "Cannot read file: #{reason}"}
      end
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  defp validate_killmail_structure(killmail) do
    required_fields = [
      "killmail_id",
      "killmail_time",
      "solar_system_id",
      "hash",
      "victim",
      "Attackers"
    ]

    for field <- required_fields do
      unless Map.has_key?(killmail, field) do
        raise "Missing required field: #{field}"
      end
    end

    victim = killmail["victim"]
    victim_fields = ["character_id", "corporation_id", "alliance_id", "ship_type_id"]

    for field <- victim_fields do
      unless Map.has_key?(victim, field) do
        raise "Missing victim field: #{field}"
      end
    end

    unless is_list(killmail["Attackers"]) do
      raise "Attackers must be array"
    end
  end

  defp import_file(file_path, batch_size, dry_run) do
    try do
      content = File.read!(file_path)
      killmails = Jason.decode!(content)

      Logger.info("Found #{length(killmails)} killmails in #{Path.basename(file_path)}")

      if dry_run do
        Logger.info("DRY RUN: Would import #{length(killmails)} records")
        {:ok, length(killmails)}
      else
        import_killmails_in_batches(killmails, batch_size)
      end
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  defp import_killmails_in_batches(killmails, batch_size) do
    total_count = length(killmails)
    _imported_count = 0

    killmails
    |> Enum.chunk_every(batch_size)
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, 0}, fn {batch, index}, {:ok, acc} ->
      batch_num = index + 1
      total_batches = div(total_count, batch_size) + 1

      Logger.info("Processing batch #{batch_num}/#{total_batches} (#{length(batch)} records)")

      case import_batch(batch) do
        {:ok, imported} ->
          {:cont, {:ok, acc + imported}}

        {:error, reason} ->
          Logger.error("Batch #{batch_num} failed: #{reason}")
          {:halt, {:error, reason}}
      end
    end)
  end

  defp import_batch(killmails) do
    try do
      transformed_killmails = Enum.map(killmails, &transform_killmail/1)

      # Use Ash.bulk_create with upsert for safe import
      case Ash.bulk_create(
             transformed_killmails,
             EveDmv.Killmails.KillmailRaw,
             :ingest_from_source
           ) do
        %Ash.BulkResult{status: :success, records: records} ->
          {:ok, length(records)}

        %Ash.BulkResult{status: :error, errors: errors} ->
          error_msg = errors |> Enum.map(&Exception.message/1) |> Enum.join(", ")
          {:error, error_msg}
      end
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  defp transform_killmail(archive_data) do
    %{
      killmail_id: archive_data["killmail_id"],
      killmail_hash: archive_data["hash"],
      killmail_time: parse_datetime(archive_data["killmail_time"]),
      solar_system_id: archive_data["solar_system_id"],
      victim_character_id: normalize_id(archive_data["victim"]["character_id"]),
      victim_corporation_id: normalize_id(archive_data["victim"]["corporation_id"]),
      victim_alliance_id: normalize_id(archive_data["victim"]["alliance_id"]),
      victim_ship_type_id: archive_data["victim"]["ship_type_id"],
      attacker_count: length(archive_data["Attackers"]),
      raw_data: archive_data,
      source: "historical_archive"
    }
  end

  defp parse_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> raise "Invalid datetime: #{datetime_string}"
    end
  end

  # Convert 0 to nil for optional fields
  defp normalize_id(0), do: nil
  defp normalize_id(id) when is_integer(id), do: id
  defp normalize_id(nil), do: nil

  defp obscure_url(url) do
    url
    |> String.replace(~r/\/\/[^:]+:[^@]+@/, "//***:***@")
    |> String.replace(~r/password=[^&\s]+/, "password=***")
  end

  defp confirm(message) do
    IO.puts(message <> " [y/N]")

    case IO.read(:stdio, :line) do
      {:ok, "y\n"} -> true
      {:ok, "Y\n"} -> true
      _ -> false
    end
  end
end
