defmodule EveDmvWeb.Helpers.TimeFormatter do
  @moduledoc """
  Shared time formatting functions for LiveView modules.
  """

  # Time constants in seconds
  @seconds_per_minute 60
  @seconds_per_hour 3_600
  @seconds_per_day 86_400
  @days_per_week 7
  @days_per_month 30

  @doc """
  Formats a DateTime to a standard string format.
  """
  @spec format_datetime(DateTime.t() | nil) :: String.t()
  def format_datetime(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end

  def format_datetime(nil), do: "N/A"

  @doc """
  Formats a DateTime as relative time (e.g., "5m ago", "2h ago").
  """
  @spec format_relative_time(DateTime.t() | nil) :: String.t()
  def format_relative_time(%DateTime{} = datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime)

    cond do
      diff < @seconds_per_minute -> "#{diff}s ago"
      diff < @seconds_per_hour -> "#{div(diff, @seconds_per_minute)}m ago"
      diff < @seconds_per_day -> "#{div(diff, @seconds_per_hour)}h ago"
      true -> "#{div(diff, @seconds_per_day)}d ago"
    end
  end

  def format_relative_time(nil), do: "N/A"

  @doc """
  Formats a duration in seconds to a human-readable format.
  """
  @spec format_duration(integer()) :: String.t()
  def format_duration(seconds) when is_integer(seconds) do
    hours = div(seconds, @seconds_per_hour)
    minutes = div(rem(seconds, @seconds_per_hour), @seconds_per_minute)
    seconds = rem(seconds, @seconds_per_minute)

    "#{hours}h #{minutes}m #{seconds}s"
  end

  def format_duration(_), do: "N/A"

  @doc """
  Formats a DateTime to a friendly, human-readable format.

  Returns "Never" for nil, "Today", "Yesterday", "X days ago",
  "X weeks ago", or "X months ago" as appropriate.
  """
  @spec format_friendly_time(DateTime.t() | nil) :: String.t()
  def format_friendly_time(nil), do: "Never"

  def format_friendly_time(%DateTime{} = datetime) do
    now = DateTime.utc_now()
    diff_days = DateTime.diff(now, datetime, :day)

    cond do
      diff_days == 0 -> "Today"
      diff_days == 1 -> "Yesterday"
      diff_days < 7 -> "#{diff_days} days ago"
      diff_days < @days_per_month -> "#{div(diff_days, @days_per_week)} weeks ago"
      true -> "#{div(diff_days, @days_per_month)} months ago"
    end
  end

  def format_friendly_time(%NaiveDateTime{} = datetime) do
    # Convert NaiveDateTime to DateTime (assuming UTC)
    datetime
    DateTime.from_naive!("Etc/UTC")

    format_friendly_time()
  end

  def format_friendly_time(_), do: "Unknown"

  @doc """
  Alias for format_relative_time/1 for backward compatibility.
  Also handles NaiveDateTime input by converting to DateTime.
  """
  @spec format_time_ago(DateTime.t() | NaiveDateTime.t() | nil) :: String.t()
  def format_time_ago(nil), do: "Unknown"

  def format_time_ago(%DateTime{} = datetime) do
    format_relative_time(datetime)
  end

  def format_time_ago(%NaiveDateTime{} = datetime) do
    case DateTime.from_naive(datetime, "Etc/UTC") do
      {:ok, dt} -> format_relative_time(dt)
      _ -> "Unknown"
    end
  rescue
    _ -> "Unknown"
  end

  def format_time_ago(_), do: "Unknown"
end
