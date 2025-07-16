defmodule EveDmvWeb.Components.ErrorHandler do
  import Phoenix.Component, only: [assign: 3]
  require Logger

  @moduledoc """
  Standardized error handling utilities for EVE DMV LiveView components.

  Provides consistent error handling patterns, user-friendly error messages,
  and proper logging with user context.
  """

  @doc """
  Safely executes a database operation with proper error handling and logging.
  ## Examples
      case safe_database_operation(socket, "load_character_data", fn ->
        CharacterService.get_character(character_id)
      end) do
        {:ok, character} -> assign(socket, :character, character)
        {:error, message} -> put_flash(socket, :error, message)
      end
  """
  def safe_database_operation(socket, operation_name, operation_func) do
    user_context = get_user_context(socket)

    try do
      case operation_func.() do
        {:ok, result} ->
          {:ok, result}

        {:error, reason} ->
          log_with_context(:error, "#{operation_name} failed: #{inspect(reason)}", user_context)
          {:error, format_user_error(reason)}

        nil ->
          log_with_context(:warning, "#{operation_name} returned nil", user_context)
          {:error, "No data found"}

        result ->
          {:ok, result}
      end
    rescue
      error ->
        log_with_context(:error, "#{operation_name} exception: #{inspect(error)}", user_context)
        {:error, "Operation failed. Please try again."}
    end
  end

  @doc """
  Safely executes an external API call with timeout and retry logic.
  ## Examples
      case safe_external_call(socket, "fetch_character_info", fn ->
        EsiClient.get_character(character_id)
      end, timeout: 5000, max_retries: 2) do
        {:ok, data} -> handle_success(data)
        {:error, :timeout} -> handle_timeout()
        {:error, message} -> handle_error(message)
      end
  """
  def safe_external_call(socket, operation_name, operation_func, opts \\ []) do
    user_context = get_user_context(socket)
    timeout = Keyword.get(opts, :timeout, 5000)
    max_retries = Keyword.get(opts, :max_retries, 3)
    execute_with_retry(operation_name, operation_func, user_context, max_retries, timeout)
  end

  @doc """
  Validates and parses an integer parameter with proper error handling.
  ## Examples
      case validate_integer_param("character_id", params["character_id"]) do
        {:ok, character_id} -> # proceed with valid integer
        {:error, message} -> # handle validation error
      end
  """
  def validate_integer_param(param_name, param_value, opts \\ []) do
    min_value = Keyword.get(opts, :min, 1)
    max_value = Keyword.get(opts, :max, nil)

    case Integer.parse(param_value || "") do
      {int_value, ""} when int_value >= min_value ->
        if max_value && int_value > max_value do
          {:error, "#{param_name} must be less than or equal to #{max_value}"}
        else
          {:ok, int_value}
        end

      {_int_value, ""} ->
        {:error, "#{param_name} must be at least #{min_value}"}

      _ ->
        {:error, "#{param_name} must be a valid number"}
    end
  end

  @doc """
  Validates a string parameter with length and format constraints.
  ## Examples
      case validate_string_param("search_query", params["query"], min_length: 2, max_length: 100) do
        {:ok, query} -> # proceed with valid string
        {:error, message} -> # handle validation error
      end
  """
  def validate_string_param(param_name, param_value, opts \\ []) do
    min_length = Keyword.get(opts, :min_length, 0)
    max_length = Keyword.get(opts, :max_length, 1000)
    required = Keyword.get(opts, :required, false)

    case String.trim(param_value || "") do
      "" when required ->
        {:error, "#{param_name} is required"}

      "" ->
        {:ok, ""}

      value when byte_size(value) < min_length ->
        {:error, "#{param_name} must be at least #{min_length} characters"}

      value when byte_size(value) > max_length ->
        {:error, "#{param_name} must be less than #{max_length} characters"}

      value ->
        {:ok, value}
    end
  end

  @doc """
  Handles errors in LiveView event handlers with consistent flash messaging.
  ## Examples
      def handle_event("save_profile", params, socket) do
        case ProfileService.save_profile(params) do
          {:ok, profile} -> 
            {:noreply, assign(socket, :profile, profile)}
          {:error, error} -> 
            {:noreply, handle_event_error(socket, "save profile", error)}
        end
      end
  """
  def handle_event_error(socket, operation_name, error) do
    user_context = get_user_context(socket)
    error_message = format_user_error(error)
    log_with_context(:error, "Failed to #{operation_name}: #{inspect(error)}", user_context)
    put_flash(socket, :error, error_message)
  end

  @doc """
  Handles successful operations with optional success messaging.
  ## Examples
      socket = handle_event_success(socket, "Profile saved successfully")
  """
  def handle_event_success(socket, message \\ nil) do
    if message do
      put_flash(socket, :info, message)
    else
      socket
    end
  end

  @doc """
  Adds error recovery options to the socket for user-initiated retries.
  ## Examples
      socket = add_error_recovery(socket, :load_data, "Failed to load character data")
  """
  def add_error_recovery(socket, operation_atom, error_message) do
    assign(socket, :error_state, %{
      operation: operation_atom,
      message: error_message,
      recoverable: true,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Clears error recovery state after successful operation.
  """
  def clear_error_recovery(socket) do
    assign(socket, :error_state, nil)
  end

  @doc """
  Logs a message with user context information.
  ## Examples
      log_with_context(:info, "User performed action", socket)
  """
  def log_with_context(level, message, socket_or_context) do
    user_context = get_user_context(socket_or_context)

    context_info =
      case user_context do
        %{user_id: user_id, session_id: session_id} ->
          "[User:#{user_id}][Session:#{session_id}]"

        %{user_id: user_id} ->
          "[User:#{user_id}]"

        _ ->
          "[Anonymous]"
      end

    Logger.log(level, "#{context_info} #{message}")
  end

  # Private helper functions
  defp execute_with_retry(operation_name, operation_func, user_context, retries_left, timeout) do
    task = Task.async(operation_func)

    case Task.yield(task, timeout) do
      {:ok, result} ->
        case result do
          {:ok, data} ->
            {:ok, data}

          {:error, reason} ->
            if retries_left > 0 do
              log_with_context(
                :warning,
                "#{operation_name} failed, retrying (#{retries_left} attempts left)",
                user_context
              )

              # Brief delay before retry
              Process.sleep(1000)

              execute_with_retry(
                operation_name,
                operation_func,
                user_context,
                retries_left - 1,
                timeout
              )
            else
              log_with_context(
                :error,
                "#{operation_name} failed after all retries: #{inspect(reason)}",
                user_context
              )

              {:error, format_user_error(reason)}
            end
        end

      nil ->
        Task.shutdown(task, :brutal_kill)
        log_with_context(:error, "#{operation_name} timeout after #{timeout}ms", user_context)
        {:error, :timeout}
    end
  end

  defp get_user_context(socket) when is_map(socket) do
    current_user = get_in(socket.assigns, [:current_user])
    session_id = get_in(socket.assigns, [:session_id])

    %{
      user_id: current_user && current_user.id,
      session_id: session_id
    }
  end

  defp get_user_context(context) when is_map(context), do: context
  defp get_user_context(_), do: %{}

  defp format_user_error(error) do
    case error do
      %Ash.Error.Query.NotFound{} ->
        "The requested item was not found."

      %Ash.Error.Invalid{} ->
        "Invalid input provided. Please check your data."

      %Ash.Error.Forbidden{} ->
        "You don't have permission to perform this action."

      %Ecto.Changeset{} ->
        "Validation failed. Please check your input."

      :timeout ->
        "Request timed out. Please try again."

      :rate_limited ->
        "Too many requests. Please wait before trying again."

      :insufficient_data ->
        "Not enough data available for this operation."

      :character_not_found ->
        "Character not found."

      :corporation_not_found ->
        "Corporation not found."

      :alliance_not_found ->
        "Alliance not found."

      :system_not_found ->
        "Solar system not found."

      :analysis_failed ->
        "Analysis could not be completed. Please try again."

      :database_error ->
        "Database error occurred. Please try again."

      :external_api_error ->
        "External service is temporarily unavailable."

      error when is_binary(error) ->
        error

      error when is_atom(error) ->
        error |> to_string() |> String.replace("_", " ") |> String.capitalize()

      _ ->
        "An unexpected error occurred. Please try again."
    end
  end

  defp put_flash(socket, type, message) do
    Phoenix.LiveView.put_flash(socket, type, message)
  end
end
