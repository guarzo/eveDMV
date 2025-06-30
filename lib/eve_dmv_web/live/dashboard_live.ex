defmodule EveDmvWeb.DashboardLive do
  @moduledoc """
  Main dashboard LiveView displaying user statistics and recent activity.
  """

  use EveDmvWeb, :live_view
  alias EveDmvWeb.PriceMonitorComponent

  # Load current user from session on mount
  on_mount {EveDmvWeb.AuthLive, :load_from_session}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]

    # Redirect to login if not authenticated
    if current_user do
      socket =
        socket
        |> assign(:page_title, "Dashboard")
        |> assign(:current_user, current_user)
        |> assign(:killmail_count, get_killmail_count())
        |> assign(:recent_kills, get_recent_kills())

      {:ok, socket}
    else
      {:ok, redirect(socket, to: ~p"/login")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.flash_group flash={@flash} />

    <!-- Navigation -->
    <div class="mb-8 flex items-center justify-between">
      <div>
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
      <div class="flex gap-3">
        <.link
          navigate={~p"/feed"}
          class="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors"
        >
          Kill Feed
        </.link>
        <.link
          navigate={~p"/surveillance"}
          class="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors"
        >
          Surveillance
        </.link>
        <.link
          navigate={~p"/profile"}
          class="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors"
        >
          Profile
        </.link>
      </div>
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

    <!-- Main Content Grid -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
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
            <%= if @killmail_count > 0 do %>
              Check out the
              <.link navigate={~p"/feed"} class="text-blue-400 hover:text-blue-300 underline">
                live kill feed
              </.link>
              to see the latest activity.
            <% else %>
              Killmail data is being ingested. Check back soon!
            <% end %>
          </p>
        </div>
      </div>
      
    <!-- Real-time Price Monitor -->
      <.live_component module={PriceMonitorComponent} id="price-monitor" />
    </div>

    <!-- Quick Links -->
    <div class="mt-8 bg-blue-900 border border-blue-700 rounded-lg p-6">
      <h2 class="text-xl font-semibold text-white mb-4">🚀 Available Features</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <.link
          navigate={~p"/feed"}
          class="bg-gray-800 hover:bg-gray-700 rounded-lg p-4 transition-colors"
        >
          <h3 class="text-lg font-medium text-white mb-2">Live Kill Feed</h3>
          <p class="text-gray-400 text-sm">Real-time killmail data with system statistics</p>
        </.link>

        <div class="bg-gray-800 rounded-lg p-4">
          <h3 class="text-lg font-medium text-white mb-2">Character Intelligence</h3>
          <p class="text-gray-400 text-sm">Analyze pilot behavior and combat patterns</p>
          <p class="text-gray-500 text-xs mt-2">
            Enter a character ID in the URL: /intel/CHARACTER_ID
          </p>
        </div>

        <.link
          navigate={~p"/surveillance"}
          class="bg-gray-800 hover:bg-gray-700 rounded-lg p-4 transition-colors"
        >
          <h3 class="text-lg font-medium text-white mb-2">Surveillance Profiles</h3>
          <p class="text-gray-400 text-sm">Monitor hostile activity with custom filters</p>
        </.link>

        <div class="bg-gray-800 opacity-50 rounded-lg p-4">
          <h3 class="text-lg font-medium text-gray-500 mb-2">
            Fleet Analysis <span class="text-xs">(Coming Soon)</span>
          </h3>
          <p class="text-gray-600 text-sm">Optimize compositions and combat effectiveness</p>
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
