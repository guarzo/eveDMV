defmodule EveDmv.Contexts.KillmailProcessing.Api do
  @moduledoc """
  Public API for the Killmail Processing bounded context.

  This module defines the external interface that other contexts
  and the web layer can use to interact with killmail data.
  All business logic is delegated to domain services.
  """

  alias EveDmv.Contexts.KillmailProcessing.Domain
  alias EveDmv.Contexts.KillmailProcessing.Domain.HistoricalFetchManager
  alias EveDmv.Contexts.KillmailProcessing.Domain.KillmailPresenter
  alias EveDmv.Contexts.KillmailProcessing.Domain.KillmailQueryService
  alias EveDmv.Result
  alias EveDmv.SharedKernel.ValueObjects.TimeRange

  @typedoc "Entity types supported for historical fetch"
  @type entity_type :: :character | :corporation | :alliance | :system

  @typedoc "Historical fetch status structure"
  @type historical_fetch_status :: %{
          id: term(),
          entity_type: term(),
          entity_id: term(),
          status: term(),
          current_page: term(),
          killmails_fetched: term(),
          oldest_killmail_date: term(),
          target_date: term(),
          last_error: term(),
          retry_count: term(),
          phase1_completed_at: term(),
          phase2_started_at: term(),
          phase2_completed_at: term()
        }

  @type killmail_options :: [
          limit: integer(),
          offset: integer(),
          min_value: integer(),
          max_value: integer(),
          time_range: TimeRange.t()
        ]

  # ============================================================================
  # Killmail Ingestion
  # ============================================================================

  @doc """
  Ingest a raw killmail from an external source.

  This is the main entry point for killmail data coming from
  SSE feeds or historical fetching operations.

  ## Examples

      iex> ingest_killmail(%{killmail_id: 123, killmail_time: ~U[2024-01-01 12:00:00Z], ...})
      {:ok, %{raw_inserted: true, enriched_inserted: true, events_published: 2}}
  """
  @spec ingest_killmail(map()) :: Result.t(map())
  defdelegate ingest_killmail(raw_killmail), to: Domain.IngestionService, as: :ingest_validated

  # ============================================================================
  # Killmail Queries
  # ============================================================================

  @doc """
  Get recent killmails with optional filtering.

  Returns enriched killmails sorted by occurrence time (newest first).

  ## Options
  - `:limit` - Maximum number of killmails to return (default: 50, max: 500)
  - `:offset` - Number of killmails to skip (default: 0)
  - `:min_value` - Minimum ISK value filter
  - `:max_value` - Maximum ISK value filter
  - `:time_range` - TimeRange for filtering by occurrence time

  ## Examples

      iex> get_recent_killmails(limit: 10, min_value: 1_000_000_000)
      {:ok, [%EnrichedKillmail{}, ...]}
  """
  @spec get_recent_killmails(killmail_options()) :: Result.t([map()])
  defdelegate get_recent_killmails(opts \\ []), to: KillmailQueryService, as: :get_recent

  @doc """
  Get a specific killmail by its ID.

  Returns both raw and enriched data if available.
  """
  @spec get_killmail_by_id(integer()) ::
          Result.t(map()) | {:error, :not_found | :invalid_killmail_id}
  defdelegate get_killmail_by_id(killmail_id), to: KillmailQueryService, as: :get_by_id

  @doc """
  Get killmails that occurred in a specific solar system.

  ## Examples

      iex> get_killmails_by_system(30000142, limit: 20)  # Jita
      {:ok, [%EnrichedKillmail{}, ...]}
  """
  @spec get_killmails_by_system(integer(), killmail_options()) :: Result.t([map()])
  defdelegate get_killmails_by_system(system_id, opts \\ []),
    to: KillmailQueryService,
    as: :get_by_system

  @doc """
  Get killmails involving a specific character (as victim or attacker).

  ## Examples

      iex> get_killmails_by_character(123456789, limit: 50)
      {:ok, [%EnrichedKillmail{}, ...]}
  """
  @spec get_killmails_by_character(integer(), killmail_options()) :: Result.t([map()])
  defdelegate get_killmails_by_character(character_id, opts \\ []),
    to: KillmailQueryService,
    as: :get_by_character

  @doc """
  Get high-value killmails above a specified ISK threshold.

  ## Examples

      iex> get_high_value_killmails(min_value: 10_000_000_000, limit: 10)
      {:ok, [%EnrichedKillmail{}, ...]}
  """
  @spec get_high_value_killmails(killmail_options()) :: Result.t([map()])
  defdelegate get_high_value_killmails(opts \\ []), to: KillmailQueryService, as: :get_high_value

  # ============================================================================
  # Historical Fetching
  # ============================================================================

  @doc """
  Fetch historical killmail data for specific characters.

  This initiates an asynchronous process to fetch historical data
  from external sources. Returns immediately with a task reference.

  ## Options
  - `:batch_size` - Number of characters to process in parallel (default: 5)
  - `:callback` - Function to call when each character is completed
  - `:timeout` - Timeout for the entire operation (default: 5 minutes)

  ## Examples

      iex> fetch_historical_killmails([123, 456, 789], callback: &handle_completion/1)
      {:ok, %{task_ref: #Reference<>, character_count: 3}}
  """
  @spec fetch_historical_killmails([integer()], keyword()) :: Result.t(map())
  defdelegate fetch_historical_killmails(character_ids, opts \\ []),
    to: Domain.HistoricalService,
    as: :start_fetch_validated

  # ============================================================================
  # Statistics
  # ============================================================================

  @doc """
  Get aggregated statistics for a solar system over a time period.

  Returns kill counts, value destroyed, top ships, etc.

  ## Examples

      iex> time_range = TimeRange.last_days(7)
      iex> get_system_statistics(30000142, time_range)
      {:ok, %{kill_count: 1500, total_value: 45_000_000_000, top_ships: [...]}}
  """
  @spec get_system_statistics(integer(), TimeRange.t()) :: Result.t(map())
  defdelegate get_system_statistics(system_id, time_range),
    to: Domain.StatisticsService,
    as: :calculate_system_statistics_validated

  @doc """
  Get processing pipeline metrics and status.

  Returns information about pipeline performance, error rates, and throughput.
  """
  @spec get_pipeline_metrics() :: Result.t(map())
  defdelegate get_pipeline_metrics(), to: Domain.KillmailOrchestrator, as: :get_metrics_ok

  @doc """
  Get cached killmail display data for the web interface.

  This is optimized for the LiveView kill feed display.
  """
  @spec get_display_data(killmail_options()) :: Result.t(map())
  defdelegate get_display_data(opts \\ []), to: KillmailPresenter, as: :build_display_data

  # ============================================================================
  # Historical Fetch Status API
  # ============================================================================

  @doc """
  Get the historical fetch status for an entity.

  Returns the current status of the 2-year historical fetch for the given entity.

  ## Examples

      iex> get_historical_fetch_status(:character, 12345)
      {:ok, %{status: :completed, killmails_fetched: 150}}

      iex> get_historical_fetch_status(:character, 99999)
      {:error, :not_found}
  """
  @spec get_historical_fetch_status(entity_type(), integer()) ::
          {:ok, historical_fetch_status()} | {:error, :not_found}
  defdelegate get_historical_fetch_status(entity_type, entity_id),
    to: Domain.HistoricalFetchWorker,
    as: :get_status

  @doc """
  Subscribe to historical fetch status updates for an entity.

  Subscribes the current process to PubSub updates for the given entity.
  Updates are broadcast as `{:historical_fetch_update, entity_type, entity_id, update}`.

  ## Examples

      iex> subscribe_to_historical_fetch(:character, 12345)
      :ok
  """
  @spec subscribe_to_historical_fetch(entity_type(), integer()) :: :ok
  defdelegate subscribe_to_historical_fetch(entity_type, entity_id),
    to: Domain.HistoricalFetchWorker,
    as: :subscribe

  @doc """
  Unsubscribe from historical fetch status updates for an entity.

  ## Examples

      iex> unsubscribe_from_historical_fetch(:character, 12345)
      :ok
  """
  @spec unsubscribe_from_historical_fetch(entity_type(), integer()) :: :ok
  defdelegate unsubscribe_from_historical_fetch(entity_type, entity_id),
    to: Domain.HistoricalFetchWorker,
    as: :unsubscribe

  @doc """
  Queue an entity for 2-year historical fetch (Phase 2).

  Creates or updates the historical fetch status and broadcasts the update.

  ## Examples

      iex> queue_extended_historical_fetch(:character, 12345)
      {:ok, %{status: :phase1_complete, ...}}
  """
  @spec queue_extended_historical_fetch(atom(), integer()) :: Result.t(map())
  defdelegate queue_extended_historical_fetch(entity_type, entity_id),
    to: Domain.HistoricalFetchWorker,
    as: :queue_fetch

  @doc """
  Mark Phase 1 complete and queue Phase 2 fetch.

  Called after initial 90-day data is loaded to queue 2-year fetch.

  ## Examples

      iex> complete_phase1_and_queue_phase2(:character, 12345)
      {:ok, %{status: :phase1_complete, ...}}
  """
  @spec complete_phase1_and_queue_phase2(atom(), integer()) :: Result.t(map())
  defdelegate complete_phase1_and_queue_phase2(entity_type, entity_id),
    to: HistoricalFetchManager

  @doc """
  Check if the historical fetch worker is currently busy processing.
  """
  @spec historical_fetch_busy?() :: boolean()
  defdelegate historical_fetch_busy?(), to: Domain.HistoricalFetchWorker, as: :busy?
end
