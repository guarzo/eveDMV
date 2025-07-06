defmodule EveDmvWeb.Components.PageHeaderComponent do
  @moduledoc """
  Reusable page header component with title, subtitle, and action buttons.

  Used across multiple LiveViews for consistent page headers.
  """

  use Phoenix.Component

  @doc """
  Renders a standardized page header with optional elements.

  ## Examples

      <.page_header 
        title="Kill Feed" 
        subtitle="Real-time EVE Online PvP activity"
        current_user={@current_user}
      >
        <:action>
          <button class="btn-primary">Refresh</button>
        </:action>
      </.page_header>
  """
  attr(:title, :string, required: true)
  attr(:subtitle, :string, default: nil)
  attr(:current_user, :map, default: nil)
  attr(:class, :string, default: "")

  slot(:action, doc: "Action buttons on the right side")
  slot(:info, doc: "Additional info below subtitle")

  def page_header(assigns) do
    ~H"""
    <div class={"bg-gray-800 border-b border-gray-700 px-6 py-4 #{@class}"}>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-white"><%= @title %></h1>
          <p :if={@subtitle} class="mt-1 text-gray-400">
            <%= @subtitle %>
          </p>
          <div :if={@info != []} class="mt-2">
            <%= render_slot(@info) %>
          </div>
        </div>
        
        <div class="flex items-center space-x-4">
          <!-- User info -->
          <div :if={@current_user} class="text-sm text-gray-300">
            Welcome back, <span class="text-yellow-400"><%= @current_user.character_name %></span>
          </div>
          
          <!-- Action buttons -->
          <div :if={@action != []} class="flex space-x-2">
            <%= render_slot(@action) %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
