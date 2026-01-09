defmodule EveDmvWeb.Plugs.ConditionalGet do
  @moduledoc """
  Handles conditional GET requests with ETag support.

  This plug registers a before_send callback that:
  1. Generates an ETag based on the response body content
  2. Compares it with the client's If-None-Match header
  3. Returns 304 Not Modified if they match, saving bandwidth

  ## Usage

  Add to a pipeline in the router:

      pipeline :cached_api do
        plug :accepts, ["json"]
        plug EveDmvWeb.Plugs.CacheControl, :semi_static
        plug EveDmvWeb.Plugs.ConditionalGet
      end

  ## How It Works

  When a request comes in:
  1. The plug registers a before_send callback
  2. When the response is about to be sent:
     - An ETag is generated from the MD5 hash of the response body
     - The ETag is added to the response headers
     - If the client sent an If-None-Match header matching the ETag,
       a 304 Not Modified response is returned instead

  """

  import Plug.Conn

  require Logger

  @doc """
  Initializes the plug.
  """
  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @doc """
  Registers a before_send callback to handle ETag generation and validation.
  """
  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    register_before_send(conn, &process_etag/1)
  end

  defp process_etag(conn) do
    # Only process successful responses with a body
    if conn.status in 200..299 && has_response_body?(conn) do
      etag = generate_etag(conn)
      conn = put_resp_header(conn, "etag", etag)

      if_none_match = get_req_header(conn, "if-none-match") |> List.first()

      if matches_etag?(if_none_match, etag) do
        resp(conn, 304, "")
      else
        conn
      end
    else
      conn
    end
  end

  defp has_response_body?(conn) do
    case conn.resp_body do
      nil -> false
      "" -> false
      [] -> false
      _ -> true
    end
  end

  defp generate_etag(conn) do
    body =
      case conn.resp_body do
        body when is_binary(body) ->
          body

        body when is_list(body) ->
          IO.iodata_to_binary(body)

        unexpected ->
          Logger.debug("Unexpected resp_body type in generate_etag: #{inspect(unexpected)}")
          ""
      end

    hash = :crypto.hash(:md5, body) |> Base.encode16(case: :lower)
    "\"#{hash}\""
  end

  defp matches_etag?(nil, _etag), do: false
  defp matches_etag?("*", _etag), do: true

  defp matches_etag?(if_none_match, etag) do
    # Handle comma-separated list of ETags
    if_none_match
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.any?(fn client_etag ->
      # Handle weak ETags (W/"...")
      normalize_etag(client_etag) == normalize_etag(etag)
    end)
  end

  defp normalize_etag(etag) do
    etag
    |> String.trim()
    |> String.replace_leading("W/", "")
  end
end
