defmodule EveDmvWeb.Components.EmptyStateComponent do
  @moduledoc """
  Reusable empty state component for displaying when no data is available.

  Provides consistent empty state messaging across the application.
  """

  use Phoenix.Component

  @doc """
  Renders an empty state with icon, title, and message.

  ## Examples

      <.empty_state 
        icon="🛸"
        title="No kills yet"
        message="Kill data will appear here as it's processed"
      />
  """
  attr(:icon, :string, default: "📭")
  attr(:title, :string, required: true)
  attr(:message, :string, default: nil)
  attr(:class, :string, default: "")

  slot(:action, doc: "Optional action button")

  def empty_state(assigns) do
    ~H"""
    <div class={"text-center py-12 #{@class}"}>
      <div class="text-4xl text-gray-600 mb-4">
        <%= @icon %>
      </div>
      <h3 class="text-lg font-medium text-gray-400 mb-2">
        <%= @title %>
      </h3>
      <p :if={@message} class="text-gray-500">
        <%= @message %>
      </p>
      <div :if={@action != []} class="mt-4">
        <%= render_slot(@action) %>
      </div>
    </div>
    """
  end
end
