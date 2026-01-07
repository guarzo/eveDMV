defmodule EveDmv.Platform.Database.Queries.AnalyticsQueries do
  @moduledoc """
  Typed query module for complex analytics queries.

  This module wraps raw SQL queries with proper typing, error handling, and
  documentation. Raw SQL is used here for performance-critical analytics
  operations that require complex aggregations, window functions, or joins
  that are more efficiently expressed in SQL.

  ## Design Rationale

  These queries remain as raw SQL because:
  - They involve complex aggregations (GROUP BY with multiple columns)
  - They use window functions or UNION operations
  - They require performance optimizations specific to PostgreSQL
  - They query across partitioned tables with time-based filtering

  All queries return `{:ok, result}` or `{:error, reason}` tuples.
  """

  alias EveDmv.Repo
  require Logger

  # Type definitions for query results

  @type character_activity :: %{
          character_id: integer(),
          character_name: String.t() | nil,
          corporation_name: String.t() | nil,
          alliance_name: String.t() | nil,
          total_killmails: integer(),
          last_seen: DateTime.t() | nil
        }

  @type ship_usage :: %{
          ship_type_id: integer(),
          usage_count: integer()
        }

  @type ship_performance :: %{
          ship_type_id: integer(),
          kills: integer(),
          losses: integer(),
          kd_ratio: float(),
          avg_damage: integer(),
          kill_value: Decimal.t(),
          loss_value: Decimal.t(),
          isk_efficiency: float()
        }

  @type historical_killmail :: %{
          killmail_id: integer(),
          killmail_time: DateTime.t(),
          solar_system_id: integer(),
          victim_character_id: integer() | nil,
          victim_ship_type_id: integer(),
          raw_data: map(),
          total_value: Decimal.t() | nil
        }

  # Character analytics queries

  @doc """
  Get character activity with aggregated killmail data.

  Returns characters matching the search query with their activity counts.
  Uses the optimized participants table with indexed lookups.

  ## Parameters
    - `search_query` - Partial character name to search for
    - `limit` - Maximum number of results (default: 10)

  ## Returns
    - `{:ok, [character_activity()]}` on success
    - `{:error, reason}` on failure
  """
  @spec get_character_activity(String.t(), integer()) ::
          {:ok, [character_activity()]} | {:error, term()}
  def get_character_activity(search_query, limit \\ 10) do
    query = """
    SELECT DISTINCT ON (p.character_id)
      p.character_id,
      p.character_name,
      p.corporation_name,
      p.alliance_name,
      COUNT(*) OVER (PARTITION BY p.character_id) as total_killmails,
      MAX(p.killmail_time) OVER (PARTITION BY p.character_id) as last_seen
    FROM participants p
    WHERE p.character_id IS NOT NULL
      AND p.character_name IS NOT NULL
      AND p.character_name ILIKE $1
    ORDER BY p.character_id, p.killmail_time DESC
    LIMIT $2
    """

    search_pattern = "%#{search_query}%"

    case Ecto.Adapters.SQL.query(Repo, query, [search_pattern, limit]) do
      {:ok, %{rows: rows}} ->
        results =
          Enum.map(rows, fn [char_id, char_name, corp_name, alliance_name, count, last_seen] ->
            %{
              character_id: char_id,
              character_name: char_name,
              corporation_name: corp_name,
              alliance_name: alliance_name,
              total_killmails: count,
              last_seen: last_seen
            }
          end)

        {:ok, results}

      {:error, error} ->
        Logger.error("Character activity query failed: #{inspect(error)}")
        {:error, :query_failed}
    end
  rescue
    error ->
      Logger.error("Character activity query exception: #{inspect(error)}")
      {:error, :query_exception}
  end

  @doc """
  Get corporation activity with aggregated killmail data.

  Returns corporations matching the search query with their member counts and activity.

  ## Parameters
    - `search_query` - Partial corporation name to search for
    - `limit` - Maximum number of results (default: 10)

  ## Returns
    - `{:ok, [map()]}` on success
    - `{:error, reason}` on failure
  """
  @spec get_corporation_activity(String.t(), integer()) :: {:ok, [map()]} | {:error, term()}
  def get_corporation_activity(search_query, limit \\ 10) do
    query = """
    SELECT
      p.corporation_id,
      p.corporation_name,
      p.alliance_name,
      COUNT(DISTINCT p.character_id) as member_count,
      COUNT(*) as activity_count,
      MAX(p.killmail_time) as last_seen
    FROM participants p
    WHERE p.corporation_id IS NOT NULL
      AND p.corporation_name IS NOT NULL
      AND p.corporation_name ILIKE $1
    GROUP BY p.corporation_id, p.corporation_name, p.alliance_name
    ORDER BY activity_count DESC
    LIMIT $2
    """

    search_pattern = "%#{search_query}%"

    case Ecto.Adapters.SQL.query(Repo, query, [search_pattern, limit]) do
      {:ok, %{rows: rows}} ->
        results =
          Enum.map(rows, fn [corp_id, corp_name, alliance_name, members, activity, last_seen] ->
            %{
              corporation_id: corp_id,
              corporation_name: corp_name,
              alliance_name: alliance_name,
              member_count: members,
              activity_count: activity,
              last_seen: last_seen
            }
          end)

        {:ok, results}

      {:error, error} ->
        Logger.error("Corporation activity query failed: #{inspect(error)}")
        {:error, :query_failed}
    end
  rescue
    error ->
      Logger.error("Corporation activity query exception: #{inspect(error)}")
      {:error, :query_exception}
  end

  # Ship analytics queries

  @doc """
  Get ship usage statistics for a character.

  Returns a map of ship type IDs to usage counts from killmail data.
  Uses the participants table with indexed character_id lookup.

  ## Parameters
    - `character_id` - EVE character ID

  ## Returns
    - `{:ok, %{ship_type_id => count}}` on success
    - `{:error, reason}` on failure
  """
  @spec get_ship_usage(integer()) :: {:ok, map()} | {:error, term()}
  def get_ship_usage(character_id) do
    query = """
    SELECT ship_type_id, COUNT(*) as usage_count
    FROM participants
    WHERE character_id = $1
      AND ship_type_id IS NOT NULL
    GROUP BY ship_type_id
    ORDER BY usage_count DESC
    """

    case Ecto.Adapters.SQL.query(Repo, query, [character_id]) do
      {:ok, %{rows: rows}} ->
        usage_map =
          rows
          |> Enum.map(fn [ship_type_id, count] -> {ship_type_id, count} end)
          |> Map.new()

        {:ok, usage_map}

      {:error, error} ->
        Logger.error("Ship usage query failed: #{inspect(error)}")
        {:error, :query_failed}
    end
  rescue
    error ->
      Logger.error("Ship usage query exception: #{inspect(error)}")
      {:error, :query_exception}
  end

  @doc """
  Get ship performance statistics for a character.

  Returns detailed statistics per ship type including kill/death ratios,
  average damage dealt, and ISK efficiency.

  ## Parameters
    - `character_id` - EVE character ID

  ## Returns
    - `{:ok, %{ship_type_id => ship_performance()}}` on success
    - `{:error, reason}` on failure
  """
  @spec get_ship_performance(integer()) :: {:ok, map()} | {:error, term()}
  def get_ship_performance(character_id) do
    query = """
    WITH ship_kills AS (
      SELECT
        p.ship_type_id,
        COUNT(DISTINCT p.killmail_id) as kills,
        AVG(COALESCE(p.damage_done, 0)) as avg_damage
      FROM participants p
      WHERE p.character_id = $1
        AND p.is_victim = false
        AND p.ship_type_id IS NOT NULL
      GROUP BY p.ship_type_id
    ),
    ship_losses AS (
      SELECT
        p.ship_type_id,
        COUNT(*) as losses
      FROM participants p
      WHERE p.character_id = $1
        AND p.is_victim = true
        AND p.ship_type_id IS NOT NULL
      GROUP BY p.ship_type_id
    )
    SELECT
      COALESCE(sk.ship_type_id, sl.ship_type_id) as ship_type_id,
      COALESCE(sk.kills, 0) as kills,
      COALESCE(sl.losses, 0) as losses,
      COALESCE(sk.avg_damage, 0) as avg_damage
    FROM ship_kills sk
    FULL OUTER JOIN ship_losses sl ON sk.ship_type_id = sl.ship_type_id
    ORDER BY (COALESCE(sk.kills, 0) + COALESCE(sl.losses, 0)) DESC
    """

    case Ecto.Adapters.SQL.query(Repo, query, [character_id]) do
      {:ok, %{rows: rows}} ->
        stats_map = build_ship_performance_map(rows)
        {:ok, stats_map}

      {:error, error} ->
        Logger.error("Ship performance query failed: #{inspect(error)}")
        {:error, :query_failed}
    end
  rescue
    error ->
      Logger.error("Ship performance query exception: #{inspect(error)}")
      {:error, :query_exception}
  end

  # Historical killmail queries

  @doc """
  Get historical killmails for a character.

  Uses optimized query with participants table index on (character_id, killmail_time)
  instead of slow jsonb_array_elements scan.

  ## Parameters
    - `character_id` - EVE character ID
    - `months` - Number of months to look back (default: 6)

  ## Returns
    - `{:ok, [historical_killmail()]}` on success
    - `{:error, reason}` on failure
  """
  @spec get_historical_killmails(integer(), integer()) ::
          {:ok, [historical_killmail()]} | {:error, term()}
  def get_historical_killmails(character_id, months \\ 6) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -months * 30 * 86_400, :second)

    query = """
    SELECT DISTINCT
      k.killmail_id,
      k.killmail_time,
      k.solar_system_id,
      k.victim_character_id,
      k.victim_ship_type_id,
      k.raw_data,
      k.total_value
    FROM participants p
    INNER JOIN killmails_raw k ON k.killmail_id = p.killmail_id AND k.killmail_time = p.killmail_time
    WHERE p.character_id = $1
      AND p.killmail_time > $2
    ORDER BY k.killmail_time DESC
    """

    case Ecto.Adapters.SQL.query(Repo, query, [character_id, cutoff_date]) do
      {:ok, %{rows: rows}} ->
        killmails =
          Enum.map(rows, fn [km_id, km_time, system_id, victim_id, ship_id, raw_data, value] ->
            %{
              killmail_id: km_id,
              killmail_time: km_time,
              solar_system_id: system_id,
              victim_character_id: victim_id,
              victim_ship_type_id: ship_id,
              raw_data: raw_data,
              total_value: value
            }
          end)

        {:ok, killmails}

      {:error, error} ->
        Logger.error("Historical killmails query failed: #{inspect(error)}")
        {:error, :query_failed}
    end
  rescue
    error ->
      Logger.error("Historical killmails query exception: #{inspect(error)}")
      {:error, :query_exception}
  end

  # Private helper functions

  defp build_ship_performance_map(rows) do
    rows
    |> Enum.map(fn [ship_type_id, kills, losses, avg_damage] ->
      kd_ratio = if losses > 0, do: kills / losses, else: kills * 1.0

      {ship_type_id,
       %{
         kills: kills,
         losses: losses,
         kd_ratio: Float.round(kd_ratio, 2),
         avg_damage: round(avg_damage)
       }}
    end)
    |> Map.new()
  end
end
