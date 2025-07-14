defmodule EveDmvWeb.ProfileLive do
  @moduledoc """
  User profile LiveView for managing account settings and preferences.
  """

  use EveDmvWeb, :live_view

  # Load current user from session on mount
  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    current_user = socket.assigns[:current_user]

    if current_user do
      socket =
        socket
        |> assign(:page_title, "Profile")
        |> assign(:current_user, current_user)
        |> assign(:loading_stats, true)
        |> load_character_stats()

      {:ok, socket}
    else
      # Check if we have an invalid session (user ID exists but user doesn't)
      if Map.get(session, "current_user_id") do
        {:ok, redirect(socket, to: ~p"/session/clear")}
      else
        # Redirect to login if not authenticated
        {:ok, redirect(socket, to: ~p"/login")}
      end
    end
  end

  # Helper functions

  defp load_character_stats(socket) do
    current_user = socket.assigns.current_user

    # Async load stats
    Task.start(fn ->
      stats = get_character_combat_stats(current_user.eve_character_id)
      ship_intelligence = get_character_ship_intelligence(current_user.eve_character_id)

      send(self(), {:stats_loaded, stats, ship_intelligence})
    end)

    socket
  end

  @impl Phoenix.LiveView
  def handle_info({:stats_loaded, stats, ship_intelligence}, socket) do
    {:noreply,
     socket
     |> assign(:loading_stats, false)
     |> assign(:combat_stats, stats)
     |> assign(:ship_intelligence, ship_intelligence)}
  end

  defp character_portrait(character_id, size \\ 128) do
    "https://images.evetech.net/characters/#{character_id}/portrait?size=#{size}"
  end

  defp get_character_combat_stats(character_id) do
    case EveDmv.Contexts.CharacterIntelligence.get_character_intelligence_report(character_id) do
      {:ok, report} -> report.combat_stats
      _ -> nil
    end
  end

  defp get_character_ship_intelligence(character_id) do
    case EveDmv.Integrations.ShipIntelligenceBridge.calculate_ship_specialization(character_id) do
      {:ok, intelligence} -> intelligence
      _ -> nil
    end
  end

  # defp format_isk(amount) when amount >= 1_000_000_000 do
  #   "#{Float.round(amount / 1_000_000_000, 1)}B ISK"
  # end

  # defp format_isk(amount) when amount >= 1_000_000 do
  #   "#{Float.round(amount / 1_000_000, 1)}M ISK"
  # end

  # defp format_isk(amount) when amount >= 1_000 do
  #   "#{Float.round(amount / 1_000, 1)}K ISK"
  # end

  # defp format_isk(amount), do: "#{amount} ISK"

  # defp expertise_level_color(:expert), do: "text-purple-400"
  # defp expertise_level_color(:experienced), do: "text-blue-400"
  # defp expertise_level_color(:competent), do: "text-green-400"
  # defp expertise_level_color(:novice), do: "text-yellow-400"
  # defp expertise_level_color(_), do: "text-gray-400"

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.flash_group flash={@flash} />

    <div class="max-w-4xl mx-auto">
      <!-- Navigation -->
      <div class="mb-8 flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-bold text-white mb-2">Character Profile</h1>
          <p class="text-gray-400">Manage your EVE Online character information and preferences.</p>
        </div>
        <div class="flex gap-3">
          <.link
            navigate={~p"/dashboard"}
            class="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors"
          >
            Dashboard
          </.link>
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
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <!-- Enhanced Character Card -->
        <div class="bg-gray-800 rounded-lg p-6">
          <div class="text-center">
            <!-- EVE Character Portrait -->
            <img 
              src={character_portrait(@current_user.eve_character_id)} 
              alt="Character portrait"
              class="w-32 h-32 rounded-lg mx-auto mb-4 border-2 border-gray-600"
            />
            <h2 class="text-xl font-semibold text-white mb-2">
              {@current_user.eve_character_name}
            </h2>
            <p class="text-gray-400 text-sm mb-2">
              {@current_user.eve_corporation_name || "Independent Pilot"}
            </p>
            <%= if @current_user.eve_alliance_name do %>
              <p class="text-blue-400 text-sm mb-2">
                {@current_user.eve_alliance_name}
              </p>
            <% end %>
            <p class="text-gray-500 text-xs mb-4">
              ID: {@current_user.eve_character_id}
            </p>
            
            <!-- Quick Combat Stats -->
            <%= if assigns[:combat_stats] && @combat_stats do %>
              <div class="mt-4 p-3 bg-gray-900 rounded-lg">
                <div class="grid grid-cols-2 gap-3 text-center">
                  <div>
                    <p class="text-green-400 font-bold text-lg">{@combat_stats.total_kills}</p>
                    <p class="text-gray-400 text-xs">Kills</p>
                  </div>
                  <div>
                    <p class="text-red-400 font-bold text-lg">{@combat_stats.total_losses}</p>
                    <p class="text-gray-400 text-xs">Losses</p>
                  </div>
                </div>
                <div class="mt-2 pt-2 border-t border-gray-700">
                  <p class="text-blue-400 font-bold">{@combat_stats.isk_efficiency}%</p>
                  <p class="text-gray-400 text-xs">ISK Efficiency</p>
                </div>
              </div>
            <% else %>
              <%= if assigns[:loading_stats] && @loading_stats do %>
                <div class="mt-4 p-3 bg-gray-900 rounded-lg">
                  <div class="animate-pulse">
                    <div class="h-4 bg-gray-700 rounded mb-2"></div>
                    <div class="h-3 bg-gray-700 rounded"></div>
                  </div>
                </div>
              <% end %>
            <% end %>
            
            <p class="text-gray-400 text-sm mt-4">
              Last Login:
              <%= if @current_user.last_login_at do %>
                {Calendar.strftime(@current_user.last_login_at, "%Y-%m-%d %H:%M UTC")}
              <% else %>
                Never
              <% end %>
            </p>
          </div>
        </div>

    <!-- Character Information -->
        <div class="lg:col-span-2 bg-gray-800 rounded-lg p-6">
          <h3 class="text-lg font-semibold text-white mb-4">Character Information</h3>

          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-300 mb-1">Character Name</label>
              <div class="bg-gray-700 px-3 py-2 rounded-md text-white">
                {@current_user.eve_character_name}
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-300 mb-1">Corporation</label>
              <div class="bg-gray-700 px-3 py-2 rounded-md text-white">
                {@current_user.eve_corporation_name || "Unknown Corporation"}
                <%= if @current_user.eve_corporation_id do %>
                  <span class="text-gray-400 text-sm">(ID: {@current_user.eve_corporation_id})</span>
                <% end %>
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-300 mb-1">Alliance</label>
              <div class="bg-gray-700 px-3 py-2 rounded-md text-white">
                {@current_user.eve_alliance_name || "No Alliance"}
                <%= if @current_user.eve_alliance_id do %>
                  <span class="text-gray-400 text-sm">(ID: {@current_user.eve_alliance_id})</span>
                <% end %>
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-300 mb-1">Authorized Scopes</label>
              <div class="bg-gray-700 px-3 py-2 rounded-md text-white">
                <%= if @current_user.scopes && length(@current_user.scopes) > 0 do %>
                  <div class="flex flex-wrap gap-2">
                    <%= for scope <- @current_user.scopes do %>
                      <span class="bg-blue-600 text-white px-2 py-1 rounded text-xs">
                        {scope}
                      </span>
                    <% end %>
                  </div>
                <% else %>
                  <span class="text-gray-400">No scopes granted</span>
                <% end %>
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-300 mb-1">Token Status</label>
              <div class="bg-gray-700 px-3 py-2 rounded-md text-white">
                <%= if @current_user.token_expires_at do %>
                  <div class="flex items-center">
                    <%= if DateTime.compare(@current_user.token_expires_at, DateTime.utc_now()) == :gt do %>
                      <svg class="w-4 h-4 text-green-400 mr-2" fill="currentColor" viewBox="0 0 20 20">
                        <path
                          fill-rule="evenodd"
                          d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                          clip-rule="evenodd"
                        />
                      </svg>
                      <span class="text-green-400">Active</span>
                    <% else %>
                      <svg class="w-4 h-4 text-red-400 mr-2" fill="currentColor" viewBox="0 0 20 20">
                        <path
                          fill-rule="evenodd"
                          d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                          clip-rule="evenodd"
                        />
                      </svg>
                      <span class="text-red-400">Expired</span>
                    <% end %>
                    <span class="text-gray-400 text-sm ml-2">
                      Expires: {Calendar.strftime(
                        @current_user.token_expires_at,
                        "%Y-%m-%d %H:%M UTC"
                      )}
                    </span>
                  </div>
                <% else %>
                  <span class="text-gray-400">No token information</span>
                <% end %>
              </div>
            </div>
          </div>

    <!-- Actions -->
          <div class="mt-6 pt-6 border-t border-gray-700">
            <div class="flex space-x-4">
              <button
                type="button"
                class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md transition-colors duration-200"
                disabled
              >
                Refresh Token (Coming Soon)
              </button>

              <.link
                href="/auth/sign_out"
                method="post"
                class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-md transition-colors duration-200"
              >
                Sign Out
              </.link>
            </div>

            <p class="text-gray-400 text-sm mt-3">
              Token refresh functionality will be implemented in Epic 3 along with the EVE ESI integration.
            </p>
          </div>
        </div>
      </div>

    <!-- Quick Actions -->
      <div class="mt-8 bg-gray-800 rounded-lg p-6">
        <h3 class="text-lg font-semibold text-white mb-4">Quick Actions</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <.link
            navigate={~p"/character/#{@current_user.eve_character_id}"}
            class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-3 rounded-lg text-center transition-colors"
          >
            View My Character Intelligence
          </.link>
          <button
            type="button"
            class="bg-gray-700 text-gray-400 px-4 py-3 rounded-lg cursor-not-allowed"
            disabled
          >
            Export My Data (Coming Soon)
          </button>
        </div>
      </div>
    </div>
    """
  end
end
