defmodule EveDmvWeb.DashboardLive do
  @moduledoc """
  Main dashboard LiveView displaying user statistics and recent activity.
  """

  use EveDmvWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]

    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:current_user, current_user)
      |> assign(:killmail_count, get_killmail_count())
      |> assign(:recent_kills, get_recent_kills())

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.flash_group flash={@flash} />

    <div class="mb-8">
      <h1 class="text-3xl font-bold text-white mb-2">
        Welcome back, {@current_user.eve_character_name}
      </h1>
      <p class="text-gray-400">
        {@current_user.eve_corporation_name || "Independent Pilot"}
        <%= if @current_user.eve_alliance_name do %>
          • {@current_user.eve_alliance_name}
        <% end %>
      </p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
      <!-- Stats Cards -->
      <div class="bg-gray-800 rounded-lg p-6">
        <div class="flex items-center">
          <div class="p-3 bg-red-600 rounded-full">
            <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M13 10V3L4 14h7v7l9-11h-7z"
              />
            </svg>
          </div>
          <div class="ml-4">
            <h2 class="text-sm font-medium text-gray-400">Total Kills</h2>
            <p class="text-2xl font-semibold text-white">{@killmail_count}</p>
          </div>
        </div>
      </div>

      <div class="bg-gray-800 rounded-lg p-6">
        <div class="flex items-center">
          <div class="p-3 bg-yellow-600 rounded-full">
            <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"
              />
            </svg>
          </div>
          <div class="ml-4">
            <h2 class="text-sm font-medium text-gray-400">ISK Destroyed</h2>
            <p class="text-2xl font-semibold text-white">Coming Soon</p>
          </div>
        </div>
      </div>

      <div class="bg-gray-800 rounded-lg p-6">
        <div class="flex items-center">
          <div class="p-3 bg-blue-600 rounded-full">
            <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
              />
            </svg>
          </div>
          <div class="ml-4">
            <h2 class="text-sm font-medium text-gray-400">Fleet Engagements</h2>
            <p class="text-2xl font-semibold text-white">Coming Soon</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Recent Activity Section -->
    <div class="bg-gray-800 rounded-lg p-6">
      <h2 class="text-xl font-semibold text-white mb-4">Recent Activity</h2>
      <div class="text-center py-12">
        <svg
          class="mx-auto h-12 w-12 text-gray-400 mb-4"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
          />
        </svg>
        <h3 class="text-lg font-medium text-gray-300 mb-2">No activity yet</h3>
        <p class="text-gray-400">
          Killmail data will appear here once the ingestion pipeline is set up in Epic 3.
        </p>
      </div>
    </div>

    <!-- Next Steps -->
    <div class="mt-8 bg-blue-900 border border-blue-700 rounded-lg p-6">
      <h2 class="text-xl font-semibold text-white mb-4">🚧 Development Progress</h2>
      <div class="space-y-3">
        <div class="flex items-center">
          <svg class="w-5 h-5 text-green-400 mr-3" fill="currentColor" viewBox="0 0 20 20">
            <path
              fill-rule="evenodd"
              d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
              clip-rule="evenodd"
            />
          </svg>
          <span class="text-green-300 font-medium">Epic 1: Database Foundation & Schema</span>
          <span class="ml-2 text-green-400 text-sm">(Complete)</span>
        </div>
        <div class="flex items-center">
          <svg class="w-5 h-5 text-green-400 mr-3" fill="currentColor" viewBox="0 0 20 20">
            <path
              fill-rule="evenodd"
              d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
              clip-rule="evenodd"
            />
          </svg>
          <span class="text-green-300 font-medium">Epic 2: Authentication & User Management</span>
          <span class="ml-2 text-green-400 text-sm">(In Progress)</span>
        </div>
        <div class="flex items-center">
          <svg
            class="w-5 h-5 text-gray-400 mr-3"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 6v6m0 0v6m0-6h6m-6 0H6"
            />
          </svg>
          <span class="text-gray-300">Epic 3: Killmail Ingestion Pipeline</span>
          <span class="ml-2 text-gray-400 text-sm">(Next)</span>
        </div>
      </div>
    </div>
    """
  end

  # Private helper functions

  defp get_killmail_count do
    EveDmv.Killmails.KillmailRaw
    |> Ash.Query.new()
    |> Ash.count!(domain: EveDmv.Api)
  rescue
    _ -> 0
  end

  defp get_recent_kills do
    EveDmv.Killmails.KillmailRaw
    |> Ash.Query.new()
    |> Ash.Query.sort(killmail_time: :desc)
    |> Ash.Query.limit(5)
    |> Ash.read!(domain: EveDmv.Api)
  rescue
    _ -> []
  end
end
