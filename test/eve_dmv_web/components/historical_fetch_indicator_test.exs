defmodule EveDmvWeb.Components.HistoricalFetchIndicatorTest do
  @moduledoc """
  Tests for the HistoricalFetchIndicator component.

  Tests all component states:
  - nil (loading)
  - pending (loading)
  - phase1_complete (queued)
  - in_progress (progress bar)
  - completed (checkmark)
  - failed (error with retry)
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias EveDmvWeb.Components.HistoricalFetchIndicator

  @entity_type :character
  @entity_id 12_345

  describe "historical_fetch_indicator/1" do
    test "renders loading state when status is nil" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: nil,
          entity_type: @entity_type,
          entity_id: @entity_id
        )

      assert html =~ "Loading recent data..."
      assert html =~ "animate-spin"
      assert html =~ "historical-fetch-indicator"
    end

    test "renders loading state when status is pending" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{status: :pending},
          entity_type: @entity_type,
          entity_id: @entity_id
        )

      assert html =~ "Loading recent data..."
      assert html =~ "animate-spin"
    end

    test "renders queued state when status is phase1_complete" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{status: :phase1_complete},
          entity_type: @entity_type,
          entity_id: @entity_id
        )

      assert html =~ "2-year history queued"
      assert html =~ "text-blue-400"
      # Check for clock icon path
      assert html =~ "M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
    end

    test "renders progress state when status is in_progress" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{status: :in_progress, killmails_fetched: 1500},
          entity_type: @entity_type,
          entity_id: @entity_id
        )

      assert html =~ "Loading 2-year history..."
      assert html =~ "1500 kills"
      assert html =~ "text-yellow-400"
      assert html =~ "bg-yellow-400"
      # Progress bar container
      assert html =~ "bg-gray-700"
    end

    test "renders progress state with zero killmails" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{status: :in_progress},
          entity_type: @entity_type,
          entity_id: @entity_id
        )

      assert html =~ "Loading 2-year history..."
      assert html =~ "0 kills"
    end

    test "renders completed state when status is completed" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{status: :completed, killmails_fetched: 5000},
          entity_type: @entity_type,
          entity_id: @entity_id
        )

      assert html =~ "2-year history complete"
      assert html =~ "(5000 kills)"
      assert html =~ "text-green-400"
      # Check for checkmark icon path
      assert html =~ "M5 13l4 4L19 7"
    end

    test "renders completed state with zero killmails" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{status: :completed},
          entity_type: @entity_type,
          entity_id: @entity_id
        )

      assert html =~ "2-year history complete"
      assert html =~ "(0 kills)"
    end

    test "renders failed state with retry button" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{status: :failed},
          entity_type: @entity_type,
          entity_id: @entity_id
        )

      assert html =~ "History load failed"
      assert html =~ "Retry"
      assert html =~ "text-red-400"
      assert html =~ "phx-click=\"retry_historical_fetch\""
      assert html =~ "phx-value-entity_type=\"#{@entity_type}\""
      assert html =~ "phx-value-entity_id=\"#{@entity_id}\""
    end

    test "renders loading state for unknown status" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{status: :unknown_state},
          entity_type: @entity_type,
          entity_id: @entity_id
        )

      assert html =~ "Loading recent data..."
    end

    test "applies custom class" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: nil,
          entity_type: @entity_type,
          entity_id: @entity_id,
          class: "my-custom-class"
        )

      assert html =~ "historical-fetch-indicator my-custom-class"
    end
  end

  describe "different entity types" do
    test "renders for character entity type" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{status: :failed},
          entity_type: :character,
          entity_id: 123
        )

      assert html =~ "phx-value-entity_type=\"character\""
      assert html =~ "phx-value-entity_id=\"123\""
    end

    test "renders for corporation entity type" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{status: :failed},
          entity_type: :corporation,
          entity_id: 456
        )

      assert html =~ "phx-value-entity_type=\"corporation\""
      assert html =~ "phx-value-entity_id=\"456\""
    end

    test "renders for system entity type" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{status: :failed},
          entity_type: :system,
          entity_id: 789
        )

      assert html =~ "phx-value-entity_type=\"system\""
      assert html =~ "phx-value-entity_id=\"789\""
    end

    test "renders for alliance entity type" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{status: :failed},
          entity_type: :alliance,
          entity_id: 999
        )

      assert html =~ "phx-value-entity_type=\"alliance\""
      assert html =~ "phx-value-entity_id=\"999\""
    end
  end

  describe "progress calculation" do
    test "shows 100% progress when we've fetched back to target date" do
      today = Date.utc_today()
      # Target is 730 days ago (2 years)
      target_date = Date.add(today, -730)
      # We've fetched all the way back to the target date
      oldest_killmail_date = target_date

      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{
            status: :in_progress,
            oldest_killmail_date: oldest_killmail_date,
            target_date: target_date
          },
          entity_type: @entity_type,
          entity_id: @entity_id
        )

      # Should show 100% width
      assert html =~ "width: 100%"
    end

    test "shows partial progress based on dates" do
      today = Date.utc_today()
      # Target is 730 days ago (2 years)
      target_date = Date.add(today, -730)
      # We've fetched up to 365 days ago (50% progress)
      oldest_killmail_date = Date.add(today, -365)

      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{
            status: :in_progress,
            oldest_killmail_date: oldest_killmail_date,
            target_date: target_date
          },
          entity_type: @entity_type,
          entity_id: @entity_id
        )

      # Should show approximately 50% width
      assert html =~ "width: 50%"
    end

    test "shows 10% progress when no date information available" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{status: :in_progress},
          entity_type: @entity_type,
          entity_id: @entity_id
        )

      # Default progress is 10%
      assert html =~ "width: 10%"
    end

    test "caps progress at 100%" do
      today = Date.utc_today()
      # Edge case: oldest_killmail_date is before target_date
      target_date = Date.add(today, -365)
      oldest_killmail_date = Date.add(today, -730)

      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{
            status: :in_progress,
            oldest_killmail_date: oldest_killmail_date,
            target_date: target_date
          },
          entity_type: @entity_type,
          entity_id: @entity_id
        )

      # Should cap at 100%
      assert html =~ "width: 100%"
    end
  end

  describe "accessibility" do
    test "queued state has title attribute" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{status: :phase1_complete},
          entity_type: @entity_type,
          entity_id: @entity_id
        )

      assert html =~ "title=\"Historical data will be loaded in the background\""
    end

    test "completed state has title with killmail count" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{status: :completed, killmails_fetched: 2500},
          entity_type: @entity_type,
          entity_id: @entity_id
        )

      assert html =~ "title=\"2-year history loaded: 2500 killmails\""
    end

    test "retry button is interactive" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{status: :failed},
          entity_type: @entity_type,
          entity_id: @entity_id
        )

      # Button should have hover state classes
      assert html =~ "hover:text-blue-300"
    end
  end

  describe "CSS classes" do
    test "loading state has text-gray-400" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: nil,
          entity_type: @entity_type,
          entity_id: @entity_id
        )

      assert html =~ "text-gray-400"
    end

    test "progress state has transition classes" do
      html =
        render_component(&HistoricalFetchIndicator.historical_fetch_indicator/1,
          status: %{status: :in_progress, killmails_fetched: 100},
          entity_type: @entity_type,
          entity_id: @entity_id
        )

      assert html =~ "transition-all"
      assert html =~ "duration-500"
    end
  end
end
