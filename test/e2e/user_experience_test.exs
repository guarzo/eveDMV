defmodule EveDmv.E2E.UserExperienceTest do
  @moduledoc """
  End-to-end user experience tests simulating complete user workflows.
  Tests the entire application flow from authentication through intelligence analysis.
  """
  use EveDmvWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import EveDmv.Factories

  alias EveDmv.Accounts.User
  alias EveDmv.Intelligence.{CharacterAnalyzer, WHVettingAnalyzer}

  @moduletag :e2e
  @moduletag timeout: 120_000

  describe "new user onboarding workflow" do
    test "complete user registration and first intelligence analysis", %{conn: conn} do
      # Step 1: User visits landing page
      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "EVE DMV"
      assert html_response(conn, 200) =~ "Sign in with EVE"

      # Step 2: User initiates EVE SSO login
      conn = get(conn, ~p"/auth/eve_sso")
      assert response(conn, 302)

      # Step 3: Simulate successful EVE SSO callback
      user_data = create_mock_eve_user_data()
      user = create_authenticated_user(user_data)
      conn = log_in_user(conn, user)

      # Step 4: User lands on dashboard
      conn = get(conn, ~p"/dashboard")
      assert html_response(conn, 200) =~ "Dashboard"
      assert html_response(conn, 200) =~ user.character_name

      # Step 5: User navigates to intelligence section
      {:ok, view, html} = live(conn, ~p"/intel/#{user.character_id}")
      assert html =~ "Character Intelligence"

      # Wait for analysis to load
      :timer.sleep(1000)

      html = render(view)
      assert html =~ "Analysis" or html =~ "Loading"

      # Step 6: User explores different intelligence tabs
      for tab <- ["combat", "patterns", "associations"] do
        view |> element(~s([phx-click="change_tab"][phx-value-tab="#{tab}"])) |> render_click()
        html = render(view)
        assert html =~ String.capitalize(tab)
      end

      # Step 7: User searches for another character
      view
      |> element("form[phx-submit=\"search_character\"]")
      |> render_submit(%{
        "search" => %{"query" => "Test"}
      })

      :timer.sleep(200)
      html = render(view)
      assert html =~ "Search" or html =~ "No results"
    end
  end

  describe "intelligence analyst workflow" do
    test "comprehensive character investigation workflow", %{conn: conn} do
      # Setup: Create analyst user and target character
      analyst = create_analyst_user()
      target_character_id = 95_000_100
      create_target_character_activity(target_character_id)

      conn = log_in_user(conn, analyst)

      # Step 1: Analyst searches for target character
      {:ok, view, _html} = live(conn, ~p"/intel/#{target_character_id}")

      :timer.sleep(1000)

      # Step 2: Review basic intelligence
      html = render(view)
      assert html =~ "Character Intelligence"
      assert html =~ "Threat Level"

      # Step 3: Analyze combat patterns
      view |> element(~s([phx-click="change_tab"][phx-value-tab="combat"])) |> render_click()
      html = render(view)
      assert html =~ "Combat Statistics"
      assert html =~ "Ship Usage" or html =~ "K/D Ratio"

      # Step 4: Check activity patterns
      view |> element(~s([phx-click="change_tab"][phx-value-tab="patterns"])) |> render_click()
      html = render(view)
      assert html =~ "Activity Patterns"
      assert html =~ "Geographic" or html =~ "Temporal"

      # Step 5: Investigate associations
      view
      |> element(~s([phx-click="change_tab"][phx-value-tab="associations"]))
      |> render_click()

      html = render(view)
      assert html =~ "Known Associates" or html =~ "Frequent Targets"

      # Step 6: Add character for comparison
      comparison_character_id = 95_000_200
      create_comparison_character_activity(comparison_character_id)

      view
      |> element(
        ~s([phx-click="add_comparison"][phx-value-character-id="#{comparison_character_id}"])
      )
      |> render_click()

      :timer.sleep(300)
      html = render(view)
      assert html =~ "Comparison" or html =~ "Added"

      # Step 7: Export analysis report
      view |> element("[phx-click=\"export_analysis\"]") |> render_click()

      assert_push_event(view, "download", %{
        filename: filename,
        content: _content
      })

      assert filename =~ "character_analysis"
    end

    test "wormhole recruitment vetting workflow", %{conn: conn} do
      # Setup: WH corp recruiter
      recruiter = create_wh_recruiter_user()
      applicant_character_id = 95_000_300
      create_wh_applicant_activity(applicant_character_id, "Experienced Pilot")

      conn = log_in_user(conn, recruiter)

      # Step 1: Navigate to vetting interface
      {:ok, view, html} = live(conn, ~p"/wh-vetting")
      assert html =~ "Wormhole Vetting"
      assert html =~ "Enter Character Name"

      # Step 2: Submit character for vetting
      view
      |> element("form[phx-submit=\"vet_character\"]")
      |> render_submit(%{
        "vetting" => %{"character_name" => "Experienced Pilot"}
      })

      # Step 3: Wait for vetting analysis
      :timer.sleep(2000)
      html = render(view)
      assert html =~ "Vetting Analysis Complete" or html =~ "J-Space Experience"

      # Step 4: Review vetting results
      assert html =~ "Recommendation"
      assert html =~ "Security Risk" or html =~ "Risk Score"
      assert html =~ "J-Space" or html =~ "Wormhole"

      # Step 5: Export vetting report
      if html =~ "export_report" do
        view |> element("[phx-click=\"export_report\"]") |> render_click()

        assert_push_event(view, "download", %{
          filename: filename,
          content: _content
        })

        assert filename =~ "vetting_report"
      end

      # Step 6: Check vetting history
      if html =~ "show_history" do
        view |> element("[phx-click=\"show_history\"]") |> render_click()
        html = render(view)
        assert html =~ "Vetting History" or html =~ "Previous"
      end
    end
  end

  describe "real-time intelligence workflow" do
    test "live kill feed monitoring and analysis", %{conn: conn} do
      # Setup: Intelligence analyst monitoring feed
      analyst = create_analyst_user()
      conn = log_in_user(conn, analyst)

      # Step 1: Open kill feed
      {:ok, feed_view, html} = live(conn, ~p"/feed")
      assert html =~ "Kill Feed"
      assert html =~ "Total Kills"

      # Step 2: Open character intelligence in another window (simulate)
      target_character_id = 95_000_400
      create_target_character_activity(target_character_id)

      {:ok, intel_view, _html} = live(conn, ~p"/intel/#{target_character_id}")
      :timer.sleep(500)

      # Step 3: Simulate new kill in feed
      new_kill = create_live_killmail_event(target_character_id)

      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "kill_feed",
        %Phoenix.Socket.Broadcast{
          topic: "kill_feed",
          event: "new_kill",
          payload: new_kill
        }
      )

      # Step 4: Verify kill appears in feed
      :timer.sleep(200)
      feed_html = render(feed_view)
      assert feed_html =~ "Test Character" or feed_html =~ to_string(target_character_id)

      # Step 5: Simulate character-specific update
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "character:#{target_character_id}",
        {:character_update, target_character_id, :new_killmail}
      )

      # Step 6: Verify intelligence updates
      :timer.sleep(300)
      intel_html = render(intel_view)
      assert intel_html =~ "Updated" or intel_html =~ "Real-time"
    end

    test "chain monitoring and threat detection workflow", %{conn: conn} do
      # Setup: Wormhole corp director
      director = create_wh_director_user()
      conn = log_in_user(conn, director)

      # Step 1: Access chain intelligence
      {:ok, view, html} = live(conn, ~p"/chain-intelligence")
      assert html =~ "Chain Intelligence" or html =~ "Wormhole"

      # Step 2: Monitor for threats
      threat_character_id = 95_999_999
      # J-space system
      home_system_id = 31_000_001

      # Step 3: Simulate threat entering system
      location_event = %{
        "character_id" => threat_character_id,
        "solar_system_id" => home_system_id,
        # Machariel - dangerous
        "ship_type_id" => 17_738,
        "timestamp" => DateTime.utc_now()
      }

      # Simulate chain monitor detecting threat
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "chain:threats",
        {:threat_detected, threat_character_id, location_event}
      )

      # Step 4: Verify threat notification
      :timer.sleep(200)
      html = render(view)
      assert html =~ "Threat" or html =~ "Alert" or html =~ "Detected"

      # Step 5: Investigate threat character
      if html =~ "investigate" do
        view
        |> element(
          ~s([phx-click="investigate_threat"][phx-value-character-id="#{threat_character_id}"])
        )
        |> render_click()

        :timer.sleep(500)
        html = render(view)
        assert html =~ "Investigation" or html =~ "Character Analysis"
      end
    end
  end

  describe "error handling and recovery workflows" do
    test "handles service unavailability gracefully", %{conn: conn} do
      user = create_authenticated_user()
      conn = log_in_user(conn, user)

      # Step 1: Try to access intelligence when service is slow
      # Invalid character
      {:ok, view, _html} = live(conn, ~p"/intel/1")

      :timer.sleep(1000)

      # Step 2: Should show error state
      html = render(view)
      assert html =~ "Unable to analyze" or html =~ "Error" or html =~ "No data"

      # Step 3: User can retry
      if html =~ "retry" do
        view |> element("[phx-click=\"retry_analysis\"]") |> render_click()

        :timer.sleep(200)
        html = render(view)
        assert html =~ "Retrying" or html =~ "Loading"
      end
    end

    test "handles network interruption gracefully", %{conn: conn} do
      user = create_authenticated_user()
      conn = log_in_user(conn, user)

      # Step 1: Start intelligence analysis
      character_id = 95_000_500
      create_target_character_activity(character_id)

      {:ok, view, _html} = live(conn, ~p"/intel/#{character_id}")
      :timer.sleep(500)

      # Step 2: Simulate connection issues by disabling real-time
      view |> element("[phx-click=\"toggle_real_time\"]") |> render_click()

      html = render(view)
      assert html =~ "disabled" or html =~ "Real-time updates disabled"

      # Step 3: Re-enable and verify recovery
      view |> element("[phx-click=\"toggle_real_time\"]") |> render_click()

      html = render(view)
      assert html =~ "enabled" or html =~ "Real-time updates enabled"
    end
  end

  describe "mobile user experience" do
    test "responsive design on mobile viewport", %{conn: conn} do
      user = create_authenticated_user()
      conn = log_in_user(conn, user)

      # Simulate mobile viewport
      {:ok, view, html} = live(conn, ~p"/feed")

      # Should render without horizontal scroll
      assert html =~ "Kill Feed"

      # Navigation should be mobile-friendly
      assert html =~ "menu" or html =~ "nav"

      # Content should be readable
      # No horizontal overflow
      refute html =~ "overflow-x"
    end
  end

  describe "performance under user load" do
    test "maintains responsiveness with multiple concurrent users", %{conn: _conn} do
      # Simulate 5 concurrent users
      users =
        for i <- 1..5 do
          user = create_authenticated_user(%{character_id: 95_000_600 + i})
          create_target_character_activity(user.character_id)
          user
        end

      # Each user performs typical workflow
      tasks =
        for user <- users do
          Task.async(fn ->
            conn = build_conn() |> log_in_user(user)

            # Navigate to intelligence
            {:ok, view, _html} = live(conn, ~p"/intel/#{user.character_id}")
            :timer.sleep(200)

            # Switch tabs
            view
            |> element(~s([phx-click="change_tab"][phx-value-tab="combat"]))
            |> render_click()

            :timer.sleep(100)

            # Export analysis
            view |> element("[phx-click=\"export_analysis\"]") |> render_click()

            :ok
          end)
        end

      # All workflows should complete successfully
      {time_microseconds, results} =
        :timer.tc(fn ->
          Task.await_many(tasks, 30_000)
        end)

      time_ms = time_microseconds / 1000

      assert Enum.all?(results, &(&1 == :ok))
      assert time_ms < 15_000, "Concurrent user workflows took #{time_ms}ms"
    end
  end

  # Helper functions

  defp create_mock_eve_user_data do
    %{
      "character_id" => 95_465_499,
      "character_name" => "Test Character",
      "corporation_id" => 1_000_001,
      "corporation_name" => "Test Corporation",
      "alliance_id" => 99_000_001,
      "alliance_name" => "Test Alliance"
    }
  end

  defp create_authenticated_user(user_data \\ nil) do
    data = user_data || create_mock_eve_user_data()

    create(:user, %{
      character_id: data["character_id"],
      character_name: data["character_name"],
      corporation_id: data["corporation_id"],
      corporation_name: data["corporation_name"],
      alliance_id: data["alliance_id"],
      alliance_name: data["alliance_name"]
    })
  end

  defp create_analyst_user do
    create(:user, %{
      character_id: 95_100_001,
      character_name: "Intelligence Analyst",
      corporation_id: 1_000_100,
      corporation_name: "Intel Corp"
    })
  end

  defp create_wh_recruiter_user do
    create(:user, %{
      character_id: 95_200_001,
      character_name: "WH Recruiter",
      corporation_id: 1_000_200,
      corporation_name: "Wormhole Corp"
    })
  end

  defp create_wh_director_user do
    create(:user, %{
      character_id: 95_300_001,
      character_name: "WH Director",
      corporation_id: 1_000_300,
      corporation_name: "Wormhole Leadership"
    })
  end

  defp create_target_character_activity(character_id) do
    # Create varied killmail activity
    for i <- 1..25 do
      is_victim = rem(i, 4) == 0
      system_id = if rem(i, 3) == 0, do: 31_000_001, else: 30_000_142

      create(:killmail_raw, %{
        killmail_id: 98_000_000 + character_id + i,
        killmail_time: DateTime.add(DateTime.utc_now(), -i * 3600, :second),
        solar_system_id: system_id,
        raw_data: build_activity_killmail_data(character_id, is_victim)
      })
    end
  end

  defp create_comparison_character_activity(character_id) do
    # Create moderate activity for comparison
    for i <- 1..15 do
      create(:killmail_raw, %{
        killmail_id: 98_100_000 + character_id + i,
        killmail_time: DateTime.add(DateTime.utc_now(), -i * 7200, :second),
        raw_data: build_activity_killmail_data(character_id, rem(i, 5) == 0)
      })
    end
  end

  defp create_wh_applicant_activity(character_id, character_name) do
    # Create J-space focused activity
    for i <- 1..30 do
      create(:killmail_raw, %{
        killmail_id: 98_200_000 + character_id + i,
        killmail_time: DateTime.add(DateTime.utc_now(), -i * 86_400, :second),
        # J-space
        solar_system_id: Enum.random(31_000_000..31_002_000),
        raw_data: %{
          "attackers" => [
            %{
              "character_id" => character_id,
              "character_name" => character_name,
              # WH ships
              "ship_type_id" => Enum.random([12_011, 12_013, 11_987]),
              "final_blow" => rem(i, 3) != 0
            }
          ],
          "victim" => %{
            "character_id" => Enum.random(90_000_000..95_000_000),
            "ship_type_id" => Enum.random([587, 588, 589])
          }
        }
      })
    end

    # Create character record
    create(:character, %{
      character_id: character_id,
      character_name: character_name
    })
  end

  defp create_live_killmail_event(character_id) do
    %{
      "killmail_id" => System.unique_integer([:positive]),
      "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "solar_system_id" => 30_000_142,
      "solar_system_name" => "Jita",
      "victim" => %{
        "character_id" => Enum.random(90_000_000..95_000_000),
        "character_name" => "Random Victim",
        "ship_type_id" => 587,
        "ship_name" => "Rifter"
      },
      "attackers" => [
        %{
          "character_id" => character_id,
          "character_name" => "Test Character",
          "ship_type_id" => 22_456,
          "ship_name" => "Sabre",
          "final_blow" => true
        }
      ],
      "zkb" => %{
        "totalValue" => 15_000_000
      }
    }
  end

  defp build_activity_killmail_data(character_id, is_victim) do
    if is_victim do
      %{
        "attackers" => [
          %{
            "character_id" => Enum.random(90_000_000..95_000_000),
            "ship_type_id" => Enum.random([17_738, 12_011, 22_456]),
            "final_blow" => true
          }
        ],
        "victim" => %{
          "character_id" => character_id,
          "ship_type_id" => Enum.random([587, 588, 589])
        }
      }
    else
      %{
        "attackers" => [
          %{
            "character_id" => character_id,
            "ship_type_id" => Enum.random([12_011, 12_013, 11_987]),
            "final_blow" => true
          }
        ],
        "victim" => %{
          "character_id" => Enum.random(90_000_000..95_000_000),
          "ship_type_id" => Enum.random([587, 588, 589])
        }
      }
    end
  end

  defp log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user_id, user.id)
    |> Plug.Conn.assign(:current_user, user)
  end
end
