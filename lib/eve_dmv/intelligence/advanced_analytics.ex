defmodule EveDmv.Intelligence.AdvancedAnalytics do
  @moduledoc """
  Advanced analytics and machine learning-style intelligence analysis.

  Provides sophisticated statistical analysis, pattern recognition, and
  predictive modeling for EVE Online intelligence operations.
  """

  alias EveDmv.Api
  alias EveDmv.Intelligence.CharacterStats
  alias EveDmv.Intelligence.PatternAnalysis
  alias EveDmv.Intelligence.ThreatAssessment
  alias EveDmv.Intelligence.WhSpace.Vetting, as: WHVetting

  require Ash.Query
  require Logger

  @doc """
  Perform advanced behavioral pattern analysis on a character.

  Uses statistical analysis to identify patterns and anomalies in character behavior.
  """
  def analyze_behavioral_patterns(character_id) do
    Logger.info("Performing advanced behavioral pattern analysis for character #{character_id}")

    with {:ok, character_stats} <- get_character_stats(character_id),
         {:ok, vetting_data} <- get_vetting_data(character_id) do
      case {character_stats, vetting_data} do
        {[stats], [vetting]} ->
          # Full analysis with both stats and vetting data
          patterns = %{
            activity_rhythm: PatternAnalysis.analyze_activity_rhythm(stats),
            engagement_patterns: PatternAnalysis.analyze_engagement_patterns(stats),
            risk_progression: PatternAnalysis.analyze_risk_progression(stats, vetting),
            social_patterns: PatternAnalysis.analyze_social_patterns(stats),
            operational_patterns: PatternAnalysis.analyze_operational_patterns(stats),
            anomaly_detection: PatternAnalysis.detect_behavioral_anomalies(stats)
          }

          confidence_score = calculate_pattern_confidence(patterns)

          {:ok,
           %{
             patterns: patterns,
             confidence_score: confidence_score,
             analysis_timestamp: DateTime.utc_now(),
             recommendations: generate_pattern_recommendations(patterns)
           }}

        {[stats], []} ->
          # Analysis with stats only (no vetting data)
          patterns = %{
            activity_rhythm: PatternAnalysis.analyze_activity_rhythm(stats),
            engagement_patterns: PatternAnalysis.analyze_engagement_patterns(stats),
            # placeholder
            risk_progression: %{analysis_quality: "limited", risk_trend: "stable"},
            social_patterns: PatternAnalysis.analyze_social_patterns(stats),
            operational_patterns: PatternAnalysis.analyze_operational_patterns(stats),
            anomaly_detection: PatternAnalysis.detect_behavioral_anomalies(stats)
          }

          # Reduced confidence
          confidence_score = calculate_pattern_confidence(patterns) * 0.8

          {:ok,
           %{
             patterns: patterns,
             confidence_score: confidence_score,
             analysis_timestamp: DateTime.utc_now(),
             recommendations: generate_pattern_recommendations(patterns),
             note: "Analysis performed with limited vetting data"
           }}

        {[], _} ->
          # No character stats available - return minimal analysis
          Logger.warning(
            "No character stats found for character #{character_id}, returning minimal analysis"
          )

          {:ok,
           %{
             patterns: %{
               activity_rhythm: %{analysis_quality: "minimal", activity_level: "unknown"},
               engagement_patterns: %{analysis_quality: "minimal", engagement_style: "unknown"},
               risk_progression: %{analysis_quality: "minimal", risk_trend: "unknown"},
               social_patterns: %{analysis_quality: "minimal", social_connectivity: "unknown"},
               operational_patterns: %{analysis_quality: "minimal", operational_style: "unknown"},
               anomaly_detection: %{analysis_quality: "minimal", anomalies: []}
             },
             # Very low confidence
             confidence_score: 0.1,
             analysis_timestamp: DateTime.utc_now(),
             recommendations: ["Gather more character data for comprehensive analysis"],
             note: "Minimal analysis due to insufficient character statistics"
           }}

        _ ->
          {:error, "Insufficient data for behavioral pattern analysis"}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Perform advanced threat assessment using multiple intelligence sources.
  """
  def advanced_threat_assessment(character_id) do
    Logger.info("Performing advanced threat assessment for character #{character_id}")

    # Gather intelligence from multiple sources
    threat_indicators = %{
      combat_effectiveness: ThreatAssessment.assess_combat_effectiveness(character_id),
      tactical_sophistication: ThreatAssessment.assess_tactical_sophistication(character_id),
      intelligence_gathering: ThreatAssessment.assess_intelligence_capabilities(character_id),
      network_influence: ThreatAssessment.assess_network_influence(character_id),
      operational_security: ThreatAssessment.assess_operational_security(character_id)
    }

    # Weight and combine threat indicators
    threat_score = ThreatAssessment.calculate_composite_threat_score(threat_indicators)
    threat_level = ThreatAssessment.categorize_threat_level(threat_score)

    {:ok,
     %{
       threat_score: threat_score,
       threat_level: threat_level,
       threat_indicators: threat_indicators,
       mitigation_strategies:
         ThreatAssessment.suggest_mitigation_strategies(threat_level, threat_indicators),
       analysis_timestamp: DateTime.utc_now()
     }}
  end

  @doc """
  Predict future behavior patterns based on historical data.
  """
  def predict_future_behavior(character_id, prediction_horizon_days \\ 30) do
    Logger.info(
      "Predicting future behavior for character #{character_id} over #{prediction_horizon_days} days"
    )

    case get_character_stats(character_id) do
      {:ok, [stats]} ->
        # Time series analysis of activity patterns
        activity_trends = analyze_activity_trends(stats)

        # Behavioral consistency analysis
        consistency_metrics = calculate_behavioral_consistency(stats)

        # Predictive modeling
        predictions = %{
          activity_level: predict_activity_level(activity_trends, prediction_horizon_days),
          engagement_likelihood: predict_engagement_likelihood(stats, prediction_horizon_days),
          risk_evolution: predict_risk_evolution(stats, prediction_horizon_days),
          corporation_stability: predict_corp_stability(stats)
        }

        confidence = calculate_prediction_confidence(consistency_metrics, prediction_horizon_days)

        {:ok,
         %{
           predictions: predictions,
           confidence_score: confidence,
           prediction_horizon_days: prediction_horizon_days,
           methodology: "Statistical trend analysis with behavioral consistency weighting",
           analysis_timestamp: DateTime.utc_now()
         }}

      _ ->
        {:error, "Insufficient historical data for prediction"}
    end
  end

  @doc """
  Advanced correlation analysis between multiple characters.
  """
  def advanced_character_correlation(character_ids) when length(character_ids) >= 2 do
    Logger.info(
      "Performing advanced correlation analysis for #{length(character_ids)} characters"
    )

    # Load character data using batch operation to prevent N+1 queries
    character_data =
      case CharacterStats
           |> Ash.Query.new()
           |> Ash.Query.filter(character_id in ^character_ids)
           |> Ash.read(domain: Api) do
        {:ok, stats_list} ->
          character_tuples = Enum.map(stats_list, fn stats -> {stats.character_id, stats} end)
          Enum.filter(character_tuples, fn {_, stats} -> not is_nil(stats) end)

        _ ->
          []
      end

    if length(character_data) >= 2 do
      correlations = %{
        temporal_correlation: calculate_temporal_correlations(character_data),
        geographic_correlation: calculate_geographic_correlations(character_data),
        tactical_correlation: calculate_tactical_correlations(character_data),
        social_correlation: calculate_social_correlations(character_data),
        behavioral_correlation: calculate_behavioral_correlations(character_data)
      }

      overall_correlation = calculate_overall_correlation_score(correlations)
      relationship_type = classify_relationship_type(correlations, overall_correlation)

      {:ok,
       %{
         correlations: correlations,
         overall_correlation_score: overall_correlation,
         relationship_type: relationship_type,
         confidence_score: calculate_correlation_confidence(character_data),
         analysis_timestamp: DateTime.utc_now()
       }}
    else
      {:error, "Insufficient valid character data for correlation analysis"}
    end
  end

  @doc """
  Generate intelligence risk scores with advanced weighting.
  """
  def calculate_advanced_risk_score(character_id) do
    Logger.info("Calculating advanced risk score for character #{character_id}")

    with {:ok, threat_assessment} <- advanced_threat_assessment(character_id),
         {:ok, behavioral_patterns} <- analyze_behavioral_patterns(character_id) do
      risk_factors = %{
        # Weighted by importance and reliability
        threat_level: %{score: threat_assessment.threat_score, weight: 0.35},
        behavioral_anomalies: %{
          score: count_behavioral_anomalies(behavioral_patterns),
          weight: 0.25
        },
        pattern_consistency: %{score: behavioral_patterns.confidence_score, weight: 0.15},
        operational_security: %{score: assess_opsec_score(character_id), weight: 0.15},
        intelligence_value: %{score: assess_intelligence_value(character_id), weight: 0.10}
      }

      # Calculate weighted risk score
      weighted_scores =
        Enum.map(risk_factors, fn {_factor, %{score: score, weight: weight}} ->
          score * weight
        end)

      weighted_score = Enum.sum(weighted_scores)

      risk_level = categorize_risk_level(weighted_score)

      {:ok,
       %{
         advanced_risk_score: Float.round(weighted_score, 2),
         risk_level: risk_level,
         risk_factors: risk_factors,
         methodology: "Multi-factor weighted risk assessment with behavioral analysis",
         recommendations: generate_risk_recommendations(risk_level, risk_factors),
         analysis_timestamp: DateTime.utc_now()
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helper functions

  defp calculate_pattern_confidence(patterns) do
    # Calculate confidence in pattern analysis
    confidence_factors = [
      patterns.activity_rhythm.consistency_score,
      1.0 - patterns.anomaly_detection.anomaly_count * 0.1,
      patterns.social_patterns.cooperation_index,
      patterns.operational_patterns.resource_efficiency
    ]

    avg_confidence = confidence_factors |> Enum.sum() |> Kernel./(length(confidence_factors))
    Float.round(max(0.0, min(1.0, avg_confidence)), 2)
  end

  defp generate_pattern_recommendations(patterns) do
    []
    |> maybe_add_recommendation(
      patterns.activity_rhythm.consistency_score < 0.5,
      "Monitor for irregular activity patterns"
    )
    |> maybe_add_recommendation(
      patterns.anomaly_detection.anomaly_count > 2,
      "Investigate behavioral anomalies further"
    )
    |> maybe_add_recommendation(
      patterns.social_patterns.cooperation_index < 0.3,
      "Consider teamwork assessment"
    )
  end

  defp maybe_add_recommendation(recommendations, true, recommendation) do
    [recommendation | recommendations]
  end

  defp maybe_add_recommendation(recommendations, false, _recommendation) do
    recommendations
  end

  defp count_behavioral_anomalies(behavioral_patterns) do
    case get_in(behavioral_patterns, [:anomaly_detection, :anomaly_count]) do
      nil ->
        # Handle cases where anomaly_count is not available (e.g., minimal analysis)
        anomalies = get_in(behavioral_patterns, [:anomaly_detection, :anomalies]) || []
        length(anomalies) * 0.1

      count when is_number(count) ->
        count * 0.1

      _ ->
        0.0
    end
  end

  defp assess_opsec_score(character_id) do
    ThreatAssessment.assess_operational_security(character_id)
  end

  defp assess_intelligence_value(character_id) do
    ThreatAssessment.assess_intelligence_capabilities(character_id)
  end

  defp categorize_risk_level(risk_score) do
    cond do
      risk_score >= 0.8 -> "critical"
      risk_score >= 0.6 -> "high"
      risk_score >= 0.4 -> "medium"
      risk_score >= 0.2 -> "low"
      true -> "minimal"
    end
  end

  defp generate_risk_recommendations(risk_level, _risk_factors) do
    case risk_level do
      "critical" -> ["Immediate review required", "Consider rejection", "High-level monitoring"]
      "high" -> ["Enhanced screening", "Regular monitoring", "Restricted initial access"]
      "medium" -> ["Standard procedures", "Periodic review"]
      "low" -> ["Normal processing", "Basic monitoring"]
      _ -> ["Standard recruitment process"]
    end
  end

  # Prediction functions
  defp analyze_activity_trends(stats) do
    # Analyze actual activity trends from character stats
    total_kills = Map.get(stats, :total_kills, 0)
    total_losses = Map.get(stats, :total_losses, 0)
    total_activity = total_kills + total_losses

    # Calculate kill/death ratio trend
    kd_ratio = if total_losses > 0, do: total_kills / total_losses, else: total_kills

    # Determine trend based on activity level and KD ratio
    trend =
      cond do
        total_activity > 500 and kd_ratio > 2.0 -> "increasing"
        total_activity > 200 and kd_ratio > 1.0 -> "stable"
        total_activity < 50 -> "declining"
        true -> "stable"
      end

    # Calculate variance based on activity consistency
    variance =
      cond do
        # High variance for low activity
        total_activity < 10 -> 0.8
        total_activity < 100 -> 0.5
        total_activity < 500 -> 0.3
        # Low variance for high activity
        true -> 0.2
      end

    # Determine seasonality based on activity patterns
    seasonality = if total_activity > 100, do: "weekly", else: "none"

    %{trend: trend, variance: variance, seasonality: seasonality}
  end

  defp calculate_behavioral_consistency(stats) do
    # Calculate behavioral consistency from actual stats
    total_kills = Map.get(stats, :total_kills, 0)
    total_losses = Map.get(stats, :total_losses, 0)
    ship_diversity = Map.get(stats, :ship_types_used, 1)

    # Consistency factors
    activity_consistency = if total_kills + total_losses > 50, do: 0.8, else: 0.4
    # Lower diversity = higher consistency
    ship_consistency = min(1.0, 1.0 - (ship_diversity - 1) * 0.1)

    kd_ratio = if total_losses > 0, do: total_kills / total_losses, else: total_kills

    performance_consistency =
      cond do
        # Very consistent performance
        kd_ratio > 3.0 -> 0.9
        kd_ratio > 2.0 -> 0.8
        kd_ratio > 1.0 -> 0.6
        true -> 0.4
      end

    overall_consistency = (activity_consistency + ship_consistency + performance_consistency) / 3

    reliability =
      cond do
        overall_consistency > 0.8 -> "high"
        overall_consistency > 0.6 -> "medium"
        true -> "low"
      end

    %{consistency_score: Float.round(overall_consistency, 2), reliability: reliability}
  end

  defp predict_activity_level(trends, horizon) do
    # Predict activity level based on trends and horizon
    base_level =
      case trends.trend do
        "increasing" -> "high"
        "stable" -> "medium"
        "declining" -> "low"
        _ -> "medium"
      end

    # Adjust confidence based on variance and prediction horizon
    base_confidence = 1.0 - trends.variance
    # Confidence decreases over time
    horizon_penalty = min(0.5, horizon * 0.01)
    confidence = max(0.1, base_confidence - horizon_penalty)

    # Calculate expected change based on trend
    expected_change =
      case trends.trend do
        "increasing" -> 0.2
        "declining" -> -0.3
        _ -> 0.0
      end

    %{
      level: base_level,
      confidence: Float.round(confidence, 2),
      expected_change: expected_change
    }
  end

  defp predict_engagement_likelihood(stats, horizon) do
    # Predict engagement likelihood based on stats
    total_activity = Map.get(stats, :total_kills, 0) + Map.get(stats, :total_losses, 0)
    avg_gang_size = Map.get(stats, :avg_gang_size, 1.0) |> to_float()
    ship_diversity = Map.get(stats, :ship_types_used, 1)

    # Base likelihood from activity level
    activity_factor = min(1.0, total_activity / 500.0)

    # Gang preference factor (solo players more unpredictable)
    gang_factor = if avg_gang_size > 3.0, do: 0.8, else: 0.6

    # Ship diversity factor (more diverse = more engaged)
    diversity_factor = min(1.0, ship_diversity / 10.0)

    base_likelihood = (activity_factor + gang_factor + diversity_factor) / 3

    # Adjust for prediction horizon
    horizon_adjustment = max(0.3, 1.0 - horizon * 0.02)
    likelihood = base_likelihood * horizon_adjustment

    # Determine key factors
    factors = []
    factors = if total_activity > 200, do: ["high_historical_activity" | factors], else: factors
    factors = if avg_gang_size > 5.0, do: ["fleet_preference" | factors], else: factors
    factors = if ship_diversity > 5, do: ["ship_variety" | factors], else: factors
    factors = if Enum.empty?(factors), do: ["limited_data"], else: factors

    %{
      likelihood: Float.round(likelihood, 2),
      factors: factors
    }
  end

  defp predict_risk_evolution(stats, horizon) do
    # Predict risk evolution based on character progression
    total_kills = Map.get(stats, :total_kills, 0)
    total_losses = Map.get(stats, :total_losses, 0)
    danger_rating = Map.get(stats, :danger_rating, :low)
    ship_diversity = Map.get(stats, :ship_types_used, 1)

    kd_ratio = if total_losses > 0, do: total_kills / total_losses, else: total_kills

    # Determine trajectory based on current metrics
    trajectory =
      cond do
        danger_rating in [:very_dangerous, :extremely_dangerous] and kd_ratio > 3.0 ->
          "escalating"

        danger_rating in [:dangerous, :very_dangerous] and ship_diversity > 8 ->
          "developing"

        danger_rating in [:low, :moderate] and total_kills < 100 ->
          "emerging"

        true ->
          "stable"
      end

    # Calculate expected risk change
    risk_change =
      case trajectory do
        "escalating" -> 0.3
        "developing" -> 0.1
        "emerging" -> 0.05
        _ -> 0.0
      end

    # Confidence based on data quality and horizon
    data_quality = min(1.0, (total_kills + total_losses) / 200.0)
    horizon_factor = max(0.3, 1.0 - horizon * 0.015)
    confidence = data_quality * horizon_factor

    %{
      trajectory: trajectory,
      risk_change: risk_change,
      confidence: Float.round(confidence, 2)
    }
  end

  defp predict_corp_stability(stats) do
    # Predict corporation stability based on character metrics
    total_activity = Map.get(stats, :total_kills, 0) + Map.get(stats, :total_losses, 0)
    avg_gang_size = Map.get(stats, :avg_gang_size, 1.0) |> to_float()
    primary_activity = Map.get(stats, :primary_activity, :mixed)

    # Calculate loyalty indicators
    fleet_participation = if avg_gang_size > 3.0, do: 0.8, else: 0.4
    activity_commitment = min(1.0, total_activity / 300.0)

    # Activity type indicates corp engagement
    activity_factor =
      case primary_activity do
        :fleet_pilot -> 0.9
        :mixed -> 0.7
        :solo_hunter -> 0.4
        _ -> 0.5
      end

    loyalty_score = (fleet_participation + activity_commitment + activity_factor) / 3

    # Determine stability and turnover risk
    {stability, turnover_risk} =
      cond do
        loyalty_score > 0.8 -> {"high", 0.1}
        loyalty_score > 0.6 -> {"medium", 0.3}
        loyalty_score > 0.4 -> {"low", 0.5}
        true -> {"unstable", 0.8}
      end

    %{
      stability: stability,
      turnover_risk: turnover_risk,
      loyalty_score: Float.round(loyalty_score, 2)
    }
  end

  defp calculate_prediction_confidence(_consistency, horizon) do
    # Confidence decreases with longer prediction horizons
    base_confidence = 0.8
    horizon_penalty = horizon * 0.01
    max(0.1, base_confidence - horizon_penalty)
  end

  # Correlation functions
  defp calculate_temporal_correlations(character_data) do
    # Analyze temporal correlations between characters
    if length(character_data) < 2 do
      %{correlation_score: 0.0, synchronized_activity: false}
    else
      # Extract activity patterns
      activity_patterns =
        Enum.map(character_data, fn {_id, stats} ->
          total_activity = Map.get(stats, :total_kills, 0) + Map.get(stats, :total_losses, 0)
          active_days = Map.get(stats, :active_days, 1)
          activity_rate = if active_days > 0, do: total_activity / active_days, else: 0
          {stats.character_id, activity_rate}
        end)

      # Calculate correlation between activity rates
      rates = Enum.map(activity_patterns, fn {_id, rate} -> rate end)
      correlation = calculate_correlation_coefficient(rates)

      # Determine synchronization
      avg_rate = Enum.sum(rates) / length(rates)
      synchronized = Enum.all?(rates, fn rate -> abs(rate - avg_rate) < avg_rate * 0.3 end)

      %{
        correlation_score: Float.round(max(0.0, correlation), 2),
        synchronized_activity: synchronized
      }
    end
  end

  defp calculate_geographic_correlations(character_data) do
    # Analyze geographic correlations between characters
    if length(character_data) < 2 do
      %{correlation_score: 0.0, shared_regions: []}
    else
      # Extract region activity (simplified - would use actual region data)
      region_activities =
        Enum.map(character_data, fn {_id, stats} ->
          # Infer regions from activity patterns and ship types
          danger_rating = Map.get(stats, :danger_rating, :low)
          ship_diversity = Map.get(stats, :ship_types_used, 1)

          regions = []

          regions =
            if danger_rating in [:dangerous, :very_dangerous, :extremely_dangerous],
              do: ["Nullsec" | regions],
              else: regions

          regions = if ship_diversity > 5, do: ["Lowsec" | regions], else: regions
          regions = if Enum.empty?(regions), do: ["Highsec"], else: regions

          {stats.character_id, regions}
        end)

      # Find shared regions
      all_regions = Enum.flat_map(region_activities, fn {_id, regions} -> regions end)

      shared_regions =
        all_regions
        |> Enum.frequencies()
        |> Enum.filter(fn {_region, count} -> count > 1 end)
        |> Enum.map(fn {region, _count} -> region end)

      # Calculate correlation score based on shared regions
      correlation_score =
        if Enum.empty?(shared_regions), do: 0.0, else: length(shared_regions) / 3.0

      %{
        correlation_score: Float.round(min(1.0, correlation_score), 2),
        shared_regions: shared_regions
      }
    end
  end

  defp calculate_tactical_correlations(character_data) do
    # Analyze tactical correlations between characters
    if length(character_data) < 2 do
      %{correlation_score: 0.0, shared_tactics: [], coordination_level: "none"}
    else
      # Extract tactical preferences
      tactical_profiles =
        Enum.map(character_data, fn {_id, stats} ->
          avg_gang_size = Map.get(stats, :avg_gang_size, 1.0) |> to_float()
          primary_activity = Map.get(stats, :primary_activity, :mixed)
          ship_diversity = Map.get(stats, :ship_types_used, 1)

          # Determine tactical preferences
          tactics = []
          tactics = if avg_gang_size <= 2.0, do: ["solo" | tactics], else: tactics

          tactics =
            if avg_gang_size > 2.0 and avg_gang_size <= 8.0,
              do: ["small_gang" | tactics],
              else: tactics

          tactics = if avg_gang_size > 8.0, do: ["fleet" | tactics], else: tactics

          tactics =
            if primary_activity == :fleet_pilot, do: ["coordinated" | tactics], else: tactics

          tactics = if ship_diversity > 7, do: ["versatile" | tactics], else: tactics

          {stats.character_id, tactics}
        end)

      # Find shared tactics
      all_tactics = Enum.flat_map(tactical_profiles, fn {_id, tactics} -> tactics end)

      shared_tactics =
        all_tactics
        |> Enum.frequencies()
        |> Enum.filter(fn {_tactic, count} -> count > 1 end)
        |> Enum.map(fn {tactic, _count} -> tactic end)

      # Calculate correlation and coordination level
      correlation_score =
        if Enum.empty?(shared_tactics), do: 0.0, else: length(shared_tactics) / 4.0

      coordination_level =
        cond do
          "coordinated" in shared_tactics and "fleet" in shared_tactics -> "high"
          "small_gang" in shared_tactics or "coordinated" in shared_tactics -> "medium"
          length(shared_tactics) > 0 -> "low"
          true -> "none"
        end

      %{
        correlation_score: Float.round(min(1.0, correlation_score), 2),
        shared_tactics: shared_tactics,
        coordination_level: coordination_level
      }
    end
  end

  defp calculate_social_correlations(character_data) do
    # Analyze social correlations between characters
    if length(character_data) < 2 do
      %{correlation_score: 0.0, relationship_strength: "none", interaction_frequency: "none"}
    else
      # Extract social indicators
      social_profiles =
        Enum.map(character_data, fn {_id, stats} ->
          avg_gang_size = Map.get(stats, :avg_gang_size, 1.0) |> to_float()
          primary_activity = Map.get(stats, :primary_activity, :mixed)
          total_activity = Map.get(stats, :total_kills, 0) + Map.get(stats, :total_losses, 0)

          # Calculate social engagement score
          gang_preference = if avg_gang_size > 3.0, do: 1.0, else: avg_gang_size / 3.0
          activity_overlap = min(1.0, total_activity / 200.0)

          cooperation_score =
            case primary_activity do
              :fleet_pilot -> 0.9
              :mixed -> 0.6
              :solo_hunter -> 0.2
              _ -> 0.4
            end

          social_score = (gang_preference + activity_overlap + cooperation_score) / 3
          {stats.character_id, social_score}
        end)

      # Calculate correlation between social scores
      social_scores = Enum.map(social_profiles, fn {_id, score} -> score end)
      correlation = calculate_correlation_coefficient(social_scores)
      avg_social_score = Enum.sum(social_scores) / length(social_scores)

      # Determine relationship strength and interaction frequency
      {relationship_strength, interaction_frequency} =
        cond do
          correlation > 0.7 and avg_social_score > 0.7 -> {"strong", "frequent"}
          correlation > 0.5 or avg_social_score > 0.6 -> {"medium", "regular"}
          correlation > 0.3 or avg_social_score > 0.4 -> {"weak", "occasional"}
          true -> {"minimal", "rare"}
        end

      %{
        correlation_score: Float.round(max(0.0, correlation), 2),
        relationship_strength: relationship_strength,
        interaction_frequency: interaction_frequency
      }
    end
  end

  defp calculate_behavioral_correlations(character_data) do
    # Analyze behavioral correlations between characters
    if length(character_data) < 2 do
      %{correlation_score: 0.0, pattern_similarity: "none", behavior_sync: false}
    else
      # Extract behavioral patterns
      behavioral_profiles =
        Enum.map(character_data, fn {_id, stats} ->
          total_kills = Map.get(stats, :total_kills, 0)
          total_losses = Map.get(stats, :total_losses, 0)
          ship_diversity = Map.get(stats, :ship_types_used, 1)
          danger_rating = Map.get(stats, :danger_rating, :low)

          # Create behavioral fingerprint
          kd_ratio = if total_losses > 0, do: total_kills / total_losses, else: total_kills

          aggression_score =
            case danger_rating do
              :extremely_dangerous -> 1.0
              :very_dangerous -> 0.8
              :dangerous -> 0.6
              :moderate -> 0.4
              _ -> 0.2
            end

          diversity_score = min(1.0, ship_diversity / 10.0)
          risk_tolerance = min(1.0, kd_ratio / 5.0)

          fingerprint = [aggression_score, diversity_score, risk_tolerance]
          {stats.character_id, fingerprint}
        end)

      # Calculate similarity between behavioral fingerprints
      fingerprints = Enum.map(behavioral_profiles, fn {_id, fp} -> fp end)

      # Compare each pair of fingerprints
      similarities =
        for i <- 0..(length(fingerprints) - 2),
            j <- (i + 1)..(length(fingerprints) - 1) do
          fp1 = Enum.at(fingerprints, i)
          fp2 = Enum.at(fingerprints, j)
          calculate_vector_similarity(fp1, fp2)
        end

      avg_similarity =
        if Enum.empty?(similarities), do: 0.0, else: Enum.sum(similarities) / length(similarities)

      # Determine pattern similarity and sync
      {pattern_similarity, behavior_sync} =
        cond do
          avg_similarity > 0.8 -> {"high", true}
          avg_similarity > 0.6 -> {"medium", true}
          avg_similarity > 0.4 -> {"moderate", false}
          avg_similarity > 0.2 -> {"low", false}
          true -> {"minimal", false}
        end

      %{
        correlation_score: Float.round(avg_similarity, 2),
        pattern_similarity: pattern_similarity,
        behavior_sync: behavior_sync
      }
    end
  end

  defp calculate_overall_correlation_score(correlations) do
    scores = [
      correlations.temporal_correlation.correlation_score,
      correlations.geographic_correlation.correlation_score,
      correlations.tactical_correlation.correlation_score,
      correlations.social_correlation.correlation_score,
      correlations.behavioral_correlation.correlation_score
    ]

    Enum.sum(scores) / length(scores)
  end

  defp classify_relationship_type(_correlations, overall_score) do
    cond do
      overall_score >= 0.7 -> "strong_association"
      overall_score >= 0.5 -> "moderate_association"
      overall_score >= 0.3 -> "weak_association"
      true -> "minimal_association"
    end
  end

  defp calculate_correlation_confidence(character_data) do
    # Confidence based on data quality and quantity
    data_quality = length(character_data) / 10.0
    min(1.0, data_quality)
  end

  # Statistical helper functions
  defp calculate_correlation_coefficient(values) do
    if length(values) < 2 do
      0.0
    else
      n = length(values)
      mean = Enum.sum(values) / n

      if Enum.all?(values, fn v -> v == mean end) do
        # Perfect correlation if all values are the same
        1.0
      else
        variance = Enum.sum(Enum.map(values, fn v -> (v - mean) * (v - mean) end)) / n
        if variance > 0, do: min(1.0, 1.0 - variance / (mean * mean + 1)), else: 0.0
      end
    end
  end

  defp calculate_vector_similarity(vec1, vec2) do
    if length(vec1) != length(vec2) do
      0.0
    else
      # Calculate cosine similarity
      dot_product = Enum.zip(vec1, vec2) |> Enum.map(fn {a, b} -> a * b end) |> Enum.sum()
      magnitude1 = :math.sqrt(Enum.map(vec1, fn x -> x * x end) |> Enum.sum())
      magnitude2 = :math.sqrt(Enum.map(vec2, fn x -> x * x end) |> Enum.sum())

      if magnitude1 > 0 and magnitude2 > 0 do
        dot_product / (magnitude1 * magnitude2)
      else
        0.0
      end
    end
  end

  # Helper functions to query Ash resources
  defp get_character_stats(character_id) do
    case Ash.get(CharacterStats, character_id, domain: Api) do
      {:ok, stats} -> {:ok, [stats]}
      {:error, _} -> {:ok, []}
    end
  end

  defp get_vetting_data(character_id) do
    # Return empty vetting data if the WHVetting resource doesn't exist
    # This prevents errors when the wormhole vetting system isn't fully implemented
    try do
      WHVetting
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id: character_id)
      |> Ash.Query.limit(1)
      |> Ash.read(domain: Api)
    rescue
      ArgumentError ->
        {:ok, []}

      _ ->
        {:ok, []}
    end
  end

  # Helper function to safely convert values to float
  defp to_float(value) when is_float(value), do: value
  defp to_float(value) when is_integer(value), do: value * 1.0
  defp to_float(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  # fallback for nil or other types
  defp to_float(_value), do: 0.0
end
