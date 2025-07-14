defmodule EveDmvWeb.AuthLive do
  @moduledoc """
  Authentication LiveView modules for handling user sign-in flows.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias EveDmv.Security.AuditLogger

  def on_mount(:load_from_session, _params, session, socket) do
    socket = assign_current_user(socket, session)
    {:cont, socket}
  end

  def on_mount(:load_from_session_optional, _params, session, socket) do
    socket = assign_current_user_optional(socket, session)
    {:cont, socket}
  end

  defp assign_current_user(socket, session) do
    require Logger

    # Check session timeout first
    case check_session_timeout(session) do
      :timeout ->
        Logger.debug("Session timeout detected")
        socket = assign(socket, current_user: nil)
        Process.send_after(self(), :session_timeout, 100)
        socket

      :valid ->
        # Get current user from session using user ID
        case Map.get(session, "current_user_id") do
          nil ->
            Logger.debug("No current_user_id in session")
            assign(socket, current_user: nil)

          user_id ->
            Logger.debug("Loading user from database: #{user_id}")
            # Load user by ID from database
            case Ash.get(EveDmv.Users.User, user_id, domain: EveDmv.Api) do
              {:ok, user} ->
                Logger.debug("User loaded successfully: #{user.eve_character_name}")
                assign(socket, current_user: user)

              {:error, %Ash.Error.Query.NotFound{}} ->
                Logger.warning(
                  "User #{user_id} not found in database - invalid session, clearing session"
                )

                # Clear the invalid session by not scheduling any timeout
                assign(socket, current_user: nil)

              {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} ->
                Logger.warning(
                  "User #{user_id} not found in database - invalid session (wrapped), clearing session"
                )

                # Clear the invalid session by not scheduling any timeout
                assign(socket, current_user: nil)

              {:error, reason} ->
                Logger.warning("Failed to load user #{user_id}: #{inspect(reason)}")
                assign(socket, current_user: nil)
            end
        end
    end
  end

  defp assign_current_user_optional(socket, session) do
    require Logger

    # Check session timeout first
    case check_session_timeout(session) do
      :timeout ->
        Logger.debug("Session timeout detected (optional)")
        assign(socket, current_user: nil)

      :valid ->
        # Get current user from session using user ID
        case Map.get(session, "current_user_id") do
          nil ->
            Logger.debug("No current_user_id in session (optional)")
            assign(socket, current_user: nil)

          user_id ->
            Logger.debug("Loading user from database (optional): #{user_id}")
            # Load user by ID from database
            case Ash.get(EveDmv.Users.User, user_id, domain: EveDmv.Api) do
              {:ok, user} ->
                Logger.debug("User loaded successfully (optional): #{user.eve_character_name}")
                assign(socket, current_user: user)

              _error ->
                Logger.debug("Failed to load user (optional), continuing without auth")
                assign(socket, current_user: nil)
            end
        end
    end
  end

  # Check if the session has timed out based on last activity.
  defp check_session_timeout(session) do
    session_timeout = Application.get_env(:eve_dmv, :session_timeout_hours, 24) * 60 * 60 * 1000

    case Map.get(session, "last_activity") do
      nil ->
        # No last activity timestamp, consider valid for now
        :valid

      last_activity when is_integer(last_activity) ->
        current_time = System.system_time(:millisecond)

        if current_time - last_activity > session_timeout do
          :timeout
        else
          :valid
        end

      _ ->
        # Invalid timestamp format, consider timed out
        :timeout
    end
  end

  defmodule SignIn do
    @moduledoc """
    LiveView for the sign-in page with EVE SSO authentication.
    """
    use EveDmvWeb, :live_view

    on_mount({EveDmvWeb.AuthLive, :load_from_session})

    @impl Phoenix.LiveView
    def mount(_params, session, socket) do
      # If user is already authenticated, redirect to dashboard
      if socket.assigns[:current_user] do
        {:ok, redirect(socket, to: ~p"/dashboard")}
      else
        # Check if we have an invalid session (user ID exists but user doesn't)
        if Map.get(session, "current_user_id") && !socket.assigns[:current_user] do
          # Invalid session - redirect to clear it
          require Logger
          Logger.warning("Invalid session detected in SignIn, redirecting to clear session")
          {:ok, redirect(socket, to: ~p"/session/clear")}
        else
          {:ok, assign(socket, :page_title, "Sign In")}
        end
      end
    end

    @impl Phoenix.LiveView
    def handle_info(:session_timeout, socket) do
      # Log session timeout event
      case socket.assigns[:current_user] do
        %{id: character_id} ->
          session_timeout_hours = Application.get_env(:eve_dmv, :session_timeout_hours, 24)
          AuditLogger.log_session_timeout(character_id, session_timeout_hours * 3600)

        _ ->
          :ok
      end

      {:noreply,
       socket
       |> put_flash(:error, "Your session has expired. Please sign in again.")
       |> push_navigate(to: ~p"/login")}
    end

    @impl Phoenix.LiveView
    def render(assigns) do
      ~H"""
      <div class="min-h-screen flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
        <div class="max-w-md w-full space-y-8">
          <div class="text-center">
            <div class="mx-auto h-12 w-12 bg-red-600 rounded-full flex items-center justify-center mb-6">
              <svg class="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 20 20">
                <path
                  fill-rule="evenodd"
                  d="M10 2L3 7v10l7 5 7-5V7l-7-5zM8 8h4v4H8V8z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <h2 class="text-center text-3xl font-extrabold text-white">
              Sign in to EVE PvP Tracker
            </h2>
            <p class="mt-2 text-center text-sm text-gray-400">
              Authenticate with your EVE Online character
            </p>
          </div>

          <div class="mt-8 space-y-4">
            <a
              href="/auth/user/eve_sso"
              class="group relative w-full flex justify-center py-3 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors duration-200"
            >
              <span class="absolute left-0 inset-y-0 flex items-center pl-3">
                <!-- EVE Online icon -->
                <svg
                  class="h-5 w-5 text-indigo-500 group-hover:text-indigo-400"
                  fill="currentColor"
                  viewBox="0 0 20 20"
                >
                  <path
                    fill-rule="evenodd"
                    d="M10 2L3 7v10l7 5 7-5V7l-7-5zM8 8h4v4H8V8z"
                    clip-rule="evenodd"
                  />
                </svg>
              </span>
              Log in with EVE Online
            </a>

            <div class="text-center">
              <a href="/" class="text-indigo-400 hover:text-indigo-300 text-sm">
                ← Back to Home
              </a>
            </div>
          </div>

      <!-- Development Info -->
          <div class="mt-8 bg-blue-900 border border-blue-700 rounded-lg p-4">
            <h3 class="text-sm font-medium text-blue-200 mb-2">🚧 Development Status</h3>
            <p class="text-blue-300 text-xs">
              EVE SSO authentication is configured with AshAuthentication.
              Click the button above to start the OAuth2 flow with CCP's servers.
            </p>
          </div>
        </div>
      </div>
      """
    end
  end
end
