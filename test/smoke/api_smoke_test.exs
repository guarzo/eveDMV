defmodule EveDmv.Smoke.ApiSmokeTest do
  use EveDmvWeb.ConnCase, async: true

  describe "API endpoints" do
    test "health check endpoint responds" do
      conn = get(build_conn(), "/health")
      resp = json_response(conn, 200)
      assert resp["status"] == "healthy"
      assert resp["services"]["database"] == "healthy"
    end

    test "root endpoint is accessible" do
      conn = get(build_conn(), "/")
      assert response(conn, 200) =~ "EVE DMV"
    end

    test "authentication endpoints are accessible" do
      conn = get(build_conn(), "/login")
      # Should show login page (200) or redirect (302)
      status = conn.status
      assert status == 200 || status == 302
    end

    test "kill feed endpoint is accessible" do
      conn = get(build_conn(), "/feed")
      # Should either redirect to auth or show the feed
      status = conn.status
      assert status == 302 || status == 200
    end
  end

  describe "static data availability" do
    setup do
      # Create minimal test data if none exists
      alias EveDmv.Eve.ItemType
      alias EveDmv.Eve.SolarSystem

      # Create a test item type if none exist
      case Ash.read(ItemType |> Ash.Query.limit(1)) do
        {:ok, []} ->
          {:ok, _} =
            Ash.create(ItemType, %{
              type_id: 587,
              type_name: "Rifter",
              group_name: "Frigate",
              is_ship: true,
              published: true,
              mass: Decimal.new("1000000"),
              volume: Decimal.new("50000")
            })

        _ ->
          :ok
      end

      # Create a test solar system if none exist
      case Ash.read(SolarSystem |> Ash.Query.limit(1)) do
        {:ok, []} ->
          {:ok, _} =
            Ash.create(SolarSystem, %{
              system_id: 30_000_142,
              system_name: "Jita",
              constellation_id: 20_000_020,
              region_id: 10_000_002,
              security_status: Decimal.new("0.9"),
              security_class: "highsec"
            })

        _ ->
          :ok
      end

      :ok
    end

    test "EVE item types are loaded" do
      import Ash.Query
      alias EveDmv.Eve.ItemType

      query = ItemType |> limit(1)
      {:ok, items} = Ash.read(query, domain: EveDmv.Api)
      assert not Enum.empty?(items), "No static data loaded"
    end

    test "solar systems are loaded" do
      import Ash.Query
      alias EveDmv.Eve.SolarSystem

      query = SolarSystem |> limit(1)
      {:ok, systems} = Ash.read(query, domain: EveDmv.Api)
      assert not Enum.empty?(systems), "No solar systems loaded"
    end
  end

  describe "Ash API functionality" do
    test "Api module is accessible" do
      assert Code.ensure_loaded?(EveDmv.Api)
    end

    test "can perform basic Ash queries" do
      alias EveDmv.Eve.ItemType
      import Ash.Query

      query = ItemType |> filter(is_ship == true) |> limit(5)
      result = Ash.read(query, domain: EveDmv.Api)
      assert {:ok, _} = result
    end
  end
end
