defmodule EveDmvWeb.FallbackController do
  @moduledoc """
  Fallback controller for handling errors across all API endpoints.

  This controller provides consistent error responses and error handling
  for all API controllers that use action_fallback/1. It handles both
  JSON API responses and HTML view responses based on the request content type.
  """

  use EveDmvWeb, :controller
  require Logger

  @doc """
  Handle Ash framework validation errors.
  """
  def call(conn, {:error, %Ash.Error.Invalid{} = error}) do
    Logger.warning("Ash validation error: #{inspect(error)}")

    errors = format_ash_validation_errors(error.errors)

    case get_response_format(conn) do
      :json ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "Validation failed",
          details: errors
        })

      :html ->
        conn
        |> put_status(:bad_request)
        |> put_view(EveDmvWeb.ErrorView)
        |> render(:"400")
    end
  end

  def call(conn, {:error, %Ash.Error.Query.NotFound{} = error}) do
    Logger.info("Resource not found: #{inspect(error)}")

    case get_response_format(conn) do
      :json ->
        conn
        |> put_status(:not_found)
        |> json(%{
          error: "Resource not found",
          message: "The requested resource could not be found"
        })

      :html ->
        conn
        |> put_status(:not_found)
        |> put_view(EveDmvWeb.ErrorView)
        |> render(:"404")
    end
  end

  def call(conn, {:error, %Ash.Error.Forbidden{} = error}) do
    Logger.warning("Access forbidden: #{inspect(error)}")

    case get_response_format(conn) do
      :json ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error: "Access forbidden",
          message: "You do not have permission to access this resource"
        })

      :html ->
        conn
        |> put_status(:forbidden)
        |> put_view(EveDmvWeb.ErrorView)
        |> render(:"403")
    end
  end

  def call(conn, {:error, %Ash.Error.Framework{} = error}) do
    Logger.error("Ash framework error: #{inspect(error)}")

    case get_response_format(conn) do
      :json ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: "Internal server error",
          message: "An unexpected error occurred"
        })

      :html ->
        conn
        |> put_status(:internal_server_error)
        |> put_view(EveDmvWeb.ErrorView)
        |> render(:"500")
    end
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    Logger.warning("Changeset validation error: #{inspect(changeset.errors)}")

    case get_response_format(conn) do
      :json ->
        errors = format_changeset_errors(changeset)

        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "Validation failed",
          details: errors
        })

      :html ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(EveDmvWeb.ChangesetView)
        |> render("error.json", changeset: changeset)
    end
  end

  def call(conn, {:error, :not_found}) do
    case get_response_format(conn) do
      :json ->
        conn
        |> put_status(:not_found)
        |> json(%{
          error: "Not found",
          message: "The requested resource could not be found"
        })

      :html ->
        conn
        |> put_status(:not_found)
        |> put_view(EveDmvWeb.ErrorView)
        |> render(:"404")
    end
  end

  def call(conn, {:error, :unauthorized}) do
    case get_response_format(conn) do
      :json ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          error: "Unauthorized",
          message: "Authentication required"
        })

      :html ->
        conn
        |> put_status(:unauthorized)
        |> put_view(EveDmvWeb.ErrorView)
        |> render(:"401")
    end
  end

  def call(conn, {:error, :forbidden}) do
    case get_response_format(conn) do
      :json ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error: "Forbidden",
          message: "You do not have permission to access this resource"
        })

      :html ->
        conn
        |> put_status(:forbidden)
        |> put_view(EveDmvWeb.ErrorView)
        |> render(:"403")
    end
  end

  def call(conn, {:error, :invalid_params}) do
    case get_response_format(conn) do
      :json ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "Invalid parameters",
          message: "The provided parameters are invalid"
        })

      :html ->
        conn
        |> put_status(:bad_request)
        |> put_view(EveDmvWeb.ErrorView)
        |> render(:"400")
    end
  end

  def call(conn, {:error, :timeout}) do
    Logger.warning("Request timeout")

    case get_response_format(conn) do
      :json ->
        conn
        |> put_status(:request_timeout)
        |> json(%{
          error: "Request timeout",
          message: "The request took too long to process"
        })

      :html ->
        conn
        |> put_status(:request_timeout)
        |> put_view(EveDmvWeb.ErrorView)
        |> render(:"408")
    end
  end

  def call(conn, {:error, :rate_limited}) do
    case get_response_format(conn) do
      :json ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{
          error: "Rate limited",
          message: "Too many requests. Please try again later"
        })

      :html ->
        conn
        |> put_status(:too_many_requests)
        |> put_view(EveDmvWeb.ErrorView)
        |> render(:"429")
    end
  end

  def call(conn, {:error, reason}) when is_binary(reason) do
    Logger.warning("API error: #{reason}")

    case get_response_format(conn) do
      :json ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "Request failed",
          message: reason
        })

      :html ->
        conn
        |> put_status(:bad_request)
        |> put_view(EveDmvWeb.ErrorView)
        |> render(:"400")
    end
  end

  def call(conn, {:error, reason}) when is_atom(reason) do
    Logger.warning("API error: #{inspect(reason)}")

    message = humanize_error_atom(reason)

    case get_response_format(conn) do
      :json ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "Request failed",
          message: message
        })

      :html ->
        conn
        |> put_status(:bad_request)
        |> put_view(EveDmvWeb.ErrorView)
        |> render(:"400")
    end
  end

  def call(conn, {:error, reason}) do
    Logger.error("Unhandled error in API: #{inspect(reason)}")

    case get_response_format(conn) do
      :json ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: "Internal server error",
          message: "An unexpected error occurred"
        })

      :html ->
        conn
        |> put_status(:internal_server_error)
        |> put_view(EveDmvWeb.ErrorView)
        |> render(:"500")
    end
  end

  def call(conn, nil) do
    Logger.warning("Unexpected nil result in API")

    case get_response_format(conn) do
      :json ->
        conn
        |> put_status(:not_found)
        |> json(%{
          error: "Not found",
          message: "The requested resource could not be found"
        })

      :html ->
        conn
        |> put_status(:not_found)
        |> put_view(EveDmvWeb.ErrorView)
        |> render(:"404")
    end
  end

  def call(conn, other) do
    Logger.error("Unexpected fallback result: #{inspect(other)}")

    case get_response_format(conn) do
      :json ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: "Internal server error",
          message: "An unexpected error occurred"
        })

      :html ->
        conn
        |> put_status(:internal_server_error)
        |> put_view(EveDmvWeb.ErrorView)
        |> render(:"500")
    end
  end

  # Private helper functions

  defp get_response_format(conn) do
    case get_req_header(conn, "accept") do
      [accept | _] ->
        if String.contains?(accept, "application/json") do
          :json
        else
          # Check if this is an API route
          case conn.request_path do
            "/api" <> _ -> :json
            _ -> :html
          end
        end

      [] ->
        # Check if this is an API route
        case conn.request_path do
          "/api" <> _ -> :json
          _ -> :html
        end
    end
  end

  defp format_ash_validation_errors(errors) do
    Enum.map(errors, fn error ->
      %{
        field: error.field,
        message: error.message,
        code: error.code || "validation_error"
      }
    end)
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp humanize_error_atom(:not_found), do: "Resource not found"
  defp humanize_error_atom(:unauthorized), do: "Authentication required"
  defp humanize_error_atom(:forbidden), do: "Access denied"
  defp humanize_error_atom(:invalid_params), do: "Invalid parameters provided"
  defp humanize_error_atom(:timeout), do: "Request timed out"
  defp humanize_error_atom(:rate_limited), do: "Too many requests"
  defp humanize_error_atom(:insufficient_data), do: "Insufficient data for analysis"
  defp humanize_error_atom(:character_not_found), do: "Character not found"
  defp humanize_error_atom(:corporation_not_found), do: "Corporation not found"
  defp humanize_error_atom(:alliance_not_found), do: "Alliance not found"
  defp humanize_error_atom(:system_not_found), do: "Solar system not found"
  defp humanize_error_atom(:invalid_character_id), do: "Invalid character ID"
  defp humanize_error_atom(:invalid_corporation_id), do: "Invalid corporation ID"
  defp humanize_error_atom(:analysis_failed), do: "Analysis could not be completed"
  defp humanize_error_atom(:database_error), do: "Database operation failed"
  defp humanize_error_atom(:external_api_error), do: "External API request failed"
  defp humanize_error_atom(:cache_error), do: "Cache operation failed"

  defp humanize_error_atom(atom),
    do: atom |> to_string() |> String.replace("_", " ") |> String.capitalize()
end
