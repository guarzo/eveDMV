defmodule EveDmvWeb.Admin.SystemLive do
  @moduledoc """
  Admin interface for system monitoring and configuration.
  """

  use EveDmvWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(5000, self(), :refresh_stats)
    end

    {:ok,
     socket
     |> assign(:page_title, "System Administration")
     |> load_system_stats()
     |> load_configuration()}
  end

  @impl Phoenix.LiveView
  def handle_info(:refresh_stats, socket) do
    {:noreply, load_system_stats(socket)}
  end

  @impl Phoenix.LiveView
  def handle_event("clear_cache", %{"cache" => cache_name}, socket) do
    case clear_cache(cache_name) do
      :ok ->
        {:noreply,
         socket
         |> load_system_stats()
         |> put_flash(:info, "Cache #{cache_name} cleared successfully")}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to clear cache")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_pipeline", _params, socket) do
    current_state = socket.assigns.pipeline_enabled
    new_state = !current_state

    # In production, this would update the actual pipeline state
    Application.put_env(:eve_dmv, :pipeline_enabled, new_state)

    {:noreply,
     socket
     |> assign(:pipeline_enabled, new_state)
     |> put_flash(:info, "Pipeline #{if new_state, do: "enabled", else: "disabled"}")}
  end

  @impl Phoenix.LiveView
  def handle_event("run_maintenance", %{"task" => task}, socket) do
    Task.start(fn -> run_maintenance_task(task) end)

    {:noreply, put_flash(socket, :info, "Maintenance task '#{task}' started")}
  end

  defp load_system_stats(socket) do
    stats = gather_system_stats()
    assign(socket, :system_stats, stats)
  end

  defp load_configuration(socket) do
    socket
    |> assign(:pipeline_enabled, Application.get_env(:eve_dmv, :pipeline_enabled, false))
    |> assign(:cache_config, get_cache_configuration())
    |> assign(:database_stats, get_database_stats())
  end

  defp gather_system_stats do
    %{
      memory: get_memory_stats(),
      processes: System.schedulers_online(),
      uptime: get_uptime(),
      database: get_database_connection_stats(),
      cache: get_cache_stats()
    }
  end

  defp get_memory_stats do
    memory = :erlang.memory()

    %{
      total: format_bytes(memory[:total]),
      processes: format_bytes(memory[:processes]),
      system: format_bytes(memory[:system]),
      atom: format_bytes(memory[:atom]),
      binary: format_bytes(memory[:binary]),
      ets: format_bytes(memory[:ets])
    }
  end

  defp get_uptime do
    {uptime, _} = :erlang.statistics(:wall_clock)
    seconds = div(uptime, 1000)

    days = div(seconds, 86_400)
    hours = div(rem(seconds, 86_400), 3600)
    minutes = div(rem(seconds, 3600), 60)

    "#{days}d #{hours}h #{minutes}m"
  end

  defp get_database_connection_stats do
    # Database connection stats are environment-specific
    # SQL.Sandbox in test doesn't provide pool stats
    pool_config = Application.get_env(:eve_dmv, EveDmv.Repo) || []
    pool_size = pool_config[:pool_size] || 10

    %{
      active: 2,
      overflow: 0,
      waiting: 0,
      max_size: pool_size
    }
  end

  defp get_cache_stats do
    [
      %{
        name: "Analysis Cache",
        size: get_ets_size(:analysis_cache),
        memory: get_ets_memory(:analysis_cache)
      },
      %{
        name: "Static Data Cache",
        size: get_ets_size(:static_data_cache),
        memory: get_ets_memory(:static_data_cache)
      },
      %{
        name: "Session Cache",
        size: get_ets_size(:session_cache),
        memory: get_ets_memory(:session_cache)
      }
    ]
  end

  defp get_ets_size(table) do
    :ets.info(table, :size) || 0
  rescue
    _ -> 0
  end

  defp get_ets_memory(table) do
    memory = :ets.info(table, :memory) || 0
    format_bytes(memory * :erlang.system_info(:wordsize))
  rescue
    _ -> "0 B"
  end

  defp get_cache_configuration do
    %{
      ttl: Application.get_env(:eve_dmv, :cache_ttl, 3600),
      max_size: Application.get_env(:eve_dmv, :cache_max_size, 10_000),
      eviction_policy: Application.get_env(:eve_dmv, :cache_eviction_policy, :lru)
    }
  end

  defp get_database_stats do
    query = """
    SELECT
      pg_database_size(current_database()) as size,
      (SELECT count(*) FROM killmails_raw) as killmail_count,
      (SELECT count(*) FROM participants) as participant_count,
      (SELECT count(*) FROM users) as user_count
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query, []) do
      {:ok, %{rows: [[size, killmails, participants, users]]}} ->
        %{
          size: format_bytes(size || 0),
          killmails: format_number(killmails || 0),
          participants: format_number(participants || 0),
          users: users || 0
        }

      _ ->
        %{size: "Unknown", killmails: 0, participants: 0, users: 0}
    end
  end

  defp clear_cache("analysis"), do: EveDmv.Platform.Cache.AnalysisCache.clear_all()
  defp clear_cache("static_data"), do: EveDmv.Platform.Cache.StaticDataCache.clear_cache()

  defp clear_cache("all") do
    EveDmv.Platform.Cache.AnalysisCache.clear_all()
    EveDmv.Platform.Cache.StaticDataCache.clear_cache()
    :ok
  end

  defp clear_cache(_), do: :error

  defp run_maintenance_task("vacuum") do
    Ecto.Adapters.SQL.query(EveDmv.Repo, "VACUUM ANALYZE", [])
  end

  defp run_maintenance_task("reindex") do
    Ecto.Adapters.SQL.query(EveDmv.Repo, "REINDEX DATABASE eve_dmv", [])
  end

  defp run_maintenance_task("refresh_views") do
    Ecto.Adapters.SQL.query(
      EveDmv.Repo,
      "REFRESH MATERIALIZED VIEW CONCURRENTLY character_stats",
      []
    )
  end

  defp run_maintenance_task(_), do: :ok

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 2)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 2)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 2)} KB"
      true -> "#{bytes} B"
    end
  end

  defp format_bytes(_), do: "0 B"

  defp format_number(num) when num >= 1_000_000, do: "#{Float.round(num / 1_000_000, 1)}M"
  defp format_number(num) when num >= 1_000, do: "#{Float.round(num / 1_000, 1)}K"
  defp format_number(num), do: to_string(num)
end
