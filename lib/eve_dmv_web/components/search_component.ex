defmodule EveDmvWeb.SearchComponent do
  @moduledoc """
  Reusable search component for system, character, and corporation searches.
  Can be embedded in any LiveView page.
  """

  use EveDmvWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       query: "",
       results: [],
       selected_index: 0,
       loading: false,
       show_dropdown: false,
       focused: false,
       # :universal, :systems, :characters, :corporations
       search_type: :universal
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
    path =
      case type do
        "system" -> ~p"/system/#{id}"
        "character" -> ~p"/character/#{id}"
        "corporation" -> ~p"/corporation/#{id}"
        _ -> "/"
      end

    # Use JavaScript to navigate since we can't push_navigate from a component
    {:noreply,
     socket
     |> assign(show_dropdown: false, query: "")
     |> push_event("navigate", %{path: path})}
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
    # Search across all types for universal search
    search_type = socket.assigns.search_type

    case search_type do
      :universal ->
        # Search all types and show results synchronously for now
        results = perform_universal_search(query)
        assign(socket, results: results, loading: false, show_dropdown: true)

      _ ->
        # Search specific type
        send(self(), {:search_async, socket.assigns.id, query})
        assign(socket, loading: true, show_dropdown: true)
    end
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

  defp perform_universal_search(query) do
    # Perform parallel searches across all types
    tasks = [
      Task.async(fn -> search_systems(query) end),
      Task.async(fn -> search_characters(query) end),
      Task.async(fn -> search_corporations(query) end)
    ]

    [systems, characters, corporations] = Task.await_many(tasks, 5000)

    # Combine results in a single list with type information
    results = []
    results = results ++ Enum.map(systems, &Map.put(&1, :type, "system"))
    results = results ++ Enum.map(characters, &Map.put(&1, :type, "character"))
    results = results ++ Enum.map(corporations, &Map.put(&1, :type, "corporation"))

    # Sort by relevance and take top 10
    results
    |> Enum.sort_by(fn result ->
      # Simple relevance scoring - exact matches first
      if String.downcase(result.name) == String.downcase(query) do
        0
      else
        1
      end
    end)
    |> Enum.take(10)
  end

  defp search_systems(query) do
    alias EveDmv.Eve.SolarSystem

    case SolarSystem.search_by_name(name_pattern: query, similarity_threshold: 0.2) do
      {:ok, systems} ->
        systems
        |> Enum.take(3)
        |> Enum.map(fn system ->
          %{
            id: system.system_id,
            name: system.system_name,
            subtitle: "#{system.constellation_name} • #{system.region_name}",
            type_label: "System"
          }
        end)

      {:error, _reason} ->
        []
    end
  end

  defp search_characters(query) do
    # Search in participants table for character names
    character_query = """
    SELECT DISTINCT
      p.character_id,
      p.character_name,
      p.corporation_name,
      p.alliance_name,
      COUNT(*) as activity_count
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE p.character_name ILIKE $1
    GROUP BY p.character_id, p.character_name, p.corporation_name, p.alliance_name
    ORDER BY activity_count DESC
    LIMIT 3
    """

    search_pattern = "%#{query}%"

    case Ecto.Adapters.SQL.query(EveDmv.Repo, character_query, [search_pattern]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [char_id, char_name, corp_name, alliance_name, _activity] ->
          %{
            id: char_id,
            name: char_name || "Unknown Character",
            subtitle: format_character_subtitle(corp_name, alliance_name),
            type_label: "Character"
          }
        end)

      {:error, _reason} ->
        []
    end
  end

  defp search_corporations(query) do
    # Search in participants table for corporation names
    corp_query = """
    SELECT DISTINCT
      p.corporation_id,
      p.corporation_name,
      p.alliance_name,
      COUNT(DISTINCT p.character_id) as member_count
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE p.corporation_name ILIKE $1
      AND p.corporation_id IS NOT NULL
    GROUP BY p.corporation_id, p.corporation_name, p.alliance_name
    ORDER BY member_count DESC
    LIMIT 3
    """

    search_pattern = "%#{query}%"

    case Ecto.Adapters.SQL.query(EveDmv.Repo, corp_query, [search_pattern]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [corp_id, corp_name, alliance_name, members] ->
          %{
            id: corp_id,
            name: corp_name || "Unknown Corporation",
            subtitle: format_corporation_subtitle(alliance_name, members),
            type_label: "Corporation"
          }
        end)

      {:error, _reason} ->
        []
    end
  end

  defp format_character_subtitle(corp_name, alliance_name) do
    parts = []
    parts = if corp_name, do: [corp_name | parts], else: parts
    parts = if alliance_name, do: [alliance_name | parts], else: parts

    case parts do
      [] -> "Independent"
      [corp] -> corp
      [corp, alliance] -> "#{corp} • #{alliance}"
      _ -> Enum.join(parts, " • ")
    end
  end

  defp format_corporation_subtitle(alliance_name, member_count) do
    alliance_part = if alliance_name, do: alliance_name, else: "Independent"
    "#{alliance_part} • #{member_count} active members"
  end
end
