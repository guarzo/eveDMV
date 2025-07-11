defmodule EveDmv.Contexts.BattleAnalysis.Domain.ZkillboardImportService do
  @moduledoc """
  Service for importing killmail data from zkillboard.

  Supports importing individual killmails, related kills, and battle reports
  by parsing zkillboard URLs and fetching data from their API.
  """

  require Logger
  require Ash.Query
  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw

  @zkillboard_api_base "https://zkillboard.com/api"
  @esi_base "https://esi.evetech.net/latest"

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

    with {:ok, zkb_data} <- fetch_zkillboard_data("/kills/killID/#{killmail_id}/"),
         {:ok, killmail_data} <- process_zkillboard_response(zkb_data),
         {:ok, imported_ids} <- store_killmails(killmail_data) do
      {:ok, imported_ids}
    end
  end

  @doc """
  Fetches related kills for a specific system and time.
  """
  def import_related_kills(system_id, timestamp) do
    Logger.info("Importing related kills for system #{system_id} at #{timestamp}")

    # Format timestamp for zkillboard (YYYYMMDDHHMM)
    formatted_time = format_timestamp_for_zkb(timestamp)

    with {:ok, zkb_data} <- fetch_zkillboard_data("/related/#{system_id}/#{formatted_time}/"),
         {:ok, killmail_data} <- process_zkillboard_response(zkb_data),
         {:ok, imported_ids} <- store_killmails(killmail_data) do
      {:ok, imported_ids}
    end
  end

  # Private functions

  defp parse_zkillboard_url(url) do
    uri = URI.parse(url)

    cond do
      uri.host != "zkillboard.com" ->
        {:error, :invalid_zkillboard_url}

      true ->
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
        # First import the single kill, then try to get related kills
        with {:ok, imported_ids} <- import_killmail(killmail_id),
             single_id <- List.first(imported_ids),
             {:ok, killmail} <- get_killmail_details(single_id) do
          # Try to import related kills from the same battle
          import_related_from_killmail(killmail)
        else
          error -> 
            Logger.warning("Failed to import related kills: #{inspect(error)}")
            # Fallback to just the single kill import
            import_killmail(killmail_id)
        end

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

    # Get last 100 kills/losses for the character
    with {:ok, zkb_data} <- fetch_zkillboard_data("/characterID/#{character_id}/limit/100/"),
         {:ok, killmail_data} <- process_zkillboard_response(zkb_data),
         {:ok, imported_ids} <- store_killmails(killmail_data) do
      {:ok, imported_ids}
    end
  end

  defp import_corporation_recent_kills(corporation_id) do
    Logger.info("Importing recent kills for corporation #{corporation_id}")

    # Get last 100 kills/losses for the corporation
    with {:ok, zkb_data} <- fetch_zkillboard_data("/corporationID/#{corporation_id}/limit/100/"),
         {:ok, killmail_data} <- process_zkillboard_response(zkb_data),
         {:ok, imported_ids} <- store_killmails(killmail_data) do
      {:ok, imported_ids}
    end
  end

  defp import_system_recent_kills(system_id) do
    Logger.info("Importing recent kills for system #{system_id}")

    # Get last 100 kills in the system
    with {:ok, zkb_data} <- fetch_zkillboard_data("/systemID/#{system_id}/limit/100/"),
         {:ok, killmail_data} <- process_zkillboard_response(zkb_data),
         {:ok, imported_ids} <- store_killmails(killmail_data) do
      {:ok, imported_ids}
    end
  end

  defp fetch_zkillboard_data(endpoint) do
    url = @zkillboard_api_base <> endpoint

    Logger.debug("Fetching zkillboard data from: #{url}")

    headers = [
      {"User-Agent", "EVE DMV Battle Analysis"},
      {"Accept", "application/json"}
    ]

    case HTTPoison.get(url, headers, recv_timeout: 30_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, data} -> {:ok, data}
          {:error, _} -> {:error, :invalid_json_response}
        end

      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.error("Zkillboard API returned status #{status}")
        {:error, {:api_error, status}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Failed to fetch zkillboard data: #{inspect(reason)}")
        {:error, {:http_error, reason}}
    end
  end

  defp process_zkillboard_response(zkb_data) when is_list(zkb_data) do
    # zkillboard returns an array of killmail objects
    killmails =
      zkb_data
      |> Enum.map(&extract_killmail_info/1)
      |> Enum.filter(&(&1 != nil))

    {:ok, killmails}
  end

  defp process_zkillboard_response(_), do: {:error, :unexpected_response_format}

  defp extract_killmail_info(zkb_kill) do
    killmail_id = zkb_kill["killmail_id"]
    hash = zkb_kill["zkb"]["hash"]

    if killmail_id && hash do
      %{
        killmail_id: killmail_id,
        hash: hash,
        zkb_data: zkb_kill["zkb"]
      }
    else
      nil
    end
  end

  defp store_killmails(killmail_infos) do
    # Fetch full killmail data from ESI and store
    {existing_ids, new_ids} =
      killmail_infos
      |> Enum.map(&fetch_and_store_killmail/1)
      |> Enum.split_with(fn
        {:existing, _id} -> true
        _ -> false
      end)

    existing_count = length(existing_ids)
    new_count = length(Enum.filter(new_ids, &(&1 != nil)))

    all_ids =
      (Enum.map(existing_ids, fn {:existing, id} -> id end) ++
         Enum.filter(new_ids, &(&1 != nil)))
      |> Enum.uniq()

    Logger.info("Found #{existing_count} existing killmails, imported #{new_count} new killmails")
    {:ok, all_ids}
  end

  defp fetch_and_store_killmail(%{killmail_id: killmail_id, hash: hash} = info) do
    # Check if we already have this killmail
    case check_existing_killmail(killmail_id) do
      true ->
        Logger.debug("Killmail #{killmail_id} already exists, skipping")
        {:existing, killmail_id}

      false ->
        # Fetch from ESI
        case fetch_killmail_from_esi(killmail_id, hash) do
          {:ok, esi_data} ->
            store_killmail_data(killmail_id, hash, esi_data, info.zkb_data)

          {:error, reason} ->
            Logger.error("Failed to fetch killmail #{killmail_id} from ESI: #{inspect(reason)}")
            nil
        end
    end
  end

  defp check_existing_killmail(killmail_id) do
    # Check if killmail already exists in our database
    # Use raw SQL for more efficient check
    query = """
      SELECT EXISTS(
        SELECT 1 FROM killmails_raw 
        WHERE killmail_id = $1
        LIMIT 1
      )
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query, [killmail_id]) do
      {:ok, %{rows: [[exists]]}} ->
        exists

      _ ->
        false
    end
  end

  defp fetch_killmail_from_esi(killmail_id, hash) do
    url = "#{@esi_base}/killmails/#{killmail_id}/#{hash}/"

    Logger.debug("Fetching killmail from ESI: #{url}")

    headers = [
      {"User-Agent", "EVE DMV Battle Analysis"},
      {"Accept", "application/json"}
    ]

    case HTTPoison.get(url, headers, recv_timeout: 10_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode(body)

      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, {:esi_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp store_killmail_data(killmail_id, hash, esi_data, zkb_data) do
    # Extract required fields from ESI data
    killmail_time = parse_datetime(esi_data["killmail_time"])

    killmail_attrs = %{
      killmail_id: killmail_id,
      killmail_time: killmail_time,
      killmail_hash: hash,
      solar_system_id: esi_data["solar_system_id"],
      victim_character_id: get_in(esi_data, ["victim", "character_id"]),
      victim_corporation_id: get_in(esi_data, ["victim", "corporation_id"]),
      victim_alliance_id: get_in(esi_data, ["victim", "alliance_id"]),
      victim_ship_type_id: get_in(esi_data, ["victim", "ship_type_id"]),
      attacker_count: length(esi_data["attackers"] || []),
      raw_data: Map.merge(esi_data, %{"zkb" => zkb_data}),
      source: "zkillboard_import"
    }

    case Ash.create(KillmailRaw, killmail_attrs, domain: Api) do
      {:ok, _killmail} ->
        Logger.info("Stored killmail #{killmail_id}")
        killmail_id

      {:error, error} ->
        Logger.error("Failed to store killmail #{killmail_id}: #{inspect(error)}")
        nil
    end
  end

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case NaiveDateTime.from_iso8601(datetime_string) do
      {:ok, datetime} -> datetime
      _ -> NaiveDateTime.utc_now()
    end
  end

  defp parse_datetime(_), do: NaiveDateTime.utc_now()

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
  
  defp get_killmail_details(killmail_id) do
    # Fetch the killmail from our database to get system and time info
    case KillmailRaw
         |> Ash.Query.filter(killmail_id: killmail_id)
         |> Ash.read_one(domain: Api) do
      {:ok, killmail} when killmail != nil ->
        {:ok, killmail}
      _ ->
        {:error, :killmail_not_found}
    end
  end
  
  defp import_related_from_killmail(killmail) do
    Logger.info("Fetching related kills for killmail #{killmail.killmail_id} in system #{killmail.solar_system_id}")
    
    # Round the time to nearest 5 minutes for better matching
    rounded_time = round_to_nearest_5_minutes(killmail.killmail_time)
    
    # Import related kills
    case import_related_kills(killmail.solar_system_id, rounded_time) do
      {:ok, imported_ids} ->
        # Make sure our original kill is included
        all_ids = Enum.uniq([killmail.killmail_id | imported_ids])
        Logger.info("Imported #{length(all_ids)} total kills (including related)")
        {:ok, all_ids}
      
      error ->
        # If related fails, at least return the original
        Logger.warning("Failed to fetch related kills: #{inspect(error)}")
        {:ok, [killmail.killmail_id]}
    end
  end
  
  defp round_to_nearest_5_minutes(datetime) do
    # Round to nearest 5-minute interval for better zkillboard matching
    # This helps match kills that happened in the same battle window
    {:ok, dt} = NaiveDateTime.new(
      datetime.year,
      datetime.month,
      datetime.day,
      datetime.hour,
      div(datetime.minute, 5) * 5,
      0
    )
    dt
  end
end
