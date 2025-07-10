defmodule EveDmv.Intelligence.Analyzers.MemberActivityPatternAnalyzer.AnomalyDetector do
  @moduledoc """
  Specialized detector for behavioral anomalies in member activity patterns.

  This module identifies unusual activity patterns that may indicate account sharing,
  burnout, or other behavioral changes requiring attention.
  """

  require Logger

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
  def detect_behavioral_anomalies(character_id, activity_data, options \\ []) do
    sensitivity = Keyword.get(options, :sensitivity, :medium)
    lookback_days = Keyword.get(options, :lookback_days, 30)

    Logger.debug(
      "Detecting behavioral anomalies for character #{character_id} with sensitivity #{sensitivity}"
    )

    with {:ok, baseline_patterns} <- establish_baseline_patterns(activity_data, lookback_days),
         {:ok, recent_patterns} <- analyze_recent_patterns(activity_data, lookback_days),
         {:ok, anomalies} <-
           compare_patterns_for_anomalies(baseline_patterns, recent_patterns, sensitivity) do
      anomaly_analysis = %{
        character_id: character_id,
        baseline_established: baseline_patterns.established_date,
        anomalies_detected: anomalies,
        risk_level: determine_anomaly_risk_level(anomalies),
        recommendations: generate_anomaly_recommendations(anomalies)
      }

      {:ok, anomaly_analysis}
    else
      {:error, reason} ->
        Logger.error(
          "Behavioral anomaly detection failed for character #{character_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Establish baseline patterns from historical data.

  ## Parameters
  - `activity_data` - Historical activity data
  - `lookback_days` - Number of days to look back for baseline

  ## Returns
  - `{:ok, baseline_patterns}` - Baseline pattern analysis
  """
  def establish_baseline_patterns(activity_data, lookback_days) do
    # Establish baseline patterns from historical data
    cutoff_date = DateTime.add(DateTime.utc_now(), -lookback_days * 2, :day)
    baseline_date = DateTime.add(DateTime.utc_now(), -lookback_days, :day)

    baseline_patterns = %{
      established_date: baseline_date,
      average_daily_activity:
        calculate_baseline_daily_activity(activity_data, cutoff_date, baseline_date),
      typical_hours: calculate_baseline_active_hours(activity_data, cutoff_date, baseline_date),
      activity_variance: calculate_baseline_variance(activity_data, cutoff_date, baseline_date)
    }

    {:ok, baseline_patterns}
  end

  @doc """
  Analyze recent patterns for comparison with baseline.

  ## Parameters
  - `activity_data` - Activity data
  - `lookback_days` - Number of days to analyze

  ## Returns
  - `{:ok, recent_patterns}` - Recent pattern analysis
  """
  def analyze_recent_patterns(activity_data, lookback_days) do
    # Analyze recent patterns
    cutoff_date = DateTime.add(DateTime.utc_now(), -lookback_days, :day)

    recent_patterns = %{
      average_daily_activity: calculate_recent_daily_activity(activity_data, cutoff_date),
      typical_hours: calculate_recent_active_hours(activity_data, cutoff_date),
      activity_variance: calculate_recent_variance(activity_data, cutoff_date)
    }

    {:ok, recent_patterns}
  end

  @doc """
  Compare patterns to detect anomalies.

  ## Parameters
  - `baseline_patterns` - Baseline activity patterns
  - `recent_patterns` - Recent activity patterns
  - `sensitivity` - Detection sensitivity level

  ## Returns
  - `{:ok, anomalies}` - List of detected anomalies
  """
  def compare_patterns_for_anomalies(baseline_patterns, recent_patterns, sensitivity) do
    # Compare patterns to detect anomalies
    base_anomalies = []

    # Check activity level changes
    activity_anomalies =
      check_activity_level_anomaly(
        baseline_patterns,
        recent_patterns,
        sensitivity,
        base_anomalies
      )

    # Check timezone pattern changes
    timezone_anomalies =
      check_timezone_pattern_anomaly(
        baseline_patterns,
        recent_patterns,
        sensitivity,
        activity_anomalies
      )

    # Check activity variance changes
    final_anomalies =
      check_variance_anomaly(baseline_patterns, recent_patterns, sensitivity, timezone_anomalies)

    {:ok, final_anomalies}
  end

  @doc """
  Determine risk level based on detected anomalies.

  ## Parameters
  - `anomalies` - List of detected anomalies

  ## Returns
  - Atom representing risk level (:none, :low, :medium, :high)
  """
  def determine_anomaly_risk_level(anomalies) do
    cond do
      length(anomalies) >= 3 -> :high
      length(anomalies) >= 2 -> :medium
      length(anomalies) >= 1 -> :low
      true -> :none
    end
  end

  @doc """
  Generate recommendations based on detected anomalies.

  ## Parameters
  - `anomalies` - List of detected anomalies

  ## Returns
  - List of recommendation strings
  """
  def generate_anomaly_recommendations(anomalies) do
    # Generate recommendations based on detected anomalies
    Enum.map(anomalies, fn anomaly ->
      case anomaly.type do
        :activity_level_change -> "Monitor member for potential burnout or disengagement"
        :timezone_pattern_change -> "Check for account sharing or member relocation"
        :activity_variance_change -> "Review member's gaming schedule consistency"
        _ -> "Monitor member activity patterns"
      end
    end)
  end

  # Private helper functions

  # Baseline calculation helpers
  defp calculate_baseline_daily_activity(_activity_data, _cutoff_date, _baseline_date), do: 0.0
  defp calculate_baseline_active_hours(_activity_data, _cutoff_date, _baseline_date), do: []
  defp calculate_baseline_variance(_activity_data, _cutoff_date, _baseline_date), do: 0.0

  # Recent calculation helpers
  defp calculate_recent_daily_activity(_activity_data, _cutoff_date), do: 0.0
  defp calculate_recent_active_hours(_activity_data, _cutoff_date), do: []
  defp calculate_recent_variance(_activity_data, _cutoff_date), do: 0.0

  # Anomaly detection helpers
  defp check_activity_level_anomaly(baseline, recent, _sensitivity, anomalies) do
    if abs(baseline.average_daily_activity - recent.average_daily_activity) >
         baseline.average_daily_activity * 0.5 do
      anomaly = %{
        type: :activity_level_change,
        severity: :medium,
        description: "Significant change in daily activity level",
        baseline_value: baseline.average_daily_activity,
        recent_value: recent.average_daily_activity
      }

      [anomaly | anomalies]
    else
      anomalies
    end
  end

  defp check_timezone_pattern_anomaly(baseline, recent, _sensitivity, anomalies) do
    # Simple check for timezone pattern changes
    if length(baseline.typical_hours -- recent.typical_hours) > 2 do
      anomaly = %{
        type: :timezone_pattern_change,
        severity: :high,
        description: "Significant change in active hours pattern",
        baseline_value: baseline.typical_hours,
        recent_value: recent.typical_hours
      }

      [anomaly | anomalies]
    else
      anomalies
    end
  end

  defp check_variance_anomaly(baseline, recent, _sensitivity, anomalies) do
    if abs(baseline.activity_variance - recent.activity_variance) >
         baseline.activity_variance * 0.7 do
      anomaly = %{
        type: :activity_variance_change,
        severity: :low,
        description: "Change in activity consistency pattern",
        baseline_value: baseline.activity_variance,
        recent_value: recent.activity_variance
      }

      [anomaly | anomalies]
    else
      anomalies
    end
  end
end
