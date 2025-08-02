defmodule EveDmv.Shared.Strategic.RecommendationEngine do
  @moduledoc """
  Generates strategic recommendations based on comprehensive analysis.

  Responsible for:
  - Immediate action recommendations
  - Medium-term strategic planning
  - Long-term strategic guidance
  - Risk assessment and contingency planning
  """
  """

  require Logger

  @doc """
  Generates comprehensive strategic recommendations.
  """
  def generate_strategic_recommendations(
        pattern_analysis,
        territorial_analysis,
        resource_analysis,
        trend_analysis
      ) do
    immediate = generate_immediate_recommendations(pattern_analysis, trend_analysis)
    medium_term = generate_medium_term_recommendations(territorial_analysis, resource_analysis)
    long_term = generate_long_term_recommendations(trend_analysis)

    risks = assess_strategic_risks(pattern_analysis, territorial_analysis)
    contingencies = develop_contingency_plans(risks)

    priorities = determine_strategic_priorities(immediate, medium_term, long_term)

    %{
      immediate_actions: immediate,
      medium_term_strategy: medium_term,
      long_term_planning: long_term,
      risk_assessment: risks,
      contingency_planning: contingencies,
      strategic_priorities: priorities,
      implementation_roadmap: create_implementation_roadmap(priorities)
    }
  end

  @doc """
  Generates immediate action recommendations.
  """
  def generate_immediate_recommendations(pattern_analysis, trend_analysis) do
    pattern_actions = extract_pattern_based_actions(pattern_analysis)
    trend_actions = extract_trend_based_actions(trend_analysis)

    all_actions = pattern_actions ++ trend_actions

    all_actions
    |> prioritize_by_urgency()
    |> Enum.take(5)
    |> Enum.map(&format_immediate_action/1)
  end

  @doc """
  Generates medium-term strategic recommendations.
  """
  def generate_medium_term_recommendations(territorial_analysis, resource_analysis) do
    territorial_strategies = develop_territorial_strategies(territorial_analysis)
    resource_strategies = develop_resource_strategies(resource_analysis)

    combined_strategies =
      merge_complementary_strategies(territorial_strategies, resource_strategies)

    %{
      primary_objectives: identify_primary_objectives(combined_strategies),
      strategic_initiatives: format_strategic_initiatives(combined_strategies),
      resource_allocation: recommend_resource_allocation(combined_strategies),
      success_metrics: define_success_metrics(combined_strategies)
    }
  end

  @doc """
  Generates long-term strategic recommendations.
  """
  def generate_long_term_recommendations(trend_analysis) do
    future_state = project_future_state(trend_analysis)
    strategic_goals = define_strategic_goals(future_state)
    capability_requirements = identify_capability_requirements(strategic_goals)

    %{
      vision_statement: craft_vision_statement(future_state),
      strategic_goals: strategic_goals,
      capability_development: capability_requirements,
      milestone_planning: create_milestone_plan(strategic_goals),
      adaptation_strategies: develop_adaptation_strategies(trend_analysis)
    }
  end

  # Private functions - Immediate Recommendations

  defp extract_pattern_based_actions(pattern_analysis) do
    pattern_analysis.identified_patterns
    |> Enum.flat_map(fn pattern ->
      case pattern.type do
        :offensive_preparation ->
          [{:defensive_reinforcement, :critical, "Enemy offensive preparation detected"}]

        :harassment_campaign ->
          [{:anti_harassment_patrol, :high, "Counter harassment operations needed"}]

        :supply_line_disruption ->
          [{:supply_line_security, :high, "Protect critical supply routes"}]

        :reconnaissance_operation ->
          [{:counter_intelligence, :medium, "Enemy reconnaissance detected"}]

        :territorial_expansion ->
          [{:border_defense, :high, "Territorial expansion threatens borders"}]

        _ ->
          []
      end
    end)
  end

  defp extract_trend_based_actions(trend_analysis) do
    momentum = trend_analysis.momentum.momentum_direction

    base_actions =
      case momentum do
        :strong_positive ->
          [{:capitalize_momentum, :high, "Exploit positive momentum"}]

        :strong_negative ->
          [{:damage_control, :critical, "Reverse negative trend immediately"}]

        _ ->
          []
      end

    # Add inflection point actions
    inflection_actions =
      trend_analysis.inflection_points
      |> Enum.take(1)
      |> Enum.map(fn point ->
        if point.type == :peak do
          {:consolidate_gains, :medium, "Consolidate at activity peak"}
        else
          {:seize_initiative, :medium, "Exploit activity trough"}
        end
      end)

    base_actions ++ inflection_actions
  end

  defp prioritize_by_urgency(actions) do
    actions
    |> Enum.sort_by(fn {_, urgency, _} ->
      case urgency do
        :critical -> 0
        :high -> 1
        :medium -> 2
        :low -> 3
      end
    end)
  end

  defp format_immediate_action({action_type, urgency, reason}) do
    %{
      action: describe_action(action_type),
      urgency: urgency,
      reasoning: reason,
      resources_required: estimate_resources(action_type),
      expected_timeline: estimate_timeline(action_type, urgency)
    }
  end

  defp describe_action(action_type) do
    case action_type do
      :defensive_reinforcement ->
        "Reinforce defensive positions in threatened systems"

      :anti_harassment_patrol ->
        "Deploy anti-harassment patrols to protect operations"

      :supply_line_security ->
        "Increase security on critical supply routes"

      :counter_intelligence ->
        "Initiate counter-intelligence operations"

      :border_defense ->
        "Strengthen border system defenses"

      :capitalize_momentum ->
        "Launch operations to exploit current advantages"

      :damage_control ->
        "Implement emergency measures to stabilize situation"

      :consolidate_gains ->
        "Consolidate control in recently gained territories"

      :seize_initiative ->
        "Launch surprise operations while enemy is weak"

      _ ->
        "Execute strategic action"
    end
  end

  defp estimate_resources(action_type) do
    case action_type do
      :defensive_reinforcement -> "Medium fleet, defensive structures"
      :anti_harassment_patrol -> "Fast response squadrons"
      :supply_line_security -> "Escort vessels, scout ships"
      :counter_intelligence -> "Covert ops teams"
      :border_defense -> "Standing fleet, citadels"
      :capitalize_momentum -> "Main battle fleet"
      :damage_control -> "All available forces"
      _ -> "Standard operational forces"
    end
  end

  defp estimate_timeline(_action_type, urgency) do
    case urgency do
      :critical -> "Immediate - within 24 hours"
      :high -> "Within 48 hours"
      :medium -> "Within 72 hours"
      :low -> "Within one week"
    end
  end

  # Private functions - Medium Term

  defp develop_territorial_strategies(territorial_analysis) do
    if territorial_analysis do
      situation =
        territorial_analysis
        |> get_in([:territorial_assessment, :situation]) || :unknown

      case situation do
        :dominant_control ->
          [
            %{type: :selective_expansion, focus: :high_value_targets},
            %{type: :defense_optimization, focus: :efficiency}
          ]

        :stable_control ->
          [
            %{type: :consolidation, focus: :infrastructure},
            %{type: :gradual_expansion, focus: :adjacent_systems}
          ]

        :contested_territory ->
          [
            %{type: :secure_core, focus: :key_systems},
            %{type: :disrupt_enemy, focus: :contested_areas}
          ]

        :highly_contested ->
          [
            %{type: :defensive_strategy, focus: :survival},
            %{type: :alliance_building, focus: :diplomatic}
          ]

        _ ->
          [%{type: :establish_foothold, focus: :initial_territory}]
      end
    else
      []
    end
  end

  defp develop_resource_strategies(resource_analysis) do
    if resource_analysis do
      competition_level =
        resource_analysis
        |> get_in([:competition, :competition_intensity]) || 0.0

      strategies = []

      strategies =
        if competition_level > 0.7 do
          strategies ++
            [
              %{type: :resource_denial, focus: :competitor_disruption},
              %{type: :alternative_sources, focus: :diversification}
            ]
        else
          strategies ++
            [
              %{type: :resource_maximization, focus: :extraction_efficiency},
              %{type: :market_dominance, focus: :supply_control}
            ]
        end

      strategies
    else
      []
    end
  end

  defp merge_complementary_strategies(territorial, resource) do
    all_strategies = territorial ++ resource

    # Group by compatibility
    grouped =
      all_strategies
      |> Enum.group_by(fn strategy ->
        case strategy.type do
          s when s in [:selective_expansion, :gradual_expansion, :resource_maximization] ->
            :expansion

          s when s in [:consolidation, :defense_optimization, :secure_core] ->
            :consolidation

          s when s in [:disrupt_enemy, :resource_denial] ->
            :disruption

          _ ->
            :other
        end
      end)

    # Merge compatible strategies
    grouped
    |> Enum.flat_map(fn {group, strategies} ->
      if length(strategies) > 1 do
        [merge_strategy_group(group, strategies)]
      else
        strategies
      end
    end)
  end

  defp merge_strategy_group(group, strategies) do
    %{
      type: group,
      components: Enum.map(strategies, & &1.type),
      focus: unify_focus(Enum.map(strategies, & &1.focus)),
      synergy_bonus: calculate_synergy(strategies)
    }
  end

  defp unify_focus(focuses) do
    # Combine multiple focuses into unified approach
    unified_name =
      focuses
      |> Enum.uniq()
      |> Enum.take(2)
      |> Enum.join("_and_")

    try do
      String.to_existing_atom(unified_name)
    rescue
      ArgumentError -> :combined_focus
    end
  end

  defp calculate_synergy(strategies) do
    # Synergy bonus for complementary strategies
    if length(strategies) >= 2 do
      0.2
    else
      0.0
    end
  end

  defp identify_primary_objectives(strategies) do
    strategies
    |> Enum.take(3)
    |> Enum.map(fn strategy ->
      %{
        objective: format_objective(strategy),
        strategic_value: assess_strategic_value(strategy),
        implementation_complexity: assess_complexity(strategy)
      }
    end)
  end

  defp format_objective(strategy) do
    case strategy.type do
      :expansion -> "Expand territorial control focusing on #{strategy.focus}"
      :consolidation -> "Consolidate and strengthen current positions"
      :disruption -> "Disrupt enemy operations and resource flows"
      type -> "Implement #{type} strategy"
    end
  end

  defp assess_strategic_value(strategy) do
    base_value =
      case strategy.type do
        :expansion -> 0.8
        :consolidation -> 0.7
        :disruption -> 0.6
        _ -> 0.5
      end

    synergy_bonus = Map.get(strategy, :synergy_bonus, 0.0)
    Float.round(base_value + synergy_bonus, 2)
  end

  defp assess_complexity(strategy) do
    case strategy.type do
      :expansion -> :high
      :disruption -> :medium
      :consolidation -> :low
      _ -> :medium
    end
  end

  defp format_strategic_initiatives(strategies) do
    strategies
    |> Enum.map(fn strategy ->
      %{
        initiative_name: name_initiative(strategy),
        description: describe_initiative(strategy),
        key_activities: list_key_activities(strategy),
        success_criteria: define_initiative_success(strategy)
      }
    end)
  end

  defp name_initiative(strategy) do
    case strategy.type do
      :expansion -> "Operation Manifest Destiny"
      :consolidation -> "Project Fortress"
      :disruption -> "Operation Chaos"
      type -> "Strategic Initiative: #{type}"
    end
  end

  defp describe_initiative(strategy) do
    "Strategic initiative focused on #{strategy.focus} through #{strategy.type} operations"
  end

  defp list_key_activities(strategy) do
    case strategy.type do
      :expansion ->
        ["System reconnaissance", "Force buildup", "Coordinated assault", "Establish control"]

      :consolidation ->
        ["Infrastructure development", "Defense upgrades", "Supply line optimization"]

      :disruption ->
        [
          "Intelligence gathering",
          "Target identification",
          "Strike operations",
          "Withdrawal planning"
        ]

      _ ->
        ["Planning", "Resource allocation", "Execution", "Assessment"]
    end
  end

  defp define_initiative_success(strategy) do
    case strategy.type do
      :expansion -> "Control of target systems established"
      :consolidation -> "Defense rating improved by 30%"
      :disruption -> "Enemy operations reduced by 50%"
      _ -> "Strategic objectives achieved"
    end
  end

  defp recommend_resource_allocation(strategies) do
    total_weight = length(strategies)

    strategies
    |> Enum.map(fn strategy ->
      allocation = calculate_resource_allocation(strategy, total_weight)

      %{
        strategy: strategy.type,
        fleet_allocation: "#{allocation.fleet}% of available forces",
        logistics_allocation: "#{allocation.logistics}% of supply capacity",
        intelligence_allocation: "#{allocation.intelligence}% of intel resources"
      }
    end)
  end

  defp calculate_resource_allocation(strategy, total_strategies) do
    base_allocation = 100.0 / total_strategies

    type_modifiers =
      case strategy.type do
        :expansion -> %{fleet: 1.3, logistics: 1.2, intelligence: 1.0}
        :consolidation -> %{fleet: 0.8, logistics: 1.3, intelligence: 0.9}
        :disruption -> %{fleet: 1.1, logistics: 0.8, intelligence: 1.4}
        _ -> %{fleet: 1.0, logistics: 1.0, intelligence: 1.0}
      end

    %{
      fleet: round(base_allocation * type_modifiers.fleet),
      logistics: round(base_allocation * type_modifiers.logistics),
      intelligence: round(base_allocation * type_modifiers.intelligence)
    }
  end

  defp define_success_metrics(strategies) do
    strategies
    |> Enum.flat_map(fn strategy ->
      case strategy.type do
        :expansion ->
          [
            %{metric: "Systems controlled", target: "+3 systems", timeframe: "30 days"},
            %{metric: "Territory security", target: "80% secure", timeframe: "45 days"}
          ]

        :consolidation ->
          [
            %{metric: "Defense efficiency", target: "+30%", timeframe: "30 days"},
            %{metric: "Loss reduction", target: "-50%", timeframe: "30 days"}
          ]

        :disruption ->
          [
            %{metric: "Enemy losses inflicted", target: "+100%", timeframe: "30 days"},
            %{metric: "Supply lines disrupted", target: "3+ routes", timeframe: "14 days"}
          ]

        _ ->
          [%{metric: "Objectives completed", target: "80%", timeframe: "30 days"}]
      end
    end)
    |> Enum.uniq_by(& &1.metric)
    |> Enum.take(5)
  end

  # Private functions - Long Term

  defp project_future_state(trend_analysis) do
    current_momentum = trend_analysis.momentum.momentum_direction
    trend_strength = trend_analysis.trend_strength.overall_strength

    projection =
      cond do
        current_momentum in [:strong_positive, :positive] && trend_strength > 0.6 ->
          :regional_dominance

        current_momentum == :positive && trend_strength > 0.3 ->
          :steady_growth

        current_momentum == :neutral ->
          :stable_presence

        current_momentum in [:negative, :strong_negative] ->
          :strategic_retreat

        true ->
          :uncertain_future
      end

    %{
      projected_state: projection,
      confidence: calculate_projection_confidence(trend_analysis),
      key_assumptions: list_key_assumptions(projection),
      wildcards: identify_wildcards()
    }
  end

  defp calculate_projection_confidence(trend_analysis) do
    trend_confidence = Map.get(trend_analysis.trend_prediction, :confidence_level, 0.5)
    pattern_stability = Map.get(trend_analysis.pattern_evolution, :pattern_stability, 0.5)

    Float.round((trend_confidence + pattern_stability) / 2, 2)
  end

  defp list_key_assumptions(projection) do
    base_assumptions = ["Current operational tempo maintained", "No major alliance shifts"]

    projection_assumptions =
      case projection do
        :regional_dominance ->
          ["Continued resource availability", "Successful territorial expansion"]

        :steady_growth ->
          ["Stable competitive environment", "Consistent member participation"]

        :stable_presence ->
          ["Status quo maintained", "Limited external pressure"]

        :strategic_retreat ->
          ["Organized withdrawal possible", "Core systems defensible"]

        _ ->
          ["Situation remains fluid"]
      end

    base_assumptions ++ projection_assumptions
  end

  defp identify_wildcards do
    [
      "Major power enters region",
      "Game balance changes",
      "Key ally defection",
      "Resource market crash",
      "New strategic discovery"
    ]
  end

  defp define_strategic_goals(future_state) do
    case future_state.projected_state do
      :regional_dominance ->
        [
          %{goal: "Achieve regional hegemony", priority: :critical, horizon: "6 months"},
          %{goal: "Establish economic monopoly", priority: :high, horizon: "4 months"},
          %{goal: "Create vassal network", priority: :medium, horizon: "8 months"}
        ]

      :steady_growth ->
        [
          %{goal: "Double controlled territory", priority: :high, horizon: "6 months"},
          %{goal: "Increase member base 50%", priority: :high, horizon: "3 months"},
          %{goal: "Establish forward bases", priority: :medium, horizon: "4 months"}
        ]

      :stable_presence ->
        [
          %{goal: "Maintain current holdings", priority: :high, horizon: "ongoing"},
          %{goal: "Improve defensive capabilities", priority: :high, horizon: "3 months"},
          %{goal: "Optimize resource extraction", priority: :medium, horizon: "2 months"}
        ]

      :strategic_retreat ->
        [
          %{goal: "Preserve core assets", priority: :critical, horizon: "immediate"},
          %{goal: "Maintain morale", priority: :critical, horizon: "ongoing"},
          %{goal: "Identify rebuild location", priority: :high, horizon: "1 month"}
        ]

      _ ->
        [%{goal: "Survive and adapt", priority: :critical, horizon: "ongoing"}]
    end
  end

  defp identify_capability_requirements(strategic_goals) do
    required_capabilities =
      strategic_goals
      |> Enum.flat_map(fn goal ->
        case goal.goal do
          "Achieve regional hegemony" ->
            [:capital_fleet, :territory_administration, :diplomatic_corps]

          "Establish economic monopoly" ->
            [:market_manipulation, :industrial_capacity, :logistics_network]

          "Double controlled territory" ->
            [:rapid_deployment, :siege_warfare, :occupation_forces]

          "Improve defensive capabilities" ->
            [:citadel_management, :standing_fleet, :early_warning]

          "Preserve core assets" ->
            [:asset_evacuation, :guerrilla_tactics, :safe_haven]

          _ ->
            [:basic_operations]
        end
      end)
      |> Enum.uniq()

    %{
      required_capabilities: required_capabilities,
      current_gaps: assess_capability_gaps(required_capabilities),
      development_priorities: prioritize_capability_development(required_capabilities),
      training_requirements: identify_training_needs(required_capabilities)
    }
  end

  defp assess_capability_gaps(required) do
    # Simplified gap assessment
    current = [:basic_operations, :standing_fleet, :industrial_capacity]

    required
    |> Enum.reject(&(&1 in current))
    |> Enum.map(fn capability ->
      %{
        capability: capability,
        gap_severity: classify_gap_severity(capability),
        estimated_development_time: estimate_development_time(capability)
      }
    end)
  end

  defp classify_gap_severity(capability) do
    case capability do
      :capital_fleet -> :critical
      :territory_administration -> :high
      :diplomatic_corps -> :medium
      _ -> :low
    end
  end

  defp estimate_development_time(capability) do
    case capability do
      :capital_fleet -> "3-6 months"
      :territory_administration -> "2-3 months"
      :diplomatic_corps -> "1-2 months"
      :rapid_deployment -> "1 month"
      _ -> "2-4 weeks"
    end
  end

  defp prioritize_capability_development(capabilities) do
    capabilities
    |> Enum.map(fn cap ->
      {cap, capability_priority(cap)}
    end)
    |> Enum.sort_by(fn {_, priority} -> priority end)
    |> Enum.map(fn {cap, _} -> cap end)
    |> Enum.take(5)
  end

  defp capability_priority(capability) do
    case capability do
      :capital_fleet -> 1
      :territory_administration -> 2
      :early_warning -> 3
      :rapid_deployment -> 4
      :diplomatic_corps -> 5
      _ -> 10
    end
  end

  defp identify_training_needs(capabilities) do
    capabilities
    |> Enum.map(fn capability ->
      %{
        capability: capability,
        training_type: determine_training_type(capability),
        estimated_duration: estimate_training_duration(capability),
        resources_needed: list_training_resources(capability)
      }
    end)
  end

  defp determine_training_type(capability) do
    case capability do
      :capital_fleet -> "Capital ship operations"
      :diplomatic_corps -> "Diplomatic negotiation"
      :guerrilla_tactics -> "Asymmetric warfare"
      _ -> "Specialized training"
    end
  end

  defp estimate_training_duration(capability) do
    case capability do
      :capital_fleet -> "4-6 weeks intensive"
      :diplomatic_corps -> "2-3 weeks workshop"
      _ -> "1-2 weeks standard"
    end
  end

  defp list_training_resources(capability) do
    case capability do
      :capital_fleet -> ["Training capitals", "Experienced FCs", "Simulation time"]
      :diplomatic_corps -> ["Negotiation experts", "Case studies", "Mock negotiations"]
      _ -> ["Training materials", "Instructors", "Practice environment"]
    end
  end

  defp craft_vision_statement(future_state) do
    case future_state.projected_state do
      :regional_dominance ->
        "To establish uncontested dominance across the region through superior strategy and execution"

      :steady_growth ->
        "To build a thriving and expanding presence through sustainable growth and strategic excellence"

      :stable_presence ->
        "To maintain a secure and prosperous territory through efficiency and defensive strength"

      :strategic_retreat ->
        "To preserve our strength and identity while preparing for future resurgence"

      _ ->
        "To adapt and thrive in an uncertain environment through flexibility and resilience"
    end
  end

  defp create_milestone_plan(strategic_goals) do
    strategic_goals
    |> Enum.map(fn goal ->
      %{
        goal: goal.goal,
        milestones: generate_milestones(goal),
        dependencies: identify_dependencies(goal),
        risk_factors: assess_milestone_risks(goal)
      }
    end)
  end

  defp generate_milestones(goal) do
    case goal.goal do
      "Achieve regional hegemony" ->
        [
          %{milestone: "Control 30% of region", timeline: "2 months"},
          %{milestone: "Neutralize main competitor", timeline: "4 months"},
          %{milestone: "Establish hegemonic control", timeline: "6 months"}
        ]

      "Double controlled territory" ->
        [
          %{milestone: "Secure 3 new systems", timeline: "1 month"},
          %{milestone: "Establish forward bases", timeline: "3 months"},
          %{milestone: "Complete territorial doubling", timeline: "6 months"}
        ]

      _ ->
        [%{milestone: "Initial progress", timeline: "1 month"}]
    end
  end

  defp identify_dependencies(goal) do
    case goal.goal do
      "Achieve regional hegemony" -> ["Capital fleet ready", "Diplomatic isolation of enemies"]
      "Establish economic monopoly" -> ["Market control", "Industrial supremacy"]
      _ -> ["Basic operational capability"]
    end
  end

  defp assess_milestone_risks(goal) do
    case goal.priority do
      :critical -> ["Resource shortage", "Enemy counter-offensive", "Internal dissent"]
      :high -> ["Competitive response", "Market fluctuations"]
      _ -> ["Standard operational risks"]
    end
  end

  defp develop_adaptation_strategies(trend_analysis) do
    volatility = Map.get(trend_analysis.activity_trends, :volatility, 0.5)

    if volatility > 0.5 do
      %{
        primary_approach: "Flexible response doctrine",
        key_principles: [
          "Maintain strategic reserves",
          "Develop multiple contingencies",
          "Regular strategy reviews"
        ],
        trigger_points: define_adaptation_triggers(),
        response_protocols: define_response_protocols()
      }
    else
      %{
        primary_approach: "Steady state optimization",
        key_principles: [
          "Incremental improvements",
          "Efficiency maximization",
          "Risk minimization"
        ],
        trigger_points: [],
        response_protocols: []
      }
    end
  end

  defp define_adaptation_triggers do
    [
      %{trigger: "Territory loss > 20%", response: "Emergency consolidation"},
      %{trigger: "Member base decline > 30%", response: "Morale restoration program"},
      %{trigger: "New major threat", response: "Strategic reassessment"}
    ]
  end

  defp define_response_protocols do
    [
      %{
        situation: "Major offensive failure",
        protocol: ["Immediate withdrawal", "Damage assessment", "Morale management"]
      },
      %{
        situation: "Economic crisis",
        protocol: ["Resource conservation", "Priority rationing", "Alternative funding"]
      }
    ]
  end

  # Private functions - Risk and Contingency

  defp assess_strategic_risks(pattern_analysis, territorial_analysis) do
    pattern_risks = assess_pattern_risks(pattern_analysis)
    territorial_risks = assess_territorial_risks(territorial_analysis)

    all_risks = pattern_risks ++ territorial_risks

    %{
      identified_risks: all_risks,
      risk_matrix: build_risk_matrix(all_risks),
      high_priority_risks: filter_high_priority_risks(all_risks),
      risk_mitigation_budget: estimate_mitigation_budget(all_risks)
    }
  end

  defp assess_pattern_risks(pattern_analysis) do
    pattern_analysis.identified_patterns
    |> Enum.map(fn pattern ->
      case pattern.type do
        :offensive_preparation ->
          %{
            risk: "Enemy offensive imminent",
            probability: pattern.confidence,
            impact: :critical,
            category: :military
          }

        :territorial_expansion ->
          %{
            risk: "Aggressive expansion by competitor",
            probability: pattern.confidence * 0.8,
            impact: :high,
            category: :territorial
          }

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp assess_territorial_risks(territorial_analysis) do
    if territorial_analysis do
      contestation_level =
        territorial_analysis
        |> get_in([:contested_areas, :contestation_intensity]) || 0.0

      risks = []

      risks =
        if contestation_level > 0.5 do
          risks ++
            [
              %{
                risk: "Loss of contested territories",
                probability: contestation_level,
                impact: :high,
                category: :territorial
              }
            ]
        else
          risks
        end

      risks
    else
      []
    end
  end

  defp build_risk_matrix(risks) do
    risks
    |> Enum.group_by(& &1.impact)
    |> Enum.map(fn {impact, impact_risks} ->
      {impact, Enum.sort_by(impact_risks, & &1.probability, :desc)}
    end)
    |> Map.new()
  end

  defp filter_high_priority_risks(risks) do
    risks
    |> Enum.filter(fn risk ->
      (risk.impact == :critical && risk.probability > 0.3) ||
        (risk.impact == :high && risk.probability > 0.5)
    end)
    |> Enum.sort_by(fn risk ->
      impact_score =
        case risk.impact do
          :critical -> 3
          :high -> 2
          :medium -> 1
          :low -> 0
        end

      -(impact_score * risk.probability)
    end)
  end

  defp estimate_mitigation_budget(risks) do
    total_risk_value =
      risks
      |> Enum.map(fn risk ->
        impact_value =
          case risk.impact do
            :critical -> 1000
            :high -> 500
            :medium -> 200
            :low -> 50
          end

        impact_value * risk.probability
      end)
      |> Enum.sum()

    %{
      estimated_budget: round(total_risk_value * 1_000_000),
      budget_allocation: allocate_mitigation_budget(risks),
      cost_benefit_ratio: calculate_mitigation_roi(total_risk_value)
    }
  end

  defp allocate_mitigation_budget(risks) do
    high_priority = filter_high_priority_risks(risks)

    high_priority
    |> Enum.map(fn risk ->
      %{
        risk: risk.risk,
        allocation_percentage: calculate_risk_allocation(risk, length(high_priority)),
        mitigation_approach: suggest_mitigation_approach(risk)
      }
    end)
  end

  defp calculate_risk_allocation(risk, total_risks) do
    base_allocation = 100.0 / max(1, total_risks)

    impact_modifier =
      case risk.impact do
        :critical -> 1.5
        :high -> 1.2
        :medium -> 1.0
        :low -> 0.8
      end

    round(base_allocation * impact_modifier * risk.probability)
  end

  defp suggest_mitigation_approach(risk) do
    case risk.category do
      :military -> "Defensive preparations and intelligence"
      :territorial -> "Border reinforcement and rapid response"
      :economic -> "Diversification and reserves"
      _ -> "Standard risk mitigation"
    end
  end

  defp calculate_mitigation_roi(risk_value) do
    # Simplified ROI calculation
    # Assume 70% prevention rate
    prevented_losses = risk_value * 0.7
    Float.round(prevented_losses / max(1, risk_value), 2)
  end

  defp develop_contingency_plans(risks) do
    high_priority = Map.get(risks, :high_priority_risks, [])

    contingency_plans =
      high_priority
      |> Enum.map(fn risk ->
        %{
          risk_scenario: risk.risk,
          contingency_plan: create_contingency_plan(risk),
          activation_triggers: define_activation_triggers(risk),
          resource_requirements: estimate_contingency_resources(risk)
        }
      end)

    %{
      plans: contingency_plans,
      activation_protocol: create_activation_protocol(),
      communication_plan: create_crisis_communication_plan(),
      recovery_procedures: define_recovery_procedures()
    }
  end

  defp create_contingency_plan(risk) do
    case risk.risk do
      "Enemy offensive imminent" ->
        %{
          phase_1: "Alert all forces, recall deployed units",
          phase_2: "Concentrate defenses at key systems",
          phase_3: "Execute defensive strategy",
          phase_4: "Counter-offensive preparation"
        }

      "Loss of contested territories" ->
        %{
          phase_1: "Reinforce contested areas",
          phase_2: "Diplomatic initiatives",
          phase_3: "Strategic withdrawal if necessary",
          phase_4: "Regroup and counter"
        }

      _ ->
        %{
          phase_1: "Assess situation",
          phase_2: "Mobilize resources",
          phase_3: "Execute response",
          phase_4: "Review and adapt"
        }
    end
  end

  defp define_activation_triggers(risk) do
    case risk.risk do
      "Enemy offensive imminent" ->
        ["Enemy fleet movements detected", "Forward base attacks", "Intelligence confirmation"]

      "Loss of contested territories" ->
        ["System sovereignty challenged", "Defense fleet defeated", "Supply lines cut"]

      _ ->
        ["Threat threshold exceeded"]
    end
  end

  defp estimate_contingency_resources(risk) do
    case risk.impact do
      :critical ->
        %{
          personnel: "All available",
          ships: "Full mobilization",
          logistics: "Emergency supplies",
          timeline: "Immediate"
        }

      :high ->
        %{
          personnel: "75% strength",
          ships: "Main fleet",
          logistics: "Standard reserves",
          timeline: "24 hours"
        }

      _ ->
        %{
          personnel: "Standard duty",
          ships: "Response fleet",
          logistics: "Normal operations",
          timeline: "48 hours"
        }
    end
  end

  defp create_activation_protocol do
    %{
      detection: "Continuous monitoring via intelligence network",
      verification: "Cross-reference multiple sources",
      decision: "Leadership council approval",
      activation: "Automated alert system",
      escalation: "Phased response based on threat level"
    }
  end

  defp create_crisis_communication_plan do
    %{
      internal: [
        "Immediate leadership notification",
        "Member-wide alert system",
        "Secure communication channels"
      ],
      external: [
        "Ally notification protocols",
        "Public stance preparation",
        "Diplomatic channels activation"
      ],
      media: [
        "Prepared statements",
        "Designated spokespersons",
        "Information control"
      ]
    }
  end

  defp define_recovery_procedures do
    [
      %{
        phase: "Immediate stabilization",
        actions: ["Secure remaining assets", "Casualty assessment", "Morale management"]
      },
      %{
        phase: "Short-term recovery",
        actions: ["Resource redistribution", "Defensive consolidation", "Member retention"]
      },
      %{
        phase: "Long-term rebuilding",
        actions: ["Strategic reassessment", "Capability rebuilding", "Growth resumption"]
      }
    ]
  end

  defp determine_strategic_priorities(immediate, medium_term, long_term) do
    # Combine all recommendations and prioritize
    all_priorities = []

    # Add immediate priorities
    immediate_priorities =
      immediate
      |> Enum.take(3)
      |> Enum.map(fn action ->
        %{
          priority_level: 1,
          timeframe: :immediate,
          action: action.action,
          strategic_impact: :tactical
        }
      end)

    # Add medium-term priorities
    medium_priorities =
      medium_term.primary_objectives
      |> Enum.take(2)
      |> Enum.map(fn objective ->
        %{
          priority_level: 2,
          timeframe: :medium_term,
          action: objective.objective,
          strategic_impact: :operational
        }
      end)

    # Add long-term priorities
    long_priorities =
      long_term.strategic_goals
      |> Enum.take(1)
      |> Enum.map(fn goal ->
        %{
          priority_level: 3,
          timeframe: :long_term,
          action: goal.goal,
          strategic_impact: :strategic
        }
      end)

    all_priorities ++ immediate_priorities ++ medium_priorities ++ long_priorities
  end

  defp create_implementation_roadmap(priorities) do
    %{
      phase_1: %{
        duration: "0-7 days",
        focus: "Immediate actions",
        priorities: Enum.filter(priorities, &(&1.timeframe == :immediate)),
        success_criteria: "Threats addressed, situation stabilized"
      },
      phase_2: %{
        duration: "1-4 weeks",
        focus: "Operational improvements",
        priorities: Enum.filter(priorities, &(&1.timeframe == :medium_term)),
        success_criteria: "Strategic initiatives launched"
      },
      phase_3: %{
        duration: "1-6 months",
        focus: "Strategic transformation",
        priorities: Enum.filter(priorities, &(&1.timeframe == :long_term)),
        success_criteria: "Long-term goals achieved"
      },
      review_schedule: [
        %{milestone: "Week 1", review_focus: "Immediate action effectiveness"},
        %{milestone: "Week 4", review_focus: "Strategic initiative progress"},
        %{milestone: "Month 3", review_focus: "Overall strategic alignment"}
      ]
    }
  end
end
