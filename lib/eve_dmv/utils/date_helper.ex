defmodule EveDmv.Utils.DateHelper do
  @moduledoc """
  Date and time utility functions.

  Provides helper functions for date/time operations that are commonly
  used throughout the EVE DMV application, replacing deprecated or
  non-existent Elixir Date functions.
  """
  """

  @doc """
  Get the year from a DateTime struct.

  ## Examples

      iex> dt = ~U[2024-03-15 10:30:00Z]
      iex> EveDmv.Utils.DateHelper.get_year(dt)
      2024
  """
  @spec get_year(DateTime.t()) :: integer()
  def get_year(date_time) when is_struct(date_time, DateTime) do
    DateTime.to_date(date_time).year
  end

  @doc """
  Get the month from a DateTime struct.

  ## Examples

      iex> dt = ~U[2024-03-15 10:30:00Z]
      iex> EveDmv.Utils.DateHelper.get_month(dt)
      3
  """
  @spec get_month(DateTime.t()) :: integer()
  def get_month(date_time) when is_struct(date_time, DateTime) do
    DateTime.to_date(date_time).month
  end

  @doc """
  Get the week of year from a DateTime struct using ISO week numbering.

  Returns the ISO week number (1-53) for the given date.

  ## Examples

      iex> dt = ~U[2024-03-15 10:30:00Z]
      iex> EveDmv.Utils.DateHelper.get_week_of_year(dt)
      11
  """
  @spec get_week_of_year(DateTime.t()) :: integer()
  def get_week_of_year(date_time) when is_struct(date_time, DateTime) do
    date = DateTime.to_date(date_time)

    # Calculate ISO week number
    # This is a simplified implementation - for production use,
    # consider using a more robust library like Timex
    january_4th = Date.new!(date.year, 1, 4)
    days_from_jan_4 = Date.diff(date, january_4th)
    week_number = div(days_from_jan_4 + Date.day_of_week(january_4th, :monday), 7) + 1

    # Ensure week number is in valid range (1-53)
    max(1, min(53, week_number))
  end

  @doc """
  Get the day of year from a DateTime struct.

  ## Examples

      iex> dt = ~U[2024-03-15 10:30:00Z]
      iex> EveDmv.Utils.DateHelper.get_day_of_year(dt)
      75
  """
  @spec get_day_of_year(DateTime.t()) :: integer()
  def get_day_of_year(date_time) when is_struct(date_time, DateTime) do
    date = DateTime.to_date(date_time)
    Date.day_of_year(date)
  end

  @doc """
  Check if a year is a leap year.

  ## Examples

      iex> EveDmv.Utils.DateHelper.leap_year?(2024)
      true

      iex> EveDmv.Utils.DateHelper.leap_year?(2023)
      false
  """
  @spec leap_year?(integer()) :: boolean()
  def leap_year?(year) when is_integer(year) do
    Date.leap_year?(Date.new!(year, 1, 1))
  end

  @doc """
  Get the start of the week (Monday) for a given DateTime.

  ## Examples

      iex> dt = ~U[2024-03-15 10:30:00Z]  # Friday
      iex> week_start = EveDmv.Utils.DateHelper.start_of_week(dt)
      iex> DateTime.to_date(week_start)
      ~D[2024-03-11]  # Previous Monday
  """
  @spec start_of_week(DateTime.t()) :: DateTime.t()
  def start_of_week(date_time) when is_struct(date_time, DateTime) do
    date = DateTime.to_date(date_time)
    days_to_monday = Date.day_of_week(date, :monday) - 1
    monday_date = Date.add(date, -days_to_monday)

    %{date_time | year: monday_date.year, month: monday_date.month, day: monday_date.day}
  end

  @doc """
  Format a DateTime for display purposes.

  Returns a human-readable string representation.

  ## Examples

      iex> dt = ~U[2024-03-15 10:30:00Z]
      iex> EveDmv.Utils.DateHelper.format_display(dt)
      "2024-03-15 10:30 UTC"
  """
  @spec format_display(DateTime.t()) :: String.t()
  def format_display(date_time) when is_struct(date_time, DateTime) do
    "#{Date.to_string(DateTime.to_date(date_time))} #{Time.to_string(DateTime.to_time(date_time))} UTC"
  end

  @doc """
  Calculate the number of days between two DateTime structs.

  ## Examples

      iex> dt1 = ~U[2024-03-10 10:30:00Z]
      iex> dt2 = ~U[2024-03-15 10:30:00Z]
      iex> EveDmv.Utils.DateHelper.days_between(dt1, dt2)
      5
  """
  @spec days_between(DateTime.t(), DateTime.t()) :: integer()
  def days_between(start_date, end_date)
      when is_struct(start_date, DateTime) and is_struct(end_date, DateTime) do
    start_date_only = DateTime.to_date(start_date)
    end_date_only = DateTime.to_date(end_date)
    Date.diff(end_date_only, start_date_only)
  end
end
