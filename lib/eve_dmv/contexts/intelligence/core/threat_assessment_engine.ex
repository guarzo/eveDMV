defmodule EveDmv.Contexts.Intelligence.Core.ThreatAssessmentEngine do
  @moduledoc """
  Unified threat assessment engine that combines multi-dimensional threat scoring
  with practical danger ratings and mitigation strategies.

  Consolidates functionality from:
  - Character Intelligence threat assessment
  - Player Profile risk assessment
  """

  alias EveDmv.Contexts.Intelligence.Core.CharacterAnalyzer
  alias EveDmv.Contexts.Intelligence.Core.CombatThreatEngine
  alias EveDmv.Contexts.Intelligence.Core.GangEffectivenessEngine
  alias EveDmv.Contexts.Intelligence.Core.HistoricalTrendAnalysis
  alias EveDmv.Contexts.Intelligence.Core.ShipMasteryEngine
  alias EveDmv.Contexts.Intelligence.Core.UnpredictabilityEngine
  alias EveDmv.Platform.Cache.Cache
  require Logger

  @threat_aspects [
    :combat_effectiveness,
    :tactical_sophistication,
    :intelligence_gathering,
    :network_influence,
    :operational_security
  ]

  @default_weights %{
    combat_effectiveness: 0.35,
    tactical_sophistication: 0.25,
    intelligence_gathering: 0.15,
    network_influence: 0.15,
    operational_security: 0.10
  }

  @doc """
  Perform comprehensive threat assessment for a character.

  Options:
    - weights: Custom aspect weights
    - include_mitigation: Include mitigation strategies
    - include_trends: Include trend analysis
    - time_range: Time period for analysis
  """
  def assess_threat(character_id, opts \\ []) do
    cache_key = {:threat_assessment, character_id, opts}

    Cache.get_or_compute(:analysis, cache_key, fn ->
      perform_threat_assessment(character_id, opts)
    end)
  end

  @doc """
  Get simplified threat score (0-100).
  """
  def get_threat_score(character_id) do
    case assess_threat(character_id) do
      {:ok, assessment} -> {:ok, assessment.overall_score}
      error -> error
    end
  end

  @doc """
  Calculate danger rating with confidence level.
  """
  def calculate_danger_rating(character_id) do
    with {:ok, assessment} <- assess_threat(character_id),
         {:ok, combat_stats} <- CharacterAnalyzer.get_character_stats(character_id) do
      rating = %{
        level: categorize_threat_level(assessment.overall_score),
        score: assessment.overall_score,
        confidence: calculate_confidence(combat_stats),
        factors: extract_key_factors(assessment),
        recommendation: generate_engagement_recommendation(assessment)
      }

      {:ok, rating}
    end
  end

  @doc """
  Get detailed threat breakdown by aspect.
  """
  def get_threat_breakdown(character_id) do
    case assess_threat(character_id) do
      {:ok, assessment} -> {:ok, assessment.aspect_scores}
      error -> error
    end
  end

  @doc """
  Assess threats for multiple characters (batch operation).
  """
  def assess_batch(character_ids, opts \\ []) do
    character_ids
    |> Task.async_stream(
      fn char_id ->
        {char_id, assess_threat(char_id, opts)}
      end,
      max_concurrency: 10,
      timeout: 30_000
    )
    |> Enum.reduce({[], []}, fn
      {:ok, {char_id, {:ok, assessment}}}, {successes, failures} ->
        {[{char_id, assessment} | successes], failures}

      {:ok, {char_id, {:error, reason}}}, {successes, failures} ->
        {successes, [{char_id, reason} | failures]}

      {:exit, reason}, {successes, failures} ->
        Logger.error("Batch assessment task failed: #{inspect(reason)}")
        {successes, failures}
    end)
    |> then(fn {successes, failures} ->
      {:ok,
       %{
         assessments: successes |> Enum.reverse() |> Map.new(),
         failures: Enum.reverse(failures)
       }}
    end)
  end

  # Private Functions

  defp perform_threat_assessment(character_id, opts) do
    weights = Keyword.get(opts, :weights, @default_weights)

    with {:ok, aspect_scores} <- calculate_aspect_scores(character_id, opts),
         overall_score <- calculate_weighted_score(aspect_scores, weights),
         {:ok, analysis} <- perform_additional_analysis(character_id, opts) do
      initial_assessment = %{
        character_id: character_id,
        overall_score: overall_score,
        threat_level: categorize_threat_level(overall_score),
        aspect_scores: aspect_scores,
        weights_used: weights,
        analysis: analysis,
        assessed_at: DateTime.utc_now()
      }

      assessment_with_mitigation =
        if Keyword.get(opts, :include_mitigation, false) do
          Map.put(
            initial_assessment,
            :mitigation_strategies,
            generate_mitigation_strategies(initial_assessment)
          )
        else
          initial_assessment
        end

      final_assessment =
        if Keyword.get(opts, :include_trends, false) do
          Map.put(
            assessment_with_mitigation,
            :trends,
            analyze_threat_trends(character_id, overall_score)
          )
        else
          assessment_with_mitigation
        end

      {:ok, final_assessment}
    end
  end

  defp calculate_aspect_scores(character_id, opts) do
    # Run all aspect calculations in parallel
    tasks = [
      Task.async(fn -> calculate_combat_effectiveness(character_id, opts) end),
      Task.async(fn -> calculate_tactical_sophistication(character_id, opts) end),
      Task.async(fn -> calculate_intelligence_gathering(character_id, opts) end),
      Task.async(fn -> calculate_network_influence(character_id, opts) end),
      Task.async(fn -> calculate_operational_security(character_id, opts) end)
    ]

    results = Task.await_many(tasks, 10_000)

    # Check if all calculations succeeded
    if Enum.all?(results, &match?({:ok, _}, &1)) do
      scores =
        Enum.zip(@threat_aspects, results)
        |> Enum.map(fn {aspect, {:ok, score}} -> {aspect, score} end)
        |> Map.new()

      {:ok, scores}
    else
      {:error, :aspect_calculation_failed}
    end
  end

  defp calculate_combat_effectiveness(character_id, _opts) do
    case CombatThreatEngine.analyze(character_id) do
      {:ok, analysis} ->
        score = analysis.threat_score * 100
        {:ok, min(score, 100)}

      _ ->
        {:ok, 0}
    end
  end

  defp calculate_tactical_sophistication(character_id, _opts) do
    with {:ok, ship_mastery} <- ShipMasteryEngine.analyze(character_id),
         {:ok, gang_effectiveness} <- GangEffectivenessEngine.analyze(character_id) do
      # Combine ship mastery and gang effectiveness
      score =
        (ship_mastery.mastery_score * 0.6 + gang_effectiveness.effectiveness_score * 0.4) * 100

      {:ok, min(score, 100)}
    else
      _ -> {:ok, 0}
    end
  end

  defp calculate_intelligence_gathering(_character_id, _opts) do
    # Analyze killmail patterns for intelligence activity
    # For now, return a moderate score
    {:ok, 50}
  end

  defp calculate_network_influence(character_id, _opts) do
    # Analyze corporation/alliance affiliations and connections
    # For now, return based on gang participation
    case GangEffectivenessEngine.analyze(character_id) do
      {:ok, analysis} ->
        score = analysis.coordination_rating * 20
        {:ok, min(score, 100)}

      _ ->
        {:ok, 0}
    end
  end

  defp calculate_operational_security(character_id, _opts) do
    # Analyze unpredictability and operational patterns
    case UnpredictabilityEngine.analyze(character_id) do
      {:ok, analysis} ->
        score = analysis.unpredictability_score * 100
        {:ok, min(score, 100)}

      {:error, _reason} ->
        # Log error but return default score
        {:ok, 0}
    end
  end

  defp calculate_weighted_score(aspect_scores, weights) do
    @threat_aspects
    |> Enum.reduce(0, fn aspect, acc ->
      score = Map.get(aspect_scores, aspect, 0)
      weight = Map.get(weights, aspect, 0)
      acc + score * weight
    end)
    |> Float.round(2)
  end

  defp categorize_threat_level(score) do
    cond do
      score >= 80 -> :critical
      score >= 60 -> :high
      score >= 40 -> :moderate
      score >= 20 -> :low
      true -> :minimal
    end
  end

  defp perform_additional_analysis(character_id, _opts) do
    # Gather additional insights
    analysis = %{
      primary_threats: identify_primary_threats(character_id),
      engagement_history: analyze_engagement_history(character_id),
      capability_assessment: assess_capabilities(character_id)
    }

    {:ok, analysis}
  end

  defp identify_primary_threats(character_id) do
    # Identify what makes this character threatening
    with {:ok, combat} <- CombatThreatEngine.analyze(character_id),
         {:ok, ship} <- ShipMasteryEngine.analyze(character_id) do
      threats = []

      threats =
        if combat.solo_effectiveness > 0.7 do
          ["Elite solo pilot" | threats]
        else
          threats
        end

      threats =
        if ship.capital_proficiency > 0.5 do
          ["Capital ship pilot" | threats]
        else
          threats
        end

      threats =
        if combat.kill_death_ratio > 3.0 do
          ["High K/D ratio" | threats]
        else
          threats
        end

      threats
    else
      _ -> []
    end
  end

  defp analyze_engagement_history(_character_id) do
    # Analyze recent engagements
    %{
      recent_kills: 0,
      recent_losses: 0,
      preferred_targets: [],
      avoided_targets: []
    }
  end

  defp assess_capabilities(_character_id) do
    %{
      can_fly_capitals: false,
      uses_links: false,
      flies_logi: false,
      hot_dropper: false
    }
  end

  defp calculate_confidence(combat_stats) do
    # Calculate confidence based on data quality
    total_events = combat_stats.total_kills + combat_stats.total_losses

    cond do
      total_events >= 100 -> :high
      total_events >= 50 -> :medium
      total_events >= 20 -> :low
      true -> :very_low
    end
  end

  defp extract_key_factors(assessment) do
    # Extract the most significant factors
    assessment.aspect_scores
    |> Enum.sort_by(fn {_aspect, score} -> score end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {aspect, score} ->
      %{
        aspect: aspect,
        score: score,
        description: describe_aspect(aspect, score)
      }
    end)
  end

  defp describe_aspect(aspect, score) do
    level =
      cond do
        score >= 80 -> "Extremely high"
        score >= 60 -> "High"
        score >= 40 -> "Moderate"
        score >= 20 -> "Low"
        true -> "Minimal"
      end

    "#{level} #{humanize_aspect(aspect)}"
  end

  defp humanize_aspect(aspect) do
    aspect
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp generate_engagement_recommendation(assessment) do
    case assessment.threat_level do
      :critical -> "Avoid engagement unless you have significant numerical or tactical advantage"
      :high -> "Engage only with proper support and intel"
      :moderate -> "Approach with caution, assess situation carefully"
      :low -> "Standard engagement protocols apply"
      :minimal -> "Low-risk target"
    end
  end

  defp generate_mitigation_strategies(assessment) do
    initial_strategies = []

    # Add strategies based on high-scoring aspects
    strategies_with_combat =
      if assessment.aspect_scores.combat_effectiveness > 70 do
        ["Avoid solo engagements" | initial_strategies]
      else
        initial_strategies
      end

    strategies_with_tactical =
      if assessment.aspect_scores.tactical_sophistication > 70 do
        ["Expect advanced tactics and baiting" | strategies_with_combat]
      else
        strategies_with_combat
      end

    strategies_with_opsec =
      if assessment.aspect_scores.operational_security > 70 do
        ["Difficult to track - use scouts" | strategies_with_tactical]
      else
        strategies_with_tactical
      end

    final_strategies =
      if assessment.aspect_scores.network_influence > 70 do
        ["Expect backup - check local for allies" | strategies_with_opsec]
      else
        strategies_with_opsec
      end

    final_strategies
  end

  defp analyze_threat_trends(character_id, current_score) do
    {:ok, trends} = HistoricalTrendAnalysis.analyze_threat_trends(character_id, current_score)
    trends
  end
end
