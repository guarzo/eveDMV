defmodule EveDmv.Shared.Strategic.AssessmentCompiler do
  @moduledoc """
  Compiles comprehensive strategic assessments from various analyses.

  Responsible for:
  - Overall assessment compilation
  - Environment classification
  - Strategic posture recommendations
  - Executive summary generation
  """

  require Logger

  @doc """
  Compiles a complete strategic assessment from all analysis components.
  """
  def compile_strategic_assessment(analysis_scope, strategic_data, analysis_components) do
    %{
      pattern_analysis: pattern_analysis,
      territorial_analysis: territorial_analysis,
      resource_analysis: resource_analysis,
      trend_analysis: trend_analysis,
      opportunity_analysis: opportunity_analysis
    } = analysis_components

    environment_classification =
      classify_strategic_environment(
        pattern_analysis,
        territorial_analysis,
        resource_analysis,
        trend_analysis
      )

    strategic_posture =
      determine_strategic_posture(
        environment_classification,
        opportunity_analysis,
        trend_analysis
      )

    executive_summary =
      generate_executive_summary(
        environment_classification,
        strategic_posture,
        pattern_analysis,
        opportunity_analysis
      )

    %{
      assessment_id: generate_assessment_id(),
      generated_at: DateTime.utc_now(),
      analysis_scope: analysis_scope,
      time_period: extract_time_period(strategic_data),
      executive_summary: executive_summary,
      environment_classification: environment_classification,
      strategic_posture: strategic_posture,
      detailed_findings:
        compile_detailed_findings(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        ),
      opportunities_and_threats:
        summarize_opportunities_and_threats(
          opportunity_analysis,
          pattern_analysis
        ),
      recommended_actions:
        extract_key_recommendations(
          strategic_posture,
          opportunity_analysis
        ),
      confidence_level:
        calculate_overall_confidence(
          pattern_analysis,
          trend_analysis
        ),
      next_review_date: calculate_next_review_date(environment_classification)
    }
  end

  @doc """
  Generates a concise strategic briefing.
  """
  def generate_strategic_briefing(full_assessment) do
    %{
      briefing_date: DateTime.utc_now(),
      classification: full_assessment.environment_classification.overall_classification,
      threat_level: full_assessment.environment_classification.threat_level,
      recommended_posture: full_assessment.strategic_posture.recommended_posture,
      top_priorities: extract_top_priorities(full_assessment),
      key_metrics: extract_key_metrics(full_assessment),
      action_items: format_action_items(full_assessment.recommended_actions)
    }
  end

  # Private functions

  defp generate_assessment_id do
    timestamp = :os.system_time(:millisecond)
    # Use secure random bytes for ID generation
    random_bytes = :crypto.strong_rand_bytes(4)
    random_suffix = Base.encode16(random_bytes, case: :lower)
    "STRAT-#{timestamp}-#{random_suffix}"
  end

  defp extract_time_period(strategic_data) do
    %{
      start_date: strategic_data.time_range.since,
      end_date: strategic_data.time_range.until,
      duration_days:
        DateTime.diff(
          strategic_data.time_range.until,
          strategic_data.time_range.since,
          :day
        )
    }
  end

  defp classify_strategic_environment(
         pattern_analysis,
         territorial_analysis,
         resource_analysis,
         trend_analysis
       ) do
    threat_indicators = assess_threat_indicators(pattern_analysis)
    stability_indicators = assess_stability_indicators(territorial_analysis, trend_analysis)
    opportunity_indicators = assess_opportunity_indicators(resource_analysis, pattern_analysis)

    overall_classification =
      determine_environment_type(
        threat_indicators,
        stability_indicators,
        opportunity_indicators
      )

    %{
      overall_classification: overall_classification,
      threat_level: calculate_threat_level(threat_indicators),
      stability_assessment: calculate_stability_level(stability_indicators),
      opportunity_richness: calculate_opportunity_level(opportunity_indicators),
      environmental_factors:
        identify_environmental_factors(
          pattern_analysis,
          territorial_analysis,
          resource_analysis
        ),
      classification_confidence:
        calculate_classification_confidence(
          threat_indicators,
          stability_indicators,
          opportunity_indicators
        )
    }
  end

  defp assess_threat_indicators(pattern_analysis) do
    threatening_patterns = [:offensive_preparation, :territorial_expansion, :harassment_campaign]

    threat_count =
      pattern_analysis.identified_patterns
      |> Enum.count(&(&1.type in threatening_patterns))

    max_threat_confidence =
      pattern_analysis.identified_patterns
      |> Enum.filter(&(&1.type in threatening_patterns))
      |> Enum.map(& &1.confidence)
      |> Enum.max(fn -> 0.0 end)

    %{
      threat_pattern_count: threat_count,
      max_threat_confidence: max_threat_confidence,
      immediate_threats: threat_count > 0 && max_threat_confidence > 0.7,
      threat_diversity:
        length(Enum.uniq(Enum.map(pattern_analysis.identified_patterns, & &1.type)))
    }
  end

  defp assess_stability_indicators(territorial_analysis, trend_analysis) do
    territorial_stability =
      if territorial_analysis do
        territorial_analysis
        |> get_in([:control_zones, :zone_stability]) || 0.5
      else
        0.5
      end

    trend_stability =
      trend_analysis.trend_strength.overall_strength

    momentum_direction =
      trend_analysis.momentum.momentum_direction

    %{
      territorial_stability: territorial_stability,
      trend_stability: trend_stability,
      momentum: momentum_direction,
      volatility: Map.get(trend_analysis.activity_trends, :volatility, 0.5),
      overall_stability: (territorial_stability + trend_stability) / 2
    }
  end

  defp assess_opportunity_indicators(resource_analysis, pattern_analysis) do
    resource_opportunities =
      if resource_analysis do
        competition_level =
          get_in(resource_analysis, [:competition, :competition_intensity]) || 0.5

        # Lower competition = more opportunity
        1.0 - competition_level
      else
        0.5
      end

    pattern_opportunities =
      pattern_analysis.identified_patterns
      |> Enum.count(&(&1.type in [:reconnaissance_operation, :defensive_consolidation]))

    %{
      resource_opportunity_score: resource_opportunities,
      pattern_opportunity_count: pattern_opportunities,
      expansion_potential: pattern_opportunities > 0 && resource_opportunities > 0.5
    }
  end

  defp determine_environment_type(threat, stability, opportunity) do
    cond do
      threat.immediate_threats && stability.overall_stability < 0.4 ->
        :hostile_unstable

      threat.immediate_threats && stability.overall_stability >= 0.4 ->
        :hostile_stable

      !threat.immediate_threats && opportunity.expansion_potential ->
        :favorable_expansive

      !threat.immediate_threats && stability.overall_stability > 0.6 ->
        :favorable_stable

      stability.volatility > 0.7 ->
        :volatile_unpredictable

      true ->
        :neutral_competitive
    end
  end

  defp calculate_threat_level(threat_indicators) do
    score =
      threat_indicators.threat_pattern_count * 0.3 +
        threat_indicators.max_threat_confidence * 0.5 +
        if threat_indicators.immediate_threats, do: 0.2, else: 0.0

    cond do
      score > 0.7 -> :critical
      score > 0.5 -> :high
      score > 0.3 -> :moderate
      score > 0.1 -> :low
      true -> :minimal
    end
  end

  defp calculate_stability_level(stability_indicators) do
    cond do
      stability_indicators.overall_stability > 0.7 -> :highly_stable
      stability_indicators.overall_stability > 0.5 -> :stable
      stability_indicators.overall_stability > 0.3 -> :moderately_stable
      true -> :unstable
    end
  end

  defp calculate_opportunity_level(opportunity_indicators) do
    score =
      opportunity_indicators.resource_opportunity_score * 0.5 +
        min(1.0, opportunity_indicators.pattern_opportunity_count / 3) * 0.3 +
        if opportunity_indicators.expansion_potential, do: 0.2, else: 0.0

    cond do
      score > 0.7 -> :abundant
      score > 0.5 -> :moderate
      score > 0.3 -> :limited
      true -> :scarce
    end
  end

  defp identify_environmental_factors(pattern_analysis, territorial_analysis, resource_analysis) do
    base_factors = []

    # Pattern-based factors
    pattern_types = Enum.map(pattern_analysis.identified_patterns, & &1.type)

    pattern_factors =
      base_factors ++
        cond do
          :offensive_preparation in pattern_types -> ["Imminent conflict"]
          :harassment_campaign in pattern_types -> ["Ongoing harassment"]
          :defensive_consolidation in pattern_types -> ["Defensive posturing"]
          true -> []
        end

    # Territorial factors
    territorial_factors =
      if territorial_analysis do
        contestation =
          get_in(territorial_analysis, [:contested_areas, :contestation_intensity]) || 0

        if contestation > 0.5 do
          pattern_factors ++ ["High territorial contestation"]
        else
          pattern_factors
        end
      else
        pattern_factors
      end

    # Resource factors
    final_factors =
      if resource_analysis do
        competition = get_in(resource_analysis, [:competition, :competition_intensity]) || 0

        if competition > 0.7 do
          territorial_factors ++ ["Intense resource competition"]
        else
          territorial_factors
        end
      else
        territorial_factors
      end

    if Enum.empty?(final_factors) do
      ["Stable operational environment"]
    else
      final_factors
    end
  end

  defp calculate_classification_confidence(threat, stability, opportunity) do
    # Confidence based on indicator strength
    threat_confidence = if threat.immediate_threats, do: threat.max_threat_confidence, else: 0.5
    stability_confidence = min(1.0, abs(stability.overall_stability - 0.5) * 2)
    opportunity_confidence = opportunity.resource_opportunity_score

    Float.round((threat_confidence + stability_confidence + opportunity_confidence) / 3, 2)
  end

  defp determine_strategic_posture(
         environment_classification,
         opportunity_analysis,
         trend_analysis
       ) do
    base_posture = recommend_base_posture(environment_classification.overall_classification)

    posture_modifiers =
      assess_posture_modifiers(
        opportunity_analysis,
        trend_analysis,
        environment_classification
      )

    final_posture = adjust_posture(base_posture, posture_modifiers)

    %{
      recommended_posture: final_posture,
      posture_rationale: explain_posture_choice(final_posture, environment_classification),
      implementation_guidelines: provide_implementation_guidelines(final_posture),
      risk_tolerance: determine_risk_tolerance(final_posture, environment_classification),
      resource_allocation_guidance: suggest_resource_allocation(final_posture),
      posture_flexibility: assess_posture_flexibility(environment_classification)
    }
  end

  defp recommend_base_posture(environment_type) do
    case environment_type do
      :hostile_unstable -> :defensive_reactive
      :hostile_stable -> :defensive_proactive
      :favorable_expansive -> :aggressive_expansion
      :favorable_stable -> :controlled_growth
      :volatile_unpredictable -> :adaptive_flexible
      :neutral_competitive -> :balanced_competitive
    end
  end

  defp assess_posture_modifiers(opportunity_analysis, trend_analysis, environment) do
    base_modifiers = []

    # Opportunity modifiers
    high_value_opportunities =
      opportunity_analysis.prioritized_opportunities
      |> Enum.count(&(&1.priority_score > 0.8))

    opportunity_modifiers =
      if high_value_opportunities >= 3 do
        base_modifiers ++ [:opportunity_rich]
      else
        base_modifiers
      end

    # Trend modifiers
    trend_modifiers =
      case trend_analysis.momentum.momentum_direction do
        :strong_positive -> opportunity_modifiers ++ [:positive_momentum]
        :strong_negative -> opportunity_modifiers ++ [:negative_momentum]
        _ -> opportunity_modifiers
      end

    # Threat modifiers
    final_modifiers =
      if environment.threat_level in [:critical, :high] do
        trend_modifiers ++ [:high_threat]
      else
        trend_modifiers
      end

    final_modifiers
  end

  defp adjust_posture(base_posture, modifiers) do
    cond do
      :high_threat in modifiers && base_posture in [:aggressive_expansion, :controlled_growth] ->
        :defensive_proactive

      :opportunity_rich in modifiers && :positive_momentum in modifiers ->
        :aggressive_expansion

      :negative_momentum in modifiers ->
        :defensive_reactive

      true ->
        base_posture
    end
  end

  defp explain_posture_choice(posture, environment) do
    base_explanation =
      case posture do
        :defensive_reactive ->
          "Reactive defense required due to immediate threats and instability"

        :defensive_proactive ->
          "Proactive defense to maintain position against identified threats"

        :aggressive_expansion ->
          "Aggressive expansion to capitalize on favorable conditions"

        :controlled_growth ->
          "Controlled growth to build on stable foundation"

        :adaptive_flexible ->
          "Flexible approach required due to unpredictable environment"

        :balanced_competitive ->
          "Balanced approach for competitive environment"
      end

    environmental_context =
      " Environment classified as #{environment.overall_classification} " <>
        "with #{environment.threat_level} threat level."

    base_explanation <> environmental_context
  end

  defp provide_implementation_guidelines(posture) do
    case posture do
      :defensive_reactive ->
        [
          "Concentrate forces at critical systems",
          "Establish early warning networks",
          "Prepare rapid response teams",
          "Minimize extended operations"
        ]

      :defensive_proactive ->
        [
          "Fortify border systems",
          "Conduct preemptive strikes on threats",
          "Maintain strong intelligence network",
          "Build defensive alliances"
        ]

      :aggressive_expansion ->
        [
          "Identify and prioritize expansion targets",
          "Build invasion fleets",
          "Secure supply lines for extended operations",
          "Prepare occupation forces"
        ]

      :controlled_growth ->
        [
          "Focus on adjacent system acquisition",
          "Develop infrastructure in new territories",
          "Maintain defensive reserves",
          "Build sustainable logistics"
        ]

      :adaptive_flexible ->
        [
          "Maintain mobile reserve forces",
          "Develop multiple contingency plans",
          "Focus on intelligence gathering",
          "Build versatile fleet compositions"
        ]

      :balanced_competitive ->
        [
          "Balance offensive and defensive capabilities",
          "Engage in limited conflicts",
          "Maintain diplomatic flexibility",
          "Optimize resource efficiency"
        ]
    end
  end

  defp determine_risk_tolerance(posture, environment) do
    base_tolerance =
      case posture do
        :aggressive_expansion -> :high
        :controlled_growth -> :moderate
        :balanced_competitive -> :moderate
        :adaptive_flexible -> :variable
        :defensive_proactive -> :low
        :defensive_reactive -> :minimal
      end

    # Adjust for threat level
    if environment.threat_level in [:critical, :high] do
      case base_tolerance do
        :high -> :moderate
        :moderate -> :low
        _ -> :minimal
      end
    else
      base_tolerance
    end
  end

  defp suggest_resource_allocation(posture) do
    case posture do
      :defensive_reactive ->
        %{military: 80, infrastructure: 10, intelligence: 10}

      :defensive_proactive ->
        %{military: 70, infrastructure: 15, intelligence: 15}

      :aggressive_expansion ->
        %{military: 75, infrastructure: 15, intelligence: 10}

      :controlled_growth ->
        %{military: 50, infrastructure: 35, intelligence: 15}

      :adaptive_flexible ->
        %{military: 60, infrastructure: 20, intelligence: 20}

      :balanced_competitive ->
        %{military: 55, infrastructure: 30, intelligence: 15}
    end
  end

  defp assess_posture_flexibility(environment) do
    volatility = Map.get(environment, :volatility, 0.5)

    cond do
      volatility > 0.7 -> :highly_flexible
      volatility > 0.4 -> :moderately_flexible
      true -> :stable_commitment
    end
  end

  defp generate_executive_summary(environment, posture, pattern_analysis, opportunity_analysis) do
    %{
      headline: generate_headline(environment, posture),
      key_findings: compile_key_findings(environment, pattern_analysis, opportunity_analysis),
      strategic_situation: summarize_strategic_situation(environment, posture),
      recommended_course: summarize_recommended_course(posture, opportunity_analysis),
      critical_factors: identify_critical_success_factors(environment, posture),
      decision_timeline: suggest_decision_timeline(environment, pattern_analysis)
    }
  end

  defp generate_headline(environment, posture) do
    threat_descriptor =
      case environment.threat_level do
        :critical -> "Critical threat"
        :high -> "High threat"
        :moderate -> "Moderate threat"
        _ -> "Low threat"
      end

    posture_descriptor =
      case posture.recommended_posture do
        :aggressive_expansion -> "aggressive expansion recommended"
        :defensive_reactive -> "immediate defensive measures required"
        :defensive_proactive -> "proactive defense advised"
        :controlled_growth -> "controlled growth opportunity"
        :adaptive_flexible -> "flexible adaptation necessary"
        :balanced_competitive -> "balanced approach optimal"
      end

    "#{threat_descriptor} environment - #{posture_descriptor}"
  end

  defp compile_key_findings(environment, pattern_analysis, opportunity_analysis) do
    base_findings = []

    # Environment findings
    environment_findings =
      base_findings ++
        [
          "Strategic environment: #{environment.overall_classification}",
          "Threat level: #{environment.threat_level}",
          "Stability: #{environment.stability_assessment}"
        ]

    # Pattern findings
    dominant_pattern = pattern_analysis.dominant_pattern

    pattern_findings =
      if dominant_pattern do
        environment_findings ++ ["Dominant pattern: #{dominant_pattern}"]
      else
        environment_findings
      end

    # Opportunity findings
    opportunity_count = opportunity_analysis.total_opportunities

    final_findings =
      if opportunity_count > 0 do
        pattern_findings ++ ["#{opportunity_count} strategic opportunities identified"]
      else
        pattern_findings
      end

    Enum.take(final_findings, 5)
  end

  defp summarize_strategic_situation(environment, posture) do
    stability_desc =
      case environment.stability_assessment do
        :highly_stable -> "highly stable"
        :stable -> "stable"
        :moderately_stable -> "moderately stable"
        :unstable -> "unstable"
      end

    opportunity_desc =
      case environment.opportunity_richness do
        :abundant -> "abundant opportunities"
        :moderate -> "moderate opportunities"
        :limited -> "limited opportunities"
        :scarce -> "scarce opportunities"
      end

    "Operating in a #{stability_desc} environment with #{opportunity_desc}. " <>
      "#{posture.posture_rationale}"
  end

  defp summarize_recommended_course(posture, opportunity_analysis) do
    best_opportunities =
      opportunity_analysis.best_opportunities
      |> Enum.take(3)
      |> Enum.map(& &1.value_proposition)

    posture_action = List.first(posture.implementation_guidelines)

    if Enum.empty?(best_opportunities) do
      posture_action
    else
      "#{posture_action}. Priority opportunities: #{Enum.join(best_opportunities, ", ")}"
    end
  end

  defp identify_critical_success_factors(environment, posture) do
    base_factors =
      case posture.recommended_posture do
        :aggressive_expansion -> ["Superior force concentration", "Supply line security"]
        :defensive_reactive -> ["Rapid response capability", "Intelligence accuracy"]
        :defensive_proactive -> ["Border fortification", "Preemptive strike capability"]
        :controlled_growth -> ["Infrastructure development", "Local superiority"]
        :adaptive_flexible -> ["Operational flexibility", "Multi-scenario planning"]
        :balanced_competitive -> ["Resource efficiency", "Diplomatic options"]
      end

    threat_factors =
      if environment.threat_level in [:critical, :high] do
        ["Threat neutralization", "Alliance cohesion"]
      else
        []
      end

    Enum.uniq(base_factors ++ threat_factors) |> Enum.take(4)
  end

  defp suggest_decision_timeline(environment, pattern_analysis) do
    urgent_patterns = [:offensive_preparation, :defensive_weakness, :timing_window]

    has_urgent_patterns =
      pattern_analysis.identified_patterns
      |> Enum.any?(&(&1.type in urgent_patterns))

    if environment.threat_level == :critical || has_urgent_patterns do
      "Immediate action required - decision within 24 hours"
    else
      case environment.threat_level do
        :high -> "Decision required within 48 hours"
        :moderate -> "Decision recommended within 72 hours"
        _ -> "Standard planning timeline appropriate"
      end
    end
  end

  defp compile_detailed_findings(
         pattern_analysis,
         territorial_analysis,
         resource_analysis,
         trend_analysis
       ) do
    %{
      pattern_findings: summarize_pattern_findings(pattern_analysis),
      territorial_findings: summarize_territorial_findings(territorial_analysis),
      resource_findings: summarize_resource_findings(resource_analysis),
      trend_findings: summarize_trend_findings(trend_analysis),
      cross_domain_insights:
        generate_cross_domain_insights(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )
    }
  end

  defp summarize_pattern_findings(pattern_analysis) do
    %{
      patterns_identified: length(pattern_analysis.identified_patterns),
      dominant_pattern: pattern_analysis.dominant_pattern,
      pattern_confidence: pattern_analysis.overall_confidence,
      pattern_relationships: summarize_relationships(pattern_analysis.pattern_relationships),
      pattern_implications: derive_pattern_implications(pattern_analysis.identified_patterns)
    }
  end

  defp summarize_relationships(relationships) do
    relationships
    |> Enum.take(3)
    |> Enum.map(fn rel ->
      %{
        patterns: rel.patterns,
        relationship_type: rel.relationship_type,
        strength: rel.strength
      }
    end)
  end

  defp derive_pattern_implications(patterns) do
    patterns
    |> Enum.map(fn pattern ->
      case pattern.type do
        :offensive_preparation -> "Enemy offensive likely within 48-72 hours"
        :territorial_expansion -> "Territory under pressure from expansion"
        :defensive_consolidation -> "Enemy strengthening defensive positions"
        :resource_control -> "Resource competition intensifying"
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.take(3)
  end

  defp summarize_territorial_findings(territorial_analysis) do
    if territorial_analysis do
      %{
        control_zones: length(territorial_analysis.control_zones),
        zone_stability: territorial_analysis.zone_stability,
        contested_areas: Map.get(territorial_analysis.contested_areas, :contested_count, 0),
        expansion_opportunities: length(territorial_analysis.expansion_opportunities),
        territorial_assessment: territorial_analysis.territorial_assessment
      }
    else
      %{
        control_zones: 0,
        zone_stability: 0.0,
        contested_areas: 0,
        expansion_opportunities: 0,
        territorial_assessment: nil
      }
    end
  end

  defp summarize_resource_findings(resource_analysis) do
    if resource_analysis do
      %{
        resource_activity_level: classify_resource_activity(resource_analysis.resource_activity),
        competition_intensity:
          get_in(resource_analysis, [:competition, :competition_intensity]) || 0.0,
        control_stability:
          get_in(resource_analysis, [:control_stability, :overall_stability]) || 0.0,
        strategic_value: get_in(resource_analysis, [:strategic_value, :overall_value]) || 0.0,
        key_recommendations: Enum.take(resource_analysis.recommendations, 2)
      }
    else
      %{
        resource_activity_level: :unknown,
        competition_intensity: 0.0,
        control_stability: 0.0,
        strategic_value: 0.0,
        key_recommendations: []
      }
    end
  end

  defp classify_resource_activity(activity) do
    mining_losses = get_in(activity, [:mining_activity, :mining_losses]) || 0
    hauling_losses = get_in(activity, [:hauling_activity, :hauling_losses]) || 0

    total_activity = mining_losses + hauling_losses

    cond do
      total_activity >= 20 -> :very_high
      total_activity >= 10 -> :high
      total_activity >= 5 -> :moderate
      total_activity >= 1 -> :low
      true -> :minimal
    end
  end

  defp summarize_trend_findings(trend_analysis) do
    %{
      trend_direction: trend_analysis.activity_trends.trend_direction,
      trend_strength: trend_analysis.activity_trends.trend_strength,
      momentum: trend_analysis.momentum.overall_momentum,
      momentum_direction: trend_analysis.momentum.momentum_direction,
      inflection_points: length(trend_analysis.inflection_points),
      forecast_summary: summarize_forecast(trend_analysis.trend_prediction)
    }
  end

  defp summarize_forecast(prediction) do
    %{
      short_term: prediction.short_term_outlook,
      medium_term: prediction.medium_term_outlook,
      confidence: prediction.confidence_level,
      key_scenario: List.first(prediction.likely_scenarios) || "Status quo continuation"
    }
  end

  defp generate_cross_domain_insights(
         pattern_analysis,
         territorial_analysis,
         resource_analysis,
         trend_analysis
       ) do
    base_insights = []

    # Pattern-territorial insights
    territorial_insights =
      if pattern_analysis.dominant_pattern == :territorial_expansion && territorial_analysis do
        contested = get_in(territorial_analysis, [:contested_areas, :contested_count]) || 0

        if contested > 3 do
          base_insights ++
            ["Territorial expansion pattern aligns with high contestation - expect conflicts"]
        else
          base_insights
        end
      else
        base_insights
      end

    # Resource-trend insights
    resource_insights =
      if resource_analysis && trend_analysis.momentum.momentum_direction == :strong_positive do
        competition = get_in(resource_analysis, [:competition, :competition_intensity]) || 0

        if competition < 0.3 do
          territorial_insights ++
            ["Low resource competition with positive momentum - expansion opportunity"]
        else
          territorial_insights
        end
      else
        territorial_insights
      end

    # Pattern-trend insights
    final_insights =
      if pattern_analysis.dominant_pattern == :offensive_preparation &&
           trend_analysis.momentum.momentum_direction == :strong_negative do
        resource_insights ++
          ["Offensive preparation during negative momentum - desperation attack likely"]
      else
        resource_insights
      end

    if Enum.empty?(final_insights) do
      ["No significant cross-domain correlations identified"]
    else
      final_insights
    end
  end

  defp summarize_opportunities_and_threats(opportunity_analysis, pattern_analysis) do
    %{
      opportunities: %{
        total_count: opportunity_analysis.total_opportunities,
        high_value_count:
          Enum.count(opportunity_analysis.prioritized_opportunities, &(&1.priority_score > 0.8)),
        best_opportunity:
          format_best_opportunity(List.first(opportunity_analysis.best_opportunities)),
        opportunity_categories: summarize_opportunity_categories(opportunity_analysis)
      },
      threats: %{
        identified_threats: identify_threats_from_patterns(pattern_analysis),
        threat_severity: assess_overall_threat_severity(pattern_analysis),
        mitigation_priorities: suggest_threat_mitigation_priorities(pattern_analysis)
      },
      net_assessment: calculate_net_position(opportunity_analysis, pattern_analysis)
    }
  end

  defp format_best_opportunity(nil), do: "No significant opportunities identified"

  defp format_best_opportunity(opportunity) do
    "#{opportunity.value_proposition} (Score: #{format_percentage(opportunity.opportunity_score)})"
  end

  defp format_percentage(value), do: "#{round(value * 100)}%"

  defp summarize_opportunity_categories(opportunity_analysis) do
    opportunity_analysis.prioritized_opportunities
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category, opps} ->
      {category, length(opps)}
    end)
    |> Map.new()
  end

  defp identify_threats_from_patterns(pattern_analysis) do
    threat_patterns = [:offensive_preparation, :territorial_expansion, :harassment_campaign]

    pattern_analysis.identified_patterns
    |> Enum.filter(&(&1.type in threat_patterns))
    |> Enum.map(fn pattern ->
      %{
        threat_type: pattern.type,
        confidence: pattern.confidence,
        severity: assess_threat_severity(pattern)
      }
    end)
  end

  defp assess_threat_severity(pattern) do
    case pattern.type do
      :offensive_preparation -> if pattern.confidence > 0.7, do: :critical, else: :high
      :territorial_expansion -> if pattern.confidence > 0.6, do: :high, else: :moderate
      :harassment_campaign -> :moderate
      _ -> :low
    end
  end

  defp assess_overall_threat_severity(pattern_analysis) do
    threats = identify_threats_from_patterns(pattern_analysis)

    if Enum.empty?(threats) do
      :minimal
    else
      severities = Enum.map(threats, & &1.severity)

      cond do
        :critical in severities -> :critical
        :high in severities -> :high
        :moderate in severities -> :moderate
        true -> :low
      end
    end
  end

  defp suggest_threat_mitigation_priorities(pattern_analysis) do
    threats = identify_threats_from_patterns(pattern_analysis)

    threats
    |> Enum.sort_by(fn threat ->
      severity_score =
        case threat.severity do
          :critical -> 0
          :high -> 1
          :moderate -> 2
          :low -> 3
        end

      severity_score - threat.confidence
    end)
    |> Enum.take(3)
    |> Enum.map(fn threat ->
      %{
        threat: threat.threat_type,
        priority: determine_mitigation_priority(threat),
        suggested_response: suggest_mitigation_response(threat.threat_type)
      }
    end)
  end

  defp determine_mitigation_priority(threat) do
    case threat.severity do
      :critical -> "Immediate"
      :high -> "Within 24 hours"
      :moderate -> "Within 48 hours"
      :low -> "Monitor"
    end
  end

  defp suggest_mitigation_response(threat_type) do
    case threat_type do
      :offensive_preparation -> "Defensive mobilization and preemptive strikes"
      :territorial_expansion -> "Border reinforcement and containment"
      :harassment_campaign -> "Anti-harassment patrols and trap operations"
      _ -> "Standard defensive measures"
    end
  end

  defp calculate_net_position(opportunity_analysis, pattern_analysis) do
    opportunity_score =
      opportunity_analysis.prioritized_opportunities
      |> Enum.take(5)
      |> Enum.map(& &1.priority_score)
      |> Enum.sum()
      |> Kernel./(5)

    threat_score =
      pattern_analysis.identified_patterns
      |> Enum.filter(
        &(&1.type in [:offensive_preparation, :territorial_expansion, :harassment_campaign])
      )
      |> Enum.map(& &1.confidence)
      |> Enum.sum()
      |> Kernel./(3)

    net_score = opportunity_score - threat_score

    assessment =
      cond do
        net_score > 0.3 -> :strongly_favorable
        net_score > 0.1 -> :favorable
        net_score > -0.1 -> :balanced
        net_score > -0.3 -> :unfavorable
        true -> :strongly_unfavorable
      end

    %{
      net_score: Float.round(net_score, 3),
      assessment: assessment,
      recommendation: recommend_based_on_net_position(assessment)
    }
  end

  defp recommend_based_on_net_position(assessment) do
    case assessment do
      :strongly_favorable -> "Aggressive pursuit of opportunities"
      :favorable -> "Selective opportunity exploitation"
      :balanced -> "Maintain current posture with flexibility"
      :unfavorable -> "Defensive focus with limited initiatives"
      :strongly_unfavorable -> "Full defensive posture"
    end
  end

  defp extract_key_recommendations(strategic_posture, opportunity_analysis) do
    posture_recommendations =
      strategic_posture.implementation_guidelines
      |> Enum.take(3)
      |> Enum.map(fn guideline ->
        %{
          category: :strategic_posture,
          recommendation: guideline,
          priority: :high,
          timeframe: :immediate
        }
      end)

    opportunity_recommendations =
      opportunity_analysis.best_opportunities
      |> Enum.take(2)
      |> Enum.map(fn opp ->
        %{
          category: :opportunity,
          recommendation: "Pursue: #{opp.value_proposition}",
          priority: classify_opportunity_priority(opp),
          timeframe: determine_opportunity_timeframe(opp)
        }
      end)

    all_recommendations = posture_recommendations ++ opportunity_recommendations

    all_recommendations
    |> Enum.sort_by(fn rec ->
      priority_value =
        case rec.priority do
          :critical -> 0
          :high -> 1
          :medium -> 2
          :low -> 3
        end

      timeframe_value =
        case rec.timeframe do
          :immediate -> 0
          :short_term -> 1
          :medium_term -> 2
          :long_term -> 3
        end

      priority_value + timeframe_value
    end)
  end

  defp classify_opportunity_priority(opportunity) do
    cond do
      opportunity.priority_score > 0.9 -> :critical
      opportunity.priority_score > 0.7 -> :high
      opportunity.priority_score > 0.5 -> :medium
      true -> :low
    end
  end

  defp determine_opportunity_timeframe(opportunity) do
    case Map.get(opportunity, :risk_level, :medium) do
      :low -> :medium_term
      :medium -> :short_term
      :high -> :immediate
    end
  end

  defp calculate_overall_confidence(pattern_analysis, trend_analysis) do
    pattern_confidence = pattern_analysis.overall_confidence

    trend_confidence =
      if trend_analysis.activity_trends.trend_direction != :insufficient_data do
        trend_analysis.trend_strength.overall_strength
      else
        0.5
      end

    prediction_confidence =
      Map.get(trend_analysis.trend_prediction, :confidence_level, 0.5)

    overall = (pattern_confidence + trend_confidence + prediction_confidence) / 3

    %{
      overall_confidence: Float.round(overall, 3),
      confidence_level: classify_confidence_level(overall),
      confidence_factors: %{
        pattern_analysis: pattern_confidence,
        trend_analysis: trend_confidence,
        predictions: prediction_confidence
      }
    }
  end

  defp classify_confidence_level(confidence) do
    cond do
      confidence > 0.8 -> :very_high
      confidence > 0.6 -> :high
      confidence > 0.4 -> :moderate
      confidence > 0.2 -> :low
      true -> :very_low
    end
  end

  defp calculate_next_review_date(environment_classification) do
    days_until_review =
      case environment_classification.overall_classification do
        :hostile_unstable -> 1
        :hostile_stable -> 2
        :volatile_unpredictable -> 2
        :neutral_competitive -> 3
        :favorable_stable -> 5
        :favorable_expansive -> 3
      end

    DateTime.utc_now()
    |> DateTime.add(days_until_review * 24 * 3600, :second)
    |> DateTime.truncate(:second)
  end

  defp extract_top_priorities(assessment) do
    assessment.recommended_actions
    |> Enum.filter(&(&1.priority in [:critical, :high]))
    |> Enum.take(3)
    |> Enum.map(& &1.recommendation)
  end

  defp extract_key_metrics(assessment) do
    %{
      threat_level: assessment.environment_classification.threat_level,
      stability: assessment.environment_classification.stability_assessment,
      opportunities: assessment.opportunities_and_threats.opportunities.total_count,
      confidence: assessment.confidence_level.confidence_level,
      net_position: assessment.opportunities_and_threats.net_assessment.assessment
    }
  end

  defp format_action_items(recommendations) do
    recommendations
    |> Enum.map(fn rec ->
      %{
        action: rec.recommendation,
        due: format_timeframe(rec.timeframe),
        owner: "Strategic Command",
        status: :pending
      }
    end)
  end

  defp format_timeframe(timeframe) do
    case timeframe do
      :immediate -> "Within 24 hours"
      :short_term -> "Within 72 hours"
      :medium_term -> "Within 1 week"
      :long_term -> "Within 1 month"
    end
  end
end
