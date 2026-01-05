# Historical Killmail 2-Year Fetch Implementation Plan

## Overview

Expand the historical killmail retrieval system to fetch 2 years of data for all profile types (character, corporation, system, alliance). Implementation uses a two-phase approach:
1. **Phase 1 (Immediate)**: Fetch 90 days of data synchronously (current behavior)
2. **Phase 2 (Background)**: Fetch remaining data up to 2 years asynchronously

A discrete UI indicator shows the progress/completion status of the 2-year fetch.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Database Schema](#database-schema)
3. [Backend Implementation](#backend-implementation)
4. [Frontend Implementation](#frontend-implementation)
5. [Testing Strategy](#testing-strategy)
6. [Configuration](#configuration)
7. [File-by-File Implementation Guide](#file-by-file-implementation-guide)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Profile Page Visit                                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Check HistoricalFetchStatus Table                         │
│                                                                              │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐         │
│  │ Not Started     │    │ In Progress     │    │ Completed       │         │
│  │ (no record)     │    │                 │    │                 │         │
│  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘         │
│           │                      │                      │                   │
│           ▼                      ▼                      ▼                   │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐         │
│  │ Start Phase 1   │    │ Show Progress   │    │ Show Completed  │         │
│  │ (90 days sync)  │    │ Indicator       │    │ Indicator       │         │
│  └────────┬────────┘    └─────────────────┘    └─────────────────┘         │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────┐                                                        │
│  │ Start Phase 2   │                                                        │
│  │ (2yr async)     │◄──────── Background GenServer Worker                   │
│  └─────────────────┘                                                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Components

1. **HistoricalFetchStatus** - Ash Resource tracking fetch status per entity
2. **HistoricalFetchWorker** - GenServer managing background fetch queue
3. **ExtendedHistoricalFetcher** - Service that fetches beyond 90 days using zkillboard API
4. **HistoricalFetchIndicator** - LiveView component showing status

---

## Database Schema

### New Table: `historical_fetch_status`

```sql
CREATE TABLE historical_fetch_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Entity identification (polymorphic)
  entity_type VARCHAR(20) NOT NULL,  -- 'character', 'corporation', 'system', 'alliance'
  entity_id BIGINT NOT NULL,

  -- Fetch status
  status VARCHAR(20) NOT NULL DEFAULT 'pending',  -- 'pending', 'phase1_complete', 'in_progress', 'completed', 'failed'

  -- Progress tracking
  phase1_completed_at TIMESTAMP WITH TIME ZONE,  -- When 90-day fetch completed
  phase2_started_at TIMESTAMP WITH TIME ZONE,    -- When 2-year fetch started
  phase2_completed_at TIMESTAMP WITH TIME ZONE,  -- When 2-year fetch completed

  -- Detailed progress for Phase 2
  oldest_killmail_date DATE,           -- Oldest killmail fetched so far
  target_date DATE,                    -- Target date (2 years ago)
  killmails_fetched INTEGER DEFAULT 0, -- Total killmails fetched in phase 2
  current_page INTEGER DEFAULT 1,      -- Current zkillboard page being fetched

  -- Error tracking
  last_error TEXT,
  retry_count INTEGER DEFAULT 0,
  last_retry_at TIMESTAMP WITH TIME ZONE,

  -- Timestamps
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_entity UNIQUE (entity_type, entity_id),
  CONSTRAINT valid_entity_type CHECK (entity_type IN ('character', 'corporation', 'system', 'alliance')),
  CONSTRAINT valid_status CHECK (status IN ('pending', 'phase1_complete', 'in_progress', 'completed', 'failed'))
);

-- Indexes for efficient lookups
CREATE INDEX idx_historical_fetch_status_entity ON historical_fetch_status(entity_type, entity_id);
CREATE INDEX idx_historical_fetch_status_status ON historical_fetch_status(status);
CREATE INDEX idx_historical_fetch_status_pending ON historical_fetch_status(status) WHERE status IN ('pending', 'phase1_complete', 'in_progress');
```

---

## Backend Implementation

### 1. Ash Resource: HistoricalFetchStatus

**File**: `lib/eve_dmv/contexts/killmail_processing/resources/historical_fetch_status.ex`

```elixir
defmodule EveDmv.Contexts.KillmailProcessing.Resources.HistoricalFetchStatus do
  @moduledoc """
  Tracks the status of historical killmail fetches for entities.

  Supports character, corporation, system, and alliance entities.
  Tracks both Phase 1 (90-day) and Phase 2 (2-year) fetch progress.
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "historical_fetch_status"
    repo EveDmv.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :entity_type, :atom do
      constraints one_of: [:character, :corporation, :system, :alliance]
      allow_nil? false
    end

    attribute :entity_id, :integer do
      allow_nil? false
    end

    attribute :status, :atom do
      constraints one_of: [:pending, :phase1_complete, :in_progress, :completed, :failed]
      default :pending
      allow_nil? false
    end

    attribute :phase1_completed_at, :utc_datetime_usec
    attribute :phase2_started_at, :utc_datetime_usec
    attribute :phase2_completed_at, :utc_datetime_usec

    attribute :oldest_killmail_date, :date
    attribute :target_date, :date
    attribute :killmails_fetched, :integer, default: 0
    attribute :current_page, :integer, default: 1

    attribute :last_error, :string
    attribute :retry_count, :integer, default: 0
    attribute :last_retry_at, :utc_datetime_usec

    timestamps()
  end

  identities do
    identity :unique_entity, [:entity_type, :entity_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:entity_type, :entity_id, :status, :target_date]

      change fn changeset, _context ->
        # Set target_date to 2 years ago if not provided
        if Ash.Changeset.get_attribute(changeset, :target_date) == nil do
          two_years_ago = Date.add(Date.utc_today(), -730)
          Ash.Changeset.change_attribute(changeset, :target_date, two_years_ago)
        else
          changeset
        end
      end
    end

    update :mark_phase1_complete do
      accept []
      change set_attribute(:status, :phase1_complete)
      change set_attribute(:phase1_completed_at, &DateTime.utc_now/0)
    end

    update :start_phase2 do
      accept []
      change set_attribute(:status, :in_progress)
      change set_attribute(:phase2_started_at, &DateTime.utc_now/0)
    end

    update :update_progress do
      accept [:oldest_killmail_date, :killmails_fetched, :current_page]
    end

    update :mark_completed do
      accept []
      change set_attribute(:status, :completed)
      change set_attribute(:phase2_completed_at, &DateTime.utc_now/0)
    end

    update :mark_failed do
      accept [:last_error]
      change set_attribute(:status, :failed)
      change fn changeset, _context ->
        current_retry = Ash.Changeset.get_attribute(changeset, :retry_count) || 0
        changeset
        |> Ash.Changeset.change_attribute(:retry_count, current_retry + 1)
        |> Ash.Changeset.change_attribute(:last_retry_at, DateTime.utc_now())
      end
    end

    read :get_by_entity do
      argument :entity_type, :atom, allow_nil?: false
      argument :entity_id, :integer, allow_nil?: false

      filter expr(entity_type == ^arg(:entity_type) and entity_id == ^arg(:entity_id))

      prepare fn query, _context ->
        Ash.Query.limit(query, 1)
      end
    end

    read :get_pending_fetches do
      filter expr(status in [:pending, :phase1_complete])
      prepare fn query, _context ->
        Ash.Query.sort(query, inserted_at: :asc)
      end
    end

    read :get_in_progress do
      filter expr(status == :in_progress)
    end
  end

  calculations do
    calculate :progress_percentage, :float do
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          case record.status do
            :completed -> 100.0
            :pending -> 0.0
            :phase1_complete -> 10.0  # 90 days = ~10% of 2 years
            :in_progress ->
              if record.oldest_killmail_date && record.target_date do
                today = Date.utc_today()
                total_days = Date.diff(today, record.target_date)
                fetched_days = Date.diff(today, record.oldest_killmail_date)
                min(100.0, (fetched_days / total_days) * 100.0)
              else
                10.0
              end
            :failed -> 0.0
          end
        end)
      end
    end
  end
end
```

### 2. Extended Historical Fetcher Service

**File**: `lib/eve_dmv/contexts/killmail_processing/domain/extended_historical_fetcher.ex`

```elixir
defmodule EveDmv.Contexts.KillmailProcessing.Domain.ExtendedHistoricalFetcher do
  @moduledoc """
  Fetches historical killmail data beyond the 90-day window.

  Uses zkillboard API to fetch up to 2 years of historical data.
  Implements rate limiting and pagination to respect API limits.
  """

  alias EveDmv.Contexts.KillmailProcessing.Resources.HistoricalFetchStatus
  alias EveDmv.Http.UnifiedClient
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Killmails.Participant

  require Logger

  @zkillboard_base_url "https://zkillboard.com/api"
  @rate_limit_delay 1_000  # 1 second between requests (zkillboard rate limit)
  @kills_per_page 200      # zkillboard max per page
  @max_pages 100           # Safety limit: 100 pages * 200 kills = 20,000 kills max
  @two_years_days 730

  @type entity_type :: :character | :corporation | :system | :alliance
  @type fetch_result :: {:ok, map()} | {:error, term()}

  @doc """
  Fetch extended historical data for an entity.

  This is the main entry point for Phase 2 fetching.
  Fetches from zkillboard API starting from where Phase 1 left off.

  ## Options
  - `:start_page` - Page to start from (default: 1)
  - `:start_date` - Only fetch kills older than this date
  - `:callback` - Function to call with progress updates

  Returns `{:ok, %{killmails_fetched: count, pages_processed: count, oldest_date: date}}`
  """
  @spec fetch_extended_history(entity_type(), integer(), keyword()) :: fetch_result()
  def fetch_extended_history(entity_type, entity_id, opts \\ []) do
    start_page = Keyword.get(opts, :start_page, 1)
    cutoff_date = Date.add(Date.utc_today(), -@two_years_days)
    start_date = Keyword.get(opts, :start_date, Date.add(Date.utc_today(), -90))
    callback = Keyword.get(opts, :callback)

    Logger.info(
      "Starting extended historical fetch for #{entity_type} #{entity_id} " <>
      "from page #{start_page}, targeting #{cutoff_date}"
    )

    fetch_pages(
      entity_type,
      entity_id,
      start_page,
      cutoff_date,
      start_date,
      callback,
      %{killmails_fetched: 0, pages_processed: 0, oldest_date: nil}
    )
  end

  # Recursive page fetching with rate limiting
  defp fetch_pages(entity_type, entity_id, page, cutoff_date, start_date, callback, acc) do
    if page > @max_pages do
      Logger.warning("Reached max pages limit (#{@max_pages}) for #{entity_type} #{entity_id}")
      {:ok, acc}
    else
      # Rate limit
      if page > 1, do: Process.sleep(@rate_limit_delay)

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
            acc |
            killmails_fetched: acc.killmails_fetched + stored_count,
            pages_processed: acc.pages_processed + 1,
            oldest_date: oldest_date || acc.oldest_date
          }

          # Report progress
          if callback, do: callback.({:progress, new_acc})

          if reached_cutoff do
            Logger.info(
              "Reached cutoff date #{cutoff_date} for #{entity_type} #{entity_id}"
            )
            {:ok, new_acc}
          else
            # Continue to next page
            fetch_pages(
              entity_type,
              entity_id,
              page + 1,
              cutoff_date,
              start_date,
              callback,
              new_acc
            )
          end

        {:error, :rate_limited} ->
          # Back off and retry
          Logger.warning("Rate limited, backing off for 60 seconds")
          Process.sleep(60_000)
          fetch_pages(entity_type, entity_id, page, cutoff_date, start_date, callback, acc)

        {:error, reason} = error ->
          Logger.error("Failed to fetch page #{page}: #{inspect(reason)}")
          error
      end
    end
  end

  defp fetch_page(entity_type, entity_id, page) do
    url = build_url(entity_type, entity_id, page)

    case UnifiedClient.get(url, timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, kills} when is_list(kills) -> {:ok, kills}
          {:ok, _} -> {:ok, []}
          {:error, _} -> {:error, :invalid_json}
        end

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: 404}} ->
        {:ok, []}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

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

  defp process_kills(kills, cutoff_date, start_date) do
    oldest_date = nil
    reached_cutoff = false

    relevant_kills =
      kills
      |> Enum.map(fn kill ->
        kill_date = parse_kill_date(kill["killmail_time"])
        {kill, kill_date}
      end)
      |> Enum.filter(fn {_kill, kill_date} ->
        # Only include kills older than start_date (Phase 1 boundary)
        Date.compare(kill_date, start_date) == :lt
      end)
      |> Enum.take_while(fn {_kill, kill_date} ->
        # Stop when we reach the cutoff
        Date.compare(kill_date, cutoff_date) != :lt
      end)

    oldest =
      relevant_kills
      |> Enum.map(fn {_kill, date} -> date end)
      |> Enum.min(Date, fn -> nil end)

    reached =
      Enum.any?(kills, fn kill ->
        kill_date = parse_kill_date(kill["killmail_time"])
        Date.compare(kill_date, cutoff_date) == :lt
      end)

    {Enum.map(relevant_kills, fn {kill, _} -> kill end), oldest, reached}
  end

  defp parse_kill_date(nil), do: Date.utc_today()

  defp parse_kill_date(time_string) when is_binary(time_string) do
    case DateTime.from_iso8601(time_string <> "Z") do
      {:ok, datetime, _} -> DateTime.to_date(datetime)
      _ -> Date.utc_today()
    end
  rescue
    _ -> Date.utc_today()
  end

  defp store_kills(kills) do
    kills
    |> Enum.map(&transform_zkb_kill/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&store_single_kill/1)
    |> Enum.count(& &1 == :ok)
  end

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
      total_value: Decimal.new(to_string(zkb["totalValue"] || 0)),
      raw_data: zkb_kill,
      source: "zkillboard-extended"
    }
  rescue
    _ -> nil
  end

  defp parse_killmail_time(nil), do: DateTime.utc_now()

  defp parse_killmail_time(time_string) when is_binary(time_string) do
    case DateTime.from_iso8601(time_string <> "Z") do
      {:ok, datetime, _} -> datetime
      _ -> DateTime.utc_now()
    end
  end

  defp store_single_kill(killmail_data) do
    case Ash.create(KillmailRaw, killmail_data,
           action: :ingest_from_source,
           domain: EveDmv.Api) do
      {:ok, killmail} ->
        # Also create participants
        store_participants(killmail_data.raw_data, killmail.killmail_id)
        :ok
      {:error, %Ash.Error.Invalid{errors: errors}} ->
        if Enum.any?(errors, &match?(%{class: :uniqueness}, &1)) do
          :ok  # Already exists, that's fine
        else
          :error
        end
      {:error, _} ->
        :error
    end
  rescue
    _ -> :ok  # Ignore duplicate errors
  end

  defp store_participants(raw_data, killmail_id) do
    victim = raw_data["victim"] || %{}
    attackers = raw_data["attackers"] || []
    killmail_time = parse_killmail_time(raw_data["killmail_time"])
    solar_system_id = raw_data["solar_system_id"]

    participants = []

    # Add victim
    participants =
      if victim["ship_type_id"] do
        [build_participant(victim, killmail_id, killmail_time, solar_system_id, true, false) | participants]
      else
        participants
      end

    # Add attackers
    participants =
      attackers
      |> Enum.filter(& &1["ship_type_id"])
      |> Enum.map(&build_participant(&1, killmail_id, killmail_time, solar_system_id, false, &1["final_blow"] || false))
      |> Kernel.++(participants)

    # Bulk insert participants
    Ash.bulk_create(participants, Participant, :create,
      domain: EveDmv.Api,
      return_records?: false,
      return_errors?: false,
      stop_on_error?: false,
      batch_size: 500
    )
  rescue
    _ -> :ok
  end

  defp build_participant(entity, killmail_id, killmail_time, solar_system_id, is_victim, final_blow) do
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
      security_status: entity["security_status"],
      is_victim: is_victim,
      final_blow: final_blow,
      solar_system_id: solar_system_id
    }
  end
end
```

### 3. Historical Fetch Worker (GenServer)

**File**: `lib/eve_dmv/contexts/killmail_processing/domain/historical_fetch_worker.ex`

```elixir
defmodule EveDmv.Contexts.KillmailProcessing.Domain.HistoricalFetchWorker do
  @moduledoc """
  Background worker that processes the historical fetch queue.

  Manages Phase 2 (2-year) fetches for entities. Runs as a GenServer
  that processes one entity at a time to respect rate limits.
  """

  use GenServer

  alias EveDmv.Contexts.KillmailProcessing.Domain.ExtendedHistoricalFetcher
  alias EveDmv.Contexts.KillmailProcessing.Resources.HistoricalFetchStatus
  alias Phoenix.PubSub

  require Logger

  @check_interval 30_000  # Check for new work every 30 seconds
  @pubsub_topic "historical_fetch_updates"

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Queue an entity for Phase 2 historical fetch.

  Creates or updates the fetch status record and notifies the worker.
  """
  @spec queue_fetch(atom(), integer()) :: {:ok, term()} | {:error, term()}
  def queue_fetch(entity_type, entity_id) do
    GenServer.call(__MODULE__, {:queue_fetch, entity_type, entity_id})
  end

  @doc """
  Get the current status of a fetch.
  """
  @spec get_status(atom(), integer()) :: {:ok, map()} | {:error, :not_found}
  def get_status(entity_type, entity_id) do
    case Ash.read(HistoricalFetchStatus,
           action: :get_by_entity,
           arguments: %{entity_type: entity_type, entity_id: entity_id},
           domain: EveDmv.Api) do
      {:ok, [status]} -> {:ok, status}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Subscribe to status updates for an entity.
  """
  @spec subscribe(atom(), integer()) :: :ok
  def subscribe(entity_type, entity_id) do
    PubSub.subscribe(EveDmv.PubSub, topic(entity_type, entity_id))
  end

  @doc """
  Unsubscribe from status updates.
  """
  @spec unsubscribe(atom(), integer()) :: :ok
  def unsubscribe(entity_type, entity_id) do
    PubSub.unsubscribe(EveDmv.PubSub, topic(entity_type, entity_id))
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("HistoricalFetchWorker starting")

    # Schedule initial work check
    Process.send_after(self(), :check_queue, 5_000)

    {:ok, %{current_fetch: nil, queue_length: 0}}
  end

  @impl true
  def handle_call({:queue_fetch, entity_type, entity_id}, _from, state) do
    result = ensure_fetch_record(entity_type, entity_id)

    # Trigger queue check
    send(self(), :check_queue)

    {:reply, result, state}
  end

  @impl true
  def handle_info(:check_queue, %{current_fetch: nil} = state) do
    # No current fetch, look for work
    case get_next_pending() do
      {:ok, fetch_record} ->
        # Start processing
        Logger.info(
          "Starting Phase 2 fetch for #{fetch_record.entity_type} #{fetch_record.entity_id}"
        )

        # Start async fetch
        parent = self()
        Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
          result = process_fetch(fetch_record)
          send(parent, {:fetch_complete, fetch_record.id, result})
        end)

        {:noreply, %{state | current_fetch: fetch_record.id}}

      {:ok, nil} ->
        # No pending work, schedule next check
        Process.send_after(self(), :check_queue, @check_interval)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Error checking fetch queue: #{inspect(reason)}")
        Process.send_after(self(), :check_queue, @check_interval)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:check_queue, state) do
    # Already processing, ignore
    {:noreply, state}
  end

  @impl true
  def handle_info({:fetch_complete, fetch_id, result}, state) do
    Logger.info("Fetch #{fetch_id} complete: #{inspect(result)}")

    # Schedule next queue check immediately
    send(self(), :check_queue)

    {:noreply, %{state | current_fetch: nil}}
  end

  @impl true
  def handle_info({:fetch_progress, entity_type, entity_id, progress}, state) do
    # Broadcast progress update
    broadcast_update(entity_type, entity_id, {:progress, progress})
    {:noreply, state}
  end

  # Private Functions

  defp ensure_fetch_record(entity_type, entity_id) do
    case get_status(entity_type, entity_id) do
      {:ok, status} ->
        # Already exists
        {:ok, status}

      {:error, :not_found} ->
        # Create new record
        Ash.create(HistoricalFetchStatus, %{
          entity_type: entity_type,
          entity_id: entity_id,
          status: :pending
        }, domain: EveDmv.Api)
    end
  end

  defp get_next_pending do
    case Ash.read(HistoricalFetchStatus,
           action: :get_pending_fetches,
           domain: EveDmv.Api) do
      {:ok, []} -> {:ok, nil}
      {:ok, [first | _]} -> {:ok, first}
      error -> error
    end
  end

  defp process_fetch(fetch_record) do
    entity_type = fetch_record.entity_type
    entity_id = fetch_record.entity_id

    # Mark as in progress
    Ash.update(fetch_record, %{}, action: :start_phase2, domain: EveDmv.Api)
    broadcast_update(entity_type, entity_id, :started)

    # Create progress callback
    worker = self()
    callback = fn {:progress, progress} ->
      # Update record
      Ash.update(fetch_record, %{
        oldest_killmail_date: progress.oldest_date,
        killmails_fetched: progress.killmails_fetched,
        current_page: progress.pages_processed
      }, action: :update_progress, domain: EveDmv.Api)

      # Notify worker
      send(worker, {:fetch_progress, entity_type, entity_id, progress})
    end

    # Perform fetch
    case ExtendedHistoricalFetcher.fetch_extended_history(
           entity_type,
           entity_id,
           callback: callback
         ) do
      {:ok, result} ->
        # Mark as complete
        Ash.update(fetch_record, %{}, action: :mark_completed, domain: EveDmv.Api)
        broadcast_update(entity_type, entity_id, {:completed, result})
        {:ok, result}

      {:error, reason} ->
        # Mark as failed
        Ash.update(fetch_record, %{
          last_error: inspect(reason)
        }, action: :mark_failed, domain: EveDmv.Api)
        broadcast_update(entity_type, entity_id, {:failed, reason})
        {:error, reason}
    end
  end

  defp topic(entity_type, entity_id) do
    "#{@pubsub_topic}:#{entity_type}:#{entity_id}"
  end

  defp broadcast_update(entity_type, entity_id, message) do
    PubSub.broadcast(EveDmv.PubSub, topic(entity_type, entity_id),
      {:historical_fetch_update, entity_type, entity_id, message})
  end
end
```

### 4. Update Application Supervisor

**File**: `lib/eve_dmv/application.ex` (modification)

Add to children list:

```elixir
# In the children list, add:
{EveDmv.Contexts.KillmailProcessing.Domain.HistoricalFetchWorker, []}
```

### 5. Update Killmail Processing API

**File**: `lib/eve_dmv/contexts/killmail_processing/api.ex` (modification)

Add new functions:

```elixir
@doc """
Queue an entity for 2-year historical fetch (Phase 2).

Phase 1 (90-day) should be completed before calling this.
"""
@spec queue_extended_historical_fetch(atom(), integer()) :: Result.t(map())
def queue_extended_historical_fetch(entity_type, entity_id)
    when entity_type in [:character, :corporation, :system, :alliance] do
  Domain.HistoricalFetchWorker.queue_fetch(entity_type, entity_id)
end

@doc """
Get the historical fetch status for an entity.
"""
@spec get_historical_fetch_status(atom(), integer()) :: Result.t(map()) | {:error, :not_found}
def get_historical_fetch_status(entity_type, entity_id) do
  Domain.HistoricalFetchWorker.get_status(entity_type, entity_id)
end

@doc """
Subscribe to historical fetch status updates for an entity.
"""
@spec subscribe_to_historical_fetch(atom(), integer()) :: :ok
def subscribe_to_historical_fetch(entity_type, entity_id) do
  Domain.HistoricalFetchWorker.subscribe(entity_type, entity_id)
end

@doc """
Mark Phase 1 as complete and queue Phase 2.

Called after the initial 90-day fetch completes.
"""
@spec complete_phase1_and_queue_phase2(atom(), integer()) :: Result.t(map())
def complete_phase1_and_queue_phase2(entity_type, entity_id) do
  alias EveDmv.Contexts.KillmailProcessing.Resources.HistoricalFetchStatus

  # Get or create status record
  case Domain.HistoricalFetchWorker.get_status(entity_type, entity_id) do
    {:ok, status} ->
      # Mark phase 1 complete
      Ash.update(status, %{}, action: :mark_phase1_complete, domain: EveDmv.Api)

    {:error, :not_found} ->
      # Create with phase 1 complete
      Ash.create(HistoricalFetchStatus, %{
        entity_type: entity_type,
        entity_id: entity_id,
        status: :phase1_complete,
        phase1_completed_at: DateTime.utc_now()
      }, domain: EveDmv.Api)
  end
end
```

### 6. Update Player Profile DataLoader

**File**: `lib/eve_dmv/player_profile/data_loader.ex` (modification)

```elixir
defmodule EveDmv.PlayerProfile.DataLoader do
  @moduledoc """
  Data loading service for player profiles.

  Handles ESI integration, character data fetching, corporation and alliance
  information retrieval, and historical killmail loading with proper error
  handling and timeout management.

  Now supports two-phase historical fetch:
  - Phase 1: 90 days (synchronous, immediate)
  - Phase 2: 2 years (asynchronous, background)
  """

  alias EveDmv.Contexts.KillmailProcessing
  alias EveDmv.Eve.EsiClient
  alias EveDmv.Killmails.HistoricalKillmailFetcher
  require Logger

  @doc """
  Load complete character data including ESI info and historical killmails.

  Fetches character, corporation, alliance data and historical killmails
  in a background task with proper error handling.

  After Phase 1 completes, automatically queues Phase 2 (2-year fetch).
  """
  def load_character_data(character_id, callback_pid) do
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      # Fetch character info from ESI with timeout
      character_result =
        case Task.yield(Task.async(fn -> EsiClient.get_character(character_id) end), 10_000) do
          {:ok, result} -> result
          nil -> {:error, :timeout}
        end

      with {:ok, character_info} <- character_result,
           {:ok, corp_info} <- fetch_corporation_info(character_info.corporation_id),
           {:ok, alliance_info} <- fetch_alliance_info(character_info.alliance_id) do
        # Enrich character info
        enriched_info =
          character_info
          |> Map.put(:corporation_name, corp_info.name)
          |> Map.put(:corporation_ticker, corp_info.ticker)
          |> Map.put(:alliance_name, alliance_info[:name])
          |> Map.put(:alliance_ticker, alliance_info[:ticker])

        # Phase 1: Fetch 90 days of historical killmails
        Logger.info("Phase 1: Fetching 90-day historical killmails for character #{character_id}")

        case HistoricalKillmailFetcher.fetch_character_history(character_id) do
          {:ok, killmail_count} ->
            Logger.info(
              "Phase 1 complete: #{killmail_count} killmails for character #{character_id}"
            )

            # Queue Phase 2 (2-year fetch)
            queue_phase2_fetch(:character, character_id)

            send(callback_pid, {:character_esi_loaded, enriched_info, killmail_count})

          {:error, reason} ->
            Logger.warning("Failed to fetch historical killmails: #{inspect(reason)}")
            # Still queue Phase 2 even if Phase 1 failed
            queue_phase2_fetch(:character, character_id)
            send(callback_pid, {:character_esi_loaded, enriched_info, 0})
        end
      else
        {:error, :not_found} ->
          send(callback_pid, {:character_load_failed, :character_not_found})

        {:error, :timeout} ->
          send(callback_pid, {:character_load_failed, :esi_timeout})

        {:error, _reason} ->
          send(callback_pid, {:character_load_failed, :esi_unavailable})
      end
    end)
  end

  # Queue Phase 2 fetch in background
  defp queue_phase2_fetch(entity_type, entity_id) do
    Logger.info("Queueing Phase 2 (2-year) fetch for #{entity_type} #{entity_id}")
    KillmailProcessing.complete_phase1_and_queue_phase2(entity_type, entity_id)
  rescue
    error ->
      Logger.error("Failed to queue Phase 2 fetch: #{inspect(error)}")
  end

  # ... rest of existing functions unchanged ...
end
```

---

## Frontend Implementation

### 1. Historical Fetch Indicator Component

**File**: `lib/eve_dmv_web/components/historical_fetch_indicator.ex`

```elixir
defmodule EveDmvWeb.Components.HistoricalFetchIndicator do
  @moduledoc """
  Component that displays the historical data fetch status.

  Shows a discrete indicator with the following states:
  - Not started (hidden or minimal)
  - Phase 1 in progress (loading spinner)
  - Phase 2 in progress (progress bar)
  - Completed (checkmark)
  - Failed (error with retry option)
  """

  use Phoenix.Component

  attr :status, :map, required: true
  attr :entity_type, :atom, required: true
  attr :entity_id, :integer, required: true
  attr :class, :string, default: ""

  def historical_fetch_indicator(assigns) do
    ~H"""
    <div class={"historical-fetch-indicator #{@class}"}>
      <%= case @status do %>
        <% nil -> %>
          <!-- No status yet, Phase 1 likely in progress -->
          <.indicator_loading text="Loading recent data..." />

        <% %{status: :pending} -> %>
          <.indicator_loading text="Loading recent data..." />

        <% %{status: :phase1_complete} -> %>
          <.indicator_queued />

        <% %{status: :in_progress} = status -> %>
          <.indicator_progress status={status} />

        <% %{status: :completed} = status -> %>
          <.indicator_complete status={status} />

        <% %{status: :failed} = status -> %>
          <.indicator_failed
            status={status}
            entity_type={@entity_type}
            entity_id={@entity_id}
          />
      <% end %>
    </div>
    """
  end

  defp indicator_loading(assigns) do
    ~H"""
    <div class="flex items-center gap-2 text-sm text-gray-400">
      <svg class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <span><%= @text %></span>
    </div>
    """
  end

  defp indicator_queued(assigns) do
    ~H"""
    <div class="flex items-center gap-2 text-sm text-blue-400"
         title="Historical data will be loaded in the background">
      <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      <span>2-year history queued</span>
    </div>
    """
  end

  defp indicator_progress(assigns) do
    progress = calculate_progress(assigns.status)
    assigns = assign(assigns, :progress, progress)

    ~H"""
    <div class="flex flex-col gap-1">
      <div class="flex items-center gap-2 text-sm text-yellow-400">
        <svg class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <span>Loading 2-year history...</span>
        <span class="text-gray-500"><%= @status.killmails_fetched || 0 %> kills</span>
      </div>
      <div class="w-full bg-gray-700 rounded-full h-1.5">
        <div class="bg-yellow-400 h-1.5 rounded-full transition-all duration-500"
             style={"width: #{@progress}%"}>
        </div>
      </div>
    </div>
    """
  end

  defp indicator_complete(assigns) do
    ~H"""
    <div class="flex items-center gap-2 text-sm text-green-400"
         title={"2-year history loaded: #{@status.killmails_fetched || 0} killmails"}>
      <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M5 13l4 4L19 7" />
      </svg>
      <span>2-year history complete</span>
      <span class="text-gray-500">(<%= @status.killmails_fetched || 0 %> kills)</span>
    </div>
    """
  end

  defp indicator_failed(assigns) do
    ~H"""
    <div class="flex items-center gap-2 text-sm text-red-400">
      <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      <span>History load failed</span>
      <button
        phx-click="retry_historical_fetch"
        phx-value-entity_type={@entity_type}
        phx-value-entity_id={@entity_id}
        class="text-blue-400 hover:text-blue-300 underline">
        Retry
      </button>
    </div>
    """
  end

  defp calculate_progress(status) do
    cond do
      status.status == :completed -> 100
      status.oldest_killmail_date && status.target_date ->
        today = Date.utc_today()
        total_days = Date.diff(today, status.target_date)
        fetched_days = Date.diff(today, status.oldest_killmail_date)
        min(100, round(fetched_days / max(total_days, 1) * 100))
      true -> 10  # Phase 1 is ~10% of 2 years
    end
  end
end
```

### 2. Update PlayerProfileLive

**File**: `lib/eve_dmv_web/live/player_profile_live.ex` (modifications)

```elixir
defmodule EveDmvWeb.PlayerProfileLive do
  # ... existing module attributes and imports ...

  # Add import for the indicator component
  import EveDmvWeb.Components.HistoricalFetchIndicator

  # Add alias
  alias EveDmv.Contexts.KillmailProcessing

  @impl Phoenix.LiveView
  def mount(%{"character_id" => character_id_str}, _session, socket) do
    case Integer.parse(character_id_str) do
      {character_id, ""} ->
        # Subscribe to historical fetch updates
        if connected?(socket) do
          KillmailProcessing.subscribe_to_historical_fetch(:character, character_id)
        end

        # Get current historical fetch status
        historical_status = get_historical_status(:character, character_id)

        socket =
          socket
          |> assign(:character_id, character_id)
          |> assign(:player_stats, nil)
          |> assign(:character_intel, nil)
          |> assign(:character_info, nil)
          |> assign(:loading, true)
          |> assign(:error, nil)
          |> assign(:no_data, false)
          |> assign(:historical_fetch_status, historical_status)

        # Load data asynchronously
        send(self(), {:load_character_data, character_id})

        {:ok, socket}

      _ ->
        socket =
          socket
          |> assign(:error, "Invalid character ID")
          |> assign(:loading, false)

        {:ok, socket}
    end
  end

  # Handle historical fetch status updates
  @impl Phoenix.LiveView
  def handle_info({:historical_fetch_update, :character, _entity_id, update}, socket) do
    character_id = socket.assigns.character_id

    case update do
      {:progress, _progress} ->
        # Refresh status
        status = get_historical_status(:character, character_id)
        {:noreply, assign(socket, :historical_fetch_status, status)}

      {:completed, _result} ->
        # Refresh status and potentially reload data
        status = get_historical_status(:character, character_id)
        # Optionally reload stats to include new data
        send(self(), {:refresh_with_historical, character_id})
        {:noreply, assign(socket, :historical_fetch_status, status)}

      {:failed, _reason} ->
        status = get_historical_status(:character, character_id)
        {:noreply, assign(socket, :historical_fetch_status, status)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:refresh_with_historical, character_id}, socket) do
    # Reload statistics with the new historical data
    player_stats = load_player_stats(character_id)
    character_intel = load_character_intel(character_id)

    {:noreply,
     socket
     |> assign(:player_stats, player_stats)
     |> assign(:character_intel, character_intel)}
  end

  # Handle retry button click
  @impl Phoenix.LiveView
  def handle_event("retry_historical_fetch", %{"entity_type" => "character", "entity_id" => id}, socket) do
    entity_id = String.to_integer(id)
    KillmailProcessing.queue_extended_historical_fetch(:character, entity_id)
    status = get_historical_status(:character, entity_id)
    {:noreply, assign(socket, :historical_fetch_status, status)}
  end

  # Helper function
  defp get_historical_status(entity_type, entity_id) do
    case KillmailProcessing.get_historical_fetch_status(entity_type, entity_id) do
      {:ok, status} -> status
      {:error, :not_found} -> nil
    end
  end

  # ... rest of existing code ...
end
```

**Add to template** (`lib/eve_dmv_web/live/player_profile_live.html.heex`):

```heex
<!-- Add near the top of the profile, after character info -->
<div class="mb-4">
  <.historical_fetch_indicator
    status={@historical_fetch_status}
    entity_type={:character}
    entity_id={@character_id}
  />
</div>
```

### 3. Update CorporationLive

**File**: `lib/eve_dmv_web/live/corporation_live.ex` (modifications)

Add similar changes:
1. Import the indicator component
2. Subscribe to historical fetch updates in mount
3. Add `historical_fetch_status` assign
4. Handle `:historical_fetch_update` messages
5. Trigger Phase 2 fetch in `load_all_corporation_data/1`
6. Handle retry events

```elixir
# In load_all_corporation_data/1, after loading data:
# Queue historical fetch for corporation
KillmailProcessing.complete_phase1_and_queue_phase2(:corporation, corporation_id)
```

### 4. Update SystemLive

**File**: `lib/eve_dmv_web/live/system_live.ex` (modifications)

Similar pattern - add historical fetch tracking for system activity data.

### 5. Update AllianceLive

**File**: `lib/eve_dmv_web/live/alliance_live.ex` (modifications)

Similar pattern - add historical fetch tracking for alliance data.

---

## Testing Strategy

### 1. Unit Tests for ExtendedHistoricalFetcher

**File**: `test/eve_dmv/contexts/killmail_processing/domain/extended_historical_fetcher_test.exs`

```elixir
defmodule EveDmv.Contexts.KillmailProcessing.Domain.ExtendedHistoricalFetcherTest do
  use EveDmv.DataCase

  alias EveDmv.Contexts.KillmailProcessing.Domain.ExtendedHistoricalFetcher

  import Mox

  setup :verify_on_exit!

  describe "fetch_extended_history/3" do
    test "fetches pages until cutoff date is reached" do
      # Mock HTTP responses
      # ...
    end

    test "handles rate limiting with backoff" do
      # ...
    end

    test "stops at max pages limit" do
      # ...
    end

    test "stores killmails and participants" do
      # ...
    end
  end
end
```

### 2. Integration Tests for Worker

**File**: `test/eve_dmv/contexts/killmail_processing/domain/historical_fetch_worker_test.exs`

### 3. LiveView Tests

**File**: `test/eve_dmv_web/live/player_profile_live_test.exs`

Test that the indicator renders correctly for each status.

---

## Configuration

### Runtime Configuration

**File**: `config/runtime.exs` (additions)

```elixir
config :eve_dmv, EveDmv.Contexts.KillmailProcessing.Domain.ExtendedHistoricalFetcher,
  # Rate limit delay between zkillboard requests (ms)
  rate_limit_delay: System.get_env("HISTORICAL_FETCH_RATE_LIMIT", "1000") |> String.to_integer(),

  # Maximum pages to fetch per entity
  max_pages: System.get_env("HISTORICAL_FETCH_MAX_PAGES", "100") |> String.to_integer(),

  # Target lookback period in days
  lookback_days: System.get_env("HISTORICAL_FETCH_LOOKBACK_DAYS", "730") |> String.to_integer()

config :eve_dmv, EveDmv.Contexts.KillmailProcessing.Domain.HistoricalFetchWorker,
  # How often to check for new work (ms)
  check_interval: System.get_env("HISTORICAL_FETCH_CHECK_INTERVAL", "30000") |> String.to_integer(),

  # Enable/disable the worker
  enabled: System.get_env("HISTORICAL_FETCH_ENABLED", "true") == "true"
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HISTORICAL_FETCH_RATE_LIMIT` | `1000` | Delay between zkillboard API calls (ms) |
| `HISTORICAL_FETCH_MAX_PAGES` | `100` | Max pages to fetch per entity |
| `HISTORICAL_FETCH_LOOKBACK_DAYS` | `730` | Days of history to fetch (2 years) |
| `HISTORICAL_FETCH_CHECK_INTERVAL` | `30000` | Worker queue check interval (ms) |
| `HISTORICAL_FETCH_ENABLED` | `true` | Enable/disable background fetching |

---

## File-by-File Implementation Guide

### Phase 1: Database and Resource

1. **Create migration**: `priv/repo/migrations/TIMESTAMP_create_historical_fetch_status.exs`
   - Create the `historical_fetch_status` table with all columns and indexes

2. **Create Ash Resource**: `lib/eve_dmv/contexts/killmail_processing/resources/historical_fetch_status.ex`
   - Full resource definition with all actions and calculations

3. **Add to API domain**: `lib/eve_dmv/api.ex`
   - Add `HistoricalFetchStatus` to the domain's resources

### Phase 2: Backend Services

4. **Create ExtendedHistoricalFetcher**: `lib/eve_dmv/contexts/killmail_processing/domain/extended_historical_fetcher.ex`
   - Zkillboard API integration
   - Pagination and rate limiting
   - Kill storage logic

5. **Create HistoricalFetchWorker**: `lib/eve_dmv/contexts/killmail_processing/domain/historical_fetch_worker.ex`
   - GenServer implementation
   - Queue management
   - PubSub integration

6. **Update Application**: `lib/eve_dmv/application.ex`
   - Add worker to supervision tree

7. **Update KillmailProcessing API**: `lib/eve_dmv/contexts/killmail_processing/api.ex`
   - Add public API functions

### Phase 3: Integration with Data Loaders

8. **Update PlayerProfile DataLoader**: `lib/eve_dmv/player_profile/data_loader.ex`
   - Queue Phase 2 after Phase 1 completes

9. **Create/Update Corporation DataLoader** (if needed)
   - Add historical fetch queuing

10. **Update SystemLive load functions**
    - Add historical fetch queuing

11. **Update AllianceLive load functions**
    - Add historical fetch queuing

### Phase 4: Frontend Components

12. **Create HistoricalFetchIndicator**: `lib/eve_dmv_web/components/historical_fetch_indicator.ex`
    - Status display component

13. **Update PlayerProfileLive**: `lib/eve_dmv_web/live/player_profile_live.ex`
    - Subscribe to updates
    - Display indicator
    - Handle retry events

14. **Update CorporationLive**: `lib/eve_dmv_web/live/corporation_live.ex`
    - Same pattern as PlayerProfileLive

15. **Update SystemLive**: `lib/eve_dmv_web/live/system_live.ex`
    - Same pattern

16. **Update AllianceLive**: `lib/eve_dmv_web/live/alliance_live.ex`
    - Same pattern

### Phase 5: Testing

17. **Unit tests for ExtendedHistoricalFetcher**
18. **Unit tests for HistoricalFetchWorker**
19. **Integration tests for API**
20. **LiveView tests for indicator component**

### Phase 6: Documentation and Configuration

21. **Update runtime.exs** with configuration options
22. **Update CLAUDE.md** with new feature documentation
23. **Add to ARCHITECTURE.md** if needed

---

## Important Implementation Notes

### Rate Limiting
zkillboard has strict rate limits. The implementation uses:
- 1 second delay between requests (configurable)
- Automatic backoff on 429 responses (60 seconds)
- Maximum pages limit to prevent runaway fetches

### Error Handling
- Failed fetches are marked as `failed` with retry count
- Retry mechanism available via UI button
- Automatic retry can be added via scheduled job if needed

### Memory Efficiency
- Kills are processed and stored page-by-page
- No large in-memory accumulation
- Progress is persisted to database after each page

### PubSub Integration
- LiveViews subscribe to entity-specific topics
- Real-time progress updates without polling
- Automatic cleanup on disconnect

### Idempotency
- Duplicate killmails are safely ignored
- Status transitions are idempotent
- Safe to retry failed fetches

---

## Estimated Implementation Effort

| Component | Complexity | Notes |
|-----------|------------|-------|
| Database/Resource | Low | Standard Ash resource |
| ExtendedHistoricalFetcher | Medium | API integration, pagination |
| HistoricalFetchWorker | Medium | GenServer, PubSub |
| API Integration | Low | Delegate functions |
| DataLoader Updates | Low | Add queue calls |
| UI Component | Low | Simple status display |
| LiveView Updates | Medium | Subscriptions, handlers |
| Testing | Medium | Mocking HTTP, PubSub |

**Total estimated effort**: 2-3 days for a developer familiar with the codebase.
