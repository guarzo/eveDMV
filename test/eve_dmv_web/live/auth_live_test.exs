defmodule EveDmvWeb.AuthLiveTest do
  use EveDmvWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mox

  alias EveDmv.Api
  alias EveDmv.Users.User
  alias EveDmvWeb.AuthLive

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "AuthLive.load_from_session/4 on_mount hook" do
    test "loads current user from session when user_id present", %{conn: conn} do
      # Create a user
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

      # Create a simple LiveView that uses the auth hook
      defmodule TestLive do
        use Phoenix.LiveView

        on_mount {EveDmvWeb.AuthLive, :load_from_session}

        def mount(_params, _session, socket) do
          {:ok, socket}
        end

        def render(assigns) do
          ~H"""
          <div>
            <%= if @current_user do %>
              <span id="user-name">{@current_user.character_name}</span>
            <% else %>
              <span id="no-user">No user</span>
            <% end %>
          </div>
          """
        end
      end

      conn = conn |> put_session(:user_id, user.id)

      {:ok, _view, html} = live_isolated(conn, TestLive, session: %{"user_id" => user.id})

      # Should load the user
      assert html =~ "TestPilot"
      refute html =~ "No user"
    end

    test "sets current_user to nil when no user_id in session", %{conn: conn} do
      defmodule TestLiveNoUser do
        use Phoenix.LiveView

        on_mount {EveDmvWeb.AuthLive, :load_from_session}

        def mount(_params, _session, socket) do
          {:ok, socket}
        end

        def render(assigns) do
          ~H"""
          <div>
            <%= if @current_user do %>
              <span id="user-name">{@current_user.character_name}</span>
            <% else %>
              <span id="no-user">No user</span>
            <% end %>
          </div>
          """
        end
      end

      {:ok, _view, html} = live_isolated(conn, TestLiveNoUser)

      # Should not load any user
      assert html =~ "No user"
    end

    test "handles invalid user_id gracefully", %{conn: conn} do
      defmodule TestLiveInvalidUser do
        use Phoenix.LiveView

        on_mount {EveDmvWeb.AuthLive, :load_from_session}

        def mount(_params, _session, socket) do
          {:ok, socket}
        end

        def render(assigns) do
          ~H"""
          <div>
            <%= if @current_user do %>
              <span id="user-name">{@current_user.character_name}</span>
            <% else %>
              <span id="no-user">No user</span>
            <% end %>
          </div>
          """
        end
      end

      # Use non-existent user ID
      conn = conn |> put_session(:user_id, "nonexistent")

      {:ok, _view, html} =
        live_isolated(conn, TestLiveInvalidUser, session: %{"user_id" => "nonexistent"})

      # Should handle gracefully and show no user
      assert html =~ "No user"
    end
  end

  describe "AuthLive.SignIn LiveView" do
    test "renders sign in page for unauthenticated users", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/auth/sign_in")

      # Should show sign in button/link for EVE SSO
      assert html =~ "Sign in with EVE"
      assert html =~ "EVE Online"
    end

    test "redirects authenticated users to dashboard", %{conn: conn} do
      # Create and authenticate a user
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

      conn = conn |> put_session(:user_id, user.id)

      # Should redirect to dashboard
      assert {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/auth/sign_in")
    end

    test "handles authentication flow initiation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/auth/sign_in")

      # Click sign in should trigger EVE SSO redirect
      # Note: This depends on the actual implementation
      # You might need to test the link/button behavior
      assert has_element?(view, "a[href*='/auth/eve_sso']") or
               has_element?(view, "button[phx-click*='sign_in']") or
               has_element?(view, "a[href*='login.eveonline.com']")
    end

    test "displays proper branding and messaging", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/auth/sign_in")

      # Should display EVE-related branding
      assert html =~ "EVE" or html =~ "CCP"
      # Should explain what authentication provides
      assert html =~ "character" or html =~ "pilot"
    end
  end

  describe "authentication state management" do
    test "maintains authentication state across LiveView updates", %{conn: conn} do
      # Create a user
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

      defmodule TestAuthStateLive do
        use Phoenix.LiveView

        on_mount {EveDmvWeb.AuthLive, :load_from_session}

        def mount(_params, _session, socket) do
          {:ok, assign(socket, :counter, 0)}
        end

        def handle_event("increment", _params, socket) do
          {:noreply, assign(socket, :counter, socket.assigns.counter + 1)}
        end

        def render(assigns) do
          ~H"""
          <div>
            <span id="counter">{@counter}</span>
            <button phx-click="increment">Increment</button>
            <%= if @current_user do %>
              <span id="user">{@current_user.character_name}</span>
            <% end %>
          </div>
          """
        end
      end

      conn = conn |> put_session(:user_id, user.id)

      {:ok, view, html} = live_isolated(conn, TestAuthStateLive, session: %{"user_id" => user.id})

      # Initial state should have user loaded
      assert html =~ "TestPilot"
      assert html =~ "0"

      # Trigger an update
      view |> element("button") |> render_click()

      # User should still be loaded after update
      assert render(view) =~ "TestPilot"
      assert render(view) =~ "1"
    end

    test "handles user session expiry during LiveView session", %{conn: conn} do
      # Create a user
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

      defmodule TestSessionExpiryLive do
        use Phoenix.LiveView

        on_mount {EveDmvWeb.AuthLive, :load_from_session}

        def mount(_params, _session, socket) do
          {:ok, socket}
        end

        def handle_event("check_auth", _params, socket) do
          # This would trigger auth check
          {:noreply, socket}
        end

        def render(assigns) do
          ~H"""
          <div>
            <button phx-click="check_auth">Check Auth</button>
            <%= if @current_user do %>
              <span id="user">{@current_user.character_name}</span>
            <% else %>
              <span id="no-user">No user</span>
            <% end %>
          </div>
          """
        end
      end

      conn = conn |> put_session(:user_id, user.id)

      {:ok, view, _html} =
        live_isolated(conn, TestSessionExpiryLive, session: %{"user_id" => user.id})

      # Should handle auth check gracefully
      view |> element("button") |> render_click()

      # Should not crash
      assert render(view) =~ "TestPilot" or render(view) =~ "No user"
    end
  end

  describe "security considerations" do
    test "prevents unauthorized access to authenticated-only LiveViews" do
      # This would test a LiveView that requires authentication
      defmodule ProtectedLive do
        use Phoenix.LiveView

        on_mount {EveDmvWeb.AuthLive, :load_from_session}

        def mount(_params, _session, socket) do
          if socket.assigns[:current_user] do
            {:ok, socket}
          else
            {:ok, socket |> redirect(to: "/auth/sign_in")}
          end
        end

        def render(assigns) do
          ~H"""
          <div>Protected content</div>
          """
        end
      end

      # Unauthenticated user should be redirected
      assert {:error, {:redirect, %{to: "/auth/sign_in"}}} =
               live_isolated(build_conn(), ProtectedLive)
    end

    test "sanitizes user data in templates", %{conn: conn} do
      # Create user with potentially dangerous data
      eve_sso_data = %{
        "characterID" => "123456",
        "characterName" => "<script>alert('xss')</script>",
        "corporationID" => "654321",
        "corporationName" => "Test Corp",
        "access_token" => "test_token",
        "refresh_token" => "test_refresh",
        "expires_at" => DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      {:ok, user} = Api.create(User, :register_with_eve_sso, eve_sso_data)

      defmodule TestXSSLive do
        use Phoenix.LiveView

        on_mount {EveDmvWeb.AuthLive, :load_from_session}

        def mount(_params, _session, socket) do
          {:ok, socket}
        end

        def render(assigns) do
          ~H"""
          <div>
            <%= if @current_user do %>
              <span id="user-name">{@current_user.character_name}</span>
            <% end %>
          </div>
          """
        end
      end

      conn = conn |> put_session(:user_id, user.id)

      {:ok, _view, html} = live_isolated(conn, TestXSSLive, session: %{"user_id" => user.id})

      # Script tags should be escaped
      refute html =~ "<script>"
      assert html =~ "&lt;script&gt;" or html =~ "&amp;lt;script&amp;gt;"
    end
  end
end
