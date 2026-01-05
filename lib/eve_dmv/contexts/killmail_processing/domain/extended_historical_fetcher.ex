defmodule EveDmv.Contexts.KillmailProcessing.Domain.ExtendedHistoricalFetcher do
  @moduledoc """
  Fetches historical killmail data beyond the 90-day window.

  Uses zkillboard API to fetch up to 2 years of historical data.
  Implements rate limiting and pagination to respect API limits.

  ## Configuration

  The following configuration options can be set via environment variables:
  - `HISTORICAL_FETCH_RATE_LIMIT` - Delay between requests (ms, default: 1000)
  - `HISTORICAL_FETCH_MAX_PAGES` - Maximum pages to fetch (default: 100)
  - `HISTORICAL_FETCH_LOOKBACK_DAYS` - Days of history to fetch (default: 730)

  ## Usage

      # Fetch extended history for a character
      {:ok, result} = ExtendedHistoricalFetcher.fetch_extended_history(
        :character,
        12345,
        callback: fn {:progress, progress} -> IO.inspect(progress) end
      )
  """

  alias EveDmv.Http.UnifiedClient
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Killmails.Participant

  require Logger

  # zkillboard API base URL
  @zkillboard_base_url "https://zkillboard.com/api"

  # Rate limiting - 1 second between requests (zkillboard rate limit)
  @default_rate_limit_delay 1_000

  # zkillboard returns max 200 kills per page
  @kills_per_page 200

  # Safety limit: 100 pages * 200 kills = 20,000 kills max
  @default_max_pages 100

  # 2 years in days
  @default_lookback_days 730

  @type entity_type :: :character | :corporation | :system | :alliance
  @type fetch_result :: {:ok, map()} | {:error, term()}
  @type progress_callback :: (tuple() -> any()) | nil

  # Fetch context to reduce parameter count in recursive function
  @typep fetch_context :: %{
           entity_type: entity_type(),
           entity_id: integer(),
           cutoff_date: Date.t(),
           start_date: Date.t(),
           callback: progress_callback()
         }

  @doc """
  Fetch extended historical data for an entity.

  This is the main entry point for Phase 2 fetching.
  Fetches from zkillboard API starting from where Phase 1 left off.

  ## Arguments
  - `entity_type` - Type of entity: `:character`, `:corporation`, `:system`, or `:alliance`
  - `entity_id` - The EVE Online ID of the entity
  - `opts` - Keyword list of options

  ## Options
  - `:start_page` - Page to start from (default: 1)
  - `:start_date` - Only fetch kills older than this date (default: 90 days ago)
  - `:callback` - Function to call with progress updates, receives `{:progress, map()}`

  ## Returns
  - `{:ok, %{killmails_fetched: count, pages_processed: count, oldest_date: date}}`
  - `{:error, reason}`

  ## Examples

      iex> fetch_extended_history(:character, 12345)
      {:ok, %{killmails_fetched: 150, pages_processed: 1, oldest_date: ~D[2024-06-15]}}

      iex> fetch_extended_history(:corporation, 98000001, callback: &handle_progress/1)
      {:ok, %{killmails_fetched: 2500, pages_processed: 13, oldest_date: ~D[2023-01-15]}}
  """
  @spec fetch_extended_history(entity_type(), integer(), keyword()) :: fetch_result()
  def fetch_extended_history(entity_type, entity_id, opts \\ [])
      when entity_type in [:character, :corporation, :system, :alliance] and is_integer(entity_id) do
    start_page = Keyword.get(opts, :start_page, 1)
    lookback_days = get_config(:lookback_days, @default_lookback_days)
    cutoff_date = Date.add(Date.utc_today(), -lookback_days)
    start_date = Keyword.get(opts, :start_date, Date.add(Date.utc_today(), -90))
    callback = Keyword.get(opts, :callback)

    Logger.info(
      "Starting extended historical fetch for #{entity_type} #{entity_id} " <>
        "from page #{start_page}, targeting #{cutoff_date}"
    )

    ctx = %{
      entity_type: entity_type,
      entity_id: entity_id,
      cutoff_date: cutoff_date,
      start_date: start_date,
      callback: callback
    }

    fetch_pages(ctx, start_page, %{killmails_fetched: 0, pages_processed: 0, oldest_date: nil})
  end

  @doc """
  Get the current configuration for the fetcher.

  Returns a map with all configuration values.
  """
  @spec get_config() :: map()
  def get_config do
    %{
      rate_limit_delay: get_config(:rate_limit_delay, @default_rate_limit_delay),
      max_pages: get_config(:max_pages, @default_max_pages),
      lookback_days: get_config(:lookback_days, @default_lookback_days),
      zkillboard_base_url: @zkillboard_base_url,
      kills_per_page: @kills_per_page
    }
  end

  # Recursive page fetching with rate limiting
  @spec fetch_pages(fetch_context(), integer(), map()) :: fetch_result()
  defp fetch_pages(ctx, page, acc) do
    %{
      entity_type: entity_type,
      entity_id: entity_id,
      cutoff_date: cutoff_date,
      start_date: start_date,
      callback: callback
    } = ctx

    max_pages = get_config(:max_pages, @default_max_pages)

    if page > max_pages do
      Logger.warning("Reached max pages limit (#{max_pages}) for #{entity_type} #{entity_id}")
      {:ok, acc}
    else
      # Rate limit - delay before fetching (skip delay for first page)
      if page > 1 do
        rate_limit_delay = get_config(:rate_limit_delay, @default_rate_limit_delay)
        Process.sleep(rate_limit_delay)
      end

      case fetch_page(entity_type, entity_id, page) do
        {:ok, []} ->
          # No more kills
          Logger.info("No more kills found at page #{page} for #{entity_type} #{entity_id}")
          {:ok, acc}

        {:ok, kills} ->
          # Filter and process kills
          {relevant_kills, oldest_date, reached_cutoff} =
            process_kills(kills, cutoff_date, start_date)

          # Store kills
          stored_count = store_kills(relevant_kills)

          new_acc = %{
            acc
            | killmails_fetched: acc.killmails_fetched + stored_count,
              pages_processed: acc.pages_processed + 1,
              oldest_date: oldest_date || acc.oldest_date
          }

          # Report progress
          if callback, do: callback.({:progress, new_acc})

          if reached_cutoff do
            Logger.info("Reached cutoff date #{cutoff_date} for #{entity_type} #{entity_id}")

            {:ok, new_acc}
          else
            # Continue to next page
            fetch_pages(ctx, page + 1, new_acc)
          end

        {:error, :rate_limited} ->
          # Back off and retry
          Logger.warning("Rate limited, backing off for 60 seconds")
          Process.sleep(60_000)
          fetch_pages(ctx, page, acc)

        {:error, reason} = error ->
          Logger.error("Failed to fetch page #{page}: #{inspect(reason)}")
          error
      end
    end
  end

  @spec fetch_page(entity_type(), integer(), integer()) :: {:ok, list()} | {:error, term()}
  defp fetch_page(entity_type, entity_id, page) do
    url = build_url(entity_type, entity_id, page)

    case UnifiedClient.get(url, timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        decode_response(body)

      {:ok, %{body: body}} when is_list(body) ->
        {:ok, body}

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: 404}} ->
        {:ok, []}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, {:http_error, 429, _}} ->
        {:error, :rate_limited}

      {:error, {:http_error, 404, _}} ->
        {:ok, []}

      {:error, {:http_error, status, _body}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @spec decode_response(term()) :: {:ok, list()} | {:error, :invalid_json}
  defp decode_response(body) when is_list(body), do: {:ok, body}
  defp decode_response(body) when is_map(body), do: {:ok, []}

  defp decode_response(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, kills} when is_list(kills) -> {:ok, kills}
      {:ok, _} -> {:ok, []}
      {:error, _} -> {:error, :invalid_json}
    end
  end

  defp decode_response(_), do: {:ok, []}

  @spec build_url(entity_type(), integer(), integer()) :: String.t()
  defp build_url(:character, id, page) do
    "#{@zkillboard_base_url}/characterID/#{id}/page/#{page}/"
  end

  defp build_url(:corporation, id, page) do
    "#{@zkillboard_base_url}/corporationID/#{id}/page/#{page}/"
  end

  defp build_url(:alliance, id, page) do
    "#{@zkillboard_base_url}/allianceID/#{id}/page/#{page}/"
  end

  defp build_url(:system, id, page) do
    "#{@zkillboard_base_url}/solarSystemID/#{id}/page/#{page}/"
  end

  @spec process_kills(list(), Date.t(), Date.t()) :: {list(), Date.t() | nil, boolean()}
  defp process_kills(kills, cutoff_date, start_date) do
    # Parse kills with their dates
    kills_with_dates =
      kills
      |> Enum.map(fn kill ->
        kill_date = parse_kill_date(kill["killmail_time"])
        {kill, kill_date}
      end)

    # Filter to only include kills older than start_date (Phase 1 boundary)
    # and stop when we reach the cutoff
    relevant_kills =
      kills_with_dates
      |> Enum.filter(fn {_kill, kill_date} ->
        Date.compare(kill_date, start_date) == :lt
      end)
      |> Enum.take_while(fn {_kill, kill_date} ->
        Date.compare(kill_date, cutoff_date) != :lt
      end)

    # Find the oldest date among relevant kills
    oldest =
      relevant_kills
      |> Enum.map(fn {_kill, date} -> date end)
      |> Enum.min(Date, fn -> nil end)

    # Check if any kill in the page is older than cutoff
    reached_cutoff =
      Enum.any?(kills_with_dates, fn {_kill, kill_date} ->
        Date.compare(kill_date, cutoff_date) == :lt
      end)

    {Enum.map(relevant_kills, fn {kill, _} -> kill end), oldest, reached_cutoff}
  end

  @spec parse_kill_date(term()) :: Date.t()
  defp parse_kill_date(nil), do: Date.utc_today()

  defp parse_kill_date(time_string) when is_binary(time_string) do
    # zkillboard format: "2024-01-15T12:34:56Z" or "2024-01-15 12:34:56"
    normalized =
      time_string
      |> String.replace(" ", "T")
      |> ensure_timezone()

    case DateTime.from_iso8601(normalized) do
      {:ok, datetime, _} -> DateTime.to_date(datetime)
      _ -> Date.utc_today()
    end
  rescue
    _ -> Date.utc_today()
  end

  defp parse_kill_date(_), do: Date.utc_today()

  @spec ensure_timezone(String.t()) :: String.t()
  defp ensure_timezone(time_string) do
    if String.ends_with?(time_string, "Z") do
      time_string
    else
      time_string <> "Z"
    end
  end

  @spec store_kills(list()) :: non_neg_integer()
  defp store_kills(kills) do
    kills
    |> Enum.map(&transform_zkb_kill/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&store_single_kill/1)
    |> Enum.count(&(&1 == :ok))
  end

  @spec transform_zkb_kill(map()) :: map() | nil
  defp transform_zkb_kill(zkb_kill) do
    victim = zkb_kill["victim"] || %{}
    zkb = zkb_kill["zkb"] || %{}

    %{
      killmail_id: zkb_kill["killmail_id"],
      killmail_hash: zkb_kill["killmail_hash"] || zkb["hash"],
      killmail_time: parse_killmail_time(zkb_kill["killmail_time"]),
      solar_system_id: zkb_kill["solar_system_id"],
      victim_character_id: victim["character_id"],
      victim_corporation_id: victim["corporation_id"],
      victim_alliance_id: victim["alliance_id"],
      victim_ship_type_id: victim["ship_type_id"],
      attacker_count: length(zkb_kill["attackers"] || []),
      total_value: parse_total_value(zkb["totalValue"]),
      raw_data: zkb_kill,
      source: "zkillboard-extended"
    }
  rescue
    error ->
      Logger.debug("Failed to transform kill: #{inspect(error)}")
      nil
  end

  @spec parse_total_value(term()) :: Decimal.t()
  defp parse_total_value(nil), do: Decimal.new("0")
  defp parse_total_value(value) when is_number(value), do: Decimal.new(to_string(value))
  defp parse_total_value(value) when is_binary(value), do: Decimal.new(value)
  defp parse_total_value(_), do: Decimal.new("0")

  @spec parse_killmail_time(term()) :: DateTime.t()
  defp parse_killmail_time(nil), do: DateTime.utc_now()

  defp parse_killmail_time(time_string) when is_binary(time_string) do
    normalized =
      time_string
      |> String.replace(" ", "T")
      |> ensure_timezone()

    case DateTime.from_iso8601(normalized) do
      {:ok, datetime, _} -> datetime
      _ -> DateTime.utc_now()
    end
  end

  defp parse_killmail_time(_), do: DateTime.utc_now()

  @spec store_single_kill(map()) :: :ok | :error
  defp store_single_kill(killmail_data) do
    case Ash.create(
           KillmailRaw,
           killmail_data,
           action: :ingest_from_source,
           domain: EveDmv.Api
         ) do
      {:ok, _killmail} ->
        # Also create participants
        store_participants(killmail_data.raw_data)
        :ok

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        # Check if it's a uniqueness error (already exists)
        if Enum.any?(errors, &uniqueness_error?/1) do
          # Already exists, that's fine
          :ok
        else
          Logger.debug("Failed to store killmail: #{inspect(errors)}")
          :error
        end

      {:error, reason} ->
        Logger.debug("Failed to store killmail: #{inspect(reason)}")
        :error
    end
  rescue
    error ->
      Logger.debug("Error storing killmail: #{inspect(error)}")
      # Ignore errors for robustness
      :ok
  end

  @spec uniqueness_error?(term()) :: boolean()
  defp uniqueness_error?(%{class: :uniqueness}), do: true

  defp uniqueness_error?(%Ash.Error.Changes.InvalidChanges{message: msg}),
    do: String.contains?(msg || "", "unique")

  defp uniqueness_error?(_), do: false

  @spec store_participants(map()) :: :ok
  defp store_participants(raw_data) do
    victim = raw_data["victim"] || %{}
    attackers = raw_data["attackers"] || []
    killmail_time = parse_killmail_time(raw_data["killmail_time"])
    solar_system_id = raw_data["solar_system_id"]
    killmail_id = raw_data["killmail_id"]

    participants = []

    # Add victim
    participants =
      if victim["ship_type_id"] do
        [
          build_participant(victim, killmail_id, killmail_time, solar_system_id, true, false)
          | participants
        ]
      else
        participants
      end

    # Add attackers
    participants =
      attackers
      |> Enum.filter(& &1["ship_type_id"])
      |> Enum.map(
        &build_participant(
          &1,
          killmail_id,
          killmail_time,
          solar_system_id,
          false,
          &1["final_blow"] || false
        )
      )
      |> Kernel.++(participants)

    # Bulk insert participants
    if Enum.any?(participants) do
      Ash.bulk_create(participants, Participant, :create,
        domain: EveDmv.Api,
        return_records?: false,
        return_errors?: false,
        stop_on_error?: false,
        batch_size: 500
      )
    end

    :ok
  rescue
    _ -> :ok
  end

  @spec build_participant(map(), integer(), DateTime.t(), integer(), boolean(), boolean()) ::
          map()
  defp build_participant(
         entity,
         killmail_id,
         killmail_time,
         solar_system_id,
         is_victim,
         final_blow
       ) do
    %{
      killmail_id: killmail_id,
      killmail_time: killmail_time,
      character_id: entity["character_id"],
      character_name: entity["character_name"],
      corporation_id: entity["corporation_id"],
      corporation_name: entity["corporation_name"],
      alliance_id: entity["alliance_id"],
      alliance_name: entity["alliance_name"],
      faction_id: entity["faction_id"],
      faction_name: entity["faction_name"],
      ship_type_id: entity["ship_type_id"],
      ship_name: entity["ship_name"],
      weapon_type_id: entity["weapon_type_id"],
      weapon_name: entity["weapon_name"],
      damage_done: entity["damage_done"] || 0,
      security_status: parse_security_status(entity["security_status"]),
      is_victim: is_victim,
      final_blow: final_blow,
      is_npc: npc?(entity),
      solar_system_id: solar_system_id
    }
  end

  @spec parse_security_status(term()) :: Decimal.t() | nil
  defp parse_security_status(nil), do: nil
  defp parse_security_status(value) when is_number(value), do: Decimal.new(to_string(value))
  defp parse_security_status(value) when is_binary(value), do: Decimal.new(value)
  defp parse_security_status(_), do: nil

  @spec npc?(map()) :: boolean()
  defp npc?(entity) do
    # NPCs don't have character_id but may have faction_id
    is_nil(entity["character_id"]) && !is_nil(entity["faction_id"])
  end

  @spec get_config(atom(), term()) :: term()
  defp get_config(key, default) do
    config = Application.get_env(:eve_dmv, __MODULE__, [])
    Keyword.get(config, key, default)
  end
end
