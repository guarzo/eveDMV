defmodule EveDmv.Shared.Strategic.OpportunityIdentifier do
  @moduledoc """
  Identifies strategic opportunities based on pattern analysis.

  Responsible for:
  - Opportunity identification across different domains
  - Viability assessment
  - Risk evaluation
  - Timing analysis
  """

  require Logger

  @doc """
  Identifies all strategic opportunities from various analyses.
  """
  def identify_strategic_opportunities(pattern_analysis, territorial_analysis, resource_analysis) do
    territorial_opportunities = extract_territorial_opportunities(territorial_analysis)
    resource_opportunities = extract_resource_opportunities(resource_analysis)
    pattern_opportunities = extract_pattern_opportunities(pattern_analysis)
    timing_opportunities = identify_timing_opportunities(pattern_analysis)

    all_opportunities =
      territorial_opportunities ++
        resource_opportunities ++
        pattern_opportunities ++
        timing_opportunities

    prioritized = prioritize_opportunities(all_opportunities)

    %{
      total_opportunities: length(all_opportunities),
      territorial_opportunities: territorial_opportunities,
      resource_opportunities: resource_opportunities,
      pattern_opportunities: pattern_opportunities,
      timing_opportunities: timing_opportunities,
      prioritized_opportunities: prioritized,
      opportunity_assessment: assess_opportunity_viability(prioritized),
      best_opportunities: Enum.take(prioritized, 5)
    }
  end

  @doc """
  Assesses the viability of identified opportunities.
  """
  def assess_opportunity_viability(opportunities) do
    opportunities
    |> Enum.map(fn opportunity ->
      viability_score = calculate_viability_score(opportunity)
      risk_assessment = assess_opportunity_risk(opportunity)
      timing_assessment = assess_opportunity_timing(opportunity)

      Map.merge(opportunity, %{
        viability_score: viability_score,
        risk_assessment: risk_assessment,
        timing_assessment: timing_assessment,
        overall_rating:
          calculate_overall_rating(viability_score, risk_assessment, timing_assessment)
      })
    end)
  end

  @doc """
  Generates opportunity recommendations.
  """
  def generate_opportunity_recommendations(assessed_opportunities) do
    high_value = Enum.filter(assessed_opportunities, &(&1.overall_rating >= 0.7))
    quick_wins = identify_quick_wins(assessed_opportunities)
    strategic_plays = identify_strategic_plays(assessed_opportunities)

    %{
      immediate_actions: format_immediate_recommendations(quick_wins),
      strategic_initiatives: format_strategic_recommendations(strategic_plays),
      high_value_targets: format_high_value_recommendations(high_value),
      risk_warnings: generate_risk_warnings(assessed_opportunities)
    }
  end

  # Private functions

  defp extract_territorial_opportunities(territorial_analysis) do
    if territorial_analysis do
      expansion_opps =
        Map.get(territorial_analysis, :expansion_opportunities, %{})
        |> Map.get(:opportunities, [])
        |> Enum.map(fn opp ->
          Map.merge(opp, %{
            category: :territorial,
            value_proposition: "Territory expansion into #{opp.system_id}"
          })
        end)

      contested_opps =
        Map.get(territorial_analysis, :contested_areas, %{})
        |> Map.get(:contested_systems, [])
        |> Enum.filter(&(&1.conflict_intensity < 0.5))
        |> Enum.map(fn area ->
          %{
            type: :contested_control,
            category: :territorial,
            target: area.system_id,
            opportunity_score: 1.0 - area.conflict_intensity,
            risk_level: :medium,
            value_proposition: "Secure contested system #{area.system_id}"
          }
        end)

      expansion_opps ++ contested_opps
    else
      []
    end
  end

  defp extract_resource_opportunities(resource_analysis) do
    if resource_analysis do
      competition_level =
        resource_analysis
        |> get_in([:competition, :competition_intensity]) || 0.0

      resource_opps = []

      # Low competition resource areas
      resource_opps =
        if competition_level < 0.3 do
          resource_opps ++
            [
              %{
                type: :resource_exploitation,
                category: :economic,
                opportunity_score: 1.0 - competition_level,
                risk_level: :low,
                value_proposition: "Exploit low-competition resource area"
              }
            ]
        else
          resource_opps
        end

      # Disruption opportunities
      flow_efficiency =
        resource_analysis
        |> get_in([:resource_flows, :flow_efficiency]) || 1.0

      resource_opps =
        if flow_efficiency < 0.7 do
          resource_opps ++
            [
              %{
                type: :supply_disruption,
                category: :economic,
                opportunity_score: 1.0 - flow_efficiency,
                risk_level: :medium,
                value_proposition: "Disrupt vulnerable supply lines"
              }
            ]
        else
          resource_opps
        end

      resource_opps
    else
      []
    end
  end

  defp extract_pattern_opportunities(pattern_analysis) do
    patterns = pattern_analysis.identified_patterns

    patterns
    |> Enum.flat_map(fn pattern ->
      case pattern.type do
        :reconnaissance_operation ->
          [
            %{
              type: :intelligence_exploitation,
              category: :tactical,
              opportunity_score: pattern.confidence,
              risk_level: :low,
              value_proposition: "Exploit intelligence gathering for tactical advantage"
            }
          ]

        :defensive_consolidation ->
          [
            %{
              type: :defensive_weakness,
              category: :tactical,
              opportunity_score: 0.7,
              risk_level: :medium,
              value_proposition: "Target consolidating defenses before completion"
            }
          ]

        :offensive_preparation ->
          [
            %{
              type: :preemptive_action,
              category: :tactical,
              opportunity_score: 0.8,
              risk_level: :high,
              value_proposition: "Preemptive strike before offensive launch"
            }
          ]

        _ ->
          []
      end
    end)
  end

  defp identify_timing_opportunities(pattern_analysis) do
    pattern_transitions =
      pattern_analysis
      |> get_in([:pattern_relationships]) || []

    _initial_timing_opps = []

    # Transition opportunities
    timing_opps =
      pattern_transitions
      |> Enum.flat_map(fn relationship ->
        case relationship.relationship_type do
          :preparation_sequence ->
            [
              %{
                type: :timing_window,
                category: :temporal,
                opportunity_score: relationship.strength,
                risk_level: :medium,
                value_proposition: "Strike during preparation-to-action transition"
              }
            ]

          :action_reaction ->
            [
              %{
                type: :reaction_exploitation,
                category: :temporal,
                opportunity_score: relationship.strength * 0.8,
                risk_level: :low,
                value_proposition: "Exploit predictable reaction patterns"
              }
            ]

          _ ->
            []
        end
      end)

    timing_opps
  end

  defp prioritize_opportunities(opportunities) do
    opportunities
    |> Enum.map(fn opp ->
      priority_score = calculate_priority_score(opp)
      Map.put(opp, :priority_score, priority_score)
    end)
    |> Enum.sort_by(& &1.priority_score, :desc)
  end

  defp calculate_priority_score(opportunity) do
    base_score = Map.get(opportunity, :opportunity_score, 0.5)

    risk_modifier =
      case Map.get(opportunity, :risk_level, :medium) do
        :low -> 1.2
        :medium -> 1.0
        :high -> 0.8
      end

    category_modifier =
      case Map.get(opportunity, :category) do
        :territorial -> 1.1
        :economic -> 1.0
        :tactical -> 0.9
        :temporal -> 0.8
      end

    Float.round(base_score * risk_modifier * category_modifier, 3)
  end

  defp calculate_viability_score(opportunity) do
    factors = %{
      opportunity_strength: Map.get(opportunity, :opportunity_score, 0.5),
      risk_acceptability: risk_to_viability(Map.get(opportunity, :risk_level, :medium)),
      category_feasibility: category_feasibility(Map.get(opportunity, :category))
    }

    weighted_score =
      factors.opportunity_strength * 0.4 +
        factors.risk_acceptability * 0.3 +
        factors.category_feasibility * 0.3

    Float.round(weighted_score, 3)
  end

  defp risk_to_viability(risk_level) do
    case risk_level do
      :low -> 1.0
      :medium -> 0.7
      :high -> 0.4
    end
  end

  defp category_feasibility(category) do
    case category do
      :territorial -> 0.8
      :economic -> 0.9
      :tactical -> 0.7
      :temporal -> 0.6
      _ -> 0.5
    end
  end

  defp assess_opportunity_risk(opportunity) do
    risk_level = Map.get(opportunity, :risk_level, :medium)
    category = Map.get(opportunity, :category)

    risk_factors = identify_risk_factors(opportunity)
    mitigation_options = suggest_risk_mitigation(risk_level, category)

    %{
      risk_level: risk_level,
      risk_factors: risk_factors,
      mitigation_options: mitigation_options,
      acceptable_risk: length(risk_factors) <= 2
    }
  end

  defp identify_risk_factors(opportunity) do
    factors = []

    factors =
      case Map.get(opportunity, :type) do
        :contested_control -> factors ++ [:active_competition]
        :supply_disruption -> factors ++ [:retaliation_risk]
        :preemptive_action -> factors ++ [:escalation_risk, :timing_critical]
        :defensive_weakness -> factors ++ [:window_closing]
        _ -> factors
      end

    factors =
      if Map.get(opportunity, :risk_level) == :high do
        factors ++ [:high_stakes]
      else
        factors
      end

    factors
  end

  defp suggest_risk_mitigation(risk_level, category) do
    base_mitigations =
      case risk_level do
        :high -> ["Detailed reconnaissance required", "Prepare contingency plans"]
        :medium -> ["Monitor situation closely", "Ensure adequate forces"]
        :low -> ["Standard operational procedures"]
      end

    category_mitigations =
      case category do
        :territorial -> ["Secure supply lines", "Establish forward bases"]
        :economic -> ["Protect extraction operations", "Diversify targets"]
        :tactical -> ["Maintain operational security", "Prepare rapid response"]
        :temporal -> ["Precise timing critical", "Monitor for changes"]
        _ -> []
      end

    Enum.uniq(base_mitigations ++ category_mitigations)
  end

  defp assess_opportunity_timing(opportunity) do
    type = Map.get(opportunity, :type)

    urgency = determine_urgency(type)
    optimal_window = determine_optimal_window(type)
    prerequisites = identify_prerequisites(type)

    %{
      urgency: urgency,
      optimal_window: optimal_window,
      prerequisites: prerequisites,
      time_sensitive: urgency in [:critical, :high]
    }
  end

  defp determine_urgency(type) do
    case type do
      :timing_window -> :critical
      :defensive_weakness -> :high
      :preemptive_action -> :high
      :reaction_exploitation -> :medium
      :contested_control -> :medium
      :resource_exploitation -> :low
      :supply_disruption -> :low
      _ -> :medium
    end
  end

  defp determine_optimal_window(type) do
    case type do
      :timing_window -> "Next 24-48 hours"
      :defensive_weakness -> "Within 72 hours"
      :preemptive_action -> "Immediate action required"
      :reaction_exploitation -> "Next occurrence of trigger event"
      _ -> "Flexible timing"
    end
  end

  defp identify_prerequisites(type) do
    case type do
      :preemptive_action ->
        ["Intelligence confirmation", "Force assembly", "Operational security"]

      :supply_disruption ->
        ["Route identification", "Interdiction forces ready"]

      :contested_control ->
        ["Superior forces available", "Logistics in place"]

      :resource_exploitation ->
        ["Extraction capability", "Security forces"]

      _ ->
        ["Standard preparations"]
    end
  end

  defp calculate_overall_rating(viability_score, risk_assessment, timing_assessment) do
    risk_factor = if risk_assessment.acceptable_risk, do: 1.0, else: 0.7
    timing_factor = if timing_assessment.time_sensitive, do: 1.1, else: 1.0

    rating = viability_score * risk_factor * timing_factor
    Float.round(min(1.0, rating), 3)
  end

  defp identify_quick_wins(opportunities) do
    opportunities
    |> Enum.filter(fn opp ->
      opp.risk_assessment.risk_level == :low &&
        opp.viability_score > 0.6 &&
        opp.timing_assessment.urgency in [:low, :medium]
    end)
    |> Enum.take(3)
  end

  defp identify_strategic_plays(opportunities) do
    opportunities
    |> Enum.filter(fn opp ->
      opp.overall_rating > 0.7 &&
        opp.category in [:territorial, :economic]
    end)
    |> Enum.take(3)
  end

  defp format_immediate_recommendations(quick_wins) do
    quick_wins
    |> Enum.map(fn win ->
      %{
        action: win.value_proposition,
        reasoning: "Low risk opportunity with #{format_score(win.viability_score)} viability",
        requirements: win.timing_assessment.prerequisites,
        expected_outcome: describe_expected_outcome(win.type)
      }
    end)
  end

  defp format_strategic_recommendations(strategic_plays) do
    strategic_plays
    |> Enum.map(fn play ->
      %{
        initiative: play.value_proposition,
        strategic_value: "High-value #{play.category} opportunity",
        implementation_window: play.timing_assessment.optimal_window,
        success_factors: generate_success_factors(play)
      }
    end)
  end

  defp format_high_value_recommendations(high_value_opps) do
    high_value_opps
    |> Enum.map(fn opp ->
      %{
        target: opp.value_proposition,
        rating: format_score(opp.overall_rating),
        key_advantages: identify_key_advantages(opp),
        execution_priority: determine_execution_priority(opp)
      }
    end)
  end

  defp format_score(score) do
    "#{round(score * 100)}%"
  end

  defp describe_expected_outcome(type) do
    case type do
      :resource_exploitation -> "Increased resource income"
      :contested_control -> "Territorial control established"
      :supply_disruption -> "Enemy logistics compromised"
      :timing_window -> "Tactical advantage gained"
      :defensive_weakness -> "Strategic position secured"
      _ -> "Strategic objective achieved"
    end
  end

  defp generate_success_factors(opportunity) do
    base_factors = ["Adequate force allocation", "Operational security maintained"]

    type_factors =
      case opportunity.type do
        :territorial_expansion -> ["Supply lines secured", "Defensive positions established"]
        :resource_exploitation -> ["Extraction infrastructure ready", "Market access ensured"]
        :preemptive_action -> ["Intelligence accuracy", "Rapid execution"]
        _ -> []
      end

    base_factors ++ type_factors
  end

  defp identify_key_advantages(opportunity) do
    advantages = []

    advantages =
      if opportunity.risk_assessment.risk_level == :low do
        advantages ++ ["Low risk profile"]
      else
        advantages
      end

    advantages =
      if opportunity.viability_score > 0.8 do
        advantages ++ ["High success probability"]
      else
        advantages
      end

    advantages =
      if opportunity.timing_assessment.urgency == :low do
        advantages ++ ["Flexible timing"]
      else
        advantages
      end

    if Enum.empty?(advantages) do
      ["Strategic value"]
    else
      advantages
    end
  end

  defp determine_execution_priority(opportunity) do
    urgency = opportunity.timing_assessment.urgency
    rating = opportunity.overall_rating

    cond do
      urgency == :critical -> 1
      urgency == :high && rating > 0.8 -> 2
      rating > 0.8 -> 3
      urgency == :high -> 4
      true -> 5
    end
  end

  defp generate_risk_warnings(opportunities) do
    high_risk =
      opportunities
      |> Enum.filter(&(&1.risk_assessment.risk_level == :high))
      |> Enum.map(fn opp ->
        %{
          opportunity: opp.value_proposition,
          warning: generate_risk_warning(opp),
          mitigation_required: opp.risk_assessment.mitigation_options
        }
      end)

    time_critical =
      opportunities
      |> Enum.filter(& &1.timing_assessment.time_sensitive)
      |> Enum.map(fn opp ->
        %{
          opportunity: opp.value_proposition,
          deadline: opp.timing_assessment.optimal_window,
          consequence_of_delay: describe_delay_consequence(opp.type)
        }
      end)

    %{
      high_risk_opportunities: high_risk,
      time_critical_opportunities: time_critical
    }
  end

  defp generate_risk_warning(opportunity) do
    risk_factors = opportunity.risk_assessment.risk_factors

    factor_warnings =
      risk_factors
      |> Enum.map(fn factor ->
        case factor do
          :escalation_risk -> "May trigger larger conflict"
          :retaliation_risk -> "Expect counter-operations"
          :timing_critical -> "Window of opportunity closing"
          :active_competition -> "Other entities pursuing same objective"
          :high_stakes -> "Significant resources at risk"
          :window_closing -> "Opportunity may not recur"
          _ -> "Elevated operational risk"
        end
      end)

    Enum.join(factor_warnings, "; ")
  end

  defp describe_delay_consequence(type) do
    case type do
      :timing_window -> "Opportunity will be lost"
      :defensive_weakness -> "Enemy defenses will strengthen"
      :preemptive_action -> "Initiative will be lost"
      _ -> "Reduced success probability"
    end
  end
end
