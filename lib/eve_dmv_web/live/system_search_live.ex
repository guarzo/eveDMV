defmodule EveDmvWeb.SystemSearchLive do
  @moduledoc """
  LiveView component for searching EVE Online solar systems.

  Provides autocomplete search functionality with fuzzy matching
  and navigates to system intelligence pages on selection.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Eve.SolarSystem

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "System Search",
       query: "",
       results: [],
       selected_index: 0,
       loading: false,
       show_dropdown: false,
       focused: false
     )}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(query: query)
      |> search_systems(query)

    {:noreply, socket}
  end

  @impl true
  def handle_event("focus", _params, socket) do
    {:noreply, assign(socket, focused: true, show_dropdown: true)}
  end

  @impl true
  def handle_event("blur", _params, socket) do
    # Delay hiding dropdown to allow click events
    Process.send_after(self(), :hide_dropdown, 200)
    {:noreply, assign(socket, focused: false)}
  end

  @impl true
  def handle_event("select_system", %{"system_id" => system_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/system/#{system_id}")}
  end

  @impl true
  def handle_event("key_down", %{"key" => key}, socket) do
    handle_keyboard_navigation(socket, key)
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    socket =
      socket
      |> assign(query: "", results: [], show_dropdown: false, selected_index: 0)

    {:noreply, socket}
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
      {:noreply, assign(socket, results: results, loading: false, show_dropdown: true)}
    else
      {:noreply, socket}
    end
  end

  defp search_systems(socket, "") do
    assign(socket, results: [], show_dropdown: false, loading: false)
  end

  defp search_systems(socket, query) when byte_size(query) < 2 do
    assign(socket, results: [], show_dropdown: false, loading: false)
  end

  defp search_systems(socket, query) do
    self_pid = self()
    current_query = query

    Task.start(fn ->
      results = perform_search(query)
      send(self_pid, {:search_results, current_query, results})
    end)

    assign(socket, loading: true, show_dropdown: true)
  end

  defp perform_search(query) do
    # Use SolarSystem search action with fuzzy matching
    case SolarSystem.search_by_name(name_pattern: query, similarity_threshold: 0.2) do
      {:ok, systems} ->
        systems
        |> Enum.take(10)
        |> Enum.map(fn system ->
          %{
            system_id: system.system_id,
            system_name: system.system_name,
            region_name: system.region_name,
            constellation_name: system.constellation_name,
            security_status: system.security_status,
            security_class: system.security_class
          }
        end)

      {:error, _reason} ->
        []
    end
  end

  defp handle_keyboard_navigation(socket, "ArrowDown") do
    max_index = length(socket.assigns.results) - 1
    new_index = min(socket.assigns.selected_index + 1, max_index)
    {:noreply, assign(socket, selected_index: new_index)}
  end

  defp handle_keyboard_navigation(socket, "ArrowUp") do
    new_index = max(socket.assigns.selected_index - 1, 0)
    {:noreply, assign(socket, selected_index: new_index)}
  end

  defp handle_keyboard_navigation(socket, "Enter") do
    if socket.assigns.results != [] do
      selected_system = Enum.at(socket.assigns.results, socket.assigns.selected_index)

      if selected_system do
        {:noreply, push_navigate(socket, to: ~p"/system/#{selected_system.system_id}")}
      else
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

  defp security_class_color(security_class) do
    case security_class do
      "highsec" -> "text-green-400"
      "lowsec" -> "text-yellow-400"
      "nullsec" -> "text-red-400"
      "wormhole" -> "text-purple-400"
      _ -> "text-gray-400"
    end
  end

  defp format_security_status(nil), do: ""

  defp format_security_status(security_status) do
    Float.round(Decimal.to_float(security_status), 1)
  end
end
