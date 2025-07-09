defmodule EveDmvWeb.MonitoringDashboardLive do
  @moduledoc """
  Live dashboard for monitoring system health, errors, and pipeline status.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Monitoring.{
    ErrorTracker,
    PipelineMonitor,
    AlertDispatcher,
    ErrorRecoveryWorker,
    MissingDataTracker
  }

  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  # 5 seconds
  @refresh_interval 5_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to monitoring events
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "monitoring:updates")

      # Schedule periodic refresh
      :timer.send_interval(@refresh_interval, self(), :refresh)
    end

    socket =
      socket
      |> assign(:page_title, "System Monitoring")
      |> load_monitoring_data()

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, load_monitoring_data(socket)}
  end

  @impl true
  def handle_info({:monitoring_update, _data}, socket) do
    # Real-time updates from monitoring system
    {:noreply, load_monitoring_data(socket)}
  end

  @impl true
  def handle_event("clear_errors", _params, socket) do
    ErrorTracker.clear_all()
    {:noreply, load_monitoring_data(socket)}
  end

  @impl true
  def handle_event("reset_pipeline_metrics", _params, socket) do
    PipelineMonitor.reset_metrics()
    {:noreply, load_monitoring_data(socket)}
  end

  @impl true
  def handle_event("force_recovery_check", _params, socket) do
    ErrorRecoveryWorker.check_now()
    {:noreply, put_flash(socket, :info, "Recovery check initiated")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100">System Monitoring Dashboard</h1>
        <p class="mt-2 text-gray-600 dark:text-gray-400">Real-time system health and error tracking</p>
      </div>
      
      <!-- Pipeline Health Status -->
      <div class="mb-8 bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xl font-semibold text-gray-900 dark:text-gray-100">Pipeline Health</h2>
          <span class={health_badge_class(@pipeline_health.status)}>
            <%= String.upcase(to_string(@pipeline_health.status)) %>
          </span>
        </div>
        
        <%= if @pipeline_health.issues != [] do %>
          <div class="mt-4 space-y-2">
            <p class="text-sm font-medium text-gray-700 dark:text-gray-300">Issues:</p>
            <%= for issue <- @pipeline_health.issues do %>
              <div class="flex items-center text-sm text-red-600 dark:text-red-400">
                <svg class="h-4 w-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                </svg>
                <%= issue %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
      
      <!-- Pipeline Metrics Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <.metric_card
          title="Messages Processed"
          value={@pipeline_metrics.messages.processed}
          subtitle={"Success rate: #{Float.round(@pipeline_metrics.messages.success_rate, 1)}%"}
          icon="hero-check-circle"
          color="green"
        />
        
        <.metric_card
          title="Messages Failed"
          value={@pipeline_metrics.messages.failed}
          subtitle={"Last failure: #{format_relative_time(@pipeline_metrics.last_failure)}"}
          icon="hero-x-circle"
          color="red"
        />
        
        <.metric_card
          title="Avg Processing Time"
          value={"#{Float.round(@pipeline_metrics.performance.avg_processing_time_ms, 1)} ms"}
          subtitle={"P99: #{Float.round(@pipeline_metrics.performance.p99_processing_time_ms, 1)} ms"}
          icon="hero-clock"
          color="blue"
        />
        
        <.metric_card
          title="Batches Processed"
          value={@pipeline_metrics.batches.processed}
          subtitle={"Avg size: #{Float.round(@pipeline_metrics.batches.average_size || 0, 1)}"}
          icon="hero-cube-transparent"
          color="purple"
        />
      </div>
      
      <!-- Data Quality Metrics -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
        <.metric_card
          title="Missing Ship Types"
          value={@missing_ship_types_count}
          subtitle="Unique types not in database"
          icon="hero-exclamation-triangle"
          color="yellow"
        />
        
        <.metric_card
          title="Pipeline Throughput"
          value={"#{Float.round(@pipeline_metrics.messages.processed / max(1, DateTime.diff(DateTime.utc_now(), @pipeline_metrics.started_at, :minute)), 1)}/min"}
          subtitle="Messages per minute"
          icon="hero-arrow-trending-up"
          color="green"
        />
        
        <.metric_card
          title="System Uptime"
          value={format_uptime(@pipeline_metrics.started_at)}
          subtitle="Since last restart"
          icon="hero-server"
          color="blue"
        />
      </div>
      
      <!-- Error Summary -->
      <div class="mb-8 bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xl font-semibold text-gray-900 dark:text-gray-100">Error Summary</h2>
          <div class="flex space-x-2">
            <button
              phx-click="clear_errors"
              class="px-3 py-1 text-sm bg-red-600 text-white rounded hover:bg-red-700"
              data-confirm="Are you sure you want to clear all error data?"
            >
              Clear Errors
            </button>
          </div>
        </div>
        
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
          <div>
            <p class="text-sm text-gray-600 dark:text-gray-400">Total Errors</p>
            <p class="text-2xl font-bold text-gray-900 dark:text-gray-100"><%= @error_summary.total_errors %></p>
          </div>
          <div>
            <p class="text-sm text-gray-600 dark:text-gray-400">Error Rate</p>
            <p class="text-2xl font-bold text-gray-900 dark:text-gray-100">
              <%= Float.round(@error_summary.error_rate, 2) %>/min
            </p>
          </div>
          <div>
            <p class="text-sm text-gray-600 dark:text-gray-400">Retry Success Rate</p>
            <p class="text-2xl font-bold text-gray-900 dark:text-gray-100">
              <%= Float.round(@error_summary.retry_success_rate, 1) %>%
            </p>
          </div>
        </div>
        
        <!-- Top Errors Table -->
        <%= if @error_summary.top_errors != [] do %>
          <div class="mt-6">
            <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-3">Top Errors</h3>
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300 dark:divide-gray-700">
                <thead class="bg-gray-50 dark:bg-gray-900">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Error Code
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Category
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Count
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Last Seen
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                  <%= for error <- @error_summary.top_errors do %>
                    <tr>
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-gray-100">
                        <%= error.code %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                        <span class={category_badge_class(error.category)}>
                          <%= error.category %>
                        </span>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                        <%= error.count %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                        <%= format_relative_time(error.last_seen) %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        <% end %>
      </div>
      
      <!-- Missing Ship Types -->
      <div class="mb-8 bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xl font-semibold text-gray-900 dark:text-gray-100">Missing Ship Types</h2>
          <span class="text-sm text-gray-600 dark:text-gray-400">
            <%= @missing_ship_types_count %> unique types
          </span>
        </div>
        
        <%= if @top_missing_ship_types == [] do %>
          <p class="text-gray-500 dark:text-gray-400 text-center py-8">No missing ship types detected</p>
        <% else %>
          <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
            <table class="min-w-full divide-y divide-gray-300 dark:divide-gray-700">
              <thead class="bg-gray-50 dark:bg-gray-900">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Ship Type ID
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Occurrences
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    First Seen
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Example Characters
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                <%= for ship_type <- @top_missing_ship_types do %>
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-gray-100">
                      <%= ship_type.ship_type_id || "Unknown" %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                      <%= ship_type.occurrence_count %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                      <%= format_relative_time(ship_type.first_seen) %>
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
                      <%= Enum.take(ship_type.example_character_names, 2) |> Enum.join(", ") %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
          <p class="mt-4 text-sm text-gray-600 dark:text-gray-400">
            These ship types are missing from the static data. Consider updating the item types database.
          </p>
        <% end %>
      </div>
      
      <!-- Recent Alerts -->
      <div class="mb-8 bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <h2 class="text-xl font-semibold text-gray-900 dark:text-gray-100 mb-4">Recent Alerts</h2>
        
        <%= if @recent_alerts == [] do %>
          <p class="text-gray-500 dark:text-gray-400 text-center py-8">No recent alerts</p>
        <% else %>
          <div class="space-y-3">
            <%= for alert <- @recent_alerts do %>
              <div class={alert_class(alert.severity)}>
                <div class="flex items-start">
                  <%= render_alert_icon(alert.severity) %>
                  <div class="flex-1">
                    <p class="font-medium"><%= alert.message %></p>
                    <p class="text-sm mt-1">Type: <%= alert.type %> • <%= format_datetime(alert.timestamp) %></p>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
      
      <!-- Recovery Actions -->
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xl font-semibold text-gray-900 dark:text-gray-100">Recovery Actions</h2>
          <button
            phx-click="force_recovery_check"
            class="px-3 py-1 text-sm bg-blue-600 text-white rounded hover:bg-blue-700"
          >
            Force Check
          </button>
        </div>
        
        <%= if @recovery_history == [] do %>
          <p class="text-gray-500 dark:text-gray-400 text-center py-8">No recovery actions taken</p>
        <% else %>
          <div class="space-y-3">
            <%= for action <- @recovery_history do %>
              <div class="border-l-4 border-yellow-400 bg-yellow-50 dark:bg-yellow-900/20 p-4">
                <div class="flex items-start">
                  <svg class="h-5 w-5 text-yellow-600 mr-3 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M18.43 4.935a2.5 2.5 0 00-3.536-3.536L6.435 9.86a1.5 1.5 0 00-.415.915l-.224 2.238a.5.5 0 00.559.559l2.238-.224a1.5 1.5 0 00.915-.415l8.457-8.459z" clip-rule="evenodd" />
                    <path d="M2.5 13.75a.5.5 0 00-.5.5v2.25c0 .28.22.5.5.5h2.25a.5.5 0 00.5-.5v-2.25a.5.5 0 00-.5-.5h-2.25z" />
                  </svg>
                  <div class="flex-1">
                    <p class="font-medium text-yellow-800 dark:text-yellow-200">
                      <%= humanize_recovery_action(action.type) %>
                    </p>
                    <p class="text-sm text-yellow-700 dark:text-yellow-300 mt-1">
                      Reason: <%= action.reason %> • <%= format_datetime(action.timestamp) %>
                    </p>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Component helpers

  defp metric_card(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm text-gray-600 dark:text-gray-400"><%= @title %></p>
          <p class="text-2xl font-bold text-gray-900 dark:text-gray-100 mt-1"><%= @value %></p>
          <%= if @subtitle do %>
            <p class="text-xs text-gray-500 dark:text-gray-500 mt-1"><%= @subtitle %></p>
          <% end %>
        </div>
        <div class={"p-3 rounded-full bg-#{@color}-100 dark:bg-#{@color}-900/20"}>
          <%= render_metric_icon(@icon, @color) %>
        </div>
      </div>
    </div>
    """
  end

  # Private functions

  defp load_monitoring_data(socket) do
    pipeline_metrics = PipelineMonitor.get_metrics()
    pipeline_health = PipelineMonitor.get_health_status()
    error_summary = ErrorTracker.get_summary_report()
    recent_alerts = AlertDispatcher.get_recent_alerts(5)
    recovery_history = ErrorRecoveryWorker.get_recovery_history(5)
    recent_errors = ErrorTracker.get_recent_errors(5)
    missing_ship_types_count = MissingDataTracker.get_missing_ship_types_count()
    top_missing_ship_types = MissingDataTracker.get_top_missing_ship_types(5)

    socket
    |> assign(:pipeline_metrics, pipeline_metrics)
    |> assign(:pipeline_health, pipeline_health)
    |> assign(:error_summary, error_summary)
    |> assign(:recent_alerts, recent_alerts)
    |> assign(:recovery_history, recovery_history)
    |> assign(:recent_errors, recent_errors)
    |> assign(:missing_ship_types_count, missing_ship_types_count)
    |> assign(:top_missing_ship_types, top_missing_ship_types)
  end

  defp health_badge_class(:healthy),
    do:
      "px-3 py-1 text-sm font-medium rounded-full bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400"

  defp health_badge_class(:degraded),
    do:
      "px-3 py-1 text-sm font-medium rounded-full bg-yellow-100 text-yellow-800 dark:bg-yellow-900/20 dark:text-yellow-400"

  defp health_badge_class(:unhealthy),
    do:
      "px-3 py-1 text-sm font-medium rounded-full bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-400"

  defp category_badge_class(:validation),
    do:
      "px-2 py-1 text-xs rounded bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-400"

  defp category_badge_class(:external_service),
    do:
      "px-2 py-1 text-xs rounded bg-purple-100 text-purple-800 dark:bg-purple-900/20 dark:text-purple-400"

  defp category_badge_class(:system),
    do: "px-2 py-1 text-xs rounded bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-400"

  defp category_badge_class(:business_logic),
    do:
      "px-2 py-1 text-xs rounded bg-orange-100 text-orange-800 dark:bg-orange-900/20 dark:text-orange-400"

  defp category_badge_class(_),
    do:
      "px-2 py-1 text-xs rounded bg-gray-100 text-gray-800 dark:bg-gray-900/20 dark:text-gray-400"

  defp alert_class(:critical), do: "border-l-4 border-red-400 bg-red-50 dark:bg-red-900/20 p-4"

  defp alert_class(:high),
    do: "border-l-4 border-orange-400 bg-orange-50 dark:bg-orange-900/20 p-4"

  defp alert_class(:medium),
    do: "border-l-4 border-yellow-400 bg-yellow-50 dark:bg-yellow-900/20 p-4"

  defp alert_class(:low), do: "border-l-4 border-blue-400 bg-blue-50 dark:bg-blue-900/20 p-4"

  defp render_alert_icon(severity) do
    assigns = %{severity: severity}

    ~H"""
    <%= case @severity do %>
      <% :critical -> %>
        <svg class="h-5 w-5 mt-0.5 mr-3 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-6a1 1 0 000 2V6a1 1 0 00-1-1z" clip-rule="evenodd" />
        </svg>
      <% :high -> %>
        <svg class="h-5 w-5 mt-0.5 mr-3 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
        </svg>
      <% :medium -> %>
        <svg class="h-5 w-5 mt-0.5 mr-3 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a.75.75 0 000 1.5h.253a.25.25 0 01.244.304l-.459 2.066A1.75 1.75 0 0010.747 15H11a.75.75 0 000-1.5h-.253a.25.25 0 01-.244-.304l.459-2.066A1.75 1.75 0 009.253 9H9z" clip-rule="evenodd" />
        </svg>
      <% _ -> %>
        <svg class="h-5 w-5 mt-0.5 mr-3 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path d="M10 2a6 6 0 00-6 6v3.586l-.707.707A1 1 0 004 14h12a1 1 0 00.707-1.707L16 11.586V8a6 6 0 00-6-6zM10 18a3 3 0 01-3-3h6a3 3 0 01-3 3z" />
        </svg>
    <% end %>
    """
  end

  defp render_metric_icon(icon_name, color) do
    assigns = %{icon_name: icon_name, color: color}

    ~H"""
    <%= case @icon_name do %>
      <% "hero-check-circle" -> %>
        <svg class={"h-6 w-6 text-#{@color}-600"} fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
        </svg>
      <% "hero-x-circle" -> %>
        <svg class={"h-6 w-6 text-#{@color}-600"} fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
        </svg>
      <% "hero-clock" -> %>
        <svg class={"h-6 w-6 text-#{@color}-600"} fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd" />
        </svg>
      <% "hero-cube-transparent" -> %>
        <svg class={"h-6 w-6 text-#{@color}-600"} fill="currentColor" viewBox="0 0 20 20">
          <path d="M11 17a1 1 0 001.447.894l4-2A1 1 0 0017 15V9.236a1 1 0 00-1.447-.894l-4 2a1 1 0 00-.553.894V17zM15.211 6.276a1 1 0 000-1.788l-4.764-2.382a1 1 0 00-.894 0L4.789 4.488a1 1 0 000 1.788l4.764 2.382a1 1 0 00.894 0l4.764-2.382zM4.447 8.342A1 1 0 003 9.236V15a1 1 0 00.553.894l4 2A1 1 0 009 17v-5.764a1 1 0 00-.553-.894l-4-2z" />
        </svg>
      <% "hero-exclamation-triangle" -> %>
        <svg class={"h-6 w-6 text-#{@color}-600"} fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd" />
        </svg>
      <% "hero-arrow-trending-up" -> %>
        <svg class={"h-6 w-6 text-#{@color}-600"} fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M12.577 4.878a.75.75 0 01.919-.53l4.78 1.281a.75.75 0 01.531.919l-1.281 4.78a.75.75 0 01-1.449-.387l.81-3.022a19.407 19.407 0 00-5.594 5.203.75.75 0 01-1.139.093L7 10.06l-4.72 4.72a.75.75 0 01-1.06-1.061l5.25-5.25a.75.75 0 011.06 0l3.074 3.073a20.923 20.923 0 015.545-4.931l-3.042-.815a.75.75 0 01-.53-.919z" clip-rule="evenodd" />
        </svg>
      <% "hero-server" -> %>
        <svg class={"h-6 w-6 text-#{@color}-600"} fill="currentColor" viewBox="0 0 20 20">
          <path d="M4.464 3.162A2 2 0 016.28 2h7.44a2 2 0 011.816 1.162l1.154 2.5c.067.145.115.291.145.438A3.508 3.508 0 0016 6H4c-.288 0-.568.035-.835.1.03-.147.078-.293.145-.438l1.154-2.5z" />
          <path fill-rule="evenodd" d="M2 9.5a2 2 0 012-2h12a2 2 0 110 4H4a2 2 0 01-2-2zm13.24 0a.75.75 0 01.75-.75H16a.75.75 0 01.75.75v.01a.75.75 0 01-.75.75h-.01a.75.75 0 01-.75-.75V9.5zm-2.25-.75a.75.75 0 00-.75.75v.01c0 .414.336.75.75.75H13a.75.75 0 00.75-.75V9.5a.75.75 0 00-.75-.75h-.01z" clip-rule="evenodd" />
          <path fill-rule="evenodd" d="M2 15a2 2 0 012-2h12a2 2 0 110 4H4a2 2 0 01-2-2zm13.24 0a.75.75 0 01.75-.75H16a.75.75 0 01.75.75v.01a.75.75 0 01-.75.75h-.01a.75.75 0 01-.75-.75V15zm-2.25-.75a.75.75 0 00-.75.75v.01c0 .414.336.75.75.75H13a.75.75 0 00.75-.75V15a.75.75 0 00-.75-.75h-.01z" clip-rule="evenodd" />
        </svg>
      <% _ -> %>
        <svg class={"h-6 w-6 text-#{@color}-600"} fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a.75.75 0 000 1.5h.253a.25.25 0 01.244.304l-.459 2.066A1.75 1.75 0 0010.747 15H11a.75.75 0 000-1.5h-.253a.25.25 0 01-.244-.304l.459-2.066A1.75 1.75 0 009.253 9H9z" clip-rule="evenodd" />
        </svg>
    <% end %>
    """
  end

  defp format_relative_time(nil), do: "Never"

  defp format_relative_time(datetime) do
    minutes = DateTime.diff(DateTime.utc_now(), datetime, :minute)

    cond do
      minutes < 1 -> "Just now"
      minutes < 60 -> "#{minutes}m ago"
      minutes < 1440 -> "#{div(minutes, 60)}h ago"
      true -> "#{div(minutes, 1440)}d ago"
    end
  end

  defp format_datetime(nil), do: "Never"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp humanize_recovery_action(:pipeline_restart), do: "Pipeline Restart"
  defp humanize_recovery_action(:rate_limit_adjustment), do: "Rate Limit Adjustment"
  defp humanize_recovery_action(:health_intervention), do: "Health Intervention"
  defp humanize_recovery_action(:error_spike_response), do: "Error Spike Response"
  defp humanize_recovery_action(action), do: Phoenix.Naming.humanize(action)

  defp format_uptime(nil), do: "Unknown"

  defp format_uptime(started_at) do
    hours = DateTime.diff(DateTime.utc_now(), started_at, :hour)

    cond do
      hours < 1 ->
        minutes = DateTime.diff(DateTime.utc_now(), started_at, :minute)
        "#{minutes}m"

      hours < 24 ->
        "#{hours}h #{rem(DateTime.diff(DateTime.utc_now(), started_at, :minute), 60)}m"

      true ->
        days = div(hours, 24)
        remaining_hours = rem(hours, 24)
        "#{days}d #{remaining_hours}h"
    end
  end
end
