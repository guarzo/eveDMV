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

    if Enum.empty?(files) do
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
    {total_imported, total_errors} =
      Enum.reduce(files, {0, 0}, fn file, {imported_acc, errors_acc} ->
        Logger.info("Processing #{Path.basename(file)}")

        case import_file(file, batch_size, dry_run) do
          {:ok, imported} ->
            Logger.info("✅ Imported #{imported} records from #{Path.basename(file)}")
            {imported_acc + imported, errors_acc}

          {:error, reason} ->
            Logger.error("❌ Failed to import #{Path.basename(file)}: #{reason}")
            {imported_acc, errors_acc + 1}
        end
      end)

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

          if Enum.empty?(data) do
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
    # alliance_id is optional (value 0 means no alliance)
    required_victim_fields = ["character_id", "corporation_id", "ship_type_id"]

    for field <- required_victim_fields do
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
             :ingest_from_source,
             return_records?: true,
             return_errors?: true,
             stop_on_error?: false
           ) do
        %Ash.BulkResult{status: :success, records: records} ->
          {:ok, length(records)}

        %Ash.BulkResult{status: :partial_success} = result ->
          success_count = length(result.records || [])
          error_count = length(result.errors || [])
          Logger.warning("Partial success: imported #{success_count}, failed #{error_count}")

          # Categorize errors
          duplicate_errors =
            Enum.count(result.errors, fn error ->
              error_msg = inspect(error)

              String.contains?(error_msg, "killmail_id") and
                (String.contains?(error_msg, "already exists") or
                   String.contains?(error_msg, "unique constraint") or
                   String.contains?(error_msg, "duplicate key"))
            end)

          other_errors = error_count - duplicate_errors

          if duplicate_errors > 0 do
            Logger.info("Skipped #{duplicate_errors} duplicate killmails")
          end

          if other_errors > 0 do
            Logger.warning("#{other_errors} non-duplicate errors occurred")
            # Log first few non-duplicate errors for debugging
            result.errors
            |> Enum.reject(fn error ->
              error_msg = inspect(error)

              String.contains?(error_msg, "killmail_id") and
                (String.contains?(error_msg, "already exists") or
                   String.contains?(error_msg, "unique constraint") or
                   String.contains?(error_msg, "duplicate key"))
            end)
            |> Enum.take(3)
            |> Enum.each(fn error ->
              Logger.error("Import error: #{inspect(error)}")
            end)
          end

          {:ok, success_count}

        %Ash.BulkResult{status: :error, errors: errors} ->
          error_count = length(errors)

          # Categorize errors
          duplicate_errors =
            Enum.count(errors, fn error ->
              error_msg = inspect(error)

              String.contains?(error_msg, "killmail_id") and
                (String.contains?(error_msg, "already exists") or
                   String.contains?(error_msg, "unique constraint") or
                   String.contains?(error_msg, "duplicate key"))
            end)

          other_errors = error_count - duplicate_errors

          if duplicate_errors == error_count do
            # All errors are duplicates - this is actually success
            Logger.info("All #{duplicate_errors} records were duplicates, skipping batch")
            {:ok, 0}
          else
            if duplicate_errors > 0 do
              Logger.info("Skipped #{duplicate_errors} duplicate killmails")
            end

            if other_errors > 0 do
              # Log first few non-duplicate errors for debugging
              errors
              |> Enum.reject(fn error ->
                error_msg = inspect(error)

                String.contains?(error_msg, "killmail_id") and
                  (String.contains?(error_msg, "already exists") or
                     String.contains?(error_msg, "unique constraint") or
                     String.contains?(error_msg, "duplicate key"))
              end)
              |> Enum.take(3)
              |> Enum.each(fn error ->
                Logger.error("Import error: #{inspect(error)}")
              end)
            end

            {:error, "#{other_errors} non-duplicate records failed to import"}
          end
      end
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  defp transform_killmail(archive_data) do
    hash = get_or_generate_hash(archive_data)

    # Debug logging
    if is_nil(hash) or hash == "" do
      Logger.error("Hash is nil or empty for killmail #{archive_data["killmail_id"]}")
      Logger.error("Archive data keys: #{inspect(Map.keys(archive_data))}")
      Logger.error("Hash field value: #{inspect(archive_data["hash"])}")
    end

    %{
      killmail_id: archive_data["killmail_id"],
      killmail_hash: hash,
      killmail_time: parse_datetime(archive_data["killmail_time"]),
      solar_system_id: archive_data["solar_system_id"],
      victim_character_id: normalize_id(archive_data["victim"]["character_id"]),
      victim_corporation_id: normalize_id(archive_data["victim"]["corporation_id"]),
      victim_alliance_id: normalize_id(Map.get(archive_data["victim"], "alliance_id", 0)),
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

  # Get hash from killmail data or generate one if missing
  defp get_or_generate_hash(archive_data) do
    case archive_data["hash"] do
      nil ->
        # Generate a hash from killmail ID and time
        id = archive_data["killmail_id"]
        timestamp = archive_data["killmail_time"]

        if is_nil(id) or is_nil(timestamp) do
          raise "Cannot generate hash: killmail_id or killmail_time is nil"
        end

        # Generate hash from killmail ID and timestamp
        hash_data = "#{id}-#{timestamp}"
        hash = :crypto.hash(:sha256, hash_data)
        Base.encode16(hash, case: :lower)

      "" ->
        # Empty string hash - generate one
        id = archive_data["killmail_id"]
        timestamp = archive_data["killmail_time"]

        if is_nil(id) or is_nil(timestamp) do
          raise "Cannot generate hash: killmail_id or killmail_time is nil"
        end

        # Generate hash from killmail ID and timestamp
        hash_data = "#{id}-#{timestamp}"
        hash = :crypto.hash(:sha256, hash_data)
        Base.encode16(hash, case: :lower)

      hash when is_binary(hash) ->
        # Valid hash exists
        hash

      _ ->
        # Invalid hash type - generate one
        Logger.warning("Invalid hash type: #{inspect(archive_data["hash"])}, generating new hash")
        id = archive_data["killmail_id"]
        timestamp = archive_data["killmail_time"]

        if is_nil(id) or is_nil(timestamp) do
          raise "Cannot generate hash: killmail_id or killmail_time is nil"
        end

        # Generate hash from killmail ID and timestamp
        hash_data = "#{id}-#{timestamp}"
        hash = :crypto.hash(:sha256, hash_data)
        Base.encode16(hash, case: :lower)
    end
  end

  defp obscure_url(url) do
    url
    |> String.replace(~r/\/\/[^:]+:[^@]+@/, "//***:***@")
    |> String.replace(~r/password=[^&\s]+/, "password=***")
  end

  defp confirm(message) do
    IO.puts(message <> " [y/N]")

    case IO.read(:stdio, :line) do
      "y\n" -> true
      "Y\n" -> true
      _ -> false
    end
  end
end
