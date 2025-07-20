defmodule EveDmv.Auth do
  @moduledoc """
  Authentication context for managing user authentication and tokens.
  """

  alias EveDmv.Api
  alias EveDmv.Users.User

  require Logger

  @doc """
  Refresh the EVE SSO token for a user.

  Uses the refresh token to get a new access token from EVE SSO.
  """
  def refresh_user_token(user) do
    with {:ok, _} <- validate_refresh_token(user),
         {:ok, token_data} <- refresh_eve_sso_token(user.refresh_token),
         {:ok, validated_data} <- validate_token_response(token_data),
         {:ok, updated_user} <- update_user_token(user, validated_data) do
      Logger.info("Successfully refreshed token for user #{user.id}")
      {:ok, updated_user}
    else
      {:error, :no_refresh_token} = error ->
        Logger.error("No refresh token available for user #{user.id}")
        error

      {:error, :invalid_token_response} = error ->
        Logger.error("Invalid token response from EVE SSO")
        error

      {:error, reason} ->
        Logger.error("Token refresh failed: #{inspect(reason)}")
        {:error, :token_refresh_failed}
    end
  end

  defp validate_refresh_token(user) do
    if user.refresh_token && user.refresh_token != "" do
      {:ok, user.refresh_token}
    else
      {:error, :no_refresh_token}
    end
  end

  defp validate_token_response(token_data) do
    if token_data.access_token && token_data.refresh_token do
      {:ok, token_data}
    else
      {:error, :invalid_token_response}
    end
  end

  defp update_user_token(user, token_data) do
    user
    |> Ash.Changeset.for_update(:refresh_token, %{
      access_token: token_data.access_token,
      refresh_token: token_data.refresh_token,
      token_expires_at: token_data.expires_at
    })
    |> Ash.update(domain: Api)
  end

  @doc """
  Check if a user's token is expired or will expire within the next 5 minutes.
  """
  def token_needs_refresh?(user) do
    case user.token_expires_at do
      nil ->
        false

      expires_at ->
        # Check if token expires within configured buffer time
        buffer_minutes = token_refresh_buffer_minutes()
        buffer_time = DateTime.add(DateTime.utc_now(), buffer_minutes * 60, :second)
        DateTime.compare(expires_at, buffer_time) == :lt
    end
  end

  @doc """
  Get the current user from the session.
  """
  def get_current_user(user_id) when is_binary(user_id) do
    with {:ok, _} <- validate_user_id(user_id),
         {:ok, user} <- Ash.get(User, user_id, domain: Api) do
      {:ok, user}
    else
      {:error, :invalid_user_id} = error -> error
      {:error, _} -> {:error, :user_not_found}
    end
  end

  defp validate_user_id(user_id) do
    # Validate UUID format
    case Ecto.UUID.cast(user_id) do
      {:ok, _uuid} -> {:ok, user_id}
      :error -> {:error, :invalid_user_id}
    end
  end

  # Private functions

  defp token_refresh_buffer_minutes do
    # Get from config or environment, default to 5 minutes
    Application.get_env(:eve_dmv, :token_refresh_buffer_minutes, 5)
  end

  defp eve_sso_token_url do
    # Get from config or environment, default to production URL
    Application.get_env(
      :eve_dmv,
      :eve_sso_token_url,
      "https://login.eveonline.com/v2/oauth/token"
    )
  end

  defp refresh_eve_sso_token(refresh_token) do
    # EVE SSO token refresh endpoint
    url = eve_sso_token_url()

    client_id = System.get_env("EVE_SSO_CLIENT_ID")
    client_secret = System.get_env("EVE_SSO_CLIENT_SECRET")

    if client_id && client_secret do
      # Create the request body
      body = %{
        "grant_type" => "refresh_token",
        "refresh_token" => refresh_token
      }

      # Basic auth header
      auth_header = Base.encode64("#{client_id}:#{client_secret}")

      headers = [
        {"Authorization", "Basic #{auth_header}"},
        {"Content-Type", "application/x-www-form-urlencoded"},
        {"User-Agent", "EVE-DMV/1.0"}
      ]

      # Convert body to form data
      form_data = URI.encode_query(body)

      case HTTPoison.post(url, form_data, headers) do
        {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
          decode_token_response(response_body)

        {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
          Logger.error("EVE SSO token refresh failed with status #{status_code}: #{body}")
          {:error, :eve_sso_error}

        {:error, reason} ->
          Logger.error("HTTP request failed: #{inspect(reason)}")
          {:error, :network_error}
      end
    else
      Logger.error("Missing EVE SSO client credentials")
      {:error, :missing_credentials}
    end
  end

  defp decode_token_response(response_body) do
    case Jason.decode(response_body) do
      {:ok, token_data} ->
        expires_at = calculate_expires_at(token_data["expires_in"])

        result = %{
          access_token: Map.get(token_data, "access_token"),
          refresh_token: Map.get(token_data, "refresh_token"),
          expires_at: expires_at
        }

        {:ok, result}

      {:error, reason} ->
        Logger.error("Failed to decode token response: #{inspect(reason)}")
        {:error, :invalid_response}
    end
  end

  defp calculate_expires_at(nil), do: nil

  defp calculate_expires_at(expires_in) when is_integer(expires_in) do
    DateTime.add(DateTime.utc_now(), expires_in, :second)
  end

  defp calculate_expires_at(_), do: nil
end
