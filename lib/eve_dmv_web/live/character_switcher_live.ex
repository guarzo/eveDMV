defmodule EveDmvWeb.CharacterSwitcherLive do
  @moduledoc """
  LiveView component for character switching functionality.

  Displays all characters associated with the current account and
  allows switching between them without re-authentication.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Users.AccountManager

  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]
    current_account = socket.assigns[:current_account]

    if current_user && current_account do
      # Load all characters for this account
      characters = AccountManager.get_account_characters(current_account.id)

      socket =
        socket
        |> assign(:characters, characters)
        |> assign(:show_character_list, false)
        |> assign(:linking_new_character, false)
        |> assign(:account_stats, calculate_account_stats(characters))

      {:ok, socket}
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="character-switcher">
      <div class="flex items-center gap-4">
        <button
          phx-click="toggle_character_list"
          class="flex items-center gap-2 px-4 py-2 bg-gray-800 text-white rounded hover:bg-gray-700"
        >
          <img
            src={"https://images.evetech.net/characters/#{@current_user.eve_character_id}/portrait?size=32"}
            alt={@current_user.eve_character_name}
            class="w-8 h-8 rounded-full"
          />
          <span><%= @current_user.eve_character_name %></span>
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
          </svg>
        </button>
      </div>

      <%= if @show_character_list do %>
        <div class="absolute mt-2 w-64 bg-gray-800 rounded-lg shadow-lg z-50">
          <div class="p-4">
            <h3 class="text-sm font-semibold text-gray-400 mb-2">Your Characters</h3>

            <div class="space-y-2">
              <%= for character <- @characters do %>
                <div
                  phx-click="switch_character"
                  phx-value-character-id={character.id}
                  class={"flex items-center gap-3 p-2 rounded cursor-pointer hover:bg-gray-700 #{if character.id == @current_user.id, do: "bg-gray-700"}"}
                >
                  <img
                    src={"https://images.evetech.net/characters/#{character.eve_character_id}/portrait?size=32"}
                    alt={character.eve_character_name}
                    class="w-8 h-8 rounded-full"
                  />
                  <div class="flex-1">
                    <div class="text-sm font-medium text-white">
                      <%= character.eve_character_name %>
                    </div>
                    <div class="text-xs text-gray-400">
                      <%= character.eve_corporation_name || "No Corporation" %>
                    </div>
                  </div>
                  <%= if character.id == @current_account.primary_character_id do %>
                    <span class="text-xs text-green-400">Primary</span>
                  <% end %>
                </div>
              <% end %>
            </div>

            <div class="mt-4 pt-4 border-t border-gray-700">
              <button
                phx-click="toggle_link_character"
                class="w-full text-sm text-blue-400 hover:text-blue-300"
              >
                + Add Another Character
              </button>
            </div>

            <div class="mt-2 text-xs text-gray-500">
              <%= length(@characters) %> of <%= max_characters_per_account() %> characters
            </div>
          </div>
        </div>
      <% end %>

      <%= if @linking_new_character do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div class="bg-gray-800 rounded-lg p-6 w-full max-w-md mx-4">
            <h2 class="text-xl font-bold mb-4">Link Another Character</h2>

            <p class="text-gray-400 mb-6">
              To link another EVE character to your account, you'll need to authenticate
              with EVE SSO using that character.
            </p>

            <div class="bg-gray-900 p-4 rounded mb-6">
              <h3 class="font-semibold mb-2">Important:</h3>
              <ul class="text-sm text-gray-400 space-y-1">
                <li>• Make sure you're logged into EVE with the correct character</li>
                <li>• The character will be linked to your current account</li>
                <li>• You can switch between characters without logging out</li>
              </ul>
            </div>

            <div class="flex gap-4">
              <a
                href="/auth/eve_sso?link_to_account=true"
                class="flex-1 text-center px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
              >
                Authenticate with EVE SSO
              </a>
              <button
                phx-click="cancel_link_character"
                class="flex-1 px-4 py-2 bg-gray-700 text-white rounded hover:bg-gray-600"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_character_list", _params, socket) do
    {:noreply, update(socket, :show_character_list, &(!&1))}
  end

  @impl Phoenix.LiveView
  def handle_event("switch_character", %{"character-id" => character_id}, socket) do
    current_account = socket.assigns.current_account

    case AccountManager.switch_character(current_account.id, character_id) do
      {:ok, _updated_account, new_character} ->
        # Update session with new character
        {:noreply,
         socket
         |> put_flash(:info, "Switched to #{new_character.eve_character_name}")
         |> push_event("update_session", %{
           user_id: new_character.id,
           character_name: new_character.eve_character_name
         })
         |> push_navigate(to: "/dashboard")}

      {:error, :character_not_in_account} ->
        {:noreply, put_flash(socket, :error, "Character not found in your account")}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to switch character")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_link_character", _params, socket) do
    {:noreply, assign(socket, :linking_new_character, true)}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel_link_character", _params, socket) do
    {:noreply, assign(socket, :linking_new_character, false)}
  end

  defp calculate_account_stats(characters) do
    %{
      total_characters: length(characters),
      corporations:
        characters |> Enum.map(& &1.eve_corporation_name) |> Enum.uniq() |> Enum.filter(& &1),
      alliances:
        characters |> Enum.map(& &1.eve_alliance_name) |> Enum.uniq() |> Enum.filter(& &1)
    }
  end

  defp max_characters_per_account do
    Application.get_env(:eve_dmv, :max_characters_per_account, 10)
  end
end
