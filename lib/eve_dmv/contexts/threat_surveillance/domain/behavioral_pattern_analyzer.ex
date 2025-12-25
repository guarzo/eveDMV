defmodule EveDmv.Contexts.ThreatSurveillance.Domain.BehavioralPatternAnalyzer do
  @compile {:nowarn_unused_function}
  @moduledoc """
  Analyzes behavioral patterns of characters and corporations from killmail data.

  Detects patterns such as:
  - Activity time preferences (timezone analysis)
  - System/region preferences
  - Ship type preferences
  - Engagement patterns (solo vs fleet)
  - Target selection patterns
  - Anomalous behavior detection

  All analysis is based on real killmail data from the database.
  """

  import Ecto.Query

  # alias EveDmv.Api
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Shared.Infrastructure.UnifiedCache
  alias EveDmv.StaticData

  require Logger

  # 5 minutes
  @cache_ttl 300
  # @anomaly_threshold 2.5 # Standard deviations for anomaly detection

  @doc """
  Analyze behavioral patterns for an entity (character or corporation).

  ## Parameters
  - `entity_id` - Character or corporation ID
  - `entity_type` - :character or :corporation
  - `options` - Analysis options
    - `:timeframe` - Analysis period (default: last 90 days)
    - `:pattern_types` - Specific patterns to analyze (default: all)

  ## Returns
  - `{:ok, patterns}` - Analysis results with detected patterns
  - `{:error, reason}` - Error if analysis fails
  """
  @spec analyze_patterns(integer(), atom(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_patterns(entity_id, entity_type, options \\ []) do
    Logger.info("Analyzing behavioral patterns",
      entity_type: entity_type,
      entity_id: entity_id
    )

    timeframe = Keyword.get(options, :timeframe, 90)
    pattern_types = Keyword.get(options, :pattern_types, :all)

    cache_key = {:behavior_patterns, entity_type, entity_id, timeframe}

    case UnifiedCache.get(:threat, cache_key) do
      {:ok, cached_patterns} ->
        {:ok, cached_patterns}

      {:error, :not_found} ->
        with {:ok, killmails} <- fetch_entity_killmails(entity_id, entity_type, timeframe),
             {:ok, patterns} <- analyze_killmail_patterns(killmails, entity_type, pattern_types) do
          UnifiedCache.put(:threat, cache_key, patterns, @cache_ttl)
          {:ok, patterns}
        else
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Detect anomalous behavior for an entity based on recent activity.

  ## Parameters
  - `entity_id` - Character or corporation ID
  - `recent_activity` - Recent killmails or activity data

  ## Returns
  - `{:ok, anomalies}` - Detected anomalies with confidence scores
  - `{:error, reason}` - Error if detection fails
  """
  @spec detect_anomalies(integer(), list()) :: {:ok, map()} | {:error, term()}
  def detect_anomalies(entity_id, recent_activity) do
    Logger.info("Detecting anomalous behavior", entity_id: entity_id)

    with {:ok, baseline_patterns} <- get_baseline_patterns(entity_id),
         {:ok, recent_patterns} <- analyze_recent_patterns(recent_activity),
         anomalies <- compare_patterns(baseline_patterns, recent_patterns) do
      {:ok,
       %{
         anomalies: anomalies,
         baseline: baseline_patterns,
         recent: recent_patterns,
         detection_time: DateTime.utc_now()
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Process a killmail to update behavioral patterns.

  ## Parameters
  - `event` - KillmailEnriched event

  ## Returns
  - `:ok` - Processing complete
  """
  @spec process_killmail(map()) :: :ok
  def process_killmail(event) do
    Logger.debug("Processing killmail for behavioral analysis", killmail_id: event.killmail_id)

    # Extract entities to analyze
    entities = extract_entities_from_killmail(event)

    # Invalidate caches for affected entities
    Enum.each(entities, fn {entity_id, entity_type} ->
      UnifiedCache.delete(:threat, {:behavior_patterns, entity_type, entity_id, 90})
      UnifiedCache.delete(:threat, {:behavior_patterns, entity_type, entity_id, 30})
    end)

    :ok
  end

  @doc """
  Get behavioral analysis metrics.

  ## Returns
  - Map of current metrics
  """
  def get_metrics do
    %{
      analyzed_entities: count_analyzed_entities(),
      anomalies_detected: count_recent_anomalies(),
      pattern_cache_hit_rate: UnifiedCache.get_hit_rate(:surveillance),
      last_analysis: get_last_analysis_time()
    }
  end

  # Private implementation functions

  defp fetch_entity_killmails(entity_id, :character, days) do
    since = DateTimeUtils.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)

    # Get killmails where character was victim
    victim_query =
      from(k in KillmailRaw,
        where: fragment("?->>'character_id' = ?", k.victim, ^to_string(entity_id)),
        where: k.killmail_time > ^since,
        order_by: [desc: k.killmail_time],
        limit: 1000
      )

    case EveDmv.Repo.all(victim_query) do
      killmails when is_list(killmails) ->
        # Focus on victim killmails for character behavior analysis
        {:ok, killmails}

      _ ->
        {:error, :query_failed}
    end
  end

  defp fetch_entity_killmails(entity_id, :corporation, days) do
    since = DateTimeUtils.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)

    # Get killmails where corporation members were victims
    victim_query =
      from(k in KillmailRaw,
        where: fragment("?->>'corporation_id' = ?", k.victim, ^to_string(entity_id)),
        where: k.killmail_time > ^since,
        order_by: [desc: k.killmail_time],
        limit: 1000
      )

    case EveDmv.Repo.all(victim_query) do
      killmails when is_list(killmails) ->
        {:ok, killmails}

      _ ->
        {:error, :query_failed}
    end
  end

  defp analyze_killmail_patterns(killmails, _entity_type, pattern_types) do
    if killmails == [] do
      {:ok,
       %{
         activity_patterns: %{},
         system_patterns: %{},
         ship_patterns: %{},
         engagement_patterns: %{},
         temporal_patterns: %{},
         data_points: 0
       }}
    else
      patterns = %{
        activity_patterns: analyze_activity_patterns(killmails),
        system_patterns: analyze_system_patterns(killmails),
        ship_patterns: analyze_ship_patterns(killmails),
        engagement_patterns: analyze_engagement_patterns(killmails),
        temporal_patterns: analyze_temporal_patterns(killmails),
        data_points: length(killmails)
      }

      filtered_patterns =
        if pattern_types == :all do
          patterns
        else
          Map.take(patterns, pattern_types ++ [:data_points])
        end

      {:ok, filtered_patterns}
    end
  end

  defp analyze_activity_patterns(killmails) do
    # Group by hour of day to find activity patterns
    hourly_activity =
      killmails
      |> Enum.group_by(fn km -> km.killmail_time.hour end)
      |> Enum.map(fn {hour, kms} -> {hour, length(kms)} end)
      |> Map.new()

    # Find peak activity hours
    total_kills = length(killmails)

    peak_hours =
      hourly_activity
      |> Enum.sort_by(fn {_hour, count} -> count end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {hour, _} -> hour end)

    # Calculate timezone likelihood
    timezone_estimate = estimate_timezone(hourly_activity)

    %{
      hourly_distribution: hourly_activity,
      peak_hours: peak_hours,
      estimated_timezone: timezone_estimate,
      activity_concentration: calculate_activity_concentration(hourly_activity, total_kills)
    }
  end

  defp analyze_system_patterns(killmails) do
    # Group by system
    system_activity =
      killmails
      |> Enum.group_by(& &1.solar_system_id)
      |> Enum.map(fn {system_id, kms} -> {system_id, length(kms)} end)
      |> Enum.sort_by(fn {_, count} -> count end, :desc)

    # Calculate system diversity
    unique_systems = length(system_activity)
    total_kills = length(killmails)

    # Get top systems
    top_systems = Enum.take(system_activity, 10)

    # Calculate security preference
    security_preference = calculate_security_preference(killmails)

    %{
      top_systems: top_systems,
      unique_systems: unique_systems,
      system_diversity_index: calculate_diversity_index(system_activity, total_kills),
      security_preference: security_preference
    }
  end

  defp analyze_ship_patterns(killmails) do
    # Group by ship type
    ship_usage =
      killmails
      |> Enum.map(&extract_ship_type_id/1)
      |> Enum.filter(&(&1 != nil))
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_, count} -> count end, :desc)

    # Categorize by ship class
    ship_classes =
      ship_usage
      |> Enum.map(fn {ship_id, count} ->
        ship_class = StaticData.get_ship_class(ship_id)
        {ship_class, count}
      end)
      |> Enum.reduce(%{}, fn {class, count}, acc ->
        Map.update(acc, class, count, &(&1 + count))
      end)

    %{
      preferred_ships: Enum.take(ship_usage, 10),
      ship_classes: ship_classes,
      ship_diversity: length(ship_usage),
      average_ship_value: calculate_average_ship_value(killmails)
    }
  end

  defp analyze_engagement_patterns(killmails) do
    # Analyze how they engage in combat
    engagement_sizes =
      killmails
      |> Enum.map(&extract_attacker_count/1)
      |> Enum.frequencies()

    total_engagements = length(killmails)

    solo_engagements = Map.get(engagement_sizes, 1, 0)

    small_gang =
      Enum.sum(for {size, count} <- engagement_sizes, size >= 2 and size <= 5, do: count)

    fleet_engagements = Enum.sum(for {size, count} <- engagement_sizes, size > 10, do: count)

    %{
      solo_percentage: safe_percentage(solo_engagements, total_engagements),
      small_gang_percentage: safe_percentage(small_gang, total_engagements),
      fleet_percentage: safe_percentage(fleet_engagements, total_engagements),
      average_gang_size:
        calculate_average(
          Enum.flat_map(engagement_sizes, fn {size, count} -> List.duplicate(size, count) end)
        ),
      engagement_size_distribution: engagement_sizes
    }
  end

  defp analyze_temporal_patterns(killmails) do
    # Sort by time
    sorted_killmails = Enum.sort_by(killmails, & &1.killmail_time)

    if length(sorted_killmails) < 2 do
      %{
        average_interval_hours: 0,
        activity_bursts: [],
        longest_gap_hours: 0,
        consistency_score: 0
      }
    else
      # Calculate time between kills
      intervals =
        sorted_killmails
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [km1, km2] ->
          DateTimeUtils.diff(km2.killmail_time, km1.killmail_time, :second) / 3600
        end)

      %{
        average_interval_hours: calculate_average(intervals),
        activity_bursts: identify_activity_bursts(sorted_killmails),
        longest_gap_hours: Enum.max(intervals, fn -> 0 end),
        consistency_score: calculate_consistency_score(intervals)
      }
    end
  end

  # Helper functions

  defp estimate_timezone(hourly_activity) do
    # Simple timezone estimation based on peak activity hours
    # This is a simplified approach - real implementation would be more sophisticated
    peak_hour =
      hourly_activity
      |> Enum.max_by(fn {_hour, count} -> count end, fn -> {12, 0} end)
      |> elem(0)

    cond do
      peak_hour >= 18 and peak_hour <= 23 -> "US Timezones"
      peak_hour >= 12 and peak_hour <= 17 -> "EU Timezones"
      peak_hour >= 6 and peak_hour <= 11 -> "AU Timezones"
      true -> "Mixed/Unknown"
    end
  end

  defp calculate_activity_concentration(hourly_activity, total_kills) do
    # Calculate how concentrated activity is (0-1, higher = more concentrated)
    if total_kills == 0 do
      0.0
    else
      max_hour_kills =
        hourly_activity
        |> Map.values()
        |> Enum.max(fn -> 0 end)

      if total_kills > 0 do
        Float.round(max_hour_kills / total_kills, 3)
      else
        0.0
      end
    end
  end

  defp calculate_diversity_index(item_counts, total) do
    # Shannon diversity index
    if total == 0 do
      0.0
    else
      item_counts
      |> Enum.reduce(0.0, fn {_item, count}, acc ->
        proportion =
          if total > 0 do
            count / total
          else
            0.0
          end

        if proportion > 0 do
          acc - proportion * :math.log(proportion)
        else
          acc
        end
      end)
      |> Float.round(3)
    end
  end

  defp calculate_security_preference(killmails) do
    security_counts =
      killmails
      |> Enum.map(fn km ->
        system_sec = StaticData.get_system_security(km.solar_system_id)

        cond do
          system_sec >= 0.5 -> :highsec
          system_sec > 0.0 -> :lowsec
          system_sec == 0.0 -> :nullsec
          true -> :wormhole
        end
      end)
      |> Enum.frequencies()

    total = length(killmails)

    %{
      highsec: safe_percentage(Map.get(security_counts, :highsec, 0), total),
      lowsec: safe_percentage(Map.get(security_counts, :lowsec, 0), total),
      nullsec: safe_percentage(Map.get(security_counts, :nullsec, 0), total),
      wormhole: safe_percentage(Map.get(security_counts, :wormhole, 0), total)
    }
  end

  defp calculate_average_ship_value(killmails) do
    values =
      killmails
      |> Enum.map(&(&1.zkb_total_value || 0))
      |> Enum.filter(&(&1 > 0))

    if Enum.empty?(values) do
      0
    else
      values_length = length(values)

      if values_length > 0 do
        Enum.sum(values) / values_length
      else
        0.0
      end
    end
  end

  defp safe_percentage(count, total) when total > 0 do
    if total > 0 do
      Float.round(count / total * 100, 1)
    else
      0.0
    end
  end

  defp safe_percentage(_, _), do: 0.0

  defp calculate_average([_ | _] = list) do
    Float.round(Enum.sum(list) / length(list), 2)
  end

  defp calculate_average([]), do: 0.0

  defp calculate_average(_), do: 0.0

  defp identify_activity_bursts(sorted_killmails) do
    # Find periods of intense activity (multiple kills within 1 hour)
    sorted_killmails
    |> Enum.chunk_by(fn km ->
      # Group by hour
      {km.killmail_time.year, km.killmail_time.month, km.killmail_time.day, km.killmail_time.hour}
    end)
    |> Enum.filter(fn chunk -> length(chunk) >= 3 end)
    |> Enum.map(fn chunk ->
      %{
        start_time: get_safe_first_killmail_time(chunk),
        end_time: get_safe_last_killmail_time(chunk),
        kill_count: length(chunk)
      }
    end)
    |> Enum.take(10)
  end

  defp calculate_consistency_score(intervals) do
    if length(intervals) < 2 do
      0.0
    else
      # Calculate coefficient of variation (lower = more consistent)
      intervals_length = length(intervals)

      mean =
        if intervals_length > 0 do
          Enum.sum(intervals) / intervals_length
        else
          0.0
        end

      if mean == 0 do
        0.0
      else
        variance =
          intervals
          |> Enum.map(fn x -> :math.pow(x - mean, 2) end)
          |> Enum.sum()
          |> Kernel./(length(intervals))

        std_dev = :math.sqrt(variance)
        cv = std_dev / mean

        # Convert to 0-1 score where 1 = highly consistent
        consistency = max(0, 1 - cv)
        Float.round(consistency, 3)
      end
    end
  end

  # Anomaly detection functions

  defp get_baseline_patterns(entity_id) do
    # Get historical patterns (90 days)
    analyze_patterns(entity_id, :character, timeframe: 90, pattern_types: :all)
  end

  defp analyze_recent_patterns(recent_activity) do
    # Analyze patterns in recent activity (last 24-48 hours)
    if is_list(recent_activity) and not Enum.empty?(recent_activity) do
      analyze_killmail_patterns(recent_activity, :character, :all)
    else
      {:ok, %{}}
    end
  end

  defp compare_patterns(baseline, recent) do
    []
    |> then(fn anomalies ->
      # Check for timezone anomalies
      detect_timezone_anomaly(baseline, recent, anomalies)
    end)
    |> then(fn anomalies ->
      # Check for system anomalies
      detect_system_anomaly(baseline, recent, anomalies)
    end)
    |> then(fn anomalies ->
      # Check for ship type anomalies
      detect_ship_anomaly(baseline, recent, anomalies)
    end)
    |> then(fn anomalies ->
      # Check for engagement pattern anomalies
      detect_engagement_anomaly(baseline, recent, anomalies)
    end)
  end

  defp detect_timezone_anomaly(baseline, recent, anomalies) do
    baseline_peaks = get_in(baseline, [:activity_patterns, :peak_hours]) || []
    recent_peaks = get_in(recent, [:activity_patterns, :peak_hours]) || []

    if Enum.empty?(recent_peaks) or Enum.empty?(baseline_peaks) do
      anomalies
    else
      # Check if recent activity is outside normal hours
      unusual_hours = Enum.reject(recent_peaks, &(&1 in baseline_peaks))

      if Enum.empty?(unusual_hours) do
        anomalies
      else
        [
          {:timezone_anomaly,
           %{
             confidence: 0.8,
             description: "Activity detected outside normal hours",
             unusual_hours: unusual_hours,
             normal_hours: baseline_peaks
           }}
          | anomalies
        ]
      end
    end
  end

  defp detect_system_anomaly(baseline, recent, anomalies) do
    baseline_systems =
      get_in(baseline, [:system_patterns, :top_systems])
      |> Enum.map(fn {sys_id, _} -> sys_id end)
      |> Enum.take(20)

    recent_systems =
      get_in(recent, [:system_patterns, :top_systems])
      |> Enum.map(fn {sys_id, _} -> sys_id end)

    if not Enum.empty?(recent_systems) and not Enum.empty?(baseline_systems) do
      # Check for activity in unusual systems
      new_systems = Enum.reject(recent_systems, &(&1 in baseline_systems))

      if length(new_systems) > length(recent_systems) * 0.5 do
        [
          {:system_anomaly,
           %{
             confidence: 0.9,
             description: "Activity in unusual systems",
             new_systems: new_systems,
             percentage_new: calculate_percentage_new_systems(new_systems, recent_systems)
           }}
          | anomalies
        ]
      else
        anomalies
      end
    else
      anomalies
    end
  end

  defp detect_ship_anomaly(baseline, recent, anomalies) do
    baseline_ships = Map.keys(get_in(baseline, [:ship_patterns, :ship_classes]) || %{})
    recent_ships = Map.keys(get_in(recent, [:ship_patterns, :ship_classes]) || %{})

    if Enum.empty?(recent_ships) or Enum.empty?(baseline_ships) do
      anomalies
    else
      # Check for unusual ship usage
      new_ship_classes = Enum.reject(recent_ships, &(&1 in baseline_ships))

      if Enum.empty?(new_ship_classes) do
        anomalies
      else
        [
          {:ship_anomaly,
           %{
             confidence: 0.7,
             description: "Using unusual ship classes",
             new_classes: new_ship_classes
           }}
          | anomalies
        ]
      end
    end
  end

  defp detect_engagement_anomaly(baseline, recent, anomalies) do
    baseline_solo = get_in(baseline, [:engagement_patterns, :solo_percentage]) || 0
    recent_solo = get_in(recent, [:engagement_patterns, :solo_percentage]) || 0

    # Check for significant change in engagement style
    if abs(baseline_solo - recent_solo) > 30 do
      [
        {:engagement_anomaly,
         %{
           confidence: 0.85,
           description: "Significant change in engagement patterns",
           baseline_solo: baseline_solo,
           recent_solo: recent_solo
         }}
        | anomalies
      ]
    else
      anomalies
    end
  end

  defp extract_entities_from_killmail(event) do
    victim_entities = extract_entities_from_actor(event.victim)

    attacker_entities =
      event.attackers
      |> Enum.flat_map(&extract_entities_from_actor/1)
      |> Enum.uniq()

    victim_entities ++ attacker_entities
  end

  defp extract_entities_from_actor(actor) do
    []
    |> maybe_add_character_entity(actor["character_id"])
    |> maybe_add_corporation_entity(actor["corporation_id"])
  end

  defp maybe_add_character_entity(entities, nil), do: entities

  defp maybe_add_character_entity(entities, character_id),
    do: [{character_id, :character} | entities]

  defp maybe_add_corporation_entity(entities, nil), do: entities

  defp maybe_add_corporation_entity(entities, corporation_id),
    do: [{corporation_id, :corporation} | entities]

  # Metrics functions

  defp count_analyzed_entities do
    # This would query a tracking table in production
    # For now, return a placeholder that could be replaced with real tracking
    0
  end

  defp count_recent_anomalies do
    # This would query recent anomaly detections
    0
  end

  defp get_last_analysis_time do
    # This would track the last analysis run
    DateTime.utc_now()
  end

  # Helper functions for safe operations

  defp get_safe_first_killmail_time(chunk) do
    case List.first(chunk) do
      nil -> DateTime.utc_now()
      km -> km.killmail_time
    end
  end

  defp get_safe_last_killmail_time(chunk) do
    case List.last(chunk) do
      nil -> DateTime.utc_now()
      km -> km.killmail_time
    end
  end

  defp calculate_percentage_new_systems(new_systems, recent_systems) do
    recent_count = length(recent_systems)

    if recent_count > 0 do
      Float.round(length(new_systems) / recent_count * 100, 1)
    else
      0.0
    end
  end

  # Helper functions to extract data from killmail structure
  defp extract_ship_type_id(killmail) do
    killmail.victim_ship_type_id
  end

  defp extract_attacker_count(killmail) do
    case killmail.raw_data do
      %{"attackers" => attackers} when is_list(attackers) -> length(attackers)
      # Default to 1 if no attacker data
      _ -> 1
    end
  end
end
