defmodule EveDmvWeb.UniversalSearchLive do
  @moduledoc """
  Universal search component that searches across:
  - Solar Systems
  - Characters
  - Corporations

  Provides real-time autocomplete and categorized results.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Eve.SolarSystem
  alias EveDmv.Cache.AnalysisCache

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Universal Search",
       query: "",
       results: %{
         systems: [],
         characters: [],
         corporations: []
       },
       selected_index: 0,
       selected_category: nil,
       loading: false,
       show_dropdown: false,
       focused: false,
       recent_searches: load_recent_searches()
     )}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(query: query)
      |> search_all(query)

    {:noreply, socket}
  end

  @impl true
  def handle_event("focus", _params, socket) do
    {:noreply, assign(socket, focused: true, show_dropdown: true)}
  end

  @impl true
  def handle_event("blur", _params, socket) do
    Process.send_after(self(), :hide_dropdown, 200)
    {:noreply, assign(socket, focused: false)}
  end

  @impl true
  def handle_event("select_result", %{"type" => type, "id" => id}, socket) do
    # Save to recent searches
    save_recent_search(type, id, socket.assigns.query)

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
  def handle_event("key_down", %{"key" => key}, socket) do
    handle_keyboard_navigation(socket, key)
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    socket =
      socket
      |> assign(
        query: "",
        results: %{systems: [], characters: [], corporations: []},
        show_dropdown: false,
        selected_index: 0,
        selected_category: nil
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_recent", _params, socket) do
    clear_recent_searches()
    {:noreply, assign(socket, recent_searches: [])}
  end

  @impl true
  def handle_info(:hide_dropdown, socket) do
    if !socket.assigns.focused do
      {:noreply, assign(socket, show_dropdown: false)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:search_results, query, results}, socket) do
    if query == socket.assigns.query do
      # Flatten results for navigation
      flattened = flatten_results(results)
      selected_category = if length(flattened) > 0, do: elem(hd(flattened), 0), else: nil

      {:noreply,
       assign(socket,
         results: results,
         loading: false,
         show_dropdown: true,
         selected_index: 0,
         selected_category: selected_category
       )}
    else
      {:noreply, socket}
    end
  end

  defp search_all(socket, "") do
    assign(socket,
      results: %{systems: [], characters: [], corporations: []},
      show_dropdown: false,
      loading: false
    )
  end

  defp search_all(socket, query) when byte_size(query) < 2 do
    assign(socket,
      results: %{systems: [], characters: [], corporations: []},
      show_dropdown: false,
      loading: false
    )
  end

  defp search_all(socket, query) do
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

    assign(socket, loading: true, show_dropdown: true)
  end

  defp search_systems(query) do
    case SolarSystem.search_by_name(name_pattern: query, similarity_threshold: 0.2) do
      {:ok, systems} ->
        systems
        |> Enum.take(5)
        |> Enum.map(fn system ->
          %{
            id: system.system_id,
            name: system.system_name,
            subtitle: "#{system.constellation_name} • #{system.region_name}",
            meta: %{
              security_class: system.security_class,
              security_status: system.security_status
            }
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
      COUNT(*) as activity_count,
      MAX(k.killmail_time) as last_seen
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE p.character_name ILIKE $1
    GROUP BY p.character_id, p.character_name, p.corporation_name, p.alliance_name
    ORDER BY activity_count DESC
    LIMIT 5
    """

    search_pattern = "%#{query}%"

    case Ecto.Adapters.SQL.query(EveDmv.Repo, character_query, [search_pattern]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [char_id, char_name, corp_name, alliance_name, activity, last_seen] ->
          %{
            id: char_id,
            name: char_name || "Unknown Character",
            subtitle: format_character_subtitle(corp_name, alliance_name),
            meta: %{
              activity_count: activity,
              last_seen: last_seen
            }
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
      COUNT(DISTINCT p.character_id) as member_count,
      COUNT(*) as activity_count,
      MAX(k.killmail_time) as last_seen
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE p.corporation_name ILIKE $1
      AND p.corporation_id IS NOT NULL
    GROUP BY p.corporation_id, p.corporation_name, p.alliance_name
    ORDER BY activity_count DESC
    LIMIT 5
    """

    search_pattern = "%#{query}%"

    case Ecto.Adapters.SQL.query(EveDmv.Repo, corp_query, [search_pattern]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [corp_id, corp_name, alliance_name, members, activity, last_seen] ->
          %{
            id: corp_id,
            name: corp_name || "Unknown Corporation",
            subtitle: format_corporation_subtitle(alliance_name, members),
            meta: %{
              member_count: members,
              activity_count: activity,
              last_seen: last_seen
            }
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

  defp flatten_results(results) do
    systems = Enum.map(results.systems, &{:system, &1})
    characters = Enum.map(results.characters, &{:character, &1})
    corporations = Enum.map(results.corporations, &{:corporation, &1})

    systems ++ characters ++ corporations
  end

  defp handle_keyboard_navigation(socket, "ArrowDown") do
    flattened = flatten_results(socket.assigns.results)
    max_index = length(flattened) - 1

    if max_index >= 0 do
      new_index = min(socket.assigns.selected_index + 1, max_index)
      {category, _} = Enum.at(flattened, new_index)
      {:noreply, assign(socket, selected_index: new_index, selected_category: category)}
    else
      {:noreply, socket}
    end
  end

  defp handle_keyboard_navigation(socket, "ArrowUp") do
    flattened = flatten_results(socket.assigns.results)
    new_index = max(socket.assigns.selected_index - 1, 0)

    if length(flattened) > 0 do
      {category, _} = Enum.at(flattened, new_index)
      {:noreply, assign(socket, selected_index: new_index, selected_category: category)}
    else
      {:noreply, socket}
    end
  end

  defp handle_keyboard_navigation(socket, "Enter") do
    flattened = flatten_results(socket.assigns.results)

    if length(flattened) > 0 do
      case Enum.at(flattened, socket.assigns.selected_index) do
        {type, result} ->
          type_string = Atom.to_string(type)
          {:noreply, push_navigate(socket, to: build_path(type_string, result.id))}

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  defp handle_keyboard_navigation(socket, "Escape") do
    {:noreply, assign(socket, show_dropdown: false, selected_index: 0)}
  end

  defp handle_keyboard_navigation(socket, _key) do
    {:noreply, socket}
  end

  def build_path("system", id), do: ~p"/system/#{id}"
  def build_path("character", id), do: ~p"/character/#{id}"
  def build_path("corporation", id), do: ~p"/corporation/#{id}"
  def build_path(_, _), do: "/"

  # Recent searches management
  defp load_recent_searches do
    case AnalysisCache.get("recent_searches") do
      {:ok, searches} -> Enum.take(searches, 10)
      :miss -> []
      _ -> []
    end
  end

  defp save_recent_search(type, id, query) do
    recent = load_recent_searches()

    new_search = %{
      type: type,
      id: id,
      query: query,
      timestamp: DateTime.utc_now()
    }

    # Remove duplicates and add new search at the beginning
    updated =
      [new_search | Enum.reject(recent, &(&1.id == id && &1.type == type))]
      |> Enum.take(10)

    # 24 hours
    AnalysisCache.put("recent_searches", updated, 86_400_000)
  end

  defp clear_recent_searches do
    AnalysisCache.delete("recent_searches")
  end

  # Helper functions for template
  def has_results?(results) do
    results.systems != [] || results.characters != [] || results.corporations != []
  end

  def get_category_index(results, selected_index) do
    systems_count = length(results.systems)
    characters_count = length(results.characters)

    cond do
      selected_index < systems_count ->
        selected_index

      selected_index < systems_count + characters_count ->
        selected_index - systems_count

      true ->
        selected_index - systems_count - characters_count
    end
  end

  def security_class_color(security_class) do
    case security_class do
      "highsec" -> "text-green-400"
      "lowsec" -> "text-yellow-400"
      "nullsec" -> "text-red-400"
      "wormhole" -> "text-purple-400"
      _ -> "text-gray-400"
    end
  end

  def time_ago(nil), do: "unknown"

  def time_ago(%DateTime{} = datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      seconds when seconds < 60 -> "just now"
      seconds when seconds < 3600 -> "#{div(seconds, 60)}m ago"
      seconds when seconds < 86400 -> "#{div(seconds, 3600)}h ago"
      seconds when seconds < 604_800 -> "#{div(seconds, 86400)}d ago"
      seconds -> "#{div(seconds, 604_800)}w ago"
    end
  end

  def time_ago(%NaiveDateTime{} = datetime) do
    datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> time_ago()
  end

  def time_ago(_), do: "unknown"
end
