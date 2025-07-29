defmodule EveDmv.Contexts.Intelligence.Services.InsightGenerator do
  @moduledoc """
  Service for generating tactical insights, mitigation strategies, and engagement recommendations.
  """
  
  alias EveDmv.Contexts.Intelligence.Core.{
    ThreatAssessmentEngine,
    CharacterAnalyzer,
    BehavioralPatternAnalyzer,
    PerformanceAnalyzer
  }
  alias EveDmv.Platform.Cache.Intelligence.IntelligenceCache
  
  require Logger
  
  @cache_ttl :timer.hours(1)
  
  @doc """
  Generate comprehensive insights for a character.
  """
  def generate_insights(character_id) do
    cache_key = {:character_insights, character_id}
    
    IntelligenceCache.get_or_compute(cache_key, fn ->
      compile_character_insights(character_id)
    end, ttl: @cache_ttl)
  end
  
  @doc """
  Get threat mitigation strategies for a character.
  """
  def get_threat_mitigation_strategies(character_id) do
    case ThreatAssessmentEngine.assess_threat(character_id, include_mitigation: true) do
      {:ok, assessment} ->
        strategies = Map.get(assessment, :mitigation_strategies, [])
        enhanced_strategies = enhance_mitigation_strategies(assessment, strategies)
        {:ok, enhanced_strategies}
        
      error -> error
    end
  end
  
  @doc """
  Generate engagement recommendations for attacker vs target scenario.
  """
  def get_engagement_recommendations(attacker_id, target_id) do
    cache_key = {:engagement_recommendation, attacker_id, target_id}
    
    IntelligenceCache.get_or_compute(cache_key, fn ->
      generate_engagement_analysis(attacker_id, target_id)
    end, ttl: @cache_ttl)
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
        strategic_recommendations: generate_strategic_recommendations(threat_assessment, character_analysis),
        vulnerability_analysis: analyze_vulnerabilities(character_analysis, behavioral_patterns),
        opportunity_assessment: assess_opportunities(character_analysis, behavioral_patterns),
        intelligence_priorities: identify_intelligence_priorities(threat_assessment, character_analysis),
        generated_at: DateTime.utc_now()
      }
      
      {:ok, insights}
    end
  end
  
  defp generate_tactical_insights(threat_assessment, character_analysis) do
    insights = []
    
    # Threat-based insights
    insights = case threat_assessment.threat_level do
      :critical ->
        ["PRIORITY TARGET - Requires immediate attention and resources" | insights]
      :high ->
        ["HIGH VALUE TARGET - Significant threat requiring careful planning" | insights]
      _ -> insights
    end
    
    # Combat pattern insights
    insights = case character_analysis.classifications.pilot_type do
      :elite_solo_hunter ->
        ["Exceptional solo combat capability - avoid 1v1 engagements",
         "Likely to disengage if outnumbered significantly" | insights]
      :fleet_pilot ->
        ["Fleet-oriented pilot - most dangerous with backup",
         "May be vulnerable when caught alone" | insights]
      :gang_specialist ->
        ["Small gang specialist - expect coordinated tactics",
         "Optimal threat level in 3-10 person groups" | insights]
      _ -> insights
    end
    
    # Ship preference insights
    ship_data = character_analysis.data[:ship_preferences] || %{}
    if ship_data[:capital_usage] && ship_data[:capital_usage] > 0.1 do
      insights = ["Capital ship pilot - potential for escalation" | insights]
    end
    
    # Engagement style insights
    insights = case character_analysis.classifications.engagement_style do
      :hot_dropper ->
        ["Uses surprise capital drops - monitor for cyno ships",
         "Likely has capital backup on standby" | insights]
      :gate_camper ->
        ["Gate camp specialist - check common routes",
         "May use scouts on adjacent gates" | insights]
      :roamer ->
        ["Roaming pilot - unpredictable movement patterns",
         "May be part of larger roaming gang" | insights]
      :home_defender ->
        ["Home defense specialist - most dangerous in home systems",
         "Likely has local knowledge advantage" | insights]
      _ -> insights
    end
    
    Enum.reverse(insights)
  end
  
  defp generate_behavioral_insights(behavioral_patterns) do
    insights = []
    
    # Activity pattern insights
    case behavioral_patterns.activity_patterns.activity_level do
      :very_high ->
        insights = ["Extremely active pilot - high encounter probability" | insights]
      :hyperactive ->
        insights = ["Hyperactive pilot - likely online frequently" | insights]
      _ -> insights
    end
    
    # Timezone insights
    if behavioral_patterns.timezone != "Unknown" do
      insights = ["Primary timezone: #{behavioral_patterns.timezone} - plan operations accordingly" | insights]
    end
    
    # Predictability insights
    case behavioral_patterns.predictability do
      score when score > 0.7 ->
        insights = ["Highly predictable patterns - good target for planned operations" | insights]
      score when score < 0.3 ->
        insights = ["Unpredictable behavior - difficult to track and predict" | insights]
      _ -> insights
    end
    
    # Geographic insights
    geo_prefs = behavioral_patterns.geographic_preferences
    if geo_prefs.roaming_range == :local do
      insights = ["Local operator - limited to small geographic area" | insights]
    end
    
    if geo_prefs.roaming_range == :nomadic do
      insights = ["Nomadic pilot - operates across wide geographic areas" | insights]
    end
    
    # Gang preference insights
    gang_prefs = behavioral_patterns.gang_preferences
    case gang_prefs.preferred_size do
      :solo ->
        insights = ["Solo specialist - most dangerous alone" | insights]
      :fleet ->
        insights = ["Fleet pilot - strength multiplied by numbers" | insights]
      _ -> insights
    end
    
    Enum.reverse(insights)
  end
  
  defp generate_performance_insights(performance_analysis) do
    insights = []
    core_metrics = performance_analysis.core_metrics
    
    # K/D ratio insights
    if core_metrics.kill_death_ratio > 5.0 do
      insights = ["Exceptional K/D ratio (#{core_metrics.kill_death_ratio}) - highly skilled pilot" | insights]
    end
    
    # ISK efficiency insights
    if core_metrics.isk_efficiency > 80 do
      insights = ["High ISK efficiency (#{core_metrics.isk_efficiency}%) - selective target engagement" | insights]
    end
    
    # Solo effectiveness insights
    if core_metrics.solo_effectiveness > 70 do
      insights = ["Strong solo pilot - dangerous in 1v1 situations" | insights]
    end
    
    # Versatility insights
    if core_metrics.versatility_score > 70 do
      insights = ["Highly versatile pilot - adaptable to various situations" | insights]
    end
    
    # Improvement trend insights
    improvement = performance_analysis.improvement_metrics
    if improvement.improvement_rate > 20 do
      insights = ["Rapidly improving pilot - threat level increasing" | insights]
    end
    
    if improvement.improvement_rate < -20 do
      insights = ["Declining performance - may be less active or losing effectiveness" | insights]
    end
    
    # Consistency insights
    if core_metrics.consistency_score > 70 do
      insights = ["Consistent performance - reliable threat assessment" | insights]
    end
    
    Enum.reverse(insights)
  end
  
  defp generate_strategic_recommendations(threat_assessment, character_analysis) do
    recommendations = []
    
    # Engagement recommendations based on threat level
    recommendations = case threat_assessment.threat_level do
      :critical ->
        ["Deploy overwhelming force (3:1 minimum advantage)",
         "Ensure multiple escape routes planned",
         "Consider avoiding engagement unless strategic necessity" | recommendations]
      :high ->
        ["Use numerical advantage (2:1 minimum)",
         "Coordinate with allies before engagement",
         "Have backup plans ready" | recommendations]
      :moderate ->
        ["Standard engagement protocols apply",
         "Maintain situational awareness",
         "Be prepared for escalation" | recommendations]
      _ ->
        ["Normal engagement rules apply" | recommendations]
    end
    
    # Tactical recommendations based on pilot type
    recommendations = case character_analysis.classifications.pilot_type do
      :elite_solo_hunter ->
        ["Never engage solo",
         "Use overwhelming numbers",
         "Consider this pilot a priority elimination target" | recommendations]
      :fleet_pilot ->
        ["Most vulnerable when alone",
         "Monitor for fleet backup",
         "Consider hit-and-run tactics" | recommendations]
      _ -> recommendations
    end
    
    # Ship-based recommendations
    ship_data = character_analysis.data[:ship_preferences] || %{}
    if ship_data[:capital_usage] && ship_data[:capital_usage] > 0.2 do
      recommendations = ["Prepare for capital escalation",
                        "Have anti-capital ships ready" | recommendations]
    end
    
    Enum.reverse(recommendations)
  end
  
  defp analyze_vulnerabilities(character_analysis, behavioral_patterns) do
    vulnerabilities = []
    
    # Behavioral vulnerabilities
    if behavioral_patterns.predictability > 0.7 do
      vulnerabilities = [%{
        type: :behavioral,
        description: "Highly predictable activity patterns",
        severity: :medium,
        exploitation: "Plan operations during predicted active times and locations"
      } | vulnerabilities]
    end
    
    # Combat vulnerabilities
    combat_data = character_analysis.data[:combat_stats] || %{}
    if combat_data[:solo_ratio] && combat_data[:solo_ratio] > 0.8 do
      vulnerabilities = [%{
        type: :tactical,
        description: "Over-reliance on solo combat",
        severity: :high,
        exploitation: "Use coordinated group tactics to overwhelm"
      } | vulnerabilities]
    end
    
    # Geographic vulnerabilities
    geo_prefs = behavioral_patterns.geographic_preferences
    if length(geo_prefs[:home_systems] || []) > 0 do
      vulnerabilities = [%{
        type: :geographic,
        description: "Operates from identifiable home systems",
        severity: :low,
        exploitation: "Set up camps or intelligence networks in home areas"
      } | vulnerabilities]
    end
    
    # Ship vulnerabilities
    ship_data = character_analysis.data[:ship_preferences] || %{}
    if ship_data[:ship_diversity] && ship_data[:ship_diversity] < 3 do
      vulnerabilities = [%{
        type: :tactical,
        description: "Limited ship diversity",
        severity: :low,
        exploitation: "Prepare counters for known ship preferences"
      } | vulnerabilities]
    end
    
    vulnerabilities
  end
  
  defp assess_opportunities(character_analysis, behavioral_patterns) do
    opportunities = []
    
    # Recruitment opportunities
    if character_analysis.classifications.skill_level in [:veteran, :elite] do
      opportunities = [%{
        type: :recruitment,
        description: "High-skill pilot suitable for recruitment",
        priority: :high,
        approach: "Diplomatic engagement, demonstrate organizational value"
      } | opportunities]
    end
    
    # Intelligence opportunities
    if behavioral_patterns.predictability > 0.6 do
      opportunities = [%{
        type: :intelligence,
        description: "Predictable patterns allow intelligence gathering",
        priority: :medium,
        approach: "Establish surveillance networks in operational areas"
      } | opportunities]
    end
    
    # Tactical opportunities
    combat_data = character_analysis.data[:combat_stats] || %{}
    if combat_data[:solo_ratio] && combat_data[:solo_ratio] > 0.7 do
      opportunities = [%{
        type: :tactical,
        description: "Solo preference creates isolation opportunities",
        priority: :medium,
        approach: "Coordinate multi-vector attacks during solo operations"
      } | opportunities]
    end
    
    opportunities
  end
  
  defp identify_intelligence_priorities(threat_assessment, character_analysis) do
    priorities = []
    
    # High-threat pilots are priority intelligence targets
    if threat_assessment.threat_level in [:critical, :high] do
      priorities = [%{
        category: :threat_monitoring,
        priority: :high,
        focus: "Continuous activity monitoring and pattern analysis",
        resources_required: ["Dedicated surveillance", "Network infiltration"]
      } | priorities]
    end
    
    # Unknown or unpredictable pilots need more data
    if character_analysis.risk_profile.predictability < 0.4 do
      priorities = [%{
        category: :behavioral_analysis,
        priority: :medium,
        focus: "Extended behavioral pattern collection",
        resources_required: ["Long-term observation", "Activity correlation"]
      } | priorities]
    end
    
    # Fleet pilots need network analysis
    if character_analysis.classifications.pilot_type in [:fleet_pilot, :gang_specialist] do
      priorities = [%{
        category: :network_analysis,
        priority: :medium,
        focus: "Associate mapping and organizational structure",
        resources_required: ["Social network analysis", "Communication monitoring"]
      } | priorities]
    end
    
    priorities
  end
  
  defp enhance_mitigation_strategies(assessment, base_strategies) do
    enhanced = []
    
    # Enhance based on specific threat aspects
    if assessment.aspect_scores.combat_effectiveness > 70 do
      enhanced = [%{
        strategy: "Combat Superiority Mitigation",
        tactics: ["Maintain 2:1+ numerical advantage", "Use range/kiting tactics", "Coordinate focus fire"],
        reasoning: "High combat effectiveness requires overwhelming force"
      } | enhanced]
    end
    
    if assessment.aspect_scores.tactical_sophistication > 70 do
      enhanced = [%{
        strategy: "Tactical Counter-measures",
        tactics: ["Expect advanced fits and unusual tactics", "Prepare for baiting attempts", "Use simple, proven strategies"],
        reasoning: "High tactical sophistication requires conservative approach"
      } | enhanced]
    end
    
    if assessment.aspect_scores.operational_security > 70 do
      enhanced = [%{
        strategy: "Intelligence Warfare",
        tactics: ["Use multiple intelligence sources", "Expect counter-intelligence", "Maintain operational security"],
        reasoning: "High operational security requires advanced intelligence methods"
      } | enhanced]
    end
    
    # Add base strategies as simple tactical notes
    base_enhanced = Enum.map(base_strategies, fn strategy ->
      %{
        strategy: strategy,
        tactics: [],
        reasoning: "Based on threat assessment algorithm"
      }
    end)
    
    enhanced ++ base_enhanced
  end
  
  defp generate_engagement_analysis(attacker_id, target_id) do
    with {:ok, attacker_analysis} <- CharacterAnalyzer.get_character_profile(attacker_id),
         {:ok, target_analysis} <- CharacterAnalyzer.get_character_profile(target_id) do
      
      analysis = %{
        attacker_id: attacker_id,
        target_id: target_id,
        power_comparison: compare_power_levels(attacker_analysis, target_analysis),
        tactical_matchup: analyze_tactical_matchup(attacker_analysis, target_analysis),
        engagement_recommendations: generate_specific_engagement_recs(attacker_analysis, target_analysis),
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
      {hot_dropper: :roamer} => :favorable,
      {gate_camper: :roamer} => :favorable,
      {roamer: :home_defender} => :unfavorable,
      {solo_specialist: :fleet_pilot} => :unfavorable
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
      experience_advantage: cond do
        attacker_level > target_level + 1 -> :significant_attacker_advantage
        attacker_level > target_level -> :moderate_attacker_advantage
        attacker_level == target_level -> :equal
        attacker_level < target_level - 1 -> :significant_target_advantage
        true -> :moderate_target_advantage
      end
    }
  end
  
  defp generate_specific_engagement_recs(attacker, target) do
    recommendations = []
    
    # Based on threat comparison
    target_threat = target.threat_assessment.overall_score
    
    recommendations = if target_threat > 70 do
      ["HIGH RISK TARGET - Consider avoiding unless tactical necessity" | recommendations]
    else
      recommendations
    end
    
    # Based on tactical matchup
    target_style = target.analysis.classifications.engagement_style
    
    recommendations = case target_style do
      :hot_dropper ->
        ["Beware of capital backup", "Monitor for cyno ships", "Have escape plan ready" | recommendations]
      :gate_camper ->
        ["Avoid predictable routes", "Use scouts", "Consider alternative paths" | recommendations]
      _ -> recommendations
    end
    
    Enum.reverse(recommendations)
  end
  
  defp calculate_success_probability(attacker, target) do
    # Simplified probability calculation
    attacker_score = attacker.threat_assessment.overall_score
    target_score = target.threat_assessment.overall_score
    
    # Base probability from threat comparison
    base_prob = if target_score > 0 do
      (attacker_score / (attacker_score + target_score)) * 100
    else
      90.0  # Very high if target has no threat rating
    end
    
    # Adjust for various factors
    adjusted_prob = base_prob
    
    # Solo vs gang preferences
    if attacker.analysis.classifications.pilot_type == :solo_specialist and
       target.analysis.classifications.pilot_type == :fleet_pilot do
      adjusted_prob = adjusted_prob * 1.2  # Solo specialists better against fleet pilots alone
    end
    
    Float.round(min(adjusted_prob, 95.0), 1)  # Cap at 95%
  end
  
  defp assess_engagement_risk(attacker, target) do
    risks = []
    
    # High threat target risks
    if target.threat_assessment.threat_level in [:critical, :high] do
      risks = ["Significant loss probability", "Potential for counter-attack" | risks]
    end
    
    # Capital escalation risks
    target_data = target.analysis.data[:ship_preferences] || %{}
    if target_data[:capital_usage] && target_data[:capital_usage] > 0.1 do
      risks = ["Capital escalation possible", "May have backup capitals" | risks]
    end
    
    # Fleet backup risks
    if target.analysis.classifications.pilot_type in [:fleet_pilot, :gang_specialist] do
      risks = ["Likely has backup available", "May be bait for larger engagement" | risks]
    end
    
    %{
      risk_factors: risks,
      overall_risk: determine_overall_risk(target.threat_assessment.threat_level, length(risks))
    }
  end
  
  defp determine_overall_risk(:critical, _), do: :very_high
  defp determine_overall_risk(:high, risk_count) when risk_count > 2, do: :very_high
  defp determine_overall_risk(:high, _), do: :high
  defp determine_overall_risk(:moderate, risk_count) when risk_count > 3, do: :high
  defp determine_overall_risk(:moderate, _), do: :medium
  defp determine_overall_risk(_, risk_count) when risk_count > 2, do: :medium
  defp determine_overall_risk(_, _), do: :low
end