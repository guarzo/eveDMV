defmodule EveDmvWeb.ProfileGridComponent do
  @moduledoc """
  Component for displaying surveillance profiles in a grid layout.

  Handles profile cards with stats, batch selection, filter previews,
  and profile action buttons (activate/pause/delete).
  """

  use EveDmvWeb, :live_component

  @doc """
  Renders the profile grid with batch selection support.
  """
  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="flex-1 h-screen overflow-y-auto">
      <div class="p-6">
        <div class="flex items-center justify-between mb-6">
          <h2 class="text-xl font-semibold text-gray-200">Your Profiles</h2>
          <div class="text-sm text-gray-400">
            <%= length(@profiles) %> profile<%= if length(@profiles) != 1, do: "s" %>
          </div>
        </div>
        
        <!-- Profiles Grid -->
        <%= if length(@profiles) > 0 do %>
          <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            <%= for profile <- @profiles do %>
              <div class={"bg-gray-800 border rounded-lg p-6 transition-all " <>
                          if(@batch_mode && MapSet.member?(@selected_profiles, profile.id),
                             do: "border-purple-500 ring-2 ring-purple-500",
                             else: "border-gray-700")}>
                <!-- Profile Header -->
                <div class="flex items-start justify-between mb-4">
                  <div class="flex items-start space-x-3">
                    <%= if @batch_mode do %>
                      <input
                        type="checkbox"
                        checked={MapSet.member?(@selected_profiles, profile.id)}
                        phx-click="toggle_profile_selection"
                        phx-target={@myself}
                        phx-value-profile_id={profile.id}
                        class="mt-1 w-4 h-4 text-purple-600 bg-gray-700 border-gray-600 rounded focus:ring-purple-500"
                      />
                    <% end %>
                    <div>
                      <h3 class="text-lg font-semibold text-gray-200"><%= profile.name %></h3>
                      <%= if profile.description do %>
                        <p class="text-sm text-gray-400 mt-1"><%= profile.description %></p>
                      <% end %>
                    </div>
                  </div>
                  <div class="text-sm">
                    {profile_status_badge(profile.is_active)}
                  </div>
                </div>
                
                <!-- Profile Stats -->
                <div class="grid grid-cols-2 gap-4 mb-4">
                  <div class="text-center">
                    <div class="text-lg font-bold text-blue-400"><%= profile.match_count %></div>
                    <div class="text-xs text-gray-500">Matches</div>
                  </div>
                  <div class="text-center">
                    <%= if profile.last_match_at do %>
                      <div class="text-lg font-bold text-green-400">✓</div>
                      <div class="text-xs text-gray-500">Recently Active</div>
                    <% else %>
                      <div class="text-lg font-bold text-gray-500">—</div>
                      <div class="text-xs text-gray-500">No Matches</div>
                    <% end %>
                  </div>
                </div>
                
                <!-- Filter Preview -->
                <div class="mb-4">
                  <div class="text-sm font-medium text-gray-300 mb-2">Filter Rules:</div>
                  <div class="bg-gray-900 rounded p-3">
                    <code class="text-xs text-gray-400">
                      <%= String.slice(format_filter_tree(profile.filter_tree), 0, 100) %>...
                    </code>
                  </div>
                </div>
                
                <!-- Actions -->
                <div class="flex space-x-2">
                  <button
                    phx-click="toggle_profile"
                    phx-target={@myself}
                    phx-value-profile_id={profile.id}
                    class={"px-3 py-2 rounded text-sm font-medium transition-colors " <>
                           if(profile.is_active, 
                              do: "bg-yellow-600 hover:bg-yellow-700 text-white", 
                              else: "bg-green-600 hover:bg-green-700 text-white")}
                  >
                    <%= if profile.is_active, do: "Pause", else: "Activate" %>
                  </button>
                  <button
                    phx-click="delete_profile"
                    phx-target={@myself}
                    phx-value-profile_id={profile.id}
                    data-confirm="Are you sure you want to delete this profile?"
                    class="px-3 py-2 bg-red-600 hover:bg-red-700 text-white rounded text-sm font-medium transition-colors"
                  >
                    Delete
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <!-- Empty State -->
          <div class="text-center py-12">
            <div class="text-6xl text-gray-600 mb-4">🎯</div>
            <h3 class="text-lg font-medium text-gray-400 mb-2">No Surveillance Profiles</h3>
            <p class="text-gray-500 mb-6">
              Create your first profile to start tracking specific killmail patterns
            </p>
            <button
              phx-click="show_create_modal"
              phx-target={@myself}
              class="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-colors"
            >
              Create First Profile
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle_profile_selection", %{"profile_id" => profile_id}, socket) do
    # Send event to parent LiveView
    send(self(), {:toggle_profile_selection, profile_id})
    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle_profile", %{"profile_id" => profile_id}, socket) do
    send(self(), {:toggle_profile, profile_id})
    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("delete_profile", %{"profile_id" => profile_id}, socket) do
    send(self(), {:delete_profile, profile_id})
    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("show_create_modal", _params, socket) do
    send(self(), {:show_create_modal})
    {:noreply, socket}
  end

  # Helper functions
  defp profile_status_badge(is_active) do
    if is_active do
      "🟢 Active"
    else
      "🔴 Inactive"
    end
  end

  defp format_filter_tree(filter_tree) do
    Jason.encode!(filter_tree, pretty: true)
  end
end
