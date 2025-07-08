defmodule EveDmvWeb.NoDataComponent do
  @moduledoc """
  Component for displaying no statistics available state.

  Shows a friendly message when no player statistics are available,
  with options to generate statistics and view available intelligence data.
  """

  use EveDmvWeb, :live_component

  @doc """
  Renders the no statistics available section with generate button and intelligence preview.
  """
  def render(assigns) do
    ~H"""
    <!-- No Statistics Available -->
    <div class="bg-gray-800 rounded-lg p-8 border border-gray-700 text-center">
      <div class="text-gray-400 mb-4">
        <svg class="w-16 h-16 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
          >
          </path>
        </svg>
      </div>

      <h2 class="text-xl font-bold mb-2">No Statistics Available</h2>
      <p class="text-gray-400 mb-6">
        Player statistics have not been generated for this character yet.
      </p>

      <button
        phx-click="generate_stats"
        class="bg-green-600 hover:bg-green-700 text-white px-6 py-2 rounded font-medium transition-colors"
      >
        📊 Generate Player Statistics
      </button>

      <%= if @character_intel do %>
        <div class="mt-6 pt-6 border-t border-gray-700">
          <p class="text-sm text-gray-400 mb-2">
            Character intelligence data is available:
          </p>
          <div class="grid grid-cols-2 gap-4 text-sm">
            <div>
              <span class="text-gray-400">Kills:</span>
              <span class="text-green-400 ml-2">{@character_intel.total_kills || 0}</span>
            </div>
            <div>
              <span class="text-gray-400">Losses:</span>
              <span class="text-red-400 ml-2">{@character_intel.total_losses || 0}</span>
            </div>
          </div>
          <div class="mt-2">
            <a
              href={~p"/intel/#{@character_id}"}
              class="text-blue-400 hover:text-blue-300 underline text-sm"
            >
              View Character Intelligence →
            </a>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
