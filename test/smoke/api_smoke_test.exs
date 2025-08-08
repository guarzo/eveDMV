defmodule EveDmv.Smoke.ApiSmokeTest do
  use EveDmvWeb.ConnCase, async: true

  describe "API endpoints" do
    test "health check endpoint responds" do
      conn = get(build_conn(), "/health")
      assert response(conn, 200) == "ok"
    end

    test "root endpoint is accessible" do
      conn = get(build_conn(), "/")
      assert response(conn, 200) =~ "EVE DMV"
    end

    test "authentication endpoints are accessible" do
      conn = get(build_conn(), "/auth/eve")
      # Should redirect to EVE SSO
      assert response(conn, 302)
      assert get_resp_header(conn, "location") != []
    end

    test "kill feed endpoint is accessible" do
      conn = get(build_conn(), "/feed")
      # Should either redirect to auth or show the feed
      assert response(conn, 302) || response(conn, 200)
    end
  end

  describe "static data availability" do
    test "EVE item types are loaded" do
      import Ash.Query
      alias EveDmv.Api
      alias EveDmv.Eve.ItemType

      query = ItemType |> limit(1)
      {:ok, items} = Api.read(query)
      assert length(items) > 0, "No static data loaded"
    end

    test "solar systems are loaded" do
      import Ash.Query
      alias EveDmv.Api
      alias EveDmv.Eve.SolarSystem

      query = SolarSystem |> limit(1)
      {:ok, systems} = Api.read(query)
      assert length(systems) > 0, "No solar systems loaded"
    end
  end

  describe "Ash API functionality" do
    test "Api module is accessible" do
      assert Code.ensure_loaded?(EveDmv.Api)
    end

    test "can perform basic Ash queries" do
      alias EveDmv.Api
      alias EveDmv.Eve.ItemType
      import Ash.Query

      query = ItemType |> filter(is_ship == true) |> limit(5)
      result = Api.read(query)
      assert {:ok, _} = result
    end
  end
end
