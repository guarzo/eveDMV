defmodule EveDmv.Database.QueryOptimizations do
  @moduledoc """
  Specific query optimizations for common EVE DMV operations.

  This module implements optimized query patterns to eliminate N+1 queries
  and improve overall database performance.
  """

  import Ecto.Query
  alias EveDmv.Repo
  require Logger

  @doc """
  Optimized bulk character analysis that avoids N+1 queries.

  Instead of analyzing each character individually (N queries),
  this loads all necessary data in batch operations.
  """
  def bulk_analyze_characters(character_ids) when is_list(character_ids) do
    # Load all character data in parallel batches
    tasks = [
      Task.async(fn -> batch_load_character_stats(character_ids) end),
      Task.async(fn -> batch_load_recent_activity(character_ids) end),
      Task.async(fn -> batch_load_affiliations(character_ids) end),
      Task.async(fn -> batch_load_ship_preferences(character_ids) end)
    ]

    # Wait for all tasks to complete
    [stats_map, activity_map, affiliations_map, ships_map] = Task.await_many(tasks, 10_000)

    # Combine results for each character
    character_ids
    |> Enum.map(fn char_id ->
      {
        char_id,
        %{
          stats: Map.get(stats_map, char_id, default_stats()),
          recent_activity: Map.get(activity_map, char_id, []),
          affiliations: Map.get(affiliations_map, char_id, []),
          ship_preferences: Map.get(ships_map, char_id, [])
        }
      }
    end)
    |> Map.new()
  end

  @doc """
  Batch load character statistics for multiple characters.
  """
  def batch_load_character_stats(character_ids) do
    query = """
    WITH character_stats AS (
      SELECT
        character_id,
        COUNT(CASE WHEN involvement_type = 'victim' THEN 1 END) as deaths,
        COUNT(CASE WHEN involvement_type = 'attacker' THEN 1 END) as kills,
        SUM(CASE WHEN involvement_type = 'victim' THEN total_value ELSE 0 END) as isk_lost,
        SUM(CASE WHEN involvement_type = 'attacker' THEN total_value ELSE 0 END) as isk_destroyed
      FROM (
        -- Victims
        SELECT
          victim_character_id as character_id,
          'victim' as involvement_type,
          COALESCE((raw_data->>'total_value')::numeric, 0) as total_value
        FROM killmails_raw
        WHERE victim_character_id = ANY($1)
          AND killmail_time >= NOW() - INTERVAL '90 days'

        UNION ALL

        -- Attackers (using indexed JSONB query)
        SELECT
          (attacker->>'character_id')::bigint as character_id,
          'attacker' as involvement_type,
          COALESCE((raw_data->>'total_value')::numeric, 0) /
            jsonb_array_length(raw_data->'attackers') as total_value
        FROM killmails_raw,
             LATERAL jsonb_array_elements(raw_data->'attackers') as attacker
        WHERE (attacker->>'character_id')::bigint = ANY($1)
          AND killmail_time >= NOW() - INTERVAL '90 days'
      ) as involvements
      GROUP BY character_id
    )
    SELECT * FROM character_stats
    """

    case Repo.query(query, [character_ids]) do
      {:ok, %{rows: rows, columns: columns}} ->
        rows
        |> Enum.map(fn row ->
          stats = Enum.zip(columns, row) |> Map.new()
          {stats["character_id"], stats}
        end)
        |> Map.new()

      {:error, error} ->
        Logger.error("Failed to batch load character stats: #{inspect(error)}")
        %{}
    end
  end

  @doc """
  Batch load recent activity for multiple characters.
  """
  def batch_load_recent_activity(character_ids, limit \\ 10) do
    query = """
    WITH ranked_activity AS (
      SELECT
        character_id,
        killmail_id,
        killmail_time,
        solar_system_id,
        involvement_type,
        ship_type_id,
        total_value,
        ROW_NUMBER() OVER (PARTITION BY character_id ORDER BY killmail_time DESC) as rn
      FROM (
        -- Victims
        SELECT
          victim_character_id as character_id,
          killmail_id,
          killmail_time,
          solar_system_id,
          'loss' as involvement_type,
          victim_ship_type_id as ship_type_id,
          COALESCE((raw_data->>'total_value')::numeric, 0) as total_value
        FROM killmails_raw
        WHERE victim_character_id = ANY($1)

        UNION ALL

        -- Attackers
        SELECT
          (attacker->>'character_id')::bigint as character_id,
          k.killmail_id,
          k.killmail_time,
          k.solar_system_id,
          'kill' as involvement_type,
          k.victim_ship_type_id as ship_type_id,
          COALESCE((k.raw_data->>'total_value')::numeric, 0) as total_value
        FROM killmails_raw k,
             LATERAL jsonb_array_elements(k.raw_data->'attackers') as attacker
        WHERE (attacker->>'character_id')::bigint = ANY($1)
      ) as all_activity
    )
    SELECT
      character_id,
      killmail_id,
      killmail_time,
      solar_system_id,
      involvement_type,
      ship_type_id,
      total_value
    FROM ranked_activity
    WHERE rn <= $2
    ORDER BY character_id, killmail_time DESC
    """

    case Repo.query(query, [character_ids, limit]) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.group_by(fn [char_id | _] -> char_id end)
        |> Enum.map(fn {char_id, activities} ->
          mapped_activities =
            Enum.map(activities, fn [_, km_id, time, sys_id, type, ship, value] ->
              %{
                killmail_id: km_id,
                killmail_time: time,
                solar_system_id: sys_id,
                involvement_type: type,
                ship_type_id: ship,
                total_value: value
              }
            end)

          {char_id, mapped_activities}
        end)
        |> Map.new()

      {:error, error} ->
        Logger.error("Failed to batch load recent activity: #{inspect(error)}")
        %{}
    end
  end

  @doc """
  Batch load affiliations for multiple characters.
  """
  def batch_load_affiliations(character_ids) do
    query = """
    WITH character_affiliations AS (
      SELECT DISTINCT
        victim_character_id as character_id,
        victim_corporation_id as corporation_id,
        victim_corporation_name as corporation_name,
        victim_alliance_id as alliance_id,
        victim_alliance_name as alliance_name,
        FIRST_VALUE(killmail_time) OVER (
          PARTITION BY victim_character_id, victim_corporation_id
          ORDER BY killmail_time DESC
        ) as last_seen
      FROM killmails_raw
      WHERE victim_character_id = ANY($1)
        AND victim_corporation_id IS NOT NULL
    )
    SELECT
      character_id,
      corporation_id,
      corporation_name,
      alliance_id,
      alliance_name,
      last_seen
    FROM character_affiliations
    ORDER BY character_id, last_seen DESC
    """

    case Repo.query(query, [character_ids]) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.group_by(fn [char_id | _] -> char_id end)
        |> Enum.map(fn {char_id, affiliations} ->
          mapped_affiliations =
            Enum.map(affiliations, fn [_, corp_id, corp_name, ally_id, ally_name, last_seen] ->
              %{
                corporation_id: corp_id,
                corporation_name: corp_name,
                alliance_id: ally_id,
                alliance_name: ally_name,
                last_seen: last_seen
              }
            end)

          {char_id, mapped_affiliations}
        end)
        |> Map.new()

      {:error, error} ->
        Logger.error("Failed to batch load affiliations: #{inspect(error)}")
        %{}
    end
  end

  @doc """
  Batch load ship preferences for multiple characters.
  """
  def batch_load_ship_preferences(character_ids, limit \\ 5) do
    query = """
    WITH ship_usage AS (
      SELECT
        character_id,
        ship_type_id,
        COUNT(*) as usage_count,
        COUNT(CASE WHEN involvement_type = 'kill' THEN 1 END) as kill_count,
        COUNT(CASE WHEN involvement_type = 'loss' THEN 1 END) as loss_count
      FROM (
        -- Ships lost
        SELECT
          victim_character_id as character_id,
          victim_ship_type_id as ship_type_id,
          'loss' as involvement_type
        FROM killmails_raw
        WHERE victim_character_id = ANY($1)
          AND killmail_time >= NOW() - INTERVAL '90 days'

        UNION ALL

        -- Ships used in kills
        SELECT
          (attacker->>'character_id')::bigint as character_id,
          (attacker->>'ship_type_id')::bigint as ship_type_id,
          'kill' as involvement_type
        FROM killmails_raw,
             LATERAL jsonb_array_elements(raw_data->'attackers') as attacker
        WHERE (attacker->>'character_id')::bigint = ANY($1)
          AND (attacker->>'ship_type_id') IS NOT NULL
          AND killmail_time >= NOW() - INTERVAL '90 days'
      ) as all_ships
      WHERE ship_type_id IS NOT NULL
      GROUP BY character_id, ship_type_id
    ),
    ranked_ships AS (
      SELECT
        character_id,
        ship_type_id,
        usage_count,
        kill_count,
        loss_count,
        ROW_NUMBER() OVER (PARTITION BY character_id ORDER BY usage_count DESC) as rank
      FROM ship_usage
    )
    SELECT
      rs.character_id,
      rs.ship_type_id,
      rs.usage_count,
      rs.kill_count,
      rs.loss_count,
      COALESCE(eit.type_name, 'Unknown') as ship_name
    FROM ranked_ships rs
    LEFT JOIN eve_item_types eit ON eit.type_id = rs.ship_type_id
    WHERE rank <= $2
    ORDER BY character_id, usage_count DESC
    """

    case Repo.query(query, [character_ids, limit]) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.group_by(fn [char_id | _] -> char_id end)
        |> Enum.map(fn {char_id, ships} ->
          mapped_ships =
            Enum.map(ships, fn [_, ship_id, usage, kills, losses, name] ->
              %{
                ship_type_id: ship_id,
                ship_name: name,
                usage_count: usage,
                kill_count: kills,
                loss_count: losses,
                effectiveness: calculate_effectiveness(kills, losses)
              }
            end)

          {char_id, mapped_ships}
        end)
        |> Map.new()

      {:error, error} ->
        Logger.error("Failed to batch load ship preferences: #{inspect(error)}")
        %{}
    end
  end

  # Helper functions

  defp default_stats do
    %{
      "kills" => 0,
      "deaths" => 0,
      "isk_lost" => 0,
      "isk_destroyed" => 0
    }
  end

  defp calculate_effectiveness(kills, losses) when losses > 0 do
    Float.round(kills / losses, 2)
  end

  defp calculate_effectiveness(kills, 0) when kills > 0, do: kills
  defp calculate_effectiveness(_, _), do: 0.0

  @doc """
  Optimize LiveView data loading by preloading all associations.

  This prevents N+1 queries when rendering lists in LiveView.
  """
  def preload_for_liveview(query, associations) do
    # Use left joins to avoid N+1 queries
    associations
    |> Enum.reduce(query, fn assoc, acc ->
      case assoc do
        :participants ->
          acc
          |> join(:left, [k], p in assoc(k, :participants))
          |> preload([k, p], participants: p)

        :victim ->
          acc
          |> join(:left, [k], v in assoc(k, :victim))
          |> preload([k, v], victim: v)

        :attackers ->
          acc
          |> join(:left, [k], a in assoc(k, :attackers))
          |> preload([k, a], attackers: a)

        _ ->
          preload(acc, ^assoc)
      end
    end)
  end
end
