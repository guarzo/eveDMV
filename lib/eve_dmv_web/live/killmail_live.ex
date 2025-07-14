defmodule EveDmvWeb.KillmailLive do
  @moduledoc """
  LiveView for displaying individual killmail details.
  """

  use EveDmvWeb, :live_view

  @impl true
  def mount(%{"killmail_id" => killmail_id}, _session, socket) do
    # For now, just redirect back to dashboard
    # This is a placeholder until we implement full killmail display
    socket =
      socket
      |> assign(:killmail_id, killmail_id)
      |> put_flash(:info, "Killmail details coming soon!")
      |> push_navigate(to: ~p"/dashboard")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="bg-gray-800 rounded-lg p-6">
        <h1 class="text-2xl font-bold text-white mb-4">Killmail {@killmail_id}</h1>
        <p class="text-gray-300">Killmail details will be implemented in a future update.</p>
        <.link navigate={~p"/dashboard"} class="mt-4 inline-block bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded transition-colors">
          ← Back to Dashboard
        </.link>
      </div>
    </div>
    """
  end
end
