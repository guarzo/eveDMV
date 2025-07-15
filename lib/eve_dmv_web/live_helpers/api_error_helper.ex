defmodule EveDmvWeb.LiveHelpers.ApiErrorHelper do
  @moduledoc """
  Helper functions for handling API errors in LiveViews.

  Import this module in LiveViews to get convenient error handling functions.
  """

  alias EveDmvWeb.Components.ApiErrorHandler
  # import Phoenix.LiveView
  import Phoenix.Component

  @doc """
  Convenience macro for handling API calls with automatic error handling.

  ## Examples

      with_api_error_handling socket, "Loading character data" do
        case CharacterService.fetch_character(character_id) do
          {:ok, character} -> {:ok, assign(socket, :character, character)}
          error -> error
        end
      end
  """
  defmacro with_api_error_handling(socket, context, do: block) do
    quote do
      result = unquote(block)

      case result do
        {:ok, updated_socket} ->
          {:noreply, updated_socket}

        {:error, %Phoenix.LiveView.Socket{} = error_socket} ->
          {:noreply, error_socket}

        {:error, error} ->
          {:error, error_socket} =
            ApiErrorHandler.handle_api_error(unquote(socket), error, unquote(context))

          {:noreply, error_socket}

        error ->
          {:error, error_socket} =
            ApiErrorHandler.handle_api_error(unquote(socket), error, unquote(context))

          {:noreply, error_socket}
      end
    end
  end

  @doc """
  Handle API errors and return updated socket.
  """
  def handle_api_error(socket, error, context \\ "Operation failed") do
    ApiErrorHandler.handle_api_error(socket, error, context)
  end

  @doc """
  Handle API errors with retry capability.
  """
  def handle_api_error_with_retry(socket, error, context, retry_action \\ nil) do
    ApiErrorHandler.handle_api_error_with_retry(socket, error, context, retry_action)
  end

  @doc """
  Handle successful recovery after errors.
  """
  def handle_api_recovery(socket, context \\ "Operation") do
    ApiErrorHandler.handle_api_recovery(socket, context)
  end

  @doc """
  Safely execute an API call with error handling.
  """
  def safe_api_call(socket, api_function, context \\ "API call") do
    try do
      case api_function.() do
        {:ok, result} -> {:ok, result}
        error -> handle_api_error(socket, error, context)
      end
    rescue
      exception ->
        handle_api_error(socket, {:error, exception}, context)
    end
  end

  @doc """
  Execute API call with automatic retry on retryable errors.
  """
  def api_call_with_retry(socket, api_function, context, max_retries \\ 3) do
    api_call_with_retry_impl(socket, api_function, context, max_retries, 0)
  end

  defp api_call_with_retry_impl(socket, api_function, context, max_retries, attempt) do
    case safe_api_call(socket, api_function, context) do
      {:ok, result} ->
        if attempt > 0 do
          # We recovered after retries
          updated_socket = handle_api_recovery(socket, context)
          {:ok, result, updated_socket}
        else
          {:ok, result}
        end

      {:error, _error_socket} = error ->
        if attempt < max_retries and ApiErrorHandler.retryable_error?(error) do
          # Wait before retry
          delay = ApiErrorHandler.get_retry_delay(error)
          :timer.sleep(delay)

          api_call_with_retry_impl(socket, api_function, context, max_retries, attempt + 1)
        else
          error
        end
    end
  end

  @doc """
  Show loading state during API calls.
  """
  def with_loading_state(socket, loading_key, api_function, context \\ "Loading data") do
    # Set loading state
    socket = assign(socket, loading_key, true)

    case safe_api_call(socket, api_function, context) do
      {:ok, result} ->
        # Clear loading state
        updated_socket = assign(socket, loading_key, false)
        {:ok, result, updated_socket}

      {:error, error_socket} ->
        # Clear loading state even on error
        updated_socket = assign(error_socket, loading_key, false)
        {:error, updated_socket}
    end
  end
end
