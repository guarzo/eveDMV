defmodule EveDmv.Shared.KillmailQueries do
  @moduledoc """
  Shared SQL queries for killmail analysis across individual and corporation contexts.

  Provides reusable query builders for common killmail data patterns used by
  both character analysis and corporation intelligence features.
  """

  alias EveDmv.Repo
  alias Ecto.Adapters.SQL

  @doc """
  Get kills and losses for a single character.
  """
  def character_activity_query(_character_id, time_window_days \\ 90) do
    _since_date = DateTime.utc_now() |> DateTime.add(-time_window_days * 24 * 60 * 60, :second)

    """
    WITH character_activity AS (
      SELECT 
        p.is_victim,
        COUNT(*) as count,
        COALESCE(SUM(k.zkb_total_value), 0) as total_value
      FROM participants p
      JOIN killmails_raw k ON p.killmail_id = k.killmail_id
      WHERE p.character_id = $1
        AND k.killmail_time >= $2
      GROUP BY p.is_victim
    )
    SELECT 
      COALESCE(SUM(CASE WHEN is_victim = false THEN count ELSE 0 END), 0) as kills,
      COALESCE(SUM(CASE WHEN is_victim = true THEN count ELSE 0 END), 0) as losses,
      COALESCE(SUM(CASE WHEN is_victim = false THEN total_value ELSE 0 END), 0) as isk_destroyed,
      COALESCE(SUM(CASE WHEN is_victim = true THEN total_value ELSE 0 END), 0) as isk_lost
    FROM character_activity
    """
  end

  @doc """
  Get activity for all members of a corporation.
  """
  def corporation_members_activity_query(_corporation_id, time_window_days \\ 90) do
    _since_date = DateTime.utc_now() |> DateTime.add(-time_window_days * 24 * 60 * 60, :second)

    """
    SELECT 
      p.character_id,
      p.character_name,
      COUNT(CASE WHEN p.is_victim = false THEN 1 END) as kills,
      COUNT(CASE WHEN p.is_victim = true THEN 1 END) as losses,
      COALESCE(SUM(CASE WHEN p.is_victim = false THEN k.zkb_total_value END), 0) as isk_destroyed,
      COALESCE(SUM(CASE WHEN p.is_victim = true THEN k.zkb_total_value END), 0) as isk_lost,
      MAX(k.killmail_time) as last_activity
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE p.corporation_id = $1
      AND k.killmail_time >= $2
    GROUP BY p.character_id, p.character_name
    ORDER BY (COUNT(CASE WHEN p.is_victim = false THEN 1 END) + COUNT(CASE WHEN p.is_victim = true THEN 1 END)) DESC
    """
  end

  @doc """
  Get timezone activity pattern (kills/losses by hour).
  """
  def timezone_activity_query(filter_type, _filter_id, time_window_days \\ 30) do
    _since_date = DateTime.utc_now() |> DateTime.add(-time_window_days * 24 * 60 * 60, :second)

    filter_column =
      case filter_type do
        :character -> "p.character_id"
        :corporation -> "p.corporation_id"
        :alliance -> "p.alliance_id"
      end

    """
    SELECT 
      EXTRACT(HOUR FROM k.killmail_time AT TIME ZONE 'UTC') as hour,
      COUNT(CASE WHEN p.is_victim = false THEN 1 END) as kills,
      COUNT(CASE WHEN p.is_victim = true THEN 1 END) as losses,
      COUNT(DISTINCT p.character_id) as active_members
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE #{filter_column} = $1
      AND k.killmail_time >= $2
    GROUP BY hour
    ORDER BY hour
    """
  end

  @doc """
  Get ship usage statistics.
  """
  def ship_usage_query(filter_type, _filter_id, time_window_days \\ 90) do
    _since_date = DateTime.utc_now() |> DateTime.add(-time_window_days * 24 * 60 * 60, :second)

    filter_column =
      case filter_type do
        :character -> "p.character_id"
        :corporation -> "p.corporation_id"
        :alliance -> "p.alliance_id"
      end

    """
    SELECT 
      p.ship_type_id,
      MAX(t.type_name) as ship_name,
      COUNT(*) as usage_count,
      COUNT(CASE WHEN p.is_victim = false THEN 1 END) as kills_in_ship,
      COUNT(CASE WHEN p.is_victim = true THEN 1 END) as losses_in_ship
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    LEFT JOIN eve_item_types t ON p.ship_type_id = t.type_id
    WHERE #{filter_column} = $1
      AND k.killmail_time >= $2
      AND p.ship_type_id IS NOT NULL
    GROUP BY p.ship_type_id
    ORDER BY usage_count DESC
    """
  end

  @doc """
  Get daily activity for trend analysis.
  """
  def daily_activity_query(filter_type, _filter_id, days_back \\ 30) do
    _since_date = DateTime.utc_now() |> DateTime.add(-days_back * 24 * 60 * 60, :second)

    filter_column =
      case filter_type do
        :character -> "p.character_id"
        :corporation -> "p.corporation_id"
        :alliance -> "p.alliance_id"
      end

    """
    SELECT 
      DATE(k.killmail_time) as activity_date,
      COUNT(DISTINCT CASE WHEN p.is_victim = false THEN k.killmail_id END) as kills,
      COUNT(DISTINCT CASE WHEN p.is_victim = true THEN k.killmail_id END) as losses,
      COUNT(DISTINCT p.character_id) as unique_pilots
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE #{filter_column} = $1
      AND k.killmail_time >= $2
    GROUP BY DATE(k.killmail_time)
    ORDER BY activity_date DESC
    """
  end

  @doc """
  Execute a query and return results.
  """
  def execute(query, params) do
    case SQL.query(Repo, query, params) do
      {:ok, %{rows: rows, columns: columns}} ->
        results =
          Enum.map(rows, fn row ->
            Enum.zip(columns, row) |> Map.new()
          end)

        {:ok, results}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Get corporation overview stats.
  """
  def corporation_overview_query(_corporation_id) do
    """
    SELECT 
      COUNT(DISTINCT p.character_id) as total_members,
      COUNT(DISTINCT CASE WHEN k.killmail_time >= NOW() - INTERVAL '7 days' THEN p.character_id END) as active_7d,
      COUNT(DISTINCT CASE WHEN k.killmail_time >= NOW() - INTERVAL '30 days' THEN p.character_id END) as active_30d,
      COUNT(DISTINCT k.killmail_id) as total_killmails,
      COUNT(DISTINCT CASE WHEN p.is_victim = false THEN k.killmail_id END) as total_kills,
      COUNT(DISTINCT CASE WHEN p.is_victim = true THEN k.killmail_id END) as total_losses
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE p.corporation_id = $1
    """
  end
end
