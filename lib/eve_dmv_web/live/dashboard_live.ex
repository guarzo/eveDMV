defmodule EveDmvWeb.DashboardLive do
  @moduledoc """
  Main dashboard LiveView displaying user statistics and recent activity.
  """

  use EveDmvWeb, :live_view
  alias EveDmvWeb.PriceMonitorComponent
  
  # Import reusable components
  import EveDmvWeb.Components.StatsGridComponent

  # Load current user from session on mount
  on_mount({EveDmvWeb.AuthLive, :load_from_session})

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

    <.stats_grid class="mb-8">
      <:stat icon="⚡" label="Total Kills" value={@killmail_count} format="number" />
      <:stat icon="💰" label="ISK Destroyed" value="Coming Soon" color="text-yellow-400" />
      <:stat icon="👥" label="Fleet Engagements" value="Coming Soon" color="text-blue-400" />
    </.stats_grid>

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
    case EveDmv.Database.KillmailRepository.get_recent_high_value(limit: 5, hours_back: 24) do
      {:ok, killmails} -> killmails
      {:error, _reason} -> []
    end
  rescue
    _ -> []
  end
end
