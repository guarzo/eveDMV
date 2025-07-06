defmodule EveDmvWeb.ProfileLive do
  @moduledoc """
  User profile LiveView for managing account settings and preferences.
  """

  use EveDmvWeb, :live_view

  # Load current user from session on mount
  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]

    if current_user do
      socket =
        socket
        |> assign(:page_title, "Profile")
        |> assign(:current_user, current_user)

      {:ok, socket}
    else
      # Redirect to login if not authenticated
      {:ok, redirect(socket, to: ~p"/login")}
    end
  end

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
        <!-- Character Card -->
        <div class="bg-gray-800 rounded-lg p-6">
          <div class="text-center">
            <div class="w-20 h-20 bg-gray-700 rounded-full mx-auto mb-4 flex items-center justify-center">
              <svg
                class="w-10 h-10 text-gray-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
                />
              </svg>
            </div>
            <h2 class="text-xl font-semibold text-white mb-2">
              {@current_user.eve_character_name}
            </h2>
            <p class="text-gray-400 text-sm mb-1">
              Character ID: {@current_user.eve_character_id}
            </p>
            <p class="text-gray-400 text-sm">
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
            navigate={~p"/intel/#{@current_user.eve_character_id}"}
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
