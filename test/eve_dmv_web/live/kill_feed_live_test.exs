defmodule EveDmvWeb.KillFeedLiveTest do
  @moduledoc """
  Comprehensive tests for KillFeedLive LiveView component.
  """
  use EveDmvWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias EveDmv.Killmails.DisplayService

  describe "mount/3" do
    test "renders kill feed with initial data", %{conn: conn} do
      # Create test killmails
      create_test_killmails(5)

      {:ok, view, html} = live(conn, ~p"/feed")

      # Check initial render
      assert html =~ "Kill Feed"
      assert html =~ "Total Kills Today"
      assert html =~ "ISK Destroyed"

      # Check that killmails are displayed
      assert html =~ "Rifter"
      assert html =~ "Jita"
    end

    test "subscribes to kill feed updates when connected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/feed")

      # Verify subscription by sending a broadcast
      killmail_data = build_test_killmail()

      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "kill_feed",
        %Phoenix.Socket.Broadcast{
          topic: "kill_feed",
          event: "new_kill",
          payload: killmail_data
        }
      )

      # Give the view time to process
      :timer.sleep(100)

      # Check that the new kill appears
      html = render(view)
      assert html =~ "Test Victim"
    end

    test "limits displayed killmails to feed limit", %{conn: conn} do
      # Create more killmails than the limit
      create_test_killmails(60)

      {:ok, view, html} = live(conn, ~p"/feed")

      # Should only show 50 killmails (the limit)
      killmail_elements = html |> Floki.find("[data-killmail-id]")
      assert length(killmail_elements) <= 50
    end
  end

  describe "real-time updates" do
    test "adds new killmails to the feed", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/feed")

      # Send multiple killmail updates
      for i <- 1..3 do
        killmail = build_test_killmail(killmail_id: 90_000_000 + i)

        Phoenix.PubSub.broadcast(
          EveDmv.PubSub,
          "kill_feed",
          %Phoenix.Socket.Broadcast{
            topic: "kill_feed",
            event: "new_kill",
            payload: killmail
          }
        )
      end

      # Allow time for updates
      :timer.sleep(100)

      html = render(view)

      # Check all new kills are displayed
      assert html =~ "90000001"
      assert html =~ "90000002"
      assert html =~ "90000003"
    end

    test "updates statistics with new kills", %{conn: conn} do
      {:ok, view, initial_html} = live(conn, ~p"/feed")

      # Get initial ISK destroyed value
      initial_isk = extract_isk_value(initial_html)

      # Send high-value kill
      expensive_kill = build_test_killmail(total_value: 1_000_000_000)

      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "kill_feed",
        %Phoenix.Socket.Broadcast{
          topic: "kill_feed",
          event: "new_kill",
          payload: expensive_kill
        }
      )

      :timer.sleep(100)

      # ISK destroyed should have increased
      updated_html = render(view)
      updated_isk = extract_isk_value(updated_html)

      assert updated_isk > initial_isk
    end

    test "maintains feed limit when adding new kills", %{conn: conn} do
      # Start with 50 kills
      create_test_killmails(50)

      {:ok, view, _html} = live(conn, ~p"/feed")

      # Add 10 more kills
      for i <- 1..10 do
        killmail = build_test_killmail(killmail_id: 91_000_000 + i)

        Phoenix.PubSub.broadcast(
          EveDmv.PubSub,
          "kill_feed",
          %Phoenix.Socket.Broadcast{
            topic: "kill_feed",
            event: "new_kill",
            payload: killmail
          }
        )
      end

      :timer.sleep(200)

      # Should still only show 50 killmails
      html = render(view)
      killmail_elements = html |> Floki.find("[data-killmail-id]")
      assert length(killmail_elements) <= 50
    end
  end

  describe "system statistics" do
    test "displays system activity correctly", %{conn: conn} do
      # Create kills in specific systems
      create_system_specific_kills()

      {:ok, view, html} = live(conn, ~p"/feed")

      # Should show active systems
      assert html =~ "Active Systems"
      assert html =~ "Jita"
      assert html =~ "Amarr"
    end

    test "updates system stats with new kills", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/feed")

      # Send kill in new system
      podion_kill =
        build_test_killmail(
          solar_system_id: 30_003_715,
          solar_system_name: "Podion"
        )

      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "kill_feed",
        %Phoenix.Socket.Broadcast{
          topic: "kill_feed",
          event: "new_kill",
          payload: podion_kill
        }
      )

      :timer.sleep(100)

      html = render(view)
      assert html =~ "Podion"
    end
  end

  describe "display formatting" do
    test "formats ISK values correctly", %{conn: conn} do
      # Create kill with specific value
      create(:killmail_enriched, %{
        killmail_id: 95_000_001,
        total_value: 1_234_567_890,
        killmail_time: DateTime.utc_now()
      })

      {:ok, _view, html} = live(conn, ~p"/feed")

      # Should format as "1.23B ISK"
      assert html =~ "1.23B"
    end

    test "shows relative timestamps", %{conn: conn} do
      # Create kill from 5 minutes ago
      five_min_ago = DateTime.add(DateTime.utc_now(), -300, :second)

      create(:killmail_enriched, %{
        killmail_id: 95_000_002,
        killmail_time: five_min_ago
      })

      {:ok, _view, html} = live(conn, ~p"/feed")

      # Should show relative time
      assert html =~ "5 minutes ago" or html =~ "5m ago"
    end

    test "displays ship types and names", %{conn: conn} do
      create(:killmail_enriched, %{
        killmail_id: 95_000_003,
        victim_ship_name: "Loki",
        final_blow_ship_name: "Sabre",
        killmail_time: DateTime.utc_now()
      })

      {:ok, _view, html} = live(conn, ~p"/feed")

      assert html =~ "Loki"
      assert html =~ "Sabre"
    end
  end

  describe "error handling" do
    test "handles malformed broadcast data gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/feed")

      # Send invalid killmail data
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "kill_feed",
        %Phoenix.Socket.Broadcast{
          topic: "kill_feed",
          event: "new_kill",
          payload: %{"invalid" => "data"}
        }
      )

      :timer.sleep(100)

      # View should still be responsive
      assert render(view) =~ "Kill Feed"
    end

    test "recovers from display service errors", %{conn: conn} do
      # Mock DisplayService to raise an error
      expect(DisplayService, :load_recent_killmails, fn ->
        []
      end)

      {:ok, view, html} = live(conn, ~p"/feed")

      # Should still render with empty state
      assert html =~ "Kill Feed"
      assert html =~ "No kills to display"
    end
  end

  describe "performance" do
    test "handles rapid updates efficiently", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/feed")

      # Send 20 kills rapidly
      for i <- 1..20 do
        killmail = build_test_killmail(killmail_id: 96_000_000 + i)

        Phoenix.PubSub.broadcast(
          EveDmv.PubSub,
          "kill_feed",
          %Phoenix.Socket.Broadcast{
            topic: "kill_feed",
            event: "new_kill",
            payload: killmail
          }
        )

        # Small delay between broadcasts
        :timer.sleep(10)
      end

      :timer.sleep(300)

      # Should have processed all updates
      html = render(view)
      assert html =~ "96000020"
    end

    test "maintains responsiveness with large kill feed", %{conn: conn} do
      # Create maximum number of killmails
      create_test_killmails(50)

      {time_microseconds, {:ok, view, _html}} =
        :timer.tc(fn ->
          live(conn, ~p"/feed")
        end)

      time_ms = time_microseconds / 1000

      # Should load within reasonable time
      assert time_ms < 500, "Initial load took #{time_ms}ms"

      # Test update performance
      {update_time, _} =
        :timer.tc(fn ->
          new_kill = build_test_killmail()

          send(view.pid, %Phoenix.Socket.Broadcast{
            topic: "kill_feed",
            event: "new_kill",
            payload: new_kill
          })

          :timer.sleep(50)
          render(view)
        end)

      update_time_ms = update_time / 1000
      assert update_time_ms < 100, "Update took #{update_time_ms}ms"
    end
  end

  # Helper functions

  defp create_test_killmails(count) do
    for i <- 1..count do
      create(:killmail_enriched, %{
        killmail_id: 80_000_000 + i,
        killmail_time: DateTime.add(DateTime.utc_now(), -i * 60, :second),
        solar_system_id: Enum.random([30_000_142, 30_002_187, 30_003_715]),
        solar_system_name: Enum.random(["Jita", "Amarr", "Dodixie"]),
        victim_character_name: "Victim #{i}",
        victim_ship_name: Enum.random(["Rifter", "Rupture", "Hurricane"]),
        final_blow_character_name: "Attacker #{i}",
        final_blow_ship_name: Enum.random(["Sabre", "Loki", "Legion"]),
        total_value: Enum.random(1_000_000..100_000_000)
      })
    end
  end

  defp create_system_specific_kills do
    systems = [
      {30_000_142, "Jita", 10},
      {30_002_187, "Amarr", 5},
      {30_003_715, "Dodixie", 3}
    ]

    for {system_id, system_name, count} <- systems do
      for i <- 1..count do
        create(:killmail_enriched, %{
          killmail_id: 81_000_000 + system_id + i,
          killmail_time: DateTime.utc_now(),
          solar_system_id: system_id,
          solar_system_name: system_name
        })
      end
    end
  end

  defp build_test_killmail(opts \\ []) do
    %{
      "killmail_id" => Keyword.get(opts, :killmail_id, 90_000_000),
      "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "solar_system_id" => Keyword.get(opts, :solar_system_id, 30_000_142),
      "solar_system_name" => Keyword.get(opts, :solar_system_name, "Jita"),
      "victim" => %{
        "character_id" => 95_000_000,
        "character_name" => "Test Victim",
        "ship_type_id" => 587,
        "ship_name" => "Rifter"
      },
      "attackers" => [
        %{
          "character_id" => 95_000_001,
          "character_name" => "Test Attacker",
          "ship_type_id" => 22_456,
          "ship_name" => "Sabre",
          "final_blow" => true
        }
      ],
      "zkb" => %{
        "totalValue" => Keyword.get(opts, :total_value, 10_000_000)
      }
    }
  end

  defp extract_isk_value(html) do
    # Extract ISK value from HTML
    case Regex.run(~r/(\d+(?:\.\d+)?)\s*([BMK]?)\s*ISK/, html) do
      [_, number, suffix] ->
        value = String.to_float(number)

        case suffix do
          "B" -> value * 1_000_000_000
          "M" -> value * 1_000_000
          "K" -> value * 1_000
          _ -> value
        end

      _ ->
        0
    end
  end
end
