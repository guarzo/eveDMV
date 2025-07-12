defmodule EveDmvWeb.SurveillanceAlertsLiveTest do
  use EveDmvWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "surveillance alerts live" do
    test "displays alerts page", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/surveillance-alerts")

      assert html =~ "Surveillance Alerts"
    end

    test "displays alert metrics", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/surveillance-alerts")

      assert html =~ "Total Alerts"
      assert html =~ "New Alerts"
      assert html =~ "Acknowledged"
      assert html =~ "Resolved"
    end

    test "shows alert filters", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/surveillance-alerts")

      assert html =~ "Priority"
      assert html =~ "State"
      assert html =~ "Time Range"
    end

    test "can toggle sound settings", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/surveillance-alerts")

      # Should show sound toggle
      assert has_element?(index_live, "button", "Sound On")

      # Click to toggle
      index_live
      |> element("button", "Sound On")
      |> render_click()

      # Should show sound off
      assert has_element?(index_live, "button", "Sound Off")
    end

    test "can filter alerts by priority", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/surveillance-alerts")

      # Change priority filter
      index_live
      |> element("select[name='filter[priority]']")
      |> render_change(%{"filter" => %{"priority" => "1"}})

      # Should trigger alert filtering
      assert has_element?(index_live, "option[value='1'][selected]")
    end

    test "can filter alerts by state", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/surveillance-alerts")

      # Change state filter
      index_live
      |> element("select[name='filter[state]']")
      |> render_change(%{"filter" => %{"state" => "new"}})

      # Should trigger alert filtering
      assert has_element?(index_live, "option[value='new'][selected]")
    end

    test "shows bulk acknowledge button", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/surveillance-alerts")

      assert html =~ "Acknowledge All"
    end
  end

  describe "alert display" do
    test "shows no alerts message when no alerts present", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/surveillance-alerts")

      assert html =~ "No alerts found"
    end
  end
end
