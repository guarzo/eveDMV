defmodule EveDmvWeb.SearchComponent do
  @moduledoc """
  Reusable search component for system, character, and corporation searches.
  Can be embedded in any LiveView page.
  """
  
  use EveDmvWeb, :live_component
  
  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      query: "",
      results: [],
      selected_index: 0,
      loading: false,
      show_dropdown: false,
      focused: false,
      search_type: :universal  # :universal, :systems, :characters, :corporations
    )}
  end
  
  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end
  
  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket = 
      socket
      |> assign(query: query)
      |> search(query)
      
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("focus", _params, socket) do
    {:noreply, assign(socket, focused: true, show_dropdown: true)}
  end
  
  @impl true
  def handle_event("blur", _params, socket) do
    send(self(), {:hide_dropdown, socket.assigns.id})
    {:noreply, assign(socket, focused: false)}
  end
  
  @impl true
  def handle_event("select_result", %{"type" => type, "id" => id}, socket) do
    path = case type do
      "system" -> ~p"/system/#{id}"
      "character" -> ~p"/character/#{id}"
      "corporation" -> ~p"/corporation/#{id}"
      _ -> "/"
    end
    
    send(self(), {:navigate, path})
    {:noreply, assign(socket, show_dropdown: false, query: "")}
  end
  
  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply, assign(socket, query: "", results: [], show_dropdown: false)}
  end
  
  defp search(socket, "") do
    assign(socket, results: [], show_dropdown: false, loading: false)
  end
  
  defp search(socket, query) when byte_size(query) < 2 do
    assign(socket, results: [], show_dropdown: false, loading: false)
  end
  
  defp search(socket, query) do
    # For now, just search systems. Will expand to other types later.
    send(self(), {:search_async, socket.assigns.id, query})
    assign(socket, loading: true, show_dropdown: true)
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative" id={@id}>
      <form phx-change="search" phx-submit="search" phx-target={@myself}>
        <div class="relative">
          <input
            type="text"
            name="query"
            value={@query}
            phx-focus="focus"
            phx-blur="blur"
            phx-target={@myself}
            placeholder={placeholder_text(@search_type)}
            autocomplete="off"
            class={[
              "w-full px-4 py-2 pl-10 pr-10 bg-gray-800 border border-gray-700 rounded-lg",
              "text-white placeholder-gray-400",
              "focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
              @class
            ]}
          />
          
          <!-- Search Icon -->
          <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
            </svg>
          </div>
          
          <!-- Clear Button -->
          <%= if @query != "" do %>
            <button
              type="button"
              phx-click="clear_search"
              phx-target={@myself}
              class="absolute inset-y-0 right-0 pr-3 flex items-center"
            >
              <svg class="h-4 w-4 text-gray-400 hover:text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
              </svg>
            </button>
          <% end %>
        </div>
      </form>
      
      <!-- Search Results Dropdown -->
      <%= if @show_dropdown && !@loading && @results != [] do %>
        <div class="absolute mt-1 w-full bg-gray-800 border border-gray-700 rounded-lg shadow-lg max-h-80 overflow-y-auto z-50">
          <%= for result <- @results do %>
            <div
              phx-click="select_result"
              phx-value-type={result.type}
              phx-value-id={result.id}
              phx-target={@myself}
              class="px-4 py-2 hover:bg-gray-700 cursor-pointer transition-colors border-b border-gray-700 last:border-b-0"
            >
              <div class="flex items-center justify-between">
                <div>
                  <div class="font-medium text-white">
                    <%= result.name %>
                  </div>
                  <div class="text-sm text-gray-400">
                    <%= result.subtitle %>
                  </div>
                </div>
                <div class="text-xs text-gray-500">
                  <%= result.type_label %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
      
      <!-- Loading State -->
      <%= if @loading do %>
        <div class="absolute mt-1 w-full bg-gray-800 border border-gray-700 rounded-lg shadow-lg p-3">
          <div class="flex items-center justify-center">
            <div class="animate-spin rounded-full h-5 w-5 border-b-2 border-blue-500"></div>
            <span class="ml-2 text-sm text-gray-400">Searching...</span>
          </div>
        </div>
      <% end %>
      
      <!-- No Results -->
      <%= if @show_dropdown && !@loading && @results == [] && @query != "" do %>
        <div class="absolute mt-1 w-full bg-gray-800 border border-gray-700 rounded-lg shadow-lg p-3">
          <div class="text-center text-sm text-gray-400">
            No results found for "<%= @query %>"
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  defp placeholder_text(:universal), do: "Search systems, characters, corporations..."
  defp placeholder_text(:systems), do: "Search solar systems..."
  defp placeholder_text(:characters), do: "Search characters..."
  defp placeholder_text(:corporations), do: "Search corporations..."
  defp placeholder_text(_), do: "Search..."
end