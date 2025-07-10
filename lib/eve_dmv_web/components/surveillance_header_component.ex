defmodule EveDmvWeb.SurveillanceHeaderComponent do
  @moduledoc """
  Header component for surveillance profiles page.

  Provides navigation, batch mode controls, and action buttons
  for managing surveillance profiles.
  """

  use EveDmvWeb, :live_component

  @doc """
  Renders the surveillance header with batch controls and action buttons.
  """
  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="bg-gray-800 border-b border-gray-700 px-6 py-4">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <h1 class="text-2xl font-bold text-blue-400">Surveillance Profiles</h1>
          <div class="text-sm text-gray-400">Target Tracking System</div>
        </div>

        <div class="flex items-center space-x-4">
          <%= if @batch_mode do %>
            <div class="flex items-center space-x-2 text-sm">
              <span class="text-gray-400"><%= MapSet.size(@selected_profiles) %> selected</span>
              <button
                phx-click="select_all_profiles"
                phx-target={@myself}
                class="px-2 py-1 bg-gray-600 hover:bg-gray-700 rounded text-xs"
              >
                Select All
              </button>
              <button
                phx-click="deselect_all_profiles"
                phx-target={@myself}
                class="px-2 py-1 bg-gray-600 hover:bg-gray-700 rounded text-xs"
              >
                Clear
              </button>
            </div>
          <% end %>

          <button
            phx-click="toggle_batch_mode"
            phx-target={@myself}
            class={"px-3 py-2 rounded-lg text-sm transition-colors " <>
                   if(@batch_mode,
                      do: "bg-yellow-600 hover:bg-yellow-700",
                      else: "bg-gray-600 hover:bg-gray-700")}
          >
            <%= if @batch_mode, do: "✓ Batch Mode", else: "📋 Batch Mode" %>
          </button>

          <%= if @batch_mode && MapSet.size(@selected_profiles) > 0 do %>
            <button
              phx-click="show_batch_modal"
              phx-target={@myself}
              class="px-3 py-2 bg-purple-600 hover:bg-purple-700 rounded-lg text-sm transition-colors"
            >
              ⚡ Batch Actions
            </button>
          <% end %>

          <button
            phx-click="export_profiles"
            phx-target={@myself}
            title="Export profiles"
            class="px-3 py-2 bg-gray-600 hover:bg-gray-700 rounded-lg text-sm transition-colors"
          >
            📥 Export
          </button>

          <button
            phx-click="refresh_stats"
            phx-target={@myself}
            class="px-3 py-2 bg-gray-600 hover:bg-gray-700 rounded-lg text-sm transition-colors"
          >
            🔄 Refresh
          </button>

          <button
            phx-click="show_create_modal"
            phx-target={@myself}
            class="px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded-lg text-sm font-medium transition-colors"
          >
            ➕ New Profile
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle_batch_mode", _params, socket) do
    # Send event to parent LiveView
    send(self(), {:batch_mode_toggled})
    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("select_all_profiles", _params, socket) do
    send(self(), {:select_all_profiles})
    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("deselect_all_profiles", _params, socket) do
    send(self(), {:deselect_all_profiles})
    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("show_batch_modal", _params, socket) do
    send(self(), {:show_batch_modal})
    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("export_profiles", _params, socket) do
    send(self(), {:export_profiles})
    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("refresh_stats", _params, socket) do
    send(self(), {:refresh_stats})
    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("show_create_modal", _params, socket) do
    send(self(), {:show_create_modal})
    {:noreply, socket}
  end
end
