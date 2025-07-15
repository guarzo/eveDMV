defmodule EveDmvWeb.Components.ButtonComponent do
  @moduledoc """
  Reusable button component with consistent styling.

  Provides standardized button variants and sizes across the application.
  """

  use Phoenix.Component

  @doc """
  Renders a button with consistent styling.

  ## Examples

      <.button variant="primary" size="md">Save</.button>
      <.button variant="secondary" size="sm" disabled>Loading</.button>
      <.button variant="danger" size="lg" phx-click="delete">Delete</.button>
  """
  attr(:variant, :string, default: "primary", doc: "primary, secondary, danger, ghost")
  attr(:size, :string, default: "md", doc: "sm, md, lg")
  attr(:disabled, :boolean, default: false)
  attr(:loading, :boolean, default: false)
  attr(:class, :string, default: "")
  attr(:type, :string, default: "button")
  attr(:rest, :global, include: ~w(form phx-click phx-submit phx-change phx-value-id))

  slot(:inner_block, required: true)

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "inline-flex items-center justify-center font-medium rounded-lg transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-900",
        size_classes(@size),
        variant_classes(@variant),
        disabled_classes(@disabled or @loading),
        @class
      ]}
      disabled={@disabled or @loading}
      {@rest}
    >
      <%= if @loading do %>
        <div class="animate-spin rounded-full border-2 border-transparent border-t-current w-4 h-4 mr-2"></div>
      <% end %>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders a link button with consistent styling.

  ## Examples

      <.link_button navigate={~p"/dashboard"} variant="primary">Dashboard</.link_button>
      <.link_button href="/external" variant="secondary">External Link</.link_button>
  """
  attr(:navigate, :string, default: nil)
  attr(:href, :string, default: nil)
  attr(:variant, :string, default: "primary", doc: "primary, secondary, danger, ghost")
  attr(:size, :string, default: "md", doc: "sm, md, lg")
  attr(:disabled, :boolean, default: false)
  attr(:class, :string, default: "")
  attr(:rest, :global, include: ~w(method data-confirm data-method))

  slot(:inner_block, required: true)

  def link_button(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      href={@href}
      class={[
        "inline-flex items-center justify-center font-medium rounded-lg transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-900",
        size_classes(@size),
        variant_classes(@variant),
        disabled_classes(@disabled),
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  # Private helper functions

  defp size_classes(size) do
    case size do
      "sm" -> "px-3 py-1.5 text-sm"
      "md" -> "px-4 py-2 text-sm"
      "lg" -> "px-6 py-3 text-base"
      _ -> "px-4 py-2 text-sm"
    end
  end

  defp variant_classes(variant) do
    case variant do
      "primary" ->
        "bg-blue-600 hover:bg-blue-700 text-white focus:ring-blue-500 border border-transparent"

      "secondary" ->
        "bg-gray-700 hover:bg-gray-600 text-white focus:ring-gray-500 border border-gray-600"

      "danger" ->
        "bg-red-600 hover:bg-red-700 text-white focus:ring-red-500 border border-transparent"

      "ghost" ->
        "bg-transparent hover:bg-gray-700 text-gray-300 hover:text-white focus:ring-gray-500 border border-gray-600"

      _ ->
        "bg-blue-600 hover:bg-blue-700 text-white focus:ring-blue-500 border border-transparent"
    end
  end

  defp disabled_classes(disabled) do
    if disabled do
      "opacity-50 cursor-not-allowed hover:bg-current"
    else
      ""
    end
  end
end
