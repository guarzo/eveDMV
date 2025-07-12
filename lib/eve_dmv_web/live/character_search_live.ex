defmodule EveDmvWeb.CharacterSearchLive do
  @moduledoc """
  LiveView for searching EVE Online characters and accessing their intelligence reports.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Eve.NameResolver

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Character Search")
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> assign(:searching, false)
      |> assign(:error_message, nil)
      |> assign(:recent_searches, load_recent_searches())

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:searching, true)
      |> assign(:error_message, nil)
      |> perform_search(query)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("view_character", %{"character_id" => character_id}, socket) do
    # Save to recent searches
    save_recent_search(character_id)

    {:noreply,
     socket
     |> push_navigate(to: ~p"/character/#{character_id}/intelligence")}
  end

  defp perform_search(socket, query) when byte_size(query) < 3 do
    socket
    |> assign(:searching, false)
    |> assign(:search_results, [])
    |> assign(:error_message, "Please enter at least 3 characters")
  end

  defp perform_search(socket, query) do
    case search_characters(query) do
      {:ok, results} ->
        socket
        |> assign(:searching, false)
        |> assign(:search_results, results)
        |> assign(:error_message, nil)

      {:error, _reason} ->
        socket
        |> assign(:searching, false)
        |> assign(:search_results, [])
        |> assign(:error_message, "Search failed. Please try again.")
    end
  end

  defp search_characters(query) do
    # For now, use a simple search approach
    # In the future, this could use ESI search API
    case Integer.parse(query) do
      {character_id, ""} ->
        # Direct character ID lookup
        character_name = NameResolver.character_name(character_id)

        if character_name != "Unknown Character" do
          {:ok,
           [
             %{
               character_id: character_id,
               name: character_name,
               portrait_url: character_portrait(character_id)
             }
           ]}
        else
          {:ok, []}
        end

      _ ->
        # Text search - would need ESI search implementation
        # For now, return empty results
        {:ok, []}
    end
  end

  defp load_recent_searches do
    # In a real implementation, this would load from user preferences or cache
    []
  end

  defp save_recent_search(_character_id) do
    # In a real implementation, this would save to user preferences or cache
    :ok
  end

  def character_portrait(character_id, size \\ 64) do
    "https://images.evetech.net/characters/#{character_id}/portrait?size=#{size}"
  end
end
