defmodule EveDmvWeb.HomeLive do
  @moduledoc """
  LiveView home page with integrated universal search functionality.
  """

  use EveDmvWeb, :live_view

  alias Ecto.Adapters.SQL
  alias EveDmv.Eve.SolarSystem

  # Load current user from session on mount (optional for public pages)
  on_mount({EveDmvWeb.AuthLive, :load_from_session_optional})

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "EVE DMV - PvP Intelligence Platform",
       search_query: "",
       search_results: %{systems: [], characters: [], corporations: []},
       search_loading: false,
       show_search_dropdown: false,
       search_focused: false
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(search_query: query)
      |> perform_search(query)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("search_focus", _params, socket) do
    {:noreply, assign(socket, search_focused: true, show_search_dropdown: true)}
  end

  @impl Phoenix.LiveView
  def handle_event("search_blur", _params, socket) do
    Process.send_after(self(), :hide_search_dropdown, 200)
    {:noreply, assign(socket, search_focused: false)}
  end

  @impl Phoenix.LiveView
  def handle_event("select_search_result", %{"type" => type, "id" => id}, socket) do
    path =
      case type do
        "system" -> ~p"/system/#{id}"
        "character" -> ~p"/character/#{id}"
        "corporation" -> ~p"/corporation/#{id}"
        _ -> "/"
      end

    {:noreply, push_navigate(socket, to: path)}
  end

  @impl Phoenix.LiveView
  def handle_event("clear_search", _params, socket) do
    {:noreply,
     assign(socket,
       search_query: "",
       search_results: %{systems: [], characters: [], corporations: []},
       show_search_dropdown: false
     )}
  end

  @impl Phoenix.LiveView
  def handle_info(:hide_search_dropdown, socket) do
    if socket.assigns.search_focused do
      {:noreply, socket}
    else
      {:noreply, assign(socket, show_search_dropdown: false)}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:hide_dropdown, _component_id}, socket) do
    # Delay hiding to allow click events to fire on dropdown items
    Process.send_after(self(), :hide_search_dropdown, 200)
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:search_results, query, results}, socket) do
    if query == socket.assigns.search_query do
      {:noreply,
       assign(socket,
         search_results: results,
         search_loading: false,
         show_search_dropdown: true
       )}
    else
      {:noreply, socket}
    end
  end

  defp perform_search(socket, "") do
    assign(socket,
      search_results: %{systems: [], characters: [], corporations: []},
      show_search_dropdown: false,
      search_loading: false
    )
  end

  defp perform_search(socket, query) when byte_size(query) < 2 do
    assign(socket,
      search_results: %{systems: [], characters: [], corporations: []},
      show_search_dropdown: false,
      search_loading: false
    )
  end

  defp perform_search(socket, query) do
    self_pid = self()
    current_query = query

    Task.start(fn ->
      results = %{
        systems: search_systems(query),
        characters: search_characters(query),
        corporations: search_corporations(query)
      }

      send(self_pid, {:search_results, current_query, results})
    end)

    assign(socket, search_loading: true, show_search_dropdown: true)
  end

  defp search_systems(query) do
    # Try the Ash search first with a lower threshold
    case SolarSystem.search_by_name(name_pattern: query, similarity_threshold: 0.1) do
      {:ok, [_ | _] = systems} ->
        systems
        |> Enum.take(3)
        |> Enum.map(fn system ->
          %{
            id: system.system_id,
            name: system.system_name,
            subtitle: "#{system.region_name}",
            security_class: system.security_class
          }
        end)

      # Fallback to direct SQL search if Ash search fails or returns no results
      {:ok, []} ->
        fallback_system_search(query)

      {:error, _reason} ->
        fallback_system_search(query)
    end
  end

  defp fallback_system_search(query) do
    search_pattern = "%#{query}%"

    system_query = """
    SELECT DISTINCT
      system_id,
      system_name,
      region_name,
      security_class
    FROM eve_solar_systems
    WHERE system_name ILIKE $1
    ORDER BY system_name
    LIMIT 3
    """

    case SQL.query(EveDmv.Repo, system_query, [search_pattern]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, name, region, security_class] ->
          %{
            id: id,
            name: name || "Unknown",
            subtitle: region || "Unknown Region",
            security_class: security_class
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp search_characters(query) do
    # Use trigram similarity for queries >= 3 chars, prefix search otherwise
    if String.length(query) >= 3 do
      search_characters_trigram(query)
    else
      search_characters_prefix(query)
    end
  end

  defp search_characters_trigram(query) do
    # Trigram similarity search - uses GIN index efficiently
    character_query = """
    SELECT character_id, character_name, corporation_name
    FROM (
      SELECT DISTINCT ON (character_id)
        p.character_id,
        p.character_name,
        p.corporation_name,
        similarity(p.character_name, $1) as sim
      FROM participants p
      WHERE p.character_name % $1
        AND p.character_id IS NOT NULL
      ORDER BY p.character_id, similarity(p.character_name, $1) DESC
    ) sub
    ORDER BY sim DESC, character_name
    LIMIT 5
    """

    case SQL.query(EveDmv.Repo, character_query, [query], timeout: 3_000) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, name, corp] ->
          %{
            id: id,
            name: name || "Unknown",
            subtitle: corp || "Unknown Corp"
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp search_characters_prefix(query) do
    # Prefix search for short queries
    character_query = """
    SELECT DISTINCT ON (character_id)
      p.character_id,
      p.character_name,
      p.corporation_name
    FROM participants p
    WHERE p.character_name ILIKE $1
      AND p.character_id IS NOT NULL
    ORDER BY p.character_id
    LIMIT 5
    """

    search_pattern = "#{query}%"

    case SQL.query(EveDmv.Repo, character_query, [search_pattern], timeout: 3_000) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, name, corp] ->
          %{
            id: id,
            name: name || "Unknown",
            subtitle: corp || "Unknown Corp"
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp search_corporations(query) do
    # Use trigram similarity for queries >= 3 chars, prefix search otherwise
    if String.length(query) >= 3 do
      search_corporations_trigram(query)
    else
      search_corporations_prefix(query)
    end
  end

  defp search_corporations_trigram(query) do
    # Trigram similarity search - uses GIN index efficiently
    corp_query = """
    SELECT corporation_id, corporation_name, alliance_name
    FROM (
      SELECT DISTINCT ON (corporation_id)
        p.corporation_id,
        p.corporation_name,
        p.alliance_name,
        similarity(p.corporation_name, $1) as sim
      FROM participants p
      WHERE p.corporation_name % $1
        AND p.corporation_id IS NOT NULL
      ORDER BY p.corporation_id, similarity(p.corporation_name, $1) DESC
    ) sub
    ORDER BY sim DESC, corporation_name
    LIMIT 5
    """

    case SQL.query(EveDmv.Repo, corp_query, [query], timeout: 3_000) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, name, alliance] ->
          %{
            id: id,
            name: name || "Unknown",
            subtitle: alliance || "No Alliance"
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp search_corporations_prefix(query) do
    # Prefix search for short queries
    corp_query = """
    SELECT DISTINCT ON (corporation_id)
      p.corporation_id,
      p.corporation_name,
      p.alliance_name
    FROM participants p
    WHERE p.corporation_name ILIKE $1
      AND p.corporation_id IS NOT NULL
    ORDER BY p.corporation_id
    LIMIT 5
    """

    search_pattern = "#{query}%"

    case SQL.query(EveDmv.Repo, corp_query, [search_pattern], timeout: 3_000) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, name, alliance] ->
          %{
            id: id,
            name: name || "Unknown",
            subtitle: alliance || "No Alliance"
          }
        end)

      {:error, _} ->
        []
    end
  end

  def has_search_results?(results) do
    results.systems != [] || results.characters != [] || results.corporations != []
  end

  def show_search_dropdown?(assigns) do
    assigns[:current_user] &&
      assigns.show_search_dropdown &&
      !assigns.search_loading &&
      has_search_results?(assigns.search_results)
  end
end
