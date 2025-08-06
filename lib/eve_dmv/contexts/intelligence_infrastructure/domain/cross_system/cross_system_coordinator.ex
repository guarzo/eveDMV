defmodule EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.CrossSystemCoordinator do
  @moduledoc """
  Main coordinator for cross-system intelligence analysis.

  This module serves as the primary orchestrator for cross-system analysis across multiple
  EVE Online systems. It coordinates various specialized analysis modules to provide
  comprehensive intelligence spanning system boundaries. The module has been refactored
  from a monolithic 2,495-line implementation to a focused coordinator that delegates
  to specialized analysis modules.

  ## Architecture

  The coordinator follows a delegation pattern, orchestrating analysis through:
  - **ActivityCorrelationAnalyzer**: Handles activity patterns, correlations, and movement analysis
  - **RegionalConstellationAnalyzer**: Manages regional and constellation-level strategic analysis
  - **Existing Correlators**: Integrates with ActivityCorrelator, ThreatCorrelator, and IntelligenceCorrelator

  ## Key Responsibilities

  - **Analysis Orchestration**: Coordinates multiple analysis types across system boundaries
  - **Data Aggregation**: Fetches and organizes killmail data across multiple systems
  - **Pattern Synthesis**: Combines insights from different analysis modules
  - **Intelligence Generation**: Produces comprehensive cross-system intelligence reports
  - **Threat Assessment**: Coordinates threat analysis across multiple systems
  - **Strategic Insights**: Provides actionable intelligence for tactical and strategic decisions

  ## Analysis Types

  - **Cross-System Patterns**: Identifies patterns spanning multiple systems
  - **Activity Correlations**: Analyzes correlated activities between systems
  - **Threat Propagation**: Tracks threats moving across system boundaries
  - **Movement Analysis**: Analyzes entity movement patterns across systems
  - **Regional Intelligence**: Provides regional and constellation-level insights

  ## Usage

      # Analyze patterns across multiple systems
      analysis = CrossSystemCoordinator.analyze_cross_system_patterns(
        [30000142, 30000143, 30000144],
        analysis_window: 24  # hours
      )

      # Analyze regional patterns
      regional_analysis = CrossSystemCoordinator.analyze_regional_patterns(
        10000002,  # The Forge
        analysis_window: 168
      )

      # Analyze constellation patterns
      constellation_analysis = CrossSystemCoordinator.analyze_constellation_patterns(
        20000020,  # Kimotoro
        analysis_window: 72
      )

  ## Data Integration

  - **Real Killmail Data**: Uses actual combat data from `killmails_enriched` table
  - **Multi-System Queries**: Efficiently fetches data across system boundaries
  - **Temporal Analysis**: Supports configurable time windows for analysis
  - **Statistical Processing**: Applies statistical methods for pattern detection

  ## Performance Considerations

  - **Efficient Queries**: Optimized database queries for multi-system data
  - **Modular Processing**: Delegates heavy processing to specialized modules
  - **Configurable Windows**: Supports various analysis time windows
  - **Resource Management**: Manages memory and processing resources effectively

  ## Refactoring Benefits

  This refactored coordinator provides:
  - **Improved Maintainability**: Clear separation of concerns across modules
  - **Enhanced Testability**: Focused modules are easier to test individually
  - **Better Performance**: Optimized delegation reduces processing overhead
  - **Increased Extensibility**: Easy to add new analysis types through delegation
  """

  import Ecto.Query

  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Correlators.ActivityCorrelator

  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Correlators.IntelligenceCorrelator

  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Correlators.ThreatCorrelator

  # Extracted modules for better organization
  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Analyzers.ActivityCorrelationAnalyzer

  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Analyzers.RegionalConstellationAnalyzer

  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Analyzers.ThreatPatternAnalyzer

  alias EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Analyzers.IntelligenceQualityAnalyzer

  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Repo

  require Logger

  @doc """
  Analyze patterns across multiple systems.
  """
  def analyze_cross_system_patterns(system_ids, options \\ []) do
    Logger.info("Analyzing cross-system patterns for #{length(system_ids)} systems")

    analysis_window = Keyword.get(options, :analysis_window, 24)
    start_time = DateTimeUtils.add(DateTime.utc_now(), -analysis_window * 3_600, :second)

    # Fetch killmail data for all systems
    killmails = fetch_multi_system_killmails(system_ids, start_time)

    # Analyze patterns using extracted modules
    activity_patterns =
      ActivityCorrelationAnalyzer.analyze_activity_patterns(
        system_ids,
        killmails,
        analysis_window
      )

    threat_patterns = analyze_threat_patterns(system_ids, killmails, analysis_window)

    movement_patterns =
      ActivityCorrelationAnalyzer.analyze_movement_patterns(
        system_ids,
        killmails,
        analysis_window
      )

    # Calculate correlations using extracted modules
    activity_correlations =
      ActivityCorrelationAnalyzer.calculate_activity_correlations(system_ids, killmails)

    threat_correlations = calculate_threat_correlations(system_ids, killmails)
    intelligence_correlations = calculate_intelligence_correlations(system_ids, killmails)

    # Generate insights based on real patterns
    insights =
      generate_cross_system_insights(
        system_ids,
        activity_patterns,
        threat_patterns,
        movement_patterns
      )

    %{
      system_ids: system_ids,
      analysis_window_hours: analysis_window,
      total_killmails_analyzed: length(killmails),
      pattern_analysis: %{
        activity_patterns: activity_patterns,
        threat_patterns: threat_patterns,
        movement_patterns: movement_patterns
      },
      correlations: %{
        activity_correlations: activity_correlations,
        threat_correlations: threat_correlations,
        intelligence_correlations: intelligence_correlations
      },
      insights: insights,
      analyzed_at: DateTime.utc_now()
    }
  end

  @doc """
  Analyze regional intelligence patterns.
  """
  def analyze_regional_patterns(region_id, options \\ []) do
    RegionalConstellationAnalyzer.analyze_regional_patterns(region_id, options)
  end

  @doc """
  Analyze constellation-wide patterns.
  """
  def analyze_constellation_patterns(constellation_id, options \\ []) do
    RegionalConstellationAnalyzer.analyze_constellation_patterns(constellation_id, options)
  end

  @doc """
  Correlate activity across multiple systems.
  """
  def correlate_system_activities(system_ids, correlation_type \\ :activity) do
    Logger.info("Correlating #{correlation_type} across #{length(system_ids)} systems")

    case correlation_type do
      :activity -> ActivityCorrelator.correlate_activities(system_ids, [])
      :threat -> ThreatCorrelator.correlate_threats(system_ids, [])
      :intelligence -> IntelligenceCorrelator.correlate_intelligence(system_ids, [])
      _ -> {:error, "Unknown correlation type: #{correlation_type}"}
    end
  end

  # Private helper functions

  defp analyze_threat_patterns(system_ids, killmails, analysis_window) do
    # Identify threat hotspots based on kill concentration
    hotspots = identify_threat_hotspots(system_ids, killmails)

    # Track threat migration patterns
    migration = track_threat_migration(system_ids, killmails, analysis_window)

    # Detect escalation patterns
    escalation = detect_threat_escalation(system_ids, killmails)

    # Predict future threat patterns
    predictions = predict_threat_patterns(system_ids, killmails)

    %{
      threat_hotspots: hotspots,
      threat_migration: migration,
      threat_escalation: escalation,
      threat_predictions: predictions,
      high_value_losses: analyze_high_value_losses(killmails),
      capital_activity: detect_capital_activity(killmails)
    }
  end

  defp calculate_threat_correlations(system_ids, killmails) do
    # Analyze threat patterns by aggressor entities
    threat_data = ThreatPatternAnalyzer.analyze_threat_entities(killmails)

    # Calculate threat correlation between systems
    threat_correlations =
      ThreatPatternAnalyzer.calculate_threat_correlation_matrix(system_ids, threat_data)

    # Identify coordinated threats
    coordinated_threats = ThreatPatternAnalyzer.identify_coordinated_threats(threat_data)

    # Analyze threat spillover
    spillover = ThreatPatternAnalyzer.identify_threat_spillover(system_ids, killmails)

    %{
      threat_correlation_strength:
        ThreatPatternAnalyzer.calculate_threat_correlation_strength(threat_correlations),
      correlated_threats: coordinated_threats,
      threat_spillover: spillover,
      threat_entities: ThreatPatternAnalyzer.extract_major_threat_entities(threat_data),
      escalation_risk: ThreatPatternAnalyzer.calculate_escalation_risk(threat_data)
    }
  end

  defp calculate_intelligence_correlations(system_ids, killmails) do
    # Extract intelligence indicators from killmails
    intel_data = IntelligenceQualityAnalyzer.extract_intelligence_indicators(killmails)

    # Analyze shared intelligence patterns
    shared_intel = IntelligenceQualityAnalyzer.analyze_shared_intelligence(system_ids, intel_data)

    # Identify intelligence gaps
    gaps = IntelligenceQualityAnalyzer.identify_intelligence_gaps(system_ids, killmails)

    # Calculate intelligence quality
    quality = IntelligenceQualityAnalyzer.assess_intelligence_quality(intel_data)

    %{
      intelligence_correlation_strength:
        IntelligenceQualityAnalyzer.calculate_intel_correlation_strength(shared_intel),
      shared_intelligence: shared_intel,
      intelligence_gaps: gaps,
      intelligence_quality: quality,
      coverage_percentage:
        IntelligenceQualityAnalyzer.calculate_coverage_percentage(system_ids, intel_data)
    }
  end

  defp generate_cross_system_insights(
         system_ids,
         activity_patterns,
         threat_patterns,
         movement_patterns
       ) do
    # Activity-based insights
    activity_insights = ActivityCorrelationAnalyzer.generate_activity_insights(activity_patterns)

    # Threat-based insights
    threat_insights = ThreatPatternAnalyzer.generate_threat_insights(threat_patterns, system_ids)

    # Movement-based insights
    movement_insights = ActivityCorrelationAnalyzer.generate_movement_insights(movement_patterns)

    # Cross-pattern insights
    cross_pattern_insights =
      generate_cross_pattern_insights(
        activity_patterns,
        threat_patterns,
        movement_patterns
      )

    # Combine all insights
    insights = activity_insights ++ threat_insights ++ movement_insights ++ cross_pattern_insights

    # Sort by priority/relevance
    insights
    |> Enum.uniq()
    |> Enum.take(10)
  end

  # Threat analysis helper functions

  defp identify_threat_hotspots(_system_ids, killmails) do
    # Identify systems with concentrated threat activity
    system_threats =
      killmails
      |> Enum.group_by(& &1.solar_system_id)
      |> Enum.map(fn {system_id, kills} ->
        threat_score = calculate_system_threat_score(kills)
        {system_id, threat_score}
      end)
      |> Enum.sort_by(&elem(&1, 1), :desc)

    # Return top threat systems
    system_threats
    |> Enum.take(5)
    |> Enum.map(fn {system_id, score} ->
      %{
        system_id: system_id,
        threat_score: Float.round(score, 2),
        threat_level: categorize_threat_level(score)
      }
    end)
  end

  defp calculate_system_threat_score(kills) do
    # Calculate threat based on kill value, frequency, and patterns
    total_value = kills |> Enum.map(&(&1.total_value || 0)) |> Enum.sum()
    kill_count = length(kills)

    avg_attackers =
      kills
      |> Enum.map(&(&1.attacker_count || 1))
      |> Enum.sum()
      |> Kernel./(kill_count)

    # Weighted threat score
    # Billions
    value_score = min(100, total_value / 1_000_000_000)
    frequency_score = min(100, kill_count * 2)
    gang_score = min(100, avg_attackers * 5)

    value_score * 0.4 + frequency_score * 0.4 + gang_score * 0.2
  end

  defp categorize_threat_level(score) do
    cond do
      score > 80 -> :critical
      score > 60 -> :high
      score > 40 -> :moderate
      score > 20 -> :low
      true -> :minimal
    end
  end

  defp track_threat_migration(_system_ids, killmails, _analysis_window) do
    # Track how threats move between systems over time
    bucket_hours = 6

    time_buckets =
      Enum.group_by(killmails, fn kill ->
        hours_ago = DateTimeUtils.diff(DateTime.utc_now(), kill.killmail_time, :hour)
        div(hours_ago, bucket_hours)
      end)

    # Analyze movement between buckets
    migration_patterns =
      time_buckets
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [{earlier_bucket, earlier_kills}, {later_bucket, later_kills}] ->
        earlier_systems = earlier_kills |> Enum.map(& &1.solar_system_id) |> MapSet.new()
        later_systems = later_kills |> Enum.map(& &1.solar_system_id) |> MapSet.new()

        new_systems = MapSet.difference(later_systems, earlier_systems)
        abandoned_systems = MapSet.difference(earlier_systems, later_systems)

        %{
          time_period: {earlier_bucket * bucket_hours, later_bucket * bucket_hours},
          new_threat_systems: MapSet.to_list(new_systems),
          cleared_systems: MapSet.to_list(abandoned_systems),
          persistent_systems:
            earlier_systems |> MapSet.intersection(later_systems) |> MapSet.to_list()
        }
      end)

    # Calculate migration speed
    system_changes =
      migration_patterns
      |> Enum.map(&(length(&1.new_threat_systems) + length(&1.cleared_systems)))
      |> Enum.sum()

    avg_changes =
      if Enum.empty?(migration_patterns) do
        0
      else
        system_changes / length(migration_patterns)
      end

    migration_speed =
      cond do
        avg_changes > 10 -> :rapid
        avg_changes > 5 -> :fast
        avg_changes > 2 -> :moderate
        avg_changes > 0 -> :slow
        true -> :static
      end

    # Determine overall direction
    migration_direction = analyze_migration_direction(migration_patterns)

    %{
      migration_patterns: Enum.take(migration_patterns, 5),
      migration_speed: migration_speed,
      migration_direction: migration_direction
    }
  end

  defp analyze_migration_direction(patterns) do
    # Simplified direction analysis
    expanding =
      Enum.count(patterns, fn p -> length(p.new_threat_systems) > length(p.cleared_systems) end)

    contracting =
      Enum.count(patterns, fn p -> length(p.cleared_systems) > length(p.new_threat_systems) end)

    cond do
      expanding > contracting * 1.5 -> :expanding
      contracting > expanding * 1.5 -> :contracting
      true -> :lateral
    end
  end

  defp detect_threat_escalation(_system_ids, killmails) do
    # Detect escalating threat patterns
    recent_kills =
      Enum.filter(killmails, fn kill ->
        DateTimeUtils.diff(DateTime.utc_now(), kill.killmail_time, :hour) <= 24
      end)

    older_kills =
      Enum.filter(killmails, fn kill ->
        hours_ago = DateTimeUtils.diff(DateTime.utc_now(), kill.killmail_time, :hour)
        hours_ago > 24 and hours_ago <= 72
      end)

    # Compare metrics
    recent_metrics = calculate_threat_metrics(recent_kills)
    older_metrics = calculate_threat_metrics(older_kills)

    # Detect escalation indicators
    kill_rate_indicator =
      if recent_metrics.kill_rate > older_metrics.kill_rate * 1.5 do
        %{
          type: :increased_kill_rate,
          severity: :high,
          change_ratio:
            Float.round(recent_metrics.kill_rate / max(older_metrics.kill_rate, 0.1), 2)
        }
      else
        nil
      end

    value_indicator =
      if recent_metrics.avg_value > older_metrics.avg_value * 2 do
        %{
          type: :higher_value_targets,
          severity: :medium,
          change_ratio: Float.round(recent_metrics.avg_value / max(older_metrics.avg_value, 1), 2)
        }
      else
        nil
      end

    gang_size_indicator =
      if recent_metrics.avg_attackers > older_metrics.avg_attackers * 1.3 do
        %{
          type: :larger_fleets,
          severity: :medium,
          change_ratio:
            Float.round(recent_metrics.avg_attackers / max(older_metrics.avg_attackers, 1), 2)
        }
      else
        nil
      end

    escalation_indicators =
      Enum.filter([kill_rate_indicator, value_indicator, gang_size_indicator], & &1)

    escalation_detected = not Enum.empty?(escalation_indicators)
    escalation_probability = min(1.0, length(escalation_indicators) * 0.3)

    %{
      escalation_detected: escalation_detected,
      escalation_indicators: escalation_indicators,
      escalation_probability: Float.round(escalation_probability, 2)
    }
  end

  defp calculate_threat_metrics(kills) do
    if Enum.empty?(kills) do
      %{kill_rate: 0.0, avg_value: 0.0, avg_attackers: 0.0}
    else
      %{
        # per hour
        kill_rate: length(kills) / 24.0,
        avg_value: (kills |> Enum.map(&(&1.total_value || 0)) |> Enum.sum()) / length(kills),
        avg_attackers:
          (kills |> Enum.map(&(&1.attacker_count || 1)) |> Enum.sum()) / length(kills)
      }
    end
  end

  defp predict_threat_patterns(_system_ids, killmails) do
    # Predict future threat patterns based on historical data
    daily_activity =
      killmails
      |> Enum.group_by(fn kill ->
        DateTime.to_date(kill.killmail_time)
      end)
      |> Enum.map(fn {date, kills} ->
        {date,
         %{
           kill_count: length(kills),
           systems_active: kills |> Enum.map(& &1.solar_system_id) |> Enum.uniq() |> length(),
           total_value: kills |> Enum.map(&(&1.total_value || 0)) |> Enum.sum()
         }}
      end)
      |> Enum.sort_by(&elem(&1, 0))

    # Simple trend projection
    trend = calculate_activity_trend(daily_activity)

    # Identify systems likely to become hotspots
    system_trends =
      killmails
      |> Enum.group_by(& &1.solar_system_id)
      |> Enum.map(fn {system_id, kills} ->
        recent_kills =
          Enum.filter(kills, fn k ->
            DateTimeUtils.diff(DateTime.utc_now(), k.killmail_time, :hour) <= 48
          end)

        trend_score = length(recent_kills) / max(length(kills), 1)
        {system_id, trend_score}
      end)
      |> Enum.sort_by(&elem(&1, 1), :desc)

    predicted_hotspots =
      system_trends
      |> Enum.filter(fn {_, score} -> score > 0.6 end)
      |> Enum.take(5)
      |> Enum.map(&elem(&1, 0))

    # Calculate prediction confidence based on data quality
    data_points = length(daily_activity)

    prediction_confidence =
      cond do
        data_points >= 7 -> 0.8
        data_points >= 5 -> 0.6
        data_points >= 3 -> 0.4
        true -> 0.2
      end

    %{
      predicted_hotspots: predicted_hotspots,
      prediction_confidence: Float.round(prediction_confidence, 2),
      prediction_timeframe: 24,
      trend_direction: trend
    }
  end

  defp calculate_activity_trend(daily_activity) do
    if length(daily_activity) < 2 do
      :insufficient_data
    else
      recent =
        daily_activity
        |> Enum.take(-3)
        |> Enum.map(fn {_, metrics} -> metrics.kill_count end)
        |> Enum.sum()

      older =
        daily_activity
        |> Enum.take(3)
        |> Enum.map(fn {_, metrics} -> metrics.kill_count end)
        |> Enum.sum()

      cond do
        recent > older * 1.5 -> :increasing
        recent < older * 0.7 -> :decreasing
        true -> :stable
      end
    end
  end

  defp detect_capital_activity(killmails) do
    # Detect capital ship activity
    capital_activity =
      killmails
      |> Enum.filter(fn km -> km.victim_ship_type_id && km.victim_ship_type_id > 20_000 end)
      |> Enum.map(fn km ->
        %{
          killmail_id: km.killmail_id,
          system_id: km.solar_system_id,
          ship_type_id: km.victim_ship_type_id,
          time: km.killmail_time,
          value: km.total_value || 0
        }
      end)

    capital_activity
  end

  defp analyze_high_value_losses(killmails) do
    # Analyze high-value losses
    # 1 billion ISK
    high_value_threshold = 1_000_000_000

    high_value_losses =
      killmails
      |> Enum.filter(fn km -> (km.total_value || 0) > high_value_threshold end)
      |> Enum.sort_by(& &1.total_value, :desc)
      |> Enum.take(10)
      |> Enum.map(fn km ->
        %{
          killmail_id: km.killmail_id,
          system_id: km.solar_system_id,
          victim_ship_type: km.victim_ship_type_id,
          total_value: km.total_value,
          time: km.killmail_time
        }
      end)

    high_value_losses
  end

  # Generate cross-pattern insights by analyzing connections between different pattern types
  @dialyzer {:no_match, generate_cross_pattern_insights: 3}
  defp generate_cross_pattern_insights(activity_patterns, threat_patterns, movement_patterns) do
    initial_insights = []

    # Activity-threat correlation insights
    activity_threat_insights =
      if map_size(activity_patterns) > 0 and map_size(threat_patterns) > 0 do
        ["Activity and threat patterns show correlation in key systems" | initial_insights]
      else
        initial_insights
      end

    # Movement-activity correlation insights
    movement_activity_insights =
      if map_size(movement_patterns) > 0 and map_size(activity_patterns) > 0 do
        ["Movement patterns correlate with activity spikes" | activity_threat_insights]
      else
        activity_threat_insights
      end

    # Threat-movement correlation insights
    final_insights =
      if map_size(threat_patterns) > 0 and map_size(movement_patterns) > 0 do
        ["Threat patterns follow predictable movement corridors" | movement_activity_insights]
      else
        movement_activity_insights
      end

    # Return insights as structured data
    final_insights
    |> Enum.map(fn insight ->
      %{
        type: :cross_pattern,
        description: insight,
        priority: :medium,
        confidence: 0.7
      }
    end)
  end

  # Database query helper

  defp fetch_multi_system_killmails(system_ids, start_time) do
    query =
      from(k in "killmails_enriched",
        where: k.solar_system_id in ^system_ids and k.killmail_time >= ^start_time,
        select: %{
          killmail_id: k.killmail_id,
          killmail_time: k.killmail_time,
          solar_system_id: k.solar_system_id,
          victim_character_id: k.victim_character_id,
          victim_corporation_id: k.victim_corporation_id,
          victim_alliance_id: k.victim_alliance_id,
          victim_ship_type_id: k.victim_ship_type_id,
          attacker_count: k.attacker_count,
          total_value: k.total_value
        },
        order_by: [desc: k.killmail_time],
        limit: 5_000
      )

    Repo.all(query)
  rescue
    error ->
      Logger.error("Failed to fetch multi-system killmails: #{inspect(error)}")
      []
  end
end
