defmodule EveDmv.Contexts.FleetOperations.Domain.EffectivenessCalculator do
  @moduledoc """
  Fleet effectiveness calculation engine.

  Provides comprehensive metrics for fleet performance analysis,
  including damage efficiency, survival rates, and tactical effectiveness.
  """

  use EveDmv.ErrorHandler
  alias EveDmv.Result
  alias EveDmv.Contexts.FleetOperations.Infrastructure.{FleetRepository, EngagementCache}

  require Logger

  # Effectiveness weights for different metrics
  @effectiveness_weights %{
    isk_efficiency: 0.3,
    kill_death_ratio: 0.25,
    survival_rate: 0.2,
    objective_completion: 0.15,
    tactical_execution: 0.1
  }

  @doc """
  Calculate comprehensive fleet effectiveness metrics.
  """
  def calculate_fleet_effectiveness(fleet_id) do
    case EngagementCache.get_fleet_engagements(%{fleet_id: fleet_id}) do
      {:ok, engagements} ->
        if length(engagements) > 0 do
          calculate_effectiveness_from_engagements(fleet_id, engagements)
        else
          {:error, :no_engagement_data}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Calculate performance trends for a corporation over time.
  """
  def calculate_performance_trends(corporation_id, time_range \\ :last_90d) do
    case EngagementCache.get_corporation_engagements(corporation_id, time_range) do
      {:ok, engagements} ->
        calculate_trend_analysis(engagements, time_range)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Analyze fleet losses to identify improvement areas.
  """
  def analyze_fleet_losses(fleet_data) do
    participants = fleet_data.participants
    killmails = Map.get(fleet_data, :killmails, [])

    loss_analysis = perform_loss_analysis(participants, killmails)

    {:ok, loss_analysis}
  end

  @doc """
  Calculate damage per second efficiency for a fleet.
  """
  def calculate_dps_efficiency(fleet_data, engagement_duration_seconds) do
    participants = fleet_data.participants
    killmails = Map.get(fleet_data, :killmails, [])

    total_damage = calculate_total_damage_dealt(participants, killmails)

    if engagement_duration_seconds > 0 do
      dps = total_damage / engagement_duration_seconds

      efficiency_metrics = %{
        total_damage: total_damage,
        engagement_duration: engagement_duration_seconds,
        damage_per_second: Float.round(dps, 2),
        damage_per_pilot: Float.round(total_damage / length(participants), 2),
        dps_per_pilot: Float.round(dps / length(participants), 2)
      }

      {:ok, efficiency_metrics}
    else
      {:error, :invalid_duration}
    end
  end

  @doc """
  Calculate fleet coordination score based on engagement patterns.
  """
  def calculate_coordination_score(fleet_data) do
    participants = fleet_data.participants
    killmails = Map.get(fleet_data, :killmails, [])

    coordination_metrics = analyze_fleet_coordination(participants, killmails)

    {:ok, coordination_metrics}
  end

  # Private implementation functions

  defp calculate_effectiveness_from_engagements(fleet_id, engagements) do
    # Aggregate metrics across all engagements
    aggregated_metrics = aggregate_engagement_metrics(engagements)

    # Calculate individual effectiveness components
    isk_efficiency = calculate_isk_efficiency_score(aggregated_metrics)
    kd_ratio_score = calculate_kd_ratio_score(aggregated_metrics)
    survival_score = calculate_survival_score(aggregated_metrics)
    objective_score = calculate_objective_completion_score(aggregated_metrics)
    tactical_score = calculate_tactical_execution_score(aggregated_metrics)

    # Calculate weighted overall effectiveness
    overall_effectiveness =
      isk_efficiency * @effectiveness_weights.isk_efficiency +
        kd_ratio_score * @effectiveness_weights.kill_death_ratio +
        survival_score * @effectiveness_weights.survival_rate +
        objective_score * @effectiveness_weights.objective_completion +
        tactical_score * @effectiveness_weights.tactical_execution

    effectiveness_result = %{
      fleet_id: fleet_id,
      overall_effectiveness: Float.round(overall_effectiveness, 3),
      component_scores: %{
        isk_efficiency: Float.round(isk_efficiency, 3),
        kill_death_ratio: Float.round(kd_ratio_score, 3),
        survival_rate: Float.round(survival_score, 3),
        objective_completion: Float.round(objective_score, 3),
        tactical_execution: Float.round(tactical_score, 3)
      },
      engagement_count: length(engagements),
      data_period: determine_data_period(engagements),
      aggregated_metrics: aggregated_metrics,
      effectiveness_grade: determine_effectiveness_grade(overall_effectiveness),
      improvement_recommendations:
        generate_effectiveness_recommendations(
          isk_efficiency,
          kd_ratio_score,
          survival_score,
          objective_score,
          tactical_score
        )
    }

    {:ok, effectiveness_result}
  end

  defp aggregate_engagement_metrics(engagements) do
    Enum.reduce(
      engagements,
      %{
        total_kills: 0,
        total_losses: 0,
        total_isk_destroyed: 0,
        total_isk_lost: 0,
        total_participants: 0,
        total_survivors: 0,
        objectives_attempted: 0,
        objectives_completed: 0,
        engagement_durations: [],
        pilot_performance_scores: []
      },
      fn engagement, acc ->
        %{
          total_kills: acc.total_kills + (engagement.kills || 0),
          total_losses: acc.total_losses + (engagement.losses || 0),
          total_isk_destroyed: acc.total_isk_destroyed + (engagement.isk_destroyed || 0),
          total_isk_lost: acc.total_isk_lost + (engagement.isk_lost || 0),
          total_participants: acc.total_participants + (engagement.participant_count || 0),
          total_survivors: acc.total_survivors + (engagement.survivors || 0),
          objectives_attempted: acc.objectives_attempted + 1,
          objectives_completed:
            acc.objectives_completed + if(engagement.objective_achieved, do: 1, else: 0),
          engagement_durations: [engagement.duration_seconds | acc.engagement_durations],
          pilot_performance_scores:
            acc.pilot_performance_scores ++ (engagement.pilot_scores || [])
        }
      end
    )
  end

  defp calculate_isk_efficiency_score(metrics) do
    total_isk = metrics.total_isk_destroyed + metrics.total_isk_lost

    if total_isk > 0 do
      efficiency = metrics.total_isk_destroyed / total_isk
      # Convert to 0-1 scale (50% efficiency = 0.5 score)
      efficiency
    else
      # Neutral score if no ISK data
      0.5
    end
  end

  defp calculate_kd_ratio_score(metrics) do
    if metrics.total_losses > 0 do
      kd_ratio = metrics.total_kills / metrics.total_losses
      # Normalize KD ratio to 0-1 scale (3:1 ratio = 1.0 score)
      min(1.0, kd_ratio / 3.0)
    else
      # No losses is perfect score if there were kills
      if metrics.total_kills > 0, do: 1.0, else: 0.5
    end
  end

  defp calculate_survival_score(metrics) do
    if metrics.total_participants > 0 do
      survival_rate = metrics.total_survivors / metrics.total_participants
      survival_rate
    else
      0.0
    end
  end

  defp calculate_objective_completion_score(metrics) do
    if metrics.objectives_attempted > 0 do
      completion_rate = metrics.objectives_completed / metrics.objectives_attempted
      completion_rate
    else
      # Neutral score if no objectives tracked
      0.5
    end
  end

  defp calculate_tactical_execution_score(metrics) do
    # Based on engagement duration efficiency and pilot performance
    avg_engagement_duration =
      if length(metrics.engagement_durations) > 0 do
        Enum.sum(metrics.engagement_durations) / length(metrics.engagement_durations)
      else
        0
      end

    avg_pilot_performance =
      if length(metrics.pilot_performance_scores) > 0 do
        Enum.sum(metrics.pilot_performance_scores) / length(metrics.pilot_performance_scores)
      else
        0.5
      end

    # Quick engagements (< 5 minutes) with good pilot performance = high tactical score
    duration_score =
      cond do
        avg_engagement_duration == 0 -> 0.5
        # < 5 minutes
        avg_engagement_duration < 300 -> 1.0
        # < 15 minutes
        avg_engagement_duration < 900 -> 0.8
        # < 30 minutes
        avg_engagement_duration < 1800 -> 0.6
        # > 30 minutes
        true -> 0.4
      end

    # Weighted average of duration efficiency and pilot performance
    duration_score * 0.6 + avg_pilot_performance * 0.4
  end

  defp calculate_trend_analysis(engagements, time_range) do
    # Group engagements by time periods
    time_buckets = group_engagements_by_time(engagements, time_range)

    # Calculate effectiveness for each time bucket
    trend_data =
      Enum.map(time_buckets, fn {period, period_engagements} ->
        period_metrics = aggregate_engagement_metrics(period_engagements)

        %{
          period: period,
          engagement_count: length(period_engagements),
          isk_efficiency: calculate_isk_efficiency_score(period_metrics),
          kill_death_ratio:
            if(period_metrics.total_losses > 0,
              do: period_metrics.total_kills / period_metrics.total_losses,
              else: 0
            ),
          survival_rate: calculate_survival_score(period_metrics),
          average_fleet_size:
            if(length(period_engagements) > 0,
              do: period_metrics.total_participants / length(period_engagements),
              else: 0
            )
        }
      end)

    # Calculate trend directions
    trends = calculate_trend_directions(trend_data)

    trend_analysis = %{
      time_range: time_range,
      trend_data: trend_data,
      trends: trends,
      overall_improvement: calculate_overall_improvement_trend(trend_data),
      recommendations: generate_trend_recommendations(trends)
    }

    {:ok, trend_analysis}
  end

  defp perform_loss_analysis(participants, killmails) do
    participant_ids = MapSet.new(participants, & &1.character_id)

    # Find losses (fleet members who died)
    fleet_losses =
      Enum.filter(killmails, fn killmail ->
        MapSet.member?(participant_ids, killmail.victim.character_id)
      end)

    # Analyze loss patterns
    loss_patterns = analyze_loss_patterns(fleet_losses)

    # Identify common loss causes
    loss_causes = identify_loss_causes(fleet_losses)

    # Calculate loss impact
    loss_impact = calculate_loss_impact(fleet_losses, participants)

    # Generate prevention recommendations
    prevention_recommendations =
      generate_loss_prevention_recommendations(loss_patterns, loss_causes)

    loss_analysis = %{
      total_losses: length(fleet_losses),
      loss_rate: length(fleet_losses) / length(participants) * 100,
      loss_patterns: loss_patterns,
      loss_causes: loss_causes,
      loss_impact: loss_impact,
      prevention_recommendations: prevention_recommendations,
      high_risk_factors: identify_high_risk_factors(fleet_losses, participants)
    }

    loss_analysis
  end

  defp analyze_loss_patterns(fleet_losses) do
    # Analyze temporal patterns
    loss_times = Enum.map(fleet_losses, & &1.killmail_time)

    # Analyze ship type patterns
    lost_ship_types = Enum.frequencies(Enum.map(fleet_losses, & &1.victim.ship_type_id))

    # Analyze damage patterns
    damage_analysis = analyze_damage_patterns(fleet_losses)

    %{
      temporal_clustering: analyze_temporal_clustering(loss_times),
      vulnerable_ship_types: identify_vulnerable_ship_types(lost_ship_types),
      damage_patterns: damage_analysis
    }
  end

  defp identify_loss_causes(fleet_losses) do
    Enum.reduce(fleet_losses, %{}, fn loss, acc ->
      # Determine primary cause of death
      primary_attacker = Enum.max_by(loss.attackers, & &1.damage_done, fn -> nil end)

      cause =
        cond do
          is_nil(primary_attacker) -> :unknown
          primary_attacker.weapon_type_id in [0, nil] -> :bumping_or_explosion
          length(loss.attackers) == 1 -> :solo_gank
          length(loss.attackers) > 10 -> :blob_warfare
          true -> :small_gang
        end

      Map.update(acc, cause, 1, &(&1 + 1))
    end)
  end

  defp calculate_loss_impact(fleet_losses, participants) do
    total_isk_lost = Enum.sum(fleet_losses, &(&1.zkb_total_value || 0))

    # Calculate role impact
    lost_roles =
      Enum.map(fleet_losses, fn loss ->
        # Determine role of lost ship
        determine_ship_role(loss.victim.ship_type_id)
      end)

    role_impact = Enum.frequencies(lost_roles)

    %{
      total_isk_lost: total_isk_lost,
      average_loss_value:
        if(length(fleet_losses) > 0, do: total_isk_lost / length(fleet_losses), else: 0),
      role_impact: role_impact,
      fleet_capability_reduction: calculate_capability_reduction(role_impact, participants)
    }
  end

  defp calculate_total_damage_dealt(participants, killmails) do
    participant_ids = MapSet.new(participants, & &1.character_id)

    Enum.sum(killmails, fn killmail ->
      # Sum damage dealt by fleet members in this killmail
      Enum.sum(killmail.attackers, fn attacker ->
        if MapSet.member?(participant_ids, attacker.character_id) do
          attacker.damage_done || 0
        else
          0
        end
      end)
    end)
  end

  defp analyze_fleet_coordination(participants, killmails) do
    participant_ids = MapSet.new(participants, & &1.character_id)

    # Analyze kill participation rates
    kill_participation = calculate_kill_participation(participants, killmails, participant_ids)

    # Analyze timing coordination
    timing_coordination = analyze_timing_coordination(killmails, participant_ids)

    # Calculate overall coordination score
    coordination_score =
      (kill_participation.average_participation + timing_coordination.sync_score) / 2

    %{
      coordination_score: Float.round(coordination_score, 3),
      kill_participation: kill_participation,
      timing_coordination: timing_coordination,
      coordination_grade: determine_coordination_grade(coordination_score)
    }
  end

  defp calculate_kill_participation(participants, killmails, participant_ids) do
    # Calculate how many fleet members participated in each kill
    participation_rates =
      Enum.map(killmails, fn killmail ->
        participants_on_kill =
          Enum.count(killmail.attackers, fn attacker ->
            MapSet.member?(participant_ids, attacker.character_id)
          end)

        participants_on_kill / length(participants)
      end)

    average_participation =
      if length(participation_rates) > 0 do
        Enum.sum(participation_rates) / length(participation_rates)
      else
        0.0
      end

    %{
      average_participation: Float.round(average_participation, 3),
      participation_rates: participation_rates,
      high_participation_kills: Enum.count(participation_rates, &(&1 > 0.7))
    }
  end

  defp analyze_timing_coordination(killmails, participant_ids) do
    # Analyze how synchronized the fleet's damage application is
    kill_windows =
      Enum.map(killmails, fn killmail ->
        fleet_attackers =
          Enum.filter(killmail.attackers, fn attacker ->
            MapSet.member?(participant_ids, attacker.character_id)
          end)

        if length(fleet_attackers) > 1 do
          # Calculate damage concentration (how much damage was applied in short time)
          # This is simplified - real implementation would use actual timestamps
          damage_spread = calculate_damage_spread(fleet_attackers)
          # Lower spread = higher coordination
          1.0 - damage_spread
        else
          # Neutral for single attacker
          0.5
        end
      end)

    sync_score =
      if length(kill_windows) > 0 do
        Enum.sum(kill_windows) / length(kill_windows)
      else
        0.0
      end

    %{
      sync_score: Float.round(sync_score, 3),
      synchronized_kills: Enum.count(kill_windows, &(&1 > 0.7))
    }
  end

  # Helper functions

  defp determine_data_period(engagements) do
    if length(engagements) > 0 do
      earliest = Enum.min_by(engagements, & &1.timestamp)
      latest = Enum.max_by(engagements, & &1.timestamp)

      %{
        start: earliest.timestamp,
        end: latest.timestamp,
        duration_days: DateTime.diff(latest.timestamp, earliest.timestamp, :day)
      }
    else
      %{start: nil, end: nil, duration_days: 0}
    end
  end

  defp determine_effectiveness_grade(effectiveness_score) do
    cond do
      effectiveness_score >= 0.9 -> :excellent
      effectiveness_score >= 0.8 -> :very_good
      effectiveness_score >= 0.7 -> :good
      effectiveness_score >= 0.6 -> :average
      effectiveness_score >= 0.5 -> :below_average
      effectiveness_score >= 0.4 -> :poor
      true -> :very_poor
    end
  end

  defp determine_coordination_grade(coordination_score) do
    cond do
      coordination_score >= 0.8 -> :excellent
      coordination_score >= 0.6 -> :good
      coordination_score >= 0.4 -> :average
      true -> :poor
    end
  end

  defp generate_effectiveness_recommendations(
         isk_eff,
         kd_score,
         survival_score,
         objective_score,
         tactical_score
       ) do
    performance_recommendations = []

    isk_efficiency_recommendations =
      if isk_eff < 0.6,
        do: ["Focus on target prioritization and ISK efficiency" | performance_recommendations],
        else: performance_recommendations

    kill_death_recommendations =
      if kd_score < 0.6,
        do: [
          "Improve engagement selection and fleet composition" | isk_efficiency_recommendations
        ],
        else: isk_efficiency_recommendations

    fleet_survival_recommendations =
      if survival_score < 0.7,
        do: ["Enhance logistics support and escape procedures" | kill_death_recommendations],
        else: kill_death_recommendations

    objective_focus_recommendations =
      if objective_score < 0.7,
        do: [
          "Better pre-engagement planning and objective focus" | fleet_survival_recommendations
        ],
        else: fleet_survival_recommendations

    optimization_recommendations =
      if tactical_score < 0.6,
        do: [
          "Work on fleet coordination and tactical execution" | objective_focus_recommendations
        ],
        else: objective_focus_recommendations

    if Enum.empty?(optimization_recommendations) do
      ["Continue current excellent performance"]
    else
      optimization_recommendations
    end
  end

  defp group_engagements_by_time(engagements, time_range) do
    bucket_size =
      case time_range do
        # Daily buckets
        :last_7d -> 1
        # Weekly buckets
        :last_30d -> 7
        # Bi-weekly buckets
        :last_90d -> 14
        # Default to weekly
        _ -> 7
      end

    # Group by time buckets (simplified implementation)
    now = DateTime.utc_now()

    Enum.group_by(engagements, fn engagement ->
      days_ago = DateTime.diff(now, engagement.timestamp, :day)
      div(days_ago, bucket_size)
    end)
  end

  defp calculate_trend_directions(trend_data) do
    if length(trend_data) >= 2 do
      # Last 3 periods
      recent = Enum.take(trend_data, 3)
      # Previous 3 periods
      earlier = Enum.take(trend_data, -3)

      %{
        isk_efficiency: calculate_metric_trend(recent, earlier, :isk_efficiency),
        kill_death_ratio: calculate_metric_trend(recent, earlier, :kill_death_ratio),
        survival_rate: calculate_metric_trend(recent, earlier, :survival_rate),
        fleet_size: calculate_metric_trend(recent, earlier, :average_fleet_size)
      }
    else
      %{
        isk_efficiency: :insufficient_data,
        kill_death_ratio: :insufficient_data,
        survival_rate: :insufficient_data,
        fleet_size: :insufficient_data
      }
    end
  end

  defp calculate_metric_trend(recent_data, earlier_data, metric) do
    recent_avg = Enum.sum(recent_data, &Map.get(&1, metric, 0)) / length(recent_data)
    earlier_avg = Enum.sum(earlier_data, &Map.get(&1, metric, 0)) / length(earlier_data)

    cond do
      recent_avg > earlier_avg * 1.1 -> :improving
      recent_avg < earlier_avg * 0.9 -> :declining
      true -> :stable
    end
  end

  defp calculate_overall_improvement_trend(trend_data) do
    if length(trend_data) >= 2 do
      first_period = List.last(trend_data)
      last_period = List.first(trend_data)

      # Calculate weighted improvement score
      isk_improvement = (last_period.isk_efficiency - first_period.isk_efficiency) * 0.4
      kd_improvement = (last_period.kill_death_ratio - first_period.kill_death_ratio) * 0.3
      survival_improvement = (last_period.survival_rate - first_period.survival_rate) * 0.3

      overall_improvement = isk_improvement + kd_improvement + survival_improvement

      cond do
        overall_improvement > 0.1 -> :significant_improvement
        overall_improvement > 0.05 -> :moderate_improvement
        overall_improvement > -0.05 -> :stable
        overall_improvement > -0.1 -> :moderate_decline
        true -> :significant_decline
      end
    else
      :insufficient_data
    end
  end

  defp generate_trend_recommendations(trends) do
    trend_recommendations = []

    isk_efficiency_trend_recommendations =
      if trends.isk_efficiency == :declining,
        do: ["Review target selection strategies" | trend_recommendations],
        else: trend_recommendations

    kill_death_trend_recommendations =
      if trends.kill_death_ratio == :declining,
        do: [
          "Analyze recent losses for tactical improvements" | isk_efficiency_trend_recommendations
        ],
        else: isk_efficiency_trend_recommendations

    comprehensive_trend_recommendations =
      if trends.survival_rate == :declining,
        do: ["Strengthen logistics and escape procedures" | kill_death_trend_recommendations],
        else: kill_death_trend_recommendations

    if Enum.empty?(comprehensive_trend_recommendations) do
      ["Maintain current performance levels"]
    else
      comprehensive_trend_recommendations
    end
  end

  # Additional helper functions for loss analysis

  defp analyze_temporal_clustering(loss_times) do
    # Simplified temporal clustering analysis
    if length(loss_times) <= 1 do
      :no_pattern
    else
      time_gaps =
        loss_times
        |> Enum.zip(tl(loss_times))
        |> Enum.map(fn {t1, t2} -> DateTime.diff(t2, t1, :second) end)

      avg_gap = Enum.sum(time_gaps) / length(time_gaps)

      cond do
        # Losses within 1 minute
        avg_gap < 60 -> :rapid_cascade
        # Losses within 5 minutes
        avg_gap < 300 -> :clustered
        true -> :scattered
      end
    end
  end

  defp identify_vulnerable_ship_types(lost_ship_types) do
    total_losses = Enum.sum(Map.values(lost_ship_types))

    lost_ship_types
    |> Enum.filter(fn {_ship_type, count} ->
      # Ship types representing >30% of losses
      count / total_losses > 0.3
    end)
    |> Enum.map(fn {ship_type, count} ->
      %{ship_type: ship_type, losses: count, percentage: count / total_losses * 100}
    end)
  end

  defp analyze_damage_patterns(fleet_losses) do
    damage_sources =
      fleet_losses
      |> Enum.flat_map(fn loss ->
        Enum.map(loss.attackers, & &1.weapon_type_id)
      end)
      |> Enum.frequencies()

    %{
      common_damage_sources: damage_sources,
      alpha_strike_losses: count_alpha_strike_losses(fleet_losses),
      sustained_damage_losses: count_sustained_damage_losses(fleet_losses)
    }
  end

  defp count_alpha_strike_losses(fleet_losses) do
    # Count losses where victim took >50% damage from single source
    Enum.count(fleet_losses, fn loss ->
      total_damage = loss.victim.damage_taken || 1

      max_single_damage =
        Enum.max_by(loss.attackers, & &1.damage_done, fn -> %{damage_done: 0} end).damage_done ||
          0

      max_single_damage / total_damage > 0.5
    end)
  end

  defp count_sustained_damage_losses(fleet_losses) do
    # Count losses with many attackers (sustained damage)
    Enum.count(fleet_losses, fn loss ->
      length(loss.attackers) > 5
    end)
  end

  defp determine_ship_role(ship_type_id) do
    # Simplified role determination based on ship type
    case rem(ship_type_id, 10) do
      0..2 -> :tackle
      3..4 -> :dps
      5..6 -> if rem(ship_type_id, 3) == 0, do: :logistics, else: :dps
      7 -> :command
      8 -> :dps
      9 -> :capital
    end
  end

  defp calculate_capability_reduction(role_impact, participants) do
    total_participants = length(participants)

    Enum.reduce(role_impact, %{}, fn {role, losses}, acc ->
      current_role_count =
        Enum.count(participants, fn p ->
          determine_ship_role(p.ship_type_id) == role
        end)

      reduction_percentage =
        if current_role_count > 0 do
          losses / current_role_count * 100
        else
          0
        end

      Map.put(acc, role, Float.round(reduction_percentage, 1))
    end)
  end

  defp calculate_damage_spread(fleet_attackers) do
    # Simplified damage spread calculation
    damage_values = Enum.map(fleet_attackers, &(&1.damage_done || 0))

    if length(damage_values) > 1 do
      avg_damage = Enum.sum(damage_values) / length(damage_values)

      variance =
        Enum.sum(damage_values, fn damage ->
          :math.pow(damage - avg_damage, 2)
        end) / length(damage_values)

      # Normalize variance to 0-1 scale
      normalized_variance = min(1.0, variance / (avg_damage * avg_damage))
      normalized_variance
    else
      0.0
    end
  end

  defp identify_high_risk_factors(fleet_losses, participants) do
    risk_factors = []

    # High value targets lost
    high_value_losses =
      Enum.filter(fleet_losses, fn loss ->
        # >100M ISK
        (loss.zkb_total_value || 0) > 100_000_000
      end)

    value_based_risk_factors =
      if length(high_value_losses) > 0 do
        [
          %{
            type: :high_value_targets,
            description: "#{length(high_value_losses)} high-value ships lost",
            risk_level: :high
          }
          | risk_factors
        ]
      else
        risk_factors
      end

    # Logistics losses
    logistics_losses =
      Enum.filter(fleet_losses, fn loss ->
        determine_ship_role(loss.victim.ship_type_id) == :logistics
      end)

    comprehensive_risk_factors =
      if length(logistics_losses) > 0 do
        [
          %{
            type: :logistics_vulnerability,
            description: "#{length(logistics_losses)} logistics ships lost",
            risk_level: :critical
          }
          | value_based_risk_factors
        ]
      else
        value_based_risk_factors
      end

    comprehensive_risk_factors
  end

  defp generate_loss_prevention_recommendations(loss_patterns, loss_causes) do
    prevention_recommendations = []

    # Temporal pattern recommendations
    temporal_prevention_recommendations =
      case loss_patterns.temporal_clustering do
        :rapid_cascade ->
          [
            "Implement emergency extraction procedures to prevent cascading losses"
            | prevention_recommendations
          ]

        :clustered ->
          [
            "Improve fleet positioning to avoid concentrated losses"
            | prevention_recommendations
          ]

        _ ->
          prevention_recommendations
      end

    # Damage pattern recommendations
    tactical_prevention_recommendations =
      if loss_patterns.damage_patterns.alpha_strike_losses > 0 do
        [
          "Consider buffer tanking and range management to avoid alpha strikes"
          | temporal_prevention_recommendations
        ]
      else
        temporal_prevention_recommendations
      end

    # Loss cause recommendations
    comprehensive_prevention_recommendations =
      case Map.get(loss_causes, :solo_gank, 0) do
        count when count > 0 ->
          ["Implement buddy system to prevent solo ganking" | tactical_prevention_recommendations]

        _ ->
          tactical_prevention_recommendations
      end

    if Enum.empty?(comprehensive_prevention_recommendations) do
      ["Current loss patterns are within acceptable parameters"]
    else
      comprehensive_prevention_recommendations
    end
  end
end
