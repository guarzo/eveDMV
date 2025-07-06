defmodule EveDmv.Contexts.KillmailProcessing.Api do
  @moduledoc """
  Public API for the Killmail Processing bounded context.

  This module defines the external interface that other contexts
  and the web layer can use to interact with killmail data.
  """

  alias EveDmv.Contexts.KillmailProcessing.Domain
  alias EveDmv.SharedKernel.ValueObjects.{CharacterId, SolarSystemId, TimeRange}
  alias EveDmv.Result

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
    with :ok <- validate_killmail_options(opts),
         {:ok, killmails} <- Domain.QueryService.get_recent_killmails(opts) do
      {:ok, killmails}
    end
  end

  @doc """
  Get a specific killmail by its ID.

  Returns both raw and enriched data if available.
  """
  @spec get_killmail_by_id(integer()) :: Result.t(map()) | Result.t(:not_found)
  def get_killmail_by_id(killmail_id) when is_integer(killmail_id) and killmail_id > 0 do
    Domain.QueryService.get_killmail_by_id(killmail_id)
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
    with {:ok, system_id_vo} <- SolarSystemId.new(system_id),
         :ok <- validate_killmail_options(opts),
         {:ok, killmails} <- Domain.QueryService.get_killmails_by_system(system_id_vo, opts) do
      {:ok, killmails}
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
    with {:ok, character_id_vo} <- CharacterId.new(character_id),
         :ok <- validate_killmail_options(opts),
         {:ok, killmails} <- Domain.QueryService.get_killmails_by_character(character_id_vo, opts) do
      {:ok, killmails}
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

    with :ok <- validate_killmail_options(opts_with_defaults),
         {:ok, killmails} <- Domain.QueryService.get_high_value_killmails(opts_with_defaults) do
      {:ok, killmails}
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
    with :ok <- validate_character_ids(character_ids),
         {:ok, task_info} <- Domain.HistoricalService.fetch_historical_data(character_ids, opts) do
      {:ok, task_info}
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
    with {:ok, system_id_vo} <- SolarSystemId.new(system_id),
         {:ok, stats} <- Domain.StatisticsService.get_system_statistics(system_id_vo, time_range) do
      {:ok, stats}
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
    with :ok <- validate_killmail_options(opts),
         {:ok, display_data} <- Domain.DisplayService.get_display_data(opts) do
      {:ok, display_data}
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
end
