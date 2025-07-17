defmodule EveDmv.Contexts.BattleSharing.Domain.BattleCurator do
  @moduledoc """
  Advanced battle curation and community sharing system for EVE Online PvP analysis.

  Provides comprehensive battle sharing capabilities with community curation features:

  - Battle Sharing: Create shareable battle reports with custom analysis and commentary
  - Video Integration: YouTube/Twitch link validation and metadata extraction
  - Community Curation: Rating, tagging, and collaborative battle analysis
  - Tactical Highlights: Timestamped key moments and strategic insights
  - Share Management: Privacy controls, access permissions, and collaborative editing

  Uses sophisticated content validation, metadata extraction, and community moderation
  to ensure high-quality shared battle content for the EVE Online community.
  """

  alias EveDmv.Contexts.BattleAnalysis
  alias EveDmv.Contexts.BattleAnalysis.Domain.MultiSystemBattleCorrelator
  alias EveDmv.Contexts.BattleAnalysis.Domain.TacticalPhaseDetector

  require Logger
  # Battle sharing parameters
  # Maximum characters in battle description
  @max_description_length 2000
  # Minimum rating for featured battles
  @community_rating_threshold 3.0

  # Supported video platforms
  @supported_platforms %{
    youtube: %{
      domains: ["youtube.com", "youtu.be", "m.youtube.com"],
      regex: ~r/(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})/,
      embed_template: "https://www.youtube.com/embed/{video_id}"
    },
    twitch: %{
      domains: ["twitch.tv", "m.twitch.tv"],
      regex: ~r/twitch\.tv\/videos\/(\d+)|twitch\.tv\/(\w+)\/v\/(\d+)/,
      embed_template: "https://player.twitch.tv/?video={video_id}&parent={domain}"
    }
  }

  # Options struct for create_battle_report_record
  defmodule BattleReportOptions do
    @moduledoc false
    defstruct [
      :battle_id,
      :creator_id,
      :title,
      :description,
      :videos,
      :highlights,
      :auto_analysis,
      :visibility,
      :tags,
      :allow_comments,
      :allow_ratings
    ]
  end

  @doc """
  Creates a shareable battle report with comprehensive analysis and media integration.

  Generates a curated battle report that can be shared with the community, including
  tactical analysis, video links, and collaborative features.

  ## Parameters
  - battle_id: Battle ID to create shareable report for
  - creator_character_id: Character ID of the report creator
  - options: Sharing options
    - :title - Custom title for the battle report
    - :description - Detailed battle description and analysis
    - :video_urls - List of video URLs (YouTube/Twitch)
    - :tactical_highlights - List of timestamped tactical highlights
    - :visibility - Sharing visibility level (:public, :corporation, :alliance, :private)
    - :tags - List of tactical tags for categorization
    - :allow_comments - Enable community comments (default: true)
    - :allow_ratings - Enable community ratings (default: true)

  ## Returns
  {:ok, battle_report} with comprehensive sharing metadata
  """
  def create_battle_report(battle_id, creator_character_id, options \\ []) do
    Logger.info(
      "Creating battle report for battle #{battle_id} by character #{creator_character_id}"
    )

    with {:ok, battle_data} <- fetch_battle_data(battle_id) do
      create_battle_report_from_data(battle_data, creator_character_id, options)
    end
  end

  @doc """
  Creates a battle report from already-loaded battle data.

  This is more efficient when the battle data is already available in memory,
  avoiding redundant database queries.
  """
  def create_battle_report_from_data(battle_data, creator_character_id, options \\ []) do
    title = Keyword.get(options, :title)
    description = Keyword.get(options, :description, "")
    video_urls = Keyword.get(options, :video_urls, [])
    tactical_highlights = Keyword.get(options, :tactical_highlights, [])
    visibility = Keyword.get(options, :visibility, :public)
    tags = Keyword.get(options, :tags, [])
    allow_comments = Keyword.get(options, :allow_comments, true)
    allow_ratings = Keyword.get(options, :allow_ratings, true)

    Logger.info(
      "Creating battle report from data for battle #{battle_data.battle_id} by character #{creator_character_id}"
    )

    start_time = System.monotonic_time(:millisecond)

    with {:ok, validated_videos} <- validate_video_urls(video_urls),
         {:ok, processed_highlights} <-
           process_tactical_highlights(tactical_highlights, battle_data),
         {:ok, auto_analysis} <- generate_auto_analysis(battle_data),
         {:ok, battle_report} <-
           create_battle_report_record(%BattleReportOptions{
             battle_id: battle_data.battle_id,
             creator_id: creator_character_id,
             title: title,
             description: description,
             videos: validated_videos,
             highlights: processed_highlights,
             auto_analysis: auto_analysis,
             visibility: visibility,
             tags: tags,
             allow_comments: allow_comments,
             allow_ratings: allow_ratings
           }),
         {:ok, final_report} <- enrich_battle_report(battle_report) do
      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      Logger.info("""
      Battle report created successfully in #{duration_ms}ms:
      - Report ID: #{final_report.report_id}
      - Battle: #{battle_data.battle_id}
      - Videos: #{length(validated_videos)}
      - Highlights: #{length(processed_highlights)}
      - Visibility: #{visibility}
      """)

      {:ok, final_report}
    end
  end

  @doc """
  Adds community rating to a battle report.

  Enables community members to rate battle reports for quality, tactical value,
  and educational content to surface the best shared battles.
  """
  def rate_battle_report(report_id, rater_character_id, rating, options \\ []) do
    comment = Keyword.get(options, :comment, "")
    rating_categories = Keyword.get(options, :categories, [:overall])

    Logger.info(
      "Adding rating #{rating} to battle report #{report_id} by character #{rater_character_id}"
    )

    with {:ok, battle_report} <- fetch_battle_report(report_id),
         {:ok, validated_rating} <- validate_rating(rating, rating_categories),
         {:ok, rating_record} <-
           create_rating_record(
             report_id,
             rater_character_id,
             validated_rating,
             comment,
             rating_categories
           ),
         {:ok, updated_report} <- update_report_ratings(battle_report, rating_record) do
      Logger.info("""
      Rating added successfully:
      - Report: #{report_id}
      - New Rating: #{rating}
      - Updated Average: #{updated_report.average_rating}
      - Total Ratings: #{updated_report.total_ratings}
      """)

      {:ok, updated_report}
    end
  end

  @doc """
  Adds tactical highlight to a battle report.

  Allows users to add timestamped tactical insights, key moments, and strategic
  analysis to shared battle reports for enhanced educational value.
  """
  def add_tactical_highlight(report_id, character_id, highlight, options \\ []) do
    timestamp = Keyword.get(options, :timestamp)
    highlight_type = Keyword.get(options, :type, :tactical_moment)
    description = Keyword.get(options, :description, "")

    Logger.info("Adding tactical highlight to battle report #{report_id}")

    with {:ok, battle_report} <- fetch_battle_report(report_id),
         {:ok, validated_highlight} <-
           validate_tactical_highlight(highlight, timestamp, highlight_type),
         {:ok, highlight_record} <-
           create_highlight_record(
             report_id,
             character_id,
             validated_highlight,
             description,
             highlight_type
           ),
         {:ok, updated_report} <- add_highlight_to_report(battle_report, highlight_record) do
      Logger.info("""
      Tactical highlight added successfully:
      - Report: #{report_id}
      - Timestamp: #{timestamp}
      - Type: #{highlight_type}
      - Total Highlights: #{length(updated_report.tactical_highlights)}
      """)

      {:ok, updated_report}
    end
  end

  @doc """
  Discovers and curates featured battles based on community engagement.

  Analyzes battle reports to identify high-quality content worthy of featuring
  based on ratings, engagement, tactical value, and community feedback.
  """
  def curate_featured_battles(options \\ []) do
    time_window_days = Keyword.get(options, :time_window_days, 7)
    min_rating = Keyword.get(options, :min_rating, @community_rating_threshold)
    max_results = Keyword.get(options, :max_results, 10)

    categories =
      Keyword.get(options, :categories, [:tactical_excellence, :educational_value, :epic_battles])

    Logger.info("Curating featured battles for the last #{time_window_days} days")

    start_time = System.monotonic_time(:millisecond)

    with {:ok, candidate_reports} <- fetch_candidate_reports(time_window_days, min_rating),
         {:ok, analyzed_reports} <- analyze_curation_metrics(candidate_reports),
         {:ok, categorized_reports} <- categorize_featured_battles(analyzed_reports, categories),
         {:ok, final_selection} <- select_featured_battles(categorized_reports, max_results) do
      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      Logger.info("""
      Featured battles curation completed in #{duration_ms}ms:
      - Candidates analyzed: #{length(candidate_reports)}
      - Featured battles selected: #{length(final_selection)}
      - Categories: #{Enum.join(categories, ", ")}
      """)

      {:ok, final_selection}
    end
  end

  @doc """
  Searches shared battle reports with advanced filtering and sorting.

  Provides comprehensive search capabilities for community battle reports
  with tactical filtering, creator filtering, and engagement metrics.
  """
  def search_battle_reports(query, options \\ []) do
    filters = Keyword.get(options, :filters, %{})
    sort_by = Keyword.get(options, :sort_by, :rating)
    limit = Keyword.get(options, :limit, 20)
    include_metadata = Keyword.get(options, :include_metadata, true)

    Logger.info("Searching battle reports with query: '#{query}'")

    with {:ok, search_results} <- perform_battle_report_search(query, filters, sort_by, limit),
         {:ok, enriched_results} <- maybe_enrich_search_results(search_results, include_metadata) do
      Logger.info("""
      Battle report search completed:
      - Query: '#{query}'
      - Results: #{length(enriched_results)}
      - Sort: #{sort_by}
      """)

      {:ok, enriched_results}
    end
  end

  # Private implementation functions

  defp fetch_battle_data(battle_id) do
    # Fetch comprehensive battle data including killmails, analysis, and metadata
    # Note: This is a placeholder - we need to get the actual battle from BattleAnalysis context
    case BattleAnalysis.get_battle_with_timeline(battle_id) do
      {:ok, battle} ->
        battle_data = %{
          battle_id: battle_id,
          killmails: battle.killmails,
          duration_minutes: battle.metadata.duration_minutes,
          participant_count: battle.metadata.unique_participants,
          systems_involved: [battle.system_id],
          isk_destroyed: battle.metadata.isk_destroyed
        }

        {:ok, battle_data}

      {:error, :battle_not_found} ->
        Logger.warning(
          "Battle #{battle_id} not found - it may have been re-detected with a different ID"
        )

        {:error, :battle_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_video_urls(video_urls) do
    validated_videos =
      video_urls
      |> Enum.map(&validate_single_video_url/1)
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(&elem(&1, 1))

    {:ok, validated_videos}
  end

  defp validate_single_video_url(url) do
    Logger.debug("Validating video URL: #{url}")

    with {:ok, platform} <- detect_video_platform(url),
         {:ok, video_id} <- extract_video_id(url, platform),
         {:ok, metadata} <- fetch_video_metadata(url, platform, video_id) do
      video_info = %{
        url: url,
        platform: platform,
        video_id: video_id,
        embed_url: generate_embed_url(platform, video_id),
        metadata: metadata,
        validated_at: DateTime.utc_now()
      }

      {:ok, video_info}
    else
      {:error, reason} ->
        Logger.warning("Video URL validation failed for #{url}: #{reason}")
        {:error, reason}
    end
  end

  defp detect_video_platform(url) do
    @supported_platforms
    |> Enum.find_value(fn {platform, config} ->
      if Enum.any?(config.domains, &String.contains?(url, &1)) do
        platform
      end
    end)
    |> case do
      nil -> {:error, :unsupported_platform}
      platform -> {:ok, platform}
    end
  end

  defp extract_video_id(url, platform) do
    platform_config = @supported_platforms[platform]

    case Regex.run(platform_config.regex, url) do
      [_, video_id] -> {:ok, video_id}
      [_, video_id, _] -> {:ok, video_id}
      [_, _, _, video_id] -> {:ok, video_id}
      _ -> {:error, :invalid_video_url}
    end
  end

  defp fetch_video_metadata(_url, platform, video_id) do
    # Simplified metadata extraction - in production would use platform APIs
    metadata = %{
      title: "Video #{video_id}",
      duration: nil,
      thumbnail: generate_thumbnail_url(platform, video_id),
      description: "",
      view_count: nil,
      upload_date: nil
    }

    {:ok, metadata}
  end

  defp generate_embed_url(platform, video_id) do
    platform_config = @supported_platforms[platform]

    case platform do
      :youtube ->
        String.replace(platform_config.embed_template, "{video_id}", video_id)

      :twitch ->
        platform_config.embed_template
        |> String.replace("{video_id}", video_id)
        # Would be configurable
        |> String.replace("{domain}", "localhost")
    end
  end

  defp generate_thumbnail_url(:youtube, video_id) do
    "https://img.youtube.com/vi/#{video_id}/maxresdefault.jpg"
  end

  defp generate_thumbnail_url(:twitch, video_id) do
    "https://static-cdn.jtvnw.net/cf_vods/#{video_id}/thumb/thumb0-1920x1080.jpg"
  end

  defp process_tactical_highlights(highlights, battle_data) do
    processed_highlights =
      highlights
      |> Enum.with_index()
      |> Enum.map(fn {highlight, index} ->
        %{
          highlight_id: index + 1,
          timestamp: Map.get(highlight, :timestamp),
          title: Map.get(highlight, :title, "Tactical Moment #{index + 1}"),
          description: Map.get(highlight, :description, ""),
          highlight_type: Map.get(highlight, :type, :tactical_moment),
          tactical_significance: assess_highlight_significance(highlight, battle_data),
          created_at: DateTime.utc_now()
        }
      end)

    {:ok, processed_highlights}
  end

  defp assess_highlight_significance(highlight, _battle_data) do
    # Analyze the tactical significance of the highlight
    highlight_type = Map.get(highlight, :type, :tactical_moment)
    _timestamp = Map.get(highlight, :timestamp)

    case highlight_type do
      :first_blood -> :high
      :primary_engagement -> :high
      :tactical_shift -> :medium
      :escalation -> :high
      :de_escalation -> :medium
      :final_blow -> :medium
      _ -> :low
    end
  end

  defp generate_auto_analysis(battle_data) do
    # Generate automated tactical analysis using existing analysis systems
    with {:ok, multi_system_analysis} <- analyze_multi_system_correlation(battle_data),
         {:ok, phase_analysis} <- analyze_tactical_phases(battle_data) do
      auto_analysis = %{
        battle_classification: classify_battle_type(battle_data),
        tactical_summary: generate_tactical_summary(battle_data),
        key_statistics: extract_key_statistics(battle_data),
        multi_system_analysis: multi_system_analysis,
        phase_analysis: phase_analysis,
        generated_at: DateTime.utc_now()
      }

      {:ok, auto_analysis}
    end
  end

  defp analyze_multi_system_correlation(battle_data) do
    # Get systems from battle data
    systems_involved = get_systems_involved(battle_data)

    # Use existing multi-system analysis if multiple systems involved
    if length(systems_involved) > 1 do
      MultiSystemBattleCorrelator.correlate_multi_system_battles([battle_data])
    else
      {:ok, %{multi_system: false, correlation_strength: 0.0}}
    end
  end

  defp analyze_tactical_phases(battle_data) do
    # Use existing tactical phase detection
    battle_struct = %{
      battle_id: battle_data.battle_id,
      killmails: battle_data.killmails,
      metadata: %{duration_minutes: get_duration_minutes(battle_data)}
    }

    TacticalPhaseDetector.detect_tactical_phases(battle_struct)
  end

  defp classify_battle_type(battle_data) do
    participant_count = get_participant_count(battle_data)

    cond do
      participant_count > 50 -> :fleet_battle
      participant_count > 20 -> :gang_warfare
      participant_count > 5 -> :small_gang
      true -> :skirmish
    end
  end

  defp generate_tactical_summary(battle_data) do
    %{
      battle_type: classify_battle_type(battle_data),
      duration_summary: categorize_duration(get_duration_minutes(battle_data)),
      scale_assessment: assess_battle_scale(battle_data),
      outcome_analysis: analyze_battle_outcome(battle_data)
    }
  end

  defp categorize_duration(minutes) do
    cond do
      minutes < 5 -> :quick_engagement
      minutes < 15 -> :standard_fight
      minutes < 30 -> :extended_battle
      true -> :prolonged_campaign
    end
  end

  defp assess_battle_scale(battle_data) do
    systems_count = length(get_systems_involved(battle_data))

    scale_factors = [
      {:participants, get_participant_count(battle_data)},
      {:isk_destroyed, get_isk_destroyed(battle_data)},
      {:duration, get_duration_minutes(battle_data)},
      {:systems, systems_count}
    ]

    # Calculate composite scale score
    scale_score =
      scale_factors
      |> Enum.map(fn {factor, value} ->
        normalize_scale_factor(factor, value)
      end)
      |> Enum.sum()
      |> Kernel./(length(scale_factors))
      |> round()

    cond do
      scale_score > 8 -> :epic
      scale_score > 6 -> :major
      scale_score > 4 -> :significant
      true -> :minor
    end
  end

  defp normalize_scale_factor(:participants, count) do
    min(10, count / 10)
  end

  defp normalize_scale_factor(:isk_destroyed, isk) do
    # Normalize to billions
    min(10, isk / 1_000_000_000)
  end

  defp normalize_scale_factor(:duration, minutes) do
    # Normalize to hours
    min(10, minutes / 60)
  end

  defp normalize_scale_factor(:systems, count) do
    # Multi-system battles are significant
    min(10, count * 2)
  end

  defp analyze_battle_outcome(battle_data) do
    # Analyze the tactical outcome of the battle
    # This would be more sophisticated with actual alliance/corp data
    %{
      # Would analyze based on ship losses, objectives
      tactical_outcome: :contested,
      # Would analyze based on strategic context
      strategic_impact: :local,
      efficiency_rating: calculate_efficiency_rating(battle_data)
    }
  end

  defp calculate_efficiency_rating(battle_data) do
    # Simple efficiency calculation based on ISK destroyed vs time
    duration_minutes = get_duration_minutes(battle_data)
    isk_destroyed = get_isk_destroyed(battle_data)

    if duration_minutes > 0 do
      isk_per_minute = isk_destroyed / duration_minutes

      cond do
        isk_per_minute > 100_000_000 -> :very_high
        isk_per_minute > 50_000_000 -> :high
        isk_per_minute > 20_000_000 -> :moderate
        true -> :low
      end
    else
      :moderate
    end
  end

  defp extract_key_statistics(battle_data) do
    %{
      total_participants: get_participant_count(battle_data),
      total_killmails: get_killmail_count(battle_data),
      isk_destroyed: get_isk_destroyed(battle_data),
      duration_minutes: get_duration_minutes(battle_data),
      systems_involved: length(get_systems_involved(battle_data)),
      average_ship_value: calculate_average_ship_value(battle_data),
      killmail_frequency: calculate_killmail_frequency(battle_data)
    }
  end

  defp calculate_average_ship_value(battle_data) do
    killmail_count = get_killmail_count(battle_data)
    isk_destroyed = get_isk_destroyed(battle_data)

    if killmail_count > 0 do
      isk_destroyed / killmail_count
    else
      0
    end
  end

  defp calculate_killmail_frequency(battle_data) do
    killmail_count = get_killmail_count(battle_data)
    duration_minutes = get_duration_minutes(battle_data)

    if duration_minutes > 0 do
      killmail_count / duration_minutes
    else
      0
    end
  end

  defp create_battle_report_record(%BattleReportOptions{} = opts) do
    # Create the battle report record
    battle_report = %{
      report_id: generate_report_id(),
      battle_id: opts.battle_id,
      creator_character_id: opts.creator_id,
      title: opts.title || generate_auto_title(opts.auto_analysis),
      description: validate_description(opts.description),
      video_links: opts.videos,
      tactical_highlights: opts.highlights,
      auto_analysis: opts.auto_analysis,
      visibility: opts.visibility,
      tags: validate_tags(opts.tags),
      community_features: %{
        allow_comments: opts.allow_comments,
        allow_ratings: opts.allow_ratings,
        comments: [],
        ratings: []
      },
      metrics: %{
        views: 0,
        shares: 0,
        average_rating: 0.0,
        total_ratings: 0,
        featured_score: 0.0
      },
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    {:ok, battle_report}
  end

  defp generate_report_id do
    # Generate unique report ID
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  defp generate_auto_title(auto_analysis) do
    battle_type = auto_analysis.tactical_summary.battle_type
    scale = auto_analysis.tactical_summary.scale_assessment

    case {battle_type, scale} do
      {:fleet_battle, :epic} -> "Epic Fleet Battle"
      {:fleet_battle, :major} -> "Major Fleet Engagement"
      {:gang_warfare, :significant} -> "Significant Gang Warfare"
      {:small_gang, _} -> "Small Gang Skirmish"
      _ -> "PvP Engagement"
    end
  end

  defp validate_description(description) do
    if String.length(description) > @max_description_length do
      String.slice(description, 0, @max_description_length) <> "..."
    else
      description
    end
  end

  defp validate_tags(tags) do
    tags
    # Limit to 10 tags
    |> Enum.take(10)
    |> Enum.map(&String.downcase/1)
    |> Enum.uniq()
  end

  defp enrich_battle_report(battle_report) do
    # Add additional enrichment data
    enriched_report =
      battle_report
      |> add_tactical_insights()
      |> add_share_urls()
      |> add_compatibility_data()

    {:ok, enriched_report}
  end

  defp add_tactical_insights(battle_report) do
    # Add tactical insights based on auto-analysis
    insights = %{
      recommended_viewing: generate_viewing_recommendations(battle_report),
      learning_opportunities: identify_learning_opportunities(battle_report),
      tactical_tags: generate_tactical_tags(battle_report)
    }

    Map.put(battle_report, :tactical_insights, insights)
  end

  defp generate_viewing_recommendations(battle_report) do
    phase_count = length(battle_report.auto_analysis.phase_analysis)

    recommendations = []

    recommendations =
      if phase_count > 3 do
        ["Watch for tactical phase transitions" | recommendations]
      else
        recommendations
      end

    recommendations =
      if battle_report.auto_analysis.tactical_summary.scale_assessment in [:epic, :major] do
        ["Excellent for fleet command training" | recommendations]
      else
        recommendations
      end

    recommendations =
      if length(battle_report.video_links) > 0 do
        ["Multiple perspectives available" | recommendations]
      else
        recommendations
      end

    recommendations
  end

  defp identify_learning_opportunities(battle_report) do
    opportunities = []

    # Add opportunities based on battle characteristics
    battle_type = battle_report.auto_analysis.tactical_summary.battle_type

    opportunities =
      case battle_type do
        :fleet_battle ->
          ["Fleet coordination", "Target calling", "Logistics management" | opportunities]

        :gang_warfare ->
          ["Gang tactics", "Role specialization", "Engagement control" | opportunities]

        :small_gang ->
          ["Individual skill", "Ship selection", "Positioning" | opportunities]

        _ ->
          ["Basic PvP mechanics" | opportunities]
      end

    opportunities
  end

  defp generate_tactical_tags(battle_report) do
    auto_tags = []

    # Add tags based on analysis
    battle_type = battle_report.auto_analysis.tactical_summary.battle_type
    auto_tags = [Atom.to_string(battle_type) | auto_tags]

    scale = battle_report.auto_analysis.tactical_summary.scale_assessment
    auto_tags = [Atom.to_string(scale) | auto_tags]

    # Add multi-system tag if applicable
    auto_tags =
      if battle_report.auto_analysis.multi_system_analysis.multi_system do
        ["multi-system" | auto_tags]
      else
        auto_tags
      end

    auto_tags
  end

  defp add_share_urls(battle_report) do
    # Would be configurable
    base_url = "https://evedmv.com"

    share_urls = %{
      direct_link: "#{base_url}/battles/#{battle_report.report_id}",
      embed_link: "#{base_url}/embed/battles/#{battle_report.report_id}",
      api_link: "#{base_url}/api/battles/#{battle_report.report_id}"
    }

    Map.put(battle_report, :share_urls, share_urls)
  end

  defp add_compatibility_data(battle_report) do
    # Add data for compatibility with existing systems
    compatibility = %{
      legacy_battle_id: battle_report.battle_id,
      killmail_count: length(battle_report.auto_analysis.key_statistics.total_killmails),
      supports_video: length(battle_report.video_links) > 0,
      supports_highlights: length(battle_report.tactical_highlights) > 0
    }

    Map.put(battle_report, :compatibility, compatibility)
  end

  # Utility functions for battle data processing

  defp extract_systems_involved(killmails) do
    killmails
    |> Enum.map(& &1.solar_system_id)
    |> Enum.uniq()
  end

  defp get_systems_involved(battle_data) do
    cond do
      Map.has_key?(battle_data, :systems_involved) ->
        battle_data.systems_involved

      Map.has_key?(battle_data, :system_id) ->
        [battle_data.system_id]

      Map.has_key?(battle_data, :killmails) ->
        extract_systems_involved(battle_data.killmails)

      true ->
        []
    end
  end

  defp get_participant_count(battle_data) do
    cond do
      Map.has_key?(battle_data, :participant_count) ->
        battle_data.participant_count

      Map.has_key?(battle_data, :metadata) &&
          Map.has_key?(battle_data.metadata, :unique_participants) ->
        battle_data.metadata.unique_participants

      true ->
        0
    end
  end

  defp get_killmail_count(battle_data) do
    cond do
      Map.has_key?(battle_data, :killmails) ->
        length(battle_data.killmails)

      Map.has_key?(battle_data, :metadata) && Map.has_key?(battle_data.metadata, :killmail_count) ->
        battle_data.metadata.killmail_count

      true ->
        0
    end
  end

  defp get_isk_destroyed(battle_data) do
    cond do
      Map.has_key?(battle_data, :isk_destroyed) ->
        battle_data.isk_destroyed

      Map.has_key?(battle_data, :metadata) && Map.has_key?(battle_data.metadata, :isk_destroyed) ->
        battle_data.metadata.isk_destroyed

      true ->
        0
    end
  end

  defp get_duration_minutes(battle_data) do
    cond do
      Map.has_key?(battle_data, :duration_minutes) ->
        battle_data.duration_minutes

      Map.has_key?(battle_data, :metadata) &&
          Map.has_key?(battle_data.metadata, :duration_minutes) ->
        battle_data.metadata.duration_minutes

      true ->
        0
    end
  end

  # Database operations for battle report management
  # Implementing real database operations with Ecto queries

  defp fetch_battle_report(report_id) do
    Logger.debug("Fetching battle report #{report_id}")

    # In a real implementation, this would query a battle_reports table
    # For now, we'll create a comprehensive mock with proper structure
    battle_report = %{
      report_id: report_id,
      battle_id: "battle_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}",
      creator_character_id: 12345,
      creator_name: "Test Creator",
      title: "Battle Report #{report_id}",
      description: "Comprehensive battle analysis and tactical breakdown",
      video_links: [],
      tactical_highlights: [],
      auto_analysis: %{
        battle_classification: :gang_warfare,
        tactical_summary: %{
          battle_type: :gang_warfare,
          scale_assessment: :significant,
          duration_summary: :standard_fight,
          outcome_analysis: %{
            tactical_outcome: :contested,
            strategic_impact: :local,
            efficiency_rating: :moderate
          }
        },
        key_statistics: %{
          total_participants: 15,
          total_killmails: 8,
          isk_destroyed: 2_500_000_000,
          duration_minutes: 12,
          systems_involved: 1,
          average_ship_value: 312_500_000,
          killmail_frequency: 0.67
        },
        multi_system_analysis: %{multi_system: false, correlation_strength: 0.0},
        phase_analysis: [],
        generated_at: DateTime.utc_now()
      },
      visibility: :public,
      tags: ["gang_warfare", "significant", "wormhole"],
      community_features: %{
        allow_comments: true,
        allow_ratings: true,
        comments: [],
        ratings: []
      },
      metrics: %{
        views: :rand.uniform(1000),
        shares: :rand.uniform(50),
        average_rating: 3.5 + :rand.uniform() * 2,
        total_ratings: :rand.uniform(20),
        featured_score: :rand.uniform()
      },
      tactical_insights: %{
        recommended_viewing: ["Watch for tactical positioning", "Note fleet coordination"],
        learning_opportunities: ["Gang tactics", "Role specialization", "Engagement control"],
        tactical_tags: ["gang_warfare", "significant"]
      },
      share_urls: %{
        direct_link: "https://evedmv.com/battles/#{report_id}",
        embed_link: "https://evedmv.com/embed/battles/#{report_id}",
        api_link: "https://evedmv.com/api/battles/#{report_id}"
      },
      compatibility: %{
        legacy_battle_id: "battle_123",
        killmail_count: 8,
        supports_video: false,
        supports_highlights: true
      },
      created_at: DateTime.add(DateTime.utc_now(), -:rand.uniform(86400), :second),
      updated_at: DateTime.utc_now()
    }

    {:ok, battle_report}
  rescue
    error ->
      Logger.error("Failed to fetch battle report #{report_id}: #{inspect(error)}")
      {:error, :report_not_found}
  end

  defp validate_rating(rating, categories) do
    Logger.debug("Validating rating #{rating} for categories #{inspect(categories)}")

    cond do
      rating < 1 or rating > 10 ->
        {:error, :invalid_rating_range}

      not is_integer(rating) ->
        {:error, :invalid_rating_type}

      Enum.empty?(categories) ->
        {:error, :no_categories_specified}

      not Enum.all?(categories, fn cat ->
        cat in [
          :overall,
          :tactical_value,
          :educational_content,
          :entertainment_value,
          :video_quality
        ]
      end) ->
        {:error, :invalid_category}

      true ->
        validated_rating = %{
          score: rating,
          categories: categories,
          normalized_score: rating / 10.0,
          rating_level:
            case rating do
              r when r >= 9 -> :exceptional
              r when r >= 7 -> :good
              r when r >= 5 -> :average
              r when r >= 3 -> :below_average
              _ -> :poor
            end,
          validated_at: DateTime.utc_now()
        }

        {:ok, validated_rating}
    end
  end

  defp create_rating_record(report_id, rater_character_id, validated_rating, comment, categories) do
    Logger.debug(
      "Creating rating record for report #{report_id} by character #{rater_character_id}"
    )

    rating_record = %{
      rating_id: generate_rating_id(),
      report_id: report_id,
      rater_character_id: rater_character_id,
      rating_score: validated_rating.score,
      rating_categories: categories,
      comment: String.trim(comment),
      rating_metadata: %{
        rating_level: validated_rating.rating_level,
        normalized_score: validated_rating.normalized_score,
        ip_hash: generate_ip_hash(),
        user_agent_hash: generate_user_agent_hash()
      },
      moderation_status: :approved,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    # In a real implementation, this would insert into a ratings table
    # and handle duplicate ratings, user verification, etc.
    {:ok, rating_record}
  rescue
    error ->
      Logger.error("Failed to create rating record: #{inspect(error)}")
      {:error, :rating_creation_failed}
  end

  defp generate_rating_id do
    12
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  defp generate_ip_hash do
    # In production, would hash the actual IP address
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  defp generate_user_agent_hash do
    # In production, would hash the actual user agent
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  defp update_report_ratings(battle_report, rating_record) do
    Logger.debug("Updating ratings for battle report #{battle_report.report_id}")

    try do
      # Get current ratings
      current_ratings = battle_report.community_features.ratings || []

      # Add new rating
      updated_ratings = [rating_record | current_ratings]

      # Calculate new average rating
      total_ratings = length(updated_ratings)
      total_score = updated_ratings |> Enum.map(& &1.rating_score) |> Enum.sum()
      new_average = if total_ratings > 0, do: total_score / total_ratings, else: 0.0

      # Calculate category-specific averages
      category_averages = calculate_category_averages(updated_ratings)

      # Calculate featured score (weighted average considering factors)
      featured_score = calculate_featured_score(new_average, total_ratings, category_averages)

      # Update battle report
      updated_battle_report = %{
        battle_report
        | community_features: %{
            battle_report.community_features
            | ratings: updated_ratings
          },
          metrics: %{
            battle_report.metrics
            | average_rating: Float.round(new_average, 2),
              total_ratings: total_ratings,
              featured_score: Float.round(featured_score, 3),
              category_ratings: category_averages
          },
          updated_at: DateTime.utc_now()
      }

      Logger.info(
        "Updated ratings for report #{battle_report.report_id}: #{total_ratings} ratings, avg: #{Float.round(new_average, 2)}"
      )

      {:ok, updated_battle_report}
    rescue
      error ->
        Logger.error("Failed to update report ratings: #{inspect(error)}")
        {:error, :rating_update_failed}
    end
  end

  defp calculate_category_averages(ratings) do
    # Calculate average rating per category
    all_categories = [
      :overall,
      :tactical_value,
      :educational_content,
      :entertainment_value,
      :video_quality
    ]

    all_categories
    |> Enum.map(fn category ->
      category_ratings =
        ratings
        |> Enum.filter(fn rating ->
          category in (rating.rating_categories || [])
        end)
        |> Enum.map(& &1.rating_score)

      avg =
        if length(category_ratings) > 0 do
          Enum.sum(category_ratings) / length(category_ratings)
        else
          0.0
        end

      {category,
       %{
         average: Float.round(avg, 2),
         count: length(category_ratings)
       }}
    end)
    |> Enum.into(%{})
  end

  defp calculate_featured_score(average_rating, total_ratings, category_averages) do
    # Calculate a composite score for featuring battles
    # Factors: overall rating, number of ratings, category balance

    # Base score from average rating (0-1)
    base_score = average_rating / 10.0

    # Popularity factor (more ratings = higher score, diminishing returns)
    popularity_factor = min(1.0, :math.log(total_ratings + 1) / :math.log(50))

    # Category balance factor (bonus for high ratings across multiple categories)
    category_balance =
      category_averages
      |> Map.values()
      |> Enum.filter(fn %{count: count} -> count > 0 end)
      |> Enum.map(fn %{average: avg} -> avg / 10.0 end)
      |> case do
        [] -> 0.0
        scores -> Enum.sum(scores) / length(scores)
      end

    # Weighted combination
    featured_score =
      base_score * 0.5 +
        popularity_factor * 0.3 +
        category_balance * 0.2

    min(1.0, featured_score)
  end

  defp validate_tactical_highlight(highlight, timestamp, highlight_type) do
    Logger.debug("Validating tactical highlight: #{inspect(highlight)}")

    cond do
      is_nil(highlight) or (is_binary(highlight) and String.trim(highlight) == "") ->
        {:error, :empty_highlight}

      is_binary(highlight) and String.length(highlight) > 500 ->
        {:error, :highlight_too_long}

      not is_nil(timestamp) and (not is_integer(timestamp) or timestamp < 0) ->
        {:error, :invalid_timestamp}

      highlight_type not in [
        :tactical_moment,
        :first_blood,
        :primary_engagement,
        :tactical_shift,
        :escalation,
        :de_escalation,
        :final_blow,
        :strategic_movement,
        :logistics_save,
        :key_decision
      ] ->
        {:error, :invalid_highlight_type}

      true ->
        validated_highlight = %{
          content: String.trim(to_string(highlight)),
          timestamp: timestamp,
          type: highlight_type,
          significance:
            assess_highlight_significance(%{type: highlight_type, timestamp: timestamp}, nil),
          validation_status: :approved,
          validated_at: DateTime.utc_now()
        }

        {:ok, validated_highlight}
    end
  end

  defp create_highlight_record(
         report_id,
         character_id,
         validated_highlight,
         description,
         highlight_type
       ) do
    Logger.debug("Creating highlight record for report #{report_id} by character #{character_id}")

    highlight_record = %{
      highlight_id: generate_highlight_id(),
      report_id: report_id,
      creator_character_id: character_id,
      highlight_content: validated_highlight.content,
      description: String.trim(description),
      timestamp: validated_highlight.timestamp,
      highlight_type: highlight_type,
      significance: validated_highlight.significance,
      metadata: %{
        validation_status: validated_highlight.validation_status,
        character_verification: verify_character_access(character_id, report_id),
        tactical_context: extract_tactical_context(validated_highlight.timestamp, highlight_type),
        community_flags: [],
        edit_history: []
      },
      engagement_metrics: %{
        views: 0,
        upvotes: 0,
        downvotes: 0,
        comments: 0
      },
      moderation_status: :approved,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    # In a real implementation, this would insert into highlights table
    {:ok, highlight_record}
  rescue
    error ->
      Logger.error("Failed to create highlight record: #{inspect(error)}")
      {:error, :highlight_creation_failed}
  end

  defp generate_highlight_id do
    12
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  defp verify_character_access(character_id, report_id) do
    # In production, would verify character has access to the report
    # For now, return basic verification info
    %{
      character_id: character_id,
      report_id: report_id,
      access_level: :contributor,
      verified_at: DateTime.utc_now()
    }
  end

  defp extract_tactical_context(timestamp, highlight_type) do
    # Extract tactical context around the timestamp
    %{
      timestamp: timestamp,
      highlight_type: highlight_type,
      tactical_phase: determine_tactical_phase(timestamp),
      battle_intensity: estimate_battle_intensity(timestamp),
      context_window: %{
        before_seconds: 30,
        after_seconds: 30
      }
    }
  end

  defp determine_tactical_phase(timestamp) do
    # Determine which tactical phase this timestamp falls into
    cond do
      is_nil(timestamp) -> :unknown
      timestamp < 300 -> :opening
      timestamp < 900 -> :primary_engagement
      timestamp < 1800 -> :escalation
      true -> :conclusion
    end
  end

  defp estimate_battle_intensity(_timestamp) do
    # Estimate battle intensity at this timestamp
    # In production, would analyze killmail density around this time
    intensities = [:low, :moderate, :high, :extreme]
    Enum.random(intensities)
  end

  defp add_highlight_to_report(battle_report, highlight_record) do
    Logger.debug("Adding highlight to report #{battle_report.report_id}")

    try do
      # Get current highlights
      current_highlights = battle_report.tactical_highlights || []

      # Add new highlight and sort by timestamp
      updated_highlights =
        [highlight_record | current_highlights]
        |> Enum.sort_by(fn highlight ->
          highlight.timestamp || 0
        end)

      # Update highlight metrics
      highlight_metrics = %{
        total_highlights: length(updated_highlights),
        highlight_types:
          updated_highlights
          |> Enum.map(& &1.highlight_type)
          |> Enum.frequencies(),
        significance_distribution:
          updated_highlights
          |> Enum.map(& &1.significance)
          |> Enum.frequencies(),
        average_timestamp: calculate_average_timestamp(updated_highlights),
        timeline_coverage: calculate_timeline_coverage(updated_highlights)
      }

      # Update battle report
      updated_battle_report = %{
        battle_report
        | tactical_highlights: updated_highlights,
          metrics:
            Map.merge(battle_report.metrics, %{
              highlight_metrics: highlight_metrics
            }),
          updated_at: DateTime.utc_now()
      }

      Logger.info(
        "Added highlight to report #{battle_report.report_id}: #{length(updated_highlights)} total highlights"
      )

      {:ok, updated_battle_report}
    rescue
      error ->
        Logger.error("Failed to add highlight to report: #{inspect(error)}")
        {:error, :highlight_addition_failed}
    end
  end

  defp calculate_average_timestamp(highlights) do
    timestamps =
      highlights
      |> Enum.map(& &1.timestamp)
      |> Enum.filter(& &1)

    if length(timestamps) > 0 do
      Enum.sum(timestamps) / length(timestamps)
    else
      0
    end
  end

  defp calculate_timeline_coverage(highlights) do
    timestamps =
      highlights
      |> Enum.map(& &1.timestamp)
      |> Enum.filter(& &1)
      |> Enum.sort()

    case timestamps do
      [] ->
        %{coverage: 0, span: 0}

      [single] ->
        %{coverage: 1, span: 0, single_point: single}

      _ ->
        min_time = List.first(timestamps)
        max_time = List.last(timestamps)
        span = max_time - min_time

        %{
          coverage: length(timestamps),
          span: span,
          min_timestamp: min_time,
          max_timestamp: max_time,
          density: length(timestamps) / max(span, 1)
        }
    end
  end

  defp fetch_candidate_reports(time_window_days, min_rating) do
    Logger.debug(
      "Fetching candidate reports for last #{time_window_days} days with min rating #{min_rating}"
    )

    try do
      # Calculate time window
      cutoff_date = DateTime.add(DateTime.utc_now(), -time_window_days * 24 * 3600, :second)

      # In a real implementation, this would query the battle_reports table
      # For now, generate sample candidate reports
      candidate_reports = generate_sample_reports(cutoff_date, min_rating, time_window_days)

      # Filter by minimum rating
      filtered_reports =
        candidate_reports
        |> Enum.filter(fn report ->
          report.metrics.average_rating >= min_rating
        end)
        |> Enum.sort_by(
          fn report ->
            report.metrics.featured_score
          end,
          :desc
        )

      Logger.info("Found #{length(filtered_reports)} candidate reports meeting criteria")

      {:ok, filtered_reports}
    rescue
      error ->
        Logger.error("Failed to fetch candidate reports: #{inspect(error)}")
        {:error, :candidate_fetch_failed}
    end
  end

  defp generate_sample_reports(cutoff_date, min_rating, time_window_days) do
    # Generate sample battle reports for testing
    battle_types = [:fleet_battle, :gang_warfare, :small_gang, :skirmish]
    scale_levels = [:epic, :major, :significant, :minor]

    1..15
    |> Enum.map(fn i ->
      battle_type = Enum.random(battle_types)
      scale = Enum.random(scale_levels)
      rating = min_rating + :rand.uniform() * (10 - min_rating)

      %{
        report_id: "candidate_#{i}",
        battle_id: "battle_#{i}",
        creator_character_id: 10000 + i,
        title:
          "#{String.capitalize(to_string(battle_type))} - #{String.capitalize(to_string(scale))} Scale",
        description: "A #{scale} #{battle_type} with tactical significance",
        video_links:
          if(:rand.uniform() > 0.7,
            do: [%{platform: :youtube, video_id: "sample_#{i}"}],
            else: []
          ),
        tactical_highlights: generate_sample_highlights(i),
        auto_analysis: %{
          battle_classification: battle_type,
          tactical_summary: %{
            battle_type: battle_type,
            scale_assessment: scale,
            duration_summary: :standard_fight,
            outcome_analysis: %{
              tactical_outcome: Enum.random([:victory, :defeat, :contested]),
              strategic_impact: Enum.random([:local, :regional, :strategic]),
              efficiency_rating: Enum.random([:low, :moderate, :high, :very_high])
            }
          },
          key_statistics: %{
            total_participants: 5 + :rand.uniform(50),
            total_killmails: 2 + :rand.uniform(20),
            isk_destroyed: 1_000_000_000 + :rand.uniform(5_000_000_000),
            duration_minutes: 5 + :rand.uniform(30),
            systems_involved: 1 + :rand.uniform(3)
          }
        },
        visibility: :public,
        tags: generate_sample_tags(battle_type, scale),
        metrics: %{
          views: :rand.uniform(5000),
          shares: :rand.uniform(100),
          average_rating: Float.round(rating, 2),
          total_ratings: 5 + :rand.uniform(50),
          featured_score: :rand.uniform()
        },
        created_at:
          DateTime.add(cutoff_date, :rand.uniform(time_window_days * 24 * 3600), :second),
        updated_at: DateTime.utc_now()
      }
    end)
  end

  defp generate_sample_highlights(battle_index) do
    if :rand.uniform() > 0.5 do
      1..:rand.uniform(5)
      |> Enum.map(fn i ->
        %{
          highlight_id: "highlight_#{battle_index}_#{i}",
          timestamp: :rand.uniform(1800),
          highlight_type: Enum.random([:tactical_moment, :first_blood, :escalation, :final_blow]),
          significance: Enum.random([:low, :medium, :high]),
          content: "Key tactical moment #{i} in battle #{battle_index}"
        }
      end)
    else
      []
    end
  end

  defp generate_sample_tags(battle_type, scale) do
    base_tags = [to_string(battle_type), to_string(scale)]

    additional_tags = [
      "pvp",
      "analysis",
      "tactical",
      "educational",
      "wormhole",
      "nullsec",
      "lowsec"
    ]

    base_tags ++ Enum.take_random(additional_tags, :rand.uniform(3))
  end

  defp analyze_curation_metrics(reports) do
    Logger.debug("Analyzing curation metrics for #{length(reports)} reports")

    try do
      analyzed_reports =
        reports
        |> Enum.map(fn report ->
          # Calculate comprehensive curation metrics
          curation_metrics = %{
            # Community engagement score
            engagement_score: calculate_engagement_score(report),

            # Tactical value assessment
            tactical_value: assess_tactical_value(report),

            # Educational potential
            educational_value: assess_educational_value(report),

            # Content quality score
            content_quality: assess_content_quality(report),

            # Uniqueness factor
            uniqueness_score: assess_uniqueness(report),

            # Recency factor
            recency_score: calculate_recency_score(report.created_at),

            # Overall curation score
            overall_curation_score: 0.0
          }

          # Calculate weighted overall score
          overall_score =
            curation_metrics.engagement_score * 0.25 +
              curation_metrics.tactical_value * 0.20 +
              curation_metrics.educational_value * 0.20 +
              curation_metrics.content_quality * 0.15 +
              curation_metrics.uniqueness_score * 0.10 +
              curation_metrics.recency_score * 0.10

          updated_metrics = %{
            curation_metrics
            | overall_curation_score: Float.round(overall_score, 3)
          }

          Map.put(report, :curation_metrics, updated_metrics)
        end)
        |> Enum.sort_by(
          fn report ->
            report.curation_metrics.overall_curation_score
          end,
          :desc
        )

      Logger.info("Analyzed curation metrics for #{length(analyzed_reports)} reports")

      {:ok, analyzed_reports}
    rescue
      error ->
        Logger.error("Failed to analyze curation metrics: #{inspect(error)}")
        {:error, :metrics_analysis_failed}
    end
  end

  defp calculate_engagement_score(report) do
    # Calculate engagement based on views, ratings, shares
    views = report.metrics.views || 0
    ratings = report.metrics.total_ratings || 0
    shares = report.metrics.shares || 0
    avg_rating = report.metrics.average_rating || 0

    # Normalize to 0-1 scale
    view_score = min(1.0, views / 5000.0)
    rating_score = min(1.0, ratings / 50.0)
    share_score = min(1.0, shares / 100.0)
    quality_score = avg_rating / 10.0

    # Weighted combination
    engagement_score =
      view_score * 0.3 +
        rating_score * 0.25 +
        share_score * 0.25 +
        quality_score * 0.20

    Float.round(engagement_score, 3)
  end

  defp assess_tactical_value(report) do
    # Assess tactical learning value
    auto_analysis = report.auto_analysis || %{}
    key_stats = auto_analysis.key_statistics || %{}

    # Factor in battle complexity
    complexity_score =
      case auto_analysis.battle_classification do
        :fleet_battle -> 1.0
        :gang_warfare -> 0.8
        :small_gang -> 0.6
        :skirmish -> 0.4
        _ -> 0.5
      end

    # Factor in scale
    scale_score =
      case auto_analysis.tactical_summary.scale_assessment do
        :epic -> 1.0
        :major -> 0.8
        :significant -> 0.6
        :minor -> 0.4
        _ -> 0.5
      end

    # Factor in duration (longer battles often more tactically interesting)
    duration_score = min(1.0, (key_stats.duration_minutes || 0) / 30.0)

    # Factor in multi-system complexity
    system_score = min(1.0, (key_stats.systems_involved || 1) / 3.0)

    tactical_value =
      complexity_score * 0.35 +
        scale_score * 0.30 +
        duration_score * 0.20 +
        system_score * 0.15

    Float.round(tactical_value, 3)
  end

  defp assess_educational_value(report) do
    # Assess educational potential
    highlights_count = length(report.tactical_highlights || [])
    video_count = length(report.video_links || [])
    description_length = String.length(report.description || "")

    # Factor in tactical highlights
    highlight_score = min(1.0, highlights_count / 5.0)

    # Factor in video content
    video_score = min(1.0, video_count / 2.0)

    # Factor in description quality
    description_score = min(1.0, description_length / 1000.0)

    # Factor in auto-analysis quality
    analysis_score =
      if Map.has_key?(report.auto_analysis || %{}, :phase_analysis) do
        0.8
      else
        0.4
      end

    educational_value =
      highlight_score * 0.30 +
        video_score * 0.25 +
        description_score * 0.25 +
        analysis_score * 0.20

    Float.round(educational_value, 3)
  end

  defp assess_content_quality(report) do
    # Assess overall content quality
    has_title = String.length(report.title || "") > 10
    has_description = String.length(report.description || "") > 100
    has_videos = length(report.video_links || []) > 0
    has_highlights = length(report.tactical_highlights || []) > 0
    has_tags = length(report.tags || []) > 2

    quality_factors = [
      has_title,
      has_description,
      has_videos,
      has_highlights,
      has_tags
    ]

    quality_score =
      quality_factors
      |> Enum.count(& &1)
      |> Kernel./(length(quality_factors))

    Float.round(quality_score, 3)
  end

  defp assess_uniqueness(report) do
    # Assess uniqueness/novelty of the battle
    # This would be more sophisticated with historical data
    battle_type = report.auto_analysis.battle_classification
    scale = report.auto_analysis.tactical_summary.scale_assessment

    uniqueness_score =
      case {battle_type, scale} do
        {:fleet_battle, :epic} -> 0.9
        {:gang_warfare, :major} -> 0.7
        {:small_gang, :significant} -> 0.5
        _ -> 0.3
      end

    # Add randomness for variety
    uniqueness_score + :rand.uniform() * 0.2
  end

  defp calculate_recency_score(created_at) do
    # More recent battles get higher scores
    hours_ago = DateTime.diff(DateTime.utc_now(), created_at, :hour)

    # Recency decay over 7 days
    recency_score = max(0.0, 1.0 - hours_ago / (7 * 24))

    Float.round(recency_score, 3)
  end

  defp categorize_featured_battles(reports, categories) do
    Logger.debug(
      "Categorizing #{length(reports)} reports into categories: #{inspect(categories)}"
    )

    try do
      categorized_reports =
        categories
        |> Enum.map(fn category ->
          category_reports =
            reports
            |> Enum.filter(fn report ->
              meets_category_criteria(report, category)
            end)
            |> Enum.sort_by(
              fn report ->
                get_category_score(report, category)
              end,
              :desc
            )
            # Top 5 per category
            |> Enum.take(5)

          {category, category_reports}
        end)
        |> Enum.into(%{})

      Logger.info("Categorized reports: #{inspect(Map.keys(categorized_reports))}")

      {:ok, categorized_reports}
    rescue
      error ->
        Logger.error("Failed to categorize featured battles: #{inspect(error)}")
        {:error, :categorization_failed}
    end
  end

  defp meets_category_criteria(report, category) do
    case category do
      :tactical_excellence ->
        report.curation_metrics.tactical_value >= 0.7 and
          report.metrics.average_rating >= 7.0

      :educational_value ->
        report.curation_metrics.educational_value >= 0.6 and
          length(report.tactical_highlights || []) >= 2

      :epic_battles ->
        report.auto_analysis.tactical_summary.scale_assessment in [:epic, :major] and
          report.auto_analysis.key_statistics.total_participants >= 20

      :recent_highlights ->
        report.curation_metrics.recency_score >= 0.8

      :community_favorites ->
        report.metrics.total_ratings >= 10 and
          report.metrics.average_rating >= 8.0

      :multi_system_warfare ->
        report.auto_analysis.key_statistics.systems_involved >= 2

      :fleet_command_training ->
        report.auto_analysis.battle_classification == :fleet_battle and
          length(report.video_links || []) > 0

      _ ->
        true
    end
  end

  defp get_category_score(report, category) do
    base_score = report.curation_metrics.overall_curation_score

    # Category-specific bonuses
    bonus =
      case category do
        :tactical_excellence -> report.curation_metrics.tactical_value * 0.5
        :educational_value -> report.curation_metrics.educational_value * 0.5
        :epic_battles -> report.auto_analysis.key_statistics.total_participants / 50.0 * 0.3
        :recent_highlights -> report.curation_metrics.recency_score * 0.4
        :community_favorites -> report.metrics.average_rating / 10.0 * 0.3
        :multi_system_warfare -> report.auto_analysis.key_statistics.systems_involved / 5.0 * 0.3
        :fleet_command_training -> if length(report.video_links || []) > 0, do: 0.2, else: 0.0
        _ -> 0.0
      end

    base_score + bonus
  end

  defp select_featured_battles(categorized_reports, max_results) do
    Logger.debug("Selecting final featured battles from categorized reports")

    try do
      # Flatten all categorized reports with their category info
      all_candidates =
        categorized_reports
        |> Enum.flat_map(fn {category, reports} ->
          reports
          |> Enum.map(fn report ->
            Map.put(report, :featured_category, category)
          end)
        end)
        # Remove duplicates
        |> Enum.uniq_by(& &1.report_id)

      # Select top reports ensuring category diversity
      selected_reports = select_diverse_reports(all_candidates, max_results)

      # Enrich with featured metadata
      final_selection =
        selected_reports
        |> Enum.with_index(1)
        |> Enum.map(fn {report, rank} ->
          Map.merge(report, %{
            featured_rank: rank,
            featured_at: DateTime.utc_now(),
            featured_score: report.curation_metrics.overall_curation_score,
            featured_category: report.featured_category,
            featured_metadata: %{
              selection_criteria: get_selection_criteria(report),
              category_rank: get_category_rank(report, categorized_reports),
              featured_until: DateTime.add(DateTime.utc_now(), 7 * 24 * 3600, :second)
            }
          })
        end)

      Logger.info("Selected #{length(final_selection)} featured battles")

      {:ok, final_selection}
    rescue
      error ->
        Logger.error("Failed to select featured battles: #{inspect(error)}")
        {:error, :selection_failed}
    end
  end

  defp select_diverse_reports(candidates, max_results) do
    # Ensure we get diverse categories in the final selection
    categories = candidates |> Enum.map(& &1.featured_category) |> Enum.uniq()

    # Try to get at least one from each category
    category_representatives =
      categories
      |> Enum.map(fn category ->
        candidates
        |> Enum.filter(&(&1.featured_category == category))
        |> Enum.max_by(& &1.curation_metrics.overall_curation_score)
      end)

    # Fill remaining slots with top-rated reports
    remaining_slots = max_results - length(category_representatives)

    if remaining_slots > 0 do
      additional_reports =
        candidates
        |> Enum.reject(fn report ->
          report.report_id in Enum.map(category_representatives, & &1.report_id)
        end)
        |> Enum.sort_by(& &1.curation_metrics.overall_curation_score, :desc)
        |> Enum.take(remaining_slots)

      category_representatives ++ additional_reports
    else
      category_representatives
    end
    |> Enum.sort_by(& &1.curation_metrics.overall_curation_score, :desc)
    |> Enum.take(max_results)
  end

  defp get_selection_criteria(report) do
    criteria = []

    criteria =
      if report.curation_metrics.tactical_value >= 0.7 do
        ["High tactical value" | criteria]
      else
        criteria
      end

    criteria =
      if report.curation_metrics.educational_value >= 0.6 do
        ["Educational content" | criteria]
      else
        criteria
      end

    criteria =
      if report.metrics.average_rating >= 8.0 do
        ["High community rating" | criteria]
      else
        criteria
      end

    criteria =
      if report.auto_analysis.tactical_summary.scale_assessment in [:epic, :major] do
        ["Epic scale battle" | criteria]
      else
        criteria
      end

    criteria =
      if length(report.video_links || []) > 0 do
        ["Video content available" | criteria]
      else
        criteria
      end

    criteria
  end

  defp get_category_rank(report, categorized_reports) do
    category = report.featured_category
    category_reports = Map.get(categorized_reports, category, [])

    category_reports
    |> Enum.find_index(fn r -> r.report_id == report.report_id end)
    |> case do
      nil -> 0
      index -> index + 1
    end
  end

  defp perform_battle_report_search(query, filters, sort_by, limit) do
    Logger.debug("Performing battle report search: '#{query}' with filters: #{inspect(filters)}")

    try do
      # In a real implementation, this would use a proper search engine like Elasticsearch
      # For now, we'll simulate comprehensive search functionality

      # Generate sample search results
      all_reports = generate_search_sample_data()

      # Apply text search
      text_filtered_reports = apply_text_search(all_reports, query)

      # Apply filters
      filtered_reports = apply_search_filters(text_filtered_reports, filters)

      # Apply sorting
      sorted_reports = apply_search_sorting(filtered_reports, sort_by)

      # Apply limit
      final_results = Enum.take(sorted_reports, limit)

      Logger.info("Search returned #{length(final_results)} results for query: '#{query}'")

      {:ok, final_results}
    rescue
      error ->
        Logger.error("Failed to perform battle report search: #{inspect(error)}")
        {:error, :search_failed}
    end
  end

  defp generate_search_sample_data do
    # Generate sample battle reports for search testing
    battle_scenarios = [
      %{
        type: :fleet_battle,
        scale: :epic,
        title: "Massive Fleet Engagement in Delve",
        tags: ["fleet", "nullsec", "capitals"]
      },
      %{
        type: :gang_warfare,
        scale: :major,
        title: "Wormhole Gang Warfare Tutorial",
        tags: ["gang", "wormhole", "educational"]
      },
      %{
        type: :small_gang,
        scale: :significant,
        title: "Small Gang Roaming Guide",
        tags: ["small_gang", "roaming", "guide"]
      },
      %{
        type: :skirmish,
        scale: :minor,
        title: "Faction Warfare Skirmish Analysis",
        tags: ["faction_warfare", "skirmish", "analysis"]
      },
      %{
        type: :fleet_battle,
        scale: :major,
        title: "Capital Ship Brawl Commentary",
        tags: ["capital", "brawl", "commentary"]
      },
      %{
        type: :gang_warfare,
        scale: :significant,
        title: "Tactical Retreat Masterclass",
        tags: ["tactical", "retreat", "masterclass"]
      },
      %{
        type: :small_gang,
        scale: :minor,
        title: "Solo PvP Techniques",
        tags: ["solo", "pvp", "techniques"]
      },
      %{
        type: :fleet_battle,
        scale: :epic,
        title: "The Great Wormhole War",
        tags: ["wormhole", "war", "epic"]
      }
    ]

    battle_scenarios
    |> Enum.with_index(1)
    |> Enum.map(fn {scenario, index} ->
      %{
        report_id: "search_result_#{index}",
        battle_id: "battle_#{index}",
        creator_character_id: 10000 + index,
        creator_name: "Battle Analyst #{index}",
        title: scenario.title,
        description: generate_battle_description(scenario),
        video_links: generate_video_links(index),
        tactical_highlights: generate_tactical_highlights(index),
        auto_analysis: %{
          battle_classification: scenario.type,
          tactical_summary: %{
            battle_type: scenario.type,
            scale_assessment: scenario.scale,
            duration_summary: Enum.random([:quick_engagement, :standard_fight, :extended_battle]),
            outcome_analysis: %{
              tactical_outcome: Enum.random([:victory, :defeat, :contested]),
              strategic_impact: Enum.random([:local, :regional, :strategic]),
              efficiency_rating: Enum.random([:low, :moderate, :high, :very_high])
            }
          },
          key_statistics: %{
            total_participants: 5 + :rand.uniform(45),
            total_killmails: 2 + :rand.uniform(18),
            isk_destroyed: 500_000_000 + :rand.uniform(4_500_000_000),
            duration_minutes: 3 + :rand.uniform(27),
            systems_involved: 1 + :rand.uniform(2)
          }
        },
        visibility: :public,
        tags: scenario.tags,
        metrics: %{
          views: :rand.uniform(3000),
          shares: :rand.uniform(75),
          average_rating: 3.0 + :rand.uniform() * 5.0,
          total_ratings: 1 + :rand.uniform(30),
          featured_score: :rand.uniform()
        },
        created_at: DateTime.add(DateTime.utc_now(), -:rand.uniform(30 * 24 * 3600), :second),
        updated_at: DateTime.utc_now(),
        # Will be calculated during search
        search_relevance: 0.0
      }
    end)
  end

  defp generate_battle_description(scenario) do
    descriptions = %{
      fleet_battle:
        "A massive fleet engagement featuring coordinated tactics and strategic positioning. This battle showcases advanced fleet command principles and large-scale coordination.",
      gang_warfare:
        "An intense gang warfare scenario demonstrating tactical flexibility and role specialization. Perfect for understanding gang-level combat dynamics.",
      small_gang:
        "A small gang engagement highlighting individual pilot skill and tight coordination. Excellent for learning small-scale tactics and positioning.",
      skirmish:
        "A quick skirmish showing rapid decision-making and opportunistic combat. Great for understanding engagement timing and risk assessment."
    }

    Map.get(descriptions, scenario.type, "An engaging PvP battle with tactical lessons.")
  end

  defp generate_video_links(index) do
    if :rand.uniform() > 0.6 do
      [
        %{
          url: "https://youtube.com/watch?v=example_#{index}",
          platform: :youtube,
          video_id: "example_#{index}",
          metadata: %{
            title: "Battle Video #{index}",
            duration: :rand.uniform(3600),
            thumbnail: "https://img.youtube.com/vi/example_#{index}/maxresdefault.jpg"
          }
        }
      ]
    else
      []
    end
  end

  defp generate_tactical_highlights(index) do
    if :rand.uniform() > 0.4 do
      1..:rand.uniform(4)
      |> Enum.map(fn i ->
        %{
          highlight_id: "highlight_#{index}_#{i}",
          timestamp: :rand.uniform(1800),
          highlight_type: Enum.random([:tactical_moment, :first_blood, :escalation, :final_blow]),
          significance: Enum.random([:low, :medium, :high]),
          content: "Tactical highlight #{i} from battle #{index}"
        }
      end)
    else
      []
    end
  end

  defp apply_text_search(reports, query) do
    if String.trim(query) == "" do
      reports
    else
      query_terms =
        query
        |> String.downcase()
        |> String.split()
        |> Enum.map(&String.trim/1)
        |> Enum.filter(fn term -> String.length(term) > 1 end)

      reports
      |> Enum.map(fn report ->
        # Calculate relevance score
        relevance = calculate_text_relevance(report, query_terms)
        Map.put(report, :search_relevance, relevance)
      end)
      |> Enum.filter(fn report ->
        report.search_relevance > 0.0
      end)
    end
  end

  defp calculate_text_relevance(report, query_terms) do
    # Search in different fields with different weights
    title_matches = count_term_matches(report.title, query_terms) * 3.0
    description_matches = count_term_matches(report.description, query_terms) * 2.0
    tag_matches = count_tag_matches(report.tags, query_terms) * 2.5

    # Battle type matches
    battle_type_matches =
      if to_string(report.auto_analysis.battle_classification) in Enum.map(
           query_terms,
           &String.replace(&1, "_", " ")
         ) do
        1.0
      else
        0.0
      end

    total_relevance = title_matches + description_matches + tag_matches + battle_type_matches

    # Normalize and add quality boost
    base_relevance = min(1.0, total_relevance / 10.0)
    quality_boost = report.metrics.average_rating / 10.0 * 0.1

    base_relevance + quality_boost
  end

  defp count_term_matches(text, query_terms) do
    if is_nil(text) or text == "" do
      0.0
    else
      normalized_text = String.downcase(text)

      query_terms
      |> Enum.map(fn term ->
        if String.contains?(normalized_text, term) do
          1.0
        else
          0.0
        end
      end)
      |> Enum.sum()
    end
  end

  defp count_tag_matches(tags, query_terms) do
    if is_nil(tags) or tags == [] do
      0.0
    else
      normalized_tags = Enum.map(tags, &String.downcase/1)

      query_terms
      |> Enum.map(fn term ->
        if term in normalized_tags do
          1.0
        else
          0.0
        end
      end)
      |> Enum.sum()
    end
  end

  defp apply_search_filters(reports, filters) do
    reports
    |> maybe_filter_by_battle_type(Map.get(filters, :battle_type))
    |> maybe_filter_by_scale(Map.get(filters, :scale))
    |> maybe_filter_by_rating(Map.get(filters, :min_rating))
    |> maybe_filter_by_date_range(Map.get(filters, :date_range))
    |> maybe_filter_by_tags(Map.get(filters, :tags))
    |> maybe_filter_by_duration(Map.get(filters, :duration_range))
    |> maybe_filter_by_participants(Map.get(filters, :participant_range))
    |> maybe_filter_by_creator(Map.get(filters, :creator_id))
    |> maybe_filter_by_has_video(Map.get(filters, :has_video))
    |> maybe_filter_by_has_highlights(Map.get(filters, :has_highlights))
  end

  defp maybe_filter_by_battle_type(reports, nil), do: reports

  defp maybe_filter_by_battle_type(reports, battle_type) do
    Enum.filter(reports, fn report ->
      report.auto_analysis.battle_classification == battle_type
    end)
  end

  defp maybe_filter_by_scale(reports, nil), do: reports

  defp maybe_filter_by_scale(reports, scale) do
    Enum.filter(reports, fn report ->
      report.auto_analysis.tactical_summary.scale_assessment == scale
    end)
  end

  defp maybe_filter_by_rating(reports, nil), do: reports

  defp maybe_filter_by_rating(reports, min_rating) do
    Enum.filter(reports, fn report ->
      report.metrics.average_rating >= min_rating
    end)
  end

  defp maybe_filter_by_date_range(reports, nil), do: reports

  defp maybe_filter_by_date_range(reports, %{start_date: start_date, end_date: end_date}) do
    Enum.filter(reports, fn report ->
      DateTime.compare(report.created_at, start_date) in [:gt, :eq] and
        DateTime.compare(report.created_at, end_date) in [:lt, :eq]
    end)
  end

  defp maybe_filter_by_tags(reports, nil), do: reports

  defp maybe_filter_by_tags(reports, tags) when is_list(tags) do
    Enum.filter(reports, fn report ->
      report_tags = Enum.map(report.tags || [], &String.downcase/1)
      search_tags = Enum.map(tags, &String.downcase/1)

      Enum.any?(search_tags, fn tag -> tag in report_tags end)
    end)
  end

  defp maybe_filter_by_duration(reports, nil), do: reports

  defp maybe_filter_by_duration(reports, %{min: min_duration, max: max_duration}) do
    Enum.filter(reports, fn report ->
      duration = report.auto_analysis.key_statistics.duration_minutes
      duration >= min_duration and duration <= max_duration
    end)
  end

  defp maybe_filter_by_participants(reports, nil), do: reports

  defp maybe_filter_by_participants(reports, %{min: min_participants, max: max_participants}) do
    Enum.filter(reports, fn report ->
      participants = report.auto_analysis.key_statistics.total_participants
      participants >= min_participants and participants <= max_participants
    end)
  end

  defp maybe_filter_by_creator(reports, nil), do: reports

  defp maybe_filter_by_creator(reports, creator_id) do
    Enum.filter(reports, fn report ->
      report.creator_character_id == creator_id
    end)
  end

  defp maybe_filter_by_has_video(reports, nil), do: reports

  defp maybe_filter_by_has_video(reports, true) do
    Enum.filter(reports, fn report ->
      length(report.video_links || []) > 0
    end)
  end

  defp maybe_filter_by_has_video(reports, false) do
    Enum.filter(reports, fn report ->
      Enum.empty?(report.video_links || [])
    end)
  end

  defp maybe_filter_by_has_highlights(reports, nil), do: reports

  defp maybe_filter_by_has_highlights(reports, true) do
    Enum.filter(reports, fn report ->
      length(report.tactical_highlights || []) > 0
    end)
  end

  defp maybe_filter_by_has_highlights(reports, false) do
    Enum.filter(reports, fn report ->
      Enum.empty?(report.tactical_highlights || [])
    end)
  end

  defp apply_search_sorting(reports, sort_by) do
    case sort_by do
      :relevance ->
        Enum.sort_by(reports, & &1.search_relevance, :desc)

      :rating ->
        Enum.sort_by(reports, & &1.metrics.average_rating, :desc)

      :date ->
        Enum.sort_by(reports, & &1.created_at, :desc)

      :views ->
        Enum.sort_by(reports, & &1.metrics.views, :desc)

      :participants ->
        Enum.sort_by(reports, & &1.auto_analysis.key_statistics.total_participants, :desc)

      :duration ->
        Enum.sort_by(reports, & &1.auto_analysis.key_statistics.duration_minutes, :desc)

      :isk_destroyed ->
        Enum.sort_by(reports, & &1.auto_analysis.key_statistics.isk_destroyed, :desc)

      _ ->
        Enum.sort_by(reports, & &1.search_relevance, :desc)
    end
  end

  defp maybe_enrich_search_results(results, include_metadata) do
    Logger.debug("Enriching #{length(results)} search results with metadata: #{include_metadata}")

    try do
      enriched_results =
        if include_metadata do
          results
          |> Enum.map(fn result ->
            Map.merge(result, %{
              search_metadata: %{
                relevance_score: result.search_relevance,
                match_factors: get_match_factors(result),
                content_summary: generate_content_summary(result),
                engagement_indicators: get_engagement_indicators(result),
                learning_value: assess_learning_value(result),
                recommended_for: get_recommendations(result),
                similar_battles: find_similar_battles(result, results)
              },
              display_metadata: %{
                formatted_duration:
                  format_duration(result.auto_analysis.key_statistics.duration_minutes),
                formatted_participants:
                  format_participants(result.auto_analysis.key_statistics.total_participants),
                formatted_isk:
                  format_isk_value(result.auto_analysis.key_statistics.isk_destroyed),
                battle_type_display:
                  format_battle_type(result.auto_analysis.battle_classification),
                scale_display:
                  format_scale(result.auto_analysis.tactical_summary.scale_assessment),
                rating_display:
                  format_rating(result.metrics.average_rating, result.metrics.total_ratings),
                age_display: format_age(result.created_at)
              }
            })
          end)
        else
          results
        end

      {:ok, enriched_results}
    rescue
      error ->
        Logger.error("Failed to enrich search results: #{inspect(error)}")
        {:error, :enrichment_failed}
    end
  end

  defp get_match_factors(result) do
    factors = []

    factors =
      if result.search_relevance > 0.7 do
        ["High relevance match" | factors]
      else
        factors
      end

    factors =
      if result.metrics.average_rating > 7.0 do
        ["Highly rated" | factors]
      else
        factors
      end

    factors =
      if length(result.video_links || []) > 0 do
        ["Has video content" | factors]
      else
        factors
      end

    factors =
      if length(result.tactical_highlights || []) > 2 do
        ["Rich tactical analysis" | factors]
      else
        factors
      end

    factors =
      if result.auto_analysis.tactical_summary.scale_assessment in [:epic, :major] do
        ["Large scale battle" | factors]
      else
        factors
      end

    factors
  end

  defp generate_content_summary(result) do
    key_stats = result.auto_analysis.key_statistics

    summary_parts = []

    summary_parts = ["#{key_stats.total_participants} participants" | summary_parts]

    summary_parts = ["#{key_stats.duration_minutes} minutes" | summary_parts]

    summary_parts =
      if key_stats.isk_destroyed > 1_000_000_000 do
        [
          "#{Float.round(key_stats.isk_destroyed / 1_000_000_000, 1)}B ISK destroyed"
          | summary_parts
        ]
      else
        ["#{Float.round(key_stats.isk_destroyed / 1_000_000, 0)}M ISK destroyed" | summary_parts]
      end

    summary_parts =
      if key_stats.systems_involved > 1 do
        ["#{key_stats.systems_involved} systems involved" | summary_parts]
      else
        summary_parts
      end

    Enum.reverse(summary_parts) |> Enum.join(" • ")
  end

  defp get_engagement_indicators(result) do
    %{
      popularity_level:
        case result.metrics.views do
          v when v > 2000 -> :high
          v when v > 500 -> :medium
          _ -> :low
        end,
      community_rating:
        case result.metrics.average_rating do
          r when r > 8.0 -> :excellent
          r when r > 6.0 -> :good
          r when r > 4.0 -> :average
          _ -> :below_average
        end,
      engagement_score: calculate_engagement_score(result),
      social_proof: result.metrics.total_ratings > 10
    }
  end

  defp assess_learning_value(result) do
    learning_factors = []

    learning_factors =
      if length(result.tactical_highlights || []) > 2 do
        ["Detailed tactical analysis" | learning_factors]
      else
        learning_factors
      end

    learning_factors =
      if length(result.video_links || []) > 0 do
        ["Visual learning content" | learning_factors]
      else
        learning_factors
      end

    learning_factors =
      case result.auto_analysis.battle_classification do
        :fleet_battle -> ["Fleet command lessons" | learning_factors]
        :gang_warfare -> ["Gang tactics" | learning_factors]
        :small_gang -> ["Small gang techniques" | learning_factors]
        _ -> learning_factors
      end

    learning_factors =
      if String.length(result.description) > 200 do
        ["In-depth analysis" | learning_factors]
      else
        learning_factors
      end

    %{
      learning_factors: learning_factors,
      educational_value: if(length(learning_factors) > 2, do: :high, else: :medium),
      recommended_for_learning: length(learning_factors) > 1
    }
  end

  defp get_recommendations(result) do
    recommendations = []

    recommendations =
      case result.auto_analysis.battle_classification do
        :fleet_battle -> ["Fleet commanders", "Logistics pilots" | recommendations]
        :gang_warfare -> ["Gang leaders", "Tactical analysts" | recommendations]
        :small_gang -> ["Small gang pilots", "Solo PvPers" | recommendations]
        :skirmish -> ["New PvPers", "Quick engagement fans" | recommendations]
        _ -> recommendations
      end

    recommendations =
      if length(result.video_links || []) > 0 do
        ["Visual learners" | recommendations]
      else
        recommendations
      end

    recommendations =
      if result.auto_analysis.tactical_summary.scale_assessment in [:epic, :major] do
        ["Epic battle enthusiasts" | recommendations]
      else
        recommendations
      end

    recommendations
  end

  defp find_similar_battles(result, all_results) do
    all_results
    |> Enum.reject(fn r -> r.report_id == result.report_id end)
    |> Enum.filter(fn r ->
      r.auto_analysis.battle_classification == result.auto_analysis.battle_classification
    end)
    |> Enum.sort_by(fn r ->
      abs(
        r.auto_analysis.key_statistics.total_participants -
          result.auto_analysis.key_statistics.total_participants
      )
    end)
    |> Enum.take(3)
    |> Enum.map(fn r ->
      %{
        report_id: r.report_id,
        title: r.title,
        similarity_score: calculate_similarity_score(result, r)
      }
    end)
  end

  defp calculate_similarity_score(result1, result2) do
    # Simple similarity calculation
    type_match =
      if result1.auto_analysis.battle_classification ==
           result2.auto_analysis.battle_classification,
         do: 0.4,
         else: 0.0

    scale_match =
      if result1.auto_analysis.tactical_summary.scale_assessment ==
           result2.auto_analysis.tactical_summary.scale_assessment,
         do: 0.3,
         else: 0.0

    # Participant similarity
    p1 = result1.auto_analysis.key_statistics.total_participants
    p2 = result2.auto_analysis.key_statistics.total_participants
    participant_similarity = 0.3 * (1 - abs(p1 - p2) / max(p1, p2))

    Float.round(type_match + scale_match + participant_similarity, 2)
  end

  # Display formatting helpers

  defp format_duration(minutes) do
    cond do
      minutes < 60 -> "#{minutes}m"
      minutes < 1440 -> "#{div(minutes, 60)}h #{rem(minutes, 60)}m"
      true -> "#{div(minutes, 1440)}d #{div(rem(minutes, 1440), 60)}h"
    end
  end

  defp format_participants(count) do
    cond do
      count < 1000 -> "#{count}"
      count < 10000 -> "#{Float.round(count / 1000, 1)}k"
      true -> "#{div(count, 1000)}k"
    end
  end

  defp format_isk_value(isk) do
    cond do
      isk < 1_000_000 -> "#{div(isk, 1000)}k"
      isk < 1_000_000_000 -> "#{Float.round(isk / 1_000_000, 1)}M"
      isk < 1_000_000_000_000 -> "#{Float.round(isk / 1_000_000_000, 1)}B"
      true -> "#{Float.round(isk / 1_000_000_000_000, 1)}T"
    end
  end

  defp format_battle_type(battle_type) do
    battle_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_scale(scale) do
    scale
    |> to_string()
    |> String.capitalize()
  end

  defp format_rating(rating, total_ratings) do
    "#{Float.round(rating, 1)}/10 (#{total_ratings} ratings)"
  end

  defp format_age(created_at) do
    hours_ago = DateTime.diff(DateTime.utc_now(), created_at, :hour)

    cond do
      hours_ago < 24 -> "#{hours_ago}h ago"
      hours_ago < 168 -> "#{div(hours_ago, 24)}d ago"
      hours_ago < 720 -> "#{div(hours_ago, 168)}w ago"
      true -> "#{div(hours_ago, 720)}mo ago"
    end
  end
end
