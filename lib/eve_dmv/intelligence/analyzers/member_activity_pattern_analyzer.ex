defmodule EveDmv.Intelligence.Analyzers.MemberActivityPatternAnalyzer do
  @moduledoc """
  Specialized analyzer for member activity patterns and behavior analysis.

  This module focuses on understanding when and how members are active,
  identifying patterns in their behavior, and providing insights into:

  1. **Timezone Analysis** - When members are most active based on activity patterns
  2. **Activity Consistency** - How consistent members are in their activity patterns
  3. **Trend Analysis** - Activity trends over time and pattern recognition
  4. **Behavioral Patterns** - Recognition of member behavior patterns

  The analyzer works with activity data collected by MemberActivityDataCollector
  and provides detailed pattern analysis for member intelligence systems.
  """

  require Logger

  alias EveDmv.Intelligence.Analyzers.MemberActivityPatternAnalyzer.{
    AnomalyDetector,
    ConsistencyCalculator,
    TimezoneAnalyzer,
    TrendAnalyzer
  }

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
  defdelegate analyze_timezone_patterns(character_id, activity_data), to: TimezoneAnalyzer

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
  defdelegate estimate_timezone_from_hours(active_hours), to: TimezoneAnalyzer

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
  defdelegate calculate_timezone_consistency(hourly_activity), to: TimezoneAnalyzer

  @doc """
  Analyze activity trends over time for member activities.

  Examines activity patterns to identify trends, seasonal variations,
  and behavioral changes over time.

  ## Parameters
  - `member_activities` - List of member activity records
  - `days` - Number of days to analyze

  ## Returns
  - Map containing trend analysis results

  ## Examples
      iex> analyze_activity_trends(member_activities, 30)
      %{trend_direction: :increasing, growth_rate: 15.3, activity_peaks: [5, 12]}
  """
  defdelegate analyze_activity_trends(member_activities, days), to: TrendAnalyzer

  @doc """
  Calculate trend direction from activity data series.

  Analyzes activity data to determine if the trend is increasing,
  decreasing, stable, or volatile.

  ## Parameters
  - `activity_data` - List of activity values over time

  ## Returns
  - Atom representing trend direction (:increasing, :decreasing, :stable, :volatile)

  ## Examples
      iex> calculate_trend_direction([10, 12, 15, 18, 20])
      :increasing

      iex> calculate_trend_direction([20, 18, 15, 12, 10])
      :decreasing
  """
  defdelegate calculate_trend_direction(activity_data), to: TrendAnalyzer

  @doc """
  Calculate days since last activity for a member.

  Determines how many days have passed since the member's last recorded activity.
  Useful for identifying inactive members and calculating engagement metrics.

  ## Parameters
  - `last_activity` - DateTime of last activity (or nil if no activity)
  - `current_time` - Current DateTime to compare against

  ## Returns
  - Integer number of days since last activity (999 if no activity recorded)

  ## Examples
      iex> days_since_last_activity(~U[2023-01-01 00:00:00Z], ~U[2023-01-15 00:00:00Z])
      14

      iex> days_since_last_activity(nil, ~U[2023-01-15 00:00:00Z])
      999
  """
  defdelegate days_since_last_activity(last_activity, current_time), to: TrendAnalyzer

  @doc """
  Analyze activity patterns for complex behavioral insights.

  Identifies recurring patterns, behavioral anomalies, and activity signatures
  that can help understand member engagement and predict future behavior.

  ## Parameters
  - `character_id` - Character to analyze
  - `activity_data` - Detailed activity data including timestamps and types

  ## Returns
  - `{:ok, pattern_analysis}` - Detailed pattern analysis
  - `{:error, reason}` - Error if analysis fails
  """
  def analyze_activity_patterns(character_id, activity_data) do
    Logger.debug("Analyzing activity patterns for character #{character_id}")

    with {:ok, timezone_analysis} <-
           TimezoneAnalyzer.analyze_timezone_patterns(character_id, activity_data),
         {:ok, trend_analysis} <- TrendAnalyzer.analyze_trend_patterns(activity_data),
         {:ok, consistency_metrics} <-
           ConsistencyCalculator.analyze_consistency_patterns(activity_data) do
      pattern_analysis = %{
        character_id: character_id,
        timezone_patterns: timezone_analysis,
        trend_patterns: trend_analysis,
        consistency_metrics: consistency_metrics,
        analyzed_at: DateTime.utc_now()
      }

      {:ok, pattern_analysis}
    else
      {:error, reason} ->
        Logger.error(
          "Activity pattern analysis failed for character #{character_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Detect behavioral anomalies in member activity patterns.

  Identifies unusual activity patterns that may indicate account sharing,
  burnout, or other behavioral changes requiring attention.

  ## Parameters
  - `character_id` - Character to analyze
  - `activity_data` - Historical activity data
  - `options` - Analysis options (sensitivity, lookback period, etc.)

  ## Returns
  - `{:ok, anomaly_analysis}` - Anomaly detection results
  - `{:error, reason}` - Error if analysis fails
  """
  defdelegate detect_behavioral_anomalies(character_id, activity_data, options \\ []),
    to: AnomalyDetector
end
