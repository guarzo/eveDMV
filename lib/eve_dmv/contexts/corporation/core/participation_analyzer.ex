defmodule EveDmv.Contexts.Corporation.Core.ParticipationAnalyzer do
  @moduledoc """
  Analyzes member participation in corporation activities including fleet ops,
  timezone coverage, and participation trends.

  Consolidates functionality from:
  - Corporation Analysis participation analyzer
  - Corporation Intelligence participation tracking
  """

  alias EveDmv.Database.CharacterRepository
  alias EveDmv.Platform.Cache.Corporation.CorporationCache
  alias EveDmv.Platform.Database.CorporationRepository

  require Logger

  @cache_ttl :timer.hours(3)

  @doc """
  Analyze participation patterns for a corporation.

  Options:
    - time_range: Analysis period (default: last 60 days)
    - include_trends: Include participation trend analysis
    - include_timezone: Include detailed timezone analysis
  """
  def analyze_participation(corporation_id, opts \\ []) do
    cache_key = {:participation_analysis, corporation_id, opts}

    case CorporationCache.get(cache_key) do
      nil ->
        result = perform_participation_analysis(corporation_id, opts)

        if match?({:ok, _}, result) do
          {:ok, analysis} = result
          CorporationCache.put(cache_key, analysis, ttl: @cache_ttl)
        end

        result

      cached_result ->
        {:ok, cached_result}
    end
  end

  @doc """
  Get fleet participation rates.
  """
  def get_fleet_participation_rates(corporation_id) do
    case analyze_participation(corporation_id) do
      {:ok, analysis} -> {:ok, analysis.fleet_participation}
      error -> error
    end
  end

  @doc """
  Analyze timezone coverage.
  """
  def analyze_timezone_coverage(corporation_id) do
    case analyze_participation(corporation_id) do
      {:ok, analysis} -> {:ok, analysis.timezone_coverage}
      error -> error
    end
  end

  @doc """
  Get participation trends over time.
  """
  def get_participation_trends(corporation_id, time_period) do
    with {:ok, historical_data} <- get_historical_participation_data(corporation_id, time_period) do
      trends = %{
        overall_trend: calculate_overall_participation_trend(historical_data),
        fleet_participation_trend: calculate_fleet_trend(historical_data),
        timezone_shift_trends: analyze_timezone_shifts(historical_data),
        seasonal_patterns: identify_seasonal_patterns(historical_data)
      }

      {:ok, trends}
    end
  end

  # Private Functions

  defp perform_participation_analysis(corporation_id, opts) do
    Logger.info("Analyzing participation for corporation #{corporation_id}")

    time_range = Keyword.get(opts, :time_range, days: 60)

    with {:ok, members} <- CorporationRepository.get_corporation_members(corporation_id),
         {:ok, participation_data} <- gather_participation_data(members, time_range),
         {:ok, fleet_data} <- analyze_fleet_participation(participation_data),
         {:ok, timezone_data} <- analyze_timezone_participation(participation_data) do
      base_analysis = %{
        corporation_id: corporation_id,
        analysis_period: time_range,
        total_members: length(members),
        participation_summary: build_participation_summary(participation_data),
        fleet_participation: fleet_data,
        timezone_coverage: timezone_data,
        member_participation_profiles: build_member_profiles(participation_data),
        participation_distribution: analyze_participation_distribution(participation_data),
        engagement_quality: assess_engagement_quality(participation_data),
        recommendations:
          generate_participation_recommendations(participation_data, fleet_data, timezone_data),
        analyzed_at: DateTime.utc_now()
      }

      analysis_with_trends =
        if Keyword.get(opts, :include_trends, false) do
          trends = analyze_participation_trends(corporation_id, participation_data)
          Map.put(base_analysis, :trends, trends)
        else
          base_analysis
        end

      final_analysis =
        if Keyword.get(opts, :include_timezone, false) do
          detailed_timezone = perform_detailed_timezone_analysis(participation_data)
          Map.put(analysis_with_trends, :detailed_timezone_analysis, detailed_timezone)
        else
          analysis_with_trends
        end

      {:ok, final_analysis}
    end
  end

  defp gather_participation_data(members, time_range) do
    start_date = calculate_start_date(time_range)

    # Gather participation data for all members
    participation_data =
      members
      |> Task.async_stream(
        fn member ->
          {member.character_id, collect_member_participation(member, start_date)}
        end,
        max_concurrency: 20,
        timeout: 15_000
      )
      |> Enum.reduce(%{}, fn
        {:ok, {char_id, {:ok, participation}}}, acc ->
          Map.put(acc, char_id, participation)

        {:ok, {char_id, {:error, reason}}}, acc ->
          Logger.warning(
            "Failed to get participation for character #{char_id}: #{inspect(reason)}"
          )

          Map.put(acc, char_id, %{active: false, error: reason})

        {:exit, reason}, acc ->
          Logger.error("Participation collection task failed: #{inspect(reason)}")
          acc
      end)

    {:ok, participation_data}
  end

  defp calculate_start_date(days: days) do
    DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)
  end

  defp collect_member_participation(member, start_date) do
    with {:ok, killmails} <-
           CharacterRepository.get_character_killmails_since(member.character_id, start_date) do
      participation = %{
        character_id: member.character_id,
        character_name: member.character_name,
        join_date: member.join_date,
        last_seen: member.last_seen,

        # Activity metrics
        total_activities: length(killmails),
        fleet_activities: count_fleet_activities(killmails),
        solo_activities: count_solo_activities(killmails),
        small_gang_activities: count_small_gang_activities(killmails),

        # Temporal patterns
        activity_by_hour: analyze_hourly_activity(killmails),
        activity_by_day: analyze_daily_activity(killmails),
        activity_by_week: analyze_weekly_activity(killmails, start_date),

        # Participation quality
        participation_consistency: calculate_participation_consistency(killmails, start_date),
        engagement_depth: assess_engagement_depth(killmails),
        leadership_indicators: detect_leadership_participation(killmails, member.character_id),

        # Fleet-specific metrics
        avg_fleet_size: calculate_avg_fleet_size(killmails),
        fleet_roles: identify_fleet_roles(killmails, member.character_id),
        fleet_effectiveness: assess_fleet_effectiveness(killmails, member.character_id),

        # Geographic patterns
        operational_systems: identify_operational_systems(killmails),
        regional_focus: analyze_regional_focus(killmails)
      }

      {:ok, participation}
    end
  end

  defp count_fleet_activities(killmails) do
    Enum.count(killmails, fn km -> length(km.attackers) >= 10 end)
  end

  defp count_solo_activities(killmails) do
    Enum.count(killmails, fn km -> length(km.attackers) == 1 end)
  end

  defp count_small_gang_activities(killmails) do
    Enum.count(killmails, fn km ->
      attacker_count = length(km.attackers)
      attacker_count > 1 and attacker_count < 10
    end)
  end

  defp analyze_hourly_activity(killmails) do
    killmails
    |> Enum.map(fn km -> DateTime.to_time(km.killmail_time).hour end)
    |> Enum.frequencies()
  end

  defp analyze_daily_activity(killmails) do
    killmails
    |> Enum.map(fn km -> Date.day_of_week(DateTime.to_date(km.killmail_time)) end)
    |> Enum.frequencies()
  end

  defp analyze_weekly_activity(killmails, _start_date) do
    # Group activities by week
    killmails
    |> Enum.group_by(fn km ->
      date = DateTime.to_date(km.killmail_time)
      # Use ISO week numbering
      {date.year, Date.to_iso8601(date) |> String.slice(5, 2) |> String.to_integer()}
    end)
    |> Enum.map(fn {week, kms} -> {week, length(kms)} end)
    |> Map.new()
  end

  defp calculate_participation_consistency(killmails, start_date) do
    if length(killmails) < 3 do
      0.0
    else
      # Calculate activity distribution across time period
      _total_days = DateTime.diff(DateTime.utc_now(), start_date, :day)

      daily_activity =
        killmails
        |> Enum.group_by(fn km -> DateTime.to_date(km.killmail_time) end)
        |> Map.values()
        |> Enum.map(&length/1)

      # Calculate coefficient of variation
      if length(daily_activity) > 1 do
        mean = Enum.sum(daily_activity) / length(daily_activity)

        variance =
          daily_activity
          |> Enum.map(fn count -> :math.pow(count - mean, 2) end)
          |> Enum.sum()
          |> Kernel./(length(daily_activity))

        cv = if mean > 0, do: :math.sqrt(variance) / mean, else: 1
        consistency = max(0, 100 * (1 - cv))

        Float.round(consistency, 1)
      else
        0.0
      end
    end
  end

  defp assess_engagement_depth(killmails) do
    if Enum.empty?(killmails) do
      %{depth_score: 0, assessment: :no_activity}
    else
      # Analyze variety and commitment indicators
      system_diversity =
        killmails
        |> Enum.map(& &1.solar_system_id)
        |> Enum.uniq()
        |> length()

      ship_diversity =
        killmails
        |> Enum.flat_map(fn km ->
          # Get all ships used by character (as victim or attacker)
          ships =
            if km.victim.character_id do
              [km.victim.ship_type_id]
            else
              []
            end

          attacker_ships =
            km.attackers
            |> Enum.map(& &1.ship_type_id)

          ships ++ attacker_ships
        end)
        |> Enum.uniq()
        |> length()

      # Time span of activities
      sorted_kms = Enum.sort_by(killmails, & &1.killmail_time)

      time_span =
        if length(sorted_kms) > 1 do
          DateTime.diff(
            List.last(sorted_kms).killmail_time,
            List.first(sorted_kms).killmail_time,
            :day
          )
        else
          0
        end

      # Calculate depth score
      # Max 5 points
      activity_volume = min(length(killmails) / 10, 5)
      # Max 3 points
      diversity_score = min((system_diversity + ship_diversity) / 4, 3)
      # Max 2 points
      commitment_score = min(time_span / 10, 2)

      total_score = activity_volume + diversity_score + commitment_score

      %{
        depth_score: Float.round(total_score, 1),
        system_diversity: system_diversity,
        ship_diversity: ship_diversity,
        time_span_days: time_span,
        assessment: categorize_engagement_depth(total_score)
      }
    end
  end

  defp categorize_engagement_depth(score) do
    cond do
      score >= 8 -> :deeply_engaged
      score >= 6 -> :well_engaged
      score >= 4 -> :moderately_engaged
      score >= 2 -> :lightly_engaged
      true -> :minimal_engagement
    end
  end

  defp detect_leadership_participation(killmails, character_id) do
    # Look for indicators of fleet leadership
    fleet_activities = Enum.filter(killmails, fn km -> length(km.attackers) >= 5 end)

    if Enum.empty?(fleet_activities) do
      %{leadership_score: 0, indicators: []}
    else
      indicators = []

      # Check if often first on killmails (FC indicator)
      first_attacker_count =
        Enum.count(fleet_activities, fn km ->
          case List.first(km.attackers) do
            nil -> false
            first -> first.character_id == character_id
          end
        end)

      indicators =
        if first_attacker_count > length(fleet_activities) * 0.3 do
          ["Often first on killmails (possible FC)" | indicators]
        else
          indicators
        end

      # Check for command ship usage (would need ship data)
      # This is simplified - would need actual ship type analysis

      # Consistent large fleet participation
      indicators =
        if length(fleet_activities) > 10 do
          ["High fleet participation rate" | indicators]
        else
          indicators
        end

      leadership_score = first_attacker_count / max(length(fleet_activities), 1) * 100

      %{
        leadership_score: Float.round(leadership_score, 1),
        indicators: indicators,
        fleet_activities: length(fleet_activities)
      }
    end
  end

  defp calculate_avg_fleet_size(killmails) do
    fleet_sizes =
      killmails
      |> Enum.map(fn km -> length(km.attackers) end)

    if Enum.empty?(fleet_sizes) do
      0
    else
      Enum.sum(fleet_sizes) / length(fleet_sizes)
    end
  end

  defp identify_fleet_roles(killmails, character_id) do
    # Analyze ship types used in fleets to identify roles
    fleet_ships =
      killmails
      |> Enum.filter(fn km -> length(km.attackers) >= 5 end)
      |> Enum.flat_map(fn km ->
        # Find character's ship in this killmail
        if km.victim.character_id == character_id do
          [km.victim.ship_type_id]
        else
          case Enum.find(km.attackers, fn att -> att.character_id == character_id end) do
            nil -> []
            attacker -> [attacker.ship_type_id]
          end
        end
      end)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_ship, count} -> count end, :desc)
      |> Enum.take(5)

    # Categorize ships by role (simplified)
    roles =
      fleet_ships
      |> Enum.map(fn {ship_type_id, count} ->
        role = categorize_ship_role(ship_type_id)
        {role, count}
      end)
      |> Enum.reduce(%{}, fn {role, count}, acc ->
        Map.update(acc, role, count, &(&1 + count))
      end)

    roles
  end

  defp categorize_ship_role(ship_type_id) do
    # Use proper ship role detection from static data
    alias EveDmv.StaticData.ShipRoles

    cond do
      ShipRoles.is_logistics_ship?(ship_type_id) -> :logistics
      ShipRoles.is_ewar_ship?(ship_type_id) -> :support
      ShipRoles.is_command_ship?(ship_type_id) -> :support
      # Default to DPS for combat ships
      true -> :dps
    end
  end

  defp assess_fleet_effectiveness(killmails, character_id) do
    fleet_kms = Enum.filter(killmails, fn km -> length(km.attackers) >= 5 end)

    if Enum.empty?(fleet_kms) do
      %{effectiveness_score: 0, assessment: :no_fleet_activity}
    else
      # Calculate fleet win/loss ratio
      fleet_kills = Enum.count(fleet_kms, fn km -> km.victim.character_id != character_id end)
      fleet_losses = Enum.count(fleet_kms, fn km -> km.victim.character_id == character_id end)

      effectiveness =
        if fleet_kills + fleet_losses > 0 do
          fleet_kills / (fleet_kills + fleet_losses) * 100
        else
          0
        end

      %{
        effectiveness_score: Float.round(effectiveness, 1),
        fleet_kills: fleet_kills,
        fleet_losses: fleet_losses,
        assessment: categorize_fleet_effectiveness(effectiveness)
      }
    end
  end

  defp categorize_fleet_effectiveness(score) do
    cond do
      score >= 80 -> :highly_effective
      score >= 60 -> :effective
      score >= 40 -> :moderately_effective
      score >= 20 -> :ineffective
      true -> :poor_effectiveness
    end
  end

  defp identify_operational_systems(killmails) do
    killmails
    |> Enum.map(& &1.solar_system_id)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_system, count} -> count end, :desc)
    |> Enum.take(10)
  end

  defp analyze_regional_focus(killmails) do
    # Would need system-to-region mapping
    # Simplified implementation
    systems = killmails |> Enum.map(& &1.solar_system_id) |> Enum.uniq()

    %{
      systems_operated_in: length(systems),
      geographic_spread: categorize_geographic_spread(length(systems)),
      primary_systems: Enum.take(systems, 5)
    }
  end

  defp categorize_geographic_spread(system_count) do
    cond do
      system_count >= 50 -> :nomadic
      system_count >= 20 -> :wide_ranging
      system_count >= 10 -> :regional
      system_count >= 5 -> :local
      true -> :very_local
    end
  end

  defp analyze_fleet_participation(participation_data) do
    all_members = Map.values(participation_data)

    fleet_stats = %{
      members_with_fleet_activity: count_members_with_fleet_activity(all_members),
      total_fleet_activities: sum_fleet_activities(all_members),
      avg_fleet_participation_rate: calculate_avg_fleet_participation(all_members),
      fleet_size_distribution: analyze_fleet_size_distribution(all_members),
      fleet_leadership_depth: analyze_leadership_depth(all_members),
      fleet_effectiveness: calculate_overall_fleet_effectiveness(all_members)
    }

    {:ok, fleet_stats}
  end

  defp count_members_with_fleet_activity(members) do
    Enum.count(members, fn member -> member.fleet_activities > 0 end)
  end

  defp sum_fleet_activities(members) do
    Enum.sum(Enum.map(members, & &1.fleet_activities))
  end

  defp calculate_avg_fleet_participation(members) do
    active_members = Enum.filter(members, fn member -> member.total_activities > 0 end)

    if Enum.empty?(active_members) do
      0.0
    else
      fleet_rates =
        Enum.map(active_members, fn member ->
          if member.total_activities > 0 do
            member.fleet_activities / member.total_activities
          else
            0
          end
        end)

      Enum.sum(fleet_rates) / length(fleet_rates) * 100
    end
  end

  defp analyze_fleet_size_distribution(members) do
    all_fleet_sizes =
      members
      |> Enum.flat_map(fn member ->
        # This would need actual fleet size data from killmails
        # Simplified approximation
        List.duplicate(round(member.avg_fleet_size), member.fleet_activities)
      end)

    if Enum.empty?(all_fleet_sizes) do
      %{}
    else
      all_fleet_sizes
      |> Enum.map(fn size ->
        cond do
          size >= 50 -> "large_fleet"
          size >= 20 -> "medium_fleet"
          size >= 10 -> "small_fleet"
          size >= 5 -> "gang"
          true -> "micro"
        end
      end)
      |> Enum.frequencies()
    end
  end

  defp analyze_leadership_depth(members) do
    leaders =
      Enum.filter(members, fn member ->
        member.leadership_indicators.leadership_score > 30
      end)

    %{
      potential_leaders: length(leaders),
      leadership_ratio: length(leaders) / max(length(members), 1),
      avg_leadership_score:
        if Enum.empty?(leaders) do
          0
        else
          leaders
          |> Enum.map(& &1.leadership_indicators.leadership_score)
          |> Enum.sum()
          |> Kernel./(length(leaders))
        end
    }
  end

  defp calculate_overall_fleet_effectiveness(members) do
    fleet_members = Enum.filter(members, fn member -> member.fleet_activities > 0 end)

    if Enum.empty?(fleet_members) do
      %{score: 0, assessment: :no_fleet_activity}
    else
      effectiveness_scores = Enum.map(fleet_members, & &1.fleet_effectiveness.effectiveness_score)
      avg_effectiveness = Enum.sum(effectiveness_scores) / length(effectiveness_scores)

      %{
        score: Float.round(avg_effectiveness, 1),
        assessment: categorize_fleet_effectiveness(avg_effectiveness),
        active_fleet_members: length(fleet_members)
      }
    end
  end

  defp analyze_timezone_participation(participation_data) do
    all_members = Map.values(participation_data)

    # Aggregate hourly activity across all members
    hourly_activity =
      all_members
      |> Enum.reduce(%{}, fn member, acc ->
        Enum.reduce(member.activity_by_hour, acc, fn {hour, count}, inner_acc ->
          Map.update(inner_acc, hour, count, &(&1 + count))
        end)
      end)

    timezone_coverage = %{
      hourly_distribution: hourly_activity,
      peak_hours: identify_peak_hours(hourly_activity),
      coverage_gaps: identify_coverage_gaps(hourly_activity),
      timezone_strength: assess_timezone_strength(hourly_activity),
      estimated_primary_timezone: estimate_primary_timezone(hourly_activity),
      coverage_quality: assess_coverage_quality(hourly_activity)
    }

    {:ok, timezone_coverage}
  end

  defp identify_peak_hours(hourly_activity) do
    hourly_activity
    |> Enum.sort_by(fn {_hour, count} -> count end, :desc)
    |> Enum.take(6)
    |> Enum.map(fn {hour, count} -> %{hour: hour, activity_count: count} end)
  end

  defp identify_coverage_gaps(hourly_activity) do
    # Find hours with very low activity
    total_activity = hourly_activity |> Map.values() |> Enum.sum()

    if total_activity == 0 do
      []
    else
      avg_activity = total_activity / 24

      hourly_activity
      |> Enum.filter(fn {_hour, count} -> count < avg_activity * 0.3 end)
      |> Enum.map(fn {hour, count} -> %{hour: hour, activity_count: count} end)
      |> Enum.sort_by(& &1.hour)
    end
  end

  defp assess_timezone_strength(hourly_activity) do
    if map_size(hourly_activity) == 0 do
      :no_data
    else
      # Calculate activity distribution
      values = Map.values(hourly_activity)
      max_activity = Enum.max(values)
      min_activity = Enum.min(values)

      # Strong timezone coverage has more even distribution
      ratio = if max_activity > 0, do: min_activity / max_activity, else: 0

      cond do
        ratio > 0.7 -> :excellent_coverage
        ratio > 0.5 -> :good_coverage
        ratio > 0.3 -> :moderate_coverage
        ratio > 0.1 -> :poor_coverage
        true -> :very_poor_coverage
      end
    end
  end

  defp estimate_primary_timezone(hourly_activity) do
    if map_size(hourly_activity) == 0 do
      "Unknown"
    else
      # Find 4-hour window with highest activity
      peak_windows =
        for start_hour <- 0..23 do
          hours = Enum.map(0..3, fn offset -> rem(start_hour + offset, 24) end)

          activity =
            hours
            |> Enum.map(fn h -> Map.get(hourly_activity, h, 0) end)
            |> Enum.sum()

          {start_hour, activity}
        end

      {peak_start, _} = Enum.max_by(peak_windows, fn {_, activity} -> activity end)

      # Estimate timezone based on peak activity window
      estimate_timezone_from_peak(peak_start)
    end
  end

  defp estimate_timezone_from_peak(peak_hour) do
    # Assume peak activity is around 19:00-23:00 local time
    # 21:00 UTC as baseline
    offset = peak_hour - 21

    cond do
      offset >= -2 and offset <= 2 -> "EU-TZ"
      offset >= -7 and offset <= -4 -> "US-TZ"
      offset >= 6 and offset <= 10 -> "AU-TZ"
      true -> "Mixed/Other"
    end
  end

  defp assess_coverage_quality(hourly_activity) do
    if map_size(hourly_activity) == 0 do
      %{score: 0, assessment: :no_data}
    else
      # Calculate coverage score based on how many hours have decent activity
      total_activity = hourly_activity |> Map.values() |> Enum.sum()

      if total_activity == 0 do
        %{score: 0, assessment: :no_activity}
      else
        avg_activity = total_activity / 24
        # 50% of average is "decent"
        threshold = avg_activity * 0.5

        covered_hours =
          hourly_activity
          |> Enum.count(fn {_hour, count} -> count >= threshold end)

        coverage_score = covered_hours / 24 * 100

        %{
          score: Float.round(coverage_score, 1),
          covered_hours: covered_hours,
          assessment: categorize_coverage_quality(coverage_score)
        }
      end
    end
  end

  defp categorize_coverage_quality(score) do
    cond do
      score >= 80 -> :excellent
      score >= 60 -> :good
      score >= 40 -> :moderate
      score >= 20 -> :poor
      true -> :very_poor
    end
  end

  defp build_participation_summary(participation_data) do
    all_members = Map.values(participation_data)
    active_members = Enum.filter(all_members, fn m -> m.total_activities > 0 end)

    %{
      total_members: length(all_members),
      active_members: length(active_members),
      participation_rate:
        if length(all_members) > 0 do
          length(active_members) / length(all_members) * 100
        else
          0
        end,
      total_activities: Enum.sum(Enum.map(all_members, & &1.total_activities)),
      avg_activities_per_member:
        if length(active_members) > 0 do
          Enum.sum(Enum.map(active_members, & &1.total_activities)) / length(active_members)
        else
          0
        end,
      fleet_participation_rate:
        if length(active_members) > 0 do
          members_with_fleets = Enum.count(active_members, fn m -> m.fleet_activities > 0 end)
          members_with_fleets / length(active_members) * 100
        else
          0
        end
    }
  end

  defp build_member_profiles(participation_data) do
    participation_data
    |> Enum.map(fn {char_id, data} ->
      Map.put(data, :character_id, char_id)
    end)
    |> Enum.sort_by(& &1.total_activities, :desc)
    # Top 50 most active for performance
    |> Enum.take(50)
  end

  defp analyze_participation_distribution(participation_data) do
    activity_counts =
      participation_data
      |> Map.values()
      |> Enum.map(& &1.total_activities)

    %{
      distribution: %{
        "0": Enum.count(activity_counts, &(&1 == 0)),
        "1-5": Enum.count(activity_counts, &(&1 >= 1 and &1 <= 5)),
        "6-15": Enum.count(activity_counts, &(&1 >= 6 and &1 <= 15)),
        "16-30": Enum.count(activity_counts, &(&1 >= 16 and &1 <= 30)),
        "31+": Enum.count(activity_counts, &(&1 >= 31))
      },
      statistics: calculate_participation_statistics(activity_counts)
    }
  end

  defp calculate_participation_statistics(activity_counts) do
    if Enum.empty?(activity_counts) do
      %{mean: 0, median: 0, std_dev: 0}
    else
      mean = Enum.sum(activity_counts) / length(activity_counts)
      sorted = Enum.sort(activity_counts)
      median = calculate_median(sorted)
      std_dev = calculate_std_deviation(activity_counts, mean)

      %{
        mean: Float.round(mean, 1),
        median: median,
        std_dev: Float.round(std_dev, 1)
      }
    end
  end

  defp calculate_median(sorted_values) do
    len = length(sorted_values)

    if rem(len, 2) == 0 do
      (Enum.at(sorted_values, div(len, 2) - 1) + Enum.at(sorted_values, div(len, 2))) / 2
    else
      Enum.at(sorted_values, div(len, 2))
    end
  end

  defp calculate_std_deviation(values, mean) do
    variance =
      values
      |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(length(values))

    :math.sqrt(variance)
  end

  defp assess_engagement_quality(participation_data) do
    all_members = Map.values(participation_data)

    engaged_members =
      Enum.filter(all_members, fn m ->
        m.engagement_depth.assessment in [:deeply_engaged, :well_engaged, :moderately_engaged]
      end)

    %{
      highly_engaged_members:
        Enum.count(all_members, fn m ->
          m.engagement_depth.assessment in [:deeply_engaged, :well_engaged]
        end),
      engagement_rate:
        if length(all_members) > 0 do
          length(engaged_members) / length(all_members) * 100
        else
          0
        end,
      avg_engagement_depth:
        if length(all_members) > 0 do
          all_members
          |> Enum.map(& &1.engagement_depth.depth_score)
          |> Enum.sum()
          |> Kernel./(length(all_members))
        else
          0
        end
    }
  end

  defp generate_participation_recommendations(participation_data, fleet_data, timezone_data) do
    summary = build_participation_summary(participation_data)

    []
    |> maybe_add_participation_recommendation(summary.participation_rate)
    |> maybe_add_fleet_recommendation(fleet_data.avg_fleet_participation_rate)
    |> maybe_add_timezone_recommendation(timezone_data)
    |> maybe_add_leadership_recommendation(fleet_data.fleet_leadership_depth.potential_leaders)
    |> finalize_participation_recommendations()
  end

  defp maybe_add_participation_recommendation(recommendations, participation_rate)
       when participation_rate < 50 do
    [
      "Increase member engagement - only #{Float.round(participation_rate, 1)}% participation rate"
      | recommendations
    ]
  end

  defp maybe_add_participation_recommendation(recommendations, _participation_rate),
    do: recommendations

  defp maybe_add_fleet_recommendation(recommendations, fleet_participation_rate)
       when fleet_participation_rate < 30 do
    [
      "Organize more fleet operations - low fleet participation (#{Float.round(fleet_participation_rate, 1)}%)"
      | recommendations
    ]
  end

  defp maybe_add_fleet_recommendation(recommendations, _fleet_participation_rate),
    do: recommendations

  defp maybe_add_timezone_recommendation(recommendations, timezone_data) do
    case timezone_data.timezone_strength do
      strength when strength in [:poor_coverage, :very_poor_coverage] ->
        [
          "Improve timezone coverage - gaps identified in #{length(timezone_data.coverage_gaps)} hours"
          | recommendations
        ]

      _ ->
        recommendations
    end
  end

  defp maybe_add_leadership_recommendation(recommendations, potential_leaders)
       when potential_leaders < 3 do
    [
      "Develop more fleet leaders - only #{potential_leaders} potential leaders identified"
      | recommendations
    ]
  end

  defp maybe_add_leadership_recommendation(recommendations, _potential_leaders),
    do: recommendations

  defp finalize_participation_recommendations([]) do
    ["Maintain current participation levels and continue monitoring engagement"]
  end

  defp finalize_participation_recommendations(recommendations) do
    Enum.reverse(recommendations)
  end

  defp analyze_participation_trends(_corporation_id, _participation_data) do
    # Placeholder for trend analysis
    %{
      overall_trend: :stable,
      fleet_trend: :stable,
      engagement_trend: :stable
    }
  end

  defp perform_detailed_timezone_analysis(participation_data) do
    # Perform detailed timezone analysis from member activity data
    members = participation_data.member_participation || []

    # Build hourly activity heatmap
    timezone_heatmap =
      members
      |> Enum.flat_map(fn member ->
        # Get all hours where member was active
        member.killmails
        |> Enum.map(fn km ->
          hour = DateTime.to_time(km.killmail_time).hour
          day_of_week = Date.day_of_week(DateTime.to_date(km.killmail_time))
          {{hour, day_of_week}, 1}
        end)
      end)
      |> Enum.group_by(fn {{hour, dow}, _} -> {hour, dow} end, fn {_, count} -> count end)
      |> Enum.map(fn {{hour, dow}, counts} ->
        {{hour, dow}, Enum.sum(counts)}
      end)
      |> Map.new()

    # Analyze shift patterns (early/late/night shifts)
    shift_patterns = analyze_shift_activity_patterns(timezone_heatmap)

    # Analyze weekend vs weekday patterns
    weekend_patterns = analyze_weekend_activity_patterns(timezone_heatmap)

    %{
      timezone_heatmap: timezone_heatmap,
      shift_patterns: shift_patterns,
      weekend_patterns: weekend_patterns,
      activity_concentration: calculate_activity_concentration(timezone_heatmap),
      peak_days: identify_peak_activity_days(timezone_heatmap)
    }
  end

  defp analyze_shift_activity_patterns(heatmap) do
    # Group activity by shift periods
    shifts = %{
      # 00:00 - 05:59
      early_morning: 0..5,
      # 06:00 - 11:59
      morning: 6..11,
      # 12:00 - 17:59
      afternoon: 12..17,
      # 18:00 - 23:59
      evening: 18..23
    }

    shift_activity =
      shifts
      |> Enum.map(fn {shift, hour_range} ->
        activity =
          heatmap
          |> Enum.filter(fn {{hour, _day}, _count} -> hour in hour_range end)
          |> Enum.map(fn {_, count} -> count end)
          |> Enum.sum()

        {shift, activity}
      end)
      |> Map.new()

    total_activity = shift_activity |> Map.values() |> Enum.sum() |> max(1)

    # Calculate percentages
    shift_activity
    |> Enum.map(fn {shift, count} ->
      {shift, Float.round(count / total_activity * 100, 1)}
    end)
    |> Map.new()
  end

  defp analyze_weekend_activity_patterns(heatmap) do
    weekday_activity =
      heatmap
      |> Enum.filter(fn {{_hour, day}, _count} -> day in 1..5 end)
      |> Enum.map(fn {_, count} -> count end)
      |> Enum.sum()

    weekend_activity =
      heatmap
      |> Enum.filter(fn {{_hour, day}, _count} -> day in [6, 7] end)
      |> Enum.map(fn {_, count} -> count end)
      |> Enum.sum()

    total = max(weekday_activity + weekend_activity, 1)

    %{
      weekday_percentage: Float.round(weekday_activity / total * 100, 1),
      weekend_percentage: Float.round(weekend_activity / total * 100, 1),
      weekend_to_weekday_ratio: Float.round(weekend_activity / max(weekday_activity, 1), 2)
    }
  end

  defp calculate_activity_concentration(heatmap) do
    # Calculate how concentrated activity is (Gini coefficient style)
    # Total possible hour-day combinations
    total_hours = 24 * 7
    active_hours = map_size(heatmap)

    if active_hours == 0 do
      0.0
    else
      # Higher concentration means activity is in fewer time slots
      concentration = (1 - active_hours / total_hours) * 100
      Float.round(concentration, 1)
    end
  end

  defp identify_peak_activity_days(heatmap) do
    # Identify which days have most activity
    day_names = %{
      1 => "Monday",
      2 => "Tuesday",
      3 => "Wednesday",
      4 => "Thursday",
      5 => "Friday",
      6 => "Saturday",
      7 => "Sunday"
    }

    heatmap
    |> Enum.group_by(fn {{_hour, day}, _count} -> day end, fn {_, count} -> count end)
    |> Enum.map(fn {day, counts} -> {day, Enum.sum(counts)} end)
    |> Enum.sort_by(fn {_day, total} -> total end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {day, _total} -> Map.get(day_names, day, "Unknown") end)
  end

  defp get_historical_participation_data(_corporation_id, _time_period) do
    # Placeholder for historical data
    {:ok, []}
  end

  defp calculate_overall_participation_trend(_historical_data), do: :stable
  defp calculate_fleet_trend(_historical_data), do: :stable

  defp analyze_timezone_shifts(historical_data) do
    # Analyze how activity patterns shift over time
    if Enum.empty?(historical_data) do
      %{shift_detected: false, trend: :stable}
    else
      # Group by time period and analyze peak hours
      shifts =
        historical_data
        # 30-day periods
        |> Enum.chunk_every(30)
        |> Enum.map(fn period_data ->
          # Find peak activity hours for this period
          peak_hours =
            period_data
            |> Enum.flat_map(&(&1.hourly_activity || []))
            |> Enum.group_by(fn {hour, _} -> hour end, fn {_, count} -> count end)
            |> Enum.map(fn {hour, counts} -> {hour, Enum.sum(counts)} end)
            |> Enum.sort_by(fn {_hour, total} -> total end, :desc)
            |> Enum.take(3)
            |> Enum.map(fn {hour, _} -> hour end)

          peak_hours
        end)
        |> detect_timezone_shift_pattern()

      shifts
    end
  end

  defp detect_timezone_shift_pattern(peak_hours_by_period) do
    if length(peak_hours_by_period) < 2 do
      %{shift_detected: false, trend: :insufficient_data}
    else
      # Compare first and last periods
      first_peaks = List.first(peak_hours_by_period)
      last_peaks = List.last(peak_hours_by_period)

      # Calculate average shift in hours
      avg_first = Enum.sum(first_peaks) / max(length(first_peaks), 1)
      avg_last = Enum.sum(last_peaks) / max(length(last_peaks), 1)
      shift_hours = avg_last - avg_first

      %{
        shift_detected: abs(shift_hours) > 2,
        shift_direction:
          cond do
            shift_hours > 2 -> :later
            shift_hours < -2 -> :earlier
            true -> :stable
          end,
        shift_magnitude: Float.round(abs(shift_hours), 1),
        trend: :analyzed
      }
    end
  end

  defp identify_seasonal_patterns(_historical_data), do: %{}
end
