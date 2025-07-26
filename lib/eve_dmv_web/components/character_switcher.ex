defmodule EveDmvWeb.Components.CharacterSwitcher do
  @moduledoc """
  Character switcher component for the application header.

  Provides a dropdown menu for switching between characters
  in a multi-character account.
  """

  use Phoenix.Component
  import EveDmvWeb.CoreComponents

  alias EveDmv.Users.AccountManager
  alias Phoenix.LiveView.JS

  @doc """
  Renders the character switcher dropdown.

  ## Examples

      <.character_switcher current_user={@current_user} current_account={@current_account} />
  """
  attr(:current_user, :map, required: true)
  attr(:current_account, :map, required: true)
  attr(:id, :string, default: "character-switcher")

  def character_switcher(assigns) do
    ~H"""
    <div id={@id} class="relative" phx-hook="CharacterSwitcher">
      <button
        type="button"
        class="flex items-center gap-2 px-3 py-2 text-sm text-gray-300 hover:text-white transition-colors"
        phx-click={toggle_dropdown(@id)}
      >
        <img
          src={"https://images.evetech.net/characters/#{@current_user.eve_character_id}/portrait?size=32"}
          alt={@current_user.eve_character_name}
          class="w-6 h-6 rounded-full"
        />
        <span class="hidden sm:inline"><%= @current_user.eve_character_name %></span>
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      <div
        id={"#{@id}-dropdown"}
        class="hidden absolute right-0 mt-2 w-72 bg-gray-800 rounded-lg shadow-xl border border-gray-700 z-50"
        phx-click-away={hide_dropdown(@id)}
      >
        <div class="p-4">
          <div class="flex items-center justify-between mb-3">
            <h3 class="text-sm font-semibold text-gray-400">Switch Character</h3>
            <button
              type="button"
              phx-click={hide_dropdown(@id)}
              class="text-gray-500 hover:text-gray-400"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <div class="space-y-1 max-h-64 overflow-y-auto">
            <%= for character <- get_account_characters(@current_account) do %>
              <a
                href={"/auth/switch/#{character.id}"}
                class={"flex items-center gap-3 p-2 rounded hover:bg-gray-700 transition-colors #{if character.id == @current_user.id, do: "bg-gray-700 ring-1 ring-gray-600"}"}
              >
                <img
                  src={"https://images.evetech.net/characters/#{character.eve_character_id}/portrait?size=32"}
                  alt={character.eve_character_name}
                  class="w-8 h-8 rounded-full"
                />
                <div class="flex-1 min-w-0">
                  <div class="text-sm font-medium text-white truncate">
                    <%= character.eve_character_name %>
                  </div>
                  <div class="text-xs text-gray-400 truncate">
                    <%= character.eve_corporation_name || "No Corporation" %>
                  </div>
                </div>
                <%= if character.id == @current_user.id do %>
                  <span class="text-xs text-green-400 font-medium">Active</span>
                <% end %>
                <%= if character.id == @current_account.primary_character_id do %>
                  <span class="text-xs text-blue-400">Primary</span>
                <% end %>
              </a>
            <% end %>
          </div>

          <div class="mt-4 pt-4 border-t border-gray-700 space-y-3">
            <a
              href="/auth/eve_sso?link_to_account=true"
              class="flex items-center justify-center gap-2 w-full px-3 py-2 text-sm bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              Add Another Character
            </a>

            <a
              href="/account/settings"
              class="flex items-center justify-center gap-2 w-full px-3 py-2 text-sm bg-gray-700 text-gray-300 rounded hover:bg-gray-600 transition-colors"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
              Account Settings
            </a>
          </div>

          <div class="mt-3 text-xs text-center text-gray-500">
            <%= character_count(@current_account) %> of <%= max_characters() %> characters
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp get_account_characters(account) do
    AccountManager.get_account_characters(account.id)
  end

  defp character_count(account) do
    length(get_account_characters(account))
  end

  defp max_characters do
    Application.get_env(:eve_dmv, :max_characters_per_account, 10)
  end

  defp toggle_dropdown(id) do
    JS.toggle(
      to: "##{id}-dropdown",
      in:
        {"transition ease-out duration-200", "opacity-0 translate-y-1",
         "opacity-100 translate-y-0"},
      out:
        {"transition ease-in duration-150", "opacity-100 translate-y-0",
         "opacity-0 translate-y-1"}
    )
  end

  defp hide_dropdown(id) do
    JS.hide(
      to: "##{id}-dropdown",
      transition:
        {"transition ease-in duration-150", "opacity-100 translate-y-0",
         "opacity-0 translate-y-1"}
    )
  end
end
