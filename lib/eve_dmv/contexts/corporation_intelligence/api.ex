defmodule EveDmv.Contexts.CorporationIntelligence.Api do
  @moduledoc """
  Public API for corporation intelligence analysis.
  Provides comprehensive corporation analysis capabilities.
  """

  alias EveDmv.Contexts.CorporationIntelligence.Domain.Analyzers.OperationalPatternAnalyzer
  alias EveDmv.Contexts.CorporationIntelligence.Domain.Analyzers.PerformanceAnalyzer
  alias EveDmv.Contexts.CorporationIntelligence.Domain.CombatDoctrineAnalyzer
  alias EveDmv.Contexts.CorporationIntelligence.Domain.CorporationComparator
  alias EveDmv.Contexts.CorporationIntelligence.Domain.CorporationScorer
  alias EveDmv.Contexts.CorporationIntelligence.Domain.HealthAssessor
  alias EveDmv.Intelligence.Analyzers.CorporationAnalyzer
  require Logger

  @doc """
  Performs comprehensive corporation analysis.

  Returns detailed analysis including:
  - Member correlations and synergy
  - Activity patterns and timezones
  - Risk distribution
  - Coordination metrics
  """
  @spec analyze_corporation(integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_corporation(corporation_id, _opts \\ []) do
    CorporationAnalyzer.analyze_corporation(corporation_id)
  end

  @doc """
  Analyzes corporation combat doctrines and tactics.

  Returns:
  - Identified doctrine patterns
  - Ship composition preferences
  - Engagement tactics
  - Doctrine effectiveness metrics
  """
  @spec analyze_combat_doctrines(integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_combat_doctrines(corporation_id, opts \\ []) do
    days = Keyword.get(opts, :days, 90)

    # Pass options as keyword list to the analyzer
    analyzer_opts = [
      analysis_window_days: days,
      include_member_analysis: Keyword.get(opts, :include_members, true),
      doctrine_evolution_tracking: Keyword.get(opts, :track_evolution, true)
    ]

    case CombatDoctrineAnalyzer.analyze_combat_doctrines(corporation_id, analyzer_opts) do
      {:ok, analysis} -> {:ok, analysis}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Analyzes corporation operational patterns.

  Returns:
  - Temporal patterns (hourly, daily, weekly)
  - Geographic patterns and hunting grounds
  - Target selection preferences
  - Escalation patterns
  - Predictive models
  """
  @spec analyze_operational_patterns(integer(), keyword()) :: map() | {:error, term()}
  def analyze_operational_patterns(corporation_id, opts \\ []) do
    OperationalPatternAnalyzer.analyze_patterns(corporation_id, opts)
  end

  @doc """
  Analyzes corporation performance metrics.

  Returns:
  - Efficiency metrics (K/D ratio, ISK efficiency)
  - Growth indicators
  - Performance trends
  - Operational effectiveness
  - Comparative performance
  """
  @spec analyze_performance(integer(), keyword()) :: map() | {:error, term()}
  def analyze_performance(corporation_id, opts \\ []) do
    PerformanceAnalyzer.analyze_performance(corporation_id, opts)
  end

  @doc """
  Gets comprehensive corporation intelligence report.

  Combines all analysis modules for a complete picture.
  """
  @spec get_intelligence_report(integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_intelligence_report(corporation_id, opts \\ []) do
    with {:ok, base_analysis} <- analyze_corporation(corporation_id, opts),
         {:ok, doctrines} <- analyze_combat_doctrines(corporation_id, opts),
         patterns <- analyze_operational_patterns(corporation_id, opts),
         performance <- analyze_performance(corporation_id, opts) do
      report = %{
        corporation_id: corporation_id,
        analysis_timestamp: DateTime.utc_now(),
        base_intelligence: base_analysis,
        combat_doctrines: doctrines,
        operational_patterns: patterns,
        performance_metrics: performance,
        executive_summary:
          generate_executive_summary(base_analysis, doctrines, patterns, performance)
      }

      {:ok, report}
    else
      {:error, reason} ->
        Logger.error(
          "Failed to generate intelligence report for corporation #{corporation_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Analyzes member correlations within a corporation.
  """
  @spec analyze_member_correlations(list()) :: map()
  def analyze_member_correlations(members) do
    CorporationAnalyzer.analyze_member_correlations(members)
  end

  @doc """
  Analyzes corporation activity patterns.
  """
  @spec analyze_activity_patterns(list()) :: map()
  def analyze_activity_patterns(members) do
    CorporationAnalyzer.analyze_activity_patterns(members)
  end

  @doc """
  Analyzes corporation risk distribution.
  """
  @spec analyze_risk_distribution(list()) :: map()
  def analyze_risk_distribution(members) do
    CorporationAnalyzer.analyze_risk_distribution(members)
  end

  @doc """
  Analyzes member coordination patterns.
  """
  @spec analyze_coordination(list()) :: map()
  def analyze_coordination(members) do
    CorporationAnalyzer.analyze_coordination(members)
  end

  @doc """
  Compares multiple corporations.

  Returns comparative analysis including:
  - Performance rankings
  - Strength comparisons
  - Tactical differences
  - Competitive positioning
  """
  @spec compare_corporations([integer()], keyword()) :: {:ok, map()} | {:error, term()}
  def compare_corporations(corporation_ids, opts \\ []) when is_list(corporation_ids) do
    if length(corporation_ids) < 2 do
      {:error, :insufficient_corporations}
    else
      # Gather data for each corporation
      corporations_data =
        corporation_ids
        |> Enum.map(fn corp_id ->
          with {:ok, base} <- analyze_corporation(corp_id, opts),
               performance <- analyze_performance(corp_id, opts) do
            {corp_id, %{base_analysis: base, performance: performance}}
          else
            _ -> {corp_id, %{base_analysis: nil, performance: nil}}
          end
        end)
        |> Map.new()

      comparison = %{
        corporations: corporation_ids,
        comparison_date: DateTime.utc_now(),
        member_comparison: CorporationComparator.compare_member_counts(corporations_data),
        activity_comparison: CorporationComparator.compare_activity_levels(corporations_data),
        performance_comparison:
          CorporationComparator.compare_performance_metrics(corporations_data),
        timezone_comparison: CorporationComparator.compare_timezone_coverage(corporations_data),
        operational_comparison:
          CorporationComparator.compare_operational_focus(corporations_data),
        rankings: CorporationScorer.generate_rankings(corporations_data)
      }

      {:ok, comparison}
    end
  end

  @doc """
  Gets corporation health assessment.

  Evaluates overall corporation health based on multiple factors.
  """
  @spec assess_corporation_health(integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def assess_corporation_health(corporation_id, opts \\ []) do
    with {:ok, base} <- analyze_corporation(corporation_id, opts),
         performance <- analyze_performance(corporation_id, opts),
         patterns <- analyze_operational_patterns(corporation_id, opts) do
      health_score = HealthAssessor.calculate_health_score(base, performance, patterns)

      assessment = %{
        corporation_id: corporation_id,
        health_score: health_score,
        health_rating: HealthAssessor.categorize_health_score(health_score),
        strengths: HealthAssessor.identify_strengths(base, performance, patterns),
        weaknesses: HealthAssessor.identify_weaknesses(base, performance, patterns),
        recommendations: HealthAssessor.generate_recommendations(base, performance, patterns),
        risk_factors: HealthAssessor.identify_risk_factors(base, performance, patterns)
      }

      {:ok, assessment}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helper functions

  defp generate_executive_summary(base, doctrines, patterns, performance) do
    %{
      primary_timezone: base[:activity_patterns][:primary_timezones][:primary_tz] || "Unknown",
      member_count: base[:member_count] || 0,
      coordination_level: base[:coordination_analysis][:coordination_score] || 0,
      primary_doctrine:
        doctrines[:identified_doctrines] |> List.first() || %{} |> Map.get(:name, "Unknown"),
      operational_tempo: patterns[:temporal_patterns][:operational_tempo] || :unknown,
      performance_rating: performance[:efficiency_metrics][:efficiency_rating] || :unknown,
      growth_trajectory: performance[:growth_indicators][:growth_trajectory] || :unknown
    }
  end
end
