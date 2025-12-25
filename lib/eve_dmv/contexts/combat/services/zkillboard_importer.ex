defmodule EveDmv.Contexts.Combat.Services.ZkillboardImporter do
  @moduledoc """
  Service for importing battle data from zkillboard.

  Handles:
  - Fetching killmails from zkillboard URLs
  - Importing related kills to reconstruct battles
  - Battle timeline reconstruction from zkillboard data
  - Handling zkillboard API rate limits
  """

  alias EveDmv.Contexts.BattleAnalysis.Core.BattleDetector
  alias EveDmv.Contexts.Combat.Services.BattleService
  alias EveDmv.Http.UnifiedClient
  alias EveDmv.Killmails.KillmailRaw

  require Logger

  @zkillboard_base_url "https://zkillboard.com/api"
  # 1 second between requests
  @rate_limit_delay 1000

  @doc """
  Import a battle from a zkillboard URL.

  Accepts URLs like:
  - https://zkillboard.com/kill/12345678/
  - https://zkillboard.com/related/30000142/202301011800/
  """
  def import_from_zkillboard(zkillboard_url) do
    with {:ok, import_type, params} <- parse_zkillboard_url(zkillboard_url),
         {:ok, killmail_data} <- fetch_zkillboard_data(import_type, params),
         {:ok, processed_killmails} <- process_zkillboard_response(killmail_data),
         {:ok, battle} <- create_battle_from_imports(processed_killmails) do
      Logger.info("Successfully imported battle #{battle.id} from zkillboard")
      {:ok, battle}
    else
      {:error, reason} = error ->
        Logger.error("Failed to import from zkillboard: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Import multiple kills by ID from zkillboard.
  """
  def import_kills(killmail_ids) when is_list(killmail_ids) do
    Logger.info("Importing #{length(killmail_ids)} kills from zkillboard")

    # Import kills with rate limiting
    results =
      killmail_ids
      |> Enum.with_index()
      |> Enum.map(fn {kill_id, index} ->
        # Rate limit except for first request
        if index > 0, do: Process.sleep(@rate_limit_delay)

        case fetch_single_kill(kill_id) do
          {:ok, kill_data} -> {:ok, kill_data}
          {:error, reason} -> {:error, {kill_id, reason}}
        end
      end)

    # Separate successes and failures
    {successes, failures} =
      Enum.split_with(results, fn
        {:ok, _} -> true
        {:error, _} -> false
      end)

    successful_kills = Enum.map(successes, fn {:ok, data} -> data end)
    failed_kills = Enum.map(failures, fn {:error, data} -> data end)

    if Enum.any?(failed_kills) do
      Logger.warning("Failed to import #{length(failed_kills)} kills: #{inspect(failed_kills)}")
    end

    {:ok,
     %{
       imported: successful_kills,
       failed: failed_kills,
       success_rate: length(successful_kills) / length(killmail_ids) * 100
     }}
  end

  @doc """
  Import related kills for a specific system and time.
  """
  def import_related(system_id, datetime) do
    with {:ok, formatted_time} <- format_zkillboard_time(datetime),
         {:ok, related_data} <- fetch_related_kills(system_id, formatted_time),
         {:ok, processed_killmails} <- process_zkillboard_response(related_data) do
      Logger.info("Imported #{length(processed_killmails)} related kills for system #{system_id}")
      {:ok, processed_killmails}
    end
  end

  @doc """
  Import kills for a specific battle report URL.
  """
  def import_battle_report(battle_report_url) do
    # Parse battle report URL and extract parameters
    with {:ok, params} <- parse_battle_report_url(battle_report_url),
         {:ok, killmails} <- fetch_related_kills(params),
         {:ok, battle} <- create_battle_from_imports(killmails) do
      {:ok, battle}
    end
  end

  @doc """
  Fetch and update existing battle with zkillboard data.
  """
  def enrich_battle_with_zkillboard(battle_id) do
    with {:ok, battle} <- BattleService.get_battle(battle_id),
         {:ok, zkb_data} <- fetch_zkillboard_battle_data(battle),
         {:ok, enriched_battle} <- enrich_battle_data(battle, zkb_data) do
      BattleService.update_battle(battle_id, enriched_battle)
    end
  end

  # Private Functions

  defp parse_zkillboard_url(url) do
    uri = URI.parse(url)
    path_parts = String.split(uri.path, "/", trim: true)

    case path_parts do
      ["kill", kill_id] ->
        {:ok, :single_kill, %{kill_id: kill_id}}

      ["related", system_id, timestamp] ->
        {:ok, :related, %{system_id: system_id, timestamp: timestamp}}

      ["br", battle_id | _] ->
        {:ok, :battle_report, %{battle_report_id: battle_id}}

      _ ->
        {:error, :invalid_zkillboard_url}
    end
  end

  defp fetch_zkillboard_data(:single_kill, %{kill_id: kill_id}) do
    fetch_single_kill(kill_id)
  end

  defp fetch_zkillboard_data(:related, %{system_id: system_id, timestamp: timestamp}) do
    fetch_related_kills(system_id, timestamp)
  end

  defp fetch_zkillboard_data(:battle_report, params) do
    fetch_related_kills(params)
  end

  defp fetch_single_kill(kill_id) do
    url = "#{@zkillboard_base_url}/killID/#{kill_id}/"

    case UnifiedClient.get(url, timeout: 10_000) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp fetch_related_kills(system_id, timestamp) do
    url = "#{@zkillboard_base_url}/related/#{system_id}/#{timestamp}/"

    case UnifiedClient.get(url, timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status: 404}} ->
        {:error, :no_related_kills_found}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp format_zkillboard_time(datetime) do
    # zkillboard expects format: YYYYMMDDHHMM
    formatted =
      datetime
      |> DateTime.truncate(:second)
      |> Calendar.strftime("%Y%m%d%H%M")

    {:ok, formatted}
  rescue
    _ -> {:error, :invalid_datetime}
  end

  defp process_zkillboard_response(zkb_data) when is_list(zkb_data) do
    processed =
      zkb_data
      |> Enum.map(&transform_zkillboard_kill/1)
      |> Enum.reject(&is_nil/1)

    {:ok, processed}
  end

  defp process_zkillboard_response(zkb_data) when is_map(zkb_data) do
    # Handle single kill response
    process_zkillboard_response([zkb_data])
  end

  defp transform_zkillboard_kill(zkb_kill) do
    victim = zkb_kill["victim"] || %{}

    %{
      killmail_id: zkb_kill["killmail_id"],
      killmail_hash: zkb_kill["killmail_hash"] || generate_killmail_hash(zkb_kill),
      killmail_time: parse_killmail_time(zkb_kill["killmail_time"]),
      solar_system_id: zkb_kill["solar_system_id"],
      victim_character_id: victim["character_id"],
      victim_corporation_id: victim["corporation_id"],
      victim_alliance_id: victim["alliance_id"],
      victim_ship_type_id: victim["ship_type_id"],
      attacker_count: length(zkb_kill["attackers"] || []),
      raw_data: zkb_kill,
      source: "zkillboard"
    }
  rescue
    e ->
      Logger.error("Failed to transform zkillboard kill: #{inspect(e)}")
      nil
  end

  defp parse_killmail_time(time_string) when is_binary(time_string) do
    case DateTime.from_iso8601(time_string <> "Z") do
      {:ok, datetime, _offset} -> datetime
      _ -> DateTime.utc_now()
    end
  end

  defp parse_killmail_time(_), do: DateTime.utc_now()

  defp generate_killmail_hash(zkb_kill) do
    # Generate a hash from killmail_id and time
    killmail_id = to_string(zkb_kill["killmail_id"] || 0)
    time_string = to_string(zkb_kill["killmail_time"] || "")

    :crypto.hash(:sha256, killmail_id <> time_string)
    |> Base.encode16(case: :lower)
    |> String.slice(0..39)
  end

  defp create_battle_from_imports(killmails) do
    # Save killmails to database first
    saved_killmails = Enum.map(killmails, &save_or_update_killmail/1)

    # Detect battles
    case BattleDetector.detect_battles(saved_killmails) do
      {:ok, [battle | _]} ->
        # Create battle record
        BattleService.create_battle(battle)

      {:ok, []} ->
        {:error, :no_battle_detected}

      error ->
        error
    end
  end

  defp save_or_update_killmail(killmail_data) do
    # Use Ash API to create the killmail
    case Ash.create(KillmailRaw, killmail_data, action: :ingest_from_source, domain: EveDmv.Api) do
      {:ok, killmail} ->
        killmail

      {:error, error} ->
        Logger.error("Failed to save killmail: #{inspect(error)}")
        nil
    end
  end

  defp parse_battle_report_url(url) do
    # Extract battle report ID from URL
    case Regex.run(~r/br\/(\d+)/, url) do
      [_, br_id] -> {:ok, %{battle_report_id: br_id}}
      _ -> {:error, :invalid_battle_report_url}
    end
  end

  defp fetch_related_kills(%{battle_report_id: br_id}) do
    # Battle reports require fetching from zkillboard's BR API
    url = "#{@zkillboard_base_url}/br/#{br_id}/"

    case UnifiedClient.get(url, timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        data = Jason.decode!(body)
        process_battle_report_data(data)

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp process_battle_report_data(br_data) do
    # Extract killmail IDs from battle report
    kill_ids = extract_kill_ids_from_br(br_data)

    # Fetch each kill
    import_kills(kill_ids)
  end

  defp extract_kill_ids_from_br(br_data) do
    # Battle report structure varies, extract all killmail IDs
    br_data
    |> find_all_kill_ids([])
    |> Enum.uniq()
  end

  defp find_all_kill_ids(data, acc) when is_map(data) do
    kill_id = if data["killmail_id"], do: [data["killmail_id"]], else: []

    data
    |> Map.values()
    |> Enum.reduce(acc ++ kill_id, &find_all_kill_ids/2)
  end

  defp find_all_kill_ids(data, acc) when is_list(data) do
    Enum.reduce(data, acc, &find_all_kill_ids/2)
  end

  defp find_all_kill_ids(_, acc), do: acc

  defp fetch_zkillboard_battle_data(battle) do
    # Fetch additional data for battle's system and time
    case import_related(battle.system_id, battle.start_time) do
      {:ok, killmails} ->
        {:ok,
         %{
           additional_kills: length(killmails),
           zkb_stats: calculate_zkb_stats(killmails)
         }}

      error ->
        error
    end
  end

  defp calculate_zkb_stats(killmails) do
    %{
      total_value:
        Enum.reduce(killmails, 0, fn km, acc ->
          # Access zkb data from raw_data map
          zkb_data = get_in(km.raw_data, ["zkb"]) || %{}
          acc + (zkb_data["totalValue"] || 0)
        end),
      points:
        Enum.reduce(killmails, 0, fn km, acc ->
          zkb_data = get_in(km.raw_data, ["zkb"]) || %{}
          acc + (zkb_data["points"] || 0)
        end),
      npc_kills:
        Enum.count(killmails, fn km ->
          zkb_data = get_in(km.raw_data, ["zkb"]) || %{}
          zkb_data["npc"] == true
        end),
      solo_kills:
        Enum.count(killmails, fn km ->
          zkb_data = get_in(km.raw_data, ["zkb"]) || %{}
          zkb_data["solo"] == true
        end),
      awox_kills:
        Enum.count(killmails, fn km ->
          zkb_data = get_in(km.raw_data, ["zkb"]) || %{}
          zkb_data["awox"] == true
        end)
    }
  end

  defp enrich_battle_data(_battle, zkb_data) do
    {:ok,
     %{
       zkillboard_metadata: zkb_data,
       enriched_at: DateTime.utc_now(),
       tags: extract_battle_tags(zkb_data)
     }}
  end

  defp extract_battle_tags(zkb_data) do
    tags = []

    npc_tags =
      if zkb_data.zkb_stats.npc_kills > 0 do
        ["has_npc_kills" | tags]
      else
        tags
      end

    solo_tags =
      if zkb_data.zkb_stats.solo_kills > 0 do
        ["has_solo_kills" | npc_tags]
      else
        npc_tags
      end

    awox_tags =
      if zkb_data.zkb_stats.awox_kills > 0 do
        ["has_awox" | solo_tags]
      else
        solo_tags
      end

    value_tags =
      if zkb_data.zkb_stats.total_value > 10_000_000_000 do
        ["high_value_battle" | awox_tags]
      else
        awox_tags
      end

    Enum.uniq(value_tags)
  end

  @doc """
  Import historical battles for a specific entity.
  """
  def import_entity_history(entity_type, entity_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    page = Keyword.get(opts, :page, 1)

    url = build_entity_url(entity_type, entity_id, limit, page)

    case UnifiedClient.get(url, timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        kills = Jason.decode!(body)
        process_historical_kills(kills)

      error ->
        {:error, {:fetch_failed, error}}
    end
  end

  defp build_entity_url(entity_type, entity_id, limit, page) do
    base = @zkillboard_base_url

    case entity_type do
      :character -> "#{base}/characterID/#{entity_id}/limit/#{limit}/page/#{page}/"
      :corporation -> "#{base}/corporationID/#{entity_id}/limit/#{limit}/page/#{page}/"
      :alliance -> "#{base}/allianceID/#{entity_id}/limit/#{limit}/page/#{page}/"
      :ship -> "#{base}/shipTypeID/#{entity_id}/limit/#{limit}/page/#{page}/"
      :system -> "#{base}/solarSystemID/#{entity_id}/limit/#{limit}/page/#{page}/"
      _ -> {:error, :invalid_entity_type}
    end
  end

  defp process_historical_kills(kills) do
    # Group kills by proximity to detect battles
    processed =
      Enum.map(kills, &transform_zkillboard_kill/1)
      |> Enum.reject(&is_nil/1)

    # Save kills
    saved = Enum.map(processed, &save_or_update_killmail/1)

    # Detect battles in the historical data
    case BattleDetector.detect_battles(saved) do
      {:ok, battles} ->
        # Create battle records for each detected battle
        created_battles =
          Enum.map(battles, fn battle_data ->
            case BattleService.create_battle(battle_data) do
              {:ok, battle} -> battle
              _ -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        {:ok,
         %{
           kills_imported: length(saved),
           battles_detected: length(created_battles)
         }}

      _error ->
        {:ok, %{kills_imported: length(saved), battles_detected: 0}}
    end
  end
end
