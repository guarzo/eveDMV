defmodule EveDmv.Contexts.KillmailProcessing.Api do
  @moduledoc """
  Public API for the Killmail Processing bounded context.

  This module defines the external interface that other contexts
  and the web layer can use to interact with killmail data.
  """

  import Ash.Expr

  alias EveDmv.Contexts.KillmailProcessing.Domain
  alias EveDmv.Contexts.KillmailProcessing.Resources.HistoricalFetchStatus
  alias EveDmv.Result
  alias EveDmv.SharedKernel.ValueObjects.CharacterId
  alias EveDmv.SharedKernel.ValueObjects.SolarSystemId
  alias EveDmv.SharedKernel.ValueObjects.TimeRange

  require Ash.Query

  @type killmail_options :: [
          limit: integer(),
          offset: integer(),
          min_value: integer(),
          max_value: integer(),
          time_range: TimeRange.t()
        ]

  @doc """
  Ingest a raw killmail from an external source.

  This is the main entry point for killmail data coming from
  SSE feeds or historical fetching operations.

  ## Examples

      iex> ingest_killmail(%{killmail_id: 123, killmail_time: ~U[2024-01-01 12:00:00Z], ...})
      {:ok, %{raw_inserted: true, enriched_inserted: true, events_published: 2}}
  """
  @spec ingest_killmail(map()) :: Result.t(map())
  def ingest_killmail(raw_killmail) do
    with :ok <- validate_raw_killmail(raw_killmail),
         {:ok, result} <- Domain.IngestionService.ingest(raw_killmail) do
      {:ok, result}
    end
  end

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
  def get_recent_killmails(opts \\ []) do
    with :ok <- validate_killmail_options(opts) do
      limit = Keyword.get(opts, :limit, 100)

      EveDmv.Killmails.KillmailEnriched
      |> Ash.Query.limit(limit)
      |> Ash.Query.sort(killmail_time: :desc)
      |> Ash.read()
    end
  end

  @doc """
  Get a specific killmail by its ID.

  Returns both raw and enriched data if available.
  """
  @spec get_killmail_by_id(integer()) ::
          Result.t(map()) | {:error, :not_found | :invalid_killmail_id}
  def get_killmail_by_id(killmail_id) when is_integer(killmail_id) and killmail_id > 0 do
    # Try to get enriched killmail first, fall back to raw if needed
    case Ash.get(EveDmv.Killmails.KillmailEnriched, killmail_id, domain: EveDmv.Api) do
      {:ok, enriched} ->
        {:ok,
         %{
           killmail: enriched,
           type: :enriched,
           found_at: DateTime.utc_now()
         }}

      {:error, %Ash.Error.Invalid{}} ->
        # Try raw killmail if enriched not found
        case Ash.get(EveDmv.Killmails.KillmailRaw, killmail_id, domain: EveDmv.Api) do
          {:ok, raw} ->
            {:ok,
             %{
               killmail: raw,
               type: :raw,
               found_at: DateTime.utc_now()
             }}

          {:error, _} ->
            {:error, :not_found}
        end

      {:error, _} ->
        {:error, :not_found}
    end
  end

  def get_killmail_by_id(_), do: {:error, :invalid_killmail_id}

  @doc """
  Get killmails that occurred in a specific solar system.

  ## Examples

      iex> get_killmails_by_system(30000142, limit: 20)  # Jita
      {:ok, [%EnrichedKillmail{}, ...]}
  """
  @spec get_killmails_by_system(integer(), killmail_options()) :: Result.t([map()])
  def get_killmails_by_system(system_id, opts \\ []) do
    with {:ok, _system_id_vo} <- SolarSystemId.new(system_id),
         :ok <- validate_killmail_options(opts) do
      limit = Keyword.get(opts, :limit, 100)

      EveDmv.Killmails.KillmailEnriched
      |> Ash.Query.filter(solar_system_id: system_id)
      |> Ash.Query.limit(limit)
      |> Ash.Query.sort(killmail_time: :desc)
      |> Ash.read()
    end
  end

  @doc """
  Get killmails involving a specific character (as victim or attacker).

  ## Examples

      iex> get_killmails_by_character(123456789, limit: 50)
      {:ok, [%EnrichedKillmail{}, ...]}
  """
  @spec get_killmails_by_character(integer(), killmail_options()) :: Result.t([map()])
  def get_killmails_by_character(character_id, opts \\ []) do
    with {:ok, _character_id_vo} <- CharacterId.new(character_id),
         :ok <- validate_killmail_options(opts) do
      limit = Keyword.get(opts, :limit, 100)

      EveDmv.Killmails.KillmailEnriched
      |> Ash.Query.filter(victim_character_id: character_id)
      |> Ash.Query.limit(limit)
      |> Ash.Query.sort(killmail_time: :desc)
      |> Ash.read()
    end
  end

  @doc """
  Get high-value killmails above a specified ISK threshold.

  ## Examples

      iex> get_high_value_killmails(min_value: 10_000_000_000, limit: 10)
      {:ok, [%EnrichedKillmail{}, ...]}
  """
  @spec get_high_value_killmails(killmail_options()) :: Result.t([map()])
  def get_high_value_killmails(opts \\ []) do
    # Set default minimum value for high-value killmails
    # 1B ISK default
    opts_with_defaults = Keyword.put_new(opts, :min_value, 1_000_000_000)

    with :ok <- validate_killmail_options(opts_with_defaults) do
      limit = Keyword.get(opts_with_defaults, :limit, 100)
      min_value = Keyword.get(opts_with_defaults, :min_value, 1_000_000_000)

      EveDmv.Killmails.KillmailEnriched
      |> Ash.Query.filter(expr(total_value >= ^min_value))
      |> Ash.Query.limit(limit)
      |> Ash.Query.sort(total_value: :desc)
      |> Ash.read()
    end
  end

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
  def fetch_historical_killmails(character_ids, opts \\ []) do
    with :ok <- validate_character_ids(character_ids) do
      # Start historical fetching task using the domain service
      case Domain.HistoricalService.start_fetch_task(character_ids, opts) do
        {:ok, task_info} ->
          {:ok, task_info}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Get aggregated statistics for a solar system over a time period.

  Returns kill counts, value destroyed, top ships, etc.

  ## Examples

      iex> time_range = TimeRange.last_days(7)
      iex> get_system_statistics(30000142, time_range)
      {:ok, %{kill_count: 1500, total_value: 45_000_000_000, top_ships: [...]}}
  """
  @spec get_system_statistics(integer(), TimeRange.t()) :: Result.t(map())
  def get_system_statistics(system_id, time_range) do
    with {:ok, system_id_vo} <- SolarSystemId.new(system_id) do
      # Calculate real statistics from killmail data
      case Domain.StatisticsService.calculate_system_statistics(system_id_vo.value, time_range) do
        {:ok, statistics} ->
          {:ok, statistics}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Get processing pipeline metrics and status.

  Returns information about pipeline performance, error rates, and throughput.
  """
  @spec get_pipeline_metrics() :: Result.t(map())
  def get_pipeline_metrics do
    metrics = Domain.KillmailOrchestrator.get_metrics()
    {:ok, metrics}
  end

  @doc """
  Get cached killmail display data for the web interface.

  This is optimized for the LiveView kill feed display.
  """
  @spec get_display_data(killmail_options()) :: Result.t(map())
  def get_display_data(opts \\ []) do
    with :ok <- validate_killmail_options(opts) do
      # Get real killmail display data from enriched killmails
      case get_recent_killmails(opts) do
        {:ok, killmails} ->
          display_data = %{
            killmails: Enum.map(killmails, &format_for_display/1),
            total_count: length(killmails),
            last_updated: DateTime.utc_now()
          }

          {:ok, display_data}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Private validation functions

  defp validate_raw_killmail(killmail) when is_map(killmail) do
    required_fields = [:killmail_id, :killmail_time, :victim, :attackers]

    case Enum.find(required_fields, fn field -> not Map.has_key?(killmail, field) end) do
      nil -> :ok
      missing_field -> {:error, {:missing_field, missing_field}}
    end
  end

  defp validate_raw_killmail(_), do: {:error, :invalid_killmail_format}

  defp validate_killmail_options(opts) when is_list(opts) do
    with :ok <- validate_limit(Keyword.get(opts, :limit)),
         :ok <- validate_offset(Keyword.get(opts, :offset)),
         :ok <-
           validate_value_range(Keyword.get(opts, :min_value), Keyword.get(opts, :max_value)),
         :ok <- validate_time_range(Keyword.get(opts, :time_range)) do
      :ok
    end
  end

  defp validate_killmail_options(_), do: {:error, :invalid_options_format}

  defp validate_limit(nil), do: :ok
  defp validate_limit(limit) when is_integer(limit) and limit > 0 and limit <= 500, do: :ok
  defp validate_limit(_), do: {:error, :invalid_limit}

  defp validate_offset(nil), do: :ok
  defp validate_offset(offset) when is_integer(offset) and offset >= 0, do: :ok
  defp validate_offset(_), do: {:error, :invalid_offset}

  defp validate_value_range(nil, nil), do: :ok
  defp validate_value_range(min, nil) when is_integer(min) and min >= 0, do: :ok
  defp validate_value_range(nil, max) when is_integer(max) and max >= 0, do: :ok

  defp validate_value_range(min, max)
       when is_integer(min) and is_integer(max) and min <= max and min >= 0,
       do: :ok

  defp validate_value_range(_, _), do: {:error, :invalid_value_range}

  defp validate_time_range(nil), do: :ok
  defp validate_time_range(%TimeRange{}), do: :ok
  defp validate_time_range(_), do: {:error, :invalid_time_range}

  defp validate_character_ids(character_ids) when is_list(character_ids) do
    if Enum.all?(character_ids, &(is_integer(&1) and &1 > 0)) do
      :ok
    else
      {:error, :invalid_character_ids}
    end
  end

  defp validate_character_ids(_), do: {:error, :invalid_character_ids_format}

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
  @spec get_historical_fetch_status(atom(), integer()) ::
          {:ok, map()} | {:error, :not_found}
  def get_historical_fetch_status(entity_type, entity_id)
      when entity_type in [:character, :corporation, :system, :alliance] and is_integer(entity_id) do
    Domain.HistoricalFetchWorker.get_status(entity_type, entity_id)
  end

  def get_historical_fetch_status(_, _), do: {:error, :not_found}

  @doc """
  Subscribe to historical fetch status updates for an entity.

  Subscribes the current process to PubSub updates for the given entity.
  Updates are broadcast as `{:historical_fetch_update, entity_type, entity_id, update}`.

  ## Examples

      iex> subscribe_to_historical_fetch(:character, 12345)
      :ok
  """
  @spec subscribe_to_historical_fetch(atom(), integer()) :: :ok
  def subscribe_to_historical_fetch(entity_type, entity_id)
      when entity_type in [:character, :corporation, :system, :alliance] and is_integer(entity_id) do
    Domain.HistoricalFetchWorker.subscribe(entity_type, entity_id)
  end

  def subscribe_to_historical_fetch(_, _), do: :ok

  @doc """
  Unsubscribe from historical fetch status updates for an entity.

  ## Examples

      iex> unsubscribe_from_historical_fetch(:character, 12345)
      :ok
  """
  @spec unsubscribe_from_historical_fetch(atom(), integer()) :: :ok
  def unsubscribe_from_historical_fetch(entity_type, entity_id)
      when entity_type in [:character, :corporation, :system, :alliance] and is_integer(entity_id) do
    Domain.HistoricalFetchWorker.unsubscribe(entity_type, entity_id)
  end

  def unsubscribe_from_historical_fetch(_, _), do: :ok

  @doc """
  Queue an entity for 2-year historical fetch (Phase 2).

  Creates or updates the historical fetch status and broadcasts the update.

  ## Examples

      iex> queue_extended_historical_fetch(:character, 12345)
      {:ok, %{status: :phase1_complete, ...}}
  """
  @spec queue_extended_historical_fetch(atom(), integer()) :: Result.t(map())
  def queue_extended_historical_fetch(entity_type, entity_id)
      when entity_type in [:character, :corporation, :system, :alliance] and is_integer(entity_id) do
    Domain.HistoricalFetchWorker.queue_fetch(entity_type, entity_id)
  end

  def queue_extended_historical_fetch(_, _), do: {:error, :invalid_entity}

  @doc """
  Mark Phase 1 complete and queue Phase 2 fetch.

  Called after initial 90-day data is loaded to queue 2-year fetch.

  ## Examples

      iex> complete_phase1_and_queue_phase2(:character, 12345)
      {:ok, %{status: :phase1_complete, ...}}
  """
  @spec complete_phase1_and_queue_phase2(atom(), integer()) :: Result.t(map())
  def complete_phase1_and_queue_phase2(entity_type, entity_id)
      when entity_type in [:character, :corporation, :system, :alliance] and is_integer(entity_id) do
    # Get or create the fetch status record
    case get_or_create_fetch_status(entity_type, entity_id) do
      {:ok, status} ->
        # Mark Phase 1 complete
        case Ash.update(status, %{}, action: :mark_phase1_complete, domain: EveDmv.Api) do
          {:ok, updated} ->
            # Queue for Phase 2 processing via the worker
            Domain.HistoricalFetchWorker.queue_fetch(entity_type, entity_id)
            {:ok, status_to_map(updated)}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def complete_phase1_and_queue_phase2(_, _), do: {:error, :invalid_entity}

  @doc """
  Check if the historical fetch worker is currently busy processing.
  """
  @spec historical_fetch_busy?() :: boolean()
  def historical_fetch_busy? do
    Domain.HistoricalFetchWorker.busy?()
  end

  # Private helpers for historical fetch

  defp get_or_create_fetch_status(entity_type, entity_id) do
    case HistoricalFetchStatus.get_by_entity(entity_type, entity_id) do
      {:ok, [status]} ->
        {:ok, status}

      {:ok, []} ->
        # Create new status
        Ash.create(
          HistoricalFetchStatus,
          %{entity_type: entity_type, entity_id: entity_id},
          action: :create,
          domain: EveDmv.Api
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp status_to_map(status) do
    %{
      id: status.id,
      entity_type: status.entity_type,
      entity_id: status.entity_id,
      status: status.status,
      phase1_completed_at: status.phase1_completed_at,
      phase2_started_at: status.phase2_started_at,
      phase2_completed_at: status.phase2_completed_at,
      oldest_killmail_date: status.oldest_killmail_date,
      target_date: status.target_date,
      killmails_fetched: status.killmails_fetched,
      current_page: status.current_page,
      last_error: status.last_error,
      retry_count: status.retry_count
    }
  end

  # Helper functions

  defp format_for_display(killmail) do
    %{
      id: killmail.killmail_id,
      killmail_time: killmail.killmail_time,
      solar_system_id: killmail.solar_system_id,
      victim: %{
        character_id: killmail.victim_character_id,
        corporation_id: killmail.victim_corporation_id,
        alliance_id: killmail.victim_alliance_id,
        ship_type_id: killmail.victim_ship_type_id
      },
      total_value: Map.get(killmail, :total_value, 0),
      participant_count: Map.get(killmail, :participant_count, 0),
      location: %{
        solar_system_id: killmail.solar_system_id,
        # Add region/constellation if available
        region_id: Map.get(killmail, :region_id),
        constellation_id: Map.get(killmail, :constellation_id)
      }
    }
  end
end
