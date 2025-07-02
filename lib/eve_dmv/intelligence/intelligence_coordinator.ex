defmodule EveDmv.Intelligence.IntelligenceCoordinator do
  @moduledoc """
  Central coordinator for all intelligence analysis operations.

  Orchestrates analysis across multiple intelligence modules,
  manages caching, and provides unified intelligence insights.
  """

  require Logger

  alias EveDmv.Intelligence.{
    CharacterAnalyzer,
    CorrelationEngine,
    HomeDefenseAnalyzer,
    IntelligenceCache,
    MemberActivityAnalyzer,
    WHFleetAnalyzer,
    WHVettingAnalyzer
  }

  @doc """
  Perform comprehensive intelligence analysis for a character.

  This is the primary entry point for getting complete intelligence
  analysis that includes data from all modules and cross-correlations.
  """
  def analyze_character_comprehensive(character_id, options \\ []) do
    Logger.info("Starting comprehensive intelligence analysis for character #{character_id}")

    use_cache = Keyword.get(options, :use_cache, true)
    include_correlations = Keyword.get(options, :include_correlations, true)

    with {:ok, basic_analysis} <- get_basic_analysis(character_id, use_cache),
         {:ok, specialized_analysis} <- get_specialized_analysis(character_id, use_cache),
         {:ok, correlations} <- get_correlations(character_id, use_cache, include_correlations) do
      # Combine all analysis results
      comprehensive_analysis = %{
        character_id: character_id,
        analysis_timestamp: DateTime.utc_now(),
        basic_analysis: basic_analysis,
        specialized_analysis: specialized_analysis,
        correlations: correlations,
        intelligence_summary:
          generate_intelligence_summary(basic_analysis, specialized_analysis, correlations),
        confidence_score:
          calculate_overall_confidence(basic_analysis, specialized_analysis, correlations),
        recommendations:
          generate_unified_recommendations(basic_analysis, specialized_analysis, correlations)
      }

      {:ok, comprehensive_analysis}
    else
      {:error, reason} ->
        Logger.error(
          "Comprehensive analysis failed for character #{character_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Analyze multiple characters for comparison or correlation analysis.
  """
  def analyze_character_group(character_ids, options \\ []) do
    Logger.info("Analyzing character group of #{length(character_ids)} characters")

    use_cache = Keyword.get(options, :use_cache, true)

    # Analyze each character individually
    individual_analyses =
      character_ids
      |> Enum.map(fn char_id ->
        case analyze_character_comprehensive(char_id,
               use_cache: use_cache,
               include_correlations: false
             ) do
          {:ok, analysis} ->
            {char_id, analysis}

          {:error, reason} ->
            Logger.warning("Failed to analyze character #{char_id}: #{inspect(reason)}")
            {char_id, nil}
        end
      end)
      |> Enum.filter(fn {_id, analysis} -> not is_nil(analysis) end)
      |> Enum.into(%{})

    if map_size(individual_analyses) < 2 do
      {:error, "Insufficient character data for group analysis"}
    else
      # Perform group-level correlations
      case CorrelationEngine.analyze_character_correlations(Map.keys(individual_analyses)) do
        {:ok, group_correlations} ->
          group_analysis = %{
            character_ids: character_ids,
            analysis_timestamp: DateTime.utc_now(),
            individual_analyses: individual_analyses,
            group_correlations: group_correlations,
            group_summary: generate_group_summary(individual_analyses, group_correlations),
            group_recommendations:
              generate_group_recommendations(individual_analyses, group_correlations)
          }

          {:ok, group_analysis}

        {:error, reason} ->
          Logger.warning("Group correlation analysis failed: #{inspect(reason)}")

          # Return individual analyses without correlations
          group_analysis = %{
            character_ids: character_ids,
            analysis_timestamp: DateTime.utc_now(),
            individual_analyses: individual_analyses,
            group_correlations: nil,
            group_summary: "Group correlation analysis unavailable",
            group_recommendations: []
          }

          {:ok, group_analysis}
      end
    end
  end

  @doc """
  Analyze corporation intelligence patterns.
  """
  def analyze_corporation_intelligence(corporation_id, options \\ []) do
    Logger.info("Analyzing corporation intelligence for corp #{corporation_id}")

    use_cache = Keyword.get(options, :use_cache, true)

    case CorrelationEngine.analyze_corporation_intelligence_patterns(corporation_id) do
      {:ok, corp_patterns} ->
        corp_analysis = %{
          corporation_id: corporation_id,
          analysis_timestamp: DateTime.utc_now(),
          intelligence_patterns: corp_patterns,
          corp_summary: generate_corp_summary(corp_patterns),
          security_assessment: assess_corp_security(corp_patterns),
          recommendations: generate_corp_recommendations(corp_patterns)
        }

        {:ok, corp_analysis}

      {:error, reason} ->
        Logger.error(
          "Corporation intelligence analysis failed for corp #{corporation_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Get intelligence dashboard data for real-time monitoring.
  """
  def get_intelligence_dashboard(options \\ []) do
    Logger.info("Generating intelligence dashboard")

    timeframe = Keyword.get(options, :timeframe, :last_24_hours)

    # Get recent intelligence activity
    recent_analyses = get_recent_intelligence_activity(timeframe)
    threat_alerts = get_active_threat_alerts()
    cache_performance = IntelligenceCache.get_cache_stats()

    dashboard = %{
      timestamp: DateTime.utc_now(),
      timeframe: timeframe,
      recent_analyses: recent_analyses,
      threat_alerts: threat_alerts,
      cache_performance: cache_performance,
      system_health: assess_intelligence_system_health()
    }

    {:ok, dashboard}
  end

  @doc """
  Invalidate intelligence cache when new data is available.
  """
  def invalidate_character_intelligence(character_id, reason \\ "data_update") do
    Logger.info("Invalidating intelligence cache for character #{character_id}: #{reason}")

    IntelligenceCache.invalidate_character_cache(character_id)

    # Also invalidate any group analyses that included this character
    invalidate_related_group_analyses(character_id)

    :ok
  end

  @doc """
  Warm intelligence cache for popular characters.
  """
  def warm_intelligence_cache do
    Logger.info("Starting intelligence cache warming")
    IntelligenceCache.warm_popular_cache()
    :ok
  end

  ## Private Helper Functions

  defp get_basic_analysis(character_id, use_cache) do
    if use_cache do
      IntelligenceCache.get_character_analysis(character_id)
    else
      CharacterAnalyzer.analyze_character(character_id)
    end
  end

  defp get_specialized_analysis(character_id, use_cache) do
    # Gather specialized analysis from different modules
    vetting_result = get_vetting_analysis(character_id, use_cache)

    # Get other specialized analyses (without caching for now)
    activity_result =
      safe_analyze(:activity, character_id, &MemberActivityAnalyzer.analyze_member_activity/1)

    fleet_result =
      safe_analyze(:fleet, character_id, &WHFleetAnalyzer.analyze_pilot_performance/1)

    home_defense_result =
      safe_analyze(
        :home_defense,
        character_id,
        &HomeDefenseAnalyzer.analyze_character_home_defense/1
      )

    # Combine results
    case {vetting_result, activity_result, fleet_result, home_defense_result} do
      {{:ok, vetting}, {:ok, activity}, {:ok, fleet}, {:ok, home_defense}} ->
        specialized = %{
          vetting: vetting,
          activity: activity,
          fleet: fleet,
          home_defense: home_defense
        }

        {:ok, specialized}

      _ ->
        # Partial success - include what we can get
        specialized = %{
          vetting:
            case vetting_result do
              {:ok, v} -> v
              _ -> nil
            end,
          activity:
            case activity_result do
              {:ok, a} -> a
              _ -> nil
            end,
          fleet:
            case fleet_result do
              {:ok, f} -> f
              _ -> nil
            end,
          home_defense:
            case home_defense_result do
              {:ok, h} -> h
              _ -> nil
            end
        }

        {:ok, specialized}
    end
  end

  defp get_vetting_analysis(character_id, use_cache) do
    if use_cache do
      IntelligenceCache.get_vetting_analysis(character_id)
    else
      WHVettingAnalyzer.analyze_character(character_id)
    end
  end

  defp safe_analyze(type, character_id, analysis_fn) do
    {:ok, analysis_fn.(character_id)}
  rescue
    error ->
      Logger.warning("#{type} analysis failed for #{character_id}: #{inspect(error)}")
      {:ok, nil}
  end

  defp get_correlations(character_id, use_cache, include_correlations) do
    if include_correlations do
      if use_cache do
        IntelligenceCache.get_correlation_analysis(character_id)
      else
        CorrelationEngine.analyze_cross_module_correlations(character_id)
      end
    else
      {:ok, nil}
    end
  end

  defp generate_intelligence_summary(basic_analysis, specialized_analysis, correlations) do
    summary_points = []

    # Basic analysis summary
    if basic_analysis do
      threat_level = assess_threat_level(basic_analysis)
      summary_points = ["Threat Level: #{threat_level}" | summary_points]

      if basic_analysis.dangerous_rating > 7 do
        summary_points = [
          "High threat rating detected (#{basic_analysis.dangerous_rating}/10)" | summary_points
        ]
      end
    end

    # Vetting summary
    if specialized_analysis.vetting do
      vetting = specialized_analysis.vetting
      summary_points = ["Vetting Status: #{vetting.recommendation}" | summary_points]

      if vetting.overall_risk_score > 70 do
        summary_points = [
          "High vetting risk score (#{vetting.overall_risk_score}/100)" | summary_points
        ]
      end
    end

    # Correlation summary
    if correlations do
      correlation_strength = correlations.confidence_score

      if correlation_strength > 0.8 do
        summary_points = ["Strong cross-module correlations detected" | summary_points]
      end
    end

    if Enum.empty?(summary_points) do
      "Standard intelligence profile - no significant concerns detected."
    else
      Enum.join(summary_points, ". ") <> "."
    end
  end

  defp calculate_overall_confidence(basic_analysis, specialized_analysis, correlations) do
    confidence_factors = []

    # Basic analysis confidence
    if basic_analysis do
      # High confidence in basic analysis
      confidence_factors = [0.8 | confidence_factors]
    end

    # Specialized analysis confidence
    available_modules =
      Enum.count(
        [
          specialized_analysis.vetting,
          specialized_analysis.activity,
          specialized_analysis.fleet,
          specialized_analysis.home_defense
        ],
        &(!is_nil(&1))
      )

    if available_modules > 0 do
      module_confidence = available_modules / 4.0
      confidence_factors = [module_confidence | confidence_factors]
    end

    # Correlation confidence
    if correlations do
      confidence_factors = [correlations.confidence_score | confidence_factors]
    end

    if Enum.empty?(confidence_factors) do
      # Default confidence
      0.5
    else
      Enum.sum(confidence_factors) / length(confidence_factors)
    end
  end

  defp generate_unified_recommendations(basic_analysis, specialized_analysis, correlations) do
    recommendations = []

    # Basic analysis recommendations
    if basic_analysis && basic_analysis.dangerous_rating > 8 do
      recommendations = ["Monitor closely due to high threat rating" | recommendations]
    end

    # Vetting recommendations
    if specialized_analysis.vetting do
      case specialized_analysis.vetting.recommendation do
        "reject" ->
          recommendations = ["Recommend rejection based on vetting analysis" | recommendations]

        "conditional" ->
          recommendations = ["Consider conditional acceptance with monitoring" | recommendations]

        "more_info" ->
          recommendations = ["Gather additional information before decision" | recommendations]

        _ ->
          recommendations
      end
    end

    # Correlation-based recommendations
    if correlations do
      threat_indicators = correlations.correlations.threat_assessment.threat_indicators

      if length(threat_indicators) > 2 do
        recommendations = [
          "Multiple threat indicators confirmed across modules" | recommendations
        ]
      end
    end

    if Enum.empty?(recommendations) do
      ["Standard monitoring and periodic review"]
    else
      recommendations
    end
  end

  defp generate_group_summary(individual_analyses, group_correlations) do
    analysis_count = map_size(individual_analyses)

    # Calculate group threat level
    threat_levels =
      individual_analyses
      |> Enum.map(fn {_id, analysis} ->
        basic = analysis.basic_analysis
        if basic, do: basic.dangerous_rating || 0, else: 0
      end)

    avg_threat =
      if Enum.empty?(threat_levels), do: 0, else: Enum.sum(threat_levels) / length(threat_levels)

    summary =
      "Group analysis of #{analysis_count} characters. Average threat level: #{Float.round(avg_threat, 1)}/10."

    if group_correlations && group_correlations.alt_likelihood > 0.7 do
      summary <> " High probability of alt character relationships detected."
    else
      summary
    end
  end

  defp generate_group_recommendations(individual_analyses, group_correlations) do
    recommendations = []

    # Check for high-risk individuals in group
    high_risk_count =
      individual_analyses
      |> Enum.count(fn {_id, analysis} ->
        basic = analysis.basic_analysis
        basic && basic.dangerous_rating > 7
      end)

    if high_risk_count > 0 do
      recommendations = [
        "#{high_risk_count} high-risk individuals identified in group" | recommendations
      ]
    end

    # Group correlation recommendations
    if group_correlations && group_correlations.alt_likelihood > 0.8 do
      recommendations = [
        "Strong alt character correlations - consider as single entity" | recommendations
      ]
    end

    if Enum.empty?(recommendations) do
      ["Group shows normal intelligence patterns"]
    else
      recommendations
    end
  end

  defp generate_corp_summary(corp_patterns) do
    "Corporation intelligence analysis completed. Risk distribution: #{corp_patterns.risk_distribution.risk_level}."
  end

  defp assess_corp_security(corp_patterns) do
    risk_level = corp_patterns.risk_distribution.risk_level

    %{
      overall_risk: risk_level,
      security_concerns: corp_patterns.risk_distribution.outliers || [],
      recruitment_assessment: corp_patterns.recruitment_patterns.pattern_type
    }
  end

  defp generate_corp_recommendations(corp_patterns) do
    recommendations = []

    case corp_patterns.risk_distribution.risk_level do
      "high" -> recommendations = ["Implement additional security measures" | recommendations]
      "medium" -> recommendations = ["Monitor identified risk outliers" | recommendations]
      _ -> recommendations
    end

    if length(corp_patterns.risk_distribution.outliers || []) > 0 do
      recommendations = [
        "Review high-risk individuals: #{length(corp_patterns.risk_distribution.outliers)} identified"
        | recommendations
      ]
    end

    if Enum.empty?(recommendations) do
      ["Corporation security appears nominal"]
    else
      recommendations
    end
  end

  defp assess_threat_level(basic_analysis) do
    rating = basic_analysis.dangerous_rating || 0

    cond do
      rating >= 9 -> "Critical"
      rating >= 7 -> "High"
      rating >= 5 -> "Medium"
      rating >= 3 -> "Low"
      true -> "Minimal"
    end
  end

  defp get_recent_intelligence_activity(timeframe) do
    # Placeholder - would query recent analysis records
    %{
      total_analyses: 0,
      character_analyses: 0,
      vetting_analyses: 0,
      correlation_analyses: 0
    }
  end

  defp get_active_threat_alerts do
    # Placeholder - would query for active threat alerts
    []
  end

  defp assess_intelligence_system_health do
    cache_stats = IntelligenceCache.get_cache_stats()

    %{
      cache_hit_ratio: cache_stats.hit_ratio,
      cache_size: cache_stats.cache_size,
      system_status: "operational"
    }
  end

  defp invalidate_related_group_analyses(_character_id) do
    # Placeholder - would invalidate group analyses that included this character
    :ok
  end
end
