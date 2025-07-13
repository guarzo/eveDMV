defmodule EveDmv.Analytics.BattleDetector do
  @moduledoc """
  Detects and analyzes multi-participant battles from killmail data.

  A "battle" is defined as a cluster of killmails that occurred within a 
  short time window and geographical area with multiple participants.
  """

  alias EveDmv.Repo
  require Logger

  @doc """
  Detect recent battles for a specific character.

  Returns a list of battle summaries showing the character's participation
  in multi-pilot engagements.
  """
  def detect_character_battles(character_id, limit \\ 10) do
    Logger.info("Detecting battles for character #{character_id}")

    # Find killmails involving this character with multiple participants
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    query = """
    WITH character_killmails AS (
      SELECT 
        k.killmail_id,
        k.killmail_time,
        k.solar_system_id,
        k.solar_system_name,
        k.victim_character_id,
        k.victim_ship_type_id,
        k.victim_ship_type_name,
        k.total_value,
        k.attackers_character_ids,
        k.attackers_corporation_ids,
        k.attackers_alliance_ids,
        array_length(k.attackers_character_ids, 1) as attacker_count,
        CASE 
          WHEN k.victim_character_id = $1 THEN 'loss'
          WHEN $1 = ANY(k.attackers_character_ids) THEN 'kill'
          ELSE 'unknown'
        END as participation_type
      FROM killmails_raw k
      WHERE k.killmail_time >= $2
        AND (k.victim_character_id = $1 OR $1 = ANY(k.attackers_character_ids))
        AND array_length(k.attackers_character_ids, 1) >= 5  -- Multi-pilot engagements
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

        # Group nearby battles and enhance with context
        battles
        |> group_battles_by_proximity()
        |> enhance_with_battle_context()

      {:error, reason} ->
        Logger.error("Failed to detect battles: #{inspect(reason)}")
        []
    end
  end

  @doc """
  Detect recent battles for a corporation.

  Returns a list of battle summaries showing corporation member participation
  in multi-pilot engagements.
  """
  def detect_corporation_battles(corporation_id, limit \\ 10) do
    Logger.info("Detecting battles for corporation #{corporation_id}")

    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    query = """
    WITH corp_killmails AS (
      SELECT 
        k.killmail_id,
        k.killmail_time,
        k.solar_system_id,
        k.solar_system_name,
        k.victim_character_id,
        k.victim_corporation_id,
        k.victim_ship_type_id,
        k.victim_ship_type_name,
        k.total_value,
        k.attackers_character_ids,
        k.attackers_corporation_ids,
        k.attackers_alliance_ids,
        array_length(k.attackers_character_ids, 1) as attacker_count,
        CASE 
          WHEN k.victim_corporation_id = $1 THEN 'loss'
          WHEN $1 = ANY(k.attackers_corporation_ids) THEN 'kill'
          ELSE 'unknown'
        END as participation_type,
        -- Count corp members involved
        (
          SELECT COUNT(*)
          FROM unnest(k.attackers_corporation_ids) AS corp_id
          WHERE corp_id = $1
        ) as corp_members_involved
      FROM killmails_raw k
      WHERE k.killmail_time >= $2
        AND (k.victim_corporation_id = $1 OR $1 = ANY(k.attackers_corporation_ids))
        AND array_length(k.attackers_character_ids, 1) >= 5  -- Multi-pilot engagements
    ),
    battle_clusters AS (
      SELECT 
        cm.*,
        -- Group killmails that are close in time and space
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

        # Group nearby battles and enhance with corp context
        battles
        |> group_battles_by_proximity()
        |> enhance_with_corp_battle_context()

      {:error, reason} ->
        Logger.error("Failed to detect corp battles: #{inspect(reason)}")
        []
    end
  end

  @doc """
  Get corporation battle statistics and fleet preferences.
  """
  def get_corporation_battle_stats(corporation_id) do
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    query = """
    WITH corp_battles AS (
      SELECT 
        k.killmail_id,
        k.killmail_time,
        k.total_value,
        k.solar_system_id,
        array_length(k.attackers_character_ids, 1) as fleet_size,
        CASE 
          WHEN k.victim_corporation_id = $1 THEN 'loss'
          WHEN $1 = ANY(k.attackers_corporation_ids) THEN 'kill'
          ELSE 'unknown'
        END as participation_type,
        -- Count corp members involved in this killmail
        (
          SELECT COUNT(*)
          FROM unnest(k.attackers_corporation_ids) AS corp_id
          WHERE corp_id = $1
        ) as corp_members_involved
      FROM killmails_raw k
      WHERE k.killmail_time >= $2
        AND (k.victim_corporation_id = $1 OR $1 = ANY(k.attackers_corporation_ids))
        AND array_length(k.attackers_character_ids, 1) >= 5
    )
    SELECT 
      COUNT(*) as total_battles,
      COUNT(*) FILTER (WHERE participation_type = 'kill') as battles_won,
      COUNT(*) FILTER (WHERE participation_type = 'loss') as battles_lost,
      AVG(fleet_size) as avg_fleet_size,
      AVG(corp_members_involved) as avg_corp_participation,
      SUM(total_value) FILTER (WHERE participation_type = 'kill') as isk_destroyed_in_battles,
      SUM(total_value) FILTER (WHERE participation_type = 'loss') as isk_lost_in_battles,
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
        %{
          total_battles: total || 0,
          battles_won: won || 0,
          battles_lost: lost || 0,
          battle_efficiency: calculate_battle_efficiency(won || 0, lost || 0),
          avg_fleet_size: if(avg_fleet, do: Float.round(avg_fleet, 1), else: 0.0),
          avg_corp_participation: if(avg_corp, do: Float.round(avg_corp, 1), else: 0.0),
          isk_destroyed_in_battles: isk_destroyed || 0,
          isk_lost_in_battles: isk_lost || 0,
          systems_fought_in: systems || 0,
          max_corp_members_in_battle: max_members || 0,
          fleet_coordination: calculate_fleet_coordination(avg_corp, avg_fleet)
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

  @doc """
  Detect recent battles in a specific solar system.

  Returns a list of battle summaries for multi-pilot engagements that
  occurred in the specified system.
  """
  def detect_system_battles(system_id, limit \\ 10) do
    Logger.info("Detecting battles in system #{system_id}")

    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    query = """
    WITH system_killmails AS (
      SELECT 
        k.killmail_id,
        k.killmail_time,
        k.solar_system_id,
        k.solar_system_name,
        k.victim_character_id,
        k.victim_corporation_id,
        k.victim_alliance_id,
        k.victim_ship_type_id,
        k.victim_ship_type_name,
        k.total_value,
        k.attackers_character_ids,
        k.attackers_corporation_ids,
        k.attackers_alliance_ids,
        array_length(k.attackers_character_ids, 1) as attacker_count
      FROM killmails_raw k
      WHERE k.solar_system_id = $1
        AND k.killmail_time >= $2
        AND array_length(k.attackers_character_ids, 1) >= 5  -- Multi-pilot engagements
    ),
    battle_clusters AS (
      SELECT 
        km.*,
        -- Group killmails that are close in time (same hour)
        COUNT(*) OVER (
          PARTITION BY date_trunc('hour', km.killmail_time)
        ) as hour_activity
      FROM system_killmails km
    )
    SELECT 
      bc.*,
      CASE 
        WHEN bc.hour_activity >= 15 THEN 'major_battle'
        WHEN bc.hour_activity >= 8 THEN 'fleet_engagement'
        WHEN bc.hour_activity >= 4 THEN 'skirmish'
        WHEN bc.attacker_count >= 20 THEN 'large_gang'
        ELSE 'small_gang'
      END as battle_type
    FROM battle_clusters bc
    ORDER BY bc.killmail_time DESC
    LIMIT $3
    """

    case Repo.query(query, [system_id, thirty_days_ago, limit]) do
      {:ok, %{rows: rows, columns: columns}} ->
        battles =
          Enum.map(rows, fn row ->
            Map.new(Enum.zip(columns, row))
          end)

        # Group nearby battles and enhance with system context
        battles
        |> group_battles_by_proximity()
        |> enhance_with_system_battle_context()

      {:error, reason} ->
        Logger.error("Failed to detect system battles: #{inspect(reason)}")
        []
    end
  end

  @doc """
  Get system battle statistics and activity patterns.
  """
  def get_system_battle_stats(system_id) do
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    query = """
    WITH system_battles AS (
      SELECT 
        k.killmail_id,
        k.killmail_time,
        k.total_value,
        array_length(k.attackers_character_ids, 1) as fleet_size,
        array_length(k.attackers_corporation_ids, 1) as corp_count,
        array_length(k.attackers_alliance_ids, 1) as alliance_count,
        -- Battle intensity based on time clustering
        COUNT(*) OVER (
          PARTITION BY date_trunc('hour', k.killmail_time)
        ) as hour_activity
      FROM killmails_raw k
      WHERE k.solar_system_id = $1
        AND k.killmail_time >= $2
        AND array_length(k.attackers_character_ids, 1) >= 5
    )
    SELECT 
      COUNT(*) as total_battles,
      AVG(fleet_size) as avg_fleet_size,
      AVG(corp_count) as avg_corp_participation,
      AVG(alliance_count) as avg_alliance_participation,
      MAX(fleet_size) as max_fleet_size,
      MAX(hour_activity) as max_hourly_intensity,
      COUNT(DISTINCT DATE(killmail_time)) as battle_days,
      SUM(total_value) as total_isk_destroyed,
      COUNT(*) FILTER (WHERE hour_activity >= 10) as major_battle_count,
      COUNT(*) FILTER (WHERE hour_activity >= 5 AND hour_activity < 10) as medium_battle_count
    FROM system_battles
    """

    case Repo.query(query, [system_id, thirty_days_ago]) do
      {:ok,
       %{
         rows: [
           [
             total,
             avg_fleet,
             avg_corp,
             avg_alliance,
             max_fleet,
             max_intensity,
             battle_days,
             total_isk,
             major_count,
             medium_count
           ]
         ]
       }} ->
        %{
          total_battles: total || 0,
          avg_fleet_size: if(avg_fleet, do: Float.round(avg_fleet, 1), else: 0.0),
          avg_corp_participation: if(avg_corp, do: Float.round(avg_corp, 1), else: 0.0),
          avg_alliance_participation:
            if(avg_alliance, do: Float.round(avg_alliance, 1), else: 0.0),
          max_fleet_size: max_fleet || 0,
          max_hourly_intensity: max_intensity || 0,
          battle_days: battle_days || 0,
          total_isk_destroyed: total_isk || 0,
          major_battle_count: major_count || 0,
          medium_battle_count: medium_count || 0,
          small_battle_count: (total || 0) - (major_count || 0) - (medium_count || 0),
          battle_frequency: calculate_battle_frequency(total, battle_days),
          threat_level: calculate_system_threat_level(total, max_intensity, battle_days)
        }

      {:error, reason} ->
        Logger.error("Failed to get system battle stats: #{inspect(reason)}")

        %{
          total_battles: 0,
          avg_fleet_size: 0.0,
          avg_corp_participation: 0.0,
          avg_alliance_participation: 0.0,
          max_fleet_size: 0,
          max_hourly_intensity: 0,
          battle_days: 0,
          total_isk_destroyed: 0,
          major_battle_count: 0,
          medium_battle_count: 0,
          small_battle_count: 0,
          battle_frequency: "unknown",
          threat_level: "minimal"
        }
    end
  end

  @doc """
  Get corporation fleet doctrine preferences based on battle participation.
  """
  def get_corporation_fleet_doctrines(corporation_id) do
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    query = """
    SELECT 
      k.victim_ship_type_name as ship_type,
      COUNT(*) as usage_count,
      AVG(array_length(k.attackers_character_ids, 1)) as avg_fleet_size,
      SUM(k.total_value) as total_isk_involved
    FROM killmails_raw k
    WHERE k.killmail_time >= $2
      AND $1 = ANY(k.attackers_corporation_ids)
      AND array_length(k.attackers_character_ids, 1) >= 5
      AND k.victim_ship_type_name IS NOT NULL
    GROUP BY k.victim_ship_type_name
    HAVING COUNT(*) >= 2  -- At least 2 occurrences
    ORDER BY usage_count DESC
    LIMIT 10
    """

    case Repo.query(query, [corporation_id, thirty_days_ago]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [ship_type, count, avg_fleet, total_isk] ->
          %{
            ship_type: ship_type,
            usage_count: count,
            avg_fleet_size: if(avg_fleet, do: Float.round(avg_fleet, 1), else: 0.0),
            total_isk_involved: total_isk || 0,
            doctrine_preference: classify_doctrine_preference(ship_type, count, avg_fleet)
          }
        end)

      {:error, reason} ->
        Logger.error("Failed to get corp fleet doctrines: #{inspect(reason)}")
        []
    end
  end

  @doc """
  Get battle summary statistics for a character.
  """
  def get_character_battle_stats(character_id) do
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    query = """
    SELECT 
      COUNT(*) as total_battles,
      COUNT(*) FILTER (WHERE $1 = ANY(k.attackers_character_ids)) as battles_won,
      COUNT(*) FILTER (WHERE k.victim_character_id = $1) as battles_lost,
      AVG(array_length(k.attackers_character_ids, 1)) as avg_fleet_size,
      SUM(k.total_value) FILTER (WHERE $1 = ANY(k.attackers_character_ids)) as isk_destroyed_in_battles,
      SUM(k.total_value) FILTER (WHERE k.victim_character_id = $1) as isk_lost_in_battles
    FROM killmails_raw k
    WHERE k.killmail_time >= $2
      AND (k.victim_character_id = $1 OR $1 = ANY(k.attackers_character_ids))
      AND array_length(k.attackers_character_ids, 1) >= 5
    """

    case Repo.query(query, [character_id, thirty_days_ago]) do
      {:ok, %{rows: [[total, won, lost, avg_fleet, isk_destroyed, isk_lost]]}} ->
        %{
          total_battles: total || 0,
          battles_won: won || 0,
          battles_lost: lost || 0,
          battle_efficiency: calculate_battle_efficiency(won || 0, lost || 0),
          avg_fleet_size: if(avg_fleet, do: Float.round(avg_fleet, 1), else: 0.0),
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
          avg_fleet_size: 0.0,
          isk_destroyed_in_battles: 0,
          isk_lost_in_battles: 0
        }
    end
  end

  # Private functions

  defp group_battles_by_proximity(battles) do
    # Group battles that occurred within 30 minutes and in the same system
    battles
    |> Enum.group_by(fn battle ->
      system_id = Map.get(battle, "solar_system_id")
      time = Map.get(battle, "killmail_time")

      # Create time bucket (30-minute windows)
      time_bucket =
        if time do
          time
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.add(
            -rem(DateTime.to_unix(DateTime.from_naive!(time, "Etc/UTC")), 1800),
            :second
          )
          |> DateTime.to_unix()
        else
          0
        end

      {system_id, time_bucket}
    end)
    |> Enum.map(fn {_key, group_battles} ->
      # Create a battle summary from the group
      create_battle_summary(group_battles)
    end)
    |> Enum.sort_by(& &1.battle_time, {:desc, DateTime})
  end

  defp create_battle_summary(killmails) do
    first_km = List.first(killmails)

    total_isk =
      killmails
      |> Enum.map(&(Map.get(&1, "total_value") || 0))
      |> Enum.sum()

    participants =
      killmails
      |> Enum.flat_map(fn km ->
        attackers = Map.get(km, "attackers_character_ids") || []
        victim = [Map.get(km, "victim_character_id")]
        attackers ++ victim
      end)
      |> Enum.filter(& &1)
      |> Enum.uniq()
      |> length()

    %{
      battle_id: generate_battle_id(killmails),
      battle_time: Map.get(first_km, "killmail_time") |> parse_datetime(),
      solar_system_id: Map.get(first_km, "solar_system_id"),
      solar_system_name: Map.get(first_km, "solar_system_name"),
      killmail_count: length(killmails),
      total_isk_destroyed: total_isk,
      total_participants: participants,
      battle_type: determine_battle_type(length(killmails), participants, total_isk),
      character_participation: determine_character_participation(killmails),
      major_ships_involved: extract_major_ships(killmails)
    }
  end

  defp enhance_with_battle_context(battles) do
    # Add additional context like alliance involvement, ship types, etc.
    Enum.map(battles, fn battle ->
      Map.merge(battle, %{
        duration_estimate: estimate_battle_duration(battle.killmail_count),
        intensity_level:
          calculate_intensity(battle.total_isk_destroyed, battle.total_participants),
        recommended_analysis: recommend_analysis_type(battle)
      })
    end)
  end

  defp generate_battle_id(killmails) do
    first_km = List.first(killmails)
    time = Map.get(first_km, "killmail_time")
    system = Map.get(first_km, "solar_system_id")

    hash_input = "#{time}_#{system}_#{length(killmails)}"
    :crypto.hash(:md5, hash_input) |> Base.encode16() |> String.slice(0, 8)
  end

  defp parse_datetime(nil), do: DateTime.utc_now()

  defp parse_datetime(datetime_str) when is_binary(datetime_str) do
    case DateTime.from_iso8601(datetime_str) do
      {:ok, dt, _offset} -> dt
      {:error, _} -> DateTime.utc_now()
    end
  end

  defp parse_datetime(%DateTime{} = dt), do: dt
  defp parse_datetime(_), do: DateTime.utc_now()

  defp determine_battle_type(killmail_count, participants, total_isk) do
    cond do
      participants >= 100 -> "major_battle"
      participants >= 50 -> "fleet_engagement"
      participants >= 20 -> "medium_engagement"
      total_isk >= 1_000_000_000 -> "high_value_fight"
      killmail_count >= 10 -> "extended_skirmish"
      true -> "small_gang_fight"
    end
  end

  defp determine_character_participation(killmails) do
    kills =
      Enum.count(killmails, fn km ->
        Map.get(km, "participation_type") == "kill"
      end)

    losses =
      Enum.count(killmails, fn km ->
        Map.get(km, "participation_type") == "loss"
      end)

    %{
      kills: kills,
      losses: losses,
      role: if(kills > losses, do: "aggressor", else: "defender")
    }
  end

  defp extract_major_ships(killmails) do
    killmails
    |> Enum.map(&Map.get(&1, "victim_ship_type_name"))
    |> Enum.filter(& &1)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(3)
    |> Enum.map(&elem(&1, 0))
  end

  defp estimate_battle_duration(killmail_count) do
    cond do
      killmail_count >= 20 -> "30+ minutes"
      killmail_count >= 10 -> "15-30 minutes"
      killmail_count >= 5 -> "5-15 minutes"
      true -> "< 5 minutes"
    end
  end

  defp calculate_intensity(isk_destroyed, participants) do
    isk_per_pilot = if participants > 0, do: isk_destroyed / participants, else: 0

    cond do
      isk_per_pilot >= 100_000_000 -> "very_high"
      isk_per_pilot >= 50_000_000 -> "high"
      isk_per_pilot >= 20_000_000 -> "medium"
      true -> "low"
    end
  end

  defp recommend_analysis_type(battle) do
    cond do
      battle.battle_type in ["major_battle", "fleet_engagement"] ->
        "Full tactical analysis recommended"

      battle.intensity_level in ["very_high", "high"] ->
        "Economic impact analysis suggested"

      battle.total_participants >= 30 ->
        "Fleet composition analysis available"

      true ->
        "Basic engagement summary"
    end
  end

  defp enhance_with_system_battle_context(battles) do
    # Add system-specific context like strategic importance, escalation patterns
    Enum.map(battles, fn battle ->
      Map.merge(battle, %{
        strategic_importance: assess_strategic_importance(battle),
        escalation_pattern: assess_escalation_pattern(battle),
        dominant_forces: identify_dominant_forces(battle)
      })
    end)
  end

  defp enhance_with_corp_battle_context(battles) do
    # Add corporation-specific context like coordination metrics, fleet roles
    Enum.map(battles, fn battle ->
      Map.merge(battle, %{
        coordination_level: assess_coordination_level(battle),
        fleet_discipline: assess_fleet_discipline(battle),
        tactical_role: determine_corp_tactical_role(battle)
      })
    end)
  end

  defp assess_coordination_level(battle) do
    corp_participation = Map.get(battle, "corp_members_involved", 0)
    total_participants = Map.get(battle, "total_participants", 1)

    participation_ratio = corp_participation / total_participants

    cond do
      participation_ratio >= 0.5 -> "high_coordination"
      participation_ratio >= 0.25 -> "medium_coordination"
      participation_ratio >= 0.1 -> "low_coordination"
      true -> "minimal_participation"
    end
  end

  defp assess_fleet_discipline(battle) do
    # Assess based on battle duration and killmail clustering
    killmail_count = Map.get(battle, :killmail_count, 0)
    battle_type = Map.get(battle, :battle_type, "unknown")

    case {killmail_count, battle_type} do
      {count, "fleet_engagement"} when count >= 10 -> "disciplined"
      {count, "major_battle"} when count >= 15 -> "organized"
      {count, _} when count >= 5 -> "coordinated"
      _ -> "loose"
    end
  end

  defp determine_corp_tactical_role(battle) do
    participation_type = Map.get(battle, "participation_type")
    battle_type = Map.get(battle, :battle_type, "unknown")

    case {participation_type, battle_type} do
      {"kill", "fleet_engagement"} -> "primary_aggressor"
      {"kill", "major_battle"} -> "contributing_force"
      {"kill", _} -> "attacking_force"
      {"loss", "fleet_engagement"} -> "primary_defender"
      {"loss", "major_battle"} -> "defending_force"
      {"loss", _} -> "under_attack"
      _ -> "participant"
    end
  end

  defp calculate_fleet_coordination(avg_corp_participation, avg_fleet_size) do
    case {avg_corp_participation, avg_fleet_size} do
      {nil, _} -> "unknown"
      {_, nil} -> "unknown"
      {corp, fleet} when corp >= fleet * 0.5 -> "corp_dominated"
      {corp, fleet} when corp >= fleet * 0.25 -> "significant_presence"
      {corp, fleet} when corp >= fleet * 0.1 -> "active_participation"
      _ -> "limited_involvement"
    end
  end

  defp classify_doctrine_preference(ship_type, usage_count, avg_fleet_size) do
    cond do
      String.contains?(String.downcase(ship_type), "battleship") and avg_fleet_size >= 15 ->
        "capital_doctrine"

      String.contains?(String.downcase(ship_type), "cruiser") and avg_fleet_size >= 10 ->
        "mainline_doctrine"

      String.contains?(String.downcase(ship_type), "destroyer") and usage_count >= 5 ->
        "support_doctrine"

      String.contains?(String.downcase(ship_type), "frigate") and avg_fleet_size <= 8 ->
        "small_gang_doctrine"

      true ->
        "mixed_engagement"
    end
  end

  defp calculate_battle_efficiency(won, lost) do
    case {won, lost} do
      {0, 0} -> 0
      {w, 0} when w > 0 -> 100
      {0, l} when l > 0 -> 0
      {w, l} -> round(w / (w + l) * 100)
    end
  end

  # System-specific helper functions

  defp assess_strategic_importance(battle) do
    hour_activity = Map.get(battle, "hour_activity", 0)
    total_value = Map.get(battle, "total_value", 0)
    attacker_count = Map.get(battle, "attacker_count", 0)

    cond do
      hour_activity >= 15 and total_value >= 5_000_000_000 -> "critical"
      hour_activity >= 10 or total_value >= 2_000_000_000 -> "high"
      hour_activity >= 5 or attacker_count >= 30 -> "moderate"
      true -> "low"
    end
  end

  defp assess_escalation_pattern(battle) do
    hour_activity = Map.get(battle, "hour_activity", 0)
    attacker_count = Map.get(battle, "attacker_count", 0)

    case {hour_activity, attacker_count} do
      {activity, count} when activity >= 15 and count >= 50 -> "major_escalation"
      {activity, count} when activity >= 10 or count >= 30 -> "medium_escalation"
      {activity, count} when activity >= 5 or count >= 15 -> "minor_escalation"
      _ -> "isolated_incident"
    end
  end

  defp identify_dominant_forces(battle) do
    # This would typically analyze corporation/alliance participation
    # For now, provide a simple assessment based on fleet size
    attacker_count = Map.get(battle, "attacker_count", 0)

    cond do
      attacker_count >= 100 -> "major_coalition"
      attacker_count >= 50 -> "large_alliance"
      attacker_count >= 20 -> "corporation_fleet"
      attacker_count >= 10 -> "small_gang"
      true -> "solo_activity"
    end
  end

  defp calculate_battle_frequency(total_battles, battle_days) do
    cond do
      battle_days == 0 -> "none"
      total_battles / battle_days >= 3 -> "very_high"
      total_battles / battle_days >= 2 -> "high"
      total_battles / battle_days >= 1 -> "moderate"
      total_battles / battle_days >= 0.5 -> "low"
      true -> "minimal"
    end
  end

  defp calculate_system_threat_level(total_battles, max_intensity, battle_days) do
    # Up to 50 points for battle count
    # Up to 30 points for intensity
    # Up to 20 points for consistency
    threat_score =
      min(total_battles, 50) +
        min(max_intensity * 2, 30) +
        min(battle_days * 2, 20)

    cond do
      threat_score >= 80 -> "extreme"
      threat_score >= 60 -> "high"
      threat_score >= 40 -> "moderate"
      threat_score >= 20 -> "low"
      true -> "minimal"
    end
  end
end
