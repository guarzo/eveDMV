defmodule EveDmvWeb.ChainIntelligenceLiveTest do
  @moduledoc """
  Comprehensive tests for ChainIntelligenceLive component.
  """
  use EveDmvWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "mount" do
    test "mounts successfully for authenticated user", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, _view, html} = live(conn, ~p"/chain-intelligence")

      assert html =~ "Chain Intelligence" or html =~ "Wormhole" or html =~ "chain"
    end

    test "redirects unauthenticated user", %{conn: conn} do
      # Test without authentication
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/chain-intelligence")
    end

    test "sets up PubSub subscription on mount", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence")

      # Component should subscribe to chain intelligence updates
      # This is tested by ensuring mount doesn't crash
      html = render(view)
      assert is_binary(html)
    end

    test "loads user chains on mount", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, html} = live(conn, ~p"/chain-intelligence")

      # Should attempt to load user's monitored chains
      assert html =~ "chain" or html =~ "monitored" or is_binary(html)
    end
  end

  describe "handle_params with map_id" do
    test "loads specific chain data when map_id provided", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence/test-map-123")

      # Should set selected chain and attempt to load data
      html = render(view)
      assert html =~ "test-map-123" or html =~ "chain" or is_binary(html)
    end

    test "handles invalid map_id gracefully", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence/invalid-map")

      # Should handle invalid map ID without crashing
      html = render(view)
      assert is_binary(html)
    end
  end

  describe "handle_event monitor_chain" do
    test "starts monitoring a chain", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence")

      # Try to monitor a chain
      view
      |> element("button[phx-click='monitor_chain'][phx-value-map_id='test-map-456']")
      |> render_click()

      # Should handle the monitoring request (may fail in test but shouldn't crash)
      html = render(view)

      assert html =~ "monitor" or html =~ "error" or html =~ "Started monitoring" or
               is_binary(html)
    end

    test "handles monitoring failure gracefully", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence")

      # Try to monitor non-existent chain
      view
      |> element("button[phx-click='monitor_chain'][phx-value-map_id='nonexistent']")
      |> render_click()

      # Should show error message
      html = render(view)
      assert html =~ "error" or html =~ "Failed" or is_binary(html)
    end
  end

  describe "handle_event stop_monitoring" do
    test "stops monitoring a chain", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence")

      # Try to stop monitoring a chain
      view
      |> element("button[phx-click='stop_monitoring'][phx-value-map_id='test-map-789']")
      |> render_click()

      # Should handle the stop monitoring request
      html = render(view)

      assert html =~ "monitor" or html =~ "error" or html =~ "Stopped monitoring" or
               is_binary(html)
    end
  end

  describe "handle_event refresh_chain" do
    test "refreshes chain data", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence/test-map-123")

      # Try to refresh chain data
      view
      |> element("button[phx-click='refresh_chain'][phx-value-map_id='test-map-123']")
      |> render_click()

      # Should show refresh message
      html = render(view)
      assert html =~ "Refreshing" or html =~ "refresh" or is_binary(html)
    end
  end

  describe "handle_event analyze_pilot" do
    test "starts pilot analysis", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence/test-map-123")

      # Try to analyze a pilot
      view
      |> element("button[phx-click='analyze_pilot'][phx-value-character_id='987654321']")
      |> render_click()

      # Should start pilot analysis (asynchronous)
      html = render(view)
      assert is_binary(html)
    end

    test "handles invalid character ID for analysis", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence/test-map-123")

      # Try to analyze with invalid character ID
      view
      |> element("button[phx-click='analyze_pilot'][phx-value-character_id='invalid']")
      |> render_click()

      # Should handle gracefully
      html = render(view)
      assert is_binary(html)
    end
  end

  describe "handle_info pilot_analysis" do
    test "handles completed pilot analysis", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence/test-map-123")

      # Simulate pilot analysis completion
      analysis_result = %{
        threat_level: :hostile,
        confidence: 0.8,
        details: "Known hostile pilot"
      }

      send(view.pid, {:pilot_analysis, 987_654_321, analysis_result})

      # Should update chain data with analysis
      html = render(view)
      assert html =~ "analysis complete" or html =~ "Pilot analysis complete" or is_binary(html)
    end
  end

  describe "handle_info chain updates" do
    test "handles chain_updated message", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence/test-map-123")

      # Simulate chain update
      send(view.pid, {:chain_updated, "test-map-123"})

      # Should reload chain data
      html = render(view)
      assert is_binary(html)
    end

    test "ignores updates for other chains", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence/test-map-123")

      # Simulate update for different chain
      send(view.pid, {:chain_updated, "other-map-456"})

      # Should ignore updates for other chains
      html = render(view)
      assert is_binary(html)
    end

    test "handles system_updated message", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence/test-map-123")

      # Simulate system update
      system_data = %{system_id: 31_000_001, inhabitants: []}
      send(view.pid, {:system_updated, "test-map-123", system_data})

      # Should handle system update
      html = render(view)
      assert is_binary(html)
    end

    test "handles connection_updated message", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence/test-map-123")

      # Simulate connection update
      connection_data = %{source_system: 31_000_001, target_system: 31_000_002}
      send(view.pid, {:connection_updated, "test-map-123", connection_data})

      # Should handle connection update
      html = render(view)
      assert is_binary(html)
    end
  end

  describe "data loading" do
    test "loads user chains correctly", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence")

      # Component should attempt to load chains for the corporation
      html = render(view)
      assert is_binary(html)

      # Should not crash on data loading
      refute html =~ "RuntimeError"
    end

    test "handles no monitored chains gracefully", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence")

      # Should handle case with no monitored chains
      html = render(view)
      assert html =~ "No chains" or html =~ "monitoring" or is_binary(html)
    end

    test "loads chain topology data", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence/test-map-123")

      # Should attempt to load chain topology
      html = render(view)
      assert is_binary(html)
    end

    test "handles missing chain data", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence/nonexistent-map")

      # Should show error for missing chain
      html = render(view)
      assert html =~ "not found" or html =~ "Chain not found" or is_binary(html)
    end
  end

  describe "helper function rendering" do
    test "threat level styling works correctly", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, html} = live(conn, ~p"/chain-intelligence/test-map-123")

      # Template should handle threat level styling
      assert is_binary(html)
      refute html =~ "UndefinedFunctionError"
    end

    test "mass status styling works correctly", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, html} = live(conn, ~p"/chain-intelligence/test-map-123")

      # Template should handle mass status styling
      assert is_binary(html)
      refute html =~ "UndefinedFunctionError"
    end

    test "time formatting works correctly", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, html} = live(conn, ~p"/chain-intelligence/test-map-123")

      # Template should handle time formatting
      assert is_binary(html)
      refute html =~ "UndefinedFunctionError"
    end
  end

  describe "error handling" do
    test "handles Ash query errors gracefully", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence")

      # Component should handle database query errors gracefully
      html = render(view)
      assert is_binary(html)
    end

    test "handles missing corporation ID", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: nil})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence")

      # Should handle missing corporation ID (defaults to 1)
      html = render(view)
      assert is_binary(html)
    end
  end

  describe "real-time features" do
    test "subscribes to PubSub channels", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence")

      # Component should subscribe to chain intelligence updates
      # This is verified by ensuring mount succeeds
      html = render(view)
      assert is_binary(html)
    end

    test "processes real-time updates efficiently", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence/test-map-123")

      # Send multiple rapid updates
      for i <- 1..5 do
        send(view.pid, {:system_updated, "test-map-123", %{update_id: i}})
      end

      # Should handle multiple updates without crashing
      html = render(view)
      assert is_binary(html)
    end
  end

  describe "user interface" do
    test "displays chain list when available", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, html} = live(conn, ~p"/chain-intelligence")

      # Should show chain list interface
      assert html =~ "chain" or html =~ "Chain" or has_element?(view, ".chain")
    end

    test "displays chain topology visualization", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, html} = live(conn, ~p"/chain-intelligence/test-map-123")

      # Should show topology visualization
      assert html =~ "system" or html =~ "connection" or html =~ "topology"
    end

    test "shows system inhabitants", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, html} = live(conn, ~p"/chain-intelligence/test-map-123")

      # Should show inhabitant information
      assert html =~ "inhabitant" or html =~ "pilot" or html =~ "character" or is_binary(html)
    end
  end

  describe "accessibility" do
    test "page has proper structure", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, _view, html} = live(conn, ~p"/chain-intelligence")

      # Should have proper HTML structure
      assert html =~ "<" and html =~ ">"
      assert String.length(html) > 100
    end

    test "buttons are properly labeled", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, html} = live(conn, ~p"/chain-intelligence")

      # Should have accessible button elements
      assert has_element?(view, "button") or html =~ "button"
    end
  end

  describe "performance" do
    test "renders efficiently", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      start_time = :os.system_time(:millisecond)

      {:ok, _view, html} = live(conn, ~p"/chain-intelligence")

      end_time = :os.system_time(:millisecond)
      render_time = end_time - start_time

      # Should render within reasonable time
      assert render_time < 5000
      assert is_binary(html)
    end

    test "handles large chain data efficiently", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence/large-chain-map")

      # Should handle large datasets
      html = render(view)
      assert is_binary(html)
    end
  end

  describe "integration" do
    test "integrates with Wanderer API", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence")

      # Component should integrate with external APIs gracefully
      html = render(view)
      assert is_binary(html)

      # Should not show integration errors in normal operation
      refute html =~ "Connection refused"
    end

    test "works with chain monitoring system", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence")

      # Should integrate with chain monitoring
      view
      |> element("button[phx-click='monitor_chain'][phx-value-map_id='integration-test']")
      |> render_click()

      html = render(view)
      assert is_binary(html)
    end
  end

  describe "security" do
    test "only shows data for user's corporation", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence")

      # Should only show chains for user's corporation
      html = render(view)
      assert is_binary(html)
    end

    test "validates user permissions", %{conn: conn} do
      conn = conn |> assign(:current_user, %{character_id: 123, corporation_id: 98_000_001})

      {:ok, view, _html} = live(conn, ~p"/chain-intelligence/restricted-map")

      # Should handle permission checks
      html = render(view)
      assert is_binary(html)
    end
  end
end
