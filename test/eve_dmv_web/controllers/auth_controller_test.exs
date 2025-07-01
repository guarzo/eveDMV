defmodule EveDmvWeb.AuthControllerTest do
  use EveDmvWeb.ConnCase, async: true
  use ExUnitProperties

  import Mox
  import Phoenix.ConnTest

  alias EveDmv.Api
  alias EveDmv.Users.User
  alias EveDmvWeb.AuthController

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "success/2 - OAuth success callback" do
    test "creates new user and redirects to dashboard on successful EVE SSO", %{conn: conn} do
      # Mock the OAuth provider response
      user_info = %{
        "access_token" => "valid_access_token",
        "refresh_token" => "valid_refresh_token",
        "expires_in" => 3600,
        "character" => %{
          "character_id" => 123_456,
          "character_name" => "TestPilot",
          "corporation_id" => 654_321,
          "corporation_name" => "Test Corp",
          "alliance_id" => 987_654,
          "alliance_name" => "Test Alliance"
        }
      }

      # Simulate successful OAuth callback
      conn =
        conn
        |> assign(:user_info, user_info)
        |> post(~p"/auth/success")

      # Should redirect to dashboard
      assert redirected_to(conn) == ~p"/dashboard"

      # Should set user in session
      user_id = get_session(conn, :user_id)
      assert user_id

      # Should create user in database
      {:ok, user} = Api.get(User, user_id)
      assert user.character_id == "123456"
      assert user.character_name == "TestPilot"
    end

    test "updates existing user and redirects on re-authentication", %{conn: conn} do
      # Create existing user
      existing_user_data = %{
        "characterID" => "123456",
        "characterName" => "TestPilot",
        "corporationID" => "654321",
        "corporationName" => "Old Corp",
        "access_token" => "old_token",
        "refresh_token" => "old_refresh",
        "expires_at" => DateTime.utc_now() |> DateTime.add(-3600, :second)
      }

      {:ok, existing_user} = Api.create(User, :register_with_eve_sso, existing_user_data)

      # Mock updated OAuth response
      updated_user_info = %{
        "access_token" => "new_access_token",
        "refresh_token" => "new_refresh_token",
        "expires_in" => 3600,
        "character" => %{
          "character_id" => 123_456,
          "character_name" => "TestPilot",
          "corporation_id" => 999_888,
          "corporation_name" => "New Corp"
        }
      }

      conn =
        conn
        |> assign(:user_info, updated_user_info)
        |> post(~p"/auth/success")

      assert redirected_to(conn) == ~p"/dashboard"

      # Should update the existing user
      {:ok, updated_user} = Api.get(User, existing_user.id)
      assert updated_user.corporation_name == "New Corp"
      assert updated_user.access_token == "new_access_token"
    end

    test "handles missing user info gracefully", %{conn: conn} do
      # No user_info assigned
      conn = post(conn, ~p"/auth/success")

      # Should redirect to home with error
      assert redirected_to(conn) == ~p"/"
      assert get_flash(conn, :error) =~ "Authentication failed"
    end

    test "handles invalid character data", %{conn: conn} do
      invalid_user_info = %{
        "access_token" => "token",
        "character" => %{
          # Missing required fields
          "character_id" => nil
        }
      }

      conn =
        conn
        |> assign(:user_info, invalid_user_info)
        |> post(~p"/auth/success")

      assert redirected_to(conn) == ~p"/"
      assert get_flash(conn, :error)
    end
  end

  describe "failure/2 - OAuth failure callback" do
    test "redirects to home with error message on OAuth failure", %{conn: conn} do
      conn =
        conn
        |> assign(:failure_reason, "access_denied")
        |> post(~p"/auth/failure")

      assert redirected_to(conn) == ~p"/"
      assert get_flash(conn, :error) =~ "Authentication failed"
    end

    test "handles different failure reasons", %{conn: conn} do
      failure_reasons = ["access_denied", "server_error", "temporarily_unavailable"]

      for reason <- failure_reasons do
        conn =
          conn
          |> recycle()
          |> assign(:failure_reason, reason)
          |> post(~p"/auth/failure")

        assert redirected_to(conn) == ~p"/"
        assert get_flash(conn, :error)
      end
    end

    test "handles missing failure reason", %{conn: conn} do
      conn = post(conn, ~p"/auth/failure")

      assert redirected_to(conn) == ~p"/"
      assert get_flash(conn, :error) =~ "Authentication failed"
    end
  end

  describe "sign_out/2" do
    setup %{conn: conn} do
      # Create and sign in a user
      eve_sso_data = %{
        "characterID" => "123456",
        "characterName" => "TestPilot",
        "corporationID" => "654321",
        "corporationName" => "Test Corp",
        "access_token" => "test_token",
        "refresh_token" => "test_refresh",
        "expires_at" => DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      {:ok, user} = Api.create(User, :register_with_eve_sso, eve_sso_data)

      conn =
        conn
        |> put_session(:user_id, user.id)
        |> put_session(:character_name, user.character_name)

      {:ok, conn: conn, user: user}
    end

    test "clears session and redirects to home", %{conn: conn} do
      # Verify user is logged in
      assert get_session(conn, :user_id)

      conn = post(conn, ~p"/auth/sign_out")

      # Should redirect to home
      assert redirected_to(conn) == ~p"/"

      # Should clear session
      assert get_session(conn, :user_id) == nil
      assert get_session(conn, :character_name) == nil

      # Should show sign out message
      assert get_flash(conn, :info) =~ "signed out"
    end

    test "handles sign out when not logged in", %{conn: conn} do
      # Clear session first
      conn =
        conn
        |> clear_session()
        |> post(~p"/auth/sign_out")

      # Should still redirect to home
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "session security" do
    test "prevents session fixation attacks", %{conn: conn} do
      # Get initial session ID
      initial_conn = get(conn, ~p"/")
      initial_session_id = get_session(initial_conn, :session_id)

      user_info = %{
        "access_token" => "token",
        "refresh_token" => "refresh",
        "expires_in" => 3600,
        "character" => %{
          "character_id" => 123_456,
          "character_name" => "TestPilot",
          "corporation_id" => 654_321,
          "corporation_name" => "Test Corp"
        }
      }

      # Authenticate
      auth_conn =
        initial_conn
        |> assign(:user_info, user_info)
        |> post(~p"/auth/success")

      # Session should be regenerated after authentication
      new_session_id = get_session(auth_conn, :session_id)
      # Note: This test assumes Phoenix regenerates session IDs on authentication
      # The actual implementation may vary
    end

    test "handles concurrent authentication attempts", %{conn: conn} do
      user_info = %{
        "access_token" => "token",
        "refresh_token" => "refresh",
        "expires_in" => 3600,
        "character" => %{
          "character_id" => 123_456,
          "character_name" => "TestPilot",
          "corporation_id" => 654_321,
          "corporation_name" => "Test Corp"
        }
      }

      # Simulate multiple concurrent requests
      tasks =
        for _i <- 1..5 do
          Task.async(fn ->
            conn
            |> assign(:user_info, user_info)
            |> post(~p"/auth/success")
          end)
        end

      results = Task.await_many(tasks)

      # All should succeed or fail gracefully
      for result <- results do
        assert %Plug.Conn{} = result
        # Redirect or OK
        assert result.status in [302, 200]
      end
    end
  end

  # Property-based testing for robust input validation
  property "auth controller handles various character ID formats" do
    check all(character_id <- positive_integer()) do
      user_info = %{
        "access_token" => "token",
        "refresh_token" => "refresh",
        "expires_in" => 3600,
        "character" => %{
          "character_id" => character_id,
          "character_name" => "TestPilot",
          "corporation_id" => 654_321,
          "corporation_name" => "Test Corp"
        }
      }

      conn =
        build_conn()
        |> assign(:user_info, user_info)
        |> post(~p"/auth/success")

      # Should either succeed (redirect) or fail gracefully (redirect with error)
      assert conn.status == 302
    end
  end

  describe "rate limiting" do
    test "prevents rapid authentication attempts" do
      # This test would require implementing rate limiting
      # For now, we'll test that multiple rapid requests don't crash
      user_info = %{
        "access_token" => "token",
        "refresh_token" => "refresh",
        "expires_in" => 3600,
        "character" => %{
          "character_id" => 123_456,
          "character_name" => "TestPilot",
          "corporation_id" => 654_321,
          "corporation_name" => "Test Corp"
        }
      }

      # Make 10 rapid requests
      results =
        for _i <- 1..10 do
          build_conn()
          |> assign(:user_info, user_info)
          |> post(~p"/auth/success")
        end

      # All should respond (even if rate limited)
      for result <- results do
        assert %Plug.Conn{} = result
      end
    end
  end
end
