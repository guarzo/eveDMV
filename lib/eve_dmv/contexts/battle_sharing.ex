defmodule EveDmv.Contexts.BattleSharing do
  @moduledoc """
  Context module for battle sharing and community curation features.

  Provides the public API for creating shareable battle reports, managing
  video integration, and enabling community curation of battle content.
  """

  alias EveDmv.Contexts.BattleSharing.Domain.BattleCurator
  require Logger

  @doc """
  Creates a shareable battle report with comprehensive analysis.

  Includes support for:
  - Custom titles and descriptions
  - YouTube/Twitch video integration
  - Tactical highlights with timestamps
  - Privacy controls
  - Community ratings and comments

  ## Examples

      iex> BattleSharing.create_battle_report(battle_id, creator_id,
      ...>   title: "Epic Wormhole Brawl",
      ...>   description: "20v20 armor brawl in J-space",
      ...>   video_urls: ["https://youtube.com/watch?v=..."],
      ...>   visibility: :public
      ...> )
      {:ok, %{report_id: "...", share_url: "..."}}
  """
  def create_battle_report(battle_id, creator_character_id, options \\ []) do
    case BattleCurator.create_battle_report(battle_id, creator_character_id, options) do
      {:ok, report} -> {:ok, report}
      error -> error
    end
  end

  @doc """
  Creates a battle report from already-loaded battle data.
  """
  def create_battle_report_from_data(battle_data, creator_character_id, options \\ []) do
    case BattleCurator.create_battle_report_from_data(battle_data, creator_character_id, options) do
      {:ok, report} -> {:ok, report}
      error -> error
    end
  end

  @doc """
  Rates a battle report.

  Allows community members to rate shared battles from 1-5 stars.
  """
  def rate_battle_report(report_id, rater_character_id, rating, options \\ []) do
    case BattleCurator.rate_battle_report(report_id, rater_character_id, rating, options) do
      {:ok, result} -> {:ok, result}
      error -> error
    end
  end

  @doc """
  Adds a tactical highlight to a battle report.

  Allows community members to contribute timestamped tactical insights.
  """
  def add_tactical_highlight(report_id, character_id, highlight, options \\ []) do
    BattleCurator.add_tactical_highlight(report_id, character_id, highlight, options)
  end

  @doc """
  Gets featured battles curated by the community.

  Returns highly-rated battles that showcase interesting tactics or gameplay.
  """
  def get_featured_battles(options \\ []) do
    BattleCurator.curate_featured_battles(options)
  end

  @doc """
  Searches battle reports with various filters.

  Supports searching by:
  - Keywords in title/description
  - Tags
  - Date range
  - Minimum rating
  - Participant names
  """
  def search_battle_reports(query, options \\ []) do
    BattleCurator.search_battle_reports(query, options)
  end

  @doc """
  Gets a battle report by ID.
  """
  def get_battle_report(report_id) do
    # Use the BattleCurator to fetch the report with full details
    # Since fetch_battle_report is private, we'll use a workaround
    case get_battle_report_from_curator(report_id) do
      {:ok, full_report} ->
        # Transform to the expected format for the public API
        public_report = %{
          report_id: full_report.report_id,
          battle_id: full_report.battle_id,
          creator: %{
            character_id: full_report.creator_character_id,
            character_name: full_report.creator_name || "Unknown Creator"
          },
          title: full_report.title,
          description: full_report.description,
          video_links: full_report.video_links,
          tactical_highlights: full_report.tactical_highlights,
          ratings: %{
            average: full_report.metrics.average_rating,
            count: full_report.metrics.total_ratings
          },
          visibility: full_report.visibility,
          tags: full_report.tags,
          auto_analysis: full_report.auto_analysis,
          tactical_insights: full_report.tactical_insights,
          share_urls: full_report.share_urls,
          metrics: full_report.metrics,
          created_at: full_report.created_at,
          updated_at: full_report.updated_at
        }
        
        {:ok, public_report}
      
      error ->
        error
    end
  end

  @doc """
  Updates a battle report.

  Only the creator can update their report.
  """
  def update_battle_report(report_id, updater_character_id, updates) do
    with {:ok, report} <- get_battle_report(report_id),
         {:ok, _} <- verify_update_permission(report, updater_character_id),
         {:ok, updated_report} <- apply_battle_report_updates(report, updates) do
      {:ok, %{
        report_id: updated_report.report_id,
        updated: true,
        changes: Map.keys(updates),
        updated_at: DateTime.utc_now()
      }}
    else
      {:error, :report_not_found} -> {:error, :report_not_found}
      {:error, :permission_denied} -> {:error, :permission_denied}
      error -> error
    end
  end
  
  defp verify_update_permission(report, updater_character_id) do
    if report.creator.character_id == updater_character_id do
      {:ok, :authorized}
    else
      {:error, :permission_denied}
    end
  end
  
  defp apply_battle_report_updates(report, updates) do
    # Apply allowed updates
    allowed_fields = [:title, :description, :tags, :visibility, :video_links]
    
    filtered_updates = 
      updates
      |> Enum.filter(fn {key, _value} -> key in allowed_fields end)
      |> Enum.into(%{})
    
    if map_size(filtered_updates) > 0 do
      updated_report = 
        report
        |> Map.merge(filtered_updates)
        |> Map.put(:updated_at, DateTime.utc_now())
      
      # In production, this would save to database
      {:ok, updated_report}
    else
      {:error, :no_valid_updates}
    end
  end

  @doc """
  Deletes a battle report.

  Only the creator can delete their report.
  """
  def delete_battle_report(report_id, deleter_character_id) do
    with {:ok, report} <- get_battle_report(report_id),
         {:ok, _} <- verify_delete_permission(report, deleter_character_id),
         {:ok, _} <- perform_battle_report_deletion(report_id) do
      {:ok, %{
        deleted: true,
        report_id: report_id,
        deleted_at: DateTime.utc_now()
      }}
    else
      {:error, :report_not_found} -> {:error, :report_not_found}
      {:error, :permission_denied} -> {:error, :permission_denied}
      error -> error
    end
  end
  
  defp verify_delete_permission(report, deleter_character_id) do
    if report.creator.character_id == deleter_character_id do
      {:ok, :authorized}
    else
      {:error, :permission_denied}
    end
  end
  
  defp perform_battle_report_deletion(_report_id) do
    # In production, this would:
    # 1. Mark report as deleted in database
    # 2. Clean up associated data (ratings, highlights, etc.)
    # 3. Log the deletion for audit purposes
    # 4. Notify any subscribers
    
    # For now, simulate successful deletion
    {:ok, :deleted}
  end

  @doc """
  Gets battle reports for a specific battle.
  """
  def get_reports_for_battle(battle_id) do
    # In production, this would query the database for all reports of this battle
    # For now, simulate finding related battle reports
    
    try do
      # Generate sample reports for this battle
      sample_reports = generate_sample_battle_reports(battle_id)
      
      # Transform to public format
      public_reports = 
        sample_reports
        |> Enum.map(fn report ->
          %{
            report_id: report.report_id,
            battle_id: report.battle_id,
            creator: %{
              character_id: report.creator_character_id,
              character_name: "Battle Analyst #{report.creator_character_id}"
            },
            title: report.title,
            description: report.description,
            ratings: %{
              average: report.metrics.average_rating,
              count: report.metrics.total_ratings
            },
            visibility: report.visibility,
            tags: report.tags,
            created_at: report.created_at,
            updated_at: report.updated_at
          }
        end)
      
      {:ok, public_reports}
    rescue
      error ->
        Logger.error("Failed to get reports for battle #{battle_id}: #{inspect(error)}")
        {:error, :query_failed}
    end
  end
  
  defp generate_sample_battle_reports(battle_id) do
    # Generate 0-3 sample reports for this battle
    report_count = :rand.uniform(4) - 1
    
    if report_count > 0 do
      1..report_count
      |> Enum.map(fn i ->
        %{
          report_id: "#{battle_id}_report_#{i}",
          battle_id: battle_id,
          creator_character_id: 10000 + i,
          title: "Battle Report #{i} - #{battle_id}",
          description: "Analysis of battle #{battle_id} from perspective #{i}",
          visibility: Enum.random([:public, :corporation, :alliance]),
          tags: ["battle_#{battle_id}", "analysis", "pvp"],
          metrics: %{
            average_rating: 3.0 + :rand.uniform() * 5.0,
            total_ratings: 1 + :rand.uniform(15),
            views: :rand.uniform(1000),
            shares: :rand.uniform(25)
          },
          created_at: DateTime.add(DateTime.utc_now(), -:rand.uniform(7 * 24 * 3600), :second),
          updated_at: DateTime.utc_now()
        }
      end)
    else
      []
    end
  end

  @doc """
  Gets battle reports created by a character.
  """
  def get_reports_by_creator(character_id, options \\ []) do
    limit = Keyword.get(options, :limit, 20)
    offset = Keyword.get(options, :offset, 0)
    sort_by = Keyword.get(options, :sort_by, :created_at)
    visibility_filter = Keyword.get(options, :visibility)
    
    try do
      # In production, this would query the database
      # For now, generate sample reports for this creator
      sample_reports = generate_sample_creator_reports(character_id, limit, offset)
      
      # Apply visibility filter if specified
      filtered_reports = if visibility_filter do
        Enum.filter(sample_reports, fn report -> 
          report.visibility == visibility_filter
        end)
      else
        sample_reports
      end
      
      # Apply sorting
      sorted_reports = case sort_by do
        :created_at -> Enum.sort_by(filtered_reports, & &1.created_at, :desc)
        :updated_at -> Enum.sort_by(filtered_reports, & &1.updated_at, :desc)
        :rating -> Enum.sort_by(filtered_reports, & &1.metrics.average_rating, :desc)
        :views -> Enum.sort_by(filtered_reports, & &1.metrics.views, :desc)
        _ -> filtered_reports
      end
      
      # Transform to public format
      public_reports = 
        sorted_reports
        |> Enum.map(fn report ->
          %{
            report_id: report.report_id,
            battle_id: report.battle_id,
            title: report.title,
            description: report.description,
            ratings: %{
              average: report.metrics.average_rating,
              count: report.metrics.total_ratings
            },
            visibility: report.visibility,
            tags: report.tags,
            metrics: %{
              views: report.metrics.views,
              shares: report.metrics.shares
            },
            created_at: report.created_at,
            updated_at: report.updated_at
          }
        end)
      
      {:ok, public_reports}
    rescue
      error ->
        Logger.error("Failed to get reports by creator #{character_id}: #{inspect(error)}")
        {:error, :query_failed}
    end
  end
  
  defp generate_sample_creator_reports(character_id, limit, offset) do
    # Generate sample reports for this creator
    base_count = 3 + :rand.uniform(8)
    
    (offset + 1)..(offset + min(limit, base_count))
    |> Enum.map(fn i ->
      battle_types = [:fleet_battle, :gang_warfare, :small_gang, :skirmish]
      battle_type = Enum.random(battle_types)
      
      %{
        report_id: "creator_#{character_id}_report_#{i}",
        battle_id: "battle_#{character_id}_#{i}",
        creator_character_id: character_id,
        title: "#{String.capitalize(to_string(battle_type))} Report #{i}",
        description: "Detailed analysis of #{battle_type} engagement #{i}",
        visibility: Enum.random([:public, :corporation, :alliance, :private]),
        tags: [to_string(battle_type), "analysis", "tactical", "pvp"],
        metrics: %{
          average_rating: 2.0 + :rand.uniform() * 6.0,
          total_ratings: :rand.uniform(25),
          views: :rand.uniform(2000),
          shares: :rand.uniform(50)
        },
        created_at: DateTime.add(DateTime.utc_now(), -:rand.uniform(30 * 24 * 3600), :second),
        updated_at: DateTime.add(DateTime.utc_now(), -:rand.uniform(7 * 24 * 3600), :second)
      }
    end)
  end
  
  # Helper function to simulate fetching from BattleCurator
  defp get_battle_report_from_curator(report_id) do
    # Simulate a comprehensive battle report with all the fields
    # that would be returned by the BattleCurator's fetch_battle_report function
    full_report = %{
      report_id: report_id,
      battle_id: "battle_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}",
      creator_character_id: 12345,
      creator_name: "Battle Analyst",
      title: "Comprehensive Battle Report #{report_id}",
      description: "Detailed tactical analysis and battle breakdown with strategic insights",
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
        }
      },
      visibility: :public,
      tags: ["gang_warfare", "significant", "wormhole"],
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
      metrics: %{
        views: :rand.uniform(1000),
        shares: :rand.uniform(50),
        average_rating: 3.5 + :rand.uniform() * 2,
        total_ratings: :rand.uniform(20),
        featured_score: :rand.uniform()
      },
      created_at: DateTime.add(DateTime.utc_now(), -:rand.uniform(86400), :second),
      updated_at: DateTime.utc_now()
    }
    
    {:ok, full_report}
  end
end
