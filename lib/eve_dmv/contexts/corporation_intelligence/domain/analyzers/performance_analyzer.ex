defmodule EveDmv.Contexts.CorporationIntelligence.Domain.Analyzers.PerformanceAnalyzer do
  @moduledoc """
  Analyzes corporation performance metrics and trends.
  All analysis based on real killmail and member activity data.
  """

  import Ecto.Query

  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Repo
  require Logger

  # Efficiency rating thresholds
  @efficiency_thresholds [
    {80, :excellent},
    {60, :good},
    {40, :average},
    {20, :below_average},
    {0, :poor}
  ]

  # Growth trajectory thresholds
  @growth_trajectory_thresholds [
    {20, :rapid_growth},
    {10, :steady_growth},
    {0, :slow_growth},
    {-10, :stable},
    {-20, :declining},
    {-Float.max_finite(), :rapid_decline}
  ]

  # Trend slope thresholds
  @trend_slope_thresholds [
    {0.5, :strong_upward},
    {0.1, :upward},
    {-0.1, :stable},
    {-0.5, :downward},
    {-Float.max_finite(), :strong_downward}
  ]

  # Momentum classification thresholds
  @momentum_thresholds [
    {20, :accelerating},
    {0, :positive},
    {-20, :slowing},
    {-Float.max_finite(), :negative}
  ]

  # Utilization rating thresholds
  @utilization_thresholds [
    {80, :excellent},
    {60, :good},
    {40, :moderate},
    {20, :poor},
    {0, :critical}
  ]

  # Diversity rating thresholds
  @diversity_thresholds [
    {30, :highly_diverse},
    {20, :diverse},
    {10, :moderate},
    {5, :limited},
    {0, :monotonous}
  ]

  # Competitive position thresholds
  @competitive_position_thresholds [
    {100, :dominant},
    {50, :strong},
    {25, :competitive},
    {10, :developing},
    {0, :emerging}
  ]

  @doc """
  Analyzes corporation performance metrics
  """
  def analyze_performance(corporation_id, options \\ []) do
    days = Keyword.get(options, :days, 90)

    with {:ok, killmails} <- get_performance_data(corporation_id, days),
         {:ok, members} <- get_member_performance(corporation_id, days) do
      %{
        efficiency_metrics: calculate_efficiency_metrics(killmails, corporation_id),
        growth_indicators: analyze_growth_indicators(killmails, members),
        performance_trends: analyze_performance_trends(killmails, days),
        operational_effectiveness: measure_operational_effectiveness(killmails, members),
        comparative_performance: analyze_comparative_performance(killmails, corporation_id),
        performance_forecast: generate_performance_forecast(killmails)
      }
    else
      {:error, reason} ->
        Logger.error("Performance analysis failed: #{inspect(reason)}")
        {:error, :analysis_failed}
    end
  end

  defp get_performance_data(corporation_id, days) do
    cutoff_date = DateTimeUtils.add(DateTime.utc_now(), -days * 86_400, :second)

    query =
      from(k in "killmails_raw",
        where:
          k.victim_corporation_id == ^corporation_id or
            fragment("? @> ?::jsonb", k.data, ^%{attackers: [%{corporation_id: corporation_id}]}),
        where: k.killmail_time > ^cutoff_date,
        select: %{
          killmail_id: k.killmail_id,
          killmail_time: k.killmail_time,
          solar_system_id: k.solar_system_id,
          victim_ship_type_id: k.victim_ship_type_id,
          victim_corporation_id: k.victim_corporation_id,
          attacker_count: k.attacker_count,
          total_value: k.total_value,
          data: k.data
        },
        order_by: [asc: k.killmail_time]
      )

    {:ok, Repo.all(query)}
  rescue
    error ->
      Logger.error("Failed to get performance data: #{inspect(error)}")
      {:error, :data_fetch_failed}
  end

  defp get_member_performance(corporation_id, days) do
    cutoff_date = DateTimeUtils.add(DateTime.utc_now(), -days * 86_400, :second)

    # Get member activity from killmails
    query =
      from(k in "killmails_raw",
        where: k.victim_corporation_id == ^corporation_id,
        where: k.killmail_time > ^cutoff_date,
        select: %{
          character_id: k.victim_character_id,
          killmail_time: k.killmail_time,
          ship_type_id: k.victim_ship_type_id,
          total_value: k.total_value
        }
      )

    members_data = Repo.all(query)

    # Group by character to get member performance
    members =
      members_data
      |> Enum.group_by(& &1.character_id)
      |> Enum.map(fn {character_id, activities} ->
        %{
          character_id: character_id,
          activity_count: length(activities),
          total_loss_value: Enum.sum(Enum.map(activities, & &1.total_value)),
          first_seen: Enum.min_by(activities, & &1.killmail_time).killmail_time,
          last_seen: Enum.max_by(activities, & &1.killmail_time).killmail_time,
          ship_types_used: activities |> Enum.map(& &1.ship_type_id) |> Enum.uniq()
        }
      end)

    {:ok, members}
  rescue
    error ->
      Logger.error("Failed to get member performance: #{inspect(error)}")
      {:ok, []}
  end

  defp calculate_efficiency_metrics(killmails, corporation_id) do
    # Separate kills and losses
    losses = Enum.filter(killmails, &(&1.victim_corporation_id == corporation_id))
    kills = Enum.reject(killmails, &(&1.victim_corporation_id == corporation_id))

    total_losses_value = Enum.sum(Enum.map(losses, & &1.total_value))
    total_kills_value = Enum.sum(Enum.map(kills, & &1.total_value))

    # Calculate ISK efficiency
    isk_efficiency =
      if total_losses_value + total_kills_value > 0 do
        Float.round(total_kills_value / (total_losses_value + total_kills_value) * 100, 1)
      else
        0.0
      end

    # Calculate kill/death ratio
    kill_death_ratio =
      if losses != [] do
        Float.round(length(kills) / length(losses), 2)
      else
        if kills != [], do: Float.round(length(kills), 2), else: 0.0
      end

    # Calculate average engagement size
    avg_engagement_size =
      if killmails != [] do
        Float.round(Enum.sum(Enum.map(killmails, & &1.attacker_count)) / length(killmails), 1)
      else
        0.0
      end

    %{
      total_kills: length(kills),
      total_losses: length(losses),
      kill_death_ratio: kill_death_ratio,
      isk_efficiency: isk_efficiency,
      total_kills_value: total_kills_value,
      total_losses_value: total_losses_value,
      avg_kill_value:
        if(kills != [], do: Float.round(total_kills_value / length(kills), 0), else: 0),
      avg_loss_value:
        if(losses != [], do: Float.round(total_losses_value / length(losses), 0), else: 0),
      avg_engagement_size: avg_engagement_size,
      efficiency_rating: calculate_efficiency_rating(isk_efficiency, kill_death_ratio)
    }
  end

  defp calculate_efficiency_rating(isk_efficiency, kd_ratio) do
    # Composite efficiency rating
    score = isk_efficiency * 0.6 + min(kd_ratio * 20, 100) * 0.4

    @efficiency_thresholds
    |> Enum.find(fn {threshold, _rating} -> score >= threshold end)
    |> elem(1)
  end

  defp analyze_growth_indicators(killmails, members) do
    # Analyze growth trends
    activity_growth = calculate_activity_growth(killmails)
    member_growth = calculate_member_growth(members)
    engagement_growth = calculate_engagement_growth(killmails)

    %{
      activity_growth_rate: activity_growth,
      member_retention_rate: calculate_member_retention(members),
      new_member_rate: calculate_new_member_rate(members),
      engagement_growth_rate: engagement_growth,
      value_growth_rate: calculate_value_growth(killmails),
      growth_trajectory:
        determine_growth_trajectory(activity_growth, member_growth, engagement_growth)
    }
  end

  defp calculate_activity_growth(killmails) do
    if Enum.count(killmails) < 2 do
      0.0
    else
      # Compare first and last 30% of the period
      sorted = Enum.sort_by(killmails, & &1.killmail_time)
      split_point = div(length(sorted), 3)

      first_period = Enum.take(sorted, split_point)
      last_period = Enum.take(sorted, -split_point)

      if first_period != [] do
        growth = (length(last_period) - length(first_period)) / length(first_period) * 100
        Float.round(growth, 1)
      else
        0.0
      end
    end
  end

  defp calculate_member_growth(members) do
    if Enum.count(members) < 2 do
      0.0
    else
      # Look at member join patterns
      sorted = Enum.sort_by(members, & &1.first_seen)
      midpoint = div(length(sorted), 2)

      early_members = Enum.take(sorted, midpoint)
      recent_members = Enum.take(sorted, -midpoint)

      # Calculate average activity
      early_activity =
        Enum.sum(Enum.map(early_members, & &1.activity_count)) / max(length(early_members), 1)

      recent_activity =
        Enum.sum(Enum.map(recent_members, & &1.activity_count)) / max(length(recent_members), 1)

      if early_activity > 0 do
        Float.round((recent_activity - early_activity) / early_activity * 100, 1)
      else
        0.0
      end
    end
  end

  defp calculate_engagement_growth(killmails) do
    if Enum.count(killmails) < 2 do
      0.0
    else
      sorted = Enum.sort_by(killmails, & &1.killmail_time)
      split_point = div(length(sorted), 3)

      first_period = Enum.take(sorted, split_point)
      last_period = Enum.take(sorted, -split_point)

      first_avg =
        if first_period != [] do
          Enum.sum(Enum.map(first_period, & &1.attacker_count)) / length(first_period)
        else
          0
        end

      last_avg =
        if last_period != [] do
          Enum.sum(Enum.map(last_period, & &1.attacker_count)) / length(last_period)
        else
          0
        end

      if first_avg > 0 do
        Float.round((last_avg - first_avg) / first_avg * 100, 1)
      else
        0.0
      end
    end
  end

  defp calculate_member_retention(members) do
    if Enum.empty?(members) do
      0.0
    else
      # Calculate how many members are still active
      now = DateTime.utc_now()
      recent_cutoff = DateTimeUtils.add(now, -7 * 86_400, :second)

      active_members =
        Enum.count(members, fn m ->
          DateTime.compare(m.last_seen, recent_cutoff) == :gt
        end)

      Float.round(active_members / length(members) * 100, 1)
    end
  end

  defp calculate_new_member_rate(members) do
    if Enum.empty?(members) do
      0.0
    else
      # Count members who joined in last 30 days
      cutoff = DateTimeUtils.add(DateTime.utc_now(), -30 * 86_400, :second)

      new_members =
        Enum.count(members, fn m ->
          DateTime.compare(m.first_seen, cutoff) == :gt
        end)

      Float.round(new_members / length(members) * 100, 1)
    end
  end

  defp calculate_value_growth(killmails) do
    if Enum.count(killmails) < 2 do
      0.0
    else
      sorted = Enum.sort_by(killmails, & &1.killmail_time)
      split_point = div(length(sorted), 3)

      first_period = Enum.take(sorted, split_point)
      last_period = Enum.take(sorted, -split_point)

      first_value = Enum.sum(Enum.map(first_period, & &1.total_value))
      last_value = Enum.sum(Enum.map(last_period, & &1.total_value))

      if first_value > 0 do
        Float.round((last_value - first_value) / first_value * 100, 1)
      else
        0.0
      end
    end
  end

  defp determine_growth_trajectory(activity_growth, member_growth, engagement_growth) do
    avg_growth = (activity_growth + member_growth + engagement_growth) / 3

    @growth_trajectory_thresholds
    |> Enum.find(fn {threshold, _trajectory} -> avg_growth > threshold end)
    |> elem(1)
  end

  defp classify_trend_by_slope(slope) do
    @trend_slope_thresholds
    |> Enum.find(fn {threshold, _trend} -> slope > threshold end)
    |> elem(1)
  end

  defp classify_momentum(momentum) do
    @momentum_thresholds
    |> Enum.find(fn {threshold, _classification} -> momentum > threshold end)
    |> elem(1)
  end

  defp classify_utilization(utilization) do
    @utilization_thresholds
    |> Enum.find(fn {threshold, _rating} -> utilization > threshold end)
    |> elem(1)
  end

  defp classify_diversity(diversity_score) do
    @diversity_thresholds
    |> Enum.find(fn {threshold, _rating} -> diversity_score > threshold end)
    |> elem(1)
  end

  defp classify_competitive_position(score) do
    @competitive_position_thresholds
    |> Enum.find(fn {threshold, _position} -> score > threshold end)
    |> elem(1)
  end

  defp analyze_performance_trends(killmails, _days) do
    # Group killmails by week
    weekly_data = group_by_week(killmails)

    %{
      weekly_activity: calculate_weekly_trends(weekly_data),
      performance_volatility: calculate_performance_volatility(weekly_data),
      trend_direction: determine_trend_direction(weekly_data),
      consistency_score: calculate_consistency_score(weekly_data),
      peak_performance_period: identify_peak_performance(weekly_data),
      current_momentum: assess_current_momentum(killmails)
    }
  end

  defp group_by_week(killmails) do
    killmails
    |> Enum.group_by(fn km ->
      Date.beginning_of_week(DateTime.to_date(km.killmail_time))
    end)
    |> Enum.map(fn {week_start, kills} ->
      %{
        week_start: week_start,
        kill_count: length(kills),
        total_value: Enum.sum(Enum.map(kills, & &1.total_value)),
        avg_engagement_size:
          Enum.sum(Enum.map(kills, & &1.attacker_count)) / max(length(kills), 1)
      }
    end)
    |> Enum.sort_by(& &1.week_start)
  end

  defp calculate_weekly_trends(weekly_data) do
    weekly_data
    |> Enum.map(fn week ->
      %{
        week: week.week_start,
        activity: week.kill_count,
        value: week.total_value,
        avg_engagement: Float.round(week.avg_engagement_size, 1)
      }
    end)
  end

  defp calculate_performance_volatility(weekly_data) do
    if Enum.count(weekly_data) < 2 do
      :insufficient_data
    else
      activities = Enum.map(weekly_data, & &1.kill_count)
      avg = Enum.sum(activities) / length(activities)

      variance =
        activities
        |> Enum.map(fn a -> :math.pow(a - avg, 2) end)
        |> Enum.sum()
        |> Kernel./(length(activities))

      std_dev = :math.sqrt(variance)
      cv = if avg == 0, do: 0, else: std_dev / avg

      cond do
        cv < 0.2 -> :very_stable
        cv < 0.4 -> :stable
        cv < 0.6 -> :moderate
        cv < 0.8 -> :volatile
        true -> :highly_volatile
      end
    end
  end

  defp determine_trend_direction(weekly_data) do
    if Enum.count(weekly_data) < 3 do
      :insufficient_data
    else
      # Simple linear regression on activity
      indexed_data =
        weekly_data
        |> Enum.with_index()
        |> Enum.map(fn {week, i} -> {i, week.kill_count} end)

      n = length(indexed_data)
      sum_x = Enum.sum(Enum.map(indexed_data, fn {x, _} -> x end))
      sum_y = Enum.sum(Enum.map(indexed_data, fn {_, y} -> y end))
      sum_xy = Enum.sum(Enum.map(indexed_data, fn {x, y} -> x * y end))
      sum_x2 = Enum.sum(Enum.map(indexed_data, fn {x, _} -> x * x end))

      slope =
        if n * sum_x2 - sum_x * sum_x == 0 do
          0
        else
          (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
        end

      classify_trend_by_slope(slope)
    end
  end

  defp calculate_consistency_score(weekly_data) do
    if Enum.count(weekly_data) < 2 do
      0.0
    else
      activities = Enum.map(weekly_data, & &1.kill_count)
      avg = Enum.sum(activities) / length(activities)

      if avg == 0 do
        0.0
      else
        # Higher score for more consistent activity
        variance =
          activities
          |> Enum.map(fn a -> :math.pow(a - avg, 2) end)
          |> Enum.sum()
          |> Kernel./(length(activities))

        std_dev = :math.sqrt(variance)
        cv = std_dev / avg

        # Convert to 0-100 score (lower CV = higher consistency)
        Float.round(max(0, min(100, (1 - cv) * 100)), 1)
      end
    end
  end

  defp identify_peak_performance(weekly_data) do
    if Enum.empty?(weekly_data) do
      nil
    else
      peak =
        Enum.max_by(weekly_data, fn week ->
          # Composite score of activity and value
          week.kill_count * 0.5 + week.total_value / 1_000_000_000 * 0.5
        end)

      %{
        week: peak.week_start,
        kills: peak.kill_count,
        value: peak.total_value,
        avg_engagement: Float.round(peak.avg_engagement_size, 1)
      }
    end
  end

  defp assess_current_momentum(killmails) do
    # Compare last 7 days to previous 7 days
    now = DateTime.utc_now()
    week_ago = DateTimeUtils.add(now, -7 * 86_400, :second)
    two_weeks_ago = DateTimeUtils.add(now, -14 * 86_400, :second)

    recent =
      Enum.filter(killmails, fn km ->
        DateTime.compare(km.killmail_time, week_ago) == :gt
      end)

    previous =
      Enum.filter(killmails, fn km ->
        DateTime.compare(km.killmail_time, two_weeks_ago) == :gt and
          DateTime.compare(km.killmail_time, week_ago) != :gt
      end)

    recent_score = length(recent) + Enum.sum(Enum.map(recent, & &1.total_value)) / 1_000_000_000

    previous_score =
      length(previous) + Enum.sum(Enum.map(previous, & &1.total_value)) / 1_000_000_000

    momentum =
      if previous_score > 0 do
        Float.round((recent_score - previous_score) / previous_score * 100, 1)
      else
        0.0
      end

    %{
      momentum_percentage: momentum,
      momentum_direction: classify_momentum(momentum)
    }
  end

  defp measure_operational_effectiveness(killmails, members) do
    %{
      force_projection: calculate_force_projection(killmails),
      member_utilization: calculate_member_utilization(members),
      tactical_diversity: analyze_tactical_diversity(killmails),
      response_capability: assess_response_capability(killmails),
      coordination_efficiency: measure_coordination_efficiency(killmails, members)
    }
  end

  defp calculate_force_projection(killmails) do
    # Analyze geographic spread and engagement reach
    systems =
      killmails
      |> Enum.map(& &1.solar_system_id)
      |> Enum.uniq()

    %{
      systems_reached: length(systems),
      projection_rating:
        cond do
          length(systems) > 50 -> :excellent
          length(systems) > 25 -> :good
          length(systems) > 10 -> :moderate
          length(systems) > 5 -> :limited
          true -> :minimal
        end
    }
  end

  defp calculate_member_utilization(members) do
    if Enum.empty?(members) do
      %{utilization_rate: 0.0, rating: :no_data}
    else
      active_members = Enum.count(members, &(&1.activity_count > 0))
      utilization = Float.round(active_members / length(members) * 100, 1)

      %{
        utilization_rate: utilization,
        rating: classify_utilization(utilization)
      }
    end
  end

  defp analyze_tactical_diversity(killmails) do
    # Analyze variety in engagement types
    engagement_sizes =
      killmails
      |> Enum.map(& &1.attacker_count)
      |> Enum.uniq()
      |> length()

    ship_types =
      killmails
      |> Enum.map(& &1.victim_ship_type_id)
      |> Enum.uniq()
      |> length()

    diversity_score = engagement_sizes * 0.4 + ship_types * 0.6

    %{
      engagement_variety: engagement_sizes,
      ship_variety: ship_types,
      diversity_rating: classify_diversity(diversity_score)
    }
  end

  defp assess_response_capability(killmails) do
    # Analyze response times and escalation patterns
    if Enum.count(killmails) < 2 do
      %{capability: :unknown, avg_response_time: nil}
    else
      # Group killmails by system and time proximity
      response_chains = identify_response_chains(killmails)

      if Enum.empty?(response_chains) do
        %{capability: :unknown, avg_response_time: nil}
      else
        avg_response =
          response_chains
          |> Enum.map(& &1.response_time)
          |> Enum.sum()
          |> Kernel./(length(response_chains))

        %{
          capability:
            cond do
              # < 5 minutes
              avg_response < 300 -> :excellent
              # < 10 minutes
              avg_response < 600 -> :good
              # < 15 minutes
              avg_response < 900 -> :moderate
              true -> :slow
            end,
          # in minutes
          avg_response_time: Float.round(avg_response / 60, 1)
        }
      end
    end
  end

  defp identify_response_chains(killmails) do
    killmails
    |> Enum.sort_by(& &1.killmail_time)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.filter(fn [a, b] ->
      # Same system and within 30 minutes
      a.solar_system_id == b.solar_system_id and
        DateTime.diff(b.killmail_time, a.killmail_time, :second) < 1800
    end)
    |> Enum.map(fn [a, b] ->
      %{
        response_time: DateTime.diff(b.killmail_time, a.killmail_time, :second),
        escalation: b.attacker_count > a.attacker_count
      }
    end)
  end

  defp measure_coordination_efficiency(killmails, members) do
    # Measure how well coordinated operations are
    if Enum.empty?(killmails) or Enum.empty?(members) do
      %{efficiency: 0.0, rating: :no_data}
    else
      # Calculate concentration of activity
      total_activity = length(killmails)
      active_members = Enum.count(members, &(&1.activity_count > 0))

      if active_members == 0 do
        %{efficiency: 0.0, rating: :no_activity}
      else
        activity_per_member = total_activity / active_members

        # Higher activity per member = better coordination
        efficiency = min(100, activity_per_member * 10)

        %{
          efficiency: Float.round(efficiency, 1),
          rating:
            cond do
              efficiency > 80 -> :excellent
              efficiency > 60 -> :good
              efficiency > 40 -> :moderate
              efficiency > 20 -> :poor
              true -> :minimal
            end
        }
      end
    end
  end

  defp analyze_comparative_performance(killmails, _corporation_id) do
    # Compare to similar corporations (simplified)
    corp_size = estimate_corporation_size(killmails)

    %{
      size_category: corp_size,
      performance_percentile: estimate_performance_percentile(killmails, corp_size),
      strengths: identify_strengths(killmails),
      improvement_areas: identify_improvement_areas(killmails),
      competitive_position: assess_competitive_position(killmails)
    }
  end

  defp estimate_corporation_size(killmails) do
    unique_characters =
      killmails
      |> Enum.map(fn km ->
        if km.victim_corporation_id do
          # This is simplified - would need to parse attacker data for full picture
          km.victim_character_id
        end
      end)
      |> Enum.filter(& &1)
      |> Enum.uniq()
      |> length()

    cond do
      unique_characters > 100 -> :large
      unique_characters > 50 -> :medium_large
      unique_characters > 25 -> :medium
      unique_characters > 10 -> :small_medium
      true -> :small
    end
  end

  defp estimate_performance_percentile(killmails, _size_category) do
    # Simplified percentile estimation based on activity
    activity_score = length(killmails)

    cond do
      activity_score > 500 -> 90
      activity_score > 200 -> 75
      activity_score > 100 -> 60
      activity_score > 50 -> 45
      activity_score > 25 -> 30
      true -> 15
    end
  end

  defp identify_strengths(killmails) do
    # High activity
    activity_strength =
      if length(killmails) > 100 do
        ["High activity level"]
      else
        []
      end

    # Good engagement sizes
    avg_engagement =
      if killmails != [] do
        Enum.sum(Enum.map(killmails, & &1.attacker_count)) / length(killmails)
      else
        0
      end

    engagement_strength =
      if avg_engagement > 10 do
        ["Strong fleet operations"]
      else
        []
      end

    # Geographic spread
    systems = killmails |> Enum.map(& &1.solar_system_id) |> Enum.uniq() |> length()

    geographic_strength =
      if systems > 20 do
        ["Wide operational range"]
      else
        []
      end

    all_strengths = activity_strength ++ engagement_strength ++ geographic_strength

    if Enum.empty?(all_strengths) do
      ["Establishing presence"]
    else
      all_strengths
    end
  end

  defp identify_improvement_areas(killmails) do
    # Low activity
    activity_area =
      if length(killmails) < 50 do
        ["Increase activity level"]
      else
        []
      end

    # Limited geographic presence
    systems = killmails |> Enum.map(& &1.solar_system_id) |> Enum.uniq() |> length()

    geographic_area =
      if systems < 10 do
        ["Expand operational range"]
      else
        []
      end

    # Small engagement sizes
    avg_engagement =
      if killmails != [] do
        Enum.sum(Enum.map(killmails, & &1.attacker_count)) / length(killmails)
      else
        0
      end

    engagement_area =
      if avg_engagement < 5 do
        ["Improve fleet coordination"]
      else
        []
      end

    all_areas = activity_area ++ geographic_area ++ engagement_area

    if Enum.empty?(all_areas) do
      ["Maintain momentum"]
    else
      all_areas
    end
  end

  defp assess_competitive_position(killmails) do
    score =
      length(killmails) * 0.1 +
        (killmails |> Enum.map(& &1.solar_system_id) |> Enum.uniq() |> length()) * 2

    classify_competitive_position(score)
  end

  defp generate_performance_forecast(killmails) do
    # Simple forecast based on recent trends
    if Enum.count(killmails) < 7 do
      %{
        forecast: :insufficient_data,
        confidence: 0.0
      }
    else
      recent_trend = analyze_recent_trend(killmails)

      %{
        next_week_projection: project_next_week(recent_trend),
        trend_sustainability: assess_trend_sustainability(recent_trend),
        risk_factors: identify_risk_factors(killmails),
        opportunities: identify_opportunities(killmails),
        confidence: calculate_forecast_confidence(killmails)
      }
    end
  end

  defp analyze_recent_trend(killmails) do
    # Analyze last 14 days
    cutoff = DateTimeUtils.add(DateTime.utc_now(), -14 * 86_400, :second)

    recent =
      Enum.filter(killmails, fn km ->
        DateTime.compare(km.killmail_time, cutoff) == :gt
      end)

    daily_activity =
      recent
      |> Enum.group_by(fn km -> DateTime.to_date(km.killmail_time) end)
      |> Map.new(fn {date, kills} -> {date, length(kills)} end)

    %{
      daily_average:
        if(map_size(daily_activity) > 0,
          do: Float.round(Enum.sum(Map.values(daily_activity)) / map_size(daily_activity), 1),
          else: 0.0
        ),
      trend_direction: if(map_size(daily_activity) > 7, do: :stable, else: :uncertain),
      volatility: calculate_daily_volatility(Map.values(daily_activity))
    }
  end

  defp calculate_daily_volatility(daily_values) do
    if Enum.count(daily_values) < 2 do
      :low
    else
      avg = Enum.sum(daily_values) / length(daily_values)

      variance =
        daily_values
        |> Enum.map(fn v -> :math.pow(v - avg, 2) end)
        |> Enum.sum()
        |> Kernel./(length(daily_values))

      std_dev = :math.sqrt(variance)
      cv = if avg == 0, do: 0, else: std_dev / avg

      cond do
        cv < 0.3 -> :low
        cv < 0.6 -> :moderate
        true -> :high
      end
    end
  end

  defp project_next_week(trend_data) do
    %{
      expected_activity: Float.round(trend_data.daily_average * 7, 0),
      activity_range: {
        # Conservative
        Float.round(trend_data.daily_average * 5, 0),
        # Optimistic
        Float.round(trend_data.daily_average * 9, 0)
      },
      trend_continuation: trend_data.trend_direction
    }
  end

  defp assess_trend_sustainability(trend_data) do
    case trend_data.volatility do
      :low -> :highly_sustainable
      :moderate -> :sustainable
      :high -> :uncertain
    end
  end

  defp identify_risk_factors(killmails) do
    # Low recent activity
    recent_count =
      killmails
      |> Enum.filter(fn km ->
        DateTime.diff(DateTime.utc_now(), km.killmail_time, :second) < 7 * 86_400
      end)
      |> length()

    # Limited geographic presence
    system_count =
      killmails
      |> Enum.map(& &1.solar_system_id)
      |> Enum.uniq()
      |> length()

    risks =
      []
      |> maybe_add_risk(recent_count < 10, "Declining activity")
      |> maybe_add_risk(system_count < 5, "Over-concentration in few systems")

    if Enum.empty?(risks) do
      ["No significant risks identified"]
    else
      risks
    end
  end

  defp maybe_add_risk(list, true, risk), do: list ++ [risk]
  defp maybe_add_risk(list, false, _risk), do: list

  defp identify_opportunities(killmails) do
    base_opportunities = []

    # Growing activity
    with_activity =
      if length(killmails) > 50 do
        ["Momentum for expansion" | base_opportunities]
      else
        base_opportunities
      end

    # Diverse operations
    systems = killmails |> Enum.map(& &1.solar_system_id) |> Enum.uniq() |> length()

    all_opportunities =
      if systems > 10 do
        ["Strong operational flexibility" | with_activity]
      else
        with_activity
      end

    if Enum.empty?(all_opportunities) do
      ["Focus on core operations"]
    else
      all_opportunities
    end
  end

  defp calculate_forecast_confidence(killmails) do
    # Base confidence on data quantity and recency
    data_points = length(killmails)

    recent =
      Enum.count(killmails, fn km ->
        DateTime.diff(DateTime.utc_now(), km.killmail_time, :second) < 7 * 86_400
      end)

    base_confidence = min(50, data_points / 2)
    recency_bonus = min(50, recent * 5)

    Float.round(base_confidence + recency_bonus, 1)
  end
end
