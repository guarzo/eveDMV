defmodule EveDmv.Database.CharacterQueries do
  @moduledoc """
  Optimized queries for character analysis.

  Uses materialized views and efficient indexing to avoid expensive JSONB operations.
  """

  alias EveDmv.Repo
  alias EveDmv.Database.Pagination
  alias EveDmv.Cache.QueryCache
  require Logger

  @doc """
  Get kill and death counts for a character using optimized queries.
  Cached for performance.
  """
  def get_character_stats(character_id, since_date) do
    cache_key = "char_stats:#{character_id}:#{Date.to_iso8601(since_date)}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        # Deaths are easy - we have a direct column
        deaths_query = """
        SELECT COUNT(*) as death_count
        FROM killmails_raw
        WHERE victim_character_id = $1
          AND killmail_time >= $2
        """

        # For kills, we need to check the raw_data
        # But we'll limit the search to recent killmails for performance
        kills_query = """
        WITH character_kills AS (
          SELECT killmail_id
          FROM killmails_raw
          WHERE killmail_time >= $2
            AND raw_data @> jsonb_build_object(
              'attackers', jsonb_build_array(
                jsonb_build_object('character_id', $1::text)
              )
            )
          LIMIT 1000
        )
        SELECT COUNT(*) as kill_count FROM character_kills
        """

        # Run queries
        {:ok, %{rows: [[death_count]]}} = Repo.query(deaths_query, [character_id, since_date])

        {:ok, %{rows: [[kill_count]]}} =
          Repo.query(kills_query, [to_string(character_id), since_date])

        %{
          kills: kill_count,
          deaths: death_count,
          kd_ratio: calculate_kd_ratio(kill_count, death_count)
        }
      end,
      ttl: :timer.hours(1)
    )
  end

  @doc """
  Get character's recent activity without expensive JSONB operations.
  Supports pagination.
  """
  def get_recent_activity(character_id, opts \\ []) do
    base_query = """
    SELECT 
      killmail_id,
      killmail_time,
      solar_system_id,
      CASE 
        WHEN victim_character_id = $1 THEN 'loss'
        ELSE 'kill'
      END as involvement_type,
      victim_ship_type_id as ship_type_id,
      COALESCE((raw_data->>'total_value')::numeric, 0) as total_value
    FROM killmails_raw
    WHERE victim_character_id = $1 
       OR EXISTS (
         SELECT 1 
         FROM jsonb_array_elements(raw_data->'attackers') as attacker
         WHERE attacker->>'character_id' = $2
       )
    ORDER BY killmail_time DESC
    """

    # Handle both old limit-based and new pagination-based calls
    case opts do
      limit when is_integer(limit) ->
        # Legacy support
        query = base_query <> " LIMIT $3"

        case Repo.query(query, [character_id, to_string(character_id), limit]) do
          {:ok, %{rows: rows}} ->
            map_activity_rows(rows)

          {:error, error} ->
            Logger.error("Failed to get recent activity: #{inspect(error)}")
            []
        end

      opts when is_list(opts) ->
        # New pagination support
        result =
          Pagination.paginated_query(
            base_query,
            [character_id, to_string(character_id)],
            opts
          )

        %{
          data: map_activity_rows(result.data),
          pagination: result.pagination
        }
    end
  end

  defp map_activity_rows(rows) do
    Enum.map(rows, fn row ->
      case row do
        [km_id, km_time, system_id, involvement, ship_id, value] ->
          %{
            killmail_id: km_id,
            killmail_time: km_time,
            solar_system_id: system_id,
            involvement_type: involvement,
            ship_type_id: ship_id,
            total_value: Decimal.to_float(value || Decimal.new(0))
          }

        [km_id, km_time, system_id, involvement, ship_id] ->
          # Legacy format without value
          %{
            killmail_id: km_id,
            killmail_time: km_time,
            solar_system_id: system_id,
            involvement_type: involvement,
            ship_type_id: ship_id,
            total_value: 0.0
          }
      end
    end)
  end

  @doc """
  Get character name from recent killmails.
  """
  def get_character_name_from_killmails(character_id) do
    # First check if they're a victim
    victim_query = """
    SELECT raw_data->'victim'->>'character_name'
    FROM killmails_raw
    WHERE victim_character_id = $1
    LIMIT 1
    """

    case Repo.query(victim_query, [character_id]) do
      {:ok, %{rows: [[name]]}} when not is_nil(name) ->
        name

      _ ->
        # Check attackers
        attacker_query = """
        SELECT attacker->>'character_name'
        FROM killmails_raw,
             jsonb_array_elements(raw_data->'attackers') as attacker
        WHERE attacker->>'character_id' = $1
        LIMIT 1
        """

        case Repo.query(attacker_query, [to_string(character_id)]) do
          {:ok, %{rows: [[name]]}} when not is_nil(name) -> name
          _ -> nil
        end
    end
  end

  @doc """
  Get corporation and alliance info from killmails.
  """
  def get_character_affiliations(character_id) do
    query = """
    WITH recent_data AS (
      SELECT 
        raw_data->'victim' as victim_data,
        killmail_time
      FROM killmails_raw
      WHERE victim_character_id = $1
      ORDER BY killmail_time DESC
      LIMIT 1
    ),
    attacker_data AS (
      SELECT 
        attacker as attacker_data,
        killmail_time
      FROM killmails_raw,
           jsonb_array_elements(raw_data->'attackers') as attacker
      WHERE attacker->>'character_id' = $2
      ORDER BY killmail_time DESC
      LIMIT 1
    )
    SELECT 
      COALESCE(
        (SELECT victim_data->>'corporation_name' FROM recent_data),
        (SELECT attacker_data->>'corporation_name' FROM attacker_data)
      ) as corp_name,
      COALESCE(
        (SELECT victim_data->>'corporation_id' FROM recent_data),
        (SELECT attacker_data->>'corporation_id' FROM attacker_data)
      )::integer as corp_id,
      COALESCE(
        (SELECT victim_data->>'alliance_name' FROM recent_data),
        (SELECT attacker_data->>'alliance_name' FROM attacker_data)
      ) as alliance_name,
      COALESCE(
        (SELECT victim_data->>'alliance_id' FROM recent_data),
        (SELECT attacker_data->>'alliance_id' FROM attacker_data)
      )::integer as alliance_id
    """

    case Repo.query(query, [character_id, to_string(character_id)]) do
      {:ok, %{rows: [[corp_name, corp_id, alliance_name, alliance_id]]}} ->
        %{
          corporation_name: corp_name,
          corporation_id: corp_id,
          alliance_name: alliance_name,
          alliance_id: alliance_id
        }

      _ ->
        %{
          corporation_name: nil,
          corporation_id: nil,
          alliance_name: nil,
          alliance_id: nil
        }
    end
  end

  defp calculate_kd_ratio(kills, deaths) when deaths > 0 do
    Float.round(kills / deaths, 2)
  end

  defp calculate_kd_ratio(kills, _deaths), do: kills
end
