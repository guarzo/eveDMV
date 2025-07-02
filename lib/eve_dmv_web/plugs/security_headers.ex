defmodule EveDmvWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Plug to add Content Security Policy and other security headers to HTTP responses.

  This plug sets comprehensive security headers including CSP to protect against
  XSS attacks, clickjacking, and other common web vulnerabilities.
  """

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> Plug.Conn.put_resp_header("content-security-policy", csp_header())
    |> Plug.Conn.put_resp_header("permissions-policy", permissions_policy())
  end

  defp csp_header do
    # Content Security Policy tailored for Phoenix LiveView applications
    """
    default-src 'self';
    script-src 'self' 'unsafe-inline' 'unsafe-eval';
    style-src 'self' 'unsafe-inline';
    img-src 'self' data: https: blob:;
    font-src 'self' data:;
    connect-src 'self' wss: ws: https:;
    media-src 'none';
    object-src 'none';
    frame-ancestors 'none';
    base-uri 'self';
    form-action 'self';
    upgrade-insecure-requests;
    """
    |> String.replace("\n", " ")
    |> String.trim()
  end

  defp permissions_policy do
    # Restrict access to browser features
    """
    accelerometer=(),
    camera=(),
    geolocation=(),
    gyroscope=(),
    magnetometer=(),
    microphone=(),
    payment=(),
    usb=()
    """
    |> String.replace("\n", " ")
    |> String.trim()
  end
end