defmodule EveDmvWeb.SearchComponent do
  @moduledoc """
  Reusable search component for system, character, and corporation searches.
  Can be embedded in any LiveView page.
  """

  use EveDmvWeb, :live_component

  alias Ecto.Adapters.SQL

  require Logger

  @impl Phoenix.LiveComponent
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

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(query: query)
      |> search(query)

    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("focus", _params, socket) do
    {:noreply, assign(socket, focused: true, show_dropdown: true)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("blur", _params, socket) do
    send(self(), {:hide_dropdown, socket.assigns.id})
    {:noreply, assign(socket, focused: false)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("select_result", %{"type" => type, "id" => id}, socket) do
    path =
      case type do
        "system" -> ~p"/system/#{id}"
        "character" -> ~p"/character/#{id}"
        "corporation" -> ~p"/corporation/#{id}"
        _ -> "/"
      end

    {:noreply,
     socket
     |> assign(show_dropdown: false, query: "")
     |> push_navigate(to: path)}
  end

  @impl Phoenix.LiveComponent
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

  @impl Phoenix.LiveComponent
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
            phx-debounce="500"
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

  # Wraps a search function with proper exception logging
  defp safe_search(search_type, query, search_fn) do
    search_fn.(query)
  rescue
    error ->
      Logger.error(
        "Search failed: type=#{search_type} query=#{inspect(query)} error=#{Exception.message(error)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
      )

      []
  end

  defp perform_universal_search(query) do
    # Perform parallel searches across all types with error handling
    # Each search is wrapped with proper error logging for debugging
    search_timeout = 5_000

    tasks = [
      Task.async(fn -> {:systems, safe_search(:systems, query, &search_systems/1)} end),
      Task.async(fn -> {:characters, safe_search(:characters, query, &search_characters/1)} end),
      Task.async(fn ->
        {:corporations, safe_search(:corporations, query, &search_corporations/1)}
      end)
    ]

    # Use Task.yield_many with explicit timeout handling
    results = Task.yield_many(tasks, timeout: search_timeout)

    # Process results, handling timeouts and exits with proper logging
    {systems, characters, corporations} =
      Enum.reduce(results, {[], [], []}, fn {task, result}, {sys, chars, corps} ->
        case result do
          {:ok, {:systems, data}} ->
            {data, chars, corps}

          {:ok, {:characters, data}} ->
            {sys, data, corps}

          {:ok, {:corporations, data}} ->
            {sys, chars, data}

          {:exit, reason} ->
            # Log the exit reason with context
            Logger.error("Search task exited: query=#{inspect(query)} reason=#{inspect(reason)}")

            Task.shutdown(task, :brutal_kill)
            {sys, chars, corps}

          nil ->
            # Task timed out
            Logger.warning(
              "Search task timed out: query=#{inspect(query)} timeout_ms=#{search_timeout}"
            )

            Task.shutdown(task, :brutal_kill)
            {sys, chars, corps}
        end
      end)

    # Combine results in a single list with type information
    # Sort by relevance and take top 10
    Enum.concat([
      Enum.map(systems, &Map.put(&1, :type, "system")),
      Enum.map(characters, &Map.put(&1, :type, "character")),
      Enum.map(corporations, &Map.put(&1, :type, "corporation"))
    ])
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

    # Try the Ash search first
    case SolarSystem.search_by_name(name_pattern: query, similarity_threshold: 0.2) do
      {:ok, systems} when systems != [] ->
        systems
        |> Enum.take(3)
        |> Enum.map(fn system ->
          %{
            id: system.system_id,
            name: system.system_name,
            subtitle: "#{system.constellation_name} • #{system.region_name}",
            security_class: system.security_class,
            type_label: "System"
          }
        end)

      # Fallback to direct SQL search if Ash search fails or returns no results
      _ ->
        fallback_system_search(query)
    end
  end

  defp fallback_system_search(query) do
    search_pattern = "%#{query}%"

    system_query = """
    SELECT
      system_id,
      system_name,
      constellation_name,
      region_name,
      security_class
    FROM eve_solar_systems
    WHERE system_name ILIKE $1
    ORDER BY
      CASE WHEN system_name ILIKE $1 THEN 0 ELSE 1 END,
      system_name
    LIMIT 3
    """

    case SQL.query(EveDmv.Repo, system_query, [search_pattern]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [sys_id, sys_name, const_name, reg_name, sec_class] ->
          %{
            id: sys_id,
            name: sys_name,
            subtitle: "#{const_name || "Unknown"} • #{reg_name || "Unknown"}",
            security_class: sec_class,
            type_label: "System"
          }
        end)

      {:error, _reason} ->
        []
    end
  end

  defp search_characters(query) do
    # Search in participants table for character names using trigram similarity
    # Uses the % operator which efficiently uses GIN trigram indexes
    # Falls back to ILIKE for short queries (< 3 chars) where trigrams don't work well
    if String.length(query) >= 3 do
      search_characters_trigram(query)
    else
      search_characters_ilike(query)
    end
  end

  defp search_characters_trigram(query) do
    # Trigram similarity search - uses GIN index efficiently
    # Groups by character to deduplicate, orders by similarity score
    # NOTE: Must include "character_name IS NOT NULL" to use partial index
    character_query = """
    SELECT character_id, character_name, corporation_name, alliance_name
    FROM (
      SELECT DISTINCT ON (character_id)
        character_id,
        character_name,
        corporation_name,
        alliance_name,
        similarity(character_name, $1) as sim
      FROM participants
      WHERE character_name IS NOT NULL
        AND character_name % $1
        AND character_id IS NOT NULL
      ORDER BY character_id, similarity(character_name, $1) DESC
    ) sub
    ORDER BY sim DESC, character_name
    LIMIT 5
    """

    case SQL.query(EveDmv.Repo, character_query, [query], timeout: 3_000) do
      {:ok, %{rows: []}} ->
        # Trigram returned nothing - fall back to ILIKE for exact/prefix matches
        Logger.debug("Trigram search returned no results for '#{query}', trying ILIKE fallback")
        search_characters_ilike_fallback(query)

      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [char_id, char_name, corp_name, alliance_name] ->
          %{
            id: char_id,
            name: char_name || "Unknown Character",
            subtitle: EveDmvWeb.SearchHelpers.format_character_subtitle(corp_name, alliance_name),
            type_label: "Character"
          }
        end)

      {:error, reason} ->
        Logger.error("search_characters_trigram failed: #{inspect(reason)}")
        # Fall back to ILIKE on error
        search_characters_ilike_fallback(query)
    end
  end

  defp search_characters_ilike_fallback(query) do
    # Fallback using ILIKE with LIMIT to prevent full scan
    character_query = """
    SELECT character_id, character_name, corporation_name, alliance_name
    FROM (
      SELECT DISTINCT ON (character_id)
        character_id,
        character_name,
        corporation_name,
        alliance_name
      FROM participants
      WHERE character_name ILIKE $1
        AND character_id IS NOT NULL
      ORDER BY character_id
      LIMIT 100
    ) sub
    ORDER BY
      CASE WHEN character_name ILIKE $2 THEN 0 ELSE 1 END,
      length(character_name)
    LIMIT 5
    """

    search_pattern = "%#{query}%"
    prefix_pattern = "#{query}%"

    case SQL.query(EveDmv.Repo, character_query, [search_pattern, prefix_pattern], timeout: 5_000) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [char_id, char_name, corp_name, alliance_name] ->
          %{
            id: char_id,
            name: char_name || "Unknown Character",
            subtitle: EveDmvWeb.SearchHelpers.format_character_subtitle(corp_name, alliance_name),
            type_label: "Character"
          }
        end)

      {:error, reason} ->
        Logger.error("search_characters_ilike_fallback failed: #{inspect(reason)}")
        []
    end
  end

  defp search_characters_ilike(query) do
    # Prefix search for short queries - still reasonably fast with btree index
    character_query = """
    SELECT DISTINCT ON (character_id)
      character_id,
      character_name,
      corporation_name,
      alliance_name
    FROM participants
    WHERE character_name ILIKE $1
      AND character_id IS NOT NULL
    ORDER BY character_id
    LIMIT 5
    """

    search_pattern = "#{query}%"

    case SQL.query(EveDmv.Repo, character_query, [search_pattern], timeout: 3_000) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [char_id, char_name, corp_name, alliance_name] ->
          %{
            id: char_id,
            name: char_name || "Unknown Character",
            subtitle: EveDmvWeb.SearchHelpers.format_character_subtitle(corp_name, alliance_name),
            type_label: "Character"
          }
        end)

      {:error, reason} ->
        Logger.error("search_characters_ilike failed: #{inspect(reason)}")
        []
    end
  end

  defp search_corporations(query) do
    # Search in participants table for corporation names using trigram similarity
    # Uses the % operator which efficiently uses GIN trigram indexes
    # Falls back to ILIKE for short queries (< 3 chars) where trigrams don't work well
    if String.length(query) >= 3 do
      search_corporations_trigram(query)
    else
      search_corporations_ilike(query)
    end
  end

  defp search_corporations_trigram(query) do
    # Trigram similarity search - uses GIN index efficiently
    # Orders by similarity score for best matches first
    # NOTE: Must include "corporation_name IS NOT NULL" to use partial index
    corp_query = """
    SELECT corporation_id, corporation_name, alliance_name
    FROM (
      SELECT DISTINCT ON (corporation_id)
        corporation_id,
        corporation_name,
        alliance_name,
        similarity(corporation_name, $1) as sim
      FROM participants
      WHERE corporation_name IS NOT NULL
        AND corporation_name % $1
        AND corporation_id IS NOT NULL
      ORDER BY corporation_id, similarity(corporation_name, $1) DESC
    ) sub
    ORDER BY sim DESC, corporation_name
    LIMIT 5
    """

    case SQL.query(EveDmv.Repo, corp_query, [query], timeout: 3_000) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [corp_id, corp_name, alliance_name] ->
          %{
            id: corp_id,
            name: corp_name || "Unknown Corporation",
            subtitle: EveDmvWeb.SearchHelpers.format_corporation_subtitle(alliance_name, nil),
            type_label: "Corporation"
          }
        end)

      {:error, reason} ->
        Logger.error("search_corporations_trigram failed: #{inspect(reason)}")
        []
    end
  end

  defp search_corporations_ilike(query) do
    # Prefix search for short queries
    corp_query = """
    SELECT DISTINCT ON (corporation_id)
      corporation_id,
      corporation_name,
      alliance_name
    FROM participants
    WHERE corporation_name ILIKE $1
      AND corporation_id IS NOT NULL
    ORDER BY corporation_id
    LIMIT 5
    """

    search_pattern = "#{query}%"

    case SQL.query(EveDmv.Repo, corp_query, [search_pattern], timeout: 3_000) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [corp_id, corp_name, alliance_name] ->
          %{
            id: corp_id,
            name: corp_name || "Unknown Corporation",
            subtitle: EveDmvWeb.SearchHelpers.format_corporation_subtitle(alliance_name, nil),
            type_label: "Corporation"
          }
        end)

      {:error, reason} ->
        Logger.error("search_corporations_ilike failed: #{inspect(reason)}")
        []
    end
  end
end
