defmodule EveDmvWeb.Components.HistoricalFetchIndicator do
  @moduledoc """
  Component that displays the historical data fetch status.

  Shows a discrete indicator with the following states:
  - Not started (loading spinner)
  - Phase 1 complete / queued (clock icon)
  - Phase 2 in progress (progress bar with kill count)
  - Completed (checkmark with total count)
  - Failed (error with retry option)

  Used on character, corporation, system, and alliance profile pages
  to show the status of 2-year historical killmail fetching.
  """

  use Phoenix.Component

  @doc """
  Renders the historical fetch status indicator.

  ## Attributes

    * `status` - The fetch status map from HistoricalFetchStatus resource, or nil
    * `entity_type` - Atom: :character, :corporation, :system, or :alliance
    * `entity_id` - Integer ID of the entity
    * `class` - Additional CSS classes

  ## Examples

      <.historical_fetch_indicator
        status={@historical_fetch_status}
        entity_type={:character}
        entity_id={@character_id}
      />
  """
  attr(:status, :map, default: nil)
  attr(:entity_type, :atom, required: true)
  attr(:entity_id, :integer, required: true)
  attr(:class, :string, default: "")

  def historical_fetch_indicator(assigns) do
    ~H"""
    <div class={"historical-fetch-indicator #{@class}"}>
      <%= render_indicator(@status, @entity_type, @entity_id) %>
    </div>
    """
  end

  defp render_indicator(nil, _entity_type, _entity_id) do
    assigns = %{}

    ~H"""
    <.indicator_loading text="Loading recent data..." />
    """
  end

  defp render_indicator(%{status: :pending}, _entity_type, _entity_id) do
    assigns = %{}

    ~H"""
    <.indicator_loading text="Loading recent data..." />
    """
  end

  defp render_indicator(%{status: :phase1_complete}, _entity_type, _entity_id) do
    assigns = %{}

    ~H"""
    <.indicator_queued />
    """
  end

  defp render_indicator(%{status: :in_progress} = status, _entity_type, _entity_id) do
    progress = calculate_progress(status)
    killmails = status[:killmails_fetched] || 0
    assigns = %{progress: progress, killmails: killmails}

    ~H"""
    <.indicator_progress progress={@progress} killmails={@killmails} />
    """
  end

  defp render_indicator(%{status: :completed} = status, _entity_type, _entity_id) do
    killmails = status[:killmails_fetched] || 0
    assigns = %{killmails: killmails}

    ~H"""
    <.indicator_complete killmails={@killmails} />
    """
  end

  defp render_indicator(%{status: :failed}, entity_type, entity_id) do
    assigns = %{entity_type: entity_type, entity_id: entity_id}

    ~H"""
    <.indicator_failed entity_type={@entity_type} entity_id={@entity_id} />
    """
  end

  defp render_indicator(_status, _entity_type, _entity_id) do
    assigns = %{}

    ~H"""
    <.indicator_loading text="Loading recent data..." />
    """
  end

  # Private component helpers

  attr(:text, :string, required: true)

  defp indicator_loading(assigns) do
    ~H"""
    <div class="flex items-center gap-2 text-sm text-gray-400">
      <svg
        class="animate-spin h-4 w-4"
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
      >
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
        </circle>
        <path
          class="opacity-75"
          fill="currentColor"
          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
        >
        </path>
      </svg>
      <span><%= @text %></span>
    </div>
    """
  end

  defp indicator_queued(assigns) do
    ~H"""
    <div
      class="flex items-center gap-2 text-sm text-blue-400"
      title="Historical data will be loaded in the background"
    >
      <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
        />
      </svg>
      <span>2-year history queued</span>
    </div>
    """
  end

  attr(:progress, :integer, required: true)
  attr(:killmails, :integer, required: true)

  defp indicator_progress(assigns) do
    ~H"""
    <div class="flex flex-col gap-1">
      <div class="flex items-center gap-2 text-sm text-yellow-400">
        <svg
          class="animate-spin h-4 w-4"
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
        >
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
          </circle>
          <path
            class="opacity-75"
            fill="currentColor"
            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
          >
          </path>
        </svg>
        <span>Loading 2-year history...</span>
        <span class="text-gray-500"><%= @killmails %> kills</span>
      </div>
      <div class="w-full bg-gray-700 rounded-full h-1.5">
        <div
          class="bg-yellow-400 h-1.5 rounded-full transition-all duration-500"
          style={"width: #{@progress}%"}
        >
        </div>
      </div>
    </div>
    """
  end

  attr(:killmails, :integer, required: true)

  defp indicator_complete(assigns) do
    ~H"""
    <div
      class="flex items-center gap-2 text-sm text-green-400"
      title={"2-year history loaded: #{@killmails} killmails"}
    >
      <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
      </svg>
      <span>2-year history complete</span>
      <span class="text-gray-500">(<%= @killmails %> kills)</span>
    </div>
    """
  end

  attr(:entity_type, :atom, required: true)
  attr(:entity_id, :integer, required: true)

  defp indicator_failed(assigns) do
    ~H"""
    <div class="flex items-center gap-2 text-sm text-red-400">
      <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
        />
      </svg>
      <span>History load failed</span>
      <button
        phx-click="retry_historical_fetch"
        phx-value-entity_type={@entity_type}
        phx-value-entity_id={@entity_id}
        class="text-blue-400 hover:text-blue-300 underline"
      >
        Retry
      </button>
    </div>
    """
  end

  # Progress calculation

  defp calculate_progress(status) do
    cond do
      status[:status] == :completed ->
        100

      status[:oldest_killmail_date] && status[:target_date] ->
        today = Date.utc_today()
        total_days = Date.diff(today, status.target_date)
        fetched_days = Date.diff(today, status.oldest_killmail_date)
        min(100, round(fetched_days / max(total_days, 1) * 100))

      true ->
        # Phase 1 is approximately 10% of 2 years (90/730 days)
        10
    end
  end
end
