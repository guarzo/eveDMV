defmodule EveDmvWeb.Plugs.SimpleRateLimit do
  @moduledoc """
  Simple rate limiting plug using Hammer

  This provides basic protection against abuse without being overly complex.
  Good enough for a small user base.
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, opts) do
    key = get_rate_limit_key(conn)
    # Default: 100 requests per minute
    limit = Keyword.get(opts, :limit, 100)
    # Default: 1 minute window
    window = Keyword.get(opts, :window, 60_000)

    case Hammer.check_rate(key, window, limit) do
      {:allow, count} ->
        conn
        |> put_resp_header("x-ratelimit-limit", "#{limit}")
        |> put_resp_header("x-ratelimit-remaining", "#{limit - count}")

      {:deny, _limit} ->
        Logger.warning("Rate limit exceeded for #{key}")

        conn
        |> put_status(:too_many_requests)
        |> put_resp_header("retry-after", "60")
        |> put_resp_header("x-ratelimit-limit", "#{limit}")
        |> put_resp_header("x-ratelimit-remaining", "0")
        |> json(%{
          error: "Too many requests. Please try again later.",
          retry_after: 60
        })
        |> halt()
    end
  end

  defp get_rate_limit_key(conn) do
    # Use IP address for rate limiting
    # This is simple but effective for small user bases
    ip = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    "rate_limit:#{ip}"
  end

  defp json(conn, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(conn.status || 200, Jason.encode!(data))
  end
end
