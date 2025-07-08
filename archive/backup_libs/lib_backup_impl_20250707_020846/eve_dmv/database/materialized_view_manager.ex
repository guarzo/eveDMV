defmodule EveDmv.Database.MaterializedViewManager do
  @moduledoc """
  Manages materialized views for performance optimization.

  Creates and maintains materialized views for frequently accessed aggregated data,
  automatically refreshing them based on data changes and schedules.
  """

  use GenServer
  require Logger

  alias EveDmv.Database.CacheInvalidator
  alias EveDmv.Database.MaterializedViewManager.ViewLifecycle
  alias EveDmv.Database.MaterializedViewManager.ViewMetrics
  alias EveDmv.Database.MaterializedViewManager.ViewQueryService
  alias EveDmv.Database.MaterializedViewManager.ViewRefreshScheduler

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
      ViewRefreshScheduler.schedule_refresh()
      ViewRefreshScheduler.schedule_incremental_refresh()
    end

    {:ok, state}
  end

  def handle_call({:create_view, view_name}, _from, state) do
    result = ViewLifecycle.create_materialized_view(view_name)
    {:reply, result, state}
  end

  def handle_call({:drop_view, view_name}, _from, state) do
    result = ViewLifecycle.drop_materialized_view(view_name)
    {:reply, result, state}
  end

  def handle_call(:get_view_status, _from, state) do
    status = ViewMetrics.get_view_status(state.views, state.last_refresh, state.refresh_stats)
    {:reply, status, state}
  end

  def handle_call({:get_view_data, view_name, limit}, _from, state) do
    result = ViewQueryService.query_view(view_name, limit)
    {:reply, result, state}
  end

  def handle_cast({:refresh_view, view_name}, state) do
    updated_views = ViewRefreshScheduler.refresh_view_by_name(view_name, state.views)
    new_state = %{state | views: updated_views}
    {:noreply, new_state}
  end

  def handle_cast(:refresh_all_views, state) do
    {refreshed_views, new_stats} =
      ViewRefreshScheduler.refresh_all_views(state.views, state.refresh_stats)

    new_state = %{
      state
      | views: refreshed_views,
        refresh_stats: new_stats,
        last_refresh: DateTime.utc_now()
    }

    {:noreply, new_state}
  end

  def handle_info(:initialize_views, state) do
    new_state = initialize_all_views(state)
    {:noreply, new_state}
  end

  def handle_info(:scheduled_refresh, state) do
    {refreshed_views, new_stats} =
      ViewRefreshScheduler.refresh_all_views(state.views, state.refresh_stats)

    ViewRefreshScheduler.schedule_refresh()

    new_state = %{
      state
      | views: refreshed_views,
        refresh_stats: new_stats,
        last_refresh: DateTime.utc_now()
    }

    {:noreply, new_state}
  end

  def handle_info(:incremental_refresh, state) do
    refreshed_views = ViewRefreshScheduler.perform_incremental_refreshes(state.views)
    ViewRefreshScheduler.schedule_incremental_refresh()
    new_state = %{state | views: Map.merge(state.views, refreshed_views)}
    {:noreply, new_state}
  end

  def handle_info({:cache_invalidated, pattern, _count}, state) do
    updated_views = ViewRefreshScheduler.refresh_affected_views(pattern, state.views)
    new_state = %{state | views: updated_views}
    {:noreply, new_state}
  end

  def handle_info(_, state), do: {:noreply, state}

  # Private functions

  defp initialize_all_views(state) do
    Logger.info("Initializing materialized views")

    views_status = ViewLifecycle.ensure_all_views_exist()

    %{state | views: views_status, last_refresh: DateTime.utc_now()}
  end

  # Public utilities - Delegation to ViewQueryService

  defdelegate get_character_activity(character_id), to: ViewQueryService
  defdelegate get_system_activity(system_id), to: ViewQueryService
  defdelegate get_alliance_stats(alliance_id), to: ViewQueryService
  defdelegate get_top_hunters(limit \\ 10), to: ViewQueryService
  defdelegate get_daily_activity(days_back \\ 30), to: ViewQueryService

  # Delegation to ViewMetrics
  defdelegate analyze_view_performance(), to: ViewMetrics, as: :analyze_performance
end
