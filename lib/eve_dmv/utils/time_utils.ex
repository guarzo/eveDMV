defmodule EveDmv.Utils.TimeUtils do
  @moduledoc """
  Time calculation utilities used across intelligence modules.

  This module provides common time manipulation and calculation functions
  that are frequently used throughout the application for analysis and
  data processing.
  """

  @doc """
  Calculate days between two DateTime structs.

  ## Examples

      iex> days_between(~U[2024-06-01 12:00:00Z], ~U[2024-07-01 12:00:00Z])
      30
  """
  def days_between(start_time, end_time)
      when is_struct(start_time, DateTime) and is_struct(end_time, DateTime) do
    DateTime.diff(end_time, start_time, :day)
  end

  @doc """
  Calculate days since a given DateTime.

  ## Examples

      iex> days_since(~U[2024-06-01 12:00:00Z])
      30
  """
  def days_since(datetime) when is_struct(datetime, DateTime) do
    days_between(datetime, DateTime.utc_now())
  end

  @doc """
  Calculate hours between two DateTime structs.

  ## Examples

      iex> hours_between(~U[2024-07-01 12:00:00Z], ~U[2024-07-01 15:00:00Z])
      3
  """
  def hours_between(start_time, end_time)
      when is_struct(start_time, DateTime) and is_struct(end_time, DateTime) do
    DateTime.diff(end_time, start_time, :hour)
  end

  @doc """
  Calculate minutes between two DateTime structs.

  ## Examples

      iex> minutes_between(~U[2024-07-01 12:00:00Z], ~U[2024-07-01 12:30:00Z])
      30
  """
  def minutes_between(start_time, end_time)
      when is_struct(start_time, DateTime) and is_struct(end_time, DateTime) do
    DateTime.diff(end_time, start_time, :minute)
  end

  @doc """
  Calculate seconds between two DateTime structs.

  ## Examples

      iex> seconds_between(~U[2024-07-01 12:00:00Z], ~U[2024-07-01 12:00:30Z])
      30
  """
  def seconds_between(start_time, end_time)
      when is_struct(start_time, DateTime) and is_struct(end_time, DateTime) do
    DateTime.diff(end_time, start_time, :second)
  end

  @doc """
  Truncate a DateTime to the start of the hour.

  Removes minutes, seconds, and microseconds.

  ## Examples

      iex> truncate_to_hour(~U[2024-07-01 12:34:56.789Z])
      ~U[2024-07-01 12:00:00.000000Z]
  """
  def truncate_to_hour(datetime) when is_struct(datetime, DateTime) do
    %{datetime | minute: 0, second: 0, microsecond: {0, 6}}
  end

  @doc """
  Truncate a DateTime to the start of the day.

  Removes hours, minutes, seconds, and microseconds.

  ## Examples

      iex> truncate_to_day(~U[2024-07-01 12:34:56.789Z])
      ~U[2024-07-01 00:00:00.000000Z]
  """
  def truncate_to_day(datetime) when is_struct(datetime, DateTime) do
    %{datetime | hour: 0, minute: 0, second: 0, microsecond: {0, 6}}
  end

  @doc """
  Calculate the start and end of a day for a given DateTime.

  Returns a tuple with the start of day and end of day.

  ## Examples

      iex> day_boundaries(~U[2024-07-01 12:34:56Z])
      {~U[2024-07-01 00:00:00.000000Z], ~U[2024-07-01 23:59:59.999999Z]}
  """
  def day_boundaries(datetime) when is_struct(datetime, DateTime) do
    start_of_day = truncate_to_day(datetime)
    end_of_day = %{start_of_day | hour: 23, minute: 59, second: 59, microsecond: {999_999, 6}}
    {start_of_day, end_of_day}
  end

  @doc """
  Check if two DateTimes are on the same day.

  ## Examples

      iex> same_day?(~U[2024-07-01 08:00:00Z], ~U[2024-07-01 20:00:00Z])
      true
      
      iex> same_day?(~U[2024-07-01 23:59:59Z], ~U[2024-07-02 00:00:01Z])
      false
  """
  def same_day?(datetime1, datetime2)
      when is_struct(datetime1, DateTime) and is_struct(datetime2, DateTime) do
    Date.compare(DateTime.to_date(datetime1), DateTime.to_date(datetime2)) == :eq
  end

  @doc """
  Generate a range of dates between start and end dates.

  ## Examples

      iex> date_range(~D[2024-07-01], ~D[2024-07-03])
      [~D[2024-07-01], ~D[2024-07-02], ~D[2024-07-03]]
  """
  def date_range(start_date, end_date)
      when is_struct(start_date, Date) and is_struct(end_date, Date) do
    Date.range(start_date, end_date) |> Enum.to_list()
  end

  @doc """
  Generate a list of DateTime structs for each hour between start and end.

  Returns DateTime structs truncated to the hour.

  ## Examples

      iex> hourly_range(~U[2024-07-01 10:00:00Z], ~U[2024-07-01 12:00:00Z])
      [~U[2024-07-01 10:00:00.000000Z], ~U[2024-07-01 11:00:00.000000Z], ~U[2024-07-01 12:00:00.000000Z]]
  """
  def hourly_range(start_datetime, end_datetime)
      when is_struct(start_datetime, DateTime) and is_struct(end_datetime, DateTime) do
    start_hour = truncate_to_hour(start_datetime)
    end_hour = truncate_to_hour(end_datetime)

    hours_diff = hours_between(start_hour, end_hour)

    0..hours_diff
    |> Enum.map(fn hour_offset ->
      DateTime.add(start_hour, hour_offset, :hour)
    end)
  end

  @doc """
  Convert a time period in various units to seconds.

  ## Examples

      iex> to_seconds(5, :minute)
      300
      
      iex> to_seconds(2, :hour)
      7200
      
      iex> to_seconds(1, :day)
      86400
  """
  def to_seconds(amount, :second), do: amount
  def to_seconds(amount, :minute), do: amount * 60
  def to_seconds(amount, :hour), do: amount * 60 * 60
  def to_seconds(amount, :day), do: amount * 24 * 60 * 60
  def to_seconds(amount, :week), do: amount * 7 * 24 * 60 * 60

  @doc """
  Format duration in a human-readable way.

  ## Examples

      iex> format_duration(3661)
      "1h 1m 1s"
      
      iex> format_duration(90)
      "1m 30s"
      
      iex> format_duration(45)
      "45s"
  """
  def format_duration(seconds) when is_integer(seconds) and seconds >= 0 do
    cond do
      seconds >= 3600 ->
        hours = div(seconds, 3600)
        remaining = rem(seconds, 3600)
        minutes = div(remaining, 60)
        secs = rem(remaining, 60)
        format_duration_parts([{hours, "h"}, {minutes, "m"}, {secs, "s"}])

      seconds >= 60 ->
        minutes = div(seconds, 60)
        secs = rem(seconds, 60)
        format_duration_parts([{minutes, "m"}, {secs, "s"}])

      true ->
        "#{seconds}s"
    end
  end

  @doc """
  Calculate time until a future DateTime.

  Returns the duration in seconds, or 0 if the datetime is in the past.

  ## Examples

      iex> time_until(DateTime.add(DateTime.utc_now(), 3600, :second))
      3600
  """
  def time_until(future_datetime) when is_struct(future_datetime, DateTime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(future_datetime, now, :second)
    max(0, diff)
  end

  @doc """
  Calculate time since a past DateTime.

  Returns the duration in seconds, or 0 if the datetime is in the future.

  ## Examples

      iex> time_since(DateTime.add(DateTime.utc_now(), -3600, :second))
      3600
  """
  def time_since(past_datetime) when is_struct(past_datetime, DateTime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, past_datetime, :second)
    max(0, diff)
  end

  @doc """
  Check if a DateTime is within a specified time window from now.

  ## Examples

      iex> within_window?(DateTime.add(DateTime.utc_now(), -1800, :second), 3600)
      true
      
      iex> within_window?(DateTime.add(DateTime.utc_now(), -7200, :second), 3600)
      false
  """
  def within_window?(datetime, window_seconds)
      when is_struct(datetime, DateTime) and is_integer(window_seconds) do
    time_since(datetime) <= window_seconds
  end

  @doc """
  Get the timezone offset for EVE time (UTC).

  EVE Online operates on UTC time, so this always returns 0.
  Included for clarity and potential future expansion.

  ## Examples

      iex> eve_timezone_offset()
      0
  """
  def eve_timezone_offset, do: 0

  # Private helper functions

  defp format_duration_parts(parts) do
    parts
    |> Enum.filter(fn {value, _unit} -> value > 0 end)
    |> Enum.map(fn {value, unit} -> "#{value}#{unit}" end)
    |> Enum.join(" ")
  end
end
