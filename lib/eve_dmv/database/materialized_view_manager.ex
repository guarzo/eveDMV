defmodule EveDmv.Database.MaterializedViewManager do
  @moduledoc """
  Manages materialized views for performance optimization.

  Creates and maintains materialized views for frequently accessed aggregated data,
  automatically refreshing them based on data changes and schedules.
  """

  use GenServer
  require Logger

  alias EveDmv.Database.CacheInvalidator
  alias EveDmv.Repo

  @refresh_interval :timer.hours(4)
  @incremental_refresh_interval :timer.minutes(30)

  # Materialized view definitions
  @materialized_views [
    %{
      name: "character_activity_summary",
      query: """
      SELECT 
        character_id,
        character_name,
        COUNT(*) as total_killmails,
        COUNT(*) FILTER (WHERE NOT is_victim) as kills,
        COUNT(*) FILTER (WHERE is_victim) as losses,
        MAX(updated_at) as last_activity,
        MIN(updated_at) as first_activity,
        COUNT(DISTINCT DATE_TRUNC('month', updated_at)) as active_months,
        COUNT(DISTINCT alliance_id) as alliance_count,
        COUNT(DISTINCT corporation_id) as corp_count,
        COUNT(DISTINCT solar_system_id) as system_count
      FROM participants 
      WHERE updated_at >= NOW() - INTERVAL '1 year'
      GROUP BY character_id, character_name
      HAVING COUNT(*) >= 5
      """,
      indexes: [
        "CREATE INDEX IF NOT EXISTS idx_character_activity_character_id ON character_activity_summary (character_id)",
        "CREATE INDEX IF NOT EXISTS idx_character_activity_last_activity ON character_activity_summary (last_activity DESC)",
        "CREATE INDEX IF NOT EXISTS idx_character_activity_kills ON character_activity_summary (kills DESC)"
      ],
      refresh_strategy: :full,
      dependencies: ["participants"]
    },
    %{
      name: "system_activity_summary",
      query: """
      SELECT 
        ke.solar_system_id,
        ss.system_name,
        COUNT(*) as total_killmails,
        SUM(ke.total_value) as total_value_destroyed,
        AVG(ke.total_value) as avg_killmail_value,
        COUNT(DISTINCT p.character_id) as unique_characters,
        COUNT(DISTINCT p.alliance_id) as unique_alliances,
        COUNT(DISTINCT DATE_TRUNC('day', ke.killmail_time)) as active_days,
        MAX(ke.killmail_time) as last_activity,
        COUNT(*) FILTER (WHERE ke.total_value > #{EveDmv.Constants.Isk.billion()}) as expensive_kills
      FROM killmails_enriched ke
      JOIN participants p ON ke.killmail_id = p.killmail_id
      LEFT JOIN solar_systems ss ON ke.solar_system_id = ss.system_id
      WHERE ke.killmail_time >= NOW() - INTERVAL '6 months'
      GROUP BY ke.solar_system_id, ss.system_name
      HAVING COUNT(*) >= 10
      """,
      indexes: [
        "CREATE INDEX IF NOT EXISTS idx_system_activity_system_id ON system_activity_summary (solar_system_id)",
        "CREATE INDEX IF NOT EXISTS idx_system_activity_last_activity ON system_activity_summary (last_activity DESC)",
        "CREATE INDEX IF NOT EXISTS idx_system_activity_total_value ON system_activity_summary (total_value_destroyed DESC)"
      ],
      refresh_strategy: :full,
      dependencies: ["killmails_enriched", "participants", "solar_systems"]
    },
    %{
      name: "alliance_statistics",
      query: """
      SELECT 
        p.alliance_id,
        p.alliance_name,
        COUNT(*) as total_killmails,
        COUNT(*) FILTER (WHERE NOT p.is_victim) as kills,
        COUNT(*) FILTER (WHERE p.is_victim) as losses,
        SUM(CASE WHEN NOT p.is_victim THEN ke.total_value ELSE 0 END) as value_destroyed,
        SUM(CASE WHEN p.is_victim THEN ke.total_value ELSE 0 END) as value_lost,
        COUNT(DISTINCT p.character_id) as member_count,
        COUNT(DISTINCT p.corporation_id) as corp_count,
        COUNT(DISTINCT ke.solar_system_id) as system_count,
        MAX(ke.killmail_time) as last_activity,
        COUNT(DISTINCT DATE_TRUNC('month', ke.killmail_time)) as active_months
      FROM participants p
      JOIN killmails_enriched ke ON p.killmail_id = ke.killmail_id
      WHERE p.alliance_id IS NOT NULL
      AND ke.killmail_time >= NOW() - INTERVAL '1 year'
      GROUP BY p.alliance_id, p.alliance_name
      HAVING COUNT(*) >= 20
      """,
      indexes: [
        "CREATE INDEX IF NOT EXISTS idx_alliance_stats_alliance_id ON alliance_statistics (alliance_id)",
        "CREATE INDEX IF NOT EXISTS idx_alliance_stats_last_activity ON alliance_statistics (last_activity DESC)",
        "CREATE INDEX IF NOT EXISTS idx_alliance_stats_member_count ON alliance_statistics (member_count DESC)"
      ],
      refresh_strategy: :full,
      dependencies: ["participants", "killmails_enriched"]
    },
    %{
      name: "daily_killmail_summary",
      query: """
      SELECT 
        DATE_TRUNC('day', killmail_time) as activity_date,
        COUNT(*) as total_killmails,
        SUM(total_value) as total_value_destroyed,
        AVG(total_value) as avg_killmail_value,
        COUNT(DISTINCT solar_system_id) as systems_active,
        COUNT(*) FILTER (WHERE total_value > #{EveDmv.Constants.Isk.billion()}) as expensive_kills,
        COUNT(*) FILTER (WHERE total_value > #{EveDmv.Constants.Isk.billion() * 10}) as super_expensive_kills
      FROM killmails_enriched
      WHERE killmail_time >= NOW() - INTERVAL '3 months'
      GROUP BY DATE_TRUNC('day', killmail_time)
      """,
      indexes: [
        "CREATE INDEX IF NOT EXISTS idx_daily_summary_date ON daily_killmail_summary (activity_date DESC)"
      ],
      refresh_strategy: :incremental,
      dependencies: ["killmails_enriched"]
    },
    %{
      name: "top_hunters_summary",
      query: """
      SELECT 
        p.character_id,
        p.character_name,
        COUNT(*) as kill_count,
        SUM(ke.total_value) as total_value_destroyed,
        AVG(ke.total_value) as avg_kill_value,
        COUNT(*) FILTER (WHERE p.final_blow) as final_blows,
        COUNT(DISTINCT ke.solar_system_id) as hunting_systems,
        COUNT(DISTINCT p.ship_type_id) as ships_used,
        MAX(ke.killmail_time) as last_kill,
        RANK() OVER (ORDER BY COUNT(*) DESC) as kill_rank,
        RANK() OVER (ORDER BY SUM(ke.total_value) DESC) as value_rank
      FROM participants p
      JOIN killmails_enriched ke ON p.killmail_id = ke.killmail_id
      WHERE NOT p.is_victim 
      AND ke.killmail_time >= NOW() - INTERVAL '6 months'
      GROUP BY p.character_id, p.character_name
      HAVING COUNT(*) >= 10
      """,
      indexes: [
        "CREATE INDEX IF NOT EXISTS idx_top_hunters_character_id ON top_hunters_summary (character_id)",
        "CREATE INDEX IF NOT EXISTS idx_top_hunters_kill_rank ON top_hunters_summary (kill_rank)",
        "CREATE INDEX IF NOT EXISTS idx_top_hunters_value_rank ON top_hunters_summary (value_rank)"
      ],
      refresh_strategy: :full,
      dependencies: ["participants", "killmails_enriched"]
    }
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def refresh_view(view_name) when is_binary(view_name) do
    GenServer.cast(__MODULE__, {:refresh_view, view_name})
  end

  def refresh_all_views do
    GenServer.cast(__MODULE__, :refresh_all_views)
  end

  def get_view_status do
    GenServer.call(__MODULE__, :get_view_status)
  end

  def create_view(view_name) when is_binary(view_name) do
    GenServer.call(__MODULE__, {:create_view, view_name})
  end

  def drop_view(view_name) when is_binary(view_name) do
    GenServer.call(__MODULE__, {:drop_view, view_name})
  end

  def get_view_data(view_name, limit \\ 100) when is_binary(view_name) do
    GenServer.call(__MODULE__, {:get_view_data, view_name, limit})
  end

  # Server callbacks

  def init(opts) do
    state = %{
      enabled: Keyword.get(opts, :enabled, true),
      views: %{},
      last_refresh: nil,
      refresh_stats: %{
        total_refreshes: 0,
        failed_refreshes: 0,
        avg_refresh_time_ms: 0
      }
    }

    if state.enabled do
      # Subscribe to cache invalidation events
      CacheInvalidator.subscribe_to_invalidations()

      # Schedule initial setup
      Process.send_after(self(), :initialize_views, :timer.seconds(30))
      schedule_refresh()
      schedule_incremental_refresh()
    end

    {:ok, state}
  end

  def handle_call({:create_view, view_name}, _from, state) do
    result = create_materialized_view(view_name)
    {:reply, result, state}
  end

  def handle_call({:drop_view, view_name}, _from, state) do
    result = drop_materialized_view(view_name)
    {:reply, result, state}
  end

  def handle_call(:get_view_status, _from, state) do
    status = get_current_view_status(state)
    {:reply, status, state}
  end

  def handle_call({:get_view_data, view_name, limit}, _from, state) do
    result = query_materialized_view(view_name, limit)
    {:reply, result, state}
  end

  def handle_cast({:refresh_view, view_name}, state) do
    new_state = perform_view_refresh(view_name, state)
    {:noreply, new_state}
  end

  def handle_cast(:refresh_all_views, state) do
    new_state = refresh_all_materialized_views(state)
    {:noreply, new_state}
  end

  def handle_info(:initialize_views, state) do
    new_state = initialize_all_views(state)
    {:noreply, new_state}
  end

  def handle_info(:scheduled_refresh, state) do
    new_state = refresh_all_materialized_views(state)
    schedule_refresh()
    {:noreply, new_state}
  end

  def handle_info(:incremental_refresh, state) do
    new_state = perform_incremental_refreshes(state)
    schedule_incremental_refresh()
    {:noreply, new_state}
  end

  def handle_info({:cache_invalidated, pattern, _count}, state) do
    # Check if any materialized views depend on invalidated data
    affected_views = find_affected_views(pattern)
    new_state = refresh_affected_views(affected_views, state)
    {:noreply, new_state}
  end

  def handle_info(_, state), do: {:noreply, state}

  # Private functions

  defp schedule_refresh do
    Process.send_after(self(), :scheduled_refresh, @refresh_interval)
  end

  defp schedule_incremental_refresh do
    Process.send_after(self(), :incremental_refresh, @incremental_refresh_interval)
  end

  defp initialize_all_views(state) do
    Logger.info("Initializing materialized views")

    views_status =
      Enum.reduce(@materialized_views, %{}, fn view_def, acc ->
        view_name = view_def.name

        case ensure_view_exists(view_def) do
          {:ok, status} ->
            Map.put(acc, view_name, status)

          {:error, error} ->
            Logger.error("Failed to initialize view #{view_name}: #{inspect(error)}")
            Map.put(acc, view_name, %{status: :error, error: inspect(error)})
        end
      end)

    %{state | views: views_status, last_refresh: DateTime.utc_now()}
  end

  defp ensure_view_exists(view_def) do
    view_name = view_def.name

    # Check if view already exists
    if materialized_view_exists?(view_name) do
      {:ok, %{status: :exists, last_refresh: nil}}
    else
      # Create the view
      case create_materialized_view(view_def) do
        {:ok, _} ->
          # Create indexes
          create_view_indexes(view_def.indexes)
          {:ok, %{status: :created, last_refresh: DateTime.utc_now()}}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp materialized_view_exists?(view_name) do
    query = """
    SELECT EXISTS (
      SELECT 1 FROM pg_matviews 
      WHERE schemaname = 'public' 
      AND matviewname = $1
    )
    """

    case Ecto.Adapters.SQL.query(Repo, query, [view_name]) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end

  defp create_materialized_view(view_def) when is_map(view_def) do
    sql = "CREATE MATERIALIZED VIEW #{view_def.name} AS #{view_def.query}"

    case Ecto.Adapters.SQL.query(Repo, sql, []) do
      {:ok, _} ->
        Logger.info("Created materialized view: #{view_def.name}")
        {:ok, view_def.name}

      {:error, error} ->
        Logger.error("Failed to create materialized view #{view_def.name}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp create_materialized_view(view_name) when is_binary(view_name) do
    view_def = Enum.find(@materialized_views, &(&1.name == view_name))

    if view_def do
      create_materialized_view(view_def)
    else
      {:error, "Unknown view: #{view_name}"}
    end
  end

  defp create_view_indexes(indexes) when is_list(indexes) do
    Enum.each(indexes, fn index_sql ->
      case Ecto.Adapters.SQL.query(Repo, index_sql, []) do
        {:ok, _} ->
          :ok

        {:error, error} ->
          Logger.warning("Failed to create index: #{inspect(error)}")
      end
    end)
  end

  defp drop_materialized_view(view_name) do
    sql = "DROP MATERIALIZED VIEW IF EXISTS #{view_name}"

    case Ecto.Adapters.SQL.query(Repo, sql, []) do
      {:ok, _} ->
        Logger.info("Dropped materialized view: #{view_name}")
        {:ok, view_name}

      {:error, error} ->
        Logger.error("Failed to drop materialized view #{view_name}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp refresh_all_materialized_views(state) do
    Logger.info("Starting refresh of all materialized views")
    start_time = System.monotonic_time(:millisecond)

    refreshed_views =
      Enum.reduce(@materialized_views, %{}, fn view_def, acc ->
        view_name = view_def.name

        case refresh_materialized_view(view_def) do
          {:ok, refresh_time_ms} ->
            Map.put(acc, view_name, %{
              status: :refreshed,
              last_refresh: DateTime.utc_now(),
              refresh_time_ms: refresh_time_ms
            })

          {:error, error} ->
            Logger.error("Failed to refresh view #{view_name}: #{inspect(error)}")

            Map.put(acc, view_name, %{
              status: :error,
              error: inspect(error),
              last_refresh: nil
            })
        end
      end)

    total_time_ms = System.monotonic_time(:millisecond) - start_time

    successful_refreshes =
      Enum.count(refreshed_views, fn {_, status} -> status.status == :refreshed end)

    Logger.info(
      "Materialized view refresh completed in #{total_time_ms}ms - #{successful_refreshes}/#{length(@materialized_views)} successful"
    )

    new_stats =
      update_refresh_stats(
        state.refresh_stats,
        total_time_ms,
        successful_refreshes,
        length(@materialized_views)
      )

    %{
      state
      | views: Map.merge(state.views, refreshed_views),
        last_refresh: DateTime.utc_now(),
        refresh_stats: new_stats
    }
  end

  defp refresh_materialized_view(view_def) do
    view_name = view_def.name
    start_time = System.monotonic_time(:millisecond)

    sql =
      case view_def.refresh_strategy do
        :concurrent -> "REFRESH MATERIALIZED VIEW CONCURRENTLY #{view_name}"
        _ -> "REFRESH MATERIALIZED VIEW #{view_name}"
      end

    case Ecto.Adapters.SQL.query(Repo, sql, [], timeout: :timer.minutes(10)) do
      {:ok, _} ->
        refresh_time_ms = System.monotonic_time(:millisecond) - start_time
        Logger.debug("Refreshed materialized view #{view_name} in #{refresh_time_ms}ms")
        {:ok, refresh_time_ms}

      {:error, error} ->
        {:error, error}
    end
  end

  defp perform_view_refresh(view_name, state) do
    view_def = Enum.find(@materialized_views, &(&1.name == view_name))

    if view_def do
      case refresh_materialized_view(view_def) do
        {:ok, refresh_time_ms} ->
          view_status = %{
            status: :refreshed,
            last_refresh: DateTime.utc_now(),
            refresh_time_ms: refresh_time_ms
          }

          %{state | views: Map.put(state.views, view_name, view_status)}

        {:error, error} ->
          Logger.error("Failed to refresh view #{view_name}: #{inspect(error)}")

          view_status = %{
            status: :error,
            error: inspect(error),
            last_refresh: nil
          }

          %{state | views: Map.put(state.views, view_name, view_status)}
      end
    else
      Logger.warning("Unknown view for refresh: #{view_name}")
      state
    end
  end

  defp perform_incremental_refreshes(state) do
    # Only refresh views that support incremental updates
    incremental_views = Enum.filter(@materialized_views, &(&1.refresh_strategy == :incremental))

    if length(incremental_views) > 0 do
      Logger.debug("Performing incremental refresh for #{length(incremental_views)} views")

      Enum.reduce(incremental_views, state, fn view_def, acc_state ->
        perform_view_refresh(view_def.name, acc_state)
      end)
    else
      state
    end
  end

  defp find_affected_views(cache_pattern) do
    # Determine which materialized views might be affected by cache invalidation
    affected_tables = extract_table_names_from_pattern(cache_pattern)

    Enum.filter(@materialized_views, fn view_def ->
      Enum.any?(view_def.dependencies, fn dep -> dep in affected_tables end)
    end)
    |> Enum.map(& &1.name)
  end

  defp extract_table_names_from_pattern(pattern) do
    # Extract potential table names from cache invalidation patterns
    cond do
      String.contains?(pattern, "killmail") -> ["killmails_enriched", "participants"]
      String.contains?(pattern, "character") -> ["participants"]
      String.contains?(pattern, "alliance") -> ["participants"]
      String.contains?(pattern, "system") -> ["killmails_enriched"]
      true -> []
    end
  end

  defp refresh_affected_views(affected_views, state) when length(affected_views) > 0 do
    Logger.debug("Refreshing #{length(affected_views)} views affected by cache invalidation")

    Enum.reduce(affected_views, state, fn view_name, acc_state ->
      perform_view_refresh(view_name, acc_state)
    end)
  end

  defp refresh_affected_views([], state), do: state

  defp query_materialized_view(view_name, limit) do
    # Basic query to get data from materialized view
    sql = "SELECT * FROM #{view_name} LIMIT $1"

    case Ecto.Adapters.SQL.query(Repo, sql, [limit]) do
      {:ok, %{columns: columns, rows: rows}} ->
        data =
          Enum.map(rows, fn row ->
            columns
            |> Enum.zip(row)
            |> Map.new()
          end)

        {:ok, data}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_current_view_status(state) do
    view_info =
      Enum.map(@materialized_views, fn view_def ->
        view_name = view_def.name
        status = Map.get(state.views, view_name, %{status: :unknown})

        %{
          name: view_name,
          status: status.status,
          last_refresh: status[:last_refresh],
          refresh_time_ms: status[:refresh_time_ms],
          dependencies: view_def.dependencies,
          refresh_strategy: view_def.refresh_strategy
        }
      end)

    %{
      views: view_info,
      last_global_refresh: state.last_refresh,
      refresh_stats: state.refresh_stats,
      total_views: length(@materialized_views)
    }
  end

  defp update_refresh_stats(current_stats, duration_ms, successful, total) do
    total_refreshes = current_stats.total_refreshes + 1
    failed_refreshes = current_stats.failed_refreshes + (total - successful)

    # Calculate rolling average
    current_avg = current_stats.avg_refresh_time_ms

    new_avg =
      if total_refreshes == 1 do
        duration_ms
      else
        (current_avg * (total_refreshes - 1) + duration_ms) / total_refreshes
      end

    %{
      total_refreshes: total_refreshes,
      failed_refreshes: failed_refreshes,
      avg_refresh_time_ms: round(new_avg)
    }
  end

  # Public utilities

  def get_character_activity(character_id) when is_integer(character_id) do
    query_materialized_view_where("character_activity_summary", "character_id = $1", [
      character_id
    ])
  end

  def get_system_activity(system_id) when is_integer(system_id) do
    query_materialized_view_where("system_activity_summary", "solar_system_id = $1", [system_id])
  end

  def get_alliance_stats(alliance_id) when is_integer(alliance_id) do
    query_materialized_view_where("alliance_statistics", "alliance_id = $1", [alliance_id])
  end

  def get_top_hunters(limit \\ 10) do
    query_materialized_view("top_hunters_summary", limit)
  end

  def get_daily_activity(days_back \\ 30) do
    cutoff_date = Date.add(Date.utc_today(), -days_back)

    query_materialized_view_where(
      "daily_killmail_summary",
      "activity_date >= $1",
      [cutoff_date],
      100
    )
  end

  defp query_materialized_view_where(view_name, where_clause, params, limit \\ 1) do
    sql = "SELECT * FROM #{view_name} WHERE #{where_clause} LIMIT $#{length(params) + 1}"

    case Ecto.Adapters.SQL.query(Repo, sql, params ++ [limit]) do
      {:ok, %{columns: columns, rows: rows}} ->
        data =
          Enum.map(rows, fn row ->
            columns
            |> Enum.zip(row)
            |> Map.new()
          end)

        {:ok, data}

      {:error, error} ->
        {:error, error}
    end
  end

  def analyze_view_performance do
    # Get size and usage statistics for all materialized views
    query = """
    SELECT 
      schemaname,
      matviewname,
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||matviewname)) as size,
      pg_total_relation_size(schemaname||'.'||matviewname) as size_bytes
    FROM pg_matviews 
    WHERE schemaname = 'public'
    ORDER BY pg_total_relation_size(schemaname||'.'||matviewname) DESC
    """

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, %{rows: rows}} ->
        views =
          Enum.map(rows, fn [schema, name, size, size_bytes] ->
            %{
              schema: schema,
              name: name,
              size: size,
              size_bytes: size_bytes
            }
          end)

        {:ok, views}

      {:error, error} ->
        {:error, error}
    end
  end
end
