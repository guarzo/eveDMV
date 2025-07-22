defmodule EveDmvWeb.CharacterAnalysis.Helpers.CharacterDataLoader do
  @moduledoc """
  Helper module for loading and processing character analysis data.
  """

  alias EveDmv.Database.CharacterQueries
  alias EveDmv.Database.QueryPerformance
  alias EveDmv.Shared.KillmailQueries
  alias EveDmv.StaticData
  alias EveDmv.Cache.QueryCache
  require Logger

  # Cache TTL configuration
  @ship_preferences_ttl :timer.hours(2)
  @weapon_preferences_ttl :timer.hours(2)
  @isk_efficiency_ttl :timer.hours(1)
  @gang_patterns_ttl :timer.hours(6)
  @activity_stats_ttl :timer.hours(4)
  @external_groups_ttl :timer.hours(8)
  @intelligence_summary_ttl :timer.minutes(30)

  @doc """
  Analyze character data for the character analysis LiveView.
  """
  def analyze_character(character_id) do
    try do
      Logger.info("Starting analysis for character #{character_id}")

      # Use optimized queries from CharacterQueries module
      ninety_days_ago = DateTime.utc_now() |> DateTime.add(-90, :day)

      # Get character stats using optimized query
      stats =
        QueryPerformance.tracked_query(
          "character_stats",
          fn -> CharacterQueries.get_character_stats(character_id, ninety_days_ago) end,
          metadata: %{character_id: character_id}
        )

      # Get character name from killmail data
      character_name =
        QueryPerformance.tracked_query(
          "character_name",
          fn -> CharacterQueries.get_character_name_from_killmails(character_id) end
        )

      Logger.info("Found character name: #{character_name || "Unknown"}")

      Logger.info(
        "Found #{stats.kills} kills and #{stats.deaths} deaths for character #{character_id}"
      )

      # Get affiliations
      affiliations =
        QueryPerformance.tracked_query(
          "character_affiliations",
          fn -> CharacterQueries.get_character_affiliations(character_id) end
        )

      # Get ship and weapon preferences
      top_ships = get_ship_preferences(character_id, ninety_days_ago)
      weapon_preferences = get_weapon_preferences(character_id, ninety_days_ago)

      # Calculate ISK efficiency
      isk_stats = calculate_isk_efficiency(character_id, ninety_days_ago)

      # Get external groups analysis (15-day window for more recent activity)
      fifteen_days_ago = DateTime.utc_now() |> DateTime.add(-15, :day)
      external_groups = get_external_groups(character_id, fifteen_days_ago)

      # Get gang size patterns
      gang_size_patterns = get_gang_size_patterns(character_id, ninety_days_ago)

      # Calculate activity metrics for the last 30 days
      thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)
      activity_stats = calculate_activity_stats(character_id, thirty_days_ago)

      # Calculate intelligence summary
      intelligence_summary =
        calculate_character_intelligence_summary(character_id, ninety_days_ago)

      analysis = %{
        character_id: character_id,
        character_name: character_name,
        corporation_name: affiliations.corporation_name,
        corporation_id: affiliations.corporation_id,
        alliance_name: affiliations.alliance_name,
        alliance_id: affiliations.alliance_id,
        total_kills: stats.kills,
        total_deaths: stats.deaths,
        kd_ratio: stats.kd_ratio,
        isk_efficiency: isk_stats.efficiency,
        isk_destroyed: isk_stats.destroyed,
        isk_lost: isk_stats.lost,
        top_ships: top_ships,
        weapon_preferences: weapon_preferences,
        external_groups: external_groups,
        gang_size_patterns: gang_size_patterns,
        recent_kills: activity_stats.recent_kills,
        most_active_day: activity_stats.most_active_day,
        active_days: activity_stats.active_days,
        intelligence_summary: intelligence_summary
      }

      {:ok, analysis}
    rescue
      error ->
        Logger.error("Analysis failed for character #{character_id}: #{inspect(error)}")
        {:error, "Failed to analyze character: #{inspect(error)}"}
    end
  end

  # Placeholder implementations - these would need to be moved from the original file
  # defp get_character_name(_character_id), do: "Unknown Pilot"
  defp get_ship_preferences(character_id, since_date) do
    cache_key =
      "ship_preferences:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        query = KillmailQueries.ship_usage_query(:character, character_id, 90)
        KillmailQueries.execute(query, [character_id, since_date])
      end,
      ttl: @ship_preferences_ttl
    )

    case do
      {:ok, results} ->
        # Calculate total usage for percentages
        total_usage = Enum.sum(Enum.map(results, &(&1["usage_count"] || 0)))

        results
        # Top 10 ships
        Enum.take(10)

        Enum.map(fn result ->
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

  defp get_weapon_preferences(character_id, since_date) do
    cache_key =
      "weapon_preferences:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        # Query to get killmails where the character was an attacker and analyze their weapon usage
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
                53, 54, 55, 74, 76, 506, 507, 508, 509, 510, 511, 512, 513, 514, 515, 516, 517, 518, 519, 520, 521, 522, 523, 524, 525, 526, 527, 528, 529, 530, 531, 532, 533, 534, 535, 536, 537, 538, 539, 540, 541, 542, 543, 544, 545, 546, 547, 548, 549, 550, 551, 552, 553, 554, 555, 556, 557, 558, 559, 560, 561, 562, 563, 564, 565, 566, 567, 568, 569, 570, 571, 572, 573, 574, 575, 576, 577, 578, 579, 580, 581, 582, 583, 584, 585, 586, 587, 588, 589, 590, 591, 592, 593, 594, 595, 596, 597, 598, 599, 600
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
          LIMIT 15
        )
        SELECT
          wu.weapon_type_id,
          eit.type_name as weapon_name,
          eit.group_name as weapon_group,
          wu.usage_count,
          wu.last_used
        FROM weapon_usage wu
        JOIN eve_item_types eit ON wu.weapon_type_id = eit.type_id
        ORDER BY wu.usage_count DESC
        """

        case EveDmv.Repo.query(weapon_query, [to_string(character_id), since_date]) do
          {:ok, %{rows: rows}} ->
            total_usage = Enum.sum(Enum.map(rows, fn [_, _, _, count, _] -> count end))

            rows

            Enum.map(fn [weapon_type_id, weapon_name, weapon_group, usage_count, last_used] ->
              # Categorize weapon type
              weapon_category = categorize_weapon_type(weapon_name, weapon_group)

              %{
                weapon_type_id: weapon_type_id,
                weapon_name: weapon_name,
                weapon_group: weapon_group,
                weapon_category: weapon_category,
                usage_count: usage_count,
                percentage:
                  if(total_usage > 0,
                    do: Float.round(usage_count / total_usage * 100, 1),
                    else: 0.0
                  ),
                last_used: last_used,
                effectiveness_rating: calculate_weapon_effectiveness(weapon_category, usage_count)
              }
            end)

          {:error, error} ->
            Logger.error(
              "Failed to get weapon preferences for character #{character_id}: #{inspect(error)}"
            )

            []
        end
      end,
      ttl: @weapon_preferences_ttl
    )
  end

  # Helper function to categorize weapons
  defp categorize_weapon_type(weapon_name, weapon_group) do
    name_lower = String.downcase(weapon_name || "")
    group_lower = String.downcase(weapon_group || "")

    cond do
      String.contains?(name_lower, [
        "blaster",
        "railgun",
        "beam",
        "pulse",
        "autocannon",
        "artillery"
      ]) ->
        :energy_weapon

      String.contains?(name_lower, ["missile", "torpedo", "rocket", "bomb"]) ->
        :missile_weapon

      String.contains?(name_lower, ["drone"]) ->
        :drone

      String.contains?(group_lower, ["projectile", "hybrid", "energy"]) ->
        :turret_weapon

      String.contains?(name_lower, ["neut", "nos", "neutralizer", "nosferatu"]) ->
        :energy_warfare

      String.contains?(name_lower, ["web", "scram", "disrupt", "point"]) ->
        :tackling

      String.contains?(name_lower, ["ecm", "damp", "tracking"]) ->
        :electronic_warfare

      true ->
        :other
    end
  end

  # Calculate effectiveness rating based on usage patterns
  defp calculate_weapon_effectiveness(weapon_category, usage_count) do
    base_rating =
      case weapon_category do
        :energy_weapon -> 85
        :missile_weapon -> 80
        :turret_weapon -> 82
        :drone -> 75
        :energy_warfare -> 70
        :tackling -> 78
        :electronic_warfare -> 65
        :other -> 60
      end

    # Adjust based on usage frequency (more usage = proven effectiveness)
    usage_modifier = min(usage_count * 2, 15)

    min(base_rating + usage_modifier, 100)
  end

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

  # Calculate risk level based on ship values and efficiency
  defp calculate_risk_level(avg_death_value, efficiency) do
    cond do
      # Expensive ships, poor efficiency
      avg_death_value > 5_000_000_000 and efficiency < 70 -> :very_high
      # Expensive ships, bad efficiency
      avg_death_value > 1_000_000_000 and efficiency < 60 -> :high
      # Mid-tier ships, poor efficiency
      avg_death_value > 500_000_000 and efficiency < 50 -> :medium
      # Cheap ships, terrible efficiency
      avg_death_value > 100_000_000 and efficiency < 40 -> :medium
      # Cheap ships, good efficiency
      avg_death_value < 50_000_000 and efficiency > 80 -> :low
      # Good efficiency overall
      efficiency > 70 -> :low
      # Average
      true -> :medium
    end
  end

  # Rate overall efficiency performance
  defp calculate_efficiency_rating(efficiency, net_isk) do
    cond do
      # Elite performer
      efficiency >= 85 and net_isk > 10_000_000_000 -> :excellent
      # Strong performer
      efficiency >= 75 and net_isk > 5_000_000_000 -> :very_good
      # Above average
      efficiency >= 65 and net_isk > 1_000_000_000 -> :good
      # Breaking even
      efficiency >= 50 and net_isk > 0 -> :average
      # Struggling
      efficiency >= 40 -> :below_average
      # Bad performance
      efficiency >= 25 -> :poor
      # Needs improvement
      true -> :very_poor
    end
  end

  defp get_external_groups(character_id, since_date) do
    cache_key = "external_groups:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        # Query to find external groups the character has flown with
        external_groups_query = """
        WITH character_corp_info AS (
          -- Get character's current corporation and alliance
          SELECT DISTINCT
            COALESCE(
              (SELECT raw_data->'victim'->>'corporation_id' FROM killmails_raw WHERE victim_character_id = $3 LIMIT 1),
              (SELECT attacker->>'corporation_id'
               FROM killmails_raw k, jsonb_array_elements(k.raw_data->'attackers') as attacker
               WHERE attacker->>'character_id' = $1 LIMIT 1)
            )::integer as char_corp_id,
            COALESCE(
              (SELECT raw_data->'victim'->>'alliance_id' FROM killmails_raw WHERE victim_character_id = $3 LIMIT 1),
              (SELECT attacker->>'alliance_id'
               FROM killmails_raw k, jsonb_array_elements(k.raw_data->'attackers') as attacker
               WHERE attacker->>'character_id' = $1 LIMIT 1)
            )::integer as char_alliance_id
        ),
        external_collaborations AS (
        SELECT
            k.killmail_id,
            k.killmail_time,
            k.solar_system_id,
            attacker->>'corporation_id' as ext_corp_id,
            attacker->>'corporation_name' as ext_corp_name,
            attacker->>'alliance_id' as ext_alliance_id,
            attacker->>'alliance_name' as ext_alliance_name,
            attacker->>'character_id' as ext_char_id,
            attacker->>'character_name' as ext_char_name,
            COALESCE((k.raw_data->>'total_value')::numeric, 0) as kill_value
          FROM killmails_raw k,
               jsonb_array_elements(k.raw_data->'attackers') as attacker,
               character_corp_info cci
          WHERE k.killmail_time >= $2
            AND EXISTS (
              SELECT 1 FROM jsonb_array_elements(k.raw_data->'attackers') as char_attacker
              WHERE char_attacker->>'character_id' = $1
            )
            AND attacker->>'character_id' != $1  -- Not the character themselves
            AND attacker->>'corporation_id' IS NOT NULL
            AND (
              attacker->>'corporation_id' != cci.char_corp_id::text  -- Different corporation
              OR (
                cci.char_alliance_id IS NULL AND attacker->>'alliance_id' IS NOT NULL  -- Character has no alliance, collaborator does
              )
            )
        ),
        corp_collaboration_stats AS (
        SELECT
            ext_corp_id::integer as corporation_id,
            ext_corp_name as corporation_name,
            ext_alliance_id::integer as alliance_id,
            ext_alliance_name as alliance_name,
            COUNT(DISTINCT killmail_id) as kills_together,
            COUNT(DISTINCT ext_char_id) as unique_pilots,
            COUNT(DISTINCT solar_system_id) as systems_active,
            SUM(kill_value) as total_isk_destroyed,
            AVG(kill_value) as avg_kill_value,
            MAX(killmail_time) as last_seen,
            MIN(killmail_time) as first_seen
          FROM external_collaborations
          WHERE ext_corp_id IS NOT NULL
          GROUP BY ext_corp_id, ext_corp_name, ext_alliance_id, ext_alliance_name
          HAVING COUNT(DISTINCT killmail_id) >= 2  -- At least 2 kills together
          ORDER BY kills_together DESC
          LIMIT 15
        )
        SELECT
          corporation_id,
          corporation_name,
          alliance_id,
          alliance_name,
          kills_together,
          unique_pilots,
          systems_active,
          total_isk_destroyed,
          avg_kill_value,
          last_seen,
        first_seen
        FROM corp_collaboration_stats
        """

        case EveDmv.Repo.query(external_groups_query, [
               to_string(character_id),
               since_date,
               character_id
             ]) do
          {:ok, %{rows: rows}} ->
            rows

            Enum.map(fn [
                          corp_id,
                          corp_name,
                          alliance_id,
                          alliance_name,
                          kills_together,
                          unique_pilots,
                          systems_active,
                          total_isk,
                          avg_kill_value,
                          last_seen,
                          first_seen
                        ] ->
              # Calculate collaboration strength
              collaboration_strength =
                calculate_collaboration_strength(kills_together, unique_pilots, systems_active)

              # Calculate relationship type
              relationship_type =
                determine_relationship_type(kills_together, unique_pilots, first_seen, last_seen)

              # Calculate days since last collaboration
              days_since_last =
                if last_seen do
                  Date.diff(Date.utc_today(), Date.from_iso8601!(Date.to_iso8601(last_seen)))
                else
                  nil
                end

              %{
                corporation_id: corp_id,
                corporation_name: corp_name || "Unknown Corporation",
                alliance_id: alliance_id,
                alliance_name: alliance_name,
                kills_together: kills_together,
                unique_pilots: unique_pilots,
                systems_active: systems_active,
                total_isk_destroyed: Decimal.to_float(total_isk || Decimal.new(0)),
                avg_kill_value: Decimal.to_float(avg_kill_value || Decimal.new(0)),
                last_seen: last_seen,
                first_seen: first_seen,
                days_since_last: days_since_last,
                collaboration_strength: collaboration_strength,
                relationship_type: relationship_type,
                trust_level: calculate_trust_level(kills_together, days_since_last)
              }
            end)

          {:error, error} ->
            Logger.error(
              "Failed to get external groups for character #{character_id}: #{inspect(error)}"
            )

            []
        end
      end,
      ttl: @external_groups_ttl
    )
  end

  # Calculate how strong the collaboration is
  defp calculate_collaboration_strength(kills_together, unique_pilots, systems_active) do
    # Base score from number of kills
    base_score =
      case kills_together do
        n when n >= 20 -> 80
        n when n >= 10 -> 60
        n when n >= 5 -> 40
        n when n >= 2 -> 20
        _ -> 10
      end

    # Boost for more pilots involved
    pilot_boost = min(unique_pilots * 5, 15)

    # Boost for operating in multiple systems
    system_boost = min(systems_active * 2, 10)

    total_score = base_score + pilot_boost + system_boost

    cond do
      total_score >= 90 -> :very_strong
      total_score >= 70 -> :strong
      total_score >= 50 -> :moderate
      total_score >= 30 -> :weak
      true -> :minimal
    end
  end

  # Determine the type of relationship based on activity patterns
  defp determine_relationship_type(kills_together, unique_pilots, first_seen, last_seen) do
    # Calculate time span
    time_span_days =
      if first_seen && last_seen do
        Date.diff(
          Date.from_iso8601!(Date.to_iso8601(last_seen)),
          Date.from_iso8601!(Date.to_iso8601(first_seen))
        )
      else
        0
      end

    cond do
      kills_together >= 15 and time_span_days > 30 -> :long_term_ally
      kills_together >= 10 and time_span_days <= 7 -> :intensive_campaign
      kills_together >= 5 and unique_pilots >= 5 -> :joint_operations
      kills_together >= 3 and time_span_days <= 1 -> :single_event
      kills_together >= 2 and time_span_days <= 3 -> :short_term_cooperation
      true -> :occasional_teamup
    end
  end

  # Calculate trust level based on frequency and recency
  defp calculate_trust_level(kills_together, days_since_last) do
    base_trust =
      case kills_together do
        n when n >= 20 -> :high
        n when n >= 10 -> :moderate
        n when n >= 5 -> :developing
        _ -> :low
      end

    # Adjust for recency
    case {base_trust, days_since_last} do
      {trust, days} when days != nil and days <= 7 ->
        # Recent activity boosts trust
        case trust do
          :low -> :developing
          :developing -> :moderate
          :moderate -> :high
          :high -> :very_high
        end

      {trust, days} when days != nil and days > 90 ->
        # Old activity reduces trust
        case trust do
          :very_high -> :high
          :high -> :moderate
          :moderate -> :developing
          :developing -> :low
          :low -> :minimal
        end

      {trust, _} ->
        trust
    end
  end

  defp get_gang_size_patterns(character_id, since_date) do
    cache_key = "gang_patterns:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        # Query to analyze gang size patterns from killmail participant counts
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
          COUNT(*) as kill_count,
          AVG(gang_size) as avg_gang_size,
          SUM(kill_value) as total_isk_destroyed,
          AVG(kill_value) as avg_kill_value,
          COUNT(DISTINCT solar_system_id) as systems_active
        FROM gang_size_categories
        GROUP BY size_category
        ORDER BY
          CASE size_category
            WHEN 'solo' THEN 1
            WHEN 'small_gang' THEN 2
            WHEN 'medium_gang' THEN 3
            WHEN 'large_gang' THEN 4
            WHEN 'fleet' THEN 5
        END
        """

        case EveDmv.Repo.query(gang_size_query, [to_string(character_id), since_date]) do
          {:ok, %{rows: rows}} ->
            total_kills = Enum.sum(Enum.map(rows, fn [_, count, _, _, _, _] -> count end))

            total_isk =
              Enum.sum(
                Enum.map(rows, fn [_, _, _, isk, _, _] ->
                  Decimal.to_float(isk || Decimal.new(0))
                end)
              )

            # Build patterns map with all categories
            patterns =
              Enum.reduce(rows, %{}, fn [
                                          category,
                                          count,
                                          avg_size,
                                          isk_destroyed,
                                          avg_value,
                                          systems
                                        ],
                                        acc ->
                percentage =
                  if total_kills > 0, do: Float.round(count / total_kills * 100, 1), else: 0.0

                isk_percentage =
                  if total_isk > 0,
                    do:
                      Float.round(
                        Decimal.to_float(isk_destroyed || Decimal.new(0)) / total_isk * 100,
                        1
                      ),
                    else: 0.0

                Map.put(acc, String.to_existing_atom(category), %{
                  kill_count: count,
                  percentage: percentage,
                  avg_gang_size: Float.round(Decimal.to_float(avg_size || Decimal.new(0)), 1),
                  total_isk_destroyed: Decimal.to_float(isk_destroyed || Decimal.new(0)),
                  isk_percentage: isk_percentage,
                  avg_kill_value: Decimal.to_float(avg_value || Decimal.new(0)),
                  systems_active: systems || 0,
                  effectiveness_rating: calculate_gang_effectiveness(percentage, isk_percentage)
                })
              end)

            # Ensure all categories exist with defaults
            default_pattern = %{
              kill_count: 0,
              percentage: 0.0,
              avg_gang_size: 0.0,
              total_isk_destroyed: 0.0,
              isk_percentage: 0.0,
              avg_kill_value: 0.0,
              systems_active: 0,
              effectiveness_rating: :no_data
            }

            %{
              solo: Map.get(patterns, :solo, default_pattern),
              small_gang: Map.get(patterns, :small_gang, default_pattern),
              medium_gang: Map.get(patterns, :medium_gang, default_pattern),
              large_gang: Map.get(patterns, :large_gang, default_pattern),
              fleet: Map.get(patterns, :fleet, default_pattern),
              preferred_style: determine_preferred_gang_style(patterns),
              activity_diversity: calculate_activity_diversity(patterns),
              total_kills: total_kills,
              total_isk_destroyed: total_isk
            }

          {:error, error} ->
            Logger.error(
              "Failed to get gang size patterns for character #{character_id}: #{inspect(error)}"
            )

            default_pattern = %{
              kill_count: 0,
              percentage: 0.0,
              avg_gang_size: 0.0,
              total_isk_destroyed: 0.0,
              isk_percentage: 0.0,
              avg_kill_value: 0.0,
              systems_active: 0,
              effectiveness_rating: :no_data
            }

            %{
              solo: default_pattern,
              small_gang: default_pattern,
              medium_gang: default_pattern,
              large_gang: default_pattern,
              fleet: default_pattern,
              preferred_style: :unknown,
              activity_diversity: :no_data,
              total_kills: 0,
              total_isk_destroyed: 0.0
            }
        end
      end,
      ttl: @gang_patterns_ttl
    )
  end

  # Calculate effectiveness rating for each gang size category
  defp calculate_gang_effectiveness(kill_percentage, isk_percentage) do
    cond do
      kill_percentage == 0.0 and isk_percentage == 0.0 -> :no_data
      # Dominant in this category
      kill_percentage >= 40 and isk_percentage >= 40 -> :excellent
      # Strong preference
      kill_percentage >= 25 and isk_percentage >= 30 -> :very_good
      # Regular activity
      kill_percentage >= 15 and isk_percentage >= 20 -> :good
      # Some activity
      kill_percentage >= 5 and isk_percentage >= 10 -> :moderate
      # Minimal activity
      kill_percentage > 0 or isk_percentage > 0 -> :limited
      true -> :no_data
    end
  end

  # Determine the character's preferred gang style
  defp determine_preferred_gang_style(patterns) when map_size(patterns) == 0, do: :unknown

  defp determine_preferred_gang_style(patterns) do
    # Find the category with highest combined score (kills + ISK percentage)
    {preferred, _score} =
      patterns

    Enum.map(fn {category, data} ->
      combined_score = data.percentage + data.isk_percentage
      {category, combined_score}
    end)

    Enum.max_by(fn {_category, score} -> score end, fn -> {:unknown, 0} end)

    preferred
  end

  # Calculate how diverse the character's activity is across gang sizes
  defp calculate_activity_diversity(patterns) when map_size(patterns) == 0, do: :no_data

  defp calculate_activity_diversity(patterns) do
    active_categories =
      patterns

    Enum.count(fn {_category, data} -> data.kill_count > 0 end)

    case active_categories do
      0 -> :no_data
      # Only active in one category
      1 -> :specialist
      # Active in two categories
      2 -> :focused
      # Active in three categories
      3 -> :diverse
      # Active in four categories
      4 -> :very_diverse
      # Active in all categories
      5 -> :omni_active
      _ -> :diverse
    end
  end

  defp calculate_activity_stats(character_id, since_date) do
    cache_key = "activity_stats:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        # Query to get activity patterns from killmail timestamps
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
            activity_date,
            COUNT(*) as daily_count,
            COUNT(CASE WHEN activity_type = 'kill' THEN 1 END) as kills,
            COUNT(CASE WHEN activity_type = 'death' THEN 1 END) as deaths
          FROM character_activity
          GROUP BY activity_date
          ORDER BY activity_date DESC
        ),
        weekday_activity AS (
        SELECT
            day_of_week,
            COUNT(*) as activity_count,
            CASE day_of_week
              WHEN 0 THEN 'Sunday'
              WHEN 1 THEN 'Monday'
              WHEN 2 THEN 'Tuesday'
              WHEN 3 THEN 'Wednesday'
              WHEN 4 THEN 'Thursday'
              WHEN 5 THEN 'Friday'
              WHEN 6 THEN 'Saturday'
            END as weekday_name
          FROM character_activity
          GROUP BY day_of_week
          ORDER BY activity_count DESC
        )
        SELECT
          -- Recent activity metrics
          (SELECT COUNT(*) FROM character_activity WHERE activity_date >= CURRENT_DATE - INTERVAL '7 days') as recent_kills,
          (SELECT COUNT(DISTINCT activity_date) FROM character_activity) as active_days,

          -- Peak activity patterns
          (SELECT hour_utc FROM hourly_activity LIMIT 1) as most_active_hour,
          (SELECT weekday_name FROM weekday_activity LIMIT 1) as most_active_weekday,
          (SELECT activity_date FROM daily_activity ORDER BY daily_count DESC LIMIT 1) as best_day,
          (SELECT daily_count FROM daily_activity ORDER BY daily_count DESC LIMIT 1) as best_day_count,

          -- Activity consistency
          (SELECT AVG(daily_count) FROM daily_activity) as avg_daily_activity,
          (SELECT STDDEV(daily_count) FROM daily_activity) as activity_variance,

          -- Recent trends (last 7 vs previous 7 days)
          (SELECT COUNT(*) FROM character_activity WHERE activity_date >= CURRENT_DATE - INTERVAL '7 days') as last_7_days,
          (SELECT COUNT(*) FROM character_activity WHERE activity_date >= CURRENT_DATE - INTERVAL '14 days' AND activity_date < CURRENT_DATE - INTERVAL '7 days') as prev_7_days
        """

        case EveDmv.Repo.query(activity_query, [to_string(character_id), since_date, character_id]) do
          {:ok,
           %{
             rows: [
               [
                 recent_kills,
                 active_days,
                 most_active_hour,
                 most_active_weekday,
                 best_day,
                 best_day_count,
                 avg_daily,
                 variance,
                 last_7,
                 prev_7
               ]
             ]
           }} ->
            # Calculate timezone estimate from peak hour
            timezone_estimate = estimate_timezone_from_peak_hour(most_active_hour)

            # Calculate activity trend
            trend = calculate_activity_trend(last_7 || 0, prev_7 || 0)

            # Calculate activity consistency rating
            consistency =
              calculate_activity_consistency(
                Decimal.to_float(variance || Decimal.new(0)),
                active_days || 0
              )

            # Calculate activity streak (consecutive days)
            current_streak = calculate_current_streak(character_id, since_date)
            longest_streak = calculate_longest_streak(character_id, since_date)

            %{
              recent_kills: recent_kills || 0,
              active_days: active_days || 0,
              most_active_hour: most_active_hour,
              most_active_weekday: most_active_weekday,
              best_day: best_day,
              best_day_activity: best_day_count || 0,
              avg_daily_activity: Float.round(Decimal.to_float(avg_daily || Decimal.new(0)), 1),
              activity_consistency: consistency,
              timezone_estimate: timezone_estimate,
              activity_trend: trend,
              current_streak: current_streak,
              longest_streak: longest_streak,
              activity_rating:
                calculate_activity_rating(recent_kills || 0, active_days || 0, consistency)
            }

          {:error, error} ->
            Logger.error(
              "Failed to calculate activity stats for character #{character_id}: #{inspect(error)}"
            )

            %{
              recent_kills: 0,
              active_days: 0,
              most_active_hour: nil,
              most_active_weekday: nil,
              best_day: nil,
              best_day_activity: 0,
              avg_daily_activity: 0.0,
              activity_consistency: :no_data,
              timezone_estimate: :unknown,
              activity_trend: :stable,
              current_streak: 0,
              longest_streak: 0,
              activity_rating: :inactive
            }
        end
      end,
      ttl: @activity_stats_ttl
    )
  end

  # Estimate timezone from peak activity hour (assumes player plays in their local evening)
  defp estimate_timezone_from_peak_hour(nil), do: :unknown

  defp estimate_timezone_from_peak_hour(peak_hour) when is_integer(peak_hour) do
    # Assume players are most active between 18:00-22:00 local time
    # Convert UTC peak to estimated local timezone
    case peak_hour do
      # Europe/London evening
      hour when hour in 18..22 -> "UTC+0"
      # Europe/Berlin evening
      hour when hour in 17..21 -> "UTC+1"
      # Europe/Helsinki evening
      hour when hour in 16..20 -> "UTC+2"
      # US Eastern evening
      hour when hour in 2..6 -> "UTC-5"
      # US Central evening
      hour when hour in 1..5 -> "UTC-6"
      # US Mountain evening
      hour when hour in 0..4 -> "UTC-7"
      # US Pacific evening
      hour when hour in 23..23 or hour in 0..3 -> "UTC-8"
      # Asia/Shanghai evening
      hour when hour in 9..13 -> "UTC+8"
      # Asia/Tokyo evening
      hour when hour in 8..12 -> "UTC+9"
      # Australia/Sydney evening
      hour when hour in 7..11 -> "UTC+10"
      _ -> :uncertain
    end
  end

  # Calculate activity trend comparison
  defp calculate_activity_trend(last_7, prev_7) when last_7 > 0 and prev_7 > 0 do
    change_percent = (last_7 - prev_7) / prev_7 * 100

    cond do
      change_percent > 50 -> :surging
      change_percent > 20 -> :increasing
      change_percent > 5 -> :rising
      change_percent > -5 -> :stable
      change_percent > -20 -> :declining
      change_percent > -50 -> :dropping
      true -> :crashing
    end
  end

  defp calculate_activity_trend(last_7, prev_7) when last_7 > prev_7, do: :rising
  defp calculate_activity_trend(last_7, prev_7) when last_7 < prev_7, do: :declining
  defp calculate_activity_trend(_, _), do: :stable

  # Calculate how consistent the player's activity is
  defp calculate_activity_consistency(_variance, active_days) when active_days < 3,
    do: :insufficient_data

  defp calculate_activity_consistency(variance, _active_days) do
    cond do
      # Very regular activity
      variance <= 1.0 -> :very_consistent
      # Pretty regular
      variance <= 3.0 -> :consistent
      # Some variation
      variance <= 6.0 -> :moderate
      # Quite variable
      variance <= 12.0 -> :variable
      # Very unpredictable
      true -> :erratic
    end
  end

  # Calculate current consecutive active days streak
  defp calculate_current_streak(character_id, since_date) do
    streak_query = """
    WITH daily_activity AS (
      SELECT DISTINCT DATE(k.killmail_time) as activity_date
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
      ORDER BY activity_date DESC
    ),
    streak_calc AS (
    SELECT
        activity_date,
        ROW_NUMBER() OVER (ORDER BY activity_date DESC) as rn,
        activity_date + ROW_NUMBER() OVER (ORDER BY activity_date DESC) * INTERVAL '1 day' as expected_date
      FROM daily_activity
    )
    SELECT COUNT(*) as current_streak
    FROM streak_calc
    WHERE expected_date >= CURRENT_DATE
    """

    case EveDmv.Repo.query(streak_query, [to_string(character_id), since_date, character_id]) do
      {:ok, %{rows: [[streak]]}} -> streak || 0
      _ -> 0
    end
  end

  # Calculate longest streak in the time period
  defp calculate_longest_streak(character_id, since_date) do
    # For simplicity, return current streak as longest for now
    # A more complex implementation would calculate all streaks
    calculate_current_streak(character_id, since_date)
  end

  # Rate overall activity level
  defp calculate_activity_rating(recent_kills, active_days, consistency) do
    base_score =
      cond do
        recent_kills >= 50 and active_days >= 14 -> :very_active
        recent_kills >= 20 and active_days >= 7 -> :active
        recent_kills >= 5 and active_days >= 3 -> :moderate
        recent_kills >= 1 and active_days >= 1 -> :casual
        true -> :inactive
      end

    # Adjust based on consistency
    case {base_score, consistency} do
      {:very_active, :very_consistent} -> :elite_active
      {:active, :very_consistent} -> :very_active
      {:very_active, :erratic} -> :active
      {rating, _} -> rating
    end
  end

  defp calculate_character_intelligence_summary(character_id, since_date) do
    cache_key =
      "intelligence_summary:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        # Query to aggregate intelligence data for the summary
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
            COALESCE((k.raw_data->>'total_value')::numeric, 0) as kill_value
          FROM killmails_raw k
          LEFT JOIN eve_solar_systems s ON k.solar_system_id = s.system_id
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
        hourly_analysis AS (
        SELECT
            hour_utc,
            COUNT(*) as activity_count,
            COUNT(CASE WHEN activity_type = 'kill' THEN 1 END) as kills,
            COUNT(CASE WHEN activity_type = 'death' THEN 1 END) as deaths,
            SUM(CASE WHEN activity_type = 'kill' THEN kill_value ELSE 0 END) as isk_destroyed
          FROM character_activity
          GROUP BY hour_utc
          ORDER BY activity_count DESC
        ),
        location_analysis AS (
        SELECT
            solar_system_id,
            system_name,
            region_name,
            COUNT(*) as activity_count,
            COUNT(CASE WHEN activity_type = 'kill' THEN 1 END) as kills,
            COUNT(CASE WHEN activity_type = 'death' THEN 1 END) as deaths,
            SUM(kill_value) as total_isk
          FROM character_activity
          WHERE solar_system_id IS NOT NULL
          GROUP BY solar_system_id, system_name, region_name
          ORDER BY activity_count DESC
        ),
        region_analysis AS (
        SELECT
            region_name,
            COUNT(*) as activity_count,
            COUNT(DISTINCT solar_system_id) as systems_active,
            SUM(kill_value) as total_isk
          FROM character_activity
          WHERE region_name IS NOT NULL
          GROUP BY region_name
          ORDER BY activity_count DESC
        )
        SELECT
          -- Peak activity hour
          (SELECT hour_utc FROM hourly_analysis LIMIT 1) as peak_activity_hour,
          (SELECT activity_count FROM hourly_analysis LIMIT 1) as peak_hour_activity,
          (SELECT isk_destroyed FROM hourly_analysis LIMIT 1) as peak_hour_isk,

          -- Top location (system)
          (SELECT solar_system_id FROM location_analysis LIMIT 1) as top_system_id,
          (SELECT system_name FROM location_analysis LIMIT 1) as top_system_name,
          (SELECT region_name FROM location_analysis LIMIT 1) as top_system_region,
          (SELECT activity_count FROM location_analysis LIMIT 1) as top_system_activity,

          -- Top region
          (SELECT region_name FROM region_analysis LIMIT 1) as top_region_name,
          (SELECT activity_count FROM region_analysis LIMIT 1) as top_region_activity,
          (SELECT systems_active FROM region_analysis LIMIT 1) as top_region_systems,

          -- Activity diversity metrics
          (SELECT COUNT(*) FROM hourly_analysis WHERE activity_count > 0) as active_hours,
          (SELECT COUNT(*) FROM location_analysis WHERE activity_count > 0) as active_systems,
          (SELECT COUNT(*) FROM region_analysis WHERE activity_count > 0) as active_regions
        """

        case EveDmv.Repo.query(intelligence_summary_query, [
               to_string(character_id),
               since_date,
               character_id
             ]) do
          {:ok,
           %{
             rows: [
               [
                 peak_hour,
                 peak_hour_activity,
                 peak_hour_isk,
                 top_system_id,
                 top_system_name,
                 top_system_region,
                 top_system_activity,
                 top_region_name,
                 top_region_activity,
                 top_region_systems,
                 active_hours,
                 active_systems,
                 active_regions
               ]
             ]
           }} ->
            # Estimate timezone from peak hour
            primary_timezone = estimate_timezone_from_peak_hour(peak_hour)

            # Determine activity concentration
            activity_concentration =
              determine_activity_concentration(
                active_hours || 0,
                active_systems || 0,
                active_regions || 0
              )

            # Determine preferred operational area
            operational_preference =
              determine_operational_preference(top_region_systems || 0, active_regions || 0)

            %{
              peak_activity_hour: peak_hour,
              peak_hour_activity: peak_hour_activity || 0,
              peak_hour_isk: Decimal.to_float(peak_hour_isk || Decimal.new(0)),
              primary_timezone: primary_timezone,
              top_location: %{
                system_id: top_system_id,
                system_name: top_system_name || "Unknown System",
                region_name: top_system_region || "Unknown Region",
                activity_count: top_system_activity || 0
              },
              top_region: %{
                region_name: top_region_name || "Unknown Region",
                activity_count: top_region_activity || 0,
                systems_active: top_region_systems || 0
              },
              activity_spread: %{
                active_hours: active_hours || 0,
                active_systems: active_systems || 0,
                active_regions: active_regions || 0,
                concentration: activity_concentration
              },
              operational_preference: operational_preference,
              intelligence_rating:
                calculate_intelligence_rating(
                  active_systems || 0,
                  active_regions || 0,
                  peak_hour_activity || 0
                )
            }

          {:error, error} ->
            Logger.error(
              "Failed to calculate intelligence summary for character #{character_id}: #{inspect(error)}"
            )

            %{
              peak_activity_hour: nil,
              peak_hour_activity: 0,
              peak_hour_isk: 0.0,
              primary_timezone: :unknown,
              top_location: %{
                system_id: nil,
                system_name: "No Data",
                region_name: "No Data",
                activity_count: 0
              },
              top_region: %{
                region_name: "No Data",
                activity_count: 0,
                systems_active: 0
              },
              activity_spread: %{
                active_hours: 0,
                active_systems: 0,
                active_regions: 0,
                concentration: :no_data
              },
              operational_preference: :unknown,
              intelligence_rating: :insufficient_data
            }
        end
      end,
      ttl: @intelligence_summary_ttl
    )
  end

  # Determine how concentrated the character's activity is
  defp determine_activity_concentration(active_hours, active_systems, active_regions) do
    cond do
      active_hours <= 3 and active_systems <= 5 and active_regions <= 1 -> :highly_concentrated
      active_hours <= 6 and active_systems <= 10 and active_regions <= 2 -> :concentrated
      active_hours <= 12 and active_systems <= 20 and active_regions <= 3 -> :moderate
      active_hours <= 18 and active_systems <= 40 and active_regions <= 5 -> :spread_out
      true -> :highly_dispersed
    end
  end

  # Determine operational preferences based on geographic activity
  defp determine_operational_preference(top_region_systems, total_regions) do
    cond do
      total_regions <= 1 -> :regional_specialist
      total_regions <= 2 and top_region_systems >= 5 -> :regional_focused
      total_regions <= 3 and top_region_systems >= 3 -> :multi_regional
      total_regions >= 4 and top_region_systems <= 3 -> :nomadic
      total_regions >= 5 -> :empire_wide
      true -> :unknown
    end
  end

  # Rate the quality of intelligence data available
  defp calculate_intelligence_rating(active_systems, active_regions, peak_activity) do
    # Base score from activity spread
    spread_score =
      case {active_systems, active_regions} do
        {systems, regions} when systems >= 20 and regions >= 3 -> 80
        {systems, regions} when systems >= 10 and regions >= 2 -> 60
        {systems, regions} when systems >= 5 and regions >= 1 -> 40
        {systems, _regions} when systems >= 2 -> 20
        _ -> 10
      end

    # Boost from peak activity level
    activity_boost =
      case peak_activity do
        count when count >= 10 -> 15
        count when count >= 5 -> 10
        count when count >= 2 -> 5
        _ -> 0
      end

    total_score = spread_score + activity_boost

    cond do
      total_score >= 90 -> :excellent
      total_score >= 70 -> :good
      total_score >= 50 -> :moderate
      total_score >= 30 -> :limited
      total_score >= 10 -> :poor
      true -> :insufficient_data
    end
  end

  # defp get_corporation_alliance_from_killmails(_character_id), do: {nil, nil, nil, nil}
end
