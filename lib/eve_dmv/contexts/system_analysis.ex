defmodule EveDmv.Contexts.SystemAnalysis do
  @moduledoc """
  Context module for system activity analysis and regional intelligence.

  Provides analysis of solar system activity patterns, heatmaps, activity spillover
  detection, and regional correlation analysis.
  """
  alias EveDmv.Eve.SolarSystem
  alias EveDmv.Killmails.KillmailRaw
  require Ash.Query

  # Normalization constants
  @coordinate_scale 1.0e18
  @coordinate_offset 0.5

  # Activity level thresholds
  @activity_weight_multiplier 10
  @activity_high_threshold 50
  @activity_medium_threshold 20
  @activity_low_threshold 10
  @activity_minimal_threshold 3
  @hot_zone_threshold 20

  # Threat calculation weights
  @threat_weight_activity 3.0
  @threat_weight_value 12.0
  @threat_ratio_activity 0.6
  @threat_ratio_value 0.4

  # Escalation thresholds
  @escalation_kill_threshold 5
  @escalation_activity_threshold 10.0
  @escalation_value_threshold 50_000_000
  @escalation_weight_activity 0.6
  @escalation_weight_value 0.4

  # Spillover and correlation thresholds
  @spillover_filter_threshold 1.5
  @spillover_pattern_threshold_high 0.5
  @spillover_pattern_threshold_medium 0.3
  @spillover_pattern_threshold_negative -0.3
  @severity_high_threshold 10.0
  @severity_medium_threshold 5.0
  @severity_low_threshold 2.5
  @severity_minimal_threshold 1.5
  @activity_spike_threshold 30
  @activity_increase_threshold 15
  @activity_decrease_threshold 5
  @isk_high_threshold 1_000_000_000
  @isk_medium_threshold 500_000_000
  @isk_to_millions 1_000_000
  @escalation_isk_high_factor 5.0

  @doc """
  Analyzes activity level in a specific solar system.
  Returns activity metrics, trends, and patterns.
  """
  @spec analyze_system_activity(integer(), keyword()) :: {:ok, map()} | {:error, atom()}
  def analyze_system_activity(system_id, opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days, :day)

    # Query killmails in the system
    query =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.filter(solar_system_id == ^system_id)
      |> Ash.Query.filter(killmail_time >= ^cutoff_date)

    case Ash.read(query, domain: EveDmv.Api) do
      {:ok, killmails} ->
        analysis = %{
          system_id: system_id,
          kill_count: length(killmails),
          activity_level: calculate_activity_level(length(killmails), days),
          hourly_distribution: calculate_hourly_distribution(killmails),
          peak_hours: identify_peak_hours(killmails),
          trend: calculate_activity_trend(killmails)
        }

        {:ok, analysis}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Generates activity heatmap for a region or set of systems with real data.
  """
  @spec generate_heatmap(keyword()) :: {:ok, map()} | {:error, atom()}
  def generate_heatmap(opts) do
    hours = Keyword.get(opts, :hours, 24)
    _limit = Keyword.get(opts, :limit, 100)

    cutoff_date = DateTime.utc_now() |> DateTime.add(-hours, :hour)

    query =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.filter(killmail_time >= ^cutoff_date)

    case Ash.read(query, domain: EveDmv.Api) do
      {:ok, killmails} ->
        heatmap_data = generate_heatmap_from_killmails(killmails, opts)
        {:ok, heatmap_data}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets overview metrics for system analytics dashboard.
  """
  @spec get_overview_metrics() :: {:ok, map()} | {:error, atom()}
  def get_overview_metrics do
    last_24h = DateTime.utc_now() |> DateTime.add(-24, :hour)
    last_48h = DateTime.utc_now() |> DateTime.add(-48, :hour)

    # Get current period killmails
    current_query =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.filter(killmail_time >= ^last_24h)

    # Get previous period for comparison
    previous_query =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.filter(killmail_time >= ^last_48h)
      |> Ash.Query.filter(killmail_time < ^last_24h)

    case {Ash.read(current_query, domain: EveDmv.Api),
          Ash.read(previous_query, domain: EveDmv.Api)} do
      {{:ok, current_kills}, {:ok, previous_kills}} ->
        current_count = length(current_kills)
        previous_count = length(previous_kills)

        kills_change =
          if previous_count > 0 do
            ((current_count - previous_count) / previous_count * 100) |> Float.round(1)
          else
            0.0
          end

        active_systems =
          current_kills
          |> Enum.map(& &1.solar_system_id)
          |> Enum.uniq()
          |> length()

        # Query actual system count from database
        total_systems =
          case Ash.count(SolarSystem, domain: EveDmv.Api) do
            {:ok, count} -> count
            # Fallback to prevent division by zero
            _ -> 1
          end

        metrics = %{
          total_kills: current_count,
          kills_change: kills_change,
          active_systems: active_systems,
          active_percentage: Float.round(active_systems / max(1, total_systems) * 100, 1),
          total_systems: total_systems
          # Removed avg_response_time mock value - not implementable with real data
        }

        {:ok, metrics}

      {{:error, error}, _} ->
        {:error, error}

      {_, {:error, error}} ->
        {:error, error}
    end
  end

  @doc """
  Detects activity spillover between two systems.
  """
  @spec detect_activity_spillover(integer(), integer()) :: {:ok, map()} | {:error, atom()}
  def detect_activity_spillover(system_a, system_b) do
    days = 7
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days, :day)

    # Get activity for both systems
    {activity_a, activity_b} = get_system_activities(system_a, system_b, cutoff_date)

    # Calculate correlation
    correlation = calculate_correlation(activity_a, activity_b)

    spillover = %{
      spillover_detected: abs(correlation) > 0.3,
      correlation_score: correlation,
      # time_delay removed - cannot be implemented with current data structure
      pattern: determine_spillover_pattern(correlation)
    }

    {:ok, spillover}
  end

  @doc """
  Analyzes regional correlation patterns between systems.
  Can accept either a single region_id or a list of system_ids.
  """
  @spec analyze_regional_correlation(integer() | list(integer()), keyword()) ::
          {:ok, map()} | {:error, atom()}

  # Define the default once
  def analyze_regional_correlation(region_or_systems, opts \\ [])

  # Handle single region_id
  def analyze_regional_correlation(region_id, opts) when is_integer(region_id) do
    # Query all systems in the region from the solar system table
    system_query =
      EveDmv.Eve.SolarSystem
      |> Ash.Query.new()
      |> Ash.Query.filter(region_id == ^region_id)
      |> Ash.Query.select([:system_id])

    system_ids =
      case Ash.read(system_query, domain: EveDmv.Api) do
        {:ok, systems} -> Enum.map(systems, & &1.system_id)
        {:error, _} -> []
      end

    # If no systems found in region, return error
    if Enum.empty?(system_ids) do
      {:error, :no_systems_in_region}
    else
      # Default 7 days
      hours = Keyword.get(opts, :hours, 168)
      cutoff_date = DateTime.utc_now() |> DateTime.add(-hours, :hour)

      # Get killmails for the timeframe
      query =
        KillmailRaw
        |> Ash.Query.new()
        |> Ash.Query.filter(killmail_time >= ^cutoff_date)
        |> Ash.Query.filter(solar_system_id in ^system_ids)

      case Ash.read(query, domain: EveDmv.Api) do
        {:ok, killmails} ->
          correlation_data = calculate_system_correlations(system_ids, killmails)
          # Add region_id to response for tests
          {:ok, Map.put(correlation_data, :region_id, region_id)}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  # Handle list of system_ids
  def analyze_regional_correlation(system_ids, opts) when is_list(system_ids) do
    # Default 7 days
    hours = Keyword.get(opts, :hours, 168)
    cutoff_date = DateTime.utc_now() |> DateTime.add(-hours, :hour)

    # Get killmails for the timeframe
    query =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.filter(killmail_time >= ^cutoff_date)
      |> Ash.Query.filter(solar_system_id in ^system_ids)

    case Ash.read(query, domain: EveDmv.Api) do
      {:ok, killmails} ->
        correlation_data = calculate_system_correlations(system_ids, killmails)
        {:ok, correlation_data}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Identifies hot zones based on activity levels.
  """
  @spec identify_hot_zones(keyword()) :: {:ok, map()} | {:error, atom()}
  def identify_hot_zones(opts \\ []) do
    hours = Keyword.get(opts, :hours, 24)
    cutoff_date = DateTime.utc_now() |> DateTime.add(-hours, :hour)

    # Query all recent killmails grouped by system
    query =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.filter(killmail_time >= ^cutoff_date)

    case Ash.read(query, domain: EveDmv.Api) do
      {:ok, killmails} ->
        system_activity = group_by_system(killmails)
        hot_zones = identify_high_activity_systems(system_activity)

        zones = %{
          hot_zones: hot_zones,
          rankings: sort_systems_by_activity(system_activity)
        }

        {:ok, zones}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Detects threat escalations in systems based on activity spikes.
  """
  @spec detect_escalations(keyword()) :: {:ok, list(map())} | {:error, atom()}
  def detect_escalations(opts \\ []) do
    # Look at last 6 hours
    hours = Keyword.get(opts, :hours, 6)
    # Compare to 24h baseline
    baseline_hours = Keyword.get(opts, :baseline_hours, 24)

    current_cutoff = DateTime.utc_now() |> DateTime.add(-hours, :hour)
    baseline_cutoff = DateTime.utc_now() |> DateTime.add(-baseline_hours, :hour)

    # Get current period activity
    current_query =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.filter(killmail_time >= ^current_cutoff)

    # Get baseline activity for comparison
    baseline_query =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.filter(killmail_time >= ^baseline_cutoff)
      |> Ash.Query.filter(killmail_time < ^current_cutoff)

    case {Ash.read(current_query, domain: EveDmv.Api),
          Ash.read(baseline_query, domain: EveDmv.Api)} do
      {{:ok, current_kills}, {:ok, baseline_kills}} ->
        escalations =
          analyze_escalation_patterns(current_kills, baseline_kills, hours, baseline_hours)

        {:ok, escalations}

      {{:error, error}, _} ->
        {:error, error}

      {_, {:error, error}} ->
        {:error, error}
    end
  end

  @doc """
  Gets current active escalation alerts.
  """
  @spec get_escalation_alerts(keyword()) :: list(map())
  def get_escalation_alerts(opts \\ []) do
    case detect_escalations(opts) do
      {:ok, escalations} ->
        escalations
        |> Enum.filter(fn escalation -> escalation.severity in [:medium, :high, :critical] end)
        |> Enum.sort_by(& &1.escalation_score, :desc)

      {:error, _} ->
        []
    end
  end

  # Private helper functions

  defp calculate_activity_level(kill_count, days) do
    daily_average = kill_count / days

    cond do
      daily_average >= @activity_high_threshold -> :very_high
      daily_average >= @activity_medium_threshold -> :high
      daily_average >= @activity_low_threshold -> :medium
      daily_average >= @activity_minimal_threshold -> :low
      true -> :very_low
    end
  end

  defp calculate_hourly_distribution(killmails) do
    killmails
    |> Enum.group_by(fn km -> km.killmail_time.hour end)
    |> Map.new(fn {hour, kms} -> {hour, length(kms)} end)
  end

  defp identify_peak_hours(killmails) do
    hourly_dist = calculate_hourly_distribution(killmails)

    if Enum.empty?(hourly_dist) do
      []
    else
      avg_activity = (Map.values(hourly_dist) |> Enum.sum()) / 24

      hourly_dist
      |> Enum.filter(fn {_hour, count} -> count > avg_activity * 1.5 end)
      |> Enum.map(fn {hour, _count} -> hour end)
      |> Enum.sort()
    end
  end

  defp calculate_activity_trend(killmails) when length(killmails) < 5 do
    :insufficient_data
  end

  defp calculate_activity_trend(killmails) do
    # Simple trend calculation based on recent vs older activity
    sorted_kills = Enum.sort_by(killmails, & &1.killmail_time, DateTime)
    midpoint = div(length(sorted_kills), 2)

    {older_half, newer_half} = Enum.split(sorted_kills, midpoint)

    older_count = length(older_half)
    newer_count = length(newer_half)

    cond do
      newer_count > older_count * 1.3 -> :increasing
      older_count > newer_count * 1.3 -> :decreasing
      true -> :stable
    end
  end

  defp get_system_activities(system_a, system_b, cutoff_date) do
    query_a =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.filter(solar_system_id == ^system_a)
      |> Ash.Query.filter(killmail_time >= ^cutoff_date)

    query_b =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.filter(solar_system_id == ^system_b)
      |> Ash.Query.filter(killmail_time >= ^cutoff_date)

    case {Ash.read(query_a, domain: EveDmv.Api), Ash.read(query_b, domain: EveDmv.Api)} do
      {{:ok, kills_a}, {:ok, kills_b}} ->
        {group_by_hour(kills_a), group_by_hour(kills_b)}

      _ ->
        {[], []}
    end
  end

  defp group_by_hour(killmails) do
    grouped =
      killmails
      |> Enum.group_by(fn km -> km.killmail_time.hour end)

    # Ensure hours are sorted in ascending order for proper correlation
    0..23
    |> Enum.map(fn hour ->
      Map.get(grouped, hour, []) |> length()
    end)
  end

  defp calculate_correlation([], []), do: 0.0
  defp calculate_correlation(activity_a, _activity_b) when length(activity_a) < 2, do: 0.0

  defp calculate_correlation(activity_a, activity_b) do
    # Simple Pearson correlation coefficient
    n = min(length(activity_a), length(activity_b))

    if n < 2 do
      0.0
    else
      a_vals = Enum.take(activity_a, n)
      b_vals = Enum.take(activity_b, n)

      mean_a = Enum.sum(a_vals) / n
      mean_b = Enum.sum(b_vals) / n

      numerator =
        Enum.zip(a_vals, b_vals)
        |> Enum.map(fn {a, b} -> (a - mean_a) * (b - mean_b) end)
        |> Enum.sum()

      sum_sq_a = Enum.map(a_vals, fn a -> (a - mean_a) * (a - mean_a) end) |> Enum.sum()
      sum_sq_b = Enum.map(b_vals, fn b -> (b - mean_b) * (b - mean_b) end) |> Enum.sum()

      denominator = :math.sqrt(sum_sq_a * sum_sq_b)

      if denominator == 0, do: 0.0, else: numerator / denominator
    end
  end

  # Function removed per CLAUDE.md: No stub implementations allowed
  # calculate_time_delay/2 removed - always returned 0

  defp determine_spillover_pattern(correlation)
       when correlation > @spillover_pattern_threshold_high,
       do: :immediate

  defp determine_spillover_pattern(correlation)
       when correlation > @spillover_pattern_threshold_medium,
       do: :delayed

  defp determine_spillover_pattern(correlation)
       when correlation < @spillover_pattern_threshold_negative,
       do: :bidirectional

  defp determine_spillover_pattern(_), do: :none

  defp group_by_system(killmails) do
    killmails
    |> Enum.group_by(& &1.solar_system_id)
    |> Map.new(fn {system_id, kms} ->
      total_value =
        Enum.reduce(kms, Decimal.new(0), fn km, acc ->
          value = km.total_value || Decimal.new(0)
          Decimal.add(acc, value)
        end)

      {system_id,
       %{
         system_id: system_id,
         kill_count: length(kms),
         isk_destroyed: total_value,
         # Activity scoring using configured multiplier
         activity_score: length(kms) * @activity_weight_multiplier
       }}
    end)
  end

  defp identify_high_activity_systems(system_activity) do
    system_activity
    |> Map.values()
    # Filter for hot zones using configured threshold
    |> Enum.filter(fn system -> system.kill_count >= @hot_zone_threshold end)
    |> Enum.sort_by(& &1.activity_score, :desc)
  end

  defp sort_systems_by_activity(system_activity) do
    system_activity
    |> Map.values()
    |> Enum.sort_by(& &1.activity_score, :desc)
  end

  defp generate_heatmap_from_killmails(killmails, opts) do
    # Group killmails by system and calculate threat levels
    system_activity = group_by_system(killmails)

    # Get all unique system IDs
    system_ids = Map.keys(system_activity)

    # Fetch system information from static data
    system_info_map = fetch_system_info(system_ids)

    # Convert to heatmap format with real coordinates and names
    systems =
      system_activity
      |> Map.values()
      |> Enum.map(fn system_data ->
        threat_level = calculate_threat_level(system_data)

        # Get system info from our fetched data
        sys_info = Map.get(system_info_map, system_data.system_id, %{})

        %{
          id: system_data.system_id,
          # Use real system name, fallback to ID if not found
          name: Map.get(sys_info, :system_name, "Unknown System #{system_data.system_id}"),
          threatLevel: threat_level,
          recentKills: system_data.kill_count,
          iskDestroyed: Decimal.to_float(system_data.isk_destroyed),
          # Use real coordinates, converting from Decimal to float
          # EVE uses very large coordinate values, normalize them for display
          mapX: normalize_coordinate(Map.get(sys_info, :x)),
          # Use Z for 2D map (Y is vertical in EVE)
          mapY: normalize_coordinate(Map.get(sys_info, :z))
        }
      end)
      |> Enum.take(Keyword.get(opts, :limit, 100))

    max_threat =
      if Enum.empty?(systems) do
        1.0
      else
        Enum.max_by(systems, & &1.threatLevel).threatLevel
      end

    %{
      systems: systems,
      # Add for test compatibility
      heatmap_data: systems,
      maxThreat: max_threat,
      generatedAt: DateTime.utc_now(),
      totalSystems: length(systems)
    }
  end

  defp calculate_threat_level(system_data) do
    # Normalize activity to 0-1 scale based on kill count and ISK value
    # Log scale using configured weights
    kill_factor = :math.log10(max(1, system_data.kill_count)) / @threat_weight_activity

    isk_factor =
      :math.log10(max(1, Decimal.to_float(system_data.isk_destroyed) / @isk_to_millions)) /
        @threat_weight_value

    # Combine factors using configured ratios and clamp to 0-1
    threat = kill_factor * @threat_ratio_activity + isk_factor * @threat_ratio_value
    max(0.0, min(1.0, threat))
  end

  defp calculate_system_correlations(system_ids, killmails) do
    # Group killmails by hour for time series analysis
    time_series_data = create_time_series_data(system_ids, killmails)

    # Calculate correlation matrix
    correlation_matrix = build_correlation_matrix(system_ids, time_series_data)

    # Create system info for display
    systems =
      Enum.map(system_ids, fn system_id ->
        %{
          id: system_id,
          # Fetch real system name from static data
          name: get_system_name(system_id)
        }
      end)

    %{
      systems: systems,
      matrix: correlation_matrix,
      # Add for test compatibility
      correlation_matrix: correlation_matrix,
      generated_at: DateTime.utc_now(),
      sample_size: length(killmails)
    }
  end

  defp create_time_series_data(system_ids, killmails) do
    # Create hourly buckets for the last 24 hours
    now = DateTime.utc_now()

    hours =
      for h <- 0..23 do
        DateTime.add(now, -h * 3600, :second)
        |> Map.put(:minute, 0)
        |> Map.put(:second, 0)
        |> Map.put(:microsecond, {0, 0})
      end

    # Initialize time series for each system
    time_series =
      Map.new(system_ids, fn system_id ->
        {system_id, Map.new(hours, fn hour -> {hour, 0} end)}
      end)

    # Fill in actual killmail counts by hour
    Enum.reduce(killmails, time_series, fn killmail, acc ->
      hour_bucket =
        killmail.killmail_time
        |> Map.put(:minute, 0)
        |> Map.put(:second, 0)
        |> Map.put(:microsecond, {0, 0})

      system_id = killmail.solar_system_id

      if Map.has_key?(acc, system_id) do
        update_in(acc, [system_id, hour_bucket], fn
          nil -> 1
          count -> count + 1
        end)
      else
        acc
      end
    end)
  end

  defp build_correlation_matrix(system_ids, time_series_data) do
    # Convert time series to value arrays
    system_arrays =
      Map.new(system_ids, fn system_id ->
        # Extract values in chronological order by iterating over sorted time keys
        time_data = Map.get(time_series_data, system_id, %{})

        values =
          if map_size(time_data) > 0 do
            # Get all time keys and sort them to maintain chronological order
            time_keys = Map.keys(time_data) |> Enum.sort()
            Enum.map(time_keys, fn key -> Map.get(time_data, key, 0) end)
          else
            []
          end

        {system_id, values}
      end)

    # Build NxN correlation matrix
    Enum.map(system_ids, fn system_a ->
      Enum.map(system_ids, fn system_b ->
        values_a = system_arrays[system_a]
        values_b = system_arrays[system_b]

        calculate_correlation(values_a, values_b)
      end)
    end)
  end

  defp analyze_escalation_patterns(current_kills, baseline_kills, current_hours, baseline_hours) do
    # Group current and baseline kills by system
    current_by_system = group_by_system(current_kills)
    baseline_by_system = group_by_system(baseline_kills)

    # Calculate escalation factors for each system
    all_systems = (Map.keys(current_by_system) ++ Map.keys(baseline_by_system)) |> Enum.uniq()

    Enum.map(all_systems, fn system_id ->
      current_activity =
        Map.get(current_by_system, system_id, %{kill_count: 0, isk_destroyed: Decimal.new(0)})

      baseline_activity =
        Map.get(baseline_by_system, system_id, %{kill_count: 0, isk_destroyed: Decimal.new(0)})

      # Normalize activity rates per hour
      current_rate = current_activity.kill_count / current_hours

      baseline_rate =
        if baseline_hours > 0, do: baseline_activity.kill_count / baseline_hours, else: 0

      # Calculate escalation factor
      escalation_factor =
        if baseline_rate > 0 do
          current_rate / baseline_rate
        else
          # High activity from zero baseline
          if current_rate > @escalation_kill_threshold,
            do: @escalation_activity_threshold,
            else: 1.0
        end

      # Calculate ISK escalation factor
      current_isk_rate = Decimal.to_float(current_activity.isk_destroyed) / current_hours

      baseline_isk_rate =
        if baseline_hours > 0,
          do: Decimal.to_float(baseline_activity.isk_destroyed) / baseline_hours,
          else: 0

      isk_escalation_factor =
        if baseline_isk_rate > 0 do
          current_isk_rate / baseline_isk_rate
        else
          # 50M+ ISK/hour threshold
          if current_isk_rate > @escalation_value_threshold,
            do: @escalation_isk_high_factor,
            else: 1.0
        end

      # Combined escalation score using configured weights
      escalation_score =
        escalation_factor * @escalation_weight_activity +
          isk_escalation_factor * @escalation_weight_value

      # Determine severity and type
      {severity, escalation_type} =
        classify_escalation(escalation_score, current_activity, baseline_activity)

      %{
        system_id: system_id,
        # Fetch real system name from static data
        system_name: get_system_name(system_id),
        severity: severity,
        escalation_type: escalation_type,
        escalation_score: Float.round(escalation_score, 2),
        kill_factor: Float.round(escalation_factor, 2),
        isk_factor: Float.round(isk_escalation_factor, 2),
        current_kills: current_activity.kill_count,
        baseline_kills: baseline_activity.kill_count,
        current_isk: current_activity.isk_destroyed,
        detected_at: DateTime.utc_now(),
        description:
          generate_escalation_description(
            escalation_factor,
            isk_escalation_factor,
            current_activity
          )
      }
    end)
    # Filter for significant escalations
    |> Enum.filter(fn escalation ->
      escalation.escalation_score >= @spillover_filter_threshold
    end)
    |> Enum.sort_by(& &1.escalation_score, :desc)
  end

  defp classify_escalation(score, current_activity, _baseline_activity) do
    severity =
      cond do
        score >= @severity_high_threshold -> :critical
        score >= @severity_medium_threshold -> :high
        score >= @severity_low_threshold -> :medium
        score >= @severity_minimal_threshold -> :low
        true -> :none
      end

    # Determine escalation type based on activity patterns
    escalation_type =
      cond do
        current_activity.kill_count >= @activity_spike_threshold ->
          :massive_engagement

        current_activity.kill_count >= @activity_increase_threshold ->
          :fleet_battle

        current_activity.kill_count >= @activity_decrease_threshold ->
          :skirmish

        Decimal.to_float(current_activity.isk_destroyed) >= @isk_high_threshold ->
          :capital_engagement

        Decimal.to_float(current_activity.isk_destroyed) >= @isk_medium_threshold ->
          :expensive_battle

        true ->
          :activity_spike
      end

    {severity, escalation_type}
  end

  defp generate_escalation_description(kill_factor, isk_factor, current_activity) do
    cond do
      kill_factor >= @escalation_isk_high_factor and isk_factor >= @severity_medium_threshold ->
        "Major fleet engagement - #{current_activity.kill_count} kills, #{format_isk_simple(current_activity.isk_destroyed)} destroyed"

      kill_factor >= @severity_medium_threshold ->
        "Significant activity spike - #{current_activity.kill_count}x normal kill rate"

      isk_factor >= @escalation_isk_high_factor ->
        "High-value targets engaged - #{Float.round(isk_factor, 1)}x normal ISK destruction"

      current_activity.kill_count >= @activity_medium_threshold ->
        "Large battle detected - #{current_activity.kill_count} ships destroyed"

      true ->
        "Activity escalation - #{current_activity.kill_count} kills in recent period"
    end
  end

  defp format_isk_simple(decimal_value) do
    isk_value = Decimal.to_float(decimal_value)

    cond do
      isk_value >= 1_000_000_000_000 -> "#{Float.round(isk_value / 1_000_000_000_000, 1)}T ISK"
      isk_value >= 1_000_000_000 -> "#{Float.round(isk_value / 1_000_000_000, 1)}B ISK"
      isk_value >= 1_000_000 -> "#{Float.round(isk_value / 1_000_000, 1)}M ISK"
      true -> "#{Float.round(isk_value / 1_000, 1)}K ISK"
    end
  end

  # Helper functions for fetching real system data
  defp fetch_system_info([]), do: %{}

  defp fetch_system_info(system_ids) do
    query =
      EveDmv.Eve.SolarSystem
      |> Ash.Query.new()
      |> Ash.Query.filter(system_id: [in: system_ids])
      |> Ash.Query.select([:system_id, :system_name, :x, :y, :z])

    case Ash.read(query, domain: EveDmv.Api) do
      {:ok, systems} ->
        Map.new(systems, fn sys ->
          {sys.system_id,
           %{
             system_name: sys.system_name,
             x: sys.x,
             y: sys.y,
             z: sys.z
           }}
        end)

      {:error, _} ->
        %{}
    end
  end

  defp get_system_name(system_id) do
    query =
      EveDmv.Eve.SolarSystem
      |> Ash.Query.new()
      |> Ash.Query.filter(system_id == ^system_id)
      |> Ash.Query.select([:system_name])
      |> Ash.Query.limit(1)

    case Ash.read_one(query, domain: EveDmv.Api) do
      {:ok, %{system_name: name}} when not is_nil(name) -> name
      _ -> "System #{system_id}"
    end
  end

  defp normalize_coordinate(nil), do: 0.0

  defp normalize_coordinate(coord) when is_binary(coord) do
    # Handle string coordinates (shouldn't happen but safe fallback)
    normalize_coordinate(Decimal.new(coord))
  end

  defp normalize_coordinate(%Decimal{} = coord) do
    # EVE coordinates are in meters and very large
    # Normalize to a 0-1 range for display purposes
    # EVE universe is roughly -5e17 to 5e17 meters
    float_val = Decimal.to_float(coord)
    # Scale down and center using configured constants
    (float_val / @coordinate_scale + @coordinate_offset) |> max(0.0) |> min(1.0)
  end

  defp normalize_coordinate(coord) when is_number(coord) do
    # Already a number, normalize it using configured constants
    (coord / @coordinate_scale + @coordinate_offset) |> max(0.0) |> min(1.0)
  end
end
