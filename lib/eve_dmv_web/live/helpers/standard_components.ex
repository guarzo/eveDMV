defmodule EveDmvWeb.Live.Helpers.StandardComponents do
  @moduledoc """
  Standardized UI components for consistent LiveView page layouts and interactions.

  Provides reusable components for loading states, error displays, data tables,
  and common UI patterns used across intelligence and analysis pages.
  """

  use Phoenix.Component

  @doc """
  Standard loading state component.

  ## Usage:

      <.loading_state 
        loading={@data_loading} 
        message="Loading character data..." 
        size={:large} 
      />
  """
  attr(:loading, :boolean, default: false)
  attr(:message, :string, default: "Loading...")
  attr(:size, :atom, default: :medium, values: [:small, :medium, :large])
  attr(:class, :string, default: "")

  def loading_state(assigns) do
    ~H"""
    <%= if @loading do %>
      <div class={["loading-container", size_class(@size), @class]}>
        <div class="flex items-center space-x-3">
          <div class={["animate-spin rounded-full border-b-2 border-blue-400", spinner_size(@size)]}></div>
          <span class={["text-gray-300", text_size(@size)]}><%= @message %></span>
        </div>
      </div>
    <% end %>
    """
  end

  @doc """
  Standard error state component.

  ## Usage:

      <.error_state 
        error={@data_error} 
        title="Loading Failed"
        retry_event="retry_load" 
      />
  """
  attr(:error, :string, default: nil)
  attr(:title, :string, default: "Error")
  attr(:retry_event, :string, default: nil)
  attr(:class, :string, default: "")

  def error_state(assigns) do
    ~H"""
    <%= if @error do %>
      <div class={["bg-red-900 border border-red-600 rounded-lg p-6", @class]}>
        <div class="flex items-start justify-between">
          <div>
            <h3 class="text-red-300 font-semibold mb-2"><%= @title %></h3>
            <p class="text-red-400"><%= @error %></p>
          </div>
          <%= if @retry_event do %>
            <button
              phx-click={@retry_event}
              class="ml-4 px-3 py-1 bg-red-700 hover:bg-red-600 text-white text-sm rounded transition-colors"
            >
              Retry
            </button>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  @doc """
  Standard empty state component.

  ## Usage:

      <.empty_state 
        title="No Data Found"
        message="No killmails match your search criteria."
        action_text="Clear Filters"
        action_event="clear_filters"
      />
  """
  attr(:title, :string, required: true)
  attr(:message, :string, default: "")
  attr(:action_text, :string, default: nil)
  attr(:action_event, :string, default: nil)
  attr(:icon, :string, default: "📊")
  attr(:class, :string, default: "")

  def empty_state(assigns) do
    ~H"""
    <div class={["bg-gray-800 rounded-lg p-8 text-center", @class]}>
      <div class="text-4xl mb-4"><%= @icon %></div>
      <h3 class="text-xl font-semibold text-gray-300 mb-2"><%= @title %></h3>
      <%= if @message != "" do %>
        <p class="text-gray-400 mb-4"><%= @message %></p>
      <% end %>
      <%= if @action_text && @action_event do %>
        <button
          phx-click={@action_event}
          class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded transition-colors"
        >
          <%= @action_text %>
        </button>
      <% end %>
    </div>
    """
  end

  @doc """
  Standard page header component with actions.

  ## Usage:

      <.page_header 
        title="Intelligence Dashboard"
        subtitle="Real-time threat monitoring"
        back_url="/dashboard"
      >
        <:action>
          <button phx-click="refresh">Refresh</button>
        </:action>
      </.page_header>
  """
  attr(:title, :string, required: true)
  attr(:subtitle, :string, default: nil)
  attr(:back_url, :string, default: nil)
  attr(:class, :string, default: "")

  slot(:action, doc: "Action buttons for the header")

  def page_header(assigns) do
    ~H"""
    <div class={["mb-6", @class]}>
      <div class="flex justify-between items-start">
        <div>
          <%= if @back_url do %>
            <.link 
              navigate={@back_url} 
              class="inline-flex items-center text-blue-400 hover:text-blue-300 transition-colors mb-2"
            >
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
              Back
            </.link>
          <% end %>
          
          <h1 class="text-3xl font-bold text-white"><%= @title %></h1>
          <%= if @subtitle do %>
            <p class="text-gray-400 mt-1"><%= @subtitle %></p>
          <% end %>
        </div>
        
        <%= if @action != [] do %>
          <div class="flex space-x-2">
            <%= for action <- @action do %>
              <%= render_slot(action) %>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Standard data table component with sorting and filtering.

  ## Usage:

      <.data_table 
        data={@killmails}
        columns={[
          %{key: :killmail_time, label: "Time", sortable: true},
          %{key: :victim_name, label: "Victim", sortable: true}
        ]}
        loading={@killmails_loading}
        sort_by={@sort_by}
        sort_order={@sort_order}
      />
  """
  attr(:data, :list, default: [])
  attr(:columns, :list, required: true)
  attr(:loading, :boolean, default: false)
  attr(:empty_message, :string, default: "No data available")
  attr(:sort_by, :string, default: nil)
  attr(:sort_order, :string, default: "asc")
  attr(:row_click_event, :string, default: nil)
  attr(:class, :string, default: "")

  def data_table(assigns) do
    ~H"""
    <div class={["bg-gray-800 rounded-lg overflow-hidden", @class]}>
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-gray-700">
            <tr>
              <%= for column <- @columns do %>
                <th class="px-4 py-3 text-left">
                  <%= if Map.get(column, :sortable, false) do %>
                    <button
                      phx-click="sort"
                      phx-value-column={column.key}
                      class="flex items-center space-x-1 text-gray-300 hover:text-white transition-colors"
                    >
                      <span><%= column.label %></span>
                      <%= if @sort_by == to_string(column.key) do %>
                        <%= if @sort_order == "asc" do %>
                          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                            <path d="M3 3a1 1 0 000 2h11a1 1 0 100-2H3zM3 7a1 1 0 000 2h5a1 1 0 000-2H3zM3 11a1 1 0 100 2h4a1 1 0 100-2H3zM13 16a1 1 0 102 0v-5.586l1.293 1.293a1 1 0 001.414-1.414l-3-3a1 1 0 00-1.414 0l-3 3a1 1 0 101.414 1.414L13 10.414V16z"/>
                          </svg>
                        <% else %>
                          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                            <path d="M3 3a1 1 0 000 2h11a1 1 0 100-2H3zM3 7a1 1 0 000 2h7a1 1 0 100-2H3zM3 11a1 1 0 100 2h4a1 1 0 100-2H3zM15 8a1 1 0 10-2 0v5.586l-1.293-1.293a1 1 0 00-1.414 1.414l3 3a1 1 0 001.414 0l3-3a1 1 0 00-1.414-1.414L15 13.586V8z"/>
                          </svg>
                        <% end %>
                      <% end %>
                    </button>
                  <% else %>
                    <span class="text-gray-300"><%= column.label %></span>
                  <% end %>
                </th>
              <% end %>
            </tr>
          </thead>
          
          <tbody>
            <%= if @loading do %>
              <tr>
                <td colspan={length(@columns)} class="px-4 py-8 text-center">
                  <.loading_state loading={true} message="Loading data..." />
                </td>
              </tr>
            <% else %>
              <%= if Enum.empty?(@data) do %>
                <tr>
                  <td colspan={length(@columns)} class="px-4 py-8 text-center text-gray-400">
                    <%= @empty_message %>
                  </td>
                </tr>
              <% else %>
                <%= for {row, index} <- Enum.with_index(@data) do %>
                  <tr class={[
                    "border-t border-gray-700 hover:bg-gray-750 transition-colors",
                    @row_click_event && "cursor-pointer"
                  ]}
                  {if @row_click_event, do: ["phx-click": @row_click_event, "phx-value-index": index], else: []}>
                    <%= for column <- @columns do %>
                      <td class="px-4 py-3 text-gray-300">
                        <%= render_cell_value(row, column) %>
                      </td>
                    <% end %>
                  </tr>
                <% end %>
              <% end %>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  @doc """
  Standard tab navigation component.

  ## Usage:

      <.tab_navigation 
        active_tab={@active_tab}
        tabs={[
          {"overview", "Overview"},
          {"details", "Details"},
          {"history", "History"}
        ]}
        change_event="change_tab"
      />
  """
  attr(:active_tab, :string, required: true)
  attr(:tabs, :list, required: true)
  attr(:change_event, :string, default: "change_tab")
  attr(:class, :string, default: "")

  def tab_navigation(assigns) do
    ~H"""
    <div class={["border-b border-gray-700 mb-6", @class]}>
      <nav class="flex space-x-8">
        <%= for {tab_key, tab_label} <- @tabs do %>
          <button
            phx-click={@change_event}
            phx-value-tab={tab_key}
            class={[
              "py-2 px-1 border-b-2 font-medium text-sm transition-colors",
              if(@active_tab == tab_key, 
                do: "border-blue-500 text-blue-400", 
                else: "border-transparent text-gray-400 hover:text-gray-300"
              )
            ]}
          >
            <%= tab_label %>
          </button>
        <% end %>
      </nav>
    </div>
    """
  end

  # Private helper functions

  defp size_class(:small), do: "text-sm p-2"
  defp size_class(:medium), do: "text-base p-4"
  defp size_class(:large), do: "text-lg p-6"

  defp spinner_size(:small), do: "h-4 w-4"
  defp spinner_size(:medium), do: "h-6 w-6"
  defp spinner_size(:large), do: "h-8 w-8"

  defp text_size(:small), do: "text-sm"
  defp text_size(:medium), do: "text-base"
  defp text_size(:large), do: "text-lg"

  defp render_cell_value(row, column) do
    case Map.get(row, column.key) do
      nil -> "-"
      value when is_binary(value) -> value
      value -> to_string(value)
    end
  end
end
