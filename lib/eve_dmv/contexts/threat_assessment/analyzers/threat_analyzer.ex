defmodule EveDmv.Contexts.ThreatAssessment.Analyzers.ThreatAnalyzer do
  @moduledoc """
  Comprehensive threat analysis engine for the Threat Assessment context.

  Analyzes pilots and corporations to assess threat levels, detect bait scenarios,
  and provide real-time threat assessment for wormhole chain surveillance.

  Provides multi-faceted threat analysis including:
  - Individual pilot threat scoring
  - Bait probability assessment
  - Corporation and alliance standing analysis
  - Recent activity pattern analysis
  - Associate network analysis
  - Bulk threat assessment capabilities
  """

  use EveDmv.ErrorHandler
  alias EveDmv.Result
  alias EveDmv.Contexts.ThreatAssessment.Infrastructure.ThreatDataProvider
  alias EveDmv.Contexts.ThreatAssessment.Infrastructure.StandingsRepository

  require Logger

  # Threat score thresholds
  @hostile_threshold 80
  @neutral_threshold 40
  @friendly_threshold 20

  # Bait probability thresholds
  @high_bait_threshold 70
  @moderate_bait_threshold 50
  @low_bait_threshold 30

  @doc """
  Analyze a pilot and return comprehensive threat assessment.
  
  Returns detailed threat analysis including threat level, bait probability,
  activity patterns, and associate analysis.
  """
  def analyze(character_id, base_data \\ %{}, opts \\ []) when is_integer(character_id) do
    try do
      corporation_id = Keyword.get(opts, :corporation_id) || Map.get(base_data, :corporation_id)
      alliance_id = Keyword.get(opts, :alliance_id) || Map.get(base_data, :alliance_id)
      
      with {:ok, character_stats} <- get_character_stats(base_data, character_id),
           {:ok, recent_activity} <- get_recent_activity(base_data, character_id),
           {:ok, associates} <- find_known_associates(base_data, character_id),
           {:ok, standings} <- analyze_standings(corporation_id, alliance_id) do
        
        threat_score = calculate_threat_score(character_stats, recent_activity)
        bait_probability = calculate_bait_probability(character_id, associates, recent_activity)
        threat_level = determine_threat_level(threat_score, standings)
        
        analysis = %{
          character_id: character_id,
          corporation_id: corporation_id,
          alliance_id: alliance_id,
          
          # Core threat assessment
          threat_level: threat_level,
          threat_score: threat_score,
          bait_probability: bait_probability,
          
          # Analysis components
          character_stats: character_stats,
          recent_activity: recent_activity,
          known_associates_count: length(associates),
          
          # Standings analysis
          corporation_standing: standings.corporation_standing,
          alliance_standing: standings.alliance_standing,
          standing_override: standings.standing_override,
          
          # Risk factors
          risk_factors: identify_risk_factors(character_stats, recent_activity, associates),
          warning_indicators: build_warning_indicators(threat_score, bait_probability, recent_activity),
          
          # Detailed insights
          analysis_reason: build_comprehensive_analysis_reason(threat_level, threat_score, bait_probability, standings),
          behavioral_patterns: analyze_behavioral_patterns(character_stats, recent_activity),
          threat_confidence: calculate_threat_confidence(character_stats, recent_activity, standings),
          
          # Metadata
          analysis_timestamp: DateTime.utc_now(),
          data_quality: assess_data_quality(character_stats, recent_activity)
        }
        
        Result.ok(analysis)
      else
        {:error, _reason} = error -> error
      end
    rescue
      exception -> Result.error(:analysis_failed, "Threat analysis error: #{inspect(exception)}")
    end
  end

  @doc """
  Bulk analyze multiple pilots for efficient threat assessment.
  
  Optimizes analysis by batching data collection and processing
  multiple pilots simultaneously.
  """
  def analyze_pilots(pilot_list, base_data \\ %{}, opts \\ []) when is_list(pilot_list) do
    try do
      batch_size = Keyword.get(opts, :batch_size, 50)
      include_details = Keyword.get(opts, :include_details, false)
      
      if length(pilot_list) > batch_size do
        Logger.warning("Batch size #{length(pilot_list)} exceeds recommended limit #{batch_size}")
      end
      
      # Process pilots in parallel
      tasks = 
        pilot_list
        |> Enum.map(fn {character_id, corp_id, alliance_id} ->
          Task.async(fn ->
            case analyze(character_id, base_data, corporation_id: corp_id, alliance_id: alliance_id) do
              {:ok, result} -> 
                analysis = if include_details, do: result, else: summarize_analysis(result)
                {character_id, {:ok, analysis}}
              {:error, reason} -> 
                {character_id, {:error, reason}}
            end
          end)
        end)
      
      # Collect results with timeout
      results = 
        tasks
        |> Task.await_many(30_000)
        |> Enum.filter(fn
          {_id, {:ok, _result}} -> true
          {id, {:error, reason}} ->
            Logger.warning("Failed to analyze pilot #{id}: #{inspect(reason)}")
            false
        end)
        |> Enum.map(fn {id, {:ok, result}} -> {id, result} end)
        |> Map.new()
      
      Result.ok(%{
        total_analyzed: map_size(results),
        successful_analyses: map_size(results),
        threat_summary: generate_threat_summary(results),
        pilot_analyses: results
      })
    rescue
      exception -> Result.error(:bulk_analysis_failed, "Bulk threat analysis error: #{inspect(exception)}")
    end
  end

  @doc """
  Analyze threat patterns for a system or constellation.
  
  Provides aggregate threat assessment for multiple entities
  in a specific location or context.
  """
  def analyze_system_threats(system_id, inhabitants, base_data \\ %{}, opts \\ []) do
    try do
      with {:ok, bulk_analysis} <- analyze_pilots(inhabitants, base_data, opts) do
        
        system_analysis = %{
          system_id: system_id,
          total_inhabitants: length(inhabitants),
          threat_distribution: calculate_threat_distribution(bulk_analysis.pilot_analyses),
          dominant_threat_level: determine_dominant_threat_level(bulk_analysis.pilot_analyses),
          bait_risk_assessment: assess_system_bait_risk(bulk_analysis.pilot_analyses),
          coordinated_threat_indicators: detect_coordinated_threats(bulk_analysis.pilot_analyses),
          recommended_engagement_strategy: recommend_engagement_strategy(bulk_analysis.pilot_analyses),
          system_threat_score: calculate_system_threat_score(bulk_analysis.pilot_analyses)
        }
        
        Result.ok(system_analysis)
      else
        {:error, _reason} = error -> error
      end
    rescue
      exception -> Result.error(:system_analysis_failed, "System threat analysis error: #{inspect(exception)}")
    end
  end

  @doc """
  Update threat intelligence for system inhabitants.
  
  Efficiently updates threat assessments for multiple pilots
  with optimized data collection and processing.
  """
  def update_inhabitant_threats(inhabitant_ids, base_data \\ %{}, opts \\ []) when is_list(inhabitant_ids) do
    try do
      results = 
        inhabitant_ids
        |> Enum.map(fn inhabitant_id ->
          case update_single_inhabitant_threat(inhabitant_id, base_data, opts) do
            {:ok, result} -> {inhabitant_id, :success, result}
            {:error, reason} -> {inhabitant_id, :error, reason}
          end
        end)
      
      {successful, failed} = Enum.split_with(results, fn {_id, status, _result} -> status == :success end)
      
      Result.ok(%{
        total_processed: length(inhabitant_ids),
        successful_updates: length(successful),
        failed_updates: length(failed),
        update_results: results
      })
    rescue
      exception -> Result.error(:update_failed, "Inhabitant threat update error: #{inspect(exception)}")
    end
  end

  # Private implementation functions

  defp get_character_stats(base_data, character_id) do
    case Map.get(base_data, :character_stats) do
      nil -> ThreatDataProvider.get_character_stats(character_id)
      stats -> {:ok, stats}
    end
  end

  defp get_recent_activity(base_data, character_id) do
    case Map.get(base_data, :recent_activity) do
      nil -> ThreatDataProvider.get_recent_activity(character_id, 30)
      activity -> {:ok, activity}
    end
  end

  defp find_known_associates(base_data, character_id) do
    case Map.get(base_data, :associates) do
      nil -> ThreatDataProvider.find_known_associates(character_id, 90)
      associates -> {:ok, associates}
    end
  end

  defp analyze_standings(corporation_id, alliance_id) do
    corp_standing = if corporation_id, do: StandingsRepository.check_corporation_standing(corporation_id), else: nil
    alliance_standing = if alliance_id, do: StandingsRepository.check_alliance_standing(alliance_id), else: nil
    
    standing_override = determine_standing_override(corp_standing, alliance_standing)
    
    {:ok, %{
      corporation_standing: corp_standing,
      alliance_standing: alliance_standing,
      standing_override: standing_override
    }}
  end

  defp calculate_threat_score(character_stats, recent_activity) do
    base_score = 50
    
    stats_modifier = calculate_stats_modifier(character_stats)
    activity_modifier = calculate_activity_modifier(recent_activity)
    kd_modifier = calculate_kd_modifier(recent_activity)
    value_modifier = calculate_value_modifier(recent_activity)
    experience_modifier = calculate_experience_modifier(character_stats)
    
    final_score = base_score + stats_modifier + activity_modifier + kd_modifier + value_modifier + experience_modifier
    clamp_score(final_score)
  end

  defp calculate_stats_modifier(character_stats) do
    if character_stats do
      dangerous_score = character_stats.dangerous_score || 0
      solo_kill_percentage = character_stats.solo_kill_percentage || 0
      pvp_score = character_stats.pvp_score || 0
      
      dangerous_score * 0.25 + solo_kill_percentage * 0.15 + pvp_score * 0.1
    else
      0
    end
  end

  defp calculate_activity_modifier(recent_activity) do
    kills = recent_activity.recent_kills || 0
    
    cond do
      kills > 20 -> 25
      kills > 10 -> 20
      kills > 5 -> 15
      kills > 2 -> 10
      kills > 0 -> 5
      true -> -15
    end
  end

  defp calculate_kd_modifier(recent_activity) do
    kd_ratio = recent_activity.kill_death_ratio || 0
    
    cond do
      kd_ratio > 10.0 -> 20
      kd_ratio > 5.0 -> 15
      kd_ratio > 3.0 -> 12
      kd_ratio > 2.0 -> 10
      kd_ratio > 1.0 -> 5
      kd_ratio > 0.5 -> 0
      true -> -5
    end
  end

  defp calculate_value_modifier(recent_activity) do
    avg_kill_value = recent_activity.avg_kill_value || 0
    avg_loss_value = recent_activity.avg_loss_value || 0
    
    kill_value_bonus = cond do
      avg_kill_value > 5_000_000_000 -> 15  # >5B ISK kills
      avg_kill_value > 1_000_000_000 -> 10  # >1B ISK kills
      avg_kill_value > 500_000_000 -> 5     # >500M ISK kills
      true -> 0
    end
    
    # High value losses might indicate wealth/bait potential
    loss_value_indicator = if avg_loss_value > 1_000_000_000, do: 5, else: 0
    
    kill_value_bonus + loss_value_indicator
  end

  defp calculate_experience_modifier(character_stats) do
    if character_stats do
      total_kills = character_stats.total_kills || 0
      
      cond do
        total_kills > 1000 -> 10
        total_kills > 500 -> 8
        total_kills > 200 -> 5
        total_kills > 50 -> 3
        total_kills > 10 -> 1
        true -> 0
      end
    else
      0
    end
  end

  defp clamp_score(score), do: max(0, min(100, round(score)))

  defp calculate_bait_probability(character_id, associates, recent_activity) do
    base_probability = 25
    
    associate_modifier = calculate_associate_modifier(associates)
    solo_but_connected = calculate_solo_connected_modifier(associates, recent_activity)
    bait_pattern = calculate_bait_pattern_modifier(recent_activity)
    activity_spike = calculate_activity_spike_modifier(recent_activity)
    loss_pattern = calculate_loss_pattern_modifier(recent_activity)
    
    final_probability = base_probability + associate_modifier + solo_but_connected + 
                       bait_pattern + activity_spike + loss_pattern
    
    max(0, min(100, round(final_probability)))
  end

  defp calculate_associate_modifier(associates) do
    associate_count = length(associates)
    
    cond do
      associate_count > 30 -> 35  # Very coordinated
      associate_count > 20 -> 30  # Highly coordinated
      associate_count > 10 -> 20  # Coordinated
      associate_count > 5 -> 10   # Some coordination
      true -> 0
    end
  end

  defp calculate_solo_connected_modifier(associates, recent_activity) do
    if length(associates) > 5 and recent_activity.recent_kills < 2 do
      25  # Appears solo but has many associates
    else
      0
    end
  end

  defp calculate_bait_pattern_modifier(recent_activity) do
    avg_loss_value = recent_activity.avg_loss_value || 0
    recent_kills = recent_activity.recent_kills || 0
    recent_losses = recent_activity.recent_losses || 0
    
    if avg_loss_value > 500_000_000 and recent_kills < recent_losses do
      20  # Loses expensive ships but doesn't kill much
    else
      0
    end
  end

  defp calculate_activity_spike_modifier(recent_activity) do
    recent_kills = recent_activity.recent_kills || 0
    recent_losses = recent_activity.recent_losses || 0
    
    if recent_kills == 0 and recent_losses > 0 do
      15  # Recent losses but no kills
    else
      0
    end
  end

  defp calculate_loss_pattern_modifier(recent_activity) do
    recent_losses = recent_activity.recent_losses || 0
    avg_loss_value = recent_activity.avg_loss_value || 0
    
    # Multiple expensive losses might indicate bait attempts
    if recent_losses > 3 and avg_loss_value > 1_000_000_000 do
      20
    else
      0
    end
  end

  defp determine_threat_level(threat_score, standings) do
    # Standing override takes precedence
    if standings.standing_override do
      standings.standing_override
    else
      # Score-based determination
      cond do
        threat_score >= @hostile_threshold -> :hostile
        threat_score >= @neutral_threshold -> :neutral
        threat_score >= @friendly_threshold -> :neutral
        true -> :friendly
      end
    end
  end

  defp determine_standing_override(corp_standing, alliance_standing) do
    cond do
      corp_standing == :red or alliance_standing == :red -> :hostile
      corp_standing == :blue or alliance_standing == :blue -> :friendly
      true -> nil
    end
  end

  defp identify_risk_factors(character_stats, recent_activity, associates) do
    risk_factors = []
    
    # High activity risk
    risk_factors = if recent_activity.recent_kills > 15 do
      [:high_kill_activity | risk_factors]
    else
      risk_factors
    end
    
    # Coordination risk
    risk_factors = if length(associates) > 15 do
      [:high_coordination | risk_factors]
    else
      risk_factors
    end
    
    # Experience risk
    risk_factors = if character_stats && character_stats.total_kills > 500 do
      [:veteran_pilot | risk_factors]
    else
      risk_factors
    end
    
    # High value target risk
    risk_factors = if recent_activity.avg_loss_value > 2_000_000_000 do
      [:high_value_target | risk_factors]
    else
      risk_factors
    end
    
    # Solo operator risk
    risk_factors = if character_stats && character_stats.solo_kill_percentage > 70 do
      [:solo_operator | risk_factors]
    else
      risk_factors
    end
    
    risk_factors
  end

  defp build_warning_indicators(threat_score, bait_probability, recent_activity) do
    warnings = []
    
    warnings = if threat_score >= @hostile_threshold do
      [%{type: :high_threat, severity: :high, message: "High threat pilot detected"} | warnings]
    else
      warnings
    end
    
    warnings = if bait_probability >= @high_bait_threshold do
      [%{type: :bait_risk, severity: :high, message: "High bait probability"} | warnings]
    else
      warnings
    end
    
    warnings = if recent_activity.recent_kills > 20 do
      [%{type: :high_activity, severity: :medium, message: "Very high recent kill activity"} | warnings]
    else
      warnings
    end
    
    warnings = if recent_activity.avg_loss_value > 5_000_000_000 do
      [%{type: :high_value, severity: :medium, message: "Extremely high value losses"} | warnings]
    else
      warnings
    end
    
    warnings
  end

  defp build_comprehensive_analysis_reason(threat_level, threat_score, bait_probability, standings) do
    standing_desc = build_standing_description(standings)
    threat_desc = build_threat_description(threat_level)
    bait_desc = build_bait_description(bait_probability)
    
    "#{standing_desc}#{threat_desc} (#{threat_score}/100). #{bait_desc} (#{bait_probability}%)."
  end

  defp build_standing_description(standings) do
    cond do
      standings.corporation_standing == :red or standings.alliance_standing == :red ->
        "RED STANDING - Known hostile entity. "
      
      standings.corporation_standing == :blue or standings.alliance_standing == :blue ->
        "BLUE STANDING - Friendly entity. "
      
      true -> ""
    end
  end

  defp build_threat_description(threat_level) do
    case threat_level do
      :hostile -> "High threat pilot"
      :friendly -> "Friendly pilot"
      :neutral -> "Unknown threat level"
      _ -> "Insufficient data"
    end
  end

  defp build_bait_description(bait_probability) do
    cond do
      bait_probability >= @high_bait_threshold -> "High bait probability"
      bait_probability >= @moderate_bait_threshold -> "Moderate bait probability"
      bait_probability >= @low_bait_threshold -> "Low bait probability"
      true -> "Unlikely to be bait"
    end
  end

  defp analyze_behavioral_patterns(character_stats, recent_activity) do
    patterns = %{}
    
    # Activity pattern
    patterns = Map.put(patterns, :activity_pattern, categorize_activity_pattern(recent_activity))
    
    # Combat style
    patterns = Map.put(patterns, :combat_style, determine_combat_style(character_stats, recent_activity))
    
    # Target preference
    patterns = Map.put(patterns, :target_preference, analyze_target_preference(recent_activity))
    
    # Operational pattern
    patterns = Map.put(patterns, :operational_pattern, determine_operational_pattern(recent_activity))
    
    patterns
  end

  defp categorize_activity_pattern(recent_activity) do
    kills = recent_activity.recent_kills || 0
    
    cond do
      kills > 15 -> :very_active
      kills > 8 -> :active
      kills > 3 -> :moderate
      kills > 0 -> :low
      true -> :inactive
    end
  end

  defp determine_combat_style(character_stats, recent_activity) do
    solo_percentage = character_stats && character_stats.solo_kill_percentage || 0
    avg_gang_size = calculate_estimated_gang_size(recent_activity)
    
    cond do
      solo_percentage > 70 -> :solo_hunter
      avg_gang_size > 10 -> :fleet_fighter
      avg_gang_size > 5 -> :small_gang
      true -> :mixed
    end
  end

  defp analyze_target_preference(recent_activity) do
    avg_kill_value = recent_activity.avg_kill_value || 0
    
    cond do
      avg_kill_value > 2_000_000_000 -> :high_value_targets
      avg_kill_value > 500_000_000 -> :medium_value_targets
      avg_kill_value > 100_000_000 -> :standard_targets
      true -> :low_value_targets
    end
  end

  defp determine_operational_pattern(recent_activity) do
    # This would analyze time patterns, location patterns, etc.
    # For now, simplified based on kill/loss ratio
    kills = recent_activity.recent_kills || 0
    losses = recent_activity.recent_losses || 0
    
    if kills > losses * 2 do
      :aggressive_hunter
    else
      :cautious_operator
    end
  end

  defp calculate_estimated_gang_size(recent_activity) do
    # Simplified gang size estimation
    # Would be more sophisticated with actual killmail analysis
    kd_ratio = recent_activity.kill_death_ratio || 1
    
    cond do
      kd_ratio > 5 -> 8
      kd_ratio > 3 -> 5
      kd_ratio > 1 -> 3
      true -> 2
    end
  end

  defp calculate_threat_confidence(character_stats, recent_activity, standings) do
    confidence_factors = []
    
    # Data availability
    confidence_factors = if character_stats, do: [0.3 | confidence_factors], else: confidence_factors
    confidence_factors = if recent_activity.recent_kills > 0, do: [0.2 | confidence_factors], else: confidence_factors
    confidence_factors = if standings.standing_override, do: [0.3 | confidence_factors], else: confidence_factors
    
    # Data recency and volume
    kills = recent_activity.recent_kills || 0
    confidence_factors = if kills > 5, do: [0.2 | confidence_factors], else: confidence_factors
    
    total_confidence = Enum.sum(confidence_factors)
    min(1.0, total_confidence)
  end

  defp assess_data_quality(character_stats, recent_activity) do
    quality_score = 0
    
    # Character stats availability
    quality_score = if character_stats, do: quality_score + 30, else: quality_score
    
    # Recent activity data
    quality_score = if recent_activity.recent_kills > 0, do: quality_score + 25, else: quality_score
    quality_score = if recent_activity.recent_losses >= 0, do: quality_score + 15, else: quality_score
    
    # Data completeness
    quality_score = if recent_activity.avg_kill_value, do: quality_score + 15, else: quality_score
    quality_score = if recent_activity.last_kill, do: quality_score + 15, else: quality_score
    
    case quality_score do
      score when score >= 80 -> :excellent
      score when score >= 60 -> :good
      score when score >= 40 -> :fair
      score when score >= 20 -> :poor
      _ -> :insufficient
    end
  end

  defp summarize_analysis(full_analysis) do
    %{
      character_id: full_analysis.character_id,
      threat_level: full_analysis.threat_level,
      threat_score: full_analysis.threat_score,
      bait_probability: full_analysis.bait_probability,
      corporation_standing: full_analysis.corporation_standing,
      alliance_standing: full_analysis.alliance_standing,
      primary_risk_factors: Enum.take(full_analysis.risk_factors, 3),
      confidence: full_analysis.threat_confidence
    }
  end

  defp generate_threat_summary(pilot_analyses) do
    total_pilots = map_size(pilot_analyses)
    
    if total_pilots == 0 do
      %{
        total_pilots: 0,
        threat_distribution: %{},
        average_threat_score: 0,
        average_bait_probability: 0,
        high_threat_count: 0,
        high_bait_count: 0
      }
    else
      threat_levels = Enum.map(pilot_analyses, fn {_id, analysis} -> analysis.threat_level end)
      threat_scores = Enum.map(pilot_analyses, fn {_id, analysis} -> analysis.threat_score end)
      bait_probabilities = Enum.map(pilot_analyses, fn {_id, analysis} -> analysis.bait_probability end)
      
      %{
        total_pilots: total_pilots,
        threat_distribution: Enum.frequencies(threat_levels),
        average_threat_score: Float.round(Enum.sum(threat_scores) / total_pilots, 1),
        average_bait_probability: Float.round(Enum.sum(bait_probabilities) / total_pilots, 1),
        high_threat_count: Enum.count(threat_scores, &(&1 >= @hostile_threshold)),
        high_bait_count: Enum.count(bait_probabilities, &(&1 >= @high_bait_threshold))
      }
    end
  end

  defp calculate_threat_distribution(pilot_analyses) do
    pilot_analyses
    |> Enum.map(fn {_id, analysis} -> analysis.threat_level end)
    |> Enum.frequencies()
  end

  defp determine_dominant_threat_level(pilot_analyses) do
    if map_size(pilot_analyses) == 0 do
      :unknown
    else
      pilot_analyses
      |> calculate_threat_distribution()
      |> Enum.max_by(fn {_level, count} -> count end)
      |> elem(0)
    end
  end

  defp assess_system_bait_risk(pilot_analyses) do
    if map_size(pilot_analyses) == 0 do
      %{risk_level: :unknown, average_bait_probability: 0, high_bait_pilots: 0}
    else
      bait_probabilities = Enum.map(pilot_analyses, fn {_id, analysis} -> analysis.bait_probability end)
      avg_bait = Enum.sum(bait_probabilities) / length(bait_probabilities)
      high_bait_count = Enum.count(bait_probabilities, &(&1 >= @high_bait_threshold))
      
      risk_level = cond do
        avg_bait >= @high_bait_threshold or high_bait_count > 2 -> :high
        avg_bait >= @moderate_bait_threshold or high_bait_count > 0 -> :moderate
        avg_bait >= @low_bait_threshold -> :low
        true -> :minimal
      end
      
      %{
        risk_level: risk_level,
        average_bait_probability: Float.round(avg_bait, 1),
        high_bait_pilots: high_bait_count
      }
    end
  end

  defp detect_coordinated_threats(pilot_analyses) do
    if map_size(pilot_analyses) < 3 do
      %{coordination_detected: false, coordination_score: 0}
    else
      high_associate_pilots = 
        pilot_analyses
        |> Enum.count(fn {_id, analysis} -> analysis.known_associates_count > 10 end)
      
      coordination_score = (high_associate_pilots / map_size(pilot_analyses)) * 100
      
      %{
        coordination_detected: coordination_score > 50,
        coordination_score: Float.round(coordination_score, 1),
        coordinated_pilot_count: high_associate_pilots
      }
    end
  end

  defp recommend_engagement_strategy(pilot_analyses) do
    if map_size(pilot_analyses) == 0 do
      :insufficient_data
    else
      threat_scores = Enum.map(pilot_analyses, fn {_id, analysis} -> analysis.threat_score end)
      bait_probabilities = Enum.map(pilot_analyses, fn {_id, analysis} -> analysis.bait_probability end)
      
      avg_threat = Enum.sum(threat_scores) / length(threat_scores)
      avg_bait = Enum.sum(bait_probabilities) / length(bait_probabilities)
      hostile_count = Enum.count(threat_scores, &(&1 >= @hostile_threshold))
      
      cond do
        avg_threat >= @hostile_threshold and avg_bait >= @high_bait_threshold -> :avoid_engagement
        avg_threat >= @hostile_threshold or hostile_count > 1 -> :extreme_caution
        avg_bait >= @moderate_bait_threshold -> :cautious_engagement
        avg_threat >= @neutral_threshold -> :standard_caution
        true -> :normal_engagement
      end
    end
  end

  defp calculate_system_threat_score(pilot_analyses) do
    if map_size(pilot_analyses) == 0 do
      0
    else
      threat_scores = Enum.map(pilot_analyses, fn {_id, analysis} -> analysis.threat_score end)
      avg_threat = Enum.sum(threat_scores) / length(threat_scores)
      
      # Apply multiplier for multiple threats
      multiplier = case map_size(pilot_analyses) do
        1 -> 1.0
        2 -> 1.2
        3 -> 1.4
        count when count >= 4 -> 1.6
      end
      
      system_score = avg_threat * multiplier
      clamp_score(system_score)
    end
  end

  defp update_single_inhabitant_threat(inhabitant_id, base_data, opts) do
    try do
      # This would update threat data for a specific inhabitant
      # Implementation depends on how inhabitants are stored and managed
      case ThreatDataProvider.get_inhabitant_details(inhabitant_id) do
        {:ok, inhabitant} ->
          case analyze(inhabitant.character_id, base_data, 
                      corporation_id: inhabitant.corporation_id, 
                      alliance_id: inhabitant.alliance_id) do
            {:ok, analysis} ->
              # Update inhabitant record with new threat data
              ThreatDataProvider.update_inhabitant_threat(inhabitant_id, %{
                threat_level: analysis.threat_level,
                threat_score: analysis.threat_score,
                bait_probability: analysis.bait_probability,
                last_threat_update: DateTime.utc_now()
              })
            
            {:error, reason} -> {:error, reason}
          end
        
        {:error, reason} -> {:error, reason}
      end
    rescue
      exception -> {:error, "Update failed: #{inspect(exception)}"}
    end
  end
end