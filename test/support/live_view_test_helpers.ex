defmodule EveDmvWeb.LiveViewTestHelpers do
  @moduledoc """
  Common test helpers for LiveView tests to reduce duplication.
  """

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import EveDmv.Factories

  @doc """
  Sets up an authenticated connection with a user session.
  This consolidates the common pattern used across all LiveView tests.
  """
  def setup_authenticated_conn(_context \\ %{}) do
    user = create(:user)

    conn =
      build_conn()
      |> init_test_session(%{})
      |> put_session(:current_user_id, user.id)

    {:ok, conn: conn, user: user}
  end

  @doc """
  Asserts common page elements are present.
  """
  def assert_page_loaded(html, page_title) do
    assert html =~ page_title
    refute html =~ "Internal Server Error"
    refute html =~ "Something went wrong"
  end

  @doc """
  Common assertions for metric displays.
  """
  def assert_metrics_displayed(html, metrics) do
    Enum.each(metrics, fn metric ->
      assert html =~ metric
    end)
  end

  @doc """
  Helper to render LiveView and handle common errors gracefully.
  """
  def render_live(conn, path) do
    case live(conn, path) do
      {:ok, view, html} -> {:ok, view, html}
      {:error, {:redirect, %{to: redirect_path}}} -> {:redirect, redirect_path}
      error -> error
    end
  end

  @doc """
  Common filter assertions for list views.
  """
  def assert_filters_present(html, filters) do
    Enum.each(filters, fn filter ->
      assert html =~ filter
    end)
  end

  @doc """
  Helper to test form submissions in LiveView.
  """
  def submit_form(view, form_selector, params) do
    view
    |> form(form_selector, params)
    |> render_submit()
  end

  @doc """
  Helper to test select changes in LiveView.
  """
  def change_select(view, select_selector, value) do
    view
    |> element(select_selector)
    |> render_change(%{value => value})
  end

  @doc """
  Common setup for surveillance-related tests.
  """
  def setup_surveillance_services(_context \\ %{}) do
    # Ensure required services are started
    services = [
      EveDmv.Contexts.Surveillance.Domain.AlertService,
      EveDmv.Contexts.Surveillance.Domain.MatchingEngine
    ]

    Enum.each(services, fn service ->
      case Process.whereis(service) do
        nil -> start_supervised!(service)
        pid when is_pid(pid) -> :ok
      end
    end)

    :ok
  end
end
