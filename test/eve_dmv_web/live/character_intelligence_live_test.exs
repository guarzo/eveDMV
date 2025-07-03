defmodule EveDmvWeb.CharacterIntelligenceLiveTest do
  @moduledoc """
  Comprehensive tests for CharacterIntelligenceLive LiveView component.
  """
  use EveDmvWeb.ConnCase, async: true
  @moduletag :skip

  import Phoenix.LiveViewTest
  import EveDmv.Factories

  alias EveDmv.Accounts.User
  alias EveDmv.Intelligence.CharacterAnalysis.CharacterAnalyzer
  alias EveDmv.Intelligence.IntelligenceCache

  setup %{conn: conn} do
    # Create authenticated user
    user =
      create(:user, %{
        character_id: 95_465_499,
        character_name: "Test User"
      })

    conn = log_in_user(conn, user)

    # Create test character with activity
    character_id = 95_000_100
    create_character_with_activity(character_id)

    %{conn: conn, user: user, character_id: character_id}
  end

  describe "mount/3" do
    @tag :skip
    test "loads character intelligence analysis", %{conn: conn, character_id: character_id} do
      {:ok, view, html} = live(conn, ~p"/intel/#{character_id}")

      # Should show loading initially
      assert html =~ "Loading character intelligence"

      # Wait for analysis to complete
      :timer.sleep(500)

      html = render(view)

      # Should display character info
      assert html =~ "Character Intelligence"
      assert html =~ "Threat Level"
      assert html =~ "Activity Analysis"
    end

    @tag :skip
    test "subscribes to real-time updates", %{conn: conn, character_id: character_id} do
      {:ok, view, _html} = live(conn, ~p"/intel/#{character_id}")

      # Send update via PubSub
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "character:#{character_id}",
        {:new_kill, build_test_killmail(character_id)}
      )

      :timer.sleep(100)

      # Should reflect update
      html = render(view)
      assert html =~ "Real-time updates enabled"
    end

    test "handles invalid character ID", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/intel/999999999")

      :timer.sleep(200)

      html = render(view)
      assert html =~ "Character not found" or html =~ "No data available"
    end
  end

  describe "tab navigation" do
    test "switches between analysis tabs", %{conn: conn, character_id: character_id} do
      {:ok, view, _html} = live(conn, ~p"/intel/#{character_id}")

      # Wait for initial load
      :timer.sleep(300)

      # Switch to combat stats tab
      view |> element(~s([phx-click="switch_tab"][phx-value-tab="combat"])) |> render_click()

      html = render(view)
      assert html =~ "Combat Statistics"
      assert html =~ "K/D Ratio"

      # Switch to activity patterns tab
      view |> element(~s([phx-click="switch_tab"][phx-value-tab="patterns"])) |> render_click()

      html = render(view)
      assert html =~ "Activity Patterns"
      assert html =~ "Timezone Analysis"

      # Switch to associations tab
      view
      |> element(~s([phx-click="switch_tab"][phx-value-tab="associations"]))
      |> render_click()

      html = render(view)
      assert html =~ "Known Associates"
      assert html =~ "Frequent Targets"
    end
  end

  describe "real-time updates" do
    test "displays new kills in real-time", %{conn: conn, character_id: character_id} do
      {:ok, view, _html} = live(conn, ~p"/intel/#{character_id}")

      :timer.sleep(300)

      # Get initial kill count
      initial_html = render(view)
      initial_kills = extract_kill_count(initial_html)

      # Broadcast new kill
      new_kill = build_test_killmail(character_id)

      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "character:#{character_id}",
        {:new_kill, new_kill}
      )

      :timer.sleep(200)

      # Kill count should increase
      updated_html = render(view)
      updated_kills = extract_kill_count(updated_html)

      assert updated_kills > initial_kills
    end

    test "updates threat assessment with new data", %{conn: conn, character_id: character_id} do
      {:ok, view, _html} = live(conn, ~p"/intel/#{character_id}")

      :timer.sleep(300)

      # Send high-threat activity
      for i <- 1..5 do
        # Machariel
        kill = build_test_killmail(character_id, ship_type_id: 17_738)

        Phoenix.PubSub.broadcast(
          EveDmv.PubSub,
          "character:#{character_id}",
          {:new_kill, kill}
        )
      end

      :timer.sleep(300)

      html = render(view)

      # Threat level should reflect dangerous activity
      assert html =~ "High Threat" or html =~ "Very Dangerous"
    end

    test "toggles real-time updates", %{conn: conn, character_id: character_id} do
      {:ok, view, _html} = live(conn, ~p"/intel/#{character_id}")

      :timer.sleep(300)

      # Disable real-time updates
      view |> element("[phx-click=\"toggle_realtime\"]") |> render_click()

      html = render(view)
      assert html =~ "Real-time updates disabled"

      # Send update - should not be reflected
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "character:#{character_id}",
        {:new_kill, build_test_killmail(character_id)}
      )

      :timer.sleep(100)

      # Re-enable real-time updates
      view |> element("[phx-click=\"toggle_realtime\"]") |> render_click()

      html = render(view)
      assert html =~ "Real-time updates enabled"
    end
  end

  describe "auto-refresh" do
    test "enables auto-refresh functionality", %{conn: conn, character_id: character_id} do
      {:ok, view, _html} = live(conn, ~p"/intel/#{character_id}")

      # Enable auto-refresh
      view |> element("[phx-click=\"toggle_auto_refresh\"]") |> render_click()

      html = render(view)
      assert html =~ "Auto-refresh enabled"
      assert html =~ "60 seconds"
    end

    test "changes refresh interval", %{conn: conn, character_id: character_id} do
      {:ok, view, _html} = live(conn, ~p"/intel/#{character_id}")

      # Change interval to 30 seconds
      view
      |> element("form[phx-change=\"update_refresh_interval\"]")
      |> render_change(%{
        "interval" => "30"
      })

      html = render(view)
      assert html =~ "30 seconds"
    end
  end

  describe "character comparison" do
    test "adds characters for comparison", %{conn: conn, character_id: character_id} do
      {:ok, view, _html} = live(conn, ~p"/intel/#{character_id}")

      # Create another character
      comparison_id = 95_000_200
      create_character_with_activity(comparison_id)

      # Add for comparison
      view
      |> element(~s([phx-click="add_comparison"][phx-value-character-id="#{comparison_id}"]))
      |> render_click()

      html = render(view)
      assert html =~ "Comparison Added"
      assert html =~ "95000200"
    end

    test "removes characters from comparison", %{conn: conn, character_id: character_id} do
      {:ok, view, _html} = live(conn, ~p"/intel/#{character_id}")

      # Add comparison first
      comparison_id = 95_000_201
      create_character_with_activity(comparison_id)

      view
      |> element(~s([phx-click="add_comparison"][phx-value-character-id="#{comparison_id}"]))
      |> render_click()

      # Remove comparison
      view
      |> element(~s([phx-click="remove_comparison"][phx-value-character-id="#{comparison_id}"]))
      |> render_click()

      html = render(view)
      refute html =~ "95000201"
    end
  end

  describe "search functionality" do
    test "searches for related characters", %{conn: conn, character_id: character_id} do
      {:ok, view, _html} = live(conn, ~p"/intel/#{character_id}")

      # Perform search
      view
      |> element("form[phx-submit=\"search_characters\"]")
      |> render_submit(%{
        "search" => %{"query" => "Test"}
      })

      :timer.sleep(200)

      html = render(view)
      assert html =~ "Search Results"
    end

    @tag :skip
    test "handles empty search results", %{conn: conn, character_id: character_id} do
      {:ok, view, _html} = live(conn, ~p"/intel/#{character_id}")

      # Search for non-existent character
      view
      |> element("form[phx-submit=\"search_characters\"]")
      |> render_submit(%{
        "search" => %{"query" => "zzznonexistent"}
      })

      :timer.sleep(200)

      html = render(view)
      assert html =~ "No characters found"
    end
  end

  describe "export functionality" do
    test "exports analysis data", %{conn: conn, character_id: character_id} do
      {:ok, view, _html} = live(conn, ~p"/intel/#{character_id}")

      :timer.sleep(300)

      # Click export button
      view |> element("[phx-click=\"export_analysis\"]") |> render_click()

      # Should trigger download
      assert_push_event(view, "download", %{
        filename: filename,
        content: _content
      })

      assert filename =~ "character_analysis"
      assert filename =~ "#{character_id}"
    end
  end

  describe "correlation insights" do
    @tag :skip
    test "displays character correlations", %{conn: conn, character_id: character_id} do
      # Create correlated activity
      create_correlated_activity(character_id)

      {:ok, view, _html} = live(conn, ~p"/intel/#{character_id}")

      :timer.sleep(500)

      html = render(view)

      # Should show correlations
      assert html =~ "Character Correlations"
      assert html =~ "Frequently Flies With"
      assert html =~ "Common Targets"
    end
  end

  describe "wormhole vetting integration" do
    test "shows wormhole vetting analysis when applicable", %{conn: conn} do
      # Create character with J-space activity
      wh_character_id = 95_000_300
      create_wormhole_character_activity(wh_character_id)

      {:ok, view, _html} = live(conn, ~p"/intel/#{wh_character_id}")

      :timer.sleep(500)

      html = render(view)

      # Should show WH-specific analysis
      assert html =~ "J-Space Experience"
      assert html =~ "Wormhole Activity"
      assert html =~ "Chain Mapping"
    end
  end

  describe "performance monitoring" do
    test "displays analysis timing", %{conn: conn, character_id: character_id} do
      {:ok, view, _html} = live(conn, ~p"/intel/#{character_id}")

      :timer.sleep(500)

      html = render(view)

      # Should show performance metrics
      assert html =~ "Analysis completed in"
      assert html =~ "ms"
    end

    test "handles cache hits efficiently", %{conn: conn, character_id: character_id} do
      # Prime cache
      {:ok, view1, _html} = live(conn, ~p"/intel/#{character_id}")
      :timer.sleep(500)

      # Second load should be faster (cache hit)
      {time, {:ok, view2, _html}} =
        :timer.tc(fn ->
          live(conn, ~p"/intel/#{character_id}")
        end)

      time_ms = time / 1000
      assert time_ms < 100, "Cached load took #{time_ms}ms"

      html = render(view2)
      assert html =~ "Cached"
    end
  end

  describe "error handling" do
    test "handles analysis failures gracefully", %{conn: conn} do
      # Use character ID that will cause analysis to fail
      {:ok, view, _html} = live(conn, ~p"/intel/1")

      :timer.sleep(300)

      html = render(view)
      assert html =~ "Unable to analyze character" or html =~ "Analysis failed"
    end

    test "retries failed analysis", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/intel/1")

      :timer.sleep(300)

      # Click retry
      view |> element("[phx-click=\"retry_analysis\"]") |> render_click()

      html = render(view)
      assert html =~ "Retrying analysis" or html =~ "Loading"
    end
  end

  # Helper functions

  defp create_character_with_activity(character_id) do
    # Create killmails for character
    for i <- 1..20 do
      create(:killmail_raw, %{
        killmail_id: 80_000_000 + character_id + i,
        killmail_time: DateTime.add(DateTime.utc_now(), -i * 3600, :second),
        solar_system_id: Enum.random(30_000_000..30_005_000),
        killmail_data: build_killmail_data(character_id, i)
      })
    end
  end

  defp create_correlated_activity(character_id) do
    # Create kills with same accomplices
    accomplice_ids = [95_001_000, 95_001_001, 95_001_002]

    for i <- 1..10 do
      create(:killmail_raw, %{
        killmail_id: 81_000_000 + i,
        killmail_time: DateTime.utc_now(),
        killmail_data: build_fleet_killmail_data(character_id, accomplice_ids)
      })
    end
  end

  defp create_wormhole_character_activity(character_id) do
    # Create J-space killmails
    for i <- 1..15 do
      create(:killmail_raw, %{
        killmail_id: 82_000_000 + character_id + i,
        killmail_time: DateTime.add(DateTime.utc_now(), -i * 7200, :second),
        # J-space
        solar_system_id: Enum.random(31_000_000..31_005_000),
        killmail_data: build_killmail_data(character_id, i)
      })
    end
  end

  defp build_test_killmail(character_id, opts \\ []) do
    %{
      "killmail_id" => System.unique_integer([:positive]),
      "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "solar_system_id" => 30_000_142,
      "attackers" => [
        %{
          "character_id" => character_id,
          "ship_type_id" => Keyword.get(opts, :ship_type_id, 587),
          "final_blow" => true
        }
      ],
      "victim" => %{
        "character_id" => Enum.random(90_000_000..95_000_000),
        "ship_type_id" => 588
      }
    }
  end

  defp build_killmail_data(character_id, index) do
    is_victim = rem(index, 4) == 0

    %{
      "attackers" => [
        %{
          "character_id" =>
            if(is_victim, do: Enum.random(90_000_000..95_000_000), else: character_id),
          "corporation_id" => 1_000_000,
          "ship_type_id" => Enum.random([587, 588, 589, 17_738]),
          "final_blow" => true
        }
      ],
      "victim" => %{
        "character_id" =>
          if(is_victim, do: character_id, else: Enum.random(90_000_000..95_000_000)),
        "corporation_id" => 2_000_000,
        "ship_type_id" => Enum.random([587, 588, 589])
      }
    }
  end

  defp build_fleet_killmail_data(character_id, accomplice_ids) do
    %{
      "attackers" => [
        %{
          "character_id" => character_id,
          "final_blow" => true
        }
        | Enum.map(accomplice_ids, fn id ->
            %{"character_id" => id, "final_blow" => false}
          end)
      ],
      "victim" => %{
        "character_id" => Enum.random(90_000_000..95_000_000)
      }
    }
  end

  defp extract_kill_count(html) do
    case Regex.run(~r/Total Kills:?\s*(\d+)/, html) do
      [_, count] -> String.to_integer(count)
      _ -> 0
    end
  end

  defp log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user_id, user.id)
    |> Plug.Conn.assign(:current_user, user)
  end
end
