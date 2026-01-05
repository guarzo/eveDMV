defmodule EveDmv.Platform.Database.CorporationQueries do
  @moduledoc """
  Optimized queries for corporation analysis.

  Uses efficient SQL queries to avoid expensive JSONB operations and N+1 query issues.

  All functions accept either Date or DateTime for since_date parameters.
  """

  alias EveDmv.Repo
  require Logger

  # Convert Date or DateTime to DateTime for SQL queries
  defp to_datetime(%Date{} = date), do: DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
  defp to_datetime(%DateTime{} = datetime), do: datetime
  defp to_datetime(%NaiveDateTime{} = ndt), do: DateTime.from_naive!(ndt, "Etc/UTC")

  @doc """
  Get top active members without expensive N+1 queries.
  Uses materialized view for Sprint 15A performance optimization.

  Accepts either Date or DateTime for since_date parameter.
  """
  def get_top_active_members(corporation_id, limit \\ 10, since_date) do
    since_datetime = to_datetime(since_date)

    # Use materialized view for instant results
    query = """
    SELECT
      character_id,
      character_name,
      total_killmails as total_activity,
      kills,
      losses,
      isk_destroyed,
      isk_lost,
      systems_active,
      ships_flown,
      days_active,
      activity_rank,
      last_seen,
    CASE
        WHEN losses = 0 THEN 100.0
        ELSE ROUND((kills::decimal / (kills + losses)::decimal) * 100, 2)
      END as efficiency
    FROM corporation_member_summary
    WHERE corporation_id = $1
      AND last_seen >= $3
    ORDER BY activity_rank
    LIMIT $2
    """

    case Repo.query(query, [corporation_id, limit, since_datetime]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [
                            character_id,
                            character_name,
                            total_activity,
                            kills,
                            losses,
                            isk_destroyed,
                            isk_lost,
                            systems_active,
                            ships_flown,
                            days_active,
                            activity_rank,
                            last_seen,
                            efficiency
                          ] ->
          %{
            character_id: character_id,
            character_name: character_name,
            total_activity: total_activity,
            kills: kills,
            losses: losses,
            efficiency: efficiency,
            isk_destroyed: safe_decimal_to_float(isk_destroyed),
            isk_lost: safe_decimal_to_float(isk_lost),
            systems_active: systems_active,
            ships_flown: ships_flown,
            days_active: days_active,
            activity_rank: activity_rank,
            last_seen: last_seen
          }
        end)

      {:error, _} ->
        # Fallback to direct query
        Logger.warning("Materialized view not available, falling back to direct query")
        get_top_active_members_direct(corporation_id, limit, since_datetime)
    end
  end

  # Fallback method using direct queries (expects DateTime)
  defp get_top_active_members_direct(corporation_id, limit, since_datetime) do
    query = """
    WITH member_activity AS (
      -- Members who died
    SELECT
        victim_character_id as character_id,
        raw_data->'victim'->>'character_name' as character_name,
        COUNT(*) as total_activity,
        0 as kills,
        COUNT(*) as losses
      FROM killmails_raw
      WHERE victim_corporation_id = $1
        AND victim_character_id IS NOT NULL
        AND killmail_time >= $3
      GROUP BY victim_character_id, character_name

      UNION ALL

      -- Members who got kills
    SELECT
        (attacker->>'character_id')::integer as character_id,
        attacker->>'character_name' as character_name,
        COUNT(*) as total_activity,
        COUNT(*) as kills,
        0 as losses
      FROM killmails_raw k,
           jsonb_array_elements(k.raw_data->'attackers') as attacker
      WHERE (attacker->>'corporation_id')::integer = $1
        AND attacker->>'character_id' IS NOT NULL
        AND k.killmail_time >= $3
      GROUP BY character_id, character_name
    ),
    aggregated AS (
    SELECT
        character_id,
        MAX(character_name) as character_name,
        SUM(total_activity) as total_activity,
        SUM(kills) as kills,
        SUM(losses) as losses
      FROM member_activity
      GROUP BY character_id
    )
    SELECT
      character_id,
      character_name,
      total_activity,
      kills,
      losses,
    CASE
        WHEN losses > 0 THEN ROUND(kills::numeric / losses, 2)
        ELSE kills
      END as kd_ratio
    FROM aggregated
    ORDER BY total_activity DESC
    LIMIT $2
    """

    case Repo.query(query, [corporation_id, limit, since_datetime]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [char_id, char_name, activity, kills, losses, kd] ->
          %{
            character_id: char_id,
            character_name: char_name || "Unknown",
            total_activity: activity,
            kills: kills,
            losses: losses,
            kd_ratio: kd
          }
        end)

      {:error, error} ->
        Logger.error("Failed to get top active members: #{inspect(error)}")
        []
    end
  end

  @doc """
  Get corporation activity by timezone efficiently.

  Accepts either Date or DateTime for since_date parameter.
  """
  def get_timezone_activity(corporation_id, since_date) do
    since_datetime = to_datetime(since_date)

    query = """
    WITH hourly_activity AS (
    SELECT
        EXTRACT(HOUR FROM killmail_time AT TIME ZONE 'UTC') as hour,
        COUNT(*) as activity_count,
        'loss' as activity_type
      FROM killmails_raw
      WHERE victim_corporation_id = $1
        AND killmail_time >= $2
      GROUP BY hour

      UNION ALL

    SELECT
        EXTRACT(HOUR FROM k.killmail_time AT TIME ZONE 'UTC') as hour,
        COUNT(*) as activity_count,
        'kill' as activity_type
      FROM killmails_raw k
      WHERE k.killmail_time >= $2
        AND EXISTS (
          SELECT 1
          FROM jsonb_array_elements(k.raw_data->'attackers') AS attacker
          WHERE (attacker->>'corporation_id')::integer = $1
        )
      GROUP BY hour
    )
    SELECT
      hour::integer,
      SUM(activity_count) as total_activity
    FROM hourly_activity
    GROUP BY hour
    ORDER BY hour
    """

    case Repo.query(query, [corporation_id, since_datetime]) do
      {:ok, %{rows: rows}} ->
        # Convert to map for easy lookup
        activity_map =
          rows
          |> Enum.map(fn [hour, count] -> {hour, count} end)
          |> Map.new()

        # Ensure all hours are represented
        0..23
        |> Enum.map(fn hour ->
          %{
            hour: hour,
            activity: Map.get(activity_map, hour, 0)
          }
        end)

      {:error, error} ->
        Logger.error("Failed to get timezone activity: #{inspect(error)}")
        []
    end
  end

  @doc """
  Get ship usage statistics for the corporation.

  Accepts either Date or DateTime for since_date parameter.
  """
  def get_ship_usage_stats(corporation_id, since_date, limit \\ 20) do
    since_datetime = to_datetime(since_date)

    query = """
    WITH ship_usage AS (
      -- Ships lost by corp members
    SELECT
        victim_ship_type_id as ship_type_id,
        COUNT(*) as usage_count,
        SUM(COALESCE((raw_data->>'total_value')::numeric, 0)) as total_value
      FROM killmails_raw
      WHERE victim_corporation_id = $1
        AND victim_ship_type_id IS NOT NULL
        AND killmail_time >= $2
      GROUP BY victim_ship_type_id

      UNION ALL

      -- Ships used by corp members in kills
    SELECT
        (attacker->>'ship_type_id')::integer as ship_type_id,
        COUNT(*) as usage_count,
        0 as total_value
      FROM killmails_raw k,
           jsonb_array_elements(k.raw_data->'attackers') as attacker
      WHERE (attacker->>'corporation_id')::integer = $1
        AND attacker->>'ship_type_id' IS NOT NULL
        AND k.killmail_time >= $2
      GROUP BY ship_type_id
    )
    SELECT
      ship_type_id,
      SUM(usage_count) as total_usage,
      SUM(total_value) as total_isk_lost
    FROM ship_usage
    WHERE ship_type_id IS NOT NULL
    GROUP BY ship_type_id
    ORDER BY total_usage DESC
    LIMIT $3
    """

    case Repo.query(query, [corporation_id, since_datetime, limit]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [ship_id, usage, isk_lost] ->
          %{
            ship_type_id: ship_id,
            usage_count: usage,
            isk_lost: safe_decimal_to_float(isk_lost)
          }
        end)

      {:error, error} ->
        Logger.error("Failed to get ship usage stats: #{inspect(error)}")
        []
    end
  end

  @doc """
  Get recent activity without expensive operations.
  """
  def get_recent_activity(corporation_id, limit \\ 20) do
    query = """
    SELECT
      k.killmail_id,
      k.killmail_time,
      k.solar_system_id,
      k.victim_ship_type_id,
      k.victim_character_id,
      k.raw_data->'victim'->>'character_name' as victim_name,
    CASE
        WHEN k.victim_corporation_id = $1 THEN 'loss'
        ELSE 'kill'
      END as involvement_type,
      COALESCE((k.raw_data->>'total_value')::numeric, 0) as total_value
    FROM killmails_raw k
    WHERE k.victim_corporation_id = $1
       OR EXISTS (
         SELECT 1
         FROM jsonb_array_elements(k.raw_data->'attackers') as attacker
         WHERE (attacker->>'corporation_id')::integer = $1
       )
    ORDER BY k.killmail_time DESC
    LIMIT $2
    """

    case Repo.query(query, [corporation_id, limit]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [
                            km_id,
                            km_time,
                            system_id,
                            ship_id,
                            char_id,
                            char_name,
                            inv_type,
                            value
                          ] ->
          %{
            killmail_id: km_id,
            killmail_time: km_time,
            solar_system_id: system_id,
            ship_type_id: ship_id,
            character_id: char_id,
            character_name: char_name,
            involvement_type: inv_type,
            total_value: safe_decimal_to_float(value)
          }
        end)

      {:error, error} ->
        Logger.error("Failed to get recent activity: #{inspect(error)}")
        []
    end
  end

  @doc """
  Get corporation name and alliance info from recent killmails.
  """
  def get_corporation_info_from_killmails(corporation_id) do
    query = """
    WITH corp_data AS (
      -- From victims
    SELECT
        raw_data->'victim'->>'corporation_name' as corp_name,
        raw_data->'victim'->>'alliance_name' as alliance_name,
        (raw_data->'victim'->>'alliance_id')::integer as alliance_id,
    killmail_time
      FROM killmails_raw
      WHERE victim_corporation_id = $1
      ORDER BY killmail_time DESC
      LIMIT 1
    ),
    attacker_data AS (
      -- From attackers
    SELECT
        attacker->>'corporation_name' as corp_name,
        attacker->>'alliance_name' as alliance_name,
        (attacker->>'alliance_id')::integer as alliance_id,
        k.killmail_time
      FROM killmails_raw k,
           jsonb_array_elements(k.raw_data->'attackers') as attacker
      WHERE (attacker->>'corporation_id')::integer = $1
      ORDER BY k.killmail_time DESC
      LIMIT 1
    )
    SELECT
      COALESCE(
        (SELECT corp_name FROM corp_data),
        (SELECT corp_name FROM attacker_data)
      ) as corp_name,
      COALESCE(
        (SELECT alliance_name FROM corp_data),
        (SELECT alliance_name FROM attacker_data)
      ) as alliance_name,
      COALESCE(
        (SELECT alliance_id FROM corp_data),
        (SELECT alliance_id FROM attacker_data)
      ) as alliance_id
    """

    case Repo.query(query, [corporation_id]) do
      {:ok, %{rows: [[corp_name, alliance_name, alliance_id]]}} ->
        %{
          corporation_name: corp_name,
          alliance_name: alliance_name,
          alliance_id: alliance_id
        }

      _ ->
        %{
          corporation_name: nil,
          alliance_name: nil,
          alliance_id: nil
        }
    end
  end

  # Safely convert Decimal or nil to float
  defp safe_decimal_to_float(nil), do: 0.0
  defp safe_decimal_to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp safe_decimal_to_float(value) when is_number(value), do: value * 1.0
  defp safe_decimal_to_float(_), do: 0.0
end
