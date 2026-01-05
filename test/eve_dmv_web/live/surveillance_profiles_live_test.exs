defmodule EveDmvWeb.SurveillanceProfilesLiveTest do
  @moduledoc """
  Tests for SurveillanceProfilesLive LiveView component.
  Tests profile management and filter functionality.
  """
  use EveDmvWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import EveDmv.Factories

  alias Ecto.Adapters.SQL.Sandbox

  setup do
    Sandbox.mode(EveDmv.Repo, {:shared, self()})

    # Create test killmails for preview functionality
    create_test_killmails(5)

    # Use authenticated connection with a simple session setup
    conn = authenticated_user_conn(character_id: 90_000_001)

    {:ok, conn: conn}
  end

  describe "mount/3" do
    test "renders surveillance profiles page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/surveillance-profiles")

      assert html =~ "Surveillance" or html =~ "Profile"
    end

    test "view process stays alive", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/surveillance-profiles")

      assert Process.alive?(view.pid)
    end
  end

  describe "handle_params/3" do
    test "handles new action parameter", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/surveillance-profiles?action=new")

      # Should not crash
      assert Process.alive?(view.pid)
    end

    test "handles edit action with missing id", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/surveillance-profiles?action=edit&id=nonexistent")

      # Should handle gracefully
      assert Process.alive?(view.pid)
    end
  end

  describe "handle_info callbacks" do
    test "handles profile_updated message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/surveillance-profiles")

      send(view.pid, {:profile_updated, %{id: "test", name: "Updated Profile"}})

      :timer.sleep(100)

      assert Process.alive?(view.pid)
    end

    test "handles chain_topology_update message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/surveillance-profiles")

      send(view.pid, {:chain_topology_update, "default", %{}})

      :timer.sleep(100)

      assert Process.alive?(view.pid)
    end
  end

  describe "error handling" do
    test "page renders without external services", %{conn: conn} do
      # Tests that the page can render even when external services aren't running
      {:ok, view, _html} = live(conn, ~p"/surveillance-profiles")

      assert Process.alive?(view.pid)
    end
  end

  # Helper functions

  defp create_test_killmails(count) do
    for _ <- 1..count do
      insert_killmail_raw!(%{
        solar_system_id: 30_000_142,
        total_value: Decimal.new(Enum.random(1_000_000..100_000_000))
      })
    end
  end
end
