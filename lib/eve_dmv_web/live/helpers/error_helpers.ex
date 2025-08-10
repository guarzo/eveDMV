defmodule EveDmvWeb.Live.Helpers.ErrorHelpers do
  @moduledoc """
  Simple error handling helpers for LiveViews.
  """

  import Phoenix.LiveView

  @doc """
  Handle errors in LiveView with user-friendly messages and error logging.
  """
  def handle_error(error, socket, context \\ %{}) do
    # Add LiveView context
    full_context =
      Map.merge(context, %{
        view: socket.view,
        user_id: socket.assigns[:current_user_id],
        assigns: sanitize_assigns(socket.assigns)
      })

    error_id = EveDmv.SimpleErrorLogger.log_error(error, full_context)

    socket
    |> put_flash(:error, "Something went wrong. Error ID: #{error_id}")
  end

  @doc """
  Handle errors and redirect to safe location.
  """
  def handle_error_with_redirect(error, socket, redirect_to \\ "/") do
    socket = handle_error(error, socket)
    push_navigate(socket, to: redirect_to)
  end

  @doc """
  Safely execute a function and handle any errors gracefully.
  """
  def safe_execute(socket, context, fun) when is_function(fun, 0) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} when is_binary(reason) ->
        {:error, put_flash(socket, :error, reason)}

      {:error, reason} ->
        {:error, put_flash(socket, :error, "Operation failed: #{inspect(reason)}")}

      other ->
        {:ok, other}
    end
  rescue
    error ->
      error_socket = handle_error(error, socket, context)
      {:error, error_socket}
  end

  defp sanitize_assigns(assigns) do
    # Keep only safe assigns for logging
    assigns
    |> Map.take([:current_user_id, :page_title, :live_action])
    |> Enum.reject(fn {_k, v} -> is_function(v) end)
    |> Map.new()
  end
end
