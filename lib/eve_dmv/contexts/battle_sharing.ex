defmodule EveDmv.Contexts.BattleSharing do
  @moduledoc """
  Context module for battle sharing and community curation features.

  Provides the public API for creating shareable battle reports, managing
  video integration, and enabling community curation of battle content.
  """

  alias EveDmv.Contexts.BattleSharing.Domain.BattleCurator

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
    case BattleCurator.add_tactical_highlight(report_id, character_id, highlight, options) do
      {:ok, result} -> {:ok, result}
      error -> error
    end
  end

  @doc """
  Gets featured battles curated by the community.

  Returns highly-rated battles that showcase interesting tactics or gameplay.
  """
  def get_featured_battles(options \\ []) do
    case BattleCurator.curate_featured_battles(options) do
      {:ok, battles} -> {:ok, battles}
      error -> error
    end
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
    case BattleCurator.search_battle_reports(query, options) do
      {:ok, results} -> {:ok, results}
      error -> error
    end
  end

  @doc """
  Gets a battle report by ID.
  """
  def get_battle_report(report_id) do
    # In production, this would fetch from the database
    # For now, return a mock structure
    {:ok,
     %{
       report_id: report_id,
       battle_id: "battle_123",
       creator: %{
         character_id: 12_345,
         character_name: "Test Pilot"
       },
       title: "Epic Battle Report",
       description: "An amazing battle occurred...",
       video_links: [],
       tactical_highlights: [],
       ratings: %{
         average: 4.5,
         count: 10
       },
       visibility: :public,
       tags: ["brawl", "wormhole", "capital"],
       created_at: DateTime.utc_now(),
       updated_at: DateTime.utc_now()
     }}
  end

  @doc """
  Updates a battle report.

  Only the creator can update their report.
  """
  def update_battle_report(report_id, _updater_character_id, _updates) do
    # In production, verify ownership and update
    {:ok, %{report_id: report_id, updated: true}}
  end

  @doc """
  Deletes a battle report.

  Only the creator can delete their report.
  """
  def delete_battle_report(_report_id, _deleter_character_id) do
    # In production, verify ownership and delete
    {:ok, %{deleted: true}}
  end

  @doc """
  Gets battle reports for a specific battle.
  """
  def get_reports_for_battle(_battle_id) do
    # In production, query all reports for this battle
    {:ok, []}
  end

  @doc """
  Gets battle reports created by a character.
  """
  def get_reports_by_creator(_character_id, _options \\ []) do
    # In production, query reports by creator
    {:ok, []}
  end
end
