defmodule EveDmv.Database.IncrementalViewRefresher do
  @moduledoc """
  Incremental materialized view refresh strategy for improved performance.

  Instead of fully refreshing materialized views, this module implements
  an incremental refresh approach that only updates changed data.
  """

  use GenServer

  alias Ecto.Adapters.SQL
  alias EveDmv.Core.Utils.DateTimeUtils

  require Logger

  @refresh_interval :timer.minutes(5)
  @incremental_views %{
    "character_activity_summary" => %{
      refresh_function: :refresh_character_activity,
      full_refresh_interval: :timer.hours(24),
      tracking_table: "view_refresh_tracking"
    },
    "recent_character_activity" => %{
      refresh_function: :refresh_recent_activity,
      full_refresh_interval: :timer.hours(1),
      tracking_table: "view_refresh_tracking"
    },
    "system_activity_heatmap" => %{
      refresh_function: :refresh_system_heatmap,
      full_refresh_interval: :timer.hours(6),
      tracking_table: "view_refresh_tracking"
    }
  }

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Manually trigger incremental refresh for a specific view.
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
    new_state = perform_incremental_refreshes(state)
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

  defp perform_incremental_refreshes(state) do
    Logger.info("Starting incremental view refreshes")
    start_time = System.monotonic_time(:millisecond)

    results =
      Enum.map(@incremental_views, fn {view_name, config} ->
        refresh_result = perform_view_refresh(view_name, config)
        {view_name, refresh_result}
      end)

    duration = System.monotonic_time(:millisecond) - start_time
    Logger.info("Completed incremental refreshes in #{duration}ms")

    %{
      state
      | last_refresh: Map.merge(state.last_refresh, Map.new(results)),
        refresh_stats: update_refresh_stats(state.refresh_stats, results)
    }
  end

  defp perform_view_refresh(view_name, config) do
    last_refresh = get_last_refresh_time(view_name)
    last_full_refresh = get_last_full_refresh_time(view_name)

    # Determine if we need a full refresh
    needs_full_refresh =
      case last_full_refresh do
        nil ->
          true

        timestamp ->
          time_since = DateTimeUtils.diff(DateTime.utc_now(), timestamp, :millisecond)
          time_since > config.full_refresh_interval
      end

    if needs_full_refresh do
      perform_full_refresh(view_name)
    else
      perform_incremental_refresh(view_name, config, last_refresh)
    end
  end

  defp perform_incremental_refresh(view_name, config, last_refresh) do
    Logger.info("Performing incremental refresh for #{view_name}")
    start_time = System.monotonic_time(:millisecond)

    try do
      # Call the appropriate refresh function
      refresh_function = config.refresh_function
      result = apply(__MODULE__, refresh_function, [last_refresh])

      duration = System.monotonic_time(:millisecond) - start_time

      # Update tracking
      update_refresh_tracking(view_name, "incremental", duration, result[:rows_updated] || 0)

      Logger.info("Incremental refresh of #{view_name} completed in #{duration}ms")
      {:ok, duration, result}
    rescue
      error ->
        Logger.error("Failed to refresh #{view_name}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp perform_full_refresh(view_name) do
    Logger.info("Performing full refresh for #{view_name}")
    start_time = System.monotonic_time(:millisecond)

    sql = "REFRESH MATERIALIZED VIEW CONCURRENTLY #{view_name}"

    case SQL.query(EveDmv.Repo, sql) do
      {:ok, result} ->
        duration = System.monotonic_time(:millisecond) - start_time
        rows = result.num_rows || 0

        update_refresh_tracking(view_name, "full", duration, rows)

        Logger.info("Full refresh of #{view_name} completed in #{duration}ms")
        {:ok, duration, %{rows_updated: rows}}

      {:error, error} ->
        Logger.error("Failed to fully refresh #{view_name}: #{inspect(error)}")
        {:error, error}
    end
  end

  # Specific refresh implementations

  def refresh_character_activity(last_refresh) do
    cutoff_time = last_refresh || DateTimeUtils.add(DateTime.utc_now(), -86_400, :second)

    sql = """
    WITH recent_kills AS (
    SELECT
        character_id,
        character_name,
        is_victim,
        killmail_time,
    total_value
      FROM participants p
      JOIN killmails_raw k ON p.killmail_id = k.killmail_id
      WHERE k.killmail_time > $1
    ),
    activity_delta AS (
    SELECT
        character_id,
        character_name,
        COUNT(*) FILTER (WHERE is_victim = false) as kills,
        COUNT(*) FILTER (WHERE is_victim = true) as losses,
        SUM(total_value) FILTER (WHERE is_victim = false) as isk_destroyed,
        SUM(total_value) FILTER (WHERE is_victim = true) as isk_lost,
        MAX(killmail_time) as last_activity
      FROM recent_kills
      GROUP BY character_id, character_name
    )
    INSERT INTO character_activity_summary
    SELECT * FROM activity_delta
    ON CONFLICT (character_id) DO UPDATE SET
      total_kills = character_activity_summary.total_kills + EXCLUDED.total_kills,
      total_losses = character_activity_summary.total_losses + EXCLUDED.total_losses,
      total_isk_destroyed = character_activity_summary.total_isk_destroyed + EXCLUDED.total_isk_destroyed,
      total_isk_lost = character_activity_summary.total_isk_lost + EXCLUDED.total_isk_lost,
      last_activity = GREATEST(character_activity_summary.last_activity, EXCLUDED.last_activity)
    """

    case SQL.query(EveDmv.Repo, sql, [cutoff_time]) do
      {:ok, result} ->
        %{rows_updated: result.num_rows || 0}

      {:error, error} ->
        raise error
    end
  end

  def refresh_recent_activity(_last_refresh) do
    # Recent activity is a smaller view, we can refresh it fully each time
    sql = """
    DELETE FROM recent_character_activity;

    INSERT INTO recent_character_activity
    SELECT
      p.character_id,
      p.character_name,
      COUNT(*) FILTER (WHERE p.is_victim = false) as kills_24h,
      COUNT(*) FILTER (WHERE p.is_victim = true) as losses_24h,
      SUM(k.total_value) as isk_involved_24h
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE k.killmail_time >= NOW() - INTERVAL '24 hours'
    GROUP BY p.character_id, p.character_name
    """

    case SQL.query(EveDmv.Repo, sql) do
      {:ok, result} ->
        %{rows_updated: result.num_rows || 0}

      {:error, error} ->
        raise error
    end
  end

  def refresh_system_heatmap(last_refresh) do
    # 7 days
    cutoff_time = last_refresh || DateTimeUtils.add(DateTime.utc_now(), -604_800, :second)

    sql = """
    WITH recent_activity AS (
    SELECT
        solar_system_id,
        DATE_TRUNC('hour', killmail_time) as hour,
        COUNT(*) as kill_count,
        SUM(total_value) as total_isk_destroyed,
        COUNT(DISTINCT victim_character_id) as unique_victims
      FROM killmails_raw
      WHERE killmail_time > $1
      GROUP BY solar_system_id, DATE_TRUNC('hour', killmail_time)
    )
    INSERT INTO system_activity_heatmap
    SELECT * FROM recent_activity
    ON CONFLICT (solar_system_id, hour) DO UPDATE SET
      kill_count = EXCLUDED.kill_count,
      total_isk_destroyed = EXCLUDED.total_isk_destroyed,
      unique_victims = EXCLUDED.unique_victims
    """

    case SQL.query(EveDmv.Repo, sql, [cutoff_time]) do
      {:ok, result} ->
        %{rows_updated: result.num_rows || 0}

      {:error, error} ->
        raise error
    end
  end

  # Helper functions

  defp get_last_refresh_time(view_name) do
    sql = """
    SELECT last_refresh_time
    FROM view_refresh_tracking
    WHERE view_name = $1
    """

    case SQL.query(EveDmv.Repo, sql, [view_name]) do
      {:ok, %{rows: [[timestamp]]}} when timestamp != nil -> timestamp
      _ -> nil
    end
  end

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
    case Map.get(@incremental_views, view_name) do
      nil ->
        {:error, :unknown_view}

      config ->
        if Keyword.get(opts, :full, false) do
          perform_full_refresh(view_name)
        else
          last_refresh = get_last_refresh_time(view_name)
          perform_incremental_refresh(view_name, config, last_refresh)
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
                configured: Map.has_key?(@incremental_views, name)
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
