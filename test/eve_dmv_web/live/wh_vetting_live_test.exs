defmodule EveDmvWeb.WHVettingLiveTest do
  @moduledoc """
  Comprehensive tests for WHVettingLive LiveView component.
  """
  use EveDmvWeb.ConnCase, async: true
  @moduletag :skip

  import Phoenix.LiveViewTest
  import EveDmv.Factories

  alias EveDmv.Accounts.User
  alias EveDmv.Intelligence.WHVettingAnalyzer

  setup %{conn: conn} do
    # Create authenticated user
    user =
      create(:user, %{
        character_id: 95_465_499,
        character_name: "WH Corp Recruiter"
      })

    conn = log_in_user(conn, user)

    %{conn: conn, user: user}
  end

  describe "mount/3" do
    @tag :skip
    test "renders vetting interface", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/wh-vetting")

      assert html =~ "Wormhole Vetting Analysis"
      assert html =~ "Enter Character Name"
      assert html =~ "Start Vetting"
    end

    @tag :skip
    test "requires authentication", %{conn: conn} do
      # Log out user
      conn = conn |> Phoenix.ConnTest.recycle() |> Phoenix.ConnTest.init_test_session(%{})

      # Should redirect to login
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/wh-vetting")
    end
  end

  describe "character vetting" do
    @tag :skip
    test "performs vetting analysis on valid character", %{conn: conn} do
      # Create test character with J-space activity
      character_id = 95_000_100
      create_wormhole_character(character_id, "Test Pilot")

      {:ok, view, _html} = live(conn, ~p"/wh-vetting")

      # Submit character for vetting
      view
      |> element("form[phx-submit=\"vet_character\"]")
      |> render_submit(%{
        "vetting" => %{"character_name" => "Test Pilot"}
      })

      :timer.sleep(500)

      html = render(view)

      # Should show analysis results
      assert html =~ "Vetting Analysis Complete"
      assert html =~ "J-Space Experience"
      assert html =~ "Security Risk Assessment"
      assert html =~ "Recommendation"
    end

    @tag :skip
    test "handles character not found", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/wh-vetting")

      # Submit non-existent character
      view
      |> element("form[phx-submit=\"vet_character\"]")
      |> render_submit(%{
        "vetting" => %{"character_name" => "NonExistentPilot123"}
      })

      :timer.sleep(300)

      html = render(view)
      assert html =~ "Character not found"
    end

    @tag :skip
    test "displays vetting progress", %{conn: conn} do
      character_id = 95_000_101
      create_wormhole_character(character_id, "Progress Test")

      {:ok, view, _html} = live(conn, ~p"/wh-vetting")

      # Start vetting
      view
      |> element("form[phx-submit=\"vet_character\"]")
      |> render_submit(%{
        "vetting" => %{"character_name" => "Progress Test"}
      })

      # Should show progress indicators
      html = render(view)
      assert html =~ "Analyzing" or html =~ "Loading"
      assert html =~ "J-Space Experience" or html =~ "Checking killboard"
    end
  end

  describe "vetting results" do
    @tag :skip
    test "shows approval recommendation for qualified pilot", %{conn: conn} do
      character_id = 95_000_102
      create_experienced_wormhole_pilot(character_id, "Experienced Pilot")

      {:ok, view, _html} = live(conn, ~p"/wh-vetting")

      view
      |> element("form[phx-submit=\"vet_character\"]")
      |> render_submit(%{
        "vetting" => %{"character_name" => "Experienced Pilot"}
      })

      :timer.sleep(500)

      html = render(view)

      assert html =~ "Recommendation: Approve" or html =~ "Recommended for Approval"
      assert html =~ "High J-Space Experience"
      assert html =~ "Low Security Risk"
    end

    @tag :skip
    test "shows rejection for eviction group member", %{conn: conn} do
      character_id = 95_000_103
      create_eviction_character(character_id, "Eviction Pilot")

      {:ok, view, _html} = live(conn, ~p"/wh-vetting")

      view
      |> element("form[phx-submit=\"vet_character\"]")
      |> render_submit(%{
        "vetting" => %{"character_name" => "Eviction Pilot"}
      })

      :timer.sleep(500)

      html = render(view)

      assert html =~ "Recommendation: Reject" or html =~ "Not Recommended"
      assert html =~ "Eviction Group Detected" or html =~ "Hard Knocks"
    end

    @tag :skip
    test "shows conditional approval for moderate risk", %{conn: conn} do
      character_id = 95_000_104
      create_moderate_risk_character(character_id, "Moderate Pilot")

      {:ok, view, _html} = live(conn, ~p"/wh-vetting")

      view
      |> element("form[phx-submit=\"vet_character\"]")
      |> render_submit(%{
        "vetting" => %{"character_name" => "Moderate Pilot"}
      })

      :timer.sleep(500)

      html = render(view)

      assert html =~ "Conditional" or html =~ "Further Review"
      assert html =~ "Moderate Risk"
    end
  end

  describe "detailed analysis sections" do
    @tag :skip
    test "displays J-space experience breakdown", %{conn: conn} do
      character_id = 95_000_105
      create_wormhole_character(character_id, "WH Pilot")

      {:ok, view, _html} = live(conn, ~p"/wh-vetting")

      view
      |> element("form[phx-submit=\"vet_character\"]")
      |> render_submit(%{
        "vetting" => %{"character_name" => "WH Pilot"}
      })

      :timer.sleep(500)

      html = render(view)

      # J-space metrics
      assert html =~ "Total J-Space Kills"
      assert html =~ "J-Space Time Percentage"
      assert html =~ "Wormhole Classes Visited"
      assert html =~ "Most Active WH Class"
    end

    @tag :skip
    test "displays security risk factors", %{conn: conn} do
      character_id = 95_000_106
      create_corp_hopper_character(character_id, "Corp Hopper")

      {:ok, view, _html} = live(conn, ~p"/wh-vetting")

      view
      |> element("form[phx-submit=\"vet_character\"]")
      |> render_submit(%{
        "vetting" => %{"character_name" => "Corp Hopper"}
      })

      :timer.sleep(500)

      html = render(view)

      # Risk factors
      assert html =~ "Risk Score"
      assert html =~ "Corp Hopping Detected"
      assert html =~ "Employment History"
    end

    @tag :skip
    test "displays small gang competency", %{conn: conn} do
      character_id = 95_000_107
      create_small_gang_pilot(character_id, "Small Gang Expert")

      {:ok, view, _html} = live(conn, ~p"/wh-vetting")

      view
      |> element("form[phx-submit=\"vet_character\"]")
      |> render_submit(%{
        "vetting" => %{"character_name" => "Small Gang Expert"}
      })

      :timer.sleep(500)

      html = render(view)

      # Small gang metrics
      assert html =~ "Small Gang Performance"
      assert html =~ "Average Gang Size"
      assert html =~ "Solo Capability"
    end
  end

  describe "vetting history" do
    @tag :skip
    test "saves vetting results to history", %{conn: conn} do
      character_id = 95_000_108
      create_wormhole_character(character_id, "History Test")

      {:ok, view, _html} = live(conn, ~p"/wh-vetting")

      # Perform vetting
      view
      |> element("form[phx-submit=\"vet_character\"]")
      |> render_submit(%{
        "vetting" => %{"character_name" => "History Test"}
      })

      :timer.sleep(500)

      # Check history tab
      view |> element("[phx-click=\"show_history\"]") |> render_click()

      html = render(view)
      assert html =~ "Vetting History"
      assert html =~ "History Test"
      assert html =~ DateTime.utc_now() |> DateTime.to_date() |> to_string()
    end

    @tag :skip
    test "loads previous vetting result", %{conn: conn} do
      character_id = 95_000_109
      create_wormhole_character(character_id, "Previous Result")

      {:ok, view, _html} = live(conn, ~p"/wh-vetting")

      # First vetting
      view
      |> element("form[phx-submit=\"vet_character\"]")
      |> render_submit(%{
        "vetting" => %{"character_name" => "Previous Result"}
      })

      :timer.sleep(500)

      # Click on history item
      view
      |> element(~s([phx-click="load_vetting"][phx-value-character-id="#{character_id}"]))
      |> render_click()

      html = render(view)
      assert html =~ "Previous Result"
      assert html =~ "Loaded from history"
    end
  end

  describe "export functionality" do
    test "exports vetting report", %{conn: conn} do
      character_id = 95_000_110
      create_wormhole_character(character_id, "Export Test")

      {:ok, view, _html} = live(conn, ~p"/wh-vetting")

      view
      |> element("form[phx-submit=\"vet_character\"]")
      |> render_submit(%{
        "vetting" => %{"character_name" => "Export Test"}
      })

      :timer.sleep(500)

      # Export report
      view |> element("[phx-click=\"export_report\"]") |> render_click()

      assert_push_event(view, "download", %{
        filename: filename,
        content: content
      })

      assert filename =~ "vetting_report"
      assert filename =~ "Export_Test"
      assert content =~ "Wormhole Vetting Report"
    end

    @tag :skip
    test "shares vetting result link", %{conn: conn} do
      character_id = 95_000_111
      create_wormhole_character(character_id, "Share Test")

      {:ok, view, _html} = live(conn, ~p"/wh-vetting")

      view
      |> element("form[phx-submit=\"vet_character\"]")
      |> render_submit(%{
        "vetting" => %{"character_name" => "Share Test"}
      })

      :timer.sleep(500)

      # Generate share link
      view |> element("[phx-click=\"share_result\"]") |> render_click()

      html = render(view)
      assert html =~ "Share Link"
      assert html =~ "/wh-vetting/result/"
    end
  end

  describe "batch vetting" do
    test "vets multiple characters", %{conn: conn} do
      # Create multiple characters
      characters =
        for i <- 1..3 do
          char_id = 95_000_200 + i
          name = "Batch Pilot #{i}"
          create_wormhole_character(char_id, name)
          name
        end

      {:ok, view, _html} = live(conn, ~p"/wh-vetting")

      # Switch to batch mode
      view |> element("[phx-click=\"toggle_batch_mode\"]") |> render_click()

      # Submit batch
      view
      |> element("form[phx-submit=\"batch_vet\"]")
      |> render_submit(%{
        "batch" => %{"character_names" => Enum.join(characters, "\n")}
      })

      :timer.sleep(1000)

      html = render(view)

      # Should show all results
      assert html =~ "Batch Results"
      assert html =~ "3 characters analyzed"

      Enum.each(characters, fn name ->
        assert html =~ name
      end)
    end
  end

  describe "real-time updates" do
    test "updates when character gets new kills", %{conn: conn} do
      character_id = 95_000_112
      create_wormhole_character(character_id, "Realtime Test")

      {:ok, view, _html} = live(conn, ~p"/wh-vetting")

      view
      |> element("form[phx-submit=\"vet_character\"]")
      |> render_submit(%{
        "vetting" => %{"character_name" => "Realtime Test"}
      })

      :timer.sleep(500)

      initial_html = render(view)
      initial_kills = extract_kill_count(initial_html)

      # Simulate new kill
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "character:#{character_id}",
        {:new_kill, build_j_space_kill(character_id)}
      )

      :timer.sleep(200)

      updated_html = render(view)
      updated_kills = extract_kill_count(updated_html)

      assert updated_kills > initial_kills
      assert updated_html =~ "Updated"
    end
  end

  # Helper functions

  defp create_wormhole_character(character_id, name) do
    # Create basic J-space activity
    for i <- 1..15 do
      create(:killmail_raw, %{
        killmail_id: 80_000_000 + character_id + i,
        killmail_time: DateTime.add(DateTime.utc_now(), -i * 86_400, :second),
        solar_system_id: Enum.random(31_000_000..31_002_000),
        killmail_data: build_wh_killmail_data(character_id, name, i)
      })
    end

    # Create character record
    create(:character, %{
      character_id: character_id,
      character_name: name
    })
  end

  defp create_experienced_wormhole_pilot(character_id, name) do
    # Create extensive J-space history
    for i <- 1..50 do
      create(:killmail_raw, %{
        killmail_id: 81_000_000 + character_id + i,
        killmail_time: DateTime.add(DateTime.utc_now(), -i * 43_200, :second),
        solar_system_id: Enum.random(31_000_000..31_005_000),
        killmail_data: build_wh_killmail_data(character_id, name, i, is_victim: rem(i, 10) == 0)
      })
    end

    create(:character, %{
      character_id: character_id,
      character_name: name
    })
  end

  defp create_eviction_character(character_id, name) do
    # Create kills with eviction groups
    for i <- 1..20 do
      create(:killmail_raw, %{
        killmail_id: 82_000_000 + character_id + i,
        killmail_time: DateTime.utc_now(),
        killmail_data: build_eviction_killmail_data(character_id, name)
      })
    end

    create(:character, %{
      character_id: character_id,
      character_name: name
    })
  end

  defp create_moderate_risk_character(character_id, name) do
    # Some J-space activity, some K-space
    for i <- 1..20 do
      system_id =
        if rem(i, 2) == 0 do
          # J-space
          Enum.random(31_000_000..31_002_000)
        else
          # K-space
          Enum.random(30_000_000..30_005_000)
        end

      create(:killmail_raw, %{
        killmail_id: 83_000_000 + character_id + i,
        killmail_time: DateTime.add(DateTime.utc_now(), -i * 86_400, :second),
        solar_system_id: system_id,
        killmail_data: build_wh_killmail_data(character_id, name, i)
      })
    end

    create(:character, %{
      character_id: character_id,
      character_name: name
    })
  end

  defp create_corp_hopper_character(character_id, name) do
    create_wormhole_character(character_id, name)

    # Create employment history with many corps
    base_date = ~U[2023-01-01 00:00:00Z]

    for i <- 0..10 do
      create(:employment_history, %{
        character_id: character_id,
        corporation_id: 1000 + i,
        start_date: DateTime.add(base_date, i * 20 * 86_400, :second)
      })
    end
  end

  defp create_small_gang_pilot(character_id, name) do
    # Create small gang kills
    for i <- 1..25 do
      gang_size = Enum.random(2..5)

      create(:killmail_raw, %{
        killmail_id: 84_000_000 + character_id + i,
        killmail_time: DateTime.utc_now(),
        solar_system_id: Enum.random(31_000_000..31_002_000),
        killmail_data: build_small_gang_killmail_data(character_id, name, gang_size)
      })
    end

    create(:character, %{
      character_id: character_id,
      character_name: name
    })
  end

  defp build_wh_killmail_data(character_id, name, index, opts \\ []) do
    is_victim = Keyword.get(opts, :is_victim, rem(index, 5) == 0)

    %{
      "attackers" =>
        if is_victim do
          [
            %{
              "character_id" => Enum.random(90_000_000..95_000_000),
              "character_name" => "Enemy Pilot",
              "corporation_id" => 2_000_000,
              # Machariel
              "ship_type_id" => 17_738,
              "final_blow" => true
            }
          ]
        else
          [
            %{
              "character_id" => character_id,
              "character_name" => name,
              "corporation_id" => 1_000_000,
              # T3Cs and Logi
              "ship_type_id" => Enum.random([12_011, 12_013, 11_987]),
              "final_blow" => true
            }
          ]
        end,
      "victim" =>
        if is_victim do
          %{
            "character_id" => character_id,
            "character_name" => name,
            "corporation_id" => 1_000_000,
            # Legion
            "ship_type_id" => 12_011
          }
        else
          %{
            "character_id" => Enum.random(90_000_000..95_000_000),
            "corporation_id" => 2_000_000,
            "ship_type_id" => Enum.random([587, 588, 589])
          }
        end
    }
  end

  defp build_eviction_killmail_data(character_id, name) do
    %{
      "attackers" => [
        %{
          "character_id" => character_id,
          "character_name" => name,
          # HK corp ID
          "corporation_id" => 98_000_000,
          "corporation_name" => "Hard Knocks Citizens",
          "alliance_id" => 99_000_000,
          "alliance_name" => "Hard Knocks Citizens",
          "ship_type_id" => 12_013,
          "final_blow" => true
        }
      ],
      "victim" => %{
        "character_id" => Enum.random(90_000_000..95_000_000),
        # Astrahus
        "structure_type_id" => 35_832
      }
    }
  end

  defp build_small_gang_killmail_data(character_id, name, gang_size) do
    attackers =
      for i <- 1..gang_size do
        if i == 1 do
          %{
            "character_id" => character_id,
            "character_name" => name,
            "final_blow" => true
          }
        else
          %{
            "character_id" => 95_000_000 + i,
            "character_name" => "Gang Member #{i}",
            "final_blow" => false
          }
        end
      end

    %{
      "attackers" => attackers,
      "victim" => %{
        "character_id" => Enum.random(90_000_000..95_000_000)
      }
    }
  end

  defp build_j_space_kill(character_id) do
    %{
      "killmail_id" => System.unique_integer([:positive]),
      "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "solar_system_id" => 31_000_001,
      "attackers" => [
        %{
          "character_id" => character_id,
          "ship_type_id" => 12_011,
          "final_blow" => true
        }
      ],
      "victim" => %{
        "character_id" => Enum.random(90_000_000..95_000_000)
      }
    }
  end

  defp extract_kill_count(html) do
    case Regex.run(~r/J-Space Kills:?\s*(\d+)/, html) do
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
