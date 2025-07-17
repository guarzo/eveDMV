defmodule EveDmv.Database.MaterializedViewRefresher do
  @moduledoc """
  Sprint 15A: GenServer responsible for periodically refreshing materialized views.

  Refreshes character_activity_summary and corporation_member_summary views
  to ensure they contain up-to-date aggregated data for performance optimization.
  """

  use GenServer
  require Logger

  alias EveDmv.Repo

  # Refresh interval - 15 minutes by default
  @refresh_interval :timer.minutes(15)

  # View refresh queries
  @character_activity_refresh "SELECT refresh_character_activity_summary();"
  @corporation_summary_refresh "SELECT refresh_corporation_member_summary();"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Schedule first refresh after 1 minute to allow system to start up
    Process.send_after(self(), :refresh_views, :timer.minutes(1))

    Logger.info("📊 Materialized View Refresher started - first refresh in 1 minute")

    {:ok,
     %{
       last_refresh: nil,
       refresh_count: 0,
       errors: 0,
       enabled: Application.get_env(:eve_dmv, :materialized_views_enabled, true)
     }}
  end

  @impl true
  def handle_info(:refresh_views, %{enabled: false} = state) do
    # Skip refresh if disabled
    schedule_next_refresh()
    {:noreply, state}
  end

  def handle_info(:refresh_views, state) do
    Logger.info("🔄 Starting materialized view refresh...")
    start_time = System.monotonic_time(:millisecond)

    case refresh_all_views() do
      {:ok, _} ->
        duration = System.monotonic_time(:millisecond) - start_time
        Logger.info("✅ Materialized views refreshed successfully in #{duration}ms")

        # Emit telemetry
        :telemetry.execute(
          [:eve_dmv, :materialized_views, :refresh],
          %{duration: duration},
          %{status: :success}
        )

        schedule_next_refresh()

        {:noreply,
         %{state | last_refresh: DateTime.utc_now(), refresh_count: state.refresh_count + 1}}

      {:error, reason} ->
        Logger.error("❌ Failed to refresh materialized views: #{inspect(reason)}")

        # Emit telemetry
        :telemetry.execute(
          [:eve_dmv, :materialized_views, :refresh],
          %{duration: 0},
          %{status: :error, reason: reason}
        )

        # Schedule retry sooner on error (5 minutes)
        Process.send_after(self(), :refresh_views, :timer.minutes(5))

        {:noreply, %{state | errors: state.errors + 1}}
    end
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      last_refresh: state.last_refresh,
      refresh_count: state.refresh_count,
      errors: state.errors,
      enabled: state.enabled,
      next_refresh_in: get_next_refresh_time()
    }

    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_call(:force_refresh, _from, state) do
    Logger.info("🔄 Force refresh requested for materialized views")

    case refresh_all_views() do
      {:ok, _} ->
        {:reply, :ok,
         %{state | last_refresh: DateTime.utc_now(), refresh_count: state.refresh_count + 1}}

      {:error, reason} ->
        {:reply, {:error, reason}, %{state | errors: state.errors + 1}}
    end
  end

  @impl true
  def handle_call({:enable, enabled}, _from, state) do
    Logger.info("📊 Materialized view refresh #{if enabled, do: "enabled", else: "disabled"}")
    {:reply, :ok, %{state | enabled: enabled}}
  end

  # Public API

  @doc "Get the current status of the materialized view refresher"
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc "Force an immediate refresh of all materialized views"
  def force_refresh do
    GenServer.call(__MODULE__, :force_refresh)
  end

  @doc "Enable or disable automatic refresh"
  def set_enabled(enabled) when is_boolean(enabled) do
    GenServer.call(__MODULE__, {:enable, enabled})
  end

  # Private functions

  defp refresh_all_views do
    try do
      # Use a transaction to ensure consistency
      Repo.transaction(fn ->
        # First refresh character activity (base view)
        case Repo.query(@character_activity_refresh) do
          {:ok, _} ->
            Logger.debug("✓ character_activity_summary refreshed")

          {:error, error} ->
            Logger.error("Failed to refresh character_activity_summary: #{inspect(error)}")
            Repo.rollback(error)
        end

        # Then refresh corporation summary (depends on character activity)
        case Repo.query(@corporation_summary_refresh) do
          {:ok, _} ->
            Logger.debug("✓ corporation_member_summary refreshed")

          {:error, error} ->
            Logger.error("Failed to refresh corporation_member_summary: #{inspect(error)}")
            Repo.rollback(error)
        end
      end)
    rescue
      e ->
        {:error, e}
    end
  end

  defp schedule_next_refresh do
    Process.send_after(self(), :refresh_views, @refresh_interval)
  end

  defp get_next_refresh_time do
    # Calculate approximate time until next refresh
    @refresh_interval
  end

  @doc """
  Manually refresh a specific view. Useful for testing or targeted updates.
  """
  def refresh_view(:character_activity) do
    Repo.query(@character_activity_refresh)
  end

  def refresh_view(:corporation_summary) do
    Repo.query(@corporation_summary_refresh)
  end

  def refresh_view(:all) do
    refresh_all_views()
  end
end
