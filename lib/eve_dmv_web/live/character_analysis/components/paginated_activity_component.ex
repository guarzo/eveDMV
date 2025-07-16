defmodule EveDmvWeb.CharacterAnalysis.Components.PaginatedActivityComponent do
  @moduledoc """
  LiveComponent for displaying paginated character activity.
  """

  use EveDmvWeb, :live_component

  alias EveDmv.Database.CharacterQueries
  alias EveDmvWeb.CharacterAnalysis.Helpers.DisplayFormatters

  @impl true
  def mount(socket) do
    {:ok, assign(socket, page: 1, page_size: 20, loading: false)}
  end

  @impl true
  def update(%{character_id: _character_id} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> load_activity()

    {:ok, socket}
  end

  @impl true
  def handle_event("change_page", %{"page" => page}, socket) do
    page = String.to_integer(page)

    socket =
      socket
      |> assign(page: page)
      |> load_activity()

    {:noreply, socket}
  end

  @impl true
  def handle_event("prev_page", _, socket) do
    if socket.assigns.page > 1 do
      socket =
        socket
        |> assign(page: socket.assigns.page - 1)
        |> load_activity()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("next_page", _, socket) do
    if socket.assigns.pagination && socket.assigns.pagination.has_next do
      socket =
        socket
        |> assign(page: socket.assigns.page + 1)
        |> load_activity()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp load_activity(socket) do
    character_id = socket.assigns.character_id
    page = socket.assigns.page
    page_size = socket.assigns.page_size

    result =
      CharacterQueries.get_recent_activity(
        character_id,
        page: page,
        page_size: page_size
      )

    socket
    |> assign(:activity, result.data)
    |> assign(:pagination, result.pagination)
    |> assign(:loading, false)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg p-6">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-semibold text-white">Recent Activity</h3>
        <div class="text-sm text-gray-400">
          <%= if @pagination do %>
            Showing <%= (@pagination.page - 1) * @pagination.page_size + 1 %> - 
            <%= min(@pagination.page * @pagination.page_size, @pagination.total_count) %> 
            of <%= @pagination.total_count %>
          <% end %>
        </div>
      </div>
      
      <%= if @loading do %>
        <div class="flex justify-center py-8">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-400"></div>
        </div>
      <% else %>
        <div class="space-y-2 mb-4">
          <%= for activity <- @activity || [] do %>
            <div class={"rounded p-3 flex items-center justify-between #{activity_bg_class(activity.involvement_type)}"}>
              <div class="flex-1">
                <div class="flex items-center gap-2">
                  <span class={"text-sm font-medium #{activity_text_class(activity.involvement_type)}"}>
                    <%= String.upcase(activity.involvement_type) %>
                  </span>
                  <span class="text-gray-400 text-sm">
                    <%= format_time_ago(activity.killmail_time) %>
                  </span>
                </div>
                <div class="text-xs text-gray-500 mt-1">
                  Ship Type ID: <%= activity.ship_type_id %> • 
                  System ID: <%= activity.solar_system_id %> •
                  Value: <%= format_isk(activity.total_value) %>
                </div>
              </div>
              <a 
                href={"/killmail/#{activity.killmail_id}"}
                class="text-blue-400 hover:text-blue-300 text-sm"
                target="_blank"
              >
                View →
              </a>
            </div>
          <% end %>
          
          <%= if @activity == [] do %>
            <p class="text-gray-500 text-center py-4">No activity found</p>
          <% end %>
        </div>
        
        <!-- Pagination Controls -->
        <%= if @pagination && @pagination.total_pages > 1 do %>
          <div class="flex items-center justify-between pt-4 border-t border-gray-700">
            <button
              phx-click="prev_page"
              phx-target={@myself}
              disabled={@pagination.page <= 1}
              class={"px-3 py-1 rounded text-sm #{if @pagination.page <= 1, do: "bg-gray-700 text-gray-500 cursor-not-allowed", else: "bg-gray-700 hover:bg-gray-600 text-white"}"}
            >
              ← Previous
            </button>
            
            <div class="flex items-center gap-2">
              <%= for page_num <- visible_page_numbers(@pagination) do %>
                <%= if page_num == "..." do %>
                  <span class="text-gray-500">...</span>
                <% else %>
                  <button
                    phx-click="change_page"
                    phx-value-page={page_num}
                    phx-target={@myself}
                    class={"px-3 py-1 rounded text-sm #{if page_num == @pagination.page, do: "bg-blue-600 text-white", else: "bg-gray-700 hover:bg-gray-600 text-white"}"}
                  >
                    <%= page_num %>
                  </button>
                <% end %>
              <% end %>
            </div>
            
            <button
              phx-click="next_page"
              phx-target={@myself}
              disabled={!@pagination.has_next}
              class={"px-3 py-1 rounded text-sm #{if !@pagination.has_next, do: "bg-gray-700 text-gray-500 cursor-not-allowed", else: "bg-gray-700 hover:bg-gray-600 text-white"}"}
            >
              Next →
            </button>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  # Helper functions

  defp activity_bg_class("kill"), do: "bg-green-900/20 border border-green-800/30"
  defp activity_bg_class("loss"), do: "bg-red-900/20 border border-red-800/30"
  defp activity_bg_class(_), do: "bg-gray-700"

  defp activity_text_class("kill"), do: "text-green-400"
  defp activity_text_class("loss"), do: "text-red-400"
  defp activity_text_class(_), do: "text-gray-400"

  defp visible_page_numbers(pagination) do
    current = pagination.page
    total = pagination.total_pages

    cond do
      total <= 7 ->
        1..total |> Enum.to_list()

      current <= 4 ->
        [1, 2, 3, 4, 5, "...", total]

      current >= total - 3 ->
        [1, "...", total - 4, total - 3, total - 2, total - 1, total]

      true ->
        [1, "...", current - 1, current, current + 1, "...", total]
    end
  end

  defp format_time_ago(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end

  defdelegate format_isk(value), to: DisplayFormatters
end
