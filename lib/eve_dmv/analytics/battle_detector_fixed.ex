defmodule EveDmv.Analytics.BattleDetectorFixed do
  @moduledoc """
  Fixed version of BattleDetector that uses the correct database schema.

  A "battle" is defined as a cluster of killmails that occurred within a 
  short time window and geographical area with multiple participants.
  """

  alias EveDmv.Repo
  require Logger

  @doc """
  Detect recent battles for a specific character using correct schema.
  """
  def detect_character_battles(character_id, limit \\ 10) do
    Logger.info("Detecting battles for character #{character_id}")

    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    # Use participants table to find multi-pilot killmails involving this character
    query = """
    WITH character_killmails AS (
      SELECT DISTINCT
        km.killmail_id,
        km.killmail_time,
        km.solar_system_id,
        km.raw_data->>'solar_system_name' as solar_system_name,
        km.victim_character_id,
        km.victim_ship_type_id,
        (km.raw_data->'zkb'->>'totalValue')::numeric::bigint as total_value,
        km.attacker_count,
        CASE 
          WHEN km.victim_character_id = $1 THEN 'loss'
          ELSE 'kill'
        END as participation_type
      FROM killmails_raw km
      INNER JOIN participants p ON p.killmail_id = km.killmail_id
      WHERE km.killmail_time >= $2
        AND (km.victim_character_id = $1 OR p.character_id = $1)
        AND km.attacker_count >= 5  -- Multi-pilot engagements
    ),
    battle_clusters AS (
      SELECT 
        cm.*,
        -- Group killmails that are close in time and space
        COUNT(*) OVER (
          PARTITION BY cm.solar_system_id,
          date_trunc('hour', cm.killmail_time)
        ) as system_hour_activity
      FROM character_killmails cm
    )
    SELECT 
      bc.*,
      CASE 
        WHEN bc.system_hour_activity >= 10 THEN 'major_battle'
        WHEN bc.system_hour_activity >= 5 THEN 'skirmish'
        WHEN bc.attacker_count >= 20 THEN 'fleet_engagement'
        ELSE 'small_gang'
      END as battle_type
    FROM battle_clusters bc
    ORDER BY bc.killmail_time DESC
    LIMIT $3
    """

    case Repo.query(query, [character_id, thirty_days_ago, limit]) do
      {:ok, %{rows: rows, columns: columns}} ->
        battles =
          Enum.map(rows, fn row ->
            Map.new(Enum.zip(columns, row))
          end)

        # Add battle context
        enhance_character_battles(battles, character_id)

      {:error, reason} ->
        Logger.error("Failed to detect battles: #{inspect(reason)}")
        []
    end
  end

  @doc """
  Get character battle statistics using correct schema.
  """
  def get_character_battle_stats(character_id) do
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    query = """
    WITH character_battles AS (
      SELECT 
        km.killmail_id,
        km.killmail_time,
        (km.raw_data->'zkb'->>'totalValue')::numeric::bigint as total_value,
        km.attacker_count,
        CASE 
          WHEN km.victim_character_id = $1 THEN 'loss'
          ELSE 'kill'
        END as participation_type
      FROM killmails_raw km
      INNER JOIN participants p ON p.killmail_id = km.killmail_id
      WHERE km.killmail_time >= $2
        AND (km.victim_character_id = $1 OR p.character_id = $1)
        AND km.attacker_count >= 5
    )
    SELECT 
      COUNT(*) as total_battles,
      COUNT(*) FILTER (WHERE participation_type = 'kill') as battles_won,
      COUNT(*) FILTER (WHERE participation_type = 'loss') as battles_lost,
      AVG(attacker_count) as avg_fleet_size,
      COALESCE(SUM(total_value) FILTER (WHERE participation_type = 'kill'), 0) as isk_destroyed_in_battles,
      COALESCE(SUM(total_value) FILTER (WHERE participation_type = 'loss'), 0) as isk_lost_in_battles
    FROM character_battles
    """

    case Repo.query(query, [character_id, thirty_days_ago]) do
      {:ok, %{rows: [[total, won, lost, avg_fleet, isk_destroyed, isk_lost]]}} ->
        battle_efficiency = if total > 0, do: round(won / total * 100), else: 0

        %{
          total_battles: total || 0,
          battles_won: won || 0,
          battles_lost: lost || 0,
          battle_efficiency: battle_efficiency,
          avg_fleet_size: if(avg_fleet, do: round(avg_fleet), else: 0),
          isk_destroyed_in_battles: isk_destroyed || 0,
          isk_lost_in_battles: isk_lost || 0
        }

      {:error, reason} ->
        Logger.error("Failed to get battle stats: #{inspect(reason)}")

        %{
          total_battles: 0,
          battles_won: 0,
          battles_lost: 0,
          battle_efficiency: 0,
          avg_fleet_size: 0,
          isk_destroyed_in_battles: 0,
          isk_lost_in_battles: 0
        }
    end
  end

  @doc """
  Detect recent battles for a corporation using correct schema.
  """
  def detect_corporation_battles(corporation_id, limit \\ 10) do
    Logger.info("Detecting battles for corporation #{corporation_id}")

    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    query = """
    WITH corp_killmails AS (
      SELECT DISTINCT
        km.killmail_id,
        km.killmail_time,
        km.solar_system_id,
        km.raw_data->>'solar_system_name' as solar_system_name,
        km.victim_character_id,
        km.victim_corporation_id,
        km.victim_ship_type_id,
        (km.raw_data->'zkb'->>'totalValue')::numeric::bigint as total_value,
        km.attacker_count,
        CASE 
          WHEN km.victim_corporation_id = $1 THEN 'loss'
          ELSE 'kill'
        END as participation_type,
        -- Count corp members involved in this killmail
        (
          SELECT COUNT(*)
          FROM participants p2
          WHERE p2.killmail_id = km.killmail_id 
            AND p2.corporation_id = $1
            AND p2.is_victim = false
        ) as corp_members_involved
      FROM killmails_raw km
      INNER JOIN participants p ON p.killmail_id = km.killmail_id
      WHERE km.killmail_time >= $2
        AND (km.victim_corporation_id = $1 OR p.corporation_id = $1)
        AND km.attacker_count >= 5
    ),
    battle_clusters AS (
      SELECT 
        cm.*,
        COUNT(*) OVER (
          PARTITION BY cm.solar_system_id,
          date_trunc('hour', cm.killmail_time)
        ) as system_hour_activity
      FROM corp_killmails cm
    )
    SELECT 
      bc.*,
      CASE 
        WHEN bc.system_hour_activity >= 10 THEN 'major_battle'
        WHEN bc.system_hour_activity >= 5 THEN 'skirmish'
        WHEN bc.attacker_count >= 20 THEN 'fleet_engagement'
        ELSE 'small_gang'
      END as battle_type
    FROM battle_clusters bc
    ORDER BY bc.killmail_time DESC
    LIMIT $3
    """

    case Repo.query(query, [corporation_id, thirty_days_ago, limit]) do
      {:ok, %{rows: rows, columns: columns}} ->
        battles =
          Enum.map(rows, fn row ->
            Map.new(Enum.zip(columns, row))
          end)

        enhance_corporation_battles(battles, corporation_id)

      {:error, reason} ->
        Logger.error("Failed to detect corp battles: #{inspect(reason)}")
        []
    end
  end

  @doc """
  Get corporation battle statistics using correct schema.
  """
  def get_corporation_battle_stats(corporation_id) do
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    query = """
    WITH corp_battles AS (
      SELECT 
        km.killmail_id,
        km.killmail_time,
        (km.raw_data->'zkb'->>'totalValue')::numeric::bigint as total_value,
        km.solar_system_id,
        km.attacker_count,
        CASE 
          WHEN km.victim_corporation_id = $1 THEN 'loss'
          ELSE 'kill'
        END as participation_type,
        (
          SELECT COUNT(*)
          FROM participants p2
          WHERE p2.killmail_id = km.killmail_id 
            AND p2.corporation_id = $1
            AND p2.is_victim = false
        ) as corp_members_involved
      FROM killmails_raw km
      INNER JOIN participants p ON p.killmail_id = km.killmail_id
      WHERE km.killmail_time >= $2
        AND (km.victim_corporation_id = $1 OR p.corporation_id = $1)
        AND km.attacker_count >= 5
    )
    SELECT 
      COUNT(*) as total_battles,
      COUNT(*) FILTER (WHERE participation_type = 'kill') as battles_won,
      COUNT(*) FILTER (WHERE participation_type = 'loss') as battles_lost,
      AVG(attacker_count) as avg_fleet_size,
      AVG(corp_members_involved) as avg_corp_participation,
      COALESCE(SUM(total_value) FILTER (WHERE participation_type = 'kill'), 0) as isk_destroyed_in_battles,
      COALESCE(SUM(total_value) FILTER (WHERE participation_type = 'loss'), 0) as isk_lost_in_battles,
      COUNT(DISTINCT solar_system_id) as systems_fought_in,
      MAX(corp_members_involved) as max_corp_members_in_battle
    FROM corp_battles
    """

    case Repo.query(query, [corporation_id, thirty_days_ago]) do
      {:ok,
       %{
         rows: [
           [total, won, lost, avg_fleet, avg_corp, isk_destroyed, isk_lost, systems, max_members]
         ]
       }} ->
        battle_efficiency = if total > 0, do: round(won / total * 100), else: 0

        fleet_coordination =
          cond do
            avg_corp && avg_corp >= 5 -> "corp_dominated"
            avg_corp && avg_corp >= 3 -> "significant_presence"
            avg_corp && avg_corp >= 1 -> "active_participation"
            true -> "unknown"
          end

        %{
          total_battles: total || 0,
          battles_won: won || 0,
          battles_lost: lost || 0,
          battle_efficiency: battle_efficiency,
          avg_fleet_size: if(avg_fleet, do: round(avg_fleet), else: 0),
          avg_corp_participation: if(avg_corp, do: Float.round(avg_corp, 1), else: 0.0),
          isk_destroyed_in_battles: isk_destroyed || 0,
          isk_lost_in_battles: isk_lost || 0,
          systems_fought_in: systems || 0,
          max_corp_members_in_battle: max_members || 0,
          fleet_coordination: fleet_coordination
        }

      {:error, reason} ->
        Logger.error("Failed to get corp battle stats: #{inspect(reason)}")

        %{
          total_battles: 0,
          battles_won: 0,
          battles_lost: 0,
          battle_efficiency: 0,
          avg_fleet_size: 0.0,
          avg_corp_participation: 0.0,
          isk_destroyed_in_battles: 0,
          isk_lost_in_battles: 0,
          systems_fought_in: 0,
          max_corp_members_in_battle: 0,
          fleet_coordination: "unknown"
        }
    end
  end

  # Test function to verify the fixes work
  def test_fixed_queries() do
    IO.puts("🧪 Testing Fixed BattleDetector Queries")

    # Get sample character
    {:ok, result} =
      Repo.query(
        "SELECT character_id FROM participants WHERE character_id IS NOT NULL LIMIT 1",
        []
      )

    case result.rows do
      [[character_id]] ->
        IO.puts("Testing with character #{character_id}")

        battles = detect_character_battles(character_id, 2)
        IO.puts("✅ Character battles: #{length(battles)} found")

        stats = get_character_battle_stats(character_id)
        IO.puts("✅ Character stats: #{inspect(stats)}")

      [] ->
        IO.puts("❌ No character data found")
    end

    # Get sample corporation
    {:ok, corp_result} =
      Repo.query(
        "SELECT corporation_id FROM participants WHERE corporation_id IS NOT NULL LIMIT 1",
        []
      )

    case corp_result.rows do
      [[corp_id]] ->
        IO.puts("Testing with corporation #{corp_id}")

        corp_battles = detect_corporation_battles(corp_id, 2)
        IO.puts("✅ Corporation battles: #{length(corp_battles)} found")

        corp_stats = get_corporation_battle_stats(corp_id)
        IO.puts("✅ Corporation stats: #{inspect(corp_stats)}")

      [] ->
        IO.puts("❌ No corporation data found")
    end

    IO.puts("🎉 Fixed query testing complete!")
  end

  # Helper functions
  defp enhance_character_battles(battles, _character_id) do
    Enum.map(battles, fn battle ->
      battle
      |> Map.put(:character_participation, %{
        role: Map.get(battle, "participation_type", "unknown"),
        kills: if(Map.get(battle, "participation_type") == "kill", do: 1, else: 0),
        losses: if(Map.get(battle, "participation_type") == "loss", do: 1, else: 0)
      })
      |> Map.put(:battle_time, Map.get(battle, "killmail_time"))
      |> Map.put(:total_participants, Map.get(battle, "attacker_count", 0))
      # Each row is one killmail
      |> Map.put(:killmail_count, 1)
      |> Map.put(:total_isk_destroyed, Map.get(battle, "total_value", 0))
      |> atomize_keys()
    end)
  end

  defp enhance_corporation_battles(battles, _corporation_id) do
    Enum.map(battles, fn battle ->
      battle
      |> Map.put(:battle_time, Map.get(battle, "killmail_time"))
      |> Map.put(:total_participants, Map.get(battle, "attacker_count", 0))
      # Each row is one killmail
      |> Map.put(:killmail_count, 1)
      |> Map.put(:total_isk_destroyed, Map.get(battle, "total_value", 0))
      |> Map.put(
        :coordination_level,
        determine_coordination_level(Map.get(battle, "corp_members_involved", 0))
      )
      |> atomize_keys()
    end)
  end

  defp determine_coordination_level(members_involved) when is_integer(members_involved) do
    cond do
      members_involved >= 10 -> "high_coordination"
      members_involved >= 5 -> "medium_coordination"
      members_involved >= 2 -> "basic_coordination"
      true -> "solo_operation"
    end
  end

  defp determine_coordination_level(_), do: "unknown"

  defp atomize_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)
    |> Enum.into(%{})
  end
end
