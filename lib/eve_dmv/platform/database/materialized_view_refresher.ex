defmodule EveDmv.Platform.Database.MaterializedViewRefresher do
  @moduledoc """
  Scheduled materialized view refresh manager.

  Manages periodic full refreshes of materialized views with configurable
  intervals. Uses REFRESH MATERIALIZED VIEW CONCURRENTLY to avoid blocking
  reads during refresh.

  Note: PostgreSQL materialized views only support full refresh; there is no
  incremental refresh option. This module schedules and executes those full
  refreshes based on configurable time intervals.
  """

  use GenServer

  alias Ecto.Adapters.SQL
  alias EveDmv.Core.Utils.DateTimeUtils

  require Logger

  @refresh_interval :timer.minutes(5)
  # Materialized views can only be fully refreshed - there is no incremental option.
  # The full_refresh_interval determines the minimum time between refreshes.
  @materialized_views %{
    "character_activity_summary" => %{
      full_refresh_interval: :timer.hours(24),
      tracking_table: "view_refresh_tracking"
    },
    "system_activity_heatmap" => %{
      full_refresh_interval: :timer.hours(6),
      tracking_table: "view_refresh_tracking"
    }
  }

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Manually trigger refresh for a specific view.
  """
  def refresh_view(view_name, opts \\ []) do
    GenServer.call(__MODULE__, {:refresh_view, view_name, opts}, :timer.minutes(10))
  end

  @doc """
  Get refresh status for all managed views.
  """
  def get_refresh_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Force full refresh of a specific view.
  """
  def force_full_refresh(view_name) do
    GenServer.call(__MODULE__, {:full_refresh, view_name}, :timer.minutes(30))
  end

  # Server callbacks

  @impl GenServer
  def init(opts) do
    state = %{
      enabled: Keyword.get(opts, :enabled, true),
      refresh_interval: Keyword.get(opts, :refresh_interval, @refresh_interval),
      last_refresh: %{},
      refresh_stats: %{}
    }

    if state.enabled do
      # Ensure tracking table exists
      ensure_tracking_table()

      # Schedule first refresh
      schedule_refresh(state.refresh_interval)
    end

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:refresh_views, state) do
    new_state = perform_scheduled_refreshes(state)
    schedule_refresh(state.refresh_interval)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call({:refresh_view, view_name, opts}, _from, state) do
    result = refresh_single_view(view_name, opts)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:get_status, _from, state) do
    status = compile_refresh_status(state)
    {:reply, status, state}
  end

  @impl GenServer
  def handle_call({:full_refresh, view_name}, _from, state) do
    result = perform_full_refresh(view_name)
    {:reply, result, state}
  end

  # Private functions

  defp ensure_tracking_table do
    sql = """
    CREATE TABLE IF NOT EXISTS view_refresh_tracking (
      view_name TEXT PRIMARY KEY,
      last_refresh_time TIMESTAMP WITH TIME ZONE,
      last_full_refresh_time TIMESTAMP WITH TIME ZONE,
      refresh_duration_ms INTEGER,
      rows_updated INTEGER,
      refresh_type TEXT
    )
    """

    case SQL.query(EveDmv.Repo, sql) do
      {:ok, _} -> :ok
      {:error, error} -> Logger.error("Failed to create tracking table: #{inspect(error)}")
    end
  end

  defp perform_scheduled_refreshes(state) do
    Logger.info("Starting scheduled materialized view refreshes")
    start_time = System.monotonic_time(:millisecond)

    results =
      Enum.map(@materialized_views, fn {view_name, config} ->
        refresh_result = perform_view_refresh(view_name, config)
        {view_name, refresh_result}
      end)

    duration = System.monotonic_time(:millisecond) - start_time
    Logger.info("Completed scheduled refreshes in #{duration}ms")

    %{
      state
      | last_refresh: Map.merge(state.last_refresh, Map.new(results)),
        refresh_stats: update_refresh_stats(state.refresh_stats, results)
    }
  end

  defp perform_view_refresh(view_name, config) do
    last_full_refresh = get_last_full_refresh_time(view_name)

    # Determine if enough time has passed to warrant a refresh
    # For materialized views, we always do full refresh (the only option)
    # This check just determines WHEN to refresh, not HOW
    should_refresh =
      case last_full_refresh do
        nil ->
          true

        timestamp ->
          time_since = DateTimeUtils.diff(DateTime.utc_now(), timestamp, :millisecond)
          time_since > config.full_refresh_interval
      end

    if should_refresh do
      # Materialized views can only be fully refreshed - there is no incremental option
      perform_full_refresh(view_name)
    else
      Logger.debug("Skipping refresh of #{view_name} - recently refreshed")
      {:ok, 0, %{rows_updated: 0, skipped: true}}
    end
  end

  defp perform_full_refresh(view_name) do
    # Validate view_name against whitelist to prevent SQL injection
    unless Map.has_key?(@materialized_views, view_name) do
      raise ArgumentError,
            "Unknown materialized view: #{inspect(view_name)}. " <>
              "Only configured views are allowed: #{inspect(Map.keys(@materialized_views))}"
    end

    Logger.info("Performing full refresh for #{view_name}")
    start_time = System.monotonic_time(:millisecond)

    # Use a transaction with increased work_mem to avoid disk spills during sort
    # The character_activity_summary view requires ~9MB for sorting, default is 4MB
    result =
      EveDmv.Repo.transaction(fn ->
        SQL.query!(EveDmv.Repo, "SET LOCAL work_mem = '32MB'")
        SQL.query!(EveDmv.Repo, "REFRESH MATERIALIZED VIEW CONCURRENTLY #{view_name}")
      end)

    case result do
      {:ok, _query_result} ->
        duration = System.monotonic_time(:millisecond) - start_time

        # Note: REFRESH MATERIALIZED VIEW doesn't return a meaningful row count
        update_refresh_tracking(view_name, "full", duration, 0)

        Logger.info("Full refresh of #{view_name} completed in #{duration}ms")
        {:ok, duration, %{rows_updated: 0}}

      {:error, error} ->
        Logger.error("Failed to fully refresh #{view_name}: #{inspect(error)}")
        {:error, error}
    end
  end

  # Helper functions

  defp get_last_full_refresh_time(view_name) do
    sql = """
    SELECT last_full_refresh_time
    FROM view_refresh_tracking
    WHERE view_name = $1
    """

    case SQL.query(EveDmv.Repo, sql, [view_name]) do
      {:ok, %{rows: [[timestamp]]}} when timestamp != nil -> timestamp
      _ -> nil
    end
  end

  defp update_refresh_tracking(view_name, refresh_type, duration_ms, rows_updated) do
    now = DateTime.utc_now()

    sql =
      if refresh_type == "full" do
        """
        INSERT INTO view_refresh_tracking
        (view_name, last_refresh_time, last_full_refresh_time, refresh_duration_ms, rows_updated, refresh_type)
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT (view_name) DO UPDATE SET
          last_refresh_time = EXCLUDED.last_refresh_time,
          last_full_refresh_time = EXCLUDED.last_full_refresh_time,
          refresh_duration_ms = EXCLUDED.refresh_duration_ms,
          rows_updated = EXCLUDED.rows_updated,
          refresh_type = EXCLUDED.refresh_type
        """
      else
        """
        INSERT INTO view_refresh_tracking
        (view_name, last_refresh_time, refresh_duration_ms, rows_updated, refresh_type)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (view_name) DO UPDATE SET
          last_refresh_time = EXCLUDED.last_refresh_time,
          refresh_duration_ms = EXCLUDED.refresh_duration_ms,
          rows_updated = EXCLUDED.rows_updated,
          refresh_type = EXCLUDED.refresh_type
        """
      end

    params =
      if refresh_type == "full" do
        [view_name, now, now, duration_ms, rows_updated, refresh_type]
      else
        [view_name, now, duration_ms, rows_updated, refresh_type]
      end

    SQL.query(EveDmv.Repo, sql, params)
  end

  defp refresh_single_view(view_name, opts) do
    case Map.get(@materialized_views, view_name) do
      nil ->
        {:error, :unknown_view}

      config ->
        if Keyword.get(opts, :full, false) do
          perform_full_refresh(view_name)
        else
          # Performs a full refresh if enough time has elapsed, otherwise skips.
          # Note: PostgreSQL materialized views only support full refresh;
          # there is no incremental refresh option available.
          perform_view_refresh(view_name, config)
        end
    end
  end

  defp compile_refresh_status(state) do
    sql = """
    SELECT
      view_name,
      last_refresh_time,
      last_full_refresh_time,
      refresh_duration_ms,
      rows_updated,
    refresh_type
    FROM view_refresh_tracking
    ORDER BY view_name
    """

    case SQL.query(EveDmv.Repo, sql) do
      {:ok, %{rows: rows}} ->
        %{
          views:
            Enum.map(rows, fn [name, last, last_full, duration, rows, type] ->
              %{
                view_name: name,
                last_refresh: last,
                last_full_refresh: last_full,
                last_duration_ms: duration,
                last_rows_updated: rows,
                last_refresh_type: type,
                configured: Map.has_key?(@materialized_views, name)
              }
            end),
          last_run: state.last_refresh,
          stats: state.refresh_stats
        }

      {:error, _} ->
        %{views: [], last_run: nil, stats: %{}}
    end
  end

  defp update_refresh_stats(stats, results) do
    Enum.reduce(results, stats, fn {view_name, result}, acc ->
      case result do
        {:ok, duration, _} ->
          view_stats = Map.get(acc, view_name, %{total_refreshes: 0, total_duration: 0})

          Map.put(acc, view_name, %{
            total_refreshes: view_stats.total_refreshes + 1,
            total_duration: view_stats.total_duration + duration,
            avg_duration:
              (view_stats.total_duration + duration) / (view_stats.total_refreshes + 1)
          })

        _ ->
          acc
      end
    end)
  end

  defp schedule_refresh(interval) do
    Process.send_after(self(), :refresh_views, interval)
  end
end
