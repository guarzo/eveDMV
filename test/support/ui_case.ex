defmodule EveDmv.UICase do
  @moduledoc """
  UI testing framework for Phoenix LiveView components and pages.

  Provides utilities for testing LiveView interactions, component rendering,
  user authentication flows, and real-time features.
  """

  use ExUnit.CaseTemplate

  # Import necessary functions at module level
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import EveDmv.Factories
  import Plug.Conn, only: [get_resp_header: 2]

  alias Ecto.Adapters.SQL.Sandbox

  @endpoint EveDmvWeb.Endpoint

  # Default test timeouts
  @default_timeout 5_000
  # @long_timeout 15_000

  using do
    quote do
      # Import ConnTest for HTTP testing
      use Phoenix.ConnTest

      # Import LiveViewTest for LiveView testing
      import Phoenix.LiveViewTest

      # Import test helpers
      import EveDmv.UICase
      import EveDmv.Factories

      # Set up endpoint
      @endpoint EveDmvWeb.Endpoint

      # Default test timeouts
      @default_timeout 5_000
      @long_timeout 15_000
    end
  end

  setup tags do
    # Set up database
    :ok = Sandbox.checkout(EveDmv.Repo)

    unless tags[:async] do
      Sandbox.mode(EveDmv.Repo, {:shared, self()})
    end

    # Create test user if needed
    user =
      if tags[:authenticated] do
        create_test_user()
      else
        nil
      end

    %{user: user}
  end

  @doc """
  Creates a test user with EVE SSO authentication.
  """
  def create_test_user(attrs \\ %{}) do
    default_attrs = %{
      character_id: Enum.random(90_000_000..99_999_999),
      character_name: "Test Pilot #{System.unique_integer()}",
      corporation_id: 1_000_001,
      corporation_name: "Test Corporation",
      alliance_id: 99_000_001,
      alliance_name: "Test Alliance"
    }

    attrs = Map.merge(default_attrs, attrs)

    create(:user, attrs)
  end

  @doc """
  Logs in a user and returns an authenticated connection.
  """
  def log_in_user(conn, user) do
    token = create(:token, user_id: user.id, character_id: user.character_id)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token.access_token)
    |> Plug.Conn.put_session(:current_user, user)
  end

  @doc """
  Creates an authenticated LiveView connection.
  """
  def authenticated_lv_conn(user \\ nil) do
    user = user || create_test_user()

    conn = Phoenix.ConnTest.build_conn()
    log_in_user(conn, user)
  end

  @doc """
  Navigates to a LiveView and waits for it to load.
  """
  def navigate_to_liveview(conn, path, _timeout \\ @default_timeout) do
    {:ok, view, html} = live(conn, path)

    # Wait for initial render
    Process.sleep(100)

    {view, html}
  end

  @doc """
  Waits for a specific element to appear on the page.
  """
  def wait_for_element(view, selector, timeout \\ @default_timeout) do
    end_time = System.monotonic_time(:millisecond) + timeout
    wait_for_element_loop(view, selector, end_time)
  end

  defp wait_for_element_loop(view, selector, end_time) do
    if System.monotonic_time(:millisecond) > end_time do
      flunk("Element '#{selector}' not found within timeout")
    end

    html = render(view)

    if html =~ ~r/#{Regex.escape(selector)}/ do
      :ok
    else
      Process.sleep(100)
      wait_for_element_loop(view, selector, end_time)
    end
  end

  @doc """
  Waits for text content to appear on the page.
  """
  def wait_for_text(view, text, timeout \\ @default_timeout) do
    end_time = System.monotonic_time(:millisecond) + timeout
    wait_for_text_loop(view, text, end_time)
  end

  defp wait_for_text_loop(view, text, end_time) do
    if System.monotonic_time(:millisecond) > end_time do
      flunk("Text '#{text}' not found within timeout")
    end

    html = render(view)

    if html =~ text do
      :ok
    else
      Process.sleep(100)
      wait_for_text_loop(view, text, end_time)
    end
  end

  @doc """
  Simulates typing in a form field.
  """
  def type_in_field(view, field_selector, value) do
    view
    |> form(field_selector)
    |> render_change(%{field_selector => value})
  end

  @doc """
  Simulates clicking a button or link.
  """
  def click_element(view, selector) do
    view
    |> element(selector)
    |> render_click()
  end

  @doc """
  Submits a form and waits for response.
  """
  def submit_form(view, form_selector, form_data \\ %{}) do
    view
    |> form(form_selector, form_data)
    |> render_submit()
  end

  @doc """
  Waits for a LiveView to receive a specific message.
  """
  def wait_for_message(view, message, timeout \\ @default_timeout) do
    end_time = System.monotonic_time(:millisecond) + timeout
    wait_for_message_loop(view, message, end_time)
  end

  defp wait_for_message_loop(view, message, end_time) do
    if System.monotonic_time(:millisecond) > end_time do
      flunk("Message '#{inspect(message)}' not received within timeout")
    end

    receive do
      ^message -> :ok
    after
      100 -> wait_for_message_loop(view, message, end_time)
    end
  end

  @doc """
  Simulates real-time data updates via PubSub.
  """
  def simulate_pubsub_broadcast(topic, event, payload \\ %{}) do
    Phoenix.PubSub.broadcast(EveDmv.PubSub, topic, {event, payload})
    # Allow time for LiveView to process
    Process.sleep(50)
  end

  @doc """
  Creates test killmail data for UI testing.
  """
  def create_test_killmail(attrs \\ %{}) do
    default_attrs = %{
      killmail_id: System.unique_integer([:positive]),
      killmail_time: DateTime.utc_now(),
      solar_system_id: 30_000_142,
      solar_system_name: "Jita",
      total_value: Decimal.new("50_000_000"),
      victim_character_id: Enum.random(90_000_000..99_999_999),
      victim_character_name: "Test Victim",
      victim_ship_name: "Rifter"
    }

    attrs = Map.merge(default_attrs, attrs)
    create(:killmail_enriched, attrs)
  end

  @doc """
  Creates test character intelligence data.
  """
  def create_test_character_stats(attrs \\ %{}) do
    default_attrs = %{
      character_id: Enum.random(90_000_000..99_999_999),
      character_name: "Test Character",
      corporation_id: 1_000_001,
      corporation_name: "Test Corp",
      kill_count: 50,
      loss_count: 20,
      kd_ratio: 2.5,
      dangerous_rating: 3,
      completeness_score: 85,
      analysis_data:
        Jason.encode!(%{
          "basic_stats" => %{
            "kills" => %{"count" => 50, "solo" => 15},
            "losses" => %{"count" => 20, "solo" => 5}
          },
          "ship_usage" => %{
            "favorite_ships" => ["Rifter", "Punisher", "Merlin"]
          },
          "behavioral_patterns" => %{
            "aggression_level" => "Moderate",
            "risk_aversion" => "Low"
          }
        })
    }

    attrs = Map.merge(default_attrs, attrs)
    create(:character_stats, attrs)
  end

  @doc """
  Asserts that an element is visible on the page.
  """
  def assert_element_visible(view, selector) do
    html = render(view)

    assert html =~ ~r/#{Regex.escape(selector)}/,
           "Element '#{selector}' not found in rendered HTML"
  end

  @doc """
  Asserts that text is present on the page.
  """
  def assert_text_present(view, text) do
    html = render(view)

    assert html =~ text,
           "Text '#{text}' not found in rendered HTML"
  end

  @doc """
  Asserts that an element has specific attributes.
  """
  def assert_element_attributes(view, selector, expected_attrs) do
    html = render(view)

    for {attr, expected_value} <- expected_attrs do
      pattern = "#{selector}[^>]*#{attr}\\s*=\\s*[\"']#{Regex.escape(expected_value)}[\"']"

      assert html =~ ~r/#{pattern}/,
             "Element '#{selector}' does not have #{attr}='#{expected_value}'"
    end
  end

  @doc """
  Asserts that a form field has a specific value.
  """
  def assert_field_value(view, field_name, expected_value) do
    html = render(view)

    # Check for input field
    input_pattern =
      "input[^>]*name\\s*=\\s*[\"']#{field_name}[\"'][^>]*value\\s*=\\s*[\"']#{Regex.escape(expected_value)}[\"']"

    # Check for textarea
    textarea_pattern =
      "textarea[^>]*name\\s*=\\s*[\"']#{field_name}[\"'][^>]*>#{Regex.escape(expected_value)}</textarea>"

    assert html =~ ~r/#{input_pattern}/ or html =~ ~r/#{textarea_pattern}/,
           "Field '#{field_name}' does not have value '#{expected_value}'"
  end

  @doc """
  Verifies that authentication is required for a route.
  """
  def assert_authentication_required(conn, path) do
    conn = get(conn, path)

    # Should redirect to login or return 401/403
    assert conn.status in [302, 401, 403]

    if conn.status == 302 do
      # Check redirect location contains auth
      location_headers = get_resp_header(conn, "location")
      location = List.first(location_headers)
      assert location =~ ~r/(login|auth)/i
    end
  end

  @doc """
  Creates multiple test killmails for table/list testing.
  """
  def create_killmail_list(count \\ 10, base_attrs \\ %{}) do
    for i <- 1..count do
      attrs =
        Map.merge(base_attrs, %{
          killmail_id: 100_000 + i,
          killmail_time: DateTime.add(DateTime.utc_now(), -i * 3600, :second),
          victim_character_name: "Victim #{i}",
          total_value: Decimal.new("#{i * 10_000_000}")
        })

      create_test_killmail(attrs)
    end
  end

  @doc """
  Simulates user actions with realistic delays.
  """
  def simulate_user_interaction(view, actions) when is_list(actions) do
    for action <- actions do
      case action do
        {:click, selector} ->
          click_element(view, selector)
          Process.sleep(Enum.random(100..300))

        {:type, field, value} ->
          type_in_field(view, field, value)
          Process.sleep(Enum.random(50..150))

        {:wait, ms} ->
          Process.sleep(ms)

        {:submit, form_selector, data} ->
          submit_form(view, form_selector, data)
          Process.sleep(Enum.random(200..500))

        {:wait_for_text, text} ->
          wait_for_text(view, text)
      end
    end
  end

  @doc """
  Tests responsive design by simulating different viewport sizes.
  """
  def test_responsive_design(view, viewports \\ [:mobile, :tablet, :desktop]) do
    for viewport <- viewports do
      html = render(view)

      case viewport do
        :mobile ->
          # Check for mobile-specific elements/classes
          assert html =~ ~r/(mobile|sm:|block md:hidden)/

        :tablet ->
          # Check for tablet-specific elements/classes
          assert html =~ ~r/(tablet|md:|hidden lg:block)/

        :desktop ->
          # Check for desktop-specific elements/classes
          assert html =~ ~r/(desktop|lg:|hidden md:block)/
      end
    end
  end

  @doc """
  Verifies accessibility attributes are present.
  """
  def assert_accessibility_compliance(view) do
    html = render(view)

    # Check for basic accessibility attributes
    accessibility_checks = [
      # Images should have alt attributes
      {~r/<img[^>]*>/, ~r/<img[^>]*alt\s*=\s*[\"'][^\"']*[\"'][^>]*>/},

      # Form inputs should have labels or aria-label
      {~r/<input[^>]*type\s*=\s*[\"'](text|email|password)[\"'][^>]*>/,
       ~r/<(label[^>]*for\s*=\s*[\"'][^\"']*[\"']|input[^>]*aria-label\s*=\s*[\"'][^\"']*[\"'])/},

      # Buttons should have accessible text
      {~r/<button[^>]*>/, ~r/<button[^>]*>[^<]*\w+[^<]*<\/button>/}
    ]

    for {element_pattern, requirement_pattern} <- accessibility_checks do
      if html =~ element_pattern do
        assert html =~ requirement_pattern,
               "Accessibility requirement not met for elements matching #{inspect(element_pattern)}"
      end
    end
  end

  @doc """
  Performance testing helper for LiveView rendering.
  """
  def measure_render_performance(_view, action_fn, iterations \\ 10) do
    times =
      for _i <- 1..iterations do
        {time, _result} = :timer.tc(action_fn)
        # Convert to milliseconds
        time / 1_000
      end

    avg_time = Enum.sum(times) / length(times)
    max_time = Enum.max(times)
    min_time = Enum.min(times)

    %{
      avg_render_time_ms: avg_time,
      max_render_time_ms: max_time,
      min_render_time_ms: min_time,
      total_iterations: iterations
    }
  end

  @doc """
  Helper to test error handling in LiveViews.
  """
  def test_error_handling(view, error_trigger_fn) do
    # Capture any error messages
    Process.flag(:trap_exit, true)

    try do
      error_trigger_fn.()

      # Check if error is displayed gracefully
      html = render(view)

      # Should show user-friendly error message
      assert html =~ ~r/(error|sorry|try again|something went wrong)/i
    rescue
      error ->
        # LiveView should handle errors gracefully without crashing
        html = render(view)
        assert html != "", "LiveView crashed and returned empty HTML"

        {:error, error}
    after
      Process.flag(:trap_exit, false)
    end
  end

  @doc """
  Creates mock ESI responses for testing.
  """
  def mock_esi_response(character_id, response_data \\ nil) do
    default_response = %{
      "character_id" => character_id,
      "name" => "Test Character #{character_id}",
      "corporation_id" => 1_000_001,
      "alliance_id" => 99_000_001,
      "security_status" => 0.5,
      "birthday" => "2010-01-01T00:00:00Z"
    }

    response_data || default_response
  end
end
