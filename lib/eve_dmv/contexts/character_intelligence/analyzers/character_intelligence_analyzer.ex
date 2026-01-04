defmodule EveDmv.Contexts.CharacterIntelligence.Analyzers.CharacterIntelligenceAnalyzer do
  @moduledoc """
  Consolidated character intelligence analyzer.

  This module combines all character intelligence analysis functions that were previously
  split across multiple analyzer modules:
  - WeaponPreferenceAnalyzer
  - ShipPreferenceAnalyzer
  - GangPatternAnalyzer
  - ActivityStatsAnalyzer
  - IskEfficiencyAnalyzer
  - IntelligenceSummaryAnalyzer

  All analysis functions use cached queries for performance and return structured
  intelligence data about character combat patterns and behaviors.
  """

  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Core.Utils.NumericUtils
  alias EveDmv.Platform.Cache.QueryCache
  alias EveDmv.Shared.KillmailQueries
  alias EveDmv.StaticData
  require Logger

  # Cache TTLs for different analysis types
  @weapon_preferences_ttl :timer.hours(2)
  @ship_preferences_ttl :timer.hours(2)
  @gang_patterns_ttl :timer.hours(6)
  @activity_stats_ttl :timer.hours(4)
  @isk_efficiency_ttl :timer.hours(1)
  @intelligence_summary_ttl :timer.minutes(30)

  @doc """
  Analyze ship loadouts - weapons grouped by ship from actual killmail data.

  Returns only weapons we've actually seen the character use on each ship.
  No inference or guessing - purely data-driven.
  """
  def analyze_ship_loadouts(character_id, since_date) do
    cache_key =
      "ship_loadouts:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        # Query to get weapons used per ship from attacker data in killmails
        # We can only know what weapons they used when they were an ATTACKER
        # because that's what gets recorded in the killmail
        # Also includes death counts for each ship type
        loadout_query = """
        WITH character_kills AS (
          -- Get killmails where character was an attacker
          SELECT DISTINCT p.killmail_id, p.killmail_time
          FROM participants p
          WHERE p.character_id = $3
            AND p.killmail_time >= $2
            AND p.is_victim = false
        ),
        character_deaths AS (
          -- Get killmails where character died (to count deaths per ship)
          SELECT k.victim_ship_type_id as ship_type_id, COUNT(*) as death_count
          FROM killmails_raw k
          WHERE k.victim_character_id = $3
            AND k.killmail_time >= $2
          GROUP BY k.victim_ship_type_id
        ),
        attacker_data AS (
          -- Extract the character's ship and weapon from each kill
          SELECT
            k.killmail_id,
            (attacker->>'ship_type_id')::integer as ship_type_id,
            (attacker->>'weapon_type_id')::integer as weapon_type_id
          FROM killmails_raw k
          INNER JOIN character_kills ck ON k.killmail_id = ck.killmail_id
            AND k.killmail_time = ck.killmail_time
          CROSS JOIN LATERAL jsonb_array_elements(k.raw_data->'attackers') as attacker
          WHERE attacker->>'character_id' = $1
            AND attacker->>'ship_type_id' IS NOT NULL
        ),
        ship_weapon_usage AS (
          SELECT
            ad.ship_type_id,
            ad.weapon_type_id,
            COUNT(DISTINCT ad.killmail_id) as usage_count
          FROM attacker_data ad
          WHERE ad.weapon_type_id IS NOT NULL
            AND ad.weapon_type_id > 0
          GROUP BY ad.ship_type_id, ad.weapon_type_id
        ),
        ship_stats AS (
          SELECT
            ad.ship_type_id,
            COUNT(DISTINCT ad.killmail_id) as total_kills
          FROM attacker_data ad
          GROUP BY ad.ship_type_id
        )
        SELECT
          swu.ship_type_id,
          ship.type_name as ship_name,
          swu.weapon_type_id,
          weapon.type_name as weapon_name,
          weapon.group_name as weapon_group,
          swu.usage_count,
          ss.total_kills as ship_total_kills,
          COALESCE(cd.death_count, 0) as ship_deaths
        FROM ship_weapon_usage swu
        JOIN ship_stats ss ON swu.ship_type_id = ss.ship_type_id
        LEFT JOIN character_deaths cd ON swu.ship_type_id = cd.ship_type_id
        LEFT JOIN eve_item_types ship ON swu.ship_type_id = ship.type_id
        LEFT JOIN eve_item_types weapon ON swu.weapon_type_id = weapon.type_id
        WHERE weapon.category_id NOT IN (6, 20, 22)  -- Exclude ships, implants, deployables
        ORDER BY ss.total_kills DESC, swu.ship_type_id, swu.usage_count DESC
        """

        case Ecto.Adapters.SQL.query(EveDmv.Repo, loadout_query, [
               to_string(character_id),
               since_date,
               character_id
             ]) do
          {:ok, %{rows: rows}} ->
            ship_loadouts = build_ship_loadouts(rows)

            {:ok,
             %{
               ship_loadouts: ship_loadouts,
               analysis_period: %{from: since_date, to: DateTime.utc_now()}
             }}

          {:error, error} ->
            Logger.error("Ship loadout analysis failed: #{inspect(error)}")
            {:error, :query_failed}
        end
      end,
      ttl: @ship_preferences_ttl
    )
  end

  @doc """
  Analyze weapon preferences for a character within a given time range.
  """
  def analyze_weapon_preferences(character_id, since_date) do
    cache_key =
      "weapon_preferences:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        # Optimized query: Use participants table for indexed lookup,
        # then extract weapon_type_id from attacker data (not items - attackers use weapon_type_id)
        # $1 = character_id as string (for JSONB text comparison)
        # $2 = since_date
        # $3 = character_id as integer (for participants table)
        weapon_query = """
        WITH character_killmails AS (
          -- Step 1: Fast indexed lookup via participants table
          -- Uses idx_participants_character_activity index on (character_id, killmail_time)
          SELECT DISTINCT p.killmail_id, p.killmail_time
          FROM participants p
          WHERE p.character_id = $3
            AND p.killmail_time >= $2
            AND p.is_victim = false
        ),
        character_weapons AS (
          -- Step 2: Extract weapon_type_id from attacker data
          -- EVE killmails store weapon_type_id directly on each attacker, not in an items array
          SELECT
            (attacker->>'weapon_type_id')::integer as weapon_type_id,
            k.killmail_time
          FROM killmails_raw k
          INNER JOIN character_killmails ck ON k.killmail_id = ck.killmail_id AND k.killmail_time = ck.killmail_time
          CROSS JOIN LATERAL jsonb_array_elements(k.raw_data->'attackers') as attacker
          WHERE attacker->>'character_id' = $1
            AND attacker->>'weapon_type_id' IS NOT NULL
        ),
        weapon_usage AS (
          SELECT
            cw.weapon_type_id,
            COUNT(*) as usage_count,
            MAX(cw.killmail_time) as last_used
          FROM character_weapons cw
          JOIN eve_item_types eit ON cw.weapon_type_id = eit.type_id
          WHERE cw.weapon_type_id IS NOT NULL
            AND cw.weapon_type_id > 0
            -- Exclude ships (category 6), deployables (22), implants (20)
            AND eit.category_id NOT IN (6, 20, 22)
            -- Exclude tackle/ewar modules: warp scramblers (52), stasis webs (65),
            -- warp disrupt field gen (899), target painters (379), sensor dampeners (289),
            -- tracking disruptors (290), ECM (273), remote sensor dampeners (283)
            AND eit.group_id NOT IN (52, 65, 899, 379, 289, 290, 273, 283, 291, 292)
            -- Exclude EW drones (639), but keep combat drones (100)
            AND NOT (eit.category_id = 18 AND eit.group_id = 639)
          GROUP BY cw.weapon_type_id
          ORDER BY usage_count DESC
          LIMIT 20
        )
        SELECT
          wu.weapon_type_id,
          wu.usage_count,
          wu.last_used,
          eit.type_name as weapon_name,
          eit.group_name,
          eit.category_name
        FROM weapon_usage wu
        LEFT JOIN eve_item_types eit ON wu.weapon_type_id = eit.type_id
        ORDER BY wu.usage_count DESC
        """

        # $1 = string (JSONB), $2 = date, $3 = integer (participants)
        case Ecto.Adapters.SQL.query(EveDmv.Repo, weapon_query, [
               to_string(character_id),
               since_date,
               character_id
             ]) do
          {:ok, %{rows: rows}} ->
            total_usage = Enum.sum(Enum.map(rows, &Enum.at(&1, 1)))

            weapon_preferences =
              rows
              |> Enum.take(10)
              |> Enum.map(fn [
                               weapon_type_id,
                               usage_count,
                               last_used,
                               weapon_name,
                               group_name,
                               category_name
                             ] ->
                %{
                  weapon_type_id: weapon_type_id,
                  weapon_name: weapon_name || "Unknown Weapon",
                  group_name: group_name || "Unknown Group",
                  category_name: category_name || "Unknown Category",
                  usage_count: usage_count || 0,
                  usage_percentage:
                    if(total_usage > 0,
                      do: Float.round(usage_count / total_usage * 100, 1),
                      else: 0.0
                    ),
                  last_used: last_used
                }
              end)

            {:ok, %{preferences: weapon_preferences}}

          {:error, error} ->
            Logger.error("Weapon preference analysis failed: #{inspect(error)}")
            {:error, :query_failed}
        end
      end,
      ttl: @weapon_preferences_ttl
    )
  end

  @doc """
  Analyze ship preferences for a character within a given time range.
  """
  def analyze_ship_preferences(character_id, since_date) do
    cache_key =
      "ship_preferences:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    result =
      QueryCache.get_or_compute(
        cache_key,
        fn ->
          query = KillmailQueries.ship_usage_query(:character, character_id, 90)
          KillmailQueries.execute(query, [character_id, since_date])
        end,
        ttl: @ship_preferences_ttl
      )

    case result do
      {:ok, results} ->
        total_usage = Enum.sum(Enum.map(results, &(&1["usage_count"] || 0)))

        ship_preferences =
          results
          |> Enum.take(10)
          |> Enum.map(fn result ->
            ship_type_id = result["ship_type_id"]
            usage_count = result["usage_count"] || 0
            ship_name = result["ship_name"] || "Unknown Ship"
            kills_in_ship = result["kills_in_ship"] || 0
            losses_in_ship = result["losses_in_ship"] || 0

            ship_info =
              StaticData.get_ship_group(ship_type_id) || %{class: :unknown, group_name: "Unknown"}

            total_engagements = kills_in_ship + losses_in_ship

            efficiency =
              if total_engagements > 0 do
                Float.round(kills_in_ship / total_engagements * 100, 1)
              else
                0.0
              end

            %{
              ship_type_id: ship_type_id,
              ship_name: ship_name,
              ship_class: ship_info.class,
              ship_group: ship_info.group_name,
              usage_count: usage_count,
              usage_percentage:
                if(total_usage > 0,
                  do: Float.round(usage_count / total_usage * 100, 1),
                  else: 0.0
                ),
              kills_in_ship: kills_in_ship,
              losses_in_ship: losses_in_ship,
              efficiency_percentage: efficiency,
              last_used: result["last_used"]
            }
          end)

        ship_stats = %{
          total_ships_used: length(results),
          total_usage_count: total_usage,
          most_used_ship: List.first(ship_preferences),
          ship_diversity_score: calculate_diversity_score(ship_preferences),
          preferred_ship_classes: analyze_ship_class_preferences(ship_preferences),
          analysis_period: %{
            from: since_date,
            to: DateTime.utc_now()
          }
        }

        {:ok, %{preferences: ship_preferences, stats: ship_stats}}

      {:error, error} ->
        Logger.error("Ship preference analysis failed: #{inspect(error)}")
        {:error, :query_failed}
    end
  end

  @doc """
  Analyze gang size patterns for a character within a given time range.
  """
  def analyze_gang_patterns(character_id, since_date) do
    cache_key = "gang_patterns:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        # Optimized: Use participants table for indexed character lookup
        # Uses idx_participants_character_activity on (character_id, killmail_time)
        # $1 = character_id (integer), $2 = since_date
        gang_size_query = """
        WITH character_killmails AS (
          -- Fast indexed lookup via participants table
          SELECT DISTINCT p.killmail_id, p.killmail_time
          FROM participants p
          WHERE p.character_id = $1
            AND p.killmail_time >= $2
            AND p.is_victim = false
        ),
        character_gang_data AS (
          SELECT
            k.killmail_id,
            k.killmail_time,
            k.attacker_count as gang_size,
            COALESCE((k.raw_data->'zkb'->>'totalValue')::numeric, k.total_value, 0) as kill_value,
            k.solar_system_id
          FROM character_killmails ck
          JOIN killmails_raw k ON k.killmail_id = ck.killmail_id AND k.killmail_time = ck.killmail_time
          WHERE k.attacker_count > 0
        ),
        gang_size_categories AS (
        SELECT
            killmail_id,
            gang_size,
            kill_value,
            solar_system_id,
        CASE
              WHEN gang_size = 1 THEN 'solo'
              WHEN gang_size BETWEEN 2 AND 5 THEN 'small_gang'
              WHEN gang_size BETWEEN 6 AND 15 THEN 'medium_gang'
              WHEN gang_size BETWEEN 16 AND 50 THEN 'large_gang'
              ELSE 'fleet'
            END as size_category
          FROM character_gang_data
        )
        SELECT
          size_category,
          COUNT(*) as participation_count,
          AVG(gang_size) as avg_gang_size,
          SUM(kill_value) as total_isk_involved,
          AVG(kill_value) as avg_kill_value,
          MIN(gang_size) as min_gang_size,
          MAX(gang_size) as max_gang_size
        FROM gang_size_categories
        GROUP BY size_category
        ORDER BY participation_count DESC
        """

        # $1 = character_id (integer), $2 = since_date
        case Ecto.Adapters.SQL.query(EveDmv.Repo, gang_size_query, [character_id, since_date]) do
          {:ok, %{rows: rows}} ->
            # Convert participation counts to floats before summing (handles Decimals)
            total_participations =
              rows
              |> Enum.map(fn row -> NumericUtils.to_float(Enum.at(row, 1)) || 0.0 end)
              |> Enum.sum()

            gang_patterns =
              Enum.map(rows, fn [
                                  size_category,
                                  participation_count,
                                  avg_gang_size,
                                  total_isk_involved,
                                  avg_kill_value,
                                  min_gang_size,
                                  max_gang_size
                                ] ->
                # Convert Decimals to floats for arithmetic
                count = NumericUtils.to_float(participation_count) || 0.0
                avg_size = NumericUtils.to_float(avg_gang_size)
                avg_value = NumericUtils.to_float(avg_kill_value)

                %{
                  size_category: size_category,
                  participation_count: trunc(count),
                  participation_percentage:
                    if(total_participations > 0,
                      do: Float.round(count / total_participations * 100, 1),
                      else: 0.0
                    ),
                  avg_gang_size: if(avg_size, do: Float.round(avg_size, 1), else: 0.0),
                  total_isk_involved: NumericUtils.to_float(total_isk_involved) || 0.0,
                  avg_kill_value: if(avg_value, do: Float.round(avg_value, 0), else: 0.0),
                  min_gang_size: NumericUtils.to_float(min_gang_size) || 0,
                  max_gang_size: NumericUtils.to_float(max_gang_size) || 0
                }
              end)

            preferred_style =
              if Enum.empty?(gang_patterns),
                do: "unknown",
                else: List.first(gang_patterns).size_category

            gang_stats = %{
              total_participations: total_participations,
              preferred_gang_style: preferred_style,
              gang_size_variance: calculate_gang_size_variance(gang_patterns),
              analysis_period: %{
                from: since_date,
                to: DateTime.utc_now()
              }
            }

            {:ok, %{patterns: gang_patterns, stats: gang_stats}}

          {:error, error} ->
            Logger.error("Gang pattern analysis failed: #{inspect(error)}")
            {:error, :query_failed}
        end
      end,
      ttl: @gang_patterns_ttl
    )
  end

  @doc """
  Analyze activity statistics for a character within a given time range.
  """
  def analyze_activity_stats(character_id, since_date) do
    cache_key = "activity_stats:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        # Optimized: Use participants table for indexed character lookup
        # Uses idx_participants_character_activity on (character_id, killmail_time)
        # $1 = character_id (integer), $2 = since_date
        activity_query = """
        WITH character_participation AS (
          -- Fast indexed lookup via participants table
          SELECT DISTINCT p.killmail_id, p.killmail_time, p.is_victim
          FROM participants p
          WHERE p.character_id = $1
            AND p.killmail_time >= $2
        ),
        character_activity AS (
          -- Get all killmails where character participated
          SELECT
            k.killmail_time,
            DATE(k.killmail_time) as activity_date,
            EXTRACT(HOUR FROM k.killmail_time) as hour_utc,
            EXTRACT(DOW FROM k.killmail_time) as day_of_week,
            CASE
              WHEN cp.is_victim THEN 'death'
              ELSE 'kill'
            END as activity_type
          FROM character_participation cp
          JOIN killmails_raw k ON k.killmail_id = cp.killmail_id AND k.killmail_time = cp.killmail_time
        ),
        hourly_activity AS (
        SELECT
            hour_utc,
            COUNT(*) as activity_count
          FROM character_activity
          GROUP BY hour_utc
          ORDER BY activity_count DESC
        ),
        daily_activity AS (
        SELECT
            day_of_week,
            COUNT(*) as activity_count
          FROM character_activity
          GROUP BY day_of_week
          ORDER BY activity_count DESC
        ),
        activity_summary AS (
        SELECT
            COUNT(*) as total_events,
            COUNT(DISTINCT activity_date) as active_days,
            COUNT(CASE WHEN activity_type = 'kill' THEN 1 END) as total_kills,
            COUNT(CASE WHEN activity_type = 'death' THEN 1 END) as total_deaths,
            MIN(killmail_time) as first_activity,
            MAX(killmail_time) as last_activity
          FROM character_activity
        )
        SELECT
          (SELECT json_agg(json_build_object('hour', hour_utc, 'count', activity_count)) FROM hourly_activity) as hourly_data,
          (SELECT json_agg(json_build_object('day', day_of_week, 'count', activity_count)) FROM daily_activity) as daily_data,
          total_events,
          active_days,
          total_kills,
          total_deaths,
          first_activity,
          last_activity
        FROM activity_summary
        """

        # $1 = character_id (integer), $2 = since_date
        case Ecto.Adapters.SQL.query(EveDmv.Repo, activity_query, [
               character_id,
               since_date
             ]) do
          {:ok,
           %{
             rows: [
               [
                 hourly_data,
                 daily_data,
                 total_events,
                 active_days,
                 total_kills,
                 total_deaths,
                 first_activity,
                 last_activity
               ]
             ]
           }} ->
            efficiency =
              if total_deaths > 0,
                do: Float.round(total_kills / (total_kills + total_deaths) * 100, 1),
                else: 100.0

            activity_stats = %{
              total_events: total_events || 0,
              active_days: active_days || 0,
              total_kills: total_kills || 0,
              total_deaths: total_deaths || 0,
              kill_death_efficiency: efficiency,
              events_per_day:
                if(active_days && active_days > 0,
                  do: Float.round(total_events / active_days, 1),
                  else: 0.0
                ),
              first_activity: first_activity,
              last_activity: last_activity,
              peak_activity_hour: find_peak_activity_hour(hourly_data),
              peak_activity_day: find_peak_activity_day(daily_data),
              analysis_period: %{
                from: since_date,
                to: DateTime.utc_now()
              }
            }

            {:ok,
             %{
               stats: activity_stats,
               hourly_distribution: hourly_data || [],
               daily_distribution: daily_data || []
             }}

          {:ok, %{rows: []}} ->
            {:ok,
             %{
               stats: %{
                 total_events: 0,
                 active_days: 0,
                 total_kills: 0,
                 total_deaths: 0,
                 kill_death_efficiency: 0.0,
                 events_per_day: 0.0,
                 first_activity: nil,
                 last_activity: nil,
                 peak_activity_hour: nil,
                 peak_activity_day: nil,
                 analysis_period: %{
                   from: since_date,
                   to: DateTime.utc_now()
                 }
               },
               hourly_distribution: [],
               daily_distribution: []
             }}

          {:error, error} ->
            Logger.error("Activity stats analysis failed: #{inspect(error)}")
            {:error, :query_failed}
        end
      end,
      ttl: @activity_stats_ttl
    )
  end

  @doc """
  Analyze ISK efficiency for a character within a given time range.
  """
  def analyze_isk_efficiency(character_id, since_date) do
    cache_key = "isk_efficiency:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        # Optimized: Use participants table for indexed character lookup
        # Uses idx_participants_character_activity on (character_id, killmail_time)
        # $1 = character_id as integer, $2 = since_date
        # Note: total_value is stored in raw_data->'zkb'->>'totalValue' from zKillboard
        efficiency_query = """
        WITH character_kills AS (
          SELECT DISTINCT p.killmail_id, p.killmail_time
          FROM participants p
          WHERE p.character_id = $1
            AND p.killmail_time >= $2
            AND p.is_victim = false
        ),
        character_losses AS (
          SELECT DISTINCT p.killmail_id, p.killmail_time
          FROM participants p
          WHERE p.character_id = $1
            AND p.killmail_time >= $2
            AND p.is_victim = true
        ),
        character_isk_data AS (
          SELECT
            SUM(COALESCE((k.raw_data->'zkb'->>'totalValue')::numeric, k.total_value, 0)) as isk_destroyed,
            0 as isk_lost
          FROM character_kills ck
          JOIN killmails_raw k ON k.killmail_id = ck.killmail_id AND k.killmail_time = ck.killmail_time

          UNION ALL

          SELECT
            0 as isk_destroyed,
            SUM(COALESCE((k.raw_data->'zkb'->>'totalValue')::numeric, k.total_value, 0)) as isk_lost
          FROM character_losses cl
          JOIN killmails_raw k ON k.killmail_id = cl.killmail_id AND k.killmail_time = cl.killmail_time
        )
        SELECT
          SUM(isk_destroyed) as total_isk_destroyed,
          SUM(isk_lost) as total_isk_lost
        FROM character_isk_data
        """

        case Ecto.Adapters.SQL.query(EveDmv.Repo, efficiency_query, [character_id, since_date]) do
          {:ok, %{rows: [[isk_destroyed_raw, isk_lost_raw]]}} ->
            # Convert Decimal results to float for arithmetic
            isk_destroyed = NumericUtils.to_float(isk_destroyed_raw) || 0.0
            isk_lost = NumericUtils.to_float(isk_lost_raw) || 0.0
            net_isk = isk_destroyed - isk_lost

            efficiency_ratio =
              cond do
                isk_lost > 0 -> Float.round(isk_destroyed / isk_lost, 2)
                isk_destroyed > 0 -> :infinite
                true -> 0.0
              end

            efficiency_percentage =
              if isk_destroyed + isk_lost > 0 do
                Float.round(isk_destroyed / (isk_destroyed + isk_lost) * 100, 1)
              else
                0.0
              end

            isk_stats = %{
              isk_destroyed: isk_destroyed,
              isk_lost: isk_lost,
              net_isk: net_isk,
              efficiency_ratio: efficiency_ratio,
              efficiency_percentage: efficiency_percentage,
              profitability: if(net_isk > 0, do: :profitable, else: :unprofitable),
              analysis_period: %{
                from: since_date,
                to: DateTime.utc_now()
              }
            }

            {:ok, isk_stats}

          {:error, error} ->
            Logger.error("ISK efficiency analysis failed: #{inspect(error)}")
            {:error, :query_failed}
        end
      end,
      ttl: @isk_efficiency_ttl
    )
  end

  @doc """
  Analyze intelligence summary for a character within a given time range.
  """
  def analyze_intelligence_summary(character_id, since_date) do
    cache_key =
      "intelligence_summary:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        # Optimized: Use participants table for indexed character lookup
        # Uses idx_participants_character_activity on (character_id, killmail_time)
        # $1 = character_id as integer, $2 = since_date
        intelligence_summary_query = """
        WITH character_participation AS (
          SELECT DISTINCT p.killmail_id, p.killmail_time, p.is_victim
          FROM participants p
          WHERE p.character_id = $1
            AND p.killmail_time >= $2
        ),
        character_activity AS (
          SELECT
            k.killmail_time,
            k.solar_system_id,
            s.system_name,
            s.region_name,
            EXTRACT(HOUR FROM k.killmail_time) as hour_utc,
            CASE
              WHEN cp.is_victim THEN 'death'
              ELSE 'kill'
            END as activity_type,
            COALESCE((k.raw_data->'zkb'->>'totalValue')::numeric, k.total_value, 0) as isk_value
          FROM character_participation cp
          JOIN killmails_raw k ON k.killmail_id = cp.killmail_id AND k.killmail_time = cp.killmail_time
          LEFT JOIN eve_solar_systems s ON k.solar_system_id = s.system_id
        ),
        regional_activity AS (
        SELECT
            region_name,
            COUNT(*) as activity_count,
            SUM(CASE WHEN activity_type = 'kill' THEN isk_value ELSE 0 END) as isk_destroyed,
            SUM(CASE WHEN activity_type = 'death' THEN isk_value ELSE 0 END) as isk_lost
          FROM character_activity
          WHERE region_name IS NOT NULL
          GROUP BY region_name
          ORDER BY activity_count DESC
          LIMIT 5
        ),
        activity_summary AS (
        SELECT
            COUNT(*) as total_events,
            COUNT(DISTINCT solar_system_id) as unique_systems,
            COUNT(DISTINCT region_name) as unique_regions,
            COUNT(CASE WHEN activity_type = 'kill' THEN 1 END) as total_kills,
            COUNT(CASE WHEN activity_type = 'death' THEN 1 END) as total_deaths,
            EXTRACT(EPOCH FROM (MAX(killmail_time) - MIN(killmail_time)))/3600 as activity_span_hours
          FROM character_activity
        )
        SELECT
          (SELECT json_agg(json_build_object('region', region_name, 'activity_count', activity_count, 'isk_destroyed', isk_destroyed, 'isk_lost', isk_lost)) FROM regional_activity) as regional_data,
          total_events,
          unique_systems,
          unique_regions,
          total_kills,
          total_deaths,
          activity_span_hours
        FROM activity_summary
        """

        case Ecto.Adapters.SQL.query(EveDmv.Repo, intelligence_summary_query, [
               character_id,
               since_date
             ]) do
          {:ok,
           %{
             rows: [
               [
                 regional_data,
                 total_events,
                 unique_systems,
                 unique_regions,
                 total_kills,
                 total_deaths,
                 activity_span_hours
               ]
             ]
           }} ->
            threat_level = calculate_threat_level(total_events, total_kills, total_deaths)
            activity_intensity = calculate_activity_intensity(total_events, activity_span_hours)

            intelligence_summary = %{
              total_events: total_events || 0,
              unique_systems: unique_systems || 0,
              unique_regions: unique_regions || 0,
              total_kills: total_kills || 0,
              total_deaths: total_deaths || 0,
              kill_death_ratio: NumericUtils.calculate_kd_ratio(total_kills, total_deaths),
              threat_level: threat_level,
              activity_intensity: activity_intensity,
              mobility_score: calculate_mobility_score(unique_systems, unique_regions),
              regional_activity: regional_data || [],
              analysis_period: %{
                from: since_date,
                to: DateTime.utc_now(),
                span_hours: NumericUtils.to_float(activity_span_hours) || 0.0
              }
            }

            {:ok, intelligence_summary}

          {:ok, %{rows: []}} ->
            {:ok,
             %{
               total_events: 0,
               unique_systems: 0,
               unique_regions: 0,
               total_kills: 0,
               total_deaths: 0,
               kill_death_ratio: 0.0,
               threat_level: :unknown,
               activity_intensity: :inactive,
               mobility_score: 0.0,
               regional_activity: [],
               analysis_period: %{
                 from: since_date,
                 to: DateTime.utc_now(),
                 span_hours: 0.0
               }
             }}

          {:error, error} ->
            Logger.error("Intelligence summary analysis failed: #{inspect(error)}")
            {:error, :query_failed}
        end
      end,
      ttl: @intelligence_summary_ttl
    )
  end

  @doc """
  Get comprehensive character intelligence analysis.

  This function combines all analysis types into a single comprehensive report.
  """
  def analyze_comprehensive(character_id, since_date \\ nil) do
    since_date = since_date || DateTimeUtils.add(DateTime.utc_now(), -90 * 24 * 60 * 60, :second)

    with {:ok, weapon_analysis} <- analyze_weapon_preferences(character_id, since_date),
         {:ok, ship_analysis} <- analyze_ship_preferences(character_id, since_date),
         {:ok, gang_analysis} <- analyze_gang_patterns(character_id, since_date),
         {:ok, activity_analysis} <- analyze_activity_stats(character_id, since_date),
         {:ok, isk_analysis} <- analyze_isk_efficiency(character_id, since_date),
         {:ok, summary_analysis} <- analyze_intelligence_summary(character_id, since_date) do
      comprehensive_analysis = %{
        character_id: character_id,
        analysis_timestamp: DateTime.utc_now(),
        analysis_period: %{
          from: since_date,
          to: DateTime.utc_now(),
          days: DateTimeUtils.diff(DateTime.utc_now(), since_date, :day)
        },
        weapon_preferences: weapon_analysis,
        ship_preferences: ship_analysis,
        gang_patterns: gang_analysis,
        activity_stats: activity_analysis,
        isk_efficiency: isk_analysis,
        intelligence_summary: summary_analysis,
        overall_assessment:
          generate_overall_assessment(
            weapon_analysis,
            ship_analysis,
            gang_analysis,
            activity_analysis,
            isk_analysis,
            summary_analysis
          )
      }

      {:ok, comprehensive_analysis}
    else
      {:error, reason} ->
        Logger.error(
          "Comprehensive character analysis failed for #{character_id}: #{inspect(reason)}"
        )

        {:error, :comprehensive_analysis_failed}
    end
  end

  # ============================================================================
  # ENHANCED INTELLIGENCE FEATURES
  # ============================================================================

  @doc """
  Analyze known associates - pilots who frequently appear on the same kills.
  Returns list of characters this pilot regularly flies with.
  """
  def analyze_known_associates(character_id, since_date) do
    cache_key =
      "known_associates:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        # Find other attackers who appear on the same killmails as this character
        associates_query = """
        WITH character_kills AS (
          SELECT DISTINCT p.killmail_id, p.killmail_time
          FROM participants p
          WHERE p.character_id = $1
            AND p.killmail_time >= $2
            AND p.is_victim = false
        ),
        co_attackers AS (
          SELECT
            (attacker->>'character_id')::bigint as associate_id,
            attacker->>'character_name' as associate_name,
            (attacker->>'corporation_id')::bigint as corp_id,
            attacker->>'corporation_name' as corp_name,
            COUNT(DISTINCT ck.killmail_id) as shared_kills
          FROM character_kills ck
          JOIN killmails_raw k ON k.killmail_id = ck.killmail_id
            AND k.killmail_time = ck.killmail_time
          CROSS JOIN LATERAL jsonb_array_elements(k.raw_data->'attackers') as attacker
          WHERE (attacker->>'character_id')::bigint IS NOT NULL
            AND (attacker->>'character_id')::bigint != $1
          GROUP BY associate_id, associate_name, corp_id, corp_name
          HAVING COUNT(DISTINCT ck.killmail_id) >= 2
          ORDER BY shared_kills DESC
          LIMIT 10
        )
        SELECT
          associate_id,
          associate_name,
          corp_id,
          corp_name,
          shared_kills
        FROM co_attackers
        """

        case Ecto.Adapters.SQL.query(EveDmv.Repo, associates_query, [character_id, since_date]) do
          {:ok, %{rows: rows}} ->
            associates =
              Enum.map(rows, fn [id, name, corp_id, corp_name, shared_kills] ->
                %{
                  character_id: id,
                  character_name: name || "Unknown",
                  corporation_id: corp_id,
                  corporation_name: corp_name,
                  shared_kills: shared_kills || 0
                }
              end)

            {:ok, %{associates: associates, total_associates: length(associates)}}

          {:error, error} ->
            Logger.error("Known associates analysis failed: #{inspect(error)}")
            {:error, :query_failed}
        end
      end,
      ttl: @gang_patterns_ttl
    )
  end

  @doc """
  Analyze hunting grounds - systems where this character is most active.
  """
  def analyze_hunting_grounds(character_id, since_date) do
    cache_key =
      "hunting_grounds:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        grounds_query = """
        WITH character_activity AS (
          SELECT
            k.solar_system_id,
            s.system_name,
            s.security_status,
            s.region_name,
            COUNT(*) as activity_count,
            COUNT(CASE WHEN p.is_victim = false THEN 1 END) as kills,
            COUNT(CASE WHEN p.is_victim = true THEN 1 END) as deaths
          FROM participants p
          JOIN killmails_raw k ON k.killmail_id = p.killmail_id
            AND k.killmail_time = p.killmail_time
          LEFT JOIN eve_solar_systems s ON k.solar_system_id = s.system_id
          WHERE p.character_id = $1
            AND p.killmail_time >= $2
          GROUP BY k.solar_system_id, s.system_name, s.security_status, s.region_name
          ORDER BY activity_count DESC
          LIMIT 10
        ),
        security_breakdown AS (
          SELECT
            COALESCE(s.security_class, 'unknown') as sec_class,
            COUNT(*) as count
          FROM participants p
          JOIN killmails_raw k ON k.killmail_id = p.killmail_id
            AND k.killmail_time = p.killmail_time
          LEFT JOIN eve_solar_systems s ON k.solar_system_id = s.system_id
          WHERE p.character_id = $1
            AND p.killmail_time >= $2
          GROUP BY s.security_class
        )
        SELECT
          (SELECT json_agg(json_build_object(
            'system_id', solar_system_id,
            'system_name', system_name,
            'security_status', security_status,
            'region_name', region_name,
            'activity_count', activity_count,
            'kills', kills,
            'deaths', deaths
          )) FROM character_activity) as systems,
          (SELECT json_agg(json_build_object(
            'sec_class', sec_class,
            'count', count
          )) FROM security_breakdown) as security_breakdown
        """

        case Ecto.Adapters.SQL.query(EveDmv.Repo, grounds_query, [character_id, since_date]) do
          {:ok, %{rows: [[systems_json, security_json]]}} ->
            systems = systems_json || []
            security = security_json || []

            total_activity = Enum.sum(Enum.map(systems, &(&1["activity_count"] || 0)))

            top_systems =
              Enum.map(systems, fn sys ->
                %{
                  system_id: sys["system_id"],
                  system_name: sys["system_name"] || "Unknown",
                  security_status: sys["security_status"],
                  region_name: sys["region_name"] || "Unknown",
                  activity_count: sys["activity_count"] || 0,
                  activity_pct:
                    if(total_activity > 0,
                      do: Float.round((sys["activity_count"] || 0) / total_activity * 100, 1),
                      else: 0.0
                    ),
                  kills: sys["kills"] || 0,
                  deaths: sys["deaths"] || 0
                }
              end)

            sec_total = Enum.sum(Enum.map(security, &(&1["count"] || 0)))

            security_preference =
              Enum.map(security, fn sec ->
                %{
                  sec_class: sec["sec_class"],
                  count: sec["count"] || 0,
                  percentage:
                    if(sec_total > 0,
                      do: Float.round((sec["count"] || 0) / sec_total * 100, 1),
                      else: 0.0
                    )
                }
              end)
              |> Enum.sort_by(& &1.count, :desc)

            primary_sec =
              if Enum.empty?(security_preference),
                do: "unknown",
                else: List.first(security_preference).sec_class

            {:ok,
             %{
               top_systems: top_systems,
               security_preference: security_preference,
               primary_security: primary_sec
             }}

          {:error, error} ->
            Logger.error("Hunting grounds analysis failed: #{inspect(error)}")
            {:error, :query_failed}
        end
      end,
      ttl: @activity_stats_ttl
    )
  end

  @doc """
  Analyze target selection - what types of ships/targets does this character hunt.
  """
  def analyze_target_selection(character_id, since_date) do
    cache_key =
      "target_selection:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        targets_query = """
        WITH character_kills AS (
          SELECT DISTINCT p.killmail_id, p.killmail_time
          FROM participants p
          WHERE p.character_id = $1
            AND p.killmail_time >= $2
            AND p.is_victim = false
        ),
        victim_ships AS (
          SELECT
            k.victim_ship_type_id,
            eit.type_name as ship_name,
            eit.group_id,
            eit.group_name,
            SUM(COALESCE((k.raw_data->'zkb'->>'totalValue')::numeric, k.total_value, 0)) as kill_value,
            COUNT(*) as kill_count
          FROM character_kills ck
          JOIN killmails_raw k ON k.killmail_id = ck.killmail_id
            AND k.killmail_time = ck.killmail_time
          LEFT JOIN eve_item_types eit ON k.victim_ship_type_id = eit.type_id
          GROUP BY k.victim_ship_type_id, eit.type_name, eit.group_id, eit.group_name
        ),
        ship_class_summary AS (
          SELECT
            CASE
              WHEN group_id IN (25, 420, 831, 324, 830, 893, 541, 543, 1305) THEN 'frigates_destroyers'
              WHEN group_id IN (26, 419, 358, 894, 906, 833, 832, 963, 1201) THEN 'cruisers_bc'
              WHEN group_id IN (27, 898, 900) THEN 'battleships'
              WHEN group_id IN (547, 485, 1538, 659, 30, 883) THEN 'capitals'
              WHEN group_id IN (463, 543, 513, 902) THEN 'industrial'
              WHEN group_id IN (28, 941, 463) THEN 'mining'
              WHEN group_id = 670 THEN 'capsules'
              ELSE 'other'
            END as ship_class,
            SUM(kill_count) as total_kills,
            SUM(kill_value) as total_value
          FROM victim_ships
          WHERE group_id IS NOT NULL
          GROUP BY ship_class
        )
        SELECT
          (SELECT json_agg(json_build_object(
            'ship_type_id', victim_ship_type_id,
            'ship_name', ship_name,
            'group_name', group_name,
            'kill_count', kill_count,
            'total_value', kill_value
          )) FROM (SELECT * FROM victim_ships ORDER BY kill_count DESC LIMIT 10) limited) as top_targets,
          (SELECT json_agg(json_build_object(
            'ship_class', ship_class,
            'total_kills', total_kills,
            'total_value', total_value
          )) FROM (SELECT * FROM ship_class_summary ORDER BY total_kills DESC) ordered) as class_breakdown,
          (SELECT AVG(kill_value) FROM victim_ships) as avg_victim_value,
          (SELECT COUNT(*) FROM character_kills) as total_kills
        """

        case Ecto.Adapters.SQL.query(EveDmv.Repo, targets_query, [character_id, since_date]) do
          {:ok, %{rows: [[top_targets_json, class_json, avg_value, total_kills]]}} ->
            top_targets = top_targets_json || []
            class_breakdown = class_json || []

            total = Enum.sum(Enum.map(class_breakdown, &(&1["total_kills"] || 0)))

            class_summary =
              Enum.map(class_breakdown, fn cls ->
                %{
                  ship_class: humanize_ship_class(cls["ship_class"]),
                  raw_class: cls["ship_class"],
                  total_kills: cls["total_kills"] || 0,
                  percentage:
                    if(total > 0,
                      do: Float.round((cls["total_kills"] || 0) / total * 100, 1),
                      else: 0.0
                    ),
                  total_value: NumericUtils.to_float(cls["total_value"]) || 0.0
                }
              end)
              |> Enum.filter(&(&1.total_kills > 0))
              |> Enum.sort_by(& &1.total_kills, :desc)

            formatted_targets =
              Enum.map(top_targets, fn t ->
                %{
                  ship_type_id: t["ship_type_id"],
                  ship_name: t["ship_name"] || "Unknown",
                  group_name: t["group_name"] || "Unknown",
                  kill_count: t["kill_count"] || 0,
                  total_value: NumericUtils.to_float(t["total_value"]) || 0.0
                }
              end)

            avg_val = NumericUtils.to_float(avg_value) || 0.0

            # Determine if they punch up or down
            target_assessment =
              cond do
                avg_val > 500_000_000 -> "high_value_hunter"
                avg_val > 100_000_000 -> "standard_pvp"
                avg_val > 20_000_000 -> "opportunist"
                true -> "ganker"
              end

            {:ok,
             %{
               top_targets: formatted_targets,
               class_breakdown: class_summary,
               avg_victim_value: avg_val,
               total_kills: total_kills || 0,
               target_assessment: target_assessment
             }}

          {:error, error} ->
            Logger.error("Target selection analysis failed: #{inspect(error)}")
            {:error, :query_failed}
        end
      end,
      ttl: @ship_preferences_ttl
    )
  end

  @doc """
  Analyze recent activity timeline - daily activity over last 30 days.
  """
  def analyze_activity_timeline(character_id, since_date) do
    cache_key =
      "activity_timeline:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        timeline_query = """
        WITH daily_activity AS (
          SELECT
            DATE(p.killmail_time) as activity_date,
            COUNT(CASE WHEN p.is_victim = false THEN 1 END) as kills,
            COUNT(CASE WHEN p.is_victim = true THEN 1 END) as deaths,
            SUM(CASE WHEN p.is_victim = false THEN
              COALESCE((k.raw_data->'zkb'->>'totalValue')::numeric, 0)
              ELSE 0 END) as isk_destroyed,
            SUM(CASE WHEN p.is_victim = true THEN
              COALESCE((k.raw_data->'zkb'->>'totalValue')::numeric, 0)
              ELSE 0 END) as isk_lost
          FROM participants p
          JOIN killmails_raw k ON k.killmail_id = p.killmail_id
            AND k.killmail_time = p.killmail_time
          WHERE p.character_id = $1
            AND p.killmail_time >= $2
          GROUP BY DATE(p.killmail_time)
          ORDER BY activity_date DESC
        ),
        streak_calc AS (
          SELECT
            activity_date,
            kills,
            deaths,
            SUM(kills) OVER (ORDER BY activity_date DESC ROWS BETWEEN CURRENT ROW AND 6 FOLLOWING) as week_kills,
            SUM(deaths) OVER (ORDER BY activity_date DESC ROWS BETWEEN CURRENT ROW AND 6 FOLLOWING) as week_deaths
          FROM daily_activity
        )
        SELECT
          (SELECT json_agg(json_build_object(
            'date', activity_date,
            'kills', kills,
            'deaths', deaths,
            'isk_destroyed', isk_destroyed,
            'isk_lost', isk_lost
          ) ORDER BY activity_date DESC) FROM daily_activity) as timeline,
          (SELECT kills FROM daily_activity ORDER BY activity_date DESC LIMIT 1) as last_day_kills,
          (SELECT week_kills FROM streak_calc ORDER BY activity_date DESC LIMIT 1) as week_kills,
          (SELECT week_deaths FROM streak_calc ORDER BY activity_date DESC LIMIT 1) as week_deaths
        """

        case Ecto.Adapters.SQL.query(EveDmv.Repo, timeline_query, [character_id, since_date]) do
          {:ok, %{rows: [[timeline_json, last_day, week_kills, week_deaths]]}} ->
            timeline = timeline_json || []

            formatted_timeline =
              Enum.map(timeline, fn day ->
                %{
                  date: day["date"],
                  kills: day["kills"] || 0,
                  deaths: day["deaths"] || 0,
                  isk_destroyed: NumericUtils.to_float(day["isk_destroyed"]) || 0.0,
                  isk_lost: NumericUtils.to_float(day["isk_lost"]) || 0.0
                }
              end)

            # Calculate current streak
            {kill_streak, death_streak} = calculate_streaks(formatted_timeline)

            {:ok,
             %{
               timeline: formatted_timeline,
               last_day_kills: last_day || 0,
               week_kills: week_kills || 0,
               week_deaths: week_deaths || 0,
               current_kill_streak: kill_streak,
               current_death_streak: death_streak,
               activity_trend: determine_trend(formatted_timeline)
             }}

          {:error, error} ->
            Logger.error("Activity timeline analysis failed: #{inspect(error)}")
            {:error, :query_failed}
        end
      end,
      ttl: @activity_stats_ttl
    )
  end

  @doc """
  Analyze corporation context - how active is their corp/alliance.
  """
  def analyze_corp_context(character_id, since_date) do
    cache_key =
      "corp_context:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        # First get the character's corp from recent killmails
        corp_query = """
        WITH char_corp AS (
          SELECT
            COALESCE(
              (SELECT (k.raw_data->'victim'->>'corporation_id')::bigint
               FROM killmails_raw k WHERE k.victim_character_id = $1
               ORDER BY k.killmail_time DESC LIMIT 1),
              (SELECT (attacker->>'corporation_id')::bigint
               FROM killmails_raw k, jsonb_array_elements(k.raw_data->'attackers') as attacker
               WHERE (attacker->>'character_id')::bigint = $1
               ORDER BY k.killmail_time DESC LIMIT 1)
            ) as corp_id,
            COALESCE(
              (SELECT k.raw_data->'victim'->>'corporation_name'
               FROM killmails_raw k WHERE k.victim_character_id = $1
               ORDER BY k.killmail_time DESC LIMIT 1),
              (SELECT attacker->>'corporation_name'
               FROM killmails_raw k, jsonb_array_elements(k.raw_data->'attackers') as attacker
               WHERE (attacker->>'character_id')::bigint = $1
               ORDER BY k.killmail_time DESC LIMIT 1)
            ) as corp_name
        ),
        corp_activity AS (
          SELECT
            COUNT(DISTINCT (attacker->>'character_id')::bigint) as active_pilots,
            COUNT(DISTINCT k.killmail_id) as corp_kills
          FROM killmails_raw k,
               jsonb_array_elements(k.raw_data->'attackers') as attacker,
               char_corp cc
          WHERE (attacker->>'corporation_id')::bigint = cc.corp_id
            AND k.killmail_time >= $2
        )
        SELECT
          cc.corp_id,
          cc.corp_name,
          ca.active_pilots,
          ca.corp_kills
        FROM char_corp cc, corp_activity ca
        """

        case Ecto.Adapters.SQL.query(EveDmv.Repo, corp_query, [character_id, since_date]) do
          {:ok, %{rows: [[corp_id, corp_name, active_pilots, corp_kills]]}} ->
            corp_size_assessment =
              cond do
                (active_pilots || 0) >= 20 -> "large_active_corp"
                (active_pilots || 0) >= 10 -> "medium_active_corp"
                (active_pilots || 0) >= 5 -> "small_active_corp"
                (active_pilots || 0) >= 2 -> "micro_corp"
                true -> "solo_corp"
              end

            {:ok,
             %{
               corporation_id: corp_id,
               corporation_name: corp_name || "Unknown",
               active_pilots: active_pilots || 0,
               corp_kills: corp_kills || 0,
               corp_size_assessment: corp_size_assessment
             }}

          {:ok, %{rows: []}} ->
            {:ok,
             %{
               corporation_id: nil,
               corporation_name: "Unknown",
               active_pilots: 0,
               corp_kills: 0,
               corp_size_assessment: "unknown"
             }}

          {:error, error} ->
            Logger.error("Corp context analysis failed: #{inspect(error)}")
            {:error, :query_failed}
        end
      end,
      ttl: @gang_patterns_ttl
    )
  end

  @doc """
  Analyze bait indicators - does this pilot appear to be bait?
  Looks for patterns where they die in cheap ships while corpmates get kills.
  """
  def analyze_bait_indicators(character_id, since_date) do
    cache_key =
      "bait_indicators:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        bait_query = """
        WITH char_deaths AS (
          -- Get deaths of this character
          SELECT
            k.killmail_id,
            k.killmail_time,
            k.solar_system_id,
            k.victim_ship_type_id,
            COALESCE((k.raw_data->'zkb'->>'totalValue')::numeric, 0) as loss_value
          FROM killmails_raw k
          WHERE k.victim_character_id = $1
            AND k.killmail_time >= $2
        ),
        char_corp AS (
          SELECT COALESCE(
            (SELECT (k.raw_data->'victim'->>'corporation_id')::bigint
             FROM killmails_raw k WHERE k.victim_character_id = $1
             ORDER BY k.killmail_time DESC LIMIT 1),
            0
          ) as corp_id
        ),
        related_kills AS (
          -- Find kills by corpmates within 5 minutes and same system of character's death
          SELECT
            cd.killmail_id as death_id,
            cd.loss_value,
            COUNT(DISTINCT k.killmail_id) as related_corp_kills,
            SUM(COALESCE((k.raw_data->'zkb'->>'totalValue')::numeric, 0)) as related_kill_value
          FROM char_deaths cd
          JOIN char_corp cc ON true
          JOIN killmails_raw k ON k.solar_system_id = cd.solar_system_id
            AND k.killmail_time BETWEEN cd.killmail_time - interval '5 minutes'
                                    AND cd.killmail_time + interval '5 minutes'
            AND k.killmail_id != cd.killmail_id
          WHERE EXISTS (
            SELECT 1 FROM jsonb_array_elements(k.raw_data->'attackers') as att
            WHERE (att->>'corporation_id')::bigint = cc.corp_id
          )
          GROUP BY cd.killmail_id, cd.loss_value
        )
        SELECT
          COUNT(*) as deaths_with_related_kills,
          (SELECT COUNT(*) FROM char_deaths) as total_deaths,
          AVG(related_corp_kills) as avg_related_kills,
          SUM(related_kill_value) as total_related_value,
          SUM(loss_value) as total_bait_losses
        FROM related_kills
        """

        case Ecto.Adapters.SQL.query(EveDmv.Repo, bait_query, [character_id, since_date]) do
          {:ok,
           %{
             rows: [
               [deaths_with_kills, total_deaths, avg_related, total_related_val, bait_losses]
             ]
           }} ->
            total = total_deaths || 0
            with_kills = deaths_with_kills || 0

            bait_percentage =
              if total > 0, do: Float.round(with_kills / total * 100, 1), else: 0.0

            is_likely_bait = bait_percentage >= 40 and total >= 3

            {:ok,
             %{
               total_deaths: total,
               deaths_with_related_kills: with_kills,
               bait_percentage: bait_percentage,
               avg_related_kills: NumericUtils.to_float(avg_related) || 0.0,
               total_related_value: NumericUtils.to_float(total_related_val) || 0.0,
               total_bait_losses: NumericUtils.to_float(bait_losses) || 0.0,
               is_likely_bait: is_likely_bait,
               bait_assessment:
                 if(is_likely_bait, do: "Potential bait pilot", else: "No bait indicators")
             }}

          {:error, error} ->
            Logger.error("Bait indicators analysis failed: #{inspect(error)}")
            {:error, :query_failed}
        end
      end,
      ttl: @gang_patterns_ttl
    )
  end

  # Helper for target selection
  defp humanize_ship_class(class) do
    case class do
      "frigates_destroyers" -> "Frigates & Destroyers"
      "cruisers_bc" -> "Cruisers & Battlecruisers"
      "battleships" -> "Battleships"
      "capitals" -> "Capitals"
      "industrial" -> "Industrial Ships"
      "mining" -> "Mining Ships"
      "capsules" -> "Capsules"
      "other" -> "Other"
      _ -> class || "Unknown"
    end
  end

  # Helper for activity timeline
  defp calculate_streaks(timeline) do
    # Count consecutive days with kills (no deaths) for kill streak
    # Count consecutive days with deaths (no kills) for death streak
    kill_streak = count_streak(timeline, fn day -> day.kills > 0 and day.deaths == 0 end)
    death_streak = count_streak(timeline, fn day -> day.deaths > 0 and day.kills == 0 end)
    {kill_streak, death_streak}
  end

  defp count_streak(timeline, condition) do
    timeline
    |> Enum.take_while(condition)
    |> length()
  end

  defp determine_trend(timeline) do
    if length(timeline) < 7 do
      "insufficient_data"
    else
      recent = timeline |> Enum.take(7) |> Enum.map(& &1.kills) |> Enum.sum()
      older = timeline |> Enum.drop(7) |> Enum.take(7) |> Enum.map(& &1.kills) |> Enum.sum()

      cond do
        recent > older * 1.5 -> "increasing"
        recent < older * 0.5 -> "decreasing"
        true -> "stable"
      end
    end
  end

  # Private helper functions

  defp calculate_diversity_score(preferences) when is_list(preferences) do
    if Enum.empty?(preferences) do
      0.0
    else
      # Simple diversity calculation based on distribution
      total_usage = Enum.sum(Enum.map(preferences, &(&1.usage_count || 0)))

      if total_usage > 0 do
        # Calculate Shannon diversity index
        shannon_diversity =
          preferences
          |> Enum.map(fn pref ->
            proportion = pref.usage_count / total_usage
            -proportion * :math.log(proportion)
          end)
          |> Enum.sum()

        # Normalize to 0-1 scale
        max_diversity = :math.log(length(preferences))
        if max_diversity > 0, do: Float.round(shannon_diversity / max_diversity, 3), else: 0.0
      else
        0.0
      end
    end
  end

  defp analyze_ship_class_preferences(ship_preferences) do
    ship_preferences
    |> Enum.group_by(& &1.ship_class)
    |> Enum.map(fn {ship_class, ships} ->
      total_usage = Enum.sum(Enum.map(ships, & &1.usage_count))
      avg_efficiency = Enum.sum(Enum.map(ships, & &1.efficiency_percentage)) / length(ships)

      %{
        ship_class: ship_class,
        ship_count: length(ships),
        total_usage: total_usage,
        avg_efficiency: Float.round(avg_efficiency, 1)
      }
    end)
    |> Enum.sort_by(& &1.total_usage, :desc)
  end

  defp calculate_gang_size_variance(gang_patterns) do
    if length(gang_patterns) < 2 do
      0.0
    else
      gang_sizes = Enum.map(gang_patterns, & &1.avg_gang_size)
      mean = Enum.sum(gang_sizes) / length(gang_sizes)

      variance =
        gang_sizes
        |> Enum.map(fn size -> :math.pow(size - mean, 2) end)
        |> Enum.sum()
        |> Kernel./(length(gang_sizes))

      Float.round(:math.sqrt(variance), 2)
    end
  end

  defp find_peak_activity_hour(hourly_data) when is_list(hourly_data) do
    hourly_data
    |> Enum.max_by(fn %{"count" => count} -> count end, fn -> %{"hour" => nil} end)
    |> Map.get("hour")
  end

  defp find_peak_activity_hour(_), do: nil

  defp find_peak_activity_day(daily_data) when is_list(daily_data) do
    day_names = %{
      1 => "Monday",
      2 => "Tuesday",
      3 => "Wednesday",
      4 => "Thursday",
      5 => "Friday",
      6 => "Saturday",
      0 => "Sunday"
    }

    peak_day =
      daily_data
      |> Enum.max_by(fn %{"count" => count} -> count end, fn -> %{"day" => nil} end)
      |> Map.get("day")

    Map.get(day_names, peak_day, "Unknown")
  end

  defp find_peak_activity_day(_), do: "Unknown"

  defp calculate_threat_level(total_events, total_kills, _total_deaths) do
    cond do
      total_events >= 100 and total_kills >= 50 -> :extreme
      total_events >= 50 and total_kills >= 25 -> :high
      total_events >= 20 and total_kills >= 10 -> :medium
      total_events >= 5 -> :low
      true -> :minimal
    end
  end

  defp calculate_activity_intensity(total_events, activity_span_hours) do
    # Convert values to floats to handle Decimal types from database
    events = NumericUtils.to_float(total_events)
    hours = NumericUtils.to_float(activity_span_hours)

    if hours && hours > 0 do
      events_per_hour = events / hours

      cond do
        events_per_hour >= 5 -> :very_high
        events_per_hour >= 2 -> :high
        events_per_hour >= 1 -> :medium
        events_per_hour >= 0.5 -> :low
        true -> :very_low
      end
    else
      :inactive
    end
  end

  defp calculate_mobility_score(unique_systems, unique_regions) do
    # Simple mobility score based on system and region diversity
    # Convert to float to handle database types
    systems = NumericUtils.to_float(unique_systems) || 0.0
    regions = NumericUtils.to_float(unique_regions) || 0.0

    system_score = min(systems / 10, 1.0) * 0.7
    region_score = min(regions / 5, 1.0) * 0.3

    Float.round(system_score + region_score, 2)
  end

  # Helper to build ship loadouts from query results
  defp build_ship_loadouts(rows) do
    rows
    |> Enum.group_by(fn [ship_type_id, ship_name, _, _, _, _, total_kills, deaths] ->
      {ship_type_id, ship_name, total_kills, deaths}
    end)
    |> Enum.map(&build_ship_loadout/1)
    |> Enum.sort_by(& &1.total_kills, :desc)
    |> Enum.take(10)
  end

  defp build_ship_loadout({{ship_type_id, ship_name, total_kills, deaths}, weapon_rows}) do
    weapons =
      weapon_rows
      |> Enum.map(&parse_weapon_row/1)
      |> Enum.take(5)

    %{
      ship_type_id: ship_type_id,
      ship_name: ship_name || "Unknown Ship",
      total_kills: total_kills || 0,
      total_deaths: deaths || 0,
      weapons: weapons
    }
  end

  defp parse_weapon_row([_, _, weapon_type_id, weapon_name, weapon_group, usage_count, _, _]) do
    %{
      weapon_type_id: weapon_type_id,
      weapon_name: weapon_name || "Unknown",
      weapon_group: weapon_group || "Unknown",
      usage_count: usage_count || 0
    }
  end

  defp generate_overall_assessment(
         _weapon_analysis,
         ship_analysis,
         gang_analysis,
         activity_analysis,
         isk_analysis,
         _summary_analysis
       ) do
    # Generate an overall threat/capability assessment
    preferred_gang_style = gang_analysis.stats.preferred_gang_style
    ship_diversity = ship_analysis.stats.ship_diversity_score

    threat_indicators =
      []
      |> add_activity_indicator(activity_analysis.stats.total_events)
      |> add_efficiency_indicator(activity_analysis.stats.kill_death_efficiency)
      |> add_isk_efficiency_indicator(isk_analysis.efficiency_percentage)
      |> add_gang_preference_indicator(preferred_gang_style)
      |> add_ship_diversity_indicator(ship_diversity)

    indicator_count = length(threat_indicators)

    overall_threat_level =
      cond do
        indicator_count >= 4 -> :extreme
        indicator_count >= 3 -> :high
        indicator_count >= 2 -> :medium
        indicator_count >= 1 -> :low
        true -> :minimal
      end

    %{
      overall_threat_level: overall_threat_level,
      threat_indicators: threat_indicators,
      combat_style: determine_combat_style(gang_analysis, ship_analysis),
      experience_level: determine_experience_level(activity_analysis, isk_analysis),
      recommendations:
        generate_tactical_recommendations(
          overall_threat_level,
          threat_indicators,
          preferred_gang_style
        )
    }
  end

  defp determine_combat_style(gang_analysis, ship_analysis) do
    preferred_gang = gang_analysis.stats.preferred_gang_style
    most_used_ship = ship_analysis.stats.most_used_ship

    ship_class = if most_used_ship, do: most_used_ship.ship_class, else: :unknown

    case {preferred_gang, ship_class} do
      {"solo", _} -> :solo_hunter
      {"small_gang", :frigate} -> :small_gang_tackler
      {"small_gang", :cruiser} -> :small_gang_brawler
      {"fleet", :battleship} -> :fleet_dps
      {"fleet", :logistics} -> :fleet_support
      _ -> :versatile
    end
  end

  defp determine_experience_level(activity_analysis, isk_analysis) do
    total_events = activity_analysis.stats.total_events
    efficiency = activity_analysis.stats.kill_death_efficiency
    isk_efficiency = isk_analysis.efficiency_percentage

    cond do
      total_events >= 100 and efficiency >= 80 and isk_efficiency >= 70 -> :elite
      total_events >= 50 and efficiency >= 60 and isk_efficiency >= 50 -> :veteran
      total_events >= 20 and efficiency >= 40 -> :experienced
      total_events >= 5 -> :novice
      true -> :beginner
    end
  end

  defp generate_tactical_recommendations(threat_level, threat_indicators, gang_style) do
    []
    |> add_threat_level_recommendations(threat_level)
    |> add_gang_style_recommendations(gang_style)
    |> add_activity_recommendations(threat_indicators)
    |> Enum.reverse()
  end

  defp add_threat_level_recommendations(recommendations, threat_level) do
    case threat_level do
      :extreme ->
        [
          "Extreme caution advised - avoid engagement unless overwhelming advantage"
          | recommendations
        ]

      :high ->
        ["High threat target - engage with superior numbers and preparation" | recommendations]

      :medium ->
        ["Moderate threat - standard engagement protocols with backup ready" | recommendations]

      :low ->
        ["Low threat - standard engagement protocols apply" | recommendations]

      :minimal ->
        ["Minimal threat - opportunity target" | recommendations]
    end
  end

  defp add_gang_style_recommendations(recommendations, gang_style) do
    case gang_style do
      "solo" ->
        ["Solo pilot - vulnerable to ganks but may be skilled in 1v1" | recommendations]

      "small_gang" ->
        ["Small gang specialist - dangerous with 2-5 allies" | recommendations]

      "fleet" ->
        ["Fleet pilot - most dangerous when supported" | recommendations]

      _ ->
        recommendations
    end
  end

  defp add_activity_recommendations(recommendations, threat_indicators) do
    if "High activity level" in Enum.map(threat_indicators, &String.slice(&1, 0, 18)) do
      ["Very active player - expect experienced gameplay" | recommendations]
    else
      recommendations
    end
  end

  # Helper functions for threat indicator pipeline
  defp add_activity_indicator(indicators, total_events) do
    if total_events >= 50 do
      ["High activity level (#{total_events} events)" | indicators]
    else
      indicators
    end
  end

  defp add_efficiency_indicator(indicators, kill_death_efficiency) do
    if kill_death_efficiency >= 80.0 do
      ["High kill efficiency (#{kill_death_efficiency}%)" | indicators]
    else
      indicators
    end
  end

  defp add_isk_efficiency_indicator(indicators, efficiency_percentage) do
    if efficiency_percentage >= 70.0 do
      ["High ISK efficiency (#{efficiency_percentage}%)" | indicators]
    else
      indicators
    end
  end

  defp add_gang_preference_indicator(indicators, preferred_gang_style) do
    case preferred_gang_style do
      "solo" -> ["Solo combat preference" | indicators]
      "small_gang" -> ["Small gang specialist" | indicators]
      "fleet" -> ["Fleet combat experience" | indicators]
      _ -> indicators
    end
  end

  defp add_ship_diversity_indicator(indicators, ship_diversity) do
    if ship_diversity >= 0.7 do
      ["High ship diversity (#{ship_diversity})" | indicators]
    else
      indicators
    end
  end
end
