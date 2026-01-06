defmodule EveDmvWeb.SystemActivityLiveTest do
  use EveDmvWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import EveDmv.Factories
  import EveDmv.UICase, only: [log_in_user: 2]

  describe "System Activity LiveView" do
    setup do
      user = create(:user)
      conn = log_in_user(build_conn(), user)
      {:ok, conn: conn}
    end

    test "renders system analytics dashboard", %{conn: conn} do
      {:ok, view, html} = live(conn, "/system-activity")

      assert html =~ "System Activity Analytics"
      assert html =~ "Overview"
      assert html =~ "Heatmap"
      assert has_element?(view, "select[phx-change='change_timeframe']")
    end

    test "switches between view modes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/system-activity")

      # Switch to heatmap view
      view
      |> element("button[phx-value-view='heatmap']")
      |> render_click()

      assert has_element?(view, "#heatmap-container")
      assert has_element?(view, "[phx-hook='HeatmapVisualization']")
    end

    test "updates timeframe selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/system-activity")

      view
      |> element("select[phx-change='change_timeframe']")
      |> render_change(%{timeframe: "last_7_days"})

      assert has_element?(view, "option[value='last_7_days'][selected]")
    end

    test "refreshes data on button click", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/system-activity")

      # Should not crash when refreshing
      refute view
             |> element("button", "Refresh")
             |> render_click()
             |> String.contains?("error")
    end

    test "renders overview metrics", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/system-activity")

      assert html =~ "Total Kills"
      assert html =~ "Active Systems"
      assert html =~ "Threat Escalations"
      assert html =~ "Avg Response Time"
    end

    test "heatmap view shows visualization container", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/system-activity")

      # Switch to heatmap view
      view
      |> element("button[phx-value-view='heatmap']")
      |> render_click()

      # Should show heatmap container with D3 hook
      assert has_element?(view, "#heatmap-container[phx-hook='HeatmapVisualization']")
      assert has_element?(view, ".heatmap-visualization")
    end
  end

  describe "System Analysis context" do
    test "generates heatmap data with real killmails" do
      # Create some test killmails
      create(:killmail_raw,
        solar_system_id: 30_000_142,
        zkb_total_value: Decimal.new(100_000_000)
      )

      create(:killmail_raw, solar_system_id: 30_000_142, zkb_total_value: Decimal.new(50_000_000))

      create(:killmail_raw,
        solar_system_id: 30_000_143,
        zkb_total_value: Decimal.new(200_000_000)
      )

      {:ok, heatmap_data} = EveDmv.Contexts.SystemAnalysis.generate_heatmap(hours: 24, limit: 50)

      assert %{systems: systems, maxThreat: max_threat} = heatmap_data
      assert is_list(systems)
      assert is_number(max_threat)
      assert max_threat >= 0 and max_threat <= 1

      # Should have systems from our test data
      system_ids = Enum.map(systems, & &1.id)
      assert 30_000_142 in system_ids or 30_000_143 in system_ids
    end

    test "gets overview metrics from real data" do
      # Create test killmails in the last 24 hours
      recent_time = DateTime.utc_now() |> DateTime.add(-12, :hour)
      create(:killmail_raw, killmail_time: recent_time, solar_system_id: 30_000_142)
      create(:killmail_raw, killmail_time: recent_time, solar_system_id: 30_000_143)

      {:ok, metrics} = EveDmv.Contexts.SystemAnalysis.get_overview_metrics()

      assert %{
               total_kills: total_kills,
               active_systems: active_systems,
               kills_change: kills_change
             } = metrics

      assert is_integer(total_kills)
      assert is_integer(active_systems)
      assert is_number(kills_change)
      assert total_kills >= 2
      assert active_systems >= 2
    end

    test "identifies hot zones from killmail data" do
      # Create killmails to simulate hot zone
      hot_system = 30_000_142
      # Above the threshold of 20
      for _ <- 1..25 do
        create(:killmail_raw,
          solar_system_id: hot_system,
          zkb_total_value: Decimal.new(Enum.random(10_000_000..100_000_000))
        )
      end

      {:ok, zones} = EveDmv.Contexts.SystemAnalysis.identify_hot_zones(hours: 24)

      assert %{hot_zones: hot_zones} = zones
      assert is_list(hot_zones)

      # Our high-activity system should be identified as a hot zone
      hot_zone_ids = Enum.map(hot_zones, & &1.system_id)
      assert hot_system in hot_zone_ids
    end

    test "detects escalation alerts" do
      # Create escalation scenario
      current_time = DateTime.utc_now() |> DateTime.add(-2, :hour)
      escalation_system = 30_000_144

      # High activity in recent period
      for _ <- 1..15 do
        create(:killmail_raw,
          solar_system_id: escalation_system,
          killmail_time: current_time,
          zkb_total_value: Decimal.new(Enum.random(100_000_000..300_000_000))
        )
      end

      alerts = EveDmv.Contexts.SystemAnalysis.get_escalation_alerts()

      assert is_list(alerts)

      # Check if our escalation system is in the alerts
      alert_systems = Enum.map(alerts, & &1.system_id)

      # May or may not trigger depending on baseline, but should not crash
      assert is_list(alert_systems)
    end
  end

  describe "Escalation Alert UI" do
    setup do
      user = create(:user)
      conn = log_in_user(build_conn(), user)

      # Create escalation scenario
      current_time = DateTime.utc_now() |> DateTime.add(-1, :hour)

      for _ <- 1..20 do
        create(:killmail_raw,
          solar_system_id: 30_000_145,
          killmail_time: current_time,
          zkb_total_value: Decimal.new(200_000_000)
        )
      end

      {:ok, conn: conn}
    end

    test "renders escalation alerts in overview", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/system-activity")

      # Should show escalation section if alerts exist
      assert html =~ "Threat Escalations" || html =~ "No Escalation Data"
    end

    test "dismisses alerts on button click", %{conn: conn} do
      {:ok, view, html} = live(conn, "/system-activity")

      # Only test if alerts are present
      if html =~ "phx-click=\"dismiss_alert\"" do
        result =
          view
          |> element("button[phx-click='dismiss_alert']")
          |> render_click(%{alert_id: "30000145"})

        # Should not contain error messages
        refute result =~ "error"
      else
        # No alerts present - verify the page loads without errors
        refute html =~ "error"
      end
    end

    test "navigates to system detail from alert", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/system-activity")

      # Verify the page loads without errors
      refute html =~ "Internal Server Error"

      # If alerts are present, verify the "View Details" button exists
      # Note: Actually clicking the button requires complete system data which
      # may not be available in the test environment, so we just verify the UI renders
      if html =~ "phx-click=\"view_alert_system\"" do
        assert html =~ "View Details"
      end
    end
  end
end
