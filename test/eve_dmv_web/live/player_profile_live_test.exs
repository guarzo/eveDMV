defmodule EveDmvWeb.PlayerProfileLiveTest do
  @moduledoc """
  Tests for PlayerProfileLive LiveView component.
  """
  use EveDmvWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL.Sandbox
  alias EveDmv.Eve.ItemType
  alias EveDmv.Eve.SolarSystem

  setup do
    Sandbox.mode(EveDmv.Repo, {:shared, self()})

    # Create reference data
    create_test_solar_systems()
    create_test_item_types()

    # Use authenticated connection
    conn = authenticated_user_conn(character_id: 90_000_001)

    {:ok, conn: conn}
  end

  describe "mount/3" do
    test "renders player profile page for valid character_id", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/player/90000001")

      assert html =~ "Loading" or html =~ "character" or html =~ "Profile"
      assert Process.alive?(view.pid)
    end
  end

  describe "handle_info - character loading" do
    test "handles character_esi_loaded message with no killmails", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/player/90000001")

      character_info = %{
        character_id: 90_000_001,
        character_name: "Test Character",
        corporation_id: 98_000_001
      }

      # Use killmail_count: 0 to test the "no data" path
      # (avoids triggering PlayerAnalyzer which isn't started in tests)
      send(view.pid, {:character_esi_loaded, character_info, 0})

      :timer.sleep(200)

      # View should remain alive and show the no-data state
      assert Process.alive?(view.pid)
      html = render(view)
      assert html =~ "No Statistics" or html =~ "Generate" or html =~ "Profile"
    end

    test "handles character_load_failed message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/player/90000001")

      send(view.pid, {:character_load_failed, :character_not_found})

      :timer.sleep(100)

      assert Process.alive?(view.pid)
    end
  end

  # Helper functions

  defp create_test_solar_systems do
    systems = [
      %{
        system_id: 30_000_142,
        system_name: "Jita",
        region_id: 10_000_002,
        region_name: "The Forge",
        constellation_id: 20_000_020,
        constellation_name: "Kimotoro",
        security_status: 1.0,
        security_class: "highsec"
      }
    ]

    for system <- systems do
      case Ash.read_one(SolarSystem, filter: [system_id: system.system_id]) do
        {:ok, nil} ->
          Ash.create!(SolarSystem, system, action: :create)

        _ ->
          :ok
      end
    end
  rescue
    _ -> :ok
  end

  defp create_test_item_types do
    items = [
      %{
        type_id: 587,
        type_name: "Rifter",
        group_id: 25,
        group_name: "Frigate",
        category_id: 6,
        category_name: "Ship"
      }
    ]

    for item <- items do
      case Ash.read_one(ItemType, filter: [type_id: item.type_id]) do
        {:ok, nil} ->
          Ash.create!(ItemType, item, action: :create)

        _ ->
          :ok
      end
    end
  rescue
    _ -> :ok
  end
end
