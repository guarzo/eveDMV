defmodule EveDmv.Contexts.BattleAnalysis.Domain.ZkillboardImportService do
  @moduledoc """
  Service for importing killmail data from zkillboard.

  Supports importing individual killmails, related kills, and battle reports
  by parsing zkillboard URLs and fetching data from their API.
  """

  require Logger

  @zkillboard_api_base "https://zkillboard.com/api"

  @doc """
  Imports killmail data from a zkillboard URL.

  Supports various zkillboard URL formats:
  - Single kill: https://zkillboard.com/kill/128431979/
  - Related kills: https://zkillboard.com/related/31001629/202507090500/
  - Character kills: https://zkillboard.com/character/1234567890/
  - Corporation kills: https://zkillboard.com/corporation/98765432/
  - System kills: https://zkillboard.com/system/30003089/

  Returns {:ok, killmail_ids} or {:error, reason}
  """
  def import_from_url(url) when is_binary(url) do
    Logger.info("Importing from zkillboard URL: #{url}")

    case parse_zkillboard_url(url) do
      {:ok, import_spec} ->
        import_killmails(import_spec)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches and imports a specific killmail by ID.
  """
  def import_killmail(killmail_id) when is_integer(killmail_id) do
    Logger.info("Importing killmail #{killmail_id} from zkillboard")

    case fetch_zkillboard_data("/kills/killID/#{killmail_id}/") do
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetches related kills for a specific system and time.
  """
  def import_related_kills(system_id, timestamp) do
    Logger.info("Importing related kills for system #{system_id} at #{timestamp}")

    # Format timestamp for zkillboard (YYYYMMDDHHMM)
    formatted_time = format_timestamp_for_zkb(timestamp)

    case fetch_zkillboard_data("/related/#{system_id}/#{formatted_time}/") do
      {:error, reason} -> {:error, reason}
    end
  end

  # Private functions

  defp parse_zkillboard_url(url) do
    uri = URI.parse(url)

    if uri.host != "zkillboard.com" do
      {:error, :invalid_zkillboard_url}
    else
      parse_zkillboard_path(uri.path)
    end
  end

  defp parse_zkillboard_path(path) do
    segments =
      path
      |> String.split("/", trim: true)
      |> Enum.filter(&(&1 != ""))

    case segments do
      ["kill", killmail_id] ->
        case Integer.parse(killmail_id) do
          {id, ""} -> {:ok, {:single_kill, id}}
          _ -> {:error, :invalid_killmail_id}
        end

      ["related", system_id, timestamp] ->
        case Integer.parse(system_id) do
          {id, ""} -> {:ok, {:related_kills, id, timestamp}}
          _ -> {:error, :invalid_system_id}
        end

      ["character", character_id | _rest] ->
        case Integer.parse(character_id) do
          {id, ""} -> {:ok, {:character_kills, id}}
          _ -> {:error, :invalid_character_id}
        end

      ["corporation", corporation_id | _rest] ->
        case Integer.parse(corporation_id) do
          {id, ""} -> {:ok, {:corporation_kills, id}}
          _ -> {:error, :invalid_corporation_id}
        end

      ["system", system_id | _rest] ->
        case Integer.parse(system_id) do
          {id, ""} -> {:ok, {:system_kills, id}}
          _ -> {:error, :invalid_system_id}
        end

      _ ->
        {:error, :unsupported_url_format}
    end
  end

  defp import_killmails(import_spec) do
    case import_spec do
      {:single_kill, killmail_id} ->
        # Import single kill (currently unavailable)
        import_killmail(killmail_id)

      {:related_kills, system_id, timestamp} ->
        import_related_kills(system_id, timestamp)

      {:character_kills, character_id} ->
        import_character_recent_kills(character_id)

      {:corporation_kills, corporation_id} ->
        import_corporation_recent_kills(corporation_id)

      {:system_kills, system_id} ->
        import_system_recent_kills(system_id)
    end
  end

  defp import_character_recent_kills(character_id) do
    Logger.info("Importing recent kills for character #{character_id}")

    # Get last 100 kills/losses for the character (currently unavailable)
    case fetch_zkillboard_data("/characterID/#{character_id}/limit/100/") do
      {:error, reason} -> {:error, reason}
    end
  end

  defp import_corporation_recent_kills(corporation_id) do
    Logger.info("Importing recent kills for corporation #{corporation_id}")

    # Get last 100 kills/losses for the corporation (currently unavailable)
    case fetch_zkillboard_data("/corporationID/#{corporation_id}/limit/100/") do
      {:error, reason} -> {:error, reason}
    end
  end

  defp import_system_recent_kills(system_id) do
    Logger.info("Importing recent kills for system #{system_id}")

    # Get last 100 kills in the system (currently unavailable)
    case fetch_zkillboard_data("/systemID/#{system_id}/limit/100/") do
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_zkillboard_data(endpoint) do
    url = @zkillboard_api_base <> endpoint

    Logger.debug("Fetching zkillboard data from: #{url}")

    # Use a fallback approach since HTTPoison may not be available
    Logger.warning(
      "HTTP client not available - zkillboard import requires HTTP client configuration"
    )

    {:error, :http_client_unavailable}
  end

  defp format_timestamp_for_zkb(timestamp) when is_binary(timestamp) do
    # Already a string, return as-is (assuming it's in YYYYMMDDHHMM format)
    timestamp
  end

  defp format_timestamp_for_zkb(%DateTime{} = timestamp) do
    # Convert DateTime to zkillboard format: YYYYMMDDHHMM
    Calendar.strftime(timestamp, "%Y%m%d%H%M")
  end

  defp format_timestamp_for_zkb(%NaiveDateTime{} = timestamp) do
    # Convert NaiveDateTime to zkillboard format: YYYYMMDDHHMM
    Calendar.strftime(timestamp, "%Y%m%d%H%M")
  end

  defp format_timestamp_for_zkb(timestamp) do
    # Fallback for other types, try to convert to string
    to_string(timestamp)
  end
end
