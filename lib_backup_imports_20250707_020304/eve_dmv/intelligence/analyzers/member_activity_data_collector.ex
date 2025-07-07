defmodule EveDmv.Intelligence.Analyzers.MemberActivityDataCollector do
  alias EveDmv.Api
  alias EveDmv.Database.CharacterRepository
  alias EveDmv.Database.KillmailRepository
  alias EveDmv.Eve.EsiUtils
  alias EveDmv.Intelligence.MemberActivityIntelligence
  alias EveDmv.Killmails.Participant
  alias EveDmv.Utils.TimeUtils

  require Ash.Query
  require Logger
  @moduledoc """
  Data collection module for member activity analysis.

  This module handles all external data collection operations for member activity analysis,
  including fetching character information, killmail data, and corporation member data.
  It provides a clean separation between data collection and analysis logic.
  """


  @doc """
  Fetch character information including corporation and alliance data.

  Returns {:ok, character_info} with character name, corporation, and alliance details.
  """
  def get_character_info(character_id) do
    # Use the optimized EsiUtils function that consolidates all ESI calls
    # This function always returns {:ok, data} with fallback values
    {:ok, character_data} = EsiUtils.fetch_character_corporation_alliance(character_id)

    {:ok,
     %{
       character_name: character_data.character_name,
       corporation_id: character_data.corporation_id,
       corporation_name: character_data.corporation_name,
       alliance_id: character_data.alliance_id,
       alliance_name: character_data.alliance_name
     }}
  end

  @doc """
  Collect comprehensive activity data for a character within a specified time period.

  Returns {:ok, activity_data} with kill/loss counts, daily/hourly activity patterns.
  """
  def collect_activity_data(character_id, period_start, period_end) do
    # Collect killmail data for the period
    case get_character_killmails(character_id, period_start, period_end) do
      {:ok, killmails} ->
        activity_data = %{
          total_kills: count_kills(killmails),
          total_losses: count_losses(killmails),
          total_activities: length(killmails),
          daily_activity: group_by_day(killmails),
          hourly_activity: group_by_hour(killmails),
          monthly_activity: group_by_month(killmails)
        }

        {:ok, activity_data}
    end
  end

  @doc """
  Fetch killmail data for a character within a specified time period.

  Returns {:ok, killmails} with processed killmail data including victim status and ship info.
  """
  def get_character_killmails(character_id, period_start, period_end) do
    # Use KillmailRepository for optimized character killmail retrieval
    case KillmailRepository.get_by_character(character_id,
           start_date: period_start,
           end_date: period_end,
           preload_participants: true
         ) do
      {:ok, killmails} ->
        # Convert killmails to expected format for compatibility
        processed_killmails =
          Enum.flat_map(killmails, fn killmail ->
            # Find this character's participation in each killmail
            character_participants =
              Enum.filter(killmail.participants || [], fn p ->
                p.character_id == character_id
              end)
            Enum.map(character_participants, fn participant ->
              %{
                killmail_id: killmail.killmail_id,
                killmail_time: killmail.killmail_time,
                is_victim: participant.is_victim,
                ship_type_id: participant.ship_type_id,
                ship_name: participant.ship_name,
                solar_system_id: killmail.solar_system_id,
                solar_system_name: killmail.solar_system_name,
                total_value: killmail.total_value
              }
            end)
          end)
          |> Enum.reject(&is_nil(&1.killmail_time))

        {:ok, processed_killmails}

      {:error, reason} ->
        Logger.error("Failed to fetch character killmails: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Fetch participants for a specific killmail.

  Returns {:ok, participants} with all participant data for the killmail.
  """
  def get_killmail_participants(killmail_id) do
    query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(killmail_id == ^killmail_id)

    case Ash.read(query, domain: Api) do
      {:ok, participants} -> {:ok, participants}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetch member activity analyses for a corporation.

  Returns {:ok, member_analyses} with all member activity intelligence records.
  """
  def get_corporation_member_analyses(corporation_id) do
    case MemberActivityIntelligence.get_by_corporation(corporation_id) do
      {:ok, analyses} -> {:ok, analyses}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetch activity scores for all members in a corporation.

  Returns {:ok, activity_scores} with numerical activity scores for peer comparison.
  """
  def get_corporation_activity_scores(_corporation_id) do
    # This is a simplified implementation that returns sample data
    # In a real implementation, this would fetch actual activity scores
    # from the database based on member activity intelligence records
    {:ok, [50, 60, 70, 80]}
  end

  @doc """
  Fetch corporation members with their activity data.

  Returns {:ok, members} with processed member data including activity scores.
  """
  def fetch_corporation_members(corporation_id) do
    members =
      case CharacterRepository.get_corporation_members(corporation_id) do
        {:ok, members} -> members
        {:error, _reason} -> []
      end

    case members do
      [_ | _] = members ->
        processed_members =
          Enum.map(members, fn member ->
            %{
              character_id: member.character_id,
              character_name: member.character_name || "Unknown",
              last_activity: member.last_killmail_date,
              activity_score: calculate_member_activity_score(member)
            }
          end)

        {:ok, processed_members}

      [] ->
        {:ok, []}
    end
  rescue
    error ->
      {:error, error}
  end

  # Helper functions for data processing

  defp count_kills(killmails), do: Enum.count(killmails, &(&1.is_victim == false))
  defp count_losses(killmails), do: Enum.count(killmails, &(&1.is_victim == true))

  defp group_by_day(killmails) do
    killmails
    |> Enum.group_by(fn km -> Date.to_string(DateTime.to_date(km.killmail_time)) end)
    |> Enum.map(fn {date, kms} -> {date, length(kms)} end)
    |> Map.new()
  end

  defp group_by_hour(killmails) do
    killmails
    |> Enum.group_by(fn km -> km.killmail_time.hour end)
    |> Enum.map(fn {hour, kms} -> {hour, length(kms)} end)
    |> Map.new()
  end

  defp group_by_month(killmails) do
    killmails
    |> Enum.group_by(fn km -> "#{km.killmail_time.year}-#{km.killmail_time.month}" end)
    |> Enum.map(fn {month, kms} -> {month, length(kms)} end)
    |> Map.new()
  end

  defp calculate_member_activity_score(member) do
    # Calculate activity score based on kills, losses, and recent activity
    total_activity = (member.total_kills || 0) + (member.total_losses || 0)
    base_score = min(80, total_activity * 2)

    # Recent activity bonus
    recent_bonus =
      case member.last_killmail_date do
        nil ->
          0

        last_date ->
          days_ago = TimeUtils.days_since(last_date)
          max(0, 20 - days_ago)
      end

    min(100, base_score + recent_bonus)
  end
end
