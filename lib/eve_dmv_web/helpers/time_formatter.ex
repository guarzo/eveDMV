defmodule EveDmvWeb.Helpers.TimeFormatter do
  @moduledoc """
  Shared time formatting functions for LiveView modules.
  """

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
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86_400)}d ago"
    end
  end

  def format_relative_time(nil), do: "N/A"

  @doc """
  Formats a duration in seconds to a human-readable format.
  """
  @spec format_duration(integer()) :: String.t()
  def format_duration(seconds) when is_integer(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    seconds = rem(seconds, 60)

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
      diff_days < 30 -> "#{div(diff_days, 7)} weeks ago"
      true -> "#{div(diff_days, 30)} months ago"
    end
  end
end
