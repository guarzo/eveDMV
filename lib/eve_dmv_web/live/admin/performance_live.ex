defmodule EveDmvWeb.Admin.PerformanceLive do
  @moduledoc """
  Sprint 15A: Real-time performance monitoring dashboard.

  Displays system performance metrics, alerts, and trends for administrators.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Monitoring.PerformanceDashboard
  alias Phoenix.PubSub

  # 5 seconds
  @refresh_interval 5_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to performance updates
      PerformanceDashboard.subscribe()
      PubSub.subscribe(EveDmv.PubSub, "performance:alerts")

      # Schedule periodic refresh
      Process.send_after(self(), :refresh, @refresh_interval)
    end

    # Load initial metrics
    metrics = PerformanceDashboard.get_metrics()
    report = PerformanceDashboard.generate_report(60)

    socket =
      socket
      |> assign(:page_title, "Performance Monitor")
      |> assign(:metrics, metrics)
      |> assign(:report, report)
      |> assign(:selected_tab, :overview)
      |> assign(:auto_refresh, true)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    tab = String.to_existing_atom(params["tab"] || "overview")
    {:noreply, assign(socket, :selected_tab, tab)}
  end

  @impl true
  def handle_event("select_tab", %{"tab" => tab}, socket) do
    {:noreply,
     socket
     |> assign(:selected_tab, String.to_existing_atom(tab))
     |> push_patch(to: ~p"/admin/performance?tab=#{tab}")}
  end

  def handle_event("toggle_refresh", _params, socket) do
    auto_refresh = !socket.assigns.auto_refresh

    if auto_refresh do
      Process.send_after(self(), :refresh, @refresh_interval)
    end

    {:noreply, assign(socket, :auto_refresh, auto_refresh)}
  end

  def handle_event("clear_alerts", _params, socket) do
    # In a real implementation, this would clear alerts in the dashboard
    {:noreply, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    if socket.assigns.auto_refresh do
      # Refresh metrics
      metrics = PerformanceDashboard.get_metrics()
      report = PerformanceDashboard.generate_report(60)

      socket =
        socket
        |> assign(:metrics, metrics)
        |> assign(:report, report)

      # Schedule next refresh
      Process.send_after(self(), :refresh, @refresh_interval)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:metrics_update, metrics}, socket) do
    # Real-time metric updates
    {:noreply, assign(socket, :metrics, metrics)}
  end

  def handle_info({:performance_alert, alert}, socket) do
    # Add new alert to report
    report = socket.assigns.report
    alerts = [alert | report.alerts] |> Enum.take(50)
    updated_report = %{report | alerts: alerts}

    {:noreply, assign(socket, :report, updated_report)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="performance-dashboard">
      <div class="dashboard-header">
        <h1 class="text-2xl font-bold">Performance Monitor</h1>
        <div class="controls">
          <button 
            phx-click="toggle_refresh" 
            class={"btn " <> if @auto_refresh, do: "btn-primary", else: "btn-secondary"}
          >
            <%= if @auto_refresh, do: "Auto Refresh: ON", else: "Auto Refresh: OFF" %>
          </button>
        </div>
      </div>
      
      <div class="tabs">
        <button 
          phx-click="select_tab" 
          phx-value-tab="overview" 
          class={"tab " <> if @selected_tab == :overview, do: "active", else: ""}
        >
          Overview
        </button>
        <button 
          phx-click="select_tab" 
          phx-value-tab="queries" 
          class={"tab " <> if @selected_tab == :queries, do: "active", else: ""}
        >
          Queries
        </button>
        <button 
          phx-click="select_tab" 
          phx-value-tab="cache" 
          class={"tab " <> if @selected_tab == :cache, do: "active", else: ""}
        >
          Cache
        </button>
        <button 
          phx-click="select_tab" 
          phx-value-tab="memory" 
          class={"tab " <> if @selected_tab == :memory, do: "active", else: ""}
        >
          Memory
        </button>
        <button 
          phx-click="select_tab" 
          phx-value-tab="alerts" 
          class={"tab " <> if @selected_tab == :alerts, do: "active", else: ""}
        >
          Alerts <%= if length(@report.alerts) > 0, do: "(#{length(@report.alerts)})", else: "" %>
        </button>
      </div>
      
      <div class="tab-content">
        <%= case @selected_tab do %>
          <% :overview -> %>
            <.overview_tab metrics={@metrics} report={@report} />
          <% :queries -> %>
            <.queries_tab metrics={@metrics} report={@report} />
          <% :cache -> %>
            <.cache_tab metrics={@metrics} />
          <% :memory -> %>
            <.memory_tab metrics={@metrics} />
          <% :alerts -> %>
            <.alerts_tab alerts={@report.alerts} />
        <% end %>
      </div>
    </div>
    """
  end

  # Component: Overview Tab
  defp overview_tab(assigns) do
    ~H"""
    <div class="overview-grid">
      <div class="metric-card">
        <h3>System Uptime</h3>
        <div class="metric-value"><%= @report.summary.uptime %></div>
      </div>
      
      <div class="metric-card">
        <h3>Total Queries</h3>
        <div class="metric-value"><%= format_number(@metrics.queries.count) %></div>
        <div class="metric-sub">
          Avg: <%= @metrics.queries.stats.avg_duration %>ms
        </div>
      </div>
      
      <div class="metric-card">
        <h3>Cache Hit Rate</h3>
        <div class={"metric-value #{cache_hit_class(@metrics.cache.hit_rate)}"}>
          <%= @metrics.cache.hit_rate %>%
        </div>
        <div class="metric-sub">
          <%= format_number(@metrics.cache.hits) %> hits / 
          <%= format_number(@metrics.cache.misses) %> misses
        </div>
      </div>
      
      <div class="metric-card">
        <h3>Memory Usage</h3>
        <div class={"metric-value #{memory_class(@metrics.memory.total_mb)}"}>
          <%= round(@metrics.memory.total_mb) %> MB
        </div>
      </div>
      
      <div class="metric-card">
        <h3>Broadway Pipeline</h3>
        <div class="metric-value">
          <%= format_number(@metrics.broadway.messages_processed) %>
        </div>
        <div class="metric-sub">
          Messages processed
        </div>
      </div>
      
      <div class="metric-card">
        <h3>Import Activity</h3>
        <div class="metric-value">
          <%= format_number(@metrics.imports.total_processed) %>
        </div>
        <div class="metric-sub">
          Killmails imported
        </div>
      </div>
    </div>

    <div class="trends-section">
      <h2>Performance Trends</h2>
      <div class="trends-grid">
        <.trend_indicator 
          label="Cache Performance" 
          trend={@report.trends.cache_hit_trend} 
        />
        <.trend_indicator 
          label="Memory Usage" 
          trend={@report.trends.memory_trend}
          inverse={true} 
        />
        <.trend_indicator 
          label="Query Rate" 
          trend={@report.trends.query_rate_trend} 
        />
      </div>
    </div>
    """
  end

  # Component: Queries Tab
  defp queries_tab(assigns) do
    ~H"""
    <div class="queries-section">
      <div class="query-stats">
        <div class="stat-box">
          <h3>Query Performance</h3>
          <table class="stats-table">
            <tr>
              <td>P50 (Median)</td>
              <td><%= @metrics.queries.stats.p50 %>ms</td>
            </tr>
            <tr>
              <td>P95</td>
              <td><%= @metrics.queries.stats.p95 %>ms</td>
            </tr>
            <tr>
              <td>P99</td>
              <td><%= @metrics.queries.stats.p99 %>ms</td>
            </tr>
            <tr>
              <td>Average</td>
              <td><%= @metrics.queries.stats.avg_duration %>ms</td>
            </tr>
          </table>
        </div>
      </div>
      
      <div class="top-queries">
        <h3>Top Queries by Total Time</h3>
        <table class="data-table">
          <thead>
            <tr>
              <th>Query Name</th>
              <th>Count</th>
              <th>Avg Duration</th>
              <th>Total Time</th>
            </tr>
          </thead>
          <tbody>
            <%= for {name, stats} <- @report.performance.top_queries do %>
              <tr>
                <td><%= name %></td>
                <td><%= format_number(stats.count) %></td>
                <td><%= stats.avg_duration %>ms</td>
                <td><%= format_duration_ms(stats.total_duration) %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
      
      <%= if length(@metrics.queries.slow_queries) > 0 do %>
        <div class="slow-queries">
          <h3>Recent Slow Queries</h3>
          <table class="data-table">
            <thead>
              <tr>
                <th>Query</th>
                <th>Duration</th>
                <th>Time</th>
              </tr>
            </thead>
            <tbody>
              <%= for query <- Enum.take(@metrics.queries.slow_queries, 10) do %>
                <tr>
                  <td class="query-name"><%= query.name %></td>
                  <td class="duration-critical"><%= query.duration %>ms</td>
                  <td><%= format_time(query.timestamp) %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  # Component: Cache Tab
  defp cache_tab(assigns) do
    ~H"""
    <div class="cache-section">
      <div class="cache-overview">
        <div class="cache-chart">
          <h3>Cache Performance</h3>
          <div class="hit-rate-display">
            <div class={"rate-value #{cache_hit_class(@metrics.cache.hit_rate)}"}>
              <%= @metrics.cache.hit_rate %>%
            </div>
            <div class="rate-label">Hit Rate</div>
          </div>
        </div>
        
        <div class="cache-stats">
          <h3>Cache Statistics</h3>
          <table class="stats-table">
            <tr>
              <td>Total Hits</td>
              <td><%= format_number(@metrics.cache.hits) %></td>
            </tr>
            <tr>
              <td>Total Misses</td>
              <td><%= format_number(@metrics.cache.misses) %></td>
            </tr>
            <tr>
              <td>Invalidations</td>
              <td><%= format_number(@metrics.cache.invalidations) %></td>
            </tr>
            <tr>
              <td>Efficiency</td>
              <td><%= calculate_cache_efficiency(@metrics.cache) %>%</td>
            </tr>
          </table>
        </div>
      </div>
      
      <div class="cache-recommendations">
        <h3>Recommendations</h3>
        <%= cache_recommendations(@metrics.cache) %>
      </div>
    </div>
    """
  end

  # Component: Memory Tab
  defp memory_tab(assigns) do
    ~H"""
    <div class="memory-section">
      <div class="memory-overview">
        <h3>Memory Usage: <%= round(@metrics.memory.total_mb) %> MB</h3>
      </div>
      
      <div class="memory-breakdown">
        <div class="process-memory">
          <h3>Top Processes by Memory</h3>
          <table class="data-table">
            <thead>
              <tr>
                <th>Process</th>
                <th>Memory</th>
                <th>Message Queue</th>
              </tr>
            </thead>
            <tbody>
              <%= for process <- Enum.take(@metrics.memory.process_memory, 10) do %>
                <tr>
                  <td><%= inspect(process.name) %></td>
                  <td><%= Float.round(process.memory_mb, 2) %> MB</td>
                  <td><%= process.message_queue %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
        
        <div class="ets-memory">
          <h3>ETS Tables</h3>
          <table class="data-table">
            <thead>
              <tr>
                <th>Table</th>
                <th>Size</th>
                <th>Memory</th>
              </tr>
            </thead>
            <tbody>
              <%= for table <- @metrics.memory.ets_tables do %>
                <tr>
                  <td><%= inspect(table.name) %></td>
                  <td><%= format_number(table.size) %></td>
                  <td><%= Float.round(table.memory_mb, 2) %> MB</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  # Component: Alerts Tab
  defp alerts_tab(assigns) do
    ~H"""
    <div class="alerts-section">
      <div class="alerts-header">
        <h3>Performance Alerts</h3>
        <button phx-click="clear_alerts" class="btn btn-secondary">
          Clear All
        </button>
      </div>
      
      <%= if length(@alerts) == 0 do %>
        <div class="no-alerts">
          ✅ No active performance alerts
        </div>
      <% else %>
        <div class="alerts-list">
          <%= for alert <- @alerts do %>
            <div class={"alert alert-" <> to_string(alert.level)}>
              <div class="alert-header">
                <span class="alert-level"><%= alert.level %></span>
                <span class="alert-time"><%= format_time(alert.timestamp) %></span>
              </div>
              <div class="alert-message"><%= alert.message %></div>
              <%= if map_size(alert.details) > 0 do %>
                <div class="alert-details">
                  <pre><%= Jason.encode!(alert.details, pretty: true) %></pre>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Component: Trend Indicator
  defp trend_indicator(assigns) do
    ~H"""
    <div class="trend-indicator">
      <div class="trend-label"><%= @label %></div>
      <div class={"trend-value " <> trend_class(@trend, @inverse)}>
        <%= trend_icon(@trend.direction) %>
        <%= @trend.percentage %>%
      </div>
    </div>
    """
  end

  # Helper functions

  defp format_number(n) when n > 1_000_000 do
    "#{Float.round(n / 1_000_000, 1)}M"
  end

  defp format_number(n) when n > 1_000 do
    "#{Float.round(n / 1_000, 1)}K"
  end

  defp format_number(n), do: to_string(n)

  defp format_duration_ms(ms) when ms > 60_000 do
    "#{round(ms / 60_000)}m"
  end

  defp format_duration_ms(ms) when ms > 1_000 do
    "#{Float.round(ms / 1_000, 1)}s"
  end

  defp format_duration_ms(ms), do: "#{ms}ms"

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S")
  end

  defp cache_hit_class(rate) when rate >= 90, do: "metric-good"
  defp cache_hit_class(rate) when rate >= 70, do: "metric-warning"
  defp cache_hit_class(_), do: "metric-critical"

  defp memory_class(mb) when mb < 1000, do: "metric-good"
  defp memory_class(mb) when mb < 2000, do: "metric-warning"
  defp memory_class(_), do: "metric-critical"

  defp trend_class(%{direction: :up}, true), do: "trend-bad"
  defp trend_class(%{direction: :up}, _), do: "trend-good"
  defp trend_class(%{direction: :down}, true), do: "trend-good"
  defp trend_class(%{direction: :down}, _), do: "trend-bad"
  defp trend_class(_, _), do: "trend-neutral"

  defp trend_icon(:up), do: "↑"
  defp trend_icon(:down), do: "↓"
  defp trend_icon(:stable), do: "→"

  defp calculate_cache_efficiency(cache) do
    avoided_misses = cache.hits
    potential_operations = cache.hits + cache.misses + cache.invalidations

    if potential_operations > 0 do
      Float.round(avoided_misses / potential_operations * 100, 2)
    else
      0.0
    end
  end

  defp cache_recommendations(cache) do
    cond do
      cache.hit_rate < 50 ->
        "⚠️ Very low hit rate. Consider reviewing cache TTLs and invalidation patterns."

      cache.hit_rate < 70 ->
        "⚠️ Below target hit rate. Check for aggressive invalidation or short TTLs."

      cache.invalidations > cache.hits ->
        "⚠️ High invalidation rate. Review invalidation patterns for optimization."

      true ->
        "✅ Cache performance is within acceptable parameters."
    end
  end
end
