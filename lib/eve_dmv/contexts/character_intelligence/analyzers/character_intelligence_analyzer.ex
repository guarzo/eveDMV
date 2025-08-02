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
  """

  alias EveDmv.Cache.QueryCache
  alias EveDmv.Core.Utils.DateTimeUtils
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
  Analyze weapon preferences for a character within a given time range.
  """
  def analyze_weapon_preferences(character_id, since_date) do
    cache_key =
      "weapon_preferences:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        weapon_query = """
        WITH character_weapons AS (
        SELECT
            attacker->>'character_id' as char_id,
            jsonb_array_elements(attacker->'items') as item_data,
            k.killmail_time
          FROM killmails_raw k,
               jsonb_array_elements(k.raw_data->'attackers') as attacker
          WHERE attacker->>'character_id' = $1
            AND k.killmail_time >= $2
            AND jsonb_array_length(COALESCE(attacker->'items', '[]'::jsonb)) > 0
        ),
        weapon_usage AS (
        SELECT
            (item_data->>'type_id')::integer as weapon_type_id,
            COUNT(*) as usage_count,
            MAX(killmail_time) as last_used
          FROM character_weapons cw
          JOIN eve_item_types eit ON (cw.item_data->>'type_id')::integer = eit.type_id
          WHERE eit.category_id IN (7, 8, 18)  -- Modules, Charges, Drones
            AND (
              eit.group_id IN (
                53, 54, 55, 74, 76, 506, 507, 508, 509, 510, 511, 512, 513, 514, 515, 516, 517, 518, 519, 520
              ) OR
              eit.type_name ILIKE '%gun%' OR
              eit.type_name ILIKE '%launcher%' OR
              eit.type_name ILIKE '%turret%' OR
              eit.type_name ILIKE '%missile%' OR
              eit.type_name ILIKE '%torpedo%' OR
              eit.type_name ILIKE '%drone%'
            )
          GROUP BY weapon_type_id
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
        JOIN eve_item_types eit ON wu.weapon_type_id = eit.type_id
        ORDER BY wu.usage_count DESC
        """

        case Ecto.Adapters.SQL.query(EveDmv.Repo, weapon_query, [
               character_id,
               since_date
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

            weapon_stats = %{
              total_weapons_used: length(rows),
              total_usage_count: total_usage,
              most_used_weapon: List.first(weapon_preferences),
              weapon_diversity_score: calculate_diversity_score(weapon_preferences),
              analysis_period: %{
                from: since_date,
                to: DateTime.utc_now()
              }
            }

            {:ok, %{preferences: weapon_preferences, stats: weapon_stats}}

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
        gang_size_query = """
        WITH character_gang_data AS (
        SELECT
            k.killmail_id,
            k.killmail_time,
            jsonb_array_length(k.raw_data->'attackers') as gang_size,
            COALESCE((k.raw_data->>'total_value')::numeric, 0) as kill_value,
            k.solar_system_id
          FROM killmails_raw k,
               jsonb_array_elements(k.raw_data->'attackers') as attacker
          WHERE attacker->>'character_id' = $1
            AND k.killmail_time >= $2
            AND jsonb_array_length(k.raw_data->'attackers') > 0
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

        case Ecto.Adapters.SQL.query(EveDmv.Repo, gang_size_query, [character_id, since_date]) do
          {:ok, %{rows: rows}} ->
            total_participations = Enum.sum(Enum.map(rows, &Enum.at(&1, 1)))

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
                %{
                  size_category: size_category,
                  participation_count: participation_count || 0,
                  participation_percentage:
                    if(total_participations > 0,
                      do: Float.round(participation_count / total_participations * 100, 1),
                      else: 0.0
                    ),
                  avg_gang_size: if(avg_gang_size, do: Float.round(avg_gang_size, 1), else: 0.0),
                  total_isk_involved: total_isk_involved || 0,
                  avg_kill_value:
                    if(avg_kill_value, do: Float.round(avg_kill_value, 0), else: 0.0),
                  min_gang_size: min_gang_size || 0,
                  max_gang_size: max_gang_size || 0
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
        activity_query = """
        WITH character_activity AS (
          -- Get all killmails where character participated
        SELECT
            k.killmail_time,
            DATE(k.killmail_time) as activity_date,
            EXTRACT(HOUR FROM k.killmail_time) as hour_utc,
            EXTRACT(DOW FROM k.killmail_time) as day_of_week,
        CASE
              WHEN k.victim_character_id = $3 THEN 'death'
              ELSE 'kill'
            END as activity_type
          FROM killmails_raw k
          WHERE k.killmail_time >= $2
            AND (
              k.victim_character_id = $3
              OR EXISTS (
                SELECT 1
                FROM jsonb_array_elements(k.raw_data->'attackers') as attacker
                WHERE attacker->>'character_id' = $1
              )
            )
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

        case Ecto.Adapters.SQL.query(EveDmv.Repo, activity_query, [
               character_id,
               since_date,
               character_id
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
        efficiency_query = """
        WITH character_isk_data AS (
          -- ISK destroyed (when character is attacker)
        SELECT
            SUM(COALESCE((k.raw_data->>'total_value')::numeric, 0)) as isk_destroyed,
            0 as isk_lost
          FROM killmails_raw k,
               jsonb_array_elements(k.raw_data->'attackers') as attacker
          WHERE attacker->>'character_id' = $1
            AND k.killmail_time >= $2

          UNION ALL

          -- ISK lost (when character is victim)
        SELECT
            0 as isk_destroyed,
            SUM(COALESCE((k.raw_data->>'total_value')::numeric, 0)) as isk_lost
          FROM killmails_raw k
          WHERE k.victim_character_id = $1
            AND k.killmail_time >= $2
        )
        SELECT
          SUM(isk_destroyed) as total_isk_destroyed,
          SUM(isk_lost) as total_isk_lost
        FROM character_isk_data
        """

        case Ecto.Adapters.SQL.query(EveDmv.Repo, efficiency_query, [character_id, since_date]) do
          {:ok, %{rows: [[isk_destroyed, isk_lost]]}} ->
            isk_destroyed = isk_destroyed || 0
            isk_lost = isk_lost || 0
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
        intelligence_summary_query = """
        WITH character_activity AS (
        SELECT
            k.killmail_time,
            k.solar_system_id,
            s.system_name,
            s.region_name,
            EXTRACT(HOUR FROM k.killmail_time) as hour_utc,
        CASE
              WHEN k.victim_character_id = $3 THEN 'death'
              ELSE 'kill'
            END as activity_type,
            COALESCE((k.raw_data->>'total_value')::numeric, 0) as isk_value
          FROM killmails_raw k
          LEFT JOIN eve_systems s ON k.solar_system_id = s.system_id
          WHERE k.killmail_time >= $2
            AND (
              k.victim_character_id = $3
              OR EXISTS (
                SELECT 1
                FROM jsonb_array_elements(k.raw_data->'attackers') as attacker
                WHERE attacker->>'character_id' = $1
              )
            )
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
               since_date,
               character_id
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
              kill_death_ratio:
                if(total_deaths && total_deaths > 0,
                  do: Float.round(total_kills / total_deaths, 2),
                  else: :infinite
                ),
              threat_level: threat_level,
              activity_intensity: activity_intensity,
              mobility_score: calculate_mobility_score(unique_systems, unique_regions),
              regional_activity: regional_data || [],
              analysis_period: %{
                from: since_date,
                to: DateTime.utc_now(),
                span_hours:
                  if(activity_span_hours, do: Float.round(activity_span_hours, 1), else: 0.0)
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
    if activity_span_hours && activity_span_hours > 0 do
      events_per_hour = total_events / activity_span_hours

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
    system_score = min(unique_systems / 10, 1.0) * 0.7
    region_score = min(unique_regions / 5, 1.0) * 0.3

    Float.round(system_score + region_score, 2)
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

    overall_threat_level =
      cond do
        length(threat_indicators) >= 4 -> :extreme
        length(threat_indicators) >= 3 -> :high
        length(threat_indicators) >= 2 -> :medium
        length(threat_indicators) >= 1 -> :low
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
