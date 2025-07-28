defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.ThreatScoringCoordinator do
  @moduledoc """
  Main orchestrator for threat scoring analysis.

  Coordinates threat scoring operations through specialized sub-modules:
  - **Data Fetchers**: Combat data collection and processing
  - **Calculators**: Score calculation and weighting algorithms
  - **Analyzers**: Trend analysis and pattern detection
  - **Generators**: Insight and comparison generation
  - **Cache Managers**: Performance optimization through caching

  ## Architecture

  The coordinator delegates to specialized sub-modules:
  - `CombatDataFetcher` - Handles data collection from killmail sources
  - `ThreatScoreCalculator` - Performs score calculations and weighting
  - `TrendAnalyzer` - Analyzes threat trends over time
  - `ComparisonEngine` - Handles multi-character comparisons
  - `InsightGenerator` - Generates tactical insights from scores

  ## Usage

      {:ok, threat_score} = ThreatScoringCoordinator.calculate_threat_score(character_id)
      {:ok, comparison} = ThreatScoringCoordinator.compare_threat_levels([id1, id2, id3])
      {:ok, trends} = ThreatScoringCoordinator.analyze_threat_trends(character_id)
  """

  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.ThreatScoringCoordinator.Analyzers.TrendAnalyzer
  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.ThreatScoringCoordinator.Calculators.
          ThreatScoreCalculator,
        as: Calculator

  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.ThreatScoringCoordinator.DataFetchers.
          CombatDataFetcher,
        as: DataFetcher
  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.ThreatScoringCoordinator.Generators.ComparisonEngine
  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.ThreatScoringCoordinator.Generators.InsightGenerator

  alias EveDmv.Intelligence.Cache.IntelligenceCache

  require Logger

  # Cache TTL configuration
  @cache_ttl_threat_score :timer.hours(6)
  @cache_ttl_trend_analysis :timer.hours(12)
  @cache_ttl_comparison :timer.hours(4)

  @doc """
  Calculates comprehensive threat score for a character with caching.

  ## Parameters
  - character_id: EVE character ID to analyze
  - options: Analysis options (analysis_window_days, cache_ttl, etc.)

  ## Returns
  - {:ok, threat_assessment} - Complete threat analysis
  - {:error, reason} - Error details
  """
  def calculate_threat_score(character_id, options \\ []) do
    Logger.debug("Coordinating threat score calculation for character #{character_id}")
    ttl = Keyword.get(options, :cache_ttl, @cache_ttl_threat_score)

    case IntelligenceCache.get_threat_score(character_id, options, ttl) do
      {:ok, result} -> {:ok, result}
      {:error, _} = error -> error
    end
  end

  @doc """
  Calculates comprehensive threat score for a character without caching.

  This is the internal implementation called by the cache system.
  """
  def calculate_threat_score_uncached(character_id, options \\ []) do
    Logger.info("Calculating threat score for character #{character_id}")

    with {:ok, combat_data} <-
           DataFetcher.fetch_character_combat_data(character_id, options),
         {:ok, threat_assessment} <-
           Calculator.calculate_comprehensive_score(combat_data, options),
         {:ok, insights} <- InsightGenerator.generate_threat_insights(threat_assessment) do
      {:ok, Map.put(threat_assessment, :insights, insights)}
    else
      {:error, reason} ->
        Logger.warning(
          "Failed to calculate threat score for character #{character_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Compare threat levels between multiple characters with caching.

  ## Parameters
  - character_ids: List of character IDs to compare
  - options: Analysis options

  ## Returns
  - {:ok, comparison_results} - Comparative analysis
  - {:error, reason} - Error details
  """
  def compare_threat_levels(character_ids, options \\ []) when is_list(character_ids) do
    Logger.debug("Coordinating threat comparison for #{length(character_ids)} characters")
    ttl = Keyword.get(options, :cache_ttl, @cache_ttl_comparison)

    case IntelligenceCache.get_threat_comparison(character_ids, options, ttl) do
      {:ok, result} -> {:ok, result}
      {:error, _} = error -> error
    end
  end

  @doc """
  Compare threat levels between multiple characters without caching.

  This is the internal implementation called by the cache system.
  """
  def compare_threat_levels_uncached(character_ids, options \\ []) when is_list(character_ids) do
    Logger.info("Comparing threat levels for #{length(character_ids)} characters")

    ComparisonEngine.compare_multiple_threats(character_ids, options)
  end

  @doc """
  Analyze threat trends for a character over time with caching.

  ## Parameters
  - character_id: Character to analyze
  - options: Analysis options

  ## Returns
  - {:ok, trend_analysis} - Trend analysis results
  - {:error, reason} - Error details
  """
  def analyze_threat_trends(character_id, options \\ []) do
    Logger.debug("Coordinating threat trend analysis for character #{character_id}")
    ttl = Keyword.get(options, :cache_ttl, @cache_ttl_trend_analysis)

    case IntelligenceCache.get_threat_trends(character_id, options, ttl) do
      {:ok, result} -> {:ok, result}
      {:error, _} = error -> error
    end
  end

  @doc """
  Analyze threat trends for a character over time without caching.

  This is the internal implementation called by the cache system.
  """
  def analyze_threat_trends_uncached(character_id, options \\ []) do
    Logger.info("Analyzing threat trends for character #{character_id}")

    TrendAnalyzer.analyze_character_threat_trends(character_id, options)
  end
end
