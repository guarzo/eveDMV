defmodule EveDmv.Platform.Database.MaterializedViewOptimizer do
  @moduledoc """
  Manages and optimizes materialized views for performance.
  Provides incremental refresh strategies and automatic maintenance.

  Features:
  - Automatic refresh scheduling with GenServer
  - Incremental refresh strategies
  - Performance monitoring and optimization
  - Dependency management between views
  - Stale data detection
  """

  use GenServer
  alias EveDmv.Repo
  require Logger

  defstruct [
    :refresh_timers,
    :last_refresh,
    :refresh_stats,
    :active_refreshes
  ]

  @views [
    %{
      name: "character_activity_summary",
      refresh_interval: :timer.minutes(10),
      priority: :high,
      concurrent: true,
      dependencies: [],
      indexes: [
        {:character_id, :unique},
        {:last_activity, :btree},
        {:total_kills, :btree},
        {:activity_score, :btree}
      ]
    },
    %{
      name: "ship_type_usage",
      refresh_interval: :timer.minutes(30),
      priority: :medium,
      concurrent: true,
      dependencies: [],
      indexes: [
        {:ship_type_id, :unique},
        {:usage_count, :btree},
        {:last_used, :btree}
      ]
    },
    %{
      name: "system_activity_heatmap",
      refresh_interval: :timer.minutes(5),
      priority: :high,
      concurrent: true,
      dependencies: [],
      indexes: [
        {:solar_system_id, :btree},
        {:activity_timestamp, :btree},
        {[:solar_system_id, :activity_timestamp], :unique}
      ]
    },
    %{
      name: "fleet_composition_summary",
      refresh_interval: :timer.hours(1),
      priority: :low,
      concurrent: true,
      dependencies: ["killmails_raw"],
      indexes: [
        {[:day, :solar_system_id], :unique},
        {:day, :btree},
        {:solar_system_id, :btree}
      ]
    },
    %{
      name: "high_value_targets",
      refresh_interval: :timer.hours(6),
      priority: :low,
      concurrent: true,
      dependencies: ["killmails_raw"],
      indexes: [
        {:victim_character_id, :unique},
        {:total_loss_value, :btree},
        {:last_loss, :btree}
      ]
    },
    %{
      name: "timezone_activity_patterns",
      refresh_interval: :timer.hours(2),
      priority: :medium,
      concurrent: true,
      dependencies: ["killmails_raw"],
      indexes: [
        {[:hour_utc, :day_of_week], :unique},
        {:killmail_count, :btree}
      ]
    }
  ]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Optimize all materialized views
  """
  def optimize_all do
    GenServer.call(__MODULE__, :optimize_all, :timer.minutes(10))
  end

  @doc """
  Manually trigger refresh for a specific view
  """
  def refresh_view_async(view_name) do
    GenServer.cast(__MODULE__, {:refresh_view, view_name})
  end

  @doc """
  Get detailed performance statistics
  """
  def get_performance_analysis do
    GenServer.call(__MODULE__, :get_performance_analysis)
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(_opts) do
    state = %__MODULE__{
      refresh_timers: %{},
      last_refresh: %{},
      refresh_stats: %{},
      active_refreshes: MapSet.new()
    }

    # Schedule initial refresh tasks
    schedule_all_refreshes()

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:optimize_all, _from, state) do
    Logger.info("Starting materialized view optimization...")

    results =
      Enum.map(@views, fn view_config ->
        optimize_view(view_config)
      end)

    Logger.info("Materialized view optimization complete")
    {:reply, {:ok, results}, state}
  end

  @impl GenServer
  def handle_call(:get_performance_analysis, _from, state) do
    analysis = %{
      refresh_stats: get_refresh_stats(),
      view_sizes: get_view_sizes(),
      stale_views: detect_stale_views(),
      optimization_recommendations: generate_recommendations()
    }

    {:reply, {:ok, analysis}, state}
  end

  @impl GenServer
  def handle_cast({:refresh_view, view_name}, state) do
    if MapSet.member?(state.active_refreshes, view_name) do
      Logger.warning("View #{view_name} is already being refreshed")
      {:noreply, state}
    else
      new_state = %{state | active_refreshes: MapSet.put(state.active_refreshes, view_name)}

      Task.start(fn ->
        result = refresh_view(view_name)
        GenServer.cast(__MODULE__, {:refresh_complete, view_name, result})
      end)

      {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_cast({:refresh_complete, view_name, result}, state) do
    new_state = %{
      state
      | active_refreshes: MapSet.delete(state.active_refreshes, view_name),
        last_refresh: Map.put(state.last_refresh, view_name, DateTime.utc_now())
    }

    case result do
      :ok ->
        Logger.info("Successfully refreshed #{view_name}")

      {:error, reason} ->
        Logger.error("Failed to refresh #{view_name}: #{inspect(reason)}")
    end

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:scheduled_refresh, view_name}, state) do
    view_config = Enum.find(@views, fn v -> v.name == view_name end)

    if view_config do
      # Trigger refresh
      GenServer.cast(self(), {:refresh_view, view_name})

      # Reschedule
      timer_ref =
        Process.send_after(self(), {:scheduled_refresh, view_name}, view_config.refresh_interval)

      new_timers = Map.put(state.refresh_timers, view_name, timer_ref)
      {:noreply, %{state | refresh_timers: new_timers}}
    else
      {:noreply, state}
    end
  end

  ## Private Helper Functions

  defp schedule_all_refreshes do
    Enum.each(@views, fn view_config ->
      # Schedule first refresh with some initial delay to avoid thundering herd
      # Random delay up to 1 minute
      initial_delay = :rand.uniform(60_000)
      Process.send_after(self(), {:scheduled_refresh, view_config.name}, initial_delay)
    end)
  end

  @doc """
  Optimize a specific materialized view
  """
  def optimize_view(%{name: name} = config) do
    Logger.info("Optimizing materialized view: #{name}")

    with :ok <- ensure_indexes(name, config.indexes),
         :ok <- analyze_view(name),
         :ok <- setup_refresh_schedule(name, config.refresh_interval),
         :ok <- vacuum_view(name) do
      Logger.info("Successfully optimized #{name}")
      {:ok, name}
    else
      {:error, reason} ->
        Logger.error("Failed to optimize #{name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Refresh a materialized view
  """
  def refresh_view(name, opts \\ []) do
    concurrent = Keyword.get(opts, :concurrent, true)

    query =
      if concurrent do
        "REFRESH MATERIALIZED VIEW CONCURRENTLY #{name}"
      else
        "REFRESH MATERIALIZED VIEW #{name}"
      end

    Logger.info("Refreshing materialized view: #{name} (concurrent: #{concurrent})")

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, _} ->
        Logger.info("Successfully refreshed #{name}")
        update_refresh_tracking(name)
        :ok

      {:error, error} ->
        Logger.error("Failed to refresh #{name}: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Create or update a materialized view with optimizations
  """
  def create_optimized_view(name, query, opts \\ []) do
    indexes = Keyword.get(opts, :indexes, [])
    tablespace = Keyword.get(opts, :tablespace)
    storage_params = Keyword.get(opts, :storage_params, [])

    # Drop existing view if recreating
    if Keyword.get(opts, :replace, false) do
      drop_query = "DROP MATERIALIZED VIEW IF EXISTS #{name} CASCADE"
      Ecto.Adapters.SQL.query!(Repo, drop_query, [])
    end

    # Build CREATE MATERIALIZED VIEW statement
    create_query = build_create_query(name, query, tablespace, storage_params)

    case Ecto.Adapters.SQL.query(Repo, create_query, []) do
      {:ok, _} ->
        Logger.info("Created materialized view: #{name}")

        # Create indexes
        Enum.each(indexes, fn index_spec ->
          create_view_index(name, index_spec)
        end)

        # Analyze for statistics
        analyze_view(name)

        {:ok, name}

      {:error, error} ->
        Logger.error("Failed to create materialized view #{name}: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Get refresh statistics for all materialized views
  """
  def get_refresh_stats do
    query = """
    SELECT 
      v.matviewname as view_name,
      v.ispopulated as is_populated,
      r.last_refresh,
      r.refresh_duration_ms,
      r.row_count,
      pg_size_pretty(pg_relation_size(c.oid)) as size
    FROM pg_matviews v
    LEFT JOIN view_refresh_tracking r ON v.matviewname = r.view_name
    JOIN pg_class c ON c.relname = v.matviewname
    WHERE v.schemaname = 'public'
    ORDER BY v.matviewname
    """

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, result} ->
        Enum.map(result.rows, fn [name, populated, last_refresh, duration, rows, size] ->
          %{
            name: name,
            populated: populated,
            last_refresh: last_refresh,
            refresh_duration_ms: duration,
            row_count: rows,
            size: size
          }
        end)

      {:error, _} ->
        []
    end
  end

  @doc """
  Get view sizes and statistics
  """
  def get_view_sizes do
    query = """
    SELECT 
      matviewname,
      pg_size_pretty(pg_relation_size(matviewname::regclass)) as size,
      pg_relation_size(matviewname::regclass) as size_bytes
    FROM pg_matviews
    WHERE schemaname = 'public'
    ORDER BY pg_relation_size(matviewname::regclass) DESC
    """

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, result} ->
        Enum.map(result.rows, fn [name, size_pretty, size_bytes] ->
          %{
            name: name,
            size_pretty: size_pretty,
            size_bytes: size_bytes
          }
        end)

      {:error, _} ->
        []
    end
  end

  @doc """
  Detect stale materialized views
  """
  def detect_stale_views do
    query = """
    SELECT 
      view_name,
      last_refresh,
      NOW() - last_refresh as staleness
    FROM view_refresh_tracking
    WHERE last_refresh < NOW() - INTERVAL '24 hours'
    ORDER BY last_refresh ASC
    """

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, result} ->
        Enum.map(result.rows, fn [name, last_refresh, staleness] ->
          %{
            name: name,
            last_refresh: last_refresh,
            staleness: format_interval(staleness)
          }
        end)

      {:error, _} ->
        []
    end
  end

  @doc """
  Generate optimization recommendations
  """
  def generate_recommendations do
    # Check for missing indexes
    missing_indexes = check_missing_indexes()

    index_recommendations =
      if Enum.empty?(missing_indexes) do
        []
      else
        ["Missing indexes on views: #{Enum.join(missing_indexes, ", ")}"]
      end

    # Check for oversized views
    oversized = check_oversized_views()

    size_recommendations =
      if Enum.empty?(oversized) do
        index_recommendations
      else
        ["Oversized views (>1GB): #{Enum.join(oversized, ", ")}" | index_recommendations]
      end

    # Check refresh frequency
    stale = detect_stale_views()

    if Enum.empty?(stale) do
      size_recommendations
    else
      stale_names = Enum.map(stale, & &1.name)
      ["Stale views needing refresh: #{Enum.join(stale_names, ", ")}" | size_recommendations]
    end
  end

  defp check_missing_indexes do
    query = """
    SELECT v.matviewname
    FROM pg_matviews v
    LEFT JOIN pg_indexes i ON i.tablename = v.matviewname
    WHERE v.schemaname = 'public'
    GROUP BY v.matviewname
    HAVING COUNT(i.indexname) = 0
    """

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, result} ->
        Enum.map(result.rows, fn [name] -> name end)

      {:error, _} ->
        []
    end
  end

  defp check_oversized_views do
    query = """
    SELECT matviewname
    FROM pg_matviews
    WHERE pg_relation_size(matviewname::regclass) > 1073741824 -- 1GB
    """

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, result} ->
        Enum.map(result.rows, fn [name] -> name end)

      {:error, _} ->
        []
    end
  end

  defp format_interval(interval) when is_binary(interval), do: interval
  defp format_interval(interval), do: "#{interval}"

  @doc """
  Setup automatic refresh schedule using pg_cron
  """
  def setup_refresh_schedule(view_name, interval) do
    # Convert new interval format to cron schedule
    schedule =
      cond do
        is_integer(interval) ->
          minutes = div(interval, 60_000)

          cond do
            minutes <= 60 -> "*/#{minutes} * * * *"
            minutes <= 1440 -> "0 */#{div(minutes, 60)} * * *"
            true -> "0 2 * * *"
          end

        interval == :hourly ->
          "0 * * * *"

        interval == :daily ->
          "0 2 * * *"

        interval == :weekly ->
          "0 2 * * 0"

        true ->
          nil
      end

    if schedule do
      job_name = "refresh_#{view_name}"

      # Remove existing job if it exists
      remove_query = "SELECT cron.unschedule($1)"
      Ecto.Adapters.SQL.query(Repo, remove_query, [job_name])

      # Create new job
      create_query = """
      SELECT cron.schedule($1, $2, $3)
      """

      refresh_command = "REFRESH MATERIALIZED VIEW CONCURRENTLY #{view_name}"

      case Ecto.Adapters.SQL.query(Repo, create_query, [job_name, schedule, refresh_command]) do
        {:ok, _} ->
          Logger.info("Scheduled automatic refresh for #{view_name}: #{schedule}")
          :ok

        {:error, %{postgres: %{code: :undefined_function}}} ->
          Logger.warning(
            "pg_cron not available, skipping automatic refresh setup for #{view_name}"
          )

          :ok

        {:error, error} ->
          Logger.error("Failed to schedule refresh for #{view_name}: #{inspect(error)}")
          {:error, error}
      end
    else
      :ok
    end
  end

  # Private functions

  defp ensure_indexes(view_name, index_specs) do
    Enum.each(index_specs, fn spec ->
      create_view_index(view_name, spec)
    end)

    :ok
  end

  defp create_view_index(view_name, {columns, type}) when is_list(columns) do
    column_list = Enum.join(columns, ", ")
    index_name = "#{view_name}_#{Enum.join(columns, "_")}_idx"
    create_index(view_name, index_name, column_list, type)
  end

  defp create_view_index(view_name, {column, type}) do
    index_name = "#{view_name}_#{column}_idx"
    create_index(view_name, index_name, to_string(column), type)
  end

  defp create_index(view_name, index_name, columns, type) do
    type_clause =
      case type do
        :unique -> "UNIQUE"
        :gin -> "USING gin"
        :gist -> "USING gist"
        _ -> ""
      end

    query =
      "CREATE INDEX CONCURRENTLY IF NOT EXISTS #{index_name} ON #{view_name} #{type_clause} (#{columns})"

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, _} ->
        Logger.debug("Created index #{index_name} on #{view_name}")
        :ok

      {:error, %{postgres: %{code: :duplicate_table}}} ->
        Logger.debug("Index #{index_name} already exists")
        :ok

      {:error, error} ->
        Logger.error("Failed to create index #{index_name}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp analyze_view(view_name) do
    query = "ANALYZE #{view_name}"

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, _} ->
        Logger.debug("Analyzed #{view_name}")
        :ok

      {:error, error} ->
        Logger.error("Failed to analyze #{view_name}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp vacuum_view(view_name) do
    query = "VACUUM ANALYZE #{view_name}"

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, _} ->
        Logger.debug("Vacuumed #{view_name}")
        :ok

      {:error, error} ->
        Logger.error("Failed to vacuum #{view_name}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp update_refresh_tracking(view_name) do
    # Update or insert refresh tracking record
    query = """
    INSERT INTO view_refresh_tracking (view_name, last_refresh, row_count)
    SELECT $1, NOW(), COUNT(*) FROM #{view_name}
    ON CONFLICT (view_name) 
    DO UPDATE SET 
      last_refresh = NOW(),
      row_count = (SELECT COUNT(*) FROM #{view_name}),
      refresh_count = view_refresh_tracking.refresh_count + 1
    """

    Ecto.Adapters.SQL.query(Repo, query, [view_name])
    :ok
  rescue
    # Table might not exist
    _ -> :ok
  end

  defp build_create_query(name, query, tablespace, storage_params) do
    base_query = "CREATE MATERIALIZED VIEW #{name}"

    storage_clause =
      if Enum.empty?(storage_params) do
        ""
      else
        params = Enum.map_join(storage_params, ", ", fn {k, v} -> "#{k}=#{v}" end)
        " WITH (#{params})"
      end

    tablespace_clause =
      if tablespace do
        " TABLESPACE #{tablespace}"
      else
        ""
      end

    "#{base_query}#{storage_clause}#{tablespace_clause} AS #{query}"
  end
end
