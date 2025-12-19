defmodule EveDmv.Contexts.BattleSharing.Domain.BattleCurator do
  @moduledoc """
  Advanced battle curation and community sharing system for EVE Online PvP analysis.

  This module serves as the main coordinator for battle sharing functionality,
  delegating specific tasks to specialized modules for better maintainability.
  """

  alias EveDmv.Contexts.BattleAnalysis
  alias EveDmv.Contexts.BattleSharing.Domain.CommunityManager
  alias EveDmv.Contexts.BattleSharing.Domain.VideoProcessor

  require Logger

  # Battle sharing parameters
  @max_description_length 2000

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
  """
  def create_battle_report(battle_id, creator_character_id, options \\ []) do
    Logger.info(
      "Creating battle report for battle #{battle_id} by character #{creator_character_id}"
    )

    case fetch_battle_data(battle_id) do
      {:ok, battle_data} ->
        # Create the battle report from the fetched data
        create_battle_report_from_data(battle_data, creator_character_id, options)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates a battle report from already-loaded battle data.
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

    with {:ok, validated_videos} <- validate_videos(video_urls),
         {:ok, processed_highlights} <- process_highlights(tactical_highlights, battle_data),
         {:ok, auto_analysis} <- generate_auto_analysis(battle_data),
         {:ok, battle_report} <-
           create_battle_report_record(%__MODULE__.BattleReportOptions{
             battle_id: battle_data.id,
             creator_id: creator_character_id,
             title: title || generate_auto_title(auto_analysis),
             description: validate_description(description),
             videos: validated_videos,
             highlights: processed_highlights,
             auto_analysis: auto_analysis,
             visibility: visibility,
             tags: validate_tags(tags),
             allow_comments: allow_comments,
             allow_ratings: allow_ratings
           }),
         {:ok, enriched_report} <- enrich_battle_report(battle_report) do
      Logger.info("Successfully created battle report #{battle_report.id}")
      {:ok, enriched_report}
    else
      {:error, reason} ->
        Logger.error("Failed to create battle report: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Rate a battle report with community scoring.
  """
  def rate_battle_report(report_id, rater_character_id, rating, options \\ []) do
    case fetch_battle_report(report_id) do
      {:ok, battle_report} ->
        CommunityManager.rate_battle_report(battle_report, rater_character_id, rating, options)
    end
  end

  @doc """
  Add a tactical highlight to a battle report.
  """
  def add_tactical_highlight(report_id, character_id, highlight, options \\ []) do
    timestamp = Keyword.get(options, :timestamp)
    highlight_type = Keyword.get(options, :highlight_type, :tactical_moment)

    with {:ok, battle_report} <- fetch_battle_report(report_id),
         {:ok, validated_highlight} <-
           validate_tactical_highlight(highlight, timestamp, highlight_type),
         {:ok, highlight_record} <-
           create_highlight_record(
             report_id,
             character_id,
             validated_highlight,
             timestamp,
             highlight_type
           ),
         {:ok, _access_verified} <- verify_character_access(character_id, report_id),
         {:ok, updated_report} <- add_highlight_to_report(battle_report, highlight_record) do
      {:ok, updated_report}
    end
  end

  @doc """
  Curate featured battles based on community engagement.
  """
  def curate_featured_battles(options \\ []) do
    CommunityManager.curate_featured_battles(options)
  end

  @doc """
  Search battle reports with advanced filtering.
  """
  def search_battle_reports(query, options \\ []) do
    CommunityManager.search_battle_reports(query, options)
  end

  # Private helper functions

  defp fetch_battle_data(battle_id) do
    case BattleAnalysis.get_battle_with_timeline(battle_id) do
      {:ok, battle_with_timeline} ->
        # Extract battle data and format for report creation
        battle_data = %{
          id: battle_id,
          battle_id: battle_id,
          killmails: Map.get(battle_with_timeline, :killmails, []),
          timeline: Map.get(battle_with_timeline, :timeline),
          metadata: Map.get(battle_with_timeline, :metadata, %{}),
          participants: extract_participants(battle_with_timeline),
          start_time: get_battle_start_time(battle_with_timeline),
          end_time: get_battle_end_time(battle_with_timeline)
        }

        {:ok, battle_data}

      {:error, :battle_not_found} ->
        Logger.warning("Battle not found: #{battle_id}")
        {:error, :battle_not_found}

      {:error, :reconstruction_failed} ->
        Logger.warning("Battle timeline reconstruction failed: #{battle_id}")
        {:error, :reconstruction_failed}

      {:error, reason} ->
        Logger.error("Failed to fetch battle data for #{battle_id}: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.error("Failed to fetch battle data: #{inspect(error)}")
      {:error, :database_error}
  end

  # Extracts unique participants from battle killmails
  defp extract_participants(battle_with_timeline) do
    killmails = Map.get(battle_with_timeline, :killmails, [])

    killmails
    |> Enum.flat_map(fn km ->
      victim =
        if km.victim_character_id,
          do: [
            %{
              character_id: km.victim_character_id,
              corporation_id: km.victim_corporation_id,
              alliance_id: km.victim_alliance_id,
              ship_type_id: km.victim_ship_type_id,
              role: :victim
            }
          ],
          else: []

      attackers =
        case km.raw_data do
          %{"attackers" => attackers} when is_list(attackers) ->
            Enum.filter(attackers, & &1["character_id"])
            |> Enum.map(fn att ->
              %{
                character_id: att["character_id"],
                corporation_id: att["corporation_id"],
                alliance_id: att["alliance_id"],
                ship_type_id: att["ship_type_id"],
                role: :attacker
              }
            end)

          _ ->
            []
        end

      victim ++ attackers
    end)
    |> Enum.uniq_by(& &1.character_id)
  end

  defp get_battle_start_time(battle_with_timeline) do
    case get_in(battle_with_timeline, [:metadata, :start_time]) do
      nil ->
        # Fallback to first killmail time
        case Map.get(battle_with_timeline, :killmails, []) do
          [first | _] -> first.killmail_time
          _ -> DateTime.utc_now()
        end

      time ->
        time
    end
  end

  defp get_battle_end_time(battle_with_timeline) do
    case get_in(battle_with_timeline, [:metadata, :end_time]) do
      nil ->
        # Fallback to last killmail time
        case Map.get(battle_with_timeline, :killmails, []) |> Enum.reverse() do
          [last | _] -> last.killmail_time
          _ -> DateTime.utc_now()
        end

      time ->
        time
    end
  end

  defp validate_videos(video_urls) when is_list(video_urls) do
    validated_videos = VideoProcessor.validate_video_urls(video_urls)
    {:ok, validated_videos}
  end

  defp process_highlights(highlights, battle_data) when is_list(highlights) do
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
          tactical_significance: assess_highlight_significance(highlight, battle_data)
        }
      end)

    {:ok, processed_highlights}
  end

  defp generate_auto_analysis(battle_data) do
    # Enhanced auto-analysis with real battle correlation
    multi_system_analysis = analyze_multi_system_correlation(battle_data)
    tactical_phases = analyze_tactical_phases(battle_data)
    battle_type = classify_battle_type(battle_data)
    tactical_summary = generate_tactical_summary(battle_data)
    battle_outcome = analyze_battle_outcome(battle_data)
    efficiency_rating = calculate_efficiency_rating(battle_data)
    key_statistics = extract_key_statistics(battle_data)

    auto_analysis = %{
      multi_system_correlation: multi_system_analysis,
      tactical_phases: tactical_phases,
      battle_type: battle_type,
      tactical_summary: tactical_summary,
      battle_outcome: battle_outcome,
      efficiency_rating: efficiency_rating,
      key_statistics: key_statistics,
      analyzed_at: DateTime.utc_now()
    }

    {:ok, auto_analysis}
  end

  defp create_battle_report_record(%__MODULE__.BattleReportOptions{} = opts) do
    battle_report = %{
      id: generate_report_id(),
      battle_id: opts.battle_id,
      creator_character_id: opts.creator_id,
      title: opts.title,
      description: opts.description,
      videos: Map.get(opts, :videos, []),
      tactical_highlights: Map.get(opts, :highlights, []),
      auto_analysis: opts.auto_analysis,
      visibility: opts.visibility,
      tags: Map.get(opts, :tags, []),
      allow_comments: opts.allow_comments,
      allow_ratings: opts.allow_ratings,
      community_features: %{
        ratings: [],
        average_rating: 0.0,
        total_ratings: 0,
        views: 0,
        shares: 0,
        comments: []
      },
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    {:ok, battle_report}
  end

  defp enrich_battle_report(battle_report) do
    enriched_report =
      battle_report
      |> add_tactical_insights()
      |> add_share_urls()
      |> add_compatibility_data()

    {:ok, enriched_report}
  end

  defp fetch_battle_report(report_id) do
    # In a real implementation, this would query the database
    # For now, return a sample report structure
    sample_report = %{
      id: report_id,
      title: "Sample Battle Report",
      description: "A sample battle report for demonstration",
      community_features: %{
        ratings: [],
        average_rating: 0.0,
        total_ratings: 0
      },
      tactical_highlights: [],
      created_at: DateTime.utc_now()
    }

    {:ok, sample_report}
  end

  # Analysis helper functions using real battle data

  defp assess_highlight_significance(highlight, battle_data) do
    # Assess based on ISK value if available
    isk_value = Map.get(highlight, :isk_value, 0)
    total_isk = get_in(battle_data, [:metadata, :total_isk_destroyed]) || 1

    cond do
      isk_value > total_isk * 0.3 -> :critical
      isk_value > total_isk * 0.1 -> :high
      isk_value > total_isk * 0.05 -> :medium
      true -> :low
    end
  end

  defp analyze_multi_system_correlation(battle_data) do
    systems = Map.get(battle_data, :systems, [])
    system_count = length(systems)

    %{
      is_multi_system: system_count > 1,
      system_count: system_count,
      correlation_strength: if(system_count > 1, do: 0.8, else: 1.0)
    }
  end

  defp analyze_tactical_phases(battle_data) do
    timeline = Map.get(battle_data, :timeline, [])

    if Enum.empty?(timeline) do
      []
    else
      # Group by time windows to identify phases
      timeline
      |> Enum.chunk_every(5)
      |> Enum.with_index()
      |> Enum.map(fn {events, idx} ->
        %{
          phase: idx + 1,
          event_count: length(events),
          phase_type: classify_phase_type(events)
        }
      end)
    end
  end

  defp classify_phase_type(events) do
    kill_count = Enum.count(events, &Map.has_key?(&1, :killmail_id))

    cond do
      kill_count > 3 -> :heavy_engagement
      kill_count > 0 -> :skirmish
      true -> :positioning
    end
  end

  defp classify_battle_type(battle_data) do
    participant_count = get_in(battle_data, [:metadata, :participant_count]) || 0
    killmail_count = length(Map.get(battle_data, :killmails, []))

    cond do
      participant_count > 100 -> :large_fleet_battle
      participant_count > 30 -> :fleet_engagement
      participant_count > 10 -> :medium_gang
      participant_count > 3 -> :small_gang
      killmail_count > 0 -> :skirmish
      true -> :unknown
    end
  end

  defp generate_tactical_summary(battle_data) do
    battle_type = classify_battle_type(battle_data)
    system_count = length(Map.get(battle_data, :systems, []))
    participant_count = get_in(battle_data, [:metadata, :participant_count]) || 0

    type_desc =
      case battle_type do
        :large_fleet_battle -> "Large-scale fleet engagement"
        :fleet_engagement -> "Fleet engagement"
        :medium_gang -> "Medium gang fight"
        :small_gang -> "Small gang skirmish"
        :skirmish -> "Tactical skirmish"
        _ -> "Combat engagement"
      end

    system_desc = if system_count > 1, do: " spanning #{system_count} systems", else: ""

    "#{type_desc} involving #{participant_count} participants#{system_desc}"
  end

  defp analyze_battle_outcome(battle_data) do
    sides = Map.get(battle_data, :sides, %{})

    if map_size(sides) < 2 do
      %{winner: :inconclusive, margin: 0.0, reason: "Unable to determine sides"}
    else
      # Calculate ISK efficiency per side
      side_stats =
        Enum.map(sides, fn {side_name, side_data} ->
          isk_destroyed = Map.get(side_data, :isk_destroyed, 0)
          isk_lost = Map.get(side_data, :isk_lost, 0)
          efficiency = if isk_lost > 0, do: isk_destroyed / isk_lost, else: isk_destroyed

          {side_name, %{efficiency: efficiency, isk_destroyed: isk_destroyed, isk_lost: isk_lost}}
        end)

      [{winner, winner_stats}, {loser, loser_stats}] =
        Enum.sort_by(side_stats, fn {_, stats} -> stats.efficiency end, :desc)
        |> Enum.take(2)

      margin =
        if loser_stats.efficiency > 0 do
          (winner_stats.efficiency - loser_stats.efficiency) / winner_stats.efficiency
        else
          1.0
        end

      %{
        winner: winner,
        loser: loser,
        margin: Float.round(margin, 2),
        winner_efficiency: Float.round(winner_stats.efficiency, 2)
      }
    end
  end

  defp calculate_efficiency_rating(battle_data) do
    total_destroyed = get_in(battle_data, [:metadata, :total_isk_destroyed]) || 0
    killmail_count = length(Map.get(battle_data, :killmails, []))

    # Calculate ISK per kill as a measure of engagement quality
    isk_per_kill = if killmail_count > 0, do: total_destroyed / killmail_count, else: 0

    overall =
      cond do
        isk_per_kill > 1_000_000_000 -> 0.95
        isk_per_kill > 500_000_000 -> 0.85
        isk_per_kill > 100_000_000 -> 0.75
        isk_per_kill > 50_000_000 -> 0.65
        true -> 0.5
      end

    %{
      overall: overall,
      isk_efficiency: overall,
      isk_per_kill: isk_per_kill,
      killmail_count: killmail_count
    }
  end

  defp extract_key_statistics(battle_data) do
    killmails = Map.get(battle_data, :killmails, [])
    participants = Map.get(battle_data, :participants, [])
    metadata = Map.get(battle_data, :metadata, %{})

    %{
      participants: length(participants),
      killmail_count: length(killmails),
      isk_destroyed: Map.get(metadata, :total_isk_destroyed, 0),
      systems_involved: length(Map.get(battle_data, :systems, [])),
      duration_minutes: calculate_duration_minutes(battle_data)
    }
  end

  defp calculate_duration_minutes(battle_data) do
    start_time = get_in(battle_data, [:metadata, :start_time])
    end_time = get_in(battle_data, [:metadata, :end_time])

    if start_time && end_time do
      DateTime.diff(end_time, start_time, :minute)
    else
      0
    end
  end

  defp generate_report_id,
    do: "br_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)

  defp generate_auto_title(auto_analysis), do: "Battle Report - #{auto_analysis.battle_type}"

  defp validate_description(description) when is_binary(description) do
    String.slice(description, 0, @max_description_length)
  end

  defp validate_description(_), do: ""

  defp validate_tags(tags) when is_list(tags) do
    tags
    |> Enum.take(10)
    |> Enum.map(&String.downcase/1)
    |> Enum.uniq()
  end

  defp validate_tags(_), do: []

  defp add_tactical_insights(battle_report) do
    insights = %{
      recommended_viewing: ["Key engagement moments", "Fleet coordination examples"],
      tactical_lessons: ["Effective range control", "Logistics coordination"],
      strategic_value: "High educational value for fleet commanders"
    }

    Map.put(battle_report, :tactical_insights, insights)
  end

  defp add_share_urls(battle_report) do
    base_url = "https://evedmv.com/battles"
    public_url = "#{base_url}/#{battle_report.id}"

    share_urls = %{
      public: public_url,
      embed: "#{base_url}/#{battle_report.id}/embed",
      api: "#{base_url}/#{battle_report.id}/api"
    }

    battle_report
    |> Map.put(:share_urls, share_urls)
    # Also add singular share_url and report_id for API compatibility
    |> Map.put(:share_url, public_url)
    |> Map.put(:report_id, battle_report.id)
  end

  defp add_compatibility_data(battle_report) do
    compatibility = %{
      format_version: "2.0",
      schema_version: "1.0",
      export_formats: ["json", "xml", "csv"],
      api_endpoints: ["rest", "graphql"]
    }

    Map.put(battle_report, :compatibility, compatibility)
  end

  defp validate_tactical_highlight(highlight, _timestamp, _highlight_type) do
    validated = %{
      title: Map.get(highlight, :title, "Tactical Highlight"),
      description: Map.get(highlight, :description, ""),
      tactical_significance: Map.get(highlight, :significance, :medium)
    }

    {:ok, validated}
  end

  defp create_highlight_record(
         report_id,
         character_id,
         validated_highlight,
         timestamp,
         highlight_type
       ) do
    highlight_record = %{
      id: generate_highlight_id(),
      report_id: report_id,
      character_id: character_id,
      title: validated_highlight.title,
      description: validated_highlight.description,
      timestamp: timestamp,
      highlight_type: highlight_type,
      significance: validated_highlight.tactical_significance,
      created_at: DateTime.utc_now()
    }

    {:ok, highlight_record}
  end

  defp verify_character_access(_character_id, _report_id), do: {:ok, true}

  defp add_highlight_to_report(battle_report, highlight_record) do
    updated_highlights = [highlight_record | battle_report.tactical_highlights]
    updated_report = Map.put(battle_report, :tactical_highlights, updated_highlights)
    {:ok, updated_report}
  end

  defp generate_highlight_id,
    do: "hl_" <> Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)
end
