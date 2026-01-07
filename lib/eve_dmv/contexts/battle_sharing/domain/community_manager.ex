defmodule EveDmv.Contexts.BattleSharing.Domain.CommunityManager do
  @moduledoc """
  Community management module for battle reports.

  Handles ratings, featured battle curation, search functionality, and community
  interactions extracted from the larger BattleCurator for better modularity.
  """

  alias EveDmv.Core.Utils.DateTimeUtils

  require Logger

  # Community rating parameters
  @community_rating_threshold 3.0

  @doc """
  Rate a battle report with community scoring.
  """
  def rate_battle_report(report, rater_character_id, rating, options \\ []) do
    comment = Keyword.get(options, :comment, "")
    categories = Keyword.get(options, :categories, %{})

    with {:ok, validated_rating} <- validate_rating(rating, categories),
         {:ok, rating_record} <-
           create_rating_record(
             report.id,
             rater_character_id,
             validated_rating,
             comment,
             categories
           ),
         {:ok, updated_report} <- update_report_ratings(report, rating_record) do
      {:ok, updated_report}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Curate featured battles based on community ratings and engagement.
  """
  def curate_featured_battles(options \\ []) do
    time_window_days = Keyword.get(options, :time_window_days, 30)
    max_results = Keyword.get(options, :max_results, 20)
    min_rating = Keyword.get(options, :min_rating, @community_rating_threshold)

    with {:ok, candidate_reports} <- fetch_candidate_reports(time_window_days, min_rating),
         {:ok, analyzed_reports} <- analyze_curation_metrics(candidate_reports),
         {:ok, categorized_reports} <-
           categorize_featured_battles(analyzed_reports, [
             :epic,
             :tactical,
             :educational,
             :cinematic
           ]),
         {:ok, selected_reports} <- select_featured_battles(categorized_reports, max_results) do
      {:ok, selected_reports}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Search battle reports with filtering and ranking.
  """
  def search_battle_reports(query, options \\ []) do
    filters = Keyword.get(options, :filters, %{})
    sort_by = Keyword.get(options, :sort_by, :relevance)
    limit = Keyword.get(options, :limit, 50)
    include_metadata = Keyword.get(options, :include_metadata, false)

    with {:ok, search_results} <- perform_battle_report_search(query, filters, sort_by, limit),
         {:ok, enriched_results} <- maybe_enrich_search_results(search_results, include_metadata) do
      {:ok, enriched_results}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helper functions for rating management

  defp validate_rating(rating, categories) do
    cond do
      not is_number(rating) -> {:error, {:invalid_rating, :must_be_number}}
      rating < 1 or rating > 10 -> {:error, {:invalid_rating, :out_of_range}}
      not is_map(categories) -> {:error, {:invalid_categories, :must_be_map}}
      true -> {:ok, %{overall: rating, categories: categories}}
    end
  end

  defp create_rating_record(report_id, rater_character_id, validated_rating, comment, categories) do
    rating_record = %{
      id: generate_rating_id(),
      report_id: report_id,
      rater_character_id: rater_character_id,
      rating_score: validated_rating.overall,
      category_ratings: categories,
      comment: String.slice(comment || "", 0, 500),
      rated_at: DateTime.utc_now(),
      ip_hash: generate_ip_hash(),
      user_agent_hash: generate_user_agent_hash()
    }

    {:ok, rating_record}
  end

  defp update_report_ratings(battle_report, rating_record) do
    current_ratings = Map.get(Map.get(battle_report, :community_features, %{}), :ratings, [])
    updated_ratings = [rating_record | current_ratings]

    # Calculate new statistics
    total_ratings = length(updated_ratings)
    total_score = updated_ratings |> Enum.map(& &1.rating_score) |> Enum.sum()
    new_average = if total_ratings > 0, do: total_score / total_ratings, else: 0.0

    # Calculate category averages
    category_averages = calculate_category_averages(updated_ratings)

    # Calculate featured score
    featured_score = calculate_featured_score(new_average, total_ratings, category_averages)

    updated_community_features = %{
      ratings: updated_ratings,
      average_rating: Float.round(new_average, 2),
      total_ratings: total_ratings,
      category_averages: category_averages,
      featured_score: featured_score,
      last_rated_at: DateTime.utc_now()
    }

    updated_report = Map.put(battle_report, :community_features, updated_community_features)
    {:ok, updated_report}
  end

  defp calculate_category_averages(ratings) do
    all_categories = ratings |> Enum.flat_map(&Map.keys(&1.category_ratings)) |> Enum.uniq()

    Enum.reduce(all_categories, %{}, fn category, acc ->
      category_ratings =
        ratings
        |> Enum.map(&Map.get(&1.category_ratings, category))
        |> Enum.filter(& &1)

      if Enum.empty?(category_ratings) do
        acc
      else
        average = Enum.sum(category_ratings) / length(category_ratings)

        Map.put(acc, category, %{
          average: Float.round(average, 2),
          count: length(category_ratings)
        })
      end
    end)
  end

  defp calculate_featured_score(average_rating, total_ratings, category_averages) do
    base_score = average_rating / 10.0

    # Popularity factor
    popularity_factor = min(0.3, :math.log(total_ratings + 1) / :math.log(50))

    # Category balance factor
    scores =
      category_averages
      |> Map.values()
      |> Enum.filter(fn avg -> avg > 0 end)
      |> Enum.map(fn avg -> avg / 10.0 end)

    category_balance =
      case scores do
        [] -> 0.0
        scores -> Enum.sum(scores) / length(scores)
      end

    # Weighted combination
    featured_score = base_score * 0.6 + popularity_factor + category_balance * 0.2
    Float.round(min(1.0, featured_score), 3)
  end

  # Private helper functions for curation

  defp fetch_candidate_reports(time_window_days, min_rating) do
    cutoff_date = DateTimeUtils.add(DateTime.utc_now(), -time_window_days * 24 * 3600, :second)

    # In a real implementation, this would query the database
    # For now, generate sample data to demonstrate the curation logic
    sample_reports = generate_sample_reports(cutoff_date, min_rating, time_window_days)
    {:ok, sample_reports}
  end

  defp generate_sample_reports(_cutoff_date, _min_rating, _time_window_days) do
    # Return empty list - real implementation would query actual battle reports from database
    []

    # Function body removed - was generating fake battle report data
  end

  defp analyze_curation_metrics(reports) do
    analyzed_reports =
      reports
      |> Enum.map(fn report ->
        engagement_score = calculate_engagement_score(report)
        tactical_value = assess_tactical_value(report)
        educational_value = assess_educational_value(report)
        content_quality = assess_content_quality(report)
        uniqueness = assess_uniqueness(report)
        recency_score = calculate_recency_score(report.created_at)

        overall_curation_score =
          engagement_score * 0.25 + tactical_value * 0.25 + educational_value * 0.2 +
            content_quality * 0.15 + uniqueness * 0.1 + recency_score * 0.05

        curation_metrics = %{
          engagement_score: engagement_score,
          tactical_value: tactical_value,
          educational_value: educational_value,
          content_quality: content_quality,
          uniqueness: uniqueness,
          recency_score: recency_score,
          overall_curation_score: Float.round(overall_curation_score, 3)
        }

        Map.put(report, :curation_metrics, curation_metrics)
      end)

    {:ok, analyzed_reports}
  end

  defp categorize_featured_battles(reports, categories) do
    categorized =
      Enum.reduce(categories, %{}, fn category, acc ->
        category_reports =
          reports
          |> Enum.filter(&meets_category_criteria(&1, category))
          |> Enum.sort_by(&get_category_score(&1, category), :desc)
          |> Enum.take(10)
          |> Enum.with_index()
          |> Enum.map(fn {report, index} ->
            Map.merge(report, %{
              featured_category: category,
              category_rank: index + 1,
              category_score: get_category_score(report, category)
            })
          end)

        Map.put(acc, category, category_reports)
      end)

    {:ok, categorized}
  end

  defp select_featured_battles(categorized_reports, max_results) do
    all_candidates =
      categorized_reports
      |> Map.values()
      |> List.flatten()
      |> Enum.sort_by(& &1.curation_metrics.overall_curation_score, :desc)

    selected = select_diverse_reports(all_candidates, max_results)
    {:ok, selected}
  end

  defp select_diverse_reports(candidates, max_results) do
    categories = candidates |> Enum.map(& &1.featured_category) |> Enum.uniq()

    # Try to get at least one from each category
    category_representatives =
      categories
      |> Enum.map(fn category ->
        candidates
        |> Enum.filter(&(&1.featured_category == category))
        |> Enum.max_by(& &1.curation_metrics.overall_curation_score)
      end)

    # Fill remaining slots with highest-scoring reports
    remaining_slots = max_results - length(category_representatives)

    remaining_candidates =
      candidates
      |> Enum.reject(&(&1 in category_representatives))
      |> Enum.take(remaining_slots)

    (category_representatives ++ remaining_candidates)
    |> Enum.sort_by(& &1.curation_metrics.overall_curation_score, :desc)
    |> Enum.take(max_results)
  end

  # Private helper functions for search

  defp perform_battle_report_search(_query, _filters, _sort_by, _limit) do
    # Battle sharing feature not yet implemented
    # Return empty results instead of fake data
    {:ok, []}
  end

  defp maybe_enrich_search_results(results, false), do: {:ok, results}

  defp maybe_enrich_search_results(results, true) do
    enriched = Enum.map(results, &enrich_search_result/1)
    {:ok, enriched}
  end

  defp enrich_search_result(result) do
    Map.merge(result, %{
      match_factors: get_match_factors(result),
      content_summary: generate_content_summary(result),
      engagement_indicators: get_engagement_indicators(result),
      learning_value: assess_learning_value(result),
      recommendations: get_recommendations(result),
      similar_battles: find_similar_battles(result, [])
    })
  end

  # Utility functions for generating sample data and calculations
  # Removed random data generation functions - battle sharing not yet implemented

  # Placeholder implementations for helper functions
  defp generate_rating_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16()
  defp generate_ip_hash, do: :crypto.hash(:sha256, "127.0.0.1") |> Base.encode16()
  defp generate_user_agent_hash, do: :crypto.hash(:sha256, "sample-user-agent") |> Base.encode16()

  defp calculate_engagement_score(_report), do: 0.7
  defp assess_tactical_value(_report), do: 0.8
  defp assess_educational_value(_report), do: 0.6
  defp assess_content_quality(_report), do: 0.7
  defp assess_uniqueness(_report), do: 0.5
  defp calculate_recency_score(_created_at), do: 0.8

  defp meets_category_criteria(_report, _category), do: true
  defp get_category_score(_report, _category), do: 0.8

  # Search functions removed - battle sharing not yet implemented

  defp get_match_factors(_result), do: %{}
  defp generate_content_summary(_result), do: ""
  defp get_engagement_indicators(_result), do: %{}
  defp assess_learning_value(_result), do: %{}
  defp get_recommendations(_result), do: []
  defp find_similar_battles(_result, _all_results), do: []
end
