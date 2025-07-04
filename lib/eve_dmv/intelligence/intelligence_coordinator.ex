defmodule EveDmv.Intelligence.IntelligenceCoordinator do
  @moduledoc """
  Coordinates character intelligence analysis across multiple specialized analyzers.

  This module serves as the central orchestrator for character intelligence gathering,
  combining data from multiple sources:

  - Character analysis (basic info, corporation history)
  - Vetting analysis (threat assessment, eviction participation)
  - Activity analysis (fleet participation, communication patterns)
  - Correlation analysis (cross-module pattern detection)

  ## Usage

      {:ok, analysis} = IntelligenceCoordinator.coordinate_character_analysis(character_id)

  ## Analysis Structure

  The returned analysis contains:
  - `character_analysis`: Basic character information and metrics
  - `vetting_analysis`: Security and threat assessment
  - `activity_analysis`: Behavioral pattern analysis
  - `correlation_data`: Cross-module correlations and insights
  - `recommendations`: Actionable intelligence recommendations

  ## Configuration

  Configure analysis modules in `config.exs`:

      config :eve_dmv, :intelligence,
        analysis_timeout: 30_000,
        correlation_enabled: true
  """

  require Logger

  alias EveDmv.Intelligence.{
    CorrelationEngine,
    IntelligenceCache
  }

  alias EveDmv.Intelligence.CharacterAnalysis.CharacterAnalyzer

  alias EveDmv.Intelligence.WhSpace.VettingAnalyzer, as: WHVettingAnalyzer

  @doc """
  Perform comprehensive intelligence analysis for a character.

  This is the primary entry point for getting complete intelligence
  analysis that includes data from all modules and cross-correlations.
  """
  def analyze_character_comprehensive(character_id, options \\ []) do
    Logger.info("Starting comprehensive intelligence analysis for character #{character_id}")

    options = parse_analysis_options(options)

    case gather_analysis_components(character_id, options) do
      {:ok, analysis_components} ->
        comprehensive_analysis = build_comprehensive_analysis(character_id, analysis_components)
        {:ok, comprehensive_analysis}

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

    with {:ok, individual_analyses} <- gather_individual_analyses(character_ids, use_cache),
         {:ok, group_data} <- perform_group_analysis(character_ids, individual_analyses) do
      {:ok, group_data}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Analyze corporation intelligence patterns.
  """
  def analyze_corporation_intelligence(corporation_id, options \\ []) do
    Logger.info("Analyzing corporation intelligence for corp #{corporation_id}")

    _use_cache = Keyword.get(options, :use_cache, true)

    case CorrelationEngine.analyze_corporation_intelligence_patterns(corporation_id) do
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

  defp parse_analysis_options(options) do
    %{
      use_cache: Keyword.get(options, :use_cache, true),
      include_correlations: Keyword.get(options, :include_correlations, true)
    }
  end

  defp gather_analysis_components(character_id, options) do
    with {:ok, basic_analysis} <- get_basic_analysis(character_id, options.use_cache),
         {:ok, specialized_analysis} <- get_specialized_analysis(character_id, options.use_cache),
         {:ok, correlations} <-
           get_correlations(character_id, options.use_cache, options.include_correlations) do
      analysis_components = %{
        basic_analysis: basic_analysis,
        specialized_analysis: specialized_analysis,
        correlations: correlations
      }

      {:ok, analysis_components}
    end
  end

  defp build_comprehensive_analysis(character_id, analysis_components) do
    %{
      character_id: character_id,
      analysis_timestamp: DateTime.utc_now(),
      basic_analysis: analysis_components.basic_analysis,
      specialized_analysis: analysis_components.specialized_analysis,
      correlations: analysis_components.correlations,
      intelligence_summary: build_intelligence_summary(analysis_components),
      confidence_score: calculate_confidence_score(analysis_components),
      recommendations: build_unified_recommendations(analysis_components)
    }
  end

  defp build_intelligence_summary(%{
         basic_analysis: basic,
         specialized_analysis: specialized,
         correlations: correlations
       }) do
    generate_intelligence_summary(basic, specialized, correlations)
  end

  defp calculate_confidence_score(%{
         basic_analysis: basic,
         specialized_analysis: specialized,
         correlations: correlations
       }) do
    calculate_overall_confidence(basic, specialized, correlations)
  end

  defp build_unified_recommendations(%{
         basic_analysis: basic,
         specialized_analysis: specialized,
         correlations: correlations
       }) do
    generate_unified_recommendations(basic, specialized, correlations)
  end

  defp gather_individual_analyses(character_ids, use_cache) do
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
      {:ok, individual_analyses}
    end
  end

  defp perform_group_analysis(character_ids, individual_analyses) do
    case CorrelationEngine.analyze_character_correlations(Map.keys(individual_analyses)) do
      {:ok, group_correlations} ->
        group_analysis =
          build_successful_group_analysis(character_ids, individual_analyses, group_correlations)

        {:ok, group_analysis}

      {:error, reason} ->
        Logger.warning("Group correlation analysis failed: #{inspect(reason)}")
        group_analysis = build_fallback_group_analysis(character_ids, individual_analyses)
        {:ok, group_analysis}
    end
  end

  defp build_successful_group_analysis(character_ids, individual_analyses, group_correlations) do
    %{
      character_ids: character_ids,
      analysis_timestamp: DateTime.utc_now(),
      individual_analyses: individual_analyses,
      group_correlations: group_correlations,
      group_summary: generate_group_summary(individual_analyses, group_correlations),
      group_recommendations:
        generate_group_recommendations(individual_analyses, group_correlations)
    }
  end

  defp build_fallback_group_analysis(character_ids, individual_analyses) do
    %{
      character_ids: character_ids,
      analysis_timestamp: DateTime.utc_now(),
      individual_analyses: individual_analyses,
      group_correlations: nil,
      group_summary: "Group correlation analysis unavailable",
      group_recommendations: []
    }
  end

  defp get_basic_analysis(character_id, use_cache) do
    if use_cache do
      IntelligenceCache.get_character_analysis(character_id)
    else
      CharacterAnalyzer.analyze_character(character_id)
    end
  end

  defp get_specialized_analysis(character_id, use_cache) do
    analysis_modules = gather_specialized_analysis_modules(character_id, use_cache)
    specialized_results = build_specialized_analysis_results(analysis_modules)
    {:ok, specialized_results}
  end

  defp gather_specialized_analysis_modules(character_id, use_cache) do
    %{
      vetting: get_vetting_analysis(character_id, use_cache),
      activity: get_activity_analysis(character_id, use_cache),
      fleet: get_fleet_analysis(character_id, use_cache),
      home_defense: get_home_defense_analysis(character_id, use_cache)
    }
  end

  defp build_specialized_analysis_results(analysis_modules) do
    %{
      vetting: extract_analysis_result(analysis_modules.vetting),
      activity: extract_analysis_result(analysis_modules.activity),
      fleet: extract_analysis_result(analysis_modules.fleet),
      home_defense: extract_analysis_result(analysis_modules.home_defense)
    }
  end

  defp extract_analysis_result({:ok, result}), do: result
  defp extract_analysis_result({:error, _reason}), do: nil
  defp extract_analysis_result(nil), do: nil

  defp get_activity_analysis(_character_id, _use_cache) do
    # Activity analysis requires time range, skip for now
    {:ok, nil}
  end

  defp get_fleet_analysis(_character_id, _use_cache) do
    # Fleet analysis requires multiple characters, skip for individual analysis
    {:ok, nil}
  end

  defp get_home_defense_analysis(_character_id, _use_cache) do
    # Home defense analysis not applicable for individual character
    {:ok, nil}
  end

  defp get_vetting_analysis(character_id, use_cache) do
    if use_cache do
      IntelligenceCache.get_vetting_analysis(character_id)
    else
      WHVettingAnalyzer.analyze_character(character_id)
    end
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
    summary_points =
      []
      |> add_basic_analysis_summary(basic_analysis)
      |> add_vetting_summary(specialized_analysis.vetting)
      |> add_correlation_summary(correlations)

    if Enum.empty?(summary_points) do
      "Standard intelligence profile - no significant concerns detected."
    else
      Enum.join(summary_points, ". ") <> "."
    end
  end

  defp add_basic_analysis_summary(summary_points, nil), do: summary_points

  defp add_basic_analysis_summary(summary_points, basic_analysis) do
    threat_level = assess_threat_level(basic_analysis)
    points = ["Threat Level: #{threat_level}" | summary_points]

    if basic_analysis.dangerous_rating > 7 do
      ["High threat rating detected (#{basic_analysis.dangerous_rating}/10)" | points]
    else
      points
    end
  end

  defp add_vetting_summary(summary_points, nil), do: summary_points

  defp add_vetting_summary(summary_points, vetting) do
    points = ["Vetting Status: #{vetting.recommendation}" | summary_points]

    if vetting.overall_risk_score > 70 do
      ["High vetting risk score (#{vetting.overall_risk_score}/100)" | points]
    else
      points
    end
  end

  defp add_correlation_summary(summary_points, nil), do: summary_points

  defp add_correlation_summary(summary_points, correlations) do
    if correlations.confidence_score > 0.8 do
      ["Strong cross-module correlations detected" | summary_points]
    else
      summary_points
    end
  end

  defp calculate_overall_confidence(basic_analysis, specialized_analysis, correlations) do
    confidence_factors =
      []
      |> add_basic_confidence(basic_analysis)
      |> add_module_confidence(specialized_analysis)
      |> add_correlation_confidence(correlations)

    if Enum.empty?(confidence_factors) do
      # Default confidence
      0.5
    else
      Enum.sum(confidence_factors) / length(confidence_factors)
    end
  end

  defp add_basic_confidence(factors, nil), do: factors
  defp add_basic_confidence(factors, _basic_analysis), do: [0.8 | factors]

  defp add_module_confidence(factors, specialized_analysis) do
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
      [available_modules / 4.0 | factors]
    else
      factors
    end
  end

  defp add_correlation_confidence(factors, nil), do: factors

  defp add_correlation_confidence(factors, correlations),
    do: [correlations.confidence_score | factors]

  defp generate_unified_recommendations(basic_analysis, specialized_analysis, correlations) do
    recommendations =
      []
      |> add_basic_recommendations(basic_analysis)
      |> add_vetting_recommendations(specialized_analysis.vetting)
      |> add_correlation_recommendations(correlations)

    if Enum.empty?(recommendations) do
      ["Standard monitoring and periodic review"]
    else
      recommendations
    end
  end

  defp add_basic_recommendations(recommendations, basic_analysis) do
    if basic_analysis && basic_analysis.dangerous_rating > 8 do
      ["Monitor closely due to high threat rating" | recommendations]
    else
      recommendations
    end
  end

  defp add_vetting_recommendations(recommendations, nil), do: recommendations

  defp add_vetting_recommendations(recommendations, vetting) do
    case vetting.recommendation do
      "reject" ->
        ["Recommend rejection based on vetting analysis" | recommendations]

      "conditional" ->
        ["Consider conditional acceptance with monitoring" | recommendations]

      "more_info" ->
        ["Gather additional information before decision" | recommendations]

      _ ->
        recommendations
    end
  end

  defp add_correlation_recommendations(recommendations, nil), do: recommendations

  defp add_correlation_recommendations(recommendations, correlations) do
    threat_indicators = correlations.correlations.threat_assessment.threat_indicators

    if length(threat_indicators) > 2 do
      ["Multiple threat indicators confirmed across modules" | recommendations]
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

    if Map.get(group_correlations, :alt_likelihood, 0) > 0.7 do
      summary <> " High probability of alt character relationships detected."
    else
      summary
    end
  end

  defp generate_group_recommendations(individual_analyses, group_correlations) do
    # Check for high-risk individuals in group
    high_risk_count =
      individual_analyses
      |> Enum.count(fn {_id, analysis} ->
        basic = analysis.basic_analysis
        basic && basic.dangerous_rating > 7
      end)

    recommendations =
      []
      |> add_high_risk_recommendation(high_risk_count)
      |> add_group_correlation_recommendation(group_correlations)

    if Enum.empty?(recommendations) do
      ["Group shows normal intelligence patterns"]
    else
      recommendations
    end
  end

  defp add_high_risk_recommendation(recommendations, 0), do: recommendations

  defp add_high_risk_recommendation(recommendations, high_risk_count) do
    ["#{high_risk_count} high-risk individuals identified in group" | recommendations]
  end

  defp add_group_correlation_recommendation(recommendations, group_correlations) do
    if Map.get(group_correlations, :alt_likelihood, 0) > 0.8 do
      ["Strong alt character correlations - consider as single entity" | recommendations]
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

  defp get_recent_intelligence_activity(_timeframe) do
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
