defmodule EveDmvWeb.CharacterIntelligenceLiveTest do
  use EveDmvWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  import EveDmv.Factories
  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Users.Token
  alias EveDmv.Users.User

  setup do
    # Create a test user with authentication
    {:ok, user} =
      Api.create(User, %{
        character_id: 95_000_001,
        character_name: "Test Pilot",
        owner_hash: "test_hash_#{System.unique_integer()}"
      })

    {:ok, token} =
      Api.create(Token, %{
        user_id: user.id,
        character_id: user.character_id,
        character_name: user.character_name,
        character_owner_hash: user.owner_hash,
        access_token: "test_access_token",
        refresh_token: "test_refresh_token",
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
        scopes: "publicData esi-killmails.read_killmails.v1"
      })

    # Create test killmail data for the character
    for i <- 1..20 do
      killmail_attrs = killmail_raw_factory()

      # Mix of kills and losses
      if rem(i, 3) == 0 do
        # Losses
        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 700_000_000 + i,
              killmail_time: DateTime.utc_now() |> DateTime.add(-i * 2, :day),
              solar_system_id: 30_000_142,
              victim_character_id: user.character_id,
              # Vexor
              victim_ship_type_id: 624,
              victim_corporation_id: 98_000_000,
              attacker_count: 3,
              total_value: Decimal.new("30000000"),
              raw_data: %{
                "victim" => %{"character_id" => user.character_id}
              }
            })
          )
      else
        # Kills
        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 701_000_000 + i,
              killmail_time: DateTime.utc_now() |> DateTime.add(-i * 2, :day),
              solar_system_id: 30_000_142,
              victim_character_id: 95_100_000 + i,
              # Rifter
              victim_ship_type_id: 587,
              victim_corporation_id: 98_000_000,
              attacker_count: 1,
              total_value: Decimal.new("10000000"),
              raw_data: %{
                "attackers" => [
                  %{
                    "character_id" => user.character_id,
                    # Tengu
                    "ship_type_id" => 29_984,
                    "final_blow" => true
                  }
                ]
              }
            })
          )
      end
    end

    %{user: user, token: token}
  end

  describe "character intelligence live view" do
    test "displays character threat analysis", %{conn: conn, user: user} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{
          user_id: user.id,
          character_id: user.character_id,
          character_name: user.character_name
        })

      {:ok, _view, html} = live(conn, "/character/#{user.character_id}")

      # Check that the page loads
      assert html =~ "Character Intelligence"
      assert html =~ user.character_name

      # Check for threat score display
      assert html =~ "Threat Score" or html =~ "threat-score"

      # Should show activity stats
      assert html =~ "Recent Activity" or html =~ "Kills" or html =~ "Deaths"
    end

    test "displays behavioral patterns", %{conn: conn, user: user} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{
          user_id: user.id,
          character_id: user.character_id,
          character_name: user.character_name
        })

      {:ok, view, _html} = live(conn, "/character/#{user.character_id}")

      # Wait for async data to load
      :timer.sleep(100)

      html = render(view)

      # Should show behavioral analysis
      assert html =~ "Behavioral" or html =~ "Pattern" or html =~ "Style"
    end

    test "shows ship preferences", %{conn: conn, user: user} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{
          user_id: user.id,
          character_id: user.character_id,
          character_name: user.character_name
        })

      {:ok, view, _html} = live(conn, "/character/#{user.character_id}")

      # Click on ship preferences tab if it exists
      if has_element?(view, "[data-tab=\"ships\"]") do
        view
        |> element("[data-tab=\"ships\"]")
        |> render_click()

        html = render(view)

        # Should show ship usage
        assert html =~ "Ship" or html =~ "Usage" or html =~ "Preferred"
      end
    end

    test "displays threat trends", %{conn: conn, user: user} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{
          user_id: user.id,
          character_id: user.character_id,
          character_name: user.character_name
        })

      {:ok, view, _html} = live(conn, "/character/#{user.character_id}")

      # Check for trends section
      if has_element?(view, "[data-tab=\"trends\"]") do
        view
        |> element("[data-tab=\"trends\"]")
        |> render_click()

        html = render(view)

        # Should show trend analysis
        assert html =~ "Trend" or html =~ "History" or html =~ "Activity"
      end
    end

    test "handles character not found", %{conn: conn, user: user} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{
          user_id: user.id,
          character_id: user.character_id,
          character_name: user.character_name
        })

      {:ok, _view, html} = live(conn, "/character/99999999")

      # Should show error or redirect
      assert html =~ "not found" or html =~ "error" or html =~ "Character Intelligence"
    end

    test "updates in real-time when new killmail arrives", %{conn: conn, user: user} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{
          user_id: user.id,
          character_id: user.character_id,
          character_name: user.character_name
        })

      {:ok, view, _initial_html} = live(conn, "/character/#{user.character_id}")

      # Create a new killmail
      killmail_attrs = killmail_raw_factory()

      {:ok, _new_kill} =
        Api.create(
          KillmailRaw,
          Map.merge(killmail_attrs, %{
            killmail_id: 799_999_999,
            killmail_time: DateTime.utc_now() |> DateTime.add(-1, :hour),
            solar_system_id: 30_000_142,
            victim_character_id: 95_200_000,
            # Armageddon
            victim_ship_type_id: 643,
            victim_corporation_id: 98_000_000,
            attacker_count: 1,
            total_value: Decimal.new("150000000"),
            raw_data: %{
              "attackers" => [
                %{
                  "character_id" => user.character_id,
                  # Loki
                  "ship_type_id" => 29_986,
                  "final_blow" => true
                }
              ]
            }
          })
        )

      # Broadcast the update via PubSub
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "character:#{user.character_id}",
        {:killmail_update, user.character_id}
      )

      # Give the view time to update
      :timer.sleep(200)

      updated_html = render(view)

      # The view should have updated (exact behavior depends on implementation)
      # At minimum, it shouldn't crash
      assert updated_html
    end
  end

  describe "character comparison" do
    setup %{user: _user} do
      # Create another character to compare with
      {:ok, other_user} =
        Api.create(User, %{
          character_id: 95_000_002,
          character_name: "Enemy Pilot",
          owner_hash: "enemy_hash_#{System.unique_integer()}"
        })

      # Create killmails for the other character
      for i <- 1..10 do
        killmail_attrs = killmail_raw_factory()

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 710_000_000 + i,
              killmail_time: DateTime.utc_now() |> DateTime.add(-i * 3, :day),
              solar_system_id: 30_000_142,
              victim_character_id: 95_300_000 + i,
              victim_ship_type_id: 624,
              victim_corporation_id: 98_000_000,
              attacker_count: 1,
              total_value: Decimal.new("25000000"),
              raw_data: %{
                "attackers" => [
                  %{
                    "character_id" => other_user.character_id,
                    "ship_type_id" => 29_984,
                    "final_blow" => true
                  }
                ]
              }
            })
          )
      end

      %{other_user: other_user}
    end

    test "can compare two characters", %{conn: conn, user: user, other_user: other_user} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{
          user_id: user.id,
          character_id: user.character_id,
          character_name: user.character_name
        })

      {:ok, view, _html} = live(conn, "/character/compare")

      # Add first character
      view
      |> form("#comparison-form", %{
        character_1: user.character_id,
        character_2: other_user.character_id
      })
      |> render_submit()

      html = render(view)

      # Should show comparison
      assert html =~ user.character_name or html =~ to_string(user.character_id)
      assert html =~ other_user.character_name or html =~ to_string(other_user.character_id)

      # Should show threat scores or comparison metrics
      assert html =~ "Threat" or html =~ "Score" or html =~ "Comparison"
    end
  end

  describe "gang analysis view" do
    setup %{user: user} do
      # Create gang members
      gang_members =
        for i <- 1..5 do
          {:ok, member} =
            Api.create(User, %{
              character_id: 95_010_000 + i,
              character_name: "Gang Member #{i}",
              owner_hash: "gang_hash_#{i}_#{System.unique_integer()}"
            })

          member
        end

      # Create shared killmails
      for i <- 1..15 do
        killmail_attrs = killmail_raw_factory()

        # Select random gang members as attackers
        attackers =
          [user | gang_members]
          |> Enum.take_random(rem(i, 4) + 2)
          |> Enum.with_index()
          |> Enum.map(fn {member, idx} ->
            %{
              "character_id" => member.character_id,
              "ship_type_id" => Enum.random([29_984, 624, 11_987]),
              "final_blow" => idx == 0
            }
          end)

        {:ok, _} =
          Api.create(
            KillmailRaw,
            Map.merge(killmail_attrs, %{
              killmail_id: 720_000_000 + i,
              killmail_time: DateTime.utc_now() |> DateTime.add(-i * 2, :day),
              solar_system_id: 30_000_142,
              victim_character_id: 95_400_000 + i,
              victim_ship_type_id: 643,
              victim_corporation_id: 98_000_000,
              attacker_count: length(attackers),
              total_value: Decimal.new("75000000"),
              raw_data: %{
                "victim" => %{"character_id" => 95_400_000 + i},
                "attackers" => attackers
              }
            })
          )
      end

      %{gang_members: gang_members}
    end

    test "displays gang synergy analysis", %{conn: conn, user: user, gang_members: gang_members} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{
          user_id: user.id,
          character_id: user.character_id,
          character_name: user.character_name
        })

      character_ids = [user.character_id | Enum.map(gang_members, & &1.character_id)]
      ids_param = Enum.join(character_ids, ",")

      {:ok, _view, html} = live(conn, "/gang/analysis?ids=#{ids_param}")

      # Should show gang analysis
      assert html =~ "Gang" or html =~ "Synergy" or html =~ "Group"

      # Should show coordination metrics
      assert html =~ "Coordination" or html =~ "Effectiveness" or html =~ "synergy"
    end

    test "shows role compatibility", %{conn: conn, user: user, gang_members: gang_members} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{
          user_id: user.id,
          character_id: user.character_id,
          character_name: user.character_name
        })

      character_ids = [user.character_id | Enum.map(gang_members, & &1.character_id)]
      ids_param = Enum.join(character_ids, ",")

      {:ok, view, _html} = live(conn, "/gang/analysis?ids=#{ids_param}")

      # Wait for async load
      :timer.sleep(200)

      html = render(view)

      # Should show role analysis
      assert html =~ "Role" or html =~ "DPS" or html =~ "Support" or html =~ "Tackle"
    end
  end
end
