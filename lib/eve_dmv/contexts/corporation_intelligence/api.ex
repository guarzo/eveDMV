defmodule EveDmv.Contexts.CorporationIntelligence.Api do
  @moduledoc """
  Public API for corporation intelligence analysis.
  Provides comprehensive corporation analysis capabilities.
  """

  alias EveDmv.Contexts.CorporationIntelligence.Domain.Analyzers.OperationalPatternAnalyzer
  alias EveDmv.Contexts.CorporationIntelligence.Domain.Analyzers.PerformanceAnalyzer
  alias EveDmv.Contexts.CorporationIntelligence.Domain.CombatDoctrineAnalyzer
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
        member_comparison: compare_member_counts(corporations_data),
        activity_comparison: compare_activity_levels(corporations_data),
        performance_comparison: compare_performance_metrics(corporations_data),
        timezone_comparison: compare_timezone_coverage(corporations_data),
        operational_comparison: compare_operational_focus(corporations_data),
        rankings: generate_rankings(corporations_data)
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
      health_score = calculate_health_score(base, performance, patterns)

      assessment = %{
        corporation_id: corporation_id,
        health_score: health_score,
        health_rating: categorize_health_score(health_score),
        strengths: identify_strengths(base, performance, patterns),
        weaknesses: identify_weaknesses(base, performance, patterns),
        recommendations: generate_recommendations(base, performance, patterns),
        risk_factors: identify_risk_factors(base, performance, patterns)
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

  defp compare_member_counts(corporations_data) do
    corporations_data
    |> Enum.map(fn {corp_id, data} ->
      member_count = data.base_analysis[:member_count] || 0
      {corp_id, member_count}
    end)
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
  end

  defp compare_activity_levels(corporations_data) do
    corporations_data
    |> Enum.map(fn {corp_id, data} ->
      activity = data.performance[:efficiency_metrics][:total_kills] || 0
      {corp_id, activity}
    end)
    |> Enum.sort_by(fn {_, activity} -> activity end, :desc)
  end

  defp compare_performance_metrics(corporations_data) do
    corporations_data
    |> Enum.map(fn {corp_id, data} ->
      metrics = data.performance[:efficiency_metrics] || %{}

      {corp_id,
       %{
         kd_ratio: metrics[:kill_death_ratio] || 0,
         isk_efficiency: metrics[:isk_efficiency] || 0,
         rating: metrics[:efficiency_rating] || :unknown
       }}
    end)
    |> Enum.sort_by(fn {_, metrics} -> metrics.isk_efficiency end, :desc)
  end

  defp compare_timezone_coverage(corporations_data) do
    corporations_data
    |> Enum.map(fn {corp_id, data} ->
      timezone =
        data.base_analysis[:activity_patterns][:primary_timezones][:primary_tz] || "Unknown"

      coverage =
        data.base_analysis[:activity_patterns][:primary_timezones][:coverage] || "Unknown"

      {corp_id, %{primary_tz: timezone, coverage: coverage}}
    end)
  end

  defp compare_operational_focus(corporations_data) do
    corporations_data
    |> Enum.map(fn {corp_id, data} ->
      focus = data.base_analysis[:activity_patterns][:operational_focus][:focus] || "Unknown"
      {corp_id, focus}
    end)
  end

  defp generate_rankings(corporations_data) do
    # Create composite rankings
    corporations_data
    |> Enum.map(fn {corp_id, data} ->
      score = calculate_composite_score(data)
      {corp_id, score}
    end)
    |> Enum.sort_by(fn {_, score} -> score end, :desc)
    |> Enum.with_index(1)
    |> Enum.map(fn {{corp_id, score}, rank} ->
      %{rank: rank, corporation_id: corp_id, score: Float.round(score, 1)}
    end)
  end

  defp calculate_composite_score(data) do
    base_score =
      if data.base_analysis do
        coordination = data.base_analysis[:coordination_analysis][:coordination_score] || 0
        members = min(data.base_analysis[:member_count] || 0, 100)
        (coordination + members) / 2
      else
        0
      end

    performance_score =
      if data.performance do
        efficiency = data.performance[:efficiency_metrics][:isk_efficiency] || 0
        kd_ratio = min((data.performance[:efficiency_metrics][:kill_death_ratio] || 0) * 20, 100)
        (efficiency + kd_ratio) / 2
      else
        0
      end

    base_score * 0.4 + performance_score * 0.6
  end

  defp calculate_health_score(base, performance, _patterns) do
    # Calculate overall health score (0-100)
    member_score = min(base[:member_count] || 0, 100)
    coordination_score = base[:coordination_analysis][:coordination_score] || 0
    efficiency_score = performance[:efficiency_metrics][:isk_efficiency] || 0

    growth_score =
      case performance[:growth_indicators][:growth_trajectory] do
        :rapid_growth -> 100
        :steady_growth -> 80
        :slow_growth -> 60
        :stable -> 50
        :declining -> 30
        :rapid_decline -> 10
        _ -> 40
      end

    consistency_score = performance[:performance_trends][:consistency_score] || 0

    # Weighted average
    total =
      member_score * 0.15 +
        coordination_score * 0.25 +
        efficiency_score * 0.25 +
        growth_score * 0.20 +
        consistency_score * 0.15

    Float.round(total, 1)
  end

  defp categorize_health_score(score) do
    cond do
      score >= 80 -> :excellent
      score >= 60 -> :good
      score >= 40 -> :fair
      score >= 20 -> :poor
      true -> :critical
    end
  end

  defp identify_strengths(base, performance, patterns) do
    []
    |> add_if(
      base[:coordination_analysis][:coordination_score] > 70,
      "Excellent member coordination"
    )
    |> add_if(performance[:efficiency_metrics][:isk_efficiency] > 60, "High ISK efficiency")
    |> add_growth_strength(performance[:growth_indicators][:growth_trajectory])
    |> add_if(
      patterns[:geographic_patterns][:operational_range][:classification] in [
        :nomadic,
        :wide_range
      ],
      "Wide operational range"
    )
    |> finalize_strengths()
  end

  defp add_if(list, condition, item) do
    if condition, do: [item | list], else: list
  end

  defp add_growth_strength(list, trajectory) when trajectory in [:rapid_growth, :steady_growth] do
    ["Positive growth trajectory" | list]
  end

  defp add_growth_strength(list, _), do: list

  defp finalize_strengths([]), do: ["Established presence"]
  defp finalize_strengths(list), do: Enum.reverse(list)

  defp identify_weaknesses(base, performance, patterns) do
    []
    |> add_if(base[:member_count] < 10, "Low member count")
    |> add_if(performance[:efficiency_metrics][:isk_efficiency] < 40, "Poor ISK efficiency")
    |> add_if(
      performance[:performance_trends][:consistency_score] < 30,
      "Inconsistent performance"
    )
    |> add_if(
      patterns[:temporal_patterns][:operational_tempo] in [:sporadic, :minimal],
      "Low operational tempo"
    )
    |> finalize_weaknesses()
  end

  defp finalize_weaknesses([]), do: ["No significant weaknesses identified"]
  defp finalize_weaknesses(list), do: Enum.reverse(list)

  defp generate_recommendations(base, performance, patterns) do
    []
    |> add_if(base[:member_count] < 20, "Focus on recruitment to increase member base")
    |> add_if(
      performance[:efficiency_metrics][:kill_death_ratio] < 1.0,
      "Improve combat tactics and target selection"
    )
    |> add_timezone_recommendation(base[:activity_patterns][:primary_timezones][:coverage])
    |> add_if(
      patterns[:geographic_patterns][:operational_range][:classification] in [:static, :local],
      "Expand operational range to new systems"
    )
    |> finalize_recommendations()
  end

  defp add_timezone_recommendation(list, coverage) when coverage in [nil, ""], do: list

  defp add_timezone_recommendation(list, coverage) do
    if String.contains?(coverage, ["Limited", "Minimal"]) do
      ["Expand timezone coverage for better operational flexibility" | list]
    else
      list
    end
  end

  defp finalize_recommendations([]), do: ["Maintain current operational excellence"]
  defp finalize_recommendations(list), do: Enum.reverse(list)

  defp identify_risk_factors(base, performance, patterns) do
    []
    |> add_growth_risk(performance[:growth_indicators][:growth_trajectory])
    |> add_if(
      performance[:growth_indicators][:member_retention_rate] < 50,
      "Low member retention rate"
    )
    |> add_concentration_risk(patterns[:geographic_patterns][:home_systems])
    |> add_if(base[:coordination_analysis][:coordination_score] < 30, "Poor member coordination")
    |> finalize_risks()
  end

  defp add_growth_risk(list, trajectory) when trajectory in [:declining, :rapid_decline] do
    ["Declining activity levels" | list]
  end

  defp add_growth_risk(list, _), do: list

  defp add_concentration_risk(list, nil), do: list
  defp add_concentration_risk(list, []), do: list

  defp add_concentration_risk(list, [first | _]) do
    if first[:percentage] > 50 do
      ["Over-concentrated in few systems" | list]
    else
      list
    end
  end

  defp finalize_risks([]), do: ["No significant risks identified"]
  defp finalize_risks(list), do: Enum.reverse(list)
end
