defmodule EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystemAnalyzer.ActivityCorrelator do
  @moduledoc """
  Analyzes and correlates activities across multiple systems.

  This module has been refactored to use a modular correlation system.
  All functionality is now delegated to specialized modules:
  - SystemActivityCollector: Fetches and processes activity data
  - TimelineManager: Timeline building and management
  - TemporalCorrelationAnalyzer: Statistical correlation analysis

  The Facade module coordinates these components while maintaining
  backward compatibility with the original ActivityCorrelator interface.
  """
  """

  # Delegate all functions to the new modular correlation facade
  defdelegate fetch_system_activities(system_ids, time_window_hours),
    to: EveDmv.Shared.Correlation.Facade

  defdelegate build_activity_timeline(system_activities),
    to: EveDmv.Shared.Correlation.Facade

  defdelegate analyze_temporal_correlations(activity_timeline),
    to: EveDmv.Shared.Correlation.Facade

  defdelegate track_pilot_movements(system_activities),
    to: EveDmv.Shared.Correlation.Facade

  defdelegate analyze_corp_activities(system_activities),
    to: EveDmv.Shared.Correlation.Facade

  defdelegate identify_activity_bursts(timeline_events),
    to: EveDmv.Shared.Correlation.Facade

  defdelegate calculate_activity_correlation(activities1, activities2, options \\ []),
    to: EveDmv.Shared.Correlation.Facade

  defdelegate identify_lag_relationships(system_timelines, options \\ []),
    to: EveDmv.Shared.Correlation.Facade

  defdelegate detect_synchronized_patterns(system_timelines, options \\ []),
    to: EveDmv.Shared.Correlation.Facade

  defdelegate analyze_activity_dependencies(system_timelines, options \\ []),
    to: EveDmv.Shared.Correlation.Facade

  defdelegate create_timeline_windows(timeline_events, window_size_minutes),
    to: EveDmv.Shared.Correlation.Facade

  defdelegate identify_coordinated_operations(timeline_events),
    to: EveDmv.Shared.Correlation.Facade

  defdelegate calculate_timeline_statistics(timeline_events),
    to: EveDmv.Shared.Correlation.Facade
end
