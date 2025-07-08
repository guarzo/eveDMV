defmodule EveDmvWeb.CoreComponents do
  @moduledoc """
  Core components for EVE DMV application.

  This module provides the core UI components needed throughout the application,
  including both Phoenix defaults and custom EVE DMV components.
  """

  alias Phoenix.LiveView.JS
  use Phoenix.Component

  # Import our custom reusable components - commented out to avoid unused import warnings
  # Since these components are imported directly in the LiveViews that use them,
  # we don't need to import them here in CoreComponents
  # import EveDmvWeb.Components.PageHeaderComponent
  # import EveDmvWeb.Components.StatsGridComponent
  # import EveDmvWeb.Components.DataTableComponent
  # import EveDmvWeb.Components.LoadingStateComponent
  # import EveDmvWeb.Components.ErrorStateComponent
  # import EveDmvWeb.Components.EmptyStateComponent
  # import EveDmvWeb.Components.TabNavigationComponent
  # import EveDmvWeb.Components.CharacterInfoComponent

  # Note: IntelligenceComponents should be imported separately where needed
  # to avoid circular dependencies

  # Phoenix default components

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
  """
  attr(:id, :string, doc: "the optional id of flash container")
  attr(:flash, :map, default: %{}, doc: "the map of flash messages")
  attr(:title, :string, default: nil)
  attr(:kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup")
  attr(:rest, :global, doc: "the arbitrary HTML attributes to apply to the flash container")

  slot(:inner_block, doc: "the optional inner block that renders the flash message")

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg cursor-pointer",
        @kind == :info && "bg-blue-900 text-blue-100 border border-blue-700",
        @kind == :error && "bg-red-900 text-red-100 border border-red-700"
      ]}
      {@rest}
    >
      <div class="flex items-start space-x-3">
        <div :if={@kind == :info} class="flex-shrink-0">
          <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
          </svg>
        </div>
        <div :if={@kind == :error} class="flex-shrink-0">
          <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
          </svg>
        </div>
        <div class="flex-1">
          <p :if={@title} class="font-medium mb-1"><%= @title %></p>
          <p class="text-sm"><%= msg %></p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")
  attr(:id, :string, default: "flash-group", doc: "the optional id of flash container")

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} title="Success" flash={@flash} />
      <.flash kind={:error} title="Error" flash={@flash} />
    </div>
    """
  end

  @doc """
  Helper function to hide an element using Phoenix LiveView JS commands.
  """
  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition: {
        "transition-all ease-in duration-200",
        "opacity-100",
        "opacity-0"
      }
    )
  end

  @doc """
  Helper function to show an element using Phoenix LiveView JS commands.
  """
  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 200,
      transition: {
        "transition-all ease-out duration-200",
        "opacity-0",
        "opacity-100"
      }
    )
  end
end
