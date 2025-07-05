defmodule EveDmv.Intelligence.Analyzers.MemberActivityPatternAnalyzer.TimezoneAnalyzer do
  @moduledoc """
  Specialized analyzer for timezone pattern analysis.

  This module focuses on understanding when members are active,
  identifying their primary timezone, and calculating timezone consistency.
  """

  require Logger

  @doc """
  Analyze timezone patterns for a character based on their activity data.

  Returns timezone analysis including:
  - Primary timezone estimation
  - Active hours identification
  - Timezone consistency score

  ## Parameters
  - `character_id` - The character to analyze
  - `activity_data` - Activity data map containing hourly activity patterns

  ## Returns
  - `{:ok, timezone_analysis}` - Analysis results
  - `{:error, reason}` - Error if analysis fails

  ## Examples
      iex> analyze_timezone_patterns(123456, %{hourly_activity: %{14 => 5, 15 => 8}})
      {:ok, %{primary_timezone: "EU TZ", active_hours: [14, 15], timezone_consistency: 0.8}}
  """
  def analyze_timezone_patterns(character_id, activity_data) do
    Logger.debug("Analyzing timezone patterns for character #{character_id}")

    if not is_map(activity_data) do
      {:error, "Invalid activity data format"}
    else
      # Analyze when the member is most active based on actual activity
      hourly_activity = Map.get(activity_data, :hourly_activity, %{})

      # Find peak activity hours
      total_activity = hourly_activity |> Map.values() |> Enum.sum()

      active_hours =
        if total_activity > 0 do
          # Get hours with >5% of total activity
          threshold = total_activity * 0.05

          hourly_activity
          |> Enum.filter(fn {_hour, count} -> count >= threshold end)
          |> Enum.map(&elem(&1, 0))
          |> Enum.sort()
        else
          []
        end

      # Determine primary timezone based on peak hours
      primary_timezone = estimate_timezone_from_hours(active_hours)

      # Calculate consistency (how concentrated activity is)
      timezone_consistency = calculate_timezone_consistency(hourly_activity)

      timezone_analysis = %{
        primary_timezone: primary_timezone,
        active_hours: active_hours,
        timezone_consistency: timezone_consistency
      }

      {:ok, timezone_analysis}
    end
  end

  @doc """
  Estimate timezone from peak activity hours.

  Analyzes active hours to determine the most likely timezone based on
  typical activity patterns for different regions.

  ## Parameters
  - `active_hours` - List of hours (0-23) when member is most active

  ## Returns
  - String timezone identifier ("EU TZ", "US TZ", "AU TZ", "Mixed TZ", "Unknown")

  ## Examples
      iex> estimate_timezone_from_hours([14, 15, 16])
      "EU TZ"

      iex> estimate_timezone_from_hours([])
      "Unknown"
  """
  def estimate_timezone_from_hours(active_hours) when is_list(active_hours) do
    if Enum.empty?(active_hours) do
      "Unknown"
    else
      # Find the most likely timezone based on peak hours
      avg_hour = Enum.sum(active_hours) / length(active_hours)

      cond do
        # Australian timezone
        avg_hour >= 22 or avg_hour <= 6 -> "AU TZ"
        # European timezone
        avg_hour >= 7 and avg_hour <= 15 -> "EU TZ"
        # US timezone
        avg_hour >= 16 and avg_hour <= 21 -> "US TZ"
        true -> "Mixed TZ"
      end
    end
  end

  def estimate_timezone_from_hours(_), do: "Unknown"

  @doc """
  Calculate timezone consistency based on activity distribution.

  Determines how concentrated a member's activity is within a 6-hour window,
  indicating how consistent their timezone patterns are.

  ## Parameters
  - `hourly_activity` - Map of hour -> activity count

  ## Returns
  - Float between 0.0 and 1.0 (higher = more consistent)

  ## Examples
      iex> calculate_timezone_consistency(%{14 => 10, 15 => 8, 16 => 5})
      0.85
  """
  def calculate_timezone_consistency(hourly_activity) when is_map(hourly_activity) do
    if map_size(hourly_activity) == 0 do
      0.0
    else
      # Calculate how concentrated activity is in a 6-hour window
      total_activity = hourly_activity |> Map.values() |> Enum.sum()

      max_6h_activity =
        0..23
        |> Enum.map(fn start_hour ->
          0..5
          |> Enum.map(fn offset ->
            hour = rem(start_hour + offset, 24)
            Map.get(hourly_activity, hour, 0)
          end)
          |> Enum.sum()
        end)
        |> Enum.max()

      if total_activity > 0 do
        max_6h_activity / total_activity
      else
        0.0
      end
    end
  end

  def calculate_timezone_consistency(_), do: 0.0
end
