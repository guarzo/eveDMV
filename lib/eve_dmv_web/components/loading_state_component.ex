defmodule EveDmvWeb.Components.LoadingStateComponent do
  @moduledoc """
  Reusable loading state component with spinner animation.
  
  Provides consistent loading states across the application.
  """
  
  use Phoenix.Component
  
  @doc """
  Renders a loading state with optional message.
  
  ## Examples
  
      <.loading_state message="Loading character data..." />
      <.loading_state />
  """
  attr :message, :string, default: "Loading..."
  attr :class, :string, default: ""
  attr :size, :string, default: "normal", doc: "small, normal, large"
  
  def loading_state(assigns) do
    ~H"""
    <div class={"flex items-center justify-center py-12 #{@class}"}>
      <div class="text-center">
        <div class={"#{spinner_size_class(@size)} animate-spin rounded-full border-4 border-gray-600 border-t-blue-500 mx-auto"}>
        </div>
        <p class="mt-4 text-gray-400 text-sm">
          <%= @message %>
        </p>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders an inline loading spinner without the full container.
  
  ## Examples
  
      <.loading_spinner size="small" class="mr-2" />
  """
  attr :size, :string, default: "small"
  attr :class, :string, default: ""
  
  def loading_spinner(assigns) do
    ~H"""
    <div class={"#{spinner_size_class(@size)} animate-spin rounded-full border-2 border-gray-600 border-t-blue-500 #{@class}"}>
    </div>
    """
  end
  
  # Private helper function
  
  defp spinner_size_class(size) do
    case size do
      "small" -> "w-4 h-4"
      "normal" -> "w-8 h-8"
      "large" -> "w-12 h-12"
      _ -> "w-8 h-8"
    end
  end
end