defmodule EveDmv.Contexts.Intelligence.Services.ComparisonService do
  @moduledoc """
  Service for comparing characters across various metrics and finding similar pilots.
  """

  alias EveDmv.Cache
  alias EveDmv.Contexts.Intelligence.Core.CharacterAnalyzer
  alias EveDmv.Contexts.Intelligence.Core.PerformanceAnalyzer
  alias EveDmv.Contexts.Intelligence.Core.ThreatAssessmentEngine

  require Logger

  @cache_ttl :timer.minutes(30)

  @doc """
  Compare multiple characters across specified aspects.

  Aspects can be:
  - :all - Compare all available metrics
  - :threat - Threat assessment comparison
  - :combat - Combat performance comparison
  - :ships - Ship preferences comparison
  - :behavior - Behavioral patterns comparison
  - [:threat, :combat] - Specific aspects list
  """
  def compare_characters(character_ids, aspects \\ :all) do
    cache_key = {:character_comparison, Enum.sort(character_ids), aspects}

    Cache.get_or_compute(
      :analysis,
      cache_key,
      fn ->
        perform_character_comparison(character_ids, aspects)
      end,
      ttl: @cache_ttl
    )
  end

  @doc """
  Find characters similar to the given character.

  Options:
    - similarity_threshold: Minimum similarity score (0.0-1.0, default: 0.7)
    - max_results: Maximum number of similar characters to return (default: 10)
    - aspects: Which aspects to consider for similarity (default: :all)
    - exclude_corp: Exclude corporation members (default: false)
    - exclude_alliance: Exclude alliance members (default: false)
  """
  def find_similar_characters(character_id, opts \\ []) do
    cache_key = {:similar_characters, character_id, opts}

    Cache.get_or_compute(
      :analysis,
      cache_key,
      fn ->
        perform_similarity_search(character_id, opts)
      end,
      ttl: @cache_ttl
    )
  end

  @doc """
  Rank characters by a specific metric.

  Supported metrics:
  - :threat_score
  - :kill_death_ratio
  - :isk_efficiency
  - :activity_score
  - :danger_rating
  - :versatility
  """
  def rank_characters(character_ids, metric) do
    cache_key = {:character_ranking, Enum.sort(character_ids), metric}

    Cache.get_or_compute(
      :analysis,
      cache_key,
      fn ->
        perform_character_ranking(character_ids, metric)
      end,
      ttl: @cache_ttl
    )
  end

  # Private Functions

  defp perform_character_comparison(character_ids, aspects) do
    # Gather data for all characters
    character_data =
      character_ids
      |> Task.async_stream(
        fn char_id ->
          {char_id, gather_comparison_data(char_id, aspects)}
        end,
        max_concurrency: 10,
        timeout: 30_000
      )
      |> Enum.reduce(%{}, fn
        {:ok, {char_id, {:ok, data}}}, acc ->
          Map.put(acc, char_id, data)

        {:ok, {char_id, {:error, reason}}}, acc ->
          Logger.warning("Failed to gather data for character #{char_id}: #{inspect(reason)}")
          acc

        {:exit, reason}, acc ->
          Logger.error("Comparison task failed: #{inspect(reason)}")
          acc
      end)

    if map_size(character_data) < 2 do
      {:error, :insufficient_data}
    else
      comparison = %{
        characters: character_data,
        summary: generate_comparison_summary(character_data, aspects),
        rankings: generate_aspect_rankings(character_data, aspects),
        insights: generate_comparison_insights(character_data, aspects),
        compared_at: DateTime.utc_now()
      }

      {:ok, comparison}
    end
  end

  defp gather_comparison_data(character_id, aspects) do
    data = %{character_id: character_id}

    with {:ok, data} <- maybe_add_threat_data(data, character_id, aspects),
         {:ok, data} <- maybe_add_combat_data(data, character_id, aspects),
         {:ok, data} <- maybe_add_performance_data(data, character_id, aspects),
         {:ok, data} <- maybe_add_ship_data(data, character_id, aspects),
         {:ok, data} <- maybe_add_behavior_data(data, character_id, aspects) do
      {:ok, data}
    end
  end

  defp maybe_add_threat_data(data, character_id, aspects) do
    if should_include_aspect?(:threat, aspects) do
      case ThreatAssessmentEngine.assess_threat(character_id) do
        {:ok, threat} -> {:ok, Map.put(data, :threat, threat)}
        error -> error
      end
    else
      {:ok, data}
    end
  end

  defp maybe_add_combat_data(data, character_id, aspects) do
    if should_include_aspect?(:combat, aspects) do
      case CharacterAnalyzer.analyze_character(character_id, include_combat_stats: true) do
        {:ok, analysis} -> {:ok, Map.put(data, :combat, analysis.data.combat_stats)}
        error -> error
      end
    else
      {:ok, data}
    end
  end

  defp maybe_add_performance_data(data, character_id, aspects) do
    if should_include_aspect?(:performance, aspects) do
      case PerformanceAnalyzer.analyze_performance(character_id) do
        {:ok, performance} -> {:ok, Map.put(data, :performance, performance)}
        error -> error
      end
    else
      {:ok, data}
    end
  end

  defp maybe_add_ship_data(data, character_id, aspects) do
    if should_include_aspect?(:ships, aspects) do
      case CharacterAnalyzer.analyze_character(character_id, include_ship_prefs: true) do
        {:ok, analysis} -> {:ok, Map.put(data, :ships, analysis.data.ship_preferences)}
        error -> error
      end
    else
      {:ok, data}
    end
  end

  defp maybe_add_behavior_data(data, character_id, aspects) do
    if should_include_aspect?(:behavior, aspects) do
      case CharacterAnalyzer.analyze_character(character_id, include_behavior: true) do
        {:ok, analysis} -> {:ok, Map.put(data, :behavior, analysis.data.behavioral_patterns)}
        error -> error
      end
    else
      {:ok, data}
    end
  end

  defp should_include_aspect?(_aspect, :all), do: true
  defp should_include_aspect?(aspect, aspects) when is_list(aspects), do: aspect in aspects
  defp should_include_aspect?(aspect, single_aspect), do: aspect == single_aspect

  defp generate_comparison_summary(character_data, aspects) do
    char_count = map_size(character_data)

    initial_summary = %{
      character_count: char_count,
      aspects_compared: normalize_aspects(aspects)
    }

    # Add aspect-specific summaries
    final_summary =
      if Map.has_key?(List.first(Map.values(character_data)), :threat) do
        threat_scores =
          character_data
          |> Map.values()
          |> Enum.map(& &1.threat.overall_score)

        Map.put(initial_summary, :threat_summary, %{
          min: Enum.min(threat_scores),
          max: Enum.max(threat_scores),
          avg: Float.round(Enum.sum(threat_scores) / length(threat_scores), 2)
        })
      else
        initial_summary
      end

    final_summary
  end

  defp normalize_aspects(:all), do: [:threat, :combat, :performance, :ships, :behavior]
  defp normalize_aspects(aspects) when is_list(aspects), do: aspects
  defp normalize_aspects(aspect), do: [aspect]

  defp generate_aspect_rankings(character_data, aspects) do
    initial_rankings = %{}

    # Threat rankings
    rankings_with_threat =
      if should_include_aspect?(:threat, aspects) do
        threat_ranking =
          character_data
          |> Enum.filter(fn {_, data} -> Map.has_key?(data, :threat) end)
          |> Enum.sort_by(fn {_, data} -> data.threat.overall_score end, :desc)
          |> Enum.with_index(1)
          |> Enum.map(fn {{char_id, data}, rank} ->
            %{character_id: char_id, rank: rank, score: data.threat.overall_score}
          end)

        Map.put(initial_rankings, :threat, threat_ranking)
      else
        initial_rankings
      end

    # Combat rankings
    final_rankings =
      if should_include_aspect?(:combat, aspects) do
        combat_ranking =
          character_data
          |> Enum.filter(fn {_, data} -> Map.has_key?(data, :combat) end)
          |> Enum.sort_by(fn {_, data} -> data.combat.kill_death_ratio end, :desc)
          |> Enum.with_index(1)
          |> Enum.map(fn {{char_id, data}, rank} ->
            %{character_id: char_id, rank: rank, kd_ratio: data.combat.kill_death_ratio}
          end)

        Map.put(rankings_with_threat, :combat, combat_ranking)
      else
        rankings_with_threat
      end

    final_rankings
  end

  defp generate_comparison_insights(character_data, _aspects) do
    initial_insights = []

    # Find the most threatening character
    insights_with_threat =
      case find_highest_threat(character_data) do
        nil ->
          initial_insights

        {char_id, threat_score} ->
          ["Character #{char_id} poses the highest threat (#{threat_score})" | initial_insights]
      end

    # Find outliers
    final_insights =
      case find_performance_outliers(character_data) do
        [] -> insights_with_threat
        outliers -> outliers ++ insights_with_threat
      end

    Enum.reverse(final_insights)
  end

  defp find_highest_threat(character_data) do
    character_data
    |> Enum.filter(fn {_, data} -> Map.has_key?(data, :threat) end)
    |> Enum.max_by(fn {_, data} -> data.threat.overall_score end, fn -> nil end)
    |> case do
      nil -> nil
      {char_id, data} -> {char_id, data.threat.overall_score}
    end
  end

  defp find_performance_outliers(character_data) do
    # Find characters with unusually high performance in specific areas
    initial_outliers = []

    # High K/D ratio outliers
    final_outliers =
      character_data
      |> Enum.filter(fn {_, data} ->
        Map.has_key?(data, :combat) and data.combat.kill_death_ratio > 5.0
      end)
      |> Enum.map(fn {char_id, data} ->
        "Character #{char_id} has exceptional K/D ratio (#{data.combat.kill_death_ratio})"
      end)
      |> Kernel.++(initial_outliers)

    final_outliers
  end

  defp perform_similarity_search(character_id, opts) do
    # For now, return a simplified similarity search
    # In practice, this would:
    # 1. Get the target character's profile
    # 2. Search database for characters with similar patterns
    # 3. Calculate similarity scores using cosine similarity or similar
    # 4. Filter and rank results

    similarity_threshold = Keyword.get(opts, :similarity_threshold, 0.7)
    max_results = Keyword.get(opts, :max_results, 10)

    # Placeholder implementation
    {:ok,
     %{
       target_character: character_id,
       similar_characters: [],
       similarity_threshold: similarity_threshold,
       max_results: max_results,
       searched_at: DateTime.utc_now()
     }}
  end

  defp perform_character_ranking(character_ids, metric) do
    # Gather metric data for all characters
    character_metrics =
      character_ids
      |> Task.async_stream(
        fn char_id ->
          {char_id, get_metric_value(char_id, metric)}
        end,
        max_concurrency: 10,
        timeout: 15_000
      )
      |> Enum.reduce([], fn
        {:ok, {char_id, {:ok, value}}}, acc ->
          [{char_id, value} | acc]

        {:ok, {char_id, {:error, _}}}, acc ->
          Logger.warning("Failed to get #{metric} for character #{char_id}")
          acc

        {:exit, _}, acc ->
          acc
      end)

    # Sort and rank
    rankings =
      character_metrics
      |> Enum.sort_by(fn {_, value} -> value end, :desc)
      |> Enum.with_index(1)
      |> Enum.map(fn {{char_id, value}, rank} ->
        %{
          character_id: char_id,
          rank: rank,
          value: value,
          metric: metric
        }
      end)

    {:ok,
     %{
       metric: metric,
       rankings: rankings,
       total_characters: length(rankings),
       ranked_at: DateTime.utc_now()
     }}
  end

  defp get_metric_value(character_id, :threat_score) do
    case ThreatAssessmentEngine.get_threat_score(character_id) do
      {:ok, score} -> {:ok, score}
      error -> error
    end
  end

  defp get_metric_value(character_id, :kill_death_ratio) do
    case CharacterAnalyzer.get_character_stats(character_id) do
      {:ok, stats} -> {:ok, stats.kill_death_ratio || 0}
      error -> error
    end
  end

  defp get_metric_value(character_id, :isk_efficiency) do
    case CharacterAnalyzer.get_character_stats(character_id) do
      {:ok, stats} -> {:ok, stats.isk_efficiency || 0}
      error -> error
    end
  end

  defp get_metric_value(character_id, metric) do
    # For other metrics, try to get from performance analysis
    case PerformanceAnalyzer.get_performance_metrics(character_id) do
      {:ok, metrics} -> {:ok, Map.get(metrics, metric, 0)}
      error -> error
    end
  end
end
