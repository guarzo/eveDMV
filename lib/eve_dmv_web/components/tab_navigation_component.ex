defmodule EveDmvWeb.Components.TabNavigationComponent do
  @moduledoc """
  Reusable tab navigation component with active state management.

  Provides consistent tab styling and navigation across pages.
  """

  use Phoenix.Component

  @doc """
  Renders a tab navigation bar.

  ## Examples

      <.tab_navigation active_tab={@active_tab}>
        <:tab id="overview" label="Overview" icon="chart-line" />
        <:tab id="kills" label="Recent Kills" icon="crosshairs" count={@kill_count} />
        <:tab id="analysis" label="Analysis" icon="brain" />
      </.tab_navigation>
  """
  attr(:active_tab, :string, required: true)
  attr(:class, :string, default: "")
  attr(:variant, :string, default: "default", doc: "default, pills, underline")

  slot :tab, required: true do
    attr(:id, :string, required: true)
    attr(:label, :string, required: true)
    attr(:icon, :string, doc: "Icon name for the tab")
    attr(:count, :integer, doc: "Badge count to display")
    attr(:disabled, :boolean, doc: "Whether the tab is disabled")
  end

  def tab_navigation(assigns) do
    ~H"""
    <div class={"#{tab_container_class(@variant)} #{@class}"}>
      <nav class={"#{tab_nav_class(@variant)}"} aria-label="Tabs">
        <button
          :for={tab <- @tab}
          type="button"
          phx-click="change_tab"
          phx-value-tab={tab.id}
          disabled={Map.get(tab, :disabled, false)}
          class={"#{tab_button_class(@variant, @active_tab == tab.id, Map.get(tab, :disabled, false))}"}
          aria-current={if @active_tab == tab.id, do: "page", else: false}
        >
          <div class="flex items-center space-x-2">
            <svg :if={tab[:icon]} class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <%= tab_icon_path(tab.icon) %>
            </svg>
            <span><%= tab.label %></span>
            <span
              :if={tab[:count]}
              class={"#{count_badge_class(@variant, @active_tab == tab.id)}"}
            >
              <%= tab.count %>
            </span>
          </div>
        </button>
      </nav>
    </div>
    """
  end

  # Private helper functions

  defp tab_container_class(variant) do
    case variant do
      "pills" -> "bg-gray-800 p-1 rounded-lg"
      "underline" -> "border-b border-gray-700"
      _ -> "bg-gray-900 border-b border-gray-700"
    end
  end

  defp tab_nav_class(variant) do
    case variant do
      "pills" -> "flex space-x-1"
      "underline" -> "flex space-x-8"
      _ -> "flex space-x-1"
    end
  end

  defp tab_button_class(variant, is_active, is_disabled) do
    base_classes =
      "px-3 py-2 text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500"

    disabled_classes = if is_disabled, do: "opacity-50 cursor-not-allowed", else: ""

    variant_classes =
      case variant do
        "pills" ->
          if is_active do
            "bg-blue-600 text-white rounded-md"
          else
            "text-gray-300 hover:text-white hover:bg-gray-700 rounded-md"
          end

        "underline" ->
          if is_active do
            "text-blue-400 border-b-2 border-blue-400"
          else
            "text-gray-300 hover:text-white border-b-2 border-transparent hover:border-gray-600"
          end

        _ ->
          if is_active do
            "bg-gray-800 text-white border border-gray-600 rounded-t-lg"
          else
            "text-gray-300 hover:text-white hover:bg-gray-800 border border-transparent rounded-t-lg"
          end
      end

    "#{base_classes} #{variant_classes} #{disabled_classes}"
  end

  defp count_badge_class(variant, is_active) do
    base_classes =
      "inline-flex items-center justify-center px-2 py-1 text-xs font-bold rounded-full min-w-[1.25rem]"

    color_classes =
      case variant do
        "pills" ->
          if is_active, do: "bg-blue-800 text-blue-100", else: "bg-gray-600 text-gray-200"

        _ ->
          if is_active, do: "bg-blue-600 text-white", else: "bg-gray-600 text-gray-300"
      end

    "#{base_classes} #{color_classes}"
  end

  defp tab_icon_path(icon) do
    case icon do
      "chart-line" ->
        Phoenix.HTML.raw(
          ~s{<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 12l3-3 3 3 4-4M8 21l4-4 4 4M3 4h18M4 4h16v12a1 1 0 01-1 1H5a1 1 0 01-1-1V4z" />}
        )

      "crosshairs" ->
        Phoenix.HTML.raw(
          ~s{<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 2v20M2 12h20M12 8a4 4 0 100 8 4 4 0 000-8z" />}
        )

      "brain" ->
        Phoenix.HTML.raw(
          ~s{<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />}
        )

      "users" ->
        Phoenix.HTML.raw(
          ~s{<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z" />}
        )

      "shield" ->
        Phoenix.HTML.raw(
          ~s{<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />}
        )

      _ ->
        Phoenix.HTML.raw(
          ~s{<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />}
        )
    end
  end
end
