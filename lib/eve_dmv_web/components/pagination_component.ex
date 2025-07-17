defmodule EveDmvWeb.Components.PaginationComponent do
  @moduledoc """
  Sprint 15A: Reusable pagination component for cursor-based pagination.

  Provides navigation controls for large datasets with proper accessibility
  and performance considerations.
  """

  use Phoenix.Component

  @doc """
  Renders pagination controls for cursor-based pagination.

  ## Attributes
  - `has_next_page` (boolean) - Whether there's a next page
  - `has_previous_page` (boolean) - Whether there's a previous page
  - `next_cursor` (string) - Cursor for next page
  - `prev_cursor` (string) - Cursor for previous page
  - `page_size` (integer) - Current page size
  - `total_count` (integer, optional) - Total count if available
  - `target` (atom) - LiveView target for pagination events
  - `event_prefix` (string) - Prefix for pagination events (default: "paginate")
  """
  attr(:has_next_page, :boolean, default: false)
  attr(:has_previous_page, :boolean, default: false)
  attr(:next_cursor, :string, default: nil)
  attr(:prev_cursor, :string, default: nil)
  attr(:page_size, :integer, default: 50)
  attr(:total_count, :integer, default: nil)
  attr(:target, :any, default: nil)
  attr(:event_prefix, :string, default: "paginate")
  attr(:class, :string, default: "")

  def pagination(assigns) do
    ~H"""
    <div class={"pagination-wrapper " <> @class}>
      <div class="pagination-controls">
        <!-- Previous page button -->
        <button
          :if={@has_previous_page}
          phx-click={"#{@event_prefix}_prev"}
          phx-value-cursor={@prev_cursor}
          phx-target={@target}
          class="pagination-btn pagination-prev"
          aria-label="Previous page"
        >
          <svg class="pagination-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path>
          </svg>
          Previous
        </button>
        
        <button
          :if={!@has_previous_page}
          class="pagination-btn pagination-prev pagination-disabled"
          disabled
          aria-label="Previous page (disabled)"
        >
          <svg class="pagination-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path>
          </svg>
          Previous
        </button>
        
        <!-- Page info -->
        <div class="pagination-info">
          <span class="pagination-text">
            Showing <%= @page_size %> items
            <%= if @total_count do %>
              of <%= format_number(@total_count) %> total
            <% end %>
          </span>
        </div>
        
        <!-- Next page button -->
        <button
          :if={@has_next_page}
          phx-click={"#{@event_prefix}_next"}
          phx-value-cursor={@next_cursor}
          phx-target={@target}
          class="pagination-btn pagination-next"
          aria-label="Next page"
        >
          Next
          <svg class="pagination-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
          </svg>
        </button>
        
        <button
          :if={!@has_next_page}
          class="pagination-btn pagination-next pagination-disabled"
          disabled
          aria-label="Next page (disabled)"
        >
          Next
          <svg class="pagination-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
          </svg>
        </button>
      </div>
      
      <!-- Page size selector -->
      <div class="pagination-size-selector">
        <label for="page-size-select" class="sr-only">Items per page</label>
        <select
          id="page-size-select"
          phx-change={"#{@event_prefix}_size"}
          phx-target={@target}
          class="pagination-size-select"
        >
          <option value="25" selected={@page_size == 25}>25 per page</option>
          <option value="50" selected={@page_size == 50}>50 per page</option>
          <option value="100" selected={@page_size == 100}>100 per page</option>
          <option value="250" selected={@page_size == 250}>250 per page</option>
        </select>
      </div>
    </div>
    """
  end

  @doc """
  Renders a simple pagination indicator showing current status.
  """
  attr(:has_more, :boolean, default: false)
  attr(:current_count, :integer, required: true)
  attr(:total_count, :integer, default: nil)
  attr(:loading, :boolean, default: false)

  def pagination_status(assigns) do
    ~H"""
    <div class="pagination-status">
      <%= if @loading do %>
        <div class="pagination-loading">
          <div class="spinner"></div>
          Loading...
        </div>
      <% else %>
        <div class="pagination-count">
          Showing <%= format_number(@current_count) %> items
          <%= if @total_count do %>
            of <%= format_number(@total_count) %> total
          <% end %>
          <%= if @has_more do %>
            <span class="pagination-more">(more available)</span>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders an infinite scroll trigger for seamless pagination.
  """
  attr(:target, :any, default: nil)
  attr(:event, :string, default: "load_more")
  attr(:cursor, :string, default: nil)
  attr(:has_more, :boolean, default: false)
  attr(:loading, :boolean, default: false)

  def infinite_scroll_trigger(assigns) do
    ~H"""
    <div
      :if={@has_more and !@loading}
      id="infinite-scroll-trigger"
      class="infinite-scroll-trigger"
      phx-hook="InfiniteScroll"
      phx-click={@event}
      phx-value-cursor={@cursor}
      phx-target={@target}
      data-threshold="200"
    >
      <button class="load-more-btn">
        Load More
      </button>
    </div>

    <div :if={@loading} class="infinite-scroll-loading">
      <div class="spinner"></div>
      Loading more items...
    </div>
    """
  end

  # Helper functions

  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp format_number(number) when is_nil(number), do: "0"
  defp format_number(number), do: to_string(number)
end
