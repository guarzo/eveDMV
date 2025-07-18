defmodule EveDmv.Users.TokenRefreshService do
  @moduledoc """
  Service for automatically refreshing EVE SSO tokens before they expire.

  This service runs in the background and automatically refreshes user tokens
  when they are within 5 minutes of expiring, ensuring seamless user experience
  without requiring manual re-authentication.
  """

  use GenServer
  require Logger

  alias EveDmv.Api
  alias EveDmv.Users.User

  import Ash.Query

  # Check for expiring tokens every 2 minutes
  @check_interval :timer.minutes(2)
  # Refresh tokens when they expire within 5 minutes
  @refresh_threshold_minutes 5

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Manually refresh a user's token if it's about to expire.
  Returns {:ok, user} if refresh was successful or not needed.
  """
  def refresh_user_token(user_id) do
    GenServer.call(__MODULE__, {:refresh_user_token, user_id})
  end

  @doc """
  Check if a user's token needs refreshing.
  """
  def token_needs_refresh?(user) do
    case user.token_expires_at do
      nil ->
        false

      expires_at ->
        threshold = DateTime.add(DateTime.utc_now(), @refresh_threshold_minutes * 60, :second)
        DateTime.compare(expires_at, threshold) == :lt
    end
  end

  # GenServer callbacks

  @impl GenServer
  def init(_opts) do
    # Schedule the first token check
    schedule_token_check()

    state = %{
      refreshes_performed: 0,
      last_check_at: DateTime.utc_now(),
      errors_encountered: 0
    }

    Logger.info(
      "🔄 Token Refresh Service started - checking every #{@check_interval / 60_000} minutes"
    )

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:refresh_user_token, user_id}, _from, state) do
    case refresh_single_user_token(user_id) do
      {:ok, user} ->
        new_state = %{state | refreshes_performed: state.refreshes_performed + 1}
        {:reply, {:ok, user}, new_state}

      {:error, reason} ->
        new_state = %{state | errors_encountered: state.errors_encountered + 1}
        {:reply, {:error, reason}, new_state}
    end
  end

  def handle_call(:get_stats, _from, state) do
    stats = %{
      refreshes_performed: state.refreshes_performed,
      errors_encountered: state.errors_encountered,
      last_check_at: state.last_check_at,
      service_uptime_seconds: DateTime.diff(DateTime.utc_now(), state.last_check_at)
    }

    {:reply, stats, state}
  end

  @impl GenServer
  def handle_info(:check_tokens, state) do
    Logger.debug("🕐 Checking for tokens that need refreshing...")

    new_state =
      state
      |> Map.put(:last_check_at, DateTime.utc_now())
      |> check_and_refresh_tokens()

    # Schedule the next check
    schedule_token_check()

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(msg, state) do
    Logger.debug("TokenRefreshService received unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private functions

  defp schedule_token_check do
    Process.send_after(self(), :check_tokens, @check_interval)
  end

  defp check_and_refresh_tokens(state) do
    # Find users with tokens that are about to expire
    threshold = DateTime.add(DateTime.utc_now(), @refresh_threshold_minutes * 60, :second)

    query =
      User
      |> new()
      |> filter(not is_nil(refresh_token))
      |> filter(not is_nil(token_expires_at))
      |> filter(token_expires_at <= ^threshold)
      |> select([:id, :eve_character_name, :token_expires_at, :refresh_token])
      # Process in batches to avoid overwhelming the system
      |> limit(50)

    case Ash.read(query, domain: Api) do
      {:ok, users} ->
        if length(users) > 0 do
          Logger.info("🔄 Found #{length(users)} users with tokens needing refresh")

          refresh_results =
            users
            |> Enum.map(&refresh_single_user_token/1)
            |> Enum.reduce({0, 0}, fn result, {success_count, error_count} ->
              case result do
                {:ok, _} -> {success_count + 1, error_count}
                {:error, _} -> {success_count, error_count + 1}
              end
            end)

          {success_count, error_count} = refresh_results

          if success_count > 0 do
            Logger.info("✅ Successfully refreshed #{success_count} tokens")
          end

          if error_count > 0 do
            Logger.warning("❌ Failed to refresh #{error_count} tokens")
          end

          %{
            state
            | refreshes_performed: state.refreshes_performed + success_count,
              errors_encountered: state.errors_encountered + error_count
          }
        else
          Logger.debug("✅ No tokens need refreshing at this time")
          state
        end

      {:error, reason} ->
        Logger.error("Failed to query users for token refresh: #{inspect(reason)}")
        %{state | errors_encountered: state.errors_encountered + 1}
    end
  end

  defp refresh_single_user_token(user_or_user_id) do
    user =
      case user_or_user_id do
        %User{} = u ->
          u

        user_id when is_binary(user_id) ->
          case Ash.get(User, user_id, domain: Api) do
            {:ok, user} -> user
            {:error, _} -> nil
          end

        _ ->
          nil
      end

    if user && user.refresh_token do
      Logger.debug("🔄 Refreshing token for user #{user.eve_character_name} (#{user.id})")

      case request_token_refresh(user.refresh_token) do
        {:ok, new_tokens} ->
          # Update the user with new tokens
          case update_user_tokens(user, new_tokens) do
            {:ok, updated_user} ->
              Logger.info("✅ Successfully refreshed token for #{user.eve_character_name}")
              {:ok, updated_user}

            {:error, reason} ->
              Logger.error(
                "Failed to save refreshed tokens for #{user.eve_character_name}: #{inspect(reason)}"
              )

              {:error, :update_failed}
          end

        {:error, reason} ->
          Logger.warning(
            "Failed to refresh token for #{user.eve_character_name}: #{inspect(reason)}"
          )

          {:error, reason}
      end
    else
      {:error, :invalid_user_or_no_refresh_token}
    end
  end

  defp request_token_refresh(refresh_token) do
    # Make a request to EVE SSO to refresh the token
    client_id = System.get_env("EVE_SSO_CLIENT_ID")
    client_secret = System.get_env("EVE_SSO_CLIENT_SECRET")

    if client_id && client_secret do
      # Prepare the refresh request
      auth_header = Base.encode64("#{client_id}:#{client_secret}")

      headers = [
        {"Authorization", "Basic #{auth_header}"},
        {"Content-Type", "application/x-www-form-urlencoded"},
        {"User-Agent", "EVE-DMV/1.0"}
      ]

      body =
        URI.encode_query(%{
          "grant_type" => "refresh_token",
          "refresh_token" => refresh_token
        })

      url = "https://login.eveonline.com/v2/oauth/token"

      case HTTPoison.post(url, body, headers) do
        {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
          case Jason.decode(response_body) do
            {:ok, token_data} ->
              # Calculate expiration time
              expires_at =
                case Map.get(token_data, "expires_in") do
                  expires_in when is_integer(expires_in) ->
                    DateTime.add(DateTime.utc_now(), expires_in, :second)

                  _ ->
                    # Default to 20 minutes if no expires_in provided
                    DateTime.add(DateTime.utc_now(), 20 * 60, :second)
                end

              new_tokens = %{
                access_token: Map.get(token_data, "access_token"),
                refresh_token: Map.get(token_data, "refresh_token", refresh_token),
                token_expires_at: expires_at
              }

              {:ok, new_tokens}

            {:error, reason} ->
              Logger.error("Failed to parse token refresh response: #{inspect(reason)}")
              {:error, :invalid_response}
          end

        {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
          Logger.error("Token refresh failed with status #{status_code}: #{body}")
          {:error, :refresh_failed}

        {:error, reason} ->
          Logger.error("HTTP request failed during token refresh: #{inspect(reason)}")
          {:error, :network_error}
      end
    else
      Logger.error("EVE SSO credentials not configured for token refresh")
      {:error, :missing_credentials}
    end
  end

  defp update_user_tokens(user, new_tokens) do
    # Use the refresh_token action to update the user
    user
    |> Ash.Changeset.for_update(:refresh_token, new_tokens)
    |> Ash.update(domain: Api)
  end

  @doc """
  Get service statistics for monitoring.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end
end
