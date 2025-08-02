defmodule EveDmv.Contexts.FleetOperations.Domain.EffectivenessCalculator do
  @moduledoc """
  Fleet effectiveness calculation engine.

  Provides comprehensive metrics for fleet performance analysis,
  including damage efficiency, survival rates, and tactical effectiveness.
  """

  alias EveDmv.Core.Utils.DateTimeUtils
  """

  use EveDmv.ErrorHandler

  require Logger

  # Effectiveness weights for different metrics
  # Currently unused as full fleet effectiveness calculation is not implemented
  # @effectiveness_weights %{
  #   isk_efficiency: 0.3,
  #   kill_death_ratio: 0.25,
  #   survival_rate: 0.2,
  #   objective_completion: 0.15,
  #   tactical_execution: 0.1
  # }

  @doc """
  Calculate comprehensive fleet effectiveness metrics.

  Currently returns minimal effectiveness data as fleet engagement tracking is not fully implemented.
  """
  def calculate_fleet_effectiveness(_fleet_id) do
    {:error, :no_engagement_data}
  end

  @doc """
  Calculate performance trends for a corporation over time.

  Currently returns minimal trend data as fleet engagement tracking is not fully implemented.
  """
  def calculate_performance_trends(_corporation_id, _time_range \\ :last_90d) do
    {:error, :no_engagement_data}
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
    total_isk_lost = Enum.sum(Enum.map(fleet_losses, &(&1.zkb_total_value || 0)))

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
        if(Enum.empty?(fleet_losses), do: 0, else: total_isk_lost / length(fleet_losses)),
      role_impact: role_impact,
      fleet_capability_reduction: calculate_capability_reduction(role_impact, participants)
    }
  end

  defp calculate_total_damage_dealt(participants, killmails) do
    participant_ids = MapSet.new(participants, & &1.character_id)

    killmails
    |> Enum.map(fn killmail ->
      # Sum damage dealt by fleet members in this killmail
      Enum.sum(
        Enum.map(killmail.attackers, fn attacker ->
          if MapSet.member?(participant_ids, attacker.character_id) do
            attacker.damage_done || 0
          else
            0
          end
        end)
      )
    end)
    |> Enum.sum()
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
      if Enum.empty?(participation_rates) do
        0.0
      else
        Enum.sum(participation_rates) / length(participation_rates)
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
      if Enum.empty?(kill_windows) do
        0.0
      else
        Enum.sum(kill_windows) / length(kill_windows)
      end

    %{
      sync_score: Float.round(sync_score, 3),
      synchronized_kills: Enum.count(kill_windows, &(&1 > 0.7))
    }
  end

  # Helper functions

  defp determine_coordination_grade(coordination_score) do
    cond do
      coordination_score >= 0.8 -> :excellent
      coordination_score >= 0.6 -> :good
      coordination_score >= 0.4 -> :average
      true -> :poor
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
        |> Enum.map(fn {t1, t2} -> DateTimeUtils.diff(t2, t1, :second) end)

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
    # Determine role based on actual ship class from static data
    case EveDmv.StaticData.get_ship_class(ship_type_id) do
      :interceptor ->
        :tackle

      :interdictor ->
        :tackle

      :heavy_interdictor ->
        :tackle

      :logistics_frigate ->
        :logistics

      :logistics_cruiser ->
        :logistics

      :force_recon ->
        :ewar

      :combat_recon ->
        :ewar

      :electronic_attack_frigate ->
        :ewar

      :command_destroyer ->
        :command

      :command_battlecruiser ->
        :command

      ship_class
      when ship_class in [:frigate, :destroyer, :cruiser, :battlecruiser, :battleship] ->
        :dps

      :assault_frigate ->
        :dps

      :heavy_assault_cruiser ->
        :dps

      :marauder ->
        :dps

      :black_ops ->
        :dps

      :dreadnought ->
        :dps

      :carrier ->
        :support

      :supercarrier ->
        :support

      :titan ->
        :dps

      # Default to DPS for unknown ships
      _ ->
        :dps
    end
  end

  defp calculate_capability_reduction(role_impact, participants) do
    _total_participants = length(participants)

    role_impact
    |> Enum.reduce(%{}, fn {role, losses}, acc ->
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
        Enum.sum(
          Enum.map(damage_values, fn damage ->
            :math.pow(damage - avg_damage, 2)
          end)
        ) / length(damage_values)

      # Normalize variance to 0-1 scale
      normalized_variance = min(1.0, variance / (avg_damage * avg_damage))
      normalized_variance
    else
      0.0
    end
  end

  defp identify_high_risk_factors(fleet_losses, _participants) do
    risk_factors = []

    # High value targets lost
    high_value_losses =
      Enum.filter(fleet_losses, fn loss ->
        # >100M ISK
        (loss.zkb_total_value || 0) > 100_000_000
      end)

    value_based_risk_factors =
      if Enum.empty?(high_value_losses) do
        risk_factors
      else
        [
          %{
            type: :high_value_targets,
            description: "#{length(high_value_losses)} high-value ships lost",
            risk_level: :high
          }
          | risk_factors
        ]
      end

    # Logistics losses
    logistics_losses =
      Enum.filter(fleet_losses, fn loss ->
        determine_ship_role(loss.victim.ship_type_id) == :logistics
      end)

    comprehensive_risk_factors =
      if Enum.empty?(logistics_losses) do
        value_based_risk_factors
      else
        [
          %{
            type: :logistics_vulnerability,
            description: "#{length(logistics_losses)} logistics ships lost",
            risk_level: :critical
          }
          | value_based_risk_factors
        ]
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
