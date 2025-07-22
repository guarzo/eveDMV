defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Engines.FleetComparisonEngine do
  @moduledoc """
  Engine for comparing fleet compositions and battle effectiveness across multiple engagements.

  Provides comprehensive analysis of:
  - Fleet effectiveness trends over time
  - Doctrine usage patterns and evolution
  - Cross-battle comparison metrics
  - Strategic impact assessment
  """

  require Logger

  @doc """
  Compare effectiveness trends across multiple battle analyses.
  """
  def compare_effectiveness_trends(battle_analyses) do
    if length(battle_analyses) < 2 do
      %{trend: :insufficient_data}
    else
      # Extract effectiveness metrics from each battle
      effectiveness_data =
        Enum.with_index(battle_analyses)
    Enum.map(fn {analysis, index} ->
          %{
            battle_index: index,
            timestamp: extract_battle_timestamp(analysis),
            kill_efficiency: extract_kill_efficiency(analysis),
            isk_efficiency: extract_isk_efficiency(analysis),
            tactical_success: calculate_tactical_success(analysis),
            strategic_impact: calculate_strategic_impact(analysis)
          }
        end)

      # Calculate trends
      kill_efficiency_trend = calculate_metric_trend(effectiveness_data, :kill_efficiency)
      isk_efficiency_trend = calculate_metric_trend(effectiveness_data, :isk_efficiency)
      tactical_trend = calculate_metric_trend(effectiveness_data, :tactical_success)
      strategic_trend = calculate_metric_trend(effectiveness_data, :strategic_impact)

      %{
        timeline: effectiveness_data,
        kill_efficiency_trend: kill_efficiency_trend,
        isk_efficiency_trend: isk_efficiency_trend,
        tactical_success_trend: tactical_trend,
        strategic_impact_trend: strategic_trend,
        overall_effectiveness_direction:
          determine_overall_effectiveness_trend([
            kill_efficiency_trend,
            isk_efficiency_trend,
            tactical_trend,
            strategic_trend
          ])
      }
    end
  end

  @doc """
  Compare doctrine usage patterns across multiple battles.
  """
  def compare_doctrine_usage(battle_analyses) do
    if length(battle_analyses) < 2 do
      %{comparison: :insufficient_data}
    else
      # Extract doctrine data from each battle
      doctrine_timeline =
        Enum.with_index(battle_analyses)
    Enum.map(fn {analysis, index} ->
          doctrines = extract_doctrines_from_battle(analysis)

          %{
            battle_index: index,
            timestamp: extract_battle_timestamp(analysis),
            primary_doctrines: doctrines,
            doctrine_count: length(doctrines),
            doctrine_diversity: calculate_doctrine_diversity(doctrines),
            dominant_doctrine: find_dominant_doctrine(doctrines)
          }
        end)

      # Analyze doctrine evolution
      doctrine_stability = calculate_doctrine_usage_stability(doctrine_timeline)
      doctrine_effectiveness = analyze_doctrine_effectiveness(doctrine_timeline, battle_analyses)

      %{
        timeline: doctrine_timeline,
        stability_score: doctrine_stability,
        effectiveness_analysis: doctrine_effectiveness,
        most_used_doctrines: identify_most_used_doctrines(doctrine_timeline),
        doctrine_success_rates:
          calculate_doctrine_success_rates(doctrine_timeline, battle_analyses),
        evolution_pattern: determine_doctrine_evolution_pattern(doctrine_timeline)
      }
    end
  end

  @doc """
  Analyze fleet strength comparison between opposing sides.
  """
  def compare_fleet_strengths(side_a, side_b) do
    %{
      numerical_advantage: calculate_numerical_advantage(side_a, side_b),
      firepower_comparison: compare_firepower(side_a, side_b),
      support_comparison: compare_support_capabilities(side_a, side_b),
      mobility_comparison: compare_mobility(side_a, side_b),
      overall_assessment: determine_overall_fleet_advantage(side_a, side_b)
    }
  end

  # Private helper functions

  defp extract_battle_timestamp(analysis) do
    get_in(analysis, [:timeline_analysis, :start_time]) ||
      get_in(analysis, [:metadata, :timestamp]) || |> DateTime.utc_now()
  end

  defp extract_kill_efficiency(analysis) do
    get_in(analysis, [:outcome_analysis, :kill_efficiency]) || 0.5
  end

  defp extract_isk_efficiency(analysis) do
    get_in(analysis, [:outcome_analysis, :isk_efficiency]) || 0.5
  end

  defp calculate_tactical_success(analysis) do
    # Combine multiple tactical factors
    patterns = get_in(analysis, [:tactical_analysis, :patterns]) || []
    coordination = get_in(analysis, [:tactical_analysis, :coordination_score]) || 0.5

    pattern_score = if Enum.any?(patterns, &(&1.confidence > 70)), do: 0.8, else: 0.5
    (pattern_score + coordination) / 2
  end

  defp calculate_strategic_impact(analysis) do
    # Assess strategic importance of the battle
    participants = get_in(analysis, [:fleet_analysis, :total_participants]) || 0
    isk_value = get_in(analysis, [:outcome_analysis, :total_isk_destroyed]) || 0

    # Normalize to 0-1 scale
    participant_score = min(participants / 100, 1.0)
    isk_score = min(isk_value / 10_000_000_000, 1.0)

    (participant_score + isk_score) / 2
  end

  defp calculate_metric_trend(data, metric_key) do
    if length(data) < 2 do
      %{trend: :insufficient_data, change: 0}
    else
      values = Enum.map(data, &Map.get(&1, metric_key, 0))

      recent = values |> Enum.take(3) |> average()
      older = values |> Enum.drop(3) |> Enum.take(3) |> average()

      change = if older > 0, do: (recent - older) / older, else: 0

      trend =
        cond do
          change > 0.1 -> :improving
          change < -0.1 -> :declining
          true -> :stable
        end

      %{trend: trend, change: Float.round(change * 100, 1)}
    end
  end

  defp determine_overall_effectiveness_trend(trend_list) do
    improving_count = Enum.count(trend_list, &(&1[:trend] == :improving))
    declining_count = Enum.count(trend_list, &(&1[:trend] == :declining))

    cond do
      improving_count > declining_count -> :improving
      declining_count > improving_count -> :declining
      true -> :stable
    end
  end

  defp extract_doctrines_from_battle(analysis) do
    get_in(analysis, [:fleet_analysis, :doctrines]) || []
  end

  defp calculate_doctrine_diversity(doctrines) do
    if Enum.empty?(doctrines) do
      0.0
    else
      unique_doctrines = doctrines |> Enum.map(& &1.name) |> Enum.uniq()
      Float.round(length(unique_doctrines) / length(doctrines), 2)
    end
  end

  defp find_dominant_doctrine(doctrines) do
    if Enum.empty?(doctrines) do
      nil
    else
      doctrines
    Enum.group_by(& &1.name)
    Enum.max_by(fn {_name, group} -> length(group) end)
    elem(0)
    end
  end

  defp calculate_doctrine_usage_stability(timeline) do
    if length(timeline) < 2 do
      1.0
    else
      dominant_doctrines = Enum.map(timeline, & &1.dominant_doctrine)
      unique_dominants = Enum.uniq(dominant_doctrines)

      # More consistent doctrine usage = higher stability
      stability = 1.0 - (length(unique_dominants) - 1) / length(timeline)
      Float.round(max(stability, 0.0), 2)
    end
  end

  defp analyze_doctrine_effectiveness(timeline, battle_analyses) do
    # Correlate doctrine usage with battle outcomes
    doctrine_outcomes =
      timeline
    Enum.zip(battle_analyses)
    Enum.group_by(fn {timeline_entry, _analysis} ->
        timeline_entry.dominant_doctrine
      end)
    Enum.map(fn {doctrine, battles} ->
        win_rate = calculate_doctrine_win_rate(battles)
        %{doctrine: doctrine, win_rate: win_rate, sample_size: length(battles)}
      end)

    %{doctrine_performance: doctrine_outcomes}
  end

  defp calculate_doctrine_win_rate(battle_pairs) do
    if Enum.empty?(battle_pairs) do
      0.0
    else
      wins =
        Enum.count(battle_pairs, fn {_timeline, analysis} ->
          get_in(analysis, [:outcome_analysis, :victor]) != nil
        end)

      Float.round(wins / length(battle_pairs), 2)
    end
  end

  defp identify_most_used_doctrines(timeline) do
    timeline
    Enum.flat_map(& &1.primary_doctrines)
    Enum.frequencies_by(& &1.name)
    Enum.sort_by(&elem(&1, 1), :desc)
    Enum.take(5)
  end

  defp calculate_doctrine_success_rates(timeline, battle_analyses) do
    timeline
    Enum.zip(battle_analyses)
    Enum.group_by(fn {timeline_entry, _} -> timeline_entry.dominant_doctrine end)
    Enum.map(fn {doctrine, battles} ->
      success_rate = calculate_doctrine_win_rate(battles)
      {doctrine, success_rate}
    end) |> Map.new()
  end

  defp determine_doctrine_evolution_pattern(timeline) do
    if length(timeline) < 3 do
      :insufficient_data
    else
      diversity_trend =
        timeline
    Enum.map(& &1.doctrine_diversity)
    calculate_simple_trend()

      case diversity_trend do
        :increasing -> :diversifying
        :decreasing -> :consolidating
        :stable -> :stable
      end
    end
  end

  defp calculate_simple_trend(values) do
    if length(values) < 2 do
      :stable
    else
      recent = values |> Enum.take(div(length(values), 2)) |> average()
      older = values |> Enum.drop(div(length(values), 2)) |> average()

      cond do
        recent > older * 1.1 -> :increasing
        recent < older * 0.9 -> :decreasing
        true -> :stable
      end
    end
  end

  defp calculate_numerical_advantage(side_a, side_b) do
    count_a = get_in(side_a, [:total_participants]) || 0
    count_b = get_in(side_b, [:total_participants]) || 0

    if count_b > 0 do
      Float.round(count_a / count_b, 2)
    else
      if count_a > 0, do: 999.0, else: 1.0
    end
  end

  defp compare_firepower(side_a, side_b) do
    dps_a = estimate_fleet_dps(side_a)
    dps_b = estimate_fleet_dps(side_b)

    %{
      side_a_dps: dps_a,
      side_b_dps: dps_b,
      advantage_ratio: if(dps_b > 0, do: Float.round(dps_a / dps_b, 2), else: 999.0)
    }
  end

  defp compare_support_capabilities(side_a, side_b) do
    %{
      side_a_logistics: count_logistics_ships(side_a),
      side_b_logistics: count_logistics_ships(side_b),
      side_a_ewar: count_ewar_ships(side_a),
      side_b_ewar: count_ewar_ships(side_b)
    }
  end

  defp compare_mobility(side_a, side_b) do
    %{
      side_a_avg_speed: estimate_fleet_speed(side_a),
      side_b_avg_speed: estimate_fleet_speed(side_b),
      side_a_tackle: count_tackle_ships(side_a),
      side_b_tackle: count_tackle_ships(side_b)
    }
  end

  defp determine_overall_fleet_advantage(side_a, side_b) do
    numerical = calculate_numerical_advantage(side_a, side_b)
    firepower = compare_firepower(side_a, side_b)

    # Simple scoring system
    score_a = numerical + firepower.advantage_ratio

    cond do
      score_a > 1.5 -> :side_a_advantage
      score_a < 0.67 -> :side_b_advantage
      true -> :balanced
    end
  end

  # Fleet estimation helpers
  defp estimate_fleet_dps(side) do
    # Simple DPS estimation based on ship counts and types
    participants = get_in(side, [:total_participants]) || 0
    # Rough average DPS per ship
    participants * 400
  end

  defp count_logistics_ships(side) do
    get_in(side, [:ship_classes, :logistics]) || 0
  end

  defp count_ewar_ships(side) do
    recon = get_in(side, [:ship_classes, :recon]) || 0
    ewar = get_in(side, [:ship_classes, :ewar]) || 0
    recon + ewar
  end

  defp count_tackle_ships(side) do
    get_in(side, [:ship_classes, :tackle]) || 0
  end

  defp estimate_fleet_speed(side) do
    # Simple speed estimation based on ship composition
    total = get_in(side, [:total_participants]) || 1
    frigates = get_in(side, [:ship_classes, :frigate]) || 0
    capitals = get_in(side, [:ship_classes, :capital]) || 0

    # Weighted average speed (m/s)
    (frigates * 3000 + (total - frigates - capitals) * 1500 + capitals * 500) / total
  end

  defp average(list) when is_list(list) and length(list) > 0 do
    Enum.sum(list) / length(list)
  end

  defp average(_), do: 0.0
end
