defmodule EveDmvWeb.HomeLive do
  @moduledoc """
  LiveView home page with integrated universal search functionality.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Eve.SolarSystem

  @impl true
  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user")

    {:ok,
     assign(socket,
       page_title: "EVE DMV - PvP Intelligence Platform",
       current_user: current_user,
       search_query: "",
       search_results: %{systems: [], characters: [], corporations: []},
       search_loading: false,
       show_search_dropdown: false,
       search_focused: false
     )}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(search_query: query)
      |> perform_search(query)

    {:noreply, socket}
  end

  @impl true
  def handle_event("search_focus", _params, socket) do
    {:noreply, assign(socket, search_focused: true, show_search_dropdown: true)}
  end

  @impl true
  def handle_event("search_blur", _params, socket) do
    Process.send_after(self(), :hide_search_dropdown, 200)
    {:noreply, assign(socket, search_focused: false)}
  end

  @impl true
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

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply,
     assign(socket,
       search_query: "",
       search_results: %{systems: [], characters: [], corporations: []},
       show_search_dropdown: false
     )}
  end

  @impl true
  def handle_info(:hide_search_dropdown, socket) do
    if !socket.assigns.search_focused do
      {:noreply, assign(socket, show_search_dropdown: false)}
    else
      {:noreply, socket}
    end
  end

  @impl true
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

    case Ecto.Adapters.SQL.query(EveDmv.Repo, system_query, [search_pattern]) do
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
    # Quick character search
    search_pattern = "%#{query}%"

    character_query = """
    SELECT DISTINCT
      p.character_id,
      p.character_name,
      p.corporation_name,
      COUNT(*) as activity_count
    FROM participants p
    WHERE p.character_name ILIKE $1
    GROUP BY p.character_id, p.character_name, p.corporation_name
    ORDER BY activity_count DESC
    LIMIT 3
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, character_query, [search_pattern]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, name, corp, _] ->
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
    # Quick corporation search
    search_pattern = "%#{query}%"

    corp_query = """
    SELECT DISTINCT
      p.corporation_id,
      p.corporation_name,
      COUNT(DISTINCT p.character_id) as member_count
    FROM participants p
    WHERE p.corporation_name ILIKE $1
      AND p.corporation_id IS NOT NULL
    GROUP BY p.corporation_id, p.corporation_name
    ORDER BY member_count DESC
    LIMIT 3
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, corp_query, [search_pattern]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, name, members] ->
          %{
            id: id,
            name: name || "Unknown",
            subtitle: "#{members} active members"
          }
        end)

      {:error, _} ->
        []
    end
  end

  def has_search_results?(results) do
    results.systems != [] || results.characters != [] || results.corporations != []
  end
end
