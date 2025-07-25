defmodule EveDmv.Historical.KillmailImporter do
  @moduledoc """
  Core functionality for importing historical killmails.

  This module contains the core logic extracted from the Mix task to reduce
  module dependencies and improve maintainability.
  """

  require Logger

  @doc """
  Transform killmail data from archive format to database format.
  """
  def transform_killmail(archive_data) do
    hash = get_or_generate_hash(archive_data)

    if hash == "" do
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

  @doc """
  Validate the structure of a killmail record.
  """
  def validate_killmail_structure(killmail) do
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

  @doc """
  Import a batch of killmails using Ash.bulk_create.
  """
  def import_batch(killmails) do
    try do
      transformed_killmails = Enum.map(killmails, &transform_killmail/1)

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
          handle_partial_success(result)

        %Ash.BulkResult{status: :error, errors: errors} ->
          handle_error_result(errors)
      end
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  # Private functions

  defp parse_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> raise "Invalid datetime: #{datetime_string}"
    end
  end

  defp normalize_id(0), do: nil
  defp normalize_id(id) when is_integer(id), do: id
  defp normalize_id(nil), do: nil

  defp get_or_generate_hash(archive_data) do
    case archive_data["hash"] do
      nil ->
        generate_hash_from_data(archive_data)

      "" ->
        generate_hash_from_data(archive_data)

      hash when is_binary(hash) ->
        hash

      _ ->
        Logger.warning("Invalid hash type: #{inspect(archive_data["hash"])}, generating new hash")
        generate_hash_from_data(archive_data)
    end
  end

  defp generate_hash_from_data(archive_data) do
    id = archive_data["killmail_id"]
    timestamp = archive_data["killmail_time"]

    if is_nil(id) or is_nil(timestamp) do
      raise "Cannot generate hash: killmail_id or killmail_time is nil"
    end

    hash_data = "#{id}-#{timestamp}"
    hash = :crypto.hash(:sha256, hash_data)
    Base.encode16(hash, case: :lower)
  end

  defp handle_partial_success(result) do
    success_count = length(result.records || [])
    error_count = length(result.errors || [])
    Logger.warning("Partial success: imported #{success_count}, failed #{error_count}")

    {duplicate_errors, other_errors} = categorize_errors(result.errors || [])

    if duplicate_errors > 0 do
      Logger.info("Skipped #{duplicate_errors} duplicate killmails")
    end

    if other_errors > 0 do
      Logger.warning("#{other_errors} non-duplicate errors occurred")
      log_sample_errors(result.errors || [])
    end

    {:ok, success_count}
  end

  defp handle_error_result(errors) do
    error_count = length(errors)
    {duplicate_errors, other_errors} = categorize_errors(errors)

    if duplicate_errors == error_count do
      Logger.info("All #{duplicate_errors} records were duplicates, skipping batch")
      {:ok, 0}
    else
      if duplicate_errors > 0 do
        Logger.info("Skipped #{duplicate_errors} duplicate killmails")
      end

      if other_errors > 0 do
        log_sample_errors(errors)
      end

      {:error, "#{other_errors} non-duplicate records failed to import"}
    end
  end

  defp categorize_errors(errors) do
    duplicate_errors =
      Enum.count(errors, fn error ->
        error_msg = inspect(error)

        String.contains?(error_msg, "killmail_id") and
          (String.contains?(error_msg, "already exists") or
             String.contains?(error_msg, "unique constraint") or
             String.contains?(error_msg, "duplicate key"))
      end)

    other_errors = length(errors) - duplicate_errors
    {duplicate_errors, other_errors}
  end

  defp log_sample_errors(errors) do
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
end
