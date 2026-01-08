defmodule EveDmvWeb.BattleAnalysisLiveTest do
  @moduledoc """
  Tests for BattleAnalysisLive LiveView component.
  Tests battle analysis, timeline, and fleet composition functionality.
  """
  use EveDmvWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL.Sandbox
  alias EveDmv.Eve.ItemType
  alias EveDmv.Eve.SolarSystem

  setup do
    Sandbox.mode(EveDmv.Repo, {:shared, self()})

    # Ensure ETS table for fitting cache exists
    ensure_ets_table_exists()

    # Create reference data
    create_test_solar_systems()
    create_test_item_types()

    # Use authenticated connection
    conn = authenticated_user_conn(character_id: 90_000_001)

    {:ok, conn: conn}
  end

  describe "mount/3" do
    test "renders battle analysis page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/battle")

      assert html =~ "Battle"
    end

    test "view process stays alive", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/battle")

      assert Process.alive?(view.pid)
    end
  end

  describe "handle_params/3" do
    test "handles battle_id parameter", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/battle/test_battle_123")

      :timer.sleep(200)

      assert Process.alive?(view.pid)
    end

    test "handles missing battle gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/battle/nonexistent_battle")

      :timer.sleep(200)

      assert Process.alive?(view.pid)
    end
  end

  describe "view switching" do
    test "change_main_view event is handled", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/battle")

      render_click(view, "change_main_view", %{"view" => "timeline"})

      assert Process.alive?(view.pid)
    end

    test "change_timeline_view event is handled", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/battle")

      render_click(view, "change_timeline_view", %{"view" => "phases"})

      assert Process.alive?(view.pid)
    end
  end

  describe "fleet editing" do
    test "toggle_fleet_edit_mode event is handled", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/battle")

      render_click(view, "toggle_fleet_edit_mode")

      assert Process.alive?(view.pid)
    end

    test "add_custom_side event is handled", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/battle")

      render_click(view, "add_custom_side")

      assert Process.alive?(view.pid)
    end

    test "reset_fleet_sides event is handled", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/battle")

      render_click(view, "reset_fleet_sides")

      assert Process.alive?(view.pid)
    end
  end

  describe "handle_info callbacks" do
    test "handles import_complete error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/battle")

      send(view.pid, {:import_complete, {:error, :invalid_url}})

      :timer.sleep(100)

      assert Process.alive?(view.pid)
    end

    test "handles combat_log_parsed message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/battle")

      log = %{id: "log_1", pilot_name: "Test", parsed_data: %{}, parse_status: :completed}
      send(view.pid, {:combat_log_parsed, log})

      :timer.sleep(100)

      assert Process.alive?(view.pid)
    end

    test "handles hide_dropdown message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/battle")

      send(view.pid, {:hide_dropdown, "test_component"})

      :timer.sleep(100)

      assert Process.alive?(view.pid)
    end
  end

  describe "helper functions" do
    test "format_timestamp handles datetime" do
      alias EveDmvWeb.BattleAnalysisLive

      timestamp = ~U[2024-01-15 14:30:00Z]
      result = BattleAnalysisLive.format_timestamp(timestamp)

      assert result =~ "14:30:00"
    end

    test "format_timestamp handles nil" do
      alias EveDmvWeb.BattleAnalysisLive

      assert BattleAnalysisLive.format_timestamp(nil) == ""
    end

    test "format_duration formats minutes" do
      alias EveDmvWeb.BattleAnalysisLive

      assert BattleAnalysisLive.format_duration(0) == "<1m"
      assert BattleAnalysisLive.format_duration(5) == "5m"
      assert BattleAnalysisLive.format_duration(65) == "1h 5m"
    end

    test "phase_class returns CSS class" do
      alias EveDmvWeb.BattleAnalysisLive

      assert BattleAnalysisLive.phase_class(:initial_engagement) == "bg-red-900"
      assert BattleAnalysisLive.phase_class(:escalation) == "bg-orange-900"
      assert BattleAnalysisLive.phase_class(:cleanup) == "bg-gray-800"
    end
  end

  # Helper functions

  defp ensure_ets_table_exists do
    case :ets.info(:battle_fitting_cache) do
      :undefined ->
        :ets.new(:battle_fitting_cache, [:set, :public, :named_table])

      _ ->
        :ok
    end
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
