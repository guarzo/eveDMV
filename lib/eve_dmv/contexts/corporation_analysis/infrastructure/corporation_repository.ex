defmodule EveDmv.Contexts.CorporationAnalysis.Infrastructure.CorporationRepository do
  @moduledoc """
  Repository for corporation data and member statistics.

  Provides data access layer for corporation analysis operations using
  real killmail data from the database.
  """

  use EveDmv.ErrorHandler
  alias EveDmv.Result
  alias EveDmv.Shared.{KillmailQueries, ActivityMetrics}
  alias EveDmv.Repo
  alias Ecto.Adapters.SQL
  require Logger

  @doc """
  Get corporation basic data from killmail participants.
  """
  def get_corporation_data(corporation_id) do
    # Get basic corporation info from participants table
    query = """
    SELECT DISTINCT
      p.corporation_id,
      p.corporation_name,
      p.alliance_id,
      p.alliance_name,
      COUNT(DISTINCT p.character_id) as member_count,
      MIN(k.killmail_time) as first_seen,
      MAX(k.killmail_time) as last_seen
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE p.corporation_id = $1
    GROUP BY p.corporation_id, p.corporation_name, p.alliance_id, p.alliance_name
    """

    case SQL.query(Repo, query, [corporation_id]) do
      {:ok, %{rows: [row]}} ->
        [corp_id, corp_name, alliance_id, alliance_name, member_count, first_seen, _last_seen] =
          row

        corporation_data = %{
          corporation_id: corp_id,
          name: corp_name || "Unknown Corporation",
          member_count: member_count,
          alliance_id: alliance_id,
          alliance_name: alliance_name,
          creation_date: first_seen,
          ticker: "[#{String.slice(corp_name || "UNK", 0..3)}]",
          description: "Corporation data from killmail analysis",
          # Would need ESI for full history
          member_history: [],
          # Would need ESI for this
          recent_joins: [],
          # Would need ESI for this
          recent_departures: []
        }

        Result.ok(corporation_data)

      {:ok, %{rows: []}} ->
        Result.error(:not_found, "Corporation not found in killmail data")

      {:error, error} ->
        Logger.error("Failed to get corporation data", error: inspect(error))
        Result.error(:database_error, "Failed to fetch corporation data")
    end
  end

  @doc """
  Get member statistics for a corporation.
  """
  def get_member_statistics(corporation_id) do
    # Get real member activity data
    case KillmailQueries.execute(
           KillmailQueries.corporation_members_activity_query(corporation_id, 90),
           [corporation_id, DateTime.add(DateTime.utc_now(), -90 * 24 * 60 * 60, :second)]
         ) do
      {:ok, members} ->
        # Get timezone data for each member
        member_stats =
          Enum.map(members, fn member ->
            character_id = Map.get(member, "character_id")

            # Get hourly activity for timezone analysis
            {:ok, hourly_data} = get_member_hourly_activity(character_id, 30)
            timezone_info = ActivityMetrics.analyze_timezone_patterns(hourly_data)

            %{
              character_id: character_id,
              character_name: Map.get(member, "character_name", "Unknown"),
              # Would need ESI for actual roles
              corp_role: "Member",
              recent_kills: Map.get(member, "kills", 0),
              recent_losses: Map.get(member, "losses", 0),
              last_active: Map.get(member, "last_activity"),
              activity_by_hour: Map.new(hourly_data),
              # Could add daily breakdown if needed
              activity_by_day: %{},
              group_activity_ratio: calculate_group_activity_ratio(character_id, corporation_id),
              corp_activity_score:
                ActivityMetrics.calculate_activity_score(
                  Map.get(member, "kills", 0),
                  Map.get(member, "losses", 0),
                  Map.get(member, "last_activity")
                ),
              prime_timezone: timezone_info.primary_timezone,
              isk_destroyed: Map.get(member, "isk_destroyed", 0),
              isk_lost: Map.get(member, "isk_lost", 0)
            }
          end)

        member_stats

      {:error, error} ->
        Logger.error("Failed to get member statistics", error: inspect(error))
        []
    end
  end

  @doc """
  Get corporation killmail statistics.
  """
  def get_killmail_statistics(corporation_id) do
    query = """
    SELECT 
      COUNT(DISTINCT CASE WHEN p.is_victim = false THEN k.killmail_id END) as total_kills,
      COUNT(DISTINCT CASE WHEN p.is_victim = true THEN k.killmail_id END) as total_losses,
      COALESCE(SUM(CASE WHEN p.is_victim = false THEN k.zkb_total_value END), 0) as isk_destroyed,
      COALESCE(SUM(CASE WHEN p.is_victim = true THEN k.zkb_total_value END), 0) as isk_lost,
      AVG(k.zkb_fitted_value) as avg_ship_value,
      COUNT(DISTINCT p.character_id) as unique_pilots
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE p.corporation_id = $1
      AND k.killmail_time >= NOW() - INTERVAL '90 days'
    """

    case SQL.query(Repo, query, [corporation_id]) do
      {:ok, %{rows: [row]}} ->
        [total_kills, total_losses, isk_destroyed, isk_lost, avg_ship_value, unique_pilots] = row

        # Calculate recent trend
        {:ok, trend_data} = get_activity_trend(corporation_id, 30)
        trend_info = ActivityMetrics.calculate_activity_trend(trend_data)

        %{
          total_kills: total_kills || 0,
          total_losses: total_losses || 0,
          isk_destroyed: Decimal.to_float(isk_destroyed || 0),
          isk_lost: Decimal.to_float(isk_lost || 0),
          recent_activity_trend: trend_info.growth_rate / 100,
          avg_engagement_size: calculate_avg_engagement_size(corporation_id),
          unique_pilots: unique_pilots || 0,
          avg_ship_value: Decimal.to_float(avg_ship_value || 0)
        }

      {:error, error} ->
        Logger.error("Failed to get killmail statistics", error: inspect(error))

        %{
          total_kills: 0,
          total_losses: 0,
          isk_destroyed: 0,
          isk_lost: 0,
          recent_activity_trend: 0,
          avg_engagement_size: 0,
          unique_pilots: 0,
          avg_ship_value: 0
        }
    end
  end

  @doc """
  Get corporation activity timeline.
  """
  def get_activity_timeline(corporation_id, days_back \\ 30) do
    case KillmailQueries.execute(
           KillmailQueries.daily_activity_query(:corporation, corporation_id, days_back),
           [corporation_id, DateTime.add(DateTime.utc_now(), -days_back * 24 * 60 * 60, :second)]
         ) do
      {:ok, timeline_data} ->
        timeline =
          timeline_data
          |> Enum.map(fn day ->
            %{
              date: Map.get(day, "activity_date"),
              total_activity: Map.get(day, "kills", 0) + Map.get(day, "losses", 0),
              kills: Map.get(day, "kills", 0),
              losses: Map.get(day, "losses", 0),
              active_members: Map.get(day, "unique_pilots", 0)
            }
          end)
          |> Enum.reverse()

        Result.ok(timeline)

      {:error, error} ->
        Logger.error("Failed to get activity timeline", error: inspect(error))
        Result.error(:database_error, "Failed to fetch activity timeline")
    end
  end

  @doc """
  Get corporation timezone distribution.
  """
  def get_timezone_distribution(corporation_id) do
    case KillmailQueries.execute(
           KillmailQueries.timezone_activity_query(:corporation, corporation_id, 30),
           [corporation_id, DateTime.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second)]
         ) do
      {:ok, hourly_data} ->
        # Convert to hourly activity map
        hourly_map =
          hourly_data
          |> Enum.map(fn row ->
            {trunc(Map.get(row, "hour", 0)), Map.get(row, "kills", 0) + Map.get(row, "losses", 0)}
          end)
          |> Map.new()

        # Ensure all hours are represented
        full_hourly_data =
          for hour <- 0..23, into: %{} do
            {hour, Map.get(hourly_map, hour, 0)}
          end

        Result.ok(full_hourly_data)

      {:error, error} ->
        Logger.error("Failed to get timezone distribution", error: inspect(error))
        Result.error(:database_error, "Failed to fetch timezone data")
    end
  end

  # Helper functions

  defp get_member_hourly_activity(character_id, days) do
    case KillmailQueries.execute(
           KillmailQueries.timezone_activity_query(:character, character_id, days),
           [character_id, DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)]
         ) do
      {:ok, data} ->
        hourly_activity =
          data
          |> Enum.map(fn row ->
            {trunc(Map.get(row, "hour", 0)), Map.get(row, "kills", 0) + Map.get(row, "losses", 0)}
          end)

        {:ok, hourly_activity}

      {:error, _} ->
        {:ok, []}
    end
  end

  defp calculate_group_activity_ratio(character_id, corporation_id) do
    # Calculate ratio of fleet vs solo activity
    query = """
    SELECT 
      COUNT(DISTINCT CASE WHEN 
        (SELECT COUNT(DISTINCT p2.character_id) 
         FROM participants p2 
         WHERE p2.killmail_id = k.killmail_id 
           AND p2.corporation_id = $2
           AND p2.is_victim = false) > 1 
        THEN k.killmail_id END)::float / 
      NULLIF(COUNT(DISTINCT k.killmail_id)::float, 0) as group_ratio
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE p.character_id = $1
      AND p.is_victim = false
      AND k.killmail_time >= NOW() - INTERVAL '30 days'
    """

    case SQL.query(Repo, query, [character_id, corporation_id]) do
      {:ok, %{rows: [[ratio]]}} when is_number(ratio) ->
        Decimal.to_float(ratio)

      _ ->
        0.0
    end
  end

  defp calculate_avg_engagement_size(corporation_id) do
    query = """
    SELECT AVG(participants_per_kill) as avg_size
    FROM (
      SELECT k.killmail_id, COUNT(DISTINCT p.character_id) as participants_per_kill
      FROM killmails_raw k
      JOIN participants p ON k.killmail_id = p.killmail_id
      WHERE p.corporation_id = $1
        AND p.is_victim = false
        AND k.killmail_time >= NOW() - INTERVAL '30 days'
      GROUP BY k.killmail_id
    ) as engagement_sizes
    """

    case SQL.query(Repo, query, [corporation_id]) do
      {:ok, %{rows: [[avg_size]]}} when is_number(avg_size) ->
        Float.round(Decimal.to_float(avg_size), 1)

      _ ->
        0.0
    end
  end

  defp get_activity_trend(corporation_id, days) do
    case KillmailQueries.execute(
           KillmailQueries.daily_activity_query(:corporation, corporation_id, days),
           [corporation_id, DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)]
         ) do
      {:ok, data} ->
        trend_data =
          Enum.map(data, fn day ->
            %{
              total_activity: Map.get(day, "kills", 0) + Map.get(day, "losses", 0)
            }
          end)

        {:ok, trend_data}

      {:error, _} ->
        {:ok, []}
    end
  end
end
