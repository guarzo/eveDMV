defmodule EveDmvWeb.Api.ApiKeysController do
  @moduledoc """
  Controller for managing API keys through REST endpoints.

  Provides endpoints for creating, listing, and revoking API keys
  for authenticated users.
  """

  use EveDmvWeb, :controller
  require Logger

  alias EveDmv.Security.{ApiAuthentication, AuditLogger}

  action_fallback(EveDmvWeb.FallbackController)

  @doc """
  List API keys for the current user.
  """
  def index(conn, _params) do
    with character_id when character_id != nil <- get_current_character_id(conn),
         {:ok, api_keys} <- ApiAuthentication.list_character_api_keys(character_id) do
      conn
      |> put_status(:ok)
      |> json(%{api_keys: Enum.map(api_keys, &format_api_key/1)})
    else
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to retrieve API keys: #{reason}"})
    end
  end

  @doc """
  Create a new API key.
  """
  def create(conn, params) do
    with character_id when character_id != nil <- get_current_character_id(conn),
         {:ok, api_key} <-
           ApiAuthentication.create_api_key(
             character_id,
             Map.get(params, "name", "API Key"),
             Map.get(params, "permissions", []),
             parse_expires_at(Map.get(params, "expires_at"))
           ) do
      # Log the creation
      AuditLogger.log_api_key_event(:key_created, api_key.id, character_id)

      conn
      |> put_status(:created)
      |> json(%{api_key: format_api_key(api_key)})
    else
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to create API key: #{inspect(reason)}"})
    end
  end

  @doc """
  Delete/revoke an API key.
  """
  def delete(conn, %{"id" => api_key_id}) do
    with character_id when character_id != nil <- get_current_character_id(conn),
         {:ok, _api_key} <- ApiAuthentication.revoke_api_key(api_key_id, character_id) do
      # Log the revocation
      AuditLogger.log_api_key_event(:key_revoked, api_key_id, character_id)

      conn
      |> put_status(:no_content)
      |> json(%{})
    else
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "API key not found"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to revoke API key: #{inspect(reason)}"})
    end
  end

  @doc """
  Validate an API key.
  """
  def validate(conn, %{"api_key" => api_key}) do
    client_ip = get_client_ip(conn)
    required_permissions = Map.get(conn.params, "permissions", [])

    case ApiAuthentication.validate_api_key(api_key, client_ip, required_permissions) do
      {:ok, key_record} ->
        conn
        |> put_status(:ok)
        |> json(%{
          valid: true,
          character_id: key_record.character_id,
          permissions: key_record.permissions
        })

      {:error, :invalid_api_key} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{valid: false, error: "Invalid API key"})

      {:error, :expired} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{valid: false, error: "API key has expired"})

      {:error, :insufficient_permissions} ->
        conn
        |> put_status(:forbidden)
        |> json(%{valid: false, error: "Insufficient permissions"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{valid: false, error: "Validation failed: #{inspect(reason)}"})
    end
  end

  # Helper functions
  defp get_current_character_id(conn) do
    # Extract character ID from session or token
    case get_session(conn, :current_user_id) do
      nil -> nil
      user_id -> user_id
    end
  end

  defp get_client_ip(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> to_string(:inet_parse.ntoa(conn.remote_ip))
    end
  end

  defp parse_expires_at(nil), do: nil

  defp parse_expires_at(expires_at) when is_binary(expires_at) do
    case DateTime.from_iso8601(expires_at) do
      {:ok, datetime, _} -> datetime
      {:error, _} -> nil
    end
  end

  defp parse_expires_at(%DateTime{} = datetime), do: datetime
  defp parse_expires_at(_), do: nil

  defp format_api_key(api_key) do
    %{
      id: api_key.id,
      name: api_key.name,
      permissions: api_key.permissions,
      last_used_at: api_key.last_used_at,
      expires_at: api_key.expires_at,
      created_at: api_key.created_at,
      is_active: api_key.is_active
      # Note: Never include the actual API key in responses
    }
  end
end
