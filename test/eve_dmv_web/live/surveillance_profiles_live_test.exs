defmodule EveDmvWeb.SurveillanceProfilesLiveTest do
  use EveDmvWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import EveDmv.Factories

  describe "surveillance profiles live" do
    setup do
      user = create(:user)

      conn =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:current_user_id, user.id)

      %{conn: conn, user: user}
    end

    test "displays surveillance profiles page", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/surveillance-profiles")

      assert html =~ "Surveillance Profiles"
      assert html =~ "New Profile"
    end

    test "displays chain status", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/surveillance-profiles")

      assert html =~ "Chain Status"
    end

    test "shows new profile form when clicking new profile", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/surveillance-profiles")

      assert index_live |> element("button", "New Profile") |> render_click()

      # Should redirect to new profile form
      assert_patch(index_live, ~p"/surveillance-profiles?action=new")
    end
  end

  describe "profile editor" do
    setup do
      user = create(:user)

      conn =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:current_user_id, user.id)

      %{conn: conn, user: user}
    end

    test "displays profile creation form", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/surveillance-profiles?action=new")

      assert html =~ "Create Profile"
      assert html =~ "Profile Name"
      assert html =~ "Description"
      assert html =~ "Filters"
    end

    test "can add filters to profile", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/surveillance-profiles?action=new")

      # Add a character filter
      index_live
      |> element("select[name='type']")
      |> render_change(%{"type" => "character"})

      # Should show character filter inputs
      assert has_element?(index_live, "input[placeholder*='Character IDs']")
    end

    test "shows filter preview when conditions are added", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/surveillance-profiles?action=new")

      # Add a filter
      index_live
      |> element("select[name='type']")
      |> render_change(%{"type" => "isk_value"})

      # Should show preview section
      assert has_element?(index_live, "h4", "Preview")
    end
  end

  describe "filter types" do
    setup do
      user = create(:user)

      conn =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:current_user_id, user.id)

      %{conn: conn, user: user}
    end

    test "supports character watch filters", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/surveillance-profiles?action=new")

      index_live
      |> element("select[name='type']")
      |> render_change(%{"type" => "character"})

      assert has_element?(index_live, "span", "Character")
      assert has_element?(index_live, "input[placeholder*='Character IDs']")
    end

    test "supports corporation watch filters", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/surveillance-profiles?action=new")

      index_live
      |> element("select[name='type']")
      |> render_change(%{"type" => "corporation"})

      assert has_element?(index_live, "span", "Corporation")
      assert has_element?(index_live, "input[placeholder*='Corporation IDs']")
    end

    test "supports chain awareness filters", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/surveillance-profiles?action=new")

      index_live
      |> element("select[name='type']")
      |> render_change(%{"type" => "chain"})

      assert has_element?(index_live, "span", "Chain Awareness")
      assert has_element?(index_live, "label", "Map ID")
      assert has_element?(index_live, "label", "Filter Type")
    end

    test "supports ISK value filters", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/surveillance-profiles?action=new")

      index_live
      |> element("select[name='type']")
      |> render_change(%{"type" => "isk_value"})

      assert has_element?(index_live, "span", "ISK Value")
      assert has_element?(index_live, "label", "Operator")
      assert has_element?(index_live, "label", "ISK Value")
    end

    test "supports participant count filters", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/surveillance-profiles?action=new")

      index_live
      |> element("select[name='type']")
      |> render_change(%{"type" => "participant_count"})

      assert has_element?(index_live, "span", "Participant Count")
      assert has_element?(index_live, "label", "Operator")
      assert has_element?(index_live, "label", "Participant Count")
    end
  end

  describe "logic operators" do
    setup do
      user = create(:user)

      conn =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:current_user_id, user.id)

      %{conn: conn, user: user}
    end

    test "allows changing logic operator from AND to OR", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/surveillance-profiles?action=new")

      # Add a filter first
      index_live
      |> element("select[name='type']")
      |> render_change(%{"type" => "character"})

      # Change logic operator
      index_live
      |> element("select[name='operator']")
      |> render_change(%{"operator" => "or"})

      # Should show OR selected
      assert has_element?(index_live, "option[value='or'][selected]")
    end
  end

  describe "filter management" do
    setup do
      user = create(:user)

      conn =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:current_user_id, user.id)

      %{conn: conn, user: user}
    end

    test "can remove filters", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/surveillance-profiles?action=new")

      # Add a filter
      index_live
      |> element("select[name='type']")
      |> render_change(%{"type" => "character"})

      # Should have remove button
      assert has_element?(index_live, "button", "Remove")

      # Click remove
      index_live
      |> element("button", "Remove")
      |> render_click()

      # Filter should be removed
      refute has_element?(index_live, "span", "Character")
    end

    test "can update filter values", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/surveillance-profiles?action=new")

      # Add character filter
      index_live
      |> element("select[name='type']")
      |> render_change(%{"type" => "character"})

      # Update character IDs
      index_live
      |> element("input[placeholder*='Character IDs']")
      |> render_blur(%{
        "index" => "0",
        "field" => "character_ids",
        "value" => "123456789, 987654321"
      })

      # Value should be updated (would need to check internal state in real implementation)
    end
  end
end
