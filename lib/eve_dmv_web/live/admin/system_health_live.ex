defmodule EveDmvWeb.Admin.SystemHealthLive do
  @moduledoc """
  Comprehensive system health dashboard for administrators.

  Provides real-time visibility into:
  - Database connection pool status
  - Broadway pipeline throughput and backlog
  - Cache hit rates and memory usage
  - Slow query detection
  - LiveView socket counts
  - Recent errors and alerts
  - BEAM VM statistics
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Platform.Monitoring.HealthAggregator
  alias Phoenix.PubSub

  require Logger

  # 5 seconds
  @refresh_interval 5_000
  @valid_tabs ~w(overview database pipeline cache memory queries errors)a

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      schedule_refresh()
      PubSub.subscribe(EveDmv.PubSub, "performance:alerts")
    end

    {:ok,
     socket
     |> assign(:page_title, "System Health")
     |> assign(:health, get_health_safely())
     |> assign(:auto_refresh, true)
     |> assign(:alerts, [])
     |> assign(:selected_tab, :overview)}
  end

  @impl Phoenix.LiveView
  def handle_info(:refresh, socket) do
    if socket.assigns.auto_refresh do
      schedule_refresh()
      {:noreply, assign(socket, :health, get_health_safely())}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:performance_alert, alert}, socket) do
    alerts = [alert | socket.assigns.alerts] |> Enum.take(20)
    {:noreply, assign(socket, :alerts, alerts)}
  end

  def handle_info(msg, socket) do
    Logger.debug(
      "SystemHealthLive received unexpected message: #{inspect(msg)}, " <>
        "assigns: #{inspect(Map.take(socket.assigns, [:page_title, :auto_refresh, :selected_tab]))}"
    )

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_refresh", _, socket) do
    new_state = !socket.assigns.auto_refresh
    if new_state, do: schedule_refresh()
    {:noreply, assign(socket, :auto_refresh, new_state)}
  end

  def handle_event("refresh_now", _, socket) do
    {:noreply, assign(socket, :health, get_health_safely())}
  end

  def handle_event("select_tab", %{"tab" => tab}, socket) do
    case Enum.find(@valid_tabs, fn valid -> Atom.to_string(valid) == tab end) do
      nil -> {:noreply, socket}
      tab_atom -> {:noreply, assign(socket, :selected_tab, tab_atom)}
    end
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end

  defp get_health_safely do
    HealthAggregator.get_health_snapshot()
  rescue
    e ->
      Logger.error(
        "Failed to get health snapshot from HealthAggregator.get_health_snapshot/0: " <>
          Exception.format(:error, e, __STACKTRACE__)
      )

      %{
        timestamp: DateTime.utc_now(),
        overall_status: :unknown,
        database: %{
          status: :unknown,
          pool: %{pool_size: 0, checked_out: 0, available: 0, queue_length: 0, utilization: 0},
          slow_queries: []
        },
        pipeline: %{
          status: :unknown,
          messages_processed: 0,
          messages_failed: 0,
          batches_processed: 0,
          success_rate: 0,
          throughput: 0
        },
        cache: %{
          status: :unknown,
          query_cache: %{hits: 0, misses: 0, hit_rate: 0, size: 0, memory_mb: 0},
          ets_tables: []
        },
        memory: %{
          status: :unknown,
          total_mb: 0,
          processes_mb: 0,
          ets_mb: 0,
          binary_mb: 0,
          atom_mb: 0,
          code_mb: 0,
          system_mb: 0,
          top_processes: []
        },
        liveview: %{status: :unknown, active_sockets: 0},
        queries: %{
          status: :unknown,
          slow_query_count: 0,
          n_plus_one_count: 0,
          slow_queries: [],
          n_plus_one_alerts: []
        },
        errors: %{count: 0, errors: []},
        uptime: %{total_seconds: 0, formatted: "0d 0h 0m 0s", started_at: DateTime.utc_now()}
      }
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-gray-100 p-6">
      <header class="mb-8">
        <div class="flex justify-between items-center">
          <div>
            <h1 class="text-3xl font-bold">System Health Dashboard</h1>
            <p class="text-gray-400 mt-1">
              Last updated: <%= Calendar.strftime(@health.timestamp, "%Y-%m-%d %H:%M:%S UTC") %>
            </p>
          </div>
          <div class="flex gap-4 items-center">
            <.status_badge status={@health.overall_status} size="lg" />
            <button
              phx-click="refresh_now"
              class="px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded-lg"
            >
              Refresh Now
            </button>
            <button
              phx-click="toggle_refresh"
              class={"px-4 py-2 rounded-lg #{if @auto_refresh, do: "bg-green-600", else: "bg-gray-600"}"}
            >
              Auto-refresh: <%= if @auto_refresh, do: "ON", else: "OFF" %>
            </button>
          </div>
        </div>
      </header>

      <nav class="flex gap-2 mb-6 border-b border-gray-700 pb-2">
        <.tab_button tab={:overview} selected={@selected_tab} label="Overview" />
        <.tab_button tab={:database} selected={@selected_tab} label="Database" />
        <.tab_button tab={:pipeline} selected={@selected_tab} label="Pipeline" />
        <.tab_button tab={:cache} selected={@selected_tab} label="Cache" />
        <.tab_button tab={:memory} selected={@selected_tab} label="Memory" />
        <.tab_button tab={:queries} selected={@selected_tab} label="Queries" />
        <.tab_button tab={:errors} selected={@selected_tab} label="Errors" />
      </nav>

      <div class="space-y-6">
        <%= case @selected_tab do %>
          <% :overview -> %>
            <.overview_tab health={@health} />
          <% :database -> %>
            <.database_tab db={@health.database} />
          <% :pipeline -> %>
            <.pipeline_tab pipeline={@health.pipeline} />
          <% :cache -> %>
            <.cache_tab cache={@health.cache} />
          <% :memory -> %>
            <.memory_tab memory={@health.memory} />
          <% :queries -> %>
            <.queries_tab queries={@health.queries} />
          <% :errors -> %>
            <.errors_tab errors={@health.errors} alerts={@alerts} />
        <% end %>
      </div>

      <footer class="mt-8 pt-4 border-t border-gray-700 text-gray-400 text-sm">
        Uptime: <%= @health.uptime.formatted %> | Started: <%= Calendar.strftime(@health.uptime.started_at, "%Y-%m-%d %H:%M UTC") %>
      </footer>
    </div>
    """
  end

  # Component for status badges
  defp status_badge(assigns) do
    size_class = if assigns[:size] == "lg", do: "px-4 py-2 text-lg", else: "px-2 py-1 text-sm"

    {bg_class, text} =
      case assigns.status do
        :healthy -> {"bg-green-600", "Healthy"}
        :warning -> {"bg-yellow-600", "Warning"}
        :critical -> {"bg-red-600", "Critical"}
        :degraded -> {"bg-orange-600", "Degraded"}
        _ -> {"bg-gray-600", "Unknown"}
      end

    assigns =
      assigns
      |> assign(:bg_class, bg_class)
      |> assign(:text, text)
      |> assign(:size_class, size_class)

    ~H"""
    <span class={"rounded-lg font-semibold #{@bg_class} #{@size_class}"}>
      <%= @text %>
    </span>
    """
  end

  defp tab_button(assigns) do
    active_class =
      if assigns.tab == assigns.selected, do: "bg-blue-600", else: "bg-gray-700 hover:bg-gray-600"

    assigns = assign(assigns, :active_class, active_class)

    ~H"""
    <button
      phx-click="select_tab"
      phx-value-tab={@tab}
      class={"px-4 py-2 rounded-t-lg #{@active_class}"}
    >
      <%= @label %>
    </button>
    """
  end

  # Overview tab with all key metrics
  defp overview_tab(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <.metric_card title="Database" status={@health.database.status}>
        <div class="space-y-2">
          <div class="flex justify-between">
            <span>Pool Utilization</span>
            <span class="font-mono"><%= @health.database.pool.utilization %>%</span>
          </div>
          <div class="w-full bg-gray-700 rounded-full h-2">
            <div
              class={"h-2 rounded-full #{utilization_color(@health.database.pool.utilization)}"}
              style={"width: #{@health.database.pool.utilization}%"}
            >
            </div>
          </div>
          <div class="flex justify-between text-sm text-gray-400">
            <span>Active: <%= @health.database.pool.checked_out %></span>
            <span>Available: <%= @health.database.pool.available %></span>
          </div>
        </div>
      </.metric_card>

      <.metric_card title="Pipeline" status={@health.pipeline.status}>
        <div class="space-y-2">
          <div class="flex justify-between">
            <span>Success Rate</span>
            <span class="font-mono"><%= @health.pipeline.success_rate %>%</span>
          </div>
          <div class="flex justify-between text-sm">
            <span>Processed: <%= format_number(@health.pipeline.messages_processed) %></span>
            <span>Failed: <%= @health.pipeline.messages_failed %></span>
          </div>
          <div class="text-sm text-gray-400">
            Throughput: ~<%= @health.pipeline.throughput %>/min
          </div>
        </div>
      </.metric_card>

      <.metric_card title="Cache" status={@health.cache.status}>
        <div class="space-y-2">
          <div class="flex justify-between">
            <span>Hit Rate</span>
            <span class="font-mono"><%= @health.cache.query_cache.hit_rate %>%</span>
          </div>
          <div class="flex justify-between text-sm text-gray-400">
            <span>Hits: <%= format_number(@health.cache.query_cache.hits) %></span>
            <span>Misses: <%= format_number(@health.cache.query_cache.misses) %></span>
          </div>
        </div>
      </.metric_card>

      <.metric_card title="Memory" status={@health.memory.status}>
        <div class="space-y-2">
          <div class="flex justify-between">
            <span>Total</span>
            <span class="font-mono"><%= @health.memory.total_mb %> MB</span>
          </div>
          <div class="grid grid-cols-2 gap-2 text-sm text-gray-400">
            <span>Processes: <%= @health.memory.processes_mb %> MB</span>
            <span>ETS: <%= @health.memory.ets_mb %> MB</span>
            <span>Binary: <%= @health.memory.binary_mb %> MB</span>
            <span>Code: <%= @health.memory.code_mb %> MB</span>
          </div>
        </div>
      </.metric_card>

      <.metric_card title="Queries" status={@health.queries.status}>
        <div class="space-y-2">
          <div class="flex justify-between">
            <span>Slow Queries</span>
            <span class="font-mono"><%= @health.queries.slow_query_count %></span>
          </div>
          <div class="flex justify-between">
            <span>N+1 Alerts</span>
            <span class="font-mono"><%= @health.queries.n_plus_one_count %></span>
          </div>
        </div>
      </.metric_card>

      <.metric_card title="LiveView" status={@health.liveview.status}>
        <div class="space-y-2">
          <div class="flex justify-between">
            <span>Active Sockets</span>
            <span class="font-mono"><%= @health.liveview.active_sockets %></span>
          </div>
        </div>
      </.metric_card>
    </div>
    """
  end

  defp metric_card(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg p-4 border border-gray-700">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-semibold"><%= @title %></h3>
        <.status_badge status={@status} />
      </div>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  # Database detail tab
  defp database_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-xl font-semibold mb-4">Connection Pool</h3>
        <div class="grid grid-cols-4 gap-4">
          <div class="text-center">
            <div class="text-3xl font-bold"><%= @db.pool.pool_size %></div>
            <div class="text-gray-400">Pool Size</div>
          </div>
          <div class="text-center">
            <div class="text-3xl font-bold text-green-400"><%= @db.pool.available %></div>
            <div class="text-gray-400">Available</div>
          </div>
          <div class="text-center">
            <div class="text-3xl font-bold text-yellow-400"><%= @db.pool.checked_out %></div>
            <div class="text-gray-400">In Use</div>
          </div>
          <div class="text-center">
            <div class="text-3xl font-bold text-red-400"><%= @db.pool.queue_length %></div>
            <div class="text-gray-400">Waiting</div>
          </div>
        </div>
      </div>

      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-xl font-semibold mb-4">Slow Queries (>100ms avg)</h3>
        <%= if length(@db.slow_queries) > 0 do %>
          <table class="w-full text-sm">
            <thead class="text-gray-400 border-b border-gray-700">
              <tr>
                <th class="text-left py-2">Query</th>
                <th class="text-right py-2">Calls</th>
                <th class="text-right py-2">Avg (ms)</th>
                <th class="text-right py-2">Max (ms)</th>
              </tr>
            </thead>
            <tbody>
              <%= for query <- @db.slow_queries do %>
                <tr class="border-b border-gray-700">
                  <td class="py-2 font-mono text-xs truncate max-w-md"><%= query.query %></td>
                  <td class="text-right py-2"><%= format_number(query.calls) %></td>
                  <td class="text-right py-2 text-yellow-400"><%= query.avg_ms %></td>
                  <td class="text-right py-2 text-red-400"><%= query.max_ms %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% else %>
          <p class="text-gray-400">No slow queries detected</p>
        <% end %>
      </div>
    </div>
    """
  end

  # Pipeline detail tab
  defp pipeline_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-xl font-semibold mb-4">Broadway Pipeline Stats</h3>
        <div class="grid grid-cols-4 gap-4">
          <div class="text-center">
            <div class="text-3xl font-bold">
              <%= format_number(@pipeline.messages_processed) %>
            </div>
            <div class="text-gray-400">Processed</div>
          </div>
          <div class="text-center">
            <div class="text-3xl font-bold text-red-400">
              <%= format_number(@pipeline.messages_failed) %>
            </div>
            <div class="text-gray-400">Failed</div>
          </div>
          <div class="text-center">
            <div class="text-3xl font-bold">
              <%= format_number(@pipeline.batches_processed) %>
            </div>
            <div class="text-gray-400">Batches</div>
          </div>
          <div class="text-center">
            <div class="text-3xl font-bold text-green-400"><%= @pipeline.success_rate %>%</div>
            <div class="text-gray-400">Success Rate</div>
          </div>
        </div>
      </div>

      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-xl font-semibold mb-4">Throughput</h3>
        <div class="text-4xl font-bold">
          ~<%= @pipeline.throughput %> <span class="text-lg text-gray-400">kills/min</span>
        </div>
        <div class="mt-2 text-gray-400">
          Avg processing time: <%= @pipeline[:avg_processing_time_ms] || "N/A" %> ms
        </div>
      </div>
    </div>
    """
  end

  # Cache detail tab
  defp cache_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-xl font-semibold mb-4">Query Cache</h3>
        <div class="grid grid-cols-4 gap-4">
          <div class="text-center">
            <div class="text-3xl font-bold text-green-400"><%= @cache.query_cache.hit_rate %>%</div>
            <div class="text-gray-400">Hit Rate</div>
          </div>
          <div class="text-center">
            <div class="text-3xl font-bold"><%= format_number(@cache.query_cache.hits) %></div>
            <div class="text-gray-400">Hits</div>
          </div>
          <div class="text-center">
            <div class="text-3xl font-bold"><%= format_number(@cache.query_cache.misses) %></div>
            <div class="text-gray-400">Misses</div>
          </div>
          <div class="text-center">
            <div class="text-3xl font-bold"><%= @cache.query_cache[:memory_mb] || 0 %> MB</div>
            <div class="text-gray-400">Memory</div>
          </div>
        </div>
      </div>

      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-xl font-semibold mb-4">Top ETS Tables by Memory</h3>
        <table class="w-full text-sm">
          <thead class="text-gray-400 border-b border-gray-700">
            <tr>
              <th class="text-left py-2">Table</th>
              <th class="text-right py-2">Entries</th>
              <th class="text-right py-2">Memory</th>
            </tr>
          </thead>
          <tbody>
            <%= for table <- @cache.ets_tables do %>
              <tr class="border-b border-gray-700">
                <td class="py-2 font-mono"><%= table.name %></td>
                <td class="text-right py-2"><%= format_number(table.size) %></td>
                <td class="text-right py-2"><%= format_bytes(table.memory_bytes) %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # Memory detail tab
  defp memory_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-xl font-semibold mb-4">BEAM Memory Usage</h3>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div class="bg-gray-700 rounded-lg p-4">
            <div class="text-2xl font-bold"><%= @memory.total_mb %> MB</div>
            <div class="text-gray-400">Total</div>
          </div>
          <div class="bg-gray-700 rounded-lg p-4">
            <div class="text-2xl font-bold"><%= @memory.processes_mb %> MB</div>
            <div class="text-gray-400">Processes</div>
          </div>
          <div class="bg-gray-700 rounded-lg p-4">
            <div class="text-2xl font-bold"><%= @memory.ets_mb %> MB</div>
            <div class="text-gray-400">ETS Tables</div>
          </div>
          <div class="bg-gray-700 rounded-lg p-4">
            <div class="text-2xl font-bold"><%= @memory.binary_mb %> MB</div>
            <div class="text-gray-400">Binaries</div>
          </div>
        </div>
      </div>

      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-xl font-semibold mb-4">Top Memory Consumers</h3>
        <table class="w-full text-sm">
          <thead class="text-gray-400 border-b border-gray-700">
            <tr>
              <th class="text-left py-2">Process</th>
              <th class="text-left py-2">Name/Function</th>
              <th class="text-right py-2">Memory</th>
            </tr>
          </thead>
          <tbody>
            <%= for proc <- @memory.top_processes do %>
              <tr class="border-b border-gray-700">
                <td class="py-2 font-mono text-xs"><%= proc.pid %></td>
                <td class="py-2 truncate max-w-xs"><%= proc.name %></td>
                <td class="text-right py-2"><%= proc.memory_kb %> KB</td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # Queries detail tab
  defp queries_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-xl font-semibold mb-4">
          Slow Queries (<%= @queries.slow_query_count %> detected)
        </h3>
        <%= if length(@queries.slow_queries) > 0 do %>
          <div class="space-y-2">
            <%= for query <- @queries.slow_queries do %>
              <div class="bg-gray-700 rounded p-3">
                <div class="font-mono text-xs text-gray-300 mb-2">
                  <%= Map.get(query, :query, Map.get(query, :normalized_query, "N/A")) %>
                </div>
                <div class="text-sm text-gray-400">
                  Duration: <%= Map.get(query, :duration_ms, "N/A") %> ms
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <p class="text-gray-400">No slow queries in the monitoring window</p>
        <% end %>
      </div>

      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-xl font-semibold mb-4">
          N+1 Query Alerts (<%= @queries.n_plus_one_count %> detected)
        </h3>
        <%= if length(@queries.n_plus_one_alerts) > 0 do %>
          <div class="space-y-2">
            <%= for alert <- @queries.n_plus_one_alerts do %>
              <div class="bg-yellow-900/30 border border-yellow-700 rounded p-3">
                <div class="font-mono text-xs text-yellow-300">
                  <%= Map.get(alert, :query, "N/A") %>
                </div>
                <div class="text-sm text-yellow-400 mt-1">
                  Executed <%= Map.get(alert, :execution_count, Map.get(alert, :count, "N/A")) %> times in monitoring window
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <p class="text-gray-400">No N+1 patterns detected</p>
        <% end %>
      </div>
    </div>
    """
  end

  # Errors detail tab
  defp errors_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-xl font-semibold mb-4">Recent Errors (<%= @errors.count %>)</h3>
        <%= if length(@errors.errors) > 0 do %>
          <div class="space-y-2">
            <%= for error <- @errors.errors do %>
              <div class="bg-red-900/30 border border-red-700 rounded p-3">
                <div class="text-sm text-red-300"><%= Map.get(error, :message, inspect(error)) %></div>
                <div class="text-xs text-red-400 mt-1">
                  <%= format_timestamp(Map.get(error, :timestamp)) %>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <p class="text-gray-400">No recent errors</p>
        <% end %>
      </div>

      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-xl font-semibold mb-4">Performance Alerts</h3>
        <%= if length(@alerts) > 0 do %>
          <div class="space-y-2">
            <%= for alert <- @alerts do %>
              <div class="bg-yellow-900/30 border border-yellow-700 rounded p-3">
                <div class="text-sm"><%= inspect(alert) %></div>
              </div>
            <% end %>
          </div>
        <% else %>
          <p class="text-gray-400">No performance alerts</p>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper functions
  defp format_number(nil), do: "0"

  defp format_number(n) when is_integer(n) and n >= 1_000_000,
    do: "#{Float.round(n / 1_000_000, 1)}M"

  defp format_number(n) when is_integer(n) and n >= 1_000, do: "#{Float.round(n / 1_000, 1)}K"
  defp format_number(n) when is_float(n), do: Float.round(n, 1) |> to_string()
  defp format_number(n), do: to_string(n)

  defp format_bytes(bytes) when bytes >= 1_048_576, do: "#{Float.round(bytes / 1_048_576, 1)} MB"
  defp format_bytes(bytes) when bytes >= 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{bytes} B"

  defp format_timestamp(nil), do: "N/A"
  defp format_timestamp(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
  defp format_timestamp(other), do: inspect(other)

  defp utilization_color(pct) when pct >= 90, do: "bg-red-500"
  defp utilization_color(pct) when pct >= 70, do: "bg-yellow-500"
  defp utilization_color(_), do: "bg-green-500"
end
