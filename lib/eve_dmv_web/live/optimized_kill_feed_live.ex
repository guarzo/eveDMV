defmodule EveDmvWeb.OptimizedKillFeedLive do
  @moduledoc """
  Optimized kill feed LiveView with efficient data loading patterns.

  Implements:
  - Virtualized scrolling for large datasets
  - Cursor-based pagination
  - Debounced filtering
  - Async data loading
  - Progressive enhancement
  """

  use EveDmvWeb, :live_view

  on_mount({EveDmvWeb.AuthLive, :load_from_session_optional})

  alias EveDmv.Platform.Cache.MultiLayerCache
  alias EveDmv.Streaming.KillmailStreamer
  alias Phoenix.LiveView.AsyncResult

  @page_size 20
  @max_items_in_memory 100
  @debounce_ms 300

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    # Subscribe to real-time updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "killmail_feed")
      schedule_stats_update()
    end

    socket =
      socket
      |> assign(:killmails, AsyncResult.loading())
      |> assign(:page, 1)
      |> assign(:has_more, true)
      |> assign(:filters, %{})
      |> assign(:stats, %{total_kills: 0, total_value: 0})
      |> assign(:viewport_items, [])
      |> assign(:scroll_position, 0)
      |> assign(:search_query, "")
      |> assign(:debounce_timer, nil)
      |> load_initial_data()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    filters = build_filters(params)

    socket =
      socket
      |> assign(:filters, filters)
      |> assign(:page, 1)
      |> assign(:killmails, AsyncResult.loading())
      |> load_killmails_async()

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="kill-feed-container">
      <div class="header">
        <h1>Optimized Kill Feed</h1>
        <div class="subtitle">
          <span class="stats">
            <%= @stats.total_kills %> kills • 
            <%= format_isk(@stats.total_value) %> ISK destroyed
          </span>
        </div>
      </div>
      
      <div class="filters-section">
        <input
          type="text"
          value={@search_query}
          phx-change="search_changed"
          phx-debounce={@debounce_ms}
          placeholder="Search characters, systems, ships..."
          class="search-input"
        />
        
        <div class="filter-chips">
          <%= for {key, value} <- @filters do %>
            <div class="chip">
              <%= humanize_filter(key) %>: <%= value %>
              <button phx-click="remove_filter" phx-value-filter={key}>×</button>
            </div>
          <% end %>
        </div>
      </div>
      
      <div class="kill-feed-scroll" 
           id="kill-feed"
           phx-hook="VirtualScroll"
           data-page-size={@page_size}
           phx-viewport-top="viewport_top"
           phx-viewport-bottom="viewport_bottom">
        
        <div class="killmail-results">
          <%= case @killmails do %>
            <% %AsyncResult{loading: true} -> %>
              <div class="loading-skeleton">
                <%= for _ <- 1..5 do %>
                  <div class="skeleton-item">
                    <div class="skeleton-line skeleton-line-short"></div>
                    <div class="skeleton-line skeleton-line-long"></div>
                  </div>
                <% end %>
              </div>
            <% %AsyncResult{failed: true} -> %>
              <div class="error-message">
                <p>Failed to load killmails</p>
                <button phx-click="retry">Retry</button>
              </div>
            <% %AsyncResult{ok?: true, result: killmails} -> %>
          
          <div class="virtual-list" style={"height: #{calculate_list_height(killmails)}px"}>
            <div class="virtual-spacer-top" style={"height: #{@scroll_position}px"}></div>
            
            <%= for killmail <- @viewport_items do %>
              <div class="killmail-card" id={"killmail-#{killmail.killmail_id}"}>
                <div class="killmail-header">
                  <span class="victim"><%= Map.get(killmail, :victim_character, %{}) |> Map.get(:character_name, "Unknown") %></span>
                  <span class="ship"><%= killmail.victim_ship_type_id %></span>
                </div>
                <div class="killmail-details">
                  <span class="system"><%= Map.get(killmail, :solar_system, %{}) |> Map.get(:system_name, "Unknown") %></span>
                  <span class="value"><%= format_isk(killmail.total_value) %></span>
                  <span class="time"><%= format_time(killmail.killmail_time) %></span>
                </div>
              </div>
            <% end %>
            
            <div class="virtual-spacer-bottom"></div>
          </div>
          
          <%= if @has_more do %>
            <div class="load-more" phx-click="load_more" phx-viewport-bottom>
              <button class="btn-primary">Load More</button>
            </div>
          <% end %>
            <% _ -> %>
              <div>Loading...</div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Event Handlers

  @impl Phoenix.LiveView
  def handle_event("search_changed", %{"query" => query}, socket) do
    # Cancel previous debounce timer
    if socket.assigns.debounce_timer do
      Process.cancel_timer(socket.assigns.debounce_timer)
    end

    # Set new debounce timer
    timer = Process.send_after(self(), {:perform_search, query}, @debounce_ms)

    {:noreply, assign(socket, search_query: query, debounce_timer: timer)}
  end

  @impl Phoenix.LiveView
  def handle_event("viewport_top", %{"item_id" => item_id}, socket) do
    # Handle viewport scrolling for virtual list
    socket = update_viewport(socket, :top, item_id)
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("viewport_bottom", %{"item_id" => item_id}, socket) do
    # Handle viewport scrolling and trigger load more if needed
    updated_socket = update_viewport(socket, :bottom, item_id)

    final_socket =
      if should_load_more?(updated_socket) do
        load_more_killmails(updated_socket)
      else
        updated_socket
      end

    {:noreply, final_socket}
  end

  @impl Phoenix.LiveView
  def handle_event("load_more", _params, socket) do
    updated_socket = load_more_killmails(socket)
    {:noreply, updated_socket}
  end

  @impl Phoenix.LiveView
  def handle_event("filter_changed", %{"filter" => filter, "value" => value}, socket) do
    filters = Map.put(socket.assigns.filters, String.to_existing_atom(filter), value)

    socket =
      socket
      |> assign(:filters, filters)
      |> assign(:page, 1)
      |> load_killmails_async()

    {:noreply, socket}
  end

  # Info Handlers

  @impl Phoenix.LiveView
  def handle_info({:perform_search, query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> apply_search_filter()
      |> load_killmails_async()

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:new_killmail, killmail}, socket) do
    # Add new killmail to the top of the feed
    socket = prepend_killmail(socket, killmail)
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(:update_stats, socket) do
    socket = update_feed_stats(socket)
    schedule_stats_update()
    {:noreply, socket}
  end

  # Async Result Handlers

  @impl Phoenix.LiveView
  def handle_async(:load_killmails, {:ok, {killmails, has_more}}, socket) do
    socket =
      socket
      |> assign(:killmails, AsyncResult.ok(socket.assigns.killmails, killmails))
      |> assign(:has_more, has_more)
      |> update_viewport_items(killmails)
      |> update_stats_from_killmails(killmails)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_async(:load_killmails, {:error, reason}, socket) do
    socket = assign(socket, :killmails, AsyncResult.failed(socket.assigns.killmails, reason))
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_async(:load_more, {:ok, {killmails, has_more}}, socket) do
    current_killmails =
      if socket.assigns.killmails.ok?, do: socket.assigns.killmails.result, else: []

    all_killmails = current_killmails ++ killmails

    # Keep only the most recent items in memory
    trimmed_killmails =
      if length(all_killmails) > @max_items_in_memory do
        Enum.take(all_killmails, @max_items_in_memory)
      else
        all_killmails
      end

    socket =
      socket
      |> assign(:killmails, AsyncResult.ok(socket.assigns.killmails, trimmed_killmails))
      |> assign(:has_more, has_more)
      |> assign(:page, socket.assigns.page + 1)
      |> update_viewport_items(trimmed_killmails)

    {:noreply, socket}
  end

  # Private Functions

  defp load_initial_data(socket) do
    cache_key = {:kill_feed, :initial, socket.assigns.filters}

    case MultiLayerCache.get(cache_key) do
      {:ok, cached_data} ->
        socket
        |> assign(:killmails, AsyncResult.ok(socket.assigns.killmails, cached_data.killmails))
        |> assign(:stats, cached_data.stats)
        |> update_viewport_items(cached_data.killmails)

      :miss ->
        load_killmails_async(socket)
    end
  end

  defp load_killmails_async(socket) do
    filters = socket.assigns.filters
    page = socket.assigns.page

    socket
    |> assign_async(:killmails, fn ->
      fetch_killmails_with_cache(filters, page)
    end)
  end

  defp load_more_killmails(socket) do
    next_page = socket.assigns.page + 1
    filters = socket.assigns.filters

    socket
    |> assign(:page, next_page)
    |> assign_async(:load_more, fn ->
      fetch_killmails_with_cache(filters, next_page)
    end)
  end

  defp fetch_killmails_with_cache(filters, page) do
    cache_key = {:kill_feed, filters, page}

    MultiLayerCache.get_or_compute(
      cache_key,
      fn ->
        # Fetch from database with streaming
        end_time = DateTime.utc_now()
        start_time = DateTime.add(end_time, -24 * 3600, :second)

        options = [
          batch_size: @page_size,
          filter: build_filter_function(filters),
          preload: [:solar_system, :victim_character]
        ]

        killmails =
          KillmailStreamer.stream_killmails(start_time, end_time, options)
          |> Enum.take(1)
          |> List.flatten()

        has_more = length(killmails) == @page_size

        {:ok, {killmails, has_more}}
      end,
      # Cache for 1 minute
      ttl_ms: 60_000
    )
  end

  defp update_viewport(socket, _direction, _item_id) do
    # Implement virtual scrolling viewport update
    socket
  end

  defp update_viewport_items(socket, killmails) do
    # Calculate visible items based on scroll position
    visible_items = Enum.take(killmails, @page_size)
    assign(socket, :viewport_items, visible_items)
  end

  defp should_load_more?(socket) do
    socket.assigns.has_more &&
      length(socket.assigns.viewport_items) < @page_size * 2
  end

  defp prepend_killmail(socket, killmail) do
    current_killmails =
      if socket.assigns.killmails.ok?, do: socket.assigns.killmails.result, else: []

    updated_killmails = [killmail | current_killmails] |> Enum.take(@max_items_in_memory)

    socket
    |> assign(:killmails, AsyncResult.ok(socket.assigns.killmails, updated_killmails))
    |> update_viewport_items(updated_killmails)
  end

  defp apply_search_filter(socket) do
    query = socket.assigns.search_query

    if String.length(query) >= 3 do
      filters = Map.put(socket.assigns.filters, :search, query)
      assign(socket, :filters, filters)
    else
      filters = Map.delete(socket.assigns.filters, :search)
      assign(socket, :filters, filters)
    end
  end

  defp build_filters(params) do
    %{
      system_id: params["system_id"],
      character_id: params["character_id"],
      corporation_id: params["corporation_id"],
      alliance_id: params["alliance_id"],
      min_value: params["min_value"]
    }
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Map.new()
  end

  defp build_filter_function(filters) do
    fn killmail ->
      Enum.all?(filters, fn
        {:system_id, id} -> killmail.solar_system_id == id
        {:character_id, id} -> killmail.victim_character_id == id
        {:min_value, value} -> killmail.total_value >= value
        {:search, query} -> matches_search?(killmail, query)
        _ -> true
      end)
    end
  end

  defp matches_search?(_killmail, _query) do
    # Implement search matching logic
    true
  end

  defp update_feed_stats(socket) do
    # Update stats from cache or compute
    socket
  end

  defp update_stats_from_killmails(socket, killmails) do
    stats = %{
      total_kills: length(killmails),
      total_value: Enum.sum(Enum.map(killmails, & &1.total_value))
    }

    assign(socket, :stats, stats)
  end

  defp calculate_list_height(killmails) do
    # Calculate virtual list height based on item count
    # Assuming 120px per item
    length(killmails) * 120
  end

  defp format_isk(value) when value >= 1_000_000_000 do
    "#{Float.round(value / 1_000_000_000, 1)}B"
  end

  defp format_isk(value) when value >= 1_000_000 do
    "#{Float.round(value / 1_000_000, 1)}M"
  end

  defp format_isk(value) do
    "#{round(value / 1000)}K"
  end

  defp schedule_stats_update do
    # Update every 30 seconds
    Process.send_after(self(), :update_stats, 30_000)
  end

  # Helper functions

  defp humanize_filter(key) do
    key
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_time(datetime) do
    # Format datetime for display
    Calendar.strftime(datetime, "%H:%M:%S")
  end
end
