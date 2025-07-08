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
end