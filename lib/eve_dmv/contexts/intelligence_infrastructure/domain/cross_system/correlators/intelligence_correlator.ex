defmodule EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Correlators.IntelligenceCorrelator do
  @moduledoc """
  Correlator for intelligence data across multiple systems.
  """

  alias EveDmv.Repo
  import Ecto.Query
  require Logger

  # Correlation weight constants
  @overlap_weight 0.4
  @quality_weight 0.3
  @temporal_weight 0.3

  # Quality assessment thresholds
  @stale_data_threshold_hours 48
  @insufficient_data_threshold 0.3
  @incomplete_coverage_types_threshold 2
  @age_weight_factor 0.3
  @completeness_weight_factor 0.4
  @coverage_severity_divisor 72

  @doc """
  Correlate intelligence data across systems.
  """
  def correlate_intelligence(system_ids, _options) do
    Logger.debug("Correlating intelligence across #{length(system_ids)} systems")

    %{
      intelligence_correlation_strength: calculate_intelligence_correlation_strength(system_ids),
      shared_intelligence: identify_shared_intelligence(system_ids),
      intelligence_gaps: identify_intelligence_gaps(system_ids),
      intelligence_quality: assess_intelligence_quality(system_ids)
    }
  end

  defp calculate_intelligence_correlation_strength(system_ids) do
    # Calculate intelligence correlation based on data overlap and quality
    if length(system_ids) < 2 do
      0.0
    else
      # Get intelligence coverage for each system
      intel_coverage = fetch_intelligence_coverage(system_ids)

      if map_size(intel_coverage) == 0 do
        0.0
      else
        # Calculate overlap between systems
        overlap_score = calculate_intelligence_overlap(intel_coverage)

        # Calculate data quality score
        quality_score = calculate_data_quality_score(intel_coverage)

        # Calculate temporal correlation
        temporal_score = calculate_temporal_correlation(intel_coverage)

        # Combine scores
        correlation_strength =
          overlap_score * @overlap_weight + quality_score * @quality_weight +
            temporal_score * @temporal_weight

        Float.round(correlation_strength, 2)
      end
    end
  end

  defp identify_shared_intelligence(system_ids) do
    # Identify intelligence that spans multiple systems
    if length(system_ids) < 2 do
      []
    else
      intel_data = fetch_cross_system_intelligence(system_ids)

      # Pattern 1: Character sightings across systems
      character_intel = analyze_character_sightings(intel_data)

      # Pattern 2: Fleet movements
      fleet_intel = analyze_fleet_intelligence(intel_data)

      # Pattern 3: Structure status changes
      structure_intel = analyze_structure_intelligence(intel_data)

      # Pattern 4: Alliance operations
      alliance_intel = analyze_alliance_operations(intel_data)

      # Concatenate all intelligence lists
      shared_intel = character_intel ++ fleet_intel ++ structure_intel ++ alliance_intel

      # Sort by relevance and take top results
      shared_intel
      |> Enum.sort_by(& &1.relevance_score, :desc)
      |> Enum.take(10)
    end
  end

  defp identify_intelligence_gaps(system_ids) do
    # Identify gaps in intelligence coverage
    if Enum.empty?(system_ids) do
      %{
        coverage_gaps: [],
        data_quality_issues: [],
        priority_systems: []
      }
    else
      # Analyze coverage for each system
      coverage_analysis = analyze_system_coverage(system_ids)

      # Identify systems with poor coverage
      coverage_gaps =
        coverage_analysis
        |> Enum.filter(fn {_system, coverage} -> coverage.coverage_score < 0.3 end)
        |> Enum.map(fn {system, coverage} ->
          %{
            system_id: system,
            coverage_score: coverage.coverage_score,
            missing_data_types: coverage.missing_types,
            last_update: coverage.last_update
          }
        end)

      # Identify data quality issues
      data_quality_issues =
        coverage_analysis
        |> Enum.filter(fn {_system, coverage} ->
          coverage.data_age_hours > 24 or coverage.data_completeness < 0.5
        end)
        |> Enum.map(fn {system, coverage} ->
          %{
            system_id: system,
            issue_type: determine_quality_issue(coverage),
            severity: rate_issue_severity(coverage),
            recommendation: suggest_remediation(coverage)
          }
        end)

      # Prioritize systems for intelligence gathering
      priority_systems =
        coverage_analysis
        |> Enum.sort_by(
          fn {_system, coverage} ->
            # Prioritize by strategic value and coverage gap
            coverage.strategic_value * (1 - coverage.coverage_score)
          end,
          :desc
        )
        |> Enum.take(5)
        |> Enum.map(fn {system, coverage} ->
          %{
            system_id: system,
            priority_score:
              Float.round(coverage.strategic_value * (1 - coverage.coverage_score), 2),
            reasoning: determine_priority_reasoning(coverage)
          }
        end)

      %{
        coverage_gaps: coverage_gaps,
        data_quality_issues: data_quality_issues,
        priority_systems: priority_systems,
        overall_coverage: calculate_overall_coverage(coverage_analysis)
      }
    end
  end

  defp assess_intelligence_quality(system_ids) do
    # Assess overall intelligence quality across systems
    if Enum.empty?(system_ids) do
      %{
        overall_quality: 0.0,
        data_freshness: 0.0,
        coverage_completeness: 0.0,
        reliability_score: 0.0
      }
    else
      # Get quality metrics for each system
      quality_metrics = fetch_quality_metrics(system_ids)

      # Calculate data freshness
      data_freshness = calculate_data_freshness(quality_metrics)

      # Calculate coverage completeness
      coverage_completeness = calculate_coverage_completeness(quality_metrics)

      # Calculate reliability score
      reliability_score = calculate_reliability_score(quality_metrics)

      # Calculate overall quality
      overall_quality =
        data_freshness * 0.3 + coverage_completeness * 0.4 + reliability_score * 0.3

      %{
        overall_quality: Float.round(overall_quality, 2),
        data_freshness: Float.round(data_freshness, 2),
        coverage_completeness: Float.round(coverage_completeness, 2),
        reliability_score: Float.round(reliability_score, 2),
        quality_breakdown: build_quality_breakdown(quality_metrics),
        recommendations:
          generate_quality_recommendations(overall_quality, data_freshness, coverage_completeness)
      }
    end
  end

  # Helper functions

  defp fetch_intelligence_coverage(system_ids) do
    # Fetch intelligence data coverage for systems
    start_time = DateTime.add(DateTime.utc_now(), -72 * 3600, :second)

    query =
      from(k in "killmails_enriched",
        where: k.solar_system_id in ^system_ids and k.killmail_time >= ^start_time,
        group_by: k.solar_system_id,
        select: %{
          system_id: k.solar_system_id,
          kill_count: count(k.killmail_id),
          unique_characters: count(fragment("DISTINCT ?", k.victim_character_id)),
          unique_corporations: count(fragment("DISTINCT ?", k.victim_corporation_id)),
          latest_activity: max(k.killmail_time),
          earliest_activity: min(k.killmail_time)
        }
      )

    results = Repo.all(query)

    # Convert to map for easier access
    results
    |> Enum.map(fn r ->
      {r.system_id,
       %{
         coverage_metrics: r,
         data_density: calculate_data_density(r),
         temporal_coverage: calculate_temporal_coverage(r)
       }}
    end)
    |> Map.new()
  rescue
    error ->
      Logger.error("Failed to fetch intelligence coverage: #{inspect(error)}")
      %{}
  end

  defp calculate_intelligence_overlap(intel_coverage) do
    # Calculate how much intelligence overlaps between systems
    if map_size(intel_coverage) < 2 do
      0.0
    else
      # Extract all unique entities across systems
      all_characters =
        intel_coverage
        |> Enum.flat_map(fn {_system, data} ->
          get_in(data, [:coverage_metrics, :unique_characters]) || []
        end)
        |> List.flatten()

      # Calculate overlap ratio
      total_sightings = length(all_characters)
      unique_sightings = all_characters |> Enum.uniq() |> length()

      if total_sightings > 0 do
        overlap_ratio = 1 - unique_sightings / total_sightings
        Float.round(overlap_ratio, 2)
      else
        0.0
      end
    end
  end

  defp calculate_data_quality_score(intel_coverage) do
    # Calculate average data quality across systems
    if map_size(intel_coverage) == 0 do
      0.0
    else
      quality_scores =
        intel_coverage
        |> Enum.map(fn {_system, data} ->
          density = Map.get(data, :data_density, 0)
          temporal = Map.get(data, :temporal_coverage, 0)
          (density + temporal) / 2
        end)

      avg_quality = Enum.sum(quality_scores) / length(quality_scores)
      Float.round(avg_quality, 2)
    end
  end

  defp calculate_temporal_correlation(intel_coverage) do
    # Calculate if activity patterns are temporally correlated
    if map_size(intel_coverage) < 2 do
      0.0
    else
      # Check for simultaneous activity windows
      time_overlaps =
        intel_coverage
        |> Enum.map(fn {system, data} ->
          metrics = Map.get(data, :coverage_metrics, %{})
          {system, metrics.earliest_activity, metrics.latest_activity}
        end)
        |> calculate_time_overlap_score()

      Float.round(time_overlaps, 2)
    end
  end

  defp fetch_cross_system_intelligence(system_ids) do
    # Fetch detailed intelligence data for cross-system analysis
    start_time = DateTime.add(DateTime.utc_now(), -48 * 3600, :second)

    query =
      from(k in "killmails_enriched",
        where: k.solar_system_id in ^system_ids and k.killmail_time >= ^start_time,
        select: %{
          killmail_id: k.killmail_id,
          solar_system_id: k.solar_system_id,
          killmail_time: k.killmail_time,
          victim_character_id: k.victim_character_id,
          victim_corporation_id: k.victim_corporation_id,
          victim_alliance_id: k.victim_alliance_id,
          victim_ship_type_id: k.victim_ship_type_id,
          attacker_count: k.attacker_count,
          total_value: k.total_value
        },
        order_by: [desc: k.killmail_time],
        # Reduced from 5000 to 1000 for better memory efficiency
        # Still provides ~6 hours of data for high-activity systems
        limit: 1000
      )

    Repo.all(query)
  rescue
    error ->
      Logger.error("Failed to fetch cross-system intelligence: #{inspect(error)}")
      []
  end

  defp analyze_character_sightings(intel_data) do
    # Analyze character movements and sightings
    intel_data
    |> Enum.group_by(& &1.victim_character_id)
    |> Enum.filter(fn {char_id, sightings} ->
      char_id != nil and length(sightings) > 1
    end)
    |> Enum.map(fn {char_id, sightings} ->
      systems = sightings |> Enum.map(& &1.solar_system_id) |> Enum.uniq()

      %{
        type: :character_movement,
        entity_id: char_id,
        entity_type: :character,
        systems: systems,
        sighting_count: length(sightings),
        time_span: calculate_time_span(sightings),
        relevance_score: min(1.0, length(systems) * 0.2 + length(sightings) * 0.05)
      }
    end)
    |> Enum.sort_by(& &1.relevance_score, :desc)
    |> Enum.take(5)
  end

  defp analyze_fleet_intelligence(intel_data) do
    # Detect fleet operations from killmail patterns
    intel_data
    |> Enum.chunk_by(fn k ->
      {k.solar_system_id, k.killmail_time |> DateTime.truncate(:minute)}
    end)
    |> Enum.filter(fn chunk -> length(chunk) > 3 end)
    |> Enum.map(fn chunk ->
      %{
        type: :fleet_operation,
        entity_type: :fleet,
        systems: chunk |> Enum.map(& &1.solar_system_id) |> Enum.uniq(),
        size: length(chunk),
        time_window: List.first(chunk).killmail_time,
        participants: extract_fleet_participants(chunk),
        relevance_score: min(1.0, length(chunk) * 0.1)
      }
    end)
    |> Enum.take(5)
  end

  defp analyze_structure_intelligence(intel_data) do
    # Detect structure-related intelligence
    intel_data
    |> Enum.filter(fn k -> k.victim_ship_type_id && k.victim_ship_type_id > 35000 end)
    |> Enum.group_by(& &1.solar_system_id)
    |> Enum.map(fn {system, kills} ->
      %{
        type: :structure_activity,
        entity_type: :structure,
        systems: [system],
        structure_count: length(kills),
        total_value: kills |> Enum.map(&(&1.total_value || 0)) |> Enum.sum(),
        time_range: calculate_time_span(kills),
        relevance_score: min(1.0, length(kills) * 0.3)
      }
    end)
    |> Enum.take(3)
  end

  defp analyze_alliance_operations(intel_data) do
    # Detect alliance-level operations
    intel_data
    |> Enum.filter(& &1.victim_alliance_id)
    |> Enum.group_by(& &1.victim_alliance_id)
    |> Enum.filter(fn {_alliance, kills} -> length(kills) > 5 end)
    |> Enum.map(fn {alliance_id, kills} ->
      systems = kills |> Enum.map(& &1.solar_system_id) |> Enum.uniq()

      %{
        type: :alliance_operation,
        entity_id: alliance_id,
        entity_type: :alliance,
        systems: systems,
        operation_scale: length(kills),
        multi_system: length(systems) > 1,
        time_span: calculate_time_span(kills),
        relevance_score: min(1.0, length(systems) * 0.15 + length(kills) * 0.02)
      }
    end)
    |> Enum.sort_by(& &1.relevance_score, :desc)
    |> Enum.take(3)
  end

  defp analyze_system_coverage(system_ids) do
    # Analyze intelligence coverage for each system in parallel
    system_ids
    |> Task.async_stream(
      fn system_id ->
        coverage = analyze_single_system_coverage(system_id)
        {system_id, coverage}
      end,
      max_concurrency: 5,
      timeout: 10_000
    )
    |> Enum.reduce(%{}, fn
      {:ok, {system_id, coverage}}, acc -> Map.put(acc, system_id, coverage)
      {:exit, _reason}, acc -> acc
    end)
  end

  defp analyze_single_system_coverage(system_id) do
    # Analyze coverage for a single system
    start_time = DateTime.add(DateTime.utc_now(), -72 * 3600, :second)

    query =
      from(k in "killmails_enriched",
        where: k.solar_system_id == ^system_id and k.killmail_time >= ^start_time,
        select: %{
          kill_count: count(k.killmail_id),
          latest_activity: max(k.killmail_time),
          unique_entities:
            count(
              fragment("DISTINCT COALESCE(?, ?)", k.victim_character_id, k.victim_corporation_id)
            ),
          data_types: count(fragment("DISTINCT ?", k.victim_ship_type_id))
        }
      )

    result = Repo.one(query) || %{}

    kill_count = Map.get(result, :kill_count, 0)
    latest = Map.get(result, :latest_activity, start_time)
    data_age_hours = DateTime.diff(DateTime.utc_now(), latest, :hour)

    %{
      coverage_score: calculate_coverage_score(kill_count, data_age_hours),
      data_completeness: min(1.0, kill_count / 100),
      data_age_hours: data_age_hours,
      last_update: latest,
      missing_types: identify_missing_data_types(result),
      strategic_value: estimate_strategic_value(system_id)
    }
  rescue
    error ->
      Logger.error("Failed to analyze system coverage for #{system_id}: #{inspect(error)}")

      %{
        coverage_score: 0.0,
        data_completeness: 0.0,
        data_age_hours: 999,
        last_update: nil,
        missing_types: [:all],
        strategic_value: 0.5
      }
  end

  defp fetch_quality_metrics(system_ids) do
    # Fetch quality metrics for intelligence assessment
    system_ids
    |> Enum.map(fn system_id ->
      metrics = fetch_system_quality_metrics(system_id)
      {system_id, metrics}
    end)
    |> Map.new()
  end

  defp fetch_system_quality_metrics(system_id) do
    # Fetch quality metrics for a single system
    time_windows = [
      {1, DateTime.add(DateTime.utc_now(), -1 * 3600, :second)},
      {6, DateTime.add(DateTime.utc_now(), -6 * 3600, :second)},
      {24, DateTime.add(DateTime.utc_now(), -24 * 3600, :second)},
      {72, DateTime.add(DateTime.utc_now(), -72 * 3600, :second)}
    ]

    metrics =
      time_windows
      |> Enum.map(fn {hours, start_time} ->
        query =
          from(k in "killmails_enriched",
            where: k.solar_system_id == ^system_id and k.killmail_time >= ^start_time,
            select: count(k.killmail_id)
          )

        count = Repo.one(query) || 0
        {hours, count}
      end)
      |> Map.new()

    %{
      hourly_metrics: metrics,
      consistency: calculate_data_consistency(metrics),
      coverage_trend: calculate_coverage_trend(metrics)
    }
  rescue
    error ->
      Logger.error("Failed to fetch quality metrics for #{system_id}: #{inspect(error)}")
      %{hourly_metrics: %{}, consistency: 0.0, coverage_trend: :unknown}
  end

  # Additional helper functions

  defp calculate_data_density(metrics) do
    # Calculate how dense the data is (events per time unit)
    if metrics.kill_count == 0 do
      0.0
    else
      time_span = DateTime.diff(metrics.latest_activity, metrics.earliest_activity, :hour)

      if time_span > 0 do
        density = metrics.kill_count / time_span
        # Normalize to 0-1
        min(1.0, density / 10)
      else
        # Single time point
        0.5
      end
    end
  end

  defp calculate_temporal_coverage(metrics) do
    # Calculate how well the time period is covered
    # hours
    expected_span = 72
    actual_span = DateTime.diff(metrics.latest_activity, metrics.earliest_activity, :hour)
    min(1.0, actual_span / expected_span)
  end

  defp calculate_time_overlap_score(system_times) do
    # Calculate overlap in activity times between systems
    if length(system_times) < 2 do
      0.0
    else
      # Find overlapping time periods
      overlaps =
        for {s1, start1, end1} <- system_times,
            {s2, start2, end2} <- system_times,
            s1 < s2,
            DateTime.compare(start1, end2) != :gt,
            DateTime.compare(end1, start2) != :lt,
            do: calculate_overlap_duration(start1, end1, start2, end2)

      if length(overlaps) > 0 do
        avg_overlap = Enum.sum(overlaps) / length(overlaps)
        # Normalize to 0-1 based on 24 hour overlap
        min(1.0, avg_overlap / 24)
      else
        0.0
      end
    end
  end

  defp calculate_overlap_duration(start1, end1, start2, end2) do
    overlap_start = if DateTime.compare(start1, start2) == :gt, do: start1, else: start2
    overlap_end = if DateTime.compare(end1, end2) == :lt, do: end1, else: end2
    DateTime.diff(overlap_end, overlap_start, :hour)
  end

  defp calculate_time_span(items) do
    if Enum.empty?(items) do
      %{hours: 0, start: nil, end: nil}
    else
      times = items |> Enum.map(& &1.killmail_time) |> Enum.sort()
      first = List.first(times)
      last = List.last(times)

      %{
        hours: DateTime.diff(last, first, :hour),
        start: first,
        end: last
      }
    end
  end

  defp extract_fleet_participants(kills) do
    # Extract unique participants from fleet kills
    kills
    |> Enum.flat_map(fn k ->
      [k.victim_character_id, k.victim_corporation_id, k.victim_alliance_id]
    end)
    |> Enum.filter(& &1)
    |> Enum.uniq()
    |> length()
  end

  defp determine_quality_issue(coverage) do
    cond do
      coverage.data_age_hours > @stale_data_threshold_hours ->
        :stale_data

      coverage.data_completeness < @insufficient_data_threshold ->
        :insufficient_data

      length(coverage.missing_types) > @incomplete_coverage_types_threshold ->
        :incomplete_coverage

      true ->
        :quality_degradation
    end
  end

  defp rate_issue_severity(coverage) do
    severity_score =
      coverage.data_age_hours / @coverage_severity_divisor * @age_weight_factor +
        (1 - coverage.data_completeness) * @completeness_weight_factor +
        length(coverage.missing_types) / 5 * 0.3

    cond do
      severity_score > 0.7 -> :critical
      severity_score > 0.5 -> :high
      severity_score > 0.3 -> :medium
      true -> :low
    end
  end

  defp suggest_remediation(coverage) do
    cond do
      coverage.data_age_hours > 48 -> "Deploy scouts for fresh intelligence"
      coverage.data_completeness < 0.3 -> "Increase monitoring frequency"
      length(coverage.missing_types) > 2 -> "Expand intelligence collection scope"
      true -> "Maintain current collection efforts"
    end
  end

  defp determine_priority_reasoning(coverage) do
    cond do
      coverage.strategic_value > 0.8 and coverage.coverage_score < 0.3 ->
        "High strategic value with poor coverage"

      coverage.data_age_hours > 48 ->
        "Intelligence data critically outdated"

      coverage.data_completeness < 0.2 ->
        "Severe lack of intelligence data"

      true ->
        "Standard intelligence gap"
    end
  end

  defp calculate_overall_coverage(coverage_analysis) do
    if map_size(coverage_analysis) == 0 do
      0.0
    else
      total_score =
        coverage_analysis
        |> Enum.map(fn {_system, coverage} -> coverage.coverage_score end)
        |> Enum.sum()

      Float.round(total_score / map_size(coverage_analysis), 2)
    end
  end

  defp calculate_data_freshness(quality_metrics) do
    # Calculate average data freshness across systems
    if map_size(quality_metrics) == 0 do
      0.0
    else
      freshness_scores =
        quality_metrics
        |> Enum.map(fn {_system, metrics} ->
          recent_activity = Map.get(metrics.hourly_metrics, 1, 0)
          day_activity = Map.get(metrics.hourly_metrics, 24, 0)

          if day_activity > 0 do
            recent_ratio = recent_activity / day_activity
            # Boost recent activity
            min(1.0, recent_ratio * 2)
          else
            0.0
          end
        end)

      Enum.sum(freshness_scores) / length(freshness_scores)
    end
  end

  defp calculate_coverage_completeness(quality_metrics) do
    # Calculate how complete the coverage is
    if map_size(quality_metrics) == 0 do
      0.0
    else
      completeness_scores =
        quality_metrics
        |> Enum.map(fn {_system, metrics} ->
          consistency = Map.get(metrics, :consistency, 0)

          trend =
            case Map.get(metrics, :coverage_trend) do
              :improving -> 1.0
              :stable -> 0.7
              :degrading -> 0.4
              _ -> 0.5
            end

          (consistency + trend) / 2
        end)

      Enum.sum(completeness_scores) / length(completeness_scores)
    end
  end

  defp calculate_reliability_score(quality_metrics) do
    # Calculate reliability of intelligence data
    if map_size(quality_metrics) == 0 do
      0.0
    else
      reliability_scores =
        quality_metrics
        |> Enum.map(fn {_system, metrics} ->
          # Consistent data flow indicates reliability
          consistency = Map.get(metrics, :consistency, 0)

          # Multiple data points increase reliability
          data_points =
            metrics.hourly_metrics
            |> Map.values()
            |> Enum.sum()

          point_score = min(1.0, data_points / 100)

          consistency * 0.6 + point_score * 0.4
        end)

      Enum.sum(reliability_scores) / length(reliability_scores)
    end
  end

  defp build_quality_breakdown(quality_metrics) do
    # Build detailed quality breakdown
    quality_metrics
    |> Enum.map(fn {system, metrics} ->
      %{
        system_id: system,
        consistency: Map.get(metrics, :consistency, 0),
        coverage_trend: Map.get(metrics, :coverage_trend, :unknown),
        data_points_24h: Map.get(metrics.hourly_metrics, 24, 0)
      }
    end)
    |> Enum.sort_by(& &1.consistency, :desc)
  end

  defp generate_quality_recommendations(overall_quality, freshness, completeness) do
    recommendations = []

    recommendations =
      if overall_quality < 0.5 do
        ["Critical: Intelligence quality below acceptable threshold" | recommendations]
      else
        recommendations
      end

    recommendations =
      if freshness < 0.3 do
        ["Deploy scouts to gather fresh intelligence" | recommendations]
      else
        recommendations
      end

    recommendations =
      if completeness < 0.4 do
        ["Expand intelligence collection to cover gaps" | recommendations]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["Maintain current intelligence collection standards"]
    else
      recommendations
    end
  end

  defp calculate_coverage_score(kill_count, data_age_hours) do
    # Calculate coverage score based on data volume and age
    volume_score = min(1.0, kill_count / 50)
    freshness_score = max(0.0, 1.0 - data_age_hours / 72)

    volume_score * 0.6 + freshness_score * 0.4
  end

  defp identify_missing_data_types(result) do
    # Identify what types of data are missing
    missing = []

    missing =
      if Map.get(result, :kill_count, 0) == 0 do
        [:killmail_data | missing]
      else
        missing
      end

    missing =
      if Map.get(result, :unique_entities, 0) < 5 do
        [:entity_diversity | missing]
      else
        missing
      end

    missing =
      if Map.get(result, :data_types, 0) < 3 do
        [:ship_variety | missing]
      else
        missing
      end

    missing
  end

  defp estimate_strategic_value(system_id) do
    # Comprehensive strategic value calculation
    try do
      # 1. Get system security status
      security_score = calculate_security_score(system_id)

      # 2. Calculate trade route proximity
      trade_proximity_score = calculate_trade_proximity_score(system_id)

      # 3. Assess structure presence (placeholder for now as structure data not available)
      structure_score = estimate_structure_presence_score(system_id)

      # 4. Recent activity levels
      activity_score = calculate_activity_score(system_id)

      # 5. Alliance sovereignty importance (placeholder for now)
      sovereignty_score = estimate_sovereignty_importance(system_id)

      # 6. Wormhole connectivity (for J-space systems)
      connectivity_score = calculate_connectivity_score(system_id)

      # Weighted combination of all factors
      strategic_value =
        security_score * 0.15 +
          trade_proximity_score * 0.2 +
          structure_score * 0.15 +
          activity_score * 0.25 +
          sovereignty_score * 0.15 +
          connectivity_score * 0.1

      Float.round(strategic_value, 3)
    rescue
      error ->
        Logger.warning(
          "Failed to calculate strategic value for system #{system_id}: #{inspect(error)}"
        )

        # Return medium value on error
        0.5
    end
  end

  defp calculate_security_score(system_id) do
    # Query system security status
    query =
      from(s in "eve_solar_systems",
        where: s.solar_system_id == ^system_id,
        select: s.security_status
      )

    case Repo.one(query) do
      # Unknown system
      nil ->
        0.5

      security_status ->
        # Convert security status to strategic value
        # Null-sec (negative) and low-sec (0.0-0.4) are more strategically valuable
        cond do
          # Null-sec - highest value
          security_status < 0.0 -> 1.0
          # Low-sec - high value  
          security_status <= 0.4 -> 0.8
          # Mid-sec - medium value
          security_status <= 0.7 -> 0.4
          # High-sec - lower strategic value
          true -> 0.2
        end
    end
  end

  defp calculate_trade_proximity_score(system_id) do
    # Major trade hubs
    trade_hubs = [
      # Jita
      30_000_142,
      # Amarr
      30_002_187,
      # Dodixie
      30_002_659,
      # Rens
      30_002_510,
      # Hek
      30_002_053
    ]

    if system_id in trade_hubs do
      # Is a trade hub
      1.0
    else
      # Check proximity through stargates (simplified - checks direct connections)
      query =
        from(sg in "eve_stargates",
          where: sg.from_solar_system_id == ^system_id and sg.to_solar_system_id in ^trade_hubs,
          select: count()
        )

      case Repo.one(query) do
        # Not directly connected
        0 -> 0.3
        # Direct connection to trade hub
        _ -> 0.7
      end
    end
  end

  defp estimate_structure_presence_score(system_id) do
    # Placeholder - would query structure data when available
    # For now, estimate based on recent kill activity involving structures
    start_time = DateTime.add(DateTime.utc_now(), -30 * 24 * 3600, :second)

    query =
      from(k in "killmails_enriched",
        # Structure type IDs typically > 40000
        where:
          k.solar_system_id == ^system_id and
            k.killmail_time >= ^start_time and
            k.victim_ship_type_id > 40000 and
            k.victim_ship_type_id < 50000,
        select: count()
      )

    structure_kills = Repo.one(query) || 0

    cond do
      # Heavy structure presence
      structure_kills >= 10 -> 0.9
      # Moderate presence
      structure_kills >= 5 -> 0.7
      # Some presence
      structure_kills >= 1 -> 0.5
      # No recent structure activity
      true -> 0.3
    end
  end

  defp calculate_activity_score(system_id) do
    # Recent PvP activity levels
    start_time = DateTime.add(DateTime.utc_now(), -7 * 24 * 3600, :second)

    query =
      from(k in "killmails_enriched",
        where: k.solar_system_id == ^system_id and k.killmail_time >= ^start_time,
        select: %{
          kill_count: count(k.killmail_id),
          total_value: sum(k.total_value),
          unique_characters: count(k.victim_character_id, :distinct)
        }
      )

    case Repo.one(query) do
      %{kill_count: count, total_value: value, unique_characters: chars} when count > 0 ->
        # Normalize scores
        kill_score = min(count / 500.0, 1.0)
        value_score = if value, do: min(value / 50_000_000_000, 1.0), else: 0.0
        diversity_score = min(chars / 100.0, 1.0)

        # Combined activity score
        kill_score * 0.4 + value_score * 0.4 + diversity_score * 0.2

      _ ->
        # Minimal activity
        0.1
    end
  end

  defp estimate_sovereignty_importance(system_id) do
    # Placeholder - would query sovereignty data when available
    # For now, estimate based on alliance activity concentration
    start_time = DateTime.add(DateTime.utc_now(), -30 * 24 * 3600, :second)

    query =
      from(k in "killmails_enriched",
        where: k.solar_system_id == ^system_id and k.killmail_time >= ^start_time,
        group_by: k.victim_alliance_id,
        having: count() > 10,
        select: count()
      )

    active_alliances = Repo.all(query) |> length()

    cond do
      # Highly contested
      active_alliances >= 5 -> 0.9
      # Moderately contested
      active_alliances >= 3 -> 0.7
      # Some alliance presence
      active_alliances >= 1 -> 0.5
      # No significant alliance activity
      true -> 0.3
    end
  end

  defp calculate_connectivity_score(system_id) do
    # Check stargate connections
    query =
      from(sg in "eve_stargates",
        where: sg.from_solar_system_id == ^system_id,
        select: count()
      )

    connection_count = Repo.one(query) || 0

    # Also check if it's a wormhole system (J-space)
    is_wormhole = system_id >= 31_000_000 and system_id < 32_000_000

    cond do
      # Connected wormhole
      is_wormhole and connection_count > 0 -> 0.9
      # Isolated wormhole
      is_wormhole -> 0.7
      # Major crossroads
      connection_count >= 5 -> 0.8
      # Well connected
      connection_count >= 3 -> 0.6
      # Some connections
      connection_count >= 1 -> 0.4
      # Dead-end system
      true -> 0.2
    end
  end

  defp calculate_data_consistency(hourly_metrics) do
    # Calculate how consistent data flow is
    values = Map.values(hourly_metrics)

    if length(values) < 2 do
      0.0
    else
      # Check if data flow is consistent across time windows
      [h1, h6, h24, h72] = [1, 6, 24, 72] |> Enum.map(fn h -> Map.get(hourly_metrics, h, 0) end)

      # Expected ratios if data is consistent
      expected_6_1 = 6
      expected_24_1 = 24
      expected_72_1 = 72

      actual_6_1 = if h1 > 0, do: h6 / h1, else: 0
      actual_24_1 = if h1 > 0, do: h24 / h1, else: 0
      actual_72_1 = if h1 > 0, do: h72 / h1, else: 0

      # Calculate deviation from expected
      deviation_6 = abs(actual_6_1 - expected_6_1) / expected_6_1
      deviation_24 = abs(actual_24_1 - expected_24_1) / expected_24_1
      deviation_72 = abs(actual_72_1 - expected_72_1) / expected_72_1

      avg_deviation = (deviation_6 + deviation_24 + deviation_72) / 3

      # Convert to consistency score (lower deviation = higher consistency)
      max(0.0, 1.0 - avg_deviation)
    end
  end

  defp calculate_coverage_trend(hourly_metrics) do
    # Determine if coverage is improving, stable, or degrading
    _h1 = Map.get(hourly_metrics, 1, 0)
    h6 = Map.get(hourly_metrics, 6, 0)
    h24 = Map.get(hourly_metrics, 24, 0)

    recent_rate = h6 / 6
    older_rate = (h24 - h6) / 18

    cond do
      recent_rate > older_rate * 1.2 -> :improving
      recent_rate < older_rate * 0.8 -> :degrading
      true -> :stable
    end
  end
end
