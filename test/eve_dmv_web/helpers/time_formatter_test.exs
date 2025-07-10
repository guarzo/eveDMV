defmodule EveDmvWeb.Helpers.TimeFormatterTest do
  use ExUnit.Case, async: true

  alias EveDmvWeb.Helpers.TimeFormatter

  describe "format_datetime/1" do
    test "formats datetime correctly" do
      dt = ~U[2024-01-15 14:30:00Z]
      assert TimeFormatter.format_datetime(dt) == "2024-01-15 14:30:00 UTC"
    end

    test "handles nil" do
      assert TimeFormatter.format_datetime(nil) == "N/A"
    end

    test "formats datetime with different time zones correctly" do
      dt = ~U[2023-12-25 23:59:59Z]
      assert TimeFormatter.format_datetime(dt) == "2023-12-25 23:59:59 UTC"
    end
  end

  describe "format_relative_time/1" do
    test "formats seconds ago" do
      now = DateTime.utc_now()
      past = DateTime.add(now, -30, :second)
      result = TimeFormatter.format_relative_time(past)

      assert result =~ ~r/\d+s ago/
      assert result =~ "30s ago"
    end

    test "formats minutes ago" do
      now = DateTime.utc_now()
      past = DateTime.add(now, -5 * 60, :second)
      result = TimeFormatter.format_relative_time(past)

      assert result =~ ~r/\d+m ago/
      assert result =~ "5m ago"
    end

    test "formats hours ago" do
      now = DateTime.utc_now()
      past = DateTime.add(now, -3 * 3600, :second)
      result = TimeFormatter.format_relative_time(past)

      assert result =~ ~r/\d+h ago/
      assert result =~ "3h ago"
    end

    test "formats days ago" do
      now = DateTime.utc_now()
      past = DateTime.add(now, -2 * 86_400, :second)
      result = TimeFormatter.format_relative_time(past)

      assert result =~ ~r/\d+d ago/
      assert result =~ "2d ago"
    end

    test "handles nil" do
      assert TimeFormatter.format_relative_time(nil) == "N/A"
    end

    test "handles edge case of 0 seconds" do
      now = DateTime.utc_now()
      result = TimeFormatter.format_relative_time(now)

      assert result =~ ~r/\d+s ago/
    end
  end

  describe "format_duration/1" do
    test "formats duration correctly" do
      assert TimeFormatter.format_duration(3661) == "1h 1m 1s"
    end

    test "formats zero duration" do
      assert TimeFormatter.format_duration(0) == "0h 0m 0s"
    end

    test "formats minutes only" do
      assert TimeFormatter.format_duration(125) == "0h 2m 5s"
    end

    test "formats hours only" do
      assert TimeFormatter.format_duration(7_200) == "2h 0m 0s"
    end

    test "handles large duration" do
      assert TimeFormatter.format_duration(90_061) == "25h 1m 1s"
    end

    test "handles nil" do
      assert TimeFormatter.format_duration(nil) == "N/A"
    end

    test "handles non-integer input" do
      assert TimeFormatter.format_duration("invalid") == "N/A"
    end
  end

  describe "format_friendly_time/1" do
    test "returns 'Never' for nil" do
      assert TimeFormatter.format_friendly_time(nil) == "Never"
    end

    test "returns 'Today' for today" do
      now = DateTime.utc_now()
      result = TimeFormatter.format_friendly_time(now)

      assert result == "Today"
    end

    test "returns 'Yesterday' for yesterday" do
      yesterday = DateTime.add(DateTime.utc_now(), -1, :day)
      result = TimeFormatter.format_friendly_time(yesterday)

      assert result == "Yesterday"
    end

    test "returns days ago for recent days" do
      three_days_ago = DateTime.add(DateTime.utc_now(), -3, :day)
      result = TimeFormatter.format_friendly_time(three_days_ago)

      assert result == "3 days ago"
    end

    test "returns weeks ago for recent weeks" do
      two_weeks_ago = DateTime.add(DateTime.utc_now(), -14, :day)
      result = TimeFormatter.format_friendly_time(two_weeks_ago)

      assert result == "2 weeks ago"
    end

    test "returns months ago for older dates" do
      two_months_ago = DateTime.add(DateTime.utc_now(), -60, :day)
      result = TimeFormatter.format_friendly_time(two_months_ago)

      assert result == "2 months ago"
    end
  end
end
