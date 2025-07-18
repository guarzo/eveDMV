defmodule EveDmvWeb.Admin.PerformanceDashboardLive do
  @moduledoc """
  Real-time performance monitoring dashboard for EVE DMV.
  Provides visibility into query performance, bottlenecks, and system health.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Monitoring.PerformanceTracker
  alias EveDmv.Cache.QueryCache
  require Logger

  # 5 seconds
  @refresh_interval 5_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :refresh_metrics)
    end

    socket =
      socket
      |> assign(:page_title, "Performance Dashboard")
      |> assign(:time_range, :hour)
      |> assign(:threshold_ms, 1000)
      |> load_metrics()

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh_metrics, socket) do
    {:noreply, load_metrics(socket)}
  end

  @impl true
  def handle_event("change_time_range", %{"range" => range}, socket) do
    time_range = String.to_existing_atom(range)

    socket =
      socket
      |> assign(:time_range, time_range)
      |> load_metrics()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_threshold", %{"threshold" => threshold}, socket) do
    case Integer.parse(threshold) do
      {threshold_ms, _} ->
        socket =
          socket
          |> assign(:threshold_ms, threshold_ms)
          |> load_metrics()

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-white mb-2">Performance Dashboard</h1>
        <p class="text-gray-400">Real-time monitoring of system performance and bottlenecks</p>
      </div>
      
      <!-- Controls -->
      <div class="bg-gray-800 rounded-lg p-4 mb-6">
        <div class="flex flex-wrap gap-4">
          <div>
            <label class="text-sm text-gray-400">Time Range</label>
            <select 
              phx-change="change_time_range" 
              name="range"
              class="ml-2 bg-gray-700 text-white rounded px-3 py-1"
            >
              <option value="minute" selected={@time_range == :minute}>Last Minute</option>
              <option value="hour" selected={@time_range == :hour}>Last Hour</option>
              <option value="day" selected={@time_range == :day}>Last 24 Hours</option>
            </select>
          </div>
          
          <div>
            <label class="text-sm text-gray-400">Slow Query Threshold (ms)</label>
            <input 
              type="number" 
              phx-change="change_threshold"
              name="threshold"
              value={@threshold_ms}
              class="ml-2 bg-gray-700 text-white rounded px-3 py-1 w-24"
            />
          </div>
        </div>
      </div>
      
      <!-- Metrics Summary -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <%= for {type, label} <- [{:query, "Database Queries"}, {:api_call, "API Calls"}, {:liveview, "LiveView Operations"}] do %>
          <div class="bg-gray-800 rounded-lg p-6">
            <h3 class="text-lg font-semibold text-white mb-4"><%= label %></h3>
            <%= if stats = @metrics_summary[type] do %>
              <div class="space-y-2 text-sm">
                <div class="flex justify-between">
                  <span class="text-gray-400">Total Count:</span>
                  <span class="text-white"><%= stats.count %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-400">Average:</span>
                  <span class="text-white"><%= stats.avg %>ms</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-400">Min/Max:</span>
                  <span class="text-white"><%= stats.min %>ms / <%= stats.max %>ms</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-400">P50/P95/P99:</span>
                  <span class="text-white">
                    <%= stats.p50 %>ms / <%= stats.p95 %>ms / <%= stats.p99 %>ms
                  </span>
                </div>
              </div>
            <% else %>
              <p class="text-gray-500">No data available</p>
            <% end %>
          </div>
        <% end %>
      </div>
      
      <!-- Bottlenecks Analysis -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        <!-- Slow Queries -->
        <div class="bg-gray-800 rounded-lg p-6">
          <h3 class="text-lg font-semibold text-white mb-4">
            Slow Queries (><%= @threshold_ms %>ms)
          </h3>
          <%= if @slow_queries != [] do %>
            <div class="space-y-2">
              <%= for query <- Enum.take(@slow_queries, 10) do %>
                <div class="bg-gray-700 rounded p-3">
                  <div class="flex justify-between items-start">
                    <span class="text-sm text-gray-300 font-mono flex-1">
                      <%= truncate_string(query.name, 50) %>
                    </span>
                    <span class="text-sm text-red-400 ml-2">
                      <%= query.duration_ms %>ms
                    </span>
                  </div>
                  <div class="text-xs text-gray-500 mt-1">
                    <%= format_timestamp(query.timestamp) %>
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <p class="text-gray-500">No slow queries detected</p>
          <% end %>
        </div>
        
        <!-- Performance Degradation -->
        <div class="bg-gray-800 rounded-lg p-6">
          <h3 class="text-lg font-semibold text-white mb-4">
            Performance Degradation Detected
          </h3>
          <%= if @bottlenecks.performance_degradation != [] do %>
            <div class="space-y-2">
              <%= for item <- Enum.take(@bottlenecks.performance_degradation, 10) do %>
                <div class="bg-gray-700 rounded p-3">
                  <div class="flex justify-between items-start">
                    <span class="text-sm text-gray-300">
                      <%= item.type %>: <%= truncate_string(item.name, 40) %>
                    </span>
                    <span class={"text-sm #{degradation_color(item.degradation_pct)}"}>
                      +<%= Float.round(item.degradation_pct, 1) %>%
                    </span>
                  </div>
                  <div class="text-xs text-gray-500 mt-1">
                    <%= item.older_avg_ms %>ms → <%= item.recent_avg_ms %>ms
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <p class="text-gray-500">No performance degradation detected</p>
          <% end %>
        </div>
      </div>
      
      <!-- Cache Statistics -->
      <div class="bg-gray-800 rounded-lg p-6 mb-8">
        <h3 class="text-lg font-semibold text-white mb-4">Query Cache Statistics</h3>
        <%= if @cache_stats do %>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div>
              <div class="text-sm text-gray-400">Hit Rate</div>
              <div class="text-2xl font-bold text-green-400"><%= @cache_stats.hit_rate %>%</div>
            </div>
            <div>
              <div class="text-sm text-gray-400">Total Hits</div>
              <div class="text-xl font-semibold text-white"><%= @cache_stats.hits %></div>
            </div>
            <div>
              <div class="text-sm text-gray-400">Total Misses</div>
              <div class="text-xl font-semibold text-white"><%= @cache_stats.misses %></div>
            </div>
            <div>
              <div class="text-sm text-gray-400">Cache Size</div>
              <div class="text-xl font-semibold text-white">
                <%= @cache_stats.cache_size %> entries
                <span class="text-sm text-gray-400">(<%= @cache_stats.memory_mb %>MB)</span>
              </div>
            </div>
          </div>
          <div class="mt-4 text-sm text-gray-400">
            Evictions: <%= @cache_stats.evictions %> | 
            Uptime: <%= @cache_stats.uptime_hours %>h
          </div>
        <% else %>
          <p class="text-gray-500">Cache statistics unavailable</p>
        <% end %>
      </div>
      
      <!-- High Frequency Operations -->
      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-lg font-semibold text-white mb-4">
          High Frequency Operations (Total Time Impact)
        </h3>
        <%= if @bottlenecks.high_frequency != [] do %>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="text-gray-400 border-b border-gray-700">
                  <th class="text-left pb-2">Type</th>
                  <th class="text-left pb-2">Operation</th>
                  <th class="text-right pb-2">Count</th>
                  <th class="text-right pb-2">Total Time</th>
                  <th class="text-right pb-2">Avg Time</th>
                </tr>
              </thead>
              <tbody>
                <%= for op <- Enum.take(@bottlenecks.high_frequency, 15) do %>
                  <tr class="border-b border-gray-700">
                    <td class="py-2 text-gray-400"><%= op.type %></td>
                    <td class="py-2 text-gray-300"><%= truncate_string(op.name, 60) %></td>
                    <td class="py-2 text-right text-white"><%= op.count %></td>
                    <td class="py-2 text-right text-orange-400">
                      <%= format_duration(op.total_time_ms) %>
                    </td>
                    <td class="py-2 text-right text-gray-400">
                      <%= div(op.total_time_ms, op.count) %>ms
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% else %>
          <p class="text-gray-500">No high frequency operations detected</p>
        <% end %>
      </div>
    </div>
    """
  end

  # Private functions

  defp load_metrics(socket) do
    metrics_summary = PerformanceTracker.get_metrics_summary(socket.assigns.time_range)
    slow_queries = PerformanceTracker.get_slow_queries(socket.assigns.threshold_ms)
    bottlenecks = PerformanceTracker.get_bottlenecks()
    cache_stats = QueryCache.get_stats()

    socket
    |> assign(:metrics_summary, metrics_summary)
    |> assign(:slow_queries, slow_queries)
    |> assign(:bottlenecks, bottlenecks)
    |> assign(:cache_stats, cache_stats)
  end

  defp truncate_string(str, max_length) do
    if String.length(str) > max_length do
      String.slice(str, 0, max_length - 3) <> "..."
    else
      str
    end
  end

  defp format_timestamp(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S")
  end

  defp format_duration(ms) when ms >= 60_000 do
    minutes = div(ms, 60_000)
    seconds = rem(ms, 60_000) / 1_000
    "#{minutes}m #{Float.round(seconds, 1)}s"
  end

  defp format_duration(ms) when ms >= 1_000 do
    "#{Float.round(ms / 1_000, 1)}s"
  end

  defp format_duration(ms), do: "#{ms}ms"

  defp degradation_color(pct) when pct > 50, do: "text-red-400"
  defp degradation_color(pct) when pct > 20, do: "text-orange-400"
  defp degradation_color(_), do: "text-yellow-400"
end
