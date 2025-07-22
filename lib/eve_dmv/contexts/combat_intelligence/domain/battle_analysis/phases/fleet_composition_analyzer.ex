defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Phases.FleetCompositionAnalyzer do
  @moduledoc """
  Fleet composition analyzer for analyzing fleet compositions and their effectiveness.

  This module serves as the main coordinator for fleet composition analysis,
  delegating specific tasks to specialized analyzer modules for better maintainability.
  """

  require Logger

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.ShipClassificationAnalyzer

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.FleetEffectivenessAnalyzer

  @doc """
  Analyze fleet compositions from participant data.
  """
  def analyze_fleet_compositions(participants, killmails) do
    Logger.debug("Analyzing fleet compositions for #{length(participants)} participants")

    # Classify participants by side
    sides = classify_participants_by_side(participants)

    # Analyze each side's composition
    side_a_analysis = analyze_side_composition(sides.side_a)
    side_b_analysis = analyze_side_composition(sides.side_b)

    # Compare fleet compositions
    composition_comparison = compare_fleet_compositions(side_a_analysis, side_b_analysis)

    # Analyze effectiveness using killmail data
    effectiveness_analysis = analyze_composition_effectiveness(sides, killmails)

    # Generate comprehensive analysis
    %{
      side_a: side_a_analysis,
      side_b: side_b_analysis,
      composition_comparison: composition_comparison,
      effectiveness_analysis: effectiveness_analysis,
      battle_summary: generate_battle_summary(side_a_analysis, side_b_analysis, killmails)
    }
  end

  @doc """
  Analyze ship class performance in battle.
  """
  def analyze_ship_class_performance(killmails, participants) do
    Logger.debug("Analyzing ship class performance")

    ship_classes = ShipClassificationAnalyzer.classify_ships_by_class(participants)

    # Performance metrics per ship class
    performance_analysis =
      ship_classes

    Enum.map(fn {ship_class, count} ->
      class_participants =
        Enum.filter(
          participants,
          &(ShipClassificationAnalyzer.classify_ship_role(&1) == ship_class)
        )

      performance_metrics =
        calculate_ship_class_performance(ship_class, class_participants, killmails)

      {ship_class, performance_metrics}
    end)

    Enum.into(%{})

    # Cross-class interaction analysis
    interaction_analysis = analyze_cross_class_interactions(performance_analysis, killmails)

    # Performance trends
    trend_analysis = analyze_performance_trends(performance_analysis, killmails)

    # Overall statistics
    overall_stats = calculate_overall_statistics(performance_analysis)

    %{
      ship_class_performance: performance_analysis,
      cross_class_interactions: interaction_analysis,
      performance_trends: trend_analysis,
      overall_statistics: overall_stats
    }
  end

  @doc """
  Analyze fleet composition gaps and optimization opportunities.
  """
  def analyze_fleet_composition_gaps(fleet_compositions) do
    Logger.debug("Analyzing fleet composition gaps")

    # Identify missing roles and imbalances
    missing_roles = identify_missing_roles(fleet_compositions)
    role_imbalances = identify_role_imbalances(fleet_compositions)

    # Generate optimization suggestions
    optimization_suggestions = generate_optimization_suggestions(fleet_compositions)

    # Identify synergy opportunities
    synergy_opportunities = identify_synergy_opportunities(fleet_compositions)

    %{
      missing_roles: missing_roles,
      role_imbalances: role_imbalances,
      optimization_suggestions: optimization_suggestions,
      synergy_opportunities: synergy_opportunities
    }
  end

  @doc """
  Analyze strategic positioning effectiveness.
  """
  def analyze_strategic_positioning(battle_analysis) do
    Logger.debug("Analyzing strategic positioning")

    participants = get_participants_from_battle_analysis(battle_analysis)
    killmails = get_killmails_from_battle_analysis(battle_analysis)

    # Calculate positioning effectiveness
    positioning_effectiveness = calculate_positioning_effectiveness(participants, killmails)

    # Analyze range control
    range_control = analyze_range_control(participants, killmails)

    # Analyze tactical positioning
    tactical_positioning = analyze_tactical_positioning_effectiveness(participants, killmails)

    # Generate positioning recommendations
    recommendations =
      generate_positioning_recommendations(
        positioning_effectiveness,
        range_control,
        tactical_positioning
      )

    %{
      positioning_effectiveness: positioning_effectiveness,
      range_control: range_control,
      tactical_positioning: tactical_positioning,
      recommendations: recommendations
    }
  end

  @doc """
  Analyze enhanced fleet composition from ship list.
  """
  def analyze_enhanced_fleet_composition(ship_list) when is_list(ship_list) do
    Logger.debug("Analyzing enhanced fleet composition for #{length(ship_list)} ships")

    participants = ShipClassificationAnalyzer.convert_ships_to_participants(ship_list)

    # Basic composition analysis using extracted modules
    role_distribution = ShipClassificationAnalyzer.calculate_role_distribution(participants)
    effectiveness = FleetEffectivenessAnalyzer.estimate_fleet_effectiveness(participants)
    synergy = FleetEffectivenessAnalyzer.calculate_fleet_synergy(participants)
    balance = FleetEffectivenessAnalyzer.analyze_composition_balance(role_distribution)

    %{
      fleet_size: length(participants),
      role_distribution: role_distribution,
      effectiveness: effectiveness,
      synergy: synergy,
      balance: balance,
      fleet_strength: FleetEffectivenessAnalyzer.calculate_fleet_strength(participants)
    }
  end

  # Private helper functions - streamlined versions that delegate to extracted modules

  defp classify_participants_by_side(participants) do
    # Simple side classification - can be enhanced later
    total = length(participants)
    half = div(total, 2)

    {side_a, side_b} = Enum.split(participants, half)

    %{
      side_a: side_a,
      side_b: side_b
    }
  end

  defp analyze_side_composition(side_participants) do
    if Enum.empty?(side_participants) do
      %{
        participant_count: 0,
        role_distribution: %{},
        effectiveness: %{overall: 0.0},
        synergy: %{overall: 0.0},
        doctrine_adherence: %{score: 0.0}
      }
    else
      role_distribution =
        ShipClassificationAnalyzer.calculate_role_distribution(side_participants)

      effectiveness = FleetEffectivenessAnalyzer.estimate_fleet_effectiveness(side_participants)
      synergy = FleetEffectivenessAnalyzer.calculate_fleet_synergy(side_participants)

      doctrine_adherence =
        FleetEffectivenessAnalyzer.calculate_doctrine_adherence(side_participants)

      %{
        participant_count: length(side_participants),
        role_distribution: role_distribution,
        effectiveness: effectiveness,
        synergy: synergy,
        doctrine_adherence: doctrine_adherence,
        fleet_strength: FleetEffectivenessAnalyzer.calculate_fleet_strength(side_participants)
      }
    end
  end

  defp compare_fleet_compositions(side_a_analysis, side_b_analysis) do
    %{
      numerical_advantage:
        calculate_numerical_advantage(
          side_a_analysis.participant_count,
          side_b_analysis.participant_count
        ),
      effectiveness_comparison: %{
        side_a: side_a_analysis.effectiveness.overall,
        side_b: side_b_analysis.effectiveness.overall,
        advantage:
          determine_advantage(
            side_a_analysis.effectiveness.overall,
            side_b_analysis.effectiveness.overall
          )
      },
      synergy_comparison: %{
        side_a: side_a_analysis.synergy.overall,
        side_b: side_b_analysis.synergy.overall,
        advantage:
          determine_advantage(side_a_analysis.synergy.overall, side_b_analysis.synergy.overall)
      }
    }
  end

  defp analyze_composition_effectiveness(sides, killmails) do
    side_a_effectiveness = calculate_side_effectiveness(sides.side_a, killmails)
    side_b_effectiveness = calculate_side_effectiveness(sides.side_b, killmails)

    %{
      side_a: side_a_effectiveness,
      side_b: side_b_effectiveness,
      overall_winner: determine_overall_winner(side_a_effectiveness, side_b_effectiveness)
    }
  end

  defp calculate_ship_class_performance(ship_class, ships, killmails) do
    if Enum.empty?(ships) do
      %{
        survival_rate: 0.0,
        kill_participation: 0.0,
        effectiveness_score: 0.0,
        performance_grade: :no_data
      }
    else
      survival_rate = FleetEffectivenessAnalyzer.calculate_survival_rate(ships, killmails)
      kill_participation = calculate_kill_participation(ships, killmails)
      effectiveness_score = calculate_effectiveness_score(ships, killmails)

      %{
        ship_count: length(ships),
        survival_rate: survival_rate,
        kill_participation: kill_participation,
        effectiveness_score: effectiveness_score,
        performance_grade: grade_performance(effectiveness_score, survival_rate)
      }
    end
  end

  defp generate_battle_summary(side_a_analysis, side_b_analysis, killmails) do
    total_participants = side_a_analysis.participant_count + side_b_analysis.participant_count

    %{
      battle_scale: determine_battle_scale(total_participants),
      battle_intensity: calculate_battle_intensity(killmails, total_participants),
      dominant_side: determine_dominant_side(side_a_analysis, side_b_analysis),
      key_factors: identify_key_battle_factors(side_a_analysis, side_b_analysis, killmails)
    }
  end

  # Placeholder implementations for remaining functions
  defp identify_missing_roles(_fleet_compositions), do: []
  defp identify_role_imbalances(_fleet_compositions), do: []
  defp generate_optimization_suggestions(_fleet_compositions), do: []
  defp identify_synergy_opportunities(_fleet_compositions), do: []

  defp get_participants_from_battle_analysis(battle_analysis),
    do: battle_analysis[:participants] || []

  defp get_killmails_from_battle_analysis(battle_analysis), do: battle_analysis[:killmails] || []

  defp calculate_positioning_effectiveness(_participants, _killmails), do: %{score: 0.5}
  defp analyze_range_control(_participants, _killmails), do: %{control_rating: :moderate}

  defp analyze_tactical_positioning_effectiveness(_participants, _killmails),
    do: %{effectiveness: 0.5}

  defp generate_positioning_recommendations(_pos_eff, _range_ctrl, _tact_pos), do: []

  defp calculate_numerical_advantage(side_a_count, side_b_count) do
    if side_b_count == 0, do: :overwhelming_a

    ratio = side_a_count / side_b_count

    cond do
      ratio >= 2.0 -> :significant_a
      ratio >= 1.5 -> :moderate_a
      ratio >= 1.1 -> :slight_a
      ratio >= 0.9 -> :balanced
      ratio >= 0.67 -> :slight_b
      ratio >= 0.5 -> :moderate_b
      true -> :significant_b
    end
  end

  defp determine_advantage(value_a, value_b) do
    diff = value_a - value_b

    cond do
      diff >= 0.2 -> :side_a
      diff <= -0.2 -> :side_b
      true -> :balanced
    end
  end

  defp calculate_side_effectiveness(_side_participants, _killmails), do: %{score: 0.5}
  defp determine_overall_winner(_side_a_eff, _side_b_eff), do: :inconclusive

  defp calculate_kill_participation(_ships, _killmails), do: 0.5
  defp calculate_effectiveness_score(_ships, _killmails), do: 0.5

  defp grade_performance(effectiveness_score, survival_rate) do
    combined_score = (effectiveness_score + survival_rate) / 2

    cond do
      combined_score >= 0.8 -> :excellent
      combined_score >= 0.6 -> :good
      combined_score >= 0.4 -> :fair
      combined_score >= 0.2 -> :poor
      true -> :very_poor
    end
  end

  defp analyze_cross_class_interactions(_performance_analysis, _killmails), do: %{}
  defp analyze_performance_trends(_performance_analysis, _killmails), do: %{}

  defp calculate_overall_statistics(performance_analysis),
    do: %{ship_classes: map_size(performance_analysis)}

  defp determine_battle_scale(total_participants) do
    cond do
      total_participants >= 500 -> :massive
      total_participants >= 200 -> :large
      total_participants >= 100 -> :medium
      total_participants >= 50 -> :small
      true -> :skirmish
    end
  end

  defp calculate_battle_intensity(killmails, total_participants) do
    if total_participants > 0 do
      length(killmails) / total_participants
    else
      0.0
    end
  end

  defp determine_dominant_side(side_a_analysis, side_b_analysis) do
    if side_a_analysis.effectiveness.overall > side_b_analysis.effectiveness.overall do
      :side_a
    else
      :side_b
    end
  end

  defp identify_key_battle_factors(_side_a_analysis, _side_b_analysis, _killmails), do: []
end
