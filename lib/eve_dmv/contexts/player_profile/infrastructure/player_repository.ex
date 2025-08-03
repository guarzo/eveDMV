defmodule EveDmv.Contexts.PlayerProfile.Infrastructure.PlayerRepository do
  @moduledoc """
  Repository for player profile data and statistics.

  Provides data access for player analysis including combat statistics,
  ship preferences, activity patterns, and affiliations.
  """

  alias EveDmv.Cache.QueryCache
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Database.CharacterQueries
  alias EveDmv.Database.QueryPerformance
  alias EveDmv.Shared.KillmailQueries
  alias EveDmv.StaticData
  require Logger

  # Cache TTL configuration
  @ship_preferences_ttl :timer.hours(2)
  @weapon_preferences_ttl :timer.hours(2)
  @isk_efficiency_ttl :timer.hours(1)
  @gang_patterns_ttl :timer.hours(6)
  @external_groups_ttl :timer.hours(8)
  @intelligence_summary_ttl :timer.minutes(30)

  # Type definitions
  @type player_data :: %{
          character_id: integer(),
          name: String.t(),
          corporation_id: integer() | nil,
          corporation_name: String.t() | nil,
          alliance_id: integer() | nil,
          alliance_name: String.t() | nil,
          created_at: DateTime.t(),
          last_seen: DateTime.t()
        }

  @type killmail_stats :: %{
          total_kills: non_neg_integer(),
          total_deaths: non_neg_integer(),
          kd_ratio: float(),
          isk_destroyed: non_neg_integer(),
          isk_lost: non_neg_integer(),
          isk_efficiency: float(),
          favorite_ships: [map()],
          security_preference: atom()
        }

  @type activity_data :: %{
          total_activity_days: non_neg_integer(),
          last_activity: DateTime.t() | nil,
          activity_patterns: %{
            most_active_hour: non_neg_integer(),
            most_active_weekday: String.t(),
            avg_daily_activity: float()
          },
          timezone_preference: String.t(),
          engagement_frequency: float(),
          activity_rating: atom(),
          activity_trend: atom()
        }

  @type gang_size_patterns :: [%{
          gang_size: non_neg_integer(),
          frequency: non_neg_integer(),
          percentage: float()
        }]

  @type intelligence_summary :: %{
          threat_level: atom(),
          activity_level: atom(),
          engagement_preference: atom(),
          tactical_tendency: atom()
        }

  @doc """
  Get comprehensive player data for analysis.
  """
  @spec get_player_data(integer()) :: {:ok, player_data()}
  def get_player_data(character_id) do
    # Get character name from killmail data
    character_name = CharacterQueries.get_character_name_from_killmails(character_id)

    # Get affiliations
    affiliations = CharacterQueries.get_character_affiliations(character_id)

    {:ok,
     %{
       character_id: character_id,
       name: character_name || "Unknown Character",
       corporation_id: affiliations.corporation_id,
       corporation_name: affiliations.corporation_name,
       alliance_id: affiliations.alliance_id,
       alliance_name: affiliations.alliance_name,
       created_at: DateTime.utc_now(),
       last_seen: DateTime.utc_now()
     }}
  end

  @doc """
  Get killmail statistics for a character.
  """
  @spec get_killmail_stats(integer()) :: {:ok, killmail_stats()} | {:error, Ash.Error.t()}
  def get_killmail_stats(character_id) do
    get_killmail_stats(character_id, DateTime.utc_now() |> DateTimeUtils.add(-90 * 24 * 60 * 60, :second))
  end

  @doc """
  Get killmail statistics for a character since a specific date.
  """
  @spec get_killmail_stats(integer(), DateTime.t()) :: {:ok, killmail_stats()} | {:error, Ash.Error.t()}
  def get_killmail_stats(character_id, since_date) do
    # Get character stats using optimized query
    stats =
      QueryPerformance.tracked_query(
        "character_stats",
        fn -> CharacterQueries.get_character_stats(character_id, since_date) end,
        metadata: %{character_id: character_id}
      )

    # Get ISK efficiency
    isk_stats = calculate_isk_efficiency(character_id, since_date)

    # Get ship preferences
    ship_preferences = get_ship_preferences(character_id, since_date)

    {:ok,
     %{
       total_kills: stats.kills,
       total_deaths: stats.deaths,
       kd_ratio: stats.kd_ratio,
       isk_destroyed: isk_stats.destroyed,
       isk_lost: isk_stats.lost,
       isk_efficiency: isk_stats.efficiency,
       favorite_ships: Enum.take(ship_preferences, 5),
       security_preference: determine_security_preference(ship_preferences)
     }}
  end

  @doc """
  Get activity data for a character.
  """
  @spec get_activity_data(integer()) :: {:ok, activity_data()} | {:error, atom()}
  def get_activity_data(character_id) do
    get_activity_data(character_id, DateTime.utc_now() |> DateTimeUtils.add(-30 * 24 * 60 * 60, :second))
  end

  @doc """
  Get activity data for a character since a specific date.
  """
  @spec get_activity_data(integer(), DateTime.t()) :: {:ok, activity_data()} | {:error, atom()}
  def get_activity_data(character_id, since_date) do
    # Delegate to the proper implementation in CharacterIntelligence
    case EveDmv.Contexts.CharacterIntelligence.calculate_activity_stats(character_id, since_date) do
      {:ok, activity_stats} ->
        {:ok,
         %{
           total_activity_days: activity_stats.total_active_days || 0,
           last_activity: activity_stats.last_activity_date,
           activity_patterns: %{
             most_active_hour: activity_stats.peak_activity_hour || 20,
             most_active_weekday: activity_stats.peak_activity_day || "Saturday",
             avg_daily_activity: activity_stats.avg_daily_kills || 0.0
           },
           timezone_preference: activity_stats.timezone_estimate || "Unknown",
           engagement_frequency: activity_stats.avg_daily_kills || 0.0,
           activity_rating: activity_stats.activity_consistency || :stable,
           activity_trend: activity_stats.activity_trend || :stable
         }}

      {:error, reason} ->
        Logger.error(
          "Failed to get activity stats for character #{character_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Get corporation history for a character.
  Returns empty list as corporation history is not currently tracked.
  """
  @spec get_corporation_history(integer()) :: {:ok, [map()]} | {:error, term()}
  def get_corporation_history(_character_id) do
    # Corporation history not currently implemented - returns empty list
    {:ok, []}
  end

  @doc """
  Get weapon preferences for a character.
  """
  @spec get_weapon_preferences(integer(), DateTime.t()) :: [map()]
  def get_weapon_preferences(character_id, since_date) do
    cache_key =
      "weapon_preferences:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        query = build_weapon_preferences_query()

        case EveDmv.Repo.query(query, [to_string(character_id), since_date]) do
          {:ok, %{rows: rows}} ->
            format_weapon_preferences(rows)

          {:error, error} ->
            Logger.error("Failed to get weapon preferences: #{inspect(error)}")
            []
        end
      end,
      ttl: @weapon_preferences_ttl
    )
  end

  @doc """
  Get external groups (corps/alliances) the character has flown with.
  """
  @spec get_external_groups(integer(), DateTime.t()) :: [map()]
  def get_external_groups(character_id, since_date) do
    cache_key = "external_groups:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        query = build_external_groups_query()

        case EveDmv.Repo.query(query, [
               to_string(character_id),
               since_date,
               character_id
             ]) do
          {:ok, %{rows: rows}} ->
            format_external_groups(rows)

          {:error, error} ->
            Logger.error("Failed to get external groups: #{inspect(error)}")
            []
        end
      end,
      ttl: @external_groups_ttl
    )
  end

  @doc """
  Get gang size patterns for a character.
  """
  @spec get_gang_size_patterns(integer(), DateTime.t()) :: gang_size_patterns()
  def get_gang_size_patterns(character_id, since_date) do
    cache_key = "gang_patterns:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        query = build_gang_size_query()

        case EveDmv.Repo.query(query, [to_string(character_id), since_date]) do
          {:ok, %{rows: rows}} ->
            format_gang_size_patterns(rows)

          {:error, error} ->
            Logger.error("Failed to get gang size patterns: #{inspect(error)}")
            default_gang_patterns()
        end
      end,
      ttl: @gang_patterns_ttl
    )
  end

  @doc """
  Get intelligence summary for a character.
  """
  @spec get_intelligence_summary(integer(), DateTime.t()) :: intelligence_summary()
  def get_intelligence_summary(character_id, since_date) do
    cache_key =
      "intelligence_summary:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        query = build_intelligence_summary_query()

        case EveDmv.Repo.query(query, [
               to_string(character_id),
               since_date,
               character_id
             ]) do
          {:ok, %{rows: rows}} ->
            format_intelligence_summary(rows)

          {:error, error} ->
            Logger.error("Failed to get intelligence summary: #{inspect(error)}")
            default_intelligence_summary()
        end
      end,
      ttl: @intelligence_summary_ttl
    )
  end

  @doc """
  Get ship preferences for a character.
  """
  @spec get_ship_preferences(integer(), DateTime.t()) :: [map()]
  def get_ship_preferences(character_id, since_date) do
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
        # Calculate total usage for percentages
        total_usage = Enum.sum(Enum.map(results, &(&1["usage_count"] || 0)))

        results
        # Top 10 ships
        |> Enum.take(10)
        |> Enum.map(fn result ->
          ship_type_id = result["ship_type_id"]
          usage_count = result["usage_count"] || 0
          ship_name = result["ship_name"] || "Unknown Ship"
          kills_in_ship = result["kills_in_ship"] || 0
          losses_in_ship = result["losses_in_ship"] || 0

          # Get ship classification from static data
          ship_info =
            StaticData.get_ship_group(ship_type_id) || %{class: :unknown, group_name: "Unknown"}

          # Calculate efficiency in this ship
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
            group_name: ship_info.group_name,
            usage_count: usage_count,
            percentage:
              if(total_usage > 0, do: Float.round(usage_count / total_usage * 100, 1), else: 0.0),
            kills_in_ship: kills_in_ship,
            losses_in_ship: losses_in_ship,
            efficiency: efficiency
          }
        end)

      {:error, error} ->
        Logger.error(
          "Failed to get ship preferences for character #{character_id}: #{inspect(error)}"
        )

        []
    end
  end

  # Private helper functions

  defp calculate_isk_efficiency(character_id, since_date) do
    cache_key = "isk_efficiency:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        # Query to calculate ISK efficiency from killmails
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
          WHERE k.victim_character_id = $3
            AND k.killmail_time >= $4
        )
        SELECT
          SUM(isk_destroyed) as total_destroyed,
          SUM(isk_lost) as total_lost,
          COUNT(CASE WHEN isk_destroyed > 0 THEN 1 END) as kills_count,
          COUNT(CASE WHEN isk_lost > 0 THEN 1 END) as deaths_count
        FROM character_isk_data
        """

        case EveDmv.Repo.query(efficiency_query, [
               to_string(character_id),
               since_date,
               character_id,
               since_date
             ]) do
          {:ok, %{rows: [[destroyed, lost, kills, deaths]]}} ->
            destroyed_isk = Decimal.to_float(destroyed || Decimal.new(0))
            lost_isk = Decimal.to_float(lost || Decimal.new(0))

            # Calculate efficiency percentage (destroyed / (destroyed + lost) * 100)
            efficiency =
              if destroyed_isk + lost_isk > 0 do
                Float.round(destroyed_isk / (destroyed_isk + lost_isk) * 100, 1)
              else
                0.0
              end

            # Calculate average ISK per kill/death
            avg_kill_value = if kills > 0, do: Float.round(destroyed_isk / kills, 0), else: 0.0
            avg_death_value = if deaths > 0, do: Float.round(lost_isk / deaths, 0), else: 0.0

            # Calculate net ISK (positive means net destroyer, negative means net loser)
            net_isk = destroyed_isk - lost_isk

            # Calculate risk assessment
            risk_level = calculate_risk_level(avg_death_value, efficiency)

            %{
              efficiency: efficiency,
              destroyed: destroyed_isk,
              lost: lost_isk,
              net_isk: net_isk,
              avg_kill_value: avg_kill_value,
              avg_death_value: avg_death_value,
              kills_count: kills || 0,
              deaths_count: deaths || 0,
              risk_level: risk_level,
              efficiency_rating: calculate_efficiency_rating(efficiency, net_isk)
            }

          {:error, error} ->
            Logger.error(
              "Failed to calculate ISK efficiency for character #{character_id}: #{inspect(error)}"
            )

            %{
              efficiency: 0,
              destroyed: 0,
              lost: 0,
              net_isk: 0,
              avg_kill_value: 0,
              avg_death_value: 0,
              kills_count: 0,
              deaths_count: 0,
              risk_level: :unknown,
              efficiency_rating: :poor
            }
        end
      end,
      ttl: @isk_efficiency_ttl
    )
  end

  defp calculate_risk_level(avg_death_value, efficiency) do
    cond do
      avg_death_value > 1_000_000_000 && efficiency < 50 -> :very_high
      avg_death_value > 500_000_000 && efficiency < 60 -> :high
      avg_death_value > 100_000_000 && efficiency < 70 -> :moderate
      true -> :low
    end
  end

  defp calculate_efficiency_rating(efficiency, net_isk) do
    cond do
      efficiency >= 90 && net_isk > 0 -> :elite
      efficiency >= 75 && net_isk > 0 -> :excellent
      efficiency >= 60 -> :good
      efficiency >= 50 -> :average
      true -> :poor
    end
  end

  defp determine_security_preference(ship_preferences) do
    # Analyze ship usage to determine preferred security space
    # Return :unknown until proper ship type analysis is implemented
    if Enum.empty?(ship_preferences) do
      :unknown
    else
      :unknown
    end
  end

  defp format_gang_size_patterns(results) do
    results
    |> Enum.map(fn [size, count] ->
      %{
        gang_size: size,
        frequency: count,
        # Would calculate from total
        percentage: 0.0
      }
    end)
  end

  defp build_gang_size_query do
    """
    WITH gang_sizes AS (
      SELECT
        jsonb_array_length(k.raw_data->'attackers') as gang_size,
        COUNT(*) as frequency
      FROM killmails_raw k
      WHERE k.killmail_time >= $2
        AND EXISTS (
          SELECT 1 FROM jsonb_array_elements(k.raw_data->'attackers') as attacker
          WHERE attacker->>'character_id' = $1
        )
      GROUP BY gang_size
      ORDER BY frequency DESC
      LIMIT 10
    )
    SELECT gang_size, frequency FROM gang_sizes
    """
  end

  defp default_gang_patterns do
    []
  end

  defp format_external_groups(results) do
    results
    |> Enum.map(fn [corp_id, corp_name, alliance_id, alliance_name, count] ->
      %{
        corporation_id: corp_id,
        corporation_name: corp_name || "Unknown Corp",
        alliance_id: alliance_id,
        alliance_name: alliance_name,
        interaction_count: count
      }
    end)
  end

  defp build_external_groups_query do
    """
    WITH external_interactions AS (
      SELECT
        a.corporation_id,
        a.corporation_name,
        a.alliance_id,
        a.alliance_name,
        COUNT(*) as interaction_count
      FROM killmails_raw k,
           jsonb_array_elements(k.raw_data->'attackers') as attacker,
           LATERAL (
             SELECT
               (attacker->>'corporation_id')::integer as corporation_id,
               attacker->>'corporation_name' as corporation_name,
               (attacker->>'alliance_id')::integer as alliance_id,
               attacker->>'alliance_name' as alliance_name
           ) a
      WHERE k.killmail_time >= $2
        AND EXISTS (
          SELECT 1 FROM jsonb_array_elements(k.raw_data->'attackers') as other
          WHERE other->>'character_id' = $1
        )
        AND attacker->>'character_id' != $1
      GROUP BY a.corporation_id, a.corporation_name, a.alliance_id, a.alliance_name
      ORDER BY interaction_count DESC
      LIMIT 20
    )
    SELECT * FROM external_interactions
    """
  end

  defp format_intelligence_summary(results) do
    if Enum.empty?(results) do
      default_intelligence_summary()
    else
      [[threat_level, activity_level, engagement_preference, tactical_tendency]] = results

      %{
        threat_level: safe_to_atom(threat_level, :unknown),
        activity_level: safe_to_atom(activity_level, :unknown),
        engagement_preference: safe_to_atom(engagement_preference, :unknown),
        tactical_tendency: safe_to_atom(tactical_tendency, :unknown)
      }
    end
  end

  defp build_intelligence_summary_query do
    """
    SELECT
      'moderate' as threat_level,
      'active' as activity_level,
      'small_gang' as engagement_preference,
      'aggressive' as tactical_tendency
    """
  end

  defp default_intelligence_summary do
    %{
      threat_level: :unknown,
      activity_level: :unknown,
      engagement_preference: :unknown,
      tactical_tendency: :unknown
    }
  end

  defp format_weapon_preferences(results) do
    results
    |> Enum.map(fn [weapon_id, weapon_name, usage_count] ->
      %{
        weapon_type_id: weapon_id,
        weapon_name: weapon_name || "Unknown Weapon",
        usage_count: usage_count,
        # Would calculate from total
        percentage: 0.0
      }
    end)
  end

  defp build_weapon_preferences_query do
    """
    WITH weapon_usage AS (
      SELECT
        (k.raw_data->>'final_blow'->>'weapon_type_id')::integer as weapon_id,
        ei.type_name as weapon_name,
        COUNT(*) as usage_count
      FROM killmails_raw k
      LEFT JOIN eve_item_types ei ON ei.type_id = (k.raw_data->>'final_blow'->>'weapon_type_id')::integer
      WHERE k.killmail_time >= $2
        AND k.raw_data->>'final_blow'->>'character_id' = $1
      GROUP BY weapon_id, weapon_name
      ORDER BY usage_count DESC
      LIMIT 10
    )
    SELECT weapon_id, weapon_name, usage_count FROM weapon_usage
    """
  end

  # Helper function to safely convert strings to existing atoms
  defp safe_to_atom(nil, default), do: default
  defp safe_to_atom("", default), do: default

  defp safe_to_atom(value, default) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> default
  end

  defp safe_to_atom(value, _default) when is_atom(value), do: value
  defp safe_to_atom(_value, default), do: default
end
