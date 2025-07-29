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
    {:ok, full_report} = get_battle_report_from_curator(report_id)

    # Transform to the expected format for the public API
    public_report = %{
      report_id: full_report.report_id,
      battle_id: full_report.battle_id,
      creator: %{
        character_id: full_report.creator_character_id,
        character_name: full_report.creator_name
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
  end

  @doc """
  Updates a battle report.

  Only the creator can update their report.
  """
  def update_battle_report(report_id, updater_character_id, updates) do
    with {:ok, report} <- get_battle_report(report_id),
         {:ok, _} <- verify_update_permission(report, updater_character_id),
         {:ok, updated_report} <- apply_battle_report_updates(report, updates) do
      {:ok,
       %{
         report_id: updated_report.report_id,
         updated: true,
         changes: Map.keys(updates),
         updated_at: DateTime.utc_now()
       }}
    else
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
      {:ok,
       %{
         deleted: true,
         report_id: report_id,
         deleted_at: DateTime.utc_now()
       }}
    else
      {:error, :permission_denied} -> {:error, :permission_denied}
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

    # Generate sample reports for this battle
    sample_reports = generate_sample_battle_reports(battle_id)

    # Transform to public format
    public_reports =
      Enum.map(sample_reports, fn report ->
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

  defp generate_sample_battle_reports(battle_id) do
    # Get actual battle reports from the database
    case get_battle_reports_from_db(battle_id) do
      {:ok, reports} when reports != [] ->
        reports

      _ ->
        # Return empty list instead of generating fake data
        # Real implementation would either return no reports or fetch from actual sources
        []
    end
  end

  defp get_battle_reports_from_db(battle_id) do
    # This would query actual battle reports from database
    # For now, return empty to avoid fake data
    {:ok, []}
  rescue
    error ->
      Logger.error("Failed to fetch battle reports for #{battle_id}: #{inspect(error)}")
      {:error, :query_failed}
  end

  @doc """
  Gets battle reports created by a character.
  """
  def get_reports_by_creator(character_id, options \\ []) do
    limit = Keyword.get(options, :limit, 20)
    offset = Keyword.get(options, :offset, 0)
    sort_by = Keyword.get(options, :sort_by, :created_at)
    visibility_filter = Keyword.get(options, :visibility)

    # In production, this would query the database
    # For now, generate sample reports for this creator
    sample_reports = generate_sample_creator_reports(character_id, limit, offset)

    # Apply visibility filter if specified
    filtered_reports =
      if visibility_filter do
        Enum.filter(sample_reports, fn report ->
          report.visibility == visibility_filter
        end)
      else
        sample_reports
      end

    # Apply sorting
    sorted_reports =
      case sort_by do
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

  defp generate_sample_creator_reports(character_id, limit, offset) do
    # Get actual reports created by this character from database
    case query_character_battle_reports(character_id, offset, limit) do
      {:ok, reports} ->
        reports

      {:error, _} ->
        # Return empty list instead of generating fake data
        []
    end
  end

  defp query_character_battle_reports(_character_id, _offset, _limit) do
    # This would query the actual database for battle reports
    # created by the specified character with pagination
    {:ok, []}
  rescue
    error ->
      Logger.error("Failed to query battle reports: #{inspect(error)}")

      {:error, :query_failed}
  end

  # Helper function to fetch battle report from BattleCurator
  defp get_battle_report_from_curator(report_id) do
    # Try to fetch actual battle report from the curator service
    case fetch_battle_report_from_service(report_id) do
      {:ok, report} ->
        {:ok, report}

      {:error, :not_found} ->
        {:error, :report_not_found}

      {:error, reason} ->
        Logger.error(
          "Failed to fetch battle report #{report_id} from curator: #{inspect(reason)}"
        )

        {:error, :curator_unavailable}
    end
  end

  defp fetch_battle_report_from_service(_report_id) do
    # This would integrate with the actual BattleCurator service
    # For now, return not found to avoid fake data
    {:error, :not_found}
  rescue
    error ->
      Logger.error("Error accessing battle curator service: #{inspect(error)}")
      {:error, :service_error}
  end
end
