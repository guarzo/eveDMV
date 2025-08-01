defmodule EveDmv.Contexts.Intelligence.Services.InsightGenerator do
  @moduledoc """
  Service for generating tactical insights, mitigation strategies, and engagement recommendations.
  """

  alias EveDmv.Cache
  alias EveDmv.Contexts.Intelligence.Core.BehavioralPatternAnalyzer
  alias EveDmv.Contexts.Intelligence.Core.CharacterAnalyzer
  alias EveDmv.Contexts.Intelligence.Core.PerformanceAnalyzer
  alias EveDmv.Contexts.Intelligence.Core.ThreatAssessmentEngine

  require Logger

  @cache_ttl :timer.hours(1)

  @doc """
  Generate comprehensive insights for a character.
  """
  @spec generate_insights(integer()) :: {:ok, map()} | {:error, atom()}
  def generate_insights(character_id) do
    cache_key = {:character_insights, character_id}

    case Cache.get_or_compute(
           :analysis,
           cache_key,
           fn ->
             compile_character_insights(character_id)
           end,
           ttl: @cache_ttl
         ) do
      {:ok, insights} -> {:ok, insights}
      {:error, reason} -> {:error, reason}
      result -> result
    end
  end

  @doc """
  Get threat mitigation strategies for a character.
  """
  @spec get_threat_mitigation_strategies(integer()) :: {:ok, [map()]} | {:error, atom()}
  def get_threat_mitigation_strategies(character_id) do
    case ThreatAssessmentEngine.assess_threat(character_id, include_mitigation: true) do
      {:ok, assessment} ->
        strategies = Map.get(assessment, :mitigation_strategies, [])
        enhanced_strategies = enhance_mitigation_strategies(assessment, strategies)
        {:ok, enhanced_strategies}

      error ->
        error
    end
  end

  @doc """
  Generate engagement recommendations for attacker vs target scenario.
  """
  @spec get_engagement_recommendations(integer(), integer()) :: {:ok, map()} | {:error, atom()}
  def get_engagement_recommendations(attacker_id, target_id) do
    cache_key = {:engagement_recommendation, attacker_id, target_id}

    case Cache.get_or_compute(
           :analysis,
           cache_key,
           fn ->
             generate_engagement_analysis(attacker_id, target_id)
           end,
           ttl: @cache_ttl
         ) do
      {:ok, analysis} -> {:ok, analysis}
      {:error, reason} -> {:error, reason}
      result -> result
    end
  end

  # Private Functions

  defp compile_character_insights(character_id) do
    with {:ok, threat_assessment} <- ThreatAssessmentEngine.assess_threat(character_id),
         {:ok, character_analysis} <- CharacterAnalyzer.analyze_character(character_id),
         {:ok, behavioral_patterns} <- BehavioralPatternAnalyzer.analyze_behavior(character_id),
         {:ok, performance_analysis} <- PerformanceAnalyzer.analyze_performance(character_id) do
      insights = %{
        character_id: character_id,
        tactical_insights: generate_tactical_insights(threat_assessment, character_analysis),
        behavioral_insights: generate_behavioral_insights(behavioral_patterns),
        performance_insights: generate_performance_insights(performance_analysis),
        strategic_recommendations:
          generate_strategic_recommendations(threat_assessment, character_analysis),
        vulnerability_analysis: analyze_vulnerabilities(character_analysis, behavioral_patterns),
        opportunity_assessment: assess_opportunities(character_analysis, behavioral_patterns),
        intelligence_priorities:
          identify_intelligence_priorities(threat_assessment, character_analysis),
        generated_at: DateTime.utc_now()
      }

      {:ok, insights}
    end
  end

  defp generate_tactical_insights(threat_assessment, character_analysis) do
    ship_data = character_analysis.data[:ship_preferences] || %{}

    threat_cases = %{
      critical: "PRIORITY TARGET - Requires immediate attention and resources",
      high: "HIGH VALUE TARGET - Significant threat requiring careful planning"
    }

    pilot_type_cases = %{
      elite_solo_hunter: [
        "Exceptional solo combat capability - avoid 1v1 engagements",
        "Likely to disengage if outnumbered significantly"
      ],
      fleet_pilot: [
        "Fleet-oriented pilot - most dangerous with backup",
        "May be vulnerable when caught alone"
      ],
      gang_specialist: [
        "Small gang specialist - expect coordinated tactics",
        "Optimal threat level in 3-10 person groups"
      ]
    }

    engagement_style_cases = %{
      hot_dropper: [
        "Uses surprise capital drops - monitor for cyno ships",
        "Likely has capital backup on standby"
      ],
      gate_camper: [
        "Gate camp specialist - check common routes",
        "May use scouts on adjacent gates"
      ],
      roamer: [
        "Roaming pilot - unpredictable movement patterns",
        "May be part of larger roaming gang"
      ],
      home_defender: [
        "Home defense specialist - most dangerous in home systems",
        "Likely has local knowledge advantage"
      ]
    }

    []
    |> add_case_insights(threat_assessment.threat_level, threat_cases)
    |> add_case_insights(character_analysis.classifications.pilot_type, pilot_type_cases)
    |> add_insights_for(
      ship_data[:capital_usage] && ship_data[:capital_usage] > 0.1,
      "Capital ship pilot - potential for escalation"
    )
    |> add_case_insights(
      character_analysis.classifications.engagement_style,
      engagement_style_cases
    )
    |> Enum.reverse()
  end

  defp generate_behavioral_insights(behavioral_patterns) do
    insights = []

    # Activity pattern insights
    activity_insights =
      case behavioral_patterns.activity_patterns.activity_level do
        :very_high ->
          ["Extremely active pilot - high encounter probability" | insights]

        :hyperactive ->
          ["Hyperactive pilot - likely online frequently" | insights]

        _ ->
          insights
      end

    # Timezone insights
    timezone_insights =
      if behavioral_patterns.timezone != "Unknown" do
        [
          "Primary timezone: #{behavioral_patterns.timezone} - plan operations accordingly"
          | activity_insights
        ]
      else
        activity_insights
      end

    # Predictability insights
    predictability_insights =
      case behavioral_patterns.predictability do
        score when score > 0.7 ->
          ["Highly predictable patterns - good target for planned operations" | timezone_insights]

        score when score < 0.3 ->
          ["Unpredictable behavior - difficult to track and predict" | timezone_insights]

        _ ->
          timezone_insights
      end

    # Geographic insights
    geo_prefs = behavioral_patterns.geographic_preferences

    geographic_insights =
      if geo_prefs.roaming_range == :local do
        ["Local operator - limited to small geographic area" | predictability_insights]
      else
        predictability_insights
      end

    nomadic_insights =
      if geo_prefs.roaming_range == :nomadic do
        ["Nomadic pilot - operates across wide geographic areas" | geographic_insights]
      else
        geographic_insights
      end

    # Gang preference insights
    gang_prefs = behavioral_patterns.gang_preferences

    gang_size_insights =
      case gang_prefs.preferred_size do
        :solo ->
          ["Solo specialist - most dangerous alone" | nomadic_insights]

        :fleet ->
          ["Fleet pilot - strength multiplied by numbers" | nomadic_insights]

        _ ->
          nomadic_insights
      end

    Enum.reverse(gang_size_insights)
  end

  defp generate_performance_insights(performance_analysis) do
    insights = []
    core_metrics = performance_analysis.core_metrics

    # K/D ratio insights
    kd_insights =
      if core_metrics.kill_death_ratio > 5.0 do
        [
          "Exceptional K/D ratio (#{core_metrics.kill_death_ratio}) - highly skilled pilot"
          | insights
        ]
      else
        insights
      end

    # ISK efficiency insights
    isk_insights =
      if core_metrics.isk_efficiency > 80 do
        [
          "High ISK efficiency (#{core_metrics.isk_efficiency}%) - selective target engagement"
          | kd_insights
        ]
      else
        kd_insights
      end

    # Solo effectiveness insights
    solo_insights =
      if core_metrics.solo_effectiveness > 70 do
        ["Strong solo pilot - dangerous in 1v1 situations" | isk_insights]
      else
        isk_insights
      end

    # Versatility insights
    versatility_insights =
      if core_metrics.versatility_score > 70 do
        ["Highly versatile pilot - adaptable to various situations" | solo_insights]
      else
        solo_insights
      end

    # Improvement trend insights
    improvement = performance_analysis.improvement_metrics

    improvement_insights =
      if improvement.improvement_rate > 20 do
        ["Rapidly improving pilot - threat level increasing" | versatility_insights]
      else
        versatility_insights
      end

    decline_insights =
      if improvement.improvement_rate < -20 do
        [
          "Declining performance - may be less active or losing effectiveness"
          | improvement_insights
        ]
      else
        improvement_insights
      end

    # Consistency insights
    final_insights =
      if core_metrics.consistency_score > 70 do
        ["Consistent performance - reliable threat assessment" | decline_insights]
      else
        decline_insights
      end

    Enum.reverse(final_insights)
  end

  defp generate_strategic_recommendations(threat_assessment, character_analysis) do
    recommendations = []

    # Engagement recommendations based on threat level
    threat_recommendations =
      case threat_assessment.threat_level do
        :critical ->
          [
            "Deploy overwhelming force (3:1 minimum advantage)",
            "Ensure multiple escape routes planned",
            "Consider avoiding engagement unless strategic necessity" | recommendations
          ]

        :high ->
          [
            "Use numerical advantage (2:1 minimum)",
            "Coordinate with allies before engagement",
            "Have backup plans ready" | recommendations
          ]

        :moderate ->
          [
            "Standard engagement protocols apply",
            "Maintain situational awareness",
            "Be prepared for escalation" | recommendations
          ]

        _ ->
          ["Normal engagement rules apply" | recommendations]
      end

    # Tactical recommendations based on pilot type
    tactical_recommendations =
      case character_analysis.classifications.pilot_type do
        :elite_solo_hunter ->
          [
            "Never engage solo",
            "Use overwhelming numbers",
            "Consider this pilot a priority elimination target" | threat_recommendations
          ]

        :fleet_pilot ->
          [
            "Most vulnerable when alone",
            "Monitor for fleet backup",
            "Consider hit-and-run tactics" | threat_recommendations
          ]

        _ ->
          threat_recommendations
      end

    # Ship-based recommendations
    ship_data = character_analysis.data[:ship_preferences] || %{}

    ship_recommendations =
      if ship_data[:capital_usage] && ship_data[:capital_usage] > 0.2 do
        [
          "Prepare for capital escalation",
          "Have anti-capital ships ready" | tactical_recommendations
        ]
      else
        tactical_recommendations
      end

    # Based on tactical matchup - Note: this section needs character_analysis parameter for target
    # Removing this section until proper implementation
    final_tactical_recommendations = ship_recommendations

    _disabled_tactical_recommendations =
      case :placeholder do
        :hot_dropper ->
          [
            "Beware of capital backup",
            "Monitor for cyno ships",
            "Have escape plan ready" | ship_recommendations
          ]

        :gate_camper ->
          [
            "Avoid predictable routes",
            "Use scouts",
            "Consider alternative paths" | ship_recommendations
          ]

        _ ->
          ship_recommendations
      end

    Enum.reverse(final_tactical_recommendations)
  end

  defp analyze_vulnerabilities(character_analysis, behavioral_patterns) do
    initial_vulnerabilities = []

    # Behavioral vulnerabilities
    behavioral_vulnerabilities =
      if behavioral_patterns.predictability > 0.7 do
        [
          %{
            type: :behavioral,
            description: "Highly predictable activity patterns",
            severity: :medium,
            exploitation: "Plan operations during predicted active times and locations"
          }
          | initial_vulnerabilities
        ]
      else
        initial_vulnerabilities
      end

    # Combat vulnerabilities
    combat_data = character_analysis.data[:combat_stats] || %{}

    combat_vulnerabilities =
      if combat_data[:solo_ratio] && combat_data[:solo_ratio] > 0.8 do
        [
          %{
            type: :tactical,
            description: "Over-reliance on solo combat",
            severity: :high,
            exploitation: "Use coordinated group tactics to overwhelm"
          }
          | behavioral_vulnerabilities
        ]
      else
        behavioral_vulnerabilities
      end

    # Geographic vulnerabilities
    geo_prefs = behavioral_patterns.geographic_preferences

    geographic_vulnerabilities =
      if length(geo_prefs[:home_systems] || []) > 0 do
        [
          %{
            type: :geographic,
            description: "Operates from identifiable home systems",
            severity: :low,
            exploitation: "Set up camps or intelligence networks in home areas"
          }
          | combat_vulnerabilities
        ]
      else
        combat_vulnerabilities
      end

    # Ship vulnerabilities
    ship_data = character_analysis.data[:ship_preferences] || %{}

    final_vulnerabilities =
      if ship_data[:ship_diversity] && ship_data[:ship_diversity] < 3 do
        [
          %{
            type: :tactical,
            description: "Limited ship diversity",
            severity: :low,
            exploitation: "Prepare counters for known ship preferences"
          }
          | geographic_vulnerabilities
        ]
      else
        geographic_vulnerabilities
      end

    final_vulnerabilities
  end

  defp assess_opportunities(character_analysis, behavioral_patterns) do
    initial_opportunities = []

    # Recruitment opportunities
    recruitment_opportunities =
      if character_analysis.classifications.skill_level in [:veteran, :elite] do
        [
          %{
            type: :recruitment,
            description: "High-skill pilot suitable for recruitment",
            priority: :high,
            approach: "Diplomatic engagement, demonstrate organizational value"
          }
          | initial_opportunities
        ]
      else
        initial_opportunities
      end

    # Intelligence opportunities
    intelligence_opportunities =
      if behavioral_patterns.predictability > 0.6 do
        [
          %{
            type: :intelligence,
            description: "Predictable patterns allow intelligence gathering",
            priority: :medium,
            approach: "Establish surveillance networks in operational areas"
          }
          | recruitment_opportunities
        ]
      else
        recruitment_opportunities
      end

    # Tactical opportunities
    combat_data = character_analysis.data[:combat_stats] || %{}

    tactical_opportunities =
      if combat_data[:solo_ratio] && combat_data[:solo_ratio] > 0.7 do
        [
          %{
            type: :tactical,
            description: "Solo preference creates isolation opportunities",
            priority: :medium,
            approach: "Coordinate multi-vector attacks during solo operations"
          }
          | intelligence_opportunities
        ]
      else
        intelligence_opportunities
      end

    tactical_opportunities
  end

  defp identify_intelligence_priorities(threat_assessment, character_analysis) do
    initial_priorities = []

    # High-threat pilots are priority intelligence targets
    threat_priorities =
      if threat_assessment.threat_level in [:critical, :high] do
        [
          %{
            category: :threat_monitoring,
            priority: :high,
            focus: "Continuous activity monitoring and pattern analysis",
            resources_required: ["Dedicated surveillance", "Network infiltration"]
          }
          | initial_priorities
        ]
      else
        initial_priorities
      end

    # Unknown or unpredictable pilots need more data
    behavioral_priorities =
      if character_analysis.risk_profile.predictability < 0.4 do
        [
          %{
            category: :behavioral_analysis,
            priority: :medium,
            focus: "Extended behavioral pattern collection",
            resources_required: ["Long-term observation", "Activity correlation"]
          }
          | threat_priorities
        ]
      else
        threat_priorities
      end

    # Fleet pilots need network analysis
    final_priorities =
      if character_analysis.classifications.pilot_type in [:fleet_pilot, :gang_specialist] do
        [
          %{
            category: :network_analysis,
            priority: :medium,
            focus: "Associate mapping and organizational structure",
            resources_required: ["Social network analysis", "Communication monitoring"]
          }
          | behavioral_priorities
        ]
      else
        behavioral_priorities
      end

    final_priorities
  end

  defp enhance_mitigation_strategies(assessment, base_strategies) do
    initial_enhanced = []

    # Enhance based on specific threat aspects
    combat_enhanced =
      if assessment.aspect_scores.combat_effectiveness > 70 do
        [
          %{
            strategy: "Combat Superiority Mitigation",
            tactics: [
              "Maintain 2:1+ numerical advantage",
              "Use range/kiting tactics",
              "Coordinate focus fire"
            ],
            reasoning: "High combat effectiveness requires overwhelming force"
          }
          | initial_enhanced
        ]
      else
        initial_enhanced
      end

    tactical_enhanced =
      if assessment.aspect_scores.tactical_sophistication > 70 do
        [
          %{
            strategy: "Tactical Counter-measures",
            tactics: [
              "Expect advanced fits and unusual tactics",
              "Prepare for baiting attempts",
              "Use simple, proven strategies"
            ],
            reasoning: "High tactical sophistication requires conservative approach"
          }
          | combat_enhanced
        ]
      else
        combat_enhanced
      end

    opsec_enhanced =
      if assessment.aspect_scores.operational_security > 70 do
        [
          %{
            strategy: "Intelligence Warfare",
            tactics: [
              "Use multiple intelligence sources",
              "Expect counter-intelligence",
              "Maintain operational security"
            ],
            reasoning: "High operational security requires advanced intelligence methods"
          }
          | tactical_enhanced
        ]
      else
        tactical_enhanced
      end

    # Add base strategies as simple tactical notes
    base_enhanced =
      Enum.map(base_strategies, fn strategy ->
        %{
          strategy: strategy,
          tactics: [],
          reasoning: "Based on threat assessment algorithm"
        }
      end)

    opsec_enhanced ++ base_enhanced
  end

  defp generate_engagement_analysis(attacker_id, target_id) do
    with {:ok, attacker_analysis} <- CharacterAnalyzer.get_character_profile(attacker_id),
         {:ok, target_analysis} <- CharacterAnalyzer.get_character_profile(target_id) do
      analysis = %{
        attacker_id: attacker_id,
        target_id: target_id,
        power_comparison: compare_power_levels(attacker_analysis, target_analysis),
        tactical_matchup: analyze_tactical_matchup(attacker_analysis, target_analysis),
        engagement_recommendations:
          generate_specific_engagement_recs(attacker_analysis, target_analysis),
        success_probability: calculate_success_probability(attacker_analysis, target_analysis),
        risk_assessment: assess_engagement_risk(attacker_analysis, target_analysis),
        analyzed_at: DateTime.utc_now()
      }

      {:ok, analysis}
    end
  end

  defp compare_power_levels(attacker, target) do
    attacker_threat = attacker.threat_assessment.overall_score
    target_threat = target.threat_assessment.overall_score

    power_ratio = if target_threat > 0, do: attacker_threat / target_threat, else: attacker_threat

    %{
      attacker_threat_score: attacker_threat,
      target_threat_score: target_threat,
      power_ratio: Float.round(power_ratio, 2),
      advantage: determine_advantage(power_ratio)
    }
  end

  defp determine_advantage(ratio) do
    cond do
      ratio > 1.5 -> :strong_attacker_advantage
      ratio > 1.2 -> :moderate_attacker_advantage
      ratio > 0.8 -> :balanced
      ratio > 0.6 -> :moderate_target_advantage
      true -> :strong_target_advantage
    end
  end

  defp analyze_tactical_matchup(attacker, target) do
    # Compare specific tactical aspects
    %{
      combat_matchup: compare_combat_styles(attacker, target),
      ship_matchup: compare_ship_preferences(attacker, target),
      experience_matchup: compare_experience_levels(attacker, target)
    }
  end

  defp compare_combat_styles(attacker, target) do
    attacker_style = attacker.analysis.classifications.engagement_style
    target_style = target.analysis.classifications.engagement_style

    matchup_matrix = %{
      {:hot_dropper, :roamer} => :favorable,
      {:gate_camper, :roamer} => :favorable,
      {:roamer, :home_defender} => :unfavorable,
      {:solo_specialist, :fleet_pilot} => :unfavorable
    }

    result = Map.get(matchup_matrix, {attacker_style, target_style}, :neutral)

    %{
      attacker_style: attacker_style,
      target_style: target_style,
      matchup_result: result
    }
  end

  defp compare_ship_preferences(_attacker, _target) do
    # Simplified ship preference comparison
    %{
      matchup_result: :neutral,
      notes: ["Ship preference analysis requires more detailed data"]
    }
  end

  defp compare_experience_levels(attacker, target) do
    attacker_skill = attacker.analysis.classifications.skill_level
    target_skill = target.analysis.classifications.skill_level

    skill_levels = [:novice, :intermediate, :experienced, :veteran, :elite]
    attacker_level = Enum.find_index(skill_levels, &(&1 == attacker_skill)) || 0
    target_level = Enum.find_index(skill_levels, &(&1 == target_skill)) || 0

    %{
      attacker_skill: attacker_skill,
      target_skill: target_skill,
      experience_advantage:
        cond do
          attacker_level > target_level + 1 -> :significant_attacker_advantage
          attacker_level > target_level -> :moderate_attacker_advantage
          attacker_level == target_level -> :equal
          attacker_level < target_level - 1 -> :significant_target_advantage
          true -> :moderate_target_advantage
        end
    }
  end

  defp generate_specific_engagement_recs(_attacker, target) do
    recommendations = []

    # Based on threat comparison
    target_threat = target.threat_assessment.overall_score

    final_recommendations =
      if target_threat > 70 do
        ["HIGH RISK TARGET - Consider avoiding unless tactical necessity" | recommendations]
      else
        recommendations
      end

    final_recommendations
  end

  defp calculate_success_probability(attacker, target) do
    # Simplified probability calculation
    attacker_score = attacker.threat_assessment.overall_score
    target_score = target.threat_assessment.overall_score

    # Base probability from threat comparison
    base_prob =
      if target_score > 0 do
        attacker_score / (attacker_score + target_score) * 100
      else
        # Very high if target has no threat rating
        90.0
      end

    # Adjust for various factors
    initial_adjusted_prob = base_prob

    # Solo vs gang preferences
    final_adjusted_prob =
      if attacker.analysis.classifications.pilot_type == :solo_specialist and
           target.analysis.classifications.pilot_type == :fleet_pilot do
        # Solo specialists better against fleet pilots alone
        initial_adjusted_prob * 1.2
      else
        initial_adjusted_prob
      end

    # Cap at 95%
    Float.round(min(final_adjusted_prob, 95.0), 1)
  end

  defp assess_engagement_risk(_attacker, target) do
    initial_risks = []

    # High threat target risks
    threat_risks =
      if target.threat_assessment.threat_level in [:critical, :high] do
        ["Significant loss probability", "Potential for counter-attack" | initial_risks]
      else
        initial_risks
      end

    # Capital escalation risks
    target_data = target.analysis.data[:ship_preferences] || %{}

    capital_risks =
      if target_data[:capital_usage] && target_data[:capital_usage] > 0.1 do
        ["Capital escalation possible", "May have backup capitals" | threat_risks]
      else
        threat_risks
      end

    # Fleet backup risks
    final_risks =
      if target.analysis.classifications.pilot_type in [:fleet_pilot, :gang_specialist] do
        ["Likely has backup available", "May be bait for larger engagement" | capital_risks]
      else
        capital_risks
      end

    %{
      risk_factors: final_risks,
      overall_risk:
        determine_overall_risk(target.threat_assessment.threat_level, length(final_risks))
    }
  end

  defp determine_overall_risk(:critical, _), do: :very_high
  defp determine_overall_risk(:high, risk_count) when risk_count > 2, do: :very_high
  defp determine_overall_risk(:high, _), do: :high
  defp determine_overall_risk(:moderate, risk_count) when risk_count > 3, do: :high
  defp determine_overall_risk(:moderate, _), do: :medium
  defp determine_overall_risk(_, risk_count) when risk_count > 2, do: :medium
  defp determine_overall_risk(_, _), do: :low

  # Helper functions for building insight lists
  defp add_insights_for(insights, condition, new_insights) when is_list(new_insights) do
    if condition, do: new_insights ++ insights, else: insights
  end

  defp add_insights_for(insights, condition, new_insight) do
    if condition, do: [new_insight | insights], else: insights
  end

  defp add_case_insights(insights, value, cases) do
    case Map.get(cases, value) do
      nil -> insights
      new_insights when is_list(new_insights) -> new_insights ++ insights
      new_insight -> [new_insight | insights]
    end
  end
end
