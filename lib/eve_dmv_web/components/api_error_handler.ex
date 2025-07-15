defmodule EveDmvWeb.Components.ApiErrorHandler do
  @moduledoc """
  Centralized API error handling component for user feedback.

  Provides consistent error handling across all LiveView pages,
  with user-friendly error messages and fallback strategies.
  """

  use Phoenix.Component
  import Phoenix.LiveView
  require Logger

  @doc """
  Handle API errors and provide user feedback via flash messages.

  ## Examples

      case make_api_call() do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> handle_api_error(socket, reason, "Failed to load data")
      end
  """
  def handle_api_error(socket, error, context \\ "Operation failed") do
    {user_message, log_level} = classify_error(error)

    # Log the error with context
    case log_level do
      :error ->
        Logger.error("API Error in #{context}: #{inspect(error)}")

      :warning ->
        Logger.warning("API Warning in #{context}: #{inspect(error)}")

      :info ->
        Logger.info("API Info in #{context}: #{inspect(error)}")
    end

    # Show user-friendly message
    updated_socket = put_flash(socket, :error, user_message)

    {:error, updated_socket}
  end

  @doc """
  Handle API errors with retry capability.
  """
  def handle_api_error_with_retry(socket, error, context, retry_action \\ nil) do
    {user_message, log_level} = classify_error(error)

    case log_level do
      :error ->
        Logger.error("API Error in #{context}: #{inspect(error)}")

      :warning ->
        Logger.warning("API Warning in #{context}: #{inspect(error)}")

      :info ->
        Logger.info("API Info in #{context}: #{inspect(error)}")
    end

    # Build message with retry option if available
    final_message =
      if retry_action do
        "#{user_message} You can try refreshing the page or try again later."
      else
        user_message
      end

    updated_socket = put_flash(socket, :error, final_message)

    {:error, updated_socket}
  end

  @doc """
  Handle successful API recovery after previous errors.
  """
  def handle_api_recovery(socket, context \\ "Operation") do
    Logger.info("API Recovery: #{context} succeeded after previous errors")
    put_flash(socket, :info, "Connection restored successfully")
  end

  # Classify errors and return user-friendly messages.
  defp classify_error(error) do
    case error do
      # Network/connectivity errors
      {:error, %{reason: :nxdomain}} ->
        {"Unable to connect to EVE servers. Please check your internet connection.", :error}

      {:error, %{reason: :timeout}} ->
        {"Request timed out. EVE servers may be experiencing high load.", :warning}

      {:error, %{reason: :econnrefused}} ->
        {"Connection refused. EVE servers may be down for maintenance.", :error}

      {:error, %{reason: :closed}} ->
        {"Connection closed unexpectedly. Please try again.", :warning}

      # HTTP status errors
      {:error, %{status: 404}} ->
        {"The requested data was not found. It may have been moved or deleted.", :warning}

      {:error, %{status: 500}} ->
        {"EVE servers are experiencing internal errors. Please try again later.", :error}

      {:error, %{status: 502}} ->
        {"EVE servers are temporarily unavailable. Please try again in a few minutes.", :warning}

      {:error, %{status: 503}} ->
        {"EVE servers are under maintenance. Please try again later.", :warning}

      {:error, %{status: 429}} ->
        {"Rate limit exceeded. Please wait before making more requests.", :warning}

      {:error, %{status: 420}} ->
        {"EVE API rate limit exceeded. Please wait before trying again.", :warning}

      # Authentication errors
      {:error, %{status: 401}} ->
        {"Authentication failed. Please log in again.", :error}

      {:error, %{status: 403}} ->
        {"Access denied. You may not have permission to access this data.", :error}

      # Database errors
      {:error, :timeout} ->
        {"Database operation timed out. Please try again.", :warning}

      {:error, :database_unavailable} ->
        {"Database is temporarily unavailable. Please try again later.", :error}

      # Parse/format errors
      {:error, :invalid_json} ->
        {"Received invalid data format. Please try again.", :warning}

      {:error, :invalid_response} ->
        {"Received unexpected response format. Please try again.", :warning}

      # ESI-specific errors
      {:error, :esi_unavailable} ->
        {"EVE ESI API is temporarily unavailable. Please try again later.", :warning}

      {:error, :character_not_found} ->
        {"Character not found. Please check the character name and try again.", :warning}

      {:error, :corporation_not_found} ->
        {"Corporation not found. Please check the corporation name and try again.", :warning}

      # Circuit breaker errors
      {:error, :circuit_open} ->
        {"Service temporarily unavailable due to repeated failures. Please try again later.",
         :error}

      # Generic errors
      {:error, reason} when is_binary(reason) ->
        {"#{reason}. Please try again.", :warning}

      {:error, reason} when is_atom(reason) ->
        {humanize_error(reason), :warning}

      {:error, _} ->
        {"An unexpected error occurred. Please try again.", :error}

      # Non-tuple errors
      :timeout ->
        {"Operation timed out. Please try again.", :warning}

      :unavailable ->
        {"Service temporarily unavailable. Please try again later.", :warning}

      _ ->
        {"An unexpected error occurred. Please try again.", :error}
    end
  end

  # Convert atom errors to human-readable messages.
  defp humanize_error(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  @doc """
  Check if an error is retryable.
  """
  def retryable_error?(error) do
    case error do
      {:error, %{reason: :timeout}} -> true
      {:error, %{reason: :closed}} -> true
      {:error, %{status: status}} when status in [502, 503, 429, 420] -> true
      {:error, :timeout} -> true
      {:error, :esi_unavailable} -> true
      :timeout -> true
      :unavailable -> true
      _ -> false
    end
  end

  @doc """
  Get retry delay based on error type.
  """
  def get_retry_delay(error) do
    case error do
      # 30 seconds for rate limit
      {:error, %{status: 429}} -> 30_000
      # 60 seconds for ESI rate limit
      {:error, %{status: 420}} -> 60_000
      # 2 minutes for maintenance
      {:error, %{status: 503}} -> 120_000
      # 5 seconds for timeout
      {:error, %{reason: :timeout}} -> 5_000
      # 10 seconds default
      _ -> 10_000
    end
  end
end
