defmodule EveDmvWeb.LiveHelpers.LiveViewPatternTemplate do
  @moduledoc """
  Common LiveView pattern matching templates and helpers for fixing Dialyzer issues.

  This module provides standard patterns and helper functions to ensure consistent
  error handling and pattern matching across all LiveView modules.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  @doc """
  Standard mount callback pattern that handles both authenticated and unauthenticated states.

  ## Example Usage

      def mount(params, session, socket) do
        case socket.assigns[:current_user] do
          nil ->
            {:ok, redirect(socket, to: Routes.auth_path(socket, :login))}

          user ->
            socket =
              socket
              |> assign(:user, user)
              |> initialize_assigns()
              |> subscribe_to_pubsub()

            {:ok, socket}
        end
      end
  """
  def mount_template do
    :ok
  end

  @doc """
  Standard handle_event pattern with comprehensive error handling.

  ## Pattern for API calls that may fail

      def handle_event("action", params, socket) do
        case perform_action(params) do
          {:ok, result} ->
            socket =
              socket
              |> assign(:result, result)
              |> put_flash(:info, "Action successful")

            {:noreply, socket}

          {:error, reason} ->
            socket = put_flash(socket, :error, format_error(reason))
            {:noreply, socket}
        end
      end
  """
  def handle_event_template do
    :ok
  end

  @doc """
  Pattern for async operations with proper error handling.

  ## Example for async data loading

      def handle_info({:load_data, ref}, socket) when socket.assigns.loading_ref == ref do
        case fetch_data() do
          {:ok, data} ->
            socket =
              socket
              |> assign(:data, data)
              |> assign(:loading, false)
              |> assign(:error, nil)

            {:noreply, socket}

          {:error, reason} ->
            socket =
              socket
              |> assign(:loading, false)
              |> assign(:error, reason)
              |> put_flash(:error, "Failed to load data")

            {:noreply, socket}
        end
      end
  """
  def handle_info_template do
    :ok
  end

  @doc """
  Safe pattern matching for API responses with fallback.

  This helper ensures that pattern matches won't fail on unexpected responses.
  """
  def safe_api_call(socket, api_function, success_handler) do
    case api_function.() do
      {:ok, result} ->
        success_handler.(socket, result)

      {:error, reason} ->
        handle_api_error(socket, reason)

      unexpected ->
        # Log unexpected response for debugging
        require Logger
        Logger.warning("Unexpected API response: #{inspect(unexpected)}")
        handle_api_error(socket, :unexpected_response)
    end
  end

  @doc """
  Standard error handling for API responses.
  """
  def handle_api_error(socket, reason) do
    error_message = format_error(reason)
    put_flash(socket, :error, error_message)
  end

  @doc """
  Format error reasons into user-friendly messages.
  """
  def format_error(reason) do
    case reason do
      :not_found ->
        "Resource not found"

      :unauthorized ->
        "You don't have permission to perform this action"

      :timeout ->
        "Request timed out. Please try again"

      :battle_not_found ->
        "Battle not found"

      :not_implemented ->
        "This feature is not yet implemented"

      :curator_unavailable ->
        "Battle curator service is unavailable"

      :battle_data_unavailable ->
        "Battle data is currently unavailable"

      {:error, msg} when is_binary(msg) ->
        msg

      error when is_atom(error) ->
        error
        |> Atom.to_string()
        |> String.replace("_", " ")
        |> String.capitalize()

      _ ->
        "An unexpected error occurred"
    end
  end

  @doc """
  Safe assign pattern that handles nil values.
  """
  def safe_assign(socket, key, value, default \\ nil) do
    case value do
      nil -> assign(socket, key, default)
      val -> assign(socket, key, val)
    end
  end

  @doc """
  Pattern for handling potentially nil current_user.
  """
  def with_authenticated_user(socket, callback) do
    case socket.assigns[:current_user] do
      nil ->
        socket
        |> put_flash(:error, "You must be logged in to perform this action")
        |> redirect(to: "/auth/login")

      user ->
        callback.(socket, user)
    end
  end

  @doc """
  Safe pattern for updating nested assigns.
  """
  def update_nested_assign(socket, path, value) when is_list(path) do
    current = get_in(socket.assigns, path) || %{}

    case value do
      %{} = map when map_size(map) > 0 ->
        updated = Map.merge(current, map)
        put_in(socket.assigns, path, updated)

      _ ->
        socket
    end
  end

  @doc """
  Pattern for handling list operations that may return empty lists.
  """
  def handle_list_operation(socket, operation, assign_key) do
    case operation.() do
      {:ok, []} ->
        assign(socket, assign_key, [])

      {:ok, items} when is_list(items) ->
        assign(socket, assign_key, items)

      {:error, reason} ->
        socket
        |> assign(assign_key, [])
        |> handle_api_error(reason)

      _ ->
        assign(socket, assign_key, [])
    end
  end

  @doc """
  Standard pattern for handling PubSub messages.
  """
  def handle_pubsub_message(socket, message, handler) do
    case message do
      {topic, payload} when is_binary(topic) and is_map(payload) ->
        handler.(socket, topic, payload)

      _ ->
        # Ignore malformed messages
        socket
    end
  end

  @doc """
  Pattern for safe battle analysis operations.
  """
  def with_battle_data(socket, battle_id, callback) do
    case EveDmv.Contexts.BattleAnalysis.get_battle_with_timeline(battle_id) do
      {:ok, battle} ->
        callback.(socket, battle)

      {:error, :battle_not_found} ->
        socket
        |> put_flash(:error, "Battle not found")
        |> push_navigate(to: "/battles")

      {:error, reason} ->
        handle_api_error(socket, reason)
    end
  end

  @doc """
  Common assigns initialization pattern.
  """
  def initialize_common_assigns(socket, user) do
    socket
    |> assign(:current_user, user)
    |> assign(:loading, false)
    |> assign(:error, nil)
    |> assign(:page_title, "EVE DMV")
  end

  @doc """
  Safe pattern for form changeset handling.
  """
  def handle_form_change(socket, params, changeset_fn) do
    changeset = changeset_fn.(params)

    socket
    |> assign(:changeset, changeset)
    |> assign(:form_errors, format_changeset_errors(changeset))
  end

  defp format_changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp format_changeset_errors(_), do: %{}
end
