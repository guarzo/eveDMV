defmodule EveDmv.Utils.TimezoneAnalyzer do
  @moduledoc """
  Shared timezone analysis utilities for character and corporation analysis.

  Provides consistent timezone detection based on EVE Online activity patterns.
  """

  @doc """
  Analyzes timezone based on killmail activity patterns.

  Returns the primary timezone based on peak activity hours:
  - EUTZ: 16:00-20:00 EVE time
  - USTZ: 21:00-03:00 EVE time (wraps around midnight)
  - AUTZ: 08:00-14:00 EVE time

  ## Examples

      iex> killmails = [%{killmail_time: ~U[2023-01-01 18:00:00Z]}, ...]
      iex> TimezoneAnalyzer.analyze_primary_timezone(killmails)
      "EUTZ"
  """
  def analyze_primary_timezone(killmails) when is_list(killmails) do
    # Extract hours from killmail times
    hourly_distribution =
      killmails
      |> Enum.map(&extract_hour_from_killmail/1)
      |> Enum.filter(& &1)
      |> Enum.frequencies()

    if map_size(hourly_distribution) == 0 do
      "Unknown"
    else
      {peak_hour, _count} = Enum.max_by(hourly_distribution, fn {_hour, count} -> count end)
      categorize_timezone(peak_hour)
    end
  end

  @doc """
  Analyzes timezone from an hourly distribution map.

  Used when you already have hourly activity data as a map.
  """
  def analyze_primary_timezone_from_hourly_distribution(hourly_distribution)
      when is_map(hourly_distribution) do
    if map_size(hourly_distribution) == 0 do
      "Unknown"
    else
      {peak_hour, _count} = Enum.max_by(hourly_distribution, fn {_hour, count} -> count end)
      categorize_timezone(peak_hour)
    end
  end

  @doc """
  Analyzes timezone distribution across all hours.

  Returns a map with activity counts for each timezone.
  """
  def analyze_timezone_distribution(killmails) when is_list(killmails) do
    hourly_distribution =
      killmails
      |> Enum.map(&extract_hour_from_killmail/1)
      |> Enum.filter(& &1)
      |> Enum.frequencies()

    # Calculate activity for each timezone
    eutz_activity = calculate_timezone_activity(hourly_distribution, eutz_hours())
    ustz_activity = calculate_timezone_activity(hourly_distribution, ustz_hours())
    autz_activity = calculate_timezone_activity(hourly_distribution, autz_hours())

    %{
      eutz: eutz_activity,
      ustz: ustz_activity,
      autz: autz_activity,
      primary: determine_primary_from_distribution(eutz_activity, ustz_activity, autz_activity)
    }
  end

  # Private functions

  defp extract_hour_from_killmail(%{killmail_time: %DateTime{} = dt}) do
    dt |> DateTime.to_time() |> Time.to_erl() |> elem(0)
  end

  defp extract_hour_from_killmail(_), do: nil

  defp categorize_timezone(hour) do
    cond do
      hour in eutz_hours() -> "EUTZ"
      hour in ustz_hours() -> "USTZ"
      hour in autz_hours() -> "AUTZ"
      true -> "Mixed"
    end
  end

  defp eutz_hours, do: 16..20 |> Enum.to_list()
  defp autz_hours, do: 8..14 |> Enum.to_list()

  # USTZ wraps around midnight (21-23 + 0-3)
  defp ustz_hours, do: [21, 22, 23, 0, 1, 2, 3]

  defp calculate_timezone_activity(hourly_distribution, timezone_hours) do
    timezone_hours
    |> Enum.map(&Map.get(hourly_distribution, &1, 0))
    |> Enum.sum()
  end

  defp determine_primary_from_distribution(eutz, ustz, autz) do
    case Enum.max_by([{"EUTZ", eutz}, {"USTZ", ustz}, {"AUTZ", autz}], &elem(&1, 1)) do
      {timezone, activity} when activity > 0 -> timezone
      _ -> "Unknown"
    end
  end
end
