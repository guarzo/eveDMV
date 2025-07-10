# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmvWeb.Endpoint do
  @moduledoc """
  Phoenix endpoint for the EVE DMV web application.

  Handles HTTP requests, WebSocket connections, and static file serving
  for the EVE Online PvP data tracking application.
  """

  use Phoenix.Endpoint, otp_app: :eve_dmv

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_eve_dmv_key",
    signing_salt: "fTSiD2Eh",
    same_site: "Lax",
    secure: true,
    http_only: true,
    # 24 hours
    max_age: 24 * 60 * 60
  ]

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]
  )

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug(Plug.Static,
    at: "/",
    from: :eve_dmv,
    gzip: false,
    only: EveDmvWeb.static_paths(),
    headers: %{
      "strict-transport-security" => "max-age=31_536_000; includeSubDomains",
      "x-frame-options" => "DENY",
      "x-content-type-options" => "nosniff",
      "x-xss-protection" => "1; mode=block",
      "referrer-policy" => "strict-origin-when-cross-origin"
    }
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
    plug(Phoenix.Ecto.CheckRepoStatus, otp_app: :eve_dmv)
  end

  plug(Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"
  )

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(EveDmvWeb.Router)
end
