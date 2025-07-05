defmodule EveDmvWeb.Components.CharacterInfoComponent do
  @moduledoc """
  Reusable character information display component.
  
  Shows character details with avatar, name, and additional info.
  """
  
  use Phoenix.Component
  
  @doc """
  Renders character information with avatar and details.
  
  ## Examples
  
      <.character_info 
        character_id={@character.id}
        character_name={@character.name}
        corporation_name={@character.corporation_name}
        alliance_name={@character.alliance_name}
      />
  """
  attr :character_id, :integer, required: true
  attr :character_name, :string, required: true
  attr :corporation_name, :string, default: nil
  attr :alliance_name, :string, default: nil
  attr :avatar_size, :string, default: "medium", doc: "small, medium, large"
  attr :show_links, :boolean, default: true
  attr :class, :string, default: ""
  
  slot :additional_info, doc: "Additional character information"
  
  def character_info(assigns) do
    ~H"""
    <div class={"flex items-center space-x-3 #{@class}"}>
      <img 
        src={character_avatar_url(@character_id, @avatar_size)}
        alt={"#{@character_name} avatar"}
        class={"#{avatar_size_class(@avatar_size)} rounded-full bg-gray-700"}
        onerror="this.src='/images/character-placeholder.png'"
      />
      <div class="flex-1 min-w-0">
        <div class="flex items-center space-x-2">
          <span class="text-white font-medium truncate">
            <%= if @show_links do %>
              <.link navigate={"/intel/#{@character_id}"} class="hover:text-blue-400 transition-colors">
                <%= @character_name %>
              </.link>
            <% else %>
              <%= @character_name %>
            <% end %>
          </span>
        </div>
        <div :if={@corporation_name} class="text-sm text-gray-400 truncate">
          <%= @corporation_name %>
          <span :if={@alliance_name} class="text-gray-500">
            • <%= @alliance_name %>
          </span>
        </div>
        <div :if={@additional_info != []} class="mt-1">
          <%= render_slot(@additional_info) %>
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders a compact character link with optional avatar.
  
  ## Examples
  
      <.character_link character_id={123} character_name="Pilot Name" />
  """
  attr :character_id, :integer, required: true
  attr :character_name, :string, required: true
  attr :show_avatar, :boolean, default: false
  attr :class, :string, default: ""
  
  def character_link(assigns) do
    ~H"""
    <div class={"flex items-center space-x-2 #{@class}"}>
      <img 
        :if={@show_avatar}
        src={character_avatar_url(@character_id, "small")}
        alt={"#{@character_name} avatar"}
        class="w-6 h-6 rounded-full bg-gray-700"
        onerror="this.src='/images/character-placeholder.png'"
      />
      <.link 
        navigate={"/intel/#{@character_id}"} 
        class="text-blue-400 hover:text-blue-300 transition-colors truncate"
      >
        <%= @character_name %>
      </.link>
    </div>
    """
  end
  
  # Private helper functions
  
  defp character_avatar_url(character_id, size) do
    size_param = case size do
      "small" -> 64
      "medium" -> 128
      "large" -> 256
      _ -> 128
    end
    
    "https://images.evetech.net/characters/#{character_id}/portrait?size=#{size_param}"
  end
  
  defp avatar_size_class(size) do
    case size do
      "small" -> "w-8 h-8"
      "medium" -> "w-12 h-12"
      "large" -> "w-16 h-16"
      _ -> "w-12 h-12"
    end
  end
end