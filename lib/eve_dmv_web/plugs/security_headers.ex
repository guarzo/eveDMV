defmodule EveDmvWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Plug for adding security headers to HTTP responses.

  This plug adds Content Security Policy and other security-related headers
  to protect against common web vulnerabilities.
  """

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> Plug.Conn.put_resp_header("content-security-policy", csp_header())
  end

  defp csp_header do
    """
    default-src 'self';
    script-src 'self' 'unsafe-inline';
    style-src 'self' 'unsafe-inline';
    img-src 'self' data: https:;
    connect-src 'self' wss: https:;
    """
    |> String.replace("\n", " ")
    |> String.trim()
  end
end
