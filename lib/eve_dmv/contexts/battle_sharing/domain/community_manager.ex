defmodule EveDmv.Contexts.BattleSharing.Domain.CommunityManager do
  @moduledoc """
  Community management module for battle reports.

  Handles ratings, featured battle curation, search functionality, and community
  interactions extracted from the larger BattleCurator for better modularity.
  """

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
      not is_number(rating) -> {:error, "Rating must be a number"}
      rating < 1 or rating > 10 -> {:error, "Rating must be between 1 and 10"}
      not is_map(categories) -> {:error, "Categories must be a map"}
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
    current_ratings = Map.get(battle_report, :community_features, %{}) |> Map.get(:ratings, [])
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

      Enum.map(&Map.get(&1.category_ratings, category))
      Enum.filter(& &1)

      if length(category_ratings) > 0 do
        average = Enum.sum(category_ratings) / length(category_ratings)

        Map.put(acc, category, %{
          average: Float.round(average, 2),
          count: length(category_ratings)
        })
      else
        acc
      end
    end)
  end

  defp calculate_featured_score(average_rating, total_ratings, category_averages) do
    base_score = average_rating / 10.0

    # Popularity factor
    popularity_factor = min(0.3, :math.log(total_ratings + 1) / :math.log(50))

    # Category balance factor
    scores =
      Map.values(category_averages)

    Enum.filter(fn avg -> avg > 0 end)
    Enum.map(fn avg -> avg / 10.0 end)

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
    cutoff_date = DateTime.add(DateTime.utc_now(), -time_window_days * 24 * 3600, :second)

    # In a real implementation, this would query the database
    # For now, generate sample data to demonstrate the curation logic
    sample_reports = generate_sample_reports(cutoff_date, min_rating, time_window_days)
    {:ok, sample_reports}
  end

  defp generate_sample_reports(cutoff_date, min_rating, time_window_days) do
    base_time = cutoff_date

    for i <- 1..50 do
      # Vary creation time within the window
      time_offset = :rand.uniform(time_window_days * 24 * 3600)
      created_at = DateTime.add(base_time, time_offset, :second)

      # Generate realistic battle data
      participants = 10 + :rand.uniform(200)
      # 1B to 50B ISK
      isk_destroyed = (1 + :rand.uniform(50)) * 1_000_000_000
      duration_minutes = 15 + :rand.uniform(180)

      # Generate community metrics
      rating = min_rating + :rand.uniform() * (10 - min_rating)
      views = :rand.uniform(5000)
      total_ratings = :rand.uniform(50)

      # Generate tactical highlights
      highlights = generate_sample_highlights(i)

      # Generate tags based on battle characteristics
      tags =
        generate_sample_tags(
          determine_battle_type(participants, isk_destroyed),
          determine_battle_scale(participants)
        )

      %{
        id: "battle_#{i}",
        title: "Battle Report ##{i}",
        description: generate_battle_description({participants, isk_destroyed, duration_minutes}),
        created_at: created_at,
        creator_character_id: 1000 + :rand.uniform(1000),
        battle_data: %{
          participants: participants,
          isk_destroyed: isk_destroyed,
          duration_minutes: duration_minutes,
          systems_involved: 1 + :rand.uniform(3)
        },
        community_features: %{
          average_rating: Float.round(rating, 2),
          total_ratings: total_ratings,
          views: views,
          comments: :rand.uniform(20),
          shares: :rand.uniform(10)
        },
        tactical_highlights: highlights,
        tags: tags,
        video_links: generate_video_links(i)
      }
    end
  end

  defp analyze_curation_metrics(reports) do
    analyzed_reports =
      reports

    Enum.map(fn report ->
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

        Enum.filter(&meets_category_criteria(&1, category))
        Enum.sort_by(&get_category_score(&1, category), :desc)
        Enum.take(10) |> Enum.with_index()

        Enum.map(fn {report, index} ->
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
      Map.values(categorized_reports) |> List.flatten()

    Enum.sort_by(& &1.curation_metrics.overall_curation_score, :desc)

    selected = select_diverse_reports(all_candidates, max_results)
    {:ok, selected}
  end

  defp select_diverse_reports(candidates, max_results) do
    categories = candidates |> Enum.map(& &1.featured_category) |> Enum.uniq()

    # Try to get at least one from each category
    category_representatives =
      categories

    Enum.map(fn category ->
      candidates
      Enum.filter(&(&1.featured_category == category))
      Enum.max_by(& &1.curation_metrics.overall_curation_score)
    end)

    # Fill remaining slots with highest-scoring reports
    remaining_slots = max_results - length(category_representatives)

    remaining_candidates =
      candidates

    Enum.reject(&(&1 in category_representatives))
    Enum.take(remaining_slots)

    category_representatives ++ remaining_candidates
    Enum.sort_by(& &1.curation_metrics.overall_curation_score, :desc)
    Enum.take(max_results)
  end

  # Private helper functions for search

  defp perform_battle_report_search(query, filters, sort_by, limit) do
    # Generate sample search data for demonstration
    search_results = generate_search_sample_data()

    filtered_results =
      search_results
      |> apply_text_search(query)
      |> apply_search_filters(filters)
      |> apply_search_sorting(sort_by)
      |> Enum.take(limit)

    {:ok, filtered_results}
  end

  defp generate_search_sample_data do
    scenarios = [
      {"Jita Trade Hub Siege", :structure_bash, :massive, 8.5},
      {"Wormhole Capital Brawl", :capital_engagement, :large, 7.8},
      {"Low-sec Faction Warfare", :small_gang, :medium, 6.9},
      {"Null-sec Roaming Gang", :roaming, :small, 7.2},
      {"Alliance Tournament Match", :tournament, :medium, 9.1},
      {"Keepstar Defense", :structure_defense, :massive, 8.8},
      {"Carrier Ratting Gank", :gank, :small, 5.4},
      {"Providence Evacuation", :strategic_op, :large, 7.5}
    ]

    for {title, battle_type, scale, rating} <- scenarios do
      %{
        id: :crypto.strong_rand_bytes(8) |> Base.encode16(),
        title: title,
        description: generate_battle_description({title, battle_type, scale}),
        battle_type: battle_type,
        scale: scale,
        rating: rating,
        participants: scale_to_participants(scale),
        isk_destroyed: scale_to_isk(scale),
        duration: scale_to_duration(scale),
        created_at: DateTime.add(DateTime.utc_now(), -:rand.uniform(30 * 24 * 3600), :second),
        tags: generate_sample_tags(battle_type, scale),
        has_video: :rand.uniform() > 0.5,
        has_highlights: :rand.uniform() > 0.3,
        views: :rand.uniform(10000),
        comments: :rand.uniform(50)
      }
    end
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

  defp determine_battle_type(participants, isk_destroyed) do
    cond do
      participants > 500 -> :massive_fleet
      isk_destroyed > 10_000_000_000 -> :capital_engagement
      participants < 20 -> :small_gang
      true -> :medium_fleet
    end
  end

  defp determine_battle_scale(participants) do
    cond do
      participants > 200 -> :massive
      participants > 50 -> :large
      participants > 10 -> :medium
      true -> :small
    end
  end

  defp scale_to_participants(:small), do: 5 + :rand.uniform(10)
  defp scale_to_participants(:medium), do: 15 + :rand.uniform(35)
  defp scale_to_participants(:large), do: 50 + :rand.uniform(150)
  defp scale_to_participants(:massive), do: 200 + :rand.uniform(800)

  defp scale_to_isk(:small), do: (100 + :rand.uniform(900)) * 1_000_000
  defp scale_to_isk(:medium), do: (1 + :rand.uniform(4)) * 1_000_000_000
  defp scale_to_isk(:large), do: (5 + :rand.uniform(15)) * 1_000_000_000
  defp scale_to_isk(:massive), do: (20 + :rand.uniform(80)) * 1_000_000_000

  defp scale_to_duration(:small), do: 5 + :rand.uniform(15)
  defp scale_to_duration(:medium), do: 15 + :rand.uniform(30)
  defp scale_to_duration(:large), do: 30 + :rand.uniform(60)
  defp scale_to_duration(:massive), do: 60 + :rand.uniform(120)

  # Placeholder implementations for helper functions
  defp generate_rating_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16()
  defp generate_ip_hash, do: :crypto.hash(:sha256, "127.0.0.1") |> Base.encode16()
  defp generate_user_agent_hash, do: :crypto.hash(:sha256, "sample-user-agent") |> Base.encode16()

  defp generate_sample_highlights(_i), do: []
  defp generate_sample_tags(_battle_type, _scale), do: ["pvp", "fleet"]
  defp generate_video_links(_i), do: []
  defp generate_battle_description(_data), do: "An epic battle in the depths of space."

  defp calculate_engagement_score(_report), do: 0.7
  defp assess_tactical_value(_report), do: 0.8
  defp assess_educational_value(_report), do: 0.6
  defp assess_content_quality(_report), do: 0.7
  defp assess_uniqueness(_report), do: 0.5
  defp calculate_recency_score(_created_at), do: 0.8

  defp meets_category_criteria(_report, _category), do: true
  defp get_category_score(_report, _category), do: 0.8

  defp apply_text_search(results, _query), do: results
  defp apply_search_filters(results, _filters), do: results
  defp apply_search_sorting(results, _sort_by), do: results

  defp get_match_factors(_result), do: %{}
  defp generate_content_summary(_result), do: ""
  defp get_engagement_indicators(_result), do: %{}
  defp assess_learning_value(_result), do: %{}
  defp get_recommendations(_result), do: []
  defp find_similar_battles(_result, _all_results), do: []
end
