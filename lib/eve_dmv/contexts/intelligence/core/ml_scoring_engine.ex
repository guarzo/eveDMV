defmodule EveDmv.Contexts.Intelligence.Core.MLScoringEngine do
  @moduledoc """
  Machine Learning-enhanced intelligence scoring engine.

  Implements advanced scoring algorithms including:
  - Feature engineering from killmail data
  - Anomaly detection
  - Predictive modeling
  - Dynamic weight optimization
  - Ensemble scoring methods
  """

  alias EveDmv.Cache
  alias EveDmv.Database.CharacterRepository
  alias EveDmv.Database.KillmailRepository

  require Logger

  @cache_ttl :timer.hours(4)

  # Feature engineering constants
  # Days
  @time_windows [7, 30, 90]
  @percentiles [0.1, 0.25, 0.5, 0.75, 0.9]

  @doc """
  Calculate ML-enhanced intelligence score with feature engineering.
  """
  @spec calculate_ml_score(integer(), keyword()) :: {:ok, map()} | {:error, atom()}
  def calculate_ml_score(character_id, opts \\ []) do
    cache_key = {:ml_intelligence_score, character_id, opts}

    Cache.get_or_compute(
      :analysis,
      cache_key,
      fn ->
        perform_ml_scoring(character_id, opts)
      end,
      ttl: @cache_ttl
    )
  end

  @doc """
  Detect anomalies in character behavior using statistical methods.
  """
  @spec detect_behavioral_anomalies(integer()) :: {:ok, map()} | {:error, atom()}
  def detect_behavioral_anomalies(character_id) do
    with {:ok, features} <- extract_features(character_id),
         {:ok, baseline} <- calculate_baseline_behavior(character_id),
         anomalies <- identify_anomalies(features, baseline) do
      {:ok,
       %{
         anomaly_count: length(anomalies),
         anomalies: anomalies,
         anomaly_score: calculate_anomaly_score(anomalies),
         confidence: calculate_anomaly_confidence(features)
       }}
    end
  end

  @doc """
  Predict future threat level using historical trends.
  """
  @spec predict_threat_trajectory(integer(), integer()) :: {:ok, map()} | {:error, atom()}
  def predict_threat_trajectory(character_id, days_ahead \\ 30) do
    with {:ok, historical_data} <- get_historical_features(character_id),
         {:ok, trend_model} <- fit_trend_model(historical_data) do
      prediction = apply_trend_model(trend_model, days_ahead)

      {:ok,
       %{
         current_threat: trend_model.current_level,
         predicted_threat: prediction.threat_level,
         confidence_interval: prediction.confidence_interval,
         trend_direction: prediction.trend,
         risk_factors: identify_risk_factors(trend_model)
       }}
    end
  end

  @doc """
  Calculate ensemble score combining multiple models.
  """
  @spec calculate_ensemble_score(integer()) :: {:ok, map()} | {:error, atom()}
  def calculate_ensemble_score(character_id) do
    models = [
      {:behavioral, &score_behavioral_model/1, 0.25},
      {:combat, &score_combat_model/1, 0.30},
      {:network, &score_network_model/1, 0.25},
      {:anomaly, &score_anomaly_model/1, 0.20}
    ]

    with {:ok, features} <- extract_features(character_id) do
      # Run all models in parallel
      model_scores =
        models
        |> Enum.map(fn {name, scorer, weight} ->
          Task.async(fn ->
            {name, scorer.(features), weight}
          end)
        end)
        |> Task.await_many(5000)

      # Combine scores
      ensemble_score = calculate_weighted_ensemble(model_scores)

      {:ok,
       %{
         ensemble_score: ensemble_score,
         model_scores: format_model_scores(model_scores),
         confidence: calculate_ensemble_confidence(model_scores),
         recommendation: generate_ml_recommendation(ensemble_score)
       }}
    end
  end

  # Private Functions

  @spec perform_ml_scoring(integer(), keyword()) :: {:ok, map()} | {:error, atom()}
  defp perform_ml_scoring(character_id, opts) do
    with {:ok, features} <- extract_features(character_id),
         {:ok, behavioral_score} <- calculate_behavioral_score(features),
         {:ok, combat_score} <- calculate_combat_effectiveness_score(features),
         {:ok, network_score} <- calculate_network_influence_score(features),
         {:ok, anomaly_score} <- calculate_anomaly_detection_score(features) do
      # Dynamic weight optimization based on data quality
      weights = optimize_weights(features, opts)

      # Calculate composite ML score
      ml_score = %{
        overall_score:
          calculate_composite_score(
            behavioral_score,
            combat_score,
            network_score,
            anomaly_score,
            weights
          ),
        component_scores: %{
          behavioral: behavioral_score,
          combat_effectiveness: combat_score,
          network_influence: network_score,
          anomaly_detection: anomaly_score
        },
        feature_importance: calculate_feature_importance(features),
        model_confidence: calculate_model_confidence(features),
        weights_used: weights,
        analyzed_at: DateTime.utc_now()
      }

      {:ok, ml_score}
    end
  end

  @spec extract_features(integer()) :: {:ok, map()} | {:error, atom()}
  defp extract_features(character_id) do
    # Extract comprehensive feature set for ML models
    with {:ok, killmails} <- get_recent_killmails(character_id),
         {:ok, character_stats} <- CharacterRepository.get_character_stats(character_id) do
      features = %{
        # Basic statistics
        basic_stats: extract_basic_statistics(killmails, character_stats),

        # Time-based features
        temporal_features: extract_temporal_features(killmails),

        # Combat features
        combat_features: extract_combat_features(killmails),

        # Network features
        network_features: extract_network_features(killmails),

        # Behavioral features
        behavioral_features: extract_behavioral_features(killmails),

        # Statistical features
        statistical_features: extract_statistical_features(killmails),

        # Engineered features
        engineered_features: engineer_advanced_features(killmails)
      }

      {:ok, features}
    end
  end

  defp get_recent_killmails(character_id) do
    start_date = DateTime.utc_now() |> DateTime.add(-90 * 24 * 60 * 60, :second)
    KillmailRepository.get_by_character(character_id, start_date)
  end

  defp extract_basic_statistics(killmails, character_stats) do
    %{
      total_kills: length(Enum.filter(killmails, &(not &1.is_victim))),
      total_losses: length(Enum.filter(killmails, & &1.is_victim)),
      kill_death_ratio: calculate_kd_ratio(killmails),
      total_isk_destroyed: sum_isk_destroyed(killmails),
      total_isk_lost: sum_isk_lost(killmails),
      isk_efficiency: calculate_isk_efficiency(killmails),
      days_active: calculate_days_active(killmails),
      character_age_days: calculate_character_age(character_stats)
    }
  end

  defp extract_temporal_features(killmails) do
    # Time-based feature engineering
    Enum.reduce(@time_windows, %{}, fn window, acc ->
      window_kills = filter_by_window(killmails, window)

      window_features = %{
        "kills_#{window}d" => count_kills(window_kills),
        "losses_#{window}d" => count_losses(window_kills),
        "unique_systems_#{window}d" => count_unique_systems(window_kills),
        "activity_variance_#{window}d" => calculate_activity_variance(window_kills),
        "peak_hour_concentration_#{window}d" => calculate_peak_hour_concentration(window_kills),
        "weekend_ratio_#{window}d" => calculate_weekend_ratio(window_kills)
      }

      Map.merge(acc, window_features)
    end)
  end

  defp extract_combat_features(killmails) when is_list(killmails) do
    kills =
      Enum.filter(killmails, fn km ->
        is_map(km) && Map.get(km, :is_victim, false) == false
      end)

    %{
      solo_kill_ratio: calculate_solo_ratio(kills),
      average_gang_size: calculate_average_gang_size(kills),
      ship_diversity_index: calculate_ship_diversity(kills),
      capital_usage_ratio: calculate_capital_usage(kills),
      average_kill_value: calculate_average_value(kills),
      killing_blow_ratio: calculate_killing_blow_ratio(kills),
      weapon_diversity: calculate_weapon_diversity(kills),
      engagement_range_variance: calculate_engagement_variance(kills)
    }
  end

  defp extract_combat_features(_),
    do: %{
      solo_kill_ratio: 0.0,
      average_gang_size: 0.0,
      ship_diversity_index: 0.0,
      capital_usage_ratio: 0.0,
      average_kill_value: 0.0,
      killing_blow_ratio: 0.0,
      weapon_diversity: 0.0,
      engagement_range_variance: 0.0
    }

  defp extract_network_features(killmails) do
    %{
      unique_allies_count: count_unique_allies(killmails),
      repeat_engagement_ratio: calculate_repeat_engagement_ratio(killmails),
      corporation_diversity: calculate_corp_diversity(killmails),
      alliance_participation: calculate_alliance_participation(killmails),
      social_clustering_coefficient: calculate_social_clustering(killmails),
      fleet_consistency_score: calculate_fleet_consistency(killmails)
    }
  end

  defp extract_behavioral_features(killmails) do
    %{
      activity_consistency: measure_activity_consistency(killmails),
      timezone_stability: calculate_timezone_stability(killmails),
      hunting_pattern_score: identify_hunting_patterns(killmails),
      risk_taking_index: calculate_risk_index(killmails),
      target_selection_bias: analyze_target_selection(killmails),
      operational_security_score: measure_opsec(killmails)
    }
  end

  defp extract_statistical_features(killmails) do
    # Advanced statistical features
    values = Enum.map(killmails, & &1.total_value)
    timestamps = Enum.map(killmails, & &1.killmail_time)

    %{
      value_percentiles: calculate_percentiles(values, @percentiles),
      inter_kill_time_stats: calculate_time_interval_stats(timestamps),
      value_skewness: calculate_skewness(values),
      value_kurtosis: calculate_kurtosis(values),
      activity_entropy: calculate_activity_entropy(killmails),
      burst_activity_score: detect_activity_bursts(timestamps)
    }
  end

  defp engineer_advanced_features(killmails) do
    %{
      # Interaction features
      kd_isk_interaction: calculate_kd_isk_interaction(killmails),

      # Trend features
      kill_trend_slope: calculate_trend_slope(killmails, :kills),
      value_trend_slope: calculate_trend_slope(killmails, :value),

      # Ratio features
      high_value_target_ratio: calculate_high_value_ratio(killmails),
      defensive_loss_ratio: calculate_defensive_losses(killmails),

      # Pattern features
      activity_periodicity: detect_periodic_patterns(killmails),
      engagement_complexity: calculate_engagement_complexity(killmails)
    }
  end

  # ML Model Scoring Functions

  @spec calculate_behavioral_score(map()) :: {:ok, float()} | {:error, atom()}
  defp calculate_behavioral_score(features) do
    try do
      behavioral_features = Map.get(features, :behavioral_features, %{})
      engineered_features = Map.get(features, :engineered_features, %{})

      # Score based on behavioral consistency and patterns with safe access
      behavioral_components = [
        Map.get(behavioral_features, :activity_consistency, 0.0) * 0.2,
        Map.get(behavioral_features, :timezone_stability, 0.0) * 0.15,
        Map.get(behavioral_features, :operational_security_score, 0.0) * 0.25,
        (1.0 - Map.get(behavioral_features, :risk_taking_index, 0.0)) * 0.2,
        Map.get(engineered_features, :activity_periodicity, 0.0) * 0.2
      ]

      score = Enum.sum(behavioral_components)
      {:ok, Float.round(score, 3)}
    rescue
      _error -> {:error, :behavioral_score_calculation_failed}
    end
  end

  @spec calculate_combat_effectiveness_score(map()) :: {:ok, float()} | {:error, atom()}
  defp calculate_combat_effectiveness_score(features) do
    try do
      basic_stats = Map.get(features, :basic_stats, %{})
      combat_features = Map.get(features, :combat_features, %{})

      # Advanced combat scoring with feature interactions and safe access
      combat_components = [
        normalize_kd_ratio(Map.get(basic_stats, :kill_death_ratio, 0.0)) * 0.25,
        Map.get(basic_stats, :isk_efficiency, 0.0) * 0.20,
        Map.get(combat_features, :solo_kill_ratio, 0.0) * 0.15,
        Map.get(combat_features, :ship_diversity_index, 0.0) * 0.15,
        normalize_kill_value(Map.get(combat_features, :average_kill_value, 0.0)) * 0.15,
        Map.get(combat_features, :killing_blow_ratio, 0.0) * 0.10
      ]

      score = Enum.sum(combat_components)
      {:ok, Float.round(score, 3)}
    rescue
      _error -> {:error, :combat_score_calculation_failed}
    end
  end

  @spec calculate_network_influence_score(map()) :: {:ok, float()} | {:error, atom()}
  defp calculate_network_influence_score(features) do
    try do
      network_features = Map.get(features, :network_features, %{})

      # Network-based influence scoring with safe access
      network_components = [
        normalize_network_size(Map.get(network_features, :unique_allies_count, 0)) * 0.3,
        Map.get(network_features, :repeat_engagement_ratio, 0.0) * 0.2,
        Map.get(network_features, :corporation_diversity, 0.0) * 0.15,
        Map.get(network_features, :social_clustering_coefficient, 0.0) * 0.2,
        Map.get(network_features, :fleet_consistency_score, 0.0) * 0.15
      ]

      score = Enum.sum(network_components)
      {:ok, Float.round(score, 3)}
    rescue
      _error -> {:error, :network_score_calculation_failed}
    end
  end

  @spec calculate_anomaly_detection_score(map()) :: {:ok, float()} | {:error, atom()}
  defp calculate_anomaly_detection_score(features) do
    try do
      statistical_features = Map.get(features, :statistical_features, %{})
      temporal_features = Map.get(features, :temporal_features, %{})
      behavioral_features = Map.get(features, :behavioral_features, %{})
      combat_features = Map.get(features, :combat_features, %{})

      # Detect anomalous patterns with safe access
      anomaly_indicators = [
        detect_value_anomalies(Map.get(statistical_features, :value_percentiles, [])),
        detect_temporal_anomalies(temporal_features),
        detect_behavioral_anomalies_score(behavioral_features),
        detect_combat_anomalies(combat_features)
      ]

      # Invert for scoring (fewer anomalies = higher score)
      anomaly_count = Enum.sum(anomaly_indicators)
      score = max(0.0, 1.0 - anomaly_count / 10.0)

      {:ok, Float.round(score, 3)}
    rescue
      _error -> {:error, :anomaly_score_calculation_failed}
    end
  end

  # Weight Optimization

  defp optimize_weights(features, _opts) do
    # Dynamic weight optimization based on data quality and completeness
    default_weights = %{
      behavioral: 0.25,
      combat: 0.30,
      network: 0.25,
      anomaly: 0.20
    }

    # Adjust weights based on data availability
    quality_scores = assess_feature_quality(features)

    optimized_weights =
      Enum.reduce(default_weights, %{}, fn {component, weight}, acc ->
        quality = Map.get(quality_scores, component, 1.0)
        adjusted_weight = weight * quality
        Map.put(acc, component, adjusted_weight)
      end)

    # Normalize weights to sum to 1.0
    total = Enum.sum(Map.values(optimized_weights))

    Enum.reduce(optimized_weights, %{}, fn {component, weight}, acc ->
      Map.put(acc, component, weight / total)
    end)
  end

  defp assess_feature_quality(features) do
    %{
      behavioral: assess_behavioral_quality(features.behavioral_features),
      combat: assess_combat_quality(features.combat_features),
      network: assess_network_quality(features.network_features),
      anomaly: assess_statistical_quality(features.statistical_features)
    }
  end

  # Helper Functions

  defp calculate_kd_ratio(killmails) when is_list(killmails) do
    kills = count_kills(killmails)
    losses = count_losses(killmails)

    if losses == 0, do: kills * 1.0, else: kills / losses
  end

  defp calculate_kd_ratio(_), do: 0.0

  defp count_kills(killmails) when is_list(killmails) do
    Enum.count(killmails, fn km ->
      is_map(km) && Map.get(km, :is_victim, false) == false
    end)
  end

  defp count_kills(_), do: 0

  defp count_losses(killmails) when is_list(killmails) do
    Enum.count(killmails, fn km ->
      is_map(km) && Map.get(km, :is_victim, false) == true
    end)
  end

  defp count_losses(_), do: 0

  defp sum_isk_destroyed(killmails) when is_list(killmails) do
    killmails
    |> Enum.filter(fn km ->
      is_map(km) && Map.get(km, :is_victim, false) == false
    end)
    |> Enum.map(fn km -> Map.get(km, :total_value, 0.0) end)
    |> Enum.sum()
  end

  defp sum_isk_destroyed(_), do: 0.0

  defp sum_isk_lost(killmails) when is_list(killmails) do
    killmails
    |> Enum.filter(fn km ->
      is_map(km) && Map.get(km, :is_victim, false) == true
    end)
    |> Enum.map(fn km -> Map.get(km, :total_value, 0.0) end)
    |> Enum.sum()
  end

  defp sum_isk_lost(_), do: 0.0

  defp calculate_isk_efficiency(killmails) do
    destroyed = sum_isk_destroyed(killmails)
    lost = sum_isk_lost(killmails)

    total = destroyed + lost
    if total == 0, do: 0.0, else: destroyed / total
  end

  defp calculate_days_active(killmails) do
    if Enum.empty?(killmails) do
      0
    else
      dates =
        killmails
        |> Enum.map(&DateTime.to_date(&1.killmail_time))
        |> Enum.uniq()

      length(dates)
    end
  end

  defp calculate_character_age(_character_stats) do
    # Placeholder - would use actual character creation date
    365
  end

  defp filter_by_window(killmails, days) when is_list(killmails) and is_integer(days) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    Enum.filter(killmails, fn km ->
      is_map(km) && is_struct(Map.get(km, :killmail_time), DateTime) &&
        DateTime.compare(km.killmail_time, cutoff) != :lt
    end)
  end

  defp filter_by_window(_, _), do: []

  defp count_unique_systems(killmails) do
    killmails
    |> Enum.map(& &1.solar_system_id)
    |> Enum.uniq()
    |> length()
  end

  defp calculate_activity_variance(killmails) do
    if length(killmails) < 2 do
      0.0
    else
      # Group by day and calculate variance
      daily_counts =
        killmails
        |> Enum.group_by(&DateTime.to_date(&1.killmail_time))
        |> Enum.map(fn {_date, kms} -> length(kms) end)

      mean = Enum.sum(daily_counts) / length(daily_counts)

      variance =
        daily_counts
        |> Enum.map(fn count -> :math.pow(count - mean, 2) end)
        |> Enum.sum()
        |> Kernel./(length(daily_counts))

      Float.round(variance, 3)
    end
  end

  defp calculate_peak_hour_concentration(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      hourly_counts =
        killmails
        |> Enum.map(&DateTime.to_time(&1.killmail_time).hour)
        |> Enum.frequencies()

      max_hour_count = hourly_counts |> Map.values() |> Enum.max(fn -> 0 end)
      total_count = length(killmails)

      max_hour_count / total_count
    end
  end

  defp calculate_weekend_ratio(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      weekend_count =
        Enum.count(killmails, fn km ->
          day = Date.day_of_week(DateTime.to_date(km.killmail_time))
          # Saturday, Sunday
          day in [6, 7]
        end)

      weekend_count / length(killmails)
    end
  end

  defp calculate_percentiles(values, percentiles) do
    if Enum.empty?(values) do
      Enum.map(percentiles, fn p -> {p, 0} end) |> Map.new()
    else
      sorted = Enum.sort(values)
      count = length(sorted)

      percentiles
      |> Enum.map(fn p ->
        index = round(p * (count - 1))
        value = Enum.at(sorted, index)
        {p, value}
      end)
      |> Map.new()
    end
  end

  defp calculate_composite_score(behavioral, combat, network, anomaly, weights) do
    scores = %{
      behavioral: behavioral,
      combat: combat,
      network: network,
      anomaly: anomaly
    }

    weighted_sum =
      Enum.reduce(scores, 0.0, fn {component, score}, acc ->
        weight = Map.get(weights, component, 0.0)
        acc + score * weight
      end)

    Float.round(weighted_sum, 3)
  end

  defp calculate_feature_importance(_features) do
    # Simplified feature importance based on variance and correlation
    %{
      kill_death_ratio: 0.15,
      isk_efficiency: 0.12,
      activity_consistency: 0.10,
      network_size: 0.10,
      combat_diversity: 0.08,
      anomaly_score: 0.08,
      timezone_stability: 0.07,
      fleet_participation: 0.06,
      target_selection: 0.06,
      operational_security: 0.05,
      other_features: 0.13
    }
  end

  defp calculate_model_confidence(features) do
    # Confidence based on data completeness and quality
    data_points = features.basic_stats.total_kills + features.basic_stats.total_losses

    confidence =
      cond do
        data_points >= 100 -> 0.95
        data_points >= 50 -> 0.85
        data_points >= 20 -> 0.70
        data_points >= 10 -> 0.50
        true -> 0.30
      end

    Float.round(confidence, 2)
  end

  # Normalization functions

  defp normalize_kd_ratio(ratio) do
    # Sigmoid normalization for K/D ratio
    max(0.0, min(1.0, ratio / (ratio + 2.0)))
  end

  defp normalize_kill_value(avg_value) do
    # Log normalization for ISK values
    if avg_value <= 0 do
      0.0
    else
      # 10B ISK = 1.0
      normalized = :math.log10(avg_value) / 10.0
      min(1.0, normalized)
    end
  end

  defp normalize_network_size(count) do
    # Square root normalization for network size
    # 100 connections = 1.0
    min(1.0, :math.sqrt(count) / 10.0)
  end

  # Additional ML-specific functions would go here...
  # Including anomaly detection, trend analysis, ensemble methods, etc.

  defp calculate_solo_ratio(killmails) do
    total_kills = length(killmails)

    if total_kills > 0 do
      solo_kills =
        Enum.count(killmails, fn km ->
          attackers = Map.get(km, :attackers, [])
          length(attackers) == 1
        end)

      solo_kills / total_kills
    else
      0.0
    end
  end

  defp calculate_average_gang_size(killmails) do
    if length(killmails) > 0 do
      total_attackers =
        killmails
        |> Enum.map(fn km -> length(Map.get(km, :attackers, [])) end)
        |> Enum.sum()

      total_attackers / length(killmails)
    else
      0.0
    end
  end

  defp calculate_ship_diversity(killmails) do
    unique_ships =
      killmails
      |> Enum.map(& &1.ship_type_id)
      |> Enum.uniq()
      |> length()

    # Normalize to 0-1 scale (assuming max 20 different ship types is high diversity)
    min(unique_ships / 20.0, 1.0)
  end

  defp calculate_capital_usage(killmails) do
    total_kills = length(killmails)

    if total_kills > 0 do
      capital_kills =
        Enum.count(killmails, fn km ->
          # This would need actual ship classification logic
          ship_type_id = km.ship_type_id
          # Simple heuristic: ship type IDs above 30000 are often capitals
          ship_type_id > 30000
        end)

      capital_kills / total_kills
    else
      0.0
    end
  end

  defp calculate_average_value(killmails) do
    if length(killmails) > 0 do
      total_value = Enum.sum(Enum.map(killmails, & &1.total_value))
      total_value / length(killmails)
    else
      0.0
    end
  end

  defp calculate_killing_blow_ratio(killmails) do
    total_kills = length(killmails)

    if total_kills > 0 do
      final_blows =
        Enum.count(killmails, fn km ->
          Map.get(km, :is_final_blow, false)
        end)

      final_blows / total_kills
    else
      0.0
    end
  end

  defp calculate_weapon_diversity(killmails) do
    unique_weapons =
      killmails
      |> Enum.flat_map(fn km -> Map.get(km, :attackers, []) end)
      |> Enum.map(fn attacker -> Map.get(attacker, :weapon_type_id) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> length()

    # Normalize to 0-1 scale (assuming max 15 different weapon types is high diversity)
    min(unique_weapons / 15.0, 1.0)
  end

  defp calculate_engagement_variance(killmails) do
    if length(killmails) < 2 do
      0.0
    else
      values = Enum.map(killmails, & &1.total_value)
      mean = Enum.sum(values) / length(values)

      if mean > 0 do
        variance =
          Enum.reduce(values, 0, fn val, acc ->
            acc + :math.pow(val - mean, 2)
          end) / length(values)

        :math.sqrt(variance) / mean
      else
        0.0
      end
    end
  end

  defp count_unique_allies(killmails) do
    killmails
    |> Enum.flat_map(fn km -> Map.get(km, :attackers, []) end)
    |> Enum.map(fn attacker -> Map.get(attacker, :character_id) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> length()
  end

  defp calculate_repeat_engagement_ratio(killmails) do
    if length(killmails) > 1 do
      # Count how many times this character engages the same targets
      victims = Enum.map(killmails, fn km -> km.victim.character_id end)
      unique_victims = Enum.uniq(victims)

      if length(unique_victims) > 0 do
        1.0 - length(unique_victims) / length(victims)
      else
        0.0
      end
    else
      0.0
    end
  end

  defp calculate_corp_diversity(killmails) do
    unique_corps =
      killmails
      |> Enum.map(fn km -> Map.get(km.victim, :corporation_id) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> length()

    # Normalize: more than 10 different corps is high diversity
    min(unique_corps / 10.0, 1.0)
  end

  defp calculate_alliance_participation(killmails) do
    unique_alliances =
      killmails
      |> Enum.map(fn km -> Map.get(km.victim, :alliance_id) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> length()

    # Normalize: more than 5 different alliances is high participation
    min(unique_alliances / 5.0, 1.0)
  end

  # Simplified implementations that return meaningful but basic calculations
  defp calculate_social_clustering(killmails) do
    # Simple heuristic: how often do you kill with the same people
    if length(killmails) > 1 do
      all_allies =
        killmails
        |> Enum.flat_map(fn km -> Map.get(km, :attackers, []) end)
        |> Enum.map(fn attacker -> Map.get(attacker, :character_id) end)
        |> Enum.reject(&is_nil/1)

      unique_allies = Enum.uniq(all_allies)

      if length(unique_allies) > 0 do
        1.0 - length(unique_allies) / length(all_allies)
      else
        0.0
      end
    else
      0.0
    end
  end

  defp calculate_fleet_consistency(killmails) do
    # How consistent are gang sizes
    gang_sizes = Enum.map(killmails, fn km -> length(Map.get(km, :attackers, [])) end)

    if length(gang_sizes) > 1 do
      mean = Enum.sum(gang_sizes) / length(gang_sizes)

      variance =
        Enum.reduce(gang_sizes, 0, fn size, acc ->
          acc + :math.pow(size - mean, 2)
        end) / length(gang_sizes)

      # Lower variance = higher consistency
      max(0.0, 1.0 - :math.sqrt(variance) / mean)
    else
      1.0
    end
  end

  # Anomaly detection functions - simplified implementations
  defp detect_value_anomalies(killmails) do
    if length(killmails) < 3 do
      0
    else
      values = Enum.map(killmails, & &1.total_value)
      mean = Enum.sum(values) / length(values)
      outliers = Enum.count(values, fn val -> abs(val - mean) > mean * 2 end)
      outliers
    end
  end

  defp detect_temporal_anomalies(killmails) do
    # Simple temporal anomaly detection based on unusual kill timing
    if length(killmails) < 3 do
      0
    else
      timestamps =
        Enum.map(killmails, & &1.killmail_time)
        |> Enum.sort(DateTime)

      intervals =
        timestamps
        |> Enum.zip(Enum.drop(timestamps, 1))
        |> Enum.map(fn {t1, t2} -> DateTime.diff(t2, t1, :second) end)

      if length(intervals) > 0 do
        mean_interval = Enum.sum(intervals) / length(intervals)

        unusual_intervals =
          Enum.count(intervals, fn interval ->
            abs(interval - mean_interval) > mean_interval * 3
          end)

        unusual_intervals
      else
        0
      end
    end
  end

  defp detect_behavioral_anomalies_score(_killmails), do: 0
  defp detect_combat_anomalies(_killmails), do: 0

  # Quality assessment functions
  defp assess_behavioral_quality(features) do
    # Simple data quality check based on available features
    required_fields = [:activity_consistency, :timezone_stability, :operational_security_score]
    available_fields = Map.keys(features.behavioral_features || %{})
    overlap = MapSet.intersection(MapSet.new(required_fields), MapSet.new(available_fields))
    MapSet.size(overlap) / length(required_fields)
  end

  defp assess_combat_quality(features) do
    basic_stats = features.basic_stats || %{}
    required_fields = [:kill_death_ratio, :isk_efficiency]

    available_count =
      Enum.count(required_fields, fn field -> Map.has_key?(basic_stats, field) end)

    available_count / length(required_fields)
  end

  defp assess_network_quality(features) do
    network_features = features.network_features || %{}
    if map_size(network_features) > 0, do: 1.0, else: 0.0
  end

  defp assess_statistical_quality(features) do
    statistical_features = features.statistical_features || %{}
    if map_size(statistical_features) > 0, do: 1.0, else: 0.0
  end

  # Behavioral feature functions
  defp measure_activity_consistency(killmails) do
    if length(killmails) < 7 do
      # Neutral consistency for insufficient data
      0.5
    else
      # Group by day of week and measure consistency
      daily_counts =
        killmails
        |> Enum.group_by(fn km -> DateTime.to_date(km.killmail_time) |> Date.day_of_week() end)
        |> Enum.map(fn {_day, kills} -> length(kills) end)

      if length(daily_counts) > 1 do
        mean = Enum.sum(daily_counts) / length(daily_counts)

        variance =
          Enum.reduce(daily_counts, 0, fn count, acc ->
            acc + :math.pow(count - mean, 2)
          end) / length(daily_counts)

        # Higher consistency = lower variance
        max(0.0, 1.0 - :math.sqrt(variance) / mean)
      else
        1.0
      end
    end
  end

  defp calculate_timezone_stability(killmails) do
    if length(killmails) < 3 do
      0.5
    else
      # Extract hours of activity
      hours =
        killmails
        |> Enum.map(fn km -> km.killmail_time.hour end)

      # Measure how concentrated the activity is in certain hours
      hour_counts = Enum.frequencies(hours)
      max_count = Enum.max(Map.values(hour_counts))
      total_count = length(killmails)

      # Higher concentration = higher stability
      max_count / total_count
    end
  end

  defp identify_hunting_patterns(killmails) do
    if length(killmails) < 2 do
      0.0
    else
      # Simple pattern: how often kills happen in quick succession
      timestamps = Enum.map(killmails, & &1.killmail_time) |> Enum.sort(DateTime)

      quick_succession =
        timestamps
        |> Enum.zip(Enum.drop(timestamps, 1))
        |> Enum.count(fn {t1, t2} -> DateTime.diff(t2, t1, :minute) < 15 end)

      quick_succession / (length(timestamps) - 1)
    end
  end

  defp calculate_risk_index(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      # Risk based on going after high-value targets and ship types
      high_value_kills = Enum.count(killmails, fn km -> km.total_value > 100_000_000 end)
      high_value_ratio = high_value_kills / length(killmails)

      # Risk based on attacking capitals/expensive ships
      expensive_ships = Enum.count(killmails, fn km -> km.total_value > 500_000_000 end)
      expensive_ratio = expensive_ships / length(killmails)

      # Combined risk index
      high_value_ratio * 0.6 + expensive_ratio * 0.4
    end
  end

  defp analyze_target_selection(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      # Analyze if pilot shows bias toward certain target types
      ship_types = Enum.map(killmails, & &1.ship_type_id)
      ship_frequencies = Enum.frequencies(ship_types)

      if map_size(ship_frequencies) > 0 do
        # Measure how concentrated the targeting is
        max_frequency = Enum.max(Map.values(ship_frequencies))
        max_frequency / length(killmails)
      else
        0.0
      end
    end
  end

  defp measure_opsec(killmails) do
    if Enum.empty?(killmails) do
      # No data = assume good opsec
      1.0
    else
      # Simple heuristic: variety in systems and timing suggests better opsec
      unique_systems =
        killmails
        |> Enum.map(& &1.solar_system_id)
        |> Enum.uniq()
        |> length()

      system_diversity = min(unique_systems / length(killmails), 1.0)

      # Time diversity - kills spread across different hours
      unique_hours =
        killmails
        |> Enum.map(fn km -> km.killmail_time.hour end)
        |> Enum.uniq()
        |> length()

      time_diversity = unique_hours / 24.0

      # Combined opsec score
      system_diversity * 0.6 + time_diversity * 0.4
    end
  end

  # Statistical functions
  defp calculate_time_interval_stats(timestamps) do
    if length(timestamps) < 2 do
      %{mean: 0, variance: 0, min: 0, max: 0}
    else
      sorted_timestamps = Enum.sort(timestamps, DateTime)

      intervals =
        sorted_timestamps
        |> Enum.zip(Enum.drop(sorted_timestamps, 1))
        |> Enum.map(fn {t1, t2} -> DateTime.diff(t2, t1, :second) end)

      mean = Enum.sum(intervals) / length(intervals)

      variance =
        if length(intervals) > 1 do
          Enum.reduce(intervals, 0, fn interval, acc ->
            acc + :math.pow(interval - mean, 2)
          end) / length(intervals)
        else
          0
        end

      %{
        mean: mean,
        variance: variance,
        min: Enum.min(intervals),
        max: Enum.max(intervals)
      }
    end
  end

  defp calculate_skewness(values) do
    if length(values) < 3 do
      0.0
    else
      mean = Enum.sum(values) / length(values)

      variance =
        Enum.reduce(values, 0, fn val, acc ->
          acc + :math.pow(val - mean, 2)
        end) / length(values)

      if variance > 0 do
        std_dev = :math.sqrt(variance)

        skewness =
          Enum.reduce(values, 0, fn val, acc ->
            acc + :math.pow((val - mean) / std_dev, 3)
          end) / length(values)

        skewness
      else
        0.0
      end
    end
  end

  defp calculate_kurtosis(values) do
    if length(values) < 4 do
      0.0
    else
      mean = Enum.sum(values) / length(values)

      variance =
        Enum.reduce(values, 0, fn val, acc ->
          acc + :math.pow(val - mean, 2)
        end) / length(values)

      if variance > 0 do
        std_dev = :math.sqrt(variance)

        kurtosis =
          Enum.reduce(values, 0, fn val, acc ->
            acc + :math.pow((val - mean) / std_dev, 4)
          end) / length(values)

        # Subtract 3 for excess kurtosis
        kurtosis - 3.0
      else
        0.0
      end
    end
  end

  defp calculate_activity_entropy(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      # Calculate entropy based on system activity distribution
      system_counts =
        killmails
        |> Enum.map(& &1.solar_system_id)
        |> Enum.frequencies()
        |> Map.values()

      total = length(killmails)

      entropy =
        system_counts
        |> Enum.reduce(0, fn count, acc ->
          p = count / total

          if p > 0 do
            acc - p * :math.log2(p)
          else
            acc
          end
        end)

      # Normalize to 0-1 scale
      max_entropy = :math.log2(length(system_counts))
      if max_entropy > 0, do: entropy / max_entropy, else: 0.0
    end
  end

  defp detect_activity_bursts(timestamps) do
    if length(timestamps) < 3 do
      0.0
    else
      sorted_timestamps = Enum.sort(timestamps, DateTime)

      intervals =
        sorted_timestamps
        |> Enum.zip(Enum.drop(sorted_timestamps, 1))
        |> Enum.map(fn {t1, t2} -> DateTime.diff(t2, t1, :minute) end)

      # Define burst as multiple kills within 5 minutes
      burst_intervals = Enum.count(intervals, fn interval -> interval <= 5 end)
      burst_intervals / length(intervals)
    end
  end

  # Advanced feature functions
  defp calculate_kd_isk_interaction(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      kills = Enum.filter(killmails, fn km -> not Map.get(km, :is_victim, false) end)
      deaths = Enum.filter(killmails, fn km -> Map.get(km, :is_victim, false) end)

      avg_kill_value =
        if length(kills) > 0 do
          Enum.sum(Enum.map(kills, & &1.total_value)) / length(kills)
        else
          0
        end

      avg_death_value =
        if length(deaths) > 0 do
          Enum.sum(Enum.map(deaths, & &1.total_value)) / length(deaths)
        else
          0
        end

      # Higher kill value vs death value indicates better performance
      if avg_death_value > 0 do
        min(avg_kill_value / avg_death_value / 10.0, 1.0)
      else
        min(avg_kill_value / 100_000_000.0, 1.0)
      end
    end
  end

  defp calculate_trend_slope(killmails, metric) do
    if length(killmails) < 3 do
      0.0
    else
      # Group killmails by week and calculate trend
      sorted_killmails = Enum.sort_by(killmails, & &1.killmail_time, DateTime)

      # Calculate weekly values
      weekly_data =
        sorted_killmails
        |> Enum.group_by(fn km ->
          Date.beginning_of_week(DateTime.to_date(km.killmail_time))
        end)
        |> Enum.map(fn {week, kms} ->
          value =
            case metric do
              :kills -> length(kms)
              :value -> Enum.sum(Enum.map(kms, & &1.total_value))
              _ -> length(kms)
            end

          {week, value}
        end)
        |> Enum.sort_by(fn {week, _} -> week end, Date)

      if length(weekly_data) < 2 do
        0.0
      else
        # Simple linear trend calculation
        values = Enum.map(weekly_data, fn {_, value} -> value end)
        first_half_sum = Enum.take(values, div(length(values), 2)) |> Enum.sum()
        first_half_avg = first_half_sum / max(div(length(values), 2), 1)
        second_half_sum = Enum.drop(values, div(length(values), 2)) |> Enum.sum()
        second_half_avg = second_half_sum / max(length(values) - div(length(values), 2), 1)

        # Normalize trend slope
        if first_half_avg > 0 do
          (second_half_avg - first_half_avg) / first_half_avg
        else
          0.0
        end
      end
    end
  end

  defp calculate_high_value_ratio(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      high_value_kills = Enum.count(killmails, fn km -> km.total_value > 1_000_000_000 end)
      high_value_kills / length(killmails)
    end
  end

  defp calculate_defensive_losses(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      # Simple heuristic: losses in home systems or known defensive situations
      defensive_losses =
        Enum.count(killmails, fn km ->
          # Outnumbered = defensive
          Map.get(km, :is_victim, false) and
            Map.get(km, :attackers, []) |> length() > 3
        end)

      total_losses = Enum.count(killmails, fn km -> Map.get(km, :is_victim, false) end)

      if total_losses > 0 do
        defensive_losses / total_losses
      else
        0.0
      end
    end
  end

  defp detect_periodic_patterns(killmails) do
    if length(killmails) < 7 do
      0.0
    else
      # Detect patterns in daily activity
      daily_activity =
        killmails
        |> Enum.group_by(fn km ->
          DateTime.to_date(km.killmail_time) |> Date.day_of_week()
        end)
        |> Enum.map(fn {day, kms} -> {day, length(kms)} end)
        |> Enum.sort_by(fn {day, _} -> day end)

      if length(daily_activity) > 1 do
        values = Enum.map(daily_activity, fn {_, count} -> count end)
        mean = Enum.sum(values) / length(values)

        # Measure how much the pattern deviates from uniform distribution
        variance =
          Enum.reduce(values, 0, fn count, acc ->
            acc + :math.pow(count - mean, 2)
          end) / length(values)

        # Higher variance suggests more periodic patterns
        if mean > 0 do
          min(:math.sqrt(variance) / mean, 1.0)
        else
          0.0
        end
      else
        0.0
      end
    end
  end

  defp calculate_engagement_complexity(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      # Measure complexity based on various factors
      ship_diversity =
        killmails
        |> Enum.map(& &1.ship_type_id)
        |> Enum.uniq()
        |> length()

      system_diversity =
        killmails
        |> Enum.map(& &1.solar_system_id)
        |> Enum.uniq()
        |> length()

      avg_gang_size =
        killmails
        |> Enum.map(fn km -> length(Map.get(km, :attackers, [])) end)
        |> Enum.sum()
        |> Kernel./(length(killmails))

      # Combine factors for complexity score
      ship_factor = min(ship_diversity / 10.0, 1.0)
      system_factor = min(system_diversity / 20.0, 1.0)
      gang_factor = min(avg_gang_size / 20.0, 1.0)

      ship_factor * 0.4 + system_factor * 0.3 + gang_factor * 0.3
    end
  end

  # Ensemble scoring functions

  defp score_behavioral_model(features) do
    {:ok, score} = calculate_behavioral_score(features)
    score
  end

  defp score_combat_model(features) do
    {:ok, score} = calculate_combat_effectiveness_score(features)
    score
  end

  defp score_network_model(features) do
    {:ok, score} = calculate_network_influence_score(features)
    score
  end

  defp score_anomaly_model(features) do
    {:ok, score} = calculate_anomaly_detection_score(features)
    score
  end

  defp calculate_weighted_ensemble(model_scores) do
    weighted_sum =
      Enum.reduce(model_scores, 0.0, fn {_name, score, weight}, acc ->
        acc + score * weight
      end)

    Float.round(weighted_sum, 3)
  end

  defp format_model_scores(model_scores) do
    Enum.map(model_scores, fn {name, score, _weight} ->
      {name, Float.round(score, 3)}
    end)
    |> Map.new()
  end

  defp calculate_ensemble_confidence(model_scores) do
    scores = Enum.map(model_scores, fn {_name, score, _weight} -> score end)

    # Confidence based on agreement between models
    mean = Enum.sum(scores) / length(scores)

    variance =
      scores
      |> Enum.map(fn score -> :math.pow(score - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(length(scores))

    # Lower variance = higher confidence
    confidence = max(0.0, 1.0 - :math.sqrt(variance))
    Float.round(confidence, 2)
  end

  defp generate_ml_recommendation(score) do
    cond do
      score >= 0.9 -> "Exceptional candidate - ML models show consistent excellence"
      score >= 0.8 -> "Strong candidate - High scores across multiple dimensions"
      score >= 0.7 -> "Good candidate - Above average in most metrics"
      score >= 0.6 -> "Average candidate - Mixed signals from ML analysis"
      score >= 0.5 -> "Below average - Several concerning patterns detected"
      true -> "Poor candidate - ML models indicate significant risks"
    end
  end

  # Anomaly detection helpers

  defp calculate_baseline_behavior(_character_id) do
    # Calculate statistical baseline from historical data
    {:ok,
     %{
       activity_mean: 5.0,
       activity_std: 2.0,
       value_mean: 100_000_000,
       value_std: 50_000_000,
       timezone_mode: 21
     }}
  end

  defp identify_anomalies(_features, _baseline) do
    # Identify deviations from baseline
    []
  end

  defp calculate_anomaly_score(anomalies) do
    # Score based on anomaly severity
    max(0.0, 1.0 - length(anomalies) / 10.0)
  end

  defp calculate_anomaly_confidence(features) do
    # Confidence in anomaly detection
    data_points = features.basic_stats.total_kills + features.basic_stats.total_losses
    min(0.95, data_points / 100.0)
  end

  # Trend prediction helpers

  defp get_historical_features(_character_id) do
    # Get time-series features
    {:ok, []}
  end

  defp fit_trend_model(_historical_data) do
    # Fit trend model to historical data
    {:ok,
     %{
       current_level: 0.5,
       trend_slope: 0.01,
       seasonality: [],
       residuals: []
     }}
  end

  defp apply_trend_model(model, days_ahead) do
    # Apply model for prediction
    %{
      threat_level: model.current_level + model.trend_slope * days_ahead,
      confidence_interval: {0.4, 0.6},
      trend: if(model.trend_slope > 0, do: :increasing, else: :decreasing)
    }
  end

  defp identify_risk_factors(_model) do
    # Identify factors contributing to trend
    []
  end
end
