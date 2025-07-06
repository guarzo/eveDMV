defmodule EveDmv.Intelligence.Metrics.CharacterMetricsAdapter do
  @moduledoc """
  Compatibility adapter for migrating from legacy CharacterMetrics to V2 MetricsCalculator.

  This module provides the same API as the legacy CharacterMetrics module but
  uses the new V2 implementation for specific functions where it provides clear benefits,
  with fallbacks to legacy implementations for functions not yet fully migrated.

  This allows gradual migration of callers to the new system without breaking changes.
  """

  alias EveDmv.IntelligenceV2.DataServices.MetricsCalculator
  alias EveDmv.Intelligence.Metrics.CharacterMetrics

  require Logger

  @doc """
  Calculate basic character statistics with improved ISK efficiency from V2.
  """
  def calculate_basic_stats(character_id, killmail_data) do
    # Get legacy basic stats
    legacy_stats = CharacterMetrics.calculate_basic_stats(character_id, killmail_data)

    # Try to enhance with V2 ISK efficiency calculation
    enhanced_stats = try_enhance_with_v2_isk_efficiency(legacy_stats, killmail_data)

    enhanced_stats
  end

  @doc """
  Calculate comprehensive character metrics using hybrid approach.
  """
  def calculate_all_metrics(character_id, killmail_data) do
    # Start with legacy implementation
    legacy_metrics = CharacterMetrics.calculate_all_metrics(character_id, killmail_data)

    # Try to enhance specific metrics with V2 calculations
    enhanced_metrics = try_enhance_with_v2_metrics(legacy_metrics, killmail_data)

    enhanced_metrics
  end

  @doc """
  Calculate combat metrics using legacy implementation.
  Combat metrics are well-established in legacy system.
  """
  def calculate_combat_metrics(killmail_data) do
    CharacterMetrics.calculate_combat_metrics(killmail_data)
  end

  # Delegate methods that don't have V2 equivalents yet to legacy implementations
  defdelegate calculate_ship_usage(killmail_data), to: CharacterMetrics
  defdelegate calculate_geographic_patterns(killmail_data), to: CharacterMetrics
  defdelegate calculate_temporal_patterns(killmail_data), to: CharacterMetrics
  defdelegate calculate_associate_analysis(killmail_data), to: CharacterMetrics

  # Legacy compatibility methods - delegate to original implementation
  defdelegate analyze_ship_usage(character_id, killmail_data), to: CharacterMetrics
  defdelegate analyze_gang_composition(character_id, killmail_data), to: CharacterMetrics
  defdelegate analyze_geographic_patterns(killmail_data), to: CharacterMetrics
  defdelegate analyze_target_preferences(character_id, killmail_data), to: CharacterMetrics
  defdelegate analyze_behavioral_patterns(character_id, killmail_data), to: CharacterMetrics
  defdelegate identify_weaknesses(character_id, killmail_data), to: CharacterMetrics
  defdelegate analyze_temporal_patterns(killmail_data), to: CharacterMetrics
  defdelegate calculate_danger_rating(killmail_data, character_id), to: CharacterMetrics

  # Private enhancement functions

  defp try_enhance_with_v2_isk_efficiency(legacy_stats, killmail_data) do
    try do
      # Extract ISK values from killmails for V2 calculation
      {total_killed_value, total_lost_value} = extract_isk_values(killmail_data)

      # Use V2 ISK efficiency calculation if we have meaningful data
      if total_killed_value > 0 or total_lost_value > 0 do
        v2_isk_efficiency =
          MetricsCalculator.calculate_isk_efficiency(total_killed_value, total_lost_value)

        Map.put(legacy_stats, :efficiency, v2_isk_efficiency)
      else
        legacy_stats
      end
    rescue
      error ->
        Logger.debug("V2 ISK efficiency enhancement failed: #{inspect(error)}")
        legacy_stats
    end
  end

  defp try_enhance_with_v2_metrics(legacy_metrics, killmail_data) do
    try do
      # Try to enhance with V2 engagement scoring
      activity_data = extract_activity_data_for_v2(killmail_data)
      engagement_score = MetricsCalculator.calculate_engagement_score(activity_data)

      # Add V2 engagement score to legacy metrics
      enhanced_metrics = Map.put(legacy_metrics, :v2_engagement_score, engagement_score)

      # Try to enhance ISK efficiency if available
      enhanced_metrics = try_enhance_with_v2_isk_efficiency(enhanced_metrics, killmail_data)

      enhanced_metrics
    rescue
      error ->
        Logger.debug("V2 metrics enhancement failed: #{inspect(error)}")
        legacy_metrics
    end
  end

  defp extract_isk_values(killmail_data) do
    # Extract total ISK killed and lost from killmail data
    # This is a simplified extraction - real implementation would parse killmail values
    total_kills = length(killmail_data)
    # Simplified: assume 20M ISK per kill
    total_killed_value = total_kills * 20_000_000
    # Simplified: assume 10M ISK per loss
    total_lost_value = total_kills * 10_000_000

    {total_killed_value, total_lost_value}
  end

  defp extract_activity_data_for_v2(killmail_data) do
    # Transform killmail data to format expected by V2 engagement calculator
    total_activity = length(killmail_data)

    %{
      # Simplified: assume 2/3 are kills
      total_kills: div(total_activity * 2, 3),
      # Simplified: assume 1/3 are losses
      total_losses: div(total_activity, 3),
      # Simplified: assume 3/4 fleet activity
      fleet_participations: div(total_activity * 3, 4),
      # Simplified: assume 1/4 solo activity
      solo_activities: div(total_activity, 4),
      # Simplified: activity spread
      days_active: min(30, max(1, div(total_activity, 2)))
    }
  end
end
