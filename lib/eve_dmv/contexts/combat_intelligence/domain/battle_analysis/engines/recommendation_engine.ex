defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Engines.RecommendationEngine do
  @moduledoc """
  Engine for generating tactical, strategic, doctrine, and training recommendations.

  Analyzes battle data to provide actionable recommendations for:
  - Tactical improvements based on battle patterns
  - Strategic positioning and fleet composition
  - Doctrine evolution and counter-strategies
  - Training focus areas and skill development
  """

  require Logger

  @doc """
  Generate comprehensive tactical recommendations from battle analysis.
  """
  def generate_tactical_recommendations(battle_analysis) do
    if valid_analysis?(battle_analysis) do
      perform_basic_tactical_recommendations(battle_analysis)
    else
      {:error, :insufficient_data}
    end
  end

  @doc """
  Generate strategic recommendations for fleet operations.
  """
  def generate_strategic_recommendations(battle_analysis) do
    if valid_analysis?(battle_analysis) do
      perform_basic_strategic_recommendations(battle_analysis)
    else
      {:error, :insufficient_data}
    end
  end

  @doc """
  Generate doctrine-specific recommendations.
  """
  def generate_doctrine_recommendations(battle_analysis) do
    if valid_analysis?(battle_analysis) do
      perform_basic_doctrine_recommendations(battle_analysis)
    else
      {:error, :insufficient_data}
    end
  end

  @doc """
  Generate training recommendations based on performance gaps.
  """
  def generate_training_recommendations(battle_analysis) do
    if valid_analysis?(battle_analysis) do
      perform_basic_training_recommendations(battle_analysis)
    else
      {:error, :insufficient_data}
    end
  end

  @doc """
  Generate recommendations from tactical patterns.
  """
  def generate_pattern_based_recommendations(patterns) do
    patterns
    |> Enum.flat_map(&pattern_to_recommendations/1)
    |> Enum.uniq()
    |> Enum.take(10)  # Limit to top 10 recommendations
  end

  # Private implementation functions

  defp valid_analysis?(battle_analysis) do
    case battle_analysis do
      %{fleet_analysis: %{}, tactical_analysis: %{}} -> true
      _ -> false
    end
  end

  defp perform_basic_tactical_recommendations(battle_analysis) do
    tactical_analysis = Map.get(battle_analysis, :tactical_analysis, %{})
    fleet_analysis = Map.get(battle_analysis, :fleet_analysis, %{})

    base_recommendations = [
      %{
        type: :tactical,
        priority: :medium,
        title: "Engagement Analysis",
        description: "Review tactical patterns and key moments",
        actions: ["Analyze engagement flow", "Study target selection patterns"]
      }
    ]

    # Add pattern-based recommendations
    pattern_recommendations =
      case Map.get(tactical_analysis, :patterns) do
        patterns when is_list(patterns) ->
          generate_pattern_based_recommendations(patterns)
          |> Enum.map(&tactical_pattern_to_recommendation/1)
        _ -> []
      end

    # Add fleet composition recommendations
    composition_recommendations = generate_fleet_composition_recommendations(fleet_analysis)

    (base_recommendations ++ pattern_recommendations ++ composition_recommendations)
    |> Enum.take(8)
  end

  defp perform_basic_strategic_recommendations(battle_analysis) do
    fleet_analysis = Map.get(battle_analysis, :fleet_analysis, %{})
    outcome_analysis = Map.get(battle_analysis, :outcome_analysis, %{})

    base_recommendations = [
      %{
        type: :strategic,
        priority: :high,
        title: "Strategic Position",
        description: "Optimize strategic positioning and engagement timing",
        actions: ["Review engagement windows", "Assess strategic objectives"]
      }
    ]

    # Add ISK efficiency recommendations
    isk_recommendations = generate_isk_efficiency_recommendations(outcome_analysis)

    # Add force multiplication recommendations
    force_mult_recommendations = generate_force_multiplication_recommendations(fleet_analysis)

    (base_recommendations ++ isk_recommendations ++ force_mult_recommendations)
    |> Enum.take(6)
  end

  defp perform_basic_doctrine_recommendations(battle_analysis) do
    fleet_analysis = Map.get(battle_analysis, :fleet_analysis, %{})

    base_recommendations = [
      %{
        type: :doctrine,
        priority: :medium,
        title: "Doctrine Evaluation",
        description: "Assess doctrine effectiveness and evolution",
        actions: ["Review current doctrine performance", "Consider doctrine adaptations"]
      }
    ]

    # Add counter-doctrine recommendations
    counter_recommendations = generate_counter_doctrine_recommendations(fleet_analysis)

    (base_recommendations ++ counter_recommendations)
    |> Enum.take(5)
  end

  defp perform_basic_training_recommendations(battle_analysis) do
    performance_metrics = Map.get(battle_analysis, :performance_metrics, %{})
    tactical_analysis = Map.get(battle_analysis, :tactical_analysis, %{})

    base_recommendations = [
      %{
        type: :training,
        priority: :medium,
        title: "Skill Development",
        description: "Focus training on identified performance gaps",
        actions: ["Assess pilot skill levels", "Prioritize training objectives"]
      }
    ]

    # Add performance gap recommendations
    gap_recommendations = generate_performance_gap_recommendations(performance_metrics)

    # Add tactical skill recommendations
    tactical_recommendations = generate_tactical_skill_recommendations(tactical_analysis)

    (base_recommendations ++ gap_recommendations ++ tactical_recommendations)
    |> Enum.take(7)
  end

  defp tactical_pattern_to_recommendation(pattern) do
    case pattern do
      %{name: :alpha_strike} ->
        %{
          type: :tactical,
          priority: :high,
          title: "Alpha Strike Defense",
          description: "Develop counter-alpha strategies",
          actions: ["Spread formation", "Pre-position logistics", "Use damage mitigation"]
        }

      %{name: :kiting} ->
        %{
          type: :tactical,
          priority: :medium,
          title: "Anti-Kiting Tactics",
          description: "Counter long-range kiting strategies",
          actions: ["Deploy fast tackle", "Use long-range weapons", "Control engagement range"]
        }

      %{name: :brawling} ->
        %{
          type: :tactical,
          priority: :medium,
          title: "Brawling Optimization",
          description: "Optimize close-range combat effectiveness",
          actions: ["Maximize DPS application", "Coordinate target calls", "Manage overheating"]
        }

      _ ->
        %{
          type: :tactical,
          priority: :low,
          title: "General Tactical Review",
          description: "Review engagement tactics",
          actions: ["Analyze battle footage", "Practice maneuvers"]
        }
    end
  end

  defp generate_fleet_composition_recommendations(fleet_analysis) do
    doctrines = Map.get(fleet_analysis, :doctrines, [])

    if Enum.empty?(doctrines) do
      [%{
        type: :tactical,
        priority: :medium,
        title: "Fleet Composition Analysis",
        description: "Establish doctrine analysis baseline",
        actions: ["Document current fleet compositions", "Analyze role distribution"]
      }]
    else
      [%{
        type: :tactical,
        priority: :high,
        title: "Doctrine Optimization",
        description: "Optimize fleet doctrine effectiveness",
        actions: ["Review doctrine performance metrics", "Consider composition adjustments"]
      }]
    end
  end

  defp generate_isk_efficiency_recommendations(outcome_analysis) do
    isk_efficiency = Map.get(outcome_analysis, :isk_efficiency, 1.0)

    if isk_efficiency < 0.8 do
      [%{
        type: :strategic,
        priority: :high,
        title: "ISK Efficiency Improvement",
        description: "Focus on high-value target selection",
        actions: ["Improve target prioritization", "Avoid wasteful engagements", "Optimize killmail values"]
      }]
    else
      []
    end
  end

  defp generate_force_multiplication_recommendations(fleet_analysis) do
    ewar_presence = Map.get(fleet_analysis, :ewar_presence, false)
    logistics_ratio = Map.get(fleet_analysis, :logistics_ratio, 0.0)

    recommendations = []

    recommendations = if not ewar_presence do
      [%{
        type: :strategic,
        priority: :medium,
        title: "Electronic Warfare Integration",
        description: "Add EWAR ships for force multiplication",
        actions: ["Deploy ECM/dampening ships", "Train EWAR pilots", "Coordinate EWAR tactics"]
      } | recommendations]
    else
      recommendations
    end

    recommendations = if logistics_ratio < 0.1 do
      [%{
        type: :strategic,
        priority: :high,
        title: "Logistics Support",
        description: "Increase logistics ship presence",
        actions: ["Add logistics ships", "Train logistics pilots", "Improve repair coordination"]
      } | recommendations]
    else
      recommendations
    end

    recommendations
  end

  defp generate_counter_doctrine_recommendations(fleet_analysis) do
    dominant_ships = Map.get(fleet_analysis, :dominant_ship_types, [])

    if Enum.empty?(dominant_ships) do
      []
    else
      [%{
        type: :doctrine,
        priority: :medium,
        title: "Counter-Doctrine Development",
        description: "Develop counters to enemy doctrines",
        actions: ["Analyze enemy ship preferences", "Design counter compositions", "Test counter-strategies"]
      }]
    end
  end

  defp generate_performance_gap_recommendations(performance_metrics) do
    by_side = Map.get(performance_metrics, :by_side, %{})

    if Enum.empty?(by_side) do
      []
    else
      [%{
        type: :training,
        priority: :medium,
        title: "Performance Analysis",
        description: "Address identified performance gaps",
        actions: ["Review individual pilot performance", "Focus on weak areas", "Schedule additional training"]
      }]
    end
  end

  defp generate_tactical_skill_recommendations(tactical_analysis) do
    patterns = Map.get(tactical_analysis, :patterns, [])
    focus_fire = Map.get(tactical_analysis, :focus_fire_effectiveness, 0.5)

    recommendations = []

    recommendations = if focus_fire < 0.6 do
      [%{
        type: :training,
        priority: :high,
        title: "Focus Fire Training",
        description: "Improve target calling and focus fire coordination",
        actions: ["Practice target calling", "Improve communication discipline", "Coordinate alpha strikes"]
      } | recommendations]
    else
      recommendations
    end

    recommendations = if Enum.any?(patterns, &(&1.name == :poor_positioning)) do
      [%{
        type: :training,
        priority: :medium,
        title: "Positioning Skills",
        description: "Improve fleet positioning and maneuvering",
        actions: ["Practice fleet movements", "Study positioning theory", "Review engagement angles"]
      } | recommendations]
    else
      recommendations
    end

    recommendations
  end

  defp pattern_to_recommendations(pattern) do
    case pattern do
      %{type: :doctrine, name: name} ->
        ["Consider counters to #{name} doctrine", "Prepare appropriate ship compositions"]

      %{type: :tactical, name: :kiting} ->
        ["Use fast tackle to close range", "Consider long-range weapons"]

      %{type: :tactical, name: :brawling} ->
        ["Maintain range control", "Use kiting tactics"]

      %{type: :timing, name: :multi_phase_engagement} ->
        ["Prepare for extended engagement", "Manage capacitor and ammunition"]

      _ ->
        []
    end
  end
end