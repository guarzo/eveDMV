defmodule EveDmvWeb.Plugs.ConditionalGetTest do
  @moduledoc """
  Tests for the ConditionalGet plug.

  Verifies ETag generation and conditional request handling.
  """
  use EveDmvWeb.ConnCase, async: true

  alias EveDmvWeb.Plugs.ConditionalGet

  describe "init/1" do
    test "returns options unchanged" do
      opts = [some: :option]
      assert ConditionalGet.init(opts) == opts
    end
  end

  describe "call/2" do
    test "registers a before_send callback", %{conn: conn} do
      conn = ConditionalGet.call(conn, [])

      # Verify that the plug doesn't immediately modify the connection
      assert conn.state == :unset
    end
  end

  describe "ETag generation" do
    test "adds ETag header to successful responses", %{conn: conn} do
      conn =
        conn
        |> ConditionalGet.call([])
        |> resp(200, ~s({"data": "test"}))
        |> send_resp()

      etag = get_resp_header(conn, "etag") |> List.first()
      assert etag != nil
      assert String.starts_with?(etag, "\"")
      assert String.ends_with?(etag, "\"")
    end

    test "generates different ETags for different content", %{conn: conn} do
      conn1 =
        conn
        |> ConditionalGet.call([])
        |> resp(200, ~s({"data": "test1"}))
        |> send_resp()

      conn2 =
        build_conn()
        |> ConditionalGet.call([])
        |> resp(200, ~s({"data": "test2"}))
        |> send_resp()

      etag1 = get_resp_header(conn1, "etag") |> List.first()
      etag2 = get_resp_header(conn2, "etag") |> List.first()

      assert etag1 != etag2
    end

    test "generates same ETag for identical content", %{conn: conn} do
      content = ~s({"data": "identical"})

      conn1 =
        conn
        |> ConditionalGet.call([])
        |> resp(200, content)
        |> send_resp()

      conn2 =
        build_conn()
        |> ConditionalGet.call([])
        |> resp(200, content)
        |> send_resp()

      etag1 = get_resp_header(conn1, "etag") |> List.first()
      etag2 = get_resp_header(conn2, "etag") |> List.first()

      assert etag1 == etag2
    end
  end

  describe "conditional request handling" do
    test "returns 304 Not Modified when ETag matches If-None-Match", %{conn: conn} do
      content = ~s({"data": "test"})

      # First request to get the ETag
      conn1 =
        conn
        |> ConditionalGet.call([])
        |> resp(200, content)
        |> send_resp()

      etag = get_resp_header(conn1, "etag") |> List.first()

      # Second request with matching If-None-Match
      conn2 =
        build_conn()
        |> put_req_header("if-none-match", etag)
        |> ConditionalGet.call([])
        |> resp(200, content)
        |> send_resp()

      assert conn2.status == 304
      assert conn2.resp_body == ""
    end

    test "returns full response when ETag does not match If-None-Match", %{conn: conn} do
      content = ~s({"data": "test"})

      conn =
        conn
        |> put_req_header("if-none-match", "\"different-etag\"")
        |> ConditionalGet.call([])
        |> resp(200, content)
        |> send_resp()

      assert conn.status == 200
      assert conn.resp_body == content
    end

    test "handles wildcard If-None-Match (*)", %{conn: conn} do
      content = ~s({"data": "test"})

      conn =
        conn
        |> put_req_header("if-none-match", "*")
        |> ConditionalGet.call([])
        |> resp(200, content)
        |> send_resp()

      assert conn.status == 304
    end

    test "handles comma-separated If-None-Match values", %{conn: conn} do
      content = ~s({"data": "test"})

      # First request to get the ETag
      conn1 =
        conn
        |> ConditionalGet.call([])
        |> resp(200, content)
        |> send_resp()

      etag = get_resp_header(conn1, "etag") |> List.first()

      # Second request with multiple ETags
      conn2 =
        build_conn()
        |> put_req_header("if-none-match", "\"other-etag\", #{etag}, \"another-etag\"")
        |> ConditionalGet.call([])
        |> resp(200, content)
        |> send_resp()

      assert conn2.status == 304
    end

    test "handles weak ETags (W/...)", %{conn: conn} do
      content = ~s({"data": "test"})

      # First request to get the ETag
      conn1 =
        conn
        |> ConditionalGet.call([])
        |> resp(200, content)
        |> send_resp()

      etag = get_resp_header(conn1, "etag") |> List.first()

      # Second request with weak ETag prefix
      conn2 =
        build_conn()
        |> put_req_header("if-none-match", "W/#{etag}")
        |> ConditionalGet.call([])
        |> resp(200, content)
        |> send_resp()

      assert conn2.status == 304
    end
  end

  describe "non-cacheable responses" do
    test "does not add ETag to non-2xx responses", %{conn: conn} do
      conn =
        conn
        |> ConditionalGet.call([])
        |> resp(404, ~s({"error": "not found"}))
        |> send_resp()

      etag = get_resp_header(conn, "etag") |> List.first()
      assert etag == nil
    end

    test "does not add ETag to responses without body", %{conn: conn} do
      conn =
        conn
        |> ConditionalGet.call([])
        |> resp(204, "")
        |> send_resp()

      etag = get_resp_header(conn, "etag") |> List.first()
      assert etag == nil
    end
  end
end
