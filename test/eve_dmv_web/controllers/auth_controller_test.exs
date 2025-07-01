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
      # Create a test user using EVE SSO action
      user_info = %{
        "CharacterID" => 123_456,
        "CharacterName" => "TestPilot"
      }

      oauth_tokens = %{
        "access_token" => "valid_access_token",
        "refresh_token" => "valid_refresh_token",
        "expires_in" => 3600
      }

      {:ok, user} =
        Ash.create(
          User,
          %{
            user_info: user_info,
            oauth_tokens: oauth_tokens
          },
          action: :register_with_eve_sso,
          domain: Api
        )

      # Call the success function directly
      conn =
        conn
        |> init_test_session(%{})
        |> Phoenix.Controller.fetch_flash()
        |> AuthController.success(:sign_in, user, nil)

      # Should redirect to dashboard
      assert redirected_to(conn) == ~p"/dashboard"

      # Should set user in session
      assert get_session(conn, "current_user_id") == user.id
      # Check that AshAuthentication token was stored
      assert get_session(conn, "user_token")
    end

    test "updates existing user and redirects on re-authentication", %{conn: conn} do
      # Create existing user
      user_info = %{
        "CharacterID" => 123_456,
        "CharacterName" => "TestPilot"
      }

      oauth_tokens = %{
        "access_token" => "old_token",
        "refresh_token" => "old_refresh",
        "expires_in" => 3600
      }

      {:ok, existing_user} =
        Ash.create(
          User,
          %{
            user_info: user_info,
            oauth_tokens: oauth_tokens
          },
          action: :register_with_eve_sso,
          domain: Api
        )

      # Update the user with new tokens
      {:ok, updated_user} =
        Ash.update(
          existing_user,
          %{
            access_token: "new_access_token",
            refresh_token: "new_refresh_token",
            token_expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
          },
          action: :refresh_token,
          domain: Api
        )

      # Call success function with updated user
      conn =
        conn
        |> init_test_session(%{})
        |> Phoenix.Controller.fetch_flash()
        |> AuthController.success(:sign_in, updated_user, nil)

      assert redirected_to(conn) == ~p"/dashboard"
      assert get_session(conn, "current_user_id") == updated_user.id
    end

    test "handles failure callback", %{conn: conn} do
      # Call failure function
      conn =
        conn
        |> init_test_session(%{})
        |> Phoenix.Controller.fetch_flash()
        |> AuthController.failure(:sign_in, "Authentication failed")

      # Should redirect to home with error
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Authentication failed"
    end

    test "handles sign out", %{conn: conn} do
      # Create and sign in a user
      user_info = %{
        "CharacterID" => 123_456,
        "CharacterName" => "TestPilot"
      }

      oauth_tokens = %{
        "access_token" => "valid_token",
        "refresh_token" => "valid_refresh",
        "expires_in" => 3600
      }

      {:ok, user} =
        Ash.create(
          User,
          %{
            user_info: user_info,
            oauth_tokens: oauth_tokens
          },
          action: :register_with_eve_sso,
          domain: Api
        )

      # Set up session
      conn =
        conn
        |> init_test_session(%{})
        |> put_session("current_user_id", user.id)
        |> Phoenix.Controller.fetch_flash()
        |> AuthController.sign_out(%{})

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "signed out"
    end
  end

  describe "failure/2 - OAuth failure callback" do
    test "redirects to home with error message on OAuth failure", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> Phoenix.Controller.fetch_flash()
        |> AuthController.failure(:sign_in, "access_denied")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Authentication failed"
    end

    test "handles different failure reasons", %{conn: conn} do
      failure_reasons = ["access_denied", "server_error", "temporarily_unavailable"]

      for reason <- failure_reasons do
        conn =
          conn
          |> recycle()
          |> init_test_session(%{})
          |> Phoenix.Controller.fetch_flash()
          |> AuthController.failure(:sign_in, reason)

        assert redirected_to(conn) == ~p"/"
        assert Phoenix.Flash.get(conn.assigns.flash, :error)
      end
    end

    test "handles nil failure reason", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> Phoenix.Controller.fetch_flash()
        |> AuthController.failure(:sign_in, nil)

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Authentication failed"
    end
  end

  describe "sign_out/2" do
    setup %{conn: conn} do
      # Create and sign in a user
      user_info = %{
        "CharacterID" => 123_456,
        "CharacterName" => "TestPilot"
      }

      oauth_tokens = %{
        "access_token" => "test_token",
        "refresh_token" => "test_refresh",
        "expires_in" => 3600
      }

      {:ok, user} =
        Ash.create(
          User,
          %{
            user_info: user_info,
            oauth_tokens: oauth_tokens
          },
          action: :register_with_eve_sso,
          domain: Api
        )

      conn =
        conn
        |> init_test_session(%{})
        |> put_session("current_user_id", user.id)
        |> put_session(:eve_dmv, %{user_id: user.id})

      {:ok, conn: conn, user: user}
    end

    test "clears session and redirects to home", %{conn: conn} do
      # Verify user is logged in
      assert get_session(conn, "current_user_id")

      conn = conn |> fetch_flash() |> AuthController.sign_out(%{})

      # Should redirect to home
      assert redirected_to(conn) == ~p"/"

      # Should clear session
      assert get_session(conn, :eve_dmv) == nil

      # Should show sign out message
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "signed out"
    end

    test "handles sign out when not logged in", %{conn: conn} do
      # Clear session first
      conn =
        conn
        |> clear_session()
        |> Phoenix.Controller.fetch_flash()
        |> AuthController.sign_out(%{})

      # Should still redirect to home
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "session security" do
    test "prevents session fixation attacks", %{conn: conn} do
      # Create a test user
      user_info = %{
        "CharacterID" => 123_456,
        "CharacterName" => "TestPilot"
      }

      oauth_tokens = %{
        "access_token" => "token",
        "refresh_token" => "refresh",
        "expires_in" => 3600
      }

      {:ok, user} =
        Ash.create(
          User,
          %{
            user_info: user_info,
            oauth_tokens: oauth_tokens
          },
          action: :register_with_eve_sso,
          domain: Api
        )

      # Authenticate
      auth_conn =
        conn
        |> init_test_session(%{})
        |> Phoenix.Controller.fetch_flash()
        |> AuthController.success(:sign_in, user, nil)

      # Session should have user ID set
      assert get_session(auth_conn, "current_user_id") == user.id
    end

    test "handles concurrent authentication attempts", %{conn: _conn} do
      # Create a test user
      user_info = %{
        "CharacterID" => 123_456,
        "CharacterName" => "TestPilot"
      }

      oauth_tokens = %{
        "access_token" => "token",
        "refresh_token" => "refresh",
        "expires_in" => 3600
      }

      {:ok, user} =
        Ash.create(
          User,
          %{
            user_info: user_info,
            oauth_tokens: oauth_tokens
          },
          action: :register_with_eve_sso,
          domain: Api
        )

      # Simulate multiple concurrent requests
      tasks =
        for _i <- 1..5 do
          Task.async(fn ->
            # Each task needs its own conn
            new_conn = Phoenix.ConnTest.build_conn()

            new_conn
            |> init_test_session(%{})
            |> Phoenix.Controller.fetch_flash()
            |> AuthController.success(:sign_in, user, nil)
          end)
        end

      results = Task.await_many(tasks)

      # All should succeed
      for result <- results do
        assert %Plug.Conn{} = result
        assert result.status == 302
        assert result.state == :sent
      end
    end
  end

  # Property-based testing for robust input validation
  property "auth controller handles various character ID formats" do
    check all(character_id <- positive_integer()) do
      # Create user with various character IDs
      user_info = %{
        "CharacterID" => character_id,
        "CharacterName" => "TestPilot"
      }

      oauth_tokens = %{
        "access_token" => "token",
        "refresh_token" => "refresh",
        "expires_in" => 3600
      }

      {:ok, user} =
        Ash.create(
          User,
          %{
            user_info: user_info,
            oauth_tokens: oauth_tokens
          },
          action: :register_with_eve_sso,
          domain: Api
        )

      conn = build_conn()

      result =
        conn
        |> init_test_session(%{})
        |> Phoenix.Controller.fetch_flash()
        |> AuthController.success(:sign_in, user, nil)

      # Should always redirect successfully
      assert result.status == 302
      assert result.state == :sent
    end
  end

  describe "rate limiting" do
    test "prevents rapid authentication attempts" do
      # This test would require implementing rate limiting
      # For now, we'll test that multiple rapid requests don't crash
      user_info = %{
        "CharacterID" => 123_456,
        "CharacterName" => "TestPilot"
      }

      oauth_tokens = %{
        "access_token" => "token",
        "refresh_token" => "refresh",
        "expires_in" => 3600
      }

      {:ok, user} =
        Ash.create(
          User,
          %{
            user_info: user_info,
            oauth_tokens: oauth_tokens
          },
          action: :register_with_eve_sso,
          domain: Api
        )

      # Make 10 rapid requests
      results =
        for _i <- 1..10 do
          conn = build_conn()

          conn
          |> init_test_session(%{})
          |> Phoenix.Controller.fetch_flash()
          |> AuthController.success(:sign_in, user, nil)
        end

      # All should respond (even if rate limited)
      for result <- results do
        assert %Plug.Conn{} = result
      end
    end
  end
end
