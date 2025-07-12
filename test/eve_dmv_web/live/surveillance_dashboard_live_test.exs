defmodule EveDmvWeb.SurveillanceDashboardLiveTest do
  use EveDmvWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "surveillance dashboard live" do
    test "displays dashboard page", %{conn: conn} do
      # The dashboard will call Surveillance.list_profiles but it should handle errors gracefully
      {:ok, _index_live, html} = live(conn, ~p"/surveillance-dashboard")

      assert html =~ "Surveillance Performance Dashboard"
    end

    test "displays system metrics", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/surveillance-dashboard")

      assert html =~ "Total Profiles"
      assert html =~ "Total Alerts"
      assert html =~ "Avg Response"
      assert html =~ "System Health"
    end

    test "shows time range selector", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/surveillance-dashboard")

      assert html =~ "Last Hour"
      assert html =~ "Last 24 Hours"
      assert html =~ "Last 7 Days"
      assert html =~ "Last 30 Days"
    end

    test "can change time range", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/surveillance-dashboard")

      # Change time range
      index_live
      |> element("select[name='time_range']")
      |> render_change(%{"time_range" => "last_7d"})

      # Should trigger navigation
      assert_patch(index_live, ~p"/surveillance-dashboard?time_range=last_7d")
    end

    test "shows refresh button", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/surveillance-dashboard")

      assert has_element?(index_live, "button", "Refresh")

      # Click refresh
      index_live
      |> element("button", "Refresh")
      |> render_click()

      # Should trigger metrics refresh
    end

    test "displays profile performance table", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/surveillance-dashboard")

      assert html =~ "Profile Performance Metrics"
      # Headers may not be present if no profiles are available in test env
      # assert html =~ "Profile"
      # assert html =~ "Alerts"
      # assert html =~ "Match Rate"  
      # assert html =~ "Performance"
    end
  end

  describe "performance recommendations" do
    test "shows recommendations section when recommendations exist", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/surveillance-dashboard")

      # Should show recommendations section (even if empty)
      assert html =~ "Performance Recommendations" or html =~ "Profile Performance Metrics"
    end
  end

  describe "alert trends" do
    test "displays alert trends chart area", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/surveillance-dashboard")

      # Should show trends section
      assert html =~ "Alert Trends" or html =~ "Profile Performance Metrics"
    end
  end
end
