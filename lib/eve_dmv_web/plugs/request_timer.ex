defmodule EveDmvWeb.Plugs.RequestTimer do
  @moduledoc """
  Simple request timing plug that logs slow requests and adds timing headers.
  """

  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    start_time = System.monotonic_time()

    register_before_send(conn, fn conn ->
      duration = System.monotonic_time() - start_time
      duration_ms = duration / 1_000_000

      # Log slow requests (over 500ms)
      if duration_ms > 500 do
        Logger.warning("""
        Slow request: #{conn.method} #{conn.request_path} took #{round(duration_ms)}ms
        Query params: #{inspect(conn.query_params)}
        """)
      end

      # Add response time header for monitoring
      put_resp_header(conn, "x-response-time", "#{round(duration_ms)}ms")
    end)
  end
end
