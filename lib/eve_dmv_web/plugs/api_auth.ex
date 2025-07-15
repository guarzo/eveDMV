defmodule EveDmvWeb.Plugs.ApiAuth do
  @moduledoc """
  Plug for authenticating API requests using API keys.

  This plug validates API keys for internal endpoints and ensures
  the requesting client has the necessary permissions.
  """

  import Plug.Conn

  alias EveDmv.Security.ApiAuthentication

  require Logger

  @doc """
  Initialize the plug with options.

  Options:
  - permissions: List of required permissions (default: [])
  - optional: If true, allows requests without API keys (default: false)
  """
  def init(opts) do
    %{
      permissions: Keyword.get(opts, :permissions, []),
      optional: Keyword.get(opts, :optional, false)
    }
  end

  @doc """
  Authenticate the API request using the Authorization header.
  """
  def call(conn, opts) do
    case get_api_key_from_headers(conn) do
      {:ok, api_key} ->
        authenticate_api_key(conn, api_key, opts)

      {:error, :missing} ->
        if opts.optional do
          assign(conn, :api_authenticated, false)
        else
          send_unauthorized(conn, "API key required")
        end

      {:error, :invalid_format} ->
        send_unauthorized(conn, "Invalid API key format")
    end
  end

  @doc """
  Helper function to check if the current request is API authenticated.
  """
  def api_authenticated?(conn) do
    Map.get(conn.assigns, :api_authenticated, false)
  end

  @doc """
  Helper function to get the current API key from the connection.
  """
  def current_api_key(conn) do
    Map.get(conn.assigns, :current_api_key)
  end

  @doc """
  Helper function to check if current API key has a specific permission.
  """
  def has_api_permission?(conn, permission) do
    case current_api_key(conn) do
      nil -> false
      api_key -> ApiAuthentication.has_permission?(api_key, permission)
    end
  end

  # Private helper functions

  defp get_api_key_from_headers(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> api_key] -> validate_api_key(api_key)
      ["ApiKey " <> api_key] -> validate_api_key(api_key)
      [api_key] -> validate_api_key(api_key)
      [] -> check_query_params(conn)
      _ -> {:error, :invalid_format}
    end
  end

  defp validate_api_key(api_key) do
    if valid_api_key_format?(api_key) do
      {:ok, api_key}
    else
      {:error, :invalid_format}
    end
  end

  defp check_query_params(conn) do
    case conn.params["api_key"] do
      nil -> {:error, :missing}
      api_key when is_binary(api_key) -> validate_api_key(api_key)
      _ -> {:error, :invalid_format}
    end
  end

  defp valid_api_key_format?(api_key) when is_binary(api_key) do
    # API keys should match format: edv_<8_char_prefix>_<base64_key>
    case String.split(api_key, "_") do
      ["edv", prefix, key] when byte_size(prefix) == 8 and byte_size(key) > 0 ->
        # Validate base64 format
        case Base.decode64(key, padding: false) do
          {:ok, _} -> true
          :error -> false
        end

      _ ->
        false
    end
  end

  @spec authenticate_api_key(Plug.Conn.t(), String.t(), map()) :: Plug.Conn.t()
  defp authenticate_api_key(conn, api_key, opts) do
    client_ip = get_client_ip(conn)

    case ApiAuthentication.validate_api_key(api_key, client_ip, opts.permissions) do
      {:ok, api_key_record} ->
        conn
        |> assign(:api_authenticated, true)
        |> assign(:current_api_key, api_key_record)
        |> assign(:api_created_by, api_key_record.created_by_character_id)

      {:error, reason} ->
        Logger.warning("API authentication failed", %{
          reason: reason,
          ip: client_ip,
          user_agent: conn |> get_req_header("user-agent") |> List.first()
        })

        error_message = format_api_error_message(reason)
        send_unauthorized(conn, error_message)
    end
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

  @spec send_unauthorized(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  defp send_unauthorized(conn, message) do
    conn
    |> put_status(:unauthorized)
    |> put_resp_content_type("application/json")
    |> send_resp(
      401,
      Jason.encode!(%{
        error: "Unauthorized",
        message: message,
        timestamp: DateTime.utc_now()
      })
    )
    |> halt()
  end

  defp format_api_error_message(:not_found), do: "Invalid API key"
  defp format_api_error_message(:invalid_key), do: "Invalid API key"
  defp format_api_error_message(:expired), do: "API key has expired"
  defp format_api_error_message(:inactive), do: "API key has been deactivated"
  defp format_api_error_message(:insufficient_permissions), do: "Insufficient permissions"
  defp format_api_error_message(_), do: "Authentication failed"
end
