defmodule EveDmvWeb.Components.ErrorStateComponent do
  @moduledoc """
  Reusable error state component for displaying errors and failures.

  Provides consistent error messaging across the application.
  """

  use Phoenix.Component

  @doc """
  Renders an error state with message and optional action.

  ## Examples

      <.error_state message="Failed to load character data" />
      <.error_state message="Connection error" severity="critical">
        <:action>
          <button phx-click="retry" class="btn-primary">Try Again</button>
        </:action>
      </.error_state>
  """
  attr(:message, :string, required: true)
  attr(:severity, :string, default: "error", doc: "error, warning, critical")
  attr(:class, :string, default: "")
  attr(:show_icon, :boolean, default: true)

  slot(:action, doc: "Action buttons for error recovery")

  def error_state(assigns) do
    ~H"""
    <div class={"rounded-lg border p-4 #{error_border_class(@severity)} #{error_bg_class(@severity)} #{@class}"}>
      <div class="flex items-start">
        <div :if={@show_icon} class={"flex-shrink-0 #{error_icon_class(@severity)}"}>
          <%= error_icon(@severity) %>
        </div>
        <div class={"ml-3 flex-1 #{error_text_class(@severity)}"}>
          <p class="text-sm font-medium">
            <%= @message %>
          </p>
          <div :if={@action != []} class="mt-3">
            <%= render_slot(@action) %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders an inline error message without the full container.

  ## Examples

      <.error_message message="Invalid input" />
  """
  attr(:message, :string, required: true)
  attr(:class, :string, default: "")

  def error_message(assigns) do
    ~H"""
    <p class={"text-sm text-red-400 #{@class}"}>
      <%= @message %>
    </p>
    """
  end

  # Private helper functions

  defp error_border_class(severity) do
    case severity do
      "warning" -> "border-yellow-600"
      "critical" -> "border-red-500"
      _ -> "border-red-600"
    end
  end

  defp error_bg_class(severity) do
    case severity do
      "warning" -> "bg-yellow-900/20"
      "critical" -> "bg-red-900/30"
      _ -> "bg-red-900/20"
    end
  end

  defp error_text_class(severity) do
    case severity do
      "warning" -> "text-yellow-200"
      "critical" -> "text-red-200"
      _ -> "text-red-300"
    end
  end

  defp error_icon_class(severity) do
    case severity do
      "warning" -> "text-yellow-400"
      "critical" -> "text-red-400"
      _ -> "text-red-400"
    end
  end

  defp error_icon(severity) do
    case severity do
      "warning" ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
        </svg>
        """)

      _ ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
        </svg>
        """)
    end
  end
end
