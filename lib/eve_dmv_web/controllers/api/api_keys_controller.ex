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
    character_id = get_current_character_id(conn)

    case ApiAuthentication.list_character_api_keys(character_id) do
      {:ok, api_keys} ->
        json(conn, %{data: api_keys})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to fetch API keys", reason: inspect(reason)})
    end
  end

  @doc """
  Create a new API key.
  """
  def create(conn, %{"name" => name} = params) do
    character_id = get_current_character_id(conn)
    permissions = Map.get(params, "permissions", [])
    expires_at = parse_expiration(Map.get(params, "expires_at"))

    api_key_params = %{
      name: name,
      permissions: permissions,
      expires_at: expires_at,
      created_by_character_id: character_id
    }

    case Ash.create(ApiAuthentication, api_key_params, domain: EveDmv.Api) do
      {:ok, api_key} ->
        # Get the generated key from the context
        generated_key = get_generated_key_from_context(api_key)

        # Log API key creation
        AuditLogger.log_config_change(
          "character_#{character_id}",
          :api_key_creation,
          nil,
          %{name: name, permissions: permissions}
        )

        conn
        |> put_status(:created)
        |> json(%{
          data: format_created_api_key(api_key, generated_key),
          message:
            "API key created successfully. Store this key securely - it cannot be retrieved again."
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to create API key", reason: inspect(reason)})
    end
  end

  @doc """
  Revoke an API key.
  """
  def delete(conn, %{"id" => api_key_id}) do
    character_id = get_current_character_id(conn)

    case ApiAuthentication.revoke_api_key(api_key_id, character_id) do
      {:ok, _api_key} ->
        json(conn, %{message: "API key revoked successfully"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to revoke API key", reason: inspect(reason)})
    end
  end

  @doc """
  Validate an API key (for testing purposes).
  """
  def validate(conn, %{"api_key" => api_key}) do
    client_ip = get_client_ip(conn)

    case ApiAuthentication.validate_api_key(api_key, client_ip) do
      {:ok, api_key_record} ->
        json(conn, %{
          valid: true,
          data: %{
            name: api_key_record.name,
            permissions: api_key_record.permissions,
            last_used_at: api_key_record.last_used_at,
            expires_at: api_key_record.expires_at
          }
        })

      {:error, reason} ->
        json(conn, %{
          valid: false,
          error: inspect(reason)
        })
    end
  end

  # Private helper functions

  defp get_current_character_id(conn) do
    # This would typically come from the authenticated user session
    # For now, we'll use a placeholder
    case conn.assigns[:current_user] do
      %{id: user_id} -> user_id
      _ -> nil
    end
  end

  defp parse_expiration(nil), do: nil
  defp parse_expiration(""), do: nil

  defp parse_expiration(expiration_string) when is_binary(expiration_string) do
    case DateTime.from_iso8601(expiration_string) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> nil
    end
  end

  defp parse_expiration(_), do: nil

  defp get_generated_key_from_context(api_key) do
    # Retrieve the generated key from the Ash context
    # If not available, this indicates a system error
    case Map.get(api_key.__context__ || %{}, :generated_key) do
      nil ->
        Logger.error("Generated API key not found in Ash context for API key #{api_key.id}")
        # Generate a new key as fallback, but this should be investigated
        Base.encode64(:crypto.strong_rand_bytes(32), padding: false)

      key ->
        key
    end
  end

  defp format_created_api_key(api_key, generated_key) do
    %{
      id: api_key.id,
      name: api_key.name,
      api_key: generated_key,
      prefix: api_key.prefix,
      permissions: api_key.permissions,
      expires_at: api_key.expires_at,
      created_at: api_key.inserted_at
    }
  end

  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded_ips] ->
        forwarded_ips
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end
end
