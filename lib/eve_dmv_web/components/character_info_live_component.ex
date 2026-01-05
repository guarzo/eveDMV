defmodule EveDmvWeb.CharacterInfoComponent do
  @moduledoc """
  Live component for displaying character information in player profile.

  Shows character details with avatar, name, corporation, and alliance info.
  """

  use EveDmvWeb, :live_component

  @doc """
  Renders character information section with avatar and details.
  """
  def render(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
      <div class="flex items-center space-x-4">
        <img
          src={character_avatar_url(@character_info.character_id)}
          alt={"#{@character_info.character_name} avatar"}
          class="w-20 h-20 rounded-full bg-gray-700"
          onerror="this.src='/images/character-placeholder.png'"
        />
        <div class="flex-1">
          <h2 class="text-2xl font-bold text-white">
            <%= @character_info.character_name %>
          </h2>
          <div :if={@character_info[:corporation_name]} class="text-gray-400 mt-1">
            <%= @character_info.corporation_name %>
          </div>
          <div :if={@character_info[:alliance_name]} class="text-gray-500 text-sm">
            <%= @character_info.alliance_name %>
          </div>
        </div>
      </div>

      <div :if={@character_info[:security_status]} class="mt-4 pt-4 border-t border-gray-700">
        <div class="flex justify-between text-sm">
          <span class="text-gray-400">Security Status:</span>
          <span class={security_status_class(@character_info.security_status)}>
            <%= format_security_status(@character_info.security_status) %>
          </span>
        </div>
      </div>
    </div>
    """
  end

  defp character_avatar_url(character_id) do
    "https://images.evetech.net/characters/#{character_id}/portrait?size=128"
  end

  defp format_security_status(nil), do: "Unknown"

  defp format_security_status(status) when is_number(status) do
    :erlang.float_to_binary(status * 1.0, decimals: 2)
  end

  defp format_security_status(_), do: "Unknown"

  defp security_status_class(nil), do: "text-gray-400"

  defp security_status_class(status) when is_number(status) do
    cond do
      status >= 5.0 -> "text-green-400"
      status >= 0.0 -> "text-blue-400"
      status >= -5.0 -> "text-yellow-400"
      true -> "text-red-400"
    end
  end

  defp security_status_class(_), do: "text-gray-400"
end
