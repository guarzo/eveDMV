defmodule EveDmvWeb.Plugs.CacheControlTest do
  @moduledoc """
  Tests for the CacheControl plug.

  Verifies that Cache-Control headers are correctly set based on cache type.
  """
  use EveDmvWeb.ConnCase, async: true

  alias EveDmvWeb.Plugs.CacheControl

  describe "init/1" do
    test "returns the cache type unchanged" do
      assert CacheControl.init(:static) == :static
      assert CacheControl.init(:semi_static) == :semi_static
      assert CacheControl.init(:dynamic) == :dynamic
      assert CacheControl.init(:realtime) == :realtime
    end
  end

  describe "call/2 with :static cache type" do
    test "sets public, max-age=86400, stale-while-revalidate=3600", %{conn: conn} do
      conn = CacheControl.call(conn, :static)

      cache_control = get_resp_header(conn, "cache-control") |> List.first()
      assert cache_control =~ "public"
      assert cache_control =~ "max-age=86400"
      assert cache_control =~ "stale-while-revalidate=3600"
    end
  end

  describe "call/2 with :semi_static cache type" do
    test "sets public, max-age=3600, stale-while-revalidate=300", %{conn: conn} do
      conn = CacheControl.call(conn, :semi_static)

      cache_control = get_resp_header(conn, "cache-control") |> List.first()
      assert cache_control =~ "public"
      assert cache_control =~ "max-age=3600"
      assert cache_control =~ "stale-while-revalidate=300"
    end
  end

  describe "call/2 with :dynamic cache type" do
    test "sets private, max-age=60, must-revalidate", %{conn: conn} do
      conn = CacheControl.call(conn, :dynamic)

      cache_control = get_resp_header(conn, "cache-control") |> List.first()
      assert cache_control =~ "private"
      assert cache_control =~ "max-age=60"
      assert cache_control =~ "must-revalidate"
      refute cache_control =~ "public"
    end
  end

  describe "call/2 with :realtime cache type" do
    test "sets no-store, no-cache", %{conn: conn} do
      conn = CacheControl.call(conn, :realtime)

      cache_control = get_resp_header(conn, "cache-control") |> List.first()
      assert cache_control =~ "no-store"
      assert cache_control =~ "no-cache"
      refute cache_control =~ "max-age"
    end
  end

  describe "call/2 with unknown cache type" do
    test "defaults to realtime (no-store, no-cache)", %{conn: conn} do
      conn = CacheControl.call(conn, :unknown_type)

      cache_control = get_resp_header(conn, "cache-control") |> List.first()
      assert cache_control =~ "no-store"
      assert cache_control =~ "no-cache"
    end
  end
end
