defmodule EveDmvWeb.Components.ErrorRecoveryComponent do
  @moduledoc """
  Reusable error recovery component for LiveView pages.

  Provides consistent error display and recovery options across the application.
  """

  use Phoenix.Component

  @doc """
  Renders an error state with recovery options.

  ## Examples

      <.error_recovery
        error_state={@error_state}
        retry_event="retry_operation"
        show_details={false}
      />
  """
  attr(:error_state, :map, default: nil)
  attr(:retry_event, :string, default: "retry_operation")
  attr(:clear_event, :string, default: "clear_error")
  attr(:refresh_event, :string, default: "refresh_page")
  attr(:show_details, :boolean, default: false)
  attr(:class, :string, default: "")

  def error_recovery(assigns) do
    ~H"""
    <%= if @error_state do %>
      <div class={["bg-red-900/20 border border-red-700 rounded-lg p-6 mb-6", @class]}>
        <div class="flex items-start">
          <!-- Error Icon -->
          <div class="flex-shrink-0">
            <svg class="w-6 h-6 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.728-.833-2.498 0L4.316 16.5c-.77.833.192 2.5 1.732 2.5z" />
            </svg>
          </div>
          
          <!-- Error Content -->
          <div class="ml-4 flex-1">
            <h3 class="text-lg font-medium text-red-400 mb-2">
              Something went wrong
            </h3>
            <%= if Map.get(@error_state, :message) do %>
              <p class="text-red-300 mb-4">
                <%= @error_state.message %>
              </p>
            <% end %>
            
            <%= if @show_details && Map.get(@error_state, :details) do %>
              <details class="mb-4">
                <summary class="cursor-pointer text-red-300 hover:text-red-200 transition-colors">
                  Technical details
                </summary>
                <pre class="mt-2 text-sm text-red-200 bg-red-950/50 p-3 rounded overflow-x-auto">
                  <%= @error_state.details %>
                </pre>
              </details>
            <% end %>
            
            <!-- Recovery Actions -->
            <div class="flex items-center gap-4">
              <%= if @error_state[:recoverable] do %>
                <button
                  phx-click={@retry_event}
                  phx-value-operation={@error_state[:operation]}
                  class="inline-flex items-center px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg transition-colors duration-200"
                >
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                  </svg>
                  Try Again
                </button>
              <% end %>
              
              <button
                phx-click={@clear_event}
                class="inline-flex items-center px-4 py-2 bg-gray-600 hover:bg-gray-700 text-white rounded-lg transition-colors duration-200"
              >
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
                Dismiss
              </button>
              
              <button
                phx-click={@refresh_event}
                class="inline-flex items-center px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors duration-200"
              >
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
                Refresh Page
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders a compact error message for inline errors.

  ## Examples

      <.inline_error message="Invalid character ID" />
  """
  attr(:message, :string, required: true)
  attr(:class, :string, default: "")

  def inline_error(assigns) do
    ~H"""
    <div class={["flex items-center text-red-400 text-sm mt-1", @class]}>
      <svg class="w-4 h-4 mr-1 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      <%= @message %>
    </div>
    """
  end

  @doc """
  Renders a network error state with specific messaging.

  ## Examples

      <.network_error retry_event="retry_connection" />
  """
  attr(:retry_event, :string, default: "retry_connection")
  attr(:class, :string, default: "")

  def network_error(assigns) do
    ~H"""
    <div class={["bg-yellow-900/20 border border-yellow-700 rounded-lg p-6 text-center", @class]}>
      <div class="flex flex-col items-center">
        <svg class="w-12 h-12 text-yellow-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.728-.833-2.498 0L4.316 16.5c-.77.833.192 2.5 1.732 2.5z" />
        </svg>
        <h3 class="text-lg font-medium text-yellow-400 mb-2">
          Connection Problem
        </h3>
        <p class="text-yellow-300 mb-4">
          Unable to connect to the server. Please check your internet connection and try again.
        </p>
        <button
          phx-click={@retry_event}
          class="inline-flex items-center px-4 py-2 bg-yellow-600 hover:bg-yellow-700 text-white rounded-lg transition-colors duration-200"
        >
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          Try Again
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a timeout error state.

  ## Examples

      <.timeout_error operation="load character data" retry_event="retry_load" />
  """
  attr(:operation, :string, required: true)
  attr(:retry_event, :string, default: "retry_operation")
  attr(:class, :string, default: "")

  def timeout_error(assigns) do
    ~H"""
    <div class={["bg-orange-900/20 border border-orange-700 rounded-lg p-6 text-center", @class]}>
      <div class="flex flex-col items-center">
        <svg class="w-12 h-12 text-orange-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <h3 class="text-lg font-medium text-orange-400 mb-2">
          Request Timeout
        </h3>
        <p class="text-orange-300 mb-4">
          The operation to <%= @operation %> took too long to complete. This might be due to high server load.
        </p>
        <button
          phx-click={@retry_event}
          class="inline-flex items-center px-4 py-2 bg-orange-600 hover:bg-orange-700 text-white rounded-lg transition-colors duration-200"
        >
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          Try Again
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a permission denied error state.

  ## Examples

      <.permission_error />
  """
  attr(:class, :string, default: "")

  def permission_error(assigns) do
    ~H"""
    <div class={["bg-red-900/20 border border-red-700 rounded-lg p-6 text-center", @class]}>
      <div class="flex flex-col items-center">
        <svg class="w-12 h-12 text-red-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-1.17 10.47L12 15" />
        </svg>
        <h3 class="text-lg font-medium text-red-400 mb-2">
          Access Denied
        </h3>
        <p class="text-red-300 mb-4">
          You don't have permission to access this resource. Please contact your administrator if you believe this is an error.
        </p>
        <button
          phx-click="navigate_back"
          class="inline-flex items-center px-4 py-2 bg-gray-600 hover:bg-gray-700 text-white rounded-lg transition-colors duration-200"
        >
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
          </svg>
          Go Back
        </button>
      </div>
    </div>
    """
  end
end
