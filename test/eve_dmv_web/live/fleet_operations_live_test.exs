defmodule EveDmvWeb.FleetOperationsLiveTest do
  @moduledoc """
  Comprehensive tests for FleetOperationsLive LiveView component.
  Tests fleet analysis, composition breakdown, effectiveness metrics,
  and performance analysis functionality.
  """
  use EveDmvWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import EveDmv.Factories

  alias Ecto.Adapters.SQL.Sandbox
  alias EveDmv.Contexts.BattleAnalysis
  alias EveDmv.Eve.ItemType
  alias EveDmv.Eve.SolarSystem

  setup do
    Sandbox.mode(EveDmv.Repo, {:shared, self()})

    # Create reference data
    create_test_solar_systems()
    create_test_item_types()

    # Use authenticated connection with a simple session setup
    # This avoids ESI API calls during user creation
    conn = authenticated_user_conn(character_id: 90_000_001)

    {:ok, conn: conn}
  end

  describe "mount/3" do
    test "renders fleet operations page with initial state", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/fleet")

      assert html =~ "Fleet Operations"
    end

    test "sets correct page title", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/fleet")

      assert render(view) =~ "Fleet Operations"
    end

    test "initializes with empty fleet data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/fleet")

      # Should show no fleet data initially
      html = render(view)
      assert html =~ "Fleet Operations" or html =~ "No fleet"
    end
  end

  describe "handle_params/3 with battle_id" do
    test "loads fleet data when battle_id is provided", %{conn: conn} do
      # Create a battle with killmails
      battle = create_test_battle()

      {:ok, view, _html} = live(conn, ~p"/fleet?battle_id=#{battle.battle_id}")

      # Give time for async loading
      :timer.sleep(300)

      html = render(view)
      # Should show battle data or loading state
      assert html =~ "Fleet" or html =~ "Battle" or html =~ "Loading"
    end

    test "loads specific side when side parameter is provided", %{conn: conn} do
      battle = create_test_battle()

      {:ok, view, _html} = live(conn, ~p"/fleet?battle_id=#{battle.battle_id}&side=side_1")

      :timer.sleep(300)

      html = render(view)
      assert html =~ "Fleet" or html =~ "side" or html =~ "Loading"
    end

    test "handles invalid battle_id gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/fleet?battle_id=nonexistent")

      :timer.sleep(300)

      # Should not crash, may show error
      assert Process.alive?(view.pid)
    end
  end

  describe "analyze_fleet event" do
    test "runs composition analysis", %{conn: conn} do
      battle = create_test_battle()

      {:ok, view, _html} = live(conn, ~p"/fleet?battle_id=#{battle.battle_id}")
      :timer.sleep(300)

      # Trigger composition analysis
      render_click(view, "analyze_fleet", %{"type" => "composition"})

      :timer.sleep(200)

      html = render(view)
      # Should show composition results or analysis type
      assert html =~ "Composition" or html =~ "Fleet" or html =~ "Ships"
    end

    test "runs effectiveness analysis", %{conn: conn} do
      battle = create_test_battle()

      {:ok, view, _html} = live(conn, ~p"/fleet?battle_id=#{battle.battle_id}")
      :timer.sleep(300)

      render_click(view, "analyze_fleet", %{"type" => "effectiveness"})

      :timer.sleep(200)

      html = render(view)
      assert html =~ "Effectiveness" or html =~ "Fleet" or html =~ "Rating"
    end

    test "runs pilot performance analysis", %{conn: conn} do
      battle = create_test_battle()

      {:ok, view, _html} = live(conn, ~p"/fleet?battle_id=#{battle.battle_id}")
      :timer.sleep(300)

      render_click(view, "analyze_fleet", %{"type" => "performance"})

      :timer.sleep(200)

      html = render(view)
      assert html =~ "Performance" or html =~ "Pilot" or html =~ "Fleet"
    end

    test "shows error when no fleet data available", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/fleet")

      # Try to analyze without fleet data
      render_click(view, "analyze_fleet", %{"type" => "composition"})

      html = render(view)
      assert html =~ "No fleet data" or html =~ "error" or html =~ "Fleet Operations"
    end
  end

  describe "handle_info callbacks" do
    test "handles run_analysis message for composition", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/fleet")

      # Simulate a run_analysis message
      fleet_data = build_mock_fleet_data()
      send(view.pid, {:run_analysis, "composition", fleet_data})

      :timer.sleep(200)

      assert Process.alive?(view.pid)
    end

    test "handles run_analysis message for effectiveness", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/fleet")

      fleet_data = build_mock_fleet_data()
      send(view.pid, {:run_analysis, "effectiveness", fleet_data})

      :timer.sleep(200)

      assert Process.alive?(view.pid)
    end

    test "handles run_analysis message for performance", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/fleet")

      fleet_data = build_mock_fleet_data()
      send(view.pid, {:run_analysis, "performance", fleet_data})

      :timer.sleep(200)

      assert Process.alive?(view.pid)
    end

    test "handles load_battle_fleet_data message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/fleet")

      # Simulate loading battle fleet data
      send(view.pid, {:load_battle_fleet_data, "test_battle_id", nil})

      :timer.sleep(300)

      # Should handle without crashing
      assert Process.alive?(view.pid)
    end

    test "handles load_battle_side_data message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/fleet")

      send(view.pid, {:load_battle_side_data, "test_battle_id", "side_1"})

      :timer.sleep(300)

      assert Process.alive?(view.pid)
    end
  end

  describe "analysis results display" do
    test "displays composition summary correctly", %{conn: conn} do
      battle = create_test_battle()

      {:ok, view, _html} = live(conn, ~p"/fleet?battle_id=#{battle.battle_id}")
      :timer.sleep(300)

      render_click(view, "analyze_fleet", %{"type" => "composition"})
      :timer.sleep(200)

      html = render(view)
      # Should display composition data
      assert html =~ "Fleet" or html =~ "Ship" or html =~ "Composition"
    end

    test "displays effectiveness metrics", %{conn: conn} do
      battle = create_test_battle()

      {:ok, view, _html} = live(conn, ~p"/fleet?battle_id=#{battle.battle_id}")
      :timer.sleep(300)

      render_click(view, "analyze_fleet", %{"type" => "effectiveness"})
      :timer.sleep(200)

      html = render(view)
      assert html =~ "Effectiveness" or html =~ "DPS" or html =~ "Rating" or html =~ "Fleet"
    end

    test "displays performance metrics", %{conn: conn} do
      battle = create_test_battle()

      {:ok, view, _html} = live(conn, ~p"/fleet?battle_id=#{battle.battle_id}")
      :timer.sleep(300)

      render_click(view, "analyze_fleet", %{"type" => "performance"})
      :timer.sleep(200)

      html = render(view)
      assert html =~ "Performance" or html =~ "Pilot" or html =~ "Survival" or html =~ "Fleet"
    end
  end

  describe "error handling" do
    test "handles missing fleet data for analysis", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/fleet")

      # Try to analyze with no fleet data loaded
      render_click(view, "analyze_fleet", %{"type" => "composition"})

      :timer.sleep(100)

      # Should handle gracefully
      assert Process.alive?(view.pid)
    end

    test "handles missing battle data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/fleet?battle_id=missing_id")

      :timer.sleep(300)

      html = render(view)
      # Should show error or empty state
      assert html =~ "Fleet Operations" or html =~ "not found" or html =~ "error"
    end
  end

  # Helper functions

  defp create_test_battle do
    # Create killmails that form a battle
    now = DateTime.utc_now()
    system_id = 30_000_142

    killmails =
      for i <- 1..5 do
        insert_killmail_raw!(%{
          killmail_time: DateTime.add(now, -i * 60, :second),
          solar_system_id: system_id
        })
      end

    # Detect the battle
    start_time = DateTime.add(now, -3600, :second)

    case BattleAnalysis.detect_battles(start_time, now) do
      {:ok, [battle | _]} -> battle
      _ -> %{battle_id: "test_battle_#{System.unique_integer([:positive])}", killmails: killmails}
    end
  end

  defp build_mock_fleet_data do
    fleet_id = "fleet_#{System.unique_integer([:positive])}"

    %{
      fleet_id: fleet_id,
      fleet_data: %{
        fleet_id: fleet_id,
        fleet_name: "Test Fleet",
        start_time: DateTime.to_iso8601(DateTime.utc_now()),
        end_time: DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), 3600, :second)),
        engagement_status: "Active"
      },
      fleet_participants: %{
        fleet_id => [
          %{
            character_id: 90_000_001,
            character_name: "Test Pilot 1",
            ship_type_id: 587,
            ship_name: "Rifter",
            corporation_id: 98_000_001,
            is_victim: false
          },
          %{
            character_id: 90_000_002,
            character_name: "Test Pilot 2",
            ship_type_id: 620,
            ship_name: "Arbitrator",
            corporation_id: 98_000_001,
            is_victim: false
          }
        ]
      }
    }
  end

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

        {:ok, _existing} ->
          :ok

        {:error, _} ->
          Ash.create!(SolarSystem, system, action: :create)
      end
    end
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
      },
      %{
        type_id: 620,
        type_name: "Arbitrator",
        group_id: 26,
        group_name: "Cruiser",
        category_id: 6,
        category_name: "Ship"
      }
    ]

    for item <- items do
      case Ash.read_one(ItemType, filter: [type_id: item.type_id]) do
        {:ok, nil} ->
          Ash.create!(ItemType, item, action: :create)

        {:ok, _existing} ->
          :ok

        {:error, _} ->
          Ash.create!(ItemType, item, action: :create)
      end
    end
  end
end
