defmodule EveDmvWeb.Plugs.AuthRateLimiter do
  @moduledoc """
  Rate limiting plug for authentication endpoints to prevent brute force attacks.

  This plug uses a token bucket algorithm to limit authentication attempts
  per IP address, preventing brute force attacks on the authentication system.
  """

  import Plug.Conn

  alias EveDmv.Security.AuditLogger

  require Logger

  # Default configuration
  @default_max_attempts 5
  @default_window_minutes 15
  @default_block_duration_minutes 30

  def init(opts) do
    opts
    |> Keyword.put_new(:max_attempts, @default_max_attempts)
    |> Keyword.put_new(:window_minutes, @default_window_minutes)
    |> Keyword.put_new(:block_duration_minutes, @default_block_duration_minutes)
  end

  def call(conn, opts) do
    # Only apply rate limiting to auth-related endpoints
    if should_rate_limit?(conn) do
      apply_rate_limiting(conn, opts)
    else
      conn
    end
  end

  defp should_rate_limit?(conn) do
    # Rate limit authentication-related endpoints
    conn.request_path =~ ~r{^/auth/} or
      conn.request_path =~ ~r{^/user/} or
      conn.request_path == "/login"
  end

  defp apply_rate_limiting(conn, opts) do
    client_ip = get_client_ip(conn)
    max_attempts = Keyword.get(opts, :max_attempts)
    window_minutes = Keyword.get(opts, :window_minutes)
    block_duration_minutes = Keyword.get(opts, :block_duration_minutes)

    case check_rate_limit(client_ip, max_attempts, window_minutes, block_duration_minutes) do
      :allowed ->
        # Track this attempt
        track_attempt(client_ip, window_minutes)
        conn

      {:blocked, remaining_time} ->
        # Log rate limiting event
        AuditLogger.log_rate_limit_exceeded(client_ip, conn.request_path, max_attempts)

        Logger.warning("Authentication rate limit exceeded", %{
          ip: client_ip,
          path: conn.request_path,
          remaining_block_time: remaining_time
        })

        conn
        |> put_status(:too_many_requests)
        |> put_resp_header("retry-after", to_string(remaining_time))
        |> put_resp_content_type("application/json")
        |> send_resp(
          429,
          Jason.encode!(%{
            error: "Too many authentication attempts",
            retry_after: remaining_time,
            message: "Please wait #{remaining_time} seconds before trying again"
          })
        )
        |> halt()
    end
  end

  defp get_client_ip(conn) do
    # Check X-Forwarded-For header for real IP when behind proxy
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded_ips] ->
        # Take the first IP from the forwarded chain
        forwarded_ips
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        # Fallback to direct connection IP
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end

  defp check_rate_limit(client_ip, max_attempts, window_minutes, block_duration_minutes) do
    current_time = System.system_time(:second)
    window_start = current_time - window_minutes * 60

    # Check if IP is currently blocked
    case get_block_status(client_ip, current_time) do
      {:blocked, until_time} ->
        remaining = until_time - current_time
        {:blocked, remaining}

      :not_blocked ->
        # Check attempt count in current window
        attempts = count_recent_attempts(client_ip, window_start)

        if attempts >= max_attempts do
          # Block this IP
          block_until = current_time + block_duration_minutes * 60
          set_block_status(client_ip, block_until)
          {:blocked, block_duration_minutes * 60}
        else
          :allowed
        end
    end
  end

  defp track_attempt(client_ip, window_minutes) do
    current_time = System.system_time(:second)

    # Store attempt timestamp
    attempts_key = "auth_attempts:#{client_ip}"

    # Get current attempts and filter out old ones
    current_attempts = get_attempts(attempts_key)
    window_start = current_time - window_minutes * 60

    filtered_attempts = Enum.filter(current_attempts, &(&1 > window_start))
    new_attempts = [current_time | filtered_attempts]

    # Store updated attempts
    set_attempts(attempts_key, new_attempts, window_minutes * 60)
  end

  defp count_recent_attempts(client_ip, window_start) do
    attempts_key = "auth_attempts:#{client_ip}"
    attempts = get_attempts(attempts_key)

    Enum.count(attempts, &(&1 > window_start))
  end

  defp get_block_status(client_ip, current_time) do
    block_key = "auth_block:#{client_ip}"

    case get_cache_value(block_key) do
      nil ->
        :not_blocked

      block_until when is_integer(block_until) ->
        if current_time < block_until do
          {:blocked, block_until}
        else
          # Block expired, clean up
          delete_cache_value(block_key)
          :not_blocked
        end

      _ ->
        :not_blocked
    end
  end

  defp set_block_status(client_ip, block_until) do
    block_key = "auth_block:#{client_ip}"
    ttl = block_until - System.system_time(:second)
    set_cache_value(block_key, block_until, ttl)
  end

  defp get_attempts(key) do
    case get_cache_value(key) do
      nil -> []
      attempts when is_list(attempts) -> attempts
      _ -> []
    end
  end

  defp set_attempts(key, attempts, ttl) do
    set_cache_value(key, attempts, ttl)
  end

  # Cache operations using ETS or a simple GenServer-based cache
  # For now, we'll use a simple ETS table approach

  defp get_cache_value(key) do
    case :ets.lookup(:auth_rate_limiter_cache, key) do
      [{^key, value, expires_at}] ->
        if System.system_time(:second) < expires_at do
          value
        else
          :ets.delete(:auth_rate_limiter_cache, key)
          nil
        end

      [] ->
        nil
    end
  rescue
    ArgumentError ->
      # Table doesn't exist, create it
      ensure_cache_table()
      nil
  end

  defp set_cache_value(key, value, ttl) do
    ensure_cache_table()
    expires_at = System.system_time(:second) + ttl
    :ets.insert(:auth_rate_limiter_cache, {key, value, expires_at})
  end

  defp delete_cache_value(key) do
    :ets.delete(:auth_rate_limiter_cache, key)
  rescue
    ArgumentError ->
      # Table doesn't exist, that's fine
      :ok
  end

  defp ensure_cache_table do
    case :ets.whereis(:auth_rate_limiter_cache) do
      :undefined ->
        :ets.new(:auth_rate_limiter_cache, [
          :named_table,
          :public,
          :set,
          {:read_concurrency, true},
          {:write_concurrency, true}
        ])

      _ ->
        :ok
    end
  rescue
    ArgumentError ->
      # Table might already exist due to race condition
      :ok
  end
end
